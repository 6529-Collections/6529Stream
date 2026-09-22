// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamArtistBindingTermsStorage as TermsStorage
} from "../../../smart-contracts/domains/artist/StreamArtistBindingTermsStorage.sol";
import {
    StreamArtistOnboardingTypes as T
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistOnboardingTypes.sol";
import {
    StreamArtistCollaboratorTypes as C
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistCollaboratorTypes.sol";

interface BindingTermsVm {
    function expectRevert(bytes calldata reason) external;
}

/// @dev Typed storage boundary only; the actual Binding owner keeps its unchanged proposal guards.
contract BindingTermsStorageHarness {
    bytes32 public left = keccak256("terms left canary");
    mapping(uint256 => mapping(uint64 => C.BindingTerms)) private terms;
    mapping(uint256 => mapping(uint64 => T.CollaboratorRecord[])) private rows;
    bytes32 public right = keccak256("terms right canary");
    address public lastCaller;
    error AfterTerms(uint256 collection, uint64 generation);

    function save(
        uint256 collection,
        uint64 generation,
        T.CollaboratorRecord[] calldata items,
        bool fail
    ) external {
        TermsStorage.store(terms, rows, collection, generation, items);
        if (fail) revert AfterTerms(collection, generation);
        lastCaller = msg.sender;
    }

    function read(uint256 collection, uint64 generation)
        external
        view
        returns (C.BindingTerms memory, T.CollaboratorRecord[] memory)
    {
        return (terms[collection][generation], rows[collection][generation]);
    }
}

contract StreamArtistBindingTermsStorageTest {
    BindingTermsVm private constant vm =
        BindingTermsVm(address(uint160(uint256(keccak256("hevm cheat code")))));
    BindingTermsStorageHarness private host;

    function setUp() public {
        host = new BindingTermsStorageHarness();
    }

    function testEmptyTermsKeepLiteralDomainsAndAllZeroPolicyFields() external {
        T.CollaboratorRecord[] memory rows = new T.CollaboratorRecord[](0);
        host.save(17, 1, rows, false);
        _assert(17, 1, rows);
        _empty(18, 1);
    }

    function testFullWidthCoordinatesAndSameAccountOrderedRoles() external {
        uint256 collection = (uint256(1) << 255) + 17;
        T.CollaboratorRecord[] memory rows = new T.CollaboratorRecord[](2);
        rows[0] = T.CollaboratorRecord(address(0xBEEF), bytes32(uint256(1)), keccak256("first"));
        rows[1] = T.CollaboratorRecord(address(0xBEEF), bytes32(uint256(2)), keccak256("second"));
        host.save(collection, type(uint64).max, rows, false);
        _assert(collection, type(uint64).max, rows);
        _empty(uint256(uint128(collection)), type(uint64).max);
        _empty(collection, type(uint64).max - 1);
    }

    function testThirtyThreeRowsRefuseBeforeZeroAccountAndLeaveStorageEmpty() external {
        T.CollaboratorRecord[] memory rows = new T.CollaboratorRecord[](33);
        vm.expectRevert(abi.encodeWithSelector(T.BoundExceeded.selector, uint256(33), uint256(32)));
        host.save(17, 1, rows, false);
        _empty(17, 1);
    }

    function testLateZeroAccountRollsBackFirstAppendAndRetryHasOneCopy() external {
        T.CollaboratorRecord[] memory rows = new T.CollaboratorRecord[](2);
        rows[0] = T.CollaboratorRecord(address(1), bytes32(0), keccak256("first"));
        vm.expectRevert(abi.encodeWithSelector(T.InvalidRecord.selector));
        host.save(17, 1, rows, false);
        _empty(17, 1);
        rows[1] = T.CollaboratorRecord(address(2), bytes32(0), keccak256("second"));
        host.save(17, 1, rows, false);
        _assert(17, 1, rows);
    }

    function testUnsortedAndDuplicatePairRefuseRegardlessOfShareLabel() external {
        T.CollaboratorRecord[] memory rows = new T.CollaboratorRecord[](2);
        rows[0] = T.CollaboratorRecord(address(2), bytes32(uint256(1)), keccak256("first"));
        rows[1] = T.CollaboratorRecord(address(1), bytes32(uint256(9)), keccak256("second"));
        vm.expectRevert(abi.encodeWithSelector(T.InvalidRecord.selector));
        host.save(17, 1, rows, false);
        _empty(17, 1);
        rows[1] =
            T.CollaboratorRecord(address(2), bytes32(uint256(1)), keccak256("different share"));
        vm.expectRevert(abi.encodeWithSelector(T.InvalidRecord.selector));
        host.save(17, 1, rows, false);
        _empty(17, 1);
        rows[1].role = bytes32(uint256(2));
        host.save(17, 1, rows, false);
        _assert(17, 1, rows);
    }

    function testLateHostFailureRollsBackCompletedWorkerAndIdenticalRetry() external {
        T.CollaboratorRecord[] memory prior = new T.CollaboratorRecord[](1);
        prior[0] =
            T.CollaboratorRecord(address(7), keccak256("prior role"), keccak256("prior share"));
        host.save(17, 1, prior, false);
        T.CollaboratorRecord[] memory rows = new T.CollaboratorRecord[](1);
        rows[0] = T.CollaboratorRecord(address(9), keccak256("next role"), keccak256("next share"));
        vm.expectRevert(
            abi.encodeWithSelector(
                BindingTermsStorageHarness.AfterTerms.selector, uint256(17), uint64(2)
            )
        );
        host.save(17, 2, rows, true);
        _empty(17, 2);
        _assert(17, 1, prior);
        host.save(17, 2, rows, false);
        _assert(17, 2, rows);
        _assert(17, 1, prior);
    }

    function testFuzzFullTupleHashStorageAndCaller(
        uint256 collection,
        uint64 generation,
        address account,
        bytes32 role,
        bytes32 share
    ) external {
        if (account == address(0)) account = address(1);
        T.CollaboratorRecord[] memory rows = new T.CollaboratorRecord[](1);
        rows[0] = T.CollaboratorRecord(account, role, share);
        host.save(collection, generation, rows, false);
        _assert(collection, generation, rows);
        _empty(collection ^ 1, generation);
    }

    function _assert(uint256 collection, uint64 generation, T.CollaboratorRecord[] memory rows)
        private
        view
    {
        (C.BindingTerms memory actual, T.CollaboratorRecord[] memory retained) =
            host.read(collection, generation);
        T.CapabilityPolicyOverride[] memory empty = new T.CapabilityPolicyOverride[](0);
        C.BindingTerms memory expected = C.BindingTerms(
            keccak256(abi.encode(keccak256("6529STREAM_ARTIST_COLLABORATOR_SET_V1"), rows)),
            keccak256(abi.encode(keccak256("6529STREAM_ARTIST_CAPABILITY_POLICY_SET_V1"), empty)),
            0,
            0,
            uint32(rows.length)
        );
        require(
            keccak256(abi.encode(actual)) == keccak256(abi.encode(expected)),
            "literal complete terms"
        );
        require(
            keccak256(abi.encode(retained)) == keccak256(abi.encode(rows)),
            "every retained collaborator field"
        );
        require(host.lastCaller() == address(this), "original host caller");
        _canaries();
    }

    function _empty(uint256 collection, uint64 generation) private view {
        (C.BindingTerms memory actual, T.CollaboratorRecord[] memory rows) =
            host.read(collection, generation);
        C.BindingTerms memory zero;
        require(
            keccak256(abi.encode(actual)) == keccak256(abi.encode(zero)) && rows.length == 0,
            "no partial storage"
        );
        _canaries();
    }

    function _canaries() private view {
        require(
            host.left() == keccak256("terms left canary")
                && host.right() == keccak256("terms right canary"),
            "unrelated storage"
        );
    }
}
