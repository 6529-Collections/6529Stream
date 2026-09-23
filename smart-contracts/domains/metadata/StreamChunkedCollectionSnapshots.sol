// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import { StreamCollectionSnapshots } from "./StreamCollectionSnapshots.sol";
import { StreamSnapshotTypes as T } from "../../interfaces/stream/metadata/StreamSnapshotTypes.sol";
import { StreamSnapshotSourceReads } from "../records/StreamSnapshotSourceReads.sol";
import {
    StreamChunkedSnapshotDefinitions as D
} from "../records/StreamChunkedSnapshotDefinitions.sol";
import { StreamChunkedSnapshotJson } from "../records/StreamChunkedSnapshotJson.sol";
import { StreamWorkRecordContext } from "../records/StreamWorkRecordContext.sol";
import { IStreamSchemaRegistry } from "../../interfaces/stream/metadata/IStreamSchemaRegistry.sol";
import {
    StreamFinalityCoordinatorPolicyEvidence
} from "../../interfaces/stream/finality/StreamFinalityCoordinatorPolicyTypes.sol";
import { StreamChunkedContentEvidence as E } from "../finality/StreamChunkedContentEvidence.sol";

/// @notice Explicit chunked ONCHAIN snapshot producer with complete embedded executable sources.
/// @dev Original publication grants, replay/lineage, locks and receipt ABI are inherited unchanged.
///      Distinct schema/source/record/chain domains prevent interpreting this profile as inline v1.
contract StreamChunkedCollectionSnapshots is StreamCollectionSnapshots {
    constructor(T.Dependencies memory d, address executor, GasParameterConfig[4] memory configs)
        StreamCollectionSnapshots(d, executor, configs)
    { }

    function _manifestLimit() internal pure override returns (uint256) {
        return 3000000;
    }

    function _recordDomain() internal pure override returns (bytes32) {
        return keccak256("6529STREAM_CHUNKED_SNAPSHOT_RECORD_V1");
    }

    function _chainDomain() internal pure override returns (bytes32) {
        return keccak256("6529STREAM_CHUNKED_SNAPSHOT_CHAIN_V1");
    }

    function _receipt(T.Publication memory p, address publisher)
        internal
        view
        override
        returns (T.Receipt memory r)
    {
        r = super._receipt(p, publisher);
        r.schemaDefinitionHash = D.SCHEMA_HASH;
        r.profileDefinitionHash = D.PROFILE_HASH;
        r.canonicalizationDefinitionHash = D.CANON_HASH;
    }

    function _nativeSources(T.Dependencies memory d, uint256 cid)
        internal
        view
        override
        returns (T.NativeFacts memory)
    {
        return StreamSnapshotSourceReads.requireCurrentChunked(d, cid);
    }

    function _evidence(T.Dependencies memory d, T.NativeFacts memory n)
        private
        view
        returns (E.Evidence memory)
    {
        return E.source(
            d.targets[0], d.targets[4], d.chainId, n.collectionId, n.serving, d.sourceGas, true
        );
    }

    function _sourceHash(
        T.Dependencies memory d,
        T.NativeFacts memory n,
        StreamFinalityCoordinatorPolicyEvidence memory entropy
    ) internal view override returns (bytes32) {
        return keccak256(
            abi.encode(
                keccak256("6529STREAM_CHUNKED_SNAPSHOT_SOURCES_V1"),
                d.chainId,
                address(this),
                d.targets,
                d.codeHashes,
                n,
                entropy,
                _evidence(d, n)
            )
        );
    }

    function _assemble(T.Publication memory p, T.Receipt memory r)
        internal
        view
        override
        returns (bytes32 sourceHash, bytes memory canonical)
    {
        T.Dependencies memory d = dependencies();
        (T.NativeFacts memory n, StreamFinalityCoordinatorPolicyEvidence memory entropy) =
            _sources(d, p);
        sourceHash = _sourceHash(d, n, entropy);
        canonical = StreamChunkedSnapshotJson.manifest(d, n, entropy, p, r, _evidence(d, n));
    }

    function _definitions(T.Dependencies memory d) internal view override {
        StreamWorkRecordContext.Dependencies memory defs;
        for (uint256 i; i < 4; ++i) {
            defs.targets[i] = d.targets[i];
            defs.codeHashes[i] = d.codeHashes[i];
        }
        defs.chainId = d.chainId;
        defs.readGas = d.readGas;
        StreamWorkRecordContext.definition(
            defs,
            D.SCHEMA_ID,
            IStreamSchemaRegistry.DocumentKind.SCHEMA,
            D.SCHEMA_HASH,
            D.SCHEMA_BYTES,
            keccak256("RAW_BYTES"),
            true
        );
        StreamWorkRecordContext.definition(
            defs,
            D.PROFILE_ID,
            IStreamSchemaRegistry.DocumentKind.CATALOG,
            D.PROFILE_HASH,
            D.PROFILE_BYTES,
            keccak256("RAW_BYTES"),
            true
        );
        StreamWorkRecordContext.definition(
            defs,
            D.CANON_ID,
            IStreamSchemaRegistry.DocumentKind.CANONICALIZATION,
            D.CANON_HASH,
            D.CANON_BYTES,
            keccak256("RAW_BYTES"),
            true
        );
    }
}
