// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    IStreamViewCheckpointServingV2 as API
} from "../../interfaces/stream/metadata/IStreamViewCheckpointServingV2.sol";
import {
    IStreamGasParameterHost as Gas
} from "../../interfaces/stream/parameters/IStreamGasParameterHost.sol";
import { IERC165 } from "../../vendor/openzeppelin/IERC165.sol";
import {
    StreamViewAdoptionTypes as V
} from "../../interfaces/stream/metadata/StreamViewAdoptionTypes.sol";
import { StreamViewAdoptionReads as Read } from "./StreamViewAdoptionReads.sol";
import { StreamViewCheckpointReadsV2 as Output } from "./StreamViewCheckpointReadsV2.sol";
import "../../interfaces/stream/finality/StreamArtworkFinalityTypes.sol";

/// @notice Read-only exact-source adapter. Publication authority remains on the original Router.
contract StreamViewCheckpointServingV2 is API, IERC165 {
    Binding private _binding;
    bytes32 public immutable override configurationHash;
    bytes32 private immutable _workerCodeHash;

    constructor(Binding memory b) {
        if (b.chainId != block.chainid || b.rendererGas < 50000 || b.rendererGas > 14000000) {
            revert V.InvalidViewAdoption();
        }
        Read.pin(b.core, b.coreCodeHash);
        Read.pin(b.router, b.routerCodeHash);
        (address router, bytes32 hash) = Read.selected(b.core, keccak256("METADATA_ROUTER"), 100000);
        if (
            router != b.router || hash != b.routerCodeHash
                || Read.addr(b.router, abi.encodeWithSignature("core()"), 100000) != b.core
        ) {
            revert V.InvalidViewAdoption();
        }
        _binding = b;
        _workerCodeHash = address(Output).codehash;
        Read.pin(address(Output), _workerCodeHash);
        configurationHash = keccak256(
            abi.encode(
                keccak256("6529STREAM_VIEW_CHECKPOINT_SERVING_V2"),
                block.chainid,
                address(this),
                b,
                address(Output),
                _workerCodeHash
            )
        );
    }

    function binding() external view override returns (Binding memory) {
        return _binding;
    }

    function workerBinding() external view override returns (address, bytes32) {
        return (address(Output), _workerCodeHash);
    }

    function supportsInterface(bytes4 id) external pure override returns (bool) {
        return id == type(API).interfaceId || id == type(IERC165).interfaceId;
    }

    function currentOutput(StreamFinalityScope calldata scope, uint256 tokenId, uint8 mode)
        external
        view
        override
        returns (bytes32 record, string memory output)
    {
        if (
            scope.scopeType != StreamFinalityScopeType.VIEW || scope.collectionId == 0
                || scope.tokenId != 0 || scope.scopeId == 0
        ) revert V.InvalidViewAdoption();
        StreamFinalityScope memory observed;
        (record, observed, output) = _serve(tokenId, scope.scopeId, false, mode);
        if (keccak256(abi.encode(observed)) != keccak256(abi.encode(scope))) {
            revert V.InvalidViewAdoption();
        }
    }

    function historicalOutput(bytes32 record, uint256 tokenId, uint8 mode)
        external
        view
        override
        returns (StreamFinalityScope memory scope, string memory output)
    {
        (, scope, output) = _serve(tokenId, record, true, mode);
    }

    function _serve(uint256 tokenId, bytes32 key, bool historical, uint8 mode)
        private
        view
        returns (bytes32, StreamFinalityScope memory, string memory)
    {
        Binding memory b = _binding;
        if (b.chainId != block.chainid) revert V.InvalidViewAdoption();
        Read.pin(b.core, b.coreCodeHash);
        Read.pin(b.router, b.routerCodeHash);
        Read.pin(address(Output), _workerCodeHash);
        uint256 readGas = Read.word(
            b.router,
            abi.encodeCall(Gas.gasParameter, (keccak256("6529STREAM_GGP_ROUTER_BUNDLE_READ_GAS"))),
            100000
        );
        return
            Output.serve(b.router, b.core, tokenId, key, historical, mode, readGas, b.rendererGas);
    }
}
