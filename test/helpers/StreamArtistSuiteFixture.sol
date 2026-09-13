// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../regression/legacy/helpers/CharacterizationTestBase.sol";
import "../../smart-contracts/domains/artist/StreamArtistOnboardingRegistry.sol";
import "../../smart-contracts/domains/artist/StreamArtistOnboardingCoordinator.sol";
import "../../smart-contracts/domains/artist/StreamArtistArchiveV2.sol";
import "../../smart-contracts/domains/artist/StreamArtistBindingLifecycle.sol";
import "../../smart-contracts/domains/artist/StreamArtistCollaboratorLifecycle.sol";
import "../../smart-contracts/domains/artist/StreamArtistIdentityAuthority.sol";
import "../../smart-contracts/domains/artist/StreamArtistAcceptanceLifecycle.sol";
import "../../smart-contracts/domains/artist/StreamArtistAttributionLifecycle.sol";
import "../../smart-contracts/domains/artist/StreamArtistPayoutLifecycle.sol";
import "../../smart-contracts/domains/artist/StreamArtistConsentFinalityLifecycle.sol";
import "../../smart-contracts/domains/revenue/StreamRevenueResolver.sol";
import "../../smart-contracts/domains/revenue/StreamRoyaltyResolver.sol";
import { StreamMetadataRouter } from "../../smart-contracts/domains/metadata/StreamMetadataRouter.sol";
import "../../smart-contracts/domains/preservation/StreamArchivalCoverage.sol";
import "../../smart-contracts/domains/preservation/StreamArweaveCheckpointVerifier.sol";
import "../../smart-contracts/interfaces/stream/preservation/StreamArchivalTypes.sol";

interface ArtistSuiteVm {
    function getNonce(address account) external view returns (uint64);
    function computeCreateAddress(address deployer, uint256 nonce) external pure returns (address);
}

/// @notice Real artist owners and real provider dependencies shared by current-stack scenarios.
/// @dev CREATE predictions break constructor references only; no code, storage or authority is mocked.
abstract contract StreamArtistSuiteFixture is CharacterizationTestBase {
    bytes32 internal constant PRIMARY_REVENUE_CLASS = keccak256("PRIMARY_SALE");
    StreamArtistOnboardingRegistry internal artists;
    StreamArtistOnboardingCoordinator internal artistCoordinator;
    StreamRevenueResolver internal primaryResolver;
    StreamMetadataRouter internal router;
    StreamRoyaltyResolver internal royalties;
    StreamArchivalCoverage internal artistArchivalCoverage;
    StreamArweaveCheckpointVerifier internal artistArchivalCheckpoint;
    uint256 internal constant ARCHIVAL_OBSERVER_ONE = 0xE5701;
    uint256 internal constant ARCHIVAL_OBSERVER_TWO = 0xE5702;
    T.SuiteConfiguration internal artistSuite;
    bytes32 internal fixtureArtistId;
    uint256 private _artistAuthorizationNonce;

    function _deployArtistSuite(
        address core_,
        address manager_,
        address roles_,
        IStreamSplitFactory factory_,
        address executor_,
        bytes32 deploymentHash
    ) internal {
        T.SuiteConfiguration memory s;
        s.core = core_;
        s.mintManager = manager_;
        s.roleRegistry = roles_;
        s.validator = address(new StreamArtistRegistryValidatorBase());
        s.primaryRevenueClass = PRIMARY_REVENUE_CLASS;
        _deployArtistArchival(core_, executor_, roles_);
        ArtistSuiteVm prediction = ArtistSuiteVm(address(vm));
        uint256 nonce = prediction.getNonce(address(this));
        // Facade, archive, seven owners, metadata, primary, royalty, then coordinator.
        address nextCoordinator = prediction.computeCreateAddress(address(this), nonce + 12);
        artists = new StreamArtistOnboardingRegistry(
            core_,
            manager_,
            nextCoordinator,
            executor_,
            address(artistArchivalCoverage),
            deploymentHash,
            "urn:6529stream:fixture:artist",
            keccak256("fixture artist module")
        );
        s.registry = address(artists);
        s.archive = address(new StreamArtistArchiveV2(s.registry, nextCoordinator));
        s.owners[0] = address(
            new StreamArtistBindingLifecycle(
                s.registry, nextCoordinator, s.archive, core_, manager_
            )
        );
        s.owners[1] = address(
            new StreamArtistCollaboratorLifecycle(
                s.registry, nextCoordinator, s.archive, core_, manager_
            )
        );
        s.owners[2] = address(
            new StreamArtistIdentityAuthority(
                s.registry, nextCoordinator, s.archive, core_, manager_
            )
        );
        s.owners[3] = address(
            new StreamArtistAcceptanceLifecycle(
                s.registry, nextCoordinator, s.archive, core_, manager_
            )
        );
        s.owners[4] = address(
            new StreamArtistAttributionLifecycle(
                s.registry, nextCoordinator, s.archive, core_, manager_
            )
        );
        s.owners[5] = address(
            new StreamArtistPayoutLifecycle(s.registry, nextCoordinator, s.archive, core_, manager_)
        );
        s.owners[6] = address(
            new StreamArtistConsentFinalityLifecycle(
                s.registry, nextCoordinator, s.archive, core_, manager_
            )
        );
        IStreamArtistAttribution attribution = IStreamArtistAttribution(s.registry);
        router = new StreamMetadataRouter(
            core_,
            executor_,
            deploymentHash,
            "urn:6529stream:fixture:metadata",
            keccak256("fixture metadata module"),
            attribution
        );
        primaryResolver = new StreamRevenueResolver(
            IStreamCore(core_),
            factory_,
            executor_,
            attribution,
            IStreamGasParameterHost.GasParameterConfig(
                "ARTIST_BENEFICIARY_READ_GAS", 200_000, 50_000, 2
            )
        );
        royalties = new StreamRoyaltyResolver(IStreamCore(core_), factory_, executor_, attribution);
        s.metadata = address(router);
        s.primaryResolver = address(primaryResolver);
        s.royaltyResolver = address(royalties);
        artistCoordinator = new StreamArtistOnboardingCoordinator(s);
        require(address(artistCoordinator) == nextCoordinator, "artist deployment order");
        artistSuite = s;
    }

    /// @dev Canonical governance must already bind its RoleRegistry. Observer signatures in
    ///      tests authenticate fixture evidence; they do not establish an external network quorum.
    function _deployArtistArchival(address core_, address executor_, address roles_) private {
        StreamArchivalTypes.Observer[] memory observers = new StreamArchivalTypes.Observer[](2);
        observers[0] = StreamArchivalTypes.Observer(
            vm.addr(ARCHIVAL_OBSERVER_ONE), keccak256("current archival observer organization one")
        );
        observers[1] = StreamArchivalTypes.Observer(
            vm.addr(ARCHIVAL_OBSERVER_TWO), keccak256("current archival observer organization two")
        );
        if (observers[0].account > observers[1].account) {
            (observers[0], observers[1]) = (observers[1], observers[0]);
        }
        IStreamGasParameterHost.GasParameterConfig memory signatureGas =
            IStreamGasParameterHost.GasParameterConfig(
                "ARCHIVAL_ERC1271_VERIFY_GAS", 400_000, 90_000, 2
            );
        artistArchivalCheckpoint =
            new StreamArweaveCheckpointVerifier(executor_, observers, 2, signatureGas);
        artistArchivalCoverage = new StreamArchivalCoverage(
            core_,
            executor_,
            roles_,
            address(artistArchivalCheckpoint),
            signatureGas,
            IStreamGasParameterHost.GasParameterConfig(
                "ARCHIVAL_DEPENDENCY_READ_GAS", 150_000, 50_000, 2
            )
        );
        require(address(artistArchivalCheckpoint).code.length <= 24_576, "checkpoint deployable");
        require(address(artistArchivalCoverage).code.length <= 24_576, "coverage deployable");
    }

    /// @dev Called after real role grant, Core pointer selection, content and economics configuration.
    function _onboardFixtureArtist(address artist_) internal {
        bytes memory document = bytes("current-stack artist identity");
        T.BindingProposal memory p;
        p.artistAddress = artist_;
        p.identityRecordHash = keccak256(document);
        p.identityRecordURI = "urn:6529stream:fixture:artist-identity";
        p.consentMode = 1;
        p.saleConsentScope = _fixtureSaleConsentScope();
        p.collaborators = new T.CollaboratorRecord[](0);
        p.capabilityPolicyOverrides = new T.CapabilityPolicyOverride[](0);
        (fixtureArtistId,) = artists.proposeArtistBinding(1, p, document, "Stream Artist");
        T.Authorization memory a = _artistAuthorization(false);
        a.signature = _artistProof(artists.acceptanceDigest(1, a));
        artists.acceptArtistBinding(1, a);
        T.PayoutDesignation memory payout =
            T.PayoutDesignation(fixtureArtistId, artist_, bytes32(0));
        a = _artistAuthorization(true);
        a.signature = _artistProof(artists.payoutDesignationDigest(payout, a));
        artists.recordPayoutDesignation(payout, a);
        (T.AssignmentFact memory primary, T.AssignmentFact memory royalty) =
            artistCoordinator.reads().currentAssignments(1);
        _recordFixtureEconomics(primary);
        _recordFixtureEconomics(royalty);
        (, bytes32 contentState) = router.currentArtistContentState(1);
        T.Ratification memory ratification = T.Ratification(1, address(router), contentState);
        a = _artistAuthorization(false);
        a.signature = _artistProof(artists.contentRatificationDigest(ratification, a));
        artists.recordContentRatification(ratification, a);
        T.Binding memory binding_ = IStreamArtistBindingOwner(artistSuite.owners[0]).binding(1);
        bytes32 facts = StreamArtistHashes.deploymentFacts(
            StreamArtistHashes.Environment(
                block.chainid, address(artists), artistSuite.core, artistSuite.mintManager
            ),
            1,
            binding_
        );
        _recordFixtureAttestation(
            9,
            bytes32(uint256(uint160(artistSuite.core))),
            facts,
            keccak256("6529STREAM_ARTIST_DEPLOYMENT_ATTESTATION_V1")
        );
        _recordFixtureAttestation(
            10,
            fixtureArtistId,
            binding_.identityRecordHash,
            keccak256("6529STREAM_ARTIST_PERSONHOOD_WAIVER_V1")
        );
    }

    function _recordFixtureEconomics(T.AssignmentFact memory fact) private {
        T.EconomicsConsent memory p = T.EconomicsConsent(
            1, fact.resolver, fact.revenueClass, fact.scope, fact.scopeId, fact.assignmentHash
        );
        T.Authorization memory a = _artistAuthorization(false);
        a.signature = _artistProof(artists.economicsConsentDigest(p, a));
        artists.recordEconomicsConsent(p, a);
    }

    function _recordFixtureAttestation(uint8 kind, bytes32 subject, bytes32 state, bytes32 schema)
        private
    {
        bytes memory statement = abi.encode(kind, subject, state, schema);
        T.Attestation memory p = T.Attestation(
            1,
            kind,
            subject,
            state,
            schema,
            keccak256(statement),
            "urn:6529stream:fixture:statement"
        );
        T.Authorization memory a = _artistAuthorization(true);
        a.signature = _artistProof(artists.attestationDigest(p, a));
        artists.recordArtistAttestation(p, a, statement);
    }

    function _recordFixturePolicy(bytes32 phase, bytes32 hash) internal {
        T.PolicyConsent memory p = T.PolicyConsent(1, phase, hash);
        T.Authorization memory a = _artistAuthorization(false);
        a.signature = _artistProof(artists.policyConsentDigest(p, a));
        artists.recordPolicyConsent(p, a);
    }

    /// @dev A scenario chooses the immutable binding election before proposing the artist.
    function _fixtureSaleConsentScope() internal view virtual returns (uint8) {
        return 0;
    }

    function _artistAuthorization(bool signedAt) internal returns (T.Authorization memory) {
        return T.Authorization(
            _artistAuthorizationNonce++,
            uint64(signedAt ? block.timestamp : block.timestamp + 1 days),
            ""
        );
    }

    /// @dev Scenario overrides may sign through an actual threshold Safe instead of an EOA.
    function _artistProof(bytes32 digest) internal virtual returns (bytes memory);
}
