# Entropy policy evidence

`StreamEntropyCoordinator.entropyPolicyFrozen(collectionId)` exposes the named
coordinator's actual collection policy through `IStreamEntropyFinalityPolicy`.
`StreamFinalityEntropyEvidenceProvider` joins that read to fixed Core, Metadata
and scope-membership sources. `StreamFinalityServingHostAdapter` supplies the
ordinary finality component identity for `ENTROPY_COORDINATOR`.

This implements evidence for the current single-provider, epoch-1 coordinator.
It does not complete the specification's additional entropy modes, security
classes, fresh recovery, provider migration or explicit freeze before public mint.

## Policy and request state

The policy read returns `(frozen, policyManifestHash, provider, providerEpoch,
collectionSaltCommitment)`. Missing provider or reveal declarations return five
zero values. A fully configured but unlocked policy returns its hash with
`frozen=false`. The first actual token or scope registration locks both policy
declarations without changing their hash.

The commitment covers the original provider address, runtime hash, configuration
hash, epoch, collection salt, public-request declaration, declared timeout, reveal
request mode, reveal-owner role identifier and declared reveal SLO. The explicit
`6529STREAM_ENTROPY_EPOCH1_NO_FRESH_RECOVERY_V1` profile records the absence of
fresh-randomness recovery in this implementation. The request-mode field records
the configured declaration; it does not claim that all specified automatic
request and sale-enforcement branches are implemented.

Live governed timing values, reveal fees and escrow balances, requester grants,
provider revocation and individual request progress are operational state. They
do not change this policy hash. Provider code loss does not erase the stored
original policy. Availability and request completion remain distinct reads.

In particular, `frozen=true` does not mean a seed has finalized. Token and scope
outputs must be authenticated independently when constructing content roots and
the complete finality manifest.

## Exact commitments

All encodings use `abi.encode`, never packed encoding. The named domains are the
keccak256 of their literal strings:

| Commitment | Domain | Ordered values after the domain |
| --- | --- | --- |
| Salt | `6529STREAM_ENTROPY_COLLECTION_SALT_V1` | chain ID, coordinator, Core, collection ID, original salt |
| Provider policy | `6529STREAM_ENTROPY_SINGLE_PROVIDER_POLICY_V1` | provider, original provider runtime hash, `uint32(1)`, provider configuration hash, salt commitment, public requests, declared `uint64` timeout |
| Reveal policy | `6529STREAM_ENTROPY_DECLARED_REVEAL_POLICY_V1` | declared `uint8` request mode, reveal-owner role ID, declared `uint64` SLO |
| Policy manifest | `6529STREAM_ENTROPY_FINALITY_POLICY_V1` | chain ID, coordinator, Core, collection ID, explicit profile hash, provider-policy hash, reveal-policy hash |
| Component data | `6529STREAM_ENTROPY_COMPONENT_EVIDENCE_V1` | deployment chain ID, Core, coordinator, exact scope tuple, policy manifest hash, provider, `uint32` epoch, salt commitment |

The component reports the actual coordinator's constructor-bound module version
and module manifest hash. Its adapter reports its own address and runtime hash.
The component-data commitment is independent of the finality manifest and artist
sanction, avoiding a circular dependency during preparation.

## Deployment and historical reads

Deploy the provider with `(Core, Metadata, coordinator, membership, readGas,
sourceGas)`. All four source addresses and runtime hashes are fixed, and reciprocal
Core/Metadata bindings and the required interfaces are checked in construction.
Module identity is read from the actual coordinator. Scope validation uses the
actual membership interface's eight-word result, including its exact subject.
Unknown, malformed or incomplete scopes cannot produce evidence.

The focused profile uses 500,000 gas for fixed source reads and 2,000,000 for the
membership read. These are separate forwarding envelopes, not a whole finality
transaction limit. The original Registry's eventual component budget must cover
the complete adapter/provider/source chain.

`requireCurrentEntropySelection()` checks the selected entropy and Metadata
pointers and live module eligibility. Historical component reads retain the
original fixed sources after pointer replacement or deprecation. A changed source
runtime or chain invalidates provider reads.

Core's retained `coordinatorAtMint(tokenId)` remains authoritative for each token.
A policy from a later coordinator cannot replace the policy of earlier tokens.
Complete discovery and content-root admission must join every original coordinator
needed by the scope; this single named-policy provider does not make that join.

## Evidence and remaining composition

The focused cohort has 48 passing cases in both compiler modes, including 15 new
policy/provider cases, a 256-input policy property and 18 actual threshold-Safe
transactions covering every new provider selector and the coordinator policy read.
It uses the actual Coordinator and serving adapter, with explicit Core, Metadata,
membership, role, execution-context and external randomness boundaries.

The named cold coordinator read costs 18,028 gas in default and 17,490 with IR;
the five-named-source provider call costs 37,478 / 34,886. The latter uses the
explicit membership fixture, and neither measurement represents all linked
accounts, complete current contracts or transaction intrinsic gas.

A separate 32-case IR cohort joins actual Core, Coordinator and Router. It
proves that the first actual mint locks the configured policy before a seed
exists, fulfillment leaves that policy unchanged, and replacing the Coordinator
preserves each token's original coordinator and policy. Artist/Finality and
external oracle boundaries remain explicit. This cohort also retains the
maximum-data serving test: the named cold Router call uses 11,939,859 gas,
while the outer Core call uses 12,749,169. Frozen-finality serving is a separate
composition requirement.

Full discovery, original-coordinator inventory, the complete typed metadata
provider and a newly frozen candidate remain separate acceptance work. See the
[delivery ledger](../../ops/V1_DELIVERY.md) and
[entropy specification](../stream-entropy-coordinator.md).
