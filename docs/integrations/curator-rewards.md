# Curator Rewards

This document is the integration flow spec for curator reward claims through
`StreamCuratorsPool`. It is for React, mobile, Electron, indexer, operator UI,
and backend reward-service teams that need to show reward eligibility, submit
claims, surface withdrawable curator credits, and reconcile curator-pool
accounting.

The repository remains a pre-audit local baseline. It is not production-ready
and this document is not a security claim. Local evidence does not replace
fork/testnet/live evidence required for public beta or production release.

Use this with the integration source-of-truth entrypoint in
[`docs/integrations/README.md`](README.md), the event/indexer guide in
[`docs/integrations/events-and-indexing.md`](events-and-indexing.md), the
operator guide in [`docs/integrations/operator-admin-ui.md`](operator-admin-ui.md),
and the release dashboard in
[`docs/release-readiness.md`](../release-readiness.md).

## Maturity And Scope

This page documents the current checked local contract behavior for curator
reward claims and withdrawals.

It covers:

- reward Merkle root publication by authorized admins;
- domain-separated `abi.encode` reward leaf hashing;
- root epoch handling and stale-proof rejection;
- direct curator claims and delegated claims;
- pull-payment curator credits;
- curator credit withdrawal UX;
- failed withdrawal and zero-recipient handling;
- forced ETH and emergency surplus boundaries;
- events, indexer reconstruction, and frontend state transitions.

It does not provide production curator reward data, production delegation
policy, production admin ceremony evidence, reviewed testnet/live root
publication, or final frontend implementation readiness. Those remain governed
by [`docs/non-local-release-evidence.md`](../non-local-release-evidence.md),
[`docs/public-beta-evidence.md`](../public-beta-evidence.md), and
[`release-artifacts/latest/public-beta-evidence.json`](../../release-artifacts/latest/public-beta-evidence.json).

## Curator Reward Overview

The curator reward flow is:

1. A reward service computes reward leaves for a collection and root epoch.
2. An authorized function admin calls `setMerkleRoot` or
   `setMultipleMerkleRoots` on `StreamCuratorsPool`.
3. The pool increments `collectionMerkleRootEpoch(collectionId)` and emits
   `MerkleRootUpdated`.
4. A curator or authorized delegate submits
   `claimRewards(collectionId, amount, merkleProof, delegator)`.
5. The pool verifies the leaf against the current `collectionMerkleRoot`,
   rejects duplicate/stale/wrong proofs, marks the reward claimed, and creates
   `curatorCredits(rewardAddress)`.
6. The curator withdraws with `withdrawCuratorCredit()` or
   `withdrawCuratorCreditTo(recipient)`.
7. Indexers reconcile `Reward`, `CuratorCreditCreated`,
   `CuratorCreditWithdrawn`, `MerkleRootUpdated`, and the owed/surplus views.

Claims are pull-payment based. A successful claim does not push ETH to the
curator; it creates withdrawable credit. This is intentional because rejecting
recipients and reentrancy attempts must not block reward accounting.

## Source Of Truth

Use tracked generated artifacts and checked docs, not hand-maintained copies.

| Need | Source of truth | Integration note |
| --- | --- | --- |
| Integration entrypoint | [`docs/integrations/README.md`](README.md) | Starts frontend, mobile, Electron, indexer, operator UI, and signing-service discovery |
| Event/indexer model | [`docs/integrations/events-and-indexing.md`](events-and-indexing.md) | Event subscriptions, read-after-event calls, and reconstruction guidance |
| Operator UI model | [`docs/integrations/operator-admin-ui.md`](operator-admin-ui.md) | Admin ceremony and monitoring surfaces |
| Release readiness | [`docs/release-readiness.md`](../release-readiness.md) | Current launch blocker dashboard |
| Public beta evidence | [`docs/public-beta-evidence.md`](../public-beta-evidence.md) | Public beta gate evidence |
| Non-local evidence boundary | [`docs/non-local-release-evidence.md`](../non-local-release-evidence.md) | Retained fork/testnet/live evidence requirements |
| Risk register | [`release-artifacts/latest/risk-register.json`](../../release-artifacts/latest/risk-register.json) | Generated blocker and risk source |
| Release manifest | [`release-artifacts/latest/release-manifest.json`](../../release-artifacts/latest/release-manifest.json) | Generated source-of-truth manifest |
| ABI review surface | [`release-artifacts/baselines/v0.1.0/abi-surface.json`](../../release-artifacts/baselines/v0.1.0/abi-surface.json) | Tracked ABI baseline |
| ABI checksums | [`release-artifacts/latest/abi-checksums.json`](../../release-artifacts/latest/abi-checksums.json) | Integrator checksum source |
| Event topic catalog | [`release-artifacts/latest/event-topic-catalog.json`](../../release-artifacts/latest/event-topic-catalog.json) | Indexer event signature source |
| Interface IDs | [`release-artifacts/latest/interface-ids.json`](../../release-artifacts/latest/interface-ids.json) | Interface lookup source |
| Local address book | [`deployments/address-books/anvil-6529stream-v0.1.0-001.json`](../../deployments/address-books/anvil-6529stream-v0.1.0-001.json) | Local development addresses |
| Fork-mainnet address book | [`deployments/address-books/fork-mainnet-6529stream-v0.1.0-001-broadcast.json`](../../deployments/address-books/fork-mainnet-6529stream-v0.1.0-001-broadcast.json) | Retained fork rehearsal addresses |
| Curator pool contract | [`smart-contracts/StreamCuratorsPool.sol`](../../smart-contracts/StreamCuratorsPool.sol) | Reward root, claim, credit, withdrawal, and emergency logic |
| Admin contract | [`smart-contracts/StreamAdmins.sol`](../../smart-contracts/StreamAdmins.sol) | Function admin and emergency recipient source |
| Delegation interface | [`smart-contracts/IDelegationManagementContract.sol`](../../smart-contracts/IDelegationManagementContract.sol) | Delegated claim lookup surface |
| Pause domains | [`smart-contracts/StreamPauseDomains.sol`](../../smart-contracts/StreamPauseDomains.sol) | Emergency domain naming |
| Curator pool tests | [`test/StreamCuratorsPool.t.sol`](../../test/StreamCuratorsPool.t.sol) | Claim, delegated claim, failed withdrawal, leaf hash, root epoch, and emergency surplus behavior |
| Payment invariant tests | [`test/StreamPaymentsInvariant.t.sol`](../../test/StreamPaymentsInvariant.t.sol) | Cross-payment owed/surplus invariant baseline |

## Artifact Inputs

An app or indexer needs these inputs before showing curator reward actions:

- chain ID from the connected wallet or indexer environment;
- `StreamCuratorsPool` address from the selected address book;
- `StreamCuratorsPool` ABI from a local `forge build` output or generated
  package;
- event topics from `event-topic-catalog.json`;
- current `collectionMerkleRoot(collectionId)`;
- current `collectionMerkleRootEpoch(collectionId)`;
- reward amount and Merkle proof from the reward service;
- claimant address and optional delegator address;
- delegation status when claiming on behalf of a delegator;
- current `curatorCredits(account)`;
- `rewardsClaimPerAddress(collectionId, account)`;
- `totalCuratorOwed()`, `totalOwed()`, `surplus()`, and
  `emergencyWithdrawable()`;
- current release evidence boundary from public beta and production blocker
  docs.

Raw ABIs under ignored `out/` are local build products. For committed review,
use `release-artifacts/baselines/v0.1.0/abi-surface.json`,
`release-artifacts/latest/abi-checksums.json`,
`release-artifacts/latest/event-topic-catalog.json`, and
`release-artifacts/latest/interface-ids.json`.

## Root And Leaf Model

Each reward root is collection-scoped and epoch-scoped:

- `collectionMerkleRoot(collectionId)` stores the active root;
- `collectionMerkleRootEpoch(collectionId)` increments every time a root is
  set for that collection;
- `MerkleRootUpdated(collectionId, rootEpoch, merkleRoot)` emits the new epoch
  and root.

Reward leaves are domain-separated and encoded with `abi.encode`:

```solidity
keccak256(
    bytes.concat(
        keccak256(
            abi.encode(
                CURATOR_REWARD_LEAF_DOMAIN,
                block.chainid,
                address(this),
                collectionId,
                rewardAddress,
                amount,
                rootEpoch
            )
        )
    )
)
```

The domain is `CURATOR_REWARD_LEAF_DOMAIN`, currently
`keccak256("6529Stream.StreamCuratorsPool.curatorRewardLeaf.v2")`.

The leaf binds:

- chain ID;
- deployed curator pool address;
- collection ID;
- reward address;
- amount;
- root epoch.

Do not use `abi.encodePacked` for reward leaves. The checked contract path and
tests expect `abi.encode` with explicit domain fields. Duplicate leaves,
wrong claimant, wrong collection, wrong amount, stale root epoch, and double
claims must fail without consuming the claim or creating credit.

## Claim Preflight Reads

Before submitting a claim, read:

| Read | Why |
| --- | --- |
| `collectionMerkleRoot(collectionId)` | Confirms the reward service proof targets the active root |
| `collectionMerkleRootEpoch(collectionId)` | Binds the proof to the current epoch |
| `hashRewardLeaf(rewardAddress, collectionId, amount, rootEpoch)` | Lets clients verify the leaf matches the reward service output |
| `rewardsClaimPerAddress(collectionId, rewardAddress)` | Prevents duplicate-claim UI |
| `rewardsPerAddress(collectionId, rewardAddress)` | Shows already recorded reward amount |
| `curatorCredits(rewardAddress)` | Shows withdrawable credit |
| `totalCuratorOwed()` and `totalOwed()` | Reconciles owed balances |
| `surplus()` and `emergencyWithdrawable()` | Confirms pool funding above owed obligations |
| Delegation status | Required when `_delegator` is non-zero |

For delegated claims, `rewardAddress` is the delegator, not the wallet
submitting the transaction. The delegate pays gas and calls the contract, but
credit is created for the delegator.

## Claim Transaction

Submit:

```solidity
StreamCuratorsPool.claimRewards(
    collectionId,
    amount,
    merkleProof,
    delegator
)
```

Use `delegator = address(0)` for a direct curator claim. Use a non-zero
delegator only when the delegation contract confirms the caller is authorized
for the curator reward use case.

On success:

- `rewardsPerAddress(collectionId, rewardAddress)` is set to `amount`;
- `rewardsClaimPerAddress(collectionId, rewardAddress)` becomes `true`;
- `curatorCredits(rewardAddress)` increases by `amount` when amount is non-zero;
- `totalCuratorOwed()` increases by `amount` when amount is non-zero;
- `CuratorCreditCreated` is emitted for non-zero amount;
- `Reward` is emitted for every successful claim.

The contract requires enough `emergencyWithdrawable()` surplus to cover the
new claim. An unfunded claim fails before consuming the claim.

## Delegated Claims

Delegated claims use the external delegation management contract. The pool
queries:

```solidity
retrieveGlobalStatusOfDelegation(
    delegator,
    0x8888888888888888888888888888888888888888,
    msg.sender,
    1
)
```

The constants are:

- delegation collection: `0x8888888888888888888888888888888888888888`;
- curator reward use case: `1`.

If delegation is not allowed, the claim fails with `No delegation`. If it is
allowed, the reward leaf, claim-consumed flag, credit, and withdrawal ownership
all use the delegator address.

Frontend copy should make this explicit: the connected delegate wallet submits
the claim, but the delegator receives the withdrawable credit.

## Credits And Withdrawals

Withdraw:

```solidity
StreamCuratorsPool.withdrawCuratorCredit()
StreamCuratorsPool.withdrawCuratorCreditTo(recipient)
```

Current withdrawal rules:

- credit belongs to `msg.sender`;
- `recipient` may differ from the credit owner;
- `recipient` must not be zero;
- credit must be non-zero;
- the contract zeroes credit and decrements `totalCuratorOwed()` before the ETH
  transfer, but a failed transfer reverts the whole transaction and preserves
  credit;
- `CuratorCreditWithdrawn(owner, recipient, amount)` is emitted on success.

A failed withdrawal should remain retryable. The UI should show the preserved
credit and let the owner retry with a payable recipient.

## Events And Indexing

Indexers should watch:

- `MerkleRootUpdated(collectionID, rootEpoch, merkleRoot)`;
- `Reward(account, collectionID, amount)`;
- `CuratorCreditCreated(account, collectionID, funds)`;
- `CuratorCreditWithdrawn(account, recipient, funds)`;
- `EmergencyWithdrawal(admin, recipient, domain, funds, resultingSurplus)`;
- legacy `Withdraw(account, status, funds)` for emergency-withdraw compatibility.

Recommended projection fields:

- collection ID;
- current root;
- current root epoch;
- reward address;
- claimed flag;
- reward amount;
- curator credit;
- total curator owed;
- total owed;
- surplus;
- emergency withdrawable;
- last root update transaction;
- last claim transaction;
- last withdrawal transaction.

Use events for history, but re-read `rewardsClaimPerAddress`,
`curatorCredits`, `totalCuratorOwed`, `surplus`, and
`emergencyWithdrawable` after each claim, withdrawal, root update, or emergency
action.

## Failure States

| Failure | Client classification |
| --- | --- |
| Missing root | Operator/reward-service state; wait for `MerkleRootUpdated` |
| Stale root epoch | Terminal stale proof; request a new proof |
| Invalid proof | Terminal proof error |
| Wrong collection leaf | Terminal proof or payload mismatch |
| Wrong claimant leaf | Terminal wallet or delegation mismatch |
| Wrong amount leaf | Terminal amount mismatch |
| Duplicate claim | Terminal already-claimed state |
| Unfunded claim | Operator funding state; do not mark claimed |
| Missing delegation | Terminal delegated-claim authorization error |
| Zero recipient withdrawal | User input error |
| No credit withdrawal | Terminal no-balance state |
| Failed ETH withdrawal | Retry with a payable recipient; credit is preserved |
| Emergency surplus withdrawn | Reconcile owed funds remain covered |

Do not auto-retry with mutated collection, amount, claimant, root epoch, or
proof fields. Any mutation requires a new reward-service proof.

## Frontend State Machine

Suggested UI states:

| UI state | Contract source |
| --- | --- |
| `unconfigured` | No address book or curator pool ABI for the chain |
| `wrong-chain` | Connected chain does not match the reward proof chain |
| `loading-root` | Reading `collectionMerkleRoot` and `collectionMerkleRootEpoch` |
| `no-root` | Root is zero or reward service has no current proof |
| `proof-ready` | Proof, amount, reward address, and root epoch match |
| `delegation-required` | `_delegator` is non-zero and delegation status is unknown |
| `ready-to-claim` | Not claimed, funded, proof valid, delegation valid |
| `claim-submitted` | Claim transaction pending |
| `credit-available` | `curatorCredits(account) > 0` |
| `withdraw-submitted` | Withdrawal transaction pending |
| `withdrawn` | Credit is zero and withdrawal event observed |
| `failed-retryable` | Failed withdrawal, wallet rejection, or network issue |
| `failed-terminal` | Invalid proof, stale epoch, duplicate claim, or missing delegation |

Indexers can display history, but transaction buttons should re-read contract
state directly before submission.

## Operator And Admin Boundaries

Only authorized function admins can update roots:

- `setMerkleRoot(collectionId, merkleRoot)`;
- `setMultipleMerkleRoots(collectionIds, roots)`.

Operator UI should require:

- collection IDs and roots are length-matched;
- every root update records the intended root epoch;
- the reward service can reproduce the leaf list;
- roots and proof-generation inputs are retained without secrets;
- root publication is not described as public beta or production evidence
  unless reviewed non-local evidence exists.

Emergency withdrawal is surplus-only:

- `totalOwed()` equals `totalCuratorOwed()`;
- `totalReserved()` returns zero in the current pool;
- `surplus()` is contract balance above owed funds;
- `emergencyWithdrawable()` equals `surplus()`;
- emergency withdrawal must not withdraw curator credits.

## Validation Commands

Run these when editing this flow:

```sh
python scripts/test_curator_rewards_flow.py
python scripts/check_curator_rewards_flow.py
python scripts/test_integrations_readme.py
python scripts/check_integrations_readme.py
python scripts/test_release_readiness.py
python scripts/check_release_readiness.py
python scripts/check_changelog.py
```

Useful focused Solidity coverage for curator rewards:

```sh
forge test --match-path test/StreamCuratorsPool.t.sol
forge test --match-path test/StreamPaymentsInvariant.t.sol
```

For release artifact drift after doc/checker updates:

```sh
python scripts/generate_release_manifest.py --check
python scripts/generate_bytecode_release_proof.py --check
python scripts/generate_release_checksums.py --check
```

## Maintenance

Refresh this document and `scripts/check_curator_rewards_flow.py` whenever:

- curator pool ABI, events, delegation constants, root handling, or credit
  behavior changes;
- reward leaf encoding changes;
- delegation policy or reward-service proof format changes;
- event topic catalog or ABI artifact names move;
- `INT-005` adds a more complete event replay model for curator rewards; or
- release evidence graduates from local baseline to reviewed fork, testnet, or
  live evidence.

Keep this guide conservative. It should help builders implement curator
rewards against the current local baseline without weakening the repo's
pre-audit and not-production-ready boundary.
