import json
from http.server import BaseHTTPRequestHandler, HTTPServer


class IngestHandler(BaseHTTPRequestHandler):
    posted_count = 0

    def do_POST(self):
        if self.path != "/ingest":
            self.send_response(404)
            self.end_headers()
            return

        content_length = int(self.headers.get("Content-Length", "0"))
        body = self.rfile.read(content_length).decode("utf-8")
        try:
            payload = json.loads(body)
        except json.JSONDecodeError:
            self.send_response(400)
            self.end_headers()
            self.wfile.write(b"invalid json")
            return

        IngestHandler.posted_count += 1
        event_id = payload.get("event_id", "unknown")
        print(f"[{IngestHandler.posted_count}] received event_id={event_id}")

        self.send_response(202)
        self.send_header("Content-Type", "application/json")
        self.end_headers()
        self.wfile.write(json.dumps({"status": "accepted"}).encode("utf-8"))

    def log_message(self, format, *args):
        return


def run_server(port: int = 8080):
    server = HTTPServer(("0.0.0.0", port), IngestHandler)
    print(f"Local ingest stub listening on http://0.0.0.0:{port}/ingest")
    server.serve_forever()


if __name__ == "__main__":
    run_server()
