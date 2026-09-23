// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamReferenceModeTypes as M
} from "../../interfaces/stream/preservation/StreamReferenceModeTypes.sol";
import {
    StreamReferenceRenderTypes as R
} from "../../interfaces/stream/preservation/StreamReferenceRenderTypes.sol";
import {
    IStreamCollectionAttestations as A
} from "../../interfaces/stream/metadata/IStreamCollectionAttestations.sol";
import {
    IStreamConservationRecordSelection as C
} from "../../interfaces/stream/metadata/IStreamConservationRecordSelection.sol";
import {
    IStreamPreservationRecords as P
} from "../../interfaces/stream/preservation/IStreamPreservationRecords.sol";
import {
    StreamConservationRecordTypes as V
} from "../../interfaces/stream/metadata/StreamConservationRecordTypes.sol";
import { StreamReferenceModeReads as Read } from "./StreamReferenceModeReads.sol";
import { StreamReferenceModeDefinitions as D } from "../records/StreamReferenceModeDefinitions.sol";
import "../records/StreamArtistIntentJson.sol";
import { StreamCollectionRecordHashes } from "../records/StreamCollectionRecordHashes.sol";
import { StreamReferenceModeInput as Input } from "./StreamReferenceModeInput.sol";

/// @notice Exact selected Artist voice plus an actual original independent signed examination.
/// @dev Credentials are referenced statements. No institutional qualification or present Safe-owner
/// reauthorization is inferred; the pinned original attestation host verified publication once.
library StreamReferenceModeCurated {
    function requireEvidence(
        R.Dependencies memory d,
        M.Dependencies memory bindings,
        R.Publication memory p,
        R.SourceFacts memory source,
        M.Curated memory w,
        bytes32 contextHash
    ) public view returns (bytes32 selectionHash, bytes32 receiptHash) {
        return requireEvidenceProjected(d, bindings, Input.project(p, contextHash), source, w);
    }

    function requireEvidenceProjected(
        R.Dependencies memory d,
        M.Dependencies memory bindings,
        Input.EvidenceInput memory p,
        R.SourceFacts memory source,
        M.Curated memory w
    ) public view returns (bytes32 selectionHash, bytes32 receiptHash) {
        Read.pin(bindings.conservation, bindings.conservationCodeHash);
        Read.pin(bindings.attestations, bindings.attestationsCodeHash);
        _binding(bindings.conservation, "core()", d.targets[0], d.readGas);
        _binding(bindings.conservation, "metadata()", d.targets[1], d.readGas);
        _binding(bindings.conservation, "schemaRegistry()", d.targets[2], d.readGas);
        _binding(bindings.conservation, "chunkStore()", d.targets[3], d.readGas);
        _binding(bindings.attestations, "core()", d.targets[0], d.readGas);
        _binding(bindings.attestations, "schemaRegistry()", d.targets[2], d.readGas);
        _binding(bindings.attestations, "chunkStore()", d.targets[3], d.readGas);
        bytes memory raw = Read.read(
            bindings.conservation,
            abi.encodeCall(
                C.requireCurrent,
                (
                    p.collectionId,
                    source.subject,
                    V.StatementOrigin.ARTIST_INTENT,
                    w.intentRecordHash,
                    w.intentRevision
                )
            ),
            16384,
            d.snapshotGas
        );
        C.Selection memory selected = abi.decode(raw, (C.Selection));
        Read.canonical(bindings.conservation, raw, abi.encode(selected));
        if (
            selected.record.kind != C.RecordKind.INTENT
                || selected.record.recordHash != w.intentRecordHash
                || selected.origin != V.StatementOrigin.ARTIST_INTENT
                || selected.revision != w.intentRevision || selected.selectionHash == 0
                || selected.association.artistId != source.artistId
                || w.intent.artist.origin != V.StatementOrigin.ARTIST_INTENT
                || w.intent.subjectId != source.subject
                || keccak256(StreamArtistIntentJson.serialize(w.intent))
                    != selected.record.payloadHash
        ) {
            revert M.InvalidModeEvidence();
        }
        selectionHash = selected.selectionHash;
        _assess(p, w, p.contextHash, selectionHash);
        receiptHash = _condition(d, bindings.attestations, p, source.subject, w);
    }

    function _assess(
        Input.EvidenceInput memory p,
        M.Curated memory w,
        bytes32 contextHash,
        bytes32 selected
    ) private pure {
        bytes memory properties = abi.encode(w.properties);
        V.Reference memory ref = w.intent.significantProperties;
        bytes32 digest = ref.algorithm == 1
            ? keccak256(properties)
            : ref.algorithm == 2 ? sha256(properties) : bytes32(0);
        if (
            digest == 0 || ref.digest.length != 32 || bytes32(ref.digest) != digest
                || ref.canonicalizationId != D.CANON_ID || w.properties.length == 0
                || w.properties.length > 32 || w.condition.contextHash != contextHash
                || w.condition.intentRecordHash != w.intentRecordHash
                || w.condition.intentSelectionHash != selected
                || w.condition.propertiesHash != keccak256(properties)
                || w.condition.examiner == address(0) || bytes(w.condition.examinerName).length == 0
                || bytes(w.condition.examinerName).length > 256 || w.condition.examinedAt == 0
                || w.condition.assessments.length != w.properties.length * p.captures.length
        ) {
            revert M.InvalidModeEvidence();
        }
        StreamConservationRecordFields.referenceJSON(w.condition.institution);
        StreamConservationRecordFields.referenceJSON(w.condition.credentials);
        for (uint256 j; j < w.properties.length; ++j) {
            M.Property memory property = w.properties[j];
            if (
                property.id == 0 || bytes(property.name).length == 0
                    || bytes(property.name).length > 256
                    || bytes(property.significantValue).length == 0
                    || bytes(property.significantValue).length > 1024
            ) {
                revert M.InvalidModeEvidence();
            }
            for (uint256 k; k < j; ++k) {
                if (w.properties[k].id == property.id) revert M.InvalidModeEvidence();
            }
            for (uint256 i; i < p.captures.length; ++i) {
                M.Assessment memory row = w.condition.assessments[i * w.properties.length + j];
                if (
                    row.propertyId != property.id || !row.conforms
                        || bytes(row.observation).length == 0
                        || bytes(row.observation).length > 1024
                        || w.condition.examinedAt < p.captures[i].capturedAt
                ) {
                    revert M.InvalidModeEvidence();
                }
            }
        }
    }

    function _condition(
        R.Dependencies memory d,
        address host,
        Input.EvidenceInput memory p,
        bytes32 subject,
        M.Curated memory w
    ) private view returns (bytes32) {
        bytes memory raw = Read.read(
            host, abi.encodeCall(A.collectionRecord, (w.conditionRecordHash)), 16384, d.sourceGas
        );
        (P.CollectionRecord memory record, A.Receipt memory receipt) =
            abi.decode(raw, (P.CollectionRecord, A.Receipt));
        Read.canonical(host, raw, abi.encode(record, receipt));
        bytes memory payload = abi.encode(w.condition);
        if (
            w.conditionRecordHash == 0 || payload.length > 8192
                || receipt.attestor != w.condition.examiner || receipt.scopeKey != p.collectionId
                || receipt.authorizationClass != 5 || receipt.recordChainHash == 0
                || receipt.authorizationDigest == 0 || receipt.recordedAt < w.condition.examinedAt
                || receipt.recordedAt > p.effectiveAt || receipt.deadline < receipt.recordedAt
                || receipt.schemaDefinitionHash != D.CONDITION_HASH
                || receipt.canonicalizationDefinitionHash != D.CANON_HASH
                || record.recordType != keccak256("INDEPENDENT_CONDITION")
                || record.subjectId != subject || record.schemaId != D.CONDITION_ID
                || record.contentHash.algorithm != 1
                || record.contentHash.canonicalizationId != D.CANON_ID
                || record.contentHash.digest.length != 32
                || bytes32(record.contentHash.digest) != keccak256(payload)
                || (record.signatureScheme != keccak256("EIP712")
                    && record.signatureScheme != keccak256("ERC1271"))
        ) {
            revert M.InvalidModeEvidence();
        }
        raw = Read.read(
            host, abi.encodeCall(A.recordPayload, (w.conditionRecordHash)), 8320, d.sourceGas
        );
        (address pointer, bytes memory stored) = abi.decode(raw, (address, bytes));
        Read.canonical(host, raw, abi.encode(pointer, stored));
        if (pointer.code.length == 0 || keccak256(stored) != keccak256(payload)) {
            revert M.InvalidModeEvidence();
        }
        raw = Read.exact(
            host, abi.encodeCall(A.recordSubject, (w.conditionRecordHash)), 128, d.readGas
        );
        A.Subject memory origin = abi.decode(raw, (A.Subject));
        Read.canonical(host, raw, abi.encode(origin));
        if (
            origin.kind != A.SubjectKind.COLLECTION || origin.collectionId != p.collectionId
                || origin.tokenId != 0 || origin.objectId != 0
        ) {
            revert M.InvalidModeEvidence();
        }
        if (
            abi.decode(
                    Read.exact(
                        host,
                        abi.encodeCall(
                            A.recordHashAt, (p.collectionId, record.recordType, receipt.recordIndex)
                        ),
                        32,
                        d.readGas
                    ),
                    (bytes32)
                ) != w.conditionRecordHash
        ) {
            revert M.InvalidModeEvidence();
        }
        StreamCollectionRecordHashes.Preimage memory pre;
        pre.domain = keccak256("6529stream.preservation-record.v2");
        pre.chainId = d.chainId;
        pre.host = host;
        pre.core = d.targets[0];
        pre.recorder = receipt.attestor;
        pre.collectionId = p.collectionId;
        pre.recordType = record.recordType;
        pre.subjectId = record.subjectId;
        pre.contentHash = StreamCollectionRecordHashes.hashRef(
            record.contentHash.algorithm,
            record.contentHash.digest,
            record.contentHash.canonicalizationId
        );
        pre.uriHash = keccak256(bytes(record.uri));
        pre.schemaId = record.schemaId;
        pre.signatureScheme = record.signatureScheme;
        pre.signatureHash = StreamCollectionRecordHashes.hashRef(
            record.signatureHash.algorithm,
            record.signatureHash.digest,
            record.signatureHash.canonicalizationId
        );
        pre.effectiveAt = record.effectiveAt;
        if (keccak256(abi.encode(pre)) != w.conditionRecordHash) revert M.InvalidModeEvidence();
        _bundle(d, host, w.conditionRecordHash, record, receipt, payload);
        return keccak256(abi.encode(receipt));
    }

    function _bundle(
        R.Dependencies memory d,
        address host,
        bytes32 hash,
        P.CollectionRecord memory r,
        A.Receipt memory receipt,
        bytes memory payload
    ) private view {
        bytes memory raw = Read.read(
            host, abi.encodeCall(A.recordSignatureBundle, (hash)), 8320, d.sourceGas
        );
        (address pointer, bytes memory bundle) = abi.decode(raw, (address, bytes));
        Read.canonical(host, raw, abi.encode(pointer, bundle));
        if (
            pointer.code.length == 0 || bundle.length > 8192 || r.signatureHash.algorithm != 1
                || r.signatureHash.canonicalizationId != keccak256("RAW_BYTES")
                || r.signatureHash.digest.length != 32
                || bytes32(r.signatureHash.digest) != keccak256(bundle)
        ) revert M.InvalidModeEvidence();
        (bytes32 domain, bytes32[14] memory words, bytes memory signature) =
            abi.decode(bundle, (bytes32, bytes32[14], bytes));
        Read.canonical(host, bundle, abi.encode(domain, words, signature));
        bytes32 expectedDomain = keccak256(
            abi.encode(
                keccak256(
                    "EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"
                ),
                keccak256("6529StreamCollectionAttestations"),
                keccak256("1"),
                d.chainId,
                host
            )
        );
        bytes32[14] memory expected;
        expected[0] = 0xcb13914f7a4c90b3e2d3d1513c3009284117ccab71b2a60935a620486947c768;
        expected[1] = bytes32(uint256(uint160(receipt.attestor)));
        expected[2] = bytes32(receipt.scopeKey);
        expected[3] = r.subjectId;
        expected[4] = r.recordType;
        expected[5] = r.schemaId;
        expected[6] = bytes32(uint256(r.contentHash.algorithm));
        expected[7] = keccak256(r.contentHash.digest);
        expected[8] = r.contentHash.canonicalizationId;
        expected[9] = keccak256(bytes(r.uri));
        expected[10] = keccak256(payload);
        expected[11] = bytes32(uint256(r.effectiveAt));
        expected[12] = bytes32(receipt.nonce);
        expected[13] = bytes32(uint256(receipt.deadline));
        if (
            domain != expectedDomain || signature.length == 0 || signature.length > 4096
                || keccak256(abi.encode(words)) != keccak256(abi.encode(expected))
                || keccak256(abi.encodePacked(hex"1901", domain, keccak256(abi.encode(words))))
                    != receipt.authorizationDigest
        ) {
            revert M.InvalidModeEvidence();
        }
    }

    function _binding(address host, string memory getter, address target, uint256 cap)
        private
        view
    {
        if (
            abi.decode(Read.exact(host, abi.encodeWithSignature(getter), 32, cap), (address))
                != target
        ) {
            revert M.InvalidModeEvidence();
        }
    }
}
