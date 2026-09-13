// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../../../smart-contracts/domains/records/StreamOwnerNoticeFields.sol";

/// @notice Acceptance and exact ordered JSON against the retained quadratic implementation.
/// @dev Both paths use the unchanged contact validator; this is not URI or identity verification.
contract StreamOwnerContactUniquenessTest {
    function current(StreamOwnerNoticeTypes.Contact[] memory values)
        external
        pure
        returns (string memory)
    {
        return StreamOwnerNoticeFields.contacts(values);
    }

    /// @dev Literal prior contacts body, with its unchanged contact call qualified by library.
    function prior(StreamOwnerNoticeTypes.Contact[] memory values)
        external
        pure
        returns (string memory)
    {
        if (values.length == 0) revert StreamOwnerNoticeFields.InvalidNoticeWitness();
        string memory out = "[";
        bytes32[] memory hashes = new bytes32[](values.length);
        for (uint256 i; i < values.length; ++i) {
            string memory row = StreamOwnerNoticeFields.contact(values[i]);
            hashes[i] = keccak256(bytes(row));
            for (uint256 j; j < i; ++j) {
                if (hashes[i] == hashes[j]) revert StreamOwnerNoticeFields.InvalidNoticeWitness();
            }
            out = string.concat(out, i == 0 ? "" : ",", row);
            if (bytes(out).length > 8192) revert StreamOwnerNoticeFields.InvalidNoticeWitness();
        }
        return string.concat(out, "]");
    }

    function _values(uint256 n) private pure returns (StreamOwnerNoticeTypes.Contact[] memory a) {
        a = new StreamOwnerNoticeTypes.Contact[](n);
        for (uint256 i; i < n; ++i) {
            if (i % 3 == 0) {
                a[i] = StreamOwnerNoticeTypes.Contact(
                    StreamOwnerNoticeTypes.ContactKind.HTTPS,
                    string.concat("https://example/", _digits(i)),
                    0,
                    address(0)
                );
            } else if (i % 3 == 1) {
                a[i] = StreamOwnerNoticeTypes.Contact(
                    StreamOwnerNoticeTypes.ContactKind.MAILTO,
                    string.concat("mailto:a", _digits(i), "@example.org"),
                    0,
                    address(0)
                );
            } else {
                a[i] = StreamOwnerNoticeTypes.Contact(
                    StreamOwnerNoticeTypes.ContactKind.EIP155, "", i + 1, address(uint160(i + 1))
                );
            }
        }
    }

    function _digits(uint256 v) private pure returns (string memory) {
        return string(abi.encodePacked(bytes1(uint8(97 + v / 26)), bytes1(uint8(97 + v % 26))));
    }

    function _compare(StreamOwnerNoticeTypes.Contact[] memory a, bool expected) private view {
        bytes32 original = keccak256(abi.encode(a));
        (bool oldOK, bytes memory oldResult) =
            address(this).staticcall(abi.encodeCall(this.prior, (a)));
        (bool newOK, bytes memory newResult) =
            address(this).staticcall(abi.encodeCall(this.current, (a)));
        require(oldOK == expected && newOK == expected, "acceptance differs");
        if (expected) {
            require(keccak256(oldResult) == keccak256(newResult), "ordered JSON differs");
        }
        require(original == keccak256(abi.encode(a)), "input tuple order changed");
    }

    function testSingleOddEvenAndIncompleteHeapLevels() external view {
        for (uint256 n = 1; n <= 33; ++n) {
            _compare(_values(n), true);
        }
    }

    function testSortedAndReverseCanonicalHashOrder() external view {
        StreamOwnerNoticeTypes.Contact[] memory a = _values(64);
        // Independent insertion sort constructs adversarial input orders, never production logic.
        for (uint256 i = 1; i < a.length; ++i) {
            uint256 j = i;
            while (
                j != 0
                    && keccak256(bytes(StreamOwnerNoticeFields.contact(a[j - 1])))
                        > keccak256(bytes(StreamOwnerNoticeFields.contact(a[j])))
            ) {
                (a[j - 1], a[j]) = (a[j], a[j - 1]);
                --j;
            }
        }
        _compare(a, true);
        for (uint256 i; i < a.length / 2; ++i) {
            (a[i], a[a.length - i - 1]) = (a[a.length - i - 1], a[i]);
        }
        _compare(a, true);
    }

    function testDuplicateFirstMiddleLastAndEveryContactKind() external view {
        for (uint256 kind; kind < 3; ++kind) {
            for (uint256 offset = 3; offset < 16; offset += 6) {
                StreamOwnerNoticeTypes.Contact[] memory a = _values(16);
                a[offset] = a[kind];
                _compare(a, false);
            }
        }
        StreamOwnerNoticeTypes.Contact[] memory adjacent = _values(16);
        adjacent[1] = adjacent[0];
        _compare(adjacent, false);
    }

    function testSameAccountDifferentChainAndExactCaseAreDistinctTuples() external view {
        StreamOwnerNoticeTypes.Contact[] memory a = _values(4);
        a[0] = StreamOwnerNoticeTypes.Contact(
            StreamOwnerNoticeTypes.ContactKind.EIP155, "", 1, address(1)
        );
        a[1] = StreamOwnerNoticeTypes.Contact(
            StreamOwnerNoticeTypes.ContactKind.EIP155, "", type(uint256).max, address(1)
        );
        a[2] = StreamOwnerNoticeTypes.Contact(
            StreamOwnerNoticeTypes.ContactKind.HTTPS, "https://EXAMPLE/a", 0, address(0)
        );
        a[3] = StreamOwnerNoticeTypes.Contact(
            StreamOwnerNoticeTypes.ContactKind.HTTPS, "https://example/a", 0, address(0)
        );
        _compare(a, true);
    }

    function testExactUnicodeURIAndOriginalJSONEscapingPreserved() external view {
        StreamOwnerNoticeTypes.Contact[] memory a = _values(2);
        a[0].uri = unicode'https://example/🎨é"\\';
        _compare(a, true);
    }

    function testInactiveFieldsAndMalformedContactRemainRejected() external view {
        StreamOwnerNoticeTypes.Contact[] memory a = _values(3);
        a[0].chainId = 1;
        _compare(a, false);
        a = _values(3);
        a[1].account = address(1);
        _compare(a, false);
        a = _values(3);
        a[2].uri = "https://unused";
        _compare(a, false);
        a = _values(3);
        a[1].uri = "mailto:broken..name@example.org";
        _compare(a, false);
    }

    function testEmptyAndOverTotalBoundRemainRejected() external view {
        _compare(_values(0), false);
        _compare(_values(150), false);
    }

    function testDuplicateWithLaterMalformedRowStillRejects() external view {
        StreamOwnerNoticeTypes.Contact[] memory a = _values(4);
        a[1] = a[0];
        a[3].uri = string(abi.encodePacked("https://", bytes1(0xff)));
        // Rejection is preserved; competing invalid fields do not promise prior error priority.
        _compare(a, false);
    }

    function _longURI(uint256 n, uint8 last) private pure returns (string memory) {
        bytes memory out = new bytes(n);
        bytes memory prefix = "https://";
        for (uint256 i; i < prefix.length; ++i) {
            out[i] = prefix[i];
        }
        for (uint256 i = prefix.length; i < n; ++i) {
            out[i] = "a";
        }
        out[n - 1] = bytes1(last);
        return string(out);
    }

    function testEveryRowTailResidueAndMultipleWordCopyMatchesPriorBytes() external view {
        for (uint256 residue; residue < 32; ++residue) {
            StreamOwnerNoticeTypes.Contact[] memory a = _values(3);
            a[0].uri = _longURI(96 + residue, 0x62);
            _compare(a, true);
        }
    }

    function testOriginalPrefix8192PlusClosingBracketBoundaryIsUnchanged() external view {
        StreamOwnerNoticeTypes.Contact[] memory a = new StreamOwnerNoticeTypes.Contact[](5);
        for (uint256 i; i < a.length; ++i) {
            a[i] = StreamOwnerNoticeTypes.Contact(
                StreamOwnerNoticeTypes.ContactKind.HTTPS,
                _longURI(1600, uint8(98 + i)),
                0,
                address(0)
            );
        }
        uint256 oldLength = bytes(this.prior(a)).length;
        require(oldLength < 8193 && 1600 + 8193 - oldLength <= 2048, "literal prior boundary shape");
        a[4].uri = _longURI(1600 + 8193 - oldLength, 0x66);
        _compare(a, true);
        require(
            bytes(this.current(a)).length == 8193,
            "old Fields includes final bracket after prefix bound"
        );
        a[4].uri = string.concat(a[4].uri, "x");
        _compare(a, false);
    }

    function testFuzzPermutationAndInjectedDuplicate(uint256 seed, uint8 size, bool duplicate)
        external
        view
    {
        uint256 n = 2 + uint256(size) % 31;
        StreamOwnerNoticeTypes.Contact[] memory a = _values(n);
        for (uint256 i = n; i > 1;) {
            --i;
            seed = uint256(keccak256(abi.encode(seed, i)));
            uint256 j = seed % (i + 1);
            (a[i], a[j]) = (a[j], a[i]);
        }
        if (duplicate) a[n - 1] = a[0];
        _compare(a, !duplicate);
    }
}
