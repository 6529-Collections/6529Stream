// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { StreamMetadataRenderTypes } from "./StreamMetadataRenderTypes.sol";
import { IStreamMetadataServingFacts } from "./IStreamMetadataServingFacts.sol";

/// @notice Exact stateless renderer ABI for the stable presentation profile.
/// @dev This caller subset does not assert ERC165 or authorize a renderer. Finality selects
///      and pins its host and runtime before the router calls the renderer by STATICCALL.
interface IStreamMetadataTokenRendering {
    /// @notice Canonical abi.encode(Token, ServingSource, bytes artist) using the types above.
    /// @dev The bytes-only external argument also has the same selector for Solidity libraries,
    ///      whose typed struct parameter selectors differ from ordinary contract selectors.
    function renderForFinality(bool asURI, bytes calldata input)
        external
        pure
        returns (string memory);
}
