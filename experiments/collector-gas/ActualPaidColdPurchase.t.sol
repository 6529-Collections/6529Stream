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

interface PaidProviderView {
    function fee() external view returns (uint256);
    function nextRequestId() external view returns (uint256);
    function fulfill(uint256 id, bytes32 raw) external returns (uint8);
}

interface PaidEntropyAccounting {
    function revealFeeEscrow(uint256 collectionId) external view returns (uint256);
    function totalRevealFeeEscrows() external view returns (uint256);
    function pendingRequestCount() external view returns (uint256);
}

/// @notice Successor discovery recipe. Gas is measured only by replaying complete cold transactions.
/// @dev Retains actual Core/Manager/Ledger/Artist/Recorder/Floor/official plural Dutch routing.
/// Only the existing external entropy provider is a test double. Nothing bypasses original setup.
abstract contract ActualPaidColdPurchaseSupport is ActualColdPurchaseExportSupport {
    ActualColdExportVm private constant paidVm =
        ActualColdExportVm(address(uint160(uint256(keccak256("hevm cheat code")))));
    uint256 internal constant PAID_FEE = 10;
    uint256 internal constant PAID_EXCESS = 500;
    bytes32 private constant RAW_RANDOMNESS = keccak256("actual paid cold purchase provider result");
    uint256 internal paidArtworkLength;

    struct Read { address target; bytes data; bytes result; }
    struct Balance { address account; uint256 amount; }
    struct Step {
        address sender;
        address target;
        uint256 value;
        bytes data;
        bytes result;
        Read[] post;
        Balance[] balances;
    }

    function _paidProvider() internal view virtual returns (address);

    function _coldValue() internal pure override returns (uint256) {
        return 1000 + PAID_FEE + PAID_EXCESS;
    }

    function _paidArtwork() internal view returns (bytes memory data) {
        data = new bytes(paidArtworkLength);
        for (uint256 i; i < data.length; ++i) data[i] = bytes1(uint8(i + 1));
    }

    function _coldExtraProbes(address[13] memory a, S.Purchase memory p, S.Receipt memory r)
        internal view override returns (Probe[] memory probes)
    {
        probes = new Probe[](9);
        probes[0] = _probe(a, 1, abi.encodeWithSignature("refundableBalance(bytes32,address)", p.saleId, a[0]));
        probes[1] = _probe(a, 1, abi.encodeWithSignature("refundLiability()"));
        probes[2] = _probe(a, 1, abi.encodeWithSignature("refundAccountCount()"));
        probes[3] = _probe(a, 7, abi.encodeWithSignature("collectionRevealPolicy(uint256)", uint256(1)));
        probes[4] = _probe(a, 7, abi.encodeWithSignature("revealFeeEscrow(uint256)", uint256(1)));
        probes[5] = _probe(a, 7, abi.encodeWithSignature("totalRevealFeeEscrows()"));
        probes[6] = _probe(a, 7, abi.encodeWithSignature("tokenEntropyStatus(uint256)", r.tokenId));
        probes[7] = _probe(a, 7, abi.encodeWithSignature("pendingRequestCount()"));
        probes[8] = _probe(a, 1, abi.encodeWithSignature("saleRevealQuote(bytes32)", p.saleId));
    }

    function _coldAfterDiscovery(string memory label, S.Purchase memory p, S.Receipt memory r)
        internal override
    {
        address[13] memory a = _coldRoles();
        address externalProvider = _paidProvider();
        require(paidArtworkLength == 0 || paidArtworkLength == 128, "reviewed artwork cases");
        require(r.chargedAmount == 1000 && r.revealFee == PAID_FEE && r.revealCredit == PAID_EXCESS,
            "complete paid accounting tuple");
        require(D(a[1]).saleRevealQuote(p.saleId).policy.revealFeePerTokenWei == PAID_FEE,
            "original captured live reveal fee");
        require(PaidProviderView(externalProvider).fee() == PAID_FEE
            && PaidProviderView(externalProvider).nextRequestId() == 2
            && externalProvider.balance == PAID_FEE,
            "provider request and exact transfer actually succeeded");
        PaidEntropyAccounting accounting = PaidEntropyAccounting(a[7]);
        require(accounting.revealFeeEscrow(1) == 0 && accounting.totalRevealFeeEscrows() == 0
            && accounting.pendingRequestCount() == 1
            && IStreamEntropyView(a[7]).tokenEntropyStatus(r.tokenId) == StreamEntropyStatus.REQUESTED,
            "successful immediate request with no deferred funding");
        require(D(a[1]).refundableBalance(p.saleId, a[0]) == PAID_EXCESS
            && D(a[1]).refundLiability() == PAID_EXCESS && a[1].balance == PAID_EXCESS,
            "original pull refund retains exact excess");

        Read[] memory history = _history(a, p, r);
        Balance[] memory purchaseBalances = _balances(a, externalProvider);
        Read[] memory purchaseAccounting = _accounting(a, p, r, externalProvider);
        Step[] memory steps = new Step[](2);

        // Each is a separate later transaction in the RPC recipe; discovery gas is never a metric.
        steps[0] = _call(a[0], externalProvider,
            abi.encodeCall(PaidProviderView.fulfill, (uint256(1), RAW_RANDOMNESS)));
        (, bool finalized) = IStreamEntropyView(a[7]).tokenSeed(r.tokenId);
        require(finalized && accounting.pendingRequestCount() == 0, "actual deferred fulfillment");
        _assertHistory(history);
        steps[0].post = _accounting(a, p, r, externalProvider);
        steps[0].balances = _balances(a, externalProvider);

        uint256 beforeClaim = a[0].balance;
        steps[1] = _call(a[0], a[1], abi.encodeWithSignature("claimRefund(bytes32,address)", p.saleId, a[0]));
        require(a[0].balance == beforeClaim + PAID_EXCESS && a[1].balance == 0
            && D(a[1]).refundableBalance(p.saleId, a[0]) == 0 && D(a[1]).refundLiability() == 0
            && D(a[1]).refundAccountCount() == 1, "original refund claim and retained enumeration");
        _assertHistory(history);
        steps[1].post = _accounting(a, p, r, externalProvider);
        steps[1].balances = _balances(a, externalProvider);

        // Sidecar v1: exact scenario, post-purchase history/balances/accounting, then ordered calls.
        // The unchanged checkpoint records ALL discovered accesses, reverts, and exports original state.
        paidVm.writeFileBinary(
            string.concat(paidVm.envString("COLLECTOR_ACTUAL_EXPORT_DIR"), "/", label, "-paid.abi"),
            abi.encode(uint256(1), uint256(1000), PAID_FEE, PAID_EXCESS, externalProvider,
                paidArtworkLength, keccak256(p.tokenData), history, purchaseBalances, purchaseAccounting, steps)
        );
    }

    function _read(address target, bytes memory data) private view returns (Read memory item) {
        require(target.code.length != 0, "real read target");
        (bool ok, bytes memory result) = target.staticcall(data);
        require(ok && result.length != 0, "original history read succeeded");
        return Read(target, data, result);
    }

    function _history(address[13] memory a, S.Purchase memory p, S.Receipt memory r)
        private view returns (Read[] memory reads)
    {
        reads = new Read[](9);
        reads[0] = _read(a[1], abi.encodeWithSignature("executionReceipt(bytes32)", r.executionId));
        reads[1] = _read(a[5], abi.encodeWithSignature("settlementResult(bytes32)", r.settlementKey));
        reads[2] = _read(a[8], abi.encodeWithSignature("settlementReceipt(bytes32)", r.settlementKey));
        reads[3] = _read(a[8], abi.encodeWithSignature("firstSale(uint256)", uint256(1)));
        reads[4] = _read(a[8], abi.encodeWithSignature("releaseFloorReceipt(bytes32)", _coldReleaseKey()));
        reads[5] = _read(a[2], abi.encodeWithSignature("tokenCollectionIdentity(uint256)", r.tokenId));
        reads[6] = _read(a[2], abi.encodeWithSignature("coordinatorAtMint(uint256)", r.tokenId));
        reads[7] = _read(a[2], abi.encodeWithSignature("tokenData(uint256)", r.tokenId));
        // Post-only: index zero legitimately does not exist before the first paid credit.
        reads[8] = _read(a[1], abi.encodeWithSignature("refundAccountAt(uint256)", uint256(0)));
        (bytes32 saleId, address payer) = abi.decode(reads[8].result, (bytes32, address));
        require(saleId == p.saleId && payer == a[0], "original enumerated refund account");
    }

    function _accounting(address[13] memory a, S.Purchase memory p, S.Receipt memory r, address provider_)
        private view returns (Read[] memory reads)
    {
        reads = new Read[](8);
        reads[0] = _read(a[7], abi.encodeWithSignature("tokenSeed(uint256)", r.tokenId));
        reads[1] = _read(a[7], abi.encodeWithSignature("tokenEntropyStatus(uint256)", r.tokenId));
        reads[2] = _read(a[7], abi.encodeWithSignature("pendingRequestCount()"));
        reads[3] = _read(a[7], abi.encodeWithSignature("revealFeeEscrow(uint256)", uint256(1)));
        reads[4] = _read(a[7], abi.encodeWithSignature("totalRevealFeeEscrows()"));
        reads[5] = _read(provider_, abi.encodeWithSignature("nextRequestId()"));
        reads[6] = _read(a[1], abi.encodeWithSignature("refundableBalance(bytes32,address)", p.saleId, a[0]));
        reads[7] = _read(a[1], abi.encodeWithSignature("refundLiability()"));
    }

    function _balances(address[13] memory a, address provider_) private view returns (Balance[] memory rows) {
        rows = new Balance[](5);
        rows[0] = Balance(a[0], a[0].balance);
        rows[1] = Balance(a[1], a[1].balance);
        rows[2] = Balance(a[7], a[7].balance);
        rows[3] = Balance(provider_, provider_.balance);
        rows[4] = Balance(a[5], a[5].balance);
    }

    function _assertHistory(Read[] memory reads) private view {
        for (uint256 i; i < reads.length; ++i) {
            Read memory current = _read(reads[i].target, reads[i].data);
            require(keccak256(current.result) == keccak256(reads[i].result), "immutable paid history retained");
        }
    }

    function _call(address sender, address target, bytes memory data) private returns (Step memory step) {
        paidVm.prank(sender, sender);
        (bool ok, bytes memory result) = target.call(data);
        require(ok, "original follow-up succeeds");
        step.sender = sender;
        step.target = target;
        step.data = data;
        step.result = result;
    }
}
