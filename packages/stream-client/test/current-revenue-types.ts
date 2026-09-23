import { CurrentRevenueClient, primaryCollaboratorSource } from "../src/index.js";
import type { Address, Hex, RevenueIntent, RevenueAuthorization, CurrentRevenueBindings, CurrentRevenueAddresses } from "../src/index.js";
const address = "0x0000000000000000000000000000000000000001" as Address;
const hash = "0x1234" as Hex;
declare const bindings: CurrentRevenueBindings;
declare const addresses: CurrentRevenueAddresses;
const client = new CurrentRevenueClient(31337n, addresses, bindings);
const token: RevenueIntent = { kind: "primary-profile", collectionId: 1n, scope: 2n, scopeId: 9007199254740993n, profileId: hash };
const disabled: RevenueIntent = { kind: "royalty-set", collectionId: 1n, scope: 1n, scopeId: 1n, profileId: hash, royaltyBps: 0n };
const auth: RevenueAuthorization = { nonce: 1n, deadline: 2n, signature: "0x" };
primaryCollaboratorSource({ account: address, role: hash, shareLabelId: hash });
client.materialize(address, 1n, hash, address, true);
// @ts-expect-error unsafe number cannot replace a uint256 bigint
const badToken: RevenueIntent = { ...token, scopeId: 9007199254740993 };
// @ts-expect-error fixed profile preview has no global Artist scope
const badScope: RevenueIntent = { kind: "primary-profile", collectionId: 1n, scope: 0n, scopeId: 0n, profileId: hash };
// @ts-expect-error original row role is bytes32, not an integer or payout address
primaryCollaboratorSource({ account: address, role: 0n, shareLabelId: hash });
// @ts-expect-error original poster is required, never inferred from caller
client.materialize(address, 1n, hash, true);
// @ts-expect-error original authorization nonce is full-width bigint
const badAuth: RevenueAuthorization = { ...auth, nonce: 1 };
void disabled; void badToken; void badScope; void badAuth;
const clear: RevenueIntent = { kind: "primary-template-clear", collectionId: 1n, scope: 2n, scopeId: 2n, templateId: hash };
const freeze: RevenueIntent = { kind: "primary-template-freeze", collectionId: 1n, scope: 1n, scopeId: 1n, templateId: hash };
// @ts-expect-error exact-template mutations never authorize global/default scope
const globalFreeze: RevenueIntent = { ...freeze, scope: 0n, scopeId: 0n };
// @ts-expect-error a reviewed template ID is required for a clear intent
const unknownTemplate: RevenueIntent = { kind: "primary-template-clear", collectionId: 1n, scope: 2n, scopeId: 2n };
void clear; void freeze; void globalFreeze; void unknownTemplate;
