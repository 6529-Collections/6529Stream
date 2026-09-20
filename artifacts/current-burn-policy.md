# Current Burn policy acceptance source

Base: `4fa32ae1c9206b05be848c7553c6492f516a7bfe`.
Branch: `codex/current-burn-finality`.

## Scope and actual components

The dedicated [seven-case host](../test/current/StreamCurrentBurnPolicy.t.sol)
adds acceptance source for Burn policy and rollback behavior. It creates source
collection 2 through the real delayed Executor, onboards the existing Artist
identity with distinct collection records, and seeds the source through the actual
Manager. Target collection 1 remains independent. The host uses current Core,
Manager, Ledger, Artist, native sale, settlement, revenue, registry and governance
components. Artist, buyer and governor use distinct official 2-of-2 Safes. The
inherited external entropy service remains a test boundary.

The recorder, native adapter and gate are genuinely admitted in the module
registry. Paid cases enable the actual governed WAIVED conservation floor; that
waiver does not replace recorder admission or establish documentary floor coverage.
The shared fixture, original Burn host and production contracts are unchanged.

## Authored cases

1. A CLOSED source collection with no burn block still supplies a free mint into
   its independently ACTIVE target.
2. A real governed source burn block rejects free Burn execution without residue.
3. The same block rejects native paid execution without settlement or credit.
4. A PAUSED target rejects the actual Core mint after native settlement; all
   effects roll back, and the identical Safe envelope succeeds after resume.
5. A CLOSED target repeatedly rejects paid minting and restores the source. The
   holder can subsequently burn that source independently; there is no reopen.
6. A paused free Burn phase restores the burned source and accepts the original
   signed Safe transaction after the actual Manager phase resumes.
7. The native phase-pause equivalent reaches settlement and target mint only on
   the successful retry.

Counted call expectations are installed once for each complete test, including
diagnostic attempts, threshold Safe attempts, successful retry and independent
owner burn. Late target tests require the actual 1,000-wei recorder call and full
Core mint calldata. Direct buyer-address calls identify the exact downstream
error; separate real signed Safe calls assert GS013 and unchanged Safe nonce.

Rollback equality covers source identity/data/ownership/approval, collection and
global allocation counts, Manager nonce and counters, attempted authorization and
burn nullifier, the seed operation and authorization, Safe and product balances,
revenue and escrow totals, refund liabilities, sale authorization/execution state,
reveal escrow and the conservation first-sale receipt. Success checks canonical
Burn events, actual operation-root consumption, target identity, one settlement,
original payer credit and Safe replay refusal. The successful root is read from
the actual event; no pre-burn operation-root preview is claimed.

Self-only external setup calls separate governance clock advances from new
signature and deadline reads. Core status and burn-block actions use independently
constructed original transition commitments. No finality state is fabricated.

## Remaining scoped-finality acceptance

The original NativeFinalityAssembly fixture and its provider are COLLECTION-only.
A complete actual scoped Burn ceremony still requires the MultiScope provider
with ProfileDiscovery, genuine STATIC selection/content/output records, scoped
snapshot and reference publications, render inventory and archive coverage, and
the Artist content-root/sanction records before class-2 finalization. It must keep
the collection mint path active and its burn path unblocked. Typed scoped-provider
tests and this host do not establish that joined acceptance result.

## Validation and handoff

Source review and ABI-only compilation are tracked separately from runtime.
The integrator and Testing own combined native code generation, current graph
preparation, execution, deployment fit, gas, fuzz/invariants and release evidence.
No native build or runtime execution is claimed for this seven-case batch.
The held ERC20 Burn native-reveal-fee extension remains excluded.

Independent source review found and resolved fixture call-count, recorder
admission and fresh-clock setup issues. Final test SHA256:
`9b712118c104720163dfd41c55eb840e571392199122d13490a3bfa9f71dce51`.

Final Solidity 0.8.19 ABI-only capture: 1,472 sources, zero errors, under
`artifacts/art27-gap3/current-burn-policy-v4`.
Input SHA256:
`58601907b4248e1ce56fcac54fc330c7d3fc78b7e4a1e77eaffa46446add33a7`.
Output SHA256:
`59cab3274238c6587dbc269a9e561390e2640a929ef702b0c6f22e86a863f328`.
Scoped Solidity formatting, 17 Markdown-checker tests, link/changelog checks and
Windows-aware whitespace checks pass. These checks do not generate or execute
native bytecode; the complete seven-case runtime result remains pending.
