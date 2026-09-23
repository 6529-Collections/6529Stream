# Original collaborator identity and binding acceptance

These modules prepare and inspect the original collaborator operations 5–7.
They use the existing Registry EIP-712 version `1` and the already implemented
`PRIMARY_ONLY` binding profile. The compiler ABI and source witness is frozen
at `bd4a291e9e159cbbb5079a9a2a418fb151a8c01b`, in
`test/fixtures/current-artist-recovered-multiple-attestation-hydration-abi.json`.
Selected collaborator producers are compared with integration
`4fd8017505c979da6d8545900b8d6cf5b42003fa`; this does not adopt that fixture's
other capabilities or establish runtime validation of the integration.

| Operation | Request kind | Registry method | Selector |
| --- | --- | --- | --- |
| 5 | `proposeIdentity` | `proposeCollaboratorIdentity` | `0xddc50578` |
| 6 | `acceptIdentity` | `acceptCollaboratorIdentity` | `0x6338b9e6` |
| 7 | `acceptRow` | `acceptCollaborator` | `0x80631a17` |

The pure module is `src/current-artist-collaborator.ts`; provider workflows
are in `src/current-artist-collaborator-workflow.ts`. The signing schemas for
operations 6 and 7 remain those in `current-artist.ts`.

## Prepare the exact call

`prepareCollaboratorCall(request)` returns immutable calldata, the operation
number and a signing payload for operations 6 or 7. Operation 5 has no Artist
signature. Every call carries zero native value, and `factsVerified` is always
false: encoding does not establish permission, available nonces or a valid
signature.

```ts
import { prepareCollaboratorCall } from "../src/current-artist-collaborator.js";

const prepared = prepareCollaboratorCall({
  kind: "acceptRow",
  chainId,
  registry,
  caller, // actual Registry caller: account, relayer or Safe
  core,
  terms: {
    collectionId,
    generation,
    bindingHash,
    account,
    role,
    shareLabelId,
  },
  authorization: { nonce, time: deadline, signature },
});
// prepared.signing.payload contains domain, types, message and digest.
// Obtain any required signature and prepare again with its proof bytes.
```

Integer inputs are bounded `bigint` values, and objects have exact fields.
An identity proposal requires nonzero account, identity document hash and
reason hash. Document and reason URIs may be empty; each is limited to 2,048
UTF-8 bytes. Identity acceptance supplies 1–8,192 document bytes whose hash
matches the proposal, and a display name of 1–256 UTF-8 bytes. These are the
original source's byte and hash checks; the helper does not assert that an
opaque document satisfies a broader JSON schema.

The client limits proof bytes to 4,096 bytes as a resource bound. It does not
infer signature validity from their length or encoding.

`role` is a bytes32 role identifier. A zero role is valid. `shareLabelId` is a
label, not a percentage or payment amount; zero represents unpaid credit.
The frozen binding's rows are limited to 32 and must be strictly ordered by
numeric account, then numeric role. One account may have several distinct
roles. The same account/role pair cannot appear twice with different labels.
`normalizeCollaboratorTerms` validates this order without changing it.

## Proposal, identity and row acceptance are separate actions

Operation 5 requires the Registry admin role. It records a proposal for one
account and identity document hash; it does not register the identity or
accept a collection binding. The source archives the role's membership hash
and mutation revision alongside the proposal.

Operation 6 needs the proposed account's own consent. It does not require the
accepting caller to be an admin or collection owner. The proposal must exist
and remain unaccepted, and the account must not already have an active
identity. Successful acceptance creates a fresh original Artist identity and
marks the proposal accepted.

The account authorization nonce is independent of the global registration
counter used to derive the new Artist ID. Acceptance consumes the account's
kind 3 lane and the fresh Artist's kind 1 principal lane. Applications must
not substitute the global allocation counter for the signed account nonce.
`collaboratorIdentityId` accepts the allocation counter explicitly.

Operation 7 joins an existing pending binding to the exact collection,
generation, binding hash, account, role and share label. That account must be
the current ordinary principal of its own active collaborator identity. The
source accepts the original admissible classes 1, 3 and 4 with their matching
status; a historical binding address or delegated signer is not sufficient.
This consumes the collaborator identity's kind 1 principal nonce.

`PRIMARY_ONLY` uses mode zero, threshold zero and no capability overrides.
It still requires each listed collaborator row to accept individually. The
primary Artist may accept before or after the rows. Operation 7 completes the
binding only when the final row accepts and the primary acceptance record
already exists. Collaborator acceptance does not require a new primary
co-signature. These modules do not implement the separate multiparty
approval-policy or co-signed gate work.

## Signing and nonce observations

The EIP-712 domain is `6529StreamArtistRegistry`, version `1`, with the actual
chain ID and Registry facade address. Operation 6 signs account, identity
document hash, nonce and deadline. Operation 7 signs Core, collection,
generation, binding hash, collaborator account, role, share label, nonce and
deadline. Proof bytes and transaction caller are not signed fields.

Both authorization times are deadlines, including direct calls. Equality
with the inclusion timestamp is allowed. A signer is direct only when it is
the actual Registry caller and the proof is empty. Direct calls require the
next available nonce in their own lane. An empty relayed EOA proof is invalid;
a contract account may accept empty proof through ERC-1271. Capture does not
validate ERC-1271 or EOA signatures, so contract simulation remains necessary.
An observed principal digest alone is not a replay refusal: consumed or
revoked nonce and revoked digest facts are checked according to the source.

`collaboratorAcceptanceRecordHash` reproduces the original acceptance record
domain. That record hash omits role and share label. Applications must retain
and check the full signed terms, native event and archived row; a matching
record hash alone cannot prove which role and label were accepted.

## Observe, simulate and inspect

Supply a reviewed `CurrentArtistDeployment` with chain ID, Registry,
Coordinator, all sixteen ordered suite components and the Reads runtime pin.
No addresses or trusted runtime hashes are assumed by these modules.

```ts
import {
  captureCollaborator,
  simulateCollaborator,
  createCollaboratorSafePlan,
  inspectCollaboratorReceipt,
} from "../src/current-artist-collaborator-workflow.js";

const captured = await captureCollaborator(provider, deployment, prepared, {
  blockTag: observationBlock,
});
const simulated = await simulateCollaborator(provider, captured, {
  gasLimit: 5_000_000n,
  blockTag: simulationBlock,
});
const safePlan = createCollaboratorSafePlan(simulated.observation, {
  safe: caller,
  title: "Accept collaborator binding row",
});
// After the application submits the reviewed transaction and it is mined:
const evidence = await inspectCollaboratorReceipt(provider, captured, {
  transactionHash,
  execution: "safe", // ordinary Registry transaction uses "direct"
});
```

Capture pins a concrete block and checks deployment wiring, runtime hashes
and the relevant authoritative proposal, identity, role or binding facts.
It rechecks the block hash and returns `simulationRequired: true`.
Simulation checks capture correspondence, refreshes the requested observation
block and calls the exact calldata from the actual actor with explicit gas.
A successful simulation does not reserve a nonce or guarantee inclusion.

Receipt inspection checks the transaction and full original Archive payload,
the Coordinator-domain evidence ID, metadata, retained STOP bytes, native
events and the operation's owner snapshot transitions. Its result is
historical evidence. It does not reconstruct native owner state roots or
establish current identity authority, payout entitlement or Safe ownership.
Concurrent valid state changes can make a successful transaction differ from
the prior capture and require investigation of its original evidence.

The inspector allows the global allocation counter to advance before identity
acceptance is mined: the actual event and Archive determine the allocated ID.
For row acceptance, other rows and the primary acceptance may arrive between
capture and mining. The result's `completion` contains the archived counts
and primary record that actually determined completion. Immutable binding
terms, selected row, principal and submitted proof must still correspond.

The native receipt search is bounded to 128 entries added after the captured
journal cursor. A longer interval is outside this helper's inspection bound.
Post-block principal replay observations must show digest observation and
nonce consumption; identity registration also checks its account nonce and
the original account-digest replay cell. These reads can include later actions
within the same block, so the Archive remains the operation's historical
payload.

`prepareCollaboratorRead` and `decodeCollaboratorRead` cover proposal state,
the account registration nonce, collaborator count, individual rows and
collaborator payout designation. The read result decoder checks canonical
ABI encoding. A historical row or payout designation alone does not prove
present authority or that a payment is due.

A Safe is the actual caller of a zero-value Registry `CALL`. The Safe's outer
transaction authorization is separate from Artist EIP-712 consent. These
modules do not handle private keys, send transactions or propose to a Safe
service. Fixture, TypeScript and mocked provider tests are separate from
EOA/ERC-1271/Safe runtime execution, gas/capacity validation, audit and release
readiness.

Source ownership is described in
[ADR 0023](../../../docs/adr/0023-modular-artist-authority-domain-ownership.md).
