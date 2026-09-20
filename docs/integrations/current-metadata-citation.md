# Current metadata work citation

Current default JSON carries `properties.stream.citation`, with the original work identity:

```text
eip155:<chainId>/erc721:<lowercase original Core address>/<global tokenId>
```

All integers use full unsigned decimal notation. The address has `0x` followed by
exactly forty lowercase hexadecimal digits. Collection serial, Renderer address,
Registry address and a successor's address never replace the work identity.
This is a base citation, without a finality, snapshot or recovery qualifier.
In particular, a configuration record hash is not a snapshot citation.

The current linked ordinary and script-bundle render entries receive Core and
chain explicitly from their original Router context. They compose live Artist
attribution and citation under one `properties` object. Core's fallback uses its
existing linked helper and delegate-host context; its selector is unchanged and
the helper is now `view`. Core source and storage are unchanged. Remote OFFCHAIN
token URIs remain remote URIs; this implementation does not rewrite remote JSON.

## Separate STATIC admission

`IStreamCurrentCitationRenderer` advertises the fixed
`6529STREAM_CURRENT_BASE_CITATION_V1` profile, `renderCurrent(request, mode)` and
the existing encoder runtime binding. The original `tokenURI` and `renderView`
entries retain their original output. Current Router JSON/URI and `tokenJSON`
select the current entry only after `requireCurrentCitation(versionKey)` succeeds.
An advertised but missing, malformed, foreign or stale admission fails; it never
silently falls back to the old golden output. Core may then use its ordinary
explicit metadata-unavailable fallback.

The original Registry constructor, version registration and all base/derived
storage roots remain unchanged. `IStreamCurrentCitationRegistry` adds an immutable
record and declared read list per original version in the fixed
`6529STREAM_RENDERER_REGISTRY_CURRENT_CITATION_STORAGE_V1` namespace. In particular,
the derived module's original manifest URI stays in slot 7. Registration is an original Governance V2
class-1 action over a distinct scope/state and exact declaration. The declaration
binds Registry/chain/schema pins, target set, original registration hash, current
profile/selector/encoder pins, evidence document identities and declared reads.

Admission requires ACTIVE retained catalog bytes for:

- A canonical `CurrentAnalysis`, tagged
  `6529STREAM_CURRENT_BASE_CITATION_ANALYSIS_ABI_V1`, binding the new profile,
  selector, renderer and encoder runtimes, complete declared read hash, original
  registration and named analysis-tool/findings commitments.
- Canonical `CurrentGoldenVector[]`, with three to sixteen vectors covering all
  three JSON modes: compact JSON 0, URI 1 and full JSON 2. At least three vectors
  are consequently required. Each exact request/mode is executed by bounded
  STATICCALL and compared to its independently supplied output hash.

The declared list must preserve every original read entry exactly and include
the new fixed encoder entry under its immutable `METADATA_COMPANION` target.
Serving rechecks every declared target runtime, renderer pin and encoder binding.
The Registry's serving binding checks are inlined, so that path has no transitive
library DELEGATECALL. Catalogue retirement or renderer deprecation does not erase
the previously accepted immutable evidence, following original retained-version
semantics. Renderer/runtime drift is terminal.

The onchain analysis document is an attributed assertion. Acceptance of a document
does not prove a complete transitive opcode analysis or adequate operational gas.
Deployment evidence must identify the exact linked code, complete read roster,
analysis tool and current-profile golden inputs/outputs; old-profile goldens alone
are insufficient. New current evidence must be generated for this source graph.
This change does not rewrite historical source manifests or golden artifacts.

## Historical boundary

Original linked finality entries and the original STATIC public entries preserve
their output. STATIC `historicalTokenMetadataJSON` and
`historicalFullTokenMetadataJSON` explicitly retain those original entries. Current
`tokenJSON` is distinct even though it can read a retained burned-token identity.
The original HTML and executable STREAM_CONTEXT_V1 are unchanged; citation is a
JSON disclosure, not a new JavaScript context field. Existing finality-selected
linked rendering still returns before the current ordinary path.

## Validation boundary

Ten isolated native tests pass for literal identity, full uint256 formatting,
lowercase/padding, ordinary/bundle/fallback/current STATIC JSON shape, no duplicate
properties and old-entry compatibility. Their bundle source is an explicit typed
fixture; these are output-codec checks. Seven authored actual-current recipes reuse the unchanged
`CurrentStaticTokenRenderingFixture`: real Core, Manager, Ledger, Artist owners,
Schema/Store, Registry, Renderer, Governance Executor and threshold Safes, with an
external entropy fixture and explicitly raised Router/Core budgets. They cover
governed admission, missing/foreign evidence, incomplete read declarations, bad
goldens, replay, runtime drift and original historical outputs.

The current golden recipe inserts a literal citation into the independently
literal-checked original actual-token output; it never reads `renderCurrent` to
construct expected hashes. Its analysis document remains explicitly synthetic,
and its inherited read roster is partial. These tests exercise evidence admission
and current routing; they do not establish release STATIC conformance. Those
seven actual-current recipes remain ABI-checked and unexecuted at this handoff.
The final 1,055-source ABI check passes, and all nine selected production products
fit under Solidity 0.8.19, viaIR, optimizer 200 and Paris. The 270 prior ABI entries
are retained except the intentional fallback helper's `pure` to `view` annotation;
its selector is unchanged. Original ordinary storage roots, including the derived
Registry module URI, are unchanged. Complete current-graph runtime and operational
gas acceptance remain separate.
