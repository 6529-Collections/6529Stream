# Current preservation governance composition

The full-v1 preservation planner constructs the original
`StreamPreservationRecords` role27 product, an original `StreamCollectionMetadata`
instance used only as its record-family registry, and
`StreamMetadataGovernanceAdapter`. The role24 metadata pointer remains the
current `StreamCollectionMetadataV1` host. This composition closes the legacy
admin-interface activation gap; it does not establish complete museum payload
coverage or executed full-genesis acceptance.

## Authority and supported scope

The adapter pins the current Executor and its runtime code hash at construction.
Its `owner()` returns that Executor, so the original family-registry constructor
initializes its stored configuration authority directly to the Executor. No
deployer or temporary operator receives authority. Family admissions and writer
grants then use real scheduled Executor calls under class1.

The adapter binds exactly two deployed hosts once, through an exact class1
transition. Binding verifies their common Core, family-registry relationships,
admin dependency and stored configuration authority, and records both runtime
code hashes. These deployment-time observations must subsequently be reconciled
with independently reviewed compiler products; self-reported markers and observed
code hashes alone are not independent runtime authentication.

`retrieveFunctionAdmin` accepts only the actual Executor as actor, queried by a
bound host with unchanged runtime, during a nonzero executing action. The scope
binds this adapter, chain, target, target runtime hash and selector. Only class3
`updateAdminContract` and the family host's class2 `lockCollectionRecord` are
supported. The latter still obeys the host's record-family restrictions and the
Executor's terminal-freeze rules. Global and collection admin reads always return
false. Emergency recipient is zero. There are no operator grants, ownership
transfers or alternative scheduling entry points on the adapter. It is not a
general-purpose replacement for `StreamAdmins`.

## Metadata pause

Only `METADATA_MUTATION` is supported. Every other domain returns false; do not
wire this adapter to mint, auction, withdrawal, entropy or other non-metadata
hosts. `pauseMetadata()` requires class0 and `resumeMetadata()` requires delayed
class1. Both require the exact executing action, scope, old state and new state.
The state includes a monotonically increasing revision, preventing stale
pause/resume preimages from surviving a round trip. Each change emits
`MetadataPauseUpdated` with its action ID.

Install `pauseMetadata` as an Executor tightening selector through the isolated,
delayed `pauseClassification` plan before exposing pause operations. A class0
catalog entry by itself is insufficient. Direct Safe or EOA calls cannot pause
or resume. The existing preservation host's admitted independent-family
exemption is preserved: those append-only records remain writable during a
metadata pause. Neither Safe ownership nor governance-root status implicitly
grants a family writer role.

## Construction and activation

Use [StreamFullV1PreservationPlan](../../script/current/StreamFullV1PreservationPlan.sol)
for separate observed stages:

1. `deploy(core, executor)` constructs the three original products.
2. Admit `operatingPolicies` through the current governance catalog. Retain the
   Executor self-call policy needed for the isolated tightening installation.
3. Register the three actual ERC165 rows returned by `registrations`, with the
   canonical required SystemManifest publication tail.
4. Execute `bind` with ordinary class1 delay, then `pauseClassification` as a
   separate delayed Executor self-call.
5. Admit exact record types and grant explicit family writers using
   `admitRecordType` and `grantWriter`. Derive each next plan from confirmed
   configuration state. Grants and revocations in this planner use class1.

The planner supplies exact family configuration-chain commitments. The legacy
family host itself enforces its stored caller authority, not Governance V2
old/new hashes; its canonical Executor supplies catalog admission and scheduling.
The new adapter checks its own binding and pause transitions target-side.

[Current composition tests](../../test/current/StreamCurrentPreservationGovernance.t.sol)
use the actual current Core, Executor, family registry and preservation host,
with official two-owner Safe transactions. Their scope includes writer grants
and revocation, payload/event identity, target/selector scoping, pause and
independent-family behavior, stale transition rejection and runtime-pin failure.
Authored or ABI-checked tests do not establish runtime acceptance. Record native
execution separately against the eventual frozen integration source.
