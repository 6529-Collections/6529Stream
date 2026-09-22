# Authenticated declaration lineage

The additive `DeclarationLineageProfile` implements the account-authorized
declaration correction, merge and split slice of [MSM-IDENTITY rule 8](museum-semantic-mapping.md).
It uses the existing independent semantic record family. It adds no contract,
protocol subject, ownership right or signing authority. Original account V1/V2
definitions, profile hashes, review rules and acceptance remain unchanged.

## Version and authority

`STREAM_MUSEUM_INDEPENDENT_ACCOUNT_PROFILE_V3` uses the new
`STREAM_SEMANTIC_ASSERTION_V3` schema and the `account-3` projection version.
The profile, assertion/export schemas, authority policy, crosswalk and dependency
index are generated under
[`schemas/museum/declaration-lineage-profile`](../schemas/museum/declaration-lineage-profile/).
Generate/check them with:

```text
python -B -m tools.museum.declaration_lineage_profile
python -B -m tools.museum.declaration_lineage_profile --check
```

Generation does not register these documents. The recorded adapter accepts this
profile only after reading its exact registered document bytes, canonicalizations,
predecessor IDs and complete retained dependency closure at the pinned original
source. The replay entrypoint selects the profile by its exact content hash;
an old capture cannot be promoted by changing the requested profile hash.

Every lineage edge binds an earlier original declaration selector, canonical
declaration hash and authenticated historical account. The source adapter checks
each declaration's original subject, schema, profile, receipt and publication
position. The successor and every predecessor must have the same declaring
account and entity kind. A claimed account name, matching IRI, first arrival or
matching object label conveys no authority. This profile proves a historical
account's attributed declaration; it does not prove named-human identity,
institutional mandate, ownership or independent human review. Cross-account
merge authority is refused in this profile.

## Declaration wire

V3 entities retain the original `id`, `kind`, `names`, `declaringAgent`,
`sourceRecords` and `predecessors` fields. `continuation` is required to be null;
the old V2 continuation wire is still interpreted under its original schema.
The new required `lineage` field is null for a declaration without predecessor
claims, or an object with exactly:

| Field | Meaning |
| --- | --- |
| `operation` | `correction`, `merge` or `split` |
| `predecessors` | Ordered exact `{selector, declarationHash}` references |
| `successors` | Sorted unique successor IRIs for a split; empty otherwise |
| `rationale` | Nonempty original explanation |

Each predecessor selector must also appear in both the entity's and payload's
`sourceRecords`. Entity `predecessors` must equal the referenced declaration IDs
in the same order. A forged pointer, hash, subject, recorder, authority class,
schema, publication order or other selector word fails admission.

- A **correction** cites one earlier declaration and preserves its stable ID and
  kind. Its names and other declared information may change.
- A **merge** cites two to sixteen distinct predecessor IDs and declares one
  different ID. None of the predecessor identities is deleted or made equivalent.
- A **split** cites one predecessor and declares two to sixteen distinct successor
  IDs in the same authenticated payload. Every cohort member must be present
  exactly once and carry identical lineage, rationale, predecessor and kind.
  Every successor differs from the predecessor and all its ancestors.

Merges and splits cannot recycle any ancestor's ID. "New" means new within the
explicit lineage: the exporter does not invent a global IRI ownership registry.
Competing unselected declarations remain attributed. Selected incompatible or
ambiguous declarations still fail. Lineage depth is at most eight links,
including earlier V2 continuations; DAG branches cannot hide a longer path by
sharing a previously visited ancestor. Original 8,192-byte payload bounds apply,
so a theoretical arity limit does not guarantee a particular payload fits.

## Projection and original evidence

Use `project_declaration_lineage` from
[`declaration_lineage_projection.py`](../tools/museum/declaration_lineage_projection.py),
or its offline CLI:

```text
python -B -m tools.museum.declaration_lineage_projection --input CAPTURE --output EXPORT --source-hash HASH --publication-hash HASH --interpretation-hash HASH --profile-hash HASH --selection-hash HASH --plan-hash HASH
```

The existing public `project_recorded` entrypoint also routes concrete V3
profiles through these checks, including callers in existing export/package
tools. It cannot bypass lineage validation by choosing the old entrypoint.
The selection policy and plan retain their existing exact fields and hash pins.
Use `recorded_account_selection` version `1`, the new profile hash,
`recorded_account_resource_projection` version `account-3`, and the new
crosswalk hash. `entityAuthoritySet` explicitly selects declaration selectors.
For a corrected resource, select its corrected declaration. Selecting both its
old and new declarations remains ambiguous; there is no latest-wins rule.
For merges/splits, select the distinct predecessor and successor resources, or
declare an omitted predecessor as an explicit external reference of its exact
original kind. A selected predecessor cannot substitute an unrelated declaration
merely because its ID matches. A connected explicitly selected correction is
allowed and its evidence remains separate.

The result contains actual Linked Art resources (or existing typed extensions)
with the selected declaration's exact IDs, names and kinds. It also contains:

- `declarationLineage` in the sidecar: selected exact selector; all reachable
  original declaration values, hashes, selectors and authority evidence; explicit
  operation edges; and exact original declaration references for split cohorts.
- Complete field inventories for all lineage ancestor records, even when their
  resource is omitted. Their original bytes remain in `publicSources`.
- A `declarationLineageHash` and updated sidecar/coverage hashes in the report.

The projection limits the accumulated lineage graphs to 512 nodes and the whole
encoded result to the existing 64 MiB cap. It does not redirect old assertion
subjects, authority alignments or reviews to merged/split IDs, transfer review
dispositions, delete original records, or assert an equivalence relation. A
separately governed qualified-reviewer policy is not part of this account-only
profile. Existing dossier and archival adapters are unchanged; this entrypoint
produces a resource/sidecar projection, not a newly registered export package.

## Validation and limits

`tools.museum.test_declaration_lineage` exercises real semantic-admission and
projection code using explicitly synthetic V3 records: corrected resources,
merge/split resources, all three authority refusals, exact selector mutations,
rewritten/missing split lineage, original subject/profile bindings, old V2
continuations, depth/merge-DAG bounds, original-byte retention, and unrelated
selected/external predecessor refusals. Existing retained V1/V2 local-capture
tests separately verify compatibility and reject profile promotion.

No V3 signature, chain registration, native contract execution or new archival
format acceptance is claimed by these Python tests. Full-v1 Museum work and its
runtime/evidence gates remain tracked separately.
