// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./helpers/CharacterizationTestBase.sol";
import "../smart-contracts/domains/governance/StreamGovernanceBootstrap.sol";

contract StreamGovernanceBytesTest is CharacterizationTestBase {
    function testWordComparisonHandlesBoundariesAndAllDifferencePositions() public {
        uint256[8] memory lengths = [uint256(0), 1, 31, 32, 33, 63, 64, 97];
        for (uint256 k; k < lengths.length; ++k) {
            bytes memory a = new bytes(lengths[k]);
            bytes memory b = new bytes(lengths[k]);
            require(StreamGovernanceBootstrap.bytesEqual(a, b), "equal bytes");
            require(!StreamGovernanceBootstrap.bytesEqual(a, new bytes(a.length + 1)), "different lengths");
            for (uint256 i; i < a.length; ++i) {
                b[i] = 0x01;
                require(!StreamGovernanceBootstrap.bytesEqual(a, b), "changed byte");
                b[i] = 0;
            }
        }
    }

    function testFuzzWordComparisonMatchesReference(bytes memory a, bytes memory b) public {
        bool equal = a.length == b.length;
        if (equal) {
            for (uint256 i; i < a.length; ++i) {
                if (a[i] != b[i]) { equal = false; break; }
            }
        }
        require(StreamGovernanceBootstrap.bytesEqual(a, b) == equal, "reference equality");
        require(StreamGovernanceBootstrap.bytesEqual(a, a), "identical arbitrary bytes");
    }
}
