import type { Address, Hex } from "../src/generated/contracts.js";
import type { ReferenceInventorySnapshot } from "../src/current-reference-inventory.js";
import { normalizeReferenceEnvironment, normalizeReferenceEnvironmentSnapshot, prepareReferenceEnvironment,
  referenceEnvironmentCanonicalBytes, referenceEnvironmentId, type ReferenceEnvironment,
  type ReferenceEnvironmentSnapshot } from "../src/current-reference-environment.js";

declare const environment: ReferenceEnvironment;
declare const chainId: bigint;
declare const host: Address;
declare const hash: Hex;
const canonical: Hex = referenceEnvironmentCanonicalBytes(environment);
const identity: Hex = referenceEnvironmentId(chainId, host, environment);
const snapshot: ReferenceEnvironmentSnapshot = prepareReferenceEnvironment(chainId, host, environment);
const inventory: ReferenceInventorySnapshot = snapshot.packageInventory;
const length: bigint = snapshot.byteLength;
normalizeReferenceEnvironment(environment);
normalizeReferenceEnvironmentSnapshot(snapshot);
void canonical; void identity; void inventory; void length;

// @ts-expect-error chain coordinates require exact uint256 bigint
prepareReferenceEnvironment(1, host, environment);
// @ts-expect-error original uint32 manifest length is not a lossy number
normalizeReferenceEnvironment({ ...environment, manifestBytes: 1 });
// @ts-expect-error original uint16 viewport width is a bigint
normalizeReferenceEnvironment({ ...environment, viewportWidth: 1920 });
// @ts-expect-error original uint8 device ratio is a bigint
normalizeReferenceEnvironment({ ...environment, devicePixelRatio: 1 });
// @ts-expect-error package file lengths preserve uint64 bigint
normalizeReferenceEnvironment({ ...environment, packageFiles: [{ path: "a", byteSize: 1, sha256Digest: hash }] });
// @ts-expect-error manifest declaration is part of the original complete Environment
normalizeReferenceEnvironment({ ...environment, manifestHash: undefined });
// @ts-expect-error a caller-selected environment identity is not an original field
normalizeReferenceEnvironment({ ...environment, environmentId: hash });
// @ts-expect-error prepared snapshots do not permit replacing coverage after review
snapshot.environment.coverageHash = hash;
// @ts-expect-error copied package arrays are immutable
snapshot.environment.packageFiles.push({ path: "a", byteSize: 1n, sha256Digest: hash });
// @ts-expect-error nested inventory rows are immutable
snapshot.platformInventory.rows[0]!.path = "different";
// @ts-expect-error canonical byte preparation does not attest authority
snapshot.authorized = true;
