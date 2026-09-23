# Recovered accepted Artist generations

This additive operation-60 profile preserves an original living Artist and collection
whose earlier accepted binding was revoked through a governed operation-44 opening
and operation-46 resolution, followed by a fresh class2 operation-1 correction and an
independent operation-2 acceptance. It also accepts pending refused or withdrawn
generations interleaved with those accepted generations. It does not change the
recovery request, facade selector, original signing domains or seven-owner write
sequence.

The profile is selected from the complete authenticated acceptance journal, rather
than a caller-selected list. It requires feature bit `4096` in addition to the
existing generation and correction capabilities. Seven-owner headers, all original
native journals, full Identity signatures and both nonce indexes, replay aliases,
source roots and final source recheck remain mandatory. Imported receipts preserve
their original registry and owner environment; a correction first produced in a
successor uses that successor's actual era and original local revision sequence.
Every era boundary must have an accepted current collection.

## Canonical owner payloads

Version 1 adds three closed `abi.encode(tag, version, bundle)` payloads:

| Owner | Tag | Retained original state |
| --- | --- | --- |
| Binding, 0 | `6529STREAM_ARTIST_RECOVERED_ACCEPTED_BINDINGS_V1` | Every binding, collaborator terms, pending terminal and full class2 correction approval |
| Acceptance, 3 | `6529STREAM_ARTIST_RECOVERED_ACCEPTANCE_HISTORY_V1` | Every acceptance record and timestamp, ordered by generation |
| Attribution, 4 | `6529STREAM_ARTIST_RECOVERED_REVOKED_ATTRIBUTION_V1` | Current attribution plus every earlier governed opening, closed head and original revoking resolution |

The Binding bundle retains the existing nominal correction bundle. Acceptance
and Attribution use the typed structures in
[`StreamArtistRecoveredAcceptedGenerationTypes.sol`](../../smart-contracts/domains/artist/StreamArtistRecoveredAcceptedGenerationTypes.sol).
A decoder rejects an unknown tag/version, noncanonical bytes, incomplete history,
foreign original domain, inconsistent generation or unsupported record family.
Existing generation-only, pending-correction and single-acceptance codecs remain
unchanged for their supported histories.

All earlier acceptance maps are copied, including their original times and saved
Identity signature bundles. The importer does not reconstruct an acceptance
signer or nonce from a guessed preimage. It authenticates actual original source
maps and the complete journal and replay guards. Attribution imports use the
original dispute namespace and rebuild its immutable evidence-use map from the
complete accepted revocation records. All destination maps must be empty first.
The caller cannot choose a different namespace, writer or partial commit plan.

## Supported composition and remaining work

This batch supports one Artist and one collection, generations 2 through 128,
PRIMARY_ONLY collaborator terms, modes 1 and 2 and the previously supported
current-generation consent/grant histories. It retains all original Identity
recovery, nonce, signature and grant proof. It does not substitute a current grant
for a historic authorization.

Every formerly accepted binding in this profile must have exactly one original
governed opening followed by its class2 revoking resolution. Signed disputes,
counterstatements, reopened or multiply resolved disputes, repudiation,
Platform-correction lineages and operation-24 Attribution history are rejected
before import. Earlier-generation consent composition and multiple Artists or
collections remain required follow-up work. These refusals are explicit scope
bounds of this implementation, not a reduction of the full-v1 requirements.
The original carrier-size limit remains unchanged; 128 is a semantic bound and
is not evidence that every maximum-size bundle fits that carrier or a transaction.

## Authored verification

`StreamArtistRecoveredAcceptedGenerationsActual.t.sol` adds eight cases using
actual owners, Coordinator, Archive and threshold Safe:

- exact current and historical owner maps after import;
- original A-to-B import, a correction produced in B, then import into C;
- two revocations across three accepted generations and a repeated import;
- missing, foreign, malformed or stale source/cause/replay/capability refusals;
- late Archive failure with two counted append attempts, destination/Safe rollback
  and retry of the identical encoded operation-60 request.

The surrounding Core, governance action/roles, Metadata getters and archival
coverage facts are typed test boundaries. Document bytes use the actual Store.
These are not full-current-stack, actual delayed Executor or archival-coverage
acceptance tests. Source/type and selected deployment-size evidence are retained
separately; native runtime and cold gas acceptance remain pending.
