# Active Context

## Goal

Deliver issue #664 through coordinator-approved sequential slices, each ending
as an agent-happy and bot-happy review-ready draft PR. The current slice is the
partial Proposed ADR 0019 review surface; it does not complete issue #664.

## Branch

`codex/payment-intent-adapter`, created from fetched `origin/main` at
`b4af30a58c22f79bafad241c6e4fab7a4a76063b` and finally rebased after #688,
#669, and their serialized prerequisites to
`f7100716be652b3dc4aa2eed1ef7d109b3216e7a`.

## Current State

- The worktree began clean and isolated.
- Issue #664 and issue #688 have been read.
- The root operating guide, autonomous-manager skill, PR skill, GitHub
  publish/review/CI skills, roadmap, execution backlog, maturity docs, tooling,
  payment/revenue ADRs, and the normative PaymentIntent sections have been
  inspected.
- Current `StreamPrimarySaleSettlement` performs the payer allowance pull
  itself, while the accepted architecture says genesis inventory contract 20 is
  the top-level PaymentIntent verifier and sole protocol pull initiator, while
  contract 9 is not.
- No concrete launch sale adapter or `StreamRevenueEscrow` exists on current
  main.
- `IStreamSplitFactory` exposes no governed gas-parameter host, although
  `[RSR-1271]` requires the verifier to read the current
  `ERC_1271_GAS_LIMIT` from the factory line.
- Proposed ADR 0018 is now present on the final base. ADR 0019 imports its exact
  current/bound mint-policy identity without altering #688-owned derivation,
  manager/ledger replay, or Core semantics.

## Constraints

- Do not alter issue #688 operation identity or prepared-mint replay semantics.
- Do not alter issues #684, #685, #669, #671, or #673 governance/gas surfaces.
- Do not alter issue #670's `StreamRevenueResolver` or
  `IStreamRoyaltyResolver` ownership.
- Stop at a review-ready draft PR; do not merge or deploy.
- Keep pre-audit and not-production-ready language unchanged.

## Current Decision

The coordinator selected contract `20` as the top-level payer boundary and
prohibited implementation until a security ADR fixes the missing orchestration
seam. The first authorized slice is proposed ADR 0019. Its provisional ABI and
state-machine clauses are under coordinator and independent security review;
they must not be treated as frozen or used for implementation yet.

The reviewed call graph is now:

`contract 20 -> one typed sale-adapter callback -> contract 9 direct
settlement -> contract 20 exact funding callback -> contract 9 route/record`,
then control returns through the sale adapter to contract 20. Contract 20 has
no sale-adapter-callable settlement reentry. Contract 9 authenticates
Replaceable role-20 instances through the canonical module registry rather than
pinning or owner-allowlisting a singleton.

Remaining freeze dependencies include the final ADR-0018/#688 orchestration and
operation/execution identity and distinct revenue settlement-key binding, exact
selectors/ERC-165/module constants and commitment hashes, exact escrow credit
ABI, an accepted RSR/#669 classification for the proposed lifecycle read, and
the explicitly open multi-component-charge and custody-transfer sale gates. The
partial ADR pins payer-is-caller-only EIP-2612 and plain Permit2 convenience
paths; neither permit signature is misrepresented as independent sale
authorization for a relayer.

The provisional candidate now commits a typed `SaleLifecycleBinding` containing
the exact payment adapter, immutable sale-creation timestamp, and separate
creation-time registry revisions for the sale adapter and payment adapter. The
sale adapter, contract 20, and contract 9 receive the same binding. Each
participant compares each module's creation evidence with that module's current
canonical record and independently fails closed on missing, zero, future,
equal-deprecation-boundary, or substituted facts.

Contract 20 and contract 9 independently observe the sale adapter's immutable
record through the provisional single-selector
`IStreamSaleLifecycleBinding` read. After registry, runtime-code, and interface
authentication, the ADR proposes an exact-code available-gas, zero-value
`staticcall` with exact 36-byte calldata, bounded 128-byte returndata, canonical
decoding, and no revert-data bubbling. This is not yet an accepted
trusted-infrastructure exception: the revenue spec and issue #669 external-call
inventory must classify both consumers before ADR acceptance. No new or
overloaded GGP is proposed. Issue #684 remains a prerequisite only for actual
governed calls such as ERC-1271, asset policy, and wallet deposit.

The candidate also commits the original top-level executor, which must equal
contract 20's `msg.sender`; no path uses `tx.origin`. A separate
candidate-committed `SaleExecutionBinding` identifies one purchase without
consuming or closing the durable `(saleId, saleNonce)` sale program. The signed
branch recomputes and consumes one exact `SaleAuthorization` digest and enforces
its executor. The public branch derives authority from the immutable public sale
record, requires a zero digest and
`msg.sender == payer == candidate.executor`, and writes no
authorization-consumption fact. A non-payer relayer must use the signed-sale
branch even with a valid permanent `PaymentIntent`, because that intent is not a
full-purchase commitment. Both branches create an execution-scoped
`SETTLEMENT_IN_PROGRESS` record before their first downstream interaction and
terminally settle only that execution after the exact result and mint
completion. Repeatable fixed-price/open-edition programs remain open under their
own close rules. Final execution/purchase and revenue settlement-key derivation
remains an explicit ADR-0018/#688 prerequisite.

The imported mint-policy boundary is exact: configured and ungated paths bind
`MintBatch.expectedPolicyHash` as the current hash or one valid immediate
predecessor; the operation root and settlement records carry both the live
`currentPolicyHash` and accepted `boundPolicyHash`. Current artist
consent, modules, gate behavior, counters, caps, and increments always govern.
The predecessor supplies authorization continuity only and cannot be treated as
live economics or consent.

For `PRE_REVENUE_SINGLE_STEP`, the sale adapter calls exact manager preview
selector `0xa5651f13` before its execution record, authorization consumption,
or settlement effects. The manager observes the adapter as `msg.sender`,
validates configured gate equality or exact ungated zero/NONE/empty-nullifier
normalization, and returns the root plus the full operation-ID vector. The
adapter later compares the manager execution return byte-for-byte and any
preview, gate, race, root, length, value, or ordering mismatch rolls the whole
transaction back.

Contract 20 remains the sole protocol payer boundary and pull initiator. It
calls the token directly on allowance/EIP-2612 paths; pinned Permit2 is the
actual ERC-20 `transferFrom` caller on its SignatureTransfer branch, for which
contract 20 proves exact payer/receiver deltas. Contract 20 never creates or
expands payer-to-Permit2 approval, but the transfer consumes finite allowance
under the approved token's semantics; residual excess or supported infinite
approval remains external payer-granted authority while the Permit2 nonce
prevents signature replay. Code-bearing payer fallback to ERC-1271 is mandatory
under #684's eventual exact gas binding. The first profile contains only the two
paid-mint orders; ERC-20
`CUSTODY_SETTLEMENT_TRANSFER` is explicitly excluded and its production gate
remains open.

## Next Actions

1. Regenerate the canonical release tail from the final rebased inputs and run
   the proportional documentation plus full Windows validation ladder.
2. Push the rebased draft PR with lease and iterate CI or actionable review
   findings until the Proposed ADR slice is review-ready.
3. Wait for coordinator merge before starting a dependent slice from current
   `origin/main`.
4. After ADR 0018 is accepted, #684 lands, and the RSR/#669 lifecycle-read
   exception is accepted, replace placeholders, freeze/golden-test the exact
   ABI, reconcile approved normative specs, and only then begin contract
   implementation.
