#!/usr/bin/env python3
"""Run the aggregate size/warning diagnostic while retaining its Forge log."""

from __future__ import annotations

import argparse
import os
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
]


def parse_args(argv: list[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--log",
        type=Path,
        default=Path("cache/forge-size.log"),
        help="Path that receives combined forge stdout/stderr.",
    )
    return parser.parse_args(argv)


def run_with_log(log_path: Path) -> int:
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

    if exit_code == 0:
        os.replace(temp_log_path, log_path)
    else:
        temp_log_path.unlink(missing_ok=True)
        log_path.unlink(missing_ok=True)
    return exit_code


def main(argv: list[str] | None = None) -> int:
    args = parse_args(sys.argv[1:] if argv is None else argv)
    return run_with_log(args.log)


if __name__ == "__main__":
    raise SystemExit(main())
