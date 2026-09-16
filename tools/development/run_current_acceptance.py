"""Capture and execute selected current graph suites with canonical native preparation.

Every invocation uses a fresh directory. It retains exact sources, Forge output,
full build-info/AST, preparation inputs, production sizes and actual test results.
This is scoped development evidence, never release or full-system acceptance.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import time

from tools.build.prepare_current_graph import CREATION_SOURCE, host_coordinate

ROOT = Path(__file__).resolve().parents[2]
TOOLS = (
    "tools/build/prepare_current_graph.py",
    "test/helpers/native_assembly_native_exports.py",
    "test/helpers/native_assembly_artifacts.py",
    "tools/development/run_current_acceptance.py",
)
# Keep strings intact while removing comments, so a commented import cannot add
# an unrelated source and comment markers inside URI strings remain literal.
TOKENS = re.compile(r'"(?:\\.|[^"\\])*"|\'(?:\\.|[^\'\\])*\'|//[^\n]*|/\*.*?\*/', re.S)
IMPORTS = re.compile(r'\bimport\s+(?:[^;]*?\bfrom\s+)?["\']([^"\']+)["\']\s*;')


def digest(raw: bytes) -> str:
    return hashlib.sha256(raw).hexdigest()


def source_files(root: Path, roots: set[str]) -> dict[str, bytes]:
    """Capture the repository's relative-import closure; unsupported imports fail."""
    root = root.resolve()
    pending = list(roots)
    result = {}
    while pending:
        name = pending.pop()
        if name in result:
            continue
        path = (root / name).resolve()
        if not path.is_relative_to(root) or path.suffix != ".sol":
            raise ValueError(f"Source is outside project: {name}")
        raw = path.read_bytes()
        result[name] = raw
        text = TOKENS.sub(lambda m: " " if m[0].startswith(("//", "/*")) else m[0], raw.decode("utf-8"))
        for target in IMPORTS.findall(text):
            if not target.startswith("."):
                raise ValueError(f"Scoped capture requires relative imports: {name}: {target}")
            dependency = (path.parent / target).resolve()
            if not dependency.is_relative_to(root):
                raise ValueError(f"Import escapes project: {name}: {target}")
            pending.append(dependency.relative_to(root).as_posix())
    return result


def write_json(path: Path, value: object) -> None:
    path.write_text(json.dumps(value, indent=2) + "\n", encoding="utf-8")


def read_forge_json(path: Path) -> dict:
    text = path.read_text(encoding="utf-8")
    for match in re.finditer(r"(?m)^\s*\{", text):
        try:
            data, end = json.JSONDecoder().raw_decode(text[match.start():].lstrip())
            if isinstance(data, dict):
                return data
        except json.JSONDecodeError:
            pass
    raise ValueError(f"No Forge JSON object in {path}")


def native_inventory(project: Path) -> dict[str, str]:
    result = {}
    for folder in ('out/current', 'cache/current'):
        for path in sorted((project / folder).rglob('*.json')):
            with path.open('rb') as stream:
                result[path.relative_to(project).as_posix()] = hashlib.file_digest(stream, 'sha256').hexdigest()
    if not result:
        raise ValueError('No native artifact/cache inventory')
    return result


def expected_cases(project: Path, hosts: tuple[tuple[str, str], ...]) -> dict[str, list[str]]:
    def abi_type(item: dict) -> str:
        value = item['type']
        return '(' + ','.join(abi_type(c) for c in item['components']) + ')' + value[5:] if value.startswith('tuple') else value
    result = {}
    for source, name in hosts:
        artifact = json.loads((project / 'out/current' / Path(source).name / (name + '.json')).read_bytes())
        cases = [item['name'] + '(' + ','.join(abi_type(i) for i in item['inputs']) + ')'
                 for item in artifact['abi'] if item['type'] == 'function'
                 and item['name'].startswith(('test', 'invariant_'))]
        if not cases:
            raise ValueError(f'No test cases in authenticated host ABI: {source}:{name}')
        result[source + ':' + name] = sorted(cases)
    return result


def validate_filters(config: dict) -> None:
    if any(config.get(k) for k in ('match_test', 'no_match_test', 'match_contract',
                                  'no_match_contract', 'match_path', 'no_match_path', 'skip')):
        raise ValueError('Clear configured test/path filters; every selected host must run completely')
    for family in ('fuzz', 'invariant'):
        if config.get(family, {}).get('timeout') is not None:
            raise ValueError('Clear fuzz/invariant timeout overrides for complete budgets')
        if config.get(family, {}).get('corpus_dir') is not None:
            raise ValueError('Clear external corpus directories; capture must use its own corpus')
    if config.get('invariant', {}).get('check_interval') != 1:
        raise ValueError('Acceptance requires invariant check_interval=1')


def test_results(data: dict, hosts: tuple[tuple[str, str], ...], expected: dict | None = None) -> dict:
    suites = {source + ":" + name for source, name in hosts}
    if set(data) != suites:
        raise ValueError(f"Executed suite inventory differs: missing={suites - set(data)}, extra={set(data) - suites}")
    counts = {"passed": 0, "failed": 0, "skipped": 0}
    for suite, item in data.items():
        cases = item.get("test_results", {})
        if not cases:
            raise ValueError(f"No test cases executed in {suite}")
        if expected is not None and sorted(cases) != expected[suite]:
            raise ValueError(f'Executed test cases differ from authenticated host ABI: {suite}')
        for name, result in cases.items():
            status = result.get("status")
            if status not in ("Success", "Failure", "Skipped"):
                raise ValueError(f"Unknown test status: {suite}: {name}: {status}")
            counts[{"Success": "passed", "Failure": "failed", "Skipped": "skipped"}[status]] += 1
            if status == 'Success':
                kind = result.get('kind', {})
                if 'Fuzz' in kind and kind['Fuzz'].get('runs', 0) < 256:
                    raise ValueError(f'Input fuzz budget incomplete: {suite}:{name}')
                if name.startswith('invariant_'):
                    actual = kind.get('Invariant', {})
                    if actual.get('runs', 0) < 32 or actual.get('calls', 0) < 32 * 64 or actual.get('reverts') != 0:
                        raise ValueError(f'Invariant sequence budget incomplete: {suite}:{name}')
    return counts


def capture(root: Path, destination: Path, hosts: tuple[tuple[str, str], ...]) -> dict:
    if not hosts or len(set(hosts)) != len(hosts) or len({n for _, n in hosts}) != len(hosts):
        raise ValueError("Select nonempty, uniquely named test hosts")
    for source, name in hosts:
        host_coordinate(source + ":" + name)
    products = json.loads((root / "test/fixtures/current-graph/products.json").read_bytes())
    sources = source_files(root, {CREATION_SOURCE, *(s for s, _ in hosts), *products.values()})
    files = dict(sources)
    for folder in ("test/fixtures", "schemas", "docs/schemas/finality"):
        for path in (root / folder).rglob("*"):
            # Solidity fixture programs belong to the import closure above;
            # copying unrelated planner fixtures changes the compile scope.
            if path.is_file() and path.suffix != ".sol":
                files[path.relative_to(root).as_posix()] = path.read_bytes()
    for name in TOOLS:
        files[name] = (root / name).read_bytes()
    original_config = (root / "foundry.toml").read_bytes()
    # Only the test search directory changes: the snapshot also admits selected
    # domain hosts. Its source tree contains only the captured import closure.
    config = original_config.decode("utf-8")
    if config.count('test = "test/current"') != 1:
        raise ValueError("Unrecognized current profile test directory")
    files["foundry.toml"] = config.replace('test = "test/current"', 'test = "test"').encode("utf-8")
    destination.mkdir(parents=True, exist_ok=False)
    project = destination / "project"
    for name, raw in sorted(files.items()):
        path = project / name
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(raw)
    (destination / "source-foundry.toml").write_bytes(original_config)
    commit = subprocess.run(["git", "rev-parse", "HEAD"], cwd=root, capture_output=True, text=True, check=True).stdout.strip()
    report = {"sourceCommit": commit, "sourceProject": str(root), "hosts": hosts,
              "sourceCount": len(sources), "files": {n: digest(v) for n, v in sorted(files.items())},
              "sourceFoundrySha256": digest(original_config),
              "qualification": "Exact working-source snapshot; hashes, not Git HEAD alone, identify uncommitted changes. Scoped development evidence only."}
    write_json(destination / "capture.json", report)
    return report


def run(root: Path, destination: Path, hosts: tuple[tuple[str, str], ...], *, solc: str | None = None) -> int:
    report = capture(root, destination, hosts)
    project = destination / "project"
    env = {k: v for k, v in os.environ.items() if not k.upper().startswith(("FOUNDRY_", "DAPP_"))}
    env.update(FOUNDRY_PROFILE="current", NO_COLOR="1")
    if solc:
        env["FOUNDRY_SOLC"] = solc
    # Fixed local seed/corpora prevent unrelated earlier counterexamples from
    # entering this snapshot. Meaningful campaign budgets remain explicit.
    env.update(FOUNDRY_FUZZ_SEED="0x6529", FOUNDRY_FUZZ_RUNS="256",
               FOUNDRY_INVARIANT_RUNS="32", FOUNDRY_INVARIANT_DEPTH="64",
               FOUNDRY_INVARIANT_FAILURE_PERSIST_DIR=str(destination / "invariant-failures"),
               FOUNDRY_FUZZ_FAILURE_PERSIST_DIR=str(destination / "fuzz-failures"))
    forge = shutil.which("forge", path=env.get("PATH"))
    if not forge:
        raise ValueError("Forge is not installed")
    selection = "^(" + "|".join(re.escape(n) for _, n in hosts) + ")$"
    commands = []
    started = time.monotonic()
    result = {"status": "STARTED", "sourceCommit": report["sourceCommit"], "commands": commands}

    def execute(command: list[str], log: str) -> int:
        commands.append({"argv": command, "log": log})
        write_json(destination / "result.json", result)
        print(f"{log}: {' '.join(command)}", flush=True)
        with (destination / log).open("w", encoding="utf-8") as stream:
            return subprocess.run(command, cwd=project, env=env, stdout=stream, stderr=subprocess.STDOUT).returncode

    try:
        execute([forge, "--version"], "forge-version.log")
        if execute([forge, "config", "--json"], "config.json"):
            raise ValueError("Forge configuration failed")
        config = read_forge_json(destination / "config.json")
        expected = {"via_ir": True, "build_info": True, "ast": True, "optimizer": True,
                    "optimizer_runs": 200, "evm_version": "paris", "bytecode_hash": "none", "cbor_metadata": False}
        if any(config.get(k) != v for k, v in expected.items()) or config.get("eth_rpc_url"):
            raise ValueError("Current native compiler settings differ, or inherited RPC is configured")
        validate_filters(config)
        common = [forge, "test", "--offline", "--threads", "1", "--match-contract", selection]
        if execute([*common, "--list", "--json"], "compile.log"):
            raise ValueError("Native compilation failed; retained compile.log")
        prepare = [sys.executable, "-m", "tools.build.prepare_current_graph"]
        for source, name in hosts:
            prepare += ["--host", source + ":" + name]
        if execute(prepare, "prepare-graph.log"):
            raise ValueError("Canonical graph preparation failed; no tests executed")
        # Bind all generated graph inputs before the actual execution.
        projections = {p.relative_to(project).as_posix(): digest(p.read_bytes())
                       for folder in ("artifacts/current-graph/compiled", "artifacts/native-assembly/compiled")
                       for p in (project / folder).iterdir()}
        sizes = []
        for path in (project / "out/current").rglob("*.json"):
            if "build-info" in path.parts:
                continue
            artifact = json.loads(path.read_bytes())
            target = artifact.get("metadata", {}).get("settings", {}).get("compilationTarget", {})
            for source, name in target.items():
                if source.startswith("smart-contracts/"):
                    runtime = len(artifact["deployedBytecode"]["object"].removeprefix("0x")) // 2
                    creation = len(artifact["bytecode"]["object"].removeprefix("0x")) // 2
                    if runtime:
                        sizes.append({"source": source, "name": name, "runtime": runtime, "creation": creation})
        write_json(destination / "products.json", sizes)
        result["productionProducts"] = len(sizes)
        result["oversize"] = [s for s in sizes if s["runtime"] > 24576 or s["creation"] > 49152]
        if result["oversize"]:
            raise ValueError("Production product exceeds deployment size limit")
        result['nativeInputs'] = native_inventory(project)
        result['expectedCases'] = expected_cases(project, hosts)
        result["testExitCode"] = execute([*common, "--json", "-vvv"], "tests.json")
        result.update(test_results(read_forge_json(destination / "tests.json"), hosts, result['expectedCases']))
        if native_inventory(project) != result['nativeInputs']:
            raise ValueError('Native compiler cache/build-info/artifacts changed during execution')
        if any(digest((project / n).read_bytes()) != h for n, h in report["files"].items()):
            raise ValueError("Captured source/input changed during execution")
        if any(digest((project / n).read_bytes()) != h for n, h in projections.items()):
            raise ValueError("Prepared graph inputs changed during execution")
        result["graphInputs"] = projections
        result["status"] = "PASSED" if not result["testExitCode"] and not result["failed"] and not result["skipped"] else "FAILED"
    except (OSError, ValueError, KeyError, subprocess.CalledProcessError) as error:
        result.update(status="FAILED", error=str(error))
    finally:
        result["seconds"] = round(time.monotonic() - started, 3)
        write_json(destination / "result.json", result)
    print(json.dumps({k: v for k, v in result.items() if k not in ("commands", "graphInputs", "nativeInputs", "expectedCases")}), flush=True)
    return 0 if result["status"] == "PASSED" else 1


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--project", type=Path, default=ROOT)
    parser.add_argument("--artifacts", type=Path, required=True, help="Fresh task-owned capture directory")
    parser.add_argument("--host", type=host_coordinate, action="append", required=True)
    parser.add_argument("--solc", help="Installed native Solidity 0.8.19 executable")
    args = parser.parse_args()
    return run(args.project.resolve(), args.artifacts.resolve(), tuple(args.host), solc=args.solc)


if __name__ == "__main__":
    raise SystemExit(main())
