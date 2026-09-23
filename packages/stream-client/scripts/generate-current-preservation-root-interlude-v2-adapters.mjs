/**
 * Generate the separately pinned Prepared-v2 adapters from the exact committed v1 pair.
 * The output intentionally preserves the original module headers and every other byte:
 * packet: three profile constants; transport: only its versioned packet import.
 * No arbitrary profile injection, admission change, RPC, signing or submission occurs.
 *
 * Usage: node scripts/generate-current-preservation-root-interlude-v2-adapters.mjs [--check]
 * --check authenticates the same Git base and compares output without writing files.
 */
import { execFileSync } from "node:child_process";
import { createHash } from "node:crypto";
import { readFileSync, writeFileSync } from "node:fs";
import { fileURLToPath } from "node:url";

const BASE_COMMIT = "439aedbe8d81569b44d3e0eea98fa35211cfcdd5";
const repository = fileURLToPath(new URL("../../../", import.meta.url));
const args = process.argv.slice(2);
if (args.length > 1 || (args.length === 1 && args[0] !== "--check")) {
  throw Error("Expected no arguments or --check");
}
const check = args[0] === "--check";
const sha256 = value => createHash("sha256").update(value).digest("hex");
const git = parameters => execFileSync("git", parameters, {
  cwd: repository,
  encoding: "buffer",
  maxBuffer: 1024 * 1024,
  windowsHide: true,
});
const resolved = git(["rev-parse", `${BASE_COMMIT}^{commit}`]).toString("ascii").trim();
if (resolved !== BASE_COMMIT) throw Error("Committed adapter base differs");

const jobs = [
  {
    source: "packages/stream-client/examples/current-preservation-root-interlude-packet.mjs",
    bytes: 21385,
    sha256: "ad828865120d54d4c0f89f4109819182ebbf92c5c8e3d9575ed1e2fd19dab5ce",
    output: "current-preservation-root-interlude-packet-v2.mjs",
    replacements: [
      ["61d0efc5c88db67126a1af2e3ccaa6d1ddecb41d", "eda052c75dc9fd5c4e2e658bdf453ab01f5b7c0e"],
      ["5537434a6b43233bcc2c6f577659c18a045db0144c8dbb2c8d74d9f3ef82f5df", "66f66b99a6cb5af3c8997ab27c67ece208257eac6a337b78096cea8ff07af706"],
      ["0c9d4afe6a5a9df72a5b560bda3fe5684fe63c378e6b4746aa8afcb753cda178", "065f5ee0748ab75f143c5bee600646e3da6e3e6225a91654a0c1f300f72837d7"],
    ],
  },
  {
    source: "packages/stream-client/examples/current-preservation-root-interlude-transport.mjs",
    bytes: 18269,
    sha256: "3c7188751b4372075332e3ae1f42ff2439923a729649e08cdc899affbcc440ad",
    output: "current-preservation-root-interlude-transport-v2.mjs",
    replacements: [
      ["'./current-preservation-root-interlude-packet.mjs'", "'./current-preservation-root-interlude-packet-v2.mjs'"],
    ],
  },
];

function replaceOnce(bytes, before, after) {
  const needle = Buffer.from(before, "ascii");
  const offset = bytes.indexOf(needle);
  if (offset < 0 || bytes.indexOf(needle, offset + needle.length) >= 0) {
    throw Error("Expected exactly one pinned substitution");
  }
  return Buffer.concat([
    bytes.subarray(0, offset),
    Buffer.from(after, "ascii"),
    bytes.subarray(offset + needle.length),
  ]);
}

// Authenticate both sources and prepare both outputs before making any write.
const prepared = jobs.map(job => {
  let bytes = git(["show", `${BASE_COMMIT}:${job.source}`]);
  if (bytes.length !== job.bytes || sha256(bytes) !== job.sha256) {
    throw Error(`Committed base bytes differ: ${job.source}`);
  }
  for (const [before, after] of job.replacements) bytes = replaceOnce(bytes, before, after);
  return {
    file: job.output,
    path: fileURLToPath(new URL(`../examples/${job.output}`, import.meta.url)),
    bytes,
  };
});

for (const item of prepared) {
  if (check) {
    if (!readFileSync(item.path).equals(item.bytes)) throw Error(`Generated adapter differs: ${item.file}`);
  } else {
    writeFileSync(item.path, item.bytes);
  }
  process.stdout.write(`${check ? "Verified" : "Generated"} ${item.file} ${item.bytes.length} bytes SHA256 ${sha256(item.bytes)}\n`);
}
