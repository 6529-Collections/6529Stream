// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    StreamEntropyPolicyInventory as Inventory
} from "../../../smart-contracts/domains/entropy/StreamEntropyPolicyInventory.sol";

interface EntropyInventoryVm {
    function etch(address target, bytes calldata code) external;
}

contract EntropyPolicyInventoryHarness {
    uint256 public originalSlot = 6529;

    function header() external view returns (Inventory.Header memory) {
        return Inventory.header();
    }

    function count() external view returns (uint256) {
        return Inventory.count();
    }

    function at(uint256 index) external view returns (uint256) {
        return Inventory.at(index);
    }

    function origin(uint256 id) external view returns (address, bytes32) {
        return Inventory.origin(id);
    }

    function inventoried(uint256 id) external view returns (bool) {
        return Inventory.store().inventoried[id];
    }

    function recordLocal(uint256 id) external {
        Inventory.recordLocal(id);
    }

    function touch(uint256 id) external {
        Inventory.touch(id);
    }

    function installImported(uint256 id, address policyOrigin, bytes32 hash) external {
        Inventory.installImported(id, policyOrigin, hash);
    }

    function seedSerialForTest(uint64 serial) external {
        Inventory.store().serial = serial;
    }
}

/// @dev Any accidental origin call fails; account code facts remain available.
contract EntropyPolicyInventoryOriginFixture {
    fallback() external {
        revert("origin unavailable");
    }
}

contract StreamEntropyPolicyInventoryTest {
    EntropyInventoryVm private constant vm =
        EntropyInventoryVm(address(uint160(uint256(keccak256("hevm cheat code")))));
    bytes32 private constant INITIAL =
        keccak256("6529STREAM_ENTROPY_POLICY_INVENTORY_IDS_INITIAL_V1");
    bytes32 private constant APPEND =
        keccak256("6529STREAM_ENTROPY_POLICY_INVENTORY_IDS_APPEND_V1");
    EntropyPolicyInventoryHarness private inventory;

    function setUp() public {
        inventory = new EntropyPolicyInventoryHarness();
    }

    function testEmptyHeaderAndUnknownReadsFailWithoutLegacyDefaults() public {
        _header(0, 0, INITIAL);
        require(INITIAL != 0 && inventory.originalSlot() == 6529, "initial state");
        _reject(
            abi.encodeCall(inventory.at, (0)),
            abi.encodeWithSelector(Inventory.PolicyInventoryIndexOutOfBounds.selector, 0)
        );
        _reject(
            abi.encodeCall(inventory.origin, (0)),
            abi.encodeWithSelector(Inventory.UnknownPolicyInventoryCollection.selector, 0)
        );
    }

    function testLocalRecordsAppendInOrderIncludingZeroAndPreserveOriginalStorage() public {
        uint256[3] memory ids = [uint256(37), uint256(0), type(uint256).max];
        bytes32 digest = INITIAL;
        for (uint256 i; i < ids.length; ++i) {
            inventory.recordLocal(ids[i]);
            digest = keccak256(abi.encode(APPEND, digest, i, ids[i]));
            _header(i + 1, uint64(i + 1), digest);
            require(inventory.at(i) == ids[i] && inventory.inventoried(ids[i]), "ordered ID");
            _origin(ids[i], address(inventory), address(inventory).codehash);
        }
        require(inventory.originalSlot() == 6529, "original slot untouched");
        _reject(
            abi.encodeCall(inventory.at, (3)),
            abi.encodeWithSelector(Inventory.PolicyInventoryIndexOutOfBounds.selector, 3)
        );
    }

    function testTouchRetainsImportedOriginAndLocalConfigurationReauthorsWithoutAppend() public {
        address source = address(new EntropyPolicyInventoryOriginFixture());
        bytes32 hash = source.codehash;
        inventory.installImported(42, source, hash);
        bytes32 digest = keccak256(abi.encode(APPEND, INITIAL, uint256(0), uint256(42)));
        _header(1, 1, digest);
        _origin(42, source, hash);
        inventory.touch(42);
        _header(1, 2, digest);
        _origin(42, source, hash);
        inventory.recordLocal(42);
        _header(1, 3, digest);
        _origin(42, address(inventory), address(inventory).codehash);
        require(inventory.at(0) == 42, "one ordered ID");
    }

    function testUnknownTouchDoesNotRegisterOrAdvance() public {
        _reject(
            abi.encodeCall(inventory.touch, (12)),
            abi.encodeWithSelector(Inventory.UnknownPolicyInventoryCollection.selector, 12)
        );
        _header(0, 0, INITIAL);
        require(!inventory.inventoried(12), "unknown remains absent");
    }

    function testImportRejectsDuplicateWithoutChangingHeaderOrOrigin() public {
        address first = address(new EntropyPolicyInventoryOriginFixture());
        address second = address(new EntropyPolicyInventoryOriginFixture());
        inventory.installImported(5, first, first.codehash);
        Inventory.Header memory before = inventory.header();
        _reject(
            abi.encodeCall(inventory.installImported, (5, second, second.codehash)),
            abi.encodeWithSelector(Inventory.PolicyInventoryAlreadyRegistered.selector, 5)
        );
        _header(before.count, before.serial, before.idDigest);
        _origin(5, first, first.codehash);
        inventory.recordLocal(6);
        before = inventory.header();
        _reject(
            abi.encodeCall(inventory.installImported, (6, first, first.codehash)),
            abi.encodeWithSelector(Inventory.PolicyInventoryAlreadyRegistered.selector, 6)
        );
        _header(before.count, before.serial, before.idDigest);
        _origin(6, address(inventory), address(inventory).codehash);
    }

    function testImportRejectsZeroNonliveAndWrongCodeHashWithoutAppending() public {
        address source = address(new EntropyPolicyInventoryOriginFixture());
        _invalidImport(address(0), source.codehash);
        _invalidImport(source, bytes32(0));
        _invalidImport(address(0x6529), bytes32(uint256(1)));
        _invalidImport(source, bytes32(uint256(1)));
        _header(0, 0, INITIAL);
        require(!inventory.inventoried(7), "invalid import absent");
    }

    function testRelaysRetainUltimateOriginRatherThanImmediatePredecessor() public {
        EntropyPolicyInventoryHarness source = new EntropyPolicyInventoryHarness();
        EntropyPolicyInventoryHarness relay = new EntropyPolicyInventoryHarness();
        source.recordLocal(99);
        (address ultimate, bytes32 hash) = source.origin(99);
        relay.installImported(99, ultimate, hash);
        (ultimate, hash) = relay.origin(99);
        inventory.installImported(99, ultimate, hash);
        _origin(99, address(source), address(source).codehash);
        _header(1, 1, keccak256(abi.encode(APPEND, INITIAL, uint256(0), uint256(99))));
    }

    function testRecordedOriginSurvivesRuntimeLossButFurtherImportChecksLivePin() public {
        address source = address(new EntropyPolicyInventoryOriginFixture());
        bytes32 hash = source.codehash;
        inventory.installImported(17, source, hash);
        vm.etch(source, hex"60006000fd");
        _origin(17, source, hash);
        _invalidImport(source, hash);
        vm.etch(source, bytes(""));
        _origin(17, source, hash);
        _invalidImport(source, hash);
        _header(1, 1, keccak256(abi.encode(APPEND, INITIAL, uint256(0), uint256(17))));
    }

    function testSerialReachesMaxThenEveryMutationRevertsAtomically() public {
        inventory.recordLocal(9);
        Inventory.Header memory before = inventory.header();
        inventory.seedSerialForTest(type(uint64).max - 1);
        inventory.touch(9);
        _header(1, type(uint64).max, before.idDigest);
        bytes memory errorData =
            abi.encodeWithSelector(Inventory.PolicyInventorySerialOverflow.selector);
        _reject(abi.encodeCall(inventory.touch, (9)), errorData);
        _reject(abi.encodeCall(inventory.recordLocal, (9)), errorData);
        _reject(abi.encodeCall(inventory.recordLocal, (10)), errorData);
        address source = address(new EntropyPolicyInventoryOriginFixture());
        _reject(abi.encodeCall(inventory.installImported, (11, source, source.codehash)), errorData);
        _header(1, type(uint64).max, before.idDigest);
        require(!inventory.inventoried(10) && !inventory.inventoried(11), "no partial append");
        _origin(9, address(inventory), address(inventory).codehash);
    }

    function testFuzzRepeatedChangesAdvanceSerialWithoutAppending(uint256 id, uint8 changes)
        public
    {
        uint256 bounded = uint256(changes) % 17;
        inventory.recordLocal(id);
        bytes32 digest = keccak256(abi.encode(APPEND, INITIAL, uint256(0), id));
        for (uint256 i; i < bounded; ++i) {
            if (i % 2 == 0) inventory.touch(id);
            else inventory.recordLocal(id);
        }
        _header(1, uint64(1 + bounded), digest);
        require(inventory.at(0) == id && inventory.originalSlot() == 6529, "single namespaced ID");
        _origin(id, address(inventory), address(inventory).codehash);
    }

    function _invalidImport(address source, bytes32 hash) private {
        _reject(
            abi.encodeCall(inventory.installImported, (7, source, hash)),
            abi.encodeWithSelector(Inventory.InvalidPolicyInventoryOrigin.selector, source, hash)
        );
    }

    function _header(uint256 count, uint64 serial, bytes32 digest) private view {
        Inventory.Header memory h = inventory.header();
        require(
            h.count == count && inventory.count() == count && h.serial == serial
                && h.idDigest == digest,
            "exact inventory header"
        );
    }

    function _origin(uint256 id, address expected, bytes32 hash) private view {
        (address actual, bytes32 actualHash) = inventory.origin(id);
        require(actual == expected && actualHash == hash, "exact ultimate origin");
    }

    function _reject(bytes memory input, bytes memory expected) private {
        (bool ok, bytes memory result) = address(inventory).call(input);
        require(!ok && keccak256(result) == keccak256(expected), "exact inventory rejection");
    }
}
