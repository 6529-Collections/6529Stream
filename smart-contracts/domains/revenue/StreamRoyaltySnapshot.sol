// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { IStreamCore } from "../../interfaces/stream/core/IStreamCore.sol";
import { IStreamCorePointers } from "../../interfaces/stream/core/IStreamCorePointers.sol";
import {
    IStreamArtistAttribution
} from "../../interfaces/stream/artist/IStreamArtistAttribution.sol";
import {
    IStreamArtistEconomicsAuthority
} from "../../interfaces/stream/artist/IStreamArtistEconomicsAuthority.sol";
import { IStreamRoyaltySnapshot } from "../../interfaces/stream/revenue/IStreamRoyaltySnapshot.sol";
import { IStreamRoyaltyResolver } from "../../interfaces/stream/revenue/IStreamRoyaltyResolver.sol";
import { IStreamSplitFactory } from "../../interfaces/stream/revenue/IStreamSplitFactory.sol";
import { IERC165 } from "../../vendor/openzeppelin/IERC165.sol";
import { StreamRoyaltyAssignmentHash } from "./StreamRoyaltyAssignmentHash.sol";
import { StreamRoyaltyPreparedProof } from "./StreamRoyaltyPreparedProof.sol";
import { StreamRoyaltyPlatformAdmission } from "./StreamRoyaltyPlatformAdmission.sol";

import { StreamRevenueArtistSelection } from "./StreamRevenueArtistSelection.sol";

/// @notice Fixed linked mode election and snapshot worker in the actual Resolver storage context.
library StreamRoyaltySnapshot {
    struct Election {
        uint8 mode;
        bytes32 hash;
    }

    struct State {
        mapping(uint256 => Election) elections;
        mapping(uint256 => IStreamRoyaltySnapshot.Snapshot) snapshots;
        bool entered;
    }

    struct Context {
        IStreamCore core;
        bytes32 coreRuntimeHash;
        IStreamSplitFactory factory;
        IStreamArtistAttribution artist;
        bytes32 artistRuntimeHash;
    }

    struct Hook {
        uint256 tokenId;
        uint256 collectionId;
        bytes32 operationRoot;
        bytes32 operationId;
        bytes32 revenueClass;
        bytes32 expectedSourcePolicy;
    }
    event CollectionRoyaltyModeElected(
        uint16 schemaVersion,
        uint256 indexed collectionId,
        bytes32 indexed electionHash,
        address indexed executor,
        address core,
        uint8 mode
    );
    event TokenRoyaltySnapshotted(
        uint16 schemaVersion,
        bytes32 indexed operationId,
        uint256 indexed tokenId,
        bytes32 indexed operationRoot,
        uint256 collectionId,
        bytes32 revenueClass,
        bytes32 tokenRoyaltyAssignmentHash
    );

    function elect(State storage state, Context memory x, uint256 collectionId, uint8 mode) public {
        if (state.elections[collectionId].mode != 0) {
            revert IStreamRoyaltySnapshot.RoyaltyModeAlreadyElected(collectionId);
        }
        if (mode != 1 && mode != 2) revert IStreamRoyaltySnapshot.InvalidRoyaltySnapshot();
        _core(x, collectionId);
        if (x.core.collectionNextSerial(collectionId) != 1) {
            revert IStreamRoyaltySnapshot.InvalidRoyaltySnapshot();
        }
        bytes32 hash = keccak256(
            abi.encode(
                keccak256("6529STREAM_ROYALTY_MODE_ELECTION_V1"),
                block.chainid,
                address(this),
                address(x.core),
                collectionId,
                mode
            )
        );
        state.elections[collectionId] = Election(mode, hash);
        emit CollectionRoyaltyModeElected(1, collectionId, hash, msg.sender, address(x.core), mode);
    }

    function modeHash(Context memory x, uint256 collectionId, bytes32 election, bytes32 original)
        public
        view
        returns (bytes32)
    {
        if (election == 0 || original == 0) revert IStreamRoyaltySnapshot.InvalidRoyaltySnapshot();
        return keccak256(
            abi.encode(
                keccak256("6529STREAM_SNAPSHOT_ROYALTY_ASSIGNMENT_V1"),
                block.chainid,
                address(this),
                address(x.core),
                collectionId,
                election,
                original
            )
        );
    }

    function source(
        State storage state,
        IStreamRoyaltyResolver.RoyaltyConfig memory config,
        Context memory x,
        uint256 collectionId,
        bool requireConsent
    ) public view returns (IStreamRoyaltySnapshot.Source memory s) {
        return _source(state, config, x, collectionId, requireConsent, 1, collectionId);
    }

    /// @notice Resolve the original configured collection key, otherwise the actual default.
    /// @dev Approval remains collection-specific; canonical source hashes retain their real scope.
    function selectedSource(
        State storage state,
        IStreamRoyaltyResolver.RoyaltyConfig storage defaultConfig,
        mapping(uint256 => IStreamRoyaltyResolver.RoyaltyConfig) storage collections,
        Context memory x,
        uint256 collectionId,
        bool requireConsent
    ) public view returns (IStreamRoyaltySnapshot.Source memory) {
        if (collections[collectionId].configured) {
            return _source(
                state, collections[collectionId], x, collectionId, requireConsent, 1, collectionId
            );
        }
        return _source(state, defaultConfig, x, collectionId, requireConsent, 0, 0);
    }

    function _source(
        State storage state,
        IStreamRoyaltyResolver.RoyaltyConfig memory config,
        Context memory x,
        uint256 collectionId,
        bool requireConsent,
        uint8 scope,
        uint256 scopeId
    ) private view returns (IStreamRoyaltySnapshot.Source memory s) {
        _core(x, collectionId);
        Election memory e = state.elections[collectionId];
        if (e.mode != 2) revert IStreamRoyaltySnapshot.RoyaltySnapshotModeRequired(collectionId);
        if (!config.configured || (scope == 1 && config.frozen) || config.royaltyBps > 1000) {
            revert IStreamRoyaltySnapshot.InvalidRoyaltySnapshot();
        }
        if (config.royaltyBps == 0) {
            // ADR 0038: configured zero suppresses fallback without claiming a split profile.
            if (config.profileId != 0 || config.wallet != address(0)) {
                revert IStreamRoyaltySnapshot.InvalidRoyaltySnapshot();
            }
        } else if (
            config.profileId == 0 || config.wallet == address(0)
                || !x.factory.splitWalletExists(config.profileId)
                || x.factory.walletFor(config.profileId) != config.wallet
        ) {
            revert IStreamRoyaltySnapshot.InvalidRoyaltySnapshot();
        }
        s.collectionId = collectionId;
        s.electionHash = e.hash;
        s.config = config;
        s.sourceAssignmentHash =
            StreamRoyaltyAssignmentHash.assignment(x.factory, config, scope, scopeId);
        s.sourceRoyaltyPolicyHash = StreamRoyaltyAssignmentHash.policy(
            collectionId, scope, scopeId, config, s.sourceAssignmentHash
        );
        s.modeAssignmentHash = modeHash(x, collectionId, e.hash, s.sourceAssignmentHash);
        if (requireConsent) _consent(x, collectionId, s.modeAssignmentHash);
    }

    function create(
        State storage state,
        IStreamRoyaltyResolver.RoyaltyConfig storage defaultConfig,
        mapping(
            uint256 => IStreamRoyaltyResolver.RoyaltyConfig
        ) storage collections,
        mapping(uint256 => IStreamRoyaltyResolver.RoyaltyConfig) storage tokens,
        Context memory x,
        Hook memory h
    ) public returns (bytes32) {
        if (
            state.entered || h.revenueClass != keccak256("ROYALTY_ERC2981")
                || h.expectedSourcePolicy == 0
        ) revert IStreamRoyaltySnapshot.InvalidRoyaltySnapshot();
        state.entered = true;
        // These authority coordinates come only from Resolver immutables, never hook calldata.
        StreamRoyaltyPreparedProof.Request memory proof = StreamRoyaltyPreparedProof.Request(
            address(x.core),
            x.coreRuntimeHash,
            h.collectionId,
            h.tokenId,
            h.operationRoot,
            h.operationId
        );
        bytes32 proofHash = StreamRoyaltyPreparedProof.requireCurrent(proof);
        IStreamRoyaltySnapshot.Source memory s =
            selectedSource(state, defaultConfig, collections, x, h.collectionId, true);
        if (s.sourceRoyaltyPolicyHash != h.expectedSourcePolicy) {
            revert IStreamRoyaltySnapshot.InvalidRoyaltySnapshot();
        }
        IStreamRoyaltyResolver.RoyaltyConfig memory token = IStreamRoyaltyResolver.RoyaltyConfig({
            wallet: s.config.wallet,
            royaltyBps: s.config.royaltyBps,
            configured: s.config.configured,
            frozen: true,
            revision: 1,
            profileId: s.config.profileId
        });
        IStreamRoyaltySnapshot.Snapshot memory next;
        next.exists = true;
        next.collectionId = h.collectionId;
        next.tokenId = h.tokenId;
        next.manager = msg.sender;
        next.operationRoot = h.operationRoot;
        next.operationId = h.operationId;
        next.preparedProofHash = proofHash;
        next.electionHash = s.electionHash;
        next.sourceAssignmentHash = s.sourceAssignmentHash;
        next.modeAssignmentHash = s.modeAssignmentHash;
        next.sourceRoyaltyPolicyHash = s.sourceRoyaltyPolicyHash;
        next.tokenAssignmentHash =
            StreamRoyaltyAssignmentHash.assignment(x.factory, token, 2, h.tokenId);
        next.tokenRoyaltyPolicyHash = StreamRoyaltyAssignmentHash.policy(
            h.collectionId, 2, h.tokenId, token, next.tokenAssignmentHash
        );
        next.tokenConfigHash = keccak256(abi.encode(token));
        // Recheck original authority and all source economics after profile/Artist reads.
        if (
            StreamRoyaltyPreparedProof.requireCurrent(proof) != proofHash
                || keccak256(
                        abi.encode(
                            selectedSource(
                                state, defaultConfig, collections, x, h.collectionId, true
                            )
                        )
                    ) != keccak256(abi.encode(s))
        ) {
            revert IStreamRoyaltySnapshot.InvalidRoyaltySnapshot();
        }
        IStreamRoyaltySnapshot.Snapshot memory old = state.snapshots[h.tokenId];
        if (old.exists) {
            if (
                keccak256(abi.encode(old)) != keccak256(abi.encode(next))
                    || keccak256(abi.encode(tokens[h.tokenId])) != next.tokenConfigHash
            ) {
                revert IStreamRoyaltySnapshot.InvalidRoyaltySnapshot();
            }
        } else {
            IStreamRoyaltySnapshot.Snapshot memory empty;
            IStreamRoyaltyResolver.RoyaltyConfig memory emptyToken;
            if (
                keccak256(abi.encode(old)) != keccak256(abi.encode(empty))
                    || keccak256(abi.encode(tokens[h.tokenId])) != keccak256(abi.encode(emptyToken))
            ) {
                revert IStreamRoyaltySnapshot.InvalidRoyaltySnapshot();
            }
            tokens[h.tokenId] = token;
            state.snapshots[h.tokenId] = next;
            emit TokenRoyaltySnapshotted(
                1,
                h.operationId,
                h.tokenId,
                h.operationRoot,
                h.collectionId,
                h.revenueClass,
                next.tokenRoyaltyPolicyHash
            );
        }
        state.entered = false;
        return next.tokenRoyaltyPolicyHash;
    }

    function _core(Context memory x, uint256 collectionId) private view {
        if (
            address(x.core).codehash != x.coreRuntimeHash || x.coreRuntimeHash == 0
                || collectionId == 0 || !x.core.collectionExists(collectionId)
        ) {
            revert IStreamRoyaltySnapshot.InvalidRoyaltySnapshot();
        }
    }

    function _consent(Context memory x, uint256 collectionId, bytes32 hash) private view {
        (address current, bytes32 currentHash,,,,,,,,) =
            IStreamCorePointers(address(x.core)).getSatellitePointer(keccak256("ARTIST_REGISTRY"));
        if (current != address(x.artist)) {
            current = StreamRevenueArtistSelection.successor(
                StreamRevenueArtistSelection.Context(
                    address(x.core),
                    address(x.artist),
                    x.artistRuntimeHash,
                    current,
                    currentHash,
                    false,
                    abi.encodeWithSelector(IStreamRoyaltySnapshot.InvalidRoyaltySnapshot.selector),
                    0
                )
            );
        } else if (currentHash != x.artistRuntimeHash || current.codehash != x.artistRuntimeHash) {
            revert IStreamRoyaltySnapshot.InvalidRoyaltySnapshot();
        }

        if (StreamRoyaltyPlatformAdmission.requireCurrent(
                address(x.core), IStreamArtistAttribution(current), currentHash, collectionId
            )) return;
        (address selected, bytes32 runtime,,,,,,,,) =
            IStreamCorePointers(address(x.core)).getSatellitePointer(keccak256("ARTIST_REGISTRY"));
        if (
            selected != current || runtime != currentHash || selected.codehash != runtime
                || runtime == 0
                || (current == address(x.artist) && currentHash != x.artistRuntimeHash)
                || IStreamArtistAttribution(current).attribution(collectionId).nominationHash == 0
                || !IERC165(selected)
                    .supportsInterface(type(IStreamArtistEconomicsAuthority).interfaceId)
        ) {
            revert IStreamRoyaltySnapshot.InvalidRoyaltySnapshot();
        }
        IStreamArtistEconomicsAuthority(selected)
            .requireEconomicsConsent(
                collectionId, keccak256("ROYALTY_ERC2981"), 1, collectionId, hash
            );
    }
}
