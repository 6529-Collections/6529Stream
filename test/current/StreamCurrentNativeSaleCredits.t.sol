// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    IStreamNativeCustodyAuction
} from "../../smart-contracts/interfaces/stream/auctions/IStreamNativeCustodyAuction.sol";
import "./StreamCurrentNativeSurplus.t.sol";
import { StreamCurrentSecondaryInventoryTest } from "./StreamCurrentSecondaryInventory.t.sol";
import {
    NativeEnglishAuctionFixture,
    IStreamNativeEnglishAuction,
    StreamEnglishAuctionClock,
    StreamNativeEnglishAuctionSupport
} from "../helpers/NativeEnglishAuctionFixture.sol";
import {
    IStreamNativeSaleCredits as Credits
} from "../../smart-contracts/interfaces/stream/mint/IStreamNativeSaleCredits.sol";

library CreditChecks {
    function reconcile(address host) internal view returns (uint256 total, uint256 available) {
        Credits.CreditState memory s = Credits(host).nativeSaleCreditState();
        for (uint256 i; i < s.accountCount; ++i) {
            uint256 cursor;
            bytes32 sale;
            address account;
            do {
                Credits.CreditPage memory p = Credits(host).nativeSaleCreditPage(i, cursor, 1);
                if (cursor != 0) {
                    require(
                        p.saleId == sale && p.account == account && p.claimable == 0,
                        "stable disjoint pages"
                    );
                }
                require(
                    p.account != address(0) && p.saleId != 0 && p.claimable <= p.owed,
                    "original key/owed"
                );
                sale = p.saleId;
                account = p.account;
                total += p.owed;
                available += p.claimable;
                require(p.nextCursor == 0 || p.nextCursor == cursor + 1, "bounded original nonce");
                cursor = p.nextCursor;
            } while (cursor != 0);
        }
        require(
            total == s.totalLiabilities && s.balance >= total, "all original liabilities reconcile"
        );
    }
}

contract CreditClaimReceiver {
    bool public rejecting = true;

    function repair() external {
        rejecting = false;
    }

    receive() external payable {
        require(!rejecting, "claim unavailable");
    }
}

contract StreamCurrentFixedCreditExportTest is StreamCurrentFixedSurplusTest {
    function testFixedIndexKeepsZeroAccountAfterGovernedSweepAndOriginalSafeClaim() external {
        this.testSurplusFixedDonationAndGuardPreserveCreditAndOriginalClaim();
        Credits.CreditState memory s = Credits(address(nativeSale)).nativeSaleCreditState();
        Credits.CreditPage memory p = Credits(address(nativeSale)).nativeSaleCreditPage(0, 0, 1);
        require(
            s.accountCount == 1 && p.account == address(payerSafe) && p.saleId == saleId
                && p.owed == 0 && p.claimable == 0,
            "historical key survives claim and sweep"
        );
        CreditChecks.reconcile(address(nativeSale));
    }

    function testFixedFailedClaimAndByteIdenticalSafeRetryPreserveCreditIndex() external {
        this.deployNativeScenario(false, false);
        (IStreamNativeFixedPriceSaleAdapter.SaleExecutionData memory e,) =
            _execution(1, address(payerSafe));
        uint256 fee = nativeSale.saleRevealQuote(saleId).policy.revealFeePerTokenWei;
        require(
            executeSafe(
                payerSafe,
                keys,
                address(nativeSale),
                1017 + fee,
                abi.encodeCall(nativeSale.purchase, (e)),
                0
            )
        );
        CreditClaimReceiver recipient = new CreditClaimReceiver();
        vm.deal(address(this), 99);
        new NativeSurplusForce{ value: 99 }(payable(address(nativeSale)));
        bytes memory data = abi.encodeCall(nativeSale.claimRefund, (saleId, address(recipient)));
        uint256 nonce = payerSafe.nonce();
        bytes memory signatures = safeThresholdSignature(
            keys,
            payerSafe.getTransactionHash(
                address(nativeSale),
                0,
                data,
                uint8(0),
                0,
                0,
                0,
                address(0),
                payable(address(0)),
                nonce
            )
        );
        bytes memory callData = abi.encodeCall(
            payerSafe.execTransaction,
            (
                address(nativeSale),
                0,
                data,
                uint8(0),
                0,
                0,
                0,
                address(0),
                payable(address(0)),
                signatures
            )
        );
        SurplusCallVm(address(vm)).expectCall(address(recipient), 17, bytes(""), uint64(2));
        vm.expectRevert(abi.encodeWithSignature("Error(string)", "GS013"));
        address(payerSafe).call(callData);
        require(
            payerSafe.nonce() == nonce
                && Credits(address(nativeSale)).nativeSaleCreditState().accountCount == 1,
            "failed claim rolls back Safe/index"
        );
        (uint256 owed, uint256 available) = CreditChecks.reconcile(address(nativeSale));
        require(owed == 17 && available == 17, "same original credit");
        recipient.repair();
        (bool ok,) = address(payerSafe).call(callData);
        require(ok && payerSafe.nonce() == nonce + 1, "identical complete Safe retry");
        (owed, available) = CreditChecks.reconcile(address(nativeSale));
        require(
            owed == 0 && available == 0 && address(nativeSale).balance == 99,
            "only donation remains"
        );
        vm.expectRevert(abi.encodeWithSelector(Credits.NativeSaleCreditPageInvalid.selector));
        Credits(address(nativeSale)).nativeSaleCreditPage(0, 1, 1);
        vm.expectRevert(abi.encodeWithSelector(Credits.NativeSaleCreditPageInvalid.selector));
        Credits(address(nativeSale)).nativeSaleCreditPage(1, 0, 1);
    }
}

contract StreamCurrentDutchCreditExportTest is StreamCurrentDutchSaleTest {
    function testDutchActualCreditCannotBeOmittedAfterOwnSafeWithdrawal() external {
        _consent();
        _purchase(_purchaseData(1, 1000), 1117);
        (uint256 owed, uint256 available) = CreditChecks.reconcile(address(dutchSale));
        require(owed == 17 && available == 17, "exact token delivery excess");
        require(
            executeSafe(
                payerSafe,
                keys,
                address(dutchSale),
                0,
                abi.encodeCall(dutchSale.claimRefund, (dutchId, address(payerSafe))),
                0
            )
        );
        Credits.CreditPage memory p = Credits(address(dutchSale)).nativeSaleCreditPage(0, 0, 64);
        require(
            p.account == address(payerSafe) && p.saleId == dutchId && p.owed == 0,
            "zeroed original Dutch account"
        );
        CreditChecks.reconcile(address(dutchSale));
    }
}

contract StreamCurrentClearingCreditExportTest is StreamCurrentClearingSaleTest {
    function testClearingOriginalLockedReserveAndExcessAreSeparateFromClaimability() external {
        _consent();
        _buy(_purchaseData(1), 1217);
        Credits.CreditPage memory p = Credits(address(clearing)).nativeSaleCreditPage(0, 0, 64);
        uint256 originalClaimable = clearing.refundableBalance(saleId, address(payerSafe));
        require(
            p.claimable == originalClaimable && p.owed > p.claimable,
            "supplement reserve included before fixing"
        );
        CreditChecks.reconcile(address(clearing));
        require(
            executeSafe(
                payerSafe,
                signingKeys,
                address(clearing),
                0,
                abi.encodeCall(clearing.claimRefund, (saleId, address(payerSafe))),
                0
            )
        );
        Credits.CreditPage memory afterClaim =
            Credits(address(clearing)).nativeSaleCreditPage(0, 0, 1);
        require(
            afterClaim.owed == p.owed - originalClaimable && afterClaim.claimable == 0,
            "claim does not erase locked reserve"
        );
        vm.warp(uint256(clearing.saleRecord(saleId).config.absoluteEscapeDeadline) + 1);
        clearing.unlockRefunds(saleId, 0);
        afterClaim = Credits(address(clearing)).nativeSaleCreditPage(0, 0, 1);
        require(afterClaim.owed == afterClaim.claimable, "time escape converts same reserve");
        require(
            executeSafe(
                payerSafe,
                signingKeys,
                address(clearing),
                0,
                abi.encodeCall(clearing.claimRefund, (saleId, address(payerSafe))),
                0
            )
        );
        CreditChecks.reconcile(address(clearing));
        require(
            Credits(address(clearing)).nativeSaleCreditState().accountCount == 1,
            "cleared key stays"
        );
    }
}

contract StreamCurrentWindowCreditExportTest is StreamCurrentRefundWindowTest {
    function testWindowPagesRebuildTwoOriginalDepositsThroughRefundClaimAndEscape() external {
        bytes32 first = _purchase(_purchaseData(1));
        bytes32 second = _purchase(_purchaseData(2));
        Credits.CreditState memory s = Credits(address(refundSale)).nativeSaleCreditState();
        require(s.accountCount == 1 && s.totalLiabilities == 2200, "one key two original deposits");
        Credits.CreditPage memory p = Credits(address(refundSale)).nativeSaleCreditPage(0, 0, 1);
        require(
            p.owed == 1100 && p.claimable == 0 && p.nextCursor == 1, "first original purchase page"
        );
        p = Credits(address(refundSale)).nativeSaleCreditPage(0, 1, 1);
        require(
            p.owed == 1100 && p.claimable == 0 && p.nextCursor == 0, "second original purchase page"
        );
        CreditChecks.reconcile(address(refundSale));
        _exec(payerSafe, address(refundSale), 0, abi.encodeCall(refundSale.refundPurchase, (first)));
        p = Credits(address(refundSale)).nativeSaleCreditPage(0, 0, 1);
        require(p.owed == 1100 && p.claimable == 1100, "pending becomes credit once");
        _exec(
            payerSafe,
            address(refundSale),
            0,
            abi.encodeCall(refundSale.claimRefund, (refundId, payable(address(payerSafe))))
        );
        (uint256 owed, uint256 available) = CreditChecks.reconcile(address(refundSale));
        require(owed == 1100 && available == 0, "only second original pending liability");
        (, uint64 deadline,) = refundSale.purchaseDeadlines(second);
        vm.warp(uint256(deadline) + 1);
        _exec(
            payerSafe,
            address(refundSale),
            0,
            abi.encodeCall(refundSale.unlockRefund, (second, uint8(0)))
        );
        _exec(
            payerSafe,
            address(refundSale),
            0,
            abi.encodeCall(refundSale.claimRefund, (refundId, payable(address(payerSafe))))
        );
        (owed, available) = CreditChecks.reconcile(address(refundSale));
        require(
            owed == 0 && available == 0
                && Credits(address(refundSale)).nativeSaleCreditState().accountCount == 1,
            "all original zero records remain reconstructible"
        );
        vm.expectRevert(abi.encodeWithSelector(Credits.NativeSaleCreditPageInvalid.selector));
        Credits(address(refundSale)).nativeSaleCreditPage(0, 2, 1);
        vm.expectRevert(abi.encodeWithSelector(Credits.NativeSaleCreditPageInvalid.selector));
        Credits(address(refundSale)).nativeSaleCreditPage(0, 0, 65);
    }
}

contract StreamCurrentAuctionCreditExportTest is NativeEnglishAuctionFixture {
    function testOriginalCustodyDigestTransportPreservesEveryFieldAndSeparateDomain() external {
        IStreamNativeCustodyAuction.Acquisition memory a = IStreamNativeCustodyAuction.Acquisition(
            keccak256("config"),
            keccak256("artwork"),
            3,
            (uint256(1) << 200) + 5,
            7,
            11,
            keccak256("original context"),
            address(0x1234),
            (uint256(1) << 180) + 13,
            address(0x5678),
            keccak256("nonce"),
            type(uint64).max - 17
        );
        bytes32 oldHash = house.custodyAcquisitionDigest(a);
        bytes32 preparedHash = house.preparedCustodyAcquisitionDigest(a);
        require(
            oldHash == _independentDigest(a, false) && preparedHash == _independentDigest(a, true)
                && oldHash != preparedHash,
            "original independent complete twelve-field preimages"
        );
        ++a.expectedOperationNonce;
        require(
            house.custodyAcquisitionDigest(a) == _independentDigest(a, false)
                && house.custodyAcquisitionDigest(a) != oldHash,
            "exact original coordinate remains signed"
        );
    }

    function _independentDigest(IStreamNativeCustodyAuction.Acquisition memory a, bool prepared)
        private
        view
        returns (bytes32)
    {
        bytes32 domain = keccak256(
            abi.encode(
                keccak256(
                    "EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"
                ),
                prepared
                    ? keccak256("6529StreamPreparedNativeCustodyAuction")
                    : keccak256("6529StreamNativeCustodyAuction"),
                keccak256("1"),
                block.chainid,
                address(house)
            )
        );
        bytes32 kind = prepared
            ? keccak256(
                "PreparedNativeCustodyAcquisition(bytes32 configHash,bytes32 tokenDataHash,uint256 expectedSaleNonce,uint256 expectedTokenId,uint256 expectedCollectionSerial,uint256 expectedOperationNonce,bytes32 contextHash,address executor,uint256 revealFeeDeposit,address artist,bytes32 nonce,uint64 deadline)"
            )
            : keccak256(
                "NativeCustodyAcquisition(bytes32 configHash,bytes32 tokenDataHash,uint256 expectedSaleNonce,uint256 expectedTokenId,uint256 expectedCollectionSerial,uint256 expectedOperationNonce,bytes32 contextHash,address executor,uint256 revealFeeDeposit,address artist,bytes32 nonce,uint64 deadline)"
            );
        bytes32 body = keccak256(
            abi.encode(
                kind,
                a.configHash,
                a.tokenDataHash,
                a.expectedSaleNonce,
                a.expectedTokenId,
                a.expectedCollectionSerial,
                a.expectedOperationNonce,
                a.contextHash,
                a.executor,
                a.revealFeeDeposit,
                a.artist,
                a.nonce,
                a.deadline
            )
        );
        return keccak256(abi.encodePacked(hex"1901", domain, body));
    }

    function _newAuction() private returns (bytes32 id) {
        IStreamNativeEnglishAuction.Configuration memory c;
        c.collectionId = 1;
        c.phaseId = PHASE;
        c.mintAtSettlement = true;
        c.artworkCommitment = keccak256("credit artwork");
        c.mintCommitment = keccak256("credit mint");
        c.poster = address(this);
        c.reservePrice = 1000;
        c.minIncrementBps = 500;
        c.clock = StreamEnglishAuctionClock.Configuration(
            uint64(block.timestamp), uint64(block.timestamp + 3600), 0, 600, 600, 3600, false, false
        );
        c.expectedPrimaryPolicyHash = StreamNativeEnglishAuctionSupport.profilePolicy(resolver, 1);
        c.primaryPolicyMode = 1;
        c.settlementWindow = 86400;
        c.mintPolicyHash = manager.phasePolicyHash(1, PHASE);
        IStreamNativeEnglishAuction.CreationAuthorization memory a =
            IStreamNativeEnglishAuction.CreationAuthorization(
                house.auctionConfigurationHash(c),
                vm.addr(SIGNER_KEY),
                bytes32(uint256(1)),
                uint64(block.timestamp + 1000)
            );
        bytes32 digest = house.creationAuthorizationDigest(a);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(AUCTION_PLATFORM_KEY, digest);
        bytes memory platformSignature = abi.encodePacked(r, s, v);
        (v, r, s) = vm.sign(SIGNER_KEY, digest);
        return house.registerAuction(
            c, bytes("credit artwork"), a, platformSignature, abi.encodePacked(r, s, v)
        );
    }

    function testAuctionOriginalSafeOutbidCreditAndWinningDepositBothExportUntilClaim() external {
        bytes32 id = _newAuction();
        bytes32 sale = house.auction(id).saleId;
        uint256[] memory keys = new uint256[](2);
        keys[0] = 0x8831;
        keys[1] = 0x8832;
        OfficialSafe payer =
            createOfficialSafe(deploySafeComponents("1.4.1"), safeOwnerAddresses(keys), 2, 903);
        vm.deal(address(payer), 1 ether);
        uint256 fee = entropy.fee();
        require(
            executeSafe(
                payer,
                keys,
                address(house),
                1000 + fee,
                abi.encodeCall(house.bid, (id, address(0))),
                0
            )
        );
        Credits.CreditPage memory p = Credits(address(house)).nativeSaleCreditPage(0, 0, 1);
        require(p.owed == 1000 + fee && p.claimable == 0, "winning Safe deposit is owed but locked");
        address next = address(0xA11CE);
        vm.deal(next, 1 ether);
        vm.prank(next);
        house.bid{ value: 1100 + fee }(id, address(0));
        CreditChecks.reconcile(address(house));
        p = Credits(address(house)).nativeSaleCreditPage(0, 0, 1);
        require(p.claimable == 1000 + fee, "same Safe key converted by outbid");
        require(
            executeSafe(
                payer,
                keys,
                address(house),
                0,
                abi.encodeCall(house.claimRefund, (sale, payable(address(payer)))),
                0
            )
        );
        (uint256 owed, uint256 available) = CreditChecks.reconcile(address(house));
        require(owed == 1100 + fee && available == 0, "second winner retained after first exit");
        (uint64 end,,,) = house.auctionDeadlines(id);
        vm.warp(uint256(end) + 1);
        artists.setState(4);
        house.unlockNoMint(id, 4);
        vm.prank(next);
        house.claimRefund(sale, payable(next));
        CreditChecks.reconcile(address(house));
        require(
            Credits(address(house)).nativeSaleCreditState().accountCount == 2,
            "both zeroed historical payers retained"
        );
    }
}

contract StreamCurrentPrivateCreditExportTest is StreamCurrentSecondaryInventoryTest {
    function testInventoryAllOriginalCreditClassesSurvivePrimaryRevocationAndRetry() external {
        (bytes32 id, uint256[] memory ids) = _opened(1, 1);
        (address receiver, uint256 amount,,) = inventory.inventoryRoyaltyQuote(id, ids[0]);
        calls.expectCall(receiver, amount, bytes(""), uint64(2));
        calls.mockCallRevert(
            receiver, amount, bytes(""), abi.encodeWithSignature("Error(string)", "reject royalty")
        );
        _buy(id, ids[0], 1017);
        calls.clearMockedCalls();
        (uint256 owed, uint256 available) = CreditChecks.reconcile(address(inventory));
        require(
            owed == 1017 && available == 1017 && core.ownerOf(ids[0]) == address(customer),
            "original excess proceeds and failed royalty all indexed"
        );
        platform.contest(3);
        _status(address(inventory), ModuleRegistryStatus.INCIDENT_REVOKED);
        require(
            inventory.retryInventoryRoyalty(id, receiver), "historical royalty retry independent"
        );
        require(
            executeSafe(
                collector,
                collectorKeys,
                address(inventory),
                0,
                abi.encodeCall(inventory.claimRefund, (id, address(collector))),
                0
            )
        );
        require(
            executeSafe(
                customer,
                customerKeys,
                address(inventory),
                0,
                abi.encodeCall(inventory.claimRefund, (id, address(customer))),
                0
            )
        );
        (owed, available) = CreditChecks.reconcile(address(inventory));
        require(
            owed == 0 && available == 0
                && Credits(address(inventory)).nativeSaleCreditState().accountCount == 3,
            "all three historical keys survive claims and revoked admission"
        );
    }
}
