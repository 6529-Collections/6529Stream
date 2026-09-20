// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    StreamArtistOwnerCommit as Hash
} from "../../../smart-contracts/domains/artist/StreamArtistOwnerCommit.sol";

contract OwnerReplayPureCaller {
    function derive(Hash.Environment calldata e, address owner, bytes32 surface, bytes32 scope)
        external
        pure
        returns (bytes32)
    {
        return Hash.replayKey(e, owner, surface, scope);
    }
}

/// @notice Independent original flat-word preimages for the pure replay-key encoder.
/// @dev Original StreamArtistOwnerAdmissionTest separately exercises actual _consume/commit guards.
contract StreamArtistOwnerReplayHashTest {
    function _word(address value) private pure returns (bytes32) {
        return bytes32(uint256(uint160(value)));
    }

    function testFuzzExactOriginalNineWords(
        uint256 chainId,
        address registry,
        address coordinator,
        address archive,
        address owner,
        bytes32 domain,
        bytes32 surface,
        bytes32 scope
    ) public pure {
        Hash.Environment memory e =
            Hash.Environment(chainId, registry, coordinator, archive, domain);
        bytes32[9] memory original = [
            keccak256("6529STREAM_ARTIST_OWNER_REPLAY_KEY_V2"),
            bytes32(chainId),
            _word(registry),
            _word(coordinator),
            _word(archive),
            _word(owner),
            domain,
            surface,
            scope
        ];
        require(
            Hash.replayKey(e, owner, surface, scope) == keccak256(abi.encode(original)),
            "original flat words"
        );
    }

    function testCallerAndLiveChainAreNotImplicitHashInputs() public {
        OwnerReplayPureCaller first = new OwnerReplayPureCaller();
        OwnerReplayPureCaller second = new OwnerReplayPureCaller();
        Hash.Environment memory e =
            Hash.Environment(123456789, address(1), address(2), address(3), bytes32(uint256(4)));
        address owner = address(5);
        bytes32 surface = bytes32(uint256(6));
        bytes32 scope = bytes32(uint256(7));
        bytes32[9] memory original = [
            keccak256("6529STREAM_ARTIST_OWNER_REPLAY_KEY_V2"),
            bytes32(uint256(123456789)),
            bytes32(uint256(1)),
            bytes32(uint256(2)),
            bytes32(uint256(3)),
            bytes32(uint256(5)),
            bytes32(uint256(4)),
            bytes32(uint256(6)),
            bytes32(uint256(7))
        ];
        bytes32 expected = keccak256(abi.encode(original));
        require(
            first.derive(e, owner, surface, scope) == expected, "first caller exact explicit owner"
        );
        require(
            second.derive(e, owner, surface, scope) == expected,
            "second caller exact explicit owner"
        );
        require(
            Hash.replayKey(e, address(first), surface, scope) != expected,
            "owner is still committed"
        );
    }

    function testAllZeroTypedFieldsRetainOriginalDomainTag() public pure {
        Hash.Environment memory e;
        bytes32[9] memory original;
        original[0] = keccak256("6529STREAM_ARTIST_OWNER_REPLAY_KEY_V2");
        require(
            Hash.replayKey(e, address(0), bytes32(0), bytes32(0))
                == keccak256(abi.encode(original)),
            "zero fields original domain"
        );
    }
}
