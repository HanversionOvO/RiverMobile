#!/usr/bin/env python3
from __future__ import annotations

import hashlib
import json
import re
import sys
import zipfile
from pathlib import Path


ROOT = Path(__file__).resolve().parent.parent
MANIFEST = ROOT / "miniapps.json"
SEMVER = re.compile(r"^\d+\.\d+\.\d+(?:-[0-9A-Za-z.-]+)?(?:\+[0-9A-Za-z.-]+)?$")


def _sha256(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as f:
        for chunk in iter(lambda: f.read(1024 * 1024), b""):
            h.update(chunk)
    return h.hexdigest()


def _is_relative_url(url: str) -> bool:
    return "://" not in url


def _to_local_path(url: str) -> Path:
    return ROOT / url.lstrip("./")


def main() -> int:
    errors: list[str] = []
    warnings: list[str] = []

    if not MANIFEST.exists():
        print(f"ERROR: manifest not found: {MANIFEST}")
        return 1

    with MANIFEST.open("r", encoding="utf-8") as f:
        data = json.load(f)

    if not isinstance(data, dict):
        print("ERROR: manifest must be an object")
        return 1

    version = str(data.get("version", "")).strip()
    if not version or not SEMVER.match(version):
        errors.append("manifest.version is required and must be semver")

    apps = data.get("apps")
    if not isinstance(apps, list):
        errors.append("manifest.apps must be a list")
        apps = []

    seen_ids: set[str] = set()
    seen_orders: set[int] = set()
    required_fields = ["id", "name", "version", "url", "icon", "package_url", "bridge_version"]

    for i, app in enumerate(apps):
        if not isinstance(app, dict):
            errors.append(f"apps[{i}] must be an object")
            continue

        for field in required_fields:
            value = str(app.get(field, "")).strip()
            if not value:
                errors.append(f"apps[{i}].{field} is required")

        app_id = str(app.get("id", "")).strip()
        if app_id:
            if app_id in seen_ids:
                errors.append(f"duplicate app id: {app_id}")
            seen_ids.add(app_id)

        app_ver = str(app.get("version", "")).strip()
        if app_ver and not SEMVER.match(app_ver):
            errors.append(f"apps[{i}].version is not semver: {app_ver}")

        order = app.get("order")
        if isinstance(order, int):
            if order in seen_orders:
                warnings.append(f"duplicate order value: {order}")
            seen_orders.add(order)
        else:
            warnings.append(f"apps[{i}].order should be int")

        url = str(app.get("url", "")).strip()
        if url and _is_relative_url(url):
            local = _to_local_path(url)
            if not local.exists():
                errors.append(f"apps[{i}].url local file not found: {url}")

        icon = str(app.get("icon", "")).strip()
        if icon and _is_relative_url(icon):
            local = _to_local_path(icon)
            if not local.exists():
                errors.append(f"apps[{i}].icon local file not found: {icon}")

        package_url = str(app.get("package_url", "")).strip()
        if package_url and _is_relative_url(package_url):
            pkg = _to_local_path(package_url)
            if not pkg.exists():
                errors.append(f"apps[{i}].package_url local file not found: {package_url}")
            else:
                sha = str(app.get("package_sha256", "")).strip().lower()
                if sha:
                    actual = _sha256(pkg)
                    if sha != actual:
                        errors.append(
                            f"apps[{i}].package_sha256 mismatch: expected={sha} actual={actual}"
                        )
                try:
                    with zipfile.ZipFile(pkg, "r") as zf:
                        names = set(zf.namelist())
                        if "index.html" not in names:
                            warnings.append(
                                f"apps[{i}] package has no root index.html: {package_url}"
                            )
                except Exception as exc:
                    errors.append(f"apps[{i}] invalid zip package: {package_url} ({exc})")

    if warnings:
        print("WARNINGS:")
        for w in warnings:
            print(f"  - {w}")

    if errors:
        print("ERRORS:")
        for e in errors:
            print(f"  - {e}")
        return 1

    print("manifest validation passed.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

