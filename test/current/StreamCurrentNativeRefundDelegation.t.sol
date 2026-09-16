// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import { StreamCurrentNativeSettlementTest } from "./StreamCurrentNativeSettlement.t.sol";
import { StreamCurrentDutchSaleTest } from "./StreamCurrentDutchSale.t.sol";
import { StreamCurrentRefundWindowTest } from "./StreamCurrentRefundWindow.t.sol";
import { StreamCurrentClearingSaleTest } from "./StreamCurrentClearingSale.t.sol";
import { OfficialSafeFixture, OfficialSafe } from "../helpers/OfficialSafeFixture.sol";
import {
    DelegationManagementContract
} from "../../smart-contracts/integrations/delegation/NFTdelegation.sol";
import {
    IStreamNativeRefundDelegatedClaims as RC
} from "../../smart-contracts/interfaces/stream/mint/IStreamNativeRefundDelegatedClaims.sol";
import {
    IStreamGasParameterHost
} from "../../smart-contracts/interfaces/stream/parameters/IStreamGasParameterHost.sol";
import {
    IStreamNativeFixedPriceSaleAdapter
} from "../../smart-contracts/interfaces/stream/mint/IStreamNativeFixedPriceSaleAdapter.sol";
import {
    IStreamNativePricePrograms
} from "../../smart-contracts/interfaces/stream/mint/IStreamNativePricePrograms.sol";

interface NativeRefundProbeVm {
    struct Log {
        bytes32[] topics;
        bytes data;
        address emitter;
    }
    function expectCall(address, bytes calldata, uint64) external;
    function expectCall(address, uint256, bytes calldata, uint64) external;
    function mockCall(address, bytes calldata, bytes calldata) external;
    function mockCallRevert(address, bytes calldata, bytes calldata) external;
    function mockCallRevert(address, uint256, bytes calldata, bytes calldata) external;
    function clearMockedCalls() external;
    function recordLogs() external;
    function getRecordedLogs() external returns (Log[] memory);
}

/// @dev Shared assertions operate actual caller Safes, original NFTDelegation and four real current ledgers.
/// Mocked registry/recipient failures are explicitly labeled and are cleared before positive controls.
contract NativeRefundClaimProbe is OfficialSafeFixture {
    DelegationManagementContract public registry = new DelegationManagementContract();
    OfficialSafe private delegate;
    uint256[] private keys;
    NativeRefundProbeVm private constant probeVm =
        NativeRefundProbeVm(address(uint160(uint256(keccak256("hevm cheat code")))));

    constructor() {
        keys.push(0xDC1001);
        keys.push(0xDC1002);
        delegate =
            createOfficialSafe(deploySafeComponents("1.4.1"), safeOwnerAddresses(keys), 2, 0xDC10);
    }

    function deployment() external view returns (RC.DelegationDeployment memory) {
        return RC.DelegationDeployment(
            address(registry),
            2,
            keccak256("native refunds original deployment"),
            IStreamGasParameterHost.GasParameterConfig(
                "DELEGATE_REGISTRY_GAS_LIMIT", 150000, 50000, 2
            )
        );
    }

    function _read(address host, bytes memory data) private view returns (uint256) {
        (bool ok, bytes memory out) = host.staticcall(data);
        require(ok && out.length == 32, "exact ledger read");
        return abi.decode(out, (uint256));
    }

    function _balance(address host, bytes32 id, address account) private view returns (uint256) {
        return
            _read(host, abi.encodeWithSignature("refundableBalance(bytes32,address)", id, account));
    }

    function _grant(OfficialSafe payer, uint256[] memory payerKeys, address core, bool wallet)
        private
    {
        require(
            executeSafe(
                payer,
                payerKeys,
                address(registry),
                0,
                abi.encodeCall(
                    registry.registerDelegationAddress,
                    (
                        wallet ? address(0x8888888888888888888888888888888888888888) : core,
                        address(delegate),
                        block.timestamp + 1 days,
                        uint256(2),
                        true,
                        uint256(0)
                    )
                ),
                0
            ),
            "actual grant"
        );
    }

    function _serialize(address host, bytes memory data) private returns (bytes memory) {
        bytes32 digest = delegate.getTransactionHash(
            host, 0, data, 0, 0, 0, 0, address(0), address(0), delegate.nonce()
        );
        return abi.encodeCall(
            OfficialSafe.execTransaction,
            (
                host,
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
    }

    function _attempt(bytes memory serialized, bool expected) private {
        (bool ok, bytes memory out) = address(delegate).call(serialized);
        if (expected) {
            require(ok && abi.decode(out, (bool)), "actual delegate Safe success");
        } else {
            require(
                !ok
                    && keccak256(out)
                        == keccak256(abi.encodeWithSignature("Error(string)", "GS013")),
                "exact Safe target failure"
            );
        }
    }

    /// @param mode 0: absent grant/exact retry; 1: post-debit failed payment/exact retry;
    /// 2: full-row and scope failures, then own exit while registry/module unavailable.
    function exercise(
        address host,
        bytes32 id,
        OfficialSafe payer,
        uint256[] memory payerKeys,
        uint256 expectedCredit,
        string calldata liabilityGetter,
        bytes32 eventTopic,
        uint8 mode
    ) external {
        RC.DelegationConfiguration memory c = RC(host).refundDelegationConfiguration();
        require(
            c.chainId == block.chainid && c.registry == address(registry)
                && c.registryCodeHash == address(registry).codehash && c.core != address(0)
                && c.usecase == 2,
            "actual immutable pins"
        );
        require(
            keccak256(RC(host).refundDelegationManifest())
                == keccak256(
                    abi.encode(
                        keccak256("6529STREAM_NATIVE_AUCTION_NFTDELEGATION_MANIFEST_V1"),
                        block.chainid,
                        host,
                        c.baseManifestHash,
                        c.core,
                        c.registry,
                        c.registryCodeHash,
                        c.usecase
                    )
                ),
            "original compact manifest preimage"
        );
        uint256 credit = _balance(host, id, address(payer));
        require(credit == expectedCredit && credit != 0, "actual earned credit");
        uint256 beforeBalance = host.balance;
        uint256 beforePayer = address(payer).balance;
        uint256 beforeDelegate = address(delegate).balance;
        bytes memory liabilityCall = abi.encodeWithSignature(liabilityGetter);
        uint256 liability = _read(host, liabilityCall);
        require(liability >= credit, "solvent classes");
        bool wallet = mode == 1;
        bytes memory callData = abi.encodeCall(
            RC.claimRefundFor, (id, address(payer), RC.DelegationWitness(wallet, 0))
        );
        bytes memory serialized = _serialize(host, callData);
        uint256 nonce = delegate.nonce();
        bytes memory row = abi.encodeWithSignature(
            "globalDelegationHashes(bytes32,uint256)",
            keccak256(
                abi.encodePacked(
                    address(payer),
                    wallet ? address(0x8888888888888888888888888888888888888888) : c.core,
                    address(delegate),
                    uint256(2)
                )
            ),
            uint256(0)
        );
        if (mode == 0) {
            probeVm.expectCall(address(registry), row, uint64(3)); // failed claim, successful retry, fresh spent-credit refusal
            _attempt(serialized, false);
            require(
                delegate.nonce() == nonce && _balance(host, id, address(payer)) == credit
                    && host.balance == beforeBalance,
                "failed grant leaves exact claim"
            );
            _grant(payer, payerKeys, c.core, false);
        } else if (mode == 1) {
            _grant(payer, payerKeys, c.core, true);
            probeVm.expectCall(address(payer), credit, bytes(""), uint64(2));
            probeVm.mockCallRevert(
                address(payer), credit, bytes(""), bytes("explicit recipient fault")
            );
            _attempt(serialized, false);
            require(
                delegate.nonce() == nonce && _balance(host, id, address(payer)) == credit
                    && _read(host, liabilityCall) == liability && host.balance == beforeBalance
                    && address(payer).balance == beforePayer,
                "payment rollback restores every liability"
            );
            probeVm.clearMockedCalls();
        } else {
            _grant(payer, payerKeys, c.core, false);
            // A row under the right key is still insufficient unless every retained field matches.
            uint256[6] memory actual = [
                uint256(uint160(address(payer))),
                uint256(uint160(address(delegate))),
                block.timestamp,
                block.timestamp + 1 days,
                uint256(1),
                uint256(0)
            ];
            for (uint256 i; i < 6; ++i) {
                uint256[6] memory wrong;
                for (uint256 j; j < 6; ++j) {
                    wrong[j] = actual[j];
                }
                wrong[i] = i == 2
                    ? block.timestamp + 1 days
                    : i == 3 ? block.timestamp : i == 4 ? 0 : actual[i] + 1;
                probeVm.mockCall(address(registry), row, abi.encode(wrong));
                _attempt(serialized, false);
                probeVm.clearMockedCalls();
            }
            probeVm.mockCall(address(registry), row, new bytes(224));
            _attempt(serialized, false);
            probeVm.clearMockedCalls();
            probeVm.mockCall(address(registry), row, new bytes(160));
            _attempt(serialized, false);
            probeVm.clearMockedCalls();
            bytes memory wrongScope = _serialize(
                host,
                abi.encodeCall(
                    RC.claimRefundFor, (id, address(payer), RC.DelegationWitness(true, 0))
                )
            );
            _attempt(wrongScope, false);
            require(
                executeSafe(
                    payer,
                    payerKeys,
                    address(registry),
                    0,
                    abi.encodeCall(
                        registry.revokeDelegationAddress, (c.core, address(delegate), uint256(2))
                    ),
                    0
                ),
                "actual revocation"
            );
            _attempt(serialized, false);
            probeVm.mockCallRevert(address(registry), bytes(""), bytes("registry unavailable"));
            probeVm.mockCallRevert(
                c.moduleRegistry, bytes(""), bytes("retired provider unavailable")
            );
            require(
                executeSafe(
                    payer,
                    payerKeys,
                    host,
                    0,
                    abi.encodeWithSignature("claimRefund(bytes32,address)", id, address(delegate)),
                    0
                ),
                "original alternate recipient exit remains independent"
            );
            probeVm.clearMockedCalls();
            require(
                address(delegate).balance == beforeDelegate + credit
                    && address(payer).balance == beforePayer,
                "only principal chose alternate destination"
            );
            require(
                host.balance == beforeBalance - credit
                    && _read(host, liabilityCall) == liability - credit
                    && _balance(host, id, address(payer)) == 0,
                "own per-key conservation"
            );
            return;
        }
        // Earned delegate credits also survive failure of the current module provider.
        probeVm.mockCallRevert(
            c.moduleRegistry, bytes(""), bytes("retired module provider unavailable")
        );
        probeVm.recordLogs();
        _attempt(serialized, true);
        NativeRefundProbeVm.Log[] memory logs = probeVm.getRecordedLogs();
        probeVm.clearMockedCalls();
        uint256 found;
        for (uint256 i; i < logs.length; ++i) {
            if (logs[i].emitter == host && logs[i].topics[0] == eventTopic) {
                require(
                    logs[i].topics.length == 4 && logs[i].topics[1] == id
                        && logs[i].topics[2] == bytes32(uint256(uint160(address(payer))))
                        && logs[i].topics[3] == logs[i].topics[2]
                        && keccak256(logs[i].data) == keccak256(abi.encode(uint16(1), credit)),
                    "original full claim event uses credited principal"
                );
                ++found;
            }
        }
        require(
            found == 1 && delegate.nonce() == nonce + 1
                && address(delegate).balance == beforeDelegate
                && address(payer).balance == beforePayer + credit,
            "delegate never receives funds"
        );
        require(
            host.balance == beforeBalance - credit
                && _read(host, liabilityCall) == liability - credit
                && _balance(host, id, address(payer)) == 0
                && _balance(host, id, address(delegate)) == 0,
            "exact key/liability conservation"
        );
        _attempt(_serialize(host, callData), false); // Fresh Safe nonce cannot spend the consumed credit again.
    }
}

/// @dev Actual Core/Manager/Artist/Executor/recorder and original registry/Safes; external entropy service remains the fixture double.
contract StreamCurrentFixedRefundDelegationTest is StreamCurrentNativeSettlementTest {
    NativeRefundClaimProbe private probe;

    function _refundClaimDeployment() internal override returns (RC.DelegationDeployment memory) {
        probe = new NativeRefundClaimProbe();
        return probe.deployment();
    }

    function testFreeOpenAndPayWhatYouWantCreditsStayInDistinctOriginalSaleKeys() external {
        this.deployNativeScenario(false, false);
        bytes32[3] memory ids = [zeroProgram, pwywProgram, openProgram];
        uint256[3] memory amounts = [uint256(0), uint256(500), uint256(1000)];
        for (uint256 i; i < 3; ++i) {
            IStreamNativePricePrograms.PriceProgramExecution memory e =
                _programExecution(ids[i], i + 1, amounts[i], i == 1 ? 100 : amounts[i]);
            uint256 fee = nativeSale.saleRevealQuote(ids[i]).policy.revealFeePerTokenWei;
            require(
                executeSafe(
                    payerSafe,
                    keys,
                    address(nativeSale),
                    amounts[i] + fee + 17,
                    abi.encodeCall(nativeSale.executePriceProgram, (e)),
                    0
                )
            );
        }
        require(
            nativeSale.refundLiability() == 51 && core.totalSupply() == 3,
            "three original programs minted separate credited keys"
        );
        probe.exercise(
            address(nativeSale),
            ids[1],
            payerSafe,
            keys,
            17,
            "refundLiability()",
            keccak256("SaleRefundClaimed(uint16,bytes32,address,address,uint256)"),
            uint8(1)
        );
        require(
            nativeSale.refundableBalance(ids[0], address(payerSafe)) == 17
                && nativeSale.refundableBalance(ids[2], address(payerSafe)) == 17,
            "delegation cannot cross sale keys"
        );
        for (uint256 i; i < 3; i += 2) {
            require(
                executeSafe(
                    payerSafe,
                    keys,
                    address(nativeSale),
                    0,
                    abi.encodeCall(nativeSale.claimRefund, (ids[i], address(payerSafe))),
                    0
                )
            );
        }
        require(nativeSale.refundLiability() == 0, "every per-sale refund completes once");
    }

    function _earnedClaim(uint8 mode) private {
        this.deployNativeScenario(false, false);
        (IStreamNativeFixedPriceSaleAdapter.SaleExecutionData memory e,) =
            _execution(1, address(payerSafe));
        uint256 fee = nativeSale.saleRevealQuote(saleId).policy.revealFeePerTokenWei;
        require(
            executeSafe(
                payerSafe,
                keys,
                address(nativeSale),
                1017 + fee,
                abi.encodeCall(nativeSale.purchase, (e)),
                0
            )
        );
        require(core.ownerOf(1) == address(payerSafe), "actual minted collector custody");
        probe.exercise(
            address(nativeSale),
            saleId,
            payerSafe,
            keys,
            17,
            "refundLiability()",
            keccak256("SaleRefundClaimed(uint16,bytes32,address,address,uint256)"),
            mode
        );
    }

    function testDelegateMissingGrantPreservesExactSafeClaimThenOriginalGrantRetries() external {
        _earnedClaim(0);
    }

    function testDelegatePaymentFailureRollsBackThenIdenticalSafeCallPaysOnlyPrincipal() external {
        _earnedClaim(1);
    }

    function testDelegateRequiresCompleteCurrentRowButOwnExitSurvivesUnavailableProviders()
        external
    {
        _earnedClaim(2);
    }
}

/// @dev Actual Core/Manager/Artist/Executor/recorder and original registry/Safes; external entropy service remains the fixture double.
contract StreamCurrentDutchRefundDelegationTest is StreamCurrentDutchSaleTest {
    NativeRefundClaimProbe private probe;

    function _refundClaimDeployment() internal override returns (RC.DelegationDeployment memory) {
        probe = new NativeRefundClaimProbe();
        return probe.deployment();
    }

    function _earnedClaim(uint8 mode) private {
        _consent();
        _purchase(_purchaseData(1, 1000), 1117);
        require(core.ownerOf(1) == address(payerSafe), "actual Dutch collector custody");
        probe.exercise(
            address(dutchSale),
            dutchId,
            payerSafe,
            keys,
            17,
            "refundLiability()",
            keccak256("DutchRefundClaimed(uint16,bytes32,address,address,uint256)"),
            mode
        );
    }

    function testDelegateMissingGrantPreservesExactSafeClaimThenOriginalGrantRetries() external {
        _earnedClaim(0);
    }

    function testDelegatePaymentFailureRollsBackThenIdenticalSafeCallPaysOnlyPrincipal() external {
        _earnedClaim(1);
    }

    function testDelegateRequiresCompleteCurrentRowButOwnExitSurvivesUnavailableProviders()
        external
    {
        _earnedClaim(2);
    }
}

/// @dev Actual Core/Manager/Artist/Executor/recorder and original registry/Safes; external entropy service remains the fixture double.
contract StreamCurrentWindowRefundDelegationTest is StreamCurrentRefundWindowTest {
    NativeRefundClaimProbe private probe;

    function _refundClaimDeployment() internal override returns (RC.DelegationDeployment memory) {
        probe = new NativeRefundClaimProbe();
        return probe.deployment();
    }

    function _earnedClaim(uint8 mode) private {
        bytes32 purchase = _purchase(_purchaseData(1));
        _exec(
            payerSafe, address(refundSale), 0, abi.encodeCall(refundSale.refundPurchase, (purchase))
        );
        require(
            core.totalSupply() == 0 && refundSale.totalPendingDeposits() == 0,
            "true canceled deposit, no mint"
        );
        probe.exercise(
            address(refundSale),
            refundId,
            payerSafe,
            keys,
            1100,
            "totalBuyerLiabilities()",
            keccak256("RefundCreditClaimed(uint16,bytes32,address,address,uint256)"),
            mode
        );
    }

    function testDelegateMissingGrantPreservesExactSafeClaimThenOriginalGrantRetries() external {
        _earnedClaim(0);
    }

    function testDelegatePaymentFailureRollsBackThenIdenticalSafeCallPaysOnlyPrincipal() external {
        _earnedClaim(1);
    }

    function testDelegateRequiresCompleteCurrentRowButOwnExitSurvivesUnavailableProviders()
        external
    {
        _earnedClaim(2);
    }
}

/// @dev Actual Core/Manager/Artist/Executor/recorder and original registry/Safes; external entropy service remains the fixture double.
contract StreamCurrentClearingRefundDelegationTest is StreamCurrentClearingSaleTest {
    NativeRefundClaimProbe private probe;

    function _refundClaimDeployment() internal override returns (RC.DelegationDeployment memory) {
        probe = new NativeRefundClaimProbe();
        return probe.deployment();
    }

    function _earnedClaim(uint8 mode) private {
        _consent();
        _buy(_purchaseData(1), 1217);
        require(core.ownerOf(1) == address(payerSafe), "actual clearing collector custody");
        probe.exercise(
            address(clearing),
            saleId,
            payerSafe,
            signingKeys,
            217,
            "totalBuyerLiabilities()",
            keccak256("ClearingRefundClaimed(uint16,bytes32,address,address,uint256)"),
            mode
        );
    }

    function testDelegateMissingGrantPreservesExactSafeClaimThenOriginalGrantRetries() external {
        _earnedClaim(0);
    }

    function testDelegatePaymentFailureRollsBackThenIdenticalSafeCallPaysOnlyPrincipal() external {
        _earnedClaim(1);
    }

    function testDelegateRequiresCompleteCurrentRowButOwnExitSurvivesUnavailableProviders()
        external
    {
        _earnedClaim(2);
    }
}
