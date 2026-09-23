// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../../helpers/MintEngineTestBase.sol";
import "../../../smart-contracts/domains/mint/StreamMintTicketGate.sol";
import "../../../smart-contracts/interfaces/stream/mint/IStreamMintPolicyGrace.sol";
import "../../../script/current/StreamCurrentStackPlan.sol";

/// @dev Deliberate Artist read boundary: production Artist/Safe joins belong to current-stack tests.
contract MintGraceArtistBoundary {
    address public immutable core;
    address public immutable mintManager;
    bool public consented = true;

    constructor(address c, address m) {
        core = c;
        mintManager = m;
    }

    function setConsented(bool value) external {
        consented = value;
    }

    function consentMode(uint256) external pure returns (uint8) {
        return 1;
    }

    function isPolicyConsented(uint256, bytes32, bytes32) external view returns (bool, bytes32) {
        return (consented, consented ? keccak256("explicit grace fixture consent") : bytes32(0));
    }

    function requireMintConsent(uint256, bytes32, bytes32) external view {
        require(consented, "artist boundary denies current policy");
    }
}

/// @dev Separate Ledger-only boundary for initial-registration validation, never the main producer.
contract MintGraceInitialWriter {
    function register(StreamMintLedger target, uint64 until) external {
        target.registerPhasePolicy(
            address(this),
            1,
            keccak256("initial phase"),
            keccak256("initial policy"),
            new bytes32[](0),
            new IStreamMintLedger.LedgerCounterPolicy[](0),
            until
        );
    }
}

/// @dev Actual Manager, Ledger, Registry and signed ticket gate. Core/Artist/governance are explicit
/// typed boundaries. Every production-policy rotation goes through the owner-authorized Manager;
/// no prank as Manager or storage write manufactures a grace tuple.
contract StreamMintPolicyGraceTest is MintEngineTestBase {
    bytes32 private constant COUNTER = keccak256("grace lifetime counter");
    bytes32 private constant COUNTER_CONFIG = keccak256("grace fixed cap");
    address private constant EXTRA = address(0xE100);
    address private constant THIRD = address(0xE200);
    address private constant RECIPIENT = address(0xCAFE);
    uint64 private constant CAP = 20;
    StreamMintTicketGate private ticketGate;
    MintGraceArtistBoundary private graceArtist;

    struct SignedRequest {
        IStreamMintManager.MintBatch batch;
        bytes data;
        bytes32 digest;
    }

    function setUp() public override {
        super.setUp();
        graceArtist = new MintGraceArtistBoundary(address(core), address(manager));
        core.initialize(address(registry), address(graceArtist), address(manager));
        ticketGate = new StreamMintTicketGate(address(authority), signer, 1);
        _admitGate();
        bytes32[] memory ids = new bytes32[](1);
        ids[0] = COUNTER;
        IStreamMintManager.MintCounterConfig[] memory counters =
            new IStreamMintManager.MintCounterConfig[](1);
        counters[0] = IStreamMintManager.MintCounterConfig(
            true,
            IStreamMintManager.CounterKeyMode.CONSTANT,
            IStreamMintLedger.CounterCapMode.STATIC,
            IStreamMintLedger.CounterDeltaMode.STATIC,
            CAP,
            1,
            COUNTER_CONFIG
        );
        manager.configurePhase(
            1,
            PHASE,
            IStreamMintManager.MintPhaseConfig(false, 0, 0, 1, keccak256("grace terms"), 0),
            IStreamMintManager.MintGateConfig(
                address(ticketGate),
                ticketGate.gateConfigHash(),
                address(ticketGate).codehash,
                0,
                0,
                600_000
            ),
            ids,
            counters
        );
        manager.setPhaseExecutor(1, PHASE, address(this), true);
    }

    function _admitGate() private {
        StreamModuleRegistration[] memory records = new StreamModuleRegistration[](1);
        records[0] = StreamModuleRegistration(
            address(ticketGate),
            keccak256("6529STREAM_MINT_GATE_V1"),
            keccak256("grace ticket v1"),
            type(IStreamMintGate).interfaceId,
            600_000,
            address(ticketGate).codehash,
            keccak256("grace deployment"),
            keccak256("grace gate manifest"),
            "urn:grace:gate"
        );
        (GovernanceCall[] memory calls,) =
            StreamCurrentStackPlan.registrationCalls(registry, records);
        authority.setCurrentAction(
            true,
            keccak256("typed gate admission"),
            1,
            calls[0].scopeHash,
            calls[0].oldValueHash,
            calls[0].newValueHash
        );
        vm.prank(address(authority));
        registry.registerModule(records[0]);
        authority.setCurrentAction(false, 0, 0, 0, 0, 0);
    }

    function _request(uint256 nonce) private returns (SignedRequest memory q) {
        q.batch = _batch(0);
        q.batch.authorizer = signer;
        q.batch.initialRecipients[0] = RECIPIENT;
        q.batch.contextHash = keccak256("original signed grace context");
        StreamMintTicketTypes.MintTicket memory t = _ticket(nonce);
        t.initialRecipientsHash = keccak256(
            abi.encode(keccak256("6529STREAM_MINT_BATCH_RECIPIENTS_V1"), q.batch.initialRecipients)
        );
        t.beneficiariesHash = keccak256(
            abi.encode(keccak256("6529STREAM_MINT_BATCH_BENEFICIARIES_V1"), q.batch.beneficiaries)
        );
        t.tokenDataArrayHash = keccak256(
            abi.encode(keccak256("6529STREAM_MINT_BATCH_TOKEN_DATA_V1"), q.batch.tokenData)
        );
        t.mintCommitmentsHash = keccak256(
            abi.encode(keccak256("6529STREAM_MINT_BATCH_COMMITMENTS_V1"), q.batch.mintCommitments)
        );
        t.contextHash = q.batch.contextHash;
        t.deadline = uint64(block.timestamp + 90 days);
        q.digest = StreamMintTicketHash.digest(block.chainid, address(ticketGate), t);
        q.batch.authorizationId = StreamMintTicketHash.authorizationId(q.digest);
        q.data = abi.encode(t, _signature(SIGNER_KEY, q.digest));
    }

    function _rotate(address who, bool allowed, uint64 until) private returns (bytes32) {
        manager.setPhaseExecutorWithGrace(1, PHASE, who, allowed, until);
        return manager.phasePolicyHash(1, PHASE);
    }

    function _grace() private view returns (bytes32 hash, uint64 revision, uint64 until) {
        return ledger.policyGrace(address(manager), 1, PHASE);
    }

    function _subject() private view returns (bytes32) {
        return keccak256(
            abi.encode(
                keccak256("6529STREAM_MINT_COUNTER_SUBJECT_V1"),
                block.chainid,
                address(ledger),
                IStreamMintManager.CounterKeyMode.CONSTANT,
                uint256(1),
                PHASE,
                COUNTER
            )
        );
    }

    function _key() private view returns (bytes32) {
        return keccak256(
            abi.encode(
                keccak256("6529STREAM_MINT_COUNTER_VALUE_KEY_V1"),
                address(manager),
                uint256(1),
                PHASE,
                COUNTER,
                _subject()
            )
        );
    }

    function _resolution(SignedRequest memory q) private view returns (bytes32) {
        return keccak256(
            abi.encode(
                keccak256("6529STREAM_MINT_COUNTER_RESOLUTION_V1"),
                block.chainid,
                address(manager),
                address(ledger),
                q.batch.collectionId,
                q.batch.phaseId,
                COUNTER,
                _subject(),
                uint256(0),
                COUNTER_CONFIG
            )
        );
    }

    /// @dev Independently reconstruct the original root; do not call production derive/preview.
    function _expectedRoot(SignedRequest memory q) private view returns (bytes32 root, bytes32 id) {
        IStreamMintLedger.CounterConsumption[] memory cs =
            new IStreamMintLedger.CounterConsumption[](1);
        cs[0] = IStreamMintLedger.CounterConsumption(
            _key(),
            1,
            PHASE,
            COUNTER,
            _subject(),
            q.batch.payer,
            signer,
            signer,
            address(this),
            1,
            CAP,
            q.batch.contextHash,
            _resolution(q)
        );
        bytes32 validated = keccak256(
            abi.encode(
                keccak256("6529STREAM_MINT_VALIDATED_RESULT_V1"),
                address(ticketGate),
                q.batch.authorizationId,
                keccak256(abi.encode(keccak256("6529STREAM_MINT_NULLIFIERS_V1"), new bytes32[](0))),
                signer,
                uint8(1),
                uint64(1),
                q.digest,
                keccak256(abi.encode(keccak256("6529STREAM_MINT_COUNTER_CONSUMPTIONS_V1"), cs))
            )
        );
        bytes32 request = keccak256(
            abi.encode(
                keccak256("6529STREAM_MINT_REQUEST_COMMITMENT_V1"),
                q.batch.payer,
                q.batch.authorizer,
                q.batch.expectedPolicyHash,
                keccak256(
                    abi.encode(
                        keccak256("6529STREAM_MINT_BATCH_RECIPIENTS_V1"), q.batch.initialRecipients
                    )
                ),
                keccak256(
                    abi.encode(
                        keccak256("6529STREAM_MINT_BATCH_BENEFICIARIES_V1"), q.batch.beneficiaries
                    )
                ),
                keccak256(
                    abi.encode(keccak256("6529STREAM_MINT_BATCH_TOKEN_DATA_V1"), q.batch.tokenData)
                ),
                keccak256(
                    abi.encode(
                        keccak256("6529STREAM_MINT_BATCH_COMMITMENTS_V1"), q.batch.mintCommitments
                    )
                ),
                validated
            )
        );
        StreamMintOperationIdentity.OperationRootPreimage memory p;
        p.chainId = block.chainid;
        p.manager = address(manager);
        p.coreAddress = address(core);
        p.ledgerAddress = address(ledger);
        p.executionPath = keccak256("6529STREAM_MINT_EXECUTION_PATH_SINGLE_STEP_V1");
        p.collectionId = 1;
        p.phaseId = PHASE;
        p.currentPolicyHash = manager.phasePolicyHash(1, PHASE);
        p.boundPolicyHash = q.batch.expectedPolicyHash;
        p.authorizationId = q.batch.authorizationId;
        p.requestCommitmentHash = request;
        p.contextHash = q.batch.contextHash;
        p.executor = address(this);
        p.firstOperationNonce = manager.nextOperationNonce();
        p.quantity = 1;
        root = keccak256(abi.encode(keccak256("6529STREAM_MINT_OPERATION_ROOT_V1"), p));
        id = keccak256(
            abi.encode(
                keccak256("6529STREAM_MINT_TOKEN_OPERATION_ID_V1"),
                root,
                p.firstOperationNonce,
                uint256(0),
                keccak256(q.batch.tokenData[0]),
                q.batch.mintCommitments[0]
            )
        );
    }

    function _mint(SignedRequest memory q) private returns (bytes32 root) {
        bytes32 expectedId;
        (root, expectedId) = _expectedRoot(q);
        uint256 beforeNonce = manager.nextOperationNonce();
        uint256 beforeMinted = core.minted();
        uint64 beforeCount = ledger.counterValue(_key());
        (uint256[] memory tokens, bytes32 actual, bytes32[] memory ids) =
            manager.executeSingleStepMint(q.batch, q.data);
        require(
            actual == root && ids.length == 1 && ids[0] == expectedId, "exact root and operation"
        );
        require(tokens.length == 1 && tokens[0] == beforeMinted + 1, "exact token");
        require(core.minted() == beforeMinted + 1, "one Core allocation");
        require(MintEngineCoreFixture(address(core)).ownerOf(tokens[0]) == RECIPIENT, "delivery");
        require(manager.nextOperationNonce() == beforeNonce + 1, "one operation nonce");
        require(ledger.counterValue(_key()) == beforeCount + 1, "same durable counter");
        require(manager.isAuthorizationUsed(q.batch.authorizationId), "Manager replay read");
        require(
            ledger.isManagerAuthorizationUsed(address(manager), q.batch.authorizationId),
            "Ledger authorization"
        );
        require(ledger.isManagerOperationRootUsed(address(manager), root), "Ledger root");
    }

    function _assertUnused(SignedRequest memory q) private view {
        require(!manager.isAuthorizationUsed(q.batch.authorizationId), "authorization untouched");
        (bytes32 root,) = _expectedRoot(q);
        require(!ledger.isManagerOperationRootUsed(address(manager), root), "root untouched");
    }

    function _expectPolicyFailure(SignedRequest memory q) private {
        uint256 beforeNonce = manager.nextOperationNonce();
        uint256 beforeMinted = core.minted();
        uint64 beforeCount = ledger.counterValue(_key());
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamMintManager.MintPolicyHashMismatch.selector,
                q.batch.expectedPolicyHash,
                manager.phasePolicyHash(1, PHASE)
            )
        );
        manager.executeSingleStepMint(q.batch, q.data);
        _assertUnused(q);
        require(
            manager.nextOperationNonce() == beforeNonce && core.minted() == beforeMinted,
            "failed mint unchanged"
        );
        require(ledger.counterValue(_key()) == beforeCount, "failed counter unchanged");
        vm.expectRevert(
            abi.encodeWithSelector(
                StreamMintTicketGate.MintTicketPolicyMismatch.selector, q.batch.expectedPolicyHash
            )
        );
        ticketGate.validateMintBatch(address(manager), address(this), q.batch, q.data);
    }

    function _receipt(
        Vm.Log[] memory logs,
        address emitter,
        bytes32 signature,
        bytes32 first,
        bytes32 second,
        bytes32 third,
        bytes memory data
    ) private pure {
        uint256 matches;
        for (uint256 i; i < logs.length; ++i) {
            Vm.Log memory entry = logs[i];
            if (
                entry.emitter != emitter || entry.topics.length == 0 || entry.topics[0] != signature
            ) continue;
            require(entry.topics.length == 4, "exact indexed receipt shape");
            require(
                entry.topics[1] == first && entry.topics[2] == second && entry.topics[3] == third,
                "exact receipt topics"
            );
            require(keccak256(entry.data) == keccak256(data), "exact full receipt data");
            ++matches;
        }
        require(matches == 1, "exactly one receipt");
    }

    function testProductionGracePreservesOriginalTicketAndExactBoundReceipts() public {
        SignedRequest memory q = _request(1);
        bytes32 oldHash = q.batch.expectedPolicyHash;
        uint64 until = uint64(block.timestamp + 1 days);
        vm.recordLogs();
        bytes32 current = _rotate(EXTRA, true, until);
        Vm.Log[] memory registrationLogs = vm.getRecordedLogs();
        _receipt(
            registrationLogs,
            address(ledger),
            keccak256(
                "MintLedgerPolicyGraceSet(uint16,uint256,bytes32,address,bytes32,bytes32,uint64)"
            ),
            bytes32(uint256(1)),
            PHASE,
            bytes32(uint256(uint160(address(manager)))),
            abi.encode(uint16(1), oldHash, current, until)
        );
        _receipt(
            registrationLogs,
            address(manager),
            keccak256("MintPhaseExecutorUpdated(uint256,bytes32,address,bool,bytes32,address)"),
            bytes32(uint256(1)),
            PHASE,
            bytes32(uint256(uint160(EXTRA))),
            abi.encode(true, current, address(this))
        );
        (bytes32 previous, uint64 revision, uint64 deadline) = _grace();
        require(
            previous == oldHash && revision == 2 && deadline == until,
            "real second policy predecessor"
        );
        (, bytes32 operationId) = _expectedRoot(q);
        vm.recordLogs();
        bytes32 root = _mint(q);
        Vm.Log[] memory logs = vm.getRecordedLogs();
        _receipt(
            logs,
            address(ledger),
            keccak256(
                "MintLedgerOperationRootConsumed(uint16,bytes32,address,bytes32,bytes32,bytes32)"
            ),
            root,
            bytes32(uint256(uint160(address(manager)))),
            oldHash,
            abi.encode(uint16(1), current, q.batch.authorizationId)
        );
        _receipt(
            logs,
            address(ledger),
            keccak256("MintLedgerAuthorizationConsumed(uint16,bytes32,bytes32,address,bytes32)"),
            q.batch.authorizationId,
            root,
            bytes32(uint256(uint160(address(manager)))),
            abi.encode(uint16(1), oldHash)
        );
        _receipt(
            logs,
            address(ledger),
            keccak256(
                "MintLedgerCounterConsumed(uint16,bytes32,uint256,bytes32,address,bytes32,bytes32,uint64,uint64,uint64,bytes32,bytes32)"
            ),
            _key(),
            bytes32(uint256(1)),
            PHASE,
            abi.encode(
                uint16(1),
                address(manager),
                COUNTER,
                _subject(),
                uint64(1),
                uint64(1),
                CAP,
                oldHash,
                root
            )
        );
        _receipt(
            logs,
            address(ledger),
            keccak256(
                "MintLedgerCounterConsumptionContext(uint16,bytes32,bytes32,bytes32,address,address,address,address,address,bytes32,bytes32)"
            ),
            _key(),
            COUNTER,
            _subject(),
            abi.encode(
                uint16(1),
                address(manager),
                signer,
                signer,
                signer,
                address(this),
                q.batch.contextHash,
                _resolution(q)
            )
        );
        _receipt(
            logs,
            address(manager),
            keccak256(
                "MintBatchExecuted(uint16,bytes32,uint256,bytes32,address,address,address,uint256,uint256,bytes32,bytes32,bytes32,bytes32)"
            ),
            root,
            bytes32(uint256(1)),
            PHASE,
            abi.encode(
                uint16(1),
                address(this),
                signer,
                signer,
                uint256(1),
                uint256(1),
                q.batch.contextHash,
                q.digest,
                current,
                oldHash
            )
        );
        _receipt(
            logs,
            address(manager),
            keccak256("MintAuthorizationConsumed(uint16,uint256,bytes32,bytes32,bytes32,bytes32)"),
            bytes32(uint256(1)),
            PHASE,
            q.batch.authorizationId,
            abi.encode(uint16(1), oldHash, root)
        );
        _receipt(
            logs,
            address(manager),
            keccak256(
                "MintGateValidated(uint256,bytes32,address,bytes32,address,uint256,bytes32,bytes32,bytes32)"
            ),
            bytes32(uint256(1)),
            PHASE,
            bytes32(uint256(uint160(address(ticketGate)))),
            abi.encode(
                q.batch.authorizationId, signer, uint256(1), q.batch.contextHash, q.digest, oldHash
            )
        );
        _receipt(
            logs,
            address(manager),
            keccak256(
                "MintTokenExecuted(uint16,bytes32,uint256,bytes32,uint256,bytes32,uint256,address,address,bytes32,bytes32)"
            ),
            operationId,
            bytes32(uint256(1)),
            root,
            abi.encode(
                uint16(1),
                uint256(1),
                PHASE,
                uint256(0),
                RECIPIENT,
                signer,
                keccak256(q.batch.tokenData[0]),
                q.batch.mintCommitments[0]
            )
        );
        require(logs.length == 8, "eight exact committed production receipts");
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamMintLedger.AuthorizationAlreadyConsumed.selector, q.batch.authorizationId
            )
        );
        manager.executeSingleStepMint(q.batch, q.data);
        require(
            core.minted() == 1 && ledger.counterValue(_key()) == 1
                && manager.nextOperationNonce() == 1,
            "replay cannot mint or reset"
        );
    }

    function testDeadlineInclusiveThenOldTicketFailsWhileCurrentRemainsValid() public {
        SignedRequest memory atDeadline = _request(1);
        SignedRequest memory afterDeadline = _request(2);
        uint64 until = uint64(block.timestamp + 100);
        _rotate(EXTRA, true, until);
        vm.warp(until);
        _mint(atDeadline);
        vm.warp(uint256(until) + 1);
        _expectPolicyFailure(afterDeadline);
        _mint(_request(3));
    }

    function testThirdDistinctPolicyOverwritesOlderLivePredecessor() public {
        SignedRequest memory a = _request(1);
        _rotate(EXTRA, true, uint64(block.timestamp + 100));
        SignedRequest memory b = _request(2);
        bytes32 c = _rotate(THIRD, true, uint64(block.timestamp + 200));
        (bytes32 previous, uint64 revision, uint64 until) = _grace();
        require(
            c != a.batch.expectedPolicyHash && previous == b.batch.expectedPolicyHash
                && revision == 3,
            "distinct third policy"
        );
        require(until == block.timestamp + 200, "only newest window");
        _expectPolicyFailure(a);
        _mint(b);
    }

    function testOriginalSetterClearsGraceOnRealPolicyChange() public {
        SignedRequest memory a = _request(1);
        _rotate(EXTRA, true, uint64(block.timestamp + 100));
        SignedRequest memory b = _request(2);
        manager.setPhaseExecutor(1, PHASE, THIRD, true);
        (bytes32 previous, uint64 revision, uint64 until) = _grace();
        require(previous == 0 && revision == 0 && until == 0, "original API clears grace");
        _expectPolicyFailure(a);
        _expectPolicyFailure(b);
        _mint(_request(3));
    }

    function testUnchangedExecutorCannotExtendGraceAndZeroNoOpPreservesIt() public {
        SignedRequest memory a = _request(1);
        uint64 until = uint64(block.timestamp + 100);
        bytes32 current = _rotate(EXTRA, true, until);
        (bytes32 previous, uint64 revision,) = _grace();
        vm.expectRevert(
            abi.encodeWithSelector(IStreamMintLedger.InvalidPolicyGrace.selector, until + 1)
        );
        manager.setPhaseExecutorWithGrace(1, PHASE, EXTRA, true, until + 1);
        vm.expectRevert(
            abi.encodeWithSelector(IStreamMintLedger.InvalidPolicyGrace.selector, until)
        );
        manager.setPhaseExecutorWithGrace(1, PHASE, THIRD, false, until);
        vm.recordLogs();
        manager.setPhaseExecutorWithGrace(1, PHASE, EXTRA, true, 0);
        manager.setPhaseExecutorWithGrace(1, PHASE, THIRD, false, 0);
        manager.setPhaseExecutor(1, PHASE, EXTRA, true);
        require(vm.getRecordedLogs().length == 0, "no-op does not register or emit");
        (bytes32 afterHash, uint64 afterRevision, uint64 afterUntil) = _grace();
        require(
            afterHash == previous && afterRevision == revision && afterUntil == until,
            "no-op preserves grace exactly"
        );
        require(
            manager.phasePolicyHash(1, PHASE) == current && manager.nextOperationNonce() == 0,
            "no policy or nonce movement"
        );
        _mint(a);
        _rotate(THIRD, true, until);
        (, uint64 nextRevision,) = _grace();
        require(nextRevision == revision + 1, "no hidden revision movement");
    }

    function testBeyondThirtyDaysRollsBackExecutorPolicyAndCounterThenBoundarySucceeds() public {
        bytes32 beforeHash = manager.phasePolicyHash(1, PHASE);
        uint64 tooLate = uint64(block.timestamp + 30 days + 1);
        vm.expectRevert(
            abi.encodeWithSelector(IStreamMintLedger.InvalidPolicyGrace.selector, tooLate)
        );
        manager.setPhaseExecutorWithGrace(1, PHASE, EXTRA, true, tooLate);
        require(!manager.phaseExecutor(1, PHASE, EXTRA), "executor write rolled back");
        require(
            manager.phasePolicyHash(1, PHASE) == beforeHash
                && ledger.registeredPhasePolicyHash(address(manager), 1, PHASE) == beforeHash,
            "policy writes rolled back"
        );
        (bytes32 previous, uint64 revision, uint64 until) = _grace();
        require(
            previous == 0 && revision == 0 && until == 0 && ledger.counterValue(_key()) == 0,
            "no grace or count residue"
        );
        _rotate(EXTRA, true, uint64(block.timestamp + 30 days));
        (previous, revision, until) = _grace();
        require(
            previous == beforeHash && revision == 2 && until == block.timestamp + 30 days,
            "inclusive thirty day bound"
        );
    }

    function testPastDeadlineRegistersExpiredGraceWithoutInventingLowerBound() public {
        SignedRequest memory a = _request(1);
        _rotate(EXTRA, true, uint64(block.timestamp - 1));
        (bytes32 previous,, uint64 until) = _grace();
        require(
            previous == a.batch.expectedPolicyHash && until == block.timestamp - 1,
            "expired tuple recorded"
        );
        _expectPolicyFailure(a);
        _mint(_request(2));
    }

    function testCurrentTimestampDeadlineAllowsOnlyCurrentBlockPredecessor() public {
        SignedRequest memory a = _request(1);
        SignedRequest memory b = _request(2);
        _rotate(EXTRA, true, uint64(block.timestamp));
        _mint(a);
        vm.warp(block.timestamp + 1);
        _expectPolicyFailure(b);
    }

    function testOnlyOwnerMayRotatePolicyWithGrace() public {
        bytes32 beforeHash = manager.phasePolicyHash(1, PHASE);
        vm.expectRevert(
            abi.encodeWithSignature("Error(string)", "Ownable: caller is not the owner")
        );
        vm.prank(EXTRA);
        manager.setPhaseExecutorWithGrace(1, PHASE, EXTRA, true, uint64(block.timestamp + 100));
        require(
            !manager.phaseExecutor(1, PHASE, EXTRA)
                && manager.phasePolicyHash(1, PHASE) == beforeHash,
            "unauthorized no mutation"
        );
    }

    function testRemovedExecutorDeniedImmediatelyEvenWhenItsTicketHashHasGrace() public {
        SignedRequest memory a = _request(1);
        _rotate(address(this), false, uint64(block.timestamp + 100));
        (bytes32 previous,,) = _grace();
        require(previous == a.batch.expectedPolicyHash, "old hash genuinely retained");
        // The gate recognizes the original ticket; live Manager executor admission still wins.
        ticketGate.validateMintBatch(address(manager), address(this), a.batch, a.data);
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamMintManager.UnauthorizedMintExecutor.selector,
                uint256(1),
                PHASE,
                address(this)
            )
        );
        manager.executeSingleStepMint(a.batch, a.data);
        _assertUnused(a);
        require(
            core.minted() == 0 && ledger.counterValue(_key()) == 0
                && manager.nextOperationNonce() == 0,
            "no execution under removed executor"
        );
    }

    function testReturningToSamePolicyReacceptsUnusedTicketButNeverConsumedReplay() public {
        SignedRequest memory consumed = _request(1);
        SignedRequest memory unused = _request(2);
        bytes32 a = consumed.batch.expectedPolicyHash;
        _mint(consumed);
        manager.setPhaseExecutor(1, PHASE, EXTRA, true);
        _expectPolicyFailure(unused);
        manager.setPhaseExecutor(1, PHASE, EXTRA, false);
        require(manager.phasePolicyHash(1, PHASE) == a, "documented deterministic ABA");
        _mint(unused);
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamMintLedger.AuthorizationAlreadyConsumed.selector,
                consumed.batch.authorizationId
            )
        );
        manager.executeSingleStepMint(consumed.batch, consumed.data);
        require(
            core.minted() == 2 && ledger.counterValue(_key()) == 2
                && manager.nextOperationNonce() == 2,
            "replay remains durable across ABA"
        );
    }

    function testMissingArtistConsentRollsBackRotationThenExactOwnerCallCanRetry() public {
        bytes32 beforeHash = manager.phasePolicyHash(1, PHASE);
        uint64 until = uint64(block.timestamp + 100);
        graceArtist.setConsented(false);
        vm.expectRevert();
        manager.setPhaseExecutorWithGrace(1, PHASE, EXTRA, true, until);
        require(
            !manager.phaseExecutor(1, PHASE, EXTRA)
                && manager.phasePolicyHash(1, PHASE) == beforeHash,
            "consent failure restores executor and Manager policy"
        );
        require(
            ledger.registeredPhasePolicyHash(address(manager), 1, PHASE) == beforeHash,
            "consent failure preserves Ledger policy"
        );
        graceArtist.setConsented(true);
        _rotate(EXTRA, true, until);
        (bytes32 previous, uint64 revision, uint64 actualUntil) = _grace();
        require(
            previous == beforeHash && revision == 2 && actualUntil == until,
            "exact original rotation retries"
        );
    }

    function testGraceNeverBypassesCurrentArtistAuthorityAndOriginalTicketRetries() public {
        SignedRequest memory q = _request(1);
        uint64 deadline = uint64(block.timestamp + 100);
        _rotate(EXTRA, true, deadline);
        (bytes32 root,) = _expectedRoot(q);
        bytes32 signedBytes = keccak256(q.data);
        // The gate still recognizes the old signature and live predecessor policy.
        ticketGate.validateMintBatch(address(manager), address(this), q.batch, q.data);
        graceArtist.setConsented(false);
        vm.expectRevert(
            abi.encodeWithSelector(
                StreamMintArtistConsent.ArtistAuthorityReadFailed.selector,
                address(graceArtist),
                IStreamArtistMintConsent.requireMintConsent.selector
            )
        );
        manager.executeSingleStepMint(q.batch, q.data);
        _assertUnused(q);
        require(
            core.minted() == 0 && manager.nextOperationNonce() == 0
                && ledger.counterValue(_key()) == 0,
            "withdrawn current Artist authority prevents grace execution"
        );
        (bytes32 previous, uint64 revision, uint64 until) = _grace();
        require(
            previous == q.batch.expectedPolicyHash && revision == 2 && until == deadline,
            "runtime authority failure leaves registered grace intact"
        );
        graceArtist.setConsented(true);
        require(
            _mint(q) == root && keccak256(q.data) == signedBytes,
            "restored authority accepts the exact original signed ticket"
        );
    }

    function testLateTypedCoreFailureRollsBackOldTicketAndIdenticalSignatureRetries() public {
        SignedRequest memory q = _request(1);
        _rotate(EXTRA, true, uint64(block.timestamp + 100));
        bytes32 signedBytes = keccak256(q.data);
        (bytes32 root,) = _expectedRoot(q);
        MintEngineCoreFixture(address(core)).setRejectMint(true);
        vm.expectRevert(abi.encodeWithSignature("Error(string)", "core mint admission"));
        manager.executeSingleStepMint(q.batch, q.data);
        require(
            core.minted() == 0 && manager.nextOperationNonce() == 0
                && ledger.counterValue(_key()) == 0,
            "late Core failure rolls back all accounting"
        );
        _assertUnused(q);
        MintEngineCoreFixture(address(core)).setRejectMint(false);
        require(
            _mint(q) == root && keccak256(q.data) == signedBytes, "identical signed grace retry"
        );
    }

    function testLedgerInitialRegistrationSeparatelyRejectsGraceWithoutPolicyHistory() public {
        MintGraceInitialWriter writer = new MintGraceInitialWriter();
        ledger.setLedgerWriter(address(writer), true);
        uint64 until = uint64(block.timestamp + 100);
        vm.expectRevert(
            abi.encodeWithSelector(IStreamMintLedger.InvalidPolicyGrace.selector, until)
        );
        writer.register(ledger, until);
        require(
            ledger.registeredPhasePolicyHash(address(writer), 1, keccak256("initial phase")) == 0,
            "failed first registration absent"
        );
        writer.register(ledger, 0);
        (bytes32 previous, uint64 revision, uint64 actualUntil) =
            ledger.policyGrace(address(writer), 1, keccak256("initial phase"));
        require(
            previous == 0 && revision == 0 && actualUntil == 0,
            "initial registration has no predecessor"
        );
    }

    function testAdditiveCapabilityKeepsOriginalManagerInterfaceAdvertised() public view {
        require(
            manager.supportsInterface(type(IStreamMintManager).interfaceId), "permanent Manager ABI"
        );
        require(
            manager.supportsInterface(type(IStreamMintPolicyGrace).interfaceId),
            "additive grace ABI"
        );
        require(!manager.supportsInterface(0xffffffff), "invalid ERC165 id");
    }
}
