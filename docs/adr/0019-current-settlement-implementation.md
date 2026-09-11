# ADR 0019 implementation decision: single-step ERC-20 settlement

This addendum specifies the first executable universal settlement increment.
It is under implementation and independent review; it does not relabel the
[historical ADR 0019 packet](0019-payment-intent-orchestration.md) or claim that
its prepared, custody, public-sale, batch, and freeze requirements are complete.
The integrator owns reconciliation of the canonical ADR after this review.

## Authority and first consumer

The call sequence is contract 20 (payer adapter), the registered sale adapter,
contract 9 (official recorder), then the one authorized funding return to 20.
Contract 20 is the sole first allowance puller. Contract 9 alone resolves the
primary assignment, selects/materializes concrete rights, routes received
funds, consumes the official settlement key, and records official totals.
Only 9 is an escrow producer. The sale adapter retains commercial signatures,
authorization replay, its durable sale program, and per-execution mint state.

The first concrete consumer is a signed fixed-price, one-token
`PRE_REVENUE_SINGLE_STEP` sale. Its orchestration wire value is 1; signed
authority is 1. Other values reject. It uses an explicit collection
`PRIMARY_SALE` assignment, policy mode 0 (strict), and no token override
(`tokenId = 0` before mint). Contract 9 can resolve the already supported
concrete PROFILE/TEMPLATE forms; the first sale consumer admits only PROFILE.
The existing native/ERC-20 adapters and V2 auction keep their existing APIs.
In particular, a fixed V2 auction's creation-time concrete rights are retained.

The replacement contract 9's ERC-20 interface has only the typed
`settleERC20PrimarySaleFromAdapter(paymentAdapter,candidate)` entry. The old
allowance-pulling `settleERC20PrimarySale(PrimarySale,address)` selector
`0x9e6dc442` and its caller allowlist do not authorize this graph. Native
settlement admission is a separate surface; it cannot authorize ERC-20 pulls.

## Typed transcript and preimages

[StreamPrimarySettlementTypes](../../smart-contracts/interfaces/stream/revenue/StreamPrimarySettlementTypes.sol)
owns the exact tuple layouts. The candidate includes the sale adapter,
executor, eleven-field `PrimarySale`, immutable four-field lifecycle binding,
four-field execution binding, asset, order, actual manager, manager operation
root **and the one exact token operation ID**, current and signed-bound mint
policy hashes, five concrete rights fields, and `keccak256(saleExecutionData)`.
Concrete rights are profile, wallet, template, assignment and entries hashes.
They are independently derived by contract 9, never destination authority
granted to contract 20 or its caller.

All preimages below use `abi.encode`; each label denotes its `keccak256` hash:

```text
candidateCommitment = keccak256(abi.encode(
  "6529STREAM_ERC20_SETTLEMENT_CANDIDATE_V2",
  chainId, paymentAdapter, recorder, entireCandidateTuple))

executionId = keccak256(abi.encode(
  "6529STREAM_ERC20_SALE_EXECUTION_V1", chainId, saleAdapter,
  sale.settlementId, sale.payer, executor, executionNonce, authorityMode,
  saleAuthorizationDigest, currentPolicyHash, boundPolicyHash, operationRoot))

settlementKey = keccak256(abi.encode(
  "6529STREAM_PRIMARY_SETTLEMENT_KEY_V2", chainId, recorder,
  saleAdapter, executionId))
```

The new candidate domain distinguishes the expanded tuple from the provisional
V1 candidate in ADR 0019. The execution preimage preserves that ADR's atomic
identity. A replay cannot reopen the official key by changing policy, asset,
amount, payer or destination while retaining the authenticated execution ID.
The sale adapter additionally binds `(saleId, executionNonce)` once to that
exact ID and consumes the commercial authorization nonce independently.
Changing a field that participates in `executionId` therefore cannot create a
second accepted execution for the same authenticated nonce. Both uniqueness
boundaries are checked before funding; a mapping keyed only by the recomputed
ID is insufficient. The full context is committed and validated separately.
This single-result key is not a proposed batched or custody key.
A future canonical purchase-ID mode must explicitly adopt its existing ID,
not silently substitute this atomic derivation.

The sale adapter independently recomputes the digest from its typed sale
authorization, checks the signed executor against `candidate.executor`, and
reconstructs a canonical execution payload. Trailing bytes and alternative
encodings reject. It previews the actual manager as the manager's caller,
checks both returned identities and the full candidate, and creates its
execution record before calling 9. The sale program remains repeatable.
After official funding it mints once and requires the actual root and exactly
one operation ID to equal the preview. No scalar root substitutes for that ID.

## Admission and bounded reads

Contracts 9 and 20 each pin Core, the canonical module registry, resolver and
factory deployment line and code identities. Explicit constructor pins avoid
a genesis pointer-installation cycle; every operation subsequently requires
the actual Core `MODULE_REGISTRY` pointer to select the pinned registry/code.
A stored pointer status is not a substitute for reading live module status.

Each boundary independently checks both the sale and payment module's live
record: exact role, supported version, served interface, runtime code hash,
nondelegated deployed code and lifecycle. The version label for this new
profile is `6529STREAM_UNIVERSAL_SETTLEMENT_V1`; role labels are
`FIXED_PRICE_SALE_ADAPTER` and `ERC20_PRIMARY_SETTLEMENT_ADAPTER`.
Only ACTIVE or DEPRECATED records can serve existing bindings. For each
DEPRECATED module separately, creation time must precede status-change time
and creation revision must precede its current revision. Unknown and
INCIDENT_REVOKED always reject. Creation requires both modules ACTIVE.

This addendum authorizes a narrow lifecycle-read exception: after checking
exact pinned Core/registry code, read the Core pointer and the canonical
registry record with available gas and fixed output buffers; after authenticating
the sale module, read `saleLifecycleBinding(bytes32)` the same way.
There is no arbitrary selector/target or allocated/bubbled remote returndata.
The Core result is exactly 320 bytes. Registry decoding copies only its fixed
448-byte header, checks canonical offsets, widths and full URI-tail length,
and does not copy the URI. Lifecycle output is exactly 128 bytes with canonical
address/uint64 words. Failed or malformed reads fail closed. The lifecycle
surface is caller-insensitive, immutable after sale creation, and returns all
zeroes for an unknown sale. Zero/future timestamps and invalid revisions reject.
This is not an uncapped exception for tokens, signatures or arbitrary modules.

Deployment-line identity reads retain their trusted-code treatment: the pinned
factory's `gasParameter` and authority, canonical registry's governance executor,
and admitted modules' `primarySaleSettlement`, `core`, `moduleRegistry`,
`revenueResolver` and `mintManager` getters use exact one-word results where
read by the bounded helper. Constructor marker and typed resolver/factory
identity checks also remain explicit. These reads cannot select an arbitrary
callee; their targets are the pinned deployment line or the independently
admitted sale/payment module. Asset and permit-policy reads use the separate
governed asset-read budget; token calls and Stream signatures have their own
current governed budgets.
The three exact ERC-165 probes on a code-authenticated module retain the
canonical registry's existing available-gas, exact-32-byte read convention.
They require ERC-165 and the served interface, and reject `0xffffffff` support;
DEPRECATED admission cannot use the registry's ACTIVE-only eligibility shortcut.

## Funding phase and rollback

Contract 20 locks before its first external read or signature verification:

```text
IDLE -> LOCKED -> AUTHENTICATED -> SALE_CALLBACK
     -> FUNDING -> FUNDED -> callback returns -> IDLE
```

Its active context commits the candidate, exact top-level selector/funding
mode, typed permit input hash, expected recorder, key, asset, payer and amount.
Only that recorder may call `fundERC20PrimarySale`, only in SALE_CALLBACK,
and only with exact active fields. The transition to FUNDING precedes permit
or token code. It cannot be invoked twice or nested through a token, permit,
Safe signature or receiver. Every other mutator, including revocation,
requires IDLE. The legitimate funding return is explicitly phase-gated,
not disabled by a blanket nonReentrant modifier.

A verified PaymentIntent consumes the payer-scoped nonce before the sale
callback. Direct payer and permit entries require payer = executor = actual
`msg.sender` and do not synthesize intent events. The intent and revocation
domain/type strings remain exactly ADR 0019's payer-verifier domain; the
factory supplies the current governed ERC-1271 cap, with no local writer or
fallback cap. Canonical own-key ECDSA remains possible for delegated EOAs;
contract signatures have no 65-byte restriction.

The recorder checks admission and ACTIVE asset independently, selects and
materializes exact rights, consumes its key, and then requests funding.
Every payer -> 20 -> 9 -> wallet/escrow hop checks both exact balance deltas.
Both 20 and 9 must finish with their original surplus unchanged. A failed
bounded direct-wallet CALL can use escrow; successful false/malformed/no-op/
fee responses revert the entire transaction. An empty verified template
prediction receives escrow only. Wrong-code predictions reject.

The recorder returns exactly 384 bytes. The sale callback returns exactly
416 bytes: its exact selector as ABI bytes4 magic plus that twelve-word result.
Contract 20 compares the complete result with its active fields and the
recorder's stored result, proves one completed funding call, and only then
clears the lock. Any later failure reverts mint, registration, transfers,
escrow, official totals, execution and intent replay together.

## Permit capability and exact calls

[IStreamAssetPermitPolicy](../../smart-contracts/interfaces/stream/revenue/IStreamAssetPermitPolicy.sol)
adds explicit class-1 governed attestation, independently of ACTIVE status.
Bits 1/2 mean canonical EIP-2612/pinned Permit2 SignatureTransfer. The record
binds asset runtime, asset policy hash and revision; any policy revision makes
it stale until reattested. Permit2 also binds its target/runtime and an exact
allowance model: every finite allowance decreases by the spend; mode 1 also
decrements uint256.max, while mode 2 preserves uint256.max. Zero bits revoke.
The adapter separately pins the supported Permit2 deployment/runtime/chain;
the asset registry cannot select a different target through this record.

Permit authorization never substitutes for sale authorization or relayed
Stream payment consent. Both permit entries are payer-called only and execute
the permit inside the single authorized FUNDING phase, after commercial checks:

- EIP-2612 constructs `permit(payer,20,amount,deadline,v,r,s)`. It requires
  exact allowance `amount` afterward and zero after the exact payer pull.
  No arbitrary permit bytes or selector are forwarded.
- Permit2 constructs the single `permitTransferFrom` with token/amount exactly
  from the candidate, destination 20, requested amount equal to the charge,
  owner equal to the actual payer, and typed nonce/deadline/signature. It
  checks the real unordered nonce bit and exact token/allowance deltas.
  It creates no allowance and does not use AllowanceTransfer, batches or witness
  entry points. Preexisting payer approval to Permit2 is still required.

The integrator accepts this narrow third-party authorization distinction:
the exact EIP-2612 and Permit2 operations live in the linked, stateless
`StreamPermitExecution` library. Deploy and link that library before contract 20.
Delegatecall preserves contract 20 as the spender and destination; direct library
calls reject. Contract 20 retains its single funding latch, locked permit mode,
live capability/code/chain checks, authenticated input hash and all balance
accounting. The library exposes no arbitrary selector or approval operation.

For gas accounting,
the entire pinned Permit2 call uses the current factory
`WALLET_DEPOSIT_GAS_LIMIT`, with EIP-150 admission and atomic failure. Official
Permit2 controls its inner Safe/ERC-1271 call and offers no Stream cap argument.
This does not establish an exact inner stipend or literal full RSR-1271.1
conformance. Direct Stream intent, revocation and commercial signature calls
still use the exact current factory `ERC_1271_GAS_LIMIT`. Actual Safe/official
Permit2 tests must cover sufficient and insufficient governed whole-call budgets.

The recorder keeps the current normative RSR context event ABI, including both
operation root and operation ID. A separate schema-1 `PrimaryRevenueExecutionBound`
event joins that key to the authenticated executor, payment adapter, execution ID,
candidate commitment and current/bound policy pair. This supersedes the historical
ADR packet's provisional proposal to insert those fields into the context event.

EIP-2612's usual EOA verification is not claimed to validate a Safe. Actual Safe
coverage uses direct approval plus execution, the Stream ERC-1271 intent path,
and the pinned official Permit2 ERC-1271 path. Sources:
[ERC-2612](https://eips.ethereum.org/EIPS/eip-2612) and
[official Permit2 SignatureTransfer](https://developers.uniswap.org/docs/protocols/permit2/concepts/signature-transfer).

## Acceptance and subsequent slices

Acceptance requires real money, replay/domain and phase attacks, malformed
return/revert bombs, lifecycle transitions, callback policy drift, Safe
execution/signatures and exact official event accounting. Domain tests and
current-Core integration are reported separately. Governed planning caps are
not an all-cold collector gas-budget result.

Prepared mint, custody/refundable settlement, batches, public-sale authority,
native contract-9 orchestration, universal template sale admission, recovery,
and all-cold ceilings remain explicit follow-ups. Template auctions need
separate settlement-time payout resolution and failure/refund semantics;
existing fixed V2 auctions retain their creation-time rights.
