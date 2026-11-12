#!/usr/bin/env python3
"""Serve the Flutter web build with SPA fallback.

GoRouter uses path-style URLs on web when they are available, so a plain
http.server 404s on refresh of /home, /profile, etc. This server serves
index.html for unknown paths while still returning real 404s for missing
asset files.

Usage:
    python3 scripts/serve_web.py [port] [directory]
"""
from __future__ import annotations

import http.server
import os
import socketserver
import sys

PORT = int(sys.argv[1]) if len(sys.argv) > 1 else 8080
ROOT = os.path.abspath(
    sys.argv[2]
    if len(sys.argv) > 2
    else os.path.join(os.path.dirname(__file__), "..", "app", "build", "web")
)


class SpaHandler(http.server.SimpleHTTPRequestHandler):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=ROOT, **kwargs)

    def do_GET(self):  # noqa: N802 (stdlib naming)
        path = self.translate_path(self.path)
        if os.path.isdir(path):
            index = os.path.join(path, "index.html")
            if os.path.exists(index):
                self.path = os.path.join(self.path, "index.html")
        elif not os.path.exists(path):
            # Missing asset vs missing route: keep asset 404s honest.
            looks_like_asset = os.path.splitext(self.path)[1] not in ("", ".html")
            if not looks_like_asset:
                self.path = "/index.html"
        super().do_GET()

    def end_headers(self):
        # The release build is static; avoid stale service-worker confusion in
        # local demo sessions.
        self.send_header("Cache-Control", "no-store")
        super().end_headers()


class ReusableServer(socketserver.TCPServer):
    allow_reuse_address = True


if __name__ == "__main__":
    if not os.path.exists(os.path.join(ROOT, "index.html")):
        raise SystemExit(
            f"No web build at {ROOT}. Run: cd app && flutter build web --release"
        )
    with ReusableServer(("127.0.0.1", PORT), SpaHandler) as httpd:
        print(f"NightWise web app: http://127.0.0.1:{PORT}  (root: {ROOT})")
        httpd.serve_forever()
