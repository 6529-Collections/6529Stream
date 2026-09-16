// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../helpers/StreamCurrentStackFixture.sol";
import "../helpers/OfficialSafeFixture.sol";

interface CurrentCallOnlyMultiSend {
    function multiSend(bytes calldata transactions) external payable;
}

/// @dev A downstream caller-owned condition, after the actual protocol calls.
contract CurrentBatchPostcondition {
    bool public accepted;

    function accept() external {
        accepted = true;
    }

    function check() external view {
        require(accepted, "batch postcondition rejected");
    }

    function succeed() external pure { }
}

/// @notice Real Safe 1.4.1 all-CALL batches across paid mint, reveal and custody.
/// @dev Core, Manager, Ledger, Artist, Executor, split and entropy are actual products.
/// Only the external entropy service and the downstream rejection trigger are test controls.
contract StreamCurrentSafeBatchTest is StreamCurrentStackFixture, OfficialSafeFixture {
    OfficialSafe private artistSafe;
    OfficialSafe private buyerSafe;
    address private multiSend;
    uint256[] private keys;
    SafeComponents private safeComponents;

    function setUp() public {
        keys.push(0x5AFE01);
        keys.push(0x5AFE02);
        SafeComponents memory components = deploySafeComponents("1.4.1");
        safeComponents = components;
        multiSend = components.multiSend;
        artistSafe = createOfficialSafe(components, safeOwnerAddresses(keys), 2, 301);
        buyerSafe = createOfficialSafe(components, safeOwnerAddresses(keys), 2, 302);
        _deployCurrentStack(address(artistSafe), vm.addr(PLATFORM_KEY));
        vm.deal(address(buyerSafe), 20 ether);
    }

    function _artistProof(bytes32 digest) internal override returns (bytes memory) {
        return safeThresholdSignature(keys, safeMessageDigest(artistSafe, abi.encode(digest)));
    }

    function _authorization(uint256 price)
        private
        view
        returns (IStreamFixedPriceSaleAdapter.SaleAuthorization memory a)
    {
        a = IStreamFixedPriceSaleAdapter.SaleAuthorization({
            collectionId: 1,
            phaseId: PHASE,
            payer: address(buyerSafe),
            recipient: address(buyerSafe),
            artist: address(artistSafe),
            profileId: profile,
            expectedPrimaryPolicyHash: _nativePrimaryPolicyHash(),
            tokenDataHash: keccak256(TOKEN_DATA),
            mintCommitment: keccak256("all-call current Safe artwork"),
            mintPolicyHash: manager.phasePolicyHash(1, PHASE),
            price: price,
            nonce: keccak256("all-call current Safe authorization"),
            deadline: uint64(block.timestamp + 1 days),
            signerEpoch: sale.signerEpoch()
        });
    }

    function _call(address target, uint256 value, bytes memory data)
        private
        pure
        returns (bytes memory)
    {
        // Upstream MultiSend wire format: one-byte CALL, address, value, length, data.
        return abi.encodePacked(uint8(0), target, value, uint256(data.length), data);
    }

    function _buy(IStreamFixedPriceSaleAdapter.SaleAuthorization memory a)
        private
        returns (bytes memory)
    {
        return _call(address(sale), a.price, _buyData(a));
    }

    function _buyData(IStreamFixedPriceSaleAdapter.SaleAuthorization memory a)
        private
        returns (bytes memory)
    {
        bytes32 digest = sale.authorizationDigest(a);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(PLATFORM_KEY, digest);
        return abi.encodeCall(
            sale.buy, (a, TOKEN_DATA, abi.encodePacked(r, s, v), _artistProof(digest))
        );
    }

    function _request() private view returns (bytes memory) {
        return _call(address(entropy), 0, abi.encodeCall(entropy.requestEntropy, (uint256(1))));
    }

    function _transfer() private view returns (bytes memory) {
        return _call(
            address(core),
            0,
            abi.encodeCall(core.transferFrom, (address(buyerSafe), SECOND_OWNER, uint256(1)))
        );
    }

    function executeBuyerBatch(bytes calldata transactions) external returns (bool) {
        require(msg.sender == address(this), "test invocation only");
        // The official wrapper executes in Safe context; every enclosed operation is CALL.
        return executeSafe(
            buyerSafe,
            keys,
            multiSend,
            0,
            abi.encodeCall(CurrentCallOnlyMultiSend.multiSend, (transactions)),
            1
        );
    }

    function _assertRollback(IStreamFixedPriceSaleAdapter.SaleAuthorization memory a) private view {
        require(buyerSafe.nonce() == 0, "outer Safe nonce rolled back");
        require(address(buyerSafe).balance == 20 ether, "payer value rolled back");
        require(
            core.totalSupply() == 0 && core.lastAllocatedTokenId() == 0,
            "Core allocation rolled back"
        );
        require(core.collectionMintedEver(1) == 0, "lifetime collection count rolled back");
        require(manager.nextOperationNonce() == 0, "Manager operation nonce rolled back");
        require(_ledgerSupply() == 0, "Ledger supply consumption rolled back");
        require(
            !ledger.isManagerAuthorizationUsed(
                address(manager), sale.authorizationId(artist, a.nonce)
            ),
            "Ledger authorization rolled back"
        );
        require(!sale.authorizationUsed(artist, a.nonce), "Artist sale authorization rolled back");
        require(sale.totalNativeProceeds() == 0 && wallet.balance == 0, "split payment rolled back");
        require(revenueEscrow.totalOwed(address(0)) == 0, "no residual escrow liability");
        require(
            entropy.tokenEntropyStatus(1) == StreamEntropyStatus.NONE,
            "entropy registration rolled back"
        );
        require(provider.nextRequestId() == 1, "upstream request allocation rolled back");
        require(entropy.pendingRequestCount() == 0, "coordinator pending count rolled back");
        require(
            entropy.providerRequestKeys(address(provider), 1) == 0,
            "coordinator request key rolled back"
        );
        (bytes32 key,,,,) = provider.results(1);
        require(key == bytes32(0), "upstream request record rolled back");
    }

    function _assertPurchased(IStreamFixedPriceSaleAdapter.SaleAuthorization memory a)
        private
        view
    {
        _assertPurchasedAt(a, SECOND_OWNER);
    }

    function _assertPurchasedAt(
        IStreamFixedPriceSaleAdapter.SaleAuthorization memory a,
        address recipient
    ) private view {
        require(buyerSafe.nonce() == 1, "one outer Safe transaction");
        require(
            address(buyerSafe).balance == 20 ether - a.price, "payer charged exact signed amount"
        );
        require(core.totalSupply() == 1 && core.collectionMintedEver(1) == 1, "one permanent mint");
        require(core.ownerOf(1) == recipient, "later CALL transferred actual custody");
        require(
            manager.nextOperationNonce() == 1 && sale.authorizationUsed(artist, a.nonce),
            "one authorization consumed"
        );
        require(_ledgerSupply() == 1, "Ledger supply consumed once");
        require(
            ledger.isManagerAuthorizationUsed(
                address(manager), sale.authorizationId(artist, a.nonce)
            ),
            "Ledger binds actual sale authorization"
        );
        require(
            wallet.balance == a.price && sale.totalNativeProceeds() == a.price,
            "all proceeds accounted"
        );
        require(provider.nextRequestId() == 2, "one actual upstream request");
        (bytes32 key,,,,) = provider.results(1);
        require(
            entropy.pendingRequestCount() == 1 && key != 0
                && entropy.providerRequestKeys(address(provider), 1) == key,
            "coordinator and provider retain one identical pending request"
        );
        require(
            entropy.tokenEntropyStatus(1) == StreamEntropyStatus.REQUESTED,
            "request survives transfer"
        );
    }

    function _ledgerSupply() private view returns (uint64) {
        bytes32 counter = keccak256("supply");
        bytes32 subject = manager.previewSubjectKey(
            IStreamMintManager.CounterKeyMode.CONSTANT,
            1,
            PHASE,
            counter,
            address(0),
            address(0),
            address(0),
            address(0),
            bytes32(0)
        );
        return ledger.counterValue(manager.previewCounterValueKey(1, PHASE, counter, subject));
    }

    function testAllCallPurchaseRequestTransferFinalizeAndArtistWithdrawal() public {
        IStreamFixedPriceSaleAdapter.SaleAuthorization memory a = _authorization(0.01 ether);
        require(
            this.executeBuyerBatch(bytes.concat(_buy(a), _request(), _transfer())),
            "complete all-call purchase"
        );
        _assertPurchased(a);
        provider.fulfill(1, keccak256("all-call entropy"));
        (, bool finalized) = entropy.tokenSeed(1);
        require(
            finalized && bytes(core.tokenURI(1)).length != 0, "current metadata after fulfillment"
        );
        require(entropy.pendingRequestCount() == 0, "fulfillment consumes pending count once");
        bytes memory claim = _call(
            wallet,
            0,
            abi.encodeCall(IStreamSplitWallet.release, (address(0), artist, payable(artist)))
        );
        require(
            executeSafe(
                artistSafe,
                keys,
                multiSend,
                0,
                abi.encodeCall(CurrentCallOnlyMultiSend.multiSend, (claim)),
                1
            ),
            "all-call Artist payout"
        );
        require(
            artist.balance == 0.009 ether && wallet.balance == 0.001 ether,
            "original beneficiary split"
        );
    }

    function testFuzzAllCallFailureRestoresEveryPriorComponentAndExactRetry(
        uint8 position,
        uint96 amount
    ) public {
        uint256 price = uint256(amount) % (10 ether + 1);
        IStreamFixedPriceSaleAdapter.SaleAuthorization memory a = _authorization(price);
        CurrentBatchPostcondition condition = new CurrentBatchPostcondition();
        bytes memory reject = _call(address(condition), 0, abi.encodeCall(condition.check, ()));
        bytes memory buy = _buy(a);
        bytes memory batch;
        if (position % 3 == 0) batch = bytes.concat(buy, reject, _request(), _transfer());
        else if (position % 3 == 1) batch = bytes.concat(buy, _request(), reject, _transfer());
        else batch = bytes.concat(buy, _request(), _transfer(), reject);
        vm.expectRevert(abi.encodeWithSignature("Error(string)", "GS013"));
        this.executeBuyerBatch(batch);
        _assertRollback(a);
        condition.accept();
        require(
            this.executeBuyerBatch(batch), "byte-identical batch retries after downstream repair"
        );
        _assertPurchased(a);
    }

    function testRepeatedAuthorizationInOneBatchRollsBackFirstPurchase() public {
        IStreamFixedPriceSaleAdapter.SaleAuthorization memory a = _authorization(0.01 ether);
        bytes memory buy = _buy(a);
        vm.expectRevert(abi.encodeWithSignature("Error(string)", "GS013"));
        this.executeBuyerBatch(bytes.concat(buy, _request(), buy));
        _assertRollback(a);
        require(
            this.executeBuyerBatch(bytes.concat(buy, _request(), _transfer())),
            "original authorization remains usable"
        );
        _assertPurchased(a);
    }

    function testCallOnlyWrapperRejectsInnerDelegatecallAfterPurchase() public {
        IStreamFixedPriceSaleAdapter.SaleAuthorization memory a = _authorization(0.01 ether);
        CurrentBatchPostcondition condition = new CurrentBatchPostcondition();
        bytes memory data = abi.encodeCall(condition.succeed, ());
        // The target succeeds under either EVM operation. Only wrapper policy rejects this entry.
        bytes memory prohibited =
            abi.encodePacked(uint8(1), address(condition), uint256(0), uint256(data.length), data);
        bytes memory buy = _buy(a);
        bytes memory batch = bytes.concat(buy, prohibited);
        vm.expectRevert(abi.encodeWithSignature("Error(string)", "GS013"));
        this.executeBuyerBatch(batch);
        _assertRollback(a);
        require(
            this.executeBuyerBatch(
                bytes.concat(buy, _call(address(condition), 0, data), _request(), _transfer())
            ),
            "same target and calldata succeed with CALL"
        );
        _assertPurchased(a);
    }

    function _signedBatch(OfficialSafe account, bytes memory transactions)
        private
        returns (bytes memory)
    {
        bytes memory data = abi.encodeCall(CurrentCallOnlyMultiSend.multiSend, (transactions));
        bytes32 digest = account.getTransactionHash(
            multiSend, 0, data, 1, 0, 0, 0, address(0), address(0), account.nonce()
        );
        return abi.encodeCall(
            account.execTransaction,
            (
                multiSend,
                0,
                data,
                uint8(1),
                0,
                0,
                0,
                address(0),
                payable(address(0)),
                safeThresholdSignature(keys, digest)
            )
        );
    }

    function testSafeOwnerAndIdenticallyOwnedSafeCannotImpersonateBuyer() public {
        IStreamFixedPriceSaleAdapter.SaleAuthorization memory a = _authorization(0.01 ether);
        bytes memory data = _buyData(a);
        address owner = vm.addr(keys[0]);
        vm.deal(owner, a.price);
        vm.prank(owner);
        (bool ok, bytes memory reason) = address(sale).call{ value: a.price }(data);
        require(
            !ok
                && keccak256(reason)
                    == keccak256(abi.encodeWithSignature("InvalidSaleAuthorization()")),
            "owner EOA is not the signed Safe payer"
        );
        require(owner.balance == a.price, "rejected owner keeps value");
        _assertRollback(a);

        // Both Safes have the same keys and threshold. Their protocol identities still differ.
        vm.deal(address(artistSafe), a.price);
        (ok, reason) = address(artistSafe).call(_signedBatch(artistSafe, _buy(a)));
        require(
            !ok && keccak256(reason) == keccak256(abi.encodeWithSignature("Error(string)", "GS013"))
                && artistSafe.nonce() == 0 && address(artistSafe).balance == a.price,
            "another valid Safe cannot substitute its own caller identity"
        );
        _assertRollback(a);
        require(
            this.executeBuyerBatch(bytes.concat(_buy(a), _request(), _transfer())),
            "exact signed authorization remains available to its actual Safe payer"
        );
        _assertPurchased(a);
    }

    function testFuzzAllCallArtistRedirectRollbackAndExactSignedRetry(uint96 amount) public {
        uint256 price = uint256(amount) % (10 ether) + 2;
        IStreamFixedPriceSaleAdapter.SaleAuthorization memory a = _authorization(price);
        require(
            this.executeBuyerBatch(bytes.concat(_buy(a), _request(), _transfer())),
            "paid mint creates actual split entitlement"
        );
        _assertPurchased(a);
        IStreamSplitWallet split = IStreamSplitWallet(wallet);
        uint256 entitlement = price * 900_000 / 1_000_000;
        uint256 recipientBefore = SECOND_OWNER.balance;
        bytes memory release = abi.encodeCall(
            split.release, (address(0), address(artistSafe), payable(SECOND_OWNER))
        );
        address owner = vm.addr(keys[0]);
        vm.prank(owner);
        (bool ok, bytes memory reason) = wallet.call(release);
        require(
            !ok
                && keccak256(reason)
                    == keccak256(
                        abi.encodeWithSelector(
                            IStreamSplitWallet.UnauthorizedReleaseRecipient.selector,
                            owner,
                            address(artistSafe),
                            SECOND_OWNER
                        )
                    ),
            "owner EOA cannot redirect its Safe's entitlement"
        );
        (ok, reason) = address(buyerSafe).call(_signedBatch(buyerSafe, _call(wallet, 0, release)));
        require(
            !ok && keccak256(reason) == keccak256(abi.encodeWithSignature("Error(string)", "GS013"))
                && buyerSafe.nonce() == 1,
            "identically owned buyer Safe cannot redirect Artist entitlement"
        );
        CurrentBatchPostcondition condition = new CurrentBatchPostcondition();
        bytes memory batch = bytes.concat(
            _call(wallet, 0, release),
            _call(address(condition), 0, abi.encodeCall(condition.check, ()))
        );
        bytes memory savedCall = _signedBatch(artistSafe, batch);
        (ok, reason) = address(artistSafe).call(savedCall);
        require(
            !ok && keccak256(reason) == keccak256(abi.encodeWithSignature("Error(string)", "GS013"))
                && artistSafe.nonce() == 0 && wallet.balance == price
                && SECOND_OWNER.balance == recipientBefore
                && split.accountReleased(address(0), artist) == 0
                && split.totalReleased(address(0)) == 0
                && split.releasable(address(0), artist) == entitlement,
            "later CALL rolls back payout, released accounting and Artist Safe nonce"
        );
        condition.accept();
        (ok, reason) = address(artistSafe).call(savedCall);
        require(ok && abi.decode(reason, (bool)), "identical signed Artist batch retries");
        require(
            artistSafe.nonce() == 1 && buyerSafe.nonce() == 1
                && SECOND_OWNER.balance == recipientBefore + entitlement
                && wallet.balance == price - entitlement
                && split.accountReleased(address(0), artist) == entitlement
                && split.totalReleased(address(0)) == entitlement
                && split.releasable(address(0), artist) == 0
                && split.observedReceived(address(0)) == price && core.ownerOf(1) == SECOND_OWNER
                && core.collectionMintedEver(1) == 1 && sale.totalNativeProceeds() == price
                && revenueEscrow.totalOwed(address(0)) == 0,
            "one exact entitlement transfer conserves paid mint proceeds and NFT custody"
        );
        (ok,) = address(artistSafe).call(savedCall);
        require(
            !ok && artistSafe.nonce() == 1 && wallet.balance == price - entitlement
                && SECOND_OWNER.balance == recipientBefore + entitlement,
            "consumed Safe envelope cannot replay the release"
        );
    }

    function testAllCallMissingSafeReceiverHandlerRollsBackAndExactSignedRetry() public {
        SafeComponents memory components = safeComponents;
        address handler = components.handler;
        components.handler = address(0);
        OfficialSafe recipient = createOfficialSafe(components, safeOwnerAddresses(keys), 2, 303);
        IStreamFixedPriceSaleAdapter.SaleAuthorization memory a = _authorization(0.01 ether);
        bytes memory batch = bytes.concat(
            _buy(a),
            _request(),
            _call(address(core), 0, abi.encodeCall(core.approve, (SECOND_OWNER, uint256(1)))),
            _call(
                address(core),
                0,
                abi.encodeWithSignature(
                    "safeTransferFrom(address,address,uint256)",
                    address(buyerSafe),
                    address(recipient),
                    uint256(1)
                )
            )
        );
        bytes memory savedCall = _signedBatch(buyerSafe, batch);
        (bool ok, bytes memory result) = address(buyerSafe).call(savedCall);
        require(
            !ok
                && keccak256(result)
                    == keccak256(abi.encodeWithSignature("Error(string)", "GS013")),
            "missing receiver handler rejects late custody delivery"
        );
        _assertRollback(a);
        require(
            recipient.nonce() == 0 && core.balanceOf(address(recipient)) == 0, "recipient unchanged"
        );
        require(
            executeSafe(
                recipient,
                keys,
                address(recipient),
                0,
                abi.encodeWithSignature("setFallbackHandler(address)", handler),
                0
            ),
            "recipient configures its actual official compatibility handler"
        );
        (ok, result) = address(buyerSafe).call(savedCall);
        require(ok && abi.decode(result, (bool)), "identical signed buyer batch retries");
        _assertPurchasedAt(a, address(recipient));
        require(
            recipient.nonce() == 1 && core.balanceOf(address(recipient)) == 1
                && core.getApproved(1) == address(0),
            "real Safe receives NFT and transfer clears approval"
        );
    }
}
