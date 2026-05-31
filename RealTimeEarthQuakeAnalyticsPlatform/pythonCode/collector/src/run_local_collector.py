import json
import os

from lambda_collector import lambda_handler


def main() -> None:
    event_path = os.getenv(
        "COLLECTOR_EVENT_FILE",
        os.path.join(os.path.dirname(__file__), "..", "tests", "sample_scheduler_event.json"),
    )

    with open(os.path.abspath(event_path), "r", encoding="utf-8") as fp:
        event = json.load(fp)

    result = lambda_handler(event, None)
    print(json.dumps(result, indent=2))


if __name__ == "__main__":
    main()
