# Native onchain snapshots

`StreamCollectionSnapshots` publishes an assembled JSON document from fixed contract
inputs. It is an actual Snapshot-family producer with its own append-only history;
publication does not change Router rendering authority or any content value.

The first profile captures collection-level `IDENTITY_DISPLAY` facts for the native
ONCHAIN Router. It retains exact name, description, image URI, animation base URI,
script bytes, the immutable nominated-artist presentation, renderer/runtime/profile
identity, the original content-root record, complete checkpoint/leaf-manifest
references, and every policy in the complete original-coordinator inventory.
It requires the Router's six presentation/content locks, a nonempty script, a
complete current content checkpoint, and nonempty frozen native policies. The
renderer dependency flag concerns its fixed contract assignment and declared
contract read set; it does not prove arbitrary JavaScript/browser/web closure.

The publisher needs two independent actual Metadata grants: `SNAPSHOT` and
`IDENTITY_DISPLAY`. Collection class 7 precedes global class 8 separately for each.
Both original classes and revisions are retained. Neither grant supplies artist,
rights or archive authority. The content-root and artist/archive facts are
references to the independently admitted originals, not fresh statements authored
by the snapshot administrator. The fixed original Metadata Executor runtime is
checked at construction and again for terminal lock execution.

## Publish and retrieve

1. Register the exact generated schema and interpretation profile, and the shared
   `RFC8785_JCS` definition, in the actual Schema registry. Definition documents
   use `RAW_BYTES` registration, retaining their exact original bytes. Each current
   use reconstructs every ordered definition chunk and checks the active status,
   kind, canonicalization, whole hash, length and first-version lineage.
2. Finish the actual token inventory, original-coordinator inventory, locked
   content checkpoint and preserved leaf-manifest verification. Publish the
   original content root through the Router's existing artist-consent path.
3. Call `previewSnapshot(publication, publisher)` with an unused opaque snapshot
   label, exact expected head/revision, inventory plan, explicit effective time,
   reason hash and optional manifest URI. The effective time is nonzero and no
   later than publication. It does not ask the producer to reconstruct historical
   state at that time: source values are observed when publication executes.
4. Split the returned canonical bytes into consecutive 8,192-byte segments and
   publish them with the existing permissionless Store. The final segment may be
   shorter. Uploading these bytes confers no record authority.
5. Set the returned `expectedSourceHash` and call `publishSnapshot` from the
   authorized account or its threshold Safe. The producer repeats all actual
   source/authority checks and computes the exact expected chunk hashes itself.
   Missing or changed bytes revert atomically. Concurrent publication uses an
   exact head/revision compare-and-swap; it cannot silently replace a newer head.

The logical manifest limit is 524,288 bytes, at most 64 canonical segments.
`snapshotManifestBytes` reconstructs every segment and checks its length, STOP
prefix, hash and whole-document hash. The pointer/chunk inventory getters expose
the original retained locations for independent reconstruction; they do not
assert that current external evidence is still eligible. The first pointer is
only the first segment, not a promise that the whole document occupies one blob.
Use the chunk inventory for large RPC reads.

`snapshotId` is a caller-chosen unique label. `snapshotHash(collection,id)` and
`latestSnapshotHash(collection)` return the canonical manifest hash. The original
record hash and rolling record-chain hash are separate. To reproduce the original
record hash, take the saved Publication and Receipt, set the Receipt's
`recordHash` and `recordChainHash` to zero, then hash the exact ABI tuple
`(keccak256("6529STREAM_NATIVE_SNAPSHOT_RECORD_V1"), chainId, host, Core, Metadata,
Publication, Receipt)`. The chain commitment uses its separate domain, chain,
host, Core, collection, preceding chain, revision and completed record hash.
Neither completed hash occurs inside its own canonical JSON preimage.

## Current evidence and locks

`currentSnapshot` and `snapshotRecord` are historical getters. `requireCurrent`
requires the exact latest record/revision, active fixed definitions, intact
stored manifest bytes and the same current source evidence. It reuses original
publisher/grant evidence and does not reapply today's grants to old publication.
Current validation reconstructs every mutable source fact and checks its full
source commitment, then verifies all retained manifest bytes. It does not repeat
JSON serialization: the remaining publication inputs are immutable saved facts,
and their exact serialization was already checked during publication.
The manifest commits its original predecessor and new revision as provenance;
the current source hash excludes today's snapshot head, later snapshot locks and
Core freeze. Thus locking a snapshot or freezing Core does not change its artwork
bytes or invalidate its own commitment.

`StreamFinalitySnapshotReads` is the fixed dependency consumer. It reconstructs
the original record hash from the canonical full Publication/Receipt witness,
requires byte-exact equality with the producer's fresh 672-byte current receipt,
and reads all three lock tuples. Its 17-word evidence retains the original
publisher, two grant classes/revisions, manifest/source/inventory/definition
hashes and explicit lock status. The input commitment uses the
`6529STREAM_FINALITY_NATIVE_SNAPSHOT_INPUT_V1` domain with its own `inputHash`
field zero while hashing. `requireCurrent` permits an unlocked observation;
`requireLocked` rejects it. Neither method supplies the remaining archive,
entropy-output, reference-render or aggregate finality evidence.

`requireLocked` additionally requires a one-way applicable snapshot-host lock.
`SNAPSHOTS` and the local `METADATA_ALL` lock must be applied before Core freeze;
the `SNAPSHOT_NATIVE_ONCHAIN` record-type lock remains available afterward.
Only the immutable Metadata Executor can apply them, under the exact executing
TERMINAL_FREEZE/class-2 action, scope and old/new head/revision commitments exposed
by `lockTransition`. These locks only constrain this host; `METADATA_ALL` here is
not a complete shared metadata lock. Original history remains readable.

The complete original-coordinator inventory supplies all retained at-mint sources,
including an older coordinator after the current pointer changes. Frozen policy
facts do not establish token entropy output, oracle truth or archive coverage.
An empty or mutable policy set fails this snapshot profile.

## Validation boundary

Generate/check definition bytes with `python -m tools.metadata.snapshot_profile --check`.
The offline `validate` function checks closed schema, exact canonical
JSON, definition pins, source lengths/hashes, canonical collection subject and
enumerated source requirements, including nonzero native policy epochs. These
are declared self-consistency checks, not every live contract predicate. It does
not authenticate a supplied document's chain carrier or turn its references
into independent archival proof. Zero predecessors and empty optional
publication/content-root URIs remain valid; required nonzero fields are checked
individually.

Focused contract tests compose actual Metadata, Schema, Store, Router, native
Coordinator policy, token/source inventories, checkpoint and leaf-manifest
verifier. Core identity/selection, Executor action context, artist consent,
token-seed production and archive-family receipts are explicit fixtures. They
do not prove the full production deployment graph or real institutional archive
standing. Governed read caps, full dynamic policy-list capacity and complete
aggregate-provider gas must be assessed on the deployed composition.

The retained [example](../../test/fixtures/metadata/snapshot-native-onchain.json)
is the exact 7,441-byte output of that default-compiler contract fixture. The
offline tests validate its complete canonical bytes and separately reject
malformed definitions, quantities, source values and policy correspondence.
The example records fixture state; it is not a public-chain deployment record.

The measured capacity fixture has two original coordinator policies, a 256-byte
name, 2,048-byte description/base URI/publication URI, a 2,046-byte inline PNG
URI and an 8,192-byte script, producing a 24,033-byte manifest. With ABI input
construction excluded and 16 named targets cooled (17 for the fixed consumer),
the default/IR publication calls use 14,951,241/14,648,836 gas within a 16M callee
budget. Current reads use 3,359,264/3,353,621; fixed-consumer calls use
3,479,431/3,474,669. This is a particular source/escaping/policy-count shape;
transaction intrinsic gas, every linked or SSTORE2 account, larger policy lists
and aggregate-provider composition are outside that measurement. A separate
storage-library test checks all 64 repeated segments and the exact 524,288-byte
limit; it does not establish practical publication capacity at that limit.

Other v1 scopes and media modes, every generic/custom metadata family, arbitrary
runtime dependency closure, dual-family archival coverage of the assembled
manifest, reference rendering and institutional acceptance remain required work.
Successful publication/current consumption of this bounded profile does not
claim full finality readiness or full museum conformance.
