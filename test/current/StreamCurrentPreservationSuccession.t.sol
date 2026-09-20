// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./StreamCurrentRecoveredArtistMigration.t.sol";
import {
    StreamArtistMultipleRecordsTypes as ArchiveRecords
} from "../../smart-contracts/interfaces/stream/artist/IStreamArtistMultipleRecordsHydration.sol";
import {
    StreamArtistReadinessHydrationTypes as ArchiveReady
} from "../../smart-contracts/interfaces/stream/artist/IStreamArtistReadinessAuthorityHydration.sol";
import {
    StreamArtistRecordPublicationTypes as ArchivePublication
} from "../../smart-contracts/interfaces/stream/artist/StreamArtistRecordPublicationTypes.sol";
import {
    IStreamArtistRecordPublicationOwner as ArchivePublicationOwner
} from "../../smart-contracts/interfaces/stream/artist/IStreamArtistRecordPublicationOwner.sol";
import {
    StreamArtistHashes as ArchiveArtistHashes
} from "../../smart-contracts/domains/artist/StreamArtistHashes.sol";
import {
    StreamPreservationArtistBundleReads as ArchiveArtistBundle
} from "../../smart-contracts/domains/preservation/StreamPreservationArtistBundleReads.sol";
import {
    StreamPreservationOriginalReads as ArchiveOriginal
} from "../../smart-contracts/domains/preservation/StreamPreservationOriginalReads.sol";
import {
    StreamBundleArchiveReads as ArchiveBundle
} from "../../smart-contracts/domains/preservation/StreamBundleArchiveReads.sol";
import {
    StreamRenderCriticalSourceTypes as ArchiveSources
} from "../../smart-contracts/interfaces/stream/preservation/StreamRenderCriticalSourceTypes.sol";
import {
    StreamPreservationInventoryTypes as ArchiveInventory
} from "../../smart-contracts/interfaces/stream/preservation/StreamPreservationInventoryTypes.sol";
import {
    StreamBundleArchiveTypes as ArchiveCoverage
} from "../../smart-contracts/interfaces/stream/preservation/StreamBundleArchiveTypes.sol";
import {
    IStreamPreservationRecords as ArchiveMetadataRecord
} from "../../smart-contracts/interfaces/stream/preservation/IStreamPreservationRecords.sol";
import {
    StreamRecordFamilies as ArchiveFamilies
} from "../../smart-contracts/domains/records/StreamRecordFamilies.sol";
import {
    StreamMetadataSubjects as ArchiveSubjects
} from "../../smart-contracts/domains/metadata/StreamMetadataSubjects.sol";

/// @notice Actual publication and recovered60 recipe shared by preservation component tests.
/// @dev Current authority and immutable historical records are exercised separately. This
/// fixture alone does not establish complete inventory or selected Finality acceptance.
abstract contract StreamCurrentPreservationSuccessionFixture is
    StreamCurrentRecoveredArtistMigrationFixture
{
    bytes32 internal constant STATEMENT = keccak256("ARTIST_STATEMENT");
    bytes32 internal constant SCHEMA = keccak256("STREAM_ARTIST_STATEMENT_V1");

    struct PublicationRecord {
        bytes32 metadataRecord;
        bytes32 attestation;
        bytes32 archiveId;
        T.Attestation terms;
        uint256 nonce;
        ArchivePublication.Evidence evidence;
        bytes payload;
        bytes archiveBytes;
    }
    PublicationRecord internal original;

    function _additionalOperatingPolicies()
        internal
        view
        override
        returns (GovernanceActionPolicyEntry[] memory rows)
    {
        GovernanceActionPolicyEntry[] memory prior = super._additionalOperatingPolicies();
        rows = new GovernanceActionPolicyEntry[](prior.length + 2);
        for (uint256 i; i < prior.length; ++i) {
            rows[i] = prior[i];
        }
        rows[prior.length] =
            _policy(1, address(assemblySchemas), assemblySchemas.registerDocument.selector);
        rows[prior.length + 1] =
            _policy(1, address(assemblyMetadata), assemblyMetadata.admitRecordType.selector);
    }

    function _request() internal view override returns (MigrationHydration.Request memory p) {
        p = super._request();
        require(original.attestation != 0, "one actual original publication");
        ArchiveReady.AttestationInput[] memory rows = new ArchiveReady.AttestationInput[](1);
        rows[0] = ArchiveReady.AttestationInput(original.terms, original.nonce);
        p.records.witnesses = new ArchiveRecords.CollectionWitness[](1);
        p.records.witnesses[0] =
            ArchiveRecords.CollectionWitness(1, new T.EconomicsConsent[](0), rows);
    }

    function _seedOriginalPublication() internal {
        _document(
            "RAW_BYTES",
            IStreamSchemaRegistry.DocumentKind.CANONICALIZATION,
            bytes(assemblySchemas.RAW_BYTES_DEFINITION())
        );
        _document(
            "RFC8785_JCS",
            IStreamSchemaRegistry.DocumentKind.CANONICALIZATION,
            bytes(vm.readFile("schemas/museum/account-profile/RFC8785_JCS.json"))
        );
        // Metadata admits this statement schema ID. These exact fixture bytes define only
        // a generic object; no full statement or typed conservation profile is claimed.
        _document(
            "STREAM_ARTIST_STATEMENT_V1",
            IStreamSchemaRegistry.DocumentKind.SCHEMA,
            bytes('{"type":"object"}')
        );
        (bytes32 scope, bytes32 before_, bytes32 after_) =
            assemblyMetadata.recordTypeTransition(STATEMENT, ArchiveFamilies.ARTIST, 2);
        _govern(
            _governanceRequest(
                1,
                address(assemblyMetadata),
                abi.encodeCall(
                    assemblyMetadata.admitRecordType, (STATEMENT, ArchiveFamilies.ARTIST, uint16(2))
                ),
                scope,
                before_,
                after_
            )
        );
        original = _publish(artistSuite, address(artistCoordinator), "original");
        _candidate(
            2,
            "identity_authority.replay.attestation_key",
            keccak256(abi.encode(original.attestation))
        );
    }

    function _document(
        string memory name,
        IStreamSchemaRegistry.DocumentKind kind,
        bytes memory payload
    ) internal {
        bytes32 id = keccak256(bytes(name));
        if (assemblySchemas.document(id).exists) {
            require(
                assemblySchemas.document(id).status == IStreamSchemaRegistry.DocumentStatus.ACTIVE
                    && keccak256(assemblySchemas.documentBytes(id)) == keccak256(payload),
                "exact active existing interpretation bytes"
            );
            return;
        }
        require(payload.length != 0 && payload.length <= 8192, "one actual bounded document");
        bytes32[] memory chunks = new bytes32[](1);
        (chunks[0],) = assemblyStore.publishChunk(payload);
        IStreamSchemaRegistry.DocumentSpec memory spec = IStreamSchemaRegistry.DocumentSpec(
            name,
            kind,
            keccak256(payload),
            assemblySchemas.RAW_BYTES(),
            0,
            "",
            uint32(payload.length)
        );
        (bytes32 scope, bytes32 before_, bytes32 after_) =
            assemblySchemas.registrationTransition(spec, chunks);
        _govern(
            _governanceRequest(
                1,
                address(assemblySchemas),
                abi.encodeCall(assemblySchemas.registerDocument, (spec, chunks)),
                scope,
                before_,
                after_
            )
        );
        require(
            keccak256(assemblySchemas.documentBytes(id)) == keccak256(payload),
            "real governed original document"
        );
    }

    function _publish(T.SuiteConfiguration memory suite, address coordinator, string memory label)
        internal
        returns (PublicationRecord memory result)
    {
        StreamArtistOnboardingRegistry facade =
            StreamArtistOnboardingRegistry(payable(suite.registry));
        result.payload = bytes(string.concat('{"statement":"', label, '"}'));
        (bytes32 payloadHash,) = assemblyStore.publishChunk(result.payload);
        require(
            payloadHash == keccak256(result.payload),
            "actual candidate payload retained before attestation"
        );
        ArchiveMetadataRecord.CollectionRecord memory record;
        record.recordType = STATEMENT;
        record.subjectId = ArchiveSubjects.scopeSubject(
            block.chainid,
            address(core),
            StreamFinalityScope(StreamFinalityScopeType.COLLECTION, 1, 0, 0)
        );
        record.schemaId = SCHEMA;
        record.contentHash = ArchiveMetadataRecord.HashRef(
            1, abi.encode(keccak256(result.payload)), keccak256("RFC8785_JCS")
        );
        record.uri = string.concat("ipfs://current-preservation-", label);
        record.effectiveAt = uint64(block.timestamp);
        result.metadataRecord =
            assemblyMetadata.deriveCollectionRecordHashFor(address(recoveredSafe), 1, record);
        ArchivePublication.Publication memory publication = ArchivePublication.Publication(
            address(assemblyMetadata),
            address(recoveredSafe),
            1,
            record.subjectId,
            STATEMENT,
            SCHEMA,
            keccak256("RFC8785_JCS"),
            1,
            keccak256(result.payload),
            keccak256(bytes(record.uri)),
            record.effectiveAt,
            result.metadataRecord
        );
        bytes memory statement = abi.encode(uint16(1), publication);
        result.terms = T.Attestation(
            1,
            8,
            record.subjectId,
            0,
            keccak256("6529STREAM_ARTIST_RECORD_PUBLICATION_V1"),
            keccak256(statement),
            record.uri
        );
        result.nonce =
        IStreamArtistIdentityOwner(suite.owners[2]).identity(fixtureArtistId).nonceHint;
        T.Authorization memory authorization =
            T.Authorization(result.nonce, uint64(block.timestamp), "");
        bytes32 digest = facade.attestationDigest(result.terms, authorization);
        authorization.signature = safeThresholdSignature(
            recoveredKeys, safeMessageDigest(recoveredSafe, abi.encode(digest))
        );
        if (suite.registry == address(artists)) _authorizationCandidate(digest, result.nonce);
        result.attestation = ArchiveArtistHashes.attestationRecordForAuthority(
            ArchiveArtistHashes.Environment(
                block.chainid, suite.registry, address(core), suite.mintManager
            ),
            result.terms,
            fixtureArtistId,
            address(recoveredSafe),
            1,
            result.nonce,
            authorization.time
        );
        uint256 count = MigrationNative(suite.owners[4]).artistNativeReceiptCount();
        _safeCall(
            suite.registry,
            abi.encodeCall(facade.recordArtistAttestation, (result.terms, authorization, statement))
        );
        HT.Receipt memory receipt = MigrationNative(suite.owners[4]).artistNativeReceiptAt(count);
        require(
            receipt.operation == 24 && receipt.recordHash == result.attestation
                && receipt.artistId == fixtureArtistId,
            "actual native op24 and exact original domain"
        );
        result.evidence =
        ArchivePublicationOwner(suite.owners[4]).publicationAttestation(result.attestation).evidence;
        require(
            result.evidence.attestationRecordHash == result.attestation
                && result.evidence.signer == address(recoveredSafe),
            "actual owner publication evidence"
        );
        _safeCall(
            address(assemblyMetadata),
            abi.encodeCall(
                assemblyMetadata.recordArtistCollectionRecordWithPayload,
                (address(recoveredSafe), uint256(1), record, result.payload, result.attestation)
            )
        );
        require(
            assemblyMetadata.consumedArtistAuthorization(result.attestation),
            "actual Metadata consumes exact publication"
        );
        result.archiveId = _archiveId(suite.registry, coordinator, result.attestation);
        result.archiveBytes =
            IStreamArtistArchiveV2(suite.archive).artistEvidenceBytesV2(result.archiveId, 1);
        require(result.archiveBytes.length != 0, "original Coordinator retained complete evidence");
    }

    function _archiveId(address registry_, address coordinator, bytes32 record)
        internal
        view
        returns (bytes32)
    {
        return keccak256(
            abi.encode(
                keccak256("6529STREAM_ARTIST_ONBOARDING_OPERATION_EVIDENCE_V1"),
                block.chainid,
                registry_,
                coordinator,
                uint16(24),
                address(recoveredSafe),
                record
            )
        );
    }

    function _sources(T.SuiteConfiguration memory suite, address coordinator)
        internal
        view
        returns (ArchiveSources.Dependencies memory d)
    {
        d.targets[0] = address(core);
        d.targets[1] = address(assemblyMetadata);
        d.targets[4] = address(router);
        for (uint256 i; i < 12; ++i) {
            d.codeHashes[i] = d.targets[i].codehash;
        }
        d.artistTargets =
            [suite.registry, coordinator, suite.owners[2], suite.owners[4], suite.archive];
        for (uint256 i; i < 5; ++i) {
            d.artistCodeHashes[i] = d.artistTargets[i].codehash;
        }
        d.artistContentOwner = suite.owners[6];
        d.artistContentOwnerCodeHash = suite.owners[6].codehash;
        d.chainId = block.chainid;
        d.readGas = 500000;
        d.sourceGas = 4000000;
    }

    /// @dev Exact component boundary; no complete Snapshot/Reference/inventory prerequisites are claimed.
    function readPublicationBundle(
        ArchiveSources.Dependencies calldata d,
        ArchivePublication.Evidence calldata evidence,
        bytes32 record
    ) external view returns (ArchiveInventory.Item memory) {
        return ArchiveArtistBundle.item(d, evidence, record, address(recoveredSafe));
    }

    function admitArchiveItem(address archive, ArchiveInventory.Item calldata item)
        external
        view
        returns (ArchiveCoverage.Admission memory a, bytes32 observation)
    {
        ArchiveCoverage.Dependencies memory d;
        d.targets[5] = archive;
        d.codeHashes[5] = archive.codehash;
        d.chainId = block.chainid;
        d.readGas = 500000;
        d.archiveGas = 2000000;
        ArchiveCoverage.Proof memory proof;
        return ArchiveBundle.admit(d, fixtureArtistId, item, proof);
    }

    function _migrate() internal {
        _cutover();
        (MigrationHydration.Request memory request, Commit.Prepared memory prepared) = _prepared();
        _safeCall(
            address(successor),
            abi.encodeCall(MigrationRecovered.hydrateRecoveredArtistAuthority, (request))
        );
        _assertImported(prepared);
        require(
            keccak256(
                abi.encode(
                    ArchivePublicationOwner(destination.owners[4])
                        .publicationAttestation(original.attestation)
                )
            )
            == keccak256(
                abi.encode(
                    ArchivePublicationOwner(artistSuite.owners[4])
                        .publicationAttestation(original.attestation)
                )
            ),
            "import retains original publication tuple"
        );
    }
}

/// @notice Original negative characterizations retain their existing assertions.
contract StreamCurrentPreservationSuccessionTest is StreamCurrentPreservationSuccessionFixture {
    function testHistoricalPublicationRetainsOriginalArchiveAfterActualRecoveredSuccession()
        public
    {
        _seedOriginalPublication();
        ArchiveSources.Dependencies memory historical =
            _sources(artistSuite, address(artistCoordinator));
        ArchiveInventory.Item memory before_ =
            this.readPublicationBundle(historical, original.evidence, original.metadataRecord);
        require(
            before_.source == artistSuite.archive && before_.sourceRecord == original.archiveId,
            "exact original archive and evidence id"
        );
        _migrate();
        bytes32 sourceState = _state(artistSuite);
        bytes32 selectedState = _state(destination);
        ArchiveInventory.Item memory retained =
            this.readPublicationBundle(historical, original.evidence, original.metadataRecord);
        require(
            keccak256(abi.encode(retained)) == keccak256(abi.encode(before_)),
            "historical loader remains byte-exact after real60"
        );
        require(
            keccak256(
                IStreamArtistArchiveV2(artistSuite.archive)
                    .artistEvidenceBytesV2(original.archiveId, 1)
            ) == keccak256(original.archiveBytes),
            "immutable source evidence remains in original domain"
        );
        ArchiveSources.Context memory context_;
        context_.collectionId = 1;
        context_.subject = original.terms.subjectId;
        ArchiveInventory.Item[] memory metadataItems = ArchiveOriginal.items(
            historical, context_, original.metadataRecord, keccak256(original.payload)
        );
        require(
            metadataItems.length == 2 && metadataItems[0].source == address(assemblyMetadata)
                && metadataItems[1].sourceRecord == original.metadataRecord,
            "original Metadata tuple and exact payload remain available"
        );
        ArchiveSources.Dependencies memory current =
            _sources(destination, address(successorCoordinator));
        vm.expectRevert(abi.encodeWithSelector(ArchiveInventory.InvalidInventoryItem.selector));
        this.readPublicationBundle(current, original.evidence, original.metadataRecord);
        (ArchiveCoverage.Admission memory admission,) =
            this.admitArchiveItem(artistSuite.archive, retained);
        require(
            admission.immutablePartsHash != 0 && admission.originalBundleHash != 0,
            "actual original Archive correspondence passes"
        );
        vm.expectRevert(abi.encodeWithSelector(ArchiveInventory.InvalidInventoryItem.selector));
        this.admitArchiveItem(destination.archive, retained);
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamArtistArchiveV2.ArtistArchiveEvidenceUnavailable.selector,
                original.archiveId,
                uint64(1)
            )
        );
        IStreamArtistArchiveV2(destination.archive).artistEvidenceBytesV2(original.archiveId, 1);
        require(
            _state(artistSuite) == sourceState && _state(destination) == selectedState,
            "preservation reads never mutate either Artist"
        );
    }

    function testFreshSuccessorPublicationNeedsItsOwnOriginalArchiveDomain() public {
        _seedOriginalPublication();
        _migrate();
        bytes32 sourceState = _state(artistSuite);
        PublicationRecord memory fresh =
            _publish(destination, address(successorCoordinator), "successor");
        bytes32 wrongId =
            _archiveId(address(artists), address(artistCoordinator), fresh.attestation);
        require(
            fresh.archiveId != wrongId && destination.archive != artistSuite.archive,
            "distinct genuine publication origins"
        );
        require(
            IStreamArtistArchiveV2(destination.archive)
            .artistEvidenceBytesV2(fresh.archiveId, 1)
            .length != 0,
            "fresh original bytes live in successor Archive"
        );
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamArtistArchiveV2.ArtistArchiveEvidenceUnavailable.selector, wrongId, uint64(1)
            )
        );
        IStreamArtistArchiveV2(artistSuite.archive).artistEvidenceBytesV2(wrongId, 1);
        ArchiveSources.Dependencies memory historical =
            _sources(artistSuite, address(artistCoordinator));
        vm.expectRevert(
            abi.encodeWithSelector(ArchiveInventory.InventoryRead.selector, artistSuite.archive)
        );
        this.readPublicationBundle(historical, fresh.evidence, fresh.metadataRecord);
        ArchiveSources.Dependencies memory current =
            _sources(destination, address(successorCoordinator));
        vm.expectRevert(abi.encodeWithSelector(ArchiveInventory.InvalidInventoryItem.selector));
        this.readPublicationBundle(current, fresh.evidence, fresh.metadataRecord);
        require(
            _state(artistSuite) == sourceState
                && assemblyMetadata.artistRegistry() == address(artists),
            "fresh current authority does not rewrite source or Metadata ancestry"
        );
    }
}
