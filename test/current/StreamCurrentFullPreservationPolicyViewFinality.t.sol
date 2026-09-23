// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../helpers/StreamCurrentFullPreservationPolicyViewInputFixture.sol";
import {
    IStreamSchemaRegistry as ViewFinalitySchema
} from "../../smart-contracts/interfaces/stream/metadata/IStreamSchemaRegistry.sol";
import {
    IStreamSchemaDocumentFacts as ViewFinalityDocuments
} from "../../smart-contracts/interfaces/stream/metadata/IStreamSchemaDocumentFacts.sol";
import {
    StreamFinalityViewPreservationInputSchemasV1 as ViewFinalityDefinitions
} from "../../smart-contracts/domains/finality/StreamFinalityViewPreservationInputSchemasV1.sol";
import {
    StreamFinalityViewSanctionProfileV1 as ViewFinalityMediaProfile
} from "../../smart-contracts/domains/finality/StreamFinalityViewSanctionProfileV1.sol";
import {
    StreamPreservationInventoryTypes as ViewFinalityInventory
} from "../../smart-contracts/interfaces/stream/preservation/StreamPreservationInventoryTypes.sol";

/// @notice Explicit supplied-observation recipe through the actual original VIEW ceremony.
/// @dev This entry is not a default test, browser execution or measured transaction fit claim.
/// Input observations and complete package members must correspond to the constructed artwork.
contract StreamCurrentFullPreservationPolicyViewFinalityTest is
    StreamCurrentFullPreservationPolicyViewInputFixture
{
    /// @notice Export the actual current recipe to a fresh caller-selected directory.
    /// @dev The current Foundry profile permits artifacts/native-assembly. sourceRevision is
    /// caller provenance; the export additionally pins actual runtime and all current bytes.
    function exportViewFinalitySource(string memory outputDirectory, bytes20 sourceRevision)
        external
        returns (bytes32 sourceHash, bytes32 exportSHA256)
    {
        return _viewExportSource(outputDirectory, sourceRevision);
    }

    /// @param measuredArtistReadGas Zero retains the original parameter; a nonzero target must
    /// be justified by separate measurements. Original class1 governance enforces every raise.
    function runSuppliedViewFinalityObservation(
        string memory environmentJSON,
        string memory browserJSON,
        string memory capturesJSON,
        string memory packageMembersDirectory,
        uint256 measuredArtistReadGas
    ) external returns (bytes32 referenceRecord, bytes32 sanctionRecord, bytes32 finalityRecord) {
        return _runSuppliedViewFinalityObservation(
            environmentJSON,
            browserJSON,
            capturesJSON,
            packageMembersDirectory,
            measuredArtistReadGas
        );
    }

    /// @notice Load JSON contents, authenticate the full actual export, then use the same recipe.
    function runSuppliedViewFinalityObservationFiles(
        string memory sourceExportFile,
        bytes32 expectedExportSHA256,
        bytes20 expectedSourceRevision,
        string memory environmentFile,
        string memory browserFile,
        string memory capturesFile,
        string memory packageMembersDirectory,
        uint256 measuredArtistReadGas
    ) external returns (bytes32 referenceRecord, bytes32 sanctionRecord, bytes32 finalityRecord) {
        (string memory environmentJSON, string memory browserJSON, string memory capturesJSON) = _viewLoadSuppliedFiles(
            sourceExportFile,
            expectedExportSHA256,
            expectedSourceRevision,
            environmentFile,
            browserFile,
            capturesFile,
            packageMembersDirectory
        );
        return _runSuppliedViewFinalityObservation(
            environmentJSON,
            browserJSON,
            capturesJSON,
            packageMembersDirectory,
            measuredArtistReadGas
        );
    }

    function _runSuppliedViewFinalityObservation(
        string memory environmentJSON,
        string memory browserJSON,
        string memory capturesJSON,
        string memory packageMembersDirectory,
        uint256 measuredArtistReadGas
    ) private returns (bytes32 referenceRecord, bytes32 sanctionRecord, bytes32 finalityRecord) {
        require(
            bytes(environmentJSON).length != 0 && bytes(browserJSON).length != 0
                && bytes(capturesJSON).length != 0 && bytes(packageMembersDirectory).length != 0,
            "explicit complete observation inputs required"
        );
        _viewPrepareInputSource();
        viewPackageMembersDirectory = packageMembersDirectory;
        _viewPrepareReferenceDefinitions();
        _viewPublishReference(environmentJSON, browserJSON, capturesJSON);
        ViewFinalityInventory.Item[][] memory rows = _viewMaterializeInventory();
        _viewCoverCompleteBundle(rows);
        if (measuredArtistReadGas != 0) {
            _viewRaiseMeasuredSanctionReadBudget(measuredArtistReadGas);
        }
        _viewPerformSanctionAndFinality();
        return (assemblyViewReferenceRecord, viewSanctionRecord, viewFinalityRecord);
    }

    function testViewSourceExportRejectsMissingRevisionBeforeConstruction() external {
        (bool ok, bytes memory reason) = address(this)
            .call(
                abi.encodeCall(
                    this.exportViewFinalitySource,
                    ("artifacts/native-assembly/view-refusal", bytes20(0))
                )
            );
        require(
            !ok
                && keccak256(reason)
                    == keccak256(
                        abi.encodeWithSignature(
                            "Error(string)", "explicit source revision provenance"
                        )
                    ) && address(assemblyCore) == address(0),
            "missing revision refuses before construction or writes"
        );
    }

    function testViewSourceExportRejectsTraversalBeforeConstruction() external {
        (bool ok, bytes memory reason) = address(this)
            .call(
                abi.encodeCall(
                    this.exportViewFinalitySource,
                    ("artifacts/native-assembly/../view-refusal", bytes20(uint160(1)))
                )
            );
        require(
            !ok
                && keccak256(reason)
                    == keccak256(
                        abi.encodeWithSignature(
                            "Error(string)", "no relative traversal path segments"
                        )
                    ) && address(assemblyCore) == address(0),
            "traversal refuses before construction or writes"
        );
    }

    function testViewSuppliedFilesRejectMissingPinsBeforeConstruction() external {
        (bool ok, bytes memory reason) = address(this)
            .call(
                abi.encodeCall(
                    this.runSuppliedViewFinalityObservationFiles,
                    (
                        "artifacts/native-assembly/source.json",
                        bytes32(0),
                        bytes20(uint160(1)),
                        "environment.json",
                        "browser.json",
                        "captures.json",
                        "members",
                        uint256(0)
                    )
                )
            );
        require(
            !ok
                && keccak256(reason)
                    == keccak256(
                        abi.encodeWithSignature(
                            "Error(string)", "explicit pinned source export required"
                        )
                    ) && address(assemblyCore) == address(0),
            "unanchored files refuse before construction or reads"
        );
    }

    function _viewPrepareFinalityDefinitions() internal override {
        _viewRegisterFinalityDefinition(
            "STREAM_VIEW_PRESERVATION_FINALITY_INPUT_V1",
            ViewFinalityDefinitions.SCHEMA_ID,
            ViewFinalitySchema.DocumentKind.SCHEMA,
            ViewFinalityDefinitions.document(ViewFinalityDefinitions.SCHEMA_ID)
        );
        _viewRegisterFinalityDefinition(
            "STREAM_VIEW_PRESERVATION_FINALITY_INPUT_ABI_V1",
            ViewFinalityDefinitions.CANON_ID,
            ViewFinalitySchema.DocumentKind.CANONICALIZATION,
            ViewFinalityDefinitions.document(ViewFinalityDefinitions.CANON_ID)
        );
        _viewRegisterFinalityDefinition(
            "6529STREAM_ARTIST_SANCTION_VIEW_MEDIA_V1",
            ViewFinalityMediaProfile.ID,
            ViewFinalitySchema.DocumentKind.CATALOG,
            ViewFinalityMediaProfile.document()
        );
        ViewFinalityMediaProfile.requireCurrent(
            address(assemblySchemas),
            address(assemblySchemas).codehash,
            address(assemblyStore),
            address(assemblyStore).codehash,
            500000
        );
    }

    function _viewRegisterFinalityDefinition(
        string memory name,
        bytes32 id,
        ViewFinalitySchema.DocumentKind kind,
        bytes memory raw
    ) private {
        bytes32 registered = _assemblyRegisterDocument(name, kind, raw, assemblySchemas.RAW_BYTES());
        ViewFinalityDocuments.DocumentFacts memory facts = assemblySchemas.documentFacts(id);
        require(
            registered == id && id == keccak256(bytes(name)) && facts.exists && facts.kind == kind
                && facts.status == ViewFinalitySchema.DocumentStatus.ACTIVE
                && facts.contentHash == keccak256(raw)
                && facts.canonicalizationId == assemblySchemas.RAW_BYTES()
                && facts.supersedesId == 0 && facts.chunkCount == 1
                && facts.totalBytes == raw.length && facts.declarationHash != 0
                && keccak256(assemblySchemas.documentBytes(id)) == keccak256(raw)
                && keccak256(assemblyStore.readChunk(keccak256(raw))) == keccak256(raw),
            "exact VIEW producer definition and complete registered bytes"
        );
    }
}
