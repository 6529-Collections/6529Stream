import { readFileSync } from "node:fs";
import { createHash } from "node:crypto";
import { Interface, ParamType } from "ethers";
import * as prior from "./current-artist-recovered-multiple-attestation-hydration-source-fixture.mjs";

// These remain the original bd4 compiler objects. The separate supplement proves
// full ABI/method equality at ABI178; it never relabels the old capture.
export const fixture = prior.fixture;
export const sourceProfile = JSON.parse(readFileSync(new URL("./fixtures/current-artist-recovered-multiple-generation-hydration-source-profile.json", import.meta.url), "utf8"));
export const generationFixture = sourceProfile;
const aliases = Object.fromEntries(Object.keys(sourceProfile.libraryAbis).map(name => ["multipleGeneration" + name.slice("StreamArtistRecoveredMultipleGeneration".length), name]));
aliases.multipleGeneration = "StreamArtistRecoveredMultipleGenerationCodec";
const resolved = name => aliases[name] ?? fixture.aliases[name] ?? name;
const sha = value => createHash("sha256").update(value).digest("hex");

export function generationSource(path) {
  const row = sourceProfile.sources[path], text = sourceProfile.sourceOverrides[path] ?? fixture.sourceTexts[path];
  if (!row || typeof text !== "string" || sha(text) !== row.sha256) throw Error(`Missing current generation source: ${path}`);
  return text;
}
function retained(name, kind) {
  const row = sourceProfile.retainedDeclarations[name];
  if (!row || row.kind !== kind || !row.abiEqual || !row.methodsEqual) throw Error(`No current retained declaration comparison: ${name}`);
}
export function compiledABI(name) { const key = resolved(name); retained(key, "ordinary"); return prior.compiledABI(key); }
export const compiledInterfaces = Object.fromEntries(Object.keys(fixture.abis).map(name => [name, new Interface(compiledABI(name))]));
for (const [alias, name] of Object.entries(fixture.aliases)) if (compiledInterfaces[name]) compiledInterfaces[alias] = compiledInterfaces[name];
export function libraryABI(name) {
  const key = resolved(name), current = sourceProfile.libraryAbis[key];
  if (current) return current;
  retained(key, "library"); return fixture.libraryAbis[key];
}
export function compiledLibraryEvents(name) { return new Interface(libraryABI(name).filter(row => row.type === "event")); }

/** Value encoding only. Original nominal methodIdentifiers remain separate. */
export function libraryValueABI(name) {
  const value = structuredClone(libraryABI(name));
  function visit(field) {
    if (!field || typeof field !== "object") return;
    if (field.internalType?.startsWith("enum ") && field.type !== "uint8") {
      const evidence = fixture.libraryValueTypeEvidence[field.internalType];
      if (!evidence || evidence.nominalType !== field.type || evidence.abiType !== "uint8") throw Error(`Unwitnessed enum: ${field.internalType}`);
      retained(evidence.witness.contract, "ordinary");
      let original = fixture.abis[evidence.witness.contract][evidence.witness.abiIndex][evidence.witness.direction];
      for (const key of evidence.witness.parameterPath) original = original[key];
      if (original.internalType !== field.internalType || original.type !== "uint8") throw Error("Ordinary enum width witness differs");
      field.type = "uint8";
    }
    for (const child of Object.values(field)) {
      if (Array.isArray(child)) child.forEach(visit);
      else if (child && typeof child === "object") visit(child);
    }
  }
  visit(value); return value;
}
export function compiledLibraryValueInterface(name) { return new Interface(libraryValueABI(name)); }

/** Genuine ABI178 tuple witness; absence is an error, never source inference. */
export function generationTuple(internalType) {
  const found = [];
  function visit(field) {
    if (!field || typeof field !== "object") return;
    if (field.internalType?.replace(/(?:\[[0-9]*\])+$/, "") === `struct ${internalType}` && /^tuple(?:\[[0-9]*\])*$/.test(field.type)) found.push(ParamType.from({ type: "tuple", components: field.components }));
    for (const child of Object.values(field)) {
      if (Array.isArray(child)) child.forEach(visit);
      else if (child && typeof child === "object") visit(child);
    }
  }
  for (const name of Object.keys(sourceProfile.libraryAbis)) visit(libraryValueABI(name));
  // Some unchanged nested types occur only in retained full declarations. Their
  // complete ABI and nominal methods were compared to ABI178 before reuse.
  if (!found.length) for (const [name, row] of Object.entries(sourceProfile.retainedDeclarations)) {
    if (row.kind === "ordinary") visit(compiledABI(name));
    else visit(libraryValueABI(name));
  }
  if (!found.length) throw Error(`No ABI178 tuple witness: ${internalType}`);
  if (found.some(row => row.format("full") !== found[0].format("full"))) throw Error(`Conflicting tuple witnesses: ${internalType}`);
  return found[0];
}
