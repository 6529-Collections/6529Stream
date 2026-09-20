# Mint eligibility preview batch

## Scope

This implements the original MPA Read API `canMint` requirement on the
phase-freeze source plus native-evidence commit `b2757bce`. The exact original
`MintPreview` and `CounterPreview` tuples live in the additive
`IStreamMintPreview` interface. The selector/capability is `0x4466a6fe`.
The [caller guide](../docs/integrations/mint-eligibility-preview.md) explains
diagnostics, explicit executor context and the limits of an advisory result.

The Manager facade delegates to one fixed linked read worker. One bounded
self-STATICCALL catches evaluation failures while preserving the actual Manager
as gate caller; its self-call branch evaluates once. Gate validation and every
executor-derived key use the explicit prospective executor. Current policy,
inclusive predecessor grace, current Artist authority, shared royalty source,
counter definitions/proofs, Ledger readiness and Manager-scoped replay checks
remain required. No state or execution identity is returned or reserved.

The ordinary counter preparation path retains its exact resolution body and
strict aggregate cap/overflow checks. Only the diagnostic sibling defers those
two checks to the result formatter. Complete aggregate cap denials retain all
rows; overflow has no representable `uint64` projected value and returns no rows.

Core, original execution/identity ABIs, storage, compiler profile, production
size limits, mint limits, governance delays and gate budgets are unchanged.
Host headroom comes from moving the original executable-phase admission body
into the existing fixed policy helper and the exact capability table into the
existing views helper. Original phase error order and actual execution caller
remain intact. All original royalty admission bodies remain unchanged.

## Focused recipes

The 15-case actual Manager/Ledger/Registry suite uses explicitly typed Core, Artist and
governance seams, genuine Allowlist and Ticket gates, and a named adversarial
gate fixture. It covers explicit executor context, caller-independent replay,
aggregate alias caps, effective Merkle rows, all 160 rows, overflow, malformed
proofs/batches, phase time/pause/error precedence, grace/current Artist authority,
malicious return/gas behavior, low caller gas, and downstream failure/rollback.
Capability checks retain the original ERC165 probe budget after body factoring.

The combined ABI/type capture `mint-preview-combined-abi-final-1` contains 191
exact sources and 21 cases: the 15 preview cases plus six original configuration
codec cases. It has zero compiler errors. `mint-preview-compatibility-1` retains
all 192 Manager and 194 fallback ABI entries, adding only `canMint` and
`MintPreviewUnavailable`; all 19 recursively normalized storage entries are
unchanged. The existing GasHost API remains usable without newly advertising
its ERC165 interface, preserving the original capability answers.

The focused native cohort passes all 21 cases on immutable commit
`b7378eeb281c3344a2d66d136d36c7dec1ce4e37`. Full-current/Safe/fuzz/gas acceptance
is pending. This
batch does not claim production readiness or complete the remaining original
`rawCounterValue`, `remainingForCounter` and `resolveCounter` Read API surfaces.

## Selected size evidence

Captures under ignored `artifacts/native-assembly/counter-scopes/` are immutable.
`mint-preview-native-b7378eeb-1` binds 191 exact sources to commit
`b7378eeb281c3344a2d66d136d36c7dec1ce4e37`, tree
`3f5de9fba5c8ce46b9d10a2855d935ab66e1b891`. All 21 tests pass, exit zero in
361.048 seconds, with no source mismatches or captured production-size failures.
Native JSON SHA-256 is
`322bac7fe9aa42fc551b888f907f2373d2bed164929def4fe1fc90e3b5313391`; its separate
log is empty. The original native profile and test envelope are unchanged.
Foundry reuses a copy of the validated freeze cache through ordinary dependency
invalidation. Cached products outside this source closure are excluded from the
new product-size claims. This evidence does not validate subsequent Read API work.

`mint-preview-size-4` compiles 153 exact sources and seven selected products with
Solidity 0.8.19, IR, optimizer 200, Paris, no CBOR/hash metadata. It completes in
32.735 seconds with zero errors and no runtime/init cap violations.

Input SHA-256: `c3a04991b41e5e0aaa59d23d130bfe6aae0abf66d5d1a150c3bd27727c8f416c`.
Output SHA-256: `fb53fa8db18e440b93f21b38466bd93672a421f15c560384e182593ac7bd1b6a`.

| Product | Runtime bytes | Init bytes |
| --- | ---: | ---: |
| Manager | 24,359 | 27,476 |
| Fallback Manager | 24,476 | 27,593 |
| Preview | 11,571 | 11,603 |
| Counter preparation | 6,491 | 6,523 |
| Transcript | 5,071 | 5,103 |
| Manager policy | 3,555 | 3,589 |
| Manager views | 4,814 | 4,846 |

Earlier oversized captures remain retained. An attempted private common royalty
admission helper increased generated size and was removed before this fitting
capture. Independent source review caught an initial library-selector self-call
mistake; the final worker explicitly encodes the Manager selector. Positive
preview cases cover that boundary. Neither rejected candidate is the final code.
