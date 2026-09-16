// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./StreamArtistSanctionCandidate.sol";
import "./StreamArtistRecordPublicationReads.sol";
import "./StreamArtistRegistryValidatorBase.sol";
import "../../interfaces/stream/artist/IStreamArtistSanction.sol";
import "../../interfaces/stream/artist/IStreamArtistArchiveV2.sol";
import {
    StreamArtistDelegationTypes as D
} from "../../interfaces/stream/artist/StreamArtistDelegationTypes.sol";

/// @notice Typed operation12 in the Coordinator's immutable execution context.
library StreamArtistSanctionOperations {
    function record(
        D.CoordinatorContext memory x,
        StreamArtistSanctionCandidate.Pins memory pins,
        address actor,
        Q.Request memory q,
        T.Authorization memory a
    ) public returns (bytes32 recordHash) {
        if (a.signature.length == 0) revert S.SanctionSignatureRequired();
        if (a.signature.length > 4096) revert T.BoundExceeded(a.signature.length, 4096);
        if (block.timestamp > a.time) revert T.ExpiredAuthorization(a.time);
        T.Snapshot[7] memory prior = _snapshots(x.suite);
        T.Binding memory b =
            StreamArtistRecordPublicationReads.binding(x.suite, q.terms.collectionId);
        C.BindingTerms memory terms = IStreamArtistCollaboratorBindingOwner(x.suite.owners[0])
            .bindingTerms(q.terms.collectionId, b.generation);
        if (
            terms.count != 0
                || terms.capabilityPolicySetHash != StreamArtistHashes.emptyCapabilities()
        ) revert T.UnsupportedProfile();
        StreamArtistHashes.Environment memory e = StreamArtistHashes.Environment(
            block.chainid, x.suite.registry, x.suite.core, x.suite.mintManager
        );
        Q.Prepared memory prepared = StreamArtistSanctionCandidate.prepare(e, pins, q);
        if (
            q.terms.sanctionSubjectHash != StreamArtistSanctionHashes.subject(prepared.subject)
                || q.terms.statementHash != keccak256(prepared.ceremony)
        ) revert S.InvalidSanction();
        R.AuthorityFact memory authority =
            StreamArtistCurrentAuthorityFacts.read(x.suite.owners[2], b.artistId, false);
        bytes32 digest = StreamArtistSanctionHashes.digest(e, q.terms, a);
        (uint256 cap,, uint8 failure, uint64 revision) = IStreamGasParameterHost(x.suite.registry)
            .gasParameterInfo(keccak256("6529STREAM_GGP_ARTIST_ERC1271_VERIFY_GAS"));
        if (
            failure != 2 || revision == 0
                || !StreamArtistRegistryValidatorBase(x.suite.validator)
                    .validateSignerProof(authority.authorityAddress, digest, a.signature, cap)
        ) revert T.InvalidSignature();
        T.SignerApproval memory proof = T.SignerApproval(authority.authorityAddress, digest, false);
        recordHash = IStreamArtistIdentitySanctionOwner(x.suite.owners[2])
            .consumeSanction(T.ActionContext(12, actor, prior[2]), b, q.terms, a, proof);
        if (block.timestamp > type(uint64).max) revert T.InvalidTimestamp(type(uint64).max);
        S.Record memory r = S.Record(
            recordHash,
            b.artistId,
            proof.signer,
            authority.authorityClass,
            q.terms,
            a.nonce,
            uint64(block.timestamp),
            a.time,
            b.generation,
            b.bindingHash,
            digest
        );
        if (
            IStreamArtistSanctionOwner(x.suite.owners[6])
                    .recordSanction(
                        T.ActionContext(12, actor, prior[6]),
                        b,
                        r,
                        authority,
                        pins.finalityRegistry,
                        prepared.ceremony,
                        a.signature
                    ) != recordHash
        ) revert S.InvalidSanction();
        bytes memory payload = abi.encode(b, q, a, proof, authority, r, prepared);
        T.Snapshot[7] memory after_ = _snapshots(x.suite);
        bytes32 id = keccak256(
            abi.encode(
                keccak256("6529STREAM_ARTIST_ONBOARDING_OPERATION_EVIDENCE_V1"),
                block.chainid,
                x.suite.registry,
                address(this),
                uint16(12),
                actor,
                recordHash
            )
        );
        bytes memory evidence = abi.encode(
            uint16(1), x.configurationHash, uint16(12), actor, recordHash, prior, after_, payload
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
            if ((uint256(0x47) & (1 << i)) != 0) {
                result[i] = IStreamArtistOwner(suite.owners[i]).ownerStateSnapshotV2();
            }
        }
    }
}
