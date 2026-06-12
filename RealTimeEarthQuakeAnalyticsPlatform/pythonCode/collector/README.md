# Collector Lambda (Local + AWS)

This collector fetches USGS GeoJSON events and forwards each event to the ingestion endpoint.
It is designed to run both locally and as an AWS Lambda handler.

## Files

- `requirements.txt` - collector dependencies (minimal)
- `src/lambda_collector.py` - Lambda handler and core collector logic
- `src/local_stub_server.py` - Local `/ingest` stub endpoint for testing
- `src/run_local_collector.py` - Local runner that loads a sample event
- `tests/sample_scheduler_event.json` - Example scheduler payload
- `tests/test_lambda_collector.py` - unit tests for collector contract

## Runtime Contract

Handler:

- `lambda_collector.lambda_handler`

Input event fields:

- `feed_url` (optional)
- `feed_type` (optional)
- `ingest_url` (required unless `dry_run=true`)
- `api_key` (optional)
- `timeout_seconds` (optional, integer)
- `max_events` (optional, integer; `0` means all)
- `dry_run` (optional, boolean)

Environment fallback variables:

- `USGS_FEED_URL`
- `USGS_FEED_TYPE`
- `INGEST_API_URL`
- `INGEST_API_KEY`
- `HTTP_TIMEOUT_SECONDS`
- `COLLECTOR_MAX_EVENTS`
- `COLLECTOR_DRY_RUN`
- `COLLECTOR_USER_AGENT`

## Local Test (project venv)

From `RealTimeEarthQuakeAnalyticsPlatform`:

```bash
source .venv/bin/activate
cd pythonCode/collector/src
python local_stub_server.py
```

Open a second terminal:

```bash
source .venv/bin/activate
cd pythonCode/collector/src
python run_local_collector.py
```

## Dry-Run Test (no ingest endpoint required)

```bash
source .venv/bin/activate
cd pythonCode/collector/src
COLLECTOR_DRY_RUN=true COLLECTOR_MAX_EVENTS=3 INGEST_API_URL= \
python -c "from lambda_collector import lambda_handler; print(lambda_handler({'feed_type':'all_hour'}, None))"
```

## Unit Tests

```bash
source .venv/bin/activate
cd pythonCode/collector
python -m unittest tests/test_lambda_collector.py -v
```

## Packaging

The collector currently uses only Python standard library dependencies.
You can package this source directly for Lambda zip deployment.
