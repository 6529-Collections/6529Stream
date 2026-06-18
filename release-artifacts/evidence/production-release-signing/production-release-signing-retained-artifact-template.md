# Production Release Signing Retained Artifact

This template is the retained, no-secret evidence shape for future production
release-signing review. It supports the `production_signatures` and
`signed_git_tag` production-release tracker rows, but this checked template is
not completion evidence.

## Release Signing Context

- Requirement ID: `production_release_signing`
- Supported requirements: `production_signatures, signed_git_tag`
- Readiness claim: `blocked`
- Environment: `release_signing`
- Review status: `template`
- Release version: `TBD`
- Signed Git tag: `TBD`
- Release commit: `TBD`
- Signer fingerprint: `TBD`
- Signer custody summary: `TBD`
- Signer rotation/revocation policy: `TBD`

## Signature Evidence

- Release manifest/checksum digests: `TBD`
- Checksum bundle: `TBD`
- Detached checksum signature evidence: `TBD`
- Signed Git tag verification evidence: `TBD`
- Release signature evidence JSON: `TBD`
- Verification command outputs: `TBD`

## Review And Redaction

- Reviewer: `TBD`
- Review decision: `TBD`
- No secrets retained: `TBD`
- Production signatures tracker updated: `TBD`
- Signed tag tracker updated: `TBD`
- Release signature checker executed: `TBD`
- Signed release tag checker executed: `TBD`

## Validation Commands

```sh
python scripts/test_production_release_signing_evidence.py
python scripts/check_production_release_signing_evidence.py
python scripts/test_release_signatures.py
python scripts/check_release_signatures.py
python scripts/test_signed_release_tag.py
python scripts/check_signed_release_tag.py
python scripts/generate_release_evidence_packet_index.py --check
python scripts/generate_release_manifest.py --check
python scripts/generate_release_checksums.py --check
```

## Operator Notes

- Keep #223 and #224 open until reviewed production release-signing evidence is
  linked from the shared release evidence status manifest.
- Do not commit private keys, mnemonic material, API keys, RPC URLs, signer
  service secrets, unreleased drop payloads, or private ceremony transcripts.
- For pending-review or reviewed evidence, required retained artifact fields
  must be repo-relative UTF-8 files. Absolute paths, `..` escapes, Windows
  backslashes, ambiguous whitespace in paths, placeholders, missing files,
  stale hashes, duplicate hashes, provider/API-token-shaped URLs, credentialed
  URLs, bearer tokens, CLI secret flags, bare 64-hex strings, symlinked files,
  and non-UTF-8 files fail validation. The checksum bundle field is the one
  retained file allowed to contain `sha256sum`-style bare digest lines because
  that is the exact file being signed.
- Retained file references may append one declared digest as
  `path/to/file sha256:<64 lowercase hex>` or
  `path/to/file / sha256:<64 lowercase hex>`. Normalize `sha256sum`-style
  retained digest output, including release digest files, to the explicit
  `sha256:<hex>` form before review.
- The referenced release signature evidence JSON must also pass
  `scripts/check_release_signatures.py` and must describe a `mainnet` or
  `production` release whose version and commit match this retained artifact.
  The signed Git tag release-mode verifier remains the source of truth for live
  `git tag -v` validation when an actual release tag exists locally.
