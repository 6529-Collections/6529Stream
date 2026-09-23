// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamArtistPlatformCorrectionReads as Reads
} from "../../../smart-contracts/domains/artist/StreamArtistPlatformCorrectionReads.sol";
import {
    StreamArtistPlatformTypes as PW
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistPlatformTypes.sol";
import {
    StreamArtistPlatformCorrectionLineageTypes as PL
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistPlatformCorrectionLineage.sol";

/// @notice Independent typed ABI/reference admission versus exact raw six-word consumer.
contract StreamArtistPlatformCorrectionStatusTest {
    function raw(PW.State calldata p, bytes calldata value) external pure returns (bool) {
        return Reads.effectiveEncoded(p, value);
    }

    function typedOracle(PW.State calldata p, bytes calldata value) external pure returns (bool) {
        require(value.length == 192);
        PL.Status memory r = abi.decode(value, (PL.Status));
        require(r.originalCorrectionRecord == p.correction.recordHash);
        if (r.count == 0) {
            require(
                r.latestLineageRecord == 0 && r.generation == 0 && !r.effectiveAccepted
                    && r.latestAcceptanceRecord == 0
            );
        } else {
            require(
                r.latestLineageRecord != 0 && r.generation > p.correction.correctiveGeneration
                    && r.count == r.generation - p.correction.correctiveGeneration
                    && r.effectiveAccepted == (r.latestAcceptanceRecord != 0)
            );
        }
        return r.effectiveAccepted;
    }

    function _parity(PW.State memory p, bytes memory value) private view {
        (bool a, bytes memory x) = address(this).staticcall(abi.encodeCall(this.raw, (p, value)));
        (bool b, bytes memory y) =
            address(this).staticcall(abi.encodeCall(this.typedOracle, (p, value)));
        require(
            a == b && (!a || keccak256(x) == keccak256(y)),
            "independent typed admission and exact result"
        );
    }

    function testFuzzRawStatusMatchesTypedReference(
        bytes32[6] memory words,
        uint64 first,
        bytes32 original
    ) public view {
        PW.State memory p;
        p.correction.recordHash = original;
        p.correction.correctiveGeneration = first;
        _parity(p, abi.encode(words));
    }

    function testFuzzValidRowsAndSingleFieldCorruption(
        uint64 first,
        uint64 count,
        bytes32 head,
        bytes32 accepted
    ) public view {
        first = uint64(uint256(first) % 1_000_000);
        count = uint64(uint256(count) % 1_000_000) + 1;
        if (head == 0) head = bytes32(uint256(1));
        PW.State memory p;
        p.correction.recordHash = keccak256("original");
        p.correction.correctiveGeneration = first;
        PL.Status memory r =
            PL.Status(p.correction.recordHash, head, first + count, count, accepted != 0, accepted);
        _parity(p, abi.encode(r));
        for (uint256 i; i < 6; ++i) {
            bytes memory value = abi.encode(r);
            assembly ("memory-safe") {
                let at := add(add(value, 32), mul(i, 32))
                mstore(at, xor(mload(at), shl(255, 1)))
            }
            _parity(p, value);
        }
    }

    function testZeroUnknownStatusAndExactLength() public view {
        PW.State memory p;
        p.correction.recordHash = keccak256("original");
        PL.Status memory r;
        r.originalCorrectionRecord = p.correction.recordHash;
        _parity(p, abi.encode(r));
        _parity(p, new bytes(191));
        _parity(p, new bytes(193));
        r.effectiveAccepted = true;
        _parity(p, abi.encode(r));
        r.effectiveAccepted = false;
        r.latestAcceptanceRecord = bytes32(uint256(1));
        _parity(p, abi.encode(r));
    }
}
