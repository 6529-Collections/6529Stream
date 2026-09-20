// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    IStreamViewRouteReadBudgetV1 as Budget
} from "../../interfaces/stream/finality/IStreamViewRouteReadBudgetV1.sol";
import {
    IStreamFinalityDeploymentBindings as Finality
} from "../../interfaces/stream/finality/IStreamFinalityDeploymentBindings.sol";
import {
    IStreamViewSourceBinding as Binding
} from "../../interfaces/stream/finality/IStreamViewSourceBinding.sol";
import {
    StreamViewAdoptionTypes as V
} from "../../interfaces/stream/metadata/StreamViewAdoptionTypes.sol";
import { IERC165 } from "../../vendor/openzeppelin/IERC165.sol";

/// @notice Fixed VIEW-only interpretation of an explicitly declared governed budget.
/// @dev The caller has already authenticated the selected Finality and its global cap.
/// Unsupported providers keep that original cap; declared invalid/pending providers fail.
/// Every original caller still performs its full selected-source and currentness checks.
library StreamViewRouteReadBudgetV1 {
    bytes32 internal constant PROFILE = keccak256("6529STREAM_GOVERNED_VIEW_ROUTE_READ_BUDGET_V1");
    error InvalidViewRouteReadBudget(address provider);

    function select(address finality, uint256 originalCap)
        public
        view
        returns (uint256 cap, bool governed)
    {
        cap = originalCap;
        // This optional bootstrap never substitutes for the original legacy validations.
        (bool ok, bytes memory raw) =
            _read(finality, abi.encodeCall(Finality.scopeEvidenceProvider, ()), 32, 100000);
        if (!ok) return (cap, false);
        uint256 word = abi.decode(raw, (uint256));
        if (word == 0 || word > type(uint160).max) return (cap, false);
        address provider = address(uint160(word));
        (ok, raw) = _read(
            provider,
            abi.encodeCall(IERC165.supportsInterface, (type(Budget).interfaceId)),
            32,
            100000
        );
        if (!ok || abi.decode(raw, (uint256)) != 1) return (cap, false);
        // Once the provider advertises this profile, no error may fall back to legacy.
        (ok, raw) =
            _read(finality, abi.encodeCall(Finality.scopeEvidenceProviderCodeHash, ()), 32, 100000);
        if (!ok || provider.code.length == 0 || abi.decode(raw, (bytes32)) != provider.codehash) {
            revert InvalidViewRouteReadBudget(provider);
        }
        (ok, raw) = _read(provider, abi.encodeCall(Budget.viewRouteReadBudget, ()), 64, 100000);
        if (!ok) revert InvalidViewRouteReadBudget(provider);
        (bytes32 profile, uint256 declaredCap) = abi.decode(raw, (bytes32, uint256));
        if (
            profile != PROFILE || declaredCap < 50000 || declaredCap > 16777216
                || declaredCap > originalCap
        ) revert InvalidViewRouteReadBudget(provider);
        // Bind the cheap getter to the full original six-word declaration. It is not
        // an independent allowance, projection, configuration cache or new authority.
        (ok, raw) = _read(provider, abi.encodeCall(Binding.viewSourceBinding, ()), 192, declaredCap);
        if (!ok) revert InvalidViewRouteReadBudget(provider);
        V.Binding memory binding = abi.decode(raw, (V.Binding));
        if (
            keccak256(raw) != keccak256(abi.encode(binding)) || binding.readGas != declaredCap
                || binding.sourceGas < binding.readGas
        ) revert InvalidViewRouteReadBudget(provider);
        return (declaredCap, true);
    }

    function _read(address target, bytes memory input, uint256 size, uint256 cap)
        private
        view
        returns (bool ok, bytes memory raw)
    {
        // Preserve full forwarding and bound returndata before allocation/copy.
        if (gasleft() <= cap + cap / 63 + 5000) return (false, raw);
        uint256 actual;
        assembly ("memory-safe") {
            ok := staticcall(cap, target, add(input, 32), mload(input), 0, 0)
            actual := returndatasize()
        }
        if (!ok || actual != size) return (false, raw);
        raw = new bytes(size);
        assembly ("memory-safe") { returndatacopy(add(raw, 32), 0, size) }
    }
}
