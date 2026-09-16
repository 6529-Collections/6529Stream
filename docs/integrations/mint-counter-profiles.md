# Counter scopes and Merkle allowances

The current Mint Manager and Ledger retain `MintCounterConfig` and the original
phase configuration ABI. An optional content-addressed definition extends the
meaning of `counterConfigHash`. The canonical accounting requirements remain in
[Mint policy and accounting](../mint-policy-and-accounting.md).

## Register and select a profile

`IStreamMintCounterPolicy.Definition` contains, in order:

| Field | Meaning |
| --- | --- |
| `scope` | `GLOBAL = 0`, `COLLECTION = 1`, `PHASE = 2` |
| `keyMode` | The existing Manager counter subject enum |
| `capRoot` | Sorted-pair Merkle root, or zero for a static cap |
| `metadataHash` | Application description commitment |

Register the definition on the Ledger before configuring the phase. Its hash is
`keccak256(abi.encode(keccak256("6529STREAM_MINT_COUNTER_DEFINITION_V1"), definition))`.
Registration is permissionless and grants no phase, writer or mint authority.
The returned hash goes in the unchanged `MintCounterConfig.counterConfigHash`.
The configuration's `keyMode` must match the registered definition.

First policy registration permanently selects a definition's interpretation for
that Manager. A hash used before its definition exists remains legacy, with
phase scope, even if somebody later registers that hash's preimage. This also
applies when the Manager later configures another phase. Inspect the effective
selection with `counterDefinitionForManager(manager, hash)`; the global
`counterDefinition(hash)` lookup alone does not show this selection.

Registered profiles support `STATIC` and `MERKLE_STATIC` caps with positive
static ceilings and positive static increments. `NONE` remains supported for
legacy configurations. Dynamic resolver modes are not implemented. Registered
profiles reject `UNKNOWN`, `AUTHORIZER`, global `CONTEXT`, and Merkle caps on
global scope or on subjects other than `PAYER` and `RECIPIENT`.

## Counter namespaces

| Scope | Value-key collection | Value-key phase |
| --- | --- | --- |
| Global | `0` | `bytes32(0)` |
| Collection | Actual collection | `bytes32(0)` |
| Phase / legacy | Actual collection | Actual phase |

The subject and value-key domains remain those of `StreamMintOperationIdentity`.
The namespace normalization also applies to a `CONSTANT` subject. Address
subjects bind the Ledger, subject mode and account; recipient accounting uses
the batch beneficiary, including a delegated vault, rather than the executor.
Use Manager previews with the configured counter ID to obtain the effective
subject and value key.

Sharing a `counterId` and normalized namespace shares its running value. Caps
are checked against that value, including every duplicate occurrence in a
batch. Manager checks the complete projected batch before Ledger consumption;
Ledger independently enforces each write. Policy reconfiguration does not
clear stored values.

## Merkle proof encoding

`CounterCapMode.MERKLE_STATIC` is appended as value `3`; previous enum values
remain unchanged. Its definition must have a nonzero `capRoot`. The unchanged
`staticCap` field is the maximum admitted per-account allowance. Each proof's
`maxCount` must be positive and no greater than that ceiling.

`AllowlistProof` contains `(uint64 maxCount, bool hasPriceOverride,
uint256 priceOverride, bytes32[] proof)`. Its leaf is exactly:

```solidity
keccak256(bytes.concat(keccak256(abi.encode(
    keccak256("6529STREAM_MINT_ALLOWLIST_LEAF_V1"),
    block.chainid, manager, collectionId, phaseId, counterId, account,
    maxCount, hasPriceOverride, priceOverride
))))
```

Hash each pair in ascending `bytes32` order using `keccak256(abi.encode(a, b))`.
The leaf always binds the actual phase, even for a collection-scoped counter.
Proof siblings do not enter the resolution commitment; the canonical leaf does.

Put `abi.encode(AllowlistProof[][])` in the mint batch's `resolverData`:

- Outer rows correspond only to Merkle counters, in configured counter order.
- A `PAYER` row contains exactly one proof for the batch payer.
- A `RECIPIENT` row contains exactly one proof per beneficiary, in batch order.
- Duplicate beneficiaries still require one occurrence per token and consume
  the same accumulated allowance.

This standard Manager proof path currently accepts only
`hasPriceOverride = false` and `priceOverride = 0`. Any other combination,
including the declared-free shape `true/0` and the inconsistent shape
`false/nonzero`, reverts with `MintAllowlistPriceOverrideUnsupported` before
counter, replay, operation-nonce, or Core state can be written. The price fields
remain in the canonical leaf preimage so the Merkle schema does not change.
They can be enabled only after an explicit sale/payment consumer authenticates
the same leaf and applies the resulting price during settlement. Independent
sale authorization types with their own price fields do not enable prices in
this `MERKLE_STATIC` proof path. Executor, payer, initial recipient,
beneficiary and authorizer remain distinct identities.

## Succession and evidence

Follow [mint continuity](mint-continuity.md) to preserve both values and profile
selections across Manager or Ledger replacement. A Merkle root binds a Manager;
successor proofs need a new root/configuration while retaining the intended
counter ID and scope.

`StreamMintCounterScopes.t.sol` exercises actual Manager/Ledger accounting,
cross-phase and cross-collection sharing, legacy first-use selection,
differentiated allowances, duplicate recipients and proof mutations. Its Core,
Artist and governance boundaries are typed fixtures; it is not the whole-Core
activation or complete settlement acceptance suite.
