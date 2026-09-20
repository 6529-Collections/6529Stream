// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    StreamPrivateSaleOfferDelegation as RetainedSecondary
} from "../../../smart-contracts/domains/mint/StreamPrivateSaleOfferDelegation.sol";
import {
    StreamPrivateSaleSupport as Support
} from "../../../smart-contracts/domains/mint/StreamPrivateSaleSupport.sol";
import {
    StreamNativeAuctionDelegation as Delegate
} from "../../../smart-contracts/domains/auctions/StreamNativeAuctionDelegation.sol";
import {
    IStreamPrivateSaleAdapter as PrivateSale
} from "../../../smart-contracts/interfaces/stream/mint/IStreamPrivateSaleAdapter.sol";
import "../../../smart-contracts/interfaces/stream/modules/IStreamModuleRegistry.sol";

interface SecondaryManifestVm {
    function warp(uint256) external;
}

/// @dev Synthetic self-lifecycle and registry/Core-pointer readers isolate malformed facts.
/// No actual current deployment, signed authority, transfer or settlement is represented here.
contract SecondaryManifestRegistryBoundary {
    StreamModuleRecord private record;

    function set(StreamModuleRecord memory r) external {
        record = r;
    }

    function moduleRecord(address) external view returns (StreamModuleRecord memory) {
        return record;
    }
}

contract SecondaryManifestCoreBoundary {
    address private immutable registry;

    constructor(address target) {
        registry = target;
    }

    function getSatellitePointer(bytes32)
        external
        view
        returns (address, bytes32, bool, bytes32, bytes4, address, uint8, bytes32, bytes32, uint64)
    {
        return (
            registry,
            registry.codehash,
            false,
            keccak256("MODULE_REGISTRY"),
            type(IStreamModuleRegistry).interfaceId,
            registry,
            1,
            keccak256("original config"),
            keccak256("original manifest"),
            1
        );
    }
}

contract SecondaryManifestHostBoundary {
    bytes32 private constant SALE = keccak256("original secondary offer");
    uint256 public createdAt = 900;
    uint256 public revision = 5;
    uint256 public length = 64;
    bool public interfaceEnabled = true;

    function set(uint256 created, uint256 rev, uint256 size) external {
        createdAt = created;
        revision = rev;
        length = size;
    }

    function setInterface(bool enabled) external {
        interfaceEnabled = enabled;
    }

    function supportsInterface(bytes4 id) external view returns (bool) {
        return interfaceEnabled && (id == 0x01ffc9a7 || id == type(PrivateSale).interfaceId);
    }

    function custodySaleLifecycle(bytes32 id) external view returns (uint64, uint64) {
        uint256[3] memory words;
        if (id == SALE) {
            words[0] = createdAt;
            words[1] = revision;
        }
        uint256 size = length;
        assembly ("memory-safe") { return(words, size) }
    }

    function retained(
        Support.Context memory x,
        Delegate.Configuration memory c,
        bytes32 id,
        uint256 cap
    ) external view {
        RetainedSecondary.requireRetained(x, c, id, cap);
    }

    function fresh(Delegate.Configuration memory c) external view {
        Delegate.requireManifest(c, 200000);
    }
}

contract StreamPrivateSaleOfferDelegationTest {
    SecondaryManifestVm private constant vm =
        SecondaryManifestVm(address(uint160(uint256(keccak256("hevm cheat code")))));
    bytes32 private constant SALE = keccak256("original secondary offer");
    SecondaryManifestRegistryBoundary private registry;
    SecondaryManifestCoreBoundary private core;
    SecondaryManifestHostBoundary private host;
    Support.Context private context;
    Delegate.Configuration private configuration;

    function setUp() public {
        vm.warp(1000);
        registry = new SecondaryManifestRegistryBoundary();
        core = new SecondaryManifestCoreBoundary(address(registry));
        host = new SecondaryManifestHostBoundary();
        context = Support.Context(
            address(core), address(registry), address(core).codehash, address(registry).codehash
        );
        configuration = Delegate.Configuration(
            block.chainid,
            address(core),
            address(core),
            address(core).codehash,
            2,
            keccak256("secondary original manifest"),
            address(registry),
            address(registry).codehash
        );
        registry.set(_record());
    }

    function testSecondaryRetainedManifestUsesOriginalConsignmentRoleAndActiveNewAdmission()
        public
    {
        _accept();
        _fails(
            abi.encodeCall(host.fresh, (configuration)),
            abi.encodeWithSelector(Delegate.DelegationManifestMismatch.selector)
        );
        StreamModuleRecord memory r = _record();
        r.status = ModuleRegistryStatus.ACTIVE;
        registry.set(r);
        host.fresh(configuration);
        _accept();
    }

    function testSecondaryRetainedManifestNeverUsesZeroLifecycleAsNewRegistrationSentinel() public {
        StreamModuleRecord memory r = _record();
        r.status = ModuleRegistryStatus.ACTIVE;
        registry.set(r);
        _fails(_input(context, configuration, bytes32(0), 200000), _notAdmitted());
        host.set(0, 0, 64);
        _fails(_input(context, configuration, SALE, 200000), _notAdmitted());
        host.set(0, 5, 64);
        _fails(_input(context, configuration, SALE, 200000), _notAdmitted());
        host.set(900, 0, 64);
        _fails(_input(context, configuration, SALE, 200000), _notAdmitted());
        host.set(900, 5, 64);
        _accept();
    }

    function testSecondaryRetainedManifestRejectsNoncanonicalAndNonPriorLifecycle() public {
        for (uint256 n; n < 10; ++n) {
            uint256 time = 900;
            uint256 rev = 5;
            uint256 size = 64;
            if (n == 0) size = 32;
            if (n == 1) size = 96;
            if (n == 2) time = uint256(type(uint64).max) + 1;
            if (n == 3) rev = uint256(type(uint64).max) + 1;
            if (n == 4) time = 1001;
            if (n == 5) time = 799;
            if (n == 6) time = 1000;
            if (n == 7) rev = 0;
            if (n == 8) rev = 8;
            if (n == 9) rev = 9;
            host.set(time, rev, size);
            _fails(_input(context, configuration, SALE, 200000), _notAdmitted());
        }
        host.set(900, 5, 64);
        _accept();
    }

    function testSecondaryRetainedManifestRejectsPrimaryRolesAndOriginalRegistryFaults() public {
        for (uint256 n; n < 12; ++n) {
            StreamModuleRecord memory r = _record();
            if (n == 0) r.moduleType = keccak256("NATIVE_PREPARED_SALE_ADAPTER");
            if (n == 1) r.moduleType = keccak256("FIXED_PRICE_SALE_ADAPTER");
            if (n == 2) r.moduleVersion = keccak256("6529STREAM_PREPARED_NATIVE_SETTLEMENT_V1");
            if (n == 3) r.interfaceId = 0x12345678;
            if (n == 4) r.runtimeCodeHash = keccak256("different live code");
            if (n == 5) r.status = ModuleRegistryStatus.INCIDENT_REVOKED;
            if (n == 6) r.status = ModuleRegistryStatus.UNKNOWN;
            if (n == 7) r.registeredAt = 0;
            if (n == 8) r.statusUpdatedAt = 799;
            if (n == 9) r.statusUpdatedAt = 1001;
            if (n == 10) r.revision = 0;
            if (n == 11) r.deploymentManifestHash = 0;
            registry.set(r);
            _fails(_input(context, configuration, SALE, 200000), _notAdmitted());
        }
        registry.set(_record());
        host.setInterface(false);
        _fails(_input(context, configuration, SALE, 200000), _notAdmitted());
        host.setInterface(true);
        _accept();
    }

    function testSecondaryRetainedManifestBindsOriginalContextAndActualHostDeclaration() public {
        Delegate.Configuration memory c = configuration;
        c.core = address(host);
        _fails(
            _input(context, c, SALE, 200000),
            abi.encodeWithSelector(Delegate.DelegationConfigurationInvalid.selector)
        );
        c = configuration;
        c.moduleRegistry = address(host);
        _fails(
            _input(context, c, SALE, 200000),
            abi.encodeWithSelector(Delegate.DelegationConfigurationInvalid.selector)
        );
        c = configuration;
        c.delegateRegistryCodeHash = keccak256("substituted provider code");
        _fails(
            _input(context, c, SALE, 200000),
            abi.encodeWithSelector(Delegate.DelegationRegistryUnavailable.selector, address(core))
        );
        Support.Context memory x = context;
        x.coreCodeHash = keccak256("substituted original Core pin");
        _fails(
            _input(x, configuration, SALE, 200000),
            abi.encodeWithSignature("SettlementBindingInvalid(address)", address(core))
        );
        StreamModuleRecord memory r = _record();
        r.moduleManifestHash = _manifest(address(this));
        registry.set(r);
        _fails(
            _input(context, configuration, SALE, 200000),
            abi.encodeWithSelector(Delegate.DelegationManifestMismatch.selector)
        );
        registry.set(_record());
        _accept();
    }

    function testSecondaryRetainedManifestKeepsGovernedCapWithoutAvailableGasFallback() public {
        (bool ok, bytes memory reason) =
            address(host).staticcall(_input(context, configuration, SALE, 0));
        require(
            !ok && reason.length == 68 && bytes4(reason) == Delegate.DelegationReadGas.selector,
            "zero delegation cap refuses"
        );
        _fails(
            _input(context, configuration, SALE, 1),
            abi.encodeWithSelector(Delegate.DelegationReadFailed.selector, address(registry))
        );
        _accept();
    }

    function _record() private view returns (StreamModuleRecord memory r) {
        r.status = ModuleRegistryStatus.DEPRECATED;
        r.moduleType = keccak256("PRIVATE_SALE_ADAPTER");
        r.moduleVersion = keccak256("6529STREAM_NATIVE_CONSIGNMENT_V1");
        r.interfaceId = type(PrivateSale).interfaceId;
        r.runtimeCodeHash = address(host).codehash;
        r.deploymentManifestHash = keccak256("original deployment");
        r.moduleManifestHash = _manifest(address(host));
        r.moduleManifestURI = "original secondary";
        r.registeredAt = 800;
        r.statusUpdatedAt = 1000;
        r.revision = 8;
    }

    function _manifest(address actualHost) private view returns (bytes32) {
        return keccak256(
            abi.encode(
                keccak256("6529STREAM_NATIVE_AUCTION_NFTDELEGATION_MANIFEST_V1"),
                configuration.chainId,
                actualHost,
                configuration.baseManifestHash,
                configuration.core,
                configuration.delegateRegistry,
                configuration.delegateRegistryCodeHash,
                configuration.delegationUsecase
            )
        );
    }

    function _input(
        Support.Context memory x,
        Delegate.Configuration memory c,
        bytes32 id,
        uint256 cap
    ) private pure returns (bytes memory) {
        return abi.encodeCall(SecondaryManifestHostBoundary.retained, (x, c, id, cap));
    }

    function _notAdmitted() private pure returns (bytes memory) {
        return abi.encodeWithSelector(PrivateSale.PrivateSaleModuleNotAdmitted.selector);
    }

    function _fails(bytes memory input, bytes memory expected) private view {
        (bool ok, bytes memory reason) = address(host).staticcall(input);
        require(
            !ok && keccak256(reason) == keccak256(expected),
            "exact secondary retained-manifest refusal"
        );
    }

    function _accept() private view {
        host.retained(context, configuration, SALE, 200000);
    }
}
