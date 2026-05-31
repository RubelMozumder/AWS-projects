import json
import logging
import os
import urllib.error
import urllib.request
from datetime import datetime, timezone
from typing import Any, Dict, List, Optional, Tuple

logger = logging.getLogger()
if not logger.handlers:
    logging.basicConfig(level=logging.INFO)
logger.setLevel(logging.INFO)

DEFAULT_TIMEOUT_SECONDS = 10
DEFAULT_USER_AGENT = "eq-analytics-collector/1.0"


def _resolve_setting(
    event: Dict[str, Any],
    key: str,
    env_key: str,
    default: Optional[str] = None,
) -> Optional[str]:
    """
    Resolve a string setting from the event, environment, or default.
    Priority: event[key] > os.environ[env_key] > default.
    """
    value = event.get(key)
    if isinstance(value, str) and value.strip():
        return value.strip()

    env_value = os.getenv(env_key)
    if isinstance(env_value, str) and env_value.strip():
        return env_value.strip()

    return default


def _resolve_int_setting(
    event: Dict[str, Any],
    key: str,
    env_key: str,
    default: int,
    minimum: int = 1,
) -> int:
    """
    Resolve an integer setting from event, environment, or default, enforcing a minimum value.
    """
    value = event.get(key)
    if value is None:
        value = os.getenv(env_key, str(default))

    try:
        parsed = int(value)
    except (TypeError, ValueError) as exc:
        raise ValueError(f"{key} must be an integer") from exc

    return max(minimum, parsed)


def _resolve_bool_setting(
    event: Dict[str, Any],
    key: str,
    env_key: str,
    default: bool = False,
) -> bool:
    """
    Resolve a boolean setting from event, environment, or default.
    Accepts common string representations of true/false.
    """
    value = event.get(key)
    if value is None:
        value = os.getenv(env_key, str(default).lower())

    if isinstance(value, bool):
        return value
    if isinstance(value, str):
        return value.strip().lower() in {"1", "true", "yes", "on"}
    return bool(value)


def _get_usgs_payload(feed_url: str, timeout_seconds: int) -> Dict[str, Any]:
    """
    Fetch the USGS GeoJSON feed and return the parsed JSON payload.
    Raises on HTTP or parsing errors.
    """
    request = urllib.request.Request(
        feed_url,
        headers={"User-Agent": os.getenv("COLLECTOR_USER_AGENT", DEFAULT_USER_AGENT)},
    )

    with urllib.request.urlopen(request, timeout=timeout_seconds) as response:
        status = getattr(response, "status", None)
        if status is not None and status >= 400:
            raise RuntimeError(f"USGS request failed with status {status}")

        body = response.read().decode("utf-8")
        return json.loads(body)


def _post_ingest_record(
    ingest_url: str,
    api_key: Optional[str],
    record: Dict[str, Any],
    timeout_seconds: int,
) -> Tuple[bool, Optional[str]]:
    """
    POST a single record to the ingestion endpoint.
    Returns (success, error_reason_if_any).
    """
    payload = json.dumps(record).encode("utf-8")
    headers = {"Content-Type": "application/json"}
    if api_key:
        headers["x-api-key"] = api_key

    request = urllib.request.Request(
        ingest_url,
        data=payload,
        headers=headers,
        method="POST",
    )

    try:
        with urllib.request.urlopen(request, timeout=timeout_seconds) as response:
            status = getattr(response, "status", 200)
            if 200 <= status < 300:
                return True, None
            return False, f"HTTP {status}"
    except urllib.error.HTTPError as exc:
        return False, f"HTTPError {exc.code}: {exc.reason}"
    except urllib.error.URLError as exc:
        return False, f"URLError: {exc.reason}"
    except TimeoutError:
        return False, "TimeoutError"


def _build_ingest_record(
    feature: Dict[str, Any],
    feed_type: str,
    feed_url: str,
) -> Dict[str, Any]:
    """
    Build the payload to send to the ingestion endpoint for a single USGS feature.
    """
    return {
        "source": "usgs",
        "feed_type": feed_type,
        "feed_url": feed_url,
        "event_id": feature.get("id"),
        "fetched_at_utc": datetime.now(timezone.utc).isoformat(),
        "feature": feature,
    }


def collect_and_forward(
    feed_url: str,
    feed_type: str,
    ingest_url: Optional[str],
    api_key: Optional[str],
    timeout_seconds: int,
    dry_run: bool,
    max_events: int,
) -> Dict[str, Any]:
    """
    Fetch USGS events and forward each to the ingestion endpoint, or simulate in dry-run mode.
    Returns a summary dict of the operation.
    """
    usgs_payload = _get_usgs_payload(feed_url, timeout_seconds)
    features: List[Dict[str, Any]] = usgs_payload.get("features", [])
    limited_features = features[:max_events] if max_events > 0 else features

    sent_count = 0
    failed_count = 0
    failures: List[Dict[str, str]] = []
    mode = "dry_run" if dry_run else "forward"

    for feature in limited_features:
        event_id = str(feature.get("id", "unknown"))
        ingest_record = _build_ingest_record(feature, feed_type, feed_url)
        if dry_run:
            sent_count += 1
            continue

        ok, reason = _post_ingest_record(
            ingest_url=ingest_url or "",
            api_key=api_key,
            record=ingest_record,
            timeout_seconds=timeout_seconds,
        )

        if ok:
            sent_count += 1
        else:
            failed_count += 1
            failures.append({"event_id": event_id, "reason": reason or "unknown"})

    return {
        "feed_url": feed_url,
        "feed_type": feed_type,
        "mode": mode,
        "fetched_events": len(features),
        "processed_events": len(limited_features),
        "sent_events": sent_count,
        "failed_events": failed_count,
        "failures": failures[:20],
    }


def lambda_handler(event: Dict[str, Any], context: Any) -> Dict[str, Any]:
    """
    AWS Lambda handler for the collector.
    Reads config from event and environment, fetches USGS feed, and forwards events.
    Returns a summary dict.
    """
    event = event or {}

    feed_url = _resolve_setting(
        event=event,
        key="feed_url",
        env_key="USGS_FEED_URL",
        default="https://earthquake.usgs.gov/earthquakes/feed/v1.0/summary/all_hour.geojson",
    )
    feed_type = _resolve_setting(
        event=event,
        key="feed_type",
        env_key="USGS_FEED_TYPE",
        default="all_hour",
    )
    ingest_url = _resolve_setting(
        event=event,
        key="ingest_url",
        env_key="INGEST_API_URL",
        default=None,
    )
    api_key = _resolve_setting(
        event=event,
        key="api_key",
        env_key="INGEST_API_KEY",
        default=None,
    )
    dry_run = _resolve_bool_setting(
        event=event,
        key="dry_run",
        env_key="COLLECTOR_DRY_RUN",
        default=False,
    )
    max_events = _resolve_int_setting(
        event=event,
        key="max_events",
        env_key="COLLECTOR_MAX_EVENTS",
        default=0,
        minimum=0,
    )

    timeout_seconds = _resolve_int_setting(
        event=event,
        key="timeout_seconds",
        env_key="HTTP_TIMEOUT_SECONDS",
        default=DEFAULT_TIMEOUT_SECONDS,
        minimum=1,
    )

    if not ingest_url and not dry_run:
        raise ValueError("ingest_url missing: set event.ingest_url or INGEST_API_URL")

    logger.info(
        "Collector invocation feed_type=%s feed_url=%s ingest_url=%s dry_run=%s max_events=%s\n",
        feed_type,
        feed_url,
        ingest_url,
        dry_run,
        max_events,
    )

    result = collect_and_forward(
        feed_url=feed_url,
        feed_type=feed_type or "all_hour",
        ingest_url=ingest_url,
        api_key=api_key,
        timeout_seconds=timeout_seconds,
        dry_run=dry_run,
        max_events=max_events,
    )

    logger.info("Collector summary: %s", json.dumps(result))
    return result


