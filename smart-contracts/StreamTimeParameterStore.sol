// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./StreamTimeParameterHost.sol";

/// @notice Standalone deployable Governed Time Parameter store — the concrete
///         host shape for [LTA-GTP] inventory rows (the entropy coordinator's
///         genesis windows once that satellite embeds the pattern) and the
///         reference host exercised by the [LTA-GTP] conformance discipline suite.
/// @dev    The parameter set is fixed in the constructor: registration happens at
///         deployment only, pinning genesis value, immutable block floor,
///         immutable wall-clock floor, cadence-probe binding, and recency bound
///         per [LTA-GTP] definition items 1-6. By construction the store has no
///         emergency path and no permissionless conditional raise or re-lower
///         (change discipline 1; ADR 0012 decision T1).
contract StreamTimeParameterStore is StreamTimeParameterHost {
    /// @param authority The governance action executor seam
    ///        (`IStreamGovernedParameterAuthority`), or address(0) for a store
    ///        with no governance.
    /// @param configs The full parameter inventory hosted by this store.
    constructor(address authority, TimeParameterConfig[] memory configs)
        StreamTimeParameterHost(authority)
    {
        uint256 count = configs.length;
        for (uint256 i = 0; i < count; ) {
            _registerTimeParameter(configs[i]);
            unchecked {
                ++i;
            }
        }
    }
}
