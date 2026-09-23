// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    CharacterizationTestBase
} from "../../regression/legacy/helpers/CharacterizationTestBase.sol";
import {
    StreamViewPreservationContentTreeV1 as Tree
} from "../../../smart-contracts/domains/finality/StreamViewPreservationContentTreeV1.sol";
import {
    StreamViewPreservationCheckpointTypesV1 as T
} from "../../../smart-contracts/interfaces/stream/finality/StreamViewPreservationCheckpointTypesV1.sol";
import {
    StreamFinalityScope,
    StreamFinalityScopeType
} from "../../../smart-contracts/interfaces/stream/finality/StreamArtworkFinalityTypes.sol";

contract PreservationTreeProbe {
    function root(
        uint256 chainId,
        address core,
        StreamFinalityScope memory scope,
        bytes32 adoption,
        T.Output[] memory rows
    ) external pure returns (bytes32) {
        return Tree.root(chainId, core, scope, adoption, rows);
    }

    function overMaximum(StreamFinalityScope memory scope) external pure returns (bytes32) {
        T.Output[] memory rows = new T.Output[](1);
        // Only the early length predicate is probed, without allocating a sixteen-megabyte array.
        assembly ("memory-safe") { mstore(rows, 16385) }
        return Tree.root(1, address(1), scope, bytes32(uint256(1)), rows);
    }
}

/// @notice Independent recursive split oracle for the ordered pair/promote tree; no source authority.
contract StreamViewPreservationContentTreeV1Test is CharacterizationTestBase {
    PreservationTreeProbe private probe = new PreservationTreeProbe();

    function _scope() private pure returns (StreamFinalityScope memory) {
        return
            StreamFinalityScope(
                StreamFinalityScopeType.VIEW, 17, 0, keccak256("membership, not viewId")
            );
    }

    function _rows(uint256 count, bytes32 salt) private pure returns (T.Output[] memory rows) {
        rows = new T.Output[](count);
        for (uint256 i; i < count; ++i) {
            rows[i].index = uint64(i);
            rows[i].tokenId = 100 + i * 7;
            rows[i].collectionSerial = i * 3 + 5;
            rows[i].jsonHash = keccak256(abi.encode("complete JSON", salt, i));
            rows[i].htmlHash = keccak256(abi.encode("complete HTML", salt, i));
            rows[i].entropy.policyHash = salt;
            rows[i].entropy.policy.revision = uint64(i + 1);
        }
    }

    function _leaf(
        uint256 chain,
        address core,
        StreamFinalityScope memory scope,
        bytes32 adopted,
        T.Output memory row
    ) private pure returns (bytes32) {
        return keccak256(
            abi.encode(
                keccak256("6529STREAM_VIEW_PRESERVATION_CONTENT_LEAF_V1"),
                keccak256("6529STREAM_ADOPTED_POLICY_VIEW_PRESERVATION_V1"),
                chain,
                core,
                scope,
                adopted,
                row
            )
        );
    }

    function _node(bytes32 left, bytes32 right) private pure returns (bytes32) {
        return
            keccak256(
                abi.encode(keccak256("6529STREAM_VIEW_PRESERVATION_CONTENT_NODE_V1"), left, right)
            );
    }

    function _recursive(T.Output[] memory rows, uint256 start, uint256 count)
        private
        pure
        returns (bytes32)
    {
        if (count == 1) {
            return _leaf(9, address(0x1234), _scope(), bytes32(uint256(42)), rows[start]);
        }
        uint256 split = 1;
        while (split * 2 < count) split *= 2;
        return _node(_recursive(rows, start, split), _recursive(rows, start + split, count - split));
    }

    function _actual(T.Output[] memory rows) private view returns (bytes32) {
        return probe.root(9, address(0x1234), _scope(), bytes32(uint256(42)), rows);
    }

    function testOddNodesPromoteRatherThanDuplicateOrSort() public view {
        T.Output[] memory rows = _rows(3, bytes32(uint256(8)));
        bytes32 a = _leaf(9, address(0x1234), _scope(), bytes32(uint256(42)), rows[0]);
        bytes32 b = _leaf(9, address(0x1234), _scope(), bytes32(uint256(42)), rows[1]);
        bytes32 c = _leaf(9, address(0x1234), _scope(), bytes32(uint256(42)), rows[2]);
        bytes32 root = _actual(rows);
        require(root == _node(_node(a, b), c));
        require(root != _node(_node(a, b), _node(c, c)) && root != _node(_node(b, a), c));
    }

    function testEveryOutputWordAndAllDomainCoordinatesParticipate() public view {
        T.Output[] memory rows = _rows(1, bytes32(uint256(8)));
        bytes memory canonical = abi.encode(rows[0]);
        require(canonical.length == 31 * 32);
        bytes32 baseline = _actual(rows);
        for (uint256 i; i < 31; ++i) {
            // Raw leaf commitment covers even scalar words whose mutated value is not a valid output.
            bytes memory frame = abi.encode(
                keccak256("6529STREAM_VIEW_PRESERVATION_CONTENT_LEAF_V1"),
                keccak256("6529STREAM_ADOPTED_POLICY_VIEW_PRESERVATION_V1"),
                uint256(9),
                address(0x1234),
                _scope(),
                bytes32(uint256(42)),
                rows[0]
            );
            frame[(9 + i) * 32 + 31] ^= bytes1(uint8(1));
            require(keccak256(frame) != baseline);
        }
        StreamFinalityScope memory scope = _scope();
        require(probe.root(10, address(0x1234), scope, bytes32(uint256(42)), rows) != baseline);
        require(probe.root(9, address(0x1235), scope, bytes32(uint256(42)), rows) != baseline);
        require(probe.root(9, address(0x1234), scope, bytes32(uint256(43)), rows) != baseline);
        scope.scopeId = keccak256("different membership");
        require(probe.root(9, address(0x1234), scope, bytes32(uint256(42)), rows) != baseline);
    }

    function testEmptyOversizeAndWrongScopeRejectBeforeRows() public {
        vm.expectRevert(abi.encodeWithSelector(T.InvalidViewCheckpoint.selector));
        probe.root(9, address(0x1234), _scope(), bytes32(uint256(42)), new T.Output[](0));
        vm.expectRevert(abi.encodeWithSelector(T.InvalidViewCheckpoint.selector));
        probe.overMaximum(_scope());
        StreamFinalityScope memory scope = _scope();
        scope.scopeType = StreamFinalityScopeType.RELEASE;
        T.Output[] memory rows = _rows(1, 0);
        vm.expectRevert(abi.encodeWithSelector(T.InvalidViewCheckpoint.selector));
        probe.root(9, address(0x1234), scope, bytes32(uint256(42)), rows);
    }

    function testMissingDuplicateIndexAndEmptyOutputHashRefuseThenRestore() public {
        T.Output[] memory rows = _rows(3, 0);
        bytes32 expected = _actual(rows);
        rows[1].index = 2;
        vm.expectRevert(abi.encodeWithSelector(T.ViewCheckpointIndex.selector, uint256(1)));
        probe.root(9, address(0x1234), _scope(), bytes32(uint256(42)), rows);
        rows[1].index = 1;
        rows[1].tokenId = 100;
        vm.expectRevert(abi.encodeWithSelector(T.ViewCheckpointIndex.selector, uint256(1)));
        probe.root(9, address(0x1234), _scope(), bytes32(uint256(42)), rows);
        rows[1].tokenId = 107;
        bytes32 saved = rows[1].htmlHash;
        rows[1].htmlHash = 0;
        vm.expectRevert(abi.encodeWithSelector(T.ViewCheckpointIndex.selector, uint256(1)));
        probe.root(9, address(0x1234), _scope(), bytes32(uint256(42)), rows);
        rows[1].htmlHash = saved;
        require(_actual(rows) == expected);
    }

    function testFuzzCompleteRecursiveParity(uint8 rawCount, bytes32 salt) public view {
        uint256 count = uint256(rawCount) % 65 + 1;
        T.Output[] memory rows = _rows(count, salt);
        require(_actual(rows) == _recursive(rows, 0, count));
    }
}
