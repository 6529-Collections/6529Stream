# Mint counter Read API batch

## Scope

This batch follows immutable `canMint` commit `b7378eeb` and its focused native
evidence commit `65ed8db6`. It implements the original `rawCounterValue`,
`counterValue`, `remainingForCounter` and `resolveCounter` surfaces, plus a
proof-aware combined read. The original 11-field `CounterKeyContext` and
four-field `CounterResolution` are retained in `IStreamMintCounterReads`.
Its additive ERC165 capability is `0xe96c52f4`.

The [caller guide](../docs/integrations/mint-counter-reads.md) documents scope,
counter units, raw-key semantics, context indices and proof encoding. STATIC
remaining saturates at zero; legacy NONE reports uint64 storage headroom.
Proofless MERKLE_STATIC remaining explicitly rejects because a subject key
cannot identify one validated allocation. The combined context read resolves
the exact supplied leaf and returns resolution, current value and remaining
units atomically. Dynamic resolver profiles remain excluded.

Execution and reads share the original single-row consumption body and existing
scope/proof helpers. The original batch preparation still performs all strict
aggregate checks. Actual Manager identity, beneficiary rather than custody,
explicit executor/authorizer, token indices and existing resolution preimages
remain exact. No Core, storage, royalty behavior, mint limits or production caps
change. Counter resolution alone does not authenticate mint eligibility.

The five new typed view facades and four retained accounting reads share a
private return helper. It captures
original Manager calldata before invoking the fixed linked worker. Only the
nine declared selectors dispatch; standard ABI decoding is used. Exact static
32/64/128/192-byte results bypass duplicate facade decoding/encoding. The original
three replay reads preserve Manager scope and the grace read preserves its
hash/expiry pair. No generic
fallback, user-selected target or storage alias is introduced.

## Focused recipes and evidence boundary

The 15 actual Manager/Ledger/Registry tests use explicitly typed Core, Artist and
governance boundaries. They compare 18 supported profiles against `canMint`
and literal original hash preimages: 12 static scope/key combinations, two
CONTEXT scopes and four payer/beneficiary Merkle profiles. Further cases cover
real scoped consumption, custody separation, explicit executor, increment units,
shared-key cap saturation, two valid leaf caps on one subject, uint64 bounds,
proof/domain/index failures, canonical encoding and no authority/write effects.
Direct staticcalls check exact 32/64/128/192-byte return encodings, malformed
context rejection, 30,000-gas capability/replay/grace reads, caller-independent
scope and inclusive grace expiry after a real mint and policy rotation.

`mint-counter-reads-combined-abi-final-1` checks 194 exact sources and 36 cases:
15 counter reads, 15 preview cases and six original configuration codec cases.
It has zero compiler errors. `mint-counter-reads-compatibility-1` retains all
194 Manager and 196 fallback ABI entries, adding five functions and three
explicit errors. All 19 recursively normalized storage entries are unchanged.

The native preview21 result remains evidence only for its frozen `b7378eeb`
source. The frozen `3cbc67bc` counter-read capture executes all 36 cases: 35
pass and the replay/grace deadline assertion fails. All 13 budgeted read calls
succeed within 30,000 gas; the final grace call returns the correct 64-byte
tuple and stored deadline 1100 in 6,630 gas. Independent disassembly of the
exact test artifact shows `TIMESTAMP + 100` is recomputed after `vm.warp(1100)`,
making the test expect 1200. The test now uses literal 1100 from its unchanged
`setUp` time of 1000, preserving inclusive 1100, expired 1101 and every other
assertion. No production source or gas allowance changes.

The original negative capture `mint-counter-reads-native-3cbc67bc-1` is retained:
412.441 seconds, exit one, native JSON SHA-256
`8c7ac52e03907a243ed28663bee562a32ddbfcf374e36f57dc7325a1324c58fb`.
Independent checks bind all 194 sources, 221 artifact metadata records and
4,470 source Keccaks to their cache-selected compiler output. All 90 captured
production runtime artifacts fit; fallback remains outside this native closure.
The native Preview emission is 11,580/11,612 bytes, distinct from the selected
emission below. A separate copied two-case diagnostic on unchanged `b7378eeb`
passes both the original recipe and literal-deadline control; its different
test compilation context does not reproduce the original optimizer behavior.
The decisive evidence is the original failing artifact's generated code.

The corrected full 36-case native retry on immutable `82f41c88` passes all 36
cases, exit zero in 305.890 seconds. Capture
`mint-counter-reads-native-82f41c88-1` retains 194 exact sources, the original
compiler/test profile, ordinary cache invalidation and separate production
size checks. Native JSON SHA-256 is
`bfaebb1c96bec8b4fcef199ebc70f754562b740f062195a66386c7d04813a930`;
the log is empty. All 15 counter-read, 15 preview and six configuration-codec
cases pass, including the unchanged 30,000-gas replay/grace calls and both
deadline boundaries. Independent verification matches all 194 Git/captured
sources and 221 artifacts to their metadata and cache-selected compiler outputs,
including 4,470 source Keccaks and 941 link slots. All 90 production products
fit; six outside-closure cached artifacts are excluded. Full-current/Safe/fuzz/gas acceptance and release artifacts
remain pending; this focused result does not establish production readiness.

## Selected size evidence

All captures under ignored `artifacts/native-assembly/counter-scopes/` are
immutable. `mint-counter-reads-size-4` compiles 155 exact sources and nine
products with Solidity 0.8.19, via IR, optimizer 200, Paris and no CBOR/hash
metadata. It completes in 37.284 seconds with zero errors and no runtime/init
cap violations. Earlier oversized captures are retained.

Input SHA-256: `4c9a503b09967a65a664ab2f88dc63ed57c94a9918cdaaec9b4f4c6329e61f84`.
Output SHA-256: `ca00d03de1281e1ac4266d4152d4f6bfae373721300493e077bfceb4148a2a6b`.

| Product | Runtime bytes | Init bytes |
| --- | ---: | ---: |
| Manager | 24,211 | 27,314 |
| Fallback Manager | 24,328 | 27,431 |
| Counter reads | 5,614 | 5,646 |
| Counter preparation | 7,599 | 7,631 |
| Operation identity | 9,811 | 9,843 |
| Manager views | 4,838 | 4,870 |
| Manager policy | 3,555 | 3,589 |
| Manager transcript | 5,071 | 5,103 |
| Mint preview | 11,564 | 11,596 |
