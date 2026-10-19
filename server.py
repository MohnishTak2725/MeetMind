#!/usr/bin/env python3
"""
MeetMind Cross-Platform Server (macOS / Linux / Windows)
Runs a zero-dependency HTTP server implementing the MeetMind API bridge.
"""

import os
import sys
import json
import urllib.parse
from http.server import HTTPServer, BaseHTTPRequestHandler

PORT = 3000
DIRECTORY = os.path.dirname(os.path.abspath(__file__))

feed_items = []
ask_queue = []

class MeetMindHandler(BaseHTTPRequestHandler):
    def end_headers(self):
        self.send_header('Access-Control-Allow-Origin', '*')
        self.send_header('Access-Control-Allow-Methods', 'GET, POST, OPTIONS')
        self.send_header('Access-Control-Allow-Headers', 'Content-Type')
        super().end_headers()

    def do_OPTIONS(self):
        self.send_response(200)
        self.end_headers()

    def do_GET(self):
        parsed = urllib.parse.urlparse(self.path)
        path = parsed.path

        if path == "/api/feed":
            query = urllib.parse.parse_qs(parsed.query)
            since = 0
            if "since" in query:
                try:
                    since = int(query["since"][0])
                except ValueError:
                    since = 0

            items = feed_items[since:]
            body = json.dumps({"total": len(feed_items), "items": items}).encode("utf-8")
            self.send_response(200)
            self.send_header("Content-Type", "application/json; charset=utf-8")
            self.send_header("Content-Length", str(len(body)))
            self.end_headers()
            self.wfile.write(body)
            return

        if path == "/api/ask":
            item = ask_queue.pop(0) if ask_queue else None
            body = json.dumps(item).encode("utf-8") if item else b"null"
            self.send_response(200)
            self.send_header("Content-Type", "application/json; charset=utf-8")
            self.send_header("Content-Length", str(len(body)))
            self.end_headers()
            self.wfile.write(body)
            return

        # Static files
        if path == "/" or not path:
            path = "/index.html"

        file_path = os.path.join(DIRECTORY, path.lstrip("/"))
        if os.path.isfile(file_path):
            self.send_response(200)
            if file_path.endswith(".html"):
                self.send_header("Content-Type", "text/html; charset=utf-8")
            elif file_path.endswith(".js"):
                self.send_header("Content-Type", "application/javascript")
            elif file_path.endswith(".css"):
                self.send_header("Content-Type", "text/css")
            else:
                self.send_header("Content-Type", "application/octet-stream")

            size = os.path.getsize(file_path)
            self.send_header("Content-Length", str(size))
            self.end_headers()
            with open(file_path, "rb") as f:
                self.wfile.write(f.read())
        else:
            self.send_response(404)
            self.end_headers()

    def do_POST(self):
        parsed = urllib.parse.urlparse(self.path)
        path = parsed.path
        length = int(self.headers.get("Content-Length", 0))
        raw_body = self.rfile.read(length).decode("utf-8") if length > 0 else ""

        if path == "/api/feed":
            if raw_body:
                try:
                    feed_items.append(json.loads(raw_body))
                except json.JSONDecodeError:
                    feed_items.append(raw_body)
                if len(feed_items) > 200:
                    del feed_items[:50]
            resp = b'{"status":"ok"}'
            self.send_response(200)
            self.send_header("Content-Type", "application/json; charset=utf-8")
            self.send_header("Content-Length", str(len(resp)))
            self.end_headers()
            self.wfile.write(resp)
            return

        if path == "/api/ask":
            if raw_body:
                try:
                    ask_queue.append(json.loads(raw_body))
                except json.JSONDecodeError:
                    ask_queue.append(raw_body)
            resp = b'{"status":"queued"}'
            self.send_response(200)
            self.send_header("Content-Type", "application/json; charset=utf-8")
            self.send_header("Content-Length", str(len(resp)))
            self.end_headers()
            self.wfile.write(resp)
            return

        if path == "/api/clear":
            feed_items.clear()
            resp = b'{"status":"cleared"}'
            self.send_response(200)
            self.send_header("Content-Type", "application/json; charset=utf-8")
            self.send_header("Content-Length", str(len(resp)))
            self.end_headers()
            self.wfile.write(resp)
            return

        self.send_response(404)
        self.end_headers()

    def log_message(self, format, *args):
        pass

def main():
    server_address = ('127.0.0.1', PORT)
    try:
        httpd = HTTPServer(server_address, MeetMindHandler)
        print(f"[*] MeetMind server running at http://localhost:{PORT}/")
        httpd.serve_forever()
    except OSError:
        server_address = ('127.0.0.1', PORT + 1)
        httpd = HTTPServer(server_address, MeetMindHandler)
        print(f"[*] MeetMind server running at http://localhost:{PORT + 1}/")
        httpd.serve_forever()

if __name__ == "__main__":
    main()
