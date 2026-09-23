// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    IStreamArtistRecoveryRewindEvidence
} from "../../interfaces/stream/artist/IStreamArtistRecoveryRewindEvidence.sol";
import {
    StreamArtistRecoveryRewindTypes as W
} from "../../interfaces/stream/artist/StreamArtistRecoveryRewindTypes.sol";
import {
    StreamArtistRecoveryEvidenceTypes as E
} from "../../interfaces/stream/artist/StreamArtistRecoveryEvidenceTypes.sol";
import {
    StreamArtistGuardianAppealTypes as Appeal
} from "../../interfaces/stream/artist/StreamArtistGuardianAppealTypes.sol";
import { StreamArtistHashes } from "./StreamArtistHashes.sol";
import {
    StreamArtistRecoveryRewindEnvironment as Environment
} from "./StreamArtistRecoveryRewindEnvironment.sol";

/// @notice Immutable, permissionless V3 evidence bound to the original initialized owner suite.
/// @dev Publication checks shape and supplied original hashes, not adjudication or original admission.
contract StreamArtistRecoveryRewindEvidence is IStreamArtistRecoveryRewindEvidence {
    address public immutable override owner;
    address public immutable override artistRegistry;
    uint256 public immutable override deploymentChainId;
    address public immutable override coordinator;
    address public immutable override archive;
    address public immutable override core;
    address public immutable override mintManager;

    struct Pins {
        bytes32 identity;
        bytes32 payout;
        bytes32 environmentHash;
    }
    mapping(bytes32 => W.ResolutionManifestV3) private _manifests;
    mapping(bytes32 => Pins) private _manifestPins;
    mapping(bytes32 => W.AppealDocumentV3) private _appeals;
    mapping(bytes32 => Pins) private _appealPins;
    mapping(bytes32 => W.PayoutOriginalV3) private _payoutOriginals;
    mapping(bytes32 => bytes32) private _payoutEvidenceHashes;
    mapping(bytes32 => Pins) private _payoutPins;

    constructor(
        address owner_,
        address registry_,
        address coordinator_,
        address archive_,
        address core_,
        address manager_
    ) {
        // Identity and the original Coordinator may both still be awaiting construction.
        if (
            owner_ == address(0) || registry_ == address(0) || coordinator_ == address(0)
                || archive_ == address(0) || core_ == address(0) || manager_ == address(0)
                || owner_ == registry_ || owner_ == coordinator_ || registry_ == coordinator_
                || core_ == manager_
        ) revert W.InvalidRecoveryRewindManifest(bytes32(0));
        owner = owner_;
        artistRegistry = registry_;
        deploymentChainId = block.chainid;
        coordinator = coordinator_;
        archive = archive_;
        core = core_;
        mintManager = manager_;
    }

    function payoutOwner() external view override returns (address) {
        return _environment().payoutOwner;
    }

    function publishResolutionManifestV3(W.ResolutionManifestV3 calldata manifest)
        external
        override
        returns (bytes32 hash)
    {
        W.EnvironmentV3 memory e = _environment();
        _manifestShape(manifest);
        hash = W.manifestHash(e, manifest);
        if (_manifestPins[hash].identity != 0) {
            _requirePins(e, _manifestPins[hash]);
            return hash;
        }
        _manifests[hash] = manifest;
        _manifestPins[hash] = Pins(e.identityCodeHash, e.payoutCodeHash, keccak256(abi.encode(e)));
        emit RecoveryRewindManifestPublished(
            hash, manifest.artistId, manifest.causeHash, e.identityCodeHash, e.payoutCodeHash
        );
    }

    function resolutionManifestV3(bytes32 hash)
        external
        view
        override
        returns (W.ResolutionManifestV3 memory, bytes32, bytes32)
    {
        Pins memory pins = _manifestPins[hash];
        if (pins.identity == 0) revert W.InvalidRecoveryRewindManifest(hash);
        _requirePins(_environment(), pins);
        return (_manifests[hash], pins.identity, pins.payout);
    }

    function publishAppealV3(W.AppealDocumentV3 calldata document)
        external
        override
        returns (bytes32 hash)
    {
        W.EnvironmentV3 memory e = _environment();
        _appealShape(document);
        hash = W.appealHash(e, document);
        if (_appealPins[hash].identity != 0) {
            _requirePins(e, _appealPins[hash]);
            return hash;
        }
        _appeals[hash] = document;
        _appealPins[hash] = Pins(e.identityCodeHash, e.payoutCodeHash, keccak256(abi.encode(e)));
        emit RecoveryRewindAppealPublished(
            hash, document.resolutionManifestHash, e.identityCodeHash, e.payoutCodeHash
        );
    }

    function appealEvidenceV3(bytes32 hash)
        external
        view
        override
        returns (W.AppealDocumentV3 memory, bytes32, bytes32)
    {
        Pins memory pins = _appealPins[hash];
        if (pins.identity == 0) revert W.InvalidRecoveryRewindAppeal(hash);
        _requirePins(_environment(), pins);
        return (_appeals[hash], pins.identity, pins.payout);
    }

    function publishPayoutOriginalV3(W.PayoutOriginalV3 calldata original)
        external
        override
        returns (bytes32 hash)
    {
        W.EnvironmentV3 memory e = _environment();
        _payoutShape(e, original);
        hash = W.payoutOriginalHash(e, original);
        bytes32 saved = _payoutEvidenceHashes[original.recordHash];
        if (saved != 0) {
            _requirePins(e, _payoutPins[original.recordHash]);
            if (saved != hash) revert W.InvalidRecoveryPayoutOriginal(original.recordHash);
            return hash;
        }
        _payoutOriginals[original.recordHash] = original;
        _payoutEvidenceHashes[original.recordHash] = hash;
        _payoutPins[original.recordHash] =
            Pins(e.identityCodeHash, e.payoutCodeHash, keccak256(abi.encode(e)));
        emit RecoveryPayoutOriginalPublished(
            hash, original.recordHash, original.terms.artistId, e.identityCodeHash, e.payoutCodeHash
        );
    }

    function payoutOriginalV3(bytes32 recordHash)
        external
        view
        override
        returns (W.PayoutOriginalV3 memory, bytes32, bytes32, bytes32)
    {
        bytes32 hash = _payoutEvidenceHashes[recordHash];
        if (hash == 0) revert W.InvalidRecoveryPayoutOriginal(recordHash);
        Pins memory pins = _payoutPins[recordHash];
        _requirePins(_environment(), pins);
        return (_payoutOriginals[recordHash], hash, pins.identity, pins.payout);
    }

    function _environment() private view returns (W.EnvironmentV3 memory) {
        if (block.chainid != deploymentChainId) {
            revert W.RecoveryRewindDependencyChanged(owner);
        }
        return Environment.fromFixed(owner, artistRegistry, coordinator, archive, core, mintManager);
    }

    function _requirePins(W.EnvironmentV3 memory e, Pins memory pins) private pure {
        if (pins.identity != e.identityCodeHash) {
            revert W.RecoveryRewindDependencyChanged(e.identityOwner);
        }
        if (pins.payout != e.payoutCodeHash) {
            revert W.RecoveryRewindDependencyChanged(e.payoutOwner);
        }
        if (pins.environmentHash != keccak256(abi.encode(e))) {
            revert W.RecoveryRewindDependencyChanged(e.coordinator);
        }
    }

    function _manifestShape(W.ResolutionManifestV3 calldata m) private pure {
        uint256 count = m.contestedVestings.length;
        if (
            m.artistId == 0 || m.causeHash == 0 || m.requestCommitment == 0
                || m.resolutionEvidenceHash == 0 || m.identity.snapshot.revision == 0
                || m.identity.snapshot.domainId != keccak256("domain:identity_authority")
                || m.payout.snapshot.domainId != keccak256("domain:payout_lifecycle")
                || m.identity.snapshot.stateRoot == 0 || m.identity.snapshot.recordChainTip == 0
                || m.payout.snapshot.stateRoot == 0 || m.payout.snapshot.recordChainTip == 0
                || count > W.MAX_DECLARED_VESTINGS
                || m.supersededRecords.length > W.MAX_SUPERSESSIONS
                || (m.basis == E.VestingBasis.NO_CONTESTED_VESTING
                        ? count != 0
                        : count == 0 || m.executedHead == 0)
        ) revert W.InvalidRecoveryRewindManifest(bytes32(0));
        for (uint256 i; i < count; ++i) {
            E.VestingReference calldata item = m.contestedVestings[i];
            if (item.transitionRecordHash == 0 || item.vestingCommitment == 0) {
                revert W.InvalidRecoveryRewindManifest(bytes32(0));
            }
            for (uint256 j; j < i; ++j) {
                if (
                    m.contestedVestings[j].transitionRecordHash == item.transitionRecordHash
                        || m.contestedVestings[j].vestingCommitment == item.vestingCommitment
                ) revert W.InvalidRecoveryRewindManifest(bytes32(0));
            }
        }
        bytes32 previous;
        for (uint256 i; i < m.supersededRecords.length; ++i) {
            bytes32 record = m.supersededRecords[i].recordHash;
            if (record <= previous) revert W.InvalidRecoveryRewindManifest(bytes32(0));
            previous = record;
        }
    }

    function _appealShape(W.AppealDocumentV3 calldata d) private pure {
        if (
            d.resolutionManifestHash == 0 || d.hostileFindingsHash == 0 || d.findings.length == 0
                || d.findings.length > W.MAX_SUPERSESSIONS
        ) revert W.InvalidRecoveryRewindAppeal(bytes32(0));
        bytes32 previous;
        for (uint256 i; i < d.findings.length; ++i) {
            Appeal.Finding calldata finding = d.findings[i];
            if (
                finding.guardianRecordHash <= previous || finding.parties.length == 0
                    || finding.parties.length > W.MAX_FINDING_PARTIES
            ) revert W.InvalidRecoveryRewindAppeal(bytes32(0));
            address prior;
            for (uint256 j; j < finding.parties.length; ++j) {
                if (finding.parties[j] <= prior) revert W.InvalidRecoveryRewindAppeal(bytes32(0));
                prior = finding.parties[j];
            }
            previous = finding.guardianRecordHash;
        }
    }

    function _payoutShape(W.EnvironmentV3 memory e, W.PayoutOriginalV3 calldata p) private pure {
        if (
            p.recordHash == 0 || p.terms.artistId == 0 || p.terms.payoutAccount == address(0)
                || p.signer == address(0) || (p.authorityClass != 1 && p.authorityClass != 3)
                || p.signedAt == 0
                || StreamArtistHashes.payoutRecordForAuthority(
                        StreamArtistHashes.Environment(e.chainId, e.registry, e.core, e.manager),
                        p.terms,
                        p.signer,
                        p.authorityClass,
                        p.nonce,
                        p.signedAt
                    ) != p.recordHash
        ) revert W.InvalidRecoveryPayoutOriginal(p.recordHash);
    }
}
