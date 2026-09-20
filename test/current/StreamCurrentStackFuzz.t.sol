// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../helpers/CurrentStatefulConservationFixture.sol";
import "../../smart-contracts/domains/revenue/StreamDirectPrimarySaleFloorCall.sol";

interface StatefulFuzzFaultVm {
    function mockCallRevert(address target, bytes calldata data, bytes calldata reason) external;
    function expectCall(address target, bytes calldata data) external;
    function clearMockedCalls() external;
}

/// @notice Input-fuzzed sale properties against the sealed current contract stack.
/// @dev Prices include zero and rounding dust; signatures are real EIP-712 signatures.
contract StreamCurrentStackFuzzTest is CurrentStatefulConservationFixture {
    function setUp() public {
        vm.deal(address(this), 300 ether);
        _deployCurrentStack(vm.addr(ARTIST_KEY), vm.addr(PLATFORM_KEY));
        _enableStatefulConservation(address(0));
    }

    function testFuzzNativeSettlementConservesEveryWei(uint128 priceSeed) public {
        uint256 price = uint256(priceSeed) % (100 ether + 1);
        IStreamFixedPriceSaleAdapter.SaleAuthorization memory auth = _authorization(price);
        (bytes memory platformSig, bytes memory artistSig) = _sign(auth);
        uint256 payerBefore = address(this).balance;
        (uint256 tokenId, bytes32 operationRoot) =
            sale.buy{ value: price }(auth, TOKEN_DATA, platformSig, artistSig);

        require(core.ownerOf(tokenId) == BUYER, "recipient owns mint");
        require(core.totalSupply() == 1 && core.collectionMintedEver(1) == 1, "one mint");
        require(manager.isOperationRootUsed(operationRoot), "canonical operation consumed");
        require(address(this).balance == payerBefore - price, "payer charged exact amount");
        require(wallet.balance == price && address(sale).balance == 0, "all value reaches split");
        require(sale.totalNativeProceeds() == price, "sale proceeds match receipts");
        _assertPaid(auth, tokenId, operationRoot);
        bytes32 evidence =
            _statefulDirectEvidenceHash(address(sale), sale.authorizationId(artist, auth.nonce));

        // Independent integer arithmetic for the fixture's 90/10 split, including dust.
        uint256 artistShare = price * 9 / 10;
        uint256 protocolShare = price / 10;
        IStreamSplitWallet split = IStreamSplitWallet(wallet);
        require(split.releasable(address(0), artist) == artistShare, "artist entitlement");
        require(split.releasable(address(0), PROTOCOL) == protocolShare, "protocol entitlement");
        uint256 artistBefore = artist.balance;
        uint256 protocolBefore = PROTOCOL.balance;
        if (artistShare != 0) split.release(address(0), artist, payable(artist));
        if (protocolShare != 0) split.release(address(0), PROTOCOL, payable(PROTOCOL));
        require(artist.balance - artistBefore == artistShare, "artist paid exactly");
        require(PROTOCOL.balance - protocolBefore == protocolShare, "protocol paid exactly");
        require(wallet.balance + artistShare + protocolShare == price, "wei conserved");
        require(wallet.balance <= 1, "only rounding dust remains");
        require(split.observedReceived(address(0)) == price, "receipts survive releases");
        require(split.releasable(address(0), artist) == 0, "artist cannot withdraw twice");
        require(split.releasable(address(0), PROTOCOL) == 0, "protocol cannot withdraw twice");
        require(
            _statefulDirectEvidenceHash(address(sale), sale.authorizationId(artist, auth.nonce))
                == evidence,
            "all original floor first and empty release evidence survives beneficiary releases"
        );
    }

    function testFuzzIncorrectValueDoesNotConsumeSale(uint128 priceSeed, bool overpay) public {
        uint256 price = uint256(priceSeed) % 100 ether + 1;
        IStreamFixedPriceSaleAdapter.SaleAuthorization memory auth = _authorization(price);
        (bytes memory platformSig, bytes memory artistSig) = _sign(auth);
        uint256 sent = overpay ? price + 1 : price - 1;
        uint256 payerBefore = address(this).balance;
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamFixedPriceSaleAdapter.IncorrectSaleValue.selector, price, sent
            )
        );
        sale.buy{ value: sent }(auth, TOKEN_DATA, platformSig, artistSig);
        _assertUnconsumed(auth, payerBefore);
        // The exact signed authorization remains usable after the failed attempt.
        (uint256 tokenId, bytes32 root) =
            sale.buy{ value: price }(auth, TOKEN_DATA, platformSig, artistSig);
        require(core.totalSupply() == 1 && wallet.balance == price, "correct retry succeeds");
        _assertPaid(auth, tokenId, root);
    }

    function testFuzzChangedPriceInvalidatesConsent(uint128 priceSeed, uint128 increaseSeed)
        public
    {
        uint256 price = uint256(priceSeed) % (100 ether + 1);
        IStreamFixedPriceSaleAdapter.SaleAuthorization memory auth = _authorization(price);
        (bytes memory platformSig, bytes memory artistSig) = _sign(auth);
        auth.price = price + uint256(increaseSeed) % 100 ether + 1;
        uint256 payerBefore = address(this).balance;
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamFixedPriceSaleAdapter.InvalidSaleSignature.selector, vm.addr(PLATFORM_KEY)
            )
        );
        // Send the changed amount so the signature check, not the value check, rejects it.
        sale.buy{ value: auth.price }(auth, TOKEN_DATA, platformSig, artistSig);
        _assertUnconsumed(auth, payerBefore);
        auth.price = price;
        (uint256 tokenId, bytes32 root) =
            sale.buy{ value: price }(auth, TOKEN_DATA, platformSig, artistSig);
        _assertPaid(auth, tokenId, root);
    }

    function testFuzzConsumedAuthorizationCannotMintOrChargeAgain(uint128 priceSeed) public {
        uint256 price = uint256(priceSeed) % (100 ether + 1);
        IStreamFixedPriceSaleAdapter.SaleAuthorization memory auth = _authorization(price);
        (bytes memory platformSig, bytes memory artistSig) = _sign(auth);
        (uint256 tokenId, bytes32 operationRoot) =
            sale.buy{ value: price }(auth, TOKEN_DATA, platformSig, artistSig);
        uint256 payerBeforeReplay = address(this).balance;
        uint256 ledgerNonce = manager.nextOperationNonce();
        _assertPaid(auth, tokenId, operationRoot);
        bytes32 evidence =
            _statefulDirectEvidenceHash(address(sale), sale.authorizationId(artist, auth.nonce));
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamFixedPriceSaleAdapter.SaleAlreadyConsumed.selector, artist, auth.nonce
            )
        );
        sale.buy{ value: price }(auth, TOKEN_DATA, platformSig, artistSig);
        require(address(this).balance == payerBeforeReplay, "replay cannot charge payer");
        require(wallet.balance == price && sale.totalNativeProceeds() == price, "no second receipt");
        require(core.totalSupply() == 1 && core.collectionMintedEver(1) == 1, "no second mint");
        require(core.ownerOf(tokenId) == BUYER, "owner unchanged");
        require(manager.nextOperationNonce() == ledgerNonce, "no second ledger operation");
        require(manager.isOperationRootUsed(operationRoot), "first operation retained");
        require(
            _statefulDirectEvidenceHash(address(sale), sale.authorizationId(artist, auth.nonce))
                == evidence,
            "replay preserves all original and floor evidence"
        );
        _assertNativeCounter(1);
    }

    function testFuzzExpiryIsInclusiveAndFailurePreservesConsent(uint32 durationSeed) public {
        IStreamFixedPriceSaleAdapter.SaleAuthorization memory auth = _authorization(1 wei);
        auth.deadline = uint64(block.timestamp + uint256(durationSeed) % 7 days);
        (bytes memory platformSig, bytes memory artistSig) = _sign(auth);
        uint256 payerBefore = address(this).balance;
        vm.warp(uint256(auth.deadline) + 1);
        vm.expectRevert(
            abi.encodeWithSelector(IStreamFixedPriceSaleAdapter.SaleExpired.selector, auth.deadline)
        );
        sale.buy{ value: 1 wei }(auth, TOKEN_DATA, platformSig, artistSig);
        _assertUnconsumed(auth, payerBefore);
        // Rewind only the test clock to independently exercise the inclusive boundary.
        vm.warp(auth.deadline);
        (uint256 tokenId, bytes32 root) =
            sale.buy{ value: 1 wei }(auth, TOKEN_DATA, platformSig, artistSig);
        require(core.totalSupply() == 1, "deadline itself is valid");
        _assertPaid(auth, tokenId, root);
    }

    function testFuzzOfficialSafeIsTheLiteralPaidCaller(uint128 priceSeed) public {
        uint256 price = uint256(priceSeed) % 100 ether + 1;
        vm.deal(address(governorSafe), 300 ether);
        IStreamFixedPriceSaleAdapter.SaleAuthorization memory auth = _authorization(price);
        auth.payer = address(governorSafe);
        (bytes memory platformSig, bytes memory artistSig) = _sign(auth);
        uint256 callerBalance = address(this).balance;
        uint256 safeNonce = governorSafe.nonce();
        vm.expectRevert(
            abi.encodeWithSelector(IStreamFixedPriceSaleAdapter.InvalidSaleAuthorization.selector)
        );
        sale.buy{ value: price }(auth, TOKEN_DATA, platformSig, artistSig);
        _assertUnconsumed(auth, callerBalance);
        require(
            address(governorSafe).balance == 300 ether && governorSafe.nonce() == safeNonce,
            "wrong caller cannot spend Safe funds or nonce"
        );
        require(
            executeSafe(
                governorSafe,
                governorKeys,
                address(sale),
                price,
                abi.encodeCall(sale.buy, (auth, TOKEN_DATA, platformSig, artistSig)),
                0
            ),
            "actual threshold Safe submits unchanged signed buy"
        );
        bytes32 id = sale.authorizationId(artist, auth.nonce);
        StreamDirectPrimarySaleTypes.Receipt memory original = sale.directPrimarySaleReceipt(id);
        _assertPaid(auth, original.tokenId, original.operationRoot);
        require(
            original.payer == address(governorSafe) && original.beneficiary == BUYER
                && address(governorSafe).balance == 300 ether - price
                && address(this).balance == callerBalance && governorSafe.nonce() == safeNonce + 1,
            "receipt binds actual Safe payer independently of submitting test relayer"
        );
    }

    function testFuzzLateFloorFailureRollsBackEveryWeiAndExactAuthorizationRetries(uint128 priceSeed)
        public
    {
        uint256 price = uint256(priceSeed) % 100 ether + 1;
        IStreamFixedPriceSaleAdapter.SaleAuthorization memory auth = _authorization(price);
        (bytes memory platformSig, bytes memory artistSig) = _sign(auth);
        bytes32 id = sale.authorizationId(artist, auth.nonce);
        bytes32 beforeEvidence = _statefulDirectEvidenceHash(address(sale), id);
        uint256 payerBefore = address(this).balance;
        bytes4 cause = bytes4(keccak256("StatefulLateFloorFault()"));
        bytes memory floorCall =
            abi.encodeCall(IStreamDirectPrimaryConservationFloor.recordDirectPrimarySale, (id));
        // Only this named failed branch substitutes the final floor call; the retry uses the
        // actual bound production consumer and exact original signed buy/value/caller.
        StatefulFuzzFaultVm(address(vm))
            .mockCallRevert(address(commerceFloor), floorCall, abi.encodeWithSelector(cause));
        StatefulFuzzFaultVm(address(vm)).expectCall(address(commerceFloor), floorCall);
        vm.expectRevert(
            abi.encodeWithSelector(
                StreamDirectPrimarySaleFloorCall.DirectSaleFloorCallFailed.selector,
                address(commerceFloor),
                cause
            )
        );
        sale.buy{ value: price }(auth, TOKEN_DATA, platformSig, artistSig);
        _assertUnconsumed(auth, payerBefore);
        require(
            _statefulDirectEvidenceHash(address(sale), id) == beforeEvidence,
            "late rejection preserves complete floor state"
        );
        StatefulFuzzFaultVm(address(vm)).clearMockedCalls();
        (uint256 tokenId, bytes32 root) =
            sale.buy{ value: price }(auth, TOKEN_DATA, platformSig, artistSig);
        _assertPaid(auth, tokenId, root);
        require(
            wallet.balance == price && address(this).balance == payerBefore - price,
            "genuine retry funds once"
        );
    }

    function _assertUnconsumed(
        IStreamFixedPriceSaleAdapter.SaleAuthorization memory auth,
        uint256 payerBalance
    ) private view {
        bytes32 id = sale.authorizationId(artist, auth.nonce);
        require(
            !sale.authorizationUsed(artist, auth.nonce) && !manager.isAuthorizationUsed(id),
            "failed attempt consumed consent"
        );
        require(
            core.totalSupply() == 0 && core.collectionMintedEver(1) == 0, "failed attempt minted"
        );
        require(manager.nextOperationNonce() == 0, "failed attempt changed ledger");
        require(wallet.balance == 0 && sale.totalNativeProceeds() == 0, "failed attempt paid");
        require(address(this).balance == payerBalance, "failed attempt charged payer");
        require(
            core.lastAllocatedTokenId() == 0 && address(sale).balance == 0
                && entropy.tokenEntropyStatus(1) == StreamEntropyStatus.NONE
                && revenueEscrow.totalOwed(address(0)) == 0 && address(revenueEscrow).balance == 0
                && revenueEscrow.escrowOwed(PRIMARY_REVENUE_CLASS, profile, wallet, address(0))
                    == 0,
            "no allocation entropy cash or escrow progress"
        );
        _assertNativeCounter(0);
        _assertNoStatefulDirectReceipt(address(sale), id);
        _assertNoCommerceFloorReceipt(_statefulDirectKey(address(sale), id));
    }

    function _assertPaid(
        IStreamFixedPriceSaleAdapter.SaleAuthorization memory auth,
        uint256 tokenId,
        bytes32 root
    ) private view {
        bytes32 id = sale.authorizationId(artist, auth.nonce);
        _assertStatefulDirectReceipt(address(sale), id, auth.price);
        require(
            sale.authorizationUsed(artist, auth.nonce) && manager.isAuthorizationUsed(id)
                && manager.isOperationRootUsed(root) && manager.nextOperationNonce() == 1
                && core.ownerOf(tokenId) == auth.recipient && core.tokenLifecycle(tokenId) == 2
                && entropy.tokenEntropyStatus(tokenId) == StreamEntropyStatus.REGISTERED,
            "one genuine operation and literal recipient"
        );
        _assertNativeCounter(1);
        if (auth.price == 0) {
            require(commerceFloor.firstSale(1).receiptHash == 0, "free mint is not first paid sale");
            return;
        }
        StreamDirectPrimarySaleTypes.Receipt memory original = sale.directPrimarySaleReceipt(id);
        require(
            original.authorizationDigest == sale.authorizationDigest(auth)
                && original.collectionId == auth.collectionId && original.tokenId == tokenId
                && original.operationRoot == root
                && original.boundMintPolicyHash == auth.mintPolicyHash
                && original.expectedPrimaryPolicyHash == auth.expectedPrimaryPolicyHash
                && original.profileId == auth.profileId && original.wallet == wallet
                && original.payer == auth.payer && original.beneficiary == auth.recipient
                && original.asset == address(0) && original.amount == auth.price
                && !original.escrowed && original.createdAt == block.timestamp
                && original.registryRevision == registry.moduleRecord(address(sale)).revision,
            "original literal authorization retained in complete paid receipt"
        );
        StreamConservationFloorTypes.FirstSaleReceipt memory first = commerceFloor.firstSale(1);
        require(
            first.recorder == address(sale)
                && first.settlementKey == _statefulDirectKey(address(sale), id),
            "actual first paid operation owns first receipt"
        );
    }

    function _assertNativeCounter(uint64 expected) private view {
        bytes32 counterId = keccak256("supply");
        bytes32 subject = keccak256(
            abi.encode(
                keccak256("6529STREAM_MINT_COUNTER_SUBJECT_V1"),
                block.chainid,
                address(ledger),
                IStreamMintManager.CounterKeyMode.CONSTANT,
                uint256(1),
                PHASE,
                counterId
            )
        );
        require(
            manager.counterValue(1, PHASE, counterId, subject) == expected,
            "independent original phase counter"
        );
    }

    function _sign(IStreamFixedPriceSaleAdapter.SaleAuthorization memory auth)
        private
        returns (bytes memory platformSig, bytes memory artistSig)
    {
        bytes32 digest = sale.authorizationDigest(auth);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(PLATFORM_KEY, digest);
        platformSig = abi.encodePacked(r, s, v);
        (v, r, s) = vm.sign(ARTIST_KEY, digest);
        artistSig = abi.encodePacked(r, s, v);
    }

    function _authorization(uint256 price)
        private
        view
        returns (IStreamFixedPriceSaleAdapter.SaleAuthorization memory)
    {
        return IStreamFixedPriceSaleAdapter.SaleAuthorization({
            collectionId: 1,
            phaseId: PHASE,
            payer: address(this),
            recipient: BUYER,
            artist: artist,
            profileId: profile,
            expectedPrimaryPolicyHash: _nativePrimaryPolicyHash(),
            tokenDataHash: keccak256(TOKEN_DATA),
            mintCommitment: keccak256("input fuzz artwork"),
            mintPolicyHash: manager.phasePolicyHash(1, PHASE),
            price: price,
            nonce: keccak256("input fuzz authorization"),
            deadline: uint64(block.timestamp + 1 days),
            signerEpoch: sale.signerEpoch()
        });
    }
}
