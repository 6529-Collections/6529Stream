import type { Provider } from "ethers";
import type { Address, Hex } from "../src/generated/contracts.js";
import { prepareArtistPersonhoodCall } from "../src/current-artist-personhood.js";
import {
  captureArtistPersonhood,
  inspectArtistPersonhood,
  reconcileArtistPersonhoodReceipt,
  simulateArtistPersonhood,
  type ArtistPersonhoodCapture,
  type ArtistPersonhoodDeployment,
  type ArtistPersonhoodReceiptReader,
} from "../src/current-artist-personhood-workflow.js";

declare const provider: Provider;
declare const receiptProvider: ArtistPersonhoodReceiptReader;
declare const deployment: ArtistPersonhoodDeployment;
declare const capture: ArtistPersonhoodCapture;
declare const address: Address;
declare const hash: Hex;

const prepared = prepareArtistPersonhoodCall({
  chainId: 1n,
  registry: address,
  core: address,
  caller: address,
  collectionId: 1n,
  reference: {
    version: 1n,
    profileHash: hash,
    artistRegistry: address,
    artistId: hash,
    operativeIdentityRecordHash: hash,
    notarizationHost: address,
    notarizationRuntimeHash: hash,
    notarizationRecordHash: hash,
  },
  nonce: 0n,
  signedAt: 0n,
  signature: "0x",
  statementURI: "ipfs:personhood",
});

void captureArtistPersonhood(provider, deployment, prepared, { blockTag: 100 });
void simulateArtistPersonhood(provider, capture, { blockTag: 101, gasLimit: 5000000n });
void reconcileArtistPersonhoodReceipt(receiptProvider, capture, hash, { execution: "direct" });
void reconcileArtistPersonhoodReceipt(receiptProvider, capture, hash, {
  execution: "safe",
  expectedSafeTxHash: hash,
});
void inspectArtistPersonhood(provider, {
  chainId: 1n,
  attribution: deployment.artist.components[4]!,
}, { method: "personhoodEvidence", collectionId: 1n, artistId: hash }, {
  blockTag: 103,
  gasLimit: 5000000n,
}).then(result => {
  const status: bigint | undefined = result.selection?.status;
  const immutableHash: Hex = result.summaryHash;
  void status;
  void immutableHash;
});

// @ts-expect-error Concrete block numbers are required.
void captureArtistPersonhood(provider, deployment, prepared, { blockTag: "latest" });
// @ts-expect-error Simulation requires explicit gas.
void simulateArtistPersonhood(provider, capture, { blockTag: 101 });
// @ts-expect-error Gas values use bigint.
void simulateArtistPersonhood(provider, capture, { blockTag: 101, gasLimit: 5000000 });
// @ts-expect-error Safe receipt verification requires an independently supplied hash.
void reconcileArtistPersonhoodReceipt(receiptProvider, capture, hash, { execution: "safe" });
// @ts-expect-error Delegatecall is not an ordinary Safe CALL receipt.
void reconcileArtistPersonhoodReceipt(receiptProvider, capture, hash, { execution: "delegatecall" });
// @ts-expect-error A reviewed capture is not a free-form call.
void simulateArtistPersonhood(provider, prepared, { blockTag: 101, gasLimit: 5000000n });
// @ts-expect-error The pinned suite is immutable.
capture.deployment.artist.components.push(deployment.artist.registry);
// @ts-expect-error The original request nonce is immutable.
capture.prepared.request.nonce = 1n;
// @ts-expect-error The captured owner snapshot is immutable.
capture.owners[0]!.snapshot.revision = 1n;
void inspectArtistPersonhood(provider, { chainId: 1n, attribution: deployment.artist.components[4]! }, {
  // @ts-expect-error Current status methods require a subject, not a record key.
  method: "personhoodEvidence", nativeRecordHash: hash,
}, { blockTag: 103, gasLimit: 5000000n });

void simulateArtistPersonhood(provider, capture, { blockTag: 101, gasLimit: 5000000n }).then(result => {
  const exactRecord: Hex = result.recordHash;
  const noStandaloneGasClaim: false = result.nestedGasEquivalenceClaimed;
  void exactRecord;
  void noStandaloneGasClaim;
  // @ts-expect-error Simulation results are immutable.
  result.gasLimit = 1n;
});

void reconcileArtistPersonhoodReceipt(receiptProvider, capture, hash, { execution: "direct" }).then(result => {
  const historicalOnly: false = result.currentnessClaimed;
  void historicalOnly;
  // @ts-expect-error Receipt summaries are immutable.
  result.summary.generation = 3n;
  // @ts-expect-error Original Archive snapshots are immutable.
  result.after[2]!.revision = 4n;
});
