// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    StreamScopedPreservationPolicySnapshotTypesV1 as S
} from "../../interfaces/stream/metadata/StreamScopedPreservationPolicySnapshotTypesV1.sol";
import {
    IStreamSchemaRegistry as Schema
} from "../../interfaces/stream/metadata/IStreamSchemaRegistry.sol";
import {
    StreamPreservationPolicySnapshotFamiliesV2 as SnapshotFamilies
} from "./StreamPreservationPolicySnapshotFamiliesV2.sol";
import {
    StreamScopedPreservationPolicySnapshotSourceReadsV1 as Sources
} from "./StreamScopedPreservationPolicySnapshotSourceReadsV1.sol";
import { StreamWorkRecordContext as Documents } from "./StreamWorkRecordContext.sol";

/// @notice Fixed complete-source snapshot encoding, preserving the publisher's address and caller.
/// @dev The linked library owns no storage or authority. It returns the exact canonical payload;
/// the host retains publication admission, receipt/history writes, retention and atomicity.
library StreamScopedPreservationSnapshotAssemblyV1 {
    function assemble(
        S.Dependencies memory d,
        S.Publication memory p,
        S.Receipt memory r,
        bytes32 family
    ) public view returns (bytes32 hash, bytes memory canonical) {
        _definitions(d, family);
        S.Source memory f = Sources.current(d, p, family);
        hash = Sources.sourceHash(d, f, family);
        r.sourceHash = hash;
        p.expectedSourceHash = 0; // The actual hash is present in receipt/source; no preview circularity.
        canonical = abi.encode(
            SnapshotFamilies.payloadDomain(family, true),
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

    function _definitions(S.Dependencies memory d, bytes32 family) private view {
        Documents.Dependencies memory known;
        for (uint256 i; i < 4; ++i) {
            known.targets[i] = d.targets[i];
            known.codeHashes[i] = d.codeHashes[i];
        }
        known.chainId = d.chainId;
        known.readGas = d.readGas;
        bytes32[3] memory ids = SnapshotFamilies.ids(family, true);
        bytes32[3] memory hashes = SnapshotFamilies.hashes(family, true);
        uint256[3] memory sizes = SnapshotFamilies.lengths(family, true);
        for (uint256 i; i < 3; ++i) {
            Documents.definition(
                known,
                ids[i],
                i == 0
                    ? Schema.DocumentKind.SCHEMA
                    : i == 1 ? Schema.DocumentKind.CATALOG : Schema.DocumentKind.CANONICALIZATION,
                hashes[i],
                sizes[i],
                keccak256("RAW_BYTES"),
                true
            );
        }
    }
}
