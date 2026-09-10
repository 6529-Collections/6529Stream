import test from "node:test";
import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import { typedDataFromJSON, provenance } from "../dist/index.js";

test("all six payloads retain the independently observed current-contract digest vectors", async () => {
  const fixture = JSON.parse(await readFile(new URL("./fixtures/onchain-digests.json", import.meta.url), "utf8"));
  assert.equal(fixture.compilerInputSha256, provenance.compilerInputSha256);
  assert.deepEqual(fixture.vectors.map(v => v.request.kind).sort(), ["nativeSale", "erc20Sale", "paymentIntent", "paymentIntentRevocation", "artistAcceptance", "auction"].sort());
  for (const vector of fixture.vectors) assert.equal(typedDataFromJSON(vector.request).digest, vector.digest, vector.request.kind);
});
