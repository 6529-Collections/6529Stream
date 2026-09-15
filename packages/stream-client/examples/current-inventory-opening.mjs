/** Original native inventory opening; caller-selected compiler ABIs and confirmed registration.
 * No key, signing, submission, Safe nonce selection or automatic resend lives here.
 */
import { readFile, writeFile } from "node:fs/promises";
import { CurrentInventoryWorkflow, toSafeCall } from "../dist/index.js";

// 1. Prepare the original owner-authorized registration CALL; submit it independently.
export function registrationCall(chainId, adapter, bindings, configurationOwner, config, tokenIds) {
  const workflow = new CurrentInventoryWorkflow(chainId, adapter, bindings);
  const prepared = workflow.sales.registerInventory(configurationOwner, config, tokenIds);
  return { caller: prepared.caller, safeCall: toSafeCall(prepared.call) };
}

// 2. The actual InventoryConfigured receipt provides saleRef. Prepare original owner grants,
//    compare each signing digest to custodyGrantDigest, and obtain owner EOA/1271 signatures.
//    The NFT owner's original Core transfer approval is a separate required transaction.
//    Then start with {receipt, config, tokenIds, deposits, opener, pins, registrationSafe?}.
export async function prepareRegisteredInventory(workflow, provider, input, blockTag = "latest") {
  return workflow.start(provider, input, blockTag);
}

// Retain the returned saved object before writing either file, so a disk error cannot lose its hash.
export async function persistInventoryJournal(saved, journalPath, hashPath) {
  // Exclusive creation avoids silently replacing a journal or its independently retained hash.
  await writeFile(journalPath, saved.json, { encoding: "utf8", flag: "wx" });
  await writeFile(hashPath, saved.hash + "\n", { encoding: "utf8", flag: "wx" });
  return saved;
}

// 3. Resume before every independently submitted transaction. Do not regenerate a journal after
//    a failed simulation or Safe CALL. Repair the actual approval/authority/callback condition,
//    then resume the same file with its original hash: its next call bytes/value stay identical.
export async function resumeInventoryOpening(workflow, provider, journalPath, originalHash, blockTag = "latest") {
  const saved = workflow.restore(await readFile(journalPath, "utf8"), originalHash);
  const step = await workflow.resume(provider, saved, blockTag);
  return { saved, step, next: step.prepared ? workflow.safeCall(step) : null };
}

// 4. After a confirmed direct Safe CALL, check its independently verified Safe transaction hash
//    and original deposit/open events, then resume again. An outer success receipt is insufficient.
export function verifyInventoryStep(workflow, saved, priorStep, receipt, originalSafeTransactionHash) {
  if (priorStep.status !== "deposit" && priorStep.status !== "open") throw Error("No submitted inventory step");
  workflow.verifyStepReceipt(saved, priorStep.status, priorStep.tokenId, receipt, originalSafeTransactionHash);
}

// An "opened" result observes the completed opening state, even if later token purchases occurred.
// It does not claim who opened the inventory. "cancelled" / "expired" are separate terminal exits:
// use the existing own-account or delegated NFT/refund claim helpers; never recreate a listing here.
