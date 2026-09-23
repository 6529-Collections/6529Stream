// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import { IStreamRenderer as R } from "../../interfaces/stream/metadata/IStreamRenderer.sol";
import {
    IStreamStaticMetadataRouter as S
} from "../../interfaces/stream/metadata/IStreamStaticMetadataRouter.sol";
import {
    IStreamScriptBundles as B
} from "../../interfaces/stream/metadata/IStreamScriptBundles.sol";
import { StreamRenderContextV1 as Context } from "./StreamRenderContextV1.sol";
import { Strings } from "../../vendor/openzeppelin/Strings.sol";
import { Base64 } from "../../vendor/openzeppelin/Base64.sol";
import {
    IStreamC2PAReconciliation as C2PA
} from "../../interfaces/stream/metadata/IStreamC2PAReconciliation.sol";
import { StreamStaticC2PAJSON } from "./StreamStaticC2PAJSON.sol";
import { StreamMetadataCitation as Citation } from "./StreamMetadataCitation.sol";
import {
    IStreamC2PAConflicts as Conflicts
} from "../../interfaces/stream/metadata/IStreamC2PAConflicts.sol";

/// @notice Fixed pure Metadata companion; consumes authenticated renderer input and makes no external read.
/// @dev Its address/runtime/selector belong to the version's transitive declared read set.
library StreamStaticRenderEncoding {
    using Strings for uint256;
    bytes32 private constant ID = keccak256("6529STREAM_RENDERER_V1");
    bytes32 private constant VERSION = keccak256("6529STREAM_STATIC_RENDERER_V1");
    bytes32 private constant CONTEXT = keccak256("STREAM_CONTEXT_V1");
    uint256 private constant MAX_DEFAULT_URI_BYTES = 24576;
    uint256 private constant MAX_FULL_BYTES = 16777216;
    error InvalidStaticRender();
    error StaticOutputTooLarge();

    struct Prepared {
        S.RawSource source;
        R.MetadataConfig config;
        Context.Facts facts;
        bytes32 bundle;
        B.Facts bundleFacts;
        bytes artist;
        C2PA.Display c2pa;
        bytes32 c2paSubject;
        bool c2paUnavailable;
        Conflicts.Standing c2paTokenConflict;
        Conflicts.Standing c2paCollectionConflict;
        bool c2paConflictsEnabled;
        bool c2paConflictsUnavailable;
    }

    function _c2pa(Prepared memory p) private pure returns (bytes memory) {
        if (!p.c2paConflictsEnabled) {
            return StreamStaticC2PAJSON.fields(p.c2pa, p.c2paSubject, p.c2paUnavailable);
        }
        return StreamStaticC2PAJSON.withConflicts(
            p.c2pa,
            p.c2paSubject,
            p.c2paUnavailable,
            p.c2paTokenConflict,
            p.c2paCollectionConflict,
            p.c2paConflictsUnavailable
        );
    }

    function render(
        R.RenderRequest memory r,
        Prepared memory p,
        string memory script,
        address router,
        uint8 mode
    ) public pure returns (string memory) {
        return _render(r, p, script, router, mode, false);
    }

    /// @notice Separately admitted current JSON; original render remains byte-compatible.
    function renderCurrent(
        R.RenderRequest memory r,
        Prepared memory p,
        string memory script,
        address router,
        uint8 mode
    ) public pure returns (string memory) {
        return _render(r, p, script, router, mode, true);
    }

    function _render(
        R.RenderRequest memory r,
        Prepared memory p,
        string memory script,
        address router,
        uint8 mode,
        bool current
    ) private pure returns (string memory) {
        bool full = mode >= 2;
        string memory context = Context.json(r, p.facts, ID, VERSION);
        string memory html;
        if (
            r.state != R.TokenRenderState.PENDING_RANDOMNESS
                && p.config.mode != R.MetadataMode.OFFCHAIN && (full || p.bundle == 0)
        ) {
            html = Context.html(context, p.facts.dependencyScript, script);
            if (bytes(html).length > MAX_FULL_BYTES) revert StaticOutputTooLarge();
        }
        if (mode == 3) return bytes(html).length == 0 ? Context.html(context, "", "") : html;
        // A large program is available at the actual full methods. Its compact reference is
        // never described as a complete executable export. No external URI is executed here.
        if (current) {
            context = Citation.inObject(context, Citation.work(p.source.chainId, r.core, r.tokenId));
        }
        bytes memory json = _json(r, p, context, html, full, router);
        if (!full && (p.bundle != 0 || json.length > 18000)) {
            json = _compact(r, p, router, current);
        }
        if (json.length > (full ? MAX_FULL_BYTES : 18000)) revert StaticOutputTooLarge();
        if (mode == 1) {
            string memory uri = string.concat("data:application/json;base64,", Base64.encode(json));
            if (bytes(uri).length > MAX_DEFAULT_URI_BYTES) revert StaticOutputTooLarge();
            return uri;
        }
        return string(json);
    }

    function _json(
        R.RenderRequest memory r,
        Prepared memory p,
        string memory context,
        string memory html,
        bool full,
        address router
    ) private pure returns (bytes memory) {
        string memory fullPrefix = string.concat(
            "web3://", uint256(uint160(router)).toHexString(20), ":", p.source.chainId.toString()
        );
        string memory animation;
        if (bytes(html).length != 0) {
            // The fixed prefix and Base64 alphabet contain no JSON escape characters.
            animation = string.concat("data:text/html;base64,", Base64.encode(bytes(html)));
        } else if (bytes(p.source.animationBaseURI).length != 0) {
            animation =
                Context.escape(string.concat(p.source.animationBaseURI, r.tokenId.toString()));
        }
        bytes memory out = abi.encodePacked(
            '{"name":"',
            Context.escape(bytes(p.source.name).length == 0 ? "6529 Stream" : p.source.name),
            " #",
            r.collectionSerial.toString(),
            '","description":"',
            Context.escape(p.source.description),
            '","image":"',
            Context.escape(p.source.imageURI),
            '","animation_url":"',
            animation,
            '","metadata_state":"',
            _renderState(r.state),
            '","metadata_schema_version":"6529stream-static-v1","token_data_base64":"',
            Base64.encode(p.facts.tokenData),
            '","properties":{"stream":',
            context,
            ',"provenance":{"attribution":',
            p.artist,
            _c2pa(p),
            '},"render_mode":"',
            full ? "full" : "marketplace",
            '","config_record_hash":"',
            uint256(r.metadataSnapshotHash).toHexString(32),
            '","views":{"tokenJSON":"',
            fullPrefix,
            "/tokenJSON/",
            r.tokenId.toString(),
            '","tokenHTML":"',
            fullPrefix,
            "/tokenHTML/",
            r.tokenId.toString(),
            '"}'
        );
        if (p.config.mode != R.MetadataMode.ONCHAIN) {
            out = bytes.concat(
                out,
                abi.encodePacked(
                    ',"offchain_metadata_uri":"',
                    Context.escape(
                        string.concat(
                            p.config.baseURI,
                            (p.config.offchainURIIdMode == R.OffchainURIIdMode.TOKEN_ID
                                    ? r.tokenId
                                    : r.collectionSerial)
                            .toString()
                        )
                    ),
                    '"'
                )
            );
        }
        return bytes.concat(out, bytes("}}"));
    }

    function _renderState(R.TokenRenderState state) private pure returns (string memory) {
        return state == R.TokenRenderState.BURNED
            ? "burned"
            : state == R.TokenRenderState.PENDING_RANDOMNESS
                ? "pending"
                : state == R.TokenRenderState.FROZEN ? "frozen" : "active";
    }

    function _compact(R.RenderRequest memory r, Prepared memory p, address router, bool current)
        private
        pure
        returns (bytes memory)
    {
        string memory root = string.concat(
            "web3://", uint256(uint160(router)).toHexString(20), ":", p.source.chainId.toString()
        );
        bytes memory artist = p.artist;
        if (artist.length > 8192) {
            // The complete object begins with the canonical state field. Retain that actual
            // state while linking the full object; truncation is never mislabeled unavailable.
            bytes memory prefix = bytes('{"state":"');
            uint256 end = prefix.length;
            if (artist.length < prefix.length) revert InvalidStaticRender();
            for (uint256 i; i < prefix.length; ++i) {
                if (artist[i] != prefix[i]) revert InvalidStaticRender();
            }
            while (end < artist.length && artist[end] != 0x22 && end < 64) ++end;
            if (end == artist.length || end == 64) revert InvalidStaticRender();
            bytes memory state = new bytes(end);
            for (uint256 i; i < end; ++i) {
                state[i] = artist[i];
            }
            artist = abi.encodePacked(state, '","details_location":"tokenJSON"}');
        }
        return abi.encodePacked(
            '{"name":"',
            Context.escape(p.source.name),
            " #",
            r.collectionSerial.toString(),
            '","image":"',
            Context.escape(p.source.imageURI),
            '","metadata_state":"',
            _renderState(r.state),
            '","metadata_schema_version":"6529stream-static-v1","token_data_location":"tokenJSON:token_data_base64","properties":{',
            current
                ? abi.encodePacked(
                    '"stream":{"citation":"',
                    Citation.work(p.source.chainId, r.core, r.tokenId),
                    '"},'
                )
                : bytes(""),
            '"render_mode":"compact","renderer_id":"',
            uint256(ID).toHexString(32),
            '","renderer_version":"',
            uint256(VERSION).toHexString(32),
            '","context_version":"',
            uint256(CONTEXT).toHexString(32),
            '","config_record_hash":"',
            uint256(r.metadataSnapshotHash).toHexString(32),
            '","script_hash":"',
            uint256(p.facts.scriptHash).toHexString(32),
            '","dependency_hash":"',
            uint256(p.facts.dependencyHash).toHexString(32),
            '","provenance":{"attribution":',
            artist,
            _c2pa(p),
            '},"views":{"tokenJSON":"',
            root,
            "/tokenJSON/",
            r.tokenId.toString(),
            '","tokenHTML":"',
            root,
            "/tokenHTML/",
            r.tokenId.toString(),
            '"}}}'
        );
    }
}
