# Keep and reconstruct a completed collection

A collector package preserves the exact inputs and outputs needed to view the
three local Field Studies artworks without a running RPC, metadata server or
Stream application. It includes the stored renderer, immutable token bytes,
finalized seeds, artist attribution, complete metadata JSON, original HTML and
independently regenerated SVG previews. Open `index.html` to view the retained
artworks, or run the included verifier using Node.js.

This is a scoped local demonstration. It does not implement the broader artwork
finality registry and rendering-input manifest design, prove chain consensus,
or claim production readiness. The controller supplied the demo entropy.

## Complete and freeze the local collection

Finish all [product scenarios](product-demo.md) before freezing. The completion
runner accepts only the existing local Anvil chain and never creates or resets
a node. It keeps a separate journal and preserves the original product evidence.

```powershell
pwsh -NoProfile -File scripts/complete-current-stack-collection.ps1 `
  -DeploymentState D:/local-stream/current-stack.json `
  -ScenarioState D:/local-stream/product-demo/scenario-state.json `
  -OutputDirectory D:/local-stream/completion `
  -Stage All -Execute -AdvanceLocalTime
```

`Complete` stores the final collection name, description and deterministic SVG
script through an ordinary class-1 action with its 48-hour delay. `Freeze`
executes a class-2 action with the normal 72-hour delay, in this order: close the
collection, block burns, freeze the collection, and freeze its royalty record.
The local time-advance switch is explicit; it does not alter contract delays or
veto rules. Without it, rerun after the recorded action timestamp. The selected
collection is permanently closed with three completed mints; its original
configured cap remains ten and the unused mint capacity cannot be consumed.

The runner requires all three tokens to exist with their expected owners, final
entropy and completed metadata notifications, and requires the auction to have
settled. It then makes read-only calls from the normal authorized actors and
requires the exact frozen-metadata, frozen-royalty and burn-block error data.
Those probes send no transactions and retain their requests and responses.
Collection 1 is not frozen by this workflow.

`Package` captures one pinned block and reconstructs the files. It needs no
signing access. Use `-BlockNumber` to choose a specific retained block and
`-CollectorDirectory` for a separate package destination; an existing manifest
is verified rather than overwritten. Completed transactions are checked and
reused on subsequent runs.

## What is permanent, and what still has authority

The current implementation preserves token identity and token data at mint.
The selected coordinator retains finalized seeds and locks its collection
entropy policy when minting starts. Accepted artist attribution is already
locked once the collection has started. Collection closure prevents new mints;
the burn block prevents burns; collection freeze prevents configuration changes
and makes the current metadata router reject collection metadata and script
edits. The separate royalty freeze locks the selected resolver's collection
record and its existing immutable split wallet.

**Global pointer authority remains.** Governance can still replace Core's
metadata router, entropy coordinator, artist registry or royalty resolver.
Freezing a collection's record in today's resolver does not freeze Core's future
royalty response; likewise it does not globally pin future `tokenURI` output.
The package therefore retains the selected module addresses, runtime bytes,
observed code hashes, pointer fields and royalty configuration at its pinned
block. It makes no claim that global pointers were frozen. Transfers remain
possible, so recorded owner addresses describe that block, not future custody.
There is no separate token-freeze operation in this current stack.

## Verify the portable files

Retain the manifest SHA-256 through an independent trusted channel alongside the
package. Treat a supplied `verify.mjs` as executable code: run it only when its
source or independently supplied hash is trusted. For an untrusted package, use
the repository-owned verifier with the package as data:

```powershell
node scripts/verify_current_stack_collector.mjs D:/local-stream/completion/collector-package `
  --expected-manifest-sha256 <retained-64-character-sha256>
```

Hash integrity alone does not establish who supplied it or whether its
RPC observations describe a canonical public chain.

```powershell
node D:/local-stream/completion/collector-package/verify.mjs `
  D:/local-stream/completion/collector-package `
  --expected-manifest-sha256 <retained-64-character-sha256>
```

The verifier needs only built-in Node modules. It checks exact membership,
lengths and SHA-256 values; assembles metadata JSON and HTML again from the
retained collection, token, seed and artist inputs; and regenerates the SVGs.
It executes only the exact reviewed Field Studies renderer selected by its
built-in hash, not arbitrary artwork scripts. The visible gallery uses static
SVG files. No network request or wallet is needed.

Keep a [supported state snapshot](state-exports.md) separately when broader
public getter coverage is useful. That client package captures selected records,
raw ABI responses and code hashes at the same block; it still does not claim a
complete archive or replace chain verification.

Developer checks:

```powershell
pwsh -NoProfile -File scripts/test_current_stack_scenarios.ps1
pwsh -NoProfile -File scripts/test_current_stack_completion.ps1
node scripts/test_current_stack_collector.mjs
```
