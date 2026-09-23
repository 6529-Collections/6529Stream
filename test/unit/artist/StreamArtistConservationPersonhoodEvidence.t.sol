// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { ArtistConservationPersonhoodFixture } from "./StreamArtistConservationPersonhood.t.sol";
import { IArtistSaleGovernanceContext } from "./ArtistSaleRegistryFixture.sol";
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
    StreamGeneralAttestationDefinitions as GeneralDefinitions
} from "../../../smart-contracts/domains/metadata/StreamGeneralAttestationDefinitions.sol";
import {
    IStreamArtistPersonhoodEvidence,
    StreamArtistPersonhoodTypes as Personhood
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistPersonhoodEvidence.sol";
import {
    StreamArtistPersonhoodDefinitions as PersonhoodDefinitions
} from "../../../smart-contracts/domains/artist/StreamArtistPersonhoodDefinitions.sol";
import {
    StreamArtistPersonhoodJSON
} from "../../../smart-contracts/domains/artist/StreamArtistPersonhoodJSON.sol";
import {
    IStreamGasParameterHost
} from "../../../smart-contracts/interfaces/stream/parameters/IStreamGasParameterHost.sol";
import {
    IStreamSchemaRegistry
} from "../../../smart-contracts/interfaces/stream/metadata/IStreamSchemaRegistry.sol";
import {
    StreamModuleRegistration
} from "../../../smart-contracts/interfaces/stream/modules/IStreamModuleRegistry.sol";

/// @notice Actual signed General records and Safe op24 summaries feed both collection-floor tiers.
/// @dev Core, governance and the original suite Router retain the base fixture's typed boundaries.
/// Instrument references are synthetic documentary fixture data, not proof of legal personhood.
/// No personhood/General read is mocked. Source-only: native Artist capacity and execution are pending;
/// this does not establish the release floor, paid settlement or a complete current-stack integration.
contract StreamArtistConservationPersonhoodEvidenceTest is ArtistConservationPersonhoodFixture {
    // Public deterministic test signer, used only by vm.sign in this local fixture.
    uint256 private constant TEST_NOTARY_KEY = 0x123451;
    StreamGeneralAttestations private notary;
    uint256 private notaryNonce;

    function _prepareResolvedProvider() private {
        _preparePersonhoodProvider();
        _personhoodDocument(
            "STREAM_IDENTITY_NOTARIZATION_V1",
            IStreamSchemaRegistry.DocumentKind.SCHEMA,
            bytes(vm.readFile("schemas/records/STREAM_IDENTITY_NOTARIZATION_V1.json"))
        );
        _personhoodDocument(
            "STREAM_IDENTITY_NOTARIZATION_JSON_PROFILE_V1",
            IStreamSchemaRegistry.DocumentKind.CATALOG,
            bytes(vm.readFile("schemas/records/STREAM_IDENTITY_NOTARIZATION_JSON_PROFILE_V1.json"))
        );
        bytes memory profile = bytes(
            vm.readFile("schemas/records/STREAM_ARTIST_PERSONHOOD_REFERENCE_JSON_PROFILE_V1.json")
        );
        require(
            profile.length == PersonhoodDefinitions.PROFILE_BYTES
                && keccak256(profile) == PersonhoodDefinitions.PROFILE_HASH,
            "exact original personhood reference definition"
        );
        _personhoodDocument(
            "STREAM_ARTIST_PERSONHOOD_REFERENCE_JSON_PROFILE_V1",
            IStreamSchemaRegistry.DocumentKind.CATALOG,
            profile
        );
        StreamGeneralAttestations.Configuration memory c;
        c.core = address(core);
        c.schemas = address(personhoodSchemas);
        c.metadata = address(personhoodMetadata);
        c.artistRegistry = address(ingress);
        c.artistAttribution = suite.owners[4];
        c.executor = address(personhoodGovernance);
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

    function _registerNotary() private {
        // Preserve the original class-1 recipe; the generic sale helper uses a different version.
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

    function _notarize(bytes32 supersedes) private returns (bytes32 hash) {
        Subjects.Subject memory subject = Subjects.Subject(Subjects.SubjectKind.COLLECTION, 1, 0, 0);
        General.Notarization memory n;
        n.artistId = artistId;
        n.operativeIdentityRecordHash = ingress.operativeIdentityRecord(artistId);
        // The report signs these synthetic references; no external instrument authenticity is claimed.
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
        r.attester = vm.addr(TEST_NOTARY_KEY);
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
        (uint8 v, bytes32 r_, bytes32 s_) = vm.sign(TEST_NOTARY_KEY, digest);
        bytes memory signature = abi.encodePacked(r_, s_, v);
        hash = notary.recordIdentityNotarization(subject, r, n, signature);
        (General.Attestation memory a, General.Receipt memory receipt) = notary.attestation(hash);
        require(
            receipt.recorder == r.attester && receipt.authorizationDigest == digest
                && receipt.signatureScheme == keccak256("EIP712")
                && receipt.verificationClass == General.VerificationClass.SIGNER_VERIFIED
                && receipt.authorityQualification
                    == General.AuthorityQualification.GENERAL_SIGNER_CLAIM
                && receipt.artistId == artistId
                && receipt.operativeIdentityRecordHash == n.operativeIdentityRecordHash
                && a.supersedes == supersedes,
            "original signed and artist-bound General receipt"
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
            "independent original General record preimage"
        );
        require(
            notary.latestAttestationHashFor(1, r.attestationType, r.subjectId, r.attester) == hash,
            "actual original recorder-scoped head"
        );
        _assertGeneralBytes(hash, r.payload, signature, receipt.signatureBundleHash);
    }

    function _assertGeneralBytes(
        bytes32 record,
        bytes memory payload,
        bytes memory signature,
        bytes32 bundleHash
    ) private view {
        (address payloadPointer, bytes memory stored) = notary.recordPayload(record);
        require(
            payloadPointer.code.length != 0 && keccak256(stored) == keccak256(payload),
            "complete original notarization payload"
        );
        (address signaturePointer, bytes memory bundle) = notary.recordSignatureBundle(record);
        (bytes32 domain, bytes32[15] memory words, bytes memory retainedSignature) =
            abi.decode(bundle, (bytes32, bytes32[15], bytes));
        require(
            signaturePointer.code.length != 0 && keccak256(bundle) == bundleHash
                && keccak256(bundle) == keccak256(abi.encode(domain, words, retainedSignature))
                && keccak256(retainedSignature) == keccak256(signature),
            "complete original ECDSA signature bundle"
        );
    }

    function _selectDocumentary(bytes32 documentary) private returns (bytes32) {
        Personhood.Reference memory ref = Personhood.Reference(
            1,
            PersonhoodDefinitions.PROFILE_HASH,
            address(ingress),
            artistId,
            ingress.operativeIdentityRecord(artistId),
            address(notary),
            address(notary).codehash,
            documentary
        );
        return _recordNativePersonhood(
            StreamArtistPersonhoodJSON.encode(ref), PersonhoodDefinitions.EVIDENCE_SCHEMA
        );
    }

    function _assertResolvedSummary(bytes32 nativeRecord, bytes32 documentary)
        private
        view
        returns (bytes32 expected)
    {
        Personhood.Selection memory selected = _nativePersonhoodSelection();
        require(
            selected.status == Personhood.Status.RESOLVED && selected.identityCurrent
                && selected.notarizationCurrent && selected.nativeRecord.recordHash == nativeRecord
                && selected.nativeRecord.schemaId == PersonhoodDefinitions.EVIDENCE_SCHEMA
                && selected.evidenceReference.notarizationRecordHash == documentary
                && selected.notarizationHead == documentary
                && selected.sourceRegistry == address(ingress),
            "current original native proof selection"
        );
        IStreamArtistPersonhoodEvidence owner = IStreamArtistPersonhoodEvidence(suite.owners[4]);
        Personhood.Summary memory summary = owner.personhoodProofSummary(nativeRecord);
        require(
            abi.encode(summary).length == 1536 && summary.version == 1
                && summary.chainId == block.chainid && summary.nativeRecordHash == nativeRecord
                && summary.statementHash == selected.nativeRecord.statementHash
                && summary.artistId == artistId && summary.collectionId == 1
                && summary.generation == selected.nativeRecord.generation
                && summary.identityRecordHash == ingress.operativeIdentityRecord(artistId)
                && keccak256(abi.encode(summary.evidenceReference))
                    == keccak256(abi.encode(selected.evidenceReference)),
            "original complete summary and operative identity"
        );
        require(
            summary.notarizationCollectionId == 1 && summary.recorder == selected.recorder
                && summary.attestationType == keccak256("INSTITUTIONAL_VERIFICATION")
                && selected.notarizationType == summary.attestationType,
            "original collection and recorder qualification"
        );
        require(
            summary.core == address(core) && summary.coreCodeHash == address(core).codehash
                && summary.originalRegistryCodeHash == address(ingress).codehash
                && summary.moduleRegistry == address(saleModules)
                && summary.moduleRegistryCodeHash == address(saleModules).codehash
                && summary.schemaRegistry == address(personhoodSchemas)
                && summary.schemaRegistryCodeHash == address(personhoodSchemas).codehash
                && summary.chunkStore == address(personhoodStore)
                && summary.chunkStoreCodeHash == address(personhoodStore).codehash,
            "actual original dependency pins"
        );
        for (uint256 i; i < 6; ++i) {
            require(
                summary.carriers[i].code.length != 0
                    && summary.carriers[i].codehash == summary.carrierCodeHashes[i],
                "actual retained documentary carriers"
            );
        }
        expected = keccak256(
            abi.encode(keccak256("6529STREAM_ARTIST_PERSONHOOD_PROOF_SUMMARY_V1"), summary)
        );
        require(
            expected != 0 && expected != nativeRecord
                && owner.personhoodProofSummaryHash(nativeRecord) == expected,
            "exact original summary hash consumed by conservation"
        );
    }

    function testActualGeneralRecordAndSafeOp24SummarySatisfyBothCollectionFloors() public {
        _prepareResolvedProvider();
        require(_nativePersonhoodSelection().status == Personhood.Status.NONE, "no seeded waiver");
        _expectPersonhoodUnavailable();
        bytes32 documentary = _notarize(0);
        require(
            _nativePersonhoodSelection().status == Personhood.Status.NONE,
            "General cannot select op24"
        );
        _expectPersonhoodUnavailable();
        bytes32 nativeRecord = _selectDocumentary(documentary);
        bytes32 expected = _assertResolvedSummary(nativeRecord, documentary);
        _assertCollectionFloor(expected);
    }

    function testActualRecorderSupersessionRejectsUntilFreshSafeOp24SelectsNewReport() public {
        _prepareResolvedProvider();
        bytes32 first = _notarize(0);
        bytes32 firstNative = _selectDocumentary(first);
        bytes32 firstSummary = _assertResolvedSummary(firstNative, first);
        _assertCollectionFloor(firstSummary);

        bytes32 second = _notarize(first);
        Personhood.Selection memory stale = _nativePersonhoodSelection();
        require(
            stale.status == Personhood.Status.STALE && stale.identityCurrent
                && !stale.notarizationCurrent && stale.nativeRecord.recordHash == firstNative
                && stale.evidenceReference.notarizationRecordHash == first
                && stale.notarizationHead == second,
            "new original recorder head stales rather than replaces native selection"
        );
        _expectPersonhoodUnavailable();
        IStreamArtistPersonhoodEvidence owner = IStreamArtistPersonhoodEvidence(suite.owners[4]);
        require(
            owner.personhoodProofSummaryHash(firstNative) == firstSummary,
            "historical original summary survives current rejection"
        );

        bytes32 secondNative = _selectDocumentary(second);
        bytes32 secondSummary = _assertResolvedSummary(secondNative, second);
        require(
            secondNative != firstNative && secondSummary != firstSummary,
            "fresh original native selection and summary"
        );
        _assertCollectionFloor(secondSummary);
        require(
            owner.personhoodProofSummaryHash(firstNative) == firstSummary,
            "fresh op24 preserves the earlier historical proof"
        );
    }
}
