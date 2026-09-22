import { readFileSync } from "node:fs";
import { Interface } from "ethers";

export const fixture = JSON.parse(readFileSync(new URL("./fixtures/current-artist-recovered-multiple-consent-hydration-abi.json", import.meta.url), "utf8"));
const contractName = name => fixture.aliases[name] ?? name;

/** Complete original ordinary ABI only; nominal library functions are never ordinary endpoints. */
export function compiledABI(name) {
  const rows = fixture.abis[contractName(name)];
  if (!rows) throw Error(`No ordinary compiler ABI: ${name}`);
  return rows;
}
export const compiledInterfaces = Object.fromEntries(Object.keys(fixture.abis).map(name => [name, new Interface(compiledABI(name))]));
for (const [alias, name] of Object.entries(fixture.aliases)) {
  if (Object.hasOwn(compiledInterfaces, name)) compiledInterfaces[alias] = compiledInterfaces[name];
}

export function compiledLibraryEvents(name) {
  const rows = fixture.libraryAbis[contractName(name)];
  if (!rows) throw Error(`No nominal compiler library: ${name}`);
  return new Interface(rows.filter(row => row.type === "event"));
}

/** Value encoding only. Never use the resulting Interface's expanded tuple
 * selector as a library call selector. Use retained compiler methodIdentifiers.
 * The fixture remains literal and unchanged; substitution happens in a copy.
 */
export function libraryValueABI(name) {
  const rows = fixture.libraryAbis[contractName(name)];
  if (!rows) throw Error(`No nominal compiler library: ${name}`);
  const value = structuredClone(rows);
  function visit(field) {
    if (!field || typeof field !== "object") return;
    if (field.internalType?.startsWith("enum ") && field.type !== "uint8") {
      const evidence = fixture.libraryValueTypeEvidence[field.internalType];
      if (!evidence || field.type !== evidence.nominalType || evidence.abiType !== "uint8") throw Error(`Unwitnessed nominal enum: ${field.internalType}`);
      let original = fixture.abis[evidence.witness.contract][evidence.witness.abiIndex][evidence.witness.direction];
      for (const key of evidence.witness.parameterPath) original = original[key];
      if (original.internalType !== field.internalType || original.type !== "uint8") throw Error("Ordinary enum value witness differs");
      field.type = "uint8";
    }
    for (const child of Object.values(field)) {
      if (Array.isArray(child)) child.forEach(visit);
      else if (child && typeof child === "object") visit(child);
    }
  }
  visit(value);
  return value;
}
export function compiledLibraryValueInterface(name) { return new Interface(libraryValueABI(name)); }
