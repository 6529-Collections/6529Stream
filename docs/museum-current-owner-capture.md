# Current owner loan and valuation capture recipe

This batch supplies an actual-current contract test recipe and executable local
publication/capture helpers for the existing [loan](museum-recorded-loans.md)
and [valuation](museum-recorded-valuations.md) dossier profiles. Native execution
and positive RPC capture of this new recipe are pending. No transient Foundry
test state or inspector log is represented as a canonical transaction receipt.

The target is the owner-record portion of [CMC-OBJECT-DOSSIER](collection-metadata-contract.md#object-dossier-export-cmc-object-dossier),
[CMC-EXHIBITION-LOAN](collection-metadata-contract.md#exhibition-and-loan-records-cmc-exhibition-loan)
and the shared-source [MSM-INTEROP](museum-semantic-mapping.md#10-coexistence-with-existing-museum-formats-msm-interop)
requirement. This finite recipe does not establish the complete object dossier,
an institutional ingest, appraisal authority, physical performance or custody.

## Contract recipe

`test/current/StreamCurrentOwnerMuseumCapture.t.sol` reuses the existing current
Core/Artist/Manager/Executor/registry/royalty/metadata graph and its admitted
collection and phase. It buys one actual token through the existing native sale
and delivers it to an official two-owner Safe. The inherited randomness provider
remains an explicit upstream test double. The governance root is the inherited
real `StreamGovernanceActor`, not an assertion that every governance action was
sent by a Safe.

The derived fixture adds only an actual SchemaRegistry and OwnerRecords host,
created from the existing artifact helper. Its initial action catalog includes
schema registration. Every definition is registered through the actual delayed
Executor transition, followed by exact byte readback. The original RAW_BYTES
definition and existing RFC8785_JCS file are retained. No Core pointer, Artist
approval, owner check or record nonce is mocked. OwnerRecords remains a separate
documentation host; this recipe does not claim it has been selected as a Core
serving authority.

Three authored cases cover:

- Direct Safe insurance valuation and outbound/return condition declarations,
  an independently hashed fourteen-word relayed Safe loan authorization, and a
  later separate book-value statement. Original receipt fields, registered schema
  hashes, signature carrier, complete event fields, lane count and unchanged
  token ownership are checked.
- Actual transfer to a distinct Safe, rejection of the old owner's original
  signed loan through a full Safe transaction, transfer back, and identical
  calldata retry. The failed Safe nonce, owner nonce and record chain are checked.
- Repeating an accepted relayed loan cannot append another record or advance
  the failed Safe transaction nonce.

The test validates event fields but does not manufacture block headers or RPC
transaction ordering. Multiple records in one Foundry test can share its
timestamp; `recordedAt` alone cannot order the loan and valuation lanes.

The six files under `test/fixtures/metadata/current-owner-museum/` are public
fictional test statements. The condition schema is explicitly an opaque fixture
schema, not the complete institutional condition-report profile. The loan JSON
template contains six explicit markers: three returned original record hashes
and three payload digests. The native recipe replaces each exactly once. The
Python test independently proves that those substitutions equal the canonical
JSON builder. The unfilled template is never published.

## Coordinated local publication

No additional compiler or chain process is launched by this module. The test
recipe is intended for the integrator's next native batch. A passing test will
establish only its executed contract flow; it will not create a reusable RPC
snapshot. A later local-chain run must construct a compatible current graph,
mint its real token, and retain the actual deployment/transaction evidence.

`publish_owner_records(fixture, token_id, owner_safe)` in
`tools/museum/current_owner_capture.py` is an executable publication helper for
that already constructed, task-owned local graph. It requires:

- An existing `CurrentMuseumFixture` (the native fixture with original governed document registration) with loopback RPC on chain 31337, genuine
  native products and controlled official Safe owners.
- Actual Core token ownership by that Safe, an unburned token in collection 1,
  and the actual OwnerRecords Core/schema bindings.
- The original JCS definition already registered, and the existing
  `register_document` helper admitted under that graph's actual Executor.

The helper registers the exact loan, valuation and opaque condition definitions,
then performs direct Safe writes and a relayed ERC-1271 loan write. It approves
the official handler's `SafeMessage(bytes)` digest with the actual Safe owners;
it does not use impersonation or replace signature checks. Returned original
record hashes are read back with their full receipts and signature bundles and
checked by `verify_wire`. The result supplies selected records and the exact
three transaction hashes needed for the loan plus complete valuation lane.

New captures use an empty optional record URI because the payload is embedded
and no hosted fixture location is established. The former fixture URN fails
the native content-URI policy. The Python helper and current-stack recipe now
use the permitted empty value, with native renderer regression cases authored
for the next coordinated test run. This repair does not establish execution
acceptance for the old recipe or modify any retained fixture bytes.
The recipe's separate required module-manifest URI uses the raw CID of its
exact local manifest bytes. This is a content commitment; no IPFS publication
or remote availability is asserted.

Minting is deliberately delegated to the existing current graph recipe. A
foundation with no Artist or minted token cannot substitute a platform shortcut.
Do not run this helper against another task's Anvil process. Coordinate the
process and source snapshot with the integrator before publication.

## One final anchor and offline dossier replay

Publish the existing account/media source records and all five owner records
before selecting one final block. The existing recorded account capture must
produce its complete Linked Art, PREMIS, IIIF and LIDO package at that block.
`make_owner_anchor` copies that exact chain/Core/block identity and adds the
OwnerRecords host, schema, store, original runtime pins and explicit record
selection. Preserve the original deployment evidence and its external hash.

Create a canonical capture plan with exactly:

```json
{"version":"1","loans":["RETURNED_LOAN_RECORD_HASH"],"valuations":["RETURNED_INSURANCE_RECORD_HASH","RETURNED_BOOK_VALUE_RECORD_HASH"],"transactions":["INSURANCE_TRANSACTION_HASH","LOAN_TRANSACTION_HASH","BOOK_VALUE_TRANSACTION_HASH"]}
```

Those labels are explanatory placeholders, not accepted hashes. Use actual
returned hashes and canonicalize the plan with the existing JCS implementation.
Condition records remain in the owner anchor and source package, but their
transactions are not substituted for required loan/valuation ordering evidence.

The CLI is read-only and accepts only loopback RPC:

```text
python -m tools.museum.current_owner_capture capture --account-package ACCOUNT_PACKAGE --account-hash HASH --anchor OWNER_ANCHOR.json --anchor-hash HASH --evidence DEPLOYMENT_EVIDENCE.json --plan CAPTURE_PLAN.json --plan-hash HASH --rpc http://127.0.0.1:PORT --output NEW_OUTPUT --disclosure public
```

It checks the externally pinned package, anchor and plan, then verifies every
selected original owner receipt and full valuation-lane count/head/index. The
existing history reader joins full OwnerRecordRecorded events to canonical
ancestor headers, transaction positions and log indexes. It retains the original
256-block ancestry bound and makes no consensus or receipt-trie proof claim.

The result contains the literal four-format account package inside a loan
package inside a valuation package. Loan and monetary semantics use their
existing explicit sidecars and resources. The old LIDO/PREMIS/IIIF documents are
not rewritten to imply support for new monetary fields. Every old source file
must remain byte-identical. Same Core/block binding does not conflate token,
work, file, named parties or account identities.

The builder rejects a base missing any of the four formats, altered source
bindings, incomplete receipt evidence, restricted disclosure or an existing
output path. A failed later build may leave an incomplete output directory;
only the final successful `result.json` and independently pinned manifest mark
a completed run. Verification is network-free:

```text
python -m tools.museum.package_v2 verify NEW_OUTPUT/valuation-package --manifest-hash HASH
python -m tools.museum.current_owner_capture check-fixtures
python -m unittest tools.museum.test_current_owner_capture -v
```

The result explicitly lists each loan-insurance join status. The positive
`ordered_selected_unsuperseded_reference` status means the documented loan
selected an earlier, explicitly unsuperseded reference under the bounded
evidence profile. It never proves a legal operative valuation or professional
countersignature. A later book-value statement does not silently supersede an
insurance statement merely because its timestamp is later.

## Opt-in single-process RPC composition

`tools.museum.current_owner_rpc_capture` combines the original token governance,
native Artist graph and paid-mint helpers with `CurrentMuseumFixture`. It owns
one new loopback Anvil through the existing process runner. The ordinary
`CurrentTokenFixture` and its defaults remain unchanged. This is an authored
composition; positive native/RPC execution remains pending.

```text
python -m tools.museum.current_owner_rpc_capture --native-manifest NATIVE_MANIFEST.json --native-manifest-sha256 SHA256 --output NEW_OUTPUT --disclosure public --anvil ANVIL_EXECUTABLE
```

The manifest must use the existing `current_museum_native_products_v1` format,
pin every artifact by SHA-256 and include the original official Safe inputs.
`OWNER_PRODUCT_ROOTS` in the new module is the explicit root inventory: the
existing token roots plus OwnerRecords, CollectionAttestations, IndependentReads,
ConservationFloor and the DIRECT receipt interface. Supply their complete native
creation/runtime link closure, ABI, method identifiers, metadata and AST from
each producing compilation. The token graph also requires the existing
authenticated `graphImmutableProjection`, including declaration parents. This
command neither compiles nor discovers replacement artifacts. Deployment checks
retain the 24,576-byte runtime and 49,152-byte full-initcode bounds.

Before signing the paid mint, the bridge admits the original native sale under
the exact DIRECT module type/version/interface, binds an actual ConservationFloor
through the delayed Executor, and grants only collection-1 authorization class 7
for the CONSERVATION family to the governor Safe. That Safe explicitly declares
WAIVED. Floor read/producer/call configuration is 300,000/1,000,000/2,000,000 with
failure class 2; these are local fixture values, not gas-conformance evidence.
The bridge checks the original complete DIRECT and first-sale floor receipts.
This WAIVED path does not establish the MUSEUM/LITE documentary floor.

The original paid-mint evidence retains its EOA buyer. A separate actual
`transferFrom` transaction moves that token to a distinct official two-owner
Safe; the sender, receipt, Transfer event and current owner are checked before
constructing OwnerRecords. Its original manifest CID and constructor/runtime
bindings are checked. Five owner publications then run through the existing
direct and relayed Safe recipe after media publication, before the final block
is selected. Controlled local entropy remains explicit.

The combined schema registry reuses a definition only when its status is ACTIVE
and its declaration hash, complete specification, ordered chunk hashes, every
chunk and reconstructed bytes match exactly. A retired or conflicting definition
fails; an absent definition uses the original delayed registration and full
readback. Repeated chunks retain their order.

`owner-anchor.json` copies the account capture's final Core/block identity and
adds all five selected records. `owner-plan.json` and `owner-input-pins.json`
pin the loan/valuation transaction selection and input hashes. The same Anvil remains alive for
the RPC history capture and offline dossier export into `owner-dossier`.
Original account source files remain byte-identical; canonical ancestor history
retains its 256-block bound. A failed run leaves its evidence/journal for diagnosis
and does not restart a partially completed ceremony.

The focused pure/transport-double tests cover composition order, original
receipt encoding, exact schema reuse, genuine-transaction requirements, explicit
waiver setup, refusal cases, integer preservation and process ownership:

```text
python -m unittest tools.museum.test_current_owner_rpc_capture tools.museum.test_current_owner_rpc_commerce -v
```

They do not execute a compiler, Anvil, paid mint or actual RPC capture. The
integration/testing owner must authenticate native inputs, run the joined
composition and replay both outputs before claiming positive capture acceptance.

## Optional Genesis Registry coverage at the same anchor

The same command can add the frozen [Genesis Registry coverage
profile](../tools/museum/GENESIS-REGISTRY-COVERAGE-V1.md) after the original owner
dossier export. Supply both optional arguments:

```text
--registry-runtime-bridge REVIEWED_RUNTIME_SOURCE_ARTIFACT --registry-runtime-bridge-hash EXTERNAL_KECCAK256
```

The exact nonempty artifact bytes and their external Keccak-256 commitment are
checked before the existing process starts. The artifact must already have been
reviewed for runtime/source admission. The adapter retains and byte-pins it;
neither the adapter nor Registry reader verifies its admission semantics. The
reader's fixed `SOURCE_REVISION` is a reader review checkpoint, separate from the
actual deployment build and its `nativeInputManifestSha256`.

After replaying the original account package and OwnerRecords source, the adapter
uses their shared final block without selecting another block. It reads the
selected CollectionMetadata pointer and preserves its original
`admissionModuleRegistry`, even if Core's current registry differs. Exactly six
role addresses receive their expected runtime hashes from the original deployment
artifacts: Core, selected Metadata, admission ModuleRegistry, SchemaRegistry,
chunk store and governance. The Registry source checks those pins against the
recorded code and graph. Its closed twelve-field anchor carries the original
eight common source fields; collection and token identity remain in the separate
cross-source join.

All 51 fixed-plan names are looked up. Absent, deprecated, archived and conflicting
documents remain explicit outcomes; the adapter performs no registrations. It
retains discovery calls, replays both discovery and complete Registry coverage,
and checks common source state, shared getter results and runtime pins against
the concrete account and owner sources before publishing:

- `registry-coverage/`: independently pinned, network-free replay package.
- `registry-discovery-transcript.json`: original same-block discovery calls.
- `registry-runtime-bridge.bin`: exact supplied admission artifact bytes.
- `registry-capture.json`: input pins, all coverage outcomes and cross-source join.

The existing account and owner packages and returned valuation manifest hash are
unchanged. Pin the coverage manifest hash independently and verify it with:

```text
python -m tools.museum.genesis_registry_coverage_v1 verify NEW_OUTPUT/registry-coverage --manifest-hash COVERAGE_HASH
python -m unittest tools.museum.test_current_owner_registry_capture tools.museum.test_current_owner_rpc_capture -v
```

The coverage verifier proves the retained Registry package under its original
qualifications. The outer join report alone does not verify the separate account,
owner or admission artifacts; retain their original pins and verifiers. New
checks use transport doubles, including all 51 lookup outcomes and refusal of
changed source, native-manifest, role or block identities. Actual joined RPC
execution remains with the integration/testing owner. This adapter does not
establish full Registry history, a complete object dossier or the full VIEW
workflow.

## Validation boundary

The three Solidity cases are ABI/type-checked and authored for the next native
run. Ten focused Python cases pass: exact public fixtures and schema shapes,
native six-marker/JSON correspondence, original codec, synthetic owner and
canonical-receipt replay, source/receipt omissions, external pins, disclosure,
no-overwrite and honest refusal of the existing recorded account package when
its four-format inputs are incomplete. The synthetic RPC test mocks only the
base package presence and its RPC responses; it is not a captured chain.

No positive actual OwnerRecord capture, four-format OwnerRecord derivative
acceptance, full-current native runtime, transaction-gas conformance or
institutional acceptance is claimed by this source handoff.
