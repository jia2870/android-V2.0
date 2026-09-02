"""Fallback nationwide seed when no PropertyGuru/Mudah export is available.

Generates unique descriptions, realistic built-up, and https photos for every
Malaysian state used by the app. Does not scrape listing sites.
"""

from __future__ import annotations

import json
from datetime import datetime, timezone
from pathlib import Path

from listing_quality import VALID_STATES, filter_listings

DATA_DIR = Path(__file__).resolve().parent / "data"

STATE_CODES = {
    "Johor": "joh",
    "Kedah": "ked",
    "Kelantan": "kel",
    "Melaka": "mlk",
    "Negeri Sembilan": "nsn",
    "Pahang": "phg",
    "Penang": "png",
    "Perak": "prk",
    "Perlis": "pls",
    "Selangor": "sgr",
    "Terengganu": "trg",
    "Sabah": "sbh",
    "Sarawak": "swk",
    "Kuala Lumpur": "kul",
    "Labuan": "lbn",
    "Putrajaya": "pjy",
}

STATE_DISTRICTS: dict[str, list[str]] = {
    "Johor": ["Johor Bahru", "Skudai", "Kulai", "Iskandar Puteri", "Batu Pahat"],
    "Kedah": ["Alor Setar", "Sungai Petani", "Kulim", "Langkawi"],
    "Kelantan": ["Kota Bharu", "Pengkalan Chepa", "Pasir Mas"],
    "Melaka": ["Melaka Tengah", "Ayer Keroh", "Alor Gajah"],
    "Negeri Sembilan": ["Seremban", "Nilai", "Port Dickson"],
    "Pahang": ["Kuantan", "Bentong", "Temerloh"],
    "Penang": ["George Town", "Bayan Lepas", "Butterworth", "Bukit Mertajam"],
    "Perak": ["Ipoh", "Taiping", "Sitiawan"],
    "Perlis": ["Kangar", "Arau"],
    "Selangor": ["Petaling Jaya", "Subang Jaya", "Shah Alam", "Kajang", "Puchong"],
    "Terengganu": ["Kuala Terengganu", "Kemaman", "Dungun"],
    "Sabah": ["Kota Kinabalu", "Penampang", "Sandakan"],
    "Sarawak": ["Kuching", "Miri", "Sibu"],
    "Kuala Lumpur": ["Cheras", "Kepong", "Bangsar", "Setapak", "Mont Kiara"],
    "Labuan": ["Labuan"],
    "Putrajaya": ["Presint 8", "Presint 11"],
}

TYPES = [
    ("Apartment", 2, 2, 650, 1100, 0.72),
    ("Condominium", 3, 2, 900, 1600, 0.95),
    ("Serviced Residence", 1, 1, 450, 850, 0.85),
    ("1-storey Terraced House", 3, 2, 900, 1400, 1.05),
    ("2-storey Terraced House", 4, 3, 1400, 2200, 1.25),
    ("Semi-D", 4, 3, 1800, 3200, 1.7),
    ("Bungalow", 5, 4, 2800, 5500, 2.4),
]

STATE_PRICE: dict[str, int] = {
    "Kuala Lumpur": 780000,
    "Selangor": 620000,
    "Penang": 580000,
    "Putrajaya": 700000,
    "Johor": 480000,
    "Melaka": 420000,
    "Negeri Sembilan": 400000,
    "Perak": 380000,
    "Sabah": 450000,
    "Sarawak": 430000,
    "Pahang": 360000,
    "Kedah": 340000,
    "Kelantan": 300000,
    "Terengganu": 320000,
    "Perlis": 280000,
    "Labuan": 400000,
}

PHOTOS = [
    "https://images.unsplash.com/photo-1522708323590-d24dbb6b0267?auto=format&fit=crop&w=1200&q=80",
    "https://images.unsplash.com/photo-1502672260266-1c1ef2d93688?auto=format&fit=crop&w=1200&q=80",
    "https://images.unsplash.com/photo-1560448204-e02f11c3d0e2?auto=format&fit=crop&w=1200&q=80",
    "https://images.unsplash.com/photo-1564013799919-ab600027ffc6?auto=format&fit=crop&w=1200&q=80",
    "https://images.unsplash.com/photo-1600585154340-0ef3ee41bbe6?auto=format&fit=crop&w=1200&q=80",
    "https://images.unsplash.com/photo-1600596542815-ffad4c1539a9?auto=format&fit=crop&w=1200&q=80",
    "https://images.unsplash.com/photo-1570129477492-45c003edd2be?auto=format&fit=crop&w=1200&q=80",
    "https://images.unsplash.com/photo-1605276374104-dee2a0ed3cd6?auto=format&fit=crop&w=1200&q=80",
]

AGENTS = [
    "Lee Property Hub",
    "Siti Homes",
    "Ahmad Realty",
    "Tan & Co",
    "Mei Ling Properties",
    "Borneo Home Advisors",
]

TENURES = ["Freehold", "Leasehold"]

FACILITY_SETS = [
    "24-hour security|Covered parking|Playground",
    "Gym|Swimming Pool|Security|Parking",
    "Covered parking|Playground|Security",
    "Swimming Pool|Gym|Jogging track|Security",
    "Gated community|Parking|Playground",
]

NEARBY = {
    "Johor": "CIQ / RTS access and malls along the Iskandar corridor",
    "Kedah": "padi-field townships and the North-South Expressway",
    "Kelantan": "Kota Bharu town centre and weekend pasar",
    "Melaka": "heritage core and Ayer Keroh education belt",
    "Negeri Sembilan": "Seremban–KLIA commute and Nilai colleges",
    "Pahang": "Kuantan waterfront and East Coast Expressway",
    "Penang": "Bayan Lepas industrial parks and island beaches",
    "Perak": "Ipoh old town cafes and the North-South Expressway",
    "Perlis": "Kangar civic centre and the Thai border towns",
    "Selangor": "LRT/MRT catchments and Klang Valley job centres",
    "Terengganu": "Kuala Terengganu drawbridge and coastal kampung",
    "Sabah": "KK city malls and the ridgeline toward Penampang",
    "Sarawak": "Kuching riverfront and pending new townships",
    "Kuala Lumpur": "LRT/MRT stations and established food streets",
    "Labuan": "the financial park and ferry terminal",
    "Putrajaya": "government precincts and lakeside parks",
}


def _price(state: str, multiplier: float, index: int) -> int:
    base = STATE_PRICE[state]
    raw = int(base * multiplier * (0.82 + (index % 7) * 0.04))
    return max(120_000, min(8_500_000, raw))


def _sqft(low: int, high: int, index: int) -> int:
    span = high - low
    return low + (index * 97) % span


def _description(
    *,
    ptype: str,
    district: str,
    state: str,
    beds: int,
    baths: int,
    sqft: int,
    price: int,
    tenure: str,
    index: int,
) -> str:
    commute = [
        "weekday traffic is busiest toward the nearest highway interchange",
        "school-run hours are the main congestion window",
        "weekends stay relatively quiet except around the local pasar",
        "ride-hailing coverage is reliable for last-mile trips",
    ][index % 4]
    finish = [
        "original built-in kitchen cabinets with room to refresh the worktop",
        "a recently painted interior and tiled wet areas",
        "timber-look flooring in the living zone and ceramic in the wet kitchen",
        "air-cond points in the living room and master bedroom",
    ][index % 4]
    buyer = [
        "first-time buyers who want a liveable size without stretching the loan",
        "upgraders leaving a smaller high-rise",
        "families who need extra bedrooms near everyday amenities",
        "investors looking at owner-occupier demand rather than short stays",
    ][index % 4]
    return (
        f"This {ptype.lower()} in {district}, {state} is listed at about RM {price:,} "
        f"with {beds} bedrooms, {baths} bathrooms and roughly {sqft:,} sq ft built-up "
        f"on {tenure.lower()} tenure. Daily needs sit close by — groceries, clinics and "
        f"eateries within a short drive — and the wider location is known for "
        f"{NEARBY[state]}. {commute.capitalize()}. Inside, {finish}. The living-dining "
        f"area can take a family sofa set; bedrooms get natural light from the front "
        f"or side elevation. Facilities vary by scheme but typically cover security "
        f"and parking. Best suited for {buyer}. Confirm title, maintenance fees and "
        f"exact measurements during viewing before locking in a loan offer."
    )


def generate(per_state: int = 24) -> list[dict]:
    now = datetime.now(timezone.utc).isoformat()
    rows: list[dict] = []
    n = 0
    for state in sorted(VALID_STATES):
        districts = STATE_DISTRICTS[state]
        for i in range(per_state):
            ptype, beds, baths, low, high, mult = TYPES[i % len(TYPES)]
            district = districts[i % len(districts)]
            sqft = _sqft(low, high, i + n)
            price = _price(state, mult, i)
            tenure = TENURES[i % 2]
            photos = "|".join(PHOTOS[(n + k) % len(PHOTOS)] for k in range(3))
            listing_id = f"seed-{STATE_CODES[state]}-{100000 + n}"
            rows.append(
                {
                    "listing_id": listing_id,
                    "price": price,
                    "property_type": ptype,
                    "bedrooms": beds,
                    "bathrooms": baths,
                    "built_up": f"{sqft:,} sq ft",
                    "full_address": f"{district}, {state}",
                    "district": district,
                    "state": state,
                    "tenure": tenure,
                    "description": _description(
                        ptype=ptype,
                        district=district,
                        state=state,
                        beds=beds,
                        baths=baths,
                        sqft=sqft,
                        price=price,
                        tenure=tenure,
                        index=n,
                    ),
                    "facilities": FACILITY_SETS[i % len(FACILITY_SETS)],
                    "photo_urls": photos,
                    "listing_url": f"https://example.invalid/listing/{listing_id}",
                    "agent_name": AGENTS[i % len(AGENTS)],
                    "lat": None,
                    "lng": None,
                    "scraped_at": now,
                }
            )
            n += 1
    return rows


def main() -> None:
    DATA_DIR.mkdir(parents=True, exist_ok=True)
    rows = generate()
    kept, dropped = filter_listings(rows)
    if dropped:
        raise SystemExit(f"seed failed quality checks: {dropped[:3]}")
    out = DATA_DIR / "clean_listings.json"
    raw = DATA_DIR / "raw_listings.json"
    payload = json.dumps(kept, indent=2, ensure_ascii=False)
    out.write_text(payload, encoding="utf-8")
    raw.write_text(payload, encoding="utf-8")
    states = sorted({r["state"] for r in kept})
    print(f"Wrote {len(kept)} listings across {len(states)} states -> {out}")


if __name__ == "__main__":
    main()
