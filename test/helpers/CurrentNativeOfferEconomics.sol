// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./CurrentArtistNativeOfferFixture.sol";

interface NativeOfferEconomicsVm {
    function mockCallRevert(
        address target,
        uint256 value,
        bytes calldata data,
        bytes calldata reason
    ) external;
    function clearMockedCalls() external;
    function expectCall(address target, uint256 value, bytes calldata data) external;
}

interface INativeOfferEconomicDriver {
    function economicAction(uint256 seed) external;
}

contract NativeOfferEconomicHandler {
    INativeOfferEconomicDriver private immutable driver;

    constructor(INativeOfferEconomicDriver driver_) {
        driver = driver_;
    }

    function step(uint256 seed) external {
        driver.economicAction(seed);
    }
}

/// @dev External refund destination chosen by the buyer, with an explicit repairable fault.
contract NativeOfferRefundRecipient {
    address private immutable controller = msg.sender;
    bool private accepts;

    function repair() external {
        require(msg.sender == controller, "refund fault controller");
        accepts = true;
    }

    receive() external payable {
        require(accepts, "refund recipient rejected");
    }
}

/// @notice Independent native offer accounting through contract9, revenue escrow and all splits.
/// @dev Original Safe/Artist/Core products. External entropy and injected wallet deposit failure
/// are explicit boundaries; no ERC20, held payment implementation or cold-gas claim.
abstract contract CurrentNativeOfferEconomics is CurrentArtistNativeOfferFixture {
    uint256 public constant ECONOMIC_OPENING = 14;
    uint256 public constant ECONOMIC_BOUND = 64;

    struct EconomicModel {
        bool consented;
        bool recorderEnabled;
        bool paid;
        bool flushed;
        bool refunded;
        bool artistReleased;
        bool collaboratorReleased;
        bool protocolReleased;
        bool revealed;
        uint256 excess;
        uint256[5] nonces;
    }
    EconomicModel internal model;
    NativeOfferEconomicHandler internal economicHandler;
    NativeOfferRefundRecipient internal refundRecipient;
    ArtistNativeOfferPlan internal offerPlan;
    NativeOffer.Acceptance internal acceptance;
    ArtistNativeOfferReceipt internal originalReceipt;
    bytes internal exactPurchase;
    bytes internal exactFlush;
    bytes32 internal attemptedRoot;
    bytes32 internal attemptedOperation;
    bytes32 internal officialKey;
    bytes32 internal committedReceipt;
    uint256[5] internal initialBalances;
    uint256 internal protocolBalance;
    uint256 internal producerRevision;
    uint256 internal producerChanges;
    uint256 public economicSteps;
    uint256 public latePurchaseFailures;
    uint256 public flushFailures;
    uint256 public refundFailures;
    uint256 public authorityDenials;
    uint256 public purchaseReplays;
    bytes32 public economicDigest;

    function _constructNativeOfferEconomics() internal {
        _deployArtistNativeOffers();
        (offerPlan, acceptance) = _openArtistNativeOffer(true, false);
        refundRecipient = new NativeOfferRefundRecipient();
        model.recorderEnabled = true;
        for (uint256 i; i < 5; ++i) {
            OfficialSafe safe = _economicSafe(i);
            require(safe.getThreshold() == 2, "original threshold-two economic principals");
            for (uint256 j; j < i; ++j) {
                require(
                    address(safe) != address(_economicSafe(j)), "separate Safe authority domains"
                );
            }
            model.nonces[i] = safe.nonce();
            initialBalances[i] = address(safe).balance;
        }
        protocolBalance = PROTOCOL.balance;
        (bool enabled,, uint64 revision) = revenueEscrow.creditProducer(address(joinedRecorder));
        require(
            enabled && provider.fee() == 0,
            "original recorder admission and zero-quote external service"
        );
        producerRevision = revision;
        require(
            IStreamSplitWallet(wallet).aggregateSharePpm(address(joinedArtist)) == 700000
                && IStreamSplitWallet(wallet).aggregateSharePpm(address(joinedCollaborator))
                    == 200000 && IStreamSplitWallet(wallet).aggregateSharePpm(PROTOCOL) == 100000,
            "original immutable seventy twenty ten split"
        );
        economicHandler = new NativeOfferEconomicHandler(INativeOfferEconomicDriver(address(this)));
        assertEconomicState();
    }

    function _economicSafe(uint256 index) private view returns (OfficialSafe) {
        if (index == 0) return joinedArtist;
        if (index == 1) return joinedCollaborator;
        if (index == 2) return joinedCollector;
        if (index == 3) return joinedBuyer;
        require(index == 4, "five economic principals");
        return governorSafe;
    }

    function economicAction(uint256 seed) external {
        require(msg.sender == address(economicHandler), "selected economic handler only");
        if (economicSteps == ECONOMIC_BOUND) {
            assertEconomicState();
            return;
        }
        uint256 action = economicSteps < ECONOMIC_OPENING ? economicSteps : 14 + seed % 5;
        if (action == 0) {
            model.excess = 1 + seed % 1000;
            exactPurchase = _nativeOfferSafePayload(acceptance, 1100 + model.excess);
            _nativeOfferFailed(exactPurchase);
            ++authorityDenials;
        } else if (action == 1) {
            _nativeOfferConsent(offerPlan);
            model.consented = true;
            ++model.nonces[0];
        } else if (action == 2) {
            _denyWrongSellerDomain();
            this.artistNativeOfferRecorderAdmission(false);
            ++model.nonces[4];
            ++producerChanges;
            model.recorderEnabled = false;
            _depositFault();
            NativeOfferEconomicsVm(address(vm)).expectCall(wallet, 1000, bytes(""));
            NativeOfferEconomicsVm(address(vm))
                .expectCall(
                    address(revenueEscrow),
                    1000,
                    abi.encodeCall(
                        revenueEscrow.creditNative, (PRIMARY_REVENUE_CLASS, profile, wallet, false)
                    )
                );
            vm.recordLogs();
            _nativeOfferFailed(exactPurchase);
            _failedPreparation(vm.getRecordedLogs());
            ++latePurchaseFailures;
        } else if (action == 3) {
            this.artistNativeOfferRecorderAdmission(true);
            ++model.nonces[4];
            ++producerChanges;
            model.recorderEnabled = true;
            require(
                block.timestamp < offerPlan.config.sale.endsAt,
                "exact original authority remains unexpired through repair"
            );
            _depositFault();
            vm.recordLogs();
            _nativeOfferSucceeded(exactPurchase);
            ArtistNativeOfferReceipt memory r =
                _nativeOfferReceipt(offerPlan, acceptance, vm.getRecordedLogs(), true);
            require(
                r.execution.operationRoot == attemptedRoot
                    && r.execution.operationId == attemptedOperation
                    && r.execution.settlementKey == officialKey,
                "identical Safe retry retains all original operation and settlement identities"
            );
            model.paid = true;
            ++model.nonces[3];
            originalReceipt = r;
            committedReceipt = _retainedReceipt();
        } else if (action == 4) {
            exactFlush = _economicEnvelope(joinedBuyer, address(revenueEscrow), _flushData());
            _depositFault();
            NativeOfferEconomicsVm(address(vm)).expectCall(wallet, 1000, bytes(""));
            _economicFailure(joinedBuyer, exactFlush);
            ++flushFailures;
        } else if (action == 5) {
            NativeOfferEconomicsVm(address(vm)).clearMockedCalls();
            vm.recordLogs();
            _economicSuccess(joinedBuyer, exactFlush);
            _oneEvent(
                vm.getRecordedLogs(),
                address(revenueEscrow),
                keccak256("EscrowFlushed(bytes32,bytes32,address,uint16,address,uint256,uint256)"),
                PRIMARY_REVENUE_CLASS,
                profile,
                bytes32(uint256(uint160(wallet))),
                abi.encode(uint16(1), address(0), uint256(1000), uint256(0))
            );
            model.flushed = true;
            ++model.nonces[3];
        } else if (action == 6 || action == 15) {
            _denyCreditAuthority();
        } else if (action == 7) {
            _refundExactRetry();
        } else if (action == 8) {
            _releaseShare(0);
        } else if (action == 9) {
            _releaseShare(seed & 1 == 0 ? 1 : 2);
        } else if (action == 10) {
            _releaseShare(model.collaboratorReleased ? 2 : 1);
        } else if (action == 11) {
            uint256 request = provider.nextRequestId();
            _joinedSafe(
                joinedBuyer,
                address(entropy),
                0,
                abi.encodeCall(entropy.requestEntropy, (uint256(1)))
            );
            ++model.nonces[3];
            require(provider.nextRequestId() == request + 1, "one actual coordinator request");
            require(
                provider.fulfill(request, keccak256("native economics entropy")) == 0,
                "original coordinator accepts external entropy"
            );
            model.revealed = true;
        } else if (action == 12 || action == 14) {
            _nativeOfferFailed(_nativeOfferSafePayload(acceptance, 1100 + model.excess));
            ++purchaseReplays;
        } else if (action == 13 || action == 16) {
            _denyRecorderAuthority();
        } else if (action == 17) {
            _economicFailure(
                joinedBuyer,
                _economicEnvelope(
                    joinedBuyer,
                    address(artistNativeOffers),
                    abi.encodeCall(
                        artistNativeOffers.claimRefund, (offerPlan.id, address(refundRecipient))
                    )
                )
            );
        } else {
            _economicFailure(
                joinedArtist,
                _economicEnvelope(
                    joinedArtist,
                    wallet,
                    abi.encodeCall(
                        IStreamSplitWallet.release,
                        (address(0), address(joinedArtist), payable(address(joinedArtist)))
                    )
                )
            );
        }
        ++economicSteps;
        economicDigest = keccak256(abi.encode(economicDigest, seed, action, model));
        assertEconomicState();
    }

    function _depositFault() private {
        NativeOfferEconomicsVm(address(vm))
            .mockCallRevert(
                wallet,
                1000,
                bytes(""),
                abi.encodeWithSignature("Error(string)", "explicit economic wallet deposit fault")
            );
    }

    function _economicEnvelope(OfficialSafe safe, address target, bytes memory data)
        private
        returns (bytes memory)
    {
        return _economicValueEnvelope(safe, target, 0, data);
    }

    function _economicValueEnvelope(
        OfficialSafe safe,
        address target,
        uint256 value,
        bytes memory data
    ) private returns (bytes memory) {
        bytes32 digest = safe.getTransactionHash(
            target, value, data, 0, 0, 0, 0, address(0), address(0), safe.nonce()
        );
        return abi.encodeCall(
            safe.execTransaction,
            (
                target,
                value,
                data,
                uint8(0),
                0,
                0,
                0,
                address(0),
                payable(address(0)),
                safeThresholdSignature(joinedKeys, digest)
            )
        );
    }

    function _economicFailure(OfficialSafe safe, bytes memory payload) private {
        (bool ok, bytes memory out) = address(safe).call(payload);
        require(
            !ok && keccak256(out) == keccak256(abi.encodeWithSignature("Error(string)", "GS013")),
            "original Safe target failure"
        );
        assertEconomicState();
    }

    function _economicSuccess(OfficialSafe safe, bytes memory payload) private {
        (bool ok, bytes memory out) = address(safe).call(payload);
        require(ok && abi.decode(out, (bool)), "original Safe target success");
    }

    function _flushData() private view returns (bytes memory) {
        return abi.encodeCall(
            revenueEscrow.flushEscrow, (PRIMARY_REVENUE_CLASS, profile, wallet, address(0))
        );
    }

    function _denyWrongSellerDomain() private {
        NativeOffer.Acceptance memory wrong = acceptance;
        wrong.sellerProof.signature =
            _joinedProof(joinedBuyer, _nativeOfferSellerDigest(wrong.authorization));
        _nativeOfferFailed(_nativeOfferSafePayload(wrong, 1100 + model.excess));
        ++authorityDenials;
    }

    function _denyCreditAuthority() private {
        bytes memory refund =
            abi.encodeCall(artistNativeOffers.claimRefund, (offerPlan.id, address(joinedBuyer)));
        _economicFailure(
            joinedCollector, _economicEnvelope(joinedCollector, address(artistNativeOffers), refund)
        );
        _economicFailure(
            joinedCollaborator,
            _economicEnvelope(joinedCollaborator, address(artistNativeOffers), refund)
        );
        _economicFailure(
            joinedBuyer,
            _economicEnvelope(
                joinedBuyer,
                address(artistNativeOffers),
                abi.encodeCall(
                    artistNativeOffers.claimRefund, (offerPlan.id, address(artistNativeOffers))
                )
            )
        );
        _economicFailure(
            joinedCollector,
            _economicEnvelope(
                joinedCollector,
                wallet,
                abi.encodeCall(
                    IStreamSplitWallet.release,
                    (address(0), address(joinedArtist), payable(address(joinedCollector)))
                )
            )
        );
        authorityDenials += 4;
    }

    function _denyRecorderAuthority() private {
        // Sale ownership and economic signatures confer neither recorder nor escrow authority.
        _economicFailure(
            joinedCollaborator,
            _economicEnvelope(
                joinedCollaborator,
                address(revenueEscrow),
                abi.encodeCall(revenueEscrow.setCreditProducer, (address(joinedCollaborator), true))
            )
        );
        _economicFailure(
            joinedBuyer,
            _economicValueEnvelope(
                joinedBuyer,
                address(revenueEscrow),
                1000,
                abi.encodeCall(
                    revenueEscrow.creditNative, (PRIMARY_REVENUE_CLASS, profile, wallet, false)
                )
            )
        );
        _economicFailure(
            joinedBuyer,
            _economicValueEnvelope(
                joinedBuyer,
                address(joinedRecorder),
                1000,
                abi.encodeCall(
                    IStreamPreparedNativeOfferSettlement.settlePreparedNativeOffer,
                    (originalReceipt.facts, originalReceipt.intent)
                )
            )
        );
        authorityDenials += 3;
    }

    function _refundExactRetry() private {
        bytes memory exact = _economicEnvelope(
            joinedBuyer,
            address(artistNativeOffers),
            abi.encodeCall(artistNativeOffers.claimRefund, (offerPlan.id, address(refundRecipient)))
        );
        NativeOfferEconomicsVm(address(vm))
            .expectCall(address(refundRecipient), model.excess, bytes(""));
        _economicFailure(joinedBuyer, exact);
        ++refundFailures;
        refundRecipient.repair();
        vm.recordLogs();
        _economicSuccess(joinedBuyer, exact);
        _oneEvent(
            vm.getRecordedLogs(),
            address(artistNativeOffers),
            keccak256("CuratedCreditClaimed(bytes32,address,address,uint256)"),
            offerPlan.id,
            bytes32(uint256(uint160(address(joinedBuyer)))),
            bytes32(uint256(uint160(address(refundRecipient)))),
            abi.encode(model.excess)
        );
        model.refunded = true;
        ++model.nonces[3];
    }

    function _releaseShare(uint256 which) private {
        address account = which == 0
            ? address(joinedArtist)
            : which == 1 ? address(joinedCollaborator) : PROTOCOL;
        uint256 amount = which == 0 ? 700 : which == 1 ? 200 : 100;
        OfficialSafe caller =
            which == 0 ? joinedArtist : which == 1 ? joinedCollaborator : joinedBuyer;
        uint256 total = (model.artistReleased ? 700 : 0) + (model.collaboratorReleased ? 200 : 0)
            + (model.protocolReleased ? 100 : 0) + amount;
        vm.recordLogs();
        _joinedSafe(
            caller,
            wallet,
            0,
            abi.encodeCall(IStreamSplitWallet.release, (address(0), account, payable(account)))
        );
        _oneEvent(
            vm.getRecordedLogs(),
            wallet,
            keccak256("NativeReleased(bytes32,address,address,uint256,uint256,uint256)"),
            profile,
            bytes32(uint256(uint160(account))),
            bytes32(uint256(uint160(account))),
            abi.encode(amount, total, uint256(1000))
        );
        if (which == 0) {
            model.artistReleased = true;
            ++model.nonces[0];
        } else if (which == 1) {
            model.collaboratorReleased = true;
            ++model.nonces[1];
        } else {
            model.protocolReleased = true;
            ++model.nonces[3];
        }
    }

    function _oneEvent(
        Vm.Log[] memory logs,
        address emitter,
        bytes32 topic,
        bytes32 a,
        bytes32 b,
        bytes32 c,
        bytes memory data
    ) private pure {
        uint256 count;
        for (uint256 i; i < logs.length; ++i) {
            if (
                logs[i].emitter != emitter || logs[i].topics.length != 4
                    || logs[i].topics[0] != topic
            ) continue;
            require(
                logs[i].topics[1] == a && logs[i].topics[2] == b && logs[i].topics[3] == c
                    && keccak256(logs[i].data) == keccak256(data),
                "exact native economic receipt"
            );
            ++count;
        }
        require(count == 1, "one native economic receipt");
    }

    function _failedPreparation(Vm.Log[] memory logs) private {
        uint256 authorizations;
        uint256 preparations;
        for (uint256 i; i < logs.length; ++i) {
            if (logs[i].topics.length != 4) continue;
            if (
                logs[i].emitter == address(ledger)
                    && logs[i].topics[0]
                        == keccak256(
                            "MintLedgerAuthorizationConsumed(uint16,bytes32,bytes32,address,bytes32)"
                        )
            ) {
                require(
                    logs[i].topics[1] == _nativeOfferId(offerPlan.config.offerDigest)
                        && logs[i].topics[3] == bytes32(uint256(uint160(address(manager))))
                        && keccak256(logs[i].data)
                            == keccak256(
                                abi.encode(uint16(1), offerPlan.config.sale.mintPolicyHash)
                            ),
                    "failed original Ledger authorization trace"
                );
                attemptedRoot = logs[i].topics[2];
                ++authorizations;
            } else if (
                logs[i].emitter == address(manager)
                    && logs[i].topics[0]
                        == keccak256(
                            "PreparedMintStarted(uint16,bytes32,uint256,uint256,bytes32,uint256,address,bytes32,bytes32)"
                        )
            ) {
                require(
                    authorizations == 1 && uint256(logs[i].topics[2]) == 1
                        && uint256(logs[i].topics[3]) == 1
                        && keccak256(logs[i].data)
                            == keccak256(
                                abi.encode(
                                    uint16(1),
                                    attemptedRoot,
                                    uint256(1),
                                    address(joinedBuyer),
                                    keccak256(acceptance.selection.tokenData),
                                    acceptance.selection.mintCommitment
                                )
                            ),
                    "actual failed prepared identity trace"
                );
                attemptedOperation = logs[i].topics[1];
                ++preparations;
            }
        }
        require(
            authorizations == 1 && preparations == 1 && attemptedRoot != 0
                && attemptedOperation != 0,
            "late failure reached original preparation"
        );
        NativeOfferPrepared.Intent memory intent = _nativeOfferIntent(offerPlan, acceptance);
        NativeOfferPrepared.Facts memory facts;
        facts.saleAdapter = address(artistNativeOffers);
        facts.intentHash = keccak256(
            abi.encode(
                keccak256("6529STREAM_PREPARED_NATIVE_OFFER_INTENT_V1"),
                block.chainid,
                address(artistNativeOffers),
                address(joinedRecorder),
                intent
            )
        );
        facts.currentPolicyHash = offerPlan.config.sale.mintPolicyHash;
        facts.boundPolicyHash = offerPlan.config.sale.mintPolicyHash;
        facts.operationRoot = attemptedRoot;
        facts.operationId = attemptedOperation;
        officialKey = StreamPrimarySettlementHash.settlementKey(
            address(joinedRecorder),
            address(artistNativeOffers),
            StreamPreparedNativeSettlementHash.executionId(facts, intent)
        );
        // The LOGs above are reverted execution observations, not transaction receipts.
    }

    function _retainedReceipt() private view returns (bytes32) {
        bytes32 purchase = artistNativeOffers.purchaseIdFor(offerPlan.id, address(joinedBuyer), 1);
        return keccak256(
            abi.encode(
                artistNativeOffers.executionRecord(purchase),
                joinedRecorder.settlementResult(officialKey),
                joinedRecorder.preparedNativeFactsHash(officialKey),
                joinedRecorder.preparedNativeContentHash(officialKey)
            )
        );
    }

    function assertEconomicState() public view {
        uint256 paid = model.paid ? 1000 : 0;
        uint256 credit = model.paid && !model.refunded ? model.excess : 0;
        uint256 escrow = model.paid && !model.flushed ? 1000 : 0;
        uint256 released = (model.artistReleased ? 700 : 0) + (model.collaboratorReleased ? 200 : 0)
            + (model.protocolReleased ? 100 : 0);
        uint256 fee = model.paid ? 100 : 0;
        require(
            artistNativeOffers.refundableBalance(offerPlan.id, address(joinedBuyer)) == credit
                && artistNativeOffers.refundableBalance(offerPlan.id, address(joinedCollector)) == 0
                && artistNativeOffers.refundableBalance(offerPlan.id, address(joinedCollaborator))
                    == 0 && artistNativeOffers.refundLiability() == credit
                && artistNativeOffers.totalBuyerLiabilities() == credit
                && address(artistNativeOffers).balance == credit,
            "independent buyer-only refundable liability"
        );
        require(
            revenueEscrow.totalOwed(address(0)) == escrow
                && revenueEscrow.escrowOwed(PRIMARY_REVENUE_CLASS, profile, wallet, address(0))
                    == escrow && address(revenueEscrow).balance == escrow
                && revenueEscrow.surplus(address(0)) == 0,
            "independent revenue escrow conservation"
        );
        require(
            wallet.balance == (model.flushed ? 1000 : 0) - released
                && IStreamSplitWallet(wallet).totalReleased(address(0)) == released
                && IStreamSplitWallet(wallet).observedReceived(address(0))
                    == (model.flushed ? 1000 : 0)
                && IStreamSplitWallet(wallet).roundingDust(address(0)) == 0,
            "independent split conservation"
        );
        _assertShare(address(joinedArtist), 700, model.artistReleased);
        _assertShare(address(joinedCollaborator), 200, model.collaboratorReleased);
        _assertShare(PROTOCOL, 100, model.protocolReleased);
        require(
            entropy.revealFeeEscrow(1) == fee && entropy.totalRevealFeeEscrows() == fee
                && address(entropy).balance == fee && entropy.totalFeeCredits() == 0
                && address(provider).balance == 0,
            "original reveal reserve retained under zero provider quote"
        );
        require(
            address(joinedBuyer).balance
                    == initialBalances[3] - (model.paid ? 1100 + model.excess : 0)
                && address(refundRecipient).balance == (model.refunded ? model.excess : 0),
            "independent payer debit and authorized refund destination"
        );
        require(
            address(joinedArtist).balance == initialBalances[0] + (model.artistReleased ? 700 : 0)
                && address(joinedCollaborator).balance
                    == initialBalances[1] + (model.collaboratorReleased ? 200 : 0)
                && PROTOCOL.balance == protocolBalance + (model.protocolReleased ? 100 : 0)
                && address(joinedCollector).balance == initialBalances[2]
                && address(governorSafe).balance == initialBalances[4],
            "separate beneficiary seller owner governor balances"
        );
        require(
            initialBalances[3] - address(joinedBuyer).balance
                == address(artistNativeOffers).balance + address(revenueEscrow).balance
                    + wallet.balance + released + address(entropy).balance
                    + address(provider).balance + address(refundRecipient).balance,
            "independent whole-flow native conservation"
        );
        for (uint256 i; i < 5; ++i) {
            require(
                _economicSafe(i).nonce() == model.nonces[i],
                "independent Safe transaction and signature nonces"
            );
        }
        (bool enabled, bytes32 hash, uint64 revision) =
            revenueEscrow.creditProducer(address(joinedRecorder));
        require(
            enabled == model.recorderEnabled && hash == address(joinedRecorder).codehash
                && revision == producerRevision + producerChanges,
            "only original governance changes recorder credit authority"
        );
        (bool accepted,) = artists.isSaleConsented(
            1, offerPlan.id, artistNativeOffers.saleRecord(offerPlan.id).configHash
        );
        require(
            accepted == model.consented
                && artistNativeOffers.owner() == address(joinedCollaborator),
            "independent Artist consent and separate sale owner"
        );
        require(
            joinedRecorder.totalOfficialSettled(address(0)) == paid
                && joinedRecorder.officialSettled(
                        PRIMARY_REVENUE_CLASS, profile, wallet, address(0)
                    ) == paid && address(joinedRecorder).balance == 0,
            "contract9 records exact price once without retaining funds"
        );
        _assertMintAndReplay();
    }

    function _assertShare(address account, uint256 amount, bool released) private view {
        IStreamSplitWallet split = IStreamSplitWallet(wallet);
        require(
            split.accountReleased(address(0), account) == (released ? amount : 0)
                && split.releasable(address(0), account)
                    == (model.flushed && !released ? amount : 0),
            "independent immutable beneficiary entitlement"
        );
    }

    function _assertMintAndReplay() private view {
        bytes32 buyerId = _nativeOfferId(offerPlan.config.offerDigest);
        bytes32 seller = _nativeOfferSellerDigest(acceptance.authorization);
        bytes32 purchase = artistNativeOffers.purchaseIdFor(offerPlan.id, address(joinedBuyer), 1);
        require(
            artistNativeOffers.digestConsumed(seller) == model.paid
                && !artistNativeOffers.digestRevoked(seller)
                && !artistNativeOffers.digestConsumed(offerPlan.config.offerDigest)
                && ledger.isManagerAuthorizationUsed(address(manager), buyerId) == model.paid
                && !ledger.isManagerAuthorizationUsed(address(manager), _nativeOfferId(seller))
                && ledger.counterValue(_nativeOfferCounter(offerPlan)) == (model.paid ? 1 : 0),
            "independent seller and canonical buyer replay domains"
        );
        require(
            core.totalSupply() == (model.paid ? 1 : 0)
                && core.collectionMintedEver(1) == (model.paid ? 1 : 0)
                && core.lastAllocatedTokenId() == (model.paid ? 1 : 0)
                && core.collectionNextSerial(1) == (model.paid ? 2 : 1)
                && manager.nextOperationNonce() == (model.paid ? 1 : 0)
                && core.pendingPreparedMintTokenId() == 0 && !core.preparedMint(1).exists
                && !core.preparedMint(2).exists && core.tokenData(2).length == 0
                && core.coordinatorAtMint(2) == address(0),
            "independent one-token allocation and no outstanding preparation"
        );
        (bool exists, uint256 collection, uint256 serial, bool burned) =
            core.tokenCollectionIdentity(1);
        require(
            exists == model.paid && collection == (model.paid ? 1 : 0)
                && serial == (model.paid ? 1 : 0) && !burned,
            "exact completed token identity"
        );
        if (model.paid) {
            require(
                core.ownerOf(1) == address(joinedBuyer)
                    && keccak256(core.tokenData(1)) == keccak256(acceptance.selection.tokenData)
                    && core.coordinatorAtMint(1) == address(entropy)
                    && _retainedReceipt() == committedReceipt,
                "original NFT and all immutable official receipt fields retained"
            );
        } else {
            require(
                core.tokenData(1).length == 0 && core.coordinatorAtMint(1) == address(0),
                "failed preparation leaves no data or entropy anchor"
            );
        }
        require(
            artistNativeOffers.saleRecord(offerPlan.id).status == (model.paid ? 4 : 1)
                && artistNativeOffers.nextPurchaseNonce(offerPlan.id, address(joinedBuyer))
                    == (model.paid ? 2 : 1)
                && IStreamPreparedNativeOfferMint(address(manager)).preparedNativeOfferAdmission()
                == 0
                && IStreamPreparedNativeOfferMint(address(manager))
                .activePreparedNativeOfferContent()
                .operationRoot == 0 && manager.activePreparedNativeMint().operationRoot == 0,
            "original sale lifecycle and temporary context cleared"
        );
        if (attemptedRoot != 0) {
            require(
                ledger.isManagerOperationRootUsed(address(manager), attemptedRoot) == model.paid
                    && manager.isOperationRootUsed(attemptedRoot) == model.paid
                    && joinedRecorder.settlementConsumed(officialKey) == model.paid
                    && IStreamPreparedNativeOfferSettlement(address(joinedRecorder))
                        .preparedNativeOfferConsumed(address(artistNativeOffers), purchase)
                    == model.paid,
                "exact failed or committed operation and recorder replay identities"
            );
        }
        if (!model.paid && officialKey != 0) {
            require(
                joinedRecorder.preparedNativeFactsHash(officialKey) == 0
                    && joinedRecorder.preparedNativeContentHash(officialKey) == 0
                    && joinedRecorder.settlementResult(officialKey).candidateCommitment == 0
                    && artistNativeOffers.executionRecord(purchase).operationRoot == 0,
                "no surviving failed official settlement receipt"
            );
        }
        require(
            !joinedRecorder.preparedNativeSaleConsumed(
                joinedRecorder.preparedNativeSaleKey(
                    address(artistNativeOffers), offerPlan.id, offerPlan.nonce
                )
            ),
            "offer does not consume unrelated ordinary sale replay lane"
        );
        (, bool revealed) = entropy.tokenSeed(1);
        require(
            revealed == model.revealed && provider.nextRequestId() == (model.revealed ? 2 : 1),
            "one externally fulfilled original coordinator request"
        );
    }

    function assertEconomicActivity() public view {
        require(
            economicSteps >= ECONOMIC_OPENING && latePurchaseFailures == 1 && flushFailures == 1
                && refundFailures == 1 && authorityDenials >= 9 && purchaseReplays != 0
                && model.paid && model.flushed && model.refunded && model.artistReleased
                && model.collaboratorReleased && model.protocolReleased && model.revealed,
            "complete native economic action family is nonvacuous"
        );
    }
}
