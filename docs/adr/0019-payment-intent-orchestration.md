# ADR 0019: Payer-Bound ERC-20 Settlement Orchestration

## Status

Proposed for issue
[#664](https://github.com/6529-Collections/6529Stream/issues/664).

The interface and state-machine sketches in this draft are provisional while
coordinator and independent security review is active. They are not an accepted
or frozen protocol ABI. This ADR must be accepted before implementation begins.

This ADR resolves an implementation-blocking ambiguity between the permanent
`PaymentIntent` verifier rules and the current primary-sale settlement
foundation. It does not claim that the adapter, sale adapters, revenue escrow,
deployment candidate, or release evidence exists.

## Problem

The genesis architecture assigns two different roles:

- genesis inventory contract `20`, the ERC-20 primary-settlement adapter, is
  the `PaymentIntent` verifier and sole protocol pull initiator; it either pulls
  through the asset directly or invokes the separately reviewed pinned Permit2
  branch; and
- genesis inventory contract `9`, `StreamPrimarySaleSettlement`, resolves
  primary revenue, consumes settlement keys, routes revenue, and records
  official settlement, but must not pull the payer's allowance.

The current implementation does not preserve that split.
`StreamPrimarySaleSettlement.settleERC20PrimarySale` is both the official
revenue recorder and the contract that calls `transferFrom(payer, ...)`.
No contract `20` implementation exists.

Moving signature verification in front of the current contract `9` call is not
enough. The no-signature exemption in `[RSR-PAYMENT-INTENT].5` requires the
top-level verifier initiating the pull to observe `payer == msg.sender` in the
settlement call frame. A downstream verifier called by a sale adapter would
observe the sale adapter, not the payer. Treating contract `9` as the verifier
would contradict `[RSR-DOMAINS].2`.

The missing seam is security-sensitive. A generic callback, `delegatecall`,
multicall, arbitrary target/selector, or loosely bound byte payload could turn
the payment adapter into an execution router. Pulling before the sale adapter
has validated its mode-specific sale authority could make invalid sale data
observable
to a callback asset. Letting the payment adapter write revenue or escrow state
would duplicate the accounting authority of contract `9`. Adding an operation
identifier here would also collide with issue
[#688](https://github.com/6529-Collections/6529Stream/issues/688), which owns the
batch operation-root and prepared-mint replay ABI.

The first paid-mint profile therefore needs one top-level payer boundary and
two narrow, phase-gated mint callbacks whose complete authority and rollback
behavior are fixed before code lands. The separately required
`CUSTODY_SETTLEMENT_TRANSFER` path remains outside this first profile.

## Current Behavior

The merged `StreamPrimarySaleSettlement` foundation:

1. allowlists settlement callers;
2. validates the supplied `PrimarySale` and active asset policy;
3. resolves or materializes the primary revenue assignment;
4. consumes its settlement key;
5. pulls the ERC-20 directly from `sale.payer`;
6. transfers the ERC-20 to the resolved split wallet; and
7. records official counters and settlement events.

The foundation has no `PaymentIntent` domain, signature verification,
signer-scoped replay store, intent revocation, revenue-escrow fallback, or
top-level sale-adapter orchestration. Its `PrimarySale` struct also names the
numeric adapter-local sale nonce `saleId`, while the accepted mapping gives
`saleId` to the `bytes32 settlementId` and calls the numeric field
`saleNonce`.

These facts are useful implementation evidence, not a conformant genesis
boundary. The target removes the legacy
`settleERC20PrimarySale(PrimarySale,address)` ABI entirely. Its current selector
`0x9e6dc442` must be absent, and contract `9` must have no fallback or alternate
entry through which a native settlement caller can cause a payer allowance
pull. Leaving the selector callable-but-discouraged would preserve the exact
bypass contract `20` is intended to close.

## Decision

### 1. Contract 20 Is The Only ERC-20 Payer Boundary

Genesis inventory contract `20` is the top-level entry for every official
ERC-20 primary settlement covered by this first paid-mint profile. It:

- exposes the permanent
  `("6529StreamPaymentIntentVerifier", "1", chainId, address(this))`
  EIP-712 domain and ERC-5267 introspection;
- verifies payer authorization before any sale-adapter, resolver,
  materialization, escrow, mint, or token-transfer effect;
- owns signer-scoped `PaymentIntent` nonce consumption and revocation;
- is the sole protocol payer boundary and initiator of every allowed payer
  pull;
- calls the asset's `transferFrom(payer, ...)` itself on direct and EIP-2612
  funding paths, while the pinned Permit2 SignatureTransfer contract performs
  that token call on the separately specified Permit2 path; and
- temporarily receives the exact pulled amount before funding contract `9`.

Contract `9` is not an EIP-712 verifier and receives no standing payer
allowance.

The provisional shared structs are:

```solidity
struct PaymentIntent {
    address payer;
    address asset;
    uint256 maxAmount;
    bytes32 saleRef;
    bytes32 expectedPrimaryPolicyHash;
    bytes32 nonce;
    uint64 deadline;
}

struct SaleLifecycleBinding {
    address paymentAdapter;
    uint64 saleCreatedAt;
    uint64 saleAdapterRegistryRevision;
    uint64 paymentAdapterRegistryRevision;
}

struct SaleExecutionBinding {
    bytes32 executionId;
    uint256 executionNonce;
    uint8 authorityMode;
    bytes32 saleAuthorizationDigest;
}

struct ERC20SettlementCandidate {
    address saleAdapter;
    address executor;
    IStreamPrimarySaleSettlement.PrimarySale sale;
    SaleLifecycleBinding lifecycleBinding;
    SaleExecutionBinding executionBinding;
    address asset;
    uint8 orchestrationOrder;
    bytes32 operationIdentityCommitment;
    bytes32 currentPolicyHash;
    bytes32 boundPolicyHash;
    bytes32 saleExecutionHash;
}

struct PrimarySettlementResult {
    bytes32 candidateCommitment;
    bytes32 settlementKey;
    bytes32 profileId;
    address wallet;
    address asset;
    uint256 amount;
    address executor;
    bytes32 executionId;
    bool escrowed;
    bytes32 operationIdentityCommitment;
    bytes32 currentPolicyHash;
    bytes32 boundPolicyHash;
}
```

`saleExecutionHash` is `keccak256(saleExecutionData)`. The provisional
candidate commitment is:

```solidity
keccak256(
    abi.encode(
        STREAM_ERC20_SETTLEMENT_CANDIDATE_V1,
        block.chainid,
        address(this),
        candidate.saleAdapter,
        candidate.executor,
        candidate.sale,
        candidate.lifecycleBinding,
        candidate.executionBinding,
        candidate.asset,
        candidate.orchestrationOrder,
        candidate.operationIdentityCommitment,
        candidate.currentPolicyHash,
        candidate.boundPolicyHash,
        candidate.saleExecutionHash
    )
)
```

where:

```solidity
STREAM_ERC20_SETTLEMENT_CANDIDATE_V1 =
    keccak256("6529STREAM_ERC20_SETTLEMENT_CANDIDATE_V1");
```

`orchestrationOrder` is one of `PRE_REVENUE_SINGLE_STEP` or `PREPARED_MINT`.
For both orders, `operationIdentityCommitment` is the exact nonzero
ADR-0018 `operationRoot`. `PRE_REVENUE_SINGLE_STEP` takes it from the
manager-owned preview and compares it with the manager's execution return;
`PREPARED_MINT` carries the root established by the manager/ledger prepared
path. A token-scoped settlement additionally carries the corresponding exact
per-token `operationId` through its typed callback, settlement, result, and
event surfaces. This ADR does not redefine either preimage or create a parallel
replay namespace. The provisional field name remains subject to the final ABI
freeze, but its value cannot be zero, locally re-hashed, or lossily re-encoded.

The imported single-step preview ABI is exact:

```solidity
function previewSingleStepMintOperation(
    MintBatch calldata batch,
    bytes calldata gateData
) external view returns (
    bytes32 operationRoot,
    bytes32[] memory operationIds
);
```

Its selector is `0xa5651f13`, derived from
`previewSingleStepMintOperation((uint256,bytes32,address,address,address[],address[],bytes[],bytes32[],bytes32,bytes32,bytes32,bytes),bytes)`.
The sale adapter calls this manager-owned view before any sale execution record,
sale-authorization consumption, settlement-key consumption, deposit, payer
pull, or mint effect. The manager therefore observes the adapter itself as
`msg.sender` and binds that address as executor; it never binds the adapter's
external caller, payer, relayer, or `tx.origin`. The preview invokes the
configured gate and resolvers from the manager, reads the current
`nextOperationNonce`, and uses byte-identical normalization and identity
derivation with execution. It is `STATICCALL`-safe, emits and writes nothing,
consumes no replay state, and returns exactly `batch.beneficiaries.length`
operation IDs.

`currentPolicyHash` and `boundPolicyHash` import ADR 0018's policy
identity boundary without changing its ownership:

- `boundPolicyHash` is exactly `MintBatch.expectedPolicyHash`, accepted for
  both configured and ungated paths only when it equals the current registered
  mint-policy hash or the exact unexpired immediate predecessor with adjacent
  revision. A second rotation invalidates the older predecessor.
- `currentPolicyHash` is the live hash independently recomputed by the
  manager and loaded by the ledger for the exact manager, collection, and
  phase. It alone controls artist consent, live mint modules and gate
  evaluation, counter policies, caps, and increments.
- The `operationRoot` commits `currentPolicyHash` and then
  `boundPolicyHash`. The manager preview returns the root and token
  operation IDs, not either hash separately; the candidate commits the two
  exact identities used by that preview and execution.
- A predecessor-bound request authorizes continuity only. It does not revive
  predecessor economics or consent, bypass current modules or gates, weaken
  current caps, revive a deprecated sale/payment adapter, or substitute for
  the independently current approved-asset and primary-revenue policies.
- With a configured gate, the normalized result requires
  `GateResult.authorizationId == MintBatch.authorizationId`,
  `GateResult.authorizer == MintBatch.authorizer`, and an authorizer kind valid
  for that same address; the gate's signed payload and validated result bind
  `MintBatch.expectedPolicyHash`. Without a gate, normalized authorizer,
  authorizer kind, maximum quantity, and gate hash are exactly
  `(address(0), AuthorizerKind.NONE, 0, bytes32(0))`; `MintBatch.authorizer` is
  zero and canonical nullifiers are empty. Ungated execution never infers an
  authorizer or kind from caller, payer, account code, or phase data.
  `MintBatch.authorizationId` remains explicit and nonzero in both cases; an
  ungated path consumes that request value and never infers it from the root,
  context, or presentation bytes.

These mint-policy fields are distinct from
`sale.expectedPrimaryPolicyHash`, which remains the exact primary-revenue
policy identity. No participant may substitute one policy namespace for the
other. The candidate fields are comparison evidence, not caller authority:
the manager still recomputes current policy, the ledger still loads it from the
registered manager/collection/phase tuple, and the sale adapter rejects any
preview or execution whose root and returned identities do not match the
candidate.

The complete `PrimarySale` tuple is part of the commitment. The exact
sale-adapter address, authenticated top-level executor, sale reference, payer,
asset, charged amount, expected primary-policy hash, policy mode,
collection/token context, revenue class, poster, beneficiary, adapter-local
sale-program nonce, per-execution identity and nonce, authority mode, signed
authorization digest or its required zero value, paid-mint order, final #688
operation root, current and bound mint-policy identities, and callback payload
are therefore immutable throughout one operation.

`sale.settlementId` and `sale.saleNonce` identify the durable sale program.
They are not a purchase replay key and are never consumed or terminally closed
merely because one purchase succeeds. `executionBinding.executionId` identifies
one purchase/settlement attempt and keys a separate adapter-owned execution
record. `executionBinding.executionNonce` is nonzero, adapter-issued, monotonic,
and never reused for the same `(saleId, payer)` pair.

The provisional authority modes are:

```text
SIGNED_SALE_AUTHORIZATION = 1
PUBLIC_SALE_RECORD        = 2
```

For `SIGNED_SALE_AUTHORIZATION`, `saleAuthorizationDigest` is the exact nonzero
digest recomputed by the sale adapter. For `PUBLIC_SALE_RECORD`, it is zero:
the active immutable sale record declares public execution and is the authority,
so no synthetic or reusable authorization digest exists. The public mode is
valid only when the top-level entry observes
`msg.sender == candidate.sale.payer == candidate.executor`; a payer
`PaymentIntent` that binds only the permanent fields is not a full-purchase
authorization for a relayer.

The provisional atomic-execution preimage is:

```solidity
keccak256(
    abi.encode(
        STREAM_ERC20_SALE_EXECUTION_V1,
        block.chainid,
        candidate.saleAdapter,
        candidate.sale.settlementId,
        candidate.sale.payer,
        candidate.executor,
        candidate.executionBinding.executionNonce,
        candidate.executionBinding.authorityMode,
        candidate.executionBinding.saleAuthorizationDigest,
        candidate.currentPolicyHash,
        candidate.boundPolicyHash,
        candidate.operationIdentityCommitment
    )
)
```

where `STREAM_ERC20_SALE_EXECUTION_V1` is
`keccak256("6529STREAM_ERC20_SALE_EXECUTION_V1")`. For an atomic execution with
no canonical sales-spec `purchaseId`, the resulting value must equal
`candidate.executionBinding.executionId`. A mode with an existing canonical
`purchaseId` instead requires `executionId == purchaseId` and forbids the atomic
preimage from creating a parallel namespace. Before ADR 0019 can be accepted,
ADR 0018 / issue #688 and the revenue settlement-key/event reconciliation must
pin how the final typed operation identity carries either branch. This
provisional key must not be implemented as an independent manager/ledger/Core
replay namespace.

The provisional top-level entries are deliberately separate:

```solidity
function settleERC20PrimarySaleByPayer(
    ERC20SettlementCandidate calldata candidate,
    bytes calldata saleExecutionData
)
    external
    returns (PrimarySettlementResult memory result);

function settleERC20PrimarySaleWithIntent(
    ERC20SettlementCandidate calldata candidate,
    PaymentIntent calldata intent,
    bytes calldata signature,
    bytes calldata saleExecutionData
)
    external
    returns (PrimarySettlementResult memory result);
```

The direct entry requires
`msg.sender == candidate.sale.payer`. The signed entry requires the exact
`PaymentIntent` bindings:

- `intent.payer == candidate.sale.payer`;
- `intent.asset == candidate.asset`;
- `candidate.sale.amount <= intent.maxAmount`;
- `intent.saleRef == candidate.sale.settlementId`; and
- `intent.expectedPrimaryPolicyHash ==
  candidate.sale.expectedPrimaryPolicyHash`.

Both entries require `candidate.executor == msg.sender`, nonzero values where
the normative structs require them,
`keccak256(saleExecutionData) == candidate.saleExecutionHash`, an active
approved-standard asset, and a registered sale-adapter candidate whose
lifecycle permits this exact sale. The direct and payer-called permit entries
therefore require `candidate.executor == candidate.sale.payer`; a relayed
signed-intent entry may use a different executor only under
`SIGNED_SALE_AUTHORIZATION`, when that exact address is candidate-committed and
authorized by the signed sale surface. `PUBLIC_SALE_RECORD` always requires the
same top-level payer-is-caller equality, including if a caller selects the
`settleERC20PrimarySaleWithIntent` selector. A non-payer relayer presenting a
valid `PaymentIntent` with public mode fails before mutation.
Contract `20` also requires a nonzero execution ID and execution nonce, one of
the two exact authority modes, the mode-correct zero/nonzero authorization
digest, and exact recomputation of the provisional execution preimage before
its first external read or call.
There is no entry that infers the payer from `tx.origin`, a sale-adapter
caller, or arbitrary callback data.

### 2. Paid-Mint Callbacks Are Fixed, Order-Specific, And Single-Use

For a transaction that mints against ERC-20 payment in this first profile,
contract `20` calls exactly one of two provisional selectors on exactly
`candidate.saleAdapter` after payer authorization succeeds:

```solidity
function executeERC20PreRevenueSingleStep(
    ERC20SettlementCandidate calldata candidate,
    bytes calldata saleExecutionData
) external returns (bytes4 magic, PrimarySettlementResult memory result);

function executeERC20PreparedMint(
    ERC20SettlementCandidate calldata candidate,
    bytes calldata saleExecutionData
) external returns (bytes4 magic, PrimarySettlementResult memory result);
```

The required magic is the selector of the exact function called. The first
selector requires `orchestrationOrder == PRE_REVENUE_SINGLE_STEP` and the exact
nonzero operation root returned by the ADR-0018 manager preview. The second
requires `orchestrationOrder == PREPARED_MINT` and the exact nonzero operation
root established by the ADR-0018 prepared path. Both require the root's exact
current/bound mint-policy identities.

The target must have the sale-adapter module type, expected interface, and
matching runtime code registered under `[SSA-REGISTRY]`. Registry lifecycle is
preserved:

- `ACTIVE` accepts new sale configuration and settlement;
- `DEPRECATED` rejects new sale configuration but continues settlement of an
  immutable sale record created before deprecation;
- `INCIDENT_REVOKED`, unknown, mismatched-runtime, or mismatched-interface
  adapters fail closed for state-changing settlement.

Contract `20` must not simplify this to an `ACTIVE`-only execution check.
For a `DEPRECATED` adapter, the callback must prove from its immutable sale
record that the exact `candidate.sale.settlementId` existed before the
deprecation transition. Every sale record, whether its current module status is
`ACTIVE` or `DEPRECATED`, stores the exact `SaleLifecycleBinding` copied into
`candidate.lifecycleBinding`. The candidate commitment therefore binds:

- the exact contract-`20` `paymentAdapter`;
- the immutable nonzero `saleCreatedAt`; and
- the nonzero sale-adapter module-registry revision observed at sale creation;
  and
- the nonzero payment-adapter module-registry revision observed at sale
  creation.

The sale adapter, contract `20`, and contract `9` independently require the
candidate binding to equal the immutable sale record byte-for-byte, require
`lifecycleBinding.paymentAdapter` to equal the top-level contract `20`, and
compare both creation revisions with the corresponding current canonical
module records. For `ACTIVE` records, each creation revision must be nonzero and
no greater than its current module-record revision. A missing or zero field, a
future revision, a future `saleCreatedAt`, or a substituted payment adapter
fails closed.

When the sale adapter's current module record is `DEPRECATED`, all three
participants additionally require:

```solidity
candidate.lifecycleBinding.saleCreatedAt
    < moduleRecord(candidate.saleAdapter).statusUpdatedAt;
candidate.lifecycleBinding.saleAdapterRegistryRevision
    < moduleRecord(candidate.saleAdapter).revision;
```

When the payment adapter's current module record is `DEPRECATED`, all three
participants independently require:

```solidity
candidate.lifecycleBinding.saleCreatedAt
    < moduleRecord(paymentAdapter).statusUpdatedAt;
candidate.lifecycleBinding.paymentAdapterRegistryRevision
    < moduleRecord(paymentAdapter).revision;
```

If both modules are deprecated, both pairs of inequalities apply. An equal
timestamp or revision does not prove pre-deprecation creation and fails closed.
Registry status and live code/interface facts for both modules are checked
again in the settlement transaction.

The lifecycle binding is observable through one narrow provisional
registered-sale-adapter interface:

```solidity
interface IStreamSaleLifecycleBinding {
    function saleLifecycleBinding(bytes32 settlementId)
        external
        view
        returns (SaleLifecycleBinding memory binding);
}
```

The function selector and single-function ERC-165 interface ID are both
provisionally `0x2b022c4e`. A conforming sale adapter returns only the immutable
record stored for that exact `settlementId`; an unknown ID returns the all-zero
binding and therefore fails closed. The registered sale-adapter module profile
must attest this interface and exact runtime code before either caller trusts
the read.

After payer authorization, module-registry authentication, and live
code/interface validation, but before the sale callback or asset pull, contract
`20` performs the read and requires exact equality with
`candidate.lifecycleBinding`. Before consuming the settlement key, resolving
revenue, or requesting funds, contract `9` independently repeats the same read
from `candidate.saleAdapter` and requires the same equality. Inside the typed
callback, the sale adapter independently compares the candidate binding with
its own immutable storage before any sale effect or contract-`9` call.

Both external observers first authenticate the sale adapter's canonical module
record, exact runtime code hash, and lifecycle interface. They then use the
proposed exact-code trusted-infrastructure exception: a zero-value `staticcall`
with the exact 36-byte `abi.encodeCall` calldata forwards available gas, writes
into a fixed 128-byte output buffer, and accepts only success with
`returndatasize() == 128` and canonical decoding. They never allocate, decode,
or bubble arbitrary returndata. The provisional local error classes are:

```solidity
error SaleLifecycleBindingReadFailed(address saleAdapter, bytes32 settlementId);
error SaleLifecycleBindingMalformed(
    address saleAdapter,
    bytes32 settlementId,
    uint256 returndataLength
);
error SaleLifecycleBindingMismatch(
    address saleAdapter,
    bytes32 settlementId
);
```

Revert or target out-of-gas uses `SaleLifecycleBindingReadFailed`; any return
length other than 128 uses `SaleLifecycleBindingMalformed`; and a zero, stale,
future,
equal-deprecation-boundary, or otherwise unequal decoded binding uses
`SaleLifecycleBindingMismatch`. Every case reverts the complete settlement.

The lifecycle read proposes no new or overloaded GGP. It is not yet an accepted
extension of `[RSR-GGP].6`, whose current explicit uncapped exception is the
pinned factory parameter fetch. Before ADR 0019 can be accepted, the revenue
spec must normatively authorize this exact-code, interface-authenticated
sale-adapter read, and issue #669's external-call inventory must classify both
contract-`20` and contract-`9` consumers, caller-insensitivity, forwarded-gas
behavior, bounded copy/decode, failure direction, and reentrancy posture.
Issue #684 remains a prerequisite for the actual `ERC_1271_GAS_LIMIT`,
`ASSET_POLICY_GAS_LIMIT`, and other existing governed payment/revenue calls,
not a source of a convenience cap for this proposed exception. ADR 0019 does
not edit either issue's owned surfaces.

The call has zero native value. Contract `20` does not accept a target,
selector, call array, gas-forwarding mode, or delegatecall flag from calldata.
The callback interface has no fallback dispatch and cannot invoke an arbitrary
function through contract `20`.

The bytes carry only the concrete sale adapter's one documented ABI type for
that callback. Their hash is part of the candidate commitment. Every concrete
adapter must decode the complete value, reject trailing or malformed data,
reconstruct the same candidate from sale and execution state, and validate all
sale-side fields before requesting settlement.

The authority branches are explicit:

- `SIGNED_SALE_AUTHORIZATION` requires a complete
  `SaleAuthorization` presentation, recomputes its exact nonzero digest,
  requires equality with `executionBinding.saleAuthorizationDigest`, and
  requires `candidate.executor` to equal both the signed
  `SaleAuthorization.executor` and the immutable sale configuration's
  permitted executor;
- `PUBLIC_SALE_RECORD` rejects any authorization presentation or nonzero
  authorization digest, requires the immutable sale record to declare the
  public/no-per-buyer-authorization path, treats that record and the registered
  adapter's phase-executor authority as the sale authority, independently
  requires the active top-level context to prove
  `msg.sender == payer == candidate.executor`, and binds the exact payer,
  executor, recipients, beneficiaries, quantity, price, and policy facts into
  the unique execution record. It does not invent or consume a reusable
  `SaleAuthorization` digest. A relayer cannot derive purchase authority from a
  permanent `PaymentIntent` that omits executor, execution ID, recipients,
  beneficiaries, and quantity.

Inside the callback `msg.sender` is contract `20`, not the original executor;
the adapter authenticates the original executor only through the active
candidate commitment that contract `20` proved against its top-level
`msg.sender`. A value merely claimed in `saleExecutionData` is not authority,
and no path reads `tx.origin`. The typed
`PREPARED_MINT` payload must carry and recompute the exact ADR-0018 operation
identity; hashing that identity out of the payload, substituting a local
operation ID, or accepting an unbound generic byte suffix is nonconformant.

At its order-specific settlement point, the sale adapter calls contract `9`
directly and exactly once:

```solidity
PrimarySettlementResult memory result =
    primarySaleSettlement.settleERC20PrimarySaleFromAdapter(
        msg.sender,
        candidate
    );
```

Inside this sale-adapter callback, `msg.sender` is the payment adapter
(contract `20`). Contract `9` observes and records the real sale adapter as its
own `msg.sender`, preserving `[RSR-SALE-AUTH].4`, the existing
`settlementCaller`/context-event semantics, and the sale-adapter registry
lifecycle. Contract `20` exposes no
`settleValidatedERC20PrimarySale` or equivalent sale-adapter-callable
settlement entry.

The sale adapter owns a separate sale-side checks-effects-interactions and
replay boundary. On callback entry it acquires its non-reentrant operation lock
before any external signature or authorization verification. After every sale,
price, payer, recipient, policy, deadline, lifecycle, and mode-specific
authority check succeeds, it rechecks the durable sale program and unique
execution ID. Before the first downstream contract-`9`, manager, ledger, Core,
token, or receiver call, it atomically:

1. creates an execution record keyed by
   `candidate.executionBinding.executionId`, binding the durable sale ID,
   execution nonce, payer, executor, authority mode, candidate commitment,
   operation root, current and bound mint-policy identities, and the
   mode-correct authorization digest;
2. marks only that execution record `SETTLEMENT_IN_PROGRESS`;
3. for `SIGNED_SALE_AUTHORIZATION` only, consumes the exact verified
   authorization digest in its append-only adapter-scoped store and emits the
   existing canonical
   `SaleAuthorizationConsumed(1, saleId, authorizationDigest, authorizer)`;
4. for `PUBLIC_SALE_RECORD`, requires a zero authorization digest and writes no
   authorization-consumption fact; and
5. emits the provisional execution-scoped event:

```solidity
event SaleExecutionStatusChanged(
    uint16 schemaVersion,
    bytes32 indexed saleId,
    bytes32 indexed executionId,
    bytes32 indexed operationRoot,
    bytes32 currentPolicyHash,
    bytes32 boundPolicyHash,
    uint8 previousStatus,
    uint8 newStatus,
    bytes32 reasonHash
);
```

with `(1, saleId, executionId, operationRoot, currentPolicyHash,
boundPolicyHash, UNSET, SETTLEMENT_IN_PROGRESS, candidateCommitment)`.

The durable sale program remains active after this effect. Its `saleId`,
sale-program nonce, immutable configuration, lifecycle binding, and ordinary
open/close semantics are unchanged. Repeatable fixed-price and open-edition
programs can therefore create multiple unique execution records. Sold-quantity
or fairness counters may advance under the sale's existing rules, but a
purchase does not terminally close the program unless its separately specified
supply, time, cancellation, or manual-close rule does so.

Any bounded external verification needed to finish the checks occurs under the
already-acquired non-reentrant lock. After the final local-state recheck, no
external interaction of any kind occurs until all mode-appropriate sale-owned
effects and events above are written.

The exact provisional sale-side errors are:

```solidity
error SaleExecutionIdentityInvalid(bytes32 executionId);
error SaleExecutionAlreadyExists(bytes32 executionId);
error SaleExecutionAuthorityModeInvalid(uint8 authorityMode);
error SaleAuthorizationAlreadyConsumed(
    bytes32 saleId,
    bytes32 authorizationDigest
);
error SaleExecutionStateMismatch(
    bytes32 executionId,
    uint8 expectedStatus,
    uint8 actualStatus
);
```

Replay or reentry fails at this boundary before another downstream call. Only
after the exact contract-`9` result and the required mint completion have both
succeeded may the adapter change that execution record
`SETTLEMENT_IN_PROGRESS -> SETTLED` and emit
`SaleExecutionStatusChanged(1, saleId, executionId, operationRoot,
currentPolicyHash, boundPolicyHash, SETTLEMENT_IN_PROGRESS, SETTLED,
settlementKey)`. It does not emit a terminal `SaleStatusChanged` for the durable
program. Any downstream revert removes the execution record, restores any
signed-authorization consumption and sale-specific counters, and rolls back
every execution/authorization event.

The two callback orderings are distinct:

```text
PRE_REVENUE_SINGLE_STEP
  -> validate the immutable sale/payment/executor inputs needed to construct the
     exact MintBatch and gateData, without writing an execution record or
     consuming sale authorization
  -> sale adapter calls manager preview selector 0xa5651f13; manager observes
     the adapter as msg.sender, validates current/bound policy identity,
     configured GateResult equality or exact ungated normalization, and all
     canonical gate/resolver results
  -> require nonzero preview root equal to the candidate operation root and
     exactly N nonzero, pairwise-distinct operationIds; retain the full vector
     for the later execution comparison
  -> finish sale state, signed-or-public authority, price, payer, authenticated
     top-level executor, asset, amount, recipients, unique execution
     identity/nonce, and deadline validation
  -> create and mark only the unique execution SETTLEMENT_IN_PROGRESS;
     consume/emit SaleAuthorization only on the signed branch
  -> call contract 9 directly with the calling payment adapter and candidate
  -> contract 9 authenticates caller + payment adapter and calls contract 20
     fundERC20PrimarySale exactly once
  -> contract 9 routes and records official revenue
  -> call manager, ledger, and Core single-step mint
  -> require the manager return to match the exact previewed root and the full
     operationIds vector byte-for-byte; verify the exact contract-9 result,
     mark the execution SETTLED, and emit its terminal status without closing
     the durable sale program
  -> return the pre-revenue callback magic and exact contract-9 result

PREPARED_MINT
  -> validate the same sale/payment/executor/authority/execution facts and exact
     ADR-0018 operation root plus current/bound mint-policy identity
  -> create and mark only the unique execution SETTLEMENT_IN_PROGRESS;
     consume/emit SaleAuthorization only on the signed branch
  -> call manager and ledger
  -> Core prepare establishes authoritative token identity
  -> write every required resolver/royalty snapshot against that identity
  -> call contract 9 directly with the calling payment adapter and candidate
  -> contract 9 authenticates caller + payment adapter and calls contract 20
     fundERC20PrimarySale exactly once
  -> contract 9 routes and records official revenue
  -> Core completes the exact prepared mint
  -> verify exact contract-9 result, mark the execution SETTLED, and emit its
     terminal status without closing the durable sale program
  -> return the prepared-mint callback magic and exact contract-9 result
```

`PREPARED_MINT` funding before Core prepare or before required resolver
snapshots is nonconformant. `PRE_REVENUE_SINGLE_STEP` manager, ledger, or Core
minting before official revenue settlement is nonconformant. Contract `20`
rejects missing or malformed callback return data, the other order's magic, no
funding callback, a returned settlement key different from the key accepted
during funding, or a result that differs from contract `9`'s recorded result
for that key. Any preview failure, configured-gate mismatch, ungated
normalization mismatch, nonce/policy/gate/resolver race, manager root mismatch,
or operation-ID length/value/order mismatch reverts the whole transaction and
leaves no execution record, authorization consumption, settlement, payment, or
mint effect.

The seam introduces no new `operationRoot`, per-token `operationId`,
mint-ledger replay key, or prepared-mint replay rule. It imports and binds the
ADR-0018 identity byte-for-byte; all derivation and replay semantics remain
owned by issue #688 and the mint-policy specification. It also cannot narrow
ADR 0018 into an ungated-current-only rule: configured and ungated settlement
paths accept the same current-or-valid-immediate-predecessor bound identity,
while all live consent, module, gate, counter, and cap decisions remain current.

### 3. Contract 9 Authenticates Replaceable Contract-20 Instances

Contract `20` immutably pins the already-deployed contract `9`. Contract `9`
does not constructor-pin, one-time-bind, owner-allowlist, or otherwise store a
singleton contract `20`. Mutual constructor pinning creates a
future-address/CREATE2 fixed point, while a permanent contract-`9` singleton
would contradict role `20`'s `Replaceable` lifecycle and strand existing sales
after a reviewed adapter successor.

The direct sale-adapter call passes the payment adapter that invoked the typed
callback. Contract `9` authenticates that address through the canonical module
registry on every settlement. The provisional entry is:

```solidity
function settleERC20PrimarySaleFromAdapter(
    address paymentAdapter,
    ERC20SettlementCandidate calldata candidate
)
    external
    returns (PrimarySettlementResult memory result);
```

Contract `9` requires `msg.sender == candidate.saleAdapter`. It recomputes the
candidate commitment using `paymentAdapter` as the contract-`20`
domain/address, requires
`paymentAdapter == candidate.lifecycleBinding.paymentAdapter`, independently
reads and verifies the complete lifecycle binding from the authenticated sale
adapter against the candidate and both current module records, requires the exact
role-20 module type, interface, version, and registered runtime code hash,
verifies
`paymentAdapter.primarySaleSettlement() == address(this)`, and verifies the
same revenue resolver, split factory, asset-policy registry, chain, and
deployment line. Unknown, mismatched-code, mismatched-interface, and
`INCIDENT_REVOKED` instances fail closed.

`ACTIVE` sale- and payment-adapter instances may serve eligible active sale
records. A `DEPRECATED` sale adapter may finish only a sale created before its
own deprecation transition. A `DEPRECATED` role-20 instance may finish only a
sale already bound to that verifier/domain before its separate transition.
Neither deprecated module can be selected for a new sale or binding. Every
path passes the same candidate-committed `SaleLifecycleBinding`; each
deprecated module applies its own strict timestamp/revision pair specified
above. Replacement adds a new registry-authenticated contract-20 instance and
new sales bind that instance; it does not mutate contract `9` or the EIP-712
domain of old intents.

Native settlement authorization remains structurally separate. Contract `9`
keeps a native-only caller policy for approved native sale adapters. ERC-20
settlement requires both the real sale adapter caller and the registry-
authenticated payment adapter committed above; neither native authorization
nor a raw owner allowlist satisfies it.

The legacy `settleERC20PrimarySale(PrimarySale,address)` selector
`0x9e6dc442` is removed from the interface and implementation. Calling it
reverts through the absence of a matching selector; it is never forwarded to
the new entry. Contract `9`:

1. validates the sale-adapter caller, payment adapter, complete candidate, and
   active asset;
2. rejects a consumed settlement key;
3. verifies the candidate's operation root plus current/bound mint-policy
   identities, resolves or materializes the exact primary assignment, and
   independently enforces the expected primary-revenue policy hash/mode;
4. consumes the settlement key under checks-effects-interactions;
5. snapshots its own asset balance;
6. requests exactly the committed funds from the authenticated
   `paymentAdapter`;
7. verifies that its own balance increased by exactly `sale.amount`;
8. routes the funds to the verified split wallet or revenue escrow; and
9. records official counters and events only after wallet residence or a
   solvent owed escrow credit exists.

The provisional funding callback is:

```solidity
function fundERC20PrimarySale(
    bytes32 candidateCommitment,
    bytes32 settlementKey,
    address asset,
    uint256 amount
) external;
```

The authenticated payment adapter accepts it only from its immutable contract
`9`, only while its exact candidate's sale callback is active, and only when
the candidate commitment, settlement key, asset, and amount match. The active
state also proves that the address passed by the sale adapter is the live
top-level verifier for this operation. The active authorization context also
commits the exact top-level selector, funding mode, and typed permit-input hash;
a mode or authorization substitution fails before token code. Before either
token-moving call contract `20` moves the operation to the single-use funding
phase. On the signed-intent path the pair was already consumed before the sale
callback under decision 7; funding rechecks that the active authorization
context contains that exact consumed pair.

Every funding mode first snapshots payer and contract-`20` balances:

- direct allowance and signed-`PaymentIntent` funding call
  `asset.transferFrom(payer, address(this), amount)` from contract `20`;
- EIP-2612 funding first executes the exact typed permit, then makes that same
  contract-`20` token call, requires the permit-created allowance to contract
  `20` to be exactly consumed, and leaves zero residual allowance from that
  permit; and
- Permit2 funding calls only the immutably pinned SignatureTransfer entry with
  owner `candidate.sale.payer`, permitted token `candidate.asset`, permitted
  amount `candidate.sale.amount`, recipient `address(contract20)`, requested
  amount `candidate.sale.amount`, and the exact committed nonce, deadline, and
  signature. Permit2, not contract `20`, is the ERC-20 `transferFrom` caller on
  this branch. Contract `20` never creates or expands the payer-to-Permit2
  approval; Permit2's exact transfer consumes finite approval according to the
  approved token's allowance semantics, while any supported infinite-allowance
  behavior must match the asset-policy profile.

Contract `20` requires the same exact postcondition on every branch: payer
decreases by `amount` and contract `20` increases by `amount`. It then snapshots
contract `9`'s balance, calls `asset.transfer(contract9, amount)`, and requires
the exact contract-`20` decrease and contract-`9` increase.

Contract `9` independently verifies its snapshot around the funding callback,
records `msg.sender` as the real settlement caller, and stores the exact
`PrimarySettlementResult` under the settlement key so contract `20` can compare
the sale callback's returned tuple after control returns. The result's
`executor`, `executionId`, `operationIdentityCommitment`,
`currentPolicyHash`, and `boundPolicyHash` must equal the candidate.
The target `PrimaryRevenueSettlementContext` event adds `address executor`,
`bytes32 executionId`, `bytes32 operationRoot`,
`bytes32 currentPolicyHash`, and `bytes32 boundPolicyHash` immediately
after `address settlementCaller`; those fields and the result view make the
authenticated top-level initiator, per-purchase identity, live policy, and
grace-bound request identity reconstructable without mislabeling contract `20`,
the sale adapter, or the durable sale program. Central
`MintBatchExecuted`/`MintLedgerOperationRootConsumed` evidence exposes the same
current/bound pair. Authorization, nullifier, counter-consumption, and other
subordinate consumption evidence carries `boundPolicyHash` and joins
through `operationRoot`; it cannot present the predecessor as live economics or
consent. The exact event selector, schema-version treatment, and updated fixed
returndata length remain part of the provisional freeze/golden work.
Contract `9` never initiates or performs a payer pull, and contract `20` never
writes official-revenue or escrow accounting.

The existing numeric `PrimarySale.saleId` field is renamed `saleNonce` in the
target interface without changing its ABI type or tuple position.
`PrimarySale.settlementId` remains the sales-spec `bytes32 saleId` and the
exact `PaymentIntent.saleRef`. Both identify the durable sale program; neither
may be repurposed as the per-purchase replay nonce.

The current revenue `settlementKey` preimage contains only that durable
sale-program identity and is therefore not sufficient by itself for repeatable
fixed-price or open-edition executions. Before ADR 0019 can be accepted, the
ADR-0018/#688 typed operation identity and revenue-spec reconciliation must
carry the exact candidate-committed `executionId` into the contract-`9`
settlement, deposit, result, and event surfaces so two valid purchases cannot
collide. ADR 0019 does not choose or redefine #688's final operation root,
per-token IDs, or replay preimage.

### 4. Revenue And Escrow Ownership Stay Singular

The sale adapter owns signed/public sale authority, durable sale-program state,
per-execution records, refundable pre-revenue custody, and the named mint order.
Contract `20` owns payer authorization,
signer-scoped intent replay/revocation, and initiation of the exact payer pull:
directly against the asset for the allowance/EIP-2612 branches or through the
immutably pinned Permit2 SignatureTransfer branch.
Contract `9` owns assignment resolution/materialization, settlement-key
consumption, destination selection, and official revenue evidence. The revenue
escrow owns owed credits and flush/recovery.

Contract `20` cannot choose a wallet, create an escrow credit, increment an
official counter, or emit `PrimaryRevenueSettled`. The exact sale adapter calls
contract `9` directly but cannot fund it itself: contract `9` accepts value only
through the committed payment adapter's phase-gated callback. Contract `9`
cannot spend a payer allowance.

The revenue escrow's concrete credit ABI remains owned by
`[RSR-ESCROW]`. Whichever exact ABI implements that existing rule, contract `9`
is the source settlement authority and the credit is not official until:

- the escrow has received exactly the routed asset amount;
- the asset-keyed
  `(revenueClass, profileId, wallet, asset)` owed credit increased by that
  amount; and
- the escrow's per-asset solvency inequality remains true.

Wrong-code deterministic wallet addresses revert and do not use normal
escrow. Undeployed template wallets and failed bounded deposits use the exact
existing escrow eligibility rules. Contract `9` emits its official settlement
event only after one of the two routes is complete.

This ADR consumes the resolver interfaces owned by issue
[#670](https://github.com/6529-Collections/6529Stream/issues/670). It does not
add or change `StreamRevenueResolver` or `IStreamRoyaltyResolver`. A missing
resolver capability is a cross-lane dependency to coordinate, not authority
for issue #664 to edit that target opportunistically.

### 5. Asset Policy And Value Conservation Are Independently Enforced

Contract `20` derives the split factory and asset-policy registry from its
immutable contract `9` deployment line. After acquiring its operation lock and
before the sale callback or any pull, it reads the current
`ASSET_POLICY_GAS_LIMIT` from that pinned split-factory host, performs the
EIP-150 parent-gas precheck, reads the exact asset policy under that cap, and
requires `ACTIVE`. A hard-coded cap, caller-supplied registry, cached success,
or policy read from another deployment line is nonconformant.

Contract `9` independently repeats the current approved-asset-policy check
before consuming the settlement key or requesting funds. The revenue escrow
independently repeats it before accepting an ERC-20 credit. These are separate
fail-closed checks; success at contract `20` cannot be inherited by contract
`9` or the escrow. They do not replace the separate mint-policy rule above:
the accepted `boundPolicyHash` may be the live immediate predecessor, but
the current mint policy alone supplies consent, module/gate behavior, counters,
caps, and increments.

Every hop has its own balance snapshots and exact-delta proof:

```text
payer -> contract 20:
  payer decreases by amount
  contract 20 increases by amount

contract 20 -> contract 9:
  contract 20 decreases by amount
  contract 9 increases by amount

contract 9 -> split wallet:
  contract 9 decreases by amount
  wallet increases by amount

or contract 9 -> revenue escrow:
  contract 9 decreases by amount
  escrow increases by amount
  exact owed credit increases by amount
  total owed for the asset remains <= escrow balance for the asset
```

After success, contract `20` and contract `9` must each equal their
pre-operation balance for the settlement asset. Preexisting balances remain
separately classified ADR-0003 surplus and are neither spent nor counted as
this settlement. The split wallet or escrow is the only final holder of the
new amount.

Fee-on-transfer, no-op, rebasing movement, unexpected third-party balance
movement, malformed return data, or any inexact hop reverts. A wrong-code
deterministic wallet address reverts and cannot be converted into a normal
escrow credit. Escrow accepts only an exact asset-backed credit and proves its
per-asset solvency after the credit before contract `9` records official
revenue.

### 6. One Transaction And One Rollback Domain

Contract `20` uses an explicit operation state machine because contract `9`'s
one authorized funding callback occurs while the top-level call is executing
the typed sale-adapter callback:

```text
IDLE
  -> LOCKED
  -> AUTHENTICATED_AND_CONSUMED (signed intent)
     or AUTHENTICATED_BY_CONSTRUCTION
        (msg.sender == payer; direct or payer-called exact permit)
  -> SALE_CALLBACK
  -> FUNDING
  -> FUNDED
  -> OFFICIAL_SETTLED
  -> EXECUTION_COMPLETED
  -> IDLE
```

Every top-level settlement and signed-revocation entry acquires `LOCKED` before
the first external read or call, including the module registry, sale-lifecycle
binding, asset-policy registry, split-factory GGP host, ERC-1271 payer,
EIP-2612 token, or Permit2.
Pure calldata checks, including the execution-data hash, must precede the
lock; no external verification may precede it. Every mutating entry other than
the exact contract-9 funding entry requires `IDLE`.
`fundERC20PrimarySale` is valid only in `SALE_CALLBACK`, moves to `FUNDING`
before token code, and moves to `FUNDED` only after all exact deltas pass.
Each transition is written before its following external interaction. No phase
can be entered twice.

When the typed sale-adapter callback returns, contract `20` requires:

- exact ABI returndata length and decoding;
- the exact order-specific magic;
- exactly one completed funding callback;
- the returned `candidateCommitment`, settlement key, execution ID, asset,
  amount, executor, operation root, `currentPolicyHash`, and
  `boundPolicyHash` equal the active context;
- the full returned result equal contract `9`'s recorded result; and
- contract `20` and contract `9` retain no balance from this operation.

Only then may it transition
`FUNDED -> OFFICIAL_SETTLED -> EXECUTION_COMPLETED`, clear the active commitment
and authorization context, and return to `IDLE`.
Zero settlement, multiple settlement, early cleanup, callback omission, stale
context, and any phase mismatch use explicit custom errors and revert the
entire operation.

Contract `9`, the sale adapter, the mint manager, and the revenue escrow keep
their own non-reentrancy guards. The explicit contract-`20` state machine does
not weaken or replace them.

All steps execute in one top-level transaction. A revert after funding,
including a sale callback, manager, ledger, Core, receiver, route, escrow, or
event failure, restores:

- the sale adapter's unique execution record, signed-authorization state where
  applicable, public-sale counters, and execution events;
- `PaymentIntent` nonce state and consumption event;
- payer, contract-`20`, contract-`9`, wallet, and escrow token balances;
- the contract-`9` settlement key;
- template/profile materialization;
- escrow owed credit;
- official revenue counters and events; and
- manager, ledger, Core, token, and mint state.

No catch-and-continue path may preserve payment or official settlement after a
failed sale callback.

### 7. The Complete Verifier Surface Is Explicit

Contract `20` implements the exact `[RSR-PAYMENT-INTENT]`, `[RSR-1271]`, and
`[MPA-AUTHZ]` rules. Its permanent constants are:

```solidity
bytes32 public constant PAYMENT_INTENT_TYPEHASH =
    0x72c99e6f6f9e2422510a5dd5c2dc2f9ffd83c776670a8de4ffab990e45f825cd;

bytes32 public constant PAYMENT_INTENT_REVOCATION_TYPEHASH =
    0x3a5991afab010b2aa3f78362da982cf536e46d406a9e205c1f27b0f0e4c42e50;
```

They are recomputed from these exact strings:

```text
StreamPaymentIntent(address payer,address asset,uint256 maxAmount,bytes32 saleRef,bytes32 expectedPrimaryPolicyHash,bytes32 nonce,uint64 deadline)
StreamPaymentIntentRevocation(address payer,bytes32 nonce,uint64 deadline)
```

The revocation struct and complete public verifier/replay surface are:

```solidity
struct PaymentIntentRevocation {
    address payer;
    bytes32 nonce;
    uint64 deadline;
}

function isStreamERC20PrimarySettlementAdapter()
    external pure returns (bool);
function primarySaleSettlement()
    external view returns (IStreamPrimarySaleSettlement);
function paymentIntentDigest(PaymentIntent calldata intent)
    external view returns (bytes32);
function paymentIntentRevocationDigest(
    PaymentIntentRevocation calldata revocation
) external view returns (bytes32);
function isPaymentIntentNonceUsed(address payer, bytes32 nonce)
    external view returns (bool);
function revokePaymentIntent(bytes32 nonce) external;
function revokePaymentIntentWithSignature(
    PaymentIntentRevocation calldata revocation,
    bytes calldata signature
) external;
function eip712Domain()
    external
    view
    returns (
        bytes1 fields,
        string memory name,
        string memory version,
        uint256 chainId,
        address verifyingContract,
        bytes32 salt,
        uint256[] memory extensions
    );
```

ERC-5267 returns fields `0x0f`, name
`"6529StreamPaymentIntentVerifier"`, version `"1"`, current `block.chainid`,
`address(this)`, zero salt, and an empty extensions array. The same domain
verifies both typed structs. Wrong-chain and wrong-verifier signatures fail by
digest construction, not by a caller-supplied domain.

The canonical events are exactly:

```solidity
event PaymentIntentConsumed(
    address indexed payer,
    bytes32 indexed saleRef,
    bytes32 indexed nonce,
    uint16 schemaVersion,
    address asset,
    uint256 amount
);

event PaymentIntentRevoked(
    address indexed payer,
    bytes32 indexed nonce,
    uint16 schemaVersion
);
```

Genesis emits `schemaVersion = 1`. Direct payer and exact-permit paths do not
emit a synthetic `PaymentIntentConsumed`; only a verified `PaymentIntent`
does.

`revokePaymentIntent` consumes `(msg.sender, nonce)`.
`revokePaymentIntentWithSignature` requires
`block.timestamp <= revocation.deadline`, verifies the exact
`revocation.payer`, and consumes only that payer's pair. Used or revoked pairs
cannot be consumed or revoked again. Expired signed revocations fail at
submission; expiration never revalidates a used pair. Both successful paths
emit `PaymentIntentRevoked`.

Every top-level signed settlement and signed revocation acquires the operation
lock before its first external verification. It rejects an already used pair,
expired deadline, or mismatched typed field before signature verification.
After full signature verification, the signed settlement rechecks the pair,
sets `(payer, nonce)` used, and emits `PaymentIntentConsumed` before the first
sale-adapter callback. Any later revert rolls the state and event back
atomically. Consumption is not delayed until funding.

Canonical ECDSA is valid for the payer even when the payer has code in the
current observation, preserving the accepted EIP-7702 behavior. Recovery must
be nonzero and equal the payer, `s` must be low, and `v` must be `27` or `28`.
When canonical recovery does not authorize a code-bearing payer, contract `20`
must attempt ERC-1271 by `staticcall` through the exact bounded path below; a
no-code payer has no ERC-1271 fallback.
Malformed, oversized, failed, out-of-gas, or wrong-magic results fail before
nonce consumption and token transfer.

Contract `20` derives the split factory from its immutable contract `9` and
reads the current `GGP_ERC_1271_GAS_LIMIT` through that deployment line for
every ERC-1271 call. The parameter read follows `[RSR-GGP].6`: an uncapped
`staticcall` to pinned trusted infrastructure with exact bounded decoding,
then the EIP-150 parent-gas precheck and exact cap on the untrusted wallet call.

Issue
[#684](https://github.com/6529-Collections/6529Stream/issues/684) owns the host
implementation, binding, selector, floors, sizing evidence, and governance.
Contract `20` owns no parameter store, writer, cached fallback, or hard-coded
ERC-1271 cap. The #664 implementation consumes the #684-approved
split-factory read rather than inventing a parallel host.

### 8. Exact Permit Paths Are Payer-Called And Narrowly Typed

Issue #664 includes the exact EIP-2612 and Permit2 paths. They are not deferred
to an unreviewed generic `permitData` entry. The provisional typed inputs are:

```solidity
struct EIP2612PermitAuthorization {
    uint256 deadline;
    uint8 v;
    bytes32 r;
    bytes32 s;
}

struct Permit2TransferAuthorization {
    uint256 nonce;
    uint256 deadline;
    bytes signature;
}
```

with separate top-level entries:

```solidity
function settleERC20PrimarySaleWithEIP2612Permit(
    ERC20SettlementCandidate calldata candidate,
    EIP2612PermitAuthorization calldata authorization,
    bytes calldata saleExecutionData
) external returns (PrimarySettlementResult memory result);

function settleERC20PrimarySaleWithPermit2(
    ERC20SettlementCandidate calldata candidate,
    Permit2TransferAuthorization calldata authorization,
    bytes calldata saleExecutionData
) external returns (PrimarySettlementResult memory result);
```

Both entries require
`msg.sender == candidate.sale.payer`. Their sale intent is therefore the
`[RSR-PAYMENT-INTENT].5` payer-is-caller fact, not the permit signature. Neither
a plain EIP-2612 signature nor a plain Permit2 `TokenPermissions` signature
binds `saleRef`, `expectedPrimaryPolicyHash`, callback payload, or the #688
operation identity, so neither entry is callable by a relayer and neither
signature independently replaces `PaymentIntent`.

For EIP-2612, contract `20` constructs the token call itself with owner equal to
`candidate.sale.payer`, spender equal to `address(this)`, value equal to
`candidate.sale.amount`, asset equal to `candidate.asset`, and the typed
deadline/signature fields above. It never accepts owner, spender, value, token,
selector, or calldata bytes separately. The asset's approved policy must
explicitly attest EIP-2612 support. The permit is not called or externally
verified before the sale callback. During the one funding phase, contract `20`
calls the exact `permit` selector, requires the exact allowance, pulls the
exact amount, and requires the resulting allowance to be zero.

For Permit2, the deployment immutably pins the reviewed Permit2 address and
records its chain/code identity in the manifest. Contract `20` constructs
`TokenPermissions(candidate.asset, candidate.sale.amount)` and transfer
details `(to = address(this), requestedAmount = candidate.sale.amount)`;
contract `20` is the signed spender by Permit2's digest. Only the typed nonce,
deadline, and signature are supplied. The Permit2 call occurs in the one
funding phase and its nonce plus exact transfer are rolled back on any later
failure. Contract `20` is the sole protocol pull initiator, but pinned Permit2
is the asset's actual `transferFrom` caller on this branch. The approved asset
policy must explicitly permit this reviewed SignatureTransfer model, including
the pinned Permit2 chain/code identity and exact-delta behavior.

Permit2 SignatureTransfer requires the payer to have separately approved the
pinned Permit2 contract at the ERC-20 layer. Contract `20` neither creates nor
expands that approval, but the exact Permit2 transfer ordinarily consumes it:
an exact finite allowance becomes zero, a larger finite allowance decreases by
the transferred amount, and a supported infinite allowance follows the
approved token's explicitly tested infinite-allowance semantics. Any approval
remaining after the transfer is residual payer-granted authority held by
Permit2 outside contract `20`; Permit2's one-use signature nonce prevents the
presented SignatureTransfer authorization from replaying. The path creates no
allowance to contract `20`; exact payer/contract-`20` deltas, the reviewed
allowance transition, and Permit2's nonce are the funding proof. Plain
`TokenPermissions` is not described or treated as sale-bound.

Before the sale callback, both paths validate `msg.sender == payer` plus the
candidate, sale reference, expected primary-policy hash, asset, exact charged
amount, deadline, callback payload, and orchestration identity. Permit execution
is deferred until contract `9` makes the one exact funding request. They
preserve the same sale-adapter, contract-`9`, revenue, escrow, and rollback
graph.

A relayed permit path requires either a separately verified full
`PaymentIntent` in the same top-level entry or an accepted, pinned
`permitWitnessTransferFrom` witness type/hash covering the complete candidate
and PaymentIntent semantics with verification-before-effects ordering. ADR
0019 currently specifies neither relayed variant. A generic permit target,
selector, calldata blob, batch, arbitrary token call, non-exact EIP-2612
permit-created allowance, non-exact Permit2 signed or requested transfer
amount, residual allowance created by the EIP-2612 path, or Permit2 recipient
other than contract `20` is forbidden. The separately preexisting
payer-to-Permit2 approval described above need not equal the transfer amount and
is not contract-`20` authority; settlement consumes only the exact transfer
amount under the approved token's pinned allowance semantics and does not claim
to revoke arbitrary excess authority.

### 9. Multi-Component Charges And Custody Transfers Remain Outside

In this ADR's first implementation profile,
`candidate.sale.amount` is both the exact payer pull and the complete official
primary-revenue amount. `PaymentIntent.maxAmount` caps that complete pull. No
untyped surcharge, refundable custody amount, clearing overage, reveal fee,
protocol fee, or secondary destination may be added to it.

The following ERC-20 mechanics are explicitly excluded from the first profile:

- refund-window buyer custody;
- Dutch-clearing maximum-price overage and rebate liability; and
- a reveal-fee line item in addition to primary revenue.

ERC-20 `CUSTODY_SETTLEMENT_TRANSFER` is also excluded from this first profile.
It is a paid first sale of an already-minted program-custody token, not either
of the two mint-against-payment orders. Supporting it requires a third fixed
custody-transfer callback/order that consumes sale-side authorization/custody,
records official revenue, and only then performs the exact custody transfer
with complete rollback and no manager/ledger mint. ADR 0019 does not sketch or
reserve that callback selector.

These production gates remain open. Multi-component charge modes cannot claim
issue #664 coverage until a later accepted typed surface binds, at minimum:

```solidity
struct ERC20TotalCharge {
    uint256 primaryRevenueAmount;
    uint256 refundableCustodyAmount;
    uint256 clearingOverageAmount;
    uint256 revealFeeAmount;
    uint256 totalPayerCharge;
    bytes32 componentDestinationsHash;
}
```

That successor surface must prove the component sum equals
`totalPayerCharge`, apply `PaymentIntent.maxAmount` to the total payer charge,
bind each component's destination and owed/refund class, and preserve separate
official-revenue and sale-custody accounting. This provisional field inventory
does not authorize implementation or reserve an ABI selector.

Likewise, no ERC-20 custody-inventory or auction-custody primary sale may claim
this adapter profile, enable its genesis production gate, or route through a
mint callback until the separate typed `CUSTODY_SETTLEMENT_TRANSFER` surface
satisfies `[RSR-ORCHESTRATION].1` and
`[RSR-SETTLEMENT-BOUNDARY].7`.

### 10. Freeze Requires Complete Identity And ABI Constants

ADR 0019 remains Proposed and partial. ADR 0018 is accepted for an atomic
pre-genesis source cutover, but issue #688 remains open until that cutover is
implemented and independently reviewed. Before this ADR can be frozen, the
final revision must replace the provisional
operation-identity placeholder with the exact typed orchestration kind and
complete #688 operation identity in:

- both order-specific callback payloads;
- the candidate-committed execution binding and separate sale-execution record;
- the contract-`9` settlement request and settlement key/context;
- the contract-`9` funding request;
- split-wallet or escrow deposit/credit context; and
- reconstructable official settlement events and result views.

A frozen revision must carry the exact `operationRoot`,
`currentPolicyHash`, and `boundPolicyHash` through every applicable
surface above. It must preserve configured and ungated current-or-valid-
immediate-predecessor acceptance, current-only consent/modules/gate/counter/cap
evaluation, central current/bound evidence, and root-joined subordinate bound
evidence. An ungated-current-only settlement branch or any treatment of the
predecessor as live economics/consent is nonconformant.

A bare `saleExecutionHash` is not sufficient for any participant required to
reject an operation-identity mismatch. Contract `20`, the sale adapter,
contract `9`, and the wallet/escrow route must each receive or derive the typed
identity and compare it independently.

The frozen revision must publish and golden-test:

- exact Solidity interfaces, canonical tuple field names
  (`saleNonce`, `expectedPrimaryPolicyHash`), signatures, and numeric selectors;
- exact manager preview selector `0xa5651f13`, canonical
  `previewSingleStepMintOperation(MintBatch,bytes)` tuple signature, return
  order `(operationRoot, operationIds)`, adapter-as-`msg.sender` executor
  semantics, `STATICCALL`-safe no-write/no-event/no-consumption behavior, and
  exactly-`N` operation-ID cardinality;
- preview-before-execution-record ordering, configured
  `GateResult.authorizationId`/authorizer/address-kind equality, exact ungated
  `(address(0), AuthorizerKind.NONE, 0, bytes32(0))` plus empty-nullifier
  normalization, and the final byte-for-byte preview-versus-manager
  root/full-vector comparison with whole-transaction rollback;
- ERC-165 interface IDs;
- module types, module versions, schema hashes, and callback magic values;
- the exact fixed returndata length for each order-specific callback and every
  bounded external read;
- candidate, settlement, result, funding, and operation-context commitment
  string preimages plus computed hashes;
- the exact `SaleExecutionBinding` tuple, signed/public authority-mode numeric
  values, nonzero execution ID/nonce rules, atomic execution preimage,
  current/bound mint-policy fields, canonical-`purchaseId` branch, and
  ADR-0018/revenue-key derivation;
- the active authorization context's exact top-level selector, funding mode,
  and typed permit-input hash, with mode/substitution negatives and separate
  direct, EIP-2612, and pinned-Permit2 funding vectors;
- the exact `SaleLifecycleBinding` tuple in the candidate preimage, immutable
  sale record, contract-`9` request, registered-adapter read, and
  active-operation view, including both creation-time registry revisions, with
  independent sale-adapter and payment-adapter vectors for `ACTIVE`, valid
  pre-deprecation `DEPRECATED`, zero, missing, equal-boundary, future, and
  substituted values;
- `IStreamSaleLifecycleBinding`, selector/interface ID `0x2b022c4e`, exact
  36-byte calldata and 128-byte returndata shapes, proposed
  exact-code/interface-authenticated available-gas `staticcall`, bounded
  copy/canonical decode/no-bubbling behavior, numeric selectors for each
  provisional local read error, and the accepted RSR/#669 reconciliation for
  this normative exception;
- candidate-committed `executor`, top-level `msg.sender` authentication, exact
  signed-branch `SaleAuthorization.executor` and immutable-state equality,
  public-record payer-is-caller-only authority rules, mandatory signed-sale
  authority for non-payer relayers, result-view fields, and updated
  `PrimaryRevenueSettlementContext` event ABI;
- the adapter-owned `STREAM_ERC20_SALE_EXECUTION_V1` preimage, exact signed-only
  `SaleAuthorizationConsumed` and all-mode `SaleExecutionStatusChanged`
  operation-root/current-policy/bound-policy arguments, provisional
  execution-status numeric values, the five exact sale-side errors, and
  execution-record transition order from `UNSET` through
  `SETTLEMENT_IN_PROGRESS` to `SETTLED` without terminally closing the durable
  sale program;
- the execution-data hash check before the first external read or call;
- the sale adapter's check that `msg.sender` is the canonical active/deprecated
  verifier for the immutable sale record and that
  `paymentAdapter.activeERC20Settlement()` returns the same candidate
  commitment, lifecycle binding, execution binding, executor, order, operation
  identity, and `SALE_CALLBACK` phase;
- explicit errors for wrong phase, stale commitment, zero settlement, multiple
  settlement, wrong funding caller, wrong payment adapter, wrong return magic,
  wrong returndata length, result mismatch, and incomplete terminal cleanup;
  and
- terminal cleanup only after the corrected direct-sale-adapter graph has
  funded once, the exact contract-`9` result has been verified, and the sale
  adapter has completed the unique execution record's terminal status/event
  transition.

Until those constants are present, no checker may describe this ABI as frozen,
no implementation may rely on a provisional selector, and no genesis profile
or release artifact may claim role-20 conformance.

## Alternatives Considered

### Make Contract 9 The Verifier

Rejected. It contradicts the permanent contract `9`/`20` split in
`[RSR-DOMAINS].2`, changes the named genesis verifier, and preserves the
current payer pull in the wrong contract.

### Put A Downstream Verifier Behind Each Sale Adapter

Rejected. A downstream call observes the sale adapter as `msg.sender`, so it
cannot implement the payer-is-caller exemption. Removing that exemption would
fail issue #664's acceptance criteria.

### Trust Sale Adapters To Report Payer Consent

Rejected. Enabled-caller discipline is defense in depth, not payer
authorization. A compromised sale adapter must not be able to spend a standing
allowance.

### Generic Callback Or Multicall

Rejected. Arbitrary targets, selectors, values, delegatecalls, or call arrays
would make contract `20` an execution router and make its phase and rollback
proof open-ended.

### Pull Before Calling The Sale Adapter

Rejected. The signed authorization or public sale-record authority and exact
candidate would not yet be validated. An invalid sale could reach token code,
and a callback asset could observe a payment attempt that should have failed at
the sale boundary.

### Let Contract 20 Record Revenue And Escrow

Rejected. It duplicates contract `9`'s policy, settlement-key, routing, and
accounting authority and creates two sources of official-revenue truth.

### Add Operation IDs In This Seam

Rejected. The candidate commitment prevents callback substitution without
claiming the mint replay namespace. Issue #688 owns operation-root and
per-token operation identity.

## Security Impact

The fixed top-level boundary makes payer consent observable at the sole
protocol payer boundary and pull initiator. Contract `20` performs the asset
`transferFrom` on direct and EIP-2612 paths; on the Permit2 path it initiates
only the exact pinned SignatureTransfer call and proves the resulting payer and
receiver deltas. Exact candidate binding prevents a sale adapter from switching
the asset, amount, policy, payer, sale reference, executor, execution ID,
recipients, beneficiaries, quantity, or execution payload only after the
complete authority branch succeeds: a full signed `PaymentIntent` plus signed
sale authorization for a relayer, or top-level payer-is-caller public-sale
authority. Candidate binding alone is not purchase authorization. The one
contract-`9` funding callback is caller-, phase-, and commitment-gated,
eliminating generic reentry authority.

The design intentionally composes multiple non-reentrant contracts in one
atomic transaction. That composition increases call depth and requires
adversarial tests for every transition, but it avoids persistent token
approvals between protocol contracts and lets contract `9` validate revenue
policy before token code runs.

The approved-standard asset policy remains a required first-line exclusion of
fee-on-transfer, rebasing, hook, callback, no-op, malformed-return, or otherwise
non-exact assets. Exact balance deltas and independent contract-`9` receipt
measurement remain the defense if policy configuration is wrong.

## Release Impact

This is a pre-genesis target correction, not a compatibility promise for a
deployed contract. After acceptance, implementation changes affect at least:

- genesis roles `20` (`ERC20_PRIMARY_SETTLEMENT_ADAPTER`), `9`
  (`PRIMARY_SALE_SETTLEMENT`), and `7` (`REVENUE_ESCROW`);
- every concrete sale adapter that supports this ERC-20 paid-mint profile,
  including genesis roles `14` (`FIXED_PRICE_SALE_ADAPTER`) and `17`
  (`PRIVATE_SALE_ADAPTER`); custody-transfer support remains a separate open
  production gate;
- the production contract catalog, interface and marker checks, constructor and
  dependency bindings, external-call gas inventory, ABI and selector goldens,
  system-manifest payload, deployment plans, rehearsals, and source
  verification; and
- release notes, manifest, bytecode proof, lockfile, and checksums.

The concrete contract and instance artifacts must not be added for this ADR
alone. They regenerate only after implementations and instance checks exist.
The ADR and its normative spec amendments are release inputs and must be added
to the canonical release manifest and checksum generators in their documented
order after the ABI clauses are approved.

## Test Plan

The implementation PRs must prove:

- direct payer settlement succeeds only when the top-level caller equals both
  payer and candidate executor and cannot exceed the mode-correct signed
  authorization or public sale record's asset and amount; a direct
  payer/executor mismatch, public-mode non-payer relayer even with an otherwise
  valid `PaymentIntent`, and a relayed signed-intent executor mismatch fail
  before mutation; every non-payer relayed intent requires
  `SIGNED_SALE_AUTHORIZATION`;
- a signed intent binds every field, consumes exactly one payer-scoped nonce
  after complete verification and before the first sale-adapter callback, emits
  the canonical event, and rolls the nonce back on every later failure;
- replayed, revoked, expired, wrong-chain, wrong-verifier, wrong-payer,
  wrong-asset, wrong-sale, wrong-policy, and over-cap intents fail without
  lasting state or balance effects;
- configured and ungated paths accept `boundPolicyHash` only as the current
  hash or one live immediate predecessor; zero, expired, non-immediate,
  second-rotation-invalidated, gate-mismatched, and substituted hashes fail,
  including one second before, exactly at, and one second after the grace
  deadline;
- predecessor-bound execution still uses current artist consent, modules, gate
  results, counter policies, caps, and increments. Preview/execution rotation,
  substitution, omission, and replay vectors prove that the operation root,
  sale execution record, settlement result, and central events expose the same
  current/bound pair, while subordinate consumption facts expose the bound hash
  and join through the root;
- selector `0xa5651f13` decodes only the exact
  `previewSingleStepMintOperation(MintBatch,bytes)` ABI and returns one nonzero
  root plus exactly `N` nonzero, pairwise-distinct operation IDs without state,
  event, nonce, authorization, nullifier, or counter consumption. Caller
  substitution proves the executor is the sale adapter, never payer, relayer,
  the adapter's external caller, or `tx.origin`;
- configured preview rejects mismatched `GateResult.authorizationId`,
  authorizer, address-kind, expected-policy binding, gate result, and nullifier
  data. Ungated preview rejects a nonzero authorizer, non-`NONE` kind, nonzero
  normalized maximum/hash, or nonempty canonical nullifiers;
- preview/gate/resolver failure occurs before the sale execution record or
  signed-authorization consumption. A nonce/policy/gate/resolver race,
  manager-returned root mismatch, or any full-vector length/value/order mismatch
  reverts the settlement, payment, execution/replay, and mint state together;
- EOA zero recovery, high-`s`, bad-`v`, wrong signer, signer separation,
  EIP-7702 observation, maximum supported ERC-1271 wallet classes, malformed
  return, oversized return, wrong magic, revert, and gas exhaustion;
- inactive/malformed policy reads and every non-exact token behavior fail
  before official settlement or mint survives;
- callback target, selector, payload, candidate, phase, settlement key, asset,
  amount, return magic, zero/multiple settlement, duplicate funding request,
  and callback omission negatives;
- active and deprecated lifecycle candidates expose the same committed
  `SaleLifecycleBinding` to the sale adapter, contract `20`, and contract `9`;
  sale-adapter and payment-adapter revisions/timestamps are checked against
  their own module records, and zero, missing, future,
  equal-deprecation-boundary, and substituted facts fail closed independently
  at all three;
- contract `20` and contract `9` independently observe the authenticated sale
  adapter's stored binding through the exact bounded read; wrong, stale, zero,
  malformed, short, oversized, reverting, out-of-gas, and wrong-code read
  targets fail with the specified local error class before settlement effects
  survive; acceptance evidence also proves the proposed exception's exact
  RSR/#669 external-call classification and caller-insensitivity;
- both paid-mint orders create the exact candidate-committed unique execution
  record and expose its `SETTLEMENT_IN_PROGRESS` status before contract `9` or
  mint execution; replay, reentry, zero/reused/mismatched execution identity,
  wrong authority mode, wrong prior status, and every later failure roll those
  effects back, while success alone emits the execution's terminal `SETTLED`
  transition;
- signed-sale executions recompute and consume exactly one
  `SaleAuthorization` digest and emit `SaleAuthorizationConsumed`; public-sale
  executions require the immutable public record, a zero digest, and no
  authorization-consumption event. Multiple fixed-price/open-edition purchases
  use distinct execution IDs, settle independently, and leave the durable sale
  program open until its own close/exhaustion rule;
- reentrant sale adapters, contract wallets, policy registries, resolver/factory
  mocks, tokens, contract `9`, wallets, and escrow cannot double-consume,
  double-pull, double-record, double-credit, or mint twice;
- wallet success, undeployed-template escrow, bounded-deposit escrow, wrong-code
  rejection, escrow-credit failure, and flush/accounting conservation;
- every failure after the payer pull, including manager, ledger, Core,
  receiver, and mint completion failure, rolls back the complete state and
  balance vector;
- both paid-mint orchestration orders preserve their required ordering, while
  `CUSTODY_SETTLEMENT_TRANSFER` is rejected as unsupported and its production
  gate remains open;
- contract `9` never initiates or performs a payer pull, contract `20` never
  writes official counters, the Permit2 branch proves its pinned caller and
  exact payer/receiver deltas, and no production path uses `tx.origin`,
  `delegatecall`, generic call arrays, or generic permit dispatch;
- EIP-2612 and Permit2 success, expired, wrong-owner, wrong-token,
  wrong-spender, wrong-value, wrong-recipient, replay, EIP-2612 residual
  allowance, malformed-signature, and rollback vectors; Permit2 tests prove
  contract `20` never creates or expands payer-to-Permit2 approval, exact finite
  allowance becomes zero, excess finite allowance decreases by exactly the
  transferred amount, supported infinite allowance follows the pinned token
  semantics, remaining approval is external residual authority, and the
  Permit2 nonce prevents signature replay;
- contract `20`, contract `9`, wallet, and escrow exact per-hop deltas,
  post-success transient-balance cleanup, preexisting-surplus isolation,
  escrow backing/solvency, and wrong-code wallet rejection; and
- focused Foundry tests pass before the proportional full build, test, static
  analysis, deterministic release-artifact, deployment-rehearsal, and
  production release-mode ladders.

## Rollout

1. Publish this ADR only as a partial `Proposed` review slice after coordinator
   approval. That publication does not accept or freeze any provisional ABI and
   does not unblock contract implementation.
2. Merge issue #688's ADR 0018 and replace every provisional orchestration/
   operation-identity field with its exact typed surface, including the final
   per-execution/purchase derivation and distinct contract-`9` settlement-key,
   deposit, result, and event bindings.
3. Merge issue #684's exact host, value, floor, class, guarded-consumer, sizing,
   and fixed-stipend bindings for the existing `ERC_1271_GAS_LIMIT`,
   `ASSET_POLICY_GAS_LIMIT`, `WALLET_DEPOSIT_GAS_LIMIT`, and any other actual
   payment/revenue GGP consumed by the final graph. It does not supply a
   convenience cap for the sale-lifecycle read.
4. Accept the exact RSR normative exception and issue #669 external-call
   inventory reconciliation for both exact-code sale-lifecycle read consumers,
   including caller-insensitivity, available-gas behavior, bounded returndata,
   failure direction, and reentrancy posture. Do not add or overload a GGP row
   by convenience.
5. Freeze the exact interfaces, selectors, ERC-165 IDs, module constants,
   commitment hashes, callback magic/returndata, and verifier/permit ABI in
   this ADR.
6. Accept ADR 0019 and reconcile the normative revenue and sales
   specifications only after steps 2-5 are complete and independently reviewed.
7. Implement the shared candidate and callback interfaces plus contract `20`
   payer authorization, replay, revocation, and state machine.
8. Reconcile contract `9` to adapter funding and implement the existing
   wallet/escrow routing rules.
9. Implement one concrete sale adapter against the fixed callback before
   claiming end-to-end integration; do not broaden the contract-`20` PR into
   unrelated sale mechanics.
10. Add genesis-profile implementation names, interfaces, dependencies,
   deployment/rehearsal wiring, and deterministic release evidence only when
   the concrete graph exists.
11. Run issue #664's adversarial suite, independent review, CodeRabbit, CI, and
   release-currentness gates. Keep maturity language pre-audit.

Each implementation slice remains a separate branch and PR from current
`origin/main`. Dependent implementation must not stack on this unmerged ADR.

## Non-Goals

- No contract implementation, interface freeze before this ADR is accepted, or
  deployment-instance evidence.
- No sale-kind mechanics, auction behavior, refund policy, or concrete
  sale-adapter implementation.
- No ERC-20 `CUSTODY_SETTLEMENT_TRANSFER` callback/order; custody-inventory and
  auction-custody primary-sale production gates remain open.
- No resolver or royalty-resolver changes owned by issue #670.
- No operation-root, per-token operation ID, manager/ledger/Core replay change,
  or prepared-mint replay decision; issue #688 owns those surfaces.
- No GGP host, parameter binding, governance, floor, sizing, or release-evidence
  change; issue #684 owns those surfaces.
- No external-call inventory change; issue #669 owns that surface and must
  reconcile the proposed lifecycle-read exception before ADR acceptance.
- No merge, deployment, release, live-chain action, audit-completion claim, or
  readiness promotion.
- No generic permit payload or arbitrary token-call entry; only the separately
  typed EIP-2612 and Permit2 variants in decision 8 are in scope.

## Accepted Risks

- The fixed choreography adds two controlled nested calls and greater call
  depth than a single settlement contract.
- Contract `20` necessarily holds the payer's asset transiently inside one
  transaction.
- A valid signed intent is verified and consumed before the sale callback;
  callers may pay signature-verification gas for a sale that later fails
  authorization, while EVM rollback restores the consumed pair.
- Issue #664 implementation remains blocked until this ADR and its callback ABI
  are accepted, and its ERC-1271 path remains dependent on issue #684's exact
  split-factory host binding.
- Concrete sale adapters and the revenue escrow remain separate missing
  implementations. Contract `20` alone cannot satisfy the end-to-end genesis
  conformance gate.

These risks are accepted in exchange for a payer-observable verifier boundary,
one official accounting authority, exact callback commitments, and atomic
rollback without a generic execution router.
