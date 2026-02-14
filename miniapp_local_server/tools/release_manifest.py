#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import subprocess
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parent.parent
MANIFEST = ROOT / "miniapps.json"
BUILD_SCRIPT = ROOT / "tools" / "build_packages.py"
VALIDATE_SCRIPT = ROOT / "tools" / "validate_manifest.py"


def _run_script(path: Path) -> int:
    cmd = [sys.executable, str(path)]
    completed = subprocess.run(cmd, cwd=str(ROOT))
    return int(completed.returncode)


def _bump_semver(version: str, level: str) -> str:
    parts = version.strip().split(".")
    if len(parts) != 3:
        raise ValueError(f"invalid semver: {version}")
    major, minor, patch = [int(p) for p in parts]
    if level == "major":
        major += 1
        minor = 0
        patch = 0
    elif level == "minor":
        minor += 1
        patch = 0
    else:
        patch += 1
    return f"{major}.{minor}.{patch}"


def _update_manifest_version(level: str) -> str:
    with MANIFEST.open("r", encoding="utf-8") as f:
        data = json.load(f)
    current = str(data.get("version", "1.0.0")).strip() or "1.0.0"
    next_version = _bump_semver(current, level)
    data["version"] = next_version
    with MANIFEST.open("w", encoding="utf-8") as f:
        json.dump(data, f, ensure_ascii=False, indent=2)
        f.write("\n")
    return next_version


def _parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Bump manifest version, build packages, and validate.")
    parser.add_argument(
        "--bump",
        choices=["major", "minor", "patch"],
        default="patch",
        help="SemVer bump level for manifest.version (default: patch)",
    )
    parser.add_argument(
        "--no-bump",
        action="store_true",
        help="Skip version bump and only run build + validate",
    )
    return parser.parse_args()


def main() -> int:
    if not MANIFEST.exists():
        print(f"manifest not found: {MANIFEST}")
        return 1

    args = _parse_args()
    if not args.no_bump:
        try:
            new_version = _update_manifest_version(args.bump)
            print(f"manifest version bumped to: {new_version}")
        except Exception as exc:
            print(f"failed to bump manifest version: {exc}")
            return 1

    print("running package build...")
    if _run_script(BUILD_SCRIPT) != 0:
        return 1

    print("running manifest validation...")
    if _run_script(VALIDATE_SCRIPT) != 0:
        return 1

    print("release pipeline done.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
