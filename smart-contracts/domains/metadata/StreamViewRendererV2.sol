// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import { IStreamRenderer as R } from "../../interfaces/stream/metadata/IStreamRenderer.sol";
import {
    IStreamViewRendererV2 as API
} from "../../interfaces/stream/metadata/IStreamViewRendererV2.sol";
import {
    IStreamViewAdoptionRouter as Router
} from "../../interfaces/stream/metadata/IStreamViewAdoptionRouter.sol";
import {
    IStreamCoreIdentity as Identity
} from "../../interfaces/stream/core/IStreamCoreIdentity.sol";
import {
    IStreamCoreCollectionView as Collection
} from "../../interfaces/stream/core/IStreamCoreCollectionView.sol";
import { IStreamCoreMint as Mint } from "../../interfaces/stream/core/IStreamCoreMint.sol";
import {
    IStreamStaticEntropySource as Entropy
} from "../../interfaces/stream/metadata/IStreamStaticEntropySource.sol";
import {
    IStreamFinalityScopeMembership as Membership
} from "../../interfaces/stream/finality/IStreamFinalityScopeMembership.sol";
import {
    StreamViewAdoptionTypes as V
} from "../../interfaces/stream/metadata/StreamViewAdoptionTypes.sol";
import { StreamViewAdoptionReads as Read } from "./StreamViewAdoptionReads.sol";
import { StreamViewPayloadBytes as Bytes } from "./StreamViewPayloadBytes.sol";
import { StreamViewPayloadV2 as Payload } from "./StreamViewPayloadV2.sol";
import { StreamViewRendererFormatV2 as Format } from "./StreamViewRendererFormatV2.sol";
import { StreamViewRendererEncodingV2 as Encoding } from "./StreamViewRendererEncodingV2.sol";
import { StreamGasParameterHost } from "../parameters/StreamGasParameterHost.sol";
import { StreamViewPolicyTypesV2 as T } from "./StreamViewPolicyTypesV2.sol";
import { StreamViewPolicySourceV2 as PolicySource } from "./StreamViewPolicySourceV2.sol";
import {
    IStreamViewAdoptionPolicyRouterV2 as PolicyRouter
} from "../../interfaces/stream/metadata/IStreamViewAdoptionPolicyRouterV2.sol";
import {
    StreamFinalityCoordinatorPolicyV2 as Policy
} from "../../interfaces/stream/finality/StreamFinalityCoordinatorPolicyTypesV2.sol";
import "../../interfaces/stream/finality/StreamArtworkFinalityTypes.sol";

/// @notice Separate admitted STATIC policy VIEW over immutable adopted bytes and actual original tokens.
/// @dev Constructor binds the actual complete scoped policy set. Token validation stays internal; the immutable formatting worker uses STATICCALL.
/// All external serving calls are bounded STATICCALL only. Terminal output is explicit, never finalized.
contract StreamViewRendererV2 is R, API, StreamGasParameterHost {
    bytes32 public constant READ_GAS = keccak256("6529STREAM_GGP_METADATA_DEPENDENCY_READ_GAS");
    bytes32 public constant ATTRIBUTION_GAS = keccak256("6529STREAM_GGP_STATIC_ATTRIBUTION_GAS");
    uint32 public constant MAX_BYTES = 262144;
    address[4] private _targets;
    bytes32[4] private _pins;
    RendererManifest private _manifest;
    uint256 private immutable _chainId;
    bytes32 private immutable _encodingCodeHash;
    T.Binding private _policyBinding;
    Policy[] private _policies;
    mapping(address => uint256) private _positions;

    constructor(
        address[4] memory targets,
        address factory,
        StreamFinalityScope memory scope,
        uint32 policySourceGas,
        address executor,
        GasParameterConfig memory readGas,
        GasParameterConfig memory attributionGas,
        RendererManifest memory manifest
    ) StreamGasParameterHost(executor) {
        if (
            manifest.rendererId != Format.ID || manifest.rendererVersion != Format.VERSION
                || manifest.contextVersion != T.CONTEXT
                || manifest.rendererClass != keccak256("STATIC")
                || manifest.schemaHash != Format.schemaHash() || manifest.manifestHash == 0
                || manifest.deprecated || manifest.maxJSONBytes != MAX_BYTES
                || manifest.maxHTMLBytes != MAX_BYTES || readGas.genesisValue > type(uint32).max
                || readGas.failureClass != 2 || attributionGas.failureClass != 2
                || _registerGasParameter(readGas) != READ_GAS
                || _registerGasParameter(attributionGas) != ATTRIBUTION_GAS
        ) revert V.InvalidViewAdoption();
        for (uint256 i; i < 4; ++i) {
            Read.pin(targets[i], targets[i].codehash);
            _pins[i] = targets[i].codehash;
        }
        (T.Binding memory binding, Policy[] memory policies) = PolicySource.bind(
            targets[0], factory, targets[2], scope, uint32(readGas.genesisValue), policySourceGas
        );
        _policyBinding = binding;
        for (uint256 i; i < policies.length; ++i) {
            if (_positions[policies[i].coordinator] != 0) revert V.InvalidViewAdoption();
            _positions[policies[i].coordinator] = i + 1;
            _policies.push(policies[i]);
        }
        _targets = targets;
        _manifest = manifest;
        _chainId = block.chainid;
        _encodingCodeHash = address(Encoding).codehash;
        Read.pin(address(Encoding), _encodingCodeHash);
        if (
            Read.addr(targets[3], abi.encodeWithSignature("core()"), readGas.genesisValue)
                    != targets[0]
                || Read.addr(targets[3], abi.encodeWithSignature("router()"), readGas.genesisValue)
                    != targets[1]
        ) revert V.InvalidViewAdoption();
    }

    function supportsInterface(bytes4 id) external pure override returns (bool) {
        return id == type(R).interfaceId || id == type(API).interfaceId || id == 0x01ffc9a7;
    }

    function rendererVersion() external pure override returns (bytes32) {
        return Format.VERSION;
    }

    function renderContextVersion() external pure override returns (bytes32) {
        return T.CONTEXT;
    }

    function rendererManifest() external view override returns (RendererManifest memory) {
        return _manifest;
    }

    function sourceBindings()
        external
        view
        override
        returns (address[4] memory, bytes32[4] memory)
    {
        return (_targets, _pins);
    }

    function encodingBinding() external view override returns (address, bytes32) {
        return (address(Encoding), _encodingCodeHash);
    }

    function policyViewBinding() external view override returns (T.Binding memory) {
        return _policyBinding;
    }

    function tokenURI(RenderRequest calldata request)
        external
        view
        override
        returns (string memory)
    {
        return _render(request, 1);
    }

    function renderPolicyView(RenderRequest calldata request, uint8 mode)
        external
        view
        override
        returns (string memory)
    {
        return _render(request, mode);
    }

    function _render(RenderRequest memory r, uint8 mode) private view returns (string memory) {
        if (
            mode > 3 || r.core != _targets[0] || r.mode != MetadataMode.ONCHAIN
                || block.chainid != _chainId
        ) {
            revert V.InvalidViewAdoption();
        }
        // Explicit registration golden only. This empty vector proves no token or adoption.
        if (r.tokenId == 0) {
            if (
                r.collectionId != 0 || r.collectionSerial != 0 || r.tokenHash != 0 || r.viewId != 0
                    || r.viewManifestHash != 0 || r.metadataSnapshotHash != 0
                    || r.collectionSupplyMode != 0 || r.collectionStatus != 0
                    || r.state != TokenRenderState.PENDING_RANDOMNESS
            ) revert V.InvalidViewAdoption();
            string memory empty = mode == 3
                ? "<html><head></head><body></body></html>"
                : '{"state":"unconfigured_view"}';
            return mode == 1
                ? "data:application/json;base64,eyJzdGF0ZSI6InVuY29uZmlndXJlZF92aWV3In0="
                : empty;
        }
        for (uint256 i; i < 4; ++i) {
            Read.pin(_targets[i], _pins[i]);
        }
        uint256 cap = _gasParameterValue(READ_GAS);
        bytes memory raw = Read.recordBytes(_targets[1], r.metadataSnapshotHash, cap);
        V.Record memory saved = abi.decode(raw, (V.Record));
        if (
            keccak256(raw) != keccak256(abi.encode(saved))
                || saved.recordHash != r.metadataSnapshotHash
                || saved.source.route.router != _targets[1]
                || saved.source.route.routerCodeHash != _pins[1]
                || saved.source.route.core != _targets[0]
                || saved.source.route.coreCodeHash != _pins[0]
                || saved.source.renderer.renderer != address(this)
                || saved.source.renderer.rendererCodeHash != address(this).codehash
                || saved.input.scope.collectionId != r.collectionId
                || saved.input.viewId != r.viewId
                || saved.input.viewRecordHash != r.viewManifestHash || saved.artistConsent == 0
                || saved.source.renderer.contextVersion != T.CONTEXT
                || keccak256(abi.encode(saved.input.scope))
                    != keccak256(abi.encode(_policyBinding.scope))
                || keccak256(abi.encode(saved.source.membership))
                    != keccak256(abi.encode(_policyBinding.membership))
                || bytes32(
                        Read.word(
                            _targets[1],
                            abi.encodeCall(
                                PolicyRouter.viewAdoptionProfile, (r.metadataSnapshotHash)
                            ),
                            cap
                        )
                    ) != T.PROFILE
        ) revert V.InvalidViewAdoption();
        T.Entropy memory entropy = _identity(r, saved, cap);
        V.Payload memory payload = Payload.decode(Bytes.read(saved.source));
        bytes memory tdRaw = Read.bounded(
            _targets[0], abi.encodeCall(Mint.tokenData, (r.tokenId)), 16480, cap, false
        );
        bytes memory tokenData = abi.decode(tdRaw, (bytes));
        if (tokenData.length > 16384 || keccak256(tdRaw) != keccak256(abi.encode(tokenData))) {
            revert V.InvalidViewAdoption();
        }
        string memory html = _encode(
            abi.encodeWithSelector(
                Encoding.html.selector,
                r,
                saved.input.scope.scopeId,
                saved.sourceHash,
                _chainId,
                tokenData,
                entropy,
                payload.script
            )
        );
        if (mode == 3) return html;
        bytes memory artistRaw = Read.bounded(
            _targets[3],
            abi.encodeWithSignature("attribution(uint256,uint256)", r.collectionId, r.tokenId),
            32864,
            _gasParameterValue(ATTRIBUTION_GAS),
            false
        );
        bytes memory artist = abi.decode(artistRaw, (bytes));
        if (artist.length > 32768 || keccak256(artistRaw) != keccak256(abi.encode(artist))) {
            revert V.InvalidViewAdoption();
        }
        return _encode(
            abi.encodeWithSelector(
                Encoding.output.selector,
                r,
                payload.name,
                payload.description,
                payload.imageURI,
                html,
                artist,
                mode
            )
        );
    }

    function _identity(RenderRequest memory r, V.Record memory saved, uint256 cap)
        private
        view
        returns (T.Entropy memory entropy)
    {
        (bool exists, uint256 cid, uint256 serial, bool burned) = abi.decode(
            Read.read(
                _targets[0], abi.encodeCall(Identity.tokenCollectionIdentity, (r.tokenId)), 128, cap
            ),
            (bool, uint256, uint256, bool)
        );
        bool frozen = Read.word(
            _targets[0], abi.encodeCall(Collection.collectionFreezeStatus, (cid)), cap
        ) == 1;
        if (
            !exists || cid != r.collectionId || serial != r.collectionSerial
                || Read.word(_targets[0], abi.encodeCall(Identity.tokenLifecycle, (r.tokenId)), cap)
                    != (burned ? 3 : 2)
                || r.state
                    != (burned
                            ? TokenRenderState.BURNED
                            : frozen ? TokenRenderState.FROZEN : TokenRenderState.ACTIVE)
                || Read.word(
                        _targets[0], abi.encodeCall(Collection.collectionSupplyMode, (cid)), cap
                    ) != r.collectionSupplyMode
                || Read.word(_targets[0], abi.encodeCall(Collection.collectionStatus, (cid)), cap)
                    != r.collectionStatus
        ) revert V.InvalidViewAdoption();
        address coordinator =
            Read.addr(_targets[0], abi.encodeCall(Identity.coordinatorAtMint, (r.tokenId)), cap);
        uint256 position = _positions[coordinator];
        if (position == 0) revert V.InvalidViewAdoption();
        entropy = PolicySource.token(
            _targets[0], r.tokenId, r.collectionId, _policies[position - 1], cap
        );
        if (entropy.seed != r.tokenHash) revert V.InvalidViewAdoption();
        Read.pin(
            saved.source.route.binding.membership, saved.source.route.binding.membershipCodeHash
        );
        if (
            Read.word(
                    saved.source.route.binding.membership,
                    abi.encodeCall(Membership.scopeCoversToken, (saved.input.scope, r.tokenId)),
                    cap
                ) != 1
        ) revert V.InvalidViewAdoption();
    }

    /// @dev Same enclosing render gas budget; no callback or delegated execution. The two calls
    /// preserve HTML/MAX validation before the original live attribution read. Failed formatter
    /// errors bubble unchanged; successful canonical strings retain the original 262144 bound.
    function _encode(bytes memory input) private view returns (string memory result) {
        address target = address(Encoding);
        Read.pin(target, _encodingCodeHash);
        bool ok;
        uint256 size;
        assembly ("memory-safe") {
            ok := staticcall(gas(), target, add(input, 32), mload(input), 0, 0)
            size := returndatasize()
        }
        if (size > uint256(MAX_BYTES) + 64) revert V.InvalidViewAdoption();
        bytes memory raw = new bytes(size);
        assembly ("memory-safe") { returndatacopy(add(raw, 32), 0, size) }
        if (!ok) assembly ("memory-safe") { revert(add(raw, 32), mload(raw)) }
        result = abi.decode(raw, (string));
        if (bytes(result).length > MAX_BYTES || keccak256(raw) != keccak256(abi.encode(result))) {
            revert V.InvalidViewAdoption();
        }
    }
}
