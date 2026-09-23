# Scoped full-policy publication graph preparation

This additive client profile targets ABI129 source
`896899f7ca4130f86e066587f780a3b1f755a25d`, tree
`743efae1136e5742cb57c9e477080bd1c6aca5aa`. It prepares the genuine scoped
entropy source set and the fixed seven-child publication graph for TOKEN,
RELEASE and SEASON. Earlier fixtures and client profiles keep their original
meaning. COLLECTION and VIEW use separate products and interpretation rules.

## Two preparation calls

| Target | Original call | Purpose |
| --- | --- | --- |
| Scoped entropy factory | `prepareSourceSet(scope)` | Retain the complete original frozen coordinator policies for the current inventory plan |
| Scoped publication factory | `prepareGraph(scope, maximumChildren)` | Create at most `maximumChildren` additional fixed children for that genuine source plan |

Both calls are permissionless and nonpayable. A Safe uses the same exact
zero-value CALL; the Safe is the actual caller. Preparing children grants no
curator, Artist, archival, governance or finality authority.

TOKEN requires its real nonzero collection and token ID and a zero scope ID.
RELEASE and SEASON require a nonzero collection and membership scope ID and a
zero token ID. They remain different scopes even when their IDs match. The
source factory itself also supports VIEW, but this publication-graph client
profile deliberately admits only the three scopes supported by this graph.

## Genuine source and constructor recipe

Complete the authoritative membership and original Coordinator Inventory before
preparing a source set. Policies belong to each token's original
`coordinatorAtMint`, including retained burned identities. Empty, incomplete or
substituted inventories cannot create a genuine set. All original policy facts
must be frozen; that condition does not make pending token output renderable.
Terminal NOT_REQUIRED output remains separate from finalized randomness.

Source-set preparation checks its original fixed dependencies, inventory and
policies. It does not introduce a selected-Metadata or selected-Router gate.
Graph preparation additionally checks the selected Metadata and Router, the
complete operative recipe, current source route and factory-owned source set.
These distinct admission rules matter when a previous host remains available.

The workflow uses one reviewed `ScopedPolicyGraphV2Deployment` for both calls:
chain ID, both factory address/runtime pins, expected recipe and source-dependency
hashes, and the reviewed linked-library pins. Even source-only capture therefore
requires this publication-factory profile. This is a client setup requirement;
the original source factory can operate independently of that publication host.

The source dependency hash is the exact ABI hash of its original 352-byte tuple.
The publication recipe hash binds the original profile, chain and full recipe.
The graph ID additionally binds the actual publication factory, recipe and
source dependency hashes, full scope, inventory plan, source set and runtime.
Hashing supplied facts establishes their commitment; deployed-source checks
remain necessary.

The recipe fixes twelve original inventory roles, five Artist roles, the
content-consent owner, membership, STATIC selection, scoped source factory,
Governance executor and their expected runtimes. Inventory slots 5 and 6,
including their runtime hashes, must initially be zero: the factory fills them
with its own snapshot and reference children. Callers cannot nominate those
children or substitute deployment workers. Other late hosts have fixed nonzero
addresses and expected runtimes, checked when the original operation uses them.

Runtime and library pins must come from reviewed deployment/link evidence.
Matching a caller-supplied runtime hash proves consistency with that pin; it
does not establish the pin's provenance or completeness.

## Fixed order, bounded progress and receipts

| Index | Child |
| --- | --- |
| 0 | Terminal entropy readiness |
| 1 | Scoped-policy content checkpoint |
| 2 | Scoped-policy output manifest |
| 3 | Scoped-policy snapshot |
| 4 | Scoped-policy reference |
| 5 | Scoped-policy render-critical inventory |
| 6 | Scoped-policy archive bundle |

`maximumChildren` must be between 1 and 7 and means additional children, capped
by the remaining slots. Saved progress is a contiguous prefix. A newly saved
graph has at least one child; an unknown plan returns the original empty graph.
Child creation uses fixed workers in the genuine factory context. The client
must not predict a mined address from an earlier simulation.

The original schema-2 `ScopedPolicyPublicationChildPrepared` event identifies
each new child, its index, graph and plan. There is no separate graph-created or
graph-completed event. A complete graph retry creates no events but still
rechecks current eligibility. Source-set retries are likewise eventless and
validate their current source facts.

## Client entry points

`prepareScopedPolicyGraphV2Call` only encodes supplied coordinates and request
facts. `captureScopedPolicyGraphV2` reads the pinned deployment and eligible
source facts at a concrete block. Simulation authenticates that saved capture,
rechecks it at the requested block and runs the original factory call from the
actual caller. It returns `persisted: false`.

```ts
import type { Provider } from "ethers";
import {
  captureScopedPolicyGraphV2,
  simulateScopedPolicyGraphV2,
  type Address,
  type ScopedPolicyGraphV2Deployment,
  type ScopedPolicyGraphV2Request
} from "@6529/stream-client";

async function prepare(
  reader: Provider,
  deployment: ScopedPolicyGraphV2Deployment,
  caller: Address,
  request: ScopedPolicyGraphV2Request,
  blockTag: number,
  gasLimit: bigint
) {
  const capture = await captureScopedPolicyGraphV2(
    reader, deployment, caller, request, { blockTag }
  );
  const simulation = await simulateScopedPolicyGraphV2(
    reader, capture, { blockTag, gasLimit }
  );
  return { capture, simulation, call: capture.prepared.call };
}
```

Use `{ kind: "prepareSourceSet", scope }` first. After that source is mined and
reconciled, recapture `{ kind: "prepareGraph", scope, maximumChildren: 2n }`.
Repeat from newly observed progress until all seven children exist. The returned
unsigned CALL can be sent directly or composed with `createSafeCallPlan`; use
the Safe address as `caller` before capturing and simulating a Safe operation.

`reconcileScopedPolicyGraphV2Receipt(reader, capture, transactionHash, options)`
accepts `{ execution: "direct" }` or
`{ execution: "safe", expectedSafeTxHash }`. It uses the exact preceding block
and receipt block, reauthenticates the saved capture and refuses concurrent
source/progress changes that prevent attribution. It does not infer transaction
ordering from end-of-block state. The receipt block must be strictly later than
the capture block. An eventless retry still needs the matching
successful transaction envelope and retained state. The Safe path supports a
direct `execTransaction` with operation CALL; a module or MultiSend envelope
requires separate support.

Direct and Safe receipts must bind the exact transaction, caller, target,
zero value and calldata, then join new events to the recorded progress and
runtime bytes. An independently obtained Safe transaction hash is required.
Existing children must remain unchanged. Snapshot and reference gas limits may
rise through their original governance paths; identity comparison normalizes
only those permitted gas fields after checking their original lower bounds.
Inventory and bundle dependency hashes keep their exact original recipes.

The returned receipt evidence is `prior-and-end-block-reconciliation`. Concurrent
governance changes to existing child gas settings also refuse that receipt
comparison; recapture the resulting state separately. Graph inspection permits
the original monotonic gas increases when evaluating current identity.

The factory checks the source again after child creation. Failure within one
call rolls back that call's new progress; earlier mined stages remain. RPC
simulation and retained-state observations are bounded client evidence and do
not independently prove complete EVM rollback.

## History, current graph and provider selection

`sourceSetForPlan` and `graphForPlan` retain local deployment history. Their
results do not assert current eligibility and may remain useful after source
retirement. `requireCurrentGraph` requires all seven genuine children, current
source and runtime identities, and the original constructor dependencies. It
does not require an output, snapshot, root, reference or inventory publication.

The stable provider's six-field `scopedPolicyPublicationBinding` pins the actual
publication factory, its runtime, recipe hash, original source dependency hash,
graph-validation budget and provider-computed configuration hash. Its immutable
source catalogue still has the original three entries. A scoped V2 graph is not
a fourth static catalogue row.

Before a scoped V2 root exists, the provider can resolve the genuine graph's
snapshot child so that publication can proceed. That preparatory lookup differs
from `finalitySourcesForScope`: an absent root or completely empty V2 binding
retains the original scoped V1 branch. Only an actual V2 root and its exact
interpretation binding select the V2 branch. Unknown tags and partially populated
empty-tag bindings refuse. Later COLLECTION factory/discovery APIs belong to a
separate explicit source profile.

Use `inspectScopedPolicyGraphV2History` with the smaller historical deployment
profile and retained plan: it needs the publication factory, recipe and dependency
hashes, but does not demand live former source or child runtimes. Its result sets
`currentnessChecked: false`. `inspectScopedPolicyGraphV2Current` uses the full
deployment and scope and requires a complete current graph. Discovery adds
reviewed provider/discovery runtime pins, expected provider configuration and
source-configuration hashes, and their linked dependencies through
`ScopedPolicyGraphV2DiscoveryDeployment`.

Discovery options are `{ blockTag, includeRoutes, includeSanction }`, with both
flags explicit. When routes are requested, the original discovery must return
nine ordered component routes, or ten with the sanction component. Their runtime
pins and applicable V2 source-set/reference joins are checked. This observation
grants no authority to lock finality.

## Finite client bounds

These are refusal limits for this client profile, not protocol capacity claims.

| Input or observation | Limit |
| --- | --- |
| Pure codec bytes | 524,288 bytes |
| Pure supplied policy/coordinator arrays | 1,024 entries |
| Gas parameter name | 256 UTF-8 bytes |
| Workflow observed coordinators | 256 entries |
| Each reviewed linked-dependency list | 256 unique addresses |
| Each RPC result | 1,048,576 bytes |
| Each runtime | 131,072 bytes |
| Receipt | 4,096 logs; four topics and 65,536 data bytes per log; 1,048,576 aggregate log-data bytes |
| Outer transaction payload | 81,920 bytes, including Safe envelope |
| Simulation gas | 1 through 100,000,000 |

`observeScopedPolicyGraphV2Refusal` distinguishes a provider-reported execution
revert from an RPC failure and reports whether retained getters stayed unchanged.
It always returns `rollbackProven: false`.

## Publication steps that follow preparation

After completing the graph:

1. Complete STATIC selection, actual content checkpoint and covered output.
2. Publish the root-free scoped snapshot using the original registered documents
   and independent SNAPSHOT and IDENTITY writer grants.
3. Adopt the Router root with the original stored Artist operation-17 consent.
4. Publish the matching scoped reference, complete its ordered render-critical
   inventory and archive bundle, then perform the original finality ceremony.

This batch provides preparation and discovery callers. It does not replace those
later record writes or authority checks with a graph-complete result.

## Evidence boundary

The compiler fixture retains full ordinary ABIs, separate raw nominal library
ABIs, their source import closure and original interpretation documents. Every
one of the 3,262 ABI129 input literals matches its committed Git blob without
source line-ending normalization. The producer's bridge file retains its own
CRLF formatting and exact hash.

Compiler/source checks and mocked RPC/Safe-envelope tests qualify client
behavior. Native execution, actual Safe behavior, complete rollback, deployed
size and gas, child publication ceremonies and release acceptance require their
own evidence.
