// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { ScopedPolicyReferenceFixtureV2 } from "./StreamScopedPolicyReferencePublicationV2.t.sol";
import { PreservationOnchainArchiveFixture } from "./PreservationOnchainArchiveFixture.sol";
import {
    StreamBundleArchiveReads as ArchiveReads
} from "../../../smart-contracts/domains/preservation/StreamBundleArchiveReads.sol";
import {
    StreamBundleArchiveTypes as B
} from "../../../smart-contracts/interfaces/stream/preservation/StreamBundleArchiveTypes.sol";
import {
    StreamPreservationInventoryTypes as I
} from "../../../smart-contracts/interfaces/stream/preservation/StreamPreservationInventoryTypes.sol";
import {
    StreamRenderCriticalSourceTypes as D
} from "../../../smart-contracts/interfaces/stream/preservation/StreamRenderCriticalSourceTypes.sol";
import {
    StreamScopedPolicyRenderCriticalTypesV2 as C
} from "../../../smart-contracts/interfaces/stream/preservation/StreamScopedPolicyRenderCriticalTypesV2.sol";
import {
    StreamScopedPolicyReferenceTypesV2 as R
} from "../../../smart-contracts/interfaces/stream/preservation/StreamScopedPolicyReferenceTypesV2.sol";
import {
    StreamScopedPolicyRenderCriticalNativeReadsV2 as Native
} from "../../../smart-contracts/domains/preservation/StreamScopedPolicyRenderCriticalNativeReadsV2.sol";
import {
    StreamScopedPolicyReferenceInventoryReadsV2 as References
} from "../../../smart-contracts/domains/preservation/StreamScopedPolicyReferenceInventoryReadsV2.sol";
import {
    StreamScopedPolicySnapshotDefinitionsV2 as SnapshotDefinitions
} from "../../../smart-contracts/domains/records/StreamScopedPolicySnapshotDefinitionsV2.sol";
import {
    StreamScopedPolicyReferenceDefinitionsV2 as ReferenceDefinitions
} from "../../../smart-contracts/domains/records/StreamScopedPolicyReferenceDefinitionsV2.sol";
import {
    IStreamCorePointers
} from "../../../smart-contracts/interfaces/stream/core/IStreamCorePointers.sol";
import {
    StreamFinalityArtifactTypes as F
} from "../../../smart-contracts/interfaces/stream/preservation/StreamFinalityArtifactTypes.sol";

/// @dev A thin entry into the exact production reader. No correspondence or Archive reply is mocked.
contract CanonicalProducedArchiveProbe {
    function admit(
        B.Dependencies calldata d,
        bytes32 artist,
        I.Item calldata row,
        B.Proof calldata p
    ) external view returns (B.Admission memory result) {
        (result,) = ArchiveReads.admit(d, artist, row, p);
    }

    function current(
        B.Dependencies calldata d,
        bytes32 artist,
        I.Item calldata row,
        B.Admission calldata original
    ) external view {
        ArchiveReads.current(d, artist, row, original);
    }
}

/// @dev Explicit selected Artist/Finality boundary for the separate historical-byte archive exercise.
contract CanonicalProducedArchiveSelection {
    address public immutable core;
    address public archivalCoverage;
    address public artifactCoverage;

    constructor(address core_) {
        core = core_;
    }

    function configure(address archive, address artifact) external {
        require(archivalCoverage == address(0) && archive != address(0) && artifact != address(0));
        archivalCoverage = archive;
        artifactCoverage = artifact;
    }
}

/// @notice Genuine scoped Snapshot/Reference publication and production inventory rows reach the
/// actual Archive reader with their original ABI schema/canonicalization and exact retained bytes.
/// @dev The inherited fixture authenticates native entropy, factory, checkpoint, Snapshot, Router
/// root, Reference, Metadata grants and Store. Core/Artist/governance/module admission and external
/// screenshot coverage remain its named typed boundaries. After both production rows are collected,
/// this test selects a separate typed Artist/Finality archive graph for the SAME Core and archives
/// the immutable original bytes through actual RoleRegistry, native checkpoint verifier, dual-family
/// ArchivalCoverage and ArtifactCoverage. Local observer/fixity signatures are synthetic observations.
/// This proves per-object correspondence/current Archive reads, not a complete current inventory,
/// VIEW coverage, full current-stack governance, network delivery or transaction-gas acceptance.
contract StreamCanonicalArchiveProducedPayloadsTest is
    ScopedPolicyReferenceFixtureV2,
    PreservationOnchainArchiveFixture
{
    CanonicalProducedArchiveProbe private probe;
    CanonicalProducedArchiveSelection private archiveSelection;
    B.Dependencies private archiveDependencies;

    struct Originals {
        I.Item snapshot;
        I.Item referenceRow;
        bytes snapshotBytes;
        bytes referenceBytes;
        bytes32 snapshotRecordHash;
        bytes32 referenceRecordHash;
    }

    function testActualTokenPolicySnapshotAndReferenceKeepCanonicalArchiveTuples() public {
        _paired(1);
    }

    function testActualReleasePolicySnapshotAndReferenceKeepCanonicalArchiveTuples() public {
        _paired(2);
    }

    function testActualSeasonPolicySnapshotAndReferenceKeepCanonicalArchiveTuples() public {
        _paired(3);
    }

    function testActualProducedRowRejectsMutantsAndOriginalFamilyStatusInvalidatesCurrent() public {
        Originals memory original = _produce(1);
        _archiveGraph();
        (B.Proof memory proof, B.Admission memory saved) =
            _cover(original.snapshot, original.snapshotBytes);
        bytes32 savedHash = keccak256(abi.encode(saved));
        bytes32 coverageHash = keccak256(abi.encode(ocArtifact.coverage(proof.coverageHash)));
        for (uint8 i; i < 8; ++i) {
            I.Item memory row = abi.decode(abi.encode(original.snapshot), (I.Item));
            if (i == 0) row.digest = abi.encodePacked(keccak256("different original bytes"));
            if (i == 1) ++row.byteSize;
            if (i == 2) row.schemaId = keccak256("different schema");
            if (i == 3) row.canonicalizationId = keccak256("different canonicalization");
            if (i == 4) row.kind = I.Kind.NATIVE_BYTES;
            if (i == 5) row.algorithm = 2;
            if (i == 6) row.role = 0;
            if (i == 7) row.role = bytes32(uint256(12345));
            _reject(abi.encodeCall(probe.admit, (archiveDependencies, SNAPSHOT_ARTIST, row, proof)));
        }
        _reject(
            abi.encodeCall(
                probe.admit,
                (archiveDependencies, SNAPSHOT_ARTIST, original.snapshot, B.Proof(0, 0, 0))
            )
        );
        _reject(
            abi.encodeCall(
                probe.admit,
                (
                    archiveDependencies,
                    SNAPSHOT_ARTIST,
                    original.snapshot,
                    B.Proof(2, proof.coverageHash, keccak256("different object"))
                )
            )
        );
        _reject(
            abi.encodeCall(
                probe.admit,
                (
                    archiveDependencies,
                    SNAPSHOT_ARTIST,
                    original.snapshot,
                    B.Proof(2, keccak256("different coverage"), proof.objectHash)
                )
            )
        );
        B.Admission memory retry =
            probe.admit(archiveDependencies, SNAPSHOT_ARTIST, original.snapshot, proof);
        require(keccak256(abi.encode(retry)) == savedHash, "exact unchanged admission retry");
        probe.current(archiveDependencies, SNAPSHOT_ARTIST, original.snapshot, saved);

        _familyStatus(2);
        _reject(
            abi.encodeCall(
                probe.current, (archiveDependencies, SNAPSHOT_ARTIST, original.snapshot, saved)
            )
        );
        require(
            keccak256(abi.encode(ocArtifact.coverage(proof.coverageHash))) == coverageHash,
            "family status never rewrites original coverage"
        );
        _familyStatus(1);
        // Restoring admission does not erase the epoch change: actual chunk refresh is required.
        _reject(
            abi.encodeCall(
                probe.current, (archiveDependencies, SNAPSHOT_ARTIST, original.snapshot, saved)
            )
        );
        for (uint32 i; i < saved.onchainOriginal.chunkCount; ++i) {
            ocArtifact.refreshNextChunk(
                proof.coverageHash,
                i,
                ocArtifact.originalArtifactChunkCoverage(proof.coverageHash, i)
            );
        }
        probe.current(archiveDependencies, SNAPSHOT_ARTIST, original.snapshot, saved);
        retry = probe.admit(archiveDependencies, SNAPSHOT_ARTIST, original.snapshot, proof);
        require(
            keccak256(abi.encode(retry)) == savedHash, "same original bundle after live refresh"
        );
        _historical(original);
    }

    function _paired(uint8 scopeKind) private {
        Originals memory original = _produce(scopeKind);
        bytes32 snapshotRow = keccak256(abi.encode(original.snapshot));
        bytes32 referenceRow = keccak256(abi.encode(original.referenceRow));
        _archiveGraph();
        (, B.Admission memory snapshot) = _cover(original.snapshot, original.snapshotBytes);
        (, B.Admission memory reference_) = _cover(original.referenceRow, original.referenceBytes);
        require(
            snapshot.originalBundleHash != reference_.originalBundleHash,
            "distinct retained snapshot and reference bundles"
        );
        probe.current(archiveDependencies, SNAPSHOT_ARTIST, original.snapshot, snapshot);
        probe.current(archiveDependencies, SNAPSHOT_ARTIST, original.referenceRow, reference_);
        require(
            keccak256(abi.encode(original.snapshot)) == snapshotRow
                && keccak256(abi.encode(original.referenceRow)) == referenceRow,
            "production rows never relabelled"
        );
        _historical(original);
    }

    function _produce(uint8 scopeKind) private returns (Originals memory result) {
        _reference(1, scopeKind);
        bytes32 referenceId = _publishReference();
        R.Receipt memory receipt = referenceHost.currentReference(publication.scope);
        R.SourceFacts memory facts = referenceHost.referenceSource(referenceId);
        require(receipt.observation.recordHash == referenceId, "actual published reference head");
        D.Dependencies memory d;
        d.targets = [
            address(core),
            address(metadata),
            address(schemas),
            address(snapshotStore),
            address(router),
            address(snapshotHost),
            address(referenceHost),
            address(artist),
            address(artist),
            address(artist),
            address(snapshotCoverage),
            address(externalArchive)
        ];
        for (uint256 i; i < 12; ++i) {
            d.codeHashes[i] = d.targets[i].codehash;
        }
        for (uint256 i; i < 5; ++i) {
            d.artistTargets[i] = address(artist);
            d.artistCodeHashes[i] = address(artist).codehash;
        }
        d.artistContentOwner = address(artist);
        d.artistContentOwnerCodeHash = address(artist).codehash;
        d.chainId = block.chainid;
        d.readGas = 2000000;
        d.sourceGas = 16000000;
        d.selectionGas = 16000000;
        d.snapshotGas = 256000000;
        d.referenceGas = 512000000;
        C.Context memory c;
        c.scope = publication.scope;
        c.subject = facts.scopeSubject;
        c.artistId = facts.snapshotSource.artist.artistId;
        c.snapshot = facts.snapshot;
        c.snapshotSource = facts.snapshotSource;
        c.referenceRender = receipt;
        c.nativeHash = keccak256(abi.encode(facts.snapshotSource));
        c.rootRecordHash = facts.contentRootRecordHash;
        c.tokenInventoryHash = facts.snapshotSource.membership.membershipHash;
        c.checkpointHash = facts.snapshotSource.outputs.checkpointHash;
        c.outputManifestRecord = publication.outputManifestRecord;
        c.selectionId = facts.snapshotSource.content.selectionId;
        c.selectionHash = facts.snapshotSource.content.selectionHash;
        c.tokenCount = uint64(facts.snapshotSource.membership.tokenCount);
        (I.Item[] memory rows,) = Native.items(d, c, 1, 1);
        result.snapshot = rows[0];
        (rows,) = References.items(
            d,
            References.Context(c.scope, c.subject, c.artistId, c.snapshot, c.referenceRender),
            0,
            1
        );
        result.referenceRow = rows[0];
        result.snapshotBytes = snapshotHost.snapshotPayload(adoptedSnapshot);
        result.referenceBytes = referenceHost.referencePayload(referenceId);
        result.snapshotRecordHash = _snapshotRecord(adoptedSnapshot);
        result.referenceRecordHash = _referenceRecord(referenceId);
        _tuple(result.snapshot, SnapshotDefinitions.SCHEMA_ID, SnapshotDefinitions.CANON_ID);
        _tuple(result.referenceRow, ReferenceDefinitions.SCHEMA_ID, ReferenceDefinitions.CANON_ID);
        require(
            result.snapshot.source == address(snapshotHost)
                && result.snapshot.sourceRecord == adoptedSnapshot
                && result.referenceRow.source == address(referenceHost)
                && result.referenceRow.sourceRecord == referenceId,
            "original producer namespaces"
        );
    }

    function _tuple(I.Item memory row, bytes32 schema, bytes32 canon) private pure {
        require(
            row.kind == I.Kind.ORIGINAL_PAYLOAD && row.algorithm == 1 && row.schemaId == schema
                && row.canonicalizationId == canon && row.byteSize > 0,
            "genuine ABI payload tuple"
        );
        require(canon != keccak256("RAW_BYTES") && canon != keccak256("RFC8785_JCS"));
    }

    function _archiveGraph() private {
        archiveSelection = new CanonicalProducedArchiveSelection(address(core));
        _ocSetupArchive(address(core), address(executor), address(archiveSelection));
        _ocDeployArtifact(address(schemas), address(snapshotStore), address(archiveSelection));
        archiveSelection.configure(address(ocArchive), address(ocArtifact));
        core.setPointer(keccak256("ARTIST_REGISTRY"), address(archiveSelection));
        // Replace only the inherited explicit Core selection reply, after genuine row production.
        snapshotVm.mockCall(
            address(core),
            abi.encodeCall(
                IStreamCorePointers.getSatellitePointer, (keccak256("ARTWORK_FINALITY_REGISTRY"))
            ),
            abi.encode(
                address(archiveSelection),
                address(archiveSelection).codehash,
                false,
                keccak256("ARTWORK_FINALITY_REGISTRY"),
                bytes4(0),
                address(0),
                uint8(1),
                bytes32(0),
                bytes32(0),
                uint64(1)
            )
        );
        archiveDependencies.targets[0] = address(core);
        archiveDependencies.targets[1] = address(metadata);
        archiveDependencies.targets[3] = address(ocArtifact);
        archiveDependencies.codeHashes[0] = address(core).codehash;
        archiveDependencies.codeHashes[1] = address(metadata).codehash;
        archiveDependencies.codeHashes[3] = address(ocArtifact).codehash;
        archiveDependencies.chainId = block.chainid;
        archiveDependencies.readGas = 1000000;
        archiveDependencies.archiveGas = 4000000;
        probe = new CanonicalProducedArchiveProbe();
    }

    function _cover(I.Item memory row, bytes memory raw)
        private
        returns (B.Proof memory proof, B.Admission memory saved)
    {
        require(
            row.byteSize == raw.length
                && keccak256(row.digest) == keccak256(abi.encodePacked(keccak256(raw))),
            "exact retained producer bytes"
        );
        (bytes32 artifact, bytes32 completion) = _ocCover(raw, row.schemaId, row.canonicalizationId);
        proof = B.Proof(2, completion, artifact);
        saved = probe.admit(archiveDependencies, SNAPSHOT_ARTIST, row, proof);
        F.Coverage memory c = saved.onchainOriginal;
        require(
            c.artifactHash == artifact && c.completionHash == completion
                && c.schemaId == row.schemaId && c.canonicalizationId == row.canonicalizationId
                && c.contentHash == keccak256(raw) && c.byteLength == raw.length
                && c.firstFamilyRecordHash == ocFirstFamily
                && c.secondFamilyRecordHash == ocSecondFamily && saved.immutablePartsHash != 0
                && saved.originalBundleHash != 0,
            "actual original Archive correspondence and complete chunk evidence"
        );
    }

    function _historical(Originals memory original) private view {
        require(
            keccak256(snapshotHost.snapshotPayload(original.snapshot.sourceRecord))
                    == keccak256(original.snapshotBytes)
                && keccak256(referenceHost.referencePayload(original.referenceRow.sourceRecord))
                == keccak256(original.referenceBytes)
                && _snapshotRecord(original.snapshot.sourceRecord) == original.snapshotRecordHash
                && _referenceRecord(original.referenceRow.sourceRecord)
                    == original.referenceRecordHash,
            "original producer records and payloads remain unchanged"
        );
    }

    function _snapshotRecord(bytes32 id) private view returns (bytes32) {
        (bool ok, bytes memory raw) =
            address(snapshotHost).staticcall(abi.encodeWithSignature("snapshotRecord(bytes32)", id));
        require(ok);
        return keccak256(raw);
    }

    function _referenceRecord(bytes32 id) private view returns (bytes32) {
        (bool ok, bytes memory raw) = address(referenceHost)
            .staticcall(abi.encodeWithSignature("referenceRecord(bytes32)", id));
        require(ok);
        return keccak256(raw);
    }

    function _familyStatus(uint8 status) private {
        (bytes32 scope, bytes32 oldHash, bytes32 newHash) =
            ocArchive.familyStatusContext(ocFirstFamily, status);
        executor.execute(
            address(ocArchive),
            abi.encodeCall(ocArchive.setFamilyStatus, (ocFirstFamily, status)),
            scope,
            oldHash,
            newHash
        );
    }

    function _reject(bytes memory input) private view {
        (bool ok,) = address(probe).staticcall(input);
        require(!ok, "invalid actual Archive consumer input accepted");
    }

    function _ocBindArchiveRoles(address authority, address roles) internal override {
        snapshotVm.mockCall(authority, abi.encodeWithSignature("roleRegistry()"), abi.encode(roles));
        snapshotVm.mockCall(
            address(scopedModules),
            abi.encodeWithSignature("governanceExecutor()"),
            abi.encode(authority)
        );
    }

    function _ocArtistId() internal pure override returns (bytes32) {
        return SNAPSHOT_ARTIST;
    }
}
