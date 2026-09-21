// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    StreamViewCeremonyInputEncoding as Wire
} from "../../helpers/StreamViewCeremonyInputEncoding.sol";

contract ViewCeremonyInputEncodingProbe {
    function name(uint256 index) external pure returns (string memory) {
        return Wire.memberName(index);
    }

    function digest(bytes calldata raw) external pure returns (bytes32) {
        return Wire.digest(raw);
    }

    function size(uint256 raw) external pure returns (uint64) {
        return Wire.byteSize(raw);
    }
}

contract StreamViewCeremonyInputEncodingTest {
    function testPackageMemberNamesMatchExistingPaddedProducer() external pure {
        require(
            keccak256(bytes(Wire.memberName(0))) == keccak256("member-00000000000000000000.json")
        );
        require(
            keccak256(bytes(Wire.memberName(19))) == keccak256("member-00000000000000000019.json")
        );
        require(
            keccak256(bytes(Wire.memberName(type(uint64).max)))
                == keccak256("member-18446744073709551615.json")
        );
    }

    function testPackageMemberIndexOverflowRejectsWithoutTruncation() external {
        ViewCeremonyInputEncodingProbe probe = new ViewCeremonyInputEncodingProbe();
        (bool ok, bytes memory reason) =
            address(probe).call(abi.encodeCall(probe.name, (uint256(type(uint64).max) + 1)));
        require(
            !ok
                && keccak256(reason)
                    == keccak256(abi.encodeWithSelector(Wire.InvalidMemberIndex.selector))
        );
    }

    function testPackageDigestRejectsShortLongAndZero() external {
        ViewCeremonyInputEncodingProbe probe = new ViewCeremonyInputEncodingProbe();
        bytes memory valid = abi.encode(keccak256("actual digest width"));
        require(probe.digest(valid) == keccak256("actual digest width"));
        bytes[3] memory invalid = [new bytes(31), bytes.concat(valid, hex"01"), new bytes(32)];
        for (uint256 i; i < invalid.length; ++i) {
            (bool ok, bytes memory reason) =
                address(probe).call(abi.encodeCall(probe.digest, (invalid[i])));
            require(
                !ok
                    && keccak256(reason)
                        == keccak256(abi.encodeWithSelector(Wire.InvalidDigest.selector))
            );
        }
    }

    function testPackageSizeRejectsZeroAndOverflow() external {
        ViewCeremonyInputEncodingProbe probe = new ViewCeremonyInputEncodingProbe();
        require(probe.size(1) == 1 && probe.size(type(uint64).max) == type(uint64).max);
        uint256[2] memory invalid = [uint256(0), uint256(type(uint64).max) + 1];
        for (uint256 i; i < invalid.length; ++i) {
            (bool ok, bytes memory reason) =
                address(probe).call(abi.encodeCall(probe.size, (invalid[i])));
            require(
                !ok
                    && keccak256(reason)
                        == keccak256(abi.encodeWithSelector(Wire.InvalidByteSize.selector))
            );
        }
    }
}
