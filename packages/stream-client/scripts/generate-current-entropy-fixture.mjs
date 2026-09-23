import { readFileSync, writeFileSync } from "node:fs";
import { createHash } from "node:crypto";
const [,, inputPath, outputPath, target] = process.argv;
if (!inputPath || !outputPath || !target) throw Error("Pass explicit compiler input, output and fixture destination");
const input = JSON.parse(readFileSync(inputPath, "utf8")), output = JSON.parse(readFileSync(outputPath, "utf8"));
if (output.errors?.some(e => e.severity === "error")) throw Error("Compiler errors remain");
const selected = {
  recovery: ["smart-contracts/interfaces/stream/entropy/IStreamEntropyFreshRecovery.sol", "IStreamEntropyFreshRecovery"],
  coordinator: ["smart-contracts/domains/entropy/StreamEntropyCoordinator.sol", "StreamEntropyCoordinator"],
  artist: ["smart-contracts/interfaces/stream/artist/IStreamArtistContentAuthority.sol", "IStreamArtistContentAuthority"],
};
const abis = {}, sources = {};
for (const [key, [path, name]] of Object.entries(selected)) {
  const text = input.sources[path]?.content, abi = output.contracts[path]?.[name]?.abi;
  if (typeof text !== "string" || !Array.isArray(abi)) throw Error("Missing selected compiler source/ABI: " + path);
  sources[path] = createHash("sha256").update(text).digest("hex");
  const methods = { recovery: ["requestFreshEntropy", "freshRecoveryTransition"],
    coordinator: ["markEntropyRequestUnrecoverable", "markEntropyScopeRequestUnrecoverable", "claimEntropyFeeCredit"],
    artist: ["recordContentConsent", "contentConsentDigest"] }[key];
  abis[key] = abi.filter(f => f.type === "function" && methods.includes(f.name));
  if (abis[key].length !== methods.length) throw Error("Missing exact selected methods: " + key);
}
writeFileSync(target, JSON.stringify({ qualification: "Compiler-selected encoding fixture; not deployed-state or runtime acceptance.", sources, abis }, null, 2) + "\n");
