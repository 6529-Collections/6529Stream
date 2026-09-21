# Current governance lifecycle and operational roles

These modules describe the original contracts at source
`eda052c75dc9fd5c4e2e658bdf453ab01f5b7c0e`, tree
`1a71ae4ee9806c601237129d81e494058c547ee0`. They require caller-reviewed
deployment addresses, runtime hashes and linked dependencies. They do not sign
or send transactions.

The [portable ABI witness](../test/fixtures/current-governance-executor-v2-abi.json)
retains the complete 42-file Executor and RoleRegistry import closure, five
governance ADRs, 23 ordinary declarations and 19 nominal library declarations.
Its generator authenticates the ABI164 compiler input's 4,119 source literals
against the recorded Git source. Nominal library selectors are provenance;
they are not exposed as wallet call targets. The generator's `--check` mode
checks exact deterministic output without compiling contracts.

## Executor calls

Import the helpers from this package's `dist/index.js` after `npm run build`.
`prepareGovernanceExecutorV2Call(coordinates, caller, request)` accepts exactly:

| Method | Request details |
| --- | --- |
| `publishGovernanceCallData` | Ordered `callDatas` |
| `scheduleGovernanceAction` | Original single-call `request` |
| `scheduleGovernanceBatch` | Original batch fields and ordered `calls` |
| `executeGovernanceAction` | `actionId`, `callData` and single `call` descriptor |
| `executeGovernanceBatch` | `actionId`, ordered `calls` and `callDatas` |
| `cancelGovernanceAction` | `actionId`, `reasonHash` |
| `vetoTerminalFreeze` | `actionId`, `reasonHash` |
| `materializeExpiredAction` | `actionId` |
| `pruneElapsedTerminalFreezeActions` | `scopeHash` |

The execution descriptor supplies the original payable value and commitments;
the single execution ABI still encodes only `actionId` and `callData`. Batch
execution value is the sum of all call values. `toSafeCall(prepared.call)`
preserves that value and uses ordinary CALL. The other seven methods carry zero
native value. Safe receipt options specify the outer transaction's native value
separately from the signed inner call value.

The pure module includes canonical codecs, original V2 domain hashes,
per-call and aggregate commitments, action identities and closed lifecycle
reads. Action identity uses the original schedule nonce. It cannot be rebuilt
using today's governance nonce. The publication key hashes the concatenated
calldata hashes; its preimage is different from ABI-encoding a dynamic array.

Raw tuple codecs preserve ABI values. Admission helpers apply additional
source rules, including delay/window checks. Clients impose their own limits
of 256 calls, 2,048 UTF-8 reason-URI bytes and 2 MiB outer calldata. The original
SSTORE2 publication permits at most 24,575 encoded payload bytes. These client
allocation limits do not change the contracts.

## Observe, simulate and authenticate a receipt

`captureGovernanceExecutorV2` accepts a receipt-capable reader, a deployment,
actual caller, request and `{ blockTag, gasLimit }`. The profile requires a
sealed Executor. Reads use a concrete block number and recheck its hash.
Retain the returned immutable capture for subsequent workflow calls.

For an existing action, supply `schedule: { transactionHash, logIndex }`
identifying its original `GovernanceActionScheduled` log. The workflow checks
the successful receipt, exact emitter, policy event and action identity. For
existing raw terminal-membership rows, supply bounded `membershipSchedules`
locators with each action's ID. These original append events establish private
root-capacity facts. The client neither invents a getter nor scans chain-wide
logs. Empty membership pages require no locators.

`simulateGovernanceExecutorV2` rechecks the captured facts and calls the original
selected method from the actual caller. Its result establishes that call's
admission at that block, subject to the supplied provider and deployment pins.
`inspectGovernanceExecutorV2Current` performs a fresh capture and simulation.
`observeGovernanceExecutorV2Refusal` tests the saved call without requiring its
old optimistic state; RPC failures remain distinct from contract reverts.

`reconcileGovernanceExecutorV2Receipt` checks the mined envelope, preceding and
ending state, nonce and pending counts, original lifecycle event fields/order,
publication carrier and raw membership swap/pop transitions. Safe mode also
checks the actual caller's pinned runtime, preceding/ending Safe nonce, all ten
signed transaction fields, independent EIP-712 hash, original Safe hash read
and unique matching success event. Signature collection and independent signer
acceptance are external. Unrelated guard logs may follow Safe success.

Receipt attribution conservatively requires the expected preceding-block and
ending state. Concurrent mutations may require a new capture or a separate
trace-based review. This client does not prove intermediate same-block effects.
An Executor success also does not independently prove product-specific target
effects; use the relevant target client for those checks.

## Historical state and terminal freeze

`inspectGovernanceExecutorV2History` authenticates retained action fields and
calldata from the original schedule using only the supplied historical getter
closure. It does not reauthorize the proposer, catalog or guardians today.

`governanceActionFacts` reports stored status. `governanceAction` can report
virtual expiry before `materializeExpiredAction` changes storage. Execution and
cancellation allow the expiry timestamp; materialization requires a later
timestamp. Veto ends at `notBefore`, and membership pruning is allowed at that
deadline. Pruning removes membership only; it does not change action status or
the pending action count. A publication retry or empty prune can emit no events.

Terminal operations use distinct per-call scopes and original raw membership
pages, including elapsed rows. Live filtered enumerations are not substitutes.
Current simulation remains the authority for source checks that cannot be
fully reconstructed through public getters, including private schedule
snapshots and catalog admission.

## Operational RoleRegistry calls

`prepareRoleRegistryOperationalCall(coordinates, caller, request)` accepts
`{ kind: "grantRole" | "revokeRole", role, holder }` for exactly these constants:

- `ROLE_ENTROPY_INCIDENT_DECLARER`
- `ROLE_ENTROPY_REVEAL_OWNER`
- `ROLE_ARTIST_REGISTRY_ADMIN`
- `ROLE_FIXITY_OPERATOR`
- `ROLE_EXPORT_PUBLISHER`
- `ROLE_CLAIM_ROUTER_OPERATOR`
- `ROLE_ENTROPY_ADMIN`

The actual caller must be a registered RoleManager. It may be a RoleManager
Safe. Executor-owned governance calls, manager configuration, scoped roles and
root-only roles are outside this profile. Operational holders do not inherit
guardian code or redundancy restrictions.

`captureRoleRegistryOperational` pins the reciprocal sealed Executor/Registry
binding, manager configuration, complete ordered holders, role mutation chain
and global mutation chain. `simulateRoleRegistryOperational` refreshes these
facts and calls the actual Registry method. Grant appends a holder; revoke
uses the original swap/pop order. The explicit client holder limit is 1,024.

`reconcileRoleRegistryOperationalReceipt` and
`inspectRoleRegistryOperationalHistory` require the exact
`RoleMutationCommitted` then `StreamRoleGranted`/`StreamRoleRevoked` events with
zero governance action ID, plus exact preceding/ending mutation chains and
holder order. Safe mode checks runtime, singleton, version, owners, threshold,
nonce and the original signed transaction hash. The profile requires zero
outer transaction value. Same-block registry or manager interference is
rejected by conservative whole-state comparison.

`inspectRoleRegistryOperationalCurrent` reports later membership, manager and
chain changes without invalidating authenticated history.
`probeRoleRegistryOperationalRefusal` calls the unchanged request against the
current pinned deployment and distinguishes provider failure from a revert.
Historical verification does not claim current authority or independent signer
or redundancy verification.

## Evidence boundary

Compiler parity, pure regression tests and mocked provider workflows establish
client behavior for the retained source. They do not establish runtime
provenance, real Safe execution, native current-stack acceptance, deployment
readiness or an audit. Release and deployment evidence remain separate.
