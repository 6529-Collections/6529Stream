// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./StreamArtistEconomicOperations.sol";
import "../../interfaces/stream/core/IStreamCoreCollectionView.sol";
import "../../interfaces/stream/artist/IStreamArtistBindingTerminationOwner.sol";
import "../../interfaces/stream/artist/IStreamArtistIdentityBindingOwner.sol";
import "../../interfaces/stream/artist/IStreamArtistAttributionBindingOwner.sol";
import "../../interfaces/stream/artist/IStreamArtistCollaboratorBindingOwner.sol";
import "../../interfaces/stream/artist/IStreamArtistCollaboratorRecordsOwner.sol";
import "../../interfaces/stream/artist/IStreamArtistCurrentBindingOwner.sol";

/// @notice Linked typed pending-binding recipes behind the Coordinator's authentication, code checks and lock.
/// @dev Owns no semantic state. Hash functions use the explicit immutable registry environment.
library StreamArtistBindingOperations {
    function accept(
        D.CoordinatorContext memory x,
        address actor,
        uint256 collectionId,
        T.Authorization memory a,
        uint64 expectedGeneration,
        bytes32 expectedHash,
        bool expected
    ) public returns (bytes32 record) {
        T.Snapshot[7] memory before_ = _snapshots(x, 2);
        T.Binding memory b = IStreamArtistBindingOwner(x.suite.owners[0]).binding(collectionId);
        if (!IStreamCoreCollectionView(x.suite.core).collectionExists(collectionId)) {
            revert T.InvalidAttribution(collectionId);
        }
        (uint8 state, uint64 generation) =
            IStreamArtistAttributionOwner(x.suite.owners[4]).attributionState(collectionId);
        if (b.accepted || b.bindingHash == bytes32(0) || state != 1 || generation != b.generation) {
            revert T.InvalidAttribution(collectionId);
        }
        R.AuthorityFact memory authority =
            StreamArtistCurrentAuthorityFacts.read(x.suite.owners[2], b.artistId, false);
        if (expected) {
            if (b.generation != expectedGeneration || b.bindingHash != expectedHash) {
                revert T.InvalidAttribution(collectionId);
            }
        } else if (
            actor == authority.authorityAddress && a.signature.length == 0 && b.generation != 1
        ) {
            revert T.InvalidAttribution(collectionId);
        }
        T.SignerApproval memory proof = _verify(
            x,
            actor,
            authority.authorityAddress,
            StreamArtistHashes.acceptanceDigest(_environment(x), collectionId, b, a),
            a.signature
        );
        record = IStreamArtistIdentityOwner(x.suite.owners[2])
            .consumeAcceptance(T.ActionContext(2, actor, before_[2]), collectionId, b, a, proof);
        bytes32 actual = IStreamArtistCurrentAcceptanceOwner(x.suite.owners[3])
            .recordAcceptanceWithAuthority(
                T.ActionContext(2, actor, before_[3]),
                collectionId,
                b,
                authority,
                proof.signer,
                a.nonce
            );
        if (actual != record) revert T.InvalidRecord();
        uint32 required =
            IStreamArtistCollaboratorBindingOwner(x.suite.owners[0])
        .bindingTerms(collectionId, b.generation)
        .count;
        uint32 accepted =
            IStreamArtistCollaboratorRecordsOwner(x.suite.owners[1]).acceptedCount(b.bindingHash);
        if (accepted > required) revert T.InvalidRecord();
        bool complete = accepted == required;
        if (complete) {
            IStreamArtistBindingOwner(x.suite.owners[0])
                .accept(T.ActionContext(2, actor, before_[0]), collectionId, b.bindingHash, record);
            IStreamArtistCurrentAttributionOwner(x.suite.owners[4])
                .acceptWithAuthority(
                    T.ActionContext(2, actor, before_[4]), collectionId, b, record, authority
                );
        }
        bytes memory payload = expected
            ? abi.encode(collectionId, b, a, proof, expectedGeneration, expectedHash)
            : abi.encode(collectionId, b, a, proof);
        if (required != 0) payload = abi.encode(payload, required, accepted, complete);
        payload = abi.encode(payload, authority);
        _archive(x, 2, actor, record, before_, payload);
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
            (uint256 cap,, uint8 failure, uint64 revision) = IStreamGasParameterHost(
                    x.suite.registry
                ).gasParameterInfo(keccak256("6529STREAM_GGP_ARTIST_ERC1271_VERIFY_GAS"));
            if (
                revision == 0 || failure != 2
                    || !StreamArtistRegistryValidatorBase(x.suite.validator)
                        .validateSignerProof(signer, digest, signature, cap)
            ) revert T.InvalidSignature();
        }
        return T.SignerApproval(signer, digest, direct);
    }

    function refusalDigest(
        StreamArtistHashes.Environment memory e,
        L.Termination memory p,
        T.Authorization memory a
    ) public pure returns (bytes32) {
        return StreamArtistHashes.typed(
            e,
            keccak256(
                abi.encode(
                    bytes32(0xc893b08f32a42da1625fa6427599c670031a4718906493412194962b8605a4bc),
                    e.core,
                    p.collectionId,
                    p.generation,
                    p.bindingHash,
                    p.reasonHash,
                    a.nonce,
                    a.time
                )
            )
        );
    }

    function refusalRecord(
        StreamArtistHashes.Environment memory e,
        L.Termination memory p,
        bytes32 artistId,
        address signer,
        uint256 nonce,
        uint64 time
    ) public pure returns (bytes32) {
        return keccak256(
            abi.encode(
                bytes32(0x61e2c527c98d65328522fa0ac36862f52a59a2035e3e2ca4a0bfd5da13ee95ed),
                e.chainId,
                e.registry,
                e.core,
                p.collectionId,
                p.generation,
                p.bindingHash,
                artistId,
                signer,
                uint8(1),
                p.reasonHash,
                nonce,
                time
            )
        );
    }

    function refusalRecordForAuthority(
        StreamArtistHashes.Environment memory e,
        L.Termination memory p,
        bytes32 artistId,
        address signer,
        uint8 authorityClass,
        uint256 nonce,
        uint64 time
    ) public pure returns (bytes32) {
        return keccak256(
            abi.encode(
                bytes32(0x61e2c527c98d65328522fa0ac36862f52a59a2035e3e2ca4a0bfd5da13ee95ed),
                e.chainId,
                e.registry,
                e.core,
                p.collectionId,
                p.generation,
                p.bindingHash,
                artistId,
                signer,
                authorityClass,
                p.reasonHash,
                nonce,
                time
            )
        );
    }

    function refuse(
        D.CoordinatorContext memory x,
        address actor,
        L.Termination memory p,
        T.Authorization memory a
    ) public returns (bytes32 record) {
        T.Snapshot[7] memory before_ = _snapshots(x, 3);
        T.Binding memory b = _pending(x, p);
        R.AuthorityFact memory authority =
            StreamArtistCurrentAuthorityFacts.read(x.suite.owners[2], b.artistId, false);
        bytes32 digest = refusalDigest(_environment(x), p, a);
        T.SignerApproval memory proof =
            _verify(x, actor, authority.authorityAddress, digest, a.signature);
        record = IStreamArtistIdentityBindingOwner(x.suite.owners[2])
            .consumeRefusal(T.ActionContext(3, actor, before_[2]), b, p, a, proof);
        bytes32 actual = IStreamArtistCurrentBindingOwner(x.suite.owners[0])
            .refuseWithAuthority(
                T.ActionContext(3, actor, before_[0]), p, authority, proof.signer, a.nonce
            );
        if (actual != record) revert T.InvalidRecord();
        IStreamArtistCurrentAttributionOwner(x.suite.owners[4])
            .recordRefusalWithAuthority(
                T.ActionContext(3, actor, before_[4]),
                b,
                p,
                authority,
                proof.signer,
                a.nonce,
                record
            );
        _archive(x, 3, actor, record, before_, abi.encode(b, p, a, proof, authority));
    }

    function withdraw(D.CoordinatorContext memory x, address actor, L.Termination memory p) public {
        T.Snapshot[7] memory before_ = _snapshots(x, 4);
        T.Binding memory b = _pending(x, p);
        if (actor != b.proposer) revert T.Unauthorized(actor);
        IStreamArtistBindingTerminationOwner(x.suite.owners[0])
            .withdraw(T.ActionContext(4, actor, before_[0]), p);
        IStreamArtistAttributionBindingOwner(x.suite.owners[4])
            .recordWithdrawal(T.ActionContext(4, actor, before_[4]), b, p);
        // Operation4 cites the existing binding record; it creates no new semantic record.
        _archive(x, 4, actor, b.bindingHash, before_, abi.encode(b, p));
    }

    function _pending(D.CoordinatorContext memory x, L.Termination memory p)
        private
        view
        returns (T.Binding memory b)
    {
        b = IStreamArtistBindingOwner(x.suite.owners[0]).binding(p.collectionId);
        (uint8 state, uint64 generation) =
            IStreamArtistAttributionOwner(x.suite.owners[4]).attributionState(p.collectionId);
        if (
            b.accepted || state != 1 || generation != b.generation || p.generation != b.generation
                || p.bindingHash != b.bindingHash || b.bindingHash == bytes32(0)
        ) revert T.InvalidAttribution(p.collectionId);
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

    function _snapshots(D.CoordinatorContext memory x, uint16 op)
        private
        view
        returns (T.Snapshot[7] memory result)
    {
        uint256 mask = op == 2 ? 0x1f : op == 3 ? 0x15 : 0x11;
        for (uint256 i; i < 7; ++i) {
            if ((mask & (1 << i)) != 0) {
                result[i] = IStreamArtistOwner(x.suite.owners[i]).ownerStateSnapshotV2();
            }
        }
    }

    function _archive(
        D.CoordinatorContext memory x,
        uint16 op,
        address actor,
        bytes32 recordReference,
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
                recordReference
            )
        );
        bytes memory evidence = abi.encode(
            uint16(1),
            x.configurationHash,
            op,
            actor,
            recordReference,
            before_,
            _snapshots(x, op),
            payload
        );
        (bytes32 hash,, bool appended) =
            IStreamArtistArchiveV2(x.suite.archive).appendArtistEvidenceV2(id, 1, evidence);
        if (!appended || hash != keccak256(evidence)) revert T.InvalidRecord();
    }
}
