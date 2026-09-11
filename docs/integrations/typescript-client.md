# Use the TypeScript client

The [client package](../../packages/stream-client/README.md) gives applications
typed calls and EIP-712 payloads for the current native sale, ERC-20 sale, artist
acceptance and auction contracts. It uses the exact retained current ABIs. Full
Artist V2, universal settlement and finality recovery are outside this package.

## Build and connect

Install and build the package independently of the Solidity workflow:

```sh
npm --prefix packages/stream-client ci --ignore-scripts
npm --prefix packages/stream-client test
```

Node.js 22 or newer is required. On Windows PowerShell, `npm.cmd` is also
available if the shell's npm script policy prevents running `npm`.

Provide an ethers `Provider` and public deployment configuration. The package
does not select an RPC service, connect a wallet, load keys or publish a package.

```typescript
import { BrowserProvider } from "ethers";
import { StreamClient, stackConfigFromJSON } from "@6529/stream-client";

// walletProvider is the EIP-1193 provider supplied by your application.
// deployment is a caller-reviewed JSON object from your actual deployment.
const provider = new BrowserProvider(walletProvider);
const client = new StreamClient(provider, stackConfigFromJSON(deployment));
await client.assertChain();
const artist = await client.read("artistRegistry", "acceptedArtist", [collectionId]);
const policy = await client.read("manager", "phasePolicyHash", [collectionId, phaseId]);
```

For a local package dependency, point your app's package manager at
`packages/stream-client` and build it first. There is no registry release to
install. Without a package dependency, import its built `dist/index.js` directly.

The configuration shape is `{ schemaVersion: 1, chainId: "31337", addresses }`.
`addresses.core` is required. Other keys are `manager`, `nativeSale`, `erc20Sale`,
`auction`, `artistRegistry`, `entropy`, `splitFactory`, `splitWallet`,
`primaryRevenue`, `assetPolicy` and `executor`. Include each address before using
that contract. Split wallets vary by profile; calls can supply an explicit wallet
address. RPC URLs and wallet credentials do not belong in this configuration.

Chain checking prevents accidental use of another chain. It does not prove that
the supplied addresses are the correct deployment, that their code matches the
export, or that an RPC server is honest. Verify the deployment through its
retained bytecode/source evidence before configuring an application.

## Build and sign exact payloads

All TypeScript integer inputs are `bigint`, including token IDs, prices,
deadlines and signer epochs. JSON integers must be decimal strings. This avoids
silently rounding values above JavaScript's safe integer range.

```typescript
import { nativeSaleTypedData } from "@6529/stream-client";

const payload = nativeSaleTypedData(
  client.config.chainId, client.address("nativeSale"), authorization,
);
await client.assertDigest(payload, "nativeSale", "authorizationDigest", [authorization]);
const platformSignature = await platformWallet.signTypedData(
  payload.domain, payload.types, payload.message,
);
const artistSignature = await artistWallet.signTypedData(
  payload.domain, payload.types, payload.message,
);
const call = client.prepare("nativeSale", "buy", [
  authorization, tokenData, platformSignature, artistSignature,
], { value: authorization.price });
await client.simulate(call, authorization.payer);
// This explicit application action prompts the payer's wallet and submits.
const tx = await payerWallet.sendTransaction(client.transaction(call));
```

Use `signTypedData`; `signMessage` produces a different signature. Payload
construction verifies field names, order, widths and domain encoding. It does
not mean the sale is currently authorized, that a nonce is unused, or that
balances, allowances, policy, timestamp and receiver behavior will permit it.
Read the live state and simulate with the **actual submitting address**, signature
bytes and value. State can change between simulation and mining.

| Helper | Signers and purpose |
| --- | --- |
| `nativeSaleTypedData` | Platform and accepted artist authorize one native purchase |
| `erc20SaleTypedData` | Platform and accepted artist authorize the registered ERC-20 sale terms |
| `paymentIntentTypedData` | Payer authorizes asset, maximum amount, canonical sale ID and primary policy |
| `paymentIntentRevocationTypedData` | Payer revokes a nonce through a relayer |
| `artistAcceptanceTypedData` | Nominated artist accepts Core, collection and exact nomination |
| `auctionTypedData` | Platform and accepted artist authorize auction creation |

The ERC-20 sale and payment intent share the deployed adapter's
`6529StreamPaymentIntentVerifier` domain, but have different primary types and
separate artist/payer nonce spaces. `saleRef` is the canonical `saleId`, not the
config hash or authorization digest. The payer approves the **adapter** as token
spender separately; the client never sends an unlimited token approval.

Artist acceptance is immutable and must happen before the first mint or
collection freeze. A relayer can pay gas without becoming the artist. Nomination
alone does not authorize a sale. The current registry does not implement signer
rotation, collaborators or estate recovery.

For ERC-1271 wallets, use the wallet's actual signing integration and simulate
its opaque signature bytes. EOA recovery is not a contract-wallet validity test.
The general `prepare` API accepts those bytes; the examples require a compatible
caller-supplied ethers Signer abstraction. The contract's actual signature gas
budget remains authoritative.

## Read receipts and continue a flow

```typescript
const receipt = await tx.wait();
if (!receipt) throw new Error("No receipt");
const settled = client.uniqueEvent(receipt, "nativeSale", "NativeSaleSettled");
// Compare its digest, profile and amount to your approved terms before displaying success.
const tokenId = settled.args.tokenId as bigint;
const owner = await client.read("core", "ownerOf", [tokenId]);
const metadata = await client.read("core", "tokenURI", [tokenId]);
```

The decoder requires a successful receipt and the exact configured emitter. It
rejects a missing or duplicated matching event. Your app still checks business
identifiers, confirmations and reorgs. A token counter or the first same-named
event in a receipt is not proof of your purchase.

`examples/` contains complete native purchase, ERC-20 purchase, relayed artist
acceptance and auction-creation functions. They verify the relevant receipt and
ownership before returning outputs. Call them only after the user reviews and
authorizes the operation; importing them does not submit anything.

A validation error after `sendTransaction` does not undo a mined transaction.
Record the submitted transaction hash in your application's journal and inspect
the receipt before retrying. Each example accepts a final optional
`{ onSubmitted: async (hash) => { /* persist hash */ } }` argument, called before
waiting for the receipt. Recipient contracts may move the NFT during receipt
callbacks, so an ownership postcondition can fail after a successful purchase.

Auction creation escrows a newly minted NFT. Subsequent bids, refunds and
delivery recovery remain explicit actions:

```typescript
const minimum = await client.read("auction", "minimumBid", [tokenId]);
const bid = client.prepare("auction", "bid", [tokenId, recipient], { value: minimum });
const refund = client.prepare("auction", "withdrawRefund", [refundRecipient]);
const changeRecipient = client.prepare("auction", "setDeliveryRecipient", [tokenId, replacement]);
const settle = client.prepare("auction", "settle", [tokenId]);
```

Simulate and submit each action with the correct wallet. The highest bidder
controls delivery changes; refunds belong to the bidder. Settlement may create
a pending no-bid claim instead of delivering an NFT. See the
[auction lifecycle](auction-flows.md) before reporting delivery as complete.

## Offline JSON and digest checks

To prepare a payload without a network, write a JSON object with exactly `kind`,
`chainId`, `verifyingContract` and `message`. `kind` is `nativeSale`, `erc20Sale`,
`paymentIntent`, `paymentIntentRevocation`, `artistAcceptance` or `auction`.
Run:

```sh
npm --prefix packages/stream-client run example -- /absolute/path/request.json
```

The output has `domain`, `types`, `primaryType`, `message` and `digest`. Give
wallets the domain, types and message; the digest is for comparison. No signature
is collected. For raw `eth_signTypedData_v4`, pass `--rpc` before the input path
or call `walletTypedData(payload)`. This adds the canonical `EIP712Domain` type
and produces the complete JSON-RPC wallet representation; do not pass that
extra domain type back into ethers `signTypedData`.

`npm run parity -- config.json requests.json`, from the package
directory with `STREAM_RPC_URL` set privately, compares an array of requests to
the actual deployed digest methods using read-only calls.

`npm run generate:check` validates generated ABIs and TypeScript types against
the current export's file hashes and compiler input. Six retained local onchain
vectors pin domain/field encoding in offline tests. This is integration evidence,
not audit credit, public deployment evidence or a proof of full-v1 conformance.

## Capture and verify supported state

The client can capture a verifiable package of current **public getter results**
at one explicit past block. Select up to 32 collections, 32 tokens, 64 registered
ERC-20 sale IDs and 64 mint phases. Token, sale and phase selections must also
include their collection IDs. There is no implicit event crawl or claim that an
omitted collection has no activity.

Save a selection JSON with decimal-string IDs:

```json
{
  "blockNumber": "365",
  "collectionIds": ["2"],
  "tokenIds": ["2", "3", "4"],
  "saleIds": [],
  "phases": []
}
```

Those are format examples, not chain/deployment defaults. For a sale or phase,
provide its exact bytes32 ID. The configuration must include Core, manager,
native sale, ERC-20 sale, auction, artist registry, entropy and Executor.
Optional configured split/revenue/asset addresses are checked against the
observed bindings when those getters exist.

Set `STREAM_RPC_URL` privately for capture/readback. Do not commit or print a
credentialed endpoint. From the package directory:

```sh
npm run snapshot -- capture config.json selection.json /absolute/path/new-snapshot
npm run snapshot -- verify /absolute/path/new-snapshot
npm run snapshot -- inspect /absolute/path/new-snapshot
npm run snapshot -- readback config.json /absolute/path/new-snapshot
```

The output directory must not already exist. Capture writes three fixed files:

| File | Contents |
| --- | --- |
| `snapshot.json` | Chain/block identity, exact client ABI/compiler provenance, explicit coverage and selection, observed code hashes, raw ABI returns and decoded facts |
| `manifest.json` | The relative `snapshot.json` reference, byte count, SHA-256 and export hash, chain/block and compilation identity |
| `publication.json` | The four block/hash arguments used by `publishStateExport`, before the caller adds a manifest URI |

Canonical format v1 sorts object keys, preserves array order, writes UTF-8 with
no insignificant whitespace or final newline, and represents protocol integers
as decimal strings. Selections are sorted before capture. `exportHash` is
Keccak-256 of the exact `snapshot.json` bytes. `manifestHash` is Keccak-256 of
the exact `manifest.json` bytes. Do not pretty-print these files before hosting:
that changes their hashes. `inspect` prints a readable decoded view without
rewriting the canonical files.

The fixed coverage includes Core's twelve current stored pointer families and
allocation/supply counters; selected collection status, supply, burns/freeze,
artist attribution and entropy configuration; selected token identity and data;
rendered metadata; registered ERC-20 sale configuration and current primary
policy; and selected mint-phase policy/configuration. Configured sale and auction
signer/pause/accounting reads are also retained. It deliberately excludes full
role, replay and credit mappings, individual auction/refund history, all counter
subjects, unselected state, and offchain content availability. The complete
coverage and exclusions are embedded in every snapshot and checked offline.

Burned and prepared-incomplete tokens retain their identity and stored bytes.
The package explicitly marks `ownerOf` and `tokenURI`
unavailable for those lifecycle states; it does not call them and hide a revert.
Core assigns the entropy coordinator during completion, so a prepared token with
a zero coordinator also explicitly omits the two coordinator getters. Burned
tokens retain their coordinator and entropy observations.
For every other supported getter, an unexpected failure aborts capture. Tokens
use their stored **coordinator at mint**, including an older compatible
coordinator, rather than substituting the current entropy pointer.

The snapshot API requires a JSON-RPC provider exposing `send(method, params)`;
the CLI supplies an ethers `JsonRpcProvider`. It uses fresh raw JSON-RPC reads
for headers, chain identity, calls and code, bypassing ethers' short-lived
high-level provider cache. Each call and code read uses the selected block number. Capture checks the
canonical block hash before and after the bounded reads; a detected reorg aborts
it. A historical block may require an archive-capable RPC. Getter calls use a
16-million gas budget and reject oversized ABI returns. An incompatible earlier
coordinator or unsupported getter requires an explicit later exporter version;
it is never represented by invented empty state.

Offline verification checks the exact schema, canonical bytes, ABI decoding,
fixed read inventory, expected dependency bindings, selection, declared lifecycle
omissions, code-hash coverage and manifest/publication hashes. An attacker can
still forge a coherent package and recompute its hashes. `readback` repeats all
observations against the pinned canonical block and compares the complete
snapshot; use a trusted independent RPC for meaningful corroboration. Neither
mode proves consensus, hidden storage completeness or full protocol conformance.
Observed code hashes do not themselves prove a source-code match: the package
records the ABI/compiler identity used to decode the calls separately.

To publish the reference, host the **unaltered three files together** at a durable
reachable location so `snapshot.json` resolves relative to `manifest.json`.
Then use the fields in `publication.json` with that real manifest URI:

```typescript
const call = client.prepare("executor", "publishStateExport", [
  BigInt(publication.blockNumber), publication.blockHash,
  publication.exportHash, publication.manifestHash, manifestURI,
]);
```

The current publisher requires a recent canonical nonzero past block within
256 blocks, an active matching Core publisher pointer and the live publication
role. A valid historical snapshot can be too old to publish; capture a new one
instead of relabeling its anchor. The CLI never uploads, signs, schedules or
publishes. Hosting a package or publishing its hash does not turn it into a full
archival export or independently audited state. See the
[publisher guide](state-exports.md) for challenges, supersession and lineage.
