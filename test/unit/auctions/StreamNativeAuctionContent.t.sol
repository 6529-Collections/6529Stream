// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../../../smart-contracts/domains/auctions/StreamNativeAuctionContent.sol";

interface AuctionContentVm {
    function chainId(uint256 value) external;
}

/// @dev Authenticates the linked caller domain only; no fixture pretends to publish or mint.
contract NativeAuctionContentHarness {
    function check(
        bytes32 saleId,
        bytes32 commitment,
        bytes32 root,
        bytes memory data,
        StreamNativeAuctionContent.Selection memory selection
    ) external view returns (StreamNativeAuctionContent.Verified memory) {
        return StreamNativeAuctionContent.requireArtwork(saleId, commitment, root, data, selection);
    }
}

contract StreamNativeAuctionContentTest {
    AuctionContentVm private constant vm =
        AuctionContentVm(address(uint160(uint256(keccak256("hevm cheat code")))));
    bytes32 private constant SALE = keccak256("original auction sale");
    NativeAuctionContentHarness private host;
    uint256 private originalChain;

    function setUp() public {
        originalChain = block.chainid;
        host = new NativeAuctionContentHarness();
    }

    // Literal normative preimages, independently reproduced outside the linked implementation.
    function _leaf(address adapter, uint256 chain, bytes32 sale, bytes32 id, bytes32 dataHash)
        private
        pure
        returns (bytes32)
    {
        return keccak256(
            abi.encodePacked(
                keccak256(
                    abi.encode(
                        keccak256("6529STREAM_CONTENT_LEAF_V1"), chain, adapter, sale, id, dataHash
                    )
                )
            )
        );
    }

    function _context(address adapter, uint256 chain, bytes32 sale, bytes32 id)
        private
        pure
        returns (bytes32)
    {
        return keccak256(
            abi.encode(keccak256("6529STREAM_CONTENT_CONTEXT_V1"), chain, adapter, sale, id)
        );
    }

    function _pair(bytes32 a, bytes32 b) private pure returns (bytes32) {
        return a < b ? keccak256(abi.encodePacked(a, b)) : keccak256(abi.encodePacked(b, a));
    }

    function _reject(
        bytes32 sale,
        bytes32 commitment,
        bytes32 root,
        bytes memory data,
        StreamNativeAuctionContent.Selection memory selection
    ) private view {
        (bool ok,) = address(host)
            .staticcall(abi.encodeCall(host.check, (sale, commitment, root, data, selection)));
        require(!ok, "changed original content must reject");
    }

    function testExactDataAndEmptyBytesPreserveHashIdentityAndRejectInactiveLeafFields()
        public
        view
    {
        StreamNativeAuctionContent.Selection memory none;
        bytes memory raw = bytes("actual work bytes");
        StreamNativeAuctionContent.Verified memory r =
            host.check(SALE, keccak256(raw), 0, raw, none);
        require(
            r.actualTokenDataHash == keccak256(raw) && r.contentSelectionHash == keccak256(raw)
                && r.contentContextHash == 0,
            "exact-data identity"
        );
        r = host.check(SALE, keccak256(""), 0, "", none);
        require(
            r.actualTokenDataHash == keccak256("") && r.actualTokenDataHash != 0
                && r.contentSelectionHash == r.actualTokenDataHash && r.contentContextHash == 0,
            "empty is not absent"
        );
        _reject(SALE, keccak256(raw), 0, bytes("substitute"), none);
        _reject(0, keccak256(raw), 0, raw, none);
        _reject(SALE, 0, 0, raw, none);
        none.contentId = bytes32(uint256(1));
        _reject(SALE, keccak256(raw), 0, raw, none);
        none.contentId = 0;
        none.tokenDataHash = keccak256(raw);
        _reject(SALE, keccak256(raw), 0, raw, none);
        none.tokenDataHash = 0;
        none.proof = new bytes32[](1);
        _reject(SALE, keccak256(raw), 0, raw, none);
    }

    function testZeroContentIdEmptyTokenDataAndSingleLeafTreeAreValid() public view {
        StreamNativeAuctionContent.Selection memory s;
        s.tokenDataHash = keccak256("");
        bytes32 leaf = _leaf(address(host), block.chainid, SALE, 0, s.tokenDataHash);
        StreamNativeAuctionContent.Verified memory r = host.check(SALE, leaf, leaf, "", s);
        require(
            r.actualTokenDataHash == keccak256("") && r.contentSelectionHash == leaf
                && r.contentContextHash == _context(address(host), block.chainid, SALE, 0)
                && r.contentSelectionHash != r.actualTokenDataHash,
            "full original leaf and context domains"
        );
        s.proof = new bytes32[](1);
        s.proof[0] = leaf;
        _reject(SALE, leaf, leaf, "", s);
    }

    function testCuratedProofRejectsLeafDataRootSaleChainAndAdapterSubstitution() public {
        bytes memory data = bytes("curated original");
        StreamNativeAuctionContent.Selection memory s;
        s.contentId = keccak256("content 7");
        s.tokenDataHash = keccak256(data);
        s.proof = new bytes32[](2);
        s.proof[0] = _leaf(
            address(host), block.chainid, SALE, keccak256("content 8"), keccak256("other bytes")
        );
        s.proof[1] = keccak256("another subtree");
        bytes32 leaf = _leaf(address(host), block.chainid, SALE, s.contentId, s.tokenDataHash);
        bytes32 root = _pair(_pair(leaf, s.proof[0]), s.proof[1]);
        StreamNativeAuctionContent.Verified memory r = host.check(SALE, leaf, root, data, s);
        require(
            r.actualTokenDataHash == keccak256(data) && r.contentSelectionHash == leaf
                && r.contentContextHash
                    == _context(address(host), block.chainid, SALE, s.contentId),
            "actual two-level sorted proof"
        );
        _reject(SALE, leaf ^ bytes32(uint256(1)), root, data, s);
        _reject(SALE, leaf, root ^ bytes32(uint256(1)), data, s);
        _reject(SALE, leaf, root, bytes("curated substitute"), s);
        _reject(SALE ^ bytes32(uint256(1)), leaf, root, data, s);
        s.contentId ^= bytes32(uint256(1));
        _reject(SALE, leaf, root, data, s);
        s.contentId ^= bytes32(uint256(1));
        s.tokenDataHash ^= bytes32(uint256(1));
        _reject(SALE, leaf, root, data, s);
        s.tokenDataHash ^= bytes32(uint256(1));
        s.proof[0] ^= bytes32(uint256(1));
        _reject(SALE, leaf, root, data, s);
        s.proof[0] ^= bytes32(uint256(1));
        NativeAuctionContentHarness other = new NativeAuctionContentHarness();
        (bool ok,) =
            address(other).staticcall(abi.encodeCall(other.check, (SALE, leaf, root, data, s)));
        require(!ok, "different linked host rejects original tree");
        // Retained before this test: the optimizer treats CHAINID as transaction-stable.
        uint256 chain = originalChain;
        vm.chainId(chain + 1);
        _reject(SALE, leaf, root, data, s);
        vm.chainId(chain);
        r = host.check(SALE, leaf, root, data, s);
        require(r.contentSelectionHash == leaf, "original restored proof");
    }

    function testDoubleHashCannotBeReplacedByInnerLeafHash() public view {
        bytes memory data = bytes("double hash boundary");
        StreamNativeAuctionContent.Selection memory s;
        s.contentId = bytes32(uint256(12));
        s.tokenDataHash = keccak256(data);
        bytes32 inner = keccak256(
            abi.encode(
                keccak256("6529STREAM_CONTENT_LEAF_V1"),
                block.chainid,
                address(host),
                SALE,
                s.contentId,
                s.tokenDataHash
            )
        );
        bytes32 outer = keccak256(abi.encodePacked(inner));
        _reject(SALE, inner, inner, data, s);
        _reject(SALE, outer, inner, data, s);
        require(
            host.check(SALE, outer, outer, data, s).contentSelectionHash == outer,
            "double hash accepted"
        );
    }

    function testFuzzCanonicalLeafContextAndMutatedBytes(
        bytes32 contentId,
        bytes32 seed,
        bool right
    ) public view {
        bytes memory data = abi.encode(seed);
        StreamNativeAuctionContent.Selection memory s;
        s.contentId = contentId;
        s.tokenDataHash = keccak256(data);
        bytes32 leaf = _leaf(address(host), block.chainid, SALE, contentId, s.tokenDataHash);
        bytes32 sibling = _leaf(
            address(host),
            block.chainid,
            SALE,
            contentId ^ bytes32(uint256(1)),
            keccak256(abi.encode(seed, uint256(1)))
        );
        s.proof = new bytes32[](1);
        s.proof[0] = sibling;
        bytes32 root = right ? _pair(sibling, leaf) : _pair(leaf, sibling);
        StreamNativeAuctionContent.Verified memory r = host.check(SALE, leaf, root, data, s);
        require(
            r.actualTokenDataHash == s.tokenDataHash && r.contentSelectionHash == leaf
                && r.contentContextHash == _context(address(host), block.chainid, SALE, contentId),
            "independent original preimages"
        );
        data[0] = bytes1(uint8(data[0]) ^ 1);
        _reject(SALE, leaf, root, data, s);
    }
}
