// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    IStreamArtistReconstruction
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistReconstruction.sol";
import "./ArtistPublicationHydrationFixture.sol";
import {
    StreamGeneralAttestations
} from "../../../smart-contracts/domains/metadata/StreamGeneralAttestations.sol";
import {
    IStreamGeneralAttestations as General
} from "../../../smart-contracts/interfaces/stream/metadata/IStreamGeneralAttestations.sol";
import {
    IStreamCollectionAttestations as Subjects
} from "../../../smart-contracts/interfaces/stream/metadata/IStreamCollectionAttestations.sol";
import {
    StreamOwnerNoticeTypes as Notice
} from "../../../smart-contracts/interfaces/stream/metadata/StreamOwnerNoticeTypes.sol";
import {
    IStreamSchemaDocumentFacts
} from "../../../smart-contracts/interfaces/stream/metadata/IStreamSchemaDocumentFacts.sol";
import {
    StreamSchemaRegistry
} from "../../../smart-contracts/domains/metadata/StreamSchemaRegistry.sol";
import {
    StreamSchemaDocumentStore
} from "../../../smart-contracts/domains/metadata/StreamSchemaDocumentStore.sol";
import {
    StreamGeneralAttestationDefinitions as GeneralDefinitions
} from "../../../smart-contracts/domains/metadata/StreamGeneralAttestationDefinitions.sol";
import {
    IStreamArtistPersonhoodEvidence as PersonhoodRead,
    IStreamArtistPersonhoodReadFrame,
    StreamArtistPersonhoodTypes as Personhood
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistPersonhoodEvidence.sol";
import {
    StreamArtistPersonhoodJSON as PersonhoodJSON
} from "../../../smart-contracts/domains/artist/StreamArtistPersonhoodJSON.sol";
import {
    StreamArtistPersonhoodDefinitions as PersonhoodDefinitions
} from "../../../smart-contracts/domains/artist/StreamArtistPersonhoodDefinitions.sol";
import {
    StreamArtistC2PATypes as CredentialTypes,
    IStreamArtistC2PAReads
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistC2PA.sol";

interface PersonhoodRetentionVm {
    function expectCall(address callee, bytes calldata data, uint64 count) external;
}

/// @dev Only governance context is typed. Schema registry and Store are original implementations.
contract PersonhoodDocumentFixture {
    address public immutable root = msg.sender;
    StreamSchemaRegistry public schemas;
    StreamSchemaDocumentStore public store;
    bool private active;
    bytes32 private scope;
    bytes32 private oldState;
    bytes32 private nextState;
    uint256 private sequence;

    function deploy() external {
        require(msg.sender == root && address(schemas) == address(0), "fixture deploy once");
        schemas = new StreamSchemaRegistry(address(this));
        store = StreamSchemaDocumentStore(schemas.chunkStore());
        _register(
            "RAW_BYTES",
            IStreamSchemaRegistry.DocumentKind.CANONICALIZATION,
            bytes(schemas.RAW_BYTES_DEFINITION())
        );
    }

    function isStreamGovernedParameterAuthority() external pure returns (bool) {
        return true;
    }

    function governanceRootState() external view returns (address, bytes32, uint64) {
        return (root, root.codehash, 1);
    }

    function currentAction()
        external
        view
        returns (bool, bytes32, uint8, bytes32, bytes32, bytes32)
    {
        return (
            active,
            active ? keccak256(abi.encode(address(this), sequence)) : bytes32(0),
            active ? 1 : 0,
            scope,
            oldState,
            nextState
        );
    }

    function register(
        string calldata name,
        IStreamSchemaRegistry.DocumentKind kind,
        bytes calldata raw
    ) external {
        require(msg.sender == root, "fixture controller");
        _register(name, kind, raw);
    }

    function _register(
        string memory name,
        IStreamSchemaRegistry.DocumentKind kind,
        bytes memory raw
    ) private {
        (bytes32 hash,) = store.publishChunk(raw);
        bytes32[] memory chunks = new bytes32[](1);
        chunks[0] = hash;
        IStreamSchemaRegistry.DocumentSpec memory spec = IStreamSchemaRegistry.DocumentSpec(
            name, kind, hash, keccak256("RAW_BYTES"), 0, "", uint32(raw.length)
        );
        (scope, oldState, nextState) = schemas.registrationTransition(spec, chunks);
        active = true;
        ++sequence;
        schemas.registerDocument(spec, chunks);
        active = false;
        scope = 0;
        oldState = 0;
        nextState = 0;
    }
}

/// @notice Authored only: actual Artist/Safe/seven owners/Archive/General/Schema/Store.
/// @dev Core, Metadata router, governance and negative fault injections are explicit typed boundaries.
/// No current-stack, capacity, legal-person or cryptographic-instrument validation claim.
contract StreamArtistPersonhoodEvidenceTest is ArtistPublicationHydrationFixture {
    uint256 private constant NOTARY_KEY = 0x123451;
    PersonhoodDocumentFixture private documents;
    StreamGeneralAttestations private notary;
    uint256 private notaryNonce;

    function _start(bool referenceProfile) private {
        actualSaleRegistryFixture = true;
        setUp();
        _readinessHistory();
        documents = new PersonhoodDocumentFixture();
        documents.deploy();
        documents.register(
            "STREAM_IDENTITY_NOTARIZATION_V1",
            IStreamSchemaRegistry.DocumentKind.SCHEMA,
            bytes(vm.readFile("schemas/records/STREAM_IDENTITY_NOTARIZATION_V1.json"))
        );
        documents.register(
            "STREAM_IDENTITY_NOTARIZATION_JSON_PROFILE_V1",
            IStreamSchemaRegistry.DocumentKind.CATALOG,
            bytes(vm.readFile("schemas/records/STREAM_IDENTITY_NOTARIZATION_JSON_PROFILE_V1.json"))
        );
        documents.register(
            "RFC8785_JCS",
            IStreamSchemaRegistry.DocumentKind.CANONICALIZATION,
            bytes(vm.readFile("schemas/museum/account-profile/RFC8785_JCS.json"))
        );
        if (referenceProfile) _registerReferenceProfile();
        StreamGeneralAttestations.Configuration memory c;
        c.core = address(core);
        c.schemas = address(documents.schemas());
        c.metadata = address(metadata);
        c.artistRegistry = address(ingress);
        c.artistAttribution = suite.owners[4];
        c.executor = address(documents);
        c.deploymentManifestHash = keccak256("personhood fixture deployment");
        c.manifestURI = "urn:personhood:fixture";
        c.manifestHash = keccak256("personhood fixture manifest");
        c.signatureGas = IStreamGasParameterHost.GasParameterConfig(
            "METADATA_ERC1271_VERIFY_GAS", 150000, 90000, 2
        );
        c.dependencyReadGas = IStreamGasParameterHost.GasParameterConfig(
            "METADATA_DEPENDENCY_READ_GAS", 2000000, 50000, 2
        );
        notary = StreamGeneralAttestations(
            _artistArtifactCreate(
                "smart-contracts/domains/metadata/StreamGeneralAttestations.sol:StreamGeneralAttestations",
                abi.encode(c)
            )
        );
        _registerNotary();
    }

    function _registerReferenceProfile() private {
        bytes memory raw = bytes(
            vm.readFile("schemas/records/STREAM_ARTIST_PERSONHOOD_REFERENCE_JSON_PROFILE_V1.json")
        );
        require(
            raw.length == PersonhoodDefinitions.PROFILE_BYTES
                && keccak256(raw) == PersonhoodDefinitions.PROFILE_HASH,
            "exact pinned profile bytes"
        );
        documents.register(
            "STREAM_ARTIST_PERSONHOOD_REFERENCE_JSON_PROFILE_V1",
            IStreamSchemaRegistry.DocumentKind.CATALOG,
            raw
        );
    }

    function _registerNotary() private {
        // Exact original ModuleRegistry class-1 registration, with the General module's actual version.
        StreamModuleRegistration memory r = StreamModuleRegistration(
            address(notary),
            keccak256("GENERAL_ATTESTATIONS"),
            keccak256("6529stream.general-attestations.v2"),
            type(General).interfaceId,
            0,
            address(notary).codehash,
            keccak256("personhood fixture deployment"),
            keccak256("personhood fixture manifest"),
            "urn:personhood:fixture"
        );
        (bytes32 chain, uint64 count) = saleModules.registrationChainHash();
        bytes32 record = keccak256(
            abi.encode(
                saleModules.STREAM_MODULE_REGISTRATION_RECORD_V1(),
                r.module,
                r.moduleType,
                r.interfaceId,
                r.moduleVersion,
                r.expectedRuntimeCodeHash,
                r.deploymentManifestHash,
                r.moduleManifestHash
            )
        );
        bytes32 next = keccak256(
            abi.encode(
                saleModules.STREAM_RECORD_CHAIN_V1(),
                block.chainid,
                address(saleModules),
                uint256(0),
                keccak256("MODULE_REGISTRATION"),
                chain,
                record,
                count
            )
        );
        bytes32 scope = keccak256(
            abi.encode(
                saleModules.STREAM_MODULE_REGISTRATION_SCOPE_V1(),
                block.chainid,
                address(saleModules),
                address(notary)
            )
        );
        StreamModuleRegistration memory empty;
        bytes32 oldState = keccak256(
            abi.encode(
                saleModules.STREAM_MODULE_REGISTRATION_STATE_V1(),
                scope,
                false,
                _registrationFacts(empty, 0, 0),
                uint256(count),
                chain,
                count,
                address(0)
            )
        );
        bytes32 nextState = keccak256(
            abi.encode(
                saleModules.STREAM_MODULE_REGISTRATION_STATE_V1(),
                scope,
                true,
                _registrationFacts(r, 1, 1),
                uint256(count) + 1,
                next,
                count + 1,
                address(notary)
            )
        );
        IArtistSaleGovernanceContext(factory.governanceAuthority())
            .executeModuleContext(
                address(saleModules),
                abi.encodeCall(saleModules.registerModule, (r)),
                1,
                scope,
                oldState,
                nextState
            );
    }

    function _registrationFacts(StreamModuleRegistration memory r, uint8 status, uint64 revision)
        private
        pure
        returns (bytes32)
    {
        return keccak256(
            abi.encode(
                status,
                r.moduleType,
                r.moduleVersion,
                r.interfaceId,
                r.moduleGasLimit,
                r.expectedRuntimeCodeHash,
                r.deploymentManifestHash,
                r.moduleManifestHash,
                keccak256(bytes(r.moduleManifestURI)),
                revision
            )
        );
    }

    function _notarize(bytes32 supersedes, bool safeIssuer, Subjects.SubjectKind kind)
        private
        returns (bytes32 hash)
    {
        Subjects.Subject memory subject = Subjects.Subject(kind, 1, 0, 0);
        if (kind == Subjects.SubjectKind.MEDIA) {
            subject.objectId = keccak256("identity evidence media");
        }
        if (kind == Subjects.SubjectKind.TOKEN) {
            subject.tokenId = 77;
            core.setTokenCollection(77, 1);
            avm.mockCall(
                address(core),
                abi.encodeWithSignature("tokenLifecycle(uint256)", 77),
                abi.encode(uint8(2))
            );
        }
        General.Notarization memory n;
        n.artistId = artistId;
        n.operativeIdentityRecordHash = ingress.operativeIdentityRecord(artistId);
        Notice.Reference memory ref = Notice.Reference(
            2,
            keccak256("RAW_BYTES"),
            abi.encode(keccak256("synthetic instrument bytes")),
            "ipfs://personhood-fixture"
        );
        n.legalPersonRef = ref;
        n.instrumentRef = ref;
        n.officiatingAuthorityIdentityRef = ref;
        n.verifyingInstitutionIdentityRef = ref;
        General.Request memory r;
        r.attester = safeIssuer ? address(artist) : vm.addr(NOTARY_KEY);
        r.collectionId = 1;
        r.subjectId = notary.deriveSubject(subject);
        r.attestationType = keccak256("INSTITUTIONAL_VERIFICATION");
        r.attesterDID = "did:example:fixture-only";
        r.schemaId = GeneralDefinitions.SCHEMA_ID;
        r.canonicalizationId = keccak256("RFC8785_JCS");
        r.statementURI = "urn:personhood:instrument";
        r.payload = notary.notarizationPayload(n);
        r.supersedes = supersedes;
        r.effectiveAt = uint64(block.timestamp);
        r.nonce = ++notaryNonce;
        r.deadline = uint64(block.timestamp + 1 days);
        bytes32 digest = notary.attestationDigest(r);
        bytes memory signature;
        if (safeIssuer) {
            signature = _signature(digest);
        } else {
            (uint8 v, bytes32 r_, bytes32 s_) = vm.sign(NOTARY_KEY, digest);
            signature = abi.encodePacked(r_, s_, v);
        }
        hash = notary.recordIdentityNotarization(subject, r, n, signature);
        (General.Attestation memory a, General.Receipt memory receipt) = notary.attestation(hash);
        require(
            receipt.recorder == r.attester && receipt.authorizationDigest == digest
                && receipt.verificationClass == General.VerificationClass.SIGNER_VERIFIED
                && receipt.authorityQualification
                    == General.AuthorityQualification.GENERAL_SIGNER_CLAIM,
            "actual original signer-qualified receipt, not legal truth"
        );
        General.Receipt memory original = abi.decode(abi.encode(receipt), (General.Receipt));
        original.recordIndex = 0;
        original.recordChainHash = 0;
        require(
            hash
                == keccak256(
                    abi.encode(
                        keccak256("6529STREAM_GENERAL_ATTESTATION_RECORD_V1"),
                        block.chainid,
                        address(notary),
                        a,
                        original
                    )
                ),
            "independent original record preimage"
        );
    }

    function _reference(bytes32 hash) private view returns (Personhood.Reference memory) {
        return Personhood.Reference(
            1,
            PersonhoodDefinitions.PROFILE_HASH,
            address(ingress),
            artistId,
            ingress.operativeIdentityRecord(artistId),
            address(notary),
            address(notary).codehash,
            hash
        );
    }

    function _terms(bytes memory statement, bytes32 schema)
        private
        view
        returns (T.Attestation memory)
    {
        return T.Attestation(
            1,
            10,
            artistId,
            ingress.operativeIdentityRecord(artistId),
            schema,
            keccak256(statement),
            "urn:personhood:native-reference"
        );
    }

    function _recordPersonhood(bytes memory statement, bytes32 schema)
        private
        returns (bytes32 record)
    {
        T.Attestation memory p = _terms(statement, schema);
        T.Authorization memory a = _authorization(true);
        bytes32 digest = ingress.attestationDigest(p, a);
        _authOrigins(digest, a.nonce);
        a.signature = _signature(digest);
        uint256 beforeCount = Native(suite.owners[4]).artistNativeReceiptCount();
        vm.recordLogs();
        _artistCall(
            abi.encodeCall(IStreamArtistOnboarding.recordArtistAttestation, (p, a, statement))
        );
        Vm.Log[] memory logs = vm.getRecordedLogs();
        record =
        IStreamArtistC2PAReads(suite.owners[4]).personhoodAttestation(1, artistId).recordHash;
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
            "unchanged independent op24 record"
        );
        uint256 events;
        for (uint256 i; i < logs.length; ++i) {
            if (
                logs[i].emitter == suite.owners[4] && logs[i].topics.length == 4
                    && logs[i].topics[0]
                        == keccak256(
                            "ArtistAttestationRecorded(uint16,uint256,uint8,address,bytes32,bytes32,bytes32,bytes32,bytes32,uint8,uint256,uint64,bytes32)"
                        )
            ) {
                require(
                    logs[i].topics[1] == bytes32(uint256(1))
                        && logs[i].topics[2] == bytes32(uint256(10))
                        && logs[i].topics[3] == bytes32(uint256(uint160(address(artist))))
                        && keccak256(logs[i].data)
                            == keccak256(
                                abi.encode(
                                    uint16(1),
                                    artistId,
                                    p.subjectStateHash,
                                    schema,
                                    p.statementHash,
                                    keccak256(bytes(p.statementURI)),
                                    uint8(1),
                                    a.nonce,
                                    a.time,
                                    record
                                )
                            ),
                    "unchanged original op24 event"
                );
                ++events;
            }
        }
        require(
            events == 1 && Native(suite.owners[4]).artistNativeReceiptCount() == beforeCount + 1,
            "one original native receipt, no new authority record"
        );
        if (PersonhoodRead(suite.owners[4]).personhoodProofSummary(record).version != 0) {
            _assertSummaryRetention(suite.owners[4], address(archive), record, logs);
        }
        originalAttestations.push(RH.AttestationInput(p, a.nonce));
        originalAttestationRecords.push(record);
        _candidate(2, "identity_authority.replay.attestation_key", keccak256(abi.encode(record)));
    }

    function _select(bytes32 hash) private returns (bytes32) {
        return _recordPersonhood(
            PersonhoodJSON.encode(_reference(hash)), PersonhoodDefinitions.EVIDENCE_SCHEMA
        );
    }

    function _selection() private view returns (Personhood.Selection memory) {
        return PersonhoodRead(suite.owners[4]).personhoodEvidence(1, artistId);
    }

    function _reject(bytes memory statement) private returns (bytes memory data) {
        T.Attestation memory p = _terms(statement, PersonhoodDefinitions.EVIDENCE_SCHEMA);
        T.Authorization memory a = _authorization(true);
        data = abi.encodeCall(IStreamArtistOnboarding.recordArtistAttestation, (p, a, statement));
        bytes32 before_ = _roots();
        uint256 nonce = artist.nonce();
        (bool ok,) =
            address(this).call(abi.encodeCall(this.executeTargetSafe, (address(ingress), data)));
        require(
            !ok && _roots() == before_ && artist.nonce() == nonce,
            "actual Safe rejects without partial original writes"
        );
    }

    function testActualNotarizationOriginalNativeConsentAndMintFloor() public {
        _start(true);
        require(!_closed(_mintCall()), "existing waiver floor control");
        bytes32 documentary = _notarize(0, false, Subjects.SubjectKind.COLLECTION);
        bytes32 native_ = _select(documentary);
        Personhood.Selection memory s = _selection();
        require(
            s.status == Personhood.Status.RESOLVED && s.identityCurrent && s.notarizationCurrent
                && s.nativeRecord.recordHash == native_
                && s.evidenceReference.notarizationRecordHash == documentary
                && s.sourceRegistry == address(ingress) && s.recorder == vm.addr(NOTARY_KEY),
            "exact native selection"
        );
        require(
            !_closed(_mintCall()), "actual original floor consumes resolved documentary evidence"
        );
    }

    function testNewRecorderHeadNeverSilentlyReplacesNativeSelection() public {
        _start(true);
        bytes32 first = _notarize(0, false, Subjects.SubjectKind.COLLECTION);
        bytes32 native_ = _select(first);
        bytes32 second = _notarize(first, false, Subjects.SubjectKind.COLLECTION);
        Personhood.Selection memory s = _selection();
        require(
            s.status == Personhood.Status.STALE
                && s.evidenceReference.notarizationRecordHash == first
                && s.notarizationHead == second && s.nativeRecord.recordHash == native_,
            "no automatic replacement"
        );
        require(_closed(_mintCall()), "stale selected evidence cannot satisfy floor");
        _reject(PersonhoodJSON.encode(_reference(first)));
        _select(second);
        require(
            _selection().status == Personhood.Status.RESOLVED && !_closed(_mintCall()),
            "fresh original op24 required"
        );
        require(
            IStreamArtistAttributionOwner(suite.owners[4]).attestationRecord(native_).recordHash
                == native_,
            "history retained"
        );
    }

    function testWaiverAndOpaqueLegacyRemainDistinct() public {
        _start(true);
        bytes memory opaque = bytes("legacy opaque documentary claim");
        bytes32 record = _recordPersonhood(opaque, PersonhoodDefinitions.EVIDENCE_SCHEMA);
        require(
            _selection().status == Personhood.Status.UNRESOLVED && _closed(_mintCall()),
            "opaque is not acquisition-grade proof"
        );
        require(
            keccak256(
                        IStreamArtistAttributionOwner(suite.owners[4])
                            .statementBytes(keccak256(opaque))
                    ) == keccak256(opaque)
                && IStreamArtistAttributionOwner(suite.owners[4])
                .attestationRecord(record)
                .recordHash == record,
            "original bytes remain"
        );
        _recordPersonhood(
            bytes("I elect to waive recorded personhood evidence"),
            PersonhoodDefinitions.WAIVER_SCHEMA
        );
        require(
            _selection().status == Personhood.Status.WAIVER && !_closed(_mintCall()),
            "explicit unchanged waiver election"
        );
    }

    function testWrongArtistIdentityOriginRuntimeAndRecordRefuseWithoutConsumingNonce() public {
        _start(true);
        bytes32 hash = _notarize(0, false, Subjects.SubjectKind.COLLECTION);
        Personhood.Reference memory p = _reference(hash);
        p.artistId = keccak256("foreign artist");
        _reject(PersonhoodJSON.encode(p));
        p = _reference(hash);
        p.operativeIdentityRecordHash = keccak256("foreign identity");
        _reject(PersonhoodJSON.encode(p));
        p = _reference(hash);
        p.artistRegistry = address(notary);
        _reject(PersonhoodJSON.encode(p));
        p = _reference(hash);
        p.notarizationRuntimeHash = keccak256("foreign code");
        _reject(PersonhoodJSON.encode(p));
        p = _reference(hash);
        p.notarizationRecordHash = keccak256("foreign record");
        _reject(PersonhoodJSON.encode(p));
        _select(hash);
        require(
            _selection().status == Personhood.Status.RESOLVED,
            "fresh valid original nonce remains usable"
        );
    }

    function testMissingReferenceDefinitionThenExactNativeSafeRetry() public {
        _start(false);
        bytes32 hash = _notarize(0, false, Subjects.SubjectKind.COLLECTION);
        bytes memory statement = PersonhoodJSON.encode(_reference(hash));
        bytes memory data = _reject(statement);
        _registerReferenceProfile();
        require(
            this.executeTargetSafe(address(ingress), data),
            "same exact original calldata and Safe nonce after definition"
        );
        require(
            _selection().status == Personhood.Status.RESOLVED, "genuine definition satisfies proof"
        );
    }

    function testHistoricalSignatureIsNotReauthorizedAgainstCurrentSafeOwners() public {
        _start(true);
        bytes32 hash = _notarize(0, true, Subjects.SubjectKind.COLLECTION);
        _select(hash);
        (, General.Receipt memory r) = notary.attestation(hash);
        require(
            r.signatureScheme == keccak256("ERC1271"), "actual original Safe issuer verification"
        );
        avm.mockCall(
            address(artist),
            abi.encodeWithSignature(
                "isValidSignature(bytes32,bytes)",
                r.authorizationDigest,
                _signature(r.authorizationDigest)
            ),
            abi.encode(bytes4(0xffffffff))
        );
        require(
            _selection().status == Personhood.Status.RESOLVED,
            "historical proof never reauthorizes old signature"
        );
    }

    function testDifferentRecorderDoesNotReplaceChosenNotarization() public {
        _start(true);
        bytes32 first = _notarize(0, false, Subjects.SubjectKind.COLLECTION);
        _select(first);
        _notarize(0, true, Subjects.SubjectKind.COLLECTION);
        Personhood.Selection memory s = _selection();
        require(
            s.status == Personhood.Status.RESOLVED && s.recorder == vm.addr(NOTARY_KEY)
                && s.evidenceReference.notarizationRecordHash == first
                && s.notarizationHead == first,
            "another issuer has no implicit selection authority"
        );
    }

    function testCredentialOnlyUpdateCannotEraseOrSupplyPersonhoodSelection() public {
        _start(true);
        bytes32 chosen = _select(_notarize(0, false, Subjects.SubjectKind.COLLECTION));
        CredentialTypes.Credential[] memory credentials = new CredentialTypes.Credential[](0);
        bytes memory statement = abi.encode(
            CredentialTypes.Payload(
                1, artistId, ingress.operativeIdentityRecord(artistId), bytes32(0), credentials
            )
        );
        T.Attestation memory p =
            _terms(statement, keccak256("6529STREAM_ARTIST_C2PA_CREDENTIALS_V1"));
        T.Authorization memory a = _authorization(true);
        a.signature = _signature(ingress.attestationDigest(p, a));
        _artistCall(
            abi.encodeCall(IStreamArtistOnboarding.recordArtistAttestation, (p, a, statement))
        );
        require(
            IStreamArtistC2PAReads(suite.owners[4]).c2paCredentialHead(artistId).recordHash != 0
                && _selection().nativeRecord.recordHash == chosen
                && _selection().status == Personhood.Status.RESOLVED && !_closed(_mintCall()),
            "credential history stays independent of original personhood floor"
        );
    }

    function testDeprecatedHistoryRemainsResolvedButCannotAdmitFreshNativeReference() public {
        _start(true);
        bytes32 hash = _notarize(0, false, Subjects.SubjectKind.COLLECTION);
        _select(hash);
        _saleStatus(
            saleModules,
            factory.governanceAuthority(),
            address(notary),
            ModuleRegistryStatus.DEPRECATED
        );
        require(
            _selection().status == Personhood.Status.RESOLVED,
            "retained immutable historical receipt"
        );
        _reject(PersonhoodJSON.encode(_reference(hash)));
    }

    function testMalformedHeadIsUnresolvedAndKnownIncidentIsStale() public {
        _start(true);
        bytes32 hash = _notarize(0, false, Subjects.SubjectKind.COLLECTION);
        _select(hash);
        (General.Attestation memory a, General.Receipt memory r) = notary.attestation(hash);
        bytes memory query = abi.encodeCall(
            notary.latestAttestationHashFor,
            (a.collectionId, a.attestationType, a.subjectId, r.recorder)
        );
        avm.mockCall(address(notary), query, hex"01");
        require(
            _selection().status == Personhood.Status.UNRESOLVED && _closed(_mintCall()),
            "malformed live source fails closed"
        );
        avm.mockCall(address(notary), query, abi.encode(hash));
        require(_selection().status == Personhood.Status.RESOLVED, "exact restored source positive");
        _saleStatus(
            saleModules,
            factory.governanceAuthority(),
            address(notary),
            ModuleRegistryStatus.INCIDENT_REVOKED
        );
        require(
            _selection().status == Personhood.Status.STALE && _closed(_mintCall()),
            "known incident invalidates prior documentary liveness"
        );
    }

    function testOriginalSubjectDomainsForCollectionAndMedia() public {
        _start(true);
        bytes32 collectionRecord = _notarize(0, false, Subjects.SubjectKind.COLLECTION);
        _select(collectionRecord);
        bytes32 mediaRecord = _notarize(0, false, Subjects.SubjectKind.MEDIA);
        Subjects.Subject memory actual = notary.recordSubject(mediaRecord);
        Subjects.Subject memory wrong = Subjects.Subject(Subjects.SubjectKind.COLLECTION, 2, 0, 0);
        avm.mockCall(
            address(notary), abi.encodeCall(notary.recordSubject, (mediaRecord)), abi.encode(wrong)
        );
        _reject(PersonhoodJSON.encode(_reference(mediaRecord)));
        avm.mockCall(
            address(notary), abi.encodeCall(notary.recordSubject, (mediaRecord)), abi.encode(actual)
        );
        bytes32 selected = _select(mediaRecord);
        require(
            _selection().status == Personhood.Status.RESOLVED, "canonical original media domain"
        );
        Personhood.Summary memory s =
            PersonhoodRead(suite.owners[4]).personhoodProofSummary(selected);
        require(
            s.subjectId
                == keccak256(
                    abi.encode(
                        bytes32(0x030f2701e9035fcb711b3acc44ec0bf14b4f4e344e231cdaadce7d14e590994b),
                        block.chainid,
                        address(core),
                        actual.collectionId,
                        actual.objectId
                    )
                ),
            "independent original media preimage"
        );
    }

    function testTypedTokenSubjectRetainsOriginalDomain() public {
        _start(true);
        // Token existence/lifecycle are explicitly typed Core facts; original General/Artist are real.
        bytes32 hash = _notarize(0, false, Subjects.SubjectKind.TOKEN);
        _select(hash);
        require(
            _selection().status == Personhood.Status.RESOLVED, "canonical original token domain"
        );
    }

    function testReadDisclosesInjectedIdentityMismatchWithoutChangingSelectedHistory() public {
        _start(true);
        bytes32 hash = _notarize(0, false, Subjects.SubjectKind.COLLECTION);
        bytes32 record = _select(hash);
        avm.mockCall(
            suite.owners[2],
            abi.encodeCall(IStreamArtistIdentityRevisionReads.operativeIdentityRecord, (artistId)),
            abi.encode(keccak256("new operative identity"))
        );
        Personhood.Selection memory s = _selection();
        require(
            s.status == Personhood.Status.STALE && !s.identityCurrent
                && s.nativeRecord.recordHash == record
                && s.evidenceReference.notarizationRecordHash == hash,
            "staleness preserves provenance"
        );
    }

    function testOriginalOriginSurvivesActualCompleteHydration() public {
        _start(true);
        bytes32 hash = _notarize(0, false, Subjects.SubjectKind.COLLECTION);
        bytes32 native_ = _select(hash);
        bytes memory original = IStreamArtistAttributionOwner(suite.owners[4])
            .statementBytes(_selection().nativeRecord.statementHash);
        Next memory n = _cutover(true, true);
        RH.Request memory p = _readyRequest();
        vm.recordLogs();
        require(
            this.executeTargetSafe(
                address(n.registry),
                abi.encodeCall(ReadyHydrate.hydrateArtistAuthorityWithReadiness, (p))
            ),
            "complete actual original op60"
        );
        Vm.Log[] memory importedLogs = vm.getRecordedLogs();
        _assertSummaryRetention(
            n.coordinator.suiteConfiguration().owners[4], address(n.archive), native_, importedLogs
        );
        address owner = n.coordinator.suiteConfiguration().owners[4];
        Personhood.Selection memory s = PersonhoodRead(owner).personhoodEvidence(1, artistId);
        require(
            s.status == Personhood.Status.RESOLVED && s.sourceRegistry == address(ingress)
                && s.evidenceReference.artistRegistry == address(ingress)
                && s.nativeRecord.recordHash == native_
                && s.evidenceReference.notarizationRecordHash == hash,
            "old native and General domains remain original"
        );
        require(
            keccak256(
                IStreamArtistAttributionOwner(owner).statementBytes(s.nativeRecord.statementHash)
            ) == keccak256(original),
            "statement bytes unchanged"
        );
        // Fresh successor op24 cannot pretend an old-domain reference was freshly recorded there.
        T.Attestation memory terms = originalAttestations[originalAttestations.length - 1].terms;
        T.Authorization memory a;
        a.nonce = IStreamArtistIdentityOwner(n.identity).identity(artistId).nonceHint;
        a.time = uint64(block.timestamp);
        bytes32 roots = _allRoots(n.coordinator);
        uint256 nonce = artist.nonce();
        (bool ok,) = address(this)
            .call(
                abi.encodeCall(
                    this.executeTargetSafe,
                    (
                        address(n.registry),
                        abi.encodeCall(
                            IStreamArtistOnboarding.recordArtistAttestation, (terms, a, original)
                        )
                    )
                )
            );
        require(
            !ok && roots == _allRoots(n.coordinator) && nonce == artist.nonce(),
            "fresh successor does not reuse old receipt as new domain"
        );
    }

    function testOmittedNativeEvidenceCannotHydrateAFalseEmptyHead() public {
        _start(true);
        _select(_notarize(0, false, Subjects.SubjectKind.COLLECTION));
        Next memory n = _cutover(true, true);
        RH.Request memory p = _readyRequest();
        RH.AttestationInput[] memory reduced = new RH.AttestationInput[](p.attestations.length - 1);
        for (uint256 i; i < reduced.length; ++i) {
            reduced[i] = p.attestations[i];
        }
        p.attestations = reduced;
        bytes32 roots = _allRoots(n.coordinator);
        (bool ok,) = address(n.registry)
            .call(abi.encodeCall(ReadyHydrate.hydrateArtistAuthorityWithReadiness, (p)));
        require(
            !ok && roots == _allRoots(n.coordinator),
            "original complete source inventory refuses omission"
        );
        _notHydrated(n);
    }

    function testLateArchiveFailureRollsBackDerivedOriginAndOriginalSafeNonce() public {
        _start(true);
        bytes32 hash = _notarize(0, false, Subjects.SubjectKind.COLLECTION);
        bytes memory statement = PersonhoodJSON.encode(_reference(hash));
        T.Authorization memory a = _authorization(true);
        T.Attestation memory p = _terms(statement, PersonhoodDefinitions.EVIDENCE_SCHEMA);
        bytes32 expected = keccak256(
            abi.encode(
                keccak256("6529STREAM_ARTIST_ATTESTATION_RECORD_V1"),
                block.chainid,
                address(ingress),
                address(core),
                uint256(1),
                uint8(10),
                artistId,
                p.subjectStateHash,
                p.schemaId,
                p.statementHash,
                keccak256(bytes(p.statementURI)),
                artistId,
                address(artist),
                uint8(1),
                a.nonce,
                a.time
            )
        );
        bytes memory data =
            abi.encodeCall(IStreamArtistOnboarding.recordArtistAttestation, (p, a, statement));
        bytes32 roots = _roots();
        bytes32 selected = _selection().nativeRecord.recordHash;
        uint256 nonce = artist.nonce();
        uint256 previous = block.number;
        vm.roll(uint256(type(uint64).max) + 1);
        (bool ok,) =
            address(this).call(abi.encodeCall(this.executeTargetSafe, (address(ingress), data)));
        require(
            !ok && roots == _roots() && nonce == artist.nonce()
                && _selection().nativeRecord.recordHash == selected
                && PersonhoodRead(suite.owners[4]).personhoodProofSummaryHash(expected) == 0
                && PersonhoodRead(suite.owners[4]).personhoodProofSummary(expected).version == 0,
            "late original Archive refusal restores selection, summary and all owners"
        );
        vm.roll(previous);
        require(
            this.executeTargetSafe(address(ingress), data), "identical Safe call and nonce retry"
        );
        require(
            _selection().status == Personhood.Status.RESOLVED && artist.nonce() == nonce + 1
                && _selection().nativeRecord.recordHash == expected
                && PersonhoodRead(suite.owners[4]).personhoodProofSummaryHash(expected) != 0,
            "one successful commit"
        );
    }

    function testSelfOnlyResolutionCannotBeCalledAsExternalEvidenceAuthority() public {
        _start(true);
        Personhood.Selection memory s = _selection();
        (bool ok, bytes memory reason) = suite.owners[4].staticcall(
            abi.encodeCall(
                IStreamArtistPersonhoodReadFrame.personhoodResolution,
                (uint256(1), artistId, s.nativeRecord, false)
            )
        );
        require(
            !ok
                && keccak256(reason)
                    == keccak256(abi.encodeWithSelector(T.Unauthorized.selector, address(this))),
            "self-only read frame"
        );
    }

    function testCanonicalJsonDefinitionAndMalformedBytesAreClosed() public {
        _start(true);
        Personhood.Reference memory p = _reference(keccak256("record"));
        bytes memory raw = PersonhoodJSON.encode(p);
        require(
            raw.length == 590
                && keccak256(abi.encode(PersonhoodJSON.decode(raw))) == keccak256(abi.encode(p)),
            "fixed canonical roundtrip"
        );
        for (uint256 i; i < raw.length; ++i) {
            bytes memory altered = abi.decode(abi.encode(raw), (bytes));
            altered[i] = bytes1(uint8(altered[i]) ^ 0x80);
            (bool valid,) = PersonhoodJSON.tryDecode(altered);
            require(!valid, "high-bit mutation cannot be canonical JSON");
        }
        (bool valid,) = PersonhoodJSON.tryDecode(bytes.concat(raw, hex"00"));
        require(!valid, "trailing bytes refuse");
    }

    function testFuzzCanonicalJsonRoundTrip(bytes32 artist_, bytes32 identity_, bytes32 record_)
        public
    {
        if (artist_ == 0 || identity_ == 0 || record_ == 0) return;
        Personhood.Reference memory p = Personhood.Reference(
            1,
            PersonhoodDefinitions.PROFILE_HASH,
            address(0x1234),
            artist_,
            identity_,
            address(0x5678),
            keccak256("code"),
            record_
        );
        require(
            keccak256(abi.encode(PersonhoodJSON.decode(PersonhoodJSON.encode(p))))
                == keccak256(abi.encode(p))
        );
    }

    function _summary(bytes32 record) private view returns (Personhood.Summary memory) {
        return PersonhoodRead(suite.owners[4]).personhoodProofSummary(record);
    }

    function testSummaryHasExactOriginalPinsAndIndependentHashAndFullAudit() public {
        _start(true);
        bytes32 documentary = _notarize(0, false, Subjects.SubjectKind.COLLECTION);
        bytes32 native_ = _select(documentary);
        Personhood.Summary memory s = _summary(native_);
        require(
            abi.encode(s).length == 1536 && s.version == 1 && s.chainId == block.chainid,
            "closed 48-word summary"
        );
        require(
            s.nativeRecordHash == native_
                && s.statementHash == _selection().nativeRecord.statementHash
                && s.artistId == artistId && s.collectionId == 1 && s.generation == 1
                && s.identityRecordHash == ingress.operativeIdentityRecord(artistId),
            "original native subject facts"
        );
        require(
            s.evidenceReference.artistRegistry == address(ingress)
                && s.originalRegistryCodeHash == address(ingress).codehash
                && s.evidenceReference.notarizationRecordHash == documentary
                && s.core == address(core) && s.coreCodeHash == address(core).codehash
                && s.moduleRegistry == address(saleModules)
                && s.moduleRegistryCodeHash == address(saleModules).codehash
                && s.schemaRegistry == address(documents.schemas())
                && s.chunkStore == address(documents.store()),
            "source pins"
        );
        bytes32 expected =
            keccak256(abi.encode(keccak256("6529STREAM_ARTIST_PERSONHOOD_PROOF_SUMMARY_V1"), s));
        require(
            PersonhoodRead(suite.owners[4]).personhoodProofSummaryHash(native_) == expected,
            "independent summary preimage"
        );
        for (uint256 i; i < 6; ++i) {
            require(
                s.carriers[i].code.length != 0 && s.carriers[i].codehash == s.carrierCodeHashes[i],
                "actual immutable carrier"
            );
        }
        (bytes32 audit, Personhood.NotarizationFacts memory f) =
            PersonhoodRead(suite.owners[4]).auditPersonhoodEvidence(native_);
        require(
            audit == s.documentaryHash && f.current && f.head == documentary,
            "full documentary reconstruction"
        );
    }

    function testBoundedCurrentReadDoesNotReplayDocumentaryPayloadOrHistoricalSignature() public {
        _start(true);
        bytes32 hash = _notarize(0, false, Subjects.SubjectKind.COLLECTION);
        bytes32 native_ = _select(hash);
        bytes32 saved = PersonhoodRead(suite.owners[4]).personhoodProofSummaryHash(native_);
        avm.mockCall(address(notary), abi.encodeCall(notary.attestation, (hash)), hex"01");
        avm.mockCall(address(notary), abi.encodeCall(notary.recordPayload, (hash)), hex"01");
        require(
            _selection().status == Personhood.Status.RESOLVED && !_closed(_mintCall()),
            "admitted immutable summary serves bounded currentness"
        );
        (bool ok,) = suite.owners[4].staticcall(
            abi.encodeCall(PersonhoodRead.auditPersonhoodEvidence, (native_))
        );
        require(
            !ok && PersonhoodRead(suite.owners[4]).personhoodProofSummaryHash(native_) == saved,
            "separate full audit exposes documentary read failure"
        );
    }

    function testAdmittedCarrierCodeDriftStalesAndRestorationDoesNotSelectNewEvidence() public {
        _start(true);
        bytes32 hash = _notarize(0, false, Subjects.SubjectKind.COLLECTION);
        bytes32 native_ = _select(hash);
        Personhood.Summary memory s = _summary(native_);
        bytes memory saved = s.carriers[0].code;
        bytes memory changed = abi.decode(abi.encode(saved), (bytes));
        changed[changed.length - 1] = bytes1(uint8(changed[changed.length - 1]) ^ 1);
        vm.etch(s.carriers[0], changed);
        require(
            _selection().status == Personhood.Status.STALE && _closed(_mintCall()),
            "carrier pin checked without copying bytes"
        );
        vm.etch(s.carriers[0], saved);
        require(
            _selection().status == Personhood.Status.RESOLVED
                && _selection().nativeRecord.recordHash == native_,
            "exact retained source restored"
        );
    }

    function testSchemaFactsAndRuntimeDriftCannotSatisfyNewFloor() public {
        _start(true);
        bytes32 hash = _notarize(0, false, Subjects.SubjectKind.COLLECTION);
        _select(hash);
        IStreamSchemaDocumentFacts.DocumentFacts memory actual = IStreamSchemaDocumentFacts(
                address(documents.schemas())
            ).documentFacts(PersonhoodDefinitions.PROFILE_ID);
        IStreamSchemaDocumentFacts.DocumentFacts memory wrong =
            abi.decode(abi.encode(actual), (IStreamSchemaDocumentFacts.DocumentFacts));
        wrong.contentHash = keccak256("different frozen profile");
        bytes memory query = abi.encodeCall(
            IStreamSchemaDocumentFacts.documentFacts, (PersonhoodDefinitions.PROFILE_ID)
        );
        avm.mockCall(address(documents.schemas()), query, abi.encode(wrong));
        require(
            _selection().status == Personhood.Status.STALE && _closed(_mintCall()),
            "definition drift"
        );
        avm.mockCall(address(documents.schemas()), query, abi.encode(actual));
        bytes memory runtime = address(notary).code;
        vm.etch(address(notary), hex"00");
        require(
            _selection().status == Personhood.Status.STALE && _closed(_mintCall()),
            "host code drift"
        );
        vm.etch(address(notary), runtime);
        require(_selection().status == Personhood.Status.RESOLVED, "exact pins restored");
    }

    function testMissingOrForeignSummaryCannotBeImportedThenExactSafeRetry() public {
        _start(true);
        bytes32 hash = _notarize(0, false, Subjects.SubjectKind.COLLECTION);
        bytes32 native_ = _select(hash);
        Personhood.Summary memory original = _summary(native_);
        bytes memory query = abi.encodeCall(PersonhoodRead.personhoodProofSummary, (native_));
        Next memory n = _cutover(true, true);
        RH.Request memory p = _readyRequest();
        bytes memory data = abi.encodeCall(ReadyHydrate.hydrateArtistAuthorityWithReadiness, (p));
        bytes32 roots = _allRoots(n.coordinator);
        uint256 nonce = artist.nonce();
        avm.mockCall(suite.owners[4], query, hex"");
        (bool ok,) =
            address(this).call(abi.encodeCall(this.executeTargetSafe, (address(n.registry), data)));
        require(
            !ok && roots == _allRoots(n.coordinator) && nonce == artist.nonce(),
            "missing proof refuses before activation"
        );
        _notHydrated(n);
        Personhood.Summary memory wrong = abi.decode(abi.encode(original), (Personhood.Summary));
        wrong.evidenceReference.artistRegistry = address(n.registry);
        avm.mockCall(suite.owners[4], query, abi.encode(wrong));
        bytes memory hashQuery =
            abi.encodeCall(PersonhoodRead.personhoodProofSummaryHash, (native_));
        avm.mockCall(
            suite.owners[4],
            hashQuery,
            abi.encode(
                keccak256(
                    abi.encode(keccak256("6529STREAM_ARTIST_PERSONHOOD_PROOF_SUMMARY_V1"), wrong)
                )
            )
        );
        (ok,) =
            address(this).call(abi.encodeCall(this.executeTargetSafe, (address(n.registry), data)));
        require(
            !ok && roots == _allRoots(n.coordinator) && nonce == artist.nonce(),
            "even rehashed foreign original domain cannot copy proof"
        );
        avm.mockCall(
            suite.owners[4],
            hashQuery,
            abi.encode(
                keccak256(
                    abi.encode(keccak256("6529STREAM_ARTIST_PERSONHOOD_PROOF_SUMMARY_V1"), original)
                )
            )
        );
        _notHydrated(n);
        wrong = abi.decode(abi.encode(original), (Personhood.Summary));
        wrong.documentaryHash = keccak256("substituted proof");
        avm.mockCall(suite.owners[4], query, abi.encode(wrong));
        (ok,) =
            address(this).call(abi.encodeCall(this.executeTargetSafe, (address(n.registry), data)));
        require(
            !ok && roots == _allRoots(n.coordinator),
            "source retained hash independently joins summary"
        );
        avm.mockCall(suite.owners[4], query, abi.encode(original));
        require(
            this.executeTargetSafe(address(n.registry), data),
            "identical operation60 and Safe nonce retry"
        );
        address nextOwner = n.coordinator.suiteConfiguration().owners[4];
        require(
            keccak256(abi.encode(PersonhoodRead(nextOwner).personhoodProofSummary(native_)))
                == keccak256(abi.encode(original)),
            "byte-exact original proof carried"
        );
    }

    function testOriginalOp24ReplayCannotReplaceValidatedSummary() public {
        _start(true);
        bytes32 hash = _notarize(0, false, Subjects.SubjectKind.COLLECTION);
        bytes memory statement = PersonhoodJSON.encode(_reference(hash));
        T.Attestation memory p = _terms(statement, PersonhoodDefinitions.EVIDENCE_SCHEMA);
        T.Authorization memory a = _authorization(true);
        a.signature = _signature(ingress.attestationDigest(p, a));
        bytes memory data =
            abi.encodeCall(IStreamArtistOnboarding.recordArtistAttestation, (p, a, statement));
        require(this.executeTargetSafe(address(ingress), data), "original valid op24");
        bytes32 selected = _selection().nativeRecord.recordHash;
        bytes32 summaryHash = PersonhoodRead(suite.owners[4]).personhoodProofSummaryHash(selected);
        bytes32 roots = _roots();
        uint256 nonce = artist.nonce();
        (bool ok,) =
            address(this).call(abi.encodeCall(this.executeTargetSafe, (address(ingress), data)));
        require(
            !ok && _roots() == roots && artist.nonce() == nonce
                && PersonhoodRead(suite.owners[4]).personhoodProofSummaryHash(selected)
                    == summaryHash,
            "original replay guard owns proof lifecycle"
        );
    }

    function testBindingAndSelectedModuleRegistryDriftRemainExplicitlyStale() public {
        _start(true);
        bytes32 hash = _notarize(0, false, Subjects.SubjectKind.COLLECTION);
        bytes32 native_ = _select(hash);
        T.Binding memory original = IStreamArtistBindingOwner(suite.owners[0]).binding(1);
        T.Binding memory wrong = abi.decode(abi.encode(original), (T.Binding));
        wrong.generation += 1;
        bytes memory bindingQuery = abi.encodeCall(IStreamArtistBindingOwner.binding, (uint256(1)));
        avm.mockCall(suite.owners[0], bindingQuery, abi.encode(wrong));
        require(
            _selection().status == Personhood.Status.STALE && !_selection().identityCurrent,
            "generation drift"
        );
        wrong = abi.decode(abi.encode(original), (T.Binding));
        wrong.bindingHash = keccak256("substituted binding same generation");
        avm.mockCall(suite.owners[0], bindingQuery, abi.encode(wrong));
        require(_selection().status == Personhood.Status.STALE, "binding hash drift");
        avm.mockCall(suite.owners[0], bindingQuery, abi.encode(original));
        bytes memory pointerQuery =
            abi.encodeWithSignature("getSatellitePointer(bytes32)", keccak256("MODULE_REGISTRY"));
        (bool read, bytes memory saved) = address(core).staticcall(pointerQuery);
        require(read && saved.length == 320, "original actual typed Core pointer");
        avm.mockCall(
            address(core),
            pointerQuery,
            abi.encode(
                address(notary),
                address(notary).codehash,
                false,
                bytes32(0),
                bytes4(0),
                address(0),
                uint8(0),
                bytes32(0),
                bytes32(0),
                uint64(0)
            )
        );
        require(
            _selection().status == Personhood.Status.STALE && _closed(_mintCall()),
            "foreign selected module registry"
        );
        avm.mockCall(address(core), pointerQuery, saved);
        require(
            _selection().status == Personhood.Status.RESOLVED
                && _selection().nativeRecord.recordHash == native_,
            "restoration does not select a new documentary record"
        );
    }

    function _summaryCarrier(address catalog, bytes32 hash, bytes memory expected)
        private
        view
        returns (address pointer)
    {
        uint256 found;
        uint256 count = IStreamArtistReconstruction(catalog).storedPayloadCount();
        for (uint256 i; i < count; ++i) {
            (address p, bytes32 kind, bytes32 contentHash) =
                IStreamArtistReconstruction(catalog).storedPayloadAt(i);
            if (kind != keccak256("ARTIST_PERSONHOOD_PROOF_SUMMARY") || contentHash != hash) {
                continue;
            }
            ++found;
            pointer = p;
            require(
                p.code.length == expected.length + 1
                    && p.codehash == keccak256(bytes.concat(hex"00", expected)),
                "exact original STOP-prefixed summary carrier bytes"
            );
        }
        require(found == 1 && pointer != address(0), "one exact typed summary catalog row");
    }

    function _assertSummaryRetention(
        address owner,
        address archive_,
        bytes32 native_,
        Vm.Log[] memory logs
    ) private view {
        Personhood.Summary memory summary = PersonhoodRead(owner).personhoodProofSummary(native_);
        bytes memory expected =
            abi.encode(keccak256("6529STREAM_ARTIST_PERSONHOOD_PROOF_SUMMARY_V1"), summary);
        bytes32 hash = keccak256(expected);
        require(
            summary.version == 1 && summary.nativeRecordHash == native_
                && PersonhoodRead(owner).personhoodProofSummaryHash(native_) == hash,
            "original retained summary identity and independent bytes"
        );
        address pointer = _summaryCarrier(owner, hash, expected);
        require(
            _summaryCarrier(archive_, hash, expected) == pointer,
            "Archive registers exact immutable owner carrier"
        );
        bytes32 eventTopic = keccak256(
            "ArtistPersonhoodProofRetained(uint16,bytes32,address,bytes32,(uint16,uint256,bytes32,bytes32,bytes32,bytes32,uint64,uint256,bytes32,(uint16,bytes32,address,bytes32,bytes32,address,bytes32,bytes32),bytes32,address,bytes32,address,bytes32,address,bytes32,address,bytes32,bytes32[4],uint256,bytes32,bytes32,address,bytes32,bytes32,address[6],bytes32[6]))"
        );
        uint256 found;
        for (uint256 i; i < logs.length; ++i) {
            if (
                logs[i].emitter != owner || logs[i].topics.length == 0
                    || logs[i].topics[0] != eventTopic
            ) continue;
            ++found;
            require(
                logs[i].topics.length == 3 && logs[i].topics[1] == native_
                    && logs[i].topics[2]
                        == bytes32(uint256(uint160(summary.evidenceReference.artistRegistry)))
                    && keccak256(logs[i].data) == keccak256(abi.encode(uint16(1), hash, summary)),
                "exact original emitter, indexed origin/native hash and all retained event fields"
            );
        }
        require(found == 1, "one successful original proof-retention event");
    }

    function _hydrationRollbackFingerprint(Next memory n) private view returns (bytes32) {
        T.SuiteConfiguration memory nextSuite = n.coordinator.suiteConfiguration();
        CP.Checkpoint[7] memory headers;
        bytes32[7] memory commitments;
        uint256[7] memory receipts;
        uint256[4] memory payloads;
        for (uint256 i; i < 7; ++i) {
            headers[i] = CP(nextSuite.owners[i]).authorityCheckpoint();
            commitments[i] = HydrationOwner(nextSuite.owners[i]).authorityHydrationCommitment();
            receipts[i] = Native(nextSuite.owners[i]).artistNativeReceiptCount();
        }
        for (uint256 i; i < 3; ++i) {
            payloads[i] =
                IStreamArtistReconstruction(nextSuite.owners[2 + i * 2]).storedPayloadCount();
        }
        payloads[3] = n.archive.storedPayloadCount();
        return keccak256(
            abi.encode(
                headers,
                commitments,
                receipts,
                payloads,
                History(address(n.registry)).artistHistoryContinuityCommitment(),
                IStreamArtistC2PAReads(nextSuite.owners[4]).personhoodAttestation(1, artistId)
            )
        );
    }

    function testOp60LateArchiveFailureRestoresAllSevenImportsAndIdenticalSafeRetry() public {
        _start(true);
        bytes32 documentary = _notarize(0, false, Subjects.SubjectKind.COLLECTION);
        bytes32 native_ = _select(documentary);
        Personhood.Summary memory original = _summary(native_);
        Next memory n = _cutover(true, true);
        RH.Request memory p = _readyRequest();
        bytes memory data = abi.encodeCall(ReadyHydrate.hydrateArtistAuthorityWithReadiness, (p));
        address nextOwner = n.coordinator.suiteConfiguration().owners[4];
        bytes32 before_ = _hydrationRollbackFingerprint(n);
        bytes32 sourceBefore = _roots();
        uint256 nonce = artist.nonce();
        uint256 previousBlock = block.number;
        // This is the original Archive's actual uint64 append bound. Hydration source reads,
        // all seven owner writes and history activation precede that append. The counted
        // expectation covers exactly TWO calls across failure and retry; the successful
        // retry alone cannot satisfy it when the failed attempt stopped prematurely.
        vm.roll(uint256(type(uint64).max) + 1);
        PersonhoodRetentionVm(address(vm))
            .expectCall(
                address(n.archive),
                abi.encodeWithSelector(IStreamArtistArchiveV2.appendArtistEvidenceV2.selector),
                uint64(2)
            );
        (bool ok,) =
            address(this).call(abi.encodeCall(this.executeTargetSafe, (address(n.registry), data)));
        require(
            !ok && _hydrationRollbackFingerprint(n) == before_ && _roots() == sourceBefore
                && artist.nonce() == nonce
                && PersonhoodRead(nextOwner).personhoodProofSummaryHash(native_) == 0
                && PersonhoodRead(nextOwner).personhoodProofSummary(native_).version == 0
                && IStreamArtistC2PAReads(nextOwner).personhoodAttestation(1, artistId).recordHash
                    == 0,
            "late op60 refusal restores seven headers/guards/receipts, activation, catalogs, selection, summary and Safe"
        );
        _notHydrated(n);
        vm.roll(previousBlock);
        vm.recordLogs();
        require(
            this.executeTargetSafe(address(n.registry), data), "identical op60 Safe calldata retry"
        );
        Vm.Log[] memory successfulLogs = vm.getRecordedLogs();
        require(
            artist.nonce() == nonce + 1
                && keccak256(abi.encode(PersonhoodRead(nextOwner).personhoodProofSummary(native_)))
                    == keccak256(abi.encode(original))
                && IStreamArtistC2PAReads(nextOwner).personhoodAttestation(1, artistId).recordHash
                == native_,
            "exact original summary and native record imported once"
        );
        T.SuiteConfiguration memory nextSuite = n.coordinator.suiteConfiguration();
        bytes32 commitment = HydrationOwner(nextSuite.owners[0]).authorityHydrationCommitment();
        require(commitment != 0, "completed import");
        for (uint256 i; i < 7; ++i) {
            require(
                HydrationOwner(nextSuite.owners[i]).authorityHydrationCommitment() == commitment,
                "all seven original ownership commitments agree"
            );
        }
        _assertSummaryRetention(nextOwner, address(n.archive), native_, successfulLogs);
    }

    function testEarlyOp60RefusalDoesNotCountAsLateArchiveAttempt() public {
        _start(true);
        bytes32 native_ = _select(_notarize(0, false, Subjects.SubjectKind.COLLECTION));
        Next memory n = _cutover(true, true);
        RH.Request memory complete = _readyRequest();
        RH.Request memory incomplete = abi.decode(abi.encode(complete), (RH.Request));
        RH.AttestationInput[] memory reduced =
            new RH.AttestationInput[](complete.attestations.length - 1);
        for (uint256 i; i < reduced.length; ++i) {
            reduced[i] = complete.attestations[i];
        }
        incomplete.attestations = reduced;
        bytes32 before_ = _hydrationRollbackFingerprint(n);
        uint256 nonce = artist.nonce();
        // Unlike the late-failure case, the omitted-row attempt must make no Archive
        // append. Exactly ONE append across both calls belongs to the complete retry.
        PersonhoodRetentionVm(address(vm))
            .expectCall(
                address(n.archive),
                abi.encodeWithSelector(IStreamArtistArchiveV2.appendArtistEvidenceV2.selector),
                uint64(1)
            );
        (bool ok,) = address(this)
            .call(
                abi.encodeCall(
                    this.executeTargetSafe,
                    (
                        address(n.registry),
                        abi.encodeCall(
                            ReadyHydrate.hydrateArtistAuthorityWithReadiness, (incomplete)
                        )
                    )
                )
            );
        require(
            !ok && _hydrationRollbackFingerprint(n) == before_ && artist.nonce() == nonce,
            "early omitted-row refusal never imports or advances the Safe"
        );
        _notHydrated(n);
        vm.recordLogs();
        require(
            this.executeTargetSafe(
                address(n.registry),
                abi.encodeCall(ReadyHydrate.hydrateArtistAuthorityWithReadiness, (complete))
            ),
            "complete control retry"
        );
        Vm.Log[] memory logs = vm.getRecordedLogs();
        require(artist.nonce() == nonce + 1, "one successful control transaction");
        _assertSummaryRetention(
            n.coordinator.suiteConfiguration().owners[4], address(n.archive), native_, logs
        );
    }
}
