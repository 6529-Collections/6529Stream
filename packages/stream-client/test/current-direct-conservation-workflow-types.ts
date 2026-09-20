import type { Provider } from 'ethers';
import type { Address, Hex } from '../src/generated/contracts.js';
import type { DirectConservationCall } from '../src/current-direct-conservation.js';
import {
  captureDirectConservation,
  simulateDirectConservation,
  reconcileDirectConservationReceipt,
  inspectDirectConservationFloorHistory,
  inspectDirectConservationReceipt,
  type DirectConservationCapture,
  type DirectConservationDeployment,
  type DirectConservationAuctionCreation,
  type DirectConservationTransactionReceipt
} from '../src/current-direct-conservation-workflow.js';

declare const provider: Provider;
declare const deployment: DirectConservationDeployment;
declare const prepared: DirectConservationCall;
declare const capture: DirectConservationCapture;
declare const hash: Hex;
declare const address: Address;
declare const creation: DirectConservationAuctionCreation;

void captureDirectConservation(provider, deployment, prepared, { blockTag: 10 });
void simulateDirectConservation(provider, capture, { blockTag: 11, gasLimit: 5_000_000n });
void reconcileDirectConservationReceipt(provider, capture, hash, { execution: 'direct' });
void reconcileDirectConservationReceipt(provider, capture, hash, {
  execution: 'safe', expectedSafeTxHash: hash, auctionCreation: creation, releaseKey: hash
});
void inspectDirectConservationFloorHistory(provider, {
  chainId: 1n, core: address, floor: deployment.product, key: hash
}, { blockTag: 20, releaseKey: hash });
void inspectDirectConservationReceipt(provider, {
  chainId: 1n, product: deployment.product, authorizationId: hash
}, { blockTag: 20 });

async function outputs(): Promise<void> {
  const result = await simulateDirectConservation(provider, capture, { blockTag: 11, gasLimit: 5_000_000n });
  const token: bigint | null = result.tokenId;
  const receipt: DirectConservationTransactionReceipt = await reconcileDirectConservationReceipt(provider, capture, hash, { execution: 'direct' });
  const amount: bigint | undefined = receipt.paidReceipt?.amount;
  const beneficiary: Address | undefined = receipt.floorHistory?.receipt.sale.beneficiary;
  void [token, amount, beneficiary];
  // @ts-expect-error Receipt outputs are immutable.
  receipt.outcome = 'paid';
  // @ts-expect-error Saved runtime pins are immutable.
  capture.deployment.core.codeHash = hash;
  // @ts-expect-error An unpaid receipt has no guaranteed paid tuple.
  const guaranteedAmount: bigint = receipt.paidReceipt.amount;
  void guaranteedAmount;
}
void outputs;
// @ts-expect-error Independent Safe hash is required.
void reconcileDirectConservationReceipt(provider, capture, hash, { execution: 'safe' });
// @ts-expect-error Explicit simulation gas is required.
void simulateDirectConservation(provider, capture, { blockTag: 11 });
// @ts-expect-error Moving block labels cannot pin observations.
void captureDirectConservation(provider, deployment, prepared, { blockTag: 'latest' });
// @ts-expect-error Numeric payment/gas values are not accepted.
void simulateDirectConservation(provider, capture, { blockTag: 11, gasLimit: 5000000 });
// @ts-expect-error No delegatecall receipt transport exists.
void reconcileDirectConservationReceipt(provider, capture, hash, { execution: 'delegatecall' });
