// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./StreamSettlementContext.sol";
import "./StreamPrimarySettlementHash.sol";
import "../mint/StreamSaleTemplate.sol";
import "../../interfaces/stream/revenue/IStreamPrimarySaleSettlement.sol";
import "../../vendor/openzeppelin/ReentrancyGuard.sol";
import "../../vendor/openzeppelin/ERC165.sol";

/// @notice Universal official recorder's first ERC20 single-step profile.
/// @dev The registered sale adapter calls directly. Only its immutable bound contract20 funds
///      this recorder. No owner, caller allowlist, payer allowance or arbitrary transfer route.
contract StreamPrimarySaleSettlement is
    IStreamPrimarySaleSettlement,
    StreamSettlementContext,
    ReentrancyGuard,
    ERC165
{
    bytes32 private constant _CLASS = keccak256("PRIMARY_SALE");
    bytes32 private constant _TOTAL = keccak256("6529STREAM_OFFICIAL_PRIMARY_SETTLED_V1");
    IStreamRevenueEscrow public immutable override revenueEscrow;
    bytes32 public immutable escrowCodeHash;
    bytes32 public immutable walletCodeHash;
    mapping(bytes32 => bool) public override settlementConsumed;
    mapping(bytes32 => StreamPrimarySettlementTypes.PrimarySettlementResult) private _results;
    mapping(bytes32 => uint256) private _officialSettled;
    mapping(address => uint256) public override totalOfficialSettled;

    struct ContextEventData {
        uint16 schemaVersion;
        address settlementCaller;
        bytes32 settlementId;
        uint8 policyMode;
        uint256 collectionId;
        uint256 tokenId;
        bytes32 operationRoot;
        bytes32 operationId;
        uint256 saleNonce;
        address poster;
        address beneficiary;
        bytes32 templateId;
    }
    bytes32 private constant _CONTEXT_EVENT = keccak256(
        "PrimaryRevenueSettlementContext(bytes32,bytes32,bytes32,uint16,address,bytes32,uint8,uint256,uint256,bytes32,bytes32,uint256,address,address,bytes32)"
    );

    constructor(IStreamRevenueResolver resolver, address registry, IStreamRevenueEscrow escrow)
        StreamSettlementContext(resolver, registry)
    {
        if (
            !StreamSettlementAdmission.isContract(address(escrow))
                || _read(address(escrow), abi.encodeWithSignature("splitFactory()"), gasleft())
                    != uint256(uint160(address(splitFactory)))
                || _read(
                        address(escrow), abi.encodeWithSignature("assetPolicyRegistry()"), gasleft()
                    ) != uint256(uint160(address(assetPolicyRegistry)))
                || _read(address(escrow), abi.encodeWithSignature("factoryCodeHash()"), gasleft())
                    != uint256(factoryCodeHash)
                || escrow.governanceAuthority() != splitFactory.governanceAuthority()
        ) revert InvalidSettlementContext(address(escrow));
        revenueEscrow = escrow;
        escrowCodeHash = address(escrow).codehash;
        walletCodeHash = splitFactory.splitWalletRuntimeCodeHash();
        if (
            _read(address(escrow), abi.encodeWithSignature("walletCodeHash()"), gasleft())
                != uint256(walletCodeHash)
        ) {
            revert InvalidSettlementContext(address(escrow));
        }
    }

    function isStreamPrimarySaleSettlement() external pure override returns (bool) {
        return true;
    }

    function supportsInterface(bytes4 id) public view override returns (bool) {
        return id == type(IStreamPrimarySaleSettlement).interfaceId || super.supportsInterface(id);
    }

    function settlementKey(address saleAdapter, bytes32 executionId)
        public
        view
        override
        returns (bytes32)
    {
        return StreamPrimarySettlementHash.settlementKey(address(this), saleAdapter, executionId);
    }

    function settlementResult(bytes32 key)
        external
        view
        override
        returns (StreamPrimarySettlementTypes.PrimarySettlementResult memory)
    {
        return _results[key];
    }

    function officialSettled(bytes32 revenueClass, bytes32 profileId, address wallet, address asset)
        external
        view
        override
        returns (uint256)
    {
        return _officialSettled[_totalKey(revenueClass, profileId, wallet, asset)];
    }

    function settleERC20PrimarySaleFromAdapter(
        address paymentAdapter,
        StreamPrimarySettlementTypes.ERC20SettlementCandidate calldata candidate
    )
        external
        override
        nonReentrant
        returns (StreamPrimarySettlementTypes.PrimarySettlementResult memory result)
    {
        StreamPrimarySettlementTypes.ERC20SettlementCandidate memory c = candidate;
        _validate(paymentAdapter, c);
        bytes32 key = settlementKey(c.saleAdapter, c.executionBinding.executionId);
        if (settlementConsumed[key]) revert SettlementAlreadyConsumed(key);
        StreamSaleTemplate.Selection memory rights = _resolve(c);
        StreamSaleTemplate.materialize(revenueResolver, c.sale.collectionId, rights);
        _requireWallet(rights);
        settlementConsumed[key] = true;
        uint256 cap = _gas(_DEPOSIT_GAS);
        uint256 original = _balance(c.asset, address(this), cap);
        bytes32 commitment =
            StreamPrimarySettlementHash.candidateCommitment(paymentAdapter, address(this), c);
        IStreamERC20PrimarySettlementAdapter(paymentAdapter)
            .fundERC20PrimarySale(commitment, key, c.asset, c.sale.amount);
        if (_balance(c.asset, address(this), cap) != original + c.sale.amount) {
            revert SettlementAmountMismatch(c.asset);
        }
        _requireContext();
        _requireActive(c.asset);
        StreamSettlementAdmission.requireAdmission(moduleRegistry, paymentAdapter, c);
        _requireCurrent(c, rights);
        bool escrowed = _route(c, rights, cap);
        if (_balance(c.asset, address(this), cap) != original) {
            revert SettlementAmountMismatch(c.asset);
        }
        _requireContext();
        _requireActive(c.asset);
        StreamSettlementAdmission.requireAdmission(moduleRegistry, paymentAdapter, c);
        _requireCurrent(c, rights);
        result = StreamPrimarySettlementTypes.PrimarySettlementResult(
            commitment,
            key,
            rights.profileId,
            rights.wallet,
            c.asset,
            c.sale.amount,
            c.executor,
            c.executionBinding.executionId,
            escrowed,
            c.operationIdentityCommitment,
            c.currentPolicyHash,
            c.boundPolicyHash
        );
        _results[key] = result;
        _officialSettled[
            _totalKey(c.sale.revenueClass, rights.profileId, rights.wallet, c.asset)
        ] += c.sale.amount;
        totalOfficialSettled[c.asset] += c.sale.amount;
        _emit(c, result, paymentAdapter);
    }

    function _validate(
        address paymentAdapter,
        StreamPrimarySettlementTypes.ERC20SettlementCandidate memory c
    ) private view {
        if (
            msg.sender != c.saleAdapter || c.saleAdapter == address(0) || c.executor == address(0)
                || c.sale.settlementId == 0 || c.sale.revenueClass != _CLASS
                || c.sale.policyMode != 0 || c.sale.collectionId == 0 || c.sale.tokenId != 0
                || c.sale.saleNonce == 0 || c.sale.payer == address(0)
                || c.sale.payer == address(this) || c.sale.payer == paymentAdapter
                || c.sale.payer == c.rights.wallet || c.sale.payer == address(revenueEscrow)
                || c.sale.beneficiary == address(0) || c.sale.amount == 0
                || c.sale.expectedPrimaryPolicyHash == 0 || c.orchestrationOrder != 1
                || c.executionBinding.authorityMode != 1 || c.executionBinding.executionNonce == 0
                || c.executionBinding.saleAuthorizationDigest == 0
                || c.operationIdentityCommitment == 0 || c.operationId == 0
                || c.currentPolicyHash == 0 || c.boundPolicyHash == 0 || c.saleExecutionHash == 0
                || c.executionBinding.executionId != StreamPrimarySettlementHash.executionId(c)
        ) {
            revert InvalidPrimarySale();
        }
        _requireContext();
        _requireActive(c.asset);
        StreamSettlementAdmission.requireAdmission(moduleRegistry, paymentAdapter, c);
        if (
            _read(paymentAdapter, abi.encodeWithSignature("primarySaleSettlement()"), gasleft())
                    != uint256(uint160(address(this)))
                || _read(paymentAdapter, abi.encodeWithSignature("core()"), gasleft())
                    != uint256(uint160(core))
                || _read(paymentAdapter, abi.encodeWithSignature("moduleRegistry()"), gasleft())
                    != uint256(uint160(moduleRegistry))
                || _read(paymentAdapter, abi.encodeWithSignature("revenueResolver()"), gasleft())
                    != uint256(uint160(address(revenueResolver)))
                || _read(
                        c.saleAdapter, abi.encodeWithSignature("primarySaleSettlement()"), gasleft()
                    ) != uint256(uint160(address(this)))
                || _read(c.saleAdapter, abi.encodeWithSignature("core()"), gasleft())
                    != uint256(uint160(core))
                || _read(c.saleAdapter, abi.encodeWithSignature("mintManager()"), gasleft())
                    != uint256(uint160(c.mintManager))
        ) {
            revert PrimarySettlementPaymentBindingInvalid(paymentAdapter);
        }
    }

    function _resolve(StreamPrimarySettlementTypes.ERC20SettlementCandidate memory c)
        private
        view
        returns (StreamSaleTemplate.Selection memory rights)
    {
        IStreamRevenueResolver.ResolvedPrimaryAssignment memory a =
            revenueResolver.resolvePrimaryAssignment(c.sale.collectionId, 0, _CLASS);
        if (a.assignmentType == 2) {
            rights = StreamSaleTemplate.preview(revenueResolver, c.sale.collectionId, a);
        } else {
            if (
                !a.exists || a.assignmentType != 1 || a.scope != 1
                    || a.scopeId != c.sale.collectionId || a.profileId == 0 || a.templateId != 0
                    || a.assignmentHash == 0 || a.policyHash != 0
            ) revert PrimarySettlementRightsMismatch();
            rights = StreamSaleTemplate.Selection(
                a.profileId,
                splitFactory.walletFor(a.profileId),
                0,
                a.assignmentHash,
                splitFactory.profileEntriesHash(a.profileId)
            );
        }
        if (keccak256(abi.encode(rights)) != keccak256(abi.encode(c.rights))) {
            revert PrimarySettlementRightsMismatch();
        }
        if (
            StreamSaleTemplate.policyHash(revenueResolver, c.sale.collectionId, rights)
                != c.sale.expectedPrimaryPolicyHash
        ) revert PrimarySettlementPolicyMismatch();
    }

    function _requireCurrent(
        StreamPrimarySettlementTypes.ERC20SettlementCandidate memory c,
        StreamSaleTemplate.Selection memory rights
    ) private view {
        if (rights.templateId != 0) {
            StreamSaleTemplate.requireCurrent(revenueResolver, c.sale.collectionId, rights);
        } else {
            _resolve(c);
        }
        _requireWallet(rights);
    }

    function _requireWallet(StreamSaleTemplate.Selection memory rights) private view {
        if (
            splitFactory.walletFor(rights.profileId) != rights.wallet
                || !splitFactory.profileExists(rights.profileId)
                || (rights.wallet.code.length == 0 && rights.templateId == 0)
                || (rights.wallet.code.length != 0
                    && (rights.wallet.codehash != walletCodeHash
                        || !splitFactory.splitWalletExists(rights.profileId)))
        ) {
            revert PrimarySettlementRightsMismatch();
        }
    }

    function _route(
        StreamPrimarySettlementTypes.ERC20SettlementCandidate memory c,
        StreamSaleTemplate.Selection memory rights,
        uint256 cap
    ) private returns (bool escrowed) {
        _requireWallet(rights);
        if (
            rights.wallet.code.length != 0
                && _transfer(c.asset, rights.wallet, c.sale.amount, cap, true)
        ) return false;
        if (address(revenueEscrow).codehash != escrowCodeHash) {
            revert InvalidSettlementContext(address(revenueEscrow));
        }
        uint256 beforeEscrow = _balance(c.asset, address(revenueEscrow), cap);
        uint256 beforeWallet = _balance(c.asset, rights.wallet, cap);
        uint256 owed = revenueEscrow.escrowOwed(_CLASS, rights.profileId, rights.wallet, c.asset);
        if (_allowance(c.asset, address(this), address(revenueEscrow), cap) != 0) {
            revert PrimarySettlementEscrowMismatch();
        }
        _tokenCall(
            c.asset,
            abi.encodeCall(IERC20.approve, (address(revenueEscrow), c.sale.amount)),
            cap,
            false
        );
        if (_allowance(c.asset, address(this), address(revenueEscrow), cap) != c.sale.amount) {
            revert PrimarySettlementEscrowMismatch();
        }
        revenueEscrow.creditERC20(
            _CLASS, rights.profileId, rights.wallet, c.asset, c.sale.amount, rights.templateId != 0
        );
        if (
            _allowance(c.asset, address(this), address(revenueEscrow), cap) != 0
                || _balance(c.asset, address(revenueEscrow), cap) != beforeEscrow + c.sale.amount
                || _balance(c.asset, rights.wallet, cap) != beforeWallet
                || revenueEscrow.escrowOwed(_CLASS, rights.profileId, rights.wallet, c.asset)
                    != owed + c.sale.amount
        ) {
            revert PrimarySettlementEscrowMismatch();
        }
        return true;
    }

    function _totalKey(bytes32 revenueClass, bytes32 profileId, address wallet, address asset)
        private
        pure
        returns (bytes32)
    {
        return keccak256(abi.encode(_TOTAL, revenueClass, profileId, wallet, asset));
    }

    function _emit(
        StreamPrimarySettlementTypes.ERC20SettlementCandidate memory c,
        StreamPrimarySettlementTypes.PrimarySettlementResult memory r,
        address paymentAdapter
    ) private {
        emit PrimaryRevenueSettled(
            r.settlementKey,
            _CLASS,
            r.profileId,
            1,
            r.wallet,
            r.asset,
            c.sale.payer,
            r.amount,
            keccak256(abi.encode(c.sale)),
            false,
            c.rights.templateId == 0 ? 1 : 2
        );
        _emitContext(c, r);
        emit PrimaryRevenueSettlementPolicy(
            r.settlementKey,
            _CLASS,
            r.profileId,
            1,
            c.sale.expectedPrimaryPolicyHash,
            c.sale.expectedPrimaryPolicyHash,
            c.rights.assignmentHash,
            c.rights.templateId
        );
        emit PrimaryRevenueExecutionBound(
            r.settlementKey,
            c.saleAdapter,
            r.executionId,
            1,
            c.executor,
            paymentAdapter,
            r.candidateCommitment,
            c.currentPolicyHash,
            c.boundPolicyHash
        );
    }

    function _emitContext(
        StreamPrimarySettlementTypes.ERC20SettlementCandidate memory c,
        StreamPrimarySettlementTypes.PrimarySettlementResult memory r
    ) private {
        ContextEventData memory context;
        context.schemaVersion = 1;
        context.settlementCaller = c.saleAdapter;
        context.settlementId = c.sale.settlementId;
        context.policyMode = c.sale.policyMode;
        context.collectionId = c.sale.collectionId;
        context.tokenId = c.sale.tokenId;
        context.operationRoot = c.operationIdentityCommitment;
        context.operationId = c.operationId;
        context.saleNonce = c.sale.saleNonce;
        context.poster = c.sale.poster;
        context.beneficiary = c.sale.beneficiary;
        context.templateId = c.rights.templateId;
        // A static tuple is the exact twelve nonindexed ABI words. Explicit LOG4 avoids
        // the legacy compiler's stack limit without changing the normative event layout.
        bytes memory data = abi.encode(context);
        bytes32 topic = _CONTEXT_EVENT;
        bytes32 key = r.settlementKey;
        bytes32 profile = r.profileId;
        bytes32 revenueClass = _CLASS;
        assembly ("memory-safe") {
            log4(add(data, 32), mload(data), topic, key, revenueClass, profile)
        }
    }
}
