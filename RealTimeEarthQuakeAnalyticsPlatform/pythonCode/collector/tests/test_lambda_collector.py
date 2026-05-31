import os
import sys
import unittest
from pathlib import Path
from unittest.mock import patch


SRC_DIR = Path(__file__).resolve().parent.parent / "src"
if str(SRC_DIR) not in sys.path:
    sys.path.insert(0, str(SRC_DIR))

from lambda_collector import lambda_handler  # noqa: E402


class TestLambdaCollector(unittest.TestCase):
    """
    Unit tests for the lambda_handler contract and config parsing.
    """
    @patch("lambda_collector.collect_and_forward")
    def test_lambda_handler_requires_ingest_url_when_not_dry_run(self, _mock_collect):
        """
        Should raise ValueError if ingest_url is missing and not in dry_run mode.
        """
        event = {
            "feed_type": "all_hour",
            "dry_run": False,
            "timeout_seconds": 5,
        }

        with self.assertRaises(ValueError) as ctx:
            lambda_handler(event, None)

        self.assertIn("ingest_url missing", str(ctx.exception))

    @patch("lambda_collector.collect_and_forward")
    def test_lambda_handler_allows_dry_run_without_ingest_url(self, mock_collect):
        """
        Should allow dry_run mode even if ingest_url is missing.
        """
        mock_collect.return_value = {
            "feed_url": "https://earthquake.usgs.gov/earthquakes/feed/v1.0/summary/all_hour.geojson",
            "feed_type": "all_hour",
            "mode": "dry_run",
            "fetched_events": 2,
            "processed_events": 2,
            "sent_events": 2,
            "failed_events": 0,
            "failures": [],
        }

        event = {
            "feed_type": "all_hour",
            "dry_run": True,
            "max_events": 2,
            "timeout_seconds": 5,
        }

        result = lambda_handler(event, None)
        self.assertEqual(result["mode"], "dry_run")
        mock_collect.assert_called_once()

        kwargs = mock_collect.call_args.kwargs
        self.assertTrue(kwargs["dry_run"])
        self.assertEqual(kwargs["max_events"], 2)
        self.assertIsNone(kwargs["ingest_url"])

    @patch.dict(os.environ, {"INGEST_API_URL": "http://localhost:8080/ingest"}, clear=False)
    @patch("lambda_collector.collect_and_forward")
    def test_lambda_handler_reads_ingest_url_from_environment(self, mock_collect):
        """
        Should read ingest_url from environment variable if not in event.
        """
        mock_collect.return_value = {
            "feed_url": "https://earthquake.usgs.gov/earthquakes/feed/v1.0/summary/all_hour.geojson",
            "feed_type": "all_hour",
            "mode": "forward",
            "fetched_events": 1,
            "processed_events": 1,
            "sent_events": 1,
            "failed_events": 0,
            "failures": [],
        }

        event = {
            "feed_type": "all_hour",
            "dry_run": False,
            "max_events": 1,
            "timeout_seconds": 5,
        }

        result = lambda_handler(event, None)
        self.assertEqual(result["mode"], "forward")

        kwargs = mock_collect.call_args.kwargs
        self.assertEqual(kwargs["ingest_url"], "http://localhost:8080/ingest")


if __name__ == "__main__":
    unittest.main()
