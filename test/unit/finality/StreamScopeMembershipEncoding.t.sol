// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../../../smart-contracts/domains/finality/StreamScopeMembershipEncoding.sol";

contract StreamScopeMembershipEncodingTest {
    function decodeManifest(bytes calldata raw)
        external
        pure
        returns (StreamScopeMembershipManifest memory)
    {
        return StreamScopeMembershipEncoding.decode(raw);
    }

    function encodeManifest(StreamScopeMembershipManifest calldata manifest)
        external
        pure
        returns (bytes memory)
    {
        return StreamScopeMembershipEncoding.encode(manifest);
    }

    function _manifest(uint256 count)
        private
        pure
        returns (StreamScopeMembershipManifest memory m)
    {
        m.version = 1;
        m.chainId = 31337;
        m.core = address(0x1234);
        m.collectionId = 9;
        m.scopeType = 2;
        m.tokenCount = count;
        m.tokenListHash = count == 0 ? keccak256("") : bytes32(uint256(0xAABB));
        m.chunkHashes = new bytes32[]((count + 255) / 256);
        for (uint256 i; i < m.chunkHashes.length; ++i) {
            m.chunkHashes[i] = bytes32(i + 1);
        }
    }

    function testFlatManifestHasLiteralCanonicalHeadAndArray() public pure {
        StreamScopeMembershipManifest memory m = _manifest(257);
        // Eight flat head words, then array length and two hash words. No outer struct offset.
        bytes memory expected = bytes.concat(
            hex"0000000000000000000000000000000000000000000000000000000000000001",
            hex"0000000000000000000000000000000000000000000000000000000000007a69",
            hex"0000000000000000000000000000000000000000000000000000000000001234",
            hex"0000000000000000000000000000000000000000000000000000000000000009",
            hex"0000000000000000000000000000000000000000000000000000000000000002",
            hex"0000000000000000000000000000000000000000000000000000000000000101",
            hex"000000000000000000000000000000000000000000000000000000000000aabb",
            hex"0000000000000000000000000000000000000000000000000000000000000100",
            hex"0000000000000000000000000000000000000000000000000000000000000002",
            hex"0000000000000000000000000000000000000000000000000000000000000001",
            hex"0000000000000000000000000000000000000000000000000000000000000002"
        );
        require(expected.length == 352, "literal 11-word payload");
        require(
            keccak256(StreamScopeMembershipEncoding.encode(m)) == keccak256(expected),
            "literal payload"
        );
        require(
            keccak256(abi.encode(StreamScopeMembershipEncoding.decode(expected)))
                == keccak256(abi.encode(m)),
            "literal typed decoding"
        );
    }

    function testRejectHeaderWidthOffsetsTrailingAndWrongCount() public view {
        bytes memory raw = StreamScopeMembershipEncoding.encode(_manifest(257));
        _reject(abi.encodePacked(raw, bytes32(0)));
        bytes memory short_ = new bytes(287);
        _reject(short_);
        uint256[7] memory positions = [uint256(0), 2, 4, 7, 8, 5, 9];
        uint256[7] memory values =
            [uint256(0x10001), uint256(1) << 160, uint256(0x102), 288, 65, 1, 0];
        for (uint256 i; i < positions.length; ++i) {
            bytes memory changed = bytes.concat(raw);
            uint256 at = positions[i];
            uint256 value = values[i];
            assembly ("memory-safe") { mstore(add(add(changed, 32), mul(at, 32)), value) }
            _reject(changed);
        }
        _reject(abi.encode(_manifest(257)));
    }

    function testExactStorageMaximumAndCanonicalEmptyList() public view {
        StreamScopeMembershipManifest memory m = _manifest(16384);
        bytes memory raw = StreamScopeMembershipEncoding.encode(m);
        require(
            raw.length == 2336 && StreamScopeMembershipEncoding.decode(raw).tokenCount == 16384,
            "64 native parts fit"
        );
        ++m.tokenCount;
        (bool ok, bytes memory reason) =
            address(this).staticcall(abi.encodeCall(this.encodeManifest, (m)));
        _invalid(ok, reason);
        m = _manifest(0);
        raw = StreamScopeMembershipEncoding.encode(m);
        require(
            raw.length == 288 && StreamScopeMembershipEncoding.decode(raw).chunkHashes.length == 0,
            "exact empty list"
        );
        m.tokenListHash = bytes32(uint256(1));
        (ok, reason) = address(this).staticcall(abi.encodeCall(this.encodeManifest, (m)));
        _invalid(ok, reason);
    }

    function testRecordIdentitySeparatesFamiliesProvenanceAndFactWords() public pure {
        bytes32 record = bytes32(uint256(123));
        bytes32 id = StreamScopeMembershipEncoding.scopeId(31337, address(0x1234), 9, 2, record);
        require(
            id
                == keccak256(
                    abi.encode(
                        keccak256("6529STREAM_SCOPE_MEMBERSHIP_ID_V1"),
                        uint256(31337),
                        address(0x1234),
                        uint256(9),
                        uint8(2),
                        record
                    )
                ),
            "independent six-word record identity"
        );
        require(
            id != StreamScopeMembershipEncoding.scopeId(31337, address(0x1234), 9, 3, record),
            "season separated"
        );
        require(
            id != StreamScopeMembershipEncoding.scopeId(31337, address(0x1234), 9, 4, record),
            "view separated"
        );
        require(
            id
                != StreamScopeMembershipEncoding.scopeId(
                    31337, address(0x1234), 9, 2, bytes32(uint256(124))
                ),
            "provenance separated"
        );
        StreamFinalityScope memory scope =
            StreamFinalityScope(StreamFinalityScopeType.RELEASE, 9, 0, id);
        StreamScopeMembershipFacts memory f = StreamScopeMembershipFacts(
            bytes32(uint256(1)), bytes32(uint256(2)), record, 257, bytes32(uint256(3)), 0, 0, 0
        );
        bytes32 expected = keccak256(
            abi.encode(
                keccak256("6529STREAM_SCOPE_MEMBERSHIP_FACTS_V1"),
                uint256(31337),
                address(0x1234),
                address(0x4567),
                address(0x6789),
                uint8(2),
                uint256(9),
                uint256(0),
                id,
                keccak256(
                    abi.encode(
                        f.scopeSubject,
                        f.scopeManifestHash,
                        record,
                        uint256(257),
                        f.tokenListHash,
                        uint256(0),
                        bytes32(0)
                    )
                )
            )
        );
        require(
            StreamScopeMembershipEncoding.membershipHash(
                31337, address(0x1234), address(0x4567), address(0x6789), scope, f
            ) == expected,
            "independent flat ten-word membership preimage"
        );
        f.membershipHash = expected;
        require(
            StreamScopeMembershipEncoding.membershipHash(
                31337, address(0x1234), address(0x4567), address(0x6789), scope, f
            ) == expected,
            "no hash cycle"
        );
        ++f.tokenCount;
        require(
            StreamScopeMembershipEncoding.membershipHash(
                31337, address(0x1234), address(0x4567), address(0x6789), scope, f
            ) != expected,
            "complete count bound"
        );
    }

    function testFuzzCanonicalRoundTrip(uint16 count, uint8 family, uint256 chainId, bytes32 seed)
        public
        pure
    {
        StreamScopeMembershipManifest memory m = _manifest(uint256(count) % 16385);
        m.scopeType = 2 + family % 3;
        m.chainId = chainId;
        for (uint256 i; i < m.chunkHashes.length; ++i) {
            m.chunkHashes[i] = keccak256(abi.encode(seed, i));
        }
        bytes memory raw = StreamScopeMembershipEncoding.encode(m);
        require(raw.length == 288 + 32 * m.chunkHashes.length, "exact flattened length");
        require(
            keccak256(abi.encode(StreamScopeMembershipEncoding.decode(raw)))
                == keccak256(abi.encode(m)),
            "roundtrip all fields"
        );
    }

    function testFuzzRecordIdentity(
        uint256 chainId,
        uint256 collectionId,
        uint8 family,
        bytes32 record
    ) public pure {
        collectionId |= 1;
        if (record == 0) record = bytes32(uint256(1));
        uint8 kind = 2 + family % 3;
        bytes32 actual = StreamScopeMembershipEncoding.scopeId(
            chainId, address(0x1234), collectionId, kind, record
        );
        bytes memory preimage = bytes.concat(
            abi.encode(keccak256("6529STREAM_SCOPE_MEMBERSHIP_ID_V1")),
            abi.encode(chainId),
            abi.encode(address(0x1234)),
            abi.encode(collectionId),
            abi.encode(kind),
            abi.encode(record)
        );
        require(
            preimage.length == 192 && actual == keccak256(preimage),
            "six independently concatenated words"
        );
    }

    function _reject(bytes memory raw) private view {
        (bool ok, bytes memory reason) =
            address(this).staticcall(abi.encodeCall(this.decodeManifest, (raw)));
        _invalid(ok, reason);
    }

    function _invalid(bool ok, bytes memory reason) private pure {
        require(
            !ok
                && keccak256(reason)
                    == keccak256(
                        abi.encodeWithSelector(
                            StreamScopeMembershipEncoding.InvalidScopeMembershipEncoding.selector
                        )
                    ),
            "exact malformed-manifest error"
        );
    }
}
