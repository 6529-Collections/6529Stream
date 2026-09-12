# Museum pinned vocabulary interpretation

This candidate vocabulary is a separate increment after the source/selection
foundation. It supports explicit RDFS class, superclass, property-domain and
property-range checks. It is not a complete CRM reasoner, a JSON-LD processor,
an institutionally reviewed crosswalk, or a registered semantic profile.

The byte closure retains three original RDF/XML documents: the official CRM
7.1.3 RDFS implementation (434,213 bytes), the Linked Art terms document (23,556
bytes), and Linked Art's imported CRM enhancements (7,959 bytes). Both Linked
Art documents are pinned to Git commit
`a3b57fae50f9be9b0c15d4c7d5d61eb65a3596e8`. The index records each whole SHA-256,
original URI, retrieval time, version, attribution and ordered raw chunks.
The official RDFS is an implementation of CRM; it does not replace the normative
definition or justify interpreting every class as part of the Linked Art subset.

The initial parser stopped at duplicate class declarations. Inspection showed
six explicit additions in the pinned Linked Art terms document. The candidate
`vocabulary-policy.json` records each exact original declaration and source hash.
For these six classes only, the checker retains both declarations and unions
their named superclasses. It never chooses the first or last document. Any
unlisted duplicate, changed parent, changed source hash, property/class mismatch,
duplicate rule or unused rule fails. This is an explicit interpretation rule to
be committed by the future profile, not a rule for agent authority or ownership
of an entity IRI.

| CRM class | CRM superclass retained | Linked Art superclass addition |
| --- | --- | --- |
| E8 Acquisition | E7 Activity | Transfer |
| E9 Move | E7 Activity | Transfer |
| E10 Transfer of Custody | E7 Activity | Transfer |
| E74 Group | E39 Actor | Set (E39 Actor is also restated) |
| E85 Joining | E7 Activity | Addition |
| E86 Leaving | E7 Activity | Removal |

Every resolved term keeps its original declaration provenance. Relation checks
require explicit domains and ranges, with every constraint satisfied by the
selected subject/object class hierarchy. Missing terms or hierarchy dependencies
fail locally; no URL is fetched. Multiple domain/range declarations are
conjunctive. Unsupported nested RDF references and term-local bases reject. XML
is bounded and cannot declare entities or a document type. This parser does not
implement OWL restrictions, property inference, datatype validation or a general
RDF/XML-to-triples transformation.

The initial relation controls distinguish physical prints from digital files,
Creation from Production, visual/linguistic information from generic sound
information, and event location from depicted place. An accepted class/domain
pair alone does not prove that a source claim is true, authorized, sufficiently
precise, or eligible for projection. Exact selected assertions, authenticated
reviews and mapping rules remain additional requirements.

The three raw documents and the finite policy form an acyclic hash dependency
closure. Semantic superclass links are not document-hash edges; they remain
bounded at evaluation by visited terms. All twelve museum gates and eight
media/history scenarios remain required. JSON-LD expansion, profile-specific
shape validation, full source crosswalks, Getty authority evidence, cross-format
exports and institutional ingest are subsequent executable work.

Primary definitions: [CRM 7.1.3](https://cidoc-crm.org/Version/version-7.1.3),
[Linked Art profile](https://linked.art/model/profile/), and the exact RDF/XML
source URIs recorded in the dependency index. Linked Art source reuse is under
CC BY 4.0; the CRM document retains its embedded license and attribution.

```text
python -m unittest tools.museum.test_vocabulary -v
```
