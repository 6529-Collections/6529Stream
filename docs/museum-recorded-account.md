# Recorded account semantic projection

`STREAM_MUSEUM_INDEPENDENT_ACCOUNT_PROFILE_V1` admits account-authored semantic
assertions from the dedicated `StreamCollectionAttestations` host into the
existing finite Linked Art v2 model. Its tracked example is actual isolated
local-EVM execution with public fixture accounts and explicit Core, Executor and
ERC-1271 boundary contracts. It is not a public-chain deployment or institutional
acceptance. The original synthetic profiles and packages remain separate.

## Exact registered interpretation

The selected host record must use the unchanged `STREAM_SEMANTIC_ASSERTION_V1`
schema and `INDEPENDENT_SEMANTIC_ASSERTION` family. Its payload names the unchanged
`STREAM_MUSEUM_SEMANTIC_PROFILE_V1` schema and the exact content hash of the new
registered CATALOG profile instance. The source adapter verifies the actual
registry kinds, declarations, original bytes, ordered chunks and canonicalization
references at the supplied source block. Schema names, profile hashes and payload
selectors cannot be supplied as replacement wrapper metadata.

The profile binds its authority policy, crosswalk, validation rules, evaluation
rules and dependency index through an acyclic hash graph. Original Linked Art,
CIDOC CRM and CRMdig bytes stay in their existing offline dependency closure;
the registered index commits to that closure. This does not claim every original
standard document was separately registered. Registration is distinct from
upstream endorsement or the authority to make a source assertion. Retired
schema, profile and canonicalization definitions remain readable.

The shared `RFC8785_JCS` definition retains standard JSON canonicalization
meaning. It bootstraps through the exact registered `RAW_BYTES` definition;
every other selected JSON interpretation document uses that exact JCS identity.
The Museum account profile supports a narrower input language: JSON decimal
numbers are unsupported, wide integers use canonical schema-defined decimal
strings, and source bytes must already equal the canonical encoding. It does
not round, trim, repair Unicode or normalize an existing source representation.
The dedicated source profile currently supports 8,192-byte record payloads and
512 selected-source records. The parent Museum schema's larger general bounds
are unchanged; this increment does not claim those branches.

## Account authorship and reviews

The account reference has this exact form:

```text
urn:6529stream:account:eip155:<canonical uint256 chainId>:<lowercase 0x address20>
```

Both components come from the anchored chain and historical receipt attestor.
Every selected assertion's `assertingAgent` and every declaration's
`declaringAgent` must equal that reference. The URI is an external `account`
reference in the recorded projection plan only. It is not a new entity kind in
the original schema, cannot be declared as a Person or Group, and does not
establish a human identity or current account control. A separately asserted
Person/Group remains a statement in the account's voice, never proof that the
account is that person or group.

Direct statements are eligible under the selected account policy. A mapping
requires an approving **SELF review** by the same authenticated historical
account and an explicit `allowAccountSelfReview` opt-in. Reviews bind the entire
original selector, exact assertion revision hash, profile, mapping rule and
later `(blockNumber, transactionIndex, logIndex)` position. The review body's
own record selector is resolved externally. Claimed creation timestamps do not
establish order. Conflicting admitted review dispositions withhold the mapping;
contradictory single-valued source claims withhold the affected projection.

Different-account reviews are explicitly unsupported by this profile. They
cannot establish human independence, even if both signatures were accepted.
`independentReviewRequired=true` rejects. Self reviews never count toward an
independent-review quorum. Unselected review records remain attributed sidecars.

Every cited source selector must resolve an original earlier record. Evidence
hash references must match those original payloads and canonicalization IDs;
supported JSON pointers resolve exactly, and `own_signed_statement` evidence
must come from the same historical account. This is evidence correspondence,
not a judgment that the cited statement is true. Unsupported evidence selector
kinds reject when selected. Dates, authority alignments, correction/dispute
links, qualifications and unprojected technical fields remain exact source
values; this profile does not invent additional authority or policy effects
from them.

## Trust, preservation and limits

The concrete entrypoint requires the source, publication and registered
interpretation adapters with independently supplied transcript commitments.
Every RPC/code/registry read is anchored to the same EIP-1898 block hash. The
operator must independently admit the exact host/Core/schema/store runtimes,
links and deployment evidence. This is trusted-RPC recorded state, not an MPT
inclusion proof, consensus-finality verification or an arbitrary runtime made
trusted by its self-declared hash. Completeness covers only the explicit lanes.

Whole selected canonical records validate before their schema-derived source
fields are counted. Every original public record, including malformed or
unsupported **unselected** records, retains its exact payload, schema and
historical account evidence in the sidecar. Unselected records cannot veto
selection. The resulting resources use the existing pinned v2 model, context,
vocabulary and guarded interpretations. They do not assert that all source
fields fit Linked Art; coverage accounts for unmapped and absent fields.

The output report keeps source evidence separate from output claims. Its
`registered=false` describes the generated export, not the registry documents
that the input adapter actually verified. Full Museum gates, other source
families (including WORK_DESCRIPTION/RIGHTS), recorded PREMIS/IIIF/LIDO exports,
complete packages, public deployment, independent reviewers and institutional
acceptance remain open. There is no synthetic-to-recorded Boolean switch.

## Local use

Use the isolated environment and locked dependencies in
[the tooling README](../tools/museum/README.md). No new dependency or compiler is
needed for offline replay:

```text
python -m tools.museum.account_profile --check
python -m unittest tools.museum.test_recorded_account -v
python -m tools.museum.recorded_projection --help
```

The projection command takes an input directory and six independent commitment
arguments: source transcript, publication transcript, interpretation transcript,
profile, selection policy and projection plan. Output goes to a new directory.
The CLI regression invokes the complete command using the pinned public example
and compares every output byte. Copying a hash from an untrusted directory does
not independently authenticate it.

`python -m tools.museum.local_independent_fixture --artifacts <reviewed-out>
--output <new-evidence-directory> --semantics` starts its own loopback Anvil,
reuses the reviewed prebuilt contracts and captures actual registrations,
records, receipts, block ancestry and model outputs. It cannot accept an external
broadcast URL. The tracked example contains six original byte-retention records,
two valid semantic records, a same-account review, a different-account review,
and eight signed authority/profile/conflict controls. Its assertion schema and JCS
definition are retired before the final read. Constructor and artifact evidence
retain the named boundary contracts; it is not the full current Core/Executor
stack. No new compiler is run by the fixture.
