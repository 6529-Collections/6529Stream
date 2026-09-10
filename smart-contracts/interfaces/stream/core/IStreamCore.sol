// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../../../vendor/openzeppelin/IERC165.sol";
import "../../../vendor/openzeppelin/IERC2981.sol";
import "../../../vendor/openzeppelin/IERC721Metadata.sol";
import "../../standards/IERC7572.sol";
import "./IStreamCoreCollectionView.sol";
import "./IStreamCoreCollectionManagement.sol";
import "./IStreamCoreIdentity.sol";
import "./IStreamCoreEnumeration.sol";
import "./IStreamCoreMint.sol";
import "./IStreamCoreBurn.sol";
import "./IStreamCorePointers.sol";
import "./IStreamCoreGasParameters.sol";
import "./IStreamCoreMetadataEmitters.sol";
import "./StreamCoreTypes.sol";

/// @notice Complete permanent StreamCore API; capabilities remain separately importable.
/// @dev This aggregate declares no functions of its own. Its ERC165 ID and every
///      capability ID retain the original inheritance and selector arithmetic.
interface IStreamCore is
    IERC165,
    IERC721Metadata,
    IERC2981,
    IERC7572,
    IStreamCoreCollectionManagement,
    IStreamCoreIdentity,
    IStreamCoreEnumeration,
    IStreamCoreMint,
    IStreamCoreBurn,
    IStreamCorePointers,
    IStreamCoreGasParameters,
    IStreamCoreMetadataEmitters
{ }
