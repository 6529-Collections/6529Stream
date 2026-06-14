#!/usr/bin/env python3
"""Check the scoped Solidity formatting baseline."""

from __future__ import annotations

import argparse
import os
import shutil
import subprocess
import sys
from pathlib import Path


SMART_CONTRACTS_DIR = Path("smart-contracts")

DEFERRED_FORMATTING_FILES = frozenset(
    {
        "smart-contracts/Address.sol",
        "smart-contracts/Base64.sol",
        "smart-contracts/Context.sol",
        "smart-contracts/ERC165.sol",
        "smart-contracts/ERC2981.sol",
        "smart-contracts/ERC721.sol",
        "smart-contracts/ERC721Enumerable.sol",
        "smart-contracts/IERC165.sol",
        "smart-contracts/IERC2981.sol",
        "smart-contracts/IERC721.sol",
        "smart-contracts/IERC721Metadata.sol",
        "smart-contracts/IERC721Receiver.sol",
        "smart-contracts/Math.sol",
        "smart-contracts/MerkleProof.sol",
        "smart-contracts/Ownable.sol",
        "smart-contracts/ReentrancyGuard.sol",
        "smart-contracts/SignedMath.sol",
    }
)


class SolidityFormattingError(RuntimeError):
    pass


def normalize_path(path: str | Path) -> str:
    return str(path).replace("\\", "/").removeprefix("./")


def discover_solidity_files(repo_root: Path) -> list[str]:
    source_dir = repo_root / SMART_CONTRACTS_DIR
    return sorted(
        normalize_path(path.relative_to(repo_root))
        for path in source_dir.rglob("*.sol")
        if path.is_file()
    )


def formatting_required_files(solidity_files: list[str]) -> list[str]:
    return sorted(path for path in solidity_files if path not in DEFERRED_FORMATTING_FILES)


def parse_fmt_diff_files(output: str) -> list[str]:
    diff_files = []
    for line in output.splitlines():
        if not line.startswith("Diff in "):
            continue
        raw_path = line.removeprefix("Diff in ").removesuffix(":").strip()
        diff_files.append(normalize_path(raw_path))
    return sorted(dict.fromkeys(diff_files))


def validate_deferred_baseline(solidity_files: list[str], diff_files: list[str]) -> None:
    known_files = set(solidity_files)
    missing_deferred = sorted(DEFERRED_FORMATTING_FILES - known_files)
    if missing_deferred:
        raise SolidityFormattingError(
            "deferred formatting baseline references missing file(s): "
            + ", ".join(missing_deferred)
        )

    diff_set = set(diff_files)
    unexpected = sorted(diff_set - DEFERRED_FORMATTING_FILES)
    if unexpected:
        raise SolidityFormattingError(
            "unexpected unformatted Solidity file(s) outside the deferred baseline: "
            + ", ".join(unexpected)
        )

    fixed_without_baseline_update = sorted(DEFERRED_FORMATTING_FILES - diff_set)
    if fixed_without_baseline_update:
        raise SolidityFormattingError(
            "deferred formatting baseline changed; remove fixed file(s) from "
            "DEFERRED_FORMATTING_FILES and update docs: "
            + ", ".join(fixed_without_baseline_update)
        )


def forge_environment() -> dict[str, str]:
    env = os.environ.copy()
    foundry_bin = Path.home() / ".foundry" / "bin"
    if foundry_bin.exists():
        env["PATH"] = f"{foundry_bin}{os.pathsep}{env.get('PATH', '')}"
    return env


def resolve_forge(forge_bin: str, env: dict[str, str]) -> str:
    configured = Path(forge_bin)
    if configured.is_file():
        return str(configured)

    resolved = shutil.which(forge_bin, path=env.get("PATH"))
    if resolved is not None:
        return resolved

    foundry_bin = Path.home() / ".foundry" / "bin"
    candidates = [foundry_bin / forge_bin]
    if not forge_bin.lower().endswith(".exe"):
        candidates.append(foundry_bin / f"{forge_bin}.exe")
    for candidate in candidates:
        if candidate.is_file():
            return str(candidate)

    raise SolidityFormattingError(
        f"{forge_bin!r} was not found. Run the repository bootstrap script, then retry."
    )


def run_forge_fmt_check(
    repo_root: Path, forge: str, paths: list[str], env: dict[str, str]
) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        [forge, "fmt", "--check", *paths],
        cwd=repo_root,
        check=False,
        encoding="utf-8",
        env=env,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
    )


def format_output_sample(output: str, limit: int = 80) -> str:
    lines = output.splitlines()
    if len(lines) <= limit:
        return output.strip()
    sample = "\n".join(lines[:limit]).strip()
    return f"{sample}\n... truncated {len(lines) - limit} additional line(s)"


def check_solidity_formatting(repo_root: Path, forge_bin: str) -> None:
    repo_root = repo_root.resolve()
    env = forge_environment()
    forge = resolve_forge(forge_bin, env)
    solidity_files = discover_solidity_files(repo_root)
    required_files = formatting_required_files(solidity_files)

    required_result = run_forge_fmt_check(repo_root, forge, required_files, env)
    if required_result.returncode != 0:
        diff_files = parse_fmt_diff_files(required_result.stdout)
        formatted_diff_files = ", ".join(diff_files) if diff_files else "(none parsed)"
        raise SolidityFormattingError(
            "formatting-required Solidity files failed forge fmt: "
            + formatted_diff_files
            + "\n\n"
            + format_output_sample(required_result.stdout)
        )

    raw_result = run_forge_fmt_check(repo_root, forge, [str(SMART_CONTRACTS_DIR)], env)
    diff_files = parse_fmt_diff_files(raw_result.stdout)
    if raw_result.returncode != 0 and not diff_files:
        raise SolidityFormattingError(
            "raw forge fmt check failed without parseable formatting diffs:\n\n"
            + format_output_sample(raw_result.stdout)
        )
    validate_deferred_baseline(solidity_files, diff_files)

    print(
        "Solidity formatting scoped gate passed: "
        f"{len(required_files)} required file(s) formatted; "
        f"{len(DEFERRED_FORMATTING_FILES)} deferred file(s) match the documented baseline."
    )


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="Check the scoped Solidity formatting baseline.")
    parser.add_argument("--repo-root", type=Path, default=Path(__file__).resolve().parents[1])
    parser.add_argument("--forge-bin", default="forge")
    return parser


def main(argv: list[str] | None = None) -> int:
    parser = build_parser()
    args = parser.parse_args(argv)
    try:
        check_solidity_formatting(args.repo_root, args.forge_bin)
    except SolidityFormattingError as exc:
        print(f"Solidity formatting check failed: {exc}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
