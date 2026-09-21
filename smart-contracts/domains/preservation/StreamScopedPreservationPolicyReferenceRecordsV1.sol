// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamPreservationPolicyReferenceFamiliesV2 as F
} from "./StreamPreservationPolicyReferenceFamiliesV2.sol";
import {
    StreamPreservationTokenProducerProfilesV1 as Profiles
} from "../../interfaces/stream/finality/StreamPreservationTokenProducerProfilesV1.sol";

import {
    StreamScopedPreservationPolicyReferenceTypesV1 as T
} from "../../interfaces/stream/preservation/StreamScopedPreservationPolicyReferenceTypesV1.sol";
import {
    StreamScopedPreservationPolicyReferenceSourceReadsV1 as Sources
} from "./StreamScopedPreservationPolicyReferenceSourceReadsV1.sol";
import {
    StreamReferenceRenderTypes as R
} from "../../interfaces/stream/preservation/StreamReferenceRenderTypes.sol";
import {
    StreamScopedPreservationPolicyReferenceDefinitionsV1 as D
} from "../records/StreamScopedPreservationPolicyReferenceDefinitionsV1.sol";
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

import {
    StreamScopedPreservationReferencePayloadWorkerV1 as PayloadWorker
} from "./StreamScopedPreservationReferencePayloadWorkerV1.sol";

import {
    StreamScopedPreservationReferenceRecordsDefinitionsV1 as DefinitionsWorker
} from "./StreamScopedPreservationReferenceRecordsDefinitionsV1.sol";
import {
    StreamScopedPreservationReferenceRecordsHistoryV1 as HistoryWorker
} from "./StreamScopedPreservationReferenceRecordsHistoryV1.sol";

/// @notice Fixed byte construction and typed historical/current reads for the scoped host.
library StreamScopedPreservationPolicyReferenceRecordsV1 {
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
        ) revert T.InvalidScopedPolicyReference();
        p.observation.expectedSourcesHash = 0;
        receipt.observation.recordHash = 0;
        receipt.observation.recordChainHash = 0;
        receipt.observation.payloadHash = 0;
        receipt.observation.payloadBytes = 0;
        receipt.observation.recordedAt = 0;
        canonical = abi.encode(
            F.payloadDomain(family, true), d.chainId, address(this), p, receipt, f, environment
        );
        if (canonical.length == 0 || canonical.length > 524288) {
            revert T.InvalidScopedPolicyReference();
        }
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
        T.SourceFacts memory f = Sources.requireSource(d, publication(original), true, family);
        if (
            Sources.sourceHash(d, f, family) != receipt.observation.sourcesHash
                || Bytes.requireIntact(payload) != receipt.observation.payloadHash
        ) revert T.InvalidScopedPolicyReference();
    }

    function recordBytes(Bytes.Manifest storage original, T.Receipt storage receipt)
        public
        view
        returns (bytes memory)
    {
        return HistoryWorker.recordBytes(original, receipt);
    }

    function source(Bytes.Manifest storage payload) public view returns (bytes memory) {
        return source(payload, Profiles.ORIGINAL_PROFILE);
    }

    function source(Bytes.Manifest storage payload, bytes32 family)
        public
        view
        returns (bytes memory)
    {
        return PayloadWorker.source(payload, family);
    }

    function publication(Bytes.Manifest storage original)
        internal
        view
        returns (T.Publication memory p)
    {
        return HistoryWorker.publication(original);
    }

    function definitions(T.Dependencies memory d) public view {
        definitions(d, Profiles.ORIGINAL_PROFILE);
    }

    function definitions(T.Dependencies memory d, bytes32 family) public view {
        DefinitionsWorker.definitions(d, family);
    }
}
