"""Prepare current graph fixtures from exact native compiler output, without compiling.

Run after ``forge build`` with the current profile. Original Forge artifacts stay
unchanged; both graph fixtures receive projections from the graph test host's
actual compiler context. This is local test input preparation, not release proof.
"""
from __future__ import annotations

import argparse
import hashlib
import importlib.util
import json
import os
from pathlib import Path, PurePosixPath
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parents[2]
CREATION_SOURCE = "test/helpers/StreamNativeAssemblyCreation.sol"
CREATION_NAME = "StreamNativeAssemblyCreation"


def sha(raw: bytes) -> str:
    return hashlib.sha256(raw).hexdigest()


GRAPH_HOSTS = (
    ("test/current/StreamCurrentStack.t.sol", "StreamCurrentStackTest"),
    ("test/current/StreamNativeFinalityAssembly.t.sol", "StreamNativeFinalityAssemblyTest"),
)
CAMPAIGN_HOSTS = (
    ("test/current/StreamCurrentStackFuzz.t.sol", "StreamCurrentStackFuzzTest"),
    ("test/current/StreamCurrentStackInvariant.t.sol", "StreamCurrentStackInvariantTest"),
)


def select_build(cache: dict, hosts: tuple | None = None) -> str:
    # The creation library may be unchanged and cached from an older compilation.
    # The actual graph test host determines the context whose linked products run.
    for source, name in hosts or GRAPH_HOSTS:
        if source not in cache["files"]:
            continue
        entries = cache["files"][source]["artifacts"][name]["0.8.19"]
        expected = Path(source).name + "/" + name + ".json"
        matches = [item["build_id"] for item in entries.values()
                   if item["path"].replace("\\", "/") == expected]
        if len(matches) != 1:
            raise ValueError("Graph test host has no unambiguous cached build; rebuild the current profile")
        return matches[0]
    raise ValueError("No current graph test host is built; run the current profile build first")


def validate_sources(project: Path, build: dict) -> list[str]:
    if build["solcVersion"] != "0.8.19":
        raise ValueError("Current graph requires Solidity 0.8.19")
    settings = build["input"]["settings"]
    if not settings.get("viaIR") or settings.get("evmVersion") != "paris":
        raise ValueError("Current graph requires the via-IR Paris compiler profile")
    if settings.get("optimizer") != {"enabled": True, "runs": 200}:
        raise ValueError("Current graph requires optimizer 200")
    transports = []
    for name, item in build["input"]["sources"].items():
        path = PurePosixPath(name)
        if path.is_absolute() or ".." in path.parts or "\\" in name or ":" in name:
            raise ValueError(f"Non-project compiler source: {name}")
        source = (project / name).resolve()
        if not source.is_relative_to(project.resolve()):
            raise ValueError(f"Compiler source escapes the project: {name}")
        raw = source.read_bytes()
        literal = item["content"].encode("utf-8")
        if raw != literal:
            if raw.replace(b"\r\n", b"\n") != literal:
                raise ValueError(f"Stale compiler source: {name}; rebuild the current profile")
            transports.append(name)
    return transports


def check_campaign_owner(project: Path, campaign: bool) -> None:
    lease = project / "cache/current-graph.campaign.lock"
    if lease.exists() and (not campaign or lease.read_text(encoding="ascii") != str(os.getppid())):
        raise ValueError("An active campaign owns these graph inputs; finish it before preparation")


def prepare(project: Path, products_path: Path, *, out: Path | None = None,
            cache_dir: Path | None = None, campaign: bool = False) -> dict:
    project = project.resolve()
    out = (project / (out or "out/current")).resolve()
    cache_dir = (project / (cache_dir or "cache/current")).resolve()
    hosts = CAMPAIGN_HOSTS if campaign else GRAPH_HOSTS
    artifact_root = project / "artifacts/current-graph"
    artifact_root.mkdir(parents=True, exist_ok=True)
    lock = artifact_root / ".prepare.lock"
    try:
        fd = os.open(lock, os.O_CREAT | os.O_EXCL | os.O_WRONLY)
    except FileExistsError as exc:
        raise ValueError("Graph preparation is already locked; check the active owner before recovery") from exc
    try:
        os.write(fd, str(os.getpid()).encode()); os.close(fd)
        # Check inside the prepare lock. A campaign cannot begin execution until its
        # own child prepares successfully; other preparers then see its retained lease.
        check_campaign_owner(project, campaign)
        cache_path = cache_dir / "solidity-files-cache.json"
        cache_raw = cache_path.read_bytes()
        cache = json.loads(cache_raw)
        if campaign and any(source not in cache["files"] for source, _ in hosts):
            raise ValueError("Both campaign hosts must be compiled before preparation")
        build_id = select_build(cache, hosts)
        build_path = out / "build-info" / (build_id + ".json")
        build_raw = build_path.read_bytes()
        build = json.loads(build_raw)
        if build["id"] != build_id:
            raise ValueError("Build-info identity differs from the graph test cache")
        transports = validate_sources(project, build)
        products = json.loads(products_path.read_bytes())
        if not products or any(not source.startswith("smart-contracts/") for source in products.values()):
            raise ValueError("Graph product inventory must name production sources")
        helper = {CREATION_NAME: CREATION_SOURCE}
        for source, name in hosts:
            if source in cache["files"]:
                helper[name] = source
        with tempfile.TemporaryDirectory(prefix="prepare-", dir=artifact_root) as temporary:
            temp = Path(temporary)
            helper_path = temp / "helpers.json"
            helper_path.write_text(json.dumps(helper), encoding="utf-8")
            exports = temp / "exports"
            command = [sys.executable, str(ROOT / "test/helpers/native_assembly_native_exports.py"),
                       "--project", str(project), "--build-id", build_id,
                       "--products", str(products_path), "--helpers", str(helper_path),
                       "--out", str(out), "--cache-path", str(cache_dir),
                       "--output", str(exports)]
            subprocess.run(command, check=True)
            spec = importlib.util.spec_from_file_location(
                "stream_native_artifact_projection", ROOT / "test/helpers/native_assembly_artifacts.py")
            module = importlib.util.module_from_spec(spec)
            spec.loader.exec_module(module)
            # Retain the complete exports at a stable address so the projection's
            # provenance remains inspectable after this temporary directory closes.
            # Export provenance includes the original paths, selected hosts and exporter.
            # The same compilation in a different campaign cache has its own provenance.
            export_digest = sha((exports / "manifest.json").read_bytes())[:16]
            retained = artifact_root / "native" / (build_id + "-" + export_digest)
            generated_files = {f.relative_to(exports) for f in exports.rglob("*") if f.is_file()}
            if retained.exists():
                existing_files = {f.relative_to(retained) for f in retained.rglob("*") if f.is_file()}
                if existing_files != generated_files or any(
                    (retained / name).read_bytes() != (exports / name).read_bytes()
                    for name in generated_files
                ):
                    raise ValueError("Retained native exports differ from the validated compilation")
            else:
                retained.parent.mkdir(parents=True, exist_ok=True)
                exports.rename(retained)
            projected = temp / "compiled"
            report = module.project(build_path, retained, projected, products, True)
            if cache_path.read_bytes() != cache_raw or build_path.read_bytes() != build_raw:
                raise ValueError("Compiler output changed during graph preparation; retry after the build finishes")
            validate_sources(project, build)
            # All validation finishes before replacing fixture inputs. Each manifest is
            # replaced last, so an interrupted write cannot appear fully consistent.
            for relative in ("artifacts/current-graph/compiled", "artifacts/native-assembly/compiled"):
                destination = project / relative
                destination.mkdir(parents=True, exist_ok=True)
                expected = {name + ".json" for name in products} | {"manifest.json"}
                unexpected = {f.name for f in destination.iterdir()} - expected
                if unexpected:
                    raise ValueError(f"Unexpected files in managed graph directory: {sorted(unexpected)}")
                for name in sorted(expected - {"manifest.json"}) + ["manifest.json"]:
                    target = destination / name
                    temporary_target = destination / (name + ".tmp")
                    temporary_target.write_bytes((projected / name).read_bytes())
                    os.replace(temporary_target, target)
            result = {"buildId": build_id, "buildInfoSha256": sha(build_raw),
                      "sourceLineEndingTransports": transports, "products": len(products),
                      "productionRuntimes": len(report["productionRuntimeSizes"]),
                      "out": str(out), "cache": str(cache_dir), "hosts": helper,
                      "projectionManifestSha256": sha((projected / "manifest.json").read_bytes()),
                      "qualification": "Native fixture projections only; no tests, deployment or release accepted."}
            (artifact_root / "preparation.json").write_text(json.dumps(result, indent=2) + "\n", encoding="utf-8")
            return result
    finally:
        lock.unlink()


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--project", type=Path, default=ROOT)
    parser.add_argument("--products", type=Path, default=ROOT / "test/fixtures/current-graph/products.json")
    parser.add_argument("--out", type=Path, help="Completed Forge output directory, relative to project or absolute")
    parser.add_argument("--cache-path", type=Path, help="Matching Forge cache directory")
    parser.add_argument("--campaign", action="store_true", help="Bind both executed fuzz/invariant hosts")
    args = parser.parse_args()
    try:
        print(json.dumps(prepare(args.project, args.products, out=args.out,
                                 cache_dir=args.cache_path, campaign=args.campaign), indent=2))
        return 0
    except (AssertionError, KeyError, OSError, ValueError, subprocess.CalledProcessError) as exc:
        print(f"Graph preparation failed: {exc}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
