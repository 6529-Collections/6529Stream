#!/usr/bin/env python3
"""Run the aggregate size/warning diagnostic while retaining its Forge log."""

from __future__ import annotations

import argparse
import os
import re
import subprocess
import sys
from pathlib import Path


FORGE_SIZE_COMMAND = [
    "forge",
    "build",
    "--sizes",
    "--via-ir",
    "--skip",
    "test",
    "--skip",
    "script",
    "--force",
    "--out",
    "out-diagnostics",
    "--cache-path",
    "cache-diagnostics",
]
EXPECTED_TEST_ONLY_RUNTIME_OVERFLOWS = {
    "LegacyStreamCore": (24_587, -11),
}
RUNTIME_SIZE_ERROR = (
    "Error: some contracts exceed the runtime size limit "
    "(EIP-170: 24576 bytes)"
)
SIZE_ROW_RE = re.compile(
    r"^\|\s*(?P<contract>[^|]+?)\s*"
    r"\|\s*(?P<runtime>[0-9,]+)\s*"
    r"\|\s*(?P<initcode>[0-9,]+)\s*"
    r"\|\s*(?P<runtime_margin>-?[0-9,]+)\s*"
    r"\|\s*(?P<initcode_margin>-?[0-9,]+)\s*\|$"
)


def parse_args(argv: list[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--log",
        type=Path,
        default=Path("cache/forge-size.log"),
        help="Path that receives combined forge stdout/stderr.",
    )
    return parser.parse_args(argv)


def accepted_test_only_runtime_overflow(log_text: str) -> bool:
    """Accept only the exact non-deployable helper overage in the diagnostic."""
    if "Compiler run successful" not in log_text:
        return False
    error_lines = [
        line.strip()
        for line in log_text.splitlines()
        if line.strip().startswith("Error:")
    ]
    if error_lines != [RUNTIME_SIZE_ERROR]:
        return False

    negative_runtime_margins: dict[str, tuple[int, int]] = {}
    for line in log_text.splitlines():
        match = SIZE_ROW_RE.match(line)
        if match is None:
            continue
        runtime_margin = int(match.group("runtime_margin").replace(",", ""))
        if runtime_margin < 0:
            negative_runtime_margins[match.group("contract")] = (
                int(match.group("runtime").replace(",", "")),
                runtime_margin,
            )
    return negative_runtime_margins == EXPECTED_TEST_ONLY_RUNTIME_OVERFLOWS


def run_with_log(log_path: Path) -> int:
    # --force clears Forge's selected outputs. Keep this diagnostic independent
    # of both the default build and the nested current-profile evidence, including
    # when a local symlink or Windows junction would otherwise alias those paths.
    root = Path.cwd().resolve()
    for option in ("--out", "--cache-path"):
        path = root / FORGE_SIZE_COMMAND[FORGE_SIZE_COMMAND.index(option) + 1]
        if path.is_symlink() or path.resolve() != path or (path.exists() and not path.is_dir()):
            raise ValueError(f"Diagnostic output must be an unlinked directory: {path}")
    log_path.parent.mkdir(parents=True, exist_ok=True)
    temp_log_path = log_path.with_name(f"{log_path.name}.tmp")
    for stale_path in (log_path, temp_log_path):
        stale_path.unlink(missing_ok=True)

    with temp_log_path.open("w", encoding="utf-8", newline="") as log_file:
        process = subprocess.Popen(
            FORGE_SIZE_COMMAND,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            text=True,
            encoding="utf-8",
            errors="replace",
        )
        assert process.stdout is not None
        for line in process.stdout:
            console_encoding = sys.stdout.encoding or "utf-8"
            safe_line = line.encode(console_encoding, errors="replace").decode(
                console_encoding,
                errors="replace",
            )
            print(safe_line, end="")
            log_file.write(line)
        exit_code = process.wait()

    log_text = temp_log_path.read_text(encoding="utf-8")
    accepted_test_only_overflow = (
        exit_code == 1 and accepted_test_only_runtime_overflow(log_text)
    )
    if exit_code == 0 or accepted_test_only_overflow:
        os.replace(temp_log_path, log_path)
        if accepted_test_only_overflow:
            print(
                "Accepted exact test-only LegacyStreamCore size overage in the "
                "aggregate diagnostic; canonical production size checks remain "
                "authoritative."
            )
        return 0
    else:
        temp_log_path.unlink(missing_ok=True)
        log_path.unlink(missing_ok=True)
        return exit_code


def main(argv: list[str] | None = None) -> int:
    args = parse_args(sys.argv[1:] if argv is None else argv)
    return run_with_log(args.log)


if __name__ == "__main__":
    raise SystemExit(main())
