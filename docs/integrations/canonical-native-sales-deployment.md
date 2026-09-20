# Deploy and activate canonical native sales

The additive Solidity planners in
[StreamCanonicalNativeSalesDeployment](../../script/current/StreamCanonicalNativeSalesDeployment.sol)
and [StreamCanonicalNativeSalesActivationPlan](../../script/current/StreamCanonicalNativeSalesActivationPlan.sol)
construct and plan setup for three companion products. They reuse the current
Recorder and leave the original 37-role inventory, its hash domain and existing
sale adapters intact.

| Index | Companion | Sale kinds |
| --- | --- | --- |
| 0 | `StreamNativeImmediateSales` | FIXED `0`, OPEN `1` |
| 1 | `StreamNativeClaimSales` | zero-price claim `12`, bounded PWYW `13` |
| 2 | `StreamNativeDutchSales` | standard Dutch `3` |

These helpers prepare deployment and activation inputs. They do not establish
release readiness, audit completion or successful mint execution. Runtime
acceptance for the new helper recipe remains pending in this source batch.

## Construction and retained evidence

Supply three explicit constructor configurations sharing the same Manager,
Recorder, Artist registry, role registry and governance Executor. Provide a
deployment commitment, three module manifest hashes/URIs and three proposed
registry read budgets. Gas budgets are operator inputs, not measured launch
defaults. Preserve the exact constructor arguments and linked creation artifacts.

`deploy(configuration)` creates the three hosts and transfers their initial
ownership to the configured Executor. It does not register modules, grant phase
execution, install signers or consume Artist consent. The Recorder may still be
unregistered at construction. The helper pins the chain, host runtimes and twelve
dependency runtimes; `constructionHash(configuration, products)` commits that
separate companion inventory. Genuine deployment still requires checking each
linked artifact and constructor-inclusive initcode against the chain's limits.

`validate` allows a later legitimate owner transfer and governed gas increases.
It continues to check the saved graph, runtime pins and original configuration
metadata. Every owner plan reads the target's actual current owner.

## Observe each stage before planning its successor

1. **Catalog authority.** Compare `policies(context)` with the verified retained
   catalog history. `catalogAdditions` preserves compatible existing entries and
   rejects conflicting ones; the actual Executor remains authoritative. Extend
   its catalog through the existing approved root route before scheduling new
   selectors. These ten class-1, zero-value intents cover registry registration,
   Recorder credit, Manager phase configuration/executor addition and each
   companion's signer/sale registration. They do not include arbitrary calls,
   role grants, pauses, ownership changes or gas repricing.
2. **Module admission.** Run `registrationBatch(context)` for the remaining
   companions. Each row uses `NATIVE_PRIMARY_SALE_ADAPTER`,
   `keccak256("6529STREAM_UNIVERSAL_SETTLEMENT_V1")` and
   `IStreamNativeSaleBinding.interfaceId`, with the exact saved runtime,
   deployment/module commitments, URI and read budget. UNKNOWN rows are included
   in the batch; matching ACTIVE rows are omitted after prior execution.
   Every existing row must match and be ACTIVE.
   Read back all three before continuing.
3. **Existing Recorder.** Register it with its original deployment plan and
   prepared-settlement profile. `recorderCredit(context)` enables only that
   Recorder as an escrow credit producer. `requireSettlementReady` checks
   admission and the exact credit runtime pin. Canonical immediate products use
   their single-step native Recorder entries; this recipe does not bind Manager's
   prepared Recorder or the English auction custody house.
4. **Phase and Artist consent.** Supply `Phase` with an existing collection, a
   fresh phase ID, an unpaused singleton configuration and explicit nonempty
   bounded counter arrays. The helper deliberately plans an ungated phase.
   `configurePhase` returns `resultingPolicyHash` before Artist consent exists.
   Obtain the actual Artist's consent for that exact policy, then execute the
   returned owner call and read back Manager and Ledger state. Existing royalty
   policy prerequisites still apply at the target.
5. **Admit each carrier to the phase.** Use `phaseExecutor(context, index, ...)`
   one at a time. Each addition changes the phase policy and needs consent for
   its newly previewed hash. Observe each successful transaction before planning
   the next. After the last addition, capture the final live policy for sale
   configuration. A frozen phase cannot add a new executor.
6. **Signed collection authority.** For SIGNED mode, execute `configureSigner`
   and read back the exact enabled binding: authorizer, kind, evidence,
   revision and installing authority. Kind `1` means EOA and kind `2` means
   ERC-1271, including a genuine threshold Safe. This is distinct from the
   governance root or owner. PUBLIC mode uses the all-zero signer binding.
7. **Register the sale.** `registerImmediate`, `registerClaim` or `registerDutch`
   checks the final phase policy and installed signer and produces exact typed
   calldata. The target still validates its complete economic configuration,
   price policy, rights selection and lifecycle. Observe the actual returned
   sale ID/nonce/configuration hash, then obtain the actual Artist's consent for
   those immutable sale facts. Sale consent is a separate step from phase consent.

Positive-price settlement still needs the actual primary rights assignment and
all mint-time requirements: conservation floor, collection state, royalty,
entropy/reveal policy and applicable counters. Passing a deployment or sale
registration check alone establishes none of those execution results.

## Safe owner and Safe governance root

An `OwnerCall` contains `call.caller`, `call.target`, zero value, exact calldata,
the observed state hash and any prospective phase policy. If `call.caller` is
the configured Executor, `governed(context, savedCall)` returns its class-1 batch.
Save it through the existing
[governance stage planner](../../script/current/StreamGovernanceStagePlan.sol),
publish the exact calldata, and have the actual governance root schedule it.
A Safe root signs the Executor scheduling call; it does not impersonate the
target's owner. Preserve the scheduled bytes through the delay and verify the
confirmed action before execution. Apply the deployment's existing manifest
publication requirements through its normal stage procedure.

If a companion or Manager is instead owned by a Safe, execute `call.target`,
`call.value` and `call.data` directly through that Safe's normal threshold
transaction. `governed` refuses this owner route. The helper does not transfer
ownership to a Safe or grant it governance membership.

Run `validateOwnerCall(context, savedCall)` immediately before submission and
execution. It rebuilds the same typed operation to compare the saved owner,
phase, signer and sale-nonce observations. It rejects drift; it never silently
replaces scheduled calldata. These observations are offchain checks. Ordinary
owner methods do not enforce their hashes onchain, so operators must preserve
ordering and independently read back execution while the target enforces its
own current-state conditions.

The [current Safe recipe](../../test/current/StreamCanonicalNativeSalesDeployment.t.sol)
uses the actual current Core, Manager, Ledger, Artist, Recorder, Registry and
Executor with an official Safe 1.4.1. It covers construction, admission and
configuration; its upstream entropy service is a test double. It does not
substitute for the separate current purchase and callback acceptance campaigns.

Product behavior: [fixed/open](native-immediate-sales.md),
[claim/PWYW](native-claim-sales.md),
[canonical Dutch](canonical-native-dutch-sales.md).
