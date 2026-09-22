import { readFileSync } from 'node:fs';
import { Interface } from 'ethers';

export const fixture = JSON.parse(readFileSync(new URL('./fixtures/current-artist-complete-history-source-profile.json', import.meta.url), 'utf8'));

/** Original production compiler ABI. A library ABI is never a wallet endpoint. */
export function compiledABI(name) {
  const declaration = fixture.selections[name];
  if (!declaration || declaration.kind !== 'ordinary') throw Error(`No ordinary compiler ABI: ${name}`);
  return declaration.abi;
}
export const compiledInterfaces = Object.fromEntries(Object.entries(fixture.selections)
  .filter(([, value]) => value.kind === 'ordinary').map(([name]) => [name, new Interface(compiledABI(name))]));

/** Value encoding only. Retain compiler methodIdentifiers for library selectors. */
export function valueField(field) {
  const result = structuredClone(field);
  if (result.internalType?.startsWith('enum ') && !/^uint8(?:\[[0-9]*\])*$/.test(result.type)) {
    const internal = result.internalType.replace(/(\[[0-9]*\])+$/, '');
    const evidence = fixture.libraryValueTypeEvidence[internal];
    if (!evidence || evidence.abiType !== 'uint8') throw Error(`Unwitnessed nominal enum ${internal}`);
    let original = evidence.entry[evidence.direction];
    for (const key of evidence.parameterPath) original = original[key];
    if (original.internalType !== internal || original.type !== 'uint8') throw Error('Enum witness differs');
    const nominal = internal.slice(5), suffix = result.type.slice(nominal.length);
    if (!result.type.startsWith(nominal) || !/^(\[[0-9]*\])*$/.test(suffix)) throw Error('Unexpected nominal enum shape');
    result.type = 'uint8' + suffix;
  }
  if (result.components) result.components = result.components.map(valueField);
  return result;
}

export function compiledValueABI(name) {
  const declaration = fixture.selections[name];
  if (!declaration) throw Error(`Missing compiler declaration ${name}`);
  return declaration.abi.map(entry => ({ ...entry,
    ...(entry.inputs ? { inputs: entry.inputs.map(valueField) } : {}),
    ...(entry.outputs ? { outputs: entry.outputs.map(valueField) } : {}),
  }));
}

export function source(name) {
  const rows = Object.entries(fixture.sources).filter(([path]) => path.endsWith('/' + name));
  if (rows.length !== 1) throw Error(`Ambiguous or missing source ${name}`);
  return rows[0][1].text;
}
