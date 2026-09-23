// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamArtistRecoveredHydrationTypes as RH
} from "../../interfaces/stream/artist/StreamArtistRecoveredHydrationTypes.sol";
import {
    StreamArtistRecoveredTimingTypes as TM,
    IStreamArtistRecoveredTimingInventory as TimingOwner
} from "../../interfaces/stream/artist/StreamArtistRecoveredTimingTypes.sol";
import {
    IStreamArtistIdentityOwner as Identity
} from "../../interfaces/stream/artist/IStreamArtistIdentityOwner.sol";
import {
    StreamArtistAuthorityHydrationTypes as AH
} from "../../interfaces/stream/artist/IStreamArtistAuthorityHydration.sol";
import {
    StreamArtistRecoveredTimingInventory as Timing
} from "./StreamArtistRecoveredTimingInventory.sol";
import {
    StreamArtistRecoveredHydrationProvenance as Provenance
} from "./StreamArtistRecoveredHydrationProvenance.sol";
import {
    StreamArtistRecoveredIdentityHydrationExportRows as Export
} from "./StreamArtistRecoveredIdentityHydrationExportRows.sol";
import { StreamArtistUnboundPlatformTypes as U } from "./StreamArtistUnboundPlatformTypes.sol";

/// @notice Explicit empty-principal certificate, never a fabricated zero-Artist Identity bundle.
/// @dev This first profile requires untouched global operational timing. History admission and
/// cutover cells remain complete authenticated provenance and are copied by the original guards.
library StreamArtistUnboundPlatformEmptyIdentity {
    bytes32 private constant LATCH = keccak256("identity_authority.replay.one_way_cutover_latch");
    bytes32 private constant LANE = keccak256("identity_authority.replay.verified_lane_key");
    bytes32 private constant IMPORT_LANE = keccak256("identity_authority.replay.import_binding");
    bytes32 private constant BINDING = keccak256("identity_authority.replay.import_binding_key");
    bytes32 private constant ACTION = keccak256("identity_authority.replay.governance_action");

    function collect(address source, RH.OwnerProvenance memory p, AH.Query[] memory collections)
        public
        view
        returns (bytes memory raw, TM.Checkpoint memory checkpoint)
    {
        Provenance.validateOwnerSource(p, 2, source);
        if (Identity(source).nextRegistrationNonce() != 0) _invalid();
        checkpoint = TimingOwner(source).recoveredTimingCheckpoint();
        raw = abi.encode(U.TAG, U.VERSION, checkpoint);
        validate(p, new RH.NonceInventory[](0), collections, raw);
    }

    function validate(
        RH.OwnerProvenance memory p,
        RH.NonceInventory[] memory nonces,
        AH.Query[] memory collections,
        bytes memory raw
    ) public pure returns (TM.Bundle memory b) {
        Provenance.validateOwner(p, 2);
        (bytes32 tag, uint16 version, TM.Checkpoint memory checkpoint) =
            abi.decode(raw, (bytes32, uint16, TM.Checkpoint));
        if (
            tag != U.TAG || version != U.VERSION
                || keccak256(raw) != keccak256(abi.encode(tag, version, checkpoint))
                || nonces.length != 0 || p.journal.length != 0
        ) _invalid();
        b.entries = new TM.Entry[](0);
        b.checkpoint =
            TM.Checkpoint(TM.SCHEMA, TM.VERSION, 0, 0, keccak256(abi.encode(b.configuration)));
        if (keccak256(abi.encode(checkpoint)) != keccak256(abi.encode(b.checkpoint))) _invalid();
        Timing.validate(b);
        uint256 aliases;
        for (uint256 e; e < p.eras.length; ++e) {
            uint256 lanes;
            uint256 roots;
            uint256 actions;
            uint256 cutovers;
            uint256 links;
            RH.OwnerEra memory era = p.eras[e];
            for (uint256 i; i < p.aliases.length; ++i) {
                RH.ReplayAlias memory a = p.aliases[i];
                if (a.originHash != era.originHash) continue;
                ++aliases;
                if (
                    a.ownerIndex != 2 || a.cell.kind != 1 || a.cell.status != 2
                        || a.cell.commitment == 0
                ) _invalid();
                if (a.surface == LATCH) {
                    if (
                        a.scope != 0 || a.admittedAt.environmentHash != era.originHash
                            || a.admittedAt.ownerRevision != era.checkpoint.ownerState.revision
                    ) _invalid();
                    ++cutovers;
                } else if (a.surface == LANE || a.surface == IMPORT_LANE) {
                    if (
                        e == 0 || a.admittedAt.environmentHash != era.originHash
                            || a.admittedAt.ownerRevision < 2
                            || a.admittedAt.ownerRevision >= era.lowerRevision
                    ) _invalid();
                    bool found;
                    for (uint256 k; k < collections.length; ++k) {
                        bytes32 expected = a.surface == LANE
                            ? keccak256(abi.encode(uint8(2), bytes32(collections[k].collectionId)))
                            : keccak256(
                                abi.encode(
                                    uint256(0), uint8(2), bytes32(collections[k].collectionId)
                                )
                            );
                        if (a.scope == expected) found = true;
                    }
                    if (!found) _invalid();
                    if (a.surface == LANE) ++lanes;
                    else ++links;
                } else if (a.surface == BINDING) {
                    if (a.scope == 0) _invalid();
                    ++roots;
                } else if (a.surface == ACTION) {
                    if (a.scope == 0) _invalid();
                    ++actions;
                } else {
                    _invalid();
                }
            }
            if (
                cutovers != 1 || lanes != links || roots != e || actions != e
                    || era.lowerRevision != (e == 0 ? 0 : 2 + lanes)
                    || era.checkpoint.ownerState.revision != era.lowerRevision + 1
                    || era.nativeCount != 0 || era.checkpoint.nonceIndexCount != 0
                    || era.checkpoint.nonceRoot != 0
                    || era.checkpoint.replayCount != 1 + lanes + links + roots + actions
            ) _invalid();
        }
        if (aliases != p.aliases.length) _invalid();
    }

    function install(
        uint256[17] memory roots,
        RH.OwnerProvenance memory p,
        RH.NonceInventory[] memory nonces,
        AH.Query[] memory collections,
        bytes memory raw
    ) public {
        TM.Bundle memory b = validate(p, nonces, collections, raw);
        TM.Configuration memory zero;
        if (keccak256(abi.encode(Export.configuration(roots))) != keccak256(abi.encode(zero))) {
            _invalid();
        }
        Timing.install(b);
    }

    function _invalid() private pure {
        revert RH.InvalidRecoveredHydrationProfile();
    }
}
