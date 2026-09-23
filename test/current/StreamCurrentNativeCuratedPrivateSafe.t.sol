// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./helpers/NativeCuratedSaleFixture.sol";
import {
    StreamNativeCuratedPrivateSale
} from "../../smart-contracts/domains/mint/StreamNativeCuratedPrivateSale.sol";
import {
    StreamPrivateSaleHash
} from "../../smart-contracts/domains/mint/StreamPrivateSaleHash.sol";
import { StreamMintTicketHash } from "../../smart-contracts/domains/mint/StreamMintTicketHash.sol";
import {
    IStreamNativeRefundDelegatedClaims
} from "../../smart-contracts/interfaces/stream/mint/IStreamNativeRefundDelegatedClaims.sol";

/// @notice Real official Safe proxy/handler bytecode and threshold signatures join the actual
/// current private-sale Manager/Core/Ledger/recorder graph. No ERC1271 signer substitute is used.
contract StreamCurrentNativeCuratedPrivateSafeTest is NativeCuratedSaleFixture {
    StreamNativeCuratedPrivateSale private privateSale;

    function setUp() public override {
        super.setUp();
        privateSale = new StreamNativeCuratedPrivateSale(_curatedDeployment());
        _registerCuratedHost(address(privateSale));
        entropy.configure(7, 1, false, false);
    }

    function testOfficialSafeBuyerCallsFullPrivateAuthorizationOwnsNFTAndClaimsFeeCredit() public {
        (OfficialSafe buyer, uint256[] memory keys) = _safe("1.4.1", 401);
        (CuratedPlan memory p, Curated.Selection memory chosen) =
            _open(address(buyer), vm.addr(SIGNER_KEY), 1, 1);
        StreamPrivateSaleTypes.SaleAuthorization memory authorization = _authorization(p, chosen);
        uint256 before = address(buyer).balance;
        // A valid seller signature for another executor cannot turn a Safe CALL into that executor.
        authorization.executor = payer;
        bytes memory wrong = _safePayload(
            buyer,
            keys,
            1027,
            _purchaseData(
                authorization,
                chosen,
                IStreamPrivateSaleAdapter.Signature(
                    vm.addr(SIGNER_KEY), 1, _curatedSignature(SIGNER_KEY, _digest(authorization))
                )
            )
        );
        (bool ok,) = address(buyer).call(wrong);
        require(!ok && buyer.nonce() == 0, "signed executor must be the actual Safe caller");
        authorization.executor = address(buyer);
        bytes32 digest = _digest(authorization);
        bytes memory purchaseData = _purchaseData(
            authorization,
            chosen,
            IStreamPrivateSaleAdapter.Signature(
                vm.addr(SIGNER_KEY), 1, _curatedSignature(SIGNER_KEY, digest)
            )
        );
        require(
            executeSafe(buyer, keys, address(privateSale), 1027, purchaseData, 0),
            "official Safe CALL purchase"
        );
        Curated.ExecutionRecord memory execution = _assertPurchase(p, chosen, authorization);
        require(
            buyer.nonce() == 1 && buyer.getThreshold() == 2
                && core.ownerOf(execution.tokenId) == address(buyer)
                && recorder.settlementResult(execution.settlementKey).executor == address(buyer)
                && address(buyer).balance == before - 1027 && wallet.balance == 1000
                && entropy.revealFeeEscrow(1) == 7
                && privateSale.refundableBalance(p.saleId, address(buyer)) == 20
                && privateSale.refundableBalance(p.saleId, address(this)) == 0,
            "Safe remains executor buyer owner and fee-credit beneficiary"
        );
        vm.etch(address(entropy), hex"60006000fd");
        require(
            executeSafe(
                buyer,
                keys,
                address(privateSale),
                0,
                abi.encodeCall(privateSale.claimRefund, (p.saleId, address(buyer))),
                0
            ),
            "Safe buyer pulls its own fee credit"
        );
        require(
            buyer.nonce() == 2 && address(buyer).balance == before - 1007
                && privateSale.totalBuyerLiabilities() == 0 && address(privateSale).balance == 0,
            "actual Safe refund conserves price plus live reveal fee without provider reads"
        );
    }

    function testOfficialSafeSellerERC1271UsesOriginalSaleDigestAndOfficialFallbackHandler()
        public
    {
        (OfficialSafe seller, uint256[] memory keys) = _safe("1.5.0", 501);
        (CuratedPlan memory p, Curated.Selection memory chosen) =
            _open(payer, address(seller), 2, 0);
        StreamPrivateSaleTypes.SaleAuthorization memory authorization = _authorization(p, chosen);
        bytes32 digest = _digest(authorization);
        bytes memory rawOwnerSignatures = safeThresholdSignature(keys, digest);
        IStreamPrivateSaleAdapter.Signature memory proof =
            IStreamPrivateSaleAdapter.Signature(address(seller), 2, rawOwnerSignatures);
        vm.prank(payer);
        (bool ok,) =
            address(privateSale).call{ value: 1007 }(_purchaseData(authorization, chosen, proof));
        require(
            !ok && core.lastAllocatedTokenId() == 0
                && !ledger.isManagerAuthorizationUsed(
                    address(manager), StreamMintTicketHash.authorizationId(digest)
                ),
            "raw owner signatures cannot replace SafeMessage authorization"
        );
        proof.signature =
            safeThresholdSignature(keys, safeMessageDigest(seller, abi.encode(digest)));
        (ok, rawOwnerSignatures) = address(seller)
            .staticcall(abi.encodeWithSelector(bytes4(0x1626ba7e), digest, proof.signature));
        require(
            ok && rawOwnerSignatures.length == 32
                && abi.decode(rawOwnerSignatures, (bytes4)) == bytes4(0x1626ba7e),
            "genuine official compatibility handler validates the wrapped full Stream digest"
        );
        // Same declared manifest but altered signed content cannot reuse the authorized seller proof.
        StreamPrivateSaleTypes.SaleAuthorization memory altered =
            abi.decode(abi.encode(authorization), (StreamPrivateSaleTypes.SaleAuthorization));
        altered.tokenDataArrayHash = keccak256("changed signed token bytes array");
        vm.prank(payer);
        (ok,) = address(privateSale).call{ value: 1007 }(_purchaseData(altered, chosen, proof));
        require(
            !ok && privateSale.nextPurchaseNonce(p.saleId, payer) == 1,
            "Safe seller proof binds full original batch fields"
        );
        vm.prank(payer);
        privateSale.purchasePrivateContent{ value: 1007 }(authorization, proof, chosen, _direct());
        Curated.ExecutionRecord memory execution = _assertPurchase(p, chosen, authorization);
        require(
            core.tokenData(execution.tokenId).length == 0
                && core.ownerOf(execution.tokenId) == payer && seller.nonce() == 0
                && seller.getThreshold() == 2
                && privateSale.privateSaleConfiguration(p.saleId).signer == address(seller)
                && privateSale.privateSaleConfiguration(p.saleId).signerKind == 2,
            "static Safe seller authority retains published empty work and no Safe transaction nonce"
        );
    }

    function testIdenticalOfficialSafePrivatePurchaseRetriesLateCoreFailureWithOriginalNonces()
        public
    {
        (OfficialSafe buyer, uint256[] memory keys) = _safe("1.5.0", 502);
        (CuratedPlan memory p, Curated.Selection memory chosen) =
            _open(address(buyer), vm.addr(SIGNER_KEY), 1, 2);
        StreamPrivateSaleTypes.SaleAuthorization memory authorization = _authorization(p, chosen);
        bytes32 digest = _digest(authorization);
        bytes memory exact = _safePayload(
            buyer,
            keys,
            1027,
            _purchaseData(
                authorization,
                chosen,
                IStreamPrivateSaleAdapter.Signature(
                    vm.addr(SIGNER_KEY), 1, _curatedSignature(SIGNER_KEY, digest)
                )
            )
        );
        uint256 before = address(buyer).balance;
        entropy.configure(7, 1, true, false);
        (bool ok,) = address(buyer).call(exact);
        require(
            !ok && buyer.nonce() == 0 && address(buyer).balance == before
                && privateSale.nextPurchaseNonce(p.saleId, address(buyer)) == 1
                && privateSale.saleRecord(p.saleId).status == 1
                && !ledger.isManagerAuthorizationUsed(
                    address(manager), StreamMintTicketHash.authorizationId(digest)
                ) && ledger.counterValue(_curatedCounterKey(p, 2)) == 0
                && manager.nextOperationNonce() == 0,
            "late Core failure restores original Safe authorization purchase and ledger nonces"
        );
        require(
            core.lastAllocatedTokenId() == 0 && core.collectionNextSerial(1) == 1
                && core.pendingPreparedMintTokenId() == 0
                && manager.preparedNativeContentAdmission() == 0
                && manager.activePreparedNativeContent().operationRoot == 0 && wallet.balance == 0
                && recorder.totalOfficialSettled(address(0)) == 0
                && privateSale.totalBuyerLiabilities() == 0 && address(privateSale).balance == 0
                && entropy.revealFeeEscrow(1) == 0 && entropy.mintCalls() == 0,
            "actual paid callback allocation fee and official settlement rolled back"
        );
        entropy.configure(7, 1, false, false);
        bytes memory returned;
        (ok, returned) = address(buyer).call(exact);
        require(
            ok && returned.length == 32 && abi.decode(returned, (bool)),
            "identical fully signed Safe payload retries"
        );
        Curated.ExecutionRecord memory execution = _assertPurchase(p, chosen, authorization);
        require(
            buyer.nonce() == 1 && execution.tokenId == 1 && core.ownerOf(1) == address(buyer)
                && wallet.balance == 1000 && entropy.revealFeeEscrow(1) == 7
                && privateSale.refundableBalance(p.saleId, address(buyer)) == 20,
            "one repaired current-stack purchase with original buyer and exact price"
        );
        (ok,) = address(buyer).call(exact);
        require(
            !ok && buyer.nonce() == 1 && core.lastAllocatedTokenId() == 1
                && recorder.totalOfficialSettled(address(0)) == 1000,
            "successful original Safe payload cannot replay"
        );
    }

    function _safe(string memory version, uint256 salt)
        private
        returns (OfficialSafe account, uint256[] memory keys)
    {
        keys = new uint256[](2);
        keys[0] = 0x5AFE731;
        keys[1] = 0x5AFE732;
        account =
            createOfficialSafe(deploySafeComponents(version), safeOwnerAddresses(keys), 2, salt);
        require(
            keccak256(bytes(account.VERSION())) == keccak256(bytes(version)),
            "actual upstream Safe version"
        );
        vm.deal(address(account), 1 ether);
    }

    function _open(address buyer, address signer, uint8 kind, uint256 index)
        private
        returns (CuratedPlan memory p, Curated.Selection memory chosen)
    {
        p = _curatedPlan(address(privateSale), 5, Curated.SelectionMode.PUBLIC);
        privateSale.configureCollectionSigner(
            1, signer, kind, keccak256("official Safe private seller evidence"), true
        );
        Curated.CollectionSigner memory member = privateSale.collectionSigner(1, signer, kind);
        Curated.PrivateConfiguration memory config;
        config.sale = p.config;
        config.buyer = buyer;
        config.contentId = bytes32(index);
        config.tokenDataHash = keccak256(_curatedArtwork(index));
        config.signer = signer;
        config.signerKind = kind;
        config.signerEvidenceHash = member.evidenceHash;
        config.signerRevision = member.revision;
        config.signerAuthority = member.authority;
        chosen = _curatedSelection(p, index, buyer, 1);
        bytes32 saleId = privateSale.registerCuratedPrivateSale(config, chosen.content.proof);
        require(
            saleId == p.saleId && privateSale.saleRecord(saleId).saleNonce == p.nonce,
            "original immutable private creation identity"
        );
        _bindCuratedConsent(saleId, privateSale.privateConfigurationHash(config));
        vm.warp(p.config.startsAt);
    }

    function _authorization(CuratedPlan memory p, Curated.Selection memory chosen)
        private
        view
        returns (StreamPrivateSaleTypes.SaleAuthorization memory a)
    {
        address[] memory recipients = new address[](1);
        recipients[0] = address(privateSale);
        address[] memory beneficiaries = new address[](1);
        beneficiaries[0] = chosen.recipient;
        bytes[] memory data = new bytes[](1);
        data[0] = chosen.tokenData;
        bytes32[] memory commitments = new bytes32[](1);
        commitments[0] = chosen.mintCommitment;
        a.chainId = block.chainid;
        a.saleAdapter = address(privateSale);
        a.mintManager = address(manager);
        a.collectionId = 1;
        a.phaseId = p.config.phaseId;
        a.saleId = p.saleId;
        a.saleKind = 5;
        a.revenueClass = CLASS;
        a.expectedPrimaryPolicyHash = p.config.expectedPrimaryPolicyHash;
        a.primaryPolicyMode = 0;
        a.initialRecipientsHash =
            keccak256(abi.encode(keccak256("6529STREAM_MINT_BATCH_RECIPIENTS_V1"), recipients));
        a.beneficiariesHash = keccak256(
            abi.encode(keccak256("6529STREAM_MINT_BATCH_BENEFICIARIES_V1"), beneficiaries)
        );
        a.tokenDataArrayHash =
            keccak256(abi.encode(keccak256("6529STREAM_MINT_BATCH_TOKEN_DATA_V1"), data));
        a.mintCommitmentsHash =
            keccak256(abi.encode(keccak256("6529STREAM_MINT_BATCH_COMMITMENTS_V1"), commitments));
        a.payer = chosen.recipient;
        a.executor = chosen.recipient;
        a.asset = address(0);
        a.unitPrice = p.config.price;
        a.quantity = 1;
        a.contentSelectionHash = p.leaves[uint256(chosen.content.contentId)];
        a.policyHash = p.config.mintPolicyHash;
        a.nonce =
            keccak256(abi.encode("official Safe full private nonce", p.saleId, chosen.recipient));
        a.deadline = p.config.endsAt;
        a.finalizeBy = 0;
    }

    function _digest(StreamPrivateSaleTypes.SaleAuthorization memory a)
        private
        view
        returns (bytes32 digest)
    {
        bytes32 typeHash = keccak256(
            "SaleAuthorization(uint256 chainId,address saleAdapter,address mintManager,uint256 collectionId,bytes32 phaseId,bytes32 saleId,uint8 saleKind,bytes32 revenueClass,bytes32 expectedPrimaryPolicyHash,uint8 primaryPolicyMode,bytes32 initialRecipientsHash,bytes32 beneficiariesHash,bytes32 tokenDataArrayHash,bytes32 mintCommitmentsHash,address payer,address executor,address asset,uint256 unitPrice,uint256 quantity,bytes32 contentSelectionHash,bytes32 policyHash,bytes32 nonce,uint64 deadline,uint64 finalizeBy)"
        );
        bytes32 domain = keccak256(
            abi.encode(
                keccak256(
                    "EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"
                ),
                keccak256("6529Stream Sales"),
                keccak256("1"),
                block.chainid,
                address(privateSale)
            )
        );
        digest = keccak256(abi.encodePacked(hex"1901", domain, keccak256(abi.encode(typeHash, a))));
        require(
            digest
                == StreamPrivateSaleHash.digest(
                    block.chainid, address(privateSale), StreamPrivateSaleHash.authorizationBody(a)
                ),
            "unchanged full original SSA type and EIP712 domain"
        );
    }

    function _purchaseData(
        StreamPrivateSaleTypes.SaleAuthorization memory a,
        Curated.Selection memory chosen,
        IStreamPrivateSaleAdapter.Signature memory proof
    ) private view returns (bytes memory) {
        return abi.encodeCall(privateSale.purchasePrivateContent, (a, proof, chosen, _direct()));
    }

    function _direct()
        private
        pure
        returns (IStreamNativeRefundDelegatedClaims.DelegationWitness memory)
    {
        return IStreamNativeRefundDelegatedClaims.DelegationWitness(false, 0);
    }

    function _safePayload(
        OfficialSafe account,
        uint256[] memory keys,
        uint256 value,
        bytes memory data
    ) private returns (bytes memory) {
        bytes32 hash = account.getTransactionHash(
            address(privateSale), value, data, 0, 0, 0, 0, address(0), address(0), account.nonce()
        );
        return abi.encodeCall(
            account.execTransaction,
            (
                address(privateSale),
                value,
                data,
                0,
                0,
                0,
                0,
                address(0),
                payable(address(0)),
                safeThresholdSignature(keys, hash)
            )
        );
    }

    function _assertPurchase(
        CuratedPlan memory p,
        Curated.Selection memory chosen,
        StreamPrivateSaleTypes.SaleAuthorization memory a
    ) private view returns (Curated.ExecutionRecord memory e) {
        bytes32 purchase = privateSale.purchaseIdFor(p.saleId, a.payer, chosen.purchaseNonce);
        e = privateSale.executionRecord(purchase);
        _assertCuratedExecution(p, uint256(chosen.content.contentId), e);
        require(
            e.buyer == a.payer && e.recipient == a.payer && e.purchaseNonce == chosen.purchaseNonce
                && e.authorizationDigest == _digest(a)
                && e.authorizationId == StreamMintTicketHash.authorizationId(_digest(a))
                && e.mintCommitment == chosen.mintCommitment
                && privateSale.saleRecord(p.saleId).status == 4
                && privateSale.nextPurchaseNonce(p.saleId, a.payer) == 2,
            "complete immutable signed private execution readback"
        );
        require(
            IStreamPreparedNativeContentPurchaseSettlement(address(recorder))
                .preparedNativeContentPurchaseConsumed(address(privateSale), purchase)
            && !recorder.preparedNativeSaleConsumed(
                recorder.preparedNativeSaleKey(address(privateSale), p.saleId, p.nonce)
            ),
            "actual additive recorder consumes purchase only"
        );
    }
}
