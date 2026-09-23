# Current operator distribution caller

`current-distribution.ts` builds the complete ordered token manifest and prepares
the free operator-distribution calls described by the protocol guide. It does
not sign, send, create a sale, credit a payment, or grant operator or delegation
authority.

## Build and review the manifest

Supply the pinned chain, distributor, Core and Manager addresses, the phase and
counter identities, the operator, delivery mode, and every ordered token fact.
The producer partitions that list into consecutive slices of 1 through 10
tokens. It preserves duplicate beneficiaries and exact artwork bytes. Every
slice index is committed, including slices with otherwise identical contents.

The returned artifact contains the canonical program and its `programHash`,
direct `sliceHash` leaves, sorted-pair proofs, and the original ordered facts. Its `totalQuantity` is the
reviewed token count. `manifestCompletenessReviewed: true` is an explicit caller
assertion; the producer cannot discover an omitted token. Artifacts are bounded
to 4,096 tokens, 4 MiB of token bytes, and 16 MiB of canonical JSON.

`DIRECT` routes each initial recipient to its beneficiary. A receiver rejection
reverts the whole slice. `FAILURE_ISOLATED` routes initial delivery through the
distributor while retaining the same beneficiary list and accounting. Failed
delivery creates a fixed-beneficiary claim.

## Prepare a slice

`inspectAndPrepareOperatorDistribution` uses one concrete block number to check:

- the distributor's immutable Core and Manager;
- Core's selected current `MINT_MANAGER` pointer;
- the phase config, active policy hash, distributor executor permission and the
  exact supply and recipient counters;
- optional prepared-royalty composition;
- the live program, slice and authorization hashes and unused slice flag; and
- Core's selected entropy coordinator and declared per-token reveal fee.

The returned payable CALL uses the committed operator as caller and exact
`fee * slice quantity` as value. Payer and authorizer are zero. Runtime
`resolverData` and `gateData` are retained in the CALL but are outside the slice
hash, as defined by the contract. Review those bytes separately.

`simulatePreparedOperatorDistribution` repeats the pinned reads, reconstructs
the entire CALL, and executes `eth_call` from the operator. A successful
simulation checks current contract behavior at that block. It does not prove a
Safe threshold, preserve state for a later block, or submit a transaction.
Numeric block pinning has no block-hash reorg check. Runtime code identity,
module/delegation admission and phase timing remain contract checks exercised by
simulation or execution.

## Recover a retained NFT

`prepareOwnDistributionClaim` makes the saved beneficiary the caller and allows
that beneficiary to choose a nonzero receiver other than the distributor.
`prepareDelegatedDistributionClaim` records the expected original beneficiary,
but encodes only the protocol's `(tokenId, walletWide, delegationIndex)` witness.
The delegated contract path can deliver only to that saved beneficiary.

`inspectDistributionClaim` reads `nftClaim(tokenId)` at a concrete block and
checks its exact collection, phase, and beneficiary. Claims intentionally remain
available after phase or module lifecycle changes, so this read does not reuse
new-distribution admission checks. `simulatePreparedDistributionClaim` then
executes the exact call from the claimed caller. A `false` result is a valid
failed delivery: the onchain claim remains. Delegation scope, expiry, use case,
registry runtime, receiver behavior, and Core runtime are live contract checks;
the client does not claim them from the stored claim row.
