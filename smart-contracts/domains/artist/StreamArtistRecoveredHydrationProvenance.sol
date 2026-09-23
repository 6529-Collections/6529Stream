// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    StreamArtistRecoveredHydrationTypes as RH
} from "../../interfaces/stream/artist/StreamArtistRecoveredHydrationTypes.sol";
import {
    IStreamArtistRecoveredHydrationOwner as Source,
    IStreamArtistRecoveredNativeChronology as NativeChronology
} from "../../interfaces/stream/artist/IStreamArtistRecoveredHydration.sol";
import {
    IStreamArtistAuthorityHydrationCoordinator as Coordinator,
    IStreamArtistAuthorityHydrationOwner as PreviousOwner
} from "../../interfaces/stream/artist/IStreamArtistAuthorityHydration.sol";
import {
    IStreamArtistAuthorityCheckpoint as CP
} from "../../interfaces/stream/artist/IStreamArtistAuthorityCheckpoint.sol";
import { IStreamArtistOwner } from "../../interfaces/stream/artist/IStreamArtistOwner.sol";
import {
    IStreamArtistNativeReceipts as Native
} from "../../interfaces/stream/artist/IStreamArtistHistory.sol";
import {
    StreamArtistOnboardingTypes as T
} from "../../interfaces/stream/artist/StreamArtistOnboardingTypes.sol";
import {
    StreamArtistRecoveredHydrationChronology as Chronology
} from "./StreamArtistRecoveredHydrationChronology.sol";
import {
    StreamArtistRecoveredHydrationCodec as Codec
} from "./StreamArtistRecoveredHydrationCodec.sol";

/// @notice Flattened original environments, complete native occurrences, and cumulative guard keys.
/// @dev Pure validation authenticates shape, not authority. validateSource additionally binds the
/// exact imported prefixes and actual native/current-guard suffixes to all seven fixed owners. The caller
/// still authenticates the governed predecessor, cutover57, verified lanes, semantic owner facts,
/// nonce inventories, and the destination suite. No recursive historical call chain is followed.
library StreamArtistRecoveredHydrationProvenance {
    function environment(RH.Provenance memory p, bytes32 hash)
        public
        pure
        returns (RH.OriginEnvironment memory result)
    {
        bool found;
        for (uint256 i; i < p.origins.length; ++i) {
            if (RH.originHash(p.origins[i]) != hash) continue;
            if (found) revert RH.InvalidRecoveredHydrationProvenance();
            found = true;
            result = p.origins[i];
        }
        if (!found) revert RH.InvalidRecoveredHydrationProvenance();
    }

    function validate(RH.Provenance memory p) public pure returns (bytes32 commitment) {
        if (
            p.origins.length == 0 || p.origins.length != p.eras.length
                || p.eras.length > RH.MAX_ERAS
        ) {
            revert RH.InvalidRecoveredHydrationProvenance();
        }
        for (uint256 i; i < p.eras.length; ++i) {
            _origin(p, i);
        }
        uint256 journalCount;
        uint256 aliasCount;
        for (uint8 i; i < 7; ++i) {
            journalCount += p.journals[i].length;
            aliasCount += p.aliases[i].length;
            if (journalCount > RH.MAX_JOURNAL_ENTRIES || aliasCount > RH.MAX_REPLAY_ALIASES) {
                revert RH.InvalidRecoveredHydrationProvenance();
            }
            _journal(p, i);
            _aliases(p, i);
        }
        return RH.provenanceHash(p);
    }

    /// @notice Exact original nonce-index and full leaf/ancestor-word export, including exhaustion.
    /// @dev Current cells cannot reconstruct a rolling nonceRoot. The fixed producer checkpoint
    /// and every indexed getter must match; the Coordinator repeats its source header check.
    function validateNonces(
        address owner,
        CP.Checkpoint memory expected,
        RH.NonceInventory[] memory n
    ) public view returns (bytes32) {
        if (
            expected.schema != RH.CHECKPOINT || n.length > RH.MAX_NONCE_INDICES
                || n.length != expected.nonceIndexCount
                || keccak256(abi.encode(CP(owner).authorityCheckpoint()))
                    != keccak256(abi.encode(expected))
        ) revert RH.InvalidRecoveredHydrationProvenance();
        for (uint256 i; i < n.length; ++i) {
            CP.NonceIndex memory index = n[i].index;
            if (
                index.kind == 0 || index.kind > 5 || index.key == 0 || index.prefixCount == 0
                    || index.prefixCount > RH.MAX_NONCE_PREFIXES
                    || index.prefixCount != n[i].words.length
                    || keccak256(abi.encode(CP(owner).authorityNonceIndexAt(i)))
                        != keccak256(abi.encode(index))
            ) revert RH.InvalidRecoveredHydrationProvenance();
            for (uint256 prior; prior < i; ++prior) {
                if (n[prior].index.kind == index.kind && n[prior].index.key == index.key) {
                    revert RH.InvalidRecoveredHydrationProvenance();
                }
            }
            for (uint256 j; j < n[i].words.length; ++j) {
                (uint256 prefix, uint256[32] memory words, bool exhausted) =
                    CP(owner).authorityNonceWordAt(index.kind, index.key, j);
                if (
                    prefix != n[i].words[j].prefix || exhausted != n[i].words[j].exhausted
                        || keccak256(abi.encode(words))
                            != keccak256(abi.encode(n[i].words[j].words))
                ) revert RH.InvalidRecoveredHydrationProvenance();
                for (uint256 prior; prior < j; ++prior) {
                    if (n[i].words[prior].prefix == prefix) {
                        revert RH.InvalidRecoveredHydrationProvenance();
                    }
                }
            }
        }
        return keccak256(
            abi.encode(
                keccak256("6529STREAM_ARTIST_RECOVERED_HYDRATION_NONCES_V1"),
                RH.VERSION,
                owner,
                expected,
                n
            )
        );
    }

    function validateSource(RH.Provenance memory p, address sourceCoordinator)
        public
        view
        returns (bytes32 commitment)
    {
        commitment = validate(p);
        uint256 last = p.eras.length - 1;
        RH.OriginEnvironment memory current = p.origins[last];
        if (current.coordinator != sourceCoordinator) {
            revert RH.InvalidRecoveredHydrationProvenance();
        }
        for (uint256 i; i < p.origins.length; ++i) {
            _fixedEnvironment(p.origins[i]);
        }
        for (uint8 i; i < 7; ++i) {
            _sourceOwner(p, last, i);
        }
    }

    /// @notice Owner-local validation for a fixed typed exporter receiving verified-key witnesses.
    /// @dev Reads only this owner's mutable state and the constructor-fixed suite configuration.
    /// It cannot validate another owner's semantic state or replace the Coordinator's complete join.
    function validateOwnerSource(RH.OwnerProvenance memory local, uint8 ownerIndex, address owner)
        public
        view
        returns (bytes32)
    {
        RH.Provenance memory p = _validatedOwner(local, ownerIndex);
        uint256 last = p.eras.length - 1;
        RH.OriginEnvironment memory o = p.origins[last];
        if (o.owners[ownerIndex] != owner || o.chainId != block.chainid) {
            revert RH.InvalidRecoveredHydrationProvenance();
        }
        _fixedOwner(o, ownerIndex);
        _fixedSuite(o);
        _sourceOwner(p, last, ownerIndex);
        return RH.ownerProvenanceHash(local, ownerIndex);
    }

    /// @notice Pure owner-local shape validation for an already admitted destination import.
    /// @dev No external source reads and no authority inference. The Coordinator authenticates
    /// the complete seven-owner certificate before the original guarded operation60 apply.
    function validateOwner(RH.OwnerProvenance memory local, uint8 ownerIndex)
        public
        pure
        returns (bytes32)
    {
        _validatedOwner(local, ownerIndex);
        return RH.ownerProvenanceHash(local, ownerIndex);
    }

    function _validatedOwner(RH.OwnerProvenance memory local, uint8 ownerIndex)
        private
        pure
        returns (RH.Provenance memory p)
    {
        if (
            ownerIndex >= 7 || local.origins.length == 0
                || local.origins.length != local.eras.length || local.eras.length > RH.MAX_ERAS
                || local.journal.length > RH.MAX_JOURNAL_ENTRIES
                || local.aliases.length > RH.MAX_REPLAY_ALIASES
        ) revert RH.InvalidRecoveredHydrationProvenance();
        p.origins = local.origins;
        p.eras = new RH.Era[](local.eras.length);
        p.journals[ownerIndex] = local.journal;
        p.aliases[ownerIndex] = local.aliases;
        for (uint256 i; i < local.eras.length; ++i) {
            p.eras[i].originHash = local.eras[i].originHash;
            p.eras[i].checkpoints[ownerIndex] = local.eras[i].checkpoint;
            p.eras[i].nativeCounts[ownerIndex] = local.eras[i].nativeCount;
            p.eras[i].lowerRevisions[ownerIndex] = local.eras[i].lowerRevision;
            p.eras[i].priorImportCommitment = local.eras[i].priorImportCommitment;
        }
        for (uint256 i; i < p.eras.length; ++i) {
            _originBase(p, i);
            _ownerEra(p, i, ownerIndex);
        }
        _journal(p, ownerIndex);
        _aliases(p, ownerIndex);
    }

    /// @notice Matches an already structurally validated complete export to one saved owner prefix.
    /// @dev The actual fixed-owner getter supplies prefix/commitment/revision. Empty is permitted
    /// only for the genuine first era, with both the marker and local import revision absent.
    function validateImportedPrefix(
        RH.Provenance memory p,
        uint8 ownerIndex,
        RH.OwnerProvenance memory prefix,
        bytes32 importCommitment,
        uint64 importedAtRevision
    ) public pure {
        if (ownerIndex >= 7 || p.eras.length == 0 || p.origins.length != p.eras.length) {
            revert RH.InvalidRecoveredHydrationProvenance();
        }
        uint256 last = p.eras.length - 1;
        if (
            importCommitment != p.eras[last].priorImportCommitment
                || importedAtRevision != p.eras[last].lowerRevisions[ownerIndex]
                || (last == 0 && (importCommitment != 0 || importedAtRevision != 0))
                || (last != 0 && (importCommitment == 0 || importedAtRevision == 0))
        ) revert RH.InvalidRecoveredHydrationProvenance();
        RH.OwnerProvenance memory expected;
        expected.origins = new RH.OriginEnvironment[](last);
        expected.eras = new RH.OwnerEra[](last);
        uint256 oldRows;
        for (uint256 i; i < last; ++i) {
            expected.origins[i] = p.origins[i];
            RH.Era memory era = p.eras[i];
            expected.eras[i] = RH.OwnerEra(
                era.originHash,
                era.checkpoints[ownerIndex],
                era.nativeCounts[ownerIndex],
                era.lowerRevisions[ownerIndex],
                era.priorImportCommitment
            );
            oldRows += era.nativeCounts[ownerIndex];
        }
        if (oldRows > p.journals[ownerIndex].length) {
            revert RH.InvalidRecoveredHydrationProvenance();
        }
        expected.journal = new RH.JournalEntry[](oldRows);
        for (uint256 i; i < oldRows; ++i) {
            expected.journal[i] = p.journals[ownerIndex][i];
        }
        uint256 oldAliases;
        for (uint256 i; i < p.aliases[ownerIndex].length; ++i) {
            if (p.aliases[ownerIndex][i].originHash != p.eras[last].originHash) ++oldAliases;
        }
        expected.aliases = new RH.ReplayAlias[](oldAliases);
        uint256 cursor;
        for (uint256 i; i < p.aliases[ownerIndex].length; ++i) {
            RH.ReplayAlias memory alias_ = p.aliases[ownerIndex][i];
            if (alias_.originHash != p.eras[last].originHash) expected.aliases[cursor++] = alias_;
        }
        if (
            RH.ownerProvenanceHash(prefix, ownerIndex)
                != RH.ownerProvenanceHash(expected, ownerIndex)
        ) {
            revert RH.InvalidRecoveredHydrationProvenance();
        }
    }

    function _origin(RH.Provenance memory p, uint256 i) private pure {
        _originBase(p, i);
        for (uint8 ownerIndex; ownerIndex < 7; ++ownerIndex) {
            _ownerEra(p, i, ownerIndex);
        }
    }

    function _originBase(RH.Provenance memory p, uint256 i) private pure {
        RH.OriginEnvironment memory o = p.origins[i];
        RH.Era memory era = p.eras[i];
        if (
            o.chainId == 0 || o.chainId != p.origins[0].chainId || o.registry == address(0)
                || o.coordinator == address(0) || o.archive == address(0) || o.core == address(0)
                || o.manager == address(0) || o.suiteConfigurationHash == 0
                || o.core != p.origins[0].core || o.manager != p.origins[0].manager
                || RH.originHash(o) != era.originHash || (i == 0 && era.priorImportCommitment != 0)
                || (i != 0 && era.priorImportCommitment == 0)
        ) revert RH.InvalidRecoveredHydrationProvenance();
        for (uint256 prior; prior < i; ++prior) {
            if (
                p.eras[prior].originHash == era.originHash
                    || p.origins[prior].registry == o.registry
                    || p.origins[prior].coordinator == o.coordinator
            ) revert RH.InvalidRecoveredHydrationProvenance();
        }
        for (uint8 ownerIndex; ownerIndex < 7; ++ownerIndex) {
            for (uint8 other; other < ownerIndex; ++other) {
                if (o.owners[ownerIndex] == o.owners[other]) {
                    revert RH.InvalidRecoveredHydrationProvenance();
                }
            }
        }
    }

    function _ownerEra(RH.Provenance memory p, uint256 i, uint8 ownerIndex) private pure {
        RH.OriginEnvironment memory o = p.origins[i];
        RH.Era memory era = p.eras[i];
        CP.Checkpoint memory cp = era.checkpoints[ownerIndex];
        if (
            o.owners[ownerIndex] == address(0) || o.ownerCodeHashes[ownerIndex] == 0
                || cp.schema != RH.CHECKPOINT
                || cp.ownerState.domainId != RH.ownerDomain(ownerIndex)
                || cp.ownerState.stateRoot == 0 || cp.ownerState.recordChainTip == 0
                || era.lowerRevisions[ownerIndex] > cp.ownerState.revision
                || (i == 0 && era.lowerRevisions[ownerIndex] != 0)
                || (i != 0 && era.lowerRevisions[ownerIndex] == 0)
        ) revert RH.InvalidRecoveredHydrationProvenance();
    }

    function _journal(RH.Provenance memory p, uint8 ownerIndex) private pure {
        uint256 cursor;
        for (uint256 era; era < p.eras.length; ++era) {
            uint64 previousRevision = p.eras[era].lowerRevisions[ownerIndex];
            for (uint256 j; j < p.eras[era].nativeCounts[ownerIndex]; ++j) {
                if (cursor >= p.journals[ownerIndex].length) {
                    revert RH.InvalidRecoveredHydrationProvenance();
                }
                RH.JournalEntry memory entry = p.journals[ownerIndex][cursor++];
                RH.Point memory point = entry.position.point;
                if (
                    point.environmentHash != p.eras[era].originHash
                        || point.ownerIndex != ownerIndex || entry.position.nativeIndex != j
                        || point.ownerRevision <= p.eras[era].lowerRevisions[ownerIndex]
                        || point.ownerRevision < previousRevision || entry.receipt.recordHash == 0
                        || entry.receipt.operation == 0
                        || (entry.receipt.operation > 59 && entry.receipt.operation != 61)
                        || (entry.receipt.artistId == 0 && entry.receipt.collectionId == 0)
                ) revert RH.InvalidRecoveredHydrationProvenance();
                Chronology.validatePoint(p, point);
                previousRevision = point.ownerRevision;
            }
        }
        if (cursor != p.journals[ownerIndex].length) {
            revert RH.InvalidRecoveredHydrationProvenance();
        }
    }

    function _aliases(RH.Provenance memory p, uint8 ownerIndex) private pure {
        uint256[] memory counts = new uint256[](p.eras.length);
        bytes32 previousKey;
        for (uint256 i; i < p.aliases[ownerIndex].length; ++i) {
            RH.ReplayAlias memory a = p.aliases[ownerIndex][i];
            uint256 keyEra = _era(p, a.originHash);
            uint256 mutationEra = _era(p, a.admittedAt.environmentHash);
            RH.OriginEnvironment memory o = p.origins[keyEra];
            if (
                a.ownerIndex != ownerIndex || a.originalKey <= previousKey || a.cell.status == 0
                    || a.admittedAt.ownerIndex != ownerIndex || mutationEra > keyEra
                    || a.admittedAt.ownerRevision != a.cell.touchedRevision
                    || a.originalKey
                        != keccak256(
                            abi.encode(
                                keccak256("6529STREAM_ARTIST_OWNER_REPLAY_KEY_V2"),
                                o.chainId,
                                o.registry,
                                o.coordinator,
                                o.archive,
                                o.owners[ownerIndex],
                                RH.ownerDomain(ownerIndex),
                                a.surface,
                                a.scope
                            )
                        )
            ) revert RH.InvalidRecoveredHydrationProvenance();
            Chronology.validatePoint(p, a.admittedAt);
            previousKey = a.originalKey;
            ++counts[keyEra];
        }
        for (uint256 i; i < counts.length; ++i) {
            if (counts[i] != p.eras[i].checkpoints[ownerIndex].replayCount) {
                revert RH.InvalidRecoveredHydrationProvenance();
            }
        }
    }

    function _era(RH.Provenance memory p, bytes32 hash) private pure returns (uint256) {
        for (uint256 i; i < p.eras.length; ++i) {
            if (p.eras[i].originHash == hash) return i;
        }
        revert RH.InvalidRecoveredHydrationProvenance();
    }

    function _fixedEnvironment(RH.OriginEnvironment memory o) private view {
        if (o.chainId != block.chainid) revert RH.InvalidRecoveredHydrationProvenance();
        _fixedSuite(o);
        for (uint8 i; i < 7; ++i) {
            _fixedOwner(o, i);
        }
    }

    function _fixedSuite(RH.OriginEnvironment memory o) private view {
        T.SuiteConfiguration memory suite = Coordinator(o.coordinator).authorityHydrationSuite();
        if (
            keccak256(abi.encode(suite)) != o.suiteConfigurationHash || suite.registry != o.registry
                || suite.archive != o.archive || suite.core != o.core
                || suite.mintManager != o.manager
                || keccak256(abi.encode(suite.owners)) != keccak256(abi.encode(o.owners))
        ) revert RH.InvalidRecoveredHydrationProvenance();
        // Runtime pins are immutable environment facts, not cross-owner semantic reads.
        for (uint8 i; i < 7; ++i) {
            if (o.owners[i].code.length == 0 || o.owners[i].codehash != o.ownerCodeHashes[i]) {
                revert RH.InvalidRecoveredHydrationProvenance();
            }
        }
    }

    function _fixedOwner(RH.OriginEnvironment memory o, uint8 i) private view {
        IStreamArtistOwner owner = IStreamArtistOwner(o.owners[i]);
        if (
            o.owners[i].code.length == 0 || o.owners[i].codehash != o.ownerCodeHashes[i]
                || owner.artistRegistry() != o.registry
                || owner.operationCoordinator() != o.coordinator || owner.archiveV2() != o.archive
                || owner.core() != o.core || owner.mintManager() != o.manager
                || owner.deploymentChainId() != o.chainId || owner.domainId() != RH.ownerDomain(i)
        ) revert RH.InvalidRecoveredHydrationProvenance();
    }

    function _sourceOwner(RH.Provenance memory p, uint256 last, uint8 i) private view {
        address owner = p.origins[last].owners[i];
        Source source = Source(owner);
        Codec.requireCapability(
            source.recoveredAuthorityHydrationCapability(), i, last == 0 ? 0 : RH.REPEATED_IMPORT
        );
        (RH.OwnerProvenance memory prefix, bytes32 importCommitment, uint64 importedAtRevision) =
            source.recoveredHydrationImportedPrefix();
        if (PreviousOwner(owner).authorityHydrationCommitment() != importCommitment) {
            revert RH.InvalidRecoveredHydrationProvenance();
        }
        validateImportedPrefix(p, i, prefix, importCommitment, importedAtRevision);
        if (
            Native(owner).artistNativeReceiptCount() != p.eras[last].nativeCounts[i]
                || keccak256(abi.encode(CP(owner).authorityCheckpoint()))
                    != keccak256(abi.encode(p.eras[last].checkpoints[i]))
        ) revert RH.InvalidRecoveredHydrationProvenance();
        for (uint256 j; j < p.journals[i].length; ++j) {
            RH.JournalEntry memory entry = p.journals[i][j];
            if (entry.position.point.environmentHash != p.eras[last].originHash) continue;
            if (
                keccak256(
                            abi.encode(
                                Native(owner).artistNativeReceiptAt(entry.position.nativeIndex)
                            )
                        ) != keccak256(abi.encode(entry.receipt))
                    || NativeChronology(owner)
                            .artistNativeReceiptRevisionAt(entry.position.nativeIndex)
                        != entry.position.point.ownerRevision
            ) revert RH.InvalidRecoveredHydrationProvenance();
        }
        _liveKeys(p, last, i, owner);
    }

    function _liveKeys(RH.Provenance memory p, uint256 last, uint8 i, address owner) private view {
        for (uint256 j; j < p.eras[last].checkpoints[i].replayCount; ++j) {
            (bytes32 key, T.ReplayCell memory cell) = CP(owner).authorityReplayAt(j);
            bool found;
            for (uint256 k; k < p.aliases[i].length; ++k) {
                RH.ReplayAlias memory a = p.aliases[i][k];
                if (a.originalKey != key) continue;
                if (
                    a.originHash != p.eras[last].originHash
                        || keccak256(abi.encode(a.cell)) != keccak256(abi.encode(cell))
                        || keccak256(abi.encode(IStreamArtistOwner(owner).replayCell(key)))
                            != keccak256(abi.encode(cell))
                        || keccak256(abi.encode(Source(owner).recoveredHydrationReplayPoint(key)))
                            != keccak256(abi.encode(a.admittedAt))
                ) revert RH.InvalidRecoveredHydrationProvenance();
                found = true;
                break;
            }
            if (!found) revert RH.InvalidRecoveredHydrationProvenance();
        }
    }
}
