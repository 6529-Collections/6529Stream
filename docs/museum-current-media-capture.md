# Actual current foundation media capture

`tools.museum.current_museum_capture` creates one public test-image example through
actual, prebuilt Stream contracts and official Safe accounts on its own loopback
Anvil. It publishes the original semantic records, captures their reads and
receipts, and exports the selected source as Linked Art, PREMIS, IIIF and LIDO.
This is a development example of a recorded source, not a museum accession.

The foundation uses actual Core, Governance Executor, Role Registry, Module
Registry, System Manifest, Schema Registry and its Chunk Store. An existing
native `StreamDeploymentPlan` produces the canonical genesis configuration.
Ordinary delayed governance admits collection creation, the Schema Registry
publication selector, and exact schema/profile documents. A separate two-owner
Safe publishes independent attestations. Both Safes execute real `approveHash`
and `execTransaction` calls; the capture does not manufacture ERC-1271 success,
replace code or storage, or impersonate a contract sender.

## Inputs and execution

Use existing native artifacts whose source and compiler context have been
reviewed separately. This command never runs Forge or Solc and never reads a
remote RPC URL. The JSON input manifest has this shape:

```json
{
  "mode": "current_museum_native_products_v1",
  "products": {
    "StreamCore": {
      "source": "smart-contracts/core/StreamCore.sol",
      "artifact": "/absolute/path/to/StreamCore.json",
      "sha256": "<SHA-256 of the complete native artifact>"
    }
  },
  "safeFixture": {
    "path": "/absolute/path/to/test/fixtures/safe/1.4.1.json",
    "sha256": "<SHA-256 of the exact official fixture>"
  }
}
```

Supply the actual Core, Governance Executor, Role Registry, Module Registry,
System Manifest, Schema Registry, Governance Bootstrap, Governance Action Policy,
Deployment Plan and Collection Attestations products, plus every declared linked
library. Each product names its exact source and contract. Missing, ambiguous or
mismatched products fail. Library selectors use the compiler's method identifiers,
including nominal struct signatures, rather than assuming contract ABI tuple
selectors work for libraries.

```text
python -m tools.museum.current_museum_capture --native-manifest native-inputs.json --native-manifest-sha256 <sha256> --output new-current-media-capture --disclosure public
python -m unittest tools.museum.test_current_media_capture -v
```

`--anvil` may specify the existing executable. No environment installation is
performed. The output directory must be new. Restricted classification rejects
before input reads, directory creation or Anvil startup. The owned process is
terminated on success and failure, and an execution journal retains failed
attempts. Prebuilt production runtime sizes retain the 24,576-byte limit; library
addresses are resolved explicitly and patched only at declared offsets. Deployed
runtime bytes must match outside declared immutable words and the verified
Solidity library self-address guard. Constructor arguments, links, runtime hashes,
transaction receipts and the original input manifest remain in the capture.

## What the example demonstrates

The prospective input builder creates a deterministic 70-byte PNG and derives its
size, SHA-256, raw content identifier and one-pixel dimensions from those exact
bytes. An actual Safe subsequently records those facts, explicit work/creation
statements and a selected publisher assertion. The named publisher is a declared
Group, distinct from the account issuer. It remains an account-authored claim;
no human or legal-body identity is inferred from Safe ownership.

The exporter uses the existing `IndependentSourceAdapter`, publication receipts,
registered interpretation capture and `RecordedSemanticSource` unchanged. It
retains their original bytes and verifies offline replay before projection. The
completed package is reconstructed with the existing offline verifier. A second
selection omits only the publisher assertion from the same source: PREMIS and
IIIF remain supported, while LIDO produces a precise unsupported report and no XML.

`result.json`, `pins.json`, `missing-publisher-report.json` and `package/` describe
the completed output. `test-image.png` is retained next to the package; the
metadata package does not embed or retrieve media bytes. Its content URI describes
the local bytes but does not assert that an IPFS gateway serves them. The original
source records, definition bytes, publication receipts and replay transcripts are
included in the package under its existing public-input policy.

This workflow covers a selected native foundation and independent metadata flow.
It does not establish the complete current product graph, latest-source parity,
consensus finality, public deployment readiness, independent human review or
institutional conformance. Synthetic adapters and prior recorded package modes
are unchanged. Full release evidence remains a later integration activity.
