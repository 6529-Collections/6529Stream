// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamEntropyPolicyConsumerTypes as P
} from "../../interfaces/stream/entropy/StreamEntropyPolicyConsumerTypes.sol";
import {
    StreamMetadataRenderTypes as T
} from "../../interfaces/stream/metadata/StreamMetadataRenderTypes.sol";
import {
    IStreamMetadataServingFacts as F
} from "../../interfaces/stream/metadata/IStreamMetadataServingFacts.sol";
import { StreamMetadataCitation as Citation } from "./StreamMetadataCitation.sol";
import { Strings } from "../../vendor/openzeppelin/Strings.sol";
import { Base64 } from "../../vendor/openzeppelin/Base64.sol";

/// @notice Truthful ordinary metadata only. Executable terminal programs need separate STATIC admission.
library StreamTerminalEntropyJSON {
    using Strings for uint256;
    error TerminalExecutableAdmissionRequired();

    function fields(P.Terminal memory p) internal pure returns (bytes memory) {
        return abi.encodePacked(
            '"entropy_status":"',
            p.status == 1 ? "DISABLED" : "NOT_REQUIRED",
            '","entropy_security_class":"',
            p.policy.securityClass == 0 ? "HIGH_ASSURANCE" : "LOW_SECURITY",
            '","entropy_policy_hash":"',
            uint256(p.policy.policyHash).toHexString(32),
            '","entropy_policy_content_hash":"',
            uint256(p.policy.contentStateHash).toHexString(32),
            '","entropy_mode":"',
            p.policy.mode == 0 ? "DISABLED" : "ASYNC",
            '","entropy_render_requirement":"NOT_REQUIRED","entropy_finalized":false,"entropy_seed_present":false'
        );
    }

    function render(
        uint8 mode,
        T.Token memory t,
        F.ServingSource memory m,
        bytes memory artist,
        bool nestedArtist,
        uint256 chainId,
        address core,
        P.Terminal memory p
    ) public pure returns (string memory) {
        if (mode > 2) revert TerminalExecutableAdmissionRequired();
        string memory result = string(
            abi.encodePacked(
                '{"name":"',
                t.configured ? m.name : "6529 Stream",
                " #",
                t.serial.toString(),
                '","description":"',
                m.description,
                '","image":"',
                m.imageURI,
                '","metadata_schema_version":"6529stream-terminal-entropy-v1","metadata_state":"',
                t.state,
                '","token_id":',
                t.tokenId.toString(),
                ',"collection_id":',
                t.collectionId.toString(),
                ',"collection_serial":',
                t.serial.toString(),
                ',"token_data_base64":"',
                Base64.encode(t.tokenData),
                '","attributes":[]',
                nestedArtist ? bytes("") : artist,
                ',"properties":{"stream":{"render_state":"',
                t.state,
                '","citation":"',
                Citation.work(chainId, core, t.tokenId),
                '",',
                fields(p),
                ',"terminal_executable_admitted":false}',
                nestedArtist
                    ? abi.encodePacked(',"provenance":{"attribution":', artist, "}")
                    : bytes(""),
                "}}"
            )
        );
        return mode == 1
            ? string.concat("data:application/json;base64,", Base64.encode(bytes(result)))
            : result;
    }
}
