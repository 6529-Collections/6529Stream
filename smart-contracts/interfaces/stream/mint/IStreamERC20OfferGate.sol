// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./IStreamMintGate.sol";
import "./IStreamMintManager.sol";
import "./StreamERC20OfferMintTypes.sol";

/// @notice Dedicated offer admission. The ordinary validateMint route must reject this profile.
interface IStreamERC20OfferGate is IStreamMintGate {
    function publication()
        external
        view
        returns (StreamPreparedNativeContentTypes.Publication memory);
    function gateConfigHash() external view returns (bytes32);
    function manifestBytes() external view returns (bytes memory);
    function itemCount() external view returns (uint256);
    function offerPurchaseVersion() external pure returns (bytes32);

    function validateERC20OfferBatch(
        address manager,
        address house,
        IStreamMintManager.MintBatch calldata batch,
        StreamERC20OfferMintTypes.GateData calldata offerData
    ) external view returns (GateResult memory);
}
