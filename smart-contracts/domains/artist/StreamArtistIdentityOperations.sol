// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./StreamArtistEconomicOperations.sol";
import "./StreamArtistIdentityRevisionState.sol";
import "../../interfaces/stream/artist/IStreamArtistCurrentBindingOwner.sol";

/// @notice Typed identity recipes in the guarded Coordinator's delegatecall context.
library StreamArtistIdentityOperations {
    function revise(
        D.CoordinatorContext memory x,
        address actor,
        StreamArtistIdentityRevisionTypes.Revision memory p,
        T.Authorization memory submitted,
        bytes memory document,
        string memory displayName
    ) public returns (bytes32 record) {
        T.Snapshot[7] memory before_ = _snapshots(x, 25);
        (address signer, uint8 class_, uint8 status,) =
            IStreamArtistIdentityOwner(x.suite.owners[2]).authorityState(p.artistId);
        if (class_ != 1 || status != 1) revert T.InvalidIdentity(p.artistId);
        T.Authorization memory effective = _directTime(actor, signer, submitted);
        T.SignerApproval memory proof = _verify(
            x,
            actor,
            signer,
            StreamArtistIdentityRevisionState.digest(_environment(x), p, effective),
            effective.signature
        );
        record = IStreamArtistIdentityRevisionOwner(x.suite.owners[2])
            .recordIdentityRevision(
                T.ActionContext(25, actor, before_[2]), p, effective, proof, document, displayName
            );
        _archive(
            x,
            25,
            actor,
            record,
            before_,
            abi.encode(p, submitted, document, displayName, proof, effective)
        );
    }

    function validateProposalIdentity(
        address owner,
        T.BindingProposal memory p,
        bytes memory document,
        string memory displayName
    ) public view {
        IStreamArtistIdentityOwner identity = IStreamArtistIdentityOwner(owner);
        (address authority, uint8 class_, uint8 status,) = identity.authorityState(p.artistId);
        (bytes32 hash, string memory uri, string memory name) =
            IStreamArtistIdentityRevisionOwner(owner).operativeIdentityMetadata(p.artistId);
        if (
            status != 1 || class_ != 1 || authority != p.artistAddress
                || hash != p.identityRecordHash
                || identity.activeIdentity(p.artistAddress) != p.artistId
                || keccak256(document) != hash
                || keccak256(bytes(displayName)) != keccak256(bytes(name))
                || keccak256(bytes(p.identityRecordURI)) != keccak256(bytes(uri))
        ) {
            revert T.InvalidIdentity(p.artistId);
        }
    }

    function attest(
        D.CoordinatorContext memory x,
        address actor,
        T.Attestation memory p,
        T.Authorization memory submitted,
        bytes memory statement
    ) public returns (bytes32 record) {
        T.Snapshot[7] memory before_ = _snapshots(x, 24);
        T.Binding memory b = StreamArtistOnboardingReads(x.reads).acceptedBinding(p.collectionId);
        if (!IStreamCoreCollectionView(x.suite.core).collectionExists(p.collectionId)) {
            revert T.InvalidAttribution(p.collectionId);
        }
        R.AuthorityFact memory authority =
            StreamArtistCurrentAuthorityFacts.read(x.suite.owners[2], b.artistId, false);
        T.Authorization memory effective = _directTime(actor, authority.authorityAddress, submitted);
        T.SignerApproval memory proof = _verify(
            x,
            actor,
            authority.authorityAddress,
            StreamArtistHashes.attestationDigest(_environment(x), p, effective),
            effective.signature
        );
        bytes32 operative;
        if (p.subjectKind == 10) {
            operative = IStreamArtistIdentityRevisionReads(x.suite.owners[2])
                .operativeIdentityRecord(b.artistId);
        }
        record = IStreamArtistIdentityOwner(x.suite.owners[2])
            .consumeAttestation(T.ActionContext(24, actor, before_[2]), b, p, effective, proof);
        bytes32 actual = IStreamArtistCurrentAttributionOwner(x.suite.owners[4])
            .recordAttestationWithAuthority(
                T.ActionContext(24, actor, before_[4]),
                b,
                p,
                operative,
                authority,
                proof.signer,
                effective.nonce,
                effective.time,
                statement
            );
        if (actual != record) revert T.InvalidRecord();
        bytes memory payload = submitted.time == effective.time
            ? abi.encode(b, p, submitted, statement, proof)
            : abi.encode(b, p, submitted, statement, proof, effective);
        if (p.subjectKind == 10) payload = abi.encode(payload, operative);
        payload = abi.encode(payload, authority);
        _archive(x, 24, actor, record, before_, payload);
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
