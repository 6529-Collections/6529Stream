import { readFileSync, writeFileSync } from "node:fs";
import { createHash } from "node:crypto";
const [,, inputPath, outputPath, target] = process.argv;
if (!inputPath || !outputPath || !target) throw Error("Pass explicit compiler input, output and destination");
const input = JSON.parse(readFileSync(inputPath, "utf8")), output = JSON.parse(readFileSync(outputPath, "utf8"));
if (output.errors?.some(e => e.severity === "error")) throw Error("Compiler errors remain");
const selected = {
  artist: ["smart-contracts/domains/artist/StreamArtistOnboardingRegistry.sol", "StreamArtistOnboardingRegistry", ["core", "operationCoordinator", "recordEntropyUnavailabilityFinding", "entropyUnavailabilityFindingContext", "entropyUnavailabilityFindingRecord", "verifyEntropyRecoveryUnavailability", "hydrateArtistAuthorityWithEntropyFindings"]],
  entropy: ["smart-contracts/domains/entropy/StreamEntropyCoordinator.sol", "StreamEntropyCoordinator", ["core", "artistEntropyRecoveryIntent", "freshRecoveryTransition", "requestFreshEntropyWithUnavailability", "entropyUnavailabilityEvidence"]],
  coordinator: ["smart-contracts/domains/artist/StreamArtistOnboardingCoordinator.sol", "StreamArtistOnboardingCoordinator", ["authorityHydrationSuite"]],
  owner: ["smart-contracts/domains/artist/StreamArtistIdentityAuthority.sol", "StreamArtistIdentityAuthority", ["core", "operationCoordinator", "artistRegistry", "authorityHydrationCommitment", "entropyUnavailabilityFindingOrigin"]],
  core: ["smart-contracts/interfaces/stream/core/IStreamCore.sol", "IStreamCore", ["getSatellitePointer"]],
};
const abis = {}, sources = {};
for (const [key, [path, name, methods]] of Object.entries(selected)) {
  const source = input.sources[path]?.content, abi = output.contracts[path]?.[name]?.abi;
  if (typeof source !== "string" || !Array.isArray(abi)) throw Error("Missing compiler-selected product " + path);
  sources[path] = createHash("sha256").update(source).digest("hex");
  abis[key] = abi.filter(f => f.type === "function" && methods.includes(f.name));
  if (abis[key].length !== methods.length) throw Error("Missing or overloaded selected method in " + key);
}
writeFileSync(target, JSON.stringify({ qualification: "Compiler-selected encoding fixture only; no deployed-state, runtime or source inventory acceptance.", sources, abis }, null, 2) + "\n");
