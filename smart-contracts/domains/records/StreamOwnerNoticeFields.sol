// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./StreamRecordJson.sol";
import "../../interfaces/stream/metadata/StreamOwnerNoticeTypes.sol";

/// @notice Closed references and notice endpoints; no identity or delivery assertion.
library StreamOwnerNoticeFields {
    error InvalidNoticeWitness();

    function referenceJSON(StreamOwnerNoticeTypes.Reference memory r)
        public
        pure
        returns (string memory)
    {
        if (r.canonicalizationId == 0 || r.algorithm == 0 || r.algorithm > 6) {
            revert InvalidNoticeWitness();
        }
        if (r.algorithm == 4 || r.algorithm == 5) {
            if (r.digest.length == 0 || r.digest.length > 128) revert InvalidNoticeWitness();
        } else if (r.digest.length != 32) {
            revert InvalidNoticeWitness();
        }
        _contentURI(r.uri);
        return string.concat(
            '{"hash":{"algorithm":',
            string(abi.encodePacked(bytes1(uint8(48 + r.algorithm)))),
            ',"canonicalizationId":',
            StreamRecordJson.hexValue(r.canonicalizationId),
            ',"digest":',
            _hexBytes(r.digest),
            '},"uri":',
            StreamRecordJson.quote(r.uri, 2048, false),
            "}"
        );
    }

    function contacts(StreamOwnerNoticeTypes.Contact[] memory values)
        public
        pure
        returns (string memory)
    {
        if (values.length == 0) revert InvalidNoticeWitness();
        bytes[] memory rows = new bytes[](values.length);
        bytes32[] memory hashes = new bytes32[](values.length);
        uint256 length = 1;
        for (uint256 i; i < values.length; ++i) {
            rows[i] = bytes(contact(values[i]));
            hashes[i] = keccak256(rows[i]);
            length += rows[i].length + (i == 0 ? 0 : 1);
            if (length > 8192) revert InvalidNoticeWitness();
        }
        _requireUnique(hashes);
        // Preserve the original prefix bound, then append its closing bracket exactly.
        bytes memory out = new bytes(length + 1);
        out[0] = "[";
        uint256 offset = 1;
        for (uint256 i; i < rows.length; ++i) {
            if (i != 0) out[offset++] = ",";
            _copyRow(rows[i], out, offset);
            offset += rows[i].length;
        }
        out[offset] = "]";
        return string(out);
    }

    /// @dev Only complete words and remaining actual bytes are copied; no padded tail write.
    function _copyRow(bytes memory row, bytes memory out, uint256 offset) private pure {
        assembly ("memory-safe") {
            let size := mload(row)
            let source := add(row, 32)
            let target := add(add(out, 32), offset)
            let cursor := 0
            for { } iszero(gt(add(cursor, 32), size)) { cursor := add(cursor, 32) } {
                mstore(add(target, cursor), mload(add(source, cursor)))
            }
            if lt(cursor, size) {
                let tail := mload(add(source, cursor))
                let index := 0
                for { } lt(cursor, size) {
                    cursor := add(cursor, 1)
                    index := add(index, 1)
                } { mstore8(add(target, cursor), byte(index, tail)) }
            }
        }
    }

    /// @dev Sort only hashes; emitted contacts retain their original order. Heap construction
    /// and extraction bound uniqueness work to O(n log n), without recursion or an item cap.
    function _requireUnique(bytes32[] memory hashes) private pure {
        uint256 n = hashes.length;
        for (uint256 i = n / 2; i != 0;) {
            --i;
            _siftDown(hashes, i, n);
        }
        for (uint256 end = n; end > 1;) {
            --end;
            (hashes[0], hashes[end]) = (hashes[end], hashes[0]);
            _siftDown(hashes, 0, end);
        }
        for (uint256 i = 1; i < n; ++i) {
            if (hashes[i - 1] == hashes[i]) revert InvalidNoticeWitness();
        }
    }

    function _siftDown(bytes32[] memory hashes, uint256 root, uint256 n) private pure {
        while (root < n / 2) {
            uint256 child = root * 2 + 1;
            if (child + 1 < n && hashes[child] < hashes[child + 1]) ++child;
            if (hashes[root] >= hashes[child]) return;
            (hashes[root], hashes[child]) = (hashes[child], hashes[root]);
            root = child;
        }
    }

    function contact(StreamOwnerNoticeTypes.Contact memory c) public pure returns (string memory) {
        if (c.kind == StreamOwnerNoticeTypes.ContactKind.EIP155) {
            if (bytes(c.uri).length != 0 || c.chainId == 0) revert InvalidNoticeWitness();
            return string.concat(
                '{"account":',
                StreamRecordJson.account(c.account),
                ',"chainId":',
                StreamRecordJson.unsigned(c.chainId),
                ',"kind":"eip155"}'
            );
        }
        if (c.chainId != 0 || c.account != address(0)) revert InvalidNoticeWitness();
        if (c.kind == StreamOwnerNoticeTypes.ContactKind.HTTPS) {
            bytes memory u = bytes(c.uri);
            if (u.length < 9 || keccak256(_prefix(u, 8)) != keccak256("https://")) {
                revert InvalidNoticeWitness();
            }
            _contentURI(c.uri);
        } else {
            _mailto(bytes(c.uri));
        }
        return string.concat(
            '{"kind":',
            c.kind == StreamOwnerNoticeTypes.ContactKind.HTTPS ? '"https"' : '"mailto"',
            ',"uri":',
            StreamRecordJson.quote(c.uri, 2048, false),
            "}"
        );
    }

    function references(StreamOwnerNoticeTypes.Reference[] memory values)
        public
        pure
        returns (string memory)
    {
        string memory out = "[";
        for (uint256 i; i < values.length; ++i) {
            out = string.concat(out, i == 0 ? "" : ",", referenceJSON(values[i]));
            if (bytes(out).length > 8192) revert InvalidNoticeWitness();
        }
        return string.concat(out, "]");
    }

    function _hexBytes(bytes memory input) private pure returns (string memory) {
        bytes memory alphabet = "0123456789abcdef";
        bytes memory out = new bytes(4 + input.length * 2);
        out[0] = '"';
        out[1] = "0";
        out[2] = "x";
        out[out.length - 1] = '"';
        for (uint256 i; i < input.length; ++i) {
            out[3 + i * 2] = alphabet[uint8(input[i]) >> 4];
            out[4 + i * 2] = alphabet[uint8(input[i]) & 15];
        }
        return string(out);
    }

    function _contentURI(string memory value) private pure {
        StreamMetadataRenderer.requireValidUtf8ContentUri(
            bytes32("NOTICE_REFERENCE"), value, 2048, false
        );
    }

    function _prefix(bytes memory value, uint256 n) private pure returns (bytes memory out) {
        out = new bytes(n);
        for (uint256 i; i < n; ++i) {
            out[i] = value[i];
        }
    }

    /// @dev Single ASCII dot-atom mailbox and DNS-style host. No headers, quoted local or escapes.
    function _mailto(bytes memory u) private pure {
        if (u.length < 10 || u.length > 2048 || keccak256(_prefix(u, 7)) != keccak256("mailto:")) {
            revert InvalidNoticeWitness();
        }
        uint256 at;
        for (uint256 i = 7; i < u.length; ++i) {
            uint8 c = uint8(u[i]);
            if (c == 64) {
                if (at != 0 || i == 7 || u[i - 1] == ".") revert InvalidNoticeWitness();
                at = i;
            } else if (at == 0) {
                bool letter = (c >= 65 && c <= 90) || (c >= 97 && c <= 122);
                bool digit = c >= 48 && c <= 57;
                if (!(letter || digit || c == 46 || c == 95 || c == 43 || c == 45)) {
                    revert InvalidNoticeWitness();
                }
                if (c == 46 && (i == 7 || u[i - 1] == ".")) revert InvalidNoticeWitness();
            } else {
                bool letter = (c >= 65 && c <= 90) || (c >= 97 && c <= 122);
                bool digit = c >= 48 && c <= 57;
                if (!(letter || digit || c == 46 || c == 45)) revert InvalidNoticeWitness();
                if ((i == at + 1 || u[i - 1] == ".") && (c == 46 || c == 45)) {
                    revert InvalidNoticeWitness();
                }
                if (c == 46 && u[i - 1] == "-") revert InvalidNoticeWitness();
            }
        }
        if (at == 0 || at + 1 == u.length || u[u.length - 1] == "." || u[u.length - 1] == "-") {
            revert InvalidNoticeWitness();
        }
    }
}
