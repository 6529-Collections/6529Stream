# Preservation factory and provider source checkpoint

Base: `d1fdcc89bd2becfa8ad1ab1733431cb045179f0d`.
This additive batch continues [ADR 0054](../docs/adr/0054-explicit-non-sanction-preservation-rendering.md).

## Implemented source

- Fixed COLLECTION and TOKEN/RELEASE/SEASON factories create the seven matching
  preservation children, preserve genuine original source-factory authority,
  and retain recipe, runtime, scope and graph identity checks.
- COLLECTION retains the original generic bundle host. A distinct scoped
  preservation bundle retains complete ordered occurrence coverage and currentness.
- New provider and discovery capabilities consume only exact matching 608/800
  byte root bindings, 608 byte output manifests and their actual fixed graphs.
  The original static base-provider routes remain unchanged.
- Separate input manifest documents preserve the complete non-sanction facts,
  entropy policy, ten source inputs, capture and original Artist evidence.
  Sanction/archive evidence stays independent of the preserved output.

## Authored tests and source review

There are 47 authored cases: COLLECTION factory 11, scoped factory 8, scoped
bundle 7, provider/discovery 9 and input manifest readers 12. Factories and
their actual children are exercised in source-authored tests. Archive/Safe and
Schema/Store components are genuine; identified root, late-record, Registry
staging and independent-fact boundaries remain explicit.

Independent reviews cover both construction families, scoped bundle, provider,
discovery and tests. Review corrected a TOKEN manifest fixture from two leaves
to its required single leaf. It did not change production behavior.

## Validation and limits

ABI-only capture: `artifacts/art27-gap3/preservation-factories-provider-freeze`.

- Solidity 0.8.19: 790 sources, zero compiler errors.
- Input SHA-256:
  `784e2c60e995de7c82b026594398e7abbca96996652a8199fa038e562c6b71e6`.
- Output SHA-256:
  `0a583d6c1a2dc87b9949a80c95cfa2994ae124177369dfa4e853d1f8f411541c`.
- Exact schema documents match Solidity literals and captured ABI field lists.
  Scoped formatting, documentation and Windows whitespace checks pass.

The same six pinned B/writer dependency sources from the preceding batch are
excluded from this commit. The capture's index bridge records their pins and
the exact indexed source bytes. Shared Router dispatch and closed archive
correspondence are integrated independently by their assigned owners.

No native test, code generation, linked size, gas or actual ceremony result is
claimed. The separate current-stack construction and actual producer/Registry
ceremony sources are subsequent work. Original full-output sources remain intact.
