// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "./StreamArtistGuardianHeadSelectionActual.t.sol";
import {
    ArtistUnitCore,
    StreamModuleRegistry,
    IStreamGovernanceExecutor,
    ArtistUnitModuleRegistry,
    StreamMintLedger,
    StreamMintManager,
    IStreamCore,
    IERC165,
    StreamArtistRegistryValidatorBase,
    ArtistUnitMetadata,
    StreamSplitFactory,
    StreamAssetPolicyRegistry,
    IStreamSplitWallet,
    ArtistSanctionFinalityFixture,
    StreamArtistOnboardingRegistry,
    StreamArtistArchiveV2,
    StreamArtistBindingLifecycle,
    StreamArtistCollaboratorLifecycle,
    ArtistRotationContestHarness,
    StreamArtistIdentityAuthority,
    StreamArtistAcceptanceLifecycle,
    StreamArtistAttributionLifecycle,
    StreamArtistPayoutLifecycle,
    StreamArtistConsentFinalityLifecycle,
    StreamRevenueResolver,
    IStreamGasParameterHost,
    StreamRoyaltyResolver,
    StreamArtistOnboardingCoordinator
} from "./ArtistOnboardingFixture.sol";

/// @dev Coherent constructor-bound typed governance graph; does not model real scheduling or role administration.
contract ArtistAppealUnitGovernance is ArtistUnitGovernance {
    address public immutable admin;
    address public owner;
    uint64 public rootRevision = 1;

    constructor(address root) {
        admin = msg.sender;
        owner = root;
    }

    function configureRoot(address root) external {
        require(msg.sender == admin, "unit admin");
        owner = root;
        ++rootRevision;
    }

    function governanceRootState() external view returns (address, bytes32, uint64) {
        return (owner, owner.codehash, rootRevision);
    }
}

contract ArtistAppealUnitRoles {
    address public owner;

    function configureOwner(address value) external {
        require(msg.sender == admin, "unit admin");
        owner = value;
    }
    address public immutable admin;
    mapping(address => bool) private extraAdmins;
    uint64 private revision = 1;
    bytes32 private changes;
    mapping(address => bool) private arbiters;
    mapping(address => bool) private appeals;

    constructor(address admin_) {
        admin = admin_;
    }

    function hasRole(bytes32 role, address account) external view returns (bool) {
        return (role == keccak256("ROLE_ATTRIBUTION_APPEAL") && appeals[account])
            || (role == keccak256("ROLE_ATTRIBUTION_ARBITER") && arbiters[account])
            || role == keccak256("ROLE_ARTIST_REGISTRY_ADMIN")
            && (account == admin || extraAdmins[account]);
    }

    function setAppeal(address account, bool enabled) external {
        require(msg.sender == admin, "unit admin");
        appeals[account] = enabled;
        changes = keccak256(abi.encode(changes, account, enabled, "appeal"));
        ++revision;
    }

    function setArbiter(address account, bool enabled) external {
        require(msg.sender == admin, "unit admin");
        arbiters[account] = enabled;
        changes = keccak256(abi.encode(changes, account, enabled, "arbiter"));
        ++revision;
    }

    function setAdmin(address account, bool enabled) external {
        require(msg.sender == admin, "unit admin");
        extraAdmins[account] = enabled;
        changes = keccak256(abi.encode(changes, account, enabled));
        ++revision;
    }

    function roleMutationState(bytes32 role) external view returns (bytes32, uint64) {
        return (
            changes == bytes32(0)
                ? keccak256(abi.encode(role, admin))
                : keccak256(abi.encode(role, admin, changes)),
            revision
        );
    }
}

/// @dev The inherited baseline setup runs first; each appeal case then deploys this separate complete graph.
/// Constructor substitutions are the only changes to the copied original setup body.
abstract contract ArtistGuardianAppealFixture is StreamArtistGuardianHeadSelectionActualTest {
    function _deployAppealSuite() internal {
        nextNonce = 0;
        directArtistCalls = false;
        vm.warp(1000);
        keys = new uint256[](2);
        keys[0] = 0xA11CE;
        keys[1] = 0xB0B;
        safeComponents = deploySafeComponents("1.4.1");
        artist = createOfficialSafe(safeComponents, safeOwnerAddresses(keys), 2, 17);
        core = new ArtistUnitCore();
        address governance = address(new ArtistAppealUnitGovernance(address(this)));
        address modules;
        if (actualSaleRegistryFixture) {
            saleModules = new StreamModuleRegistry(
                IStreamGovernanceExecutor(governance),
                keccak256("artist sale registry"),
                "urn:artist-sale-registry"
            );
            modules = address(saleModules);
        } else {
            modules = address(new ArtistUnitModuleRegistry(governance));
        }
        core.set(keccak256("MODULE_REGISTRY"), modules, false);
        ledger = new StreamMintLedger();
        manager =
            new StreamMintManager(IStreamCore(address(core)), ledger, IERC165(address(modules)));
        // Match the integrated live-provider profile; the real delayed Executor
        // raise is integration-owned. This fixture exercises the actual host checks.
        ArtistUnitGovernance(governance)
            .raise(manager, manager.GGP_ARTIST_AUTHORITY_GAS_LIMIT(), 300_000);
        ledger.setLedgerWriter(address(manager), true);
        suite.core = address(core);
        suite.mintManager = address(manager);
        suite.roleRegistry = address(new ArtistAppealUnitRoles(address(this)));
        ArtistUnitRoles(suite.roleRegistry).configureOwner(governance);
        suite.validator = address(new StreamArtistRegistryValidatorBase());
        metadata = new ArtistUnitMetadata();
        metadata.configureCore(address(core));
        suite.metadata = address(metadata);
        factory = new StreamSplitFactory(
            new StreamAssetPolicyRegistry(governance), governance, _walletGasConfigs()
        );
        IStreamSplitWallet.SplitEntry[] memory entries = new IStreamSplitWallet.SplitEntry[](2);
        entries[0] = IStreamSplitWallet.SplitEntry(address(artist), 900_000, keccak256("artist"));
        entries[1] = IStreamSplitWallet.SplitEntry(address(0xFEE), 100_000, keccak256("protocol"));
        (bytes32 profile, address wallet) =
            factory.createProfile(entries, keccak256("artist unit split"));
        suite.primaryRevenueClass = PRIMARY;
        _deployEstateArchival(address(core), governance);
        sanctionFixture = new ArtistSanctionFinalityFixture();
        uint256 nonce = avm.getNonce(address(this));
        address predictedRegistry = avm.computeCreateAddress(address(this), nonce);
        address predictedArchive = avm.computeCreateAddress(address(this), nonce + 1);
        address predictedCoordinator = avm.computeCreateAddress(address(this), nonce + 12);
        ingress = new StreamArtistOnboardingRegistry(
            suite.core,
            suite.mintManager,
            predictedCoordinator,
            governance,
            address(estateCoverageProvider),
            keccak256("unit deployment"),
            "urn:artist-unit",
            keccak256("unit manifest")
        );
        archive = new StreamArtistArchiveV2(address(ingress), predictedCoordinator);
        suite.registry = address(ingress);
        suite.archive = address(archive);
        suite.owners[0] = address(
            new StreamArtistBindingLifecycle(
                predictedRegistry,
                predictedCoordinator,
                predictedArchive,
                suite.core,
                suite.mintManager
            )
        );
        suite.owners[1] = address(
            new StreamArtistCollaboratorLifecycle(
                predictedRegistry,
                predictedCoordinator,
                predictedArchive,
                suite.core,
                suite.mintManager
            )
        );
        if (rotationContestFixture) {
            suite.owners[2] = address(
                new ArtistRotationContestHarness(
                    predictedRegistry,
                    predictedCoordinator,
                    predictedArchive,
                    suite.core,
                    suite.mintManager
                )
            );
        } else {
            suite.owners[2] = address(
                new StreamArtistIdentityAuthority(
                    predictedRegistry,
                    predictedCoordinator,
                    predictedArchive,
                    suite.core,
                    suite.mintManager
                )
            );
        }
        suite.owners[3] = address(
            new StreamArtistAcceptanceLifecycle(
                predictedRegistry,
                predictedCoordinator,
                predictedArchive,
                suite.core,
                suite.mintManager
            )
        );
        suite.owners[4] = address(
            new StreamArtistAttributionLifecycle(
                predictedRegistry,
                predictedCoordinator,
                predictedArchive,
                suite.core,
                suite.mintManager
            )
        );
        suite.owners[5] = address(
            new StreamArtistPayoutLifecycle(
                predictedRegistry,
                predictedCoordinator,
                predictedArchive,
                suite.core,
                suite.mintManager
            )
        );
        suite.owners[6] = address(
            new StreamArtistConsentFinalityLifecycle(
                predictedRegistry,
                predictedCoordinator,
                predictedArchive,
                suite.core,
                suite.mintManager
            )
        );
        primary = new StreamRevenueResolver(
            IStreamCore(address(core)),
            factory,
            governance,
            ingress,
            IStreamGasParameterHost.GasParameterConfig(
                "ARTIST_BENEFICIARY_READ_GAS", 200_000, 50_000, 2
            )
        );
        // Separate real factory/profile proves royalty payout reads cannot substitute
        // the primary resolver's factory, even when both profiles name the same artist.
        StreamSplitFactory royaltyFactory = new StreamSplitFactory(
            factory.assetPolicyRegistry(), governance, _walletGasConfigs()
        );
        (profile, wallet) = royaltyFactory.createProfile(entries, keccak256("royalty unit split"));
        royalty = new StreamRoyaltyResolver(
            IStreamCore(address(core)), royaltyFactory, governance, ingress
        );
        bytes32 royaltyProfile = profile;
        suite.primaryResolver = address(primary);
        suite.royaltyResolver = address(royalty);
        ArtistUnitGovernance(governance)
            .configureContestReads(
                suite.roleRegistry, address(this), keccak256("finality unit"), "urn:unit"
            );
        address finality =
            sanctionFixture.deploy(address(core), address(metadata), address(ingress), governance);
        coordinator = new StreamArtistOnboardingCoordinator(suite, finality);
        ArtistUnitGovernance(governance)
            .configureContestReads(
                address(estateFixityRoles),
                address(this),
                keccak256("archival fixture"),
                "urn:unit:archival"
            );
        core.set(keccak256("ARTWORK_FINALITY_REGISTRY"), finality, false);
        core.set(keccak256("COLLECTION_METADATA"), address(metadata), false);
        require(address(coordinator) == predictedCoordinator, "fixed constructor pins");
        core.set(keccak256("ARTIST_REGISTRY"), address(ingress), false);
        core.set(keccak256("METADATA_ROUTER"), address(metadata), false);
        metadata.configureArtist(address(ingress));
        core.set(keccak256("ROYALTY_RESOLVER"), address(royalty), false);
        (profile,) = factory.createProfile(entries, keccak256("artist unit split"));
        _installInitialPrimary(governance, profile);
        vm.prank(governance);
        royalty.configureCollectionRoyalty(1, royaltyProfile, 500);
        (artistId,) = ingress.proposeArtistBinding(
            1, _proposal(bytes32(0)), bytes("unit identity document"), "Artist Safe"
        );
        POLICY = _prospective(false);
    }
}
