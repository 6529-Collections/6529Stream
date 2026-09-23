# Compose a current token Museum dossier offline

`current_token_composition` is a read-only follow-up to the coordinated
`current_token_dossier_capture` recipe. It verifies that recipe's retained token,
base dossier and native dossier, then composes the existing V10, V3, semantic
V2, V4, V5, current assessment V1/V2 and four-format packages. The final
offline join checks exact original native-input and V4 byte retention. All
stages are published together to a new output directory after successful
replay. The command performs no RPC call or transaction.

The original recipe cannot supply V10's preservation, WORK/Metadata and
recovery inputs. Supply their original bytes at the **same final block** as
the capture, plus an independently pinned V5–V9 acquisition packet. The
`--native-sources` directory has exactly these paths:

```text
preservation/input.json
work/evidence.json
work/metadata/anchor.json
work/metadata/transcript.json
work/metadata/snapshot.json
work/metadata/pins.json
work/metadata/profile.json
recovery/evidence.json
```

It may also contain the complete original condition capture under
`work/condition/`. The command creates the existing
`canonical_native_inputs_v1` transport in memory and checks its externally
recorded manifest hash. It does not convert recipe observations into these
different source families or invent absent history. V10's concrete consumers
replay every supplied source and reconcile its native state with the prior
packet. The recipe capture is separately replayed and required to share the
final chain, Core, collection, token, block and state root. Its V1 summary
contains token identity but omits timestamp, state root and environment; the
command takes those three fields from the retained original anchor, checks
them against the verified native plan, and then compares all nine current
state fields to V4.

Provide the exact `canonical_semantic_export_v2` selection for the resulting
V3 and the closed four-adapter `native_multiformat_package_v2` plan for the
resulting V4. Both are externally pinned raw files. Their source hashes must
match the V3 and V4 this command recomputes. These plans can be prepared and
reviewed with the existing `canonical_semantic_export_v2 prepare-selection`
and native adapter plan tools after deriving those source manifests. A plan
with a guessed source hash fails. Empty selections remain explicit and do not
claim media availability or complete format mapping.

From the repository root, once every source and plan has an external pin:

```powershell
.\.venv-museum\Scripts\python.exe -m tools.museum.current_token_composition `
  --capture <RECIPE_OUTPUT_DIR> --capture-result-hash <RECIPE_RESULT_KECCAK256> `
  --prior <V5_TO_V9_PACKET_DIR> --prior-hash <PACKET_MANIFEST_HASH> `
  --native-sources <ORIGINAL_NATIVE_SOURCE_DIR> --native-inputs-hash <TRANSPORT_MANIFEST_HASH> `
  --selection <SEMANTIC_SELECTION_JSON> --selection-hash <SELECTION_KECCAK256> `
  --format-plan <FOUR_FORMAT_PLAN_JSON> --format-plan-hash <PLAN_KECCAK256> `
  --output <NEW_OUTPUT_DIR>
```

The recipe result hash is Keccak-256 of its exact `recipe-result.json`. The
native-input hash is the `canonical_native_inputs_v1.create` manifest hash
for the exact raw source tree above. Add paired `--conservation`,
`--production`, `--general`, `--transfer`, `--finality`, `--entropy`, `--script`
or `--owner-plan` directories and `--<role>-hash` pins when applicable.

The output contains the existing packages under `native-inputs/`, `v10/`,
`v3/`, `semantic-v2/`, `v4/`, `v5/`, `current-v1/`, `current-v2/` and
`four-formats/`. `run-result.json` records their manifest hashes and the
qualified offline-join report. The V5 wrapper has no Artist or General review
packet in this path; those remain unprovided. Neither the command nor a
successful synthetic regression authenticates RPC origin, chain consensus,
current legal authority, media retrieval, institutional standing or actual
current capture acceptance. Testing must provide genuine same-block original
inputs after the native deployment is ready.
