# Recovered sanction and confirmed-attribution history

This additive operation-60 profile carries original signed operation 12 and
executed operation 13 through the existing seven-owner recovered Artist import.
It composes with the original accepted/corrected generations, signed dispute and
repudiation history, and required base policy/economics/sale consents. It supports
one recovered living Artist and one accepted collection, including current
accepted, confirmed, disputed, and revoked attribution states.

The requirements are the original [AA-STATE and AA-SANCTION rules](../stream-artist-authority.md)
and the original [operation-13 evidence and governance boundary](../adr/0039-canonical-finality-governance-and-evidence.md).
A recorded sanction does not by itself confirm attribution. Only the original
collection-scope executed-finality confirmation establishes state 3. A subsequent
dispute remains visible, and an original upheld resolution or withdrawal can
restore that exact confirmed state. A later accepted corrective generation does
not inherit confirmation from its predecessor.

## Capability and encoding

The request remains `hydrateRecoveredArtistAuthority(RH.Request)`. Every owner
advertises the explicit `SANCTION_HISTORY` bit, 16384, in addition to the earlier
capabilities. The actual complete source journal and confirmation replay surface
select it. Its headers also carry `DISPUTE_HISTORY`; a caller cannot request a
partial history or silently select an older codec.

Two additional version-1 tags have their own canonical `abi.encode` tuples:

- Owner 4: `6529STREAM_ARTIST_RECOVERED_SANCTION_ATTRIBUTION_V1`, containing the
  complete original dispute-history bundle and the sanction inventory.
- Owner 6: `6529STREAM_ARTIST_RECOVERED_SANCTION_CONSENT_V1`, containing the
  complete original base-consent bundle and that identical sanction inventory.

The inventory contains the authenticated catalogue for every original Archive,
every selected operation-12/13 descriptor, every full sanction record and its
original archive bytes/facts, and every original confirmation with distinct
Attribution and Consent revision points. Owner 0 and owner 3 retain the preceding
dispute-history binding and acceptance encodings. Other original requests,
selectors, signing domains, record hashes, storage fields and supported codec
bytes remain unchanged.

## Why the Archive is required

Original operation 13 has no native receipt in Attribution or Consent. It commits
once in each owner, consumes one Consent replay cell, and leaves both record-chain
tips unchanged. Its actor-dependent evidence ID and two independent local
revision points cannot be reconstructed from a Consent alias alone.

The collector therefore enumerates the original Archive's complete stored-payload
catalogue. It authenticates its immutable registry/Coordinator/environment,
schema, marker, binding, code identity and original configuration hash. Every row
participates in the catalogue commitment. Operation evidence additionally has
exact STOP-prefixed stored bytes, content hash, original evidence ID, metadata,
and canonical flat tuple encoding. The complete owner provenance supplies each
era's frozen cutoff; later writes to an old Archive are committed by the scan
without being imported past that cutoff.

For operation 13 the immutable payload retains the original binding, sanction,
Finality record, ordered components, execution and archival witnesses, raw-read
hash, and replay key. Both original owner transition roots are recomputed from
their own before/after snapshots and original actor. No cross-owner ordering or
current Finality decision substitutes for those original facts. The confirmation
must join exactly one earlier sanction in the Consent chronology. State-3
restoration must join a prior confirmation in the Attribution chronology.

Operation 12 retains its original authorization, exact signature bundle, consumed
principal nonce, observed digest, signed timestamp, authority class, generation,
association head, archive bytes and facts. The complete Identity source remains
responsible for original authority history and nonce inventories. The new join
does not make an expired or revoked authorization live or substitute a current
grant. Base and dispute delegation use totals remain independently reconciled.

## Atomic import and limits

All original owner guards remain before the fixed typed import workers. The
complete seven-owner source and Archive catalogue are checked before writes.
Each new owner codec checks its own authenticated clock and exact retained
evidence again. The original replay/nonce installation, semantic map writes,
source validation, seven-owner commit and operation-60 Archive append remain
atomic. Only this new profile adds the complete catalogue recheck immediately
after the existing post-write source validation. An error rolls back all owners,
semantic records, nonce state, Archive writes and the enclosing Safe transaction.

The collector is explicitly bounded to 16 original eras, 16,384 catalogue rows,
64 MiB of operation-evidence payload reads, 4,096 sanction/native rows and 128
confirmations. These are finite transport refusal boundaries, not new validity
limits on original lifetime history. Existing 24,575-byte evidence pages and
production deployment/gas limits remain unchanged. Repeated catalogue scans and
complete provenance have material cost; type checking or fitting bytecode does
not establish maximum-size or transaction-gas acceptance.

Platform declarations, native attestation 24, content/freeze/ratification
combinations and multi-Artist/multi-collection composition remain required
following work. They continue to fail before import rather than lose records.

## Evidence scope

Twelve authored actual-owner/Safe cases cover original signed sanctions,
unconfirmed versus confirmed state, different owner clocks, A-to-B-to-C import,
restoration and live disputes, corrective generations, preserved prior heads,
missing catalogue rows, signature drift, malformed points/generations,
capability/replay refusal and late Archive rollback with exactly two observed
append attempts across failure and identical-request retry. Eight additional pure
cases use independent flat-tuple and word-array oracles for the original encoding,
roots, component join and clocks.

The fixture uses actual Artist owners, Store, Archive and Safe. Core, governance
execution and documentary coverage remain inherited typed boundaries. The
original operation-13 producer is executed against explicitly prepared historical
Finality responses; this does not execute a Finality governance transaction.
Native execution, full-current integration, cold gas and maximum transport
capacity require separately frozen evidence.
