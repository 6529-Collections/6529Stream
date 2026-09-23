import { readFileSync } from "node:fs";
import { Interface } from "ethers";

export const rootInterludeFixture = JSON.parse(readFileSync(new URL("./fixtures/current-preservation-root-interlude-source.json", import.meta.url), "utf8"));
export const rootInterludeReport = JSON.parse(rootInterludeFixture.sourceReport.text);
export const rootInterludeInterfaces = Object.fromEntries([...new Set(rootInterludeFixture.methods.map(m => m.target))]
  .map(target => [target, new Interface(rootInterludeFixture.methods.filter(m => m.target === target).map(m => m.abi))]));
// Exact original synthetic example bytes, never an admitted runtime/default.
export const rootInterludeSyntheticText = (kind, part) => {
  if (!["collection", "scoped"].includes(kind) || !["admission", "request"].includes(part)) throw Error("Unknown synthetic input");
  return rootInterludeFixture.syntheticInputs[`example.synthetic.${kind}.${part}.json`].text;
};
