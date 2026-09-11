// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./StreamArtistEconomicsHashes.sol";

import "./StreamArtistOnboardingCoordinator.sol";
import "../../interfaces/stream/artist/IStreamArtistOnboarding.sol";
import "../../interfaces/stream/artist/IStreamArtistContentRatification.sol";
import "../../interfaces/stream/artist/IStreamArtistEconomicsAuthority.sol";
import "../modules/StreamModuleBase.sol";
import "../parameters/StreamGasParameterHost.sol";
import {
    StreamArtistOnboardingTypes as T
} from "../../interfaces/stream/artist/StreamArtistOnboardingTypes.sol";

/// @notice Immutable artist ingress and composed reads for the supported first-sale profile.
/// @dev The facade is the EIP712 registry identity. Semantic state stays in its separate owners.
///      This subset does not advertise the full artist lifecycle or legacy nomination API.
contract StreamArtistOnboardingRegistry is
    IStreamArtistOnboarding,
    IStreamArtistMintConsent,
    IStreamArtistAttribution,
    IStreamArtistContentRatification,
    IStreamArtistEconomicsAuthority,
    StreamModuleBase,
    StreamGasParameterHost
{
    address public immutable override(IStreamArtistMintConsent, IStreamArtistAttribution) core;
    address public immutable override mintManager;
    address public immutable operationCoordinator;

    constructor(
        address core_,
        address manager_,
        address coordinator_,
        address governance_,
        bytes32 deploymentHash,
        string memory manifestURI,
        bytes32 manifestHash
    )
        StreamModuleBase(
            keccak256("6529stream.artist-onboarding.v1"),
            address(0),
            deploymentHash,
            manifestURI,
            manifestHash
        )
        StreamGasParameterHost(governance_)
    {
        if (
            core_.code.length == 0 || manager_.code.length == 0 || coordinator_ == address(0)
                || coordinator_ == address(this) || core_ == manager_
        ) revert T.InvalidBinding();
        core = core_;
        mintManager = manager_;
        operationCoordinator = coordinator_;
        _registerGasParameter(GasParameterConfig("ARTIST_ERC1271_VERIFY_GAS", 150_000, 90_000, 2));
    }

    function streamModuleType() public pure override returns (bytes32) {
        return keccak256("ARTIST_REGISTRY");
    }

    function streamModuleVersion() public pure override returns (bytes32) {
        return keccak256("6529stream.artist-onboarding.v1");
    }

    function streamModuleInterfaceId() public pure override returns (bytes4) {
        return type(IStreamArtistMintConsent).interfaceId;
    }

    function supportsInterface(bytes4 id) public view override returns (bool) {
        return id == type(IStreamArtistMintConsent).interfaceId
            || id == type(IStreamArtistAttribution).interfaceId
            || id == type(IStreamArtistOnboarding).interfaceId
            || id == type(IStreamArtistContentRatification).interfaceId
            || id == type(IStreamArtistEconomicsAuthority).interfaceId
            || super.supportsInterface(id);
    }

    function proposeArtistBinding(
        uint256 collectionId,
        T.BindingProposal calldata p,
        bytes calldata document,
        string calldata displayName
    ) external returns (bytes32, bytes32) {
        return IStreamArtistOnboardingCoordinator(operationCoordinator)
            .coordinateProposeArtistBinding(msg.sender, collectionId, p, document, displayName);
    }

    function acceptArtistBinding(uint256 collectionId, T.Authorization calldata a)
        external
        returns (bytes32)
    {
        return IStreamArtistOnboardingCoordinator(operationCoordinator)
            .coordinateAcceptArtistBinding(msg.sender, collectionId, a);
    }

    function recordPolicyConsent(T.PolicyConsent calldata p, T.Authorization calldata a)
        external
        returns (bytes32)
    {
        return IStreamArtistOnboardingCoordinator(operationCoordinator)
            .coordinateRecordPolicyConsent(msg.sender, p, a);
    }

    function recordEconomicsConsent(T.EconomicsConsent calldata p, T.Authorization calldata a)
        external
        returns (bytes32)
    {
        return IStreamArtistOnboardingCoordinator(operationCoordinator)
            .coordinateRecordEconomicsConsent(msg.sender, p, a);
    }

    function recordPayoutDesignation(T.PayoutDesignation calldata p, T.Authorization calldata a)
        external
        returns (bytes32)
    {
        return IStreamArtistOnboardingCoordinator(operationCoordinator)
            .coordinateRecordPayoutDesignation(msg.sender, p, a);
    }

    function recordProspectiveEconomicsConsent(
        T.EconomicsConsent calldata p,
        T.FixedEconomicsCandidate calldata candidate,
        T.Authorization calldata a
    ) external returns (bytes32) {
        return IStreamArtistEconomicsCoordinator(operationCoordinator)
            .coordinateRecordProspectiveEconomicsConsent(msg.sender, p, candidate, a);
    }

    function authorizeArtistRoyaltyFreeze(T.RoyaltyFreeze calldata p, T.Authorization calldata a)
        external
        returns (bytes32)
    {
        return IStreamArtistEconomicsCoordinator(operationCoordinator)
            .coordinateAuthorizeArtistRoyaltyFreeze(msg.sender, p, a);
    }

    function isRoyaltyFreezeAuthorized(uint256 collectionId, bytes32 expectedAssignmentHash)
        external
        view
        returns (bool)
    {
        return _reads().isRoyaltyFreezeAuthorized(collectionId, expectedAssignmentHash);
    }

    function royaltyFreezeDigest(T.RoyaltyFreeze calldata p, T.Authorization calldata a)
        external
        view
        returns (bytes32)
    {
        return StreamArtistEconomicsHashes.royaltyFreezeDigest(_environment(), p, a.nonce, a.time);
    }

    function recordArtistAttestation(
        T.Attestation calldata p,
        T.Authorization calldata a,
        bytes calldata statement
    ) external returns (bytes32) {
        return IStreamArtistOnboardingCoordinator(operationCoordinator)
            .coordinateRecordArtistAttestation(msg.sender, p, a, statement);
    }

    function recordContentRatification(T.Ratification calldata p, T.Authorization calldata a)
        external
        returns (bytes32)
    {
        return IStreamArtistOnboardingCoordinator(operationCoordinator)
            .coordinateRecordContentRatification(msg.sender, p, a);
    }

    function consentMode(uint256 collectionId) external view returns (uint8) {
        return _reads().consentMode(collectionId);
    }

    function acceptedArtist(uint256 collectionId) external view returns (address) {
        return _reads().acceptedArtist(collectionId);
    }

    function attribution(uint256 collectionId)
        external
        view
        returns (IStreamCollectionArtistRegistry.Attribution memory)
    {
        return _reads().attribution(collectionId);
    }

    function isPolicyConsented(uint256 collectionId, bytes32 phaseId, bytes32 policyHash)
        external
        view
        returns (bool, bytes32)
    {
        return _reads().isPolicyConsented(collectionId, phaseId, policyHash);
    }

    function requireMintConsent(uint256 collectionId, bytes32 phaseId, bytes32 policyHash)
        external
        view
    {
        _reads().requireMintConsent(collectionId, phaseId, policyHash);
    }

    function firstReleaseRatification(uint256 collectionId)
        external
        view
        returns (bool, bytes32, bytes32)
    {
        T.SuiteConfiguration memory s =
            StreamArtistOnboardingCoordinator(operationCoordinator).suiteConfiguration();
        T.RatificationRecord memory r =
            IStreamArtistConsentOwner(s.owners[6]).firstReleaseRatification(collectionId);
        return (r.recordHash != bytes32(0), r.contentStateHash, r.recordHash);
    }

    function artistPayoutAccount(bytes32 artistId) external view returns (address, bytes32) {
        T.SuiteConfiguration memory s =
            StreamArtistOnboardingCoordinator(operationCoordinator).suiteConfiguration();
        return IStreamArtistPayoutOwner(s.owners[5]).artistPayoutAccount(artistId);
    }

    function requireEconomicsConsent(
        uint256 collectionId,
        bytes32 revenueClass,
        uint8 scope,
        uint256 scopeId,
        bytes32 assignmentHash
    ) external view {
        _reads()
            .requireEconomicsConsent(
                T.EconomicsConsent(
                    collectionId, msg.sender, revenueClass, scope, scopeId, assignmentHash
                )
            );
    }

    function acceptanceDigest(uint256 collectionId, T.Authorization calldata a)
        external
        view
        returns (bytes32)
    {
        T.SuiteConfiguration memory s =
            StreamArtistOnboardingCoordinator(operationCoordinator).suiteConfiguration();
        return StreamArtistHashes.acceptanceDigest(
            _environment(),
            collectionId,
            IStreamArtistBindingOwner(s.owners[0]).binding(collectionId),
            a
        );
    }

    function policyConsentDigest(T.PolicyConsent calldata p, T.Authorization calldata a)
        external
        view
        returns (bytes32)
    {
        return StreamArtistHashes.policyDigest(_environment(), p, a);
    }

    function economicsConsentDigest(T.EconomicsConsent calldata p, T.Authorization calldata a)
        external
        view
        returns (bytes32)
    {
        return StreamArtistEconomicsHashes.economicsDigest(_environment(), p, a.nonce, a.time);
    }

    function payoutDesignationDigest(T.PayoutDesignation calldata p, T.Authorization calldata a)
        external
        view
        returns (bytes32)
    {
        return StreamArtistHashes.payoutDigest(_environment(), p, a);
    }

    function attestationDigest(T.Attestation calldata p, T.Authorization calldata a)
        external
        view
        returns (bytes32)
    {
        return StreamArtistHashes.attestationDigest(_environment(), p, a);
    }

    function contentRatificationDigest(T.Ratification calldata p, T.Authorization calldata a)
        external
        view
        returns (bytes32)
    {
        return StreamArtistHashes.ratificationDigest(_environment(), p, a);
    }

    function _environment() private view returns (StreamArtistHashes.Environment memory) {
        return StreamArtistHashes.Environment(
            StreamArtistOnboardingCoordinator(operationCoordinator).deploymentChainId(),
            address(this),
            core,
            mintManager
        );
    }

    function _reads() private view returns (StreamArtistOnboardingReads) {
        return StreamArtistOnboardingCoordinator(operationCoordinator).reads();
    }
}
