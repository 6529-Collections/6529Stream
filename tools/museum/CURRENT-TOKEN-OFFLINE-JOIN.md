# Current token offline join

`current_token_offline_join_v1` checks a separately pinned original V10 native
input transport and a single pinned V4 dossier against a current 49-row
assessment, a native four-format package, and an optional V5
review wrapper. It verifies each package independently, then compares the
retained original V4 files byte-for-byte. It writes no new package and makes no
live RPC calls.

## Inputs before this check

`current_token_dossier_capture` is a coordinated fresh-chain transaction recipe.
Its output stops at an original token capture, retained token, base assembly,
and native dossier; it does not produce a V10 acquisition packet or V4 dossier.
Do not run that recipe against a shared chain merely to satisfy this check.

The V4 source must already have been independently built and pinned through:

1. A V5–V9 acquisition packet with its exact original manifest pin.
2. A `canonical_native_inputs_v1` transport containing preservation input,
   WORK evidence and five original Metadata files, and recovery evidence, all
   for the same final block; an optional complete condition capture can join.
3. `acquisition_canonical_v10`, `canonical_object_dossier_v3`,
   `canonical_semantic_export_v2` with its owner-definition plan and selection,
   then `canonical_object_dossier_v4`.
4. `canonical_current_assessment_v1` from that exact V4, optionally with
   finality and entropy captures; `canonical_current_assessment_v2` from that
   V1, optionally with a registered token-script capture.
5. `native_multiformat_package_v2` from that exact V4, with a pinned closed
   export plan containing Linked Art, PREMIS, IIIF, and LIDO adapter plans.
   Empty selections remain explicit and may leave media or format coverage
   unsupported. A painting body requires original retained VIEW bytes and a
   separate operator designation.

The optional V5 review wrapper must also derive from the same V4. Original
captured inputs are retained below V4's V10 acquisition child and checked by
the existing concrete replay consumers. The join reports that retained native
input manifest hash; it does not infer that an unrelated capture directory was
used to build it.

## Run

From the repository root in PowerShell, set each external pin to the exact
manifest hash recorded when its package was created:

```powershell
$nativeHash = '<V10_NATIVE_INPUTS_MANIFEST_HASH>'
$v4Hash = '<V4_MANIFEST_HASH>'
$assessmentHash = '<CURRENT_V2_MANIFEST_HASH>'
$formatsHash = '<NATIVE_MULTIFORMAT_V2_MANIFEST_HASH>'
.\.venv-museum\Scripts\python.exe -m tools.museum.current_token_offline_join_v1 `
  --native-inputs <V10_NATIVE_INPUTS_DIRECTORY> --native-inputs-hash $nativeHash `
  --v4 <V4_DIRECTORY> --v4-hash $v4Hash `
  --assessment <CURRENT_V2_DIRECTORY> --assessment-hash $assessmentHash `
  --formats <NATIVE_MULTIFORMAT_V2_DIRECTORY> --formats-hash $formatsHash
```

Add `--v5 <V5_DIRECTORY> --v5-hash <V5_MANIFEST_HASH>` when a reviewed dossier
exists. A successful command prints one JSON report with all input pins,
source state, original 19/49 counts, current verified codes, and per-format
availability where each adapter reports it. It always reports source
authentication, current authority, actual capture acceptance, and
institutional acceptance as unproven. Supplied
`trusted_rpc` provenance remains a source claim, not independent authentication.

The command is useful after Testing supplies genuine original inputs and
external pins. Synthetic fixture success demonstrates offline replay and join
logic only. Complete current-chain capture and institutional acceptance still
require their own evidence.
