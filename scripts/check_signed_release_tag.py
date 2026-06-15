#!/usr/bin/env python3
"""Validate signed release tag and checksum-bundle linkage."""

from __future__ import annotations

import argparse
import re
import subprocess
import sys
from pathlib import Path
from typing import Sequence


SCRIPT_DIR = Path(__file__).resolve().parent
if str(SCRIPT_DIR) not in sys.path:
    sys.path.insert(0, str(SCRIPT_DIR))

import check_release_signatures as release_signatures  # noqa: E402
import generate_release_checksums as checksum_generator  # noqa: E402


DEFAULT_SIGNATURE_DIR = Path("release-artifacts/signatures")
DEFAULT_OUTPUT_DIR = checksum_generator.DEFAULT_OUTPUT_DIR
DEFAULT_COVERED_PATHS = checksum_generator.DEFAULT_COVERED_PATHS
TAG_NAME_RE = re.compile(r"^[A-Za-z0-9][A-Za-z0-9._/-]*$")
GOOD_SIGNATURE_RE = re.compile(
    r"(?im)(^|\b)(gpg:\s+)?good\s+(?:\"git\"\s+)?signature\b|"
    r"^\[GNUPG:\]\s+(GOODSIG|VALIDSIG)\b"
)
FINGERPRINT_TOKEN_RE = re.compile(
    r"(?<![0-9A-Fa-f])(?:[0-9A-Fa-f][ :]?){40,64}(?![0-9A-Fa-f])"
)


class SignedReleaseTagError(RuntimeError):
    pass


class CommandResult:
    def __init__(self, returncode: int, stdout: str = "", stderr: str = "") -> None:
        self.returncode = returncode
        self.stdout = stdout
        self.stderr = stderr


class GitRunner:
    def run(self, args: Sequence[str], cwd: Path) -> CommandResult:
        completed = subprocess.run(
            list(args),
            cwd=cwd,
            check=False,
            capture_output=True,
            text=True,
        )
        return CommandResult(completed.returncode, completed.stdout, completed.stderr)


def normalize_path(path: Path, repo_root: Path) -> str:
    try:
        return path.resolve().relative_to(repo_root.resolve()).as_posix()
    except ValueError:
        return path.as_posix()


def validate_tag_name(tag: str) -> None:
    if not tag:
        raise SignedReleaseTagError("release mode requires --tag")
    if not TAG_NAME_RE.fullmatch(tag):
        raise SignedReleaseTagError("release tag must be a safe Git tag name")
    if (
        tag.startswith("/")
        or tag.startswith("-")
        or tag.endswith("/")
        or tag.endswith(".")
        or "//" in tag
        or "@{" in tag
        or tag == "@"
    ):
        raise SignedReleaseTagError("release tag must be a safe Git tag name")
    for component in tag.split("/"):
        if (
            component in {"", ".", ".."}
            or component.startswith(".")
            or component.endswith(".lock")
            or component.endswith(".")
        ):
            raise SignedReleaseTagError("release tag must be a safe Git tag name")
    if ".." in tag:
        raise SignedReleaseTagError("release tag must be a safe Git tag name")


def run_git(
    repo_root: Path,
    runner: GitRunner,
    args: Sequence[str],
    failure_message: str,
) -> str:
    result = runner.run(["git", *args], repo_root)
    if result.returncode != 0:
        details = (result.stderr or result.stdout).strip()
        if details:
            raise SignedReleaseTagError(f"{failure_message}: {details}")
        raise SignedReleaseTagError(failure_message)
    return result.stdout.strip()


def current_commit(repo_root: Path, runner: GitRunner) -> str:
    commit = run_git(repo_root, runner, ["rev-parse", "HEAD"], "could not resolve HEAD")
    release_signatures.require_git_commit(commit, "git rev-parse HEAD")
    return commit.lower()


def tag_commit(repo_root: Path, runner: GitRunner, tag: str) -> str:
    commit = run_git(
        repo_root,
        runner,
        ["rev-parse", "--verify", f"refs/tags/{tag}^{{commit}}"],
        f"could not resolve release tag {tag}",
    )
    release_signatures.require_git_commit(commit, f"refs/tags/{tag}^{{commit}}")
    return commit.lower()


def verify_tag_signature(repo_root: Path, runner: GitRunner, tag: str) -> str:
    result = runner.run(["git", "tag", "-v", tag], repo_root)
    output = "\n".join(part for part in [result.stdout.strip(), result.stderr.strip()] if part)
    if result.returncode != 0:
        if output:
            raise SignedReleaseTagError(f"release tag {tag} signature verification failed: {output}")
        raise SignedReleaseTagError(f"release tag {tag} signature verification failed")
    if not output:
        raise SignedReleaseTagError(f"release tag {tag} signature verification produced no output")
    if not GOOD_SIGNATURE_RE.search(output):
        raise SignedReleaseTagError(
            f"release tag {tag} signature verification did not include a good-signature marker"
        )
    return output


def verification_output_contains_fingerprint(output: str, fingerprint: str) -> bool:
    expected = fingerprint.lower()
    for line in output.splitlines():
        for match in FINGERPRINT_TOKEN_RE.finditer(line):
            candidate = "".join(
                character.lower()
                for character in match.group(0)
                if character in "0123456789abcdefABCDEF"
            )
            if candidate == expected:
                return True
    return False


def verify_checksum_bundle(
    repo_root: Path,
    covered_paths: Sequence[Path],
    output_dir: Path,
) -> set[str]:
    checksum_path = repo_root / output_dir / checksum_generator.CHECKSUM_FILE_NAME
    manifest_path = repo_root / output_dir / checksum_generator.CHECKSUM_MANIFEST_NAME
    if not checksum_path.is_file():
        raise SignedReleaseTagError(f"missing checksum bundle: {normalize_path(checksum_path, repo_root)}")
    if not manifest_path.is_file():
        raise SignedReleaseTagError(
            f"missing checksum manifest: {normalize_path(manifest_path, repo_root)}"
        )

    try:
        current_text = checksum_path.read_text(encoding="utf-8")
        current_manifest = manifest_path.read_text(encoding="utf-8")
        expected_text, expected_manifest = checksum_generator.build_outputs(
            repo_root,
            list(covered_paths),
            repo_root / output_dir,
        )
        mismatches = checksum_generator.verify_committed_checksum_file(repo_root, current_text)
    except checksum_generator.ChecksumError as exc:
        raise SignedReleaseTagError(f"release checksum bundle is invalid: {exc}") from exc

    if mismatches:
        raise SignedReleaseTagError("release checksum bundle is stale: " + "; ".join(mismatches))
    if current_text != expected_text:
        raise SignedReleaseTagError(
            f"release checksum bundle is stale: changed {normalize_path(checksum_path, repo_root)}"
        )
    if current_manifest != expected_manifest:
        raise SignedReleaseTagError(
            f"release checksum manifest is stale: changed {normalize_path(manifest_path, repo_root)}"
        )
    try:
        return {
            relative_path
            for _, relative_path in checksum_generator.parse_checksum_file(current_text)
        }
    except checksum_generator.ChecksumError as exc:
        raise SignedReleaseTagError(f"release checksum bundle is invalid: {exc}") from exc


def evidence_paths(repo_root: Path, configured: Sequence[Path] | None) -> list[Path]:
    if configured:
        return [path if path.is_absolute() else repo_root / path for path in configured]
    signature_dir = repo_root / DEFAULT_SIGNATURE_DIR
    if not signature_dir.is_dir():
        raise SignedReleaseTagError(f"missing release signature directory: {DEFAULT_SIGNATURE_DIR}")
    paths = sorted(signature_dir.glob("*.json"))
    if not paths:
        raise SignedReleaseTagError(f"no release signature evidence found under {DEFAULT_SIGNATURE_DIR}")
    return paths


def load_valid_evidence(path: Path, repo_root: Path) -> dict:
    try:
        release_signatures.validate_evidence(path, repo_root)
        return release_signatures.load_json(path)
    except release_signatures.ReleaseSignatureEvidenceError as exc:
        raise SignedReleaseTagError(f"invalid release signature evidence {path}: {exc}") from exc


def matching_release_evidence(
    repo_root: Path,
    tag: str,
    commit: str,
    configured_evidence: Sequence[Path] | None,
    checksum_covered_paths: set[str],
    tag_verification_output: str,
) -> Path:
    checked = []
    for path in evidence_paths(repo_root, configured_evidence):
        evidence = load_valid_evidence(path, repo_root)
        relative = normalize_path(path, repo_root)
        reasons = []
        if relative in checksum_covered_paths:
            reasons.append(
                "release signature evidence is covered by the checksum bundle "
                "and cannot prove a post-bundle signature"
            )
        if evidence.get("release_version") != tag:
            reasons.append("release_version does not match tag")
        source = evidence.get("source", {})
        if str(source.get("git_commit", "")).lower() != commit:
            reasons.append("source.git_commit does not match HEAD")
        if source.get("source_dirty") is not False:
            reasons.append("source.source_dirty is not false")
        if evidence.get("network", {}).get("environment") == "local":
            reasons.append("network.environment is local")
        try:
            fingerprint = release_signatures.require_fingerprint(
                evidence.get("signing_identity", {}).get("public_key_fingerprint"),
                "signing_identity.public_key_fingerprint",
            )
        except release_signatures.ReleaseSignatureEvidenceError as exc:
            reasons.append(str(exc))
            fingerprint = ""
        if fingerprint and not verification_output_contains_fingerprint(
            tag_verification_output, fingerprint
        ):
            reasons.append("signed tag verification output does not include signer fingerprint")

        signatures = evidence.get("signatures", {})
        checksum_signature = signatures.get("detached_checksum_signature", {})
        signed_tag = signatures.get("signed_git_tag", {})
        if checksum_signature.get("status") != "signed":
            reasons.append("detached_checksum_signature is not signed")
        if signed_tag.get("status") != "signed":
            reasons.append("signed_git_tag is not signed")
        if signed_tag.get("artifact_path") != tag:
            reasons.append("signed_git_tag.artifact_path does not match tag")
        checksum_signature_artifact = checksum_signature.get("artifact_path")
        if checksum_signature_artifact in checksum_covered_paths:
            reasons.append("detached checksum signature artifact is covered by checksum bundle")
        for index, item in enumerate(checksum_signature.get("evidence", [])):
            path_value = item.get("path")
            if path_value in checksum_covered_paths:
                reasons.append(
                    "detached checksum signature evidence "
                    f"{index} is covered by checksum bundle"
                )

        if not reasons:
            return path
        checked.append(f"{relative}: {', '.join(reasons)}")

    raise SignedReleaseTagError(
        "no release signature evidence matches the signed tag and checksum requirements; "
        + "checked "
        + "; ".join(checked)
    )


def check_signed_release_tag(
    repo_root: Path,
    mode: str,
    tag: str | None = None,
    evidence: Sequence[Path] | None = None,
    covered_paths: Sequence[Path] = DEFAULT_COVERED_PATHS,
    output_dir: Path = DEFAULT_OUTPUT_DIR,
    runner: GitRunner | None = None,
) -> Path | None:
    if mode == "non-release":
        if tag:
            raise SignedReleaseTagError("--tag is only valid with --mode release")
        return None
    if mode != "release":
        raise SignedReleaseTagError(f"unsupported mode: {mode}")

    if tag is None:
        raise SignedReleaseTagError("release mode requires --tag")
    validate_tag_name(tag)
    runner = runner or GitRunner()

    head = current_commit(repo_root, runner)
    peeled_tag_commit = tag_commit(repo_root, runner, tag)
    if peeled_tag_commit != head:
        raise SignedReleaseTagError(
            f"release tag {tag} points at {peeled_tag_commit}, not HEAD {head}"
        )
    tag_verification_output = verify_tag_signature(repo_root, runner, tag)
    checksum_covered_paths = verify_checksum_bundle(repo_root, covered_paths, output_dir)
    return matching_release_evidence(
        repo_root,
        tag,
        head,
        evidence,
        checksum_covered_paths,
        tag_verification_output,
    )


def parse_args(argv: Sequence[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repo-root", type=Path, default=Path(__file__).resolve().parents[1])
    parser.add_argument("--mode", choices=("non-release", "release"), default="non-release")
    parser.add_argument("--tag", help="Release tag to verify in release mode.")
    parser.add_argument(
        "--evidence",
        type=Path,
        action="append",
        help="Release signature evidence JSON to inspect. Defaults to all committed evidence.",
    )
    parser.add_argument(
        "--covered-path",
        type=Path,
        action="append",
        dest="covered_paths",
        help="Checksum covered path. Defaults to the release checksum generator defaults.",
    )
    parser.add_argument("--output-dir", type=Path, default=DEFAULT_OUTPUT_DIR)
    return parser.parse_args(argv)


def main(argv: Sequence[str] | None = None) -> int:
    args = parse_args(argv or sys.argv[1:])
    repo_root = args.repo_root.resolve()
    covered_paths = args.covered_paths or DEFAULT_COVERED_PATHS
    try:
        evidence_path = check_signed_release_tag(
            repo_root=repo_root,
            mode=args.mode,
            tag=args.tag,
            evidence=args.evidence,
            covered_paths=covered_paths,
            output_dir=args.output_dir,
        )
    except SignedReleaseTagError as exc:
        print(f"error: {exc}", file=sys.stderr)
        return 1

    if args.mode == "non-release":
        print("signed release tag gate is in non-release mode; no signed release status claimed")
    else:
        print(
            "signed release tag verified: "
            f"{args.tag} with evidence {normalize_path(evidence_path, repo_root)}"
        )
    return 0


if __name__ == "__main__":
    sys.exit(main())
