# Token-resolved native script evidence

The additive token script source reads one Core token at one externally pinned
block. It keeps the [collection script V1 source](../tools/museum/COLLECTION-SCRIPT-DEPENDENCY-V1.md)
and its hash/byte rules unchanged. The new reader first proves Core token to
collection identity, the current Router-selected Metadata host and runtime,
and the token's `resolvedMetadataConfig`.

The Router's `MetadataConfigAuthorization`, `MetadataConfigRecorded` and
`MetadataStaticActivated` logs are scanned from block zero through the pinned
block. Matching successful receipts, transaction positions and canonical
provider headers are checked. The activation's level-3 record identifies its
retained global default through `previous`; today's global default is not
substituted. Every later collection and token override, including other
tokens' changes to the collection-wide override head, contributes to the
reconstructed revision and hash chain. Current collection and token getters
must resolve to the reconstructed records. A frozen source must match the
record's source-snapshot hash.

A selected native script manifest is then read from its original Metadata
host. The existing V1 wire checks its typed hash and ordered bytes. A complete
script produces a **positive script classification**. `OFFCHAIN` mode can
still have a script; zero selection, unavailable reads, incomplete bytes and
unsupported compatibility remain `unknown`. No negative `non_script`
classification is inferred.

## Registered interpretation

The existing 51-document Genesis Registry plan has no script-manifest
interpretation. It remains unchanged. A separate fixed plan defines exact
canonicalization, schema and format-catalog bytes for the two supported native
manifest hash domains, plus the existing `RFC8785_JCS` dependency. These are
prospective document definitions until a SchemaRegistry returns matching
ACTIVE documents, exact original chunks and Store carriers.

`token_script_registry_source_v1` reads those four documents from the
Core-selected Metadata host's SchemaRegistry. The registered-capture join
replays both original transcripts, requires the same chain/Core/block and
current Metadata runtime, and only then exposes an
`OD-SCRIPT-MANIFEST` eligibility reference. A missing, retired or mismatched
document fails the join. Synthetic fixture registration demonstrates the
checker; it is not a deployed registration or an actual-chain acceptance
claim. The final Museum dossier assessment remains separate.

Both source readers trust a provider's complete log responses and canonical
header mapping. They do not prove consensus, full ancestry or receipt tries,
historical writer grants, renderer execution, script safety, URI availability,
institutional acceptance or complete dossier conformance. The Router's
`familyStateHash` event field is retained, including any VIEW aggregation; this
reader does not recompute that value from only STATIC fields.

Run the focused offline controls with the Museum Python environment:

```powershell
python -m unittest tools.museum.test_token_script_source_v1 tools.museum.test_token_script_registry_source_v1 -v
```
