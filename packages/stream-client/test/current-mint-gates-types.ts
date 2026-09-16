import type { Address, Hex } from "../src/generated/contracts.js";
import type { MintGateBatch, MintTicket, MintAllowlistLeafInput } from "../src/current-mint-gates.js";
import {
  delegateMintRequest, mintAllowlistLeaf, mintBatchHashes, mintTicketForBatch, mintTicketTypedData,
} from "../src/current-mint-gates.js";

declare const address: Address, hash: Hex;
declare const batch: MintGateBatch, ticket: MintTicket, leaf: MintAllowlistLeafInput;
mintBatchHashes(batch);
mintTicketForBatch({ chainId: 1n, manager: address, ledger: address, executor: address, authorizerKind: 2n, nonce: hash, deadline: 1n }, batch);
mintTicketTypedData(1n, address, ticket);
mintAllowlistLeaf(leaf);
delegateMintRequest(address, address, batch, address, hash);
// @ts-expect-error full-width chain identifiers must be bigint
mintTicketTypedData(1, address, ticket);
// @ts-expect-error authorizer kind must not be rounded through a JS number
mintTicketForBatch({ chainId: 1n, manager: address, ledger: address, executor: address, authorizerKind: 2, nonce: hash, deadline: 1n }, batch);
// @ts-expect-error current allowlists statically disallow price overrides
const unsupportedPrice: MintAllowlistLeafInput = { ...leaf, hasPriceOverride: true };
// @ts-expect-error current allowlists require the literal zero price
const nonzeroPrice: MintAllowlistLeafInput = { ...leaf, priceOverride: 1n };
void unsupportedPrice; void nonzeroPrice;
