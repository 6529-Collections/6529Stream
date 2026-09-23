// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    StreamPrimaryOfferDelegationManifest as Retained
} from "../../../smart-contracts/domains/mint/StreamPrimaryOfferDelegationManifest.sol";
import {
    StreamNativeAuctionDelegation as Delegation
} from "../../../smart-contracts/domains/auctions/StreamNativeAuctionDelegation.sol";
import "../../../smart-contracts/interfaces/stream/modules/IStreamModuleRegistry.sol";
import "../../../smart-contracts/interfaces/stream/revenue/IStreamSaleLifecycleBinding.sol";
import "../../../smart-contracts/interfaces/stream/revenue/IStreamPreparedNativeSaleBinding.sol";
import "../../../smart-contracts/interfaces/stream/revenue/IStreamERC20SaleExecution.sol";
import "../../../smart-contracts/interfaces/stream/revenue/IStreamERC20PrimarySettlementAdapter.sol";

interface RetainedManifestVm {
    function warp(uint256) external;
}

/// @dev Adversarial read-only protocol boundaries for impossible canonical-registry/storage
/// shapes. These fixtures do not prove actual module creation, Safe authority, grants or payment.
contract RetainedManifestRegistryBoundary {
    mapping(address => StreamModuleRecord) private records;
    uint256 public fault;

    function set(address module, StreamModuleRecord memory r) external {
        records[module] = r;
    }

    function setFault(uint256 value) external {
        fault = value;
    }

    function moduleRecord(address module) external view returns (StreamModuleRecord memory r) {
        r = records[module];
        if (fault == 0) return r;
        bytes memory raw = abi.encode(r);
        if (fault == 1) assembly ("memory-safe") { return(add(raw, 32), sub(mload(raw), 32)) }
        if (fault == 2) assembly ("memory-safe") { mstore(add(raw, 32), 64) }
        if (fault == 3) assembly ("memory-safe") { mstore(add(raw, 64), 4) }
        if (fault == 4) assembly ("memory-safe") { mstore(add(raw, 192), shl(32, 1)) }
        if (fault == 5) assembly ("memory-safe") { mstore(add(raw, 320), 416) }
        if (fault == 6) assembly ("memory-safe") { mstore(add(raw, 352), shl(64, 1)) }
        if (fault == 7) assembly ("memory-safe") { mstore(add(raw, 448), 33) }
        assembly ("memory-safe") { return(add(raw, 32), mload(raw)) }
    }
}

contract RetainedManifestHouseBoundary {
    bytes32 private constant SALE = keccak256("original retained unit sale");
    StreamPrimarySettlementTypes.SaleLifecycleBinding private binding;
    uint256 public fault;
    bool public invalidInterface;

    constructor(address payment) {
        binding = StreamPrimarySettlementTypes.SaleLifecycleBinding(payment, 900, 5, 5);
    }

    function setBinding(StreamPrimarySettlementTypes.SaleLifecycleBinding memory value) external {
        binding = value;
    }

    function setFault(uint256 value) external {
        fault = value;
    }

    function setInvalidInterface(bool value) external {
        invalidInterface = value;
    }

    function supportsInterface(bytes4 id) external view returns (bool) {
        if (invalidInterface) return true;
        return id == 0x01ffc9a7 || id == type(IStreamERC20SaleExecution).interfaceId
            || id == type(IStreamPreparedNativeSaleBinding).interfaceId
            || id == type(IStreamERC20PrimarySettlementAdapter).interfaceId;
    }

    function saleLifecycleBinding(bytes32 id)
        external
        view
        returns (StreamPrimarySettlementTypes.SaleLifecycleBinding memory r)
    {
        if (id == SALE) r = binding;
        if (fault == 0) return r;
        bytes memory raw = abi.encode(r);
        if (fault == 1) assembly ("memory-safe") { return(add(raw, 32), 96) }
        if (fault == 2) assembly ("memory-safe") { mstore(add(raw, 32), shl(160, 1)) }
        if (fault == 3) assembly ("memory-safe") { mstore(add(raw, 64), shl(64, 1)) }
        if (fault == 4) assembly ("memory-safe") { mstore(add(raw, 96), shl(64, 1)) }
        if (fault == 5) assembly ("memory-safe") { mstore(add(raw, 128), shl(64, 1)) }
        assembly ("memory-safe") { return(add(raw, 32), mload(raw)) }
    }

    function preparedNativeSaleLifecycle(bytes32 id)
        external
        view
        returns (StreamNativeSettlementTypes.SaleLifecycleBinding memory r)
    {
        if (id == SALE) {
            r = StreamNativeSettlementTypes.SaleLifecycleBinding(
                binding.saleCreatedAt, binding.saleAdapterRegistryRevision
            );
        }
        if (fault == 0) return r;
        bytes memory raw = abi.encode(r);
        if (fault == 1) assembly ("memory-safe") { return(add(raw, 32), 32) }
        if (fault == 2) assembly ("memory-safe") { mstore(add(raw, 32), shl(64, 1)) }
        if (fault == 3) assembly ("memory-safe") { mstore(add(raw, 64), shl(64, 1)) }
        assembly ("memory-safe") { return(add(raw, 32), mload(raw)) }
    }

    function requireNewManifest(Delegation.Configuration memory c) external view {
        Delegation.requireManifest(c, 200000);
    }
}

/// @dev Models the explicit-house linked call from a different carrier/Manager/gate address.
contract RetainedManifestCaller {
    function erc20(Delegation.Configuration memory c, address house, bytes32 id, uint256 cap)
        external
        view
    {
        Retained.requireERC20(c, house, id, cap);
    }

    function nativeOffer(Delegation.Configuration memory c, address house, bytes32 id, uint256 cap)
        external
        view
    {
        Retained.requireNative(c, house, id, cap);
    }
}

contract StreamPrimaryOfferDelegationManifestTest {
    RetainedManifestVm private constant vm =
        RetainedManifestVm(address(uint160(uint256(keccak256("hevm cheat code")))));
    bytes32 private constant SALE = keccak256("original retained unit sale");
    RetainedManifestRegistryBoundary private registry;
    RetainedManifestHouseBoundary private erc20House;
    RetainedManifestHouseBoundary private nativeHouse;
    RetainedManifestHouseBoundary private payment;
    RetainedManifestHouseBoundary private replacement;
    RetainedManifestCaller private caller;
    Delegation.Configuration private config;

    function setUp() public {
        vm.warp(1000);
        registry = new RetainedManifestRegistryBoundary();
        payment = new RetainedManifestHouseBoundary(address(0));
        replacement = new RetainedManifestHouseBoundary(address(0));
        erc20House = new RetainedManifestHouseBoundary(address(payment));
        nativeHouse = new RetainedManifestHouseBoundary(address(0));
        caller = new RetainedManifestCaller();
        config = Delegation.Configuration(
            block.chainid,
            address(0xC0DE),
            address(caller),
            address(caller).codehash,
            2,
            keccak256("original unit declaration"),
            address(registry),
            address(registry).codehash
        );
        registry.set(address(erc20House), _record(address(erc20House), 0));
        registry.set(address(nativeHouse), _record(address(nativeHouse), 1));
        registry.set(address(payment), _record(address(payment), 2));
        registry.set(address(replacement), _record(address(replacement), 2));
    }

    function testRetainedTypedPrimaryOfferReadersNameOriginalHouseAndStoredPayment() public view {
        _acceptBoth();
        require(
            address(caller) != address(erc20House) && address(caller) != address(nativeHouse),
            "distinct worker identity"
        );
    }

    function testGenericNewManifestRemainsActiveOnlyForBothOriginalHouses() public {
        _failure(
            address(erc20House),
            abi.encodeCall(erc20House.requireNewManifest, (config)),
            abi.encodeWithSelector(Delegation.DelegationManifestMismatch.selector)
        );
        _failure(
            address(nativeHouse),
            abi.encodeCall(nativeHouse.requireNewManifest, (config)),
            abi.encodeWithSelector(Delegation.DelegationManifestMismatch.selector)
        );
        StreamModuleRecord memory e = _record(address(erc20House), 0);
        e.status = ModuleRegistryStatus.ACTIVE;
        registry.set(address(erc20House), e);
        erc20House.requireNewManifest(config);
        _acceptBoth();
    }

    function testRetainedTypedReadersRejectUnknownSaleAndNonPriorLifecycle() public {
        _failure(
            address(caller),
            _input(false, config, address(erc20House), bytes32(0), 200000),
            abi.encodeWithSignature(
                "SaleLifecycleMismatch(address,bytes32)", address(erc20House), bytes32(0)
            )
        );
        _failure(
            address(caller),
            _input(true, config, address(nativeHouse), bytes32(0), 200000),
            abi.encodeWithSignature(
                "SaleLifecycleMismatch(address,bytes32)", address(nativeHouse), bytes32(0)
            )
        );
        for (uint256 n; n < 7; ++n) {
            StreamPrimarySettlementTypes.SaleLifecycleBinding memory b = _binding();
            if (n == 0) b.saleCreatedAt = 0;
            if (n == 1) b.saleCreatedAt = 1001;
            if (n == 2) b.saleCreatedAt = 799;
            if (n == 3) b.saleCreatedAt = 1000;
            if (n == 4) b.saleAdapterRegistryRevision = 0;
            if (n == 5) b.saleAdapterRegistryRevision = 8;
            if (n == 6) b.saleAdapterRegistryRevision = 9;
            erc20House.setBinding(b);
            nativeHouse.setBinding(b);
            bool invalidTime = n < 2;
            _failure(
                address(caller),
                _input(false, config, address(erc20House), SALE, 200000),
                invalidTime
                    ? abi.encodeWithSignature(
                        "SaleLifecycleMismatch(address,bytes32)", address(erc20House), SALE
                    )
                    : _notAdmitted(address(erc20House))
            );
            _failure(
                address(caller),
                _input(true, config, address(nativeHouse), SALE, 200000),
                invalidTime
                    ? abi.encodeWithSignature(
                        "SaleLifecycleMismatch(address,bytes32)", address(nativeHouse), SALE
                    )
                    : _notAdmitted(address(nativeHouse))
            );
        }
        erc20House.setBinding(_binding());
        nativeHouse.setBinding(_binding());
        _acceptBoth();
    }

    function testRetainedTypedReadersRejectWrongRoleVersionInterfaceCodeAndLifecycleStatus()
        public
    {
        for (uint256 nativeMode; nativeMode < 2; ++nativeMode) {
            address house = nativeMode == 1 ? address(nativeHouse) : address(erc20House);
            for (uint256 n; n < 12; ++n) {
                StreamModuleRecord memory r = _record(house, nativeMode);
                if (n == 0) r.moduleType = keccak256("wrong role");
                if (n == 1) r.moduleVersion = keccak256("wrong version");
                if (n == 2) r.interfaceId = 0x12345678;
                if (n == 3) r.runtimeCodeHash = keccak256("wrong runtime");
                if (n == 4) r.status = ModuleRegistryStatus.UNKNOWN;
                if (n == 5) r.status = ModuleRegistryStatus.INCIDENT_REVOKED;
                if (n == 6) r.registeredAt = 0;
                if (n == 7) r.registeredAt = 1001;
                if (n == 8) r.statusUpdatedAt = 799;
                if (n == 9) r.statusUpdatedAt = 1001;
                if (n == 10) r.revision = 0;
                if (n == 11) r.deploymentManifestHash = 0;
                registry.set(house, r);
                _failure(
                    address(caller),
                    _input(nativeMode == 1, config, house, SALE, 200000),
                    _notAdmitted(house)
                );
            }
            registry.set(house, _record(house, nativeMode));
        }
        _acceptBoth();
    }

    function testRetainedTypedReadersRequireCompactDeclarationForActualHouse() public {
        for (uint256 nativeMode; nativeMode < 2; ++nativeMode) {
            address house = nativeMode == 1 ? address(nativeHouse) : address(erc20House);
            StreamModuleRecord memory r = _record(house, nativeMode);
            r.moduleManifestHash = _manifest(address(caller));
            registry.set(house, r);
            _failure(
                address(caller),
                _input(nativeMode == 1, config, house, SALE, 200000),
                abi.encodeWithSelector(Delegation.DelegationManifestMismatch.selector)
            );
            registry.set(house, _record(house, nativeMode));
        }
        _acceptBoth();
    }

    function testRetainedERC20CannotBorrowHealthyReplacementPaymentAdmission() public {
        StreamModuleRecord memory r = _record(address(payment), 2);
        r.status = ModuleRegistryStatus.INCIDENT_REVOKED;
        registry.set(address(payment), r);
        _failure(
            address(caller),
            _input(false, config, address(erc20House), SALE, 200000),
            _notAdmitted(address(payment))
        );
        require(
            registry.moduleRecord(address(replacement)).status == ModuleRegistryStatus.ACTIVE,
            "additional admitted Payment cannot replace stored original"
        );
        registry.set(address(payment), _record(address(payment), 2));
        for (uint256 n; n < 4; ++n) {
            StreamPrimarySettlementTypes.SaleLifecycleBinding memory b = _binding();
            if (n == 0) b.paymentAdapter = address(0);
            if (n == 1) b.paymentAdapterRegistryRevision = 0;
            if (n == 2) b.paymentAdapterRegistryRevision = 9;
            if (n == 3) {
                r = _record(address(payment), 2);
                r.status = ModuleRegistryStatus.DEPRECATED;
                r.statusUpdatedAt = b.saleCreatedAt;
                registry.set(address(payment), r);
            }
            erc20House.setBinding(b);
            _failure(
                address(caller),
                _input(false, config, address(erc20House), SALE, 200000),
                _notAdmitted(b.paymentAdapter)
            );
        }
        registry.set(address(payment), _record(address(payment), 2));
        erc20House.setBinding(_binding());
        _acceptBoth();
    }

    function testRetainedTypedReadersRejectMalformedLifecycleLengthsAndWidths() public {
        for (uint256 n = 1; n <= 5; ++n) {
            erc20House.setFault(n);
            _failure(
                address(caller),
                _input(false, config, address(erc20House), SALE, 200000),
                abi.encodeWithSignature(
                    "SaleLifecycleReadMalformed(address,uint256)",
                    address(erc20House),
                    n == 1 ? uint256(96) : uint256(128)
                )
            );
        }
        erc20House.setFault(0);
        for (uint256 n = 1; n <= 3; ++n) {
            nativeHouse.setFault(n);
            _failure(
                address(caller),
                _input(true, config, address(nativeHouse), SALE, 200000),
                abi.encodeWithSignature(
                    "SaleLifecycleReadMalformed(address,uint256)",
                    address(nativeHouse),
                    n == 1 ? uint256(32) : uint256(64)
                )
            );
        }
        nativeHouse.setFault(0);
        _acceptBoth();
    }

    function testRetainedTypedReadersRejectMalformedRegistryHeaderWithoutDynamicAllocation()
        public
    {
        for (uint256 n = 1; n <= 7; ++n) {
            registry.setFault(n);
            uint256 size = n == 1 ? 448 : 480;
            _failure(
                address(caller),
                _input(false, config, address(erc20House), SALE, 200000),
                abi.encodeWithSignature(
                    "SettlementModuleReadMalformed(address,uint256)", address(erc20House), size
                )
            );
            _failure(
                address(caller),
                _input(true, config, address(nativeHouse), SALE, 200000),
                abi.encodeWithSignature(
                    "SettlementModuleReadMalformed(address,uint256)", address(nativeHouse), size
                )
            );
        }
        registry.setFault(0);
        _acceptBoth();
    }

    function testRetainedTypedReadersPreserveOriginalConfigurationAndExactERC165Rules() public {
        Delegation.Configuration memory c = config;
        c.chainId += 1;
        _failBoth(c, abi.encodeWithSelector(Delegation.DelegationConfigurationInvalid.selector));
        c = config;
        c.delegateRegistryCodeHash = keccak256("wrong original provider");
        _failBoth(
            c,
            abi.encodeWithSelector(
                Delegation.DelegationRegistryUnavailable.selector, c.delegateRegistry
            )
        );
        c = config;
        c.moduleRegistryCodeHash = keccak256("wrong module registry");
        _failBoth(c, abi.encodeWithSelector(Delegation.DelegationConfigurationInvalid.selector));
        erc20House.setInvalidInterface(true);
        nativeHouse.setInvalidInterface(true);
        _failure(
            address(caller),
            _input(false, config, address(erc20House), SALE, 200000),
            _notAdmitted(address(erc20House))
        );
        _failure(
            address(caller),
            _input(true, config, address(nativeHouse), SALE, 200000),
            _notAdmitted(address(nativeHouse))
        );
        erc20House.setInvalidInterface(false);
        nativeHouse.setInvalidInterface(false);
        _acceptBoth();
    }

    function testRetainedManifestReadGasIsBoundedAfterTypedAdmission() public {
        for (uint256 n; n < 2; ++n) {
            bool nativeMode = n == 1;
            address house = nativeMode ? address(nativeHouse) : address(erc20House);
            (bool ok, bytes memory reason) =
                address(caller).staticcall(_input(nativeMode, config, house, SALE, 0));
            require(
                !ok && reason.length == 68
                    && bytes4(reason) == Delegation.DelegationReadGas.selector,
                "zero manifest cap cannot use available-gas fallback"
            );
            _failure(
                address(caller),
                _input(nativeMode, config, house, SALE, 1),
                abi.encodeWithSelector(Delegation.DelegationReadFailed.selector, address(registry))
            );
        }
        _acceptBoth();
    }

    function _record(address module, uint256 kind)
        private
        view
        returns (StreamModuleRecord memory r)
    {
        r.status = kind == 2 ? ModuleRegistryStatus.ACTIVE : ModuleRegistryStatus.DEPRECATED;
        r.moduleType = kind == 0
            ? keccak256("FIXED_PRICE_SALE_ADAPTER")
            : kind == 1
                ? keccak256("NATIVE_PREPARED_SALE_ADAPTER")
                : keccak256("ERC20_PRIMARY_SETTLEMENT_ADAPTER");
        r.moduleVersion = kind == 1
            ? keccak256("6529STREAM_PREPARED_NATIVE_SETTLEMENT_V1")
            : keccak256("6529STREAM_UNIVERSAL_SETTLEMENT_V1");
        r.interfaceId = kind == 0
            ? type(IStreamERC20SaleExecution).interfaceId
            : kind == 1
                ? type(IStreamPreparedNativeSaleBinding).interfaceId
                : type(IStreamERC20PrimarySettlementAdapter).interfaceId;
        r.runtimeCodeHash = module.codehash;
        r.deploymentManifestHash = keccak256("original deployment");
        r.moduleManifestHash = _manifest(module);
        r.moduleManifestURI = "original";
        r.registeredAt = 800;
        r.statusUpdatedAt = 1000;
        r.revision = 8;
    }

    function _manifest(address house) private view returns (bytes32) {
        return keccak256(
            abi.encode(
                keccak256("6529STREAM_NATIVE_AUCTION_NFTDELEGATION_MANIFEST_V1"),
                config.chainId,
                house,
                config.baseManifestHash,
                config.core,
                config.delegateRegistry,
                config.delegateRegistryCodeHash,
                config.delegationUsecase
            )
        );
    }

    function _binding()
        private
        view
        returns (StreamPrimarySettlementTypes.SaleLifecycleBinding memory)
    {
        return StreamPrimarySettlementTypes.SaleLifecycleBinding(address(payment), 900, 5, 5);
    }

    function _input(
        bool nativeMode,
        Delegation.Configuration memory c,
        address house,
        bytes32 id,
        uint256 cap
    ) private pure returns (bytes memory) {
        return nativeMode
            ? abi.encodeCall(RetainedManifestCaller.nativeOffer, (c, house, id, cap))
            : abi.encodeCall(RetainedManifestCaller.erc20, (c, house, id, cap));
    }

    function _failure(address target, bytes memory input, bytes memory expected) private view {
        (bool ok, bytes memory reason) = target.staticcall(input);
        require(
            !ok && keccak256(reason) == keccak256(expected),
            "exact retained-manifest reader refusal"
        );
    }

    function _notAdmitted(address module) private pure returns (bytes memory) {
        return abi.encodeWithSignature("SettlementModuleNotAdmitted(address)", module);
    }

    function _acceptBoth() private view {
        caller.erc20(config, address(erc20House), SALE, 200000);
        caller.nativeOffer(config, address(nativeHouse), SALE, 200000);
    }

    function _failBoth(Delegation.Configuration memory c, bytes memory expected) private view {
        _failure(address(caller), _input(false, c, address(erc20House), SALE, 200000), expected);
        _failure(address(caller), _input(true, c, address(nativeHouse), SALE, 200000), expected);
    }
}
