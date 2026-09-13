# Split-wallet signed releases and deprecated-asset exits

This guide describes the wallet-version-3 implementation. It requires a newly
deployed factory and wallets; it does not change existing deployed wallets or the
published supported release candidate. Integration and deployment records must name
the actual factory, wallet version and compiler output they use.

## Claim to the entitled account

Anyone, including a Safe, can call `release(asset, account, account)`. The funds
always go to the entitled account. The account itself can call
`release(asset, account, recipient)` to choose another recipient. For a Safe payee,
this means the Safe executes the call through `execTransaction`; a call from one
of its owners is not a call from the Safe.

The [claim router](claim-router.md) batches release-to-self calls without holding
funds or accepting approvals. Safe callers can use both router methods, and Safe
payees can receive native ETH or an approved standard ERC-20 through either the
wallet or router. Zero entitlement reverts with `NoReleasableFunds`; use the
router's documented continue mode when individual empty claims are expected.

## Authorize an exact release to another recipient

Read `releasable(asset, account)` immediately before constructing the authorization.
Sign this exact EIP-712 type:

```text
StreamReleaseAuthorization(address asset,address account,address recipient,uint256 releasableSnapshot,bytes32 nonce,uint64 deadline)
```

The domain is `name = "6529StreamSplitWallet"`, `version = "1"`, the current
chain ID, and `verifyingContract = the individual wallet`. `domainSeparator()`,
`eip712Domain()` and `releaseAuthorizationDigest(authorization)` expose the
onchain values. The asset, account, recipient, full releasable amount, 32-byte
nonce and inclusive deadline are signed. This is not permission to release a
chosen partial amount.

Any relayer can submit
`releaseWithAuthorization(authorization, signature)`. The wallet observes current
receipts and computes the full releasable amount before validating the snapshot.
A new receipt, another claim or a changed balance can invalidate the quote.
`ReleaseSnapshotMismatch` leaves the nonce and funds unchanged. A failed
signature, transfer or post-transfer accounting check likewise rolls back the
nonce, observation and release accounting. Successful calls emit the same
`NativeReleased` or `ERC20Released` payment event as direct claims.

Nonces are scoped to the signer account inside each wallet. Check
`isReleaseAuthorizationNonceUsed(account, nonce)`; a successful release or
revocation consumes the nonce permanently. The deadline is valid at the exact
timestamp and expired afterward. Native and token releases share this nonce space.

The payee can revoke directly with `revokeReleaseAuthorization(nonce)`, or sign:

```text
StreamReleaseAuthorizationRevocation(address account,bytes32 nonce,uint64 deadline)
```

The revocation uses the same wallet domain and is submitted through
`revokeReleaseAuthorizationBySignature(account, nonce, deadline, signature)`.
`releaseRevocationDigest` exposes its digest. The event
`ReleaseAuthorizationRevoked(account, nonce, schemaVersion)` uses schema version 1.
Expiry never restores a consumed nonce. A different account cannot revoke the
payee's nonce by calling the direct method.

## Safe signatures and calls

Contract signatures are validated through ERC-1271 with no EOA signature-length
restriction. The tested official Safes are 1.3.0, 1.4.1 and 1.5.0 with their
CompatibilityFallbackHandler and a 2-of-3 owner threshold. That handler validates
the Safe's `SafeMessage(bytes message)` digest where `message` is
`abi.encode(walletDigest)`. Owner signatures over the Stream digest alone are
insufficient. Use a Safe-aware signing implementation and the actual Safe domain.

The official `SignMessageLib`, executed by the Safe with delegatecall, can approve
that exact message onchain. A later relayer can then submit an empty signature.
An unapproved empty signature fails. Tests cover this for both release and
revocation; they also check insufficient owner proofs, wrong signed fields,
replay, and actual payment and nonce effects.

Canonical own-key ECDSA remains valid for an EIP-7702 delegated EOA, alongside its
contract-signature path. EOA signatures accept canonical 65-byte and compact
64-byte forms, enforce low `s`, and do not confer authority on a Safe owner.

The selector tests execute all wallet, factory and policy views through a real
Safe, with a separate comparison of returned read values. They exercise all
permissionless and payee write selectors and both router methods. Wallet
initialization is factory-only; a direct Safe call is rejected. Policy updates
and gas raises require the configured governance executor, so a direct Safe call
to those targets is also rejected. An authorized Safe must use the normal delayed
governance route. Target-side mocked execution contexts in domain tests do not
prove the real Executor's scheduling delay.

Always inspect the protocol event/state as well as Safe execution status. A Safe
transaction's outer receipt alone is not evidence that its inner operation
succeeded.

## Token status and exit grace

Native ETH does not consult the asset policy registry. For ERC-20s, the wallet
uses the factory's pinned registry and applies these rules:

| Status | Existing split-wallet release or sync |
| --- | --- |
| ACTIVE | Allowed, subject to standard-token and accounting checks |
| DEPRECATED, observation already initialized | Allowed indefinitely, including later passive receipts |
| DEPRECATED, observation not initialized | Allowed only while `block.timestamp < assetReleaseGraceUntil(asset)` |
| UNKNOWN, INACTIVE or UNSUPPORTED | Rejected for that token |

An explicit successful observation at a zero balance counts as initialized.
Initialization during grace also preserves the exit after grace. At the exact
grace timestamp an unobserved wallet is ineligible. An unsuccessful release does
not initialize observation because the transaction rolls back. Deprecation does
not authorize new sales: callers requiring ACTIVE status continue to reject it.

The registry's four-argument setter is
`setAssetStatus(asset, status, policyHash, releaseGraceUntil)`. Its four-value
`assetPolicy(asset)` view includes the grace timestamp. Updates require a
class-1 executing governance action whose scope and old/new state hashes match
`assetPolicyTransitionHashes`. Revisions prevent an old authorization from
becoming valid again after a state returns to previous values.

Every deprecation must provide at least 180 days from its execution timestamp.
Grace may never decrease, including across intermediate ACTIVE, INACTIVE,
UNSUPPORTED or UNKNOWN states. A non-deprecation update preserves the previous
grace exactly. Policy changes emit the prior/new status and policy hash, actual
effective time, retained grace, action ID, executor address and schema version 1.
This implementation has no separate immediate policy-update path.

## Deployment and verification budgets

The registry constructor takes the governance executor address. The factory
constructor takes the registry, the governance executor, and exactly three ordered
`GasParameterConfig` rows: `ERC_1271_GAS_LIMIT`, `ASSET_POLICY_GAS_LIMIT`, and
`WALLET_DEPOSIT_GAS_LIMIT`, all
`FAIL_CLOSED_PRECHECK`. The executor must already expose its canonical authority
and current-action interfaces when these contracts are constructed.

Wallets fetch current gas budgets from that factory. There is no fixed fallback
cap. Governance can raise them only through the existing class-1, at-most-2x,
monotonic gas-parameter host rules. Registry reads and ERC-1271 validation use
their separate caps, exact 32-byte return shapes and an outer-gas admission
check. Invalid, oversized or insufficiently funded reads fail closed. Asset
status and release grace are separate reads; the four-word `assetPolicy` result
is not decoded under a one-word allowance.

Domain tests use genesis budgets of 400,000 and 30,000, with floors of 350,000
and 15,000 respectively. These are explicit fixture configuration values. The
tests include heavy contract signers, an actual budget raise and all three
official Safe versions; their gas observations include fixture access warmth.
They do not replace a fully cold, release-specific gas admission measurement.
The factory-wide `WALLET_DEPOSIT_GAS_LIMIT` row is registered. Its consumer
migrations and all-cold release sizing remain separate work; see
[split profiles](split-profiles.md) for that row's explicit planning inputs and
deferred wallet deployment.

The factory links `StreamSplitWalletDeployment` to keep its deployed runtime
within EIP-170. Library delegatecall preserves the factory as the CREATE2 deployer
and the wallet constructor's caller. Tests bind the predicted address, creation
hash, deployed runtime, initialized profile and wallet version. A Safe can read
the library's two hash methods; direct Safe calls to its delegatecall-only
deployment method are rejected. The tested factory route performs that
deployment. Deployment tools
must link this library before predicting the factory's wallets; do not reuse a
version-2 profile or runtime receipt as proof for version 3.
