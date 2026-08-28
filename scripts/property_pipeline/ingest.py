"""Validate listings and upsert into Supabase `properties`.

Reads scripts/property_pipeline/.env (SUPABASE_URL + SUPABASE_SERVICE_ROLE_KEY).
Never scrapes PropertyGuru / iProperty / Mudah — drop a licensed JSON/CSV export
into data/clean_listings.json, or run generate_seed.py as a fallback.
"""

from __future__ import annotations

import csv
import json
import os
import sys
import urllib.error
import urllib.request
from pathlib import Path

from listing_quality import filter_listings

ROOT = Path(__file__).resolve().parent
DATA = ROOT / "data"
ENV_PATH = ROOT / ".env"


def _load_env() -> dict[str, str]:
    values: dict[str, str] = {}
    if ENV_PATH.exists():
        for line in ENV_PATH.read_text(encoding="utf-8").splitlines():
            line = line.strip()
            if not line or line.startswith("#") or "=" not in line:
                continue
            key, val = line.split("=", 1)
            values[key.strip()] = val.strip().strip('"').strip("'")
    values.update({k: v for k, v in os.environ.items() if k.startswith("SUPABASE_")})
    return values


def _load_rows(path: Path) -> list[dict]:
    if path.suffix.lower() == ".json":
        data = json.loads(path.read_text(encoding="utf-8"))
        if not isinstance(data, list):
            raise SystemExit("JSON must be a list of listing objects")
        return data
    if path.suffix.lower() == ".csv":
        with path.open(encoding="utf-8", newline="") as fh:
            return list(csv.DictReader(fh))
    raise SystemExit(f"Unsupported file type: {path}")


def _upsert(url: str, key: str, rows: list[dict]) -> None:
    endpoint = url.rstrip("/") + "/rest/v1/properties?on_conflict=listing_id"
    body = json.dumps(rows).encode("utf-8")
    req = urllib.request.Request(
        endpoint,
        data=body,
        method="POST",
        headers={
            "apikey": key,
            "Authorization": f"Bearer {key}",
            "Content-Type": "application/json",
            "Prefer": "resolution=merge-duplicates,return=minimal",
        },
    )
    try:
        with urllib.request.urlopen(req, timeout=60) as resp:
            if resp.status not in (200, 201, 204):
                raise SystemExit(f"Supabase returned HTTP {resp.status}")
    except urllib.error.HTTPError as exc:
        detail = exc.read().decode("utf-8", errors="replace")
        raise SystemExit(f"Supabase upsert failed ({exc.code}): {detail[:500]}") from exc


def main() -> None:
    src = Path(sys.argv[1]) if len(sys.argv) > 1 else DATA / "clean_listings.json"
    rows = _load_rows(src)
    kept, dropped = filter_listings(rows)
    report = DATA / "ingest_report.json"
    report.write_text(
        json.dumps(
            {"kept": len(kept), "dropped": len(dropped), "rejects": dropped[:80]},
            indent=2,
        ),
        encoding="utf-8",
    )
    print(f"Validated {len(rows)} rows -> kept {len(kept)}, dropped {len(dropped)}")
    print(f"Reject report: {report}")
    if not kept:
        raise SystemExit("Nothing to upsert")

    env = _load_env()
    url = env.get("SUPABASE_URL")
    key = env.get("SUPABASE_SERVICE_ROLE_KEY")
    if not url or not key:
        print("No SUPABASE_URL / SUPABASE_SERVICE_ROLE_KEY — wrote clean file only.")
        (DATA / "clean_listings.validated.json").write_text(
            json.dumps(kept, indent=2, ensure_ascii=False),
            encoding="utf-8",
        )
        return

    chunk = 80
    for i in range(0, len(kept), chunk):
        _upsert(url, key, kept[i : i + chunk])
        print(f"Upserted {min(i + chunk, len(kept))}/{len(kept)}")


if __name__ == "__main__":
    main()
