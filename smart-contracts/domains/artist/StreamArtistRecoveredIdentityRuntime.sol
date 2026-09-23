// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    StreamArtistRecoveredRuntimeReads as Runtime
} from "./StreamArtistRecoveredRuntimeReads.sol";
import {
    StreamArtistRecoveryRewindEnvironment as Environments
} from "./StreamArtistRecoveryRewindEnvironment.sol";
import { StreamArtistHashes as Hashes } from "./StreamArtistHashes.sol";
import { StreamArtistRotationHashes } from "./StreamArtistRotationHashes.sol";
import {
    StreamArtistRecoveredHydrationTypes as RH
} from "../../interfaces/stream/artist/StreamArtistRecoveredHydrationTypes.sol";
import {
    StreamArtistGuardianVestingTypes as V
} from "../../interfaces/stream/artist/StreamArtistGuardianVestingTypes.sol";
import {
    StreamArtistGuardianHistoryTypes as GH
} from "../../interfaces/stream/artist/StreamArtistGuardianHistoryTypes.sol";
import {
    StreamArtistRotationTypes as R
} from "../../interfaces/stream/artist/StreamArtistRotationTypes.sol";
import {
    StreamArtistRecoveryActionTypes as A
} from "../../interfaces/stream/artist/StreamArtistRecoveryActionTypes.sol";
import {
    StreamArtistOnboardingTypes as T
} from "../../interfaces/stream/artist/StreamArtistOnboardingTypes.sol";
import { IStreamArtistOwner } from "../../interfaces/stream/artist/IStreamArtistOwner.sol";
import {
    IStreamArtistRecoveredHydrationOwner
} from "../../interfaces/stream/artist/IStreamArtistRecoveredHydration.sol";
import {
    IStreamArtistGuardianHistory
} from "../../interfaces/stream/artist/IStreamArtistGuardianHistory.sol";

/// @notice Typed Identity origin joins over the complete retained prefix and actual local suffix.
/// @dev New signatures and authorization keep the current environment. These reads authenticate
/// the creation domain of retained facts without changing their original bodies or revisions.
library StreamArtistRecoveredIdentityRuntime {
    bytes32 internal constant VESTING = keccak256("identity_authority.hydration.guardian_vesting");
    bytes32 internal constant PREPARATION =
        keccak256("identity_authority.replay.recovery_preparation");

    function active(address owner) public view returns (bool) {
        (, bytes32 commitment,) =
            IStreamArtistRecoveredHydrationOwner(owner).recoveredHydrationImportedPrefix();
        return commitment != 0;
    }

    function load(address owner, address registry, uint256 chainId)
        public
        view
        returns (Runtime.Context memory c)
    {
        IStreamArtistOwner source = IStreamArtistOwner(owner);
        if (
            chainId != block.chainid || source.deploymentChainId() != chainId
                || source.artistRegistry() != registry
        ) _invalid();
        c = Runtime.load(
            Environments.fromFixed(
                owner,
                registry,
                source.operationCoordinator(),
                source.archiveV2(),
                source.core(),
                source.mintManager()
            ),
            2
        );
    }

    function nativeFact(Runtime.Context memory c, uint16 operation, bytes32 artistId, bytes32 key)
        public
        view
        returns (Runtime.ReceiptFact memory f)
    {
        uint256 count = Runtime.logicalCount(c);
        if (c.ownerIndex != 2 || operation == 0 || artistId == 0 || key == 0) _invalid();
        bool found;
        for (uint256 i; i < count; ++i) {
            Runtime.ReceiptFact memory row = Runtime.receiptAt(c, i);
            if (
                row.receipt.operation != operation || row.receipt.artistId != artistId
                    || row.receipt.recordHash != key
            ) continue;
            if (found || row.receipt.collectionId != 0) _invalid();
            f = row;
            found = true;
        }
        if (!found) _invalid();
    }

    function hashes(RH.OriginEnvironment memory origin)
        public
        pure
        returns (Hashes.Environment memory)
    {
        return Hashes.Environment(origin.chainId, origin.registry, origin.core, origin.manager);
    }

    function guardianEntry(Runtime.Context memory c, GH.Entry memory entry)
        public
        view
        returns (Runtime.OriginFact memory f)
    {
        Runtime.ReceiptFact memory row = nativeFact(c, 28, entry.artistId, entry.recordHash);
        f = Runtime.OriginFact(row.position.point, row.environment);
        if (
            entry.index == 0 || entry.ownerRevision != f.point.ownerRevision
                || entry.recordDataHash == 0 || entry.commitment == 0
                || entry.commitment != guardianHash(f.environment, entry)
        ) _invalid();
    }

    function guardian(
        Runtime.Context memory c,
        GH.Entry memory entry,
        R.GuardianRecord memory record
    ) public view returns (Runtime.OriginFact memory f) {
        f = guardianEntry(c, entry);
        if (
            record.recordHash != entry.recordHash || record.terms.artistId != entry.artistId
                || record.signer == address(0)
                || (record.authorityClass != 1 && record.authorityClass != 3)
                || entry.recordDataHash != keccak256(abi.encode(record))
                || StreamArtistRotationHashes.guardianRecord(
                        hashes(f.environment),
                        record.terms,
                        T.Authorization(record.nonce, record.signedAt, new bytes(0))
                    ) != record.recordHash
        ) _invalid();
    }

    function guardianStep(
        Runtime.Context memory c,
        GH.Entry memory entry,
        R.GuardianRecord memory record,
        uint64 previousRevision,
        bytes32 previousCommitment
    ) public view returns (Runtime.OriginFact memory current) {
        current = guardian(c, entry, record);
        if (entry.previousCommitment != previousCommitment) _invalid();
        if (entry.index == 1) {
            if (previousRevision != 0 || previousCommitment != 0) _invalid();
        } else {
            (, GH.Entry memory previous,,) = IStreamArtistGuardianHistory(c.owner)
                .guardianHistoryState(entry.artistId, entry.index - 1, address(0), 0);
            Runtime.OriginFact memory older = guardianEntry(c, previous);
            if (
                previous.ownerRevision != previousRevision
                    || previous.commitment != previousCommitment
                    || !Runtime.before(c, older.point, current.point)
            ) _invalid();
        }
    }

    function guardianHash(RH.OriginEnvironment memory origin, GH.Entry memory entry)
        public
        pure
        returns (bytes32)
    {
        return keccak256(
            abi.encode(
                keccak256("6529STREAM_ARTIST_GUARDIAN_ADMISSION_HISTORY_V1"),
                origin.chainId,
                origin.registry,
                origin.owners[2],
                entry.artistId,
                entry.index,
                entry.ownerRevision,
                entry.recordHash,
                entry.recordDataHash,
                entry.previousCommitment
            )
        );
    }

    function vesting(Runtime.Context memory c, V.Snapshot memory v)
        public
        view
        returns (Runtime.OriginFact memory f)
    {
        f = Runtime.auxiliary(c, VESTING, v.transitionRecordHash);
        if (
            v.artistId == 0 || v.ownerRevision != f.point.ownerRevision || v.executedAt == 0
                || v.oldAddress == address(0) || v.newAddress == address(0)
                || v.oldAddress == v.newAddress || (v.authorityClass != 1 && v.authorityClass != 3)
                || (v.operationId != 32
                    && v.operationId != 35
                    && v.operationId != 40
                    && v.operationId != 43) || (v.operationId == 40 && v.authorityClass != 3)
                || v.commitment == 0 || v.commitment != vestingHash(f.environment, v)
        ) _invalid();
        if (v.guardians.count == 0) {
            if (v.guardians.ownerRevision != 0 || v.guardians.commitment != 0) _invalid();
        } else {
            (, GH.Entry memory entry,,) = IStreamArtistGuardianHistory(c.owner)
                .guardianHistoryState(v.artistId, v.guardians.count, address(0), 0);
            Runtime.OriginFact memory g = guardianEntry(c, entry);
            if (
                entry.index != v.guardians.count || entry.ownerRevision != v.guardians.ownerRevision
                    || entry.commitment != v.guardians.commitment
                    || !Runtime.before(c, g.point, f.point)
            ) _invalid();
        }
    }

    function vestingHash(RH.OriginEnvironment memory origin, V.Snapshot memory v)
        public
        pure
        returns (bytes32)
    {
        return keccak256(
            bytes.concat(
                abi.encode(
                    keccak256("6529STREAM_ARTIST_GUARDIAN_VESTING_V1"),
                    origin.chainId,
                    origin.registry,
                    origin.owners[2]
                ),
                abi.encode(
                    v.artistId,
                    v.transitionRecordHash,
                    v.operationId,
                    v.ownerRevision,
                    v.executedAt,
                    v.oldAddress,
                    v.newAddress,
                    v.authorityClass,
                    v.guardians,
                    v.previousTransitionRecordHash,
                    v.previousCommitment
                )
            )
        );
    }

    function preparation(Runtime.Context memory c, A.Association memory a)
        public
        view
        returns (Runtime.OriginFact memory f)
    {
        f = Runtime.auxiliary(c, PREPARATION, a.action.actionId);
        Runtime.ReplayFact memory replay =
            Runtime.replay(c, f.point.environmentHash, PREPARATION, a.action.actionId);
        if (
            a.artistId == 0 || a.associationHash == 0 || a.ownerRevision != f.point.ownerRevision
                || replay.cell.kind != 1 || replay.cell.status != 2
                || replay.cell.commitment != a.associationHash
                || !samePoint(replay.admission.point, f.point)
        ) _invalid();
    }

    function samePoint(RH.Point memory a, RH.Point memory b) public pure returns (bool) {
        return a.environmentHash == b.environmentHash && a.ownerIndex == b.ownerIndex
            && a.ownerRevision == b.ownerRevision;
    }

    function _invalid() private pure {
        revert RH.InvalidRecoveredHydrationProvenance();
    }
}
