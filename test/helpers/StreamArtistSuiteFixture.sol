// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    IStreamTestArtistExtensionFactory,
    IStreamTestArtistArtifactAddress
} from "./StreamCurrentTestArtistInterfaces.sol";
import { StreamCurrentTestSlots } from "./StreamCurrentTestSlots.sol";
import { StreamDeploymentSlot } from "../../script/current/StreamDeploymentSlot.sol";
import { StreamCurrentTestRuntime } from "./StreamCurrentTestRuntime.sol";

import "../regression/legacy/helpers/CharacterizationTestBase.sol";
import {
    StreamCurrentFinalityGraph,
    StreamArtistOnboardingRegistry
} from "../../script/current/StreamCurrentFinalityGraph.sol";
import { StreamCurrentGraphKinds } from "../../script/current/StreamCurrentGraphKinds.sol";
import { StreamNativeAssemblyCreation } from "./StreamNativeAssemblyCreation.sol";
import "../../smart-contracts/domains/artist/StreamArtistOnboardingCoordinator.sol";
import "../../smart-contracts/domains/revenue/StreamRevenueResolver.sol";
import "../../smart-contracts/domains/revenue/StreamRoyaltyResolver.sol";
import {
    StreamMetadataRouter
} from "../../smart-contracts/domains/metadata/StreamMetadataRouter.sol";
import "../../smart-contracts/domains/preservation/StreamArchivalCoverage.sol";
import "../../smart-contracts/domains/preservation/StreamArweaveCheckpointVerifier.sol";
import "../../smart-contracts/interfaces/stream/preservation/StreamArchivalTypes.sol";

interface ArtistSuiteVm {
    function getCode(string calldata artifact) external view returns (bytes memory);
    function getNonce(address account) external view returns (uint64);
    function computeCreateAddress(address deployer, uint256 nonce) external pure returns (address);
}

/// @notice Real artist owners and real provider dependencies shared by current-stack scenarios.
/// @dev CREATE predictions break constructor references only; no code, storage or authority is mocked.
abstract contract StreamArtistSuiteFixture is CharacterizationTestBase, StreamCurrentFinalityGraph {
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
        s.validator = address(
            StreamArtistRegistryValidatorBase(
                payable(_artistSuiteArtifactCreate(
                        "smart-contracts/domains/artist/StreamArtistRegistryValidatorBase.sol:StreamArtistRegistryValidatorBase",
                        abi.encode()
                    ))
            )
        );
        s.primaryRevenueClass = PRIMARY_REVENUE_CLASS;
        _deployArtistArchival(core_, executor_, roles_);
        address nextCoordinator = _reserveCurrentCoordinator(address(this));
        IStreamTestArtistExtensionFactory artistExtensions = IStreamTestArtistExtensionFactory(
            payable(_artistSuiteArtifactCreate(
                    "smart-contracts/domains/artist/StreamArtistExtensionFactory.sol:StreamArtistExtensionFactory",
                    abi.encode(
                        [
                            address(
                                IStreamTestArtistArtifactAddress(
                                    payable(_artistSuiteArtifactCreate(
                                            "smart-contracts/domains/artist/StreamArtistIdentityCreationPart.sol:StreamArtistIdentityCreationPart",
                                            abi.encode(0)
                                        ))
                                )
                            ),
                            address(
                                IStreamTestArtistArtifactAddress(
                                    payable(_artistSuiteArtifactCreate(
                                            "smart-contracts/domains/artist/StreamArtistIdentityCreationPart.sol:StreamArtistIdentityCreationPart",
                                            abi.encode(1)
                                        ))
                                )
                            ),
                            address(
                                IStreamTestArtistArtifactAddress(
                                    payable(_artistSuiteArtifactCreate(
                                            "smart-contracts/domains/artist/StreamArtistEstateCreationPart.sol:StreamArtistEstateCreationPart",
                                            abi.encode(0)
                                        ))
                                )
                            ),
                            address(
                                IStreamTestArtistArtifactAddress(
                                    payable(_artistSuiteArtifactCreate(
                                            "smart-contracts/domains/artist/StreamArtistEstateCreationPart.sol:StreamArtistEstateCreationPart",
                                            abi.encode(1)
                                        ))
                                )
                            )
                        ]
                    )
                ))
        );
        artists = _deploySplitArtistFacade(
            _graphCreation(StreamCurrentGraphKinds.Kind.StreamArtistOnboardingRegistry),
            address(this),
            address(artistExtensions),
            [core_, manager_, nextCoordinator, executor_, address(artistArchivalCoverage)],
            deploymentHash,
            "urn:6529stream:fixture:artist",
            keccak256("fixture artist module")
        );
        s.registry = address(artists);
        s.archive = address(
            IStreamTestArtistArtifactAddress(
                payable(_artistSuiteArtifactCreate(
                        "smart-contracts/domains/artist/StreamArtistArchiveV2.sol:StreamArtistArchiveV2",
                        abi.encode(s.registry, nextCoordinator)
                    ))
            )
        );
        s.owners[0] = address(
            IStreamTestArtistArtifactAddress(
                payable(_artistSuiteArtifactCreate(
                        "smart-contracts/domains/artist/StreamArtistBindingLifecycle.sol:StreamArtistBindingLifecycle",
                        abi.encode(s.registry, nextCoordinator, s.archive, core_, manager_)
                    ))
            )
        );
        s.owners[1] = address(
            IStreamTestArtistArtifactAddress(
                payable(_artistSuiteArtifactCreate(
                        "smart-contracts/domains/artist/StreamArtistCollaboratorLifecycle.sol:StreamArtistCollaboratorLifecycle",
                        abi.encode(s.registry, nextCoordinator, s.archive, core_, manager_)
                    ))
            )
        );
        s.owners[2] = _deploySplitArtistIdentity(
            _graphCreation(StreamCurrentGraphKinds.Kind.StreamArtistIdentityAuthority),
            address(this),
            address(artistExtensions),
            [s.registry, nextCoordinator, s.archive, core_, manager_]
        );
        s.owners[3] = address(
            IStreamTestArtistArtifactAddress(
                payable(_artistSuiteArtifactCreate(
                        "smart-contracts/domains/artist/StreamArtistAcceptanceLifecycle.sol:StreamArtistAcceptanceLifecycle",
                        abi.encode(s.registry, nextCoordinator, s.archive, core_, manager_)
                    ))
            )
        );
        s.owners[4] = address(
            IStreamTestArtistArtifactAddress(
                payable(_artistSuiteArtifactCreate(
                        "smart-contracts/domains/artist/StreamArtistAttributionLifecycle.sol:StreamArtistAttributionLifecycle",
                        abi.encode(s.registry, nextCoordinator, s.archive, core_, manager_)
                    ))
            )
        );
        s.owners[5] = address(
            IStreamTestArtistArtifactAddress(
                payable(_artistSuiteArtifactCreate(
                        "smart-contracts/domains/artist/StreamArtistPayoutLifecycle.sol:StreamArtistPayoutLifecycle",
                        abi.encode(s.registry, nextCoordinator, s.archive, core_, manager_)
                    ))
            )
        );
        s.owners[6] = address(
            IStreamTestArtistArtifactAddress(
                payable(_artistSuiteArtifactCreate(
                        "smart-contracts/domains/artist/StreamArtistConsentFinalityLifecycle.sol:StreamArtistConsentFinalityLifecycle",
                        abi.encode(s.registry, nextCoordinator, s.archive, core_, manager_)
                    ))
            )
        );
        IStreamArtistAttribution attribution = IStreamArtistAttribution(s.registry);
        router = StreamMetadataRouter(
            payable(_artistSuiteArtifactCreate(
                    "smart-contracts/domains/metadata/StreamMetadataRouter.sol:StreamMetadataRouter",
                    abi.encode(
                        core_,
                        executor_,
                        deploymentHash,
                        "https://engineering.example.invalid/6529stream/fixture/router",
                        keccak256("fixture metadata module"),
                        attribution
                    )
                ))
        );
        primaryResolver = StreamRevenueResolver(
            payable(_artistSuiteArtifactCreate(
                    "smart-contracts/domains/revenue/StreamRevenueResolver.sol:StreamRevenueResolver",
                    abi.encode(
                        IStreamCore(core_),
                        factory_,
                        executor_,
                        attribution,
                        IStreamGasParameterHost.GasParameterConfig(
                            "ARTIST_BENEFICIARY_READ_GAS", 200_000, 50_000, 2
                        )
                    )
                ))
        );
        royalties = StreamRoyaltyResolver(
            payable(_artistSuiteArtifactCreate(
                    "smart-contracts/domains/revenue/StreamRoyaltyResolver.sol:StreamRoyaltyResolver",
                    abi.encode(IStreamCore(core_), factory_, executor_, attribution)
                ))
        );
        s.metadata = address(router);
        s.primaryResolver = address(primaryResolver);
        s.royaltyResolver = address(royalties);
        artistSuite = s;
        _bindCurrentArtistGraph(
            s,
            _fixtureModuleRegistry(),
            executor_,
            _fixtureSystemManifest(),
            address(artistArchivalCoverage),
            address(artistArchivalCheckpoint),
            deploymentHash
        );
    }

    /// @dev Real zero-value CREATE in this fixture, with original constructor bytes.
    /// Forge resolves the genuine native artifact's libraries before returning its code.
    function _artistSuiteArtifactCreate(string memory artifact, bytes memory arguments)
        private
        returns (address deployed)
    {
        ArtistSuiteVm artifactVm =
            ArtistSuiteVm(address(uint160(uint256(keccak256("hevm cheat code")))));
        bytes memory creation = artifactVm.getCode(artifact);
        require(creation.length != 0, "missing original Artist production artifact");
        bytes memory init = bytes.concat(creation, arguments);
        assembly ("memory-safe") {
            deployed := create(0, add(init, 32), mload(init))
            if iszero(deployed) {
                let ptr := mload(0x40)
                returndatacopy(ptr, 0, returndatasize())
                revert(ptr, returndatasize())
            }
        }
    }

    // Keep artifact/runtime selection in this host at its original post-factory position.
    function _slot()
        internal
        virtual
        override
        returns (StreamDeploymentSlot slot, address expected)
    {
        return StreamCurrentTestSlots.reserve(graphOperator);
    }

    function _deploySlot(
        StreamDeploymentSlot slot,
        address expected,
        bytes memory creation,
        bytes memory args,
        bytes memory runtime
    ) internal virtual override returns (address product) {
        return StreamCurrentTestSlots.deploySlot(
            graphOperator, slot, expected, creation, args, runtime
        );
    }

    function _deploySplitArtistFacade(
        bytes memory creation,
        address operator_,
        address factory_,
        address[5] memory p,
        bytes32 deploymentHash,
        string memory uri,
        bytes32 manifestHash
    ) internal virtual override returns (StreamArtistOnboardingRegistry) {
        StreamCurrentTestSlots.FacadeContext memory c =
            StreamCurrentTestSlots.FacadeContext(
                operator_, factory_, p, deploymentHash, uri, manifestHash
            );
        StreamCurrentTestSlots.SplitPlan memory plan = StreamCurrentTestSlots.prepareFacade(c);
        bytes memory runtime = _productRuntime(plan.name, plan.parents, creation, plan.values);
        return StreamArtistOnboardingRegistry(
            payable(StreamCurrentTestSlots.finishFacade(c, plan, creation, runtime))
        );
    }

    function _deploySplitArtistIdentity(
        bytes memory creation,
        address operator_,
        address factory_,
        address[5] memory p
    ) internal virtual override returns (address host) {
        StreamCurrentTestSlots.IdentityContext memory c =
            StreamCurrentTestSlots.IdentityContext(operator_, factory_, p);
        StreamCurrentTestSlots.SplitPlan memory plan = StreamCurrentTestSlots.prepareIdentity(c);
        bytes memory runtime = _productRuntime(plan.name, plan.parents, creation, plan.values);
        return StreamCurrentTestSlots.finishIdentity(c, plan, creation, runtime);
    }

    function _runtime(
        string memory artifactPath,
        string[] memory declarationArtifacts,
        bytes memory linkedCreation,
        RuntimeValue[] memory values
    ) internal view virtual override returns (bytes memory) {
        return StreamCurrentTestRuntime.runtime(
            artifactPath, declarationArtifacts, linkedCreation, values
        );
    }

    function _linkRuntime(string memory artifact, bytes memory linkedCreation)
        internal
        view
        virtual
        override
        returns (bytes memory, bytes memory)
    {
        return StreamCurrentTestRuntime.linkRuntime(artifact, linkedCreation);
    }

    function _fixtureModuleRegistry() internal view virtual returns (address);
    function _fixtureSystemManifest() internal view virtual returns (address);

    function _graphCreation(StreamCurrentGraphKinds.Kind kind)
        internal
        view
        override
        returns (bytes memory)
    {
        return StreamNativeAssemblyCreation.creation(
            StreamNativeAssemblyCreation.Kind(uint256(kind))
        );
    }

    function _completeFixtureArtistSuite(bytes memory rendererCatalog) internal {
        _completeCurrentFinalityGraph(rendererCatalog);
        artistCoordinator = assemblyCoordinator;
        require(
            address(artistCoordinator) == assemblyCoordinatorAddress,
            "original Coordinator slot fulfilled"
        );
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
        artistArchivalCheckpoint = StreamArweaveCheckpointVerifier(
            payable(_artistSuiteArtifactCreate(
                    "smart-contracts/domains/preservation/StreamArweaveCheckpointVerifier.sol:StreamArweaveCheckpointVerifier",
                    abi.encode(executor_, observers, 2, signatureGas)
                ))
        );
        artistArchivalCoverage = StreamArchivalCoverage(
            payable(_artistSuiteArtifactCreate(
                    "smart-contracts/domains/preservation/StreamArchivalCoverage.sol:StreamArchivalCoverage",
                    abi.encode(
                        core_,
                        executor_,
                        roles_,
                        address(artistArchivalCheckpoint),
                        signatureGas,
                        IStreamGasParameterHost.GasParameterConfig(
                            "ARCHIVAL_DEPENDENCY_READ_GAS", 150_000, 50_000, 2
                        )
                    )
                ))
        );
        require(address(artistArchivalCheckpoint).code.length <= 24_576, "checkpoint deployable");
        require(address(artistArchivalCoverage).code.length <= 24_576, "coverage deployable");
    }

    /// @dev Called after real role grant, Core pointer selection, content and economics configuration.
    function _onboardFixtureArtist(address artist_) internal virtual {
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
