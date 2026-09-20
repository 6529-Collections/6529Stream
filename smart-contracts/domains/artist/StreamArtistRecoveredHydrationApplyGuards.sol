// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    StreamArtistRecoveredHydrationTypes as RH
} from "../../interfaces/stream/artist/StreamArtistRecoveredHydrationTypes.sol";
import {
    StreamArtistAuthorityHydrationTypes as AH
} from "../../interfaces/stream/artist/IStreamArtistAuthorityHydration.sol";
import {
    StreamArtistOnboardingTypes as T
} from "../../interfaces/stream/artist/StreamArtistOnboardingTypes.sol";
import { StreamArtistHydrationGuards as Original } from "./StreamArtistHydrationGuards.sol";
import {
    StreamArtistRecoveredHydrationGuards as Keys
} from "./StreamArtistRecoveredHydrationGuards.sol";
import {
    StreamArtistRecoveredHydrationState as Imported
} from "./StreamArtistRecoveredHydrationState.sol";

/// @notice Projects complete active guards while retaining registry-local history admission.
/// @dev The fixed owner first authenticates operation60 and installs its exact immutable prefix.
/// Old55 binding/action guards remain spent. Old56 lane latches and57 cutover are historical;
/// the destination's actual55/56 admissions and its unused57 latch stay in the local namespace.
library StreamArtistRecoveredHydrationApplyGuards {
    function applyGuards(
        mapping(bytes32 => T.ReplayCell) storage replay,
        RH.OriginEnvironment memory destination,
        uint8 ownerIndex,
        AH.OwnerData memory source,
        bytes32 value
    ) public returns (bytes32 delta) {
        if (
            value == 0 || Imported.commitment() != value || ownerIndex >= 7
                || destination.chainId != block.chainid
                || destination.owners[ownerIndex] != address(this)
                || source.origins.length != source.sourceKeys.length
                || source.origins.length != source.cells.length
        ) revert RH.InvalidRecoveredHydrationProvenance();
        RH.OwnerProvenance memory prefix = Imported.importedPrefix();
        if (
            prefix.eras.length == 0
                || source.origins.length
                    != prefix.eras[prefix.eras.length - 1].checkpoint.replayCount
        ) revert RH.InvalidRecoveredHydrationProvenance();
        RH.OriginEnvironment memory origin = prefix.origins[prefix.origins.length - 1];
        uint256 count;
        bytes32 historicalDelta;
        for (uint256 i; i < source.origins.length; ++i) {
            AH.Origin memory logical = source.origins[i];
            RH.ReplayAlias memory alias_ = Imported.historicalAlias(source.sourceKeys[i]);
            if (
                source.sourceKeys[i] != Keys.replayKey(origin, ownerIndex, logical)
                    || alias_.originHash != RH.originHash(origin) || alias_.ownerIndex != ownerIndex
                    || alias_.surface != logical.surface || alias_.scope != logical.scope
                    || keccak256(abi.encode(alias_.cell)) != keccak256(abi.encode(source.cells[i]))
            ) revert RH.InvalidRecoveredHydrationProvenance();
            if (_historical(ownerIndex, logical.surface)) {
                bytes32 currentKey = Keys.replayKey(destination, ownerIndex, logical);
                T.ReplayCell memory current = replay[currentKey];
                if (logical.surface == keccak256("identity_authority.replay.one_way_cutover_latch"))
                {
                    if (logical.scope != 0 || current.status != 0) {
                        revert RH.InvalidRecoveredHydrationProvenance();
                    }
                } else if (current.commitment == 0 || current.kind != 1 || current.status != 2) {
                    // A source lane cannot substitute for the target's genuine operation56.
                    revert RH.InvalidRecoveredHydrationProvenance();
                }
                historicalDelta =
                    keccak256(abi.encode(historicalDelta, alias_, currentKey, current));
            } else {
                ++count;
            }
        }
        AH.OwnerData memory active;
        active.origins = new AH.Origin[](count);
        active.sourceKeys = new bytes32[](count);
        active.cells = new T.ReplayCell[](count);
        uint256 cursor;
        for (uint256 i; i < source.origins.length; ++i) {
            if (_historical(ownerIndex, source.origins[i].surface)) continue;
            active.origins[cursor] = source.origins[i];
            active.sourceKeys[cursor] = source.sourceKeys[i];
            active.cells[cursor++] = source.cells[i];
        }
        delta = Original.applyGuards(
            replay,
            active,
            destination.registry,
            destination.coordinator,
            destination.archive,
            RH.ownerDomain(ownerIndex),
            value
        );
        for (uint256 i; i < active.origins.length; ++i) {
            // This must follow original noteReplay, whose normal local-write hook clears
            // previous overrides. A copied cell keeps its actual original mutation point.
            Imported.installActiveReplayPoint(
                Keys.replayKey(destination, ownerIndex, active.origins[i]), active.sourceKeys[i]
            );
        }
        return keccak256(
            abi.encode(
                keccak256("6529STREAM_ARTIST_RECOVERED_HYDRATION_GUARDS_V1"),
                RH.VERSION,
                ownerIndex,
                value,
                delta,
                historicalDelta
            )
        );
    }

    function _historical(uint8 ownerIndex, bytes32 surface) private pure returns (bool) {
        if (ownerIndex != 2) return false;
        return surface == keccak256("identity_authority.replay.one_way_cutover_latch")
            || surface == keccak256("identity_authority.replay.verified_lane_key")
            || surface == keccak256("identity_authority.replay.import_binding");
    }
}
