import { readFileSync } from "node:fs";
import { Interface } from "ethers";
export const fixture = JSON.parse(readFileSync(new URL("./fixtures/current-tagged-policy-view-v2-abi.json", import.meta.url), "utf8"));
export const compiledABI = key => fixture.abis[key];
export const compiledInterfaces = Object.fromEntries(Object.entries(fixture.abis).map(([key, abi]) => [key, new Interface(abi)]));
// These events retain the compiler's exact tuple shapes. Nominal library
// function selectors are intentionally unavailable through this helper.
export const compiledLibraryEvents = key => {
  const abi = fixture.libraryAbis[key];
  if (!abi) throw Error(`Unknown compiler library ${key}`);
  return new Interface(abi.filter(fragment => fragment.type === "event"));
};
