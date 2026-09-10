#!/usr/bin/env python3
"""Portable entry point for developing and checking the supported Stream stack.

Run from any directory. Only the child process receives the selected Foundry
profile; this command never changes shell configuration or installs software.
"""

from __future__ import annotations

import argparse
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys


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
