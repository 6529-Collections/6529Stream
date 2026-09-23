// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./StreamMintFallbackIncidentFixture.sol";

interface ICurrentRecoveryActionDriver {
    function executeRecoveryAction(uint256 seed) external;
}

contract CurrentRecoveryActionHandler {
    ICurrentRecoveryActionDriver private immutable driver;

    constructor(ICurrentRecoveryActionDriver driver_) {
        driver = driver_;
    }

    function step(uint256 seed) external {
        driver.executeRecoveryAction(seed);
    }
}

/// @notice Bounded action model for original Core abort, two real imports and old auction exits.
/// @dev The intentionally stranding Manager, entitlement gate, entropy service and fault receiver
/// are explicit seams inherited from the incident fixture. This is not a launch-gate campaign.
abstract contract CurrentRecoveryActions is StreamMintFallbackIncidentFixture {
    uint256 public constant RECOVERY_OPENING = 16;
    uint256 public constant RECOVERY_BOUND = 64;
    address internal constant OUTBID = address(0xB1D1);
    bytes32 internal constant AUCTION_NONCE = keccak256("recovery action auction");
    bytes32 internal constant FRESH_CLAIM = keccak256("recovery action fresh claim");
    bytes32 internal constant FRESH_NONCE = keccak256("recovery action fresh nonce");

    struct RecoveryModel {
        bool retired;
        bool imported;
        bool recovered;
        bool minted;
        bool settled;
        bool refunded;
        uint256 safeNonce;
        uint256 allocation;
    }

    RecoveryModel internal expected;
    CurrentRecoveryActionHandler internal recoveryHandler;
    IncidentBatch internal importBatch;
    IncidentBatch internal rejectedBatch;
    IncidentBatch internal recoveryBatch;
    CurrentContinuityReceiver internal faultReceiver;
    IStreamEnglishAuctionHouse.Auction internal auctionBefore;
    IStreamMintManager.MintBatch internal freshBatch;
    bytes internal freshGateData;
    bytes32 internal firstImportRoot;
    bytes32 internal freshRoot;
    bytes32[] internal deniedAuthorizations;
    bytes32[] internal deniedClaims;
    bytes32 internal originalContentHistory;
    bytes32 internal ledgerPointerHistory;
    uint256 public recoverySteps;
    uint256 public aborted;
    uint256 public manifestRollbacks;
    uint256 public incompleteImportDenials;
    uint256 public receiverRollbacks;
    uint256 public settlementRollbacks;
    uint256 public refundRollbacks;
    uint256 public writerDenials;
    uint256 public replayDenials;
    uint256 public capDenials;
    bytes32 public recoveryDigest;

    function _incidentTokenId() internal pure override returns (uint256) {
        return 4;
    }

    function _incidentCompletedCount() internal pure override returns (uint256) {
        return 3;
    }

    function _constructRecoveryActions() internal {
        firstImportRoot = _setupIncident();
        require(leaves.length == 4, "auction supply included in actual import");
        expected.safeNonce = continuitySafe.nonce();
        expected.allocation = 4;
        originalContentHistory = _completedContentHistory();
        ledgerPointerHistory =
            keccak256(abi.encode(StreamCurrentStackPlan.readPointer(core, LEDGER_POINTER)));
        recoveryHandler =
            new CurrentRecoveryActionHandler(ICurrentRecoveryActionDriver(address(this)));
        assertRecoveryState();
    }

    function _beforeIncidentCutover() internal override {
        faultReceiver = new CurrentContinuityReceiver();
        (bytes32 policy,,) = auction.primaryPolicy(1);
        IStreamEnglishAuctionHouse.AuctionAuthorization memory a =
            IStreamEnglishAuctionHouse.AuctionAuthorization({
                collectionId: 1,
                phaseId: AUCTION_PHASE,
                artist: artist,
                profileId: profile,
                expectedPrimaryPolicyHash: policy,
                tokenDataHash: keccak256(TOKEN_DATA),
                mintCommitment: keccak256("recovery action custody"),
                mintPolicyHash: manager.phasePolicyHash(1, AUCTION_PHASE),
                reservePrice: 0.01 ether,
                startTime: uint64(block.timestamp),
                endTime: uint64(block.timestamp + 1 days),
                extensionWindow: 0,
                minBidIncrementBps: 500,
                nonce: AUCTION_NONCE,
                deadline: uint64(block.timestamp + 1 days),
                signerEpoch: auction.signerEpoch()
            });
        bytes32 digest = auction.authorizationDigest(a);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(PLATFORM_KEY, digest);
        pendingAuctionToken =
            auction.createAuction(a, TOKEN_DATA, abi.encodePacked(r, s, v), _artistProof(digest));
        require(
            pendingAuctionToken == 3 && core.ownerOf(3) == address(auction),
            "original auction minted custody token3"
        );
        vm.deal(OUTBID, 1 ether);
        vm.prank(OUTBID);
        auction.bid{ value: 0.02 ether }(3, OUTBID);
        vm.deal(BUYER, 1 ether);
        vm.prank(BUYER);
        auction.bid{ value: 0.03 ether }(3, address(faultReceiver));
        auctionBefore = auction.auction(3);
        require(
            auctionBefore.operationRoot != 0
                && auctionBefore.authorizationId
                    == keccak256(
                        abi.encode(
                            keccak256("6529STREAM_ENGLISH_AUCTION_NONCE_V1"),
                            block.chainid,
                            address(auction),
                            artist,
                            AUCTION_NONCE
                        )
                    ),
            "original auction identity independently bound"
        );
    }

    /// @dev Foundry targets only this selector. Expected booleans are action intentions, never
    /// copied from protocol flags. All successful governance/mint writes use the actual Safe.
    function executeRecoveryAction(uint256 seed) external {
        require(msg.sender == address(recoveryHandler), "selected recovery handler only");
        _recoveryStep(seed);
    }

    function _recoveryStep(uint256 seed) private {
        if (recoverySteps == RECOVERY_BOUND) {
            assertRecoveryState();
            return;
        }
        uint256 action = recoverySteps < RECOVERY_OPENING ? recoverySteps : 16 + seed % 6;
        if (action == 0) {
            (IncidentBatch memory imports, IncidentBatch memory bad) = _scheduleIncident(true);
            importBatch = imports;
            rejectedBatch = bad;
            expected.retired = true;
            // revoke schedule+execute, immediate retire schedule+execute, import+recovery schedules.
            expected.safeNonce += 6;
        } else if (action == 1) {
            vm.warp(rejectedBatch.ready);
            _rejectIncidentBatchThroughSafe(rejectedBatch);
            ++incompleteImportDenials;
        } else if (action == 2) {
            _refundFailure();
        } else if (action == 3) {
            if (seed & 1 == 0) _refundSuccess();
            else _settlementFailure();
        } else if (action == 4) {
            _executeIncidentBatch(importBatch);
            expected.imported = true;
            ++expected.safeNonce;
        } else if (action == 5) {
            _lateManifestFailure();
            IncidentBatch memory fresh;
            (fresh.calls, fresh.data) = _activationPlan(4, INCIDENT_OPERATION);
            _assertRecoveryIntent(fresh.calls[1]);
            (fresh.action, fresh.ready) = _scheduleBatchAsGovernor(3, fresh.calls, fresh.data);
            recoveryBatch = fresh;
            ++expected.safeNonce;
        } else if (action == 6) {
            _settlementFailure();
        } else if (action == 7) {
            // Exercise settlement on either side of abort; it changes wallet balances, not supply.
            if (seed & 1 == 0) _settlementSuccess();
        } else if (action == 8) {
            vm.warp(recoveryBatch.ready);
            vm.recordLogs();
            _executeIncidentBatch(recoveryBatch);
            _assertRecoveryEvent(vm.getRecordedLogs(), recoveryBatch.action);
            expected.recovered = true;
            ++expected.safeNonce;
            ++aborted;
        } else if (action == 9) {
            _configureSuccessorWithFreshConsent();
            // Two budget changes, phase configuration and executor admission: two Safe tx each.
            expected.safeNonce += 8;
        } else if (action == 10 || action == 16) {
            _denyMint(CLAIM, keccak256(abi.encode("imported replay", recoverySteps)));
            ++replayDenials;
        } else if (action == 11) {
            _mintWithExactRetry();
        } else if (action == 12 || action == 17) {
            _denyWriterRestoration(originalArtistManager);
            _denyWriterRestoration(address(manager));
            _denyRepeatedRecovery();
        } else if (action == 13) {
            if (!expected.settled) _settlementSuccess();
            if (!expected.refunded) _refundSuccess();
        } else if (action == 14 || action == 18) {
            _denySavedAuthorization();
        } else if (action == 15 || action == 19) {
            bytes32 claim = keccak256(abi.encode("over imported cap", recoverySteps, seed));
            _denyMint(claim, keccak256(abi.encode("cap nonce", recoverySteps, seed)));
            ++capDenials;
        } else if (action == 20) {
            _settlementFailure();
        } else {
            _refundFailure();
        }
        ++recoverySteps;
        recoveryDigest = keccak256(abi.encode(recoveryDigest, seed, action, expected));
        assertRecoveryState();
    }

    function _lateManifestFailure() private {
        bytes32 before_ = _rollbackState();
        vm.expectRevert(
            abi.encodeWithSelector(
                StreamSystemManifest.GovernanceNewValueHashMismatch.selector,
                rejectedBatch.calls[2].newValueHash ^ bytes32(uint256(1)),
                rejectedBatch.calls[2].newValueHash
            )
        );
        executor.executeGovernanceBatch(
            rejectedBatch.action, rejectedBatch.calls, rejectedBatch.data
        );
        require(_rollbackState() == before_, "diagnostic late failure restores preparation");
        CurrentFallbackIncidentCallVm(address(vm))
            .expectCall(
                address(core),
                abi.encodeCall(core.abortPreparedMintFromManager, (4, INCIDENT_OPERATION))
            );
        _rejectIncidentBatchThroughSafe(rejectedBatch);
        ++manifestRollbacks;
    }

    function _mintWithExactRetry() private {
        preparedExecution = true;
        (IStreamMintManager.MintBatch memory batch, bytes memory data) =
            _mintRequest(successor, FRESH_CLAIM, FRESH_NONCE);
        // A separate receiver leaves the auction's delivery fault independent.
        CurrentContinuityReceiver recipient = new CurrentContinuityReceiver();
        batch.initialRecipients[0] = address(recipient);
        batch.authorizationId = gate.authorization(
            address(successor), address(continuitySafe), batch, FRESH_CLAIM, FRESH_NONCE
        );
        bytes memory saved = _signedSuccessorCall(batch, data);
        bytes32 before_ = _rollbackState();
        vm.recordLogs();
        (bool ok, bytes memory returned) = address(continuitySafe).call(saved);
        _requireSafeFailure(ok, returned);
        // Reverted LOGs are execution trace only. Their root must still be unused.
        bytes32 attemptedRoot = _committedRescueRoot(vm.getRecordedLogs(), batch.authorizationId);
        require(
            !ledger.isManagerOperationRootUsed(address(rescue), attemptedRoot),
            "failed operation root remains unused"
        );
        require(
            _rollbackState() == before_ && core.lastAllocatedTokenId() == 4
                && !core.preparedMint(5).exists
                && !ledger.isManagerAuthorizationUsed(address(rescue), batch.authorizationId)
                && !ledger.isManagerNullifierUsed(
                    address(rescue), gate.claimNullifier(FRESH_CLAIM)
                ),
            "whole failed mint rolls back gap successor and replay"
        );
        assertRecoveryState();
        ++receiverRollbacks;
        recipient.accept();
        vm.recordLogs();
        (ok,) = address(continuitySafe).call(saved);
        require(ok, "byte-identical original Safe retry");
        freshRoot = _committedRescueRoot(vm.getRecordedLogs(), batch.authorizationId);
        require(freshRoot == attemptedRoot, "exact retry commits original attempted root");
        freshBatch = batch;
        freshGateData = data;
        expected.minted = true;
        expected.allocation = 5;
        ++expected.safeNonce;
    }

    function _committedRescueRoot(Vm.Log[] memory logs, bytes32 authorization)
        private
        view
        returns (bytes32 root)
    {
        bytes32 topic = keccak256(
            "MintLedgerAuthorizationConsumed(uint16,bytes32,bytes32,address,bytes32)"
        );
        for (uint256 i; i < logs.length; ++i) {
            if (
                logs[i].emitter != address(ledger) || logs[i].topics.length != 4
                    || logs[i].topics[0] != topic
            ) continue;
            require(
                root == 0 && logs[i].topics[1] == authorization
                    && logs[i].topics[3] == bytes32(uint256(uint160(address(rescue)))),
                "one exact committed rescue authorization"
            );
            root = logs[i].topics[2];
        }
        require(root != 0, "successful receipt supplies rescue root");
    }

    function _denyMint(bytes32 claim, bytes32 nonce) private {
        (IStreamMintManager.MintBatch memory batch, bytes memory data) =
            _mintRequest(successor, claim, nonce);
        bytes32 before_ = _rollbackState();
        (bool ok, bytes memory returned) =
            address(continuitySafe).call(_signedSuccessorCall(batch, data));
        _requireSafeFailure(ok, returned);
        require(_rollbackState() == before_, "denied mint preserves protocol and Safe state");
        deniedAuthorizations.push(batch.authorizationId);
        if (claim != CLAIM) deniedClaims.push(gate.claimNullifier(claim));
    }

    function _denySavedAuthorization() private {
        bytes32 before_ = _rollbackState();
        // Fresh outer Safe nonce ensures the inner committed authorization is actually retried.
        (bool ok, bytes memory returned) =
            address(continuitySafe).call(_signedSuccessorCall(freshBatch, freshGateData));
        _requireSafeFailure(ok, returned);
        require(_rollbackState() == before_, "committed authorization cannot mint twice");
        ++replayDenials;
    }

    function _requireSafeFailure(bool ok, bytes memory returned) private pure {
        require(
            !ok
                && keccak256(returned)
                    == keccak256(abi.encodeWithSignature("Error(string)", "GS013")),
            "actual Safe target failure"
        );
    }

    function _denyWriterRestoration(address writer) private {
        bytes memory data = abi.encodeCall(ledger.setLedgerWriter, (writer, true));
        GovernanceActionRequest memory request = _governanceRequest(
            1,
            address(ledger),
            data,
            keccak256(abi.encode("retired writer action", writer)),
            0,
            keccak256(data)
        );
        bytes32 action = _scheduleAsGovernor(request);
        ++expected.safeNonce;
        vm.warp(request.notBefore);
        bytes32 before_ = _rollbackState();
        vm.expectRevert(
            abi.encodeWithSelector(IStreamMintLedger.InvalidLedgerWriter.selector, writer)
        );
        executor.executeGovernanceAction(action, data);
        vm.expectRevert();
        this.executeCurrentGovernorCall(
            address(executor), abi.encodeCall(executor.executeGovernanceAction, (action, data))
        );
        require(
            _rollbackState() == before_ && !ledger.ledgerWriter(writer)
                && executor.governanceAction(action).status == GovernanceActionStatus.SCHEDULED,
            "retired writer denied through actual owner authority"
        );
        ++writerDenials;
    }

    function _settlementFailure() private {
        bytes32 before_ = _economics();
        if (expected.settled) {
            vm.expectRevert(
                abi.encodeWithSelector(
                    IStreamEnglishAuctionHouse.AuctionAlreadySettled.selector, uint256(3)
                )
            );
        } else {
            CurrentFallbackIncidentCallVm(address(vm))
                .expectCall(
                    address(faultReceiver),
                    abi.encodeCall(
                        IERC721Receiver.onERC721Received,
                        (address(auction), address(auction), uint256(3), bytes(""))
                    )
                );
            vm.expectRevert(
                abi.encodeWithSignature("Error(string)", "continuity receiver rejected")
            );
        }
        auction.settle(3);
        require(_economics() == before_, "failed settlement restores all liabilities and balances");
        ++settlementRollbacks;
    }

    function _denyRepeatedRecovery() private {
        bytes32 before_ = _rollbackState();
        vm.expectRevert();
        this.executeCurrentGovernorCall(
            address(rescue), abi.encodeCall(rescue.recoverPreparedMint, (4, INCIDENT_OPERATION))
        );
        vm.expectRevert();
        this.executeCurrentGovernorCall(
            address(executor),
            abi.encodeCall(
                executor.executeGovernanceBatch,
                (recoveryBatch.action, recoveryBatch.calls, recoveryBatch.data)
            )
        );
        require(
            _rollbackState() == before_,
            "Safe cannot bypass recovery context or replay completed action"
        );
    }

    function _settlementSuccess() private {
        faultReceiver.accept();
        vm.recordLogs();
        auction.settle(3);
        _oneEconomicEvent(
            vm.getRecordedLogs(),
            keccak256("AuctionSettled(uint256,address,address,address,uint256)"),
            bytes32(uint256(3)),
            bytes32(uint256(uint160(BUYER))),
            bytes32(uint256(uint160(address(faultReceiver)))),
            abi.encode(wallet, uint256(0.03 ether))
        );
        expected.settled = true;
    }

    function _refundFailure() private {
        bytes32 before_ = _economics();
        vm.prank(OUTBID);
        if (expected.refunded) {
            vm.expectRevert(
                abi.encodeWithSelector(IStreamEnglishAuctionHouse.NoAuctionRefund.selector)
            );
        } else {
            vm.expectRevert(
                abi.encodeWithSelector(
                    IStreamEnglishAuctionHouse.AuctionNativeTransferFailed.selector,
                    address(faultReceiver)
                )
            );
        }
        // Receiver has no payable fallback, independently of its ERC-721 acceptance switch.
        auction.withdrawRefund(payable(address(faultReceiver)));
        require(_economics() == before_, "failed pull refund restores exact credit and balance");
        ++refundRollbacks;
    }

    function _refundSuccess() private {
        vm.recordLogs();
        vm.prank(OUTBID);
        auction.withdrawRefund(payable(OUTBID));
        Vm.Log[] memory logs = vm.getRecordedLogs();
        uint256 count;
        for (uint256 i; i < logs.length; ++i) {
            if (
                logs[i].emitter == address(auction) && logs[i].topics.length == 3
                    && logs[i].topics[0]
                        == keccak256("AuctionRefundWithdrawn(address,address,uint256)")
            ) {
                ++count;
                require(
                    logs[i].topics[1] == bytes32(uint256(uint160(OUTBID)))
                        && logs[i].topics[2] == logs[i].topics[1]
                        && keccak256(logs[i].data) == keccak256(abi.encode(uint256(0.02 ether))),
                    "exact original refund receipt"
                );
            }
        }
        require(count == 1, "one refund receipt");
        expected.refunded = true;
    }

    function _oneEconomicEvent(
        Vm.Log[] memory logs,
        bytes32 topic,
        bytes32 a,
        bytes32 b,
        bytes32 c,
        bytes memory data
    ) private view {
        uint256 count;
        for (uint256 i; i < logs.length; ++i) {
            if (
                logs[i].emitter == address(auction) && logs[i].topics.length == 4
                    && logs[i].topics[0] == topic
            ) {
                ++count;
                require(
                    logs[i].topics[1] == a && logs[i].topics[2] == b && logs[i].topics[3] == c
                        && keccak256(logs[i].data) == keccak256(data),
                    "exact original settlement receipt"
                );
            }
        }
        require(count == 1, "one settlement receipt");
    }

    function _economics() private view returns (bytes32) {
        return keccak256(
            abi.encode(
                auction.auction(3),
                auction.refundCredit(OUTBID),
                auction.totalBidEscrow(),
                auction.totalRefundOwed(),
                auction.totalNativeProceeds(),
                auction.nativeProceeds(profile),
                auction.totalOwed(),
                address(auction).balance,
                wallet.balance,
                OUTBID.balance,
                BUYER.balance,
                core.ownerOf(3),
                revenueEscrow.totalOwed(address(0))
            )
        );
    }

    function _completedContentHistory() private view returns (bytes32) {
        return keccak256(
            abi.encode(
                core.tokenData(1),
                core.tokenData(2),
                core.tokenData(3),
                core.coordinatorAtMint(1),
                core.coordinatorAtMint(2),
                core.coordinatorAtMint(3)
            )
        );
    }

    function assertRecoveryState() public view {
        require(
            core.lastAllocatedTokenId() == expected.allocation
                && core.collectionNextSerial(1) == expected.allocation + 1
                && core.collectionMintedEver(1) == (expected.minted ? 4 : 3)
                && core.totalSupply() == (expected.minted ? 3 : 2),
            "independent consumed allocation and serial model"
        );
        require(
            _completedContentHistory() == originalContentHistory && core.ownerOf(1) == BUYER,
            "completed content survives recovery"
        );
        _identity(1, true, 1, false);
        _identity(2, true, 2, true);
        _identity(3, true, 3, false);
        _identity(4, !expected.recovered, expected.recovered ? 0 : 4, false);
        _identity(5, expected.minted, expected.minted ? 5 : 0, false);
        _identity(6, false, 0, false);
        StreamPreparedMintRecord memory p = core.preparedMint(4);
        require(
            core.pendingPreparedMintTokenId() == (expected.recovered ? 0 : 4)
                && p.exists == !expected.recovered
                && p.operationId == (expected.recovered ? bytes32(0) : INCIDENT_OPERATION)
                && p.collectionId == (expected.recovered ? 0 : 1),
            "exact preparation lifecycle"
        );
        require(
            keccak256(core.tokenData(4))
                    == keccak256(
                        expected.recovered ? bytes("") : bytes("original incident preparation")
                    ) && core.coordinatorAtMint(4) == address(0),
            "prepared-only identity has no completed entropy anchor"
        );
        require(
            !core.preparedMint(5).exists && !core.preparedMint(6).exists
                && core.tokenData(6).length == 0 && core.coordinatorAtMint(6) == address(0),
            "no future preparation or allocation"
        );
        if (expected.minted) {
            require(
                core.ownerOf(5) == freshBatch.initialRecipients[0]
                    && keccak256(core.tokenData(5)) == keccak256(TOKEN_DATA)
                    && core.coordinatorAtMint(5) == address(entropy),
                "successor owns next original Core token"
            );
        } else {
            require(
                core.tokenData(5).length == 0 && core.coordinatorAtMint(5) == address(0),
                "failed mint leaves next token clean"
            );
        }
        require(continuitySafe.nonce() == expected.safeNonce, "independent Safe transaction count");
        _assertAuthorityAndReplay();
        _assertEconomicModel();
    }

    function _identity(uint256 token, bool wantExists, uint256 wantSerial, bool wantBurned)
        private
        view
    {
        (bool exists, uint256 collection, uint256 serial, bool burned) =
            core.tokenCollectionIdentity(token);
        require(
            exists == wantExists && collection == (wantExists ? 1 : 0) && serial == wantSerial
                && burned == wantBurned,
            "independent completed burned or gap identity"
        );
    }

    function _assertAuthorityAndReplay() private view {
        require(
            keccak256(abi.encode(StreamCurrentStackPlan.readPointer(core, LEDGER_POINTER)))
                    == ledgerPointerHistory
                && StreamCurrentStackPlan.readPointer(core, MANAGER_POINTER).target
                == (expected.recovered ? address(rescue) : address(manager)),
            "canonical Ledger and selected successor authority"
        );
        require(
            !ledger.ledgerWriter(originalArtistManager)
                && ledger.ledgerWriterRetiredAt(originalArtistManager) != 0
                && ledger.ledgerWriter(address(manager)) == !expected.retired
                && (ledger.ledgerWriterRetiredAt(address(manager)) != 0) == expected.retired
                && ledger.ledgerWriter(address(rescue))
                && ledger.ledgerWriterRetiredAt(address(rescue)) == 0,
            "permanent retired writer and live rescue authority"
        );
        require(
            artists.mintManager() == originalArtistManager
                && StreamMintManager(originalArtistManager).nextOperationNonce() == 3
                && manager.nextOperationNonce() == 0
                && rescue.nextOperationNonce() == (expected.minted ? 1 : 0),
            "original Artist anchor and independent mint nonces"
        );
        require(
            ledger.mintImportCommitment(firstImportRoot).complete
                && ledger.isCompletedMintDescendant(
                    address(ledger), originalArtistManager, address(manager)
                ) == !expected.retired,
            "historical import persists while live descendant authority ends at retirement"
        );
        _assertImportInventories();
        if (expected.retired) {
            require(
                ledger.mintImportCommitment(tree[0]).complete == expected.imported,
                "second import completion model"
            );
        }
        require(
            ledger.isCompletedMintDescendant(
                    address(ledger), originalArtistManager, address(rescue)
                ) == expected.imported,
            "successor lineage needs complete import"
        );
        bytes32[3] memory auths = [
            sale.authorizationId(artist, keccak256("paid baseline")),
            originalAuthorization,
            auctionBefore.authorizationId
        ];
        bytes32[3] memory roots = [paidOperation, originalOperation, auctionBefore.operationRoot];
        for (uint256 i; i < 3; ++i) {
            require(
                ledger.isManagerAuthorizationUsed(originalArtistManager, auths[i])
                    && ledger.isManagerOperationRootUsed(originalArtistManager, roots[i])
                    && !ledger.isManagerAuthorizationUsed(address(manager), auths[i])
                    && !ledger.isManagerAuthorizationUsed(address(rescue), auths[i])
                    && !ledger.isManagerOperationRootUsed(address(manager), roots[i])
                    && !ledger.isManagerOperationRootUsed(address(rescue), roots[i]),
                "canonical predecessor replay facts stay in original namespaces"
            );
        }
        bytes32 lifetime = gate.claimNullifier(CLAIM);
        require(
            ledger.isManagerNullifierUsed(originalArtistManager, lifetime)
                && ledger.isManagerNullifierUsed(address(manager), lifetime)
                && ledger.isManagerNullifierUsed(address(rescue), lifetime) == expected.imported,
            "complete lifetime replay import"
        );
        for (uint256 i; i < leaves.length; ++i) {
            uint64 want = expected.imported ? (expected.minted && (i == 1 || i == 2) ? 2 : 1) : 0;
            require(
                _value(ledger, StreamMintManager(originalArtistManager), leaves[i]) == 1
                    && _value(ledger, manager, leaves[i]) == 1
                    && _value(ledger, rescue, leaves[i]) == want,
                "independent complete counter inventory including auction"
            );
        }
        if (expected.imported) {
            require(
                ledger.managerDefinitionCount(address(rescue))
                    == ledger.managerDefinitionCount(originalArtistManager),
                "all original counter definitions retained"
            );
            for (uint256 i; i < ledger.managerDefinitionCount(originalArtistManager); ++i) {
                (bytes32 a, bool b, IStreamMintCounterPolicy.Definition memory d) =
                    ledger.managerDefinitionAt(originalArtistManager, i);
                (bytes32 x, bool y, IStreamMintCounterPolicy.Definition memory z) =
                    ledger.managerDefinitionAt(address(rescue), i);
                require(
                    a == x && b == y && keccak256(abi.encode(d)) == keccak256(abi.encode(z)),
                    "exact original definition interpretation"
                );
            }
        }
        require(
            ledger.isManagerNullifierUsed(address(rescue), gate.claimNullifier(FRESH_CLAIM))
                == expected.minted,
            "fresh rescue nullifier history"
        );
        if (expected.minted) {
            require(
                ledger.isManagerAuthorizationUsed(address(rescue), freshBatch.authorizationId)
                    && ledger.isManagerOperationRootUsed(address(rescue), freshRoot),
                "committed rescue authorization and operation remain consumed"
            );
        }
        for (uint256 i; i < deniedAuthorizations.length; ++i) {
            require(
                !ledger.isManagerAuthorizationUsed(address(rescue), deniedAuthorizations[i]),
                "denied authorization stays unused"
            );
        }
        for (uint256 i; i < deniedClaims.length; ++i) {
            require(
                !ledger.isManagerNullifierUsed(address(rescue), deniedClaims[i]),
                "over-cap claim stays unused"
            );
        }
        if (expected.recovered) {
            StreamSystemManifest.AggregateState memory aggregate =
                StreamGenesisManifestPlan.readAggregate(manifest);
            require(
                aggregate.modules.mintManager == address(rescue)
                    && aggregate.modules.mintLedger == address(ledger)
                    && executor.governanceAction(recoveryBatch.action).status
                        == GovernanceActionStatus.EXECUTED
                    && executor.governanceAction(rejectedBatch.action).status
                        == GovernanceActionStatus.SCHEDULED,
                "only valid recovery publishes successor"
            );
        }
    }

    function _assertImportInventories() private view {
        IStreamMintLedgerImport.ImportCommitment memory first =
            ledger.mintImportCommitment(firstImportRoot);
        require(
            first.predecessorLedger == address(ledger)
                && first.predecessorManager == originalArtistManager
                && first.successorManager == address(manager)
                && first.manifestHash == SNAPSHOT_MANIFEST && first.importedCounters == 4
                && first.importedNullifiers == 1 && first.complete,
            "complete first canonical import facts"
        );
        require(
            ledger.mintAncestorCount(originalArtistManager) == 0
                && ledger.mintAncestorCount(address(manager)) == 1
                && ledger.mintAncestorCount(address(rescue)) == (expected.imported ? 2 : 0),
            "exact retained ancestor inventory counts"
        );
        (address l, address m) = ledger.mintAncestorAt(address(manager), 0);
        require(
            l == address(ledger) && m == originalArtistManager, "first canonical ancestor identity"
        );
        if (expected.imported) {
            IStreamMintLedgerImport.ImportCommitment memory second =
                ledger.mintImportCommitment(tree[0]);
            require(
                tree[0] != firstImportRoot && second.predecessorLedger == address(ledger)
                    && second.predecessorManager == address(manager)
                    && second.successorManager == address(rescue)
                    && second.snapshotBlock == snapshotBlock
                    && second.manifestHash == SNAPSHOT_MANIFEST && second.importedCounters == 4
                    && second.importedNullifiers == 1 && second.complete,
                "complete second canonical import facts"
            );
            (l, m) = ledger.mintAncestorAt(address(rescue), 0);
            require(
                l == address(ledger) && m == address(manager), "second immediate ancestor identity"
            );
            (l, m) = ledger.mintAncestorAt(address(rescue), 1);
            require(
                l == address(ledger) && m == originalArtistManager,
                "second original ancestor identity"
            );
            (uint256 copied, uint256 required) = ledger.mintImportAncestryProgress(tree[0]);
            require(copied == 1 && required == 1, "complete frozen predecessor ancestry copied");
            (copied, required) = ledger.mintImportDefinitionProgress(tree[0]);
            require(
                copied == required
                    && required == ledger.managerDefinitionCount(originalArtistManager),
                "complete frozen definition inventory copied"
            );
        }
    }

    function _assertEconomicModel() private view {
        IStreamEnglishAuctionHouse.Auction memory want = auctionBefore;
        want.settled = expected.settled;
        uint256 bid = expected.settled ? 0 : 0.03 ether;
        uint256 refund = expected.refunded ? 0 : 0.02 ether;
        uint256 proceeds = expected.settled ? 0.03 ether : 0;
        require(
            keccak256(abi.encode(auction.auction(3))) == keccak256(abi.encode(want))
                && core.ownerOf(3)
                    == (expected.settled ? address(faultReceiver) : address(auction)),
            "exact original custody and settlement record"
        );
        require(
            auction.totalBidEscrow() == bid && auction.totalRefundOwed() == refund
                && auction.refundCredit(OUTBID) == refund && auction.totalOwed() == bid + refund
                && address(auction).balance == bid + refund && auction.surplus() == 0,
            "independent auction conservation and pull credit"
        );
        require(
            auction.nativeProceeds(profile) == proceeds && auction.totalNativeProceeds() == proceeds
                && wallet.balance == 0.01 ether + proceeds
                && OUTBID.balance == 0.98 ether + (expected.refunded ? 0.02 ether : 0)
                && BUYER.balance == 0.97 ether && revenueEscrow.totalOwed(address(0)) == 0,
            "settlement refund and baseline balances exact"
        );
        require(
            sale.authorizationUsed(artist, keccak256("paid baseline"))
                && sale.nativeProceeds(profile) == 0.01 ether
                && auction.authorizationUsed(artist, AUCTION_NONCE),
            "original commercial settlement replay and paid facts retained"
        );
    }

    function assertRecoveryActivity() public view {
        require(
            recoverySteps >= RECOVERY_OPENING && aborted == 1 && manifestRollbacks == 1
                && incompleteImportDenials == 1 && receiverRollbacks == 1
                && settlementRollbacks != 0 && refundRollbacks != 0 && writerDenials >= 2
                && replayDenials >= 2 && capDenials != 0 && expected.minted && expected.settled
                && expected.refunded,
            "required recovery actions are nonvacuous"
        );
    }
}
