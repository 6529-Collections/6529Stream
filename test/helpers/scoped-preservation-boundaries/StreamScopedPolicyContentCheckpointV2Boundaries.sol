// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    IStreamCollectionMetadataV1
} from "../../../smart-contracts/interfaces/stream/metadata/IStreamCollectionMetadataV1.sol";
import {
    IStreamRendererRegistry as V
} from "../../../smart-contracts/interfaces/stream/metadata/IStreamRendererRegistry.sol";
import { TerminalRouteVersions } from "./StreamTerminalEntropyRoutingBoundaries.sol";
import {
    IStreamCurrentCitationRenderer as CurrentRenderer
} from "../../../smart-contracts/interfaces/stream/metadata/IStreamCurrentCitationRenderer.sol";
import {
    IStreamCurrentCitationRegistry as ScopedCitation
} from "../../../smart-contracts/interfaces/stream/metadata/IStreamCurrentCitationRegistry.sol";

/// @dev Typed admission boundary, shared by both genuine renderer instances. This does not
/// stand in for a governed ModuleRegistry or the Renderer Registry's analysis/golden evidence.
contract ScopedPolicyOutputModulesBoundary {
    address public immutable metadata;
    address public immutable governanceExecutor;
    mapping(address => bool) public rendererRegistries;
    bool public enabled = true;

    constructor(address m) {
        metadata = m;
        governanceExecutor = msg.sender;
    }

    function admit(address registry) external {
        rendererRegistries[registry] = true;
    }

    function setEnabled(bool value) external {
        enabled = value;
    }

    function isModuleEligible(address a, bytes32 kind, bytes4 id) external view returns (bool) {
        return enabled
            && ((a == metadata
                    && kind == keccak256("COLLECTION_METADATA")
                    && id == type(IStreamCollectionMetadataV1).interfaceId)
                || (rendererRegistries[a]
                    && kind == keccak256("RENDERER_REGISTRY")
                    && id == type(V).interfaceId));
    }
}

contract ScopedPolicyOutputVersionsBoundary is TerminalRouteVersions {
    address private immutable actualRenderer;

    constructor(address e, address s, address r) TerminalRouteVersions(e, s, r) {
        actualRenderer = r;
    }

    function requireCurrentCitation(bytes32 k)
        external
        view
        override
        returns (address, bytes32, bytes32, bytes4)
    {
        require(admitted && k == key, "separate current citation admission");
        return (
            actualRenderer,
            actualRenderer.codehash,
            keccak256("6529STREAM_CURRENT_BASE_CITATION_V1"),
            CurrentRenderer.renderCurrent.selector
        );
    }

    function terminalEntropyRecord(bytes32 k)
        external
        view
        returns (ScopedCitation.CurrentRecord memory r)
    {
        require(admitted && k == key, "separate terminal admission");
        r.registration.versionKey = k;
        r.registrationHash =
            keccak256(abi.encode("typed terminal program admission", actualRenderer));
    }
}
