// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../../smart-contracts/domains/auctions/StreamNativeEnglishAuction.sol";
import "../../smart-contracts/domains/revenue/StreamPrimarySaleSettlement.sol";
import "../../smart-contracts/interfaces/stream/mint/IStreamPreparedNativeMint.sol";
import "./StreamCurrentStackPlan.sol";
import "../../smart-contracts/interfaces/stream/governance/IStreamGenesisInitializer.sol";

/// @notice Native commerce deployment and admission for an existing current contract graph.
/// @dev Deployments do not register products, grant phase execution or consume artist consent.
///      Persist the returned coordinates; build admission only against observed live state.
library StreamNativeCommerceDeployment {
    error InvalidNativeCommerceDeployment();
    error NativeCommerceRuntimeChanged();

    struct Products {
        uint256 chainId;
        StreamPrimarySaleSettlement recorder;
        StreamNativeEnglishAuction house;
        bytes32 recorderCodeHash;
        bytes32 houseCodeHash;
        bytes32 deploymentManifestHash;
        bytes32 moduleManifestHash;
        bytes32 houseModuleManifestHash;
    }

    /// @notice Deploy a matched official recorder and auction against existing dependencies.
    /// @dev A nonzero nominated recorder is rejected: this operation creates its own exact pair.
    function deploy(
        IStreamRevenueResolver resolver,
        StreamModuleRegistry registry,
        IStreamRevenueEscrow escrow,
        StreamNativeEnglishAuction.DeploymentConfig memory config,
        bytes32 deploymentManifestHash,
        bytes32 moduleManifestHash
    ) internal returns (Products memory products) {
        if (
            address(config.recorder) != address(0) || deploymentManifestHash == bytes32(0)
                || moduleManifestHash == bytes32(0)
        ) revert InvalidNativeCommerceDeployment();
        (address bound,,,) =
            IStreamPreparedNativeMint(address(config.manager)).preparedNativeRecorder();
        if (bound != address(0)) revert InvalidNativeCommerceDeployment();
        StreamPrimarySaleSettlement recorder =
            new StreamPrimarySaleSettlement(resolver, address(registry), escrow);
        config.recorder = recorder;
        StreamNativeEnglishAuction house = new StreamNativeEnglishAuction(config);
        products = Products(
            block.chainid,
            recorder,
            house,
            address(recorder).codehash,
            address(house).codehash,
            deploymentManifestHash,
            moduleManifestHash,
            config.delegateRegistry == address(0)
                ? moduleManifestHash
                : keccak256(house.delegationManifest())
        );
        validate(products);
    }

    /// @notice Authenticate saved live products before generating or using admission plans.
    function validate(Products memory products) internal view {
        address recorder = address(products.recorder);
        address house = address(products.house);
        if (
            products.chainId != block.chainid || products.deploymentManifestHash == bytes32(0)
                || products.moduleManifestHash == bytes32(0) || recorder.code.length == 0
                || house.code.length == 0 || recorder.code.length > 24_576
                || house.code.length > 24_576 || recorder.codehash != products.recorderCodeHash
                || house.codehash != products.houseCodeHash
        ) revert NativeCommerceRuntimeChanged();
        if (
            products.house.primarySaleSettlement() != recorder
                || products.house.settlementCodeHash() != products.recorderCodeHash
                || products.house.core() != products.recorder.core()
                || products.house.moduleRegistry() != products.recorder.moduleRegistry()
                || address(products.house.revenueResolver())
                    != address(products.recorder.revenueResolver())
        ) {
            revert InvalidNativeCommerceDeployment();
        }
        _validateDependencies(products);
    }

    function _validateDependencies(Products memory products) private view {
        StreamPrimarySaleSettlement recorder = products.recorder;
        StreamNativeEnglishAuction house = products.house;
        StreamSettlementAdmission.requireRegistry(
            recorder.core(),
            recorder.coreCodeHash(),
            recorder.moduleRegistry(),
            recorder.moduleRegistryCodeHash()
        );
        _pin(address(recorder.revenueResolver()), recorder.resolverCodeHash());
        _pin(address(recorder.splitFactory()), recorder.factoryCodeHash());
        _pin(address(recorder.assetPolicyRegistry()), recorder.assetRegistryCodeHash());
        _pin(address(recorder.revenueEscrow()), recorder.escrowCodeHash());
        _pin(address(house.mintManager()), house.mintManagerCodeHash());
        _pin(address(house.artistRegistry()), house.artistRegistryCodeHash());
        _pin(address(house.entropyCoordinator()), house.entropyCodeHash());
        _pin(address(house.roleRegistry()), house.roleRegistryCodeHash());
        if (house.delegateRegistry() != address(0)) {
            _pin(house.delegateRegistry(), house.delegateRegistryCodeHash());
        }
        bytes32 expected = house.delegateRegistry() == address(0)
            ? products.moduleManifestHash
            : keccak256(house.delegationManifest());
        if (products.houseModuleManifestHash != expected) revert InvalidNativeCommerceDeployment();
    }

    function _pin(address target, bytes32 codeHash) private view {
        if (!StreamSettlementAdmission.isContract(target) || target.codehash != codeHash) {
            revert NativeCommerceRuntimeChanged();
        }
    }

    function registrations(Products memory products)
        internal
        view
        returns (StreamModuleRegistration[] memory rows)
    {
        validate(products);
        rows = new StreamModuleRegistration[](2);
        bytes32 version = keccak256("6529STREAM_PREPARED_NATIVE_SETTLEMENT_V1");
        rows[0] = StreamModuleRegistration(
            address(products.recorder),
            keccak256("PRIMARY_SALE_SETTLEMENT"),
            version,
            type(IStreamPreparedNativePrimarySaleSettlement).interfaceId,
            500_000,
            products.recorderCodeHash,
            products.deploymentManifestHash,
            products.moduleManifestHash,
            "urn:6529stream:native-commerce:recorder:v1"
        );
        rows[1] = StreamModuleRegistration(
            address(products.house),
            keccak256("NATIVE_PREPARED_SALE_ADAPTER"),
            version,
            type(IStreamPreparedNativeSaleBinding).interfaceId,
            500_000,
            products.houseCodeHash,
            products.deploymentManifestHash,
            products.houseModuleManifestHash,
            "urn:6529stream:native-commerce:auction:v1"
        );
    }

    /// @notice Class 1 plan: register both originals, then admit the recorder as escrow producer.
    /// @dev Schedule through normal governance after the catalog admits the exact target rows.
    ///      Rebuild only before scheduling; execute saved calldata after the normal delay.
    function admission(Products memory products) internal view returns (GenesisBatch memory batch) {
        StreamModuleRegistry registry =
            StreamModuleRegistry(payable(products.recorder.moduleRegistry()));
        (GovernanceCall[] memory calls, bytes[] memory data) =
            StreamCurrentStackPlan.registrationCalls(registry, registrations(products));
        batch.actionClass = 1;
        batch.calls = new GovernanceCall[](3);
        batch.callDatas = new bytes[](3);
        for (uint256 i; i < 2; ++i) {
            batch.calls[i] = calls[i];
            batch.callDatas[i] = data[i];
        }
        IStreamRevenueEscrow escrow = products.recorder.revenueEscrow();
        (bytes32 scope, bytes32 oldHash, bytes32 newHash) =
            escrow.creditProducerTransitionHashes(address(products.recorder), true);
        batch.callDatas[2] =
            abi.encodeCall(escrow.setCreditProducer, (address(products.recorder), true));
        batch.calls[2] = StreamCurrentStackPlan.call(
            address(escrow), batch.callDatas[2], scope, oldHash, newHash
        );
    }

    /// @notice Exact policy intents; subtract existing matching rows before catalog extension.
    /// @dev Entries do not grant ownership, roles or execution rights by themselves.
    function policies(Products memory products)
        internal
        view
        returns (GovernanceActionPolicyEntry[] memory rows)
    {
        validate(products);
        rows = new GovernanceActionPolicyEntry[](4);
        rows[0] = _policy(
            products,
            products.recorder.moduleRegistry(),
            StreamModuleRegistry.registerModule.selector
        );
        rows[1] = _policy(
            products,
            address(products.recorder.revenueEscrow()),
            IStreamRevenueEscrow.setCreditProducer.selector
        );
        rows[2] = _policy(
            products,
            address(products.house.mintManager()),
            IStreamPreparedNativeMint.bindPreparedNativeRecorder.selector
        );
        rows[3] = _policy(
            products, address(products.house), IStreamGasParameterHost.raiseGasParameter.selector
        );
        for (uint256 i = 1; i < rows.length; ++i) {
            for (uint256 j = i; j > 0 && _key(rows[j - 1]) > _key(rows[j]); --j) {
                (rows[j - 1], rows[j]) = (rows[j], rows[j - 1]);
            }
        }
    }

    /// @notice Owner binding after the exact recorder is admitted and enabled for escrow credit.
    /// @dev An actual Safe owner executes this calldata as a Safe transaction. If the
    ///      Executor owns Manager, its authorized Safe proposer uses the governed Executor route.
    function managerBinding(Products memory products)
        internal
        view
        returns (address target, bytes memory data)
    {
        validate(products);
        StreamModuleRegistry registry =
            StreamModuleRegistry(payable(products.recorder.moduleRegistry()));
        StreamModuleRecord memory record = registry.moduleRecord(address(products.recorder));
        StreamModuleRegistration[] memory expected = registrations(products);
        if (
            record.status != ModuleRegistryStatus.ACTIVE
                || record.moduleType != expected[0].moduleType
                || record.moduleVersion != expected[0].moduleVersion
                || record.interfaceId != expected[0].interfaceId
                || record.runtimeCodeHash != products.recorderCodeHash
                || record.moduleManifestHash != products.moduleManifestHash
                || record.deploymentManifestHash != products.deploymentManifestHash
        ) {
            revert InvalidNativeCommerceDeployment();
        }
        (bool enabled, bytes32 codeHash,) =
            products.recorder.revenueEscrow().creditProducer(address(products.recorder));
        if (!enabled || codeHash != products.recorderCodeHash) {
            revert InvalidNativeCommerceDeployment();
        }
        target = address(products.house.mintManager());
        (address bound,,,) = IStreamPreparedNativeMint(target).preparedNativeRecorder();
        if (bound != address(0)) revert InvalidNativeCommerceDeployment();
        data = abi.encodeCall(
            IStreamPreparedNativeMint.bindPreparedNativeRecorder, (address(products.recorder))
        );
    }

    function _policy(Products memory products, address target, bytes4 selector)
        private
        view
        returns (GovernanceActionPolicyEntry memory)
    {
        return GovernanceActionPolicyEntry(
            1,
            target,
            selector,
            target.codehash,
            keccak256(abi.encode(products.deploymentManifestHash, target)),
            1,
            0,
            0,
            bytes32(0)
        );
    }

    function _key(GovernanceActionPolicyEntry memory row) private pure returns (bytes32) {
        return keccak256(abi.encode(row.actionClass, row.target, row.selector));
    }
}
