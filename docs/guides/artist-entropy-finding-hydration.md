# Importing Artist entropy-unavailability findings

`IStreamArtistEntropyFindingHydration.hydrateArtistAuthorityWithEntropyFindings`
selects `6529STREAM_ARTIST_ENTROPY_FINDING_HYDRATION_V1` under the existing
permissionless operation 60. It preserves the seven-owner mask `0x7f`, original
55/56/57 lineage admission, all-owner completion commitment and one atomic
Archive append. The five earlier hydration selectors keep their original
allowlists; none silently starts accepting op23 findings.

The request contains the original authority request plus `includePayout`,
`publications`, original economics inputs and original attestation inputs. This
composes the complete existing living, accepted generation-1 baseline, payout,
economics, readiness or publication profile with one or more entropy findings.
Economics requires payout; readiness requires economics; publication uses the
existing stricter kind-7/8 evidence checker. All original dependent receipts,
policy keys, signed terms, signatures, nonce prefixes, revocations, replay cells,
current heads and owner revisions remain mandatory. The new Identity allowlist
adds op23 to registration and authorization revocation; each finding must name
the same Artist and collection. No omitted other-collection finding can be
hidden behind a matching latest pointer.

The Identity export retains the original baseline state and a tagged bundle of
every op23 receipt in owner order: the unchanged FindingRecord, full entropy
Target and captured Intent, entropy runtime hash, admitted activity epoch and
governance witness commitment. It also exports the actual latest finding,
current activity epoch and cancellation flag. The independent consumer compares
the entire baseline Identity byte string with the original fixed-owner export,
every finding/admission with its original getter, and each original governance
action and finding replay key with the complete source checkpoint. The latest
must be the final admitted row. Its epoch equals the current epoch exactly when
the cancellation flag is true; otherwise current epoch is one greater. Earlier
rows and cancelled findings remain immutable history.

The source is the exact pinned first predecessor, sealed to this successor and
without its own imported predecessor. All seven source headers and both complete
history lanes are checked before writes, then source headers and suite bindings
are checked again before the Archive append. Historical governance is trusted
only as immutable fixed-owner admission under this complete source proof. An
individual receipt, ten-word hash, epoch or caller-supplied target cannot install
authority. The original inline Archive evidence bound still rejects an oversized
complete request before any owner write; this batch adds no paging bypass.

Both canonical preimages remain original. FindingRecord keeps the ten-word
record domain and the entropy evidence field continues to commit the complete
original Target, Intent and runtime under the predecessor Registry. The existing
Admission tuple is unchanged. A new mapping in the already separate entropy
namespace records that original Registry when the fixed Identity import succeeds.
`IStreamArtistEntropyFindingHydrationOwner.entropyUnavailabilityFindingOrigin`
returns that domain, the local Registry for an original entropy record, or zero
for an unknown or finality-profile record. No ordinary Identity storage root is
moved. Original finality admissions remain empty for entropy findings.

After hydration, the active successor verifier uses the original Registry only
to reconstruct the record and evidence manifest. It still requires the current
accepted binding, canonical latest finding, current Identity activity epoch,
current selected entropy Coordinator/runtime and exact current recovery intent.
The original notice is preserved. A cancelled finding never becomes usable by
migration, and successfully authenticated successor activity cancels an imported
live finding through the existing epoch. Fresh successor records and signatures
use the successor domain; no old signature is newly authorized by this profile.
The same entropy host retains its consumed-evidence map, provider/journal and
ordered recovery state. Hydration neither resets those guards nor permits a new
draw from a historical receipt. Finality and entropy finding readers remain
separate profiles.

The current fixed producer has default notice timing only (90 days, revision 1).
This profile requires the unchanged zero raw timing configuration; no timing
override or hidden timing-action history is discarded. Mixed artwork-finality
findings, multiple Artists/collections, transitioned or delegated authority,
repeated predecessor imports and histories outside the existing complete living
profiles remain unsupported and fail closed. They remain separate full-v1 import
obligations. No recovery eligibility, global freeze or steward transition changes
are part of this batch.

Nine authored cases in `StreamArtistEntropyFindingHydration.t.sol` use actual
two-registry Artist suites, seven owners, Archive, entropy workers and threshold
Safe calls. They cover original-domain live consumption, new successor activity,
cancelled source heads, replaced heads plus policy dependency, omitted and forged
rows, source/replay drift, strict old selector behavior, same-request non-repetition and refusal to retarget an eligible next request, and late Archive rollback
with identical Safe retry. The consumed-evidence mapping remains unchanged in source; the tests do not directly inspect that private cell. Core, governance, role resolution and upstream entropy
remain explicit typed boundaries. These are source-authored cases until the
integrator executes its consolidated native cohort; ABI checking and selected
product sizes do not establish runtime, gas, full capacity or deployment readiness.
