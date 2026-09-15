/** Read-only preparation using actual selected contracts. Wallet signing/submission stays external. */
import { readFile } from "node:fs/promises";
import { resolve } from "node:path";
import { fileURLToPath } from "node:url";
import { JsonRpcProvider } from "ethers";
import { CurrentRevenueClient, toSafeCall, requireSafeExecution } from "../dist/index.js";

// Keep this returned session in your application across the independently submitted Safe CALL.
// Every retry reobserves the original intent and preserves the original authorization nonce/signature.
export async function prepareRevenueApproval(client, provider, caller, intent, authorization) {
  const plan = await client.quote(provider, caller, intent);
  const current = await client.assertFresh(provider, plan, caller);
  if (current.approval === null) return { plan: current, approval: null, artistSafeCall: null, ownerSetup: current.ownerCall };
  const approval = client.prepareArtistApproval(current, authorization);
  await client.assertApprovalDigest(provider, approval, caller);
  await client.simulate(provider, approval);
  return { plan: current, approval, artistSafeCall: toSafeCall(approval.call), ownerSetup: current.ownerCall };
}

export async function retryRevenueApproval(client, provider, session) {
  if (!session.approval) throw Error("No Artist approval in this session");
  await client.assertFresh(provider, session.plan, session.plan.caller);
  await client.assertApprovalDigest(provider, session.approval, session.plan.caller);
  await client.simulate(provider, session.approval);
  return toSafeCall(session.approval.call); // byte-identical target/data/value; no replacement signature
}

// For a direct Artist Safe CALL only. Independently obtain the exact Safe transaction hash.
// For a relayer carrying an Artist signature, verify that relayer's own receipt separately.
export async function confirmRevenueApproval(client, provider, session, receipt, safe, safeTxHash) {
  if (safe.toLowerCase() !== session.plan.caller.toLowerCase()) throw Error("Safe differs from actual prepared caller");
  requireSafeExecution(receipt, safe, safeTxHash);
  await client.assertApproved(provider, session.plan);
  return session.ownerSetup; // normally a delayed GovernanceExecutor payload, not an Artist Safe transaction
}

export async function confirmRevenueInstallation(client, provider, session) {
  await client.assertInstalled(provider, session.plan, session.plan.caller);
}

function decimal(value, name) {
  if (typeof value !== "string" || !/^(0|[1-9][0-9]*)$/.test(value)) throw Error(`${name} must be a canonical decimal string`);
  return BigInt(value);
}
export function revenueRecipeInput(config) {
  const intent = { ...config.intent, collectionId: decimal(config.intent.collectionId, "collectionId") };
  if (intent.kind !== "snapshot-current") { intent.scope = decimal(intent.scope, "scope"); intent.scopeId = decimal(intent.scopeId, "scopeId"); }
  if (intent.kind === "royalty-set") intent.royaltyBps = decimal(intent.royaltyBps, "royaltyBps");
  return { chainId: decimal(config.chainId, "chainId"), addresses: config.addresses, caller: config.caller, intent,
    authorization: config.authorization ? { nonce: decimal(config.authorization.nonce, "nonce"), deadline: decimal(config.authorization.deadline, "deadline"), signature: config.authorization.signature } : undefined };
}

// Usage: STREAM_RPC_URL=<rpc> node examples/current-revenue-safe.mjs CONFIG.json SELECTED_ABI.json
// SELECTED_ABI.json is {abis:{primary,royalty,artist,core,manager}} produced from your compiled graph.
// This command makes eth_call/getCode/block reads only; it does not sign, fund, send or select a Safe nonce.
if (process.argv[1] && resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  const [configPath, abiPath] = process.argv.slice(2);
  if (!configPath || !abiPath || !process.env.STREAM_RPC_URL) throw Error("Provide CONFIG.json SELECTED_ABI.json and STREAM_RPC_URL");
  const config = revenueRecipeInput(JSON.parse(await readFile(configPath, "utf8")));
  const { abis } = JSON.parse(await readFile(abiPath, "utf8"));
  const provider = new JsonRpcProvider(process.env.STREAM_RPC_URL, undefined, { cacheTimeout: -1 });
  try {
    const client = new CurrentRevenueClient(config.chainId, config.addresses, abis);
    const session = await prepareRevenueApproval(client, provider, config.caller, config.intent, config.authorization);
    console.log(JSON.stringify({ qualification: "Read-only proposal. Refresh before submission; original signing and owner authority remain required.",
      blockNumber: session.plan.blockNumber, blockHash: session.plan.blockHash, fingerprint: session.plan.fingerprint,
      assignment: session.plan.fact, selectedRawSource: session.plan.rawSource, sourcePolicyHash: session.plan.sourcePolicyHash,
      artistTypedData: session.approval?.payload ?? null, artistSafeCall: session.artistSafeCall, ownerSetup: session.ownerSetup },
      (_, value) => typeof value === "bigint" ? value.toString() : value, 2));
  } finally { provider.destroy(); }
}
