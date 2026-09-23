// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    StreamPreservationPolicySnapshotFamiliesV2 as SnapshotFamilies
} from "../records/StreamPreservationPolicySnapshotFamiliesV2.sol";
import {
    StreamPreservationPolicyRootFamiliesV2 as RootFamilies
} from "../finality/StreamPreservationPolicyRootFamiliesV2.sol";

import {
    StreamPreservationPolicySnapshotTypesV1 as S
} from "../../interfaces/stream/metadata/StreamPreservationPolicySnapshotTypesV1.sol";

import {
    IStreamSchemaRegistry as Schema
} from "../../interfaces/stream/metadata/IStreamSchemaRegistry.sol";
import {
    StreamPreservationPolicySnapshotSourceReadsV1 as Sources
} from "../records/StreamPreservationPolicySnapshotSourceReadsV1.sol";

import { StreamWorkRecordContext as Documents } from "../records/StreamWorkRecordContext.sol";

/// @notice Fixed linked operations retain the original host storage and domains.
library StreamPreservationPolicySnapshotAssembly {
    function assemble(
        S.Dependencies memory d,
        S.Publication memory p,
        S.Receipt memory r,
        bytes32 _family
    ) public view returns (bytes32 hash, bytes memory canonical) {
        _definitions(d, _family);
        S.Source memory f = Sources.current(d, p, _family);
        hash = Sources.sourceHash(d, f, _family);
        r.sourceHash = hash;
        p.expectedSourceHash = 0; // The actual hash is present in receipt/source; no preview circularity.
        canonical = abi.encode(
            SnapshotFamilies.payloadDomain(_family, false),
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

    function _definitions(S.Dependencies memory d, bytes32 _family) private view {
        Documents.Dependencies memory known;
        for (uint256 i; i < 4; ++i) {
            known.targets[i] = d.targets[i];
            known.codeHashes[i] = d.codeHashes[i];
        }
        known.chainId = d.chainId;
        known.readGas = d.readGas;
        bytes32[5] memory allIds = RootFamilies.ids(_family, false);
        bytes32[2] memory rootIds = [allIds[3], allIds[4]];
        for (uint256 i; i < 2; ++i) {
            bytes memory raw = RootFamilies.document(_family, false, rootIds[i]);
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
        bytes32[3] memory ids = SnapshotFamilies.ids(_family, false);
        bytes32[3] memory hashes = SnapshotFamilies.hashes(_family, false);
        uint256[3] memory sizes = SnapshotFamilies.lengths(_family, false);
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
