// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./StreamArtistRecoveryApprovalReads.sol";
import "./StreamArtistRegistryValidatorBase.sol";
import "../../interfaces/stream/artist/IStreamArtistArchiveV2.sol";
import {
    StreamArtistDelegationTypes as D
} from "../../interfaces/stream/artist/StreamArtistDelegationTypes.sol";

/// @notice Locked operation22: shared Identity nonce first, immutable Consent approval second.
library StreamArtistRecoveryApprovalOperations {
    function record(
        D.CoordinatorContext memory x,
        StreamArtistRecoveryOriginalReads.Pins memory pins,
        address actor,
        Approval.Request memory request,
        T.Authorization memory a
    ) public returns (bytes32 recordHash) {
        if (actor == address(0)) revert T.Unauthorized(actor);
        if (a.signature.length > 4096) revert T.BoundExceeded(a.signature.length, 4096);
        if (block.timestamp > a.time) revert T.ExpiredAuthorization(a.time);
        T.Snapshot[7] memory prior = _snapshots(x.suite);
        StreamArtistRecoveryApprovalReads.Prepared memory p =
            StreamArtistRecoveryApprovalReads.prepare(x.suite, pins, request);
        StreamArtistHashes.Environment memory e = StreamArtistHashes.Environment(
            block.chainid, x.suite.registry, x.suite.core, x.suite.mintManager
        );
        bytes32 digest =
            StreamArtistRecoveryHashes.approvalDigest(e, request.terms, a.nonce, a.time);
        T.SignerApproval memory proof =
            _proof(x.suite, actor, p.authority.authorityAddress, digest, a.signature);
        if (
            keccak256(abi.encode(p))
                    != keccak256(
                        abi.encode(
                            StreamArtistRecoveryApprovalReads.prepare(x.suite, pins, request)
                        )
                    ) || keccak256(abi.encode(prior)) != keccak256(abi.encode(_snapshots(x.suite)))
        ) revert T.InvalidRecord();
        recordHash = IStreamArtistIdentityRecoveryApprovalOwner(x.suite.owners[2])
            .consumeRecoveryApproval(
                T.ActionContext(22, actor, prior[2]), p.binding_, request.terms, a, proof
            );
        if (block.timestamp > type(uint64).max) revert T.InvalidTimestamp(type(uint64).max);
        Recovery.ApprovalRecord memory r = Recovery.ApprovalRecord(
            recordHash,
            request.terms,
            p.binding_.artistId,
            proof.signer,
            p.authority.authorityClass,
            a.nonce,
            uint64(block.timestamp),
            a.time,
            p.binding_.generation,
            p.binding_.bindingHash,
            digest
        );
        if (
            IStreamArtistRecoveryApprovalOwner(x.suite.owners[6])
                    .recordRecoveryApproval(
                        T.ActionContext(22, actor, prior[6]),
                        p.binding_,
                        r,
                        p.authority,
                        p.admission
                    ) != recordHash
        ) {
            revert Recovery.InvalidRecoveryApproval();
        }
        _append(x, actor, recordHash, prior, abi.encode(request, a, proof, p, r));
    }

    function _proof(
        T.SuiteConfiguration memory suite,
        address actor,
        address signer,
        bytes32 digest,
        bytes memory signature
    ) private view returns (T.SignerApproval memory) {
        if (actor == signer && signature.length == 0) {
            return T.SignerApproval(signer, digest, true);
        }
        (uint256 cap,, uint8 failure, uint64 revision) = IStreamGasParameterHost(suite.registry)
            .gasParameterInfo(keccak256("6529STREAM_GGP_ARTIST_ERC1271_VERIFY_GAS"));
        if (
            cap == 0 || failure != 2 || revision == 0
                || !StreamArtistRegistryValidatorBase(suite.validator)
                    .validateSignerProof(signer, digest, signature, cap)
        ) revert T.InvalidSignature();
        return T.SignerApproval(signer, digest, false);
    }

    function _append(
        D.CoordinatorContext memory x,
        address actor,
        bytes32 recordHash,
        T.Snapshot[7] memory prior,
        bytes memory payload
    ) private {
        T.Snapshot[7] memory after_ = _snapshots(x.suite);
        bytes32 id = keccak256(
            abi.encode(
                keccak256("6529STREAM_ARTIST_ONBOARDING_OPERATION_EVIDENCE_V1"),
                block.chainid,
                x.suite.registry,
                address(this),
                uint16(22),
                actor,
                recordHash
            )
        );
        bytes memory evidence = abi.encode(
            uint16(1), x.configurationHash, uint16(22), actor, recordHash, prior, after_, payload
        );
        (bytes32 hash,, bool appended) =
            IStreamArtistArchiveV2(x.suite.archive).appendArtistEvidenceV2(id, 1, evidence);
        if (!appended || hash != keccak256(evidence)) revert T.InvalidRecord();
    }

    function _snapshots(T.SuiteConfiguration memory suite)
        private
        view
        returns (T.Snapshot[7] memory result)
    {
        for (uint256 i; i < 7; ++i) {
            if ((uint256(0x57) & (1 << i)) != 0) {
                result[i] = IStreamArtistOwner(suite.owners[i]).ownerStateSnapshotV2();
            }
        }
    }
}
