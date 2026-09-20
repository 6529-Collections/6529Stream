// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "./StreamArtistEconomicOperations.sol";
import "./StreamArtistSaleOperations.sol";
import "../../interfaces/stream/artist/IStreamArtistDelegatedConsent.sol";

/// @notice Additive op14/op16 producer. Original signature, nonce, record and Archive domains are retained.
library StreamArtistDelegatedConsentOperations {
    function policy(
        D.CoordinatorContext memory x,
        address actor,
        T.PolicyConsent memory p,
        bytes32 grant,
        T.Authorization memory a
    ) public returns (bytes32 record) {
        if (grant == 0) revert D.InvalidDelegation(grant);
        T.Snapshot[7] memory before_ = _snapshots(x, 14);
        T.Binding memory b = StreamArtistOnboardingReads(x.reads).acceptedBinding(p.collectionId);
        if (b.consentMode != 2) revert T.UnsupportedProfile();
        _collection(x, p.collectionId);
        bytes memory facts = bytes("");
        D.Record memory prior =
            IStreamArtistDelegationOwner(x.suite.owners[2]).delegationRecord(grant);
        T.SignerApproval memory proof = _verify(
            x,
            actor,
            prior.grant.delegate,
            StreamArtistHashes.policyDigest(_environment(x), p, a),
            a.signature
        );
        record = IStreamArtistDelegatedPolicySaleIdentityOwner(x.suite.owners[2])
            .consumeDelegatedPolicyConsent(
                T.ActionContext(14, actor, before_[2]), b, p, grant, a, proof
            );
        bytes32 actual = IStreamArtistDelegatedPolicySaleConsentOwner(x.suite.owners[6])
            .recordDelegatedPolicyConsent(
                T.ActionContext(14, actor, before_[6]), b, p, proof.signer, a.nonce, grant
            );
        if (actual != record) revert T.InvalidRecord();
        _archive(x, 14, actor, record, before_, abi.encode(b, p, a, proof, grant, prior, facts));
    }

    function sale(
        D.CoordinatorContext memory x,
        address actor,
        Sale.Consent memory p,
        bytes32 grant,
        T.Authorization memory a
    ) public returns (bytes32 record) {
        if (grant == 0) revert D.InvalidDelegation(grant);
        T.Snapshot[7] memory before_ = _snapshots(x, 16);
        T.Binding memory b = StreamArtistSaleOperations.delegatedBinding(x.suite, p.collectionId);
        if (b.consentMode != 2) revert T.UnsupportedProfile();
        bytes memory facts = StreamArtistSaleOperations.saleFacts(x.suite, p);
        D.Record memory prior =
            IStreamArtistDelegationOwner(x.suite.owners[2]).delegationRecord(grant);
        T.SignerApproval memory proof = _verify(
            x,
            actor,
            prior.grant.delegate,
            StreamArtistSaleHashes.digest(_environment(x), p, a),
            a.signature
        );
        record = IStreamArtistDelegatedPolicySaleIdentityOwner(x.suite.owners[2])
            .consumeDelegatedSaleConsent(
                T.ActionContext(16, actor, before_[2]), b, p, grant, a, proof
            );
        bytes32 actual = IStreamArtistDelegatedPolicySaleConsentOwner(x.suite.owners[6])
            .recordDelegatedSaleConsent(
                T.ActionContext(16, actor, before_[6]), b, p, proof.signer, a.nonce, grant
            );
        if (actual != record) revert T.InvalidRecord();
        _archive(x, 16, actor, record, before_, abi.encode(b, p, a, proof, grant, prior, facts));
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

    function _collection(D.CoordinatorContext memory x, uint256 collectionId) private view {
        if (!IStreamCoreCollectionView(x.suite.core).collectionExists(collectionId)) {
            revert T.InvalidAttribution(collectionId);
        }
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
        uint256 mask = op == 26 || op == 27 || op == 54 ? 4 : op == 15 ? 0x77 : 0x57;
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
        T.Snapshot[7] memory prior,
        bytes memory payload
    ) private {
        T.Snapshot[7] memory after_ = _snapshots(x, op);
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
        bytes memory evidence =
            abi.encode(uint16(1), x.configurationHash, op, actor, record, prior, after_, payload);
        (bytes32 hash,, bool appended) =
            IStreamArtistArchiveV2(x.suite.archive).appendArtistEvidenceV2(id, 1, evidence);
        if (!appended || hash != keccak256(evidence)) revert T.InvalidRecord();
    }
}
