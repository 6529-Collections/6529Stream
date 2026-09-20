// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "./StreamNativeSettlementHash.sol";
import "./StreamPrimarySettlementHash.sol";
import "./StreamSettlementAdmission.sol";
import "../../interfaces/stream/revenue/IStreamPrimarySaleSettlement.sol";
import "../../interfaces/stream/revenue/IStreamNativePublicSaleBinding.sol";

/// @notice Compiler-linked field and exact immutable reads for existing recorder entries.
/// @dev The recorder preserves surrounding admission/replay/funding order and supplies its own pins.
library StreamPrimarySettlementValidation {
    struct Bindings {
        address core;
        address registry;
        address resolver;
        address escrow;
    }
    bytes32 private constant _CLASS = keccak256("PRIMARY_SALE");
    error SettlementReadFailed(address target, bytes4 selector);

    function nativeFields(
        Bindings memory x,
        StreamNativeSettlementTypes.NativeSettlementCandidate memory c
    ) public view {
        if (
            msg.sender != c.saleAdapter || c.saleAdapter == address(0) || c.executor == address(0)
                || c.sale.settlementId == 0 || c.sale.revenueClass != _CLASS
                || c.sale.policyMode != 0 || c.sale.collectionId == 0 || c.sale.tokenId != 0
                || c.sale.saleNonce == 0 || c.sale.payer == address(0)
                || c.sale.payer == address(this) || c.sale.payer == c.saleAdapter
                || c.sale.payer == c.rights.wallet || c.sale.payer == x.escrow
                || c.sale.payer != c.executor || c.sale.beneficiary == address(0)
                || c.sale.amount == 0 || msg.value != c.sale.amount
                || c.sale.expectedPrimaryPolicyHash == 0 || c.orchestrationOrder != 1
                || c.executionBinding.authorityMode != 1 || c.executionBinding.executionNonce == 0
                || c.executionBinding.saleAuthorizationDigest == 0
                || c.operationIdentityCommitment == 0 || c.operationId == 0
                || c.currentPolicyHash == 0 || c.boundPolicyHash == 0 || c.saleExecutionHash == 0
                || c.executionBinding.executionId != StreamNativeSettlementHash.executionId(c)
        ) {
            revert IStreamPrimarySaleSettlement.InvalidPrimarySale();
        }
    }

    function nativePublicFields(
        Bindings memory x,
        StreamNativeSettlementTypes.NativeSettlementCandidate memory c
    ) public view {
        if (
            msg.sender != c.saleAdapter || c.saleAdapter == address(0) || c.executor == address(0)
                || c.sale.settlementId == 0 || c.sale.revenueClass != _CLASS
                || c.sale.policyMode != 0 || c.sale.collectionId == 0 || c.sale.tokenId != 0
                || c.sale.saleNonce == 0 || c.sale.payer == address(0)
                || c.sale.payer == address(this) || c.sale.payer == c.saleAdapter
                || c.sale.payer == c.rights.wallet || c.sale.payer == x.escrow
                || c.sale.payer != c.executor || c.sale.beneficiary == address(0)
                || c.sale.amount == 0 || msg.value != c.sale.amount
                || c.sale.expectedPrimaryPolicyHash == 0 || c.orchestrationOrder != 1
                || c.executionBinding.authorityMode != 2 || c.executionBinding.executionNonce == 0
                || c.executionBinding.saleAuthorizationDigest != 0
                || c.operationIdentityCommitment == 0 || c.operationId == 0
                || c.currentPolicyHash == 0 || c.boundPolicyHash == 0 || c.saleExecutionHash == 0
                || c.executionBinding.executionId != StreamNativeSettlementHash.executionId(c)
        ) {
            revert IStreamPrimarySaleSettlement.InvalidPrimarySale();
        }
    }

    /// @notice Authenticate only the caller's exact public record and active candidate.
    /// @dev The native tuple has no phase/config fields; the full active commitment authenticates
    /// the candidate, while the immutable sale record supplies its nonzero phase/config binding.
    function nativePublicBindings(
        Bindings memory x,
        StreamNativeSettlementTypes.NativeSettlementCandidate memory c
    ) public view returns (bytes32 recordHash) {
        nativeBindings(x, c);
        bytes memory data = abi.encodeCall(
            IStreamNativePublicSaleBinding.publicNativeSaleBinding, (c.sale.settlementId)
        );
        uint256[4] memory words;
        address adapter = c.saleAdapter;
        bool ok;
        uint256 size;
        assembly ("memory-safe") {
            ok := staticcall(gas(), adapter, add(data, 32), mload(data), words, 128)
            size := returndatasize()
        }
        if (!ok || size != 128) revert SettlementReadFailed(adapter, bytes4(data));
        if (
            words[0] != c.sale.collectionId || words[1] == 0 || words[2] == 0 || words[3] != 2
                || bytes32(
                        _read(
                            adapter,
                            abi.encodeCall(
                                IStreamNativePublicSaleBinding.activePublicNativeCandidate,
                                (c.executionBinding.executionId)
                            ),
                            gasleft()
                        )
                    ) != StreamNativeSettlementHash.candidateCommitment(address(this), c)
        ) revert IStreamPrimarySaleSettlement.InvalidPrimarySale();
        return keccak256(abi.encode(words));
    }

    function nativeBindings(
        Bindings memory x,
        StreamNativeSettlementTypes.NativeSettlementCandidate memory c
    ) public view {
        if (
            _read(c.saleAdapter, abi.encodeWithSignature("primarySaleSettlement()"), gasleft())
                    != uint256(uint160(address(this)))
                || _read(c.saleAdapter, abi.encodeWithSignature("core()"), gasleft())
                    != uint256(uint160(x.core))
                || _read(c.saleAdapter, abi.encodeWithSignature("moduleRegistry()"), gasleft())
                    != uint256(uint160(x.registry))
                || _read(c.saleAdapter, abi.encodeWithSignature("revenueResolver()"), gasleft())
                    != uint256(uint160(x.resolver))
                || _read(c.saleAdapter, abi.encodeWithSignature("mintManager()"), gasleft())
                    != uint256(uint160(c.mintManager))
                || !StreamSettlementAdmission.isContract(c.mintManager)
                || _read(c.mintManager, abi.encodeWithSignature("core()"), gasleft())
                    != uint256(uint160(x.core))
                || _read(c.mintManager, abi.encodeWithSignature("moduleRegistry()"), gasleft())
                    != uint256(uint160(x.registry))
        ) {
            revert IStreamPrimarySaleSettlement.InvalidPrimarySale();
        }
    }

    function erc20Fields(
        Bindings memory x,
        address paymentAdapter,
        StreamPrimarySettlementTypes.ERC20SettlementCandidate memory c
    ) public view {
        if (
            msg.sender != c.saleAdapter || c.saleAdapter == address(0) || c.executor == address(0)
                || c.sale.settlementId == 0 || c.sale.revenueClass != _CLASS
                || c.sale.policyMode != 0 || c.sale.collectionId == 0 || c.sale.tokenId != 0
                || c.sale.saleNonce == 0 || c.sale.payer == address(0)
                || c.sale.payer == address(this) || c.sale.payer == paymentAdapter
                || c.sale.payer == c.rights.wallet || c.sale.payer == x.escrow
                || c.sale.beneficiary == address(0) || c.sale.amount == 0
                || c.sale.expectedPrimaryPolicyHash == 0 || c.orchestrationOrder != 1
                || c.executionBinding.authorityMode != 1 || c.executionBinding.executionNonce == 0
                || c.executionBinding.saleAuthorizationDigest == 0
                || c.operationIdentityCommitment == 0 || c.operationId == 0
                || c.currentPolicyHash == 0 || c.boundPolicyHash == 0 || c.saleExecutionHash == 0
                || c.executionBinding.executionId != StreamPrimarySettlementHash.executionId(c)
        ) {
            revert IStreamPrimarySaleSettlement.InvalidPrimarySale();
        }
    }

    function erc20Bindings(
        Bindings memory x,
        address paymentAdapter,
        StreamPrimarySettlementTypes.ERC20SettlementCandidate memory c
    ) public view {
        if (
            _read(paymentAdapter, abi.encodeWithSignature("primarySaleSettlement()"), gasleft())
                    != uint256(uint160(address(this)))
                || _read(paymentAdapter, abi.encodeWithSignature("core()"), gasleft())
                    != uint256(uint160(x.core))
                || _read(paymentAdapter, abi.encodeWithSignature("moduleRegistry()"), gasleft())
                    != uint256(uint160(x.registry))
                || _read(paymentAdapter, abi.encodeWithSignature("revenueResolver()"), gasleft())
                    != uint256(uint160(x.resolver))
                || _read(
                        c.saleAdapter, abi.encodeWithSignature("primarySaleSettlement()"), gasleft()
                    ) != uint256(uint160(address(this)))
                || _read(c.saleAdapter, abi.encodeWithSignature("core()"), gasleft())
                    != uint256(uint160(x.core))
                || _read(c.saleAdapter, abi.encodeWithSignature("mintManager()"), gasleft())
                    != uint256(uint160(c.mintManager))
        ) {
            revert IStreamPrimarySaleSettlement.PrimarySettlementPaymentBindingInvalid(paymentAdapter);
        }
    }

    function _read(address target, bytes memory data, uint256 cap)
        private
        view
        returns (uint256 word)
    {
        bool ok;
        uint256 size;
        assembly ("memory-safe") {
            ok := staticcall(cap, target, add(data, 32), mload(data), 0, 32)
            size := returndatasize()
            word := mload(0)
        }
        if (!ok || size != 32) revert SettlementReadFailed(target, bytes4(data));
    }
}
