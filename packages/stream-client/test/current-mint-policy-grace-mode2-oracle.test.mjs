import test from "node:test";
import assert from "node:assert/strict";
import { createHash } from "node:crypto";
import { readFileSync } from "node:fs";

const read = name => JSON.parse(readFileSync(new URL(`./fixtures/${name}.json`, import.meta.url), "utf8"));
const legacy = read("current-mint-policy-grace-abi");
const current = read("current-mint-policy-grace-mode2-abi");
const mint = "smart-contracts/domains/mint/", governance = "smart-contracts/domains/governance/";

test("mode2 grace fixture binds the separate exact ABI56 capture and retained source texts", () => {
  assert.equal(current.sourceCommit, "ed4d557246a98698167d6986bc4266d9e375d558");
  assert.equal(current.sourceCount, 2241);
  assert.equal(current.inputSha256, "6aec6f59bb3037d83ee9a3bc2a3a1552bfac224c4b8cbf7bbe9ec79ce6c253c7");
  assert.equal(current.outputSha256, "7423844d40d9ee2982473692bee53bb482f578a90e90e340f95d06469cbe3aaf");
  assert.equal(Object.keys(current.sourceHashes).length, 543);
  assert.equal(Object.keys(current.sourceTexts).length, 15);
  for (const [path, literal] of Object.entries(current.sourceTexts)) {
    assert.equal(createHash("sha256").update(literal).digest("hex"), current.sourceHashes[path]);
  }
  assert.match(current.qualification, /do not establish native/);
});

test("mode2 keeps every historical ABI entry, policy preimage and Ledger/governance source unchanged", () => {
  assert.equal(legacy.sourceCommit, "44af244ed576cc4b26632b800fe70a068d577940");
  assert.equal(legacy.sourceCount, 2212);
  assert.deepEqual(current.abis, legacy.abis);
  assert.equal(Object.values(current.abis).reduce((n, rows) => n + rows.length, 0), 197);
  for (const path of [mint + "StreamMintOperationIdentity.sol", mint + "StreamMintPhaseState.sol", mint + "StreamMintLedger.sol",
    governance + "StreamGovernanceBootstrap.sol", governance + "StreamGovernanceScheduling.sol",
    governance + "StreamGovernanceActionPolicy.sol", governance + "StreamGovernanceExecutor.sol"]) {
    assert.equal(current.sourceHashes[path], legacy.sourceHashes[path], path);
  }
});

test("mode2 registration still requires the original exact durable policy evidence and current mint checks", () => {
  const before = legacy.sourceTexts[mint + "StreamMintArtistConsent.sol"];
  const after = current.sourceTexts[mint + "StreamMintArtistConsent.sol"];
  assert.match(before, /mode != 1 && mode != 3/);
  assert.match(after, /mode != 1 && mode != 2 && mode != 3/);
  const registration = after.slice(after.indexOf("function registration("), after.indexOf("function mint("));
  assert.match(registration, /IStreamArtistMintConsent\.isPolicyConsented, \(collectionId, phaseId, policyHash\)/);
  assert.match(registration, /if \(!consented \|\| evidence == bytes32\(0\)\)/);
  assert.match(registration, /IStreamArtistMintConsent\.requireMintConsent, \(collectionId, phaseId, policyHash\)/);
  assert.doesNotMatch(registration, /delegationRecord|delegationState|grantEpoch/);
  const reads = current.sourceTexts["smart-contracts/domains/artist/StreamArtistOnboardingReads.sol"];
  assert.match(reads, /personhoodAttestation\(collectionId, b\.artistId\)/);
});

test("linked Manager worker preserves original no-op, refresh and Manager event order", () => {
  const manager = current.sourceTexts[mint + "StreamMintManager.sol"];
  assert.match(manager, /StreamMintManagerPolicy\.updateExecutor\(/);
  const worker = current.sourceTexts[mint + "StreamMintManagerPolicy.sol"];
  const update = worker.slice(worker.indexOf("function updateExecutor("), worker.indexOf("function _refresh("));
  assert.match(update, /if \(update\.graceUntil != 0\)/);
  assert.match(update, /revert IStreamMintLedger\.InvalidPolicyGrace\(update\.graceUntil\)/);
  assert.ok(update.indexOf("return;") < update.indexOf("bytes32 policyHash = _refresh("));
  assert.ok(update.indexOf("emit MintPhaseExecutorUpdated(") > update.indexOf("bytes32 policyHash = _refresh("));
  assert.match(update, /policyHash,\s+msg\.sender/);
  const refresh = worker.slice(worker.indexOf("function _refresh("), worker.indexOf("function _recordArtistConsent("));
  const order = ["StreamMintManagerAccounting.ledgerPolicies(", "policyHash = _computePolicyHash(",
    "_recordArtistConsent(", "policyHashes[phaseId] = policyHash", ".registerPhasePolicy("].map(token => refresh.indexOf(token));
  assert.ok(order.every((n, i) => n >= 0 && (i === 0 || n > order[i - 1])));
  assert.match(refresh, /address\(this\), collectionId, phaseId, policyHash, ids, ledgerPolicies, graceUntil/);
});
