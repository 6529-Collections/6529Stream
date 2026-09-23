# Reference Mode payload preparation

These callers prepare the original Publication and complete Mode payload bytes
for the fixed reference publication host. Preparation retains bytes without
granting writer, Artist, source, metric, conservation or finality authority.

The payload remains the original seven-field encoding:

```text
abi.encode(REFERENCE_MODE_PAYLOAD_V1, Publication, normalizedReceipt,
           SourceFacts, Evidence, Facts, canonicalEnvironment)
```

Every nested field and array is retained, including conservation evidence,
signed metric scores, capture HTML and complete Environment file inventories.
The earlier metric projection types cannot substitute for these full inputs.

## Ordered workflow

1. Prepare both original file inventories and the exact Environment using the
   [inventory](current-reference-inventory.md) and
   [Environment](current-reference-environment.md) callers. Their preparation
   identities include the actual chain and publication host.
2. Capture `previewModeReference` at a concrete block with the intended recorder.
   Decode its complete returned payload and keep the returned Publication,
   including its populated `expectedSourcesHash`. The initial submitted
   Publication may have a different hash. Preview performs the original live
   source and recorder checks at that block.
3. Upload the chunks of `abi.encode(returnedPublication)` to the original Store,
   then call `prepareModePublication` with that full Publication.
4. Upload the chunks of the complete canonical payload, then call
   `prepareModePayload` with the publication preparation ID and the original
   receipt, source, evidence and facts.
5. Review any later publication separately. The unchanged
   `publishModeReference(publication,evidence)` accepts the full original
   arguments and derives any prepared-byte identity internally. Its live checks
   still apply when it executes.

Uploads and the two preparation calls are permissionless. The uploader,
preparer and eventual recorder may be different accounts. Preparation calls
carry zero native value and do not request signatures or submit transactions.

```js
const preview = await captureReferenceModePreview(
  provider, deployment, recorder, publication, evidence, { blockTag }
);
const plan = prepareReferenceModePayloadPlan(
  deployment, preparer, preview.snapshot, { uploader }
);
```

`preview.publishCall` contains the original returned Publication and Evidence.
Its `publicationSimulationRequired: true` flag keeps later publication review
explicit. The preparation plan's steps cover uploads and the two byte-preparation
calls.

An intact repeated preparation returns the same ID without emitting another
preparation event. A changed input has a different identity. Missing or corrupt
chunks fail the original transaction atomically.

## Canonical inputs and identities

`prepareReferenceModePublication(chainId, publicationHost, publication)` copies
the full original input and reconstructs its ABI bytes, Environment snapshot,
preparation ID and descriptor. `prepareReferenceModePayload` uses that snapshot
and the original receipt/source/evidence/facts to reconstruct the complete
payload and its component commitments. Snapshot normalizers rebuild these
values before asynchronous work uses them.

Only these five Receipt fields are normalized to zero:

- `recordHash`
- `recordChainHash`
- `payloadHash`
- `payloadBytes`
- `recordedAt`

The other fifteen fields remain committed. These include recorder,
authorization class, grant revision, effective time, predecessor, revision and
source identity. Perceptual thresholds and scores retain signed `int64` values.
No authorizing signature schema or payload domain changes.
String fields accept valid Unicode text without normalization. Arbitrary
non-UTF-8 Solidity string bytes are outside this client.

The publication preparation ID hashes the original preparation domain, chain,
actual host, Publication ABI hash and its `uint32` byte length. Its descriptor
also retains the input-derived Environment ID and exact canonical hash/length;
the contract derives that descriptor from the full input.

The payload preparation ID hashes its original domain, chain, actual host and
the hash/length pair for each component, in order:

1. Publication ABI
2. Normalized Receipt ABI, exactly 640 bytes
3. SourceFacts ABI
4. Evidence ABI
5. Facts ABI
6. Raw canonical Environment bytes

`decodeReferenceModePayload` requires the original domain, canonical re-encoding
and exact Environment equality. Retained bytes do not establish that the stated
facts were ever current or that the supplied recorder is authorized.

## Pinned review and receipts

The workflow authenticates the actual host and Store runtimes, deployment chain
and configured dependencies. Preview additionally checks the original dependency
and recorder observations. Its snapshot is tied to the captured block/hash; a
later source or writer revision can change the prepared identity needed for
publication.

The preparation plan deduplicates original Store chunks of at most 8,192 bytes.
Availability checks verify each pointer's exact `STOP || chunk` runtime, length
and hash. Preparation requires the exact retained Environment and, for the
second stage, the exact retained Publication. Inspection and retry do not invent
the upload history or rerun a preview as proof of historical creation.

Step simulation uses the exact caller, target, calldata and zero value. Gas
quotes concern that inner call; a Safe's enclosing execution has additional gas
costs. Ordinary Safe CALL plans preserve step order and caller identities.
Dependent steps must be inspected again after their prerequisites are mined.

When the recorded uploader and preparer are Safes, compose the unsigned steps
with the existing [ordered Safe CALL planner](safe-call-plans.md) and the exact
Store and Mode host ABIs from the reviewed compiler output:

```js
const safePlan = createSafeCallPlan(
  deployment.chainId, "Prepare reference Mode payload",
  plan.steps.map(step => ({
    safe: step.caller,
    intent: step.kind === "upload" ? "Retain an exact payload chunk"
      : step.kind === "publication" ? "Prepare the original Publication"
      : "Prepare the original Mode payload",
    call: step.call,
    abi: step.kind === "upload" ? compiledStoreABI : compiledModeABI,
  }))
);
```

Each step remains an individual ordinary CALL. Use direct transactions for
steps whose recorded caller is an EOA. Target-level simulation does not check
Safe owners, threshold or signatures.

Receipt inspection joins the exact direct call or ordinary Safe call, original
preparation event and retained descriptor/bytes. Safe success must follow the
relevant retention events. An eventless repeat requires intact prior-block
retention evidence; first creation followed by a same-block repeat cannot be
attributed from end-of-block reads alone.

Receipt inspection requires block number at least one and authenticates the
host and Store runtime pins at both the receipt block and its preceding block.
It cannot inspect a preparation receipt from the block that deployed either
contract. Repeated payload preparation still requires the exact intact
Environment and Publication.

The original content limit is 524,288 bytes. Inspection accepts RPC byte returns
up to 528,384 bytes and outer transaction calldata up to 2,000,000 bytes. A
receipt may contain at most 256 logs, each with at most four topics and 16,384
data bytes. Pinned dependency runtimes are bounded to 65,536 bytes; a Store
chunk runtime is at most 8,193 bytes including its leading `STOP`. These wrapper
bounds do not change the original content or chunk limits.

## Frozen source and limits

The fixture uses `parallel-feature-batch57-20260920` at
`9beafd1ab5e5a5c8403f24958e49801f34625e66`. All 2,248 literal compiler inputs were
verified byte-for-byte against Git. The fixture retains 33 ABI entries in five
selections, 107 production closure hashes and ten source texts. Existing
Environment and inventory fixtures remain tied to their original sources.

```sh
node scripts/generate-current-reference-mode-payload-fixture.mjs \
  /path/to/abi-input.json /path/to/abi-output.json --check
```

Client encoding, mocked RPC, source and ABI checks do not prove full publication
or real Safe execution. The integrator's separate native9 capture passed the two
actual-host preparation calls within their transaction limits, but full
publication exhausted gas while reading and retaining the large payload.
This frozen ABI57 fixture does not include the later internal transport repair;
that source refresh and its execution evidence remain separate from this batch.
Preparation success does not establish publication, genesis or release readiness.
