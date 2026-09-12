# Stream Museum Semantic Mapping: CIDOC CRM, Linked Art and Getty TGN

Specification status: Draft

Adopted into Stream's full-v1 scope by the owner on 12 September 2026, with
the incorporation decisions in [ADR 0036](adr/0036-museum-semantic-profile.md).
Draft is the specification lifecycle status; the delivery commitment is accepted.
The registered documents, implementations and conformance evidence remain to be
delivered. Adoption does not claim their completion or an onchain governance action.

This addendum assumes delivery of the complete Stream specification. It adds a
museum semantic profile and geographic authority mapping to the existing
descriptive, preservation and dossier targets. The [delivery plan](../ops/MUSEUM_DELIVERY.md)
builds these in parallel with contract implementation and testnet engineering.
Initial contract testing can proceed before museum conformance is complete;
full-v1 acceptance retains every requirement below.

## Purpose

An institution receiving a Stream work should be able to understand what the work is, who contributed to it, which files and physical objects belong to its history, where relevant events occurred, and who supplied each statement. It should receive that information in a form that connects to other museum collections without reconstructing the relationships from prose.

The division of responsibilities is:

| Standard or existing Stream surface | Responsibility |
| --- | --- |
| CIDOC CRM | Conceptual relationships between cultural objects, information, people, places and events |
| Linked Art | A practical, constrained JSON-LD expression of those relationships |
| Getty TGN | Shared geographic authority identities and contextual information for places |
| Existing Getty AAT, ULAN, VIAF and Wikidata references | Existing terminology and identity alignments; complemented by TGN |
| Existing Stream records and their authority model | Original statements, evidence, authorship, signatures, chronology and applicable finality |
| Existing LIDO profile | Collections-management interchange of descriptive information |
| Existing PREMIS profile | Preservation objects, events, agents, rights and fixity |
| Existing IIIF profile | Presentation and access to image, audiovisual and related resources |
| Existing dossier, BagIt and OCFL provisions | Complete, verifiable archival delivery |

These are complementary views over a common, attributed record. The artist's writing remains part of that record.

## 1. Scope and normative homes [MSM-SCOPE]

1. Stream must provide a registered museum semantic profile, attributed semantic assertions and reproducible semantic exports as specified here. Support applies to still images, audiovisual works, software and interactive works, physical realizations, documentation and composite works; applicability depends on the supplied evidence, not the file extension of the main artwork.
2. This document must own the new mapping rules and profile payload definitions. Existing definitions must retain their normative homes:

   | Definition | Existing home in `docs/collection-metadata-contract.md`, unless otherwise stated |
   | --- | --- |
   | Record primitive, algorithm-tagged `HashRef` and canonicalization identifiers | V1 Onchain Record Primitive; canonical hashing and serialization |
   | Meaning-bearing payload retention and enumerable pointers | `[CMC-RECORD-PAYLOAD]`, `[CMC-PAYLOAD-POINTERS]` |
   | Token, media, scope and collection subject derivation | `[CMC-SUBJECT-ID]` |
   | Record history and supersession | `[CMC-RECORD-CHAIN]` and the applicable family lifecycle |
   | Artist authority and record-family authorization | `docs/stream-artist-authority.md`; `[CMC-AUTHZ]` |
   | Artist intent and interview | `[CMC-ARTIST-INTENT]`, `[CMC-GENESIS-SCHEMAS]` |
   | Work description and LIDO | `[CMC-TOMBSTONE]` |
   | Preservation, formats and IIIF | `[CMC-PREMIS-PROFILE]`, `[CMC-IIIF]` |
   | Rights, accession, title, custody and loans | `[CMC-RIGHTS-SCHEMA]`, `[CMC-OWNER-RECORDS]`, `[CMC-EXHIBITION-LOAN]` |
   | Schema documents and their immutable versions | `[CMC-SCHEMA-REGISTRY]`, `[CMC-GENESIS-SCHEMAS]` |
   | Dossier content, packaging and institutional validation | `[CMC-OBJECT-DOSSIER]`, `[CMC-PACKAGING]` |
   | Finality and recovery | Applicable finality sections and `docs/stream-long-term-architecture.md` |

3. No semantic alignment or export must change Core identity, hash preimages, signing domains, rights, ownership, custody, finality, or the authority of an existing record. This addendum introduces no new Core selector, event, subject domain, payment behavior or freeze exception.
4. The permanence classification must be:

   | Surface | Class |
   | --- | --- |
   | Existing record, subject, authorization, registry and finality mechanisms used by this addendum | Permanent; inherited unchanged from their homes |
   | Registered profile/schema entries and additional record-family catalog entries | Replaceable-layer catalog state through those mechanisms; each published version has immutable meaning |
   | Exporters, reconciliation interfaces, indexing, validation and archival tools | Operational, with reproducible, archived implementations where required below |

5. Protocol support for the profile must be part of the museum interoperability target. A Getty match, ontology classification or semantic-review approval must not become an additional Core mint or finality condition. Existing required records and evidence remain required under their own specifications.

## 2. Standards baseline and registered documents [MSM-PROFILE]

The adopted baseline is CIDOC CRM 7.1.3 and Linked Art Model 1.0.0, expressed using JSON-LD 1.1. Linked Art identifies that CRM version as its conceptual baseline. The Stream profile fixes a supported subset and its exact dependencies rather than following an unversioned "latest" standard. [Linked Art model](https://linked.art/model/)

1. The following exact schema names must enter the schema catalog through `[CMC-GENESIS-SCHEMAS]` and `[CMC-SCHEMA-REGISTRY]`. Their schema IDs follow the existing exact-name derivation; this document does not introduce another derivation.

   | Schema name | Content |
   | --- | --- |
   | `STREAM_MUSEUM_SEMANTIC_PROFILE_V1` | Standards lock, supported classes and relationships, source-to-target crosswalk, authority/place definitions, projection policy, deterministic serialization rules and validation requirements |
   | `STREAM_SEMANTIC_ASSERTION_V1` | Entity declarations and attributed mapping assertions, including TGN alignments and their evidence |
   | `STREAM_SEMANTIC_EXPORT_V1` | A semantic package manifest identifying the source state, profile, entity resources, assertion sidecar, authority snapshots and validation/coverage reports |

2. Each document must be a canonical, registered JSON Schema document with its interpretation-critical definitions retained as onchain bytes under the existing registry rules. The profile document must include machine-readable mapping tables and versioned validation definitions as schema annotations or referenced registered documents; a prose URL alone is insufficient.
3. The profile must pin the exact Linked Art context, applicable ontology/class/property definitions, validation schemas, classification catalog and crosswalk bytes. The lock must record each dependency's source URI, stated version or source commit, retrieval date, media type and `HashRef`. All interpretation-critical dependencies must be available through the existing state-readable document/pointer mechanism; mirrors supplement those bytes.
4. `https://linked.art/ns/v1/linked-art.json` must be treated as an identifier resolved to the profile's pinned context bytes during verification. Its live response must not redefine historical exports. Imported or nested contexts must be included in the dependency lock. Validation must run without remote context fetching. [Linked Art JSON-LD](https://linked.art/api/1.0/json-ld/)
5. The profile must use only the classes, properties and controlled terms enumerated in its registered mapping tables. Linked Art's use of extensions such as CRMdig for digital objects must be identified explicitly; the export must not be described as using only CRM core when it uses those extensions.
6. A change to mapping meaning, supported ontology version, dependency bytes or projection policy must create a new profile/schema version and explicit supersession lineage. Old records and exports must continue to verify with their original documents. Existing `STREAM_WORK_DESCRIPTION_V1`, LIDO and PREMIS schemas must not be silently widened or reinterpreted.
7. Conformance claims must distinguish the Stream profile, the Linked Art data model/JSON-LD representation and the Linked Art API. This specification requires an archival semantic package; it does not require a live Linked Art HTTP API. URN-identified archival resources must not be presented as satisfying API requirements for dereferenceable HTTP(S) entity identifiers. An optional API adapter must validate against the API separately and publish a reversible identity correspondence to the canonical archival entities. [Linked Art Digital Object API](https://linked.art/api/1.0/endpoint/digital_object/)

8. Every onchain assertion and export-manifest payload must fit the existing
   `MAX_RECORD_PAYLOAD_BYTES` limit; every schema/dependency document must use
   the registry's existing bounded document and pointer mechanisms. A profile
   must partition large mapping tables and dependency closures into individually
   identified, hash-bound documents, with a deterministic index and finite
   document, reference-depth and aggregate-byte limits. It must validate those
   limits before publication. No unbounded ontology blob, silent truncation,
   hash-plus-live-URL substitution or increased Core limit is permitted. Full
   meaning remains recoverable from the retained closure; external descriptive
   evidence uses the applicable archival rules. The machine-readable profile
   must fix its operational limits and boundary fixtures before registration.

## 3. Entities, identity and references [MSM-IDENTITY]

1. The semantic model must distinguish the entities below. An entity may have several supported classifications, but one identifier must not collapse different entities merely because they share a title, filename, owner or visual appearance.

   | Entity | Identity boundary |
   | --- | --- |
   | Artwork or intellectual content | The authored work/content being described |
   | Token | The existing Stream token identity and its protocol state |
   | Digital object | A particular identified file or digital resource; versions and derivatives remain distinguishable |
   | Physical object | A particular print, proof, installation component, carrier or other material object |
   | Realization or presentation | An evidenced configuration, manifestation or presentation of a work, linked to its components |
   | Person or organization | A credited or acting party; distinct from its wallet, account, signature and authority-file record |
   | Place | A geographic entity with a stated spatial/temporal interpretation |
   | Event | A particular creation, printing, interview, exhibition, preservation or other activity |
   | Statement/document | An attributed text, interview, instrument or other information resource |
   | Series, collection or package | A grouping whose membership is explicit; grouping does not imply ownership or physical composition |

2. Existing Stream subjects must use `[CMC-SUBJECT-ID]` unchanged. Supplemental people, places, physical objects, events and content entities must use stable absolute IRIs stored in source or semantic records. They must not be manufactured as new protocol subjects.
3. For an entity without an existing durable identity, the profile must permit a once-assigned `urn:uuid:` IRI. Exporters must preserve that IRI across drafts, publication, host changes and subsequent export versions. An archive must be able to resolve a packaged entity through the package index without an HTTP service. A resolvable web alias may supplement its identity.
4. Entity declarations must record the relationship between the supplemental IRI and each relevant Stream subject, media object ID, source record or external identifier. A token-to-work binding must be a typed relationship, never implicit equivalence between the token and its represented content.
5. A file's role, storage address and checksum must not substitute for its entity identity. The same digital object may have several declared roles and verified access points. Distinct physical prints must retain distinct identities even when produced from the same file. A byte-identical copy must not automatically merge a separately accessioned object or another artist's record.
6. Every exported entity reference must resolve either to an entity in the package index or to an explicitly declared external reference. The validator must reject incompatible entity kinds among selected declarations, unreported dangling local references and replacement of stable entity IDs during an ordinary metadata revision. A conflicting declaration from an unselected source remains attributed in the assertion sidecar with its collision diagnostic; it must not overwrite the selected entity or make a third-party identity collision alone prevent an otherwise valid export.
7. A supplemental entity match must not prove that two artists, wallets, works or tokens are the same. Identity reconciliation must remain an attributed assertion with the scope and evidence required in `[MSM-ASSERTIONS]` and `[MSM-AUTHORITIES]`.

8. An entity declaration must identify its exact source record and declaration
   hash/selector, declaring agent, authority class and subject binding. Reuse
   must cite that declaration and its lineage; an IRI is a reference, never
   proof of authority to revise its declaration, merge another work, or bind a
   token. The export's selected declaration must come from its declared source
   authority policy under [MSM-ASSERTIONS] rule 9. Corrections and explicit
   merge/split mappings must preserve predecessor identities and provenance;
   matching text, first arrival and namespace resemblance confer no authority.
   This is source-selection bookkeeping through existing record families, not
   a new protocol subject, ownership registry or signing authority.

## 4. Required crosswalk coverage [MSM-MAPPING]

1. The registered crosswalk must include the following entity and relationship patterns. These are Stream's required mapping coverage, not a claim that Linked Art provides a universal class for every artistic practice.

   | Source meaning | Linked Art/CRM projection |
   | --- | --- |
   | An abstract work or conception explicitly distinguished from its carriers/content | `PropositionalObject` / CRM E89; use only when the source makes this distinction, rather than adding an artificial extra work for every file |
   | A person's identity | `Person`; retain names and identifiers separately |
   | A museum, studio or other organization | `Group`; roles attach to the relevant activity or relationship |
   | A physical print, proof or material component | `HumanMadeObject`; physical dimensions and material attach to that object |
   | A file, recording, project, digital master or derivative | `DigitalObject`; digital dimensions, format and access points attach to that resource |
   | Identified visual content | `VisualItem`; linked to a digital carrier through `digitally_shows`, or a physical carrier through `shows` |
   | Artist text, transcript or instructions as linguistic content | `LinguisticObject`; a digital file `digitally_carries` it |
   | Nonlinguistic sound, structured multimedia or software content | CRM E73 `InformationObject` where applicable, explicitly identified in the Stream/CRM extension sidecar; its digital carrier is a separate `DigitalObject` in the Linked Art projection |
   | Creation of intellectual content or a digital object | `Creation`, connected through `created_by` |
   | Production of a physical object | `Production`, connected through `produced_by` |
   | Interview, exhibition or other evidenced activity | `Activity` or a supported more-specific class; participants, roles, time and place remain distinct |
   | Geographic place | `Place`; event locations use `took_place_at` |
   | Place represented in visual content | `represents`, with the appropriate content entity as subject |
   | Place discussed by a document/work | `about`, with a supported information entity as subject |
   | Names and identifiers | `identified_by` with the appropriate `Name`/`Identifier`; `_label` is a display aid |
   | Classifications, materials and techniques | Appropriate `classified_as`, `made_of` or activity `technique` patterns, preserving their different meanings |
   | Grouping of related works or resources | `Set` membership where applicable; physical or conceptual parts use their specific part relationships |

   Linked Art distinguishes information from its digital or physical carriers and uses Creation for digital objects, Production for physical objects. Those distinctions are retained here. [Digital model](https://linked.art/model/digital/)

2. Each crosswalk entry must specify: source schema/version and field selector; source subject kind; target class/property path; cardinality; transformation; applicable authority; controlled terms; uncertainty treatment; reverse correspondence for supported values; and a named positive and negative test vector. A heading such as "mapped to CRM" is insufficient.
3. The crosswalk must cover the complete applicable Stream source set: work description, artist identity/attribution, artist intent, interview and instrument, rights, media and dependencies, media relationships, preservation objects/events/agents, condition, reference renders, accession/title/custody, exhibitions/loans, citations and dossier provenance. A record not present in the selected source state must not be invented to fill the graph.
4. Audio, video, software and interactive materials must retain their digital-object identities, durations and technical descriptions, source/dependency relationships, associated activities and documentation. Their content must use only a semantically valid supported information class. Visual and linguistic components may be identified separately when evidenced; a music recording must not become a `VisualItem`, and software behavior must not become a human `Person` or `Group`. Natural speech and transcripts may be modeled as linguistic content, but computer code must not be classified as linguistic content merely because it is readable text. A generic E73 content entity must not be forced into Linked Art's textual-work carrier relationship. The extension crosswalk must preserve its precise source relationship and identify any target property it cannot express. [CRM 7.1.3 class definitions](https://cidoc-crm.org/sites/default/files/Documents/cidoc_crm_version_7.1.3.html), [Linked Art abstract-work model](https://linked.art/api/1.0/endpoint/abstract_work/)
5. Where a source meaning has no faithful Linked Art pattern in the pinned baseline, the exporter must retain it as a typed Stream assertion/source reference in the companion sidecar and report `retained_stream_only`. It must not invent a standard property, flatten the fact into a misleading relationship, or silently discard it. This rule includes execution environments, byte-level derivation, some realization relationships and protocol-specific evidence.
6. Preservation events projected into the museum graph must remain linked to their complete PREMIS records. Software agents, fixity results and C2PA validation must retain their existing evidence semantics; a museum Activity projection must not replace the preservation record or imply that a successful safety scan proves artistic authorship.
7. Exact dates, ranges, approximate dates and unknown dates must remain distinguishable. The original date expression, precision and any calendar/timezone must be preserved. Serialization into a `TimeSpan` must express bounds rather than inventing an exact event time. Capture, completion, file export, recording, upload, mint and accession dates must not be substituted for one another.
8. Measurements must retain entity scope, measurement type, value, unit, precision and source. Pixel dimensions, physical sheet dimensions, image-area dimensions, duration and file size must remain separately typed. Unit conversion must preserve the original value/unit and identify the conversion; an export must not silently round an archival measurement.
9. Captions, artist statements, biographies, interviews and care instructions must remain available as attributed, language-tagged content with their original source references. Controlled classifications must supplement the artist's prose. A generated summary or translation must identify its derivation and must not replace the source text.
10. The semantic package must declare one of `complete_for_profile`, `complete_with_stream_extensions`, or `incomplete`. `complete_with_stream_extensions` is permitted when every source value is accounted for but some require the Stream sidecar. `incomplete` must identify missing/invalid required inputs; it must not be advertised as a conformant complete dossier.

## 5. Semantic assertions and authorship [MSM-ASSERTIONS]

1. `STREAM_SEMANTIC_ASSERTION_V1` must carry the following required structure. References to existing Stream values use their existing types and hash rules.

   | Member | Required meaning |
   | --- | --- |
   | `profileSchemaId`, `profileHash` | Exact registered semantic profile being used |
   | `anchorSubject` | Existing Stream subject kind/ID; verified against the enclosing record |
   | `entities` | Zero or more supplemental entity declarations with stable IRI, entity kind, names and source references |
   | `assertions` | One or more independently identified assertions in this recorder's voice |
   | `sourceRecords` | Exact record hashes, subject IDs, schemas and record-chain references used as evidence; never a bare "latest" pointer |

2. Each assertion must have a stable assertion IRI; subject IRI; registered relation/type identifier; exactly one entity object or typed literal value; asserting-agent reference; creation time; evidence/source selectors; origin; review status; and a rationale where interpretation is involved. Effective date/range, language, source confidence and references to assertions it corrects or disputes must be supported when applicable.
3. `origin` must be one of `direct_statement`, `human_mapping`, `automated_mapping`, or `derived_projection`. `reviewStatus` must be one of `unreviewed`, `reviewed`, `disputed`, or `withdrawn`. A reviewed assertion must identify the reviewer, time and immutable authenticated review evidence binding the exact assertion revision/hash and mapping/profile. Naming a reviewer in someone else's payload does not prove that reviewer approved it: verification must resolve the reviewer's own authenticated statement under the existing record-family/signature rules. Self-review must be explicit and cannot satisfy an independent-review requirement. Status is the recorder's attributed statement; it is not a universal verdict, source-selection authority, or a change to signature verification.
4. Every evidence selector must resolve within immutable referenced bytes: a JSON Pointer into a canonical record, or a typed document/page/time selector anchored to a `HashRef`. An assertion without independent documentary evidence may cite its own signed statement as its evidence, but must declare that basis rather than claiming external corroboration. A qualifying review must be appended separately against an already-published assertion revision/hash; the source assertion need not commit to its future review. Later dispositions cite the existing assertion and review records without introducing a circular commitment or substituting a changed claim for the reviewed revision.
5. Corrections, disputes and withdrawals must use append-only records and the applicable existing supersession rules. A correction must identify its predecessor; a dispute must identify the other assertion. No recorder may rewrite another recorder's assertion. Exports must preserve competing live claims and their attribution; recency alone must not choose truth across authors.
6. The following additional record types must be allocated through the existing record-type catalog, all using `STREAM_SEMANTIC_ASSERTION_V1`:

   | Record type | Inherited authorization |
   | --- | --- |
   | `ARTIST_SEMANTIC_ASSERTION` | `ARTIST_*`; existing artist authority only |
   | `CURATOR_SEMANTIC_ASSERTION` | `CURATOR_*` |
   | `INSTITUTION_SEMANTIC_ASSERTION` | `INSTITUTION_*` |
   | `INDEPENDENT_SEMANTIC_ASSERTION` | `INDEPENDENT_*`; statements in the attestor's own name |

7. These meaning-bearing assertions must use the existing payload-carrying writes and onchain payload retention. Recorders, authorization classes, schema versions and history must be recoverable through the existing read/pointer surfaces. Profile registration must not give its registrant authority over the content mapped with it. `INDEPENDENT_SEMANTIC_ASSERTION` must use the host, signer verification, replay protection, permanent entry/nonblocking behavior, history and renderer read-set firewall of `[CMC-INDEPENDENT-ATTESTOR]`; it must not enter through a newly admin-gated substitute lane.
8. The exporter must distinguish copying an authorized source fact from adding an interpretation. A curator who maps an artist's "Milos, Greece" to a place identifier owns that alignment; the artist continues to own the quoted place statement. A platform-authenticated draft confirmation must not be presented as an onchain artist signature.
9. The default Linked Art projection must use the registered profile's deterministic
   selection rules and a manifest-bound source/reviewer authority set, evaluated
   at the bound source state. The set must identify exact authenticated record
   selectors and the existing family authority for each selected scope; merely
   listing an address or declaring `reviewed` cannot create authority. Only
   eligible, non-withdrawn direct statements and authenticated reviewed mappings
   enter the default graph. An artist may explicitly confirm their own mapping;
   label that as author-confirmed self-review, without requiring an external
   reviewer or describing it as independent review. A live conflict between eligible claims must be
   reported and the affected unqualified triple withheld pending a disposition
   admitted by that same policy; recency never selects truth across authors.
   An independent or otherwise unselected dispute must remain visible in the
   scoped sidecar and conflict report, but cannot by itself suppress an
   artist-authorized default dossier claim. A qualified reviewer may acknowledge
   it in their own authenticated record, with that review's scope and effect
   explicit. Unreviewed claims, alternatives and withheld triples retain their
   original evidence and attribution. A researcher view may select different
   claims but must declare its policy and cannot present them as the artist's
   approved account. Selection affects this dossier view only: it cannot grant
   a reviewer a protocol veto, alter an original record, block independent-lane
   entry, or change default `tokenURI`/renderer inputs and their firewall.
10. Every emitted semantic claim must have a provenance-index entry linking its entity/property path and value to the exact source assertion or record selector and mapping rule. Shared claims may cite several sources. Labels copied from an authority snapshot must identify that snapshot; they must not appear as artist-authored wording. Linked Art's assignment patterns can express selected attribution, while Stream retains the full source/version history. [Linked Art assertions](https://linked.art/model/assertion/)

## 6. Authority alignment and Getty TGN [MSM-AUTHORITIES]

1. The profile must add `GETTY_TGN` geographic alignments alongside the existing creator and terminology authority references. A local person, place or term must remain valid without an external match. The absence of a TGN record must not block saving, artist confirmation or otherwise valid museum export.
2. An authority-alignment assertion must include:

   | Member | Meaning |
   | --- | --- |
   | `entityId` | The Stream-side entity being aligned |
   | `authority` | Registered authority code, including `GETTY_TGN` |
   | `identifier` | Authority-native identifier as a string |
   | `canonicalIri` | Authority-issued vocabulary/entity IRI, distinct from HTML, JSON or RDF document URLs |
   | `focusIri` | Real-world entity focus IRI when supplied by the authority; otherwise explicit absence |
   | `matchKind` | `equivalent_entity`, `close_match`, or `related_reference` |
   | `snapshotRef` | Archived source representation and `HashRef` |
   | `retrievedAt` | Retrieval timestamp |
   | `authorityRevision` | Supplied revision/release information, or an explicit `not_supplied` value |
   | `labelAtReview` | Label/language actually reviewed, preserved as a snapshot value |
   | `basis` | Rationale and relevant evidence selectors, with the assertion's author/reviewer provenance |

3. The profile must treat TGN identifiers as geographic authority identities, not as coordinates, filename suffixes or user-facing place text. Canonical IRIs must be taken from Getty's published identity vocabulary. The usual entity form is `http://vocab.getty.edu/tgn/{identifier}`; changing its scheme, adding a document extension or following a redirect must not silently mint a different identity. Retrieval may use a secure document endpoint while preserving the canonical entity IRI. [Getty semantic representation](https://vocab.getty.edu/doc/)

   Getty distinguishes the vocabulary subject `.../tgn/{identifier}` from its real-world place focus `.../tgn/{identifier}-place`. Both identities and the evidenced focus relationship must be retained when supplied. The Linked Art adapter must follow its documented Place alignment convention; a general CRM/RDF adapter must distinguish the concept from its place focus and must not equate them. [Linked Art Place API](https://linked.art/api/1.0/endpoint/place/)
4. Match production must include entity-type and geographic-context checks. Name equality, a search ranking, an LLM suggestion or nearby coordinates alone must not establish `equivalent_entity`. An automated suggestion must start `unreviewed`; an accepted alignment must identify the responsible reviewer and evidence.
5. The registered crosswalk must state how each match kind is represented for each target class. `equivalent_entity` may yield a Linked Art `equivalent` relationship only when the pinned class/profile permits it and the assertion supports identity. That relationship uses Linked Art's `https://linked.art/ns/terms/equivalent`, not `owl:sameAs` or `skos:exactMatch`. Weaker matches must not be promoted to identity. SKOS concept-mapping predicates must not be applied indiscriminately to real-world people or places; where the target profile has no faithful weaker relation, the alignment remains in the Stream sidecar. [Linked Art equivalence term](https://linked.art/ns/terms/)
6. The snapshot must preserve the relevant authority record and the labels, types, hierarchy assertions and other source values actually used by the mapping, together with source attribution and reuse terms. A digest of a live URL without those bytes is insufficient. Stream need not archive all of Getty TGN for each work.
7. A subsequent authority rename, merge, split, deprecation or hierarchy change must not rewrite an existing assertion or historical export. Reconciliation must create a new assertion, cite the new snapshot, and explain the disposition of the old match. Original identifiers and evidence must remain resolvable from the old package.
8. Authority lookup must be an authoring/indexing convenience. Reading, verifying or reconstructing an archived record must not require a Getty account, API key, live SPARQL endpoint or availability of the original website. Getty publishes per-record linked-data representations and dataset distributions; the profile uses archived source bytes rather than relying on a particular service remaining operational. [Getty LOD access](https://www.getty.edu/research/tools/vocabularies/lod/index.html)
9. ULAN, VIAF, Wikidata and AAT alignments must follow the same attribution, snapshot and non-escalation principles. External recognition of a person or institution must not grant Stream artist, curator, owner or institution signing authority.

## 7. Place descriptions and event geography [MSM-PLACES]

1. A place entity must support: stable local IRI; preferred display name; alternate/historical names with language and applicable dates; human-readable context; supported place classification; source references; optional authority alignments; and optional geometry. Each substantive value must have attributable evidence.
2. Place associations must record their role explicitly. The baseline roles must cover `capture_location`, `creation_location`, `depicted_place`, `subject_place`, `production_location`, `interview_location`, `exhibition_location`, `custody_location`, and `publication_location`. Custom roles require a registered profile extension; they must not enter an untyped catch-all place field.
3. Event roles must map through the relevant event's `took_place_at`. Depiction and aboutness must use the content's appropriate relation. A photographer's position, the coast visible in an image and the studio where editing occurred must not automatically become the same place or event.
4. A broad place must remain broad. An island-level statement must not become an exact beach, building or coordinate without additional evidence. A fictional or unidentified place may retain a local identity and description; it must not receive a real-world authority match merely to satisfy an input requirement.
5. Geographic containment must distinguish asserted physical/spatial containment from an authority's catalog hierarchy and from political/administrative affiliation. A copied authority hierarchy must retain its source, scope and historical applicability. It must not silently become an unqualified claim about modern sovereignty.
6. Geometry, when supplied for publication, must record its representation/coordinate reference system, precision or uncertainty, source and applicable date. Coordinates must be optional. Missing geometry must not be filled with an invented point; a regional centroid must be labeled as such and must not imply the artist's capture position.
7. Authoring systems must allow a public place statement at the level of precision the contributor intends to publish. This profile does not create a private-material intake channel. Any institutionally restricted material supported by other Stream families retains those families' access/disclosure rules and must not be exposed by this public semantic projection.

## 8. Relationships, evidence and authority boundaries [MSM-RELATIONS]

1. The profile must preserve distinct source relationships for: work membership in a series; work-to-token binding; digital carrier/content; physical carrier/content; original/derived file; master/display/print-output roles; transcript/recording/instrument; software/dependency/environment; work/reference render; physical production; and presentation/exhibition. Generic `related` links may supplement a record but must not replace a known, more precise relationship.
2. A full-size master, display JPEG, original capture, working project, color profile, preset, interview recording, transcript and other supporting file must remain separately describable digital objects when supplied. The graph must support arbitrary additional documentary resources through typed roles and attributed relations, without requiring each to be a new top-level artwork or a new Core contract field.
3. Asset presence must be stated from actual ingest evidence. A filename mentioned in an interview or sample is a described resource, not proof that the file was received, validated, archived or included in the package. The export must distinguish `described_only`, `received`, and `verified_archival` resource states and cite the corresponding evidence for the latter two.
4. Archival verification, file fixity and website safety scanning must remain separate assertions. A safety scan must retain its scanner/version/result reference under the applicable ingest/preservation schema; it must not stand in for fixity, format validation, rights clearance or authorship. Referenced uploads remain subject to the website's applicable safety scanning and file-type validation before publication; the semantic exporter must not provide an unscanned publication path.
5. A physical object's creation, custody, legal title and museum accession must remain separate assertions/events. A token transfer, file upload, CC0 declaration, exhibition or authority match must not create an `Acquisition`, `TransferOfCustody`, accession or physical-ownership claim without the corresponding authoritative source record/instrument.
6. Artist preferences and instructions must remain identified as intent, not observed events. Proposed exhibitions, expected printing and future preservation work must not be exported as completed activities. The profile must preserve `planned`, `completed`, `cancelled`, or `unknown` event status in its source/sidecar and use only supported target patterns that retain that distinction.
7. Rights must stay scoped to their existing subject and instrument. Fixed Keys and Gates CC0 terms must map from the actual applicable rights/program record; the exporter must not turn them into a proposed license or infer that every interview, third-party document, person depicted or authority-data snapshot has identical rights.

## 9. Export, deterministic verification and archival delivery [MSM-EXPORT]

1. Object-dossier exports under the expanded museum profile must include a semantic package validated against `STREAM_SEMANTIC_EXPORT_V1`. The package must contain the following components, included in the existing BagIt manifests:

   | Component | Required content |
   | --- | --- |
   | Semantic manifest | Profile/schema IDs and hashes; source-state bindings; selection-policy hash and exact source/reviewer authority set; component paths and `HashRef`s; completeness status; separate Stream-profile, Linked Art model and optional API conformance results |
   | Entity index | Stable entity IRIs, kinds, resource paths and representation classification: `linked_art`, `stream_extension`, or `external` |
   | Linked Art resources | One bounded JSON-LD resource per entity classified `linked_art`, using the pinned profile; Stream-only entities resolve to their typed sidecar entries |
   | Assertion sidecar | Complete applicable attributed assertions, including alternatives and Stream-only facts |
   | Provenance index | Source record/assertion and crosswalk rule for every emitted semantic claim |
   | Authority snapshots | Exact source bytes used for authority reconciliation, with attribution/reuse metadata |
   | Dependency lock and documents | Pinned schema/context/crosswalk/validation documents needed for offline interpretation |
   | Coverage and validation reports | Accounted-for source fields, conformance results, warnings and errors |

2. The source-state binding must identify chain ID, Core, collection, applicable token/scope, canonical subject/citation, block number and block hash, finality qualifier, source record hashes/chain heads and exact semantic assertion records included. It must also declare the authorized source/disclosure scope before field coverage is evaluated. That scope must apply to every package component, including sidecars, provenance indexes, authority snapshots, reports and embedded source bytes. Existing restricted institutional families must not leak through any component; a permitted, non-disclosing withheld marker may account for such an excluded resource, without reproducing its restricted values. The export must resolve a specified state, never an unspecified mixture of several "latest" reads. Reorganization or later corrections require a new export with lineage, not replacement of the old evidence.
3. `ARCHIVE_SEMANTIC_EXPORT` must be an additional archive-family record type using `STREAM_SEMANTIC_EXPORT_V1` and the existing `ARCHIVE_*` authorization. It records the archivist's derived export and input commitments. It must not be treated as `publishCollectionSnapshot`, acquire authority over source families, or make an archivist the author of the underlying artist/owner/institution claims. Anyone may independently generate and verify an unrecorded export.
4. A recorded export's meaning-bearing manifest must use the existing payload retention rules. Export resources and large authority evidence must use the existing archival rules; the object-dossier bag must embed the semantic manifest, JSON-LD resources, sidecars, schemas, contexts, mapping rules, validation definitions and relevant authority snapshot bytes so semantic interpretation is offline. Large referenced artwork media follow `[CMC-PACKAGING]` without weakening render-critical embedding requirements.
5. Canonical JSON hashing must use the registered RFC 8785 JCS profile. Enclosing onchain record payloads must follow `[CMC-RECORD-PAYLOAD]` exactly, including its fixed `HASH_KECCAK256` requirement; the availability of other registered algorithms does not change that carrier rule. Child resources, media and authority snapshots must use their applicable registered `HashRef` profiles, and BagIt manifests retain `[CMC-PACKAGING]`'s hash requirements. The exporter must reject duplicate JSON keys and invalid JCS input. It must not apply an unregistered text-normalization step that changes original artist content or pre-existing source hashes.
6. Deterministic export must fix entity partitioning, embedding depth, property emission, array ordering and source-selection policy in the profile. Stable entity IRIs must not be replaced with export-run IDs. Referenced nodes must have stable IDs; nested value nodes may be anonymous only where the profile's fixed structure makes their serialization deterministic.
7. Ordered source values must retain their order. Unordered collections must be sorted by the profile's declared stable key, with a specified tie-breaker over their canonical value bytes. Export-time timestamps, random IDs and nondeterministic tool output must be excluded from canonical entity resources. Run metadata belongs in a separate manifest/report; identical source state and profile must produce identical canonical resource hashes.
8. JSON byte canonicalization must not be represented as RDF graph canonicalization or proof of semantic equivalence. JSON-LD expansion and semantic validation must use the pinned offline context and vocabulary. Alternative Turtle/RDF exports may be supplied as separately identified derivatives; their digests must not be substituted for JCS digests.
9. Resource discovery and document loading must use the package index and pinned dependency set. Validators must enforce declared size, depth and resource-count limits; reject unsupported required terms; and prohibit arbitrary network resolution, executable context handling and archive-path traversal. These operational limits must be published in the profile bundle, with boundary fixtures and a deterministic resource-splitting rule; they do not change existing onchain write limits.
10. Export manifests must not hash themselves or require a circular commitment between dossier and semantic manifest. The semantic manifest commits to source records and its child components; the enclosing dossier manifest commits to the semantic manifest. The semantic manifest must not include its own subsequently recorded export record as an input source.
11. The existing dossier-generation/reconstruction tooling must be able to regenerate and verify this package without the operator's database or web service. Its source archive, build instructions, dependencies and test vectors must follow `[CMC-OBJECT-DOSSIER]` and the reconstruction-client archival discipline.

12. New semantic schemas must represent protocol integers, including uint256
    token/subject components, as canonical decimal strings (`0` or a nonzero
    digit followed by digits), with their unsigned width checked before use.
    New fields containing addresses, byte strings and hashes must use the
    schema's exact typed representation, including byte length; addresses and
    bytes use lowercase `0x`-prefixed hexadecimal in these new JSON documents.
    Display aliases may be separate. Existing source bytes and their established
    encodings must remain unchanged and separately verifiable. Binary64 JSON
    numbers must never be an intermediate for protocol integers or exact source
    decimals. Exact decimal measurements retain their source lexical value,
    unit and precision. Fixtures must include `2^53 - 1`, `2^53`, `2^53 + 1`,
    `2^256 - 1`, out-of-range values and leading-zero rejection. JCS provides
    deterministic serialization of these typed values; it does not make rounded
    values faithful to their originals.

## 10. Coexistence with existing museum formats [MSM-INTEROP]

1. Linked Art must be an additional dossier representation, not a replacement for LIDO, PREMIS, IIIF or the full Stream source payloads. All applicable outputs must derive from the same source-state binding.
2. The profile must publish a shared-identity correspondence table covering Stream subjects, supplemental entity IRIs, LIDO object/work identifiers, PREMIS object/agent/event identifiers and applicable IIIF resources. The table must identify relationships between different entities instead of forcing every format to use one ID for artwork, token and file.
3. Cross-format validation must compare the applicable title/creator, content and carrier identities, event dates, scoped measurements, rights references and media relationships. Conflicting values must be reported with their source records; an exporter must not silently make one format agree by rewriting an authoritative value.
4. Full fidelity must be evaluated across the complete package for its declared authorized source/disclosure scope. Coverage must be assessed against a schema-versioned inventory of source field paths, including repeated entries, null/absent distinctions, order and exact typed values; an exporter must not define its coverage denominator from only the values it successfully emitted. Every in-scope source field must be assigned `mapped`, `retained_stream_only`, or `not_applicable` with a rule/reason; missing in-scope source bytes or a dropped value must be an error. Where permitted by the source family's disclosure rules, an excluded resource may be accounted for as `withheld_by_source_policy`, without its restricted contents or identifying details being copied into the report. An exporter must not use that marker to hide ordinary missing public evidence. A lossy Linked Art projection may be valid when the complete sidecar/source package preserves the omitted in-scope semantics and the coverage report identifies them. It must not be called a lossless Linked Art conversion or a complete export of records outside its declared scope.
5. Verification must demonstrate both target-model validity and useful institutional reconstruction: a recipient can identify the work, its creators, distinct files/physical objects, event chronology, places, rights references and source authors without private Stream API access.

## 11. Application boundary [MSM-AUTHORING]

This section defines the capture contract for applications; it does not prescribe a frontend framework or require a graph database.

1. Applications must preserve original artist text and allow stable entity references, repeating roles/relationships, language-tagged names, scoped dates/measurements and documentary attachments. Controlled mapping may be completed by artists, registrars or qualified reviewers under their own identities.
2. Artists must be able to provide a normal place name, creator credit, medium description and account of events without knowing CRM class names or Getty identifiers. Reconciliation interfaces may suggest controlled matches, but must expose enough geographic/type context to review a choice and allow no match.
3. A mapping workflow must record who supplied the source statement and who made/reviewed its structured interpretation. Curatorial enrichment must not silently change the version the artist confirmed or enlarge the scope of that confirmation.
4. Database-backed drafts may precede chain identifiers and archival publication. Such drafts must retain stable entity IDs and exact confirmed source versions; export tools must label them `draft_preview` and must not fabricate chain bindings, signatures, receipts, finality or content-addressed media locations. A draft preview is not a conformant recorded Stream dossier.
5. The same capture/mapping module must support initial submission and later documentation. Linking a record to an existing Stream work must use an explicit verified binding, not a match on artist handle or artwork title. Mint preparation and transaction execution are outside this addendum.

## 12. Conformance and acceptance [MSM-CONFORMANCE]

1. Every numbered requirement in this document must be covered by the named gates below. These gate names are adopted requirements, not claims that checkers or tests already exist. Their delivery owners and evidence status are tracked in the [museum delivery plan](../ops/MUSEUM_DELIVERY.md). Evidence must identify the implementation revision, source/profile hashes, test outputs and reviewer disposition.

   | Gate | Requirements | Required verification |
   | --- | --- | --- |
   | `MSM-01-SCOPE` | `[MSM-SCOPE]` 1–5 | Spec/integration review: no new Core semantics, inherited homes and unchanged mint/finality behavior |
   | `MSM-02-PROFILE-LOCK` | `[MSM-PROFILE]` 1–8 | Registered bytes/IDs and complete offline dependency closure; old/new profile version verification; data-model/API claims distinguished |
   | `MSM-03-IDENTITY` | `[MSM-IDENTITY]` 1–8 | Work/token/file/print separation, stable supplemental IDs, dangling-reference/collision rejection |
   | `MSM-04-CROSSWALK` | `[MSM-MAPPING]` 1–10 | Field-level mappings, class/domain/range validation, dates/measurements/media coverage and retained semantics |
   | `MSM-05-AUTHORSHIP` | `[MSM-ASSERTIONS]` 1–10 | Authorization positive/negative tests, independent-lane entry and renderer firewall, immutable evidence selectors, competing claims, source provenance and projection policy |
   | `MSM-06-AUTHORITIES` | `[MSM-AUTHORITIES]` 1–9 | Reviewed/unreviewed matches, wrong entity type, external revision, evidence snapshots and no signing-authority escalation |
   | `MSM-07-PLACES` | `[MSM-PLACES]` 1–7 | Place roles, uncertainty, historical context, coordinates, fictional/unknown place and public precision |
   | `MSM-08-RELATIONS` | `[MSM-RELATIONS]` 1–7 | File-role/derivation/physical-event distinctions; no invented receipt, rights, custody or accession; scan-path parity |
   | `MSM-09-EXPORT` | `[MSM-EXPORT]` 1–12 | Chain-state binding, package-wide disclosure scope, fixed record-payload versus child hashes, offline regeneration, deterministic golden hashes, tamper detection, limits and acyclic manifests |
   | `MSM-10-INTEROP` | `[MSM-INTEROP]` 1–5 | Valid Linked Art plus LIDO/PREMIS/IIIF consistency and complete field-coverage accounting |
   | `MSM-11-AUTHORING` | `[MSM-AUTHORING]` 1–5 | Artist capture without ontology expertise, attribution of enrichment, draft labeling and submission/later-edit reuse |
   | `MSM-12-INSTITUTIONAL` | `[MSM-CONFORMANCE]` 1–4 | Requirement traceability, fixture corpus and existing named-repository/practitioner evidence extended to semantic outputs |

2. The fixture corpus must include at least:

   | Fixture | Required demonstration |
   | --- | --- |
   | Still photograph with a master, display derivative and two physical prints | One content entity, distinct digital/physical objects, separate capture/completion/printing events and distinct pixel/image/sheet dimensions |
   | Written artist interview | Instrument, artist/interviewer roles, date, language and transcript; absence of an AV recording is preserved |
   | Audio/video interview | Recording, transcript, captions/time references, duration and participant attribution remain linked without collapsing their identities |
   | Software or interactive work | Code/dependencies/environment, execution or installation, significant properties, reference output and preservation evidence survive the projection |
   | Historical or disputed geographic attribution | Original statement, local place identity, TGN snapshot, alternatives and later reconciliation remain distinguishable |
   | Incomplete or conflicting documentation | A mentioned-but-unreceived master and conflicting physical-custody statements remain visible as such |
   | Independent curator and artist accounts | No author impersonation or silent selection of one party's claim as universal truth |
   | Fully offline archive and later profile revision | Old package verification succeeds with live sites unavailable and after newer schema/context/authority data exist |

3. Negative tests must include at least: forged reviewer approval; undisclosed self-review; an unselected dispute suppressing an artist-authorized dossier claim; hostile reuse of a stable entity IRI; altered selection-policy inputs; uint256 rounding or overflow; field coverage calculated only from emitted values; dependency closure exceeding its published limits; wrong-role semantic write; blocked independent-lane entry; an independent claim affecting authoritative default renderer output; schema/profile mismatch; an incorrect enclosing record-payload hash algorithm; altered context; tampered source/authority bytes; inferred exact geolocation; false TGN equivalence; mint or upload misreported as physical accession; scan success misreported as provenance validation; restricted source data leaked through a sidecar/report; unsupported JSON-LD term; loss of original language/date precision; silent omission of a source field; duplicate identity with incompatible kind; circular manifest commitment; oversized/hostile resource; and an exporter that requests a live context or authority service during offline verification.
4. The existing `[CMC-OBJECT-DOSSIER]` institutional-validation gate must include the new semantic package: the two named independent repository ingests, registrar/collections-management review and time-based-media conservation review must examine the semantic outputs and loss/coverage reports. At least one recorded review must also assess CRM/Linked Art modeling and authority reconciliation competence. Synthetic fixtures and schema validation must not substitute for the existing external evidence requirement. This is an extension of that gate, not a second competing definition of it.

## Appendix A. AN ALTERATION as a worked-example brief — informative

The user-authored AN ALTERATION record is a useful demonstration fixture. Its text is source testimony for an example, not independently established historical evidence. The supplied preview and written record do not establish receipt of the files named in the narrative.

The example should show:

- The visual content of **AN ALTERATION** as distinct from its Stream token and its digital carriers.
- Elia Maris as the credited person, with the creator statement attributed to its source. No invented ULAN, VIAF, wallet or signing identity.
- **COMMON PASSAGE** as a series/grouping, with the work's membership explicitly stated.
- The supplied preview as an actual supplied resource; the named TIFF master, IIQ capture, working project, color profile and print presets as separately described resources until actual receipt is evidenced.
- Two separately identified physical reference prints, not two interchangeable file copies.
- The stated capture date of 18 May 2026, completion date of 24 May 2026 and interview date of 2 June 2026 as different events.
- Milos, Greece as an attributed place statement with its actual role. A TGN alignment requires a verified record and review; this brief deliberately supplies no guessed TGN identifier or exact capture coordinate.
- A written interview with Elia Maris and Leonie Karras, its instrument and transcript. No invented audio/video recording.
- Separate physical image-area and sheet dimensions, and digital pixel dimensions, attached to the right entities.
- The conflicting statements about the location of the two prints retained for review; neither converted into a completed custody transfer without clarification and supporting evidence.
- Fixed applicable Keys and Gates CC0 terms cited from the program/rights record, while third-party source material and authority snapshots retain their own scoped rights information.

## Appendix B. Incorporation and implementation boundary — informative

This document is the single normative home. The incorporation amendments link to it; publication of executable schemas, catalogs and tools remains tracked work:

| Repository document/surface | Required incorporation |
| --- | --- |
| `docs/museum-semantic-mapping.md` | Adopt this Draft as the normative home for `[MSM-*]` requirements |
| `docs/spec-policy.md` | Add the new document and its classes to the specification inventory |
| `docs/collection-metadata-contract.md`, `[CMC-GENESIS-SCHEMAS]` | Add the three exact schema names and cross-references; register their documents and examples |
| Same document, `[CMC-AUTHZ]`, `[CMC-INDEPENDENT-ATTESTOR]` and record-type catalog | Add the five semantic record types under their existing authority classes; add the independent type/schema to its lane's enumerated list and preserve its host, entry, replay and renderer firewall rules |
| Same document, `[CMC-TOMBSTONE]` | Link to the semantic sidecar and TGN alignment; leave existing versioned work-description semantics intact |
| Same document, `[CMC-OBJECT-DOSSIER]` and `[CMC-PACKAGING]` | Require the additional semantic components for the expanded museum profile; version affected schema/profile documents where their contents change |
| Same document, LIDO/PREMIS/IIIF profile provisions | Link to the shared-identity and cross-format validation requirements without duplicating their definitions |
| `docs/launch-conformance-matrix.md` | Add `MSM-01` through `MSM-12`, identify owners/evidence and extend the existing institutional gate |
| `docs/launch-v1-target-architecture.md` and applicable schema/catalog manifests | Reflect the additive museum profile without altering Core interfaces or identity domains |
| `ops/ROADMAP.md` / `ops/EXECUTION_BACKLOG.md` | Track schema/profile publication, mapping/export tools, capture compatibility and institutional evidence against these anchors |
| ADR / release artifacts | Follow specification-policy amendment rules; record an accepted ADR if amending a Review/Final home; regenerate affected catalogs/artifacts through their owning generators |

The names above are accepted specification allocations, not a claim that registered documents or deployed catalog entries already exist. The release work includes publishing the actual registered machine-readable documents, crosswalk tables, dependency lock, validation definitions and fixture bytes. This addendum supplies their required behavior and acceptance criteria; it does not substitute prose for those deliverables.

## Appendix C. Source basis — informative

Stream baseline inspected: `origin/main` commit `569bf87f1fa808787d324f6e1582924b5ccf1d40`. Implementation completion is deliberately not used to narrow this proposal.

- [Stream collection metadata specification](https://github.com/6529-Collections/6529Stream/blob/569bf87f1fa808787d324f6e1582924b5ccf1d40/docs/collection-metadata-contract.md): existing subject, record, authority, preservation, museum profile and dossier homes cited above.
- [Stream specification policy](https://github.com/6529-Collections/6529Stream/blob/569bf87f1fa808787d324f6e1582924b5ccf1d40/docs/spec-policy.md): lifecycle, permanence classes, single sourcing and verification rules.
- [CIDOC CRM versions](https://cidoc-crm.org/versions-of-the-cidoc-crm): versioned conceptual-model source.
- [Linked Art model](https://linked.art/model/): baseline model and scope.
- [Linked Art digital resources](https://linked.art/model/digital/): digital objects and information/carrier relationships.
- [Linked Art assertions](https://linked.art/model/assertion/): attribution/assignment patterns.
- [Linked Art JSON-LD](https://linked.art/api/1.0/json-ld/): context and serialization.
- [Getty semantic representation](https://vocab.getty.edu/doc/): vocabulary entity identities and representation.
- [Getty linked-data access](https://www.getty.edu/research/tools/vocabularies/lod/index.html): authority record/dataset distribution.

The normative decisions specific to Stream in this proposal — record names, field requirements, review policy, deterministic export and gates — are adopted Stream design choices, not claims that those choices are mandated by CIDOC CRM, Linked Art or Getty.

The original proposal is retained outside this repository unchanged; its SHA-256 is
`f86048f0849de5250c70fbeae76fbaeac71c41992be6384e3667dd2e526549bf`.
ADR 0036 records the incorporation changes and owner adoption.
