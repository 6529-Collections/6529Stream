# Add registered token script evidence to the current assessment

The current assessment V2 replays a complete
[current V1 assessment](museum-current-native-assessment-v1.md) and retains
every file under `current-v1/`. It keeps the original nineteen packet groups
and forty-nine requirement identities. A separately replayed
[registered token-script capture](museum-token-script-native-v1.md) may add
`OD-SCRIPT-MANIFEST` to the current forty-nine-row assessment.

The script capture must identify the same chain, Core, collection, token,
block hash, height, timestamp, state root and environment as the V1 source.
The selected Core, Metadata, SchemaRegistry and Store runtimes must also agree
with V1's retained V4 Metadata source. The original script and Registry RPC
transcripts are reconciled with every retained V1/V4 source; overlapping
successful getter results, headers, receipts and log observations must agree.
Explicitly unavailable script reads contribute no positive value. The
registered capture itself checks that its native script and four ACTIVE
interpretation documents came from the same source state and
current Metadata host. Every child package is replayed from its original
transcript; its exact bytes remain under `script/`.

A complete selected script establishes positive `script` work class. The
script requirement is verified only when its dependency is also complete or
authenticated empty and the exact registered interpretation matches. An
unknown selection stays `unknown`; a complete script with an incomplete
dependency has `script` work class but leaves `OD-SCRIPT-MANIFEST` unresolved.
`OD-DEPENDENCY-MANIFEST` remains a separate unresolved requirement. V2 never
infers a `non_script` class or changes a V1 or V4 decision.

## Assemble and verify

Use the [Museum Python environment](../tools/museum/README.md) and supply the
original external manifest pins:

```powershell
python -m tools.museum.canonical_current_assessment_v2 assemble --current-v1 <current-v1-directory> --current-v1-hash <current-v1-manifest-hash> --script <registered-token-script-directory> --script-hash <registered-token-script-manifest-hash> --disclosure public --output <new-directory>
python -m tools.museum.canonical_current_assessment_v2 verify <new-directory> --manifest-hash <current-v2-manifest-hash>
```

Omit both `--script` and `--script-hash` when the capture is unavailable. The
new assessment lives at `assessment/current-requirements.json`, and
`assessment/previous-comparison.json` locates V1 decisions. Synthetic fixture
tests show the join and replay behavior; they are not an actual-chain
registration or Museum acceptance claim. Provider completeness, consensus,
historical writer grants, renderer execution and institutional acceptance
remain unproven.
