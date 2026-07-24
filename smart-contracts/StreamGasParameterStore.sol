// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./StreamGasParameterHost.sol";

/// @notice Standalone deployable Governed Gas Parameter store: the concrete host
///         for parameter-store rows of the [LTA-GGP] inventory (for example the
///         split factory parameter store hosting `ASSET_POLICY_GAS_LIMIT`,
///         `ERC_1271_GAS_LIMIT`, and `WALLET_DEPOSIT_GAS_LIMIT`), and the
///         reference host exercised by the [LTA-GGP] requirement 9 conformance
///         suite.
/// @dev    The parameter set is fixed in the constructor: registration happens at
///         deployment only, with floors, probe bindings, failure classes, recency
///         bounds, and — for `FORWARDING_CAP` rows — the standing conditional
///         raise/re-lower actions all pinned per [LTA-GGP] definition items 2 and 6
///         and requirement 11. Consumers read live values via `gasParameter` /
///         `gasParameterInfo`; contracts that host their own rows embed
///         `StreamGasParameterHost` instead.
contract StreamGasParameterStore is StreamGasParameterHost {
    /// @param authority The governance action executor seam
    ///        (`IStreamGovernedParameterAuthority`), or address(0) for a store with
    ///        no governance — conditional paths remain live for `FORWARDING_CAP`
    ///        rows per [LTA-GGP] requirement 11.
    /// @param core_ The immutable Core source of the live module-registry pointer.
    /// @param genesisModuleRegistry_ The expected genesis registry committed into
    ///        every constructor-time probe binding.
    /// @param configs The full parameter inventory hosted by this store.
    constructor(
        address authority,
        address core_,
        address genesisModuleRegistry_,
        GasParameterConfig[] memory configs
    ) StreamGasParameterHost(authority, core_, genesisModuleRegistry_) {
        uint256 count = configs.length;
        for (uint256 i = 0; i < count;) {
            _registerGasParameter(configs[i]);
            unchecked {
                ++i;
            }
        }
    }
}
