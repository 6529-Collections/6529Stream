# Artist personhood documentary references

This additive client is pinned to ABI102 source
`70c0d9c37f6435c480b87083af8d1cbd4fa7098d`, tree
`6f5e76e63d2ed31fa881aed6983e405b7aa07e89`. Its 2,710 literal compiler inputs
were independently matched to that Git source. Earlier client fixtures retain
their original source qualifications.

The caller authors the original principal `recordArtistAttestation` operation
24, subject kind 10 and `6529STREAM_ARTIST_PERSONHOOD_EVIDENCE_V1` schema.
There is no additional personhood write selector, signature domain or nonce.
The reference links documentary evidence; it does not establish legal personhood
or the external standing of a signer.

## Prepare the original call

```js
const prepared = prepareArtistPersonhoodCall({
  chainId, registry, core, caller, collectionId,
  reference: {
    version: 1n,
    profileHash: PERSONHOOD_PROFILE_HASH,
    artistRegistry: registry,
    artistId,
    operativeIdentityRecordHash,
    notarizationHost,
    notarizationRuntimeHash,
    notarizationRecordHash,
  },
  nonce, signedAt, signature, statementURI,
});
```

Protocol integers are `bigint`. The closed JSON format has eight ordered keys,
lowercase hexadecimal fields and exactly 590 bytes. The immutable interpretation
document has 1,837 bytes and its original hash is `PERSONHOOD_PROFILE_HASH`.
`decodeArtistPersonhoodReference` rejects alternative encodings, key order,
unknown fields and foreign profile hashes.

The operative identity hash is distinct from the original registration document.
A fresh reference uses the actual Registry domain receiving operation 24.
Historical imported references keep their original domain; they cannot become
fresh successor authority by changing the outer transaction target.

The prepared call retains `factsVerified: false`, the original
`6529StreamArtistRegistry` version-1 typed data and zero native value. Preparation
does not validate the current authority or reserve its nonce. The original inner
Artist signature is at most 4,096 bytes; outer Safe signatures are separate.
The client permits at most 2,048 UTF-8 bytes in a scalar-valid statement URI.

Direct execution requires the literal current principal as caller and the
original current nonce. A zero direct `signedAt` means the mined timestamp.
An explicit direct timestamp must equal that block's timestamp. Relayed
execution retains the original signature, nonce and positive timestamp. An
empty ERC-1271 proof is not by itself proof of direct execution.

## Capture, simulate and reconcile

```js
const captured = await captureArtistPersonhood(
  provider, deployment, prepared, { blockTag: captureBlock }
);
const checked = await simulateArtistPersonhood(
  provider, captured, { blockTag: laterBlock, gasLimit }
);

const plan = createSafeCallPlan(chainId, "Record personhood evidence", [{
  safe: caller,
  intent: "Original principal Artist operation 24",
  call: prepared.call,
  abi: CURRENT_ARTIST_PERSONHOOD_ABI,
}]);

// Submit through your wallet, then inspect its transaction:
const receipt = await reconcileArtistPersonhoodReceipt(
  provider, captured, transactionHash,
  { execution: "safe", expectedSafeTxHash }
);
```

The shared Safe planner retains the exact Registry target, calldata, caller and
zero value. Its plan hash is an application review commitment, not a Safe
signature digest. The receipt profile covers ordinary single-call
`execTransaction` with operation zero and an independently supplied Safe
transaction hash. Batches and module execution need separate receipt profiles.

`deployment.artist` uses the existing `CurrentArtistDeployment` shape with an
additional `reads` address/runtime pin for the Coordinator's original reader.
Its 16 components remain the seven owners, Registry, Archive, Core, Manager,
roles, Metadata, primary Resolver, royalty Resolver and validator, in that order.
The outer deployment also pins `general`, `moduleRegistry`, `schemaRegistry`
and `chunkStore`. These are reviewed address/runtime pairs; the capture verifies
the actual reciprocal suite and dependency bindings at a concrete block.

Receipt reconciliation requires a block later than capture and checks reviewed
facts at the prior block. A same-block prerequisite or intervening change may
therefore require a new capture. This is a conservative client acceptance rule,
not an atomic expected-state argument added to the contract. Later owner writes
do not replace the immutable original Archive and native receipt evidence.

The original principal personhood receipt has nested operation-24 evidence.
Delegated/scoped attestation evidence uses a different encoding and cannot be
substituted. Admission may legitimately cancel a pending living-Artist dormancy
notice and append an operation-42 Identity occurrence before the operation-24
Attribution occurrence. Authority is the current principal selected by Identity,
including its original class, status and attestation capability rules.

Other original living-Artist activity can cancel an estate activation or record
an unavailability activity observation. This receipt profile authenticates those
effects through the containing original Archive/Identity checkpoint. It does
not independently reconstruct every activity event or auxiliary state cell.

Receipt evidence includes the original operation, owner commits and Archive,
plus the complete `ArtistPersonhoodProofRetained` event and matching summary
catalog carriers. The immutable summary contains 48 ABI words (1,536 bytes).
Its tagged payload is 1,568 bytes and its original hash is
`keccak256(abi.encode(PERSONHOOD_SUMMARY_TAG, summary))`. An event or catalog row
alone does not replace the original authority receipt.

## Evidence reads

`prepareArtistPersonhoodRead` makes zero-value calls for the original Attribution
owner's five public views. Reads require no Safe transaction. The fixed
Attribution owner is found through the actual Registry/Coordinator suite.

| View | Meaning |
| --- | --- |
| `personhoodEvidence` | Original native head, retained reference and current status. |
| `personhoodEvidenceStatus` | Compact native hash and the same status. |
| `personhoodProofSummary` | Complete immutable summary, or exact zero when absent. |
| `personhoodProofSummaryHash` | Retained hash of that complete summary. |
| `auditPersonhoodEvidence` | Explicit full replay of the original documentary proof. |

`inspectArtistPersonhood` exposes these reads with an explicit block and owner
runtime pin. Immutable summary inspection is separate from a currentness check
or full audit of former external dependencies.

```js
const observed = await inspectArtistPersonhood(
  provider,
  { chainId, attribution: { address: attributionOwner, codeHash } },
  { method: "personhoodEvidence", collectionId, artistId },
  { blockTag: inspectionBlock, gasLimit }
);
```

The client bounds each payload catalog at 4,096 entries, ordinary runtime reads
at 65,536 bytes and simulation/read gas at 100,000,000. These are client
allocation limits. Target-level simulation does not establish equivalent gas
inside a Safe or the protocol's nested read paths.

RPC byte responses are capped at 262,144 bytes, outer transaction calldata at
524,288 bytes, and receipts at 512 logs with at most four topics and 65,536 data
bytes per log. Original Archive evidence is capped at 24,575 bytes and its
STOP-prefixed carrier at 24,576 bytes. The General payload and signature bundle
each retain their original 8,192-byte bounds.

| Status | Interpretation |
| --- | --- |
| NONE | No selected native personhood head. |
| WAIVER | Original explicit waiver remains current. |
| RESOLVED | The admitted original documentary reference remains current. |
| STALE | A known identity, binding, selected head or dependency fact changed. |
| UNRESOLVED | Missing proof, opaque historical evidence or a failed bounded read. |

The selected native personhood head is authoritative for these reads. A newer
General record, different recorder or C2PA credential is not silently selected.
Fresh evidence requires the actual ACTIVE General module and exact definitions.
DEPRECATED permits inspection of previously admitted immutable evidence.
Historical signatures are retained; today's ERC-1271 owners are not asked to
authorize the old signature again.

## Scope and remaining coverage

This batch supplies the canonical evidence profile of principal operation 24.
It preserves the existing explicit waiver and opaque-history semantics without
introducing a new waiver authoring surface. Recovered-history operation 60 plus
personhood is unsupported at ABI102. The recovered profile-10 caller and broader
operation/role coverage remain explicit gaps in the
[whole-v1 Safe inventory](current-v1-safe-coverage.json).

Validation here covers frozen source/ABI compatibility, TypeScript and client
tests. Actual Safe execution, whole-current-stack behavior, bytecode capacity,
transaction gas and release/deployment acceptance remain separate evidence.
