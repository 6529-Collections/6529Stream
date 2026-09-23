# Mint counter accounting reads

These callers inspect the five original accounting views on a Manager or
fallback Manager. They report counter identities, values and remaining units.
They do not establish gate, Artist, payment, executor or mint authorization.
Use the original `canMint` and operation previews for those separate decisions.

| Method | Result |
| --- | --- |
| `rawCounterValue(valueKey)` | The value at any explicit key in this Manager's Ledger |
| `counterValue(collectionId,phaseId,counterId,subjectKey)` | The value at the configured scoped key |
| `remainingForCounter(collectionId,phaseId,counterId,subjectKey)` | Static remaining units or uncapped storage headroom; Merkle caps require a proof |
| `resolveCounter(context)` | Original subject, effective cap, increment and resolution hash |
| `remainingForResolvedCounter(context)` | That resolution, current value and remaining units in one original read |

## Pinned inspection

```js
const prepared = prepareMintCounterReadCall(manager, caller, {
  method: "remainingForResolvedCounter",
  context,
});
const observed = await inspectMintCounterRead(
  provider, deployment, prepared, { blockTag }
);
```

`deployment` contains `chainId` and reviewed address/runtime-hash pins for the
actual Manager and its Ledger. `blockTag` is a concrete block number. The
inspector copies the full request before asynchronous reads, checks both
runtimes and the Manager's Ledger binding, and rejects changed block hashes or
noncanonical return bytes.

For scoped reads it checks the existing phase and enabled counter, reconstructs
the scoped key, and joins the original Manager result with the Ledger value at
the same block. Raw-key reads accept any explicit `bytes32`, including zero,
and do not infer a phase, subject or another Manager's preimage.

The output is recursively immutable and carries `accountingOnly: true`.
`returnData` retains the exact original response. Scalar responses are 32 bytes;
resolution and combined responses are 128 and 192 bytes respectively. The
prepared calls are view requests for `eth_call`; they create no transactions,
signatures or mint receipts.

The inspector limits resolver data to 8,192 bytes, prepared calldata to 16,384
bytes, each pinned runtime to 65,536 bytes, and the optional capability response
to 4,096 bytes. These are client inspection bounds, not additional protocol
limits. The pure encoding helpers preserve the original ABI widths.

## Counter units

For static caps, remaining units are `max(cap - current, 0)`. For legacy
`NONE`, they are `uint64.max - current`, which is storage headroom rather than
a mint allowance. The output labels these meanings separately.

`remainingConsumptions` divides the remaining units by the positive configured
increment. A per-token counter consumes once per token; a `CONTEXT` counter
consumes once per batch. Neither number replaces phase quantity limits or
full-batch eligibility checks. A paused phase or withdrawn Artist consent can
prevent minting while its accounting remains readable.

## Exact context and scopes

The original context contains these fields in order:

```text
collectionId, phaseId, counterId, payer, initialRecipient, beneficiary,
executor, authorizer, tokenIndex, contextHash, resolverData
```

`RECIPIENT` uses the beneficiary. `initialRecipient` remains in the original
calldata but does not select this accounting subject. `EXECUTOR` and
`AUTHORIZER` use their explicit context fields, independently of the RPC caller.
Only the selected subject input must be nonzero. `CONTEXT` requires a nonzero
context hash and the original `uint256.max` token-index sentinel; other key
modes require an index below ten.

`PHASE` retains both original scope IDs, `COLLECTION` replaces the phase ID
with zero, and `GLOBAL` replaces both IDs with zero. Every value key retains the
actual Manager. A scoped `CONSTANT` counter preserves the pre-scope subject in
its base resolution hash while returning the scoped subject and value key.
The client retains `preScopeSubjectKey` so this distinction is visible.

## Merkle proof presentation

Merkle resolution uses exactly `abi.encode(one AllowlistProof)` in
`context.resolverData`. The original proof fields are `uint64 maxCount`,
`bool hasPriceOverride`, `uint256 priceOverride` and `bytes32[] proof`.
This single proof differs from the batch executor's nested proof arrays.

The proof must match the original chain, Manager, collection, phase, counter,
account and price-declaration domain. Its positive cap must not exceed the
configured ceiling. Noncanonical encoding, trailing bytes, a wrong domain or
an invalid proof rejects. `hasPriceOverride: false` requires a zero price;
`true` permits the supplied price, including zero. These reads do not interpret
or charge that price.

Different valid leaves for one account can select different caps against the
same current counter value. A proofless Merkle remaining query therefore cannot
use the configured ceiling as the account's allowance. Invalid proofs never
fall back to that ceiling. Non-Merkle modes ignore resolver bytes exactly as
the original counter path does.

## Definition observations

The original Manager queries the Ledger's optional counter-policy capability
with a nested 30,000-gas limit. Unsupported or unsuccessful probing selects
legacy `PHASE` scope. Supported reads use `counterDefinitionForManager`, which
preserves the Manager's pinned interpretation; they do not substitute a newer
global definition. When the definition is absent, the original helper replaces
only its scope with `PHASE`.

The inspector's direct Ledger probe is labeled
`scope: "direct-ledger-observation"` and `noNestedGasEquivalence: true`.
An ordinary RPC call does not reproduce that internal gas budget. The observed
definition supplies a candidate reconstruction, which must match the original
Manager's scoped key and accounting result. Matching results still do not prove
which internal probe branch ran when both branches produce the same accounting.

An actual call exception or a noncanonical capability response can select the
legacy candidate. Other transport failures remain errors. Runtime and block
checks apply to both paths. An observation failure is not a mint-eligibility
decision.

## Frozen evidence

The additive fixture uses `parallel-feature-batch65-20260920` at
`ea92b7d41ae9e9eede2a00f2c12b70543f125307`. All 2,309 literal compiler inputs
were verified byte-for-byte against Git. The selected fixture retains 58 ABI
entries, 115 dependency-source hashes and 12 original source texts.

The context, resolution and counter tuples come from the retained compiler ABI.
`AllowlistProof` is internal to the contracts and has no ABI entry in this
capture; its independent test encoding follows the retained original Solidity
declaration. Existing client fixtures retain their earlier source pins.

```sh
node scripts/generate-current-mint-counter-reads-fixture.mjs \
  /path/to/abi-input.json /path/to/abi-output.json --check
```

Source, client and mocked-RPC checks do not establish native current-stack,
actual mint, gas, genesis or release acceptance. The integrator owns that
separate execution evidence.
