// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    StreamArtistRecoveredHydrationTypes as RH
} from "../../interfaces/stream/artist/StreamArtistRecoveredHydrationTypes.sol";
import {
    IStreamArtistRecoveredHydrationOwner as Owner,
    IStreamArtistRecoveredNativeChronology as NativeChronology
} from "../../interfaces/stream/artist/IStreamArtistRecoveredHydration.sol";
import {
    StreamArtistAuthorityHydrationTypes as AH,
    IStreamArtistAuthorityHydrationOwner as HydratedOwner
} from "../../interfaces/stream/artist/IStreamArtistAuthorityHydration.sol";
import {
    IStreamArtistAuthorityCheckpoint as CP
} from "../../interfaces/stream/artist/IStreamArtistAuthorityCheckpoint.sol";
import {
    StreamArtistOnboardingTypes as T
} from "../../interfaces/stream/artist/StreamArtistOnboardingTypes.sol";
import {
    IStreamArtistNativeReceipts as Native
} from "../../interfaces/stream/artist/IStreamArtistHistory.sol";
import {
    StreamArtistRecoveredHydrationProvenance as Provenance
} from "./StreamArtistRecoveredHydrationProvenance.sol";
import {
    StreamArtistRecoveredHydrationGuards as Guards
} from "./StreamArtistRecoveredHydrationGuards.sol";

/// @notice Assembles complete flattened provenance using exact original source getter results.
/// @dev Caller still proves governed predecessor/cutover/lane admission and every semantic codec.
/// Replay preimages are necessary witnesses, never replacements for actual checkpoint key/cells.
library StreamArtistRecoveredHydrationSource {
    function collect(
        T.SuiteConfiguration memory source,
        address sourceCoordinator,
        AH.Origin[][7] memory origins
    ) public view returns (RH.Provenance memory p) {
        RH.OwnerProvenance[7] memory prefixes;
        uint64[7] memory importedAt;
        bytes32 importCommitment;
        for (uint8 i; i < 7; ++i) {
            bytes32 commitment;
            (prefixes[i], commitment, importedAt[i]) =
                Owner(source.owners[i]).recoveredHydrationImportedPrefix();
            if (
                commitment != HydratedOwner(source.owners[i]).authorityHydrationCommitment()
                    || (i != 0 && commitment != importCommitment)
                    || (commitment == 0
                            ? importedAt[i] != 0 || prefixes[i].origins.length != 0
                            || prefixes[i].eras.length != 0 || prefixes[i].journal.length != 0
                            || prefixes[i].aliases.length != 0
                            : importedAt[i] == 0 || prefixes[i].origins.length == 0)
            ) revert RH.InvalidRecoveredHydrationProvenance();
            if (i == 0) importCommitment = commitment;
            if (
                prefixes[i].origins.length != prefixes[0].origins.length
                    || prefixes[i].eras.length != prefixes[0].origins.length
                    || keccak256(abi.encode(prefixes[i].origins))
                        != keccak256(abi.encode(prefixes[0].origins))
            ) revert RH.InvalidRecoveredHydrationProvenance();
        }
        uint256 currentEra = prefixes[0].origins.length;
        if (currentEra >= RH.MAX_ERAS) revert RH.InvalidRecoveredHydrationProvenance();
        p.origins = new RH.OriginEnvironment[](currentEra + 1);
        p.eras = new RH.Era[](currentEra + 1);
        for (uint256 j; j < currentEra; ++j) {
            p.origins[j] = prefixes[0].origins[j];
            p.eras[j].originHash = RH.originHash(p.origins[j]);
            p.eras[j].priorImportCommitment = prefixes[0].eras[j].priorImportCommitment;
            for (uint8 i; i < 7; ++i) {
                RH.OwnerEra memory era = prefixes[i].eras[j];
                if (
                    era.originHash != p.eras[j].originHash
                        || era.priorImportCommitment != p.eras[j].priorImportCommitment
                ) revert RH.InvalidRecoveredHydrationProvenance();
                p.eras[j].checkpoints[i] = era.checkpoint;
                p.eras[j].nativeCounts[i] = era.nativeCount;
                p.eras[j].lowerRevisions[i] = era.lowerRevision;
            }
        }
        p.origins[currentEra] = _environment(source, sourceCoordinator);
        bytes32 currentOrigin = RH.originHash(p.origins[currentEra]);
        p.eras[currentEra].originHash = currentOrigin;
        p.eras[currentEra].priorImportCommitment = importCommitment;
        for (uint8 i; i < 7; ++i) {
            address owner = source.owners[i];
            CP.Checkpoint memory cp = CP(owner).authorityCheckpoint();
            uint256 count = Native(owner).artistNativeReceiptCount();
            if (
                prefixes[i].journal.length > RH.MAX_JOURNAL_ENTRIES
                    || count > RH.MAX_JOURNAL_ENTRIES - prefixes[i].journal.length
                    || prefixes[i].aliases.length > RH.MAX_REPLAY_ALIASES
                    || cp.replayCount > RH.MAX_REPLAY_ALIASES - prefixes[i].aliases.length
                    || origins[i].length != cp.replayCount
            ) revert RH.InvalidRecoveredHydrationProvenance();
            p.eras[currentEra].checkpoints[i] = cp;
            p.eras[currentEra].nativeCounts[i] = count;
            p.eras[currentEra].lowerRevisions[i] = importedAt[i];
            p.journals[i] = _journal(owner, i, currentOrigin, count, prefixes[i].journal);
            p.aliases[i] = _aliases(p.origins[currentEra], i, origins[i], prefixes[i].aliases);
        }
        Provenance.validateSource(p, sourceCoordinator);
    }

    function _environment(T.SuiteConfiguration memory s, address coordinator)
        private
        view
        returns (RH.OriginEnvironment memory o)
    {
        o.chainId = block.chainid;
        o.registry = s.registry;
        o.coordinator = coordinator;
        o.archive = s.archive;
        o.owners = s.owners;
        for (uint8 i; i < 7; ++i) {
            o.ownerCodeHashes[i] = s.owners[i].codehash;
        }
        o.core = s.core;
        o.manager = s.mintManager;
        o.suiteConfigurationHash = keccak256(abi.encode(s));
    }

    function _journal(
        address owner,
        uint8 ownerIndex,
        bytes32 currentOrigin,
        uint256 count,
        RH.JournalEntry[] memory prefix
    ) private view returns (RH.JournalEntry[] memory rows) {
        rows = new RH.JournalEntry[](prefix.length + count);
        for (uint256 i; i < prefix.length; ++i) {
            rows[i] = prefix[i];
        }
        for (uint256 i; i < count; ++i) {
            rows[prefix.length + i] = RH.JournalEntry(
                RH.Position(
                    RH.Point(
                        currentOrigin,
                        ownerIndex,
                        NativeChronology(owner).artistNativeReceiptRevisionAt(i)
                    ),
                    i
                ),
                Native(owner).artistNativeReceiptAt(i)
            );
        }
    }

    function _aliases(
        RH.OriginEnvironment memory source,
        uint8 ownerIndex,
        AH.Origin[] memory origins,
        RH.ReplayAlias[] memory prefix
    ) private view returns (RH.ReplayAlias[] memory aliases) {
        aliases = new RH.ReplayAlias[](prefix.length + origins.length);
        for (uint256 i; i < prefix.length; ++i) {
            aliases[i] = prefix[i];
        }
        address owner = source.owners[ownerIndex];
        bytes32 originHash = RH.originHash(source);
        for (uint256 i; i < origins.length; ++i) {
            (bytes32 key, T.ReplayCell memory cell) = CP(owner).authorityReplayAt(i);
            if (key != Guards.replayKey(source, ownerIndex, origins[i]) || cell.status == 0) {
                revert RH.InvalidRecoveredHydrationProvenance();
            }
            aliases[prefix.length + i] = RH.ReplayAlias(
                originHash,
                ownerIndex,
                origins[i].surface,
                origins[i].scope,
                key,
                cell,
                Owner(owner).recoveredHydrationReplayPoint(key)
            );
        }
        return _sort(aliases);
    }

    /// @dev Bounded stable merge sort avoids quadratic work over the complete cumulative keys.
    function _sort(RH.ReplayAlias[] memory aliases) private pure returns (RH.ReplayAlias[] memory) {
        if (aliases.length < 2) return aliases;
        RH.ReplayAlias[] memory scratch = new RH.ReplayAlias[](aliases.length);
        for (uint256 width = 1; width < aliases.length; width *= 2) {
            for (uint256 first; first < aliases.length; first += width * 2) {
                uint256 middle = first + width;
                if (middle > aliases.length) middle = aliases.length;
                uint256 end = middle + width;
                if (end > aliases.length) end = aliases.length;
                uint256 left = first;
                uint256 right = middle;
                for (uint256 output = first; output < end; ++output) {
                    if (
                        right == end
                            || (left < middle
                                && aliases[left].originalKey <= aliases[right].originalKey)
                    ) {
                        scratch[output] = aliases[left++];
                    } else {
                        scratch[output] = aliases[right++];
                    }
                }
            }
            (aliases, scratch) = (scratch, aliases);
        }
        return aliases;
    }
}
