// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./ArtistPublicationHydrationFixture.sol";
import { MetadataExecutorBoundary } from "../../helpers/scoped-preservation-boundaries/StreamCollectionMetadataV1Boundaries.sol";
import "../../../smart-contracts/domains/metadata/StreamConservationRecordSelection.sol";
import "../../../smart-contracts/domains/metadata/StreamRightsRecordSelection.sol";
import "../../../smart-contracts/domains/metadata/StreamNativeConservationFloorProvider.sol";
import {
    IStreamArtistPersonhoodEvidence,
    StreamArtistPersonhoodTypes as Personhood
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistPersonhoodEvidence.sol";
import {
    StreamArtistPersonhoodDefinitions as PersonhoodDefinitions
} from "../../../smart-contracts/domains/artist/StreamArtistPersonhoodDefinitions.sol";

/// @notice Actual Artist/Safe/op24/Archive joined to original conservation and RIGHTS records.
/// @dev The inherited Core, governance and original suite Router are explicit unit boundaries.
/// No personhood selection, summary, identity, publication or receipt is injected. This fixture
/// checks the collection-floor read only; it makes no release, paid-settlement or capacity claim.
abstract contract ArtistConservationPersonhoodFixture is ArtistPublicationHydrationFixture {
    MetadataExecutorBoundary internal personhoodGovernance;
    StreamSchemaRegistry internal personhoodSchemas;
    StreamSchemaDocumentStore internal personhoodStore;
    StreamCollectionMetadataV1 internal personhoodMetadata;
    StreamRightsRecordSelection internal personhoodRights;
    StreamConservationRecordSelection internal personhoodConservation;
    StreamNativeConservationFloorProvider internal personhoodProvider;
    bytes32 internal conservationSubject;
    bytes32 internal registrationIdentity;
    bytes32 internal rightsRecord;
    bytes32 internal intentWaiverRecord;
    bytes32 internal intentWaiverAuthorization;
    bytes32 internal constant PERSONHOOD_LITE = keccak256("MUSEUM_GRADE_LITE");
    bytes32 internal constant PERSONHOOD_FULL = keccak256("MUSEUM_GRADE");

    function _preparePersonhoodProvider() internal {
        actualSaleRegistryFixture = true;
        setUp();
        _accept();
        // Do not use _readinessHistory(): this test must start without a personhood head.
        registrationIdentity =
        IStreamArtistBindingOwner(suite.owners[0]).binding(1).identityRecordHash;
        personhoodGovernance = new MetadataExecutorBoundary();
        personhoodSchemas = new StreamSchemaRegistry(address(personhoodGovernance));
        personhoodStore = StreamSchemaDocumentStore(personhoodSchemas.chunkStore());
        _personhoodDocument(
            "RAW_BYTES",
            IStreamSchemaRegistry.DocumentKind.CANONICALIZATION,
            bytes(personhoodSchemas.RAW_BYTES_DEFINITION())
        );
        _personhoodDocument(
            "RFC8785_JCS",
            IStreamSchemaRegistry.DocumentKind.CANONICALIZATION,
            bytes(vm.readFile("schemas/museum/account-profile/RFC8785_JCS.json"))
        );
        string[10] memory names = [
            "STREAM_ARTIST_INTENT_V1",
            "STREAM_ARTIST_INTENT_JSON_PROFILE_V1",
            "STREAM_ARTIST_INTENT_WAIVER_V1",
            "STREAM_ARTIST_INTENT_WAIVER_JSON_PROFILE_V1",
            "STREAM_ARTIST_INTERVIEW_V1",
            "STREAM_ARTIST_INTERVIEW_JSON_PROFILE_V1",
            "STREAM_CONSERVATION_FORMAT_CATALOG_V1",
            "STREAM_CONSERVATION_FORMAT_CATALOG_JSON_PROFILE_V1",
            "STREAM_RIGHTS_V1",
            "STREAM_RIGHTS_JSON_PROFILE_V1"
        ];
        for (uint256 i; i < names.length; ++i) {
            _personhoodDocument(
                names[i],
                i % 2 == 0
                    ? IStreamSchemaRegistry.DocumentKind.SCHEMA
                    : IStreamSchemaRegistry.DocumentKind.CATALOG,
                bytes(vm.readFile(string.concat("schemas/records/", names[i], ".json")))
            );
        }
        StreamCollectionMetadataV1.Configuration memory c;
        c.core = address(core);
        c.executor = address(personhoodGovernance);
        c.schemas = address(personhoodSchemas);
        c.artistRegistry = address(ingress);
        c.deploymentManifestHash = keccak256("original Artist conservation personhood deployment");
        c.manifestHash = keccak256("original Artist conservation personhood manifest");
        c.manifestURI = "urn:artist-conservation-personhood";
        c.dependencyReadGas = IStreamGasParameterHost.GasParameterConfig(
            "METADATA_DEPENDENCY_READ_GAS", 150000, 100000, 2
        );
        c.artistReadGas = IStreamGasParameterHost.GasParameterConfig(
            "METADATA_ARTIST_READ_GAS", 2000000, 1000000, 2
        );
        personhoodMetadata = new StreamCollectionMetadataV1(c);
        _saleRegister(
            saleModules,
            factory.governanceAuthority(),
            address(personhoodMetadata),
            keccak256("COLLECTION_METADATA"),
            type(IStreamCollectionMetadataV1).interfaceId
        );
        core.set(keccak256("COLLECTION_METADATA"), address(personhoodMetadata), false);
        require(
            suite.metadata == address(metadata)
                && core.targets(keccak256("METADATA_ROUTER")) == address(metadata),
            "original Coordinator-pinned Router stays selected"
        );
        _personhoodRecordType(keccak256("ARTIST_INTENT_WAIVER"), StreamRecordFamilies.ARTIST, 2);
        _personhoodRecordType(keccak256("RIGHTS_STATEMENT"), StreamRecordFamilies.RIGHTS, 1 << 7);
        (bytes32 scope, bytes32 oldHash, bytes32 nextHash) = personhoodMetadata.familyWriterTransition(
            1, StreamRecordFamilies.RIGHTS, 7, address(this), true
        );
        personhoodGovernance.execute(
            address(personhoodMetadata),
            abi.encodeCall(
                personhoodMetadata.setFamilyWriter,
                (uint256(1), StreamRecordFamilies.RIGHTS, uint8(7), address(this), true)
            ),
            scope,
            oldHash,
            nextHash
        );
        conservationSubject = StreamMetadataSubjects.scopeSubject(
            block.chainid,
            address(core),
            StreamFinalityScope(StreamFinalityScopeType.COLLECTION, 1, 0, 0)
        );
        personhoodConservation = new StreamConservationRecordSelection(
            address(core), address(personhoodMetadata), address(personhoodSchemas)
        );
        personhoodRights = new StreamRightsRecordSelection(
            address(core), address(personhoodMetadata), address(personhoodSchemas)
        );
        _originalRights();
        _originalIntentWaiver();
        StreamNativeConservationFloorProvider.Configuration memory p;
        p.targets = [
            address(core),
            address(personhoodMetadata),
            address(personhoodSchemas),
            address(personhoodStore),
            address(personhoodRights),
            address(personhoodConservation),
            address(0),
            address(metadata),
            address(ingress),
            address(0)
        ];
        for (uint256 i; i < 9; ++i) {
            if (p.targets[i] != address(0)) p.codeHashes[i] = p.targets[i].codehash;
        }
        p.executor = address(personhoodGovernance);
        p.readGas = IStreamGasParameterHost.GasParameterConfig(
            "CONSERVATION_PROVIDER_READ_GAS", 300000, 100000, 2
        );
        p.sourceGas = IStreamGasParameterHost.GasParameterConfig(
            "CONSERVATION_PROVIDER_SOURCE_GAS", 8000000, 1000000, 2
        );
        p.referenceGas = IStreamGasParameterHost.GasParameterConfig(
            "CONSERVATION_PROVIDER_REFERENCE_GAS", 16000000, 1000000, 2
        );
        // No master/reference host is supplied: no release-floor success is asserted.
        personhoodProvider = new StreamNativeConservationFloorProvider(p);
    }

    function _personhoodDocument(
        string memory name,
        IStreamSchemaRegistry.DocumentKind kind,
        bytes memory payload
    ) internal {
        bytes32[] memory chunks = new bytes32[]((payload.length + 8191) / 8192);
        for (uint256 i; i < chunks.length; ++i) {
            uint256 size = payload.length - i * 8192;
            if (size > 8192) size = 8192;
            bytes memory chunk = new bytes(size);
            for (uint256 j; j < size; ++j) {
                chunk[j] = payload[i * 8192 + j];
            }
            (chunks[i],) = personhoodStore.publishChunk(chunk);
        }
        IStreamSchemaRegistry.DocumentSpec memory spec = IStreamSchemaRegistry.DocumentSpec(
            name, kind, keccak256(payload), keccak256("RAW_BYTES"), 0, "", uint32(payload.length)
        );
        (bytes32 scope, bytes32 oldHash, bytes32 nextHash) =
            personhoodSchemas.registrationTransition(spec, chunks);
        personhoodGovernance.execute(
            address(personhoodSchemas),
            abi.encodeCall(personhoodSchemas.registerDocument, (spec, chunks)),
            scope,
            oldHash,
            nextHash
        );
    }

    function _personhoodRecordType(bytes32 kind, bytes32 family, uint16 mask) internal {
        (bytes32 scope, bytes32 oldHash, bytes32 nextHash) =
            personhoodMetadata.recordTypeTransition(kind, family, mask);
        personhoodGovernance.execute(
            address(personhoodMetadata),
            abi.encodeCall(personhoodMetadata.admitRecordType, (kind, family, mask)),
            scope,
            oldHash,
            nextHash
        );
    }

    function _originalRecord(bytes32 kind, bytes32 schema, bytes memory payload)
        internal
        view
        returns (IStreamPreservationRecords.CollectionRecord memory r)
    {
        r.recordType = kind;
        r.subjectId = conservationSubject;
        r.schemaId = schema;
        r.contentHash = IStreamPreservationRecords.HashRef(
            1, abi.encode(keccak256(payload)), keccak256("RFC8785_JCS")
        );
        r.uri = "ipfs://original-artist-conservation-floor";
        r.effectiveAt = uint64(block.timestamp);
    }

    function _originalRights() internal {
        StreamRightsRecordTypes.Statement memory w;
        w.subjectId = conservationSubject;
        w.profileHash = StreamRightsRecordDefinitions.PROFILE_HASH;
        w.licensor.kind = StreamRightsRecordTypes.LicensorKind.ACCOUNT;
        w.licensor.account = address(artist);
        w.startDate = 20260920;
        w.openEnd = true;
        bytes memory payload = StreamRightsRecordJson.serialize(w);
        IStreamPreservationRecords.CollectionRecord memory r = _originalRecord(
            keccak256("RIGHTS_STATEMENT"), StreamRightsRecordDefinitions.SCHEMA_ID, payload
        );
        rightsRecord = personhoodMetadata.recordCollectionRecordWithPayload(1, r, payload);
        personhoodRights.selectCurrent(1, conservationSubject, rightsRecord, 0, 0, w);
    }

    function _originalIntentWaiver() internal {
        T.Binding memory b = IStreamArtistBindingOwner(suite.owners[0]).binding(1);
        IStreamConservationRecordSelection.WaiverWitness memory w;
        w.waiver.subjectId = conservationSubject;
        w.waiver.profileHash = StreamConservationDefinitions.WAIVER_PROFILE_HASH;
        w.waiver.artist = StreamConservationRecordTypes.ArtistClaim(
            artistId,
            b.generation,
            b.bindingHash,
            StreamConservationRecordTypes.StatementOrigin.ARTIST_INTENT
        );
        w.waiver.waiverStatement = _conservationStatement("ipfs://explicit-original-intent-waiver");
        w.waiver.interview.status = StreamConservationRecordTypes.InterviewStatus.WAIVED;
        w.waiver.interview.waiverStatement =
            _conservationStatement("ipfs://independent-original-interview-waiver");
        bytes memory payload = StreamArtistIntentWaiverJson.serialize(w.waiver);
        (bytes32 payloadHash,) = personhoodStore.publishChunk(payload);
        w.original = _originalRecord(
            keccak256("ARTIST_INTENT_WAIVER"),
            StreamConservationDefinitions.WAIVER_SCHEMA_ID,
            payload
        );
        P.Publication memory pub = P.Publication(
            address(personhoodMetadata),
            address(artist),
            1,
            conservationSubject,
            w.original.recordType,
            w.original.schemaId,
            keccak256("RFC8785_JCS"),
            1,
            payloadHash,
            keccak256(bytes(w.original.uri)),
            w.original.effectiveAt,
            personhoodMetadata.deriveCollectionRecordHashFor(address(artist), 1, w.original)
        );
        require(
            pub.candidateRecordHash == _canonicalRecordHash(w.original, pub),
            "original Metadata preimage"
        );
        bytes memory statement = abi.encode(uint16(1), pub);
        T.Attestation memory p = T.Attestation(
            1,
            7,
            conservationSubject,
            pub.candidateRecordHash,
            keccak256("6529STREAM_ARTIST_RECORD_PUBLICATION_V1"),
            keccak256(statement),
            w.original.uri
        );
        T.Authorization memory a = _authorization(true);
        a.signature = _signature(ingress.attestationDigest(p, a));
        intentWaiverAuthorization = ingress.recordArtistAttestation(p, a, statement);
        require(
            this.executeTargetSafe(
                address(personhoodMetadata),
                abi.encodeCall(
                    personhoodMetadata.recordArtistCollectionRecordWithPayload,
                    (address(artist), uint256(1), w.original, payload, intentWaiverAuthorization)
                )
            ),
            "original Artist Safe publishes exactly its signed intent waiver"
        );
        intentWaiverRecord = pub.candidateRecordHash;
        IStreamConservationRecordSelection.Selection memory selected =
            personhoodConservation.adoptWaiver(1, conservationSubject, intentWaiverRecord, 0, 0, w);
        require(
            selected.association.identityRecordHash == registrationIdentity
                && selected.record.publication.attestationRecordHash == intentWaiverAuthorization
                && selected.record.publication.requiredCapability == 64
                && selected.interviewStatus == StreamConservationRecordTypes.InterviewStatus.WAIVED
                && personhoodMetadata.consumedArtistAuthorization(intentWaiverAuthorization),
            "actual original association, op24 capability and consumed publication"
        );
        (, bytes memory stored) = personhoodMetadata.recordPayload(intentWaiverRecord);
        require(keccak256(stored) == keccak256(payload), "original full conservation bytes");
    }

    function _conservationStatement(string memory uri)
        internal
        pure
        returns (StreamConservationRecordTypes.Reference memory)
    {
        return StreamConservationRecordTypes.Reference(
            1, keccak256("RAW_BYTES"), abi.encode(keccak256(bytes(uri))), uri
        );
    }

    function _recordNativePersonhood(bytes memory statement, bytes32 schema)
        internal
        returns (bytes32 record)
    {
        T.Attestation memory p = T.Attestation(
            1,
            10,
            artistId,
            ingress.operativeIdentityRecord(artistId),
            schema,
            keccak256(statement),
            "urn:original-personhood-floor-statement"
        );
        T.Authorization memory a = _authorization(true);
        a.signature = _signature(ingress.attestationDigest(p, a));
        uint256 count = Native(suite.owners[4]).artistNativeReceiptCount();
        uint256 safeNonce = artist.nonce();
        require(
            this.executeTargetSafe(
                address(ingress),
                abi.encodeCall(IStreamArtistOnboarding.recordArtistAttestation, (p, a, statement))
            ),
            "original threshold Safe executes signed native personhood op24"
        );
        require(artist.nonce() == safeNonce + 1, "one genuine Safe operation");
        record = _nativePersonhoodSelection().nativeRecord.recordHash;
        require(
            record
                == keccak256(
                    abi.encode(
                        keccak256("6529STREAM_ARTIST_ATTESTATION_RECORD_V1"),
                        block.chainid,
                        address(ingress),
                        address(core),
                        uint256(1),
                        uint8(10),
                        artistId,
                        p.subjectStateHash,
                        schema,
                        p.statementHash,
                        keccak256(bytes(p.statementURI)),
                        artistId,
                        address(artist),
                        uint8(1),
                        a.nonce,
                        a.time
                    )
                ),
            "independent original native op24 record preimage"
        );
        T.AttestationRecord memory saved =
            IStreamArtistAttributionOwner(suite.owners[4]).attestationRecord(record);
        require(
            saved.recordHash == record && saved.subjectStateHash == p.subjectStateHash
                && saved.schemaId == schema && saved.statementHash == keccak256(statement)
                && saved.signer == address(artist) && saved.generation != 0
                && keccak256(
                    IStreamArtistAttributionOwner(suite.owners[4])
                        .statementBytes(saved.statementHash)
                ) == keccak256(statement)
                && keccak256(IStreamArtistIdentityOwner(suite.owners[2]).signatureBundle(record))
                == keccak256(a.signature),
            "original owner record, complete statement and threshold signature retained"
        );
        HT.Receipt memory receipt = Native(suite.owners[4]).artistNativeReceiptAt(count);
        require(
            Native(suite.owners[4]).artistNativeReceiptCount() == count + 1
                && receipt.operation == 24 && receipt.artistId == artistId
                && receipt.collectionId == 1 && receipt.recordHash == record,
            "one actual original native receipt"
        );
        _assertPersonhoodArchive(record);
    }

    function _assertPersonhoodArchive(bytes32 record) internal view {
        bytes32 id = keccak256(
            abi.encode(
                keccak256("6529STREAM_ARTIST_ONBOARDING_OPERATION_EVIDENCE_V1"),
                block.chainid,
                address(ingress),
                address(coordinator),
                uint16(24),
                address(artist),
                record
            )
        );
        bytes memory raw = archive.artistEvidenceBytesV2(id, 1);
        (bytes32 hash,, uint32 length,) = archive.artistEvidenceMetadataV2(id, 1);
        (
            uint16 version,
            bytes32 configuration,
            uint16 operation,
            address actor,
            bytes32 saved,,,
            bytes memory payload
        ) = abi.decode(
            raw, (uint16, bytes32, uint16, address, bytes32, T.Snapshot[7], T.Snapshot[7], bytes)
        );
        require(
            hash == keccak256(raw) && length == raw.length && payload.length != 0 && version == 1
                && configuration == coordinator.configurationHash() && operation == 24
                && actor == address(artist) && saved == record,
            "exact original Archive operation receipt and complete immutable bytes"
        );
    }

    function _nativePersonhoodSelection() internal view returns (Personhood.Selection memory) {
        return IStreamArtistPersonhoodEvidence(suite.owners[4]).personhoodEvidence(1, artistId);
    }

    function _assertCollectionFloor(bytes32 expected) internal view {
        StreamConservationFloorTypes.CollectionFacts memory diagnostic =
            personhoodProvider.currentCollectionRecords(1);
        require(
            !diagnostic.platformWorks && diagnostic.artistId == artistId
                && diagnostic.identityRecordHash == registrationIdentity
                && diagnostic.intentWaiverRecordHash == intentWaiverRecord
                && diagnostic.intentRecordHash == 0 && diagnostic.interviewEvidenceHash != 0
                && diagnostic.rightsRecordHash == rightsRecord
                && diagnostic.personhoodEvidenceHash == 0,
            "actual original collection facts remain separate from personhood diagnostic"
        );
        StreamConservationFloorTypes.CollectionFacts memory lite =
            personhoodProvider.requireCollectionFloor(1, PERSONHOOD_LITE);
        StreamConservationFloorTypes.CollectionFacts memory full =
            personhoodProvider.requireCollectionFloor(1, PERSONHOOD_FULL);
        require(
            lite.personhoodEvidenceHash == expected && expected != 0,
            "exact personhood evidence hash"
        );
        require(
            keccak256(abi.encode(lite)) == keccak256(abi.encode(full)),
            "both collection-floor tiers"
        );
        lite.personhoodEvidenceHash = 0;
        require(
            keccak256(abi.encode(lite)) == keccak256(abi.encode(diagnostic)),
            "other original facts unchanged"
        );
    }

    function _expectPersonhoodUnavailable() internal {
        bytes memory reason = abi.encodeWithSelector(
            StreamNativeConservationFloorProvider.NativePersonhoodVerificationUnavailable.selector,
            uint256(1),
            artistId,
            registrationIdentity
        );
        vm.expectRevert(reason);
        personhoodProvider.requireCollectionFloor(1, PERSONHOOD_LITE);
        vm.expectRevert(reason);
        personhoodProvider.requireCollectionFloor(1, PERSONHOOD_FULL);
    }
}

/// @notice Source-only regressions; native Artist code-size and runtime acceptance are pending.
contract StreamArtistConservationPersonhoodTest is ArtistConservationPersonhoodFixture {
    function testActualPersonhoodWaiverOp24SatisfiesBothCollectionFloors() public {
        _preparePersonhoodProvider();
        require(
            _nativePersonhoodSelection().status == Personhood.Status.NONE, "no preseeded personhood"
        );
        _expectPersonhoodUnavailable();
        bytes32 record = _recordNativePersonhood(
            bytes("I explicitly waive recorded personhood evidence for this collection."),
            PersonhoodDefinitions.WAIVER_SCHEMA
        );
        Personhood.Selection memory selected = _nativePersonhoodSelection();
        require(
            selected.status == Personhood.Status.WAIVER && selected.identityCurrent
                && !selected.notarizationCurrent && selected.notarizationHead == 0
                && selected.nativeRecord.recordHash == record
                && IStreamArtistPersonhoodEvidence(suite.owners[4])
                    .personhoodProofSummaryHash(record) == 0,
            "actual explicit waiver has no documentary proof summary"
        );
        _assertCollectionFloor(record);
    }

    function testActualOpaqueHeadSupersedesWaiverWithoutFallbackThenFreshWaiverRestores() public {
        _preparePersonhoodProvider();
        bytes32 original = _recordNativePersonhood(
            bytes("First explicit personhood waiver."), PersonhoodDefinitions.WAIVER_SCHEMA
        );
        _assertCollectionFloor(original);
        bytes32 opaque = _recordNativePersonhood(
            bytes("An opaque documentary claim supplies no authenticated notarization reference."),
            PersonhoodDefinitions.EVIDENCE_SCHEMA
        );
        Personhood.Selection memory selected = _nativePersonhoodSelection();
        require(
            selected.nativeRecord.recordHash == opaque
                && selected.status == Personhood.Status.UNRESOLVED && selected.identityCurrent
                && IStreamArtistPersonhoodEvidence(suite.owners[4])
                    .personhoodProofSummaryHash(opaque) == 0,
            "original opaque record is retained but unavailable"
        );
        _expectPersonhoodUnavailable();
        bytes32 restored = _recordNativePersonhood(
            bytes("A new explicit personhood waiver after the opaque statement."),
            PersonhoodDefinitions.WAIVER_SCHEMA
        );
        require(restored != original && restored != opaque, "fresh native authorization");
        _assertCollectionFloor(restored);
        require(
            IStreamArtistAttributionOwner(suite.owners[4]).attestationRecord(original).recordHash
                    == original
                && IStreamArtistAttributionOwner(suite.owners[4])
                .attestationRecord(opaque)
                .recordHash == opaque,
            "superseded original history remains intact"
        );
    }

    function testActualIdentityRevisionStalesWaiverAndNewOp24PreservesRegistrationIdentity()
        public
    {
        _preparePersonhoodProvider();
        bytes32 original = _recordNativePersonhood(
            bytes("Explicit waiver for the original operative identity."),
            PersonhoodDefinitions.WAIVER_SCHEMA
        );
        _assertCollectionFloor(original);
        bytes memory document = bytes("Actual separately signed operative identity revision.");
        bytes32 revision = _reviseDocument(document);
        bytes32 operativeIdentity = keccak256(document);
        require(
            revision != 0 && ingress.operativeIdentityRecord(artistId) == operativeIdentity
                && operativeIdentity != registrationIdentity,
            "actual op25 changes operative identity, not original registration"
        );
        Personhood.Selection memory stale = _nativePersonhoodSelection();
        require(
            stale.status == Personhood.Status.STALE && !stale.identityCurrent
                && stale.nativeRecord.recordHash == original,
            "old selected waiver remains original and becomes stale"
        );
        _expectPersonhoodUnavailable();
        bytes32 restored = _recordNativePersonhood(
            bytes("A fresh explicit waiver for the revised operative identity."),
            PersonhoodDefinitions.WAIVER_SCHEMA
        );
        require(
            _nativePersonhoodSelection().nativeRecord.subjectStateHash == operativeIdentity
                && IStreamArtistBindingOwner(suite.owners[0]).binding(1).identityRecordHash
                    == registrationIdentity,
            "current operative personhood and original conservation registration remain distinct"
        );
        _assertCollectionFloor(restored);
    }
}
