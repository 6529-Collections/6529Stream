# Stream client

Typed calls, receipt decoding and EIP-712 payloads for the **retained testnet RC1
export**. The ongoing v1 contracts have changed; their ABIs and signing payloads
must be exported and verified before using this client against that new stack.
This private development package is not published to npm. It contains
no wallet keys, RPC credentials, deployment defaults or automatic transactions.

From this directory, with Node.js 22 or newer:

```sh
npm ci --ignore-scripts
npm test
```

`npm run build` emits JavaScript and declarations into `dist/`. Import
`dist/index.js` from a local app, or use this directory as a local package
dependency. The only runtime dependency is ethers 6.17.0; TypeScript 5.9.3 is a
build dependency. Both are pinned in the lockfile.

See the [integration guide](../../docs/integrations/typescript-client.md) for
configuration, signing, transaction simulation, examples and limitations.

`npm run generate` projects ABI and call types from the exact retained
`release-artifacts/current` export. `npm run generate:check` verifies the
projection without writing. Generation does not compile Solidity or update
release evidence. A source export update requires reviewing the client diff and
rechecking its onchain digest vectors; the client is not a source-verification
or deployment-attestation tool.

`toSafeCall` preserves any prepared call's target, calldata and native value for
a Safe transaction builder. `requireSafeExecution` checks the expected Safe and
its independently verified transaction hash against actual execution success,
including the different event layouts in Safe 1.3.0, 1.4.1 and 1.5.0. Applications
also verify the expected Stream events and resulting state. See the
[Safe workflow](../../docs/integrations/typescript-client.md#submit-through-a-safe).

The examples are executable functions accepting caller-supplied ethers wallets:

- `examples/native-purchase.mjs`: platform and artist signatures, payer submission.
- `examples/erc20-purchase.mjs`: separate payer intent, relayer submission.
- `examples/artist-acceptance.mjs`: unfunded artist acceptance through a relayer.
- `examples/auction.mjs`: signed creation and escrow; bidding/settlement are separate.
- `examples/prepare.mjs`: offline JSON payload construction.
- `examples/check-digests.mjs`: read-only comparison against deployed digest methods.
- `examples/snapshot.mjs`: pinned-block capture, readable inspection, offline verification and chain readback.

The supported-state exporter creates a deterministic package for **explicitly
selected** collections, tokens, ERC-20 sales and mint phases. It is compatible
with the current publisher's export/manifest hash fields. It does not reconstruct
all history, expose private mappings, host files or publish a transaction. See
the [snapshot workflow](../../docs/integrations/typescript-client.md#capture-and-verify-supported-state).

The retained RC1 digest fixtures were observed on its local stack deployment.
Their addresses are encoding-vector inputs, not an address book or live launch
evidence. No test or example imports their addresses as defaults.

## Use a newer compiler catalog

`StreamClient` and the original six signing helpers retain the RC1
ABI and EIP-712 contracts. The four explicitly current auction helpers below
use their separately verified domains. For a different build, generate a separate client from
the exact compiler build-info and an explicit source/contract selection:

```sh
node scripts/generate-bindings.mjs --build-info /path/to/build-info.json --targets scripts/current-binding-targets.example.json --out /path/to/app/stream-bindings
node scripts/generate-bindings.mjs --build-info /path/to/build-info.json --targets scripts/current-binding-targets.example.json --out /path/to/app/stream-bindings --check
```

The example target list is a small current-commerce selection, not the complete
v1 call inventory. Add each required host or interface by its exact compiler
source key and contract name. An interface alias can use the same configured
address as its host; this makes fallback-routed Artist capabilities explicit.
The command requires literal compiler input and matching output ABIs. It records
the build file, target selection, source and ABI digests, then emits `abis.ts`,
`contracts.ts`, `provenance.ts` and `index.ts`. It does not compile Solidity.

Install this private package as a local dependency in the consuming app and
import `StreamClient` from the generated `index.js`. Supply that build’s actual
addresses through its `stackConfigFromJSON`; `core` and a positive decimal
`chainId` are required. Calls support typed arguments/results, overloads,
positional unnamed tuples, reads, sender-aware simulation, gas estimation and
exact-emitter receipt decoding. Pass `client.prepare(...)` to the existing
`toSafeCall` helper for an ordinary Safe CALL with unchanged target/value/data.

Each client captures its supplied ABI catalog at construction. It never falls
back to the retained RC1 ABI when a new method is absent. `--check` compares the
generated files byte-for-byte with the same selected build and target file.

Compiler provenance alone does not establish the identity of a deployed stack.
Verify source/build/deployment correspondence before using those addresses.
EIP-712 domain names, versions and semantic field layouts cannot be inferred
from an ABI: the retained signing helpers must not be reused for a new domain
without explicit implementation and onchain digest parity checks. Full-v1
signing, workflow examples and new-candidate acceptance remain in progress.

## Sign current native auctions and custody acquisitions

Use the explicitly current helpers with a separately generated current client:

| Helper | Current house digest getter |
| --- | --- |
| `nativeAuctionCreationTypedData` | `creationAuthorizationDigest` |
| `nativeAuctionBidTypedData` | `bidAuthorizationDigest` |
| `nativeCustodyAcquisitionTypedData` | `custodyAcquisitionDigest` |
| `preparedNativeCustodyAcquisitionTypedData` | `preparedCustodyAcquisitionDigest` |

All four use version `1`, the actual chain ID and the auction **house** as
`verifyingContract`. A prepared-custody interface alias must point at that same
house. Single-step and prepared custody use different domain and primary-type
names, even for identical acquisition fields. The historical `auctionTypedData`
helper remains tied to the retained RC1 auction.

```js
import { nativeAuctionCreationTypedData } from "@6529/stream-client";
const payload = nativeAuctionCreationTypedData(
  currentClient.config.chainId, currentClient.address("nativeAuction"), authorization,
);
await currentClient.assertDigest(
  payload, "nativeAuction", "creationAuthorizationDigest", [payload.message],
);
```

Get the exact configuration hash from the current house before requesting
signatures. `examples/current-auction-signing.mjs` checks the ordinary auction
configuration and the actual digest getter before returning its immutable
payload. Curated and rights configurations require their corresponding hash
getters. Signing still requires the current authority, nonce, deadline and
configuration to remain valid; payload construction alone checks encoding.

`currentTypedDataFromJSON` accepts only these four explicit current kinds, with
uint fields represented as decimal strings. It does not reinterpret retained
RC1 JSON requests. `walletTypedData` formats either kind for wallet RPC.
For Safe calls, pass the current client’s prepared transaction to `toSafeCall`
and simulate with the actual Safe sender and exact native value. Acquisitions
bind the expected sale, token, collection serial and operation nonces; prepared
acquisition cannot substitute a signature for the single-step path.

The four current fixtures call actual native-compiled digest getters on an
isolated Anvil. Their libraries are deployed normally; the linked house runtime
is installed without its constructor. These getters read only the payload,
chain and house address. This is encoding evidence, separate from lifecycle,
deployment and complete Safe workflow acceptance. The fixture records compiler
and runtime hashes, library addresses, exact calldata and returned bytes.
Recreate it from a reviewed native build with Foundry’s `anvil` on PATH:

```sh
node scripts/generate-current-signing-vectors.mjs --build-info /path/to/native-build.json --output /path/to/current-native-auction-digests.json
```

The generator starts and stops its own loopback chain and accepts no existing
RPC endpoint or signer. It requires no new Solidity compilation.

## Prepare current Artist and collaborator operations

The current Artist helpers support eight signed operations: binding acceptance,
policy consent, economics consent, payout designation, attestation, content
ratification, collaborator identity acceptance and collaborator acceptance.
They use the current `StreamArtistOnboardingRegistry` facade as the EIP-712
verifying contract, with domain name `6529StreamArtistRegistry` and version `1`.
They are separate from the retained RC1 `artistAcceptanceTypedData` helper.

`currentArtistTypedData(kind, chainId, registry, message)` creates an immutable,
wallet-readable payload. `currentArtistTypedDataFromJSON` accepts the same
explicit request shape as the current auction parser, with all integer fields
represented as decimal strings. The kinds are the keys of
`CurrentArtistSigningMessages`; TypeScript exposes every exact message field.

`prepareCurrentArtistOperation` returns the signing payload, transaction
calldata and matching digest-getter calldata together. Its submission details
include an explicit signature: `"0x"` selects direct execution by the actual
authorized account, including a Safe; a nonempty value contains the EOA or
ERC-1271 authorization bytes for a relayed call.

```js
import {
  prepareCurrentArtistOperation, assertCurrentArtistDigest, toSafeCall,
} from "@6529/stream-client";

const prepared = prepareCurrentArtistOperation(
  "artistAcceptance", chainId, artistFacade,
  {
    core, collectionId, bindingGeneration, bindingHash, identityRecordHash,
    nonce, deadline,
  },
  { signature: "0x" },
);
await assertCurrentArtistDigest(provider, prepared);
const safeTransaction = toSafeCall(prepared.call);
```

Submit that transaction through the Safe which currently holds Artist authority.
For a relayed signature, construct and review the payload first, collect the
signature with the appropriate wallet, then prepare again with those signature
bytes. Nonce and authority checks remain onchain. Read current state after each
confirmed onboarding operation; do not assume an entire multi-transaction
sequence can reserve consecutive nonces.

The usual order is registry-admin binding proposal, Artist acceptance and payout,
collaborator acceptance/designation when applicable, both primary and royalty
economics consent, content ratification and required attestations/policy consent.
Existing compiler-generated bindings expose the unsigned proposal and state
reads. Collaborator identity registration has its own nonce namespace; subsequent
collaborator operations use that identity's current authorization state.
`examples/current-artist-onboarding.mjs` prepares a direct Safe call after
checking the selected facade's digest getter.

Submission details carry the bytes that are represented by hashes in a signature:
attestations require `statementURI` and `statement`, and collaborator identity
acceptance requires `document` and `displayName`. Hash mismatches are rejected
before calldata is returned. Display names are supplied to the contract and are
not fields of the permanent collaborator identity signature. Payout and attestation
signatures use `signedAt`; the other six operations use `deadline`. An explicit
zero `signedAt` is supported only for direct execution.

Economics consent also requires an explicit submission `collectionId`. The
permanent signature binds the resolver, revenue class, scope and assignment,
while the contract separately admits and records its collection/binding
association. The helper preserves that distinction; a default consent is not
automatically reusable for another collection.

These helpers have source-preimage and compiled-ABI encoding checks.
`assertCurrentArtistDigest` checks the live chain and digest at an optional
`blockTag`, but does not establish current authorization or complete mint
eligibility. Joined onboarding and new-candidate runtime acceptance follow the
integrated feature batch.
