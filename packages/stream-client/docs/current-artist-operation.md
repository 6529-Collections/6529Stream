# Current Artist operation callers

The ART39 extension adds the following public calls. Existing acceptance,
collaborator, policy, economics, payout, attestation, content-consent and
ratification payloads remain in their original client modules.

| Original operation | Public facade method | Purpose |
| --- | --- | --- |
| 3 | `refuseArtistBinding` | Refuse an exact pending generation and binding hash. |
| 14 | `recordDelegatedPolicyConsent` | Record exact policy consent using a scoped delegation. |
| 15 | `recordDelegatedEconomicsConsent` | Consent to an exact installed economic assignment. |
| 15 | `recordDelegatedProspectiveEconomicsConsent` | Consent to a proposed fixed assignment or clearing. |
| 16 | `recordSaleConsent` | Record approval of an exact current sale configuration. |
| 16 | `recordDelegatedSaleConsent` | Record exact sale consent using a scoped delegation. |
| 20 | `authorizeArtistRoyaltyFreeze` | Authorize the specified royalty assignment freeze. |
| 20 | `authorizeDelegatedRoyaltyFreeze` | Authorize that freeze using a scoped delegation. |
| 21 | `authorizeArtistContentFreeze` | Authorize specified metadata locks at an exact state. |
| 24 | `recordDelegatedArtistAttestation` | Attest to an original authenticated subject using a delegation. |
| 24 | `recordDelegatedArtistScopedAttestation` | Attest to an exact finality or economics scope using a delegation. |
| 25 | `recordIdentityRevision` | Extend the operative document with exact document bytes. |
| 26 | `grantArtistDelegation` | Grant the original scoped capabilities and use/window limits. |
| 27 | `revokeArtistDelegation` | Revoke an exact grant using its stored grantor. |
| 54 | `revokeArtistAuthorization` | Revoke one unused digest or nonzero nonce. |

Operations 20 and 21 record authorization. The corresponding resolver or metadata
operation must still perform the freeze.

The frozen [coverage register](current-artist-operation-coverage.json) tracks every
original operation 1–60, the existing operation 61 dispute withdrawal, source-pinned
method variants, and three additional public configuration/checkpoint methods.
An operation ID is not a claim that all its variants have client workflows.
Operation 36 is historically named `designateSuccessor`; its actual facade method
is `recordSuccessorDesignation`. Delegated policy and sale consent retain the
original operation IDs 14 and 16. C2PA callers remain pending.

The additive [authority hydration callers](current-artist-authority-hydration.md)
cover operation 60's approved baseline, multiple and single-delegation profiles.
Their newer compiler fixture preserves the coverage register's earlier source
snapshot and does not imply support for every hydration combination.

## Payload and caller review

`currentArtistOperationTypedData` reconstructs the permanent EIP-712 schema.
`prepareCurrentArtistAction` retains the complete request, typed payload,
original write calldata and read-only digest call. Its exact request contains
`kind`, `chainId`, `registry`, `caller`, `signer`, `artistId`, `mode`, `signature`,
`message` and `details`. The kind names are `bindingRefusal`, `saleConsent`,
`royaltyFreeze`, `contentFreeze`, `authorizationRevocation`, `identityRevision`,
`delegationGrant`, `delegationRevocation`, `delegatedPolicyConsent` and
`delegatedSaleConsent`, `delegatedEconomicsConsent`,
`delegatedProspectiveEconomicsConsent`, `delegatedRoyaltyFreeze`,
`delegatedAttestation` and `delegatedScopedAttestation`.

The signing domain is `6529StreamArtistRegistry`, version `1`, with the actual
chain and `StreamArtistOnboardingRegistry` facade address. Coordinator, owner,
extension and configuration-directory addresses are not signing hosts.

Every integer is a bigint. Refusal, consent, freezes and both revocation schemas
use a deadline; their records use the transaction block timestamp. Refusal's `details.reasonURI` is reviewed
calldata outside the signed schema, limited to 2,048 UTF-8 bytes. Identity revision
details are described below. Delegated actions retain the nonzero `grant` record
hash; economics adds its collection and prospective candidate as described below.
Attestation details are described below. The other details objects are empty.
This client accepts Unicode URI text; it does not represent
arbitrary non-UTF-8 Solidity string bytes. Content-freeze lock classes retain their supplied order and
must be 1–16 strictly increasing, nonzero bytes32 values. Their signed commitment
hashes packed words; the record preimage retains the original dynamic array.

`mode: "direct"` requires caller equal to signer and empty signature bytes.
`mode: "signature"` retains opaque EOA or ERC-1271 proof bytes. An empty proof
from a distinct relayer can be valid for an ERC-1271 wallet; signature length
alone does not determine the lane. The original authorization path limits proofs
to 4,096 bytes. No helper asks a wallet to sign or submits
a transaction. EIP-7702 signers follow contract signature validation; deployment
components must match the reviewed immutable runtime pins.

## Identity and delegation

Identity revision signs the Artist ID, previous and revised document hashes,
nonce and `signedAt`. The previous hash is the operative document hash. Details
retain the URI, actual document bytes and display name; the document must be
1–8,192 bytes and hash to the signed revised value. The URI is at most 2,048
UTF-8 bytes and the display name is 1–256 bytes. Both are Unicode text inputs;
arbitrary non-UTF-8 contract strings are outside this client. URI and display name are
supplemental calldata outside the permanent signed schema.

A direct revision with `signedAt: 0n` keeps that submitted sentinel in calldata.
The contract replaces it with the execution timestamp before hashing and replay
consumption. Capture retains the submitted and block-specific effective digest;
receipt inspection recomputes the digest at the mined timestamp. An explicit
direct time must equal the execution timestamp. A relayed revision uses its
explicit nonzero time, which cannot be later than execution.

Delegation grants sign Core, delegate, collection, capabilities, start/end times,
maximum uses, constraints and nonce. The Artist ID remains in the original
request and record; it is not added to the permanent signature. Authorization
time is exactly zero, with no invented deadline. Collection zero is global,
maximum uses zero is unlimited, and zero constraints hash is permitted. The
accepted capability mask is `1143` (`1 | 2 | 4 | 16 | 32 | 64 | 1024`), including
policy consent (`2`) and sale consent (`1024`). A future grant still
reserves its Artist/delegate key until revoked, expired or exhausted.

Grant revocation resolves the stored grantor independently from current Artist
authority. An expired, exhausted or replaced historical grant may still be
explicitly revoked if it is not already revoked. Zero reason hash is permitted.
These three operations consume the shared Artist nonce lane. Delegated consent
uses the persistent Artist/delegate nonce lane described below.

Receipt verification preserves the original storage and event formats. Revision
storage reports authority class `1` even where its record hash and event use the
actual class. The delegation-revoked event omits the resulting revocation hash,
so verification joins the original preimage, Archive and grant record. Later
document revisions, grant uses or revocation do not erase the historical action.

## Delegated policy and sale consent

The additive methods reuse the permanent policy and sale EIP-712 schemas, digest
getters and actual Registry domain. The grant hash and client Artist locator
are outside those signatures. Both methods retain the original authorization
tuple and deadline. Creation requires an accepted binding in consent mode 2,
current living authority, an eligible grant epoch, collection scope and the
specific policy or sale capability. The grant must be active with a use available;
successful creation consumes one use and a nonce in the Artist/delegate lane.
Replacing a grant does not reset that nonce lane.

Principal sale and content-freeze calls also admit consent mode 2. A principal
authorization continues to consume its ordinary Artist nonce. Captures keep
these lanes distinct and exact-call simulation checks the original contracts'
remaining prerequisites.

Consent creation and later consumption have different checks. The stored
class-2 consent retains its original grant association after the grant expires,
is revoked or exhausts its uses. Receipt inspection verifies the original
class-2 record, Consent-owner association event and Archive payload, including
the full grant before execution. Later applicability depends on the original
policy or sale checks and current ordinary prerequisites; it does not require
the grant to remain live. Sale verification uses the actual sale adapter as the
caller because the original Registry read derives the adapter from `msg.sender`.

`inspectCurrentArtistRecordedConsent(provider, deployment, request, { blockTag })`
reads a supplied policy or sale record independently from a creation capture.
Its policy result is explicitly `policy-record-only`: the exact retained policy
record does not establish full mint readiness. Its sale result is
`sale-consent-checked-for-adapter` and includes the exact checked call with the
adapter as `from`. Sale readback also reconstructs the original stored record
hash and checks its authority class and grant association. Neither result rechecks the grant's lifetime. Refresh the
relevant ordinary prerequisites before a later mint or sale.

## Delegated economics and royalty freeze

Both economics variants reuse `CurrentArtistEconomicsConsent` and the original
`economicsConsentDigest`. Their message contains Core, resolver, revenue class,
scope, scope ID, assignment hash, nonce and deadline. The collection ID is in
`details.collectionId`, outside the signature. Both retain `details.grant`.
Prospective consent also retains `details.candidate` with `profileHash`,
`policyHash`, uint16 `royaltyBps` and `frozen`. The candidate, payout and binding
are outside the original signature; the exact-call review and contract checks
must admit them. Candidate `frozen` is preserved, `policyHash` must be zero, and
`royaltyBps` is bounded to 1,000. The chosen resolver checks its exact profile and
royalty combination.

These routes admit the original consent modes 1 and 2. Economics requires grant
capability `4`; royalty freeze requires `32`. They use the same persistent
Artist/delegate nonce lane and consume one grant use. The current principal
authority must still have class 1. Economics follows ordinary identity admission;
freeze also admits the original defensive identity status 4.

For these three routes, supply `deployment.reads`, an independently reviewed code
pin for the Coordinator's immutable `reads()` host. Capture verifies that binding
and calls the original Reads composition. Current economics retains its exact
installed assignment and payout evidence, including supported primary-template
and snapshot-royalty paths. Prospective economics retains the exact preview fact
and previous assignment hash. A legitimate clear uses zero `assignmentHash` with
an all-zero, unfrozen candidate; it does not create a new assignment. The original
Reads host checks payout shares and collaborator designations through the chosen
resolver's own split factory. Consent alone never installs an assignment or
changes payout rights.

Delegated royalty freeze reuses `CurrentArtistRoyaltyFreeze` and its original
digest getter. It requires the selected live royalty resolver, the current
collection assignment and an unfrozen collection configuration. Snapshot royalty
mode is not a freeze target.

Economic receipt verification joins the class-2 record, original
`ArtistEconomicsConsentRecorded`, `ArtistEconomicsConsentAssociated` and
`ArtistRecordDelegation` events, the binding-specific getter and the original
nested Archive payload. The record preimage itself omits collection ID; its
association binds the full terms, Artist, generation and binding hash. A later
binding continuation can have a new record while `economicsRecord(terms)` retains
the first record. Historical payout designation evidence does not require today's
operative payout to remain unchanged. Freeze joins its original authorization,
`ArtistRecordDelegation` event and historical freeze record. Neither family uses
the additive policy/sale `ArtistConsentDelegationRecorded` event.

## Delegated attestation

Both attestation variants retain original operation 24 and
`CurrentArtistAttestation`: Core, collection, subject kind, subject ID, subject
state hash, schema, statement hash, URI hash, nonce and `signedAt`. Details contain
`grant`, `statementURI` and the exact `statement` bytes. Statements must be
1–8,192 bytes; URIs are at most 2,048 UTF-8 bytes. Both must match their signed
hashes. A scoped request adds `details.subject` with `scopeType`, `tokenId`,
`scopeId` and `resolver`. The grant and descriptor remain outside the signature.

Consent modes 1 and 2 are admitted with current principal authority class 1 and
ordinary identity status 1 or 2. Subject kind 7 requires delegation capability
`64`; every other supported kind requires `1`. Each creation consumes one grant
use and the persistent Artist/delegate nonce lane shared with other delegated
operations. The original grant epoch, scope, time window, use limit and estate
restrictions must admit creation.

For these delegated attestation methods, direct `signedAt: 0n` is replaced with
the transaction timestamp. An explicit positive direct or relayed time may be
earlier than execution, but cannot be later. A relayed zero time is invalid.
This differs from the exact-timestamp rule for direct identity revision.

Capture authenticates each subject through the original reads at one block:

| Kind | Subject and evidence |
| --- | --- |
| 1 | Snapshot from the facade's finality registry and its pinned provider/configuration; current receipt and both snapshot hash getters agree. |
| 2 / 3 | Script/media manifest hash on the Core-selected collection metadata host. |
| 4 | Finalized collection or scoped finality record on the facade-bound finality registry. |
| 5 | Existing phase and policy hash on the suite's original Mint Manager. |
| 6 | Exact primary or royalty assignment, with the original resolver and scope checks. |
| 7 / 8 | Original canonical publication envelope and the selected, eligible metadata host's candidate read. |
| 9 | Original deployment facts reconstructed from chain, Core, collection and binding. |
| 10 | Operative Identity document with the original personhood waiver/evidence schema. |

Scoped calls are supported only for kinds 4 and 6. Finality uses scope 0 for the
collection, 1 for a nonzero `tokenId`, and 2–4 for a nonzero `scopeId`; its
resolver is zero. Economics always uses zero `tokenId`: scope 0 has zero
`scopeId`, scope 1 encodes the collection ID in `scopeId`, and scope 2 has a
nonzero `scopeId`. Economics names the suite's actual primary or royalty
resolver. Signed subject IDs must match the original scope hash.

Kinds 7 and 8 require the original 416-byte
`abi.encode(uint16(1), Publication)` statement. The exact tuple is exported as
`CURRENT_ARTIST_ATTESTATION_PUBLICATION_TUPLE`. It retains metadata host,
recorder, collection, subject, record type, schema, canonicalization, payload
algorithm/hash, URI hash, effective time and candidate record hash. The
publication recorder must be the delegate. Kind 7 signs that candidate as its
subject state; kind 8 requires a zero subject state. The actual metadata host
still checks the record family, schema and canonical candidate.

The receipt joins the Attribution owner's `ArtistAttestationRecorded` and
`ArtistAttestationDelegation` events, record-by-hash, authority class, statement
bytes, binding association and original flat eleven-field Archive payload.
Publication kinds also join the stored publication evidence. Later latest-head,
subject or grant changes do not erase a correctly recorded historical receipt.
Subsequent detached publication separately rechecks the live grant epoch,
window, revocation, succession, binding and candidate. Exhausting `maxUses` alone
does not invalidate the already consumed publication use. This batch verifies
attestation creation; it does not perform that later publication.

C2PA schemas and the two principal attestation variants remain outside these new
workflows. Their earlier payload helpers retain their existing scope.

## Authority and execution

`captureCurrentArtistOperation(provider, deployment, request, { blockTag })`
requires a concrete block number. Deployment pins contain the Registry,
Coordinator and the Coordinator's exact 16-component order: seven owners,
Registry, Archive, Core, Manager, roles, metadata, primary resolver, royalty
resolver and validator. The caller supplies independently reviewed code hashes.

Capture checks the chain, runtime hashes, component bindings, current Registry,
authority, operation capability, binding, operation timing, original digest and replay
lane. Economic routes also retain the original payout and assignment evidence.
Direct execution uses the current nonce hint. Signed execution can use
another unused nonce. Revocation reads the target separately from the nonce
authorizing the revocation. Captures are immutable and reconstructed before
asynchronous work.

A capture is an observation and carries `simulationRequired: true`.
`simulateCurrentArtistCall` rechecks its historical observation, refreshes at the
chosen block and calls the original write with the actual caller. That write
establishes the operation-specific sale-adapter, metadata or royalty admission
at the simulated block. It also checks revision provisional-child occupancy,
live or future delegation-key conflicts and estate-directive restrictions.
A changed binding or authority requires a new capture.
State can still change before mining; simulation reserves neither authority nor
a nonce.

`createCurrentArtistSafePlan` preserves the supplied order and creates ordinary,
zero-value Safe CALLs. It accepts only supported original public methods through
reconstructed requests. It rejects repeated authorization nonces, repeated grant
revocation targets and known authorization-revocation conflicts in the same lane.
A delegated action cannot follow revocation of its grant in the supplied plan;
the action followed by revocation remains permitted. Principal and delegate nonce
lanes stay separate.
The future effective digest of a direct zero-time revision or attestation is unknown and is not
treated as a known digest conflict. Refresh timing and replay before execution.
Each entry is a separate transaction. When one action
changes the next action's nonce or other state, mine it and capture the dependent
action again. The [review example](../examples/current-artist-operation.mjs)
combines capture, exact-call simulation and a one-step plan. Its request already
contains the intended direct or signed authorization.

## Receipt evidence

`inspectCurrentArtistReceipt` checks a successful direct transaction or an
ordinary Safe `execTransaction`, its exact caller/calldata, original semantic
owner events, record hash and durable record/replay reads. Archive evidence must
match the original operation envelope and request, and follow the owner events.
Both Safe success-event layouts are admitted; success must follow the operation
evidence. Captures must precede the receipt block.

Client receipt inspection is bounded to 512 logs, 65,536 bytes per log and
524,288 transaction-calldata bytes; decoded Archive/read data is bounded to
262,144 bytes. A receipt outside these inspection limits requires a separate
review rather than a successful result from this helper.

Receipt verification concerns that transaction and its retained records. Later
same-block state is not proof that the consent remains applicable. For example,
historical sale-consent existence does not replace current adapter/configuration
validation. Protocol-only owner/Coordinator methods are not user-call targets.

## Frozen source and limits

The historical operation fixture uses the retained `parallel-feature-batch52-20260920` ABI capture at
commit `44af244ed576cc4b26632b800fe70a068d577940`. All 2,212 literal input sources
were verified byte-for-byte against that commit. It retains 322 production
closure hashes, selected original ABI entries and twenty-three original source
texts for independent preimage tests. Verify without compiling Solidity:

```sh
node scripts/generate-current-artist-operation-fixture.mjs \
  /path/to/abi-input.json /path/to/abi-output.json --check
```

The additive attestation fixture uses `parallel-feature-batch56-20260920` at
`ed4d557246a98698167d6986bc4266d9e375d558`, with all 2,241 input sources verified
against Git. It retains 81 ABI entries in 26 selections, 368 closure hashes and
12 source texts. The original ABI52 fixture remains unchanged. Check against
the retained ABI56 input/output:

```sh
node scripts/generate-current-artist-attestation-fixture.mjs \
  /path/to/abi-input.json /path/to/abi-output.json --check
```

These are client encoding, mocked RPC and source/ABI checks. They do not establish
deployed Artist or Safe execution, gas acceptance, completed ceremonies, genesis
readiness or release readiness. The remaining register entries and variants are
explicitly pending; ART39 is not complete.
