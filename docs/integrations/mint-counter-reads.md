# Mint counter reads

Use `IStreamMintCounterReads` (ERC165 `0xe96c52f4`) at the actual Manager or
fallback Manager. These
reads explain accounting without obtaining gate, Artist, payment or executor
authorization. Use [canMint](mint-eligibility-preview.md) for shared mint
eligibility, and the original executor-sensitive operation preview for identity.

## Values and remaining units

| Read | Meaning |
| --- | --- |
| `rawCounterValue(valueKey)` | Read the explicit key in this Manager's Ledger |
| `counterValue(collectionId, phaseId, counterId, subjectKey)` | Apply the configured scope and this Manager's identity to derive the Ledger key |
| `remainingForCounter(collectionId, phaseId, counterId, subjectKey)` | Remaining counter units for a static or uncapped counter |
| `resolveCounter(context)` | Derive one canonical subject, effective cap, increment and resolution hash |
| `remainingForResolvedCounter(context)` | Return that resolution, current value and verified remaining units together |

Selectors are `0x9dec2d63` (raw value), `0x28795416` (scoped value),
`0x3921c74c` (proofless remaining), `0x2b30d626` (resolution), and
`0x4ee83aeb` (resolved remaining).

Tuple-based reads require an existing phase and enabled counter. Value-key
derivation uses its pinned effective definition, including legacy phase scope.
`PHASE` keeps both IDs, `COLLECTION` uses the original zero phase sentinel, and
`GLOBAL` uses both original zero scope sentinels. Every derived value key keeps
the actual Manager identity. The raw read accepts any explicit Ledger key; it
does not infer a subject or another Manager's preimage.

For `STATIC`, remaining units are `max(cap - current, 0)`. For legacy `NONE`,
they are `uint64.max - current`: remaining storage headroom, not a mint limit.
Divide remaining units by the positive configured increment to count further
counter consumptions. A per-token counter consumes once per token; a `CONTEXT`
counter consumes once per batch. These are distinct from mint quantity limits.

## Merkle allowances require evidence

The proofless `remainingForCounter` reverts with
`MintCounterProofRequired(counterId)` for `MERKLE_STATIC`. Its configured ceiling
is not a wallet allocation. A root can contain different valid caps for the
same account, so the account or subject key alone cannot select an allowance.

Supply exactly `abi.encode(one IStreamMintCounterPolicy.AllowlistProof)` in
`context.resolverData` to resolve a Merkle counter. The proof is checked against
the existing Manager/chain/collection/phase/counter/account domain and pinned
root, with the original positive cap, configured ceiling and price-declaration
rules. Noncanonical encodings and trailing bytes reject. Malformed ABI also
rejects. The returned cap belongs to that validated leaf. Counter reads do not
charge or interpret sale prices. Non-Merkle modes ignore resolver bytes as the
ordinary batch counter path does.

`remainingForResolvedCounter` reads the same scoped Ledger key after resolving
the proof. Two valid leaves for one subject can return different remaining
allowances against the same current value. Invalid proof presentation never
falls back to the configured ceiling.

## Exact context and hashes

The original context fields, in order, are `collectionId`, `phaseId`,
`counterId`, `payer`, `initialRecipient`, `beneficiary`, `executor`, `authorizer`,
`tokenIndex`, `contextHash`, and `resolverData`.

`RECIPIENT` means beneficiary, not temporary delivery/custody. `EXECUTOR` and
`AUTHORIZER` use the supplied context, not the read caller. This does not validate
those addresses' authority. `CONTEXT` requires a nonzero context hash and the
original `uint256.max` batch token-index sentinel; other modes require a token
index below the original ten-token bound.

Resolution shares execution's original single-row preimage, scope and proof
helpers. In particular, a scoped `CONSTANT` row retains the original pre-scope
subject inside its base resolution hash, while its returned subject and value
key receive the configured scope. These reads do not rewrite that identity.

Calls do not mutate counters, replay state, operation nonces or phase settings,
and do not emit mint receipts. Pauses or withdrawn Artist consent can prevent
minting while accounting remains readable. Dynamic resolver profiles excluded
from v1 are not enabled by this interface.

## Implementation boundary

The five new Manager views and four retained accounting views pass their original
calldata to one fixed linked worker. Its dispatch table accepts only those nine
declared selectors; ordinary
ABI decoding enforces their argument types. The worker returns the exact static
32-byte scalar, 64-byte policy-grace pair, 128-byte resolution or 192-byte
combined result. The original replay views still use the actual Manager's
Ledger scope, and the grace read retains its original hash/expiry result. This adds no
fallback proxy, configurable target or generic execution method.

Source, focused recipes and pending runtime acceptance are recorded in the
[batch evidence](../../ops/MINT_COUNTER_READS_ACCEPTANCE.md).
