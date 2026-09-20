import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { Interface } from "ethers";

export const fixture = JSON.parse(readFileSync(new URL("./fixtures/current-artist-recovered-hydration-abi.json", import.meta.url), "utf8"));

// Value encoding only. Library function selectors remain the original compiler
// methodIdentifiers; an Interface created here must not choose their call selector.
export function libraryValueABI(rows) {
  const copied = structuredClone(rows);
  function visit(value) {
    if (!value || typeof value !== "object") return;
    const evidence = fixture.libraryValueTypeEvidence[value.internalType];
    if (evidence && value.type === evidence.nominalType) value.type = evidence.abiType;
    for (const child of Object.values(value)) {
      if (Array.isArray(child)) child.forEach(visit);
      else if (child && typeof child === "object") visit(child);
    }
  }
  visit(copied);
  return copied;
}

export function verifyLibraryValueTypeEvidence() {
  for (const [name, evidence] of Object.entries(fixture.libraryValueTypeEvidence)) {
    const witness = evidence.witness;
    const functions = fixture.abis[witness.segment].filter(row => row.type === "function" && row.name === witness.function);
    assert.equal(functions.length, 1, witness.function);
    let field = functions[0][witness.direction];
    for (const part of witness.parameterPath) field = field[part];
    assert.equal(field.internalType, name);
    assert.equal(field.type, evidence.abiType);
    assert.equal(evidence.abiType, "uint8");
    assert.equal(name, `enum ${evidence.nominalType}`);
  }
}

verifyLibraryValueTypeEvidence();
export const compiledABI = Object.fromEntries(Object.entries(fixture.abis).map(([key, rows]) => [key, libraryValueABI(rows)]));
export const compiledInterfaces = Object.fromEntries(Object.entries(compiledABI).map(([key, rows]) => [key, new Interface(rows)]));
