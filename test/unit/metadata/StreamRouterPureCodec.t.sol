// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    StreamMetadataRenderPreparation as Preparation
} from "../../../smart-contracts/domains/metadata/StreamMetadataRenderPreparation.sol";
import { Base64 } from "../../../smart-contracts/vendor/openzeppelin/Base64.sol";

contract StreamRouterPureCodecTest {
    function testDefaultContractURIKeepsLiteralBytes() public {
        require(
            keccak256(bytes(Preparation.defaultContractURI()))
                == keccak256(
                    bytes(
                        string.concat(
                            "data:application/json;base64,",
                            Base64.encode(
                                bytes(
                                    '{"name":"6529 Stream","description":"6529 Stream NFT collections."}'
                                )
                            )
                        )
                    )
                )
        );
    }

    function testFuzzPreparedCollectionFieldsPreserveOriginalSerialization(
        string calldata name,
        string calldata description,
        string calldata image,
        bytes calldata attribution
    ) public {
        bytes memory original = abi.encodePacked(
            '{"name":"',
            name,
            '","description":"',
            description,
            '","image":"',
            image,
            '","properties":{"provenance":{"attribution":',
            attribution,
            "}}}"
        );
        require(
            keccak256(
                bytes(Preparation.attributedCollectionURI(name, description, image, attribution))
            )
            == keccak256(
                bytes(string.concat("data:application/json;base64,", Base64.encode(original)))
            )
        );
    }
}
