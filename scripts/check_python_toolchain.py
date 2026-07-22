#!/usr/bin/env python3
"""Validate the reproducible Python toolchain used by CI and release mode."""

from __future__ import annotations

import re
import sys
from pathlib import Path


PYTHON_VERSION = "3.12.13"
SETUP_PYTHON_SHA = "ece7cb06caefa5fff74198d8649806c4678c61a1"
FOUNDRY_TOOLCHAIN_SHA = "c7450ba673e133f5ee30098b3b54f444d3a2ca2d"
FOUNDRY_VERSION = "v1.7.1"
LOCK_INSTALL_COMMAND = (
    "python -m pip install --disable-pip-version-check --require-hashes "
    "--only-binary=:all: -r requirements-tools.lock"
)
PIP_CHECK_COMMAND = "python -m pip check"
PLAYWRIGHT_INSTALL_COMMAND = "python -m playwright install --with-deps chromium"

DIRECT_REQUIREMENTS_PATH = Path("requirements-tools.txt")
LOCK_PATH = Path("requirements-tools.lock")
WORKFLOW_PATHS = (
    Path(".github/workflows/ci.yml"),
    Path(".github/workflows/release-mode.yml"),
)
RELEASE_WORKFLOW_PATH = Path(".github/workflows/release-mode.yml")
RELEASE_BRANCH_GUARD = "- name: Require protected default branch"
PROVENANCE_PATHS = (
    DIRECT_REQUIREMENTS_PATH,
    LOCK_PATH,
    *WORKFLOW_PATHS,
    Path("scripts/check_python_toolchain.py"),
    Path("scripts/test_python_toolchain.py"),
)
EXPECTED_DIRECT_NAMES = {
    "eth-hash",
    "playwright",
    "slither-analyzer",
    "solc-select",
}

NAME_PATTERN = r"[A-Za-z0-9][A-Za-z0-9._-]*"
VERSION_PATTERN = r"[^\s\\;]+"
DIRECT_RE = re.compile(rf"^({NAME_PATTERN})==({VERSION_PATTERN})$")
LOCK_REQUIREMENT_RE = re.compile(
    rf"^({NAME_PATTERN})==({VERSION_PATTERN})\s+\\$"
)
HASH_RE = re.compile(r"^--hash=sha256:([0-9a-f]{64})(?:\s+\\)?$")
ACTION_RE = re.compile(r"^\s*(?:-\s*)?uses:\s*([^@\s]+)@([^\s#]+)\s*$", re.MULTILINE)
INSTALL_INVOCATION_RE = re.compile(
    r"(?:\bpython(?:3(?:\.\d+)?)?\s+-m\s+pip|\bpip(?:3(?:\.\d+)?)?|\buv\s+pip)"
    r"\s+install\b"
)
PLAYWRIGHT_INSTALL_RE = re.compile(r"\bplaywright\s+install\b")


class ToolchainError(RuntimeError):
    """Raised when a Python toolchain input violates repository policy."""


def canonicalize_name(name: str) -> str:
    """Return the PEP 503 normalized distribution name."""

    return re.sub(r"[-_.]+", "-", name).lower()


def parse_direct_requirements(text: str) -> dict[str, str]:
    """Parse the human-maintained direct requirements file."""

    lowered = text.lower()
    if any(
        fragment in lowered
        for fragment in ("://", "--index-url", "--extra-index-url", "--trusted-host")
    ):
        raise ToolchainError(
            f"{DIRECT_REQUIREMENTS_PATH} must not contain index, host, or credential-bearing URLs"
        )

    requirements: dict[str, str] = {}
    for line_number, raw_line in enumerate(text.splitlines(), start=1):
        line = raw_line.strip()
        if not line or line.startswith("#"):
            continue
        match = DIRECT_RE.fullmatch(line)
        if match is None:
            raise ToolchainError(
                f"{DIRECT_REQUIREMENTS_PATH}:{line_number} must be an exact name==version pin"
            )
        name = canonicalize_name(match.group(1))
        if name in requirements:
            raise ToolchainError(
                f"{DIRECT_REQUIREMENTS_PATH}:{line_number} duplicates {name}"
            )
        requirements[name] = match.group(2)

    if set(requirements) != EXPECTED_DIRECT_NAMES:
        raise ToolchainError(
            f"{DIRECT_REQUIREMENTS_PATH} direct names must be exactly "
            f"{sorted(EXPECTED_DIRECT_NAMES)}, got {sorted(requirements)}"
        )
    return requirements


def parse_lock(text: str) -> dict[str, tuple[str, frozenset[str]]]:
    """Parse a pip-compile lock and require exact pins plus SHA-256 hashes."""

    lowered = text.lower()
    forbidden_fragments = (
        "://",
        "--index-url",
        "--extra-index-url",
        "--trusted-host",
        "--find-links",
    )
    for fragment in forbidden_fragments:
        if fragment in lowered:
            raise ToolchainError(
                f"{LOCK_PATH} must not contain index, host, link, or credential-bearing URLs"
            )

    requirements: dict[str, tuple[str, frozenset[str]]] = {}
    current_name: str | None = None
    current_version: str | None = None
    current_hashes: set[str] = set()

    def finish_current() -> None:
        nonlocal current_name, current_version, current_hashes
        if current_name is None or current_version is None:
            return
        if not current_hashes:
            raise ToolchainError(f"{LOCK_PATH} entry {current_name} has no SHA-256 hash")
        if current_name in requirements:
            raise ToolchainError(f"{LOCK_PATH} duplicates {current_name}")
        requirements[current_name] = (current_version, frozenset(current_hashes))
        current_name = None
        current_version = None
        current_hashes = set()

    for line_number, raw_line in enumerate(text.splitlines(), start=1):
        stripped = raw_line.strip()
        if not stripped or stripped.startswith("#"):
            continue

        requirement_match = LOCK_REQUIREMENT_RE.fullmatch(raw_line)
        if requirement_match is not None:
            finish_current()
            current_name = canonicalize_name(requirement_match.group(1))
            current_version = requirement_match.group(2)
            continue

        hash_match = HASH_RE.fullmatch(stripped)
        if hash_match is not None:
            if current_name is None:
                raise ToolchainError(
                    f"{LOCK_PATH}:{line_number} has a hash without a requirement"
                )
            digest = hash_match.group(1)
            if digest in current_hashes:
                raise ToolchainError(
                    f"{LOCK_PATH}:{line_number} duplicates a hash for {current_name}"
                )
            current_hashes.add(digest)
            continue

        raise ToolchainError(
            f"{LOCK_PATH}:{line_number} is not an exact hashed requirement entry"
        )

    finish_current()
    if not requirements:
        raise ToolchainError(f"{LOCK_PATH} contains no locked requirements")
    return requirements


def check_lock_matches_direct(
    direct: dict[str, str],
    locked: dict[str, tuple[str, frozenset[str]]],
) -> list[str]:
    """Return mismatches between direct intent and the complete lock."""

    errors: list[str] = []
    for name, version in sorted(direct.items()):
        locked_entry = locked.get(name)
        if locked_entry is None:
            errors.append(f"{LOCK_PATH} is missing direct requirement {name}=={version}")
        elif locked_entry[0] != version:
            errors.append(
                f"{LOCK_PATH} has {name}=={locked_entry[0]}, expected direct pin {version}"
            )
    return errors


def check_workflow(path: Path, text: str) -> list[str]:
    """Return CI/release workflow policy violations."""

    errors: list[str] = []
    setup_ref = f"uses: actions/setup-python@{SETUP_PYTHON_SHA}"
    python_pin = f'python-version: "{PYTHON_VERSION}"'
    foundry_ref = f"uses: foundry-rs/foundry-toolchain@{FOUNDRY_TOOLCHAIN_SHA}"

    action_refs = ACTION_RE.findall(text)
    setup_refs = [ref for action, ref in action_refs if action == "actions/setup-python"]
    if setup_refs != [SETUP_PYTHON_SHA]:
        errors.append(
            f"{path} setup-python refs must be exactly [{SETUP_PYTHON_SHA!r}], "
            f"got {setup_refs!r}"
        )
    foundry_refs = [
        ref for action, ref in action_refs if action == "foundry-rs/foundry-toolchain"
    ]
    if foundry_refs != [FOUNDRY_TOOLCHAIN_SHA]:
        errors.append(
            f"{path} Foundry action refs must be exactly [{FOUNDRY_TOOLCHAIN_SHA!r}], "
            f"got {foundry_refs!r}"
        )

    python_pins = [
        line.strip()
        for line in text.splitlines()
        if re.match(r"^\s*python-version\s*:", line)
    ]
    if python_pins != [python_pin]:
        errors.append(
            f"{path} Python runtime pins must be exactly [{python_pin!r}], got {python_pins!r}"
        )

    foundry_pins = [
        line.strip()
        for line in text.splitlines()
        if re.match(r"^\s*version\s*:\s*v1\.7\.1\s*$", line)
    ]
    if foundry_pins != [f"version: {FOUNDRY_VERSION}"]:
        errors.append(
            f"{path} must contain exactly one Foundry version pin "
            f"version: {FOUNDRY_VERSION}"
        )

    logical_text = re.sub(r"\\\s*\r?\n\s*", " ", text)

    install_commands = [
        line.strip()
        for line in logical_text.splitlines()
        if INSTALL_INVOCATION_RE.search(line)
    ]
    if install_commands != [LOCK_INSTALL_COMMAND]:
        errors.append(
            f"{path} pip install commands must be exactly [{LOCK_INSTALL_COMMAND!r}], "
            f"got {install_commands!r}"
        )

    pip_check_commands = [
        line.strip()
        for line in text.splitlines()
        if re.search(r"\bpython(?:3)?\s+-m\s+pip\s+check\b", line)
    ]
    if pip_check_commands != [PIP_CHECK_COMMAND]:
        errors.append(
            f"{path} must run the locked environment integrity check "
            f"{PIP_CHECK_COMMAND!r} exactly once"
        )

    playwright_commands = [
        line.strip()
        for line in logical_text.splitlines()
        if PLAYWRIGHT_INSTALL_RE.search(line)
    ]
    if playwright_commands != [PLAYWRIGHT_INSTALL_COMMAND]:
        errors.append(
            f"{path} Playwright install commands must be exactly "
            f"[{PLAYWRIGHT_INSTALL_COMMAND!r}], got {playwright_commands!r}"
        )

    setup_position = text.find(setup_ref)
    install_position = text.find(LOCK_INSTALL_COMMAND)
    browser_position = text.find(PLAYWRIGHT_INSTALL_COMMAND)
    if not (0 <= setup_position < install_position < browser_position):
        errors.append(
            f"{path} must set up pinned Python before the locked package and browser installs"
        )

    if path.as_posix() == RELEASE_WORKFLOW_PATH.as_posix():
        checkout_position = text.find("uses: actions/checkout@")
        guard_position = text.find(RELEASE_BRANCH_GUARD)
        foundry_position = text.find(foundry_ref)
        guard_immediately_follows_checkout = re.search(
            r"- name: Checkout\n"
            r"\s+uses: actions/checkout@[0-9a-f]{40}\n"
            r"\s+with:\n"
            r"\s+fetch-depth: 0\n"
            r"\s+persist-credentials: false\n\n"
            r"\s+- name: Require protected default branch\n",
            text,
        ) is not None
        if not (
            guard_immediately_follows_checkout
            and 0 <= checkout_position
            < guard_position
            < setup_position
            < foundry_position
        ):
            errors.append(
                f"{path} must run the protected-default-branch guard immediately "
                "after checkout and before Python or Foundry setup"
            )

    for action, ref in action_refs:
        if action.startswith("./"):
            continue
        if re.fullmatch(r"[0-9a-f]{40}", ref) is None:
            errors.append(f"{path} action {action}@{ref} is not pinned to a full SHA")

    return errors


def check_provenance_coverage(text: str) -> list[str]:
    """Require toolchain inputs in the deterministic release checksum bundle."""

    errors: list[str] = []
    for path in PROVENANCE_PATHS:
        literal = f'Path("{path.as_posix()}")'
        if literal not in text:
            errors.append(
                "scripts/generate_release_checksums.py must checksum-cover "
                f"{path.as_posix()}"
            )
    return errors


def check_repository(repo_root: Path) -> tuple[list[str], int]:
    """Validate all committed Python toolchain inputs below ``repo_root``."""

    errors: list[str] = []
    package_count = 0
    try:
        direct = parse_direct_requirements(
            (repo_root / DIRECT_REQUIREMENTS_PATH).read_text(encoding="utf-8")
        )
        locked = parse_lock((repo_root / LOCK_PATH).read_text(encoding="utf-8"))
        package_count = len(locked)
        errors.extend(check_lock_matches_direct(direct, locked))
    except (OSError, ToolchainError) as exc:
        errors.append(str(exc))

    for workflow_path in WORKFLOW_PATHS:
        try:
            workflow_text = (repo_root / workflow_path).read_text(encoding="utf-8")
        except OSError as exc:
            errors.append(str(exc))
            continue
        errors.extend(check_workflow(workflow_path, workflow_text))

    checksum_generator = repo_root / "scripts" / "generate_release_checksums.py"
    try:
        errors.extend(check_provenance_coverage(checksum_generator.read_text(encoding="utf-8")))
    except OSError as exc:
        errors.append(str(exc))

    return errors, package_count


def main() -> int:
    repo_root = Path(__file__).resolve().parents[1]
    errors, package_count = check_repository(repo_root)
    if errors:
        for error in errors:
            print(f"python toolchain error: {error}", file=sys.stderr)
        return 1

    print(
        "Python toolchain lock is valid: "
        f"CPython {PYTHON_VERSION}, {package_count} hashed packages, "
        f"{len(WORKFLOW_PATHS)} aligned workflows."
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
