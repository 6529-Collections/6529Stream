// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamArtistGuardianAppealTypes as A
} from "../../interfaces/stream/artist/StreamArtistGuardianAppealTypes.sol";

/// @notice Immutable public content retained by Identity's fixed recovery child.
/// @dev Publication does not authenticate findings, choose an appeal tier or create a pending recovery.
contract StreamArtistGuardianAppealEvidence {
    address public immutable owner;
    address public immutable artistRegistry;
    uint256 public immutable deploymentChainId;
    mapping(bytes32 => A.Document) private _documents;
    mapping(bytes32 => bytes32) private _ownerCodeHashes;

    event GuardianAppealEvidencePublished(
        bytes32 indexed documentHash, bytes32 indexed contestRecordHash
    );

    constructor(address owner_, address registry_) {
        // The fixed Identity owner has not finished construction yet.
        if (owner_ == address(0) || registry_ == address(0) || owner_ == registry_) {
            revert A.InvalidGuardianAppeal(bytes32(0));
        }
        owner = owner_;
        artistRegistry = registry_;
        deploymentChainId = block.chainid;
    }

    function publish(A.Document calldata document) external returns (bytes32 hash) {
        if (block.chainid != deploymentChainId || owner.code.length == 0) {
            revert A.GuardianAppealDependencyChanged(owner);
        }
        if (
            document.requestCommitment == 0 || document.causeHash == 0
                || document.contestRecordHash == 0 || document.vestingCommitment == 0
                || document.transitionRecordHash == 0 || document.hostileFindingsHash == 0
                || document.findings.length == 0 || document.findings.length > 64
        ) {
            revert A.InvalidGuardianAppeal(bytes32(0));
        }
        bytes32 previous;
        for (uint256 i; i < document.findings.length; ++i) {
            A.Finding calldata finding = document.findings[i];
            if (
                finding.guardianRecordHash <= previous || finding.parties.length == 0
                    || finding.parties.length > 8
            ) {
                revert A.InvalidGuardianAppeal(finding.guardianRecordHash);
            }
            address prior;
            for (uint256 j; j < finding.parties.length; ++j) {
                if (finding.parties[j] <= prior) {
                    revert A.InvalidGuardianAppeal(finding.guardianRecordHash);
                }
                prior = finding.parties[j];
            }
            previous = finding.guardianRecordHash;
        }
        hash = A.documentHash(deploymentChainId, artistRegistry, owner, document);
        bytes32 recorded = _ownerCodeHashes[hash];
        if (recorded != 0) {
            if (recorded != owner.codehash) revert A.GuardianAppealDependencyChanged(owner);
            return hash;
        }
        _documents[hash] = document;
        _ownerCodeHashes[hash] = owner.codehash;
        emit GuardianAppealEvidencePublished(hash, document.contestRecordHash);
    }

    function evidence(bytes32 hash) external view returns (A.Document memory, bytes32) {
        if (_ownerCodeHashes[hash] == 0) revert A.InvalidGuardianAppeal(hash);
        return (_documents[hash], _ownerCodeHashes[hash]);
    }
}
