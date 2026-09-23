# ADR 0050: Original attribution dispute withdrawal

- Status: Accepted integrator decision for the developing full-v1 implementation.
- Date: 2026-09-16.
- Evidence: source and focused ABI checks; authored scenarios await runtime execution.

## Decision

Implement AA-DISPUTE requirement 4 and its already pinned action **2 WITHDRAW**
with additive operation **61**, `withdrawAttributionDispute`. The original 57-row
catalog pins operation 44 to action 1. It stays exact, as do operations 45–60.
The separate withdrawal selector never grants the arbiter an unstaged exit.
The [typed operation extension](../architecture/artist-operation61-dispute-withdrawal.json)
is normative for this addition. Operation 61 belongs to withdrawal; a proposed
primary-resolver graph transition has no adopted operation number or recipe.

The caller supplies the original `Filing`, `Standing` and `Authorization` tuples.
It signs the original `StreamArtistAttributionDispute` EIP-712 payload under the
current Registry domain, with action 2 and the original deadline and nonce rules.
The record retains the original `DISPUTE_RECORD_DOMAIN` twelve-word preimage.
No transport-specific signature is substituted.

The exact live disputed generation must still have its original open record.
That record must be a signed artist-side opening, not a governed arbiter opening
or a reopened arbiter revocation. The saved opener signer, signing class and full
Standing tuple must match, and that signer must authenticate through the current
original Identity or delegation machinery. A new principal after rotation does
not inherit another address's unilateral withdrawal right. The old address also
cannot act after losing current authority. An original delegate needs the same
still-live CAP_DISPUTE grant, its current epoch, deadline, nonce, revocation and
remaining-use checks. The primary cannot replace a delegate opener, nor vice versa.
A prior-generation artist or accepted collaborator opener uses its exact saved
standing and its own still-current authority. The arbiter resolution route remains
available when the original opener is no longer authorized.

Withdrawal is defensive speech while Identity is contested. It restores only the
saved attribution state (ACCEPTED or VERIFIED), never dismisses the independent
identity compromise, and does not revive any repudiation invalidated by opening.
Successful authentication uses the existing activity hooks, cancelling any live
dormancy or unavailability notice through the original state and epoch rules.

Both evidence and reason are the original covered 192-byte commitment documents.
Their immutable parent must be this opening, preventing a fresh signature over an
old episode's documents from being retargeted. Narrative availability and truth
are not independently established by the commitment-document profile.

## State, history and atomicity

Read/snapshot mask is `0x15` (Binding, Identity, Attribution); write mask is `0x14`.
Identity performs its original zero-record authorization commit. Attribution
appends one original signed record, one schema-1 withdrawal event and the original
context/state-change event shapes. A new namespaced map records the immutable
outcome keyed by opening: withdrawal record, latest counterstatement and restored
state. The existing Head and Record tuple ABIs and old storage remain unchanged.
The latest counterstatement is retained even when withdrawal closes the dispute.
A later opening preserves the old opening and all outcomes.

The new Attribution replay surface is
`attribution_lifecycle.replay.dispute_withdrawal_key`, scoped to the opening hash.
Native receipts and lane sync explicitly accept operation 61; operation 60 still
has no synthetic signed-record receipt and unknown operations still fail closed.
Archive uses the existing atomic operation evidence envelope. Late append or sync
failure reverts all state, nonce/grant use, activity, events and Safe execution.

Existing operation-60 hydration profiles continue to reject dispute histories,
including withdrawals. Lane reconstruction alone grants no imported authority.
Complete dispute/withdrawal hydration remains explicit further work.

## Validation scope

Ten authored cases use actual Artist owners, Safes, Archive and dual-family
coverage, with existing explicit Core, metadata getter and governance boundaries.
They cover exact digest/record/event/native-lane reconstruction; current-opener,
arbiter, rotation, grant-use/revocation/exhaustion and contested-identity rules;
deadline/nonce/owner admission; stale resolution and episode retargeting; and
missing-coverage/late-Archive rollback with identical Safe retry.
No native execution, deployability or current-Executor acceptance is claimed.
Existing oversized Artist products and unapplied size proposals remain separate.
