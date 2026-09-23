// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../helpers/CurrentSafeOwnerConfigurationFixture.sol";

/// @notice Nine actual-current authorization recipes; native execution remains pending.
contract StreamCurrentSafeOwnerConfigurationTest is CurrentSafeOwnerConfigurationFixture {
    function testSafe130ThresholdChangeStaleProofExactRetry() public {
        _thresholdConfiguration("1.3.0");
    }

    function testSafe141ThresholdChangeStaleProofExactRetry() public {
        _thresholdConfiguration("1.4.1");
    }

    function testSafe150ThresholdChangeStaleProofExactRetry() public {
        _thresholdConfiguration("1.5.0");
    }

    function testSafe130OwnerReplacementArtistReceiptAndPaidMint() public {
        _replacementConfiguration("1.3.0");
    }

    function testSafe141OwnerReplacementArtistReceiptAndPaidMint() public {
        _replacementConfiguration("1.4.1");
    }

    function testSafe150OwnerReplacementArtistReceiptAndPaidMint() public {
        _replacementConfiguration("1.5.0");
    }

    function testSafe130NestedOwnerRevocationExactPaidRetryAndZeroValueTransfer() public {
        _nestedConfiguration("1.3.0");
    }

    function testSafe141NestedOwnerRevocationExactPaidRetryAndZeroValueTransfer() public {
        _nestedConfiguration("1.4.1");
    }

    function testSafe150NestedOwnerRevocationExactPaidRetryAndZeroValueTransfer() public {
        _nestedConfiguration("1.5.0");
    }
}
