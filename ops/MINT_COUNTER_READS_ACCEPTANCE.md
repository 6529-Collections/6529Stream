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
source. This new batch's focused runtime, full-current/Safe/fuzz/gas acceptance
and release artifacts are pending. Source/ABI compilation does not establish
runtime correctness or production readiness.

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
