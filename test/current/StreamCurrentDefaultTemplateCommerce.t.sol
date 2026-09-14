// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "../helpers/NativeDefaultTemplateFixture.sol";

interface DefaultTemplateCalls {
    function expectCall(address target, uint256 value, bytes calldata data, uint64 count) external;
}

contract StreamCurrentDefaultTemplatePreparedTest is NativeDefaultTemplateAuctionFixture {
    DefaultTemplateCalls private constant calls =
        DefaultTemplateCalls(address(uint160(uint256(keccak256("hevm cheat code")))));
    bytes32 private constant RECEIPT = keccak256(
        "PreparedNativeRightsRevenueRecorded(bytes32,bytes32,bytes32,((address,address,address,bytes32,uint256,bytes32,bytes32,bytes32,bytes32,uint256,uint256,address,address,address,bytes32,bytes32,bytes32,bytes32),(uint8,bytes32,bytes32)),((uint256,bytes32,bytes32,uint256,address,address,address,address,uint256,uint8,bytes32,uint256,uint8,bytes32,bytes32,bytes32,bytes32,bytes32,bytes32),(uint8,bytes32,bytes32)),bytes32)"
    );

    function testThreeDefaultTemplateFamiliesUseScopeZeroAndActualPreparedTokenReceipts() public {
        for (uint8 mode = 5; mode <= 7; ++mode) {
            _setDefault(mode);
            bytes32 id = _createRights(_rightsConfig());
            StreamSaleTemplate.Selection memory s = _selected();
            _rightsBid(id, payer);
            _endRights(id);
            vm.recordLogs();
            (uint256 token, bytes32 key) = house.settle(id);
            Vm.Log[] memory logs = vm.getRecordedLogs();
            uint256 count;
            require(
                token == mode - 4 && core.ownerOf(token) == payer
                    && manager.nextOperationNonce() == token
                    && escrow.escrowOwed(CLASS, s.profileId, s.wallet, address(0)) == 1000,
                "actual default template mint and forced escrow"
            );
            for (uint256 i; i < logs.length; ++i) {
                if (
                    logs[i].emitter == address(recorder) && logs[i].topics.length == 4
                        && logs[i].topics[0] == RECEIPT
                ) {
                    ++count;
                    (
                        StreamPreparedNativeRightsTypes.Facts memory f,
                        StreamPreparedNativeRightsTypes.Intent memory intent,
                        bytes32 policy
                    ) = abi.decode(
                        logs[i].data,
                        (
                            StreamPreparedNativeRightsTypes.Facts,
                            StreamPreparedNativeRightsTypes.Intent,
                            bytes32
                        )
                    );
                    bytes32 hash = keccak256(
                        abi.encode(
                            keccak256("6529STREAM_PREPARED_NATIVE_RIGHTS_FACTS_V1"),
                            block.chainid,
                            f
                        )
                    );
                    require(
                        logs[i].data.length == 1376 && logs[i].topics[1] == key
                            && logs[i].topics[2]
                                == recorder.preparedNativeSaleKey(
                                    address(house),
                                    house.auction(id).saleId,
                                    house.auction(id).saleNonce
                                ) && logs[i].topics[3] == hash
                            && recorder.preparedNativeRightsFactsHash(key) == hash,
                        "all original indexed receipt words"
                    );
                    require(
                        f.mint.tokenId == token && f.original.mode == mode
                            && f.original.assignmentHash == selectedDefault
                            && f.original.templateId == s.templateId
                            && keccak256(abi.encode(f.original))
                                == keccak256(abi.encode(intent.original))
                            && policy == _policy(token, s)
                            && policy != intent.sale.originalPrimaryPolicyHash,
                        "raw default hash and actual token context distinct"
                    );
                    require(
                        ledger.isManagerOperationRootUsed(address(manager), f.mint.operationRoot)
                            && recorder.settlementResult(key).operationIdentityCommitment
                                == f.mint.operationRoot,
                        "original operation root/result binding"
                    );
                }
            }
            require(count == 1, "one complete prepared rights receipt");
        }
    }

    function testFrozenDefaultNeedsItsOwnCurrentConsentAndOverridesCannotBeSkipped() public {
        bytes32 old = selectedDefault;
        resolver.freezePrimaryAssignment(CLASS, 0, 0);
        bytes32 frozen = resolver.primaryEconomicsFacts(1, 0, 0).assignmentHash;
        require(
            old != frozen && resolver.primaryEconomicsFacts(1, 0, 0).frozen,
            "frozen bit belongs to original default preimage"
        );
        (bool ok,) = address(this).staticcall(abi.encodeCall(this.project, (uint256(0))));
        require(!ok, "unfrozen approval cannot authorize frozen source");
        defaultArtist.approveScope(address(resolver), 1, 0, 0, frozen, true);
        bytes32 id = _createRights(_rightsConfig());
        resolver.setPrimaryProfileAssignment(CLASS, 1, 1, profile, 0);
        uint256 value = 1000 + entropy.fee();
        vm.deal(payer, 1 ether);
        vm.prank(payer);
        (ok,) = address(house).call{ value: value }(abi.encodeCall(house.bid, (id, payer)));
        require(
            !ok && house.auction(id).winner.amount == 0,
            "configured collection overrides frozen default"
        );
        resolver.clearPrimaryAssignment(CLASS, 1, 1);
        _rightsBid(id, payer);
        _endRights(id);
        house.settle(id);
        require(core.ownerOf(1) == payer, "inherited frozen default is usable with exact consent");
        bytes32 p =
            resolver.previewArtistPrimaryAssignmentForScope(1, 2, 1, profile, 0, false)
        .assignmentHash;
        defaultArtist.approveScope(address(resolver), 1, 2, 1, p, true);
        resolver.setPrimaryProfileAssignment(CLASS, 2, 1, profile, 0);
        (ok,) = address(this).staticcall(abi.encodeCall(this.project, (uint256(1))));
        require(!ok, "token override cannot be bypassed");
    }

    function project(uint256 token) external view returns (bytes32) {
        (StreamSaleTemplate.Selection memory s,) =
            StreamDefaultSaleTemplate.resolve(resolver, 1, token, defaultMode, address(this));
        return s.assignmentHash;
    }

    function testDefaultDynamicSafeLateEscrowFailureAndIdenticalTransactionRetry() public {
        _setDefault(7);
        bytes32 id = _createRights(_rightsConfig());
        uint256[] memory keys = new uint256[](2);
        keys[0] = 0x17501;
        keys[1] = 0x17502;
        OfficialSafe safe =
            createOfficialSafe(deploySafeComponents("1.4.1"), safeOwnerAddresses(keys), 2, 175);
        vm.deal(address(safe), 1 ether);
        uint256 value = 1000 + entropy.fee();
        require(
            executeSafe(
                safe, keys, address(house), value, abi.encodeCall(house.bid, (id, address(safe))), 0
            ),
            "actual Safe bid"
        );
        _endRights(id);
        StreamSaleTemplate.Selection memory selected = _selected();
        uint256 nonce = safe.nonce();
        bytes memory data = abi.encodeCall(house.settle, (id));
        bytes32 digest =
            safe.getTransactionHash(
            address(house), 0, data, 0, 0, 0, 0, address(0), address(0), nonce
        );
        bytes memory original = abi.encodeCall(
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
        require(address(escrow).balance == 0, "zero late funding baseline");
        defaultArtist.failAfterFunding(address(escrow));
        calls.expectCall(
            address(escrow),
            1000,
            abi.encodeCall(escrow.creditNative, (CLASS, selected.profileId, selected.wallet, true)),
            2
        );
        (bool ok,) = address(safe).call(original);
        require(
            !ok && safe.nonce() == nonce && core.lastAllocatedTokenId() == 0
                && manager.nextOperationNonce() == 0 && address(escrow).balance == 0
                && recorder.totalOfficialSettled(address(0)) == 0,
            "post-credit failure rolls back mint and payment"
        );
        defaultArtist.failAfterFunding(address(0));
        bytes memory out;
        (ok, out) = address(safe).call(original);
        require(
            ok && abi.decode(out, (bool)) && safe.nonce() == nonce + 1
                && core.ownerOf(1) == address(safe)
                && escrow.escrowOwed(CLASS, selected.profileId, selected.wallet, address(0))
                    == 1000,
            "identical signed transaction commits once"
        );
    }
}

contract StreamCurrentDefaultTemplateCustodyTest is NativeCustodyRightsBatchFixture {
    function testThreeDefaultTemplatesTransferActualCustodyWithoutAnotherMint() public {
        _bindCustody();
        for (uint8 mode = 5; mode <= 7; ++mode) {
            resolver.setPrimaryProfileAssignment(CLASS, 1, 1, profile, 0);
            Plan memory p = _custodyPlan(false, address(this), address(this));
            bytes32 id = _openCustody(p);
            (, bytes32 hash) = NativeDefaultTemplateBuilder.select(resolver, scopedArtist, mode);
            resolver.clearPrimaryAssignment(CLASS, 1, 1);
            StreamCustodyRightsTypes.Activation memory active = _activateBatch(id, mode);
            (StreamSaleTemplate.Selection memory selected,,) = StreamCustodyRightsValidation.selection(
                StreamPrimarySettlementRights.Context(
                    resolver, factory, factory.splitWalletRuntimeCodeHash()
                ),
                1,
                p.auth.expectedTokenId,
                mode,
                address(this)
            );
            require(active.authorization.assignmentHash == hash, "scope0 original source");
            _batchBid(id, payer);
            _custodyEnd(id);
            (uint256 token, bytes32 key) = house.settleCustodyRights(id);
            require(
                token == mode - 4 && core.ownerOf(token) == payer
                    && manager.nextOperationNonce() == token && _custodyCounter(p) == 1
                    && recorder.settlementResult(key).operationIdentityCommitment == 0
                    && escrow.escrowOwed(CLASS, selected.profileId, selected.wallet, address(0))
                        == 1000,
                "official unpaid-origin transfer with default template escrow"
            );
        }
    }

    function testDefaultCustodyActivationRequiresSourceApprovalAndHonorsCollectionOverride()
        public
    {
        _bindCustody();
        Plan memory p = _custodyPlan(false, address(this), address(this));
        bytes32 id = _openCustody(p);
        (, bytes32 hash) = NativeDefaultTemplateBuilder.select(resolver, scopedArtist, 6);
        resolver.clearPrimaryAssignment(CLASS, 1, 1);
        StreamCustodyRightsTypes.Authorization memory a = _batchAuthorization(id, 6, id);
        bytes memory original = _batchCall(a);
        scopedArtist.approveScope(address(resolver), 1, 0, 0, hash, false);
        (bool ok,) = address(house).call(original);
        require(
            !ok && !house.custodyRightsNonceUsed(a.artist, a.nonce),
            "collection approval is not default scope approval"
        );
        scopedArtist.approveScope(address(resolver), 1, 0, 0, hash, true);
        (ok,) = address(house).call(original);
        require(ok, "identical activation retry");
        resolver.setPrimaryProfileAssignment(CLASS, 1, 1, profile, 0);
        vm.deal(payer, 1 ether);
        vm.prank(payer);
        (ok,) = address(house).call{ value: 1000 }(
            abi.encodeCall(house.bidCustodyRights, (id, payer))
        );
        require(
            !ok && house.auction(id).winner.amount == 0,
            "activation cannot skip newly configured override"
        );
        resolver.clearPrimaryAssignment(CLASS, 1, 1);
        _batchBid(id, payer);
        _custodyEnd(id);
        house.settleCustodyRights(id);
        require(core.ownerOf(1) == payer, "restored exact source remains usable");
    }
}
