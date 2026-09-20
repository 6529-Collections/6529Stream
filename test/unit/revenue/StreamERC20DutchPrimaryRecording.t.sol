// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../../helpers/NativeCuratedCommerceConservationFixture.sol";
import { UniversalPermitToken } from "../../helpers/UniversalSettlementTestMocks.sol";
import "../../../smart-contracts/interfaces/stream/revenue/IStreamERC20DutchPrimarySaleSettlement.sol";
import "../../../smart-contracts/interfaces/stream/revenue/IStreamERC20PublicDutchPrimarySaleSettlement.sol";
import "../../../smart-contracts/interfaces/stream/revenue/IStreamERC20PublicSaleBinding.sol";
import "../../../smart-contracts/interfaces/stream/revenue/IStreamERC20PrimarySettlementAdapter.sol";
import "../../../smart-contracts/interfaces/stream/revenue/IStreamERC20SaleExecution.sol";
import "../../../smart-contracts/interfaces/stream/revenue/IStreamERC20DutchSaleResolution.sol";
import "../../../smart-contracts/domains/revenue/StreamSettlementAdmission.sol";
import "../../../smart-contracts/domains/revenue/StreamPrimarySettlementHash.sol";
import "../../../smart-contracts/domains/revenue/StreamPrimarySettlementValidation.sol";
import "../../../smart-contracts/domains/revenue/StreamPrimarySaleFloorCall.sol";

/// @dev Funding boundary only: no claim that the original Payment product authorizes mode 2.
/// This fixture pins each arm to the actual caller/candidate and pulls real test-token balances.
contract DutchRecorderPaymentBoundary {
    address public immutable core;
    address public immutable moduleRegistry;
    address public immutable revenueResolver;
    address public immutable primarySaleSettlement;
    bytes32 public activeCommitment;
    bytes32 public activeKey;
    address public activeAsset;
    address public activePayer;
    uint256 public activeAmount;
    bool public funded;
    bool public shortFund;

    constructor(address c, address registry, address resolver, address recorder) {
        core = c;
        moduleRegistry = registry;
        revenueResolver = resolver;
        primarySaleSettlement = recorder;
    }

    function supportsInterface(bytes4 id) external pure returns (bool) {
        return id == 0x01ffc9a7 || id == type(IStreamERC20PrimarySettlementAdapter).interfaceId;
    }

    function setShortFund(bool value) external {
        shortFund = value;
    }

    function arm(StreamPrimarySettlementTypes.ERC20SettlementCandidate calldata c) external {
        require(msg.sender == c.saleAdapter, "fixture sale caller");
        activeCommitment = StreamPrimarySettlementHash.candidateCommitment(
            address(this), primarySaleSettlement, c
        );
        activeKey = StreamPrimarySettlementHash.settlementKey(
            primarySaleSettlement, c.saleAdapter, c.executionBinding.executionId
        );
        activeAsset = c.asset;
        activePayer = c.sale.payer;
        activeAmount = c.sale.amount;
        funded = false;
    }

    function fundERC20PrimarySale(bytes32 commitment, bytes32 key, address asset, uint256 amount)
        external
    {
        require(msg.sender == primarySaleSettlement && !funded, "one recorder funding callback");
        require(
            commitment == activeCommitment && key == activeKey && asset == activeAsset
                && amount == activeAmount,
            "exact original funding tuple"
        );
        funded = true;
        require(
            IERC20(asset).transferFrom(activePayer, msg.sender, shortFund ? amount - 1 : amount),
            "fixture exact transfer"
        );
    }
}

/// @dev Typed Dutch sale execution and public-record boundary. Production price/authorization
/// and Payment entrypoints are separate acceptance; this fixture supplies only recorder evidence.
contract DutchRecorderSaleBoundary is
    IStreamERC20PublicSaleBinding,
    IStreamERC20DutchSaleResolution
{
    address public immutable core;
    address public immutable moduleRegistry;
    address public immutable revenueResolver;
    address public immutable primarySaleSettlement;
    address public immutable mintManager;
    address public immutable observedWallet;
    address public immutable payment;
    bool public immutable dutch;
    bytes32 public constant SALE = keccak256("typed Dutch recorder sale");
    bytes32 public constant PHASE = keccak256("actual paid prepared phase");
    bytes32 public constant CONFIG = keccak256("typed immutable Dutch config");
    StreamPrimarySettlementTypes.SaleLifecycleBinding private _lifecycle;
    bytes32 private _activeId;
    bytes32 private _commitment;
    address private _asset;
    uint256 public fault;

    constructor(
        address c,
        address registry,
        address resolver,
        address recorder,
        address manager,
        address wallet,
        address payment_,
        bool dutch_
    ) {
        core = c;
        moduleRegistry = registry;
        revenueResolver = resolver;
        primarySaleSettlement = recorder;
        mintManager = manager;
        observedWallet = wallet;
        payment = payment_;
        dutch = dutch_;
    }

    function supportsInterface(bytes4 id) external view returns (bool) {
        return id == 0x01ffc9a7 || id == type(IStreamERC20SaleExecution).interfaceId
            || id == type(IStreamERC20PublicSaleBinding).interfaceId
            || id == type(IStreamERC20DutchSaleResolution).interfaceId;
    }

    function dutchResolutionProfile() external pure returns (bytes32) {
        return keccak256("6529STREAM_ERC20_STANDARD_DUTCH_V1");
    }

    /// @dev This recorder-only boundary does not claim production Dutch resolution semantics.
    function resolveERC20DutchExecution(bytes32, bytes32, address, bytes calldata)
        external
        pure
        returns (StreamPrimarySettlementTypes.ERC20SettlementCandidate memory)
    {
        revert("recorder-only boundary");
    }

    function initializeLifecycle() external {
        require(_lifecycle.saleCreatedAt == 0, "once");
        _lifecycle = dutch
            ? StreamSettlementAdmission.captureDutch(moduleRegistry, address(this), payment)
            : StreamSettlementAdmission.capture(moduleRegistry, address(this), payment);
    }

    function saleLifecycleBinding(bytes32 id)
        external
        view
        returns (StreamPrimarySettlementTypes.SaleLifecycleBinding memory)
    {
        require(id == SALE, "original sale");
        return _lifecycle;
    }

    function setFault(uint256 mode) external {
        fault = mode;
    }

    function publicERC20SaleBinding(bytes32 id)
        external
        view
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
        if (fault == 12) revert("public record unavailable");
        bytes32 config = fault == 5 ? bytes32(0) : CONFIG;
        if ((fault == 8 && _funded()) || (fault == 9 && _routed())) {
            config = keccak256("callback changed immutable record");
        }
        return (fault == 6 ? 2 : 1, fault == 7 ? bytes32(0) : PHASE, config, 2);
    }

    function activePublicERC20Candidate(bytes32 id) external view returns (bytes32) {
        if (fault == 2) {
            assembly ("memory-safe") {
                mstore(0, 1)
                mstore(32, 2)
                return(0, 64)
            }
        }
        if (fault == 1 || (fault == 10 && _funded()) || (fault == 11 && _routed())) return 0;
        if (fault == 13) return keccak256("different payment or recorder commitment");
        return id == _activeId ? _commitment : bytes32(0);
    }

    function _funded() private view returns (bool) {
        return _asset != address(0) && IERC20(_asset).balanceOf(primarySaleSettlement) != 0;
    }

    function _routed() private view returns (bool) {
        return _asset != address(0) && IERC20(_asset).balanceOf(observedWallet) != 0;
    }

    function preview(IStreamMintManager.MintBatch calldata batch)
        external
        view
        returns (bytes32, bytes32[] memory)
    {
        return IStreamMintManager(mintManager).previewSingleStepMintOperation(batch, "");
    }

    function settle(StreamPrimarySettlementTypes.ERC20SettlementCandidate calldata c, uint8 route)
        external
        returns (StreamPrimarySettlementTypes.PrimarySettlementResult memory)
    {
        return _settle(c, route);
    }

    function settleAndMint(
        StreamPrimarySettlementTypes.ERC20SettlementCandidate calldata c,
        IStreamMintManager.MintBatch calldata batch,
        uint8 route
    ) external returns (StreamPrimarySettlementTypes.PrimarySettlementResult memory result) {
        result = _settle(c, route);
        (uint256[] memory ids, bytes32 root, bytes32[] memory operations) =
            IStreamMintManager(mintManager).executeSingleStepMint(batch, "");
        require(
            ids.length == 1 && ids[0] != 0 && root == c.operationIdentityCommitment
                && operations.length == 1 && operations[0] == c.operationId,
            "actual exact singleton mint"
        );
    }

    function _settle(StreamPrimarySettlementTypes.ERC20SettlementCandidate calldata c, uint8 route)
        private
        returns (StreamPrimarySettlementTypes.PrimarySettlementResult memory result)
    {
        require(_activeId == 0, "fixture active callback lock");
        _activeId = c.executionBinding.executionId;
        _commitment =
            StreamPrimarySettlementHash.candidateCommitment(payment, primarySaleSettlement, c);
        _asset = c.asset;
        DutchRecorderPaymentBoundary(payment).arm(c);
        if (route == 0) {
            result = IStreamPrimarySaleSettlement(primarySaleSettlement)
                .settleERC20PrimarySaleFromAdapter(payment, c);
        } else if (route == 1) {
            result = IStreamERC20DutchPrimarySaleSettlement(primarySaleSettlement)
                .settleERC20DutchPrimarySaleFromAdapter(payment, c);
        } else {
            result = IStreamERC20PublicDutchPrimarySaleSettlement(primarySaleSettlement)
                .settleERC20PublicDutchPrimarySaleFromAdapter(payment, c);
        }
        delete _activeId;
        delete _commitment;
        delete _asset;
    }
}

/// @notice Actual Core, Manager, Ledger, Registry, Recorder, Resolver, wallet, escrow and WAIVED Floor.
/// @dev Sale/Payment, token, Artist, governance, entropy and Metadata writer are explicit test boundaries.
/// Does not claim production Dutch pricing, PaymentIntent/permit authorization or current Artist onboarding.
contract StreamERC20DutchPrimaryRecordingTest is NativeCuratedCommerceConservationFixture {
    DutchRecorderPaymentBoundary private dutchPayment;
    DutchRecorderSaleBoundary private dutchSale;
    UniversalPermitToken private settlementToken;
    bytes32 private constant VERSION = keccak256("6529STREAM_UNIVERSAL_SETTLEMENT_V1");

    function setUp() public override {
        super.setUp();
        settlementToken = new UniversalPermitToken();
        _setAssetPolicy(policy, address(settlementToken), 1, keccak256("exact Dutch test token"), 0);
        dutchPayment = new DutchRecorderPaymentBoundary(
            address(core), address(registry), address(resolver), address(recorder)
        );
        _register(
            address(dutchPayment),
            keccak256("ERC20_PRIMARY_SETTLEMENT_ADAPTER"),
            type(IStreamERC20PrimarySettlementAdapter).interfaceId,
            VERSION
        );
        dutchSale = _saleBoundary(true);
        manager.setPhaseExecutor(1, PHASE, address(dutchSale), true);
        settlementToken.mint(payer, 10_000);
        vm.prank(payer);
        settlementToken.approve(address(dutchPayment), 10_000);
    }

    function _saleBoundary(bool isDutch) private returns (DutchRecorderSaleBoundary s) {
        s = new DutchRecorderSaleBoundary(
            address(core),
            address(registry),
            address(resolver),
            address(recorder),
            address(manager),
            wallet,
            address(dutchPayment),
            isDutch
        );
        _register(
            address(s),
            isDutch ? keccak256("DUTCH_AUCTION_ADAPTER") : keccak256("FIXED_PRICE_SALE_ADAPTER"),
            type(IStreamERC20SaleExecution).interfaceId,
            VERSION
        );
        s.initializeLifecycle();
    }

    function testPublicDutchRetainsEntireResultFloorReplayAndActualMint() public {
        _enableNativeCommerceFloor();
        (
            IStreamMintManager.MintBatch memory batch,
            StreamPrimarySettlementTypes.ERC20SettlementCandidate memory c
        ) = _request(2);
        vm.recordLogs();
        StreamPrimarySettlementTypes.PrimarySettlementResult memory r =
            dutchSale.settleAndMint(c, batch, 2);
        _success(c, batch, r);
        Vm.Log[] memory logs = vm.getRecordedLogs();
        bytes32 topic = keccak256(
            "PrimaryRevenueExecutionBound(bytes32,address,bytes32,uint16,address,address,bytes32,bytes32,bytes32)"
        );
        uint256 count;
        for (uint256 i; i < logs.length; ++i) {
            if (logs[i].emitter != address(recorder) || logs[i].topics[0] != topic) continue;
            ++count;
            require(
                logs[i].topics.length == 4 && logs[i].topics[1] == r.settlementKey
                    && logs[i].topics[2] == bytes32(uint256(uint160(address(dutchSale))))
                    && logs[i].topics[3] == c.executionBinding.executionId
                    && keccak256(logs[i].data)
                        == keccak256(
                            abi.encode(
                                uint16(1),
                                payer,
                                address(dutchPayment),
                                r.candidateCommitment,
                                c.currentPolicyHash,
                                c.boundPolicyHash
                            )
                        ),
                "exact original ERC20 event"
            );
        }
        require(count == 1 && abi.encode(r).length == 384, "one original twelve-word result");
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamPrimarySaleSettlement.SettlementAlreadyConsumed.selector, _key(c)
            )
        );
        dutchSale.settle(c, 2);
        require(
            settlementToken.balanceOf(wallet) == 1000 && settlementToken.balanceOf(payer) == 9000,
            "no repeated funding"
        );
        require(
            recorder.supportsInterface(
                type(IStreamERC20PublicDutchPrimarySaleSettlement).interfaceId
            )
            && recorder.supportsInterface(type(IStreamERC20DutchPrimarySaleSettlement).interfaceId)
            && recorder.supportsInterface(type(IStreamPrimarySaleSettlement).interfaceId),
            "additive capabilities"
        );
    }

    function testSignedDutchKeepsOriginalSignedValidationAndFunding() public {
        _enableNativeCommerceFloor();
        (
            IStreamMintManager.MintBatch memory publicBatch,
            StreamPrimarySettlementTypes.ERC20SettlementCandidate memory publicCandidate
        ) = _request(2);
        _invalid();
        dutchSale.settle(publicCandidate, 1);
        _unchanged(publicCandidate, publicBatch);
        (
            IStreamMintManager.MintBatch memory batch,
            StreamPrimarySettlementTypes.ERC20SettlementCandidate memory c
        ) = _request(1);
        _invalid();
        dutchSale.settle(c, 2);
        _unchanged(c, batch);
        _success(c, batch, dutchSale.settleAndMint(c, batch, 1));
    }

    function testClosedDutchAndOriginalFixedAdmissionsCannotBeInterchanged() public {
        (
            IStreamMintManager.MintBatch memory batch,
            StreamPrimarySettlementTypes.ERC20SettlementCandidate memory c
        ) = _request(1);
        vm.expectRevert(
            abi.encodeWithSelector(
                StreamSettlementAdmission.SettlementModuleNotAdmitted.selector, address(dutchSale)
            )
        );
        dutchSale.settle(c, 0);
        _unchanged(c, batch);
        DutchRecorderSaleBoundary fixedBoundary = _saleBoundary(false);
        c.saleAdapter = address(fixedBoundary);
        c.lifecycleBinding = fixedBoundary.saleLifecycleBinding(fixedBoundary.SALE());
        c.executionBinding.executionId = StreamPrimarySettlementHash.executionId(c);
        vm.expectRevert(
            abi.encodeWithSelector(
                StreamSettlementAdmission.SettlementModuleNotAdmitted.selector,
                address(fixedBoundary)
            )
        );
        fixedBoundary.settle(c, 1);
        require(
            settlementToken.balanceOf(payer) == 10_000
                && recorder.totalOfficialSettled(address(settlementToken)) == 0,
            "neither admission widens"
        );
    }

    function testPublicRejectsWrongCallerSignedDigestZeroAmountAndMintIdentities() public {
        (
            IStreamMintManager.MintBatch memory batch,
            StreamPrimarySettlementTypes.ERC20SettlementCandidate memory c
        ) = _request(2);
        _invalid();
        recorder.settleERC20PublicDutchPrimarySaleFromAdapter(address(dutchPayment), c);
        _unchanged(c, batch);
        for (uint256 i; i < 6; ++i) {
            (, c) = _request(2);
            if (i == 0) {
                c.executionBinding.saleAuthorizationDigest = keccak256("synthetic seller digest");
            } else if (i == 1) {
                c.executionBinding.authorityMode = 1;
            } else if (i == 2) {
                c.operationId = 0;
            } else if (i == 3) {
                c.operationIdentityCommitment = 0;
            } else if (i == 4) {
                c.sale.amount = 0;
            } else {
                c.executionBinding.executionNonce = 0;
            }
            c.executionBinding.executionId = StreamPrimarySettlementHash.executionId(c);
            _invalid();
            dutchSale.settle(c, 2);
            _unchanged(c, batch);
        }
    }

    function testPublicRecordAndActiveCommitmentReadsAreExactAndFailClosed() public {
        (
            IStreamMintManager.MintBatch memory batch,
            StreamPrimarySettlementTypes.ERC20SettlementCandidate memory c
        ) = _request(2);
        uint256[9] memory modes = [uint256(1), 2, 3, 4, 5, 6, 7, 12, 13];
        for (uint256 i; i < modes.length; ++i) {
            uint256 mode = modes[i];
            dutchSale.setFault(mode);
            if (mode == 2 || mode == 3 || mode == 12) {
                vm.expectRevert(
                    abi.encodeWithSelector(
                        StreamPrimarySettlementValidation.SettlementReadFailed.selector,
                        address(dutchSale),
                        mode == 2
                            ? IStreamERC20PublicSaleBinding.activePublicERC20Candidate.selector
                            : IStreamERC20PublicSaleBinding.publicERC20SaleBinding.selector
                    )
                );
            } else {
                _invalid();
            }
            dutchSale.settle(c, 2);
            _unchanged(c, batch);
        }
    }

    function testPublicRecordAndWitnessRecheckedAfterBothFundingAndRouting() public {
        _enableNativeCommerceFloor();
        (
            IStreamMintManager.MintBatch memory batch,
            StreamPrimarySettlementTypes.ERC20SettlementCandidate memory c
        ) = _request(2);
        for (uint256 mode = 8; mode <= 11; ++mode) {
            dutchSale.setFault(mode);
            _invalid();
            dutchSale.settleAndMint(c, batch, 2);
            _unchanged(c, batch);
            require(
                nativeCommerceFloor.firstSale(1).receiptHash == 0,
                "callback drift cannot publish floor"
            );
        }
        dutchSale.setFault(0);
        _success(c, batch, dutchSale.settleAndMint(c, batch, 2));
    }

    function testExactFundingDeltaAndOriginalRecorderReentrancyRemainEnforced() public {
        _enableNativeCommerceFloor();
        (
            IStreamMintManager.MintBatch memory batch,
            StreamPrimarySettlementTypes.ERC20SettlementCandidate memory c
        ) = _request(2);
        dutchPayment.setShortFund(true);
        vm.expectRevert(
            abi.encodeWithSelector(
                StreamSettlementContext.SettlementAmountMismatch.selector, address(settlementToken)
            )
        );
        dutchSale.settle(c, 2);
        _unchanged(c, batch);
        dutchPayment.setShortFund(false);
        settlementToken.setCallback(
            address(recorder),
            abi.encodeCall(
                recorder.settleERC20PublicDutchPrimarySaleFromAdapter, (address(dutchPayment), c)
            )
        );
        _success(c, batch, dutchSale.settleAndMint(c, batch, 2));
        require(
            !settlementToken.callbackSuccess()
                && settlementToken.callbackResultHash()
                    == keccak256(
                        abi.encodeWithSignature("Error(string)", "ReentrancyGuard: reentrant call")
                    ),
            "token callbacks cannot reenter original host lock"
        );
    }

    function testMissingPermanentFloorRollsBackAndExactCandidateRetriesAfterBinding() public {
        (
            IStreamMintManager.MintBatch memory batch,
            StreamPrimarySettlementTypes.ERC20SettlementCandidate memory c
        ) = _request(2);
        vm.expectRevert(
            abi.encodeWithSelector(StreamPrimarySaleFloorCall.SaleFloorBindingUnavailable.selector)
        );
        dutchSale.settleAndMint(c, batch, 2);
        _unchanged(c, batch);
        _enableNativeCommerceFloor();
        _success(c, batch, dutchSale.settleAndMint(c, batch, 2));
    }

    function _request(uint8 mode)
        private
        view
        returns (
            IStreamMintManager.MintBatch memory batch,
            StreamPrimarySettlementTypes.ERC20SettlementCandidate memory c
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
        batch.tokenData[0] = bytes("typed Dutch artwork");
        batch.mintCommitments = new bytes32[](1);
        batch.mintCommitments[0] = keccak256("typed Dutch commitment");
        batch.expectedPolicyHash = manager.phasePolicyHash(1, PHASE);
        batch.authorizationId = keccak256(abi.encode("typed Dutch replay identity", mode));
        batch.contextHash = keccak256("typed Dutch request");
        (bytes32 root, bytes32[] memory operations) = dutchSale.preview(batch);
        StreamSaleTemplate.Selection memory rights =
            StreamNativeSettlementSupport.rights(resolver, 1);
        c.saleAdapter = address(dutchSale);
        c.executor = payer;
        c.sale = StreamPrimarySettlementTypes.PrimarySale(
            dutchSale.SALE(),
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
        c.lifecycleBinding = dutchSale.saleLifecycleBinding(dutchSale.SALE());
        c.executionBinding.executionNonce = 1;
        c.executionBinding.authorityMode = mode;
        if (mode == 1) {
            c.executionBinding.saleAuthorizationDigest =
                keccak256("typed signed authorization digest");
        }
        c.asset = address(settlementToken);
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
        c.executionBinding.executionId = StreamPrimarySettlementHash.executionId(c);
    }

    function _key(StreamPrimarySettlementTypes.ERC20SettlementCandidate memory c)
        private
        view
        returns (bytes32)
    {
        return keccak256(
            abi.encode(
                keccak256("6529STREAM_PRIMARY_SETTLEMENT_KEY_V2"),
                block.chainid,
                address(recorder),
                c.saleAdapter,
                c.executionBinding.executionId
            )
        );
    }

    function _invalid() private {
        vm.expectRevert(
            abi.encodeWithSelector(IStreamPrimarySaleSettlement.InvalidPrimarySale.selector)
        );
    }

    function _unchanged(
        StreamPrimarySettlementTypes.ERC20SettlementCandidate memory c,
        IStreamMintManager.MintBatch memory batch
    ) private view {
        require(
            settlementToken.balanceOf(payer) == 10_000
                && settlementToken.allowance(payer, address(dutchPayment)) == 10_000
                && settlementToken.balanceOf(wallet) == 0
                && settlementToken.balanceOf(address(recorder)) == 0
                && settlementToken.balanceOf(address(escrow)) == 0
                && recorder.totalOfficialSettled(address(settlementToken)) == 0
                && !recorder.settlementConsumed(_key(c))
                && recorder.settlementResult(_key(c)).candidateCommitment == 0
                && dutchPayment.activeCommitment() == 0 && !dutchPayment.funded(),
            "payment balances allowance replay result and callback state roll back"
        );
        require(
            core.collectionMintedEver(1) == 0 && manager.nextOperationNonce() == 0
                && !manager.isAuthorizationUsed(batch.authorizationId)
                && !manager.isOperationRootUsed(c.operationIdentityCommitment),
            "Core and Ledger unchanged"
        );
    }

    function _success(
        StreamPrimarySettlementTypes.ERC20SettlementCandidate memory c,
        IStreamMintManager.MintBatch memory batch,
        StreamPrimarySettlementTypes.PrimarySettlementResult memory r
    ) private view {
        bytes32 commitment = keccak256(
            abi.encode(
                keccak256("6529STREAM_ERC20_SETTLEMENT_CANDIDATE_V2"),
                block.chainid,
                address(dutchPayment),
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
                address(settlementToken),
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
            "entire original token result"
        );
        require(
            settlementToken.balanceOf(wallet) == 1000 && settlementToken.balanceOf(payer) == 9000
                && settlementToken.allowance(payer, address(dutchPayment)) == 9000
                && settlementToken.balanceOf(address(recorder)) == 0
                && recorder.totalOfficialSettled(address(settlementToken)) == 1000
                && recorder.officialSettled(CLASS, profile, wallet, address(settlementToken))
                    == 1000 && recorder.settlementConsumed(_key(c)),
            "one conserved official ERC20 payment"
        );
        require(
            core.ownerOf(1) == payer && core.collectionMintedEver(1) == 1
                && manager.nextOperationNonce() == 1
                && manager.isAuthorizationUsed(batch.authorizationId)
                && manager.isOperationRootUsed(c.operationIdentityCommitment),
            "actual post-payment mint consumes exact original identities"
        );
        _assertNativeCommerceReceipt(_key(c), 0);
        StreamConservationFloorTypes.SettlementReceipt memory floor =
            nativeCommerceFloor.settlementReceipt(_key(c));
        require(
            floor.resultHash == keccak256(abi.encode(expected))
                && floor.candidateCommitment == commitment
                && nativeCommerceFloor.sourceCount() == 0,
            "real permanent explicitly WAIVED Floor without documentary fabrication"
        );
    }
}
