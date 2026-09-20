// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamProspectiveReferenceTypes as P
} from "../../interfaces/stream/preservation/StreamProspectiveReferenceTypes.sol";
import { StreamWorkRecordContext as Context } from "../records/StreamWorkRecordContext.sol";
import {
    StreamProspectiveReferenceDefinitions as D
} from "../records/StreamProspectiveReferenceDefinitions.sol";
import {
    StreamReferenceRenderDefinitions as R
} from "../records/StreamReferenceRenderDefinitions.sol";
import { IStreamSchemaRegistry } from "../../interfaces/stream/metadata/IStreamSchemaRegistry.sol";

library StreamProspectiveReferenceDefinitionReads {
    function requireDefinitions(P.Dependencies memory d, P.Source memory s) public view {
        Context.Dependencies memory c;
        c.targets = [d.targets[0], s.provider.metadata, d.targets[2], d.targets[3]];
        c.codeHashes =
            [d.codeHashes[0], s.provider.metadataCodeHash, d.codeHashes[2], d.codeHashes[3]];
        c.chainId = d.chainId;
        c.readGas = d.readGas;
        bytes32[8] memory ids = [
            D.SCHEMA_ID,
            D.PROFILE_ID,
            D.CANON_ID,
            R.ENVIRONMENT_SCHEMA_ID,
            R.PNG_SCHEMA_ID,
            R.ZIP_SCHEMA_ID,
            R.FORMAT_CATALOG_ID,
            R.CANON_ID
        ];
        bytes32[8] memory hashes = [
            D.SCHEMA_HASH,
            D.PROFILE_HASH,
            D.CANON_HASH,
            R.ENVIRONMENT_SCHEMA_HASH,
            R.PNG_SCHEMA_HASH,
            R.ZIP_SCHEMA_HASH,
            R.FORMAT_CATALOG_HASH,
            R.CANON_HASH
        ];
        uint32[8] memory lengths = [
            D.SCHEMA_BYTES,
            D.PROFILE_BYTES,
            D.CANON_BYTES,
            R.ENVIRONMENT_SCHEMA_BYTES,
            R.PNG_SCHEMA_BYTES,
            R.ZIP_SCHEMA_BYTES,
            R.FORMAT_CATALOG_BYTES,
            R.CANON_BYTES
        ];
        for (uint256 i; i < 8; ++i) {
            IStreamSchemaRegistry.DocumentKind kind = (i == 2 || i == 7)
                ? IStreamSchemaRegistry.DocumentKind.CANONICALIZATION
                : (i == 1 || i == 6)
                    ? IStreamSchemaRegistry.DocumentKind.CATALOG
                    : IStreamSchemaRegistry.DocumentKind.SCHEMA;
            Context.definition(c, ids[i], kind, hashes[i], lengths[i], keccak256("RAW_BYTES"), true);
        }
    }
}
