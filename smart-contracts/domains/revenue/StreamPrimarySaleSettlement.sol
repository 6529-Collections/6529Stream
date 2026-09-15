// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./StreamSettlementContext.sol";
import "../../interfaces/stream/revenue/IStreamPlatformNativePrimarySettlement.sol";
import "../../interfaces/stream/revenue/IStreamPlatformProfilePrimarySettlement.sol";
import "./StreamERC20PrimaryRecording.sol";
import "./StreamPreparedNativeRightsRecording.sol";
import "./StreamNativeCustodyPrimaryRecording.sol";
import "./StreamTokenProfileCustodyRecording.sol";
import "./StreamCustodyRightsRecording.sol";
import "./StreamPlatformCustodyRecording.sol";
import "./StreamNativeSupplementalExecution.sol";
import "./StreamNativePrimaryExecution.sol";
import "./StreamNativePrimaryRecording.sol";
import "./StreamPrimaryTokenRouting.sol";
import "./StreamPrimarySettlementValidation.sol";
import "./StreamPrimarySettlementHash.sol";
import "./StreamNativeSettlementHash.sol";
import "./StreamNativeSettlementAdmission.sol";
import "./StreamNativeSettlementSupport.sol";
import "./StreamPrimarySettlementEmission.sol";
import "./StreamPrimarySettlementRights.sol";
import "./StreamDeferredNativeSettlementValidation.sol";
import "./StreamPreparedNativeSettlementAccounting.sol";
import "./StreamPreparedNativeSettlementExecution.sol";
import "./StreamPreparedNativeContentRecording.sol";
import "../../interfaces/stream/revenue/IStreamDeferredNativePrimarySaleSettlement.sol";
import "../../interfaces/stream/revenue/IStreamNativePrimarySaleSettlement.sol";
import "../mint/StreamSaleTemplate.sol";
import "../../interfaces/stream/revenue/IStreamPrimarySaleSettlement.sol";
import "../../vendor/openzeppelin/ReentrancyGuard.sol";
import "../../vendor/openzeppelin/ERC165.sol";

/// @notice Official recorder for typed mint payments and native clearing supplemental revenue.
/// @dev Registered sale adapters call directly. The ERC20 path is funded only by its bound contract20;
///      native adapters supply exact value. No owner, payer allowance or arbitrary transfer route.
contract StreamPrimarySaleSettlement is
    IStreamPrimarySaleSettlement,
    IStreamNativePrimarySaleSettlement,
    IStreamDeferredNativePrimarySaleSettlement,
    IStreamPreparedNativePrimarySaleSettlement,
    IStreamPreparedNativeContentSettlement,
    IStreamNativeSupplementalSettlement,
    IStreamNativeCustodyPrimarySettlement,
    IStreamTokenProfileCustodySettlement,
    IStreamCustodyRightsSettlement,
    IStreamPlatformCustodyPrimarySettlement,
    IStreamPreparedNativeRightsPrimarySettlement,
    IStreamPlatformNativePrimarySettlement,
    IStreamPlatformProfilePrimarySettlement,
    StreamSettlementContext,
    ReentrancyGuard,
    ERC165
{
    // Retain decoding for the same error now bubbled through the linked rights helper.
    error UnsupportedSaleTemplate();
    // Preserve decoding of the exact errors now emitted by the fixed ERC20 worker.
    error SaleTemplateMaterializationMismatch();
    error SaleTemplateAssignmentChanged();
    error SaleLifecycleReadFailed(address saleAdapter);
    error SaleLifecycleReadMalformed(address saleAdapter, uint256 length);
    error SaleLifecycleMismatch(address saleAdapter, bytes32 saleId);
    error SettlementModuleReadMalformed(address module, uint256 length);
    error SettlementModuleNotAdmitted(address module);
    error SettlementModuleReadFailed(address module);

    bytes32 private constant _CLASS = keccak256("PRIMARY_SALE");
    bytes32 private constant _TOTAL = keccak256("6529STREAM_OFFICIAL_PRIMARY_SETTLED_V1");
    IStreamRevenueEscrow public immutable override revenueEscrow;
    bytes32 public immutable escrowCodeHash;
    bytes32 public immutable walletCodeHash;
    mapping(bytes32 => bool) public override settlementConsumed;
    mapping(bytes32 => StreamPrimarySettlementTypes.PrimarySettlementResult) private _results;
    mapping(bytes32 => uint256) private _officialSettled;
    mapping(address => uint256) public override totalOfficialSettled;
    mapping(bytes32 => bool) public deferredPurchaseConsumed;
    mapping(bytes32 => bool) public supplementalPurchaseConsumed;
    mapping(bytes32 => bool) public supplementalFloorConsumed;
    mapping(bytes32 => StreamNativeSupplementalTypes.NativeSupplementalResult) private
        _supplementalResults;
    mapping(bytes32 => bytes32) public override preparedNativeFactsHash;
    mapping(bytes32 => bool) public override preparedNativeSaleConsumed;
    mapping(bytes32 => bytes32) public override preparedNativeContentHash;
    address public immutable custodyGovernanceAuthority;
    bytes32 public immutable custodyGovernanceAuthorityCodeHash;
    StreamNativeCustodySettlementTypes.CanonicalHouse private _canonicalCustodyHouse;
    mapping(bytes32 => bytes32) public override nativeCustodyFactsHash;
    mapping(bytes32 => bytes32) public override preparedNativeRightsFactsHash;

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
        custodyGovernanceAuthority = splitFactory.governanceAuthority();
        custodyGovernanceAuthorityCodeHash = StreamNativeCustodyPrimaryAdmission.validateAuthority(
            splitFactory.governanceAuthority()
        );
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

    function isStreamPlatformProfilePrimarySettlement() external pure override returns (bool) {
        return true;
    }

    function isStreamPlatformNativePrimarySettlement() external pure override returns (bool) {
        return true;
    }

    function supportsInterface(bytes4 id) public view override returns (bool) {
        return id == type(IStreamPrimarySaleSettlement).interfaceId
            || id == type(IStreamNativePrimarySaleSettlement).interfaceId
            || id == type(IStreamDeferredNativePrimarySaleSettlement).interfaceId
            || id == type(IStreamPreparedNativePrimarySaleSettlement).interfaceId
            || id == type(IStreamPreparedNativeContentSettlement).interfaceId
            || id == type(IStreamNativeCustodyPrimarySettlement).interfaceId
            || id == type(IStreamTokenProfileCustodySettlement).interfaceId
            || id == type(IStreamCustodyRightsSettlement).interfaceId
            || id == type(IStreamPlatformCustodyPrimarySettlement).interfaceId
            || id == type(IStreamPreparedNativeRightsPrimarySettlement).interfaceId
            || id == type(IStreamPlatformNativePrimarySettlement).interfaceId
            || id == type(IStreamPlatformProfilePrimarySettlement).interfaceId
            || id == type(IStreamNativeSupplementalSettlement).interfaceId
            || super.supportsInterface(id);
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
        return StreamERC20PrimaryRecording.execute(
            _erc20RecordingContext(),
            settlementConsumed,
            _results,
            _officialSettled,
            totalOfficialSettled,
            paymentAdapter,
            candidate
        );
    }

    function settleNativePrimarySaleFromAdapter(
        StreamNativeSettlementTypes.NativeSettlementCandidate calldata candidate
    )
        external
        payable
        override
        nonReentrant
        returns (StreamPrimarySettlementTypes.PrimarySettlementResult memory result)
    {
        return StreamNativePrimaryRecording.settleNative(
            _nativeRecordingContext(),
            settlementConsumed,
            _results,
            _officialSettled,
            totalOfficialSettled,
            candidate
        );
    }

    function deferredPurchaseKey(address adapter, bytes32 purchaseId)
        public
        view
        returns (bytes32)
    {
        return StreamDeferredNativeSettlementHash.purchaseKey(address(this), adapter, purchaseId);
    }

    function settleDeferredNativePrimarySaleFromAdapter(
        StreamDeferredNativeSettlementTypes.DeferredNativeCandidate calldata candidate
    )
        external
        payable
        override
        nonReentrant
        returns (StreamPrimarySettlementTypes.PrimarySettlementResult memory result)
    {
        return StreamNativePrimaryRecording.settleDeferred(
            _nativeRecordingContext(),
            settlementConsumed,
            _results,
            _officialSettled,
            totalOfficialSettled,
            deferredPurchaseConsumed,
            candidate
        );
    }

    function supplementalPurchaseKey(address adapter, bytes32 id) public view returns (bytes32) {
        return StreamNativeSupplementalHash.purchaseKey(address(this), adapter, id);
    }

    function preparedNativeSaleKey(address adapter, bytes32 saleId, uint256 saleNonce)
        public
        view
        override
        returns (bytes32)
    {
        return StreamPreparedNativeSettlementHash.saleKey(address(this), adapter, saleId, saleNonce);
    }

    function settlePreparedNativePrimarySale(
        StreamPreparedNativeSettlementTypes.Facts calldata facts,
        StreamPreparedNativeSettlementTypes.Intent calldata intent
    )
        external
        payable
        override
        nonReentrant
        returns (StreamPrimarySettlementTypes.PrimarySettlementResult memory result)
    {
        return StreamPreparedNativeSettlementExecution.execute(
            StreamPreparedNativeSettlementExecution.Context(
                core,
                coreCodeHash,
                moduleRegistry,
                moduleRegistryCodeHash,
                resolverCodeHash,
                StreamNativePrimaryExecution.Context(
                    _rightsContext(), revenueEscrow, escrowCodeHash, factoryCodeHash
                )
            ),
            preparedNativeSaleConsumed,
            settlementConsumed,
            _results,
            preparedNativeFactsHash,
            _officialSettled,
            totalOfficialSettled,
            facts,
            intent
        );
    }

    function settlePreparedNativeRightsSale(
        StreamPreparedNativeRightsTypes.Facts calldata facts,
        StreamPreparedNativeRightsTypes.Intent calldata intent
    )
        external
        payable
        override
        nonReentrant
        returns (StreamPrimarySettlementTypes.PrimarySettlementResult memory result)
    {
        return StreamPreparedNativeRightsRecording.execute(
            StreamPreparedNativeRightsRecording.Context(
                core,
                coreCodeHash,
                moduleRegistry,
                moduleRegistryCodeHash,
                resolverCodeHash,
                StreamNativePrimaryExecution.Context(
                    _rightsContext(), revenueEscrow, escrowCodeHash, factoryCodeHash
                )
            ),
            preparedNativeSaleConsumed,
            settlementConsumed,
            _results,
            preparedNativeRightsFactsHash,
            _officialSettled,
            totalOfficialSettled,
            facts,
            intent
        );
    }

    function settlePreparedNativeContentSale(
        StreamPreparedNativeSettlementTypes.Facts calldata facts,
        StreamPreparedNativeSettlementTypes.Intent calldata intent
    )
        external
        payable
        override
        nonReentrant
        returns (StreamPrimarySettlementTypes.PrimarySettlementResult memory result)
    {
        return StreamPreparedNativeContentRecording.execute(
            StreamPreparedNativeContentRecording.Context(
                core,
                coreCodeHash,
                moduleRegistry,
                moduleRegistryCodeHash,
                resolverCodeHash,
                StreamNativePrimaryExecution.Context(
                    _rightsContext(), revenueEscrow, escrowCodeHash, factoryCodeHash
                )
            ),
            preparedNativeSaleConsumed,
            settlementConsumed,
            _results,
            preparedNativeFactsHash,
            preparedNativeContentHash,
            _officialSettled,
            totalOfficialSettled,
            facts,
            intent
        );
    }

    function _custodyAdmissionContext()
        private
        view
        returns (StreamNativeCustodyPrimaryAdmission.Context memory)
    {
        return StreamNativeCustodyPrimaryAdmission.Context(
            core,
            coreCodeHash,
            moduleRegistry,
            moduleRegistryCodeHash,
            custodyGovernanceAuthority,
            custodyGovernanceAuthorityCodeHash
        );
    }

    function canonicalCustodyHouse()
        external
        view
        override
        returns (StreamNativeCustodySettlementTypes.CanonicalHouse memory)
    {
        return _canonicalCustodyHouse;
    }

    function custodyHouseTransition(address house)
        external
        view
        override
        returns (bytes32, bytes32, bytes32)
    {
        return StreamNativeCustodyPrimaryAdmission.transition(
            _custodyAdmissionContext(), _canonicalCustodyHouse, house
        );
    }

    function bindCanonicalCustodyHouse(address house) external override nonReentrant {
        StreamNativeCustodyPrimaryAdmission.bind(
            _custodyAdmissionContext(), _canonicalCustodyHouse, house
        );
    }

    function requireCanonicalCustodyHouse(address house) external view override {
        StreamNativeCustodyPrimaryAdmission.requireCurrent(
            _custodyAdmissionContext(), _canonicalCustodyHouse, house
        );
    }

    function settleNativeCustodyPrimarySale(bytes32 id)
        external
        payable
        override
        nonReentrant
        returns (StreamPrimarySettlementTypes.PrimarySettlementResult memory)
    {
        return StreamNativeCustodyPrimaryRecording.execute(
            StreamNativeCustodyPrimaryRecording.Context(
                _custodyAdmissionContext(),
                resolverCodeHash,
                StreamNativePrimaryExecution.Context(
                    _rightsContext(), revenueEscrow, escrowCodeHash, factoryCodeHash
                )
            ),
            _canonicalCustodyHouse,
            preparedNativeSaleConsumed,
            settlementConsumed,
            _results,
            nativeCustodyFactsHash,
            _officialSettled,
            totalOfficialSettled,
            id
        );
    }

    function settleTokenProfileCustodyPrimarySale(bytes32 id)
        external
        payable
        override
        nonReentrant
        returns (StreamPrimarySettlementTypes.PrimarySettlementResult memory)
    {
        return StreamTokenProfileCustodyRecording.execute(
            StreamTokenProfileCustodyRecording.Context(
                _custodyAdmissionContext(),
                resolverCodeHash,
                StreamNativePrimaryExecution.Context(
                    _rightsContext(), revenueEscrow, escrowCodeHash, factoryCodeHash
                )
            ),
            _canonicalCustodyHouse,
            preparedNativeSaleConsumed,
            settlementConsumed,
            _results,
            nativeCustodyFactsHash,
            _officialSettled,
            totalOfficialSettled,
            id
        );
    }

    function settleCustodyRightsPrimarySale(bytes32 id)
        external
        payable
        override
        nonReentrant
        returns (StreamPrimarySettlementTypes.PrimarySettlementResult memory)
    {
        return StreamCustodyRightsRecording.execute(
            StreamCustodyRightsRecording.Context(
                _custodyAdmissionContext(),
                resolverCodeHash,
                StreamNativePrimaryExecution.Context(
                    _rightsContext(), revenueEscrow, escrowCodeHash, factoryCodeHash
                )
            ),
            _canonicalCustodyHouse,
            preparedNativeSaleConsumed,
            settlementConsumed,
            _results,
            nativeCustodyFactsHash,
            _officialSettled,
            totalOfficialSettled,
            id
        );
    }

    function isStreamPlatformCustodyPrimarySettlement() external pure override returns (bool) {
        return true;
    }

    function settlePlatformCustodyPrimarySale(bytes32 id)
        external
        payable
        override
        nonReentrant
        returns (StreamPrimarySettlementTypes.PrimarySettlementResult memory)
    {
        return StreamPlatformCustodyRecording.execute(
            StreamPlatformCustodyRecording.Context(
                _custodyAdmissionContext(),
                resolverCodeHash,
                StreamNativePrimaryExecution.Context(
                    _rightsContext(), revenueEscrow, escrowCodeHash, factoryCodeHash
                )
            ),
            _canonicalCustodyHouse,
            preparedNativeSaleConsumed,
            settlementConsumed,
            _results,
            nativeCustodyFactsHash,
            _officialSettled,
            totalOfficialSettled,
            id
        );
    }

    function supplementalFloorKey(bytes32 originalKey) public view returns (bytes32) {
        return StreamNativeSupplementalHash.floorKey(address(this), originalKey);
    }

    function nativeSupplementalResult(bytes32 key)
        external
        view
        override
        returns (StreamNativeSupplementalTypes.NativeSupplementalResult memory)
    {
        return _supplementalResults[key];
    }

    function settleNativeSupplementalRevenueFromAdapter(
        StreamNativeSupplementalTypes.NativeSupplementalCandidate calldata candidate
    )
        external
        payable
        override
        nonReentrant
        returns (StreamNativeSupplementalTypes.NativeSupplementalResult memory result)
    {
        StreamNativeSupplementalTypes.NativeSupplementalCandidate memory c = candidate;
        if (msg.sender != c.originalFloor.saleAdapter) {
            revert InvalidNativeSupplementalSettlement();
        }
        bytes32 purchaseKey = supplementalPurchaseKey(c.originalFloor.saleAdapter, c.purchaseId);
        if (supplementalPurchaseConsumed[purchaseKey]) {
            revert SupplementalPurchaseAlreadyConsumed(purchaseKey);
        }
        bytes32 floorKey = supplementalFloorKey(c.purchase.floorSettlementKey);
        if (supplementalFloorConsumed[floorKey]) revert SupplementalFloorAlreadyConsumed(floorKey);
        bytes32 key = settlementKey(
            c.originalFloor.saleAdapter, StreamNativeSupplementalHash.executionId(address(this), c)
        );
        if (settlementConsumed[key]) revert SettlementAlreadyConsumed(key);
        _requireNativeContext();
        if (!settlementConsumed[c.purchase.floorSettlementKey]) {
            revert InvalidNativeSupplementalSettlement();
        }
        StreamDeferredNativeSettlementValidation.Bindings memory bindings =
            StreamDeferredNativeSettlementValidation.Bindings(
                core, moduleRegistry, address(revenueResolver), address(revenueEscrow)
            );
        uint256 amount = StreamNativeSupplementalValidation.validate(
            bindings, c, _results[c.purchase.floorSettlementKey]
        );
        supplementalPurchaseConsumed[purchaseKey] = true;
        supplementalFloorConsumed[floorKey] = true;
        settlementConsumed[key] = true;
        result = StreamNativeSupplementalExecution.fund(
            StreamNativeSupplementalExecution.Context(
                _rightsContext(), revenueEscrow, escrowCodeHash, factoryCodeHash
            ),
            c,
            key,
            amount
        );
        _requireNativeContext();
        StreamNativeSupplementalValidation.requireCurrent(bindings, c);
        StreamPrimarySettlementTypes.PrimarySettlementResult memory common =
            StreamNativeSupplementalExecution.commonResult(c, result);
        _results[key] = common;
        _supplementalResults[key] = result;
        _officialSettled[_totalKey(_CLASS, result.profileId, result.wallet, address(0))] += amount;
        totalOfficialSettled[address(0)] += amount;
        StreamNativeSupplementalExecution.emitResult(c, result, common);
    }

    function _erc20RecordingContext()
        private
        view
        returns (StreamERC20PrimaryRecording.Context memory x)
    {
        x.core = core;
        x.moduleRegistry = moduleRegistry;
        x.revenueResolver = revenueResolver;
        x.splitFactory = splitFactory;
        x.assetPolicyRegistry = assetPolicyRegistry;
        x.coreCodeHash = coreCodeHash;
        x.moduleRegistryCodeHash = moduleRegistryCodeHash;
        x.resolverCodeHash = resolverCodeHash;
        x.factoryCodeHash = factoryCodeHash;
        x.assetRegistryCodeHash = assetRegistryCodeHash;
        x.revenueEscrow = revenueEscrow;
        x.escrowCodeHash = escrowCodeHash;
        x.walletCodeHash = walletCodeHash;
    }

    function _nativeRecordingContext()
        private
        view
        returns (StreamNativePrimaryRecording.Context memory)
    {
        return StreamNativePrimaryRecording.Context(
            core,
            coreCodeHash,
            moduleRegistry,
            moduleRegistryCodeHash,
            resolverCodeHash,
            StreamNativePrimaryExecution.Context(
                _rightsContext(), revenueEscrow, escrowCodeHash, factoryCodeHash
            )
        );
    }

    /// @dev Native payments do not consult ERC20 status or permit-policy availability.
    function _requireNativeContext() private view {
        StreamSettlementAdmission.requireRegistry(
            core, coreCodeHash, moduleRegistry, moduleRegistryCodeHash
        );
        if (address(revenueResolver).codehash != resolverCodeHash) {
            revert InvalidSettlementContext(address(revenueResolver));
        }
        if (address(splitFactory).codehash != factoryCodeHash) {
            revert InvalidSettlementContext(address(splitFactory));
        }
    }

    function _rightsContext() private view returns (StreamPrimarySettlementRights.Context memory) {
        return StreamPrimarySettlementRights.Context(revenueResolver, splitFactory, walletCodeHash);
    }

    function _totalKey(bytes32 revenueClass, bytes32 profileId, address wallet, address asset)
        private
        pure
        returns (bytes32)
    {
        return keccak256(abi.encode(_TOTAL, revenueClass, profileId, wallet, asset));
    }
}
