# Native reference capture and complete-object fixity

These tools preserve and run actual browser/toolchain bytes. They do not publish
records, sign archival receipts, classify arbitrary JavaScript, or establish
public-chain storage. Use the separately admitted reference-render profile and
original authorization when publishing their observations.

The current native profile uses Windows x86_64, Python 3.12.10 and the exact
dependencies in `requirements.txt`. It captures a synchronous, canvas-only still
from the original Stream HTML wrapper, with software rasterization, sRGB, DPR 1,
the exact viewport, en-US/UTC and explicit unsupported-feature rejection. Two
fresh processes must produce identical PNG bytes. Static artwork classification
must be an original authorized declaration; successful execution is not that
declaration or a complete analysis of unreachable code.

```powershell
python -m unittest tools.preservation.test_reference_package tools.preservation.test_reference_archive -v
python -m unittest tools.preservation.test_reference_manifest -v
node tools/preservation/generate_native_vectors.mjs --check
python -m tools.preservation.reference_capture --engine <engine.exe> --html <original.html> --width 64 --height 64 --output <new-directory>
```

The capture report retains exact loaded-module identities, build, flags, GPU
facts, source/capture hashes and observed runtime restrictions. Diagnostic JSON
may include the browser's floating-point diagnostic values and makes no RFC8785
registration claim. HTTP/file/WebSocket page loads are blocked and unexpected
requests rejected. This is not an operating-system firewall or a claim of zero
background OS network activity. No user browser profile is opened.

`reference_package native` copies the complete named Chrome version directory,
launcher, pinned official portable Python ZIP, installed websockets distribution,
capture tool and preservation note. It excludes user profiles and credentials.
The original Python ZIP must match its built-in SHA256 pin. The complete package
has deterministic ZIP metadata, ordered member inventory and ordered 512 KiB
transport parts. This transport size is not an EVM archive requirement.

```powershell
python -m tools.preservation.reference_package native --chrome <application-directory> --version <exact-version> --python-zip <pinned-python-zip> --output <new-package-directory>
python -m tools.preservation.reference_package restore --package <package-directory> --manifest-sha256 <externally-trusted-parts-manifest-hash> --output <new-runtime-directory>
```

Restore validates the externally anchored manifest, all parts, whole ZIP, every
original member and exact inner manifest before writing runtime files. Run the
restored `python/python.exe`, `tool/reference_capture.py` and `engine/chrome.exe`
to demonstrate that the package supplies the engine and toolchain. Compare every
loaded non-OS runtime module against the package inventory; name and hash all
remaining Windows prerequisites explicitly. A Windows loader, Ink or Defender
module outside the Windows directory must not be silently treated as packaged.
Font-dependent, audiovisual, interactive and GPU-dependent captures remain
unsupported by this profile.

The proprietary-browser license basis is `undetermined`, with a preservation
note; that note is neither a license nor permission to redistribute the binary.
Windows is an external named platform prerequisite, not an included OS image.

```powershell
python -m tools.preservation.reference_archive --object <complete-runtime.zip> --output <whole-file-observation.json>
```

`reference_manifest` requires the independently anchored original reference JSON,
the pinned native snapshot JSON (`--snapshot-manifest`), and the complete binary
content leaf manifest (`--leaf-manifest`), alongside runtime and capture inputs.
It verifies all checkpoint leaves before selecting first/last retained tokens;
aborted allocation gaps do not renumber serials, and burned endpoints remain
applicable. Leaf records do not contain serial or lifecycle fields: these remain
statements checked by the original onchain publication, not independent offline
Core observations. See the full [reference-render validation inputs and trust
boundary](../../docs/guides/native-reference-render.md#publication-sequence).

Fixity streams the same original bytes through flat SHA256, Keccak256 and native
Arweave chunk reconstruction. The native root is distinct from flat SHA256 and
must never be replaced with a raw-CID shortcut. Ordered nonempty chunks and
first/last proof paths are retained; the native final empty leaf at exact chunk
multiples is retained in the root only. `generate_native_vectors.mjs` independently
executes every function body from the pinned upstream source, substituting only
its two SHA256/concatenation imports. The vendored source/license are exact bytes;
the `.ts.txt` transport suffix preserves the upstream TypeScript bytes under the
repository's existing LF rule on Windows.
The 11 boundary vectors and existing original single-chunk fixture are offline
algorithm evidence, not native consensus or upload receipts.

The observer's full-file output is evidence for a named independent fixity
signer. Its two authority flags deliberately remain false. Actual EOA/ERC1271
receipt/fixity admission and current coverage are described in
[`external-object-archive.md`](../../docs/guides/external-object-archive.md).
