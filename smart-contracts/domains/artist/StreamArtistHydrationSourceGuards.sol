// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "../../interfaces/stream/artist/IStreamArtistMultipleAuthorityHydration.sol";
import "./StreamArtistReadinessHydrationFacts.sol";
import {
    StreamArtistReadinessHydrationTypes as RH
} from "../../interfaces/stream/artist/IStreamArtistReadinessAuthorityHydration.sol";
import "./StreamArtistEconomicsHydration.sol";
import {
    StreamArtistEconomicsHydrationTypes as EH
} from "../../interfaces/stream/artist/IStreamArtistEconomicsAuthorityHydration.sol";
import "../../interfaces/stream/artist/IStreamArtistConsentOwner.sol";
import "../../interfaces/stream/artist/IStreamArtistPayoutTransitionOwner.sol";
import "../../interfaces/stream/artist/IStreamArtistPayoutOwner.sol";
import {
    StreamArtistRotationTypes as HydrationRotation
} from "../../interfaces/stream/artist/StreamArtistRotationTypes.sol";
import "../../interfaces/stream/artist/IStreamArtistPayoutAuthorityHydration.sol";
import {
    StreamArtistPayoutHydrationTypes as PH
} from "../../interfaces/stream/artist/IStreamArtistPayoutAuthorityHydration.sol";
import "./StreamArtistHistoryOperations.sol";
import "../../interfaces/stream/artist/IStreamArtistAuthorityHydration.sol";
import "../../interfaces/stream/artist/IStreamArtistIngressBinding.sol";
import {
    StreamArtistAuthorityHydrationTypes as AH
} from "../../interfaces/stream/artist/IStreamArtistAuthorityHydration.sol";
import {
    IStreamArtistAuthorityCheckpoint as CP
} from "../../interfaces/stream/artist/IStreamArtistAuthorityCheckpoint.sol";

/// @notice Fixed original source/header/lane/replay checks for operation60.
library StreamArtistHydrationSourceGuards {
    bytes32 private constant CHECKPOINT = keccak256("6529STREAM_ARTIST_GUARD_CHECKPOINT_V1");

    function _lane(IStreamArtistHistory h, address prior, uint8 kind, bytes32 key) public view {
        (bool done, bytes32 tip, uint64 count) = h.importedLaneVerified(kind, key);
        (bytes32 actual, uint64 n) = IStreamArtistHistory(prior).artistHistoryLane(kind, key);
        if (!done || count == 0 || count != n || tip != actual) revert T.InvalidRecord();
    }

    function _header(address owner, CP.Checkpoint memory expected) public view {
        if (
            expected.schema != CHECKPOINT || expected.replayCount > 512
                || expected.nonceIndexCount > 1
                || keccak256(abi.encode(expected))
                    != keccak256(abi.encode(CP(owner).authorityCheckpoint()))
        ) revert T.InvalidRecord();
    }

    function _multipleHeader(address owner, CP.Checkpoint memory expected) public view {
        if (
            expected.schema != CHECKPOINT || expected.replayCount > 512
                || expected.nonceIndexCount > 128
                || keccak256(abi.encode(expected))
                    != keccak256(abi.encode(CP(owner).authorityCheckpoint()))
        ) {
            revert T.InvalidRecord();
        }
    }

    function _suite(
        T.SuiteConfiguration memory next,
        T.SuiteConfiguration memory source,
        address prior,
        address coordinator
    ) public view {
        if (
            source.registry != prior || source.core != next.core
                || source.mintManager != next.mintManager
                || source.roleRegistry != next.roleRegistry || source.metadata != next.metadata
                || source.primaryResolver != next.primaryResolver
                || source.royaltyResolver != next.royaltyResolver
                || source.primaryRevenueClass != next.primaryRevenueClass
                || source.validator != next.validator
        ) revert T.InvalidBinding();
        for (uint256 i; i < 7; ++i) {
            IStreamArtistOwner o = IStreamArtistOwner(source.owners[i]);
            if (
                o.artistRegistry() != prior || o.operationCoordinator() != coordinator
                    || o.archiveV2() != source.archive || o.core() != source.core
                    || o.mintManager() != source.mintManager
                    || o.deploymentChainId() != block.chainid
                    || o.domainId() != IStreamArtistOwner(next.owners[i]).domainId()
            ) revert T.InvalidBinding();
        }
    }

    function _guards(
        T.SuiteConfiguration memory s,
        address coordinator,
        uint256 i,
        AH.Request memory p
    ) public view returns (AH.OwnerData memory result) {
        CP.Checkpoint memory h = p.expectedSource[i];
        address owner = s.owners[i];
        result.origins = p.replayOrigins[i];
        if (result.origins.length != h.replayCount) revert T.InvalidRecord();
        result.cells = new T.ReplayCell[](h.replayCount);
        result.sourceKeys = new bytes32[](h.replayCount);
        for (uint256 j; j < h.replayCount; ++j) {
            (bytes32 key, T.ReplayCell memory cell) = CP(owner).authorityReplayAt(j);
            AH.Origin memory origin = result.origins[j];
            bytes32 actual = keccak256(
                abi.encode(
                    keccak256("6529STREAM_ARTIST_OWNER_REPLAY_KEY_V2"),
                    block.chainid,
                    s.registry,
                    coordinator,
                    s.archive,
                    owner,
                    h.ownerState.domainId,
                    origin.surface,
                    origin.scope
                )
            );
            if (
                actual != key || cell.status == 0
                    || keccak256(abi.encode(cell))
                        != keccak256(abi.encode(IStreamArtistOwner(owner).replayCell(key)))
            ) revert T.InvalidRecord();
            result.cells[j] = cell;
            result.sourceKeys[j] = key;
        }
        if (i != 2) {
            if (h.nonceIndexCount != 0) revert T.UnsupportedProfile();
            return result;
        }
        if (h.nonceIndexCount != 1) revert T.UnsupportedProfile();
        CP.NonceIndex memory index = CP(owner).authorityNonceIndexAt(0);
        if (
            index.kind != 1 || index.key != p.artistId || index.prefixCount == 0
                || index.prefixCount > 256
        ) revert T.UnsupportedProfile();
        result.nonces = new AH.NonceWord[](index.prefixCount);
        for (uint256 j; j < index.prefixCount; ++j) {
            (result.nonces[j].prefix, result.nonces[j].words, result.nonces[j].exhausted) =
                CP(owner).authorityNonceWordAt(1, p.artistId, j);
        }
    }
}
