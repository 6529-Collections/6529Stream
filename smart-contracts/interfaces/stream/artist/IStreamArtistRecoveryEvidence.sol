// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { StreamArtistRecoveryEvidenceTypes as E } from "./StreamArtistRecoveryEvidenceTypes.sol";

/// @notice Fixed-suite immutable content publication. Publication is not adjudication authority.
interface IStreamArtistRecoveryEvidence {
    event RecoveryResolutionManifestPublished(
        uint16 schemaVersion,
        bytes32 indexed manifestHash,
        bytes32 indexed artistId,
        bytes32 indexed causeHash,
        uint64 ownerRevision,
        bytes32 ownerCodeHash
    );
    event RecoveryAppealEvidencePublished(
        uint16 schemaVersion,
        bytes32 indexed documentHash,
        bytes32 indexed resolutionManifestHash,
        bytes32 ownerCodeHash
    );

    function owner() external view returns (address);
    function artistRegistry() external view returns (address);
    function deploymentChainId() external view returns (uint256);
    function coordinator() external view returns (address);
    function archive() external view returns (address);
    function core() external view returns (address);
    function mintManager() external view returns (address);
    function publishResolutionManifest(E.ResolutionManifest calldata manifest)
        external
        returns (bytes32);
    function resolutionManifest(bytes32 manifestHash)
        external
        view
        returns (E.ResolutionManifest memory, bytes32 ownerCodeHash);
    function publishAppealV2(E.AppealDocumentV2 calldata document) external returns (bytes32);
    function appealEvidenceV2(bytes32 documentHash)
        external
        view
        returns (E.AppealDocumentV2 memory, bytes32 ownerCodeHash);
}

/// @notice Constructor-pinned publisher on the fixed Identity recovery extension.
interface IStreamArtistRecoveryEvidenceBinding {
    function recoveryEvidenceBinding() external view returns (address, bytes32);
}
