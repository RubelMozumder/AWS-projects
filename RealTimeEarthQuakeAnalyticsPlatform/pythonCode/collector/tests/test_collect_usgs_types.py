
import os
import sys
import pytest
import json
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), '../src')))
from lambda_collector import collect_and_forward

def test_collect_and_forward_usgs_types(tmp_path):
    # Use a real USGS GeoJSON feed (or a sample file if offline)
    feed_url = os.getenv(
        "USGS_FEED_URL",
        "https://earthquake.usgs.gov/earthquakes/feed/v1.0/summary/all_hour.geojson",
    )
    result = collect_and_forward(
        feed_url=feed_url,
        feed_type="all_hour",
        ingest_url=None,  # dry_run mode
        api_key=None,
        timeout_seconds=10,
        dry_run=True,
        max_events=3,
    )
    # Check result structure
    assert isinstance(result, dict)
    assert "fetched_events" in result
    assert "processed_events" in result
    assert "sent_events" in result
    assert "failures" in result
    # Check types
    assert isinstance(result["fetched_events"], int)
    assert isinstance(result["processed_events"], int)
    assert isinstance(result["sent_events"], int)
    assert isinstance(result["failures"], list)
    # Optionally check features in the feed
    # (No value checks, just type/structure)
    # If you want to check the actual features, you can fetch the payload directly:
    # import urllib.request
    # payload = json.load(urllib.request.urlopen(feed_url))
    # assert "features" in payload and isinstance(payload["features"], list)
