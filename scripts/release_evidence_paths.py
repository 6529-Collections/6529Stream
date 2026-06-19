#!/usr/bin/env python3
"""Shared path-resolution helpers for retained release evidence."""

from __future__ import annotations

from pathlib import Path


def resolve_repo_relative_path(
    repo_root: Path,
    relative_path: str,
    *,
    error_type: type[Exception],
    forward_slash_message: str | None,
    absolute_message: str,
    traversal_message: str,
    symlink_message: str,
    escape_message: str,
    require_file: bool = False,
    missing_message: str | None = None,
    return_resolved: bool = True,
) -> Path:
    """Resolve a repo-relative path while rejecting escapes and symlinks."""
    if "\\" in relative_path:
        raise error_type(forward_slash_message or traversal_message)

    candidate = Path(relative_path)
    if candidate.is_absolute() or candidate.drive or candidate.root:
        raise error_type(absolute_message)
    if ".." in candidate.parts:
        raise error_type(traversal_message)

    root = repo_root.resolve()
    cursor = root
    for part in candidate.parts:
        cursor = cursor / part
        # Reject symlinked directories as well as symlinked leaf files before
        # resolve() can follow them outside the reviewed evidence tree.
        if cursor.is_symlink():
            raise error_type(symlink_message)

    unresolved = root / candidate
    resolved = unresolved.resolve()
    try:
        resolved.relative_to(root)
    except ValueError as exc:
        raise error_type(escape_message) from exc

    if require_file and not resolved.is_file():
        if missing_message is None:
            raise error_type(f"missing retained file: {relative_path}")
        raise error_type(missing_message)

    return resolved if return_resolved else unresolved
