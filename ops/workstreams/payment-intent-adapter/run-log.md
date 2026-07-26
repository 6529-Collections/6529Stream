# Run Log

## 2026-07-24

- Created the unbudgeted long-running goal for issue #664.
- Verified the isolated worktree was clean and detached at current
  `origin/main`; created `codex/payment-intent-adapter`.
- Read issue #664 and the coordinator-owned issue #688.
- Loaded the repository operating guide and the autonomous-manager, PR,
  publish, review-comment, and CI workflows.
- Read the relevant roadmap, execution backlog, maturity, release-readiness,
  tooling, payment accounting, revenue, PaymentIntent, signature, deployment
  inventory, and sale-authorization surfaces.
- Recorded the coordinator restriction against Manager/Ledger/Core operation
  identity changes and the required pre-artifact rebase.
- Identified an unresolved accepted-architecture seam between direct
  payer-is-caller observation, downstream sale-adapter composition, the current
  pull-performing `StreamPrimarySaleSettlement`, the absent revenue escrow, and
  the issue #684 gas-parameter host dependency.
- Sent the seam question to the integration coordinator before changing the
  protocol ABI.
- Coordinator selected contract `20` as the top-level payer boundary and
  authorized a sequential security ADR/spec-lock slice before implementation.
- Sent the proposed candidate ABI, fixed sale callback, contract-`9` funding
  callback, rollback state machine, GGP dependency, and release overlap list to
  the coordinator and independent security review.
- Added proposed ADR 0019 and its ADR index row as a concrete provisional
  source milestone. Exact ABI clauses remain explicitly unfrozen; generated and
  shared release artifacts remain untouched pending review.
- Renumbered the draft from ADR 0018 before further links were added because
  issue #688 owns ADR 0018.
- Applied coordinator/security corrections to remove the legacy contract-9
  ERC-20 selector, eliminate mutual/singleton contract-9/20 pinning, preserve
  ACTIVE/DEPRECATED/INCIDENT_REVOKED registry semantics, split paid-mint
  ordering, lock before external signature verification, consume signed intent
  before the first sale callback, spell out the verifier/revocation/events
  surface, and add typed EIP-2612/Permit2 paths.
- Replaced the redundant sale-adapter-to-contract-20 settlement reentry with the
  reviewed direct topology: the sale adapter calls contract 9; contract 9 calls
  only the live committed contract 20 for exact funding.
- Added independent active-asset checks, exact per-hop and terminal balance
  conservation, escrow backing/solvency, wrong-code wallet rejection, explicit
  freeze prerequisites, and honest exclusion of refund-window, Dutch-clearing
  overage, and reveal-fee multi-component charges.
- Corrected the permit model: plain EIP-2612 and Permit2 signatures do not bind
  sale or orchestration context, so both typed convenience entries now require
  top-level `msg.sender == payer` and execute the permit only during funding.
  No relayed plain-permit path or sale-bound Permit2 witness path is claimed.
- Pinned the deprecated-sale proof inventory to immutable sale creation time,
  payment-adapter address, and registry revision checked against the current
  module record's deprecation timestamp/revision. Corrected rollout so a
  Proposed review PR may precede #688, but acceptance/freeze and implementation
  may not.
- Closed the lifecycle observability gap by adding a typed
  `SaleLifecycleBinding` to the provisional candidate and its commitment
  preimage. The immutable sale record, contract-9 request, and active-operation
  view expose the same binding; ACTIVE and DEPRECATED checks share it, while
  DEPRECATED additionally requires strict pre-transition timestamp and
  registry-revision inequalities.
- Reran the focused documentation gates after the lifecycle correction:
  `test_markdown_links.py` passed 16/16 tests, `check_markdown_links.py`
  reported current links, and `codex-diff-check` reported no whitespace errors.
- Sent the exact patched line map and validation results to the coordinator and
  kept the draft Proposed, partial, uncommitted, unpushed, and unpublished
  pending approval.
- Closed the remaining independent-observation gap with the provisional
  `IStreamSaleLifecycleBinding` read (`0x2b022c4e`). Contract 20 reads after
  registry/code/interface authentication and before the sale callback; contract
  9 repeats before settlement-key consumption; the sale adapter checks its own
  storage. A later independent review replaced the initial capped-call shape
  with an exact 128-byte available-gas proposal, then required an explicit
  revenue-spec/#669 normative-exception review before acceptance.
- After rebasing onto the merged #687 closed 22-GGP inventory gate, removed the
  implication that #664 should add a governed parameter. A later independent
  review clarified that no existing row has the lifecycle-read semantics, so
  ADR 0019 now uses no GGP for that authenticated sale-adapter read. Issue #684
  remains a prerequisite only for actual governed calls in the final graph.
- Committed the focused partial Proposed ADR/index/manager-context slice and
  rebased it cleanly onto #687 at
  `06f36150c4b5be05851f8081c520e98a6703a0c3`. No generated release artifact or
  #684/#688/#670-owned source was changed.
- Post-rebase validation passed: 16 Markdown-link tests, the live Markdown-link
  checker, the no-release-impact changelog gate, 32 governed-parameter inventory
  tests and its ordinary 22-GGP/3-GTP/50-binding planning check, 19 governed
  identifier tests and its exact-catalog check, and the scoped whitespace gate.
- Recorded issue #670's ownership of `StreamRevenueResolver` and
  `IStreamRoyaltyResolver`; #664 will consume or coordinate that interface
  rather than changing it opportunistically.
- Applied the next seven independent-review corrections without publishing:
  split lifecycle evidence into sale-adapter and payment-adapter creation
  revisions with exact 128-byte observation; corrected Permit2 so contract 20
  is the sole protocol pull initiator while pinned Permit2 performs its branch's
  token `transferFrom`; made the code-bearing-payer ERC-1271 fallback mandatory;
  added sale-owned authorization/replay consumption and
  `SETTLEMENT_IN_PROGRESS -> SETTLED` rollback semantics; replaced the
  superseded lifecycle-read GGP with authenticated available-gas trusted
  infrastructure; excluded `CUSTODY_SETTLEMENT_TRANSFER` from the first
  paid-mint profile while leaving its gate open; and bound the original
  top-level executor through the candidate, callback, result, event, and
  negative-test surfaces without `tx.origin`.
- Applied the next three NO-GO corrections without committing or publishing:
  replaced durable `(saleId, saleNonce)` consumption and sale-program closure
  with a candidate-committed unique execution binding and separate execution
  record; split signed `SaleAuthorization` and immutable public-sale-record
  authority so repeatable fixed-price/open-edition programs remain open;
  corrected Permit2 allowance accounting so exact/excess/infinite transitions
  follow the approved token semantics while contract 20 never creates or
  expands approval; and relabeled the lifecycle available-gas read as a
  proposed normative exception requiring exact RSR and #669 external-call
  inventory reconciliation before ADR acceptance.
- Applied the next two narrow NO-GO corrections without committing or
  publishing: restricted `PUBLIC_SALE_RECORD` to top-level
  `msg.sender == payer == executor`, required every non-payer relayed
  `PaymentIntent` execution to use `SIGNED_SALE_AUTHORIZATION` absent a future
  full-purchase payer commitment, and qualified the permit prohibition so exact
  EIP-2612-created allowance and exact Permit2 signed/requested transfer amounts
  are mandatory without falsely requiring the payer's preexisting
  payer-to-Permit2 approval itself to equal the transfer amount.
- Rebased the review branch onto `f7100716be652b3dc4aa2eed1ef7d109b3216e7a`
  after proposed ADR 0018 and the issue #669 artist-authority lane merged. The
  only source conflict was the ADR index; it was resolved additively by retaining
  both ADR rows.
- Imported ADR 0018's exact policy-identity boundary into ADR 0019: both paid
  orders carry the nonzero operation root; configured and ungated paths accept
  current or one valid immediate predecessor as `boundPolicyHash`; current
  consent/modules/gate/counters/caps remain authoritative; and candidate,
  execution/replay, result, and event evidence carries the root plus
  current/bound identities without treating predecessor policy as live
  economics or consent.
- Independent incremental review found that the first import omitted the exact
  manager-owned single-step preview ABI/caller/order and configured/ungated gate
  normalization. Corrected ADR 0019 to pin selector `0xa5651f13`, exact
  `(operationRoot, operationIds)` return, adapter-as-`msg.sender` identity,
  configured authorization-ID/authorizer/address-kind equality, ungated
  zero/NONE/zero/zero plus empty-nullifier normalization, preview-before-effect
  ordering, and whole-transaction rollback on root or full-vector mismatch.
