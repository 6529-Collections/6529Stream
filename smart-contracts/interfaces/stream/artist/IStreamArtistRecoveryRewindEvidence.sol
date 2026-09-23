// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { StreamArtistRecoveryRewindTypes as W } from "./StreamArtistRecoveryRewindTypes.sol";

/// @notice Permissionless V3 content retention; original owner records decide semantic admission.
interface IStreamArtistRecoveryRewindEvidence {
    event RecoveryRewindManifestPublished(
        bytes32 indexed manifestHash,
        bytes32 indexed artistId,
        bytes32 indexed causeHash,
        bytes32 identityCodeHash,
        bytes32 payoutCodeHash
    );
    event RecoveryRewindAppealPublished(
        bytes32 indexed documentHash,
        bytes32 indexed manifestHash,
        bytes32 identityCodeHash,
        bytes32 payoutCodeHash
    );
    event RecoveryPayoutOriginalPublished(
        bytes32 indexed evidenceHash,
        bytes32 indexed recordHash,
        bytes32 indexed artistId,
        bytes32 identityCodeHash,
        bytes32 payoutCodeHash
    );

    function owner() external view returns (address);
    function payoutOwner() external view returns (address);
    function artistRegistry() external view returns (address);
    function deploymentChainId() external view returns (uint256);
    function coordinator() external view returns (address);
    function archive() external view returns (address);
    function core() external view returns (address);
    function mintManager() external view returns (address);
    function publishResolutionManifestV3(W.ResolutionManifestV3 calldata manifest)
        external
        returns (bytes32);
    function resolutionManifestV3(bytes32 hash)
        external
        view
        returns (W.ResolutionManifestV3 memory, bytes32 identityCodeHash, bytes32 payoutCodeHash);
    function publishAppealV3(W.AppealDocumentV3 calldata document) external returns (bytes32);
    function appealEvidenceV3(bytes32 hash)
        external
        view
        returns (W.AppealDocumentV3 memory, bytes32 identityCodeHash, bytes32 payoutCodeHash);
    function publishPayoutOriginalV3(W.PayoutOriginalV3 calldata original)
        external
        returns (bytes32);
    function payoutOriginalV3(bytes32 recordHash)
        external
        view
        returns (
            W.PayoutOriginalV3 memory,
            bytes32 evidenceHash,
            bytes32 identityCodeHash,
            bytes32 payoutCodeHash
        );
}

interface IStreamArtistRecoveryRewindEvidenceBinding {
    function recoveryRewindEvidenceBinding() external view returns (address, bytes32);
}
