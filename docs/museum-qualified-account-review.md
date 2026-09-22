# Authenticated account review policies

This prospective Museum profile lets an export author select another recorded
account's review of an exact mapping. A different account establishes account
distinction; it does not establish an independent person, professional competence
or an institution. These policies affect dossier exports only. They grant no
contract permissions and do not affect token rendering or independent records.

## Profile and source

`QualifiedAccountReviewProfile` constructs a distinct registered document set,
`STREAM_MUSEUM_QUALIFIED_ACCOUNT_REVIEW_PROFILE_V1`. Its assertion schema is
`STREAM_QUALIFIED_REVIEW_ASSERTION_V1`. It retains the complete V1/V2 document
and dependency closure without changing their original hashes or policies.
The typed V2 entity continuation rules remain in force.

Both a mapping and its qualifying review must opt into the new profile. Old
records can remain direct attributed sources or documentary evidence; their
old mappings do not acquire cross-account review permission retrospectively.
`RegisteredInterpretationCapture` checks the actual registered documents and
their bytes, canonicalizations and predecessors. `RecordedSemanticSource`
continues to authenticate historical independent-lane accounts and publication
positions through the existing capture/publication adapters. This is an
externally anchored trusted-RPC model, not a consensus or state-trie proof.

## Selecting claims and reviewers

The canonical selection document has exactly these fields:

- `mode`: `qualified_recorded_account_selection`; `version`: `1`.
- `sourceStateHash` and `profileHash`: the exact replayed source and profile.
- `sourceAuthoritySet` and `reviewerAuthoritySet`: complete original selectors
  with top-level assertion pointers.
- `sourceAdmissions` and `reviewAdmissions`: one exact admission per selector.
- `singleValuedRelations`: relation IRIs whose conflicting values are withheld.
  A resource projection must include the existing model's content and content-kind
  relations, as in the V2 projection policy.
- `independentReviewRequired`: `false`; `qualification`:
  `authenticated_account_under_selected_policy`.

Use `source_admission(source, selector)` to describe the already authenticated
facts for a source or review. It returns selector, original profile hash,
principal, record family, authorization class and complete chain/Core/host/
collection/subject/token/media scope. The helper does not grant authority.
The selection verifier derives these facts again and rejects differences.

A reviewer admission adds `targetSelector`, `targetRevisionHash`,
`targetProfileHash`, `mappingRule` and boolean `allowSelfReview`. These must
match the original canonical V1 review literal. That literal binds the complete
target assertion selector, its original revision hash, profile and mapping rule.
Review and original must retain the same scope, and the review must have a
strictly later authenticated block/transaction/log position. A supplied timestamp,
reviewer name or `reviewed` label cannot replace this evidence.

SELF is derived from the two historical account principals. It requires explicit
per-review opt-in and remains labelled `account_confirmed_SELF_review`. Other
admitted account reviews remain `policy_admitted_account_review`. Every retained
review evidence row states that human independence is not established. Asking
for independent-human review fails explicitly.

Withdrawn claims are omitted; self-declared disputed claims are withheld.
Withdrawn or disputed reviews cannot qualify a mapping. An admitted rejection
withholds the affected mapping, including when approvals also exist; later
timestamps do not decide which statement is true. Conflicting eligible
single-valued claims are withheld within their complete source scope and
entity/relation. Unselected records remain in the sidecar and cannot veto the
selected graph. Existing assertions and their exact review targets never move
to a later declaration automatically.

## Python entrypoints

The separate module `tools.museum.qualified_recorded_selection` exposes:

```python
selection = select_qualified_recorded(source, policy_bytes, policy_hash=policy_hash)
projection = project_qualified_recorded(
    source, policy_bytes, plan_bytes, policy_hash=policy_hash, plan_hash=plan_hash
)
```

The projection plan uses `qualified_recorded_account_projection` and the profile's
`qualified-account-review-1` version. It retains the existing exact state,
selection, crosswalk, entity selectors and external-entity commitments. Account
references must match historical chain/account identities. The ordinary V1/V2
selection entrypoint preserves V1/V2 behavior and rejects this new profile; consumers must choose this new entrypoint and
the matching policy. A projected entity IRI must have one exact native scope across
its selected declaration and subject claims; mixed token/media scopes refuse
before mapping, so no content silently replaces another scope's content.
No source files, renderer state or contract roles are written.

Generate or check the seven additional profile documents with:

```console
python -m tools.museum.qualified_review_profile --check
python -m unittest tools.museum.test_qualified_review_profile tools.museum.test_qualified_recorded_selection
```

Focused synthetic controls cover exact admissions, forged revisions/profiles/
families/scopes, publication order, SELF, withdrawal, conflicts, unselected
records, old-profile refusal and projection evidence. Separately, the
[retained local capture](museum-qualified-review-fixture.md) supplies actual
registered originals from the attestation host and Safe-governed registry.
Eight selection/projection tests replay those originals: approval, missing
approval, opposing reviews, unselected rejection, explicit SELF, authenticated
publication order, altered admission refusal and exact sidecar preservation.
The capture's original `selectionPolicyExecuted: false` remains unchanged;
these later tests execute a separate export policy against it.

```console
python -m unittest tools.museum.test_qualified_review_fixture_v1 tools.museum.test_actual_qualified_selection
```

The retained foundation has explicitly historical product sources. This is
local publication and offline selection evidence, not latest full-stack,
public-testnet, human-independence or institutional acceptance. General and
Artist review adapters require their own versioned source/authority joins and
remain separate work.
