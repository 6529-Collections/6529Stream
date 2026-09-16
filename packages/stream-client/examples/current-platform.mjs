import { keccak256, toUtf8Bytes } from "ethers";
import { platformRightsConfigurationHash, preparePlatformRightsRegistration } from "../dist/current-platform.js";

// Offline illustrative encoding values only. These are not deployed addresses or a valid
// platform signature, and this example never sends a transaction.

const chainId = 1n, house = "0x1000000000000000000000000000000000000001";
const poster = "0x2000000000000000000000000000000000000002", zero = `0x${"00".repeat(32)}`;
const tokenData = "0x1234", hash = text => keccak256(toUtf8Bytes(text));
const config = { collectionId: 6529n, phaseId: hash("phase"), tokenId: 0n, mintAtSettlement: true,
  artworkCommitment: keccak256(tokenData), contentManifestRoot: zero, mintCommitment: hash("mint"), poster,
  reservePrice: 1_000_000_000_000_000_000n, minIncrementBps: 500n, incrementFloorWaived: false,
  clock: { startTime: 1_800_000_000n, endTime: 1_800_086_400n, firstBidDuration: 0n,
    antiSnipeWindow: 0n, antiSnipeExtension: 0n, maxTotalExtension: 0n, startOnFirstBid: false, hardClose: true },
  expectedPrimaryPolicyHash: hash("opening-policy"), primaryPolicyMode: 1n, settlementWindow: 86400n, mintPolicyHash: hash("mint-policy") };
const original = { mode: 8n, assignmentHash: hash("reviewed-assignment"), templateId: hash("reviewed-template") };
const declarationHash = hash("reviewed-platform-declaration");
const authorization = { configHash: platformRightsConfigurationHash(chainId, house, config, original, declarationHash),
  declarationHash, nonce: hash("one-use-platform-nonce"), deadline: 1_800_000_000n };
const prepared = preparePlatformRightsRegistration(chainId, house, config, original, tokenData, authorization, "0x1234");
console.log({ order: ["review source/declaration", "sign payload", "simulate exact call at a pinned block", "submit CALL from original poster"], caller: prepared.caller, payload: prepared.payload, call: prepared.call });
