// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    StreamPolicySnapshotTypesV2 as S
} from "../../interfaces/stream/metadata/StreamPolicySnapshotTypesV2.sol";

import {
    IStreamSchemaRegistry as Schema
} from "../../interfaces/stream/metadata/IStreamSchemaRegistry.sol";
import {
    StreamPolicySnapshotSourceReadsV2 as Sources
} from "../records/StreamPolicySnapshotSourceReadsV2.sol";
import {
    StreamPolicySnapshotDefinitionsV2 as Definitions
} from "../records/StreamPolicySnapshotDefinitionsV2.sol";

import { StreamWorkRecordContext as Documents } from "../records/StreamWorkRecordContext.sol";
import {
    StreamPolicyContentRootSchemasV2 as RootDefinitions
} from "../finality/StreamPolicyContentRootSchemasV2.sol";

/// @notice Fixed linked operations retain the original host storage and domains.
library StreamPolicySnapshotAssemblyV2 {
    function assemble(S.Dependencies memory d, S.Publication memory p, S.Receipt memory r)
        public
        view
        returns (bytes32 hash, bytes memory canonical)
    {
        _definitions(d);
        S.Source memory f = Sources.current(d, p);
        hash = Sources.sourceHash(d, f);
        r.sourceHash = hash;
        p.expectedSourceHash = 0; // The actual hash is present in receipt/source; no preview circularity.
        canonical = abi.encode(
            keccak256("6529STREAM_POLICY_SNAPSHOT_PAYLOAD_V2"),
            d.chainId,
            address(this),
            d.targets,
            d.codeHashes,
            p,
            r,
            f
        );
        if (canonical.length > 524288) revert S.InvalidPolicySnapshot();
    }

    function _definitions(S.Dependencies memory d) private view {
        Documents.Dependencies memory known;
        for (uint256 i; i < 4; ++i) {
            known.targets[i] = d.targets[i];
            known.codeHashes[i] = d.codeHashes[i];
        }
        known.chainId = d.chainId;
        known.readGas = d.readGas;
        bytes32[2] memory rootIds = [RootDefinitions.ROOT_SCHEMA, RootDefinitions.ROOT_CANON];
        for (uint256 i; i < 2; ++i) {
            bytes memory raw = RootDefinitions.document(rootIds[i]);
            Documents.definition(
                known,
                rootIds[i],
                i == 0 ? Schema.DocumentKind.SCHEMA : Schema.DocumentKind.CANONICALIZATION,
                keccak256(raw),
                raw.length,
                keccak256("RAW_BYTES"),
                true
            );
        }
        Documents.definition(
            known,
            Definitions.SCHEMA_ID,
            Schema.DocumentKind.SCHEMA,
            Definitions.SCHEMA_HASH,
            Definitions.SCHEMA_BYTES,
            keccak256("RAW_BYTES"),
            true
        );
        Documents.definition(
            known,
            Definitions.PROFILE_ID,
            Schema.DocumentKind.CATALOG,
            Definitions.PROFILE_HASH,
            Definitions.PROFILE_BYTES,
            keccak256("RAW_BYTES"),
            true
        );
        Documents.definition(
            known,
            Definitions.CANON_ID,
            Schema.DocumentKind.CANONICALIZATION,
            Definitions.CANON_HASH,
            Definitions.CANON_BYTES,
            keccak256("RAW_BYTES"),
            true
        );
    }
}
