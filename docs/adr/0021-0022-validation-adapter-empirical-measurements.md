# ADR 0021/0022 validation-adapter empirical measurements

## Status and scope

This is reversible issue #670 prototype evidence, not an approval record.
It does not approve or freeze either candidate packet, accept either
implementation, authorize resolver or registry integration, establish a gas
reserve, authorize deployment, or change the protocol's pre-audit and
not-production-ready status.

The measurements bind:

| Item | Exact commit |
| --- | --- |
| Candidate-packet base | `8a045029185efc807edeac08d6f76b95c4387dd1` |
| Revenue prototype | `a32a56db6ecdcf5ff0bcce4d4a3d03fc40bc4d89` |
| Artist prototype | `1bd8c628cc04ce4977c6387b83b052688498187a` |

The machine-readable companion is
[empirical-adapter-measurements-v1.json](../../release-artifacts/issue-670-adapter-freeze/empirical-adapter-measurements-v1.json).
The candidate sources remain
[ADR 0021's packet](0021-revenue-resolver-validation-adapter-interface-packet.md)
and
[ADR 0022's packet](0022-artist-registry-validation-adapter-interface-packet.md).

## Decision summary

| Prototype | Strict runtime ceiling | Full-initcode ceiling | Semantic success |
| --- | --- | --- | --- |
| Revenue | **GO for this ceiling only:** 21,744 <= 22,576, margin 832 bytes | 24,531 <= 47,152, margin 22,621 bytes | Not an acceptance result; only focused O1/O2 success paths were exercised |
| Artist | **NO-GO:** 29,698 > 22,576 by 7,122 bytes and exceeds EIP-170 by 5,122 bytes | 30,005 <= 47,152, margin 17,147 bytes | **NO-GO:** all 57 entries terminate with `MeasurementOnlySemanticGap`; zero successful validation transcripts exist |

The revenue runtime **GO** says only that this prototype fits the packet's
strict runtime ceiling under the measured compiler settings. It is not a
packet, semantic, security, integration, or deployment GO.

## Reproduction and results

Measurements used Solidity 0.8.19, optimizer enabled with 200 runs, via-IR,
Paris EVM, no CBOR metadata, and no bytecode metadata hash, as configured by
the prototype build.

Authoritative size commands:

```powershell
forge build --via-ir --sizes --force smart-contracts/StreamRevenueResolverValidationAdapter.sol
forge build --via-ir --sizes --force smart-contracts/StreamArtistRegistryValidationAdapter.sol
```

The revenue command reported 21,744 runtime bytes and 23,891 creation-code
bytes. Its exact static constructor encoding is 20 words, or 640 bytes, so
full initcode is 24,531 bytes. The artist constructor has no arguments; its
forced command reported 29,698 runtime bytes and 30,005 full-initcode bytes.
The artist size command exits nonzero because the runtime also exceeds
EIP-170.

Focused behavior and gas commands:

```powershell
forge test --via-ir --match-path test/StreamRevenueResolverValidationAdapter.t.sol -vvv
forge test --via-ir --match-path test/StreamRevenueResolverValidationAdapter.t.sol --gas-report
forge test --via-ir --match-path test/StreamArtistRegistryValidationAdapter.t.sol -vv
```

Revenue focused tests passed 7/7. The gas report observed:

| Entry | Calls | Minimum | Average | Median | Maximum | Interpretation |
| --- | ---: | ---: | ---: | ---: | ---: | --- |
| O1 `computePrimaryAssignmentHashV1` | 8 | 362 | 13,484 | 4,451 | 48,605 | Mixed successful and intentionally rejected calls |
| O2 `validateSetPrimaryAssignmentV1` | 2 | 51,480 | 60,856 | 60,856 | One successful and one artist-malformed failure path |

These are local mock-path observations, not cold/warm production bounds or an
approved reserve. The same report measured a 24,531-byte deployment and
4,786,414 deployment gas.

Artist focused tests passed 8/8 only because terminal fail-closed behavior is
the expected prototype outcome. Gas consumed before the terminal semantic-gap
revert was 36,329 for one EOA proof, 49,455 for two, and 627,718 for 33.
Those numbers do not measure a successful transcript, ERC-1271 worst case,
outer registry reserve, or approved gas policy.

## Selector and interface facts

The revenue interface has 12 candidate selectors excluding inherited
`supportsInterface(bytes4)` and XORs to `0xb4165b1a`. The exact selectors are
`0xb3573c09`, `0x94bf44c4`, `0x371b62f3`, `0xaa3a3b3e`,
`0x6396e4ca`, `0xae8de4e2`, `0xa76cbd87`, `0x7e18b9d4`,
`0x02c57ac5`, `0x5e1f43f2`, `0x600e740d`, and `0x2664335b`.

The artist packet has 57 validation-entry selectors with entry XOR
`0x2efcc794`. Adding marker `0x24a325eb`, schema `0x41995c51`, and dependency
binding `0x371b62f3` produces full versioned interface ID `0x7cdddcdd`;
inherited `supportsInterface(bytes4)` remains excluded. The companion JSON
records every entry name and selector. On Foundry chain ID 31,337 the
prototype's constructor-derived dependency binding is
`0xf20c4ab74bab5090d4589e5c8abde377745276a5f7b5771d0c3ff9717759f324`.

## Preserved contradictions and gaps

### Revenue

1. Core, factory, and artist marker/schema values have no approved live probe
   surface. The prototype treats them as codehash-bound candidate facts; this
   does not resolve ADR 0021 decision R5.
2. O9's source assignment hash includes the source frozen bit, but the O9
   tuple carries no source frozen-bit field. The prototype accepts only an
   exact independently recomputed frozen or unfrozen form. That measurement
   accommodation is not a normative semantic choice.
3. O2 requires nonzero `nextPolicyHash`, while O4 requires zero
   `currentAssignmentPolicyHash` for a no-loosening freeze. Both occupy the
   primary assignment hash's policy slot, leaving that O2-to-O4 branch
   contradictory without a packet revision.
4. The exact 28-field O9 ABI requires via-IR. The prototype branch's default
   non-via-IR profile reports `Stack too deep`; integration needs an explicit
   compiler-profile decision outside this evidence change.
5. The focused suite is not the packet's complete hostile matrix, nine-entry
   golden-vector set, differential proof, resolver atomicity/reentrancy
   integration, or release evidence.

### Artist

1. Every one of the 57 entries deliberately reverts with
   `MeasurementOnlySemanticGap`; no 16-word success transcript exists.
2. Exact per-entry field masks and meanings, registry-write selectors,
   operation typehashes, state/replay digest meanings, record hashes, and
   result-word population remain unfrozen.
3. Refusal and delegation-revocation signed typehashes remain missing;
   `displayName`, deadline/`signedAt`, empty dynamic-value legality, and
   several bounded maxima remain unresolved.
4. ERC-1271 return-mode policy, reverse-composed gas reserves, outer registry
   post-call reserve, cold/warm adversarial measurements, and governed gas
   inputs remain unapproved.
5. Core burn-cutoff and finality-registry dependencies/call shapes remain
   unresolved, as do full registry mutation, replay, reentrancy, atomicity,
   selector-isolation, and golden-vector tests.
6. The runtime exceeds both the packet's strict ceiling and EIP-170. Removing
   checks or substituting stubs is not an acceptable way to claim success.

## Conclusion

The revenue prototype supplies a narrowly positive runtime-size measurement
and focused mechanical evidence. The artist prototype supplies negative
runtime and semantic measurements. Both packets remain Proposed, all blocking
review decisions remain subject to explicit independent disposition, and no
approval or irreversible protocol decision follows from this artifact.
