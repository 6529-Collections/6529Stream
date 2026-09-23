import { Result } from "ethers";
// ethers Result exposes array/method properties before named ABI fields.
const reserved = new Set(["length", "then", ...[Result.prototype, Array.prototype, Object.prototype].flatMap(Object.getOwnPropertyNames)]);
const safeNames = params => params.filter(p => p.name && !reserved.has(p.name) && params.filter(x => x.name === p.name).length === 1);
const canonicalType = p => p.type.startsWith("tuple")
  ? `(${p.components.map(canonicalType).join(",")})${p.type.slice(5)}` : p.type;
const tsType = (p, output = false) => {
  const array = /^(.*)(\[[0-9]*\])$/.exec(p.type);
  if (array) return `ReadonlyArray<${tsType({ ...p, type: array[1] }, output)}>`;
  if (p.type === "tuple") {
    if (!p.components.every(x => x.name) || new Set(p.components.map(x => x.name)).size !== p.components.length
      || (output && safeNames(p.components).length !== p.components.length)) return tuple(p.components, output);
    return `{ ${p.components.map(x => `readonly ${JSON.stringify(x.name)}: ${tsType(x, output)}`).join("; ")} }`;
  }
  if (/^u?int/.test(p.type)) return "bigint";
  if (p.type === "address") return "Address";
  if (p.type.startsWith("bytes")) return "Hex";
  if (p.type === "bool") return "boolean";
  if (p.type === "string") return "string";
  throw Error(`Unsupported ABI type ${p.type}`);
};
const tuple = (params, output = false) => `readonly [${params.map(p => tsType(p, output)).join(", ")}]`;
const result = params => params.length === 0 ? "void" : params.length === 1 ? tsType(params[0], true)
  : `${tuple(params, true)} & { ${safeNames(params).map(p => `readonly ${JSON.stringify(p.name)}: ${tsType(p, true)}`).join("; ")} }`;

export function contractDefinitions(abis) {
  const definitions = [];
  for (const [key, abi] of Object.entries(abis)) {
    const methods = abi.filter(x => x.type === "function");
    const rows = methods.map(f => {
      const name = methods.filter(x => x.name === f.name).length === 1 ? f.name : `${f.name}(${(f.inputs ?? []).map(canonicalType).join(",")})`;
      return `    ${JSON.stringify(name)}: { args: ${tuple(f.inputs ?? [])}; result: ${result(f.outputs ?? [])}; mutability: ${JSON.stringify(f.stateMutability)} };`;
    });
    definitions.push(`  ${key}: {\n${rows.join("\n")}\n  };`);
  }
  return definitions.join("\n");
}
