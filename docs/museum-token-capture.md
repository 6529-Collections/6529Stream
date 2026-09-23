# Actual token and selected-media capture

`tools.museum.current_token_capture` creates a new isolated local deployment,
mints one paid token, publishes fresh token-subject media and typed authority
statements through an actual Safe, and builds the
[scoped semantic-evidence dossier](museum-scoped-dossier.md). It uses existing
pinned native products. It does not compile contracts or use a live network.

## Exact composition

The input manifest selects an explicit constructor and recursive library
closure from the retained accepted mint build. It adds only separately pinned
`StreamCollectionAttestations` and `StreamIndependentReads` products. The Core,
governance, schema and linked `StreamMetadataRenderer` products retain their
mint-build origins. The manifest preserves the two extensions' original
compiler-pinned source bytes as provenance, including older linked-library
source. Those source bytes do not replace the selected renderer executable.

The accepted build establishes prior mint behavior. This newly linked and
deployed composition needs its own successful capture. Its manifest explicitly
records `joinedCompositionPreviouslyAccepted: false`; that historical fact
does not change after a successful new run.

Foundry artifacts can retain identical executable templates with different
compilation-local immutable declaration IDs. A narrow, pinned graph projection
supplies metadata for the Artist facade, Identity and their three abstract
ancestors. The tool requires exact creation/runtime templates, link references
and immutable offset groups before translating IDs. It never substitutes a
projection executable. CREATE slots and cyclic library addresses use ordinary
transactions, with exact deployed runtime checks.

## Run a fresh local capture

Use the existing [Museum environment](../tools/museum/README.md), Anvil, and
independently pinned local handoff and Museum artifact manifests. The handoff
contains the retained mint artifacts, acceptance result, source recipes and
graph projection. These inputs must exist locally; the tool does not discover
or download a replacement. Output paths must be new.

```powershell
python -m tools.museum.token_native_manifest work/mint-handoff.json work/museum-inputs.json work/token-inputs.json --handoff-sha256 <trusted-handoff-sha256> --museum-sha256 <trusted-museum-sha256> --token-graph
python -m tools.museum.current_token_capture --native-manifest work/token-inputs.json --native-manifest-sha256 <returned-sha256> --output work/token-capture --disclosure public
```

The second command starts its own loopback-only Anvil process, checks the
native manifest before deployment, and terminates that exact process on exit.
It retains the execution journal even when a later stage fails. Preserve failed
captures and use a new output directory for a corrected attempt.

Immediately before paid mint, `before-paid-mint/` retains an Anvil state dump,
the exact block, and a closed set of public fixture fields behind an external
checkpoint hash. It contains no signer keys. `tools.museum.token_diagnostic`
can restore that checkpoint into a fresh task-owned local chain for helper
diagnosis. The restored fixture is barred from claiming a fresh capture;
complete acceptance uses a new deployment with one coherent chronology.

The original Artist/Coordinator/finality graph is deployed before sale setup.
Real delayed governance registers modules, selects pointers and publishes the
matching system manifest. Distinct local Safe principals supply Artist and
platform consent. An unlocked local buyer pays the fixed-price sale. The
controlled development entropy provider is an explicit test substitution.

The token data contains the exact 70-byte test PNG. The fresh metadata
configuration uses its content URI, and fresh semantic claims bind its size,
SHA-256 and URI to the actual token subject. At the final source block the
capture reads Core identity, owner, lifecycle, token data, coordinator and
`tokenURI` using the exact canonical block hash. It retains the actual sale
transaction and receipt. No collection statement or earlier token fixture is
re-rooted into this capture.

## Evidence and remaining acceptance

Source, publication and registered interpretation transcripts are replayed
offline. The output contains the original authority V2 package, V3 semantic
export, selected-media BagIt dossier and OCFL object. `token-result.json`
records the exact subject, token ID and output hashes. The ordinary dossier
`verify` and `verify-ocfl` commands independently reconstruct those packages.

This is local trusted-RPC evidence. It is not consensus finality or secure
randomness. The default authority snapshot is explicitly synthetic, and the
account self-review does not establish a qualified human or authenticated
authority publisher. Selected presentation media does not establish the full
render-critical inventory, preservation roles, archival availability or the
adopted `OBJECT_DOSSIER_V1` acceptance.

## Executed local instance

The fresh local capture minted token `1` in collection `1` on chain `31337`,
with Core `0x0dcd1bf9a1b36ce34237eeafef220932846bcd82`. The final source block is
`1311`, hash
`0xeb97545385853d7aa947b8f440360be7b0c277e50f64113945bc377d33aa2818`.
Its 15 records all use token subject
`0x2f4ce6f76fb30d506d480e39202ed6fbf92f5721a6c98fa85af9b9b38a6d5331`.

The native input manifest SHA-256 is
`e6c2cefb2b322094dfd23694485cc74ff229a5cfc2d69bcdc1ee2346072ca67e`.
It selects 305 products, including the explicit two-product Museum extension.
The actual deployment/publication evidence retains 1,237 successful
transactions and 310 artifact instances. The mint transaction is
`0x7acca2677594241c3dbc04c8a091b21c17768879df885a3ac9f1d592bde1dfa6`.

| Output | External commitment |
| --- | --- |
| V3 export | `0x7fb4f5dda86886a7b7752ec1bd6174fd1cdf0647c7773a780f8b13c2924241b6` |
| Scoped BagIt dossier | `0xa5b26d213c405e04fb75d65d8bc457fd5bb1644c152025bf1cffd84a9ce36153` |
| OCFL inventory | `0x2756be5dee9edc9a7a75aacd4e83aab6df15551d4c77e66247a214b43b08a766` |

The verified bag contains 510 files (26,409,549 bytes); OCFL contains 485 files
(26,854,449 bytes). These counts describe this bounded capture. The test PNG
has SHA-256 `9cc2b380a9efb1077cefd7c25a09520a9dc477109d5d7bc4a035c5b55e7c7c84`.

## Replay the retained capture offline

The [retained fixture](../schemas/museum/dossier/token-local-fixture/manifest.json)
contains the exact capture inputs and original inert dossier-tool source
snapshot. Its external manifest commitment is
`0x62ad190d7baa57290c72d22a98fb2249bc043b632597fc4454e77178af883425`.
The compressed inputs occupy 3,945,562 bytes; the bounded JSON representation
expands to 38,261,006 bytes. Replay reconstructs and verifies the same V3,
BagIt and OCFL commitments without native artifacts, Anvil or network access.
It reads the original tool source as provenance bytes, without executing it.

```powershell
python -m tools.museum.token_fixture verify schemas/museum/dossier/token-local-fixture --manifest-hash 0x62ad190d7baa57290c72d22a98fb2249bc043b632597fc4454e77178af883425
```

The regression suite blocks sockets and rejects regeneration of the original
dossier-tool snapshot while rebuilding the retained positive. It also rejects
changed media, a foreign token subject, unrelated payment evidence and altered
native composition or sale evidence.

```powershell
python -m unittest tools.museum.test_token_native_manifest tools.museum.test_token_native_graph tools.museum.test_token_mint_flow tools.museum.test_token_media_inputs tools.museum.test_current_token_capture tools.museum.test_token_diagnostic tools.museum.test_token_fixture -v
```

These focused tests cover input boundaries, recipe preparation and retained
offline replay. They do not replace a fresh native capture or the wider
protocol test suite.
