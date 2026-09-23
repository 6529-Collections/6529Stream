# Mint Manager and Ledger succession

The additive `IStreamMintLedgerImport` and `IStreamMintManagerImport` capabilities
preserve accounting floors and raw gate nullifiers across a Manager replacement,
including replacement on the same Ledger. Existing configure, mint and counter
ABIs remain available. See the canonical [mint accounting specification](../mint-policy-and-accounting.md)
and [upgrade/redeployment ADR](../adr/0007-upgrade-redeployment.md).

## Operational order

1. Deploy the successor Manager with its intended Ledger and the same Core.
   Admit the required modules and grant its Ledger writer permission through
   the authorized governance process.
2. Resolve or cancel outstanding obligations that require the predecessor to
   mint, then permanently retire its writer with `retireLedgerWriter`. Existing
   sale and auction adapters retain their immutable Manager bindings. Disabling
   a writer alone is insufficient. Retirement cannot be undone and cannot occur
   while that writer has an incomplete import.
3. Snapshot after retirement. Build the complete manifest of counter values,
   subject bases and consumed raw nullifiers. Publish a durable, content-addressed
   manifest and a sorted-pair Merkle tree containing every import leaf plus the
   descriptor below. Review completeness before authorizing its root.
4. Commit the root through the successor Ledger owner with the exact authenticated
   delayed-governance action context described below. The successor Manager's
   governance authority must equal that owner. Both Managers' Ledger and Core
   getters are checked. The predecessor must remain permanently retired.
5. Call `importCounterDefinitions(root, maxCount)` until the returned progress is
   complete; `maxCount` is 1 through 32. This permissionless operation copies the
   frozen predecessor's complete onchain list of pinned profile selections.
   A successor already pinned to a conflicting interpretation cannot complete;
   use a fresh successor. Also call `importMintAncestors(root, maxCount)` until
   ancestry copying is complete; each call copies at most 32 historical pairs.
   For the additive [phase-freeze capability](mint-phase-freeze.md), also finish
   `importPhaseFreezes(root, maxCount)`. Every frozen phase must remain on its
   original Ledger and is copied even if the successor has not configured it.
6. The successor Manager owner calls `importMintState(abi.encode(batch))` in
   batches of at most 32 total counter and nullifier leaves. A Safe owner uses an
   ordinary Safe CALL. Each leaf is single use. Counter values merge by maximum.
7. Call `completeCounterImport(root, counterCount, nullifierCount, descriptorProof)`.
   Exact leaf counts, complete profile copying, complete ancestry copying and
   complete inherited freeze copying are required. While an import is pending the Ledger rejects ordinary successor consumption.
8. Core enforces replacement continuity before its original class-3 pointer
   transition. It reads each Manager's exact Core and immutable Ledger binding,
   verifies the predecessor's pinned runtime and the successor Ledger's normal
   catalog/interface/runtime admission, then requires canonical true from that
   Ledger's `isMintSuccessorReady(oldLedger, oldManager, newManager)`. This applies
   to same-Ledger replacement too. Initial installation and same-address catalog
   refresh retain their original behavior. A separate Core Ledger inventory
   pointer does not substitute for either Manager's actual binding.
9. Record fresh Artist consent for each successor-bound policy, configure its
   phases and executors, and establish explicitly successor-bound sale routes.
   With a retained Artist suite, successor phase registration requires the
   completed successor to be Core's currently selected Manager and Ledger.
   Policy hashes can be previewed and Artist consent recorded before cutover.
   An inherited frozen phase's first configuration uses the Ledger's remaining
   executor ceiling in that preview; actual configuration seeds those inherited
   executors before the fresh policy/consent check. It cannot add new rights.

The Artist suite retains its original Manager and signing domains. The new
consumer authenticates complete lineage from that original Manager/Ledger pair;
old signatures are not reinterpreted. Source integration and the Core unit guard
do not establish a completed actual-current live migration; that acceptance is
still pending. During a pending prepared mint, the admitted replacement retains
the original incident-abort route and cannot complete its predecessor's operation.

Keep the predecessor deployed: import checks read its frozen values and replay
state. Imported profiles are enumerable on the successor even if no current
phase uses them, so a further succession retains inherited interpretations.
Global definition registration never changes a pinned legacy selection.

## Retained Artist consent and multiple replacements

`IStreamMintLedgerContinuity` is a separate additive capability. Each commitment
records its verified immediate predecessor. `importMintAncestors` copies the
retired predecessor's complete frozen ancestry in bounded batches. Completion
requires this copy, independently of counter-profile and Merkle-leaf counts.
First-generation succession has no older ancestors to copy. The original
`IStreamMintLedgerImport` identity and exact-pair readiness call are unchanged.

For `A -> B -> C`, C retains both `(ledgerB, managerB)` and
`(ledgerA, managerA)`. B's retirement does not erase its completed history.
`isCompletedMintDescendant(ancestorLedger, ancestorManager, successorManager)`
requires the exact queried ancestor pair, completed successor import, a live
successor writer and no successor retirement. Mint-time consent performs one
bounded membership read; it does not traverse historical contracts recursively.

An Artist suite's immutable `mintManager` remains its signature and historical
record anchor. Operation 60 hydration preserves that Manager; it is not a
Manager-rebinding mechanism. A different consumer is admitted only if Core's
current codehash-pinned Manager and Ledger are the candidate and its immutable
Ledger, and that Ledger reports completed ancestry containing the Artist's
exact original Manager/Ledger pair. Inactive sibling successors cannot consume
consent merely because they share an ancestor.

The Artist still checks the exact supplied policy and all existing accepted
binding, economics, content, payout and attestation prerequisites. Its operation
14 may record a new successor policy hash under the original signature domain.
That policy hash commits the successor Manager and Ledger. Neither imported
accounting nor a predecessor policy signature supplies consent for the new hash.

Original acceptance signatures, deployment attestations, policy digest context,
replay nonces and historical records remain unchanged. Artist live surfaces that
explicitly read its original suite Manager, such as phase-policy attestations
and platform declaration phase history, retain that behavior; this consumer
admission does not silently retarget them. Retired Managers and their old sale
obligations do not gain a route to mint through a successor.

## Commitment and tree

The retained root commitment call has six arguments:

```solidity
commitCounterImportRoot(
    predecessorLedger, predecessorManager, successorManager,
    uint64(snapshotBlock), importRoot, manifestHash
);
```

Only one root may be committed per successor Manager. The predecessor and
successor Managers must differ; the Ledgers may be identical. Already-retired
successors and snapshots preceding retirement or later than the current block
are rejected.

`CounterImportLeaf` is the ordered tuple `(uint256 collectionId, bytes32 phaseId,
bytes32 counterId, uint8 keyMode, bytes32 subjectBasis, bytes32 predecessorSubjectKey,
uint64 value)`. Its collection and phase are the normalized accounting namespace,
not necessarily a live phase. The double-hashed leaf is:

```solidity
keccak256(bytes.concat(keccak256(abi.encode(
    keccak256("6529STREAM_MINT_COUNTER_IMPORT_LEAF_V1"),
    block.chainid, predecessorLedger, predecessorManager, leaf
))))
```

For address subjects, `subjectBasis` is a canonical zero-padded address. For
`CONSTANT` it is zero; for `CONTEXT` it is the nonzero context hash. Manager and
Ledger independently derive the successor subject using the successor Ledger
domain. Ledger also verifies the predecessor subject and reads the exact frozen
predecessor value. Imports cannot remap namespaces or supply a lower value.

The raw-nullifier leaf uses the same construction with
`keccak256("6529STREAM_MINT_NULLIFIER_IMPORT_LEAF_V1")`, chain ID, predecessor
Ledger, predecessor Manager and `bytes32 nullifier`. The predecessor must report
that nullifier as used. Ticket authorization IDs and operation roots are not
imported; tickets bind their Manager and Ledger and must be reissued.

The supplemental descriptor is a double hash of `abi.encode` of:

```text
keccak256("6529STREAM_MINT_IMPORT_MANIFEST_LEAF_V1"),
chainId, successorLedger, predecessorLedger, predecessorManager,
successorManager, uint64(snapshotBlock), manifestHash,
uint64(counterCount), uint64(nullifierCount)
```

Every internal tree node sorts its two `bytes32` children before hashing their
ABI encoding. The descriptor prevents premature completion of the committed
tree. It does not prove that the offchain manifest enumerated every historical
key: governance must review that completeness. Onchain profile completeness is
checked against the retired predecessor's own frozen list, independently of
the manifest counts.

## Governance context

The Ledger owner must expose the canonical `currentAction()` context. The
commitment requires `executing = true`, a nonzero action ID, action class `1`,
`oldHash = 0`, and these exact commitments:

```solidity
scope = keccak256(abi.encode(
    keccak256("6529STREAM_MINT_IMPORT_SCOPE_V1"),
    block.chainid, successorLedger, successorManager
));
newHash = keccak256(abi.encode(
    keccak256("6529STREAM_MINT_IMPORT_COMMITMENT_V1"), scope,
    predecessorLedger, predecessorManager, successorManager,
    uint64(snapshotBlock), importRoot, manifestHash
));
```

An EOA call, an unrelated active action, a wrong class or a different transition
commitment fails. The published import events retain their normative schema,
indexed fields and values. `MintLedgerImportAction`, profile-copy and completion
events provide supplemental progress evidence.

## Encoding and verification boundary

`IStreamMintManagerImport.ImportBatch` contains `importRoot`, `counters`,
`counterProofs`, `nullifiers`, and `nullifierProofs`, in that order. The counter
and nullifier arrays must match their proof-array lengths. The fixed bytes
entrypoint supports this schema only; it is not a generic call router.

`StreamMintContinuity.t.sol` covers actual Manager/Ledger imports, a real Safe
1.4.1 owner, same/new Ledger floors, replay, retirement, proof and governance
failures, and old-ticket rejection. `StreamMintContinuityProfiles.t.sol` covers
bounded profile copying and successive generations. Core, Artist and governance
context fixtures in these scoped suites do not establish production deployment
readiness or whole-stack governance/pointer activation acceptance.


## Core replacement regression evidence

The separate 57-source native capture passes all 29 tests: eight actual-Core
mint replacement cases, seven royalty cases, two Artist history cases and twelve
permanent-target regressions. The mint cases cover same/new Ledger completion,
exact predecessor/successor identity, foreign Core, missing/delegated code,
malformed/noncanonical replies, catalog and runtime drift, unchanged pointer
state on failure and retry of the same saved governance action. The prepared
mint case preserves replacement abort and rejects replacement completion.

Manager/Ledger import and governance replies in this Core cohort are typed
boundaries. The mint builder's separate 87-case capture uses actual Manager,
Ledger, ModuleRegistry and Safe with typed Core/Artist/governance/registry seams.
These complementary results do not establish whole-current-stack succession.
