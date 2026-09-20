# ADR 0054: Explicit non-sanction preservation rendering

Status: Accepted implementation direction, 20 September 2026. Producer and
consumer integration, runtime acceptance and deployment remain in development.

## Problem

The actual full-policy publication recipe exposes a circular commitment. The
STATIC display reads the current original Artist sanction, sets the displayed
state to `artist_sanctioned` and includes its record hash and authority class.
Recording sanction therefore changes the full JSON retained by the earlier
output checkpoint. Its currentness check correctly rejects that change before
the finality ceremony can finish. Fixture ordering cannot repair the cycle.

[ADR 0039](0039-canonical-finality-governance-and-evidence.md#non-circular-sanction-and-archival-joins)
requires the sanction record and signature to be excluded from the reviewed
non-sanction inputs and independently archived after they exist.
[ADR 0041](0041-typed-finality-evidence-provider.md#stable-presentation-and-live-artist-authority)
also requires an explicit public presentation profile: hashing silently filtered
bytes while claiming to bind the full public presentation is not acceptable.
Live sanctions, disputes, revocations and other adverse provenance remain
required public information.

## Decision

Add a separately named, publicly callable preservation-render capability. Its
canonical JSON contains all original artwork, executable code, media, token
data, citation, C2PA and non-sanction Artist facts. Its only semantic projection
is to omit the sanction lookup and its derived displayed state, record hash and
authority class. The existing Artist reader already normalizes the confirmed
attribution state from 3 to 2 before inspecting exact covering sanctions; the
new path keeps that normalization and skips only that final sanction inspection.

Keep every existing live Renderer, Router and attribution method's byte rules.
The public live output continues to include sanctions and adverse provenance.
Do not remove fields from a returned JSON string, freeze a stale live object,
or turn a failed canonical attribution read into a successful archival record.
Both outputs remain explicitly identifiable and independently readable.

The first producer exposes `IStreamPreservationRendererV1`:

- `preservationProfile()` identifies these exact projection and encoding rules.
- `preservationBinding()` returns Core, Router, the actual selected live renderer
  and runtime hash, and the fixed preservation attribution companion and hash.
- `preservationTokenJSON(tokenId)` and `preservationTokenHTML(tokenId)` derive
  their request and selected configuration from the actual contracts. A caller's
  arbitrary request, target or JSON is never authoritative input.

The first capability covers the selected MARKETPLACE token rendering used by
COLLECTION, TOKEN, RELEASE and SEASON. Burned-token preservation must use the
authenticated retained identity and distinguish it from normal ERC-721 serving.
VIEW requires its own exact adopted-view binding and is not implied by the
first producer. A separate companion avoids adding code to the nearly full live
attribution host.

## Commitment and compatibility boundaries

New output, root, snapshot, reference, inventory and provider profiles must bind
the preservation producer, exact runtime, profile, original live renderer and
complete admitted source/read roster. Their schemas and public documentation
must say that they commit this preservation output, not the full live
`tokenURI` JSON. Original locked deployments, schemas, signing domains,
consumed-content books and historical output hashes keep their meanings.

This is an additive pre-genesis profile, not a way to upgrade a previously locked
full-output checkpoint in place. Existing full-output checkpoints still become
stale when their live bytes change. New profile selection uses the existing
governed admission and Artist content-authorization rules. A capability claim or
constructor pin does not substitute for the actual STATIC source analysis,
golden vectors or authorization.

Sanction and signature bytes remain separately validated and archived against
the exact reviewed subject. Finalization and confirmation must not change that
subject. Later legitimate changes to identity, claims, corrections, attestation,
C2PA, artwork, entropy, configuration or membership retain their existing effect
on currentness; immutable historical receipts remain historical receipts.

The source trace establishes the narrow display distinction: sanction writes
do not alter the other displayed fields; original finalization stores its own
records and components; Core closure/freeze/burn policy are prerequisites; and
operation13's state change is already normalized by the reader. Whole-provider
and component commitment parity still requires composed regression execution.

## Validation and remaining work

The producer must prove exact live-output compatibility and preservation-output
parity across actual sanction, original finalization and confirmation. Negative
cases must cover altered artwork and other live facts, replaced targets/runtime,
wrong configuration, incomplete source evidence and failed reads. Preserve full
script, token-data, citation, entropy and C2PA bytes, with fuzz and boundary cases.

The consumer recipe must demonstrate the original sanction, its archive join,
finalization, confirmation and subsequent currentness through the actual graph.
Keep the existing failing full-output recipe as evidence of the original cycle.
Selected bytecode sizes or typed fixtures do not establish that full ceremony.

This decision does not solve large-scope gas or staged freshness. The complete
current output must still be observed unless a producer-owned commitment covers
every mutation and time-dependent input. A checkpoint-local epoch, sampled rows,
larger fixture gas limit or part/index format alone cannot establish that fact.
The original transaction limits and full-membership requirement remain in force.
