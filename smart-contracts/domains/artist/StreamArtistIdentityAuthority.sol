// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./StreamArtistContentHashes.sol";

import "./StreamArtistEconomicsHashes.sol";

import "./StreamArtistOwner.sol";
import "./StreamArtistIdentityData.sol";
import "./StreamArtistIdentityWriterExtension.sol";
import "./StreamArtistNonceAvailability.sol";
import "./StreamArtistDelegationState.sol";
import "./StreamArtistIdentityState.sol";
import "./StreamArtistBindingOperations.sol";
import "./StreamArtistCollaboratorIdentityState.sol";
import "./StreamArtistAuthorizationState.sol";
import "./StreamArtistIdentityRevisionState.sol";
import "./StreamArtistIdentityConsentState.sol";
import "./StreamArtistRotationState.sol";
import "./StreamArtistTimingState.sol";
import "../../interfaces/stream/artist/IStreamArtistRotationOwner.sol";
import {
    StreamArtistOnboardingTypes as T
} from "../../interfaces/stream/artist/StreamArtistOnboardingTypes.sol";

/// @notice Sole owner of artist identities, authorization replay, liveness and signature bytes.
/// @dev Current-principal rotation and economics/freeze delegation are supported; recovery remains separate.
contract StreamArtistIdentityAuthority is StreamArtistOwner, StreamArtistIdentityData {
    // Retain the owner ABI for errors propagated by the linked mechanics.
    error NonceAvailabilityAlreadyUsed(uint256 nonce);
    error NonceAvailabilityInconsistent(uint8 level, uint256 prefix);
    error BoundExceeded(uint256 actual, uint256 maximum);
    error AddressAlreadyRegistered(address authority);
    error InvalidSignature();
    error InvalidIdentity(bytes32 artistId);
    error InvalidTimestamp(uint64 timestamp);
    error Replay(bytes32 replayKey);
    using StreamArtistNonceAvailability for StreamArtistNonceAvailability.Index;
    address public immutable artistWindowAuthority;
    address public immutable identityWriterExtension;

    event ArtistIdentityContested(
        uint16 schemaVersion,
        bytes32 indexed artistId,
        address indexed contester,
        bytes32 subjectRecordHash,
        bytes32 evidenceHash,
        bytes32 reasonHash,
        uint64 contestedAt,
        bytes32 contestRecordHash
    );

    function contestIdentity(
        T.ActionContext calldata c,
        Contest.Request calldata p,
        Contest.GovernanceWitness calldata governance
    ) external returns (bytes32) {
        _check(c, 33);
        StreamArtistIdentityState.Mutation memory m = StreamArtistIdentityContestState.file(
            _identityContests,
            _identity,
            _rotations,
            _replay,
            _ownerContext(),
            c,
            p,
            governance,
            artistWindowAuthority
        );
        _commit(c, m.action, m.state, m.replay, m.record);
        return m.record;
    }

    function identityContestRecord(bytes32 record) external view returns (Contest.Record memory) {
        return _identityContests.records[record];
    }

    function latestIdentityContest(bytes32 artistId) external view returns (bytes32) {
        return _identityContests.latest[artistId];
    }

    function identityContestContext(Contest.Request calldata p)
        external
        view
        returns (bytes32, bytes32, bytes32)
    {
        return StreamArtistIdentityContestState.context(
            _identityContests, _identity, _rotations, _ownerContext(), p
        );
    }

    event ArtistIdentityRevisionRecorded(
        uint16 schemaVersion,
        bytes32 indexed artistId,
        address indexed signer,
        bytes32 previousRecordHash,
        bytes32 revisedRecordHash,
        string identityRecordURI,
        uint8 authorityClass,
        uint256 nonce,
        uint64 signedAt,
        bytes32 revisionRecordHash
    );

    function recordIdentityRevision(
        T.ActionContext calldata c,
        StreamArtistIdentityRevisionTypes.Revision calldata p,
        T.Authorization calldata a,
        T.SignerApproval calldata proof,
        bytes calldata document,
        string calldata displayName
    ) external returns (bytes32) {
        _forwardIdentityWriter();
    }

    function operativeIdentityRecord(bytes32 artistId) public view returns (bytes32) {
        return StreamArtistIdentityRevisionState.operative(
            _identityRevisions, _identity, _rotations, artistId
        );
    }

    function identityRecordBytes(bytes32 artistId) external view returns (bytes memory) {
        return _identity.documents[operativeIdentityRecord(artistId)];
    }

    function identityRevisionRecord(bytes32 record)
        external
        view
        returns (StreamArtistIdentityRevisionTypes.Record memory)
    {
        return _identityRevisions.records[record];
    }

    function operativeIdentityMetadata(bytes32 artistId)
        external
        view
        returns (bytes32, string memory, string memory)
    {
        return StreamArtistIdentityRevisionState.metadata(
            _identityRevisions, _identity, _rotations, artistId
        );
    }

    function artistDisplayName(bytes32 artistId)
        external
        view
        returns (string memory name, bytes32 hash)
    {
        (hash,, name) = StreamArtistIdentityRevisionState.metadata(
            _identityRevisions, _identity, _rotations, artistId
        );
    }

    event ArtistAuthorizationRevoked(
        uint16 schemaVersion,
        bytes32 indexed artistId,
        bytes32 revokedDigest,
        uint256 revokedNonce,
        uint256 nonce,
        uint64 revokedAt,
        bytes32 revocationRecordHash
    );

    function revokeAuthorization(
        T.ActionContext calldata c,
        StreamArtistAuthorizationTypes.Revocation calldata p,
        T.Authorization calldata a,
        T.SignerApproval calldata proof
    ) external returns (bytes32) {
        _forwardIdentityWriter();
    }

    function artistAuthorizationState(bytes32 artistId, bytes32 digest, uint256 nonce)
        external
        view
        returns (StreamArtistAuthorizationTypes.State memory)
    {
        return StreamArtistAuthorizationState.authorizationState(
            _identity, _replay, _ownerContext(), artistId, digest, nonce
        );
    }

    event ArtistDelegationGranted(
        uint16 schemaVersion,
        bytes32 indexed artistId,
        address indexed delegate,
        uint256 indexed collectionId,
        uint32 capabilities,
        uint64 notBefore,
        uint64 expiresAt,
        uint64 maxUses,
        bytes32 constraintsHash,
        uint256 nonce,
        bytes32 delegationRecordHash
    );
    event ArtistDelegationRevoked(
        uint16 schemaVersion,
        bytes32 indexed artistId,
        address indexed delegate,
        bytes32 indexed delegationRecordHash,
        bytes32 reasonHash,
        address signer,
        uint8 authorityClass,
        uint256 nonce,
        uint64 signedAt
    );

    event ArtistIdentityRegistered(
        uint16 schemaVersion,
        bytes32 indexed artistId,
        address indexed authorityAddress,
        bytes32 identityRecordHash,
        string identityRecordURI,
        uint256 registrationNonce
    );
    /// @notice Supplementary mirror evidence; the canonical identity document remains authoritative.
    event ArtistIdentityDisplayNameStored(
        bytes32 indexed artistId, bytes32 indexed identityRecordHash, string displayName
    );

    constructor(
        address registry_,
        address coordinator_,
        address archive_,
        address core_,
        address manager_
    )
        StreamArtistOwner(
            registry_,
            coordinator_,
            archive_,
            keccak256("domain:identity_authority"),
            core_,
            manager_
        )
    {
        artistWindowAuthority = StreamArtistTimingState.canonicalAuthority(core_, manager_);
        identityWriterExtension = address(
            new StreamArtistIdentityWriterExtension(
                address(this), registry_, coordinator_, archive_, core_, manager_
            )
        );
    }

    function setGuardians(
        T.ActionContext calldata c,
        R.GuardianSet calldata p,
        T.Authorization calldata a,
        T.SignerApproval calldata proof
    ) external returns (bytes32) {
        _check(c, 28);
        StreamArtistIdentityState.Mutation memory m = StreamArtistRotationState.setGuardians(
            _rotations, _identity, _replay, _ownerContext(), c, p, a, proof
        );
        _commit(c, m.action, m.state, m.replay, m.record);
        return m.record;
    }

    function stageRotation(
        T.ActionContext calldata c,
        R.Rotation calldata p,
        T.Authorization calldata oldAuthorization,
        T.Authorization calldata newAuthorization,
        T.SignerApproval calldata oldProof,
        T.SignerApproval calldata newProof
    ) external returns (bytes32) {
        _check(c, 29);
        StreamArtistIdentityState.Mutation memory m = StreamArtistRotationState.stage(
            _rotations,
            _identity,
            _replay,
            _ownerContext(),
            c,
            p,
            oldAuthorization,
            newAuthorization,
            oldProof,
            newProof
        );
        _commit(c, m.action, m.state, m.replay, m.record);
        return m.record;
    }

    function approveRotation(T.ActionContext calldata c, bytes32 artistId, bytes32 expected)
        external
    {
        _check(c, 30);
        StreamArtistIdentityState.Mutation memory m = StreamArtistRotationState.approve(
            _rotations, _identity, _replay, _ownerContext(), c, artistId, expected
        );
        _commit(c, m.action, m.state, m.replay, m.record);
    }

    function vetoRotation(
        T.ActionContext calldata c,
        bytes32 artistId,
        bytes32 expected,
        bytes32 reasonHash
    ) external {
        _check(c, 31);
        StreamArtistIdentityState.Mutation memory m = StreamArtistRotationState.veto(
            _rotations, _identity, _replay, _ownerContext(), c, artistId, expected, reasonHash
        );
        _commit(c, m.action, m.state, m.replay, m.record);
    }

    function executeRotation(T.ActionContext calldata c, bytes32 artistId, bytes32 expected)
        external
    {
        _check(c, 32);
        StreamArtistIdentityState.Mutation memory m = StreamArtistRotationState.execute(
            _rotations, _identity, _replay, _ownerContext(), c, artistId, expected
        );
        _commit(c, m.action, m.state, m.replay, m.record);
    }

    function revokeStanding(
        T.ActionContext calldata c,
        R.StandingRevocation calldata p,
        T.Authorization calldata a,
        T.SignerApproval calldata proof
    ) external returns (bytes32) {
        _check(c, 51);
        StreamArtistIdentityState.Mutation memory m = StreamArtistRotationState.revokeStanding(
            _rotations, _identity, _replay, _ownerContext(), c, p, a, proof
        );
        _commit(c, m.action, m.state, m.replay, m.record);
        return m.record;
    }

    function guardianSet(bytes32 artistId)
        external
        view
        returns (address[] memory, uint32, uint64, bytes32)
    {
        bytes32 record = StreamArtistRotationState.operativeGuardian(_rotations, artistId);
        R.GuardianSet storage terms = _rotations.guardians[record].terms;
        return (terms.guardians, terms.approvalThreshold, terms.minContestSeconds, record);
    }

    function pendingRotation(bytes32 artistId)
        external
        view
        returns (address, address, uint64, uint32, bytes32)
    {
        bytes32 record = _rotations.pending[artistId];
        R.RotationRecord storage r = _rotations.rotations[record];
        return (
            r.terms.oldAddress,
            r.terms.newAddress,
            r.transition.contestEndsAt,
            r.guardianApprovals,
            record
        );
    }

    function priorAddressStandingRevoked(bytes32 artistId, address account)
        external
        view
        returns (bool, bytes32)
    {
        return StreamArtistRotationState.standingRevoked(_rotations, artistId, account);
    }

    function guardianSetRecord(bytes32 record) external view returns (R.GuardianRecord memory) {
        return _rotations.guardians[record];
    }

    function rotationRecord(bytes32 record) external view returns (R.RotationRecord memory) {
        return _rotations.rotations[record];
    }

    function standingRevocationRecord(bytes32 record)
        external
        view
        returns (R.StandingRecord memory)
    {
        return _rotations.standingRecords[record];
    }

    function artistTransitionState(bytes32 record)
        external
        view
        returns (R.TransitionState memory)
    {
        return _rotations.rotations[record].transition;
    }

    function lastArtistTransition(bytes32 artistId) external view returns (bytes32) {
        return _rotations.latestTransition[artistId];
    }

    function identityRevisionProvisionalAssociation(bytes32 record)
        external
        view
        returns (R.ProvisionalAssociation memory)
    {
        return _identityRevisions.associations[record];
    }

    function activeAuthorityWindow(bytes32 artistId) external view returns (bytes32, uint64, bool) {
        return StreamArtistRotationState.activeWindow(_rotations, artistId);
    }

    function rotationAcceptanceNonceState(bytes32 artistId, address account, uint256 nonce)
        external
        view
        returns (bool, uint256)
    {
        return StreamArtistRotationState.acceptanceNonceState(
            _rotations, _replay, _ownerContext(), artistId, account, nonce
        );
    }

    function provisionalAssociation(bytes32 artistId)
        external
        view
        returns (R.ProvisionalAssociation memory)
    {
        return StreamArtistRotationState.association(_rotations, artistId);
    }

    function provisionalRecordEligible(bytes32 artistId, R.ProvisionalAssociation calldata a)
        external
        view
        returns (bool)
    {
        return StreamArtistRotationState.eligible(_rotations, artistId, a);
    }

    function artistWindowInfo(bytes32 parameter) external view returns (uint64, uint64, uint64) {
        return StreamArtistTimingState.info(_rotations, parameter);
    }

    function artistWindowScope(bytes32 parameter) external view returns (bytes32) {
        StreamArtistTimingState.info(_rotations, parameter);
        return StreamArtistTimingState.scope(parameter);
    }

    function artistWindowStateHash(bytes32 parameter, uint64 value, uint64 revision)
        external
        view
        returns (bytes32)
    {
        (, uint64 floor,) = StreamArtistTimingState.info(_rotations, parameter);
        return StreamArtistTimingState.stateHash(parameter, value, floor, revision);
    }

    function configureArtistWindow(
        address actor,
        bytes32 parameter,
        uint64 newValue,
        uint64 expectedRevision
    ) external {
        if (msg.sender != operationCoordinator) revert T.Unauthorized(msg.sender);
        if (block.chainid != deploymentChainId) revert T.InvalidBinding();
        StreamArtistTimingState.configure(
            _rotations, artistWindowAuthority, actor, parameter, newValue, expectedRevision
        );
    }

    function nextRegistrationNonce() external view returns (uint256) {
        return _identity.nextRegistrationNonce;
    }

    function activeIdentity(address account) external view returns (bytes32) {
        return _identity.activeIdentity[account];
    }

    function _ownerContext() private view returns (StreamArtistIdentityState.OwnerContext memory) {
        return StreamArtistIdentityState.OwnerContext(
            _environment(), operationCoordinator, archiveV2, domainId, _revision
        );
    }

    function identity(bytes32 artistId) external view returns (T.Identity memory) {
        return _identity.identities[artistId];
    }

    /// @notice Fixed-size authority facts with the immutable registration hash, not the operative document.
    function authorityState(bytes32 artistId)
        external
        view
        returns (
            address authorityAddress,
            uint8 authorityClass,
            uint8 status,
            bytes32 identityRecordHash
        )
    {
        T.Identity storage item = _identity.identities[artistId];
        return (item.authorityAddress, item.authorityClass, item.status, item.identityRecordHash);
    }

    function identityDocumentBytes(bytes32 documentHash) external view returns (bytes memory) {
        return _identity.documents[documentHash];
    }

    function signatureBundle(bytes32 recordHash) external view returns (bytes memory) {
        return _identity.signatures[recordHash];
    }

    function nonceUsed(bytes32 artistId, uint256 nonce) public view returns (bool) {
        return _replay[_replayKey(
                keccak256("identity_authority.replay.nonce_allocator"),
                keccak256(abi.encode(artistId, nonce))
            )].status != 0;
    }

    function delegationRecord(bytes32 grant) external view returns (D.Record memory) {
        return _delegations.records[grant];
    }

    function collaboratorRegistrationNonceState(address account, uint256 nonce)
        external
        view
        returns (bool, uint256)
    {
        return StreamArtistCollaboratorIdentityState.nonceState(
            _collaboratorAccounts, _replay, _ownerContext(), account, nonce
        );
    }

    function registerCollaboratorIdentity(
        T.ActionContext calldata c,
        C.IdentityProposal calldata p,
        T.Authorization calldata a,
        T.SignerApproval calldata proof,
        bytes calldata document,
        string calldata displayName
    ) external returns (bytes32) {
        _forwardIdentityWriter();
    }

    function consumeCollaboratorAcceptance(
        T.ActionContext calldata c,
        C.BindingAcceptance calldata p,
        bytes32 artistId,
        T.Authorization calldata a,
        T.SignerApproval calldata proof
    ) external returns (bytes32 record) {
        _forwardIdentityWriter();
    }

    function delegatedNonceState(bytes32 artistId, address delegate, uint256 nonce)
        external
        view
        returns (bool, uint256)
    {
        bytes32 lane = StreamArtistDelegationState.lane(artistId, delegate);
        return (
            _replay[_replayKey(
                        keccak256("identity_authority.replay.delegated_nonce"),
                        keccak256(abi.encode(lane, nonce))
                    )].status != 0,
            _delegations.hints[lane]
        );
    }

    function grantDelegation(
        T.ActionContext calldata c,
        D.Grant calldata p,
        T.Authorization calldata a,
        T.SignerApproval calldata proof
    ) external returns (bytes32 record) {
        _check(c, 26);
        if (a.time != 0) revert T.InvalidRecord();
        StreamArtistIdentityState.Mutation memory m = StreamArtistIdentityState.grantDelegation(
            _identity, _replay, _delegations, _ownerContext(), c, p, a, proof
        );
        _commit(c, m.action, m.state, m.replay, m.record);
        return m.record;
    }

    function revokeDelegation(
        T.ActionContext calldata c,
        D.Revocation calldata p,
        T.Authorization calldata a,
        T.SignerApproval calldata proof
    ) external returns (bytes32 record) {
        _check(c, 27);
        _deadline(a.time);
        StreamArtistIdentityState.Mutation memory m = StreamArtistIdentityState.revokeDelegation(
            _identity, _replay, _delegations, _ownerContext(), c, p, a, proof
        );
        _commit(c, m.action, m.state, m.replay, m.record);
        return m.record;
    }

    function consumeDelegatedEconomics(
        T.ActionContext calldata c,
        T.Binding calldata b,
        T.EconomicsConsent calldata p,
        bytes32 designation,
        bytes32 grant,
        T.Authorization calldata a,
        T.SignerApproval calldata proof
    ) external returns (bytes32 record) {
        _forwardIdentityWriter();
    }

    function consumeDelegatedRoyaltyFreeze(
        T.ActionContext calldata c,
        T.Binding calldata b,
        T.RoyaltyFreeze calldata p,
        bytes32 grant,
        T.Authorization calldata a,
        T.SignerApproval calldata proof
    ) external returns (bytes32 record) {
        _forwardIdentityWriter();
    }

    function registerIdentity(
        T.ActionContext calldata c,
        address artist,
        bytes32 documentHash,
        string calldata uri,
        bytes calldata document,
        string calldata displayName
    ) external returns (bytes32) {
        _check(c, 1);
        StreamArtistIdentityState.Mutation memory m = StreamArtistIdentityState.register(
            _identity, _replay, _ownerContext(), artist, documentHash, uri, document, displayName
        );
        _commit(c, m.action, m.state, m.replay, m.record);
        return m.record;
    }

    function consumeAcceptance(
        T.ActionContext calldata c,
        uint256 collectionId,
        T.Binding calldata b,
        T.Authorization calldata a,
        T.SignerApproval calldata proof
    ) external returns (bytes32 record) {
        _forwardIdentityWriter();
    }

    function consumeRefusal(
        T.ActionContext calldata c,
        T.Binding calldata b,
        L.Termination calldata p,
        T.Authorization calldata a,
        T.SignerApproval calldata proof
    ) external returns (bytes32 record) {
        _forwardIdentityWriter();
    }

    function consumeSaleConsent(
        T.ActionContext calldata c,
        T.Binding calldata b,
        Sale.Consent calldata p,
        T.Authorization calldata a,
        T.SignerApproval calldata proof
    ) external returns (bytes32 record) {
        _forwardIdentityWriter();
    }

    function consumePolicy(
        T.ActionContext calldata c,
        T.Binding calldata b,
        T.PolicyConsent calldata p,
        T.Authorization calldata a,
        T.SignerApproval calldata proof
    ) external returns (bytes32 record) {
        _forwardIdentityWriter();
    }

    function consumeEconomics(
        T.ActionContext calldata c,
        T.Binding calldata b,
        T.EconomicsConsent calldata p,
        bytes32 designation,
        T.Authorization calldata a,
        T.SignerApproval calldata proof
    ) external returns (bytes32 record) {
        _forwardIdentityWriter();
    }

    function consumePayout(
        T.ActionContext calldata c,
        T.PayoutDesignation calldata p,
        T.Authorization calldata a,
        T.SignerApproval calldata proof
    ) external returns (bytes32 record) {
        _forwardIdentityWriter();
    }

    function consumeAttestation(
        T.ActionContext calldata c,
        T.Binding calldata b,
        T.Attestation calldata p,
        T.Authorization calldata a,
        T.SignerApproval calldata proof
    ) external returns (bytes32 record) {
        _forwardIdentityWriter();
    }

    function consumeRatification(
        T.ActionContext calldata c,
        T.Binding calldata b,
        T.Ratification calldata p,
        T.Authorization calldata a,
        T.SignerApproval calldata proof
    ) external returns (bytes32 record) {
        _forwardIdentityWriter();
    }

    function consumeRoyaltyFreeze(
        T.ActionContext calldata c,
        T.Binding calldata b,
        T.RoyaltyFreeze calldata p,
        T.Authorization calldata a,
        T.SignerApproval calldata proof
    ) external returns (bytes32 record) {
        _forwardIdentityWriter();
    }

    function consumeContentConsent(
        T.ActionContext calldata c,
        T.Binding calldata b,
        Content.Consent calldata p,
        T.Authorization calldata a,
        T.SignerApproval calldata proof
    ) external returns (bytes32 record) {
        _forwardIdentityWriter();
    }

    function consumeContentFreeze(
        T.ActionContext calldata c,
        T.Binding calldata b,
        Content.Freeze calldata p,
        T.Authorization calldata a,
        T.SignerApproval calldata proof
    ) external returns (bytes32 record) {
        _forwardIdentityWriter();
    }

    function _deadline(uint64 deadline) private view {
        if (block.timestamp > deadline) revert T.ExpiredAuthorization(deadline);
    }

    function _forwardIdentityWriter() private {
        address target = identityWriterExtension;
        assembly ("memory-safe") {
            let pointer := mload(0x40)
            calldatacopy(pointer, 0, calldatasize())
            let success := delegatecall(gas(), target, pointer, calldatasize(), 0, 0)
            returndatacopy(pointer, 0, returndatasize())
            if iszero(success) { revert(pointer, returndatasize()) }
            return(pointer, returndatasize())
        }
    }
}
