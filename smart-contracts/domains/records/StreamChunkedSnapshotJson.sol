// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import { StreamSnapshotManifestJson as S } from "./StreamSnapshotManifestJson.sol";
import { StreamRecordJson as J } from "./StreamRecordJson.sol";
import { StreamChunkedSnapshotDefinitions as D } from "./StreamChunkedSnapshotDefinitions.sol";
import { StreamSnapshotTypes as T } from "../../interfaces/stream/metadata/StreamSnapshotTypes.sol";
import {
    StreamFinalityCoordinatorPolicyEvidence
} from "../../interfaces/stream/finality/StreamFinalityCoordinatorPolicyTypes.sol";
import { StreamChunkedContentEvidence as E } from "../finality/StreamChunkedContentEvidence.sol";
import { StreamChunkedSnapshotPayload } from "./StreamChunkedSnapshotPayload.sol";

/// @notice Versioned complete script/library snapshot. Compact token view links are never exported as payloads.
library StreamChunkedSnapshotJson {
    function manifest(
        T.Dependencies memory d,
        T.NativeFacts memory n,
        StreamFinalityCoordinatorPolicyEvidence memory entropy,
        T.Publication memory p,
        T.Receipt memory r,
        E.Evidence memory e
    ) public view returns (bytes memory raw) {
        (string memory script, string memory lib) =
            StreamChunkedSnapshotPayload.json(e, d.sourceGas);
        string memory out = string.concat(
            '{"chainId":',
            J.unsigned(d.chainId),
            ',"checkpointProfile":',
            S._hash(keccak256("6529STREAM_CONTENT_CHUNKED_ONCHAIN_V1")),
            ',"collectionId":',
            J.unsigned(n.collectionId),
            ',"contentRoot":',
            S._root(n),
            ',"dependencyReadProfile":',
            S._hash(n.dependencyProfile),
            ',"entropy":',
            S._entropy(entropy)
        );
        out = string.concat(
            out,
            ',"library":',
            lib,
            ',"metadata":',
            S._metadata(n),
            ',"profileHash":',
            S._hash(D.PROFILE_HASH),
            ',"publication":',
            S._publication(p, r),
            ',"renderer":',
            S._renderer(n)
        );
        out = string.concat(
            out,
            ',"schemaHash":',
            S._hash(D.SCHEMA_HASH),
            ',"schemaId":',
            S._hash(D.SCHEMA_ID),
            ',"script":',
            script,
            ',"sources":',
            S._sources(d),
            ',"subject":',
            S._hash(n.subject),
            ',"version":2}'
        );
        raw = bytes(out);
        if (raw.length == 0 || raw.length > 3000000) revert T.SnapshotSource();
    }
}
