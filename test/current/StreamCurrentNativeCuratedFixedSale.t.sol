// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./helpers/NativeCuratedSaleFixture.sol";
import {
    IStreamNativeCuratedCommitments as Deposits
} from "../../smart-contracts/interfaces/stream/mint/IStreamNativeCuratedCommitments.sol";

interface CuratedCurrentVm {
    function expectCall(address callee, uint256 value, bytes calldata data) external;
}

contract CuratedFundedReentryReceiver is IERC721Receiver {
    address public target;
    bytes public callData;
    bytes public rejectedData;
    bool public rejected;

    function configure(address target_, bytes calldata callData_) external {
        target = target_;
        callData = callData_;
    }

    function onERC721Received(address, address, uint256, bytes calldata) external returns (bytes4) {
        (bool ok, bytes memory result) = target.call{ value: 1100 }(callData);
        rejected = !ok;
        rejectedData = result;
        return IERC721Receiver.onERC721Received.selector;
    }
}

/// @notice Full current prepared-purchase graph. Only Artist/entropy/governance ceremonies are
/// controlled boundaries, as documented by NativeCuratedSaleFixture; all economic modules are real.
contract StreamCurrentNativeCuratedFixedSaleTest is NativeCuratedSaleFixture {
    address private _phaseMutationReceiver;

    function setUp() public override {
        super.setUp();
        StreamNativeCuratedSaleBase.DeploymentConfig memory deployment = _curatedDeployment();
        // Callback regressions exercise real owner-authorized Manager policy writes after delivery.
        deployment.parameters[3].genesisValue = 2_000_000;
        fixedSale = new StreamNativeCuratedFixedPriceSale(deployment);
        _registerCuratedHost(address(fixedSale));
    }

    function testPublicDistinctWorksShareCreationIdentityAndConsumeSeparatePurchases() public {
        CuratedPlan memory p = _open(Curated.SelectionMode.PUBLIC);
        vm.warp(p.config.startsAt);
        Curated.ExecutionRecord memory one = _buy(p, 0, payer, payer, 1, 1100);
        Curated.ExecutionRecord memory two = _buy(p, 1, payer, payer, 2, 1100);
        _assertCuratedExecution(p, 0, one);
        _assertCuratedExecution(p, 1, two);
        bytes32 first = fixedSale.purchaseIdFor(p.saleId, payer, 1);
        bytes32 second = fixedSale.purchaseIdFor(p.saleId, payer, 2);
        require(
            first != second && one.settlementKey != two.settlementKey && _consumed(first)
                && _consumed(second),
            "per-purchase official replay records"
        );
        require(
            !recorder.preparedNativeSaleConsumed(
                recorder.preparedNativeSaleKey(address(fixedSale), p.saleId, p.nonce)
            ),
            "recurring sale does not consume original creation identity"
        );
        require(
            fixedSale.saleRecord(p.saleId).saleNonce == p.nonce
                && fixedSale.nextSaleNonce() == p.nonce + 1 && one.tokenId == 1 && two.tokenId == 2
                && core.collectionNextSerial(1) == 3 && core.tokenData(1).length == 0
                && manager.nextOperationNonce() == 2,
            "one original sale and sequential actual selected token bytes"
        );
        require(
            wallet.balance == 2000 && recorder.totalOfficialSettled(address(0)) == 2000
                && entropy.revealFeeEscrow(1) == 200 && fixedSale.totalBuyerLiabilities() == 0,
            "two prices and separate live reveal fees"
        );
    }

    function testCollectionContestSyncIsIdempotentAndUsesTheDeclaredStopError() public {
        CuratedPlan memory p = _open(Curated.SelectionMode.PUBLIC);
        vm.warp(p.config.startsAt);
        NativeCuratedArtistBoundary boundary = NativeCuratedArtistBoundary(address(artists));
        fixedSale.syncCollectionContest(1);
        boundary.setContest(1);
        fixedSale.syncCollectionContest(1);
        fixedSale.syncCollectionContest(1);
        Curated.Selection memory chosen = _curatedSelection(p, 1, payer, 1);
        vm.expectRevert(
            abi.encodeWithSelector(StreamNativeCuratedSaleBase.SaleAttributionContested.selector, 1)
        );
        vm.prank(payer);
        fixedSale.purchaseSelectedContent{ value: 1100 }(p.saleId, chosen);
        boundary.setContest(3);
        fixedSale.syncCollectionContest(1);
        vm.expectRevert(
            abi.encodeWithSelector(StreamNativeCuratedSaleBase.SaleAttributionContested.selector, 1)
        );
        vm.prank(payer);
        fixedSale.purchaseSelectedContent{ value: 1100 }(p.saleId, chosen);
        _assertUnminted(p, 1);
        boundary.setContest(2);
        fixedSale.syncCollectionContest(1);
        fixedSale.syncCollectionContest(1);
        vm.prank(payer);
        Curated.ExecutionRecord memory result =
            fixedSale.purchaseSelectedContent{ value: 1100 }(p.saleId, chosen);
        _assertCuratedExecution(p, 1, result);
    }

    function testPublicDuplicateWorkFailsCapAndFreshNonceRemainsAvailableForOtherWork() public {
        CuratedPlan memory p = _open(Curated.SelectionMode.PUBLIC);
        vm.warp(p.config.startsAt);
        _buy(p, 1, payer, payer, 1, 1100);
        bytes memory duplicate = abi.encodeCall(
            fixedSale.purchaseSelectedContent, (p.saleId, _curatedSelection(p, 1, payer, 2))
        );
        uint256 before = payer.balance;
        vm.prank(payer);
        (bool ok,) = address(fixedSale).call{ value: 1100 }(duplicate);
        require(
            !ok && payer.balance == before && fixedSale.nextPurchaseNonce(p.saleId, payer) == 2
                && core.lastAllocatedTokenId() == 1 && manager.nextOperationNonce() == 1
                && wallet.balance == 1000 && ledger.counterValue(_curatedCounterKey(p, 1)) == 1,
            "actual content cap rejects duplicate without spending next purchase nonce"
        );
        _assertCuratedExecution(p, 2, _buy(p, 2, payer, payer, 2, 1100));
    }

    function testPublicRecipientPriceFeeAndExcessCreditConserveActualFunds() public {
        CuratedPlan memory p = _open(Curated.SelectionMode.PUBLIC);
        address recipient = address(0xB0B);
        vm.warp(p.config.startsAt);
        uint256 before = payer.balance;
        Curated.ExecutionRecord memory e = _buy(p, 1, payer, recipient, 1, 1117);
        _assertCuratedExecution(p, 1, e);
        require(
            e.buyer == payer && e.recipient == recipient && payer.balance == before - 1117
                && wallet.balance == 1000 && address(entropy).balance == 100
                && address(fixedSale).balance == 17
                && fixedSale.refundableBalance(p.saleId, payer) == 17
                && fixedSale.totalBuyerLiabilities() == 17,
            "price fee and allowance conserved"
        );
        vm.etch(address(entropy), hex"60006000fd");
        vm.prank(payer);
        fixedSale.claimRefund(p.saleId, payer);
        require(
            payer.balance == before - 1100 && fixedSale.totalBuyerLiabilities() == 0,
            "existing fee credit has no provider dependency"
        );
    }

    function testPublicReceiptRetainsOriginalSaleAndExactContentFacts() public {
        CuratedPlan memory p = _open(Curated.SelectionMode.PUBLIC);
        vm.warp(p.config.startsAt);
        vm.recordLogs();
        Curated.ExecutionRecord memory e = _buy(p, 0, payer, payer, 1, 1100);
        Vm.Log[] memory logs = vm.getRecordedLogs();
        bytes32 purchase = fixedSale.purchaseIdFor(p.saleId, payer, 1);
        bytes32 purchaseEvent = keccak256(
            "PreparedNativeContentPurchaseRecorded(uint16,address,bytes32,bytes32,bytes32,uint256)"
        );
        bytes32 contentEvent = keccak256(
            "PreparedNativeContentRecorded(bytes32,bytes32,(bytes32,address,bytes32,bytes32,bytes32,bytes32,bytes32,bytes32,bytes32,bytes32,bytes32))"
        );
        bytes32 originalEvent = keccak256(
            "PreparedNativeRevenueRecorded(bytes32,bytes32,bytes32,(address,address,address,bytes32,uint256,bytes32,bytes32,bytes32,bytes32,uint256,uint256,address,address,address,bytes32,bytes32,bytes32,bytes32),(uint256,bytes32,bytes32,uint256,address,address,address,address,uint256,uint8,bytes32,uint256,uint8,bytes32,bytes32,bytes32,bytes32,bytes32))"
        );
        uint256 purchases;
        uint256 contents;
        uint256 originals;
        for (uint256 i; i < logs.length; ++i) {
            if (logs[i].emitter != address(recorder)) continue;
            if (logs[i].topics[0] == originalEvent) {
                (
                    StreamPreparedNativeSettlementTypes.Facts memory facts,
                    StreamPreparedNativeSettlementTypes.Intent memory intent
                ) = abi.decode(
                    logs[i].data,
                    (
                        StreamPreparedNativeSettlementTypes.Facts,
                        StreamPreparedNativeSettlementTypes.Intent
                    )
                );
                bytes32 execution = keccak256(
                    abi.encode(
                        keccak256("6529STREAM_PREPARED_NATIVE_EXECUTION_V1"),
                        block.chainid,
                        facts.saleAdapter,
                        facts.intentHash,
                        intent.executionNonce,
                        facts.currentPolicyHash,
                        facts.boundPolicyHash,
                        facts.operationRoot,
                        facts.operationId
                    )
                );
                require(
                    intent.saleId == p.saleId && intent.saleNonce == p.nonce
                        && intent.executionNonce == 1 && intent.contentSelectionHash == p.leaves[0]
                        && facts.operationRoot == e.operationRoot
                        && recorder.settlementResult(e.settlementKey).executionId == execution
                        && execution != purchase,
                    "original prepared execution domain and creation nonce retained"
                );
                ++originals;
            }
            if (logs[i].topics[0] == purchaseEvent) {
                (uint16 schema, bytes32 saleId, uint256 saleNonce) =
                    abi.decode(logs[i].data, (uint16, bytes32, uint256));
                require(
                    schema == 1 && saleId == p.saleId && saleNonce == p.nonce
                        && logs[i].topics[1] == bytes32(uint256(uint160(address(fixedSale))))
                        && logs[i].topics[2] == purchase && logs[i].topics[3] == e.settlementKey,
                    "additive purchase receipt retains creation identity"
                );
                ++purchases;
            }
            if (logs[i].topics[0] == contentEvent) {
                StreamPreparedNativeContentTypes.Facts memory f =
                    abi.decode(logs[i].data, (StreamPreparedNativeContentTypes.Facts));
                require(
                    f.operationRoot == e.operationRoot && f.gate == address(p.gate)
                        && f.gateCodeHash == address(p.gate).codehash
                        && f.gateConfigHash == p.gate.gateConfigHash()
                        && f.manifestRoot == p.config.contentManifestRoot
                        && f.manifestHash == keccak256(p.gate.manifestBytes())
                        && f.counterId == p.counter && f.contentId == 0
                        && f.tokenDataHash == keccak256("") && f.contentLeaf == p.leaves[0]
                        && f.contextHash == _curatedContext(p, 0),
                    "official content facts join actual publication and Manager context"
                );
                require(
                    logs[i].topics[1] == e.settlementKey
                        && logs[i].topics[2]
                            == keccak256(
                                abi.encode(
                                    keccak256("6529STREAM_PREPARED_NATIVE_CONTENT_FACTS_V1"),
                                    block.chainid,
                                    f
                                )
                            ),
                    "content receipt domain preserved"
                );
                ++contents;
            }
        }
        require(
            purchases == 1 && contents == 1 && originals == 1,
            "one official purchase and content record"
        );
    }

    function testPublicRequiresExplicitDisclosureAndRejectsDifferentiatedOrDefaultTerms() public {
        CuratedPlan memory p = _curatedPlan(address(fixedSale), 0, Curated.SelectionMode.PUBLIC);
        Curated.FixedConfiguration memory c = _fixedConfiguration(p, Curated.SelectionMode.PUBLIC);
        c.publicSelectionDisclosure = false;
        (bool ok,) =
            address(fixedSale).call(abi.encodeCall(fixedSale.registerCuratedFixedSale, (c)));
        require(!ok, "PUBLIC requires its declaration");
        c.publicSelectionDisclosure = true;
        c.differentiatedContent = true;
        (ok,) = address(fixedSale).call(abi.encodeCall(fixedSale.registerCuratedFixedSale, (c)));
        require(!ok, "differentiated choice requires funded commit reveal");
        c.differentiatedContent = false;
        c.mode = Curated.SelectionMode.COMMIT_REVEAL;
        (ok,) = address(fixedSale).call(abi.encodeCall(fixedSale.registerCuratedFixedSale, (c)));
        require(
            !ok && fixedSale.nextSaleNonce() == p.nonce && core.lastAllocatedTokenId() == 0,
            "default mode never silently becomes PUBLIC"
        );
        _openCuratedFixed(p, Curated.SelectionMode.PUBLIC);
    }

    function testFuzzPublicTamperedSelectionRollsBackAndOriginalRetries(uint8 field) public {
        CuratedPlan memory p = _open(Curated.SelectionMode.PUBLIC);
        vm.warp(p.config.startsAt);
        Curated.Selection memory chosen = _curatedSelection(p, 1, payer, 1);
        bytes memory original =
            abi.encodeCall(fixedSale.purchaseSelectedContent, (p.saleId, chosen));
        if (field % 3 == 0) chosen.tokenData = bytes("altered");
        else if (field % 3 == 1) chosen.content.contentId = bytes32(uint256(2));
        else chosen.content.proof[0] = bytes32(uint256(99));
        vm.prank(payer);
        (bool ok,) = address(fixedSale).call{ value: 1100 }(
            abi.encodeCall(fixedSale.purchaseSelectedContent, (p.saleId, chosen))
        );
        require(
            !ok && fixedSale.nextPurchaseNonce(p.saleId, payer) == 1,
            "tampered proof consumes no purchase"
        );
        _assertUnminted(p, 1);
        vm.prank(payer);
        (ok,) = address(fixedSale).call{ value: 1100 }(original);
        require(ok && core.ownerOf(1) == payer, "exact original selected purchase retries");
    }

    function testCommitExactPriceOnlyCanonicalBuyerHashAndOriginalPurchaseDomain() public {
        CuratedPlan memory p = _open(Curated.SelectionMode.COMMIT_REVEAL);
        bytes32 salt = keccak256("buyer secret");
        bytes32 hash = fixedSale.selectionCommitment(p.saleId, payer, p.leaves[1], salt);
        require(
            hash
                == keccak256(
                    abi.encode(
                        keccak256("6529STREAM_CONTENT_COMMIT_V1"),
                        block.chainid,
                        address(fixedSale),
                        p.saleId,
                        payer,
                        p.leaves[1],
                        salt
                    )
                ),
            "canonical commitment preimage"
        );
        vm.warp(p.windows.commitOpen);
        vm.prank(payer);
        (bool ok,) = address(fixedSale).call{ value: 1100 }(
            abi.encodeCall(fixedSale.commitSelection, (p.saleId, hash, 1))
        );
        require(
            !ok && fixedSale.nextPurchaseNonce(p.saleId, payer) == 1,
            "reveal fee cannot enter commit escrow"
        );
        bytes32 purchase = _commit(p, 1, payer, 1, salt);
        (Deposits.CommitRecord memory record, bytes32 saved, uint256 nonce) =
            fixedSale.selectionDeposit(p.saleId, payer, hash);
        require(
            record.status == Deposits.Status.PENDING && record.amount == 1000
                && record.committedBlock == block.number && saved == purchase && nonce == 1
                && purchase
                    == keccak256(
                        abi.encode(
                            keccak256("6529STREAM_SALE_PURCHASE_V1"),
                            block.chainid,
                            address(fixedSale),
                            p.saleId,
                            payer,
                            uint256(1)
                        )
                    ),
            "buyer tuple deposit and original purchase nonce domain"
        );
        require(
            address(fixedSale).balance == 1000 && fixedSale.totalBuyerLiabilities() == 1000
                && wallet.balance == 0 && address(entropy).balance == 0
                && recorder.totalOfficialSettled(address(0)) == 0
                && core.lastAllocatedTokenId() == 0,
            "commit holds price only with no official sale or token allocation"
        );
    }

    function testCommitRevealStrictlyLaterBlockAndExactBuyerSaltAndNonce() public {
        CuratedPlan memory p = _open(Curated.SelectionMode.COMMIT_REVEAL);
        bytes32 salt = keccak256("original buyer salt");
        vm.warp(p.windows.commitOpen);
        _commit(p, 1, payer, 1, salt);
        Curated.Selection memory chosen = _curatedSelection(p, 1, payer, 1);
        bytes memory exact = abi.encodeCall(fixedSale.revealSelection, (p.saleId, chosen, salt));
        vm.warp(p.windows.revealOpen);
        vm.expectRevert(
            abi.encodeWithSelector(
                Deposits.ContentRevealSameBlock.selector, block.number, block.number
            )
        );
        vm.prank(payer);
        fixedSale.revealSelection{ value: 100 }(p.saleId, chosen, salt);
        vm.roll(block.number + 1);
        address other = address(0x0B0B);
        vm.deal(other, 1 ether);
        vm.prank(other);
        (bool ok,) = address(fixedSale).call{ value: 100 }(exact);
        require(!ok, "other buyer cannot reveal original tuple");
        vm.prank(payer);
        (ok,) = address(fixedSale).call{ value: 100 }(
            abi.encodeCall(fixedSale.revealSelection, (p.saleId, chosen, bytes32(uint256(8))))
        );
        require(!ok, "wrong salt cannot consume original deposit");
        chosen.purchaseNonce = 2;
        vm.prank(payer);
        (ok,) = address(fixedSale).call{ value: 100 }(
            abi.encodeCall(fixedSale.revealSelection, (p.saleId, chosen, salt))
        );
        require(!ok, "nonce remains the committed purchase nonce");
        _assertPending(p, payer, p.leaves[1], salt);
        vm.prank(payer);
        (ok,) = address(fixedSale).call{ value: 100 }(exact);
        require(ok && core.ownerOf(1) == payer, "original preimage succeeds in later block");
        vm.prank(payer);
        (ok,) = address(fixedSale).call{ value: 100 }(exact);
        require(
            !ok && manager.nextOperationNonce() == 1 && wallet.balance == 1000,
            "successful reveal cannot replay"
        );
    }

    function testRevealUsesLiveFeeWhilePriceEscrowAndExcessRemainSeparate() public {
        CuratedPlan memory p = _open(Curated.SelectionMode.COMMIT_REVEAL);
        bytes32 salt = keccak256("live fee");
        vm.warp(p.windows.commitOpen);
        _commit(p, 2, payer, 1, salt);
        entropy.configure(150, 1, false, false);
        vm.warp(p.windows.revealOpen);
        vm.roll(block.number + 1);
        Curated.ExecutionRecord memory e = _reveal(p, 2, payer, payer, 1, salt, 175);
        _assertCuratedExecution(p, 2, e);
        (uint256 pending, uint256 refunds, uint256 total) = fixedSale.selectionLiabilities();
        require(
            pending == 0 && refunds == 0 && total == 0 && wallet.balance == 1000
                && entropy.revealFeeEscrow(1) == 150
                && fixedSale.refundableBalance(p.saleId, payer) == 25
                && fixedSale.totalBuyerLiabilities() == 25 && address(fixedSale).balance == 25,
            "saved price settled once with live reveal fee and separate allowance credit"
        );
    }

    function testLosingAndUnrevealedCommitmentsReturnFullPriceAfterEndWithoutProviders() public {
        CuratedPlan memory p = _open(Curated.SelectionMode.COMMIT_REVEAL);
        address loser = address(0x10E2);
        address absent = address(0xAB5E17);
        vm.deal(loser, 1000);
        vm.deal(absent, 1000);
        bytes32 salt = keccak256("same salt different buyers");
        vm.warp(p.windows.commitOpen);
        _commit(p, 1, payer, 1, salt);
        _commit(p, 1, loser, 1, salt);
        _commit(p, 2, absent, 1, salt);
        vm.warp(p.windows.revealOpen);
        vm.roll(block.number + 1);
        _reveal(p, 1, payer, payer, 1, salt, 100);
        vm.deal(loser, 100);
        vm.prank(loser);
        (bool ok,) = address(fixedSale).call{ value: 100 }(
            abi.encodeCall(
                fixedSale.revealSelection, (p.saleId, _curatedSelection(p, 1, loser, 1), salt)
            )
        );
        require(
            !ok && loser.balance == 100 && wallet.balance == 1000,
            "loser keeps deposit and unspent reveal fee"
        );
        _assertPending(p, loser, p.leaves[1], salt);
        vm.warp(p.windows.revealClose);
        bytes32 losingHash = fixedSale.selectionCommitment(p.saleId, loser, p.leaves[1], salt);
        bytes32 absentHash = fixedSale.selectionCommitment(p.saleId, absent, p.leaves[2], salt);
        vm.etch(address(entropy), hex"60006000fd");
        vm.etch(address(artists), hex"60006000fd");
        vm.etch(address(p.gate), hex"60006000fd");
        vm.etch(address(manager), hex"60006000fd");
        require(
            fixedSale.unlockSelectionRefund(p.saleId, loser, losingHash) == 1000
                && fixedSale.unlockSelectionRefund(p.saleId, absent, absentHash) == 1000,
            "time exit has no live provider reads"
        );
        vm.prank(loser);
        fixedSale.claimSelectionRefund(p.saleId, payable(loser));
        vm.prank(absent);
        fixedSale.claimSelectionRefund(p.saleId, payable(absent));
        require(
            loser.balance == 1100 && absent.balance == 1000
                && fixedSale.totalBuyerLiabilities() == 0 && address(fixedSale).balance == 0
                && wallet.balance == 1000 && recorder.totalOfficialSettled(address(0)) == 1000,
            "losing and absent full pull refunds conserve price"
        );
        vm.prank(loser);
        (ok,) = address(fixedSale)
            .call(abi.encodeCall(fixedSale.claimSelectionRefund, (p.saleId, payable(loser))));
        require(
            !ok && fixedSale.unlockSelectionRefund(p.saleId, loser, losingHash) == 0,
            "no repeated refund"
        );
    }

    function testHalfOpenCommitAndRevealBoundariesAndPublicEntryCannotBypassCommit() public {
        CuratedPlan memory p = _open(Curated.SelectionMode.COMMIT_REVEAL);
        bytes32 salt = keccak256("window endpoints");
        bytes32 hash = fixedSale.selectionCommitment(p.saleId, payer, p.leaves[1], salt);
        vm.warp(p.windows.commitOpen - 1);
        vm.prank(payer);
        (bool ok,) = address(fixedSale).call{ value: 1000 }(
            abi.encodeCall(fixedSale.commitSelection, (p.saleId, hash, 1))
        );
        require(!ok, "commit before open rejected");
        vm.warp(p.windows.commitClose - 1);
        _commit(p, 1, payer, 1, salt);
        vm.warp(p.windows.commitClose);
        vm.prank(payer);
        (ok,) = address(fixedSale).call{ value: 1000 }(
            abi.encodeCall(fixedSale.commitSelection, (p.saleId, bytes32(uint256(7)), 2))
        );
        require(!ok, "commit close is exclusive");
        Curated.Selection memory chosen = _curatedSelection(p, 1, payer, 1);
        vm.prank(payer);
        (ok,) = address(fixedSale).call{ value: 1100 }(
            abi.encodeCall(fixedSale.purchaseSelectedContent, (p.saleId, chosen))
        );
        require(!ok, "PUBLIC entry cannot bypass required commit reveal mode");
        vm.roll(block.number + 1);
        vm.warp(p.windows.revealOpen - 1);
        vm.prank(payer);
        (ok,) = address(fixedSale).call{ value: 100 }(
            abi.encodeCall(fixedSale.revealSelection, (p.saleId, chosen, salt))
        );
        require(!ok, "reveal before open rejected");
        vm.warp(p.windows.revealClose);
        vm.prank(payer);
        (ok,) = address(fixedSale).call{ value: 100 }(
            abi.encodeCall(fixedSale.revealSelection, (p.saleId, chosen, salt))
        );
        require(
            !ok && fixedSale.unlockSelectionRefund(p.saleId, payer, hash) == 1000,
            "exclusive reveal close admits full refund instead"
        );
    }

    function testLateCoreCompletionFailureRestoresDepositAndExactRevealRetries() public {
        CuratedPlan memory p = _open(Curated.SelectionMode.COMMIT_REVEAL);
        bytes32 salt = keccak256("late Core retry");
        bytes memory exact = _readyReveal(p, payer, salt);
        entropy.configure(100, 1, true, false);
        _expectRecorderFunding();
        uint256 before = payer.balance;
        vm.prank(payer);
        (bool ok,) = address(fixedSale).call{ value: 100 }(exact);
        require(
            !ok && payer.balance == before,
            "late actual Core callback failed after recorder invocation"
        );
        _assertPending(p, payer, p.leaves[1], salt);
        _assertUnminted(p, 1);
        require(
            !_consumed(fixedSale.purchaseIdFor(p.saleId, payer, 1)) && entropy.mintCalls() == 0,
            "receipt and entropy callback effects rolled back"
        );
        entropy.configure(100, 1, false, false);
        vm.prank(payer);
        (ok,) = address(fixedSale).call{ value: 100 }(exact);
        require(
            ok && core.ownerOf(1) == payer && wallet.balance == 1000
                && fixedSale.totalBuyerLiabilities() == 0,
            "same reveal retries with original deposit"
        );
    }

    function testActualRecorderRightsFailureRollsBackAndExactRevealRetries() public {
        CuratedPlan memory p = _open(Curated.SelectionMode.COMMIT_REVEAL);
        bytes32 salt = keccak256("actual recorder failure");
        bytes memory exact = _readyReveal(p, payer, salt);
        bytes memory walletCode = wallet.code;
        vm.etch(wallet, hex"60006000fd");
        _expectRecorderFunding();
        vm.prank(payer);
        (bool ok,) = address(fixedSale).call{ value: 100 }(exact);
        require(!ok, "actual recorder rejects altered registered wallet runtime");
        _assertPending(p, payer, p.leaves[1], salt);
        _assertUnminted(p, 1);
        vm.etch(wallet, walletCode);
        vm.prank(payer);
        (ok,) = address(fixedSale).call{ value: 100 }(exact);
        require(
            ok && core.ownerOf(1) == payer && wallet.balance == 1000,
            "exact reveal retries after restoring original wallet runtime"
        );
    }

    function testLateReceiverRejectRollsBackActualPaymentAndSameRevealRetries() public {
        CuratedPlan memory p = _open(Curated.SelectionMode.COMMIT_REVEAL);
        NativeAuctionReceiver recipient = new NativeAuctionReceiver();
        recipient.configure(true, false, address(0), "", address(0));
        bytes32 salt = keccak256("receiver exact retry");
        bytes memory exact = _readyReveal(p, address(recipient), salt);
        _expectRecorderFunding();
        vm.prank(payer);
        (bool ok,) = address(fixedSale).call{ value: 100 }(exact);
        require(!ok, "late final delivery rejects after official settlement");
        _assertPending(p, payer, p.leaves[1], salt);
        _assertUnminted(p, 1);
        require(
            entropy.revealFeeEscrow(1) == 0 && entropy.requestCalls() == 0
                && !_consumed(fixedSale.purchaseIdFor(p.saleId, payer, 1)),
            "fee attempt and official record rolled back"
        );
        recipient.configure(false, false, address(0), "", address(0));
        vm.prank(payer);
        (ok,) = address(fixedSale).call{ value: 100 }(exact);
        require(
            ok && core.ownerOf(1) == address(recipient) && wallet.balance == 1000,
            "same buyer reveal and original recipient retry"
        );
    }

    function testReceiverReentryFailsSharedGuardAndCannotConsumeAnotherWork() public {
        CuratedPlan memory p = _open(Curated.SelectionMode.PUBLIC);
        CuratedFundedReentryReceiver recipient = new CuratedFundedReentryReceiver();
        bytes memory reentry = abi.encodeCall(
            fixedSale.purchaseSelectedContent,
            (p.saleId, _curatedSelection(p, 2, address(recipient), 1))
        );
        recipient.configure(address(fixedSale), reentry);
        vm.deal(address(recipient), 1100);
        vm.warp(p.config.startsAt);
        _buy(p, 1, payer, address(recipient), 1, 1100);
        require(
            recipient.rejected()
                && keccak256(recipient.rejectedData())
                    == keccak256(
                        abi.encodeWithSelector(bytes4(keccak256("ReentrancyGuardReentrantCall()")))
                    ) && address(recipient).balance == 1100 && core.ownerOf(1) == address(recipient)
                && manager.nextOperationNonce() == 1
                && ledger.counterValue(_curatedCounterKey(p, 2)) == 0
                && fixedSale.nextPurchaseNonce(p.saleId, address(recipient)) == 1,
            "shared guard preserves outer purchase against final receiver reentry"
        );
    }

    function testAbsoluteEscapeWhilePausedRefundsCollapsedEffectiveWindowsWithoutProviders()
        public
    {
        CuratedPlan memory p = _open(Curated.SelectionMode.COMMIT_REVEAL);
        bytes32 salt = keccak256("absolute paused escape");
        vm.warp(p.windows.commitOpen);
        _commit(p, 1, payer, 1, salt);
        bytes32 hash = fixedSale.selectionCommitment(p.saleId, payer, p.leaves[1], salt);
        vm.warp(p.windows.commitOpen + 50);
        vm.prank(address(0xA11));
        fixedSale.setSalePause(p.saleId, true, keccak256("paused escape test"));
        vm.warp(p.windows.absoluteEscape);
        StreamNativeCuratedClock.View memory clock = fixedSale.selectionWindows(p.saleId);
        require(
            clock.escapeReached && clock.localPaused
                && clock.commitClose == p.windows.absoluteEscape
                && clock.revealOpen == clock.commitClose && clock.revealClose == clock.commitClose,
            "effective intervals collapse at immutable absolute escape"
        );
        vm.etch(address(artists), hex"60006000fd");
        vm.etch(address(entropy), hex"60006000fd");
        vm.etch(address(manager), hex"60006000fd");
        require(
            fixedSale.unlockSelectionRefund(p.saleId, payer, hash) == 1000,
            "matured refund ignores unusable mint windows and providers"
        );
        uint256 before = payer.balance;
        vm.prank(payer);
        fixedSale.claimSelectionRefund(p.saleId, payable(payer));
        require(
            payer.balance == before + 1000 && fixedSale.totalBuyerLiabilities() == 0,
            "paused escape is a full independent pull refund"
        );
    }

    function testSelectedRaceHasEarlyFullRefundOnlyForAuthenticatedExhaustedContent() public {
        CuratedPlan memory p = _open(Curated.SelectionMode.COMMIT_REVEAL);
        address loser = address(0xCA902);
        vm.deal(loser, 1000);
        bytes32 salt = keccak256("early selected race");
        vm.warp(p.windows.commitOpen);
        _commit(p, 1, payer, 1, salt);
        _commit(p, 1, loser, 1, salt);
        bytes32 hash = fixedSale.selectionCommitment(p.saleId, loser, p.leaves[1], salt);
        Curated.Selection memory chosen = _curatedSelection(p, 1, loser, 1);
        vm.warp(p.windows.revealOpen);
        vm.roll(block.number + 1);
        (bool ok,) = address(fixedSale)
            .call(
                abi.encodeCall(
                    fixedSale.unlockSelectionRefundForReason,
                    (p.saleId, loser, hash, chosen, salt, uint8(2))
                )
            );
        require(!ok, "unconsumed selected work is no exhaustion evidence");
        _reveal(p, 1, payer, payer, 1, salt, 100);
        Curated.Selection memory other = _curatedSelection(p, 2, loser, 1);
        (ok,) = address(fixedSale)
            .call(
                abi.encodeCall(
                    fixedSale.unlockSelectionRefundForReason,
                    (p.saleId, loser, hash, other, salt, uint8(2))
                )
            );
        require(!ok, "another declared work cannot open this opaque commitment");
        (ok,) = address(fixedSale)
            .call(
                abi.encodeCall(
                    fixedSale.unlockSelectionRefundForReason,
                    (p.saleId, loser, hash, chosen, bytes32(uint256(7)), uint8(2))
                )
            );
        require(!ok, "correct exhausted work still requires saved buyer preimage");
        require(
            fixedSale.unlockSelectionRefundForReason(p.saleId, loser, hash, chosen, salt, 2) == 1000
                && block.timestamp < p.windows.revealClose
                && fixedSale.selectionRefundCredit(p.saleId, loser) == 1000,
            "authenticated actual cap1 race admits full early credit"
        );
        vm.etch(address(manager), hex"60006000fd");
        vm.etch(address(artists), hex"60006000fd");
        vm.prank(loser);
        fixedSale.claimSelectionRefund(p.saleId, payable(loser));
        require(
            loser.balance == 1000 && wallet.balance == 1000
                && fixedSale.totalBuyerLiabilities() == 0,
            "credited early refund remains independent from providers"
        );
    }

    function testFinalReceiverPhasePauseRollsBackCompletedPurchase() public {
        _phaseMutationRetry(0);
    }

    function testFinalReceiverExecutorRevocationRollsBackCompletedPurchase() public {
        _phaseMutationRetry(1);
    }

    function testFinalReceiverPolicyChangeRollsBackCompletedPurchase() public {
        _phaseMutationRetry(2);
    }

    /// @dev The test contract is the actual Manager owner. A final receiver invokes this explicit
    /// authority boundary only after Manager completion, exercising the host's post-delivery check.
    function mutateCuratedPhase(bytes32 phase, uint8 mutation) external {
        require(msg.sender == _phaseMutationReceiver, "only armed final receiver");
        if (mutation == 0) manager.setPhasePaused(1, phase, true);
        else if (mutation == 1) manager.setPhaseExecutor(1, phase, address(fixedSale), false);
        else manager.setPhaseExecutor(1, phase, address(0xE87A), true);
    }

    function _phaseMutationRetry(uint8 mutation) private {
        CuratedPlan memory p = _open(Curated.SelectionMode.PUBLIC);
        NativeAuctionReceiver recipient = new NativeAuctionReceiver();
        _phaseMutationReceiver = address(recipient);
        recipient.configure(
            false,
            false,
            address(this),
            abi.encodeCall(this.mutateCuratedPhase, (p.config.phaseId, mutation)),
            address(0)
        );
        vm.warp(p.config.startsAt);
        bytes memory exact = abi.encodeCall(
            fixedSale.purchaseSelectedContent,
            (p.saleId, _curatedSelection(p, 1, address(recipient), 1))
        );
        _expectRecorderFunding();
        vm.prank(payer);
        (bool ok,) = address(fixedSale).call{ value: 1100 }(exact);
        require(
            !ok && fixedSale.nextPurchaseNonce(p.saleId, payer) == 1,
            "successful final receiver mutation fails post-delivery retained admission"
        );
        _assertUnminted(p, 1);
        (, IStreamMintManager.MintPhaseConfig memory phase) = manager.phase(1, p.config.phaseId);
        require(
            !phase.paused && manager.phaseExecutor(1, p.config.phaseId, address(fixedSale))
                && !manager.phaseExecutor(1, p.config.phaseId, address(0xE87A))
                && manager.phasePolicyHash(1, p.config.phaseId) == p.config.mintPolicyHash,
            "callback governance mutation rolls back with payment and delivery"
        );
        recipient.configure(false, false, address(0), "", address(0));
        vm.prank(payer);
        (ok,) = address(fixedSale).call{ value: 1100 }(exact);
        require(
            ok && core.ownerOf(1) == address(recipient) && wallet.balance == 1000,
            "same original purchase retries after receiver stops mutating phase"
        );
    }

    function _open(Curated.SelectionMode mode) private returns (CuratedPlan memory p) {
        p = _curatedPlan(address(fixedSale), 0, mode);
        _openCuratedFixed(p, mode);
        require(
            fixedSale.saleRecord(p.saleId).contentCounterConfigHash
                == manager.counterConfig(1, p.config.phaseId, p.counter).counterConfigHash,
            "creation retains exact live content counter definition"
        );
    }

    function _buy(
        CuratedPlan memory p,
        uint256 index,
        address buyer,
        address recipient,
        uint256 nonce,
        uint256 value
    ) private returns (Curated.ExecutionRecord memory) {
        Curated.Selection memory chosen = _curatedSelection(p, index, recipient, nonce);
        vm.prank(buyer);
        return fixedSale.purchaseSelectedContent{ value: value }(p.saleId, chosen);
    }

    function _commit(
        CuratedPlan memory p,
        uint256 index,
        address buyer,
        uint256 nonce,
        bytes32 salt
    ) private returns (bytes32) {
        bytes32 hash = fixedSale.selectionCommitment(p.saleId, buyer, p.leaves[index], salt);
        vm.prank(buyer);
        return fixedSale.commitSelection{ value: p.config.price }(p.saleId, hash, nonce);
    }

    function _reveal(
        CuratedPlan memory p,
        uint256 index,
        address buyer,
        address recipient,
        uint256 nonce,
        bytes32 salt,
        uint256 value
    ) private returns (Curated.ExecutionRecord memory) {
        Curated.Selection memory chosen = _curatedSelection(p, index, recipient, nonce);
        vm.prank(buyer);
        return fixedSale.revealSelection{ value: value }(p.saleId, chosen, salt);
    }

    function _readyReveal(CuratedPlan memory p, address recipient, bytes32 salt)
        private
        returns (bytes memory)
    {
        vm.warp(p.windows.commitOpen);
        _commit(p, 1, payer, 1, salt);
        vm.warp(p.windows.revealOpen);
        vm.roll(block.number + 1);
        return abi.encodeCall(
            fixedSale.revealSelection, (p.saleId, _curatedSelection(p, 1, recipient, 1), salt)
        );
    }

    function _assertPending(CuratedPlan memory p, address buyer, bytes32 leaf, bytes32 salt)
        private
        view
    {
        bytes32 hash = fixedSale.selectionCommitment(p.saleId, buyer, leaf, salt);
        (Deposits.CommitRecord memory record,,) = fixedSale.selectionDeposit(p.saleId, buyer, hash);
        require(
            record.status == Deposits.Status.PENDING && record.amount == p.config.price,
            "original full deposit remains pending"
        );
    }

    function _assertUnminted(CuratedPlan memory p, uint256 index) private view {
        require(
            core.lastAllocatedTokenId() == 0 && core.collectionNextSerial(1) == 1
                && manager.nextOperationNonce() == 0
                && ledger.counterValue(_curatedCounterKey(p, index)) == 0 && wallet.balance == 0
                && recorder.totalOfficialSettled(address(0)) == 0
                && manager.activePreparedNativeContent().operationRoot == 0
                && manager.preparedNativeContentAdmission() == 0
                && core.pendingPreparedMintTokenId() == 0,
            "actual token ledger payment and active admission all rolled back"
        );
    }

    function _consumed(bytes32 purchase) private view returns (bool) {
        return IStreamPreparedNativeContentPurchaseSettlement(address(recorder))
            .preparedNativeContentPurchaseConsumed(address(fixedSale), purchase);
    }

    function _expectRecorderFunding() private {
        CuratedCurrentVm(address(vm))
            .expectCall(
                address(recorder),
                1000,
                abi.encodeWithSelector(
                    IStreamPreparedNativeContentPurchaseSettlement.settlePreparedNativeContentPurchase
                    .selector
                )
            );
    }
}
