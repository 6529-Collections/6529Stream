# Admin Ceremony Retained Artifact Template

> Template only. This file is not completion evidence.

## Evidence Status

- Evidence ID: `admin-ceremony-template`
- Requirement: `GOV-001`
- Review status: `template`
- Readiness claim: `blocked`

## Required Retained Inputs

- Deployment manifest or reviewed deployment config.
- Address book for the deployed contracts.
- Ownership transfer transaction or explicit intentionally-blocked rationale.
- Role grant and revocation transactions.
- Drop signer and signer-manager setup evidence.
- Pause guardian, unpause admin, and emergency recipient setup evidence.
- Post-state reads for each privileged surface.
- Explorer or source-verification status.

## Redaction

Do not retain private keys, mnemonics, Safe signing secrets, signer-service
credentials, signer secrets, passwords, client secrets, session cookies,
private RPC URLs, API keys, bearer tokens, raw signatures, or unreleased drop
payloads. Retain public addresses, transaction hashes, block references,
reviewer names, issue links, and sanitized command transcripts.

## Validation Commands

```sh
python scripts/test_admin_ceremony_evidence.py
python scripts/check_admin_ceremony_evidence.py
python scripts/generate_release_manifest.py --check
python scripts/generate_release_checksums.py --check
```

## Operator Notes

Copy `deployments/admin-ceremony/admin-ceremony-evidence-template.json` for a
fork, testnet, mainnet, or production ceremony. Replace every template status,
placeholder address, placeholder hash, and `TBD` field before requesting
review.
