#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import re
import shutil
import subprocess
import sys
from pathlib import Path
from typing import Any


ROOT = Path(__file__).resolve().parent.parent
MANIFEST_PATH = ROOT / "miniapps.json"
MINIAPPS_DIR = ROOT / "miniapps"
BUILD_SCRIPT = ROOT / "tools" / "build_packages.py"
VALIDATE_SCRIPT = ROOT / "tools" / "validate_manifest.py"


def _sanitize_name(value: str) -> str:
    return re.sub(r"[^a-zA-Z0-9._-]+", "_", value).strip("_")


def _load_json(path: Path) -> dict[str, Any]:
    with path.open("r", encoding="utf-8") as f:
        data = json.load(f)
    if not isinstance(data, dict):
        raise ValueError(f"invalid json object: {path}")
    return data


def _write_json(path: Path, data: dict[str, Any]) -> None:
    with path.open("w", encoding="utf-8") as f:
        json.dump(data, f, ensure_ascii=False, indent=2)
        f.write("\n")


def _detect_package_manager(project_dir: Path) -> str:
    if (project_dir / "pnpm-lock.yaml").exists():
        return "pnpm"
    if (project_dir / "yarn.lock").exists():
        return "yarn"
    return "npm"


def _detect_framework(package_json: dict[str, Any]) -> str:
    deps = package_json.get("dependencies", {})
    dev_deps = package_json.get("devDependencies", {})
    all_keys = set()
    if isinstance(deps, dict):
        all_keys.update(str(k) for k in deps.keys())
    if isinstance(dev_deps, dict):
        all_keys.update(str(k) for k in dev_deps.keys())

    if "vue" in all_keys:
        return "vue"
    if "react" in all_keys:
        return "react"
    return "unknown"


def _detect_dist_dir(project_dir: Path, framework: str, package_json: dict[str, Any]) -> Path:
    scripts = package_json.get("scripts", {})
    build_cmd = ""
    if isinstance(scripts, dict):
        build_cmd = str(scripts.get("build", ""))

    if framework == "react":
        if "react-scripts build" in build_cmd:
            return project_dir / "build"
        return project_dir / "dist"
    return project_dir / "dist"


def _run_cmd(command: str, cwd: Path) -> int:
    print(f"[run] {command} (cwd={cwd})")
    completed = subprocess.run(command, cwd=str(cwd), shell=True)
    return int(completed.returncode)


def _resolve_icon(
    icon_file: str | None,
    project_dir: Path,
    copied_dir: Path,
    keep_existing_icon_path: str,
) -> str:
    if icon_file:
        src = Path(icon_file)
        if not src.is_absolute():
            src = (project_dir / src).resolve()
        if not src.exists() or not src.is_file():
            raise FileNotFoundError(f"icon file not found: {src}")
        ext = src.suffix.lower() or ".png"
        dst_name = f"icon{ext}"
        dst = copied_dir / dst_name
        shutil.copy2(src, dst)
        return f"./miniapps/{copied_dir.name}/{dst_name}"

    for ext in (".png", ".jpg", ".jpeg", ".webp"):
        candidate = copied_dir / f"icon{ext}"
        if candidate.exists():
            return f"./miniapps/{copied_dir.name}/{candidate.name}"

    if keep_existing_icon_path:
        return keep_existing_icon_path
    return ""


def _upsert_manifest_app(
    data: dict[str, Any],
    app_id: str,
    app_name: str,
    app_version: str,
    target_dir_name: str,
    entry_file: str,
    icon_path: str,
    description: str,
    tags: list[str],
    order: int | None,
) -> None:
    apps = data.get("apps")
    if not isinstance(apps, list):
        apps = []
        data["apps"] = apps

    existing: dict[str, Any] | None = None
    for item in apps:
        if isinstance(item, dict) and str(item.get("id", "")).strip() == app_id:
            existing = item
            break

    if existing is None:
        existing = {}
        apps.append(existing)

    max_order = max(
        [int(x.get("order")) for x in apps if isinstance(x, dict) and isinstance(x.get("order"), int)],
        default=0,
    )
    existing_order = existing.get("order")
    if isinstance(existing_order, int):
        fallback_order = existing_order
    else:
        fallback_order = max_order + 1
    resolved_order = order if order is not None else fallback_order

    existing["id"] = app_id
    existing["name"] = app_name
    existing["version"] = app_version
    existing["url"] = f"./miniapps/{target_dir_name}/{entry_file}"
    if icon_path:
        existing["icon"] = icon_path
    existing["description"] = description
    existing["requires_auth"] = bool(existing.get("requires_auth", False))
    existing["enabled"] = bool(existing.get("enabled", True))
    existing["order"] = resolved_order
    existing["bridge_version"] = str(existing.get("bridge_version", "1.0.0"))
    existing["tags"] = tags


def _parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Build Vue/React scaffold app and import it as River mini-app."
    )
    parser.add_argument("--project", required=True, help="Scaffold project path")
    parser.add_argument("--app-id", required=True, help="Mini-app id, e.g. org.my_app")
    parser.add_argument("--name", required=True, help="Mini-app display name")
    parser.add_argument("--framework", choices=["auto", "vue", "react"], default="auto")
    parser.add_argument("--target-dir", default="", help="Target folder under miniapps/, default from app-id")
    parser.add_argument("--entry-file", default="index.html", help="Entry file name in target folder")
    parser.add_argument("--dist-dir", default="", help="Build output directory (absolute or relative to project)")
    parser.add_argument("--icon-file", default="", help="Icon file path (absolute or relative to project)")
    parser.add_argument("--description", default="", help="Mini-app description")
    parser.add_argument("--tags", default="", help="Comma-separated tags")
    parser.add_argument("--version", default="1.0.0", help="Mini-app version (SemVer)")
    parser.add_argument("--order", type=int, default=None, help="Display order")
    parser.add_argument("--skip-build", action="store_true", help="Skip npm/pnpm/yarn build step")
    parser.add_argument("--build-command", default="", help="Custom build command")
    parser.add_argument(
        "--skip-package",
        action="store_true",
        help="Skip package and validation scripts after import",
    )
    return parser.parse_args()


def main() -> int:
    args = _parse_args()
    project_dir = Path(args.project).resolve()
    if not project_dir.exists() or not project_dir.is_dir():
        print(f"project dir not found: {project_dir}")
        return 1

    package_json_path = project_dir / "package.json"
    if not package_json_path.exists():
        print(f"package.json not found: {package_json_path}")
        return 1

    if not MANIFEST_PATH.exists():
        print(f"manifest not found: {MANIFEST_PATH}")
        return 1

    package_json = _load_json(package_json_path)
    framework = args.framework
    if framework == "auto":
        framework = _detect_framework(package_json)
        if framework == "unknown":
            print("cannot detect framework automatically, please pass --framework vue|react")
            return 1

    if args.build_command.strip():
        build_cmd = args.build_command.strip()
    else:
        pm = _detect_package_manager(project_dir)
        build_cmd = f"{pm} run build"

    if args.dist_dir.strip():
        dist_dir = Path(args.dist_dir.strip())
        if not dist_dir.is_absolute():
            dist_dir = (project_dir / dist_dir).resolve()
    else:
        dist_dir = _detect_dist_dir(project_dir, framework, package_json).resolve()

    if not args.skip_build:
        if _run_cmd(build_cmd, project_dir) != 0:
            print("build failed")
            return 1

    if not dist_dir.exists() or not dist_dir.is_dir():
        print(f"build output dir not found: {dist_dir}")
        return 1

    target_dir_name = args.target_dir.strip() or _sanitize_name(args.app_id.split(".")[-1] or args.app_id)
    if not target_dir_name:
        target_dir_name = "app"
    target_dir = (MINIAPPS_DIR / target_dir_name).resolve()
    target_dir.parent.mkdir(parents=True, exist_ok=True)

    source_is_target = dist_dir.resolve() == target_dir
    if not source_is_target:
        if target_dir.exists():
            shutil.rmtree(target_dir)
        shutil.copytree(dist_dir, target_dir)

    entry = args.entry_file.strip() or "index.html"
    if not (target_dir / entry).exists():
        print(f"entry file not found in target: {target_dir / entry}")
        return 1

    manifest = _load_json(MANIFEST_PATH)
    existing_icon = ""
    apps = manifest.get("apps", [])
    if isinstance(apps, list):
        for item in apps:
            if isinstance(item, dict) and str(item.get("id", "")).strip() == args.app_id:
                existing_icon = str(item.get("icon", "")).strip()
                break

    tags_text = args.tags.replace("，", ",")
    tags = [x.strip() for x in tags_text.split(",") if x.strip()]
    if not tags:
        tags = [framework, "脚手架"]

    try:
        icon_path = _resolve_icon(args.icon_file.strip() or None, project_dir, target_dir, existing_icon)
    except Exception as exc:
        print(f"resolve icon failed: {exc}")
        return 1

    description = args.description.strip() or f"{framework.upper()} scaffold mini-app"
    _upsert_manifest_app(
        manifest,
        app_id=args.app_id.strip(),
        app_name=args.name.strip(),
        app_version=args.version.strip(),
        target_dir_name=target_dir_name,
        entry_file=entry,
        icon_path=icon_path,
        description=description,
        tags=tags,
        order=args.order,
    )
    _write_json(MANIFEST_PATH, manifest)
    print(f"imported app: {args.app_id} -> miniapps/{target_dir_name}")

    if not args.skip_package:
        if _run_cmd(f'"{sys.executable}" "{BUILD_SCRIPT}"', ROOT) != 0:
            return 1
        if _run_cmd(f'"{sys.executable}" "{VALIDATE_SCRIPT}"', ROOT) != 0:
            return 1

    print("done.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
