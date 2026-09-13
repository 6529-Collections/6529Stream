// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./StreamArtistSuccessionHashes.sol";
import "./StreamArtistRegistryValidatorBase.sol";
import "../../interfaces/stream/artist/IStreamArtistIdentityOwner.sol";
import "../../interfaces/stream/artist/IStreamArtistArchiveV2.sol";
import {
    StreamArtistDelegationTypes as D
} from "../../interfaces/stream/artist/StreamArtistDelegationTypes.sol";
import "../../interfaces/stream/parameters/IStreamGasParameterHost.sol";

/// @notice Fixed typed succession recipes, executed in the authenticated locked Coordinator.
library StreamArtistSuccessionOperations {
    function designate(
        D.CoordinatorContext memory x,
        address actor,
        Succ.Designation memory p,
        T.Authorization memory submitted
    ) public returns (bytes32 record) {
        T.Snapshot[7] memory before_ = _snapshots(x);
        address signer = _authority(x, p.artistId);
        T.Authorization memory effective = _effective(actor, signer, submitted);
        T.SignerApproval memory proof = _verify(
            x,
            actor,
            signer,
            StreamArtistSuccessionHashes.designationDigest(_environment(x), p, effective),
            effective.signature
        );
        IStreamArtistSuccessionOwner owner = IStreamArtistSuccessionOwner(x.suite.owners[2]);
        record = owner.recordSuccessorDesignation(
            T.ActionContext(36, actor, before_[2]), p, effective, proof
        );
        _archive(
            x,
            36,
            actor,
            record,
            before_,
            abi.encode(p, submitted, effective, proof, owner.successorDesignationRecord(record))
        );
    }

    function directive(
        D.CoordinatorContext memory x,
        address actor,
        Succ.Directive memory p,
        T.Authorization memory submitted,
        Succ.PublicDocument memory document
    ) public returns (bytes32 record) {
        T.Snapshot[7] memory before_ = _snapshots(x);
        address signer = _authority(x, p.artistId);
        T.Authorization memory effective = _effective(actor, signer, submitted);
        T.SignerApproval memory proof = _verify(
            x,
            actor,
            signer,
            StreamArtistSuccessionHashes.directiveDigest(_environment(x), p, effective),
            effective.signature
        );
        IStreamArtistSuccessionOwner owner = IStreamArtistSuccessionOwner(x.suite.owners[2]);
        record = owner.recordEstateDirective(
            T.ActionContext(37, actor, before_[2]), p, effective, proof, document
        );
        _archive(
            x,
            37,
            actor,
            record,
            before_,
            abi.encode(
                p,
                submitted,
                effective,
                proof,
                document,
                owner.estateDirectiveRecord(record),
                owner.estateDirectivePayload(record)
            )
        );
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

    function _effective(address actor, address signer, T.Authorization memory submitted)
        private
        view
        returns (T.Authorization memory effective)
    {
        effective = T.Authorization(submitted.nonce, submitted.time, submitted.signature);
        if (actor == signer && submitted.signature.length == 0 && submitted.time == 0) {
            if (block.timestamp > type(uint64).max) revert T.InvalidRecord();
            effective.time = uint64(block.timestamp);
        }
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
            ) {
                revert T.InvalidSignature();
            }
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
