// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    IStreamArtistRecoveryEvidence
} from "../../interfaces/stream/artist/IStreamArtistRecoveryEvidence.sol";
import {
    StreamArtistRecoveryEvidenceTypes as E
} from "../../interfaces/stream/artist/StreamArtistRecoveryEvidenceTypes.sol";
import {
    StreamArtistGuardianAppealTypes as Appeal
} from "../../interfaces/stream/artist/StreamArtistGuardianAppealTypes.sol";

/// @notice Permissionless, immutable evidence for one constructor-bound Identity environment.
/// @dev Only grammar is checked here. Owner admission authenticates ancestry, chronology, current
/// cause, revision, role, findings and selection; publication grants no authority or replay right.
contract StreamArtistRecoveryEvidence is IStreamArtistRecoveryEvidence {
    address public immutable override owner;
    address public immutable override artistRegistry;
    uint256 public immutable override deploymentChainId;
    address public immutable override coordinator;
    address public immutable override archive;
    address public immutable override core;
    address public immutable override mintManager;

    mapping(bytes32 => E.ResolutionManifest) private _manifests;
    mapping(bytes32 => bytes32) private _manifestOwnerCodeHashes;
    mapping(bytes32 => E.AppealDocumentV2) private _appeals;
    mapping(bytes32 => bytes32) private _appealOwnerCodeHashes;

    constructor(
        address owner_,
        address registry_,
        address coordinator_,
        address archive_,
        address core_,
        address manager_
    ) {
        // The fixed owner may not have finished construction; do not require its code yet.
        if (
            owner_ == address(0) || registry_ == address(0) || owner_ == registry_
                || coordinator_ == address(0) || archive_ == address(0) || core_ == address(0)
                || manager_ == address(0)
        ) revert E.InvalidRecoveryManifest(bytes32(0));
        owner = owner_;
        artistRegistry = registry_;
        deploymentChainId = block.chainid;
        coordinator = coordinator_;
        archive = archive_;
        core = core_;
        mintManager = manager_;
    }

    function publishResolutionManifest(E.ResolutionManifest calldata manifest)
        external
        override
        returns (bytes32 hash)
    {
        bytes32 observed = _ownerCodeHash();
        _manifestShape(manifest);
        hash = E.manifestHash(
            deploymentChainId,
            artistRegistry,
            owner,
            observed,
            coordinator,
            archive,
            core,
            mintManager,
            manifest
        );
        bytes32 retained = _manifestOwnerCodeHashes[hash];
        if (retained != 0) {
            if (retained != observed) revert E.RecoveryEvidenceDependencyChanged(owner);
            return hash;
        }
        _manifests[hash] = manifest;
        _manifestOwnerCodeHashes[hash] = observed;
        emit RecoveryResolutionManifestPublished(
            1, hash, manifest.artistId, manifest.causeHash, manifest.ownerRevision, observed
        );
    }

    function resolutionManifest(bytes32 hash)
        external
        view
        override
        returns (E.ResolutionManifest memory, bytes32)
    {
        bytes32 observed = _manifestOwnerCodeHashes[hash];
        if (observed == 0) revert E.InvalidRecoveryManifest(hash);
        return (_manifests[hash], observed);
    }

    function publishAppealV2(E.AppealDocumentV2 calldata document)
        external
        override
        returns (bytes32 hash)
    {
        bytes32 observed = _ownerCodeHash();
        _appealShape(document);
        hash = E.appealHash(deploymentChainId, artistRegistry, owner, document);
        bytes32 retained = _appealOwnerCodeHashes[hash];
        if (retained != 0) {
            if (retained != observed) revert E.RecoveryEvidenceDependencyChanged(owner);
            return hash;
        }
        _appeals[hash] = document;
        _appealOwnerCodeHashes[hash] = observed;
        emit RecoveryAppealEvidencePublished(2, hash, document.resolutionManifestHash, observed);
    }

    function appealEvidenceV2(bytes32 hash)
        external
        view
        override
        returns (E.AppealDocumentV2 memory, bytes32)
    {
        bytes32 observed = _appealOwnerCodeHashes[hash];
        if (observed == 0) revert E.InvalidRecoveryAppealEvidence(hash);
        return (_appeals[hash], observed);
    }

    function _ownerCodeHash() private view returns (bytes32) {
        if (block.chainid != deploymentChainId || owner.code.length == 0) {
            revert E.RecoveryEvidenceDependencyChanged(owner);
        }
        return owner.codehash;
    }

    function _manifestShape(E.ResolutionManifest calldata m) private pure {
        uint256 count = m.contestedVestings.length;
        if (
            m.artistId == 0 || m.ownerRevision == 0 || m.causeHash == 0 || m.requestCommitment == 0
                || m.resolutionEvidenceHash == 0 || count > E.MAX_DECLARED_VESTINGS
                || m.supersededRecordHashes.length > E.MAX_SUPERSESSIONS
                || (m.basis == E.VestingBasis.NO_CONTESTED_VESTING
                        ? count != 0
                        : count == 0 || m.executedHead == 0)
        ) revert E.InvalidRecoveryManifest(bytes32(0));
        for (uint256 i; i < count; ++i) {
            E.VestingReference calldata item = m.contestedVestings[i];
            if (item.transitionRecordHash == 0 || item.vestingCommitment == 0) {
                revert E.InvalidRecoveryManifest(bytes32(0));
            }
            // Preserve the declared chronological order; hash sorting would invent a chronology.
            for (uint256 j; j < i; ++j) {
                if (
                    m.contestedVestings[j].transitionRecordHash == item.transitionRecordHash
                        || m.contestedVestings[j].vestingCommitment == item.vestingCommitment
                ) revert E.InvalidRecoveryManifest(bytes32(0));
            }
        }
        bytes32 previous;
        for (uint256 i; i < m.supersededRecordHashes.length; ++i) {
            bytes32 record = m.supersededRecordHashes[i];
            if (record <= previous) revert E.InvalidRecoveryManifest(bytes32(0));
            previous = record;
        }
    }

    function _appealShape(E.AppealDocumentV2 calldata d) private pure {
        if (
            d.resolutionManifestHash == 0 || d.hostileFindingsHash == 0 || d.findings.length == 0
                || d.findings.length > E.MAX_SUPERSESSIONS
        ) revert E.InvalidRecoveryAppealEvidence(bytes32(0));
        bytes32 previous;
        for (uint256 i; i < d.findings.length; ++i) {
            Appeal.Finding calldata finding = d.findings[i];
            if (
                finding.guardianRecordHash <= previous || finding.parties.length == 0
                    || finding.parties.length > E.MAX_FINDING_PARTIES
            ) revert E.InvalidRecoveryAppealEvidence(bytes32(0));
            address prior;
            for (uint256 j; j < finding.parties.length; ++j) {
                if (finding.parties[j] <= prior) {
                    revert E.InvalidRecoveryAppealEvidence(bytes32(0));
                }
                prior = finding.parties[j];
            }
            previous = finding.guardianRecordHash;
        }
    }
}
