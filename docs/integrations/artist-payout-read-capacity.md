# Payout structured-read encoding

The joined Payout owner retains its original public ABI and storage while moving
the encoding of six structured reads into `StreamArtistPayoutReadEncoding`.
The helper receives the owner's five declared typed storage references and the
original calldata. It accepts only the six original selectors. It has no writer,
arbitrary target, raw storage offset, or capability-admission branch.

| Original read | Returned words |
| --- | ---: |
| `designationRecord` | 3 |
| `payoutDesignationProvisionalAssociation` | 2 |
| `payoutCandidates` | 6 |
| `payoutRewindInventoryV3` | 6 |
| `payoutRecoveryRecordStatusV3` | 5 |
| `payoutRecoveryContinuationV3` | 14 |

Each host entry ends in the original-result bytes returned by the fixed helper.
Its `calldata` return annotation avoids allocating an unused compiler default;
the function never reaches Solidity's ordinary return encoder. The helper still
reads a candidate's association by that candidate's record hash and invokes the
original `Recovery.inventory` for the inventory tuple. Empty mappings preserve
their exact zero-word results. Scalar reads remain on the owner.

All authorization, replay writes, recovery admission, checkpoint order, owner
commits, native journals, events and recovered import bodies remain unchanged.
The Burn-owned recovered-delegation feature mask is preserved. Existing external
callers retain all 56 ABI entries; the complete 11-root recursive storage layout
is unchanged. The 19 original functions outside the six read entries remain
byte-exact against integration `ccbaf41f`.

Solidity 0.8.19 with via IR, optimizer 200, Paris and no CBOR measures the exact
joined baseline at 25,473 runtime bytes and the new owner at 24,311. Creation
bytecode changes from 26,729 to 25,567 bytes. The new helper is 1,662 runtime /
1,694 creation bytes. These are source-specific measurements; the older
`70c0d9c3` 25,800-byte Payout result is separate evidence. New deployment source
and linked-library identities must be captured together.

Nine focused tests passed, including 256 fuzz cases. They cover literal outer return
words, all populated typed recovery fields, missing records, candidate association
selection, malformed calldata, caller independence, actual original Payout18
writes, authorization/stale-snapshot refusal and atomic rollback with exact retry.
The actual owner is deployed with its original constructor. The test caller is
an explicit typed Coordinator; the complete recovered-state probe is synthetic.
These tests do not establish signature/Safe/Archive ingress, recovery35 execution,
full hydration, or current-stack acceptance.

The first unfiltered 95-source native build failed in Yul code generation before
tests. The selected production pair and both new test products compile separately.
An independently selected transitive dependency reproduced the compiler failure;
the separate [recovered apply projection](artist-recovered-apply-projection.md)
repairs only that pure decoding transport. Frozen selective-artifact runs preserve
source bytes and every non-selection compiler setting, discover the complete
linked-library closure, and forward genuine compiler output without modification.
The first complete linked build then stopped at its strict size gate on the
inherited recovered-Payout codec. The separate
[evidence read extraction](artist-recovered-payout-evidence-read.md) repairs that
dependency without changing its original validation body.

The frozen `c05a2dc1ddd22b77bead6765f85d4223898f8e2d` campaign passed all 17
cases: these nine, four decoder-projection cases and four evidence-read cases,
including two 256-run fuzz tests. Its 98 source files match Git; all 32 artifacts
and 1,174 metadata source-hash joins match the genuine final native output. All
27 production products in the linked closure fit the original size limits.
The cached test run invoked no compiler and changed no artifacts.

On that later integrated source, which also includes the independently delivered
pure replay-key encoder, Payout is 23,520 runtime / 24,671 creation bytes. This
does not replace the earlier isolated 24,311 measurement or attribute all later
savings to the six-read extraction. The complete linked build took 131.17 seconds;
the cached tests took 1.40 seconds. No held replay-write relocation or authority
change is included.
