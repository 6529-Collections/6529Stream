# Signer Compromise Drill Retained Artifact

> Template only. This file is not completion evidence.

## Evidence Status

- Requirement ID: `signer_compromise_drill_evidence`
- Review status: `template`
- Readiness claim: `blocked`
- Environment: `template`
- Chain ID: `TBD`

## Drill Context

- Repository: `https://github.com/6529-Collections/6529Stream`
- Release commit: `TBD`
- Deployment version: `TBD`
- Drill bundle reference: `TBD`
- Incident class: `signer_compromise`
- Affected signer: `TBD`
- Replacement signer: `TBD`
- Signer manager: `TBD`
- Starting signer epoch: `TBD`
- Ending signer epoch: `TBD`
- Affected drop IDs: `TBD`
- Affected EIP-712 domain: `TBD`

## Containment Sequence

- Drop execution pause evidence: `TBD`
- Signer rotation evidence: `TBD`
- Signer revocation evidence: `TBD`
- Signer epoch invalidation evidence: `TBD`
- Per-drop cancellation evidence: `TBD`
- Withdrawal availability evidence: `TBD`

## Recovery Sequence

- Stale payload rejection evidence: `TBD`
- Cancelled payload rejection evidence: `TBD`
- Wrong-domain rejection evidence: `TBD`
- Recovered fixed-price payload evidence: `TBD`
- Recovered auction payload evidence: `TBD`
- Post-recovery signer state evidence: `TBD`

## Monitoring And Handoff

- Operator dashboard confirmation: `TBD`
- Monitoring alert reference: `TBD`
- Incident response decision log: `TBD`
- Public communication status: `TBD`
- Follow-up issue links: `TBD`

## Required Retained Artifacts

- Command transcript bundle: `TBD`
- Event or state snapshot bundle: `TBD`
- Signer custody readiness evidence: `TBD`
- Drop authorization signing evidence: `TBD`
- Admin ceremony evidence: `TBD`
- Release manifest/checksum digests: `TBD`

## Review

- Operator: `TBD`
- Reviewer: `TBD`
- Review decision: `template`

## Redaction

- No secrets retained: `TBD`
- Private RPC URLs removed: `TBD`
- Private keys removed: `TBD`
- Signer-service secrets removed: `TBD`
- Raw signatures removed: `TBD`
- Unreleased drop payloads removed: `TBD`
- Private collector data removed: `TBD`

## Validation Commands

```sh
python scripts/test_signer_compromise_drill_evidence.py
python scripts/check_signer_compromise_drill_evidence.py
python scripts/test_incident_drill_evidence.py
python scripts/check_incident_drill_evidence.py
python scripts/test_incident_response.py
python scripts/check_incident_response.py
python scripts/test_release_readiness.py
python scripts/check_release_readiness.py
python scripts/generate_release_manifest.py --check
python scripts/generate_release_checksums.py --check
```

## Operator Notes

- Replace every `TBD` field before requesting review.
- This artifact is for public-safe retained evidence only. It must never include
  private keys, mnemonics, signer-service credentials, private RPC URLs, raw
  signatures, unreleased drop authorization payloads, unreleased Merkle proofs,
  or private collector data.
- A reviewed signer-compromise drill should prove the operator can pause
  drop execution, rotate or revoke the signer, invalidate stale signer epochs,
  cancel affected drop IDs, reject stale/cancelled/wrong-domain payloads, and
  recover with reviewed fixed-price and auction payloads.
- Keep withdrawal availability separate from drop execution containment unless
  the withdrawal path is independently unsafe.
