// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "./IStreamFinalityComponentFacts.sol";

/// @notice Fixed provider's authoritative host identity for each supported serving family.
/// @dev componentHost is constructor-fixed, family-qualified and rejects unsupported families.
///      Facts derive raw source, locks and scope inventory; they never call the adapter or a
///      routed tokenURI. Historical reads preserve these hosts after current pointer replacement.
interface IStreamFinalityServingEvidenceProvider is IStreamFinalityComponentFacts {
    function metadataHost() external view returns (address);
    function componentHost(bytes32 componentType) external view returns (address);
}
