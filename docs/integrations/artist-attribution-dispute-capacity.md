# Joined Attribution capacity repair

This accepted source joins the original dispute/read extraction with the recovered
history and personhood source at `8972da42da396bdc3c0a2f7604d40f5db07946e5`.
It preserves the original Artist ABI, recursive storage and authority behavior.
**The Attribution runtime remains 793 bytes over the 24,576-byte limit.** This is
an incomplete capacity repair, not actual-suite deployment acceptance.

## Original mutation contract

The fixed `StreamArtistAttributionDisputeTransport` admits only the original seven
owner selectors for operations 44/45, 46, 47, 48, 49, 50 and 61. It forwards complete
original calldata, the original environment and the existing typed Attribution
store to unchanged mutation workers. The host keeps each original `_check` prefix.
No external argument carries a commit/replay plan or chooses a worker.

The host still consumes the first replay cell before the optional governance cell,
notes each cell through the original checkpoint producer, mixes a pair with the
original `keccak256(abi.encode(first, second))`, commits and appends any native
receipt. The fixed enum represents zero/one/two cells; current admitted branches
produce one or two. Resolution commits record zero, adds no native receipt and
returns the governance action ID. Repudiation veto/cancel/execute retain zero-record
and no-new-receipt behavior. Opening invalidates pending repudiation before its
original state mix. Every mutation returns normally after its commit tail.

Platform branches use `c.operationId` only after unchanged `_check(c, op)` proves
it equals the literal admitted operation. Their original replay, state, commit and
native ordering remain exact. Operation10 and ordinary platform branches have an
independent paired oracle, including operation mismatch before either branch.

## Ordinary read and import encodings

SupplementalReads closes fifteen original ordinary selectors, including the
original recovered export. It returns the complete original outer ABI, including
nested hydration bytes. PersonhoodReadEncoding closes the six existing personhood
selectors and invokes the original proof/summary/currentness implementations.
The host retains the exact self-only `personhoodResolution` guard. Original direct
STATIC13, C2PA credential and `personhoodAttestation` bodies remain unchanged.

The recovered Attribution import decoder accepts only the original operation60
selector and full `(ActionContext, Query, OwnerData, bytes32)` tuple. It calls the
original importer after the host's unchanged recovered tag/revision/nonce checks.
Original Owner guards, typed imports, late source rechecks and commit/Archive
composition remain in their existing implementations. No importer or proof is
reimplemented here; the C2PA/personhood note hook and recovered feature declaration
are unchanged. Later integrator-owned feature-bit additions must be merged as their
own exact function changes.

Three inherited Owner declarations (`recoveredAuthorityHydrationCapability`,
`recoveredHydrationImportedPrefix`, `recoveredHydrationOrigin`) use calldata instead
of memory return locations. Each unchanged body calls `_forwardRecoveredRead`, which
unconditionally performs assembly RETURN. This removes unused default allocation;
no calldata object is observed. All other Owner bodies and storage are unchanged.
No mutation uses raw return. Added ordinary fixed read frames have no established
cold-budget/runtime acceptance from these source checks.

## Paired measurements and authored checks

Solidity0.8.19, viaIR, optimizer200, Paris, no CBOR and no bytecode metadata hash:

| Product | Runtime bytes | Creation plus actual constructor bytes |
| --- | ---: | ---: |
| Original Attribution on paired original source | 34,560 | 36,417 |
| Accepted joined Attribution | 25,369 | 27,100 |
| DisputeTransport | 4,082 | 4,116 |
| SupplementalReads | 5,908 | 5,940 |
| PersonhoodReadEncoding | 4,089 | 4,121 |
| AttributionRecoveredImport | 2,408 | 2,442 |

The selected production capture is `size3`; ABI4 input is1,073 sources. Full
production ABI/storage comparison retains10,319 original entries and identical
recursive layouts. Final source proof binds later formatting to those production
tokens; the final ABI capture additionally includes the last two read oracles.
The old34,560, intermediate26,341/25,578 and unsuccessful25,552 measurements remain
retained. The unsuccessful private helper was removed; no limit was raised.

Thirteen owner-level authored tests cover independent original record/replay/root
preimages, ordered pairs, native occurrence counts, counter/withdrawal histories,
repudiation terminal/invalidation behavior, malformed calldata/check precedence,
late enclosing-frame rollback/identical retry, nested hydration bytes, personhood
outer ABI/self-only guard, platform operation branches, and recovered capability,
empty-prefix and current/unknown/wrong-suite origin reads. These use an actual
Attribution owner and original workers with an explicit typed Coordinator boundary.
They do not claim actual facade signatures, Safe execution, Archive admission or
current graph acceptance. Existing separate Safe/Archive and personhood test sources
are preserved and have not been rerun here. No native tests ran for this oversized
joined host.

Retained local evidence: `D:/repos/6529Stream/.tmp-attribution-joined-capacity`.
See `composition.json`, `compatibility.json`, `source-proof.json`, `products3.json`,
`abi-final` and `HANDOFF.json` for exact source and capture identities.

## Separately blocked proposal

A later proposal to move the original dispute replay-cell writes into the fixed
worker was rejected by automatic approval review before execution. It remains an
inert, separately hashed patch; it is not part of this source. The current host
retains its original replay mutation location. Existing denials and failing size
captures remain preserved. No other held proposal is applied by this batch.
