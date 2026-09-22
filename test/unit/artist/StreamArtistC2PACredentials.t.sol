// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "./ArtistPublicationHydrationFixture.sol";
import {
    StreamArtistC2PATypes as C2PA,
    IStreamArtistC2PAReads
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistC2PA.sol";
import {
    StreamC2PAReconciliation
} from "../../../smart-contracts/domains/metadata/StreamC2PAReconciliation.sol";
import {
    IStreamC2PAReconciliation as CR
} from "../../../smart-contracts/interfaces/stream/metadata/IStreamC2PAReconciliation.sol";
import { MetadataExecutorBoundary } from "../../helpers/scoped-preservation-boundaries/StreamCollectionMetadataV1Boundaries.sol";
import {
    IStreamStaticMetadataRouter as SR
} from "../../../smart-contracts/interfaces/stream/metadata/IStreamStaticMetadataRouter.sol";
import {
    StreamCollectionManifestTypes as CM
} from "../../../smart-contracts/interfaces/stream/metadata/StreamCollectionManifestTypes.sol";
import {
    IStreamCollectionManifestWriter,
    IStreamMetadataManifestSelection
} from "../../../smart-contracts/interfaces/stream/metadata/IStreamCollectionManifestWriter.sol";
import {
    IStreamMetadataServingFacts as C2PAServing
} from "../../../smart-contracts/interfaces/stream/metadata/IStreamMetadataServingFacts.sol";

/// @notice Actual Artist owners/facade/Archive and threshold Safe; inherited Core/governance
/// and content-owner boundaries remain typed. No genuine C2PA cryptographic validation claim.
contract StreamArtistC2PACredentialsTest is ArtistPublicationHydrationFixture {
    bytes32 private constant CREDENTIAL_SCHEMA = keccak256("6529STREAM_ARTIST_C2PA_CREDENTIALS_V1");

    function _payload(bytes32 previous, bool empty) private view returns (bytes memory) {
        C2PA.Credential[] memory credentials = new C2PA.Credential[](empty ? 0 : 1);
        if (!empty) {
            credentials[0] =
                C2PA.Credential(1, keccak256("test SPKI"), keccak256("identity key"), 1, 0);
        }
        return abi.encode(
            C2PA.Payload(
                1, artistId, ingress.operativeIdentityRecord(artistId), previous, credentials
            )
        );
    }

    function _terms(bytes memory statement) private view returns (T.Attestation memory) {
        return T.Attestation(
            1,
            10,
            artistId,
            ingress.operativeIdentityRecord(artistId),
            CREDENTIAL_SCHEMA,
            keccak256(statement),
            "urn:c2pa:credentials"
        );
    }

    function _record(bytes memory statement) private returns (bytes32 record) {
        T.Attestation memory p = _terms(statement);
        T.Authorization memory a = _authorization(true);
        bytes32 digest = ingress.attestationDigest(p, a);
        _authOrigins(digest, a.nonce);
        a.signature = _signature(digest);
        _artistCall(
            abi.encodeCall(IStreamArtistOnboarding.recordArtistAttestation, (p, a, statement))
        );
        record =
        IStreamArtistAttributionOwner(suite.owners[4]).attestation(1, 10, artistId).recordHash;
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
                CREDENTIAL_SCHEMA,
                p.statementHash,
                keccak256(bytes(p.statementURI)),
                artistId,
                address(artist),
                uint8(1),
                a.nonce,
                a.time
            )
        );
        require(record == expected, "original op24 record domain");
        originalAttestations.push(RH.AttestationInput(p, a.nonce));
        originalAttestationRecords.push(record);
        _candidate(2, "identity_authority.replay.attestation_key", keccak256(abi.encode(record)));
    }

    function testCredentialUpdatesPreservePersonhoodAndOriginalMintPrerequisites() public {
        _readinessHistory();
        bytes32 original =
            IStreamArtistC2PAReads(suite.owners[4]).personhoodAttestation(1, artistId).recordHash;
        require(original != 0 && !_closed(_mintCall()), "original complete readiness");
        bytes32 record = _record(_payload(0, false));
        C2PA.Head memory h = IStreamArtistC2PAReads(suite.owners[4]).c2paCredentialHead(artistId);
        require(h.revision == 1 && h.recordHash == record && h.previousRecordHash == 0);
        require(h.artistId == artistId && h.collectionId == 1 && h.generation == 1);
        require(
            h.bindingHash == ingress.displayBinding(1).bindingHash
                && h.sourceRegistry == address(ingress)
        );
        require(h.identityRecordHash == ingress.operativeIdentityRecord(artistId));
        require(
            IStreamArtistC2PAReads(suite.owners[4]).personhoodAttestation(1, artistId).recordHash
                == original,
            "personhood retained"
        );
        require(!_closed(_mintCall()), "credential update does not erase floor");
    }

    function testCredentialOnlyUpdateDoesNotCreatePersonhoodEvidence() public {
        _accept();
        _record(_payload(0, false));
        require(
            IStreamArtistC2PAReads(suite.owners[4]).personhoodAttestation(1, artistId).recordHash
                == 0,
            "credentials are not personhood"
        );
        require(_closed(_mintCall()), "missing original prerequisites remain closed");
    }

    function testExplicitEmptyEnumerationAndLaterPersonhoodKeepIndependentHeads() public {
        _readinessHistory();
        bytes32 first = _record(_payload(0, false));
        bytes32 second = _record(_payload(first, true));
        _attest(
            10,
            artistId,
            ingress.operativeIdentityRecord(artistId),
            keccak256("6529STREAM_ARTIST_PERSONHOOD_EVIDENCE_V1")
        );
        C2PA.Head memory h = IStreamArtistC2PAReads(suite.owners[4]).c2paCredentialHead(artistId);
        require(h.recordHash == second && h.previousRecordHash == first && h.revision == 2);
        require(
            IStreamArtistC2PAReads(suite.owners[4]).c2paCredentialRecord(first).recordHash == first,
            "immutable original head"
        );
        require(
            IStreamArtistC2PAReads(suite.owners[4]).personhoodAttestation(1, artistId).schemaId
                == keccak256("6529STREAM_ARTIST_PERSONHOOD_EVIDENCE_V1")
        );
        require(
            abi.decode(
                    IStreamArtistAttributionOwner(suite.owners[4]).statementBytes(h.statementHash),
                    (C2PA.Payload)
                ).credentials.length == 0
        );
    }

    function testStaleCredentialHeadAndMalformedStatementRollBackOriginalOwners() public {
        _readinessHistory();
        bytes32 first = _record(_payload(0, false));
        bytes32 roots = _roots();
        bytes memory stale = _payload(0, true);
        vm.expectRevert();
        this.recordCredential(stale);
        require(
            _roots() == roots
                && IStreamArtistC2PAReads(suite.owners[4]).c2paCredentialHead(artistId).recordHash
                    == first
        );
        bytes memory malformed = bytes.concat(_payload(first, false), hex"00");
        vm.expectRevert();
        this.recordCredential(malformed);
        require(
            _roots() == roots
                && IStreamArtistC2PAReads(suite.owners[4]).c2paCredentialHead(artistId).recordHash
                    == first
        );
    }

    function recordCredential(bytes calldata payload) external returns (bytes32) {
        require(msg.sender == address(this));
        return _record(payload);
    }

    function testLateArchiveRefusalRollsBackHeadsAndSafeNonceThenIdenticalRetry() public {
        _readinessHistory();
        bytes memory statement = _payload(0, false);
        T.Attestation memory p = _terms(statement);
        T.Authorization memory a = _authorization(true);
        bytes memory data =
            abi.encodeCall(IStreamArtistOnboarding.recordArtistAttestation, (p, a, statement));
        bytes32 roots = _roots();
        bytes32 personhood =
            IStreamArtistC2PAReads(suite.owners[4]).personhoodAttestation(1, artistId).recordHash;
        uint256 safeNonce = artist.nonce();
        uint256 originalBlock = block.number;
        vm.roll(uint256(type(uint64).max) + 1);
        vm.expectRevert();
        this.executeTargetSafe(address(ingress), data);
        require(_roots() == roots && artist.nonce() == safeNonce);
        require(
            IStreamArtistC2PAReads(suite.owners[4]).c2paCredentialHead(artistId).recordHash == 0
        );
        require(
            IStreamArtistC2PAReads(suite.owners[4]).personhoodAttestation(1, artistId).recordHash
                == personhood
        );
        vm.roll(originalBlock);
        require(this.executeTargetSafe(address(ingress), data), "identical Safe calldata retry");
        require(
            IStreamArtistC2PAReads(suite.owners[4]).c2paCredentialHead(artistId).revision == 1
                && artist.nonce() == safeNonce + 1
        );
    }

    function testCompleteHydrationReconstructsCredentialAndPersonhoodHistories() public {
        _readinessHistory();
        bytes32 first = _record(_payload(0, false));
        _record(_payload(first, true));
        C2PA.Head memory expected =
            IStreamArtistC2PAReads(suite.owners[4]).c2paCredentialHead(artistId);
        bytes32 personhood =
            IStreamArtistC2PAReads(suite.owners[4]).personhoodAttestation(1, artistId).recordHash;
        Next memory n = _cutover(true, true);
        RH.Request memory request = _readyRequest();
        require(
            this.executeTargetSafe(
                address(n.registry),
                abi.encodeCall(ReadyHydrate.hydrateArtistAuthorityWithReadiness, (request))
            ),
            "complete original import"
        );
        require(
            keccak256(
                abi.encode(
                    IStreamArtistC2PAReads(n.coordinator.suiteConfiguration().owners[4])
                        .c2paCredentialHead(artistId)
                )
            ) == keccak256(abi.encode(expected))
        );
        require(
            IStreamArtistC2PAReads(n.coordinator.suiteConfiguration().owners[4])
            .c2paCredentialRecord(first)
            .recordHash == first
        );
        require(
            IStreamArtistC2PAReads(n.coordinator.suiteConfiguration().owners[4])
            .personhoodAttestation(1, artistId)
            .recordHash == personhood
        );
    }

    function testHydrationCannotOmitLatestCredentialReceipt() public {
        _readinessHistory();
        _record(_payload(0, false));
        Next memory n = _cutover(true, true);
        RH.Request memory complete = _readyRequest();
        RH.Request memory missing = abi.decode(abi.encode(complete), (RH.Request));
        RH.AttestationInput[] memory shortRows =
            new RH.AttestationInput[](missing.attestations.length - 1);
        for (uint256 i; i < shortRows.length; ++i) {
            shortRows[i] = missing.attestations[i];
        }
        missing.attestations = shortRows;
        vm.expectRevert();
        this.executeTargetSafe(
            address(n.registry),
            abi.encodeCall(ReadyHydrate.hydrateArtistAuthorityWithReadiness, (missing))
        );
        require(
            IStreamArtistC2PAReads(n.coordinator.suiteConfiguration().owners[4])
            .c2paCredentialHead(artistId)
            .recordHash == 0
        );
        _notHydrated(n);
        require(
            this.executeTargetSafe(
                address(n.registry),
                abi.encodeCall(ReadyHydrate.hydrateArtistAuthorityWithReadiness, (complete))
            ),
            "complete descriptor retry"
        );
    }

    struct C2PAJoin {
        MetadataExecutorBoundary governance;
        StreamSchemaRegistry schemas;
        StreamSchemaDocumentStore store;
        StreamCollectionMetadataV1 host;
        StreamC2PAReconciliation companion;
        CR.Report report;
    }

    /// @dev Actual Artist/Metadata/schema/Store/Safe. Core, governance execution and Router
    /// content source/selection remain explicit typed boundaries; observations are synthetic.
    function _join() private returns (C2PAJoin memory j) {
        _readinessHistory();
        bytes32 credentials = _record(_payload(0, false));
        j.governance = new MetadataExecutorBoundary();
        j.schemas = new StreamSchemaRegistry(address(j.governance));
        j.store = StreamSchemaDocumentStore(j.schemas.chunkStore());
        _definition(
            j,
            "RAW_BYTES",
            IStreamSchemaRegistry.DocumentKind.CANONICALIZATION,
            bytes(j.schemas.RAW_BYTES_DEFINITION())
        );
        _definition(
            j,
            "6529STREAM_C2PA_RECONCILIATION_REPORT_V1",
            IStreamSchemaRegistry.DocumentKind.SCHEMA,
            bytes(vm.readFile("schemas/records/6529STREAM_C2PA_RECONCILIATION_REPORT_V1.json"))
        );
        StreamCollectionMetadataV1.Configuration memory config;
        config.core = address(core);
        config.executor = address(j.governance);
        config.schemas = address(j.schemas);
        config.artistRegistry = address(ingress);
        config.deploymentManifestHash = keccak256("C2PA metadata test deployment");
        config.manifestHash = keccak256("C2PA metadata test module");
        config.manifestURI = "ipfs://c2pa-test";
        config.dependencyReadGas = IStreamGasParameterHost.GasParameterConfig(
            "METADATA_DEPENDENCY_READ_GAS", 150000, 100000, 2
        );
        config.artistReadGas = IStreamGasParameterHost.GasParameterConfig(
            "METADATA_ARTIST_READ_GAS", 2000000, 1000000, 2
        );
        j.host = new StreamCollectionMetadataV1(config);
        core.set(keccak256("COLLECTION_METADATA"), address(j.host), false);
        core.set(keccak256("METADATA_ROUTER"), address(metadata), false);
        bytes32 family = keccak256("6529STREAM_RECORD_FAMILY_C2PA_V1");
        (bytes32 scope, bytes32 oldHash, bytes32 nextHash) =
            j.host.recordTypeTransition(keccak256("C2PA_VALIDATION"), family, 0x150);
        j.governance
            .execute(
                address(j.host),
                abi.encodeCall(
                    j.host.admitRecordType, (keccak256("C2PA_VALIDATION"), family, uint16(0x150))
                ),
                scope,
                oldHash,
                nextHash
            );
        _verifier(j, address(artist), 6);
        C2PAServing.ServingSource memory source;
        source.imageURI = "ipfs://actual-committed-media";
        avm.mockCall(
            address(metadata),
            abi.encodeWithSignature("renderingProfile()"),
            abi.encode(
                keccak256("6529STREAM_ROUTER_STABLE_PRESENTATION_V1"),
                keccak256("6529STREAM_METADATA_TOKEN_RENDER_CONTEXT_V1"),
                keccak256("6529STREAM_METADATA_RENDER_NO_EXTERNAL_READS_V1")
            )
        );
        avm.mockCall(
            address(metadata),
            abi.encodeCall(C2PAServing.collectionServingSource, (uint256(1))),
            abi.encode(source)
        );
        CM.MediaManifest memory media;
        media.imageSourceType = CM.PayloadSourceType.IPFS;
        media.imageURI = source.imageURI;
        media.imageHash = keccak256("actual local media");
        media.imageMimeType = "image/png";
        vm.prank(address(metadata));
        bytes32 mediaManifest =
            IStreamCollectionManifestWriter(address(j.host)).storeMediaManifest(1, media);
        CM.Selection memory selected =
            CM.Selection(address(j.host), address(j.host).codehash, mediaManifest);
        avm.mockCall(
            address(metadata),
            abi.encodeCall(
                IStreamMetadataManifestSelection.selectedCollectionManifest, (uint256(1), uint8(3))
            ),
            abi.encode(selected)
        );
        SR.RawSource memory raw;
        raw.chainId = block.chainid;
        raw.configured = true;
        raw.imageURI = source.imageURI;
        raw.mediaManifest = selected;
        avm.mockCall(
            address(metadata), abi.encodeCall(SR.staticRenderSource, (uint256(1))), abi.encode(raw)
        );
        j.companion = new StreamC2PAReconciliation(
            address(core),
            address(j.host),
            address(ingress),
            address(metadata),
            address(artist),
            address(j.governance),
            IStreamGasParameterHost.GasParameterConfig(
                "C2PA_DEPENDENCY_READ_GAS", 1000000, 100000, 2
            )
        );
        CR.Report memory p;
        p.version = 1;
        p.profile = j.companion.PROFILE();
        p.collectionId = 1;
        p.subjectId = StreamMetadataSubjects.scopeSubject(
            block.chainid,
            address(core),
            StreamFinalityScope(StreamFinalityScopeType.COLLECTION, 1, 0, 0)
        );
        p.artistId = artistId;
        p.bindingHash = ingress.displayBinding(1).bindingHash;
        p.generation = 1;
        p.identityRecordHash = ingress.operativeIdentityRecord(artistId);
        p.identityDocumentHash = p.identityRecordHash;
        p.credentialRecordHash = credentials;
        p.publicKeyHistoryHash = keccak256("synthetic verifier key history observation");
        p.credentialEnumerationHash =
        IStreamArtistC2PAReads(suite.owners[4]).c2paCredentialHead(artistId).statementHash;
        p.selectedMediaManifestHash = mediaManifest;
        p.mediaSlot = 1;
        p.mediaHash = media.imageHash;
        p.claimAssetHash = media.imageHash;
        p.manifestHash = keccak256("manifest");
        p.claimHash = keccak256("claim");
        p.claimSignatureHash = keccak256("signature");
        p.signerKind = 1;
        p.signerFingerprint = keccak256("test SPKI");
        p.signerKeyFingerprint = p.signerFingerprint;
        p.keyId = keccak256("identity key");
        p.signedAt = uint64(block.timestamp);
        p.validation = CR.ValidationStatus.VALID;
        p.authorship = CR.AuthorshipStatus.CONSISTENT;
        p.assertsAuthorship = true;
        p.validatorIdentityHash = keccak256("explicit fixture verifier");
        p.softwareVersionHash = keccak256("test-only-observation-1");
        (p.validationReportHash,) =
            j.store.publishChunk(bytes("synthetic selected verifier observation; no crypto claim"));
        (p.trustAnchorsHash,) = j.store.publishChunk(bytes("explicit test trust anchors"));
        p.reportURI = "ipfs://synthetic-c2pa-report";
        j.report = p;
    }

    function _definition(
        C2PAJoin memory j,
        string memory name,
        IStreamSchemaRegistry.DocumentKind kind,
        bytes memory payload
    ) private {
        (bytes32 hash,) = j.store.publishChunk(payload);
        bytes32[] memory chunks = new bytes32[](1);
        chunks[0] = hash;
        IStreamSchemaRegistry.DocumentSpec memory spec = IStreamSchemaRegistry.DocumentSpec(
            name, kind, hash, j.schemas.RAW_BYTES(), 0, "", uint32(payload.length)
        );
        (bytes32 s, bytes32 o, bytes32 n) = j.schemas.registrationTransition(spec, chunks);
        j.governance
            .execute(
                address(j.schemas),
                abi.encodeCall(j.schemas.registerDocument, (spec, chunks)),
                s,
                o,
                n
            );
    }

    function _verifier(C2PAJoin memory j, address account, uint8 authClass) private {
        bytes32 family = keccak256("6529STREAM_RECORD_FAMILY_C2PA_V1");
        (bytes32 s, bytes32 o, bytes32 n) =
            j.host.familyWriterTransition(1, family, authClass, account, true);
        j.governance
            .execute(
                address(j.host),
                abi.encodeCall(
                    j.host.setFamilyWriter, (uint256(1), family, authClass, account, true)
                ),
                s,
                o,
                n
            );
    }

    function _publish(C2PAJoin memory j) private returns (bytes32 hash) {
        return _publishClass(j, 6);
    }

    function _publishClass(C2PAJoin memory j, uint8 expectedClass) private returns (bytes32 hash) {
        bytes memory payload = abi.encode(j.report);
        IStreamPreservationRecords.CollectionRecord memory r;
        r.recordType = keccak256("C2PA_VALIDATION");
        r.subjectId = j.report.subjectId;
        r.schemaId = j.companion.SCHEMA();
        r.contentHash = IStreamPreservationRecords.HashRef(
            1, abi.encode(keccak256(payload)), j.schemas.RAW_BYTES()
        );
        r.uri = j.report.reportURI;
        r.effectiveAt = uint64(block.timestamp);
        hash = j.host.deriveCollectionRecordHashFor(address(artist), 1, r);
        require(
            this.executeTargetSafe(
                address(j.host),
                abi.encodeCall(j.host.recordCollectionRecordWithPayload, (uint256(1), r, payload))
            )
        );
        (, IStreamCollectionMetadataV1.RecordReceipt memory receipt) = j.host.collectionRecord(hash);
        require(
            receipt.recorder == address(artist) && receipt.authorizationClass == expectedClass
                && receipt.artistAuthorization == 0,
            "explicit receipt class, not op24 authority"
        );
    }

    function testSelectedVerifierReceiptPinsActualArtistHeadAndRetainedEvidence() public {
        C2PAJoin memory j = _join();
        bytes32 hash = _publish(j);
        bytes32 roots = _roots();
        bytes32 selected = j.companion.adopt(1, j.report.subjectId, hash, 0, 0);
        CR.Display memory d = j.companion.display(1, j.report.subjectId);
        require(d.current && d.recordHash == hash && d.selectionHash == selected);
        require(
            d.validation == CR.ValidationStatus.VALID
                && d.authorship == CR.AuthorshipStatus.CONSISTENT
        );
        require(_roots() == roots, "reconciliation never grants Artist authority");
        vm.expectRevert();
        j.companion.adopt(1, j.report.subjectId, hash, selected, 1);
    }

    function testNewVerifierHeadMakesDisplayUnevaluatedUntilExplicitAdoption() public {
        C2PAJoin memory j = _join();
        bytes32 first = _publish(j);
        bytes32 selected = j.companion.adopt(1, j.report.subjectId, first, 0, 0);
        j.report.authorship = CR.AuthorshipStatus.DIVERGENT;
        j.report.publicKeyHistoryHash = keccak256("verifier corrected key-history interpretation");
        bytes32 second = _publish(j);
        CR.Display memory stale = j.companion.display(1, j.report.subjectId);
        require(!stale.current && stale.authorship == CR.AuthorshipStatus.UNEVALUATED);
        j.companion.adopt(1, j.report.subjectId, second, selected, 1);
        require(
            j.companion.selectionAt(1, j.report.subjectId, 1).recordHash == first,
            "original survives supersession"
        );
        require(
            j.companion.display(1, j.report.subjectId).authorship == CR.AuthorshipStatus.DIVERGENT
        );
    }

    function testCredentialWithdrawalInvalidatesCurrentReportAndRejectsConsistentEmptyEnumeration()
        public
    {
        C2PAJoin memory j = _join();
        bytes32 hash = _publish(j);
        bytes32 selected = j.companion.adopt(1, j.report.subjectId, hash, 0, 0);
        j.report.credentialRecordHash = _record(_payload(j.report.credentialRecordHash, true));
        j.report.credentialEnumerationHash =
        IStreamArtistC2PAReads(suite.owners[4]).c2paCredentialHead(artistId).statementHash;
        require(
            !j.companion.display(1, j.report.subjectId).current, "changed exact credential head"
        );
        hash = _publish(j);
        vm.expectRevert();
        j.companion.adopt(1, j.report.subjectId, hash, selected, 1);
        j.report.authorship = CR.AuthorshipStatus.UNEVALUATED;
        hash = _publish(j);
        j.companion.adopt(1, j.report.subjectId, hash, selected, 1);
        require(
            j.companion.display(1, j.report.subjectId).authorship == CR.AuthorshipStatus.UNEVALUATED
        );
    }

    function testMissingRetainedTrustBytesRollBackSafeAdoptionThenIdenticalRetry() public {
        C2PAJoin memory j = _join();
        bytes memory missing = bytes("later retained exact trust anchors");
        j.report.trustAnchorsHash = keccak256(missing);
        bytes32 hash = _publish(j);
        bytes memory data = abi.encodeCall(
            j.companion.adopt, (uint256(1), j.report.subjectId, hash, bytes32(0), uint64(0))
        );
        uint256 nonce = artist.nonce();
        bytes32 roots = _roots();
        vm.expectRevert();
        this.executeTargetSafe(address(j.companion), data);
        require(
            artist.nonce() == nonce && _roots() == roots
                && j.companion.currentSelection(1, j.report.subjectId).recordHash == 0
        );
        j.store.publishChunk(missing);
        require(
            this.executeTargetSafe(address(j.companion), data),
            "identical saved Safe adoption retry"
        );
        require(j.companion.currentSelection(1, j.report.subjectId).recordHash == hash);
    }

    function testSameVerifierClassEightReceiptCannotBecomeValidatedReport() public {
        C2PAJoin memory j = _join();
        bytes32 family = keccak256("6529STREAM_RECORD_FAMILY_C2PA_V1");
        (bytes32 s, bytes32 o, bytes32 n) =
            j.host.familyWriterTransition(1, family, 6, address(artist), false);
        j.governance
            .execute(
                address(j.host),
                abi.encodeCall(
                    j.host.setFamilyWriter, (uint256(1), family, uint8(6), address(artist), false)
                ),
                s,
                o,
                n
            );
        _verifier(j, address(artist), 8);
        bytes32 hash = _publishClass(j, 8);
        vm.expectRevert(abi.encodeWithSelector(CR.InvalidC2PAReport.selector));
        j.companion.adopt(1, j.report.subjectId, hash, 0, 0);
        require(j.companion.currentSelection(1, j.report.subjectId).recordHash == 0);
    }

    function testClaimedMediaCannotReplaceActualSelectedManifestBytes() public {
        C2PAJoin memory j = _join();
        j.report.mediaHash = keccak256("foreign media");
        j.report.claimAssetHash = j.report.mediaHash;
        bytes32 hash = _publish(j);
        vm.expectRevert(abi.encodeWithSelector(CR.InvalidC2PAReport.selector));
        j.companion.adopt(1, j.report.subjectId, hash, 0, 0);
        require(j.companion.currentSelection(1, j.report.subjectId).recordHash == 0);
    }

    function testRuntimeDriftReturnsUnevaluatedWithoutErasingHistoricalSelection() public {
        C2PAJoin memory j = _join();
        bytes32 hash = _publish(j);
        bytes32 selected = j.companion.adopt(1, j.report.subjectId, hash, 0, 0);
        bytes memory runtime = address(j.host).code;
        vm.etch(address(j.host), hex"00");
        CR.Display memory d = j.companion.display(1, j.report.subjectId);
        require(
            !d.current && d.validation == CR.ValidationStatus.UNEVALUATED
                && d.authorship == CR.AuthorshipStatus.UNEVALUATED
        );
        require(d.recordHash == hash && d.selectionHash == selected);
        vm.etch(address(j.host), runtime);
        require(j.companion.display(1, j.report.subjectId).current);
    }
}
