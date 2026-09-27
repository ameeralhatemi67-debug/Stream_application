"""Static SPA server for local G0/acceptance checks (localhost only).

Serves a Flutter web build; unknown paths fall back to index.html like the
production Vercel rewrite. Logs every request so evidence can show which
URLs the app fetched. Usage: python spa_server.py <build/web> <port> <log>
"""
import http.server
import os
import sys
from functools import partial

root, port, log_path = sys.argv[1], int(sys.argv[2]), sys.argv[3]
log = open(log_path, "a", encoding="utf-8", buffering=1)


class Handler(http.server.SimpleHTTPRequestHandler):
    def send_head(self):
        path = self.translate_path(self.path)
        if not os.path.exists(path):
            self.path = "/index.html"
        return super().send_head()

    def end_headers(self):
        self.send_header("Cache-Control", "no-cache")
        super().end_headers()

    def log_message(self, fmt, *args):
        log.write("%s %s\n" % (self.log_date_time_string(), fmt % args))


http.server.ThreadingHTTPServer(("127.0.0.1", port), partial(Handler, directory=root)).serve_forever()
