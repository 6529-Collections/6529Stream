// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    StreamArtistRecoveredHydrationTypes as RH
} from "../../interfaces/stream/artist/StreamArtistRecoveredHydrationTypes.sol";
import {
    StreamArtistRecoveryRewindTypes as W
} from "../../interfaces/stream/artist/StreamArtistRecoveryRewindTypes.sol";
import {
    StreamArtistOnboardingTypes as T
} from "../../interfaces/stream/artist/StreamArtistOnboardingTypes.sol";
import {
    StreamArtistHistoryTypes as H,
    IStreamArtistNativeReceipts as Native
} from "../../interfaces/stream/artist/IStreamArtistHistory.sol";
import {
    IStreamArtistAuthorityCheckpoint as CP
} from "../../interfaces/stream/artist/IStreamArtistAuthorityCheckpoint.sol";
import { IStreamArtistOwner } from "../../interfaces/stream/artist/IStreamArtistOwner.sol";
import {
    IStreamArtistRecoveryDeployment as Deployment
} from "../../interfaces/stream/artist/IStreamArtistRecoveryDeployment.sol";
import {
    IStreamArtistAuthorityHydrationOwner as Original,
    StreamArtistAuthorityHydrationTypes as AH
} from "../../interfaces/stream/artist/IStreamArtistAuthorityHydration.sol";
import {
    IStreamArtistRecoveredHydrationOwner as Owner,
    IStreamArtistRecoveredNativeChronology as NativeClock
} from "../../interfaces/stream/artist/IStreamArtistRecoveredHydration.sol";
import {
    StreamArtistRecoveredHydrationProvenance as Provenance
} from "./StreamArtistRecoveredHydrationProvenance.sol";
import {
    StreamArtistRecoveredHydrationChronology as Chronology
} from "./StreamArtistRecoveredHydrationChronology.sol";
import {
    StreamArtistRecoveredHydrationGuards as Keys
} from "./StreamArtistRecoveredHydrationGuards.sol";

/// @notice Original environments and one owner-local clock for recovered Identity/Payout reads.
/// @dev A point proves provenance, never the semantic record body or its original authorization.
/// Fixed consumers build Context with load; caller-authored Context is not an authorization input.
library StreamArtistRecoveredRuntimeReads {
    struct Context {
        uint8 ownerIndex;
        address owner;
        RH.OriginEnvironment current;
        RH.OwnerProvenance imported;
        CP.Checkpoint checkpoint;
        bytes32 importCommitment;
        uint64 importedAtRevision;
        uint256 nativeCount;
    }

    struct OriginFact {
        RH.Point point;
        RH.OriginEnvironment environment;
    }

    struct ReceiptFact {
        RH.Position position;
        H.Receipt receipt;
        RH.OriginEnvironment environment;
        uint256 logicalIndex;
    }

    struct ReplayFact {
        bytes32 originalKey;
        T.ReplayCell cell;
        OriginFact admission;
    }

    function load(W.EnvironmentV3 memory e, uint8 ownerIndex)
        public
        view
        returns (Context memory c)
    {
        if (ownerIndex != 2 && ownerIndex != 5) _invalid();
        c.ownerIndex = ownerIndex;
        c.current = _current(e);
        c.owner = c.current.owners[ownerIndex];
        IStreamArtistOwner own = IStreamArtistOwner(c.owner);
        if (
            own.artistRegistry() != e.registry || own.operationCoordinator() != e.coordinator
                || own.archiveV2() != e.archive || own.core() != e.core
                || own.mintManager() != e.manager || own.deploymentChainId() != e.chainId
                || own.domainId() != RH.ownerDomain(ownerIndex)
        ) _invalid();
        c.checkpoint = CP(c.owner).authorityCheckpoint();
        if (
            c.checkpoint.schema != RH.CHECKPOINT
                || c.checkpoint.ownerState.domainId != RH.ownerDomain(ownerIndex)
                || c.checkpoint.ownerState.stateRoot == 0
                || c.checkpoint.ownerState.recordChainTip == 0
                || keccak256(abi.encode(c.checkpoint.ownerState))
                    != keccak256(abi.encode(own.ownerStateSnapshotV2()))
        ) _invalid();
        (c.imported, c.importCommitment, c.importedAtRevision) =
            Owner(c.owner).recoveredHydrationImportedPrefix();
        if (Original(c.owner).authorityHydrationCommitment() != c.importCommitment) _invalid();
        if (c.importCommitment == 0) {
            if (
                c.importedAtRevision != 0 || c.imported.origins.length != 0
                    || c.imported.eras.length != 0 || c.imported.journal.length != 0
                    || c.imported.aliases.length != 0
            ) _invalid();
        } else {
            Provenance.validateOwner(c.imported, ownerIndex);
            if (
                c.importedAtRevision == 0 || c.importedAtRevision > c.checkpoint.ownerState.revision
            ) _invalid();
            for (uint256 i; i < c.imported.origins.length; ++i) {
                RH.OriginEnvironment memory old = c.imported.origins[i];
                if (
                    old.chainId != e.chainId || old.core != e.core || old.manager != e.manager
                        || old.registry == e.registry || old.coordinator == e.coordinator
                        || old.owners[ownerIndex] == c.owner
                        || RH.originHash(old) == RH.originHash(c.current)
                ) _invalid();
            }
        }
        c.nativeCount = Native(c.owner).artistNativeReceiptCount();
    }

    function logicalCount(Context memory c) public pure returns (uint256) {
        return c.imported.journal.length + c.nativeCount;
    }

    function receiptAt(Context memory c, uint256 index) public view returns (ReceiptFact memory f) {
        _fresh(c);
        if (index >= logicalCount(c)) _invalid();
        f.logicalIndex = index;
        if (index < c.imported.journal.length) {
            RH.JournalEntry memory row = c.imported.journal[index];
            f.position = row.position;
            f.receipt = row.receipt;
        } else {
            uint256 nativeIndex = index - c.imported.journal.length;
            uint64 revision = NativeClock(c.owner).artistNativeReceiptRevisionAt(nativeIndex);
            if (revision <= c.importedAtRevision || revision > c.checkpoint.ownerState.revision) {
                _invalid();
            }
            f.position = RH.Position(
                RH.Point(RH.originHash(c.current), c.ownerIndex, revision), nativeIndex
            );
            f.receipt = Native(c.owner).artistNativeReceiptAt(nativeIndex);
        }
        if (
            f.receipt.operation == 0 || f.receipt.recordHash == 0
                || (f.receipt.operation > 59 && f.receipt.operation != 61)
                || (f.receipt.artistId == 0 && f.receipt.collectionId == 0)
        ) _invalid();
        _point(c, f.position.point);
        f.environment = environment(c, f.position.point.environmentHash);
    }

    function auxiliary(Context memory c, bytes32 kind, bytes32 key)
        public
        view
        returns (OriginFact memory f)
    {
        _fresh(c);
        if (kind == 0 || key == 0) _invalid();
        // Deliberately no catch, zero sentinel, or current-origin inference from missing metadata.
        f.point = Owner(c.owner).recoveredHydrationAuxiliaryPoint(kind, key);
        _point(c, f.point);
        f.environment = environment(c, f.point.environmentHash);
    }

    function replay(Context memory c, bytes32 keyEnvironment, bytes32 surface, bytes32 scope)
        public
        view
        returns (ReplayFact memory f)
    {
        _fresh(c);
        if (surface == 0) _invalid();
        RH.OriginEnvironment memory origin = environment(c, keyEnvironment);
        f.originalKey = Keys.replayKey(origin, c.ownerIndex, AH.Origin(surface, scope));
        if (keyEnvironment == RH.originHash(c.current)) {
            f.cell = IStreamArtistOwner(c.owner).replayCell(f.originalKey);
            f.admission.point = Owner(c.owner).recoveredHydrationReplayPoint(f.originalKey);
        } else {
            bool found;
            for (uint256 i; i < c.imported.aliases.length; ++i) {
                RH.ReplayAlias memory a = c.imported.aliases[i];
                if (a.originalKey != f.originalKey) continue;
                if (
                    found || a.originHash != keyEnvironment || a.ownerIndex != c.ownerIndex
                        || a.surface != surface || a.scope != scope
                ) _invalid();
                f.cell = a.cell;
                f.admission.point = a.admittedAt;
                found = true;
            }
            if (!found) _invalid();
        }
        if (
            f.cell.status == 0 || f.cell.kind == 0 || f.cell.touchedRevision == 0
                || f.cell.touchedRevision != f.admission.point.ownerRevision
        ) _invalid();
        _point(c, f.admission.point);
        f.admission.environment = environment(c, f.admission.point.environmentHash);
    }

    function before(Context memory c, RH.Point memory first, RH.Point memory second)
        public
        pure
        returns (bool)
    {
        return Chronology.beforeOwner(_clock(c), c.ownerIndex, first, second);
    }

    function environment(Context memory c, bytes32 hash)
        public
        pure
        returns (RH.OriginEnvironment memory)
    {
        if (hash == RH.originHash(c.current)) return c.current;
        for (uint256 i; i < c.imported.origins.length; ++i) {
            if (RH.originHash(c.imported.origins[i]) == hash) return c.imported.origins[i];
        }
        revert RH.InvalidRecoveredHydrationProvenance();
    }

    function rewindEnvironment(RH.OriginEnvironment memory o)
        public
        pure
        returns (W.EnvironmentV3 memory)
    {
        return W.EnvironmentV3(
            o.chainId,
            o.registry,
            o.owners[2],
            o.ownerCodeHashes[2],
            o.owners[5],
            o.ownerCodeHashes[5],
            o.coordinator,
            o.archive,
            o.core,
            o.manager
        );
    }

    function nativeKind(uint16 operationId) public pure returns (bytes32) {
        return keccak256(
            abi.encode(keccak256("6529STREAM_ARTIST_RECOVERED_NATIVE_RECORD_V1"), operationId)
        );
    }

    function _current(W.EnvironmentV3 memory e)
        private
        view
        returns (RH.OriginEnvironment memory o)
    {
        if (
            e.chainId != block.chainid || e.coordinator.code.length == 0 || e.registry == address(0)
                || e.archive == address(0) || e.core == address(0) || e.manager == address(0)
        ) _invalid();
        T.SuiteConfiguration memory s = Deployment(e.coordinator).suiteConfiguration();
        if (
            s.registry != e.registry || s.archive != e.archive || s.core != e.core
                || s.mintManager != e.manager || s.owners[2] != e.identityOwner
                || s.owners[5] != e.payoutOwner || e.identityOwner.codehash != e.identityCodeHash
                || e.payoutOwner.codehash != e.payoutCodeHash
                || Deployment(e.coordinator).deploymentChainId() != e.chainId
        ) _invalid();
        o = RH.OriginEnvironment(
            e.chainId,
            e.registry,
            e.coordinator,
            e.archive,
            s.owners,
            o.ownerCodeHashes,
            e.core,
            e.manager,
            keccak256(abi.encode(s))
        );
        for (uint256 i; i < 7; ++i) {
            if (s.owners[i].code.length == 0) _invalid();
            for (uint256 j; j < i; ++j) {
                if (s.owners[j] == s.owners[i]) _invalid();
            }
            o.ownerCodeHashes[i] = s.owners[i].codehash;
        }
    }

    function _point(Context memory c, RH.Point memory point) private pure {
        Chronology.validateOwnerPoint(_clock(c), c.ownerIndex, point);
    }

    /// @dev Clock view only: retained admitted prefix plus the actual current owner checkpoint.
    /// It can contain MAX_ERAS+1 and is never submitted as a transport/import certificate.
    function _clock(Context memory c) private pure returns (RH.OwnerProvenance memory clock) {
        uint256 n = c.imported.eras.length;
        clock.origins = new RH.OriginEnvironment[](n + 1);
        clock.eras = new RH.OwnerEra[](n + 1);
        for (uint256 i; i < n; ++i) {
            clock.origins[i] = c.imported.origins[i];
            clock.eras[i] = c.imported.eras[i];
        }
        clock.origins[n] = c.current;
        clock.eras[n] = RH.OwnerEra(
            RH.originHash(c.current),
            c.checkpoint,
            c.nativeCount,
            c.importedAtRevision,
            c.importCommitment
        );
    }

    function _fresh(Context memory c) private view {
        if (
            (c.ownerIndex != 2 && c.ownerIndex != 5) || c.owner != c.current.owners[c.ownerIndex]
                || c.owner.codehash != c.current.ownerCodeHashes[c.ownerIndex]
                || keccak256(abi.encode(CP(c.owner).authorityCheckpoint()))
                    != keccak256(abi.encode(c.checkpoint))
                || Native(c.owner).artistNativeReceiptCount() != c.nativeCount
        ) _invalid();
    }

    function _invalid() private pure {
        revert RH.InvalidRecoveredHydrationProvenance();
    }
}
