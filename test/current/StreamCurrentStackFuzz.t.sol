// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../helpers/StreamCurrentStackFixture.sol";

/// @notice Input-fuzzed sale properties against the sealed current contract stack.
/// @dev Prices include zero and rounding dust; signatures are real EIP-712 signatures.
contract StreamCurrentStackFuzzTest is StreamCurrentStackFixture {
    function setUp() public {
        vm.deal(address(this), 300 ether);
        _deployCurrentStack(vm.addr(ARTIST_KEY), vm.addr(PLATFORM_KEY));
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
        _assertUnconsumed(auth.nonce, payerBefore);
        // The exact signed authorization remains usable after the failed attempt.
        sale.buy{ value: price }(auth, TOKEN_DATA, platformSig, artistSig);
        require(core.totalSupply() == 1 && wallet.balance == price, "correct retry succeeds");
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
        _assertUnconsumed(auth.nonce, payerBefore);
    }

    function testFuzzConsumedAuthorizationCannotMintOrChargeAgain(uint128 priceSeed) public {
        uint256 price = uint256(priceSeed) % (100 ether + 1);
        IStreamFixedPriceSaleAdapter.SaleAuthorization memory auth = _authorization(price);
        (bytes memory platformSig, bytes memory artistSig) = _sign(auth);
        (uint256 tokenId, bytes32 operationRoot) =
            sale.buy{ value: price }(auth, TOKEN_DATA, platformSig, artistSig);
        uint256 payerBeforeReplay = address(this).balance;
        uint256 ledgerNonce = manager.nextOperationNonce();
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
        _assertUnconsumed(auth.nonce, payerBefore);
        // Rewind only the test clock to independently exercise the inclusive boundary.
        vm.warp(auth.deadline);
        sale.buy{ value: 1 wei }(auth, TOKEN_DATA, platformSig, artistSig);
        require(core.totalSupply() == 1, "deadline itself is valid");
    }

    function _assertUnconsumed(bytes32 nonce, uint256 payerBalance) private view {
        require(!sale.authorizationUsed(artist, nonce), "failed attempt consumed consent");
        require(
            core.totalSupply() == 0 && core.collectionMintedEver(1) == 0, "failed attempt minted"
        );
        require(manager.nextOperationNonce() == 0, "failed attempt changed ledger");
        require(wallet.balance == 0 && sale.totalNativeProceeds() == 0, "failed attempt paid");
        require(address(this).balance == payerBalance, "failed attempt charged payer");
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
