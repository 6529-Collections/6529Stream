// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./StreamArtistEconomicsHashes.sol";
import "./StreamArtistEconomicOperations.sol";
import "./StreamArtistBindingOperations.sol";
import "./StreamArtistCollaboratorOperations.sol";
import "./StreamArtistAuthorizationState.sol";
import "./StreamArtistContentOperations.sol";
import "../../interfaces/stream/artist/IStreamArtistCollaboratorCoordinator.sol";
import "../../interfaces/stream/artist/IStreamArtistBindingLifecycleCoordinator.sol";
import "../../interfaces/stream/artist/IStreamArtistDelegationCoordinator.sol";

import "./StreamArtistOnboardingReads.sol";
import "../../interfaces/stream/artist/IStreamArtistCollaboratorOwner.sol";
import "./StreamArtistRegistryValidatorBase.sol";
import "../../interfaces/stream/artist/IStreamArtistOnboardingCoordinator.sol";
import "../../interfaces/stream/artist/IStreamArtistEconomicsCoordinator.sol";
import "../../interfaces/stream/artist/IStreamArtistArchiveV2.sol";
import "../../interfaces/stream/artist/IStreamArtistMintConsent.sol";
import "../../interfaces/stream/artist/IStreamArtistIngressBinding.sol";
import "../../interfaces/stream/governance/IStreamRoleRegistry.sol";
import "../../interfaces/stream/parameters/IStreamGasParameterHost.sol";
import "../../interfaces/stream/core/IStreamCoreCollectionView.sol";
import {
    StreamArtistOnboardingTypes as T
} from "../../interfaces/stream/artist/StreamArtistOnboardingTypes.sol";

/// @notice Immutable typed orchestration of the supported artist-authority recipes.
/// @dev No generic route, semantic record or nonce lives here. Only the operation lock mutates.
contract StreamArtistOnboardingCoordinator is
    IStreamArtistOnboardingCoordinator,
    IStreamArtistEconomicsCoordinator,
    IStreamArtistDelegationCoordinator,
    IStreamArtistBindingLifecycleCoordinator,
    IStreamArtistCollaboratorCoordinator
{
    /// @notice A required artist fact is absent; retained for errors propagated by linked recipes.
    error MissingMintPrerequisite(bytes32 prerequisite);
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
                uint16(3),
                uint16(4),
                uint16(5),
                uint16(6),
                uint16(7),
                uint16(14),
                uint16(15),
                uint16(17),
                uint16(18),
                uint16(20),
                uint16(21),
                uint16(24),
                uint16(26),
                uint16(27),
                uint16(52),
                uint16(54)
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
        return StreamArtistBindingOperations.accept(
            _economicContext(), actor, collectionId, a, 0, bytes32(0), false
        );
    }

    function coordinateAcceptArtistBindingExpected(
        address actor,
        uint256 collectionId,
        uint64 generation,
        bytes32 bindingHash,
        T.Authorization calldata a
    ) external operation returns (bytes32) {
        return StreamArtistBindingOperations.accept(
            _economicContext(), actor, collectionId, a, generation, bindingHash, true
        );
    }

    function coordinateRefuseArtistBinding(
        address actor,
        L.Termination calldata p,
        T.Authorization calldata a
    ) external operation returns (bytes32) {
        return StreamArtistBindingOperations.refuse(_economicContext(), actor, p, a);
    }

    function coordinateWithdrawArtistBinding(address actor, L.Termination calldata p)
        external
        operation
    {
        StreamArtistBindingOperations.withdraw(_economicContext(), actor, p);
    }

    function coordinateProposeCollaboratorIdentity(address actor, C.IdentityProposal calldata p)
        external
        operation
        returns (bytes32)
    {
        return StreamArtistCollaboratorOperations.proposeIdentity(_economicContext(), actor, p);
    }

    function coordinateAcceptCollaboratorIdentity(
        address actor,
        address account,
        bytes32 identityRecordHash,
        T.Authorization calldata a,
        bytes calldata document,
        string calldata displayName
    ) external operation returns (bytes32) {
        return StreamArtistCollaboratorOperations.acceptIdentity(
            _economicContext(), actor, account, identityRecordHash, a, document, displayName
        );
    }

    function coordinateAcceptCollaborator(
        address actor,
        C.BindingAcceptance calldata p,
        T.Authorization calldata a
    ) external operation returns (bytes32) {
        return StreamArtistCollaboratorOperations.acceptRow(_economicContext(), actor, p, a);
    }

    function coordinateRevokeArtistAuthorization(
        address actor,
        StreamArtistAuthorizationTypes.Revocation calldata p,
        T.Authorization calldata a
    ) external operation returns (bytes32 record) {
        return StreamArtistEconomicOperations.revokeAuthorization(_economicContext(), actor, p, a);
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
    ) external operation returns (bytes32) {
        return StreamArtistEconomicOperations.economicsCurrent(
            _economicContext(), actor, p, bytes32(0), a
        );
    }

    function coordinateRecordProspectiveEconomicsConsent(
        address actor,
        T.EconomicsConsent calldata p,
        T.FixedEconomicsCandidate calldata candidate,
        T.Authorization calldata a
    ) external operation returns (bytes32) {
        return StreamArtistEconomicOperations.economicsProspective(
            _economicContext(), actor, p, candidate, bytes32(0), a
        );
    }

    function coordinateAuthorizeArtistRoyaltyFreeze(
        address actor,
        T.RoyaltyFreeze calldata p,
        T.Authorization calldata a
    ) external operation returns (bytes32) {
        return StreamArtistEconomicOperations.freeze(_economicContext(), actor, p, bytes32(0), a);
    }

    function coordinateGrantArtistDelegation(
        address actor,
        D.Grant calldata p,
        T.Authorization calldata a
    ) external operation returns (bytes32) {
        return StreamArtistEconomicOperations.grant(_economicContext(), actor, p, a);
    }

    function coordinateRevokeArtistDelegation(
        address actor,
        D.Revocation calldata p,
        T.Authorization calldata a
    ) external operation returns (bytes32) {
        return StreamArtistEconomicOperations.revoke(_economicContext(), actor, p, a);
    }

    function coordinateRecordDelegatedEconomicsConsent(
        address actor,
        T.EconomicsConsent calldata p,
        bytes32 grant,
        T.Authorization calldata a
    ) external operation returns (bytes32) {
        if (grant == bytes32(0)) revert D.InvalidDelegation(grant);
        return
            StreamArtistEconomicOperations.economicsCurrent(_economicContext(), actor, p, grant, a);
    }

    function coordinateRecordDelegatedProspectiveEconomicsConsent(
        address actor,
        T.EconomicsConsent calldata p,
        T.FixedEconomicsCandidate calldata candidate,
        bytes32 grant,
        T.Authorization calldata a
    ) external operation returns (bytes32) {
        if (grant == bytes32(0)) revert D.InvalidDelegation(grant);
        return StreamArtistEconomicOperations.economicsProspective(
            _economicContext(), actor, p, candidate, grant, a
        );
    }

    function coordinateAuthorizeDelegatedRoyaltyFreeze(
        address actor,
        T.RoyaltyFreeze calldata p,
        bytes32 grant,
        T.Authorization calldata a
    ) external operation returns (bytes32) {
        if (grant == bytes32(0)) revert D.InvalidDelegation(grant);
        return StreamArtistEconomicOperations.freeze(_economicContext(), actor, p, grant, a);
    }

    function _economicContext() private view returns (D.CoordinatorContext memory) {
        return D.CoordinatorContext(_suite, address(reads), configurationHash);
    }

    function coordinateRecordPayoutDesignation(
        address actor,
        T.PayoutDesignation calldata p,
        T.Authorization calldata a
    ) external operation returns (bytes32 record) {
        T.Snapshot[7] memory before_ = _snapshots(18);
        T.Identity memory artist = IStreamArtistIdentityOwner(_suite.owners[2]).identity(p.artistId);
        T.Authorization memory effective = _directObservedTime(actor, artist.authorityAddress, a);
        T.SignerApproval memory proof = _verify(
            actor,
            artist.authorityAddress,
            StreamArtistHashes.payoutDigest(_environment(), p, effective),
            effective.signature
        );
        record = IStreamArtistIdentityOwner(_suite.owners[2])
            .consumePayout(_context(18, actor, before_[2]), p, effective, proof);
        bytes32 actual = IStreamArtistPayoutOwner(_suite.owners[5])
            .recordDesignation(
                _context(18, actor, before_[5]), p, proof.signer, effective.nonce, effective.time
            );
        if (actual != record) revert T.InvalidRecord();
        _archive(
            18,
            actor,
            record,
            before_,
            a.time == effective.time ? abi.encode(p, a, proof) : abi.encode(p, a, proof, effective)
        );
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
        T.Authorization memory effective = _directObservedTime(actor, b.artistAddress, a);
        T.SignerApproval memory proof = _verify(
            actor,
            b.artistAddress,
            StreamArtistHashes.attestationDigest(_environment(), p, effective),
            effective.signature
        );
        record = IStreamArtistIdentityOwner(_suite.owners[2])
            .consumeAttestation(_context(24, actor, before_[2]), b, p, effective, proof);
        bytes32 actual = IStreamArtistAttributionOwner(_suite.owners[4])
            .recordAttestation(
                _context(24, actor, before_[4]),
                b,
                p,
                proof.signer,
                effective.nonce,
                effective.time,
                statement
            );
        if (actual != record) revert T.InvalidRecord();
        _archive(
            24,
            actor,
            record,
            before_,
            a.time == effective.time
                ? abi.encode(b, p, a, statement, proof)
                : abi.encode(b, p, a, statement, proof, effective)
        );
    }

    function coordinateRecordContentConsent(
        address actor,
        Content.Consent calldata p,
        T.Authorization calldata a
    ) external operation returns (bytes32) {
        return StreamArtistContentOperations.consent(_economicContext(), actor, p, a);
    }

    function coordinateAuthorizeArtistContentFreeze(
        address actor,
        Content.Freeze calldata p,
        T.Authorization calldata a
    ) external operation returns (bytes32) {
        return StreamArtistContentOperations.freeze(_economicContext(), actor, p, a);
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

    function _directObservedTime(address actor, address signer, T.Authorization calldata submitted)
        private
        view
        returns (T.Authorization memory effective)
    {
        effective = submitted;
        if (
            actor == signer && actor != address(0) && submitted.signature.length == 0
                && submitted.time == 0
        ) {
            if (block.timestamp > type(uint64).max) revert T.InvalidRecord();
            effective.time = uint64(block.timestamp);
        }
    }

    function _verify(address actor, address signer, bytes32 digest, bytes memory signature)
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
        // acceptedBinding also consumes Attribution's state/generation. Commit
        // that read for every recipe using it, without adding an owner mutation.
        uint256 mask = op == 1
            ? 0x15
            : op == 2 ? 0x1f : op == 15 ? 0x77 : op == 18 ? 0x24 : op == 24 ? 0x17 : 0x57;
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
