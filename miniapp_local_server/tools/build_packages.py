#!/usr/bin/env python3
from __future__ import annotations

import hashlib
import json
import re
import zipfile
from datetime import datetime, timezone
from pathlib import Path


ROOT = Path(__file__).resolve().parent.parent
MANIFEST = ROOT / "miniapps.json"
MINIAPPS_DIR = ROOT / "miniapps"
PACKAGES_DIR = ROOT / "packages"


def _sanitize_filename(text: str) -> str:
    return re.sub(r"[^a-zA-Z0-9._-]+", "_", text).strip("_")


def _resolve_app_dir(app: dict) -> Path | None:
    explicit = str(app.get("source_dir", "")).strip()
    if explicit:
        p = (ROOT / explicit).resolve()
        return p if p.exists() and p.is_dir() else None

    url = str(app.get("url", "")).strip()
    if not url or "://" in url:
        return None
    rel = url.lstrip("./")
    parts = rel.split("/")
    if len(parts) < 2:
        return None
    if parts[0] != "miniapps":
        return None
    app_dir = MINIAPPS_DIR / parts[1]
    return app_dir if app_dir.exists() and app_dir.is_dir() else None


def _zip_dir(src_dir: Path, dst_zip: Path) -> None:
    if dst_zip.exists():
        dst_zip.unlink()
    with zipfile.ZipFile(dst_zip, "w", compression=zipfile.ZIP_DEFLATED) as zf:
        for file in src_dir.rglob("*"):
            if not file.is_file():
                continue
            zf.write(file, file.relative_to(src_dir))


def _sha256(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as f:
        for chunk in iter(lambda: f.read(1024 * 1024), b""):
            h.update(chunk)
    return h.hexdigest()


def main() -> int:
    if not MANIFEST.exists():
        print(f"manifest not found: {MANIFEST}")
        return 1

    with MANIFEST.open("r", encoding="utf-8") as f:
        data = json.load(f)

    apps = data.get("apps", [])
    if not isinstance(apps, list):
        print("manifest apps must be a list")
        return 1

    PACKAGES_DIR.mkdir(parents=True, exist_ok=True)
    built = 0

    for app in apps:
        if not isinstance(app, dict):
            continue
        app_id = str(app.get("id", "")).strip()
        if not app_id:
            continue

        app_dir = _resolve_app_dir(app)
        if app_dir is None:
            print(f"skip {app_id}: cannot resolve source directory")
            continue

        zip_name = f"{_sanitize_filename(app_id)}.zip"
        zip_path = PACKAGES_DIR / zip_name
        _zip_dir(app_dir, zip_path)
        app["package_url"] = f"./packages/{zip_name}"
        app["package_sha256"] = _sha256(zip_path)
        built += 1
        print(f"built: {app_id} -> {zip_name}")

    data["updated_at"] = datetime.now(timezone.utc).isoformat()
    with MANIFEST.open("w", encoding="utf-8") as f:
        json.dump(data, f, ensure_ascii=False, indent=2)
        f.write("\n")

    print(f"done. built {built} package(s).")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

