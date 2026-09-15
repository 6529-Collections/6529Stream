// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./StreamCollectionMetadataV1.t.sol";
import {
    StreamArtistRecordPublicationReads
} from "../../../smart-contracts/domains/artist/StreamArtistRecordPublicationReads.sol";

contract MetadataRouterForSuccessorBoundary {
    address public immutable core;

    constructor(address core_) {
        core = core_;
    }
}

contract MetadataPublicationModulesBoundary {
    address public immutable host;

    constructor(address host_) {
        host = host_;
    }

    function isModuleEligible(address value, bytes32 kind, bytes4 id) external view returns (bool) {
        return value == host && kind == keccak256("COLLECTION_METADATA")
            && id == type(IStreamCollectionMetadataV1).interfaceId;
    }
}

contract MetadataPublicationBudgetProbe {
    function candidate(T.SuiteConfiguration memory suite, P.Publication memory p)
        external
        view
        returns (bytes32)
    {
        return StreamArtistRecordPublicationReads.candidate(suite, p);
    }
}

import {
    StreamArtistOnboardingTypes as T
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistOnboardingTypes.sol";

// Explicit typed lineage boundaries. Metadata, schemas, byte store and Safe are real contracts;
// these controls do not claim execution of Artist operations55–57/60 or signature admission.
contract MetadataHydrationCoordinatorBoundary {
    T.SuiteConfiguration private suite;

    function configure(T.SuiteConfiguration memory s) external {
        suite = s;
    }

    function authorityHydrationSuite() external view returns (T.SuiteConfiguration memory) {
        return suite;
    }
}

contract MetadataHydratedOwnerBoundary {
    address public artistRegistry;
    address public operationCoordinator;
    address public archiveV2;
    address public core;
    address public mintManager;
    uint256 public deploymentChainId;
    bytes32 public domainId;
    bytes32 public authorityHydrationCommitment;

    constructor(
        T.SuiteConfiguration memory s,
        address coordinator,
        uint256 index,
        bytes32 commitment
    ) {
        artistRegistry = s.registry;
        operationCoordinator = coordinator;
        archiveV2 = s.archive;
        core = s.core;
        mintManager = s.mintManager;
        deploymentChainId = block.chainid;
        domainId = keccak256(abi.encode("fixture owner", index));
        authorityHydrationCommitment = commitment;
    }

    function setCompletion(bytes32 value) external {
        authorityHydrationCommitment = value;
    }

    function setCore(address value) external {
        core = value;
    }

    function setDomain(bytes32 value) external {
        domainId = value;
    }
}

contract MetadataSuccessorArtistBoundary is MetadataArtistBoundary {
    address public operationCoordinator;
    address public predecessor;
    bytes32 public predecessorHash;
    bool public sourceSealed;
    address public successor;
    uint256 public bindingCount;
    bool public bound = true;
    bool public failHistory;
    constructor(address c) MetadataArtistBoundary(c) { }

    function configure(address coordinator, address prior) external {
        operationCoordinator = coordinator;
        predecessor = prior;
        predecessorHash = prior.codehash;
        bindingCount = prior == address(0) ? 0 : 1;
    }

    function seal(address value, bool enabled) external {
        successor = value;
        sourceSealed = enabled;
    }

    function setPrior(address value, bytes32 hash, bool enabled, uint256 count) external {
        predecessor = value;
        predecessorHash = hash;
        bound = enabled;
        bindingCount = count;
    }

    function gasParameterInfo(bytes32 id) external pure returns (uint256, uint256, uint8, uint64) {
        require(id == keccak256("6529STREAM_GGP_ARTIST_RECORD_PUBLICATION_READ_GAS"), "parameter");
        return (400000, 150000, 2, 1); // Original Registry genesis settings, no test-only increase.
    }

    function setFailHistory(bool value) external {
        failHistory = value;
    }

    function artistRegistryCutover() external view returns (bool, address, uint64) {
        return (sourceSealed, successor, 10);
    }

    function importedHistoryBindingCount() external view returns (uint256) {
        require(!failHistory, "history unavailable");
        return bindingCount;
    }

    function importedHistoryBinding(uint256 index)
        external
        view
        returns (address, uint64, bytes32, bytes32)
    {
        require(index == 0, "index");
        return (predecessor, 9, keccak256("root"), keccak256("manifest"));
    }

    function artistHistoryPredecessorBinding(address prior)
        external
        view
        returns (bool, bytes32, uint256)
    {
        return (bound && prior == predecessor, predecessorHash, bindingCount);
    }
}

contract StreamMetadataArtistSuccessorTest is CollectionMetadataV1Fixture {
    bytes32 private constant COMPLETION = keccak256("one complete seven-owner operation60");
    MetadataSuccessorArtistBoundary private next;
    MetadataHydrationCoordinatorBoundary private priorCoordinator;
    MetadataHydrationCoordinatorBoundary private nextCoordinator;
    T.SuiteConfiguration private nextSuite;

    function _newArtist(address c) internal override returns (MetadataArtistBoundary) {
        return new MetadataSuccessorArtistBoundary(c);
    }

    function _graph() private {
        next = new MetadataSuccessorArtistBoundary(address(core));
        priorCoordinator = new MetadataHydrationCoordinatorBoundary();
        nextCoordinator = new MetadataHydrationCoordinatorBoundary();
        T.SuiteConfiguration memory s;
        s.registry = address(artist);
        s.archive = address(priorCoordinator);
        s.core = address(core);
        s.metadata = address(new MetadataRouterForSuccessorBoundary(address(core)));
        core.setPointer(keccak256("METADATA_ROUTER"), s.metadata);
        core.setPointer(
            keccak256("MODULE_REGISTRY"),
            address(new MetadataPublicationModulesBoundary(address(metadata)))
        );
        s.mintManager = address(core);
        s.roleRegistry = address(executor);
        s.primaryResolver = address(core);
        s.royaltyResolver = address(core);
        s.primaryRevenueClass = keccak256("PRIMARY");
        s.validator = address(schemas);
        for (uint256 i; i < 7; ++i) {
            s.owners[i] =
                address(new MetadataHydratedOwnerBoundary(s, address(priorCoordinator), i, 0));
        }
        priorCoordinator.configure(s);
        MetadataSuccessorArtistBoundary(address(artist))
            .configure(address(priorCoordinator), address(0));
        s.registry = address(next);
        s.archive = address(nextCoordinator);
        for (uint256 i; i < 7; ++i) {
            s.owners[i] = address(
                new MetadataHydratedOwnerBoundary(s, address(nextCoordinator), i, COMPLETION)
            );
        }
        nextCoordinator.configure(s);
        nextSuite = s;
        next.configure(address(nextCoordinator), address(artist));
        MetadataSuccessorArtistBoundary(address(artist)).seal(address(next), true);
        core.setPointer(keccak256("ARTIST_REGISTRY"), address(next));
    }

    function _terms(address recorder, bytes memory payload)
        private
        view
        returns (IStreamPreservationRecords.CollectionRecord memory r, P.Publication memory p)
    {
        r = _record(ARTIST, payload);
        r.schemaId = keccak256("STREAM_ARTIST_INTERVIEW_V1");
        p = _publication(recorder, r);
    }

    function _candidateFailure(P.Publication memory p) private {
        (bool ok,) =
            address(metadata).staticcall(abi.encodeCall(metadata.requireArtistRecordCandidate, (p)));
        require(!ok, "unproved successor accepted");
    }

    function testOriginalPermitConsumptionSurvivesSuccessorAndNewPublicationUsesSameHostDomain()
        public
    {
        address recorder = address(0xa11ce);
        bytes memory payload = bytes("original and successor bytes");
        (IStreamPreservationRecords.CollectionRecord memory r, P.Publication memory p) =
            _terms(recorder, payload);
        artist.setSigner(recorder);
        artist.permit(keccak256("used"), p);
        bytes32 original = metadata.recordArtistCollectionRecordWithPayload(
            recorder, 1, r, payload, keccak256("used")
        );
        require(original == _oldRecordHash(recorder, r), "original preimage");
        _graph();
        next.setSigner(recorder);
        next.permit(keccak256("used"), p);
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamCollectionMetadataV1.MetadataAuthorizationConsumed.selector,
                keccak256("used")
            )
        );
        metadata.recordArtistCollectionRecordWithPayload(recorder, 1, r, payload, keccak256("used"));
        r.effectiveAt = 2;
        p = _publication(recorder, r);
        next.permit(keccak256("fresh"), p);
        bytes32 saved = metadata.recordArtistCollectionRecordWithPayload(
            recorder, 1, r, payload, keccak256("fresh")
        );
        require(saved == _oldRecordHash(recorder, r), "same Metadata/Core record domain");
        (, IStreamCollectionMetadataV1.RecordReceipt memory receipt) =
            metadata.collectionRecord(saved);
        require(
            receipt.artistAuthorization == keccak256("fresh") && receipt.recorder == recorder,
            "actual successor callback and original recorder"
        );
        require(metadata.artistRegistry() == address(artist), "birth anchor retained");
    }

    function testActualArtistCandidateWorkerUsesGenesis400kBudgetWithDistinctRouter() public {
        _graph();
        require(nextSuite.metadata != address(metadata), "router and record host distinct");
        bytes memory payload = bytes("bounded original Artist worker");
        store.publishChunk(payload);
        (, P.Publication memory p) = _terms(address(0xa11ce), payload);
        bytes32 hash = new MetadataPublicationBudgetProbe().candidate(nextSuite, p);
        require(hash == address(metadata).codehash, "actual fixed candidate worker at original cap");
        core.setPointer(
            keccak256("METADATA_ROUTER"),
            address(new MetadataRouterForSuccessorBoundary(address(core)))
        );
        _candidateFailure(p);
    }

    function testEveryOwnerMustHaveMatchingNonzeroCompletionAndCorrectDomain() public {
        _graph();
        bytes memory payload = bytes("complete only");
        store.publishChunk(payload);
        (, P.Publication memory p) = _terms(address(0xa11ce), payload);
        for (uint256 i; i < 7; ++i) {
            MetadataHydratedOwnerBoundary owner = MetadataHydratedOwnerBoundary(nextSuite.owners[i]);
            owner.setCompletion(0);
            _candidateFailure(p);
            owner.setCompletion(keccak256(abi.encode(i)));
            _candidateFailure(p);
            owner.setCompletion(COMPLETION);
            owner.setDomain(keccak256("wrong owner domain"));
            _candidateFailure(p);
            owner.setDomain(keccak256(abi.encode("fixture owner", i)));
        }
        (bytes32 hash, uint8 kind) = metadata.requireArtistRecordCandidate(p);
        require(hash == p.candidateRecordHash && kind == 8, "all seven restored");
    }

    function testSealAndImmediatePinnedPredecessorRequiredEvenWithCompleteOwnerClaims() public {
        _graph();
        bytes memory payload = bytes("lineage");
        store.publishChunk(payload);
        (, P.Publication memory p) = _terms(address(0xa11ce), payload);
        MetadataSuccessorArtistBoundary original = MetadataSuccessorArtistBoundary(address(artist));
        original.seal(address(next), false);
        _candidateFailure(p);
        original.seal(address(0xbeef), true);
        _candidateFailure(p);
        original.seal(address(next), true);
        next.setPrior(address(artist), bytes32(uint256(7)), true, 1);
        _candidateFailure(p);
        next.setPrior(address(artist), address(artist).codehash, false, 1);
        _candidateFailure(p);
        next.setPrior(address(artist), address(artist).codehash, true, 2);
        _candidateFailure(p);
        next.setPrior(address(0xbeef), address(artist).codehash, true, 1);
        _candidateFailure(p);
        next.setPrior(address(artist), address(artist).codehash, true, 1);
        (bytes32 hash,) = metadata.requireArtistRecordCandidate(p);
        require(hash == p.candidateRecordHash, "exact lineage restored");
    }

    function testSuiteAndOwnerBindingsCannotSubstituteDifferentCoreOrMetadata() public {
        _graph();
        bytes memory payload = bytes("suite");
        store.publishChunk(payload);
        (, P.Publication memory p) = _terms(address(0xa11ce), payload);
        T.SuiteConfiguration memory s = nextSuite;
        s.metadata = address(0xbeef);
        nextCoordinator.configure(s);
        _candidateFailure(p);
        s = nextSuite;
        s.core = address(0xbeef);
        nextCoordinator.configure(s);
        _candidateFailure(p);
        s = nextSuite;
        s.primaryResolver = address(0xbeef);
        nextCoordinator.configure(s);
        _candidateFailure(p);
        nextCoordinator.configure(nextSuite);
        MetadataHydratedOwnerBoundary(nextSuite.owners[3]).setCore(address(0xbeef));
        _candidateFailure(p);
        MetadataHydratedOwnerBoundary(nextSuite.owners[3]).setCore(address(core));
        (bytes32 hash,) = metadata.requireArtistRecordCandidate(p);
        require(hash == p.candidateRecordHash, "bindings restored");
    }

    function testUnavailableProofAndUnselectedMetadataFailClosed() public {
        _graph();
        bytes memory payload = bytes("availability");
        store.publishChunk(payload);
        (, P.Publication memory p) = _terms(address(0xa11ce), payload);
        next.setFailHistory(true);
        _candidateFailure(p);
        next.setFailHistory(false);
        core.setPointer(keccak256("COLLECTION_METADATA"), address(schemas));
        _candidateFailure(p);
        core.setPointer(keccak256("COLLECTION_METADATA"), address(metadata));
        (bytes32 hash,) = metadata.requireArtistRecordCandidate(p);
        require(hash == p.candidateRecordHash, "current route restored");
    }

    function testActualSafeFailurePreservesNonceAuthorizationAndChunkThenIdenticalRetry() public {
        _graph();
        uint256[] memory keys = new uint256[](2);
        keys[0] = 0xa11;
        keys[1] = 0xb22;
        OfficialSafe account =
            createOfficialSafe(deploySafeComponents("1.4.1"), safeOwnerAddresses(keys), 2, 1);
        bytes memory payload = bytes("Safe successor publication");
        (IStreamPreservationRecords.CollectionRecord memory r, P.Publication memory p) =
            _terms(address(account), payload);
        bytes32 permit = keccak256("Safe permit");
        next.setSigner(address(account));
        next.permit(permit, p);
        bytes memory data = abi.encodeCall(
            metadata.recordArtistCollectionRecordWithPayload,
            (address(account), 1, r, payload, permit)
        );
        uint256 nonce = account.nonce();
        bytes32 digest = account.getTransactionHash(
            address(metadata), 0, data, 0, 0, 0, 0, address(0), address(0), nonce
        );
        bytes memory signatures = safeThresholdSignature(keys, digest);
        MetadataHydratedOwnerBoundary(nextSuite.owners[6]).setCompletion(0);
        (bool ok, bytes memory reason) = address(account)
            .call(
                abi.encodeCall(
                    account.execTransaction,
                    (
                        address(metadata),
                        0,
                        data,
                        0,
                        0,
                        0,
                        0,
                        address(0),
                        payable(address(0)),
                        signatures
                    )
                )
            );
        require(
            !ok
                && keccak256(reason)
                    == keccak256(abi.encodeWithSignature("Error(string)", "GS013")),
            "actual Safe denied"
        );
        require(
            account.nonce() == nonce && !metadata.consumedArtistAuthorization(permit)
                && metadata.payloadPointerCount(1) == 0,
            "all state unchanged"
        );
        (address pointer,) = store.chunk(keccak256(payload));
        require(pointer == address(0), "no denied payload");
        MetadataHydratedOwnerBoundary(nextSuite.owners[6]).setCompletion(COMPLETION);
        require(
            account.execTransaction(
                address(metadata), 0, data, 0, 0, 0, 0, address(0), payable(address(0)), signatures
            ),
            "same exact signed transaction"
        );
        require(
            account.nonce() == nonce + 1 && metadata.consumedArtistAuthorization(permit),
            "one successful use"
        );
        (, IStreamCollectionMetadataV1.RecordReceipt memory receipt) =
            metadata.collectionRecord(p.candidateRecordHash);
        require(receipt.recorder == address(account), "Safe recorder retained");
    }

    function testLateAppendFailureRollsBackSuccessorUseAndActualChunk() public {
        _graph();
        bytes memory payload = bytes("late append");
        (IStreamPreservationRecords.CollectionRecord memory r,) = _terms(address(0xa11ce), payload);
        r.uri = "javascript:bad";
        P.Publication memory p = _publication(address(0xa11ce), r);
        bytes32 permit = keccak256("late permit");
        next.setSigner(address(0xa11ce));
        next.permit(permit, p);
        vm.expectRevert(abi.encodeWithSelector(StreamMetadataRenderer.UnsafeMetadataURI.selector));
        metadata.recordArtistCollectionRecordWithPayload(address(0xa11ce), 1, r, payload, permit);
        require(
            !metadata.consumedArtistAuthorization(permit) && metadata.payloadPointerCount(1) == 0,
            "authorization and index rollback"
        );
        (address pointer,) = store.chunk(keccak256(payload));
        require(pointer == address(0), "actual store rollback");
    }
}
