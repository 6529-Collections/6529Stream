// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./StreamCurrentNativeClaimSales.t.sol";

/// @dev User receiver only. All observed products retain actual current code. A self-call
/// after every callback assertion lets expectCall witness those assertions even on rollback.
contract CurrentFreeClaimCallbackReceiver {
    struct Expected {
        bytes32 saleId;
        bytes32 executionId;
        bytes32 authorizationId;
        bytes32 saleDigest;
        bytes32 operationRoot;
        bytes32 operationId;
        bytes32 tokenDataHash;
        address coordinator;
        uint256 tokenId;
        uint256 revealFee;
    }

    StreamCore private immutable core;
    StreamMintManager private immutable manager;
    StreamNativeClaimSales private immutable claims;
    StreamPrimarySaleSettlement private immutable recorder;
    StreamConservationFloor private immutable floor;
    address private immutable controller;
    Expected private expected;
    bool public rejecting = true;
    uint256 public deliveries;
    uint256 public receivedToken;
    bool public activeMintObserved;

    error FreeDeliveryRejected();

    constructor(
        StreamCore c,
        StreamMintManager m,
        StreamNativeClaimSales s,
        StreamPrimarySaleSettlement r,
        StreamConservationFloor f
    ) {
        core = c;
        manager = m;
        claims = s;
        recorder = r;
        floor = f;
        controller = msg.sender;
    }

    function configure(Expected calldata value) external {
        require(msg.sender == controller, "receiver controller");
        expected = value;
    }

    function acceptDelivery() external {
        require(msg.sender == controller, "receiver controller");
        rejecting = false;
    }

    function callbackVerified(bytes32 observation) external view {
        require(
            msg.sender == address(this) && observation == keccak256(abi.encode(expected)),
            "only self confirms the exact checked callback"
        );
    }

    function onERC721Received(address operator, address from, uint256 token, bytes calldata data)
        external
        returns (bytes4)
    {
        Expected memory e = expected;
        require(
            msg.sender == address(core) && operator == address(manager) && from == address(0)
                && token == e.tokenId && data.length == 0,
            "exact actual Core safe-mint callback arguments"
        );
        (bool exists, uint256 collection, uint256 serial, bool burned) =
            core.tokenCollectionIdentity(token);
        require(
            exists && collection == 1 && serial == 1 && !burned
                && core.ownerOf(token) == address(this) && core.balanceOf(address(this)) == 1
                && core.tokenLifecycle(token) == 2 && core.collectionMintedEver(1) == 1
                && core.pendingPreparedMintTokenId() == 0 && !core.preparedMint(token).exists
                && core.coordinatorAtMint(token) == e.coordinator
                && keccak256(core.tokenData(token)) == e.tokenDataHash,
            "complete original token exists during its first mint callback"
        );
        Immediate.Receipt memory r = claims.executionReceipt(e.executionId);
        require(
            claims.executionStatus(e.executionId) == 1 && r.saleId == e.saleId
                && r.executionId == e.executionId && r.authorizationId == e.authorizationId
                && r.saleAuthorizationDigest == e.saleDigest && r.operationRoot == e.operationRoot
                && r.operationId == e.operationId && r.tokenId == 0 && r.settlementKey == 0
                && r.chargedAmount == 0 && r.revealFee == e.revealFee && r.revealCredit == 0
                && manager.isAuthorizationUsed(e.authorizationId)
                && manager.isOperationRootUsed(e.operationRoot),
            "signed free claim remains in progress after original Ledger consumption"
        );
        bytes32 key = recorder.settlementKey(address(claims), e.executionId);
        require(
            claims.activePublicNativeCandidate(e.executionId) == 0
                && !recorder.settlementConsumed(key)
                && recorder.settlementResult(key).candidateCommitment == 0
                && recorder.totalOfficialSettled(address(0)) == 0
                && floor.firstSale(1).receiptHash == 0
                && floor.settlementReceipt(key).receiptHash == 0
                && floor.directPrimarySaleFloorReceipt(key).receiptHash == 0
                && core.declaredConservationTier(1) == 0,
            "free callback has no paid witness, official settlement or permanent Floor effects"
        );

        // This receiver already owns the token. The precise failure proves the active Core
        // mint guard, rather than a failure due to missing ownership or approval.
        (bool burnedNow, bytes memory reason) =
            address(core).call(abi.encodeCall(core.burn, (token)));
        require(
            !burnedNow
                && keccak256(reason)
                    == keccak256(
                        abi.encodeWithSelector(StreamCore.MintExecutionInProgress.selector)
                    ) && core.ownerOf(token) == address(this),
            "actual active mint rejects owner burn with the exact guard"
        );
        activeMintObserved = true;
        this.callbackVerified(keccak256(abi.encode(e)));
        ++deliveries;
        receivedToken = token;
        if (rejecting) revert FreeDeliveryRejected();
        return this.onERC721Received.selector;
    }
}

/// @notice Actual threshold Artist/payer/Governor Safes and the original current Claim graph.
/// @dev Select the single new named test explicitly: the eight inherited tests are unchanged
/// existing cases, not eight additional acceptance cases. No EVM or cold-gas result is implied.
contract StreamCurrentFreeClaimCallbackTest is StreamCurrentNativeClaimSalesTest {
    function testActualSignedZeroCallbackRollsBackAndRetriesIdenticalSafeEnvelope() public {
        bytes32 id = _register(1, 12, 1, CLAIM_PHASE);
        CurrentFreeClaimCallbackReceiver receiver =
            new CurrentFreeClaimCallbackReceiver(core, manager, claims, recorder, commerceFloor);
        Claim.Purchase memory p = _purchase(id, 81, 0);
        p.mint.initialRecipient = address(receiver);
        Sales.SaleAuthorization memory a = _authorization(p, 181, 0);
        IStreamPrivateSaleAdapter.Signature memory proof = _saleProof(a);
        bytes32 digest = _literalDigest(a);
        bytes32 auth = _authorizationId(digest);
        require(
            claims.authorizationDigest(a) == digest && proof.kind == 2
                && p.mint.payer == p.mint.executor && p.chosenUnitPrice == 0,
            "original Sales-v1 signed ZERO authority and threshold Safe payer"
        );
        Native.NativeSettlementCandidate memory c = claims.previewSignedPurchase(p, a, proof);
        require(c.sale.amount == 0 && core.collectionMintedEver(1) == 0, "fresh free purchase");

        CurrentFreeClaimCallbackReceiver.Expected memory expected =
            CurrentFreeClaimCallbackReceiver.Expected(
                id,
                c.executionBinding.executionId,
                auth,
                digest,
                c.operationIdentityCommitment,
                c.operationId,
                keccak256(p.mint.tokenData),
                address(entropy),
                core.lastAllocatedTokenId() + 1,
                REVEAL_FEE
            );
        receiver.configure(expected);
        CurrentClaimCallVm(address(vm))
            .expectCall(
                address(receiver),
                0,
                abi.encodeCall(
                    receiver.onERC721Received,
                    (address(manager), address(0), expected.tokenId, bytes(""))
                ),
                2
            );
        // Safe masks target revert data as GS013. This second counted call is reached only
        // after all callback facts and the exact owner-burn guard have been checked.
        CurrentClaimCallVm(address(vm))
            .expectCall(
                address(receiver),
                0,
                abi.encodeCall(receiver.callbackVerified, (keccak256(abi.encode(expected)))),
                2
            );
        bytes memory saved =
            _signedSafeCall(REVEAL_FEE, abi.encodeCall(claims.purchaseSigned, (p, a, proof)));
        bytes32 savedHash = keccak256(saved);
        uint256 payerBefore = p.mint.payer.balance;
        uint256 safeNonce = OfficialSafe(payable(p.mint.payer)).nonce();
        uint256 operationNonce = manager.nextOperationNonce();
        bytes32 key = recorder.settlementKey(address(claims), expected.executionId);

        _assertSafeTargetFailure(_expectSavedFailure(saved, p, c, auth));
        require(
            receiver.deliveries() == 0 && receiver.receivedToken() == 0
                && !receiver.activeMintObserved() && core.balanceOf(address(receiver)) == 0
                && core.tokenLifecycle(expected.tokenId) == 0
                && core.pendingPreparedMintTokenId() == 0
                && claims.executionStatus(expected.executionId) == 0
                && !manager.isAuthorizationUsed(auth)
                && !manager.isOperationRootUsed(expected.operationRoot)
                && OfficialSafe(payable(p.mint.payer)).nonce() == safeNonce,
            "late callback rejection restores token, receiver, Safe and original replay state"
        );
        _assertNoCommerceFloorReceipt(key);

        // Only the recipient's rejection switch changes. The seller proof, payer Safe
        // signatures, nonce, value and every byte of its execTransaction call are reused.
        receiver.acceptDelivery();
        vm.recordLogs();
        _executeSaved(saved);
        Immediate.Receipt memory r = claims.executionReceipt(expected.executionId);
        _assertReceipt(p, c, r, auth, digest, 0);
        _assertFreeEvents(vm.getRecordedLogs(), r);
        _assertMoney(payerBefore, 0, 1, 0);
        require(
            keccak256(saved) == savedHash && receiver.deliveries() == 1
                && receiver.receivedToken() == expected.tokenId && r.tokenId == expected.tokenId
                && receiver.activeMintObserved() && core.balanceOf(address(receiver)) == 1
                && manager.nextOperationNonce() == operationNonce + 1 && _counter(p) == 1
                && claims.saleRecord(id).sale.soldQuantity == 1 && claims.saleRecord(id).sale.closed
                && OfficialSafe(payable(p.mint.payer)).nonce() == safeNonce + 1,
            "identical signed Safe envelope mints once and closes the exact free cap"
        );
        _expectSavedFailure(saved, p, c, auth);
    }
}
