// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamViewPreservationReferenceTypesV1 as T
} from "../../interfaces/stream/preservation/StreamViewPreservationReferenceTypesV1.sol";
import {
    StreamReferenceRenderTypes as R
} from "../../interfaces/stream/preservation/StreamReferenceRenderTypes.sol";
import {
    StreamViewPreservationSnapshotTypesV1 as S
} from "../../interfaces/stream/metadata/StreamViewPreservationSnapshotTypesV1.sol";
import {
    StreamViewPreservationCheckpointTypesV1 as C
} from "../../interfaces/stream/finality/StreamViewPreservationCheckpointTypesV1.sol";
import {
    IStreamViewPreservationContentCheckpointV1 as Checkpoint
} from "../../interfaces/stream/finality/IStreamViewPreservationContentCheckpointV1.sol";
import {
    StreamViewPreservationCheckpointTokenV1 as Tokens
} from "../finality/StreamViewPreservationCheckpointTokenV1.sol";
import {
    StreamFinalityRouterEvidence as Reads
} from "../finality/StreamFinalityRouterEvidence.sol";
import {
    StreamReferenceRenderSourceReads as Archives
} from "./StreamReferenceRenderSourceReads.sol";

/// @notice Fresh exact producer bytes after caller-authenticated complete current snapshot/source.
/// @dev Fixed typed worker only. A caller-created Source is never an authoritative public record.
library StreamViewPreservationReferenceSampleReadsV1 {
    function requireSample(
        T.Dependencies memory d,
        S.Dependencies memory source,
        S.Source memory facts,
        uint64 index,
        R.Capture memory c,
        bool current
    ) public view returns (T.Sample memory result) {
        if (index >= facts.membership.tokenCount) {
            revert T.InvalidViewPreservationReference();
        }
        bytes memory raw = Reads.read(
            source.targets[6], abi.encodeCall(Checkpoint.configuration, ()), 384, d.readGas
        );
        C.Configuration memory config = abi.decode(raw, (C.Configuration));
        _canonical(source.targets[6], raw, abi.encode(config));
        if (
            config.core != d.targets[0] || config.coreCodeHash != d.codeHashes[0]
                || config.router != d.targets[4] || config.routerCodeHash != d.codeHashes[4]
                || config.chainId != d.chainId
        ) revert T.InvalidViewPreservationReference();
        raw = Reads.read(
            source.targets[6],
            abi.encodeCall(Checkpoint.outputAt, (facts.outputs.header.checkpointId, index)),
            992,
            d.readGas
        );
        C.Output memory saved = abi.decode(raw, (C.Output));
        _canonical(source.targets[6], raw, abi.encode(saved));
        bytes memory json;
        bytes memory html;
        (result.output, json, html) = Tokens.observe(config, facts.adoption, index);
        // Observe reruns actual permanent identity/full policy and the exact current or burned
        // historical producer route. No tokenSeed/finalized alias is introduced for terminal rows.
        if (
            keccak256(abi.encode(result.output)) != keccak256(abi.encode(saved))
                || saved.index != index || saved.tokenId != c.tokenId
                || saved.collectionSerial != c.collectionSerial
                || saved.jsonHash != c.metadataJSONHash || saved.htmlHash != c.htmlHash
                || saved.htmlBytes != c.htmlBytes || html.length == 0 || html.length > 262144
                || html.length != c.animationHTML.length
                || keccak256(html) != keccak256(c.animationHTML) || json.length != saved.jsonBytes
                || keccak256(json) != saved.jsonHash || sha256(c.animationHTML) != c.sourceSha256
                || c.capturedAt == 0 || c.capturedAt > block.timestamp
                || c.repeatCaptureSha256[0] == 0
                || c.repeatCaptureSha256[0] != c.repeatCaptureSha256[1]
        ) revert T.InvalidViewPreservationReference();
        result.membershipIndex = index;
        R.Dependencies memory archive;
        archive.targets = d.targets;
        archive.codeHashes = d.codeHashes;
        archive.chainId = d.chainId;
        archive.readGas = d.readGas;
        archive.archiveGas = d.archiveGas;
        result.captureCoverage = Archives.coverage(
            archive, c.coverageHash, facts.artist.artistId, c.objectHash, current
        );
        Archives.requireCaptureObject(archive, result.captureCoverage);
        if (result.captureCoverage.sha256Digest != c.repeatCaptureSha256[0]) {
            revert T.InvalidViewPreservationReference();
        }
    }

    function _canonical(address target, bytes memory raw, bytes memory expected) private pure {
        if (raw.length != expected.length || keccak256(raw) != keccak256(expected)) {
            revert T.ViewPreservationReferenceDependency(target);
        }
    }
}
