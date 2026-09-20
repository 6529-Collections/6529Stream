import type { Provider } from "ethers";
import type { Address, Hex } from "../src/generated/contracts.js";
import {
  captureCollectionInventory, prepareCollectionInventoryAppend, prepareCollectionInventoryScan,
  simulateCollectionInventoryOperation, inspectCollectionInventoryPrefixMember,
  inspectCollectionInventoryOperationReceipt, type CollectionInventoryDeployment,
  type CollectionInventoryCapture, type PreparedCollectionInventoryOperation,
} from "../src/current-collection-inventory-workflow.js";
import { toSafeCall } from "../src/safe.js";
declare const provider: Provider;
declare const deployment: CollectionInventoryDeployment;
declare const captured: CollectionInventoryCapture;
declare const caller: Address;
declare const transactionHash: Hex;
void captureCollectionInventory(provider, deployment, 9n, { blockTag: 50 });
const append = prepareCollectionInventoryAppend(captured, caller, [10n, 11n]);
const scan = prepareCollectionInventoryScan(captured, caller, 256n);
const operations: readonly PreparedCollectionInventoryOperation[] = [append, scan];
for (const operation of operations) {
  const zero: 0 = toSafeCall(operation.call).operation; void zero;
  void simulateCollectionInventoryOperation(provider, operation, { blockTag: 51 });
  void inspectCollectionInventoryOperationReceipt(provider, operation, { transactionHash, execution: "safe" });
}
void inspectCollectionInventoryPrefixMember(provider, captured, { collectionSerial: 20n, blockTag: 51 });
// @ts-expect-error The actual Core serial is separate from an ordinal parameter.
void inspectCollectionInventoryPrefixMember(provider, captured, { ordinal: 0n, blockTag: 51 });
// @ts-expect-error Caller and submitted integer fields are exact bigint values.
prepareCollectionInventoryScan(captured, caller, 256);
// @ts-expect-error Caller chooses a concrete pinned block, not a moving tag.
void captureCollectionInventory(provider, deployment, 9n, { blockTag: "latest" });
// @ts-expect-error Core identities and historical checkpoint evidence are immutable.
captured.checkpoint.lastIndexedSerial = 1n;
// @ts-expect-error An append does not have a bounded-scan argument.
const maximum = append.maxScan;
void maximum;
// @ts-expect-error Completeness is a current observation, never an invented collection-finality property.
const finalized = captured.finalized;
void finalized;
