// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./StreamCurrentPreservationSuccession.t.sol";
import {
    StreamMultiOriginArtistBundleReads as MultiBundles
} from "../../smart-contracts/domains/preservation/StreamMultiOriginArtistBundleReads.sol";
import {
    StreamArtistArchiveOriginTypes as Origin
} from "../../smart-contracts/interfaces/stream/preservation/StreamArtistArchiveOriginTypes.sol";
import {
    IStreamArtistImportedReceiptRead as ImportedReceipt
} from "../../smart-contracts/interfaces/stream/artist/IStreamArtistImportedReceiptRead.sol";

/// @notice Genuine publication24 before/after actual Core/Safe governed55 and recovered60.
/// @dev Component acceptance only: the exact original Metadata/Archive are real. No completed
/// Snapshot/Reference/inventory, selected successor Finality or sanction closure is asserted.
contract StreamCurrentMultiOriginPublicationTest is StreamCurrentPreservationSuccessionFixture {
    bytes32 private constant CONTEXT = keccak256("actual publication component context");

    function readMultiOriginPublication(
        ArchiveSources.Dependencies calldata d,
        PublicationRecord calldata p,
        address actor,
        Origin.ReceiptWitness calldata witness
    ) external view returns (ArchiveInventory.Item memory item, Origin.RecordOrigin memory fact) {
        return
            MultiBundles.publicationItem(d, p.evidence, p.metadataRecord, actor, CONTEXT, witness);
    }

    function _completePins(T.SuiteConfiguration memory suite, address coordinator)
        private
        view
        returns (ArchiveSources.Dependencies memory d)
    {
        // Actual source graph dependencies; this isolated record reader does not claim that
        // their complete preservation prerequisites or current selection have been satisfied.
        d = _assemblyInventoryDependencies();
        d.artistTargets =
            [suite.registry, coordinator, suite.owners[2], suite.owners[4], suite.archive];
        for (uint256 i; i < 5; ++i) {
            d.artistCodeHashes[i] = d.artistTargets[i].codehash;
        }
        d.artistContentOwner = suite.owners[6];
        d.artistContentOwnerCodeHash = suite.owners[6].codehash;
    }

    function _nativeWitness(address owner, bytes32 record)
        private
        view
        returns (Origin.ReceiptWitness memory)
    {
        uint256 count = MigrationNative(owner).artistNativeReceiptCount();
        for (uint256 i; i < count; ++i) {
            HT.Receipt memory row = MigrationNative(owner).artistNativeReceiptAt(i);
            if (row.operation == 24 && row.recordHash == record) {
                return Origin.ReceiptWitness(Origin.Lane.NATIVE, i);
            }
        }
        revert("actual native publication occurrence missing");
    }

    function _importedWitness(bytes32 record)
        private
        view
        returns (Origin.ReceiptWitness memory witness)
    {
        (MigrationHydration.OwnerProvenance memory prefix, bytes32 commitment, uint64 revision) =
            RecoveredOwner(destination.owners[4]).recoveredHydrationImportedPrefix();
        require(commitment != 0 && revision != 0, "actual installed prefix");
        for (uint256 i; i < prefix.journal.length; ++i) {
            if (
                prefix.journal[i].receipt.operation == 24
                    && prefix.journal[i].receipt.recordHash == record
            ) {
                (MigrationHydration.JournalEntry memory row, bytes32 c, uint64 r) =
                    ImportedReceipt(destination.owners[4]).recoveredHydrationImportedReceiptAt(i);
                require(
                    keccak256(abi.encode(row)) == keccak256(abi.encode(prefix.journal[i]))
                        && c == commitment && r == revision,
                    "bounded read agrees with genuine prefix"
                );
                return Origin.ReceiptWitness(Origin.Lane.IMPORTED, i);
            }
        }
        revert("actual imported publication occurrence missing");
    }

    function _assertOriginal(
        ArchiveInventory.Item memory item,
        Origin.RecordOrigin memory fact,
        PublicationRecord memory p,
        T.SuiteConfiguration memory suite,
        address coordinator
    ) private view {
        require(
            item.source == suite.archive && item.sourceRecord == p.archiveId
                && item.sourceIndex == 1,
            "exact producer Archive and unchanged evidence ID/version"
        );
        require(
            fact.producer.environment.registry == suite.registry
                && fact.producer.environment.coordinator == coordinator
                && fact.occurrence.receipt.recordHash == p.attestation
                && fact.occurrence.receipt.operation == 24
                && fact.occurrence.position.point.ownerIndex == 4
                && fact.actor == address(recoveredSafe) && fact.sourceContextHash == CONTEXT
                && Origin.evidenceId(fact) == p.archiveId,
            "original occurrence and actor"
        );
        require(
            fact.semanticRecordHash
                == keccak256(
                    abi.encode(
                        ArchivePublicationOwner(suite.owners[4])
                            .publicationAttestation(p.attestation)
                    )
                ),
            "complete genuine retained publication tuple"
        );
        require(
            keccak256(IStreamArtistArchiveV2(suite.archive).artistEvidenceBytesV2(p.archiveId, 1))
                    == keccak256(p.archiveBytes)
                && assemblyMetadata.consumedArtistAuthorization(p.attestation),
            "actual unchanged Archive bytes and consumed Metadata authorization"
        );
        (ArchiveCoverage.Admission memory admitted,) = this.admitArchiveItem(suite.archive, item);
        require(
            admitted.originalBundleHash != 0 && admitted.immutablePartsHash != 0,
            "genuine original STOP byte correspondence"
        );
    }

    function testActualNativeAndImportedPublicationUseUnchangedOriginalArchive() public {
        _seedOriginalPublication();
        Origin.ReceiptWitness memory native =
            _nativeWitness(artistSuite.owners[4], original.attestation);
        (ArchiveInventory.Item memory before_, Origin.RecordOrigin memory local) = this.readMultiOriginPublication(
            _completePins(artistSuite, address(artistCoordinator)),
            original,
            address(recoveredSafe),
            native
        );
        _assertOriginal(before_, local, original, artistSuite, address(artistCoordinator));
        require(
            local.importCommitment == 0 && local.importedAtRevision == 0, "native markers absent"
        );
        _migrate();
        bytes32 sourceBefore = _state(artistSuite);
        bytes32 currentBefore = _state(destination);
        (ArchiveInventory.Item memory retained, Origin.RecordOrigin memory imported) = this.readMultiOriginPublication(
            _completePins(destination, address(successorCoordinator)),
            original,
            address(recoveredSafe),
            _importedWitness(original.attestation)
        );
        _assertOriginal(retained, imported, original, artistSuite, address(artistCoordinator));
        require(
            keccak256(abi.encode(local.occurrence)) == keccak256(abi.encode(imported.occurrence))
                && imported.importCommitment != 0 && imported.importedAtRevision != 0,
            "original native coordinate survives separate local import markers"
        );
        require(
            retained.provenanceHash != before_.provenanceHash
                && retained.objectHash == before_.objectHash
                && retained.byteSize == before_.byteSize
                && keccak256(retained.digest) == keccak256(before_.digest),
            "new admission provenance preserves exact original bytes"
        );
        require(
            _state(artistSuite) == sourceBefore && _state(destination) == currentBefore,
            "both full owner states unchanged by reads"
        );
    }

    function testActualImportedAAndFreshBNativeRecordsKeepSeparateProducerDomains() public {
        _seedOriginalPublication();
        _migrate();
        PublicationRecord memory fresh =
            _publish(destination, address(successorCoordinator), "new-B");
        ArchiveSources.Dependencies memory d =
            _completePins(destination, address(successorCoordinator));
        bytes32 sourceBefore = _state(artistSuite);
        bytes32 currentBefore = _state(destination);
        (ArchiveInventory.Item memory a, Origin.RecordOrigin memory af) = this.readMultiOriginPublication(
            d, original, address(recoveredSafe), _importedWitness(original.attestation)
        );
        (ArchiveInventory.Item memory b, Origin.RecordOrigin memory bf) = this.readMultiOriginPublication(
            d,
            fresh,
            address(recoveredSafe),
            _nativeWitness(destination.owners[4], fresh.attestation)
        );
        _assertOriginal(a, af, original, artistSuite, address(artistCoordinator));
        _assertOriginal(b, bf, fresh, destination, address(successorCoordinator));
        require(
            a.source != b.source && a.sourceRecord != b.sourceRecord && af.importCommitment != 0
                && bf.importCommitment == 0 && bf.importedAtRevision == 0,
            "current authority admits separate imported and locally produced records"
        );
        require(
            _state(artistSuite) == sourceBefore && _state(destination) == currentBefore,
            "neither producer state changes"
        );
    }

    function testActualImportedRecordRejectsWrongActorAndMissingMembershipThenRetries() public {
        _seedOriginalPublication();
        _migrate();
        ArchiveSources.Dependencies memory d =
            _completePins(destination, address(successorCoordinator));
        Origin.ReceiptWitness memory witness = _importedWitness(original.attestation);
        bytes32 sourceBefore = _state(artistSuite);
        bytes32 currentBefore = _state(destination);
        vm.expectRevert(
            abi.encodeWithSelector(ArchiveInventory.InventoryRead.selector, artistSuite.archive)
        );
        this.readMultiOriginPublication(d, original, address(artistSafe), witness);
        vm.expectRevert(
            abi.encodeWithSelector(ArchiveInventory.InventoryRead.selector, destination.owners[4])
        );
        this.readMultiOriginPublication(
            d,
            original,
            address(recoveredSafe),
            Origin.ReceiptWitness(Origin.Lane.IMPORTED, type(uint256).max)
        );
        require(
            _state(artistSuite) == sourceBefore && _state(destination) == currentBefore,
            "failed reads restore exact states"
        );
        (ArchiveInventory.Item memory item, Origin.RecordOrigin memory fact) =
            this.readMultiOriginPublication(d, original, address(recoveredSafe), witness);
        _assertOriginal(item, fact, original, artistSuite, address(artistCoordinator));
    }
}
