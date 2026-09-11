// Read-only parity against the actual deployed contracts. No accounts, keys or transactions.
import { readFile } from "node:fs/promises";
import { JsonRpcProvider } from "ethers";
import { StreamClient, stackConfigFromJSON, typedDataFromJSON, toJSON, provenance } from "../dist/index.js";

if (process.argv.length !== 4) throw Error("Usage: npm run parity -- config.json requests.json; set STREAM_RPC_URL in your environment");
if (!process.env.STREAM_RPC_URL) throw Error("Set STREAM_RPC_URL (never committed or printed)");
const provider = new JsonRpcProvider(process.env.STREAM_RPC_URL);
try {
  const client = new StreamClient(provider, stackConfigFromJSON(JSON.parse(await readFile(process.argv[2], "utf8"))));
  const requests = JSON.parse(await readFile(process.argv[3], "utf8"));
  if (!Array.isArray(requests) || requests.length === 0) throw Error("requests.json must contain a nonempty array");
  const results = [];
  for (const request of requests) {
    const payload = typedDataFromJSON(request), m = payload.message;
    const [contract, method, args] = {
      nativeSale: ["nativeSale", "authorizationDigest", [m]],
      erc20Sale: ["erc20Sale", "authorizationDigest", [m]],
      paymentIntent: ["erc20Sale", "paymentIntentDigest", [m]],
      paymentIntentRevocation: ["erc20Sale", "paymentIntentRevocationDigest", [m.payer, m.nonce, m.deadline]],
      artistAcceptance: ["artistRegistry", "acceptanceDigest", [m.collectionId, m.nominationHash, m.nonce, m.deadline]],
      auction: ["auction", "authorizationDigest", [m]],
    }[request.kind];
    await client.assertDigest(payload, contract, method, args);
    results.push({ kind: request.kind, contract: client.address(contract), digest: payload.digest, status: "PASS" });
  }
  console.log(toJSON({ chainId: client.config.chainId, compilerInputSha256: provenance.compilerInputSha256, results }));
} catch {
  // Transport errors may contain a credentialed URL; do not echo the provider exception.
  console.error("Digest parity failed. Check the local request, configured chain/contracts and RPC connection.");
  process.exitCode = 1;
} finally { provider.destroy(); }
