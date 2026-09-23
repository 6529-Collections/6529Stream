// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamProspectiveReferenceTypes as P
} from "../../interfaces/stream/preservation/StreamProspectiveReferenceTypes.sol";
import { StreamSnapshotManifestBytes as Bytes } from "../records/StreamSnapshotManifestBytes.sol";
import {
    StreamProspectiveReferenceSourceReads as Sources
} from "./StreamProspectiveReferenceSourceReads.sol";
import {
    StreamProspectiveReferenceEvidence as Evidence
} from "./StreamProspectiveReferenceEvidence.sol";
import {
    StreamReferenceRenderPreparation as Preparation
} from "./StreamReferenceRenderPreparation.sol";
import {
    StreamProspectiveReferenceDefinitionReads as Definitions
} from "./StreamProspectiveReferenceDefinitionReads.sol";
import {
    StreamProspectiveReferenceDefinitions as D
} from "../records/StreamProspectiveReferenceDefinitions.sol";

/// @notice Original canonical record bytes and live proof are separately retained and rejoined.
library StreamProspectiveReferenceRecords {
    function canonical(
        P.Publication memory p,
        P.Source memory s,
        P.Evidence memory e,
        bytes memory environment
    ) public pure returns (bytes memory out) {
        out = abi.encode(
            keccak256("6529STREAM_PROSPECTIVE_REFERENCE_PAYLOAD_V1"), p, s, e, environment
        );
        if (out.length == 0 || out.length > 524288) revert P.InvalidProspectiveReference();
    }

    function prepare(
        mapping(bytes32 => Bytes.Manifest) storage inventories,
        P.Dependencies memory d,
        P.Publication memory p
    ) public view returns (P.Source memory s, P.Evidence memory e, bytes memory out) {
        s = Sources.current(d, p.collectionId);
        Definitions.requireDefinitions(d, s);
        bytes memory environment = Preparation.environment(inventories, p.environment);
        e = Evidence.requireEvidence(d, p, s, environment);
        p.expectedSourceHash = e.sourceHash;
        out = canonical(p, s, e, environment);
    }

    function requireCurrent(
        Bytes.Manifest storage original,
        Bytes.Manifest storage payload,
        mapping(bytes32 => Bytes.Manifest) storage inventories,
        P.Dependencies memory d,
        P.Receipt memory r
    ) public view returns (P.Publication memory p) {
        bytes memory raw = Bytes.read(original);
        p = abi.decode(raw, (P.Publication));
        Sources.canonical(raw, abi.encode(p));
        (P.Source memory s, P.Evidence memory e, bytes memory exact) = prepare(inventories, d, p);
        if (
            p.collectionId != r.collectionId || p.referenceId != r.referenceId
                || p.expectedHead != r.predecessor || p.expectedRevision + 1 != r.revision
                || p.effectiveAt != r.effectiveAt || p.reasonHash != r.reasonHash
                || p.expectedSourceHash != r.sourceHash || e.sourceHash != r.sourceHash
                || s.release.scopeSubject != r.subject
                || s.release.membershipHash != r.membershipHash || r.schemaHash != D.SCHEMA_HASH
                || r.profileHash != D.PROFILE_HASH || r.canonicalizationHash != D.CANON_HASH
                || exact.length != r.payloadBytes || keccak256(exact) != r.payloadHash
                || keccak256(Bytes.read(payload)) != r.payloadHash
        ) revert P.InvalidProspectiveReference();
    }
}
