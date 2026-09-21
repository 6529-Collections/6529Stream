# Attributed VIEW retrieval witnesses

This client targets `StreamViewRetrievalWitnessV1` at source
`a2973d360f6ab18881c04d58193f855704ec56d3`, using the
[focused ABI157 fixture](../test/fixtures/current-view-retrieval-v1-abi.json).
Its two writes are `publish(Request,signature)` and
`revoke(recordHash,reasonHash)`, both ordinary zero-value CALLs.

A witness records the original institutional writer's statement about retrieval
of a complete adopted VIEW image. It does not fetch a URL, calculate an object's
digest from its locator, establish origin immutability or parse an Arweave
manifest into independently verified path semantics.

## Prepare the original observation

The deployment pins Core, Router, the original root-free VIEW checkpoint and
external Archive, their runtime hashes, chain ID and four separate read gas
budgets. The actual witness profile and complete configuration hash must agree
with the reviewed deployment and linked-dependency evidence.

`prepare` obtains the complete current checkpoint source, adopted payload and
literal image URI. It joins the canonical locked Artist presentation and the
original Archive object, institutional receipt pair, storing agent, fixity and
native evidence. These reads derive the writer and complete Observation; the
Request cannot choose a replacement writer, source or object.

Preparation checks observation time and deadline against the actual source and
receipt times. It does not check signature validity, nonce availability or Store
chunk availability. A successful preparation alone does not make publication
ready.

## Sign the exact digest and retain the payload

The retrieval signing digest is domain-tagged `keccak256(abi.encode(...))`,
binding the chain, actual witness, complete configuration and Observation.
It is not an EIP-712 message or a `personal_sign` digest. The source key omits
`checkpointContextHash`; the complete signing digest retains that field.

The original validator supports its bounded own-key, EIP-7702 and ERC-1271
paths. An empty retrieval signature is valid when the actual caller is the
derived writer. A Safe's transaction signatures and the retrieval writer's
signature authorize different operations. The original `publish` simulation
remains the operative signature check.

A relayed empty signature can also succeed through the writer contract's
ERC-1271 path when the original validator accepts it.

The nonce is keyed by writer and is shared across scopes within this witness.
Nonce zero is valid. Publication consumes the nonce once, after current source
and original Archive preparation have been repeated following signature
validation.

The exact retained bytes are `abi.encode(observation,signature)`, limited to
524,288 bytes including the signature. The signature limit is 4,096 bytes.
Retain all exact chunks in the original Store's 8,192-byte STOP carriers before
publication. Missing or changed carriers cause publication to revert. The mined
record hash includes its actual recorded time; a preparation-time hash cannot
substitute for that mined commitment.

## Preserve literal route bytes

Each URI is limited to 2,048 UTF-8 bytes. Preserve query, percent-encoding,
fragment, Unicode and path bytes exactly. HTTPS uses the original Metadata URI
predicate. Arweave transaction roots use the original canonical base64url
interpretation; a transaction ID is not a content digest.

| Route | Original requirement |
| --- | --- |
| Direct | No steps; requested and resolved URI bytes must match. |
| HTTP redirect | Status 301, 302, 303, 307 or 308 from an HTTPS URI. |
| Mirror | An explicit attributed assertion of identical bytes, with status zero. |
| Arweave manifest path | Complete separately admitted manifest bytes, object and original pair, with exact size, Keccak and SHA-256 correspondence. |

Steps follow the original order, make progress and end at the exact resolved
URI. An unresolved Arweave path cannot be the final URI. The protocol has no
independent step-count limit beyond its complete encoded-size bounds.

## History, currentness and revocation

Historical inspection authenticates the canonical payload, receipt, source key,
observation digest and record commitment. It does not replay the historical
writer signature, expired deadline or today's Safe owners and Artist authority.

Operative `requireCurrent` and `requireCorrespondence` additionally recheck the
actual complete source, original Archive pair and route evidence. Fresh fixity
is allowed on the same retained pair; a new coverage head is not required.
Changed source or revocation can reject current admission while history remains
readable.

Only the saved writer can revoke, with a nonzero reason. Revocation uses the
scope saved with that record and increments its scope-specific epoch. It needs
no fresh source or Archive admission. When a client needs the exact scope for
receipt attribution, it must authenticate the retained canonical bytes rather
than accepting caller-selected revoke coordinates.

## Offline byte and call helpers

Use the original prepared Observation to derive the signing digest. With the
writer's exact signature, derive the publication bytes and required carriers:

```js
import {
  currentViewRetrievalV1Digest,
  currentViewRetrievalV1Payload,
  currentViewRetrievalV1Chunks,
  prepareCurrentViewRetrievalV1Call,
} from "@6529/stream-client";

const digest = currentViewRetrievalV1Digest(coordinates, configuration, observation);
const payload = currentViewRetrievalV1Payload(observation, signature);
const chunks = currentViewRetrievalV1Chunks(payload);
const publication = prepareCurrentViewRetrievalV1Call(coordinates, caller, {
  kind: "publish", request, signature,
});
```

Coordinates are the actual `{ chainId, witness }`. `chunks` contains each exact
chunk's data, byte length, hash and STOP runtime commitment; it uploads nothing.
`publication.call` is an unsigned zero-value CALL and reports no verified facts.
Use `prepareCurrentViewRetrievalV1Read` for the closed original read surface and
`authenticateCurrentViewRetrievalV1History` for retained receipt/payload checks.
All ABI integers use `bigint`; inputs are copied before asynchronous workflows.

## Fixed-block RPC workflow

Supply the actual witness address/runtime pin, full Configuration, chain ID,
and reviewed `linkedDependencies` and `historyLinkedDependencies`. These lists
record the supplied deployment's complete implementation links; the client does
not infer them or independently prove their source provenance. A history-only
deployment omits `linkedDependencies` and does not require current Core, Router,
Artist or Archive runtimes to remain available.

| API | Result |
| --- | --- |
| `previewCurrentViewRetrievalV1` | Original `prepare`, source bytes, Artist and Archive observations; nonce state is observed without becoming a preparation gate. |
| `captureCurrentViewRetrievalV1` | Immutable publish/revoke call and fixed-block evidence, without executing it. Publication checks its unused nonce and every existing Store chunk. |
| `simulateCurrentViewRetrievalV1` | Revalidated call through the actual witness, using the original signature and nested-read checks. |
| `reconcileCurrentViewRetrievalV1Receipt` | Exact direct/Safe transaction, preceding/end-block state, original event, retained bytes and nonce/epoch transition. |
| `inspectCurrentViewRetrievalV1History` | Authenticated immutable record and payload, with separate revoked and epoch observations. |
| `inspectCurrentViewRetrievalV1Current` | Historical authentication plus original current correspondence and same-pair Archive checks. |
| `observeCurrentViewRetrievalV1Refusal` | Bounded original-call result or refusal at an explicit block; it proves no submitted transaction's rollback. |

Preview, capture, history and current inspection require numeric `blockTag` and
positive `bigint` `gasLimit` options. This is an outer RPC call budget, separate
from the protocol's configured nested-read budgets. In particular, fetching up
to 524,288 retained bytes must not inherit the small configuration `readGas`.
Simulation and refusal observation accept `blockTag` and reuse the captured gas
limit. They perform no submission, signing or mining.

The workflow has explicit client transport limits: 21,000–100,000,000 outer
gas, 131,072 bytes per runtime, 256 pins per supplied list, 2 MiB inner calldata,
2 MiB plus 16 KiB outer calldata, 16 MiB RPC/log data and 65,536 receipt logs.
Original Archive receipt returns are limited to 65,536 bytes in total. Pure
codec/call allocation is limited to 1 MiB and 16,384 array entries; the original
publication payload, signature and URI bounds above still apply independently.

History and revoke capture can take `retainedPayload: { receipt, payload }`.
The receipt must equal the actual stored record and the bytes must authenticate
against it. This avoids making live carrier availability a new condition for
writer revocation; it does not accept caller-selected scope coordinates.

Receipt reconciliation requires a mined block later than capture. It compares
stable preparation facts across blocks and recomputes the publication record at
the inclusion timestamp, then checks the exact original event and stored record.
Safe mode additionally takes an independently verified `expectedSafeTxHash`.
Unrelated same-block nonce or epoch changes are refused; these block observations
do not prove an intra-block execution trace or fresh end-block source admission.

## Remaining consumer and runtime work

The retrieval-enabled VIEW inventory has a distinct profile and immutable
witness binding. Its Bundle's `coverRetrievalNext`, stored item-to-witness join,
revocation-aware refresh and media review are a separate consumer workflow.
The original dependency hash alone does not authenticate that companion, and
the token current-authority archive client does not supply this VIEW workflow.

Source, codec and client RPC checks do not establish actual Safe execution,
linked runtime provenance, transaction capacity, complete Artist/Router/finality
integration or deployment readiness. Those require matching runtime evidence.
