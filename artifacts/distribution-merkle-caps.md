# Operator distribution Merkle recipient allowances

Implementation base: `d2b65a3f7ff84952f7c3105ba8901d3f422a40e5`.
This is a source handoff, not native runtime or release acceptance.

## Requirement and implementation

[SSA-AIRDROP rule 4](../docs/stream-sales-and-auctions.md#airdrops-and-operator-distributions)
requires the offline-verifiable recipient allowance option. The distributor
previously accepted only STATIC cap mode even though Manager and Ledger already
implement MERKLE_STATIC proofs and effective leaf caps.

The distributor now accepts STATIC or MERKLE_STATIC for its required RECIPIENT
counter. It still requires enabled counters, unit static increments, an exact
Program cap ceiling and its original STATIC PHASE/CONSTANT supply counter.
Manager resolves the original `MintBatch.resolverData` proofs against actual
beneficiaries and aggregates projected duplicate consumption; this batch changes
no Manager, Ledger, proof, gate, payment, delivery or Prepared implementation.

[MPA-MERKLE rule 7](../docs/mint-policy-and-accounting.md#merkle-allowlist-cap-mode)
also requires the full list content hash in phase configuration. Merely placing
that hash in `Definition.metadataHash` would bind Manager policy, but would not
bind the original distribution Program/phase config hash. The integrator chose
an additive commitment profile instead of weakening that requirement:

```text
keccak256(abi.encode(
    keccak256("6529STREAM_OPERATOR_DISTRIBUTION_MERKLE_CONFIG_V1"),
    originalProgramHash,
    recipientCounterConfigHash,
    selectedDefinition.metadataHash
))
```

`merkleProgramHash(collectionId, phaseId, program, recipientCounterConfigHash)`
reads the actual Manager's Ledger and its manager-selected definition. It
requires a defined RECIPIENT PHASE/COLLECTION definition with nonzero cap root
and publication hash. Registration can precede this getter, which can precede
phase configuration; there is no circular setup requirement. A definition
already latched as absent for this Manager remains absent.

Admission derives the same hash from the phase's current recipient counter.
The existing royalty application-config wrapper composes this selected hash.
The caller cannot supply an alternate admission definition or publication hash.
The operator must still publish the file whose content hash is committed.

## Compatibility and validation boundary

- Original Program fields, V1 program/slice/authorization preimages and original
  `IStreamOperatorDistribution` methods remain unchanged. The new getter uses a
  separate `IStreamOperatorDistributionMerkle` interface, advertised in addition
  to the original interface. No persistent storage fields are added.
- STATIC admission keeps its original hashes and supported recipient scopes.
  Merkle admission requires the additive hash; using the V1 hash alone fails.
- No held ERC20 Burn native-fee extension, shared Artist authority, generation,
  Prepared production, full-graph fixture or generated release artifact changes
  are included.
- Independent production source review found no blocker. A mechanical
  comment/whitespace-insensitive comparison preserves the original interface
  declarations and complete `programHash`, `sliceHash`, `sliceAuthorization`,
  `distribute`, `claimNft` and `claimNftFor` functions.
- The focused regression host uses actual Manager/Ledger and its existing typed
  Core, Artist, registry, entropy and delegation boundaries. It is not an
  actual-current Core/Artist acceptance host.

## Focused source and checks

The host contains 45 test methods: all 27 original bodies are unchanged after
line-ending normalization, with 18 new Merkle cases. Independent source review
checked the positive preflight and negative failure oracles. New cases cover:

- Different wallet caps, duplicate projected consumption and PHASE/COLLECTION
  recipient scopes while supply remains PHASE.
- Missing, malformed, reordered and wrong-phase proofs; valid-membership zero
  and above-ceiling leaves; two configured Merkle counter groups in exact order.
- Cross-slice allowance/replay, DIRECT receiver failure and late reveal-funding
  failure with identical-request retry; failed isolated delivery and beneficiary
  claim redirection; the original one-token prepared preview path.
- Literal additive hash preimage and separate interface advertisement; V1-only
  rejection; same root with a different publication hash under the current
  Manager policy; unknown, unpublished, wrong-key and unsupported definitions;
  the Manager's retained first-use absent-definition interpretation.

The original distribution interface ID is `0xe1ceb09a`. The additive getter
selector and interface ID are `0x9f2d3027`, with canonical ABI signature:

```text
merkleProgramHash(uint256,bytes32,(address,bytes32,bytes32,bytes32,uint64,uint64,uint8,bool),bytes32)
```

The final ABI/type-only capture covers 171 original import-closure sources with
zero errors and exposes all 45 test methods. It uses Solidity 0.8.19, optimizer
200, via-IR, Paris and the repository's metadata settings. It requests ABI
output only; it is not code-generation, deployment-size or execution evidence.
The retained local capture is `artifacts/art27-gap3/distribution-merkle-caps-v2`.

| Evidence | SHA-256 |
| --- | --- |
| ABI input | `ae36c67ebadaf1623e070fb6a3126467442268fe23a53bdacdba6e33c6090400` |
| ABI output | `550ed0d15f34a2f45b8188b2c830c8df8389fbe6db7b1023ab890334fd48d26a` |
| Final test source bytes | `80ca504b783848706da2b92ebda068ab101e78b8208f6a5e56ab7d4bcc3b0af8` |

Scoped Solidity formatting and Windows whitespace checks pass. All 17 Markdown
link checker tests, the Markdown link checker and the changelog gate pass.

Native code generation and execution, current-stack composition, gas/size
measurements, complete fuzz/invariants, CI and final release artifacts remain
with the integrator's combined validation. Earlier STATIC distribution results
do not validate this new Merkle profile.
