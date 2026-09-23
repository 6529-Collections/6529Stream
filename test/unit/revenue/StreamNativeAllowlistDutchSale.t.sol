// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../../helpers/DutchSaleTestBase.sol";

interface DutchAllowlistReadVm {
    function mockCall(address target, bytes calldata data, bytes calldata result) external;
}

/// @dev Four typed counter-read seams supplement the existing explicit Manager fixture.
///      The sale, signatures, shared proof reader, registry and revenue/credit paths are real.
///      Actual Manager/Ledger cap consumption is covered by the mint suites, not this fixture.
contract StreamNativeAllowlistDutchSaleTest is DutchSaleTestBase {
    bytes32 private constant PRICE_COUNTER = keccak256("Dutch price tier");

    function _proof(bool overridden, uint256 price)
        private
        pure
        returns (IStreamMintCounterPolicy.AllowlistProof memory p)
    {
        p.maxCount = 7;
        p.hasPriceOverride = overridden;
        p.priceOverride = price;
        p.proof = new bytes32[](0);
    }

    function _resolverData(IStreamMintCounterPolicy.AllowlistProof memory p)
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
        address subject,
        IStreamMintManager.CounterKeyMode mode
    ) private {
        bytes32 root = keccak256(
            bytes.concat(
                keccak256(
                    abi.encode(
                        keccak256("6529STREAM_MINT_ALLOWLIST_LEAF_V1"),
                        block.chainid,
                        address(refundManager),
                        uint256(1),
                        PHASE,
                        PRICE_COUNTER,
                        subject,
                        p.maxCount,
                        p.hasPriceOverride,
                        p.priceOverride
                    )
                )
            )
        );
        IStreamMintCounterPolicy.Definition memory definition = IStreamMintCounterPolicy.Definition(
            IStreamMintCounterPolicy.CounterScope.PHASE,
            mode,
            root,
            keccak256("Dutch list artifact")
        );
        bytes32 definitionHash =
            keccak256(abi.encode(keccak256("6529STREAM_MINT_COUNTER_DEFINITION_V1"), definition));
        IStreamMintManager.MintCounterConfig memory counter = IStreamMintManager.MintCounterConfig(
            true,
            mode,
            IStreamMintLedger.CounterCapMode.MERKLE_STATIC,
            IStreamMintLedger.CounterDeltaMode.STATIC,
            10,
            1,
            definitionHash
        );
        bytes32[] memory ids = new bytes32[](1);
        ids[0] = PRICE_COUNTER;
        DutchAllowlistReadVm reads = DutchAllowlistReadVm(address(vm));
        reads.mockCall(
            address(refundManager),
            abi.encodeCall(IStreamMintReads.mintLedger, ()),
            abi.encode(address(refundManager))
        );
        reads.mockCall(
            address(refundManager),
            abi.encodeCall(IStreamMintReads.phaseCounterIds, (uint256(1), PHASE)),
            abi.encode(ids)
        );
        reads.mockCall(
            address(refundManager),
            abi.encodeCall(IStreamMintReads.counterConfig, (uint256(1), PHASE, PRICE_COUNTER)),
            abi.encode(counter)
        );
        reads.mockCall(
            address(refundManager),
            abi.encodeCall(
                IStreamMintCounterPolicy.counterDefinitionForManager,
                (address(refundManager), definitionHash)
            ),
            abi.encode(true, definition)
        );
    }

    function _registerAllowlist(bool declaredFree) private {
        IStreamNativeDutchSale.DutchSaleConfig memory config = _dutchConfig();
        config.declaredFree = declaredFree;
        dutchId = dutchSale.registerAllowlistDutchSale(config, PRICE_COUNTER);
    }

    function _purchaseProof(
        IStreamNativeDutchSale.DutchPurchaseData memory d,
        bytes memory proof,
        uint256 value
    ) private returns (IStreamNativeDutchSale.DutchPurchaseResult memory) {
        vm.prank(d.authorization.payer);
        return dutchSale.purchaseWithAllowlist{ value: value }(d, proof);
    }

    function _assertUnused(uint256 balanceBefore) private view {
        require(dutchSale.saleRecord(dutchId).mintedQuantity == 0, "sale quantity changed");
        require(!dutchSale.authorizationUsed(artist, bytes32(uint256(1))), "authorization consumed");
        require(dutchSale.executionIdByNonce(dutchId, 1) == 0, "execution consumed");
        require(
            refundManager.nonce() == 0 && payer.balance == balanceBefore, "mint or payer changed"
        );
        require(
            recorder.totalOfficialSettled(address(0)) == 0 && wallet.balance == 0
                && refundEntropy.revealFeeEscrow(1) == 0,
            "payment or fee changed"
        );
        require(
            dutchSale.refundLiability() == 0 && dutchSale.refundCredit(payer) == 0
                && dutchSale.refundableBalance(dutchId, payer) == 0
                && address(dutchSale).balance == 0,
            "buyer credit changed"
        );
    }

    function _expectedRoot(IStreamNativeDutchSale.DutchPurchaseData memory d, bytes memory proof)
        private
        view
        returns (bytes32)
    {
        IStreamMintManager.MintBatch memory b;
        b.collectionId = 1;
        b.phaseId = PHASE;
        b.payer = d.authorization.payer;
        b.initialRecipients = new address[](1);
        b.initialRecipients[0] = d.authorization.recipient;
        b.beneficiaries = new address[](1);
        b.beneficiaries[0] = d.authorization.recipient;
        b.tokenData = new bytes[](1);
        b.tokenData[0] = d.tokenData;
        b.mintCommitments = new bytes32[](1);
        b.mintCommitments[0] = d.authorization.mintCommitment;
        b.expectedPolicyHash = refundManager.currentPolicy();
        b.contextHash = dutchSale.authorizationDigest(d.authorization);
        b.authorizationId = keccak256(
            abi.encode(keccak256("6529STREAM_MINT_TICKET_AUTHORIZATION_V1"), b.contextHash)
        );
        b.resolverData = proof;
        return keccak256(abi.encode(b, address(dutchSale), refundManager.nonce()));
    }

    function testRegistrationWrapsOriginalConfigAndDisclosesCounterAndFreeDeclaration() public {
        _bind(_proof(true, 0), payer, IStreamMintManager.CounterKeyMode.PAYER);
        vm.recordLogs();
        _registerAllowlist(true);
        Vm.Log[] memory logs = vm.getRecordedLogs();
        IStreamNativeDutchSale.DutchSaleRecord memory record = dutchSale.saleRecord(dutchId);
        bytes32 originalHash = keccak256(
            abi.encode(
                keccak256("6529STREAM_NATIVE_DUTCH_CONFIG_V1"),
                dutchId,
                record.config,
                record.priceScheduleHash,
                record.expectedPrimaryPolicyHash,
                record.primaryAssignmentHash,
                uint8(0),
                address(0)
            )
        );
        bytes32 expected = keccak256(
            abi.encode(
                keccak256("6529STREAM_NATIVE_ALLOWLIST_DUTCH_CONFIG_V1"),
                originalHash,
                PRICE_COUNTER
            )
        );
        require(
            record.configHash == expected
                && dutchSale.allowlistPriceCounter(dutchId) == PRICE_COUNTER,
            "creation policy not committed"
        );
        require(
            dutchSale.supportsInterface(type(IStreamNativeAllowlistDutchSale).interfaceId)
                && dutchSale.supportsInterface(type(IStreamNativeDutchSale).interfaceId),
            "retained interfaces"
        );
        (uint256 collection, bytes32 consentHash) = dutchSale.saleConsentFacts(dutchId);
        require(
            collection == 1 && consentHash == expected, "Artist consent must bind wrapped config"
        );
        uint256 emitted;
        for (uint256 i; i < logs.length; ++i) {
            if (
                logs[i].emitter != address(dutchSale)
                    || logs[i].topics[0]
                        != keccak256(
                            "DutchAllowlistPricePolicy(bytes32,bytes32,uint16,bool,bytes32)"
                        )
            ) continue;
            require(
                logs[i].topics.length == 3 && logs[i].topics[1] == dutchId
                    && logs[i].topics[2] == PRICE_COUNTER,
                "price policy event topics"
            );
            (uint16 schema, bool free, bytes32 hash) =
                abi.decode(logs[i].data, (uint16, bool, bytes32));
            require(schema == 1 && free && hash == expected, "price policy event data");
            ++emitted;
        }
        require(emitted == 1, "one price policy disclosure");
    }

    function testCeilingBelowScheduleRetainsSignedMaximumProofFeeAndExcess() public {
        IStreamMintCounterPolicy.AllowlistProof memory p = _proof(true, 600);
        _bind(p, payer, IStreamMintManager.CounterKeyMode.PAYER);
        _registerAllowlist(false);
        IStreamNativeDutchSale.DutchPurchaseData memory d = _dutchData(1, payer, address(0xBEEF));
        d.authorization.unitPrice = 700;
        _signDutch(d);
        bytes memory proof = _resolverData(p);
        bytes32 root = _expectedRoot(d, proof);
        bytes32 digest = dutchSale.authorizationDigest(d.authorization);
        uint256 balanceBefore = payer.balance;
        IStreamNativeDutchSale.DutchPurchaseResult memory r = _purchaseProof(d, proof, 900);
        require(
            r.operationRoot == root && r.chargedAmount == 600 && r.revenueOutcome == 2
                && r.revealFeeForwarded == 100 && r.excessCredited == 200,
            "ceiling, proof or fee changed"
        );
        require(
            wallet.balance == 600 && recorder.totalOfficialSettled(address(0)) == 600
                && refundEntropy.revealFeeEscrow(1) == 100,
            "exact paid lanes"
        );
        require(
            refundManager.lastContextHash() == digest
                && refundManager.lastAuthorizationId()
                    == keccak256(
                        abi.encode(keccak256("6529STREAM_MINT_TICKET_AUTHORIZATION_V1"), digest)
                    ),
            "signed maximum was rewritten"
        );
        require(
            dutchSale.refundableBalance(dutchId, payer) == 200
                && dutchSale.refundLiability() == 200,
            "excess belongs to original payer"
        );
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamNativeDutchSale.DutchAuthorizationUsed.selector, artist, bytes32(uint256(1))
            )
        );
        _purchaseProof(d, proof, 900);
        vm.prank(payer);
        dutchSale.claimRefund(dutchId, payer);
        require(
            payer.balance == balanceBefore - 700 && dutchSale.refundLiability() == 0,
            "net price plus captured fee"
        );
    }

    function testFullWidthCeilingAboveScheduleChargesCurrentSchedule() public {
        IStreamMintCounterPolicy.AllowlistProof memory p = _proof(true, type(uint256).max);
        _bind(p, payer, IStreamMintManager.CounterKeyMode.RECIPIENT);
        _registerAllowlist(false);
        vm.warp(1005);
        IStreamNativeDutchSale.DutchPurchaseData memory d = _dutchData(1, payer, payer);
        IStreamNativeDutchSale.DutchPurchaseResult memory r =
            _purchaseProof(d, _resolverData(p), 650);
        require(
            r.chargedAmount == 550 && r.excessCredited == 0 && wallet.balance == 550,
            "full-width ceiling must not replace schedule"
        );
    }

    function testLeafWithoutOverrideRetainsSignedMaximumAndOriginalSchedulePrice() public {
        IStreamMintCounterPolicy.AllowlistProof memory p = _proof(false, 0);
        _bind(p, payer, IStreamMintManager.CounterKeyMode.PAYER);
        _registerAllowlist(false);
        IStreamNativeDutchSale.DutchPurchaseData memory d = _dutchData(1, payer, payer);
        d.authorization.unitPrice = 999;
        _signDutch(d);
        uint256 balanceBefore = payer.balance;
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamNativeDutchSale.DutchPaymentBelowPrice.selector, uint256(999), uint256(1000)
            )
        );
        _purchaseProof(d, _resolverData(p), 1100);
        _assertUnused(balanceBefore);
        d.authorization.unitPrice = 1000;
        _signDutch(d);
        IStreamNativeDutchSale.DutchPurchaseResult memory r =
            _purchaseProof(d, _resolverData(p), 1100);
        require(r.chargedAmount == 1000 && wallet.balance == 1000, "no override schedule fallback");
    }

    function testStandardDutchPositiveCeilingMayBeBelowScheduleRestingPrice() public {
        IStreamMintCounterPolicy.AllowlistProof memory p = _proof(true, 50);
        _bind(p, payer, IStreamMintManager.CounterKeyMode.PAYER);
        _registerAllowlist(false);
        IStreamNativeDutchSale.DutchPurchaseResult memory r =
            _purchaseProof(_dutchData(1, payer, payer), _resolverData(p), 150);
        require(
            r.chargedAmount == 50 && wallet.balance == 50,
            "clearing-only floor applied to standard Dutch sale"
        );
    }

    function testAuthenticatedCeilingReplacesSignedMaximumWithExactProofFundingRetry() public {
        IStreamMintCounterPolicy.AllowlistProof memory p = _proof(true, 600);
        _bind(p, payer, IStreamMintManager.CounterKeyMode.PAYER);
        _registerAllowlist(false);
        IStreamNativeDutchSale.DutchPurchaseData memory d = _dutchData(1, payer, payer);
        d.authorization.unitPrice = 599;
        _signDutch(d);
        bytes memory proof = _resolverData(p);
        bytes32 exactPurchase = keccak256(abi.encode(d, proof));
        bytes32 digest = dutchSale.authorizationDigest(d.authorization);
        bytes32 expected = _expectedRoot(d, proof);
        uint256 balanceBefore = payer.balance;
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamNativeDutchSale.DutchPaymentBelowPrice.selector, uint256(599), uint256(600)
            )
        );
        _purchaseProof(d, proof, 699);
        _assertUnused(balanceBefore);
        IStreamNativeDutchSale.DutchPurchaseResult memory r = _purchaseProof(d, proof, 900);
        require(
            keccak256(abi.encode(d, proof)) == exactPurchase && d.authorization.unitPrice == 599,
            "retry must retain every signed and proven byte"
        );
        require(
            r.operationRoot == expected && refundManager.lastContextHash() == digest
                && refundManager.lastAuthorizationId()
                    == keccak256(
                        abi.encode(keccak256("6529STREAM_MINT_TICKET_AUTHORIZATION_V1"), digest)
                    ),
            "original signed ceiling remains in digest and mint request"
        );
        require(
            r.chargedAmount == 600 && r.revealFeeForwarded == 100 && r.excessCredited == 200
                && wallet.balance == 600 && recorder.totalOfficialSettled(address(0)) == 600
                && refundEntropy.revealFeeEscrow(1) == 100
                && dutchSale.refundableBalance(dutchId, payer) == 200
                && dutchSale.refundLiability() == 200 && refundManager.nonce() == 1,
            "proven ceiling, live fee and buyer funding maximum"
        );
    }

    function testAuthenticatedCeilingDoesNotPermitMutatingTheSignedMaximum() public {
        IStreamMintCounterPolicy.AllowlistProof memory p = _proof(true, 600);
        _bind(p, payer, IStreamMintManager.CounterKeyMode.PAYER);
        _registerAllowlist(false);
        IStreamNativeDutchSale.DutchPurchaseData memory d = _dutchData(1, payer, payer);
        d.authorization.unitPrice = 599;
        _signDutch(d);
        bytes memory proof = _resolverData(p);
        bytes32 exactPurchase = keccak256(abi.encode(d, proof));
        uint256 balanceBefore = payer.balance;
        d.authorization.unitPrice = 598;
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamNativeDutchSale.DutchSignatureInvalid.selector, vm.addr(PLATFORM_KEY)
            )
        );
        _purchaseProof(d, proof, 700);
        _assertUnused(balanceBefore);
        d.authorization.unitPrice = 599;
        require(keccak256(abi.encode(d, proof)) == exactPurchase, "restore original signed bytes");
        require(_purchaseProof(d, proof, 700).chargedAmount == 600, "original signature retry");
    }

    function testOrdinaryDutchWithoutMerklePolicyRetainsSignedMaximum() public {
        require(dutchSale.allowlistPriceCounter(dutchId) == 0, "ordinary sale profile");
        IStreamNativeDutchSale.DutchPurchaseData memory d = _dutchData(1, payer, payer);
        d.authorization.unitPrice = 999;
        _signDutch(d);
        uint256 balanceBefore = payer.balance;
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamNativeDutchSale.DutchPaymentBelowPrice.selector, uint256(999), uint256(1000)
            )
        );
        vm.prank(payer);
        dutchSale.purchase{ value: 1100 }(d);
        _assertUnused(balanceBefore);
        d.authorization.unitPrice = 1000;
        _signDutch(d);
        vm.prank(payer);
        require(dutchSale.purchase{ value: 1100 }(d).chargedAmount == 1000, "ordinary cap retained");
    }

    function testUndeclaredZeroOverrideRejectsWithoutPaymentOrReplayWrites() public {
        IStreamMintCounterPolicy.AllowlistProof memory p = _proof(true, 0);
        _bind(p, payer, IStreamMintManager.CounterKeyMode.PAYER);
        _registerAllowlist(false);
        IStreamNativeDutchSale.DutchPurchaseData memory d = _dutchData(1, payer, payer);
        uint256 balanceBefore = payer.balance;
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamNativeAllowlistDutchSale.SalePriceOverrideZeroUndeclared.selector, dutchId
            )
        );
        _purchaseProof(d, _resolverData(p), 1100);
        _assertUnused(balanceBefore);
    }

    function testDeclaredZeroOverrideSkipsRightsAndRevenueButFundsRevealAndCreditsExcess() public {
        IStreamMintCounterPolicy.AllowlistProof memory p = _proof(true, 0);
        _bind(p, payer, IStreamMintManager.CounterKeyMode.PAYER);
        _registerAllowlist(true);
        IStreamNativeDutchSale.DutchPurchaseData memory d = _dutchData(1, payer, payer);
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
        IStreamNativeDutchSale.DutchPurchaseResult memory r =
            _purchaseProof(d, _resolverData(p), 200);
        require(
            r.revenueOutcome == 1 && r.chargedAmount == 0 && r.settlementKey == 0 && !r.escrowed
                && r.revealFeeForwarded == 100 && r.excessCredited == 100 && r.tokenId != 0,
            "free tier result"
        );
        require(
            recorder.totalOfficialSettled(address(0)) == 0 && wallet.balance == 0
                && factory.profileCount() == profiles && refundEntropy.revealFeeEscrow(1) == 100,
            "free tier crossed official revenue or rights"
        );
        require(dutchSale.refundableBalance(dutchId, payer) == 100, "free excess credit");
    }

    function testPriceProofTamperingAndRecipientSubstitutionRollbackThenRetry() public {
        IStreamMintCounterPolicy.AllowlistProof memory p = _proof(true, 600);
        _bind(p, payer, IStreamMintManager.CounterKeyMode.RECIPIENT);
        _registerAllowlist(false);
        IStreamNativeDutchSale.DutchPurchaseData memory d = _dutchData(1, payer, payer);
        uint256 balanceBefore = payer.balance;
        p.priceOverride = 599;
        vm.expectRevert(
            abi.encodeWithSelector(
                StreamMintSaleAllowlist.InvalidSaleAllowlistProof.selector, PRICE_COUNTER, payer
            )
        );
        _purchaseProof(d, _resolverData(p), 1100);
        _assertUnused(balanceBefore);
        p.hasPriceOverride = false;
        p.priceOverride = 0;
        vm.expectRevert(
            abi.encodeWithSelector(
                StreamMintSaleAllowlist.InvalidSaleAllowlistProof.selector, PRICE_COUNTER, payer
            )
        );
        _purchaseProof(d, _resolverData(p), 1100);
        _assertUnused(balanceBefore);
        p.hasPriceOverride = true;
        p.priceOverride = 600;
        d.authorization.recipient = address(0xBEEF);
        _signDutch(d);
        vm.expectRevert(
            abi.encodeWithSelector(
                StreamMintSaleAllowlist.InvalidSaleAllowlistProof.selector,
                PRICE_COUNTER,
                address(0xBEEF)
            )
        );
        _purchaseProof(d, _resolverData(p), 1100);
        _assertUnused(balanceBefore);
        d.authorization.recipient = payer;
        _signDutch(d);
        require(_purchaseProof(d, _resolverData(p), 700).chargedAmount == 600, "valid leaf retry");
    }

    function testMissingProofOldEntryAndNewEntryOnOrdinarySaleReject() public {
        bytes32 ordinary = dutchId;
        IStreamMintCounterPolicy.AllowlistProof memory p = _proof(true, 600);
        _bind(p, payer, IStreamMintManager.CounterKeyMode.PAYER);
        _registerAllowlist(false);
        IStreamNativeDutchSale.DutchPurchaseData memory d = _dutchData(1, payer, payer);
        uint256 balanceBefore = payer.balance;
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamNativeAllowlistDutchSale.InvalidAllowlistDutchPolicy.selector
            )
        );
        vm.prank(payer);
        dutchSale.purchase{ value: 1100 }(d);
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamNativeAllowlistDutchSale.InvalidAllowlistDutchPolicy.selector
            )
        );
        _purchaseProof(d, "", 1100);
        _assertUnused(balanceBefore);
        dutchId = ordinary;
        d = _dutchData(1, payer, payer);
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamNativeAllowlistDutchSale.InvalidAllowlistDutchPolicy.selector
            )
        );
        _purchaseProof(d, _resolverData(p), 1100);
        _assertUnused(balanceBefore);
        SaleFundingFaultVm(address(vm)).clearMockedCalls();
        vm.prank(payer);
        require(
            dutchSale.purchase{ value: 1100 }(d).chargedAmount == 1000,
            "ordinary entry changed by optional proof policy"
        );
    }

    function testRequiredArtistConsentStillPrecedesProofValidationAndPayment() public {
        IStreamMintCounterPolicy.AllowlistProof memory p = _proof(true, 600);
        _bind(p, payer, IStreamMintManager.CounterKeyMode.PAYER);
        refundArtist.configureSaleConsent(true, 0);
        _registerAllowlist(false);
        IStreamNativeDutchSale.DutchPurchaseData memory d = _dutchData(1, payer, payer);
        uint256 balanceBefore = payer.balance;
        p.priceOverride = 599;
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamNativeDutchSale.DutchDependencyInvalid.selector, address(refundArtist)
            )
        );
        _purchaseProof(d, _resolverData(p), 1100);
        _assertUnused(balanceBefore);
        refundArtist.recordTestSaleConsent(
            address(dutchSale), 1, dutchId, d.authorization.saleConfigHash, true
        );
        vm.expectRevert(
            abi.encodeWithSelector(
                StreamMintSaleAllowlist.InvalidSaleAllowlistProof.selector, PRICE_COUNTER, payer
            )
        );
        _purchaseProof(d, _resolverData(p), 1100);
        _assertUnused(balanceBefore);
        p.priceOverride = 600;
        require(
            _purchaseProof(d, _resolverData(p), 700).chargedAmount == 600,
            "consented healthy control"
        );
    }

    function testRegistrationRejectsMissingCounterWithoutConsumingSaleNonce() public {
        _bind(_proof(false, 0), payer, IStreamMintManager.CounterKeyMode.PAYER);
        IStreamNativeDutchSale.DutchSaleConfig memory config = _dutchConfig();
        bytes32 missing = keccak256("unconfigured price counter");
        uint256 nonce = dutchSale.nextSaleNonce();
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamNativeAllowlistDutchSale.InvalidAllowlistDutchPolicy.selector
            )
        );
        dutchSale.registerAllowlistDutchSale(config, bytes32(0));
        vm.expectRevert(
            abi.encodeWithSelector(
                StreamMintSaleAllowlist.InvalidSaleAllowlistPolicy.selector, missing
            )
        );
        dutchSale.registerAllowlistDutchSale(config, missing);
        require(dutchSale.nextSaleNonce() == nonce, "invalid counter consumed sale nonce");
    }

    function testMintFailureAfterPricedProofRestoresRevenueCreditsAndReplay() public {
        IStreamMintCounterPolicy.AllowlistProof memory p = _proof(true, 600);
        _bind(p, payer, IStreamMintManager.CounterKeyMode.PAYER);
        _registerAllowlist(false);
        IStreamNativeDutchSale.DutchPurchaseData memory d = _dutchData(1, payer, payer);
        uint256 balanceBefore = payer.balance;
        refundManager.setMode(1);
        vm.expectRevert(abi.encodeWithSignature("Error(string)", "mint rejected"));
        _purchaseProof(d, _resolverData(p), 900);
        _assertUnused(balanceBefore);
        refundManager.setMode(0);
        IStreamNativeDutchSale.DutchPurchaseResult memory r =
            _purchaseProof(d, _resolverData(p), 900);
        require(
            r.chargedAmount == 600 && r.excessCredited == 200 && wallet.balance == 600
                && dutchSale.refundLiability() == 200,
            "same proof failed after downstream recovery"
        );
    }

    function testLinkedWorkerCannotRegisterByDirectCallAndHostKeepsOriginalNonce() public {
        StreamDutchSaleSupport.Context memory context = StreamDutchSaleSupport.Context(
            address(core),
            IStreamMintManager(address(refundManager)),
            resolver,
            vm.addr(PLATFORM_KEY),
            artists,
            address(artists).codehash,
            refundEntropy,
            address(refundEntropy).codehash,
            dutchSale.gasParameter(keccak256("6529STREAM_GGP_SALE_ERC1271_GAS_LIMIT")),
            dutchSale.gasParameter(keccak256("6529STREAM_GGP_SALE_ARTIST_AUTHORITY_GAS_LIMIT"))
        );
        uint256 nonce = dutchSale.nextSaleNonce();
        bytes memory data = abi.encodeWithSelector(
            StreamNativeDutchSaleWorker.registerSale.selector,
            uint256(0),
            uint256(1),
            context,
            address(registry),
            _dutchConfig(),
            bytes32(0),
            nonce
        );
        vm.recordLogs();
        (bool ok, bytes memory reason) = address(StreamNativeDutchSaleWorker).call(data);
        require(!ok && reason.length == 0, "Solidity mutable-library CALL guard");
        require(
            vm.getRecordedLogs().length == 0 && dutchSale.nextSaleNonce() == nonce,
            "direct worker call changed host or emitted registration"
        );
        bytes32 expected = dutchSale.saleIdFor(1, PHASE, nonce);
        bytes32 id = dutchSale.registerDutchSale(_dutchConfig());
        require(
            id == expected && dutchSale.nextSaleNonce() == nonce + 1
                && dutchSale.saleRecord(id).saleNonce == nonce,
            "guarded host registration changed nonce"
        );
    }

    function testLinkedRecordReadPreservesEmptyRecordAbi() public view {
        IStreamNativeDutchSale.DutchSaleRecord memory empty;
        (bool ok, bytes memory data) = address(dutchSale)
            .staticcall(
                abi.encodeCall(
                    IStreamNativeDutchSale.saleRecord, (keccak256("absent Dutch record"))
                )
            );
        require(ok && keccak256(data) == keccak256(abi.encode(empty)), "empty record wire encoding");
    }
}
