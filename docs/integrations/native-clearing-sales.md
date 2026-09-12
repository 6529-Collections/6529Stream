# Native clearing sales

`StreamNativeClearingSale` implements the signed native
`DUTCH_AUCTION_CLEARING = 4` profile. Each purchase immediately mints one token,
settles a positive resting floor through the official primary-sale recorder,
funds its captured reveal fee, and retains the remaining price in buyer custody.
Later calls fix one global price and process one positive financial supplement
at a time. [ADR0030](../adr/0030-clearing-partial-settlement-and-refund-entitlements.md)
defines the partial-processing and event clarification.

## Deployment and authority

Use the explicit `DeploymentConfig`, with the current Manager, recorder, platform
signer, artist facade, reveal coordinator, role registry, governance executor and
three gas rows. The consumer pins their runtime and same-Core bindings. The
recorder must advertise both native primary and native supplemental settlement
capabilities. Deploy the new linked clearing libraries and link each artifact
using that compiler profile's link map; library addresses are deployment inputs.
No existing recorder, payment adapter, immediate native, refund or Dutch source
changes are required by this consumer.

Register the actual consumer as `NATIVE_PRIMARY_SALE_ADAPTER`, declaring
`IStreamNativeSaleBinding`. Its additional `IStreamNativeClearingSaleBinding`
capability exposes the exact stored floor/token association and the active
financial candidate commitment. Admit the consumer to its Manager phase. For
AT_MINT, separately authorize this exact adapter as an entropy requester on the
actual coordinator; a successful mock request does not establish that admission.
The deployment catalog must include `raiseGasParameter` and all three rows:

| Parameter | Purpose | Failure class |
| --- | --- | --- |
| `SALE_ERC1271_GAS_LIMIT` | Direct commercial contract signatures | 2 |
| `SALE_ARTIST_AUTHORITY_GAS_LIMIT` | Artist capability, consent and authority facts | 2 |
| `REVEAL_ATTEMPT_GAS_LIMIT` | Whole automatic reveal request | 2 |

Current factory `WALLET_DEPOSIT_GAS_LIMIT` governs each recorder deposit. The
consumer uses current governed values, with parent-gas admission before capped
calls. The inherited gas raise retains canonical executor/action authorization;
it is the governance-only exception to the consumer's shared reentrancy guard.
All ordinary mutations, including ownership, claims, rebate synchronization and
price fixing, use that guard. Pause guardian and unpause roles remain distinct.

A known canonical INCIDENT_REVOKED recorder blocks new purchase and financial
use at the same before/after-effect context checks. This closes the race between
an early refund unlock and a keeper attempting another settlement. It does not
invent an ACTIVE-only recorder admission policy: UNKNOWN and DEPRECATED retain
the existing native profile. Actual deployment still registers the intended
modules. A deprecated sale adapter serves previously configured sales while new
configuration rejects; incident sale adapters reject execution. Claims and
unconditional escape remain independent of those admission reads.

Registration stores immutable terms and a read-only primary-policy baseline; it
neither materializes a profile nor collects payment. It is not a purchase permit.
Each purchase requires the current facade's caller-bound sale consent before
commercial proofs or effects, and again after settlement, mint and fee calls.
Missing capability, malformed responses and absent REQUIRED consent reject.
The currently supported artist association is accepted state2 with active
authority status1. Future estate continuation uses the actual typed artist
capability seam; status3 is not admitted by an undocumented numeric allowance.

## Identities and purchase proofs

Canonical `saleId` encodes the sale domain, chain, consumer, literal kind4,
collection, phase and monotonically increasing sale nonce. Canonical `purchaseId`
encodes the purchase domain, chain, consumer, sale, payer and that buyer's exact
next purchase nonce, starting at1. The counter advances only with an accepted
atomic purchase and never rewinds on claim, financial settlement or unlock.
The artist's commercial nonce and the sale's execution nonce are separate lanes.

The sole EIP712 domain is `6529StreamNativeClearingSale`, version `1`; the
`eip712Domain` read exposes its current chain and consumer. The permanent
`ClearingAuthorization` commits all19 named fields in the typed interface:
sale/config, payer/executor/recipient/current artist, content and mint commitment,
purchase/execution/commercial nonces, proof deadline, concrete primary policy,
unit maximum, optional full-width override, window policy, maximum nominal
finalize-by and the common absolute escape. The Manager authorization ID is
`keccak256(abi.encode(TICKET_AUTHORIZATION_DOMAIN, fullAuthorizationDigest))`.
The original full digest also remains the Manager context hash and stored floor
evidence. No signed price field is rewritten to the eventual charge.

The current schedule price follows the existing LINEAR or STEPPED specification.
An authenticated override is a ceiling, so the purchase charges the smaller of
that ceiling and the schedule. Both the signed unit maximum and the supplied
value after the captured fee must cover that charge. The positive resting floor
is official revenue; charge minus floor stays held; every excess wei is an
immediate per-sale credit. Zero-floor configurations reject. Positive flat
schedules work and require no later zero-valued receipt.

Each freshly signed concrete primary-policy hash must match its current purchase
preview. It may differ from the immutable registration baseline. For templates,
the recorder materializes that preview once before mint callbacks and retains
those concrete rights afterward. A later payout designation affects future
execution, not the already-materialized floor. The sale saves the first accepted
artist identity, generation and binding; every later purchase must retain that
association. Fresh commercial signatures still require the actual current signer.

The public `purchaseRecord` retains the complete original tuple. New records
omit duplicate immutable values in storage: the adapter/executor, collection,
class, native/pre-revenue constants, sale nonce/lifecycle, Manager and equal
bound/current mint policy are reconstructed from the immutable sale configuration,
stable local purchase basis and consumer's immutable Manager. The original
signed primary-policy hash, concrete profile/wallet/template/assignment/entries,
full digest, operation/execution identities, beneficiary and uint256 override
remain stored verbatim. Reconstruction does not consult live providers, current
policy, deadlines or price-fixing state. A nonzero token ID plus a zero stored
adapter marks this sparse encoding; prior full records have a nonzero adapter
and return verbatim. An unknown record remains entirely zero. This is an
internal encoding change, with the same public ABI and physical storage roots.

## Fixing, supplements and permanent rebates

Sold-out fixing uses the timestamp of the last accepted purchase, including when
that buyer received a discount. Otherwise it uses the immutable configured close
or an earlier owner-recorded close. A keeper's later call time never lowers the
global price. Fixing is permissionless, bounded independently of buyer count,
and separate from money movement. `DutchClearingFinalized.supplementalRevenue`
is the exact scheduled total, not a claim that those funds have been settled.

For paid price `p`, positive floor `f` and authenticated buyer uniform price
`u = min(globalClearing, override)` (or globalClearing without an override),
the permanent rebate is `p-u`; the pending financial amount is `u-f`.
`refundableBalance(saleId,buyer)` includes that rebate immediately after fixing.
Permissionless `synchronizeRebate` emits `DutchRebateCredited` once per newly
announced entitlement, and claiming also synchronizes it. Event synchronization
never gates the balance or claim. Newly unlocked pending supplements are
identified by `DutchClearingRefundUnlocked`, not relabeled original rebates.

`settlePurchaseSupplement(purchaseId)` handles one positive amount. It retains
the original floor receipt, signed proof, consumed operation root, operation ID
and token association. The actual retained token determines current primary
rights, including a lawful current COLLECTION_ARTIST designation. The recorder
requires completed MINTED2 or retained BURNED3 lifecycle, checks the consumer's
exact active candidate, and independently consumes purchase, original-floor and
official-execution replay lanes. The consumer atomically stored the token to
operation association; Core mapping and used-root facts alone do not prove it.

Current token-aware resolver precedence and artist consent restrictions remain
in force. Unsupported artist-bound token/default scopes reject; this consumer
does not bypass the provider pending a later consent expansion. The financial
leg does not remint, charge a second fee, recheck the old commercial signature,
or depend on an already-completed mint phase remaining open. It does require the
saved association, current supported authority and current sale consent before
and after funding. An ordinary address rotation within that association does
not invalidate the proof already consumed at purchase.

Each exact512-byte result is checked field by field and against the recorder's
stored receipt. A successful receipt updates the purchase and aggregate
settled amounts; a failed call reverts the entire financial frame, including
consumer liabilities, active commitment, recorder replay and escrow credit.
Only a failed wallet CALL can use the existing exact escrow fallback. A prior
successful receipt returns its stored result on repeat, regardless of later
authority or time changes. Zero financial amounts have no invented receipt.

## Deadlines, refunds and accounting

All purchases cover one immutable sale-wide absolute escape and configured
nominal finalization horizon. The effective financial deadline is
`min(reference + finalizationWindow + observedPauseUnionToll, absoluteEscape)`.
The historical clock excludes pauses before the exact sold-out/close reference,
even when no transaction occurred at configured close. Global transitions never
iterate sales; queries binary-search transition history. Terminal clock values
are frozen. Pausing after a deadline has expired cannot revive it.

Unpaused finalization is allowed through equality. At absolute equality while
paused, refund unlock is available. Strictly after absolute escape it requires
no external dependency. Earlier typed unlocks are limited to the same saved
attribution entering DISPUTED4/REVOKED5 or referenced canonical modules entering
INCIDENT_REVOKED. Identity authority-contest status4 is a different fact. Missing
facts and transient call failures are not guessed to be permanent unlock causes.

Global unlock is terminal for unsettled financial legs. It preserves all paid
floors and completed supplements. The buyer's post-unlock entitlement is
`paidSum - count*floor - settledSupplement`, less prior entitlement claims, plus
unclaimed excess. Before fixing, only excess is claimable; after fixing the
rebate formula is `paidSum - uniformSum`. Two ceiling aggregates, one per buyer
and one per sale, keep exact sums without enumerating buyers. New trees use
compressed heap-prefix branches; each accepted purchase updates both atomically.
Old nonempty fixed-depth trees retain their exact original encoding and append
behavior. An empty new tree needs a leaf and root pointer; distinct ceilings add
one leaf and one branch, while duplicate ceilings reuse existing nodes. Queries
and insertion can still encounter96 branch decisions in a worst-case tree. Counts fit uint64,
prices fit uint96, and aggregate sums are below2^160; checked count64/sum192
packing never truncates the original uint256 signed override. Indexing
`min(rawOverride,startPrice)` preserves every valid clearing price exactly.

`claimRefund(saleId,to)` debits only that buyer's selected sale and aggregate
liability. A rejected recipient restores the full claim. Claims remain available
through pause, close, provider failure, terminal unlock and ownership changes.
Unsolicited surplus is excluded from all entitlements. Neither price fixing nor
partial claims permit that surplus to become sale proceeds.

## Evidence and remaining integration

Focused tests use real recorder, factory, wallets, revenue escrow, ModuleRegistry,
RoleRegistry and official Safe contracts. Core, Manager, artist state, fee endpoint
and governance action context are explicit domain doubles. Native wallet failure
and malformed recorder results use labeled fault injection alongside ordinary
real-wallet controls. AT_MINT admitted request reverts/OOG/malformed results keep
the purchase and fee; insufficient parent admission reverts the entire purchase.
Actual current Core/artist/coordinator composition and requester admission remain
the integrator's separate evidence.

The paired-tree cost must be measured in the complete purchase, not inferred
from a single-tree harness. Planning caps and partially cooled measurements do
not establish fully cold worst-case genesis values. This profile leaves public
or Merkle authorization, universal ERC20 clearing, generalized quantity/content,
delegated claims, and governed surplus/export tooling to their explicit remaining
delivery slices. It does not alter the creation-time retained rights of existing
V2 auctions.

The accepted functional build measured **6,843,542 gas** for the first purchase
with partially cooled consumer/recorder/wallet/Manager and two fresh aggregate
paths, and **2,084,997 gas** for a warm repeat. The earlier pre-INCIDENT-guard
measurement was 6,802,390 / 2,064,345. Compressed aggregates alone reduced the
same qualified measurement to **2,567,071 / 1,967,624**; compact local purchase
records further reduced it to **2,271,876 / 1,672,429** in the focused six-case
composition. These are measurements of distinct retained source captures, not
all-cold rehearsal values or a claim that every current-stack path is cheaper.

All remain above the normative **500,000-gas** single paid
`PRE_REVENUE_SINGLE_STEP` ceiling in
[MPA-GAS-BUDGET](../mint-policy-and-accounting.md#gas-budget-artifact).
This is a deployment blocker. Functional acceptance does not waive the ceiling.
A separate cached trace of the original current-stack composition measured a
first successful 2-of-3 Safe transaction frame of8,805,429, including the
consumer8,755,856, recorder553,549 and actual Manager798,823. The latter includes
Core469,659; those nested costs must not be added again. The second Manager frame
still used602,423. That trace has prior test activity and is not an all-cold
rehearsal. It demonstrates that clearing-only storage changes cannot by
themselves satisfy the ceiling while those shared paths remain unchanged.
Shared mint, authorization and receipt cost work remains open for integration;
this implementation neither changes the ceiling nor calls those costs accepted.
