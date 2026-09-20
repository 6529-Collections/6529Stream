// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamPreservationPolicyRootFamiliesV2 as FamilySchemas
} from "../../../smart-contracts/domains/finality/StreamPreservationPolicyRootFamiliesV2.sol";
import {
    StreamMultiOriginScopedPreservationPolicyRootAuthorizationV1 as Codec
} from "../../../smart-contracts/domains/preservation/StreamMultiOriginScopedPreservationPolicyRootAuthorizationV1.sol";
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
    StreamScopedPreservationPolicyRenderCriticalTypesV1 as Scoped
} from "../../../smart-contracts/interfaces/stream/preservation/StreamScopedPreservationPolicyRenderCriticalTypesV1.sol";
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
    IStreamScopedContentRootPublication as Root
} from "../../../smart-contracts/interfaces/stream/metadata/IStreamScopedContentRootPublication.sol";
import {
    IStreamScopedPreservationPolicyContentRootPublicationV1 as PreservationRoot
} from "../../../smart-contracts/interfaces/stream/metadata/IStreamScopedPreservationPolicyContentRootPublicationV1.sol";
import {
    StreamFinalityScope,
    StreamFinalityScopeType
} from "../../../smart-contracts/interfaces/stream/finality/StreamArtworkFinalityTypes.sol";

interface ScopedPreservationRootVm {
    function mockCall(address target, bytes calldata input, bytes calldata output) external;
    function mockCallRevert(address target, bytes calldata input, bytes calldata reason) external;
    function etch(address target, bytes calldata code) external;
}

contract ScopedPreservationRootMarker { }

contract ScopedPreservationRootStop {
    constructor(bytes memory payload) {
        bytes memory runtime = bytes.concat(hex"00", payload);
        assembly ("memory-safe") { return(add(runtime, 32), mload(runtime)) }
    }
}

/// @dev Explicit Archive boundary with actual immutable STOP byte retention, not the production
/// Archive's authorization or append-only writer. Mutations below are negative-test controls.
contract ScopedPreservationRootArchive {
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
        pointer = address(new ScopedPreservationRootStop(payload));
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

/// @notice Genuine preservation root/envelope/digest/Archive/STOP codec with an explicit Proof boundary.
/// @dev Proof admission, Router record, suite and saved consent are typed mocked boundaries.
/// No actual import admission, current authority resolution, Safe/op60 or full ceremony is claimed.
contract StreamMultiOriginScopedPreservationPolicyRootAuthorizationV1Test {
    ScopedPreservationRootVm private constant vm =
        ScopedPreservationRootVm(address(uint160(uint256(keccak256("hevm cheat code")))));
    bytes32 private constant ARTIST = keccak256("preservation boundary artist");
    bytes32 private constant BINDING = keccak256("original accepted binding");
    bytes32 private constant CONTEXT = keccak256("actual source-context boundary");
    bytes32 private constant CONFIGURATION = keccak256("original coordinator configuration");
    bytes32 private constant ROLE =
        keccak256("ORIGINAL_SCOPED_PRESERVATION_POLICY_CONTENT_ROOT_AUTHORIZATION_V1");
    address private constant ACTOR = address(7777);
    uint64 private constant OBSERVED = 90;
    S.Dependencies private d;
    Scoped.Context private context;
    Root.Aggregate private aggregate;
    bytes32 private legacyFamily;
    A.SuiteConfiguration private suite;
    O.RecordOrigin private fact;
    O.ReceiptWitness private witness;
    Codec.ContentPayload private payload;
    Root.Record private root;
    PreservationRoot.Binding private binding;
    ScopedPreservationRootArchive private originalArchive;
    ScopedPreservationRootArchive private currentArchive;
    bytes private evidence;

    function read() external view returns (V.Item memory, O.RecordOrigin memory) {
        return
            Codec.contentItem(
                d, context, ACTOR, OBSERVED, aggregate, legacyFamily, CONTEXT, witness
            );
    }

    function testImportedOccurrenceRetainsOriginalDomainAndExactNewRoleProvenance() public {
        _fixture(O.Lane.IMPORTED, StreamFinalityScopeType.TOKEN);
        bytes32 callerPins = keccak256(abi.encode(d));
        (V.Item memory item, O.RecordOrigin memory got) = this.read();
        O.RecordOrigin memory expected = fact;
        expected.role = ROLE;
        require(
            keccak256(abi.encode(got)) == keccak256(abi.encode(expected)),
            "only fixed role is added"
        );
        require(
            item.kind == V.Kind.STATE_BUNDLE && item.role == ROLE
                && item.source == address(originalArchive)
        );
        require(
            item.source != address(currentArchive) && item.sourceRecord == O.evidenceId(fact)
                && item.sourceIndex == 1
        );
        require(
            item.algorithm == 1 && item.canonicalizationId == keccak256("RAW_BYTES")
                && item.byteSize == evidence.length
        );
        require(keccak256(item.digest) == keccak256(abi.encodePacked(keccak256(evidence))));
        require(
            item.provenanceHash == _expectedProvenance(expected),
            "exact old provenance plus fixed new certificate"
        );
        require(
            keccak256(abi.encode(d)) == callerPins && d.artistTargets[4] == address(currentArchive)
        );
    }

    function testNativeReceiptAndAllSupportedScopesPreserveExactCapsule() public {
        StreamFinalityScopeType[3] memory kinds = [
            StreamFinalityScopeType.TOKEN,
            StreamFinalityScopeType.RELEASE,
            StreamFinalityScopeType.SEASON
        ];
        for (uint256 i; i < kinds.length; ++i) {
            _fixture(O.Lane.NATIVE, kinds[i]);
            (V.Item memory item, O.RecordOrigin memory got) = this.read();
            require(got.importCommitment == 0 && got.importedAtRevision == 0 && got.role == ROLE);
            require(
                got.actor == ACTOR && got.semanticRecordHash == fact.semanticRecordHash
                    && item.provenanceHash == _expectedProvenance(got)
            );
        }
    }

    function testWrongAggregateRejectsBeforeCallingProof() public {
        _fixture(O.Lane.IMPORTED, StreamFinalityScopeType.TOKEN);
        vm.mockCallRevert(
            address(Proof), _proofInput(), abi.encodeWithSelector(O.ArchiveOriginLimit.selector)
        );
        aggregate.transitionChain = keccak256("another original aggregate");
        _reject(V.InvalidInventoryItem.selector);
    }

    function testWrongLegacyFamilyRejectsOriginalConsentJoin() public {
        _fixture(O.Lane.IMPORTED, StreamFinalityScopeType.TOKEN);
        legacyFamily = keccak256("wrong collection family");
        _reject(V.InvalidInventoryItem.selector);
    }

    function testPreservationProfileRouterAndOutputProfileAreMandatory() public {
        for (uint8 mode; mode < 3; ++mode) {
            _fixture(O.Lane.IMPORTED, StreamFinalityScopeType.TOKEN);
            if (mode == 0) {
                binding.profileId = keccak256("6529STREAM_SCOPED_POLICY_CONTENT_ROOT_V2");
            } else if (mode == 1) {
                binding.metadataRouter = d.targets[0];
            } else {
                binding.preservationOutputProfile = keccak256("unrelated render profile");
            }
            _bindRoot(); // Rehash the whole record so the explicit profile/Router checks are exercised.
            _reject(V.InvalidInventoryItem.selector);
        }
    }

    function testScopeSnapshotAndArtistMustMatchTypedContext() public {
        for (uint8 mode; mode < 3; ++mode) {
            _fixture(O.Lane.IMPORTED, StreamFinalityScopeType.TOKEN);
            if (mode == 0) context.scope.tokenId += 1;
            else if (mode == 1) context.snapshot.revision += 1;
            else context.artistId = keccak256("other artist");
            _reject(V.InvalidInventoryItem.selector);
        }
    }

    function testBindingGetterRequiresExactlyEightHundredBytes() public {
        _fixture(O.Lane.IMPORTED, StreamFinalityScopeType.TOKEN);
        bytes memory raw = abi.encode(binding);
        require(raw.length == 800);
        bytes memory short = new bytes(736);
        for (uint256 i; i < short.length; ++i) {
            short[i] = raw[i];
        }
        vm.mockCall(d.targets[4], _bindingInput(), short);
        _reject(V.InventoryRead.selector);
        vm.mockCall(d.targets[4], _bindingInput(), bytes.concat(raw, bytes32(0)));
        _reject(V.InventoryRead.selector);
    }

    function testRootGetterRejectsTrailingBytes() public {
        _fixture(O.Lane.IMPORTED, StreamFinalityScopeType.TOKEN);
        vm.mockCall(
            d.targets[4],
            abi.encodeCall(Root.scopedContentRootRecord, (context.rootRecordHash)),
            bytes.concat(abi.encode(root), bytes32(0))
        );
        _reject(V.InventoryRead.selector);
    }

    function testProofFailureBubblesByteExactlyWithoutArchiveFallback() public {
        _fixture(O.Lane.IMPORTED, StreamFinalityScopeType.TOKEN);
        bytes memory reason =
            abi.encodeWithSelector(O.ArchiveOriginChanged.selector, d.artistContentOwner);
        vm.mockCallRevert(address(Proof), _proofInput(), reason);
        (bool ok, bytes memory got) = address(this).staticcall(abi.encodeCall(this.read, ()));
        require(!ok && keccak256(got) == keccak256(reason));
    }

    function testSavedConsentFullTermsCannotBeReplacedByMatchingRecordHash() public {
        _fixture(O.Lane.IMPORTED, StreamFinalityScopeType.TOKEN);
        Saved.ConsentRecord memory saved = _saved();
        saved.terms.newStateHash = keccak256("wrong terms");
        vm.mockCall(
            suite.owners[6],
            abi.encodeCall(Saved.contentConsentRecord, (_consentHash())),
            abi.encode(saved)
        );
        _reject(V.InvalidInventoryItem.selector);
    }

    function testEnvelopeConfigurationAndOriginalDigestRemainMandatory() public {
        _fixture(O.Lane.IMPORTED, StreamFinalityScopeType.TOKEN);
        _saveEnvelope(keccak256("replacement configuration"));
        _reject(V.InvalidInventoryItem.selector);
        _fixture(O.Lane.IMPORTED, StreamFinalityScopeType.TOKEN);
        payload.approval.digest = keccak256("signature under replacement registry");
        _saveEnvelope(CONFIGURATION);
        _reject(V.InvalidInventoryItem.selector);
    }

    function testNonCanonicalEnvelopeAndCorruptRetentionReject() public {
        _fixture(O.Lane.IMPORTED, StreamFinalityScopeType.TOKEN);
        originalArchive.save(O.evidenceId(fact), bytes.concat(evidence, bytes32(0)));
        _reject(V.InventoryRead.selector);
        _fixture(O.Lane.IMPORTED, StreamFinalityScopeType.TOKEN);
        originalArchive.setCorruptMetadata(true);
        _reject(V.InvalidInventoryItem.selector);
        originalArchive.setCorruptMetadata(false);
        vm.etch(originalArchive.pointer(), hex"0001");
        _reject(V.InvalidInventoryItem.selector);
    }

    function testOriginalRuntimePinAndReciprocalArchiveRemainMandatory() public {
        _fixture(O.Lane.IMPORTED, StreamFinalityScopeType.TOKEN);
        vm.etch(suite.owners[6], hex"6001600055");
        _reject(V.InventoryRead.selector);
        _fixture(O.Lane.IMPORTED, StreamFinalityScopeType.TOKEN);
        vm.mockCall(
            address(originalArchive),
            abi.encodeWithSignature("operationCoordinator()"),
            abi.encode(address(currentArchive))
        );
        _reject(V.InvalidInventoryItem.selector);
    }

    function testFamilyV2ImportedRootRetainsOriginalArchiveAndExactConsent() public {
        _fixture(O.Lane.IMPORTED, StreamFinalityScopeType.TOKEN);
        _useFamilyV2();
        (V.Item memory item, O.RecordOrigin memory got) = this.read();
        O.RecordOrigin memory expected = fact;
        expected.role = ROLE;
        require(keccak256(abi.encode(got)) == keccak256(abi.encode(expected)));
        require(item.source == address(originalArchive) && item.source != address(currentArchive));
        require(item.provenanceHash == _expectedProvenance(expected));
    }

    function testFamilyV2NativeRootRetainsOriginalArchive() public {
        _fixture(O.Lane.NATIVE, StreamFinalityScopeType.RELEASE);
        _useFamilyV2();
        (V.Item memory item, O.RecordOrigin memory got) = this.read();
        require(item.source == address(originalArchive) && got.role == ROLE);
        require(item.provenanceHash == _expectedProvenance(got));
    }

    function testFamilyV2RejectsWrongSchemaBeforeOccurrenceProof() public {
        _fixture(O.Lane.IMPORTED, StreamFinalityScopeType.TOKEN);
        _useFamilyV2();
        binding.outputSchemaHash = keccak256("wrong family schema");
        _bindRoot();
        vm.mockCallRevert(address(Proof), _proofInput(), hex"12345678");
        _reject(V.InvalidInventoryItem.selector);
    }

    function testFamilyV2RejectsCrossFamilyContextBeforeOccurrenceProof() public {
        _fixture(O.Lane.IMPORTED, StreamFinalityScopeType.TOKEN);
        _useFamilyV2();
        context.snapshotSource.content.preservationProfile = FamilySchemas.V1;
        vm.mockCallRevert(address(Proof), _proofInput(), hex"12345678");
        _reject(V.InvalidInventoryItem.selector);
    }

    function testFamilyV2RejectsV1RootProfileBeforeOccurrenceProof() public {
        _fixture(O.Lane.IMPORTED, StreamFinalityScopeType.TOKEN);
        _useFamilyV2();
        binding.profileId = FamilySchemas.profile(FamilySchemas.V1, true);
        _bindRoot();
        vm.mockCallRevert(address(Proof), _proofInput(), hex"12345678");
        _reject(V.InvalidInventoryItem.selector);
    }

    function _useFamilyV2() private {
        binding.preservationOutputProfile = FamilySchemas.V2;
        binding.profileId = FamilySchemas.profile(FamilySchemas.V2, true);
        bytes32[5] memory ids = FamilySchemas.ids(FamilySchemas.V2, true);
        binding.outputSchemaHash = FamilySchemas.definitionHash(FamilySchemas.V2, true, ids[0]);
        binding.outputCanonicalizationHash =
            FamilySchemas.definitionHash(FamilySchemas.V2, true, ids[1]);
        binding.leafSchemaHash = FamilySchemas.definitionHash(FamilySchemas.V2, true, ids[2]);
        binding.rootSchemaHash = FamilySchemas.definitionHash(FamilySchemas.V2, true, ids[3]);
        binding.rootCanonicalizationHash =
            FamilySchemas.definitionHash(FamilySchemas.V2, true, ids[4]);
        binding.outputRoot = keccak256("complete family output root");
        binding.checkpointHash = keccak256("family checkpoint");
        binding.checkpointStateHash = keccak256("complete family plan");
        context.snapshotSource.content.preservationProfile = FamilySchemas.V2;
        context.snapshotSource.outputs.preservationProfile = FamilySchemas.V2;
        context.snapshotSource.outputs.outputRoot = binding.outputRoot;
        context.snapshotSource.outputs.checkpointHash = binding.checkpointHash;
        context.snapshotSource.outputs.checkpointStateHash = binding.checkpointStateHash;
        _bindRoot();
    }

    function _fixture(O.Lane lane, StreamFinalityScopeType kind) private {
        delete d;
        delete context;
        delete suite;
        delete fact;
        delete payload;
        delete root;
        delete binding;
        for (uint256 i; i < 12; ++i) {
            d.targets[i] = address(new ScopedPreservationRootMarker());
            d.codeHashes[i] = d.targets[i].codehash;
        }
        d.chainId = block.chainid;
        d.readGas = 500000;
        d.sourceGas = 2000000;
        address registry = address(new ScopedPreservationRootMarker());
        address coordinator = address(new ScopedPreservationRootMarker());
        originalArchive = new ScopedPreservationRootArchive(registry, coordinator);
        currentArchive = new ScopedPreservationRootArchive(
            address(new ScopedPreservationRootMarker()), address(new ScopedPreservationRootMarker())
        );
        suite.registry = registry;
        suite.archive = address(originalArchive);
        suite.core = d.targets[0];
        suite.metadata = d.targets[4];
        suite.mintManager = address(new ScopedPreservationRootMarker());
        for (uint8 i; i < 7; ++i) {
            suite.owners[i] = address(new ScopedPreservationRootMarker());
        }
        for (uint256 i; i < 5; ++i) {
            d.artistTargets[i] = address(new ScopedPreservationRootMarker());
            d.artistCodeHashes[i] = d.artistTargets[i].codehash;
        }
        d.artistTargets[4] = address(currentArchive);
        d.artistCodeHashes[4] = address(currentArchive).codehash;
        d.artistContentOwner = address(new ScopedPreservationRootMarker());
        d.artistContentOwnerCodeHash = d.artistContentOwner.codehash;
        vm.mockCall(coordinator, abi.encodeWithSignature("suiteConfiguration()"), abi.encode(suite));
        vm.mockCall(
            coordinator, abi.encodeWithSignature("configurationHash()"), abi.encode(CONFIGURATION)
        );
        RH.OriginEnvironment memory env;
        env.chainId = block.chainid;
        env.registry = registry;
        env.coordinator = coordinator;
        env.archive = address(originalArchive);
        env.owners = suite.owners;
        for (uint8 i; i < 7; ++i) {
            env.ownerCodeHashes[i] = suite.owners[i].codehash;
        }
        env.core = suite.core;
        env.manager = suite.mintManager;
        env.suiteConfigurationHash = keccak256(abi.encode(suite));
        fact.producer = O.Origin(
            env, registry.codehash, coordinator.codehash, address(originalArchive).codehash
        );
        aggregate = Root.Aggregate(7, keccak256("actual original aggregate"));
        legacyFamily = keccak256("actual legacy collection family");
        payload.binding =
            A.Binding(ARTIST, ACTOR, keccak256("registration"), BINDING, 1, 1, 1, 1, ACTOR, true);
        payload.terms = C.Consent(77, d.targets[4], keccak256("CONTENT_ROOT"), _signedFamily());
        payload.authorization = A.Authorization(42, 100, bytes(""));
        payload.approval = A.SignerApproval(
            ACTOR,
            ContentHashes.consentDigest(_domain(), payload.terms, payload.authorization),
            true
        );
        payload.priorState = keccak256("distinct previous family");
        root.publication = Root.Publication(
            StreamFinalityScope(
                kind,
                77,
                kind == StreamFinalityScopeType.TOKEN ? 9 : 0,
                kind == StreamFinalityScopeType.TOKEN ? bytes32(0) : keccak256("scope membership")
            ),
            keccak256("old root"),
            keccak256("original snapshot"),
            1,
            "ipfs://typed-preservation-boundary"
        );
        root.snapshotHost = d.targets[5];
        root.snapshotCodeHash = d.codeHashes[5];
        root.artistId = ARTIST;
        root.bindingGeneration = 1;
        root.bindingHash = BINDING;
        root.stateHash = keccak256("state");
        root.artistConsent = _consentHash();
        root.publishedAt = 110;
        binding.profileId = keccak256("6529STREAM_SCOPED_PRESERVATION_POLICY_CONTENT_ROOT_V1");
        binding.metadataRouter = d.targets[4];
        binding.preservationOutputProfile = keccak256("6529STREAM_PRESERVATION_RENDER_V1");
        binding.checkpoint = d.targets[7];
        binding.checkpointCodeHash = d.codeHashes[7];
        binding.checkpointHash = keccak256("checkpoint");
        binding.snapshotSchemaHash = keccak256("snapshot schema boundary");
        context.scope = root.publication.scope;
        context.artistId = ARTIST;
        context.snapshot.recordHash = root.publication.snapshotRecordHash;
        context.snapshot.revision = 1;
        _bindRoot();
        witness = O.ReceiptWitness(lane, 2);
        fact.occurrence.position = RH.Position(RH.Point(RH.originHash(env), 6, 9), 2);
        fact.occurrence.receipt = H.Receipt(17, ARTIST, 77, _consentHash());
        if (lane == O.Lane.IMPORTED) {
            fact.importCommitment = keccak256("explicit imported proof boundary");
            fact.importedAtRevision = 3;
        }
        fact.actor = ACTOR;
        fact.semanticRecordHash = keccak256(abi.encode(_saved()));
        fact.role = keccak256("ORIGINAL_SCOPED_POLICY_CONTENT_ROOT_AUTHORIZATION_V2");
        fact.sourceContextHash = CONTEXT;
        vm.mockCall(
            suite.owners[6],
            abi.encodeCall(Saved.contentConsentRecord, (_consentHash())),
            abi.encode(_saved())
        );
        vm.mockCall(address(Proof), _proofInput(), abi.encode(fact));
        _saveEnvelope(CONFIGURATION);
        currentArchive.save(O.evidenceId(fact), bytes("wrong current Archive payload"));
    }

    function _bindRoot() private {
        context.rootRecordHash = keccak256(
            abi.encode(
                binding.preservationOutputProfile == FamilySchemas.V2
                    ? FamilySchemas.recordDomain(FamilySchemas.V2, true)
                    : keccak256("6529STREAM_SCOPED_PRESERVATION_POLICY_CONTENT_ROOT_RECORD_V1"),
                block.chainid,
                d.targets[4],
                d.targets[0],
                root,
                binding,
                aggregate
            )
        );
        vm.mockCall(
            d.targets[4],
            abi.encodeCall(Root.scopedContentRootRecord, (context.rootRecordHash)),
            abi.encode(root)
        );
        vm.mockCall(d.targets[4], _bindingInput(), abi.encode(binding));
    }

    function _saveEnvelope(bytes32 configuration) private {
        Codec.Envelope memory envelope;
        envelope.version = 1;
        envelope.configurationHash = configuration;
        envelope.operationId = 17;
        envelope.actor = ACTOR;
        envelope.record = _consentHash();
        envelope.payload = _body(abi.encode(payload));
        evidence = _body(abi.encode(envelope));
        originalArchive.save(O.evidenceId(fact), evidence);
    }

    function _proofInput() private view returns (bytes memory) {
        return abi.encodeWithSelector(
            Proof.contentOrigin.selector,
            d,
            uint256(77),
            ARTIST,
            _consentHash(),
            ACTOR,
            O.ContentRole.POLICY_SCOPED,
            CONTEXT,
            witness
        );
    }

    function _bindingInput() private view returns (bytes memory) {
        return abi.encodeCall(
            PreservationRoot.scopedPreservationPolicyContentRootBinding, (context.rootRecordHash)
        );
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

    function _signedFamily() private view returns (bytes32) {
        return keccak256(
            abi.encode(
                keccak256("6529STREAM_CONTENT_ROOT_FAMILY_WITH_SCOPES_V1"),
                block.chainid,
                d.targets[4],
                d.targets[0],
                uint256(77),
                legacyFamily,
                aggregate
            )
        );
    }

    function _expectedProvenance(O.RecordOrigin memory expected) private view returns (bytes32) {
        S.Dependencies memory original = d;
        original.artistTargets = [
            suite.registry,
            expected.producer.environment.coordinator,
            suite.owners[2],
            suite.owners[4],
            suite.archive
        ];
        original.artistCodeHashes = [
            expected.producer.registryCodeHash,
            expected.producer.coordinatorCodeHash,
            expected.producer.environment.ownerCodeHashes[2],
            expected.producer.environment.ownerCodeHashes[4],
            expected.producer.archiveCodeHash
        ];
        original.artistContentOwner = suite.owners[6];
        original.artistContentOwnerCodeHash = suite.owners[6].codehash;
        address pointer = originalArchive.pointer();
        bytes32 retained = keccak256(
            abi.encode(
                O.evidenceId(fact),
                keccak256(evidence),
                pointer,
                pointer.codehash,
                uint32(evidence.length),
                uint64(1)
            )
        );
        bytes32 oldProvenance = keccak256(
            abi.encode(
                context.rootRecordHash,
                binding,
                aggregate,
                legacyFamily,
                _signedFamily(),
                ACTOR,
                OBSERVED,
                retained,
                keccak256(abi.encode(original))
            )
        );
        return keccak256(abi.encode(O.PROFILE, oldProvenance, O.recordOriginHash(expected)));
    }

    function _body(bytes memory wrapped) private pure returns (bytes memory result) {
        result = new bytes(wrapped.length - 32);
        for (uint256 i; i < result.length; ++i) {
            result[i] = wrapped[i + 32];
        }
    }

    function _reject(bytes4 selector) private view {
        (bool ok, bytes memory reason) = address(this).staticcall(abi.encodeCall(this.read, ()));
        require(
            !ok && reason.length >= 4 && bytes4(reason) == selector,
            "exact expected codec rejection"
        );
    }
}
