# Recovered Identity transport capacity

Base: `45088f2284d0c9115188275f05555ed429a62364`.
Branch: `codex/recovered-identity-transport-fit`.

## Scope and preserved behavior

The historical linked-product discovery measured Identity Transport at 48,832
runtime bytes. Removing its repeated full Identity memory decoding exposed the
exporter dependency: its original body plus an additive encoded export wrapper
measured 80,150 runtime bytes. This source change splits Transport, Export and
Continuations into fixed compiler-linked workers that fit the deployment limits.

The owner supplies the same seventeen declared storage roots. Every storage
worker uses the original owner context through linked library calls. The host
accepts no new caller-selected roots, targets or storage selectors. The four
early Transport read routes and their selector/decode order are unchanged.

Export retains source-provenance admission, artist validation, the owner snapshot,
identity/document/registration nonce reads, all heads, query signatures, one
ordered journal scan, vestings, memberships, actions and sorting, closures,
standing, documents, nonces, timing and continuations, in that order. Fixed row
workers run at the original journal branch positions. Original count bounds,
allocation formulas, missing-record handling and final cardinality checks remain.
The full thirty-four-field Identity result survives; no semantic rows are omitted.

The internal encoding helper joins complete compiler-produced field and row
encodings. It relocates only outer tuple/array heads and preserves nested offsets.
Its inputs come from fixed typed producers. It is not an admission validator for
arbitrary raw bytes. Independent source review checked all field slots, row
encoding flags and thirty-five original producer/helper kernels.

Transport import retains the complete outer action/query/owner-data decode,
owner-two payload decode, complete canonical Identity decode, original nonce
length/guard short circuit, and ordered kind/key/full-word comparisons. The
original importer then runs its own validation and installation, followed by
History activation using the supplied commitment. The new nonce worker reads the
owner's guard storage. No guard, artist, source or callback check is weakened.

The original Transport, Export and Continuations ABI, errors, empty library
storage layout and nominal selectors are preserved. Export adds only the fixed
`exportEncoded` library method. The Continuations facade fully encodes its typed
input before invoking the original collection kernel and returning the complete
typed result. Canonical producer behavior is preserved; rejection timing for
arbitrarily malformed unused calldata is not exhaustively established.

## Selected capacity evidence

Solidity 0.8.19, optimizer 200, via IR, Paris, metadata hash disabled and no CBOR.
All twenty-two changed or new products fit 24,576 runtime and 49,152 creation
bytes. Selected results include:

| Product | Runtime | Creation |
| --- | ---: | ---: |
| IdentityTransport | 7,378 | 7,413 |
| IdentityTransportImport | 7,540 | 7,574 |
| IdentityTransportNonces | 1,085 | 1,117 |
| IdentityHydrationExportRows | 8,141 | 8,173 |
| IdentityExportCollect | 8,869 | 8,901 |
| IdentityContinuationRows | 13,685 | 13,717 |
| IdentityHydrationContinuations | 21,156 | 21,188 |

The remaining fifteen Export products have runtime sizes from 4 bytes (the
internal-only encoding helper) to 8,656 bytes. The final ABI capture includes 251
sources and all three new test hosts, with zero errors. Input SHA256:
`538a020339298eea68f02330b1374cf321632fdb3b395739f3382ce3fe4ac694`.
Output SHA256:
`eabfc02cebaf334e143384e7690d657a22a256a0ee82c990ab94607f117e0707`.

The local evidence packet is `artifacts/prepared-fit/transport-capacity-final.json`,
SHA256 `cd1b98a2763842a2ecca50b2be16ec69d64f9ef0faac17fe6b5ab3315aed7161`.
It records every selected compiler input/output hash, product size, complete
public-surface comparison and native test result. One final formatter-only change
to Collect was compiled separately; creation and runtime bytecode are identical.
Other selected products retain their exact captured source contents. Compiler
captures are retained locally, not committed as release artifacts.

## Native component evidence and remaining work

Four real nonce-worker tests pass, including one fuzz test with 256 cases and
seed `0x6529`. They compare the original typed nonce algorithm, full word contents,
failure ordering and actual owner guard storage against the new worker. The
fresh run used sixty frozen sources, seven native artifacts and one compiler
iteration. Result SHA256:
`137aa1d3955ef682bd246d2102b6d566a814123fd5da25c2ca98f0149b6a16e2`.
An earlier test-only library call-encoding type error remains in a separate
failed capture; it is not counted as a passing run. After the passing run, one
extra final blank line was removed from the test file; every other byte is
unchanged. The final ABI capture includes that whitespace-only correction.

Nine encoding-oracle tests pass, including three fuzz tests with 256 cases each
and seed `0x6529`. Actual Solidity encoders independently cover all thirty-four
fields, empty and populated bundles, static and dynamic row arrays, byte-length
boundaries and replacement of all four continuation arrays. The fresh run used
seventy-four frozen sources, one native artifact and one compiler iteration.
Result SHA256:
`92a1341a8fe4eb41fb50e8887c8c1ae7d8410c20fa88fc00a334d718cef3d5ea`.
Both passing runs verified authentic native artifacts before and after testing
and checked unchanged source/tool hashes. Existing test-only deployment caps do
not replace the production size limits above.

Four additional scoped Transport forwarding tests are source-reviewed and pass
ABI/type checking; native execution is pending. Their downstream proofs are
explicit mocks, not authenticated source or complete operation-60 evidence.

A combined twenty-product compiler pass including the unchanged original
Identity importer failed with a Yul stack-depth error. Subsequent Export and
Continuations selections succeed, narrowing the unresolved code-generation
frontier to the original importer without independently proving failure
causality. That importer is unchanged in this commit and remains assigned work.
Complete exporter/continuation runtime parity, actual source admission, full
operation-60 flows, the entire linked deployment graph and production gas remain
unproved by this packet. This is source and component evidence, not release,
audit or production-readiness evidence.
