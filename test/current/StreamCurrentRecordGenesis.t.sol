// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../helpers/StreamCurrentStackFixture.sol";
import "../helpers/OfficialSafeFixture.sol";
import {
    StreamGenesisManifestTailFixture as TailFixture
} from "../helpers/StreamGenesisManifestTailFixture.sol";
import "../../script/current/StreamFullV1RecordProducts.sol";
import "../../script/current/StreamGovernanceCatalogStagePlan.sol";
import {
    StreamOwnerNoticeTypes
} from "../../smart-contracts/interfaces/stream/metadata/StreamOwnerNoticeTypes.sol";
import {
    IStreamGeneralAttestations as General
} from "../../smart-contracts/interfaces/stream/metadata/IStreamGeneralAttestations.sol";
import {
    IStreamCollectionAttestations as Independent
} from "../../smart-contracts/interfaces/stream/metadata/IStreamCollectionAttestations.sol";
import {
    IStreamPreservationRecords as Original
} from "../../smart-contracts/interfaces/stream/preservation/IStreamPreservationRecords.sol";
import {
    IStreamPreservationRecordsV1 as Preservation
} from "../../smart-contracts/interfaces/stream/preservation/IStreamPreservationRecordsV1.sol";
import {
    IStreamSchemaRegistry as Schema
} from "../../smart-contracts/interfaces/stream/metadata/IStreamSchemaRegistry.sol";
import {
    StreamRecordFamilies as Families
} from "../../smart-contracts/domains/records/StreamRecordFamilies.sol";
import {
    IStreamArtistIdentityRevisionReads
} from "../../smart-contracts/interfaces/stream/artist/IStreamArtistIdentityRevision.sol";

/// @notice Same current Core, MetadataV1, original Artist owners and actual threshold Safes.
/// @dev Only the inherited upstream entropy service is a double. Record schema fixtures are
/// explicitly synthetic, except the exact checked-in notarization/profile/JCS documents.
/// These cases are authored composition acceptance, not an executed full37 acceptance claim.
contract StreamCurrentRecordGenesisTest is StreamCurrentStackFixture, OfficialSafeFixture {
    StreamFullV1RecordProducts.Configuration private configuration;
    StreamFullV1RecordProducts.Products private records;
    OfficialSafe private governor;
    OfficialSafe private otherSafe;
    OfficialSafe private artistSafe;
    uint256[] private keys;
    bytes32 private schemaId;
    bytes32 private constant ARCHIVE = keccak256("GENESIS_ARCHIVE_FIXTURE_V1");

    function setUp() public {
        keys.push(0x65292701);
        keys.push(0x65292702);
        SafeComponents memory components = deploySafeComponents("1.4.1");
        governor = createOfficialSafe(components, safeOwnerAddresses(keys), 2, 3727);
        otherSafe = createOfficialSafe(components, safeOwnerAddresses(keys), 2, 3728);
        artistSafe = createOfficialSafe(components, safeOwnerAddresses(keys), 2, 3729);
        _deployCurrentStack(address(artistSafe), vm.addr(PLATFORM_KEY));
        _installGovernor();
        configuration.core = address(core);
        configuration.executor = address(executor);
        configuration.metadata = address(assemblyMetadata);
        configuration.schemas = address(assemblySchemas);
        configuration.artistRegistry = address(artists);
        configuration.artistAttribution = artistSuite.owners[4];
        configuration.deploymentHash = DEPLOYMENT_HASH;
        // Raw CIDs identify the exact fixture manifest strings; availability is not asserted.
        configuration.preservation = StreamFullV1RecordProducts.Manifest(
            keccak256("fixture full-byte preservation manifest"),
            "ipfs://bafkreig4cd54mehjls33ydm2ymakbmuud5b4ofta3ee72nlwi3xt3updve"
        );
        configuration.general = StreamFullV1RecordProducts.Manifest(
            keccak256("fixture general attestation manifest"),
            "ipfs://bafkreiaum6s2mqig4ap2nkcfkohrzi7yupsiwhfm4ir5kgy6rwcjkcuvr4"
        );
        configuration.signatureGas = IStreamGasParameterHost.GasParameterConfig(
            "METADATA_ERC1271_VERIFY_GAS", 400000, 90000, 2
        );
        configuration.dependencyReadGas = IStreamGasParameterHost.GasParameterConfig(
            "METADATA_DEPENDENCY_READ_GAS", 1000000, 100000, 2
        );
        // The Artist coordinator and original owners must already exist and be reciprocal.
        records = StreamFullV1RecordProducts.deploy(configuration);
        _extendCatalog();
        TailFixture.Plan memory tail =
            TailFixture.plan(executor, address(registry), registry.registerModule.selector);
        _executeStage(tail.batch, keccak256("original Registry admission tail fixture"));
        TailFixture.assertInstalled(executor, tail, address(manifest));
        _registerModules();
        if (!assemblySchemas.document(assemblySchemas.RAW_BYTES()).exists) {
            _document(
                "RAW_BYTES",
                Schema.DocumentKind.CANONICALIZATION,
                bytes(assemblySchemas.RAW_BYTES_DEFINITION())
            );
        }
        schemaId = _document(
            "GENESIS_RECORD_SCHEMA_FIXTURE_V1",
            Schema.DocumentKind.SCHEMA,
            bytes("{\"fixture\":true,\"meaning\":\"opaque composition test bytes\"}")
        );
        _admitArchiveType();
    }

    function _artistProof(bytes32 digest) internal override returns (bytes memory) {
        return safeThresholdSignature(keys, safeMessageDigest(artistSafe, abi.encode(digest)));
    }

    function _additionalOperatingPolicies()
        internal
        view
        override
        returns (GovernanceActionPolicyEntry[] memory rows)
    {
        rows = new GovernanceActionPolicyEntry[](3);
        rows[0] = _policy(address(assemblySchemas), assemblySchemas.registerDocument.selector);
        rows[1] = _policy(address(assemblyMetadata), assemblyMetadata.setFamilyWriter.selector);
        rows[2] = _policy(address(assemblyMetadata), assemblyMetadata.admitRecordType.selector);
    }

    function testOriginalRecordProductsShareCurrentDependenciesAndGenuineModuleRows() public view {
        StreamFullV1RecordProducts.validate(configuration, records);
        require(
            records.preservation.chunkStore() == address(assemblyStore)
                && records.general.chunkStore() == address(assemblyStore),
            "one original payload store"
        );
        require(
            records.general.artistAttribution() == artistSuite.owners[4], "actual attribution owner"
        );
        StreamModuleRegistration[] memory rows =
            StreamFullV1RecordProducts.registrations(configuration, records, 500000);
        for (uint256 i; i < rows.length; ++i) {
            StreamModuleRecord memory actual = registry.moduleRecord(rows[i].module);
            require(
                actual.status == ModuleRegistryStatus.ACTIVE
                    && actual.interfaceId == rows[i].interfaceId
                    && actual.runtimeCodeHash == rows[i].expectedRuntimeCodeHash,
                "actual admission"
            );
        }
        require(
            rows[0].interfaceId == type(Preservation).interfaceId
                && rows[1].interfaceId == type(General).interfaceId,
            "distinct original interfaces"
        );
    }

    function testSafeSignedInstitutionAndEstateClaimsRetainBytesAndExactClassification() public {
        for (uint256 i; i < 2; ++i) {
            (Independent.Subject memory subject, General.Request memory r) = _request(i + 1);
            if (i == 1) r.attestationType = keccak256("ESTATE_VERIFICATION");
            bytes memory signature = _signature(governor, r);
            vm.recordLogs();
            bytes32 hash = records.general.recordSignedAttestation(subject, r, signature);
            _assertGeneralEvent(vm.getRecordedLogs(), r, hash);
            (General.Attestation memory value, General.Receipt memory receipt) =
                records.general.attestation(hash);
            require(
                value.attester == address(governor) && receipt.recorder == address(governor),
                "ERC1271 account remains attributed"
            );
            require(
                receipt.verificationClass == General.VerificationClass.SIGNER_VERIFIED
                    && receipt.authorityQualification
                        == General.AuthorityQualification.GENERAL_SIGNER_CLAIM
                    && receipt.identityRegistry == address(0)
                    && receipt.nativeArtistEvidenceHash == 0,
                "signature gives no Artist or identity elevation"
            );
            require(
                receipt.authorizationDigest == records.general.attestationDigest(r)
                    && receipt.schemaDefinitionHash
                        == keccak256(assemblySchemas.documentBytes(schemaId)),
                "actual definitions and authorization"
            );
            (, bytes memory payload) = records.general.recordPayload(hash);
            (, bytes memory bundle) = records.general.recordSignatureBundle(hash);
            require(
                keccak256(payload) == keccak256(r.payload)
                    && keccak256(bundle) == receipt.signatureBundleHash,
                "retained full evidence"
            );
        }
    }

    function testSameOwnersDifferentSafeAndNonceReplayFailWithoutPublishingEvidence() public {
        (Independent.Subject memory subject, General.Request memory r) = _request(17);
        bytes memory wrong = _signature(otherSafe, r);
        vm.expectRevert(
            abi.encodeWithSelector(General.InvalidGeneralSignature.selector, address(governor))
        );
        records.general.recordSignedAttestation(subject, r, wrong);
        require(
            !records.general.isAttesterNonceUsed(address(governor), r.nonce)
                && records.general.payloadPointerCount(1) == 0,
            "wrong Safe leaves no evidence"
        );
        bytes memory signature = _signature(governor, r);
        bytes32 hash = records.general.recordSignedAttestation(subject, r, signature);
        vm.expectRevert(
            abi.encodeWithSelector(General.GeneralNonceUsed.selector, address(governor), r.nonce)
        );
        records.general.recordSignedAttestation(subject, r, signature);
        (, uint64 count) = records.general.recordChainHash(1, r.attestationType);
        require(
            count == 1 && records.general.recordHashAt(1, r.attestationType, 0) == hash,
            "one successful original receipt"
        );
    }

    function testCurrentGeneralV2SafeRetainsFull24576BytePayloadAndOrderedChunks() public {
        (Independent.Subject memory subject, General.Request memory r) = _request(71);
        r.payload = new bytes(24576);
        for (uint256 i; i < r.payload.length; ++i) {
            r.payload[i] = bytes1(uint8(i * 37 + i / 8192));
        }
        r.statementURI = _fixtureContentURI(r.payload);
        require(records.general.MAX_RECORD_PAYLOAD_BYTES() == 24576, "current full-byte General v2");
        bytes memory signature = _signature(governor, r);
        bytes32 hash = records.general.recordSignedAttestation(subject, r, signature);
        (bytes32 contentHash, uint32 length, uint32 count) = records.general.recordPayloadInfo(hash);
        require(
            contentHash == keccak256(r.payload) && length == 24576 && count == 3,
            "all three original signed chunks"
        );
        (address first, bytes memory payload) = records.general.recordPayload(hash);
        require(
            payload.length == 24576 && keccak256(payload) == contentHash,
            "exact full historical bytes"
        );
        for (uint256 i; i < 3; ++i) {
            (bytes32 chunkHash, address pointer, uint32 bytes_) =
                records.general.recordPayloadChunkAt(hash, i);
            bytes memory chunk = new bytes(8192);
            for (uint256 j; j < 8192; ++j) {
                chunk[j] = r.payload[i * 8192 + j];
            }
            require(
                bytes_ == 8192 && chunkHash == keccak256(chunk)
                    && pointer.codehash == keccak256(bytes.concat(hex"00", chunk)),
                "ordered original chunk runtime"
            );
            if (i == 0) require(pointer == first, "backward-compatible first pointer");
        }
        (, General.Receipt memory receipt) = records.general.attestation(hash);
        require(
            receipt.recorder == address(governor)
                && receipt.authorizationDigest == records.general.attestationDigest(r)
                && receipt.authorityQualification
                    == General.AuthorityQualification.GENERAL_SIGNER_CLAIM,
            "full bytes preserve actual Safe claim authority"
        );
    }

    function testCuratorRequiresExactCollectionSafeGrantAndRevocationPreservesHistory() public {
        (Independent.Subject memory subject, General.Request memory r) = _request(31);
        r.attestationType = keccak256("CURATORIAL_STATEMENT");
        bytes memory data = abi.encodeCall(records.general.recordOperatorAttestation, (subject, r));
        _expectSafeFailure(governor, address(records.general), data);
        _grant(0, Families.CURATOR, 3, address(governor), true);
        _expectSafeFailure(governor, address(records.general), data);
        _grant(1, Families.CURATOR, 3, address(governor), true);
        _expectSafeFailure(otherSafe, address(records.general), data);
        vm.prank(vm.addr(keys[0]));
        vm.expectRevert(abi.encodeWithSelector(General.GeneralAuthorityRequired.selector));
        records.general.recordOperatorAttestation(subject, r);
        require(
            executeSafe(governor, keys, address(records.general), 0, data, 0), "exact curator Safe"
        );
        bytes32 hash = records.general
            .latestAttestationHashFor(1, r.attestationType, r.subjectId, address(governor));
        (, General.Receipt memory receipt) = records.general.attestation(hash);
        require(
            receipt.grantCollectionId == 1 && receipt.grantRevision == 1
                && receipt.authorizationClass == 3
                && receipt.authorityQualification
                    == General.AuthorityQualification.CONFIGURED_OPERATOR_CLAIM,
            "exact collection authority receipt"
        );
        _grant(1, Families.CURATOR, 3, address(governor), false);
        r.nonce = 32;
        r.supersedes = hash;
        _expectSafeFailure(
            governor,
            address(records.general),
            abi.encodeCall(records.general.recordOperatorAttestation, (subject, r))
        );
        require(
            !records.general.isAttesterNonceUsed(address(governor), r.nonce),
            "failed write nonce unconsumed"
        );
        (, bytes memory retained) = records.general.recordPayload(hash);
        require(keccak256(retained) == keccak256(r.payload), "revocation preserves original bytes");
    }

    function testSafePreservesFullThreeChunkPayloadHistoryEventAndRevokedWriter() public {
        bytes memory payload = new bytes(24576);
        for (uint256 i; i < payload.length; ++i) {
            payload[i] = bytes1(uint8(i * 37 + i / 8192));
        }
        Original.CollectionRecord memory r = _preservationRecord(payload);
        bytes memory data =
            abi.encodeCall(records.preservation.recordCollectionRecordWithPayload, (1, r, payload));
        _expectSafeFailure(governor, address(records.preservation), data);
        _grant(1, Families.ARCHIVE, 6, address(governor), true);
        _expectSafeFailure(otherSafe, address(records.preservation), data);
        vm.recordLogs();
        require(
            executeSafe(governor, keys, address(records.preservation), 0, data, 0),
            "three chunk Safe write"
        );
        Vm.Log[] memory logs = vm.getRecordedLogs();
        bytes32 hash = records.preservation.deriveCollectionRecordHashFor(address(governor), 1, r);
        (Original.CollectionRecord memory saved, Preservation.Receipt memory receipt) =
            records.preservation.collectionRecord(hash);
        require(
            keccak256(abi.encode(saved)) == keccak256(abi.encode(r))
                && receipt.recorder == address(governor) && receipt.authorizationClass == 6
                && receipt.grantCollectionId == 1 && receipt.grantRevision == 1,
            "original tuple and grant"
        );
        _assertPreservationEvent(logs, r, hash, receipt.recordChainHash);
        require(
            records.preservation.recordPayloadChunkCount(hash) == 3
                && records.preservation.payloadPointerCount(1) == 3,
            "three genuine retained pointers"
        );
        (, bytes memory full) = records.preservation.recordPayload(hash);
        require(full.length == 24576 && keccak256(full) == keccak256(payload), "all original bytes");
        for (uint256 i; i < 3; ++i) {
            (address pointer, bytes32 chunkHash) =
                records.preservation.recordPayloadChunkAt(hash, i);
            require(
                pointer.code.length == 8193 && chunkHash != 0, "actual 8192-byte payload contract"
            );
        }
        (bytes32 chain, uint64 count) = records.preservation.recordChainHash(1, ARCHIVE);
        require(
            count == 1 && chain == receipt.recordChainHash
                && records.preservation.recordHashAt(1, ARCHIVE, 0) == hash,
            "exact append-only history"
        );
        _grant(1, Families.ARCHIVE, 6, address(governor), false);
        r.effectiveAt++;
        _expectSafeFailure(
            governor,
            address(records.preservation),
            abi.encodeCall(records.preservation.recordCollectionRecordWithPayload, (1, r, payload))
        );
        (, full) = records.preservation.recordPayload(hash);
        require(keccak256(full) == keccak256(payload), "grant revocation retains original payload");
        (, count) = records.preservation.recordChainHash(1, ARCHIVE);
        require(count == 1, "revoked writer cannot append history");
    }

    function testRealArtistOp24SafeStatementJoinsOriginalReceiptAndRejectsWrongWitness() public {
        // Original native op24 requires this exact schema identity; the definition here is
        // explicitly a fixture, not a normative personhood or institutional acceptance claim.
        bytes32 nativeSchema = _document(
            "6529STREAM_ARTIST_PERSONHOOD_WAIVER_V1",
            Schema.DocumentKind.SCHEMA,
            bytes("{\"fixture\":true,\"meaning\":\"native op24 composition\"}")
        );
        (, General.Request memory r) = _request(41);
        r.attester = address(artistSafe);
        r.attestationType = keccak256("ARTIST_STATEMENT");
        r.subjectId = fixtureArtistId;
        r.schemaId = nativeSchema;
        r.payload = bytes("original Artist statement through real Safe signatures");
        r.statementURI = _fixtureContentURI(r.payload);
        bytes32 identity = IStreamArtistIdentityRevisionReads(artistSuite.owners[2])
            .operativeIdentityRecord(fixtureArtistId);
        T.Attestation memory original = T.Attestation(
            1, 10, r.subjectId, identity, r.schemaId, keccak256(r.payload), r.statementURI
        );
        T.Authorization memory authorization = _artistAuthorization(true);
        authorization.signature = _artistProof(artists.attestationDigest(original, authorization));
        uint256 index =
            IStreamArtistNativeReceipts(artistSuite.owners[4]).artistNativeReceiptCount();
        r.artistAuthorizationRecordHash =
            artists.recordArtistAttestation(original, authorization, r.payload);
        require(
            IStreamArtistNativeReceipts(artistSuite.owners[4])
                .artistNativeReceiptAt(index)
                .operation == 24,
            "actual original op24 receipt"
        );
        General.ArtistWitness memory witness =
            General.ArtistWitness(10, authorization.nonce + 1, index);
        bytes memory signature = _signature(artistSafe, r);
        vm.expectRevert();
        records.general.recordArtistStatement(r, witness, signature);
        require(
            !records.general.isAttesterNonceUsed(address(artistSafe), r.nonce),
            "bad witness is atomic"
        );
        witness.nonce = authorization.nonce;
        bytes32 hash = records.general.recordArtistStatement(r, witness, signature);
        (, General.Receipt memory receipt) = records.general.attestation(hash);
        StreamGeneralArtistEvidence.Proof memory proof = abi.decode(
            records.general.recordArtistEvidence(hash), (StreamGeneralArtistEvidence.Proof)
        );
        require(
            receipt.authorityQualification == General.AuthorityQualification.NATIVE_ARTIST_HISTORY
                && receipt.artistId == fixtureArtistId && receipt.nativeArtistAuthorityClass == 1
                && receipt.nativeArtistEvidenceHash
                    == keccak256(records.general.recordArtistEvidence(hash)),
            "real native authority remains distinct from general claim"
        );
        require(
            proof.nativeReceipt.recordHash == r.artistAuthorizationRecordHash
                && proof.record.signer == address(artistSafe)
                && proof.attribution == artistSuite.owners[4]
                && keccak256(abi.encode(proof.terms)) == keccak256(abi.encode(original)),
            "original record, account, owner and full terms"
        );
    }

    function testTypedNotarizationRetainsOriginalDefinitionsAndOperativeArtistIdentity() public {
        _document(
            "STREAM_IDENTITY_NOTARIZATION_V1",
            Schema.DocumentKind.SCHEMA,
            bytes(vm.readFile("schemas/records/STREAM_IDENTITY_NOTARIZATION_V1.json"))
        );
        _document(
            "STREAM_IDENTITY_NOTARIZATION_JSON_PROFILE_V1",
            Schema.DocumentKind.CATALOG,
            bytes(vm.readFile("schemas/records/STREAM_IDENTITY_NOTARIZATION_JSON_PROFILE_V1.json"))
        );
        _document(
            "RFC8785_JCS",
            Schema.DocumentKind.CANONICALIZATION,
            bytes(vm.readFile("schemas/museum/account-profile/RFC8785_JCS.json"))
        );
        (Independent.Subject memory subject, General.Request memory r) = _request(51);
        General.Notarization memory n;
        n.artistId = fixtureArtistId;
        n.operativeIdentityRecordHash = IStreamArtistIdentityRevisionReads(artistSuite.owners[2])
            .operativeIdentityRecord(fixtureArtistId);
        StreamOwnerNoticeTypes.Reference memory ref = StreamOwnerNoticeTypes.Reference(
            2,
            keccak256("RAW_BYTES"),
            abi.encode(sha256(bytes("fixture instrument"))),
            _fixtureContentURI(bytes("fixture instrument"))
        );
        n.legalPersonRef = ref;
        n.instrumentRef = ref;
        n.officiatingAuthorityIdentityRef = ref;
        n.verifyingInstitutionIdentityRef = ref;
        r.schemaId = keccak256("STREAM_IDENTITY_NOTARIZATION_V1");
        r.canonicalizationId = keccak256("RFC8785_JCS");
        r.payload = records.general.notarizationPayload(n);
        r.statementURI = _fixtureContentURI(r.payload);
        bytes memory signature = _signature(governor, r);
        vm.expectRevert();
        records.general.recordSignedAttestation(subject, r, signature);
        General.Notarization memory wrong = abi.decode(abi.encode(n), (General.Notarization));
        wrong.operativeIdentityRecordHash = keccak256("unrelated identity");
        General.Request memory changed = abi.decode(abi.encode(r), (General.Request));
        changed.payload = records.general.notarizationPayload(wrong);
        changed.statementURI = _fixtureContentURI(changed.payload);
        bytes memory wrongSignature = _signature(governor, changed);
        vm.expectRevert();
        records.general.recordIdentityNotarization(subject, changed, wrong, wrongSignature);
        require(
            !records.general.isAttesterNonceUsed(address(governor), r.nonce),
            "identity failure leaves nonce free"
        );
        bytes32 hash = records.general.recordIdentityNotarization(subject, r, n, signature);
        (, General.Receipt memory receipt) = records.general.attestation(hash);
        require(
            receipt.identityRegistry == address(artists)
                && receipt.identityRegistryCodeHash == address(artists).codehash
                && receipt.operativeIdentityRecordHash == n.operativeIdentityRecordHash
                && receipt.profileDefinitionHash
                    == keccak256(
                        assemblySchemas.documentBytes(
                            keccak256("STREAM_IDENTITY_NOTARIZATION_JSON_PROFILE_V1")
                        )
                    )
                && receipt.authorityQualification
                    == General.AuthorityQualification.GENERAL_SIGNER_CLAIM,
            "actual identity and definition pins without authority elevation"
        );
    }

    function testCompositionRejectsChangedProductRuntimeAndDifferentAttributionOwner() public {
        StreamFullV1RecordProducts.Configuration memory changed = configuration;
        changed.artistAttribution = artistSuite.owners[3];
        vm.expectRevert();
        this.validate(changed, records);
        vm.etch(address(records.general), hex"00");
        vm.expectRevert(
            abi.encodeWithSelector(
                StreamFullV1RecordProducts.RecordCompositionChanged.selector,
                address(records.general)
            )
        );
        this.validate(configuration, records);
    }

    function validate(
        StreamFullV1RecordProducts.Configuration memory c,
        StreamFullV1RecordProducts.Products memory p
    ) external view {
        StreamFullV1RecordProducts.validate(c, p);
    }

    function _request(uint256 nonce)
        private
        view
        returns (Independent.Subject memory subject, General.Request memory r)
    {
        subject = Independent.Subject(Independent.SubjectKind.COLLECTION, 1, 0, 0);
        r.attester = address(governor);
        r.collectionId = 1;
        r.subjectId = records.general.deriveSubject(subject);
        r.attestationType = keccak256("INSTITUTIONAL_VERIFICATION");
        r.attesterDID = "did:example:fixture-claim";
        r.schemaId = schemaId;
        r.canonicalizationId = assemblySchemas.RAW_BYTES();
        r.payload = bytes("{\"fixture\":true,\"claim\":\"general account assertion\"}");
        r.statementURI = _fixtureContentURI(r.payload);
        r.effectiveAt = uint64(block.timestamp);
        r.nonce = nonce;
        r.deadline = uint64(block.timestamp + 30 days);
    }

    function _signature(OfficialSafe signer, General.Request memory r)
        private
        returns (bytes memory)
    {
        return safeThresholdSignature(
            keys, safeMessageDigest(signer, abi.encode(records.general.attestationDigest(r)))
        );
    }

    function _preservationRecord(bytes memory payload)
        private
        view
        returns (Original.CollectionRecord memory r)
    {
        r.recordType = ARCHIVE;
        r.subjectId = records.general
            .deriveSubject(Independent.Subject(Independent.SubjectKind.COLLECTION, 1, 0, 0));
        r.contentHash =
            Original.HashRef(1, abi.encode(keccak256(payload)), assemblySchemas.RAW_BYTES());
        r.uri = _fixtureContentURI(payload);
        r.schemaId = schemaId;
        r.effectiveAt = uint64(block.timestamp);
    }

    /// @dev CIDv1/raw/sha2-256 names exact supplied bytes; no publication or availability claim.
    function _fixtureContentURI(bytes memory raw) private pure returns (string memory) {
        bytes memory binary = abi.encodePacked(hex"01551220", sha256(raw));
        bytes memory alphabet = "abcdefghijklmnopqrstuvwxyz234567";
        bytes memory encoded = new bytes(59);
        encoded[0] = "b";
        uint256 cursor = 1;
        uint256 word;
        uint256 bits;
        for (uint256 i; i < binary.length; ++i) {
            word = (word << 8) | uint8(binary[i]);
            bits += 8;
            while (bits >= 5) {
                bits -= 5;
                encoded[cursor++] = alphabet[(word >> bits) & 31];
            }
            word &= (uint256(1) << bits) - 1;
        }
        if (bits != 0) encoded[cursor++] = alphabet[(word << (5 - bits)) & 31];
        require(cursor == encoded.length, "complete raw fixture CID");
        return string.concat("ipfs://", string(encoded));
    }

    function _grant(uint256 collection, bytes32 family, uint8 class_, address account, bool enabled)
        private
    {
        (bytes32 scope, bytes32 previous, bytes32 next) =
            assemblyMetadata.familyWriterTransition(collection, family, class_, account, enabled);
        bytes memory data = abi.encodeCall(
            assemblyMetadata.setFamilyWriter, (collection, family, class_, account, enabled)
        );
        _executeStage(
            _single(
                StreamCurrentStackPlan.call(address(assemblyMetadata), data, scope, previous, next),
                data
            ),
            keccak256(abi.encode("record writer", collection, family, account, enabled))
        );
    }

    function _admitArchiveType() private {
        (bytes32 scope, bytes32 previous, bytes32 next) =
            assemblyMetadata.recordTypeTransition(ARCHIVE, Families.ARCHIVE, uint16(1 << 6));
        bytes memory data = abi.encodeCall(
            assemblyMetadata.admitRecordType, (ARCHIVE, Families.ARCHIVE, uint16(1 << 6))
        );
        _executeStage(
            _single(
                StreamCurrentStackPlan.call(address(assemblyMetadata), data, scope, previous, next),
                data
            ),
            ARCHIVE
        );
    }

    function _assertGeneralEvent(Vm.Log[] memory logs, General.Request memory r, bytes32 hash)
        private
        view
    {
        bytes32 topic = keccak256(
            "GeneralAttestationRecorded(uint256,bytes32,bytes32,bytes32,address,uint8,uint8,bytes32,bytes32,uint16)"
        );
        uint256 found;
        for (uint256 i; i < logs.length; ++i) {
            if (
                logs[i].emitter != address(records.general) || logs[i].topics.length != 4
                    || logs[i].topics[0] != topic
            ) continue;
            require(
                logs[i].topics[1] == bytes32(r.collectionId)
                    && logs[i].topics[2] == r.attestationType && logs[i].topics[3] == r.subjectId,
                "general indexed subject"
            );
            (
                bytes32 recordHash,
                address attester,
                General.VerificationClass class_,
                General.AuthorityQualification authority,
                bytes32 supersedes,
                bytes32 chain,
                uint16 version
            ) = abi.decode(
                logs[i].data,
                (
                    bytes32,
                    address,
                    General.VerificationClass,
                    General.AuthorityQualification,
                    bytes32,
                    bytes32,
                    uint16
                )
            );
            require(
                recordHash == hash && attester == r.attester
                    && class_ == General.VerificationClass.SIGNER_VERIFIED
                    && authority == General.AuthorityQualification.GENERAL_SIGNER_CLAIM
                    && supersedes == r.supersedes && chain != 0 && version == 1,
                "general full event"
            );
            ++found;
        }
        require(found == 1, "one general event");
    }

    function _assertPreservationEvent(
        Vm.Log[] memory logs,
        Original.CollectionRecord memory r,
        bytes32 hash,
        bytes32 chain
    ) private view {
        bytes32 topic = keccak256(
            "CollectionRecordRecorded(uint256,bytes32,bytes32,(bytes32,bytes32,(uint16,bytes,bytes32),string,bytes32,bytes32,(uint16,bytes,bytes32),uint64),bytes32,bytes32,address,bytes32,uint16)"
        );
        uint256 found;
        for (uint256 i; i < logs.length; ++i) {
            if (
                logs[i].emitter != address(records.preservation) || logs[i].topics.length != 4
                    || logs[i].topics[0] != topic
            ) continue;
            require(
                logs[i].topics[1] == bytes32(uint256(1)) && logs[i].topics[2] == r.recordType
                    && logs[i].topics[3] == r.subjectId,
                "preservation indexed subject"
            );
            (
                Original.CollectionRecord memory saved,
                bytes32 recordHash,
                bytes32 recordChain,
                address recorder,
                bytes32 class_,
                uint16 version
            ) = abi.decode(
                logs[i].data,
                (Original.CollectionRecord, bytes32, bytes32, address, bytes32, uint16)
            );
            require(
                keccak256(abi.encode(saved)) == keccak256(abi.encode(r)) && recordHash == hash
                    && recordChain == chain && recorder == address(governor) && class_ != 0
                    && version == 1,
                "preservation complete event"
            );
            ++found;
        }
        require(found == 1, "one preservation event");
    }

    function _document(string memory name, Schema.DocumentKind kind, bytes memory payload)
        private
        returns (bytes32 id)
    {
        (bytes32 hash,) = assemblyStore.publishChunk(payload);
        bytes32[] memory chunks = new bytes32[](1);
        chunks[0] = hash;
        Schema.DocumentSpec memory spec = Schema.DocumentSpec(
            name, kind, hash, assemblySchemas.RAW_BYTES(), 0, "", uint32(payload.length)
        );
        (bytes32 scope, bytes32 previous, bytes32 next) =
            assemblySchemas.registrationTransition(spec, chunks);
        bytes memory data = abi.encodeCall(assemblySchemas.registerDocument, (spec, chunks));
        _executeStage(
            _single(
                StreamCurrentStackPlan.call(address(assemblySchemas), data, scope, previous, next),
                data
            ),
            keccak256(bytes(name))
        );
        id = keccak256(bytes(name));
        require(
            keccak256(assemblySchemas.documentBytes(id)) == hash, "exact original document bytes"
        );
    }

    function _extendCatalog() private {
        GovernanceActionPolicyEntry[] memory rows =
            StreamFullV1RecordProducts.operatingPolicies(configuration, records);
        for (uint256 i = 1; i < rows.length; ++i) {
            for (uint256 j = i; j > 0 && _key(rows[j - 1]) > _key(rows[j]); --j) {
                (rows[j - 1], rows[j]) = (rows[j], rows[j - 1]);
            }
        }
        StreamGovernanceCatalogStagePlan.Inventory memory inventory =
            StreamGovernanceCatalogStagePlan.inventory(executor, rows);
        (address payload, StreamSystemManifestUpdate memory update) =
            _publication("record policies");
        (GenesisBatch memory batch, uint256 count) = StreamGovernanceCatalogStagePlan.nextBatch(
            inventory,
            StreamGovernanceCatalogStagePlan.inventoryHash(inventory),
            0,
            manifest,
            payload,
            update
        );
        _executeStage(batch, keccak256("original record catalog"));
        require(count == rows.length, "complete bounded policy addition");
    }

    function _registerModules() private {
        (GovernanceCall[] memory calls, bytes[] memory datas) = StreamCurrentStackPlan.registrationCalls(
            registry, StreamFullV1RecordProducts.registrations(configuration, records, 500000)
        );
        GenesisBatch memory batch;
        batch.actionClass = 1;
        batch.calls = new GovernanceCall[](calls.length + 1);
        batch.callDatas = new bytes[](calls.length + 1);
        for (uint256 i; i < calls.length; ++i) {
            batch.calls[i] = calls[i];
            batch.callDatas[i] = datas[i];
        }
        (address payload, StreamSystemManifestUpdate memory update) =
            _publication("original record hosts");
        (batch.calls[calls.length], batch.callDatas[calls.length]) =
            StreamGenesisManifestPlan.publicationCall(
                manifest, payload, update, StreamGenesisManifestPlan.readAggregate(manifest).modules
            );
        _executeStage(batch, keccak256("original record module rows"));
    }

    function _publication(string memory purpose)
        private
        returns (address payload, StreamSystemManifestUpdate memory update)
    {
        StreamSystemManifest.AggregateState memory current =
            StreamGenesisManifestPlan.readAggregate(manifest);
        bytes32 hash;
        (payload, hash) = StreamGenesisManifestPlan.writePayload(
            bytes(string.concat("{\"fixture\":true,\"purpose\":\"", purpose, "\"}"))
        );
        update = StreamSystemManifestUpdate(
            hash,
            "urn:fixture:record-genesis",
            current.discovery.eventCatalogHash,
            current.discovery.compatibilityMatrixHash,
            current.discovery.numericIdCatalogHash,
            current.discovery.schemaCatalogHash,
            current.discovery.canonicalizationCatalogHash,
            current.discovery.specBundleHash,
            current.discovery.reconstructionClientHash
        );
    }

    function _single(GovernanceCall memory operation, bytes memory data)
        private
        pure
        returns (GenesisBatch memory batch)
    {
        batch.actionClass = 1;
        batch.calls = new GovernanceCall[](1);
        batch.callDatas = new bytes[](1);
        batch.calls[0] = operation;
        batch.callDatas[0] = data;
    }

    function _policy(address target, bytes4 selector)
        private
        view
        returns (GovernanceActionPolicyEntry memory)
    {
        return GovernanceActionPolicyEntry(
            1, target, selector, target.codehash, DEPLOYMENT_HASH, 1, 0, 0, bytes32(0)
        );
    }

    function _key(GovernanceActionPolicyEntry memory row) private pure returns (bytes32) {
        return keccak256(abi.encode(row.actionClass, row.target, row.selector));
    }

    function _expectSafeFailure(OfficialSafe account, address target, bytes memory data) private {
        uint256 nonce = account.nonce();
        vm.expectRevert();
        this.safeCall(account, target, data);
        require(account.nonce() == nonce, "Safe nonce rolls back");
    }

    function safeCall(OfficialSafe account, address target, bytes memory data)
        external
        returns (bool)
    {
        return executeSafe(account, keys, target, 0, data, 0);
    }

    function _installGovernor() private {
        (address prior, bytes32 hash, uint64 revision) = executor.governanceRootState();
        bytes memory data = abi.encodeCall(
            executor.rotateGovernanceRoot, (address(governor), address(governor).codehash)
        );
        uint64 ready = uint64(block.timestamp + executor.minimumDelay(3));
        GovernanceActionRequest memory request = GovernanceActionRequest(
            3,
            address(executor),
            0,
            executor.rotateGovernanceRoot.selector,
            data,
            keccak256(
                abi.encode(
                    keccak256("6529STREAM_GOVERNANCE_ROOT_SCOPE_V1"),
                    block.chainid,
                    address(executor)
                )
            ),
            _rootState(prior, hash, revision),
            _rootState(address(governor), address(governor).codehash, revision + 1),
            ready,
            ready + 7 days,
            keccak256("full-v1 actual Safe root"),
            "urn:6529stream:genesis:Safe-root",
            DEPLOYMENT_HASH
        );
        bytes memory result = governanceRoot.execute(
            address(executor), 0, abi.encodeCall(executor.scheduleGovernanceAction, (request))
        );
        vm.warp(ready);
        executor.executeGovernanceAction(abi.decode(result, (bytes32)), data);
    }

    function _rootState(address root, bytes32 hash, uint64 revision)
        private
        view
        returns (bytes32)
    {
        return keccak256(
            abi.encode(
                keccak256("6529STREAM_GOVERNANCE_ROOT_STATE_V1"),
                block.chainid,
                address(executor),
                root,
                hash,
                revision
            )
        );
    }

    function _executeStage(GenesisBatch memory batch, bytes32 stage) private {
        uint64 ready = uint64(block.timestamp + executor.minimumDelay(batch.actionClass));
        StreamGovernanceStagePlan.Plan memory plan = StreamGovernanceStagePlan.build(
            executor,
            stage,
            batch,
            ready,
            ready + 7 days,
            stage,
            "urn:6529stream:genesis:composed-stage",
            DEPLOYMENT_HASH
        );
        bytes32 saved = StreamGovernanceStagePlan.planHash(plan);
        executor.publishGovernanceCallData(batch.callDatas);
        StreamGovernanceStagePlan.NextCall memory next =
            StreamGovernanceStagePlan.scheduling(plan, saved);
        vm.recordLogs();
        require(
            executeSafe(governor, keys, next.target, next.value, next.data, 0),
            "real Safe schedules"
        );
        Vm.Log[] memory logs = vm.getRecordedLogs();
        bytes32 topic = keccak256(
            "GovernanceActionScheduled(uint16,bytes32,uint8,address,uint256,bytes4,bytes32,bytes32,bytes32,bytes32,uint64,uint64,uint256,address,bytes32,string,bytes32)"
        );
        bytes32 action;
        for (uint256 i; i < logs.length; ++i) {
            if (
                logs[i].emitter == address(executor) && logs[i].topics.length == 4
                    && logs[i].topics[0] == topic
            ) {
                require(action == 0, "one observed action");
                action = logs[i].topics[1];
            }
        }
        require(action != 0, "actual receipt action ID");
        if (ready > block.timestamp) {
            (bool early,) =
                address(this).call(abi.encodeCall(this.executeSaved, (plan, action, saved)));
            require(!early, "execution before delay rejected");
            vm.warp(ready);
        }
        require(
            StreamGovernanceStagePlan.execute(plan, action, saved),
            "permissionless delayed execution"
        );
    }

    function executeSaved(StreamGovernanceStagePlan.Plan memory plan, bytes32 action, bytes32 saved)
        external
        returns (bool)
    {
        return StreamGovernanceStagePlan.execute(plan, action, saved);
    }
}
