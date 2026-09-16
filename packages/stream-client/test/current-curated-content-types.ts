import type { Address, Hex } from "../src/generated/contracts.js";
import { buildCuratedManifest, curatedContentGateConfigHash, curatedSaleId,
  normalizeCuratedSelection, verifyCuratedContentProof } from "../src/current-curated-content.js";
declare const address: Address, hash: Hex;
const manifest = buildCuratedManifest({ chainId: 1n, manager: address, adapter: address,
  saleId: hash, collectionId: 1n, phaseId: hash, counterId: hash,
  rows: [{ contentId: hash, tokenDataHash: hash, previewURI: "ipfs://reviewed" }] });
const selected = manifest.selections[0]!;
verifyCuratedContentProof(1n, address, hash, manifest.publication.manifestRoot, selected);
normalizeCuratedSelection({ content: selected, tokenData: "0x", mintCommitment: hash, recipient: address, purchaseNonce: 1n });
curatedContentGateConfigHash(manifest, hash, hash);
curatedSaleId(1n, address, 0n, 1n, hash, 1n);
// @ts-expect-error integer identities preserve exact bigint values
curatedSaleId(1, address, 0n, 1n, hash, 1n);
// @ts-expect-error returned manifest selections are immutable
selected.proof.push(hash);
