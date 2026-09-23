import type { Address, Hex } from "../src/generated/contracts.js";
import {
  prepareCuratedFixedRegistration,
  prepareCuratedPublicPurchase,
  prepareCuratedReasonUnlock,
  prepareCuratedSelectionCommit,
  prepareCuratedSelectionReveal,
} from "../src/current-curated-fixed.js";

declare const address: Address, hash: Hex;
const sale = {
  collectionId: 1n,
  phaseId: hash,
  price: 1n,
  poster: address,
  startsAt: 1n,
  endsAt: 4n,
  mintPolicyHash: hash,
  expectedPrimaryPolicyHash: hash,
  primaryPolicyMode: 0n,
  contentManifestRoot: hash,
} as const;
const publicConfiguration = {
  sale,
  mode: 1n,
  differentiatedContent: false,
  publicSelectionDisclosure: true,
  windows: {
    commitOpen: 0n,
    commitClose: 0n,
    revealOpen: 0n,
    revealClose: 0n,
    absoluteEscape: 0n,
  },
} as const;
const commitConfiguration = {
  sale: { ...sale, primaryPolicyMode: 1n },
  mode: 0n,
  differentiatedContent: true,
  publicSelectionDisclosure: false,
  windows: {
    commitOpen: 1n,
    commitClose: 2n,
    revealOpen: 2n,
    revealClose: 4n,
    absoluteEscape: 4n,
  },
} as const;
const content = { contentId: hash, tokenDataHash: hash, proof: [hash] } as const;
const selection = {
  content,
  tokenData: "0x",
  mintCommitment: hash,
  recipient: address,
  purchaseNonce: 1n,
} as const;
prepareCuratedFixedRegistration(1n, address, address, 1n, publicConfiguration);
prepareCuratedPublicPurchase(1n, address, address, hash, publicConfiguration, selection, 0n);
prepareCuratedSelectionCommit(1n, address, address, hash, commitConfiguration, content, hash, 1n);
prepareCuratedSelectionReveal(1n, address, address, hash, commitConfiguration, selection, hash, 0n);
prepareCuratedReasonUnlock(1n, address, address, hash, address, commitConfiguration, selection, hash, 1n);
// @ts-expect-error selection disclosure is a strict boolean
prepareCuratedFixedRegistration(1n, address, address, 1n, { ...publicConfiguration, publicSelectionDisclosure: "true" });
// @ts-expect-error reveal allowance is an exact bigint
prepareCuratedPublicPurchase(1n, address, address, hash, publicConfiguration, selection, 0);
