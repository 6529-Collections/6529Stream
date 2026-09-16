import type { Address, Hex } from "../src/generated/contracts.js";
import type { CuratedSelection } from "../src/current-curated-content.js";
import {
  CurrentCuratedPrivateClient,
  curatedPrivateBatchHashes,
  curatedPrivateConfigurationHash,
  curatedPrivateMintTicketAuthorizationId,
  curatedPrivateMintTicketRevocationPayload,
  curatedPrivateSaleAuthorizationPayload,
  type CuratedPrivateConfiguration,
  type CuratedPrivateSaleAuthorization,
} from "../src/current-curated-private.js";

declare const address: Address;
declare const hash: Hex;
declare const configuration: CuratedPrivateConfiguration;
declare const authorization: CuratedPrivateSaleAuthorization;
declare const selection: CuratedSelection;

curatedPrivateConfigurationHash(1n, address, configuration);
curatedPrivateBatchHashes(address, address, selection);
curatedPrivateSaleAuthorizationPayload(1n, address, authorization);
const authorizationId = curatedPrivateMintTicketAuthorizationId(1n, address, authorization);
curatedPrivateMintTicketRevocationPayload(1n, address, address, address, authorizationId);

const client = new CurrentCuratedPrivateClient({} as never, 1n, address);
client.prepareRegistration(address, configuration, [hash]);
client.preparePurchase(address, {
  authorization,
  signature: { authorizer: address, kind: 1n, signature: "0x" },
  selection,
  witness: { walletWide: false, index: 0n },
  revealFeeAllowance: 0n,
});
client.prepareVoidAuthorization(address, authorization, "0x");
client.claimRefundCall(address, hash, address);
client.claimRefundForCall(address, hash, address, { walletWide: true, index: 2n });

// @ts-expect-error chain identifiers remain bigint at the public boundary
curatedPrivateConfigurationHash(1, address, configuration);
// @ts-expect-error authorizer kind remains bigint at the public boundary
client.preparePurchase(address, { authorization, signature: { authorizer: address, kind: 1, signature: "0x" }, selection,
  witness: { walletWide: false, index: 0n }, revealFeeAllowance: 0n });
