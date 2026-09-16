import { ZeroAddress, id } from "ethers";
import { CurrentBurnMintClient, burnMintNullifier, burnMintProgramConfigHash } from "../dist/current-burn-mint.js";

const A = n => `0x${BigInt(n).toString(16).padStart(40, "0")}`;
const chainId = 1n;
const deployment = { gate: A(1), core: A(2), registry: A(3) };
const client = new CurrentBurnMintClient(chainId, deployment);
const freeConfig = { manager: A(4), targetCollectionId: 6529n, phaseId: id("burn phase"),
  sourceCollectionIds: [10n, 20n], sourcesPerMint: 2n, startsAt: 0n, endsAt: 0n,
  prepared: true, nativeSaleAdapter: ZeroAddress };
const configuration = client.configureProgram(freeConfig, A(5));

// These helpers perform pinned reads and return unsigned calls; they do not send or sign.
export async function reviewFreeBurnMint(provider, plan, caller, batch, sources, allowance, blockTag = "latest") {
  return client.prepareFreeBurnMint(provider, plan, caller, batch, sources, allowance, blockTag);
}
export async function reviewNativeBurnMint(provider, plan, sources, authorization, saleInput, blockTag = "latest") {
  return client.prepareNativePurchaseWithBurn(provider, plan, sources, authorization, saleInput, blockTag);
}

console.log(JSON.stringify({
  configHash: burnMintProgramConfigHash(chainId, deployment.gate, deployment.core, deployment.registry, freeConfig),
  configureCall: configuration.call,
  sampleOriginalNullifier: burnMintNullifier(chainId, deployment.core, 9007199254740993n),
  freeBatchShape: { collectionId: freeConfig.targetCollectionId, phaseId: freeConfig.phaseId,
    payer: ZeroAddress, authorizer: ZeroAddress, initialRecipients: [A(6)], beneficiaries: [A(6)],
    tokenData: ["0x"], mintCommitments: [id("mint commitment")], expectedPolicyHash: id("approved policy"),
    authorizationId: id("unique free authorization"), contextHash: id("burn context"), resolverData: "0x" },
  next: "Capture the configured program, inspect both caller and gate approvals, then prepare near submission.",
}, (_key, value) => typeof value === "bigint" ? value.toString() : value, 2));
