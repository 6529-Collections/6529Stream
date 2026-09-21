// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamPreservationPolicyReferenceRecordReadsV1 as RecordReads
} from "./StreamPreservationPolicyReferenceRecordReadsV1.sol";
import {
    StreamPreservationPolicyReferenceFamiliesV2 as F
} from "./StreamPreservationPolicyReferenceFamiliesV2.sol";
import {
    StreamPreservationTokenProducerProfilesV1 as Profiles
} from "../../interfaces/stream/finality/StreamPreservationTokenProducerProfilesV1.sol";

import {
    StreamPreservationPolicyReferenceTypesV1 as T
} from "../../interfaces/stream/preservation/StreamPreservationPolicyReferenceTypesV1.sol";
import {
    StreamPreservationPolicyReferenceSourceReadsV1 as Sources
} from "./StreamPreservationPolicyReferenceSourceReadsV1.sol";
import {
    StreamReferenceRenderTypes as R
} from "../../interfaces/stream/preservation/StreamReferenceRenderTypes.sol";
import {
    StreamPreservationPolicyReferenceDefinitionsV1 as D
} from "../records/StreamPreservationPolicyReferenceDefinitionsV1.sol";
import {
    StreamReferenceRenderDefinitions as Original
} from "../records/StreamReferenceRenderDefinitions.sol";
import { StreamWorkRecordContext as Documents } from "../records/StreamWorkRecordContext.sol";
import { StreamSnapshotManifestBytes as Bytes } from "../records/StreamSnapshotManifestBytes.sol";
import {
    StreamReferenceRenderPreparation as Prepared
} from "./StreamReferenceRenderPreparation.sol";
import {
    IStreamSchemaRegistry as Schema
} from "../../interfaces/stream/metadata/IStreamSchemaRegistry.sol";

/// @notice Fixed byte construction and typed historical/current reads for the scoped host.
library StreamPreservationPolicyReferenceRecordsV1 {
    function prepare(
        mapping(bytes32 => Bytes.Manifest) storage inventories,
        T.Dependencies memory d,
        T.Publication memory p,
        T.Receipt memory receipt,
        bool current
    ) public view returns (bytes32 hash, bytes memory canonical) {
        return prepare(inventories, d, p, receipt, current, Profiles.ORIGINAL_PROFILE);
    }

    function prepare(
        mapping(bytes32 => Bytes.Manifest) storage inventories,
        T.Dependencies memory d,
        T.Publication memory p,
        T.Receipt memory receipt,
        bool current,
        bytes32 family
    ) public view returns (bytes32 hash, bytes memory canonical) {
        definitions(d, family);
        T.SourceFacts memory f = Sources.requireSource(d, p, current, family);
        hash = Sources.sourceHash(d, f, family);
        receipt.observation.sourcesHash = hash;
        bytes memory environment = Prepared.environment(inventories, p.observation.environment);
        if (
            keccak256(environment) != p.observation.environment.manifestHash
                || environment.length != p.observation.environment.manifestBytes
        ) revert T.InvalidPolicyReference();
        p.observation.expectedSourcesHash = 0;
        receipt.observation.recordHash = 0;
        receipt.observation.recordChainHash = 0;
        receipt.observation.payloadHash = 0;
        receipt.observation.payloadBytes = 0;
        receipt.observation.recordedAt = 0;
        canonical = abi.encode(
            F.payloadDomain(family, false), d.chainId, address(this), p, receipt, f, environment
        );
        if (canonical.length == 0 || canonical.length > 524288) revert T.InvalidPolicyReference();
    }

    function requireCurrent(
        Bytes.Manifest storage original,
        Bytes.Manifest storage payload,
        T.Receipt storage receipt,
        T.Dependencies memory d
    ) public view {
        requireCurrent(original, payload, receipt, d, Profiles.ORIGINAL_PROFILE);
    }

    function requireCurrent(
        Bytes.Manifest storage original,
        Bytes.Manifest storage payload,
        T.Receipt storage receipt,
        T.Dependencies memory d,
        bytes32 family
    ) public view {
        definitions(d, family);
        RecordReads.requireCurrent(original, payload, receipt, d, family);
    }

    function recordBytes(Bytes.Manifest storage original, T.Receipt storage receipt)
        public
        view
        returns (bytes memory)
    {
        return RecordReads.recordBytes(original, receipt);
    }

    function source(Bytes.Manifest storage payload) public view returns (bytes memory) {
        return source(payload, Profiles.ORIGINAL_PROFILE);
    }

    function source(Bytes.Manifest storage payload, bytes32 family)
        public
        view
        returns (bytes memory)
    {
        return RecordReads.source(payload, family);
    }

    function publication(Bytes.Manifest storage original)
        internal
        view
        returns (T.Publication memory p)
    {
        bytes memory raw = Bytes.read(original);
        p = abi.decode(raw, (T.Publication));
        if (keccak256(raw) != keccak256(abi.encode(p))) revert T.InvalidPolicyReference();
    }

    function definitions(T.Dependencies memory d) public view {
        definitions(d, Profiles.ORIGINAL_PROFILE);
    }

    function definitions(T.Dependencies memory d, bytes32 family) public view {
        F.Definition memory definition = F.definition(family, false);
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
