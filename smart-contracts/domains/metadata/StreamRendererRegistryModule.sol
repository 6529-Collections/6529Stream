// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import { StreamRendererRegistry } from "./StreamRendererRegistry.sol";
import { StreamModuleBase } from "../modules/StreamModuleBase.sol";
import { IStreamModule } from "../../interfaces/stream/modules/IStreamModule.sol";
import {
    IStreamRendererRegistry as V
} from "../../interfaces/stream/metadata/IStreamRendererRegistry.sol";

/// @notice Module-admissible deployment of the unchanged governed renderer registry producer.
contract StreamRendererRegistryModule is StreamRendererRegistry, StreamModuleBase {
    struct Deployment {
        address executor;
        address schemas;
        V.Target[] targets;
        GasParameterConfig readGas;
        GasParameterConfig goldenGas;
        bytes32 deploymentManifestHash;
        string manifestURI;
        bytes32 manifestHash;
    }

    constructor(Deployment memory d)
        StreamRendererRegistry(d.executor, d.schemas, d.targets, d.readGas, d.goldenGas)
        StreamModuleBase(
            keccak256("STREAM_RENDERER_REGISTRY_ABI_V1"),
            address(0),
            d.deploymentManifestHash,
            d.manifestURI,
            d.manifestHash
        )
    {
        if (
            d.deploymentManifestHash == 0 || d.manifestHash == 0
                || bytes(d.manifestURI).length > 2048
        ) {
            revert InvalidRendererRegistration();
        }
    }

    function streamModuleType() public pure override returns (bytes32) {
        return keccak256("RENDERER_REGISTRY");
    }

    function streamModuleVersion() public pure override returns (bytes32) {
        return bytes32(uint256(1));
    }

    function streamModuleInterfaceId() public pure override returns (bytes4) {
        return type(V).interfaceId;
    }

    function supportsInterface(bytes4 id)
        public
        pure
        override(StreamRendererRegistry, StreamModuleBase)
        returns (bool)
    {
        return StreamRendererRegistry.supportsInterface(id) || id == type(IStreamModule).interfaceId;
    }
}
