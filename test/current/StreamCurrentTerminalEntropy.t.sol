// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../helpers/CurrentTerminalEntropyFixture.sol";

/// @notice Ten bounded actual-current terminal-entropy recipes; joined runtime remains pending.
contract StreamCurrentTerminalEntropyTest is CurrentTerminalEntropyFixture {
    function testDisabledActualArtistConsentGovernanceConfigureAndSeparateFreeze() public {
        _constructTerminal();
        _configureTerminal(true, true);
    }

    function testNotRequiredActualArtistConsentGovernanceConfigureAndSeparateFreeze() public {
        _constructTerminal();
        _configureTerminal(false, true);
    }

    function testDisabledActualSafePaidMintZeroFeeAndOriginalPullCredit() public {
        _constructTerminal();
        _configureTerminal(true, false);
        _paid(true, false);
    }

    function testNotRequiredActualSafePaidMintRetainsFeeAndOriginalPullCredit() public {
        _constructTerminal();
        _configureTerminal(false, false);
        _paid(false, false);
    }

    function testDisabledActualOperatorDistributionHasZeroFeeAndNoTokenRequest() public {
        _constructTerminal();
        _configureTerminal(true, false);
        _distribution(true);
    }

    function testNotRequiredActualOperatorDistributionFundsEachTokenWithoutRequest() public {
        _constructTerminal();
        _configureTerminal(false, false);
        _distribution(false);
    }

    function testDisabledOriginalMintCallbackGuardExactRetryAndLaterCustodyBurn() public {
        _constructTerminal();
        _configureTerminal(true, false);
        _paid(true, true);
    }

    function testNotRequiredOriginalMintCallbackGuardExactRetryAndLaterCustodyBurn() public {
        _constructTerminal();
        _configureTerminal(false, false);
        _paid(false, true);
    }

    function testNotRequiredActualAllocationScopeStillRequestsFinalizesAndClaimsCredit() public {
        _constructTerminal();
        _configureTerminal(false, false);
        _scopeRemainsAsync();
    }

    function testOriginalRequiredAsyncPaidMintStillRequestsAndFinalizes() public {
        _constructTerminal();
        _legacyRequiredControl();
    }
}
