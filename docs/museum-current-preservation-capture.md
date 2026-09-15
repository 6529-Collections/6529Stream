# Actual current preservation capture

`tools.museum.current_preservation_capture` extends the existing
[current foundation media capture](museum-current-media-capture.md) with real
local file operations and original Safe publications. It retains a successful
SHA-256 comparison, a failed comparison against deliberately changed bytes,
an actual local copy and byte comparison, and a canonical preservation object.
All four media formats and the two preservation derivatives are reconstructed
from the captured original records. This is a public development fixture, not a
museum accession or a preservation institution's attestation.

## Run with retained native products

Use the same externally pinned native-input manifest and existing dependencies
as the foundation capture. The command starts and stops its own loopback Anvil;
it does not compile Solidity, connect to a public RPC, or broadcast publicly.
The output directory must be new. Restricted input rejects before launch.

```text
python -m tools.museum.current_preservation_capture --native-manifest native-inputs.json --native-manifest-sha256 <sha256> --output new-current-preservation-capture --disclosure public
python -m unittest tools.museum.test_current_preservation_capture tools.museum.test_current_media_capture -v
```

An existing Anvil executable can be supplied with `--anvil`. Actual constructor,
library link, runtime, governance and Safe checks remain those of the foundation
capture. The original media command keeps its original publication lanes and
meaning; extra hooks are selected only by the separate preservation command.

## Measurement, publication and source authority

The fixture writes its deterministic PNG and a separately changed file before
any publication. After the original semantic declarations have been published,
it reads their actual retained payloads and original receipts. Expected size,
SHA-256 and declared PRONOM identifier come from three exact selected records,
with full selectors and field pointers. A computed metadata-description hash is
not substituted for those stored expectations.

The capture registers the exact closed schemas through ordinary delayed
Governance Executor calls. A named software-agent description retains the
Python version and capture-source SHA-256 as explicit account statements. It
assigns neither a wallet nor a DID to that software. Then it:

1. Reads the actual PNG, computes SHA-256 and size, and compares both with the
   recorded expectations. The matching check publishes `SUCCESS`.
2. Reads the changed file and performs the same comparison. Its different bytes
   publish `FAILED`, retaining both expected and observed values.
3. Copies the PNG into a new file without overwriting a destination, reads both
   files back, and compares their complete bytes. The measured operation report
   is an original linked result of a `REPLICATION` report and event.
4. Publishes a typed `PreservationObjectRef` under its canonical media subject,
   using the declared source-master role, hash, size, MIME type and PRONOM value.
   This does not claim independent format identification or rights ownership.

Reports and events use original independent-attestation record families and
class-5 account authority. Each report precedes the event that selects it;
actual stored bytes are read back after every Safe publication. Check and copy
times come from host UTC when the local operation runs. They are distinct from
simulated-chain publication timestamps and file modification times.

The host executing this fixture observes the operations described above. An
offline recipient can verify recorded authorship, selected relationships, local
observation consistency and byte commitments. Those checks cannot independently
prove historical execution, the reported clock, software identity, human review
or institutional approval. This workflow records no class-7/8 Metadata RIGHTS
receipt and makes no current rights-selection claim.

## Outputs and offline replay

`package/` retains the original recorded Linked Art, PREMIS file, IIIF and LIDO
package. `preservation-package/` is the distinct typed event/agent/fixity
derivative; `object-package/` is the canonical object derivative with no rights
selection. Each retains the original source closure and external manifest hash.
The original package's media declarations are not relabeled as embedded files.
Actual measured files remain in `observed-files/`; exact selected observations
are also retained by the performed-check derivative under its own profile.

`preservation-result.json` reports the three selected events, one selected
object, derivative hashes and completed offline checks. The capture also tests
that changing a successful check's supplied observation is rejected. A failed
check is a valid recorded outcome; it is not discarded to obtain a positive
export. `deployment-evidence.json` retains the measured reports, prior selectors
and transaction evidence; `execution-journal.json` is written on success or
failure. The owned Anvil process is terminated in either case.

After the capture, use the ordinary network-free verifier with each externally
retained hash:

```text
python -m tools.museum.package_v2 verify new-current-preservation-capture/preservation-package --manifest-hash <preservationManifestHash>
python -m tools.museum.package_v2 verify new-current-preservation-capture/object-package --manifest-hash <objectManifestHash>
```

The retained native manifest identifies the exact prebuilt source scope. This
example does not establish latest-source or whole-product integration, consensus
finality, public deployment readiness, all preservation event combinations,
Metadata RIGHTS publication or institutional conformance.
