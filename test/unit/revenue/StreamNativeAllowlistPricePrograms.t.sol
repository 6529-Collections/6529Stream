// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./StreamNativePricePrograms.t.sol";
import "../../../smart-contracts/interfaces/stream/mint/IStreamNativeAllowlistPricePrograms.sol";
import "../../../smart-contracts/domains/mint/StreamMintSaleAllowlist.sol";

/// @dev Explicit counter-read seam only. Real Manager/Ledger proof and cap enforcement
///      are exercised independently; settlement, signatures, replay and callbacks are real here.
contract NativeAllowlistPriceManagerMock is UniversalManagerMock {
    address public immutable mintLedger;
    bytes32 private _counterId;
    IStreamMintManager.MintCounterConfig private _counter;
    IStreamMintCounterPolicy.Definition private _definition;

    constructor(address c, address r) UniversalManagerMock(c, r) {
        mintLedger = address(this);
    }

    function setCounter(bytes32 id, IStreamMintManager.CounterKeyMode keyMode, bytes32 root)
        external
    {
        _counterId = id;
        _definition = IStreamMintCounterPolicy.Definition(
            IStreamMintCounterPolicy.CounterScope.PHASE, keyMode, root, keccak256("price fixture")
        );
        _counter = IStreamMintManager.MintCounterConfig(
            true,
            keyMode,
            IStreamMintLedger.CounterCapMode.MERKLE_STATIC,
            IStreamMintLedger.CounterDeltaMode.STATIC,
            10,
            1,
            keccak256(abi.encode(keccak256("6529STREAM_MINT_COUNTER_DEFINITION_V1"), _definition))
        );
    }

    function phaseCounterIds(uint256, bytes32) external view returns (bytes32[] memory ids) {
        ids = new bytes32[](1);
        ids[0] = _counterId;
    }

    function counterConfig(uint256, bytes32, bytes32 id)
        external
        view
        returns (IStreamMintManager.MintCounterConfig memory)
    {
        require(id == _counterId, "unknown fixture counter");
        return _counter;
    }

    function counterDefinitionForManager(address manager_, bytes32 hash)
        external
        view
        returns (bool, IStreamMintCounterPolicy.Definition memory)
    {
        require(manager_ == address(this), "definition must name Manager");
        return (hash == _counter.counterConfigHash, _definition);
    }
}

contract StreamNativeAllowlistPriceProgramsTest is NativePriceProgramTestBase {
    bytes32 private constant PRICE_COUNTER = keccak256("native sale price tier");
    NativeAllowlistPriceManagerMock private priceManager;

    function setUp() public override {
        super.setUp();
        _priceManager();
    }

    function _priceManager() private {
        priceManager = new NativeAllowlistPriceManagerMock(address(core), address(registry));
        manager = priceManager;
        _nativeSale();
    }

    function _proof(bool hasOverride, uint256 amount)
        private
        pure
        returns (IStreamMintCounterPolicy.AllowlistProof memory p)
    {
        p.maxCount = 7;
        p.hasPriceOverride = hasOverride;
        p.priceOverride = amount;
        p.proof = new bytes32[](0);
    }

    function _data(IStreamMintCounterPolicy.AllowlistProof memory p)
        private
        pure
        returns (bytes memory)
    {
        IStreamMintCounterPolicy.AllowlistProof[][] memory proofs =
            new IStreamMintCounterPolicy.AllowlistProof[][](1);
        proofs[0] = new IStreamMintCounterPolicy.AllowlistProof[](1);
        proofs[0][0] = p;
        return abi.encode(proofs);
    }

    function _bind(
        IStreamMintCounterPolicy.AllowlistProof memory p,
        address account,
        IStreamMintManager.CounterKeyMode mode
    ) private {
        // Independent canonical double hash, including both distinct price fields.
        bytes32 root = keccak256(
            bytes.concat(
                keccak256(
                    abi.encode(
                        keccak256("6529STREAM_MINT_ALLOWLIST_LEAF_V1"),
                        block.chainid,
                        address(manager),
                        uint256(1),
                        PHASE,
                        PRICE_COUNTER,
                        account,
                        p.maxCount,
                        p.hasPriceOverride,
                        p.priceOverride
                    )
                )
            )
        );
        priceManager.setCounter(PRICE_COUNTER, mode, root);
    }

    function _allowlist(uint8 kind, uint256 minimum, uint256 maximum, bool allowFree)
        private
        returns (bytes32)
    {
        return nativeSale.registerAllowlistPriceProgram(
            _config(kind, minimum, maximum, kind == 1 ? 0 : 5),
            IStreamNativeAllowlistPricePrograms.AllowlistPricePolicy(PRICE_COUNTER, allowFree)
        );
    }

    function _executeProof(
        IStreamNativePricePrograms.PriceProgramExecution memory e,
        bytes memory data
    ) private returns (IStreamNativePricePrograms.PriceProgramResult memory) {
        vm.prank(e.authorization.payer);
        return nativeSale.executeAllowlistPriceProgram{ value: e.chosenUnitPrice }(e, data);
    }

    function _assertUnused(bytes32 id, uint256 execution, uint256 beforeBalance) private view {
        require(nativeSale.priceProgramRecord(id).mintedQuantity == 0, "supply unchanged");
        require(
            !nativeSale.authorizationUsed(artist, bytes32(execution)), "authorization unchanged"
        );
        require(nativeSale.executionIdByNonce(id, execution) == 0, "execution replay unchanged");
        require(manager.nonce() == 0 && payer.balance == beforeBalance, "mint and payer unchanged");
        require(recorder.totalOfficialSettled(address(0)) == 0, "official revenue unchanged");
        require(
            address(nativeSale).balance == 0 && address(recorder).balance == 0,
            "no retained payment"
        );
    }

    function _expectedRoot(
        IStreamNativePricePrograms.PriceProgramExecution memory e,
        bytes memory data
    ) private view returns (bytes32) {
        IStreamMintManager.MintBatch memory b;
        b.collectionId = 1;
        b.phaseId = PHASE;
        b.payer = e.authorization.payer;
        b.initialRecipients = new address[](1);
        b.initialRecipients[0] = e.authorization.recipient;
        b.beneficiaries = new address[](1);
        b.beneficiaries[0] = e.authorization.recipient;
        b.tokenData = new bytes[](1);
        b.tokenData[0] = e.tokenData;
        b.mintCommitments = new bytes32[](1);
        b.mintCommitments[0] = e.authorization.mintCommitment;
        b.expectedPolicyHash = manager.POLICY();
        b.contextHash = nativeSale.priceProgramAuthorizationDigest(e.authorization);
        b.authorizationId = keccak256(
            abi.encode(keccak256("6529STREAM_MINT_TICKET_AUTHORIZATION_V1"), b.contextHash)
        );
        b.resolverData = data;
        return keccak256(abi.encode(b, address(nativeSale), manager.nonce()));
    }

    function testFixedAndOpenEditionUseExactLeafOutsidePublicBandAndSameProofForMint() public {
        IStreamMintCounterPolicy.AllowlistProof memory p = _proof(true, 2500);
        _bind(p, payer, IStreamMintManager.CounterKeyMode.PAYER);
        bytes memory data = _data(p);
        for (uint8 kind; kind < 2; ++kind) {
            bytes32 id = _allowlist(kind, 1000, 1000, false);
            IStreamNativePricePrograms.PriceProgramExecution memory e =
                _execution(id, kind + 1, 2500, 1000);
            IStreamNativePricePrograms.PriceProgramResult memory q =
                nativeSale.previewAllowlistPriceProgram(e, data);
            require(q.operationRoot == _expectedRoot(e, data), "preview commits exact proof bytes");
            uint256 beforeBalance = payer.balance;
            IStreamNativePricePrograms.PriceProgramResult memory r = _executeProof(e, data);
            require(
                r.operationRoot == q.operationRoot && r.operationId == q.operationId,
                "execution uses previewed proof"
            );
            require(
                r.revenueOutcome == 2 && r.chargedAmount == 2500
                    && payer.balance == beforeBalance - 2500,
                "exact authenticated fixed price"
            );
            require(
                recorder.settlementResult(r.settlementKey).amount == 2500, "exact official price"
            );
        }
        require(
            recorder.totalOfficialSettled(address(0)) == 5000 && wallet.balance == 5000,
            "both complete prices settled"
        );
    }

    function testFixedOverrideRejectsDifferentChoiceAndDifferentOriginalSignedPrice() public {
        IStreamMintCounterPolicy.AllowlistProof memory p = _proof(true, 250);
        _bind(p, payer, IStreamMintManager.CounterKeyMode.PAYER);
        bytes32 id = _allowlist(0, 1000, 1000, false);
        IStreamNativePricePrograms.PriceProgramExecution memory e = _execution(id, 1, 251, 1000);
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamNativePricePrograms.NativePriceOutsideBand.selector,
                uint256(251),
                uint256(250),
                uint256(250)
            )
        );
        nativeSale.previewAllowlistPriceProgram(e, _data(p));
        e.chosenUnitPrice = 250;
        e.authorization.unitPrice = 250;
        _programSign(e);
        vm.expectRevert(
            abi.encodeWithSelector(IStreamNativePricePrograms.InvalidNativePriceProgram.selector)
        );
        nativeSale.previewAllowlistPriceProgram(e, _data(p));
        e.authorization.unitPrice = 1000;
        _programSign(e);
        _executeProof(e, _data(p));
        require(recorder.totalOfficialSettled(address(0)) == 250, "discount remains valid");
    }

    function testPWYWLeafReplacesSignedMinimumButRetainsConfiguredFloorAndCeiling() public {
        IStreamMintCounterPolicy.AllowlistProof memory p = _proof(true, 300);
        _bind(p, payer, IStreamMintManager.CounterKeyMode.PAYER);
        bytes32 id = _allowlist(13, 100, 1000, false);
        IStreamNativePricePrograms.PriceProgramExecution memory e = _execution(id, 1, 299, 900);
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamNativePricePrograms.NativePriceOutsideBand.selector,
                uint256(299),
                uint256(300),
                uint256(1000)
            )
        );
        nativeSale.previewAllowlistPriceProgram(e, _data(p));
        e.chosenUnitPrice = 1001;
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamNativePricePrograms.NativePriceOutsideBand.selector,
                uint256(1001),
                uint256(300),
                uint256(1000)
            )
        );
        nativeSale.previewAllowlistPriceProgram(e, _data(p));
        e.chosenUnitPrice = 777;
        _executeProof(e, _data(p));
        require(recorder.totalOfficialSettled(address(0)) == 777, "whole PWYW choice settles");
        p.priceOverride = 50;
        _bind(p, payer, IStreamMintManager.CounterKeyMode.PAYER);
        e = _execution(id, 2, 99, 900);
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamNativePricePrograms.NativePriceOutsideBand.selector,
                uint256(99),
                uint256(100),
                uint256(1000)
            )
        );
        nativeSale.previewAllowlistPriceProgram(e, _data(p));
        e.chosenUnitPrice = 100;
        _executeProof(e, _data(p));
    }

    function testCapOnlyProofPreservesFixedPriceAndSignedPWYWMinimum() public {
        IStreamMintCounterPolicy.AllowlistProof memory p = _proof(false, 0);
        _bind(p, payer, IStreamMintManager.CounterKeyMode.PAYER);
        bytes32 fixedId = _allowlist(0, 1000, 1000, false);
        _executeProof(_execution(fixedId, 1, 1000, 1000), _data(p));
        bytes32 pwywId = _allowlist(13, 100, 1000, false);
        IStreamNativePricePrograms.PriceProgramExecution memory e = _execution(pwywId, 2, 599, 600);
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamNativePricePrograms.NativePriceOutsideBand.selector,
                uint256(599),
                uint256(600),
                uint256(1000)
            )
        );
        nativeSale.previewAllowlistPriceProgram(e, _data(p));
        e.chosenUnitPrice = 777;
        _executeProof(e, _data(p));
        require(recorder.totalOfficialSettled(address(0)) == 1777, "fallback semantics retained");
    }

    function testZeroFixedOverrideRequiresCreationDeclarationAndRollsBack() public {
        IStreamMintCounterPolicy.AllowlistProof memory p = _proof(true, 0);
        _bind(p, payer, IStreamMintManager.CounterKeyMode.PAYER);
        bytes32 id = _allowlist(0, 1000, 1000, false);
        IStreamNativePricePrograms.PriceProgramExecution memory e = _execution(id, 1, 0, 1000);
        bytes memory reason = abi.encodeWithSelector(
            IStreamNativeAllowlistPricePrograms.SalePriceOverrideZeroUndeclared.selector, id
        );
        uint256 beforeBalance = payer.balance;
        vm.expectRevert(reason);
        nativeSale.previewAllowlistPriceProgram(e, _data(p));
        vm.expectRevert(reason);
        _executeProof(e, _data(p));
        _assertUnused(id, 1, beforeBalance);
    }

    function testDeclaredZeroFixedPriceSkipsPayoutMaterializationAndOfficialSettlement() public {
        _template(payer);
        _priceManager();
        IStreamMintCounterPolicy.AllowlistProof memory p = _proof(true, 0);
        _bind(p, payer, IStreamMintManager.CounterKeyMode.PAYER);
        bytes32 id = _allowlist(0, 1000, 1000, true);
        IStreamNativePricePrograms.PriceProgramExecution memory e = _execution(id, 1, 0, 1000);
        uint256 profiles = factory.profileCount();
        SaleFundingFaultVm(address(vm))
            .mockCallRevert(
                address(resolver),
                0,
                abi.encodeCall(
                    IStreamRevenueResolver.resolvePrimaryAssignment, (uint256(1), uint256(0), CLASS)
                ),
                hex"cafe"
            );
        SaleFundingFaultVm(address(vm))
            .mockCallRevert(
                address(templateArtist),
                0,
                abi.encodeCall(
                    IStreamArtistBeneficiaryFacts.collectionArtistBeneficiary, (uint256(1))
                ),
                hex"babe"
            );
        IStreamNativePricePrograms.PriceProgramResult memory q =
            nativeSale.previewAllowlistPriceProgram(e, _data(p));
        vm.recordLogs();
        IStreamNativePricePrograms.PriceProgramResult memory r = _executeProof(e, _data(p));
        Vm.Log[] memory logs = vm.getRecordedLogs();
        require(
            r.operationRoot == q.operationRoot && r.revenueOutcome == 1 && r.tokenId == 1
                && r.chargedAmount == 0 && r.settlementKey == 0 && !r.escrowed,
            "explicit free mint"
        );
        require(
            factory.profileCount() == profiles && recorder.totalOfficialSettled(address(0)) == 0
                && address(escrow).balance == 0,
            "free makes no revenue state"
        );
        for (uint256 i; i < logs.length; ++i) {
            require(
                logs[i].emitter != address(recorder) && logs[i].emitter != address(escrow)
                    && logs[i].emitter != address(factory),
                "free makes no revenue events"
            );
        }
    }

    function testFreeKindRejectsPaidOverrideAndOtherKindsRejectRedundantFreeDeclaration() public {
        IStreamMintCounterPolicy.AllowlistProof memory p = _proof(true, 1);
        _bind(p, payer, IStreamMintManager.CounterKeyMode.PAYER);
        bytes32 id = _allowlist(12, 0, 0, false);
        IStreamNativePricePrograms.PriceProgramExecution memory e = _execution(id, 1, 0, 0);
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamNativeAllowlistPricePrograms.InvalidAllowlistPricePolicy.selector
            )
        );
        nativeSale.previewAllowlistPriceProgram(e, _data(p));
        for (uint8 kind = 12; kind <= 13; ++kind) {
            IStreamNativePricePrograms.PriceProgramConfig memory c =
                _config(kind, 0, kind == 12 ? 0 : 1000, 5);
            vm.expectRevert(
                abi.encodeWithSelector(
                    IStreamNativeAllowlistPricePrograms.InvalidAllowlistPricePolicy.selector
                )
            );
            nativeSale.registerAllowlistPriceProgram(
                c, IStreamNativeAllowlistPricePrograms.AllowlistPricePolicy(PRICE_COUNTER, true)
            );
        }
        p.priceOverride = 0;
        _bind(p, payer, IStreamMintManager.CounterKeyMode.PAYER);
        _executeProof(e, _data(p));
        require(recorder.totalOfficialSettled(address(0)) == 0, "zero free-kind override allowed");
    }

    function testProofPriceFlagAndRecipientTamperingFailWithoutAnyStateConsumption() public {
        IStreamMintCounterPolicy.AllowlistProof memory p = _proof(true, 250);
        _bind(p, payer, IStreamMintManager.CounterKeyMode.RECIPIENT);
        bytes32 id = _allowlist(0, 1000, 1000, false);
        IStreamNativePricePrograms.PriceProgramExecution memory e = _execution(id, 1, 250, 1000);
        uint256 beforeBalance = payer.balance;
        p.priceOverride = 251;
        vm.expectRevert(
            abi.encodeWithSelector(
                StreamMintSaleAllowlist.InvalidSaleAllowlistProof.selector, PRICE_COUNTER, payer
            )
        );
        _executeProof(e, _data(p));
        _assertUnused(id, 1, beforeBalance);
        p.priceOverride = 250;
        p.hasPriceOverride = false;
        vm.expectRevert(
            abi.encodeWithSelector(
                StreamMintSaleAllowlist.InvalidSaleAllowlistProof.selector, PRICE_COUNTER, payer
            )
        );
        _executeProof(e, _data(p));
        _assertUnused(id, 1, beforeBalance);
        p.hasPriceOverride = true;
        e.authorization.recipient = address(0xB0B);
        _programSign(e);
        vm.expectRevert(
            abi.encodeWithSelector(
                StreamMintSaleAllowlist.InvalidSaleAllowlistProof.selector,
                PRICE_COUNTER,
                address(0xB0B)
            )
        );
        _executeProof(e, _data(p));
        _assertUnused(id, 1, beforeBalance);
        e.authorization.recipient = payer;
        _programSign(e);
        _executeProof(e, _data(p));
    }

    function testPolicyHashCommitsFreeFlagAndOriginalAuthorizationCannotBeTransplanted() public {
        IStreamMintCounterPolicy.AllowlistProof memory p = _proof(true, 250);
        _bind(p, payer, IStreamMintManager.CounterKeyMode.PAYER);
        IStreamNativePricePrograms.PriceProgramConfig memory c = _config(0, 1000, 1000, 5);
        bytes32 id = _allowlist(0, 1000, 1000, false);
        bytes32 original =
            keccak256(abi.encode(keccak256("6529STREAM_NATIVE_PRICE_PROGRAM_CONFIG_V1"), id, c));
        IStreamNativeAllowlistPricePrograms.AllowlistPricePolicy memory policy =
            nativeSale.allowlistPricePolicy(id);
        require(policy.counterId == PRICE_COUNTER && !policy.allowFree, "immutable policy read");
        bytes32 expected = keccak256(
            abi.encode(
                keccak256("6529STREAM_NATIVE_ALLOWLIST_PRICE_PROGRAM_CONFIG_V1"), original, policy
            )
        );
        require(
            nativeSale.priceProgramRecord(id).configHash == expected, "exact wrapped config hash"
        );
        IStreamNativePricePrograms.PriceProgramExecution memory e = _execution(id, 1, 250, 1000);
        policy.allowFree = true;
        e.authorization.saleConfigHash = keccak256(
            abi.encode(
                keccak256("6529STREAM_NATIVE_ALLOWLIST_PRICE_PROGRAM_CONFIG_V1"), original, policy
            )
        );
        _programSign(e);
        e.authorization.saleConfigHash = expected;
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamNativeFixedPriceSaleAdapter.NativeSaleSignatureInvalid.selector,
                vm.addr(PLATFORM_KEY)
            )
        );
        nativeSale.previewAllowlistPriceProgram(e, _data(p));
        _programSign(e);
        _executeProof(e, _data(p));
    }

    function testOldEntryCannotBypassProofAndOrdinaryProgramCannotGainPricePolicy() public {
        IStreamMintCounterPolicy.AllowlistProof memory p = _proof(true, 250);
        _bind(p, payer, IStreamMintManager.CounterKeyMode.PAYER);
        bytes32 id = _allowlist(0, 1000, 1000, false);
        IStreamNativePricePrograms.PriceProgramExecution memory e = _execution(id, 1, 1000, 1000);
        uint256 beforeBalance = payer.balance;
        vm.expectRevert();
        nativeSale.previewPriceProgram(e);
        vm.expectRevert();
        _execute(e);
        _assertUnused(id, 1, beforeBalance);
        bytes32 ordinary = _program(0, 1000, 1000, 5);
        e = _execution(ordinary, 2, 1000, 1000);
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamNativeAllowlistPricePrograms.InvalidAllowlistPricePolicy.selector
            )
        );
        nativeSale.previewAllowlistPriceProgram(e, _data(p));
        _execute(e);
        require(recorder.totalOfficialSettled(address(0)) == 1000, "ordinary entry preserved");
    }

    function testReceiverFailureRollsBackPaidAndFreeOverridesThenExactRetrySucceeds() public {
        _template(payer);
        _priceManager();
        NativeSettlementReceiver receiver = new NativeSettlementReceiver();
        for (uint256 i; i < 2; ++i) {
            uint256 amount = i == 0 ? 0 : 777;
            IStreamMintCounterPolicy.AllowlistProof memory p = _proof(true, amount);
            _bind(p, address(receiver), IStreamMintManager.CounterKeyMode.RECIPIENT);
            bytes32 id = _allowlist(0, 1000, 1000, true);
            IStreamNativePricePrograms.PriceProgramExecution memory e =
                _execution(id, i + 1, amount, 1000);
            e.authorization.recipient = address(receiver);
            _programSign(e);
            receiver.configure(true, address(0), "", address(0));
            uint256 profiles = factory.profileCount();
            uint256 beforeBalance = payer.balance;
            vm.expectRevert();
            _executeProof(e, _data(p));
            require(
                nativeSale.priceProgramRecord(id).mintedQuantity == 0 && manager.nonce() == i
                    && payer.balance == beforeBalance && factory.profileCount() == profiles,
                "rollback supply mint money profile"
            );
            require(
                !nativeSale.authorizationUsed(artist, bytes32(i + 1))
                    && nativeSale.executionIdByNonce(id, i + 1) == 0
                    && recorder.totalOfficialSettled(address(0)) == 0,
                "rollback replay and revenue"
            );
            receiver.configure(false, address(0), "", address(0));
            IStreamNativePricePrograms.PriceProgramResult memory r = _executeProof(e, _data(p));
            require(
                r.tokenId == i + 1 && r.revenueOutcome == (i == 0 ? 1 : 2)
                    && r.chargedAmount == amount,
                "same proof retries successfully"
            );
        }
        require(
            recorder.totalOfficialSettled(address(0)) == 777 && address(escrow).balance == 777,
            "only final paid retry records revenue"
        );
    }
}
