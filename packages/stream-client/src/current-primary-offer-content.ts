import { AbiCoder, Interface, ZeroAddress, getAddress, id, isHexString, keccak256 } from "ethers";
import type { Provider } from "ethers";
import type { Address, Hex } from "./generated/contracts.js";
import { buildCuratedManifest } from "./current-curated-content.js";
import type { CuratedManifest, CuratedPublication } from "./current-curated-content.js";

const coder = AbiCoder.defaultAbiCoder();
const version = id("6529STREAM_NATIVE_PRIMARY_OFFER_GATE_V1");
const publicationTuple = "tuple(uint256 chainId,address manager,address house,bytes32 saleId,uint256 collectionId,bytes32 phaseId,bytes32 manifestRoot,bytes32 manifestHash,bytes32 counterId)";
const gateAbi = new Interface([
  `function publication() view returns (${publicationTuple})`,
  "function manifestBytes() view returns (bytes)", "function itemCount() view returns (uint256)",
  "function gateConfigHash() view returns (bytes32)", "function managerCodeHash() view returns (bytes32)",
  "function houseCodeHash() view returns (bytes32)", "function offerPurchaseVersion() view returns (bytes32)",
]);

function runtimeHash(value: Hex): Hex {
  if (!isHexString(value, 32) || BigInt(value) === 0n) throw Error("Expected nonzero runtime hash");
  return value.toLowerCase() as Hex;
}
function reviewedManifest(manifest: CuratedManifest): CuratedManifest {
  const saved = buildCuratedManifest({ ...manifest.coordinates, rows: manifest.rows });
  if (typeof manifest.manifestBytes !== "string" || saved.manifestBytes.toLowerCase() !== manifest.manifestBytes.toLowerCase()
    || coder.encode([publicationTuple], [saved.publication]).toLowerCase() !== coder.encode([publicationTuple], [manifest.publication]).toLowerCase()) {
    throw Error("Reviewed offer manifest differs from its complete rows");
  }
  return saved;
}

/** Original content leaf/context/publication with the distinct primary-offer gate capability. */
export function primaryOfferGateConfigHash(manifest: CuratedManifest, managerCodeHash: Hex, adapterCodeHash: Hex): Hex {
  const saved = reviewedManifest(manifest);
  return keccak256(coder.encode(["bytes32", publicationTuple, "bytes32", "bytes32"],
    [version, saved.publication, runtimeHash(managerCodeHash), runtimeHash(adapterCodeHash)])) as Hex;
}

/**
 * Inspect a selected-work offer gate. Build complete rows with buildCuratedManifest using the
 * kind-6 sale ID. Collection-level offers have no manifest or phase gate and do not use this read.
 */
export async function inspectPrimaryOfferManifest(
  provider: Pick<Provider, "getNetwork" | "call" | "getCode">, gate: Address, expected: CuratedManifest,
  options: { readonly blockTag: number },
): Promise<{ readonly gate: Address; readonly blockTag: number; readonly publication: CuratedPublication;
  readonly gateConfigHash: Hex; readonly evidenceBoundary: string }> {
  const target = getAddress(gate) as Address, blockTag = options?.blockTag;
  if (target === ZeroAddress) throw Error("Offer gate must be nonzero");
  if (!Number.isSafeInteger(blockTag) || blockTag < 0) throw Error("Concrete nonnegative offer manifest block required");
  const saved = reviewedManifest(expected);
  if ((await provider.getNetwork()).chainId !== saved.coordinates.chainId) throw Error("Offer manifest RPC chain differs");
  const read = async (method: string, maxBytes = 288): Promise<unknown> => {
    const raw = await provider.call({ to: target, data: gateAbi.encodeFunctionData(method), blockTag });
    if (typeof raw !== "string" || raw.length > 2 + maxBytes * 2 || !isHexString(raw, true)) throw Error(`Malformed or oversized ${method} response`);
    const decoded = gateAbi.decodeFunctionResult(method, raw);
    if (gateAbi.encodeFunctionResult(method, decoded).toLowerCase() !== raw.toLowerCase()) throw Error(`Noncanonical ${method} response`);
    return decoded[0];
  };
  const publication = await read("publication");
  if (coder.encode([publicationTuple], [publication]).toLowerCase() !== coder.encode([publicationTuple], [saved.publication]).toLowerCase()) throw Error("Onchain offer publication differs from reviewed manifest");
  const bytes = await read("manifestBytes", 64 + (saved.manifestBytes.length - 2) / 2);
  if (String(bytes).toLowerCase() !== saved.manifestBytes.toLowerCase()
    || await read("itemCount", 32) !== BigInt(saved.rows.length)) throw Error("Stored complete offer manifest bytes or count differ");
  if (await read("offerPurchaseVersion", 32) !== version) throw Error("Gate is not the native primary offer capability");
  const managerHash = runtimeHash(await read("managerCodeHash", 32) as Hex);
  const adapterHash = runtimeHash(await read("houseCodeHash", 32) as Hex);
  const configHash = primaryOfferGateConfigHash(saved, managerHash, adapterHash);
  if (await read("gateConfigHash", 32) !== configHash) throw Error("Stored offer gate configuration differs from complete publication");
  for (const [contract, expectedHash] of [[saved.coordinates.manager, managerHash], [saved.coordinates.adapter, adapterHash]] as const) {
    const code = await provider.getCode(contract, blockTag);
    if (!isHexString(code, true) || code === "0x" || keccak256(code) !== expectedHash) throw Error("Observed bound runtime differs from offer gate's saved runtime hash");
  }
  return Object.freeze({ gate: target, blockTag, publication: saved.publication, gateConfigHash: configHash,
    evidenceBoundary: "Complete offer publication and observed bound runtimes only; numeric block pin has no reorg check and does not establish canonical deployment, live phase admission, counter availability or preview availability." });
}
