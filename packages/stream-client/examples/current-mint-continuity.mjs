import { keccak256, toUtf8Bytes } from "ethers";
import { buildMintContinuityArtifact, mintCounterSubjectBasis, mintCounterSubjectKey, prepareCounterDefinitionImport, prepareMintAncestryImport, prepareMintImportCommit, prepareMintStateImport } from "../dist/current-mint-continuity.js";

// Offline illustrative values only: no deployment, owner, retirement, governance execution or send is implied.
const h = x => keccak256(toUtf8Bytes(x)), chainId = 1n;
const coordinates = { chainId, successorLedger: "0x2000000000000000000000000000000000000002", predecessorLedger: "0x1000000000000000000000000000000000000001", predecessorManager: "0x3000000000000000000000000000000000000003", successorManager: "0x4000000000000000000000000000000000000004", snapshotBlock: 20_000_000n };
const basis = mintCounterSubjectBasis("0x5000000000000000000000000000000000000005"), draft = { collectionId: 6529n, phaseId: h("normalized-phase"), counterId: h("mint-count"), keyMode: 2n, subjectBasis: basis, predecessorSubjectKey: h("placeholder"), value: 3n };
const counter = { ...draft, predecessorSubjectKey: mintCounterSubjectKey(chainId, coordinates.predecessorLedger, draft) };
// This assertion must come from an external inventory review. The producer cannot infer completeness.
const artifact = buildMintContinuityArtifact({ coordinates, counterLeaves: [counter], nullifiers: [h("raw-gate-nullifier")], inventoryCompletenessReviewed: true });
console.log({ manifestBytes: artifact.manifestBytes, manifestHash: artifact.manifestHash, importRoot: artifact.importRoot,
  governedCommit: prepareMintImportCommit(artifact), permissionlessProfileCopy: prepareCounterDefinitionImport(artifact, 32n),
  permissionlessOlderAncestryCopy: prepareMintAncestryImport(artifact, 32n),
  ownerImport: prepareMintStateImport(artifact, "0x6000000000000000000000000000000000000006", [0], [0]),
  next: "Reconcile exact import receipts/events; never infer used leaves from aggregate counts." });
