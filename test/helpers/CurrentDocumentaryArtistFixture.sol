// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./CurrentDocumentaryMediaFixture.sol";
import {
    StreamGeneralAttestations
} from "../../smart-contracts/domains/metadata/StreamGeneralAttestations.sol";
import {
    IStreamGeneralAttestations as DocumentaryGeneral
} from "../../smart-contracts/interfaces/stream/metadata/IStreamGeneralAttestations.sol";
import {
    IStreamCollectionAttestations as DocumentarySubjects
} from "../../smart-contracts/interfaces/stream/metadata/IStreamCollectionAttestations.sol";
import {
    StreamOwnerNoticeTypes as DocumentaryNotice
} from "../../smart-contracts/interfaces/stream/metadata/StreamOwnerNoticeTypes.sol";
import {
    StreamGeneralAttestationDefinitions as DocumentaryGeneralDefinitions
} from "../../smart-contracts/domains/metadata/StreamGeneralAttestationDefinitions.sol";
import {
    IStreamArtistPersonhoodEvidence,
    StreamArtistPersonhoodTypes as DocumentaryPersonhood
} from "../../smart-contracts/interfaces/stream/artist/IStreamArtistPersonhoodEvidence.sol";
import {
    StreamArtistPersonhoodDefinitions as DocumentaryPersonhoodDefinitions
} from "../../smart-contracts/domains/artist/StreamArtistPersonhoodDefinitions.sol";
import {
    StreamArtistPersonhoodJSON
} from "../../smart-contracts/domains/artist/StreamArtistPersonhoodJSON.sol";
import {
    StreamArtistOnboardingTypes as DocumentaryArtist
} from "../../smart-contracts/interfaces/stream/artist/StreamArtistOnboardingTypes.sol";
import {
    StreamArtistAuthorizationTypes as DocumentaryAuthorization
} from "../../smart-contracts/interfaces/stream/artist/IStreamArtistAuthorizationRevocation.sol";
import {
    StreamArtistRecordPublicationTypes as DocumentaryPublication
} from "../../smart-contracts/interfaces/stream/artist/StreamArtistRecordPublicationTypes.sol";
import {
    IStreamArtistNativeReceipts,
    StreamArtistHistoryTypes
} from "../../smart-contracts/interfaces/stream/artist/IStreamArtistHistory.sol";
import {
    IStreamArtistArchiveV2
} from "../../smart-contracts/interfaces/stream/artist/IStreamArtistArchiveV2.sol";
import {
    StreamConservationFloorTypes
} from "../../smart-contracts/interfaces/stream/metadata/StreamConservationFloorTypes.sol";
import {
    StreamArtistIntentWaiverJson
} from "../../smart-contracts/domains/records/StreamArtistIntentWaiverJson.sol";
import {
    StreamRightsRecordJson
} from "../../smart-contracts/domains/records/StreamRightsRecordJson.sol";
import {
    StreamRightsRecordDefinitions
} from "../../smart-contracts/domains/records/StreamRightsRecordDefinitions.sol";
import {
    StreamRightsRecordTypes
} from "../../smart-contracts/interfaces/stream/metadata/StreamRightsRecordTypes.sol";
import {
    IStreamRightsRecordSelection
} from "../../smart-contracts/interfaces/stream/metadata/IStreamRightsRecordSelection.sol";
import {
    StreamConservationDefinitions
} from "../../smart-contracts/domains/records/StreamConservationDefinitions.sol";
import {
    StreamConservationRecordTypes
} from "../../smart-contracts/interfaces/stream/metadata/StreamConservationRecordTypes.sol";
import {
    IStreamConservationRecordSelection
} from "../../smart-contracts/interfaces/stream/metadata/IStreamConservationRecordSelection.sol";
import {
    IStreamArtistBindingOwner
} from "../../smart-contracts/interfaces/stream/artist/IStreamArtistBindingOwner.sol";
import {
    IStreamArtistAttributionOwner
} from "../../smart-contracts/interfaces/stream/artist/IStreamArtistAttributionOwner.sol";
import {
    IStreamArtistIdentityOwner
} from "../../smart-contracts/interfaces/stream/artist/IStreamArtistIdentityOwner.sol";
import {
    IStreamPreservationRecords
} from "../../smart-contracts/interfaces/stream/preservation/IStreamPreservationRecords.sol";
import {
    IStreamSchemaRegistry
} from "../../smart-contracts/interfaces/stream/metadata/IStreamSchemaRegistry.sol";
import {
    IStreamGasParameterHost
} from "../../smart-contracts/interfaces/stream/parameters/IStreamGasParameterHost.sol";
import {
    StreamMetadataSubjects
} from "../../smart-contracts/domains/metadata/StreamMetadataSubjects.sol";
import {
    StreamRecordFamilies
} from "../../smart-contracts/domains/records/StreamRecordFamilies.sol";
import {
    StreamFinalityScope,
    StreamFinalityScopeType
} from "../../smart-contracts/interfaces/stream/finality/StreamArtworkFinalityTypes.sol";
import {
    StreamModuleRegistration
} from "../../smart-contracts/interfaces/stream/modules/IStreamModuleRegistry.sol";
import {
    GovernanceCall
} from "../../smart-contracts/interfaces/stream/governance/StreamGovernanceTypes.sol";
import { StreamCurrentStackPlan } from "../../script/current/StreamCurrentStackPlan.sol";

/// @notice Original Artist publications and signed documentary personhood on the actual current graph.
/// @dev The Artist is the fixture's original EOA; the real threshold Governor Safe relays its
/// signatures. Instrument references are synthetic fixture documents, not legal verification.
/// An Artist intent/interview waiver is documentary evidence, not the conservation WAIVED tier.
abstract contract CurrentDocumentaryArtistFixture is CurrentDocumentaryMediaFixture {
    uint256 private constant DOCUMENTARY_NOTARY_KEY = 0xD0C024;
    StreamGeneralAttestations internal documentaryNotary;
    address internal documentaryNotarySigner;
    uint256 private documentaryNotaryNonce;
    bytes32 internal documentaryCollectionSubject;
    bytes32 internal documentaryRegistrationIdentity;
    bytes32 internal documentaryRightsRecord;
    bytes32 internal documentaryIntentWaiverRecord;
    bytes32 internal documentaryIntentWaiverAuthorization;
    bytes32 internal documentaryInterviewEvidence;
    bytes32 internal documentaryFirstGeneral;
    bytes32 internal documentaryCurrentGeneral;
    bytes32 internal documentaryFirstNative;
    bytes32 internal documentaryCurrentNative;
    bytes32 internal documentaryFirstSummary;
    bytes32 internal documentaryCurrentSummary;
    bytes32 internal documentaryInitialWaiver;

    function _publishDocumentaryArtist() internal {
        require(address(documentaryNotary) == address(0), "documentary Artist publishes once");
        documentaryCollectionSubject = StreamMetadataSubjects.scopeSubject(
            block.chainid,
            address(core),
            StreamFinalityScope(StreamFinalityScopeType.COLLECTION, 1, 0, 0)
        );
        documentaryRegistrationIdentity =
        IStreamArtistBindingOwner(artistSuite.owners[0]).binding(1).identityRecordHash;
        DocumentaryPersonhood.Selection memory prior = _documentaryPersonhoodSelection();
        require(
            prior.status == DocumentaryPersonhood.Status.WAIVER && prior.identityCurrent,
            "actual onboarding's original signed waiver"
        );
        documentaryInitialWaiver = prior.nativeRecord.recordHash;
        _documentaryArtistDefinitions();
        _documentaryAdmitRecordType(
            keccak256("ARTIST_INTENT_WAIVER"), StreamRecordFamilies.ARTIST, 2
        );
        _documentaryAdmitRecordType(
            keccak256("RIGHTS_STATEMENT"), StreamRecordFamilies.RIGHTS, 1 << 7
        );
        _documentaryGrantWriter(StreamRecordFamilies.RIGHTS, address(governorSafe));
        _publishDocumentaryRights();
        _publishDocumentaryIntentWaiver();
        _deployDocumentaryNotary();
        documentaryCurrentGeneral = _notarizeDocumentaryPersonhood(0);
        documentaryFirstGeneral = documentaryCurrentGeneral;
        require(
            _documentaryPersonhoodSelection().nativeRecord.recordHash == documentaryInitialWaiver,
            "General report never selects native personhood"
        );
        _refreshDocumentaryPersonhood();
        documentaryFirstNative = documentaryCurrentNative;
        documentaryFirstSummary = documentaryCurrentSummary;
    }

    function _documentaryArtistDefinitions() private {
        string[12] memory names = [
            "STREAM_ARTIST_INTENT_V1",
            "STREAM_ARTIST_INTENT_JSON_PROFILE_V1",
            "STREAM_ARTIST_INTENT_WAIVER_V1",
            "STREAM_ARTIST_INTENT_WAIVER_JSON_PROFILE_V1",
            "STREAM_ARTIST_INTERVIEW_V1",
            "STREAM_ARTIST_INTERVIEW_JSON_PROFILE_V1",
            "STREAM_CONSERVATION_FORMAT_CATALOG_V1",
            "STREAM_CONSERVATION_FORMAT_CATALOG_JSON_PROFILE_V1",
            "STREAM_RIGHTS_V1",
            "STREAM_RIGHTS_JSON_PROFILE_V1",
            "STREAM_IDENTITY_NOTARIZATION_V1",
            "STREAM_IDENTITY_NOTARIZATION_JSON_PROFILE_V1"
        ];
        for (uint256 i; i < names.length; ++i) {
            _documentaryDocument(
                names[i],
                i % 2 == 0
                    ? IStreamSchemaRegistry.DocumentKind.SCHEMA
                    : IStreamSchemaRegistry.DocumentKind.CATALOG,
                bytes(vm.readFile(string.concat("schemas/records/", names[i], ".json")))
            );
        }
        bytes memory profileBytes = bytes(
            vm.readFile("schemas/records/STREAM_ARTIST_PERSONHOOD_REFERENCE_JSON_PROFILE_V1.json")
        );
        require(
            profileBytes.length == DocumentaryPersonhoodDefinitions.PROFILE_BYTES
                && keccak256(profileBytes) == DocumentaryPersonhoodDefinitions.PROFILE_HASH,
            "exact original personhood reference definition"
        );
        _documentaryDocument(
            "STREAM_ARTIST_PERSONHOOD_REFERENCE_JSON_PROFILE_V1",
            IStreamSchemaRegistry.DocumentKind.CATALOG,
            profileBytes
        );
    }

    function _documentaryOriginalRecord(bytes32 kind, bytes32 schema, bytes memory payload)
        private
        view
        returns (IStreamPreservationRecords.CollectionRecord memory r)
    {
        r.recordType = kind;
        r.subjectId = documentaryCollectionSubject;
        r.schemaId = schema;
        r.contentHash = IStreamPreservationRecords.HashRef(
            1, abi.encode(keccak256(payload)), keccak256("RFC8785_JCS")
        );
        r.uri = "ipfs://current-documentary-original-record";
        r.effectiveAt = uint64(block.timestamp);
    }

    function _publishDocumentaryRights() private {
        StreamRightsRecordTypes.Statement memory w;
        w.subjectId = documentaryCollectionSubject;
        w.profileHash = StreamRightsRecordDefinitions.PROFILE_HASH;
        w.licensor.kind = StreamRightsRecordTypes.LicensorKind.ACCOUNT;
        w.licensor.account = artist;
        w.startDate = 20260920;
        w.openEnd = true;
        bytes memory payload = StreamRightsRecordJson.serialize(w);
        IStreamPreservationRecords.CollectionRecord memory r = _documentaryOriginalRecord(
            keccak256("RIGHTS_STATEMENT"), StreamRightsRecordDefinitions.SCHEMA_ID, payload
        );
        documentaryRightsRecord = _documentaryRecordHash(r, address(governorSafe));
        require(
            assemblyMetadata.deriveCollectionRecordHashFor(address(governorSafe), 1, r)
                == documentaryRightsRecord,
            "independent RIGHTS record preimage"
        );
        _documentarySafeCall(
            address(assemblyMetadata),
            abi.encodeCall(assemblyMetadata.recordCollectionRecordWithPayload, (1, r, payload))
        );
        _documentarySafeCall(
            address(assemblyRights),
            abi.encodeCall(
                assemblyRights.selectCurrent,
                (1, documentaryCollectionSubject, documentaryRightsRecord, bytes32(0), uint64(0), w)
            )
        );
        IStreamRightsRecordSelection.Selection memory selected =
            assemblyRights.currentRights(1, documentaryCollectionSubject);
        require(
            selected.recordHash == documentaryRightsRecord
                && selected.selector == address(governorSafe),
            "original governed writer selects original RIGHTS"
        );
        (, bytes memory stored) = assemblyMetadata.recordPayload(documentaryRightsRecord);
        require(keccak256(stored) == keccak256(payload), "complete original RIGHTS bytes");
    }

    function _publishDocumentaryIntentWaiver() private {
        DocumentaryArtist.Binding memory b =
            IStreamArtistBindingOwner(artistSuite.owners[0]).binding(1);
        IStreamConservationRecordSelection.WaiverWitness memory w;
        w.waiver.subjectId = documentaryCollectionSubject;
        w.waiver.profileHash = StreamConservationDefinitions.WAIVER_PROFILE_HASH;
        w.waiver.artist = StreamConservationRecordTypes.ArtistClaim(
            fixtureArtistId,
            b.generation,
            b.bindingHash,
            StreamConservationRecordTypes.StatementOrigin.ARTIST_INTENT
        );
        w.waiver.waiverStatement = _documentaryStatement("ipfs://original-artist-intent-waiver");
        w.waiver.interview.status = StreamConservationRecordTypes.InterviewStatus.WAIVED;
        w.waiver.interview.waiverStatement =
            _documentaryStatement("ipfs://original-interview-waiver");
        bytes memory payload = StreamArtistIntentWaiverJson.serialize(w.waiver);
        (bytes32 payloadHash,) = assemblyStore.publishChunk(payload);
        w.original = _documentaryOriginalRecord(
            keccak256("ARTIST_INTENT_WAIVER"),
            StreamConservationDefinitions.WAIVER_SCHEMA_ID,
            payload
        );
        documentaryIntentWaiverRecord = _documentaryRecordHash(w.original, artist);
        require(
            assemblyMetadata.deriveCollectionRecordHashFor(artist, 1, w.original)
                == documentaryIntentWaiverRecord,
            "independent original Artist record preimage"
        );
        DocumentaryPublication.Publication memory pub = DocumentaryPublication.Publication(
            address(assemblyMetadata),
            artist,
            1,
            documentaryCollectionSubject,
            w.original.recordType,
            w.original.schemaId,
            keccak256("RFC8785_JCS"),
            1,
            payloadHash,
            keccak256(bytes(w.original.uri)),
            w.original.effectiveAt,
            documentaryIntentWaiverRecord
        );
        bytes memory statement = abi.encode(uint16(1), pub);
        DocumentaryArtist.Attestation memory p = DocumentaryArtist.Attestation(
            1,
            7,
            documentaryCollectionSubject,
            documentaryIntentWaiverRecord,
            keccak256("6529STREAM_ARTIST_RECORD_PUBLICATION_V1"),
            keccak256(statement),
            w.original.uri
        );
        documentaryIntentWaiverAuthorization = _documentaryAttest(p, statement);
        _documentarySafeCall(
            address(assemblyMetadata),
            abi.encodeCall(
                assemblyMetadata.recordArtistCollectionRecordWithPayload,
                (artist, uint256(1), w.original, payload, documentaryIntentWaiverAuthorization)
            )
        );
        IStreamConservationRecordSelection.Selection memory selected =
            assemblyConservation.adoptWaiver(
                1, documentaryCollectionSubject, documentaryIntentWaiverRecord, 0, 0, w
            );
        require(
            selected.association.artistId == fixtureArtistId
                && selected.association.identityRecordHash == documentaryRegistrationIdentity
                && selected.record.publication.attestationRecordHash
                    == documentaryIntentWaiverAuthorization
                && selected.record.publication.requiredCapability == 64
                && selected.interviewStatus == StreamConservationRecordTypes.InterviewStatus.WAIVED
                && assemblyMetadata.consumedArtistAuthorization(
                    documentaryIntentWaiverAuthorization
                ),
            "original Artist association and consumed op24 publication"
        );
        address[5] memory targets = [
            address(core),
            address(assemblyMetadata),
            address(assemblySchemas),
            address(assemblyStore),
            address(assemblyConservation)
        ];
        documentaryInterviewEvidence = keccak256(
            abi.encode(
                keccak256("6529STREAM_FINALITY_WAIVED_INTERVIEW_V1"),
                block.chainid,
                targets,
                StreamFinalityScope(StreamFinalityScopeType.COLLECTION, 1, 0, 0),
                documentaryCollectionSubject,
                selected,
                StreamConservationDefinitions.INTERVIEW_SCHEMA_ID,
                StreamConservationDefinitions.INTERVIEW_PROFILE_HASH
            )
        );
        (, bytes memory stored) = assemblyMetadata.recordPayload(documentaryIntentWaiverRecord);
        require(keccak256(stored) == keccak256(payload), "complete original intent waiver bytes");
    }

    function _documentaryStatement(string memory uri)
        private
        pure
        returns (StreamConservationRecordTypes.Reference memory)
    {
        return StreamConservationRecordTypes.Reference(
            1, keccak256("RAW_BYTES"), abi.encode(keccak256(bytes(uri))), uri
        );
    }

    function _documentaryRecordHash(
        IStreamPreservationRecords.CollectionRecord memory r,
        address recorder
    ) private view returns (bytes32) {
        bytes32[14] memory words;
        words[0] = keccak256("6529stream.preservation-record.v2");
        words[1] = bytes32(block.chainid);
        words[2] = bytes32(uint256(uint160(address(assemblyMetadata))));
        words[3] = bytes32(uint256(uint160(address(core))));
        words[4] = bytes32(uint256(uint160(recorder)));
        words[5] = bytes32(uint256(1));
        words[6] = r.recordType;
        words[7] = r.subjectId;
        words[8] = keccak256(
            abi.encode(
                r.contentHash.algorithm,
                keccak256(r.contentHash.digest),
                r.contentHash.canonicalizationId
            )
        );
        words[9] = keccak256(bytes(r.uri));
        words[10] = r.schemaId;
        words[11] = r.signatureScheme;
        words[12] = keccak256(
            abi.encode(
                r.signatureHash.algorithm,
                keccak256(r.signatureHash.digest),
                r.signatureHash.canonicalizationId
            )
        );
        words[13] = bytes32(uint256(r.effectiveAt));
        return keccak256(abi.encode(words));
    }

    function _deployDocumentaryNotary() private {
        documentaryNotarySigner = vm.addr(DOCUMENTARY_NOTARY_KEY);
        StreamGeneralAttestations.Configuration memory c;
        c.core = address(core);
        c.schemas = address(assemblySchemas);
        c.metadata = address(assemblyMetadata);
        c.artistRegistry = address(artists);
        c.artistAttribution = artistSuite.owners[4];
        c.executor = address(executor);
        c.deploymentManifestHash = keccak256("current documentary General deployment");
        c.manifestHash = keccak256("current documentary General manifest");
        c.manifestURI = "urn:current:documentary-general";
        c.signatureGas = IStreamGasParameterHost.GasParameterConfig(
            "METADATA_ERC1271_VERIFY_GAS", 150000, 90000, 2
        );
        c.dependencyReadGas = IStreamGasParameterHost.GasParameterConfig(
            "METADATA_DEPENDENCY_READ_GAS", 2000000, 50000, 2
        );
        documentaryNotary = StreamGeneralAttestations(
            _artistArtifactCreate(
                "smart-contracts/domains/metadata/StreamGeneralAttestations.sol:StreamGeneralAttestations",
                abi.encode(c)
            )
        );
        _assertDeployableProductionInstance(address(documentaryNotary));
        StreamModuleRegistration[] memory records = new StreamModuleRegistration[](1);
        records[0] = StreamModuleRegistration(
            address(documentaryNotary),
            keccak256("GENERAL_ATTESTATIONS"),
            keccak256("6529stream.general-attestations.v2"),
            type(DocumentaryGeneral).interfaceId,
            0,
            address(documentaryNotary).codehash,
            c.deploymentManifestHash,
            c.manifestHash,
            c.manifestURI
        );
        (GovernanceCall[] memory calls, bytes[] memory data) =
            StreamCurrentStackPlan.registrationCalls(registry, records);
        _documentaryGovern(
            calls[0].target,
            data[0],
            calls[0].scopeHash,
            calls[0].oldValueHash,
            calls[0].newValueHash
        );
    }

    function _notarizeDocumentaryPersonhood(bytes32 supersedes) private returns (bytes32 hash) {
        DocumentarySubjects.Subject memory subject =
            DocumentarySubjects.Subject(DocumentarySubjects.SubjectKind.COLLECTION, 1, 0, 0);
        DocumentaryGeneral.Notarization memory n;
        n.artistId = fixtureArtistId;
        n.operativeIdentityRecordHash = artists.operativeIdentityRecord(fixtureArtistId);
        // Genuine signed references to synthetic documents; the protocol does not verify legal truth.
        DocumentaryNotice.Reference memory ref = DocumentaryNotice.Reference(
            2,
            keccak256("RAW_BYTES"),
            abi.encode(keccak256("synthetic documentary instrument")),
            "ipfs://documentary-instrument"
        );
        n.legalPersonRef = ref;
        n.instrumentRef = ref;
        n.officiatingAuthorityIdentityRef = ref;
        n.verifyingInstitutionIdentityRef = ref;
        DocumentaryGeneral.Request memory r;
        r.attester = documentaryNotarySigner;
        r.collectionId = 1;
        r.subjectId = documentaryNotary.deriveSubject(subject);
        r.attestationType = keccak256("INSTITUTIONAL_VERIFICATION");
        r.attesterDID = "did:example:current-documentary-fixture";
        r.schemaId = DocumentaryGeneralDefinitions.SCHEMA_ID;
        r.canonicalizationId = keccak256("RFC8785_JCS");
        r.statementURI = "urn:documentary:instrument";
        r.payload = documentaryNotary.notarizationPayload(n);
        r.supersedes = supersedes;
        r.effectiveAt = uint64(block.timestamp);
        r.nonce = ++documentaryNotaryNonce;
        r.deadline = uint64(block.timestamp + 1 days);
        bytes32 digest = documentaryNotary.attestationDigest(r);
        (uint8 v, bytes32 r_, bytes32 s_) = vm.sign(DOCUMENTARY_NOTARY_KEY, digest);
        bytes memory signature = abi.encodePacked(r_, s_, v);
        hash = documentaryNotary.recordIdentityNotarization(subject, r, n, signature);
        (DocumentaryGeneral.Attestation memory a, DocumentaryGeneral.Receipt memory receipt) =
            documentaryNotary.attestation(hash);
        require(
            receipt.recorder == r.attester && receipt.authorizationDigest == digest
                && receipt.signatureScheme == keccak256("EIP712")
                && receipt.verificationClass == DocumentaryGeneral.VerificationClass.SIGNER_VERIFIED
                && receipt.authorityQualification
                    == DocumentaryGeneral.AuthorityQualification.GENERAL_SIGNER_CLAIM
                && receipt.artistId == fixtureArtistId
                && receipt.operativeIdentityRecordHash == n.operativeIdentityRecordHash
                && a.supersedes == supersedes,
            "original signed General receipt and subject"
        );
        DocumentaryGeneral.Receipt memory original =
            abi.decode(abi.encode(receipt), (DocumentaryGeneral.Receipt));
        original.recordIndex = 0;
        original.recordChainHash = 0;
        require(
            hash
                == keccak256(
                    abi.encode(
                        keccak256("6529STREAM_GENERAL_ATTESTATION_RECORD_V1"),
                        block.chainid,
                        address(documentaryNotary),
                        a,
                        original
                    )
                ),
            "independent original General record hash"
        );
        require(
            documentaryNotary.latestAttestationHashFor(
                        1, r.attestationType, r.subjectId, r.attester
                    ) == hash && documentaryNotary.isAttesterNonceUsed(r.attester, r.nonce),
            "original recorder head and consumed nonce"
        );
        (address payloadPointer, bytes memory stored) = documentaryNotary.recordPayload(hash);
        require(
            payloadPointer.code.length != 0 && keccak256(stored) == keccak256(r.payload),
            "complete original General payload"
        );
        (address signaturePointer, bytes memory bundle) =
            documentaryNotary.recordSignatureBundle(hash);
        (bytes32 domain, bytes32[15] memory words, bytes memory retainedSignature) =
            abi.decode(bundle, (bytes32, bytes32[15], bytes));
        require(
            signaturePointer.code.length != 0 && keccak256(bundle) == receipt.signatureBundleHash
                && keccak256(bundle) == keccak256(abi.encode(domain, words, retainedSignature))
                && keccak256(retainedSignature) == keccak256(signature),
            "complete original General signature bundle"
        );
    }

    /// @dev Always appends one General successor. Optional refresh selects it with one new op24.
    function _supersedeDocumentaryPersonhood(bool refreshNative) internal {
        bytes32 oldGeneral = documentaryCurrentGeneral;
        bytes32 oldNative = documentaryCurrentNative;
        bytes32 oldSummary = documentaryCurrentSummary;
        bytes32 previouslySelectedGeneral =
            _documentaryPersonhoodSelection().evidenceReference.notarizationRecordHash;
        documentaryCurrentGeneral = _notarizeDocumentaryPersonhood(oldGeneral);
        DocumentaryPersonhood.Selection memory stale = _documentaryPersonhoodSelection();
        require(
            stale.status == DocumentaryPersonhood.Status.STALE && stale.identityCurrent
                && !stale.notarizationCurrent && stale.nativeRecord.recordHash == oldNative
                && stale.evidenceReference.notarizationRecordHash == previouslySelectedGeneral
                && stale.notarizationHead == documentaryCurrentGeneral,
            "new General head stales but never silently replaces native selection"
        );
        require(
            IStreamArtistPersonhoodEvidence(artistSuite.owners[4])
                .personhoodProofSummaryHash(oldNative) == oldSummary,
            "historical native proof remains exact"
        );
        if (refreshNative) _refreshDocumentaryPersonhood();
    }

    /// @dev Selects the retained current General head; does not create another General record.
    function _refreshDocumentaryPersonhood() internal {
        require(documentaryCurrentGeneral != 0, "original report exists");
        DocumentaryPersonhood.Reference memory ref = DocumentaryPersonhood.Reference(
            1,
            DocumentaryPersonhoodDefinitions.PROFILE_HASH,
            address(artists),
            fixtureArtistId,
            artists.operativeIdentityRecord(fixtureArtistId),
            address(documentaryNotary),
            address(documentaryNotary).codehash,
            documentaryCurrentGeneral
        );
        bytes memory statement = StreamArtistPersonhoodJSON.encode(ref);
        DocumentaryArtist.Attestation memory p = DocumentaryArtist.Attestation(
            1,
            10,
            fixtureArtistId,
            ref.operativeIdentityRecordHash,
            DocumentaryPersonhoodDefinitions.EVIDENCE_SCHEMA,
            keccak256(statement),
            "urn:documentary:original-personhood-reference"
        );
        documentaryCurrentNative = _documentaryAttest(p, statement);
        documentaryCurrentSummary =
            _assertDocumentarySummary(documentaryCurrentNative, documentaryCurrentGeneral);
        if (documentaryFirstNative != 0) {
            require(
                IStreamArtistPersonhoodEvidence(artistSuite.owners[4])
                    .personhoodProofSummaryHash(documentaryFirstNative) == documentaryFirstSummary,
                "first original summary survives native refresh"
            );
        }
    }

    function _documentaryAttest(DocumentaryArtist.Attestation memory p, bytes memory statement)
        private
        returns (bytes32 record)
    {
        DocumentaryArtist.Authorization memory a = _artistAuthorization(true);
        bytes32 digest = artists.attestationDigest(p, a);
        DocumentaryAuthorization.State memory prior =
            artists.artistAuthorizationState(fixtureArtistId, digest, a.nonce);
        require(
            !prior.digestObserved && !prior.digestRevoked && !prior.nonceConsumed
                && !prior.nonceRevoked && prior.nextUnusedNonce == a.nonce,
            "fresh original Artist digest and principal nonce"
        );
        a.signature = _artistProof(digest);
        record = keccak256(
            abi.encode(
                keccak256("6529STREAM_ARTIST_ATTESTATION_RECORD_V1"),
                block.chainid,
                address(artists),
                address(core),
                p.collectionId,
                p.subjectKind,
                p.subjectId,
                p.subjectStateHash,
                p.schemaId,
                p.statementHash,
                keccak256(bytes(p.statementURI)),
                fixtureArtistId,
                artist,
                uint8(1),
                a.nonce,
                a.time
            )
        );
        IStreamArtistNativeReceipts receipts = IStreamArtistNativeReceipts(artistSuite.owners[4]);
        uint256 count = receipts.artistNativeReceiptCount();
        uint256 safeNonce = governorSafe.nonce();
        _documentarySafeCall(
            address(artists), abi.encodeCall(artists.recordArtistAttestation, (p, a, statement))
        );
        DocumentaryAuthorization.State memory consumed =
            artists.artistAuthorizationState(fixtureArtistId, digest, a.nonce);
        require(
            consumed.digestObserved && consumed.nonceConsumed && !consumed.digestRevoked
                && !consumed.nonceRevoked,
            "original Artist authorization remains consumed"
        );
        DocumentaryArtist.AttestationRecord memory saved =
            IStreamArtistAttributionOwner(artistSuite.owners[4]).attestationRecord(record);
        require(
            saved.recordHash == record && saved.subjectStateHash == p.subjectStateHash
                && saved.schemaId == p.schemaId && saved.statementHash == keccak256(statement)
                && saved.signer == artist && saved.generation != 0
                && keccak256(
                    IStreamArtistAttributionOwner(artistSuite.owners[4])
                        .statementBytes(saved.statementHash)
                ) == keccak256(statement)
                && keccak256(
                    IStreamArtistIdentityOwner(artistSuite.owners[2]).signatureBundle(record)
                ) == keccak256(a.signature),
            "original EOA signature, statement and owner record retained"
        );
        StreamArtistHistoryTypes.Receipt memory receipt = receipts.artistNativeReceiptAt(count);
        require(
            governorSafe.nonce() == safeNonce + 1
                && receipts.artistNativeReceiptCount() == count + 1 && receipt.operation == 24
                && receipt.artistId == fixtureArtistId && receipt.collectionId == 1
                && receipt.recordHash == record,
            "one original op24 via actual threshold Safe"
        );
        _assertDocumentaryArchive(record);
    }

    function _assertDocumentaryArchive(bytes32 record) private view {
        bytes32 id = keccak256(
            abi.encode(
                keccak256("6529STREAM_ARTIST_ONBOARDING_OPERATION_EVIDENCE_V1"),
                block.chainid,
                address(artists),
                address(artistCoordinator),
                uint16(24),
                address(governorSafe),
                record
            )
        );
        IStreamArtistArchiveV2 archive = IStreamArtistArchiveV2(artistSuite.archive);
        bytes memory evidence = archive.artistEvidenceBytesV2(id, 1);
        (bytes32 hash, address pointer, uint32 size,) = archive.artistEvidenceMetadataV2(id, 1);
        require(
            hash == keccak256(evidence) && size == evidence.length && pointer.code.length != 0,
            "actual immutable Archive operation bytes"
        );
        (
            uint16 version,
            bytes32 config,
            uint16 op,
            address actor,
            bytes32 saved,
            DocumentaryArtist.Snapshot[7] memory before_,
            DocumentaryArtist.Snapshot[7] memory after_,
            bytes memory payload
        ) = abi.decode(
            evidence,
            (
                uint16,
                bytes32,
                uint16,
                address,
                bytes32,
                DocumentaryArtist.Snapshot[7],
                DocumentaryArtist.Snapshot[7],
                bytes
            )
        );
        require(
            version == 1 && config == artistCoordinator.configurationHash() && op == 24
                && actor == address(governorSafe) && saved == record && payload.length != 0
                && keccak256(abi.encode(before_)) != keccak256(abi.encode(after_)),
            "original op24 Archive scope and owner transition"
        );
    }

    function _documentaryPersonhoodSelection()
        internal
        view
        returns (DocumentaryPersonhood.Selection memory)
    {
        return IStreamArtistPersonhoodEvidence(artistSuite.owners[4])
            .personhoodEvidence(1, fixtureArtistId);
    }

    function _assertDocumentarySummary(bytes32 nativeRecord, bytes32 generalRecord)
        private
        view
        returns (bytes32 expected)
    {
        DocumentaryPersonhood.Selection memory selected = _documentaryPersonhoodSelection();
        require(
            selected.status == DocumentaryPersonhood.Status.RESOLVED && selected.identityCurrent
                && selected.notarizationCurrent && selected.nativeRecord.recordHash == nativeRecord
                && selected.nativeRecord.schemaId
                    == DocumentaryPersonhoodDefinitions.EVIDENCE_SCHEMA
                && selected.evidenceReference.notarizationRecordHash == generalRecord
                && selected.notarizationHead == generalRecord
                && selected.sourceRegistry == address(artists),
            "actual current native personhood selection"
        );
        IStreamArtistPersonhoodEvidence owner =
            IStreamArtistPersonhoodEvidence(artistSuite.owners[4]);
        DocumentaryPersonhood.Summary memory summary = owner.personhoodProofSummary(nativeRecord);
        require(
            abi.encode(summary).length == 1536 && summary.version == 1
                && summary.chainId == block.chainid && summary.nativeRecordHash == nativeRecord
                && summary.statementHash == selected.nativeRecord.statementHash
                && summary.artistId == fixtureArtistId && summary.collectionId == 1
                && summary.generation == selected.nativeRecord.generation
                && summary.identityRecordHash == artists.operativeIdentityRecord(fixtureArtistId)
                && keccak256(abi.encode(summary.evidenceReference))
                    == keccak256(abi.encode(selected.evidenceReference)),
            "complete original summary and current operative identity"
        );
        require(
            summary.notarizationCollectionId == 1 && summary.recorder == documentaryNotarySigner
                && summary.attestationType == keccak256("INSTITUTIONAL_VERIFICATION")
                && selected.notarizationType == summary.attestationType,
            "original collection and recorder qualification"
        );
        require(
            summary.core == address(core) && summary.coreCodeHash == address(core).codehash
                && summary.originalRegistryCodeHash == address(artists).codehash
                && summary.moduleRegistry == address(registry)
                && summary.moduleRegistryCodeHash == address(registry).codehash
                && summary.schemaRegistry == address(assemblySchemas)
                && summary.schemaRegistryCodeHash == address(assemblySchemas).codehash
                && summary.chunkStore == address(assemblyStore)
                && summary.chunkStoreCodeHash == address(assemblyStore).codehash,
            "actual current graph dependency pins"
        );
        for (uint256 i; i < 6; ++i) {
            require(
                summary.carriers[i].code.length != 0
                    && summary.carriers[i].codehash == summary.carrierCodeHashes[i],
                "retained documentary carrier pins"
            );
        }
        expected = keccak256(
            abi.encode(keccak256("6529STREAM_ARTIST_PERSONHOOD_PROOF_SUMMARY_V1"), summary)
        );
        require(
            expected != 0 && expected != nativeRecord
                && owner.personhoodProofSummaryHash(nativeRecord) == expected,
            "independent original summary hash"
        );
    }

    /// @dev Expected collection evidence comes from retained original producer records, never provider reads.
    function _expectedDocumentaryCollectionFacts()
        internal
        view
        returns (StreamConservationFloorTypes.CollectionFacts memory f)
    {
        f.artistId = fixtureArtistId;
        f.identityRecordHash = documentaryRegistrationIdentity;
        f.intentWaiverRecordHash = documentaryIntentWaiverRecord;
        f.interviewEvidenceHash = documentaryInterviewEvidence;
        f.rightsRecordHash = documentaryRightsRecord;
        f.personhoodEvidenceHash = documentaryCurrentSummary;
    }
}
