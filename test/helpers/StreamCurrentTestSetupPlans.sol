// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { StreamGovernanceGenesisPlan } from "../../script/current/StreamGovernanceGenesisPlan.sol";
import {
    IStreamSetupPlansMintManager,
    IStreamSetupPlansMintLedger,
    IStreamSetupPlansFixedPriceSaleAdapter,
    IStreamSetupPlansEnglishAuctionHouse,
    IStreamSetupPlansEntropyCoordinator,
    IStreamSetupPlansMetadataRouter,
    IStreamSetupPlansAssetPolicyRegistry,
    IStreamSetupPlansCore,
    IStreamSetupPlansRoyaltyResolver,
    IStreamSetupPlansGovernanceExecutor,
    IStreamSetupPlansRoleRegistry,
    IStreamSetupPlansModuleRegistry,
    IStreamSetupPlansSystemManifest,
    IStreamSetupPlansSplitFactory,
    IStreamSetupPlansArtistOnboardingRegistry,
    IStreamSetupPlansRevenueEscrow,
    IStreamSetupPlansRevenueResolver
} from "./StreamCurrentTestSetupPlanTargets.sol";
import {
    IStreamArtistIdentityContest
} from "../../smart-contracts/interfaces/stream/artist/IStreamArtistIdentityContest.sol";
import {
    IStreamArtistIdentityDismissal
} from "../../smart-contracts/interfaces/stream/artist/IStreamArtistIdentityDismissal.sol";
import "../../smart-contracts/interfaces/stream/governance/IStreamGovernanceExecutor.sol";
import "../../smart-contracts/interfaces/stream/governance/IStreamSystemManifest.sol";
import "../../smart-contracts/interfaces/stream/governance/IStreamGenesisInitializer.sol";

/// @notice Read-only planners shared by current test hosts through a fixed library link.
/// @dev No fixture storage or construction moves here. Returned values retain the original
/// policy order and governance planner; the library call does not establish gas equivalence.
library StreamCurrentTestSetupPlans {
    struct Targets {
        IStreamSetupPlansMintManager manager;
        IStreamSetupPlansMintLedger ledger;
        IStreamSetupPlansFixedPriceSaleAdapter sale;
        IStreamSetupPlansEnglishAuctionHouse auction;
        IStreamSetupPlansEntropyCoordinator entropy;
        IStreamSetupPlansMetadataRouter router;
        IStreamSetupPlansAssetPolicyRegistry assetPolicy;
        IStreamSetupPlansCore core;
        IStreamSetupPlansRoyaltyResolver royalties;
        IStreamSetupPlansGovernanceExecutor executor;
        IStreamSetupPlansRoleRegistry roles;
        IStreamSetupPlansModuleRegistry registry;
        IStreamSetupPlansSystemManifest manifest;
        IStreamSetupPlansSplitFactory factory;
        IStreamSetupPlansArtistOnboardingRegistry artists;
        IStreamSetupPlansRevenueEscrow revenueEscrow;
        IStreamSetupPlansRevenueResolver primaryResolver;
    }

    function foundationPlan(
        StreamGovernanceGenesisPlan.Configuration memory c,
        address payloadRoot,
        StreamSystemManifestUpdate memory update
    )
        public
        view
        returns (SystemManifestBootstrapBinding memory binding, GenesisBatch[] memory batches)
    {
        return StreamGovernanceGenesisPlan.build(c, payloadRoot, update);
    }

    function operatingPolicies(
        Targets calldata t,
        bytes32 deploymentHash,
        GovernanceActionPolicyEntry[] calldata additional
    ) public view returns (GovernanceActionPolicyEntry[] memory rows) {
        rows = new GovernanceActionPolicyEntry[](76 + additional.length);
        rows[0] =
            _operatingPolicy(deploymentHash, address(t.manager), t.manager.configurePhase.selector);
        rows[1] = _operatingPolicy(
            deploymentHash, address(t.manager), t.manager.setPhaseExecutor.selector
        );
        rows[2] =
            _operatingPolicy(deploymentHash, address(t.manager), t.manager.setPhasePaused.selector);
        rows[3] =
            _operatingPolicy(deploymentHash, address(t.ledger), t.ledger.setLedgerWriter.selector);
        rows[4] =
            _operatingPolicy(deploymentHash, address(t.sale), t.sale.setPlatformSigner.selector);
        rows[5] = _operatingPolicy(deploymentHash, address(t.sale), t.sale.setPaused.selector);
        rows[6] = _operatingPolicy(
            deploymentHash, address(t.auction), t.auction.setPlatformSigner.selector
        );
        rows[7] = _operatingPolicy(deploymentHash, address(t.auction), t.auction.setPaused.selector);
        rows[8] =
            _operatingPolicy(deploymentHash, address(t.entropy), t.entropy.setRequester.selector);
        rows[9] = _operatingPolicy(
            deploymentHash, address(t.entropy), t.entropy.setProviderRevoked.selector
        );
        rows[10] = _operatingPolicy(
            deploymentHash, address(t.entropy), t.entropy.markRequestStale.selector
        );
        rows[11] = _operatingPolicy(
            deploymentHash, address(t.entropy), t.entropy.markRequestFailed.selector
        );
        rows[12] = _operatingPolicy(
            deploymentHash, address(t.router), t.router.setCollectionScript.selector
        );
        rows[13] = _operatingPolicy(
            deploymentHash, address(t.router), t.router.setContractMetadataURI.selector
        );
        rows[14] = _operatingPolicy(
            deploymentHash, address(t.assetPolicy), t.assetPolicy.setAssetStatus.selector
        );
        rows[15] =
            _operatingPolicy(deploymentHash, address(t.core), t.core.raiseGasParameter.selector);
        rows[16] = _operatingPolicy(
            deploymentHash, address(t.core), t.core.setCollectionMaxSupply.selector
        );
        rows[17] = _operatingPolicy(
            deploymentHash, address(t.royalties), t.royalties.configureDefaultRoyalty.selector
        );
        rows[18] = _operatingPolicy(
            deploymentHash, address(t.royalties), t.royalties.configureCollectionRoyalty.selector
        );
        rows[19] = _operatingPolicy(
            deploymentHash, address(t.royalties), t.royalties.freezeDefaultRoyalty.selector
        );
        rows[19].actionClass = 2;
        rows[20] = _operatingPolicy(
            deploymentHash, address(t.royalties), t.royalties.freezeCollectionRoyalty.selector
        );
        rows[20].actionClass = 2;
        uint256 i = 21;
        rows[i++] = _operatingPolicy(
            deploymentHash, 3, address(t.executor), t.executor.rotateGovernanceRoot.selector
        );
        rows[i++] = _operatingPolicy(
            deploymentHash, 3, address(t.executor), t.executor.extendGovernanceActionPolicy.selector
        );
        rows[i++] = _operatingPolicy(
            deploymentHash, 0, address(t.executor), t.executor.registerProposer.selector
        );
        rows[i++] = _operatingPolicy(
            deploymentHash, 1, address(t.executor), t.executor.registerProposer.selector
        );
        rows[i++] = _operatingPolicy(
            deploymentHash, 0, address(t.executor), t.executor.registerCanceller.selector
        );
        rows[i++] = _operatingPolicy(
            deploymentHash, 1, address(t.executor), t.executor.registerCanceller.selector
        );
        rows[i++] = _operatingPolicy(
            deploymentHash, 0, address(t.executor), t.executor.setApprovedNativeReceiver.selector
        );
        rows[i++] = _operatingPolicy(
            deploymentHash, 1, address(t.executor), t.executor.setApprovedNativeReceiver.selector
        );
        rows[i++] = _operatingPolicy(
            deploymentHash, 0, address(t.executor), t.executor.setTighteningCall.selector
        );
        rows[i++] = _operatingPolicy(
            deploymentHash, 1, address(t.executor), t.executor.setTighteningCall.selector
        );
        rows[i++] = _operatingPolicy(
            deploymentHash, 0, address(t.executor), t.executor.registerFreezeSelector.selector
        );
        rows[i++] = _operatingPolicy(
            deploymentHash, 1, address(t.executor), t.executor.registerFreezeSelector.selector
        );
        rows[i++] = _operatingPolicy(
            deploymentHash,
            2,
            address(t.executor),
            t.executor.registerSystemManifestTailTrigger.selector
        );
        rows[i++] =
            _operatingPolicy(deploymentHash, 1, address(t.roles), t.roles.grantRole.selector);
        rows[i++] =
            _operatingPolicy(deploymentHash, 1, address(t.roles), t.roles.revokeRole.selector);
        rows[i++] =
            _operatingPolicy(deploymentHash, 1, address(t.roles), t.roles.grantScopedRole.selector);
        rows[i++] = _operatingPolicy(
            deploymentHash, 1, address(t.roles), t.roles.revokeScopedRole.selector
        );
        rows[i++] = _operatingPolicy(
            deploymentHash, 0, address(t.roles), t.roles.registerRoleManager.selector
        );
        rows[i++] = _operatingPolicy(
            deploymentHash, 1, address(t.roles), t.roles.registerRoleManager.selector
        );
        rows[i++] = _operatingPolicy(
            deploymentHash, 0, address(t.registry), t.registry.setModuleStatus.selector
        );
        rows[i++] = _operatingPolicy(
            deploymentHash, 1, address(t.registry), t.registry.setModuleStatus.selector
        );
        rows[i++] = _operatingPolicy(
            deploymentHash, 1, address(t.registry), t.registry.setModuleRegistryManifest.selector
        );
        rows[i++] = _operatingPolicy(
            deploymentHash, 0, address(t.core), t.core.setCollectionStatus.selector
        );
        rows[i++] = _operatingPolicy(
            deploymentHash, 1, address(t.core), t.core.setCollectionStatus.selector
        );
        rows[i++] = _operatingPolicy(
            deploymentHash, 2, address(t.core), t.core.setCollectionStatus.selector
        );
        rows[i++] = _operatingPolicy(
            deploymentHash, 0, address(t.core), t.core.setCollectionMaxSupply.selector
        );
        rows[i++] = _operatingPolicy(
            deploymentHash, 2, address(t.core), t.core.blockCollectionBurns.selector
        );
        rows[i++] =
            _operatingPolicy(deploymentHash, 2, address(t.core), t.core.freezeCollection.selector);
        rows[i++] = _operatingPolicy(
            deploymentHash, 0, address(t.manifest), t.manifest.publishStreamSystemManifest.selector
        );
        rows[i++] = _operatingPolicy(
            deploymentHash, 1, address(t.manifest), t.manifest.publishStreamSystemManifest.selector
        );
        rows[i++] = _operatingPolicy(
            deploymentHash, 2, address(t.manifest), t.manifest.publishStreamSystemManifest.selector
        );
        rows[i++] = _operatingPolicy(
            deploymentHash, address(t.manager), t.manager.raiseGasParameter.selector
        );
        rows[i++] = _operatingPolicy(
            deploymentHash, address(t.factory), t.factory.raiseGasParameter.selector
        );
        rows[i++] = _operatingPolicy(
            deploymentHash, address(t.artists), t.artists.raiseGasParameter.selector
        );
        rows[i++] = _operatingPolicy(
            deploymentHash, address(t.revenueEscrow), t.revenueEscrow.setCreditProducer.selector
        );
        rows[i++] = _operatingPolicy(
            deploymentHash, address(t.revenueEscrow), t.revenueEscrow.raiseGasParameter.selector
        );
        rows[i++] = _operatingPolicy(
            deploymentHash, address(t.primaryResolver), t.primaryResolver.raiseGasParameter.selector
        );
        rows[i++] = _operatingPolicy(
            deploymentHash,
            address(t.primaryResolver),
            t.primaryResolver.createPrimaryTemplate.selector
        );
        rows[i++] = _operatingPolicy(
            deploymentHash,
            address(t.primaryResolver),
            t.primaryResolver.createDynamicPrimaryTemplate.selector
        );
        rows[i++] = _operatingPolicy(
            deploymentHash, address(t.assetPolicy), t.assetPolicy.setAssetPermitPolicy.selector
        );
        rows[i++] = _operatingPolicy(
            deploymentHash,
            address(t.primaryResolver),
            t.primaryResolver.setPrimaryTemplateAssignment.selector
        );
        rows[i++] = _operatingPolicy(
            deploymentHash, address(t.entropy), t.entropy.raiseTimeParameter.selector
        );
        rows[i++] = _operatingPolicy(
            deploymentHash,
            1,
            address(t.artists),
            IStreamArtistIdentityContest.contestArtistIdentity.selector
        );
        rows[i++] = _operatingPolicy(
            deploymentHash,
            2,
            address(t.artists),
            IStreamArtistIdentityContest.contestArtistIdentity.selector
        );
        rows[i++] = _operatingPolicy(
            deploymentHash,
            1,
            address(t.artists),
            IStreamArtistIdentityDismissal.dismissArtistIdentityContest.selector
        );
        rows[i++] = _operatingPolicy(
            deploymentHash,
            2,
            address(t.artists),
            IStreamArtistIdentityDismissal.dismissArtistIdentityContest.selector
        );
        rows[i++] = _operatingPolicy(
            deploymentHash, address(t.router), t.router.setCollectionScriptManifest.selector
        );
        rows[i++] = _operatingPolicy(
            deploymentHash, address(t.router), t.router.setCollectionMediaManifest.selector
        );
        rows[i++] = _operatingPolicy(
            deploymentHash, address(t.router), t.router.raiseGasParameter.selector
        );
        rows[i++] = _operatingPolicy(
            deploymentHash, address(t.entropy), t.entropy.activateEntropyProvider.selector
        );
        rows[i++] = _operatingPolicy(
            deploymentHash, 0, address(t.entropy), t.entropy.deprecateEntropyProvider.selector
        );
        rows[i++] = _operatingPolicy(
            deploymentHash, 0, address(t.entropy), t.entropy.revokeEntropyProvider.selector
        );
        // Bounded predecessor grace remains an exact delayed-loosening CALL.
        rows[i++] = _operatingPolicy(
            deploymentHash, address(t.manager), t.manager.setPhaseExecutorWithGrace.selector
        );
        rows[i++] =
            _operatingPolicy(deploymentHash, 2, address(t.manager), t.manager.freezePhase.selector);
        rows[i++] = _operatingPolicy(
            deploymentHash, 1, address(t.ledger), t.ledger.importPhaseFreezes.selector
        );
        // Metadata, economics and t.entropy configuration are also collected from genesis.
        for (uint256 j; j < additional.length; ++j) {
            rows[i++] = additional[j];
        }
        assert(i == rows.length);
    }

    function _operatingPolicy(
        bytes32 deploymentHash,
        uint8 actionClass,
        address target,
        bytes4 selector
    ) private view returns (GovernanceActionPolicyEntry memory row) {
        row = _operatingPolicy(deploymentHash, target, selector);
        row.actionClass = actionClass;
    }

    function _operatingPolicy(bytes32 deploymentHash, address target, bytes4 selector)
        private
        view
        returns (GovernanceActionPolicyEntry memory)
    {
        return GovernanceActionPolicyEntry(
            1,
            target,
            selector,
            target.codehash,
            keccak256(abi.encode(deploymentHash, target)),
            1,
            0,
            0,
            bytes32(0)
        );
    }
}
