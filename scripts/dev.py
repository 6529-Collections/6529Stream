#!/usr/bin/env python3
"""Portable entry point for developing and checking the supported Stream stack.

Run from any directory. Only the child process receives the selected Foundry
profile; this command never changes shell configuration or installs software.
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
from datetime import datetime, timezone


ROOT = Path(__file__).resolve().parents[1]
FOUNDRY_VERSION = "1.7.1"
CURRENT_SETTINGS = {
    "src": "smart-contracts",
    "test": "test/current",
    "script": "script/current",
    "solc": "0.8.19",
    "evm_version": "paris",
    "via_ir": True,
    "optimizer": True,
    "optimizer_runs": 200,
    "bytecode_hash": "none",
    "cbor_metadata": False,
}
SUITES = {
    "current": ("current", None),
    "unit": ("default", "test/unit/**/*.t.sol"),
    "legacy": ("default", "test/regression/legacy/**/*.t.sol"),
    "gas": ("default", "test/gas/**/*.t.sol"),
    "all": ("default", None),
}
CAMPAIGNS = {"quick": (32, 64, 256), "extended": (256, 256, 4096)}
CAMPAIGN_SUITES = {
    "test/current/StreamCurrentStackInvariant.t.sol:StreamCurrentStackInvariantTest": "invariant_",
    "test/current/StreamCurrentStackFuzz.t.sol:StreamCurrentStackFuzzTest": "testFuzz",
}
DEFAULT_CAMPAIGN_SEED = "0x6529"


def campaign_seed(value: str) -> str:
    if not re.fullmatch(r"0x[0-9a-fA-F]{1,64}", value):
        raise argparse.ArgumentTypeError("seed must be a 0x-prefixed uint256 hex value")
    return "0x" + value[2:].lower().zfill(64)


def campaign_sources() -> dict[str, str]:
    paths = set()
    for folder in ("smart-contracts", "test", "script", "lib"):
        paths.update((ROOT / folder).rglob("*.sol"))
    for name in ("foundry.toml", "foundry.lock", "remappings.txt", ".gitmodules"):
        if (ROOT / name).is_file():
            paths.add(ROOT / name)
    return {p.relative_to(ROOT).as_posix(): hashlib.sha256(p.read_bytes()).hexdigest()
            for p in sorted(paths)}


def campaign_results(text: str) -> dict[str, object]:
    """Require an executed invariant; Forge can exit successfully for an empty filter."""
    decoder = json.JSONDecoder()
    for match in re.finditer(r"(?m)^\s*\{", text):
        try:
            data, _ = decoder.raw_decode(text[match.start():].lstrip())
        except json.JSONDecodeError:
            continue
        if isinstance(data, dict) and all(key in data for key in CAMPAIGN_SUITES):
            combined = {}
            for key, prefix in CAMPAIGN_SUITES.items():
                if not isinstance(data[key], dict):
                    raise ValueError("Malformed Forge suite result")
                results = data[key].get("test_results", {})
                if not isinstance(results, dict) or not any(k.startswith(prefix) for k in results):
                    raise ValueError(f"Forge did not report an executed {prefix} property in {key}")
                if any(not isinstance(result, dict) for result in results.values()):
                    raise ValueError("Malformed Forge property result")
                combined.update({f"{key}::{name}": result for name, result in results.items()})
            return combined
    raise ValueError("Forge did not report both selected campaign suites; inspect forge.log")


def campaign_budget(results: dict[str, object], runs: int, depth: int, fuzz_runs: int) -> None:
    """Verify successful properties actually completed their configured budgets."""
    for name, result in results.items():
        if result.get("status") != "Success":
            continue  # Retain the real failing test and its shorter counterexample.
        kind = result.get("kind", {})
        if name.rsplit("::", 1)[-1].startswith("testFuzz"):
            if kind.get("Fuzz", {}).get("runs", 0) < fuzz_runs:
                raise ValueError("Successful input property did not complete the fuzz budget")
        elif name.rsplit("::", 1)[-1].startswith("invariant_"):
            actual = kind.get("Invariant", {})
            if actual.get("runs", 0) < runs or actual.get("calls", 0) < runs * depth or actual.get("reverts") != 0:
                raise ValueError("Successful invariant did not complete the sequence budget")


def campaign(args: argparse.Namespace) -> int:
    """Run a local, reproducible handler campaign without touching release exports."""
    runs, depth, fuzz_runs = CAMPAIGNS[args.mode]
    stamp = datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%S%fZ")
    artifact = Path(args.artifacts) if args.artifacts else Path("tmp/campaigns") / f"{args.mode}-{stamp}"
    artifact = artifact if artifact.is_absolute() else ROOT / artifact
    artifact = artifact.resolve()
    if artifact.exists():
        print("Campaign artifact directory already exists; use a new directory.", file=sys.stderr)
        return 1
    label = f"{args.mode}-{args.seed[2:]}"
    out = ROOT / ("out/current" if args.reuse_current else f"out/campaigns/{label}")
    cache = ROOT / ("cache/current" if args.reuse_current else f"cache/campaigns/{label}")
    # Fixed paths only; do not follow a linked build/cache destination on Windows.
    for path in (out, cache):
        if path.resolve() != ROOT.resolve() / path.relative_to(ROOT) or (path.exists() and not path.is_dir()):
            print(f"Refusing redirected/non-directory campaign build path: {path}", file=sys.stderr)
            return 1
    env = environment("current")
    forge = shutil.which("forge", path=env.get("PATH"))
    if not forge:
        print("Missing forge. See docs/first-30-minutes.md.", file=sys.stderr)
        return 127
    lock = cache.parent / (cache.name + ".campaign.lock")
    lock.parent.mkdir(parents=True, exist_ok=True)
    try:
        lock_fd = os.open(lock, os.O_CREAT | os.O_EXCL | os.O_WRONLY)
    except FileExistsError:
        print(f"A campaign already owns this cache: {lock}. Do not remove an active lock.", file=sys.stderr)
        return 1
    os.close(lock_fd)
    try:
        artifact.mkdir(parents=True, exist_ok=False)
    except OSError as error:
        lock.unlink()
        print(f"Could not create campaign artifact directory: {error}", file=sys.stderr)
        return 1
    report: dict[str, object] = {"schemaVersion": 1, "mode": args.mode, "profile": "current",
        "seed": args.seed, "runs": runs, "depth": depth, "fuzzRuns": fuzz_runs, "status": "STARTED",
        "artifactDirectory": str(artifact), "out": str(out), "cache": str(cache)}
    started = time.monotonic()
    try:
        # Avoid importing a prior failure directory by reference: retain the exact replay input.
        if args.replay_from:
            origin = Path(args.replay_from)
            origin = (origin if origin.is_absolute() else ROOT / origin).resolve()
            for name in ("invariant-failures", "fuzz-failures"):
                source = origin / name
                if source.exists():
                    if not source.is_dir() or any(p.is_symlink() or p.is_junction() for p in [source, *source.rglob("*")]):
                        raise ValueError("Replay corpus must contain ordinary files/directories")
                    shutil.copytree(source, artifact / name)
            if not any((artifact / name).exists() for name in ("invariant-failures", "fuzz-failures")):
                raise ValueError("Replay source has no retained failure corpus")
            report["replayFrom"] = str(origin)
        env.update({"FOUNDRY_OUT": str(out), "FOUNDRY_CACHE_PATH": str(cache),
            "FOUNDRY_FUZZ_SEED": args.seed, "FOUNDRY_FUZZ_RUNS": str(fuzz_runs), "FOUNDRY_FUZZ_FAIL_ON_REVERT": "true",
            "FOUNDRY_INVARIANT_RUNS": str(runs), "FOUNDRY_INVARIANT_DEPTH": str(depth),
            "FOUNDRY_INVARIANT_FAIL_ON_REVERT": "true", "FOUNDRY_INVARIANT_SHOW_METRICS": "true",
            "FOUNDRY_INVARIANT_FAILURE_PERSIST_DIR": str(artifact / "invariant-failures"),
            "FOUNDRY_FUZZ_FAILURE_PERSIST_DIR": str(artifact / "fuzz-failures"), "NO_COLOR": "1"})
        version = subprocess.run([forge, "--version"], cwd=ROOT, env=env, capture_output=True, text=True, encoding="utf-8")
        match = re.search(r"Version:\s*(\S+)", version.stdout)
        if version.returncode or not match or match.group(1) != FOUNDRY_VERSION:
            raise ValueError(f"Campaign requires Foundry {FOUNDRY_VERSION}")
        resolved = subprocess.run([forge, "config", "--json"], cwd=ROOT, env=env, capture_output=True, text=True, encoding="utf-8")
        if resolved.returncode:
            raise ValueError("Could not resolve campaign compiler settings")
        config = json.loads(resolved.stdout)
        if any(type(config.get(k)) is not type(v) or config.get(k) != v for k, v in CURRENT_SETTINGS.items()):
            raise ValueError("Campaign compiler settings differ from current; run doctor")
        if config.get("eth_rpc_url"):
            raise ValueError("Campaign is local; clear the inherited fork RPC override")
        if any(config.get(key) for key in ("match_test", "no_match_test", "match_contract", "no_match_contract", "match_path", "no_match_path")):
            raise ValueError("Clear inherited Foundry test filters; campaign selects both complete suites")
        inv = config["invariant"]
        if any(inv.get(k) != v for k, v in {"runs": runs, "depth": depth, "fail_on_revert": True, "show_metrics": True}.items()) or int(config["fuzz"]["seed"], 16) != int(args.seed, 16) or config["fuzz"]["runs"] != fuzz_runs or config["fuzz"].get("fail_on_revert") is not True:
            raise ValueError("Foundry did not apply the requested campaign settings")
        if inv.get("timeout") is not None or config["fuzz"].get("timeout") is not None:
            raise ValueError("Clear fuzz/invariant timeout overrides for a complete campaign")
        if inv.get("corpus_dir") is not None or config["fuzz"].get("corpus_dir") is not None:
            raise ValueError("Clear external corpus-directory overrides; use --replay-from for retained failures")
        if inv.get("check_interval") != 1:
            raise ValueError("Campaign requires invariant check_interval=1")
        report.update({"foundryVersion": FOUNDRY_VERSION, "compiler": {k: config[k] for k in CURRENT_SETTINGS},
                       "invariant": inv, "fuzz": config["fuzz"], "sources": campaign_sources(),
                       "execution": {k: config.get(k) for k in ("chain_id", "gas_limit", "code_size_limit", "initial_balance", "block_number", "block_timestamp", "block_base_fee_per_gas", "block_coinbase", "block_difficulty", "block_prevrandao", "block_gas_limit")}})
        head = subprocess.run(["git", "rev-parse", "HEAD"], cwd=ROOT, capture_output=True, text=True, encoding="utf-8")
        report["gitCommit"] = head.stdout.strip() if head.returncode == 0 else None
        command = [forge, "test", "--match-path", "test/current/StreamCurrentStack*.t.sol", "--match-contract", "^StreamCurrentStack(Invariant|Fuzz)Test$",
                   "--fuzz-seed", args.seed, "--threads", "1", "--json", "-vvv", "--out", str(out), "--cache-path", str(cache)]
        report["command"] = command
        (artifact / "campaign.json").write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
        print(f"[current] {args.mode}: seed={args.seed}, invariant={runs}x{depth}, fuzz={fuzz_runs}/property", flush=True)
        print(f"Evidence: {artifact}; compile/cache: {cache}. Logs stream to forge.log.", flush=True)
        with (artifact / "forge.log").open("w", encoding="utf-8") as log:
            process = subprocess.Popen(command, cwd=ROOT, env=env, stdout=log, stderr=subprocess.STDOUT)
            try:
                code = process.wait()
            except KeyboardInterrupt:
                process.terminate()
                process.wait()
                report["status"] = "INTERRUPTED"
                return 130
        report["forgeExitCode"] = code
        if report["sources"] != campaign_sources():
            raise ValueError("Compiler inputs changed during campaign; retain output but rerun stable sources")
        results = campaign_results((artifact / "forge.log").read_text(encoding="utf-8"))
        report["tests"] = {name: {"status": result.get("status"), "reason": result.get("reason"), "kind": result.get("kind")}
                           for name, result in results.items()}
        campaign_budget(results, runs, depth, fuzz_runs)
        success = code == 0 and all(result.get("status") == "Success" for result in results.values())
        report["status"] = "PASS" if success else "FAIL"
        print(f"Campaign {report['status']}; {len(results)} tests reported. Inspect forge.log for handler metrics and traces.")
        return 0 if success else code or 1
    except (OSError, ValueError, KeyError, TypeError) as error:
        report["status"] = "ERROR"
        report["error"] = str(error)
        print(f"Campaign failed: {error}", file=sys.stderr)
        return 1
    finally:
        report["durationSeconds"] = round(time.monotonic() - started, 3)
        (artifact / "campaign.json").write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
        lock.unlink()


def environment(profile: str) -> dict[str, str]:
    env = dict(os.environ)
    env["FOUNDRY_PROFILE"] = profile
    # Match the documented installation without requiring a shell restart.
    foundry_bin = Path.home() / ".foundry" / "bin"
    if foundry_bin.is_dir():
        env["PATH"] = str(foundry_bin) + os.pathsep + env.get("PATH", "")
    return env


def run(command: list[str], *, profile: str = "current") -> int:
    env = environment(profile)
    executable = shutil.which(command[0], path=env.get("PATH"))
    if executable is None:
        print(f"Missing {command[0]}. See docs/first-30-minutes.md.", file=sys.stderr)
        return 127
    print(f"[{profile}] {' '.join(command)}", flush=True)
    try:
        return subprocess.run([executable, *command[1:]], cwd=ROOT, env=env).returncode
    except KeyboardInterrupt:
        return 130


def python_tool(module: str, *args: str) -> list[str]:
    return [sys.executable, "-m", module, *args]


def doctor() -> int:
    print(f"Repository: {ROOT}")
    print(f"Python: {sys.version.split()[0]}")
    if sys.version_info[:2] != (3, 12):
        print("The repository tooling is tested on Python 3.12. Select that interpreter.", file=sys.stderr)
        return 1
    env = environment("current")
    for tool in ("forge", "cast"):
        executable = shutil.which(tool, path=env.get("PATH"))
        if executable is None:
            print(f"Missing {tool}. See docs/first-30-minutes.md.", file=sys.stderr)
            return 127
        result = subprocess.run(
            [executable, "--version"], cwd=ROOT, env=env, capture_output=True,
            text=True, encoding="utf-8",
        )
        version = re.search(r"Version:\s*(\S+)", result.stdout)
        if result.returncode or version is None or version.group(1) != FOUNDRY_VERSION:
            observed = version.group(1) if version else "unavailable"
            print(f"{tool}: expected {FOUNDRY_VERSION}, found {observed}.", file=sys.stderr)
            return 1
        print(f"{tool}: {version.group(1)}")
    result = subprocess.run(
        [shutil.which("forge", path=env.get("PATH")), "config", "--json"],
        cwd=ROOT,
        env=env,
        capture_output=True,
        text=True,
        encoding="utf-8",
    )
    if result.returncode:
        print("Foundry could not read foundry.toml.", file=sys.stderr)
        return result.returncode
    try:
        config = json.loads(result.stdout)
    except json.JSONDecodeError:
        print("Foundry returned an invalid configuration response.", file=sys.stderr)
        return 1
    # Never dump RPC or explorer settings inherited from the user's environment.
    problems = []
    for field, expected in CURRENT_SETTINGS.items():
        actual = config.get(field)
        if type(actual) is not type(expected) or actual != expected:
            problems.append(f"{field}: expected {expected!r}, found {actual!r}")
    if problems:
        print("Current compiler configuration differs from the supported build:", file=sys.stderr)
        for problem in problems:
            print(f"  {problem}", file=sys.stderr)
        print("Check FOUNDRY_* overrides and foundry.toml. No settings were changed.", file=sys.stderr)
        return 1
    print("Current profile: Solidity 0.8.19, Paris, via-IR, optimizer 200; settings match.")
    print("Ready. Run: python scripts/dev.py test")
    print("A cold Solidity build can take many minutes; later runs reuse the cache.")
    return 0


def clean() -> int:
    """Remove reproducible compiler output; retain broadcasts and deployment evidence."""
    targets = [ROOT / name for name in ("out", "out-release", "cache")]
    # Validate every target before deleting any of them, including Windows junctions.
    for target in targets:
        if target.resolve() != ROOT.resolve() / target.name or target.is_symlink():
            print(f"Refusing linked build directory: {target}", file=sys.stderr)
            return 1
        if target.exists() and not target.is_dir():
            print(f"Expected a build directory: {target}", file=sys.stderr)
            return 1
    for target in targets:
        if target.is_dir():
            shutil.rmtree(target)
            print(f"Removed {target.relative_to(ROOT)}")
    print("Build outputs cleared. Broadcast receipts and deployment records retained.")
    return 0


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    commands = parser.add_subparsers(dest="command", required=True)
    commands.add_parser("doctor", help="Check local tools and the current Foundry profile")
    commands.add_parser("clean", help="Clear build/cache outputs; retain broadcast and deployment evidence")
    commands.add_parser("build", help="Compile the supported current stack")
    test = commands.add_parser("test", help="Run current flows or a selected test suite")
    test.add_argument("--suite", choices=SUITES, default="current")
    test.add_argument("--match-path", help="Narrow a suite to a path or glob within its directory")
    invariant = commands.add_parser("campaign", help="Reproducible current-stack handler invariants with retained failures")
    invariant.add_argument("--mode", choices=CAMPAIGNS, default="quick")
    invariant.add_argument("--seed", type=campaign_seed, default=campaign_seed(DEFAULT_CAMPAIGN_SEED))
    invariant.add_argument("--artifacts", help="New evidence directory, relative to the repository or absolute")
    invariant.add_argument("--replay-from", help="Prior campaign directory whose failure corpus should be replayed")
    invariant.add_argument("--reuse-current", action="store_true", help="Reuse current compiler output ONLY when no other build/campaign is running")
    commands.add_parser("check", help="Run current flows, source layout, formatting and Core ABI checks")
    commands.add_parser("docs", help="Check documentation links and contributor entry points")
    commands.add_parser("release", help="Run the full release gate (slow; includes historical evidence)")
    args, forge_args = parser.parse_known_args(argv)
    if forge_args and args.command not in ("build", "test"):
        parser.error("extra Forge arguments are accepted only by build and test")
    if forge_args[:1] == ["--"]:
        forge_args = forge_args[1:]
    if args.command == "doctor":
        return doctor()
    if args.command == "clean":
        return clean()
    if args.command == "campaign":
        return campaign(args)
    if args.command == "build":
        return run(["forge", "build", *forge_args])
    if args.command == "test":
        profile, path = SUITES[args.suite]
        if args.match_path:
            selected = args.match_path.replace("\\", "/").removeprefix("./")
            directory = path.split("**", 1)[0] if path else None
            if directory and (not selected.startswith(directory) or ".." in selected.split("/")):
                parser.error(f"--match-path must be within {directory} for --suite {args.suite}; use --suite all for cross-suite selection")
            path = selected
        command = ["forge", "test", "-vv"]
        if path:
            command += ["--match-path", path]
        return run([*command, *forge_args], profile=profile)
    if args.command == "release":
        if os.name == "nt":
            return run([
                "powershell", "-NoProfile", "-ExecutionPolicy", "Bypass",
                "-File", str(ROOT / "scripts" / "check.ps1"),
            ], profile="default")
        return run(["make", "check"], profile="default")
    if args.command == "docs":
        checks = [python_tool(name) for name in (
            "tools.docs.check_markdown_links", "tools.docs.check_readme", "tools.docs.check_first_30_minutes",
        )]
    else:
        checks = [
            python_tool("tools.build.check_solidity_formatting"),
            python_tool("tools.build.check_solidity_source_layout"),
            ["forge", "build"],
            ["forge", "test", "-vv"],
            python_tool("tools.build.check_abi_compatibility", "--target-only"),
        ]
    for command in checks:
        result = run(command)
        if result:
            return result
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
