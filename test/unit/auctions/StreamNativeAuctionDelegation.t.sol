// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../../../smart-contracts/domains/auctions/StreamNativeAuctionDelegation.sol";
import "../../../smart-contracts/integrations/delegation/NFTdelegation.sol";
import "../../../smart-contracts/domains/modules/StreamModuleRegistry.sol";
import "../../helpers/GovernedParameterTestMocks.sol";

interface AuctionDelegationVm {
    function warp(uint256) external;
    function prank(address) external;
    function etch(address, bytes calldata) external;
}

/// @dev Real registry and delegation state; only auction effects and governance context are
/// isolated here. The queued actual auction capture does not yet use this helper.
contract AuctionDelegationHarness {
    StreamNativeAuctionDelegation.Configuration private _configuration;
    mapping(bytes32 => mapping(address => address)) private _bindings;
    uint256 public successfulBindings;

    constructor(StreamNativeAuctionDelegation.Configuration memory c) {
        _configuration = c;
        StreamNativeAuctionDelegation.validateConfiguration(c);
    }

    function supportsInterface(bytes4 id) external pure returns (bool) {
        return id == 0x01ffc9a7 || id == 0x12345678;
    }

    function declaration() external view returns (bytes memory) {
        return StreamNativeAuctionDelegation.manifestBytes(_configuration);
    }

    function bind(bytes32 id, address recipient, bool walletWide, uint256 index, uint256 cap)
        external
        returns (address bound)
    {
        bound = StreamNativeAuctionDelegation.resolveDelivery(
            _bindings,
            _configuration,
            id,
            msg.sender,
            recipient,
            StreamNativeAuctionDelegation.Witness(walletWide, index),
            cap
        );
        _bindings[id][msg.sender] = bound;
        ++successfulBindings;
    }

    function bound(bytes32 id, address bidder) external view returns (address) {
        return _bindings[id][bidder];
    }

    function claim(address account, address to, bool walletWide, uint256 index, uint256 cap)
        external
        view
        returns (address)
    {
        return StreamNativeAuctionDelegation.claimRecipient(
            _configuration,
            account,
            msg.sender,
            to,
            StreamNativeAuctionDelegation.Witness(walletWide, index),
            cap
        );
    }

    function requireRow(
        address vault,
        address delegate,
        bool walletWide,
        uint256 index,
        uint256 cap
    ) external view {
        StreamNativeAuctionDelegation.requireDelegated(
            _configuration,
            vault,
            delegate,
            StreamNativeAuctionDelegation.Witness(walletWide, index),
            cap
        );
    }
}

contract AuctionDelegationMalformedRegistry {
    uint256[6] private _row;
    uint256 private _length;
    uint256 private _mode;

    function set(uint256[6] calldata row, uint256 length, uint256 mode) external {
        _row = row;
        _length = length;
        _mode = mode;
    }

    fallback() external {
        if (_mode == 1) revert("unavailable");
        if (_mode == 2) assembly { invalid() }
        uint256[6] memory row = _row;
        uint256 length = _length;
        // Extra bytes are deliberately returned for the hostile oversized-returndata control.
        bytes memory raw = new bytes(length > 192 ? length : 192);
        assembly ("memory-safe") {
            for { let j := 0 } lt(j, 192) { j := add(j, 32) } { mstore(
                add(add(raw, 32), j),
                mload(add(row, j))
            ) }
            return(add(raw, 32), length)
        }
    }
}

contract StreamNativeAuctionDelegationTest {
    AuctionDelegationVm private constant vm =
        AuctionDelegationVm(address(uint160(uint256(keccak256("hevm cheat code")))));
    address private constant CORE = address(0xC012E);
    address private constant VAULT = address(0xA11CE);
    address private constant BIDDER = address(0xB1D);
    address private constant OTHER = address(0xBEEF);
    address private constant ALL = 0x8888888888888888888888888888888888888888;
    bytes32 private constant ID = keccak256("auction");
    bytes32 private constant MANIFEST = keccak256("delegation fixture base module meaning");
    StreamModuleRegistry private registry;
    MockGovernedParameterAuthority private authority;
    DelegationManagementContract private delegation;
    AuctionDelegationHarness private house;
    uint256 private actionNonce;

    function setUp() public {
        vm.warp(1000);
        authority = new MockGovernedParameterAuthority(true);
        registry = new StreamModuleRegistry(
            IStreamGovernanceExecutor(address(authority)), MANIFEST, "urn:delegation:registry"
        );
        delegation = new DelegationManagementContract();
        house = _harness(address(delegation), 2);
        _register(address(house), keccak256(house.declaration()));
    }

    function _harness(address target, uint256 usecase) private returns (AuctionDelegationHarness) {
        return new AuctionDelegationHarness(
            StreamNativeAuctionDelegation.Configuration(
                block.chainid,
                CORE,
                target,
                target.codehash,
                usecase,
                MANIFEST,
                address(registry),
                address(registry).codehash
            )
        );
    }

    function _grant(
        address scope,
        address delegate,
        uint256 expiry,
        uint256 usecase,
        bool allTokens,
        uint256 token
    ) private {
        vm.prank(VAULT);
        delegation.registerDelegationAddress(scope, delegate, expiry, usecase, allTokens, token);
    }

    function _bindFails(bytes32 id, address to, bool wide, uint256 index, uint256 cap) private {
        uint256 before = house.successfulBindings();
        vm.prank(BIDDER);
        (bool ok,) = address(house).call(abi.encodeCall(house.bind, (id, to, wide, index, cap)));
        require(
            !ok && house.successfulBindings() == before && house.bound(id, BIDDER) == address(0),
            "failed authority cannot bind"
        );
    }

    function testActualRetainedGrantBindingSurvivesRevocationButFreshClaimsDoNot() public {
        _grant(CORE, BIDDER, 999, 2, true, 0);
        _grant(CORE, BIDDER, 2000, 2, true, 0);
        _bindFails(ID, VAULT, false, 0, 150000);
        vm.prank(BIDDER);
        require(house.bind(ID, VAULT, false, 1, 150000) == VAULT);
        vm.prank(VAULT);
        delegation.revokeDelegationAddress(CORE, BIDDER, 2);
        vm.etch(address(delegation), hex"00");
        vm.prank(BIDDER);
        require(
            house.bind(ID, VAULT, false, 999999, 0) == VAULT,
            "original authority needs no late registry"
        );
        vm.prank(BIDDER);
        (bool ok,) = address(house).call(abi.encodeCall(house.bind, (ID, OTHER, false, 0, 150000)));
        require(!ok && house.bound(ID, BIDDER) == VAULT, "cannot replace original vault");
        vm.prank(BIDDER);
        (ok,) = address(house).call(abi.encodeCall(house.claim, (VAULT, VAULT, false, 1, 150000)));
        require(!ok, "claim needs current authority");
        vm.prank(VAULT);
        require(
            house.claim(VAULT, OTHER, false, 999999, 0) == OTHER,
            "own claim remains dependency free"
        );
    }

    function testWalletWideAndLaterUsecaseKeepVaultDeliveryAndBidderIdentityDistinct() public {
        _grant(ALL, BIDDER, 2000, 2, true, 0);
        vm.prank(BIDDER);
        require(house.bind(ID, VAULT, true, 0, 150000) == VAULT);
        require(
            house.bound(ID, VAULT) == address(0) && house.bound(ID, BIDDER) == VAULT,
            "binding remains bidder keyed"
        );
        vm.prank(BIDDER);
        require(house.claim(VAULT, VAULT, true, 0, 150000) == VAULT);
        vm.prank(BIDDER);
        (bool ok,) =
            address(house).call(abi.encodeCall(house.claim, (VAULT, OTHER, true, 0, 150000)));
        require(!ok, "delegate can trigger but never redirect");
        delegation.updateUseCaseCounter();
        AuctionDelegationHarness later = _harness(address(delegation), 1000);
        _register(address(later), keccak256(later.declaration()));
        _grant(CORE, BIDDER, 2000, 1000, true, 0);
        vm.prank(BIDDER);
        require(later.bind(ID, VAULT, false, 0, 150000) == VAULT, "actual later registered usecase");
    }

    function testTokenLimitedWrongScopeWrongUsecaseExpiredAndFutureRowsReject() public {
        _grant(CORE, BIDDER, 2000, 2, false, 7);
        _bindFails(ID, VAULT, false, 0, 150000);
        _grant(CORE, BIDDER, 2000, 3, true, 0);
        _grant(OTHER, BIDDER, 2000, 2, true, 0);
        _bindFails(ID, VAULT, true, 0, 150000);
        _grant(CORE, BIDDER, 1000, 2, true, 0);
        _bindFails(ID, VAULT, false, 1, 150000);
        _grant(CORE, OTHER, 2000, 2, true, 0);
        _bindFails(ID, VAULT, false, 2, 150000);
        _grant(CORE, BIDDER, 2000, 2, true, 0);
        vm.warp(999);
        _bindFails(ID, VAULT, false, 2, 150000);
    }

    function testActualModuleManifestAndRuntimePinsCannotBeSubstituted() public {
        AuctionDelegationHarness wrong = _harness(address(delegation), 2);
        _register(address(wrong), MANIFEST);
        _grant(CORE, BIDDER, 2000, 2, true, 0);
        vm.prank(BIDDER);
        (bool ok,) = address(wrong).call(abi.encodeCall(wrong.bind, (ID, VAULT, false, 0, 150000)));
        require(!ok && wrong.successfulBindings() == 0, "original admitted declaration required");
        vm.etch(address(registry), hex"00");
        _bindFails(ID, VAULT, false, 0, 150000);
        vm.prank(BIDDER);
        require(
            house.bind(ID, address(0), false, 0, 0) == BIDDER, "self delivery invokes no delegation"
        );
    }

    function testCanonical192BytesAndReadGasFailClosed() public {
        AuctionDelegationMalformedRegistry hostile = new AuctionDelegationMalformedRegistry();
        AuctionDelegationHarness h = _harness(address(hostile), 2);
        uint256[6] memory row =
            [uint256(uint160(VAULT)), uint256(uint160(BIDDER)), 1000, 2000, 1, 0];
        hostile.set(row, 192, 0);
        h.requireRow(VAULT, BIDDER, false, 0, 150000);
        uint256[4] memory sizes = [uint256(0), 191, 193, 32768];
        for (uint256 j; j < sizes.length; ++j) {
            hostile.set(row, sizes[j], 0);
            (bool ok,) =
                address(h).call(abi.encodeCall(h.requireRow, (VAULT, BIDDER, false, 0, 150000)));
            require(!ok, "exact192 only");
        }
        for (uint256 mode = 1; mode <= 2; ++mode) {
            hostile.set(row, 192, mode);
            (bool ok,) =
                address(h).call(abi.encodeCall(h.requireRow, (VAULT, BIDDER, false, 0, 150000)));
            require(!ok, "revert and exhausting callee fail closed");
        }
        hostile.set(row, 192, 0);
        (bool ok,) =
            address(h).call(abi.encodeCall(h.requireRow, (VAULT, BIDDER, false, 0, gasleft())));
        require(!ok, "EIP150 reserve enforced");
    }

    function testFuzzEveryRetainedRowFieldIsAuthenticated(uint8 selected) public {
        AuctionDelegationMalformedRegistry hostile = new AuctionDelegationMalformedRegistry();
        AuctionDelegationHarness h = _harness(address(hostile), 2);
        uint256[6] memory row =
            [uint256(uint160(VAULT)), uint256(uint160(BIDDER)), 1000, 2000, 1, 0];
        uint256 field = uint256(selected) % 6;
        if (field == 2) row[field] = 1001;
        else if (field == 3) row[field] = 1000;
        else row[field] ^= 1;
        hostile.set(row, 192, 0);
        (bool ok,) =
            address(h).call(abi.encodeCall(h.requireRow, (VAULT, BIDDER, false, 0, 150000)));
        require(!ok, "every exact retained authority field matters");
    }

    function _register(address module, bytes32 declarationHash) private {
        StreamModuleRegistration memory registration = StreamModuleRegistration(
            module,
            keccak256("AUCTION_DELEGATION_FIXTURE"),
            MANIFEST,
            0x12345678,
            0,
            module.codehash,
            MANIFEST,
            declarationHash,
            "urn:delegation:compact-abi-v1"
        );
        (bytes32 scope, bytes32 oldState, bytes32 newState) = _registrationTransition(registration);
        authority.setCurrentAction(true, bytes32(++actionNonce), 1, scope, oldState, newState);
        vm.prank(address(authority));
        registry.registerModule(registration);
        authority.setCurrentAction(false, 0, 0, 0, 0, 0);
    }

    // Exact four registration preimage helpers from NativeEnglishAuctionFixture follow.
    function _expectedChainHash(
        bytes32 previousChainHash,
        StreamModuleRegistration memory registration,
        bytes32 runtimeCodeHash,
        uint64 recordIndex
    ) internal view returns (bytes32) {
        bytes32 recordHash = keccak256(
            abi.encode(
                registry.STREAM_MODULE_REGISTRATION_RECORD_V1(),
                registration.module,
                registration.moduleType,
                registration.interfaceId,
                registration.moduleVersion,
                runtimeCodeHash,
                registration.deploymentManifestHash,
                registration.moduleManifestHash
            )
        );
        return keccak256(
            abi.encode(
                registry.STREAM_RECORD_CHAIN_V1(),
                uint256(block.chainid),
                address(registry),
                uint256(0),
                keccak256("MODULE_REGISTRATION"),
                previousChainHash,
                recordHash,
                recordIndex
            )
        );
    }

    function _recordFactsHash(
        ModuleRegistryStatus status,
        StreamModuleRegistration memory registration,
        bytes32 runtimeCodeHash,
        uint64 revision
    ) internal pure returns (bytes32) {
        return keccak256(
            abi.encode(
                uint8(status),
                registration.moduleType,
                registration.moduleVersion,
                registration.interfaceId,
                registration.moduleGasLimit,
                runtimeCodeHash,
                registration.deploymentManifestHash,
                registration.moduleManifestHash,
                keccak256(bytes(registration.moduleManifestURI)),
                revision
            )
        );
    }

    function _emptyRecordFactsHash() internal pure returns (bytes32) {
        StreamModuleRegistration memory empty;
        return _recordFactsHash(ModuleRegistryStatus.UNKNOWN, empty, bytes32(0), 0);
    }

    function _registrationTransition(StreamModuleRegistration memory registration)
        internal
        view
        returns (bytes32 scopeHash, bytes32 oldValueHash, bytes32 newValueHash)
    {
        uint256 count = registry.moduleCount();
        (bytes32 chainHash, uint64 recordCount) = registry.registrationChainHash();
        uint64 index = uint64(count);
        bytes32 newChainHash =
            _expectedChainHash(chainHash, registration, registration.module.codehash, index);
        scopeHash = keccak256(
            abi.encode(
                registry.STREAM_MODULE_REGISTRATION_SCOPE_V1(),
                uint256(block.chainid),
                address(registry),
                registration.module
            )
        );
        oldValueHash = keccak256(
            abi.encode(
                registry.STREAM_MODULE_REGISTRATION_STATE_V1(),
                scopeHash,
                false,
                _emptyRecordFactsHash(),
                count,
                chainHash,
                recordCount,
                address(0)
            )
        );
        newValueHash = keccak256(
            abi.encode(
                registry.STREAM_MODULE_REGISTRATION_STATE_V1(),
                scopeHash,
                true,
                _recordFactsHash(
                    ModuleRegistryStatus.ACTIVE, registration, registration.module.codehash, 1
                ),
                count + 1,
                newChainHash,
                recordCount + 1,
                registration.module
            )
        );
    }
}
