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

`currentTypedDataFromJSON` accepts these four kinds and the two custody-rights
activation kinds described below, with
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
include explicit signature bytes. Direct execution requires `"0x"` and the actual
authorized account as caller, including a Safe. Relayed EOA or ERC-1271 proofs
are opaque; a contract wallet may admit an empty proof from a distinct caller.

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

## Activate and settle current custody rights

Two additional approval helpers preserve the separate contract domains:
`tokenProfileCustodyActivationTypedData` for token PROFILE and
`custodyRightsActivationTypedData` for default PROFILE and token or default TEMPLATE modes.
Both bind the original auction, acquisition origin, actual token, initial terms,
Artist, nonce and deadline. The latter also binds `rightsMode` (1 default PROFILE,
2 strict token template, 3 consent-qualified token template, 4 dynamic token
template; 5/6/7 the corresponding default TEMPLATE modes).

`prepareCustodyActivation` returns the approval payload, unsigned activation CALL
and digest CALL. Supply both platform and Artist signatures, including opaque
ERC-1271 Safe signature bytes. The configured poster must send the transaction;
an empty signature does not grant direct-authority approval. Before signing,
check the current house with `assertCustodyActivationDigest`. Then convert the
prepared call using `toSafeCall` and simulate from the actual poster Safe.

Use `prepareCustodyBid` and `prepareCustodySettlement` with the same explicit
activation kind. The bid preserves the exact native amount. For signed bids,
use `nativeAuctionBidTypedData` with the activated configuration hash and the
corresponding `bidSignedTokenProfileCustody` or `bidSignedCustodyRights` selector
in the generated current client. Check `requireSafeExecution` on the receipt.

These helpers do not reserve a nonce or establish current auction eligibility.
The new custody tests compare exact compiler-generated interfaces and Solidity
hash preimages; actual getter runtime and full Safe workflow acceptance remain
part of consolidated integration testing. The earlier four native getter
fixtures retain their distinct executed evidence.

## Prepare native immediate sales and reveal refunds

Use `nativeFixedPriceSaleTypedData` or `nativePriceProgramTypedData` for the
current immediate adapter. These use separate domains and match its
`authorizationDigest` and `priceProgramAuthorizationDigest` getters. The
strict `currentTypedDataFromJSON` boundary also accepts both kinds.

Read `readImmediateSaleRevealQuote(provider, adapter, saleId)` for the live
policy, SLO and fee. Supply a separate allowance: a fee update within that
allowance changes the eventual refund without changing the sale signature.
For price programs, `saleAmount` is the buyer's chosen price; the signed
`unitPrice` remains the minimum that the contract checks against its live band.

```typescript
const prepared = prepareNativeImmediateSale(
  "nativePriceProgram", chainId, adapter, authorization,
  { tokenData, platformSignature, artistSignature,
    saleAmount: 777n, revealFeeAllowance: 20n },
);
await assertNativeImmediateSaleDigest(provider, prepared);
const safeTransaction = toSafeCall(prepared.call); // CALL, value "797"
```

The actual payer must also be the executor and send the transaction. Signatures
remain opaque ERC-1271-compatible bytes. The helper verifies data hashing and
encoding; simulate against the actual current host for timing, consent, price
band and caller eligibility. The final fee comes from the purchase transaction,
not the earlier quote. These helpers target native sales, not ERC-20 funding.

`prepareImmediateSaleRefund(adapter, saleId, recipient)` produces a zero-value
CALL for the credited payer's Safe. A rejected destination preserves the credit
for retry; adapter pause does not prevent withdrawal. The new six client tests
compare compiler-selected interfaces and independent Solidity type preimages;
actual current getter/runtime acceptance remains part of the combined contract
validation. See the [native immediate-sale guide](../../docs/native-immediate-reveal.md).

## Prepare current script and media manifests

`prepareScriptManifest` and `prepareMediaManifest` accept the complete typed
records and return the Router write plus its exact content-state preview call.
Integer fields use `bigint`; source types retain the Solidity enum values 0–8.
An external hash of zero remains an absent commitment. These helpers do not
fetch media or infer hashes from URIs, and encoding a descriptor does not mean
the current contract supports its execution profile.

```typescript
const manifest = prepareScriptManifest(router, collectionId, scriptManifest);
const newStateHash = await readManifestContentState(provider, manifest);
const approval = prepareManifestContentConsent(
  chainId, artistRegistry, core, manifest, newStateHash,
  { nonce, deadline, signature: "0x" },
);
await assertCurrentArtistDigest(provider, approval);
const artistTransaction = toSafeCall(approval.call);
// Confirm this transaction from the actual Artist authority Safe first.
const metadataTransaction = toSafeCall(manifest.call);
// Submit through the Router's authorized caller, which may be a different Safe.
```

The Artist approves the Router's previewed content-family state, not the raw
script hash or the manifest record hash. `prepareManifestContentConsent` keeps
the original operation-17 signing domain and includes Core, Router, collection,
family, state, nonce and deadline. Empty signature with the actual Artist as
caller selects direct execution. Relayers supply the Artist's EOA or ERC-1271
proof, which may be empty when the contract wallet admits it. Use
`assertCurrentArtistDigest` before signing and simulate each call from its actual
sender. A successful encoding or digest comparison does not reserve a nonce,
prove authority, or permit bypassing content locks. Both prepared transactions
use zero-value Safe CALL, and `requireSafeExecution` checks the corresponding
Safe result after submission.

The caller supplies the verified deployment and chain. Preview reads accept an
optional `blockTag`; refresh state if it changed before consent or execution.
Five client cases compare the six actual compiler-generated call interfaces,
the original Solidity content-consent preimage, full-width integers, absent
hashes and direct/relayed Safe preparation. These are client encoding checks;
full current-stack workflow acceptance remains separate. See the
[manifest profile](../../docs/collection-manifest-profile.md) for implemented
contract profiles and outstanding larger-script work.

## Current caller extensions

- [Current Artist operation callers](docs/current-artist-operation.md) add five
  original principal calls with pinned authority, replay, simulation and receipt review;
  the [coverage register](docs/current-artist-operation-coverage.json) tracks all 61 operations and variants.
- [Complete reference environment preparation](docs/current-reference-environment.md)
  retains original typed identities and canonical bytes after both full file inventories.
- [Current split profiles and clone wallets](docs/current-split-factory.md) bind
  each factory's implementation, preserve profile identity and verify lazy deployment.
- [Reference file-inventory preparation](docs/current-reference-inventory.md)
  preserves original inventory identities through fixed 64-row parts, pinned
  progress reads, gas quotes and separate uploader/preparer Safe calls.
- [ERC20 paid burn-to-mint](docs/current-erc20-burn-mint.md) joins ordered source
  burns, original universal signatures and token payment; its [Safe calls](docs/current-erc20-burn-mint-safe.md)
  retain separate payer, executor and NFT-owner authority.
- [ERC20 primary offers](docs/current-erc20-primary-offer.md) preserve original
  Sales signatures and separate token-payer consent; [Safe calls](docs/current-erc20-primary-offer-safe.md)
  cover all user-entry writes with zero native value.
- [Ordered Safe CALL plans](docs/safe-call-plans.md) preserve every supplied
  state-changing selector, actual caller, value and readable arguments.
- [Metric supplement bytes](docs/current-reference-metric.md) retain original
  source, runtime and replay identities; the [publication workflow](docs/current-reference-metric-workflow.md)
  stages permissionless uploads before writer publication and receipt readback.
- [Exact TEMPLATE CLEAR/FREEZE](docs/exact-template-mutations.md) covers original
  Artist approval, independent assignment reconstruction and owner installation.
- [Artist ceremony packets](docs/current-artist-ceremony.md) disclose all signed
  fields for eight supported families and check their digest and replay lane.
- [Declared PLATFORM auctions](docs/current-platform.md) prepare families 8–13
  with separate signing domains, exact custody funding and dedicated token-rights calls.
- [Royalty economic continuity](docs/current-royalty-continuity.md) reconstructs
  protected inventories and manifests, then prepares bounded import and completion calls.
- [Mint counter profiles and continuity](docs/current-mint-continuity.md) produce
  reviewed inventory manifests and prepare bounded definition, ancestry and state imports.
- [Mint Manager fallback ceremony](docs/current-mint-fallback.md) prepares
  retirement, genuine accounting imports and delayed activation or incident recovery.
- [Mint gate inputs](docs/current-mint-gates.md) produce ticket signing packets,
  delegated vault requests and canonical static allowlist proofs and commitments.
- [Operator distributions](docs/current-distribution.md) preserve ordered artwork
  manifests, prepare committed slices and recover retained beneficiary NFTs.
- [Burn-to-mint calls](docs/current-burn-mint.md) check source ownership and gate
  approval, prepare free or native purchases and recover free-burn fee credits.
- [Burn program closure warnings](docs/current-burn-finality.md) join bounded
  program histories to source and target collections before burn blocks or finality.
- [Collection token inventory recovery](docs/current-collection-inventory.md)
  scans allocation gaps, preserves actual serials and checks saved-prefix membership.
- [Native allowlist prices](docs/current-native-allowlist-price.md) prepare explicit
  price policies and proof-bearing purchases with the original signing domain.
- [Native Dutch allowlists](docs/current-native-allowlist-dutch.md) preserve signed
  maxima, apply leaf ceilings to the schedule and recover payer excess credits.
- [Native clearing allowlists](docs/current-native-allowlist-clearing.md) require
  exact signed proof prices and retain the original rebate and supplement calls.
- [Native refund-window allowlists](docs/current-native-allowlist-refund.md) capture
  exact proof prices while preserving original public-price signatures and windows.
- [Stored refund purchases](docs/current-refund-purchase-record.md) verify saved
  prices, exact proofs and immutable commitments through later terminal outcomes.
- [Curated manifests](docs/current-curated-content.md) preserve complete publication
  bytes, ordered proofs and original sale, content and purchase identities.
- [Curated fixed sales](docs/current-curated-fixed.md) prepare PUBLIC purchases,
  commit/reveal deposits and separate deposit-refund and excess-credit claims.
- [Curated private sales](docs/current-curated-private.md) retain original Sales
  signatures, buyer-bound execution and historical Manager/Ledger revocation.
- [Primary offer signatures](docs/current-primary-offer-signing.md) preserve the
  original full buyer offer and seller authorization with separate replay keys.
- [Primary offer workflows](docs/current-primary-offer.md) prepare native payments
  from the actual executor, buyer refunds, historical revocation and Safe CALLs.
- [Selected-work offer manifests](docs/current-primary-offer-content.md) verify
  complete publication bytes and the distinct primary-offer gate capability.
