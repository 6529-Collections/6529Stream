# Recovered Payout evidence read capacity

The complete linked dependency build exposed an inherited capacity failure in
`StreamArtistRecoveredPayoutHydration`: its runtime was 24,822 bytes, 246 above
the EIP-170 limit. A selected native build against integrated source
`d56e13ffc8664b322a3a208f21d308918ed47072` reproduced that exact size. The focused
runtime campaign stopped at the original production size gate before any test
ran.

The private `_original` reader now forwards its original typed environment and
record hash to the fixed `StreamArtistRecoveredPayoutEvidenceReads` library.
The extracted body is unchanged. It checks the original Identity evidence
binding, actual evidence code and runtime hash, every original environment
getter, both retained owner code hashes, the requested record and the original
payout evidence hash in the same order. Library delegation retains the same
host context for its outgoing reads. Every other original collector, decoder,
validator and commitment remains unchanged; neither file writes state.

Solidity 0.8.19, optimizer 200, via-IR, Paris, without CBOR metadata measures the
recovered codec at **23,465 runtime / 23,498 creation bytes**, and the fixed
reader at **2,549 / 2,581**. The original codec ABI and storage output are exact.
These are selected production measurements, not an executed recovery ceremony.

Four focused test cases compare the fixed helper with the frozen original body
and independent literal return/error bytes. They cover the original delegate
host caller, zero/missing-code/mismatched evidence binding, all eight publisher
environment getters, both returned code pins, the retained record and its
evidence digest, including exact restoration. Their Evidence and Identity
boundary is explicitly typed; they do not claim actual Coordinator, Safe,
Archive or recovered authority admission.

The 98-source focused ABI check is clean. All four evidence cases passed with
the unchanged nine Payout read/write cases and four complete-decoder projection
cases: **17 passed, including two 256-run fuzz tests**. The frozen source is
`c05a2dc1ddd22b77bead6765f85d4223898f8e2d`. All 98 sources match Git, and all 32
artifacts plus 1,174 metadata source-hash joins match the genuine native output.
All 27 production products in the complete linked closure fit the original
runtime and creation limits. The tests reused those artifacts without compiler
invocation or artifact changes. Previous failed native captures remain separate
evidence; full recovery and current-stack acceptance remain outside this run.
