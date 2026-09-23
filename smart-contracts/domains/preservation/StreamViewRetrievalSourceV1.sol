// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamViewRetrievalWitnessTypesV1 as T
} from "../../interfaces/stream/preservation/StreamViewRetrievalWitnessTypesV1.sol";
import {
    IStreamViewPreservationContentCheckpointV1 as Checkpoint
} from "../../interfaces/stream/finality/IStreamViewPreservationContentCheckpointV1.sol";
import {
    StreamViewPreservationCheckpointTypesV1 as C
} from "../../interfaces/stream/finality/StreamViewPreservationCheckpointTypesV1.sol";
import {
    IStreamExternalArtifactCoverage as Archive
} from "../../interfaces/stream/preservation/IStreamExternalArtifactCoverage.sol";
import {
    StreamFinalityScope
} from "../../interfaces/stream/finality/StreamArtworkFinalityTypes.sol";
import {
    StreamViewAdoptionTypes as V
} from "../../interfaces/stream/metadata/StreamViewAdoptionTypes.sol";
import { StreamPreservationInventoryIO as IO } from "./StreamPreservationInventoryIO.sol";
import { StreamViewPayloadBytes as Bytes } from "../metadata/StreamViewPayloadBytes.sol";
import { StreamViewPayloadV2 as Payload } from "../metadata/StreamViewPayloadV2.sol";

import {
    IStreamMetadataServingFacts as Artist
} from "../../interfaces/stream/metadata/IStreamMetadataServingFacts.sol";

/// @notice Actual current adopted URI/source. Constructor checks never need an unpublished head.
library StreamViewRetrievalSourceV1 {
    function validate(T.Configuration memory c) public view {
        if (
            c.chainId != block.chainid || c.readGas < 50000 || c.sourceGas < c.readGas
                || c.archiveGas < c.readGas || c.signatureGas < 90000 || c.sourceGas > 16777216
                || c.archiveGas > 16777216 || c.signatureGas > 16777216
        ) revert T.InvalidViewRetrieval();
        IO.pin(c.core, c.coreCodeHash);
        IO.pin(c.router, c.routerCodeHash);
        IO.pin(c.checkpoint, c.checkpointCodeHash);
        IO.pin(c.archive, c.archiveCodeHash);
        bytes memory raw = IO.fixedRead(
            c.checkpoint, abi.encodeCall(Checkpoint.configuration, ()), 384, c.readGas
        );
        C.Configuration memory d = abi.decode(raw, (C.Configuration));
        IO.canonical(c.checkpoint, raw, abi.encode(d));
        if (
            d.core != c.core || d.coreCodeHash != c.coreCodeHash || d.router != c.router
                || d.routerCodeHash != c.routerCodeHash || d.chainId != c.chainId
                || IO.word(
                        c.checkpoint, abi.encodeCall(Checkpoint.checkpointProfile, ()), c.readGas
                    ) != C.PROFILE
                || IO.word(
                        c.checkpoint,
                        abi.encodeWithSignature(
                            "supportsInterface(bytes4)", type(Checkpoint).interfaceId
                        ),
                        c.readGas
                    ) != bytes32(uint256(1))
                || IO.addressWord(c.archive, abi.encodeCall(Archive.core, ()), c.readGas) != c.core
                || IO.word(c.archive, abi.encodeCall(Archive.profileHash, ()), c.readGas)
                    != keccak256("STREAM_EXTERNAL_ARTIFACT_COVERAGE_V1")
                || IO.word(
                        c.archive,
                        abi.encodeCall(Archive.supportsInterface, (type(Archive).interfaceId)),
                        c.readGas
                    ) != bytes32(uint256(1))
                || IO.addressWord(c.router, abi.encodeWithSignature("core()"), c.readGas) != c.core
        ) revert T.InvalidViewRetrieval();
    }

    function current(T.Configuration memory c, StreamFinalityScope memory scope)
        public
        view
        returns (T.Source memory s, address store, uint64 adoptedAt)
    {
        validate(c);
        C.Source memory source;
        bytes memory raw = IO.fixedRead(
            c.checkpoint,
            abi.encodeCall(Checkpoint.currentSource, (scope)),
            abi.encode(source).length,
            c.sourceGas
        );
        source = abi.decode(raw, (C.Source));
        IO.canonical(c.checkpoint, raw, abi.encode(source));
        V.Record memory r = source.adoption;
        if (
            r.recordHash == 0 || r.sourceHash == 0 || source.contextHash == 0
                || keccak256(abi.encode(r.input.scope)) != keccak256(abi.encode(scope))
                || r.source.route.core != c.core || r.source.route.coreCodeHash != c.coreCodeHash
                || r.source.route.router != c.router
                || r.source.route.routerCodeHash != c.routerCodeHash
        ) revert T.InvalidViewRetrieval();
        IO.pin(r.source.route.artist, r.source.route.artistCodeHash);
        raw = IO.fixedRead(
            c.router,
            abi.encodeCall(Artist.artistPresentation, (scope.collectionId)),
            384,
            c.readGas
        );
        Artist.ArtistPresentation memory artist = abi.decode(raw, (Artist.ArtistPresentation));
        IO.canonical(c.router, raw, abi.encode(artist));
        if (
            !artist.locked || artist.artistId == 0 || artist.snapshotHash == 0
                || artist.registry != r.source.route.artist
                || artist.registryCodeHash != r.source.route.artistCodeHash
                || artist.bindingGeneration == 0 || artist.bindingHash == 0
                || artist.identityRecordHash == 0 || artist.acceptanceRecordHash == 0
                || artist.nominatedArtist == address(0) || artist.acceptedAt == 0
                || artist.lockedAt == 0
        ) revert T.InvalidViewRetrieval();
        V.Payload memory p = Payload.decode(Bytes.read(r.source));
        s = T.Source(
            scope,
            c.core,
            c.router,
            r.recordHash,
            r.sourceHash,
            r.source.route.binding.views,
            r.input.viewRecordHash,
            r.source.payloadHash,
            source.contextHash,
            p.imageURI,
            artist.artistId,
            keccak256(abi.encode(artist))
        );
        store = r.source.route.store;
        IO.pin(store, r.source.route.storeCodeHash);
        adoptedAt = r.adoptedAt;
    }
}
