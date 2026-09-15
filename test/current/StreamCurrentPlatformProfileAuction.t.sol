// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "../helpers/NativePlatformRightsFixture.sol";
import "../../smart-contracts/interfaces/stream/revenue/IStreamPlatformProfilePrimarySettlement.sol";

interface PlatformProfileCalls {
    function expectCall(address, uint256, bytes calldata, uint64) external;
    function mockCall(address, bytes calldata, bytes calldata) external;
    function clearMockedCalls() external;
}

/// @notice Actual commerce with typed Artist/governance/entropy; no synthetic platform op15.
contract StreamCurrentPlatformProfileAuctionTest is NativePlatformRightsFixture {
    PlatformProfileCalls private constant calls =
        PlatformProfileCalls(address(uint160(uint256(keccak256("hevm cheat code")))));
    bytes32 private constant RECEIPT = keccak256(
        "PlatformPreparedPrimaryBound(uint16,bytes32,bytes32,bytes32,uint8,bytes32,address,bytes32)"
    );

    function _fixed(uint8 mode, address recipient) private returns (bytes32 id, address account) {
        IStreamSplitWallet.SplitEntry[] memory entries = new IStreamSplitWallet.SplitEntry[](1);
        entries[0] =
            IStreamSplitWallet.SplitEntry(recipient, 1000000, keccak256("platform recipient"));
        (id, account) = factory.createProfile(
            entries, keccak256(abi.encode("fixed platform terms", mode, recipient))
        );
        if (mode == 11) {
            IStreamRevenueResolver.ResolvedPrimaryAssignment memory old =
                resolver.resolvePrimaryAssignment(2, 0, CLASS);
            if (old.exists && old.scope == 1) resolver.clearPrimaryAssignment(CLASS, 1, 2);
        }
        resolver.setPrimaryProfileAssignment(CLASS, mode == 10 ? 1 : 0, mode == 10 ? 2 : 0, id, 0);
    }

    function projectProfile(uint256 token, uint8 mode)
        external
        view
        returns (StreamSaleTemplate.Selection memory, bytes32)
    {
        return StreamPlatformPrimaryProfile.resolve(resolver, 2, token, mode, address(this));
    }

    function testCollectionAndDefaultVerifiedProfilesPayRealWalletWithActualTokenReceipt() public {
        for (uint8 mode = 10; mode <= 11; ++mode) {
            (bytes32 profileId, address account) = _fixed(mode, address(uint160(0xCA00 + mode)));
            bytes32 id = _open(mode);
            IStreamNativeEnglishAuction.Auction memory a = house.auction(id);
            StreamSaleTemplate.Selection memory selected = _selected(mode);
            require(
                selected.templateId == 0 && house.originalAuctionRights(id).templateId == 0,
                "explicit fixed profile"
            );
            _bid(id, payer);
            _end(id);
            uint256 balance = account.balance;
            vm.recordLogs();
            (uint256 token, bytes32 key) = house.settle(id);
            Vm.Log[] memory logs = vm.getRecordedLogs();
            require(
                token == mode - 9 && core.ownerOf(token) == payer
                    && account.balance == balance + 1000,
                "actual allocation and fixed wallet payment"
            );
            StreamPrimarySettlementTypes.PrimarySettlementResult memory result =
                recorder.settlementResult(key);
            require(
                !result.escrowed && result.amount == 1000 && result.profileId == profileId
                    && result.wallet == account,
                "original fixed-profile result"
            );
            require(
                escrow.escrowOwed(CLASS, profileId, account, address(0)) == 0,
                "no template escrow fiction"
            );
            (, bytes32 declaration,) = platform.platformWorksDeclaration(2);
            IStreamRevenueResolver.ResolvedPrimaryAssignment memory actual =
                resolver.resolvePrimaryAssignment(2, token, CLASS);
            bytes32 witness = keccak256(
                abi.encode(
                    keccak256("6529STREAM_PLATFORM_PRIMARY_PROFILE_WITNESS_V1"),
                    block.chainid,
                    address(resolver),
                    uint256(2),
                    token,
                    mode,
                    declaration,
                    address(this),
                    actual,
                    selected
                )
            );
            uint256 count;
            for (uint256 i; i < logs.length; ++i) {
                if (
                    logs[i].emitter == address(recorder) && logs[i].topics.length == 4
                        && logs[i].topics[0] == RECEIPT
                ) {
                    ++count;
                    require(
                        logs[i].topics[1] == key
                            && logs[i].topics[2]
                                == recorder.preparedNativeSaleKey(
                                    address(house), a.saleId, a.saleNonce
                                ) && logs[i].topics[3] == declaration,
                        "all indexed identities"
                    );
                    require(
                        keccak256(logs[i].data)
                            == keccak256(
                                abi.encode(
                                    uint16(1),
                                    mode,
                                    witness,
                                    address(this),
                                    _policy(token, selected)
                                )
                            ),
                        "complete independent profile receipt"
                    );
                }
            }
            require(
                count == 1 && _policy(token, selected) != a.config.expectedPrimaryPolicyHash
                    && a.artistId == 0,
                "actual token policy and no fabricated Artist"
            );
        }
    }

    function testOlderTemplateOnlyRecorderIsRejectedBeforeOpeningThenSameAuthorizationWorks()
        public
    {
        _fixed(10, address(0xCB01));
        bytes memory original = _opening(10);
        calls.mockCall(
            address(recorder),
            abi.encodeCall(
                IERC165.supportsInterface,
                (type(IStreamPlatformProfilePrimarySettlement).interfaceId)
            ),
            abi.encode(false)
        );
        (bool ok,) = address(house).call(original);
        require(
            !ok && core.lastAllocatedTokenId() == 0,
            "older platform capability cannot promise fixed profiles"
        );
        calls.clearMockedCalls();
        bytes memory out;
        (ok, out) = address(house).call(original);
        require(
            ok && house.auction(abi.decode(out, (bytes32))).status == 1,
            "same authorized opening after capability repair"
        );
        (ok,) = address(house).call(original);
        require(!ok, "original platform creator replay remains consumed");
    }

    function testWalletRuntimeLossRefusesOpeningAndIdenticalSignedCallRetriesAfterRepair() public {
        (, address account) = _fixed(10, address(0xCB02));
        bytes memory original = _opening(10);
        bytes memory runtime = account.code;
        vm.etch(account, hex"00");
        (bool ok,) = address(house).call(original);
        require(!ok, "a stored profile cannot excuse a wrong runtime");
        vm.etch(account, runtime);
        bytes memory out;
        (ok, out) = address(house).call(original);
        require(
            ok && house.auction(abi.decode(out, (bytes32))).status == 1,
            "exact original authorized call retries"
        );
    }

    function testDefaultProfileCannotSkipOverridesAndCurrentDriftStaysInsideSignedFamily() public {
        (bytes32 oldProfile, address oldWallet) = _fixed(11, address(0xCB03));
        bytes32 id = _open(11);
        _fixed(10, address(0xCB04));
        uint256 value = 1000 + entropy.fee();
        vm.deal(payer, 1 ether);
        bytes memory bidData = abi.encodeCall(house.bid, (id, payer));
        vm.prank(payer);
        (bool ok,) = address(house).call{ value: value }(bidData);
        require(
            !ok && house.auction(id).winner.amount == 0,
            "collection override blocks default before deposit"
        );
        resolver.clearPrimaryAssignment(CLASS, 1, 2);
        _bid(id, payer);
        _end(id);
        (bytes32 next, address nextWallet) = _fixed(11, address(0xCB05));
        (uint256 token, bytes32 key) = house.settle(id);
        require(
            token == 1 && next != oldProfile && recorder.settlementResult(key).profileId == next
                && nextWallet.balance == 1000 && oldWallet.balance == 0,
            "ALLOW_CURRENT selects current default PROFILE"
        );
        resolver.setPrimaryProfileAssignment(CLASS, 2, token, oldProfile, 0);
        (ok,) = address(this).staticcall(abi.encodeCall(this.projectProfile, (token, uint8(11))));
        require(!ok, "actual token override is never skipped");
        _template(9, true);
        (ok,) =
            address(this).staticcall(abi.encodeCall(this.projectProfile, (uint256(0), uint8(11))));
        require(
            !ok && core.ownerOf(1) == payer,
            "TEMPLATE replacement cannot masquerade as fixed PROFILE"
        );
    }

    function testCorrectiveArtistCannotContinuePlatformProfilePaymentButRefundEscapeSurvives()
        public
    {
        _fixed(10, address(0xCB06));
        bytes32 id = _open(10);
        _bid(id, payer);
        _end(id);
        platform.contest(3);
        platform.correct(1, true);
        (bool ok,) = address(house).call(abi.encodeCall(house.settle, (id)));
        require(
            !ok && core.lastAllocatedTokenId() == 0
                && recorder.totalOfficialSettled(address(0)) == 0,
            "corrected Artist needs own authority, not original platform signature"
        );
        (, uint64 deadline,,) = house.auctionDeadlines(id);
        vm.warp(uint256(deadline) + 1);
        house.unlockNoMint(id, 0);
        bytes32 sale = house.auction(id).saleId;
        uint256 amount = 1000 + entropy.fee();
        uint256 beforeBalance = payer.balance;
        vm.prank(payer);
        house.claimRefund(sale, payable(payer));
        require(
            payer.balance == beforeBalance + amount,
            "original independent payer refund remains usable"
        );
    }

    function testPostWalletContestRollsBackExactSafeCallAndRetryPaysOnlyOnce() public {
        (bytes32 profileId, address account) = _fixed(11, address(0xCB07));
        bytes32 id = _open(11);
        uint256[] memory keys = new uint256[](2);
        keys[0] = 0x18511;
        keys[1] = 0x18512;
        OfficialSafe safe =
            createOfficialSafe(deploySafeComponents("1.4.1"), safeOwnerAddresses(keys), 2, 186);
        vm.deal(address(safe), 1 ether);
        uint256 value = 1000 + entropy.fee();
        require(
            executeSafe(
                safe, keys, address(house), value, abi.encodeCall(house.bid, (id, address(safe))), 0
            )
        );
        _end(id);
        uint256 nonce = safe.nonce();
        bytes memory data = abi.encodeCall(house.settle, (id));
        bytes32 digest = safe.getTransactionHash(
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
        bytes32 subject = manager.previewSubjectKey(
            IStreamMintManager.CounterKeyMode.PAYER,
            2,
            PLATFORM_PHASE,
            COUNTER,
            address(safe),
            address(safe),
            address(house),
            address(0),
            0
        );
        bytes32 counter = manager.previewCounterValueKey(2, PLATFORM_PHASE, COUNTER, subject);
        require(
            account.balance == 0 && ledger.counterValue(counter) == 0,
            "exact funding/counter baseline"
        );
        platform.failAfterFunding(account);
        calls.expectCall(account, 1000, bytes(""), 2);
        (bool ok,) = address(safe).call(original);
        require(
            !ok && safe.nonce() == nonce && core.lastAllocatedTokenId() == 0
                && manager.nextOperationNonce() == 0 && account.balance == 0
                && address(escrow).balance == 0 && recorder.totalOfficialSettled(address(0)) == 0
                && ledger.counterValue(counter) == 0 && house.auction(id).status == 1,
            "actual late wallet payment rolls back with all original state"
        );
        platform.failAfterFunding(address(0));
        bytes memory out;
        (ok, out) = address(safe).call(original);
        require(
            ok && abi.decode(out, (bool)) && safe.nonce() == nonce + 1
                && core.ownerOf(1) == address(safe) && account.balance == 1000
                && recorder.totalOfficialSettled(address(0)) == 1000
                && ledger.counterValue(counter) == 1
                && escrow.escrowOwed(CLASS, profileId, account, address(0)) == 0,
            "identical Safe bytes pay fixed wallet once"
        );
    }
}
