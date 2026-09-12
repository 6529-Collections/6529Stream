# ADR 0031: Quorum-anchored public estate archival evidence

Status: Accepted design; implementation and candidate evidence remain gated.

Date: 2026-09-12

## Context

AA-ESTATE requires dual-family mirrored activation evidence. CMC-RECEIPTS and
LTA-ARCHIVE require actual receipt evidence, independent storage families and
per-family passing fixity. At least one family must have ENDOWED economics;
two renewal-funded families cannot fill the pair. The generic preservation
record store does not verify these facts and cannot supply this admission.

The first provider needs an executable network-anchoring profile without
claiming a native storage-network consensus light client. The protocol's three
existing receipt evidence classes and the permanent estate signature and
record preimages remain unchanged.

## Decision

The first profile supports a complete public payload of 1 through 8,192 bytes.
Its declared schema is `6529STREAM_PUBLIC_ESTATE_EVIDENCE_V1`, with
`BINARY_EXACT_V1` canonicalization. Both SHA256 and keccak256 and the exact size
are recomputed from retained bytes. This schema treats the evidence as an
opaque binary document; it does not validate arbitrary JSON or establish the
truth of a legal assertion. The estate notice and contest procedure remains
responsible for contested claims. Sealed payloads cannot satisfy this profile
until a separately implemented custody admission verifies their exact policy.

The endowed slot uses an explicitly named Arweave-mainnet profile. A fixed
configuration of at most eight sorted observer accounts, with unique nonzero
organization identifiers, must provide a quorum of at least two signatures.
The certificate binds the network, block hash and height, transaction root,
block size, transaction identifier, data root and size, exact transaction
range, observation time and immutable configuration identity. The verifier
then checks actual native annotated SHA256 transaction and data paths and the
complete payload. There is no governance method that installs an arbitrary
unverified data root.

This is **quorum-attested network anchoring**. Observer honesty establishes the
block's network membership and the transaction-ID-to-data-root association.
The contract verifies inclusion under those authenticated facts; it does not
verify Arweave consensus, block signatures or native transaction signatures.
The certificate, proof paths, configuration and verified digests remain
inspectable. A local synthetic certificate proves the mechanism only. A real
network receipt/checkpoint rehearsal is required before candidate acceptance.

The bounded native algorithm supports at most 32 non-rebased transaction-path
branches and a single 64-byte data leaf. The transaction range must match the
actual verified positive-size leaf. Native padding is represented in sibling
leaves, not counted as payload bytes. Partial chunks, rebasing and clamped
malformed or zero-size leaf shapes fail closed. The source reference is
[Arweave commit 18d402c7](https://github.com/ArweaveTeam/arweave/tree/18d402c714132e1de3962b12ff32a420127e0c02);
the fixture retains exact source hashes and separately generated vectors.

The second slot uses a registered independent storing agent's signed
ATTESTED_POSSESSION receipt. Its supported raw CIDv1/SHA256 form must bind the
same payload digest. An independent typed possession object is hashed before
the receipt is signed; neither that signature nor later fixity refers
circularly to its own receipt hash. This is attested possession, not a claim
that the CID alone proves storage or endowed economics.

Both family records are immutable governance-admitted taxonomy rows. Pair
checks compare nonzero network, protocol lineage, addressing lineage,
custodian, funding dependency and retrieval dependency identifiers; every
corresponding dimension must differ. Jurisdiction is recorded without being
an independence discriminator. The authenticated storing agents also differ.
Taxonomy admission remains a reviewed governance judgment about the actual
organizations and dependencies. It is not inferred from two wallet addresses.
Status changes preserve rows and advance a revision, so an old queued
governance context cannot replay after a status returns to an earlier value.

Every receipt requires a current passing fixity head. The verifier holds the
actual canonical RoleRegistry's ROLE_FIXITY_OPERATOR and differs from the
receipt's authenticated writer. The registry is owned by the canonical
Executor. A failure prevents selecting an older passing head; restoration
requires a later passing observation with explicit repair lineage and a new
coverage record. No arbitrary estate-specific freshness timeout is added.

Deployment order is canonical Executor/RoleRegistry/Core, checkpoint verifier,
coverage provider, artist facade with its mandatory immutable provider
constructor pin, then canonical Core selection. The provider validates
canonical governance and actual profile/code/configuration at construction.
Its validating coverage read later requires the actual selected deployed
facade, matching Core and reciprocal provider pin. There is no constructor
cycle, zero-code readiness case or mutable artist/provider fallback.

All external signature and dependency reads have explicit bounds. Their
Governed Gas Parameters use failureClass 2 and only exact delayed actionClass 1
raises. Initial test values are planning inputs; supported Safe configurations
and full parent/target gas paths need measured deployment admission.

## Consequences and remaining gates

The profile supplies actual typed archival admission for public estate
activation evidence and can be reused by later preservation/finality work.
It introduces explicit observer-oracle trust. Compromised quorum members can
attest false network membership; native path verification does not remove that
assumption. Independent fixity and taxonomy checks serve different obligations.

Passing domain fixtures is not a real-network rehearsal, proof of legal truth,
complete preservation implementation, finality readiness or estate activation
by itself. Estate operations 38–40 must still implement liveness cancellation,
notice and contest timing, actual authority/capability transfer, delegation
revocation and the coupled commercial paths. Broader private custody, repair
automation, archival migration and finality obligations remain explicit.

The estate-facing validation may select newer valid coverage at execution only
for the exact original envelope and evidence. It cannot replace evidence or
revive a cancelled or voided activation request.
