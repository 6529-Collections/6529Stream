// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    StreamScopedPreservationPolicyReferenceTypesV1 as T
} from "../../interfaces/stream/preservation/StreamScopedPreservationPolicyReferenceTypesV1.sol";
import {
    StreamPreservationPolicyReferenceFamiliesV2 as F
} from "./StreamPreservationPolicyReferenceFamiliesV2.sol";
import {
    StreamReferenceRenderDefinitions as Original
} from "../records/StreamReferenceRenderDefinitions.sol";
import { StreamWorkRecordContext as Documents } from "../records/StreamWorkRecordContext.sol";
import {
    IStreamSchemaRegistry as Schema
} from "../../interfaces/stream/metadata/IStreamSchemaRegistry.sol";

/// @notice Fixed ordered original interpretation-document validation for scoped reference records.
library StreamScopedPreservationReferenceRecordsDefinitionsV1 {
    function definitions(T.Dependencies memory d, bytes32 family) public view {
        F.Definition memory definition = F.definition(family, true);
        Documents.Dependencies memory known;
        for (uint256 i; i < 4; ++i) {
            known.targets[i] = d.targets[i];
            known.codeHashes[i] = d.codeHashes[i];
        }
        known.chainId = d.chainId;
        known.readGas = d.readGas;
        bytes32[7] memory ids = [
            definition.schemaId,
            definition.profileId,
            definition.canonId,
            Original.ENVIRONMENT_SCHEMA_ID,
            Original.PNG_SCHEMA_ID,
            Original.ZIP_SCHEMA_ID,
            Original.FORMAT_CATALOG_ID
        ];
        bytes32[7] memory hashes = [
            definition.schemaHash,
            definition.profileHash,
            definition.canonHash,
            Original.ENVIRONMENT_SCHEMA_HASH,
            Original.PNG_SCHEMA_HASH,
            Original.ZIP_SCHEMA_HASH,
            Original.FORMAT_CATALOG_HASH
        ];
        uint32[7] memory lengths = [
            definition.schemaBytes,
            definition.profileBytes,
            definition.canonBytes,
            Original.ENVIRONMENT_SCHEMA_BYTES,
            Original.PNG_SCHEMA_BYTES,
            Original.ZIP_SCHEMA_BYTES,
            Original.FORMAT_CATALOG_BYTES
        ];
        for (uint256 i; i < 7; ++i) {
            Schema.DocumentKind kind = i == 2
                ? Schema.DocumentKind.CANONICALIZATION
                : (i == 1 || i == 6) ? Schema.DocumentKind.CATALOG : Schema.DocumentKind.SCHEMA;
            Documents.definition(
                known, ids[i], kind, hashes[i], lengths[i], keccak256("RAW_BYTES"), true
            );
        }
    }
}
