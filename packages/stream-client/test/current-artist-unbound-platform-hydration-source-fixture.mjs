import { readFileSync } from "node:fs";
import { createHash } from "node:crypto";
import { Interface, ParamType } from "ethers";
import * as prior from "./current-artist-recovered-multiple-attestation-hydration-source-fixture.mjs";

// The retained objects keep their original bd4 identity. Current declarations
// resolve through exact ABI188 comparisons or explicit full current overrides.
export const fixture = prior.fixture;
export const sourceProfile = JSON.parse(readFileSync(new URL("./fixtures/current-artist-unbound-platform-hydration-source-profile.json", import.meta.url), "utf8"));
export const unboundPlatformFixture = sourceProfile;
const aliases = Object.fromEntries(Object.keys(sourceProfile.libraryAbis).filter(name => name.startsWith("StreamArtistUnboundPlatform")).map(name => ["unboundPlatform" + name.slice("StreamArtistUnboundPlatform".length), name]));
aliases.unboundPlatform = "StreamArtistUnboundPlatformCodec";
const resolved = name => aliases[name] ?? fixture.aliases[name] ?? name;
const sha = value => createHash("sha256").update(value).digest("hex");

export function unboundPlatformSource(path) {
  const row = sourceProfile.sources[path], text = sourceProfile.sourceOverrides[path] ?? fixture.sourceTexts[path];
  if (!row || typeof text !== "string" || sha(text) !== row.sha256) throw Error(`Missing current UNBOUND_PLATFORM source: ${path}`);
  return text;
}
function retained(name, kind) {
  const row = sourceProfile.retainedDeclarations[name];
  if (!row || row.kind !== kind || !row.abiEqual || !row.methodsEqual) throw Error(`No current retained declaration comparison: ${name}`);
}
export function compiledABI(name) {
  const key = resolved(name), current = sourceProfile.abis[key];
  if (current) return current;
  retained(key, "ordinary"); return prior.compiledABI(key);
}
export const compiledInterfaces = Object.fromEntries([...new Set([...Object.keys(fixture.abis), ...Object.keys(sourceProfile.abis)])].map(name => [name, new Interface(compiledABI(name))]));
for (const [alias, name] of Object.entries(fixture.aliases)) if (compiledInterfaces[name]) compiledInterfaces[alias] = compiledInterfaces[name];
export function libraryABI(name) {
  const key = resolved(name), current = sourceProfile.libraryAbis[key];
  if (current) return current;
  retained(key, "library"); return fixture.libraryAbis[key];
}
export function compiledLibraryEvents(name) { return new Interface(libraryABI(name).filter(row => row.type === "event")); }

// Derive enum wire widths exclusively from complete current ordinary ABI fields.
const enumWidths = new Map();
function collectEnums(field) {
  if (!field || typeof field !== "object") return;
  if (field.internalType?.startsWith("enum ") && field.type === "uint8") enumWidths.set(field.internalType, "uint8");
  for (const child of Object.values(field)) {
    if (Array.isArray(child)) child.forEach(collectEnums);
    else if (child && typeof child === "object") collectEnums(child);
  }
}
for (const name of [...Object.keys(fixture.abis), ...Object.keys(sourceProfile.abis)]) collectEnums(compiledABI(name));

/** Value encoding only. The original nominal selectors stay in separate maps. */
export function libraryValueABI(name) {
  const value = structuredClone(libraryABI(name));
  function visit(field) {
    if (!field || typeof field !== "object") return;
    if (field.internalType?.startsWith("enum ") && field.type !== "uint8") {
      if (enumWidths.get(field.internalType) !== "uint8" || field.type !== field.internalType.slice(5)) throw Error(`Unwitnessed enum: ${field.internalType}`);
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

/** Genuine ABI188 tuple witness; a source-only carrier is never inferred here. */
export function unboundPlatformTuple(internalType) {
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
  if (!found.length) {
    for (const name of [...Object.keys(fixture.abis), ...Object.keys(sourceProfile.abis)]) visit(compiledABI(name));
    for (const name of Object.keys(fixture.libraryAbis)) visit(libraryValueABI(name));
  }
  if (!found.length) throw Error(`No ABI188 tuple witness: ${internalType}`);
  if (found.some(row => row.format("full") !== found[0].format("full"))) throw Error(`Conflicting tuple witnesses: ${internalType}`);
  return found[0];
}
