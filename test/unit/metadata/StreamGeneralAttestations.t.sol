// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./StreamCollectionAttestations.t.sol";
import {
    StreamGeneralAttestations
} from "../../../smart-contracts/domains/metadata/StreamGeneralAttestations.sol";
import {
    StreamOwnerNoticeTypes
} from "../../../smart-contracts/interfaces/stream/metadata/StreamOwnerNoticeTypes.sol";
import {
    IStreamGeneralAttestations
} from "../../../smart-contracts/interfaces/stream/metadata/IStreamGeneralAttestations.sol";
import {
    StreamGeneralArtistEvidence,
    StreamArtistHashes,
    StreamArtistHistoryTypes,
    StreamArtistAttestationTypes,
    StreamArtistOnboardingTypes
} from "../../../smart-contracts/domains/metadata/StreamGeneralArtistEvidence.sol";
import {
    StreamGeneralAttestationDefinitions
} from "../../../smart-contracts/domains/metadata/StreamGeneralAttestationDefinitions.sol";

import {
    StreamGeneralAttestationSignatures
} from "../../../smart-contracts/domains/metadata/StreamGeneralAttestationSignatures.sol";

contract GeneralSignatureGasHarness {
    function verify(address signer, bytes32 digest, bytes calldata signature, uint256 cap)
        external
        view
        returns (bytes32)
    {
        return StreamGeneralAttestationSignatures.verify(signer, digest, signature, cap);
    }
}

/// @dev Explicit synthetic read boundaries; these fixtures are not actual-chain evidence.
contract GeneralCoreBoundary is IndependentCoreBoundary {
    mapping(bytes32 => address) private targets;

    function select(bytes32 kind, address target) external {
        targets[kind] = target;
    }

    function getSatellitePointer(bytes32 kind)
        external
        view
        returns (address, bytes32, bool, bytes32, bytes4, address, uint8, bytes32, bytes32, uint64)
    {
        address t = targets[kind];
        return
            (t, t.codehash, false, bytes32(0), bytes4(0), address(0), 0, bytes32(0), bytes32(0), 1);
    }
}

contract GeneralMetadataBoundary {
    address public immutable core;
    mapping(uint256 => mapping(address => bool)) private grants;

    constructor(address c) {
        core = c;
    }

    function set(uint256 collection, address who, bool enabled) external {
        grants[collection][who] = enabled;
    }

    function familyWriter(uint256 collection, bytes32 family, uint8 class_, address who)
        external
        view
        returns (bool, uint64)
    {
        return (
            family == keccak256("6529STREAM_RECORD_FAMILY_CURATOR_V1") && class_ == 3
                && grants[collection][who],
            1
        );
    }
}

contract GeneralArtistBoundary {
    address public immutable core;
    address public currentSigner;
    bytes32 public currentIdentity = keccak256("operative identity");
    mapping(bytes32 => StreamArtistOnboardingTypes.AttestationRecord) private records;
    mapping(bytes32 => StreamArtistAttestationTypes.Association) private associations;
    mapping(bytes32 => uint8) private classes;
    mapping(bytes32 => bytes) private statements;
    StreamArtistHistoryTypes.Receipt[] private receipts;

    constructor(address c) {
        core = c;
    }

    function operationCoordinator() external view returns (address) {
        return address(this);
    }

    function artistRegistry() external view returns (address) {
        return address(this);
    }

    function suiteConfiguration()
        external
        view
        returns (StreamArtistOnboardingTypes.SuiteConfiguration memory s)
    {
        s.registry = address(this);
        s.core = core;
        s.owners[4] = address(this);
    }

    function operativeIdentityRecord(bytes32) external view returns (bytes32) {
        return currentIdentity;
    }

    function rotate(address who, bytes32 identity) external {
        currentSigner = who;
        currentIdentity = identity;
    }

    function seed(
        StreamArtistOnboardingTypes.Attestation calldata p,
        address signer,
        uint8 class_,
        uint256 nonce,
        uint64 signedAt,
        bytes calldata statement
    ) external returns (bytes32 hash) {
        bytes32 id = keccak256("artist fixture");
        hash = StreamArtistHashes.attestationRecordForAuthority(
            StreamArtistHashes.Environment(block.chainid, address(this), core, address(0)),
            p,
            id,
            signer,
            class_,
            nonce,
            signedAt
        );
        records[hash] = StreamArtistOnboardingTypes.AttestationRecord(
            hash, p.subjectStateHash, p.schemaId, p.statementHash, 1, signedAt, signer
        );
        associations[hash] = StreamArtistAttestationTypes.Association(
            id,
            keccak256("binding"),
            1,
            class_ == 2 ? keccak256("original revoked delegation") : bytes32(0),
            StreamArtistAttestationTypes.Fact(
                address(this), address(this).codehash, p.subjectId, p.subjectStateHash
            )
        );
        classes[hash] = class_;
        statements[p.statementHash] = statement;
        receipts.push(StreamArtistHistoryTypes.Receipt(24, id, p.collectionId, hash));
    }

    function corruptOperation(uint16 op) external {
        receipts[0].operation = op;
    }

    function attestationRecord(bytes32 hash)
        external
        view
        returns (StreamArtistOnboardingTypes.AttestationRecord memory)
    {
        return records[hash];
    }

    function attestationAssociation(bytes32 hash)
        external
        view
        returns (StreamArtistAttestationTypes.Association memory)
    {
        return associations[hash];
    }

    function attestationAuthorityClass(bytes32 hash) external view returns (uint8) {
        return classes[hash];
    }

    function statementBytes(bytes32 hash) external view returns (bytes memory) {
        return statements[hash];
    }

    function artistNativeReceiptAt(uint256 index)
        external
        view
        returns (StreamArtistHistoryTypes.Receipt memory)
    {
        return receipts[index];
    }
}

contract GeneralGasSafeBoundary {
    function isValidSignature(bytes32, bytes memory) external view returns (bytes4) {
        return gasleft() >= 180000 ? bytes4(0x1626ba7e) : bytes4(0xffffffff);
    }
}

contract StreamGeneralAttestationsTest is IndependentAttestationTestBase {
    StreamGeneralAttestations internal general;
    GeneralCoreBoundary internal generalCore;
    GeneralMetadataBoundary internal metadata;
    GeneralArtistBoundary internal artist;

    function setUp() public override {
        super.setUp();
        generalCore = new GeneralCoreBoundary();
        metadata = new GeneralMetadataBoundary(address(generalCore));
        artist = new GeneralArtistBoundary(address(generalCore));
        generalCore.select(keccak256("COLLECTION_METADATA"), address(metadata));
        generalCore.select(keccak256("ARTIST_REGISTRY"), address(artist));
        general = new StreamGeneralAttestations(_generalConfiguration());
    }

    function _generalConfiguration()
        internal
        view
        returns (StreamGeneralAttestations.Configuration memory c)
    {
        c.core = address(generalCore);
        c.schemas = address(schemas);
        c.metadata = address(metadata);
        c.artistRegistry = address(artist);
        c.artistAttribution = address(artist);
        c.executor = address(executor);
        c.deploymentManifestHash = keccak256("general deployment fixture");
        c.manifestURI = "ipfs://general-fixture";
        c.manifestHash = keccak256("general manifest fixture");
        c.signatureGas = IStreamGasParameterHost.GasParameterConfig(
            "METADATA_ERC1271_VERIFY_GAS", 150000, 90000, 2
        );
        c.dependencyReadGas = IStreamGasParameterHost.GasParameterConfig(
            "METADATA_DEPENDENCY_READ_GAS", 1000000, 50000, 2
        );
    }

    function _generalRequest(uint256 nonce)
        internal
        view
        returns (
            IStreamCollectionAttestations.Subject memory subject,
            IStreamGeneralAttestations.Request memory r
        )
    {
        subject = IStreamCollectionAttestations.Subject(
            IStreamCollectionAttestations.SubjectKind.COLLECTION, 1, 0, 0
        );
        r.attester = signer;
        r.collectionId = 1;
        r.subjectId = general.deriveSubject(subject);
        r.attestationType = keccak256("INSTITUTIONAL_VERIFICATION");
        r.attesterDID = "did:example:claim-only";
        r.schemaId = schemaId;
        r.canonicalizationId = keccak256("RAW_BYTES");
        r.statementURI = "ipfs://original-statement";
        r.payload = bytes('{"claim":"synthetic general attestation"}');
        r.effectiveAt = 900;
        r.nonce = nonce;
        r.deadline = 2000;
    }

    function testSignedOriginalBytesBundleAndNoInstitutionUpgrade() public {
        (
            IStreamCollectionAttestations.Subject memory s,
            IStreamGeneralAttestations.Request memory r
        ) = _generalRequest(1);
        vm.recordLogs();
        bytes32 hash = general.recordSignedAttestation(s, r, _sign(general.attestationDigest(r)));
        (
            IStreamGeneralAttestations.Attestation memory value,
            IStreamGeneralAttestations.Receipt memory receipt
        ) = general.attestation(hash);
        require(
            value.attester == signer && receipt.recorder == signer
                && receipt.verificationClass
                    == IStreamGeneralAttestations.VerificationClass.SIGNER_VERIFIED
                && receipt.authorityQualification
                    == IStreamGeneralAttestations.AuthorityQualification.GENERAL_SIGNER_CLAIM,
            "claim classification"
        );
        require(
            receipt.signatureScheme == keccak256("EIP712") && receipt.authorizationClass == 0
                && receipt.authorityFamily == 0,
            "no factual institution role"
        );
        (address pointer, bytes memory payload) = general.recordPayload(hash);
        require(
            keccak256(payload) == keccak256(r.payload)
                && pointer.codehash == keccak256(bytes.concat(hex"00", r.payload)),
            "state bytes"
        );
        (, bytes memory bundle) = general.recordSignatureBundle(hash);
        require(
            bundle.length <= 8192 && keccak256(bundle) == receipt.signatureBundleHash
                && general.payloadPointerCount(1) == 2,
            "full signature carrier"
        );
        require(
            general.recordHashAt(1, r.attestationType, 0) == hash && receipt.recordIndex == 0
                && receipt.recordChainHash != 0,
            "enumeration"
        );
        Vm.Log[] memory logs = vm.getRecordedLogs();
        require(
            logs[logs.length - 1].emitter == address(general)
                && logs[logs.length - 1].topics[0]
                    == keccak256(
                        "GeneralAttestationRecorded(uint256,bytes32,bytes32,bytes32,address,uint8,uint8,bytes32,bytes32,uint16)"
                    ),
            "event"
        );
    }

    function testDirectCallerMustStillSupplySignature() public {
        (
            IStreamCollectionAttestations.Subject memory s,
            IStreamGeneralAttestations.Request memory r
        ) = _generalRequest(1);
        vm.prank(signer);
        vm.expectRevert();
        general.recordSignedAttestation(s, r, "");
        require(!general.isAttesterNonceUsed(signer, 1), "rejected nonce untouched");
    }

    function testWrongTypeSchemaChainHostAndExpiredReject() public {
        (
            IStreamCollectionAttestations.Subject memory s,
            IStreamGeneralAttestations.Request memory r
        ) = _generalRequest(1);
        bytes memory signature = _sign(general.attestationDigest(r));
        r.attestationType = keccak256("ESTATE_VERIFICATION");
        vm.expectRevert();
        general.recordSignedAttestation(s, r, signature);
        r.attestationType = keccak256("INSTITUTIONAL_VERIFICATION");
        bytes32 secondSchema = _register(
            "STREAM_GENERAL_SECOND_FIXTURE", IStreamSchemaRegistry.DocumentKind.SCHEMA, bytes("{}")
        );
        r.schemaId = secondSchema;
        vm.expectRevert();
        general.recordSignedAttestation(s, r, signature);
        r.schemaId = schemaId;
        uint256 previous = block.chainid;
        vm.chainId(previous + 1);
        vm.expectRevert();
        general.recordSignedAttestation(s, r, signature);
        vm.chainId(previous);
        StreamGeneralAttestations other = new StreamGeneralAttestations(_generalConfiguration());
        vm.expectRevert();
        other.recordSignedAttestation(s, r, signature);
        vm.warp(2001);
        vm.expectRevert();
        general.recordSignedAttestation(s, r, signature);
        require(!general.isAttesterNonceUsed(signer, 1), "failed writes atomic");
    }

    function testReplayAndSignerScopedSupersession() public {
        (
            IStreamCollectionAttestations.Subject memory s,
            IStreamGeneralAttestations.Request memory r
        ) = _generalRequest(1);
        bytes memory signature = _sign(general.attestationDigest(r));
        bytes32 first = general.recordSignedAttestation(s, r, signature);
        vm.expectRevert();
        general.recordSignedAttestation(s, r, signature);
        r.nonce = 2;
        signature = _sign(general.attestationDigest(r));
        vm.expectRevert();
        general.recordSignedAttestation(s, r, signature);
        r.supersedes = first;
        bytes32 second = general.recordSignedAttestation(s, r, _sign(general.attestationDigest(r)));
        require(
            general.latestAttestationHashFor(1, r.attestationType, r.subjectId, signer) == second,
            "own head"
        );
        r.attester = vm.addr(0xBEEF);
        r.nonce = 1;
        (uint8 v, bytes32 a, bytes32 b) = vm.sign(0xBEEF, general.attestationDigest(r));
        vm.expectRevert();
        general.recordSignedAttestation(s, r, abi.encodePacked(a, b, v));
        r.supersedes = 0;
        (v, a, b) = vm.sign(0xBEEF, general.attestationDigest(r));
        general.recordSignedAttestation(s, r, abi.encodePacked(a, b, v));
        require(general.recordHashAt(1, r.attestationType, 0) == first, "append only original");
    }

    function testSafe1271ExactReturnAndFailureRollback() public {
        (
            IStreamCollectionAttestations.Subject memory s,
            IStreamGeneralAttestations.Request memory r
        ) = _generalRequest(1);
        IndependentSignatureBoundary safe = new IndependentSignatureBoundary();
        r.attester = address(safe);
        bytes32 digest = general.attestationDigest(r);
        for (uint256 mode = 1; mode <= 5; ++mode) {
            safe.set(digest, mode);
            vm.expectRevert();
            general.recordSignedAttestation(s, r, hex"0102");
            require(!general.isAttesterNonceUsed(address(safe), 1), "1271 failure consumes nothing");
        }
        safe.set(digest, 0);
        bytes32 hash = general.recordSignedAttestation(s, r, hex"0102");
        (, IStreamGeneralAttestations.Receipt memory receipt) = general.attestation(hash);
        require(receipt.signatureScheme == keccak256("ERC1271"), "Safe class");
    }

    function testOperatorExactCollectionGrantAndSeparateRecorder() public {
        (
            IStreamCollectionAttestations.Subject memory s,
            IStreamGeneralAttestations.Request memory r
        ) = _generalRequest(1);
        r.attestationType = keccak256("CURATORIAL_STATEMENT");
        metadata.set(0, address(this), true);
        vm.expectRevert();
        general.recordOperatorAttestation(s, r);
        metadata.set(2, address(this), true);
        vm.expectRevert();
        general.recordOperatorAttestation(s, r);
        metadata.set(1, address(this), true);
        bytes32 hash = general.recordOperatorAttestation(s, r);
        (
            IStreamGeneralAttestations.Attestation memory value,
            IStreamGeneralAttestations.Receipt memory receipt
        ) = general.attestation(hash);
        require(
            value.attester == signer && receipt.recorder == address(this)
                && receipt.verificationClass
                    == IStreamGeneralAttestations.VerificationClass.OPERATOR_ASSERTED
                && receipt.authorizationClass == 3 && receipt.grantCollectionId == 1
                && receipt.grantRevision == 1,
            "exact operator provenance"
        );
        (address pointer, bytes memory bundle) = general.recordSignatureBundle(hash);
        require(
            pointer == address(0) && bundle.length == 0 && receipt.signatureScheme == 0,
            "no thirdparty signature inference"
        );
        require(
            general.isAttesterNonceUsed(address(this), 1)
                && !general.isAttesterNonceUsed(signer, 1),
            "recorder nonce"
        );
        r.nonce = 2;
        r.supersedes = hash;
        metadata.set(1, address(this), false);
        vm.expectRevert();
        general.recordOperatorAttestation(s, r);
        r.attestationType = keccak256("INSTITUTIONAL_VERIFICATION");
        vm.expectRevert();
        general.recordOperatorAttestation(s, r);
    }

    function testNativeArtistRetainsDelegationAfterRotationAndRejectsSubjectForgery() public {
        (, IStreamGeneralAttestations.Request memory r) = _generalRequest(1);
        r.attestationType = keccak256("ARTIST_STATEMENT");
        r.subjectId = keccak256("original native subject");
        StreamArtistOnboardingTypes.Attestation memory original =
            StreamArtistOnboardingTypes.Attestation(
                1,
                10,
                r.subjectId,
                keccak256("native state"),
                r.schemaId,
                keccak256(r.payload),
                r.statementURI
            );
        r.artistAuthorizationRecordHash = artist.seed(original, signer, 2, 77, 800, r.payload);
        IStreamGeneralAttestations.ArtistWitness memory witness =
            IStreamGeneralAttestations.ArtistWitness(10, 77, 0);
        artist.rotate(address(0x999), keccak256("rotated identity"));
        bytes memory signature = _sign(general.attestationDigest(r));
        witness.nonce = 78;
        vm.expectRevert();
        general.recordArtistStatement(r, witness, signature);
        witness.nonce = 77;
        artist.corruptOperation(6);
        vm.expectRevert();
        general.recordArtistStatement(r, witness, signature);
        artist.corruptOperation(24);
        r.subjectId = keccak256("forged subject");
        bytes memory forgedSignature = _sign(general.attestationDigest(r));
        vm.expectRevert();
        general.recordArtistStatement(r, witness, forgedSignature);
        r.subjectId = original.subjectId;
        bytes32 hash = general.recordArtistStatement(r, witness, signature);
        (, IStreamGeneralAttestations.Receipt memory receipt) = general.attestation(hash);
        require(
            receipt.authorityQualification
                    == IStreamGeneralAttestations.AuthorityQualification.NATIVE_ARTIST_HISTORY
                && receipt.nativeArtistAuthorityClass == 2
                && receipt.nativeArtistEvidenceHash
                    == keccak256(general.recordArtistEvidence(hash)),
            "original delegated history"
        );
        StreamGeneralArtistEvidence.Proof memory proof =
            abi.decode(general.recordArtistEvidence(hash), (StreamGeneralArtistEvidence.Proof));
        require(
            proof.association.delegation != 0 && proof.record.signer == signer
                && proof.terms.subjectId == original.subjectId,
            "full original terms"
        );
        vm.expectRevert();
        general.recordSubject(hash);
    }

    function _notarization()
        internal
        view
        returns (IStreamGeneralAttestations.Notarization memory n)
    {
        n.artistId = keccak256("artist fixture");
        n.operativeIdentityRecordHash = artist.currentIdentity();
        StreamOwnerNoticeTypes.Reference memory ref = StreamOwnerNoticeTypes.Reference(
            2,
            keccak256("RAW_BYTES"),
            abi.encode(keccak256("instrument fixture")),
            "ipfs://evidence-fixture"
        );
        n.legalPersonRef = ref;
        n.instrumentRef = ref;
        n.officiatingAuthorityIdentityRef = ref;
        n.verifyingInstitutionIdentityRef = ref;
    }

    function _registerNotarization() internal {
        _register(
            "STREAM_IDENTITY_NOTARIZATION_V1",
            IStreamSchemaRegistry.DocumentKind.SCHEMA,
            bytes(vm.readFile("schemas/records/STREAM_IDENTITY_NOTARIZATION_V1.json"))
        );
        _register(
            "STREAM_IDENTITY_NOTARIZATION_JSON_PROFILE_V1",
            IStreamSchemaRegistry.DocumentKind.CATALOG,
            bytes(vm.readFile("schemas/records/STREAM_IDENTITY_NOTARIZATION_JSON_PROFILE_V1.json"))
        );
        _register(
            "RFC8785_JCS",
            IStreamSchemaRegistry.DocumentKind.CANONICALIZATION,
            bytes(vm.readFile("schemas/museum/account-profile/RFC8785_JCS.json"))
        );
    }

    function testTypedNotarizationPinsAndIdentityRotation() public {
        _registerNotarization();
        (
            IStreamCollectionAttestations.Subject memory s,
            IStreamGeneralAttestations.Request memory r
        ) = _generalRequest(1);
        IStreamGeneralAttestations.Notarization memory n = _notarization();
        r.schemaId = keccak256("STREAM_IDENTITY_NOTARIZATION_V1");
        r.canonicalizationId = keccak256("RFC8785_JCS");
        r.payload = general.notarizationPayload(n);
        bytes memory signature = _sign(general.attestationDigest(r));
        vm.expectRevert();
        general.recordSignedAttestation(s, r, signature);
        artist.rotate(signer, keccak256("changed identity"));
        vm.expectRevert();
        general.recordIdentityNotarization(s, r, n, signature);
        require(!general.isAttesterNonceUsed(signer, 1), "late identity failure atomic");
        artist.rotate(signer, n.operativeIdentityRecordHash);
        bytes32 hash = general.recordIdentityNotarization(s, r, n, signature);
        (, IStreamGeneralAttestations.Receipt memory receipt) = general.attestation(hash);
        require(
            receipt.profileDefinitionHash == StreamGeneralAttestationDefinitions.PROFILE_HASH
                && receipt.operativeIdentityRecordHash == n.operativeIdentityRecordHash
                && receipt.identityRegistry == address(artist),
            "typed evidence pins"
        );
    }

    function testNotarizationWrongRegisteredProfileFailsAfterSignatureWithoutNonce() public {
        _register(
            "STREAM_IDENTITY_NOTARIZATION_V1",
            IStreamSchemaRegistry.DocumentKind.SCHEMA,
            bytes(vm.readFile("schemas/records/STREAM_IDENTITY_NOTARIZATION_V1.json"))
        );
        _register(
            "STREAM_IDENTITY_NOTARIZATION_JSON_PROFILE_V1",
            IStreamSchemaRegistry.DocumentKind.CATALOG,
            bytes('{"wrong":true}')
        );
        _register(
            "RFC8785_JCS",
            IStreamSchemaRegistry.DocumentKind.CANONICALIZATION,
            bytes(vm.readFile("schemas/museum/account-profile/RFC8785_JCS.json"))
        );
        (
            IStreamCollectionAttestations.Subject memory s,
            IStreamGeneralAttestations.Request memory r
        ) = _generalRequest(1);
        IStreamGeneralAttestations.Notarization memory n = _notarization();
        r.schemaId = keccak256("STREAM_IDENTITY_NOTARIZATION_V1");
        r.canonicalizationId = keccak256("RFC8785_JCS");
        r.payload = general.notarizationPayload(n);
        bytes memory signature = _sign(general.attestationDigest(r));
        vm.expectRevert();
        general.recordIdentityNotarization(s, r, n, signature);
        require(
            !general.isAttesterNonceUsed(signer, 1) && general.payloadPointerCount(1) == 0,
            "late definition failure atomic"
        );
    }

    function testBoundedGasAndSignatureConfiguration() public {
        StreamGeneralAttestations.Configuration memory c = _generalConfiguration();
        c.signatureGas.floor = 89999;
        vm.expectRevert();
        new StreamGeneralAttestations(c);
        (
            IStreamCollectionAttestations.Subject memory s,
            IStreamGeneralAttestations.Request memory r
        ) = _generalRequest(1);
        IndependentSignatureBoundary safe = new IndependentSignatureBoundary();
        r.attester = address(safe);
        safe.set(general.attestationDigest(r), 0);
        (bool ok,) = address(general).call{ gas: 150000 }(
            abi.encodeCall(general.recordSignedAttestation, (s, r, hex"01"))
        );
        require(!ok && !general.isAttesterNonceUsed(address(safe), 1), "parent gas fails closed");
        vm.expectRevert();
        general.recordSignedAttestation(s, r, new bytes(4097));
    }

    function testAllSixReferenceAlgorithmsAndClosedBounds() public {
        IStreamGeneralAttestations.Notarization memory n = _notarization();
        for (uint16 algorithm = 1; algorithm <= 6; ++algorithm) {
            n.instrumentRef.algorithm = algorithm;
            n.instrumentRef.digest = (algorithm == 4 || algorithm == 5)
                ? bytes(hex"112233")
                : abi.encode(keccak256("full hash"));
            bytes memory payload = general.notarizationPayload(n);
            require(payload.length > 100 && payload.length <= 8192, "all six reference encodings");
        }
        n.instrumentRef.algorithm = 0;
        vm.expectRevert();
        general.notarizationPayload(n);
        n.instrumentRef.algorithm = 7;
        vm.expectRevert();
        general.notarizationPayload(n);
        n.instrumentRef.algorithm = 4;
        n.instrumentRef.digest = new bytes(129);
        vm.expectRevert();
        general.notarizationPayload(n);
        n.instrumentRef.digest = "";
        vm.expectRevert();
        general.notarizationPayload(n);
        n.instrumentRef.algorithm = 1;
        n.instrumentRef.digest = new bytes(31);
        vm.expectRevert();
        general.notarizationPayload(n);
        n.instrumentRef.digest = new bytes(32);
        n.instrumentRef.uri = "javascript:claim";
        vm.expectRevert();
        general.notarizationPayload(n);
        bytes memory longURI = new bytes(2049);
        for (uint256 i; i < longURI.length; ++i) {
            longURI[i] = "x";
        }
        n.instrumentRef.uri = string(longURI);
        vm.expectRevert();
        general.notarizationPayload(n);
    }

    function testPayloadBoundAndNonceRevocation() public {
        (
            IStreamCollectionAttestations.Subject memory subject,
            IStreamGeneralAttestations.Request memory r
        ) = _generalRequest(42);
        r.payload = new bytes(8193);
        bytes memory signature = _sign(general.attestationDigest(r));
        vm.expectRevert();
        general.recordSignedAttestation(subject, r, signature);
        require(!general.isAttesterNonceUsed(signer, 42), "oversize nonce intact");
        r.payload = new bytes(8192);
        signature = _sign(general.attestationDigest(r));
        bytes32 hash = general.recordSignedAttestation(subject, r, signature);
        (, bytes memory payload) = general.recordPayload(hash);
        require(payload.length == 8192, "exact payload limit");
        vm.prank(signer);
        general.revokeAttesterNonce(43);
        r.nonce = 43;
        r.supersedes = hash;
        signature = _sign(general.attestationDigest(r));
        vm.expectRevert();
        general.recordSignedAttestation(subject, r, signature);
    }

    function testNativeSuccessorAndStewardAuthorityRemainHistorical() public {
        for (uint8 authorityClass = 3; authorityClass <= 4; ++authorityClass) {
            (, IStreamGeneralAttestations.Request memory r) = _generalRequest(authorityClass);
            r.attestationType = keccak256("ARTIST_STATEMENT");
            r.subjectId = keccak256(abi.encode("native scope", authorityClass));
            StreamArtistOnboardingTypes.Attestation memory original =
                StreamArtistOnboardingTypes.Attestation(
                    1,
                    10,
                    r.subjectId,
                    keccak256("native state"),
                    r.schemaId,
                    keccak256(r.payload),
                    r.statementURI
                );
            r.artistAuthorizationRecordHash =
                artist.seed(original, signer, authorityClass, 77, 800, r.payload);
            IStreamGeneralAttestations.ArtistWitness memory witness =
                IStreamGeneralAttestations.ArtistWitness(10, 77, authorityClass - 3);
            bytes32 hash =
                general.recordArtistStatement(r, witness, _sign(general.attestationDigest(r)));
            (, IStreamGeneralAttestations.Receipt memory receipt) = general.attestation(hash);
            require(
                receipt.nativeArtistAuthorityClass == authorityClass
                    && receipt.authorityQualification
                        == IStreamGeneralAttestations.AuthorityQualification.NATIVE_ARTIST_HISTORY,
                "native historical class retained"
            );
        }
    }

    function testLiveSignatureGasMonotonicRaiseEnablesSameSafeProof() public {
        (
            IStreamCollectionAttestations.Subject memory subject,
            IStreamGeneralAttestations.Request memory r
        ) = _generalRequest(1);
        GeneralGasSafeBoundary safe = new GeneralGasSafeBoundary();
        r.attester = address(safe);
        vm.expectRevert();
        general.recordSignedAttestation(subject, r, hex"01");
        require(
            !general.isAttesterNonceUsed(address(safe), 1), "safe retains nonce before budget raise"
        );
        bytes32 parameter = general.GGP_METADATA_ERC1271_VERIFY_GAS();
        vm.expectRevert();
        general.raiseGasParameter(parameter, 300000);
        bytes32 scope = keccak256(
            abi.encode(
                bytes32(0x9533611d402c2b44cf950a4a8900d25f6829bfac541dc4d5353094f966bb1a71),
                block.chainid,
                address(general),
                parameter
            )
        );
        bytes32 oldState = _gasState(scope, 150000, 1);
        bytes32 newState = _gasState(scope, 300000, 2);
        executor.execute(
            address(general),
            abi.encodeCall(general.raiseGasParameter, (parameter, 300000)),
            scope,
            oldState,
            newState,
            1
        );
        require(general.gasParameter(parameter) == 300000, "live raised cap");
        general.recordSignedAttestation(subject, r, hex"01");
        require(
            general.isAttesterNonceUsed(address(safe), 1),
            "same proof succeeds after governed raise"
        );
        vm.expectRevert();
        executor.execute(
            address(general),
            abi.encodeCall(general.raiseGasParameter, (parameter, 200000)),
            scope,
            newState,
            _gasState(scope, 200000, 3),
            1
        );
        require(general.gasParameter(parameter) == 300000, "no lowering");
    }

    function _gasState(bytes32 scope, uint256 value, uint64 revision)
        private
        pure
        returns (bytes32)
    {
        return keccak256(
            abi.encode(
                bytes32(0x5059a253d3f7dd63b5d9fd1f0568caf72967f501a3db678b31cefe911334159c),
                scope,
                value,
                uint256(90000),
                uint8(2),
                revision
            )
        );
    }

    function testSignatureParentGasBranchBeforeERC1271Attempt() public {
        GeneralSignatureGasHarness harness = new GeneralSignatureGasHarness();
        IndependentSignatureBoundary rejectingWallet = new IndependentSignatureBoundary();
        bytes memory input = abi.encodeCall(
            harness.verify,
            (address(rejectingWallet), keccak256("unapproved digest"), hex"01", 150000)
        );
        (bool ok, bytes memory lowGas) = address(harness).staticcall{ gas: 150000 }(input);
        require(
            !ok && bytes4(lowGas) == IStreamGeneralAttestations.GeneralParentGas.selector,
            "signature parent precheck"
        );
        // With enough parent gas this exact target/input reaches the rejecting wallet; the
        // resulting signature error is distinct from the pre-call parent-gas rejection.
        (ok, lowGas) = address(harness).staticcall{ gas: 400000 }(input);
        require(
            !ok && bytes4(lowGas) == IStreamGeneralAttestations.InvalidGeneralSignature.selector,
            "target reached only with sufficient parent gas"
        );
    }
}
