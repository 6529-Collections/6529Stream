# Entropy modes in sale and distribution completion

The shared `StreamImmediateSaleReveal` library and the Dutch/clearing and
refund-window helpers support the explicit collection policy in
[the entropy policy interface](explicit-entropy-collection-policy.md).
Existing distributions and zero-native-fee ERC-20 consumers use the shared
helper. External sale signatures, quote tuples and refund ownership are unchanged.

| Collection policy | Quoted reveal policy | Funding | Token request at mint |
| --- | --- | --- | --- |
| Original ASYNC / REQUIRED | Original declared policy | Original fee rules | Original AT_MINT or OWNER_WINDOW behavior |
| Explicit DISABLED | Undeclared, all fields zero | Zero | None |
| Explicit INSTANT / REQUIRED | Undeclared, all fields zero | Zero | None; request in a later block |
| Explicit INSTANT / NOT_REQUIRED | Undeclared, all fields zero | Zero | None |
| Explicit ASYNC / NOT_REQUIRED | Original declared policy | Original fee remains owed | None |

INSTANT REQUIRED tokens finish mint in REGISTERED state. This is neither a
terminal exemption nor finalized randomness. The coordinator permits the
separate synchronous provider read only in a later block; see
[instant entropy](instant-entropy.md). Mint completion emits no invented request
attempt or success. INSTANT NOT_REQUIRED remains terminal with no seed.

NOT_REQUIRED does not erase an ASYNC collection's declared fee or allocation
scope obligations. Immediate and Dutch/clearing paths fund their captured fee;
refund-window and auction completion retain the original `min(savedFee,currentFee)`
funding and refund the remainder through their existing accounting. DISABLED
and INSTANT return a canonical zero fee, so any saved deferred allowance remains
refundable. No payment authorization, revenue amount, refund owner or replay key
changes. Existing nonpayable ERC-20 paths still reject a nonzero native fee.

Zero-policy modes do not require an unused AT_MINT request gas budget. Original
ASYNC preflight requirements remain, including NOT_REQUIRED. The old Dutch
mode-only helper remains available; current Dutch/clearing callers use its
full-policy overload to distinguish undeclared zero from declared AT_MINT.

The fixed read helper validates explicit mode, security, consent, full policy
hash and content-state hash. After mint it also requires the frozen policy,
permanent collection identity, completed lifecycle and original coordinator.
Token status, zero seed, epoch and absent request fields must match: DISABLED,
NOT_REQUIRED, or newly REGISTERED required INSTANT. Missing capability never
creates an exemption; legacy ASYNC follows its original path. Pointer and runtime
checks remain. A burned token retains its permanent identity, but Core prevents
burning inside its mint receiver callback; that callback cannot bypass its guard.

## Validation boundary

The matched commerce capture passes all 28 cases: eighteen immediate and ten
Dutch/deferred cases, including two 256-input fee-conservation fuzz properties.
It checks malformed mode and identity evidence, exact rollback/retry and original
required-ASYNC controls. All 132 compiler inputs match the frozen source;
136 artifact metadata records and 1,520 source hashes were verified. All 52
compiled production products fit, including the six affected helpers/callers.
This is the optimized-IR Solidity 0.8.19 profile with the repository metadata settings.

These helper tests do not establish actual Core/Artist/Safe sale or auction
execution, linked graph capacity, successor continuity or release acceptance.
The actual-current terminal sale/distribution recipes remain a separate suite.
