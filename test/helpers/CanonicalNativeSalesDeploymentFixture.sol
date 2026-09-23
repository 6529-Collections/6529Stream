// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { StreamCurrentSafeGovernanceFixture } from "./StreamCurrentSafeGovernanceFixture.sol";
import { OfficialSafe } from "./OfficialSafeFixture.sol";
import {
    StreamCanonicalNativeSalesDeployment as D
} from "../../script/current/StreamCanonicalNativeSalesDeployment.sol";
import { StreamCurrentStackPlan } from "../../script/current/StreamCurrentStackPlan.sol";
import {
    StreamPrimarySaleSettlement
} from "../../smart-contracts/domains/revenue/StreamPrimarySaleSettlement.sol";
import {
    IStreamPreparedNativePrimarySaleSettlement
} from "../../smart-contracts/interfaces/stream/revenue/IStreamPreparedNativePrimarySaleSettlement.sol";
import {
    IStreamArtistAttribution
} from "../../smart-contracts/interfaces/stream/artist/IStreamArtistAttribution.sol";
import {
    IStreamGasParameterHost
} from "../../smart-contracts/interfaces/stream/parameters/IStreamGasParameterHost.sol";
import {
    StreamModuleRegistration,
    ModuleRegistryStatus
} from "../../smart-contracts/interfaces/stream/modules/IStreamModuleRegistry.sol";
import {
    GenesisBatch
} from "../../smart-contracts/interfaces/stream/governance/IStreamGenesisInitializer.sol";
import {
    GovernanceActionPolicyEntry
} from "../../smart-contracts/interfaces/stream/governance/StreamGovernanceTypes.sol";

/// @notice Canonical companions against the actual current Core/Manager/Artist/Executor graph.
/// @dev Only the upstream entropy service is a test double. The reused Recorder starts unregistered
/// and uncredited; every activation exercised by derived tests uses the real delayed Executor and Safe.
/// Deployment and sale registration are not proof of mint delivery or conservation-floor acceptance.
abstract contract CanonicalNativeSalesDeploymentFixture is StreamCurrentSafeGovernanceFixture {
    bytes32 internal constant COMPANION_PHASE = keccak256("canonical deployment companion phase");
    D.Configuration internal companionConfiguration;
    D.Products internal companionProducts;
    StreamPrimarySaleSettlement internal companionRecorder;

    function setUp() public virtual {
        _deployCurrentStack(vm.addr(ARTIST_KEY), vm.addr(PLATFORM_KEY));
        uint256[] memory keys = new uint256[](2);
        keys[0] = 0xCD501;
        keys[1] = 0xCD502;
        OfficialSafe governor =
            createOfficialSafe(deploySafeComponents("1.4.1"), safeOwnerAddresses(keys), 2, 950);
        _installGovernorSafe(governor, keys);
    }

    function _deployAdditionalProducts() internal virtual override {
        companionRecorder = StreamPrimarySaleSettlement(
            _artistArtifactCreate(
                "smart-contracts/domains/revenue/StreamPrimarySaleSettlement.sol:StreamPrimarySaleSettlement",
                abi.encode(primaryResolver, address(registry), revenueEscrow)
            )
        );
        D.Configuration memory c;
        c.immediate.manager = manager;
        c.immediate.recorder = companionRecorder;
        c.immediate.artists = IStreamArtistAttribution(address(artists));
        c.immediate.roles = roles;
        c.immediate.authority = address(executor);
        c.immediate.parameters[0] = IStreamGasParameterHost.GasParameterConfig(
            "SALE_ERC1271_GAS_LIMIT", 400000, 350000, 2
        );
        c.immediate.parameters[1] = IStreamGasParameterHost.GasParameterConfig(
            "SALE_ARTIST_AUTHORITY_GAS_LIMIT", 600000, 100000, 2
        );
        c.immediate.parameters[2] = IStreamGasParameterHost.GasParameterConfig(
            "REVEAL_ATTEMPT_GAS_LIMIT", 2000000, 50000, 2
        );
        c.claims.manager = manager;
        c.claims.recorder = companionRecorder;
        c.claims.artists = c.immediate.artists;
        c.claims.roles = roles;
        c.claims.authority = address(executor);
        c.dutch.manager = manager;
        c.dutch.recorder = companionRecorder;
        c.dutch.artists = c.immediate.artists;
        c.dutch.roles = roles;
        c.dutch.authority = address(executor);
        for (uint256 i; i < 3; ++i) {
            c.claims.parameters[i] = c.immediate.parameters[i];
            c.dutch.parameters[i] = c.immediate.parameters[i];
            c.readGas[i] = 500000;
        }
        c.deploymentHash = DEPLOYMENT_HASH;
        c.manifests[0] = D.Manifest(
            keccak256("canonical immediate deployment module"),
            "https://example.org/canonical/immediate.json"
        );
        c.manifests[1] = D.Manifest(
            keccak256("canonical claims deployment module"),
            "https://example.org/canonical/claims.json"
        );
        c.manifests[2] = D.Manifest(
            keccak256("canonical Dutch deployment module"),
            "https://example.org/canonical/dutch.json"
        );
        companionConfiguration = c;
        companionProducts = _deployCanonicalCompanions(c);
        _assertDeployableProductionInstance(address(companionRecorder));
        address[3] memory deployed = D.addresses(companionProducts);
        for (uint256 i; i < deployed.length; ++i) {
            _assertDeployableProductionInstance(deployed[i]);
        }
    }

    function _deployCanonicalCompanions(D.Configuration memory c)
        internal
        virtual
        returns (D.Products memory)
    {
        return D.deploy(c);
    }

    function _additionalOperatingPolicies()
        internal
        view
        virtual
        override
        returns (GovernanceActionPolicyEntry[] memory rows)
    {
        rows = new GovernanceActionPolicyEntry[](7);
        rows[0] = _companionPolicy(
            address(companionProducts.immediate),
            companionProducts.immediate.configureCollectionSigner.selector
        );
        rows[1] = _companionPolicy(
            address(companionProducts.immediate), companionProducts.immediate.registerSale.selector
        );
        rows[2] = _companionPolicy(
            address(companionProducts.claims),
            companionProducts.claims.configureCollectionSigner.selector
        );
        rows[3] = _companionPolicy(
            address(companionProducts.claims), companionProducts.claims.registerSale.selector
        );
        rows[4] = _companionPolicy(
            address(companionProducts.dutch),
            companionProducts.dutch.configureCollectionSigner.selector
        );
        rows[5] = _companionPolicy(
            address(companionProducts.dutch), companionProducts.dutch.registerSale.selector
        );
        rows[6] = _companionPolicy(
            address(companionProducts.immediate),
            companionProducts.immediate.transferOwnership.selector
        );
    }

    function _companionPolicy(address target, bytes4 selector)
        internal
        view
        returns (GovernanceActionPolicyEntry memory)
    {
        return GovernanceActionPolicyEntry(
            1,
            target,
            selector,
            target.codehash,
            keccak256(abi.encode(DEPLOYMENT_HASH, target)),
            1,
            0,
            0,
            0
        );
    }

    function _runCompanionBatch(GenesisBatch memory batch) internal returns (bytes32 id) {
        require(batch.calls.length != 0, "nonempty planned activation");
        uint64 ready;
        (id, ready) = _scheduleBatchAsGovernor(batch.actionClass, batch.calls, batch.callDatas);
        vm.warp(ready);
        this.executeCurrentGovernorCall(
            address(executor),
            abi.encodeCall(executor.executeGovernanceBatch, (id, batch.calls, batch.callDatas))
        );
    }

    function _admitCompanionRecorder() internal {
        StreamModuleRegistration[] memory rows = new StreamModuleRegistration[](1);
        rows[0] = StreamModuleRegistration(
            address(companionRecorder),
            keccak256("PRIMARY_SALE_SETTLEMENT"),
            keccak256("6529STREAM_PREPARED_NATIVE_SETTLEMENT_V1"),
            type(IStreamPreparedNativePrimarySaleSettlement).interfaceId,
            500000,
            address(companionRecorder).codehash,
            DEPLOYMENT_HASH,
            keccak256("canonical companion reused Recorder"),
            "https://example.org/canonical/recorder.json"
        );
        GenesisBatch memory batch;
        batch.actionClass = 1;
        (batch.calls, batch.callDatas) = StreamCurrentStackPlan.registrationCalls(registry, rows);
        _runCompanionBatch(batch);
        require(
            registry.moduleRecord(address(companionRecorder)).status == ModuleRegistryStatus.ACTIVE,
            "actual reused Recorder admission"
        );
    }
}
