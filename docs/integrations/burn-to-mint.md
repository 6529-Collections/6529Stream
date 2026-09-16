# Native Stream burn-to-mint

`StreamBurnMintGate` supplies genesis component `BURN_MINT_GATE` and implements
the same-transaction Stream-source recipe in [SSA-BURN](../stream-sales-and-auctions.md).
It serves `IStreamMintGate` and the additive
[burn execution interface](../../smart-contracts/interfaces/stream/mint/IStreamBurnMintGate.sol).
Burn-to-redeem remains the separate [redemption product](burn-redemption.md).

## Program and phase setup

The operator configures one immutable program per target collection. Its
`ProgramConfig` pins the current Core-selected Manager, target collection,
dedicated phase, sorted source-collection IDs, number of sources per minted
token, inclusive optional time bounds, free prepared-mint election and optional
native sale adapter. A nonzero native adapter selects the paid native route;
zero selects the free route. The source set has at most 64 collection IDs.

Configure the Manager phase with this gate and the exact returned program hash
as `MintGateConfig.gateConfigHash`. The Manager policy hash thereby commits to
the source set, ratio and window. Configure the phase's supply and beneficiary
counters and obtain the normal Artist policy consent. Authorize this gate as
the free phase executor, or the pinned native sale adapter as the paid phase
executor. Registry admission uses module type `6529STREAM_MINT_GATE_V1`, the
gate's declared version/runtime/manifest and `IStreamMintGate`.

The program config hash is `keccak256(abi.encode(domain, chainId, gate, core,
registry, entireProgramConfig))`, where `domain` is
`keccak256("6529STREAM_BURN_MINT_CONFIG_V1")`. The native adapter and Manager
runtime hashes are retained at registration and checked at execution. The
Core registry and Manager pointer selections must still match. Replacing the
Manager does not silently migrate the immutable program: the replacement
requires a newly admitted gate/program and the normal policy approval.

## Owners, operators and recipients

The burn caller must own every supplied source token or have its token-specific
approval or collection-wide operator approval. Independently, the gate needs
ERC-721 approval to execute each `Core.burn`. An approval to the gate alone does
not authorize an unrelated caller to burn someone else's token. An approved
burn caller selects the explicit output recipients; ownership, caller, gate,
payer and recipient are distinct facts.

Source token IDs must be strictly increasing and distinct. A call accepts at
most 16 original sources, and their count must equal minted quantity times
`sourcesPerMint`. Every source must be live in a permitted Stream collection.
After each burn the gate checks that Core still reports the same collection
and serial with `burned = true`. Preburned claims, external-collection burns and
keep-token exchanges are excluded.

## Free execution

Call `burnAndMint(batch, sourceTokenIds)`. `batch.payer` and `batch.authorizer`
are zero, initial recipients equal beneficiaries, and the request contains its
normal nonzero authorization and expected Manager policy hash. The gate calls
`executeSingleStepMint` or `executePreparedMint` according to the immutable
program. The prepared route retains the Manager's royalty-snapshot obligations.

Supply exactly the current per-token reveal fee times batch quantity as
`msg.value`. The gate captures the quote, mints through Manager/Ledger, funds
the reveal escrow and attempts the normal request. Fee-funding failure reverts
the entire burn and mint. A provider request failure retains the minted token
and funded reveal escrow under the existing reveal retry rules.

## Native paid execution

Use the additive `StreamNativeFixedPriceSaleAdapter.purchaseWithBurn(execution,
sourceTokenIds)` entry and the original signed native sale payload. The
[callback interface](../../smart-contracts/interfaces/stream/mint/IStreamBurnMintNativeSale.sol)
preserves the original `purchase` ABI.

The adapter retains the caller's ETH and commits to the exact gate, Core,
Manager, phase/sale configuration, authorization payload, source list, buyer
and supplied value. The gate authenticates the pinned adapter and burns for
that original buyer, then opens a proof only while calling the adapter back.
The adapter consumes its one-use callback permission before running the
original signature, settlement, Manager mint and reveal flow. Returned result
and token identity must match the completed inner purchase.

The buyer remains both native payer and executor. Excess ETH remains the
buyer's pull credit in the original adapter; the gate never owns that credit.
Any callback substitution, replay, rejected signature, failed settlement,
rejected receiver or Manager failure rolls back sources, payment, counters and
nullifiers together. Direct `purchase` remains unchanged for ordinary phases.
This batch does not add an ERC-20 burn consumer or alter ERC-20 native-reveal
allowance behavior.

The native adapter links `StreamNativeBurnCallback` for the one-use context
and `StreamNativeSaleMint` for its unchanged single-token mint-result and
retained-rights checks. Its existing `StreamNativeImmediateSaleWorker` also
serves the sale-ID and price-program authorization-digest reads. The external
selectors, domains and return tuples remain unchanged. The two sale-ID
wrappers are external functions; there are no internal host callers.

Use the repository's current via-IR build profile for deployable products and
include both new linked libraries in deployment and manifest generation.
Successful default code generation alone is not evidence that the non-IR
adapter meets the runtime size limit.

## Replay and event reconstruction

For every source, the gate returns the original nullifier:

```solidity
keccak256(abi.encode(
    keccak256("6529STREAM_BURN_NULLIFIER_V1"),
    uint256(block.chainid),
    address(core),
    uint256(sourceTokenId)
))
```

The Manager canonicalizes and consumes all of them through the Ledger in its
own manager scope before minting. The gate never writes Ledger state or calls
Core mint hooks. Its live proof commits to the exact request, caller, source
identities, source owners and originals, and is removed before returning.
Retained burned identity outside that guarded execution is insufficient proof.

Each source emits the specification's exact `BurnMintExecuted` event. Source
index `i` maps to minted index `i / sourcesPerMint`. `BurnMintBatchExecuted`
adds the operation root, ordered source owners and full output list. Join those
events to Core's native burn/transfer events and the normal Manager/Ledger
authorization, nullifier, operation and token events.

## Freeze and finality checks

Operator tools must inspect `allowedSourceCollections(target)` before any
source or target freeze/finality action. A source needs an explicit retained
burn path and scoped finality; a collection burn block or collection-scope
finality terminates its ability to serve as a source. Target collections need
burn-compatible open supply or scoped finality; closing their mint path ends
the program. Core remains the enforcing authority. No gate exemption changes
Core's burn block, freeze, supply or finality checks.

## Validation boundaries

The focused [gate suite](../../test/unit/mint/StreamBurnMintGate.t.sol) uses the
actual current Manager and Ledger and real Safe 1.4.1 bytecode, with explicit
Core, Artist, registry and entropy test boundaries. The
[native callback suite](../../test/unit/mint/StreamNativeBurnCallback.t.sol)
uses the actual adapter, recorder, Resolver, factory and escrow, with a hostile
typed gate and a Manager boundary. Neither substitutes for the authored
[whole current-stack test](../../test/current/StreamCurrentBurnMint.t.sol),
whose execution is tracked separately by the coordinator. Release manifests,
genesis wiring, combined validation and testnet delivery remain integration
work; these sources do not establish production readiness.
