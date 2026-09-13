// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

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
import "../../smart-contracts/domains/preservation/StreamArweaveCheckpointVerifier.sol";
import "../../smart-contracts/domains/preservation/StreamArchivalCoverage.sol";

interface ArtistDeploymentVm {
    function getNonce(address account) external view returns (uint64);
    function computeCreateAddress(address deployer, uint256 nonce) external pure returns (address);
}

/// @notice Foundry deployment assembly for the real immutable artist owners and providers.
/// @dev CREATE prediction reads the actual broadcast sender's nonce. The caller must keep
///      this sequence uninterrupted; the final equality check verifies every immutable edge.
abstract contract StreamArtistSuiteDeployment {
    bytes32 internal constant PRIMARY_REVENUE_CLASS = keccak256("PRIMARY_SALE");
    StreamArtistOnboardingRegistry internal artistRegistry;
    StreamArtistOnboardingCoordinator internal artistCoordinator;
    StreamRevenueResolver internal primaryRevenue;
    StreamMetadataRouter internal router;
    StreamRoyaltyResolver internal royalty;
    T.SuiteConfiguration internal artistSuite;
    StreamArweaveCheckpointVerifier internal archivalCheckpoint;
    StreamArchivalCoverage internal archivalCoverage;
    StreamArchivalTypes.Observer[] internal archivalObservers;
    uint8 internal archivalQuorum;
    uint256 internal archivalSignatureGas;
    uint256 internal archivalReadGas;

    function _artistDeploymentSender() internal view virtual returns (address);

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
        // The Executor foundation must already bind its actual RoleRegistry.
        // Observer accounts and organization commitments come from explicit operator
        // configuration; test private keys are never deployment defaults.
        IStreamGasParameterHost.GasParameterConfig memory signatureGas =
            IStreamGasParameterHost.GasParameterConfig(
                "ARCHIVAL_ERC1271_VERIFY_GAS", archivalSignatureGas, 90_000, 2
            );
        archivalCheckpoint = new StreamArweaveCheckpointVerifier(
            executor_, archivalObservers, archivalQuorum, signatureGas
        );
        archivalCoverage = new StreamArchivalCoverage(
            core_, executor_, roles_, address(archivalCheckpoint), signatureGas,
            IStreamGasParameterHost.GasParameterConfig(
                "ARCHIVAL_DEPENDENCY_READ_GAS", archivalReadGas, 50_000, 2
            )
        );
        ArtistDeploymentVm prediction =
            ArtistDeploymentVm(address(uint160(uint256(keccak256("hevm cheat code")))));
        uint256 nonce = prediction.getNonce(_artistDeploymentSender());
        // Facade, archive, seven owners, metadata, primary, royalty, then coordinator.
        address nextCoordinator =
            prediction.computeCreateAddress(_artistDeploymentSender(), nonce + 12);
        artistRegistry = new StreamArtistOnboardingRegistry(
            core_,
            manager_,
            nextCoordinator,
            executor_,
            address(archivalCoverage),
            deploymentHash,
            "urn:6529stream:development:artist",
            keccak256("development artist module")
        );
        s.registry = address(artistRegistry);
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
        // Retain the named artifact's exact initcode for Foundry broadcast decoding.
        bytes memory routerInitcode = bytes.concat(
            type(StreamMetadataRouter).creationCode,
            abi.encode(
                core_,
                executor_,
                deploymentHash,
                "urn:6529stream:development:metadata",
                keccak256("development metadata module"),
                attribution
            )
        );
        address deployedRouter;
        assembly ("memory-safe") {
            deployedRouter := create(0, add(routerInitcode, 32), mload(routerInitcode))
        }
        require(deployedRouter != address(0), "metadata deployment failed");
        router = StreamMetadataRouter(deployedRouter);
        primaryRevenue = new StreamRevenueResolver(
            IStreamCore(core_),
            factory_,
            executor_,
            attribution,
            IStreamGasParameterHost.GasParameterConfig(
                "ARTIST_BENEFICIARY_READ_GAS", 200_000, 50_000, 2
            )
        );
        royalty = new StreamRoyaltyResolver(IStreamCore(core_), factory_, executor_, attribution);
        s.metadata = address(router);
        s.primaryResolver = address(primaryRevenue);
        s.royaltyResolver = address(royalty);
        artistCoordinator = new StreamArtistOnboardingCoordinator(s);
        require(address(artistCoordinator) == nextCoordinator, "artist deployment order");
        artistSuite = s;
    }
}
