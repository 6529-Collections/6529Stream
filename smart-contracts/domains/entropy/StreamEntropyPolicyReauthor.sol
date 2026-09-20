// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { StreamEntropyPolicyInventory as I } from "./StreamEntropyPolicyInventory.sol";
import { StreamEntropyRecoveryPolicies as R } from "./StreamEntropyRecoveryPolicies.sol";
import { StreamEntropyIncidentParameters as Gas } from "./StreamEntropyIncidentParameters.sol";
import {
    IStreamEntropyRecoveryPolicies as RP
} from "../../interfaces/stream/entropy/IStreamEntropyRecoveryPolicies.sol";
import {
    IStreamEntropyPolicyContinuity as C
} from "../../interfaces/stream/entropy/IStreamEntropyPolicyContinuity.sol";

/// @notice Imported content may become local only when its next used providers accept this host.
/// @dev Original local configurations retain their admission rules; operational fee changes do not
/// reauthor content and never invoke this guard. No original provider or recovery tuple is changed.
library StreamEntropyPolicyReauthor {
    bytes32 private constant AUTH_GAS =
        keccak256("6529STREAM_GGP_ENTROPY_RELAY_AUTH_READ_GAS_LIMIT");

    function requireLocalProviders(
        uint256 id,
        address provider,
        bytes32 recoveryId,
        uint16 attempts
    ) public view {
        I.Store storage inventory = I.store();
        if (!inventory.inventoried[id] || inventory.origins[id].origin == address(this)) return;
        if (provider != address(0)) _caller(provider);
        if (attempts == 0) return;
        (RP.FreshRecoveryPolicy memory recovery,,,) = R.recordLocal(recoveryId);
        if (attempts > recovery.steps.length) revert C.InvalidEntropyPolicyImport();
        for (uint256 i; i < attempts; ++i) {
            _caller(recovery.steps[i].provider);
        }
    }

    function _caller(address provider) private view {
        if (provider.code.length == 0) revert C.EntropyPolicyImportDependency(provider);
        bytes memory data = abi.encodeWithSignature("coordinator()");
        bytes memory result = new bytes(32);
        uint256 cap = Gas.value(AUTH_GAS);
        uint256 available = gasleft();
        if (available <= 15000 || (available - 15000) / 64 * 63 < cap) {
            revert C.EntropyPolicyImportDependency(provider);
        }
        bool ok;
        uint256 size;
        assembly ("memory-safe") {
            ok := staticcall(cap, provider, add(data, 32), mload(data), add(result, 32), 32)
            size := returndatasize()
        }
        if (!ok || size != 32 || abi.decode(result, (uint256)) != uint256(uint160(address(this)))) {
            revert C.EntropyPolicyImportDependency(provider);
        }
    }
}
