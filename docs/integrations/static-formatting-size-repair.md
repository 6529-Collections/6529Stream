# STATIC formatter and Metadata record-commit size repair

This bounded source batch repairs two measured production size failures. The selected
15-product capture `size102` used Solidity 0.8.19, optimizer 200, viaIR, Paris and no metadata
hash/CBOR. In that frozen working source, RendererV1 measured 17,757 bytes, its fixed pure
formatter 12,905, CollectionMetadataV1 22,642, and its original manifest/record worker 20,468.
The attribution companion measured 23,711. These are scoped generation measurements, not a
combined-build size or runtime acceptance claim. The separate Router remains oversized;
its ongoing repairs and proposed storage cache are not included in this commit.

`StreamStaticRenderEncoding` contains the previous pure HTML/context/JSON/URI composition.
The original renderer still authenticates the same source targets and reconstructs complete
payloads before encoding. It uses a direct bounded STATICCALL to fixed linked code and pins
that helper's runtime at construction. `encodingBinding()` makes the exact address and hash
available for the version's declared transitive `METADATA_COMPANION` read set. Gate analysis
must include the helper and its `render` selector; linking alone is not conformance proof.
No output ceiling or governed gas default changed. The extra frame still needs actual cold
runtime/gas validation. Direct calls to the pure formatter are computations over inputs and
are not source-admission evidence.

The internal UTF-8/JSON scanner retains its original byte rules; aligned word reads avoid
reading past the allocated string word. The original optimizer posture is retained because
the optional memoryguard experiment enlarged two measured products. The context serializer
splits one concatenation without changing its field order or output bytes.

The exact original Metadata record commit now runs in its existing fixed manifest worker,
with explicit original mapping roots. Original index/chain/latest updates, event fields and
ordering remain unchanged. Host authority, schema, payload, subject and replay checks still
precede the commit, and a later failure reverts the whole transaction.

Three new authored controls check formatter runtime drift/restoration and original scanner
parity at word boundaries and arbitrary bounded inputs. The original eleven STATIC route
and fifteen Metadata cases remain unchanged. The focused 210-source ABI check (HEAD plus only this partial repair) passes, retains every original Renderer/Metadata ABI entry and exact ordinary storage layouts, and is source-only; no native
execution, full current-stack join, complete read-set analysis or finality acceptance is
claimed by this handoff.
