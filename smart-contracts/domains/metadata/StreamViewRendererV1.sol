// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import { IStreamRenderer as R } from "../../interfaces/stream/metadata/IStreamRenderer.sol";
import {
    IStreamViewRendererV1 as API
} from "../../interfaces/stream/metadata/IStreamViewRendererV1.sol";
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
import { StreamViewPayloadV1 as Payload } from "./StreamViewPayloadV1.sol";
import { StreamViewRendererFormat as Format } from "./StreamViewRendererFormat.sol";
import { StreamRenderContextV1 as Text } from "./StreamRenderContextV1.sol";
import { StreamGasParameterHost } from "../parameters/StreamGasParameterHost.sol";
import { Strings } from "../../vendor/openzeppelin/Strings.sol";
import { Base64 } from "../../vendor/openzeppelin/Base64.sol";

/// @notice Separate admitted STATIC profile over immutable adopted VIEW bytes and actual tokens.
/// @dev All serving helper bodies are internal; external calls are bounded STATICCALL only.
contract StreamViewRendererV1 is R, API, StreamGasParameterHost {
    bytes32 public constant READ_GAS = keccak256("6529STREAM_GGP_METADATA_DEPENDENCY_READ_GAS");
    bytes32 public constant ATTRIBUTION_GAS = keccak256("6529STREAM_GGP_STATIC_ATTRIBUTION_GAS");
    uint32 public constant MAX_BYTES = 262144;
    address[4] private _targets;
    bytes32[4] private _pins;
    RendererManifest private _manifest;
    uint256 private immutable _chainId;

    constructor(
        address[4] memory targets,
        address executor,
        GasParameterConfig memory readGas,
        GasParameterConfig memory attributionGas,
        RendererManifest memory manifest
    ) StreamGasParameterHost(executor) {
        if (
            manifest.rendererId != Format.ID || manifest.rendererVersion != Format.VERSION
                || manifest.contextVersion != V.CONTEXT
                || manifest.rendererClass != keccak256("STATIC")
                || manifest.schemaHash != Format.schemaHash() || manifest.manifestHash == 0
                || manifest.deprecated || manifest.maxJSONBytes != MAX_BYTES
                || manifest.maxHTMLBytes != MAX_BYTES || readGas.failureClass != 2
                || attributionGas.failureClass != 2 || _registerGasParameter(readGas) != READ_GAS
                || _registerGasParameter(attributionGas) != ATTRIBUTION_GAS
        ) revert V.InvalidViewAdoption();
        for (uint256 i; i < 4; ++i) {
            Read.pin(targets[i], targets[i].codehash);
            _pins[i] = targets[i].codehash;
        }
        _targets = targets;
        _manifest = manifest;
        _chainId = block.chainid;
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
        return V.CONTEXT;
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

    function tokenURI(RenderRequest calldata request)
        external
        view
        override
        returns (string memory)
    {
        return _render(request, 1);
    }

    function renderView(RenderRequest calldata request, uint8 mode)
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
            string memory empty =
                mode == 3
                ? "<html><head></head><body></body></html>"
                : '{"state":"unconfigured_view"}';
            return mode == 1
                ? string.concat("data:application/json;base64,", Base64.encode(bytes(empty)))
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
        ) revert V.InvalidViewAdoption();
        _identity(r, saved, cap);
        V.Payload memory payload = Payload.decode(Bytes.read(saved.source));
        bytes memory tdRaw =
            Read.bounded(
            _targets[0], abi.encodeCall(Mint.tokenData, (r.tokenId)), 16480, cap, false
        );
        bytes memory tokenData = abi.decode(tdRaw, (bytes));
        if (tokenData.length > 16384 || keccak256(tdRaw) != keccak256(abi.encode(tokenData))) {
            revert V.InvalidViewAdoption();
        }
        string memory context = _context(r, saved, tokenData);
        string memory html = string.concat(
            "<html><head></head><body><script>window.STREAM_VIEW=",
            context,
            ";const stream=window.STREAM_VIEW;const hash=stream.seed;const tokenId=Number(stream.tokenId);const tokenData=stream.tokenData;</script><script>",
            Text.scriptText(string(payload.script)),
            "</script></body></html>"
        );
        if (bytes(html).length > MAX_BYTES) revert V.InvalidViewAdoption();
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
        string memory json = string(
            abi.encodePacked(
                '{"name":"',
                Text.escape(payload.name),
                '","description":"',
                Text.escape(payload.description),
                '","image":"',
                Text.escape(payload.imageURI),
                '","animation_url":"data:text/html;base64,',
                Base64.encode(bytes(html)),
                '","view_id":"',
                Strings.toHexString(uint256(r.viewId), 32),
                '","view_record":"',
                Strings.toHexString(uint256(r.viewManifestHash), 32),
                '","adoption_record":"',
                Strings.toHexString(uint256(r.metadataSnapshotHash), 32),
                '","artist_attribution":',
                artist,
                "}"
            )
        );
        if (bytes(json).length > MAX_BYTES) revert V.InvalidViewAdoption();
        if (mode == 1) {
            string memory uri =
                string.concat("data:application/json;base64,", Base64.encode(bytes(json)));
            if (bytes(uri).length > MAX_BYTES) revert V.InvalidViewAdoption();
            return uri;
        }
        return json;
    }

    function _identity(RenderRequest memory r, V.Record memory saved, uint256 cap) private view {
        (bool exists, uint256 cid, uint256 serial, bool burned) = abi.decode(
            Read.read(
                _targets[0], abi.encodeCall(Identity.tokenCollectionIdentity, (r.tokenId)), 128, cap
            ),
            (bool, uint256, uint256, bool)
        );
        bool frozen =
            Read.word(_targets[0], abi.encodeCall(Collection.collectionFreezeStatus, (cid)), cap)
                == 1;
        if (
            !exists || cid != r.collectionId || serial != r.collectionSerial
                || Read.word(_targets[0], abi.encodeCall(Identity.tokenLifecycle, (r.tokenId)), cap)
                    != (burned ? 3 : 2)
                || Read.addr(
                        _targets[0], abi.encodeCall(Identity.coordinatorAtMint, (r.tokenId)), cap
                    ) != _targets[2]
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
        (uint8 status, bytes32 seed,) = abi.decode(
            Read.read(
                _targets[2], abi.encodeCall(Entropy.staticTokenRenderFacts, (r.tokenId)), 96, cap
            ),
            (uint8, bytes32, address)
        );
        if (status != 5 || seed != r.tokenHash) revert V.InvalidViewAdoption();
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

    function _context(RenderRequest memory r, V.Record memory saved, bytes memory tokenData)
        private
        view
        returns (string memory)
    {
        bytes memory first = abi.encodePacked(
            '{"schema":"STREAM_VIEW_CONTEXT_V1","chainId":"',
            Strings.toString(_chainId),
            '","contract":"',
            Strings.toHexString(uint256(uint160(r.core)), 20),
            '","collectionId":"',
            Strings.toString(r.collectionId),
            '","tokenId":"',
            Strings.toString(r.tokenId),
            '","collectionSerial":"',
            Strings.toString(r.collectionSerial),
            '","seed":"',
            Strings.toHexString(uint256(r.tokenHash), 32),
            '","entropyStatus":"FINALIZED","scopeId":"',
            Strings.toHexString(uint256(saved.input.scope.scopeId), 32)
        );
        return string(
            abi.encodePacked(
                first,
                '","viewId":"',
                Strings.toHexString(uint256(r.viewId), 32),
                '","viewRecord":"',
                Strings.toHexString(uint256(r.viewManifestHash), 32),
                '","adoptionRecord":"',
                Strings.toHexString(uint256(r.metadataSnapshotHash), 32),
                '","sourceHash":"',
                Strings.toHexString(uint256(saved.sourceHash), 32),
                '","tokenData":"',
                Text.hexBytes(tokenData),
                '"}'
            )
        );
    }
}
