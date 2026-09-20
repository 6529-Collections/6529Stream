"""Prepare current graph fixtures from exact native compiler output, without compiling.

Run after ``forge build`` with the current profile. Original Forge artifacts stay
unchanged; both graph fixtures use the cached literal creation library's compiler
context. Each test host is authenticated in its own selected context. This is local test input preparation, not release proof.
"""
from __future__ import annotations

import argparse
import hashlib
import importlib.util
import json
import os
import re
from pathlib import Path, PurePosixPath
import subprocess
import sys
import tempfile

from tools.build.scoped_standard_json import bind_build_capture, verify_pair

ROOT = Path(__file__).resolve().parents[2]
CREATION_SOURCE = "test/helpers/StreamNativeAssemblyCreation.sol"
CREATION_NAME = "StreamNativeAssemblyCreation"


def sha(raw: bytes) -> str:
    return hashlib.sha256(raw).hexdigest()


GRAPH_HOSTS = (
    ("test/current/StreamCurrentStack.t.sol", "StreamCurrentStackTest"),
    ("test/current/StreamCurrentNativeSettlement.t.sol", "StreamCurrentNativeSettlementTest"),
    ("test/current/StreamNativeFinalityAssembly.t.sol", "StreamNativeFinalityAssemblyTest"),
)
CAMPAIGN_HOSTS = (
    ("test/current/StreamCurrentStackFuzz.t.sol", "StreamCurrentStackFuzzTest"),
    ("test/current/StreamCurrentStackInvariant.t.sol", "StreamCurrentStackInvariantTest"),
)


def host_coordinate(value: str) -> tuple[str, str]:
    """Accept an exact test source/product coordinate, never a broad test filter."""
    source, separator, name = value.partition(":")
    path = PurePosixPath(source)
    if (not separator or not source.startswith("test/") or not source.endswith(".t.sol")
            or path.as_posix() != source or ".." in path.parts or "\\" in source
            or not re.fullmatch(r"[A-Za-z_][A-Za-z0-9_]*", name)):
        raise ValueError(f"Expected test/path.t.sol:ContractName, got {value!r}")
    return source, name


def select_build(cache: dict, hosts: tuple | None = None) -> str:
    # Select an actual cache-owned product; never infer an owner from recency.
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


def source_closure(build: dict, roots: set[str], *, analysis: dict | None = None) -> set[str]:
    """Resolve transitive source imports from this compilation's actual ASTs."""
    if analysis is not None:
        verify_pair(analysis["input"], analysis["output"], build["input"], build["output"])
    evidence = analysis if analysis is not None else build
    selected: set[str] = set(); pending = list(roots)
    while pending:
        source = pending.pop()
        if source in selected:
            continue
        if source not in build['input']['sources'] or source not in evidence['output']['sources']:
            raise ValueError(f'Compiler dependency missing: {source}')
        ast = evidence['output']['sources'][source].get('ast')
        if not isinstance(ast, dict):
            raise ValueError(f'Compiler AST missing: {source}; rebuild with build_info=true and ast=true')
        if ast['absolutePath'] != source:
            raise ValueError(f'Compiler AST source differs: {source}')
        selected.add(source)
        pending.extend(node['absolutePath'] for node in ast['nodes'] if node['nodeType'] == 'ImportDirective')
    return selected

def validate_sources(project: Path, build: dict, *, source_roots: set[str] | None = None,
                     analysis: dict | None = None) -> list[str]:
    if build["solcVersion"] != "0.8.19":
        raise ValueError("Current graph requires Solidity 0.8.19")
    settings = build["input"]["settings"]
    if not settings.get("viaIR") or settings.get("evmVersion") != "paris":
        raise ValueError("Current graph requires the via-IR Paris compiler profile")
    if settings.get("optimizer") != {"enabled": True, "runs": 200}:
        raise ValueError("Current graph requires optimizer 200")
    transports = []
    selected = set(build["input"]["sources"]) if source_roots is None else source_closure(build, source_roots, analysis=analysis)
    for name in sorted(selected):
        item = build["input"]["sources"][name]
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


def retain_exports(exports: Path, artifact_root: Path, build_id: str) -> Path:
    digest = sha((exports / 'manifest.json').read_bytes())[:16]
    retained = artifact_root / 'native' / (build_id + '-' + digest)
    generated = {f.relative_to(exports) for f in exports.rglob('*') if f.is_file()}
    if retained.exists():
        existing = {f.relative_to(retained) for f in retained.rglob('*') if f.is_file()}
        if existing != generated or any((retained / n).read_bytes() != (exports / n).read_bytes() for n in generated):
            raise ValueError('Retained native exports differ from the validated compilation')
    else:
        retained.parent.mkdir(parents=True, exist_ok=True)
        exports.rename(retained)
    return retained


def prepare(project: Path, products_path: Path, *, out: Path | None = None,
            cache_dir: Path | None = None, campaign: bool = False,
            selected_hosts: tuple[tuple[str, str], ...] | None = None,
            compiler_captures: dict[str, Path] | None = None,
            compiler_admissions: dict[str, Path] | None = None) -> dict:
    captures = compiler_captures or {}
    admissions = compiler_admissions or {}
    if set(admissions) - set(captures):
        raise ValueError('Every compiler admission requires its matching compiler capture')
    project = project.resolve()
    out = (project / (out or 'out/current')).resolve()
    cache_dir = (project / (cache_dir or 'cache/current')).resolve()
    if campaign and selected_hosts is not None:
        raise ValueError('Campaign host selection is fixed; do not combine --campaign and --host')
    hosts = selected_hosts if selected_hosts is not None else (CAMPAIGN_HOSTS if campaign else GRAPH_HOSTS)
    if not hosts or len({name for _, name in hosts}) != len(hosts):
        raise ValueError('Select nonempty, uniquely named test hosts')
    for source, name in hosts:
        host_coordinate(source + ':' + name)
    artifact_root = project / 'artifacts/current-graph'
    artifact_root.mkdir(parents=True, exist_ok=True)
    lock = artifact_root / '.prepare.lock'
    try:
        fd = os.open(lock, os.O_CREAT | os.O_EXCL | os.O_WRONLY)
    except FileExistsError as exc:
        raise ValueError('Graph preparation is already locked; check the active owner before recovery') from exc
    try:
        os.write(fd, str(os.getpid()).encode()); os.close(fd)
        check_campaign_owner(project, campaign)
        cache_path = cache_dir / 'solidity-files-cache.json'
        cache_raw = cache_path.read_bytes(); cache = json.loads(cache_raw)
        if (campaign or selected_hosts is not None) and any(source not in cache['files'] for source, _ in hosts):
            raise ValueError('Every selected test host must be compiled before preparation')
        select_build(cache, hosts)  # At least one selected test host is required.
        helper = {CREATION_NAME: CREATION_SOURCE}
        helper.update({name: source for source, name in hosts if source in cache['files']})
        coordinates = {name: select_build(cache, ((source, name),)) for name, source in helper.items()}
        build_id = coordinates[CREATION_NAME]
        products = json.loads(products_path.read_bytes())
        if not products or any(not source.startswith('smart-contracts/') for source in products.values()):
            raise ValueError('Graph product inventory must name production sources')
        if set(captures) - set(coordinates.values()):
            raise ValueError('Compiler capture does not match a selected native build')
        contexts = {}; transports = set()
        for ident in sorted(set(coordinates.values())):
            path = out / 'build-info' / (ident + '.json')
            if not path.is_file():
                raise ValueError(f'Full build-info missing: {path}; rebuild with build_info=true and ast=true')
            raw = path.read_bytes(); build = json.loads(raw)
            if build['id'] != ident:
                raise ValueError('Build-info identity differs from its selected cache entry')
            analysis = None; capture_evidence = None
            if ident in captures:
                build, analysis, capture_evidence = bind_build_capture(build, captures[ident], admission=admissions.get(ident))
            helpers = {name: source for name, source in helper.items() if coordinates[name] == ident}
            inventory = products if ident == build_id else {}
            roots = set(helpers.values()) | set(inventory.values())
            transports.update(validate_sources(project, build, source_roots=roots, analysis=analysis))
            contexts[ident] = {'path': path, 'raw': raw, 'build': build, 'helpers': helpers,
                               'products': inventory, 'roots': roots, 'analysis': analysis,
                               'compilerCapture': captures.get(ident), 'compilerAdmission': admissions.get(ident),
                               'captureEvidence': capture_evidence}
        with tempfile.TemporaryDirectory(prefix='prepare-', dir=artifact_root) as temporary:
            temp = Path(temporary)
            for ident, context in contexts.items():
                folder = temp / ident; folder.mkdir()
                helper_path = folder / 'helpers.json'; helper_path.write_text(json.dumps(context['helpers']), encoding='utf-8')
                inventory_path = folder / 'products.json'; inventory_path.write_text(json.dumps(context['products']), encoding='utf-8')
                exports = folder / 'exports'
                command = [sys.executable, str(ROOT / 'test/helpers/native_assembly_native_exports.py'),
                           '--project', str(project), '--build-id', ident, '--products', str(inventory_path),
                           '--helpers', str(helper_path), '--out', str(out), '--cache-path', str(cache_dir),
                           '--output', str(exports)]
                if context['compilerCapture'] is not None:
                    command += ['--compiler-capture', str(context['compilerCapture'])]
                if context['compilerAdmission'] is not None:
                    command += ['--compiler-admission', str(context['compilerAdmission'])]
                subprocess.run(command, check=True)
                context['retained'] = retain_exports(exports, artifact_root, ident)
            spec = importlib.util.spec_from_file_location(
                'stream_native_artifact_projection', ROOT / 'test/helpers/native_assembly_artifacts.py')
            module = importlib.util.module_from_spec(spec); spec.loader.exec_module(module)
            owner = contexts[build_id]; projected = temp / 'compiled'
            report = module.project(owner['path'], owner['retained'], projected, products, True,
                                    compiler_capture=owner['compilerCapture'], compiler_admission=owner['compilerAdmission'])
            if cache_path.read_bytes() != cache_raw:
                raise ValueError('Compiler cache changed during graph preparation')
            for context in contexts.values():
                if context['path'].read_bytes() != context['raw']:
                    raise ValueError('Compiler output changed during graph preparation')
                if context['compilerCapture'] is not None:
                    _, _, evidence = bind_build_capture(json.loads(context['raw']), context['compilerCapture'],
                                                        admission=context['compilerAdmission'])
                    if evidence != context['captureEvidence']:
                        raise ValueError('Compiler capture changed during preparation')
                validate_sources(project, context['build'], source_roots=context['roots'], analysis=context['analysis'])
            # A cached literal creation library owns the embedded product bytes.
            # Changed test hosts are authenticated in their own compiler contexts;
            # unadopted dependency emissions never replace that creation owner.
            for relative in ('artifacts/current-graph/compiled', 'artifacts/native-assembly/compiled'):
                destination = project / relative; destination.mkdir(parents=True, exist_ok=True)
                expected = {name + '.json' for name in products} | {'manifest.json'}
                unexpected = {f.name for f in destination.iterdir()} - expected
                if unexpected:
                    raise ValueError(f'Unexpected files in managed graph directory: {sorted(unexpected)}')
                for name in sorted(expected - {'manifest.json'}) + ['manifest.json']:
                    temporary_target = destination / (name + '.tmp')
                    temporary_target.write_bytes((projected / name).read_bytes())
                    os.replace(temporary_target, destination / name)
            result = {'buildId': build_id, 'buildInfoSha256': sha(owner['raw']),
                      'sourceLineEndingTransports': sorted(transports), 'products': len(products),
                      'productionRuntimes': len(report['productionRuntimeSizes']),
                      'out': str(out), 'cache': str(cache_dir), 'hosts': helper,
                      'helperBuildIds': coordinates,
                      'compilerContexts': {ident: {'buildInfoSha256': sha(ctx['raw']),
                          'nativeExports': str(ctx['retained']), 'sourceRoots': sorted(ctx['roots']),
                          'compilerCapture': ctx['captureEvidence']}
                          for ident, ctx in contexts.items()},
                      'projectionManifestSha256': sha((projected / 'manifest.json').read_bytes()),
                      'qualification': 'Native fixture projections from the cached creation owner; separately bound test hosts. No tests, deployment or release accepted.'}
            (artifact_root / 'preparation.json').write_text(json.dumps(result, indent=2) + '\n', encoding='utf-8')
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
    parser.add_argument("--host", action="append", type=host_coordinate,
                        help="Exact test/path.t.sol:ContractName to authenticate (repeatable)")
    parser.add_argument("--compiler-capture", action="append", default=[], metavar="BUILD_ID=PATH",
                        help="Verified split native capture for an actual selected Forge build (repeatable)")
    parser.add_argument("--compiler-admission", action="append", default=[], metavar="BUILD_ID=PATH",
                        help="Explicit terminal-capture readmission receipt for a matching capture (repeatable)")
    args = parser.parse_args()
    try:
        captures = {}; admissions = {}
        for values, mapping in ((args.compiler_capture, captures), (args.compiler_admission, admissions)):
            for value in values:
                ident, separator, folder = value.partition("=")
                if not separator or not ident or not folder or ident in mapping:
                    raise ValueError("Expected unique BUILD_ID=PATH compiler captures/admissions")
                mapping[ident] = Path(folder).resolve()
        print(json.dumps(prepare(args.project, args.products, out=args.out,
                                 cache_dir=args.cache_path, campaign=args.campaign,
                                 selected_hosts=tuple(args.host) if args.host else None,
                                 compiler_captures=captures, compiler_admissions=admissions), indent=2))
        return 0
    except (AssertionError, KeyError, OSError, ValueError, subprocess.CalledProcessError) as exc:
        print(f"Graph preparation failed: {exc}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
