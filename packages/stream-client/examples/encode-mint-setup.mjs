import { readFileSync } from "node:fs";
import { Interface } from "ethers";

// This operator example uses the matching locally compiled planner ABI, not RC1's SDK ABI.
// Both arguments are local public files. Nothing is signed, sent or written.
const [planPath, artifactPath] = process.argv.slice(2);
if (!planPath || !artifactPath || process.argv.length !== 4) {
  throw new Error("Usage: node examples/encode-mint-setup.mjs <plan.json> <PrepareCurrentMintSetup.json>");
}
const plan = JSON.parse(readFileSync(planPath, "utf8"));
const artifact = JSON.parse(readFileSync(artifactPath, "utf8"));
const iface = new Interface(artifact.abi);
for (const phase of plan.phases) {
  if (phase.initialConsent.signature !== "0x" || phase.executorConsent.signature !== "0x") {
    throw new Error("Use empty signatures: the planner prepares direct artist wallet CALLs.");
  }
}
const encoded = iface.encodeFunctionData("prepare", [plan]);
// The function takes exactly one Plan tuple. Its arguments are abi.encode(plan).
console.log(JSON.stringify({ STREAM_MINT_SETUP_PLAN: `0x${encoded.slice(10)}` }, null, 2));
