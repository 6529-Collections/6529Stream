# Protocol Incident Response

This runbook is the operator-facing incident response guide for 6529Stream.
The repository is pre-audit and not production-ready. It is not a security claim.
It gives maintainers a no-secret procedure for triage, containment,
recovery, evidence retention, and reopening when protocol or release operations
behave unexpectedly.

Use this runbook with the private reporting process in
[`SECURITY.md`](../SECURITY.md), the release-readiness dashboard in
[`docs/release-readiness.md`](release-readiness.md), the non-local evidence
intake runbook in
[`docs/non-local-release-evidence.md`](non-local-release-evidence.md), and the
current roadmap in [`ops/ROADMAP.md`](../ops/ROADMAP.md).
Release-status changes should also follow
[`docs/public-beta-evidence.md`](public-beta-evidence.md) and
[`docs/release-policy.md`](release-policy.md).
Signer-compromise and drop-authorization incidents should also use
[`docs/drop-authorization-signing.md`](drop-authorization-signing.md).

## Maturity And Scope

This runbook applies to incidents involving:

- stuck auctions, settlement, cancellation, or NFT custody uncertainty;
- failed randomness, stale randomness, failed post-processing, provider
  migration, or retry/recovery decisions;
- bad Merkle roots, bad curator reward claims, duplicate leaves, or suspected
  proof generation mistakes;
- bad metadata, dependency configuration, dependency source retention,
  renderer policy, or unfrozen collection repinning mistakes;
- signer compromise, stale signer epochs, leaked authorization payloads, or
  drop execution pause decisions;
- release artifact, checksum, manifest, address-book, evidence, or verification
  mistakes.

This runbook does not replace contract tests, a completed external audit,
production Safe procedures, fork/testnet/live rehearsal evidence, or private
security-advisory handling. If a report contains exploitable details, keep the
technical exploit path private until maintainers agree on disclosure timing.

## Roles And Severity

Every incident record should identify public role labels, not private keys or
secret operational details.

| Role | Responsibility |
| --- | --- |
| Incident lead | Owns triage, severity, decision log, and reopening criteria |
| Protocol maintainer | Maps observed behavior to contracts, ADRs, tests, and rollback or redeployment options |
| Operations maintainer | Executes pause, signer, release, evidence, or deployment actions through the approved ceremony |
| Communications owner | Publishes public status updates that avoid exploit details and unreleased drop payloads |
| Reviewer | Checks evidence, recovery commands, and post-incident notes before reopening |

Severity should be assigned conservatively:

| Severity | Examples | Minimum response |
| --- | --- | --- |
| SEV-1 | Live fund loss, active exploit, wrong NFT custody, signer compromise, or public bad metadata for a live drop | Private security channel, emergency pause assessment, public holding statement, retained evidence, post-incident review |
| SEV-2 | Failed settlement, failed randomness, bad Merkle root, bad dependency version, or release artifact drift before public impact | Domain-specific pause assessment, affected-surface freeze, reviewed recovery plan, retained evidence |
| SEV-3 | Local rehearsal failure, checker drift, missing evidence, stale manifest, or documentation mismatch | Fix-forward PR, evidence update, no public readiness claim |

## Universal Triage

1. Identify the affected surface: auction, randomizer, curator rewards,
   metadata, dependency, signer, admin, deployment, release artifact, or
   evidence.
2. Preserve current state before taking action: transaction hashes, block
   numbers, chain ID, contract addresses, release commit, manifest hash,
   relevant event logs, public screenshots, and no-secret command output.
3. Decide whether an emergency pause is needed for mint, bid, settlement,
   signer, metadata, dependency, randomizer, or release operations.
4. Confirm withdrawal availability. Do not pause withdrawals unless the
   accepted pause policy says the withdrawal path itself is unsafe.
5. Stop new public claims of public beta or production readiness until the
   incident lead records the current status in the issue, advisory, release
   notes, or roadmap.
6. Assign the incident lead, protocol maintainer, operations maintainer,
   communications owner, and reviewer.
7. Capture a decision log with UTC timestamps, transaction hashes, commands,
   evidence paths, and reviewer names.

## Evidence Retention And Communications

Incident evidence must be public-safe before it is committed.

Retain:

- issue, advisory, PR, release, deployment, and chain references;
- sanitized event logs, traces, screenshots, command output, and manifest
  diffs;
- affected contract addresses, chain ID, block range, and confirmation depth;
- current pause, signer epoch, randomizer epoch, Merkle root, dependency
  version, release manifest, and checksum state;
- reviewer identity, redaction statement, retained path, and SHA-256 digest for
  every non-local artifact.

Do not retain:

- private keys, mnemonics, Safe signing secrets, session cookies, API keys, or
  bearer tokens;
- private RPC URLs or provider dashboard URLs with embedded credentials;
- unreleased drop authorizations, unreleased Merkle proofs, unreleased token
  data, or non-public artist assets;
- exploitable proof-of-concept details in a public issue before disclosure is
  approved.

For fork, testnet, live, audit, explorer, gas, invariant, signature, or
post-incident evidence that changes release readiness, follow
[`docs/non-local-release-evidence.md`](non-local-release-evidence.md) and update
[`release-artifacts/latest/public-beta-evidence.json`](../release-artifacts/latest/public-beta-evidence.json)
only after review.

## Runbook: Stuck Auctions Or Settlement

Use this runbook when auction creation, bidding, cancellation, settlement,
custody, or proceeds withdrawal is stuck or inconsistent.

Immediate checks:

- Read auction state and compare it with the state model in
  [`docs/auction-custody.md`](auction-custody.md).
- Confirm token custody through owner views and relevant transfer events.
- Confirm highest bidder, highest bid, poster credit, curator credit, protocol
  credit, bidder credit, and total owed views.
- Confirm whether settlement is already terminal and idempotent.
- Confirm withdrawal availability for unaffected credits.

Containment:

- Consider bid pause or settlement pause if new bids or settlements can worsen
  the incident.
- Do not move an escrowed token or owed funds through emergency withdrawal.
- Do not erase bidder, poster, curator, or protocol credits during recovery.

Recovery:

- Prefer idempotent settlement, cancellation, or withdrawal paths that preserve
  credits and event history.
- If custody cannot be corrected safely, follow the emergency redeployment path
  in [`docs/deployment.md`](deployment.md) and
  [ADR 0007](adr/0007-upgrade-redeployment.md).
- Record the final token owner, final auction state, final owed balances, and
  zero-surplus or remaining-surplus explanation.

Reopen only after tests or retained evidence show token custody is known,
credits are covered by contract balance, and failed withdrawals do not erase
credit.

## Runbook: Failed Or Stale Randomness

Use this runbook when a request is pending too long, fails post-processing,
receives an unexpected callback, or is affected by provider migration.

Immediate checks:

- Read request ID, token ID, collection ID, provider epoch, randomizer adapter,
  raw output hash, pending count, stale state, and failed post-processing
  state.
- Compare the live state with
  [`docs/randomizer-operations.md`](randomizer-operations.md) and
  [ADR 0005](adr/0005-randomness.md).
- Confirm provider funding, billing, and request-health evidence.
- Confirm whether a retry/recovery path uses the stored seed and does not
  request new randomness.

Containment:

- Consider mint pause or randomizer migration pause if new requests could be
  affected.
- Do not replace a provider while pending requests exist unless the accepted
  migration policy explicitly permits stale marking.
- Keep withdrawal availability separate from randomizer request handling.

Recovery:

- For stale requests, record the stale-marking evidence and the provider epoch.
- For failed post-processing, use the bounded retry/recovery path and retain
  command output.
- For invalid callbacks, retain the callback transaction, request ID, token,
  collection, provider, and epoch evidence.
- Update randomizer operations evidence after fork, testnet, or live recovery.

Reopen only after request lifecycle views, metadata state, provider epoch, and
retry or stale status are coherent.

## Runbook: Bad Merkle Roots Or Curator Claims

Use this runbook when a curator reward root, proof generator, claim amount,
claimant address, or delegation assumption is wrong.

Immediate checks:

- Identify the root, root epoch, collection ID, claimant, amount, proof, and
  transaction hash.
- Verify leaf encoding uses `abi.encode` with unambiguous domain fields.
- Check duplicate leaves, double-claim attempts, delegation state, curator
  credit, and total owed views.
- Confirm whether any claim has already created withdrawable credit.

Containment:

- Pause or withhold new root publication if future claims could be wrong.
- Do not delete existing curator credits. Failed withdrawal must not erase
  credit.
- Communicate whether the issue affects only future claims or already-created
  credits.

Recovery:

- Publish a corrected root only after proof generation is reviewed.
- Retain old and new roots, generator inputs, code commit, review notes, and
  no-secret sample proofs.
- If an incorrect claim already executed, document the immutable on-chain state
  and any follow-up compensation or redeployment path outside the contract.

Reopen only after duplicate leaves and double claims are tested or otherwise
reviewed, and the affected root epoch is documented.

## Runbook: Bad Metadata Or Dependency Configuration

Use this runbook when metadata JSON, token image URI, attributes, animation
HTML, dependency source, dependency provenance, or collection dependency pinning
is wrong.

Immediate checks:

- Determine whether the affected collection is frozen.
- Read dependency key, version, content hash, registry address, freeze manifest,
  metadata state, and current `tokenURI` output.
- Compare the incident with [`docs/metadata.md`](metadata.md),
  [`docs/dependency-operations.md`](dependency-operations.md), and
  [ADR 0006](adr/0006-metadata-freeze.md).
- Run metadata fixture/browser checks for the affected output where possible.

Containment:

- For unfrozen collections, pause metadata/dependency update operations if the
  accepted admin model supports it.
- For frozen collections, do not imply that frozen output can be mutated.
- Stop publishing marketplaces or indexer guidance that depends on the bad
  output until the corrected state is reviewed.

Recovery:

- For unfrozen collections, register a corrected dependency version or metadata
  update and retain source, descriptor, manifest, checksum, and review evidence.
- For frozen collections, document the immutable proof and decide whether ADR
  0007 redeployment or a new collection path is required.
- Regenerate release manifest and checksum evidence after changing dependency
  source, metadata docs, or governance docs.

Reopen only after the corrected metadata/dependency state is retained, checked,
and communicated to affected integrators.

## Runbook: Signer Compromise Or Drop Authorization

Use this runbook when a drop signer, signer manager, signed payload, domain,
deadline, signer epoch, or drop ID is suspected to be compromised.

Immediate checks:

- Identify the signer, signer manager, signer epoch, drop ID, deadline, domain,
  verifying contract, chain ID, consumed state, cancelled state, and affected
  authorization payloads.
- Compare the payload and digest with
  [`docs/drop-authorization-signing.md`](drop-authorization-signing.md).
- Compare retained signing evidence with
  [`release-artifacts/schema/drop-authorization-signing-evidence.schema.json`](../release-artifacts/schema/drop-authorization-signing-evidence.schema.json)
  and
  [`release-artifacts/drop-authorization-signing/drop-authorization-signing-retained-artifact.txt`](../release-artifacts/drop-authorization-signing/drop-authorization-signing-retained-artifact.txt).
- Compare retained signing ceremony metadata with
  [`release-artifacts/drop-authorization-signing/drop-authorization-signing-evidence-template.json`](../release-artifacts/drop-authorization-signing/drop-authorization-signing-evidence-template.json)
  and `python scripts/check_drop_authorization_signing_evidence.py`.
- Confirm whether any payload has already been executed.
- Preserve EIP-712 domain and signature validation evidence without committing
  unreleased payloads.

Containment:

- Use emergency pause for drop execution if new payloads could execute.
- Revoke or rotate the signer through the accepted signer lifecycle controls.
- Increment signer epoch or cancel affected drop IDs where available.
- Keep withdrawal availability separate from drop execution pause unless a
  payment path is independently unsafe.

Recovery:

- Reissue only reviewed payloads under the new signer epoch and domain.
- Use the no-secret unsigned payload generator in
  [`docs/drop-authorization-signing.md`](drop-authorization-signing.md) to
  rebuild reviewed typed data, then pass the generated typed data to the
  approved signing system outside the repository. Include the generated digest
  as cross-check evidence and for ERC-1271 `isValidSignature` verification
  inputs where applicable.
- Retain redacted signer-rotation evidence, event logs, affected drop IDs,
  cancellation transactions, reviewer notes, signing-system output metadata,
  and signature verification evidence using the drop authorization signing
  evidence schema.
- Update public communications with the new active signer state and any
  affected drop status.

Reopen only after stale signer payloads, wrong domains, expired payloads,
replays, and cancelled drop IDs fail in tests or retained evidence.

## Runbook: Release Artifact Or Evidence Mistake

Use this runbook when release manifests, checksum bundles, address books,
source verification inputs, evidence metadata, public-beta status, or release
notes drift from committed reality.

Immediate checks:

- Identify the release commit, PR, CI run, manifest path, checksum file,
  affected evidence file, and public-beta requirement ID.
- Run the relevant checkers from [`docs/tooling.md`](tooling.md).
- Confirm whether a public release claim, signature, signed tag, address book,
  or explorer verification link depended on the bad artifact.

Containment:

- Stop distribution of the affected artifact or release claim.
- Do not sign a checksum bundle that is known to be stale.
- Do not mark public-beta evidence complete based on unreviewed or stale
  evidence.

Recovery:

- Regenerate release manifest and checksum outputs from committed inputs.
- Replace or correct the retained evidence metadata only after redaction and
  reviewer checks.
- Update release notes, changelog, public-beta evidence status, and
  release-readiness docs if the public claim changed.

Reopen only after check-mode commands pass and the retained evidence hash
matches the corrected artifact.

## Reopening And Post-Incident Review

An incident can be reopened only when:

- containment actions are either removed or intentionally left in place with an
  owner and expiry;
- emergency pause, withdrawal availability, signer revocation, retry/recovery,
  and evidence retention decisions are recorded;
- every changed external behavior has a test, retained evidence item, or
  explicit non-code acceptance decision;
- release manifest and checksum outputs are current if any covered artifact or
  governance document changed;
- public communications and release-readiness docs no longer overstate
  maturity.

The post-incident review should capture root cause, affected users or drops,
timeline, detection gap, recovery actions, tests added, docs changed, remaining
risk, and follow-up issue links.

## Local Verification Commands

Run the incident-response checker directly:

```sh
python scripts/test_incident_response.py
python scripts/check_incident_response.py
python scripts/test_drop_authorization_payload_generator.py
python scripts/generate_drop_authorization_payload.py --input test/fixtures/drop-authorization/payload-generator/fixed-price-input.json --output test/fixtures/drop-authorization/payload-generator/fixed-price-output.json --check
python scripts/generate_drop_authorization_payload.py --input test/fixtures/drop-authorization/payload-generator/auction-input.json --output test/fixtures/drop-authorization/payload-generator/auction-output.json --check
python scripts/test_drop_authorization_fixtures.py
python scripts/check_drop_authorization_fixtures.py
python scripts/test_drop_authorization_signing_evidence.py
python scripts/check_drop_authorization_signing_evidence.py
```

Run the release evidence checks after changing this runbook or linked
governance docs:

```sh
python scripts/generate_release_manifest.py --check
python scripts/generate_release_checksums.py --check
```

Run the full local gate before merge:

```sh
make check
powershell -ExecutionPolicy Bypass -File scripts\check.ps1
```

## Maintenance

Update this runbook whenever pause semantics, signer lifecycle, auction
custody, randomizer recovery, Merkle reward handling, metadata/dependency
operations, release evidence, security reporting, or public-beta readiness
changes.

After editing this file, run:

```sh
python scripts/test_incident_response.py
python scripts/check_incident_response.py
python scripts/test_release_readiness.py
python scripts/check_release_readiness.py
python scripts/test_audit_package.py
python scripts/check_audit_package.py
python scripts/test_drop_authorization_fixtures.py
python scripts/check_drop_authorization_fixtures.py
python scripts/test_drop_authorization_signing_evidence.py
python scripts/check_drop_authorization_signing_evidence.py
python scripts/generate_release_manifest.py
python scripts/generate_release_checksums.py
python scripts/generate_release_manifest.py --check
python scripts/generate_release_checksums.py --check
```
