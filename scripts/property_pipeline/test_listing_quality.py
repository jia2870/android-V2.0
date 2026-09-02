"""Smoke tests for listing ingest guards."""

from listing_quality import filter_listings, parse_built_up_sqft, validate_listing


def test_rejects_huge_apartment_sqft():
    row = {
        "listing_id": "x1",
        "state": "Selangor",
        "district": "Kajang",
        "price": 500000,
        "property_type": "Apartment",
        "built_up": "80,000 sq ft",
        "description": "x" * 220,
        "photo_urls": "https://images.unsplash.com/photo-1",
    }
    assert any("implausible built_up" in r for r in validate_listing(row))


def test_keeps_normal_terrace():
    row = {
        "listing_id": "x2",
        "state": "Johor",
        "district": "Skudai",
        "price": 480000,
        "property_type": "2-storey Terraced House",
        "built_up": "1,418 sq ft",
        "description": (
            "This 2-storey terraced house in Skudai, Johor is listed at about RM 480,000 "
            "with 4 bedrooms, 3 bathrooms and roughly 1,418 sq ft built-up on freehold tenure. "
            "Daily needs sit close by — groceries, clinics and eateries within a short drive. "
            "Confirm title, maintenance fees and exact measurements during viewing before "
            "locking in a loan offer for this family home."
        ),
        "photo_urls": "https://images.unsplash.com/photo-1",
    }
    assert validate_listing(row) == []


def test_parse_sqm():
    assert abs(parse_built_up_sqft("93 sq m") - 1000) < 20


def test_drops_template_and_bad_state():
    rows = [
        {
            "listing_id": "bad",
            "state": "Mars",
            "district": "x",
            "price": 100000,
            "property_type": "Apartment",
            "built_up": "800 sq ft",
            "description": "intentionally complete " + "y" * 200,
            "photo_urls": "https://example.com/a.jpg",
        }
    ]
    kept, dropped = filter_listings(rows)
    assert kept == []
    assert dropped


if __name__ == "__main__":
    test_rejects_huge_apartment_sqft()
    test_keeps_normal_terrace()
    test_parse_sqm()
    test_drops_template_and_bad_state()
    print("listing_quality tests passed")
