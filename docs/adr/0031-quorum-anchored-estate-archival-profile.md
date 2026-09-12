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

Deployment first prepares and initializes the canonical governance foundation,
including the Executor's actual RoleRegistry binding and the registry's
Executor ownership. The checkpoint verifier and coverage provider follow, then
the artist facade with its mandatory immutable provider constructor pin and
ordinary catalog extension and Core activation. This staged bootstrap is defined
in [ADR0032](0032-governance-foundation-before-product-activation.md). The old
all-products-before-genesis order creates a dependency cycle and cannot deploy
this profile. The provider validates canonical governance and actual
profile/code/configuration at construction. Its validating coverage read later
requires the actual selected deployed facade, matching Core and reciprocal
provider pin. No zero-code readiness case or mutable artist/provider fallback
resolves missing initialization; the deployment script and current fixture must
use the staged foundation.

All external signature and dependency reads have explicit bounds. Their
Governed Gas Parameters use failureClass 2 and only exact delayed actionClass 1
raises. Initial test values are planning inputs; supported Safe configurations
and full parent/target gas paths need measured deployment admission.

## Estate activation and current authority

The estate implementation preserves the permanent five-field activation signed
payload and nine-field request record. Selection of the operative designation
and verified coverage is supplemental admission evidence. The request captures
the current notice duration and revision, the larger of the rotation contest
period and operative guardian minimum, the prior-standing tail and timing
revision. Later parameter changes cannot alter those captured durations.
Execution may occur at the notice deadline. Earlier execution requires the
canonical Executor's delayed action class 1, its actual current per-call
scope and old/new state commitments, and a stored action whose reason hash is
exactly the activation evidence hash. Estate acceleration does not introduce
an arbiter role requirement.

Every successful action by the living current AUTH_ARTIST cancels an active
request, including in the same block or after notice expiry before execution.
The cancelling write and cancellation share the Identity commit and Archive
transaction: a later failure rolls both back. Delegation use, guardian actions,
governance actions and passive reads do not become living acts. An actual
operation 33 contest terminates a pending estate and records its real contest
cause and cancellation replay state. It does not fabricate operation 39 or an
artist-class cancellation event. Dismissal cannot revive a terminated request.

Activation grants the designation's capabilities intersected with its explicitly
paired directive, if any, minus the latest eligible directive's global forbidden
mask. An unrelated later directive cannot add grants. A zero-capability successor
is valid. Identity becomes SUCCEEDED (3) with AUTH_SUCCESSOR (3), the actual
active address changes, and the delegation epoch advances. Existing consent,
binding, payout and replay history remains immutable. Every outstanding old-key
proof is checked against the new actual authority; pre-activation delegations
are unusable, while their exact recorded grantor retains revocation standing.

The accepted current-authority interpretation allows fresh primary acceptance
or refusal (2/3) by the successor of the artistId already fixed in the proposal.
This preserves the exact Binding and records truthful class-3 provenance; it
does not authorize a new work's policy. Collaborator acceptance (7) still names
the immutable listed account and resolves its active identity only when that
row is accepted. An old pending account is never redirected to a successor;
changing it requires termination and a new proposal generation. Delegation
grants (26) remain AUTH_ARTIST-only; revocation (27) belongs to the exact recorded
grantor. Current-authority address rotation (29) and prior-standing revocation
(51) accept class 3 without inventing a capability bit. Other successor writes
apply their expressly named capability, including sale 1024, economics 4,
policy 2, content 128, identity/payout 512, attestation 1, guardian 256 and royalty
freeze 32. Removing the living artist's captured lifetime guardians additionally
requires capability 2048. Unsupported recovery and dormancy paths remain absent.

Commercial reads expose the exact accepted artistId, generation and Binding
hash together with the current address, class, status and effective capabilities.
A fresh successor-authored commercial proof requires sale capability 1024 and
the actual current signature. Finalizing an already-authorized obligation with
the exact saved association does not reverify its historical signature or
require a new action capability, but still requires ordinary current authority
and actual mint, economics and sale-consent admission. A status-4 identity is
not ordinary authority and is not itself an attribution dispute or revocation.

## Bounded transition storage and deployment

The existing latest-transition and latest-execution indexes hold references to
actual rotation or estate records. The referenced record belongs to exactly
one family and the same artistId; an unknown nonzero reference fails closed.
Rotation-only record getters keep their original meaning. Requests advance the
latest transition; only execution advances the latest execution. Closure-aware
window reads expose a new pending estate even after an earlier execution was
closed. Eligibility uses the actual immutable transition timing, and fresh
writes cannot attach to an abandoned cohort.

Identity retains one physical storage layout and one semantic owner. Its two
writer extensions are constructor-fixed children: the original writer is CREATE
nonce 1 and the estate/current-transition writer is nonce 2. Every host writer
selector is explicit and forwards only to its fixed child. There is no fallback,
caller-selected target, selector table or mutable routing. A direct child CALL
fails its exact host-context guard before effects; delegated execution retains
the actual Identity caller, emitter, replay cells, snapshots and one commit.
Compiler-linked guardian and authorization helpers operate on those same storage
references. Fixed read encoders return the exact declared tuple bytes; they do
not introduce new operative state or a view delegatecall surface. Actual
constructor arguments, child derivation, runtime and initcode limits, ABI and
recursive physical storage require a matching executed proof.

The facade has one additional mandatory immutable archivalCoverage constructor
argument between governance and deploymentHash; SuiteConfiguration is unchanged.
The artist's outer coverage budget must contain the provider's own bounded
reads. The initial outer test value is 400,000 with floor 250,000 and failure
class 2, distinct from the provider's 150,000 dependency budget. This is not a
cold-gas sizing claim; the full capped composition and raise/retry control must
be measured before supported deployment admission.

## Consequences and remaining gates

The profile supplies actual typed archival admission for public estate
activation evidence and can be reused by later preservation/finality work.
It introduces explicit observer-oracle trust. Compromised quorum members can
attest false network membership; native path verification does not remove that
assumption. Independent fixity and taxonomy checks serve different obligations.

Passing domain fixtures is not an independent observer rehearsal, proof of
legal truth, complete preservation implementation or finality readiness.
Network-derived native paths can exercise the inclusion algorithm while local
fixture observers remain a separate trust boundary. Candidate acceptance still
requires the actual current-stack estate flow, measured nested call budgets,
canonical governance deployment and the coupled commercial paths. The estate
domain tests exercise liveness cancellation, notice and contest timing,
authority/capability transfer and delegation invalidation within their stated
Core and governance boundaries. Broader private custody, repair automation,
archival migration and finality obligations remain explicit.

The estate-facing validation may select newer valid coverage at execution only
for the exact original envelope and evidence. It cannot replace evidence or
revive a cancelled or voided activation request.
