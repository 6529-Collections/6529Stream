#!/usr/bin/env python3
"""Run immutable artist-57 design checks against their explicitly pinned historical tree."""

from __future__ import annotations

import argparse
import hashlib
import os
from pathlib import Path, PurePosixPath, PureWindowsPath
import shutil
import subprocess
import sys
import tarfile
import tempfile
from typing import Sequence

from tools.protocol.check_artist_operation_extension import HISTORICAL


BASELINE = "569bf87f1fa808787d324f6e1582924b5ccf1d40"
GATES = {
    "matrix": "artist_semantic_owner_matrix",
    "reconstruction": "artist_record_event_reconstruction_correction",
    "continuity": "artist_owner_record_continuity",
}
PRESERVED_TOOLS = tuple(
    f"tools/protocol/{kind}_{name}.py"
    for name in (*GATES.values(), "artist_owner_state_mechanics_foundation", "artist_operation_shared_mechanics_freeze")
    for kind in ("check", "test")
)


class HistoricalCheckError(RuntimeError):
    """The historical baseline could not be validated or used safely."""


def validate_member(member: tarfile.TarInfo, destination: Path) -> Path:
    name = member.name
    path = PurePosixPath(name)
    if (not name or "\\" in name or ":" in name or path.is_absolute()
            or PureWindowsPath(name).drive or any(part in (".", "..") for part in name.split("/"))
            or path.as_posix() != name.rstrip("/") or not path.parts
            or path.parts[0] == ".git" or not (member.isfile() or member.isdir())):
        raise HistoricalCheckError(f"Unsafe archive member: {name!r}")
    target = destination.joinpath(*path.parts).resolve()
    if not target.is_relative_to(destination.resolve()):
        raise HistoricalCheckError(f"Archive member escapes the temporary root: {name!r}")
    return target


def extract_archive(archive_path: Path, destination: Path) -> None:
    with tarfile.open(archive_path, "r:") as archive:
        members = [(member, validate_member(member, destination)) for member in archive.getmembers()]
        for member, target in members:
            if member.isdir():
                target.mkdir(parents=True, exist_ok=True)
                continue
            target.parent.mkdir(parents=True, exist_ok=True)
            source = archive.extractfile(member)
            if source is None:
                raise HistoricalCheckError(f"Missing archive contents: {member.name}")
            with source, target.open("wb") as output:
                shutil.copyfileobj(source, output)


def validate_preserved_inputs(repo_root: Path, historical_root: Path) -> None:
    for relative, expected in HISTORICAL.items():
        for root in (repo_root, historical_root):
            path = root / relative
            if not path.is_file() or hashlib.sha256(path.read_bytes()).hexdigest() != expected:
                raise HistoricalCheckError(f"Frozen artist input changed or is missing: {path}")
    for relative in PRESERVED_TOOLS:
        current, baseline = repo_root / relative, historical_root / relative
        if not current.is_file() or not baseline.is_file() or current.read_bytes() != baseline.read_bytes():
            raise HistoricalCheckError(f"Frozen artist checker/test changed or is missing: {relative}")


def run_gate(repo_root: Path, gate: str) -> int:
    if gate not in GATES:
        raise HistoricalCheckError(f"Unknown historical artist gate: {gate}")
    repo_root = repo_root.resolve()
    resolved = subprocess.check_output(
        ["git", "rev-parse", "--verify", BASELINE + "^{commit}"], cwd=repo_root, text=True
    ).strip()
    if resolved != BASELINE:
        raise HistoricalCheckError("The exact historical artist baseline is unavailable.")
    print(f"Historical artist-57 {gate}: baseline {BASELINE}; no current implementation or release credit.", flush=True)
    env = {key: value for key, value in os.environ.items() if key not in ("PYTHONPATH", "PYTHONHOME")}
    with tempfile.TemporaryDirectory(prefix="stream-artist57-") as temporary:
        work = Path(temporary)
        archive = work / "baseline.tar"
        tree = work / "tree"
        tree.mkdir()
        subprocess.run(["git", "archive", "--format=tar", f"--output={archive}", BASELINE], cwd=repo_root, check=True)
        extract_archive(archive, tree)
        validate_preserved_inputs(repo_root, tree)
        for kind in ("test", "check"):
            module = f"tools.protocol.{kind}_{GATES[gate]}"
            result = subprocess.run([sys.executable, "-m", module], cwd=tree, env=env)
            if result.returncode:
                return result.returncode
    return 0


def main(argv: Sequence[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("gate", choices=tuple(GATES))
    parser.add_argument("--repo-root", type=Path, default=Path(__file__).resolve().parents[2])
    args = parser.parse_args(argv)
    try:
        return run_gate(args.repo_root, args.gate)
    except (HistoricalCheckError, OSError, subprocess.CalledProcessError, tarfile.TarError) as exc:
        print(f"Historical artist-57 check failed: {exc}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
