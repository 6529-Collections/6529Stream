// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "../../helpers/NativeSupplementalTestBase.sol";

contract StreamNativeSupplementalAdversarialTest is NativeSupplementalTestBase {
    function _reject(
        StreamNativeSupplementalTypes.NativeSupplementalCandidate memory c,
        uint256 value
    ) private {
        (bool ok,) =
            address(clearing).call{ value: value }(abi.encodeCall(clearing.supplement, (c)));
        require(!ok, "must reject");
    }

    function testBoundedFactsAndLatchMalformedMatrixWithHealthySameCandidate() external {
        StreamNativeSupplementalTypes.NativeSupplementalCandidate memory c = _floor(1);
        for (uint256 i = 1; i <= 6; ++i) {
            clearing.configureFault(i, 0, true);
            _reject(c, 2000);
            _unchanged(c, 0, 1000);
        }
        for (uint256 i = 1; i <= 3; ++i) {
            clearing.configureFault(0, i, true);
            _reject(c, 2000);
            _unchanged(c, 0, 1000);
        }
        clearing.configureFault(0, 0, false);
        _reject(c, 2000);
        _unchanged(c, 0, 1000);
        clearing.configureFault(0, 0, true);
        _submit(c);
        require(wallet.balance == 3000, "same candidate healthy control");
    }

    function testOriginalReceiptDigestOperationAndIdentityCannotBeRewritten() external {
        StreamNativeSupplementalTypes.NativeSupplementalCandidate memory good = _floor(1);
        for (uint256 i; i < 7; ++i) {
            StreamNativeSupplementalTypes.NativeSupplementalCandidate memory c = abi.decode(
                abi.encode(good), (StreamNativeSupplementalTypes.NativeSupplementalCandidate)
            );
            if (i == 0) c.originalFloor.currentPolicyHash = keccak256("new mint policy");
            if (i == 1) c.originalFloor.rights.profileId = keccak256("new original profile");
            if (i == 2) c.purchase.originalOperationId = keccak256("other operation");
            if (i == 3) c.purchase.originalAuthorizationDigest = keccak256("other digest");
            if (i == 4) c.purchase.floorCandidateCommitment = keccak256("other commitment");
            if (i == 5) c.purchase.floorSettlementKey = keccak256("unfunded floor");
            if (i == 6) c.purchase.tokenId = 99;
            clearing.replaceFacts(c.purchaseId, c.purchase);
            _reject(c, 2000);
            _unchanged(good, 0, 1000);
        }
        clearing.replaceFacts(good.purchaseId, good.purchase);
        _submit(good);
        require(wallet.balance == 3000, "original record control");
    }

    function testPriceOverrideUsesBuyerUniformAndInvalidMaximaRollback() external {
        StreamNativeSupplementalTypes.NativeSupplementalCandidate memory c = _floor(1);
        c.purchase.hasPriceOverride = true;
        c.purchase.priceOverride = 2000;
        c.purchase.buyerUniformPrice = 2000;
        clearing.replaceFacts(c.purchaseId, c.purchase);
        _reject(c, 2000);
        _unchanged(c, 0, 1000);
        c.purchase.buyerUniformPrice = 3000;
        clearing.replaceFacts(c.purchaseId, c.purchase);
        _reject(c, 2000);
        _unchanged(c, 0, 1000);
        c.purchase.priceOverride = 999;
        c.purchase.buyerUniformPrice = 999;
        clearing.replaceFacts(c.purchaseId, c.purchase);
        _reject(c, 0);
        _unchanged(c, 0, 1000);
        c.purchase.priceOverride = 2000;
        c.purchase.buyerUniformPrice = 2000;
        clearing.replaceFacts(c.purchaseId, c.purchase);
        StreamNativeSupplementalTypes.NativeSupplementalResult memory result = _submit(c);
        require(
            result.amount == 1000 && wallet.balance == 2000,
            "buyer min override not global difference"
        );
    }

    function testZeroStatusDeadlineAndPaidPriceBoundaries() external {
        StreamNativeSupplementalTypes.NativeSupplementalCandidate memory good = _floor(1);
        for (uint256 i; i < 6; ++i) {
            StreamNativeSupplementalTypes.NativeSupplementalCandidate memory c = abi.decode(
                abi.encode(good), (StreamNativeSupplementalTypes.NativeSupplementalCandidate)
            );
            if (i == 0) c.purchase.status = 0;
            if (i == 1) c.purchase.status = 2;
            if (i == 2) c.purchase.paidPrice = 2999;
            if (i == 3) c.purchase.effectiveFinalizeBy = 999;
            if (i == 4) {
                c.purchase.globalClearingPrice = 1000;
                c.purchase.buyerUniformPrice = 1000;
            }
            if (i == 5) c.purchase.priceOverride = 1;
            clearing.replaceFacts(c.purchaseId, c.purchase);
            _reject(c, i == 4 ? 0 : 2000);
            _unchanged(good, 0, 1000);
        }
        clearing.replaceFacts(good.purchaseId, good.purchase);
        vm.warp(good.purchase.effectiveFinalizeBy);
        _submit(good);
        require(wallet.balance == 3000, "inclusive deadline");
    }

    function testRootUsedAndCollectionMappingAreIndependentRequiredFacts() external {
        StreamNativeSupplementalTypes.NativeSupplementalCandidate memory c = _floor(1);
        supplementalCore.setIdentity(1, 2, false);
        _reject(c, 2000);
        _unchanged(c, 0, 1000);
        supplementalCore.setIdentity(1, 1, false);
        uint256 snapshot = vm.snapshotState();
        supplementalManager.clearRoot(c.originalFloor.operationIdentityCommitment);
        _reject(c, 2000);
        _unchanged(c, 0, 1000);
        require(vm.revertToState(snapshot));
        _submit(c);
        require(wallet.balance == 3000, "restored exact root and token");
    }

    function testStablePurchaseLaneRejectsChangedPolicyAndExecutor() external {
        StreamNativeSupplementalTypes.NativeSupplementalCandidate memory c = _floor(1);
        _submit(c);
        c.executor = address(0xCAFE);
        c.currentPrimaryPolicyHash = keccak256("changed policy");
        bytes32 purchaseKey = recorder.supplementalPurchaseKey(address(clearing), c.purchaseId);
        require(!recorder.settlementConsumed(_key(c)), "new computed official key");
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamNativeSupplementalSettlement.SupplementalPurchaseAlreadyConsumed.selector,
                purchaseKey
            )
        );
        _submit(c);
        require(
            wallet.balance == 3000 && recorder.totalOfficialSettled(address(0)) == 3000,
            "no second economic execution"
        );
    }

    function testEscrowFailureRollsBackEveryLaneAndExactRetryPreservesSurplus() external {
        StreamNativeSupplementalTypes.NativeSupplementalCandidate memory c = _floor(1);
        vm.deal(address(recorder), 77);
        _producer(false);
        SaleFundingFaultVm(address(vm))
            .mockCallRevert(
                wallet, 2000, "", abi.encodeWithSignature("Error(string)", "injected wallet fault")
            );
        _reject(c, 2000);
        _unchanged(c, 0, 1000);
        require(address(recorder).balance == 77, "surplus unchanged");
        _producer(true);
        StreamNativeSupplementalTypes.NativeSupplementalResult memory result = _submit(c);
        require(
            result.escrowed && wallet.balance == 1000
                && escrow.escrowOwed(CLASS, profile, wallet, address(0)) == 2000,
            "exact original owed"
        );
        require(
            address(recorder).balance == 77 && supplementalManager.nonce() == 1,
            "surplus and no mint"
        );
        SaleFundingFaultVm(address(vm)).clearMockedCalls();
        escrow.flushEscrow(CLASS, profile, wallet, address(0));
        require(
            wallet.balance == 3000 && escrow.escrowOwed(CLASS, profile, wallet, address(0)) == 0,
            "real escrow flush"
        );
    }

    function testDeprecatedAfterCreationAllowsAccruedFinancialLegButIncidentRejects() external {
        StreamNativeSupplementalTypes.NativeSupplementalCandidate memory c = _floor(1);
        vm.warp(1001);
        _status(address(clearing), ModuleRegistryStatus.DEPRECATED);
        uint256 snapshot = vm.snapshotState();
        _status(address(clearing), ModuleRegistryStatus.INCIDENT_REVOKED);
        _reject(c, 2000);
        _unchanged(c, 0, 1000);
        require(vm.revertToState(snapshot));
        _submit(c);
        require(wallet.balance == 3000, "retained lifecycle");
    }

    function testFuzzBuyerUniformConservesEveryWei(
        uint96 globalRaw,
        uint96 overrideRaw,
        bool overrideEnabled
    ) external {
        StreamNativeSupplementalTypes.NativeSupplementalCandidate memory c = _floor(1);
        uint256 global = 1001 + uint256(globalRaw) % 100_000;
        uint256 ceiling = 1001 + uint256(overrideRaw) % 100_000;
        c.purchase.globalClearingPrice = global;
        c.purchase.hasPriceOverride = overrideEnabled;
        c.purchase.priceOverride = overrideEnabled ? ceiling : 0;
        uint256 uniform = overrideEnabled && ceiling < global ? ceiling : global;
        c.purchase.buyerUniformPrice = uniform;
        c.purchase.paidPrice = 200_000;
        clearing.replaceFacts(c.purchaseId, c.purchase);
        uint256 before = address(this).balance;
        StreamNativeSupplementalTypes.NativeSupplementalResult memory result = _submit(c);
        require(
            result.amount == uniform - 1000 && address(this).balance == before - (uniform - 1000),
            "exact chosen delta"
        );
        require(
            wallet.balance == uniform && recorder.totalOfficialSettled(address(0)) == uniform,
            "floor plus supplement"
        );
    }
}
