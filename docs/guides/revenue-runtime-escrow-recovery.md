# Runtime admission and incident escrow recovery

This batch implements the original RSR-ESCROW-RECOVERY surface and the common
factory/runtime lifecycle it needs. Source and authored tests are available;
the selected 13 production products fit their bytecode limits. Native execution
and a complete sale-to-recovery current-stack demonstration remain pending. This guide does not authorize a
deployment, governance action or transfer.

## Admission before operator activation

`StreamRevenueRuntimeRegistry` uses the existing Executor and AssetPolicyRegistry.
Its independently governed `REVENUE_RUNTIME_READ_GAS` bounds fixed-shape reads.
Approve each factory through its exact transition commitment. The first approval
also approves its previously unknown wallet runtime in that same action. Factory
and runtime records have independent revisions and reasoned events.

ACTIVE permits new use. DEPRECATED prevents new profiles, positive assignments,
new primary-template materialization, new positive token snapshots and escrow
credits, while captured flushes and resident split-wallet release continue.
INCIDENT_REVOKED also blocks normal escrow flushing. Restoring either factory or
runtime admission uses delayed class 1, including INCIDENT_REVOKED to DEPRECATED.
Further restriction uses class 0. Only previously approved identities can be
restored; replacing factory bytecode cannot rewrite an existing admission record.

Existing Factory and Escrow constructor selectors are unchanged. For an advertising
Factory, Escrow fixes its three additional recovery gas parameters during construction,
using that Factory's current values and floors. Binding never adds a gas parameter.
Old nonadvertising Factory constructor fixtures retain their original single-parameter
behavior and cannot opt into this recovery capability. New instances
initially preserve the original unbound compatibility mode. Full operator
activation explicitly requires the common registry. Execute three separately
observed stages using `StreamRevenueRuntimePlan` and the existing saved
`StreamGovernanceStagePlan`:

1. Approve the deployed factory and its exact code/runtime in the common registry.
2. Bind that factory once, through an exact delayed Executor action.
3. Bind its escrow once to the same registry and runtime commitment. The escrow
   transition also commits the original profile preimage constants and the three
   constructor-copied ERC-1271, deposit and policy gas values/floors.

Reobserve after each stage; do not sign all later state commitments before their
predecessors execute. The four public admission/custody/manager preparation paths
in `DeployNativeCommerce` reject unbound or mismatched products. Its deployment
and catalog-discovery paths can run earlier. Original composition helpers remain
available for the explicitly qualified unbound compatibility fixtures.

The registry binds the actual Executor runtime and AssetPolicyRegistry. Each host
retains its own immutable-in-practice once-only registry pointer and code hash in
new namespaced storage. Existing constructor immutables, ordinary storage roots,
credit keys, policy hashes and signature domains are not migrated.

## Retain the canonical recovery document

Start from the actual original `EscrowCreditCreated` history and current
`escrowOwed`/`escrowCreditIdentity` reads. Do not infer collection or Artist identity
from a profile alone: the original credit key can aggregate different collections.
Resolve the original factory/profile entries and metadata hash, and the proposed
ACTIVE approved successor factory/profile/runtime. Register the successor profile
before publishing the recovery document; its wallet may remain undeployed.

`publishEscrowRecoveryManifest` retains the actual ABI-encoded `ManifestDocument`
bytes and emits them with the onchain-derived affected-account list commitment.
Its content hash is:

```solidity
keccak256(abi.encode(
    keccak256("6529STREAM_ESCROW_RECOVERY_MANIFEST_V1"),
    block.chainid,
    address(escrow),
    document
))
```

The reference uses schema `STREAM_ESCROW_RECOVERY_MANIFEST_V1`, canonicalization
`6529STREAM_ESCROW_RECOVERY_ABI_V1`, and an exact nonempty URI/URI hash. Its URI
is capped at 2,048 bytes. Preserve the reference bytes, not only its content hash.
Permissionless publication establishes the immutable content and its notice clock;
it cannot give the first publisher authority over another operator's URI. Every
schedule independently validates and commits its complete reference in the original
governed record. Republishing identical bytes at another valid URI preserves the
first content publication time; neither a URI change nor a competing publisher
changes the canonical document or restarts its clock.
Recipient notice rows follow the exact derived affected-account order. Collection
rows are unique and sorted by Core address then collection ID. Source-credit
citations are unique and sorted by transaction hash then log index, and each
collection row must have a contributing citation. The document retains each
source producer, transaction/block hash, block number, log index and collection
index. There is no invented onchain collection provenance on the old ledger.

The contract independently verifies sorted positive canonical entries (at most
64), their original profile commitment and the successor factory's stored entries
hash. When the original factory's captured code is still available, its stored
entries hash is checked as well. If the old code is unavailable, the original
profile-ID preimage is checked against the captured origin instead of calling
untrusted replacement code. A poisoned old wallet requires a different profile
ID and deterministic successor address.

For changed economics, an affected account is an old nonzero aggregate recipient
whose aggregate share decreases, including removal. Labels alone can change
without producing an affected account; the document still selects the changed
economics route. No count-only or caller-supplied affected set substitutes for
this computation.

## Three explicit recovery routes

Route 0 requires byte-identical canonical entries and is the default. Route 1
requires every affected account's recorded, unrevoked consent. Route 2 requires
the separate terminal action and notice evidence. A route cannot be inferred or
changed later from which execution entry point is called.

Every schedule is an actual class-4 FUNDS_RECOVERY action. Publication must precede
its execution by at least 14 days. Its `executeAfter` must respect that floor,
plus 72 hours for route 2. The original recovery ID remains the specified
14-word `abi.encode` commitment; it binds the original credit, successor,
expected amount, manifest content hash, execution time and reason hash.

Route 1 uses either the actual account's direct
`recordEscrowRecoveryConsent(recoveryId, nonce)` call or its EIP-712 consent relayed
by anyone. The domain remains `6529StreamRevenueEscrow`, version `1`, current
chain and escrow address. EOA/EIP-2098, delegated-EOA and exact-word ERC-1271 rules
match the original release authorization. Direct recording is independent of
signature gas limits. Both paths consume the account's same nonce map. Consent
may be recorded before scheduling once the complete intended ID is known;
that confers no transfer authority. Revocation after scheduling makes route 1
execution fail. A relayed Safe-message signature can restore consent without
consuming a pending Safe transaction nonce.

Route 2 retains a nonzero coverage statement, every affected recipient's notice,
all contributing collection identities and source-credit citations, and notice
evidence for each declared bound Artist authority. Notice timestamps must be
nonzero and no later than publication. Deliver notice by scheduling, retain the
original documents and delivery evidence, and permit objections during the
governance window. Publication starts the onchain notice floor; an earlier queued
governance action cannot shorten it. After actual escrow scheduling, a distinct
class-2 TERMINAL_FREEZE action must execute at least 72 hours later. Execution
requires both recorded actions and the unchanged canonical document.

**Evidence boundary:** recipient coverage and profile entries are verified
onchain. The source-credit citations, historical collection completeness,
Artist binding and actual notice delivery are explicit governance/operations
evidence. The contract checks their committed structure and timing; it does not
verify transaction inclusion or reconstruct historical Artist truth from hashes.
A bare arbitrary nonzero coverage hash is not sufficient documentation. The
governance approver must verify every contributing collection and source event
against the original history. Publication currently retains the document in one
transaction; operators must establish that their complete document fits the
available transaction gas before scheduling. Chunked notice-document publication
is not supplied by this batch.

The Executor classifier follows its original rules: granting a target's fast
tightening permission is an isolated delayed class-1 self-call; imposing terminal
classification is an isolated class-0 self-call. These classifier steps do not
authorize a recovery. The recovery target still demands class 4 and, for route 2,
its independent class-2 action and elapsed notice floors. Use the exact catalog
entries and original manifest tail when admitting new targets/selectors.

## Execution and failed-attempt recovery

Execution rechecks the exact current owed amount, captured old factory/runtime,
incident, original and successor entries, active successor admission, explicit
route and current consents/actions. It debits only the original credit and
`totalOwed`, then deploys/verifies the successor and moves that exact amount.
Every late failure reverts the debit, recovery status, deployment and callback
changes. It repeats current successor/incident/consent proofs and solvency checks
after payment. Ordinary non-reentrant host cleanup remains on the normal return
path. No operation here touches funds already resident in the old wallet.

Native donations above owed balances remain surplus and may arrive during a
transfer without invalidating an otherwise correct recovery. Supported token
recovery enforces the original exact sender/receiver delta and does not reapply
new-credit ACTIVE asset admission to an already captured obligation. All existing
normal claims/releases and best-effort deployed-wallet flush entry points remain.

Persist the exact saved governance plans, recovery ID/reference, unsigned Safe
CALL and any complete signed transaction separately from receipts. Revalidate
current state before submission; do not replace an old plan in place after an
amount or admission change. Failed zero-refund Safe calls preserve nonce and can
retry byte-identically after a valid repair, including a relayed consent. An
executed governance schedule and an executed escrow recovery are distinct facts.

## Validation boundary

Seventeen focused unit cases use actual Factory/Escrow/Wallet and official threshold
Safe contracts with an explicitly typed target-side governance context. It covers
old constructor compatibility, governed opt-in, lifecycle direction, deprecated
flushing, shared-runtime revocation/restoration, original resident funds,
captured-code-loss recovery, native/token conservation, both consent paths,
revocation, nonce/domain/deadline refusal, terminal timing, malformed evidence,
changed current state, cancellation, malformed optional capability replies, fixed
constructor gas inventory, URI publication liveness and complete Safe retry.

Two further authored cases use the actual current foundation Core, Executor,
catalog, manifest and Safe to approve/bind the registry and perform class-4
recovery or class-4 plus class-2 recovery. Their credit producer is explicitly
admitted directly; collection notice citations are labeled typed test evidence.
They are not a paid-sale/Core mint or actual notice-delivery capture. No authored
case is reported as passing runtime until the integrator's frozen test run does so.

Normative references: `docs/revenue-splits-and-royalties.md`, RSR-ESCROW-RECOVERY,
RSR-STAGED-GOVERNANCE, RSR-DOMAINS and runtime lifecycle; ADR 0008, ADR 0013 U7 and
ADR 0014 V4. This work does not apply the separately denied ERC20 reveal allowance
or inherited/global primary-freeze patches.
