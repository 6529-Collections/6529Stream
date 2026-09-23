// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    StreamCanonicalNativeSalesActivationPlan as A
} from "../../script/current/StreamCanonicalNativeSalesActivationPlan.sol";
import {
    StreamCurrentTestCanonicalSalesActivation as PaidActivation
} from "../../test/helpers/StreamCurrentTestCanonicalSalesActivation.sol";
import {
    GenesisBatch
} from "../../smart-contracts/interfaces/stream/governance/IStreamGenesisInitializer.sol";

import {
    ActualCanonicalDutchWaivedFixture,
    ActualCanonicalDutchDocumentaryFixture
} from "./ActualCanonicalDutchPurchase.t.sol";
import {
    ActualColdPurchaseExportSupport, ActualColdExportVm
} from "./ActualColdPurchaseExportSupport.t.sol";
import { IStreamNativeImmediateSales as S } from
    "../../smart-contracts/interfaces/stream/mint/IStreamNativeImmediateSales.sol";
import { IStreamNativeDutchSales as D } from
    "../../smart-contracts/interfaces/stream/mint/IStreamNativeDutchSales.sol";
import { IStreamEntropyView, StreamEntropyStatus } from
    "../../smart-contracts/interfaces/stream/entropy/IStreamEntropyView.sol";

import {
    StreamCanonicalNativeSalesDeployment as CanonicalDeployment
} from "../../script/current/StreamCanonicalNativeSalesDeployment.sol";
import {
    StreamCurrentTestCanonicalCompanions
} from "../../test/helpers/StreamCurrentTestCanonicalCompanions.sol";

import {
    IStreamCurrentTestPaidStackDeployment
} from "../../test/helpers/StreamCurrentTestPaidStackDeployment.sol";

import { ActualPaidColdPurchaseSupport } from "./ActualPaidColdPurchase.t.sol";

contract ActualPaidColdWaivedExportTest is ActualCanonicalDutchWaivedFixture, ActualPaidColdPurchaseSupport {
    function _deployCurrentStack(address artist_, address platform) internal override {
        address artistSuiteDeployment = _artistArtifactCreate(
            "test/helpers/StreamCurrentTestPaidWaivedArtistSuiteDeployment.sol:StreamCurrentTestPaidWaivedArtistSuiteDeployment",
            abi.encode()
        );
        address deployment = _artistArtifactCreate(
            "test/helpers/StreamCurrentTestPaidWaivedStackDeployment.sol:StreamCurrentTestPaidWaivedStackDeployment",
            abi.encode(artistSuiteDeployment)
        );
        (bool ok, bytes memory result) = deployment.delegatecall(
            abi.encodeCall(IStreamCurrentTestPaidStackDeployment.deployCurrentStack, (artist_, platform))
        );
        if (!ok) {
            assembly ("memory-safe") {
                revert(add(result, 32), mload(result))
            }
        }
    }
    function setUp() public override { }
    function testExportPaidColdWaivedEmpty() public { _exportCold("paid-waived-empty"); }
    function testExportPaidColdWaived128() public { paidArtworkLength = 128; _exportCold("paid-waived-128"); }
    function _deployCanonicalCompanions(CanonicalDeployment.Configuration memory c)
        internal override returns (CanonicalDeployment.Products memory)
    {
        return StreamCurrentTestCanonicalCompanions.deploy(c);
    }
    function _canonicalRegistrationBatch(A.Context memory x)
        internal view override returns (GenesisBatch memory)
    {
        return PaidActivation.registrationBatch(x);
    }

    function _canonicalRecorderCredit(A.Context memory x)
        internal view override returns (GenesisBatch memory)
    {
        return PaidActivation.recorderCredit(x);
    }

    function _canonicalRequireSettlementReady(A.Context memory x)
        internal view override
    {
        PaidActivation.requireSettlementReady(x);
    }

    function _canonicalConfigurePhase(A.Context memory x, A.Phase memory p)
        internal view override returns (A.OwnerCall memory)
    {
        return PaidActivation.configurePhase(x, p);
    }

    function _canonicalPhaseExecutor(A.Context memory x, uint8 index, uint256 collection, bytes32 phase)
        internal view override returns (A.OwnerCall memory)
    {
        return PaidActivation.phaseExecutor(x, index, collection, phase);
    }

    function _canonicalRegisterDutch(A.Context memory x, D.Configuration memory config)
        internal view override returns (A.OwnerCall memory)
    {
        return PaidActivation.registerDutch(x, config);
    }

    function _canonicalValidateOwnerCall(A.Context memory x, A.OwnerCall memory saved)
        internal view override
    {
        PaidActivation.validateOwnerCall(x, saved);
    }

    function _canonicalGoverned(A.Context memory x, A.OwnerCall memory saved)
        internal view override returns (GenesisBatch memory)
    {
        return PaidActivation.governed(x, saved);
    }

    function _coldSetup() internal override {
        ActualCanonicalDutchWaivedFixture.setUp();
        provider.setFee(PAID_FEE);
        entropy.updateRevealFeePerToken(1, PAID_FEE);
    }
    function _coldRequest() internal view override returns (S.Purchase memory) { return _actualPurchase(_paidArtwork()); }
    function _coldReleaseKey() internal pure override returns (bytes32) { return bytes32(0); }
    function _paidProvider() internal view override returns (address) { return address(provider); }
    function _coldAssert(S.Purchase memory p, S.Receipt memory r) internal view override {
        _assertActualPurchaseAccounting(p, r, PAID_EXCESS, PAID_FEE);
        _assertWaivedCommerceReceipt(address(companionRecorder), r.settlementKey);
    }
    function _coldRoles() internal view override returns (address[13] memory) {
        return [BUYER, address(companionProducts.dutch), address(core), address(manager), address(ledger),
            address(companionRecorder), address(artists), address(entropy), address(commerceFloor),
            address(executor), address(registry), address(assemblyMetadata), address(governorSafe)];
    }
}
