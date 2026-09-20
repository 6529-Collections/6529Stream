# Native conservation tier declaration

The additive `IStreamConservationTier` interface on `StreamCollectionMetadataV1`
implements the declaration required by CMC-MUSEUM-GRADE. It uses the durable
Core anchor defined by [ADR 0053](adr/0053-durable-museum-anchors.md).

`declareConservationTier(uint256,bytes32)` accepts exactly the Keccak-256 hashes
of the ASCII strings `MUSEUM_GRADE`, `MUSEUM_GRADE_LITE` and
`CONSERVATION_WAIVED`. The caller needs a dedicated
`6529STREAM_RECORD_FAMILY_CONSERVATION_V1` grant: class 7 for that collection,
or class 8 at global scope zero. The existing exact delayed Executor/root
transition creates or revokes those grants. RIGHTS, Artist, owner and curator
authority do not authorize a tier declaration. A class-7 global grant or a
class-8 collection grant does not authorize this operation either.

The facade checks the actual Core collection and its own stored grant, then
calls `Core.recordConservationTier`. Core independently requires its currently
selected, live code-pinned Metadata caller, a known collection, no previous
declaration, zero completed mints, and no mint-completion callback in progress.
There is no update or clear operation. On success, the facade emits the exact
original event:

```solidity
event CollectionConservationTierDeclared(
    uint256 indexed collectionId,
    bytes32 indexed tier,
    uint16 schemaVersion
);
```

The schema version is 1. Core also retains its own write event. A failed Core
write rolls back the whole declaration, including facade events. A Safe uses
an ordinary CALL to the facade under the Safe's granted account identity.

`conservationTier(collectionId)` returns `(declared,effective)` from the
original Core. Unknown collections revert. For a known undeclared collection,
both values are zero until `collectionMintedEver` becomes positive; afterward
`declared` remains zero and `effective` is `keccak256("MUSEUM_GRADE_LITE")`.
Allocation, a prepared mint, current live supply and burns are not substitutes
for completed minting. A replaced facade can still read the durable Core facts,
but only the newly selected facade can write. Replacement cannot erase an
earlier declaration or manufacture an undeclared default.

These declarations are one input to the sale floor. This producer does not
establish complete floor enforcement: actual rights, original intent/interview,
media masters, release coverage and full-tier reference captures/environment
must be checked at the sale boundary. The separate exact personhood-proof
proposal remains held and unapplied. An explicit conservation waiver exempts
only the sale floor; finality and preservation obligations remain independent.

The scoped tests exercise actual Metadata/Schema/Store and threshold Safe calls
with explicit typed Core/Artist/governance boundaries. Separate anchor tests
exercise the actual Core with typed surrounding dependencies. ABI/type checks,
native execution, bytecode size and whole-current-stack acceptance are separate
evidence; authored cases alone do not claim runtime or release acceptance.

The canonical acquisition-packet condition denominator is described separately
in [condition source selection](condition-source-selection.md).
