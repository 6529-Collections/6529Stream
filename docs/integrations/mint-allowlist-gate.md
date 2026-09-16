# Mint allowlist gate

`StreamMintAllowlistGate` is a signer-free eligibility gate for a phase that
already enforces an immutable `MERKLE_STATIC` counter in `StreamMintLedger`.
It verifies the same canonical MPA-MERKLE leaves as the Manager and refuses to
operate unless the selected counter is registered in the actual Ledger. The
gate never owns allowance state and never replaces counter consumption.

## Deployment and phase configuration

Deploy one gate with the published Merkle root and the counter ID whose caps
must govern the phase:

```solidity
StreamMintAllowlistGate gate = new StreamMintAllowlistGate(capRoot, counterId);
```

Register the gate as an active `6529STREAM_MINT_GATE_V1` module, then configure
the phase with `gate.gateConfigHash()`. The phase must also contain exactly one
matching counter ID with:

- `capMode = MERKLE_STATIC`
- `deltaMode = STATIC`
- a nonzero `staticCap` ceiling and `staticIncrement`
- `keyMode = RECIPIENT` or `PAYER`
- a registered `IStreamMintCounterPolicy.Definition` whose `capRoot`, key mode,
  and non-global scope match the Manager counter configuration

The Ledger policy registered by the Manager must still match those fields at
validation time. A gate deployment cannot be reused with another root or
counter ID; both values are immutable and included in `gateConfigHash`.

## Leaves and proofs

Use the MPA-MERKLE leaf exactly as implemented by
`StreamMintCounterPolicy.allowlistLeaf`: `abi.encode`, the chain, Manager,
collection, phase, counter ID, account, cap, and optional price fields are
hashed once and the resulting word is hashed again. Merkle nodes use sorted
pair `keccak256(abi.encode(left, right))` hashing.

The gate authenticates the optional price fields but does not collect payment
or apply a settlement price override. A sale integration must enforce that policy.

`MintBatch.resolverData` is:

```solidity
abi.encode(IStreamMintCounterPolicy.AllowlistProof[][] proofs)
```

The outer array contains one group for every `MERKLE_STATIC` counter, in the
phase's configured counter order. For this gate's selected counter:

- `PAYER` requires one proof for `batch.payer`.
- `RECIPIENT` requires one proof per token, in `batch.beneficiaries` order.

The same `resolverData` is consumed independently by the Manager's counter
preparation. A valid gate result therefore cannot mint around a spent or
over-cap Ledger counter.

## Authorization and replay

Call `previewAuthorizationId(manager, executor, batch, nonce)` after every
batch field except `authorizationId` has been filled, then copy the result into
`batch.authorizationId`. Execute with `gateData = abi.encode(nonce)`.

The authorization ID binds the chain, gate, Manager, Ledger, executor, complete
batch payload, active or grace policy hash, nonce, and each Merkle proof's cap
and price values. It intentionally excludes proof sibling arrays, which are
verification witnesses rather than policy results. The gate result uses
`authorizer = address(0)` and `AuthorizerKind.NONE`; no signature is involved.

The gate also returns one stable nonce nullifier scoped to the chain, gate,
Manager, Ledger, collection, phase, and payer. The Manager consumes both the
authorization ID and nullifier in the Ledger before Core minting. Reusing a
nonce with a changed context produces a different authorization ID but the
same nullifier and therefore fails. Failed counter or Core execution rolls all
replay consumption back atomically.

The original narrow `IStreamMintGate.validateMint` ABI always reverts because
it cannot bind token data, mint commitments, or `resolverData`. Integrations
must detect and call `IStreamMintBatchGate.validateMintBatch`, as the current
Manager does.
