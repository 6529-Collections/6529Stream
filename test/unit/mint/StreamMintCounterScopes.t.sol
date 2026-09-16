// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../../helpers/MintEngineTestBase.sol";
import "../../../smart-contracts/domains/mint/StreamMintCounterPolicy.sol";

/// @dev Actual Manager/Ledger/Registry; Core, artist and governance admission use declared typed fixtures.
contract StreamMintCounterScopesTest is MintEngineTestBase {
    bytes32 private constant COUNTER = keccak256("shared-counter");
    bytes32 private constant A = keccak256("phase-a");
    bytes32 private constant B = keccak256("phase-b");
    uint256 private nonce;

    function _definition(
        IStreamMintCounterPolicy.CounterScope scope,
        IStreamMintManager.CounterKeyMode key,
        bytes32 root
    ) private returns (bytes32) {
        return ledger.registerCounterDefinition(
            IStreamMintCounterPolicy.Definition(scope, key, root, keccak256("published metadata"))
        );
    }

    function _phase(
        uint256 collection,
        bytes32 phase,
        bytes32 hash,
        IStreamMintManager.CounterKeyMode key,
        IStreamMintLedger.CounterCapMode mode,
        uint64 cap
    ) private {
        bytes32[] memory ids = new bytes32[](1);
        ids[0] = COUNTER;
        IStreamMintManager.MintCounterConfig[] memory configs =
            new IStreamMintManager.MintCounterConfig[](1);
        configs[0] = IStreamMintManager.MintCounterConfig(
            true, key, mode, IStreamMintLedger.CounterDeltaMode.STATIC, cap, 1, hash
        );
        IStreamMintManager.MintGateConfig memory gate;
        manager.configurePhase(
            collection,
            phase,
            IStreamMintManager.MintPhaseConfig(
                false,
                0,
                0,
                10,
                keccak256("published allowlist artifact"),
                keccak256("phase metadata")
            ),
            gate,
            ids,
            configs
        );
        manager.setPhaseExecutor(collection, phase, address(this), true);
    }

    function _request(uint256 collection, bytes32 phase, address recipient, uint256 quantity)
        private
        returns (IStreamMintManager.MintBatch memory b)
    {
        b = _batch(bytes32(++nonce));
        b.collectionId = collection;
        b.phaseId = phase;
        b.expectedPolicyHash = manager.phasePolicyHash(collection, phase);
        b.initialRecipients = new address[](quantity);
        b.beneficiaries = new address[](quantity);
        b.tokenData = new bytes[](quantity);
        b.mintCommitments = new bytes32[](quantity);
        for (uint256 i; i < quantity; ++i) {
            b.initialRecipients[i] = recipient;
            b.beneficiaries[i] = recipient;
        }
    }

    function _value(
        uint256 collection,
        bytes32 phase,
        IStreamMintManager.CounterKeyMode key,
        address recipient
    ) private view returns (uint64) {
        return ledger.counterValue(_valueKey(collection, phase, key, recipient));
    }

    function _valueKey(
        uint256 collection,
        bytes32 phase,
        IStreamMintManager.CounterKeyMode key,
        address recipient
    ) private view returns (bytes32) {
        bytes32 subject = manager.previewSubjectKey(
            key,
            collection,
            phase,
            COUNTER,
            signer,
            recipient,
            address(this),
            address(0),
            keccak256("context")
        );
        return manager.previewCounterValueKey(collection, phase, COUNTER, subject);
    }

    function testCollectionRecipientCapSharedAcrossPhases() public {
        bytes32 hash = _definition(
            IStreamMintCounterPolicy.CounterScope.COLLECTION,
            IStreamMintManager.CounterKeyMode.RECIPIENT,
            0
        );
        _phase(
            1,
            A,
            hash,
            IStreamMintManager.CounterKeyMode.RECIPIENT,
            IStreamMintLedger.CounterCapMode.STATIC,
            2
        );
        _phase(
            1,
            B,
            hash,
            IStreamMintManager.CounterKeyMode.RECIPIENT,
            IStreamMintLedger.CounterCapMode.STATIC,
            2
        );
        manager.executeSingleStepMint(_request(1, A, signer, 1), "");
        manager.executeSingleStepMint(_request(1, B, signer, 1), "");
        require(
            _value(1, A, IStreamMintManager.CounterKeyMode.RECIPIENT, signer) == 2, "shared value"
        );
        IStreamMintManager.MintBatch memory b = _request(1, B, signer, 1);
        vm.expectRevert();
        manager.executeSingleStepMint(b, "");
        require(
            core.minted() == 2 && !manager.isAuthorizationUsed(b.authorizationId),
            "atomic cap failure"
        );
    }

    function testGlobalConstantCapSharedAcrossCollectionsAndPhases() public {
        bytes32 hash = _definition(
            IStreamMintCounterPolicy.CounterScope.GLOBAL,
            IStreamMintManager.CounterKeyMode.CONSTANT,
            0
        );
        _phase(
            1,
            A,
            hash,
            IStreamMintManager.CounterKeyMode.CONSTANT,
            IStreamMintLedger.CounterCapMode.STATIC,
            2
        );
        _phase(
            2,
            B,
            hash,
            IStreamMintManager.CounterKeyMode.CONSTANT,
            IStreamMintLedger.CounterCapMode.STATIC,
            2
        );
        manager.executeSingleStepMint(_request(1, A, signer, 1), "");
        manager.executeSingleStepMint(_request(2, B, address(0xBEEF), 1), "");
        bytes32 subject = keccak256(
            abi.encode(
                manager.SUBJECT_DOMAIN(),
                block.chainid,
                address(ledger),
                IStreamMintManager.CounterKeyMode.CONSTANT,
                uint256(0),
                bytes32(0),
                COUNTER
            )
        );
        bytes32 key = keccak256(
            abi.encode(
                ledger.VALUE_KEY_DOMAIN(),
                address(manager),
                uint256(0),
                bytes32(0),
                COUNTER,
                subject
            )
        );
        require(
            ledger.counterValue(key) == 2
                && _value(2, B, IStreamMintManager.CounterKeyMode.CONSTANT, signer) == 2,
            "reserved-domain key"
        );
        IStreamMintManager.MintBatch memory b = _request(1, A, signer, 1);
        vm.expectRevert();
        manager.executeSingleStepMint(b, "");
    }

    function testPhaseCountersRemainIndependent() public {
        bytes32 hash = _definition(
            IStreamMintCounterPolicy.CounterScope.PHASE, IStreamMintManager.CounterKeyMode.PAYER, 0
        );
        _phase(
            1,
            A,
            hash,
            IStreamMintManager.CounterKeyMode.PAYER,
            IStreamMintLedger.CounterCapMode.STATIC,
            1
        );
        _phase(
            1,
            B,
            hash,
            IStreamMintManager.CounterKeyMode.PAYER,
            IStreamMintLedger.CounterCapMode.STATIC,
            1
        );
        manager.executeSingleStepMint(_request(1, A, signer, 1), "");
        manager.executeSingleStepMint(_request(1, B, signer, 1), "");
        require(_value(1, A, IStreamMintManager.CounterKeyMode.PAYER, signer) == 1, "phase a");
        require(_value(1, B, IStreamMintManager.CounterKeyMode.PAYER, signer) == 1, "phase b");
    }

    function testLateDefinitionCannotReinterpretLegacyAcrossPhaseRefresh() public {
        IStreamMintCounterPolicy.Definition memory d = IStreamMintCounterPolicy.Definition(
            IStreamMintCounterPolicy.CounterScope.GLOBAL,
            IStreamMintManager.CounterKeyMode.CONSTANT,
            0,
            keccak256("late")
        );
        bytes32 hash = StreamMintCounterPolicy.definitionHash(d);
        _phase(1, A, hash, d.keyMode, IStreamMintLedger.CounterCapMode.STATIC, 1);
        manager.executeSingleStepMint(_request(1, A, signer, 1), "");
        ledger.registerCounterDefinition(d);
        manager.setPhaseExecutor(1, A, address(0xEE), true);
        _phase(2, B, hash, d.keyMode, IStreamMintLedger.CounterCapMode.STATIC, 1);
        manager.executeSingleStepMint(_request(2, B, signer, 1), "");
        (bool interpreted,) = ledger.counterDefinitionForManager(address(manager), hash);
        require(
            !interpreted && _value(1, A, d.keyMode, signer) == 1
                && _value(2, B, d.keyMode, signer) == 1,
            "legacy pin immutable"
        );
    }

    function _proof(uint64 cap)
        private
        pure
        returns (IStreamMintCounterPolicy.AllowlistProof memory p)
    {
        p.maxCount = cap;
        p.proof = new bytes32[](0);
    }

    function _withProof(
        IStreamMintManager.MintBatch memory b,
        IStreamMintCounterPolicy.AllowlistProof memory p,
        bool payer
    ) private pure returns (IStreamMintManager.MintBatch memory) {
        IStreamMintCounterPolicy.AllowlistProof[][] memory all =
            new IStreamMintCounterPolicy.AllowlistProof[][](1);
        all[0] = new IStreamMintCounterPolicy.AllowlistProof[](payer ? 1 : b.beneficiaries.length);
        for (uint256 i; i < all[0].length; ++i) {
            all[0][i] = p;
        }
        b.resolverData = abi.encode(all);
        return b;
    }

    function _configureMerkleProof(IStreamMintCounterPolicy.AllowlistProof memory p) private {
        bytes32 root =
            StreamMintCounterPolicy.allowlistLeaf(address(manager), 1, A, COUNTER, signer, p);
        bytes32 hash = _definition(
            IStreamMintCounterPolicy.CounterScope.PHASE,
            IStreamMintManager.CounterKeyMode.RECIPIENT,
            root
        );
        _phase(
            1,
            A,
            hash,
            IStreamMintManager.CounterKeyMode.RECIPIENT,
            IStreamMintLedger.CounterCapMode.MERKLE_STATIC,
            p.maxCount
        );
    }

    function testMerkleInconsistentPricePayloadUnsupported() public {
        IStreamMintCounterPolicy.AllowlistProof memory p = _proof(1);
        p.priceOverride = 1;
        _configureMerkleProof(p);
        IStreamMintManager.MintBatch memory b = _withProof(_request(1, A, signer, 1), p, false);
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamMintCounterPolicy.MintAllowlistPriceOverrideUnsupported.selector,
                COUNTER,
                signer,
                false,
                uint256(1)
            )
        );
        manager.executeSingleStepMint(b, "");
        require(
            core.minted() == 0 && manager.nextOperationNonce() == 0
                && !manager.isAuthorizationUsed(b.authorizationId)
                && _value(1, A, IStreamMintManager.CounterKeyMode.RECIPIENT, signer) == 0,
            "inconsistent price proof wrote state"
        );
    }

    function _assertAuthenticatedPricePreservesAccounting(uint256 price) private {
        IStreamMintCounterPolicy.AllowlistProof memory p = _proof(2);
        p.hasPriceOverride = true;
        p.priceOverride = price;
        _configureMerkleProof(p);
        IStreamMintManager.MintBatch memory first = _withProof(_request(1, A, signer, 1), p, false);
        (bytes32 root,) = manager.previewSingleStepMintOperation(first, "");
        manager.executeSingleStepMint(first, "");
        require(
            core.minted() == 1 && manager.nextOperationNonce() == 1
                && manager.isAuthorizationUsed(first.authorizationId)
                && manager.isOperationRootUsed(root)
                && _value(1, A, IStreamMintManager.CounterKeyMode.RECIPIENT, signer) == 1,
            "authenticated price changed accounting"
        );
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamMintLedger.AuthorizationAlreadyConsumed.selector, first.authorizationId
            )
        );
        manager.executeSingleStepMint(first, "");
        require(core.minted() == 1 && manager.nextOperationNonce() == 1, "price bypassed replay");

        manager.executeSingleStepMint(_withProof(_request(1, A, signer, 1), p, false), "");
        IStreamMintManager.MintBatch memory over = _withProof(_request(1, A, signer, 1), p, false);
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamMintLedger.CounterCapExceeded.selector,
                _valueKey(1, A, IStreamMintManager.CounterKeyMode.RECIPIENT, signer),
                uint256(3),
                uint256(2)
            )
        );
        manager.executeSingleStepMint(over, "");
        require(
            core.minted() == 2 && manager.nextOperationNonce() == 2
                && !manager.isAuthorizationUsed(over.authorizationId)
                && _value(1, A, IStreamMintManager.CounterKeyMode.RECIPIENT, signer) == 2,
            "price bypassed leaf cap"
        );
    }

    function testMerkleAuthenticatedZeroPricePreservesAccountingAndReplay() public {
        _assertAuthenticatedPricePreservesAccounting(0);
    }

    function testMerkleAuthenticatedNonzeroPricePreservesAccountingAndReplay() public {
        _assertAuthenticatedPricePreservesAccounting(17);
    }

    function testMerkleAuthenticatedFullWidthPricePreservesAccountingAndReplay() public {
        _assertAuthenticatedPricePreservesAccounting(type(uint256).max);
    }

    function testMerklePriceAndEnabledFlagTamperingRejectBeforeWrites() public {
        IStreamMintCounterPolicy.AllowlistProof memory p = _proof(1);
        p.hasPriceOverride = true;
        p.priceOverride = 17;
        _configureMerkleProof(p);
        IStreamMintManager.MintBatch memory b = _request(1, A, signer, 1);
        p.priceOverride = 18;
        b = _withProof(b, p, false);
        _assertTamperedPriceProofRejected(b);
        p.hasPriceOverride = false;
        p.priceOverride = 0;
        b = _withProof(b, p, false);
        _assertTamperedPriceProofRejected(b);

        p.hasPriceOverride = true;
        p.priceOverride = 17;
        b = _withProof(b, p, false);
        manager.executeSingleStepMint(b, "");
        require(
            core.minted() == 1 && manager.isAuthorizationUsed(b.authorizationId),
            "valid proof retry"
        );
    }

    function _assertTamperedPriceProofRejected(IStreamMintManager.MintBatch memory b) private {
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamMintCounterPolicy.MintAllowlistProofInvalid.selector, COUNTER, signer
            )
        );
        manager.executeSingleStepMint(b, "");
        require(
            core.minted() == 0 && manager.nextOperationNonce() == 0
                && !manager.isAuthorizationUsed(b.authorizationId)
                && _value(1, A, IStreamMintManager.CounterKeyMode.RECIPIENT, signer) == 0,
            "tampered price proof wrote state"
        );
    }

    function testMerkleDifferentiatedCapsAndIndependentSubjectConsumption() public {
        IStreamMintCounterPolicy.AllowlistProof memory p = _proof(1);
        IStreamMintCounterPolicy.AllowlistProof memory q = _proof(3);
        address other = address(0xBEEF);
        bytes32 left =
            StreamMintCounterPolicy.allowlistLeaf(address(manager), 1, A, COUNTER, signer, p);
        bytes32 right =
            StreamMintCounterPolicy.allowlistLeaf(address(manager), 1, A, COUNTER, other, q);
        bytes32 root =
            left < right ? keccak256(abi.encode(left, right)) : keccak256(abi.encode(right, left));
        p.proof = new bytes32[](1);
        p.proof[0] = right;
        q.proof = new bytes32[](1);
        q.proof[0] = left;
        bytes32 hash = _definition(
            IStreamMintCounterPolicy.CounterScope.PHASE,
            IStreamMintManager.CounterKeyMode.RECIPIENT,
            root
        );
        _phase(
            1,
            A,
            hash,
            IStreamMintManager.CounterKeyMode.RECIPIENT,
            IStreamMintLedger.CounterCapMode.MERKLE_STATIC,
            3
        );
        manager.executeSingleStepMint(_withProof(_request(1, A, signer, 1), p, false), "");
        manager.executeSingleStepMint(_withProof(_request(1, A, other, 3), q, false), "");
        IStreamMintManager.MintBatch memory b = _withProof(_request(1, A, signer, 1), p, false);
        vm.expectRevert();
        manager.executeSingleStepMint(b, "");
        require(
            core.minted() == 4
                && _value(1, A, IStreamMintManager.CounterKeyMode.RECIPIENT, other) == 3,
            "leaf caps consumed"
        );
    }

    function testMerkleDuplicateRecipientBatchCannotExceedLeafCap() public {
        IStreamMintCounterPolicy.AllowlistProof memory p = _proof(1);
        bytes32 root =
            StreamMintCounterPolicy.allowlistLeaf(address(manager), 1, A, COUNTER, signer, p);
        bytes32 hash = _definition(
            IStreamMintCounterPolicy.CounterScope.PHASE,
            IStreamMintManager.CounterKeyMode.RECIPIENT,
            root
        );
        _phase(
            1,
            A,
            hash,
            IStreamMintManager.CounterKeyMode.RECIPIENT,
            IStreamMintLedger.CounterCapMode.MERKLE_STATIC,
            5
        );
        IStreamMintManager.MintBatch memory b = _withProof(_request(1, A, signer, 2), p, false);
        vm.expectRevert();
        manager.executeSingleStepMint(b, "");
        require(
            core.minted() == 0 && manager.nextOperationNonce() == 0
                && !manager.isAuthorizationUsed(b.authorizationId),
            "rollback all"
        );
    }

    function testMerklePayerProofAndPayloadTampering() public {
        IStreamMintCounterPolicy.AllowlistProof memory p = _proof(2);
        bytes32 root =
            StreamMintCounterPolicy.allowlistLeaf(address(manager), 1, A, COUNTER, signer, p);
        bytes32 hash = _definition(
            IStreamMintCounterPolicy.CounterScope.PHASE,
            IStreamMintManager.CounterKeyMode.PAYER,
            root
        );
        _phase(
            1,
            A,
            hash,
            IStreamMintManager.CounterKeyMode.PAYER,
            IStreamMintLedger.CounterCapMode.MERKLE_STATIC,
            2
        );
        IStreamMintManager.MintBatch memory b =
            _withProof(_request(1, A, address(0xBEEF), 2), p, true);
        b.payer = address(0xBAD);
        vm.expectRevert();
        manager.executeSingleStepMint(b, "");
        b.payer = signer;
        p.priceOverride = 1;
        b = _withProof(b, p, true);
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamMintCounterPolicy.MintAllowlistPriceOverrideUnsupported.selector,
                COUNTER,
                signer,
                false,
                uint256(1)
            )
        );
        manager.executeSingleStepMint(b, "");
        p.priceOverride = 0;
        b = _withProof(b, p, true);
        manager.executeSingleStepMint(b, "");
        require(core.minted() == 2, "one payer proof counts every token");
        vm.expectRevert();
        manager.executeSingleStepMint(b, "");
    }

    function testMerkleWrongPhaseAndCeilingRejected() public {
        IStreamMintCounterPolicy.AllowlistProof memory p = _proof(3);
        bytes32 root =
            StreamMintCounterPolicy.allowlistLeaf(address(manager), 1, A, COUNTER, signer, p);
        bytes32 hash = _definition(
            IStreamMintCounterPolicy.CounterScope.COLLECTION,
            IStreamMintManager.CounterKeyMode.RECIPIENT,
            root
        );
        _phase(
            1,
            A,
            hash,
            IStreamMintManager.CounterKeyMode.RECIPIENT,
            IStreamMintLedger.CounterCapMode.MERKLE_STATIC,
            2
        );
        _phase(
            1,
            B,
            hash,
            IStreamMintManager.CounterKeyMode.RECIPIENT,
            IStreamMintLedger.CounterCapMode.MERKLE_STATIC,
            3
        );
        IStreamMintManager.MintBatch memory b = _withProof(_request(1, A, signer, 1), p, false);
        vm.expectRevert();
        manager.executeSingleStepMint(b, "");
        b = _withProof(_request(1, B, signer, 1), p, false);
        vm.expectRevert();
        manager.executeSingleStepMint(b, "");
    }

    function testInvalidDefinitionModesAndReservedRealScopeRejected() public {
        IStreamMintCounterPolicy.Definition memory d = IStreamMintCounterPolicy.Definition(
            IStreamMintCounterPolicy.CounterScope.GLOBAL,
            IStreamMintManager.CounterKeyMode.PAYER,
            bytes32(uint256(1)),
            0
        );
        vm.expectRevert();
        ledger.registerCounterDefinition(d);
        bytes32 hash = _definition(
            IStreamMintCounterPolicy.CounterScope.PHASE,
            IStreamMintManager.CounterKeyMode.RECIPIENT,
            0
        );
        vm.expectRevert();
        this.configureCandidate(
            0,
            A,
            hash,
            IStreamMintManager.CounterKeyMode.RECIPIENT,
            IStreamMintLedger.CounterCapMode.STATIC,
            1
        );
        vm.expectRevert();
        this.configureCandidate(
            1,
            0,
            hash,
            IStreamMintManager.CounterKeyMode.RECIPIENT,
            IStreamMintLedger.CounterCapMode.STATIC,
            1
        );
        vm.expectRevert();
        this.configureCandidate(
            1,
            A,
            hash,
            IStreamMintManager.CounterKeyMode.PAYER,
            IStreamMintLedger.CounterCapMode.STATIC,
            1
        );
        vm.expectRevert();
        this.configureCandidate(
            1,
            A,
            hash,
            IStreamMintManager.CounterKeyMode.RECIPIENT,
            IStreamMintLedger.CounterCapMode.NONE,
            0
        );
    }

    function configureCandidate(
        uint256 collection,
        bytes32 phase,
        bytes32 hash,
        IStreamMintManager.CounterKeyMode key,
        IStreamMintLedger.CounterCapMode mode,
        uint64 cap
    ) external {
        _phase(collection, phase, hash, key, mode, cap);
    }
}
