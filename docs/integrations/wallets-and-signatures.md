# Wallets and signatures

This is the current sale and auction signing guide. It is **pre-audit and not
production-ready**. The [legacy reference](../reference/legacy-stack/integrations/wallets-and-signatures.md)
preserves older payloads. Cross-check typed data with the deployed contract's
`authorizationDigest` and `eip712Domain`.

## Fixed-price typed data

The EIP-712 domain is `name: "6529StreamFixedPriceSale"`, `version: "1"`, the live
`chainId`, and the sale adapter's `verifyingContract`. There is no salt. Platform
and accepted artist sign the same `SaleAuthorization`. Names, order and integer
widths are significant.

```typescript
// ethers v6 in an existing application; Stream does not require a JavaScript SDK.
import { Contract, TypedDataEncoder, keccak256, randomBytes, hexlify } from "ethers";

const saleAbi = [
  "function signerEpoch() view returns (uint64)",
  "function authorizationDigest((uint256 collectionId,bytes32 phaseId,address payer,address recipient,address artist,bytes32 profileId,bytes32 tokenDataHash,bytes32 mintCommitment,bytes32 mintPolicyHash,uint256 price,bytes32 nonce,uint64 deadline,uint64 signerEpoch) sale) view returns (bytes32)",
  "function buy((uint256 collectionId,bytes32 phaseId,address payer,address recipient,address artist,bytes32 profileId,bytes32 tokenDataHash,bytes32 mintCommitment,bytes32 mintPolicyHash,uint256 price,bytes32 nonce,uint64 deadline,uint64 signerEpoch) sale,bytes tokenData,bytes platformSignature,bytes artistSignature) payable returns (uint256 tokenId,bytes32 operationRoot)"
];
const managerAbi = [
  "function phasePolicyHash(uint256 collectionId,bytes32 phaseId) view returns (bytes32)"
];
const saleAdapter = new Contract(saleAddress, saleAbi, payerSigner);
const manager = new Contract(managerAddress, managerAbi, provider);
const { chainId } = await provider.getNetwork();
const block = await provider.getBlock("latest");
if (!block) throw new Error("Latest block unavailable");
const domain = {
  name: "6529StreamFixedPriceSale", version: "1", chainId,
  verifyingContract: saleAddress
};
const types = {
  SaleAuthorization: [
    { name: "collectionId", type: "uint256" },
    { name: "phaseId", type: "bytes32" },
    { name: "payer", type: "address" },
    { name: "recipient", type: "address" },
    { name: "artist", type: "address" },
    { name: "profileId", type: "bytes32" },
    { name: "tokenDataHash", type: "bytes32" },
    { name: "mintCommitment", type: "bytes32" },
    { name: "mintPolicyHash", type: "bytes32" },
    { name: "price", type: "uint256" },
    { name: "nonce", type: "bytes32" },
    { name: "deadline", type: "uint64" },
    { name: "signerEpoch", type: "uint64" }
  ]
};
// Explicit app inputs reviewed by signers: collectionId, phaseId, recipient,
// acceptedArtist, profileId, tokenData, mintCommitment and priceWei.
const authorization = {
  collectionId, phaseId, payer: await payerSigner.getAddress(), recipient,
  artist: acceptedArtist, profileId, tokenDataHash: keccak256(tokenData),
  mintCommitment, mintPolicyHash: await manager.phasePolicyHash(collectionId, phaseId),
  price: priceWei, nonce: hexlify(randomBytes(32)),
  deadline: BigInt(block.timestamp + 600), signerEpoch: await saleAdapter.signerEpoch()
};
const digest = TypedDataEncoder.hash(domain, types, authorization);
if (digest !== await saleAdapter.authorizationDigest(authorization)) {
  throw new Error("Typed data does not match deployed adapter");
}
// Signer objects illustrate the API. Production platform signing stays in its
// controlled backend; the browser must never receive that private key.
const platformSignature = await platformSigner.signTypedData(domain, types, authorization);
const artistSignature = await artistSigner.signTypedData(domain, types, authorization);
await saleAdapter.buy.staticCall(authorization, tokenData, platformSignature,
  artistSignature, { value: priceWei });
const tx = await saleAdapter.buy(authorization, tokenData, platformSignature,
  artistSignature, { value: priceWei });
const receipt = await tx.wait();
if (!receipt || receipt.status !== 1) throw new Error("Purchase failed");
```

The example assumes provider, payer/platform/artist signers and verified addresses
come from your app. Perform all [purchase preflight](contract-flows.md#preflight)
reads first; this small ABI contains only the methods used here. `tokenData` is a
byte string; prices and IDs use bigint, not unsafe JavaScript numbers. Obtain
`tokenId` from address-filtered `NativeSaleSettled` as shown in [events](events-and-indexing.md).

## Auction typed data

Use domain name `6529StreamEnglishAuction`, version `1`, live chain ID and auction
house as verifying contract. The primary type is `AuctionAuthorization`:

```text
AuctionAuthorization(uint256 collectionId,bytes32 phaseId,address artist,bytes32 profileId,bytes32 tokenDataHash,bytes32 mintCommitment,bytes32 mintPolicyHash,uint256 reservePrice,uint64 startTime,uint64 endTime,uint32 extensionWindow,uint16 minBidIncrementBps,bytes32 nonce,uint64 deadline,uint64 signerEpoch)
```

Construct fields in that order with those types. Both parties sign this digest;
the auction house's `authorizationDigest` checks construction. Submit
`createAuction(authorization, tokenData, platformSignature, artistSignature)`.
A sale signature cannot be reused: domain, primary type and payload differ.
See the [auction lifecycle](auction-flows.md).

## Wallet and replay boundaries

EOAs may supply canonical 65-byte or EIP-2098 compact 64-byte signatures. The
implementation rejects high-s signatures and invalid recovery bytes. Contract
signers use ERC-1271 `isValidSignature` through a bounded static call: 100,000 gas
and exactly one ABI word containing the magic value. A Safe or other wallet must
validate this digest within that budget. Simulate the actual signature bytes;
interactive wallet approval alone does not prove onchain acceptance. Do not use
`personal_sign` or `eth_sign` instead of EIP-712.

A changed chain, adapter, recipient, token hash, policy, price or nonce invalidates
the signature. `signerEpoch` changes when the platform signer rotates. Deadlines
remain valid through the exact timestamp and fail afterward. Cancellation and
successful consumption share replay protection; reverted transactions roll back
consumption. Display chain, verifying address, recipient, price, profile and deadline.

WalletConnect/mobile clients must recheck account and chain after reconnecting.
Changing payer or recipient requires new signatures. Backend services should verify
accepted attribution, phase policy and recipients independently before signing.
Follow [signer custody](../signer-custody-readiness.md); never log private keys, seed
phrases, RPC credentials or session secrets. Report vulnerabilities through
[SECURITY.md](../../SECURITY.md).

Definitions: [sale interface](../../smart-contracts/interfaces/stream/mint/IStreamFixedPriceSaleAdapter.sol),
[auction interface](../../smart-contracts/interfaces/stream/auctions/IStreamEnglishAuctionHouse.sol),
[signature validator](../../smart-contracts/domains/mint/StreamSaleSignatures.sol).
