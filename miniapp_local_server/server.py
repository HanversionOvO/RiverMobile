#!/usr/bin/env python3
"""River mini-app local server.

Features:
- Serve static mini-app files in this folder.
- Serve normalized manifest at /miniapps.json (relative URLs => absolute URLs).
- Search/list/detail APIs:
  - /api/miniapps/list
  - /api/miniapps/search?q=...
  - /api/miniapps/{id}
- Health check:
  - /health
"""

from __future__ import annotations

import argparse
import json
import re
import sys
from datetime import datetime, timezone
from http import HTTPStatus
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from typing import Any
from urllib.parse import parse_qs, unquote, urlparse


ROOT_DIR = Path(__file__).resolve().parent
MANIFEST_PATH = ROOT_DIR / "miniapps.json"
REQUEST_LOG_PATH = ROOT_DIR / "server_requests.log"


def _append_request_log(line: str) -> None:
    try:
        with REQUEST_LOG_PATH.open("a", encoding="utf-8") as f:
            f.write(line.rstrip("\n") + "\n")
    except Exception:
        pass


def _load_manifest() -> dict[str, Any]:
    if not MANIFEST_PATH.exists():
        return {"version": "1.0.0", "updated_at": "", "apps": []}
    with MANIFEST_PATH.open("r", encoding="utf-8") as f:
        raw = json.load(f)
    if not isinstance(raw, dict):
        return {"version": "1.0.0", "updated_at": "", "apps": []}
    apps = raw.get("apps")
    if not isinstance(apps, list):
        raw["apps"] = []
    return raw


def _absolutize_url(value: str, base_url: str) -> str:
    text = (value or "").strip()
    if not text:
        return ""
    if text.startswith("http://") or text.startswith("https://"):
        return text
    if text.startswith("/"):
        return f"{base_url}{text}"
    return f"{base_url}/{text}"


def _normalize_manifest(base_url: str) -> dict[str, Any]:
    raw = _load_manifest()
    apps: list[dict[str, Any]] = []
    for item in raw.get("apps", []):
        if not isinstance(item, dict):
            continue
        app = dict(item)
        app["url"] = _absolutize_url(str(app.get("url", "")), base_url)
        app["icon"] = _absolutize_url(str(app.get("icon", "")), base_url)
        if "package_url" in app:
            app["package_url"] = _absolutize_url(str(app.get("package_url", "")), base_url)
        apps.append(app)
    return {
        "version": str(raw.get("version", "1.0.0")),
        "updated_at": str(raw.get("updated_at", "")),
        "generated_at": datetime.now(timezone.utc).isoformat(),
        "apps": apps,
    }


def _filter_apps(apps: list[dict[str, Any]], query: str) -> list[dict[str, Any]]:
    q = query.strip().lower()
    if not q:
        return apps
    result: list[dict[str, Any]] = []
    for app in apps:
        tags = app.get("tags", [])
        tags_text = " ".join([str(t) for t in tags]) if isinstance(tags, list) else ""
        haystack = " ".join(
            [
                str(app.get("id", "")),
                str(app.get("name", "")),
                str(app.get("description", "")),
                tags_text,
            ]
        ).lower()
        if q in haystack:
            result.append(app)
    return result


class MiniAppRequestHandler(SimpleHTTPRequestHandler):
    protocol_version = "HTTP/1.0"

    def __init__(self, *args: Any, **kwargs: Any) -> None:
        super().__init__(*args, directory=str(ROOT_DIR), **kwargs)

    def end_headers(self) -> None:
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Methods", "GET, OPTIONS")
        self.send_header("Access-Control-Allow-Headers", "*")
        super().end_headers()

    def do_OPTIONS(self) -> None:
        self.send_response(HTTPStatus.NO_CONTENT)
        self.end_headers()

    def do_GET(self) -> None:
        parsed = urlparse(self.path)
        path = parsed.path
        query = parse_qs(parsed.query)
        base_url = f"http://{self.headers.get('Host', '')}".rstrip("/")

        if path == "/health":
            self._write_json(
                {
                    "ok": True,
                    "service": "river-miniapp-local-server",
                    "time": datetime.now(timezone.utc).isoformat(),
                }
            )
            return

        if path == "/miniapps.json":
            self._write_json(_normalize_manifest(base_url))
            return

        if path == "/api/miniapps/list":
            manifest = _normalize_manifest(base_url)
            apps = manifest.get("apps", [])
            self._write_json(
                {
                    "success": "OK",
                    "total": len(apps),
                    "apps": apps,
                }
            )
            return

        if path == "/api/miniapps/search":
            manifest = _normalize_manifest(base_url)
            apps = manifest.get("apps", [])
            q = (query.get("q") or [""])[0]
            limit = _safe_int((query.get("limit") or ["20"])[0], 20)
            filtered = _filter_apps(apps, q)[: max(1, min(limit, 200))]
            self._write_json(
                {
                    "success": "OK",
                    "query": q,
                    "total": len(filtered),
                    "apps": filtered,
                }
            )
            return

        match = re.fullmatch(r"/api/miniapps/([^/]+)", path)
        if match:
            app_id = unquote(match.group(1))
            manifest = _normalize_manifest(base_url)
            for app in manifest.get("apps", []):
                if str(app.get("id", "")) == app_id:
                    self._write_json({"success": "OK", "app": app})
                    return
            self._write_json({"success": "NOT_FOUND"}, status=HTTPStatus.NOT_FOUND)
            return

        if path.startswith("/packages/"):
            self._serve_package(path)
            return

        super().do_GET()

    def _write_json(self, body: dict[str, Any], status: HTTPStatus = HTTPStatus.OK) -> None:
        data = json.dumps(body, ensure_ascii=False, separators=(",", ":")).encode("utf-8")
        self.send_response(int(status))
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(data)))
        self.send_header("Cache-Control", "no-store")
        self.end_headers()
        self.wfile.write(data)

    def log_message(self, format: str, *args: Any) -> None:
        # Keep log concise.
        text = "%s - - [%s] %s\n" % (
            self.client_address[0],
            self.log_date_time_string(),
            format % args,
        )
        sys.stdout.write(text)
        _append_request_log(text)

    def _serve_package(self, request_path: str) -> None:
        rel = request_path.lstrip("/")
        file_path = (ROOT_DIR / rel).resolve()
        root = ROOT_DIR.resolve()
        if root not in file_path.parents and file_path != root:
            self.send_error(HTTPStatus.FORBIDDEN, "Forbidden")
            return
        if not file_path.exists() or not file_path.is_file():
            self.send_error(HTTPStatus.NOT_FOUND, "File not found")
            return

        try:
            file_size = file_path.stat().st_size
            start = 0
            end = file_size - 1
            status = HTTPStatus.OK
            range_header = (self.headers.get("Range") or "").strip()
            if range_header:
                parsed = self._parse_range_header(range_header=range_header, file_size=file_size)
                if parsed is None:
                    self.send_response(HTTPStatus.REQUESTED_RANGE_NOT_SATISFIABLE)
                    self.send_header("Content-Range", f"bytes */{file_size}")
                    self.send_header("Connection", "close")
                    self.end_headers()
                    return
                start, end = parsed
                status = HTTPStatus.PARTIAL_CONTENT

            self.send_response(status)
            self.send_header("Content-Type", "application/zip")
            self.send_header("Accept-Ranges", "bytes")
            content_length = (end - start) + 1
            self.send_header("Content-Length", str(content_length))
            if status == HTTPStatus.PARTIAL_CONTENT:
                self.send_header("Content-Range", f"bytes {start}-{end}/{file_size}")
            self.send_header("Cache-Control", "no-store")
            self.send_header("Connection", "close")
            self.end_headers()

            sent = 0
            with file_path.open("rb") as f:
                f.seek(start)
                remain = content_length
                while remain > 0:
                    chunk = f.read(64 * 1024)
                    if not chunk:
                        break
                    if len(chunk) > remain:
                        chunk = chunk[:remain]
                    self.wfile.write(chunk)
                    remain -= len(chunk)
                    sent += len(chunk)
                self.wfile.flush()
            self.log_message(
                'PKG "%s" %s range=%s-%s/%s sent=%s',
                rel,
                int(status),
                start,
                end,
                file_size,
                sent,
            )
        except (ConnectionResetError, ConnectionAbortedError, BrokenPipeError, TimeoutError, OSError) as error:
            # Client disconnected during transfer.
            self.log_message('PKG "%s" aborted: %s', rel, error)
            return
        except Exception:
            self.send_error(HTTPStatus.INTERNAL_SERVER_ERROR, "Read file failed")

    def _parse_range_header(self, range_header: str, file_size: int) -> tuple[int, int] | None:
        match = re.match(r"^bytes=(\d*)-(\d*)$", range_header)
        if match is None:
            return None
        start_raw = match.group(1)
        end_raw = match.group(2)
        if not start_raw and not end_raw:
            return None

        if not start_raw:
            # suffix range: bytes=-500
            suffix = int(end_raw)
            if suffix <= 0:
                return None
            if suffix >= file_size:
                return (0, file_size - 1)
            return (file_size - suffix, file_size - 1)

        start = int(start_raw)
        end = int(end_raw) if end_raw else file_size - 1
        if start >= file_size:
            return None
        if end < start:
            return None
        end = min(end, file_size - 1)
        return (start, end)


def _safe_int(value: str, fallback: int) -> int:
    try:
        return int(value)
    except Exception:
        return fallback


class RiverThreadingHTTPServer(ThreadingHTTPServer):
    daemon_threads = True
    allow_reuse_address = True


def _parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Run River mini-app local server.")
    parser.add_argument("--host", default="0.0.0.0", help="Bind host, default: 0.0.0.0")
    parser.add_argument("--port", type=int, default=8765, help="Bind port, default: 8765")
    return parser.parse_args()


def main() -> None:
    args = _parse_args()
    server = RiverThreadingHTTPServer((args.host, args.port), MiniAppRequestHandler)
    server.request_queue_size = 128
    print(f"[miniapp-server] serving {ROOT_DIR}")
    print(f"[miniapp-server] http://127.0.0.1:{args.port}/miniapps.json")
    print("[miniapp-server] press Ctrl+C to stop")
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        pass
    finally:
        server.server_close()


if __name__ == "__main__":
    main()
