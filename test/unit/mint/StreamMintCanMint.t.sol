// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../../helpers/MintEngineTestBase.sol";
import "../../../smart-contracts/interfaces/stream/mint/IStreamMintPreview.sol";
import "../../../smart-contracts/interfaces/stream/mint/IStreamMintPolicyGrace.sol";
import "../../../smart-contracts/domains/mint/StreamMintAllowlistGate.sol";
import "../../../smart-contracts/domains/mint/StreamMintTicketGate.sol";
import "../../../script/current/StreamCurrentStackPlan.sol";

/// @dev Explicit live Artist authority boundary; no actual Artist/Safe acceptance is claimed.
contract MintCanMintArtistBoundary {
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
        return (consented, consented ? keccak256("typed preview consent") : bytes32(0));
    }

    function requireMintConsent(uint256, bytes32, bytes32) external view {
        require(consented, "typed current Artist withdrawal");
    }
}

/// @dev Explicit adversarial gate boundary, admitted through the actual ModuleRegistry.
contract MintCanMintMalformedGate is IStreamMintGate, IStreamMintBatchGate {
    uint256 private immutable mode;

    constructor(uint256 m) {
        mode = m;
    }

    function supportsInterface(bytes4 id) external pure override returns (bool) {
        return id == type(IERC165).interfaceId || id == type(IStreamMintGate).interfaceId
            || id == type(IStreamMintBatchGate).interfaceId;
    }

    function validateMint(
        address,
        address,
        uint256,
        bytes32,
        address,
        address,
        address[] calldata,
        address[] calldata,
        bytes32,
        bytes32,
        bytes calldata
    ) external pure override returns (GateResult memory) {
        revert("batch required");
    }

    function validateMintBatch(
        address,
        address,
        IStreamMintManager.MintBatch calldata,
        bytes calldata
    ) external view override returns (GateResult memory) {
        if (mode == 0) revert("malicious gate failure");
        if (mode == 1) assembly { return(0, 255) }
        if (mode == 3) {
            // Exhaust the gate's original registered call allowance; no protocol cap changes.
            assembly { for { } 1 { } { } }
        }
        assembly { return(0, 4096) }
    }
}

/// @notice Actual Manager/Ledger/Registry and production gates exercise advisory eligibility.
/// @dev Core, Artist and governance context are named typed seams from MintEngineTestBase.
/// Preview never proves downstream Core, payment, callback or prepared royalty acceptance.
contract StreamMintCanMintTest is MintEngineTestBase {
    bytes32 private constant COUNTER = keccak256("canMint beneficiary allowance");
    bytes32 private constant CONFIG = keccak256("canMint static counter");
    address private constant BENEFICIARY = address(0xBEEF);
    address private constant DELIVERY = address(0xD311);
    address private constant OUTSIDER = address(0x01751DE);
    address private constant OTHER = address(0x0A11CE);
    MintCanMintArtistBoundary private previewArtist;

    function setUp() public override {
        super.setUp();
        previewArtist = new MintCanMintArtistBoundary(address(core), address(manager));
        core.initialize(address(registry), address(previewArtist), address(manager));
    }

    function _preview(
        IStreamMintManager.MintBatch memory b,
        address prospective,
        bytes memory proof
    ) private view returns (IStreamMintPreview.MintPreview memory) {
        return IStreamMintPreview(address(manager)).canMint(b, prospective, proof);
    }

    function _configure(
        bytes32 phaseId,
        address gate,
        bytes32 gateConfig,
        uint256 count,
        uint64 cap,
        uint64 increment,
        IStreamMintLedger.CounterCapMode capMode,
        bytes32 definition,
        uint64 start,
        uint64 end
    ) private {
        bytes32[] memory ids = new bytes32[](count);
        IStreamMintManager.MintCounterConfig[] memory configs =
            new IStreamMintManager.MintCounterConfig[](count);
        for (uint256 i; i < count; ++i) {
            ids[i] = _id(i);
            configs[i] = IStreamMintManager.MintCounterConfig(
                true,
                IStreamMintManager.CounterKeyMode.RECIPIENT,
                capMode,
                IStreamMintLedger.CounterDeltaMode.STATIC,
                cap,
                increment,
                definition
            );
        }
        IStreamMintManager.MintGateConfig memory gc;
        if (gate != address(0)) {
            _admit(gate);
            gc.gate = gate;
            gc.gateConfigHash = gateConfig;
        }
        manager.configurePhase(
            1,
            phaseId,
            IStreamMintManager.MintPhaseConfig(
                false, start, end, 10, keccak256("preview terms"), 0
            ),
            gc,
            ids,
            configs
        );
        manager.setPhaseExecutor(1, phaseId, address(this), true);
    }

    function _static(uint256 counters, uint64 cap, uint64 increment) private {
        _configure(
            PHASE,
            address(0),
            0,
            counters,
            cap,
            increment,
            cap == 0
                ? IStreamMintLedger.CounterCapMode.NONE
                : IStreamMintLedger.CounterCapMode.STATIC,
            CONFIG,
            0,
            0
        );
    }

    function _admit(address gate) private {
        StreamModuleRegistration[] memory records = new StreamModuleRegistration[](1);
        records[0] = StreamModuleRegistration(
            gate,
            keccak256("6529STREAM_MINT_GATE_V1"),
            keccak256("canMint gate v1"),
            type(IStreamMintGate).interfaceId,
            600_000,
            gate.codehash,
            keccak256("canMint typed deployment"),
            keccak256(abi.encode("canMint gate", gate)),
            "urn:canMint:gate"
        );
        (GovernanceCall[] memory calls,) =
            StreamCurrentStackPlan.registrationCalls(registry, records);
        authority.setCurrentAction(
            true,
            keccak256(abi.encode("canMint admission", gate)),
            1,
            calls[0].scopeHash,
            calls[0].oldValueHash,
            calls[0].newValueHash
        );
        vm.prank(address(authority));
        registry.registerModule(records[0]);
        authority.setCurrentAction(false, 0, 0, 0, 0, 0);
        require(
            registry.moduleRecord(gate).status == ModuleRegistryStatus.ACTIVE, "real gate admission"
        );
    }

    function _request(uint256 quantity, uint256 nonce)
        private
        view
        returns (IStreamMintManager.MintBatch memory b)
    {
        b.collectionId = 1;
        b.phaseId = PHASE;
        b.payer = signer;
        b.initialRecipients = new address[](quantity);
        b.beneficiaries = new address[](quantity);
        b.tokenData = new bytes[](quantity);
        b.mintCommitments = new bytes32[](quantity);
        for (uint256 i; i < quantity; ++i) {
            b.initialRecipients[i] = DELIVERY;
            b.beneficiaries[i] = BENEFICIARY;
            b.tokenData[i] = abi.encode("original preview token", i);
            b.mintCommitments[i] = keccak256(abi.encode("original preview commitment", i));
        }
        b.expectedPolicyHash = manager.phasePolicyHash(1, PHASE);
        b.authorizationId = keccak256(abi.encode("preview authorization", nonce));
        b.contextHash = keccak256("preview context");
    }

    function _id(uint256 index) private pure returns (bytes32) {
        return index == 0 ? COUNTER : keccak256(abi.encode("additional preview counter", index));
    }

    function _subject() private view returns (bytes32) {
        return keccak256(
            abi.encode(
                keccak256("6529STREAM_MINT_COUNTER_SUBJECT_V1"),
                block.chainid,
                address(ledger),
                IStreamMintManager.CounterKeyMode.RECIPIENT,
                BENEFICIARY
            )
        );
    }

    function _key(bytes32 phaseId, bytes32 counterId) private view returns (bytes32) {
        return keccak256(
            abi.encode(
                keccak256("6529STREAM_MINT_COUNTER_VALUE_KEY_V1"),
                address(manager),
                uint256(1),
                phaseId,
                counterId,
                _subject()
            )
        );
    }

    function _resolution(bytes32 counterId, uint256 tokenIndex, bytes32 definition)
        private
        view
        returns (bytes32)
    {
        return keccak256(
            abi.encode(
                keccak256("6529STREAM_MINT_COUNTER_RESOLUTION_V1"),
                block.chainid,
                address(manager),
                address(ledger),
                uint256(1),
                PHASE,
                counterId,
                _subject(),
                tokenIndex,
                definition
            )
        );
    }

    function _failure(IStreamMintPreview.MintPreview memory p, bytes4 reason, uint256 quantity)
        private
        pure
    {
        require(
            !p.allowed && p.reason == reason && p.policyHash == 0 && p.gateHash == 0
                && p.quantity == quantity && p.counters.length == 0,
            "caught failure is explicit and contains no partial facts"
        );
    }

    function _unspent(
        IStreamMintManager.MintBatch memory b,
        uint64 value,
        uint256 nonce,
        uint256 minted
    ) private view {
        require(
            !manager.isAuthorizationUsed(b.authorizationId)
                && !ledger.isManagerAuthorizationUsed(address(manager), b.authorizationId)
                && manager.nextOperationNonce() == nonce && core.minted() == minted
                && ledger.counterValue(_key(b.phaseId, COUNTER)) == value,
            "preview or rejected execution preserves exact state"
        );
    }

    function _leaf(uint64 allowance) private view returns (bytes32) {
        return keccak256(
            bytes.concat(
                keccak256(
                    abi.encode(
                        keccak256("6529STREAM_MINT_ALLOWLIST_LEAF_V1"),
                        block.chainid,
                        address(manager),
                        uint256(1),
                        PHASE,
                        COUNTER,
                        BENEFICIARY,
                        allowance,
                        false,
                        uint256(0)
                    )
                )
            )
        );
    }

    function _allowlist(bool useGate, uint64 allowance)
        private
        returns (StreamMintAllowlistGate gate, bytes32 definition)
    {
        bytes32 leaf = _leaf(allowance);
        IStreamMintCounterPolicy.Definition memory d = IStreamMintCounterPolicy.Definition(
            IStreamMintCounterPolicy.CounterScope.PHASE,
            IStreamMintManager.CounterKeyMode.RECIPIENT,
            leaf,
            keccak256("preview cap root")
        );
        definition = ledger.registerCounterDefinition(d);
        if (useGate) gate = new StreamMintAllowlistGate(leaf, COUNTER);
        _configure(
            PHASE,
            address(gate),
            useGate ? gate.gateConfigHash() : bytes32(0),
            1,
            5,
            1,
            IStreamMintLedger.CounterCapMode.MERKLE_STATIC,
            definition,
            0,
            0
        );
    }

    function _proofs(uint256 quantity, uint64 allowance) private pure returns (bytes memory) {
        IStreamMintCounterPolicy.AllowlistProof[][] memory proofs =
            new IStreamMintCounterPolicy.AllowlistProof[][](1);
        proofs[0] = new IStreamMintCounterPolicy.AllowlistProof[](quantity);
        for (uint256 i; i < quantity; ++i) {
            proofs[0][i] =
                IStreamMintCounterPolicy.AllowlistProof(allowance, false, 0, new bytes32[](0));
        }
        return abi.encode(proofs);
    }

    function _allowlistRequest(
        StreamMintAllowlistGate gate,
        uint256 quantity,
        bytes32 nonce,
        uint64 allowance
    ) private view returns (IStreamMintManager.MintBatch memory b, bytes memory data) {
        b = _request(quantity, uint256(nonce));
        b.resolverData = _proofs(quantity, allowance);
        b.authorizationId = gate.previewAuthorizationId(address(manager), address(this), b, nonce);
        data = abi.encode(nonce);
    }

    function _nullifier(StreamMintAllowlistGate gate, bytes32 nonce)
        private
        view
        returns (bytes32)
    {
        return keccak256(
            abi.encode(
                keccak256("6529STREAM_MINT_ALLOWLIST_GATE_NONCE_V1"),
                block.chainid,
                address(gate),
                address(manager),
                address(ledger),
                uint256(1),
                PHASE,
                signer,
                nonce
            )
        );
    }

    function _gateHash(
        StreamMintAllowlistGate gate,
        bytes32 authorization,
        uint256 quantity,
        uint64 allowance
    ) private view returns (bytes32) {
        bytes32[] memory leaves = new bytes32[](quantity);
        for (uint256 i; i < quantity; ++i) {
            leaves[i] = _leaf(allowance);
        }
        return keccak256(
            abi.encode(
                keccak256("6529STREAM_MINT_ALLOWLIST_GATE_RESULT_V1"),
                gate.gateConfigHash(),
                authorization,
                keccak256(abi.encode(keccak256("6529STREAM_MINT_ALLOWLIST_GATE_LEAVES_V1"), leaves))
            )
        );
    }

    function testOutsiderPreviewUsesExplicitExecutorWithoutGrantingExecutionOrWriting() public {
        _static(1, 3, 1);
        IStreamMintManager.MintBatch memory b = _request(1, 1);
        vm.recordLogs();
        vm.prank(OUTSIDER);
        IStreamMintPreview.MintPreview memory p = _preview(b, address(this), "");
        require(
            p.allowed && p.reason == 0 && p.quantity == 1 && p.counters.length == 1,
            "outsider diagnostic"
        );
        require(
            p.policyHash == b.expectedPolicyHash && p.gateHash == 0,
            "live policy and ungated result"
        );
        require(vm.getRecordedLogs().length == 0, "view produces no protocol receipts");
        _unspent(b, 0, 0, 0);
        _failure(_preview(b, OUTSIDER, ""), IStreamMintManager.UnauthorizedMintExecutor.selector, 1);
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamMintManager.UnauthorizedMintExecutor.selector, uint256(1), PHASE, OUTSIDER
            )
        );
        vm.prank(OUTSIDER);
        manager.executeSingleStepMint(b, "");
        _unspent(b, 0, 0, 0);
        require(
            manager.supportsInterface(type(IStreamMintPreview).interfaceId)
                && manager.supportsInterface(type(IStreamMintManager).interfaceId),
            "additive interface only"
        );
    }

    function testRepeatedBeneficiaryRowsAggregateWholeBatchAtBoundaryAndDenialRollsBack() public {
        _static(1, 3, 1);
        manager.executeSingleStepMint(_request(1, 1), "");
        IStreamMintManager.MintBatch memory b = _request(2, 2);
        IStreamMintPreview.MintPreview memory p = _preview(b, address(this), "");
        require(p.allowed && p.counters.length == 2 && p.reason == 0, "exact remaining allowance");
        for (uint256 i; i < 2; ++i) {
            IStreamMintPreview.CounterPreview memory row = p.counters[i];
            require(
                row.counterId == COUNTER && row.subjectKey == _subject()
                    && row.valueKey == _key(PHASE, COUNTER) && row.current == 1
                    && row.increment == 1 && row.projected == 3 && row.cap == 3 && row.allowed
                    && row.resolutionHash == _resolution(COUNTER, i, CONFIG),
                "full exact row"
            );
        }
        _unspent(b, 1, 1, 1);
        IStreamMintManager.MintBatch memory excessive = _request(3, 3);
        p = _preview(excessive, address(this), "");
        require(
            !p.allowed && p.reason == IStreamMintLedger.CounterCapExceeded.selector
                && p.policyHash == excessive.expectedPolicyHash && p.gateHash == 0
                && p.quantity == 3 && p.counters.length == 3,
            "cap denial retains complete facts"
        );
        for (uint256 i; i < 3; ++i) {
            require(
                p.counters[i].current == 1 && p.counters[i].increment == 1
                    && p.counters[i].projected == 4 && p.counters[i].cap == 3
                    && !p.counters[i].allowed,
                "aggregate projection repeated for every affected row"
            );
        }
        bytes32 key = _key(PHASE, COUNTER);
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamMintLedger.CounterCapExceeded.selector, key, uint256(4), uint256(3)
            )
        );
        manager.executeSingleStepMint(excessive, "");
        _unspent(excessive, 1, 1, 1);
        manager.executeSingleStepMint(b, "");
        require(
            ledger.counterValue(key) == 3 && manager.nextOperationNonce() == 3,
            "boundary executes exactly"
        );
    }

    function testSixteenCountersTimesTenTokensReturnsAll160ExactRowsWithoutWrites() public {
        _static(16, 10, 1);
        IStreamMintManager.MintBatch memory b = _request(10, 1);
        vm.recordLogs();
        IStreamMintPreview.MintPreview memory p = _preview(b, address(this), "");
        require(
            p.allowed && p.reason == 0 && p.quantity == 10 && p.counters.length == 160
                && p.policyHash == b.expectedPolicyHash,
            "maximum full row matrix"
        );
        for (uint256 i; i < 160; ++i) {
            bytes32 id = _id(i / 10);
            IStreamMintPreview.CounterPreview memory row = p.counters[i];
            require(
                row.counterId == id && row.subjectKey == _subject()
                    && row.valueKey == _key(PHASE, id) && row.current == 0 && row.increment == 1
                    && row.projected == 10 && row.cap == 10 && row.allowed
                    && row.resolutionHash == _resolution(id, i % 10, CONFIG),
                "all160 canonical rows"
            );
            require(ledger.counterValue(row.valueKey) == 0, "no row writes");
        }
        require(vm.getRecordedLogs().length == 0, "no maximum-size preview events");
        _unspent(b, 0, 0, 0);
    }

    function testOverflowFailsWithEmptyRowsInsteadOfTruncatingUint64Projection() public {
        _static(1, 0, type(uint64).max);
        manager.executeSingleStepMint(_request(1, 1), "");
        IStreamMintManager.MintBatch memory b = _request(1, 2);
        _failure(_preview(b, address(this), ""), IStreamMintLedger.CounterValueOverflow.selector, 1);
        bytes32 key = _key(PHASE, COUNTER);
        vm.expectRevert(
            abi.encodeWithSelector(IStreamMintLedger.CounterValueOverflow.selector, key)
        );
        manager.executeSingleStepMint(b, "");
        _unspent(b, type(uint64).max, 1, 1);
    }

    function testGenuineAllowlistUsesActualManagerCallerExplicitExecutorAndExactProofRows() public {
        (StreamMintAllowlistGate gate, bytes32 definition) = _allowlist(true, 2);
        manager.setPhaseExecutor(1, PHASE, OTHER, true);
        (IStreamMintManager.MintBatch memory b, bytes memory data) =
            _allowlistRequest(gate, 2, bytes32(uint256(1)), 2);
        vm.prank(OUTSIDER);
        IStreamMintPreview.MintPreview memory p = _preview(b, address(this), data);
        require(
            p.allowed && p.policyHash == b.expectedPolicyHash && p.quantity == 2
                && p.gateHash == _gateHash(gate, b.authorizationId, 2, 2),
            "real gate caller and evidence"
        );
        for (uint256 i; i < 2; ++i) {
            require(
                p.counters[i].cap == 2 && p.counters[i].projected == 2
                    && p.counters[i].resolutionHash
                        == keccak256(
                            abi.encode(
                                keccak256("6529STREAM_MINT_ALLOWLIST_RESOLUTION_V1"),
                                _resolution(COUNTER, i, definition),
                                _leaf(2)
                            )
                        ),
                "leaf allowance and exact bound resolution"
            );
        }
        // OTHER is registered but the original authorization commits this executor instead.
        _failure(_preview(b, OTHER, data), StreamMintGateValidator.MintGateCallFailed.selector, 2);
        _unspent(b, 0, 0, 0);
        require(
            !manager.isNullifierUsed(_nullifier(gate, bytes32(uint256(1)))),
            "preview does not consume nonce"
        );
        manager.executeSingleStepMint(b, data);
        require(
            ledger.counterValue(_key(PHASE, COUNTER)) == 2,
            "real Manager repeats and consumes proofs"
        );
        (b, data) = _allowlistRequest(gate, 1, bytes32(uint256(2)), 2);
        p = _preview(b, address(this), data);
        require(
            !p.allowed && p.reason == IStreamMintLedger.CounterCapExceeded.selector
                && p.policyHash == b.expectedPolicyHash && p.quantity == 1 && p.counters.length == 1
                && p.gateHash == _gateHash(gate, b.authorizationId, 1, 2)
                && p.counters[0].current == 2 && p.counters[0].projected == 3
                && p.counters[0].cap == 2 && !p.counters[0].allowed,
            "gated cap denial retains full original gate evidence"
        );
        _unspent(b, 2, 2, 2);
        require(
            !manager.isNullifierUsed(_nullifier(gate, bytes32(uint256(2)))),
            "cap diagnostic consumes no fresh gate nonce"
        );
    }

    function testAuthorizationAndNullifierReplayDiagnosticsAreCallerIndependent() public {
        (StreamMintAllowlistGate gate,) = _allowlist(true, 5);
        bytes32 nonce = bytes32(uint256(7));
        (IStreamMintManager.MintBatch memory b, bytes memory data) =
            _allowlistRequest(gate, 1, nonce, 5);
        (, bytes32 usedRoot,) = manager.executeSingleStepMint(b, data);
        vm.prank(OUTSIDER);
        IStreamMintPreview.MintPreview memory p = _preview(b, address(this), data);
        _failure(p, IStreamMintLedger.AuthorizationAlreadyConsumed.selector, 1);
        vm.prank(OTHER);
        require(
            keccak256(abi.encode(_preview(b, address(this), data))) == keccak256(abi.encode(p)),
            "same scoped authorization answer"
        );
        b.contextHash = keccak256("fresh authorization same allowlist nonce");
        b.authorizationId = gate.previewAuthorizationId(address(manager), address(this), b, nonce);
        p = _preview(b, address(this), data);
        _failure(p, IStreamMintLedger.NullifierAlreadyConsumed.selector, 1);
        vm.prank(OUTSIDER);
        require(
            keccak256(abi.encode(_preview(b, address(this), data))) == keccak256(abi.encode(p)),
            "same scoped nullifier answer"
        );
        bytes32 nullifier = _nullifier(gate, nonce);
        vm.expectRevert(
            abi.encodeWithSelector(IStreamMintLedger.NullifierAlreadyConsumed.selector, nullifier)
        );
        manager.executeSingleStepMint(b, data);
        _unspent(b, 1, 1, 1);
        require(
            manager.isOperationRootUsed(usedRoot) && manager.isNullifierUsed(nullifier),
            "original replay remains used"
        );
    }

    function testMalformedInlineProofAndProofCountReturnPreciseEmptyFailures() public {
        _allowlist(false, 3);
        IStreamMintManager.MintBatch memory b = _request(1, 1);
        b.resolverData = _proofs(1, 2);
        _failure(
            _preview(b, address(this), ""),
            IStreamMintCounterPolicy.MintAllowlistProofInvalid.selector,
            1
        );
        b.resolverData = _proofs(0, 3);
        _failure(
            _preview(b, address(this), ""),
            IStreamMintCounterPolicy.MintAllowlistProofCountMismatch.selector,
            1
        );
        _unspent(b, 0, 0, 0);
        b.resolverData = _proofs(1, 3);
        require(_preview(b, address(this), "").allowed, "same request with original proof succeeds");
    }

    function testPausedAndExactPhaseTimeBoundsReturnReasonsWithoutStateEffects() public {
        _configure(
            PHASE,
            address(0),
            0,
            1,
            3,
            1,
            IStreamMintLedger.CounterCapMode.STATIC,
            CONFIG,
            1000,
            1100
        );
        IStreamMintManager.MintBatch memory b = _request(1, 1);
        vm.warp(999);
        _failure(_preview(b, address(this), ""), IStreamMintManager.MintPhaseNotStarted.selector, 1);
        vm.warp(1000);
        require(_preview(b, address(this), "").allowed, "inclusive start");
        manager.setPhasePaused(1, PHASE, true);
        _failure(_preview(b, address(this), ""), IStreamMintManager.MintPhasePaused.selector, 1);
        manager.setPhasePaused(1, PHASE, false);
        vm.warp(1100);
        require(_preview(b, address(this), "").allowed, "inclusive end");
        vm.warp(1101);
        _failure(_preview(b, address(this), ""), IStreamMintManager.MintPhaseEnded.selector, 1);
        _unspent(b, 0, 0, 0);
    }

    function testPreviewSuccessDoesNotClaimDownstreamCoreAndExactExecutionRetries() public {
        _static(1, 3, 1);
        IStreamMintManager.MintBatch memory b = _request(1, 1);
        MintEngineCoreFixture(address(core)).setRejectMint(true);
        require(
            _preview(b, address(this), "").allowed,
            "eligibility excludes downstream Core acceptance"
        );
        (bytes32 expectedRoot,) = manager.previewSingleStepMintOperation(b, "");
        vm.expectRevert(abi.encodeWithSignature("Error(string)", "core mint admission"));
        manager.executeSingleStepMint(b, "");
        _unspent(b, 0, 0, 0);
        require(
            !manager.isOperationRootUsed(expectedRoot),
            "downstream failure rolls back original root"
        );
        MintEngineCoreFixture(address(core)).setRejectMint(false);
        (, bytes32 actualRoot,) = manager.executeSingleStepMint(b, "");
        require(
            actualRoot == expectedRoot && manager.isOperationRootUsed(actualRoot)
                && ledger.counterValue(_key(PHASE, COUNTER)) == 1,
            "identical execution retries independently"
        );
    }

    function testRevertingShortOversizedAndGasBurningAdmittedGatesFailClosedWithoutWrites() public {
        for (uint256 mode; mode < 4; ++mode) {
            MintCanMintMalformedGate gate = new MintCanMintMalformedGate(mode);
            bytes32 phaseId = keccak256(abi.encode("malformed preview gate", mode));
            _configure(
                phaseId,
                address(gate),
                keccak256("explicit malicious gate config"),
                1,
                3,
                1,
                IStreamMintLedger.CounterCapMode.STATIC,
                CONFIG,
                0,
                0
            );
            IStreamMintManager.MintBatch memory b = _request(1, mode + 1);
            b.phaseId = phaseId;
            b.expectedPolicyHash = manager.phasePolicyHash(1, phaseId);
            _failure(
                _preview(b, address(this), ""),
                StreamMintGateValidator.MintGateCallFailed.selector,
                1
            );
            vm.expectRevert(
                abi.encodeWithSelector(
                    StreamMintGateValidator.MintGateCallFailed.selector, address(gate)
                )
            );
            manager.executeSingleStepMint(b, "");
            _unspent(b, 0, 0, 0);
        }
    }

    function testLowCallerGasReturnsCanonicalUnavailableForValid160RowRequest() public {
        _static(16, 10, 1);
        IStreamMintManager.MintBatch memory b = _request(10, 1);
        IStreamMintPreview.MintPreview memory normal = _preview(b, address(this), "");
        require(
            normal.allowed && normal.counters.length == 160, "request ordinarily returns all rows"
        );
        bytes memory payload =
            abi.encodeCall(IStreamMintPreview.canMint, (b, address(this), bytes("")));
        vm.recordLogs();
        // This caller budget is already below the worker's 100k reserve plus dispatch margin.
        // It must return the complete diagnostic, without attempting a partial row evaluation.
        vm.prank(OUTSIDER);
        (bool ok, bytes memory raw) = address(manager).staticcall{ gas: 100_000 }(payload);
        require(ok && raw.length == 256, "reserved failure returns canonical complete ABI");
        IStreamMintPreview.MintPreview memory p = abi.decode(raw, (IStreamMintPreview.MintPreview));
        _failure(p, IStreamMintPreview.MintPreviewUnavailable.selector, 10);
        require(keccak256(raw) == keccak256(abi.encode(p)), "no trailing or truncated failure data");
        require(vm.getRecordedLogs().length == 0, "low-gas diagnostic emits no protocol receipt");
        for (uint256 i; i < 16; ++i) {
            require(ledger.counterValue(_key(PHASE, _id(i))) == 0, "all counter values unchanged");
        }
        _unspent(b, 0, 0, 0);
    }

    function testLinkedCapabilityTableRetainsExactManagerInterfacesWithinERC165GasBudget()
        public
        view
    {
        bytes4[14] memory ids = [
            type(IStreamMintManager).interfaceId,
            type(IStreamPreparedNativeMint).interfaceId,
            type(IStreamPreparedNativeContentMint).interfaceId,
            type(IStreamPreparedNativeContentPurchaseMint).interfaceId,
            type(IStreamPreparedNativeOfferMint).interfaceId,
            type(IStreamERC20OfferMint).interfaceId,
            type(IStreamMintSaleAuthorizationRevocation).interfaceId,
            type(IStreamPreparedNativeRightsMint).interfaceId,
            type(IStreamMintAuthorizationRevocation).interfaceId,
            type(IStreamMintRoyaltyPolicy).interfaceId,
            type(IStreamMintManagerImport).interfaceId,
            type(IStreamMintPolicyGrace).interfaceId,
            type(IStreamMintPhaseFreeze).interfaceId,
            type(IStreamMintPreview).interfaceId
        ];
        for (uint256 i; i < ids.length; ++i) {
            _probeInterface(ids[i], true);
        }
        _probeInterface(type(IERC165).interfaceId, true);
        // The original Manager exposes the inherited gas APIs without advertising their ID.
        // StreamGasParameterHost has no ERC165 override; extraction must preserve that fact.
        _probeInterface(type(IStreamGasParameterHost).interfaceId, false);
        require(
            manager.gasParameter(manager.GGP_ARTIST_AUTHORITY_GAS_LIMIT()) != 0,
            "original inherited gas host API remains live"
        );
        _probeInterface(bytes4(0xffffffff), false);
        _probeInterface(bytes4(keccak256("not-a-6529Stream-interface")), false);
    }

    function _probeInterface(bytes4 id, bool expected) private view {
        (bool ok, bytes memory raw) = address(manager).staticcall{ gas: 30_000 }(
            abi.encodeCall(IERC165.supportsInterface, (id))
        );
        require(ok && raw.length == 32, "individual ERC165 probe fits original gas budget");
        require(
            abi.decode(raw, (uint256)) == (expected ? 1 : 0), "exact canonical capability result"
        );
    }

    function testMalformedBatchKeepsInputQuantityButReturnsNoPartialRows() public {
        _static(1, 3, 1);
        IStreamMintManager.MintBatch memory b = _request(2, 1);
        b.beneficiaries = new address[](1);
        b.beneficiaries[0] = BENEFICIARY;
        _failure(
            _preview(b, address(this), ""), IStreamMintManager.MintArrayLengthMismatch.selector, 2
        );
        _unspent(b, 0, 0, 0);
    }

    function testExistingExecutionIdentityExistenceAndPauseGuardsKeepExactOrder() public {
        _static(1, 3, 1);
        IStreamMintManager.MintBatch memory b = _request(1, 1);
        b.collectionId = 0;
        _failure(_preview(b, OUTSIDER, ""), IStreamMintManager.InvalidMintPhase.selector, 1);
        vm.expectRevert(
            abi.encodeWithSelector(IStreamMintManager.InvalidMintPhase.selector, uint256(0), PHASE)
        );
        vm.prank(OUTSIDER);
        manager.executeSingleStepMint(b, "");
        b.collectionId = 1;
        b.phaseId = keccak256("unconfigured preview phase");
        _failure(_preview(b, OUTSIDER, ""), IStreamMintManager.MintPhaseDoesNotExist.selector, 1);
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamMintManager.MintPhaseDoesNotExist.selector, uint256(1), b.phaseId
            )
        );
        vm.prank(OUTSIDER);
        manager.executeSingleStepMint(b, "");
        b.phaseId = PHASE;
        manager.setPhasePaused(1, PHASE, true);
        _failure(_preview(b, OUTSIDER, ""), IStreamMintManager.MintPhasePaused.selector, 1);
        vm.expectRevert(
            abi.encodeWithSelector(IStreamMintManager.MintPhasePaused.selector, uint256(1), PHASE)
        );
        vm.prank(OUTSIDER);
        manager.executeSingleStepMint(b, "");
        _unspent(b, 0, 0, 0);
    }

    function testSignedPredecessorGraceUsesLivePolicyAndNeverBypassesCurrentArtist() public {
        StreamMintTicketGate gate = new StreamMintTicketGate(address(authority), signer, 1);
        _configure(
            PHASE,
            address(gate),
            gate.gateConfigHash(),
            1,
            3,
            1,
            IStreamMintLedger.CounterCapMode.STATIC,
            CONFIG,
            0,
            0
        );
        IStreamMintManager.MintBatch memory b = _request(1, 1);
        b.authorizer = signer;
        StreamMintTicketTypes.MintTicket memory t = _ticket(1);
        t.initialRecipientsHash = keccak256(
            abi.encode(keccak256("6529STREAM_MINT_BATCH_RECIPIENTS_V1"), b.initialRecipients)
        );
        t.beneficiariesHash = keccak256(
            abi.encode(keccak256("6529STREAM_MINT_BATCH_BENEFICIARIES_V1"), b.beneficiaries)
        );
        t.tokenDataArrayHash =
            keccak256(abi.encode(keccak256("6529STREAM_MINT_BATCH_TOKEN_DATA_V1"), b.tokenData));
        t.mintCommitmentsHash = keccak256(
            abi.encode(keccak256("6529STREAM_MINT_BATCH_COMMITMENTS_V1"), b.mintCommitments)
        );
        t.contextHash = b.contextHash;
        t.deadline = uint64(block.timestamp + 1 days);
        bytes32 digest = StreamMintTicketHash.digest(block.chainid, address(gate), t);
        b.authorizationId = StreamMintTicketHash.authorizationId(digest);
        bytes memory proof = abi.encode(t, _signature(SIGNER_KEY, digest));
        uint64 until = uint64(block.timestamp + 100);
        IStreamMintPolicyGrace(address(manager))
            .setPhaseExecutorWithGrace(1, PHASE, OTHER, true, until);
        bytes32 live = manager.phasePolicyHash(1, PHASE);
        require(live != b.expectedPolicyHash, "genuine policy rotation");
        vm.prank(OUTSIDER);
        IStreamMintPreview.MintPreview memory p = _preview(b, address(this), proof);
        require(
            p.allowed && p.policyHash == live && p.gateHash == digest,
            "old signed proof current live diagnostics"
        );
        previewArtist.setConsented(false);
        _failure(
            _preview(b, address(this), proof),
            StreamMintArtistConsent.ArtistAuthorityReadFailed.selector,
            1
        );
        vm.expectRevert(
            abi.encodeWithSelector(
                StreamMintArtistConsent.ArtistAuthorityReadFailed.selector,
                address(previewArtist),
                IStreamArtistMintConsent.requireMintConsent.selector
            )
        );
        manager.executeSingleStepMint(b, proof);
        _unspent(b, 0, 0, 0);
        previewArtist.setConsented(true);
        vm.warp(until);
        require(_preview(b, address(this), proof).allowed, "inclusive policy grace boundary");
        vm.warp(uint256(until) + 1);
        _failure(
            _preview(b, address(this), proof), IStreamMintManager.MintPolicyHashMismatch.selector, 1
        );
        _unspent(b, 0, 0, 0);
    }
}
