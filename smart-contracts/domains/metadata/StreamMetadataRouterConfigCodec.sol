// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    IStreamStaticMetadataRouter as S
} from "../../interfaces/stream/metadata/IStreamStaticMetadataRouter.sol";
import { StreamMetadataRouterContent as Content } from "./StreamMetadataRouterContent.sol";
import {
    StreamMetadataStaticConfiguration as Configuration
} from "./StreamMetadataStaticConfiguration.sol";

/// @notice Fixed input codec; the original configuration worker owns every check and write.
/// @dev The Router performs its original collection/token guards before this delegate frame.
library StreamMetadataRouterConfigCodec {
    function write(
        Content.Layout memory layout,
        Content.Context memory context,
        uint256 collectionId,
        uint256 tokenId,
        bytes calldata input
    ) public returns (bytes32) {
        bytes4 selector = bytes4(input[:4]);
        S.ConfigInput memory value;
        if (selector == S.setDefaultMetadataConfig.selector) {
            value = abi.decode(input[4:], (S.ConfigInput));
        } else if (
            selector == S.setCollectionMetadataConfig.selector
                || selector == S.setTokenMetadataConfig.selector
        ) {
            (, value) = abi.decode(input[4:], (uint256, S.ConfigInput));
        } else {
            revert S.InvalidStaticMetadataConfig();
        }
        return Configuration.set(layout, context, collectionId, tokenId, value);
    }

    function preview(Content.Context memory context, bytes calldata input)
        public
        view
        returns (bytes32)
    {
        if (bytes4(input[:4]) != S.previewStaticMetadataConfig.selector) {
            revert S.InvalidStaticMetadataConfig();
        }
        (uint256 collectionId, uint256 tokenId, S.ConfigInput memory value) =
            abi.decode(input[4:], (uint256, uint256, S.ConfigInput));
        return Configuration.preview(context, collectionId, tokenId, value);
    }
}
