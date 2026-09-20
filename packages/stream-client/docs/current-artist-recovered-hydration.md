# Recovered Artist authority hydration

The additive client prepares original operation 60, profile 10,
`hydrateRecoveredArtistAuthority(Request)`. It imports the complete admitted
history of one recovered class-1 or class-3 Artist and one accepted generation-one
PRIMARY_ONLY collection. The original seven-owner transaction remains the
authority boundary. Decoding a payload or reading one owner is insufficient.

This client is pinned to ABI104 source
`d56e13ffc8664b322a3a208f21d308918ed47072`, tree
`3425349f0e485ac26c5e9fccc8121b240f741739`. The fixture records its full selected
ABIs, import-closure hashes and original public-library selector evidence.
Existing hydration clients and their earlier fixtures keep their original
qualifications.

## Explicit capability profiles

| Advertised feature mask | Admitted extension |
| --- | --- |
| 31 | Recovered Identity/Payout history, retained V2/V3 evidence and repeated imports. |
| 63 | The preceding history plus complete original direct economics operation 15. |
| 127 | Complete retained delegation and mixed original consent operations 14/15/16. |
| 255 | Complete original operation-24 attestations, including retained personhood and C2PA state. |

These are known capability shapes. The required mask is derived from the actual
complete history, including unused, revoked or expired grants and prior recovery
classes. Every expected source capability must equal its actual value. Every
source and destination owner must support all required features. Capability bits
grant no Artist permissions and do not change an estate's retained permission
mask, including zero.

Class 4, multiple Artists or collections, collaborators, corrected generations,
and recovered content/freeze composition require separate admitted profiles.
Future feature bit 256 and its separate entry point are outside this caller.

## Complete request and witnesses

The original request contains:

- `records.authority`: the selected Artist and collection, binding index, all
  seven expected source checkpoints, ordered policy selectors and complete
  logical replay-origin witnesses.
- `records.witnesses`: complete economics and attestation witnesses in their
  original respective journal order.
- `expectedCapabilities`: the seven exact source capability values in owner order.
- `expectedSourceImportCommitment`: the source's actual prior import commitment.
- `expectedSemanticInventory`: the exact nonzero collected certificate identifier.

When neither economics nor attestation records exist, `records.witnesses` is
empty. Otherwise it contains exactly one wrapper for the selected collection.
Its economics array contains every original operation-15 term; its attestation
array contains every original operation-24 term and nonce. One array is empty
only when that record family is absent. Missing, extra, duplicate, reordered and
empty wrappers reject. A current payout, signer or subject head cannot replace a
missing historical preimage.

All protocol integers use `bigint`. Preparation preserves the complete supplied
request and zero native value. Hydration is permissionless: the nonzero caller
does not sign a new Artist authorization. The caller remains bound by the actual
operation evidence and transaction envelope.

## Collect and simulate

```js
const captured = await captureArtistRecoveredHydration(
  provider, deployment, caller, request, { blockTag, gasLimit }
);
const checked = await simulateArtistRecoveredHydration(
  provider, captured, { blockTag: laterBlock, gasLimit }
);
```

Collection uses the original `StreamArtistRecoveredHydrationPrepared.prepare`
public view library, with an explicit reviewed deployment pin. This is a library
call, not an additional Registry endpoint. Its nominal Solidity selector has a
separate compiler witness; an ordinary tuple-based ABI selector is different.

`deployment` pins the original source and destination suites plus the original
preparation library and its linked dependencies. Each suite retains its Registry,
Coordinator and 16 component pins: seven owners, Registry, Archive, Core, Manager,
roles, Metadata, primary Resolver, royalty Resolver and validator. Runtime hashes
are checked against these inputs at the selected block.

The library pin must come from reviewed deployment/link metadata for the retained
source. A caller-supplied address and hash are trust inputs, not independent proof
that the code implements that source. The capture checks the returned certificate
against the actual suites and full producer inventories. The separate simulation
step executes the final nonzero-inventory request against the original Registry.

A draft may use zero `expectedSemanticInventory` only for the read-only
preparation phase. The final prepared mutation always contains the computed
nonzero identifier. An existing nonzero expectation must match; the client must
not silently replace stale evidence.

The predecessor must have its original operation-57 seal naming this successor.
The destination needs its genuine operation-55 history binding and operation-56
Artist and collection proofs. Lane proofs alone install no authority. The seven
non-Artist component addresses and primary revenue class must match, and all
seven destination owners must be in the original pre-import state.

Captures use explicit blocks, own their input before asynchronous reads and
reject changed block hashes. Revalidation checks both the retained capture and
the later state. A simulation applies to its concrete block; it does not reserve
the source state or prove gas sufficiency inside a Safe.

## Historical and current state

The certificate retains the complete flat provenance prefix and the immediate
source's native suffix. An A→B→C import preserves A and B as distinct original
environments. Compare era order first, then revisions within the same owner and
era. Revisions from different owners or environments are not interchangeable.
Repeated secondary operation-35 hashes remain distinct native occurrences.
Original preparation/execution mutations without native receipts do not acquire
synthetic occurrences.

Current replay-key inventories, historical aliases and logical replay witnesses
serve different purposes. All indexed nonce lanes, prefixes and 32 ancestor words
remain intact. Source operation-55/56/57 evidence stays historical; genuine local
destination lane latches remain local, and the destination retains its own future
cutover latch.

Pending requests, unused preparations and compromised status are retained as
original history. Their presence does not make the transport a fresh recovery,
execution authorization or restoration of live eligibility.

The original registration identity differs from the operative identity used by
later evidence. Historical signatures, grants, approvals and personhood summaries
retain their original domains and admissions. The import does not ask today's
principal or ERC-1271 owners to reauthorize them. Current status, grant eligibility,
notarization heads and fresh successor-domain authorization remain separate.

Complete publication catalogs retain original pointers and bytes. Timing has its
own configuration, action inventory and checkpoint. Governance, finality and
entropy observations remain on their original pinned hosts; hydration neither
resets their consumed guards nor makes old preparation a fresh authorization.

## Receipt and Safe composition

```js
const plan = createSafeCallPlan(chainId, "Import recovered Artist authority", [{
  safe: caller,
  intent: "Original recovered Artist operation 60",
  call: checked.capture.prepared.call,
  abi: CURRENT_ARTIST_RECOVERED_HYDRATION_ABI,
}]);

// After submitting through the wallet:
const receipt = await reconcileArtistRecoveredHydrationReceipt(
  provider, checked.capture, transactionHash,
  { execution: "safe", expectedSafeTxHash }
);
```

The shared planner preserves the exact target, calldata, caller and zero value.
Its review hash is not the Safe transaction digest. Receipt inspection uses the
independently supplied Safe transaction hash and original ordinary single-call
`execTransaction` with operation zero. Batches and module execution need separate
receipt profiles. Direct execution uses `{ execution: "direct" }`.

Each of the seven owners commits once at its original revision plus one, without
adding a semantic native receipt. The combined commitment binds the complete
request, certificate and original before-snapshots. The actor is separately bound
by the operation evidence identity and Archive header.

The original profile bytes are retained in ordered Archive pages. Each page ID
binds the chain, Registry, Coordinator, import commitment, complete payload hash
and length, page count, index and page hash. The canonical operation-60 header
binds the descriptor and all seven before/after snapshots. Pages or a completion
event alone cannot replace that header and the complete owner transitions.

Receipt reconciliation requires historical reads at the reviewed block, the
block immediately before execution and the receipt block. The prior-block import
context must reproduce the reviewed facts. Immutable imported prefixes and the
original Archive snapshots prove that import even if later writes in the receipt
block advance an owner's revision. The result explicitly makes no claim about
current authority or eligibility.

Source provenance, publications, timing and external guards are rechecked after
all owner writes. Pages, the header, history and payload synchronization share the
same original EVM transaction. Any propagated late failure rolls everything back;
a failed Safe transaction cannot produce an accepted hydration receipt.

## Finite transport and validation

The source profile bounds one transport to 16 eras, 4,096 native occurrences,
8,192 replay aliases, 128 nonce lanes per owner and 256 prefixes per lane. Each
eligible owner's publication catalog permits 16,384 rows. Evidence permits 128
pages of 20,480 bytes, totaling 2,621,440 bytes. Economics, policy, sale and
attestation families have their own 128-record limits.

These transport limits do not limit future original writes or runtime history
after import. The client also imposes the following allocation and execution
bounds; it can reject a protocol-valid transport that exceeds them.

| Client surface | Acceptance bound |
| --- | --- |
| Pure request/preparation calldata | 2,621,440 bytes, including the selector. |
| Workflow preparation and Registry calldata | 2,097,152 bytes. |
| Receipt outer transaction | 2,113,536 bytes, including Safe overhead. |
| Each RPC result / aggregate receipt log bytes | 16,777,216 bytes each. |
| Pinned runtime / retained payload | 131,072 / 24,575 bytes. |
| Receipt logs | 65,536 logs, at most four topics and 28,671 data bytes each. |
| Owner / Archive catalog | 16,384 / 65,536 rows. |
| Preparation dependency pins | 256 pins, plus the preparation library. |
| Explicit preparation and simulation gas | Positive and at most 100,000,000. |

Paged profile evidence uses its full 2,621,440-byte capacity. Each page and the
separate operation header must fit the original Archive's configured carrier
limit. A capture does not estimate or guarantee execution gas.

Source, ABI, TypeScript and mocked client tests are separate from actual contract
or Safe execution. Full-system runtime, bytecode size, transaction gas, release
evidence and deployment acceptance remain integration work.
