// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    IStreamViewPreservationRendererV1 as API
} from "../../interfaces/stream/metadata/IStreamViewPreservationRendererV1.sol";
import {
    IStreamPreservationAttributionV1 as Attribution
} from "../../interfaces/stream/metadata/IStreamPreservationAttributionV1.sol";
import { IERC165 } from "../../vendor/openzeppelin/IERC165.sol";
import {
    IStreamGasParameterHost as Gas
} from "../../interfaces/stream/parameters/IStreamGasParameterHost.sol";
import {
    StreamViewAdoptionTypes as V
} from "../../interfaces/stream/metadata/StreamViewAdoptionTypes.sol";
import { StreamViewAdoptionReads as Read } from "./StreamViewAdoptionReads.sol";
import { StreamViewPreservationReadsV1 as Output } from "./StreamViewPreservationReadsV1.sol";
import { StreamViewRendererEncodingV2 as Encoding } from "./StreamViewRendererEncodingV2.sol";
import "../../interfaces/stream/finality/StreamArtworkFinalityTypes.sol";

/// @notice Separately named preservation profile; only final-sanction attribution is omitted.
/// @dev Stable construction is independent of any future per-plan renderer or adoption/provider.
contract StreamViewPreservationRendererV1 is API, IERC165 {
    bytes32 public constant PROFILE = keccak256("6529STREAM_ADOPTED_POLICY_VIEW_PRESERVATION_V1");
    Configuration private _configuration;
    bytes32 public immutable override configurationHash;
    bytes32 private immutable _workerCodeHash;
    bytes32 private immutable _encodingCodeHash;

    constructor(Configuration memory c) {
        if (
            c.chainId != block.chainid || c.rendererGas < 50000 || c.rendererGas > 14000000
                || c.attributionGas < 50000 || c.attributionGas > 14000000
        ) revert V.InvalidViewAdoption();
        Read.pin(c.core, c.coreCodeHash);
        Read.pin(c.router, c.routerCodeHash);
        Read.pin(c.preservationAttribution, c.preservationAttributionCodeHash);
        (address router, bytes32 pin) = Read.selected(c.core, keccak256("METADATA_ROUTER"), 100000);
        if (
            router != c.router || pin != c.routerCodeHash
                || Read.addr(c.router, abi.encodeWithSignature("core()"), 100000) != c.core
                || Read.addr(
                        c.preservationAttribution, abi.encodeCall(Attribution.core, ()), 100000
                    ) != c.core
                || Read.addr(
                        c.preservationAttribution, abi.encodeCall(Attribution.router, ()), 100000
                    ) != c.router
                || bytes32(
                        Read.word(
                            c.preservationAttribution,
                            abi.encodeCall(Attribution.preservationAttributionProfile, ()),
                            100000
                        )
                    ) != keccak256("6529STREAM_NON_SANCTION_ATTRIBUTION_V1")
        ) revert V.InvalidViewAdoption();
        _configuration = c;
        _workerCodeHash = address(Output).codehash;
        _encodingCodeHash = address(Encoding).codehash;
        Read.pin(address(Output), _workerCodeHash);
        Read.pin(address(Encoding), _encodingCodeHash);
        configurationHash = keccak256(
            abi.encode(
                PROFILE,
                block.chainid,
                address(this),
                c,
                address(Output),
                _workerCodeHash,
                address(Encoding),
                _encodingCodeHash
            )
        );
    }

    function supportsInterface(bytes4 id) external pure returns (bool) {
        return id == type(API).interfaceId || id == type(IERC165).interfaceId;
    }

    function preservationProfile() external pure returns (bytes32) {
        return PROFILE;
    }

    function configuration() external view returns (Configuration memory) {
        return _configuration;
    }

    function workerBinding() external view returns (address, bytes32) {
        return (address(Output), _workerCodeHash);
    }

    function encodingBinding() external view returns (address, bytes32) {
        return (address(Encoding), _encodingCodeHash);
    }

    function preservationViewBinding(bytes32 key) external view returns (Binding memory) {
        Configuration memory c = _configuration;
        bytes memory raw =
            _worker(abi.encodeWithSelector(Output.binding.selector, c, key, _validate(c)), 192);
        Binding memory result = abi.decode(raw, (Binding));
        if (keccak256(raw) != keccak256(abi.encode(result))) revert V.InvalidViewAdoption();
        return result;
    }

    function preservationViewJSON(StreamFinalityScope calldata scope, uint256 token)
        external
        view
        returns (bytes32, string memory)
    {
        return _current(scope, token, 2);
    }

    function preservationViewHTML(StreamFinalityScope calldata scope, uint256 token)
        external
        view
        returns (bytes32, string memory)
    {
        return _current(scope, token, 3);
    }

    function historicalPreservationViewJSON(bytes32 key, uint256 token)
        external
        view
        returns (StreamFinalityScope memory scope, string memory output)
    {
        (, scope, output) = _serve(token, key, true, 2);
    }

    function historicalPreservationViewHTML(bytes32 key, uint256 token)
        external
        view
        returns (StreamFinalityScope memory scope, string memory output)
    {
        (, scope, output) = _serve(token, key, true, 3);
    }

    function _current(StreamFinalityScope memory scope, uint256 token, uint8 mode)
        private
        view
        returns (bytes32 record, string memory output)
    {
        if (
            scope.scopeType != StreamFinalityScopeType.VIEW || scope.collectionId == 0
                || scope.tokenId != 0 || scope.scopeId == 0
        ) revert V.InvalidViewAdoption();
        StreamFinalityScope memory seen;
        (record, seen, output) = _serve(token, scope.scopeId, false, mode);
        if (keccak256(abi.encode(seen)) != keccak256(abi.encode(scope))) {
            revert V.InvalidViewAdoption();
        }
    }

    function _serve(uint256 token, bytes32 key, bool historical, uint8 mode)
        private
        view
        returns (bytes32, StreamFinalityScope memory, string memory)
    {
        Configuration memory c = _configuration;
        bytes memory raw = _worker(
            abi.encodeWithSelector(
                Output.serve.selector, c, token, key, historical, mode, _validate(c)
            ),
            262368
        );
        (bytes32 record, StreamFinalityScope memory scope, string memory output) =
            abi.decode(raw, (bytes32, StreamFinalityScope, string));
        if (
            bytes(output).length > 262144
                || keccak256(raw) != keccak256(abi.encode(record, scope, output))
        ) revert V.InvalidViewAdoption();
        return (record, scope, output);
    }

    /// @dev Fixed compiler-linked target, all coordinates explicitly passed; no storage reference
    /// or delegate context is needed. Failed calls preserve their original bounded error bytes.
    function _worker(bytes memory input, uint256 maximum) private view returns (bytes memory raw) {
        address target = address(Output);
        bool ok;
        uint256 size;
        assembly ("memory-safe") {
            ok := staticcall(gas(), target, add(input, 32), mload(input), 0, 0)
            size := returndatasize()
        }
        if (size > maximum) revert V.InvalidViewAdoption();
        raw = new bytes(size);
        assembly ("memory-safe") { returndatacopy(add(raw, 32), 0, size) }
        if (!ok) assembly ("memory-safe") { revert(add(raw, 32), mload(raw)) }
    }

    function _validate(Configuration memory c) private view returns (uint256) {
        if (c.chainId != block.chainid) revert V.InvalidViewAdoption();
        Read.pin(c.core, c.coreCodeHash);
        Read.pin(c.router, c.routerCodeHash);
        Read.pin(c.preservationAttribution, c.preservationAttributionCodeHash);
        Read.pin(address(Output), _workerCodeHash);
        Read.pin(address(Encoding), _encodingCodeHash);
        return Read.word(
            c.router,
            abi.encodeCall(Gas.gasParameter, (keccak256("6529STREAM_GGP_ROUTER_BUNDLE_READ_GAS"))),
            100000
        );
    }
}
