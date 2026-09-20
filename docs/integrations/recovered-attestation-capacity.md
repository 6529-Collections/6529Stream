# Recovered attestation worker capacity

This is a deployment-size repair of the existing recovered operation-24 profile
in [ADR 0047](../adr/0047-complete-artist-authority-hydration.md). It adds no
supported authority, subject, history, or signing profile.

`StreamArtistRecoveredAttestationHydration` retains its original `Bundle` and
`PersonhoodRow` definitions and all six public library declarations: `selected`,
`collect`, `encode`, `decode`, `validate`, and `importState`. The storage-reference
`importState` entry uses the original nominal library selector; the other five
functions and original errors retain their complete ABI tuples.

Two fixed workers carry existing read-only work:

- `StreamArtistRecoveredAttestationValidation` performs the original complete
  provenance, journal, era, row, publication, personhood-summary, and C2PA-chain
  checks in their original order.
- `StreamArtistRecoveredAttestationCollection` performs the original source
  getter sequence, calls that validator, then checks every original source head.
  It uses the original nominal bundle types and preserves delegate-host context.

The original codec still canonicalizes the complete envelope before import.
Its empty-target checks, attribution and record maps, statements, payload-store
writes, `Credentials.note`, personhood-summary comparisons, and final C2PA and
personhood head checks remain in the original import function, in the original
order. No storage root, original schema, hash preimage, replay cell, owner guard,
feature mask, public owner interface, or mutation path changes. The Prepared
attestation stage continues to use the same original types and methods.

The new workers are compiler-linked fixed targets. They accept no caller-chosen
execution plan, storage alias, or current-authority substitute. Historical records
continue to use their authenticated original Registry environments. Expired or
replaced documentary facts are not reauthorized during import.

## Evidence scope

The retained baseline source is byte-identical to the Content35 capture's worker:
34,120 runtime bytes. The first pure-validator extraction measured 27,758 runtime
bytes for the original worker and 15,964 for the validator; that intermediate
worker remained oversized. Both measurements and source snapshots are retained.
The second selected capture measures the split original worker at 23,421 runtime
bytes (23,457 creation) and the collection worker at 13,967 (13,999 creation).
The unchanged validator is 15,964 (15,996 creation), original Prepared stage 9,594
(9,626 creation), and original Attribution import dispatcher 2,314 (2,348 creation).
These fixed libraries take no constructor arguments. Both failed intermediate
measurements remain evidence for their exact sources.

The final source adds only the original `UnsupportedProfile()` declaration after
collection moved its last lexical use out of the original library. A separate
207-source ABI check confirms all seven original ABI entries and all six nominal
library selectors exactly; no owner/state source changes. That declaration-only
successor has not yet been independently measured as native bytecode. The
existing component suite is retained unchanged; runtime remains pending.

The existing 19-case `StreamArtistRecoveredAttestationHydrationTest` is the scoped
behavioral suite. It covers original mixed records, complete witnesses, exact
source heads, malformed envelopes, original-domain summaries, empty-target
admission, late failure, and identical retry. Its explicit Coordinator/signature
and synthetic repeated-era/summary boundaries remain unchanged. Neither these
component cases nor the size check establishes actual seven-owner/Safe operation
60, Prepared's complete call graph, maximum carrier capacity, or gas-budget
acceptance. Fixed worker calls add ABI transport and call-frame cost; the original
protocol gas and code-size limits remain unchanged.
