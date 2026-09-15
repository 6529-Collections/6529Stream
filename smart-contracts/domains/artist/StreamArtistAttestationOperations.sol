// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "./StreamArtistEconomicOperations.sol";
import "./StreamArtistRecordPublicationReads.sol";
import "./StreamArtistAttestationSubjectReads.sol";
import {
    StreamArtistAttestationTypes as Attest,
    IStreamArtistAttestationIdentityOwner,
    IStreamArtistAuthenticatedAttestationOwner
} from "../../interfaces/stream/artist/IStreamArtistAttestationWriter.sol";

/// @notice Original op24 authorization with authenticated subject owners and optional original delegation.
library StreamArtistAttestationOperations {
    function attest(
        D.CoordinatorContext memory x,
        address actor,
        T.Attestation memory p,
        Attest.Subject memory subject,
        bool scoped,
        bytes32 grant,
        T.Authorization memory submitted,
        bytes memory statement
    ) public returns (bytes32 record) {
        T.Snapshot[7] memory before_ = _snapshots(x, 24);
        T.Binding memory b = StreamArtistRecordPublicationReads.binding(x.suite, p.collectionId);
        if (!IStreamCoreCollectionView(x.suite.core).collectionExists(p.collectionId)) {
            revert T.InvalidAttribution(p.collectionId);
        }
        Attest.Admission memory admission;
        admission.authority =
            StreamArtistCurrentAuthorityFacts.read(x.suite.owners[2], b.artistId, false);
        D.Record memory delegation;
        address signer = admission.authority.authorityAddress;
        if (grant != 0) {
            delegation = IStreamArtistDelegationOwner(x.suite.owners[2]).delegationRecord(grant);
            signer = delegation.grant.delegate;
        }
        bytes memory subjectEvidence;
        if (p.subjectKind <= 6) {
            (admission.fact, subjectEvidence) =
                StreamArtistAttestationSubjectReads.read(x.suite, p, subject, scoped);
        } else {
            if (scoped) revert T.UnsupportedProfile();
            if (p.subjectKind == 7 || p.subjectKind == 8) {
                (P.Publication memory publication,) =
                    StreamArtistRecordPublicationRules.decode(p, statement);
                if (publication.recorder != signer) revert T.InvalidRecord();
                bytes32 runtime = StreamArtistRecordPublicationReads.candidate(x.suite, publication);
                admission.fact =
                    Attest.Fact(publication.metadataHost, runtime, p.subjectId, p.subjectStateHash);
                subjectEvidence = abi.encode(publication, runtime);
            } else if (p.subjectKind == 9) {
                admission.fact = Attest.Fact(
                    x.suite.core,
                    x.suite.core.codehash,
                    p.subjectId,
                    StreamArtistHashes.deploymentFacts(_environment(x), p.collectionId, b)
                );
            } else if (p.subjectKind == 10) {
                admission.operativeIdentity = IStreamArtistIdentityRevisionReads(x.suite.owners[2])
                    .operativeIdentityRecord(b.artistId);
                admission.fact = Attest.Fact(
                    x.suite.owners[2],
                    x.suite.owners[2].codehash,
                    b.artistId,
                    admission.operativeIdentity
                );
            } else {
                revert T.UnsupportedProfile();
            }
        }
        T.Authorization memory effective = _directTime(actor, signer, submitted);
        T.SignerApproval memory proof = _verify(
            x,
            actor,
            signer,
            StreamArtistHashes.attestationDigest(_environment(x), p, effective),
            effective.signature
        );
        admission.signer = signer;
        admission.nonce = effective.nonce;
        admission.signedAt = effective.time;
        admission.delegation = grant;
        if (grant == 0) {
            record = IStreamArtistIdentityOwner(x.suite.owners[2])
                .consumeAttestation(T.ActionContext(24, actor, before_[2]), b, p, effective, proof);
        } else {
            record = IStreamArtistAttestationIdentityOwner(x.suite.owners[2])
                .consumeDelegatedAttestation(
                    T.ActionContext(24, actor, before_[2]), b, p, grant, effective, proof
                );
        }
        bytes32 actual = IStreamArtistAuthenticatedAttestationOwner(x.suite.owners[4])
            .recordAuthenticatedAttestation(
                T.ActionContext(24, actor, before_[4]), b, p, admission, statement
            );
        if (actual != record) revert T.InvalidRecord();
        _archive(
            x,
            24,
            actor,
            record,
            before_,
            abi.encode(
                b,
                p,
                submitted,
                effective,
                proof,
                statement,
                subject,
                scoped,
                admission,
                delegation,
                subjectEvidence
            )
        );
    }

    function _directTime(address actor, address signer, T.Authorization memory submitted)
        private
        view
        returns (T.Authorization memory effective)
    {
        effective = T.Authorization(submitted.nonce, submitted.time, submitted.signature);
        if (
            actor == signer && actor != address(0) && submitted.signature.length == 0
                && submitted.time == 0
        ) {
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
            (uint256 cap,, uint8 failure, uint64 revision) = IStreamGasParameterHost(
                    x.suite.registry
                ).gasParameterInfo(keccak256("6529STREAM_GGP_ARTIST_ERC1271_VERIFY_GAS"));
            if (
                failure != 2 || revision == 0
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

    function _snapshots(D.CoordinatorContext memory x, uint16 op)
        private
        view
        returns (T.Snapshot[7] memory result)
    {
        uint256 mask = op == 25 ? 0x04 : 0x17;
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
            uint16(1), x.configurationHash, op, actor, record, before_, _snapshots(x, op), payload
        );
        (bytes32 hash,, bool appended) =
            IStreamArtistArchiveV2(x.suite.archive).appendArtistEvidenceV2(id, 1, evidence);
        if (!appended || hash != keccak256(evidence)) revert T.InvalidRecord();
    }
}
