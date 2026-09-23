// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    StreamRenderCriticalSourceTypes as S
} from "../../../smart-contracts/interfaces/stream/preservation/StreamRenderCriticalSourceTypes.sol";
import {
    StreamPreservationInventoryTypes as V
} from "../../../smart-contracts/interfaces/stream/preservation/StreamPreservationInventoryTypes.sol";
import {
    StreamScopedPreservationPolicyRenderCriticalTypesV1 as Scoped
} from "../../../smart-contracts/interfaces/stream/preservation/StreamScopedPreservationPolicyRenderCriticalTypesV1.sol";
import {
    StreamScopedPreservationPolicyRenderCriticalRootAuthorizationV1 as Codec
} from "../../../smart-contracts/domains/preservation/StreamScopedPreservationPolicyRenderCriticalRootAuthorizationV1.sol";
import {
    StreamScopedPreservationPolicyRenderCriticalRootAuthorizationReadV1 as Read
} from "../../../smart-contracts/domains/preservation/StreamScopedPreservationPolicyRenderCriticalRootAuthorizationReadV1.sol";
import {
    StreamRecordArtistIdentityReads as Identity
} from "../../../smart-contracts/domains/records/StreamRecordArtistIdentityReads.sol";
import {
    StreamArtistArchiveV2 as Archive
} from "../../../smart-contracts/domains/artist/StreamArtistArchiveV2.sol";
import {
    StreamArtistOnboardingTypes as A
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistOnboardingTypes.sol";
import {
    StreamArtistContentTypes as C
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistContentTypes.sol";
import {
    StreamArtistHashes as Hashes
} from "../../../smart-contracts/domains/artist/StreamArtistHashes.sol";
import {
    StreamArtistContentHashes as ContentHashes
} from "../../../smart-contracts/domains/artist/StreamArtistContentHashes.sol";
import {
    IStreamArtistSuiteReads as Suite
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistSuiteReads.sol";
import {
    IStreamArtistContentRecordsOwner as Saved
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistContentOwner.sol";
import {
    IStreamScopedContentRootPublication as Root
} from "../../../smart-contracts/interfaces/stream/metadata/IStreamScopedContentRootPublication.sol";
import {
    IStreamScopedPreservationPolicyContentRootPublicationV1 as PreservationRoot
} from "../../../smart-contracts/interfaces/stream/metadata/IStreamScopedPreservationPolicyContentRootPublicationV1.sol";
import {
    StreamFinalityScope,
    StreamFinalityScopeType
} from "../../../smart-contracts/interfaces/stream/finality/StreamArtworkFinalityTypes.sol";

interface RootAuthorizationFramesVm {
    function mockCall(address target, bytes calldata input, bytes calldata output) external;
    function mockCallRevert(address target, bytes calldata input, bytes calldata output) external;
    function etch(address target, bytes calldata code) external;
    function roll(uint256 number) external;
}

contract RootAuthorizationFramesMarker { }

/// @dev Explicit read boundary, rejecting unconfigured inputs and a changed delegate host.
/// The coordinator boundary also acts as the actual Archive's immutable authorized writer.
contract RootAuthorizationFramesBoundary {
    address private expectedCaller;
    mapping(bytes32 => bytes) private replies;
    mapping(bytes32 => bool) private configured;

    function expectCaller(address caller) external {
        expectedCaller = caller;
    }

    function reply(bytes calldata input, bytes calldata output) external {
        bytes32 key = keccak256(input);
        configured[key] = true;
        replies[key] = output;
    }

    function append(Archive archive, bytes32 id, bytes calldata evidence) external {
        archive.appendArtistEvidenceV2(id, 1, evidence);
    }

    fallback(bytes calldata input) external returns (bytes memory) {
        require(msg.sender == expectedCaller, "original delegate host");
        bytes32 key = keccak256(input);
        require(configured[key], "exact original read");
        return replies[key];
    }
}

contract RootAuthorizationFramesHost {
    function read(
        S.Dependencies memory d,
        Scoped.Context memory c,
        address actor,
        uint64 observedAt,
        Root.Aggregate memory aggregate,
        bytes32 legacyFamily
    ) external view returns (V.Item memory) {
        return Codec.contentItem(d, c, actor, observedAt, aggregate, legacyFamily);
    }
}

/// @notice Source-extraction regression boundary, not a complete Artist authority ceremony.
/// @dev Only Identity.resolve is vm-mocked. Router, suite/configuration and saved consent
/// use exact-call boundary contracts. Archive append, evidence getters, STOP storage and
/// content hash functions are real. No signature verification or replay consumption is claimed.
contract StreamScopedPreservationPolicyRootAuthorizationFramesV1Test {
    RootAuthorizationFramesVm private constant vm =
        RootAuthorizationFramesVm(address(uint160(uint256(keccak256("hevm cheat code")))));
    address private constant ACTOR = address(0x7777);
    uint64 private constant OBSERVED = 90;
    bytes32 private constant ARTIST = keccak256("original artist");
    bytes32 private constant BINDING = keccak256("original binding");
    bytes32 private constant CONFIGURATION = keccak256("original suite configuration");
    bytes4 private constant IDENTITY_SENTINEL = 0x12345678;

    S.Dependencies private d;
    Scoped.Context private context;
    A.SuiteConfiguration private suite;
    Codec.ContentPayload private payload;
    Root.Record private root;
    PreservationRoot.Binding private binding;
    Root.Aggregate private aggregate;
    bytes32 private legacyFamily;
    uint8 private authorityClass;
    bytes private evidence;
    Archive private archive;
    RootAuthorizationFramesBoundary private router;
    RootAuthorizationFramesBoundary private coordinator;
    RootAuthorizationFramesBoundary private owner;

    function setUp() public {
        vm.roll(101);
        for (uint256 i; i < 12; ++i) {
            d.targets[i] = address(new RootAuthorizationFramesMarker());
            d.codeHashes[i] = d.targets[i].codehash;
        }
        router = new RootAuthorizationFramesBoundary();
        coordinator = new RootAuthorizationFramesBoundary();
        owner = new RootAuthorizationFramesBoundary();
        d.targets[4] = address(router);
        d.codeHashes[4] = address(router).codehash;
        d.chainId = block.chainid;
        d.readGas = 500000;
        d.sourceGas = 2000000;
        d.selectionGas = 600001;
        d.snapshotGas = 600002;
        d.referenceGas = 600003;
        suite.registry = address(new RootAuthorizationFramesMarker());
        suite.core = d.targets[0];
        suite.metadata = address(router);
        suite.mintManager = address(new RootAuthorizationFramesMarker());
        suite.roleRegistry = d.targets[2];
        suite.primaryResolver = d.targets[3];
        suite.royaltyResolver = d.targets[6];
        suite.primaryRevenueClass = keccak256("original primary revenue");
        suite.validator = d.targets[8];
        for (uint256 i; i < 7; ++i) {
            suite.owners[i] = address(new RootAuthorizationFramesMarker());
        }
        suite.owners[6] = address(owner);
        d.artistTargets[0] = suite.registry;
        d.artistTargets[1] = address(coordinator);
        d.artistTargets[2] = suite.owners[2];
        d.artistTargets[3] = suite.owners[4];
        for (uint256 i; i < 4; ++i) {
            d.artistCodeHashes[i] = d.artistTargets[i].codehash;
        }
        d.artistContentOwner = address(owner);
        d.artistContentOwnerCodeHash = address(owner).codehash;
        _expectCaller(address(this));
        coordinator.reply(abi.encodeWithSignature("configurationHash()"), abi.encode(CONFIGURATION));
        _identityReply();
        aggregate = Root.Aggregate(7, keccak256("original transition chain"));
        legacyFamily = keccak256("original legacy collection family");
        authorityClass = 1;
        context.scope = StreamFinalityScope(StreamFinalityScopeType.TOKEN, 77, 9, bytes32(0));
        context.artistId = ARTIST;
        context.subject = keccak256("complete context subject");
        context.interviewEvidenceHash = keccak256("complete interview");
        context.nativeHash = keccak256("complete native context");
        context.selectionId = keccak256("complete selection");
        context.selectionHash = keccak256("complete selection hash");
        context.tokenCount = 19;
        payload.binding =
            A.Binding(ARTIST, ACTOR, keccak256("registration"), BINDING, 1, 1, 1, 1, ACTOR, true);
        payload.terms = C.Consent(77, address(router), keccak256("CONTENT_ROOT"), _signedFamily());
        payload.authorization = A.Authorization(42, 100, bytes(""));
        payload.approval = A.SignerApproval(
            ACTOR,
            ContentHashes.consentDigest(_domain(), payload.terms, payload.authorization),
            true
        );
        payload.priorState = keccak256("different original family");
        root.publication = Root.Publication(
            context.scope,
            keccak256("predecessor"),
            keccak256("snapshot"),
            3,
            "ipfs://complete-original-root-with-dynamic-manifest"
        );
        root.snapshotHost = d.targets[5];
        root.snapshotCodeHash = d.codeHashes[5];
        root.snapshotManifestHash = keccak256("snapshot manifest");
        root.snapshotSourceHash = keccak256("snapshot source");
        root.contentRoot = keccak256("content root");
        root.leafCount = 23;
        root.outputManifestHash = keccak256("output manifest");
        root.artistId = ARTIST;
        root.bindingGeneration = 1;
        root.bindingHash = BINDING;
        root.publisher = ACTOR;
        root.authorizationClass = 1;
        root.grantRevision = 5;
        root.routeHash = keccak256("original route");
        root.stateHash = keccak256("original state");
        root.artistConsent = _consentHash();
        root.publishedAt = 110;
        context.snapshot.recordHash = root.publication.snapshotRecordHash;
        context.snapshot.revision = root.publication.snapshotRevision;
        _bindingFixture();
        _bindRoot();
        _savedReply(_saved());
        _archiveWith(_envelope(CONFIGURATION, _body(abi.encode(payload))));
    }

    function testCompleteOriginalConsentItemAndIndependentProvenance() public {
        _assertValid();
        require(payload.approval.digest == _independentDigest(), "original EIP712 schema");
        require(root.artistConsent == _independentConsent(), "original consent record schema");
        require(
            keccak256(archive.artistEvidenceBytesV2(_evidenceId(), 1)) == keccak256(evidence),
            "actual original archive bytes"
        );

        // Exercise the original class-3/non-direct branch with retained dynamic signature bytes.
        // Signature validation already belongs to the producer, outside this read-codec fixture.
        authorityClass = 3;
        payload.authorization.signature = hex"1234567890abcdef010203040506070809";
        payload.approval.direct = false;
        payload.approval.signer = address(0x8888);
        root.artistConsent = _consentHash();
        _bindRoot();
        _savedReply(_saved());
        _archiveWith(_envelope(CONFIGURATION, _body(abi.encode(payload))));
        _assertValid();
        require(root.artistConsent == _independentConsent(), "class-3 record schema");
    }

    function testFullMemoryInputsAndDelegateHostSurviveWorkerFrame() public {
        S.Dependencies memory inputD = d;
        Scoped.Context memory inputC = context;
        Root.Aggregate memory inputAggregate = aggregate;
        bytes32 before_ = keccak256(abi.encode(inputD, inputC, inputAggregate));
        V.Item memory viaFacade =
            Codec.contentItem(inputD, inputC, ACTOR, OBSERVED, inputAggregate, legacyFamily);
        require(keccak256(abi.encode(inputD, inputC, inputAggregate)) == before_, "facade inputs");
        V.Item memory viaWorker =
            Read.contentItem(inputD, inputC, ACTOR, OBSERVED, inputAggregate, legacyFamily);
        require(keccak256(abi.encode(inputD, inputC, inputAggregate)) == before_, "worker inputs");
        require(
            keccak256(abi.encode(viaFacade)) == keccak256(abi.encode(_expected())), "facade item"
        );
        require(
            keccak256(abi.encode(viaWorker)) == keccak256(abi.encode(_expected())), "worker item"
        );
        RootAuthorizationFramesHost host = new RootAuthorizationFramesHost();
        _expectCaller(address(host));
        V.Item memory other =
            host.read(inputD, inputC, ACTOR, OBSERVED, inputAggregate, legacyFamily);
        require(keccak256(abi.encode(other)) == keccak256(abi.encode(viaFacade)), "host item");
        _rejectRead(address(router));
        _expectCaller(address(this));
        _assertValid();
    }

    function testAggregateAndProfileGuardsPrecedeIdentityRead() public {
        vm.mockCallRevert(address(Identity), _identityInput(), abi.encodePacked(IDENTITY_SENTINEL));
        aggregate.revision = 0;
        _reject(V.InvalidInventoryItem.selector);
        aggregate.revision = 7;
        bytes32 chain = aggregate.transitionChain;
        aggregate.transitionChain = 0;
        _reject(V.InvalidInventoryItem.selector);
        aggregate.transitionChain = chain;
        bytes32 profile = binding.profileId;
        binding.profileId = keccak256("wrong profile");
        router.reply(_bindingInput(), abi.encode(binding));
        _reject(V.InvalidInventoryItem.selector);
        binding.profileId = profile;
        router.reply(_bindingInput(), abi.encode(binding));
        _reject(IDENTITY_SENTINEL);
        _identityReply();
        _assertValid();
    }

    function testRootAndBindingRequireCanonicalFullOriginalBytes() public {
        router.reply(_rootInput(), bytes.concat(abi.encode(root), bytes32(0)));
        _rejectRead(address(router));
        router.reply(_rootInput(), abi.encode(root));
        router.reply(_bindingInput(), bytes.concat(abi.encode(binding), bytes32(0)));
        _rejectRead(address(router));
        router.reply(_bindingInput(), abi.encode(binding));
        root.leafCount += 1;
        router.reply(_rootInput(), abi.encode(root));
        _reject(V.InvalidInventoryItem.selector);
        root.leafCount -= 1;
        router.reply(_rootInput(), abi.encode(root));
        bytes32 lastField = binding.preservationOutputProfile;
        binding.preservationOutputProfile = keccak256("different final binding word");
        router.reply(_bindingInput(), abi.encode(binding));
        _reject(V.InvalidInventoryItem.selector);
        binding.preservationOutputProfile = lastField;
        router.reply(_bindingInput(), abi.encode(binding));
        _assertValid();
    }

    function testCanonicalEnvelopePayloadAndConfigurationRefuseThenRestore() public {
        bytes memory valid = evidence;
        _archiveWith(bytes.concat(valid, bytes32(0)));
        _rejectRead(address(archive));
        _archiveWith(valid);
        _assertValid();
        _archiveWith(_envelope(CONFIGURATION, bytes.concat(_body(abi.encode(payload)), bytes32(0))));
        _rejectRead(address(archive));
        _archiveWith(valid);
        _assertValid();
        _archiveWith(_envelope(keccak256("wrong configuration"), _body(abi.encode(payload))));
        _reject(V.InvalidInventoryItem.selector);
        _archiveWith(valid);
        _assertValid();
    }

    function testSavedFullTermsAndDigestRefuseThenRestore() public {
        Saved.ConsentRecord memory changed = _saved();
        changed.terms.familyId = keccak256("different saved family");
        _savedReply(changed);
        _reject(V.InvalidInventoryItem.selector);
        _savedReply(_saved());
        _assertValid();
        bytes memory valid = evidence;
        bytes32 digest = payload.approval.digest;
        payload.approval.digest = keccak256("incorrect approval digest");
        _archiveWith(_envelope(CONFIGURATION, _body(abi.encode(payload))));
        _reject(V.InvalidInventoryItem.selector);
        payload.approval.digest = digest;
        _archiveWith(valid);
        _assertValid();
    }

    function testRetainedStopPrefixAndPayloadCorruptionHaveDistinctRefusals() public {
        (, address pointer,,) = archive.artistEvidenceMetadataV2(_evidenceId(), 1);
        bytes memory original = pointer.code;
        require(original[0] == 0 && original.length == evidence.length + 1, "actual STOP proof");
        bytes memory altered = abi.encodePacked(original);
        altered[0] = 0x01;
        vm.etch(pointer, altered);
        require(
            keccak256(archive.artistEvidenceBytesV2(_evidenceId(), 1)) == keccak256(evidence),
            "prefix-only alteration leaves archive bytes readable"
        );
        _reject(V.InvalidInventoryItem.selector);
        vm.etch(pointer, original);
        _assertValid();
        altered = abi.encodePacked(original);
        altered[altered.length - 1] = bytes1(uint8(altered[altered.length - 1]) ^ uint8(1));
        vm.etch(pointer, altered);
        _rejectRead(address(archive));
        vm.etch(pointer, original);
        _assertValid();
    }

    function read() external view returns (V.Item memory) {
        return Codec.contentItem(d, context, ACTOR, OBSERVED, aggregate, legacyFamily);
    }

    function _bindingFixture() private {
        binding.profileId = keccak256("6529STREAM_SCOPED_PRESERVATION_POLICY_CONTENT_ROOT_V1");
        binding.outputManifest = d.targets[6];
        binding.outputManifestCodeHash = d.codeHashes[6];
        binding.checkpoint = d.targets[7];
        binding.checkpointCodeHash = d.codeHashes[7];
        binding.checkpointHash = keccak256("checkpoint");
        binding.checkpointStateHash = keccak256("checkpoint state");
        binding.entropySourceSet = d.targets[8];
        binding.entropySourceSetCodeHash = d.codeHashes[8];
        binding.inventoryHash = keccak256("inventory");
        binding.policyChainHash = keccak256("policy chain");
        binding.outputRoot = keccak256("output root");
        binding.outputSchemaHash = keccak256("output schema");
        binding.outputCanonicalizationHash = keccak256("output canonicalization");
        binding.leafSchemaHash = keccak256("leaf schema");
        binding.rootSchemaHash = keccak256("root schema");
        binding.rootCanonicalizationHash = keccak256("root canonicalization");
        binding.sourceFactory = d.targets[9];
        binding.sourceFactoryCodeHash = d.codeHashes[9];
        binding.factoryDependenciesHash = keccak256("factory dependencies");
        binding.snapshotSchemaHash = keccak256("snapshot schema");
        binding.snapshotProfileHash = keccak256("snapshot profile");
        binding.snapshotCanonicalizationHash = keccak256("snapshot canonicalization");
        binding.metadataRouter = address(router);
        binding.preservationOutputProfile = keccak256("6529STREAM_PRESERVATION_RENDER_V1");
    }

    function _expectCaller(address caller) private {
        router.expectCaller(caller);
        coordinator.expectCaller(caller);
        owner.expectCaller(caller);
    }

    function _identityInput() private view returns (bytes memory) {
        // Use the declared library selector; do not reconstruct a tuple ABI signature.
        return abi.encodeWithSelector(
            Identity.resolve.selector, d.targets[1], d.targets[0], d.chainId, d.readGas
        );
    }

    function _identityReply() private {
        Identity.Pins memory pins;
        for (uint256 i; i < 3; ++i) {
            pins.targets[i] = d.artistTargets[i];
            pins.codeHashes[i] = d.artistCodeHashes[i];
        }
        vm.mockCall(address(Identity), _identityInput(), abi.encode(pins));
    }

    function _rootInput() private view returns (bytes memory) {
        return abi.encodeCall(Root.scopedContentRootRecord, (context.rootRecordHash));
    }

    function _bindingInput() private view returns (bytes memory) {
        return abi.encodeCall(
            PreservationRoot.scopedPreservationPolicyContentRootBinding, (context.rootRecordHash)
        );
    }

    function _bindRoot() private {
        context.rootRecordHash = keccak256(
            abi.encode(
                keccak256("6529STREAM_SCOPED_PRESERVATION_POLICY_CONTENT_ROOT_RECORD_V1"),
                d.chainId,
                d.targets[4],
                d.targets[0],
                root,
                binding,
                aggregate
            )
        );
        router.reply(_rootInput(), abi.encode(root));
        router.reply(_bindingInput(), abi.encode(binding));
    }

    function _saved() private view returns (Saved.ConsentRecord memory) {
        return Saved.ConsentRecord(root.artistConsent, ARTIST, 1, payload.terms, authorityClass);
    }

    function _savedReply(Saved.ConsentRecord memory saved) private {
        owner.reply(
            abi.encodeCall(Saved.contentConsentRecord, (root.artistConsent)), abi.encode(saved)
        );
    }

    function _envelope(bytes32 configuration, bytes memory content)
        private
        view
        returns (bytes memory)
    {
        Codec.Envelope memory envelope;
        envelope.version = 1;
        envelope.configurationHash = configuration;
        envelope.operationId = 17;
        envelope.actor = ACTOR;
        envelope.record = root.artistConsent;
        for (uint256 i; i < 7; ++i) {
            envelope.before_[i] = A.Snapshot(
                keccak256(abi.encode("domain", i)),
                uint64(i + 1),
                keccak256(abi.encode("before state", i)),
                keccak256(abi.encode("before chain", i))
            );
            envelope.after_[i] = A.Snapshot(
                envelope.before_[i].domainId,
                uint64(i + 2),
                keccak256(abi.encode("after state", i)),
                keccak256(abi.encode("after chain", i))
            );
        }
        envelope.payload = content;
        return _body(abi.encode(envelope));
    }

    function _archiveWith(bytes memory raw) private {
        // Each negative vector uses a fresh immutable Archive, never overwrites saved evidence.
        archive = new Archive(suite.registry, address(coordinator));
        suite.archive = address(archive);
        d.artistTargets[4] = address(archive);
        d.artistCodeHashes[4] = address(archive).codehash;
        coordinator.reply(abi.encodeCall(Suite.suiteConfiguration, ()), abi.encode(suite));
        evidence = raw;
        coordinator.append(archive, _evidenceId(), raw);
    }

    function _evidenceId() private view returns (bytes32) {
        return keccak256(
            abi.encode(
                keccak256("6529STREAM_ARTIST_ONBOARDING_OPERATION_EVIDENCE_V1"),
                d.chainId,
                suite.registry,
                address(coordinator),
                uint16(17),
                ACTOR,
                root.artistConsent
            )
        );
    }

    function _domain() private view returns (Hashes.Environment memory) {
        return Hashes.Environment(d.chainId, suite.registry, d.targets[0], suite.mintManager);
    }

    function _consentHash() private view returns (bytes32) {
        return ContentHashes.consentRecord(
            _domain(),
            payload.terms,
            ARTIST,
            payload.approval.signer,
            authorityClass,
            payload.authorization.nonce,
            OBSERVED
        );
    }

    function _signedFamily() private view returns (bytes32) {
        return keccak256(
            abi.encode(
                keccak256("6529STREAM_CONTENT_ROOT_FAMILY_WITH_SCOPES_V1"),
                d.chainId,
                d.targets[4],
                d.targets[0],
                uint256(77),
                legacyFamily,
                aggregate
            )
        );
    }

    function _independentDigest() private view returns (bytes32) {
        bytes32 domain = keccak256(
            abi.encode(
                keccak256(
                    "EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"
                ),
                keccak256("6529StreamArtistRegistry"),
                keccak256("1"),
                d.chainId,
                suite.registry
            )
        );
        bytes32 body = keccak256(
            abi.encode(
                keccak256(
                    "StreamArtistContentConsent(address core,address metadataContract,uint256 collectionId,bytes32 familyId,bytes32 newStateHash,uint256 nonce,uint64 deadline)"
                ),
                d.targets[0],
                payload.terms.metadataContract,
                payload.terms.collectionId,
                payload.terms.familyId,
                payload.terms.newStateHash,
                payload.authorization.nonce,
                payload.authorization.time
            )
        );
        return keccak256(abi.encodePacked(hex"1901", domain, body));
    }

    function _independentConsent() private view returns (bytes32) {
        return keccak256(
            abi.encode(
                keccak256("6529STREAM_ARTIST_CONTENT_CONSENT_RECORD_V1"),
                d.chainId,
                suite.registry,
                payload.terms.metadataContract,
                d.targets[0],
                payload.terms.collectionId,
                payload.terms.familyId,
                payload.terms.newStateHash,
                ARTIST,
                payload.approval.signer,
                authorityClass,
                payload.authorization.nonce,
                OBSERVED
            )
        );
    }

    function _expected() private view returns (V.Item memory expected) {
        (bytes32 hash, address pointer, uint32 size, uint64 appendedAt) =
            archive.artistEvidenceMetadataV2(_evidenceId(), 1);
        require(
            hash == keccak256(evidence) && size == evidence.length && appendedAt == 101,
            "retained facts"
        );
        bytes32 retained = keccak256(
            abi.encode(
                _evidenceId(),
                keccak256(evidence),
                pointer,
                pointer.codehash,
                uint32(evidence.length),
                uint64(101)
            )
        );
        expected.kind = V.Kind.STATE_BUNDLE;
        expected.role =
            keccak256("ORIGINAL_SCOPED_PRESERVATION_POLICY_CONTENT_ROOT_AUTHORIZATION_V1");
        expected.source = address(archive);
        expected.sourceRecord = _evidenceId();
        expected.sourceIndex = 1;
        expected.algorithm = 1;
        expected.canonicalizationId = keccak256("RAW_BYTES");
        expected.digest = abi.encodePacked(keccak256(evidence));
        expected.byteSize = uint64(evidence.length);
        expected.provenanceHash = keccak256(
            abi.encode(
                context.rootRecordHash,
                binding,
                aggregate,
                legacyFamily,
                _signedFamily(),
                ACTOR,
                OBSERVED,
                retained,
                keccak256(abi.encode(d))
            )
        );
    }

    function _assertValid() private view {
        V.Item memory actual =
            Codec.contentItem(d, context, ACTOR, OBSERVED, aggregate, legacyFamily);
        require(
            keccak256(abi.encode(actual)) == keccak256(abi.encode(_expected())), "all item fields"
        );
    }

    function _body(bytes memory wrapped) private pure returns (bytes memory result) {
        result = new bytes(wrapped.length - 32);
        for (uint256 i; i < result.length; ++i) {
            result[i] = wrapped[i + 32];
        }
    }

    function _reject(bytes4 selector) private view {
        (bool ok, bytes memory reason) = address(this).staticcall(abi.encodeCall(this.read, ()));
        require(!ok && reason.length >= 4 && bytes4(reason) == selector, "exact codec rejection");
    }

    function _rejectRead(address target) private view {
        (bool ok, bytes memory reason) = address(this).staticcall(abi.encodeCall(this.read, ()));
        require(
            !ok
                && keccak256(reason)
                    == keccak256(abi.encodeWithSelector(V.InventoryRead.selector, target)),
            "exact failing read target"
        );
    }
}
