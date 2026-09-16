#!/usr/bin/env python3
"""Run the deployment-slot tests and protected script in an isolated Foundry project."""
from __future__ import annotations

import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import tempfile
import time

ROOT = Path(__file__).resolve().parents[2]
FILES = (
    "script/current/StreamDeploymentSlot.sol",
    "test/current/StreamDeploymentSlot.t.sol",
    "test/helpers/OfficialSafeFixture.sol",
    "test/fixtures/deployment-planner/ProtectedDeploymentSlot.s.sol",
    "test/fixtures/safe/1.4.1.json",
)
CONFIG = """[profile.default]
src = "script/current"
test = "test/current"
script = "test/fixtures/deployment-planner"
out = "out-default"
cache_path = "cache-default"
libs = []
solc_version = "0.8.19"
auto_detect_solc = false
evm_version = "paris"
optimizer = true
optimizer_runs = 200
bytecode_hash = "none"
cbor_metadata = false
build_info = true
extra_output = ["metadata", "storageLayout"]
# Exercise the helper's own 24,576-byte product guard inside the larger test harness.
code_size_limit = 100000
gas_limit = 1000000000
fs_permissions = [{access="read",path="./test/fixtures"}]
[profile.default.fuzz]
runs = 256
seed = "0x6529"
"""


def run(output: Path, forge: str) -> None:
    project = output / "project"
    project.mkdir()
    originals = {name: (ROOT / name).read_bytes() for name in FILES}
    for name, raw in originals.items():
        target = project / name
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_bytes(raw)
    (project / "foundry.toml").write_bytes(CONFIG.encode("utf-8"))
    expected = sorted(re.findall(r"\bfunction\s+(test\w+)\s*\(", originals[FILES[1]].decode("utf-8")))
    if len(expected) != 10 or len(set(expected)) != 10:
        raise RuntimeError("Expected exactly ten distinct deployment-slot cases")
    report = {
        "qualification": "Focused deployment helper evidence, not complete Stream assembly or transaction capacity.",
        "sources": {name: {"sha256": hashlib.sha256(raw).hexdigest(), "bytes": len(raw)} for name, raw in originals.items()},
        "configSha256": hashlib.sha256(CONFIG.encode("utf-8")).hexdigest(),
        "results": [],
    }
    # Keep installed tool locations while preventing ambient profile/RPC settings from
    # selecting different compiler semantics or turning the local rehearsal into a fork.
    environment = {key: value for key, value in os.environ.items()
                   if not key.upper().startswith(("FOUNDRY_", "DAPP_"))
                   and key.upper() not in {"ETH_RPC_URL", "ETH_RPC_JWT", "ETH_RPC_HEADERS"}}
    environment["FOUNDRY_PROFILE"] = "default"
    ir = ["--via-ir", "--out", "out-ir", "--cache-path", "cache-ir"]
    commands = (
        ("default", [forge, "test", "--root", str(project), "-vvv"]),
        ("ir", [forge, "test", "--root", str(project), *ir, "-vvv"]),
        ("protected-script", [forge, "script", "--root", str(project),
         "test/fixtures/deployment-planner/ProtectedDeploymentSlot.s.sol:ProtectedDeploymentSlot",
         "--sig", "run()", *ir, "-vvv"]),
    )
    for name, command in commands:
        log = output / (name + ".log")
        started = time.monotonic()
        with log.open("wb") as stream:
            result = subprocess.run(command, cwd=project, env=environment, stdout=stream, stderr=subprocess.STDOUT, check=False)
        raw_log = log.read_bytes()
        text = raw_log.decode("utf-8", errors="replace")
        passed = re.findall(r"^\[PASS\]\s+(test\w+)\(", text, re.MULTILINE)
        row = {"name": name, "command": command, "exitCode": result.returncode,
               "seconds": time.monotonic() - started, "logSha256": hashlib.sha256(raw_log).hexdigest(), "passed": passed}
        report["results"].append(row)
        (output / "report.json").write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
        if result.returncode or (name != "protected-script" and sorted(passed) != expected):
            raise RuntimeError(name + " failed or did not execute the exact ten cases:\n" + text[-12000:])
        if name == "protected-script" and "Script ran successfully." not in text:
            raise RuntimeError("Protected local script success marker is missing:\n" + text[-12000:])
        if (project / "foundry.toml").read_bytes() != CONFIG.encode("utf-8"):
            raise RuntimeError("Captured Foundry configuration changed during execution")
        for source, raw in originals.items():
            if (project / source).read_bytes() != raw:
                raise RuntimeError("Captured source changed during execution: " + source)
        print(name + ": passed" + (" (10 tests)" if passed else " (local script simulation)"), flush=True)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, help="Retain logs and native compiler artifacts in a new directory")
    args = parser.parse_args()
    forge = shutil.which("forge")
    if not forge:
        parser.error("Foundry forge is required; follow docs/first-30-minutes.md")
    try:
        if args.output:
            output = args.output.resolve()
            output.mkdir(parents=True, exist_ok=False)
            run(output, forge)
            print("Evidence: " + str(output))
        else:
            with tempfile.TemporaryDirectory(prefix="stream-deployment-slot-") as directory:
                run(Path(directory).resolve(), forge)
    except (OSError, RuntimeError) as error:
        print(str(error))
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
