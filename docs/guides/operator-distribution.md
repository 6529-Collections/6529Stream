# Current operator distributions

`StreamOperatorDistribution` executes the free batch pattern in
[SSA-AIRDROP](../stream-sales-and-auctions.md#airdrops-and-operator-distributions).
It calls the current Manager and Ledger. Every mint has an explicit beneficiary,
and every slice has one ordinary Manager operation root and per-token operation
IDs. There is no sale ID, purchase record, payment settlement, buyer deposit or
revenue credit.

## Prepare the phase

1. Deploy the distributor with the current Core, Manager, canonical
   ModuleRegistry, Governance V2 Executor and original NFTDelegation registry.
   Pin the intended delegation use case and a nonzero base module manifest.
   Register it under `keccak256("OPERATOR_DISTRIBUTION")`, using
   `type(IStreamOperatorDistribution).interfaceId` and
   `keccak256(distributor.moduleManifestBytes())` as the module manifest hash.
   Registration and subsequent lifecycle transitions use normal governance.
2. Choose a fresh phase ID and a `Program`. Name the operator account (a Safe may
   be that account), total quantity, per-beneficiary cap, two distinct counter
   IDs and delivery mode. `prepared = true` selects free prepared minting when
   a mint-time royalty snapshot is required. Neither execution path settles
   revenue.
3. Partition the ordered token list into slices of at most ten tokens and at
   most the phase's `maxBatchQuantity`. Each slice has a unique index. Preserve
   duplicate beneficiaries: they consume multiple units of that beneficiary's
   cap. Publish the complete ordered recipient/artwork manifest and proofs.
4. Compute every `sliceHash` as specified below, then the sorted-pair Merkle root.
   Store the root in `Program.slicesRoot`. For `STATIC` recipient caps, configure
   the dedicated phase with
   `configHash = distributor.programHash(collectionId, phaseId, program)`.
   For `MERKLE_STATIC`, use the additive `merkleProgramHash` described below.
   For an explicitly registered royalty snapshot policy, put the selected hash in
   `Policy.applicationConfigHash` and use the Manager's resulting
   `phaseRoyaltyConfigHash` as the phase `configHash`. The distributor and
   Manager both verify this composition.
5. Configure the required phase-scoped supply counter with `CONSTANT` key mode,
   static cap equal to `Program.totalQuantity`, and static increment one.
   Configure the recipient counter with `RECIPIENT` key mode, `STATIC` or
   `MERKLE_STATIC` cap mode, registered `staticCap` equal to
   `Program.perRecipientCap`, and static increment one. For Merkle allowances,
   this registered cap is the maximum wallet allowance; each proven leaf sets
   that beneficiary's effective cap. Enable only the distributor as this
   phase's executor. Obtain the original Artist consent
   for both phase configuration and the executor-set policy update, then hand
   Manager administration back to governance.

The distributor resolves the supply counter through the actual Manager and
requires its original PHASE subject. A COLLECTION or GLOBAL supply definition
is rejected before minting. The Manager's latched legacy PHASE interpretation
remains valid even if a definition is registered later; recipient counters may
retain their configured shared scope.

The phase commits the program before execution; the distributor has no separate
mutable program administrator. Current phase pause, expiry, executor approval,
Artist consent and Ledger replay checks all remain in effect. The slice proof
commits which tokens the operator may distribute. A recipient allowance proof
separately establishes that beneficiary's cap through the Manager.

## Merkle recipient allowances

Publish the full allowlist file before the phase opens. Register an
`IStreamMintCounterPolicy.Definition` on the Ledger with `RECIPIENT` key mode,
`PHASE` or `COLLECTION` scope, the allowlist's nonzero `capRoot`, and the published
file's nonzero content hash in `metadataHash`.
Use the returned definition hash as the recipient counter's `counterConfigHash`.
The Manager validates this definition and its cap mode during configuration;
`GLOBAL` Merkle allowances are unsupported. Existing `STATIC` recipient counters
retain their PHASE, COLLECTION or GLOBAL scope.

After registering the definition, call
`merkleProgramHash(collectionId, phaseId, program, recipientCounterConfigHash)`.
This getter does not require the phase to exist. It reads the definition selected
by the actual Manager's Ledger and rejects absent, unsupported or zero-publication
definitions. Use its result as the phase `configHash`, or as the existing royalty
policy's `applicationConfigHash` before computing `phaseRoyaltyConfigHash`.
Admission recomputes this commitment from the phase's current recipient counter.
Using the original V1 Program hash for a Merkle phase is rejected.

The additive hash binds the original Program hash, the complete recipient
definition hash and its full-list content hash. The Program commits the recipient
counter ID and cap ceiling; the definition commits the root, scope, key mode and
publication. Changing the file hash changes the phase commitment even when the
Merkle root is unchanged. Manager policy independently binds the same counter
configuration. The contract checks the commitment; operators remain responsible
for publishing the matching file. Original Program fields, V1 hashes and slice
hashes keep their original encoding. The getter is advertised through the separate
`IStreamOperatorDistributionMerkle` interface; the original distribution interface
ID and module registration remain unchanged.

Build leaves using the exact double-hashed preimage in
[MPA-MERKLE](../mint-policy-and-accounting.md#merkle-allowlist-cap-mode): chain ID,
Manager, collection, phase, counter ID, beneficiary, `maxCount`,
`hasPriceOverride` and `priceOverride`. `maxCount` must be nonzero and no greater
than `Program.perRecipientCap`. For a free distribution, publish leaves with
`hasPriceOverride = false` and `priceOverride = 0`; the Manager's accounting
does not charge prices.

Set `batch.resolverData = abi.encode(proofs)`, where `proofs` is the original
`IStreamMintCounterPolicy.AllowlistProof[][]`. The outer array follows the
phase's configured order of Merkle counters, omitting static counters. Each
RECIPIENT inner array follows the complete ordered beneficiary array, including
duplicates. The distributor forwards these bytes unchanged. The Manager checks
each proof against the actual beneficiary and uses its proven cap when checking
the complete batch's projected consumption. Two entries for the same beneficiary
consume two units; prior slices consume the same applicable Ledger allowance.

These allowance proofs are separate from `distribute`'s slice-membership proof.
Changing a leaf's `maxCount`, beneficiary, counter or domain invalidates its
allowlist proof. A failed proof, exceeded cap or later mint/funding failure rolls
back slice use, authorization, operation root and counter consumption together.
Failure-isolated NFT delivery still consumes the beneficiary's allowance and
creates an owed NFT claim when delivery fails.

## Hashes and call construction

All hashes use `keccak256(abi.encode(...))`. No packed encoding is used by this
product. These are product commitments, separate from the Manager's original
operation-root and token-operation-ID domains.

| Getter | Exact preimage |
| --- | --- |
| `programHash(collectionId, phaseId, program)` | `keccak256("6529STREAM_OPERATOR_DISTRIBUTION_CONFIG_V1"), block.chainid, distributor, core, manager, collectionId, phaseId, program` |
| `merkleProgramHash(collectionId, phaseId, program, recipientCounterConfigHash)` | `keccak256("6529STREAM_OPERATOR_DISTRIBUTION_MERKLE_CONFIG_V1"), programHash(collectionId, phaseId, program), recipientCounterConfigHash, selectedDefinition.metadataHash` |
| `sliceHash(index, batch)` | `keccak256("6529STREAM_OPERATOR_DISTRIBUTION_SLICE_V1"), block.chainid, distributor, core, manager, batch.collectionId, batch.phaseId, index, batch.beneficiaries, batch.tokenData, batch.mintCommitments` |
| `sliceAuthorization(collectionId, phaseId, index)` | `keccak256("6529STREAM_OPERATOR_DISTRIBUTION_AUTHORIZATION_V1"), block.chainid, distributor, core, manager, collectionId, phaseId, index` |

`program` is the interface tuple in declared field order. `tokenData` is the
complete ordered `bytes[]`, not an array of hashes. Tree leaves are `sliceHash`
values directly. Each parent is `keccak256(abi.encode(min(left,right),
max(left,right)))`; a one-slice root equals its leaf. Proofs are bounded to 32
siblings. The index is committed even for identical recipient/artwork arrays.

For each call, set:

- `batch.payer = address(0)` and `batch.authorizer = address(0)`.
- `batch.contextHash = distributor.sliceHash(index, batch)`.
- `batch.authorizationId = distributor.sliceAuthorization(collectionId, phaseId, index)`.
- `batch.expectedPolicyHash` to the intended Manager phase policy hash.
- All four token arrays to equal length. Supply the original phase gate and
  resolver presentation bytes if that phase uses them; their validation remains
  with Manager. This executor-only profile does not substitute a buyer signature.

Call `distribute(program, index, proof, batch, gateData)` from the committed
operator. A Safe submits that exact payable CALL using its ordinary threshold
transaction. Individual Safe signers have no distribution authority. Successful
execution emits `DistributionSliceExecuted`; reconstruct token identities using
the Manager events. A slice is consumed both in the distributor and in the
Manager's durable authorization domain, and cannot be retried with a fresh
authorization or changed list. A reverted transaction consumes neither.

## Delivery and recovery

With `DIRECT`, set each initial recipient equal to its beneficiary. A rejecting
receiver rolls back the entire batch, including every counter and replay write.
Account code can change after commitment, so this mode requires the operator
to accept that execution risk.

Use `FAILURE_ISOLATED` whenever recipients may be contracts. Set every initial
recipient to the distributor and preserve the intended beneficiaries. The
Manager accounts against beneficiaries before any delivery. The distributor
attempts each Core-native ERC-721 transfer with the governed
`SALE_NFT_DELIVERY_GAS_LIMIT` (300,000 at deployment), copying no returndata.
A failed transfer retains that token and creates exactly one beneficiary claim,
emitting the original `AirdropDeliveryDiverted` event. Siblings remain deliverable.

The beneficiary calls `claimNft(tokenId, receiver)` to select another receiver.
Failure returns `false` and retains the claim; success clears it and emits the
original `AirdropNftClaimCompleted` event. A live NFTDelegation delegate calls
`claimNftFor(tokenId, walletWide, delegationIndex)` and can trigger delivery only
to the original beneficiary. Expired, revoked, wrong-scope and wrong-use-case
grants fail. Claims remain available after phase pause, executor removal or
distributor revocation; new-distribution policy is not reapplied to owed NFTs.
There is no admin NFT sweep or claim confiscation path.

## Reveal obligations and execution gas

ASYNC collections require an explicitly declared reveal policy. Read the live
per-token fee and send exactly `fee * quantity` with the
distribution. Both underpayment and overpayment revert. The distributor
forwards each obligation into the selected coordinator's collection reveal-fee
escrow; it retains no operator credit. Funding failure rolls back the whole
mint. For `AT_MINT`, it also attempts each request under the governed
`REVEAL_ATTEMPT_GAS_LIMIT` (400,000 initially). A failed request is evented and
the funded obligation remains with the coordinator. `OWNER_WINDOW` funds the
same obligations and leaves requesting to the declared reveal actor.

Quote and execute against the same intended chain and dependencies. Budget
enough transaction gas for the complete Manager batch, every bounded delivery
and every reveal attempt. Insufficient parent gas fails closed. Gas limits use
the existing Governance V2 delayed, raise-only policy. The selected entropy
coordinator retains its own requester authorization: grant the distributor that
permission if automatic requests require it. Permissionless fallback and
operator monitoring must cover failed attempts.

Explicit DISABLED and INSTANT collection policies have no asynchronous reveal
promise or fee. The shared completion path authenticates the original token's
policy and coordinator: DISABLED uses its real terminal record, while required
INSTANT entropy remains registered for a later-block request. An explicit
NOT_REQUIRED rendering policy skips the automatic request only after validating
its original terminal token evidence; ASYNC fee/declaration rules still apply.

STATIC is a renderer classification, not permission to omit collection entropy
configuration. Missing or contradictory policies fail closed. The separate
current terminal-entropy cases cover DISABLED and NOT_REQUIRED distribution;
complete renderer/distribution composition remains part of combined acceptance.

## Validation boundary

`test/unit/mint/StreamOperatorDistribution.t.sol` uses actual current Manager
and Ledger contracts, actual Safe 1.4.1 bytecode and real ERC-721 receiver logic.
Its Core, Artist, canonical registry, reveal coordinator and NFTDelegation read
rows are explicitly typed fixtures. It covers commitment/replay, static and
Merkle recipient counters, direct rollback, delivery isolation, claims,
delegated claims and fee custody. Merkle regression cases are authored against
the actual Manager/Ledger proof and projected-consumption paths; their native
runtime result remains pending until the combined validation run.

`test/current/StreamCurrentOperatorDistribution.t.sol` is the separate acceptance
case with the actual current Core, Manager, Ledger, Artist, ModuleRegistry,
Governance Executor, entropy coordinator, original NFTDelegation deployment and
real Safe principals. Its external provider remains the shared fixture's
service boundary. Authored acceptance cases do not establish a passing runtime
result; combined current-stack execution, gas-envelope verification and final
genesis registration/artifact inclusion belong to the integration validation.
