# Native refund-window sales

`StreamNativeRefundWindowSale` holds a signed one-token purchase until the payer
refunds it or anyone finalizes the mint. It uses the shared primary-sale recorder
and the actual split factory, resolver and revenue escrow. It is a separate
authorization schema from the immediate native fixed and price-program APIs.
[ADR 0027](../adr/0027-deferred-sale-window-envelope.md) records the timestamp
and pause reconciliation with SSA-REFUND, SSA-AUTH, SSA-ENVELOPE and SSA-PAUSE.

## Register and purchase

Deploy with one `DeploymentConfig` containing the Manager, recorder, platform
signer, artist facade, entropy coordinator, RoleRegistry, governance authority
and three explicit gas-parameter rows. The recorder, resolver, factory, Manager,
artist facade, entropy coordinator and registry must share the actual Core
identity; their runtime identities are pinned. The authority must equal the
factory's authority and own the RoleRegistry. Registration belongs to the
adapter owner; pause and unpause require their respective RoleRegistry roles.

The row order and failure classes are:

| Name | Failure class | Domain-test initial value / floor |
| --- | --- | --- |
| `SALE_ERC1271_GAS_LIMIT` | fail-closed precheck (2) | 400,000 / 350,000 |
| `SALE_ARTIST_AUTHORITY_GAS_LIMIT` | fail-closed precheck (2) | 200,000 / 50,000 |
| `REVEAL_ATTEMPT_GAS_LIMIT` | fail-closed precheck (2) | 200,000 / 50,000 |

These values are explicit test planning inputs, not fully cold protocol sizing.
Deployments must supply their reviewed values and admit `raiseGasParameter` in
the governance catalog. No omitted-row or immutable-cap fallback exists.

Register the adapter in the canonical ModuleRegistry with
`keccak256("NATIVE_REFUND_WINDOW_SALE_ADAPTER")` and the declared
`IStreamDeferredNativeSaleBinding` interface. The recorder independently admits
that role and the stored sale lifecycle. Registering a sale stores its immutable
configuration and exposes exact `saleConsentFacts(saleId)`; it grants no artist
consent. The current artist facade's canonical sale-consent check runs before
purchase effects and finalization, and again after callbacks. A REQUIRED
election needs the exact registered configuration's op16 consent.

Both the facade's declared sale capability and its void consent method receive
the current `SALE_ARTIST_AUTHORITY_GAS_LIMIT`, with parent-gas admission before
each call and exact 32-byte true / empty-success results. Missing capability or
malformed results fail closed. This consumer enforces its own declared cap.

Sale identity uses permanent catalog `REFUND_WINDOW = 7`. Registration captures
the actual read-only primary-policy baseline, stores it in the sale record,
includes it in `configHash` and emits canonical `SaleConfigured` plus detailed
configuration evidence. Gas retuning cannot change this identity. The baseline
does not require a template profile to be registered or deployed. It remains
distinct from each purchase's original policy and current finalization policy.

Only `primaryPolicyMode = 1` (`ALLOW_CURRENT`) is supported here. Strict mode
rejects explicitly. Refund windows range from 3,600 to 2,592,000 seconds and
finalization windows from 86,400 to 7,776,000 seconds. Registration requires a
Manager phase whose finite end, if present, contains the sale's last purchase
and both windows.
The configured price is positive. Zero/free purchases use the immediate price
program, not a refundable official-revenue transcript.

The `RefundPurchaseAuthorization` EIP-712 domain is
`6529StreamNativeRefundWindowSale`, version `1`, with the actual chain and
adapter. The ERC5267 `eip712Domain()` view exposes that sole domain with fields `0x0f`,
no salt and no extensions; its verifying contract is the consumer, including
when read through a Safe. Sign the entire interface-defined structure, including payer,
recipient, price, token data hash, mint commitment, commercial nonce,
`purchaseNonce`, window-policy hash, both deadline bounds and the original
primary-policy evidence. Platform and artist authorization are verified and
consumed once at purchase. The composed Identity authority status must be ACTIVE
(1); an attribution read returning the old address during an authority contest
does not make it operative, including under NONE sale-consent scope.
Contract signers use the governed ERC-1271 path;
Safe owners must sign the actual Safe message representation.

Read `nextPurchaseNonce(saleId, payer)` before signing: it starts at 1 separately
for each sale and payer. Purchase requires exactly that value and advances it
only on success. Gaps and out-of-order numeric nonces reject; refunds, unlocks
and finalization never rewind the counter. The independent artist-scoped
commercial nonce still cannot be reused with a new numeric purchase nonce.

Send the exact price plus a reveal-fee allowance. The declared live reveal fee
is captured as a refundable liability and excess allowance becomes payer pull
credit. A missing or undeclared policy fails; a declared zero fee is valid.
Purchase does not mint, materialize a profile, deposit to a split wallet or
create official revenue. Forced ETH surplus remains outside buyer liabilities.

## Deadlines, pauses and exits

At purchase, the nominal refund deadline is inclusion time plus the refund
window, and nominal finalization deadline adds the finalization window. The
nominal finalization deadline must not exceed either signed
`maximumNominalFinalizeBy` or `absoluteEscapeDeadline`. Configuration and signed
bounds are immutable for that purchase.

Adapter-wide and sale-local pauses add the union of their intervals, counting
overlap once. Each purchase records its own baseline; history before purchase
does not extend its windows. Live views and `synchronizePurchaseWindow` derive
the same values. Terminal operations freeze the observed toll. Starting a pause
after the finalization window has elapsed cannot revive it.

| Boundary | Executable outcome |
| --- | --- |
| Before effective refund deadline | Payer can convert the deposit to pull credit. |
| At refund deadline, unpaused | Refund closes and finalization opens. |
| Through effective finalization deadline, unpaused | Anyone may finalize. |
| At absolute escape, paused | Anyone may unlock the payer's refund. |
| At absolute escape, unpaused | Finalization remains available through equality. |
| Strictly after absolute escape | Refund unlock is unconditional. |

`unlockRefund(purchaseId, 0)` uses the time exit before any external dependency
read. Earlier typed reasons are: phase ended strictly after its end (1), proven
lifetime or supported static-counter exhaustion (2), original policy no longer
current or within inclusive previous-policy grace (3), the purchase's exact
artist identity/generation/binding in attribution state DISPUTED or REVOKED (4),
or canonical INCIDENT status on the adapter, recorder or purchase-captured gate
(5). Dynamic counters and nonzero-gate AUTHORIZER subjects are excluded from the
static-exhaustion inference. Unknown, malformed or failed reads are not proof.
Identity-authority contest is not attribution dispute, and a different binding
generation cannot unlock an older purchase. These are current-state predicates;
they do not promise future governance can never change a phase or cap.

Refund and unlock credit the payer with the full price and saved fee against
the originating sale. `refundableBalance(saleId, payer)` reports that native
credit; `refundCredit(payer)` is only its aggregate summary across sales. The
asset is always native ETH, represented as `address(0)` in owed-funds identity.
Purchase excess and unused saved fees likewise belong to their originating
sale. `claimRefund(saleId, recipient)` claims that sale's entire credit and
emits its exact sale, payer, recipient and amount; it leaves other sale credits
and pending deposits intact. A rejecting recipient restores the sale credit,
aggregate credit and total liability for retry. Refund, withdrawal and time escape need no current provider,
artist or registry approval. Repeating the same refunded/unlocked outcome does
not duplicate credit. Finalized purchases return their stored finalization
result; other terminal outcomes reject finalization explicitly.

## Finalization and reveal fees

Finalization retains the original payer, recipient, signed digest and purchased
artist association. The same accepted artist identity, binding generation and
binding hash and ACTIVE Identity authority status must exist before effects and after settlement, NFT and reveal
callbacks. A lawful authority-address rotation within that association is
allowed; the original signature is not revalidated after its deadline. This
checks pending finalization. Repeating an already finalized purchase still
returns its stored result without consulting current authority. Identity status
is separate from module lifecycle/grandfathering and from attribution dispute;
ordinary refunds, pull claims and unconditional time escape remain available
during an authority contest.

`ALLOW_CURRENT` derives current primary assignment and mint-policy facts. An
explicit COLLECTION_ARTIST template observes the current explicit payout once
at finalization. The concrete profile and wallet are then retained through all
callbacks. A later payout revision affects the next execution, not that already
materialized wallet. The recorder consumes both its independent
`(adapter, purchaseId)` key and canonical execution key before materialization
or funding. The adapter separately enforces its terminal purchase state.

Exactly the purchase price enters recorder 9's native accounting and split
wallet or revenue-escrow fallback. Manager preview and execution must agree on
the full-digest authorization ID, operation root and single operation ID. The
reveal fee is excluded from official revenue: finalization forwards
`min(savedFee, liveFee)` to the pinned coordinator's collection escrow and
credits the remainder to the payer. Fee escrow funding must return empty data
and increase the actual escrow by exactly that amount. A failed mint or funding
check rolls back status, liabilities, both recorder keys and all value movement.

OWNER_WINDOW leaves request timing to its declared workflow. AT_MINT makes one
bounded `requestEntropy(tokenId)` attempt after funding and mint. Its cap is
captured and preflighted before finalization effects, with EIP-150 admission
checked again at the call. An underfunded parent transaction reverts the entire
finalization. Once admitted, a reverting, gas-exhausting or malformed request
preserves mint, funded fee escrow and terminal result, and emits bounded failure
evidence. That failure alone does not authorize a refund.

Actual AT_MINT integration must separately admit this adapter as an entropy
requester, or establish the canonical public/role route. A successful domain
mock request does not prove that admission. The current Coordinator's requester
policy, real provider request and later outage/fallback behavior require the
integration owner's actual governance and current-stack tests.

## Linking and validation boundary

Use the compiler's exact link maps for the recorder and refund consumer. The
new recorder rights/emission libraries preserve its prior immediate interfaces
and event layouts; the deferred purchase lane is appended storage. Refund book,
support, unlock and typed settlement helpers execute in the consumer's context.
Compiler-linked mutable library calls reject direct CALL; arbitrary external
DELEGATECALL into a library's own caller context grants no consumer authority.

Focused evidence uses the actual split factory, wallets, policy, ModuleRegistry,
RoleRegistry, escrow, recorder and official Safe contracts. Core, Manager,
artist, fee coordinator and governance execution-context fixtures remain
explicit domain boundaries. It is not an actual-current deployment proof or
fully cold gas gate. The integration owner must wire the new module, three gas
rows, pause roles, sale consent, Manager executor/phase, entropy requester and
compiler links before claiming current-stack support. Other public sale,
Dutch/private and broader deferred profiles remain separate implementation work.
Delegate-triggered `claimRefundFor`, governed surplus recovery and the canonical
owed-funds export tooling are separate follow-ups; no current caller may sweep
surplus or claim another payer's credit through this consumer.
