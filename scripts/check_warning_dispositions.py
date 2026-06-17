#!/usr/bin/env python3
"""Validate the warning-disposition release baseline."""

from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path


DEFAULT_WARNING_DISPOSITIONS = Path("docs/warning-dispositions.md")

EXPECTED_SOLC_WARNINGS = {
    ("5667", "smart-contracts/RandomizerNXT.sol", 70),
    ("5667", "smart-contracts/RandomizerRNG.sol", 96),
    ("5667", "smart-contracts/RandomizerVRF.sol", 97),
    ("5667", "smart-contracts/StreamCore.sol", 745),
    ("2018", "smart-contracts/RandomizerNXT.sol", 90),
    ("2018", "smart-contracts/RandomizerRNG.sol", 195),
    ("2018", "smart-contracts/RandomizerVRF.sol", 181),
    ("2018", "smart-contracts/StreamCore.sol", 745),
    ("2018", "smart-contracts/StreamMinter.sol", 298),
}

REQUIRED_HEADINGS = [
    (1, "Warning Dispositions"),
    (2, "Maturity And Scope"),
    (2, "Current Warning Baseline"),
    (2, "Fixed In This Pass"),
    (2, "Accepted Solc Warning Dispositions"),
    (2, "Accepted Documentation And Linter Dispositions"),
    (2, "Size And ABI Policy"),
    (2, "Validation Commands"),
    (2, "Maintenance"),
]

REQUIRED_PHRASES = [
    "ONE-007",
    "pre-audit",
    "not production-ready",
    "not a security claim",
    "local baseline",
    "first-party warning noise",
    "ABI-neutral",
    "bytecode-neutral",
    "reviewed disposition",
    "NATSPEC-INVALID-FIRST-PARTY-HEADERS",
    "SOLC-UNUSED-RANDOMIZER-SALT-NXT",
    "SOLC-UNUSED-RANDOMIZER-SALT-RNG",
    "SOLC-UNUSED-RANDOMIZER-SALT-VRF",
    "SOLC-UNUSED-ROYALTY-TOKENID",
    "SOLC-PURE-RANDOMIZER-NXT",
    "SOLC-PURE-RANDOMIZER-RNG",
    "SOLC-PURE-RANDOMIZER-VRF",
    "SOLC-PURE-MINTER-MARKER",
    "SOLC-PURE-ROYALTY",
    "SOLC-TEST-SELFDESTRUCT-HELPERS",
    "DOC-MDBOOK-VRF-HTML",
    "LINT-VENDORED-SIGNEDMATH-TYPECAST",
    "LINT-VENDORED-MATH-SHIFT",
    "LINT-BLOCK-TIMESTAMP-AUCTION",
    "LINT-BLOCK-TIMESTAMP-CORE",
    "LINT-BLOCK-TIMESTAMP-DROPS",
    "LINT-BLOCK-TIMESTAMP-MINTER",
    "LINT-BLOCK-TIMESTAMP-TEST-HELPER",
    "accepted-abi-compatibility",
    "accepted-size-tradeoff",
    "accepted-protocol-time-window",
    "accepted-vendored-provenance",
    "accepted-vendored-prose",
    "accepted-test-only",
    "satellite-first policy",
    "StreamCore",
    "EIP-170",
]

REQUIRED_COMMANDS = [
    "python scripts/test_warning_dispositions.py",
    "python scripts/check_warning_dispositions.py --solc-warnings-log cache/forge-size.log",
    "python scripts/run_forge_size_log.py --log cache/forge-size.log",
    "forge doc --build",
    "python scripts/test_release_manifest.py",
    "python scripts/generate_release_manifest.py --check",
    "python scripts/test_release_checksums.py",
    "python scripts/generate_release_checksums.py --check",
    "make check",
    "powershell -ExecutionPolicy Bypass -File scripts\\check.ps1",
]

REQUIRED_LINK_TARGETS = [
    "docs/tooling.md",
    "docs/audit-package.md",
    "docs/release-readiness.md",
    "docs/status.md",
    "docs/slither.md",
    "docs/architecture.md",
    "docs/vendored-libraries.md",
    "ops/SLITHER_BASELINE.md",
    "ops/EXECUTION_BACKLOG.md",
    "release-artifacts/latest/risk-register.json",
    "release-artifacts/latest/bytecode-release-proof.json",
    "smart-contracts/AuctionContract.sol",
    "smart-contracts/DependencyRegistry.sol",
    "smart-contracts/NFTdelegation.sol",
    "smart-contracts/RandomizerNXT.sol",
    "smart-contracts/RandomizerRNG.sol",
    "smart-contracts/RandomizerVRF.sol",
    "smart-contracts/StreamAdmins.sol",
    "smart-contracts/StreamCore.sol",
    "smart-contracts/StreamCuratorsPool.sol",
    "smart-contracts/StreamDrops.sol",
    "smart-contracts/StreamMinter.sol",
    "smart-contracts/StreamMetadataRenderer.sol",
    "smart-contracts/VRFConsumerBaseV2.sol",
    "smart-contracts/SignedMath.sol",
    "smart-contracts/Math.sol",
    "test/StreamAuctionPayments.t.sol",
    "test/StreamCuratorsPool.t.sol",
    "test/StreamEmergencyWithdraw.t.sol",
    "test/StreamFixedPricePayments.t.sol",
    "test/StreamRandomizerPayments.t.sol",
    "test/helpers/ProtocolStateMachine.sol",
]

INVALID_NATSPEC_TAGS = (
    "@title:",
    "@date:",
    "@version:",
    "@author:",
    "@notes:",
    "@contributors:",
)

SOURCE_MARKERS = {
    "smart-contracts/RandomizerNXT.sol": [
        "function calculateTokenHash(uint256 _collectionID, uint256 _mintIndex, uint256 _saltfun_o)",
        "function isRandomizerContract() external view returns (bool)",
    ],
    "smart-contracts/RandomizerRNG.sol": [
        "function calculateTokenHash(uint256 _collectionID, uint256 _mintIndex, uint256 _saltfun_o)",
        "function isRandomizerContract() external view returns (bool)",
    ],
    "smart-contracts/RandomizerVRF.sol": [
        "function calculateTokenHash(uint256 _collectionID, uint256 _mintIndex, uint256 _saltfun_o)",
        "function isRandomizerContract() external view returns (bool)",
    ],
    "smart-contracts/StreamCore.sol": [
        "function royaltyInfo(uint256 tokenId, uint256 salePrice)",
        "block.timestamp",
    ],
    "smart-contracts/StreamMinter.sol": [
        "function isMinterContract() external view returns (bool)",
        "block.timestamp",
    ],
    "smart-contracts/VRFConsumerBaseV2.sol": [
        "constructor(<other arguments>, address _vrfCoordinator, address _link)",
        "<initialization with other arguments goes here>",
    ],
    "smart-contracts/SignedMath.sol": ["library SignedMath"],
    "smart-contracts/Math.sol": ["library Math"],
    "smart-contracts/AuctionContract.sol": ["block.timestamp"],
    "smart-contracts/StreamDrops.sol": ["block.timestamp"],
    "test/helpers/ProtocolStateMachine.sol": ["block.timestamp"],
    "test/StreamAuctionPayments.t.sol": ["selfdestruct(target);"],
    "test/StreamCuratorsPool.t.sol": ["selfdestruct(target);"],
    "test/StreamEmergencyWithdraw.t.sol": ["selfdestruct(target);"],
    "test/StreamFixedPricePayments.t.sol": ["selfdestruct(target);"],
    "test/StreamRandomizerPayments.t.sol": ["selfdestruct(target);"],
}

HEADING_RE = re.compile(r"^(#{1,6})\s+(.+?)\s*$", re.MULTILINE)
LINK_RE = re.compile(r"\[([^\]]+)\]\(([^)\s]+)(?:\s+\"[^\"]*\")?\)")
SOLC_WARNING_RE = re.compile(r"Warning \((?P<code>[0-9]+)\):")
SOLC_SOURCE_RE = re.compile(
    r"-->\s+(?P<path>[^:\r\n]+):(?P<line>[0-9]+):(?P<column>[0-9]+)"
)


class WarningDispositionError(ValueError):
    """Raised when the warning-disposition baseline is incomplete."""


def normalize_repo_path(path: Path, repo_root: Path) -> str:
    """Return a repository-relative POSIX path or reject path escapes."""
    try:
        return path.resolve().relative_to(repo_root.resolve()).as_posix()
    except ValueError as exc:
        raise WarningDispositionError(f"linked path escapes repository: {path}") from exc


def normalize_whitespace(text: str) -> str:
    """Collapse whitespace for resilient source and Markdown comparisons."""
    return re.sub(r"\s+", " ", text)


def markdown_headings(text: str) -> set[tuple[int, str]]:
    """Extract Markdown headings as level/title pairs."""
    headings = set()
    for match in HEADING_RE.finditer(text):
        level = len(match.group(1))
        title = match.group(2).strip().rstrip("#").strip()
        headings.add((level, title))
    return headings


def normalized_link_target(raw_target: str) -> str | None:
    """Return a local Markdown link path without anchors or query strings."""
    target = raw_target.strip()
    if not target or target.startswith("#"):
        return None
    if "://" in target or target.startswith("mailto:"):
        return None

    path_part = target.split("#", 1)[0].split("?", 1)[0]
    return path_part or None


def label_looks_like_repo_path(label: str) -> bool:
    """Return true when a link label should match its resolved repo path."""
    normalized = label.strip().strip("`")
    return "/" in normalized or "\\" in normalized


def linked_repo_paths(repo_root: Path, document_path: Path, text: str) -> set[str]:
    """Collect existing repository-relative file links from Markdown text."""
    links = set()
    missing = []
    for match in LINK_RE.finditer(text):
        label = match.group(1).strip().strip("`")
        target = normalized_link_target(match.group(2))
        if target is None:
            continue

        target_path = Path(target)
        if not target_path.is_absolute():
            target_path = document_path.parent / target_path

        resolved = target_path.resolve()
        normalized = normalize_repo_path(resolved, repo_root)
        if not resolved.exists():
            missing.append(normalized)
            continue
        if label_looks_like_repo_path(label) and label.replace("\\", "/") != normalized:
            raise WarningDispositionError(f"link label `{label}` points to `{normalized}`")
        links.add(normalized)

    if missing:
        raise WarningDispositionError(
            "warning disposition doc links to missing files: "
            + ", ".join(sorted(set(missing)))
        )
    return links


def missing_phrases(text: str, phrases: list[str]) -> list[str]:
    """Return required phrases not found after whitespace normalization."""
    normalized_text = normalize_whitespace(text)
    return [
        phrase
        for phrase in phrases
        if normalize_whitespace(phrase) not in normalized_text
    ]


def validate_no_invalid_natspec_tags(repo_root: Path) -> None:
    """Reject legacy colon-suffixed NatSpec tags in Solidity sources."""
    contracts_dir = repo_root / "smart-contracts"
    if not contracts_dir.is_dir():
        return

    violations = []
    for path in sorted(contracts_dir.rglob("*.sol")):
        relative = path.resolve().relative_to(repo_root.resolve()).as_posix()
        if relative.startswith("smart-contracts/lib/"):
            continue
        text = path.read_text(encoding="utf-8")
        for tag in INVALID_NATSPEC_TAGS:
            if tag in text:
                violations.append(f"{relative}: {tag}")

    if violations:
        raise WarningDispositionError(
            "invalid NatSpec header tags remain: " + ", ".join(violations)
        )


def validate_source_markers(repo_root: Path) -> None:
    """Ensure accepted warning rows still match the source surface."""
    missing = []
    for relative, snippets in SOURCE_MARKERS.items():
        source_path = repo_root / relative
        if not source_path.is_file():
            missing.append(f"{relative}: missing file")
            continue
        source = normalize_whitespace(source_path.read_text(encoding="utf-8"))
        for snippet in snippets:
            if normalize_whitespace(snippet) not in source:
                missing.append(f"{relative}: {snippet}")

    if missing:
        raise WarningDispositionError(
            "warning disposition source markers drifted: " + ", ".join(missing)
        )


def normalize_solidity_warning_path(raw_path: str) -> str:
    """Normalize a Solidity warning source path to repository POSIX form."""
    return raw_path.strip().replace("\\", "/")


def parse_solc_warnings(log_text: str) -> set[tuple[str, str, int]]:
    """Extract solc warning code, source path, and source line from forge output."""
    warnings = set()
    pending_code: str | None = None
    for line in log_text.splitlines():
        warning_match = SOLC_WARNING_RE.search(line)
        if warning_match:
            pending_code = warning_match.group("code")
            continue
        if pending_code is None:
            continue
        source_match = SOLC_SOURCE_RE.search(line)
        if not source_match:
            continue
        warnings.add(
            (
                pending_code,
                normalize_solidity_warning_path(source_match.group("path")),
                int(source_match.group("line")),
            )
        )
        pending_code = None
    return warnings


def format_solc_warning(warning: tuple[str, str, int]) -> str:
    """Render a compact solc warning identifier."""
    code, path, line = warning
    return f"Warning({code}) {path}:{line}"


def validate_solc_warning_log(log_path: Path) -> None:
    """Validate live forge output against the reviewed solc warning baseline."""
    if not log_path.is_file():
        raise WarningDispositionError(f"missing solc warning log: {log_path}")

    actual = parse_solc_warnings(log_path.read_text(encoding="utf-8"))
    missing = sorted(EXPECTED_SOLC_WARNINGS - actual)
    unexpected = sorted(actual - EXPECTED_SOLC_WARNINGS)
    if missing or unexpected:
        parts = []
        if missing:
            parts.append(
                "missing expected warning(s): "
                + ", ".join(format_solc_warning(warning) for warning in missing)
            )
        if unexpected:
            parts.append(
                "unexpected warning(s): "
                + ", ".join(format_solc_warning(warning) for warning in unexpected)
            )
        raise WarningDispositionError("solc warning baseline drifted; " + "; ".join(parts))


def validate_warning_dispositions(repo_root: Path, document_path: Path) -> None:
    """Validate the warning-disposition document and source anchors."""
    if not document_path.is_file():
        relative = normalize_repo_path(document_path, repo_root)
        raise WarningDispositionError(f"missing warning disposition doc: {relative}")

    text = document_path.read_text(encoding="utf-8")
    headings = markdown_headings(text)
    missing_headings = [
        f"{'#' * level} {title}"
        for level, title in REQUIRED_HEADINGS
        if (level, title) not in headings
    ]
    if missing_headings:
        raise WarningDispositionError(
            "warning disposition doc is missing required headings: "
            + ", ".join(missing_headings)
        )

    missing_required_phrases = missing_phrases(text, REQUIRED_PHRASES)
    if missing_required_phrases:
        raise WarningDispositionError(
            "warning disposition doc is missing required content: "
            + ", ".join(missing_required_phrases)
        )

    command_lines = {line.strip() for line in text.splitlines()}
    missing_commands = [
        command for command in REQUIRED_COMMANDS if command not in command_lines
    ]
    if missing_commands:
        raise WarningDispositionError(
            "warning disposition doc is missing required commands: "
            + ", ".join(missing_commands)
        )

    links = linked_repo_paths(repo_root, document_path, text)
    missing_links = [
        target for target in REQUIRED_LINK_TARGETS if target not in links
    ]
    if missing_links:
        raise WarningDispositionError(
            "warning disposition doc is missing required links: "
            + ", ".join(missing_links)
        )

    validate_no_invalid_natspec_tags(repo_root)
    validate_source_markers(repo_root)


def parse_args(argv: list[str]) -> argparse.Namespace:
    """Parse warning-disposition checker options."""
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repo-root", type=Path, default=Path.cwd())
    parser.add_argument(
        "--warning-dispositions",
        type=Path,
        default=DEFAULT_WARNING_DISPOSITIONS,
    )
    parser.add_argument(
        "--solc-warnings-log",
        type=Path,
        help="Optional forge build output log to compare with the accepted warning baseline.",
    )
    return parser.parse_args(argv)


def main(argv: list[str] | None = None) -> int:
    """Run the warning-disposition checker CLI."""
    args = parse_args(sys.argv[1:] if argv is None else argv)
    repo_root = args.repo_root.resolve()
    document_path = args.warning_dispositions
    if not document_path.is_absolute():
        document_path = repo_root / document_path
    solc_warnings_log = args.solc_warnings_log
    if solc_warnings_log is not None and not solc_warnings_log.is_absolute():
        solc_warnings_log = repo_root / solc_warnings_log

    try:
        validate_warning_dispositions(repo_root, document_path.resolve())
        if solc_warnings_log is not None:
            validate_solc_warning_log(solc_warnings_log.resolve())
    except WarningDispositionError as exc:
        print(f"warning disposition check failed: {exc}", file=sys.stderr)
        return 1

    print("warning disposition baseline is current")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
