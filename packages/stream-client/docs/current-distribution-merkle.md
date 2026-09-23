# Published recipient allowances for operator distributions

This additive client profile targets `StreamOperatorDistribution` at ABI117
source `5d1756eb53a28ebc5ecd24513493ce6bfe7ef62f`, tree
`b0d30c650c1e55d3b213a3e0159dcb54d0a17c42`. It prepares free distributions with
published recipient allowances and the original owed-NFT claims, including
ordinary Safe CALLs.

The [earlier STATIC client](current-distribution.md), its fixture and its
program/slice hashes retain their original evidence. Its pure ordered-manifest
helpers remain useful here. Its STATIC-only inspector does not establish
admission for this Merkle profile.

## Two commitments with different purposes

The original eight-field `Program` still commits the operator, ordered slice
tree, two counter IDs, total quantity, registered per-recipient ceiling, delivery
mode and prepared-mint choice. No field was added to that tuple.

The original `programHash`, `sliceHash` and `sliceAuthorization` preimages remain
unchanged. Slice hashing retains the complete ordered `bytes[]` artwork, exact
beneficiaries and mint commitments. Duplicate beneficiaries remain duplicates.
The slice index is committed even when two slices have identical token facts.

MPA-MERKLE.7 adds a separate application configuration hash:

```text
keccak256(abi.encode(
    keccak256("6529STREAM_OPERATOR_DISTRIBUTION_MERKLE_CONFIG_V1"),
    originalProgramHash,
    recipientCounterConfigHash,
    selectedDefinition.metadataHash
))
```

`merkleProgramHash` is advertised through the separate interface `0x9f2d3027`.
The original distribution interface stays `0xe1ceb09a`. The additive getter does
not mutate or register a phase.

Use the new application hash as the phase `configHash`. If the original phase
royalty policy is configured, place it in `Policy.applicationConfigHash` and use
the actual Manager's `phaseRoyaltyConfigHash` result for the phase. The original
V1 program hash by itself is insufficient for a Merkle recipient phase.

## Select the actual definition

The preconfiguration path follows the distributor's actual Manager to that
Manager's Ledger and reads `counterDefinitionForManager(manager, hash)`. It can
run after definition registration and before phase configuration. It requires
a selected RECIPIENT definition with PHASE or COLLECTION scope, nonzero root and
nonzero full-list publication hash.

After configuration, obtain the recipient definition hash from the actual
phase's `counterConfig` for `Program.recipientCounterId`. An unrelated raw
`counterDefinition` result, supplied metadata hash, or guessed Ledger cannot
replace this selection. A Manager interpretation latched as absent remains
absent even if someone registers a raw definition later.

The full-list content hash matters independently of the Merkle root. Changing
the publication hash changes the definition and application commitments even
when all leaves are unchanged. Publish the complete file before opening the
phase, and retain the matching file with the reviewed program. The protocol
does not prescribe a file serialization or content-digest algorithm. A client
JSON format or locally chosen digest convention must be identified separately.

No local helper can prove that an operator published a file or included every
intended recipient. Manifest completeness and publication provenance require
review outside the hash calculation.

## Preserve both proof layers

The slice-membership proof authorizes the committed ordered token slice. It uses
direct `sliceHash` leaves and sorted-pair parents, with at most 32 siblings.
This proof is separate from recipient allowance proofs.

Allowance leaves use the original double-hashed MPA-MERKLE preimage: domain,
chain, Manager, collection, phase, counter, beneficiary, `maxCount`, price flag
and price value. A different Manager, phase, counter, beneficiary or cap changes
the leaf. The Ledger address is not an extra word in that leaf domain.

The source consumes the original `AllowlistProof[][]` bytes through
`MintBatch.resolverData`:

- Enumerate the complete configured phase-counter inventory in its actual order.
- Include an outer row only for each configured Merkle counter, preserving that
  filtered order.
- For a RECIPIENT counter, include one proof for every ordered beneficiary in
  the slice, including duplicate entries.
- Keep each proven cap positive and no greater than its registered ceiling.
  The required recipient counter's ceiling equals `Program.perRecipientCap`.

The client free-distribution profile requires `hasPriceOverride = false` and
`priceOverride = 0`. This is an explicit client restriction; the underlying
Manager accounting does not charge a price from an allowance leaf. Additional
Merkle counters must fit the client's supported proof profile rather than being
silently omitted.

Repeated beneficiaries share consumption under each actual resolved value key.
Every occurrence counts, including previous slices and collection-scoped use.
If repeated entries prove different caps, projected aggregate consumption must
fit every applicable cap. Per-entry arithmetic or independently checking only
one occurrence can miss a failing batch.

The required supply counter remains enabled, STATIC, CONSTANT, increment one,
with cap equal to total quantity. Its actual Manager-resolved subject must be
PHASE, including the Manager's retained legacy interpretation. A newly supplied
definition cannot replace that resolution.

## Execute as the committed operator

The operator itself calls the exact payable `distribute` method. A Safe is that
principal; its individual owners do not acquire distribution authority.
`MintBatch.payer` and `authorizer` remain zero. The original slice hash becomes
the context hash, and the original slice authorization binds the Manager replay
domain. There is no sale, deposit, revenue settlement or operator refund credit.

Each slice contains at most ten tokens and respects the actual phase batch
limit. The call retains exact resolver and gate bytes even though they are
outside the slice hash. Source checks for phase timing, executor approval,
Artist consent, policy grace and durable replay still govern the original call.
Saved observations must be revalidated before execution; a changed policy,
definition, counter value, nonce or fee can invalidate a previously prepared
slice.

Single-step and free prepared execution have different identity and event
surfaces. Free `executePreparedMint` supports the whole distribution batch,
while the public prepared operation preview supports only one token. A client
must not substitute a single-step preview for a larger prepared batch. The
original distributor simulation can still return its token IDs and operation
root; any missing preview must remain explicit.

Prepared royalty snapshots use the original phase wrapper and original stored
snapshot provenance. They do not convert this free distribution into a paid
prepared sale. Per-token Prepared Started/Completed events have their own joins;
ordinary `MintTokenExecuted` evidence is not interchangeable with them.

## Reveal fees and delivery

For a declared reveal policy, send exactly the current per-token fee multiplied
by slice quantity. Both underpayment and overpayment fail. The distributor funds
the selected original coordinator and retains no operator excess credit.
ASYNC collections require an explicit declaration; missing policy is not a
zero-fee quote.

Explicit DISABLED and INSTANT policies can avoid asynchronous fees and automatic
requests under their original rules. INSTANT does not imply final entropy at
mint time. NOT_REQUIRED rendering can skip an automatic request only with its
original terminal evidence. A bounded failed reveal request can coexist with a
successful funded mint; a funding failure aborts the original distribution.

With DIRECT delivery, initial recipients equal beneficiaries. A rejecting
receiver causes the original call to revert. With FAILURE_ISOLATED delivery,
initial recipients are the distributor, while accounting still uses the
beneficiaries. A failed transfer leaves an owed-NFT claim and emits
`AirdropDeliveryDiverted`; other tokens can be delivered successfully.

The Manager completes the batch before the distributor's per-token reveal and
delivery loop. Each token's reveal attempt precedes its diversion event, and
`DistributionSliceExecuted` follows the entire loop. Historical initial
recipients and requested delivery destinations do not imply current ownership
after callbacks or later transfers.

## Claim an owed NFT

The saved beneficiary can call `claimNft(tokenId, receiver)` and choose a nonzero
receiver other than the distributor. A delegate uses the original
`claimNftFor(tokenId, walletWide, delegationIndex)` witness and can trigger
delivery only to the saved beneficiary.

Read the complete retained six-word NFTDelegation row at its exact locator.
Validate the original registry and runtime, scope, use case, accounts, time
window and all-token form. The registry's boolean getter is insufficient. The
beneficiary calling `claimNftFor` takes the original self-claim branch and does
not need a delegation lookup.

Claims stay available after phase pause, executor removal or distributor
revocation. Their local exit checks must not reapply new-distribution admission.
A failed delivery returns `false` and restores the claim without a completion
event. A successful delivery clears the claim and emits
`AirdropNftClaimCompleted`.

A Safe terminal success establishes successful execution of the inner CALL;
it does not make an inner `false` return true. Simulation can inspect that
boolean directly. An eventless mined receipt with retained claim and custody is
a state observation, not independently recovered EVM return data. Document that
distinction when reporting the outcome.

## Client entry points

Use the package's separate `current-distribution-merkle` exports. Pure preparation
returns `factsVerified: false`; its hashes and proofs do not verify deployment
facts. Every provider workflow requires a concrete numeric block, copies its
inputs before the first asynchronous read, and returns frozen observations.

| Function | Purpose |
| --- | --- |
| `inspectDistributionMerkleProgram` | Read the actual Manager-selected definition and compare the original additive getter before phase configuration. Returns `phaseAdmissionChecked: false`. |
| `prepareDistributionMerkleCall` | Build the exact free distribution CALL from the program, ordered slice, complete counter inventory, proofs, policy, gate bytes and reveal fee. |
| `prepareDistributionMerkleClaim` | Build the original own-beneficiary or delegated claim CALL. |
| `captureDistributionMerkle` | Bind the prepared CALL to reviewed runtimes, route-specific dependencies, current observations and canonical block identity. |
| `revalidateDistributionMerkle` | Reconstruct the saved block and require unchanged reviewed facts at the requested later block. |
| `simulateDistributionMerkle` | Revalidate, then simulate the exact original CALL with an explicit gas limit. Returns distribution token IDs/root or the claim's actual boolean. |
| `reconcileDistributionMerkleReceipt` | Join the exact mined transaction to canonical logs, historical prestate and retained state. |

`inspectDistributionMerkleClaim` is also available for a local owed-NFT read.
Deployment metadata contains a chain ID and address/runtime-hash pins for the
distributor, Core, Manager, Ledger, module registry and delegation registry.
`linkedDependencies` supplies reviewed fixed libraries for distribution calls.
`delegationLinkedDependencies` supplies the libraries reachable by `claimNftFor`,
including its beneficiary self-alias. `claimNft` does not load either library
list or reapply Manager admission. The caller must establish each list's
completeness and source linkage from reviewed release metadata; matching runtime
hashes alone cannot prove those properties.

Receipt options are `{ execution: "direct" }` or
`{ execution: "safe", expectedSafeTxHash }`. The Safe profile requires the exact
inner CALL and value, zero outer transaction value, and one successful terminal
event with the independently obtained Safe transaction hash. It supports the
original indexed and non-indexed terminal event layouts.

Reconciliation requires the mined block to follow the capture block and the
reviewed facts to remain unchanged through the block immediately before mining.
It also compares exact end-of-block counters, operation nonce, replay and reveal
escrow. Unrelated transactions in the same block can make those comparisons fail
even if the target call succeeded. Receiver callbacks that request entropy or
add escrow mutations can also exceed the supported event/order profile. Obtain
stronger transaction-level evidence before interpreting such a refusal.
Successful token delivery uses
historical transfer events; subsequent receiver activity can change ownership.
Every receipt result keeps `functionReturnObserved: false`, including a retained
claim outcome.

### Client allocation limits

These bounds describe this client profile, not new protocol rules:

- Pure encoded calls and byte inputs: 4 MiB; allowance-tree entries: 4,096;
  allowance siblings: 64. Original slice proofs retain their 32-sibling limit.
- Outer transaction calldata: 4 MiB plus 16 KiB for Safe envelope/signature data.
- Configured phase counters: 16; tokens in one slice: ten. All counter/beneficiary
  combinations must remain represented.
- Provider return data and individual log data: 2 MiB; runtime bytecode: 128 KiB;
  each reviewed linked-library list: 256 entries.
- Receipt logs: 4,096, with at most four topics each and 8 MiB aggregate log data.
- Simulation requires a positive explicit gas limit no greater than 100,000,000.
  This allocation ceiling does not establish a deployable transaction gas limit.

## Evidence boundary

Use reviewed deployment metadata, concrete canonical blocks and immutable input
snapshots. Direct and Safe reconciliation must join exact call data/value,
transaction and block identity, emitter/event ordering, retained replay and
claim state, and original Manager/Ledger token identities. Independently obtain
the expected Safe transaction hash.

Refusal checks can preserve the original RPC error and compare selected
before/after reads for slice use, replay and counter values. Those observations
do not independently prove full EVM atomic rollback. Likewise, successful local
simulation and mocked receipt joins do not establish actual deployed runtime,
native contract/Safe execution, gas capacity or release acceptance. Those remain
with combined integration validation.
