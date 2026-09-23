# Recovered Identity import capacity

Base: `e085eaadbd5285a4ea0b44cfe1bb2e2fcf382939`.
Branch: `codex/recovered-identity-import-fit`.

## Scope and preserved behavior

The original Identity importer was the unresolved code-generation dependency
after the Transport, Export and Continuations repair. This change replaces its
large typed-memory installation body with a facade and eight fixed,
compiler-linked workers. It preserves the original public memory signature,
all three errors, selector `0cb7e5fd` and empty library storage layout.

The facade first runs the complete existing SourceCodec canonical-envelope and
semantic validation. Its workers receive the complete thirty-four-field encoded
Bundle and the same seventeen declared owner storage roots. Frame views occur
only after that full validation. No caller-selected target, additional root,
raw external call or catch-and-continue path is added.

The original sequence remains: requested-artist and empty-principal checks,
records, authority including estate, recovery, continuations, nonces, timing,
heads and artifact points. Authority calls the fixed Estate worker at its
original final estate boundary. Individual row copies, collision checks,
reads-after-earlier-writes and installation order are preserved. In particular,
the delegation lane keeps its original untagged hash; nonce words precede the
original consistency checks; timing precedes heads; operation-35 artifact
classification reads the installed recovery records. Linked library calls keep
the owner's storage and sender context, and ordinary reverts remain atomic.

Complete source validation proves the supplied envelope equals the original
`abi.encode(IH.SCHEMA, bundle)`. The input Bundle is never mutated by the
installation kernels, so the returned `keccak256(raw)` equals the original
post-install envelope commitment. Independent source review checks all thirteen
original private helpers, the additional estate boundary, the fixed repudiation
storage slot/layout and the full public ABI. This is source equivalence evidence,
not an independent proof of the existing admission protocol.

## Selected capacity evidence

Solidity 0.8.19, optimizer 200, via IR, Paris, metadata hash disabled and no CBOR.
All nine changed or new products fit 24,576 runtime and 49,152 creation bytes:

| Product | Runtime | Creation |
| --- | ---: | ---: |
| IdentityHydrationImport | 4,682 | 4,716 |
| IdentityImportAuthority | 14,723 | 14,757 |
| IdentityImportContinuations | 4,547 | 4,581 |
| IdentityImportEstate | 13,343 | 13,377 |
| IdentityImportNonces | 2,584 | 2,618 |
| IdentityImportPrincipal | 9,787 | 9,821 |
| IdentityImportRecords | 11,447 | 11,481 |
| IdentityImportRecovery | 14,710 | 14,744 |
| IdentityImportTiming | 3,667 | 3,701 |

The first eight-product capture generated every selected product, but Authority
was 25,982 runtime bytes. That failed capacity capture is retained. Moving its
existing estate tail into a fixed worker produced the final nine-product pass.
Final selected input SHA256:
`b04726934638f2c3d6f70a9e36cb559acaa79d330988b8a4f193975f231c353b`.
Output SHA256:
`0b23ef1eedc609215cd4b4c431a8cefc7aa96dc8f572a7c3c389047bae0682d2`.

The final ABI capture includes 216 source files and the new test host,
with zero errors. Its input SHA256:
`44f91d3e4b0ea2a909c92ccdd5d0d0e474e59f5668d2932826453697108a2b7f`.
Output SHA256:
`930624327628d2a3735f7db814a0453c6b5885ee7f9a60a4b2dd7306b239275f`.
Every captured source matches the final working source content. The local
evidence packet is `artifacts/prepared-fit/import-capacity-final.json`, SHA256
`b5a584a36b63ba73e9d46013b3e44238d4b7e42f8b6b383a7aa4714182136683`.
Compiler captures remain local evidence, not regenerated release artifacts.

## Native component evidence and remaining work

Six Records component tests pass against genuine linked Records and PayloadStore
products. They check every installed fixture field and owner storage context,
document/signature conflicts, compound record and delegation-lane conflicts,
late directive/final-grant collisions, rollback of earlier records and payload
catalog writes, identical-byte retries, and payload catalog deduplication.
Call-count expectations observe actual PayloadStore/SSTORE2 execution; no mock
replaces the payload implementation. Native artifacts are authenticated before
and after execution, with unchanged source/tool hashes. Result SHA256:
`73a8e74025f1531627147ef6966d947e3154aa1e1cd6ff97ed59b3c4933064a2`.

These are synthetic canonical-tuple kernel fixtures. They bypass source
admission, principal checks, provenance/authorization and all later importer
stages. They do not establish complete operation-60 behavior, arbitrary-row
fuzz coverage, cross-stage runtime parity or event-log equivalence. Existing
test-only deployment caps are separate from the production limits above.

A full linked-graph build, current-stack execution, broad aggregate validation
and production gas validation remain the integration owner's work. No deployment
is performed. This packet is source, capacity and component evidence; it does
not establish release, audit or production readiness.
