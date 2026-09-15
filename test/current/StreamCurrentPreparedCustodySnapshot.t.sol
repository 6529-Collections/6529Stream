// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../helpers/NativePreparedCustodySnapshotFixture.sol";

interface PreparedCustodyFaultVm {
    function mockCallRevert(address target, uint256 value, bytes calldata data, bytes calldata result) external;
    function expectCall(address target, uint256 value, bytes calldata data) external;
    function clearMockedCalls() external;
}

contract StreamCurrentPreparedCustodySnapshotTest is NativePreparedCustodySnapshotFixture {
    PreparedCustodyFaultVm private constant faults = PreparedCustodyFaultVm(address(uint160(uint256(keccak256("hevm cheat code")))));

    function testPreparedCustodySnapshotsOriginalAcquisitionAndPaidTransferNeverMintsAgain() public {
        PreparedPlan memory p = _preparedCustodyPlan(address(this));
        bytes32 digest = house.preparedCustodyAcquisitionDigest(p.authorization);
        bytes32 domain = keccak256(abi.encode(
            keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"),
            keccak256("6529StreamPreparedNativeCustodyAuction"), keccak256("1"), block.chainid, address(house)));
        bytes32 expected = keccak256(abi.encodePacked(hex"1901", domain, keccak256(abi.encode(
            keccak256("PreparedNativeCustodyAcquisition(bytes32 configHash,bytes32 tokenDataHash,uint256 expectedSaleNonce,uint256 expectedTokenId,uint256 expectedCollectionSerial,uint256 expectedOperationNonce,bytes32 contextHash,address executor,uint256 revealFeeDeposit,address artist,bytes32 nonce,uint64 deadline)"), p.authorization))));
        require(digest == expected && digest != house.custodyAcquisitionDigest(p.authorization), "complete prepared domain and original legacy separation");
        vm.recordLogs();
        bytes32 id = house.registerPreparedCustodyAuction{value: 150}(
            p.config, p.authorization, p.artwork, p.platformSignature, p.artistSignature);
        Vm.Log[] memory logs = vm.getRecordedLogs();
        StreamNativeCustodySettlementTypes.Origin memory origin = house.custodyOrigin(id);
        IStreamRoyaltySnapshot.Snapshot memory snapshot = _assertSnapshot(1);
        require(origin.eligible && core.ownerOf(1) == address(house) && snapshot.operationRoot == origin.operationRoot
            && snapshot.operationId == origin.operationId && origin.authorizationId == digest
            && origin.tokenDataHash == p.authorization.tokenDataHash && origin.operationNonce == 0
            && manager.nextOperationNonce() == 1 && _preparedCustodyCounter(p) == 1
            && entropy.revealFeeEscrow(1) == 100 && origin.revealFeeForwarded == 100
            && house.refundableBalance(house.auction(id).saleId, address(this)) == 50
            && recorder.totalOfficialSettled(address(0)) == 0 && wallet.balance == 0,
            "unpaid actual prepared custody with separate operator reveal remainder");
        uint256 found;
        bytes32 topic = keccak256("NativeAuctionPreparedCustodyBound(uint16,bytes32,uint256,bytes32,bytes32,bytes32)");
        for (uint256 i; i < logs.length; ++i) {
            if (logs[i].emitter == address(house) && logs[i].topics.length == 4 && logs[i].topics[0] == topic) {
                require(logs[i].topics[1] == id && uint256(logs[i].topics[2]) == 1 && logs[i].topics[3] == origin.operationRoot
                    && keccak256(logs[i].data) == keccak256(abi.encode(uint16(1), origin.operationId, digest)),
                    "full prepared custody event joins original operation and authority");
                ++found;
            }
        }
        require(found == 1, "one prepared custody binding");
        vm.prank(payer); house.bid{value: 1000}(id, address(0));
        require(house.auction(id).winner.revealFee == 0, "paid custody bid never duplicates reveal funding");
        (uint64 end,,,) = house.auctionDeadlines(id); vm.warp(end);
        (uint256 token, bytes32 key) = house.settle(id);
        StreamPrimarySettlementTypes.PrimarySettlementResult memory result = recorder.settlementResult(key);
        require(token == 1 && core.ownerOf(1) == payer && wallet.balance == 1000 && result.amount == 1000
            && result.operationIdentityCommitment == 0 && result.currentPolicyHash == 0 && result.boundPolicyHash == 0
            && manager.nextOperationNonce() == 1 && core.collectionNextSerial(1) == 2 && _preparedCustodyCounter(p) == 1
            && !house.custodyOrigin(id).eligible && keccak256(abi.encode(royalty.royaltySnapshot(1))) == keccak256(abi.encode(snapshot)),
            "official paid transfer preserves original snapshot and consumes no new mint");
    }

    function testPreparedCustodySignaturesCannotSubstituteLegacyEntryAndOriginalNonceCannotReplay() public {
        PreparedPlan memory p = _preparedCustodyPlan(address(this));
        bytes memory preparedCall = _preparedCustodyCall(p);
        (bool ok,) = address(house).call{value: 150}(abi.encodeCall(house.registerCustodyAuction,
            (p.config, p.authorization, p.artwork, p.platformSignature, p.artistSignature)));
        require(!ok && core.lastAllocatedTokenId() == 0 && _preparedCustodyCounter(p) == 0, "new signature cannot select old path");
        bytes32 legacyDigest = house.custodyAcquisitionDigest(p.authorization);
        bytes memory oldPlatform = _sig(AUCTION_PLATFORM_KEY, legacyDigest);
        bytes memory oldArtist = _sig(SIGNER_KEY, legacyDigest);
        (ok,) = address(house).call{value: 150}(abi.encodeCall(house.registerPreparedCustodyAuction,
            (p.config, p.authorization, p.artwork, oldPlatform, oldArtist)));
        require(!ok && core.lastAllocatedTokenId() == 0, "old signature cannot select prepared path");
        bytes memory legacyCall = abi.encodeCall(house.registerCustodyAuction,
            (p.config, p.authorization, p.artwork, oldPlatform, oldArtist));
        bytes memory reason;
        (ok, reason) = address(house).call{value: 150}(legacyCall);
        require(!ok && keccak256(reason) == keccak256(abi.encodeWithSelector(
            IStreamMintRoyaltyPolicy.PreparedRoyaltySnapshotRequired.selector, uint256(1)))
            && manager.nextOperationNonce() == 0 && !royalty.royaltySnapshot(1).exists,
            "authorized original single-step acquisition stays closed for snapshot mode");
        (ok,) = address(house).call{value: 150}(preparedCall); require(ok, "original prepared call succeeds");
        (ok,) = address(house).call{value: 150}(preparedCall); require(!ok, "same prepared authorization cannot replay");
        (ok,) = address(house).call{value: 150}(legacyCall); require(!ok, "shared creator nonce prevents cross-entry replay");
        require(manager.nextOperationNonce() == 1 && _preparedCustodyCounter(p) == 1 && core.lastAllocatedTokenId() == 1, "one acquisition only");
        PreparedPlan memory fresh = _preparedCustodyPlan(address(this));
        require(fresh.authorization.expectedTokenId == 2 && fresh.authorization.expectedCollectionSerial == 2
            && fresh.authorization.expectedOperationNonce == 1 && fresh.authorization.expectedSaleNonce == 2
            && fresh.authorization.nonce == p.authorization.nonce, "all current coordinates with the original consumed creator nonce");
        (ok, reason) = address(house).call{value: 150}(_preparedCustodyCall(fresh));
        require(!ok && keccak256(reason) == keccak256(abi.encodeWithSelector(IStreamNativeCustodyAuction.InvalidNativeCustody.selector))
            && manager.nextOperationNonce() == 1 && !royalty.royaltySnapshot(2).exists,
            "freshly authorized coordinates cannot reuse consumed creator nonce");
        fresh.authorization.nonce = keccak256("second independent prepared custody creator nonce");
        bytes32 freshDigest = house.preparedCustodyAcquisitionDigest(fresh.authorization);
        fresh.platformSignature = _sig(AUCTION_PLATFORM_KEY, freshDigest);
        fresh.artistSignature = _sig(SIGNER_KEY, freshDigest);
        (ok,) = address(house).call{value: 150}(_preparedCustodyCall(fresh));
        require(ok && manager.nextOperationNonce() == 2 && _preparedCustodyCounter(fresh) == 2
            && core.ownerOf(2) == address(house) && royalty.royaltySnapshot(2).exists,
            "otherwise identical current acquisition succeeds with an independent creator nonce");
    }

    function testSafePreparedCustodyLateRevealFailureRollsBackSnapshotAndExactSignedRetry() public {
        uint256[] memory keys = new uint256[](2); keys[0] = 0x661; keys[1] = 0x662;
        OfficialSafe safe = createOfficialSafe(deploySafeComponents("1.4.1"), safeOwnerAddresses(keys), 2, 5152);
        vm.deal(address(safe), 1 ether);
        PreparedPlan memory p = _preparedCustodyPlan(address(safe));
        bytes memory data = _preparedCustodyCall(p);
        bytes32 hash = safe.getTransactionHash(address(house), 150, data, 0, 0, 0, 0, address(0), address(0), 0);
        bytes memory proof = safeThresholdSignature(keys, hash);
        bytes memory originalSafeCall = abi.encodeCall(safe.execTransaction,
            (address(house), uint256(150), data, uint8(0), uint256(0), uint256(0), uint256(0), address(0), payable(address(0)), proof));
        bytes memory funding = abi.encodeCall(entropy.fundRevealFeeEscrow, (uint256(1)));
        faults.mockCallRevert(address(entropy), 100, funding, bytes("actual late reveal funding fails"));
        faults.expectCall(address(entropy), 100, funding);
        (bool ok,) = address(safe).call(originalSafeCall);
        require(!ok && safe.nonce() == 0 && address(safe).balance == 1 ether && core.lastAllocatedTokenId() == 0
            && core.collectionNextSerial(1) == 1 && manager.nextOperationNonce() == 0 && _preparedCustodyCounter(p) == 0
            && !royalty.royaltySnapshot(1).exists && address(house).balance == 0 && entropy.revealFeeEscrow(1) == 0,
            "failure after actual prepared completion restores Safe mint snapshot counter and value");
        faults.clearMockedCalls();
        (ok,) = address(safe).call(originalSafeCall);
        require(ok && safe.nonce() == 1 && safe.getThreshold() == 2 && address(safe).balance == 1 ether - 150
            && manager.nextOperationNonce() == 1 && _preparedCustodyCounter(p) == 1 && core.ownerOf(1) == address(house)
            && entropy.revealFeeEscrow(1) == 100 && royalty.royaltySnapshot(1).exists,
            "identical signed Safe call acquires original snapshot exactly once");
    }
}
