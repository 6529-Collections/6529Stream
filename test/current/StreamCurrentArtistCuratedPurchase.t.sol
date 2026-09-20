// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../helpers/CurrentArtistCuratedPurchaseFixture.sol";
import {
    IStreamNativeCuratedCommitments as Deposits
} from "../../smart-contracts/interfaces/stream/mint/IStreamNativeCuratedCommitments.sol";

/// @notice Actual Artist operation16, production curated purchases, official Safes and current accounting.
/// @dev Native execution is pending the matched-source current freeze; no cold-gas claim is made.
contract StreamCurrentArtistCuratedPurchaseTest is CurrentArtistCuratedPurchaseFixture {
    function setUp() public {
        _deployArtistCuratedPurchases();
    }

    function testActualArtistSaleConsentRepairsSameSafePurchaseAndRetainsTwoOriginalWorks() public {
        PurchasePlan memory p = _openFixedPurchase(false, false);
        Curated.Selection memory first = _purchaseSelection(p, 0, address(joinedBuyer), 1);
        bytes memory exact = _purchaseSafePayload(
            address(artistFixed),
            1117,
            abi.encodeCall(artistFixed.purchaseSelectedContent, (p.id, first))
        );
        uint256 balance = address(joinedBuyer).balance;
        _purchaseFailed(exact);
        _assertPurchaseBlank(p, first);
        require(
            artistFixed.nextPurchaseNonce(p.id, address(joinedBuyer)) == 1
                && artistFixed.totalBuyerLiabilities() == 0,
            "missing actual Artist consent cannot consume purchase"
        );
        _purchaseConsent(p);
        vm.recordLogs();
        _purchaseSucceeded(exact);
        Curated.ExecutionRecord memory one = _assertPurchaseExecution(p, first);
        _assertContentReceipt(p, first, one, vm.getRecordedLogs());
        _purchaseFailed(
            _purchaseSafePayload(
                address(artistFixed),
                1100,
                abi.encodeCall(artistFixed.purchaseSelectedContent, (p.id, first))
            )
        );
        Curated.Selection memory second = _purchaseSelection(p, 1, address(joinedBuyer), 2);
        _purchaseSucceeded(
            _purchaseSafePayload(
                address(artistFixed),
                1100,
                abi.encodeCall(artistFixed.purchaseSelectedContent, (p.id, second))
            )
        );
        Curated.ExecutionRecord memory two = _assertPurchaseExecution(p, second);
        require(
            one.tokenId == 1 && two.tokenId == 2 && one.operationRoot != two.operationRoot
                && one.settlementKey != two.settlementKey && core.collectionNextSerial(1) == 3
                && core.totalSupply() == 2 && manager.nextOperationNonce() == 2
                && artistFixed.saleRecord(p.id).saleNonce == p.nonce
                && artistFixed.nextSaleNonce() == p.nonce + 1
                && artistFixed.nextPurchaseNonce(p.id, address(joinedBuyer)) == 3
                && wallet.balance == 2000 && joinedRecorder.totalOfficialSettled(address(0)) == 2000
                && entropy.revealFeeEscrow(1) == 200
                && artistFixed.refundableBalance(p.id, address(joinedBuyer)) == 17
                && artistFixed.totalBuyerLiabilities() == 17 && address(artistFixed).balance == 17,
            "one immutable sale; two content receipts, prices, reveal fees and separate buyer excess"
        );
        _joinedSafe(
            joinedBuyer,
            address(artistFixed),
            0,
            abi.encodeCall(artistFixed.claimRefund, (p.id, address(joinedBuyer)))
        );
        require(
            address(joinedBuyer).balance == balance - 2200
                && artistFixed.totalBuyerLiabilities() == 0,
            "buyer Safe pulls only its original excess"
        );
        (, uint256 request) = entropy.requestEntropy(one.tokenId);
        provider.fulfill(request, keccak256("actual curated purchase entropy"));
        (, bool finalized) = entropy.tokenSeed(one.tokenId);
        require(
            finalized && bytes(core.tokenURI(one.tokenId)).length != 0,
            "actual Coordinator and metadata complete"
        );
    }

    function testActualCuratedDeliveryFailureRestoresPaidReceiptAndIdenticalSafeRetry() public {
        PurchasePlan memory p = _openFixedPurchase(false, true);
        CurrentCuratedPurchaseRecipient recipient = new CurrentCuratedPurchaseRecipient();
        Curated.Selection memory chosen = _purchaseSelection(p, 1, address(recipient), 1);
        bytes memory exact = _purchaseSafePayload(
            address(artistFixed),
            1107,
            abi.encodeCall(artistFixed.purchaseSelectedContent, (p.id, chosen))
        );
        // Reverted trace logs establish the late failure location; they are not committed receipts.
        vm.recordLogs();
        _purchaseFailed(exact);
        (bytes32 root, bytes32 authorization, bytes32 settlement) =
            _tracePurchase(vm.getRecordedLogs());
        require(
            root != 0 && authorization != 0 && settlement != 0,
            "actual official payment recorded before delivery rejected"
        );
        _assertPurchaseBlank(p, chosen);
        require(
            !ledger.isManagerOperationRootUsed(address(manager), root)
                && !ledger.isManagerAuthorizationUsed(address(manager), authorization)
                && !joinedRecorder.settlementConsumed(settlement)
                && joinedRecorder.preparedNativeContentHash(settlement) == 0
                && joinedRecorder.preparedNativeFactsHash(settlement) == 0
                && artistFixed.nextPurchaseNonce(p.id, address(joinedBuyer)) == 1
                && artistFixed.refundableBalance(p.id, address(joinedBuyer)) == 0
                && artistFixed.totalBuyerLiabilities() == 0 && address(artistFixed).balance == 0,
            "exact replay identities, price, fee and excess credit unwind together"
        );
        recipient.accept();
        vm.recordLogs();
        _purchaseSucceeded(exact);
        Curated.ExecutionRecord memory e = _assertPurchaseExecution(p, chosen);
        _assertContentReceipt(p, chosen, e, vm.getRecordedLogs());
        require(
            e.operationRoot == root && e.authorizationId == authorization
                && e.settlementKey == settlement && core.totalSupply() == 1
                && manager.nextOperationNonce() == 1 && wallet.balance == CURATED_PRICE
                && entropy.revealFeeEscrow(1) == 100
                && artistFixed.refundableBalance(p.id, address(joinedBuyer)) == 7
                && joinedBuyer.nonce() == 1,
            "byte-identical signed retry commits the same paid content identity once"
        );
    }

    function testActualCommitRevealKeepsOriginalDepositThroughLateFailureThenSameSafeRetry()
        public
    {
        PurchasePlan memory p = _openFixedPurchase(true, true);
        CurrentCuratedPurchaseRecipient recipient = new CurrentCuratedPurchaseRecipient();
        Curated.Selection memory chosen = _purchaseSelection(p, 1, address(recipient), 1);
        bytes32 salt = keccak256("actual buyer curated selection salt");
        bytes32 commitment =
            artistFixed.selectionCommitment(p.id, address(joinedBuyer), p.leaves[1], salt);
        _joinedSafe(
            joinedBuyer,
            address(artistFixed),
            CURATED_PRICE,
            abi.encodeCall(artistFixed.commitSelection, (p.id, commitment, uint256(1)))
        );
        (Deposits.CommitRecord memory before_, bytes32 purchase, uint256 nonce) =
            artistFixed.selectionDeposit(p.id, address(joinedBuyer), commitment);
        require(
            before_.status == Deposits.Status.PENDING && before_.amount == CURATED_PRICE
                && nonce == 1
                && purchase == artistFixed.purchaseIdFor(p.id, address(joinedBuyer), 1)
                && artistFixed.totalBuyerLiabilities() == CURATED_PRICE
                && address(artistFixed).balance == CURATED_PRICE && core.totalSupply() == 0
                && wallet.balance == 0,
            "commit retains buyer price without mint or revenue"
        );
        vm.roll(block.number + 1);
        vm.warp(p.windows.revealOpen);
        bytes memory exact = _purchaseSafePayload(
            address(artistFixed),
            100,
            abi.encodeCall(artistFixed.revealSelection, (p.id, chosen, salt))
        );
        _purchaseFailed(exact);
        _assertPurchaseBlank(p, chosen);
        (Deposits.CommitRecord memory after_, bytes32 afterPurchase, uint256 afterNonce) =
            artistFixed.selectionDeposit(p.id, address(joinedBuyer), commitment);
        require(
            keccak256(abi.encode(after_)) == keccak256(abi.encode(before_))
                && afterPurchase == purchase && afterNonce == nonce
                && artistFixed.totalBuyerLiabilities() == CURATED_PRICE
                && address(artistFixed).balance == CURATED_PRICE && joinedBuyer.nonce() == 1,
            "failed reveal retains the original funded deposit and its committed-block identity"
        );
        recipient.accept();
        _purchaseSucceeded(exact);
        _assertPurchaseExecution(p, chosen);
        (after_, afterPurchase, afterNonce) =
            artistFixed.selectionDeposit(p.id, address(joinedBuyer), commitment);
        require(
            after_.status == Deposits.Status.CONSUMED && afterPurchase == purchase
                && afterNonce == 1 && artistFixed.totalBuyerLiabilities() == 0
                && address(artistFixed).balance == 0 && wallet.balance == CURATED_PRICE
                && entropy.revealFeeEscrow(1) == 100 && joinedBuyer.nonce() == 2
                && core.totalSupply() == 1 && manager.nextOperationNonce() == 1,
            "same reveal consumes the original price once and the Safe funds only the live reveal fee"
        );
        _purchaseFailed(
            _purchaseSafePayload(
                address(artistFixed),
                100,
                abi.encodeCall(artistFixed.revealSelection, (p.id, chosen, salt))
            )
        );
        require(
            wallet.balance == CURATED_PRICE
                && joinedRecorder.totalOfficialSettled(address(0)) == CURATED_PRICE,
            "terminal reveal cannot pay again"
        );
    }

    function testActualArtistPrivateSaleRequiresOriginalSellerSafeEnvelopeAndExactBuyer() public {
        (PurchasePlan memory p, Curated.Selection memory chosen) = _openPrivatePurchase(0);
        StreamPrivateSaleTypes.SaleAuthorization memory a = _privatePurchaseAuthorization(p, chosen);
        bytes32 digest = _privatePurchaseDigest(a);
        IStreamPrivateSaleAdapter.Signature memory sig = IStreamPrivateSaleAdapter.Signature(
            address(joinedCollector), 2, safeThresholdSignature(joinedKeys, digest)
        );
        IStreamNativeRefundDelegatedClaims.DelegationWitness memory direct =
            IStreamNativeRefundDelegatedClaims.DelegationWitness(false, 0);
        _purchaseFailed(
            _purchaseSafePayload(
                address(artistPrivate),
                1109,
                abi.encodeCall(artistPrivate.purchasePrivateContent, (a, sig, chosen, direct))
            )
        );
        _assertPurchaseBlank(p, chosen);
        sig.signature = _joinedProof(joinedArtist, digest);
        _purchaseFailed(
            _purchaseSafePayload(
                address(artistPrivate),
                1109,
                abi.encodeCall(artistPrivate.purchasePrivateContent, (a, sig, chosen, direct))
            )
        );
        _assertPurchaseBlank(p, chosen);
        sig.signature = _joinedProof(joinedCollector, digest);
        bytes32 originalBytes = a.tokenDataArrayHash;
        a.tokenDataArrayHash = keccak256("unsigned different content");
        _purchaseFailed(
            _purchaseSafePayload(
                address(artistPrivate),
                1109,
                abi.encodeCall(artistPrivate.purchasePrivateContent, (a, sig, chosen, direct))
            )
        );
        a.tokenDataArrayHash = originalBytes;
        address originalExecutor = a.executor;
        a.executor = address(joinedCollaborator);
        sig.signature = _joinedProof(joinedCollector, _privatePurchaseDigest(a));
        _purchaseFailed(
            _purchaseSafePayload(
                address(artistPrivate),
                1109,
                abi.encodeCall(artistPrivate.purchasePrivateContent, (a, sig, chosen, direct))
            )
        );
        _assertPurchaseBlank(p, chosen);
        require(
            !ledger.isManagerAuthorizationUsed(
                address(manager), StreamMintTicketHash.authorizationId(digest)
            ),
            "wrong signer envelope content and executor never consume original authorization"
        );
        a.executor = originalExecutor;
        sig.signature = _joinedProof(joinedCollector, digest);
        bytes memory data =
            abi.encodeCall(artistPrivate.purchasePrivateContent, (a, sig, chosen, direct));
        vm.recordLogs();
        _purchaseSucceeded(_purchaseSafePayload(address(artistPrivate), 1109, data));
        Curated.ExecutionRecord memory e = _assertPurchaseExecution(p, chosen);
        _assertContentReceipt(p, chosen, e, vm.getRecordedLogs());
        require(
            e.authorizationDigest == digest
                && e.authorizationId == StreamMintTicketHash.authorizationId(digest)
                && artistPrivate.saleRecord(p.id).status == 4
                && artistPrivate.nextPurchaseNonce(p.id, address(joinedBuyer)) == 2
                && joinedCollector.nonce() == 0 && joinedBuyer.nonce() == 1
                && core.tokenData(1).length == 0 && wallet.balance == CURATED_PRICE
                && entropy.revealFeeEscrow(1) == 100
                && artistPrivate.refundableBalance(p.id, address(joinedBuyer)) == 9,
            "original seller Safe signature and buyer CALL commit the empty published work once"
        );
        _purchaseFailed(_purchaseSafePayload(address(artistPrivate), 1109, data));
        require(
            core.totalSupply() == 1 && wallet.balance == CURATED_PRICE && joinedBuyer.nonce() == 1,
            "private replay preserves original receipt and Safe nonce"
        );
    }

    function _tracePurchase(Vm.Log[] memory logs)
        private
        view
        returns (bytes32 root, bytes32 authorization, bytes32 settlement)
    {
        for (uint256 i; i < logs.length; ++i) {
            if (
                logs[i].emitter == address(ledger)
                    && logs[i].topics[0]
                        == keccak256(
                            "MintLedgerAuthorizationConsumed(uint16,bytes32,bytes32,address,bytes32)"
                        )
            ) {
                authorization = logs[i].topics[1];
                root = logs[i].topics[2];
            }
            if (
                logs[i].emitter == address(joinedRecorder)
                    && logs[i].topics[0]
                        == keccak256(
                            "PreparedNativeContentPurchaseRecorded(uint16,address,bytes32,bytes32,bytes32,uint256)"
                        )
            ) {
                settlement = logs[i].topics[3];
            }
        }
    }

    function _assertContentReceipt(
        PurchasePlan memory p,
        Curated.Selection memory chosen,
        Curated.ExecutionRecord memory e,
        Vm.Log[] memory logs
    ) private view {
        uint256 contentRecords;
        uint256 purchaseRecords;
        bytes32 purchase = p.host.purchaseIdFor(p.id, address(joinedBuyer), chosen.purchaseNonce);
        bytes32 context = keccak256(
            abi.encode(
                keccak256("6529STREAM_CONTENT_CONTEXT_V1"),
                block.chainid,
                address(p.host),
                p.id,
                chosen.content.contentId
            )
        );
        for (uint256 i; i < logs.length; ++i) {
            if (logs[i].emitter != address(joinedRecorder)) continue;
            if (
                logs[i].topics[0]
                    == keccak256(
                        "PreparedNativeContentRecorded(bytes32,bytes32,(bytes32,address,bytes32,bytes32,bytes32,bytes32,bytes32,bytes32,bytes32,bytes32,bytes32))"
                    )
            ) {
                StreamPreparedNativeContentTypes.Facts memory f =
                    abi.decode(logs[i].data, (StreamPreparedNativeContentTypes.Facts));
                bytes32 hash = keccak256(
                    abi.encode(
                        keccak256("6529STREAM_PREPARED_NATIVE_CONTENT_FACTS_V1"), block.chainid, f
                    )
                );
                require(
                    logs[i].topics.length == 3 && logs[i].data.length == 352
                        && logs[i].topics[1] == e.settlementKey && logs[i].topics[2] == hash
                        && joinedRecorder.preparedNativeContentHash(e.settlementKey) == hash
                        && f.operationRoot == e.operationRoot && f.gate == address(p.gate)
                        && f.gateCodeHash == address(p.gate).codehash
                        && f.gateConfigHash == p.gate.gateConfigHash()
                        && f.manifestRoot == p.config.contentManifestRoot
                        && f.manifestHash == keccak256(p.gate.manifestBytes())
                        && f.counterId == p.counter && f.contentId == chosen.content.contentId
                        && f.tokenDataHash == chosen.content.tokenDataHash
                        && f.contentLeaf == e.contentLeaf && f.contextHash == context,
                    "exact independently joined original content receipt"
                );
                ++contentRecords;
            }
            if (
                logs[i].topics[0]
                    == keccak256(
                        "PreparedNativeContentPurchaseRecorded(uint16,address,bytes32,bytes32,bytes32,uint256)"
                    )
            ) {
                require(
                    logs[i].topics.length == 4
                        && address(uint160(uint256(logs[i].topics[1]))) == address(p.host)
                        && logs[i].topics[2] == purchase && logs[i].topics[3] == e.settlementKey
                        && keccak256(logs[i].data)
                            == keccak256(abi.encode(uint16(1), p.id, p.nonce)),
                    "per-purchase event retains exact original creation identity"
                );
                ++purchaseRecords;
            }
        }
        require(
            contentRecords == 1 && purchaseRecords == 1, "one committed content and purchase record"
        );
    }
}
