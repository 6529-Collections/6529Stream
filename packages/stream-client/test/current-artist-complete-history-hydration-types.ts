import {
  encodeArtistCompleteHistoryHydrationInventory,
  decodeArtistCompleteHistoryHydrationInventory,
  encodeArtistCompleteHistoryHydrationPrincipals,
  prepareArtistCompleteHistoryHydrationCall,
  captureArtistCompleteHistoryHydration,
  simulateArtistCompleteHistoryHydration,
  reconcileArtistCompleteHistoryHydrationReceipt,
  type ArtistCompleteHistoryHydrationInventory,
  type ArtistCompleteHistoryHydrationPrincipals,
  type ArtistCompleteHistoryHydrationInput,
  type ArtistCompleteHistoryHydrationReader,
  type ArtistCompleteHistoryHydrationReceiptReader,
  type ArtistCompleteHistoryHydrationDeployment,
  type ArtistCompleteHistoryHydrationCapture,
  type ArtistCompleteHistoryHydrationNonceLane,
  type Address,
  type Hex,
} from '../src/index.js';

declare const inventory: ArtistCompleteHistoryHydrationInventory;
declare const principals: ArtistCompleteHistoryHydrationPrincipals;
declare const input: ArtistCompleteHistoryHydrationInput;
declare const reader: ArtistCompleteHistoryHydrationReader;
declare const receipts: ArtistCompleteHistoryHydrationReceiptReader;
declare const deployment: ArtistCompleteHistoryHydrationDeployment;
declare const caller: Address;
declare const registry: Address;
declare const transactionHash: Hex;
declare const safeCodeHash: Hex;
declare const safeTxHash: Hex;

const bytes: Hex = encodeArtistCompleteHistoryHydrationInventory(inventory);
const decoded: ArtistCompleteHistoryHydrationInventory = decodeArtistCompleteHistoryHydrationInventory(bytes);
const principalBytes: Hex = encodeArtistCompleteHistoryHydrationPrincipals(principals);
const account: ArtistCompleteHistoryHydrationNonceLane | undefined = decoded.accounts[0];
const collectionId: bigint | undefined = decoded.accepted[0]?.collectionId;
const kind: bigint | undefined = account?.kind;
const prepared = prepareArtistCompleteHistoryHydrationCall(registry, caller, input);
const callData: Hex = prepared.call.data;
const value: bigint = prepared.call.value;

// Compiler fields remain bigint and nested inputs remain immutable.
// @ts-expect-error uint8 fields are bigint, even for a known account nonce kind.
const wrongKind: ArtistCompleteHistoryHydrationNonceLane = { kind: 3, key: transactionHash, words: [] };
// @ts-expect-error callers cannot mutate the normalized common account inventory.
decoded.accounts.push(account);
// @ts-expect-error unsupported Class Four supplements are not invented typed fields.
principals.stewardHandoff;

async function operatorFlow(): Promise<ArtistCompleteHistoryHydrationCapture> {
  const capture = await captureArtistCompleteHistoryHydration(reader, deployment, caller, input, { blockTag: 100, gasLimit: 20_000_000n });
  const simulated = await simulateArtistCompleteHistoryHydration(reader, capture, { blockTag: 101, gasLimit: 20_000_000n });
  await reconcileArtistCompleteHistoryHydrationReceipt(receipts, simulated.capture, transactionHash, { execution: 'direct' });
  await reconcileArtistCompleteHistoryHydrationReceipt(receipts, simulated.capture, transactionHash, {
    execution: 'safe', expectedSafeTxHash: safeTxHash, nonce: 7n, safeCodeHash,
  });
  return simulated.capture;
}
void [principalBytes, collectionId, kind, callData, value, wrongKind, operatorFlow];
