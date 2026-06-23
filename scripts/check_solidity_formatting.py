#!/usr/bin/env python3
"""Check the scoped Solidity formatting policy."""

from __future__ import annotations

import argparse
import os
import re
import shutil
import subprocess
import sys
from pathlib import Path


SMART_CONTRACTS_DIR = Path("smart-contracts")

VENDORED_FORMATTING_EXEMPTIONS = frozenset(
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
    return sorted(path for path in solidity_files if path not in VENDORED_FORMATTING_EXEMPTIONS)


def parse_fmt_diff_files(output: str) -> list[str]:
    diff_files = []
    for line in output.splitlines():
        if not line.startswith("Diff in "):
            continue
        raw_path = line.removeprefix("Diff in ").removesuffix(":").strip()
        diff_files.append(normalize_path(raw_path))
    return sorted(dict.fromkeys(diff_files))


def fmt_diff_blocks(output: str) -> dict[str, str]:
    """Return forge fmt diff output grouped by normalized path."""
    blocks: dict[str, list[str]] = {}
    current_path: str | None = None
    for line in output.splitlines():
        if line.startswith("Diff in "):
            raw_path = line.removeprefix("Diff in ").removesuffix(":").strip()
            current_path = normalize_path(raw_path)
            blocks.setdefault(current_path, [line])
            continue
        if current_path is not None:
            blocks[current_path].append(line)
    return {path: "\n".join(lines) for path, lines in blocks.items()}


FMT_DIFF_LINE_RE = re.compile(r"^\s*[0-9]+\s+\|(?P<marker>[+-])(?P<content>.*)$")


def is_line_ending_only_fmt_diff(block: str) -> bool:
    """Return true when forge fmt only reports identical removed/added text."""
    removed: list[str] = []
    added: list[str] = []
    for line in block.splitlines():
        match = FMT_DIFF_LINE_RE.match(line)
        if not match:
            continue
        if match.group("marker") == "-":
            removed.append(match.group("content"))
        else:
            added.append(match.group("content"))
    return bool(removed or added) and removed == added


def filter_line_ending_only_fmt_diffs(output: str, diff_files: list[str]) -> list[str]:
    """Remove CRLF-only forge fmt diffs while retaining real formatting diffs."""
    blocks = fmt_diff_blocks(output)
    return [
        path
        for path in diff_files
        if not is_line_ending_only_fmt_diff(blocks.get(path, ""))
    ]


def validate_vendored_exemptions(solidity_files: list[str], diff_files: list[str]) -> None:
    known_files = set(solidity_files)
    missing_exemptions = sorted(VENDORED_FORMATTING_EXEMPTIONS - known_files)
    if missing_exemptions:
        raise SolidityFormattingError(
            "vendored formatting exemption references missing file(s): "
            + ", ".join(missing_exemptions)
        )

    diff_set = set(diff_files)
    unexpected = sorted(diff_set - VENDORED_FORMATTING_EXEMPTIONS)
    if unexpected:
        raise SolidityFormattingError(
            "unexpected unformatted Solidity file(s) outside the vendored formatting exemptions: "
            + ", ".join(unexpected)
        )

    formatted_without_policy_update = sorted(VENDORED_FORMATTING_EXEMPTIONS - diff_set)
    if formatted_without_policy_update:
        raise SolidityFormattingError(
            "vendored formatting exemption set changed; remove formatted file(s) "
            "from VENDORED_FORMATTING_EXEMPTIONS and update provenance docs: "
            + ", ".join(formatted_without_policy_update)
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


def required_formatting_diff_files(output: str) -> list[str]:
    parsed_diff_files = parse_fmt_diff_files(output)
    diff_files = filter_line_ending_only_fmt_diffs(output, parsed_diff_files)
    if not diff_files and not parsed_diff_files:
        raise SolidityFormattingError(
            "formatting-required Solidity files failed forge fmt without "
            "parseable formatting diffs:\n\n"
            + format_output_sample(output)
        )
    return diff_files


def check_solidity_formatting(repo_root: Path, forge_bin: str) -> None:
    repo_root = repo_root.resolve()
    env = forge_environment()
    forge = resolve_forge(forge_bin, env)
    solidity_files = discover_solidity_files(repo_root)
    required_files = formatting_required_files(solidity_files)

    required_result = run_forge_fmt_check(repo_root, forge, required_files, env)
    if required_result.returncode != 0:
        diff_files = required_formatting_diff_files(required_result.stdout)
        if not diff_files:
            diff_files = []
        else:
            formatted_diff_files = ", ".join(diff_files)
            raise SolidityFormattingError(
                "formatting-required Solidity files failed forge fmt: "
                + formatted_diff_files
                + "\n\n"
                + format_output_sample(required_result.stdout)
            )

    raw_result = run_forge_fmt_check(repo_root, forge, [str(SMART_CONTRACTS_DIR)], env)
    raw_diff_files = parse_fmt_diff_files(raw_result.stdout)
    diff_files = sorted(
        set(filter_line_ending_only_fmt_diffs(raw_result.stdout, raw_diff_files))
        | (set(raw_diff_files) & VENDORED_FORMATTING_EXEMPTIONS)
    )
    if raw_result.returncode != 0 and not diff_files:
        raise SolidityFormattingError(
            "raw forge fmt check failed without parseable formatting diffs:\n\n"
            + format_output_sample(raw_result.stdout)
        )
    validate_vendored_exemptions(solidity_files, diff_files)

    print(
        "Solidity formatting scoped gate passed: "
        f"{len(required_files)} required file(s) formatted; "
        f"{len(VENDORED_FORMATTING_EXEMPTIONS)} vendored/provenance exemption file(s) "
        "match the documented policy."
    )


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="Check the scoped Solidity formatting policy.")
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
