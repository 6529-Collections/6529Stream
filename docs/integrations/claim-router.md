# Claim across split wallets

`StreamClaimRouter` implements the two calls in
[RSR-CLAIM-ROUTER](../revenue-splits-and-royalties.md#claim-aggregation-periphery).
Anyone may submit a batch. Each item names a wallet, asset and entitled account;
the router always releases directly to that same account. Use the zero address
for native ETH. The caller receives nothing unless it is the entitled account.

```solidity
import {IStreamClaimRouter} from
    "smart-contracts/interfaces/stream/revenue/IStreamClaimRouter.sol";

IStreamClaimRouter.ClaimCall[] memory claims =
    new IStreamClaimRouter.ClaimCall[](wallets.length);
for (uint256 i; i < wallets.length; ++i) {
    claims[i] = IStreamClaimRouter.ClaimCall(wallets[i], asset, recipient);
}
uint256[] memory amounts = IStreamClaimRouter(router).claimMany(claims, true);
```

`claimMany` calls `release(asset, account, account)` in input order.
`syncAndClaimMany` first calls `syncAsset(asset)` for each item, then releases
that item's entitlement. The latter is useful for explicitly observing tokens
sent directly to a wallet. A failed sync skips that item's release.

The router has no owner, stored state, approval handling, payable methods or
asset-transfer destination of its own. It cannot route alternate-recipient
claims. Those require the wallet's own authorization path. Do not send assets to
the router: it has no recovery function, including for forcibly sent ETH or
unsolicited ERC-20 transfers.

## Choose failure behavior

- `continueOnFailure = false`: the first wallet failure or malformed result
  reverts with `ClaimCallFailed`. Every preceding transfer, sync, accounting
  update and event in the transaction rolls back.
- `continueOnFailure = true`: a failed item returns zero and emits
  `ClaimFailed`; later items are attempted. A successful sync persists when its
  subsequent release fails. Each wallet call is an independent transaction
  subcall, so a malicious contract that returns malformed data successfully can
  retain its own side effects in this mode.

`ClaimFailed` indexes wallet, asset and account. Its data includes schema version
`1`, the zero-based input index, the failed wallet selector, the original return
data length and a bounded reason. Reverted calls retain at most the first 256
bytes of their revert data. No-code targets and successful calls whose results
are not exactly one 32-byte ABI word produce local validation errors instead.
The atomic error carries the same operation, input index and bounded reason.
Revert prefixes can be truncated ABI data; do not blindly decode them as complete
`Error(string)` payloads.

Results are wallet-reported amounts. Code presence and ABI shape are validated;
the router does not authenticate arbitrary wallets or independently prove their
payments. Obtain wallet addresses from the expected factory and inspect the real
wallet release events and balances. Zero is ambiguous: a conformant zero result
and a failed item both occupy zero in the output array. Inspect `ClaimFailed` to
distinguish them. The existing `StreamSplitWallet` reverts when nothing is owed,
so repeated claims produce a failure event in continue mode.

## Discovery and gas

An indexer discovers profiles and their recipients from the expected factory's
`SplitProfileCreated` and `SplitProfileEntry` events, and token receipts from the
asset's `Transfer` events. Filter by emitter, profile and entitled account;
arbitrary event names alone do not authenticate wallets or tokens. Read current
entitlements and active asset policy before submitting a batch. The test suite
constructs a 20-wallet native batch from actual factory events and also exercises
20-wallet ERC-20 aggregation and directly received, previously unsynced tokens.
These tests do not establish an operated indexer, its coverage horizon or the
deployment rehearsal obligation in RSR-CLAIM-ROUTER.6.

Discovery here uses the existing factory ABI: its `SplitProfileEntry` signature
is `(bytes32,uint16,address,uint32,bytes32)`. That earlier event omits the schema
version specified by the full-v1 revenue event sketch. This router does not
change the factory's event ABI or claim to close that separate conformance gap.

There is no fixed batch-size limit or immutable per-wallet gas stipend. In
continue mode each call receives at most current gas divided by the remaining
wallet-call count plus one router share. Sync mode initially budgets two calls
per remaining item; a skipped release does not retain a share. The EVM may
further cap forwarding. Atomic mode forwards available gas subject to EIP-150.

This lets later ordinary wallets complete after an earlier wallet consumes its
entire allocation when the caller supplies enough total gas. It cannot guarantee
completion of an underfunded transaction or of arbitrary recursive wallets.
Estimate the complete batch, keep practical batch sizes, and simulate with the
same mode and gas budget. Nested calls may independently claim other wallets;
each real wallet's own reentrancy guard and accounting prevent double release.
The router holds no shared accounting that a nested batch can corrupt.

This increment adds the contracts and focused real-wallet tests. Registration in
the full-v1 genesis candidate and deployed recipient-experience evidence remain
separate integration work; the previously published Sepolia addresses do not
include this new router.
