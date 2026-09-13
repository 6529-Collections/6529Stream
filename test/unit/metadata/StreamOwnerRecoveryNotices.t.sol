// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../../../smart-contracts/domains/metadata/StreamOwnerRecords.sol";
import "../../../smart-contracts/domains/metadata/StreamSchemaRegistry.sol";
import "../../regression/legacy/helpers/CharacterizationTestBase.sol";
import "../../helpers/OfficialSafeFixture.sol";

interface OwnerNoticeSnapshotVm {
    function snapshotState() external returns (uint256);
    function revertToState(uint256 id) external returns (bool);
}

/// @dev Explicit custody/selected-target boundary; production Core composition is separate.
contract OwnerNoticeCoreBoundary {
    address public recovery;
    mapping(uint256 => address) public owners;
    uint256 public collection = 1;

    function setOwner(uint256 id, address owner) external {
        owners[id] = owner;
    }

    function setRecovery(address target) external {
        recovery = target;
    }

    function setCollection(uint256 id) external {
        collection = id;
    }

    function supportsInterface(bytes4 id) external pure returns (bool) {
        return id == 0x80ac58cd;
    }

    function ownerOf(uint256 token) external view returns (address) {
        require(owners[token] != address(0), "burned");
        return owners[token];
    }

    function tokenCollectionIdentity(uint256 token)
        external
        view
        returns (bool, uint256, uint256, bool)
    {
        return (true, collection, token, owners[token] == address(0));
    }

    function getSatellitePointer(bytes32)
        external
        view
        returns (address, bytes32, bool, bytes32, bytes4, address, uint8, bytes32, bytes32, uint64)
    {
        return (
            recovery,
            recovery.codehash,
            false,
            keccak256("STREAM_ARTWORK_FINALITY_RECOVERY"),
            type(IStreamArtworkFinalityRecovery).interfaceId,
            address(this),
            0,
            bytes32(uint256(1)),
            bytes32(uint256(2)),
            1
        );
    }
}

/// @dev Exact tuple governance boundary, including schema registration and active recovery context.
contract OwnerNoticeExecutorBoundary {
    IStreamGovernanceActionFacts.ActionFacts private facts;
    bytes private context =
        abi.encode(false, bytes32(0), uint8(0), bytes32(0), bytes32(0), bytes32(0));

    function isStreamGovernedParameterAuthority() external pure returns (bool) {
        return true;
    }

    function setFacts(uint8 status, bytes32 hash, uint64 before_, uint64 expires) external {
        facts = IStreamGovernanceActionFacts.ActionFacts(
            GovernanceActionStatus(status), 2, hash, before_, expires
        );
    }

    function governanceActionFacts(bytes32)
        external
        view
        returns (IStreamGovernanceActionFacts.ActionFacts memory)
    {
        return facts;
    }

    function setContext(bytes calldata raw) external {
        context = raw;
    }

    function currentAction()
        external
        view
        returns (bool, bytes32, uint8, bytes32, bytes32, bytes32)
    {
        return abi.decode(context, (bool, bytes32, uint8, bytes32, bytes32, bytes32));
    }

    function execute(address target, bytes calldata data, bytes32 s, bytes32 o, bytes32 n)
        external
        returns (bytes memory)
    {
        context = abi.encode(true, bytes32(uint256(42)), uint8(1), s, o, n);
        (bool ok, bytes memory out) = target.call(data);
        if (!ok) assembly ("memory-safe") { revert(add(out, 32), mload(out)) }
        context = abi.encode(false, bytes32(0), uint8(0), bytes32(0), bytes32(0), bytes32(0));
        return out;
    }
}

/// @dev Staged-intent boundary only; no full companion preparation is inferred from these tests.
contract OwnerNoticeRecoveryBoundary {
    address public core;
    address public governanceAuthority;
    address public ownerEvidence;
    bytes32 public scopeHash;
    bytes32 public requestHash;
    bool public fail;

    constructor(address c, address e, address o) {
        core = c;
        governanceAuthority = e;
        ownerEvidence = o;
    }

    function configure(bytes32 s, bytes32 r, bool f) external {
        scopeHash = s;
        requestHash = r;
        fail = f;
    }

    function requireArtistRecoveryIntent(StreamFinalityScope calldata, bytes32, bytes32)
        external
        view
        returns (bytes32, bytes32, bytes32, bytes32)
    {
        require(!fail, "intent unavailable");
        return (scopeHash, keccak256("old"), keccak256("new"), requestHash);
    }
}

/// @notice Actual OwnerRecords, schema, store and threshold Safe with explicit Core/Executor/intent boundaries.
contract StreamOwnerRecoveryNoticesTest is CharacterizationTestBase, OfficialSafeFixture {
    StreamOwnerRecords private owner;
    StreamSchemaRegistry private schemas;
    StreamSchemaDocumentStore private store;
    OwnerNoticeCoreBoundary private core;
    OwnerNoticeExecutorBoundary private executor;
    OwnerNoticeRecoveryBoundary private recovery;
    StreamFinalityRecoveryRequest private request;
    GovernanceCall[] private calls;
    bytes32 private constant ID = keccak256("owner notice action");
    bytes32 private constant RESPONSE = keccak256("RECOVERY_RESPONSE");
    uint64 private constant END = 1000 + 72 hours;
    uint64 private constant EXPIRY = 1000 + 10 days;

    function setUp() public {
        vm.warp(1000);
        executor = new OwnerNoticeExecutorBoundary();
        core = new OwnerNoticeCoreBoundary();
        schemas = new StreamSchemaRegistry(address(executor));
        store = StreamSchemaDocumentStore(schemas.chunkStore());
        _register(
            "RAW_BYTES",
            IStreamSchemaRegistry.DocumentKind.CANONICALIZATION,
            bytes(schemas.RAW_BYTES_DEFINITION())
        );
        _register(
            "RFC8785_JCS",
            IStreamSchemaRegistry.DocumentKind.CANONICALIZATION,
            bytes(vm.readFile("schemas/museum/account-profile/RFC8785_JCS.json"))
        );
        _registerFile("STREAM_STEWARD_DESIGNATION_V1", IStreamSchemaRegistry.DocumentKind.SCHEMA);
        _registerFile(
            "STREAM_STEWARD_DESIGNATION_JSON_PROFILE_V1", IStreamSchemaRegistry.DocumentKind.CATALOG
        );
        _registerFile("STREAM_RECOVERY_RESPONSE_V1", IStreamSchemaRegistry.DocumentKind.SCHEMA);
        _registerFile(
            "STREAM_RECOVERY_RESPONSE_JSON_PROFILE_V1", IStreamSchemaRegistry.DocumentKind.CATALOG
        );
        StreamOwnerRecords.Configuration memory c;
        c.core = address(core);
        c.executor = address(executor);
        c.schemas = address(schemas);
        c.deploymentManifestHash = keccak256("deployment");
        c.manifestURI = "ipfs://owner";
        c.manifestHash = keccak256("module");
        c.signatureGas = IStreamGasParameterHost.GasParameterConfig(
            "METADATA_ERC1271_VERIFY_GAS", 150000, 90000, 2
        );
        c.dependencyReadGas = IStreamGasParameterHost.GasParameterConfig(
            "METADATA_DEPENDENCY_READ_GAS", 150000, 100000, 2
        );
        owner = new StreamOwnerRecords(c);
        core.setOwner(7, address(this));
        recovery = new OwnerNoticeRecoveryBoundary(address(core), address(executor), address(owner));
        core.setRecovery(address(recovery));
        request.scope = StreamFinalityScope(StreamFinalityScopeType.TOKEN, 1, 7, 0);
        request.expectedOriginalFinalityRecordHash = keccak256("original");
        request.expectedOldRouteHash = keccak256("old route");
        request.recoveryManifest = StreamFinalityManifestRef(
            "ipfs://manifest",
            keccak256("ipfs://manifest"),
            keccak256("manifest"),
            keccak256("schema"),
            keccak256("canon")
        );
        request.reasonHash = keccak256("reason");
        request.reasonURI = "ipfs://reason";
        calls.push(
            GovernanceCall(
                address(recovery),
                0,
                IStreamArtworkFinalityRecovery.executeFinalityRecovery.selector,
                keccak256(
                    abi.encodeCall(
                        IStreamArtworkFinalityRecovery.executeFinalityRecovery, (request)
                    )
                ),
                _scope(),
                keccak256("old"),
                keccak256("new")
            )
        );
        recovery.configure(_scope(), keccak256(abi.encode(request)), false);
        _status(1);
    }

    function _registerFile(string memory name, IStreamSchemaRegistry.DocumentKind kind) private {
        _register(name, kind, bytes(vm.readFile(string.concat("schemas/records/", name, ".json"))));
    }

    function _register(
        string memory name,
        IStreamSchemaRegistry.DocumentKind kind,
        bytes memory payload
    ) private {
        (bytes32 hash,) = store.publishChunk(payload);
        bytes32[] memory chunks = new bytes32[](1);
        chunks[0] = hash;
        IStreamSchemaRegistry.DocumentSpec memory spec = IStreamSchemaRegistry.DocumentSpec(
            name, kind, hash, keccak256("RAW_BYTES"), 0, "", uint32(payload.length)
        );
        (bytes32 s, bytes32 o, bytes32 n) = schemas.registrationTransition(spec, chunks);
        executor.execute(
            address(schemas), abi.encodeCall(schemas.registerDocument, (spec, chunks)), s, o, n
        );
    }

    function _scope() private view returns (bytes32) {
        return keccak256(
            abi.encode(
                keccak256("6529STREAM_FINALITY_RECOVERY_SCOPE_V1"),
                block.chainid,
                address(recovery),
                request.scope
            )
        );
    }

    function _callsHash() private view returns (bytes32) {
        return keccak256(
            abi.encode(
                bytes32(0x10f09566fb70f7947b61639c2a53b3aec872069a8b46edd08ba14eb2b5942b70), calls
            )
        );
    }

    function _status(uint8 value) private {
        executor.setFacts(value, _callsHash(), END, EXPIRY);
    }

    function _ref(uint16 algorithm, string memory uri)
        private
        pure
        returns (StreamOwnerNoticeTypes.Reference memory)
    {
        return StreamOwnerNoticeTypes.Reference(
            algorithm,
            keccak256("RAW_BYTES"),
            algorithm == 4 || algorithm == 5 ? bytes(hex"010203") : abi.encode(keccak256("claim")),
            uri
        );
    }

    function _designation() private view returns (StreamOwnerNoticeTypes.Designation memory d) {
        d.subjectId = owner.deriveOwnerSubject(7);
        d.profileHash = StreamOwnerNoticeDefinitions.STEWARD_PROFILE_HASH;
        d.name = "Original registrar";
        d.identity = _ref(2, "https://museum.example/identity");
        d.contactEndpoints = new StreamOwnerNoticeTypes.Contact[](2);
        d.contactEndpoints[0] = StreamOwnerNoticeTypes.Contact(
            StreamOwnerNoticeTypes.ContactKind.MAILTO,
            "mailto:registrar@museum.example",
            0,
            address(0)
        );
        d.contactEndpoints[1] = StreamOwnerNoticeTypes.Contact(
            StreamOwnerNoticeTypes.ContactKind.HTTPS,
            "https://museum.example/contact",
            0,
            address(0)
        );
    }

    function _steward(StreamOwnerNoticeTypes.Designation memory d) private returns (bytes32 hash) {
        IStreamOwnerRecords.OwnerRecord memory r = _record(
            keccak256("STEWARD_DESIGNATION"),
            StreamOwnerNoticeDefinitions.STEWARD_SCHEMA_ID,
            StreamStewardDesignationJson.serialize(d)
        );
        owner.recordStewardDesignation(7, r, d);
        return owner.stewardDesignationFor(7, address(this));
    }

    function _publication(StreamOwnerNoticeTypes.Designation memory d)
        private
        view
        returns (StreamOwnerRecoveryNoticeTypes.Publication memory p)
    {
        p.runbook = _ref(2, "ipfs://runbook");
        p.publicNotice = _ref(5, "https://museum.example/recovery");
        p.deliveries = new StreamOwnerRecoveryNoticeTypes.Delivery[](d.contactEndpoints.length + 1);
        for (uint256 i; i < p.deliveries.length; ++i) {
            p.deliveries[i].endpoint = i == 0
                ? StreamOwnerNoticeTypes.Contact(
                    StreamOwnerNoticeTypes.ContactKind.EIP155, "", block.chainid, core.ownerOf(7)
                )
                : d.contactEndpoints[i - 1];
            p.deliveries[i].evidence = _ref(uint16(i % 6 + 1), "ipfs://claimed-delivery");
        }
    }

    function _open() private {
        StreamOwnerNoticeTypes.Designation memory d;
        owner.openRecoveryNotice(ID, calls, request, d, _publication(d));
    }

    function _record(bytes32 kind, bytes32 schema, bytes memory payload)
        private
        view
        returns (IStreamOwnerRecords.OwnerRecord memory r)
    {
        r.recordType = kind;
        r.subjectId = owner.deriveOwnerSubject(7);
        r.schemaId = schema;
        r.payload = payload;
        r.contentHash = IStreamPreservationRecords.HashRef(
            1, abi.encode(keccak256(payload)), StreamWorkRecordDefinitions.CANON_ID
        );
        r.uri = "ipfs://original-owner-record";
        r.effectiveAt = 1;
    }

    function _response(uint8 cls, string memory grounds)
        private
        view
        returns (StreamOwnerNoticeTypes.Response memory r)
    {
        r.subjectId = owner.deriveOwnerSubject(7);
        r.profileHash = StreamOwnerNoticeDefinitions.RESPONSE_PROFILE_HASH;
        r.recoveryId = ID;
        r.recoveryManifestHash = request.recoveryManifest.contentHash;
        r.response = StreamOwnerNoticeTypes.ResponseClass(cls);
        r.grounds = grounds;
    }

    function _append(uint8 cls, string memory grounds) private returns (bytes32 hash) {
        StreamOwnerNoticeTypes.Response memory r = _response(cls, grounds);
        owner.recordRecoveryResponse(
            7,
            _record(
                RESPONSE,
                StreamOwnerNoticeDefinitions.RESPONSE_SCHEMA_ID,
                StreamRecoveryResponseJson.serialize(r)
            ),
            r
        );
        return owner.latestOwnerRecordHashFor(7, RESPONSE, address(this));
    }

    function _valid() private view returns (bool v) {
        (v,,,,,) = owner.verifyRecoveryOwnerEvidence(
            request.scope, ID, request.recoveryManifest.contentHash
        );
    }

    function testFullOpeningBindingExactPublicationAndImmutableSeventyTwoHours() public {
        _open();
        StreamOwnerRecoveryNoticeTypes.Snapshot memory n = owner.recoveryNotice(ID);
        require(
            n.openingOwner == address(this) && n.publisher == address(this) && n.noticeEndsAt == END
                && n.openedAt == 1000,
            "actual opening clock"
        );
        require(
            n.binding.callHash == _callsHash()
                && n.binding.requestHash == keccak256(abi.encode(request))
                && n.binding.target == address(recovery),
            "full original binding"
        );
        require(
            n.binding.originalFinalityRecordHash == request.expectedOriginalFinalityRecordHash
                && n.revision == 1,
            "immutable original lineage"
        );
        StreamOwnerNoticeTypes.Designation memory d;
        StreamOwnerRecoveryNoticeTypes.Publication memory p = _publication(d);
        (, bytes memory raw) = owner.recoveryNoticeClaim(ID, 0);
        require(
            keccak256(raw) == keccak256(abi.encode(p.runbook, p.publicNotice)),
            "exact all-six-compatible references"
        );
        (, raw) = owner.recoveryNoticeClaim(ID, 1);
        require(
            keccak256(raw) == keccak256(abi.encode(p.deliveries[0])),
            "exact original endpoint claim"
        );
        vm.warp(END - 1);
        require(!_valid(), "full interval");
        vm.warp(END);
        require(_valid(), "equality elapsed");
    }

    function testPreOpeningObjectionCannotBeHiddenByPermissionlessOpener() public {
        bytes32 hash = _append(1, "Pre-opening objection");
        _open();
        StreamOwnerRecoveryNoticeTypes.Snapshot memory n = owner.recoveryNotice(ID);
        require(
            n.responseTail == 1 && n.firstResponseIndex == 1, "original queue and ordering barrier"
        );
        vm.warp(END);
        require(!_valid(), "cannot omit original objection");
        require(owner.processRecoveryResponse(ID), "one original processed");
        n = owner.recoveryNotice(ID);
        require(
            n.objections == 1 && n.acknowledgements == 0 && _valid(),
            "objection informs but never vetoes"
        );
        require(
            owner.latestCountedRecoveryResponse(ID, address(this)) == hash, "original author head"
        );
    }

    function testSameBlockResponseOrderingAndPendingTailAfterEnd() public {
        bytes32 a = _append(1, "before");
        _open();
        bytes32 b = _append(0, "after");
        require(
            owner.recoveryResponse(a).recordedAt == owner.recoveryResponse(b).recordedAt,
            "same block timestamp"
        );
        require(
            owner.recoveryResponse(a).recordIndex < owner.recoveryNotice(ID).firstResponseIndex,
            "original index before opening"
        );
        vm.warp(END);
        require(!_valid(), "both pending");
        owner.processRecoveryResponse(ID);
        require(!_valid(), "tail still pending");
        owner.processRecoveryResponse(ID);
        require(_valid(), "complete queue");
        StreamOwnerRecoveryNoticeTypes.Snapshot memory n = owner.recoveryNotice(ID);
        require(
            n.acknowledgements == 1 && n.objections == 0 && n.revision == 3,
            "latest per author conservation"
        );
        require(
            !owner.processRecoveryResponse(ID) && owner.recoveryNotice(ID).revision == 3,
            "idempotent empty queue"
        );
    }

    function testLateResponseRemainsOperativeWithoutRestart() public {
        _open();
        vm.warp(END);
        bytes32 hash = _append(1, "late at equality");
        require(owner.recoveryResponse(hash).afterMinimumWindow && !_valid(), "late pending");
        owner.processRecoveryResponse(ID);
        require(_valid(), "late does not shorten or veto");
        require(owner.recoveryNotice(ID).noticeEndsAt == END, "clock unchanged");
    }

    function testClosedAndUnavailableGovernanceNeverDisableResponseDocumentation() public {
        _open();
        for (uint8 status = 2; status <= 5; ++status) {
            _status(status);
            bytes32 hash =
                _append(status % 2, string(abi.encodePacked("closed", bytes1(48 + status))));
            require(
                owner.recoveryResponse(hash).author == address(this),
                "permanent actual owner response"
            );
            require(!owner.processRecoveryResponse(ID), "closed action is not counted");
        }
        bytes memory code = address(executor).code;
        vm.etch(address(executor), hex"00");
        bytes32 last = _append(1, "executor unavailable");
        require(owner.recoveryResponse(last).author == address(this), "append provider independent");
        vm.etch(address(executor), code);
        _status(1);
        for (uint256 i; i < 5; ++i) {
            owner.processRecoveryResponse(ID);
        }
        require(
            owner.recoveryNotice(ID).processed == 5,
            "retained originals can be processed in this explicit reversible fixture"
        );
    }

    function testExecutedEligibilityRequiresExactActiveContextThenHistoryRemains() public {
        _open();
        vm.warp(END);
        _status(3);
        require(!_valid(), "historical EXECUTED is not live");
        executor.setContext(
            abi.encode(true, ID, uint8(2), _scope(), keccak256("old"), keccak256("new"))
        );
        require(_valid(), "actual exact execution read context");
        executor.setContext(
            abi.encode(true, ID, uint8(2), _scope(), keccak256("old"), keccak256("wrong"))
        );
        require(!_valid(), "wrong transition");
        executor.setContext(
            abi.encode(false, bytes32(0), uint8(0), bytes32(0), bytes32(0), bytes32(0))
        );
        require(
            !_valid() && owner.recoveryNotice(ID).evidenceHash != 0, "permanent historical evidence"
        );
    }

    function testCurrentStewardTransferAndBurnCannotRewriteOriginalSnapshot() public {
        StreamOwnerNoticeTypes.Designation memory d = _designation();
        bytes32 hash = _steward(d);
        owner.openRecoveryNotice(ID, calls, request, d, _publication(d));
        bytes32 evidence = owner.recoveryNotice(ID).evidenceHash;
        d.predecessor = hash;
        d.name = "Changed registrar";
        _steward(d);
        core.setOwner(7, address(0xbeef));
        require(
            owner.recoveryNotice(ID).openingOwner == address(this)
                && owner.recoveryNotice(ID).stewardRecordHash == hash,
            "original custody and designation"
        );
        core.setOwner(7, address(0));
        vm.etch(address(schemas), hex"00");
        (, bytes memory raw) = owner.recoveryNoticeClaim(ID, 2);
        StreamOwnerRecoveryNoticeTypes.Delivery memory claim =
            abi.decode(raw, (StreamOwnerRecoveryNoticeTypes.Delivery));
        require(
            keccak256(bytes(claim.endpoint.uri)) == keccak256("mailto:registrar@museum.example")
                && owner.recoveryNotice(ID).evidenceHash == evidence,
            "history independent of custody and providers"
        );
        (IStreamOwnerRecords.OwnerRecord memory original,) = owner.ownerRecord(hash);
        require(original.payload.length != 0, "complete original designation");
    }

    function testExactAllEndpointCoverageRejectsMissingReorderedAndChangedClaims() public {
        StreamOwnerNoticeTypes.Designation memory d = _designation();
        _steward(d);
        StreamOwnerRecoveryNoticeTypes.Publication memory p = _publication(d);
        p.deliveries[0].endpoint.account = address(0xbeef);
        (bool ok,) = address(owner)
            .call(abi.encodeCall(owner.openRecoveryNotice, (ID, calls, request, d, p)));
        require(!ok, "wrong owner endpoint");
        p = _publication(d);
        p.deliveries[1] = p.deliveries[2];
        (ok,) = address(owner)
            .call(abi.encodeCall(owner.openRecoveryNotice, (ID, calls, request, d, p)));
        require(!ok, "missing exact registrar endpoint");
        p = _publication(d);
        owner.openRecoveryNotice(ID, calls, request, d, p);
        require(owner.recoveryNotice(ID).deliveryCount == 3, "same proof complete retry");
    }

    function testDuplicateNoticeAndInsufficientExpiryCannotRestartWindow() public {
        executor.setFacts(1, _callsHash(), END, END - 1);
        StreamOwnerNoticeTypes.Designation memory d;
        (bool ok,) = address(owner)
            .call(
                abi.encodeCall(owner.openRecoveryNotice, (ID, calls, request, d, _publication(d)))
            );
        require(!ok, "expiry cannot cover full interval");
        executor.setFacts(1, _callsHash(), END, END);
        _open();
        vm.warp(END);
        require(_valid(), "exact expiry equality");
        (ok,) = address(owner)
            .call(
                abi.encodeCall(owner.openRecoveryNotice, (ID, calls, request, d, _publication(d)))
            );
        require(!ok, "no restart");
        vm.warp(END + 1);
        require(!_valid(), "strict expiry");
    }

    function testWrongManifestResponseRetainedWithoutPollutingNoticeQueue() public {
        _open();
        StreamOwnerNoticeTypes.Response memory r = _response(1, "different manifest");
        r.recoveryManifestHash = keccak256("other");
        owner.recordRecoveryResponse(
            7,
            _record(
                RESPONSE,
                StreamOwnerNoticeDefinitions.RESPONSE_SCHEMA_ID,
                StreamRecoveryResponseJson.serialize(r)
            ),
            r
        );
        bytes32 hash = owner.latestOwnerRecordHashFor(7, RESPONSE, address(this));
        require(!owner.recoveryResponse(hash).queued, "different pair retained");
        vm.warp(END);
        require(
            _valid() && owner.recoveryNotice(ID).responseTail == 0,
            "not a forged applicable objection"
        );
    }

    function testBadInterpretationAndCanonicalGenericBypassRollback() public {
        StreamOwnerNoticeTypes.Response memory r = _response(1, "original");
        IStreamOwnerRecords.OwnerRecord memory record = _record(
            RESPONSE,
            StreamOwnerNoticeDefinitions.RESPONSE_SCHEMA_ID,
            StreamRecoveryResponseJson.serialize(r)
        );
        (bool ok,) = address(owner).call(abi.encodeCall(owner.recordOwnerRecord, (7, record)));
        require(!ok, "typed index cannot be bypassed");
        r.profileHash = bytes32(uint256(1));
        (ok,) = address(owner).call(abi.encodeCall(owner.recordRecoveryResponse, (7, record, r)));
        require(!ok, "exact profile");
        r = _response(1, "original");
        owner.recordRecoveryResponse(7, record, r);
        require(
            owner.recoveryResponse(owner.recordHashAt(7, RESPONSE, 0)).author == address(this),
            "same original retry"
        );
    }

    function testLiteralOldNonceAndHistoryRootsAndRelayedPayloadBinding() public {
        uint256 key = 8197;
        address author = vm.addr(key);
        core.setOwner(7, author);
        StreamOwnerNoticeTypes.Response memory r = _response(1, "signed original");
        IStreamOwnerRecords.OwnerRecord memory record = _record(
            RESPONSE,
            StreamOwnerNoticeDefinitions.RESPONSE_SCHEMA_ID,
            StreamRecoveryResponseJson.serialize(r)
        );
        bytes32 digest = owner.ownerRecordDigest(7, record, author, 19, 2000);
        (uint8 v, bytes32 a, bytes32 b) = vm.sign(key, digest);
        bytes memory signature = abi.encodePacked(a, b, v);
        owner.recordRecoveryResponseFor(7, record, author, 19, 2000, signature, r);
        require(
            vm.load(
                address(owner),
                keccak256(abi.encode(uint256(19), keccak256(abi.encode(author, uint256(4)))))
            ) == bytes32(uint256(1)),
            "literal old nonce root4"
        );
        bytes32 lane =
            keccak256(abi.encode(RESPONSE, keccak256(abi.encode(uint256(7), uint256(6)))));
        require(vm.load(address(owner), lane) == bytes32(uint256(1)), "literal old history root6");
        bytes32 hash = owner.recordHashAt(7, RESPONSE, 0);
        (, IStreamOwnerRecords.Receipt memory receipt) = owner.ownerRecord(hash);
        require(
            receipt.authorizationDigest == digest && receipt.owner == author && receipt.relayed,
            "original receipt attribution"
        );
        require(owner.recoveryResponse(hash).author == author, "relayer never author");
    }

    function testColdBounded192ByteOwnerReadAndFailedIntentDoesNotRecurse() public {
        _open();
        vm.warp(END);
        recovery.configure(_scope(), keccak256(abi.encode(request)), true);
        safeVm.cool(address(owner));
        safeVm.cool(address(core));
        safeVm.cool(address(executor));
        safeVm.cool(address(recovery));
        uint256 start = gasleft();
        (bool ok, bytes memory out) = address(owner).staticcall{ gas: 500000 }(
            abi.encodeCall(
                owner.verifyRecoveryOwnerEvidence,
                (request.scope, ID, request.recoveryManifest.contentHash)
            )
        );
        uint256 used = start - gasleft();
        require(ok && out.length == 192, "exact six-word callback within500k");
        (bool valid, bytes32 hash, uint64 revision, uint64 end, uint32 ack, uint32 obj) =
            abi.decode(out, (bool, bytes32, uint64, uint64, uint32, uint32));
        require(
            valid && hash != 0 && revision == 1 && end == END && ack == 0 && obj == 0,
            "lightweight notice liveness; intent remains companion responsibility"
        );
        emit GasMeasured(used);
    }
    event GasMeasured(uint256 gasUsed);

    function testActualThresholdSafeDirectRelayedNoticeProcessingAndEveryNewRead() public {
        SafeComponents memory components = deploySafeComponents("1.4.1");
        uint256[] memory keys = new uint256[](2);
        keys[0] = 743;
        keys[1] = 927;
        OfficialSafe account = createOfficialSafe(components, safeOwnerAddresses(keys), 2, 981);
        core.setOwner(7, address(account));
        StreamOwnerNoticeTypes.Designation memory d;
        require(
            executeSafe(
                account,
                keys,
                address(owner),
                0,
                abi.encodeCall(owner.openRecoveryNotice, (ID, calls, request, d, _publication(d))),
                0
            ),
            "actual Safe permissionless publication"
        );
        require(owner.recoveryNotice(ID).publisher == address(account), "actual Safe publisher");
        StreamOwnerNoticeTypes.Response memory r = _response(1, "Safe direct objection");
        IStreamOwnerRecords.OwnerRecord memory record = _record(
            RESPONSE,
            StreamOwnerNoticeDefinitions.RESPONSE_SCHEMA_ID,
            StreamRecoveryResponseJson.serialize(r)
        );
        require(
            executeSafe(
                account,
                keys,
                address(owner),
                0,
                abi.encodeCall(owner.recordRecoveryResponse, (7, record, r)),
                0
            ),
            "actual Safe direct owner"
        );
        r = _response(0, "Safe relayed acknowledgement");
        record = _record(
            RESPONSE,
            StreamOwnerNoticeDefinitions.RESPONSE_SCHEMA_ID,
            StreamRecoveryResponseJson.serialize(r)
        );
        bytes32 digest = owner.ownerRecordDigest(7, record, address(account), 91, 2000);
        owner.recordRecoveryResponseFor(
            7,
            record,
            address(account),
            91,
            2000,
            safeThresholdSignature(keys, safeMessageDigest(account, abi.encode(digest))),
            r
        );
        require(
            executeSafe(
                account,
                keys,
                address(owner),
                0,
                abi.encodeCall(owner.processRecoveryResponse, (ID)),
                0
            ),
            "actual Safe processor"
        );
        owner.processRecoveryResponse(ID);
        bytes32 hash = owner.latestCountedRecoveryResponse(ID, address(account));
        require(owner.recoveryResponse(hash).author == address(account), "relayer not owner");
        _safeReads(account, keys, hash);
    }

    function _safeReads(OfficialSafe account, uint256[] memory keys, bytes32 hash) private {
        bytes[] memory reads = new bytes[](8);
        reads[0] = abi.encodeCall(owner.recoveryNotice, (ID));
        reads[1] = abi.encodeCall(owner.recoveryNoticeClaim, (ID, 0));
        reads[2] = abi.encodeCall(owner.recoveryNoticeClaim, (ID, 1));
        reads[3] = abi.encodeCall(owner.recoveryResponse, (hash));
        reads[4] = abi.encodeCall(owner.recoveryResponseAt, (ID, 0));
        reads[5] = abi.encodeCall(owner.latestCountedRecoveryResponse, (ID, address(account)));
        reads[6] = abi.encodeCall(
            owner.verifyRecoveryOwnerEvidence,
            (request.scope, ID, request.recoveryManifest.contentHash)
        );
        reads[7] = abi.encodeCall(owner.gasParameter, (owner.RECOVERY_INTENT_READ_GAS()));
        for (uint256 i; i < reads.length; ++i) {
            require(
                executeSafe(account, keys, address(owner), 0, reads[i], 0),
                "actual Safe read success"
            );
        }
        require(
            owner.recoveryNotice(ID).acknowledgements == 1
                && owner.recoveryNotice(ID).objections == 0,
            "exact ordinary result attribution"
        );
    }

    function testSignedLateAppendFailurePreservesNonceReceiptQueueThenExactRetry() public {
        uint256 key = 1908;
        address author = vm.addr(key);
        core.setOwner(7, author);
        _open();
        StreamOwnerNoticeTypes.Response memory r = _response(1, "original signed objection");
        IStreamOwnerRecords.OwnerRecord memory record = _record(
            RESPONSE,
            StreamOwnerNoticeDefinitions.RESPONSE_SCHEMA_ID,
            StreamRecoveryResponseJson.serialize(r)
        );
        bytes memory signature = _signRecord(key, record, 90);
        core.setOwner(7, address(0xbeef));
        (bool ok,) = address(owner)
            .call(
                abi.encodeCall(
                    owner.recordRecoveryResponseFor, (7, record, author, 90, 2000, signature, r)
                )
            );
        require(
            !ok && !owner.isOwnerRecordNonceUsed(author, 90)
                && owner.recoveryNotice(ID).responseTail == 0,
            "whole transaction rollback"
        );
        core.setOwner(7, author);
        owner.recordRecoveryResponseFor(7, record, author, 90, 2000, signature, r);
        require(
            owner.isOwnerRecordNonceUsed(author, 90) && owner.recoveryNotice(ID).responseTail == 1,
            "identical proof retry"
        );
    }

    function _signRecord(uint256 key, IStreamOwnerRecords.OwnerRecord memory record, uint256 nonce)
        private
        returns (bytes memory)
    {
        bytes32 digest = owner.ownerRecordDigest(7, record, vm.addr(key), nonce, 2000);
        (uint8 v, bytes32 a, bytes32 b) = vm.sign(key, digest);
        return abi.encodePacked(a, b, v);
    }

    function testTransferCannotErasePriorOwnerObjectionOrAuthorizeStewardToWrite() public {
        _open();
        bytes32 first = _append(1, "first owner's objection");
        owner.processRecoveryResponse(ID);
        core.setOwner(7, address(0xbeef));
        StreamOwnerNoticeTypes.Response memory r = _response(0, "new owner's answer");
        IStreamOwnerRecords.OwnerRecord memory record = _record(
            RESPONSE,
            StreamOwnerNoticeDefinitions.RESPONSE_SCHEMA_ID,
            StreamRecoveryResponseJson.serialize(r)
        );
        (bool ok,) =
            address(owner).call(abi.encodeCall(owner.recordRecoveryResponse, (7, record, r)));
        require(!ok, "old owner cannot sign later");
        vm.prank(address(0xbeef));
        owner.recordRecoveryResponse(7, record, r);
        owner.processRecoveryResponse(ID);
        require(
            owner.recoveryNotice(ID).acknowledgements == 1
                && owner.recoveryNotice(ID).objections == 1,
            "both actual custody authors"
        );
        require(
            owner.latestCountedRecoveryResponse(ID, address(this)) == first,
            "prior original retained"
        );
    }

    function testDifferentActionsKeepDistinctPerOwnerHeads() public {
        bytes32 second = keccak256("second scheduled action");
        _open();
        StreamOwnerNoticeTypes.Designation memory d;
        owner.openRecoveryNotice(second, calls, request, d, _publication(d));
        bytes32 a = _append(1, "first action");
        StreamOwnerNoticeTypes.Response memory r = _response(0, "second action");
        r.recoveryId = second;
        owner.recordRecoveryResponse(
            7,
            _record(
                RESPONSE,
                StreamOwnerNoticeDefinitions.RESPONSE_SCHEMA_ID,
                StreamRecoveryResponseJson.serialize(r)
            ),
            r
        );
        owner.processRecoveryResponse(second);
        owner.processRecoveryResponse(ID);
        require(
            owner.latestCountedRecoveryResponse(ID, address(this)) == a
                && owner.recoveryNotice(ID).objections == 1,
            "first head not globally replaced"
        );
        require(
            owner.recoveryNotice(second).acknowledgements == 1
                && owner.recoveryNotice(second).objections == 0,
            "second exact action"
        );
    }

    function testAllSixResponseHashAlgorithmsAndReferencesRemainExact() public {
        _open();
        for (uint16 algorithm = 1; algorithm <= 6; ++algorithm) {
            StreamOwnerNoticeTypes.Response memory r =
                _response(1, string(abi.encodePacked("algorithm", bytes1(uint8(48 + algorithm)))));
            r.evidenceReferences = new StreamOwnerNoticeTypes.Reference[](1);
            r.evidenceReferences[0] = _ref(algorithm, "ipfs://evidence");
            IStreamOwnerRecords.OwnerRecord memory record = _record(
                RESPONSE,
                StreamOwnerNoticeDefinitions.RESPONSE_SCHEMA_ID,
                StreamRecoveryResponseJson.serialize(r)
            );
            record.contentHash.algorithm = algorithm;
            if (algorithm == 2) record.contentHash.digest = abi.encode(sha256(record.payload));
            if (algorithm == 4 || algorithm == 5) record.contentHash.digest = hex"010203";
            owner.recordRecoveryResponse(7, record, r);
            bytes32 hash = owner.recordHashAt(7, RESPONSE, algorithm - 1);
            (IStreamOwnerRecords.OwnerRecord memory retained,) = owner.ownerRecord(hash);
            require(
                keccak256(abi.encode(retained)) == keccak256(abi.encode(record)),
                "original opaque hash and typed bytes"
            );
            owner.processRecoveryResponse(ID);
        }
        require(
            owner.recoveryNotice(ID).processed == 6 && owner.recoveryNotice(ID).objections == 1,
            "one latest answer, all six originals"
        );
    }

    function testRetiredResponseDefinitionsAndMissingInterpretationHaveExactRetry() public {
        bytes32 id = StreamOwnerNoticeDefinitions.RESPONSE_PROFILE_ID;
        (bytes32 s, bytes32 o, bytes32 n) =
            schemas.statusTransition(id, IStreamSchemaRegistry.DocumentStatus.ARCHIVED);
        executor.execute(
            address(schemas),
            abi.encodeCall(
                schemas.setDocumentStatus, (id, IStreamSchemaRegistry.DocumentStatus.ARCHIVED)
            ),
            s,
            o,
            n
        );
        bytes32 first = _append(1, "archived still readable");
        require(
            owner.recoveryResponse(first).author == address(this), "retirement cannot lock owner"
        );
        (address pointer,) = store.chunk(StreamOwnerNoticeDefinitions.RESPONSE_PROFILE_HASH);
        bytes memory code = pointer.code;
        vm.etch(pointer, hex"00");
        StreamOwnerNoticeTypes.Response memory r = _response(1, "healthy exact retry");
        IStreamOwnerRecords.OwnerRecord memory record = _record(
            RESPONSE,
            StreamOwnerNoticeDefinitions.RESPONSE_SCHEMA_ID,
            StreamRecoveryResponseJson.serialize(r)
        );
        (bool ok,) =
            address(owner).call(abi.encodeCall(owner.recordRecoveryResponse, (7, record, r)));
        require(!ok, "exact immutable bytes required");
        vm.etch(pointer, code);
        owner.recordRecoveryResponse(7, record, r);
        require(owner.recordHashAt(7, RESPONSE, 1) != 0, "no half appended record");
    }

    function testWrongCollectionAndChangedTargetFailOpeningButResponsesStayAvailable() public {
        core.setCollection(2);
        StreamOwnerNoticeTypes.Designation memory d;
        (bool ok,) = address(owner)
            .call(
                abi.encodeCall(owner.openRecoveryNotice, (ID, calls, request, d, _publication(d)))
            );
        require(!ok, "actual token collection join");
        core.setCollection(1);
        core.setRecovery(address(core));
        (ok,) = address(owner)
            .call(
                abi.encodeCall(owner.openRecoveryNotice, (ID, calls, request, d, _publication(d)))
            );
        require(!ok, "canonical selected target required");
        _append(1, "public statement despite closed action read");
        core.setRecovery(address(recovery));
        _open();
        require(
            owner.recoveryNotice(ID).responseTail == 1, "same proof plus preserved early statement"
        );
    }

    function testUnknownAndWrongScopeEvidenceDoesNotManufactureNotice() public {
        require(!_valid(), "no notice invented");
        _open();
        vm.warp(END);
        StreamFinalityScope memory wrong = request.scope;
        wrong.collectionId = 2;
        (bool valid,,,,,) =
            owner.verifyRecoveryOwnerEvidence(wrong, ID, request.recoveryManifest.contentHash);
        require(!valid, "exact scope");
        (valid,,,,,) = owner.verifyRecoveryOwnerEvidence(request.scope, ID, keccak256("wrong"));
        require(!valid, "exact manifest");
        require(_valid(), "healthy actual binding");
    }

    function testGovernedIntentRaiseRequiresActualClassOneContextAndPreservesOldRows() public {
        bytes32 id = owner.RECOVERY_INTENT_READ_GAS();
        bytes32 scope = keccak256(
            abi.encode(
                bytes32(0x9533611d402c2b44cf950a4a8900d25f6829bfac541dc4d5353094f966bb1a71),
                block.chainid,
                address(owner),
                id
            )
        );
        bytes32 domain = 0x5059a253d3f7dd63b5d9fd1f0568caf72967f501a3db678b31cefe911334159c;
        bytes32 oldHash = keccak256(
            abi.encode(domain, scope, uint256(8000000), uint256(8000000), uint8(2), uint64(1))
        );
        bytes32 newHash = keccak256(
            abi.encode(domain, scope, uint256(16000000), uint256(8000000), uint8(2), uint64(2))
        );
        (bool ok,) = address(owner).call(abi.encodeCall(owner.raiseGasParameter, (id, 16000000)));
        require(!ok, "ordinary caller cannot raise");
        executor.execute(
            address(owner),
            abi.encodeCall(owner.raiseGasParameter, (id, 16000000)),
            scope,
            oldHash,
            newHash
        );
        require(
            owner.gasParameter(id) == 16000000
                && owner.gasParameter(owner.DEPENDENCY_READ_GAS()) == 150000,
            "separate governed budget"
        );
    }

    function _text(uint256 n, bytes1 value) private pure returns (string memory) {
        bytes memory out = new bytes(n);
        for (uint256 i; i < n; ++i) {
            out[i] = value;
        }
        return string(out);
    }

    function _url(uint256 n) private pure returns (string memory) {
        return string.concat("https://museum.example/", _text(n - 23, 0x61));
    }

    function testMaximumResponseAndNoticeClaimBytesArePreservedInSeparateChunks() public {
        StreamOwnerNoticeTypes.Designation memory d = _designation();
        d.name = _text(512, 0x61);
        d.identity.uri = _url(2048);
        d.contactEndpoints = new StreamOwnerNoticeTypes.Contact[](4);
        for (uint256 i; i < 4; ++i) {
            d.contactEndpoints[i] = StreamOwnerNoticeTypes.Contact(
                StreamOwnerNoticeTypes.ContactKind.HTTPS,
                string.concat(_url(1023), string(abi.encodePacked(bytes1(uint8(98 + i))))),
                0,
                address(0)
            );
        }
        uint256 length = StreamStewardDesignationJson.serialize(d).length;
        require(length < 8192 && 1024 + 8192 - length <= 2048, "maximum designation fixture");
        d.contactEndpoints[3].uri = _url(1024 + 8192 - length);
        _steward(d);
        StreamOwnerRecoveryNoticeTypes.Publication memory p = _publication(d);
        p.runbook.uri = _url(2048);
        p.publicNotice.uri = _url(2048);
        for (uint256 i; i < p.deliveries.length; ++i) {
            p.deliveries[i].evidence.uri = _url(2048);
        }
        require(
            abi.encode(p).length > 8192, "aggregate publication intentionally exceeds one chunk"
        );
        owner.openRecoveryNotice(ID, calls, request, d, p);
        for (uint256 i; i < p.deliveries.length; ++i) {
            (, bytes memory raw) = owner.recoveryNoticeClaim(ID, i + 1);
            require(
                keccak256(raw) == keccak256(abi.encode(p.deliveries[i])),
                "complete bounded per-endpoint bytes"
            );
        }
        StreamOwnerNoticeTypes.Response memory r = _response(1, _text(1900, 0x61));
        r.evidenceReferences = new StreamOwnerNoticeTypes.Reference[](4);
        for (uint256 i; i < 4; ++i) {
            r.evidenceReferences[i] = _ref(1, _url(1024));
        }
        length = StreamRecoveryResponseJson.serialize(r).length;
        require(length < 8192 && 1024 + 8192 - length <= 2048, "maximum response fixture");
        r.evidenceReferences[3].uri = _url(1024 + 8192 - length);
        bytes memory payload = StreamRecoveryResponseJson.serialize(r);
        require(payload.length == 8192, "exact total8192");
        IStreamOwnerRecords.OwnerRecord memory record =
            _record(RESPONSE, StreamOwnerNoticeDefinitions.RESPONSE_SCHEMA_ID, payload);
        record.uri = _url(2048);
        owner.recordRecoveryResponse(7, record, r);
        owner.processRecoveryResponse(ID);
        (IStreamOwnerRecords.OwnerRecord memory retained,) =
            owner.ownerRecord(owner.recordHashAt(7, RESPONSE, 0));
        require(
            keccak256(abi.encode(retained)) == keccak256(abi.encode(record)),
            "exact original maximum fields"
        );
    }

    function testExactNewResponseEventsAndQueueIndex() public {
        _open();
        vm.recordLogs();
        bytes32 hash = _append(1, "event original");
        Vm.Log[] memory logs = vm.getRecordedLogs();
        Vm.Log memory log = logs[logs.length - 1];
        require(
            log.emitter == address(owner) && log.topics.length == 4
                && log.topics[0]
                    == keccak256(
                        "OwnerRecoveryResponseRecorded(bytes32,address,bytes32,uint256,bool,bool,uint16)"
                    ) && log.topics[1] == ID
                && log.topics[2] == bytes32(uint256(uint160(address(this))))
                && log.topics[3] == hash
                && keccak256(log.data) == keccak256(abi.encode(uint256(7), true, false, uint16(1))),
            "exact appended response event"
        );
        vm.recordLogs();
        owner.processRecoveryResponse(ID);
        logs = vm.getRecordedLogs();
        log = logs[logs.length - 1];
        require(
            log.emitter == address(owner) && log.topics.length == 4
                && log.topics[0]
                    == keccak256(
                        "OwnerRecoveryResponseProcessed(bytes32,address,bytes32,bytes32,uint64,uint32,uint32,bytes32,uint16)"
                    ) && log.topics[1] == ID
                && log.topics[2] == bytes32(uint256(uint160(address(this))))
                && log.topics[3] == hash
                && keccak256(log.data)
                    == keccak256(
                        abi.encode(
                            bytes32(0),
                            uint64(2),
                            uint32(0),
                            uint32(1),
                            owner.recoveryNotice(ID).evidenceHash,
                            uint16(1)
                        )
                    ),
            "exact processed event"
        );
        require(owner.recoveryResponseAt(ID, 0) == hash, "same original queue hash");
    }

    function testValidationOnlyPublicationPreservesAllSixReferenceFamiliesAndOpaqueBytes() public {
        OwnerNoticeSnapshotVm snap = OwnerNoticeSnapshotVm(address(vm));
        uint256 checkpoint = snap.snapshotState();
        for (uint16 algorithm = 1; algorithm <= 6; ++algorithm) {
            StreamOwnerNoticeTypes.Designation memory d;
            StreamOwnerRecoveryNoticeTypes.Publication memory p = _publication(d);
            p.runbook = _ref(algorithm, "ipfs://runbook");
            p.publicNotice = _ref(algorithm, "ar://public-notice");
            p.deliveries[0].evidence = _ref(algorithm, "https://museum.example/claim");
            owner.openRecoveryNotice(ID, calls, request, d, p);
            (, bytes memory raw) = owner.recoveryNoticeClaim(ID, 0);
            require(
                keccak256(raw) == keccak256(abi.encode(p.runbook, p.publicNotice)),
                "exact original references"
            );
            require(snap.revertToState(checkpoint), "independent algorithm frame");
        }
    }

    function testValidationOnlyPublicationRejectsEveryBadReferenceShapeThenExactRetry() public {
        for (uint256 fault; fault < 9; ++fault) {
            StreamOwnerNoticeTypes.Designation memory d;
            StreamOwnerRecoveryNoticeTypes.Publication memory p = _publication(d);
            if (fault == 0) {
                p.runbook.algorithm = 0;
            } else if (fault == 1) {
                p.runbook.algorithm = 7;
            } else if (fault == 2) {
                p.runbook.canonicalizationId = 0;
            } else if (fault == 3) {
                p.runbook.digest = new bytes(31);
            } else if (fault == 4) {
                p.runbook.algorithm = 4;
                p.runbook.digest = new bytes(0);
            } else if (fault == 5) {
                p.runbook.algorithm = 5;
                p.runbook.digest = new bytes(129);
            } else if (fault == 6) {
                p.runbook.uri = "";
            } else if (fault == 7) {
                p.runbook.uri = _url(2049);
            } else {
                bytes memory invalidUtf8 = hex"68747470733a2f2fff";
                p.runbook.uri = string(invalidUtf8);
            }
            (bool ok,) = address(owner)
                .call(abi.encodeCall(owner.openRecoveryNotice, (ID, calls, request, d, p)));
            require(!ok, "invalid reference never opens");
        }
        _open();
        require(
            owner.recoveryNotice(ID).openingOwner == address(this),
            "original healthy opening still available"
        );
    }

    event PreparedGas(bytes32 label, uint256 gasUsed, uint256 deliveryCount);

    function _begin(
        StreamOwnerNoticeTypes.Designation memory d,
        StreamOwnerRecoveryNoticeTypes.Publication memory p,
        uint256 nonce
    ) private returns (bytes32) {
        return owner.prepareRecoveryNotice(
            StreamOwnerPreparedNoticeTypes.Input(7, ID, nonce, d, p.runbook, p.publicNotice)
        );
    }

    function _deliver(bytes32 id, StreamOwnerRecoveryNoticeTypes.Publication memory p) private {
        for (uint256 i; i < p.deliveries.length; ++i) {
            owner.prepareRecoveryNoticeDelivery(id, p.deliveries[i]);
        }
    }

    function testPreparedPublisherFinalizerAndLegacyHashBytesAreExact() public {
        StreamOwnerNoticeTypes.Designation memory d = _designation();
        _steward(d);
        StreamOwnerRecoveryNoticeTypes.Publication memory p = _publication(d);
        uint256 checkpoint = OwnerNoticeSnapshotVm(address(vm)).snapshotState();
        owner.openRecoveryNotice(ID, calls, request, d, p);
        bytes memory expected = abi.encode(owner.recoveryNotice(ID));
        require(
            OwnerNoticeSnapshotVm(address(vm)).revertToState(checkpoint),
            "separate original opening"
        );
        bytes32 id = _begin(d, p, 1);
        _deliver(id, p);
        vm.recordLogs();
        vm.prank(address(0xbeef));
        owner.openPreparedRecoveryNotice(id, calls, request);
        require(
            keccak256(abi.encode(owner.recoveryNotice(ID))) == keccak256(expected),
            "original publication, attribution and evidence hash exact"
        );
        Vm.Log[] memory logs = vm.getRecordedLogs();
        Vm.Log memory last = logs[logs.length - 1];
        require(
            last.topics[0]
                    == keccak256(
                        "OwnerRecoveryNoticePreparedOpening(bytes32,bytes32,address,address,uint16)"
                    ) && last.topics[1] == id && last.topics[2] == ID
                && last.topics[3] == bytes32(uint256(uint160(address(this))))
                && keccak256(last.data) == keccak256(abi.encode(address(0xbeef), uint16(1))),
            "publisher and finalizer distinct"
        );
        require(
            owner.recoveryNoticePreparationFor(ID) == id
                && owner.recoveryNoticePreparation(id).consumed,
            "permanent original preparation link"
        );
        for (uint256 i; i <= p.deliveries.length; ++i) {
            (address a, bytes memory x) = owner.recoveryNoticeClaim(ID, i);
            (address b, bytes memory y) = owner.recoveryNoticePreparedClaim(id, i);
            bytes memory original =
                i == 0 ? abi.encode(p.runbook, p.publicNotice) : abi.encode(p.deliveries[i - 1]);
            require(
                a == b && keccak256(x) == keccak256(original)
                    && keccak256(y) == keccak256(original),
                "same complete canonical claim bytes"
            );
        }
    }

    function testPreparedNoClockUntilAtomicOpeningAndResponsesDuringPreparationCount() public {
        _append(1, "before preparation");
        StreamOwnerNoticeTypes.Designation memory d;
        StreamOwnerRecoveryNoticeTypes.Publication memory p = _publication(d);
        bytes32 id = _begin(d, p, 2);
        require(!_valid(), "preparation creates no notice");
        _append(0, "during preparation");
        vm.warp(9000);
        _deliver(id, p);
        owner.openPreparedRecoveryNotice(id, calls, request);
        StreamOwnerRecoveryNoticeTypes.Snapshot memory n = owner.recoveryNotice(ID);
        require(
            n.openedAt == 9000 && n.noticeEndsAt == 9000 + 72 hours && n.firstResponseIndex == 2
                && n.responseTail == 2 && n.processed == 0,
            "final opening clock and exact original-index barrier"
        );
        vm.warp(n.noticeEndsAt);
        require(!_valid(), "unprocessed full tail prevents stale count");
        owner.processRecoveryResponse(ID);
        require(!_valid(), "every candidate must be processed");
        owner.processRecoveryResponse(ID);
        require(
            _valid() && owner.recoveryNotice(ID).acknowledgements == 1
                && owner.recoveryNotice(ID).objections == 0,
            "latest exact action owner answer"
        );
    }

    function testPreparedHeadAndOwnerCASWithDurableReactivation() public {
        StreamOwnerNoticeTypes.Designation memory d = _designation();
        bytes32 head = _steward(d);
        StreamOwnerRecoveryNoticeTypes.Publication memory p = _publication(d);
        bytes32 id = _begin(d, p, 3);
        _deliver(id, p);
        core.setOwner(7, address(0xbeef));
        (bool ok,) = address(owner)
            .call(abi.encodeCall(owner.openPreparedRecoveryNotice, (id, calls, request)));
        require(
            !ok && !owner.recoveryNoticePreparation(id).consumed,
            "changed owner cannot use frozen recipients"
        );
        core.setOwner(7, address(this));
        uint256 checkpoint = OwnerNoticeSnapshotVm(address(vm)).snapshotState();
        d.predecessor = head;
        d.name = "new designation";
        _steward(d);
        (ok,) = address(owner)
            .call(abi.encodeCall(owner.openPreparedRecoveryNotice, (id, calls, request)));
        require(!ok && !owner.recoveryNoticePreparation(id).consumed, "exact durable head CAS");
        require(
            OwnerNoticeSnapshotVm(address(vm)).revertToState(checkpoint),
            "restore original head frame"
        );
        owner.openPreparedRecoveryNotice(id, calls, request);
        require(
            owner.recoveryNotice(ID).stewardRecordHash == head,
            "A B A original head intentionally reactivated"
        );
    }

    function testPreparedIncompleteWrongBatchAndClosedActionRollbackThenRetry() public {
        StreamOwnerNoticeTypes.Designation memory d;
        StreamOwnerRecoveryNoticeTypes.Publication memory p = _publication(d);
        bytes32 id = _begin(d, p, 4);
        (bool ok,) = address(owner)
            .call(abi.encodeCall(owner.openPreparedRecoveryNotice, (id, calls, request)));
        require(!ok, "incomplete cannot open");
        _deliver(id, p);
        _status(3);
        (ok,) = address(owner)
            .call(abi.encodeCall(owner.openPreparedRecoveryNotice, (id, calls, request)));
        require(
            !ok && !owner.recoveryNoticePreparation(id).consumed,
            "cancelled action rolls consumption back"
        );
        _status(1);
        GovernanceCall[] memory wrong = calls;
        wrong[0].newValueHash = keccak256("wrong full call");
        (ok,) = address(owner)
            .call(abi.encodeCall(owner.openPreparedRecoveryNotice, (id, wrong, request)));
        require(
            !ok && owner.recoveryNoticePreparationFor(ID) == 0, "wrong calls cannot consume proof"
        );
        StreamFinalityRecoveryRequest memory wrongRequest = request;
        wrongRequest.reasonURI = "ipfs://mutated";
        (ok,) = address(owner)
            .call(abi.encodeCall(owner.openPreparedRecoveryNotice, (id, calls, wrongRequest)));
        require(
            !ok && !owner.recoveryNoticePreparation(id).consumed, "original full request retained"
        );
        owner.openPreparedRecoveryNotice(id, calls, request);
        require(owner.recoveryNoticePreparation(id).consumed, "identical healthy proof retry");
    }

    function testPreparedExpiryCheckedAtFinalOpeningIncludingEquality() public {
        StreamOwnerNoticeTypes.Designation memory d;
        StreamOwnerRecoveryNoticeTypes.Publication memory p = _publication(d);
        bytes32 id = _begin(d, p, 5);
        _deliver(id, p);
        vm.warp(EXPIRY - 72 hours + 1);
        (bool ok,) = address(owner)
            .call(abi.encodeCall(owner.openPreparedRecoveryNotice, (id, calls, request)));
        require(
            !ok && !owner.recoveryNoticePreparation(id).consumed,
            "elapsed preparation cannot steal notice window"
        );
        vm.warp(EXPIRY - 72 hours);
        owner.openPreparedRecoveryNotice(id, calls, request);
        vm.warp(EXPIRY);
        require(_valid(), "exact expiry equality and own elapsed window");
    }

    function testPreparedPublisherOnlyAndEveryEndpointTupleFieldBound() public {
        StreamOwnerNoticeTypes.Designation memory d = _designation();
        _steward(d);
        StreamOwnerRecoveryNoticeTypes.Publication memory p = _publication(d);
        uint256 checkpoint = OwnerNoticeSnapshotVm(address(vm)).snapshotState();
        for (uint256 fault; fault < 6; ++fault) {
            bytes32 id = _begin(d, p, 6);
            vm.prank(address(0xbeef));
            (bool ok,) = address(owner)
                .call(abi.encodeCall(owner.prepareRecoveryNoticeDelivery, (id, p.deliveries[0])));
            require(
                !ok && owner.recoveryNoticePreparation(id).preparedCount == 0,
                "foreign caller cannot replace claim refs"
            );
            StreamOwnerRecoveryNoticeTypes.Delivery memory bad =
                abi.decode(abi.encode(p.deliveries[0]), (StreamOwnerRecoveryNoticeTypes.Delivery));
            if (fault == 0) bad.endpoint.account = address(0xbeef);
            else if (fault == 1) ++bad.endpoint.chainId;
            else if (fault == 2) bad.endpoint.uri = "https://a";
            else if (fault == 3) bad.endpoint.kind = StreamOwnerNoticeTypes.ContactKind.HTTPS;
            else bad = p.deliveries[1];
            owner.prepareRecoveryNoticeDelivery(id, bad);
            owner.prepareRecoveryNoticeDelivery(id, fault == 5 ? p.deliveries[0] : p.deliveries[1]);
            (ok,) = address(owner)
                .call(abi.encodeCall(owner.prepareRecoveryNoticeDelivery, (id, p.deliveries[2])));
            require(
                !ok && !owner.recoveryNoticePreparation(id).complete,
                "wrong field, duplicate, or order cannot complete"
            );
            require(
                OwnerNoticeSnapshotVm(address(vm)).revertToState(checkpoint),
                "independent ordered-root fault"
            );
        }
    }

    function testPreparedLastClaimRetryAndCompletionIrrevocablyFreezesPlan() public {
        StreamOwnerNoticeTypes.Designation memory d;
        StreamOwnerRecoveryNoticeTypes.Publication memory p = _publication(d);
        bytes32 id = _begin(d, p, 7);
        StreamOwnerRecoveryNoticeTypes.Delivery memory bad =
            abi.decode(abi.encode(p.deliveries[0]), (StreamOwnerRecoveryNoticeTypes.Delivery));
        bad.endpoint.account = address(0xbeef);
        (bool ok,) =
            address(owner).call(abi.encodeCall(owner.prepareRecoveryNoticeDelivery, (id, bad)));
        require(
            !ok && owner.recoveryNoticePreparation(id).preparedCount == 0,
            "failed final row fully rolled back"
        );
        _deliver(id, p);
        bytes32 original = keccak256(abi.encode(owner.recoveryNoticePreparation(id)));
        (ok,) = address(owner)
            .call(abi.encodeCall(owner.prepareRecoveryNoticeDelivery, (id, p.deliveries[0])));
        require(
            !ok && keccak256(abi.encode(owner.recoveryNoticePreparation(id))) == original,
            "completed count, root and refs frozen"
        );
        (ok,) = address(owner)
            .call(
                abi.encodeCall(
                    owner.prepareRecoveryNotice,
                    (StreamOwnerPreparedNoticeTypes.Input(7, ID, 7, d, p.runbook, p.publicNotice))
                )
            );
        require(!ok, "same domain plan cannot be overwritten");
    }

    function testPreparedOriginalWitnessAndUnknownTokenAreRequired() public {
        StreamOwnerNoticeTypes.Designation memory d = _designation();
        _steward(d);
        StreamOwnerRecoveryNoticeTypes.Publication memory p = _publication(d);
        d.name = "forged original";
        (bool ok,) = address(owner)
            .call(
                abi.encodeCall(
                    owner.prepareRecoveryNotice,
                    (StreamOwnerPreparedNoticeTypes.Input(7, ID, 8, d, p.runbook, p.publicNotice))
                )
            );
        require(!ok, "full saved canonical designation witness");
        d = _designation();
        core.setOwner(0, address(this));
        (ok,) = address(owner)
            .call(
                abi.encodeCall(
                    owner.prepareRecoveryNotice,
                    (StreamOwnerPreparedNoticeTypes.Input(0, ID, 8, d, p.runbook, p.publicNotice))
                )
            );
        require(!ok, "token zero not invented through fixture");
        core.setOwner(7, address(0));
        (ok,) = address(owner)
            .call(
                abi.encodeCall(
                    owner.prepareRecoveryNotice,
                    (StreamOwnerPreparedNoticeTypes.Input(7, ID, 8, d, p.runbook, p.publicNotice))
                )
            );
        require(!ok, "unknown burned token cannot prepare");
    }

    function testPreparedAllSixReferencesAndImmutableCodeIntegrity() public {
        StreamOwnerNoticeTypes.Designation memory d;
        StreamOwnerRecoveryNoticeTypes.Publication memory p = _publication(d);
        for (uint16 algorithm = 1; algorithm <= 6; ++algorithm) {
            p.runbook = _ref(algorithm, "ipfs://runbook");
            p.publicNotice = _ref(algorithm, "ar://notice");
            p.deliveries[0].evidence = _ref(algorithm, "https://claim.example/");
            bytes32 id = _begin(d, p, algorithm + 100);
            _deliver(id, p);
            (address pointer, bytes memory raw) = owner.recoveryNoticePreparedClaim(id, 1);
            require(
                keccak256(raw) == keccak256(abi.encode(p.deliveries[0])),
                "all six exact opaque references"
            );
            bytes memory code = pointer.code;
            bytes memory changed = abi.encodePacked(bytes1(0x01), raw);
            vm.etch(pointer, changed);
            (bool ok,) = address(owner)
                .staticcall(abi.encodeCall(owner.recoveryNoticePreparedClaim, (id, 1)));
            require(!ok, "STOP carrier prefix required");
            changed[0] = 0;
            changed[changed.length - 1] = bytes1(uint8(changed[changed.length - 1]) ^ 1);
            vm.etch(pointer, changed);
            (ok,) = address(owner)
                .staticcall(abi.encodeCall(owner.recoveryNoticePreparedClaim, (id, 1)));
            require(!ok, "full original bytes hash required");
            vm.etch(pointer, code);
            (, raw) = owner.recoveryNoticePreparedClaim(id, 1);
            require(
                keccak256(raw) == keccak256(abi.encode(p.deliveries[0])), "exact original restore"
            );
        }
    }

    function testPreparedStoreFailureLeavesNoPartialDeliveryThenExactRetry() public {
        StreamOwnerNoticeTypes.Designation memory d;
        StreamOwnerRecoveryNoticeTypes.Publication memory p = _publication(d);
        bytes32 id = _begin(d, p, 9);
        bytes memory code = address(store).code;
        vm.etch(address(store), hex"00");
        (bool ok,) = address(owner)
            .call(abi.encodeCall(owner.prepareRecoveryNoticeDelivery, (id, p.deliveries[0])));
        require(
            !ok && owner.recoveryNoticePreparation(id).preparedCount == 0,
            "failed write keeps root/count unchanged"
        );
        vm.etch(address(store), code);
        _deliver(id, p);
        require(owner.recoveryNoticePreparation(id).complete, "identical healthy delivery retry");
    }

    function testPreparedEncodingReadOraclesAndOriginalErrors() public {
        bytes32 hash = _append(1, "retained exact tuple");
        (
            IStreamOwnerRecords.OwnerRecord memory record,
            IStreamOwnerRecords.Receipt memory receipt
        ) = owner.ownerRecord(hash);
        (bool ok, bytes memory raw) =
            address(owner).staticcall(abi.encodeCall(owner.ownerRecord, (hash)));
        require(
            ok && keccak256(raw) == keccak256(abi.encode(record, receipt))
                && receipt.owner == address(this) && receipt.recordIndex == 0
                && record.contentHash.algorithm == 1,
            "canonical full owner return"
        );
        (address pointer, bytes memory bundle) = owner.ownerRecordSignatureBundle(hash);
        (ok, raw) =
            address(owner).staticcall(abi.encodeCall(owner.ownerRecordSignatureBundle, (hash)));
        require(
            ok && keccak256(raw) == keccak256(abi.encode(pointer, bundle))
                && keccak256(bundle)
                    == keccak256(
                        abi.encode(keccak256("DIRECT"), address(this), keccak256(record.payload))
                    ),
            "original direct bundle"
        );
        (ok, raw) =
            address(owner).staticcall(abi.encodeCall(owner.ownerRecord, (bytes32(uint256(99)))));
        require(
            !ok
                && keccak256(raw)
                    == keccak256(
                        abi.encodeWithSelector(
                            IStreamOwnerRecords.OwnerRecordUnknown.selector, bytes32(uint256(99))
                        )
                    ),
            "original unknown error exact"
        );
        _open();
        (ok, raw) = address(owner).staticcall(abi.encodeCall(owner.recoveryNotice, (ID)));
        require(
            ok && keccak256(raw) == keccak256(abi.encode(owner.recoveryNotice(ID))),
            "full canonical notice return"
        );
        (ok, raw) = address(owner).staticcall(abi.encodeCall(owner.recoveryResponse, (hash)));
        require(
            ok && keccak256(raw) == keccak256(abi.encode(owner.recoveryResponse(hash))),
            "full canonical response return"
        );
    }

    function testPreparedManyShortEndpointsHaveBoundedIndividualPublicationAndConstantFinalOpen()
        public
    {
        StreamOwnerNoticeTypes.Designation memory d = _designation();
        d.name = "x";
        d.identity.uri = "ipfs://i";
        d.contactEndpoints = new StreamOwnerNoticeTypes.Contact[](190);
        for (uint256 i; i < d.contactEndpoints.length; ++i) {
            d.contactEndpoints[i] = StreamOwnerNoticeTypes.Contact(
                StreamOwnerNoticeTypes.ContactKind.HTTPS,
                string(
                    abi.encodePacked(
                        "https://", bytes1(uint8(97 + i / 26)), bytes1(uint8(97 + i % 26))
                    )
                ),
                0,
                address(0)
            );
        }
        bytes memory serialized = StreamStewardDesignationJson.serialize(d);
        require(
            serialized.length <= 8192 && d.contactEndpoints.length > 100,
            "many valid original endpoints"
        );
        _steward(d);
        StreamOwnerRecoveryNoticeTypes.Publication memory p = _publication(d);
        uint256 beforeGas = gasleft();
        bytes32 id = _begin(d, p, 10);
        emit PreparedGas("many-begin", beforeGas - gasleft(), p.deliveries.length);
        uint256 largest;
        for (uint256 i; i < p.deliveries.length; ++i) {
            beforeGas = gasleft();
            owner.prepareRecoveryNoticeDelivery(id, p.deliveries[i]);
            uint256 used = beforeGas - gasleft();
            if (used > largest) largest = used;
        }
        emit PreparedGas("many-delivery", largest, p.deliveries.length);
        beforeGas = gasleft();
        owner.openPreparedRecoveryNotice(id, calls, request);
        uint256 opened = beforeGas - gasleft();
        emit PreparedGas("many-open", opened, p.deliveries.length);
        require(
            largest < 1500000 && opened < 2000000,
            "individual delivery and final opening bounded independently of endpoint count"
        );
        require(owner.recoveryNotice(ID).deliveryCount == 191, "every endpoint retained");
    }

    function _coolPrepared() private {
        safeVm.cool(address(owner));
        safeVm.cool(address(core));
        safeVm.cool(address(executor));
        safeVm.cool(address(recovery));
        safeVm.cool(address(store));
        safeVm.cool(address(StreamOwnerRecoveryNoticeState));
        safeVm.cool(address(StreamOwnerRecoveryNoticePreparation));
        safeVm.cool(address(StreamOwnerRecoveryActionReads));
        safeVm.cool(address(StreamOwnerRecordReads));
        safeVm.cool(address(StreamOwnerNoticeFields));
        safeVm.cool(address(StreamStewardDesignationJson));
        safeVm.cool(address(StreamRecordJson));
        safeVm.cool(address(StreamMetadataRenderer));
    }

    function testPreparedMaximumPayloadAndURIClaimsUseBoundedColdTransactions() public {
        StreamOwnerNoticeTypes.Designation memory d = _designation();
        d.name = _text(512, 0x61);
        d.identity.uri = _url(2048);
        d.contactEndpoints = new StreamOwnerNoticeTypes.Contact[](4);
        for (uint256 i; i < 4; ++i) {
            d.contactEndpoints[i] = StreamOwnerNoticeTypes.Contact(
                StreamOwnerNoticeTypes.ContactKind.HTTPS,
                string.concat(_url(1023), string(abi.encodePacked(bytes1(uint8(98 + i))))),
                0,
                address(0)
            );
        }
        uint256 length = StreamStewardDesignationJson.serialize(d).length;
        d.contactEndpoints[3].uri = _url(1024 + 8192 - length);
        require(
            StreamStewardDesignationJson.serialize(d).length == 8192,
            "exact entire designation limit"
        );
        _steward(d);
        StreamOwnerRecoveryNoticeTypes.Publication memory p = _publication(d);
        p.runbook = _ref(4, _url(2048));
        p.runbook.digest = new bytes(128);
        p.publicNotice = _ref(5, _url(2048));
        p.publicNotice.digest = new bytes(128);
        for (uint256 i; i < p.deliveries.length; ++i) {
            p.deliveries[i].evidence = _ref(4, _url(2048));
            p.deliveries[i].evidence.digest = new bytes(128);
        }
        _coolPrepared();
        uint256 beforeGas = gasleft();
        bytes32 id = _begin(d, p, 120);
        uint256 used = beforeGas - gasleft();
        emit PreparedGas("max-begin", used, p.deliveries.length);
        require(used < 30000000, "bounded whole designation authentication and base claim");
        uint256 largest;
        for (uint256 i; i < p.deliveries.length; ++i) {
            _coolPrepared();
            beforeGas = gasleft();
            owner.prepareRecoveryNoticeDelivery(id, p.deliveries[i]);
            used = beforeGas - gasleft();
            if (used > largest) largest = used;
            (, bytes memory retained) = owner.recoveryNoticePreparedClaim(id, i + 1);
            require(
                keccak256(retained) == keccak256(abi.encode(p.deliveries[i])),
                "all maximum reference bytes intact"
            );
        }
        emit PreparedGas("max-delivery", largest, p.deliveries.length);
        require(largest < 5000000, "one full maximum delivery transaction");
        _coolPrepared();
        beforeGas = gasleft();
        owner.openPreparedRecoveryNotice(id, calls, request);
        used = beforeGas - gasleft();
        emit PreparedGas("max-open", used, p.deliveries.length);
        require(
            used < 2000000 && owner.recoveryNotice(ID).deliveryCount == 5,
            "fixed final opening with complete endpoints"
        );
    }

    function testPreparedDomainBindsLiteralChainHostPublisherNonceTokenAndAction() public {
        StreamOwnerNoticeTypes.Designation memory d;
        StreamOwnerRecoveryNoticeTypes.Publication memory p = _publication(d);
        bytes32 id = _begin(d, p, 125);
        bytes32 expected = keccak256(
            abi.encode(
                keccak256("6529STREAM_OWNER_NOTICE_PREPARATION_V1"),
                block.chainid,
                address(owner),
                address(this),
                uint256(125),
                uint256(7),
                ID,
                address(this),
                bytes32(0),
                keccak256(abi.encode(p.runbook, p.publicNotice))
            )
        );
        require(id == expected, "independently encoded full preparation domain");
        require(_begin(d, p, 126) != id, "nonce separation");
        vm.prank(address(0xbeef));
        bytes32 other = _begin(d, p, 125);
        require(
            other != id && owner.recoveryNoticePreparation(other).publisher == address(0xbeef),
            "publisher separation without owner impersonation"
        );
        vm.chainId(block.chainid + 1);
        other = _begin(d, p, 125);
        require(other != id, "chain separation");
    }

    function testPreparedMalformedReferencesHaveNoPartialPlanOrDelivery() public {
        StreamOwnerNoticeTypes.Designation memory d;
        StreamOwnerRecoveryNoticeTypes.Publication memory p = _publication(d);
        bytes32 id = _begin(d, p, 130);
        for (uint256 fault; fault < 9; ++fault) {
            StreamOwnerNoticeTypes.Reference memory bad = _ref(1, "ipfs://reference");
            if (fault == 0) {
                bad.algorithm = 0;
            } else if (fault == 1) {
                bad.algorithm = 7;
            } else if (fault == 2) {
                bad.canonicalizationId = 0;
            } else if (fault == 3) {
                bad.digest = new bytes(31);
            } else if (fault == 4) {
                bad.algorithm = 4;
                bad.digest = new bytes(0);
            } else if (fault == 5) {
                bad.algorithm = 5;
                bad.digest = new bytes(129);
            } else if (fault == 6) {
                bad.uri = "";
            } else if (fault == 7) {
                bad.uri = _url(2049);
            } else {
                bytes memory invalid = hex"697066733a2f2fff";
                bad.uri = string(invalid);
            }
            (bool ok,) = address(owner)
                .call(
                    abi.encodeCall(
                        owner.prepareRecoveryNotice,
                        (StreamOwnerPreparedNoticeTypes.Input(7, ID, 131, d, bad, p.publicNotice))
                    )
                );
            require(!ok, "bad base reference rejects");
            StreamOwnerRecoveryNoticeTypes.Delivery memory delivery =
                StreamOwnerRecoveryNoticeTypes.Delivery(p.deliveries[0].endpoint, bad);
            (ok,) = address(owner)
                .call(abi.encodeCall(owner.prepareRecoveryNoticeDelivery, (id, delivery)));
            require(
                !ok && owner.recoveryNoticePreparation(id).preparedCount == 0,
                "bad delivery does not advance commitment"
            );
        }
        _deliver(id, p);
        owner.openPreparedRecoveryNotice(id, calls, request);
    }

    function testPreparedActualThresholdSafeWritesReadsAndEOAOwnerCannotReplacePublisher() public {
        SafeComponents memory components = deploySafeComponents("1.4.1");
        uint256[] memory keys = new uint256[](3);
        keys[0] = 6201;
        keys[1] = 6202;
        keys[2] = 6203;
        OfficialSafe account = createOfficialSafe(components, safeOwnerAddresses(keys), 2, 120);
        core.setOwner(7, address(account));
        StreamOwnerNoticeTypes.Designation memory d;
        StreamOwnerRecoveryNoticeTypes.Publication memory p = _publication(d);
        StreamOwnerPreparedNoticeTypes.Input memory input =
            StreamOwnerPreparedNoticeTypes.Input(7, ID, 140, d, p.runbook, p.publicNotice);
        vm.recordLogs();
        require(
            executeSafe(
                account,
                keys,
                address(owner),
                0,
                abi.encodeCall(owner.prepareRecoveryNotice, (input)),
                0
            ),
            "actual threshold preparation"
        );
        Vm.Log[] memory logs = vm.getRecordedLogs();
        bytes32 id;
        for (uint256 i; i < logs.length; ++i) {
            if (
                logs[i].emitter == address(owner)
                    && logs[i].topics[0]
                        == keccak256(
                            "OwnerRecoveryNoticePreparing(bytes32,bytes32,address,uint256,address,bytes32,uint64,uint16)"
                        )
            ) id = logs[i].topics[1];
        }
        require(
            id != 0 && owner.recoveryNoticePreparation(id).publisher == address(account),
            "actual Safe attributed publisher"
        );
        vm.prank(vm.addr(keys[0]));
        (bool ok,) = address(owner)
            .call(abi.encodeCall(owner.prepareRecoveryNoticeDelivery, (id, p.deliveries[0])));
        require(!ok, "individual signer is not Safe publisher");
        require(
            executeSafe(
                account,
                keys,
                address(owner),
                0,
                abi.encodeCall(owner.prepareRecoveryNoticeDelivery, (id, p.deliveries[0])),
                0
            ),
            "actual Safe delivery"
        );
        require(
            executeSafe(
                account,
                keys,
                address(owner),
                0,
                abi.encodeCall(owner.openPreparedRecoveryNotice, (id, calls, request)),
                0
            ),
            "actual Safe finalization"
        );
        require(
            executeSafe(
                account,
                keys,
                address(owner),
                0,
                abi.encodeCall(owner.recoveryNoticePreparation, (id)),
                0
            ),
            "actual Safe preparation read"
        );
        require(
            executeSafe(
                account,
                keys,
                address(owner),
                0,
                abi.encodeCall(owner.recoveryNoticePreparedClaim, (id, 1)),
                0
            ),
            "actual Safe original claim read"
        );
        require(
            executeSafe(
                account,
                keys,
                address(owner),
                0,
                abi.encodeCall(owner.recoveryNoticePreparationFor, (ID)),
                0
            ),
            "actual Safe action-plan read"
        );
        require(
            owner.recoveryNotice(ID).openingOwner == address(account)
                && owner.supportsInterface(type(IStreamOwnerPreparedRecoveryNotices).interfaceId),
            "actual owner and additive capability"
        );
    }

    function testColdOriginal214EndpointDesignationWriterFits16MGas() public {
        StreamOwnerNoticeTypes.Designation memory d = _designation();
        d.name = "x";
        d.identity.uri = "ipfs://i";
        d.contactEndpoints = new StreamOwnerNoticeTypes.Contact[](214);
        for (uint256 i; i < 214; ++i) {
            d.contactEndpoints[i] = StreamOwnerNoticeTypes.Contact(
                StreamOwnerNoticeTypes.ContactKind.HTTPS,
                string(
                    abi.encodePacked(
                        "https://", bytes1(uint8(97 + i / 26)), bytes1(uint8(97 + i % 26))
                    )
                ),
                0,
                address(0)
            );
        }
        d.contactEndpoints[213].uri = string.concat(d.contactEndpoints[213].uri, "xxxxxx");
        bytes memory payload = StreamStewardDesignationJson.serialize(d);
        require(payload.length == 8192, "exact complete payload boundary");
        IStreamOwnerRecords.OwnerRecord memory r = _record(
            keccak256("STEWARD_DESIGNATION"),
            StreamOwnerNoticeDefinitions.STEWARD_SCHEMA_ID,
            payload
        );
        _coolPrepared();
        safeVm.cool(address(schemas));
        safeVm.cool(address(StreamOwnerNoticeAdmission));
        safeVm.cool(address(StreamOwnerRecordBook));
        uint256 beforeGas = gasleft();
        owner.recordStewardDesignation(7, r, d);
        uint256 used = beforeGas - gasleft();
        emit PreparedGas("214-original-writer", used, 214);
        require(used < 16000000, "named-target cold original writer exceeds practical16M probe");
        bytes32 head = owner.stewardDesignationFor(7, address(this));
        (IStreamOwnerRecords.OwnerRecord memory saved,) = owner.ownerRecord(head);
        require(
            head != 0 && keccak256(saved.payload) == keccak256(payload), "exact admitted payload"
        );
    }

    function testPreparedExact8192ShortEndpointFamilyRejectsNextEntryAndPublishesEveryClaim()
        public
    {
        StreamOwnerNoticeTypes.Designation memory d = _designation();
        d.name = "x";
        d.identity.uri = "ipfs://i";
        d.contactEndpoints = new StreamOwnerNoticeTypes.Contact[](214);
        for (uint256 i; i < 214; ++i) {
            d.contactEndpoints[i] = StreamOwnerNoticeTypes.Contact(
                StreamOwnerNoticeTypes.ContactKind.HTTPS,
                string(
                    abi.encodePacked(
                        "https://", bytes1(uint8(97 + i / 26)), bytes1(uint8(97 + i % 26))
                    )
                ),
                0,
                address(0)
            );
        }
        require(
            StreamStewardDesignationJson.serialize(d).length == 8186,
            "independent canonical family byte arithmetic"
        );
        StreamOwnerNoticeTypes.Designation memory extra =
            abi.decode(abi.encode(d), (StreamOwnerNoticeTypes.Designation));
        extra.contactEndpoints = new StreamOwnerNoticeTypes.Contact[](215);
        for (uint256 i; i < 214; ++i) {
            extra.contactEndpoints[i] = d.contactEndpoints[i];
        }
        extra.contactEndpoints[214] = StreamOwnerNoticeTypes.Contact(
            StreamOwnerNoticeTypes.ContactKind.HTTPS, "https://ig", 0, address(0)
        );
        (bool ok,) = address(StreamStewardDesignationJson)
            .staticcall(
                abi.encodeWithSelector(StreamStewardDesignationJson.serialize.selector, extra)
            );
        require(!ok, "next same-family entry exceeds complete8192");
        d.contactEndpoints[213].uri = string.concat(d.contactEndpoints[213].uri, "xxxxxx");
        require(
            StreamStewardDesignationJson.serialize(d).length == 8192,
            "exact complete limit with214 distinct endpoints"
        );
        _steward(d);
        StreamOwnerRecoveryNoticeTypes.Publication memory p = _publication(d);
        _coolPrepared();
        uint256 beforeGas = gasleft();
        bytes32 id = _begin(d, p, 150);
        uint256 used = beforeGas - gasleft();
        emit PreparedGas("214-begin", used, 215);
        require(used < 30000000, "entire admitted witness remains one bounded preparation");
        uint256 largest;
        for (uint256 i; i < p.deliveries.length; ++i) {
            _coolPrepared();
            beforeGas = gasleft();
            owner.prepareRecoveryNoticeDelivery(id, p.deliveries[i]);
            used = beforeGas - gasleft();
            if (used > largest) largest = used;
        }
        emit PreparedGas("214-delivery", largest, 215);
        require(largest < 1500000, "independent per-claim publication");
        _coolPrepared();
        beforeGas = gasleft();
        owner.openPreparedRecoveryNotice(id, calls, request);
        used = beforeGas - gasleft();
        emit PreparedGas("214-open", used, 215);
        require(used < 2000000, "fixed final opening never loops214 endpoints");
        require(owner.recoveryNotice(ID).deliveryCount == 215, "no dropped endpoint");
        for (uint256 i; i < p.deliveries.length; ++i) {
            (, bytes memory raw) = owner.recoveryNoticeClaim(ID, i + 1);
            require(
                keccak256(raw) == keccak256(abi.encode(p.deliveries[i])),
                "every final ordered claim exactly retrievable"
            );
        }
    }

    function testPreparedAbsoluteABIClaimBoundsArePublishedWithEveryMaximumField() public {
        StreamOwnerNoticeTypes.Designation memory d = _designation();
        d.name = _text(512, 0x61);
        d.identity.uri = _url(2048);
        d.contactEndpoints = new StreamOwnerNoticeTypes.Contact[](1);
        d.contactEndpoints[0] = StreamOwnerNoticeTypes.Contact(
            StreamOwnerNoticeTypes.ContactKind.HTTPS, _url(2048), 0, address(0)
        );
        _steward(d);
        StreamOwnerRecoveryNoticeTypes.Publication memory p = _publication(d);
        p.runbook = _ref(4, _url(2048));
        p.runbook.digest = new bytes(128);
        p.publicNotice = _ref(5, _url(2048));
        p.publicNotice.digest = new bytes(128);
        for (uint256 i; i < 2; ++i) {
            p.deliveries[i].evidence = _ref(4, _url(2048));
            p.deliveries[i].evidence.digest = new bytes(128);
        }
        require(
            abi.encode(p.runbook, p.publicNotice).length == 4800,
            "two maximum dynamic references include every ABI head/tail word"
        );
        require(
            abi.encode(p.deliveries[1]).length == 4672,
            "maximum endpoint plus reference includes complete outer tuple"
        );
        _coolPrepared();
        uint256 beforeGas = gasleft();
        bytes32 id = _begin(d, p, 160);
        emit PreparedGas("absolute-begin", beforeGas - gasleft(), 2);
        uint256 largest;
        for (uint256 i; i < 2; ++i) {
            _coolPrepared();
            beforeGas = gasleft();
            owner.prepareRecoveryNoticeDelivery(id, p.deliveries[i]);
            uint256 used = beforeGas - gasleft();
            if (used > largest) largest = used;
        }
        emit PreparedGas("absolute-delivery", largest, 2);
        require(largest < 5000000, "complete maximum claim is individually publishable");
        _coolPrepared();
        beforeGas = gasleft();
        owner.openPreparedRecoveryNotice(id, calls, request);
        emit PreparedGas("absolute-open", beforeGas - gasleft(), 2);
        (, bytes memory base) = owner.recoveryNoticeClaim(ID, 0);
        (, bytes memory delivery) = owner.recoveryNoticeClaim(ID, 2);
        require(
            base.length == 4800 && delivery.length == 4672
                && keccak256(base) == keccak256(abi.encode(p.runbook, p.publicNotice))
                && keccak256(delivery) == keccak256(abi.encode(p.deliveries[1])),
            "both complete original maximum chunks survive final opening"
        );
    }

    function testAuthenticatedPreparationRejectsDuplicateReorderedAndInactiveWitnessFields()
        public
    {
        StreamOwnerNoticeTypes.Designation memory original = _designation();
        _steward(original);
        StreamOwnerRecoveryNoticeTypes.Publication memory p = _publication(original);
        for (uint256 fault; fault < 6; ++fault) {
            StreamOwnerNoticeTypes.Designation memory d =
                abi.decode(abi.encode(original), (StreamOwnerNoticeTypes.Designation));
            if (fault == 0) {
                d.contactEndpoints[1] = d.contactEndpoints[0];
            } else if (fault == 1) {
                d.contactEndpoints[0] = original.contactEndpoints[1];
                d.contactEndpoints[1] = original.contactEndpoints[0];
            } else if (fault == 2) {
                d.contactEndpoints[0].chainId = 1;
            } else if (fault == 3) {
                d.contactEndpoints[0].account = address(1);
            } else if (fault == 4) {
                d.predecessor = keccak256("not the original predecessor");
            } else {
                d.kind = StreamOwnerNoticeTypes.StewardKind.REGISTRAR_CONTACT;
            }
            (bool ok,) = address(owner)
                .call(
                    abi.encodeCall(
                        owner.prepareRecoveryNotice,
                        (StreamOwnerPreparedNoticeTypes.Input(
                                7, ID, 170, d, p.runbook, p.publicNotice
                            ))
                    )
                );
            require(!ok, "complete canonical hash and closed inactive unions remain required");
        }
        bytes32 id = _begin(original, p, 170);
        _deliver(id, p);
        owner.openPreparedRecoveryNotice(id, calls, request);
    }

    function testAuthenticatedPreparationPreservesAllContactKindsAndExactEscapedMeaning() public {
        StreamOwnerNoticeTypes.Designation memory d = _designation();
        bytes32 prior = _steward(d);
        d.predecessor = prior;
        d.kind = StreamOwnerNoticeTypes.StewardKind.REGISTRAR_CONTACT;
        d.name = unicode"Exact \" \\ /\r\n\u0001 🎨 é";
        d.identity = _ref(5, "ar://opaque-identity");
        d.identity.digest = hex"00ff7f";
        d.contactEndpoints = new StreamOwnerNoticeTypes.Contact[](3);
        d.contactEndpoints[0] = StreamOwnerNoticeTypes.Contact(
            StreamOwnerNoticeTypes.ContactKind.EIP155, "", type(uint256).max, address(0xabcd)
        );
        d.contactEndpoints[1] = StreamOwnerNoticeTypes.Contact(
            StreamOwnerNoticeTypes.ContactKind.MAILTO, "mailto:a+b@c.example", 0, address(0)
        );
        d.contactEndpoints[2] = StreamOwnerNoticeTypes.Contact(
            StreamOwnerNoticeTypes.ContactKind.HTTPS, unicode"https://example/🎨", 0, address(0)
        );
        bytes32 hash = _steward(d);
        StreamOwnerRecoveryNoticeTypes.Publication memory p = _publication(d);
        bytes32 id = _begin(d, p, 171);
        _deliver(id, p);
        owner.openPreparedRecoveryNotice(id, calls, request);
        require(
            owner.recoveryNotice(ID).stewardRecordHash == hash
                && owner.recoveryNoticePreparation(id).stewardPayloadHash
                    == keccak256(StreamStewardDesignationJson.serialize(d)),
            "same complete existing serializer bytes, not a new normalization"
        );
    }

    function testAuthenticatedPreparationExact8192WithMaximumEscapedNameIsBounded() public {
        StreamOwnerNoticeTypes.Designation memory d = _designation();
        d.name = _text(512, 0x01);
        d.identity.uri = _url(2048);
        d.contactEndpoints[0] = StreamOwnerNoticeTypes.Contact(
            StreamOwnerNoticeTypes.ContactKind.HTTPS, _url(2048), 0, address(0)
        );
        d.contactEndpoints[1] = StreamOwnerNoticeTypes.Contact(
            StreamOwnerNoticeTypes.ContactKind.HTTPS, "https://a", 0, address(0)
        );
        uint256 n = StreamStewardDesignationJson.serialize(d).length;
        require(n < 8192 && 9 + 8192 - n <= 2048, "maximum escaped-name complete payload fixture");
        d.contactEndpoints[1].uri = string.concat("https://a", _text(8192 - n, 0x61));
        require(
            StreamStewardDesignationJson.serialize(d).length == 8192,
            "every original escaped byte included"
        );
        _steward(d);
        StreamOwnerRecoveryNoticeTypes.Publication memory p = _publication(d);
        _coolPrepared();
        uint256 beforeGas = gasleft();
        bytes32 id = _begin(d, p, 172);
        uint256 used = beforeGas - gasleft();
        emit PreparedGas("escaped-begin", used, 3);
        require(used < 16000000, "maximum escaped original fits bounded preparation");
        _deliver(id, p);
        owner.openPreparedRecoveryNotice(id, calls, request);
        require(
            owner.recoveryNotice(ID).stewardPayloadHash
                == keccak256(StreamStewardDesignationJson.serialize(d)),
            "complete original escaped meaning"
        );
    }

    function testProductionSizeAndAdditiveInterfacesAndSeparateGovernedIntentBudget() public view {
        require(address(owner).code.length <= 24576, "OwnerRecords production fits");
        require(
            owner.supportsInterface(type(IStreamOwnerRecords).interfaceId)
                && owner.supportsInterface(type(IStreamOwnerRecoveryNotices).interfaceId)
                && owner.supportsInterface(0x20279cd8) && !owner.supportsInterface(0xffffffff),
            "truthful additive capabilities"
        );
        (uint256 value, uint256 floor, uint8 failure, uint64 revision) =
            owner.gasParameterInfo(owner.RECOVERY_INTENT_READ_GAS());
        require(
            value == 8000000 && floor == 8000000 && failure == 2 && revision == 1,
            "dedicated governed intent row"
        );
        require(
            owner.gasParameter(owner.DEPENDENCY_READ_GAS()) == 150000, "existing knob unchanged"
        );
    }
}
