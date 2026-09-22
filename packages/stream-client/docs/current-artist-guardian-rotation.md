# Original Artist guardian sets and address rotation

This client authors original Artist operations 28–32. It uses the Registry's
original EIP-712 version `1`, with ABI evidence frozen at
`c636a5f176c5765d80d15ee20f41355a8911ea9c`. The selected original family was
compared with integration `9a1a3d299d796a3907c58fb68a497bd9fb8ab457`.
The existing `current-artist-recovered-multiple-consent-hydration-abi.json`
fixture supplies the ABI and source witness; this family does not generate a
new Solidity build or adopt that fixture's other capabilities.

| Operation | Request kind | Registry method | Selector |
| --- | --- | --- | --- |
| 28 | `setGuardians` | `setArtistGuardians` | `0x06fff5c7` |
| 29 | `stageRotation` | `rotateArtistAddress` | `0x48c13be5` |
| 30 | `approveRotation` | `approveArtistRotation` | `0xbcedafce` |
| 31 | `vetoRotation` | `vetoArtistRotation` | `0x0420794d` |
| 32 | `executeRotation` | `executeArtistRotation` | `0x3255d66b` |

The pure module is `src/current-artist-guardian-rotation.ts`; the provider
workflow is `src/current-artist-guardian-rotation-workflow.ts`. No deployment
addresses or trusted runtime hashes are supplied by default. Callers must
provide the actual reviewed deployment and an explicit observation block.

## Prepare and sign

`prepareGuardianRotationCall(request)` returns an immutable unsigned call,
operation number, and signing payloads. Every call has zero native value.
`factsVerified` is always false: local encoding does not establish authority,
available nonces, timing, valid signatures, or permission to execute.

All integer inputs are bounded `bigint` values. All requests and nested terms
have exact fields. Guardians must already be strictly ascending numeric
addresses, unique and nonzero, with at most eight members. The helper never
silently sorts a reviewed list. An empty set requires threshold zero; a
nonempty set requires a threshold from one through its size. A per-identity
contest floor may be zero and cannot exceed thirty days.

```ts
import { prepareGuardianRotationCall } from "../src/current-artist-guardian-rotation.js";

const prepared = prepareGuardianRotationCall({
  kind: "stageRotation",
  chainId,
  registry,
  caller, // actual Registry caller: EOA, relayer, or Safe itself
  terms: {
    artistId,
    oldAddress,
    newAddress,
    reasonHash,
    expectedPreviousTransitionRecordHash,
  },
  oldAuthorization: { nonce: oldNonce, time: oldDeadline, signature: oldProof },
  newAuthorization: { nonce: newNonce, time: newDeadline, signature: newProof },
});

// Each .typedData is an ordinary EIP-712 domain/types/message payload.
// The application obtains any required signatures, then prepares the call again.
const oldSide = prepared.signing[0];
const newSide = prepared.signing[1];
```

There are three permanent signing schemas:

| Schema | Meaning of authorization `time` | Included terms |
| --- | --- | --- |
| `StreamArtistGuardianSet` | `signedAt` | Artist, guardians, threshold, floor, nonce and signed time |
| `StreamArtistKeyRotation` | `deadline` | Artist, old address, new address, reason, nonce and deadline |
| `StreamArtistRotationAcceptance` | `deadline` | Artist, old address, new address, nonce and deadline |

The domain name is `6529StreamArtistRegistry`. Its verifying contract is the
Registry facade, with the actual chain ID. Owners, Coordinator and Reads are
not alternate signing domains.

`expectedPreviousTransitionRecordHash` is a required concurrency guard in
calldata and is deliberately excluded from both rotation signatures. Changing
it changes the call but does not change either signed digest. Acceptance also
excludes `reasonHash`. The workflow therefore checks the actual previous
transition, and applications should present the complete call alongside both
signing payloads.

The old side consumes the Artist principal nonce lane (kind 1). The new side
consumes the independent kind 4 lane
`keccak256(abi.encode(keccak256("rotation_acceptance"), artistId, newAddress))`.
Equal numeric nonces in these two lanes are valid. New-address acceptance is
not checked against the old principal's nonce state. Direct calls require the
next available nonce in their own lane; signed calls still require an unused,
unrevoked nonce. No helper reserves a nonce.

A signer is direct only when it is the actual Registry caller and its proof
is empty. Empty bytes from another caller are not automatically direct;
contract signers may use an empty ERC-1271 proof. Both sides of a rotation need
valid consent in the same call. Because the addresses differ, they cannot both
be direct. Both deadlines apply even to a direct side and remain valid at exact
timestamp equality.

For guardian administration, a direct empty-proof `time: 0n` is a convenience
at execution: the contract replaces it with the inclusion timestamp. The
digest getter itself hashes the supplied time without replacement. Consequently
the prepared zero-time digest differs from the effective execution digest and
record. A direct explicit time must equal inclusion time; a relayed signed time
must be nonzero and no later than inclusion. Applications should recapture and
simulate close to submission.

## Observe, simulate, and inspect

The workflow uses `CurrentArtistDeployment`: chain ID, Registry and Coordinator
runtime pins, all sixteen ordered suite component pins, and a required Reads
pin. `captureGuardianRotation(provider, deployment, prepared, { blockTag })`
checks current wiring and runtime hashes, joins authoritative records, and
rechecks the concrete block hash. It returns immutable observations with
`simulationRequired: true` and per-signature `signatureVerified: false`.

```ts
import {
  captureGuardianRotation,
  simulateGuardianRotation,
  createGuardianRotationSafePlan,
  inspectGuardianRotationReceipt,
} from "../src/current-artist-guardian-rotation-workflow.js";

const captured = await captureGuardianRotation(provider, deployment, prepared, {
  blockTag: observationBlock,
});
const simulated = await simulateGuardianRotation(provider, captured, {
  gasLimit: 5_000_000n,
  blockTag: simulationBlock,
});
// Optional: the Safe must equal prepared.request.caller.
const safePlan = createGuardianRotationSafePlan(simulated.observation, {
  safe: caller,
  title: "Stage Artist address rotation",
});
// After the application submits the reviewed call and it is mined:
const evidence = await inspectGuardianRotationReceipt(provider, captured, {
  transactionHash,
  execution: "safe", // use "direct" for an ordinary Registry transaction
});
```

Simulation reconstructs the historical capture, rereads a later explicit block
when requested, and calls the exact Registry calldata from the actual actor.
It rejects changed authority, guardian, pending rotation, timing configuration
and other compared facts. Each simulation supplies positive gas capped at
100 million; this is an API resource bound, not a claim about deployment gas.
Direct zero-time guardian digests may change with the observed timestamp.
Signatures, lifetime guardian retention, duplicate guardian approvals and
composed transition admission remain contract simulation checks. A successful
`eth_call` does not reserve state or guarantee later inclusion.

Receipt inspection joins the exact transaction to the original Identity event,
Coordinator-domain Archive evidence ID, canonical full payload, retained STOP
bytes, metadata and snapshot transitions. The original record tip advances for
operations 28 and 29 and remains unchanged for operations 30–32. The result has
`historicalEvidenceOnly: true`: it does not reconstruct native owner state roots
or certify the present authority. A stage may execute later in the same block;
the original staged Archive remains the source for its staging receipt.

The inspector intentionally requires correspondence with the captured
authority, guardian and timing facts. A concurrent valid change can make it
reject a successful transaction; retain the transaction and investigate its
original evidence instead of treating that rejection as transaction failure.

## Separate approval, execution, and history

Staging captures the operative guardian record, threshold, effective contest
duration, standing tail and timing revision. The effective duration is the
greater of the governed duration and the guardian set's floor. The governed
defaults are seven days for rotation and ninety days for prior standing;
immutable minimums are seventy-two hours and thirty days respectively. The
client reads the current governed values and does not substitute defaults for
missing facts.

Guardian approval records one captured member's approval. It does not execute
the rotation, change the authority address, or establish Artist activity.
Applications submit operation 32 separately. Anyone may execute once the
contest deadline is reached, or earlier with a positive captured threshold and
enough approvals. A zero threshold does not enable early execution.

Execution begins the full captured post-execution window, even after an early
guardian quorum. A new rotation cannot bypass an active transition window.
An expired staging deadline does not discard a pending rotation, and contested
status does not expire by itself. A veto has its own original standing rules;
an arbitrary caller cannot veto merely because execution is permissionless.

Guardian maintenance follows current principal authority. Successor and
steward capabilities, the artist-recorded lifetime guardian set, and the
separate guardian-displacement capability remain relevant. A displayed set
or historical binding address is not sufficient authority evidence.

`prepareGuardianRotationRead` and `decodeGuardianRotationRead` expose the
original guardian head, pending rotation, historical guardian/rotation records,
transition, previous transition, active window and acceptance nonce reads.
Each signing entry also contains its exact digest read. Canonical ABI decoding
checks encoding; it does not establish that a historical record is operative.
`artistGuardianRecordHash` and `artistRotationRecordHash` reproduce the
permanent record domains using the effective execution timestamps.

## Safe calls and verification boundary

A Safe is the actual caller of an ordinary zero-value Registry `CALL`.
The outer Safe transaction authorization is separate from old/new Artist
EIP-712 consent. A Safe transaction bundle does not replace the other rotation
side's proof. A guardian Safe must itself be a member of the captured set.

These modules prepare calls and perform reads/simulation. They do not handle
private keys, submit transactions, propose to a Safe service, or perform an
on-chain ceremony. Fixture parity, TypeScript tests and mocked provider
workflows are separate evidence from actual EOA/ERC-1271/Safe execution,
deployment provenance, gas/capacity, audit or release readiness.

The governing semantics are documented in
[Artist authority](../../../docs/stream-artist-authority.md) and
[ADR 0025](../../../docs/adr/0025-artist-authority-windows-and-fixed-extensions.md).
