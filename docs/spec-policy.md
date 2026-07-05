# Stream Specification Policy

6529Stream is permanent infrastructure for the 6529 network. The first
production deployment is not a stepping stone toward a better future system;
it is the permanent system. Every specification in this repository is written
against that assumption.

This document defines how Stream specifications are classified, worded,
finalized, and amended. Every document listed in the
[spec inventory](#specification-inventory) follows these rules. The
[open-questions register](spec-open-questions.md) tracks every decision that
is still genuinely open.

## Why Permanence Classes Instead Of Launch Phases

Earlier drafts sorted requirements along a time axis: "launch v1
requirement" versus "future extension posture." That axis is wrong for
permanent infrastructure because it implies two quality tiers — things we
finish now and things we finish later. A deployed contract system has no
later. Once `StreamCore` is on chain, its bytecode, its identity semantics,
its hash preimages, and its event vocabulary are fixed for the life of the
system.

The correct axis is mutability. Every requirement in the Stream specs is
classified by what can ever change about it, not by when it ships:

| Class | Definition | What the spec must provide |
| --- | --- | --- |
| Permanent | Semantics that can never change for this Core line. Core bytecode behavior, token identity semantics, hash preimages and domain constants, event schema versions, public interface selectors, freeze semantics, and the extension mechanisms themselves (registry semantics, module capability surfaces, pointer lifecycle, finality model). | Complete, final, EIP-grade definition before deployment: exact signatures, storage-visible semantics, event schemas, revert conditions, stated invariants, and a named verification gate for every requirement. Changing a Permanent surface after deployment means declaring a successor Core line, never patching this one. |
| Replaceable | Satellite implementations behind Permanent interfaces: revenue resolver, split factory/wallets, mint manager and ledger, metadata router and renderers, collection metadata and its satellites, entropy coordinator and providers. Each deployed implementation is itself immutable; what changes is which implementation a governed, evented, freezable assignment points to. | Complete specification of the genesis implementations plus the Permanent interfaces they satisfy. New implementations may be added over decades, but only through the frozen extension mechanisms and only with their own accepted specs. |
| Operational | Off-chain practice: runbooks, monitoring, deployment ceremonies, state exports, evidence generation, archival drills, funding posture. | Documented, reproducible, and content-addressed where load-bearing. Freely versionable; changes follow normal repo governance, not successor declarations. |

The rule that carries over from the old framing, restated on the new axis:
a module outside the genesis deployment set must never be an implicit
dependency of a Permanent or genesis surface merely because it appears in a
design appendix.

## Future Implementations, Never Future Semantics

The only legitimate meaning of "future" in a Stream spec is a future
implementation of an interface that is already Permanent. "Other entropy
providers remain future adapters behind the same interface" is a valid
statement, because the adapter interface, provider-epoch semantics, and
registry lifecycle are fully specified now. "We will decide the fallback
semantics later" is not a valid statement for any Permanent surface.

Concretely:

1. Extension mechanisms — interfaces, selectors, registries, capability
   surfaces, compatibility checks, freeze and recovery semantics — are
   Permanent and must be final before deployment, even when only one
   implementation exists at genesis.
2. Extension catalogs — the set of registered modules, providers, renderers,
   counter policies, and approved assets — are Replaceable-layer state and
   grow over time through the frozen mechanisms.
3. A capability whose semantics are not specified in v1 is excluded from
   v1, not deferred. Adding it later requires either a new accepted
   module spec against the frozen interfaces (Replaceable) or a successor
   Core line (Permanent). Exclusions are listed explicitly in the
   [protocol v1 specification](launch-v1-target-architecture.md) so absence
   is provably intentional.

## Document Lifecycle

Every spec document carries a status line immediately after its title:

```text
Specification status: Draft | Review | Final
```

1. `Draft`: content is complete enough to review but may still contain open
   questions. Open questions must be marked inline and mirrored in the
   [open-questions register](spec-open-questions.md).
2. `Review`: no known open questions on Permanent surfaces; undergoing
   external review, audit alignment, and conformance-gate mapping.
3. `Final`: the standard the deployed system must satisfy. A document that
   specifies Permanent surfaces may reach Final only when every inline open
   question affecting it is resolved, external review is recorded, and every
   `must` maps to a named gate in the
   [conformance matrix](launch-conformance-matrix.md), a test, or a release
   artifact.

Production deployment of any surface is blocked while the spec that defines
it is not Final. The conformance matrix is the enforcement point: a failed
or unmapped gate is a spec violation, not a roadmap item.

After the genesis deployment, a Final spec for Permanent surfaces changes in
only two ways:

1. Errata: corrections that cannot change deployed semantics — wording,
   broken links, clarified descriptions of behavior the bytecode already
   has. Errata are ordinary reviewed PRs and must state that they are
   errata.
2. Successor-line specs: a new document line for a declared successor Core.
   The old spec is never rewritten to match new intentions; it remains the
   accurate description of the deployed system.

Replaceable-layer specs may be amended after deployment to add new module
specifications, but the Permanent interfaces they cite may not drift, and
existing module specs for deployed implementations become historical records
under the same errata-only rule.

## Normative Precedence And Single Sourcing

Amended by ADR 0010 (decision D3). Every Permanent definition — hash
preimage, interface, enum, event schema, canonical ordering — has exactly
one owning document section, its normative home. Every other document cites
the home instead of restating it; a checker-verified mirror table (such as
the domain-constants tables in the protocol v1 specification) is a mirror,
not a second home.

If two documents conflict, the owning home wins and the conflict is a
defect to repair, never an interpretation choice. ADRs are decision
records: the specs they amend are the homes, and ADR text that drifts from
its spec is corrected to cite the spec. One ADR is itself a designated
home, by owner decision (ADR 0010 decision D3.4; ADR 0011 decision R10):
[`docs/adr/0004-admin-governance.md`](adr/0004-admin-governance.md) owns
the governance surfaces its bracketed anchors name — the canonical
governance action identity and batch domains ([GOV-ACTION-ID],
[GOV-BATCH]), the window floors ([GOV-WINDOWS]), the material-action
holder classes ([GOV-MATERIAL]), the `ROLE_*` vocabulary ([GOV-ROLES]),
and the supported ERC-1271 wallet class ([GOV-1271-CLASS]) — and every
spec cites those sections instead of restating them. Event snippets
inside spec prose are illustrative; the machine-readable event catalog
and its golden tests are the authoritative event signatures.

## Requirement Anchors

Normative sections carry stable bracketed anchors on or directly beneath
their headings (for example `[MPA-COUNTERS]`), with binding requirements
numbered inside the section so gates, tests, reviews, and other documents
can cite a requirement precisely and durably. New and edited normative
sections must carry anchors; full backfill across the older documents is a
Review-entry condition tracked by the conformance matrix.

## Decision Citation Format

Decisions are cited uniformly as `(ADR <number> decision <id>)` — for
example `(ADR 0010 decision D2.3)` or `(ADR 0011 decision R6)`. ADR 0009
predates lettered ids and its decisions are plain numerals by
construction: `(ADR 0009 decision 21)` is the conformant shape for that
one record (ADR 0014 decision V9). No other citation shape is conformant;
mixed formats are defects.

## Amendment Process

Accepted ADRs under [`docs/adr/`](adr/README.md) are the only mechanism that
changes the normative content of a spec at `Review` or `Final` status.
Editorial improvements to `Draft` specs are ordinary PRs. An ADR that
amends a spec must name the affected documents and the permanence class of
every changed requirement; a change that touches a Permanent surface after
deployment is invalid by construction and must instead propose a successor
line or an explicitly scoped recovery path already permitted by the spec.

A spec that depends on a `Proposed` ADR cannot reach `Final` until that ADR
is `Accepted`.

## Normative Language

Stream specs use lowercase `must`, `should`, and `may` with RFC-2119-style
meaning:

1. `must` / `must not`: binding. Every `must` on a Permanent or Replaceable
   surface requires a named verification hook — a conformance gate, a test,
   a static check, or a checked release artifact.
2. `should` / `should not`: the default posture. Deviation requires a
   recorded rationale in the relevant ADR, manifest, or release evidence.
3. `may`: an explicitly allowed option. Absence of `may` is prohibition for
   Permanent surfaces; Permanent behavior is closed-world.

Hedged phrasing — "unless a later spec chooses otherwise," "subject to a
future decision," "recommended for now" — is forbidden in `Review` and
`Final` documents. While a decision is genuinely open, the spec states the
current normative default and marks the decision with an inline open-question
reference. A `Final` spec for a Permanent surface contains zero open
questions and zero hedges.

## Open Questions

A genuine open question is a decision that changes Permanent semantics, the
genesis module set, or an economic promise, and that cannot be resolved by
reading the code, the existing specs, or accepted ADRs. Style preferences,
implementation details behind stable interfaces, and already-decided defaults
are not open questions.

Convention:

1. Inline marker at the decision site: `**[OQ-<ns><n>]**` with one sentence
   of context, for example `**[OQ-X2]**`. Namespaces: `X` cross-cutting,
   `R` revenue/royalties, `M` mint policy/accounting, `MR` metadata
   router/renderer, `CM` collection metadata, `E` entropy coordinator,
   `EP` entropy providers.
2. Every marker has a matching entry in
   [`docs/spec-open-questions.md`](spec-open-questions.md) with the
   question, why it blocks finality, the options with a recommendation, and
   the decision owner.
3. Resolving an open question removes the inline marker in the same PR that
   records the decision (normally an ADR), and moves the register entry to a
   resolved section with a pointer to the decision record.

## Evidence Inside Specs

Spec documents state requirements. Proof that an implementation meets a
requirement lives in the conformance matrix, tests, and release artifacts.
Where a spec document carries point-in-time implementation measurements —
bytecode sizes, merged-slice summaries — those sections must be labeled
non-normative implementation evidence. Evidence going stale never weakens a
requirement; only the amendment process changes requirements.

## Specification Inventory

| Document | Primary layer | Status |
| --- | --- | --- |
| [`docs/stream-long-term-architecture.md`](stream-long-term-architecture.md) | Permanent (umbrella architecture) | Draft |
| [`docs/launch-v1-target-architecture.md`](launch-v1-target-architecture.md) | Permanent + genesis scope (protocol v1) | Draft |
| [`docs/revenue-splits-and-royalties.md`](revenue-splits-and-royalties.md) | Permanent interfaces + Replaceable genesis modules | Draft |
| [`docs/mint-policy-and-accounting.md`](mint-policy-and-accounting.md) | Permanent interfaces + Replaceable genesis modules | Draft |
| [`docs/metadata-router-and-renderer.md`](metadata-router-and-renderer.md) | Permanent interfaces + Replaceable genesis modules | Draft |
| [`docs/collection-metadata-contract.md`](collection-metadata-contract.md) | Permanent interfaces + Replaceable genesis modules | Draft |
| [`docs/stream-entropy-coordinator.md`](stream-entropy-coordinator.md) | Permanent interfaces + Replaceable genesis modules | Draft |
| [`docs/stream-entropy-providers.md`](stream-entropy-providers.md) | Replaceable (provider adapters) | Draft |
| [`docs/stream-artist-authority.md`](stream-artist-authority.md) | Permanent interfaces + Replaceable genesis modules (artist authority) | Draft |
| [`docs/stream-sales-and-auctions.md`](stream-sales-and-auctions.md) | Permanent interfaces + Replaceable genesis modules (sales and auctions) | Draft |
| [`docs/launch-conformance-matrix.md`](launch-conformance-matrix.md) | Deployment gate over all layers | Draft |
| [`docs/adr/`](adr/README.md) | Decision records / amendment mechanism | Per-ADR status |

Historical file names are retained where checker scripts, release manifests,
and checksum artifacts reference them; document titles and content are
authoritative for framing. Renames, if desired, are a separate mechanical
change coordinated with the release-artifact generators.

Every Markdown document under `docs/` outside the inventory above —
excluding ADRs under `docs/adr/` (decision records governed by this
policy), this policy itself, the open-question register, and index or
README files — is a baseline or operational record, not a specification,
and must carry this header block directly beneath its title (ADR 0012
decision T9):

```text
Baseline record — not a specification. This document describes as-built
or operational state; the normative target is the specification set
indexed in docs/spec-policy.md, and where this document conflicts with a
specification home, the specification wins.
```

Documents superseded by a specific spec name it in the header (for
example, `docs/royalty-policy.md` names
[`docs/revenue-splits-and-royalties.md`](revenue-splits-and-royalties.md)).
Baseline records map what exists today and must stay honest about every
divergence from the specs until the implementation conforms. A release
checker enforcing header presence across the non-inventory set is a
Review-entry condition tracked by the conformance matrix.
