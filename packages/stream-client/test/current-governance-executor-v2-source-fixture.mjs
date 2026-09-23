import { readFileSync } from "node:fs";
import { Interface } from "ethers";

export const governanceExecutorV2Fixture = JSON.parse(readFileSync(new URL("./fixtures/current-governance-executor-v2-abi.json", import.meta.url), "utf8"));
// Ordinary host/interfaces only. Nominal library ABIs remain witness data.
export const governanceExecutorV2Interfaces = Object.fromEntries(Object.entries(governanceExecutorV2Fixture.abis)
  .map(([name, abi]) => [name, new Interface(abi)]));
