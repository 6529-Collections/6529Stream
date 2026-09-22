# Artist attribution claims, disputes and repudiation

This client prepares the original Registry calls for attribution claims and
disputes, staged repudiation and the adopted dispute-withdrawal extension.
The original operation numbers and signed payloads remain unchanged.

The compiler catalog is the retained MULTIPLE_ATTESTATIONS ABI12 fixture from
`bd4a291e9e159cbbb5079a9a2a418fb151a8c01b`. The attribution source profile
separately compares its original producers with integration
`c715354ed57d2ab639f874cc595b272a7631de71`. This does not claim that those two
complete contract trees are identical: later hydration forwarding and recovery
imports differ. The existing full fixture is reused without recompilation or
changing the historical recovered-authority profile.

The [source profile](../test/fixtures/current-artist-attribution-source-profile.json)
records the complete selected current import closure: 1,027 unchanged sources,
six changed sources and seven additions. Ten concrete suite roots, 22 named
attribution producers and all nine original Registry forwarding bodies match
the retained compiler source. The changed recovery preparation/context and
hydration paths remain separately identified. This source comparison is not
current native compiler or linked-runtime evidence. Recheck it from repository
history with:

```sh
node scripts/generate-current-artist-attribution-source-profile.mjs --check
```

## Choose the original operation

| Operation | Registry method | Authority and effect |
| --- | --- | --- |
| 10 | `fileAttributionClaim` | Any caller may append an allegation for an existing collection. It changes no attribution or Artist authority. |
| 44 | `openAttributionDispute` | A currently authorized Artist-side signer with standing, or the canonical governed route, opens an attribution dispute. |
| 45 | `recordCounterStatement` | The current bound Artist or its eligible delegate records a response in the current open dispute. |
| 46 | `resolveAttributionDispute` | The canonical governed route restores attribution or records arbiter revocation. |
| 47 | `revokeAttribution` | The current nondelegated principal stages a prospective exit with a captured public window. |
| 48 | `vetoAttributionRepudiation` | One captured or current guardian terminates the pending exit and contests Identity. |
| 49 | `cancelAttributionRepudiation` | The still-current staging principal terminates its pending exit and records authenticated activity. |
| 50 | `executeAttributionRepudiation` | Any caller completes a still-live staged exit at or after its captured deadline. |
| 61 | `withdrawAttributionDispute` | The original signed opener, with its original standing and still-current authority, withdraws that dispute. |

The actual Registry selectors, in the table's order, are `0x061ed7c5`,
`0xe9375eda`, `0x24c57a62`, `0x38554d5b`, `0x555185ff`, `0x29e041a6`,
`0x99c26e2d`, `0xe907e941` and `0xe1d11786`. These come from the ordinary
compiler ABI. The old operation matrix's validation/write adapter selectors
are historical identifiers, not these public Registry tuple selectors.

`revokeAttribution` stages an exit; it does not immediately set attribution to
REVOKED. Operation 46's arbiter revocation and operation 50's completed Artist
repudiation have different consequences. Only the arbiter-revoked state is
reopenable through the governed dispute route.

## Documents and signatures

### Prepare the exact call

`prepareArtistAttributionCall(coordinates, caller, request)` returns detached,
normalized request data, the zero-value Registry call and, for a signed
operation, its original signing payload. Supply the actual chain, Registry and
Core in `coordinates`. For example, after reviewing the current opening and
original opener's authority:

```js
import { prepareArtistAttributionCall } from "@6529/stream-client";

const prepared = prepareArtistAttributionCall(coordinates, caller, {
  kind: "withdrawAttributionDispute",
  filing: {
    collectionId,
    bindingGeneration,
    disputeAction: 2n,
    evidenceHash,
    reasonHash,
  },
  standing: originalOpening.standing,
  authorization: { nonce: currentNonce, time: deadline, signature },
});
```

All unsigned integers are `bigint`. The helpers reject extra fields, malformed
or noncanonical bytes, wrong operation/action combinations and overlong dynamic
inputs. `factsVerified: false` is deliberate: offline preparation must be
followed by current authority, evidence, replay and original-call checks.

For an ordinary Safe call, pass that same prepared call to the shared planner:

```js
import {
  ARTIST_ATTRIBUTION_REGISTRY_ABI,
  createSafeCallPlan,
} from "@6529/stream-client";

const plan = createSafeCallPlan(coordinates.chainId, "Withdraw attribution dispute", [{
  safe: caller,
  intent: "Withdraw the reviewed opening using its original opener authority",
  call: prepared.call,
  abi: ARTIST_ATTRIBUTION_REGISTRY_ABI,
}]);
```

The plan retains the Registry target, exact calldata, zero native value and
ordinary CALL operation. Its review hash is not a Safe signing digest. For a
governed opening or resolution, the Safe calls the actual Executor through the
existing [governance workflow](current-governance-executor-v2.md); the Registry
call remains the authenticated inner call.

### Publish and cover the documents

A claim uses two canonical 160-byte platform-evidence documents. Each names the
collection, a zero parent claim and a nonzero narrative commitment; both must
name the same proposed Artist. The selected metadata store and current archival
coverage must authenticate both documents. A claim needs no Artist signature,
incumbent approval or attribution-state gate. Its duplicate subject is the
collection, caller, evidence hash and reason hash: changing only the reason URI
does not create a new subject. The URI is limited to 4,096 UTF-8 bytes.

Dispute evidence and reason are separate canonical 192-byte documents containing
schema 1, collection, binding generation, binding hash, parent opening and a
nonzero narrative commitment. Both require current archival coverage. For a new
opening, the parent is the current head's previous opening hash, including a
closed episode; use zero only when that head is zero. Counterstatements,
withdrawals and resolutions name their current opening. These commitments do
not establish the narrative's availability or truth.

Signed operations 44, 45, 47 and 61 use the original
`StreamArtistAttributionDispute` payload under EIP-712 domain
`6529StreamArtistRegistry`, version `1`, with the actual chain and Registry.
The payload includes Core, collection, binding generation, action, evidence,
reason, nonce and deadline. The action is respectively 1, 3, 4 or 2. The
authorization tuple calls the deadline field `time`; it is not a signing time.

An empty signature is a direct authorization only when the actual transaction
caller is the current authorized signer. A relayed authorization requires the
original signature check and a live nonzero deadline. Direct calls still check
the supplied nonce and any nonzero deadline. A Safe can be the direct signer
when that Safe is the actual authority; an owner's EOA is not interchangeable
with the Safe address. Payload construction establishes encoding, not authority
or signature validity.

Operation 47 permits zero evidence but requires a nonzero reason. It does not
use the dispute-document admission path. Claims, governed calls and repudiation
terminal operations do not invent a new signing scheme.

## Standing, replay and concurrent changes

Signed opening accepts the current bound Artist, an accepted earlier-generation
Artist through its own current authority, or an exact accepted collaborator row.
Only the current bound Artist may use an eligible delegation. Counterstatements
require the current bound Artist and the supported PRIMARY_ONLY policy. Current
class-3/class-4 principals need the original capability checks; a capability bit
does not replace the saved designation or activation rules.

Withdrawal is narrower than a fresh opening. It requires the immutable signed
opener's signer, authority class and complete Standing tuple. A new principal
cannot inherit another address's unilateral withdrawal right, and the old
address cannot act after losing authority. A delegate opener must use the same
still-live CAP_DISPUTE grant with its current epoch, nonce, deadline and remaining
uses. The primary cannot substitute for that delegate. Governed openings and
reopened arbiter revocations cannot be unilaterally withdrawn.

Dispute opening, counterstatement and withdrawal are defensive speech permitted
while Identity is contested. Withdrawal restores only the saved ARTIST_ACCEPTED
(2) or ARTIST_SANCTIONED (3) attribution state. It does not dismiss Identity's
independent contest or revive an exit invalidated by dispute opening. The
immutable withdrawal outcome keeps the latest counterstatement after closing
the dispute.

Resolution binds the current opening and latest counterstatement. A later
counterstatement makes an earlier resolution request stale. Restoring an
ordinary dispute requires at least governance class 1; revocation or resolution
of a reopened dispute requires class 2. Use the canonical Executor workflow for
publication, scheduling and execution with the exact Registry inner call and
current old/new context. Simulating a Registry call with a spoofed Executor
sender does not establish governance authorization.

## Repudiation lifecycle

Staging is nondelegable and requires an accepted or sanctioned current binding
under PRIMARY_ONLY. The current living principal, or the actual vested class-3
or class-4 principal with CAP_DISPUTE, may stage. Identity contest and a collection
dispute block staging and completion.

The stage captures the authority history, guardian set, window revision and
executable time. A later window update does not rewrite that deadline. A changed
authority history invalidates the old pending exit even if the same address
later returns to authority. The immutable record and a historical phase-1 row
alone do not prove that the exit is still live.

A fresh stage can replace a stale phase-1 exit after its binding or authority
history changes. The receipt must include the old exit's invalidation before
the new stage. Opening a dispute also invalidates a pending phase-1 exit.

A guardian in either the captured or current set can veto while the exit remains
live. The original source does not prohibit veto or cancellation merely because
the deadline has passed. Only the still-current staging principal can cancel;
there is no new signature or nonce consumption for cancellation. Execution is
permissionless after the captured deadline but rechecks the exact current
binding, authority history and capability.

Veto and cancellation both write Identity and Attribution. Veto creates the
canonical Identity contest and cause; cancellation invokes the existing activity
hooks. These effects are specified in [ADR 0048](../../../docs/adr/0048-attribution-repudiation-identity-effects.md).
The older semantic-owner matrix omits those Identity writes and remains
historical evidence. [ADR 0050](../../../docs/adr/0050-attribution-dispute-withdrawal.md)
specifies operation 61 without renumbering the original operations.

## Capture, simulate and reconcile

The provider workflow uses explicit runtime pins for Registry, Coordinator, all
seven ordered owners, Archive, Core, Manager, RoleRegistry and the reviewed
dependency closure. `captureArtistAttribution` records a concrete block, current
bindings, owner snapshots and operation-specific public facts. A capture has
`originalCallAdmissionChecked: false`; perform the original call simulation:

```js
import {
  captureArtistAttribution,
  simulateArtistAttribution,
  reconcileArtistAttributionReceipt,
} from "@6529/stream-client";

const capture = await captureArtistAttribution(
  provider, deployment, caller, prepared.request, { blockTag, gasLimit },
);
const simulation = await simulateArtistAttribution(
  provider, capture, { blockTag: latestConcreteBlock, gasLimit },
);
// The application reviews and submits the unchanged call through its wallet.
const result = await reconcileArtistAttributionReceipt(
  provider, capture, transactionHash, { execution: "direct" },
);
```

The workflow owns immutable captures; a JSON copy is not a substitute. A newer
simulation rechecks the captured facts, chain, block identity and runtime pins.
If they changed, recapture and review. The original Registry call performs its
authorization, evidence coverage, delegation and signature checks. A successful
`eth_call` is evidence for that observation, not a guarantee about a later
transaction.

Safe receipt options are `{ execution: "safe", expectedSafeTxHash, nonce,
safeCodeHash }`. Supply the independently reviewed Safe runtime and transaction
hash. Reconciliation checks the exact ordinary CALL, prior and final Safe nonce,
Safe hash getter and ordered success event in addition to the Artist evidence.
It does not independently execute the Safe's owner signatures.

For governed opening or resolution, pass `governance` in the capture options:
the original, same-instance `GovernanceExecutorV2Capture` for the actual
execution. Its block, Executor, exact single Registry target, calldata and
governance context must agree with the Artist capture. This profile supports one
governed target per execution, including a one-call batch. It delegates outer
Executor simulation and receipt checks to the existing governance workflow.

Receipt reconciliation binds the original Archive envelope and its STOP-prefixed
byte carrier, operation detail, immutable records, public state, owner revisions
and ordered events. It checks the prior block and the mined block. Additional
same-block changes to the captured owners can make those states ambiguous;
the workflow refuses that case. Reconciliation retains the explicit limitation
`privateAuxiliaryEffectsIndependentlyReconstructed: false` for private Identity
activity and transition effects.

`observeArtistAttributionRefusal` calls the unchanged prepared operation at a
selected block. It distinguishes a contract revert from an RPC failure and can
report success; it does not turn a transport error into protocol-refusal proof.

## Read current state and retained history

Use the pure `prepareArtistAttributionRead` and `decodeArtistAttributionRead`
helpers for typed ordinary getters. The host is explicit, because local
Attribution history and Registry reads have different current-dependency needs:

```js
const read = prepareArtistAttributionRead(registry, {
  host: "registry",
  kind: "attributionDispute",
  collectionId,
  bindingGeneration,
});
```

`inspectArtistAttributionCurrent` captures and simulates current admission.
`inspectArtistAttributionHistory` instead accepts a historical deployment and
`{ operationId, actor, value }` locator, authenticates the selected Archive
envelope and its immutable local record, and returns
`currentAuthorizationChecked: false`. Its optional `retainedPayload` must still
match the Archive metadata hash and length. Retained local records can remain
readable after current authority, dependencies or Registry selection changes;
their presence grants no new authority.

## Evidence boundaries

Supply deployment addresses and runtime hashes from an independently reviewed
deployment. Retained compiler artifacts and original-source equality establish
the selected ABI and semantic profile; they do not identify a live deployment.
Use concrete block observations and repeat admission immediately before sending.
A changed generation, authority, grant, dispute head, governance context or
pending exit can invalidate an earlier preparation.

Client tests use supplied provider responses. They establish encoding and client
checks only. Actual contract execution, current Executor integration, Safe
implementation and signature checks, rollback, deployability and release
acceptance require separate evidence. Existing recovered-authority profiles
continue to reject unsupported dispute histories; these callers do not extend
operation-60 import authority.
