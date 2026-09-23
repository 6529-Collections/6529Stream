# Full-preservation provider capacity

The original and current-Artist full-preservation providers now route repeated
read and binding encodings through fixed linked libraries. This makes these
two concrete providers fit the existing deployment limits without changing
their constructor inputs, stored configuration, public ABI or profile choices.

## Preserved behavior

`StreamFinalityViewProviderBindingTransportV1` decodes only the original VIEW
binding selectors. The existing binding worker still performs every admission,
governance, one-use and currentness check and every storage write. Library
delegation retains the provider address, incoming caller, event emitter and hash
domain. Historical capability and receipt getters retain their original read
semantics.

The two nominal dispatch libraries retain the original VIEW, scoped-policy,
COLLECTION-policy and original-base branch order. A route outside the selected
new profiles still calls the original `super` implementation. Both prepared
entrypoints keep their original Registry address and runtime guard before
dispatch. The original and current-Artist configuration types and preservation
profile arguments remain separate.

The stored guard helper reproduces the original Router provider's chain check,
four runtime pins, scope shape and authoritative membership checks. It reads the
constructor-identical fields in `_graph.original`. In particular, the original
Native constructor passes `componentSourceGas` into Router's `sourceGas`; the
extracted membership read uses that smaller original budget. The fixed helper
does not use the larger outer `sourceGas` budget.

Public read wrappers that terminate with encoded return data have no internal
callers in either concrete provider's existing inheritance closure. Original
base fallbacks return normally. This extraction is scoped to these concrete
hosts; it does not introduce a general selector registry or configurable
dispatch target.

## Source and size evidence

The frozen baseline is commit `b454c032bcead62642a0595bed71a898c92bacdd`.
Its two provider source texts match the retained capacity capture. The comparison
retains all 95 ABI entries and all method identifiers for each provider, all seven
storage roots recursively, and the constructor bodies. Fourteen original bodies
per provider, including construction, remain token-identical. Original base
contracts are unchanged.

Solidity 0.8.19, optimizer 200, via IR, Paris and no CBOR were used for one final
five-product selection. The original 24,576-byte runtime and 49,152-byte complete
initcode limits remain in force.

| Product | Baseline runtime | Final runtime | Final creation | Constructor bytes | Complete initcode |
| --- | ---: | ---: | ---: | ---: | ---: |
| Original full-preservation provider | 38,563 | 24,206 | 36,783 | 3,520 | 40,303 |
| Current-Artist full-preservation provider | 38,947 | 24,190 | 37,145 | 3,520 | 40,665 |
| VIEW binding transport | — | 5,896 | 5,930 | 0 | 5,930 |
| Original nominal dispatch | — | 17,401 | 17,433 | 0 | 17,433 |
| Current-Artist nominal dispatch | — | 17,649 | 17,681 | 0 | 17,681 |

The final 444-source ABI capture has zero errors. Its production sources exactly
match the selected measurement; the subsequent test-only change adds explicit
VIEW guard coverage. Earlier oversized captures are retained separately.

## Focused regressions and remaining acceptance

Six guard cases compare the extracted helper with the frozen original guard
bodies in the same harness. They cover all five canonical scope kinds, exact
chain/runtime/scope error order, all four pin failures and restores, invalid
membership facts, explicit malformed VIEW scopes, storage canaries and the
original smaller membership frame. The membership producer is an explicit
typed boundary, and its gas check observes an upper bound rather than proving
the full provider transaction cost.

Six transport cases check both nominal workers against literal six/eight-word
outputs, scope-budget projection, historical receipt bytes, original
already-bound error precedence and closed unknown-selector refusal. The
harness supplies explicit typed storage; it does not claim to authenticate a
complete provider deployment or a new binding ceremony.

These twelve new cases are authored and typechecked, not yet executed. Existing
provider construction, governance binding, source selection and finality tests
remain unchanged. Selected code size and source compatibility do not establish
linked deployment, actual current-stack finality, cold transaction cost or
full-graph runtime acceptance.
