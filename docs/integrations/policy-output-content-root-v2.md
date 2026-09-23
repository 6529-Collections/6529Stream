# Explicit entropy policy output and canonical content roots

This additive profile computes complete current collection outputs for finalized
ASYNC tokens and explicit `DISABLED` or ASYNC `NOT_REQUIRED` tokens. It advances
the original Router `CONTENT_ROOT` family through original Artist operation 17.
It does not replace the original finalized-only V1 profile or complete snapshot,
reference-render, or finality publication.

## Produce and preserve the output evidence

`StreamPolicyContentCheckpointV2` pins a complete original STATIC selection, a
V2 entropy-policy source set, and terminal-render readiness. The selection must
cover a complete collection with frozen ONCHAIN configuration. `begin` binds its
full plan, original token inventory and full frozen-policy chain. `append` reads
the actual full `tokenJSON` and `tokenHTML`, checks the supplied HTML/image bytes,
and commits every token in original order. It uses the original six-field leaf
and tree formulas. Its distinct output chain also includes source facts, exact
policy readiness, and terminal-profile admission.

For terminal tokens the original coordinator at mint must supply the complete
explicit policy. Status 1 or 2 retains zero seed and `finalized=false`, and the
selected Renderer must have the separate admitted terminal STATIC profile.
Finalized rows retain status 5 and their original exact seed. A terminal status
alone does not prove that executable art is independent of entropy. INSTANT,
VIEW and non-ONCHAIN outputs are outside this finite profile.

Current reads repeat the complete source-set, selection and output checks. A
changed current JSON byte, admission, policy or source invalidates currentness;
old plans and rows remain readable. Historical compact metadata is never used
as a substitute for full current JSON.

`StreamPolicyOutputManifestV2` verifies a covered artifact containing the exact
complete row inventory. The canonical encoding is:

```solidity
abi.encode(
    schemaId, chainId, core, checkpoint, checkpointHash, checkpointStateHash,
    entropySourceSet, inventoryHash, policyChainHash, scope,
    contentRoot, outputRoot, tokenCount, rows
)
```

The four-word scope is inline. The head is 544 bytes, followed by the 32-byte
array count and exactly `tokenCount` rows of 640 bytes. Each row contains the
original six-field leaf, selection-row hash, source-facts hash, HTML hash,
ten-word entropy readiness and terminal-admission hash. Alternate offsets,
trailing bytes, omissions and permutations are refused. Actual Store chunks,
complete artifact coverage and current schema definitions are checked. This
manifest preserves hashes and source commitments; full JSON, HTML, image and
token-data artifact bytes remain separate preservation obligations.

## Admit the canonical Router root

The actual selected combined Finality provider advertises the additive
`IStreamPolicyOutputEvidenceBindingV2` capability (`0x6f83d46a`):

| Read | Selector | Result |
| --- | --- | --- |
| `policyOutputManifestV2()` | `0xc6cbbb31` | Immutable manifest address |
| `policyOutputManifestV2CodeHash()` | `0xa9486f5b` | Immutable runtime hash |

This binding supplements the same selected provider. It does not select another
provider or borrow the V1 manifest identity. The Router checks original Core,
Artist, Finality, Metadata, Schema and artifact-coverage relationships and pins.

The new Router entries use the original four-field `Publication` tuple:

| Entry | Selector |
| --- | --- |
| `previewPolicyContentRootPublication(Publication,address)` | `0x236f53e5` |
| `publishVerifiedPolicyContentRoot(Publication)` | `0x5e1fcd38` |
| `policyContentRootBinding(bytes32)` | `0xac9fa65d` |

The publisher needs the original active Metadata SNAPSHOT class 7 collection
grant or class 8 global grant. The preview binds the actual publisher, grant
revision, current Artist binding and generation, canonical predecessor,
verified manifest, full policy/output facts and exact V2 definition hashes.
It includes the original scoped-root aggregate when deriving the next family
state. Obtain the original operation-17 consent for that exact state.

Publication invokes the existing consent-consumption and evolution/freeze
checks, repeats preparation after authorization, and writes the original
canonical Router record/head. It then records the original content application.
A late failure rolls back the root, new binding, consent consumption and any Safe
nonce. V1 and V2 publications share canonical lineage and the original one-use
consent map.

The companion stores a per-record immutable 17-word binding in a closed
namespace. Original sequential Router storage is unchanged. The original
`contentRootRecord` tuple is unchanged; V2 record and state hashes have separate
`6529STREAM_POLICY_CONTENT_ROOT_{RECORD,STATE}_V2` domains and include the binding.
`tokenContentRoot` reports `STREAM_POLICY_TOKEN_CONTENT_LEAF_V2` for marked V2
heads, and retains the exact original schema branch for unmarked V1 heads.

Five exact ACTIVE RAW_BYTES definitions are required: the output manifest,
its ABI canonicalization, the V2 leaf interpretation, the V2 root record and its
ABI canonicalization. Their canonical bytes are exposed by
`StreamPolicyContentRootSchemasV2.document`.

## Validation boundary and remaining work

The producer suites exercise actual Router, Renderer, Metadata, Schema, Store,
selection, membership, readiness and artifact aggregation, with explicitly named
Core, Artist, governance, entropy, policy-source, admission and archival-receipt
boundaries. Root tests use actual Router state, governed writer grants and
threshold-two Safe execution; their verified-manifest and Finality inputs are
typed boundaries. These scopes are not a full-current deployment or a proof of
whole-program STATIC conformance.

The new checkpoint, manifest, schema library and root worker fit the selected
via-IR/200/Paris size profile. Router remains oversized and needs its separately
owned mechanical facade repair before deployment. A subsequent V2 snapshot must
join this actual canonical root and require original SNAPSHOT plus IDENTITY
authority. A subsequent V2 reference must retain exact source/output/environment
and capture evidence under CURATOR authority. Those publications, their locked
finality consumer and transaction-cap acceptance are not supplied by this batch.
