// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import { StreamChunkedContentEvidence } from "./StreamChunkedContentEvidence.sol";
import {
    IStreamMetadataServingFacts as F
} from "../../interfaces/stream/metadata/IStreamMetadataServingFacts.sol";
import "./StreamOnchainContentBytes.sol";
import "../../interfaces/stream/finality/IStreamOnchainContentCheckpoint.sol";
import "../../interfaces/stream/metadata/IStreamMetadataFullViews.sol";
import "../../interfaces/stream/core/IStreamCoreMint.sol";
import "../../interfaces/stream/core/IStreamCoreIdentity.sol";
import "../../interfaces/stream/entropy/IStreamEntropyView.sol";

/// @notice Fixed explicit full-artwork checkpoint profile. No publication or finality authority.
library StreamChunkedCheckpoint {
    bytes32 internal constant PROFILE = keccak256("6529STREAM_CONTENT_CHUNKED_ONCHAIN_V1");

    struct Context {
        address core;
        address router;
        uint256 chainId;
        uint256 readGas;
        uint256 renderGas;
    }

    function serving(Context memory c, uint256 collectionId)
        public
        view
        returns (bytes32 hash, string memory imageURI)
    {
        F.ServingFacts memory f = abi.decode(
            StreamChunkedContentEvidence.read(
                c.router, abi.encodeCall(F.collectionServingFacts, (collectionId)), 512, c.renderGas
            ),
            (F.ServingFacts)
        );
        if (
            !f.scriptLocked || !f.mediaLocked || !f.baseURILocked || !f.dependenciesLocked
                || !f.artistIdentityLocked || !f.displayMetadataLocked
        ) revert IStreamOnchainContentCheckpoint.CheckpointContentUnlocked();
        StreamChunkedContentEvidence.Evidence memory e = StreamChunkedContentEvidence.source(
            c.core, c.router, c.chainId, collectionId, f, c.renderGas, true
        );
        StreamChunkedContentEvidence.renderer(f, c.readGas);
        bytes memory raw = StreamChunkedContentEvidence.dynamicRead(
            c.router, abi.encodeCall(F.collectionServingSource, (collectionId)), 14976, c.renderGas
        );
        F.ServingSource memory s = abi.decode(raw, (F.ServingSource));
        if (
            keccak256(raw) != keccak256(abi.encode(s)) || bytes(s.name).length > 256
                || bytes(s.description).length > 2048 || bytes(s.imageURI).length > 2048
                || bytes(s.animationBaseURI).length > 2048 || bytes(s.script).length != 0
                || f.imageURIHash != keccak256(bytes(s.imageURI))
                || f.animationBaseURIHash != keccak256(bytes(s.animationBaseURI))
        ) revert IStreamOnchainContentCheckpoint.CheckpointUnsupportedPresentation();
        // Core freeze is subsequent lifecycle state, exactly as for the original inline profile.
        f.coreFrozen = false;
        return (keccak256(abi.encode(PROFILE, f, s, e)), s.imageURI);
    }

    function leaf(
        Context memory c,
        IStreamOnchainContentCheckpoint.TokenPayload memory payload,
        string memory imageURI
    ) public view returns (StreamTokenContentLeaf memory) {
        address entropy = abi.decode(
            StreamChunkedContentEvidence.read(
                c.core,
                abi.encodeCall(IStreamCoreIdentity.coordinatorAtMint, (payload.tokenId)),
                32,
                c.readGas
            ),
            (address)
        );
        if (
            entropy.code.length == 0
                || abi.decode(
                        StreamChunkedContentEvidence.read(
                            entropy,
                            abi.encodeCall(
                                IStreamEntropyView.tokenEntropyStatus, (payload.tokenId)
                            ),
                            32,
                            c.readGas
                        ),
                        (uint256)
                    ) != uint256(StreamEntropyStatus.FINALIZED) || payload.animation.length == 0
                || payload.animation.length > 2000000 || payload.image.length > 2048
        ) revert IStreamOnchainContentCheckpoint.CheckpointPayloadMismatch(payload.tokenId);
        bytes memory raw = StreamChunkedContentEvidence.dynamicRead(
            c.router,
            abi.encodeCall(
                IStreamMetadataHistoricalFullView.historicalFullTokenMetadataJSON,
                (c.core, payload.tokenId)
            ),
            3000064,
            c.renderGas
        );
        bytes memory json = abi.decode(raw, (bytes));
        if (keccak256(raw) != keccak256(abi.encode(json))) {
            revert IStreamOnchainContentCheckpoint.CheckpointPayloadMismatch(payload.tokenId);
        }
        bytes memory tokenRaw = StreamChunkedContentEvidence.dynamicRead(
            c.core, abi.encodeCall(IStreamCoreMint.tokenData, (payload.tokenId)), 16448, c.readGas
        );
        bytes memory tokenData = abi.decode(tokenRaw, (bytes));
        if (
            keccak256(tokenRaw) != keccak256(abi.encode(tokenData)) || tokenData.length > 16384
                || json.length > 3000000
                || !StreamOnchainContentBytes.matchesFullAnimation(
                    json, payload.animation, tokenData
                ) || !StreamOnchainContentBytes.matchesImage(json, imageURI, payload.image)
        ) revert IStreamOnchainContentCheckpoint.CheckpointPayloadMismatch(payload.tokenId);
        return StreamTokenContentLeaf(
            payload.tokenId,
            keccak256(json),
            payload.image.length == 0 ? bytes32(0) : keccak256(payload.image),
            keccak256(payload.animation),
            0,
            keccak256(tokenData)
        );
    }
}
