// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../helpers/NativeEnglishAuctionFixture.sol";
import "../../smart-contracts/integrations/delegation/NFTdelegation.sol";

/// @notice Actual current paid auction and original NFTDelegation rows, including Safe claims.
/// @dev Retains the fixture's explicit Artist/entropy/target-side governance boundaries.
contract StreamCurrentNativeAuctionDelegationTest is NativeEnglishAuctionFixture {
    address private constant VAULT = address(0xA11CE);
    address private constant OTHER_VAULT = address(0xB0B);
    bytes32 private constant RECIPIENT_PHASE = keccak256("actual auction recipient phase");
    DelegationManagementContract private delegation;
    uint256 private creationNonce;

    function _prepareHouseConfiguration(StreamNativeEnglishAuction.DeploymentConfig memory d)
        internal
        override
    {
        delegation = new DelegationManagementContract();
        d.delegateRegistry = address(delegation);
        d.delegationUsecase = 2;
        d.baseModuleManifestHash = MANIFEST;
        d.delegationGas = IStreamGasParameterHost.GasParameterConfig(
            "DELEGATE_REGISTRY_GAS_LIMIT", 150000, 50000, 2
        );
    }

    function _moduleManifest(address module) internal view override returns (bytes32) {
        return module == address(house) && module != address(0)
            ? keccak256(house.delegationManifest())
            : MANIFEST;
    }

    // Configuration, signing and creation bodies copied from the original auction-first7 test.
    function _config(bool first)
        private
        view
        returns (IStreamNativeEnglishAuction.Configuration memory c)
    {
        c.collectionId = 1;
        c.phaseId = PHASE;
        c.mintAtSettlement = true;
        c.artworkCommitment = keccak256("auction artwork");
        c.mintCommitment = keccak256("auction mint commitment");
        c.poster = address(this);
        c.reservePrice = 1000;
        c.minIncrementBps = 500;
        c.clock = StreamEnglishAuctionClock.Configuration(
            uint64(block.timestamp),
            first ? 0 : uint64(block.timestamp + 3600),
            first ? 3600 : 0,
            600,
            600,
            3600,
            first,
            false
        );
        c.expectedPrimaryPolicyHash = StreamNativeEnglishAuctionSupport.profilePolicy(resolver, 1);
        c.primaryPolicyMode = 1;
        c.settlementWindow = 86400;
        c.mintPolicyHash = manager.phasePolicyHash(1, PHASE);
    }

    function _proof(uint256 key, bytes32 digest) private returns (bytes memory) {
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(key, digest);
        return abi.encodePacked(r, s, v);
    }

    function _create(IStreamNativeEnglishAuction.Configuration memory c)
        private
        returns (bytes32 id)
    {
        IStreamNativeEnglishAuction.CreationAuthorization memory auth =
            IStreamNativeEnglishAuction.CreationAuthorization(
                house.auctionConfigurationHash(c),
                vm.addr(SIGNER_KEY),
                bytes32(++creationNonce),
                uint64(block.timestamp + 1000)
            );
        bytes32 digest = house.creationAuthorizationDigest(auth);
        return house.registerAuction(
            c,
            bytes("auction artwork"),
            auth,
            _proof(AUCTION_PLATFORM_KEY, digest),
            _proof(SIGNER_KEY, digest)
        );
    }

    function _w(uint256 index)
        private
        pure
        returns (IStreamNativeAuctionDelegatedDelivery.DelegationWitness memory)
    {
        return IStreamNativeAuctionDelegatedDelivery.DelegationWitness(false, index);
    }

    function _grant(address vault, address delegate, uint256 expiry, bool allTokens) private {
        vm.prank(vault);
        delegation.registerDelegationAddress(
            address(core), delegate, expiry, 2, allTokens, allTokens ? 0 : 7
        );
    }

    function _revoke(address vault, address delegate) private {
        vm.prank(vault);
        delegation.revokeDelegationAddress(address(core), delegate, 2);
    }

    function _end(bytes32 id) private {
        (uint64 end,,,) = house.auctionDeadlines(id);
        vm.warp(end);
    }

    function _bid(bytes32 id, address bidder, uint256 amount) private {
        vm.deal(bidder, 1 ether);
        uint256 value = amount + entropy.fee();
        vm.prank(bidder);
        house.bid{ value: value }(id, address(0));
        IStreamNativeEnglishAuction.WinningBid memory winner = house.auction(id).winner;
        require(
            winner.payer == bidder && winner.executor == bidder && winner.deliverTo == bidder,
            "actual requested public bidder"
        );
    }

    function _recipientCounter(address recipient) private view returns (uint256) {
        bytes32 subject = manager.previewSubjectKey(
            IStreamMintManager.CounterKeyMode.RECIPIENT,
            1,
            RECIPIENT_PHASE,
            COUNTER,
            payer,
            recipient,
            address(house),
            address(0),
            0
        );
        return ledger.counterValue(
            ledger.deriveCounterValueKey(address(manager), 1, RECIPIENT_PHASE, COUNTER, subject)
        );
    }

    function _configureRecipientCounter() private {
        bytes32[] memory ids = new bytes32[](1);
        ids[0] = COUNTER;
        IStreamMintManager.MintCounterConfig[] memory counters =
            new IStreamMintManager.MintCounterConfig[](1);
        counters[0] = IStreamMintManager.MintCounterConfig(
            true,
            IStreamMintManager.CounterKeyMode.RECIPIENT,
            IStreamMintLedger.CounterCapMode.STATIC,
            IStreamMintLedger.CounterDeltaMode.STATIC,
            10,
            1,
            keccak256("counter")
        );
        IStreamMintManager.MintGateConfig memory gate;
        manager.configurePhase(
            1,
            RECIPIENT_PHASE,
            IStreamMintManager.MintPhaseConfig(false, 0, 0, 1, MANIFEST, MANIFEST),
            gate,
            ids,
            counters
        );
        manager.setPhaseExecutor(1, RECIPIENT_PHASE, address(house), true);
    }

    function testVaultBindingSurvivesRevocationAndSettlementUsesVaultCounterButPayerCredits()
        public
    {
        bytes memory declaration = abi.encode(
            keccak256("6529STREAM_NATIVE_AUCTION_NFTDELEGATION_MANIFEST_V1"),
            block.chainid,
            address(house),
            MANIFEST,
            address(core),
            address(delegation),
            address(delegation).codehash,
            uint256(2)
        );
        require(
            house.supportsInterface(type(IStreamNativeAuctionDelegatedDelivery).interfaceId)
                && keccak256(house.delegationManifest()) == keccak256(declaration)
                && registry.moduleRecord(address(house)).moduleManifestHash
                    == keccak256(declaration),
            "actual registered declaration"
        );
        _configureRecipientCounter();
        IStreamNativeEnglishAuction.Configuration memory c = _config(true);
        c.phaseId = RECIPIENT_PHASE;
        c.mintPolicyHash = manager.phasePolicyHash(1, RECIPIENT_PHASE);
        bytes32 id = _create(c);
        bytes32 saleId = house.auction(id).saleId;
        _grant(VAULT, payer, block.timestamp + 100000, true);
        vm.recordLogs();
        vm.prank(payer);
        house.bidForVault{ value: 1100 }(id, VAULT, _w(0));
        Vm.Log[] memory logs = vm.getRecordedLogs();
        uint256 found;
        for (uint256 j; j < logs.length; ++j) {
            if (
                logs[j].emitter == address(house) && logs[j].topics.length == 4
                    && logs[j].topics[0]
                        == keccak256("AuctionBidDeliveryBound(bytes32,bytes32,address,address)")
            ) {
                require(
                    logs[j].topics[1] == id && logs[j].topics[2] == saleId
                        && logs[j].topics[3] == bytes32(uint256(uint160(payer)))
                        && keccak256(logs[j].data) == keccak256(abi.encode(VAULT)),
                    "complete binding event"
                );
                ++found;
            }
        }
        require(found == 1 && house.bidDelivery(id, payer) == VAULT, "one immutable binding");
        _revoke(VAULT, payer);
        vm.etch(address(delegation), hex"00");
        vm.prank(payer);
        house.bid{ value: 1200 }(id, VAULT);
        require(
            house.refundableBalance(saleId, payer) == 1100
                && house.refundableBalance(saleId, VAULT) == 0,
            "outbid credit belongs to payer"
        );
        entropy.configure(50, 0, false, true);
        _end(id);
        (uint256 token,) = house.settle(id);
        require(
            core.ownerOf(token) == VAULT && _recipientCounter(VAULT) == 1
                && _recipientCounter(payer) == 0,
            "actual prepared beneficiary is vault"
        );
        require(
            wallet.balance == 1100 && entropy.revealFeeEscrow(1) == 50
                && house.refundableBalance(saleId, payer) == 1150
                && house.refundableBalance(saleId, VAULT) == 0
                && house.totalBuyerLiabilities() == 1150,
            "exact original and fee credits"
        );
        vm.prank(address(0xA11));
        house.pauseAdapter(keccak256("claims remain callable"));
        uint256 before = OTHER_VAULT.balance;
        vm.prank(payer);
        require(house.claimRefund(saleId, payable(OTHER_VAULT)) == 1150, "own escape");
        require(
            OTHER_VAULT.balance == before + 1150 && house.totalBuyerLiabilities() == 0
                && address(house).balance == 0,
            "own redirect independent of lost registry"
        );
    }

    function testSignedVaultBidRejectsMissingExpiredAndTokenRowsThenIdenticalSignatureSucceeds()
        public
    {
        bytes32 id = _create(_config(true));
        IStreamNativeEnglishAuction.BidAuthorization memory a =
            IStreamNativeEnglishAuction.BidAuthorization(
                id,
                house.auction(id).configHash,
                payer,
                address(this),
                VAULT,
                1000,
                100,
                bytes32(uint256(1)),
                uint64(block.timestamp + 1000),
                uint64(block.timestamp + 3600 + 86400)
            );
        bytes memory signature = _proof(PAYER_KEY, house.bidAuthorizationDigest(a));
        vm.deal(address(this), 1 ether);
        bytes memory data = abi.encodeCall(house.bidSignedForVault, (a, signature, _w(0)));
        (bool ok,) = address(house).call{ value: 1100 }(data);
        require(
            !ok && house.auction(id).winner.amount == 0
                && house.bidDelivery(id, payer) == address(0) && house.totalBuyerLiabilities() == 0
                && address(house).balance == 0,
            "missing row atomic"
        );
        _grant(VAULT, payer, block.timestamp + 100000, false);
        (ok,) = address(house).call{ value: 1100 }(data);
        require(!ok, "token grant is not vault delivery authority");
        _grant(VAULT, payer, block.timestamp, true);
        (ok,) = address(house).call{ value: 1100 }(
            abi.encodeCall(house.bidSignedForVault, (a, signature, _w(1)))
        );
        require(!ok, "expiry equality rejects");
        _grant(VAULT, payer, block.timestamp + 100000, true);
        (ok,) = address(house).call{ value: 1100 }(
            abi.encodeCall(house.bidSignedForVault, (a, signature, _w(3)))
        );
        require(
            !ok && house.totalBuyerLiabilities() == 0 && house.auction(id).clock.nominalEnd == 0,
            "wrong row no nonce/clock write"
        );
        house.bidSignedForVault{ value: 1100 }(a, signature, _w(2));
        require(
            house.auction(id).winner.authorizationDigest == house.bidAuthorizationDigest(a)
                && house.auction(id).winner.executor == address(this)
                && house.bidDelivery(id, payer) == VAULT,
            "same original signed authorization"
        );
        (ok,) = address(house).call{ value: 1100 }(
            abi.encodeCall(house.bidSignedForVault, (a, signature, _w(2)))
        );
        require(!ok && house.totalBuyerLiabilities() == 1100, "signed replay rejects");
        _grant(OTHER_VAULT, payer, block.timestamp + 100000, true);
        vm.prank(payer);
        (ok,) = address(house).call{ value: 1200 }(
            abi.encodeCall(house.bidForVault, (id, OTHER_VAULT, _w(0)))
        );
        require(
            !ok && house.bidDelivery(id, payer) == VAULT && house.auction(id).winner.amount == 1000,
            "fresh grant cannot redirect original"
        );
        _end(id);
        (uint256 token,) = house.settle(id);
        require(
            core.ownerOf(token) == VAULT && house.auction(id).winner.executor == address(this),
            "permissionless original-executor settlement"
        );
    }

    function testSafeDelegatedRefundRequiresLiveGrantAndSameSignedFailureRetriesOnlyToPayer()
        public
    {
        bytes32 id = _create(_config(true));
        _bid(id, payer, 1000);
        _bid(id, OTHER_VAULT, 1100);
        bytes32 saleId = house.auction(id).saleId;
        uint256[] memory keys = new uint256[](2);
        keys[0] = 0x5AFE81;
        keys[1] = 0x5AFE82;
        OfficialSafe safe =
            createOfficialSafe(deploySafeComponents("1.4.1"), safeOwnerAddresses(keys), 2, 881);
        _grant(payer, address(safe), block.timestamp + 100000, true);
        _revoke(payer, address(safe));
        bytes memory data = abi.encodeCall(house.claimRefundFor, (saleId, payer, _w(0)));
        uint256 nonce = safe.nonce();
        bytes32 hash = safe.getTransactionHash(
            address(house), 0, data, 0, 0, 0, 0, address(0), address(0), nonce
        );
        bytes memory txData = abi.encodeCall(
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
                safeThresholdSignature(keys, hash)
            )
        );
        uint256 balance = payer.balance;
        (bool ok,) = address(safe).call(txData);
        require(
            !ok && safe.nonce() == nonce && payer.balance == balance
                && house.refundableBalance(saleId, payer) == 1100
                && house.totalBuyerLiabilities() == 2300,
            "failed Safe claim rolls back original credit and nonce"
        );
        _grant(payer, address(safe), block.timestamp + 100000, true);
        vm.prank(address(0xA11));
        house.pauseAdapter(keccak256("claim during pause"));
        _status(address(house), ModuleRegistryStatus.DEPRECATED);
        bytes memory result;
        (ok, result) = address(safe).call(txData);
        require(
            ok && result.length == 32 && abi.decode(result, (bool)) && safe.nonce() == nonce + 1,
            "identical signed Safe transaction retries"
        );
        require(
            payer.balance == balance + 1100 && address(safe).balance == 0
                && house.refundableBalance(saleId, payer) == 0
                && house.totalBuyerLiabilities() == 1200 && address(house).balance == 1200,
            "delegate cannot redirect credits or touch live winner deposit"
        );
        require(safe.getThreshold() == 2 && safe.getOwners().length == 2, "Safe authority retained");
        (ok,) = address(safe).call(txData);
        require(
            !ok && safe.nonce() == nonce + 1 && payer.balance == balance + 1100,
            "Safe transaction replay rejects"
        );
    }

    function testDelegatedNFTClaimChecksOriginalVaultAndLiveGrantWhileOwnEscapeIgnoresRegistry()
        public
    {
        NativeAuctionReceiver vault = new NativeAuctionReceiver();
        vault.configure(true, false, address(0), "", address(0));
        bytes32 id = _create(_config(true));
        _grant(address(vault), payer, block.timestamp + 100000, true);
        vm.prank(payer);
        house.bidForVault{ value: 1100 }(id, address(vault), _w(0));
        _end(id);
        (uint256 token,) = house.settle(id);
        require(
            core.ownerOf(token) == address(house)
                && house.auction(id).nftClaimant == address(vault),
            "failed delivery preserves original vault claim"
        );
        _revoke(address(vault), payer);
        vm.prank(payer);
        (bool ok,) =
            address(house).call(abi.encodeCall(house.claimNFTFor, (id, address(vault), _w(0))));
        require(
            !ok && house.auction(id).nftClaimant == address(vault),
            "revoked trigger cannot consume claim"
        );
        _grant(address(vault), payer, block.timestamp + 100000, true);
        vm.prank(payer);
        (ok,) = address(house).call(abi.encodeCall(house.claimNFTFor, (id, payer, _w(0))));
        require(!ok && core.ownerOf(token) == address(house), "claimant substitution rejects");
        vault.configure(
            false,
            false,
            address(house),
            abi.encodeCall(house.claimNFTFor, (id, address(vault), _w(0))),
            address(0)
        );
        vm.prank(payer);
        house.claimNFTFor(id, address(vault), _w(0));
        require(
            core.ownerOf(token) == address(vault) && house.auction(id).nftClaimant == address(0)
                && vault.callbackRejected(),
            "exact vault delivery with guarded callback"
        );
        vault.configure(true, false, address(0), "", address(0));
        bytes32 second = _create(_config(true));
        vm.prank(payer);
        house.bidForVault{ value: 1100 }(second, address(vault), _w(0));
        _end(second);
        (uint256 token2,) = house.settle(second);
        vm.etch(address(delegation), hex"00");
        vm.prank(address(0xA11));
        house.pauseAdapter(keccak256("own NFT escape"));
        vault.callTarget(address(house), 0, abi.encodeCall(house.claimNFT, (second, OTHER_VAULT)));
        require(
            core.ownerOf(token2) == OTHER_VAULT && house.auction(second).nftClaimant == address(0)
                && recorder.totalOfficialSettled(address(0)) == 2000,
            "own redirected claim has no new delegation/payment"
        );
    }
}
