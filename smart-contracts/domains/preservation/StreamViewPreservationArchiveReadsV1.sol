// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamBundleArchiveTypes as B
} from "../../interfaces/stream/preservation/StreamBundleArchiveTypes.sol";
import {
    StreamPreservationInventoryTypes as T
} from "../../interfaces/stream/preservation/StreamPreservationInventoryTypes.sol";
import {
    StreamExternalArtifactTypes as E
} from "../../interfaces/stream/preservation/StreamExternalArtifactTypes.sol";
import {
    IStreamExternalArtifactCoverage as Archive
} from "../../interfaces/stream/preservation/IStreamExternalArtifactCoverage.sol";
import { StreamPreservationInventoryIO as IO } from "./StreamPreservationInventoryIO.sol";
import { StreamBundleArchiveReads as Original } from "./StreamBundleArchiveReads.sol";
import {
    StreamViewPreservationMediaCorrespondenceV1 as Media
} from "./StreamViewPreservationMediaCorrespondenceV1.sol";

import {
    StreamViewRetrievalWitnessTypesV1 as W
} from "../../interfaces/stream/preservation/StreamViewRetrievalWitnessTypesV1.sol";

/// @notice VIEW-only exact locator-to-object observation under the original same-pair Archive.
/// @dev A locator is never hashed as file content. The original reader still verifies complete
/// object/coverage/receipt/fixity/native evidence and present liveness. No caller-selected profile.
library StreamViewPreservationArchiveReadsV1 {
    error InvalidViewLocatorCorrespondence();

    function admit(
        B.Dependencies memory d,
        bytes32 artist,
        T.Item memory item,
        B.Proof memory proof
    ) public view returns (B.Admission memory result, bytes32 observation) {
        if (item.role == W.ROLE) revert W.InvalidViewRetrieval();
        if (item.role != Media.LOCATOR_ROLE) {
            return Original.admit(d, artist, item, proof);
        }
        T.Item memory expected = Media.item(item.source, item.sourceRecord, item.uri);
        if (
            keccak256(abi.encode(item)) != keccak256(abi.encode(expected))
                || expected.role != Media.LOCATOR_ROLE || proof.backend != 1
                || proof.objectHash == 0 || proof.coverageHash == 0
        ) revert InvalidViewLocatorCorrespondence();
        if (block.chainid != d.chainId) revert T.InventorySourceChanged();
        IO.pin(d.targets[4], d.codeHashes[4]);
        bytes memory raw = IO.fixedRead(
            d.targets[4], abi.encodeCall(Archive.objectIdentity, (proof.objectHash)), 320, d.readGas
        );
        E.ObjectIdentity memory object = abi.decode(raw, (E.ObjectIdentity));
        IO.canonical(d.targets[4], raw, abi.encode(object));
        // A separate memory value supplies the already authenticated object's digest to the
        // unchanged full Archive verifier. The retained inventory obligation stays untouched.
        T.Item memory materialized = abi.decode(abi.encode(item), (T.Item));
        materialized.algorithm = 1;
        materialized.digest = abi.encodePacked(object.contentHash);
        materialized.byteSize = object.byteSize;
        (result, observation) = Original.admit(d, artist, materialized, proof);
        _locator(d, item.uri, result.externalOriginal);
    }

    function current(
        B.Dependencies memory d,
        bytes32 artist,
        T.Item memory item,
        B.Admission memory saved
    ) public view returns (bytes32 observation) {
        if (item.role == W.ROLE) revert W.InvalidViewRetrieval();
        if (item.role != Media.LOCATOR_ROLE) {
            return Original.current(d, artist, item, saved);
        }
        B.Admission memory actual;
        (actual, observation) = admit(d, artist, item, saved.proof);
        if (keccak256(abi.encode(actual)) != keccak256(abi.encode(saved))) {
            revert T.InventorySourceChanged();
        }
    }

    function _locator(B.Dependencies memory d, string memory uri, E.Coverage memory c)
        private
        view
    {
        (uint8 kind, bytes32 transactionId) = Media.locator(uri);
        bytes32 receiptHash = kind == 1 ? c.secondReceiptHash : c.firstReceiptHash;
        bytes memory raw = IO.read(
            d.targets[4], abi.encodeCall(Archive.receipt, (receiptHash)), 65536, d.archiveGas
        );
        (E.Receipt memory r, bytes memory locator, bytes memory signature) =
            abi.decode(raw, (E.Receipt, bytes, bytes));
        IO.canonical(d.targets[4], raw, abi.encode(r, locator, signature));
        bytes memory expected = kind == 1 ? bytes(uri) : abi.encodePacked(transactionId);
        if (
            r.objectHash != c.objectHash
                || r.familyRecordHash
                    != (kind == 1 ? c.secondFamilyRecordHash : c.firstFamilyRecordHash)
                || r.writer == address(0) || locator.length != expected.length
                || keccak256(locator) != keccak256(expected)
                || r.storageIdentifierHash != keccak256(expected)
                || keccak256(
                        abi.encode(
                            keccak256("6529STREAM_EXTERNAL_RECEIPT_V1"), d.chainId, d.targets[4], r
                        )
                    ) != receiptHash || (kind == 2 && r.proofRecordHash != c.checkpointHash)
        ) revert InvalidViewLocatorCorrespondence();
        // Original.currentReceiptPair independently authenticates institutional/endowed family
        // roles and current fixities; the endowed checkpoint binds this transaction/root/full size.
    }
}
