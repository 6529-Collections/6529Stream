// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    StreamArtistOnboardingTypes as T
} from "../../interfaces/stream/artist/StreamArtistOnboardingTypes.sol";
import {
    IStreamArtistSnapshotRoyaltyFacts
} from "../../interfaces/stream/artist/IStreamArtistSnapshotRoyaltyFacts.sol";
import {
    IStreamArtistRoyaltyScopeFacts
} from "../../interfaces/stream/artist/IStreamArtistRoyaltyScopeFacts.sol";
import { IStreamRoyaltyResolver } from "../../interfaces/stream/revenue/IStreamRoyaltyResolver.sol";
import { IERC165 } from "../../vendor/openzeppelin/IERC165.sol";

/// @notice Fixed linked dispatch between original live and elected collection snapshot economics.
/// @dev The Artist host first authenticates the selected immutable suite resolver. Every
///      provider read retains that host's caller through DELEGATECALL. Snapshot facts do
///      not consume prior consent; operative admission uses the original binding lookup.
library StreamArtistRoyaltyModeReads {
    function isSnapshot(address core, address resolver, uint256 collectionId)
        public
        view
        returns (bool)
    {
        return _election(core, resolver, collectionId) != bytes32(0);
    }

    function requireLive(address core, address resolver, uint256 collectionId) public view {
        if (_election(core, resolver, collectionId) != bytes32(0)) revert T.UnsupportedProfile();
    }

    function prospective(
        address core,
        T.EconomicsConsent memory p,
        T.FixedEconomicsCandidate memory candidate
    ) public view returns (T.AssignmentFact memory fact) {
        bytes32 election = _election(core, p.resolver, p.collectionId);
        if (election != bytes32(0)) {
            _snapshotShape(
                p.collectionId,
                p.scope,
                p.scopeId,
                candidate.profileHash,
                candidate.royaltyBps,
                candidate.frozen
            );
        }
        fact = _preview(
            p.resolver,
            p.collectionId,
            p.scope,
            p.scopeId,
            candidate.profileHash,
            candidate.royaltyBps,
            candidate.frozen
        );
        if (election != bytes32(0)) {
            T.AssignmentFact memory snapshot = IStreamArtistSnapshotRoyaltyFacts(p.resolver)
                .previewArtistSnapshotRoyaltyAssignment(
                    p.collectionId, candidate.profileHash, candidate.royaltyBps, candidate.frozen
                );
            _requireSnapshot(core, p.collectionId, election, fact, snapshot);
            fact = snapshot;
        }
    }

    function current(
        address core,
        address resolver,
        uint256 collectionId,
        uint8 scope,
        uint256 scopeId
    )
        public
        view
        returns (T.AssignmentFact memory fact, IStreamRoyaltyResolver.RoyaltyConfig memory config)
    {
        bytes32 election = _election(core, resolver, collectionId);
        if (election != bytes32(0) && (scope != 1 || scopeId != collectionId)) {
            revert T.UnsupportedProfile();
        }
        (fact, config) = IStreamArtistRoyaltyScopeFacts(resolver)
            .royaltyEconomicsFacts(collectionId, scope, scopeId);
        if (
            fact.resolver != resolver || fact.revenueClass != keccak256("ROYALTY_ERC2981")
                || fact.scope != scope || fact.scopeId != scopeId
                || (config.configured == (fact.assignmentHash == bytes32(0)))
        ) revert T.InvalidRecord();
        if (election != bytes32(0)) {
            _snapshotShape(
                collectionId, scope, scopeId, config.profileId, config.royaltyBps, config.frozen
            );
            if (
                !config.configured
                    || (config.wallet == address(0)) != (config.profileId == bytes32(0))
            ) revert T.InvalidRecord();
            T.AssignmentFact memory raw = _preview(
                resolver,
                collectionId,
                scope,
                scopeId,
                config.profileId,
                config.royaltyBps,
                config.frozen
            );
            if (keccak256(abi.encode(raw)) != keccak256(abi.encode(fact))) {
                revert T.InvalidRecord();
            }
            T.AssignmentFact memory snapshot = IStreamArtistSnapshotRoyaltyFacts(resolver)
                .currentArtistSnapshotRoyaltyAssignment(collectionId);
            _requireSnapshot(core, collectionId, election, fact, snapshot);
            fact = snapshot;
        }
    }

    function rebuild(
        address core,
        uint256 collectionId,
        T.AssignmentFact memory fact,
        IStreamRoyaltyResolver.RoyaltyConfig memory config
    ) public view returns (bytes memory) {
        bytes32 election = _election(core, fact.resolver, collectionId);
        if (election != bytes32(0)) {
            _snapshotShape(
                collectionId,
                fact.scope,
                fact.scopeId,
                config.profileId,
                config.royaltyBps,
                config.frozen
            );
        }
        T.AssignmentFact memory raw = _preview(
            fact.resolver,
            collectionId,
            fact.scope,
            fact.scopeId,
            config.profileId,
            config.royaltyBps,
            config.frozen
        );
        if (election != bytes32(0)) {
            _requireSnapshot(core, collectionId, election, raw, fact);
            return abi.encode(
                keccak256("6529STREAM_CURRENT_SNAPSHOT_ROYALTY_ECONOMICS_EVIDENCE_V1"),
                election,
                raw,
                fact,
                config
            );
        }
        if (keccak256(abi.encode(raw)) != keccak256(abi.encode(fact))) revert T.InvalidRecord();
        return
            abi.encode(keccak256("6529STREAM_CURRENT_ROYALTY_ECONOMICS_EVIDENCE_V1"), fact, config);
    }

    /// @dev Return only snapshot elections. Explicit mode-one elections remain live.
    function _election(address core, address resolver, uint256 collectionId)
        private
        view
        returns (bytes32)
    {
        if (!IERC165(resolver)
                .supportsInterface(type(IStreamArtistSnapshotRoyaltyFacts).interfaceId)) {
            return bytes32(0);
        }
        (uint8 mode, bytes32 election) =
            IStreamArtistSnapshotRoyaltyFacts(resolver).collectionRoyaltyMode(collectionId);
        if (mode != 1 && mode != 2) revert T.InvalidRecord();
        if (mode == 1 && election == bytes32(0)) return bytes32(0);
        if (
            election
                != keccak256(
                    abi.encode(
                        keccak256("6529STREAM_ROYALTY_MODE_ELECTION_V1"),
                        block.chainid,
                        resolver,
                        core,
                        collectionId,
                        mode
                    )
                )
        ) revert T.InvalidRecord();
        return mode == 2 ? election : bytes32(0);
    }

    function _preview(
        address resolver,
        uint256 collectionId,
        uint8 scope,
        uint256 scopeId,
        bytes32 profile,
        uint16 bps,
        bool frozen
    ) private view returns (T.AssignmentFact memory) {
        return IStreamArtistRoyaltyScopeFacts(resolver)
            .previewArtistRoyaltyAssignmentForScope(
                collectionId, scope, scopeId, profile, bps, frozen
            );
    }

    function _snapshotShape(
        uint256 collectionId,
        uint8 scope,
        uint256 scopeId,
        bytes32 profile,
        uint16 bps,
        bool frozen
    ) private pure {
        if (
            scope != 1 || scopeId != collectionId || (profile == bytes32(0)) != (bps == 0)
                || bps > 1_000 || frozen
        ) {
            revert T.UnsupportedProfile();
        }
    }

    function _requireSnapshot(
        address core,
        uint256 collectionId,
        bytes32 election,
        T.AssignmentFact memory raw,
        T.AssignmentFact memory snapshot
    ) private view {
        if (
            raw.resolver == address(0) || raw.revenueClass != keccak256("ROYALTY_ERC2981")
                || raw.scope != 1 || raw.scopeId != collectionId || raw.assignmentHash == bytes32(0)
                || snapshot.resolver != raw.resolver || snapshot.revenueClass != raw.revenueClass
                || snapshot.scope != 1 || snapshot.scopeId != collectionId
                || snapshot.assignmentHash
                    != keccak256(
                        abi.encode(
                            keccak256("6529STREAM_SNAPSHOT_ROYALTY_ASSIGNMENT_V1"),
                            block.chainid,
                            raw.resolver,
                            core,
                            collectionId,
                            election,
                            raw.assignmentHash
                        )
                    )
        ) revert T.InvalidRecord();
    }
}
