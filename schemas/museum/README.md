# Candidate museum schemas and fixtures

These three canonical JSON Schema documents implement the adopted name and
typed-shape allocation. They are **unregistered candidates**. The profile's
interpretation-document commitments are still being assembled; its annotation
states that it is incomplete. Do not use this directory as a genesis registration
manifest or as evidence that a museum conformance gate has closed.

The schema IDs are keccak256 of their exact UTF-8 names. The documents remain
self-contained for shape validation. Semantic checks separately establish record
hashes, subject identity, source authority, review evidence, chronology, profile
selection, disclosure, vocabulary domain/range and complete dependency closure.
Shape validation alone cannot establish any of those facts.

All eight fixture source documents are explicitly synthetic, with a synthetic
source inventory schema. They exercise the required media/history categories;
they do not replace the future complete CMC-family examples or claim that named
media have been received, preserved, signed, minted, acquired or accessioned.
The photograph and interview scenarios are independent constructed test inputs,
not factual records of AN ALTERATION or Museum holdings.

The dependency fixture captures the official Linked Art context at upstream
commit `a3b57fae50f9be9b0c15d4c7d5d61eb65a3596e8`. Its ten chunks reassemble to
79,235 exact bytes and SHA-256
`3017421203aba8ea73f159aced1285e35b37cee49b5648cf19b01f237025f165`.
The published URI and Git blob were byte-identical at capture. The lock records
retrieval time, version, media type and upstream attribution; LICENSE bytes are
retained. No nested external context was found in that document. This is not a
claim that all ontology/classification dependencies have been captured.

See [tool commands](../../tools/museum/README.md) and the
[implementation boundary](../../docs/museum-exporter-boundary.md).
