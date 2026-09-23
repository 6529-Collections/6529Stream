# Preservation reference and inventory source checkpoint

Base: `eedd83924ac179f036b91f4484e04baca42d7266`.
This batch continues [ADR 0054](../docs/adr/0054-explicit-non-sanction-preservation-rendering.md)
without changing any original full-output profile.

## Implemented source

- Separate COLLECTION and TOKEN/RELEASE/SEASON reference publishers and readers,
  exact schema documents, original environment/package/capture archival joins,
  and immutable historical payloads with separate currentness and lock checks.
- Samples retain the complete producer binding and Registry admission, join the
  exact selected version and runtime, and read the saved producer's bytes.
- Both inventory families retain the original five token source stages and add
  a mandatory sixth stage for preservation registration, complete ordered reads,
  full sorted target roster, all runtimes, schema, analysis and golden documents.
- Original Artist operation evidence, policy, scope membership, artwork, script,
  library, citation/terminal, description, rights and conservation requirements
  remain mandatory. Currentness and document facts remain independent checks.

Independent review found a source-preimage defect in the first inventory port:
it encoded a decoded entropy tuple where the actual checkpoint hashes dynamic
canonical bytes. Both readers now use those exact bytes. New tests join real
checkpoint rows and independently distinguish both encodings.

## Authored tests and limits

There are 53 authored cases: COLLECTION reference 10, scoped reference 17,
admission inventory 14, COLLECTION inventory reads 3 and scoped inventory reads 9.
The reference tests use real checkpoint/output/snapshot/reference and original
Store, grant and Safe components with identified producer, admission, Artist,
root or external capture boundaries. Scoped reference execution requires the
new writer to be integrated into the shared Router.

The admission tests independently construct registration/read-set hashes and
exercise complete roster, unused-target runtime, malformed ABI, source identity,
document byte and exact restoration checks at explicit Registry/producer/store
boundaries. They do not establish actual governed admission. Inventory tests
prove real checkpoint/output byte joins and reject entering the preservation
stage before the preceding stages. Successful complete six-stage progression
and the genuine full publication ceremony remain composed-test obligations.

## Validation

Final ABI-only capture: `artifacts/art27-gap3/preservation-references-inventory-freeze`.

- Solidity 0.8.19: 591 sources, zero compiler errors.
- Input SHA-256:
  `8655b5b1272616be8e756273e2e09d78e253aca8e8fb06f908184c86b6a207d5`.
- Output SHA-256:
  `53dd488727082f85b12813491f74766036652824de5786d593ff5d05eb6490e3`.
- Independent source reviews cover both reference families, both inventory
  families, the common admission worker and all authored cases. Reference
  schema tuple trees match compiler ABI; schema bytes/hashes match the exact
  documents. Scoped formatting, documentation and Windows whitespace checks pass.

Borrowed B Registry interface and writer-owned root interfaces/schema helpers
and scoped snapshot reader are excluded from this commit. They are committed
independently in B's `e933b422` interface slice and writer `a1265c3a`.
The capture records their exact raw pins; integration must include those sources.

No native tests, fuzz execution, code generation, linked product sizes or gas
measurements are claimed. No original full-output ceremony assertion was changed.
Factories, providers, actual producer/Registry admission and the complete
sanction/archive/finalization/confirmation acceptance remain separate work.
