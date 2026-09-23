# ERC20 paid burn-to-mint signing

`current-erc20-burn-mint-signing` prepares the dedicated kind-8 ERC20 burn
profile. One atomic execution burns the ordered Stream sources, pays a positive
ERC20 price through contract 20 and mints one new token. The profile requires
an ACTIVE asset, strict collection PROFILE rights and a declared zero native
reveal fee. Those are live checks; the offline signing helpers do not establish
current admission or permission to burn an NFT.

## Original authorization and configuration

`ERC20BurnMintSaleConfig` preserves the original nine-field universal sale
configuration. `erc20BurnMintSaleId` uses `6529STREAM_SALE_V1` with kind 8,
chain ID, carrier, collection, phase and sale nonce. The configuration hash is
exactly `keccak256(abi.encode(CONFIG_DOMAIN, saleId, config))`, where the domain
is `6529STREAM_UNIVERSAL_FIXED_PRICE_CONFIG_V1`.

`ERC20BurnMintSaleAuthorization` preserves the original eleven fields:
`saleId`, `saleConfigHash`, `payer`, `executor`, `recipient`, `artist`,
`tokenDataHash`, `mintCommitment`, `executionNonce`, `nonce` and `deadline`.
Both the platform and current Artist sign the same `UniversalSaleAuthorization`
payload, using `6529StreamUniversalFixedPriceSaleAdapter`, version `1`, the exact
chain ID and the new burn carrier's address. There is no additional source-ID
field or signature kind in this original type. Runtime verification supports
the original ECDSA and bounded ERC-1271 paths.

`erc20BurnMintAuthorizationId` retains the original TICKET wrapping of the full
authorization digest. The ordinary mint context is that unwrapped digest.
Replay stores remain independent:

| Key | Owner |
| --- | --- |
| `(artist, authorization.nonce)` | Carrier; Artist nonce is not scoped to one sale |
| `(saleId, executionNonce)` | Carrier; execution nonce is positive |
| Original TICKET authorization ID | Manager/Ledger |
| Original per-source burn nullifier | Manager/Ledger |
| `(payer, paymentIntent.nonce)` | Contract 20 |

The original Artist nonce and payment-intent nonce may be zero. The Artist
cancels its carrier nonce with `cancelAuthorization`; that action is distinct
from payment-intent revocation and owner sale cancellation. This atomic route
has no separate custody purchase ID.

## Whole execution and immutable burn program

`ERC20BurnMintSaleExecutionData` contains the original authorization, raw token
data, platform signature and Artist signature. `ERC20BurnMintExecution` wraps
that complete `sale` value with `sourceTokenIds`.

```js
const packet = erc20BurnMintSigningSnapshot(
  chainId, carrier, saleConfig, saleId,
  { sale: originalSaleExecutionData, sourceTokenIds },
);
```

The snapshot checks the signed sale/configuration identities, deadline against
the sale window and raw token-data hash. It copies and freezes all nested
inputs. `saleExecutionData` is canonical `abi.encode(Execution)`, including
the source IDs; `saleExecutionHash` is its Keccak hash. It is not the encoding
of the inner sale alone.

Source IDs must be positive, strictly increasing and distinct, with at most
16 entries. Their count must equal the immutable program's `sourcesPerMint`
for this singleton mint. `validateERC20BurnMintProgram` checks that ratio and
the sale's target, phase and inclusive window against the original
`BurnMintProgramConfig`. The ERC20 program requires `prepared = false` and
`nativeSaleAdapter = 0`; its retained `nativeSaleCodeHash` is also zero.
An original program end of zero means unbounded. Allowed source collections
retain their strict increasing order and 64-entry maximum.

`erc20BurnMintProgramConfigHash` reuses the original
`6529STREAM_BURN_MINT_CONFIG_V1` preimage. The existing `burnMintNullifier`
helper retains the original chain/Core/source-token domain. Live reads still
need to establish allowed source collections, retained token identities,
unspent nullifiers, current program availability and approvals.

Source IDs do not change the original authorization digest or TICKET. They
bind the full execution, candidate commitment and gate's operation proof.
The workflow must preview that exact execution and validate the resulting
candidate; changing sources requires a fresh preview. The nonpayable preview
is simulated with `eth_call`: it temporarily opens a guarded proof and does
not burn sources or reserve mint capacity.

## Separate principals and payment

Payer, executor, source owner and output recipient may be distinct. The signed
executor must own each source or have the owner's token-specific or operator
approval. Independently, the gate needs approval to invoke Core's burn entry. A payment
intent or token allowance grants neither NFT permission.

`erc20BurnMintPaymentIntentPayload` preserves the original
`StreamPaymentIntent` under `6529StreamPaymentIntentVerifier`, version `1`, at
the actual configured contract 20. It binds the signed payer, asset, price
limit, sale ID and primary-policy hash. A nonpayer executor needs this payer
signature as well as the sale authorization and NFT permissions. The direct
payer route requires that payer to be the actual contract-20 caller.

All payment routes are nonpayable. Safe principals use ordinary zero-value
CALL; payment or sale signatures require the appropriate Safe message encoding.
Safe CALL capability does not establish token EIP-2612 signature support.
The existing permit implementation, asset policy and signature path must be
checked independently.

## Candidate identities and evidence

`normalizeERC20BurnMintCandidate` preserves the original order-one universal
candidate, with a zero poster and independent payer/output beneficiary.
`erc20BurnMintExecutionId`, `erc20BurnMintCandidateCommitment` and
`erc20BurnMintSettlementKey` preserve the original execution V1, candidate V2
and settlement-key V2 domains. Current and bound mint-policy hashes remain
separate. The carrier's guarded Manager preview decides whether a policy is admitted.
The primary-offer normalizer is not reused because its recipient and poster
rules differ.

Tests use the full compiled tuples from the 2,108-source capture at
`c717a3e10dca06950353c66c6493de41cdfcb9e1`, integrating carrier source
`83c67868303679ba34480bd120cbc08bfd87a5fc`. They cover original signing domains,
whole-execution encoding, source order and bounds, independent principals,
program compatibility, settlement identities and caller-input mutation.
This is client/source evidence; joined runtime, Safe execution, gas and release
acceptance remain separate checks owned by the integration coordinator.
