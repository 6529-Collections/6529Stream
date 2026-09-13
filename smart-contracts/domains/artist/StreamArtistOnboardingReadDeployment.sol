// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "./StreamArtistOnboardingReads.sol";

/// @notice Compiler-linked CREATE preserves the Coordinator as the original Reads creator.
library StreamArtistOnboardingReadDeployment {
    function deployReader(T.SuiteConfiguration memory suite)
        public
        returns (StreamArtistOnboardingReads)
    {
        return new StreamArtistOnboardingReads(suite);
    }
}
