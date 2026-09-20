// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./StreamDirectPrimaryAdmission.sol";
import "./StreamDirectPrimarySaleHash.sol";
import "./StreamDirectPrimarySaleFloorCall.sol";

/// @notice Local immutable paid witnesses shared by the three original direct sale products.
abstract contract StreamDirectPrimaryReceipts is IStreamDirectPrimarySaleReceipt {
    address private immutable _directCore;
    bytes32 private immutable _directCoreCodeHash;
    address private immutable _directMintManager;
    bytes32 private immutable _directMintManagerCodeHash;
    uint256 private immutable _directChainId;
    bytes32 private immutable _directProductKind;
    address private immutable _directRegistry;
    bytes32 private immutable _directRegistryCodeHash;
    mapping(bytes32 => StreamDirectPrimarySaleTypes.Receipt) private _directReceipts;

    error InvalidDirectPrimaryConfiguration();
    error DirectPrimaryReceiptAlreadyRecorded(bytes32 authorizationId);

    constructor(address core_, address manager_, bytes32 productKind_) {
        if (
            !StreamSettlementAdmission.isContract(core_)
                || !StreamSettlementAdmission.isContract(manager_)
                || address(IStreamMintReads(manager_).core()) != core_
                || (productKind_ != StreamDirectPrimarySaleTypes.NATIVE_FIXED_PRICE
                    && productKind_ != StreamDirectPrimarySaleTypes.ERC20_FIXED_PRICE
                    && productKind_ != StreamDirectPrimarySaleTypes.ENGLISH_AUCTION)
        ) revert InvalidDirectPrimaryConfiguration();
        address registry = address(IStreamMintReads(manager_).moduleRegistry());
        if (!StreamSettlementAdmission.isContract(registry)) {
            revert InvalidDirectPrimaryConfiguration();
        }
        _directCore = core_;
        _directCoreCodeHash = core_.codehash;
        _directMintManager = manager_;
        _directMintManagerCodeHash = manager_.codehash;
        _directChainId = block.chainid;
        _directProductKind = productKind_;
        _directRegistry = registry;
        _directRegistryCodeHash = registry.codehash;
    }

    function directPrimaryBindings()
        public
        view
        override
        returns (StreamDirectPrimarySaleTypes.Bindings memory)
    {
        return StreamDirectPrimarySaleTypes.Bindings(
            _directCore,
            _directCoreCodeHash,
            _directMintManager,
            _directMintManagerCodeHash,
            _directChainId,
            _directProductKind
        );
    }

    function directPrimarySaleReceipt(bytes32 authorizationId)
        public
        view
        override
        returns (StreamDirectPrimarySaleTypes.Receipt memory)
    {
        return _directReceipts[authorizationId];
    }

    function directPrimarySaleReceiptHash(bytes32 authorizationId)
        public
        view
        override
        returns (bytes32)
    {
        StreamDirectPrimarySaleTypes.Receipt memory receipt = _directReceipts[authorizationId];
        if (receipt.amount == 0) return bytes32(0);
        return StreamDirectPrimarySaleHash.receiptHash(
            directPrimaryBindings(), address(this), authorizationId, receipt
        );
    }

    function _captureDirectPrimaryAdmission()
        internal
        view
        returns (uint64 createdAt, uint64 registryRevision)
    {
        return StreamDirectPrimaryAdmission.capture(
            directPrimaryBindings(), _directRegistry, _directRegistryCodeHash
        );
    }

    /// @dev Call only after original funding, mint/transfer and final callback-sensitive checks.
    /// The receipt is readable by the floor in this call; any later revert removes every effect.
    function _recordDirectPrimarySale(
        bytes32 authorizationId,
        StreamDirectPrimarySaleTypes.Receipt memory receipt
    ) internal {
        if (_directReceipts[authorizationId].amount != 0) {
            revert DirectPrimaryReceiptAlreadyRecorded(authorizationId);
        }
        StreamDirectPrimaryAdmission.requireReceipt(
            directPrimaryBindings(),
            _directRegistry,
            _directRegistryCodeHash,
            authorizationId,
            receipt
        );
        _directReceipts[authorizationId] = receipt;
        StreamDirectPrimarySaleFloorCall.record(_directCore, authorizationId);
        emit DirectPrimarySaleRecorded(
            authorizationId,
            StreamDirectPrimarySaleHash.receiptHash(
                directPrimaryBindings(), address(this), authorizationId, receipt
            ),
            receipt.tokenId,
            receipt,
            1
        );
    }
}
