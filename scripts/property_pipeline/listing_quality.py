"""Quality rules for listings before they hit Supabase.

Source policy (do not scrape portals):
  1. PropertyGuru partner / academic / manual export — primary
  2. Mudah exports — only to fill states/districts Guru is thin on
  3. This seed generator — last resort when no licensed feed exists

data.gov.my stays for neighbourhood stats, not individual houses.
"""

from __future__ import annotations

import re
from typing import Any

VALID_STATES = {
    "Johor",
    "Kedah",
    "Kelantan",
    "Melaka",
    "Negeri Sembilan",
    "Pahang",
    "Penang",
    "Perak",
    "Perlis",
    "Selangor",
    "Terengganu",
    "Sabah",
    "Sarawak",
    "Kuala Lumpur",
    "Labuan",
    "Putrajaya",
}

# Apartment / condo / serviced: 400–2500
# Terrace / townhouse: 800–3500
# Semi-D: 1500–6000
# Bungalow / villa: 2000–12000
_SIZE_BANDS = [
    (("bungalow", "villa"), 2000, 12000),
    (("semi", "semi-d", "semi d"), 1500, 6000),
    (("terrace", "townhouse", "link"), 800, 3500),
    (("apartment", "condo", "condominium", "serviced", "flat", "soho", "studio"), 400, 2500),
]

_GENERIC_PHRASES = (
    "intentionally complete",
    "buyers looking for a balanced location",
    "this record intentionally",
)

_SQFT_RE = re.compile(r"([\d,]+(?:\.\d+)?)\s*(sq\.?\s*ft|sqft|sf)?", re.I)
_SQM_RE = re.compile(r"([\d,]+(?:\.\d+)?)\s*(sq\.?\s*m|sqm|m2|m²)", re.I)


def parse_built_up_sqft(raw: Any) -> float | None:
    if raw is None:
        return None
    text = str(raw).strip()
    if not text:
        return None
    sqm = _SQM_RE.search(text)
    if sqm:
        return float(sqm.group(1).replace(",", "")) * 10.7639
    match = _SQFT_RE.search(text.replace(" ", ""))
    if not match:
        match = _SQFT_RE.search(text)
    if not match:
        try:
            return float(text.replace(",", ""))
        except ValueError:
            return None
    return float(match.group(1).replace(",", ""))


def _type_band(property_type: str | None) -> tuple[int, int]:
    label = (property_type or "").lower()
    for needles, low, high in _SIZE_BANDS:
        if any(n in label for n in needles):
            return low, high
    return 400, 8000


def size_in_range(property_type: str | None, sqft: float) -> bool:
    low, high = _type_band(property_type)
    return low <= sqft <= high


def validate_listing(row: dict[str, Any]) -> list[str]:
    """Return a list of reject reasons. Empty means the row is ingestible."""
    reasons: list[str] = []
    listing_id = str(row.get("listing_id") or "").strip()
    if not listing_id:
        reasons.append("missing listing_id")

    state = str(row.get("state") or "").strip()
    if state not in VALID_STATES:
        reasons.append(f"invalid state: {state!r}")

    district = str(row.get("district") or "").strip()
    if not district:
        reasons.append("missing district")

    description = str(row.get("description") or "").strip()
    if len(description) < 200:
        reasons.append("description too short")
    lower = description.lower()
    if any(p in lower for p in _GENERIC_PHRASES):
        reasons.append("generic template description")

    photos = str(row.get("photo_urls") or "")
    http_photos = [
        p.strip()
        for p in photos.split("|")
        if p.strip().lower().startswith(("http://", "https://"))
    ]
    if not http_photos:
        reasons.append("no http(s) photo")

    price = row.get("price")
    try:
        price_n = float(price)
    except (TypeError, ValueError):
        reasons.append("invalid price")
        price_n = None
    if price_n is not None and not (80_000 <= price_n <= 15_000_000):
        reasons.append(f"price out of range: {price_n}")

    sqft = parse_built_up_sqft(row.get("built_up"))
    if sqft is None or sqft <= 0:
        reasons.append("unparseable built_up")
    elif not size_in_range(str(row.get("property_type") or ""), sqft):
        reasons.append(f"implausible built_up {sqft:.0f} sq ft for {row.get('property_type')}")

    return reasons


def filter_listings(rows: list[dict[str, Any]]) -> tuple[list[dict[str, Any]], list[dict[str, Any]]]:
    kept: list[dict[str, Any]] = []
    dropped: list[dict[str, Any]] = []
    seen_ids: set[str] = set()
    seen_desc: set[str] = set()

    for row in rows:
        reasons = validate_listing(row)
        listing_id = str(row.get("listing_id") or "").strip()
        if listing_id in seen_ids:
            reasons.append("duplicate listing_id")
        desc_key = re.sub(r"\s+", " ", str(row.get("description") or "").strip().lower())[:160]
        if desc_key and desc_key in seen_desc:
            reasons.append("duplicate description prefix")
        if reasons:
            dropped.append({"listing_id": listing_id, "reasons": reasons})
            continue
        seen_ids.add(listing_id)
        seen_desc.add(desc_key)
        kept.append(row)
    return kept, dropped
