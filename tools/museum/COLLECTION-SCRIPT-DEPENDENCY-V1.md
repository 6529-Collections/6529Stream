# Collection script and dependency preservation

This read-only consumer preserves one collection's script and dependency
observations at an exact block. It retains the original RPC outcomes, native
tuples, manifest commitments and available payload bytes, then replays them
offline. It does not execute JavaScript or retrieve referenced URIs.

## Selection and availability

The source reads current kind-2 manifest selection and the Router's raw saved
`collectionScriptBundle` separately. The saved bundle can refer to an original
host after Core pointers change; it does not establish current selection.
Current manifest getters and original-host `recordedScriptManifest` and
`recordedScriptBundle` getters retain their different meanings.

A zero manifest or bundle selection does not establish that no script exists.
A stable Router may serve inline script without a selected manifest. Conversely,
chunked serving source intentionally omits inline script. Inactive inline bytes
must not replace a missing or unavailable selected bundle.

Optional failed calls retain a bounded failure category and, for a JSON-RPC
error, its numeric code. Remote error messages, error data and endpoints are not
stored. A failure is not proof of record absence or of a particular native
revert. A successful empty byte response remains a successful response and must
satisfy the relevant native ABI and content rules.

The Core pointer's stored admission status is separate from present module
eligibility. This reader does not reinterpret an old pointer as a fresh
ModuleRegistry decision. It does not infer earlier stable selections when the
current getter is unavailable and the raw bundle tuple is zero. Complete event
history is outside this version's scope.

## Native byte correspondence

For supported stable and chunked manifests, the wire validator checks the exact
native manifest hash. Complete bundle bytes reconstruct ordered chunk hashes,
chunk lengths, the immutable bundle ID and whole payload hash. UTF-8 validation
applies to the assembled stream, so a code point may cross a chunk boundary.
Unavailable chunks remain explicit and prevent claims that require their bytes.

Libraries retain their original bundle and dependency manifest. The dependency
manifest's `dependencyId` is the local library bundle ID. A registry-backed
library separately records its original external registry, runtime hash,
dependency ID, version and content commitment. Its versioned reads do not
switch to the latest version or to Core's current dependency registry.

The registry's content commitment hashes typed, ordered chunk commitments; it
is distinct from the hash of concatenated payload bytes. Both commitments are
checked when the required observations are available. A later registry runtime
change does not erase the saved original facts or establish availability of the
original bytes. `libraryURI` and `scriptURI` remain provenance references.

Logical payload reconstruction through admitted native getters does not prove
each physical SSTORE2 storage carrier. No execution, visual equivalence,
authorship, archival durability or script safety follows from matching bytes.

## Original inputs and trust

The input anchor identifies the chain, Core, collection, block hash and number,
timestamp, state root, environment and deployment evidence. It supplies external
runtime pins and the source reader's reviewed native checkpoint. Calls use an
EIP-1898 block hash with `requireCanonical`; header observations by hash and
number must agree.

The runtime admission also commits to a separately retained runtime bridge file.
The package checks the file's exact bytes against that commitment. It does not
interpret or certify the bridge's contents. A source-review checkpoint does not
by itself establish the compiler inputs or runtime of a deployed contract.

`synthetic_fixture` and `trusted_rpc` are explicit provenance choices. A retained
transcript can prove internal correspondence and replay, but cannot authenticate
its provider or establish chain consensus. The new transcript profile preserves
unavailable outcomes and is not silently converted into the older successful-call
observation format.

## Assemble and verify offline

Use the existing Museum Python environment. Supply independently reviewed input
commitments and a new output directory whose parent already exists:

```powershell
python -m tools.museum.collection_script_package_v1 assemble `
  --anchor ANCHOR.json --anchor-hash ANCHOR_HASH `
  --transcript TRANSCRIPT.json --transcript-hash TRANSCRIPT_HASH `
  --runtime-bridge RUNTIME-BRIDGE.bin --runtime-bridge-hash BRIDGE_HASH `
  --provenance synthetic_fixture --disclosure public --output PACKAGE
python -m tools.museum.collection_script_package_v1 verify PACKAGE `
  --manifest-hash PACKAGE_HASH
```

The package retains the exact anchor, transcript and runtime bridge under
`source/`, the reconstructed snapshot, and the exact package/source/wire/transport
profiles under `definitions/`. Verification replays the native reader, consumes
the complete transcript and reconstructs every package byte. Rehashing a changed
report or omission does not make it valid.
Complete interpreted script and library bytes are also emitted under `payloads/`,
separately for each current or saved-bundle observation. Missing payload files do
not mean an empty dependency; the snapshot retains the applicable reason.
Complete bytes returned by the original host can be retained even when a separate
registry read is unavailable. Payload references preserve the wire validator's
completeness flags; a retained binary does not turn partial registry observations
into complete evidence.

Only explicitly public inputs are supported. This standalone source package
does not change the canonical dossier's 49 requirements or establish their
completion. Native release evidence, institutional acceptance, registration of
these tooling profiles and actual runtime capture remain separate work.
