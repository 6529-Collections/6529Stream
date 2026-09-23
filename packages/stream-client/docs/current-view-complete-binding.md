# Complete VIEW preservation binding

This client targets source
`9381dd999075693a4f63092d9924856a0dd72834`, captured by ABI146. It supports
the shared complete binding on these actual hosts:

- `StreamFinalityFullPreservationPolicyEvidenceProviderV1`
- `StreamCurrentAuthorityFullPreservationPolicyEvidenceProviderV1`

The [shared fixture](../test/fixtures/current-preservation-v2-abi.json) retains
the full selected compiler ABIs, nominal library witnesses, exact source import
closure and interpretation documents. Related token preservation V2 and
current-authority inventory/archive clients can use the same fixture.
Inclusion in that fixture alone does not establish client coverage.

## Five shared methods

| Method | Result |
| --- | --- |
| `completeViewPreservationBindingProfile()` | Exact complete binding profile. |
| `completeViewPreservationBindingTransition(configuration,declaration,selection)` | Admission preview and per-call governance transition. |
| `bindCompleteViewPreservation(configuration,declaration,selection)` | One governed mutation that stores both basic and complete receipts. |
| `viewFinalitySources()` | Operative reference, inventory and bundle selection after source revalidation. |
| `viewFinalitySourcesReceipt()` | Historical complete receipt, linked to the original basic receipt. |

Configuration has seven ABI words, declaration six, and selection six.
Declaration read/source gas fields are `uint32`; configuration validation gas
is `uint256`. The complete call has 612 bytes including its selector.
The complete receipt has thirteen words, including its nested selection.
Codecs preserve full-width integers and reject noncanonical encodings.

## Prepare one original governance action

`previewViewCompleteBinding` validates the selected host, captured authority,
original configuration, source factories and candidate dependencies at an
explicit block. Expected producer rosters derive from the provider's
authenticated original inventory; a caller cannot choose a replacement roster.

For a first bind, the policy source factory comes from the stored scoped
publication binding and authenticated factory recipe. The post-bind
`viewPolicySourceFactoryV2()` getter rejects before binding and cannot prepare
that first action.

`prepareViewCompleteBindingBatch` builds a singleton class-2 action with the
complete proposal. The three outer write stages are:

1. Executor `publishGovernanceCallData`.
2. Executor `scheduleGovernanceBatch`.
3. Executor `executeGovernanceBatch`.

The workflow requires a fresh pending-binding preview for all three stages.
This client preparation rule also applies to calldata publication, whose raw
Executor method has fewer prerequisites. After binding, use the historical
receipt and operative-source readers.

The nested call is the genuine provider's `bindCompleteViewPreservation`.
It must execute from the constructor-captured Metadata governance authority,
with its exact runtime and canonical active class-2 action. The transition
must match the complete proposal's scope, old value and new value. The basic
proposal is not a second action. Artist consent and finality-admin privileges
do not replace this authority.

Each outer transaction uses ordinary CALL with zero native value. The workflow
supports a direct caller or Safe 1.3/1.4 and simulates the actual outer call.
The pure nested call object is a governance target, not wallet authorization.
Use fresh explicit-block capture before submission; a preview does not reserve
state or prove that nested execution has enough gas.

## One-use guard and receipt reconciliation

Basic and complete binding share a permanent guard. A prior basic-only binding
cannot be upgraded to complete binding. A repeated complete bind reverts;
it is not an eventless successful retry.

A successful complete bind stores both receipts with the same action and
timestamp and emits only `ViewPreservationCompleteBound`. Receipt validation
checks that complete event, the original Executor transition and execution
events, exact transaction target/calldata/value, and the retained receipts.
It must not require a separate `ViewPreservationBound` event.

Safe reconciliation also checks the independently expected Safe transaction
hash and successful Safe result. A matching inner event without the intended
outer transaction is insufficient. Copied bounded receipt evidence and
explicit attribution checks remain client evidence, not independent chain
attestation.

## Historical receipt versus operative selection

`inspectViewCompleteBindingHistory` verifies the local basic/complete receipt
hashes, their link, shared action and timestamp. This host getter delegates to
the reviewed binding worker, so history requires the provider and that worker's
runtime pins. It does not reauthorize retired source contracts or today's
Artist authority.

`inspectViewCompleteBindingCurrent` additionally uses the genuine operative
getter and reviewed dependency closure. Source/runtime drift can invalidate
operative selection while historical admission remains readable. A permitted
reference-gas increase does not change publisher identity: current validation
must not demand that the reference's full dependency hash still equals its
initial historical hash.

The selected source hosts must exist and satisfy original capability,
profile, chain, runtime and reciprocity checks. Binding does not require or
create an adopted VIEW root, snapshot publication, completed inventory,
archive coverage, Artist signature or finality record. Operative source
selection alone does not prove those downstream products are current.

## Source and validation boundary

The two provider hosts retain different source-configuration hash domains.
Their complete binding hashes share the original formulas and bind the actual
host address and chain. Token preservation family V2 and VIEW have distinct
producer/admission rules. The historical ABI129 clients keep their original
source pins and fixtures.

This batch supplies typed calls, authenticated reads and client-side
governance/receipt checks. Current VIEW finality dispatch for C/Burn/Prepared
remains pending its own frozen source. Native contract execution, the final
all-call Safe matrix, runtime provenance, gas/capacity, rollback and release or
deployment acceptance remain separate integrator work.

Regenerate or verify the shared fixture using the exact retained ABI146
compiler input, output and committed-source bridge:

```sh
node packages/stream-client/scripts/generate-current-preservation-v2-fixture.mjs ABI_INPUT ABI_OUTPUT COMMITTED_SOURCE_BRIDGE --check
```

The generator checks all 3,914 compiler input literals against the pinned Git
commit byte for byte. It does not invoke a compiler or normalize source bytes.
It works from the repository root or another current directory when its
script path is supplied correctly.
