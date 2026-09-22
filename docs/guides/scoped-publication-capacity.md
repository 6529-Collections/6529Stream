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

The final committed-source Solidity 0.8.19/via-IR/optimizer-200/Paris capture preserves
the original no-CBOR/no-bytecode-hash settings and measures:

| Product | Runtime bytes | Full initialization bytes |
| --- | ---: | ---: |
| Snapshot V1 | 23,258 | 28,707 |
| Snapshot V2 | 23,101 | 28,550 |
| Snapshot assembly library | 15,945 | 15,977 |
| Reference V1 | 23,521 | 29,714 |
| Reference V2 | 23,521 | 29,714 |
| Reference history library | 5,707 | 5,739 |

All six fit the 24,576-byte runtime and 49,152-byte full initialization limits.
The exact `5104c901` capture input SHA-256 is
`680ab0d9a673c7ce221d1e028f019194c9ecc5413bca23db4a1f8bcad18c8a85`.
Snapshot constructor arguments add 1,632 bytes; Reference arguments add 1,664,
using the original fixed gas-parameter names. Other fields are static-width;
encoding their length does not establish valid deployment arguments or CREATE. Public wrapper ABIs,
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
