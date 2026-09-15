// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./StreamCurrentGovernanceStagePlan.t.sol";
import {
    NativeAuctionArtist,
    NativeAuctionEntropy
} from "../helpers/NativeEnglishAuctionMocks.sol";
import {
    StreamNativeCommerceGovernancePlan
} from "../../script/current/StreamNativeCommerceGovernancePlan.sol";
import {
    StreamNativeCommerceDeployment
} from "../../script/current/StreamNativeCommerceDeployment.sol";
import {
    StreamNativeEnglishAuction
} from "../../smart-contracts/domains/auctions/StreamNativeEnglishAuction.sol";
import {
    IStreamNativeCustodyPrimarySettlement,
    StreamNativeCustodySettlementTypes
} from "../../smart-contracts/interfaces/stream/revenue/IStreamNativeCustodyPrimarySettlement.sol";
import "../../script/current/StreamGovernanceCatalogStagePlan.sol";
import { StreamMintManager } from "../../smart-contracts/domains/mint/StreamMintManager.sol";
import { StreamMintLedger } from "../../smart-contracts/domains/mint/StreamMintLedger.sol";
import {
    StreamAssetPolicyRegistry
} from "../../smart-contracts/domains/revenue/StreamAssetPolicyRegistry.sol";
import { StreamSplitFactory } from "../../smart-contracts/domains/revenue/StreamSplitFactory.sol";
import "../../smart-contracts/domains/revenue/StreamRevenueResolver.sol";
import "../../smart-contracts/domains/revenue/StreamRevenueEscrow.sol";

/// @notice Actual Core, Safe root, Executor, catalog, Registry, Manager and native commerce activation.
/// @dev Artist and entropy semantics remain named test boundaries; no full-finality/testnet claim.
contract StreamNativeCommerceGovernanceTest is StreamCurrentGovernanceStagePlanTest {
    StreamMintManager private manager;
    StreamNativeCommerceDeployment.Products private products;

    function _deployProducts() private {
        _initialize();
        StreamGovernanceGenesisPlan.Configuration memory c = configuration;
        StreamMintLedger ledger = new StreamMintLedger();
        manager = new StreamMintManager(c.core, ledger, IERC165(address(c.registry)));
        StreamAssetPolicyRegistry policy = new StreamAssetPolicyRegistry(address(c.executor));
        IStreamGasParameterHost.GasParameterConfig[3] memory walletGas;
        walletGas[0] =
            IStreamGasParameterHost.GasParameterConfig("ERC_1271_GAS_LIMIT", 400000, 350000, 2);
        walletGas[1] =
            IStreamGasParameterHost.GasParameterConfig("ASSET_POLICY_GAS_LIMIT", 30000, 15000, 2);
        walletGas[2] = IStreamGasParameterHost.GasParameterConfig(
            "WALLET_DEPOSIT_GAS_LIMIT", 500000, 25000, 2
        );
        StreamSplitFactory factory = new StreamSplitFactory(policy, address(c.executor), walletGas);
        NativeAuctionArtist artists = new NativeAuctionArtist(address(c.core), address(manager));
        artists.accept(vm.addr(0x6529101));
        NativeAuctionEntropy entropy = new NativeAuctionEntropy(address(c.core));
        StreamRevenueResolver resolver = new StreamRevenueResolver(
            c.core,
            factory,
            address(c.executor),
            artists,
            IStreamGasParameterHost.GasParameterConfig(
                "ARTIST_BENEFICIARY_READ_GAS", 200000, 50000, 2
            )
        );
        StreamRevenueEscrow escrow = new StreamRevenueEscrow(
            factory,
            address(c.executor),
            IStreamGasParameterHost.GasParameterConfig("FLUSH_GAS_FLOOR", 12000000, 12000000, 3)
        );
        StreamNativeEnglishAuction.DeploymentConfig memory auction;
        auction.manager = manager;
        auction.platform = vm.addr(0x6529102);
        auction.artists = artists;
        auction.entropy = entropy;
        auction.roles = c.roles;
        auction.authority = address(c.executor);
        auction.parameters[0] =
            IStreamGasParameterHost.GasParameterConfig("SALE_ERC1271_GAS_LIMIT", 400000, 350000, 2);
        auction.parameters[1] = IStreamGasParameterHost.GasParameterConfig(
            "SALE_ARTIST_AUTHORITY_GAS_LIMIT", 300000, 50000, 2
        );
        auction.parameters[2] = IStreamGasParameterHost.GasParameterConfig(
            "REVEAL_ATTEMPT_GAS_LIMIT", 200000, 50000, 2
        );
        auction.parameters[3] = IStreamGasParameterHost.GasParameterConfig(
            "SALE_NFT_DELIVERY_GAS_LIMIT", 300000, 100000, 2
        );
        products = StreamNativeCommerceDeployment.deploy(
            resolver,
            c.registry,
            escrow,
            auction,
            c.deploymentHash,
            keccak256("native commerce governance fixture")
        );
        manager.transferOwnership(address(c.executor));
    }

    function _known() private view returns (GovernanceActionPolicyEntry[] memory) {
        (SystemManifestBootstrapBinding memory binding,) = _plan();
        return binding.actionPolicies;
    }

    function _catalogBatch() private returns (GenesisBatch memory batch) {
        GovernanceActionPolicyEntry[] memory additions =
            StreamNativeCommerceGovernancePlan.catalogAdditions(products, _known());
        StreamGovernanceCatalogStagePlan.Inventory memory inventory =
            StreamGovernanceCatalogStagePlan.inventory(configuration.executor, additions);
        StreamSystemManifest.AggregateState memory current =
            StreamGenesisManifestPlan.readAggregate(configuration.manifest);
        (address payload, bytes32 hash) = StreamGenesisManifestPlan.writePayload(
            bytes("{\"purpose\":\"native commerce exact catalog admission\",\"version\":1}")
        );
        StreamSystemManifestUpdate memory update = StreamSystemManifestUpdate(
            hash,
            "urn:6529stream:fixture:native-commerce",
            current.discovery.eventCatalogHash,
            current.discovery.compatibilityMatrixHash,
            current.discovery.numericIdCatalogHash,
            current.discovery.schemaCatalogHash,
            current.discovery.canonicalizationCatalogHash,
            current.discovery.specBundleHash,
            current.discovery.reconstructionClientHash
        );
        uint256 done;
        (batch, done) = StreamGovernanceCatalogStagePlan.nextBatch(
            inventory,
            StreamGovernanceCatalogStagePlan.inventoryHash(inventory),
            0,
            configuration.manifest,
            payload,
            update
        );
        require(done == additions.length && batch.actionClass == 3, "one complete catalog chunk");
    }

    function _executeStage(bytes32 name, GenesisBatch memory batch) private returns (bytes32 id) {
        StreamGovernanceStagePlan.Plan memory plan = this.buildCommerceStage(name, batch);
        id = _schedule(plan);
        require(plan.proposer == address(governor), "actual Safe proposer");
        vm.warp(plan.notBefore);
        require(
            executeSafe(
                governor,
                signers,
                address(configuration.executor),
                0,
                abi.encodeCall(
                    configuration.executor.executeGovernanceBatch,
                    (id, plan.batch.calls, plan.batch.callDatas)
                ),
                0
            ),
            "actual Safe execution"
        );
        require(this.verifySaved(plan, id) == GovernanceActionStatus.EXECUTED, "exact saved action");
        require(
            !this.executeSaved(plan, id), "resumption observes completion without executing twice"
        );
    }

    // External fixture boundaries observe the current block after each warp under IR.
    function buildCommerceStage(bytes32 name, GenesisBatch calldata batch)
        external
        view
        returns (StreamGovernanceStagePlan.Plan memory)
    {
        return _build(name, batch);
    }

    function commerceTime() external view returns (uint256) {
        return block.timestamp;
    }

    function _admitProducts() private {
        _executeStage(keccak256("NATIVE_COMMERCE_CATALOG"), _catalogBatch());
        _executeStage(
            keccak256("NATIVE_COMMERCE_REGISTRATION"),
            StreamNativeCommerceDeployment.admission(products)
        );
    }

    function prepareCustody() external view returns (GenesisBatch memory) {
        return StreamNativeCommerceGovernancePlan.custodyBinding(products);
    }

    function additionsWith(GovernanceActionPolicyEntry[] calldata known)
        external
        view
        returns (GovernanceActionPolicyEntry[] memory)
    {
        return StreamNativeCommerceGovernancePlan.catalogAdditions(products, known);
    }

    function testNativeCommerceSafeCatalogAdmissionManagerAndCustodyBinding() public {
        _deployProducts();
        _admitProducts();
        _executeStage(
            keccak256("NATIVE_COMMERCE_MANAGER"),
            StreamNativeCommerceGovernancePlan.managerBinding(products)
        );
        (address official, bytes32 codeHash,,) = manager.preparedNativeRecorder();
        require(
            official == address(products.recorder) && codeHash == products.recorderCodeHash,
            "actual Executor-owned Manager pin"
        );
        GenesisBatch memory binding = StreamNativeCommerceGovernancePlan.custodyBinding(products);
        require(
            binding.actionClass == 1 && binding.calls[0].value == 0
                && binding.calls[0].selector
                    == IStreamNativeCustodyPrimarySettlement.bindCanonicalCustodyHouse.selector,
            "exact custody policy class selector value"
        );
        bytes32 id = _executeStage(keccak256("NATIVE_COMMERCE_CUSTODY"), binding);
        StreamNativeCustodySettlementTypes.CanonicalHouse memory pin =
            products.recorder.canonicalCustodyHouse();
        require(
            pin.house == address(products.house) && pin.codeHash == products.houseCodeHash
                && pin.revision == 1 && pin.recorderRevision == 1,
            "canonical observed pins"
        );
        require(
            pin.boundAt == this.commerceTime() && pin.recorderBoundAt == this.commerceTime(),
            "execution-time observations survive scheduling delay"
        );
        require(
            configuration.executor.governanceAction(id).actionClass == 1, "actual delayed action"
        );
        products.recorder.requireCanonicalCustodyHouse(address(products.house));
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamNativeCustodyPrimarySettlement.NativeCustodyHouseAlreadyBound.selector
            )
        );
        this.prepareCustody();
    }

    function testNativeCommerceCustodyCannotScheduleBeforeCatalogOrAdmission() public {
        _deployProducts();
        vm.expectRevert();
        this.prepareCustody();
        GenesisBatch memory batch = StreamNativeCommerceDeployment.admission(products);
        StreamGovernanceStagePlan.Plan memory plan =
            this.buildCommerceStage(keccak256("UNADMITTED_COMMERCE"), batch);
        StreamGovernanceStagePlan.NextCall memory publication =
            StreamGovernanceStagePlan.publication(plan, StreamGovernanceStagePlan.planHash(plan));
        require(
            executeSafe(governor, signers, publication.target, 0, publication.data, 0),
            "publish exact unadmitted intent"
        );
        // Escrow is an unadmitted exact target. Root approval cannot bypass the closed catalog.
        StreamGovernanceStagePlan.NextCall memory scheduling =
            StreamGovernanceStagePlan.scheduling(plan, StreamGovernanceStagePlan.planHash(plan));
        bytes32 digest = governor.getTransactionHash(
            scheduling.target,
            0,
            scheduling.data,
            0,
            0,
            0,
            0,
            address(0),
            address(0),
            governor.nonce()
        );
        bytes memory signature = safeThresholdSignature(signers, digest);
        uint256 nonce = governor.nonce();
        vm.expectRevert(bytes("GS013"));
        governor.execTransaction(
            scheduling.target,
            0,
            scheduling.data,
            0,
            0,
            0,
            0,
            address(0),
            payable(address(0)),
            signature
        );
        require(governor.nonce() == nonce, "failed scheduling keeps Safe nonce");
        require(
            uint8(configuration.registry.moduleRecord(address(products.recorder)).status) == 0,
            "no product admission"
        );
    }

    function testNativeCommerceCustodyRequiresExecutorRouteAndActualDelay() public {
        _deployProducts();
        _admitProducts();
        GenesisBatch memory binding = StreamNativeCommerceGovernancePlan.custodyBinding(products);
        bytes memory callData = binding.callDatas[0];
        bytes32 digest = governor.getTransactionHash(
            address(products.recorder),
            0,
            callData,
            0,
            0,
            0,
            0,
            address(0),
            address(0),
            governor.nonce()
        );
        bytes memory signature = safeThresholdSignature(signers, digest);
        uint256 safeNonce = governor.nonce();
        vm.expectRevert(bytes("GS013"));
        governor.execTransaction(
            address(products.recorder),
            0,
            callData,
            0,
            0,
            0,
            0,
            address(0),
            payable(address(0)),
            signature
        );
        require(governor.nonce() == safeNonce, "Safe root is proposer, not target authority");
        StreamGovernanceStagePlan.Plan memory plan =
            this.buildCommerceStage(keccak256("DELAYED_CUSTODY"), binding);
        bytes32 id = _schedule(plan);
        vm.expectRevert();
        this.executeSaved(plan, id);
        require(products.recorder.canonicalCustodyHouse().house == address(0), "no early pin");
        vm.warp(plan.notBefore);
        require(this.executeSaved(plan, id), "same saved delayed binding succeeds");
        products.recorder.requireCanonicalCustodyHouse(address(products.house));
    }

    function testFuzzNativeCommerceExistingCatalogProfileIsRetained(bytes32 originalProfile)
        public
    {
        if (originalProfile == bytes32(0)) return;
        _deployProducts();
        GovernanceActionPolicyEntry[] memory known =
            StreamNativeCommerceGovernancePlan.policies(products);
        bytes32 oldProfile = known[0].targetProfileHash;
        known[0].targetProfileHash = originalProfile;
        require(
            StreamNativeCommerceGovernancePlan.catalogAdditions(products, known).length == 0,
            "existing compatible keys need no rewrite"
        );
        require(known[0].targetProfileHash == originalProfile, "supplied original entry retained");
        known[0].targetProfileHash = oldProfile;
        known[0].valuePolicy = 2;
        known[0].valueLimit = 1;
        vm.expectRevert(
            abi.encodeWithSelector(
                StreamNativeCommerceGovernancePlan.IncompatibleNativeCommercePolicy.selector
            )
        );
        this.additionsWith(known);
    }
}
