# Explicit conservation setup for current commerce tests

`CurrentCommerceConservationFixture` is an opt-in test helper for the actual
Terminal and INSTANT commerce graph. It does not change the common current
stack's default conservation tier or other commerce fixtures.

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

Free operator distribution and configuration-only recipes do not install a
waiver. The original required-ASYNC paid control installs the same explicit
commerce setup and checks its actual floor receipt.

## Evidence and limits

The source passed a 1,315-source ABI/type check before integration. Native
execution of the combined current graph remains pending. The original Terminal
ten and INSTANT eight cases become eleven and nine with the new refusal recipes.

The helper uses explicitly named **fixture** gas configuration: 300,000 for
reads, 1,000,000 for producers and 6,000,000 for the floor call. These are not
production defaults, a 500,000-gas acceptance, or measurements of transaction
gas. Future execution must distinguish gas required for bounded-call admission
from gas actually consumed.

WAIVED paid settlement is a real ledger operation. It does not establish
MUSEUM_GRADE or MUSEUM_GRADE_LITE documentary completeness, genuine personhood
evidence, all direct-sale/supplemental paths, or deployment readiness. See
[ADR 0053](../adr/0053-durable-museum-anchors.md) for the durable declaration and
permanent floor boundary.
