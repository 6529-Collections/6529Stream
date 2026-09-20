// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    StreamArtistArchiveOriginProof as Proof
} from "../../../smart-contracts/domains/preservation/StreamArtistArchiveOriginProof.sol";
import {
    StreamMetadataArtistConfiguration as Configuration
} from "../../../smart-contracts/domains/metadata/StreamMetadataArtistConfiguration.sol";
import {
    StreamArtistArchiveOriginTypes as O
} from "../../../smart-contracts/interfaces/stream/preservation/StreamArtistArchiveOriginTypes.sol";
import {
    StreamRenderCriticalSourceTypes as S
} from "../../../smart-contracts/interfaces/stream/preservation/StreamRenderCriticalSourceTypes.sol";
import {
    StreamArtistRecoveredHydrationTypes as RH
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistRecoveredHydrationTypes.sol";
import {
    StreamArtistOnboardingTypes as A
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistOnboardingTypes.sol";
import {
    StreamArtistRecordPublicationTypes as P
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistRecordPublicationTypes.sol";
import {
    StreamArtistHistoryTypes as H
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistHistory.sol";
import {
    IStreamArtistRecordPublicationOwner as Publication
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistRecordPublicationOwner.sol";
import {
    IStreamArtistContentRecordsOwner as Content
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistContentOwner.sol";
import {
    StreamArtistContentTypes as ContentTypes
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistContentTypes.sol";

interface ArchiveOriginProofVm {
    function etch(address target, bytes calldata code) external;
    function mockCall(address target, bytes calldata input, bytes calldata output) external;
    function mockCallRevert(address target, bytes calldata input, bytes calldata reason) external;
}

/// @notice Production proof/environment logic against explicit fixed getter boundary fixtures.
/// @dev All external suite/owner/history getters are mocked, with real runtime/configuration
/// hashing and production selection/read logic. These cases do not prove actual source
/// authorization, op55/56/57/60 execution, original Archive bytes or complete Finality admission.
/// The separate ImportedReceiptRead suite exercises genuine installed namespace/dispatch reads.
contract StreamArtistArchiveOriginProofTest {
    ArchiveOriginProofVm private constant vm =
        ArchiveOriginProofVm(address(uint160(uint256(keccak256("hevm cheat code")))));
    bytes32 private constant COMMITMENT = keccak256("fixture complete operation60 commitment");
    bytes32 private constant ARTIST = keccak256("fixture artist");
    bytes32 private constant RECORD = keccak256("fixture original publication");
    bytes32 private constant CANDIDATE = keccak256("fixture original Metadata candidate");
    bytes32 private constant CONSENT = keccak256("fixture content consent");
    bytes32 private constant CONTEXT = keccak256("fixture exact selected context");
    address private constant ACTOR = address(7777);
    address private constant FINALITY = address(5020);
    address private constant PROVIDER = address(5021);
    S.Dependencies private d;
    A.SuiteConfiguration private original;
    A.SuiteConfiguration private current_;
    Publication.Record private publication;
    Content.ConsentRecord private consent;

    function setUp() public {
        for (uint256 i; i < 12; ++i) {
            d.targets[i] = address(uint160(3000 + i));
            _code(d.targets[i]);
            d.codeHashes[i] = d.targets[i].codehash;
        }
        d.chainId = block.chainid;
        d.readGas = 300000;
        d.sourceGas = 300000;
        d.selectionGas = 300000;
        d.snapshotGas = 300000;
        d.referenceGas = 300000;
        for (uint256 i; i < 5; ++i) {
            _code(address(uint160(5010 + i)));
        }
        _code(FINALITY);
        _code(PROVIDER);
        original = _suite(1000);
        current_ = _suite(2000);
        _configure(original, address(1001));
        _configure(current_, address(2001));
        d.artistTargets = [
            current_.registry,
            address(2001),
            current_.owners[2],
            current_.owners[4],
            current_.archive
        ];
        for (uint256 i; i < 5; ++i) {
            d.artistCodeHashes[i] = d.artistTargets[i].codehash;
        }
        d.artistContentOwner = current_.owners[6];
        d.artistContentOwnerCodeHash = d.artistContentOwner.codehash;
        _metadataOriginal(current_.registry);
        _pointer(keccak256("ARTIST_REGISTRY"), current_.registry);
        _pointer(keccak256("METADATA_ROUTER"), d.targets[4]);
        _mock(d.targets[4], "core()", abi.encode(d.targets[0]));
        _records();
    }

    function currentOrigin() external view returns (O.Origin memory, bytes32) {
        return Proof.currentOrigin(d);
    }

    function publicationOrigin(O.ReceiptWitness calldata witness)
        external
        view
        returns (O.RecordOrigin memory)
    {
        return Proof.publicationOrigin(d, publication.evidence, CANDIDATE, ACTOR, CONTEXT, witness);
    }

    function contentOrigin(O.ContentRole role, O.ReceiptWitness calldata witness)
        external
        view
        returns (O.RecordOrigin memory)
    {
        return Proof.contentOrigin(d, 77, ARTIST, CONSENT, ACTOR, role, CONTEXT, witness);
    }

    function ancestor(address registry, bytes32 runtimeHash)
        external
        view
        returns (O.Origin memory)
    {
        return Proof.ancestorOrigin(d, registry, runtimeHash);
    }

    function testOriginProofCurrentExactPinsAndNativePublicationZeroImportFields() public view {
        (O.Origin memory selected, bytes32 completion) = this.currentOrigin();
        require(completion == 0, "genuine original-selection boundary allows no import");
        require(
            keccak256(abi.encode(selected))
                == keccak256(abi.encode(_origin(current_, address(2001)))),
            "exact current environment"
        );
        O.RecordOrigin memory got = this.publicationOrigin(O.ReceiptWitness(O.Lane.NATIVE, 0));
        require(
            got.importCommitment == 0 && got.importedAtRevision == 0, "native capsule is explicit"
        );
        require(
            got.occurrence.position.nativeIndex == 0
                && got.occurrence.position.point.ownerRevision == 5,
            "actual native coordinate"
        );
        require(
            got.actor == ACTOR && got.semanticRecordHash == keccak256(abi.encode(publication))
                && got.sourceContextHash == CONTEXT,
            "all semantic context retained"
        );
        require(
            got.role == keccak256("ORIGINAL_ARTIST_PUBLICATION_AUTHORIZATION"), "publication role"
        );
        require(
            O.evidenceId(got)
                == keccak256(
                    abi.encode(
                        keccak256("6529STREAM_ARTIST_ONBOARDING_OPERATION_EVIDENCE_V1"),
                        block.chainid,
                        current_.registry,
                        address(2001),
                        uint16(24),
                        ACTOR,
                        RECORD
                    )
                ),
            "unchanged original evidence ID"
        );
    }

    function testOriginProofImportedPublicationUsesOriginalNativeCoordinateAndProducer() public {
        _successor();
        _imports();
        O.RecordOrigin memory got = this.publicationOrigin(O.ReceiptWitness(O.Lane.IMPORTED, 0));
        require(
            keccak256(abi.encode(got.producer))
                == keccak256(abi.encode(_origin(original, address(1001)))),
            "actual original producer"
        );
        require(
            got.occurrence.position.nativeIndex == 2
                && got.occurrence.position.point.ownerRevision == 9,
            "original coordinate, not current prefix index"
        );
        require(
            got.importCommitment == COMMITMENT && got.importedAtRevision == 3,
            "actual current import marker"
        );
        require(
            got.semanticRecordHash == keccak256(abi.encode(publication)),
            "full704-byte semantic equality"
        );
    }

    function testOriginProofImportedContentRetainsAllFourRoleDomains() public {
        _successor();
        _imports();
        bytes32[4] memory roles = [
            keccak256("ORIGINAL_CONTENT_ROOT_AUTHORIZATION"),
            keccak256("ORIGINAL_SCOPED_CONTENT_ROOT_AUTHORIZATION"),
            keccak256("ORIGINAL_POLICY_CONTENT_ROOT_AUTHORIZATION_V2"),
            keccak256("ORIGINAL_SCOPED_POLICY_CONTENT_ROOT_AUTHORIZATION_V2")
        ];
        bytes32 previous;
        for (uint8 i; i < 4; ++i) {
            O.RecordOrigin memory got =
                this.contentOrigin(O.ContentRole(i), O.ReceiptWitness(O.Lane.IMPORTED, 0));
            require(
                got.role == roles[i] && got.semanticRecordHash == keccak256(abi.encode(consent)),
                "exact256-byte consent and role"
            );
            require(
                got.occurrence.position.point.ownerIndex == 6
                    && got.occurrence.receipt.operation == 17,
                "fixed content owner and operation"
            );
            bytes32 hash = O.recordOriginHash(got);
            require(hash != previous, "role-qualified facts stay distinct");
            previous = hash;
        }
    }

    function testOriginProofAncestorRequiresExactCurrentRuntimeOrImportedIdentityCertificate()
        public
    {
        O.Origin memory local = this.ancestor(current_.registry, current_.registry.codehash);
        require(local.environment.registry == current_.registry, "current seed");
        _reject(abi.encodeCall(this.ancestor, (current_.registry, bytes32(uint256(1)))));
        _successor();
        _imports();
        O.Origin memory old = this.ancestor(original.registry, original.registry.codehash);
        require(old.environment.registry == original.registry, "imported ancestor seed");
        bytes32 hash = RH.originHash(old.environment);
        vm.mockCall(
            current_.owners[2],
            abi.encodeWithSignature("recoveredHydrationImportedOriginCertificate(bytes32)", hash),
            abi.encode(hash, COMMITMENT, uint64(3), uint8(4))
        );
        _reject(abi.encodeCall(this.ancestor, (original.registry, original.registry.codehash)));
    }

    function testOriginProofRejectsPartialSevenOwnerCompletion() public {
        _mock(current_.owners[3], "authorityHydrationCommitment()", abi.encode(COMMITMENT));
        _reject(abi.encodeCall(this.currentOrigin, ()));
    }

    function testOriginProofRejectsAlteredCurrentPin() public {
        vm.etch(current_.owners[4], hex"600000");
        _rejectAny(abi.encodeCall(this.currentOrigin, ()));
    }

    function testOriginProofRejectsImportedOriginWithChangedSavedRuntime() public {
        _successor();
        _imports();
        vm.etch(original.owners[4], hex"600000");
        _rejectAny(abi.encodeCall(this.publicationOrigin, (O.ReceiptWitness(O.Lane.IMPORTED, 0))));
    }

    function testOriginProofCertificateAloneCannotReplaceMissingIndexedReceipt() public {
        _successor();
        _imports();
        vm.mockCallRevert(
            current_.owners[4],
            abi.encodeWithSignature("recoveredHydrationImportedReceiptAt(uint256)", uint256(0)),
            abi.encodeWithSelector(RH.InvalidRecoveredHydrationProvenance.selector)
        );
        _rejectAny(abi.encodeCall(this.publicationOrigin, (O.ReceiptWitness(O.Lane.IMPORTED, 0))));
    }

    function testOriginProofRejectsWrongImportedReceiptBeforeOriginalReads() public {
        _successor();
        _imports();
        RH.JournalEntry memory row = _row(4);
        row.receipt.collectionId = 78;
        vm.mockCall(
            current_.owners[4],
            abi.encodeWithSignature("recoveredHydrationImportedReceiptAt(uint256)", uint256(0)),
            abi.encode(row, COMMITMENT, uint64(3))
        );
        // If a later original read is reached it produces an IO error, not the required origin
        // mismatch. This establishes the expected early receipt-identity rejection order.
        vm.mockCallRevert(
            original.owners[4], abi.encodeWithSignature("artistNativeReceiptCount()"), hex"12345678"
        );
        _reject(abi.encodeCall(this.publicationOrigin, (O.ReceiptWitness(O.Lane.IMPORTED, 0))));
    }

    function testOriginProofRejectsCertificateCommitmentRevisionAndOwnerMismatch() public {
        _successor();
        _imports();
        bytes32 hash = _row(4).position.point.environmentHash;
        bytes memory input =
            abi.encodeWithSignature("recoveredHydrationImportedOriginCertificate(bytes32)", hash);
        vm.mockCall(
            current_.owners[4],
            input,
            abi.encode(hash, keccak256("wrong import"), uint64(3), uint8(4))
        );
        _reject(abi.encodeCall(this.publicationOrigin, (O.ReceiptWitness(O.Lane.IMPORTED, 0))));
        vm.mockCall(current_.owners[4], input, abi.encode(hash, COMMITMENT, uint64(4), uint8(4)));
        _reject(abi.encodeCall(this.publicationOrigin, (O.ReceiptWitness(O.Lane.IMPORTED, 0))));
        vm.mockCall(current_.owners[4], input, abi.encode(hash, COMMITMENT, uint64(3), uint8(6)));
        _reject(abi.encodeCall(this.publicationOrigin, (O.ReceiptWitness(O.Lane.IMPORTED, 0))));
    }

    function testOriginProofRejectsOriginalNativeReceiptAndRevisionMismatch() public {
        _successor();
        _imports();
        H.Receipt memory wrong = _row(4).receipt;
        wrong.recordHash = keccak256("another actual source record");
        vm.mockCall(
            original.owners[4],
            abi.encodeWithSignature("artistNativeReceiptAt(uint256)", uint256(2)),
            abi.encode(wrong)
        );
        _reject(abi.encodeCall(this.publicationOrigin, (O.ReceiptWitness(O.Lane.IMPORTED, 0))));
        vm.mockCall(
            original.owners[4],
            abi.encodeWithSignature("artistNativeReceiptAt(uint256)", uint256(2)),
            abi.encode(_row(4).receipt)
        );
        vm.mockCall(
            original.owners[4],
            abi.encodeWithSignature("artistNativeReceiptRevisionAt(uint256)", uint256(2)),
            abi.encode(uint64(10))
        );
        _reject(abi.encodeCall(this.publicationOrigin, (O.ReceiptWitness(O.Lane.IMPORTED, 0))));
    }

    function testOriginProofRejectsFullSemanticMismatchDespiteMatchingReceiptHash() public {
        _successor();
        _imports();
        Publication.Record memory different = publication;
        different.publication.uriHash = keccak256("different retained publication bytes");
        vm.mockCall(
            original.owners[4],
            abi.encodeCall(Publication.publicationAttestation, (RECORD)),
            abi.encode(different)
        );
        _reject(abi.encodeCall(this.publicationOrigin, (O.ReceiptWitness(O.Lane.IMPORTED, 0))));
        Content.ConsentRecord memory other = consent;
        other.terms.newStateHash = keccak256("different saved consent terms");
        vm.mockCall(
            original.owners[6],
            abi.encodeCall(Content.contentConsentRecord, (CONSENT)),
            abi.encode(other)
        );
        _reject(
            abi.encodeCall(
                this.contentOrigin, (O.ContentRole.COLLECTION, O.ReceiptWitness(O.Lane.IMPORTED, 0))
            )
        );
    }

    function testOriginProofRejectsOversizedImportedFrameAndWrongNativeIndex() public {
        _successor();
        _imports();
        vm.mockCall(
            current_.owners[4],
            abi.encodeWithSignature("recoveredHydrationImportedReceiptAt(uint256)", uint256(0)),
            bytes.concat(abi.encode(_row(4), COMMITMENT, uint64(3)), bytes32(0))
        );
        _rejectAny(abi.encodeCall(this.publicationOrigin, (O.ReceiptWitness(O.Lane.IMPORTED, 0))));
        _reject(abi.encodeCall(this.publicationOrigin, (O.ReceiptWitness(O.Lane.NATIVE, 1))));
    }

    function _successor() private {
        _metadataOriginal(original.registry);
        _mock(
            original.registry,
            "artistRegistryCutover()",
            abi.encode(true, current_.registry, uint64(20))
        );
        _mock(current_.registry, "importedHistoryBindingCount()", abi.encode(uint256(1)));
        vm.mockCall(
            current_.registry,
            abi.encodeWithSignature("importedHistoryBinding(uint256)", uint256(0)),
            abi.encode(
                original.registry, uint64(10), keccak256("history root"), keccak256("manifest")
            )
        );
        vm.mockCall(
            current_.registry,
            abi.encodeWithSignature("artistHistoryPredecessorBinding(address)", original.registry),
            abi.encode(true, original.registry.codehash, uint256(1))
        );
        for (uint256 i; i < 7; ++i) {
            _mock(current_.owners[i], "authorityHydrationCommitment()", abi.encode(COMMITMENT));
        }
    }

    function _imports() private {
        O.Origin memory source = _origin(original, address(1001));
        bytes32 hash = RH.originHash(source.environment);
        for (uint8 i; i < 7; ++i) {
            if (i != 2 && i != 4 && i != 6) continue;
            vm.mockCall(
                current_.owners[i],
                abi.encodeWithSignature(
                    "recoveredHydrationImportedOriginCertificate(bytes32)", hash
                ),
                abi.encode(hash, COMMITMENT, uint64(3), i)
            );
            vm.mockCall(
                current_.owners[i],
                abi.encodeWithSignature("recoveredHydrationOrigin(bytes32)", hash),
                abi.encode(source.environment)
            );
            if (i == 2) continue;
            RH.JournalEntry memory row = _row(i);
            vm.mockCall(
                current_.owners[i],
                abi.encodeWithSignature("recoveredHydrationImportedReceiptAt(uint256)", uint256(0)),
                abi.encode(row, COMMITMENT, uint64(3))
            );
            _mock(original.owners[i], "artistNativeReceiptCount()", abi.encode(uint256(3)));
            vm.mockCall(
                original.owners[i],
                abi.encodeWithSignature("artistNativeReceiptAt(uint256)", uint256(2)),
                abi.encode(row.receipt)
            );
            vm.mockCall(
                original.owners[i],
                abi.encodeWithSignature("artistNativeReceiptRevisionAt(uint256)", uint256(2)),
                abi.encode(uint64(9))
            );
        }
    }

    function _row(uint8 index) private view returns (RH.JournalEntry memory) {
        return RH.JournalEntry(
            RH.Position(
                RH.Point(RH.originHash(_origin(original, address(1001)).environment), index, 9), 2
            ),
            H.Receipt(index == 4 ? 24 : 17, ARTIST, 77, index == 4 ? RECORD : CONSENT)
        );
    }

    function _records() private {
        P.Publication memory p;
        p.metadataHost = d.targets[1];
        p.recorder = ACTOR;
        p.collectionId = 77;
        p.subjectId = keccak256("subject");
        p.recordType = keccak256("WORK");
        p.schemaId = keccak256("schema");
        p.canonicalizationId = keccak256("RAW");
        p.payloadAlgorithm = 1;
        p.payloadHash = keccak256("payload");
        p.uriHash = keccak256("original URI");
        p.effectiveAt = 10;
        p.candidateRecordHash = CANDIDATE;
        publication = Publication.Record(
            p,
            P.Evidence(
                RECORD, ARTIST, keccak256("binding"), 1, ACTOR, 1, 1, 10, keccak256(abi.encode(p))
            ),
            d.codeHashes[1]
        );
        consent = Content.ConsentRecord(
            CONSENT,
            ARTIST,
            1,
            ContentTypes.Consent(
                77, d.targets[4], keccak256("CONTENT_ROOT"), keccak256("signed root")
            ),
            1
        );
        vm.mockCall(
            current_.owners[4],
            abi.encodeCall(Publication.publicationAttestation, (RECORD)),
            abi.encode(publication)
        );
        vm.mockCall(
            original.owners[4],
            abi.encodeCall(Publication.publicationAttestation, (RECORD)),
            abi.encode(publication)
        );
        vm.mockCall(
            current_.owners[6],
            abi.encodeCall(Content.contentConsentRecord, (CONSENT)),
            abi.encode(consent)
        );
        vm.mockCall(
            original.owners[6],
            abi.encodeCall(Content.contentConsentRecord, (CONSENT)),
            abi.encode(consent)
        );
        for (uint8 i = 4; i < 7; i += 2) {
            _mock(current_.owners[i], "artistNativeReceiptCount()", abi.encode(uint256(1)));
            vm.mockCall(
                current_.owners[i],
                abi.encodeWithSignature("artistNativeReceiptAt(uint256)", uint256(0)),
                abi.encode(H.Receipt(i == 4 ? 24 : 17, ARTIST, 77, i == 4 ? RECORD : CONSENT))
            );
            vm.mockCall(
                current_.owners[i],
                abi.encodeWithSignature("artistNativeReceiptRevisionAt(uint256)", uint256(0)),
                abi.encode(uint64(5))
            );
        }
    }

    function _suite(uint160 base) private returns (A.SuiteConfiguration memory s) {
        s.registry = address(base);
        s.archive = address(base + 2);
        _code(s.registry);
        _code(address(base + 1));
        _code(s.archive);
        for (uint8 i; i < 7; ++i) {
            s.owners[i] = address(base + 10 + i);
            _code(s.owners[i]);
        }
        s.core = d.targets[0];
        s.mintManager = address(5010);
        s.roleRegistry = address(5011);
        s.metadata = d.targets[4];
        s.primaryResolver = address(5012);
        s.royaltyResolver = address(5013);
        s.primaryRevenueClass = keccak256("revenue class");
        s.validator = address(5014);
    }

    function _configure(A.SuiteConfiguration memory s, address coordinator) private {
        _mock(s.registry, "core()", abi.encode(s.core));
        _mock(s.registry, "operationCoordinator()", abi.encode(coordinator));
        _mock(s.archive, "artistRegistry()", abi.encode(s.registry));
        _mock(s.archive, "operationCoordinator()", abi.encode(coordinator));
        _mock(coordinator, "deploymentChainId()", abi.encode(block.chainid));
        _mock(coordinator, "suiteConfiguration()", abi.encode(s));
        _mock(coordinator, "finalityRegistry()", abi.encode(FINALITY));
        _mock(coordinator, "finalityEvidenceProvider()", abi.encode(PROVIDER));
        _mock(
            coordinator,
            "configurationHash()",
            abi.encode(Configuration.hash(coordinator, s, FINALITY, PROVIDER))
        );
        for (uint8 i; i < 7; ++i) {
            address owner = s.owners[i];
            _mock(owner, "core()", abi.encode(s.core));
            _mock(owner, "mintManager()", abi.encode(s.mintManager));
            _mock(owner, "artistRegistry()", abi.encode(s.registry));
            _mock(owner, "operationCoordinator()", abi.encode(coordinator));
            _mock(owner, "archiveV2()", abi.encode(s.archive));
            _mock(owner, "deploymentChainId()", abi.encode(block.chainid));
            _mock(owner, "domainId()", abi.encode(RH.ownerDomain(i)));
            _mock(owner, "authorityHydrationCommitment()", abi.encode(bytes32(0)));
            _mock(
                owner,
                "ownerStateSnapshotV2()",
                abi.encode(
                    A.Snapshot(
                        RH.ownerDomain(i), 100, keccak256("state root"), keccak256("record tip")
                    )
                )
            );
        }
    }

    function _origin(A.SuiteConfiguration memory s, address coordinator)
        private
        view
        returns (O.Origin memory result)
    {
        RH.OriginEnvironment memory e;
        e.chainId = block.chainid;
        e.registry = s.registry;
        e.coordinator = coordinator;
        e.archive = s.archive;
        e.owners = s.owners;
        for (uint8 i; i < 7; ++i) {
            e.ownerCodeHashes[i] = s.owners[i].codehash;
        }
        e.core = s.core;
        e.manager = s.mintManager;
        e.suiteConfigurationHash = keccak256(abi.encode(s));
        return O.Origin(e, s.registry.codehash, coordinator.codehash, s.archive.codehash);
    }

    function _metadataOriginal(address registry) private {
        _mock(d.targets[1], "artistRegistry()", abi.encode(registry));
        _mock(d.targets[1], "artistRegistryCodeHash()", abi.encode(registry.codehash));
    }

    function _pointer(bytes32 key, address target) private {
        vm.mockCall(
            d.targets[0],
            abi.encodeWithSignature("getSatellitePointer(bytes32)", key),
            abi.encode(
                target,
                target.codehash,
                true,
                bytes32(uint256(1)),
                bytes4(0),
                address(0),
                uint8(1),
                bytes32(0),
                bytes32(0),
                uint64(1)
            )
        );
    }

    function _code(address target) private {
        vm.etch(target, hex"00");
    }

    function _mock(address target, string memory signature, bytes memory result) private {
        vm.mockCall(target, abi.encodeWithSignature(signature), result);
    }

    function _reject(bytes memory input) private view {
        (bool ok, bytes memory reason) = address(this).staticcall(input);
        require(
            !ok
                && keccak256(reason)
                    == keccak256(abi.encodeWithSelector(O.InvalidArchiveOrigin.selector)),
            "exact origin rejection"
        );
    }

    function _rejectAny(bytes memory input) private view {
        (bool ok,) = address(this).staticcall(input);
        require(!ok, "dependency/framing failure");
    }
}
