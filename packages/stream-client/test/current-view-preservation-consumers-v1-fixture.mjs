import { readFileSync } from "node:fs";
import { Interface } from "ethers";
export const fixture = JSON.parse(readFileSync(new URL("./fixtures/current-view-preservation-consumers-v1-abi.json", import.meta.url), "utf8"));
export const compiledABI = name => fixture.abis[name];
export const compiledInterfaces = Object.fromEntries(Object.entries(fixture.abis).map(([name, abi]) => [name, new Interface(abi)]));
export const compiledLibraryEvents = name => {
  const abi = fixture.libraryAbis[name];
  if (!abi) throw Error(`Unknown compiler library ${name}`);
  return new Interface(abi.filter(fragment => fragment.type === "event"));
};
