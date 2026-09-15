// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "../helpers/NativeCustodyRightsBatchFixture.sol";

interface CustodyRightsCalls {
    function expectCall(address target, uint256 value, bytes calldata data, uint64 count) external;
}

contract StreamCurrentCustodyRightsBatchTest is NativeCustodyRightsBatchFixture {
    CustodyRightsCalls private constant calls =
        CustodyRightsCalls(address(uint160(uint256(keccak256("hevm cheat code")))));

    function testThreeTokenTemplateFamiliesMaterializeActualCustodyAndPreserveOrigin() public {
        _bindCustody();
        for (uint8 mode = 2; mode <= 4; ++mode) {
            Plan memory p = _custodyPlan(false, address(this), address(this));
            bytes32 id = _openCustody(p);
            uint256 token = p.auth.expectedTokenId;
            bytes32 origin = keccak256(abi.encode(house.custodyOrigin(id)));
            bytes32 config = house.auction(id).configHash;
            (bytes32 tid,) = _batchTemplate(token, mode);
            StreamCustodyRightsTypes.Activation memory activation = _activateBatch(id, mode);
            (StreamSaleTemplate.Selection memory selected,, bytes32 witness) = StreamCustodyRightsValidation.selection(
                StreamPrimarySettlementRights.Context(
                    resolver, factory, factory.splitWalletRuntimeCodeHash()
                ),
                1,
                token,
                mode,
                address(this)
            );
            require(
                selected.templateId == tid && selected.wallet.code.length == 0,
                "preview remains unmaterialized"
            );
            _batchBid(id, payer);
            _custodyEnd(id);
            IStreamNativeEnglishAuction.Auction memory expectedAuction = house.auction(id);
            expectedAuction.status = 2;
            StreamNativeCustodySettlementTypes.Facts memory expectedFacts =
                StreamNativeCustodySettlementTypes.Facts(
                    id, expectedAuction, house.custodyOrigin(id)
                );
            vm.recordLogs();
            (uint256 actual, bytes32 key) = house.settleCustodyRights(id);
            Vm.Log[] memory logs = vm.getRecordedLogs();
            StreamPrimarySettlementTypes.PrimarySettlementResult memory result =
                recorder.settlementResult(key);
            require(
                actual == token && core.ownerOf(token) == payer && result.amount == 1000
                    && result.profileId == selected.profileId && result.wallet == selected.wallet
                    && result.escrowed && result.operationIdentityCommitment == 0
                    && manager.nextOperationNonce() == token && core.lastAllocatedTokenId() == token
                    && _custodyCounter(p) == 1 && house.auction(id).configHash == config
                    && activation.authorization.originHash == origin
                    && !house.custodyOrigin(id).eligible,
                "official transfer no second mint"
            );
            require(
                escrow.escrowOwed(CLASS, selected.profileId, selected.wallet, address(0)) == 1000,
                "exact forced escrow"
            );
            uint256 count;
            bytes32 topic = keccak256(
                "CustodyRightsRevenueRecorded(uint16,bytes32,bytes32,bytes32,(bytes32,((uint256,bytes32,uint256,bool,bytes32,bytes32,bytes32,address,uint96,uint16,bool,(uint64,uint64,uint32,uint32,uint32,uint32,bool,bool),bytes32,uint8,uint32,bytes32),bytes32,bytes32,uint256,uint256,uint8,(uint64,uint64,bool),uint64,uint64,uint64,bytes32,bytes32,bytes32,(uint64,uint64),(address,address,address,uint256,uint256,uint256,bytes32,uint64,bool),uint256,bytes32,address),(address,bytes32,bytes32,bytes32,bytes32,bytes32,uint256,uint256,uint256,address,uint256,bool)),((bytes32,bytes32,bytes32,uint256,uint8,bytes32,bytes32,uint8,address,bytes32,uint64),bytes32,bytes32),bytes32,(bytes32,bytes32,bytes32,address,address,uint256,address,bytes32,bool,bytes32,bytes32,bytes32))"
            );
            for (uint256 i; i < logs.length; ++i) {
                if (
                    logs[i].emitter == address(recorder) && logs[i].topics.length == 4
                        && logs[i].topics[0] == topic
                ) {
                    ++count;
                    require(
                        logs[i].topics[1] == key
                            && logs[i].topics[2]
                                == recorder.preparedNativeSaleKey(
                                    address(house),
                                    house.auction(id).saleId,
                                    house.auction(id).saleNonce
                                ),
                        "indexed identities"
                    );
                    (
                        uint16 schema,
                        StreamNativeCustodySettlementTypes.Facts memory facts,
                        StreamCustodyRightsTypes.Activation memory saved,
                        bytes32 actualWitness,
                        StreamPrimarySettlementTypes.PrimarySettlementResult memory savedResult
                    ) = abi.decode(
                        logs[i].data,
                        (
                            uint16,
                            StreamNativeCustodySettlementTypes.Facts,
                            StreamCustodyRightsTypes.Activation,
                            bytes32,
                            StreamPrimarySettlementTypes.PrimarySettlementResult
                        )
                    );
                    bytes32 factsHash = keccak256(
                        abi.encode(
                            keccak256("6529STREAM_CUSTODY_RIGHTS_FACTS_V1"),
                            block.chainid,
                            address(recorder),
                            address(house),
                            facts,
                            saved
                        )
                    );
                    require(
                        logs[i].topics[3] == factsHash
                            && recorder.preparedNativeSaleConsumed(logs[i].topics[2]),
                        "full facts and shared sale replay"
                    );
                    require(
                        schema == 1
                            && keccak256(abi.encode(facts)) == keccak256(abi.encode(expectedFacts))
                            && facts.auctionId == id && facts.auction.tokenId == token
                            && keccak256(abi.encode(saved)) == keccak256(abi.encode(activation))
                            && actualWitness == witness
                            && keccak256(abi.encode(savedResult)) == keccak256(abi.encode(result)),
                        "full receipt"
                    );
                }
            }
            require(count == 1, "one complete custody-rights receipt");
            (uint256 again, bytes32 same) = house.settleCustodyRights(id);
            require(again == token && same == key, "terminal idempotence");
        }
    }

    function testDefaultProfileActualPrecedenceAndPaidCustody() public {
        _bindCustody();
        Plan memory p = _custodyPlan(false, address(this), address(this));
        bytes32 id = _openCustody(p);
        bytes32 hash = _defaultProfile();
        StreamCustodyRightsTypes.Activation memory a = _activateBatch(id, 1);
        require(a.authorization.assignmentHash == hash, "scope0 original source");
        (StreamSaleTemplate.Selection memory s,,) = StreamCustodyRightsValidation.selection(
            StreamPrimarySettlementRights.Context(
                resolver, factory, factory.splitWalletRuntimeCodeHash()
            ),
            1,
            1,
            1,
            address(this)
        );
        _batchBid(id, payer);
        _custodyEnd(id);
        (, bytes32 key) = house.settleCustodyRights(id);
        require(
            core.ownerOf(1) == payer && s.wallet.balance == 1000
                && recorder.settlementResult(key).profileId == s.profileId,
            "default PROFILE payment"
        );
    }

    function testModeMutationOldEntriesAndExactScopeLossCannotCrossActivation() public {
        _bindCustody();
        Plan memory p = _custodyPlan(false, address(this), address(this));
        bytes32 id = _openCustody(p);
        (, bytes32 hash) = _batchTemplate(1, 3);
        StreamCustodyRightsTypes.Authorization memory a = _batchAuthorization(id, 3, id);
        bytes memory original = _batchCall(a);
        bytes32 digest = house.custodyRightsDigest(a);
        bytes memory platform = _custodyProof(AUCTION_PLATFORM_KEY, digest);
        bytes memory artistProof = _custodyProof(SIGNER_KEY, digest);
        a.rightsMode = 2;
        (bool mutation,) = address(house)
            .call(abi.encodeCall(house.activateCustodyRights, (a, platform, artistProof)));
        require(
            !mutation && !house.custodyRightsNonceUsed(a.artist, a.nonce),
            "signed family cannot change"
        );
        a.rightsMode = 3;
        scopedArtist.approveScope(address(resolver), 1, 2, 1, hash, false);
        (bool missing,) = address(house).call(original);
        require(
            !missing && !house.custodyRightsNonceUsed(a.artist, a.nonce),
            "no collection consent substitution"
        );
        scopedArtist.approveScope(address(resolver), 1, 2, 1, hash, true);
        (bool ok,) = address(house).call(original);
        require(ok, "identical activation retry");
        (bool replay,) = address(house).call(original);
        require(!replay, "activation replay");
        vm.deal(payer, 1 ether);
        vm.prank(payer);
        (bool old,) = address(house).call{ value: 1000 }(abi.encodeCall(house.bid, (id, payer)));
        require(!old, "old bid segregated");
        scopedArtist.approveScope(address(resolver), 1, 2, 1, hash, false);
        vm.prank(payer);
        (bool lost,) =
            address(house).call{ value: 1000 }(abi.encodeCall(house.bidCustodyRights, (id, payer)));
        require(!lost && house.auction(id).winner.amount == 0, "bid checks exact current consent");
        scopedArtist.approveScope(address(resolver), 1, 2, 1, hash, true);
        _batchBid(id, payer);
    }

    function testSafeLateEscrowConsentFailureRetainsIdenticalSignedRetry() public {
        _bindCustody();
        Plan memory p = _custodyPlan(false, address(this), address(this));
        bytes32 id = _openCustody(p);
        _batchTemplate(1, 4);
        _activateBatch(id, 4);
        uint256[] memory keys = new uint256[](2);
        keys[0] = 0x16401;
        keys[1] = 0x16402;
        OfficialSafe safe =
            createOfficialSafe(deploySafeComponents("1.4.1"), safeOwnerAddresses(keys), 2, 164);
        vm.deal(address(safe), 1 ether);
        require(
            executeSafe(
                safe,
                keys,
                address(house),
                1000,
                abi.encodeCall(house.bidCustodyRights, (id, address(safe))),
                0
            ),
            "payer Safe bid"
        );
        _custodyEnd(id);
        (StreamSaleTemplate.Selection memory selected,,) = StreamCustodyRightsValidation.selection(
            StreamPrimarySettlementRights.Context(
                resolver, factory, factory.splitWalletRuntimeCodeHash()
            ),
            1,
            1,
            4,
            address(this)
        );
        require(address(escrow).balance == 0, "zero funding trigger baseline");
        scopedArtist.failAfterFunding(address(escrow));
        bytes memory data = abi.encodeCall(house.settleCustodyRights, (id));
        uint256 nonce = safe.nonce();
        bytes32 digest =
            safe.getTransactionHash(
            address(house), 0, data, 0, 0, 0, 0, address(0), address(0), nonce
        );
        bytes memory call_ = abi.encodeCall(
            safe.execTransaction,
            (
                address(house),
                0,
                data,
                0,
                0,
                0,
                0,
                address(0),
                payable(address(0)),
                safeThresholdSignature(keys, digest)
            )
        );
        calls.expectCall(
            address(escrow),
            1000,
            abi.encodeCall(escrow.creditNative, (CLASS, selected.profileId, selected.wallet, true)),
            2
        );
        (bool failed,) = address(safe).call(call_);
        require(
            !failed && safe.nonce() == nonce && core.ownerOf(1) == address(house)
                && house.auction(id).winner.amount == 1000
                && escrow.escrowOwed(CLASS, selected.profileId, selected.wallet, address(0)) == 0
                && manager.nextOperationNonce() == 1,
            "late rollback retains acquired token"
        );
        scopedArtist.failAfterFunding(address(0));
        (bool ok, bytes memory result) = address(safe).call(call_);
        require(
            ok && abi.decode(result, (bool)) && safe.nonce() == nonce + 1
                && core.ownerOf(1) == address(safe),
            "identical signed retry"
        );
    }

    function testActivatedNoBidRemainsIndependentOfTemplateConsent() public {
        _bindCustody();
        Plan memory p = _custodyPlan(false, address(this), address(this));
        bytes32 id = _openCustody(p);
        _batchTemplate(1, 2);
        _activateBatch(id, 2);
        _custodyEnd(id);
        scopedArtist.setConsent(false);
        house.settle(id);
        require(core.ownerOf(1) == address(this), "old no-bid exit needs no new consent");
    }

    function testActivatedSignedDeadlineRefundAndPosterClaimIgnoreLostAdmission() public {
        _bindCustody();
        Plan memory p = _custodyPlan(false, address(this), address(this));
        bytes32 id = _openCustody(p);
        _batchTemplate(1, 3);
        StreamCustodyRightsTypes.Activation memory active = _activateBatch(id, 3);
        (, uint64 deadline,,) = house.auctionDeadlines(id);
        IStreamNativeEnglishAuction.BidAuthorization memory bid =
            IStreamNativeEnglishAuction.BidAuthorization(
                id,
                active.effectiveConfigHash,
                payer,
                address(this),
                payer,
                1000,
                0,
                keccak256("batch deadline bid"),
                this.custodyFixtureTime() + 100,
                deadline
            );
        bytes memory proof = _custodyProof(PAYER_KEY, house.bidAuthorizationDigest(bid));
        house.bidSignedCustodyRights{ value: 1000 }(bid, proof);
        scopedArtist.setConsent(false);
        _status(address(recorder), ModuleRegistryStatus.INCIDENT_REVOKED);
        vm.warp(uint256(deadline) + 1);
        house.unlockCustodySale(id, 0);
        bytes32 saleId = house.auction(id).saleId;
        require(
            core.ownerOf(1) == address(this) && !house.custodyOrigin(id).eligible
                && house.refundableBalance(saleId, payer) == 1000,
            "poster token and original payer credit"
        );
        vm.prank(payer);
        house.claimRefund(saleId, payable(payer));
        house.claimRefund(saleId, payable(address(this)));
        require(
            house.totalBuyerLiabilities() == 0 && address(house).balance == 0
                && recorder.totalOfficialSettled(address(0)) == 0,
            "all original escape liabilities"
        );
    }

    function testCurrentDynamicPayoutDriftIsAllowedBeforeBidButKeepsOriginalActivation() public {
        _bindCustody();
        Plan memory p = _custodyPlan(false, address(this), address(this));
        bytes32 id = _openCustody(p);
        (, bytes32 assignment) = _batchTemplate(1, 4);
        StreamCustodyRightsTypes.Activation memory original = _activateBatch(id, 4);
        scopedArtist.setCollaboratorPayout(COLLAB, address(0xC0C));
        (StreamSaleTemplate.Selection memory current, bytes32 policy, bytes32 witness) = StreamCustodyRightsValidation.selection(
            StreamPrimarySettlementRights.Context(
                resolver, factory, factory.splitWalletRuntimeCodeHash()
            ),
            1,
            1,
            4,
            address(this)
        );
        require(
            policy != original.authorization.primaryPolicyHash
                && current.assignmentHash == assignment && witness != 0,
            "ALLOW_CURRENT separates source from payout selection"
        );
        _batchBid(id, payer);
        _custodyEnd(id);
        (, bytes32 key) = house.settleCustodyRights(id);
        require(
            recorder.settlementResult(key).profileId == current.profileId
                && keccak256(abi.encode(house.custodyRightsActivation(id)))
                    == keccak256(abi.encode(original)),
            "new concrete profile retains complete original authorization"
        );
        uint256 found;
        for (uint256 i; i < factory.profileEntryCount(current.profileId); ++i) {
            (address account, uint32 share, bytes32 label) =
                factory.profileEntry(current.profileId, i);
            if (label == keccak256("composer-share")) {
                require(
                    account == address(0xC0C) && share == 600000,
                    "current typed collaborator payout"
                );
                ++found;
            }
        }
        require(found == 1, "one paid row");
    }

    function testNewRouteNeedsActivationAndTokenTemplateRejectsInheritedFallback() public {
        _bindCustody();
        Plan memory p = _custodyPlan(false, address(this), address(this));
        bytes32 id = _openCustody(p);
        _batchTemplate(1, 3);
        vm.deal(payer, 1 ether);
        vm.prank(payer);
        (bool ok,) =
            address(house).call{ value: 1000 }(abi.encodeCall(house.bidCustodyRights, (id, payer)));
        require(
            !ok && house.auction(id).winner.amount == 0, "new entry requires explicit activation"
        );
        _activateBatch(id, 3);
        bytes32 profileHash =
            resolver.previewArtistPrimaryAssignmentForScope(1, 2, 1, profile, 0, false)
        .assignmentHash;
        scopedArtist.approveScope(address(resolver), 1, 2, 1, profileHash, true);
        resolver.setPrimaryProfileAssignment(CLASS, 2, 1, profile, 0);
        scopedArtist.approveScope(address(resolver), 1, 2, 1, bytes32(0), true);
        resolver.clearPrimaryAssignment(CLASS, 2, 1);
        vm.prank(payer);
        (ok,) = address(house).call{ value: 1000 }(
            abi.encodeCall(house.bidCustodyRights, (id, payer))
        );
        require(
            !ok && house.auction(id).winner.amount == 0,
            "inherited collection cannot replace exact token TEMPLATE"
        );
        _batchTemplate(1, 3);
        _batchBid(id, payer);
        _custodyEnd(id);
        house.settleCustodyRights(id);
        require(core.ownerOf(1) == payer, "approved exact token source restores route");
    }
}
