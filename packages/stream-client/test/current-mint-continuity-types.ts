import type { Address, Hex } from "../src/generated/contracts.js";
import { buildMintContinuityArtifact, prepareCounterDefinitionImport, prepareMintAncestryImport, prepareMintStateImport } from "../src/current-mint-continuity.js";
declare const address: Address, hash: Hex;
const artifact = buildMintContinuityArtifact({ coordinates: { chainId: 1n, successorLedger: address, predecessorLedger: address, predecessorManager: address, successorManager: address, snapshotBlock: 1n }, counterLeaves: [], nullifiers: [], inventoryCompletenessReviewed: true });
prepareCounterDefinitionImport(artifact, 1n); prepareMintAncestryImport(artifact, 1n); prepareMintStateImport(artifact, address, [], [0]);
// @ts-expect-error bounded counts use exact bigints
prepareCounterDefinitionImport(artifact, 1);
// @ts-expect-error completeness review assertion is required
buildMintContinuityArtifact({ coordinates: artifact.coordinates, counterLeaves: [], nullifiers: [hash] });
