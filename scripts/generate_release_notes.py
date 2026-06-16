#!/usr/bin/env python3
"""Generate deterministic release notes from changelog and release artifacts."""

from __future__ import annotations

import argparse
import filecmp
import hashlib
import json
import re
import sys
import tempfile
from collections import Counter
from pathlib import Path
from typing import Any, Sequence

import check_changelog


RELEASE_NOTES_SCHEMA = "6529stream.release-notes.v1"
GENERATOR_VERSION = "1"

DEFAULT_JSON_OUTPUT = Path("release-artifacts/latest/release-notes.json")
DEFAULT_MARKDOWN_OUTPUT = Path("release-artifacts/latest/release-notes.md")
DEFAULT_CHANGELOG = Path("CHANGELOG.md")
DEFAULT_RELEASE_MANIFEST = Path("release-artifacts/latest/release-manifest.json")
DEFAULT_BYTECODE_PROOF = Path("release-artifacts/latest/bytecode-release-proof.json")
DEFAULT_RISK_REGISTER = Path("release-artifacts/latest/risk-register.json")

SECRET_LIKE_RE = re.compile(
    r"(private[_-]?key\s*[:=]|mnemonic\s*[:=]|seed[_-]?phrase\s*[:=]|"
    r"api[_-]?key\s*[:=]|secret\s*[:=]|token\s*=|rpc[_-]?url\s*[:=])",
    re.IGNORECASE,
)


class ReleaseNotesError(RuntimeError):
    pass


def normalize_path(path: Path, repo_root: Path) -> str:
    try:
        return path.resolve().relative_to(repo_root.resolve()).as_posix()
    except ValueError:
        return path.as_posix()


def sha256_bytes(value: bytes) -> str:
    return "sha256:" + hashlib.sha256(value).hexdigest()


def file_sha256(path: Path) -> str:
    with path.open("rb") as handle:
        return sha256_bytes(handle.read())


def load_json(path: Path) -> Any:
    try:
        with path.open("r", encoding="utf-8") as handle:
            return json.load(handle)
    except FileNotFoundError as exc:
        raise ReleaseNotesError(f"missing required file: {path}") from exc
    except json.JSONDecodeError as exc:
        raise ReleaseNotesError(f"invalid JSON in {path}: {exc}") from exc


def require_dict(value: Any, field: str) -> dict[str, Any]:
    if not isinstance(value, dict):
        raise ReleaseNotesError(f"{field} must be an object")
    return value


def require_list(value: Any, field: str) -> list[Any]:
    if not isinstance(value, list):
        raise ReleaseNotesError(f"{field} must be a list")
    return value


def require_string(value: Any, field: str) -> str:
    if not isinstance(value, str) or value == "":
        raise ReleaseNotesError(f"{field} must be a non-empty string")
    return value


def file_record(path: Path, repo_root: Path) -> dict[str, Any]:
    if not path.is_file():
        raise ReleaseNotesError(f"missing required file: {normalize_path(path, repo_root)}")
    return {
        "path": normalize_path(path, repo_root),
        "sha256": file_sha256(path),
        "size_bytes": path.stat().st_size,
    }


def reject_secret_like_text(text: str, source: str) -> None:
    if SECRET_LIKE_RE.search(text):
        raise ReleaseNotesError(f"{source} contains secret-shaped text")


def unreleased_bullets(changelog_text: str) -> list[str]:
    entries: list[str] = []
    current: list[str] = []
    for line in check_changelog.unreleased_section(changelog_text):
        stripped = line.strip()
        if stripped.startswith("- "):
            if current:
                entries.append(" ".join(current))
            current = [stripped[2:].strip()]
            continue
        if current and stripped and not stripped.startswith("#"):
            current.append(stripped)
    if current:
        entries.append(" ".join(current))
    return [
        entry
        for entry in entries
        if entry and not entry.startswith("<!--") and not check_changelog.PLACEHOLDER_ENTRY_RE.search(entry)
    ]


def changelog_entries(path: Path) -> list[str]:
    try:
        text = path.read_text(encoding="utf-8")
    except FileNotFoundError as exc:
        raise ReleaseNotesError(f"missing required file: {path}") from exc
    entries = unreleased_bullets(text)
    if not entries:
        raise ReleaseNotesError("CHANGELOG.md has no non-placeholder Unreleased entries")
    for entry in entries:
        reject_secret_like_text(entry, "CHANGELOG.md Unreleased entry")
    return entries


def status_counts(rows: list[Any], field: str) -> dict[str, int]:
    counter: Counter[str] = Counter()
    for row in rows:
        if isinstance(row, dict):
            value = row.get(field)
            if isinstance(value, str) and value:
                counter[value] += 1
    return dict(sorted(counter.items()))


def build_notes(
    repo_root: Path,
    json_output: Path,
    markdown_output: Path,
    changelog_path: Path,
    release_manifest_path: Path,
    bytecode_proof_path: Path,
    risk_register_path: Path,
) -> dict[str, Any]:
    changelog_abs = repo_root / changelog_path
    release_manifest_abs = repo_root / release_manifest_path
    bytecode_proof_abs = repo_root / bytecode_proof_path
    risk_register_abs = repo_root / risk_register_path

    release_manifest = require_dict(load_json(release_manifest_abs), "release-manifest")
    bytecode_proof = require_dict(load_json(bytecode_proof_abs), "bytecode-release-proof")
    risk_register = require_dict(load_json(risk_register_abs), "risk-register")
    release = require_dict(release_manifest.get("release"), "release-manifest.release")
    release_artifacts = require_dict(
        release_manifest.get("release_artifacts"),
        "release-manifest.release_artifacts",
    )
    public_beta_evidence = require_dict(
        release_artifacts.get("public_beta_evidence"),
        "release_artifacts.public_beta_evidence",
    )
    public_beta_status = require_dict(
        public_beta_evidence.get("status"),
        "release_artifacts.public_beta_evidence.status",
    )
    proof_status = require_dict(bytecode_proof.get("proof_status"), "bytecode-proof.proof_status")
    risks = require_list(risk_register.get("risks"), "risk-register.risks")
    contract_proofs = require_list(
        bytecode_proof.get("contract_proofs"),
        "bytecode-proof.contract_proofs",
    )

    entries = changelog_entries(changelog_abs)
    notes = {
        "schema_version": RELEASE_NOTES_SCHEMA,
        "generated_by": f"scripts/generate_release_notes.py:{GENERATOR_VERSION}",
        "source": {
            "changelog": file_record(changelog_abs, repo_root),
            "release_manifest": {
                "path": normalize_path(release_manifest_abs, repo_root),
                "hash_omitted": "avoids release-manifest/release-notes hash cycle",
            },
            "bytecode_release_proof": {
                "path": normalize_path(bytecode_proof_abs, repo_root),
                "hash_omitted": "avoids bytecode-proof/release-notes hash cycle",
            },
            "risk_register": file_record(risk_register_abs, repo_root),
            "json_output": normalize_path(repo_root / json_output, repo_root),
            "markdown_output": normalize_path(repo_root / markdown_output, repo_root),
        },
        "release": {
            "project": require_string(release.get("project"), "release.project"),
            "status": require_string(release.get("status"), "release.status"),
            "protocol_versions": sorted(
                str(version)
                for version in require_list(release.get("protocol_versions"), "release.protocol_versions")
            ),
            "deployment_versions": sorted(
                str(version)
                for version in require_list(
                    release.get("deployment_versions"),
                    "release.deployment_versions",
                )
            ),
        },
        "readiness": {
            "public_beta": require_string(public_beta_status.get("public_beta"), "public_beta"),
            "production_release": require_string(
                public_beta_status.get("production_release"),
                "production_release",
            ),
            "boundary": (
                "These notes describe the committed pre-audit local baseline only; "
                "they do not prove live deployment, public-beta readiness, "
                "production readiness, signed tags, detached signatures, or explorer verification."
            ),
        },
        "changelog": {
            "section": "Unreleased",
            "entries": entries,
        },
        "artifact_summary": {
            "bytecode_release_proof": {
                "local_and_fork": require_string(
                    proof_status.get("local_and_fork"),
                    "proof_status.local_and_fork",
                ),
                "production": require_string(
                    proof_status.get("production"),
                    "proof_status.production",
                ),
                "contract_proof_count": len(contract_proofs),
            },
            "risk_register": {
                "risk_count": len(risks),
                "by_status": status_counts(risks, "status"),
                "by_area": status_counts(risks, "area"),
            },
            "validation_commands": [
                "python scripts/generate_release_notes.py --check",
                "python scripts/verify_release_artifacts.py",
                "python scripts/generate_release_manifest.py --check",
                "python scripts/generate_bytecode_release_proof.py --check",
                "python scripts/generate_release_checksums.py --check",
            ],
        },
    }
    reject_secret_like_text(json.dumps(notes, sort_keys=True), "release notes")
    return notes


def markdown_text(notes: dict[str, Any]) -> str:
    release = require_dict(notes["release"], "release")
    readiness = require_dict(notes["readiness"], "readiness")
    changelog = require_dict(notes["changelog"], "changelog")
    summary = require_dict(notes["artifact_summary"], "artifact_summary")
    proof = require_dict(summary["bytecode_release_proof"], "bytecode_release_proof")
    risks = require_dict(summary["risk_register"], "risk_register")

    lines = [
        "# 6529Stream Release Notes",
        "",
        f"- Project: `{release['project']}`",
        f"- Release status: `{release['status']}`",
        f"- Public beta status: `{readiness['public_beta']}`",
        f"- Production release status: `{readiness['production_release']}`",
        "",
        "## Boundary",
        "",
        readiness["boundary"],
        "",
        "## Protocol Versions",
        "",
    ]
    for version in release["protocol_versions"]:
        lines.append(f"- `{version}`")
    lines.extend(["", "## Deployment Versions", ""])
    for version in release["deployment_versions"]:
        lines.append(f"- `{version}`")
    lines.extend(["", "## Changelog Entries", ""])
    for entry in changelog["entries"]:
        lines.append(f"- {entry}")
    lines.extend(
        [
            "",
            "## Artifact Summary",
            "",
            f"- Bytecode proof local/fork status: `{proof['local_and_fork']}`",
            f"- Bytecode proof production status: `{proof['production']}`",
            f"- Contract proof count: `{proof['contract_proof_count']}`",
            f"- Risk count: `{risks['risk_count']}`",
            "",
            "### Risk Status Counts",
            "",
        ]
    )
    for status, count in risks["by_status"].items():
        lines.append(f"- `{status}`: {count}")
    lines.extend(["", "### Risk Area Counts", ""])
    for area, count in risks["by_area"].items():
        lines.append(f"- `{area}`: {count}")
    lines.extend(["", "## Validation Commands", ""])
    for command in summary["validation_commands"]:
        lines.append(f"- `{command}`")
    lines.append("")
    return "\n".join(lines)


def build_output_texts(
    repo_root: Path,
    json_output: Path,
    markdown_output: Path,
    changelog_path: Path,
    release_manifest_path: Path,
    bytecode_proof_path: Path,
    risk_register_path: Path,
) -> tuple[str, str]:
    notes = build_notes(
        repo_root,
        json_output,
        markdown_output,
        changelog_path,
        release_manifest_path,
        bytecode_proof_path,
        risk_register_path,
    )
    json_text = json.dumps(notes, indent=2, ensure_ascii=False) + "\n"
    return json_text, markdown_text(notes)


def write_outputs(
    repo_root: Path,
    json_output: Path,
    markdown_output: Path,
    changelog_path: Path,
    release_manifest_path: Path,
    bytecode_proof_path: Path,
    risk_register_path: Path,
) -> list[Path]:
    json_text, md_text = build_output_texts(
        repo_root,
        json_output,
        markdown_output,
        changelog_path,
        release_manifest_path,
        bytecode_proof_path,
        risk_register_path,
    )
    json_path = repo_root / json_output
    md_path = repo_root / markdown_output
    json_path.parent.mkdir(parents=True, exist_ok=True)
    md_path.parent.mkdir(parents=True, exist_ok=True)
    json_path.write_text(json_text, encoding="utf-8", newline="\n")
    md_path.write_text(md_text, encoding="utf-8", newline="\n")
    return [json_path, md_path]


def check_outputs(
    repo_root: Path,
    json_output: Path,
    markdown_output: Path,
    changelog_path: Path,
    release_manifest_path: Path,
    bytecode_proof_path: Path,
    risk_register_path: Path,
) -> None:
    json_path = repo_root / json_output
    md_path = repo_root / markdown_output
    if not json_path.is_file():
        raise ReleaseNotesError(f"missing {normalize_path(json_path, repo_root)}")
    if not md_path.is_file():
        raise ReleaseNotesError(f"missing {normalize_path(md_path, repo_root)}")
    expected_json, expected_md = build_output_texts(
        repo_root,
        json_output,
        markdown_output,
        changelog_path,
        release_manifest_path,
        bytecode_proof_path,
        risk_register_path,
    )
    with tempfile.TemporaryDirectory() as temp_dir:
        expected_json_path = Path(temp_dir) / json_path.name
        expected_md_path = Path(temp_dir) / md_path.name
        expected_json_path.write_text(expected_json, encoding="utf-8", newline="\n")
        expected_md_path.write_text(expected_md, encoding="utf-8", newline="\n")
        if not filecmp.cmp(expected_json_path, json_path, shallow=False):
            raise ReleaseNotesError(
                f"changed {normalize_path(json_path, repo_root)}; "
                "run `python scripts/generate_release_notes.py`"
            )
        if not filecmp.cmp(expected_md_path, md_path, shallow=False):
            raise ReleaseNotesError(
                f"changed {normalize_path(md_path, repo_root)}; "
                "run `python scripts/generate_release_notes.py`"
            )


def parse_args(argv: Sequence[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repo-root", type=Path, default=Path.cwd())
    parser.add_argument("--json-output", type=Path, default=DEFAULT_JSON_OUTPUT)
    parser.add_argument("--markdown-output", type=Path, default=DEFAULT_MARKDOWN_OUTPUT)
    parser.add_argument("--changelog", type=Path, default=DEFAULT_CHANGELOG)
    parser.add_argument("--release-manifest", type=Path, default=DEFAULT_RELEASE_MANIFEST)
    parser.add_argument("--bytecode-proof", type=Path, default=DEFAULT_BYTECODE_PROOF)
    parser.add_argument("--risk-register", type=Path, default=DEFAULT_RISK_REGISTER)
    parser.add_argument("--check", action="store_true")
    return parser.parse_args(argv)


def main(argv: Sequence[str] | None = None) -> int:
    args = parse_args(argv or sys.argv[1:])
    repo_root = args.repo_root.resolve()
    try:
        if args.check:
            check_outputs(
                repo_root,
                args.json_output,
                args.markdown_output,
                args.changelog,
                args.release_manifest,
                args.bytecode_proof,
                args.risk_register,
            )
            print("release notes are current")
        else:
            for path in write_outputs(
                repo_root,
                args.json_output,
                args.markdown_output,
                args.changelog,
                args.release_manifest,
                args.bytecode_proof,
                args.risk_register,
            ):
                print(normalize_path(path, repo_root))
    except ReleaseNotesError as exc:
        print(f"error: {exc}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
