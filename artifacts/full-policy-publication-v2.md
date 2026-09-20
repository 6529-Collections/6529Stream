# Current full-policy publication source evidence

## Scope

This additive batch follows construction commit
`6f3a7d94b10cf5c73e122e756c804c4deb0c053b` and uses the actual fixed recipe/current
graph. It authors the complete call sequence through archive, original Artist
root consent, V2 snapshot/reference, inventory/bundle and original sanction and
Registry finalization. It does not claim that sequence currently succeeds.

The source is split into Base, Archive, Preparation, Publication, Reference,
Inventory and Finality test helpers, with three ordinary current tests and an
explicit captured-ceremony simulation entry point. The new private-manifest
reader host adds four tests and inherits 16 existing tests. Shared changes are
only default-preserving recipe/discovery/Registry gas hooks, a read-only retained
foundation-policy getter and a virtual phase-configuration test hook.

## Source review

- Archive helper: the 21 original methods and two archive state blocks were
  extracted mechanically from the actual original native fixture. Observer and
  retrieval evidence remains explicitly local fixture evidence.
- Independent preparation review verified original onboarding, real Manager
  handoff, delayed phase configuration through Executor, original consent,
  STATIC freeze and Core terminal ordering. A duplicate IDENTITY writer grant
  was found and repaired by retaining the already-enabled original grant.
- Independent Publication/Inventory review verified the literal V2 output and
  snapshot codecs, original operation17 and Archive join, all 31 definitions,
  all five per-token stages, segment/link counts, complete package occurrence
  counts and source-byte coverage preimages. Review did not execute contracts.
- Independent full reader review verified the actual `Reader.statement` private
  entropy path, low-cap regression sensitivity, exact negative errors and
  restoration/history semantics. Its typed publication/Core boundaries remain
  explicit; it is not a canonical finality acceptance test.
- Two source reviews confirmed the live-sanction/output dependency described
  below. No mock, disabled attribution or weakened checkpoint masks it.

## Compiler and local checks

The final combined ABI-only capture covered 1,869 Solidity sources and
reported zero errors. It includes the new complete helper chain/current host,
the new reader host and the unchanged actual construction host.

| Capture | SHA256 |
| --- | --- |
| ABI input | `66726640527a1ac5df754ad3ff13922a3cde2a1e4babf9604e86ce6d96aaa01c` |
| ABI output | `911cd119d580e53d45a268123c91787b6465e78dd26407d6ba33d26c3cce0d2c` |
| Twelve owned Solidity source SHA256 entries, LF-normalized JSON manifest | `ab3880a09d5d9718df4983c72af82246039242bbe6d85b78b0039d7744fc51f4` |

The ABI contains exactly three publication tests, twenty factory-reader tests
(four new plus sixteen inherited) and seventeen existing construction tests.
Source bytes are captured under the untracked local
`artifacts/art27-gap3/full-policy-publication-final` directory. The capture
includes the final canvas, grant repair, simulation wrappers and formatting.
ABI-only checking does not generate bytecode, measure sizes or execute any test.
All1,869 captured source byte strings match their exact staged Git blobs;
the comparison performs no line-ending or byte normalization on the Git side.

The twelve authored/modified Solidity files pass `forge fmt --check`.
`tools.docs.test_markdown_links` passes all17 tests; Markdown-link and changelog
gates pass. `codex-diff-check` passes using the Windows CRLF-aware policy.
An initial combined unittest command named nonexistent `tools.docs.test_changelog`;
the corrected documented Markdown test command and actual changelog gate pass.

## Explicit unresolved acceptance

1. **Sanction/output cycle:** real STATIC attribution displays the saved current
   sanction immediately. Recording finality's sanction changes full `tokenJSON`;
   the actual policy checkpoint rerenders and rejects the earlier committed
   bytes. The captured ceremony retains its unchanged-manifest assertion and is
   expected to expose this source dependency. A distinct, reviewed archival/live
   display boundary is required; no fixture-only ordering fixes it.
2. **Transaction envelope:** fixture-only output read cap20m imposes a strict
   parent threshold above20,417,460 before the nested call. This cannot run under
   16,777,216. Registry56m and Artist64m are also explicit fixture reservations,
   not accepted transaction settings. Full composed measurement and repair remain.
3. **Fresh observation:** the source export and reference helper require exact
   new full STATIC HTML/JSON and separately supplied browser/package observations.
   No fresh browser run or matching capture files are claimed by this batch.
4. **Native evidence:** normal runtime/initcode sizes, the three current cases,
   reader tests, full ceremony and combined release checks remain pending. The
   already-running frozen predecessor27 campaign is separate and unchanged;
   no competing native compiler is started for this batch.

See [the developer-facing ceremony guide](../docs/integrations/full-policy-publication-v2.md)
for the exact authority sequence, observation transport and configured budgets.
