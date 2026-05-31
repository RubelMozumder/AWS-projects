import sys
import unittest
from pathlib import Path
from unittest.mock import patch

SRC_DIR = Path(__file__).resolve().parent.parent / "src"
if str(SRC_DIR) not in sys.path:
    sys.path.insert(0, str(SRC_DIR))

from lambda_collector import collect_and_forward


class TestCollectAndForward(unittest.TestCase):
    """
    Unit tests for collect_and_forward logic, including dry-run and error handling.
    """
    @patch("lambda_collector._get_usgs_payload")
    @patch("lambda_collector._post_ingest_record")
    def test_forward_success_and_failure(self, mock_post, mock_usgs):
        """
        Should count sent/failed events correctly and report failures.
        """
        # Simulate 3 features, 2 succeed, 1 fails
        mock_usgs.return_value = {
            "features": [
                {"id": "eq1", "properties": {"mag": 4.0}},
                {"id": "eq2", "properties": {"mag": 5.0}},
                {"id": "eq3", "properties": {"mag": 6.0}},
            ]
        }
        # First two succeed, last fails
        mock_post.side_effect = [(True, None), (True, None), (False, "HTTP 500")]

        result = collect_and_forward(
            feed_url="dummy-url",
            feed_type="all_hour",
            ingest_url="http://localhost:8080/ingest",
            api_key=None,
            timeout_seconds=5,
            dry_run=False,
            max_events=0,
        )
        self.assertEqual(result["fetched_events"], 3)
        self.assertEqual(result["processed_events"], 3)
        self.assertEqual(result["sent_events"], 2)
        self.assertEqual(result["failed_events"], 1)
        self.assertEqual(result["failures"][0]["event_id"], "eq3")
        self.assertIn("HTTP 500", result["failures"][0]["reason"])

    @patch("lambda_collector._get_usgs_payload")
    def test_dry_run_mode(self, mock_usgs):
        """
        Should process events in dry_run mode without calling ingest POST.
        """
        mock_usgs.return_value = {
            "features": [
                {"id": "eq1"},
                {"id": "eq2"},
                {"id": "eq3"},
            ]
        }
        result = collect_and_forward(
            feed_url="dummy-url",
            feed_type="all_hour",
            ingest_url=None,
            api_key=None,
            timeout_seconds=5,
            dry_run=True,
            max_events=2,
        )
        self.assertEqual(result["mode"], "dry_run")
        self.assertEqual(result["processed_events"], 2)
        self.assertEqual(result["sent_events"], 2)
        self.assertEqual(result["failed_events"], 0)


if __name__ == "__main__":
    unittest.main()
