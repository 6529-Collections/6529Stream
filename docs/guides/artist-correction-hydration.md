# Governed pending-binding correction hydration

The additive recovered operation60 profile retains the original class2 approval
of every governed proposal after a refused or withdrawn pending binding. The
first proposal, terminal records, independent final acceptance, original domains,
complete Identity nonce/signature history and seven-owner/Archive atomicity stay
unchanged. This is source implementation and authored-test coverage; native,
full-current and maximum-carrier acceptance are separate.

## Request and complete selection

Use the existing `hydrateRecoveredArtistAuthority(Request)` (or the existing
consent-witness variant), with the full original source journals, checkpoints,
logical replay preimages and nonce inventory. The caller supplies no new
correction list or authority assertion. The fixed collector detects the original
`binding_lifecycle.replay.correction_action` surface in authenticated owner0
provenance and reads `bindingCorrection(bindingHash)` for every generation.
Every source and destination owner must advertise `BINDING_CORRECTIONS = 2048`;
all seven envelopes require it together with `BINDING_GENERATIONS = 512`.
Previous named feature masks keep their original values; the new complete known
mask is 4095.

Owner0's semantic bytes are the canonical compiler encoding
`abi.encode(keccak256("6529STREAM_ARTIST_RECOVERED_BINDING_CORRECTIONS_V1"),
uint16(1), Bundle)`. The new Bundle contains the unchanged original
`Generations.Bundle` followed by one original `Correction` tuple per generation:
`(Approval approval, bytes32 recordHash)`. A fully empty row denotes actual
legacy ingress with no correction approval; the first row must be empty.
At least one nonempty original approval is required for this tag. Old generation
codecs remain unchanged and do not silently discard the new map.

## Historical authority and import

Each nonempty approval retains its entire previous binding, terminal cause and
bytes, proposal commitment, proposed Artist, original registration nonce,
class2 governance witness and approval time. Its exact original registry/Core/
Manager environment reproduces the original correction-record hash. Pending
causes1/2 must match the preceding refusal/withdrawal and empty dispute head.
The original correction scope, old/new values, distinct governance action and
consumed action replay cell are checked. Current governance roles are not
substituted for the historical approval. A reused same Artist has registration
nonce zero; a new Artist is a separate allocator/multiplicity composition.

All proposal/terminal and corrective-action aliases are reconciled against each
complete owner checkpoint, including original admission revision and rekeyed
successor cells. The source owner's current maps are read before payload
construction; the original final seven-owner source recheck remains in force.
The Binding owner imports its declared binding/history/terms/terminal/correction
maps only after the original operation60 guard and full codec validation. No new
native record, signature, nonce or mutation authority is created. A late Archive
failure rolls back every map and owner checkpoint with the Safe execution.

The internal bare generation Bundle passed to existing consent, attestation and
ratification validators is unchanged. Thus this pending-correction profile
composes with the already supported original modes1/2, grants, living recovery,
current accepted-generation records and repeated A-to-B-to-C imports.

## Following required compositions

This foundation retains first-era pending generations2..128 followed by one
accepted generation. Previously accepted generations, executed repudiations,
arbiter dispute histories and Platform continuation need their complete
Acceptance/Attribution typed maps and per-generation records, rather than an
invented empty history. Corrections after an import and multiple Artist/collection
combinations remain required next work. They currently fail before imports and
are not represented as full-v1 completion. Existing finite original carrier
limits remain unchanged; no size or calldata estimate proves runtime capacity.
