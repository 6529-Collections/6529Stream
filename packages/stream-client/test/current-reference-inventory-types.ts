import type { Address, Hex } from "../src/generated/contracts.js";
import {
  normalizeReferenceInventoryRows, prepareReferenceInventory, referenceInventoryCanonicalBytes,
  referenceInventoryContentHash, referenceInventoryId, referenceInventoryPartId, referenceInventoryParts,
  type ReferenceInventoryPackageFile, type ReferenceInventorySnapshot, type ReferenceInventoryPart,
} from "../src/current-reference-inventory.js";

declare const host: Address;
declare const digest: Hex;
const rows: readonly ReferenceInventoryPackageFile[] = [{ path: "zero.bin", byteSize: 0n, sha256Digest: digest }];
const saved: ReferenceInventorySnapshot = prepareReferenceInventory(1n, host, true, rows);
const parts: readonly ReferenceInventoryPart[] = referenceInventoryParts(saved);
const byteLength: bigint = saved.byteLength;
const contentHash: Hex = referenceInventoryContentHash(rows, true);
referenceInventoryCanonicalBytes(rows, true);
referenceInventoryId(1n, host, false, rows);
referenceInventoryPartId(1n, host, false, rows);
normalizeReferenceInventoryRows(rows, true);
void byteLength; void contentHash; void parts;
// @ts-expect-error file sizes are exact uint64 bigint values
prepareReferenceInventory(1n, host, true, [{ path: "file", byteSize: 1, sha256Digest: digest }]);
// @ts-expect-error chain IDs are exact uint256 bigint values
prepareReferenceInventory(1, host, true, rows);
// @ts-expect-error mode is an explicit boolean
referenceInventoryCanonicalBytes(rows, "relative");
// @ts-expect-error rows do not contain user-selected part IDs
normalizeReferenceInventoryRows([{ path: "file", byteSize: 0n, sha256Digest: digest, partId: digest }], true);
// @ts-expect-error snapshots are immutable
saved.inventoryId = digest;
// @ts-expect-error snapshot rows are immutable
saved.rows.push(rows[0]!);
// @ts-expect-error file contents are immutable
saved.rows[0]!.path = "changed";
// @ts-expect-error derived part collections are immutable
parts.push(parts[0]!);
// @ts-expect-error part offsets are immutable
parts[0]!.rowOffset = 64;
// @ts-expect-error retained byte lengths stay bigint
const wrongByteLength: number = parts[0]!.byteLength;
void wrongByteLength;
