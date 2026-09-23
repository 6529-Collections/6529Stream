# Scoped sibling description and interview capacity

Seven scoped Description/Interview libraries exceeded the original 24,576-byte
runtime limit at `ea4cf6b0a2cfa7bba529284a3cfe46bb19b6604b`. This batch moves
only their private stage-check call to the matching fixed typed stage-guard
library shared with the Record/Token repair. Each guard invokes the exact
original `State.stage` with the same compiler-owned storage reference.

The current-authority families retain the original authority check, complete
current-source read, lineage check and stored context commitment, in that order.
Original decoders, document reads, original-row authentication, append behavior,
event bytes and phase changes remain in the original hosts. Fixed library
calls preserve the host and caller through delegation; no dispatch target is
caller-selected. Explicit error declarations retain each original inferred ABI.
All seven public ABIs, method identifiers and storage layouts match the original
native artifacts, and whole-file token inverses recover the original sources.

The four shared guard sources are dependency commit
`de313e0676af5529ed3fad37498eff44b66ec88c`. They are owned by the separate
Record/Token repair. This batch makes no changes to State, source readers,
authority readers, profile definitions or the shared guards.

## Selected native capacity

The one 280-source / eleven-product capture uses Solidity 0.8.19, viaIR,
optimizer 200, Paris, no CBOR and no bytecode metadata hash, with the original
settings. It completed in 231.27 seconds. All seven hosts and four shared
guards fit both the 24,576-byte runtime and 49,152-byte complete-initcode limits;
these libraries have no constructor arguments.

| Library | Original runtime | Repaired runtime | Repaired complete initcode |
| --- | ---: | ---: | ---: |
| `StreamCurrentAuthorityScopedPolicyRenderCriticalDescriptionStagesV2` | 34,732 | 24,005 | 24,040 |
| `StreamCurrentAuthorityScopedPolicyRenderCriticalInterviewStageV2` | 29,233 | 18,567 | 18,601 |
| `StreamCurrentAuthorityScopedPreservationPolicyRenderCriticalDescriptionStagesV1` | 34,828 | 23,969 | 24,004 |
| `StreamCurrentAuthorityScopedPreservationPolicyRenderCriticalInterviewStageV1` | 29,614 | 18,628 | 18,662 |
| `StreamCurrentAuthorityScopedRenderCriticalDescriptionStages` | 27,132 | 21,725 | 21,759 |
| `StreamScopedPreservationPolicyRenderCriticalDescriptionStagesV1` | 32,744 | 21,452 | 21,486 |
| `StreamScopedPreservationPolicyRenderCriticalInterviewStageV1` | 27,563 | 16,193 | 16,227 |

Shared guard runtimes are 7,554 bytes (scoped preservation V1), 9,458 bytes
(current-authority policy V2), 9,578 bytes (current-authority preservation V1),
and 6,147 bytes (current-authority scoped). The largest repaired host has
571 bytes of runtime headroom.

The saved input SHA256 is
`48144d4ac585f2d7798acf6ecd5715a19a9c22e7a53d363a4c3069f98f201890`;
the output SHA256 is
`a79e11fe05b4e5ee0acb23603a229ee609bd2583eb0e88ab6e01618273b8a98f`.
All 280 native source texts match the final 281-source test ABI input. The
capture retains genuine same-pass AST, metadata, full creation/runtime bytecode
and link references. There are 2,376 metadata-to-source hash joins. This selected
capacity result does not prove that all external linked dependencies fit or
that a complete graph has been deployed.

## Regression scope

`StreamScopedSiblingDescriptionInterview.t.sol` contains seven authored,
type-checked tests. They exercise the actual seven stage libraries and original
State roots, with explicitly mocked authority and complete current-source
responses. They cover decoder/stage/currentness precedence, full context and
lineage drift followed by restoration, and literal waiver item/link/segment
hashes across three families. A checked segment-counter overflow tests rollback
of tentative append writes followed by the identical successful retry. Bounded
fuzz varies the three waiver families and their literal commitments.

Successful waiver paths do not prove original published-document admission.
The restored description path reaches an explicitly mocked later rights read;
it is a guard-restoration control. The tests do not establish real Artist
migration, source gas capacity or a complete finality ceremony. Independent
source/oracle review is clear, but these seven Solidity bodies have not been
executed. Added linked frames can change execution gas and EIP-150 headroom;
no gas-parity claim or runtime, initcode or transaction cap change is made.
