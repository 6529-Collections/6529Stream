import { readFileSync } from "node:fs";
import { Interface } from "ethers";

export const fixture = JSON.parse(readFileSync(new URL("./fixtures/current-revenue-pull-abi.json", import.meta.url), "utf8"));
export const compiledABI = fixture.abis;
export const compiledInterfaces = Object.fromEntries(Object.entries(compiledABI).map(([key, abi]) => [key, new Interface(abi)]));
