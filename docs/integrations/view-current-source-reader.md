# Adopted VIEW V1 current-source reader

`StreamFinalityViewSourceReads` is a fixed source reader for a consuming
constructor-pinned VIEW preservation profile. It is not a new adoption authority
or a finality provider. `Dependencies` pins Core, original Router, Artist,
original Finality, actual provider, generic Metadata, governance authority,
deployment chain, read budget and the exact provider-owned Views/Membership
binding.

`retained(dependencies, recordHash)` authenticates the original Router's
immutable Store carrier, canonical complete Record, source and record hash
preimages. It does not assert that this record is still the current head or that
its source remains eligible. `requireCurrent(dependencies, fullScope)` also
requires the actual current VIEW head, full selected source roster, current
declaration, exact ACTIVE schema/canonicalization bytes, complete retained
payload, actual governed renderer/version/read-set selection and complete sealed
membership. Scope ID and declaration viewId remain distinct.

These are read predicates. They do not repeat adoption-only family-writer or
freeze checks; a saved source can remain current after it has been frozen, and
a VIEW can finalize inside an open collection. This reader accepts only the
original adopted VIEW V1 context. Its finalized-only renderer semantics are not
terminal V2 policy support. The V2 tagged profile and full output/snapshot/
reference/inventory/finality continuation are separate required work.

The focused capture uses actual `StreamSchemaDocumentStore` and original
`StreamViewAdoptionState.commit`. Core/Artist/Views/Schema/Registry/Membership
responses are exact-input typed boundaries, not an actual governed publication
or Artist op17 ceremony. Six cases cover independent literal preimages,
historical/current separation, immutable carrier/canonical bytes and consent,
membership/declaration, selected Artist/schema, renderer read-set and host/chain
substitution, with restored positives. The foreign-host negative refuses its
unavailable carrier; it does not supply a separately forged foreign-domain
record.

The final isolated capture is `.tmp-view-current-source-native2`: 53 exact
sources, six passing tests, verified native artifact metadata and all selected
production runtime/initcode limits. Reader runtime is 13,743 bytes. No cold
transaction-envelope or full-provider acceptance is claimed. The retained first
capture passed five cases; the chain-domain test restored a compiler-reused
`block.chainid` value after the Foundry cheatcode changed the chain. The only
successor source change captures the original chain from setup dependency
storage. All production bytes and refusal assertions remained unchanged.
