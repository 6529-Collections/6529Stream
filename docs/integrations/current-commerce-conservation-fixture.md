# Explicit conservation setup for current commerce tests

`CurrentCommerceConservationFixture` is an opt-in test helper for actual current
commerce graphs. It does not change the common current stack's default
conservation tier. Terminal, INSTANT, native fixed settlement, clearing, Dutch,
paid burn/mint and dynamic royalty commerce fixtures explicitly opt in.
Refund-window recipes opt in only when they finalize paid settlement.
Universal ERC20, consented native commerce and Artist royalty-snapshot auction
recipes also opt in through their genuine current graph.

The helper deploys the actual `StreamConservationFloor`, schedules its original
Core binding through class-1 delayed governance, and executes that binding with
the actual threshold Safe. It separately grants that Safe collection-1,
class-7 `CONSERVATION` authority through the actual Metadata facade, then makes
an explicit `CONSERVATION_WAIVED` declaration before the first completed mint.
No global class-8 grant, substitute metadata writer, or fabricated governance
context authorizes these operations.

The two new recipes retain one exact signed paid transaction through:

1. An unbound-floor refusal.
2. A bound but undeclared-floor refusal, which prospectively requires LITE
   evidence and cannot find a native evidence source.
3. Success after the explicit declaration.

The actions are scheduled and their delay elapses before the paid transaction
is signed. Binding and declaring therefore do not require replacing an expired
payment signature. The same payer Safe nonce and payload reach successful
settlement. A subsequent fresh-Safe-nonce replay reaches the original sale's
authorization refusal.

Each refusal checks its original production error and the Safe failure, plus
Core mint state, commercial authorization, counters, payment balances,
liabilities, entropy and absence of settlement/floor receipts. Existing late
recipient-callback failures also assert recorder and floor rollback. Successful
paid paths require the actual ledger's first-sale and settlement receipt, with
the original recorder/runtime, collection, token and explicit tier.

Original fixed-price and deferred native settlement pay before minting. Their
floor receipt therefore retains the candidate's token ID zero, while each
recipe separately checks that the completed mint produced token one. The
receipt assertion accepts an explicit expected token ID; its current native
default is zero. A floor receipt must not be rewritten to claim a token that
was allocated only later in the same transaction.
Prepared native auctions instead assert their actual preallocated token ID one
in the floor receipt and separately verify completed custody.

Free operator distribution, configuration-only, zero-price-only native sale and
free burn recipes do not install a waiver. Free burn surplus recovery installs
its genuine Safe governor but leaves the floor unbound and the tier undeclared.
The original required-ASYNC paid control installs the same explicit commerce
setup and checks its actual floor receipt.

Paid burn setup declares before seeding the first free source tokens. Native
fixed settlement uses a separate threshold Safe governor while preserving the
payer's NFT and refund ownership. Its surplus subclass inherits the same real
governance helpers and retains that governor. Clearing and Dutch create their
dated sale schedules after all delayed setup governance; Dutch observes the
new timestamp through a self-only external call before registering the original
price schedule and transferring ownership. Derived surplus policies retain the
parent's floor-binding and metadata-writer policies.

Dynamic royalty commerce descendants share this explicit setup, including
curated auction/purchase, custody rights, native/ERC20 offers and successor
royalty continuity. Typed native English-auction and direct-sale acceptance
remain separate migrations.

The refund-window refusal recipe prepares real governance before taking the
deposit. Unbound and bound-but-undeclared finalizations retain the original
deposit record, consumed purchase authorization, buyer liabilities, Safe nonce
and zero mint/revenue/entropy effects. It checks the adapter's original
`DeferredSettlementFailed` wrapper; that wrapper deliberately hides the inner
recorder error. The exact signed keeper payload succeeds after explicit
declaration, and a later idempotent finalization preserves the same receipt.
Deposit/refund-only, delegated refund, credit export and surplus recipes retain
the unbound default.

Universal ERC20 setup runs after each recipe's final graph deployment and before
its payment signatures. Consented native commerce schedules its original
post-genesis governance requests through the newly installed threshold Safe;
initial deployment admission retains its original governance actor. Artist
royalty-snapshot auctions use their existing Safe governor. Original exact
payment, escrow failure/retry, Artist consent and immutable royalty evidence
assertions remain in these nine recipes.

Artist delegated-consent native sales also opt in before buyer signatures. A
separate threshold Safe performs the delayed floor binding and narrow Metadata
grant, preserving the principal, delegate and buyer Safe nonces. Exhausted,
revoked and expired grants retain their already-recorded policy/sale consents;
the missing-sale-consent case retries the identical signed buyer transaction.
Successful purchases assert the original payment-before-mint token-zero floor
receipt. Native execution of these four recipes remains pending.

## Typed curated-purchase fixture

The four `StreamCurrentCuratedPurchaseSettlementTest` recipes separately opt in
through `NativeCuratedCommerceConservationFixture`. That helper retains the
existing typed governance, Artist and entropy boundaries and explicitly adds a
selected Metadata-writer boundary. It binds the actual floor to the actual Core
and declares WAIVED before any mint. It does not establish actual Metadata
class-7/8 authorization or Artist onboarding.

Successful prepared purchases check their original token IDs in actual floor
receipts. Duplicate content attempts preserve the prior receipt, and late
delivery/authority failures roll back the first-sale receipt before the identical
signed Safe transaction retries. The shared native-English fixture and the
separate conservation acceptance suite retain their previous setup. Native
execution and gas acceptance remain pending.

## Evidence and limits

The Terminal/INSTANT source passed a 1,315-source ABI/type check before
integration. The later commerce migration passed a 1,463-source ABI/type check,
including native surplus/refund/credit consumers and all dynamic royalty
descendants. Independent source review retained all 27 existing test methods in
the five changed test files. These are compilation and source-review results;
native execution of the combined current graph remains pending. The original
Terminal ten and INSTANT eight cases become eleven and nine with the new
refusal recipes.

The refund-window extension and corrected payment-before-mint receipt oracle
passed a 1,471-source ABI/type check including Terminal, INSTANT and Safe
consumers. Refund-window retains its four original cases and adds the deferred
refusal/retry case. Native execution of this extension also remains pending.
The universal and prepared-auction extension passed a 1,476-source ABI/type
check covering these nine additional recipes and the prior migrated consumers;
its native execution remains pending.

The helper uses explicitly named **fixture** gas configuration: 300,000 for
reads, 1,000,000 for producers and 2,000,000 for the floor call. These are not
production defaults, a 500,000-gas acceptance, or measurements of transaction
gas. Future execution must distinguish gas required for bounded-call admission
from gas actually consumed.

WAIVED paid settlement is a real ledger operation. It does not establish
MUSEUM_GRADE or MUSEUM_GRADE_LITE documentary completeness, genuine personhood
evidence, all direct-sale/supplemental paths, or deployment readiness. See
[ADR 0053](../adr/0053-durable-museum-anchors.md) for the durable declaration and
permanent floor boundary.

## Compatible initial WAIVED call reservations

The fresh WAIVED fixture uses a two-million floor-call genesis and floor, inside
Manager's unchanged four-million prepared callback. Both opt-in helper families
check the actual Manager parameter and that the floor wrapper's EIP-150 reserve
plus103,300 overhead is below that callback ceiling. The stateful helper inherits
the same configuration. This is a necessary composition check, not a proof that
all callback work fits. Actual prepared-auction execution is still required.

The earlier frozen six-million fixture failed before calling the ledger because
its required6,198,538 admission reserve cannot fit inside a four-million callback.
Its five passing/one failing result remains valid for that source. A later initial
configuration cannot lower or relabel that deployed raise-only parameter.
Measured mixed/warm original floor calls cost547,610 inline and172,746 following
optional preparation; these exclude other transaction work and are not cold
500,000-gas acceptance. This WAIVED setup is not a general Artist/LITE/MUSEUM
configuration or a reason to skip any original ledger work.
