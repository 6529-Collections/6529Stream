// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../../helpers/MintEngineTestBase.sol";
import {
    IStreamMintCounterReads as Reads
} from "../../../smart-contracts/interfaces/stream/mint/IStreamMintCounterReads.sol";
import "../../../smart-contracts/interfaces/stream/mint/IStreamMintPreview.sol";

/// @notice Actual Manager and Ledger accounting reads with literal subject/value/resolution vectors.
/// @dev Core, Artist and governance are the explicit typed MintEngineTestBase boundaries.
/// These reads neither authorize execution nor assert downstream Core/payment acceptance.
contract StreamMintCounterReadsTest is MintEngineTestBase {
    bytes32 private constant COUNTER = keccak256("counter read units");
    bytes32 private constant OTHER_PHASE = keccak256("counter read other phase");
    bytes32 private constant CONTEXT = keccak256("counter read batch context");
    address private constant PAYER = address(0xA111);
    address private constant BENEFICIARY = address(0xB222);
    address private constant CUSTODY = address(0xC333);
    address private constant OTHER_EXECUTOR = address(0xE444);
    address private constant OBSERVER = address(0x05555);

    function _reads() private view returns (Reads) {
        return Reads(address(manager));
    }

    function _configure(
        uint256 collectionId,
        bytes32 phaseId,
        IStreamMintManager.CounterKeyMode mode,
        IStreamMintCounterPolicy.CounterScope scope,
        uint64 cap,
        uint64 increment,
        bytes32 root,
        bool unlimited
    ) private returns (bytes32 definition) {
        if (unlimited) {
            definition = keccak256("original legacy unlimited counter");
        } else {
            definition = ledger.registerCounterDefinition(
                IStreamMintCounterPolicy.Definition(
                    scope, mode, root, keccak256("read profile definition")
                )
            );
        }
        bytes32[] memory ids = new bytes32[](1);
        ids[0] = COUNTER;
        IStreamMintManager.MintCounterConfig[] memory configs =
            new IStreamMintManager.MintCounterConfig[](1);
        configs[0] = IStreamMintManager.MintCounterConfig(
            true,
            mode,
            unlimited
                ? IStreamMintLedger.CounterCapMode.NONE
                : root == 0
                    ? IStreamMintLedger.CounterCapMode.STATIC
                    : IStreamMintLedger.CounterCapMode.MERKLE_STATIC,
            IStreamMintLedger.CounterDeltaMode.STATIC,
            cap,
            increment,
            definition
        );
        IStreamMintManager.MintGateConfig memory gate;
        manager.configurePhase(
            collectionId,
            phaseId,
            IStreamMintManager.MintPhaseConfig(false, 0, 0, 10, keccak256("counter read terms"), 0),
            gate,
            ids,
            configs
        );
        manager.setPhaseExecutor(collectionId, phaseId, address(this), true);
    }

    function _context(uint256 collectionId, bytes32 phaseId, uint256 tokenIndex)
        private
        view
        returns (Reads.CounterKeyContext memory c)
    {
        c = Reads.CounterKeyContext(
            collectionId,
            phaseId,
            COUNTER,
            PAYER,
            CUSTODY,
            BENEFICIARY,
            address(this),
            address(0),
            tokenIndex,
            CONTEXT,
            ""
        );
    }

    function _batch(uint256 collectionId, bytes32 phaseId, uint256 quantity, uint256 nonce)
        private
        view
        returns (IStreamMintManager.MintBatch memory b)
    {
        b.collectionId = collectionId;
        b.phaseId = phaseId;
        b.payer = PAYER;
        b.initialRecipients = new address[](quantity);
        b.beneficiaries = new address[](quantity);
        b.tokenData = new bytes[](quantity);
        b.mintCommitments = new bytes32[](quantity);
        for (uint256 i; i < quantity; ++i) {
            b.initialRecipients[i] = CUSTODY;
            b.beneficiaries[i] = BENEFICIARY;
            b.tokenData[i] = abi.encode("counter read token", i);
        }
        b.expectedPolicyHash = manager.phasePolicyHash(collectionId, phaseId);
        b.authorizationId = keccak256(abi.encode("counter read authorization", nonce));
        b.contextHash = CONTEXT;
    }

    function _scope(
        IStreamMintCounterPolicy.CounterScope scope,
        uint256 collectionId,
        bytes32 phaseId
    ) private pure returns (uint256, bytes32) {
        if (scope == IStreamMintCounterPolicy.CounterScope.GLOBAL) {
            return (0, 0);
        }
        if (scope == IStreamMintCounterPolicy.CounterScope.COLLECTION) return (collectionId, 0);
        return (collectionId, phaseId);
    }

    function _subject(
        Reads.CounterKeyContext memory c,
        IStreamMintManager.CounterKeyMode mode,
        IStreamMintCounterPolicy.CounterScope scope
    ) private view returns (bytes32) {
        bytes32 domain = keccak256("6529STREAM_MINT_COUNTER_SUBJECT_V1");
        if (mode == IStreamMintManager.CounterKeyMode.CONSTANT) {
            (uint256 collectionId, bytes32 phaseId) = _scope(scope, c.collectionId, c.phaseId);
            return keccak256(
                abi.encode(
                    domain, block.chainid, address(ledger), mode, collectionId, phaseId, c.counterId
                )
            );
        }
        if (mode == IStreamMintManager.CounterKeyMode.CONTEXT) {
            return
                keccak256(abi.encode(domain, block.chainid, address(ledger), mode, c.contextHash));
        }
        address account = mode == IStreamMintManager.CounterKeyMode.PAYER
            ? c.payer
            : mode == IStreamMintManager.CounterKeyMode.RECIPIENT ? c.beneficiary : c.executor;
        return keccak256(abi.encode(domain, block.chainid, address(ledger), mode, account));
    }

    function _key(
        Reads.CounterKeyContext memory c,
        bytes32 subject,
        IStreamMintCounterPolicy.CounterScope scope
    ) private view returns (bytes32) {
        (uint256 collectionId, bytes32 phaseId) = _scope(scope, c.collectionId, c.phaseId);
        return keccak256(
            abi.encode(
                keccak256("6529STREAM_MINT_COUNTER_VALUE_KEY_V1"),
                address(manager),
                collectionId,
                phaseId,
                c.counterId,
                subject
            )
        );
    }

    function _resolution(Reads.CounterKeyContext memory c, bytes32 subject, bytes32 definition)
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
                c.collectionId,
                c.phaseId,
                c.counterId,
                subject,
                c.tokenIndex,
                definition
            )
        );
    }

    function _leaf(
        address managerAddress,
        Reads.CounterKeyContext memory c,
        address account,
        uint64 cap
    ) private view returns (bytes32) {
        return keccak256(
            bytes.concat(
                keccak256(
                    abi.encode(
                        keccak256("6529STREAM_MINT_ALLOWLIST_LEAF_V1"),
                        block.chainid,
                        managerAddress,
                        c.collectionId,
                        c.phaseId,
                        c.counterId,
                        account,
                        cap,
                        false,
                        uint256(0)
                    )
                )
            )
        );
    }

    function _proof(uint64 cap, bytes32 sibling)
        private
        pure
        returns (IStreamMintCounterPolicy.AllowlistProof memory p)
    {
        p.maxCount = cap;
        p.proof = new bytes32[](sibling == 0 ? 0 : 1);
        if (sibling != 0) p.proof[0] = sibling;
    }

    function _batchProof(IStreamMintCounterPolicy.AllowlistProof memory proof, uint256 quantity)
        private
        pure
        returns (bytes memory)
    {
        IStreamMintCounterPolicy.AllowlistProof[][] memory groups =
            new IStreamMintCounterPolicy.AllowlistProof[][](1);
        groups[0] = new IStreamMintCounterPolicy.AllowlistProof[](quantity);
        for (uint256 i; i < quantity; ++i) {
            groups[0][i] = proof;
        }
        return abi.encode(groups);
    }

    function _compare(
        Reads.CounterKeyContext memory c,
        IStreamMintManager.CounterKeyMode mode,
        IStreamMintCounterPolicy.CounterScope scope,
        bytes32 definition,
        uint64 cap,
        IStreamMintPreview.CounterPreview memory row,
        bytes32 leaf
    ) private view {
        Reads.CounterResolution memory r = _reads().resolveCounter(c);
        bytes32 subject = _subject(c, mode, scope);
        // Original consumption computes its evidence before scope normalizes CONSTANT's
        // returned subject/value key. Preserve that original PHASE subject in the receipt.
        bytes32 originalSubject = mode == IStreamMintManager.CounterKeyMode.CONSTANT
            ? _subject(c, mode, IStreamMintCounterPolicy.CounterScope.PHASE)
            : subject;
        bytes32 resolution = _resolution(c, originalSubject, definition);
        if (leaf != 0) {
            resolution = keccak256(
                abi.encode(keccak256("6529STREAM_MINT_ALLOWLIST_RESOLUTION_V1"), resolution, leaf)
            );
        }
        require(
            r.subjectKey == subject && r.effectiveCap == cap && r.increment == 2
                && r.resolutionHash == resolution,
            "literal original resolution preimage"
        );
        require(
            row.counterId == c.counterId && row.subjectKey == r.subjectKey
                && row.valueKey == _key(c, subject, scope) && row.cap == r.effectiveCap
                && row.increment == r.increment && row.resolutionHash == r.resolutionHash,
            "read resolution exactly matches original canMint row"
        );
        (Reads.CounterResolution memory same, uint64 current, uint64 remaining) =
            _reads().remainingForResolvedCounter(c);
        require(
            keccak256(abi.encode(same)) == keccak256(abi.encode(r)) && current == 0
                && remaining == cap,
            "atomic resolved remaining keeps original tuple and counter units"
        );
        require(
            _reads().counterValue(c.collectionId, c.phaseId, c.counterId, subject) == 0
                && _reads().rawCounterValue(row.valueKey) == 0,
            "both actual Ledger read surfaces agree"
        );
    }

    function testStaticScopeAndKeyProfilesMatchOriginalCanMintAndLiteralResolution() public {
        for (uint256 s; s < 3; ++s) {
            for (uint256 key = 1; key <= 4; ++key) {
                IStreamMintCounterPolicy.CounterScope scope =
                    IStreamMintCounterPolicy.CounterScope(s);
                IStreamMintManager.CounterKeyMode mode = IStreamMintManager.CounterKeyMode(key);
                bytes32 phaseId = keccak256(abi.encode("static read profile", s, key));
                bytes32 definition = _configure(1, phaseId, mode, scope, 12, 2, 0, false);
                IStreamMintManager.MintBatch memory b = _batch(1, phaseId, 2, 1);
                // Ordinary static preparation ignores resolver data, even when it is not a proof.
                b.resolverData = hex"010203";
                IStreamMintPreview.MintPreview memory p =
                    IStreamMintPreview(address(manager)).canMint(b, address(this), "");
                require(
                    p.allowed && p.counters.length == 2 && p.counters[1].projected == 4,
                    "static profile eligible"
                );
                Reads.CounterKeyContext memory c = _context(1, phaseId, 1);
                c.resolverData = b.resolverData;
                _compare(c, mode, scope, definition, 12, p.counters[1], 0);
            }
        }
        require(
            manager.nextOperationNonce() == 0 && core.minted() == 0,
            "all diagnostic profiles are read-only"
        );
    }

    function testContextScopeProfilesUseOriginalBatchSentinelAndSingleIncrement() public {
        for (uint256 s = 1; s <= 2; ++s) {
            IStreamMintCounterPolicy.CounterScope scope = IStreamMintCounterPolicy.CounterScope(s);
            bytes32 phaseId = keccak256(abi.encode("context read profile", s));
            bytes32 definition = _configure(
                1, phaseId, IStreamMintManager.CounterKeyMode.CONTEXT, scope, 12, 2, 0, false
            );
            IStreamMintManager.MintBatch memory b = _batch(1, phaseId, 3, 1);
            IStreamMintPreview.MintPreview memory p =
                IStreamMintPreview(address(manager)).canMint(b, address(this), "");
            require(
                p.allowed && p.counters.length == 1 && p.counters[0].projected == 2,
                "once per batch context"
            );
            Reads.CounterKeyContext memory c = _context(1, phaseId, type(uint256).max);
            _compare(
                c,
                IStreamMintManager.CounterKeyMode.CONTEXT,
                scope,
                definition,
                12,
                p.counters[0],
                0
            );
        }
    }

    function testAllPayerAndBeneficiaryMerkleProfilesMatchExactOriginalRows() public {
        for (uint256 s = 1; s <= 2; ++s) {
            for (uint256 key = 2; key <= 3; ++key) {
                IStreamMintCounterPolicy.CounterScope scope =
                    IStreamMintCounterPolicy.CounterScope(s);
                IStreamMintManager.CounterKeyMode mode = IStreamMintManager.CounterKeyMode(key);
                bytes32 phaseId = keccak256(abi.encode("Merkle read profile", s, key));
                Reads.CounterKeyContext memory c = _context(1, phaseId, 1);
                bytes32 leaf = _leaf(address(manager), c, key == 2 ? PAYER : BENEFICIARY, 7);
                bytes32 definition = _configure(1, phaseId, mode, scope, 10, 2, leaf, false);
                IStreamMintCounterPolicy.AllowlistProof memory proof = _proof(7, 0);
                c.resolverData = abi.encode(proof);
                IStreamMintManager.MintBatch memory b = _batch(1, phaseId, 2, 1);
                b.resolverData = _batchProof(proof, key == 2 ? 1 : 2);
                IStreamMintPreview.MintPreview memory p =
                    IStreamMintPreview(address(manager)).canMint(b, address(this), "");
                require(p.allowed && p.counters.length == 2, "proof bound profile eligible");
                _compare(c, mode, scope, definition, 7, p.counters[1], leaf);
            }
        }
    }

    function testPhaseCollectionAndGlobalReadsUseCanonicalScopeAcrossRealMints() public {
        for (uint256 s; s < 3; ++s) {
            IStreamMintCounterPolicy.CounterScope scope = IStreamMintCounterPolicy.CounterScope(s);
            bytes32 firstPhase = keccak256(abi.encode("scope first", s));
            bytes32 secondPhase = keccak256(abi.encode("scope second", s));
            _configure(
                1, firstPhase, IStreamMintManager.CounterKeyMode.CONSTANT, scope, 12, 2, 0, false
            );
            _configure(
                1, secondPhase, IStreamMintManager.CounterKeyMode.CONSTANT, scope, 12, 2, 0, false
            );
            _configure(
                2, firstPhase, IStreamMintManager.CounterKeyMode.CONSTANT, scope, 12, 2, 0, false
            );
            manager.executeSingleStepMint(_batch(1, firstPhase, 1, s + 1), "");
            for (uint256 route; route < 3; ++route) {
                Reads.CounterKeyContext memory c =
                    _context(route == 2 ? 2 : 1, route == 1 ? secondPhase : firstPhase, 0);
                bytes32 subject = _subject(c, IStreamMintManager.CounterKeyMode.CONSTANT, scope);
                uint64 expected = route == 0 || s == 0 || (s == 1 && route == 1) ? 2 : 0;
                require(
                    _reads().counterValue(c.collectionId, c.phaseId, COUNTER, subject) == expected
                        && _reads().rawCounterValue(_key(c, subject, scope)) == expected
                        && _reads().remainingForCounter(c.collectionId, c.phaseId, COUNTER, subject)
                        == 12 - expected,
                    "original reserved scope identity and actual stored units"
                );
            }
        }
    }

    function testBeneficiaryDoesNotBecomeCustodyAndExplicitExecutorDoesNotBecomeReader() public {
        _configure(
            1,
            PHASE,
            IStreamMintManager.CounterKeyMode.RECIPIENT,
            IStreamMintCounterPolicy.CounterScope.PHASE,
            12,
            2,
            0,
            false
        );
        Reads.CounterKeyContext memory c = _context(1, PHASE, 0);
        Reads.CounterResolution memory recipient = _reads().resolveCounter(c);
        c.initialRecipient = OBSERVER;
        vm.prank(OBSERVER);
        Reads.CounterResolution memory unchanged = _reads().resolveCounter(c);
        require(
            keccak256(abi.encode(recipient)) == keccak256(abi.encode(unchanged)),
            "custody and reader excluded from beneficiary key"
        );
        manager.executeSingleStepMint(_batch(1, PHASE, 1, 1), "");
        c.beneficiary = CUSTODY;
        Reads.CounterResolution memory custody = _reads().resolveCounter(c);
        require(
            custody.subjectKey != recipient.subjectKey
                && _reads().counterValue(1, PHASE, COUNTER, recipient.subjectKey) == 2
                && _reads().counterValue(1, PHASE, COUNTER, custody.subjectKey) == 0,
            "only intended beneficiary consumed"
        );
        _configure(
            1,
            OTHER_PHASE,
            IStreamMintManager.CounterKeyMode.EXECUTOR,
            IStreamMintCounterPolicy.CounterScope.PHASE,
            12,
            2,
            0,
            false
        );
        c = _context(1, OTHER_PHASE, 0);
        c.executor = OTHER_EXECUTOR;
        vm.prank(OBSERVER);
        Reads.CounterResolution memory executor = _reads().resolveCounter(c);
        require(
            executor.subjectKey
                == _subject(
                    c,
                    IStreamMintManager.CounterKeyMode.EXECUTOR,
                    IStreamMintCounterPolicy.CounterScope.PHASE
                ),
            "uses explicit unregistered executor without granting authority"
        );
    }

    function testStaticRemainingIsCounterUnitsAndSaturatesAtZeroAcrossSharedKey() public {
        _configure(
            1,
            PHASE,
            IStreamMintManager.CounterKeyMode.RECIPIENT,
            IStreamMintCounterPolicy.CounterScope.COLLECTION,
            7,
            2,
            0,
            false
        );
        _configure(
            1,
            OTHER_PHASE,
            IStreamMintManager.CounterKeyMode.RECIPIENT,
            IStreamMintCounterPolicy.CounterScope.COLLECTION,
            3,
            2,
            0,
            false
        );
        manager.executeSingleStepMint(_batch(1, PHASE, 2, 1), "");
        Reads.CounterKeyContext memory c = _context(1, PHASE, 0);
        (Reads.CounterResolution memory r, uint64 current, uint64 remaining) =
            _reads().remainingForResolvedCounter(c);
        require(
            r.increment == 2 && current == 4 && remaining == 3
                && _reads().remainingForCounter(1, PHASE, COUNTER, r.subjectKey) == 3,
            "three units not one token"
        );
        c.phaseId = OTHER_PHASE;
        (r, current, remaining) = _reads().remainingForResolvedCounter(c);
        require(
            r.effectiveCap == 3 && current == 4 && remaining == 0
                && _reads().remainingForCounter(1, OTHER_PHASE, COUNTER, r.subjectKey) == 0,
            "lower phase ceiling clamps without underflow"
        );
    }

    function testTwoValidLeavesForSameAccountReturnDifferentCapsOnSameLedgerValue() public {
        Reads.CounterKeyContext memory c = _context(1, PHASE, 0);
        bytes32 low = _leaf(address(manager), c, BENEFICIARY, 3);
        bytes32 high = _leaf(address(manager), c, BENEFICIARY, 7);
        bytes32 root = low < high
            ? keccak256(abi.encodePacked(low, high))
            : keccak256(abi.encodePacked(high, low));
        _configure(
            1,
            PHASE,
            IStreamMintManager.CounterKeyMode.RECIPIENT,
            IStreamMintCounterPolicy.CounterScope.PHASE,
            10,
            2,
            root,
            false
        );
        IStreamMintCounterPolicy.AllowlistProof memory highProof = _proof(7, low);
        IStreamMintManager.MintBatch memory b = _batch(1, PHASE, 2, 1);
        b.resolverData = _batchProof(highProof, 2);
        manager.executeSingleStepMint(b, "");
        c.resolverData = abi.encode(highProof);
        (Reads.CounterResolution memory highResult, uint64 highCurrent, uint64 highRemaining) =
            _reads().remainingForResolvedCounter(c);
        c.resolverData = abi.encode(_proof(3, high));
        (Reads.CounterResolution memory lowResult, uint64 lowCurrent, uint64 lowRemaining) =
            _reads().remainingForResolvedCounter(c);
        require(
            highResult.subjectKey == lowResult.subjectKey && highCurrent == 4 && lowCurrent == 4
                && highResult.effectiveCap == 7 && lowResult.effectiveCap == 3 && highRemaining == 3
                && lowRemaining == 0 && highResult.resolutionHash != lowResult.resolutionHash,
            "same account and counter value have proof-dependent honest remaining caps"
        );
        vm.expectRevert(abi.encodeWithSelector(Reads.MintCounterProofRequired.selector, COUNTER));
        _reads().remainingForCounter(1, PHASE, COUNTER, highResult.subjectKey);
        b = _batch(1, PHASE, 1, 2);
        b.resolverData = _batchProof(highProof, 1);
        require(
            IStreamMintPreview(address(manager)).canMint(b, address(this), "").allowed,
            "larger cap has allowance"
        );
        b.resolverData = _batchProof(_proof(3, high), 1);
        IStreamMintPreview.MintPreview memory denied =
            IStreamMintPreview(address(manager)).canMint(b, address(this), "");
        require(
            !denied.allowed && denied.counters[0].current == 4 && denied.counters[0].cap == 3,
            "smaller valid leaf cannot pretend unused allowance"
        );
    }

    function testNoneRemainingIsUint64HeadroomAndStaticMaximumNeverTruncates() public {
        _configure(
            1,
            PHASE,
            IStreamMintManager.CounterKeyMode.RECIPIENT,
            IStreamMintCounterPolicy.CounterScope.PHASE,
            0,
            type(uint64).max - 2,
            0,
            true
        );
        Reads.CounterKeyContext memory c = _context(1, PHASE, 0);
        (Reads.CounterResolution memory r, uint64 current, uint64 remaining) =
            _reads().remainingForResolvedCounter(c);
        require(
            r.effectiveCap == 0 && current == 0 && remaining == type(uint64).max,
            "NONE reports storage headroom"
        );
        manager.executeSingleStepMint(_batch(1, PHASE, 1, 1), "");
        (r, current, remaining) = _reads().remainingForResolvedCounter(c);
        require(
            current == type(uint64).max - 2 && remaining == 2
                && _reads().remainingForCounter(1, PHASE, COUNTER, r.subjectKey) == 2,
            "headroom is not an unlimited mint promise"
        );
        _configure(
            1,
            OTHER_PHASE,
            IStreamMintManager.CounterKeyMode.RECIPIENT,
            IStreamMintCounterPolicy.CounterScope.PHASE,
            type(uint64).max,
            type(uint64).max,
            0,
            false
        );
        manager.executeSingleStepMint(_batch(1, OTHER_PHASE, 1, 2), "");
        c.phaseId = OTHER_PHASE;
        (r, current, remaining) = _reads().remainingForResolvedCounter(c);
        require(
            r.effectiveCap == type(uint64).max && r.increment == type(uint64).max
                && current == type(uint64).max && remaining == 0,
            "exact uint64 boundary"
        );
    }

    function testWrongProofAccountManagerAndPhaseDomainsCannotResolveAllowance() public {
        Reads.CounterKeyContext memory c = _context(1, PHASE, 0);
        bytes32 root = _leaf(address(manager), c, BENEFICIARY, 7);
        _configure(
            1,
            PHASE,
            IStreamMintManager.CounterKeyMode.RECIPIENT,
            IStreamMintCounterPolicy.CounterScope.COLLECTION,
            10,
            2,
            root,
            false
        );
        _configure(
            1,
            OTHER_PHASE,
            IStreamMintManager.CounterKeyMode.RECIPIENT,
            IStreamMintCounterPolicy.CounterScope.COLLECTION,
            10,
            2,
            root,
            false
        );
        c.resolverData = abi.encode(_proof(6, 0));
        _invalidProof(BENEFICIARY);
        _reads().resolveCounter(c);
        c.resolverData = abi.encode(_proof(7, 0));
        require(_reads().resolveCounter(c).effectiveCap == 7, "original proof valid");
        c.beneficiary = CUSTODY;
        _invalidProof(CUSTODY);
        _reads().resolveCounter(c);
        c.beneficiary = BENEFICIARY;
        c.phaseId = OTHER_PHASE;
        _invalidProof(BENEFICIARY);
        _reads().resolveCounter(c);
        bytes32 foreignPhase = keccak256("proof committed to foreign Manager");
        c.phaseId = foreignPhase;
        root = _leaf(OTHER_EXECUTOR, c, BENEFICIARY, 7);
        _configure(
            1,
            foreignPhase,
            IStreamMintManager.CounterKeyMode.RECIPIENT,
            IStreamMintCounterPolicy.CounterScope.PHASE,
            10,
            2,
            root,
            false
        );
        _invalidProof(BENEFICIARY);
        _reads().resolveCounter(c);
        require(
            manager.nextOperationNonce() == 0 && core.minted() == 0, "proof failures never execute"
        );
    }

    function _invalidProof(address account) private {
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamMintCounterPolicy.MintAllowlistProofInvalid.selector, COUNTER, account
            )
        );
    }

    function testContextAndTokenIndexBoundsKeepOriginalPerTokenAndPerBatchIdentity() public {
        _configure(
            1,
            PHASE,
            IStreamMintManager.CounterKeyMode.RECIPIENT,
            IStreamMintCounterPolicy.CounterScope.PHASE,
            12,
            2,
            0,
            false
        );
        Reads.CounterKeyContext memory c = _context(1, PHASE, 9);
        require(_reads().resolveCounter(c).increment == 2, "last original per-token index");
        c.tokenIndex = 10;
        _invalidIndex(c);
        c.tokenIndex = type(uint256).max;
        _invalidIndex(c);
        _configure(
            1,
            OTHER_PHASE,
            IStreamMintManager.CounterKeyMode.CONTEXT,
            IStreamMintCounterPolicy.CounterScope.PHASE,
            12,
            2,
            0,
            false
        );
        c = _context(1, OTHER_PHASE, 0);
        _invalidIndex(c);
        c.tokenIndex = type(uint256).max;
        require(_reads().resolveCounter(c).increment == 2, "original batch sentinel accepted");
        c.contextHash = 0;
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamMintManager.MintCounterSubjectMissing.selector,
                COUNTER,
                IStreamMintManager.CounterKeyMode.CONTEXT
            )
        );
        _reads().resolveCounter(c);
    }

    function _invalidIndex(Reads.CounterKeyContext memory c) private {
        vm.expectRevert(
            abi.encodeWithSelector(
                Reads.MintCounterTokenIndexInvalid.selector, COUNTER, c.tokenIndex
            )
        );
        _reads().resolveCounter(c);
    }

    function testMerkleProofEncodingIsCanonicalAndStaticResolverBytesRemainIgnored() public {
        Reads.CounterKeyContext memory c = _context(1, PHASE, 0);
        _configure(
            1,
            PHASE,
            IStreamMintManager.CounterKeyMode.RECIPIENT,
            IStreamMintCounterPolicy.CounterScope.PHASE,
            10,
            2,
            _leaf(address(manager), c, BENEFICIARY, 7),
            false
        );
        c.resolverData = hex"01";
        vm.expectRevert(); // The original strict ABI decoder rejects truncation before canonicality.
        _reads().resolveCounter(c);
        c.resolverData = bytes.concat(abi.encode(_proof(7, 0)), hex"00");
        vm.expectRevert(
            abi.encodeWithSelector(Reads.MintCounterProofEncodingInvalid.selector, COUNTER)
        );
        _reads().resolveCounter(c);
        c.resolverData = abi.encode(_proof(7, 0));
        require(_reads().resolveCounter(c).effectiveCap == 7, "canonical single proof accepted");
        _configure(
            1,
            OTHER_PHASE,
            IStreamMintManager.CounterKeyMode.RECIPIENT,
            IStreamMintCounterPolicy.CounterScope.PHASE,
            12,
            2,
            0,
            false
        );
        c.phaseId = OTHER_PHASE;
        c.resolverData = hex"01";
        require(
            _reads().resolveCounter(c).effectiveCap == 12,
            "ordinary static route does not decode a proof"
        );
    }

    function testScalarReadsRejectInvalidIdentityUnknownCounterAndZeroSubject() public {
        _configure(
            1,
            PHASE,
            IStreamMintManager.CounterKeyMode.RECIPIENT,
            IStreamMintCounterPolicy.CounterScope.PHASE,
            12,
            2,
            0,
            false
        );
        Reads.CounterKeyContext memory c = _context(1, PHASE, 0);
        bytes32 subject = _reads().resolveCounter(c).subjectKey;
        vm.expectRevert(
            abi.encodeWithSelector(IStreamMintManager.InvalidMintPhase.selector, uint256(0), PHASE)
        );
        _reads().counterValue(0, PHASE, COUNTER, subject);
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamMintManager.InvalidMintPhase.selector, uint256(1), bytes32(0)
            )
        );
        _reads().remainingForCounter(1, 0, COUNTER, subject);
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamMintManager.MintPhaseDoesNotExist.selector, uint256(1), OTHER_PHASE
            )
        );
        _reads().counterValue(1, OTHER_PHASE, COUNTER, subject);
        bytes32 missing = keccak256("unconfigured counter read");
        vm.expectRevert(
            abi.encodeWithSelector(IStreamMintManager.InvalidMintCounter.selector, missing)
        );
        _reads().remainingForCounter(1, PHASE, missing, subject);
        vm.expectRevert(
            abi.encodeWithSelector(IStreamMintManager.InvalidMintCounter.selector, COUNTER)
        );
        _reads().counterValue(1, PHASE, COUNTER, 0);
        c.counterId = missing;
        vm.expectRevert(
            abi.encodeWithSelector(IStreamMintManager.InvalidMintCounter.selector, missing)
        );
        _reads().resolveCounter(c);
        require(
            _reads().rawCounterValue(0) == ledger.counterValue(0),
            "raw view is the exact arbitrary Ledger key read"
        );
    }

    function testReadsDoNotRequireExecutorOrCurrentArtistAuthorizationAndNeverWrite() public {
        _configure(
            1,
            PHASE,
            IStreamMintManager.CounterKeyMode.RECIPIENT,
            IStreamMintCounterPolicy.CounterScope.PHASE,
            12,
            2,
            0,
            false
        );
        manager.setPhaseExecutor(1, PHASE, address(this), false);
        manager.setPhasePaused(1, PHASE, true);
        // Explicit typed Core boundary withdraws its Artist pointer after ordinary configuration.
        core.initialize(address(registry), address(0), address(manager));
        Reads.CounterKeyContext memory c = _context(1, PHASE, 0);
        c.executor = OTHER_EXECUTOR;
        vm.recordLogs();
        vm.prank(OBSERVER);
        (Reads.CounterResolution memory r, uint64 current, uint64 remaining) =
            _reads().remainingForResolvedCounter(c);
        require(
            current == 0 && remaining == 12 && r.increment == 2,
            "accounting reads grant no mint authority"
        );
        require(
            _reads().counterValue(1, PHASE, COUNTER, r.subjectKey) == 0
                && _reads()
                    .rawCounterValue(
                        _key(c, r.subjectKey, IStreamMintCounterPolicy.CounterScope.PHASE)
                    ) == 0,
            "exact read-only key remains empty"
        );
        require(
            vm.getRecordedLogs().length == 0 && manager.nextOperationNonce() == 0
                && core.minted() == 0,
            "no events, reservations or mint effects"
        );
        IStreamMintManager.MintBatch memory b = _batch(1, PHASE, 1, 1);
        IStreamMintPreview.MintPreview memory denied =
            IStreamMintPreview(address(manager)).canMint(b, OTHER_EXECUTOR, "");
        require(
            !denied.allowed && denied.reason == IStreamMintManager.MintPhasePaused.selector,
            "eligibility remains independently denied"
        );
        require(
            manager.supportsInterface(type(Reads).interfaceId)
                && manager.supportsInterface(type(IStreamMintManager).interfaceId),
            "additive reads preserve original interface"
        );
    }

    function testCounterReadCodecReturnsExactStaticWidthsRejectsMalformedContextAndFitsERC165()
        public
    {
        bytes32 definition = _configure(
            1,
            PHASE,
            IStreamMintManager.CounterKeyMode.RECIPIENT,
            IStreamMintCounterPolicy.CounterScope.PHASE,
            7,
            2,
            0,
            false
        );
        manager.executeSingleStepMint(_batch(1, PHASE, 1, 1), "");
        Reads.CounterKeyContext memory c = _context(1, PHASE, 0);
        bytes32 subject = _subject(
            c,
            IStreamMintManager.CounterKeyMode.RECIPIENT,
            IStreamMintCounterPolicy.CounterScope.PHASE
        );
        bytes32 key = _key(c, subject, IStreamMintCounterPolicy.CounterScope.PHASE);
        Reads.CounterResolution memory expected =
            Reads.CounterResolution(subject, 7, 2, _resolution(c, subject, definition));
        vm.recordLogs();
        _encodedRead(abi.encodeCall(Reads.rawCounterValue, (key)), abi.encode(uint64(2)), 32);
        _encodedRead(
            abi.encodeCall(Reads.counterValue, (1, PHASE, COUNTER, subject)),
            abi.encode(uint64(2)),
            32
        );
        _encodedRead(
            abi.encodeCall(Reads.remainingForCounter, (1, PHASE, COUNTER, subject)),
            abi.encode(uint64(5)),
            32
        );
        _encodedRead(abi.encodeCall(Reads.resolveCounter, (c)), abi.encode(expected), 128);
        _encodedRead(
            abi.encodeCall(Reads.remainingForResolvedCounter, (c)),
            abi.encode(expected, uint64(2), uint64(5)),
            192
        );

        bytes memory truncated =
            abi.encodeWithSelector(Reads.resolveCounter.selector, uint256(32), uint256(1));
        (bool ok,) = address(manager).staticcall(truncated);
        require(!ok, "truncated dynamic context cannot reach a valid fixed read");
        bytes memory malformed = abi.encodeCall(Reads.remainingForResolvedCounter, (c));
        // Corrupt only the outer context offset; retain the original declared selector.
        assembly ("memory-safe") { mstore(add(malformed, 36), not(0)) }
        (ok,) = address(manager).staticcall(malformed);
        require(!ok, "out-of-bounds context offset is rejected");
        bytes memory capability;
        (ok, capability) = address(manager).staticcall{ gas: 30_000 }(
            abi.encodeCall(IERC165.supportsInterface, (type(Reads).interfaceId))
        );
        require(
            ok && capability.length == 32 && abi.decode(capability, (uint256)) == 1,
            "new counter reads capability fits individual ERC165 budget"
        );
        require(
            vm.getRecordedLogs().length == 0 && manager.nextOperationNonce() == 1
                && core.minted() == 1 && ledger.counterValue(key) == 2,
            "codec and capability calls preserve prior actual accounting without receipts"
        );
    }

    function testOriginalReplayAndGraceCodecKeepsExactBoundedCallerIndependentReads() public {
        _configure(
            1,
            PHASE,
            IStreamMintManager.CounterKeyMode.RECIPIENT,
            IStreamMintCounterPolicy.CounterScope.PHASE,
            7,
            2,
            0,
            false
        );
        IStreamMintManager.MintBatch memory used = _batch(1, PHASE, 1, 1);
        (, bytes32 usedRoot,) = manager.executeSingleStepMint(used, "");
        bytes32 previous = manager.phasePolicyHash(1, PHASE);
        // setUp fixes time at 1000; keep this expectation stable across vm.warp.
        uint64 until = 1100;
        manager.setPhaseExecutorWithGrace(1, PHASE, OTHER_EXECUTOR, true, until);
        bytes32 current = manager.phasePolicyHash(1, PHASE);
        require(current != previous, "real current policy rotation");
        bytes32 unused = keccak256("unused replay codec identifier");
        vm.recordLogs();
        for (uint256 i; i < 2; ++i) {
            address reader = i == 0 ? OBSERVER : OTHER_EXECUTOR;
            vm.prank(reader);
            _budgetEncodedRead(
                abi.encodeCall(IStreamMintManager.isAuthorizationUsed, (used.authorizationId)),
                abi.encode(true),
                32
            );
            vm.prank(reader);
            _budgetEncodedRead(
                abi.encodeCall(IStreamMintManager.isOperationRootUsed, (usedRoot)),
                abi.encode(true),
                32
            );
            vm.prank(reader);
            _budgetEncodedRead(
                abi.encodeCall(IStreamMintManager.isAuthorizationUsed, (unused)),
                abi.encode(false),
                32
            );
            vm.prank(reader);
            _budgetEncodedRead(
                abi.encodeCall(IStreamMintManager.isOperationRootUsed, (unused)),
                abi.encode(false),
                32
            );
            // The used authorization bytes are still unused in the separate nullifier namespace.
            vm.prank(reader);
            _budgetEncodedRead(
                abi.encodeCall(IStreamMintManager.isNullifierUsed, (used.authorizationId)),
                abi.encode(false),
                32
            );
            vm.prank(reader);
            _budgetEncodedRead(
                abi.encodeCall(IStreamMintManager.phasePolicyGrace, (1, PHASE)),
                abi.encode(previous, until),
                64
            );
        }
        require(
            !ledger.isManagerAuthorizationUsed(OBSERVER, used.authorizationId)
                && !ledger.isManagerOperationRootUsed(OTHER_EXECUTOR, usedRoot),
            "true Manager answers never switch to the observer Ledger scope"
        );
        IStreamMintManager.MintBatch memory fresh = _batch(1, PHASE, 1, 2);
        fresh.expectedPolicyHash = previous;
        vm.warp(until);
        _budgetEncodedRead(
            abi.encodeCall(IStreamMintManager.phasePolicyGrace, (1, PHASE)),
            abi.encode(previous, until),
            64
        );
        IStreamMintPreview.MintPreview memory accepted =
            IStreamMintPreview(address(manager)).canMint(fresh, address(this), "");
        require(
            accepted.allowed && accepted.policyHash == current,
            "exact inclusive predecessor deadline"
        );
        vm.warp(uint256(until) + 1);
        _budgetEncodedRead(
            abi.encodeCall(IStreamMintManager.phasePolicyGrace, (1, PHASE)),
            abi.encode(previous, until),
            64
        );
        IStreamMintPreview.MintPreview memory expired =
            IStreamMintPreview(address(manager)).canMint(fresh, address(this), "");
        require(
            !expired.allowed
                && expired.reason == IStreamMintManager.MintPolicyHashMismatch.selector,
            "historical tuple remains exact while original grace acceptance expires"
        );
        require(
            vm.getRecordedLogs().length == 0 && manager.nextOperationNonce() == 1
                && core.minted() == 1 && !manager.isAuthorizationUsed(fresh.authorizationId),
            "bounded codec reads create no new effects"
        );
    }

    function _budgetEncodedRead(bytes memory payload, bytes memory expected, uint256 width)
        private
        view
    {
        (bool ok, bytes memory raw) = address(manager).staticcall{ gas: 30_000 }(payload);
        require(
            ok && raw.length == width && expected.length == width
                && keccak256(raw) == keccak256(expected),
            "exact original replay/grace ABI within 30k gas"
        );
    }

    function _encodedRead(bytes memory payload, bytes memory expected, uint256 width) private view {
        (bool ok, bytes memory raw) = address(manager).staticcall(payload);
        require(
            ok && raw.length == width && expected.length == width
                && keccak256(raw) == keccak256(expected),
            "exact original caller-facing static ABI"
        );
    }
}
