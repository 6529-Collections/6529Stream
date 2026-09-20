# Revenue pulls and escrow recovery

These clients prepare initialized split-wallet claims, ClaimRouter batches and
Escrow delivery or incident recovery. They are qualified against ABI107 at
`d88ee108080ba1e66f1b8a9b49e3fd9a59d35c4a`, tree
`8572b46becb1b0207b2313e6371b034e4a5381ee`.

The existing split-factory client still owns profile construction, deterministic
V4 clone verification and wallet-domain release/revocation signing payloads.
The existing revenue client still owns resolver assignments and Artist approvals.
The new clients add the missing pull and recovery workflows. All earlier fixtures
keep their own source and runtime qualifications.

## Caller coverage

All 17 methods below use zero native value. An asset address of zero selects ETH;
it does not make the transaction payable. Direct and Safe calls preserve the
actual caller, exact recipient, ordered input and original signature domain.

| Target | Method | Caller requirement |
| --- | --- | --- |
| Initialized wallet | `syncAsset` | Anyone. |
| Initialized wallet | `release` | Anyone when recipient equals account; the actual account for another recipient. |
| Initialized wallet | `releaseWithAuthorization` | Any relayer with the account's original authorization. |
| Initialized wallet | `revokeReleaseAuthorization` | The account whose nonce is consumed. |
| Initialized wallet | `revokeReleaseAuthorizationBySignature` | Any relayer with the account's original revocation authorization. |
| ClaimRouter | `claimMany` | Anyone; each item pays its named account. |
| ClaimRouter | `syncAndClaimMany` | Anyone; sync and release occur in item order. |
| Escrow | `flushEscrow` | Anyone; delivers to the captured wallet and can deploy it. |
| Escrow | `flushToVerifiedWalletBestEffort` | Anyone; captured wallet must already be deployed. |
| Escrow | `publishEscrowRecoveryManifest` | Anyone; retains the complete original document. |
| Escrow | `executeEscrowRecovery` | Anyone once the recorded recovery requirements hold. |
| Escrow | `submitEscrowRecoveryConsent` | Any relayer with the account's original consent. |
| Escrow | `recordEscrowRecoveryConsent` | The actual consenting account. |
| Escrow | `revokeEscrowRecoveryConsent` | The actual consenting account. |
| Escrow via Executor | `scheduleEscrowRecovery` | Exact class-4 FUNDS_RECOVERY action. |
| Escrow via Executor | `cancelEscrowRecovery` | Exact class-0 action. |
| Escrow via Executor | `authorizeTerminalEscrowRecovery` | Separate exact class-2 TERMINAL_FREEZE action. |

The canonical role-6 address is the locked singleton wallet implementation.
Recipient claims target verified, initialized clones from the intended factory.
Factory-only initialization, runtime-registry setup, producer admission and
credits, and gas administration have separate authority and workflows. Passive
deposits do not create official Escrow credits. There is no arbitrary-recipient
Escrow sweep or Router asset-recovery method.

## Wallet capture and simulation

```js
const prepared = prepareRevenuePullCall(wallet, caller, {
  kind: "release",
  asset,
  account,
  recipient: account,
});
const captured = await captureRevenuePull(provider, deployment, prepared, {
  blockTag,
});
const simulated = await simulateRevenuePull(provider, captured, {
  blockTag: laterBlock,
  gasLimit,
});
```

The deployment description names reviewed factory, implementation, policy,
wallet-profile, Router and token identities as needed. Hashes must come from
reviewed deployment metadata for the stated source. An arbitrary address/hash
pair cannot establish that source's implementation.

Capture reads a concrete block and retains its hash, verified clone/profile,
accounting, asset observation, policy/grace, relevant authorization nonce/domain
and current gas settings. It does not establish signature validity or promise a
future payment. Simulation calls the original method from the exact caller with
an explicit gas limit. State, policy and available gas can change afterward.

Use `splitWalletReleaseTypedData` and
`splitWalletReleaseRevocationTypedData` from the existing split-factory module.
The signature domain names the individual wallet, even though its implementation
and profile are shared with other clones. The signed release binds the entire
current `releasableSnapshot`; a new receipt or another release can invalidate it.
Zero nonces are valid. Deadlines are inclusive, and both release and revocation
consume the account's shared wallet nonce space.

A Safe owner is not the Safe account. An account's direct alternate-recipient
release must originate from that account. Signed release still validates its
signature when the relayer happens to equal the account. ERC-1271 and delegated
EOA authorization stay with the original contract's checks; code presence alone
does not establish who signed.

## Observation, zero amounts and deprecated assets

`syncAsset` can initialize observation at a zero balance. A later unchanged sync
can succeed without an event. A release with zero entitlement reverts. Failed
releases revert the observation, payment accounting and nonce effects too.

ETH bypasses asset policy. ACTIVE tokens remain subject to the original standard
token and accounting checks. A DEPRECATED token can exit indefinitely once that
wallet's observation is initialized. Without initialization, the timestamp must
be strictly earlier than its retained grace deadline. At the deadline itself the
unobserved asset is ineligible. A failed release does not initialize it.

Receipt readbacks describe the state at the receipt block. Event amounts identify
the transaction's payments; block-wide balance differences can also include
other transactions, callbacks or donations. Eventless no-op evidence requires
the necessary prior state instead of attributing an unexplained change to this
call.

Wallet receipt reconciliation verifies the clone and its dependencies at both the
previous block and the receipt block. A clone first deployed during the receipt
block falls outside this receipt profile. Earlier transactions in the same block
can initialize asset observation; that alone does not invalidate a later sync.

## Ordered Router batches

The request contains ordered `{ wallet, asset, account }` items and an explicit
`continueOnFailure` boolean. Repeated items and empty batches retain their original
meaning. The Router pays each account directly and cannot select a different
recipient or retain a caller fee.

With `continueOnFailure: false`, a failure reverts the whole batch, including
earlier payments and syncs. With `true`, earlier successful calls remain and later
items run. In sync mode, a successful sync remains even if that item's release
fails; a failed sync skips its release.

The returned amount array is wallet-reported. Zero can represent an unsuccessful
item or a conformant zero return. Indexed `ClaimFailed` events identify the input
position and failed selector. Their reason may be a truncated revert prefix;
do not decode it as a complete Solidity error without checking its shape.

The verified workflow authenticates the requested wallet profiles and joins
their release events to the original item order. Callback-generated events must
not be silently attributed to another item; ambiguous payment attribution fails
closed. The client accepts at most 64 claim items as an allocation bound. The
protocol itself has no fixed batch limit or promise that every item receives
enough gas.

### Wallet and Router client bounds

This profile accepts at most 64 claims, 64 wallet descriptions and 64 token pins.
Call data, signatures, RPC responses, runtime code and individual log data are
limited to 65,536 bytes; an outer mined transaction can contain 131,072 bytes.
Receipt input is limited to 4,096 logs with at most four topics each. Reused
split-factory helper reads retain their 16,384-byte response limit. These are
client allocation limits, not protocol gas guarantees. Simulation requires an
explicit positive `uint256` gas limit.

## Escrow delivery

An Escrow credit is the exact `(revenueClass, profileId, wallet, asset)` key.
Both flush methods deliver its entire owed amount to the captured wallet,
decrement aggregate liabilities and leave recipient release to that wallet.
Zero-credit and repeated completed flushes revert.

`flushEscrow` applies the current gas floor and can deploy the captured wallet.
`flushToVerifiedWalletBestEffort` requires an existing verified wallet and skips
that deployment path. Its name does not mean that it swallows a failed transfer.
Either method reverts all changes if a late check or transfer fails.

Captured flushing permits ACTIVE or DEPRECATED factory/runtime admission and
rejects INCIDENT_REVOKED admission. It does not reapply new-credit ACTIVE token
admission. A delivered deprecated token may still be unavailable to an individual
recipient if the destination wallet missed its observation grace window.

The escrow workflow has separate capture, exact-call simulation and receipt APIs.
Capture retains the original credit identity, owed amount, aggregate liability,
relevant balances and runtime pins, and validates runtime admission and gas
parameters. Recovery and history
reads preserve their own original admission rules; a failed old factory is not
silently required to regain live code just to describe its retained credit.

Use `prepareRevenueEscrowCall`, `captureRevenueEscrow`,
`simulateRevenueEscrow` and `reconcileRevenueEscrowReceipt` for an operational
call. `inspectRevenueEscrowHistory` reads retained recovery records or manifests
using only the Escrow identity. Keep the reviewed original initialization
metadata in `RevenueEscrowDeployment.origin`; it supplies the original profile
preimage when old code is unavailable.

## Recovery document and consent

Retain the complete original manifest document and its exact reference, including
URI and URI hash. Publication binds the actual entries, successor identity,
amount, route and notice/citation structure. It starts the original notice clock.
Publishing identical content again can be eventless and preserves its first
publication time, including when another valid URI is supplied.

The canonical document establishes three explicit routes:

| Route | Requirement |
| --- | --- |
| 0 | Byte-identical canonical entries. |
| 1 | Current, unrevoked consent from every original recipient whose aggregate share decreases. |
| 2 | Separate terminal authorization and retained notice evidence. |

Labels alone can change without reducing an account's aggregate share. The
client retains exact entries and computes affected accounts from those entries;
a caller-provided count is not a substitute.

Original profile preimages allow recovery when captured old-factory code is
unavailable. The successor must satisfy its current ACTIVE admission and
deterministic profile checks. Recovery moves only funds held by Escrow; it does
not move balances already resident in an old split wallet.

Consent uses the original `6529StreamRevenueEscrow` domain and the exact recovery
ID. Direct consent can be recorded before scheduling, including with nonce zero.
A fresh nonce can record consent again. Revocation changes the current consent
flag and does not restore consumed nonces. These records alone authorize no
transfer.

## Genuine governance stages

Scheduling, cancellation and terminal authorization retain their original
transition getters, classes and Executor action commitments. Publish, schedule
and execute the appropriate governance plan as separate observed stages. A Safe
calling an Escrow governance target directly cannot supply the Executor's
current-action context.

Use `prepareRevenueEscrowGovernanceStage`,
`simulateRevenueEscrowGovernanceStage` and
`reconcileRevenueEscrowGovernanceReceipt` for each outer Executor stage. These
methods bind the target transition, governance nonce, publication, catalog and
action to the prepared operation.

Every recovery schedule is class 4. The recovery document must already have been
published for at least 14 days. Route 2 also requires a distinct class-2 action
at least 72 hours after actual Escrow scheduling. Preparing a plan earlier does
not advance either clock. An executed governance schedule and an executed funds
recovery remain separate facts.

Execution rechecks the exact owed amount, incident, successor admission, document,
route and current consents/actions. Every late failure rolls back debits,
deployment and recovery status. Normal native flushing requires exact balance
deltas; native incident recovery allows additional donated ETH while retaining
owed-funds conservation. ERC-20 recovery keeps the original exact sender and
receiver delta checks.

## Direct and Safe evidence

Use `createSafeCallPlan` for an already prepared ordinary CALL. Governed target
calldata belongs in its actual Executor plan; only the proper outer stage becomes
the Safe's ordinary CALL.

Reconciliation requires the exact mined transaction, receipt, canonical block,
relevant target events and retained state. Safe mode additionally requires an
independently obtained Safe transaction hash and its matching success event.
Both indexed and non-indexed success layouts are supported. A successful outer
receipt or an event with the right name from another address is insufficient.

Escrow receipts require the retained observations to match the preceding block,
then check the exact target events and end-of-block credit, consent or recovery
state. Concurrent transactions can prevent this conservative reconciliation even
when the requested transaction succeeded. Its result explicitly reports
`exact-prior-and-end-block` attribution; it does not isolate arbitrary changes
within a block.

### Escrow client bounds

Escrow calls, RPC responses and individual log data are limited to 2 MiB. Receipt
input permits at most 4,096 logs, four topics per log and 8 MiB of aggregate log
data. Outer transaction data and retained governance-publication code permit
2 MiB plus 16,384 bytes; pinned runtime code permits 131,072 bytes. The client
accepts at most 64 successor-factory pins and 1,024 elements per document array;
original split-entry arrays retain their 64-entry limit. URIs are limited to
2,048 UTF-8 bytes and signatures to 65,536 bytes. Simulation requires an explicit
positive gas limit no greater than 100,000,000. These client limits do not prove
that a call fits actual transaction, block or nested-call gas limits.

These are client checks against retained ABIs and mocked RPC behavior. They do
not prove deployed-code correspondence, current native contract/Safe execution,
whole-transaction gas admission or release readiness. Recovery source-credit
citations, historical collection completeness, Artist binding and actual notice
delivery remain external operational evidence. The committed structure and
timestamps do not establish transaction inclusion or actual delivery.

The [whole-v1 inventory](current-v1-safe-coverage.md) retains its earlier ABI102
source. This ABI107 caller profile has its own fixture and evidence.
