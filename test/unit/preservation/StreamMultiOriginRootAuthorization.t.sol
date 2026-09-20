// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    StreamMultiOriginArtistBundleReads as Collection
} from "../../../smart-contracts/domains/preservation/StreamMultiOriginArtistBundleReads.sol";
import {
    StreamMultiOriginScopedRootAuthorization as Scoped
} from "../../../smart-contracts/domains/preservation/StreamMultiOriginScopedRootAuthorization.sol";
import {
    StreamMultiOriginPolicyRootAuthorizationV2 as Policy
} from "../../../smart-contracts/domains/preservation/StreamMultiOriginPolicyRootAuthorizationV2.sol";
import {
    StreamMultiOriginScopedPolicyRootAuthorizationV2 as ScopedPolicy
} from "../../../smart-contracts/domains/preservation/StreamMultiOriginScopedPolicyRootAuthorizationV2.sol";
import {
    StreamArtistArchiveOriginProof as Proof
} from "../../../smart-contracts/domains/preservation/StreamArtistArchiveOriginProof.sol";
import {
    StreamArtistArchiveOriginTypes as O
} from "../../../smart-contracts/interfaces/stream/preservation/StreamArtistArchiveOriginTypes.sol";
import {
    StreamPreservationInventoryTypes as V
} from "../../../smart-contracts/interfaces/stream/preservation/StreamPreservationInventoryTypes.sol";
import {
    StreamRenderCriticalSourceTypes as S
} from "../../../smart-contracts/interfaces/stream/preservation/StreamRenderCriticalSourceTypes.sol";
import {
    StreamScopedRenderCriticalTypes as SC
} from "../../../smart-contracts/interfaces/stream/preservation/StreamScopedRenderCriticalTypes.sol";
import {
    StreamPolicyRenderCriticalTypesV2 as PC
} from "../../../smart-contracts/interfaces/stream/preservation/StreamPolicyRenderCriticalTypesV2.sol";
import {
    StreamScopedPolicyRenderCriticalTypesV2 as SPC
} from "../../../smart-contracts/interfaces/stream/preservation/StreamScopedPolicyRenderCriticalTypesV2.sol";
import {
    StreamArtistRecoveredHydrationTypes as RH
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistRecoveredHydrationTypes.sol";
import {
    StreamArtistOnboardingTypes as A
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistOnboardingTypes.sol";
import {
    StreamArtistContentTypes as C
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistContentTypes.sol";
import {
    IStreamArtistContentRecordsOwner as Saved
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistContentOwner.sol";
import {
    StreamArtistHistoryTypes as H
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistHistory.sol";
import {
    StreamArtistHashes as Hashes
} from "../../../smart-contracts/domains/artist/StreamArtistHashes.sol";
import {
    StreamArtistContentHashes as ContentHashes
} from "../../../smart-contracts/domains/artist/StreamArtistContentHashes.sol";
import {
    IStreamContentRootPublication as Root
} from "../../../smart-contracts/interfaces/stream/metadata/IStreamContentRootPublication.sol";
import {
    IStreamScopedContentRootPublication as ScopedRoot
} from "../../../smart-contracts/interfaces/stream/metadata/IStreamScopedContentRootPublication.sol";
import {
    IStreamPolicyContentRootPublicationV2 as RootV2
} from "../../../smart-contracts/interfaces/stream/metadata/IStreamPolicyContentRootPublicationV2.sol";
import {
    IStreamScopedPolicyContentRootPublicationV2 as ScopedRootV2
} from "../../../smart-contracts/interfaces/stream/metadata/IStreamScopedPolicyContentRootPublicationV2.sol";
import {
    StreamFinalityScope,
    StreamFinalityScopeType
} from "../../../smart-contracts/interfaces/stream/finality/StreamArtworkFinalityTypes.sol";

interface MultiOriginRootVm {
    function mockCall(address target, bytes calldata input, bytes calldata output) external;
    function mockCallRevert(address target, bytes calldata input, bytes calldata reason) external;
    function etch(address target, bytes calldata code) external;
}

contract MultiOriginRootMarker { }

contract MultiOriginRootStop {
    constructor(bytes memory payload) {
        bytes memory runtime = bytes.concat(hex"00", payload);
        assembly ("memory-safe") { return(add(runtime, 32), mload(runtime)) }
    }
}

/// @dev Explicit Archive boundary with actual immutable STOP byte retention, not the production
/// Archive's authorization or append-only writer. Mutations below are negative-test controls.
contract MultiOriginRootArchive {
    address public immutable artistRegistry;
    address public immutable operationCoordinator;
    bytes private _bytes;
    bytes32 private _id;
    address public pointer;
    bool public corruptMetadata;

    constructor(address registry, address coordinator) {
        artistRegistry = registry;
        operationCoordinator = coordinator;
    }

    function save(bytes32 id, bytes memory payload) external {
        _id = id;
        _bytes = payload;
        pointer = address(new MultiOriginRootStop(payload));
    }

    function setCorruptMetadata(bool value) external {
        corruptMetadata = value;
    }

    function artistEvidenceBytesV2(bytes32 id, uint64 version)
        external
        view
        returns (bytes memory)
    {
        require(id == _id && version == 1 && pointer != address(0));
        return _bytes;
    }

    function artistEvidenceMetadataV2(bytes32 id, uint64 version)
        external
        view
        returns (bytes32, address, uint32, uint64)
    {
        require(id == _id && version == 1 && pointer != address(0));
        return (corruptMetadata ? bytes32(0) : keccak256(_bytes), pointer, uint32(_bytes.length), 1);
    }
}

/// @notice Four real root/envelope/digest/retention codecs behind an explicit Proof boundary.
/// @dev The fixed Proof result, Router records, configured source suite and saved consent are
/// mocked. Production codec, domain hashing, Archive routing and STOP correspondence execute.
/// No actual source authorization, import-marker validation, Safe/op60 or full-graph claim.
contract StreamMultiOriginRootAuthorizationTest {
    MultiOriginRootVm private constant vm =
        MultiOriginRootVm(address(uint160(uint256(keccak256("hevm cheat code")))));
    bytes32 private constant ARTIST = keccak256("codec boundary artist");
    bytes32 private constant BINDING = keccak256("exact original binding");
    bytes32 private constant CONTEXT = keccak256("selected source context boundary");
    bytes32 private constant CONFIGURATION = keccak256("pinned source configuration boundary");
    uint64 private constant OBSERVED = 90;
    address private constant ACTOR = address(7777);
    S.Dependencies private d;
    S.Context private collectionContext;
    SC.Context private scopedContext;
    PC.Context private policyContext;
    SPC.Context private scopedPolicyContext;
    ScopedRoot.Aggregate private aggregate;
    bytes32 private legacyFamily;
    A.SuiteConfiguration private suite;
    O.RecordOrigin private fact;
    Collection.ContentPayload private payload;
    Root.Record private root;
    ScopedRoot.Record private scopedRoot;
    RootV2.Binding private policyBinding;
    ScopedRootV2.Binding private scopedPolicyBinding;
    MultiOriginRootArchive private originalArchive;
    MultiOriginRootArchive private currentArchive;
    bytes private evidence;

    function read(uint8 mode) external view returns (V.Item memory, O.RecordOrigin memory) {
        O.ReceiptWitness memory witness = O.ReceiptWitness(O.Lane.IMPORTED, 0);
        if (mode == 0) {
            return Collection.contentItem(d, collectionContext, ACTOR, OBSERVED, CONTEXT, witness);
        }
        if (mode == 1) {
            return Scoped.contentItem(
                d, scopedContext, ACTOR, OBSERVED, aggregate, legacyFamily, CONTEXT, witness
            );
        }
        if (mode == 2) {
            return
                Policy.contentItem(d, policyContext, ACTOR, OBSERVED, aggregate, CONTEXT, witness);
        }
        require(mode == 3);
        return ScopedPolicy.contentItem(
            d, scopedPolicyContext, ACTOR, OBSERVED, aggregate, legacyFamily, CONTEXT, witness
        );
    }

    function testAllFourRootCodecsRouteToOriginalArchiveAndReturnExactCapsule() public {
        for (uint8 mode; mode < 4; ++mode) {
            _fixture(mode, false);
            (V.Item memory item, O.RecordOrigin memory got) = this.read(mode);
            require(
                item.kind == V.Kind.STATE_BUNDLE && item.source == address(originalArchive),
                "original Archive selected"
            );
            require(
                item.source != address(currentArchive) && item.sourceRecord == O.evidenceId(fact)
                    && item.sourceIndex == 1,
                "unchanged producer evidence ID/version"
            );
            require(
                item.role == fact.role && item.byteSize == evidence.length && item.algorithm == 1,
                "typed role and original size"
            );
            require(
                keccak256(item.digest) == keccak256(abi.encodePacked(keccak256(evidence))),
                "exact original byte digest"
            );
            require(
                keccak256(abi.encode(got)) == keccak256(abi.encode(fact))
                    && item.provenanceHash != 0,
                "exact static Proof capsule transported"
            );
            require(
                d.artistTargets[4] == address(currentArchive),
                "original caller dependencies unchanged"
            );
        }
    }

    function testPolicyCollectionAcceptsExactZeroAggregateLegacyFamily() public {
        _fixture(2, true);
        (V.Item memory item,) = this.read(2);
        require(item.source == address(originalArchive));
    }

    function testWrongOriginalAggregateCannotUsePresentOrInventedFamily() public {
        for (uint8 mode = 1; mode < 4; ++mode) {
            _fixture(mode, false);
            aggregate.transitionChain = keccak256("wrong original aggregate");
            _reject(mode, V.InvalidInventoryItem.selector);
        }
    }

    function testScopedOriginalLegacyFamilyAndScopeRemainExact() public {
        for (uint8 mode = 1; mode < 4; mode += 2) {
            _fixture(mode, false);
            legacyFamily = keccak256("another collection family");
            _reject(mode, V.InvalidInventoryItem.selector);
            _fixture(mode, false);
            if (mode == 1) scopedContext.scope.tokenId += 1;
            else scopedPolicyContext.scope.tokenId += 1;
            _reject(mode, V.InvalidInventoryItem.selector);
        }
    }

    function testSourceConsentTupleCannotBeReplacedByMatchingHashOnly() public {
        for (uint8 mode; mode < 4; ++mode) {
            _fixture(mode, false);
            Saved.ConsentRecord memory saved = _saved();
            saved.terms.newStateHash = keccak256("different original terms");
            vm.mockCall(
                suite.owners[6],
                abi.encodeCall(Saved.contentConsentRecord, (fact.occurrence.receipt.recordHash)),
                abi.encode(saved)
            );
            _reject(mode, V.InvalidInventoryItem.selector);
        }
    }

    function testProofImportFailureBubblesWithoutArchiveFallback() public {
        for (uint8 mode; mode < 4; ++mode) {
            _fixture(mode, false);
            // This tests propagation of the fixed worker's rejection. Genuine marker/certificate
            // validation belongs to the separate Proof and installed-prefix test suites.
            vm.mockCallRevert(
                address(Proof),
                _proofInput(mode),
                abi.encodeWithSelector(O.InvalidArchiveOrigin.selector)
            );
            _reject(mode, O.InvalidArchiveOrigin.selector);
        }
    }

    function testExactRootGetterFramingRejectsTrailingBytes() public {
        for (uint8 mode; mode < 4; ++mode) {
            _fixture(mode, false);
            bytes memory raw = mode == 0 || mode == 2 ? abi.encode(root) : abi.encode(scopedRoot);
            vm.mockCall(d.targets[4], _rootInput(mode), bytes.concat(raw, bytes32(0)));
            _reject(mode, V.InventoryRead.selector);
        }
    }

    function testCanonicalEnvelopeAndOriginalSignatureDomainAreRetained() public {
        for (uint8 mode; mode < 4; ++mode) {
            _fixture(mode, false);
            originalArchive.save(O.evidenceId(fact), bytes.concat(evidence, bytes32(0)));
            _reject(mode, V.InventoryRead.selector);
            _fixture(mode, false);
            payload.approval.digest = keccak256("digest under a replacement registry");
            _saveEnvelope();
            _reject(mode, V.InvalidInventoryItem.selector);
        }
    }

    function testOriginalArchiveMetadataAndStopBytesAreBothRequired() public {
        for (uint8 mode; mode < 4; ++mode) {
            _fixture(mode, false);
            originalArchive.setCorruptMetadata(true);
            _reject(mode, V.InvalidInventoryItem.selector);
            originalArchive.setCorruptMetadata(false);
            vm.etch(originalArchive.pointer(), hex"0001");
            _reject(mode, V.InvalidInventoryItem.selector);
        }
    }

    function testWrongScopedPolicyTagAndHalfEmptyPolicyAggregateReject() public {
        _fixture(3, false);
        scopedPolicyBinding.profileId = keccak256("unrelated profile");
        vm.mockCall(
            d.targets[4],
            abi.encodeCall(
                ScopedRootV2.scopedPolicyContentRootBinding, (scopedPolicyContext.rootRecordHash)
            ),
            abi.encode(scopedPolicyBinding)
        );
        _reject(3, V.InvalidInventoryItem.selector);
        _fixture(2, false);
        aggregate.revision = 0;
        _reject(2, V.InvalidInventoryItem.selector);
    }

    function _fixture(uint8 mode, bool emptyAggregate) private {
        delete d;
        delete collectionContext;
        delete scopedContext;
        delete policyContext;
        delete scopedPolicyContext;
        delete suite;
        delete fact;
        delete payload;
        delete root;
        delete scopedRoot;
        delete policyBinding;
        delete scopedPolicyBinding;
        for (uint256 i; i < 12; ++i) {
            d.targets[i] = address(new MultiOriginRootMarker());
            d.codeHashes[i] = d.targets[i].codehash;
        }
        d.chainId = block.chainid;
        d.readGas = 500000;
        d.sourceGas = 2000000;
        address registry = address(new MultiOriginRootMarker());
        address coordinator = address(new MultiOriginRootMarker());
        originalArchive = new MultiOriginRootArchive(registry, coordinator);
        currentArchive = new MultiOriginRootArchive(
            address(new MultiOriginRootMarker()), address(new MultiOriginRootMarker())
        );
        suite.registry = registry;
        suite.archive = address(originalArchive);
        suite.core = d.targets[0];
        suite.metadata = d.targets[4];
        suite.mintManager = address(new MultiOriginRootMarker());
        for (uint8 i; i < 7; ++i) {
            suite.owners[i] = address(new MultiOriginRootMarker());
        }
        for (uint256 i; i < 5; ++i) {
            d.artistTargets[i] = address(new MultiOriginRootMarker());
            d.artistCodeHashes[i] = d.artistTargets[i].codehash;
        }
        d.artistTargets[4] = address(currentArchive);
        d.artistCodeHashes[4] = address(currentArchive).codehash;
        d.artistContentOwner = address(new MultiOriginRootMarker());
        d.artistContentOwnerCodeHash = d.artistContentOwner.codehash;
        vm.mockCall(coordinator, abi.encodeWithSignature("suiteConfiguration()"), abi.encode(suite));
        vm.mockCall(
            coordinator, abi.encodeWithSignature("configurationHash()"), abi.encode(CONFIGURATION)
        );
        RH.OriginEnvironment memory e;
        e.chainId = block.chainid;
        e.registry = registry;
        e.coordinator = coordinator;
        e.archive = address(originalArchive);
        e.owners = suite.owners;
        for (uint8 i; i < 7; ++i) {
            e.ownerCodeHashes[i] = suite.owners[i].codehash;
        }
        e.core = suite.core;
        e.manager = suite.mintManager;
        e.suiteConfigurationHash = keccak256(abi.encode(suite));
        fact.producer =
            O.Origin(e, registry.codehash, coordinator.codehash, address(originalArchive).codehash);
        aggregate = emptyAggregate
            ? ScopedRoot.Aggregate(0, 0)
            : ScopedRoot.Aggregate(7, keccak256("historical collection aggregate"));
        legacyFamily = keccak256("original collection family");
        bytes32 state = keccak256("root state");
        bytes32 signedFamily = mode == 0 || (mode == 2 && emptyAggregate)
            ? state
            : keccak256(
                abi.encode(
                    keccak256("6529STREAM_CONTENT_ROOT_FAMILY_WITH_SCOPES_V1"),
                    block.chainid,
                    d.targets[4],
                    d.targets[0],
                    uint256(77),
                    mode == 2 ? state : legacyFamily,
                    aggregate
                )
            );
        _payload(signedFamily);
        _roots(mode, state);
        fact.occurrence.position = RH.Position(RH.Point(RH.originHash(e), 6, 9), 2);
        fact.occurrence.receipt = H.Receipt(17, ARTIST, 77, _consentHash());
        fact.importCommitment = keccak256("explicit imported membership boundary");
        fact.importedAtRevision = 3;
        fact.actor = ACTOR;
        fact.semanticRecordHash = keccak256(abi.encode(_saved()));
        fact.role = _role(mode);
        fact.sourceContextHash = CONTEXT;
        vm.mockCall(
            suite.owners[6],
            abi.encodeCall(Saved.contentConsentRecord, (_consentHash())),
            abi.encode(_saved())
        );
        vm.mockCall(address(Proof), _proofInput(mode), abi.encode(fact));
        _saveEnvelope();
        // The current Archive contains deliberately different bytes under the same requested ID.
        // A codec accidentally routed there cannot satisfy its original envelope/digest checks.
        currentArchive.save(
            O.evidenceId(fact), bytes("current Archive is not the original producer")
        );
    }

    function _payload(bytes32 signedFamily) private {
        payload.binding =
            A.Binding(ARTIST, ACTOR, keccak256("registration"), BINDING, 1, 1, 1, 1, ACTOR, true);
        payload.terms = C.Consent(77, d.targets[4], keccak256("CONTENT_ROOT"), signedFamily);
        payload.authorization = A.Authorization(42, 100, bytes(""));
        payload.approval = A.SignerApproval(
            ACTOR,
            ContentHashes.consentDigest(_domain(), payload.terms, payload.authorization),
            true
        );
        payload.priorState = keccak256("different prior state");
    }

    function _roots(uint8 mode, bytes32 state) private {
        root.publication = Root.Publication(
            77, keccak256("previous root"), keccak256("verified manifest"), "ipfs://root-boundary"
        );
        root.artistId = ARTIST;
        root.bindingGeneration = 1;
        root.bindingHash = BINDING;
        root.stateHash = state;
        root.artistConsent = _consentHash();
        root.publishedAt = 110;
        policyBinding.profileId = keccak256("6529STREAM_POLICY_CONTENT_ROOT_V2");
        bytes32 recordHash;
        if (mode == 0 || mode == 2) {
            recordHash = mode == 0
                ? keccak256(
                    abi.encode(
                        keccak256("6529STREAM_CONTENT_ROOT_RECORD_V1"),
                        block.chainid,
                        d.targets[4],
                        root
                    )
                )
                : keccak256(
                    abi.encode(
                        keccak256("6529STREAM_POLICY_CONTENT_ROOT_RECORD_V2"),
                        block.chainid,
                        d.targets[4],
                        root,
                        policyBinding
                    )
                );
            collectionContext.collectionId = 77;
            collectionContext.artistId = ARTIST;
            collectionContext.rootRecordHash = recordHash;
            policyContext.records = collectionContext;
            policyContext.source.root = root;
            policyContext.source.rootBinding = policyBinding;
            vm.mockCall(
                d.targets[4], abi.encodeCall(Root.contentRootRecord, (recordHash)), abi.encode(root)
            );
            vm.mockCall(
                d.targets[4],
                abi.encodeCall(RootV2.policyContentRootBinding, (recordHash)),
                abi.encode(policyBinding)
            );
        } else {
            StreamFinalityScope memory scope =
                StreamFinalityScope(StreamFinalityScopeType.TOKEN, 77, 9, 0);
            scopedRoot.publication = ScopedRoot.Publication(
                scope,
                keccak256("previous scoped root"),
                keccak256("exact snapshot"),
                1,
                "ipfs://scoped-root-boundary"
            );
            scopedRoot.snapshotHost = d.targets[5];
            scopedRoot.snapshotCodeHash = d.codeHashes[5];
            scopedRoot.artistId = ARTIST;
            scopedRoot.bindingGeneration = 1;
            scopedRoot.bindingHash = BINDING;
            scopedRoot.stateHash = state;
            scopedRoot.artistConsent = _consentHash();
            scopedRoot.publishedAt = 110;
            scopedPolicyBinding.profileId = keccak256("6529STREAM_SCOPED_POLICY_CONTENT_ROOT_V2");
            recordHash = mode == 1
                ? keccak256(
                    abi.encode(
                        keccak256("6529STREAM_SCOPED_CONTENT_ROOT_RECORD_V1"),
                        block.chainid,
                        d.targets[4],
                        d.targets[0],
                        scopedRoot,
                        aggregate
                    )
                )
                : keccak256(
                    abi.encode(
                        keccak256("6529STREAM_SCOPED_POLICY_CONTENT_ROOT_RECORD_V2"),
                        block.chainid,
                        d.targets[4],
                        d.targets[0],
                        scopedRoot,
                        scopedPolicyBinding,
                        aggregate
                    )
                );
            scopedContext.scope = scope;
            scopedContext.artistId = ARTIST;
            scopedContext.snapshot.recordHash = scopedRoot.publication.snapshotRecordHash;
            scopedContext.snapshot.revision = 1;
            scopedContext.rootRecordHash = recordHash;
            scopedPolicyContext.scope = scope;
            scopedPolicyContext.artistId = ARTIST;
            scopedPolicyContext.snapshot.recordHash = scopedRoot.publication.snapshotRecordHash;
            scopedPolicyContext.snapshot.revision = 1;
            scopedPolicyContext.rootRecordHash = recordHash;
            vm.mockCall(
                d.targets[4],
                abi.encodeCall(ScopedRoot.scopedContentRootRecord, (recordHash)),
                abi.encode(scopedRoot)
            );
            vm.mockCall(
                d.targets[4],
                abi.encodeCall(ScopedRootV2.scopedPolicyContentRootBinding, (recordHash)),
                abi.encode(scopedPolicyBinding)
            );
        }
    }

    function _saveEnvelope() private {
        Collection.Envelope memory envelope;
        envelope.version = 1;
        envelope.configurationHash = CONFIGURATION;
        envelope.operationId = 17;
        envelope.actor = ACTOR;
        envelope.record = _consentHash();
        envelope.payload = _body(abi.encode(payload));
        evidence = _body(abi.encode(envelope));
        originalArchive.save(O.evidenceId(fact), evidence);
    }

    function _proofInput(uint8 mode) private view returns (bytes memory) {
        return abi.encodeWithSelector(
            Proof.contentOrigin.selector,
            d,
            uint256(77),
            ARTIST,
            _consentHash(),
            ACTOR,
            O.ContentRole(mode),
            CONTEXT,
            O.ReceiptWitness(O.Lane.IMPORTED, 0)
        );
    }

    function _rootInput(uint8 mode) private view returns (bytes memory) {
        if (mode == 0 || mode == 2) {
            return abi.encodeCall(Root.contentRootRecord, (collectionContext.rootRecordHash));
        }
        return abi.encodeCall(ScopedRoot.scopedContentRootRecord, (scopedContext.rootRecordHash));
    }

    function _saved() private view returns (Saved.ConsentRecord memory) {
        return Saved.ConsentRecord(_consentHash(), ARTIST, 1, payload.terms, 1);
    }

    function _consentHash() private view returns (bytes32) {
        return ContentHashes.consentRecord(
            _domain(), payload.terms, ARTIST, ACTOR, 1, payload.authorization.nonce, OBSERVED
        );
    }

    function _domain() private view returns (Hashes.Environment memory) {
        return Hashes.Environment(block.chainid, suite.registry, d.targets[0], suite.mintManager);
    }

    function _role(uint8 mode) private pure returns (bytes32) {
        if (mode == 0) return keccak256("ORIGINAL_CONTENT_ROOT_AUTHORIZATION");
        if (mode == 1) return keccak256("ORIGINAL_SCOPED_CONTENT_ROOT_AUTHORIZATION");
        if (mode == 2) return keccak256("ORIGINAL_POLICY_CONTENT_ROOT_AUTHORIZATION_V2");
        return keccak256("ORIGINAL_SCOPED_POLICY_CONTENT_ROOT_AUTHORIZATION_V2");
    }

    function _body(bytes memory wrapped) private pure returns (bytes memory result) {
        require(wrapped.length >= 32);
        result = new bytes(wrapped.length - 32);
        for (uint256 i; i < result.length; ++i) {
            result[i] = wrapped[i + 32];
        }
    }

    function _reject(uint8 mode, bytes4 selector) private view {
        (bool ok, bytes memory reason) = address(this).staticcall(abi.encodeCall(this.read, (mode)));
        require(!ok && reason.length >= 4 && bytes4(reason) == selector, "exact codec rejection");
    }
}
