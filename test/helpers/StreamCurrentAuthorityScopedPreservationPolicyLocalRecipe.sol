// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    StreamCurrentAuthorityScopedPreservationPolicyBytesFixture
} from "./StreamCurrentAuthorityScopedPreservationPolicyBytesFixture.sol";
import {
    StreamCurrentAuthorityScopedPreservationPolicyExportFixture
} from "./StreamCurrentAuthorityScopedPreservationPolicyExportFixture.sol";
import {
    StreamCurrentAuthorityScopedPreservationPolicyBundleFixture
} from "./StreamCurrentAuthorityScopedPreservationPolicyBundleFixture.sol";
import {
    StreamFinalityScope,
    StreamFinalityScopeType
} from "../../smart-contracts/interfaces/stream/finality/StreamArtworkFinalityTypes.sol";

/// @notice Explicit local V2 preservation simulation entrypoints for fresh source capture and coverage.
/// @dev This is a fixture, not a broadcast/deployment script or a default test with optional skips.
/// Export constructs the actual graph. Coverage can resume its exact exported instance or replay
/// the identical clean local EVM state; the real reference publisher verifies the onchain joins.
/// Production rejection boundaries remain in force. No sanction or Finality success is claimed.
contract StreamCurrentAuthorityScopedPreservationPolicyLocalRecipe is
    StreamCurrentAuthorityScopedPreservationPolicyBytesFixture,
    StreamCurrentAuthorityScopedPreservationPolicyBundleFixture,
    StreamCurrentAuthorityScopedPreservationPolicyExportFixture
{
    bytes32 public exportedSourceHash;
    bool public exportConsumed;

    struct ScopedRecipeFiles {
        string environmentJSON;
        string browserJSON;
        string capturesJSON;
        string[] packageProofs;
    }

    struct ScopedRecipeResult {
        StreamFinalityScope scope;
        uint8 authorityEra;
        bytes32 rootRecord;
        bytes32 snapshotRecord;
        bytes32 referenceRecord;
        bytes32 workRecord;
        bytes32 rightsRecord;
        bytes32 interviewRecord;
        bytes32 intentRecord;
        bytes32 inventoryPlan;
        bytes32 renderCriticalEvidence;
        bytes32 bundleCoverage;
        bytes32 authorityCapture;
        uint64 itemCount;
        uint256 uniqueByteObjects;
        uint256 packageMembers;
        uint256 emptyPackageMembers;
        uint256 originStateBundles;
    }

    /// @notice Construct original A and export only actual current bytes and source identities.
    function exportScopedSources(
        StreamFinalityScopeType kind,
        string memory directory,
        string memory label
    ) external returns (AuthorityScopedPreservationExport memory) {
        AuthorityScopedPublication memory publication = _setupScopedRecipe(kind);
        AuthorityScopedPreservationExport memory result =
            _authorityExportScopedPreservationPolicySources(publication, directory, label);
        exportedSourceHash = result.sourceHash;
        return result;
    }

    /// @notice Resume this exact original fixture after a separate in-process capture step.
    /// @dev sourceABI is the raw decoded bytes of source-identity.abi.hex. Only its hash is kept
    /// in storage; the complete exported packet must be supplied unchanged. A failed call rolls
    /// back this marker and protocol writes; exact retry also requires restoring the local VM
    /// clock/environment.
    function coverExportedScopedSources(
        bytes memory sourceABI,
        uint8 era,
        ScopedRecipeFiles memory files,
        AuthorityScopedEndpoint[] memory largeByteProofs
    ) external returns (ScopedRecipeResult memory) {
        require(
            exportedSourceHash != 0 && !exportConsumed
                && keccak256(sourceABI) == exportedSourceHash,
            "exact unconsumed export from this fixture instance"
        );
        (
            bytes32 domain,
            ScopedPreservationExportContext memory context,
            AuthorityScopedPublication memory publication,
            ScopedPreservationExportToken[] memory tokens
        ) = abi.decode(
            sourceABI,
            (
                bytes32,
                ScopedPreservationExportContext,
                AuthorityScopedPublication,
                ScopedPreservationExportToken[]
            )
        );
        require(
            domain == keccak256("6529STREAM_CURRENT_AUTHORITY_SCOPED_PRESERVATION_SOURCE_EXPORT_V2")
                && context.schemaVersion == 2
                && context.preservationFamily
                    == keccak256("6529STREAM_TOKEN_PRESERVATION_FAMILY_V2")
                && context.exporter == address(this) && context.chainId == block.chainid
                && context.targets[0] == address(assemblyCore)
                && tokens.length == publication.checkpoint.tokenCount
                && keccak256(abi.encode(domain, context, publication, tokens)) == exportedSourceHash
        );
        exportConsumed = true;
        return _coverScopedRecipe(publication, era, files, largeByteProofs);
    }

    /// @notice Replay the exact original setup, consume explicit fresh observations, and cover
    /// every actual byte occurrence under original A (0), current B (1), or current C (2).
    /// @dev A fresh replay must use the same fixture address/deployer nonce, linked artifacts,
    /// chain and initial EVM state as its export, or its actual source joins will reject. A second
    /// deployment at another address in the same EVM is not that replay; use the resume entry.
    /// Large byte objects require their genuine supplied endpoint proofs. Package files are
    /// read one at a time in the streaming proof helper, not accumulated as endpoint buffers.
    function coverScopedSources(
        StreamFinalityScopeType kind,
        uint8 era,
        ScopedRecipeFiles memory files,
        AuthorityScopedEndpoint[] memory largeByteProofs
    ) external returns (ScopedRecipeResult memory result) {
        AuthorityScopedPublication memory publication = _setupScopedRecipe(kind);
        return _coverScopedRecipe(publication, era, files, largeByteProofs);
    }

    function _coverScopedRecipe(
        AuthorityScopedPublication memory publication,
        uint8 era,
        ScopedRecipeFiles memory files,
        AuthorityScopedEndpoint[] memory largeByteProofs
    ) private returns (ScopedRecipeResult memory result) {
        require(era <= 2 && authorityEra == 0, "explicit original/B/C fixture era");
        AuthorityScopedReference memory referenceResult =
            _authorityPublishScopedPreservationPolicyReference(
                publication,
                assemblyVm.readFile(files.environmentJSON),
                assemblyVm.readFile(files.browserJSON),
                assemblyVm.readFile(files.capturesJSON),
                true
            );
        ScopedRecordHeads memory heads;
        if (era != 0) _authorityMigrateNext();
        heads.contentTag = era == 0
            ? keccak256("A original scoped ceremony records")
            : keccak256("B original scoped ceremony records");
        ScopedRecordSet memory records = _publishScopedRecords(publication.scope, heads);
        AuthorityScopedRights memory rightsResult = _authorityPublishScopedRights(publication.scope);
        if (era == 2) {
            heads.workHead = records.workPublication.recordHash;
            heads.workRevision = records.workSelection.revision;
            heads.intentHead = records.intentPublication.recordHash;
            heads.intentRevision = records.intentSelection.revision;
            heads.interviewPredecessor = records.interviewPublication.recordHash;
            heads.contentTag = keccak256("C successor scoped ceremony records");
            _authorityMigrateNext();
            records = _publishScopedRecords(publication.scope, heads);
        }
        _authoritySealScopedRecords(records, rightsResult);
        AuthorityScopedInventory memory inventoryResult = _authorityMaterializeScopedInventory(
            publication, referenceResult, records, rightsResult.statement
        );
        bytes[] memory sourceBytes = _authorityCollectScopedSourceBytes(
            publication, referenceResult, inventoryResult, records, rightsResult
        );
        AuthorityScopedBundle memory bundleResult = _authorityCoverScopedBundle(
            publication,
            referenceResult,
            inventoryResult,
            sourceBytes,
            files.packageProofs,
            largeByteProofs
        );
        _authorityRequireOriginals();
        _authorityRequireRoute();
        require(authorityEra == era && bundleResult.evidence.coverage.bundleCoverageHash != 0);
        result.scope = publication.scope;
        result.authorityEra = era;
        result.rootRecord = publication.rootHash;
        result.snapshotRecord = publication.snapshot.recordHash;
        result.referenceRecord = referenceResult.recordHash;
        result.workRecord = records.workPublication.recordHash;
        result.rightsRecord = rightsResult.recordHash;
        result.interviewRecord = records.interviewPublication.recordHash;
        result.intentRecord = records.intentPublication.recordHash;
        result.inventoryPlan = inventoryResult.planId;
        result.renderCriticalEvidence =
        inventoryResult.evidence.inventory.renderCriticalEvidenceHash;
        result.bundleCoverage = bundleResult.evidence.coverage.bundleCoverageHash;
        result.authorityCapture = inventoryResult.authorityCaptureHash;
        result.itemCount = inventoryResult.evidence.inventory.itemCount;
        result.uniqueByteObjects = sourceBytes.length;
        result.packageMembers = bundleResult.packageMembers;
        result.emptyPackageMembers = bundleResult.emptyPackageMembers;
        result.originStateBundles = bundleResult.stateBundles;
    }

    function _setupScopedRecipe(StreamFinalityScopeType kind)
        private
        returns (AuthorityScopedPublication memory publication)
    {
        require(address(assemblyCore) == address(0), "fresh local fixture contract per call");
        require(
            kind == StreamFinalityScopeType.TOKEN || kind == StreamFinalityScopeType.RELEASE
                || kind == StreamFinalityScopeType.SEASON,
            "explicit supported scoped recipe"
        );
        _deployAssemblyGraph();
        _activateAssemblyArtwork();
        _authorityRecoverOriginal();
        _assemblyPrepareDescriptionDefinitions();
        _assemblySelectDescriptionsAndWaiver();
        publication = _authorityPublishScopedPreservationPolicy(kind);
        _authorityCaptureOriginalPreservation();
    }
}
