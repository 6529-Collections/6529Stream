# Attribution terminal read encoding

This capacity change preserves all original Attribution interfaces and read
bytes. Fifteen external read functions already obtain the complete ABI result
from a fixed linked read worker and end in `_returnAttribution`, whose assembly
`RETURN` exits the external frame. Their declared struct or bytes return location
is now `calldata`. No default return object is observed or encoded, and no path
falls through that terminal return. This lets the compiler omit unused memory
allocations without changing the worker, stored record, external result, caller,
or selector.

The affected reads are `attestationAssociation`, `platformWorksAdmission`,
`platformWorksState`, `platformWorksClaimRecord`, `platformWorksContestRecord`,
`attributionClaimRecord`, `attestation`, `attestationRecord`, `statementBytes`,
`publicationAttestation`, `attributionDispute`, `attributionDisputeRecord`,
`attributionDisputeResolution`, `attributionRepudiationRecord`, and
`attributionRepudiationTerminal`. Solidity callers continue receiving ordinary
ABI-decoded memory values. The public scalar reads are unchanged.

Every function body, storage declaration, constructor, linked helper, authority
check, replay update, state update, original event and Archive composition is
unchanged. STATIC direct reads and normal-return C2PA/personhood reads are also
unchanged. This does not implement either held Owner-check or post-check
Attribution/consent mutation-tail proposal.

## Measured scope

One selected production capture compares integration source
`98fcd45f232c3fa0d3360adc871153ebb7c530bd` with this fifteen-declaration change.
The old source is compiled alongside the candidate with only its contract name
changed to distinguish the two products. All imports are pinned to the same
125-source closure. Compiler settings are Solidity 0.8.19, viaIR, optimizer 200,
Paris, no CBOR and no bytecode hash.

| Product | Runtime bytes | Creation object bytes | Actual initcode with five address arguments |
| --- | ---: | ---: | ---: |
| Original Attribution | 30,518 | 32,215 | 32,375 |
| Terminal-read candidate | 28,996 | 30,658 | 30,818 |

The candidate saves 1,522 runtime bytes and remains **4,420 bytes above the
24,576-byte deployment limit**. It is not deployable as a complete Artist owner.
All 99 ABI entries and the recursive storage layout match. An independent
inverse-diff check restores the original source byte-for-byte after line-ending
normalization by reverting only these fifteen return declarations.

The selected input hash is
`4fce9c580aa49d9b0ec470e4ac86c7b7fad37976f89971e2e408e75868c4f809`;
the output hash is
`a9e669aaa9c163621c334a8738f511e392d310ba73584b27a8ad888961d208f5`.
The retained local capture is `.tmp-attribution-read-capacity-capture` under the
main checkout. Its original compiler files remain unchanged. The result report
corrects an initial reporting-only assumption of six constructor arguments:
Attribution has five addresses (160 bytes); the common Owner's internal
constructor is not its external creation ABI.

## Authored regression boundary

`test/unit/artist/StreamArtistAttributionTerminalReads.t.sol` contains six cases:

- all fifteen empty original struct/bytes encodings;
- nonempty packed original attestation records and a typed Solidity caller;
- nested association tuples and unrelated-record isolation;
- short/long statement storage at 0, 1, 31, 32, 33, 64 and 65 bytes;
- the original namespaced dispute and repudiation terminal packed fields;
- malformed arguments refusing without changes to the owner snapshot.

The tests use the actual linked Attribution product with explicit test-only
storage seeding. Expected bytes come from the original declared types, separate
from the production read worker. They retain normal CREATE and both deployment
limits, and do not install oversized bytecode or enlarge the limit. Their
126-source ABI check passes. **They have not executed:** the remaining owner
overage blocks their setup. They do not establish record authorization, a full
seven-owner/Safe/Archive flow, cold read-budget acceptance, or launch capacity.

The next actual Artist smoke must first close the remaining deployment blocker.
Factory identity creation has no fixed governed gas cap: its deployment calls
use ordinary transaction gas, and current split deployment broadcasts each
Factory call separately. Measured 5.23m/4.96m identity extension call frames do
not justify changing a protocol gas floor or default. Aggregate fixture setup
gas is separate from each deployment transaction's budget.
