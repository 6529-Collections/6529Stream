// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    IStreamCurrentTestPaidStackDeployment,
    IStreamCurrentTestPaidStackFoundation,
    IStreamCurrentTestPaidStackProducts,
    IStreamCurrentTestPaidStackActivation
} from "./StreamCurrentTestPaidStackDeployment.sol";
import { ArtistArtifactCreate } from "./ArtistArtifactCreate.sol";

/// @dev Child phase code is created by this helper, never by the paid host.
contract StreamCurrentTestPaidWaivedStackDeployment is ArtistArtifactCreate, IStreamCurrentTestPaidStackDeployment {
    address private immutable _deploymentHost = msg.sender;
    address private immutable _foundation;
    address private immutable _products;
    address private immutable _activation;
    address private immutable _productsActivation;
    address private immutable _artistActivation;

    constructor(address artistSuiteDeployment_) {
        _foundation = _artistArtifactCreate(
            "test/helpers/StreamCurrentTestPaidWaivedStackFoundation.sol:StreamCurrentTestPaidWaivedStackFoundation",
            abi.encode(msg.sender)
        );
        _products = _artistArtifactCreate(
            "test/helpers/StreamCurrentTestPaidWaivedStackProducts.sol:StreamCurrentTestPaidWaivedStackProducts",
            abi.encode(msg.sender, artistSuiteDeployment_)
        );
        _activation = _artistArtifactCreate(
            "test/helpers/StreamCurrentTestPaidWaivedStackActivation.sol:StreamCurrentTestPaidWaivedStackActivation",
            abi.encode(msg.sender, artistSuiteDeployment_)
        );
        _productsActivation = _artistArtifactCreate(
            "test/helpers/StreamCurrentTestPaidWaivedStackProductsActivation.sol:StreamCurrentTestPaidWaivedStackProductsActivation",
            abi.encode(msg.sender)
        );
        _artistActivation = _artistArtifactCreate(
            "test/helpers/StreamCurrentTestPaidWaivedStackArtistActivation.sol:StreamCurrentTestPaidWaivedStackArtistActivation",
            abi.encode(msg.sender)
        );
    }

    function deployCurrentStack(address artist_, address platform) external override {
        require(address(this) == _deploymentHost, "original paid host delegatecall required");
        _delegate(_foundation, abi.encodeCall(
            IStreamCurrentTestPaidStackFoundation.deployFoundation, (artist_)
        ));
        _delegate(_products, abi.encodeCall(
            IStreamCurrentTestPaidStackProducts.deployProducts, (platform)
        ));
        _delegate(_activation, abi.encodeCall(
            IStreamCurrentTestPaidStackActivation.activateStack, ()
        ));
        _delegate(_productsActivation, abi.encodeCall(
            IStreamCurrentTestPaidStackActivation.activateStack, ()
        ));
        _delegate(_artistActivation, abi.encodeCall(
            IStreamCurrentTestPaidStackActivation.activateStack, ()
        ));
    }

    function _delegate(address target, bytes memory data) private {
        (bool ok, bytes memory result) = target.delegatecall(data);
        if (!ok) { assembly ("memory-safe") { revert(add(result, 32), mload(result)) } }
    }

}
