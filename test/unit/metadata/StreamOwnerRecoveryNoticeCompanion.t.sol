// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../../helpers/RecoveryOwnerNoticeCompositionFixture.sol";
import "../../../smart-contracts/domains/metadata/StreamOwnerRecords.sol";
import "../../../smart-contracts/domains/metadata/StreamSchemaRegistry.sol";

interface OwnerNoticeCompositionVm {
    function readFile(string calldata path) external view returns (string memory);
    function prank(address caller) external;
    function cool(address target) external;
    function expectRevert() external;
}

/// @notice Actual OwnerRecords/schema/store plus actual registered recovery companion and six-word read.
/// @dev Core/Executor/artist/Consent/original-finality remain explicit boundary fixtures.
contract StreamOwnerRecoveryNoticeCompanionTest is RecoveryCompanionBoundaryFixture {
    StreamOwnerRecords private owner;
    StreamSchemaRegistry private schemas;
    StreamSchemaDocumentStore private store;
    StreamArtworkFinalityRecovery private recovery;
    RecoveryOwnerNoticeCompositionFixture private fixture;
    StreamFinalityRecoveryRequest private request;
    GovernanceCall[] private calls;
    bytes32 private constant ACTION = keccak256("composed notice action");
    uint64 private constant END = 1000 + 72 hours;
    OwnerNoticeCompositionVm private constant cvm =
        OwnerNoticeCompositionVm(address(uint160(uint256(keccak256("hevm cheat code")))));

    function setUp() public override {
        super.setUp();
        vm.warp(1000);
        _erc(core, 0x80ac58cd);
        executor.answer(
            abi.encodeWithSignature("isStreamGovernedParameterAuthority()"), abi.encode(true)
        );
        executor.answer(abi.encodeWithSignature("currentAction()"), new bytes(192));
        core.answer(abi.encodeCall(IERC721.ownerOf, (23)), abi.encode(address(this)));
        core.answer(
            abi.encodeCall(IStreamCoreIdentity.tokenCollectionIdentity, (23)),
            abi.encode(true, uint256(7), uint256(1), false)
        );
        core.answer(abi.encodeCall(IStreamCoreIdentity.tokenLifecycle, (23)), abi.encode(uint8(2)));
        core.answer(
            abi.encodeCall(IStreamFinalityRecoveryCore.lastAllocatedTokenId, ()),
            abi.encode(uint256(23))
        );
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
            bytes(cvm.readFile("schemas/museum/account-profile/RFC8785_JCS.json"))
        );
        _register(
            "STREAM_RECOVERY_RESPONSE_V1",
            IStreamSchemaRegistry.DocumentKind.SCHEMA,
            bytes(cvm.readFile("schemas/records/STREAM_RECOVERY_RESPONSE_V1.json"))
        );
        _register(
            "STREAM_RECOVERY_RESPONSE_JSON_PROFILE_V1",
            IStreamSchemaRegistry.DocumentKind.CATALOG,
            bytes(cvm.readFile("schemas/records/STREAM_RECOVERY_RESPONSE_JSON_PROFILE_V1.json"))
        );
        StreamOwnerRecords.Configuration memory c;
        c.core = address(core);
        c.executor = address(executor);
        c.schemas = address(schemas);
        c.deploymentManifestHash = keccak256("deployment");
        c.manifestURI = "ipfs://owner";
        c.manifestHash = keccak256("owner-module");
        c.signatureGas = IStreamGasParameterHost.GasParameterConfig(
            "METADATA_ERC1271_VERIFY_GAS", 150000, 90000, 2
        );
        c.dependencyReadGas = IStreamGasParameterHost.GasParameterConfig(
            "METADATA_DEPENDENCY_READ_GAS", 150000, 100000, 2
        );
        owner = new StreamOwnerRecords(c);
        fixture = new RecoveryOwnerNoticeCompositionFixture();
        fixture.initialize(address(core), address(executor), address(roles), address(owner));
        recovery = fixture.recovery();
        request = fixture.requestFacts();
        _pointer(
            keccak256("MODULE_REGISTRY"),
            address(modules),
            keccak256("MODULE_REGISTRY"),
            0x11223344,
            address(modules).codehash
        );
        _pointer(RECOVERY, address(recovery), KIND, 0x83685f5c, address(recovery).codehash);
        _pointer(
            keccak256("ARTIST_REGISTRY"),
            fixture.artistTarget(),
            keccak256("ARTIST_REGISTRY"),
            type(IStreamArtistMintConsent).interfaceId,
            fixture.artistTarget().codehash
        );
        modules.answer(
            abi.encodeCall(
                IStreamModuleRegistry.isModuleEligible,
                (address(recovery), KIND, bytes4(0x83685f5c))
            ),
            abi.encode(true)
        );
        modules.answer(
            abi.encodeCall(
                IStreamModuleRegistry.isModuleEligible,
                (
                    fixture.artistTarget(),
                    keccak256("ARTIST_REGISTRY"),
                    type(IStreamArtistMintConsent).interfaceId
                )
            ),
            abi.encode(true)
        );
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
                recovery.finalityRecoveryScopeHash(request.scope),
                recovery.finalityRecoveryOldValueHash(request),
                recovery.finalityRecoveryNewValueHash(request)
            )
        );
        _action(1);
    }

    function _register(
        string memory name,
        IStreamSchemaRegistry.DocumentKind kind,
        bytes memory payload
    ) private {
        (bytes32 hash,) = store.publishChunk(payload);
        bytes32[] memory chunks = new bytes32[](1);
        chunks[0] = hash;
        IStreamSchemaRegistry.DocumentSpec memory d = IStreamSchemaRegistry.DocumentSpec(
            name, kind, hash, keccak256("RAW_BYTES"), 0, "", uint32(payload.length)
        );
        (bytes32 s, bytes32 o, bytes32 n) = schemas.registrationTransition(d, chunks);
        executor.answer(
            abi.encodeWithSignature("currentAction()"),
            abi.encode(true, keccak256(bytes(name)), uint8(1), s, o, n)
        );
        cvm.prank(address(executor));
        schemas.registerDocument(d, chunks);
        executor.answer(abi.encodeWithSignature("currentAction()"), new bytes(192));
    }

    function _action(uint8 status) private {
        bytes32 hash = keccak256(
            abi.encode(
                bytes32(0x10f09566fb70f7947b61639c2a53b3aec872069a8b46edd08ba14eb2b5942b70), calls
            )
        );
        executor.answer(
            abi.encodeCall(IStreamGovernanceActionFacts.governanceActionFacts, (ACTION)),
            abi.encode(uint256(status), uint256(2), hash, uint64(END), uint64(END + 7 days))
        );
    }

    function _open() private {
        StreamOwnerNoticeTypes.Designation memory d;
        StreamOwnerRecoveryNoticeTypes.Publication memory p;
        p.runbook = StreamOwnerNoticeTypes.Reference(
            2, keccak256("RAW_BYTES"), abi.encode(keccak256("runbook")), "ipfs://runbook"
        );
        p.publicNotice = StreamOwnerNoticeTypes.Reference(
            1, keccak256("RAW_BYTES"), abi.encode(keccak256("public notice")), "ipfs://public"
        );
        p.deliveries = new StreamOwnerRecoveryNoticeTypes.Delivery[](1);
        p.deliveries[0].endpoint = StreamOwnerNoticeTypes.Contact(
            StreamOwnerNoticeTypes.ContactKind.EIP155, "", block.chainid, address(this)
        );
        p.deliveries[0].evidence = p.publicNotice;
        owner.openRecoveryNotice(ACTION, calls, request, d, p);
    }

    function _respond(string memory grounds) private {
        StreamOwnerNoticeTypes.Response memory r;
        r.subjectId = owner.deriveOwnerSubject(23);
        r.profileHash = StreamOwnerNoticeDefinitions.RESPONSE_PROFILE_HASH;
        r.recoveryId = ACTION;
        r.recoveryManifestHash = request.recoveryManifest.contentHash;
        r.response = StreamOwnerNoticeTypes.ResponseClass.OBJECTED;
        r.grounds = grounds;
        bytes memory payload = StreamRecoveryResponseJson.serialize(r);
        IStreamOwnerRecords.OwnerRecord memory record = IStreamOwnerRecords.OwnerRecord(
            keccak256("RECOVERY_RESPONSE"),
            r.subjectId,
            StreamOwnerNoticeDefinitions.RESPONSE_SCHEMA_ID,
            IStreamPreservationRecords.HashRef(
                1, abi.encode(keccak256(payload)), StreamWorkRecordDefinitions.CANON_ID
            ),
            "ipfs://response",
            payload,
            1
        );
        owner.recordRecoveryResponse(23, record, r);
    }

    function _context() private {
        _action(3);
        executor.answer(
            abi.encodeWithSignature("currentAction()"),
            abi.encode(
                true,
                ACTION,
                uint8(2),
                calls[0].scopeHash,
                calls[0].oldValueHash,
                calls[0].newValueHash
            )
        );
    }

    function testActualCompanionConsumesCompleteOwnerNoticeAndPreservesExecutedSnapshot() public {
        _open();
        _respond("owning institution objects");
        owner.processRecoveryResponse(ACTION);
        vm.warp(END);
        StreamOwnerRecoveryNoticeTypes.Snapshot memory before_ = owner.recoveryNotice(ACTION);
        _context();
        cvm.cool(address(owner));
        cvm.cool(address(core));
        cvm.cool(address(executor));
        cvm.cool(address(recovery));
        cvm.cool(address(StreamOwnerRecoveryNoticeState));
        cvm.cool(address(StreamOwnerRecoveryActionReads));
        cvm.cool(address(StreamFinalityRecoveryOwnerReads));
        cvm.prank(address(executor));
        recovery.executeFinalityRecovery(request);
        StreamFinalityRecoveryRecord memory saved = recovery.finalityRecoveryRecord(ACTION);
        require(
            saved.executed && saved.evidence.ownerEvidenceHash == before_.evidenceHash
                && saved.evidence.ownerEvidenceRevision == before_.revision
                && saved.evidence.ownerObjectionCount == 1
                && saved.evidence.ownerNoticeEndsAt == END,
            "actual companion immutable evidence snapshot; objections never veto"
        );
        executor.answer(abi.encodeWithSignature("currentAction()"), new bytes(192));
        _respond("later historical record");
        require(
            recovery.finalityRecoveryRecord(ACTION).evidence.ownerEvidenceHash
                == before_.evidenceHash,
            "later documentation cannot rewrite executed snapshot"
        );
        (bool valid,,,,,) = owner.verifyRecoveryOwnerEvidence(
            request.scope, ACTION, request.recoveryManifest.contentHash
        );
        require(!valid, "no historical execution revival");
    }
    event OwnerCallbackGas(uint8 actionStatus, uint256 used, uint256 returnedBytes);

    function _coldOwnerCallback(uint8 status) private {
        bytes memory data = abi.encodeCall(
            IStreamFinalityRecoveryOwnerEvidence.verifyRecoveryOwnerEvidence,
            (request.scope, ACTION, request.recoveryManifest.contentHash)
        );
        StreamOwnerRecoveryNoticeTypes.Snapshot memory expected = owner.recoveryNotice(ACTION);
        cvm.cool(address(owner));
        cvm.cool(address(StreamOwnerRecoveryNoticeState));
        cvm.cool(address(StreamOwnerRecoveryActionReads));
        cvm.cool(address(core));
        cvm.cool(address(executor));
        cvm.cool(address(recovery));
        uint256 beforeGas = gasleft();
        (bool ok, bytes memory out) = address(owner).staticcall{ gas: 500000 }(data);
        uint256 used = beforeGas - gasleft();
        require(ok && out.length == 192, "cold actual companion graph callback fits fixed 500k cap");
        require(
            keccak256(out)
                == keccak256(
                    abi.encode(
                        true, expected.evidenceHash, expected.revision, END, uint32(0), uint32(1)
                    )
                ),
            "all six callback words independently match saved notice"
        );
        emit OwnerCallbackGas(status, used, out.length);
    }

    function testColdActualCompanionGraphOwnerCallbackFits500kScheduledAndExecuting() public {
        _open();
        _respond("cold bounded owner objection");
        owner.processRecoveryResponse(ACTION);
        vm.warp(END);
        _coldOwnerCallback(1);
        _context();
        _coldOwnerCallback(3);
    }

    function testActualCompanionRejectsPendingTailThenSameOriginalRequestRetries() public {
        _open();
        _respond("pending original");
        vm.warp(END);
        _context();
        cvm.prank(address(executor));
        cvm.expectRevert();
        recovery.executeFinalityRecovery(request);
        require(
            !recovery.finalityRecoveryRecord(ACTION).executed, "no partial recovery on stale count"
        );
        _action(1);
        executor.answer(abi.encodeWithSignature("currentAction()"), new bytes(192));
        owner.processRecoveryResponse(ACTION);
        _context();
        cvm.prank(address(executor));
        recovery.executeFinalityRecovery(request);
        require(
            recovery.finalityRecoveryRecord(ACTION).executed,
            "exact request retry after complete processing"
        );
    }

    function testActualCompanionRejectsChangedOriginalLineageDespiteLiveNotice() public {
        _open();
        vm.warp(END);
        fixture.changeOriginalRecord();
        (bool valid,,,,,) = owner.verifyRecoveryOwnerEvidence(
            request.scope, ACTION, request.recoveryManifest.contentHash
        );
        require(valid, "owner notice liveness deliberately omits original preparation");
        _context();
        cvm.prank(address(executor));
        cvm.expectRevert();
        recovery.executeFinalityRecovery(request);
        require(
            !recovery.finalityRecoveryRecord(ACTION).executed,
            "actual companion owns independent current lineage validation"
        );
    }

    function testPreparedNoticeActualCompanionAdmissionClockAndExecution() public {
        StreamOwnerNoticeTypes.Designation memory d;
        StreamOwnerNoticeTypes.Reference memory runbook = StreamOwnerNoticeTypes.Reference(
            2, keccak256("RAW_BYTES"), abi.encode(keccak256("runbook")), "ipfs://runbook"
        );
        StreamOwnerNoticeTypes.Reference memory notice = StreamOwnerNoticeTypes.Reference(
            5, keccak256("RAW_BYTES"), hex"010203", "ipfs://notice"
        );
        bytes32 id = owner.prepareRecoveryNotice(
            StreamOwnerPreparedNoticeTypes.Input(23, ACTION, 1, d, runbook, notice)
        );
        _respond("published during preparation");
        owner.prepareRecoveryNoticeDelivery(
            id,
            StreamOwnerRecoveryNoticeTypes.Delivery(
                StreamOwnerNoticeTypes.Contact(
                    StreamOwnerNoticeTypes.ContactKind.EIP155, "", block.chainid, address(this)
                ),
                notice
            )
        );
        cvm.cool(address(owner));
        cvm.cool(address(core));
        cvm.cool(address(executor));
        cvm.cool(address(recovery));
        cvm.cool(address(StreamOwnerRecoveryNoticeState));
        cvm.cool(address(StreamOwnerRecoveryNoticePreparation));
        cvm.cool(address(StreamOwnerRecoveryActionReads));
        owner.openPreparedRecoveryNotice(id, calls, request);
        require(
            owner.recoveryNotice(ACTION).responseTail == 1
                && owner.recoveryNotice(ACTION).firstResponseIndex == 1,
            "actual final queue capture"
        );
        owner.processRecoveryResponse(ACTION);
        vm.warp(END);
        _coldOwnerCallback(1);
        _context();
        _coldOwnerCallback(3);
        cvm.prank(address(executor));
        recovery.executeFinalityRecovery(request);
        StreamFinalityRecoveryRecord memory saved = recovery.finalityRecoveryRecord(ACTION);
        require(
            saved.executed
                && saved.evidence.ownerEvidenceHash == owner.recoveryNotice(ACTION).evidenceHash
                && saved.evidence.ownerObjectionCount == 1,
            "actual companion accepts same immutable evidence contract"
        );
    }

    event PreparedActualMaximumGas(uint256 used, uint256 requestBytes);

    function testPreparedMaximumOriginalRequestAdmitsThroughActualCompanionWithinDedicatedCap()
        public
    {
        StreamFinalityRecoveryRequest memory r = request;
        uint256 fixedBytes = abi.encode(r).length - ((bytes(r.reasonURI).length + 31) / 32) * 32;
        bytes memory reason = new bytes(24544 - fixedBytes);
        for (uint256 i; i < reason.length; ++i) {
            reason[i] = 0x61;
        }
        r.reasonURI = string(reason);
        require(abi.encode(r).length == 24544, "complete maximum word-aligned original request");
        r.recoveryManifest.contentHash =
            recovery.stageFinalityRecoveryManifest(recovery.finalityRecoveryIntentBytes(r));
        recovery.registerFinalityRecoveryIntent(r);
        request = r;
        calls[0].callDataHash =
            keccak256(abi.encodeCall(IStreamArtworkFinalityRecovery.executeFinalityRecovery, (r)));
        calls[0].newValueHash = recovery.finalityRecoveryNewValueHash(r);
        _action(1);
        StreamOwnerNoticeTypes.Designation memory d;
        StreamOwnerNoticeTypes.Reference memory reference_ = StreamOwnerNoticeTypes.Reference(
            2, keccak256("RAW_BYTES"), abi.encode(keccak256("publication")), "ipfs://publication"
        );
        bytes32 id = owner.prepareRecoveryNotice(
            StreamOwnerPreparedNoticeTypes.Input(23, ACTION, 3, d, reference_, reference_)
        );
        owner.prepareRecoveryNoticeDelivery(
            id,
            StreamOwnerRecoveryNoticeTypes.Delivery(
                StreamOwnerNoticeTypes.Contact(
                    StreamOwnerNoticeTypes.ContactKind.EIP155, "", block.chainid, address(this)
                ),
                reference_
            )
        );
        cvm.cool(address(owner));
        cvm.cool(address(core));
        cvm.cool(address(executor));
        cvm.cool(address(recovery));
        cvm.cool(address(modules));
        cvm.cool(fixture.artistTarget());
        cvm.cool(address(fixture.history()));
        cvm.cool(r.replacementRoute.component);
        cvm.cool(address(StreamOwnerRecoveryNoticeState));
        cvm.cool(address(StreamOwnerRecoveryNoticePreparation));
        cvm.cool(address(StreamOwnerRecoveryActionReads));
        uint256 beforeGas = gasleft();
        owner.openPreparedRecoveryNotice(id, calls, r);
        uint256 used = beforeGas - gasleft();
        emit PreparedActualMaximumGas(used, abi.encode(r).length);
        require(
            used < 12000000
                && owner.recoveryNotice(ACTION).binding.requestHash == keccak256(abi.encode(r)),
            "all exact original request bytes under dedicated admission cap"
        );
        vm.warp(END);
        (bool valid,,,,,) =
            owner.verifyRecoveryOwnerEvidence(r.scope, ACTION, r.recoveryManifest.contentHash);
        require(valid, "maximum request does not make the lightweight owner callback recurse");
    }
}
