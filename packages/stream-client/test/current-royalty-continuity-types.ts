import {
  CurrentRoyaltyContinuityClient, royaltyContinuityRouteHash, royaltyContinuityManifestBytes,
} from "../src/current-royalty-continuity.js";
import type {
  RoyaltyContinuityBindings, RoyaltyContinuityDeployment, RoyaltyContinuityRoute,
  RoyaltyContinuityHeader, RoyaltyContinuityManifestBody,
} from "../src/current-royalty-continuity.js";
import type { Address, Hex } from "../src/generated/contracts.js";

declare const deployment: RoyaltyContinuityDeployment;
declare const bindings: RoyaltyContinuityBindings;
declare const route: RoyaltyContinuityRoute;
declare const header: RoyaltyContinuityHeader;
declare const body: RoyaltyContinuityManifestBody;
declare const address: Address;
declare const hash: Hex;
const client = new CurrentRoyaltyContinuityClient(1n, deployment, bindings);
royaltyContinuityRouteHash(1n, address, route);
royaltyContinuityManifestBytes(1n, address, hash, address, header, body);
client.begin({} as never);
// @ts-expect-error chain identifiers are full-width bigint values
new CurrentRoyaltyContinuityClient(1, deployment, bindings);
// @ts-expect-error capture bounds are bigint and never rounded JS numbers
client.capture({} as never, "ipfs://manifest", { maxRoutes: 16, maxElections: 64n });
// @ts-expect-error route scope IDs preserve full-width uint256 values
const roundedRoute: RoyaltyContinuityRoute = { ...route, scopeId: 9007199254740993 };
// @ts-expect-error canonical manifest body has no caller-supplied content hash
const circularManifest: RoyaltyContinuityManifestBody = { ...body, contentHash: hash };
void roundedRoute; void circularManifest;
