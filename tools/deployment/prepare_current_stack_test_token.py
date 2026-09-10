"""Compile the local scenario token without modifying a deployment compilation."""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import re
import subprocess
from pathlib import Path

SOURCE = "test/mocks/MockStreamPaymentToken.sol"
CONTRACT = "MockStreamPaymentToken"
ARTIFACT = f"out/{CONTRACT}.sol/{CONTRACT}.json"
CONFIG = b'''[profile.default]
src = "test/mocks"
test = "unused-test"
script = "unused-script"
libs = []
out = "out"
cache_path = "cache"
solc_version = "0.8.19"
auto_detect_solc = false
optimizer = true
optimizer_runs = 200
evm_version = "paris"
via_ir = true
bytecode_hash = "none"
cbor_metadata = false
build_info = true
'''


def require(condition: bool, message: str) -> None:
    if not condition:
        raise ValueError(message)


def digest(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def encoded(value: object) -> bytes:
    return (json.dumps(value, indent=2, sort_keys=True) + "\n").encode("utf-8")


def child_environment() -> dict[str, str]:
    # Only the child compiler receives this environment. Caller settings, including
    # deployment output paths and profile, are neither inherited nor changed.
    return {key: value for key, value in os.environ.items()
            if not key.upper().startswith(("FOUNDRY_", "DAPP_"))}


def checked_path(path: Path) -> Path:
    path = path.absolute()
    for part in (path, *path.parents):
        require(not part.is_symlink() and not part.is_junction(), f"linked path is not supported: {part}")
    return path.resolve()


def validate(directory: Path, source: bytes) -> dict:
    require((directory / SOURCE).read_bytes() == source, "prepared test-token source differs; use a new output directory")
    require((directory / "foundry.toml").read_bytes() == CONFIG, "prepared test-token compiler configuration differs")
    infos = list((directory / "out/build-info").glob("*.json"))
    require(len(infos) == 1, "test token requires exactly one complete compiler input")
    info_bytes = infos[0].read_bytes()
    info = json.loads(info_bytes)
    require(info["solcVersion"] == "0.8.19", "test-token compiler version differs")
    compiler_input = info["input"]
    require(compiler_input["language"] == "Solidity", "test-token compiler language differs")
    require(compiler_input["sources"] == {SOURCE: {"content": source.decode("utf-8")}}, "test-token compiler source is stale or includes other sources")
    settings = dict(compiler_input["settings"])
    settings.pop("outputSelection", None)
    require(settings == {
        "optimizer": {"enabled": True, "runs": 200},
        "metadata": {"useLiteralContent": False, "bytecodeHash": "none", "appendCBOR": False},
        "evmVersion": "paris", "viaIR": True, "libraries": {},
    }, "test-token compiler settings differ")
    output = info["output"]
    require(not any(item.get("severity") == "error" for item in output.get("errors", [])), "test-token compiler reported an error")
    require(set(output["contracts"]) == {SOURCE} and set(output["contracts"][SOURCE]) == {CONTRACT}, "unexpected test-token compiler outputs")
    compiled = output["contracts"][SOURCE][CONTRACT]
    artifact_bytes = (directory / ARTIFACT).read_bytes()
    artifact = json.loads(artifact_bytes)
    require(artifact["abi"] == compiled["abi"], "test-token ABI differs from compiler output")
    for field in ("bytecode", "deployedBytecode"):
        actual, expected = artifact[field], compiled["evm"][field]
        require(actual["object"] == "0x" + expected["object"] and bool(expected["object"]), "test-token bytecode differs from compiler output")
        require(not actual.get("linkReferences") and not expected.get("linkReferences"), "unexpected test-token library links")
    require(not artifact["deployedBytecode"].get("immutableReferences") and not compiled["evm"]["deployedBytecode"].get("immutableReferences"), "unexpected test-token immutables")
    return {
        "schema": "6529stream.local-test-token-compilation.v1",
        "scope": "local chain 31337 scenario fixture; not a production deployment artifact",
        "source_path": SOURCE, "source_sha256": digest(source),
        "config_sha256": digest(CONFIG), "compiler_input_sha256": digest(encoded(compiler_input)),
        "compiler": "Solc 0.8.19 / Foundry 1.7.1 / viaIR / optimizer 200 / Paris",
        "artifact_path": ARTIFACT, "artifact_sha256": digest(artifact_bytes),
        "build_info_path": infos[0].relative_to(directory).as_posix(), "build_info_sha256": digest(info_bytes),
    }


def prepare(root: Path, destination: Path, deployment_artifacts: Path) -> dict:
    root, destination, deployment_artifacts = map(checked_path, (root, destination, deployment_artifacts))
    require(deployment_artifacts.is_dir(), "retained deployment artifact directory is missing")
    require(not (destination == deployment_artifacts or destination.is_relative_to(deployment_artifacts)
                 or deployment_artifacts.is_relative_to(destination)), "test-token output overlaps deployment artifacts")
    require(not root.is_relative_to(destination) and not destination.is_relative_to(root / "test"), "test-token output overlaps repository sources")
    source = (root / SOURCE).read_bytes()
    manifest = destination / "test-token-compilation.json"
    environment = child_environment()
    version = subprocess.run(["forge", "--version"], check=True, capture_output=True, text=True, env=environment).stdout
    require(re.search(r"\bVersion: 1\.7\.1(?:\b|[-+])", version) is not None, "Foundry 1.7.1 is required")
    if not manifest.exists():
        require(not destination.exists(), "incomplete test-token preparation; preserve it and choose a new scenario output directory")
        destination.mkdir(parents=True)
        (destination / SOURCE).parent.mkdir(parents=True)
        (destination / SOURCE).write_bytes(source)
        (destination / "foundry.toml").write_bytes(CONFIG)
        command = ["forge", "build", "--root", str(destination), "--config-path", str(destination / "foundry.toml")]
        (destination / "command.json").write_bytes(encoded(command))
        with (destination / "build.log").open("wb") as log:
            result = subprocess.run(command, cwd=destination, env=environment, stdout=log, stderr=subprocess.STDOUT)
        (destination / "build.exit").write_text(str(result.returncode) + "\n", encoding="utf-8")
        require(result.returncode == 0, f"test-token compilation failed; see {destination / 'build.log'}")
        report = validate(destination, source)
        require((root / SOURCE).read_bytes() == source, "test-token source changed during compilation")
        manifest.write_bytes(encoded(report))
    else:
        report = validate(destination, source)
        require(manifest.read_bytes() == encoded(report), "retained test-token compilation binding differs")
    return {**report, "artifact_path": str(destination / ARTIFACT), "manifest_path": str(manifest)}


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output-dir", required=True, type=Path)
    parser.add_argument("--deployment-artifacts", required=True, type=Path)
    args = parser.parse_args()
    try:
        print(json.dumps(prepare(Path(__file__).resolve().parents[2], args.output_dir, args.deployment_artifacts)))
        return 0
    except (OSError, ValueError, KeyError, subprocess.SubprocessError) as error:
        parser.exit(1, f"test-token preparation failed: {error}\n")


if __name__ == "__main__":
    raise SystemExit(main())
