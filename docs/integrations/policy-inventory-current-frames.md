# Policy inventory current evidence frame

The COLLECTION policy V2 inventory keeps its existing public ABI, storage roots,
profiles, hashes and limits. `StreamCurrentAuthorityPolicyRenderCriticalCurrentV2`
now calls the fixed compiler-linked `StreamCurrentAuthorityPolicyInventoryEvidenceV2`
read worker so the full current-source decoder and seal orchestration compile in
separate frames. Deployment tooling must include this new library and its genuine
native links. It has no constructor arguments or independent governance role.

The read worker runs the complete existing `Guard.requireCurrent` before projecting
fourteen Context-derived evidence fields, including all eight original record
hashes. The host still performs stage and counter checks first, then the read,
origin sealing and definition checks. It reads the four Plan fields only after
those calls and retains the exact evidence hash preimage, storage writes and event.
The evidence's own hash remains zero inside its original hash preimage.

The projection reads independent returned memory and makes no calls or mutations.
It does not replace full source validation with a stored hash or cached result.
Original dependency-read budgets and production deployment limits remain unchanged.
The additional linked call frame still needs gas validation in the complete flow.

## Recorded validation boundary

A native Solidity 0.8.19, via-IR, optimizer-200, Paris capture localized the original
Yul failure to the current worker alone. The other eleven preservation products in
that bounded group compiled and fit; this says nothing about the remaining products
in the original failed shared capture. All failure outputs were retained.

The repaired current worker is 3,358 runtime bytes and 3,392 creation bytes. Its new
read worker is 6,496 runtime bytes and 6,528 creation bytes. The selected capture
preserves original source-qualified compiler settings, with no metadata hash or
CBOR. Original host ABI, selectors and library storage layout compare exactly.

Four focused cases in
[StreamCurrentAuthorityPolicyInventoryEvidence.t.sol](../../test/unit/preservation/StreamCurrentAuthorityPolicyInventoryEvidence.t.sol)
are authored and type-checked. They execute the actual read worker against an
explicit typed Guard boundary: complete literal evidence for intent and waiver,
two compiler-owned storage roots and canaries, original delegate caller, exact
currentness refusal and retry, malformed full-context refusal and restoration,
and fuzzed full-width values. The Guard is replaced only in these tests; they do
not establish actual source admission, completed inventory sealing or full current
Finality. The four cases have not yet been executed. No cold gas or complete-stack
acceptance follows from the size capture or type check.
