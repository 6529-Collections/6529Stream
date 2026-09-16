# Artist subject and delegated attestations

The original operation 24 now reads the named subject before accepting an
attestation for kinds 1–6. Its `StreamArtistAttestation` signature, original
16-word record hash, statement bytes, nonce and historical record ABI are
unchanged. A successful write also saves its exact current Artist binding,
subject owner/runtime and any delegation. That association is included in the
Attribution owner state transition and the original atomic Archive evidence.

## Subject selection

`recordArtistAttestation(payload, authorization, statement)` uses these keys:

| Kind | `subjectId` | Required `subjectStateHash` |
| --- | --- | --- |
| 1 snapshot | Actual current receipt's `snapshotId` | Its manifest hash, equal to both `latestSnapshotHash` and the original per-ID manifest hash |
| 2 script manifest | `bytes32(collectionId)` | Current complete typed script-manifest hash from the selected metadata owner |
| 3 media manifest | `bytes32(collectionId)` | Current complete typed media-manifest hash from the selected metadata owner |
| 4 executed finality | `bytes32(collectionId)` | The actually finalized collection record hash |
| 5 phase policy | Actual Manager phase ID | Actual registered phase policy hash |
| 6 economics | Resolver address left-padded to `bytes32` | Current selected primary or royalty assignment hash for the collection |

Snapshot selection follows the Artist's fixed finality Registry, its pinned
scope-evidence provider, and that provider's original native configuration.
The snapshot host, Core, metadata router, Artist and finality Registry must
match those admitted pins. `SNAPSHOTS` is a lock ID, not a Core pointer.
This implements the original native-provider profile; an unrelated provider
without that authenticated configuration is not an alternate source.

Kinds 2/3 read the current Core `COLLECTION_METADATA` pointer and its runtime,
then the actual `IStreamCollectionManifestReads` capability. An absent selected
manifest, absent method, failed read or malformed fixed return rejects the
write. A script byte hash, image URI hash or raw metadata family hash cannot
replace a named full manifest. These owner reads use the existing publication
read GGP as an upper bound and allocate their fixed reply buffer before
retaining 105,000 gas for the call setup/reserve convention. This is not a
whole-transaction gas-capacity assertion.

Finality attestation records authorship of an already executed immutable
record. It does not rerun full present-day component validation or claim that
every former dependency remains available. Phase and economics facts come
from the fixed suite Manager and resolvers; royalty also verifies the
current Core royalty pointer. The economics hash is the canonical assignment
hash, not a consent-record hash or a prepared royalty-policy hash.

## Explicit scopes

The additive `recordArtistScopedAttestation` takes the original payload plus
`Subject(scopeType, tokenId, scopeId, resolver)`. It is available only for
kinds 4 and 6. Its subject locator must match the signed `payload.subjectId`.
Changing the locator therefore cannot reuse approval of another scope.

For finality, `resolver` is zero and the scope is the original
`StreamFinalityScope(scopeType, collectionId, tokenId, scopeId)`:
collection=0, token=1, release=2, season=3, view=4. The subject ID is
`keccak256(abi.encode(keccak256("6529STREAM_ARTIST_FINALITY_ATTESTATION_SUBJECT_V1"), scope))`.
The exact stored scope must be finalized; pending or foreign records fail.

For economics, `tokenId` is zero and `scopeType` is the original assignment
scope: default=0, collection=1, token=2. `scopeId` encodes the actual numeric
key and `resolver` must be one of the fixed suite resolvers. These are exact
per-key reads, without ancestor fallback. The subject ID is
`keccak256(abi.encode(keccak256("6529STREAM_ARTIST_ECONOMICS_ATTESTATION_SUBJECT_V1"), collectionId, resolver, revenueClass, scope, numericScopeId))`.
The resolver validates collection/token identity; a missing or cleared key
has no attestable assignment. A configured disabled royalty still has its
original nonzero assignment hash.

The ordinary kinds 7–10 principal routes retain their existing schemas and
canonical payloads. In particular, kind 7/8 publication envelopes are not
relabeled snapshots or deployment evidence.

## Delegated authority

`recordDelegatedArtistAttestation(payload, grant, authorization, statement)`
and `recordDelegatedArtistScopedAttestation` use the same original op24
signature, with the actual stored grant's delegate as signer. The original
operation 26 grant transport additionally admits `CAP_ATTEST` (1) and
`CAP_INTENT_RECORDS` (64), alongside existing economics (4) and royalty freeze
(32). Kind 7 uses the existing intent capability rule; other attestations
require `CAP_ATTEST`. This does not grant policy, identity, guardian-set or
guardian-displacement powers.

The original Identity machinery consumes grant scope/time/use limits,
revocation, directive exclusions, delegation epoch, digest revocations and the
independent delegate nonce lane. Direct calls use the actual Safe caller and
nonce hint; an empty direct timestamp is normalized to the execution time.
Relayed calls verify the delegate's real ERC-1271/EOA signature. A delegation
never consumes the principal nonce or claims principal liveness.

The resulting original record is class 2. `attestationAuthorityClass`,
`attestationAssociation`, and `recordDelegation` expose its saved class,
binding/source and exact grant. `ArtistAttestationDelegation` emits schema 1
with that immutable association. Revocation and expiry do not erase history.
Actual successor generic attestations retain class 3 and require their
original effective `CAP_ATTEST`; they cannot use the delegation route.

For a subsequent metadata publication using a delegated kind 7/8 record, the
existing publication proof now checks its exact saved association, current
binding, class-1 principal, grant scope/capability, revocation/time/epoch and
operative forbidden mask. It does not consume a second grant use: exhausting
`maxUses` with the already admitted op24 does not invalidate that use.
Revoked, expired or succession-invalidated grants cannot authorize a new
publication, while their original attestations remain readable.

## Validation and remaining dependencies

Sixteen new regression bodies are type-checked: real threshold Safe and direct
Safe authorization, original records and Archive, actual Manager/Resolver
subjects, real op40 successor capabilities, actual facade mint-prerequisite reads after
delegated deployment/identity approvals, scope/capability/replay/expiry,
absolute directive exclusions, malformed owner replies, and complete rollback
with the identical signed retry after a late Archive failure. Snapshot,
manifest and finalized-record producers are explicitly typed boundaries in
these domain tests. This is not an executed full-current subject publication
or commerce acceptance. Native runtime, all linked deployment product sizes
and individual transaction capacity remain for consolidated validation.

The manifest capability must be deployed by its metadata owner; this batch
does not fabricate manifest publication. Steward class 4 remains closed:
there is no actual Artist dormancy initiation/completion producer yet. Real
steward attestation requires that separate canonical op42–44 lifecycle,
liveness cancellation, effective masks and appointment history. An injected
class-4 fixture or a defaulted unknown class cannot stand in for it.

The focused commands, when the consolidated native inputs are ready, are:

```powershell
python scripts/dev.py test --suite unit --via-ir --match-path test/unit/artist/StreamArtistSubjectAttestation.t.sol --code-size-limit 2000000 --gas-limit 1000000000 --memory-limit 1073741824
python scripts/dev.py test --suite unit --via-ir --match-path test/unit/artist/StreamArtistSuccessorSubjectAttestation.t.sol --code-size-limit 2000000 --gas-limit 1000000000 --memory-limit 1073741824
```

These are aggregate unit fixtures, including their original CREATE order and
typed Core/governance boundaries. Include the original Arweave fixture JSONs
when making an isolated capture. The original 57 operations and adopted 58
retain their meanings; no attestation signature or record is reinterpreted.
