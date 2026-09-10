#!/usr/bin/env python3
"""Validate and copy a complete current compilation into a fresh writable workspace."""

from __future__ import annotations

import argparse
import hashlib
import json
import shutil
import tempfile
from pathlib import Path

from tools.deployment import generate_current_stack_artifacts as exporter


def inventory(directory: Path) -> dict[str, str]:
    result: dict[str, str] = {}
    for path in sorted(directory.rglob("*")):
        exporter.require(not path.is_symlink(), f"compiler evidence contains a symlink: {path}")
        if path.is_file():
            result[path.relative_to(directory).as_posix()] = hashlib.sha256(path.read_bytes()).hexdigest()
    return result


def overlaps(left: Path, right: Path) -> bool:
    return left == right or left.is_relative_to(right) or right.is_relative_to(left)


def prepare(root: Path, artifacts: Path, cache: Path, destination: Path, config: Path) -> dict:
    root, artifacts, cache, destination, config = (
        path.resolve() for path in (root, artifacts, cache, destination, config)
    )
    exporter.require(artifacts.is_dir() and cache.is_dir(), "raw artifact and cache directories are required")
    exporter.require(not destination.exists(), "destination already exists; use a fresh compilation workspace")
    exporter.require(not overlaps(artifacts, cache), "artifact and cache directories must be separate")
    exporter.require(
        not overlaps(destination, artifacts) and not overlaps(destination, cache),
        "destination overlaps retained compiler evidence",
    )
    original = {"out": inventory(artifacts), "cache": inventory(cache)}
    # This validates settings, literal source freshness, all selected artifacts, their
    # linked libraries, and one complete compiler input. It never invokes a compiler.
    candidate = exporter.candidate_files(root, artifacts, config)
    manifest = json.loads(candidate["manifest.json"])
    cache_file = cache / "solidity-files-cache.json"
    cache_data = exporter.load(cache_file)
    paths = cache_data["paths"]
    exporter.require((root / paths["artifacts"]).resolve() == artifacts, "cache belongs to a different raw artifact directory")
    exporter.require((root / paths["build_infos"]).resolve() == artifacts / "build-info", "cache build-info directory differs")
    exporter.require(
        (paths["sources"], paths["tests"], paths["scripts"]) == ("smart-contracts", "test/current", "script/current"),
        "cache was not prepared with the current source/test/script layout",
    )
    for build_id in cache_data["builds"]:
        exporter.require(
            isinstance(build_id, str) and build_id.isalnum()
            and (artifacts / "build-info" / (build_id + ".json")).is_file(),
            "cache references missing or invalid build-info",
        )
    writable_out, writable_cache = destination / "out", destination / "cache"
    # Rebase only the two output-location fields in the writable copy. Compiler
    # input, artifact contents, profile settings, source hashes and build IDs stay intact.
    cache_data["paths"]["artifacts"] = writable_out.as_posix()
    cache_data["paths"]["build_infos"] = (writable_out / "build-info").as_posix()
    report = {
        "schema": "6529stream.current-compilation-workspace.v1",
        "profile": "current",
        "source_selection": ["--skip", "test"],
        "source_artifacts": artifacts.as_posix(),
        "source_cache": cache.as_posix(),
        "artifact_directory": writable_out.as_posix(),
        "cache_directory": writable_cache.as_posix(),
        "compiler_input_sha256": manifest["compiler_input_sha256"],
        "target_count": len(manifest["targets"]),
        "source_count": len(manifest["sources"]),
        "retained_files": original,
        "cache_reuse": "validated writable copy; actual Forge cache hit must still be observed",
    }
    destination.parent.mkdir(parents=True, exist_ok=True)
    # Publish only a fully validated workspace. The temporary sibling is owned by
    # this invocation; exceptions clean it without touching retained evidence or
    # a destination another invocation may have created.
    with tempfile.TemporaryDirectory(prefix=f".{destination.name}-", dir=destination.parent) as temporary:
        temporary_root = Path(temporary).resolve()
        exporter.require(temporary_root.parent == destination.parent, "temporary workspace escaped destination parent")
        staging = temporary_root / "workspace"
        staging.mkdir()
        shutil.copytree(artifacts, staging / "out")
        shutil.copytree(cache, staging / "cache")
        exporter.require(inventory(staging / "out") == original["out"], "copied artifacts differ from retained evidence")
        exporter.require(inventory(staging / "cache") == original["cache"], "copied cache differs from retained evidence")
        (staging / "cache" / cache_file.name).write_bytes(exporter.encoded(cache_data))
        exporter.require(inventory(artifacts) == original["out"] and inventory(cache) == original["cache"], "retained evidence changed during copy")
        (staging / "compilation-workspace.json").write_bytes(exporter.encoded(report))
        exporter.require(not destination.exists(), "destination appeared during preparation; preserving it")
        staging.rename(destination)
    return report


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repo-root", type=Path, default=Path.cwd())
    parser.add_argument("--artifacts", type=Path, required=True)
    parser.add_argument("--cache", type=Path, required=True)
    parser.add_argument("--destination", type=Path, required=True)
    parser.add_argument("--config", type=Path, default=exporter.CONFIG)
    args = parser.parse_args(argv)
    root = args.repo_root.resolve()
    try:
        result = prepare(root, root / args.artifacts, root / args.cache, root / args.destination, root / args.config)
    except (exporter.CurrentArtifactError, OSError, ValueError, KeyError, TypeError) as exc:
        print(f"Current compilation preparation failed: {exc}")
        return 1
    print(json.dumps({key: result[key] for key in ("artifact_directory", "cache_directory", "compiler_input_sha256", "target_count", "source_count")}, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
