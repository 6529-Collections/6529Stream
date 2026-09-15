// Offline CALL preparation only. Supply the live preview output after declaring the incident and waiting.
import { prepareFreshEntropyRecovery, prepareEntropyRecoveryContentConsent, toSafeCall } from "../dist/index.js";
const [,, file] = process.argv;
if (!file) throw Error("Pass a JSON file with chainId, coordinator, registry, core, collectionId, input, nativeAllowance, preview and authorization");
const { readFile } = await import("node:fs/promises");
const q = JSON.parse(await readFile(file, "utf8"));
function decimal(value) {
  if (typeof value !== "string" || !/^(0|[1-9][0-9]*)$/.test(value)) throw Error("Integers must be decimal strings");
  return BigInt(value);
}
const prepared = prepareFreshEntropyRecovery(q.coordinator, q.input, decimal(q.nativeAllowance));
const preview = { ...q.preview, providerFee: decimal(q.preview.providerFee) };
const consent = prepareEntropyRecoveryContentConsent(decimal(q.chainId), q.registry, q.core, decimal(q.collectionId), prepared, preview,
  { ...q.authorization, nonce: decimal(q.authorization.nonce), deadline: decimal(q.authorization.deadline) });
console.log(JSON.stringify({ qualification: "Unsigned calls only. Confirm the live preview and original Artist digest before signing.",
  artistConsent: toSafeCall(consent.call), incidentRoleRecovery: toSafeCall(prepared.call) }, null, 2));
