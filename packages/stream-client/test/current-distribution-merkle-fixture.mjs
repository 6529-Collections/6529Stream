import { readFileSync } from "node:fs";
import { Interface } from "ethers";
export const fixture = JSON.parse(readFileSync(new URL("./fixtures/current-distribution-merkle-abi.json", import.meta.url), "utf8"));
export const compiledABI = key => fixture.abis[key];
export const compiledInterfaces = Object.fromEntries(Object.entries(fixture.abis).map(([key, abi]) => [key, new Interface(abi)]));
