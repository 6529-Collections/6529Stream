// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "../../interfaces/stream/artist/IStreamArtistIdentityDismissal.sol";

import "./StreamArtistRotationHashes.sol";
import "./StreamArtistRegistryValidatorBase.sol";
import "../../interfaces/stream/artist/IStreamArtistRotationOwner.sol";
import "../../interfaces/stream/artist/IStreamArtistIdentityOwner.sol";
import "../../interfaces/stream/artist/IStreamArtistArchiveV2.sol";
import {
    StreamArtistDelegationTypes as D
} from "../../interfaces/stream/artist/StreamArtistDelegationTypes.sol";
import "../../interfaces/stream/parameters/IStreamGasParameterHost.sol";

/// @notice Linked typed rotation recipes in the Coordinator's authenticated, locked context.
library StreamArtistRotationOperations {
    function guardians(
        D.CoordinatorContext memory x,
        address actor,
        R.GuardianSet memory p,
        T.Authorization memory a
    ) public returns (bytes32 record) {
        T.Snapshot[7] memory before_ = _snapshots(x);
        address signer = _authority(x, p.artistId);
        T.Authorization memory effective = T.Authorization(a.nonce, a.time, a.signature);
        if (actor == signer && a.signature.length == 0 && a.time == 0) effective.time = _now();
        T.SignerApproval memory proof = _verify(
            x,
            actor,
            signer,
            StreamArtistRotationHashes.guardianDigest(_environment(x), p, effective),
            effective.signature
        );
        record = IStreamArtistRotationOwner(x.suite.owners[2])
            .setGuardians(T.ActionContext(28, actor, before_[2]), p, effective, proof);
        _archive(
            x,
            28,
            actor,
            record,
            before_,
            abi.encode(
                p,
                a,
                proof,
                effective,
                IStreamArtistRotationOwner(x.suite.owners[2]).guardianSetRecord(record)
            )
        );
    }

    function stage(
        D.CoordinatorContext memory x,
        address actor,
        R.Rotation memory p,
        T.Authorization memory oldAuthorization,
        T.Authorization memory newAuthorization
    ) public returns (bytes32 record) {
        T.Snapshot[7] memory before_ = _snapshots(x);
        if (_authority(x, p.artistId) != p.oldAddress) revert T.InvalidIdentity(p.artistId);
        T.SignerApproval memory oldProof = _verify(
            x,
            actor,
            p.oldAddress,
            StreamArtistRotationHashes.rotationDigest(_environment(x), p, oldAuthorization),
            oldAuthorization.signature
        );
        T.SignerApproval memory newProof = _verify(
            x,
            actor,
            p.newAddress,
            StreamArtistRotationHashes.acceptanceDigest(_environment(x), p, newAuthorization),
            newAuthorization.signature
        );
        record = IStreamArtistRotationOwner(x.suite.owners[2])
            .stageRotation(
                T.ActionContext(29, actor, before_[2]),
                p,
                oldAuthorization,
                newAuthorization,
                oldProof,
                newProof
            );
        _archive(
            x,
            29,
            actor,
            record,
            before_,
            abi.encode(
                p,
                oldAuthorization,
                newAuthorization,
                oldProof,
                newProof,
                IStreamArtistRotationOwner(x.suite.owners[2]).rotationRecord(record)
            )
        );
    }

    function approve(
        D.CoordinatorContext memory x,
        address actor,
        bytes32 artistId,
        bytes32 expected
    ) public {
        T.Snapshot[7] memory before_ = _snapshots(x);
        IStreamArtistRotationOwner(x.suite.owners[2])
            .approveRotation(T.ActionContext(30, actor, before_[2]), artistId, expected);
        _archive(
            x,
            30,
            actor,
            expected,
            before_,
            abi.encode(
                artistId,
                expected,
                IStreamArtistRotationOwner(x.suite.owners[2]).rotationRecord(expected)
            )
        );
    }

    function veto(
        D.CoordinatorContext memory x,
        address actor,
        bytes32 artistId,
        bytes32 expected,
        bytes32 reasonHash
    ) public {
        T.Snapshot[7] memory before_ = _snapshots(x);
        IStreamArtistRotationOwner(x.suite.owners[2])
            .vetoRotation(T.ActionContext(31, actor, before_[2]), artistId, expected, reasonHash);
        _archive(
            x,
            31,
            actor,
            expected,
            before_,
            abi.encode(
                artistId,
                expected,
                reasonHash,
                IStreamArtistRotationOwner(x.suite.owners[2]).rotationRecord(expected),
                IStreamArtistIdentityDismissalOwner(x.suite.owners[2])
                    .currentIdentityContestCause(artistId)
            )
        );
    }

    function execute(
        D.CoordinatorContext memory x,
        address actor,
        bytes32 artistId,
        bytes32 expected
    ) public {
        T.Snapshot[7] memory before_ = _snapshots(x);
        IStreamArtistRotationOwner(x.suite.owners[2])
            .executeRotation(T.ActionContext(32, actor, before_[2]), artistId, expected);
        _archive(
            x,
            32,
            actor,
            expected,
            before_,
            abi.encode(
                artistId,
                expected,
                IStreamArtistRotationOwner(x.suite.owners[2]).rotationRecord(expected)
            )
        );
    }

    function revokeStanding(
        D.CoordinatorContext memory x,
        address actor,
        R.StandingRevocation memory p,
        T.Authorization memory a
    ) public returns (bytes32 record) {
        T.Snapshot[7] memory before_ = _snapshots(x);
        T.SignerApproval memory proof = _verify(
            x,
            actor,
            _authority(x, p.artistId),
            StreamArtistRotationHashes.standingDigest(_environment(x), p, a),
            a.signature
        );
        record = IStreamArtistRotationOwner(x.suite.owners[2])
            .revokeStanding(T.ActionContext(51, actor, before_[2]), p, a, proof);
        _archive(x, 51, actor, record, before_, abi.encode(p, a, proof));
    }

    function _authority(D.CoordinatorContext memory x, bytes32 artistId)
        private
        view
        returns (address signer)
    {
        uint8 class_;
        uint8 status;
        (signer, class_, status,) =
            IStreamArtistIdentityOwner(x.suite.owners[2]).authorityState(artistId);
        if (signer == address(0) || class_ != 1 || status != 1) revert T.InvalidIdentity(artistId);
    }

    function _verify(
        D.CoordinatorContext memory x,
        address actor,
        address signer,
        bytes32 digest,
        bytes memory signature
    ) private view returns (T.SignerApproval memory) {
        if (actor == address(0) || signer == address(0)) {
            revert T.InvalidSignature();
        }
        bool direct = actor == signer && signature.length == 0;
        if (!direct) {
            (uint256 cap,, uint8 failureClass, uint64 revision) = IStreamGasParameterHost(
                    x.suite.registry
                ).gasParameterInfo(keccak256("6529STREAM_GGP_ARTIST_ERC1271_VERIFY_GAS"));
            if (
                revision == 0 || failureClass != 2
                    || !StreamArtistRegistryValidatorBase(x.suite.validator)
                        .validateSignerProof(signer, digest, signature, cap)
            ) revert T.InvalidSignature();
        }
        return T.SignerApproval(signer, digest, direct);
    }

    function _environment(D.CoordinatorContext memory x)
        private
        view
        returns (StreamArtistHashes.Environment memory)
    {
        return StreamArtistHashes.Environment(
            block.chainid, x.suite.registry, x.suite.core, x.suite.mintManager
        );
    }

    function _now() private view returns (uint64) {
        if (block.timestamp > type(uint64).max) revert T.InvalidRecord();
        return uint64(block.timestamp);
    }

    function _snapshots(D.CoordinatorContext memory x)
        private
        view
        returns (T.Snapshot[7] memory result)
    {
        result[2] = IStreamArtistOwner(x.suite.owners[2]).ownerStateSnapshotV2();
    }

    function _archive(
        D.CoordinatorContext memory x,
        uint16 op,
        address actor,
        bytes32 record,
        T.Snapshot[7] memory before_,
        bytes memory payload
    ) private {
        bytes32 id = keccak256(
            abi.encode(
                keccak256("6529STREAM_ARTIST_ONBOARDING_OPERATION_EVIDENCE_V1"),
                block.chainid,
                x.suite.registry,
                address(this),
                op,
                actor,
                record
            )
        );
        bytes memory evidence = abi.encode(
            uint16(1), x.configurationHash, op, actor, record, before_, _snapshots(x), payload
        );
        (bytes32 hash,, bool appended) =
            IStreamArtistArchiveV2(x.suite.archive).appendArtistEvidenceV2(id, 1, evidence);
        if (!appended || hash != keccak256(evidence)) revert T.InvalidRecord();
    }
}
