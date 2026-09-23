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
const authenticatedPrice: MintAllowlistLeafInput = { ...leaf, hasPriceOverride: true, priceOverride: 1n };
// @ts-expect-error the price flag must be a boolean
const invalidFlag: MintAllowlistLeafInput = { ...leaf, hasPriceOverride: 1n };
// @ts-expect-error full-width authenticated prices must be bigint
const roundedPrice: MintAllowlistLeafInput = { ...leaf, priceOverride: 1 };
void authenticatedPrice; void invalidFlag; void roundedPrice;
