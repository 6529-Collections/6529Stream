# Current reference metric supplement bytes

`current-reference-metric.ts` is the pure codec and identity verifier for the
additive reference-metric supplement frozen at source commit
`7ca6a2df111e607f8dca055253f0c2fad182720e`. It preserves the original V1
reference record and perceptual context. It does not alter the original
seven-field metric, report preimage, publication payload, receipt, or the
identities of BYTE_EXACT and CURATED finality.

The module accepts bytes already obtained by the caller. It never downloads,
runs, restores, or publishes source code, Python, browser binaries, archives,
or diagnostics.

## Closed source and runtime profile

`ReferenceMetricSupplement` mirrors the Solidity tuple exactly. Its four source
rows are fixed in this order:

1. `tools/museum/canonical.py`
2. `tools/museum/chain_abi.py`
3. `tools/preservation/reference_manifest.py`
4. `tools/preservation/reference_metric.py`

Each content field is the raw file bytes, with no newline conversion.
`referenceMetricImplementationIndex` computes SHA-256 over each raw file and
emits the exact sorted compact JSON object with lowercase hex, no `0x`, and no
trailing newline. Its Keccak must remain the original metric implementation
hash. Parameters are also exact bytes and retain their original Keccak.

The runtime fixes the entrypoint, interpreter, launcher, source root and
arguments `-I -S -B metric/launch.py`. Its members must be the entire original
environment package inventory beneath `metric/`, in the same strict UTF-8 byte
order. The codec checks the source, implementation-index and parameter members'
exact sizes and SHA-256 values, plus nonempty interpreter and launcher members.
It retains declarations and hashes; it does not establish that the archived
runtime exists or is executable.

## Original context projection

Build `ReferenceMetricOriginalContext` from the already authenticated original
publication and PERCEPTUAL evidence. Preserve:

- the original reference record hash and `modeContextHash`;
- environment object and manifest hashes plus the full package-file inventory;
- viewport, device-pixel ratio and capture-major repeated SHA-256 pairs; and
- the original metric implementation/parameter hashes, report hash, threshold
  and evaluation time.

Collection ID and original revision are workflow currentness locators. They are
not added to a new supplement preimage. The workflow should compare them with
the original stored receipt and current-reference getter before publication.

`referenceMetricInputManifest` reconstructs the exact compact JSON inputs in
capture order. `validateReferenceMetricSupplement` then checks the original
environment, source index, parameters, context, report, inputs, exit code and
time range. Supply the timestamp of the concrete observation as
`maximumExecutedAt`; an execution after that timestamp is rejected.

## Canonical bytes and distinct hashes

`encodeReferenceMetricSupplement` and `decodeReferenceMetricSupplement` use
canonical `abi.encode(Supplement)`. Decoding re-encodes and rejects trailing or
alternative ABI bytes. The profile bounds parameters and input manifests to
65,536 bytes, each source to 131,072 bytes, the wrapped transcript to 65,536
bytes, runtime members to 2,048, and the full payload to 524,288 bytes.

Do not interchange these identities:

- `referenceMetricPayloadHash` is Keccak of canonical supplement bytes;
- `referenceMetricRuntimeHash` wraps the runtime tuple in
  `6529STREAM_METRIC_RUNTIME_V1`;
- `referenceMetricReplayHash` wraps the replay tuple in
  `6529STREAM_METRIC_REPLAY_V1`; and
- `referenceMetricSupplementHash` wraps the zero-self-hash receipt with chain,
  producer, Core and Metadata coordinates in
  `6529STREAM_METRIC_SUPPLEMENT_V1`.

The replay transcript is another canonical ABI envelope under
`6529STREAM_METRIC_TRANSCRIPT_V1`. Its copied runtime, context, report, inputs,
time and exit code must equal the replay tuple. The final diagnostic bytes must
be nonempty. That envelope attributes a recorded claim; it is not proof that
the EVM executed Python or that the diagnostic is honest.

## Chunk projection and receipt validation

`referenceMetricSupplementChunks` divides canonical bytes into the Store's
fixed 8,192-byte segments, except for the final shorter segment. The returned
rows retain every occurrence and its original index and offset. Equal chunks
remain separate rows even though their Keccak hashes match. Upload and
publication calls belong to the workflow client.

`validateReferenceMetricReceipt` reconstructs the canonical artifact before
checking its receipt. It requires the exact payload size/hash, runtime and
replay hashes, registered schema/profile/canonicalization hashes, reference
record and domain-derived supplement hash. The caller must provide the actual
observed authority: a nonzero recorder, class 3 CURATOR or class 8 global grant,
and its nonzero grant revision. The workflow must additionally bind
`recordedAt` to the mined block and event.

## Evidence boundary

These helpers establish source-derived encoding and internal byte consistency.
They do not establish current-record status, lock state, grant authority,
registered document availability, retained Store chunks, archive custody,
loaded dependencies, OS prerequisites, successful offline replay, onchain proof
acceptance, or finality. Those require the publication/readback workflow and an
independent restoration run against the same original artifacts.
