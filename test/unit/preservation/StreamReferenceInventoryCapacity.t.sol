// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamReferenceEnvironmentJson as Current
} from "../../../smart-contracts/domains/records/StreamReferenceEnvironmentJson.sol";
import {
    StreamReferenceRenderTypes as R
} from "../../../smart-contracts/interfaces/stream/preservation/StreamReferenceRenderTypes.sol";
import {
    ReferenceEnvironmentJsonFrozen as Prior
} from "../../helpers/ReferenceEnvironmentJsonFrozen.sol";

interface InventoryCapacityVm {
    function readFile(string calldata path) external view returns (string memory);
    function parseJsonBytes(string calldata json, string calldata key)
        external
        pure
        returns (bytes memory);
}

contract StreamReferenceInventoryCapacityTest {
    InventoryCapacityVm private constant vm =
        InventoryCapacityVm(address(uint160(uint256(keccak256("hevm cheat code")))));
    event log_named_uint(string label, uint256 value);

    function _compare(R.PackageFile[] memory rows, bool relative)
        private
        view
        returns (bytes memory returned)
    {
        bytes memory input = abi.encodeWithSelector(Current.files.selector, rows, relative);
        (bool ok, bytes memory actual) = address(Current).staticcall(input);
        (bool oldOk, bytes memory expected) = address(Prior).staticcall(input);
        require(ok == oldOk, "same acceptance");
        require(keccak256(actual) == keccak256(expected), "same full bytes or error");
        return actual;
    }

    function _one(string memory path, uint64 size, bytes32 digest)
        private
        pure
        returns (R.PackageFile[] memory rows)
    {
        rows = new R.PackageFile[](1);
        rows[0] = R.PackageFile(path, size, digest);
    }

    function testEmptyAndDecimalExtremes() public view {
        _compare(new R.PackageFile[](0), true);
        _compare(new R.PackageFile[](0), false);
        uint64[5] memory amounts = [uint64(0), 9, 10, 100, type(uint64).max];
        for (uint256 i; i < amounts.length; ++i) {
            _compare(_one("a/b", amounts[i], bytes32(type(uint256).max)), true);
            _compare(_one("C:\\a\"\nb", amounts[i], bytes32(uint256(1))), false);
        }
    }

    function testFuzzArbitraryPathAndDigest(
        bytes memory path,
        uint64 size,
        bytes32 digest,
        bool relative
    ) public view {
        if (path.length > 2200) return;
        _compare(_one(string(path), size, digest), relative);
    }

    function testFuzzValidPathDigestAndDecimal(bytes32 digest, uint64 size) public view {
        if (digest == 0) digest = bytes32(uint256(1));
        _compare(_one("metric/source/a_file-9.py", size, digest), true);
        _compare(_one("C:\\archived\"path", size, digest), false);
    }

    function testEveryRelativePathByte() public view {
        bytes memory path = bytes("axb");
        for (uint256 i; i < 256; ++i) {
            path[1] = bytes1(uint8(i));
            _compare(_one(string(path), 0, bytes32(uint256(1))), true);
        }
    }

    function testFuzzSortingAndErrorOrder(bytes memory a, bytes memory b, bool relative)
        public
        view
    {
        if (a.length > 2200 || b.length > 2200) return;
        R.PackageFile[] memory rows = new R.PackageFile[](2);
        rows[0] = R.PackageFile(string(a), 0, bytes32(uint256(1)));
        rows[1] = R.PackageFile(string(b), type(uint64).max, bytes32(uint256(2)));
        _compare(rows, relative);
        rows[1].sha256Digest = bytes32(0);
        _compare(rows, relative);
    }

    function testPathRulesSortDuplicatesAndZeroDigest() public view {
        string[13] memory bad = [
            string(""),
            "/a",
            "a/",
            "a//b",
            "a/./b",
            "a/../b",
            "a./b",
            "a /b",
            "a\\b",
            "a:b",
            "a?b",
            "a*b",
            "a\"b"
        ];
        for (uint256 i; i < bad.length; ++i) {
            _compare(_one(bad[i], 1, bytes32(uint256(1))), true);
        }
        bytes memory invalidUtf8 = hex"c0af";
        _compare(_one(string(invalidUtf8), 1, bytes32(uint256(1))), false);
        _compare(_one(string(hex"e280a8e280a9f09f9880"), 1, bytes32(uint256(1))), false);
        _compare(_one("", 1, 0), false);
        R.PackageFile[] memory rows = new R.PackageFile[](2);
        rows[0] = R.PackageFile("same", 0, bytes32(uint256(1)));
        rows[1] = R.PackageFile("same", 1, bytes32(uint256(2)));
        _compare(rows, true);
        rows[1].path = "earlier";
        _compare(rows, false);
        rows[1].path = "same/child";
        _compare(rows, true);
    }

    function _longPath(uint256 index, uint256 size) private pure returns (string memory) {
        bytes memory path = new bytes(size);
        assembly ("memory-safe") {
            let data := add(path, 32)
            for { let i := 0 } lt(i, size) { i := add(i, 32) } {
                mstore(
                    add(data, i),
                    0x6161616161616161616161616161616161616161616161616161616161616161
                )
            }
        }
        path[0] = bytes1(uint8(48 + index / 1000));
        path[1] = bytes1(uint8(48 + index / 100 % 10));
        path[2] = bytes1(uint8(48 + index / 10 % 10));
        path[3] = bytes1(uint8(48 + index % 10));
        return string(path);
    }

    function testExactOriginalPrefixBoundAndPathBounds() public view {
        R.PackageFile[] memory rows = new R.PackageFile[](462);
        for (uint256 i; i < rows.length; ++i) {
            rows[i] = R.PackageFile(_longPath(i, i == 461 ? 942 : 1024), 0, bytes32(uint256(1)));
        }
        bytes memory returned = _compare(rows, true);
        require(
            bytes(abi.decode(returned, (string))).length == 524289,
            "original closing bracket convention"
        );
        rows[461].path = _longPath(461, 943);
        _compare(rows, true);
        _compare(_one(_longPath(0, 1025), 0, bytes32(uint256(1))), true);
        _compare(_one(_longPath(0, 2048), 0, bytes32(uint256(1))), false);
        _compare(_one(_longPath(0, 2049), 0, bytes32(uint256(1))), false);
    }

    function testActualComplete1048And102Inventories() public {
        string memory fixture =
            vm.readFile("test/fixtures/preservation/reference-combined-native-v1.json");
        _corpus(fixture, ".packageFilesABI", true, 1048);
        _corpus(fixture, ".platformPrerequisitesABI", false, 102);
    }

    function _corpus(string memory fixture, string memory key, bool relative, uint256 count)
        private
    {
        R.PackageFile[] memory rows = abi.decode(vm.parseJsonBytes(fixture, key), (R.PackageFile[]));
        require(rows.length == count);
        bytes memory input = abi.encodeWithSelector(Current.files.selector, rows, relative);
        uint256 before = gasleft();
        (bool oldOk, bytes memory expected) = address(Prior).staticcall(input);
        uint256 oldCost = before - gasleft();
        before = gasleft();
        (bool ok, bytes memory actual) = address(Current).staticcall(input);
        uint256 cost = before - gasleft();
        require(ok && oldOk && keccak256(actual) == keccak256(expected), "actual corpus bytes");
        emit log_named_uint(relative ? "packagePriorGas" : "platformPriorGas", oldCost);
        emit log_named_uint(relative ? "packageCurrentGas" : "platformCurrentGas", cost);
        emit log_named_uint(
            relative ? "packageBytes" : "platformBytes", bytes(abi.decode(actual, (string))).length
        );
        require(cost < oldCost, "measured improvement");
    }
}
