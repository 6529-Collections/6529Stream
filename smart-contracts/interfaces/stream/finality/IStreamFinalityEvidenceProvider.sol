// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./IStreamFinalityMetadataReads.sol";
import "./IStreamFinalityScopeEvidence.sol";

/// @notice Constructor-fixed typed evidence selection over the actual generic metadata record host.
/// @dev All inherited reads derive actual records, bytes, scope membership and serving inventory.
///      The permanent scope-input hash binds metadataHost(), not this provider's address.
interface IStreamFinalityEvidenceProvider is
    IStreamFinalityMetadataReads,
    IStreamFinalityScopeEvidence
{
    /// @notice Actual generic metadata host that must be selected by Core for new candidates.
    function metadataHost() external view returns (address);
}
