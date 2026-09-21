// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamViewRetrievalWitnessTypesV1 as T
} from "../../interfaces/stream/preservation/StreamViewRetrievalWitnessTypesV1.sol";
import {
    StreamExternalArtifactTypes as E
} from "../../interfaces/stream/preservation/StreamExternalArtifactTypes.sol";
import {
    StreamArchivalTypes as A
} from "../../interfaces/stream/preservation/StreamArchivalTypes.sol";
import {
    IStreamExternalArtifactCoverage as Archive
} from "../../interfaces/stream/preservation/IStreamExternalArtifactCoverage.sol";
import {
    StreamPreservationInventoryTypes as I
} from "../../interfaces/stream/preservation/StreamPreservationInventoryTypes.sol";
import {
    StreamBundleArchiveTypes as B
} from "../../interfaces/stream/preservation/StreamBundleArchiveTypes.sol";
import { StreamPreservationInventoryIO as IO } from "./StreamPreservationInventoryIO.sol";
import { StreamBundleArchiveReads as Original } from "./StreamBundleArchiveReads.sol";
import { StreamViewRetrievalCodecV1 as Codec } from "./StreamViewRetrievalCodecV1.sol";

/// @notice Full original same-pair admission; fresh signer attribution is separate from fixity.
library StreamViewRetrievalArchiveV1 {
    function admit(T.Configuration memory c, T.Source memory source, bytes32 coverageHash)
        public
        view
        returns (
            E.ObjectIdentity memory object,
            B.Admission memory admission,
            address writer,
            uint64 observedAt
        )
    {
        IO.pin(c.archive, c.archiveCodeHash);
        bytes memory raw = IO.fixedRead(
            c.archive, abi.encodeCall(Archive.coverage, (coverageHash)), 480, c.readGas
        );
        E.Coverage memory coverage = abi.decode(raw, (E.Coverage));
        IO.canonical(c.archive, raw, abi.encode(coverage));
        raw = IO.fixedRead(
            c.archive, abi.encodeCall(Archive.objectIdentity, (coverage.objectHash)), 320, c.readGas
        );
        object = abi.decode(raw, (E.ObjectIdentity));
        IO.canonical(c.archive, raw, abi.encode(object));
        if (source.artistId == 0 || object.artistId != source.artistId) {
            revert T.InvalidViewRetrieval();
        }
        I.Item memory item;
        item.kind = I.Kind.EXTERNAL_REFERENCE;
        item.role = T.ROLE;
        item.source = source.router;
        item.sourceRecord = source.adoptionRecord;
        item.algorithm = 1;
        item.canonicalizationId = keccak256("RAW_BYTES");
        item.digest = abi.encodePacked(object.contentHash);
        item.byteSize = object.byteSize;
        B.Dependencies memory d;
        d.targets[4] = c.archive;
        d.codeHashes[4] = c.archiveCodeHash;
        d.chainId = c.chainId;
        d.readGas = c.readGas;
        d.archiveGas = c.archiveGas;
        (admission,) =
            Original.admit(d, object.artistId, item, B.Proof(1, coverageHash, coverage.objectHash));
        if (keccak256(abi.encode(coverage)) != keccak256(abi.encode(admission.externalOriginal))) {
            revert T.InvalidViewRetrieval();
        }
        raw = IO.read(
            c.archive,
            abi.encodeCall(Archive.receipt, (coverage.secondReceiptHash)),
            65536,
            c.archiveGas
        );
        (E.Receipt memory receipt, bytes memory identifier, bytes memory signature) =
            abi.decode(raw, (E.Receipt, bytes, bytes));
        IO.canonical(c.archive, raw, abi.encode(receipt, identifier, signature));
        raw = IO.fixedRead(
            c.archive,
            abi.encodeCall(Archive.family, (coverage.secondFamilyRecordHash)),
            416,
            c.readGas
        );
        (A.Family memory family, uint8 status, uint64 revision) =
            abi.decode(raw, (A.Family, uint8, uint64));
        IO.canonical(c.archive, raw, abi.encode(family, status, revision));
        if (
            receipt.objectHash != coverage.objectHash
                || receipt.familyRecordHash != coverage.secondFamilyRecordHash
                || receipt.writer == address(0) || receipt.writer != family.storingAgent
                || family.economics != 2 || status != 1 || revision == 0
                || receipt.evidenceClass != keccak256("ATTESTED_POSSESSION")
                || receipt.proofProfileHash
                    != keccak256("STREAM_INSTITUTIONAL_EXTERNAL_OBJECT_POSSESSION_V1")
                || receipt.observedAt == 0 || keccak256(identifier) != receipt.storageIdentifierHash
                || keccak256(
                        abi.encode(
                            keccak256("6529STREAM_EXTERNAL_RECEIPT_V1"),
                            c.chainId,
                            c.archive,
                            receipt
                        )
                    ) != coverage.secondReceiptHash
        ) revert T.InvalidViewRetrieval();
        writer = receipt.writer;
        observedAt = receipt.observedAt;
    }

    function routes(T.Configuration memory c, T.Observation memory o) public view {
        Codec.shape(o);
        for (uint256 i; i < o.steps.length; ++i) {
            T.Step memory step = o.steps[i];
            if (step.kind == 3) {
                (E.ObjectIdentity memory object, B.Admission memory a,,) =
                    admit(c, o.source, step.manifestCoverage);
                if (
                    a.proof.objectHash != step.manifestObject
                        || object.artistId != o.object.artistId
                        || object.byteSize != step.manifestBytes.length
                        || object.contentHash != keccak256(step.manifestBytes)
                        || object.sha256Digest != sha256(step.manifestBytes)
                ) revert T.InvalidViewRetrieval();
                (, bytes32 transactionId) = Codec.uri(step.fromURI);
                _transaction(c, a.externalOriginal, transactionId);
            }
        }
        (uint8 kind, bytes32 transactionId) = Codec.uri(o.resolvedURI);
        if (kind == 2) _transaction(c, o.coverage, transactionId);
    }

    function _transaction(
        T.Configuration memory c,
        E.Coverage memory coverage,
        bytes32 transactionId
    ) private view {
        bytes memory raw = IO.read(
            c.archive,
            abi.encodeCall(Archive.receipt, (coverage.firstReceiptHash)),
            65536,
            c.archiveGas
        );
        (E.Receipt memory r, bytes memory locator, bytes memory sig) =
            abi.decode(raw, (E.Receipt, bytes, bytes));
        IO.canonical(c.archive, raw, abi.encode(r, locator, sig));
        if (
            locator.length != 32 || abi.decode(locator, (bytes32)) != transactionId
                || r.objectHash != coverage.objectHash
                || r.familyRecordHash != coverage.firstFamilyRecordHash
                || r.proofRecordHash != coverage.checkpointHash
                || r.storageIdentifierHash != keccak256(locator)
                || keccak256(
                        abi.encode(
                            keccak256("6529STREAM_EXTERNAL_RECEIPT_V1"), c.chainId, c.archive, r
                        )
                    ) != coverage.firstReceiptHash
        ) revert T.InvalidViewRetrieval();
    }
}
