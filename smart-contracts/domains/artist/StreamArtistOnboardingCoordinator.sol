// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./StreamArtistOnboardingReads.sol";
import "../../interfaces/stream/artist/IStreamArtistCollaboratorOwner.sol";
import "./StreamArtistRegistryValidatorBase.sol";
import "../../interfaces/stream/artist/IStreamArtistOnboardingCoordinator.sol";
import "../../interfaces/stream/artist/IStreamArtistArchiveV2.sol";
import "../../interfaces/stream/artist/IStreamArtistMintConsent.sol";
import "../../interfaces/stream/artist/IStreamArtistIngressBinding.sol";
import "../../interfaces/stream/governance/IStreamRoleRegistry.sol";
import "../../interfaces/stream/parameters/IStreamGasParameterHost.sol";
import "../../interfaces/stream/core/IStreamCoreCollectionView.sol";
import {
    StreamArtistOnboardingTypes as T
} from "../../interfaces/stream/artist/StreamArtistOnboardingTypes.sol";

/// @notice Immutable typed orchestration of seven real artist-authority recipes.
/// @dev No generic route, semantic record or nonce lives here. Only the operation lock mutates.
contract StreamArtistOnboardingCoordinator is IStreamArtistOnboardingCoordinator {
    T.SuiteConfiguration private _suite;
    address[16] private _targets;
    bytes32[16] private _runtimeHashes;
    uint256 private _entered;
    uint256 public immutable deploymentChainId;
    bytes32 public immutable configurationHash;
    StreamArtistOnboardingReads public immutable reads;

    constructor(T.SuiteConfiguration memory suite) {
        deploymentChainId = block.chainid;
        if (suite.registry == address(0) || suite.primaryRevenueClass == bytes32(0)) {
            revert T.InvalidBinding();
        }
        _suite = suite;
        for (uint256 i; i < 7; ++i) {
            _targets[i] = suite.owners[i];
        }
        _targets[7] = suite.registry;
        _targets[8] = suite.archive;
        _targets[9] = suite.core;
        _targets[10] = suite.mintManager;
        _targets[11] = suite.roleRegistry;
        _targets[12] = suite.metadata;
        _targets[13] = suite.primaryResolver;
        _targets[14] = suite.royaltyResolver;
        _targets[15] = suite.validator;
        for (uint256 i; i < 16; ++i) {
            address target = _targets[i];
            if (target.code.length == 0 || target == address(this)) revert T.InvalidBinding();
            for (uint256 j; j < i; ++j) {
                if (_targets[j] == target) revert T.InvalidBinding();
            }
            _runtimeHashes[i] = target.codehash;
        }
        if (
            IStreamArtistMintConsent(suite.registry).core() != suite.core
                || IStreamArtistMintConsent(suite.registry).mintManager() != suite.mintManager
                || IStreamArtistIngressBinding(suite.registry).operationCoordinator()
                    != address(this)
                || IStreamArtistArchiveV2(suite.archive).artistRegistry() != suite.registry
                || IStreamArtistArchiveV2(suite.archive).operationCoordinator() != address(this)
        ) revert T.InvalidBinding();
        bytes32[7] memory domains = [
            keccak256("domain:binding_lifecycle"),
            keccak256("domain:collaborator_lifecycle"),
            keccak256("domain:identity_authority"),
            keccak256("domain:acceptance_lifecycle"),
            keccak256("domain:attribution_lifecycle"),
            keccak256("domain:payout_lifecycle"),
            keccak256("domain:consent_finality")
        ];
        for (uint256 i; i < 7; ++i) {
            IStreamArtistOwner owner = IStreamArtistOwner(suite.owners[i]);
            if (
                owner.artistRegistry() != suite.registry
                    || owner.operationCoordinator() != address(this)
                    || owner.archiveV2() != suite.archive || owner.core() != suite.core
                    || owner.mintManager() != suite.mintManager
                    || owner.deploymentChainId() != block.chainid || owner.domainId() != domains[i]
            ) revert T.InvalidBinding();
        }
        if (
            IStreamArtistCollaboratorOwner(suite.owners[1]).collaboratorSetHash()
                != StreamArtistHashes.emptyCollaborators()
        ) revert T.InvalidBinding();
        configurationHash = keccak256(
            abi.encode(
                keccak256("6529STREAM_ARTIST_ONBOARDING_CONFIGURATION_V1"),
                block.chainid,
                address(this),
                suite,
                _runtimeHashes,
                uint16(1),
                uint16(2),
                uint16(14),
                uint16(15),
                uint16(18),
                uint16(24),
                uint16(52)
            )
        );
        reads = new StreamArtistOnboardingReads(suite);
    }

    modifier operation() {
        if (msg.sender != _suite.registry) revert T.Unauthorized(msg.sender);
        if (_entered != 0) revert T.ReentrantOperation();
        if (block.chainid != deploymentChainId) revert T.InvalidBinding();
        for (uint256 i; i < 16; ++i) {
            if (_targets[i].codehash != _runtimeHashes[i]) revert T.ComponentChanged(_targets[i]);
        }
        _entered = 1;
        _;
        _entered = 0;
    }

    function suiteConfiguration() external view returns (T.SuiteConfiguration memory) {
        return _suite;
    }

    function coordinateProposeArtistBinding(
        address actor,
        uint256 collectionId,
        T.BindingProposal calldata p,
        bytes calldata document,
        string calldata displayName
    ) external operation returns (bytes32 artistId, bytes32 bindingHash) {
        bytes32 role = keccak256("ROLE_ARTIST_REGISTRY_ADMIN");
        if (!IStreamRoleRegistry(_suite.roleRegistry).hasRole(role, actor)) {
            revert T.Unauthorized(actor);
        }
        (bytes32 roleHash, uint64 roleRevision) =
            IStreamRoleRegistry(_suite.roleRegistry).roleMutationState(role);
        T.Snapshot[7] memory before_ = _snapshots(1);
        _collection(collectionId);
        IStreamArtistIdentityOwner identity = IStreamArtistIdentityOwner(_suite.owners[2]);
        artistId = p.artistId;
        bool reused = artistId != bytes32(0);
        if (reused) {
            T.Identity memory current = identity.identity(artistId);
            if (
                current.status != 1 || current.authorityClass != 1
                    || current.authorityAddress != p.artistAddress
                    || current.identityRecordHash != p.identityRecordHash
                    || identity.activeIdentity(p.artistAddress) != artistId
                    || keccak256(document) != p.identityRecordHash
                    || keccak256(bytes(displayName)) != keccak256(bytes(current.displayName))
                    || keccak256(bytes(p.identityRecordURI))
                        != keccak256(bytes(current.identityRecordURI))
            ) revert T.InvalidIdentity(artistId);
        } else {
            artistId = identity.registerIdentity(
                _context(1, actor, before_[2]),
                p.artistAddress,
                p.identityRecordHash,
                p.identityRecordURI,
                document,
                displayName
            );
        }
        T.Binding memory b = IStreamArtistBindingOwner(_suite.owners[0])
            .propose(_context(1, actor, before_[0]), collectionId, artistId, p);
        bindingHash = b.bindingHash;
        IStreamArtistAttributionOwner(_suite.owners[4])
            .claim(_context(1, actor, before_[4]), collectionId, b, p.reasonHash, p.reasonURI);
        _archive(
            1,
            actor,
            bindingHash,
            before_,
            abi.encode(collectionId, p, document, displayName, reused, roleHash, roleRevision)
        );
    }

    function coordinateAcceptArtistBinding(
        address actor,
        uint256 collectionId,
        T.Authorization calldata a
    ) external operation returns (bytes32 record) {
        T.Snapshot[7] memory before_ = _snapshots(2);
        T.Binding memory b = IStreamArtistBindingOwner(_suite.owners[0]).binding(collectionId);
        _collection(collectionId);
        if (b.accepted || b.bindingHash == bytes32(0)) revert T.InvalidAttribution(collectionId);
        T.SignerApproval memory proof = _verify(
            actor,
            b.artistAddress,
            StreamArtistHashes.acceptanceDigest(_environment(), collectionId, b, a),
            a.signature
        );
        record = IStreamArtistIdentityOwner(_suite.owners[2])
            .consumeAcceptance(_context(2, actor, before_[2]), collectionId, b, a, proof);
        bytes32 actual = IStreamArtistAcceptanceOwner(_suite.owners[3])
            .recordAcceptance(
                _context(2, actor, before_[3]), collectionId, b, proof.signer, a.nonce
            );
        if (actual != record) revert T.InvalidRecord();
        IStreamArtistBindingOwner(_suite.owners[0])
            .accept(_context(2, actor, before_[0]), collectionId, b.bindingHash, record);
        IStreamArtistAttributionOwner(_suite.owners[4])
            .accept(_context(2, actor, before_[4]), collectionId, b, record);
        _archive(2, actor, record, before_, abi.encode(collectionId, b, a, proof));
    }

    function coordinateRecordPolicyConsent(
        address actor,
        T.PolicyConsent calldata p,
        T.Authorization calldata a
    ) external operation returns (bytes32 record) {
        T.Snapshot[7] memory before_ = _snapshots(14);
        T.Binding memory b = reads.acceptedBinding(p.collectionId);
        _collection(p.collectionId);
        T.SignerApproval memory proof = _verify(
            actor,
            b.artistAddress,
            StreamArtistHashes.policyDigest(_environment(), p, a),
            a.signature
        );
        record = IStreamArtistIdentityOwner(_suite.owners[2])
            .consumePolicy(_context(14, actor, before_[2]), b, p, a, proof);
        bytes32 actual = IStreamArtistConsentOwner(_suite.owners[6])
            .recordPolicy(_context(14, actor, before_[6]), b, p, proof.signer, a.nonce);
        if (actual != record) revert T.InvalidRecord();
        _archive(14, actor, record, before_, abi.encode(b, p, a, proof));
    }

    function coordinateRecordEconomicsConsent(
        address actor,
        T.EconomicsConsent calldata p,
        T.Authorization calldata a
    ) external operation returns (bytes32 record) {
        T.Snapshot[7] memory before_ = _snapshots(15);
        T.Binding memory b = reads.acceptedBinding(p.collectionId);
        _collection(p.collectionId);
        (T.AssignmentFact memory primary, T.AssignmentFact memory royalty) =
            reads.currentAssignments(p.collectionId);
        T.AssignmentFact memory expected = p.resolver == primary.resolver ? primary : royalty;
        if (
            p.resolver != expected.resolver || p.revenueClass != expected.revenueClass
                || p.scope != expected.scope || p.scopeId != expected.scopeId
                || p.assignmentHash != expected.assignmentHash
        ) revert T.InvalidRecord();
        T.Payout memory payout;
        (payout.account, payout.recordHash) =
            IStreamArtistPayoutOwner(_suite.owners[5]).artistPayoutAccount(b.artistId);
        if (payout.account == address(0) || payout.recordHash == bytes32(0)) {
            revert T.MissingMintPrerequisite(keccak256("payout"));
        }
        reads.requireStaticArtistPayout(p.collectionId, p.resolver, payout.account);
        T.SignerApproval memory proof = _verify(
            actor,
            b.artistAddress,
            StreamArtistHashes.economicsDigest(_environment(), p, a),
            a.signature
        );
        record = IStreamArtistIdentityOwner(_suite.owners[2])
            .consumeEconomics(_context(15, actor, before_[2]), b, p, payout.recordHash, a, proof);
        bytes32 actual = IStreamArtistConsentOwner(_suite.owners[6])
            .recordEconomics(_context(15, actor, before_[6]), b, p, payout, proof.signer, a.nonce);
        if (actual != record) revert T.InvalidRecord();
        _archive(15, actor, record, before_, abi.encode(b, p, payout, a, proof));
    }

    function coordinateRecordPayoutDesignation(
        address actor,
        T.PayoutDesignation calldata p,
        T.Authorization calldata a
    ) external operation returns (bytes32 record) {
        T.Snapshot[7] memory before_ = _snapshots(18);
        T.Identity memory artist = IStreamArtistIdentityOwner(_suite.owners[2]).identity(p.artistId);
        T.SignerApproval memory proof = _verify(
            actor,
            artist.authorityAddress,
            StreamArtistHashes.payoutDigest(_environment(), p, a),
            a.signature
        );
        record = IStreamArtistIdentityOwner(_suite.owners[2])
            .consumePayout(_context(18, actor, before_[2]), p, a, proof);
        bytes32 actual = IStreamArtistPayoutOwner(_suite.owners[5])
            .recordDesignation(_context(18, actor, before_[5]), p, proof.signer, a.nonce, a.time);
        if (actual != record) revert T.InvalidRecord();
        _archive(18, actor, record, before_, abi.encode(p, a, proof));
    }

    function coordinateRecordArtistAttestation(
        address actor,
        T.Attestation calldata p,
        T.Authorization calldata a,
        bytes calldata statement
    ) external operation returns (bytes32 record) {
        T.Snapshot[7] memory before_ = _snapshots(24);
        T.Binding memory b = reads.acceptedBinding(p.collectionId);
        _collection(p.collectionId);
        T.SignerApproval memory proof = _verify(
            actor,
            b.artistAddress,
            StreamArtistHashes.attestationDigest(_environment(), p, a),
            a.signature
        );
        record = IStreamArtistIdentityOwner(_suite.owners[2])
            .consumeAttestation(_context(24, actor, before_[2]), b, p, a, proof);
        bytes32 actual = IStreamArtistAttributionOwner(_suite.owners[4])
            .recordAttestation(
                _context(24, actor, before_[4]), b, p, proof.signer, a.nonce, a.time, statement
            );
        if (actual != record) revert T.InvalidRecord();
        _archive(24, actor, record, before_, abi.encode(b, p, a, statement, proof));
    }

    function coordinateRecordContentRatification(
        address actor,
        T.Ratification calldata p,
        T.Authorization calldata a
    ) external operation returns (bytes32 record) {
        T.Snapshot[7] memory before_ = _snapshots(52);
        T.Binding memory b = reads.acceptedBinding(p.collectionId);
        _collection(p.collectionId);
        (address metadata, bytes32 state) = reads.currentContent(p.collectionId);
        if (p.metadataContract != metadata || p.contentStateHash != state) {
            revert T.InvalidRecord();
        }
        T.SignerApproval memory proof = _verify(
            actor,
            b.artistAddress,
            StreamArtistHashes.ratificationDigest(_environment(), p, a),
            a.signature
        );
        record = IStreamArtistIdentityOwner(_suite.owners[2])
            .consumeRatification(_context(52, actor, before_[2]), b, p, a, proof);
        bytes32 actual = IStreamArtistConsentOwner(_suite.owners[6])
            .recordRatification(_context(52, actor, before_[6]), b, p, proof.signer, a.nonce);
        if (actual != record) revert T.InvalidRecord();
        _archive(52, actor, record, before_, abi.encode(b, p, a, proof));
    }

    function _verify(address actor, address signer, bytes32 digest, bytes calldata signature)
        private
        view
        returns (T.SignerApproval memory proof)
    {
        if (actor == address(0) || signer == address(0)) revert T.InvalidSignature();
        bool direct = actor == signer && signature.length == 0;
        if (!direct) {
            (uint256 cap,, uint8 failureClass, uint64 revision) = IStreamGasParameterHost(
                    _suite.registry
                ).gasParameterInfo(keccak256("6529STREAM_GGP_ARTIST_ERC1271_VERIFY_GAS"));
            if (
                revision == 0 || failureClass != 2
                    || !StreamArtistRegistryValidatorBase(_suite.validator)
                        .validateSignerProof(signer, digest, signature, cap)
            ) revert T.InvalidSignature();
        }
        return T.SignerApproval(signer, digest, direct);
    }

    function _collection(uint256 collectionId) private view {
        if (!IStreamCoreCollectionView(_suite.core).collectionExists(collectionId)) {
            revert T.InvalidAttribution(collectionId);
        }
    }

    function _environment() private view returns (StreamArtistHashes.Environment memory) {
        return StreamArtistHashes.Environment(
            deploymentChainId, _suite.registry, _suite.core, _suite.mintManager
        );
    }

    function _context(uint16 operationId, address actor, T.Snapshot memory prior)
        private
        pure
        returns (T.ActionContext memory)
    {
        return T.ActionContext(operationId, actor, prior);
    }

    function _snapshots(uint16 op) private view returns (T.Snapshot[7] memory result) {
        uint256 mask = op == 1
            ? 0x15
            : op == 2 ? 0x1f : op == 15 ? 0x67 : op == 18 ? 0x24 : op == 24 ? 0x17 : 0x47;
        for (uint256 i; i < 7; ++i) {
            if ((mask & (1 << i)) != 0) {
                result[i] = IStreamArtistOwner(_suite.owners[i]).ownerStateSnapshotV2();
            }
        }
    }

    function _archive(
        uint16 op,
        address actor,
        bytes32 record,
        T.Snapshot[7] memory prior,
        bytes memory payload
    ) private {
        T.Snapshot[7] memory after_ = _snapshots(op);
        bytes32 id = keccak256(
            abi.encode(
                keccak256("6529STREAM_ARTIST_ONBOARDING_OPERATION_EVIDENCE_V1"),
                deploymentChainId,
                _suite.registry,
                address(this),
                op,
                actor,
                record
            )
        );
        bytes memory evidence =
            abi.encode(uint16(1), configurationHash, op, actor, record, prior, after_, payload);
        (bytes32 hash,, bool appended) =
            IStreamArtistArchiveV2(_suite.archive).appendArtistEvidenceV2(id, 1, evidence);
        if (!appended || hash != keccak256(evidence)) revert T.InvalidRecord();
    }
}
