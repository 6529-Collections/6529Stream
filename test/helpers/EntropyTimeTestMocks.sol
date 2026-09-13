// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./GovernedParameterTestMocks.sol";
import "../../smart-contracts/interfaces/stream/parameters/IStreamTimeParameterHost.sol";

/// @notice Explicit unit execution-context boundary; actual Executor coverage lives in current tests.
abstract contract EntropyTimeAuthorityFixture is MockGovernedParameterAuthority {
    constructor() MockGovernedParameterAuthority(true) { }
}

library EntropyTimeTestConfigs {
    function parameters()
        internal
        pure
        returns (IStreamTimeParameterHost.TimeParameterConfig[3] memory rows)
    {
        rows[0] = IStreamTimeParameterHost.TimeParameterConfig(
            "ENTROPY_REQUEST_TIMEOUT_BLOCKS", 10, 5, 60
        );
        rows[1] =
            IStreamTimeParameterHost.TimeParameterConfig("ENTROPY_REVEAL_SLO_BLOCKS", 10, 5, 60);
        rows[2] = IStreamTimeParameterHost.TimeParameterConfig(
            "ENTROPY_RECOVERY_STEP_DELAY_BLOCKS", 10, 5, 60
        );
    }
}
