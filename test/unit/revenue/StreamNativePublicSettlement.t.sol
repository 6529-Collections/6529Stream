// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../../helpers/NativeCuratedCommerceConservationFixture.sol";
import "../../../smart-contracts/interfaces/stream/revenue/IStreamNativePublicSaleBinding.sol";
import "../../../smart-contracts/interfaces/stream/revenue/IStreamNativePublicPrimarySaleSettlement.sol";
import "../../../smart-contracts/domains/revenue/StreamPrimarySaleFloorCall.sol";

/// @dev Typed public-adapter boundary only. It supplies the precise recorder-facing witness,
/// with explicit malformed/read-drift modes; it is not the production sale authorization layer.
contract PublicRecorderSaleBoundary is IStreamNativeSaleBinding, IStreamNativePublicSaleBinding {
    address public immutable override core;
    address public immutable override mintManager;
    address public immutable override primarySaleSettlement;
    address public immutable moduleRegistry;
    address public immutable revenueResolver;
    address public immutable observedWallet;
    bytes32 public immutable phase;
    bytes32 public constant SALE = keccak256("public recorder fixture sale");
    bytes32 public constant CONFIG = keccak256("public recorder fixture configuration");
    StreamNativeSettlementTypes.SaleLifecycleBinding private _lifecycle;
    bytes32 private _activeId;
    bytes32 private _activeCommitment;
    uint256 public fault;

    constructor(
        address core_,
        address manager_,
        address recorder_,
        address registry_,
        address resolver_,
        address wallet_,
        bytes32 phase_
    ) {
        core = core_;
        mintManager = manager_;
        primarySaleSettlement = recorder_;
        moduleRegistry = registry_;
        revenueResolver = resolver_;
        observedWallet = wallet_;
        phase = phase_;
    }

    function supportsInterface(bytes4 id) external pure returns (bool) {
        return id == 0x01ffc9a7 || id == type(IStreamNativeSaleBinding).interfaceId
            || id == type(IStreamNativePublicSaleBinding).interfaceId;
    }

    function initializeLifecycle() external {
        require(_lifecycle.saleCreatedAt == 0, "once");
        _lifecycle = StreamNativeSettlementAdmission.capture(moduleRegistry, address(this));
    }

    function setFault(uint256 mode) external {
        fault = mode;
    }

    function nativeSaleLifecycleBinding(bytes32 id)
        external
        view
        override
        returns (StreamNativeSettlementTypes.SaleLifecycleBinding memory)
    {
        require(id == SALE, "original sale");
        return _lifecycle;
    }

    function publicNativeSaleBinding(bytes32 id)
        external
        view
        override
        returns (uint256, bytes32, bytes32, uint8)
    {
        require(id == SALE, "original public sale");
        if (fault == 3) {
            assembly ("memory-safe") {
                mstore(0, 1)
                return(0, 32)
            }
        }
        if (fault == 4) {
            assembly ("memory-safe") {
                let ptr := mload(0x40)
                mstore(ptr, 1)
                mstore(add(ptr, 32), 1)
                mstore(add(ptr, 64), 1)
                mstore(add(ptr, 96), 258)
                return(ptr, 128)
            }
        }
        bytes32 config = fault == 5 ? bytes32(0) : CONFIG;
        if (fault == 8 && observedWallet.balance != 0) config = keccak256("changed after funding");
        return (fault == 6 ? 2 : 1, fault == 7 ? bytes32(0) : phase, config, 2);
    }

    function activePublicNativeCandidate(bytes32 id) external view override returns (bytes32) {
        if (fault == 2) {
            assembly ("memory-safe") {
                mstore(0, 1)
                mstore(32, 2)
                return(0, 64)
            }
        }
        if (fault == 1 || (fault == 9 && observedWallet.balance != 0)) return 0;
        return id == _activeId ? _activeCommitment : bytes32(0);
    }

    function preview(IStreamMintManager.MintBatch calldata batch)
        external
        view
        returns (bytes32 root, bytes32[] memory ids)
    {
        return IStreamMintManager(mintManager).previewSingleStepMintOperation(batch, "");
    }

    function settle(
        StreamNativeSettlementTypes.NativeSettlementCandidate calldata candidate,
        bool signedEntry
    ) external payable returns (StreamPrimarySettlementTypes.PrimarySettlementResult memory) {
        return _settle(candidate, signedEntry);
    }

    function settleAndMint(
        StreamNativeSettlementTypes.NativeSettlementCandidate calldata candidate,
        IStreamMintManager.MintBatch calldata batch
    )
        external
        payable
        returns (StreamPrimarySettlementTypes.PrimarySettlementResult memory result)
    {
        result = _settle(candidate, false);
        (uint256[] memory tokens, bytes32 root, bytes32[] memory operations) =
            IStreamMintManager(mintManager).executeSingleStepMint(batch, "");
        require(
            tokens.length == 1 && operations.length == 1
                && root == candidate.operationIdentityCommitment
                && operations[0] == candidate.operationId,
            "actual mint matches recorded preview"
        );
    }

    function _settle(
        StreamNativeSettlementTypes.NativeSettlementCandidate calldata candidate,
        bool signedEntry
    ) private returns (StreamPrimarySettlementTypes.PrimarySettlementResult memory result) {
        require(_activeId == 0, "fixture execution lock");
        _activeId = candidate.executionBinding.executionId;
        _activeCommitment =
            StreamNativeSettlementHash.candidateCommitment(primarySaleSettlement, candidate);
        if (signedEntry) {
            result = IStreamNativePrimarySaleSettlement(primarySaleSettlement)
            .settleNativePrimarySaleFromAdapter{ value: msg.value }(
                candidate
            );
        } else {
            result = IStreamNativePublicPrimarySaleSettlement(primarySaleSettlement)
            .settleNativePublicPrimarySaleFromAdapter{ value: msg.value }(
                candidate
            );
        }
        delete _activeId;
        delete _activeCommitment;
    }
}

    /// @notice Actual recorder/native funding, Core, Manager, Ledger and permanent floor.
    /// @dev The inherited governance/Artist/entropy/Metadata boundaries are explicit typed fixtures.
    /// The sale boundary tests recorder authentication; production sale signatures are separate tests.
    contract StreamNativePublicSettlementTest is NativeCuratedCommerceConservationFixture {
        PublicRecorderSaleBoundary private publicSale;

        function setUp() public override {
            super.setUp();
            publicSale = new PublicRecorderSaleBoundary(
                address(core),
                address(manager),
                address(recorder),
                address(registry),
                address(resolver),
                wallet,
                PHASE
            );
            _register(
                address(publicSale),
                keccak256("NATIVE_PRIMARY_SALE_ADAPTER"),
                type(IStreamNativeSaleBinding).interfaceId,
                keccak256("6529STREAM_UNIVERSAL_SETTLEMENT_V1")
            );
            publicSale.initializeLifecycle();
            manager.setPhaseExecutor(1, PHASE, address(publicSale), true);
            vm.deal(address(this), 10000);
        }

        function testPublicNativeRecordsOriginalResultFloorAndActualMintOnce() public {
            _enableNativeCommerceFloor();
            (
                IStreamMintManager.MintBatch memory batch,
                StreamNativeSettlementTypes.NativeSettlementCandidate memory candidate
            ) = _request();
            vm.recordLogs();
            StreamPrimarySettlementTypes.PrimarySettlementResult memory result =
                publicSale.settleAndMint{ value: 1000 }(candidate, batch);
            _success(candidate, batch, result);
            uint256 revenueEvents;
            Vm.Log[] memory logs = vm.getRecordedLogs();
            bytes32 topic = keccak256(
                "PrimaryRevenueExecutionBound(bytes32,address,bytes32,uint16,address,address,bytes32,bytes32,bytes32)"
            );
            for (uint256 i; i < logs.length; ++i) {
                if (logs[i].emitter != address(recorder) || logs[i].topics[0] != topic) continue;
                ++revenueEvents;
                require(
                    logs[i].topics.length == 4 && logs[i].topics[1] == result.settlementKey
                        && logs[i].topics[2] == bytes32(uint256(uint160(address(publicSale))))
                        && logs[i].topics[3] == candidate.executionBinding.executionId
                        && keccak256(logs[i].data)
                            == keccak256(
                                abi.encode(
                                    uint16(1),
                                    payer,
                                    address(0),
                                    result.candidateCommitment,
                                    candidate.currentPolicyHash,
                                    candidate.boundPolicyHash
                                )
                            ),
                    "original exact recorder event"
                );
            }
            require(revenueEvents == 1, "one original official receipt");
            vm.expectRevert(
                abi.encodeWithSelector(
                    IStreamPrimarySaleSettlement.SettlementAlreadyConsumed.selector,
                    result.settlementKey
                )
            );
            publicSale.settle{ value: 1000 }(candidate, false);
            require(
                wallet.balance == 1000 && recorder.totalOfficialSettled(address(0)) == 1000,
                "replay cannot fund twice"
            );
            require(
                recorder.supportsInterface(
                    type(IStreamNativePublicPrimarySaleSettlement).interfaceId
                )
                && recorder.supportsInterface(type(IStreamNativePrimarySaleSettlement).interfaceId)
                && recorder.supportsInterface(type(IStreamPrimarySaleSettlement).interfaceId),
                "additive interface only"
            );
        }

        function testPublicAndOriginalSignedEntryRejectOppositeAuthorityAndSyntheticDigest()
            public
        {
            for (uint256 i; i < 3; ++i) {
                (
                    IStreamMintManager.MintBatch memory batch,
                    StreamNativeSettlementTypes.NativeSettlementCandidate memory candidate
                ) = _request();
                if (i == 1) candidate.executionBinding.authorityMode = 1;
                if (i != 0) {
                    candidate.executionBinding.saleAuthorizationDigest =
                        keccak256("synthetic seller proof");
                }
                candidate.executionBinding.executionId =
                    StreamNativeSettlementHash.executionId(candidate);
                vm.expectRevert(
                    abi.encodeWithSelector(IStreamPrimarySaleSettlement.InvalidPrimarySale.selector)
                );
                publicSale.settle{ value: 1000 }(candidate, i == 0);
                _unchanged(candidate, batch);
            }
        }

        function testPublicRequiresActualAdapterCallerAndNonzeroOriginalMintIdentities() public {
            (
                IStreamMintManager.MintBatch memory batch,
                StreamNativeSettlementTypes.NativeSettlementCandidate memory candidate
            ) = _request();
            vm.expectRevert(
                abi.encodeWithSelector(IStreamPrimarySaleSettlement.InvalidPrimarySale.selector)
            );
            recorder.settleNativePublicPrimarySaleFromAdapter{ value: 1000 }(candidate);
            _unchanged(candidate, batch);
            for (uint256 i; i < 2; ++i) {
                (, candidate) = _request();
                if (i == 0) candidate.operationIdentityCommitment = 0;
                else candidate.operationId = 0;
                candidate.executionBinding.executionId =
                    StreamNativeSettlementHash.executionId(candidate);
                vm.expectRevert(
                    abi.encodeWithSelector(IStreamPrimarySaleSettlement.InvalidPrimarySale.selector)
                );
                publicSale.settle{ value: 1000 }(candidate, false);
                _unchanged(candidate, batch);
            }
        }

        function testPublicRejectsMissingOrMalformedActiveCandidateAndRecord() public {
            (
                IStreamMintManager.MintBatch memory batch,
                StreamNativeSettlementTypes.NativeSettlementCandidate memory candidate
            ) = _request();
            for (uint256 i = 1; i <= 7; ++i) {
                publicSale.setFault(i);
                if (i == 2 || i == 3) {
                    vm.expectRevert(
                        abi.encodeWithSelector(
                            StreamPrimarySettlementValidation.SettlementReadFailed.selector,
                            address(publicSale),
                            i == 2
                                ? IStreamNativePublicSaleBinding.activePublicNativeCandidate
                                .selector
                                : IStreamNativePublicSaleBinding.publicNativeSaleBinding.selector
                        )
                    );
                } else {
                    vm.expectRevert(
                        abi.encodeWithSelector(
                            IStreamPrimarySaleSettlement.InvalidPrimarySale.selector
                        )
                    );
                }
                publicSale.settle{ value: 1000 }(candidate, false);
                _unchanged(candidate, batch);
            }
        }

        function testPostFundingPublicWitnessChangeRollsBackThenExactCandidateMints() public {
            _enableNativeCommerceFloor();
            (
                IStreamMintManager.MintBatch memory batch,
                StreamNativeSettlementTypes.NativeSettlementCandidate memory candidate
            ) = _request();
            for (uint256 i = 8; i <= 9; ++i) {
                publicSale.setFault(i);
                vm.expectRevert(
                    abi.encodeWithSelector(IStreamPrimarySaleSettlement.InvalidPrimarySale.selector)
                );
                publicSale.settleAndMint{ value: 1000 }(candidate, batch);
                _unchanged(candidate, batch);
                require(
                    nativeCommerceFloor.firstSale(1).receiptHash == 0,
                    "no floor after failed paid witness"
                );
            }
            publicSale.setFault(0);
            _success(candidate, batch, publicSale.settleAndMint{ value: 1000 }(candidate, batch));
        }

        function testMissingPermanentFloorRollsBackPaymentAndExactCandidateSucceedsAfterBinding()
            public
        {
            (
                IStreamMintManager.MintBatch memory batch,
                StreamNativeSettlementTypes.NativeSettlementCandidate memory candidate
            ) = _request();
            vm.expectRevert(
                abi.encodeWithSelector(
                    StreamPrimarySaleFloorCall.SaleFloorBindingUnavailable.selector
                )
            );
            publicSale.settleAndMint{ value: 1000 }(candidate, batch);
            _unchanged(candidate, batch);
            _enableNativeCommerceFloor();
            _success(candidate, batch, publicSale.settleAndMint{ value: 1000 }(candidate, batch));
        }

        function _request()
            private
            view
            returns (
                IStreamMintManager.MintBatch memory batch,
                StreamNativeSettlementTypes.NativeSettlementCandidate memory c
            )
        {
            batch.collectionId = 1;
            batch.phaseId = PHASE;
            batch.payer = payer;
            batch.initialRecipients = new address[](1);
            batch.initialRecipients[0] = payer;
            batch.beneficiaries = new address[](1);
            batch.beneficiaries[0] = payer;
            batch.tokenData = new bytes[](1);
            batch.tokenData[0] = bytes("public recorder artwork");
            batch.mintCommitments = new bytes32[](1);
            batch.mintCommitments[0] = keccak256("public recorder commitment");
            batch.expectedPolicyHash = manager.phasePolicyHash(1, PHASE);
            batch.authorizationId = keccak256("typed public request replay identity");
            batch.contextHash = keccak256("typed public purchase context");
            (bytes32 root, bytes32[] memory operations) = publicSale.preview(batch);
            StreamSaleTemplate.Selection memory rights =
                StreamNativeSettlementSupport.rights(resolver, 1);
            c.saleAdapter = address(publicSale);
            c.executor = payer;
            c.sale = StreamPrimarySettlementTypes.PrimarySale(
                publicSale.SALE(),
                CLASS,
                0,
                1,
                0,
                1,
                payer,
                payer,
                payer,
                1000,
                StreamSaleTemplate.policyHash(resolver, 1, rights)
            );
            c.lifecycleBinding = publicSale.nativeSaleLifecycleBinding(publicSale.SALE());
            c.executionBinding.executionNonce = 1;
            c.executionBinding.authorityMode = 2;
            c.orchestrationOrder = 1;
            c.mintManager = address(manager);
            c.operationIdentityCommitment = root;
            c.operationId = operations[0];
            c.currentPolicyHash = batch.expectedPolicyHash;
            c.boundPolicyHash = batch.expectedPolicyHash;
            c.rights = StreamPrimarySettlementTypes.PrimaryRights(
                rights.profileId,
                rights.wallet,
                rights.templateId,
                rights.assignmentHash,
                rights.entriesHash
            );
            c.saleExecutionHash = keccak256(abi.encode(batch));
            c.executionBinding.executionId = StreamNativeSettlementHash.executionId(c);
        }

        function _key(StreamNativeSettlementTypes.NativeSettlementCandidate memory c)
            private
            view
            returns (bytes32)
        {
            return keccak256(
                abi.encode(
                    keccak256("6529STREAM_PRIMARY_SETTLEMENT_KEY_V2"),
                    block.chainid,
                    address(recorder),
                    address(publicSale),
                    c.executionBinding.executionId
                )
            );
        }

        function _unchanged(
            StreamNativeSettlementTypes.NativeSettlementCandidate memory c,
            IStreamMintManager.MintBatch memory batch
        ) private view {
            require(
                wallet.balance == 0 && address(escrow).balance == 0
                    && address(recorder).balance == 0 && address(publicSale).balance == 0
                    && recorder.totalOfficialSettled(address(0)) == 0
                    && !recorder.settlementConsumed(_key(c))
                    && recorder.settlementResult(_key(c)).candidateCommitment == 0,
                "funding official totals result and replay roll back"
            );
            require(
                core.collectionMintedEver(1) == 0 && manager.nextOperationNonce() == 0
                    && !manager.isAuthorizationUsed(batch.authorizationId)
                    && !manager.isOperationRootUsed(c.operationIdentityCommitment),
                "mint and ledger remain untouched"
            );
            require(
                publicSale.activePublicNativeCandidate(c.executionBinding.executionId) == 0
                    || publicSale.fault() == 2,
                "failed invocation restores active candidate"
            );
        }

        function _success(
            StreamNativeSettlementTypes.NativeSettlementCandidate memory c,
            IStreamMintManager.MintBatch memory batch,
            StreamPrimarySettlementTypes.PrimarySettlementResult memory r
        ) private view {
            bytes32 commitment = keccak256(
                abi.encode(
                    keccak256("6529STREAM_NATIVE_SETTLEMENT_CANDIDATE_V1"),
                    block.chainid,
                    address(recorder),
                    c
                )
            );
            StreamPrimarySettlementTypes.PrimarySettlementResult memory expected =
                StreamPrimarySettlementTypes.PrimarySettlementResult(
                    commitment,
                    _key(c),
                    profile,
                    wallet,
                    address(0),
                    1000,
                    payer,
                    c.executionBinding.executionId,
                    false,
                    c.operationIdentityCommitment,
                    c.currentPolicyHash,
                    c.boundPolicyHash
                );
            require(
                keccak256(abi.encode(r)) == keccak256(abi.encode(expected))
                    && keccak256(abi.encode(recorder.settlementResult(_key(c))))
                        == keccak256(abi.encode(expected)),
                "entire original result matches independent commitment and key"
            );
            require(
                wallet.balance == 1000 && recorder.totalOfficialSettled(address(0)) == 1000
                    && recorder.officialSettled(CLASS, profile, wallet, address(0)) == 1000
                    && recorder.settlementConsumed(_key(c)),
                "one native official credit"
            );
            require(
                core.ownerOf(1) == payer && core.collectionMintedEver(1) == 1
                    && manager.nextOperationNonce() == 1
                    && manager.isAuthorizationUsed(batch.authorizationId)
                    && manager.isOperationRootUsed(c.operationIdentityCommitment),
                "actual mint follows payment once"
            );
            _assertNativeCommerceReceipt(_key(c), 0);
        }
    }
