// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    StreamScopedPolicySnapshotTypesV2 as S
} from "../../interfaces/stream/metadata/StreamScopedPolicySnapshotTypesV2.sol";

import {
    IStreamSchemaRegistry as Schema
} from "../../interfaces/stream/metadata/IStreamSchemaRegistry.sol";
import {
    StreamScopedPolicySnapshotSourceReadsV2 as Sources
} from "../records/StreamScopedPolicySnapshotSourceReadsV2.sol";
import {
    StreamScopedPolicySnapshotDefinitionsV2 as Definitions
} from "../records/StreamScopedPolicySnapshotDefinitionsV2.sol";

import { StreamWorkRecordContext as Documents } from "../records/StreamWorkRecordContext.sol";

/// @notice Fixed linked operations retain the original host storage and domains.
library StreamScopedPolicySnapshotAssemblyV2 {
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
            keccak256("6529STREAM_SCOPED_POLICY_SNAPSHOT_PAYLOAD_V2"),
            d.chainId,
            address(this),
            d.targets,
            d.codeHashes,
            p,
            r,
            f
        );
        if (canonical.length > 524288) revert S.InvalidScopedPolicySnapshot();
    }

    function _definitions(S.Dependencies memory d) private view {
        Documents.Dependencies memory known;
        for (uint256 i; i < 4; ++i) {
            known.targets[i] = d.targets[i];
            known.codeHashes[i] = d.codeHashes[i];
        }
        known.chainId = d.chainId;
        known.readGas = d.readGas;
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
