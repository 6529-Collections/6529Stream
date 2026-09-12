// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./StreamArtistContentHashes.sol";
import "./StreamArtistCurrentAuthorityFacts.sol";
import "../../interfaces/stream/artist/IStreamArtistCurrentConsentOwner.sol";
import "./StreamArtistRegistryValidatorBase.sol";
import "../../interfaces/stream/artist/IStreamArtistContentOwner.sol";
import "../../interfaces/stream/artist/IStreamArtistContentMutationFacts.sol";
import "../../interfaces/stream/artist/IStreamArtistBindingOwner.sol";
import "../../interfaces/stream/artist/IStreamArtistIdentityOwner.sol";
import "../../interfaces/stream/artist/IStreamArtistAttributionOwner.sol";
import "../../interfaces/stream/artist/IStreamArtistCollaboratorBindingOwner.sol";
import "../../interfaces/stream/artist/IStreamArtistCollaboratorRecordsOwner.sol";
import "../../interfaces/stream/artist/IStreamArtistArchiveV2.sol";
import "../../interfaces/stream/artist/StreamArtistDelegationTypes.sol";
import "../../interfaces/stream/core/IStreamCorePointers.sol";
import "../../interfaces/stream/core/IStreamCoreCollectionView.sol";
import "../../interfaces/stream/parameters/IStreamGasParameterHost.sol";

/// @notice Stateless content recipes and read composition over the immutable artist owners and host.
/// @dev No readiness state. Executed-finality provider admission remains an explicit integration seam.
library StreamArtistContentOperations {
    function consent(
        StreamArtistDelegationTypes.CoordinatorContext memory x,
        address actor,
        Content.Consent memory p,
        T.Authorization memory a
    ) public returns (bytes32 record) {
        T.Snapshot[7] memory before_ = _snapshots(x.suite);
        T.Binding memory b = _binding(x.suite, p.collectionId, false);
        R.AuthorityFact memory authority =
            StreamArtistCurrentAuthorityFacts.read(x.suite.owners[2], b.artistId, false);
        StreamArtistContentHashes.validateConsent(p);
        _host(x.suite, p.metadataContract);
        (bool supported, bytes32 current) = IStreamArtistContentMutationFacts(p.metadataContract)
            .artistContentFamilyState(p.collectionId, p.familyId);
        if (!supported || current == bytes32(0) || current == p.newStateHash) {
            revert T.InvalidRecord();
        }
        T.SignerApproval memory proof = _verify(
            x.suite,
            actor,
            authority.authorityAddress,
            StreamArtistContentHashes.consentDigest(_environment(x.suite), p, a),
            a.signature
        );
        record = IStreamArtistContentIdentityOwner(x.suite.owners[2])
            .consumeContentConsent(T.ActionContext(17, actor, before_[2]), b, p, a, proof);
        bytes32 actual = IStreamArtistCurrentConsentOwner(x.suite.owners[6])
            .recordContentConsentWithAuthority(
                T.ActionContext(17, actor, before_[6]), b, p, proof.signer, a.nonce, authority
            );
        if (actual != record) revert T.InvalidRecord();
        _archive(x, 17, actor, record, before_, abi.encode(b, p, a, proof, current));
    }

    function freeze(
        StreamArtistDelegationTypes.CoordinatorContext memory x,
        address actor,
        Content.Freeze memory p,
        T.Authorization memory a
    ) public returns (bytes32 record) {
        T.Snapshot[7] memory before_ = _snapshots(x.suite);
        T.Binding memory b = _binding(x.suite, p.collectionId, true);
        R.AuthorityFact memory authority =
            StreamArtistCurrentAuthorityFacts.read(x.suite.owners[2], b.artistId, true);
        StreamArtistContentHashes.validateFreeze(p);
        _host(x.suite, p.metadataContract);
        IStreamArtistContentMutationFacts host =
            IStreamArtistContentMutationFacts(p.metadataContract);
        if (host.artistContentFreezeState(p.collectionId) != p.expectedStateHash) {
            revert T.InvalidRecord();
        }
        for (uint256 i; i < p.lockClasses.length; ++i) {
            (bool supported, bool locked) =
                host.artistContentLockState(p.collectionId, p.lockClasses[i]);
            if (!supported || locked) revert T.InvalidRecord();
        }
        T.SignerApproval memory proof = _verify(
            x.suite,
            actor,
            authority.authorityAddress,
            StreamArtistContentHashes.freezeDigest(_environment(x.suite), p, a),
            a.signature
        );
        record = IStreamArtistContentIdentityOwner(x.suite.owners[2])
            .consumeContentFreeze(T.ActionContext(21, actor, before_[2]), b, p, a, proof);
        bytes32 actual = IStreamArtistCurrentConsentOwner(x.suite.owners[6])
            .authorizeContentFreezeWithAuthority(
                T.ActionContext(21, actor, before_[6]), b, p, proof.signer, a.nonce, authority
            );
        if (actual != record) revert T.InvalidRecord();
        _archive(x, 21, actor, record, before_, abi.encode(b, p, a, proof));
    }

    function consentEvidence(
        T.SuiteConfiguration memory suite,
        uint256 collectionId,
        bytes32 familyId,
        bytes32 newStateHash
    ) public view returns (bytes32) {
        T.Binding memory b = _binding(suite, collectionId, false);
        _host(suite, suite.metadata);
        Content.Consent memory p =
            Content.Consent(collectionId, suite.metadata, familyId, newStateHash);
        StreamArtistContentHashes.validateConsent(p);
        (bool supported,) = IStreamArtistContentMutationFacts(suite.metadata)
            .artistContentFamilyState(collectionId, familyId);
        if (!supported) revert T.UnsupportedProfile();
        IStreamArtistContentRecordsOwner.ConsentRecord memory record =
            IStreamArtistContentRecordsOwner(suite.owners[6]).contentConsentAt(p, b.generation);
        if (
            record.recordHash == bytes32(0) || record.artistId != b.artistId
                || record.bindingGeneration != b.generation || record.authorityClass != 1
                || keccak256(abi.encode(record.terms)) != keccak256(abi.encode(p))
        ) {
            revert T.MissingMintPrerequisite(keccak256("content-consent"));
        }
        return record.recordHash;
    }

    function freezeAuthorized(
        T.SuiteConfiguration memory suite,
        uint256 collectionId,
        bytes32 lockClass
    ) public view returns (bool, bytes32) {
        T.Binding memory b = _binding(suite, collectionId, true);
        _host(suite, suite.metadata);
        IStreamArtistContentMutationFacts host = IStreamArtistContentMutationFacts(suite.metadata);
        (bool supported, bool locked) = host.artistContentLockState(collectionId, lockClass);
        if (!supported || locked || lockClass == bytes32(0)) return (false, bytes32(0));
        Content.FreezeRecord memory record = IStreamArtistContentRecordsOwner(suite.owners[6])
            .contentFreezeAt(collectionId, b.generation, suite.metadata, lockClass);
        bool valid = record.recordHash != bytes32(0) && record.artistId == b.artistId
            && record.bindingGeneration == b.generation && record.metadataContract == suite.metadata
            && record.authorityClass == 1
            && record.expectedStateHash == host.artistContentFreezeState(collectionId);
        return (valid, valid ? record.recordHash : bytes32(0));
    }

    function _binding(T.SuiteConfiguration memory suite, uint256 collectionId, bool defensive)
        private
        view
        returns (T.Binding memory b)
    {
        if (block.chainid != IStreamArtistOwner(suite.owners[2]).deploymentChainId()) {
            revert T.InvalidBinding();
        }
        _selected(suite.core, keccak256("ARTIST_REGISTRY"), suite.registry);
        if (!IStreamCoreCollectionView(suite.core).collectionExists(collectionId)) {
            revert T.InvalidAttribution(collectionId);
        }
        b = IStreamArtistBindingOwner(suite.owners[0]).binding(collectionId);
        (uint8 state, uint64 generation) =
            IStreamArtistAttributionOwner(suite.owners[4]).attributionState(collectionId);
        (address authority, uint8 class_, uint8 status,) =
            IStreamArtistIdentityOwner(suite.owners[2]).authorityState(b.artistId);
        if (
            !b.accepted || (state != 2 && !(defensive && state == 4)) || generation != b.generation
                || b.consentMode != 1 || (status != 1 && !(defensive && status == 4)) || class_ != 1
                || authority == address(0)
        ) revert T.InvalidAttribution(collectionId);
        C.BindingTerms memory terms = IStreamArtistCollaboratorBindingOwner(suite.owners[0])
            .bindingTerms(collectionId, generation);
        if (terms.mode != 0 || terms.threshold != 0 || terms.count > 32) {
            revert T.UnsupportedProfile();
        }
        if (
            IStreamArtistCollaboratorRecordsOwner(suite.owners[1]).acceptedCount(b.bindingHash)
                != terms.count
        ) {
            revert T.InvalidAttribution(collectionId);
        }
    }

    function _host(T.SuiteConfiguration memory suite, address supplied) private view {
        if (supplied != suite.metadata) revert T.ComponentChanged(supplied);
        _selected(suite.core, keccak256("METADATA_ROUTER"), suite.metadata);
    }

    function _selected(address core, bytes32 kind, address expected) private view {
        (address target, bytes32 hash,,,,,,,,) = IStreamCorePointers(core).getSatellitePointer(kind);
        if (target != expected || target.code.length == 0 || hash != target.codehash) {
            revert T.ComponentChanged(target);
        }
    }

    function _verify(
        T.SuiteConfiguration memory suite,
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
                    suite.registry
                ).gasParameterInfo(keccak256("6529STREAM_GGP_ARTIST_ERC1271_VERIFY_GAS"));
            if (
                revision == 0 || failureClass != 2
                    || !StreamArtistRegistryValidatorBase(suite.validator)
                        .validateSignerProof(signer, digest, signature, cap)
            ) revert T.InvalidSignature();
        }
        return T.SignerApproval(signer, digest, direct);
    }

    function _environment(T.SuiteConfiguration memory suite)
        private
        view
        returns (StreamArtistHashes.Environment memory)
    {
        return StreamArtistHashes.Environment(
            block.chainid, suite.registry, suite.core, suite.mintManager
        );
    }

    function _snapshots(T.SuiteConfiguration memory suite)
        private
        view
        returns (T.Snapshot[7] memory result)
    {
        for (uint256 i; i < 7; ++i) {
            if ((0x57 & (1 << i)) != 0) {
                result[i] = IStreamArtistOwner(suite.owners[i]).ownerStateSnapshotV2();
            }
        }
    }

    function _archive(
        StreamArtistDelegationTypes.CoordinatorContext memory x,
        uint16 op,
        address actor,
        bytes32 record,
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
