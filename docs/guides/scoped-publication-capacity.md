# Scoped publication capacity

The TOKEN/RELEASE/SEASON preservation Snapshot and Reference publication
contracts share fixed implementations across their V1 and V2 families. Their
public selectors, complete error ABIs, storage layouts, immutable declarations,
constructor inputs and registered gas parameters remain unchanged.

Snapshot delegates complete definition validation, current-source collection,
source hashing and canonical payload encoding to
`StreamScopedPreservationSnapshotAssemblyV1`. The host resolves its governed
dependencies at the original point. The worker retains every source field and
the original publisher address/caller context; it returns the source hash and
full payload. The host still checks the expected hash, retains the bytes and
writes all receipts, history and IDs under its existing guard.

Reference delegates its historical exact-scope check to the existing
`StreamScopedPreservationReferenceRecordsHistoryV1`. A zero head still returns
before reading storage. A nonzero head reads and authenticates every retained
chunk, decodes the complete original publication and checks canonical encoding
before comparing the full scope tuple. No current-authority or family predicate
is substituted for this historical comparison.

## Focused evidence

The first exact-source Solidity 0.8.19/via-IR/optimizer-200/Paris capture preserves
the original no-CBOR/no-bytecode-hash settings and measures:

| Product | Runtime bytes | Bare initialization bytes |
| --- | ---: | ---: |
| Snapshot V1 | 23,258 | 27,075 |
| Snapshot V2 | 23,101 | 26,918 |
| Snapshot assembly library | 15,945 | 15,977 |
| Reference V1 | 23,521 | 28,050 |
| Reference V2 | 23,521 | 28,050 |
| Reference history library | 5,707 | 5,739 |

All six fit the 24,576-byte runtime limit. The first capture input SHA-256 is
`12107504aeb76262753cfaff0b7d1fece461421ecc1e43d473efa203f0c1f6dd`;
subsequent formatting preserves executable tokens. Public wrapper ABIs,
selectors and recursive storage layouts match the baseline. The History
library adds its typed exact-scope method without changing prior methods.

Six focused Foundry tests pass against genuine Store and History code,
including a 256-input fuzz property. They cover TOKEN/RELEASE/SEASON tuples,
all four scope fields, zero-head no-read behavior, noncanonical trailing bytes,
corrupted-chunk error precedence and identical retry after restoration. The
fixture supplies stored publication data; it does not claim publication
authority or a complete current-stack ceremony.

The existing Snapshot tests retain their independent literal source/payload
preimages, full publication/receipt events, original expected source hash,
currentness, late Store failure and Safe retry oracles. Their execution on this
new source remains a separate integration obligation. Additional fixed library
calls change gas use; size and focused worker tests do not establish full-flow
gas, actual full initialization, release readiness or a testnet deployment.
