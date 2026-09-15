# Actual local Metadata RIGHTS capture

`tools.museum.current_rights_capture` extends the current foundation/media and
preservation example with original Metadata `RIGHTS_STATEMENT` publications.
It runs on a new loopback Anvil instance using supplied native artifacts and
actual governance and threshold-Safe calls. It never compiles Solidity,
installs a dependency, injects code/storage, or broadcasts to a public chain.

The two JSON statements are explicit test declarations. Their class-7 and
class-8 receipt authority means the actual Metadata host admitted those Safe
accounts through its original family-writer mechanism. It does not establish
legal ownership, license permission, licensor identity, institutional approval,
or current rights precedence. Independent class-5 object/link assertions remain
separate from the Metadata receipt authority.

## Native inputs and dependency scope

Use the original current-media native manifest plus the retained current native
artifact directory. `augment_manifest(original, expected_sha256, native_out)`
returns a separate canonical manifest, preserving every original product and
adding only the required source-identified artifact/link closure. Save its
bytes to a new file and pin its SHA-256 externally before running the CLI.
Each artifact remains SHA-256 checked at fixture construction.

The fixture creates the genuine retained Artist facade, its factory-created
extensions with exact original birth bindings, Manager/Ledger, and archival
coverage/checkpoint dependencies. The original one-use Coordinator deployment
slot remains unfulfilled. Neither that slot nor its absent product is selected
into Core. Artist onboarding and finality are unavailable in this finite
fixture. The class-7/8 direct Metadata writer does not consult the Coordinator;
this example proves that supported Metadata path, not a complete initialized
Artist/Metadata/finality system.

Mutually linked Artist libraries use an explicit ordinary-CREATE batch. Native
AST definitions must identify libraries. Only declared library link offsets and
compiler-declared self-address patches are changed. Every predicted address,
constructor transaction, deployed runtime, and complete batch runtime readback
is checked before deploying any dependent contract. This does not relax the
24,576-byte deployed-code limit or admit a test-only assembly contract.

## Run

```powershell
python -B -m tools.museum.current_rights_capture `
  --native-manifest PATH/rights-native-inputs.json `
  --native-manifest-sha256 EXACT_SHA256 `
  --output PATH/new-rights-capture `
  --disclosure public `
  --anvil PATH/anvil.exe
```

The output directory must be new. The fixture terminates only its owned Anvil
process, including on failure, and retains the transaction journal. Original
captures and manifests are never replaced. `restricted` disclosure is refused.

## Executed and replayed behavior

The fixture registers/selects the actual Metadata module through the existing
Executor/ModuleRegistry/Core path, admits its exact governance selectors,
registers the original RIGHTS schema/profile/JCS bytes, and configures the
original RIGHTS family and class mask. Separate Safes exercise classes 7 and 8.
Each first attempts an ungranted write, then retries the identical Safe target
and calldata after a real delayed grant. Original saved bytes, receipt class,
recorder and independent generic record hash must agree. A later class-7
revocation rejects a new record while its prior receipt remains readable.

After both actual records and their independent links exist, the source capture
pins one block and reads the original Metadata record/receipt/index/payload and
registered definitions. The rights derivative retains the original full-media
package plus the exact separate Metadata source anchor, transcript and deployment
evidence. The network-free verifier reconstructs the PREMIS resource export,
including two separate record-scoped licensor agents. It does not invent a
current-rights selection or promote a quoted assertion into a grant.

`rights-result.json` records the actual result and qualified dependency scope.
`metadata-rights/` retains its external pins and captured bytes. `rights-package/`
is independently replayable with the existing generic verifier:

```powershell
python -B -m tools.museum.package_v2 verify PATH/rights-package --manifest-hash EXACT_MANIFEST_HASH
```

Offline input/codec tests are separate from a successful local capture:

```powershell
python -B -m unittest tools.museum.test_current_rights_capture tools.museum.test_current_media_capture tools.museum.test_current_preservation_capture
```

If the original captures in `metadata-rights/` already exist but package assembly
has not completed, finish from those exact retained bytes without RPC:

```powershell
python -B -m tools.museum.current_rights_capture replay PATH/capture
```

This writes a new `rights-package/`; use `package_v2 verify` for an existing
package. Reverted-frame diagnostics in the transaction journal explain local
failures; they are not durable receipt logs or independent historical evidence.

The retained development example completed 535 local transactions: 532 successful
receipts and three deliberate Safe denials. It captured both original Metadata
receipt classes and 22 independent source records, then verified a 436-file
rights package. Earlier constructor/ABI/governance-planner failures were retained
separately. The actual publications and source capture completed before a final
XML namespace assertion was corrected; package completion then ran entirely
from those captured bytes. This is finite local acceptance, not a full-current
system or institutional-conformance result.
