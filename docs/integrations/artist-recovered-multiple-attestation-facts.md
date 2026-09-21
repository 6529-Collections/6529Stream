# Aggregate recovered op24 facts

`StreamArtistRecoveredMultipleAttestationFacts.validate` is a pure worker for the
next accepted generation-one, PRIMARY_ONLY aggregate recovery profile. It does
not activate a profile or change any existing owner, Coordinator, request,
constant, import or dispatch entry point.

The fixed input is:

```solidity
validate(
    bytes[] canonicalIdentities,
    StreamArtistRecoveredMultipleTypes.State scope,
    bytes[] canonicalAttestations,
    StreamArtistRecoveredHydrationTypes.Provenance provenance
) returns (uint256[][] uses)
```

Each identity is canonical `abi.encode(IH.Bundle)`, in `scope.artists` order.
Each attestation item is canonical
`abi.encode(StreamArtistRecoveredAttestationHydration.Bundle)`, in
`scope.collections` order. Every bundle commits the same complete original
Attribution provenance. `scope.rows` is deliberately unused; it belongs to the
other owner codecs. Collection queries retain their complete original record
order and multiplicity. Artists and collections use the existing sorted,
nonzero aggregate scope rules and original limits.

The worker validates the complete original Attribution and Binding provenance
shapes. Each accepted collection contributes its original two Attribution base
commits in the era of its unique original op1 Binding occurrence. Each op24 adds
one original Attribution commit in its native era. Imported eras retain the
original one-commit lower boundary; replay and nonce fields remain empty for
Attribution. No synthetic filtered journal, era or checkpoint is constructed.

Attestations are consumed in the whole Attribution journal order. Every native
op24 occurrence must match exactly one supplied collection row, and every row
must be consumed. Full original semantic row, association, publication and
personhood-summary predicates remain in the existing fixed history-row worker.
The new fixed fact-row worker preserves the original record domain, signature
witness, direct/delegated nonce, attestation key, first observed digest, grant
scope/capability and revocation/replacement chronology predicates.

C2PA predecessor chains have one evolving head per Artist across all of that
Artist's collections and original eras. Interleaving another Artist does not
reset or advance that head. Credential payload validation retains the original
canonical schema, identity reference, complete ordered credential enumeration,
key identifiers and validity fields. Personhood summaries retain their original
Registry and native-record preimages and never substitute for a credential
chain. Neither worker reauthorizes a historical signer, issuer or present
standing, replays a Safe signature, or infers present C2PA eligibility.

`uses[a][g]` is only the op24 increment for the original delegation at index `g`
in the identity at index `a`. It deliberately does not equal or overwrite the
saved total uses. The enclosing recovery composition must add all supported
consent and attestation increments, reconcile each original grant exactly once,
and install the complete state in original journal order. Empty collection
histories, including an all-empty attestation family, produce zero increments;
feature selection and the rest of the accepted graph remain caller obligations.

The enclosing source/import flow must independently authenticate the actual
complete source bundles, original Identity authority and standing/issuer facts,
accepted PRIMARY_ONLY bindings, seven-owner provenance, nonce inventory, and
actual retained per-record/current C2PA heads. This pure worker supplies no
source-address proof and performs no state installation. Those composition and
actual op60 ceremony paths are not part of this additive batch.

The focused tests execute the actual new workers and original semantic helpers
against explicit typed source evidence. They cover two Artists, three
collections, interleaved and repeated-era chains, direct/classes2/3 admission,
original publication kinds7/8, personhood, grant chronology, canonical bytes,
complete occurrence accounting and exact refusal/restoration. They do not
establish actual source admission, Safe authorization, whole-profile import,
maximum aggregate capacity or transaction-gas acceptance. Native evidence,
when available, is pinned separately to the exact tested source.
