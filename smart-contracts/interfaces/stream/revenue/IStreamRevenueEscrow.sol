// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../parameters/IStreamGasParameterHost.sol";

/// @notice Owed revenue retained for exact immutable split-wallet destinations.
interface IStreamRevenueEscrow is IStreamGasParameterHost {
    error InvalidEscrowConfiguration();
    error InvalidEscrowCredit();
    error InvalidEscrowProducer(address producer);
    error InvalidEscrowProducerAction();
    error EscrowFactoryCodeChanged(address factory);
    error EscrowUnknownProfile(bytes32 profileId);
    error EscrowWalletMismatch(bytes32 profileId, address wallet);
    error EscrowFixedWalletUndeployed(bytes32 profileId, address wallet);
    error WrongCodeAtWallet(address wallet, bytes32 expected, bytes32 actual);
    error NoEscrowCredit();
    error EscrowAssetNotActive(address asset, uint256 status);
    error EscrowReadFailed(address target, bytes4 selector);
    error EscrowTransferInvariantBroken(address asset);
    error EscrowInsolvent(address asset, uint256 balance, uint256 owed);
    error InsufficientEscrowGas(uint256 required, uint256 available);
    error InsufficientEscrowCallGas(uint256 gasLimit, uint256 available, uint256 reserve);
    error EscrowExternalCallFailed(
        address target, bytes4 selector, uint256 returnDataSize, bytes reasonPrefix
    );

    event EscrowCreditCreated(
        bytes32 indexed revenueClass,
        bytes32 indexed profileId,
        address indexed wallet,
        uint16 schemaVersion,
        address asset,
        uint256 amount,
        uint256 totalOwed,
        bytes32 escrowRuntimeCodeHash
    );
    event EscrowFlushed(
        bytes32 indexed revenueClass,
        bytes32 indexed profileId,
        address indexed wallet,
        uint16 schemaVersion,
        address asset,
        uint256 amount,
        uint256 remainingOwed
    );
    event EscrowProducerUpdated(
        uint16 schemaVersion,
        address indexed producer,
        bytes32 indexed admittedCodeHash,
        bytes32 indexed actionId,
        bool enabled,
        uint64 revision
    );

    function creditNative(
        bytes32 revenueClass,
        bytes32 profileId,
        address wallet,
        bool templateOrigin
    ) external payable;
    /// @dev Pulls only from the admitted producer; never accepts an arbitrary payer address.
    function creditERC20(
        bytes32 revenueClass,
        bytes32 profileId,
        address wallet,
        address asset,
        uint256 amount,
        bool templateOrigin
    ) external;
    function escrowOwed(bytes32 revenueClass, bytes32 profileId, address wallet, address asset)
        external
        view
        returns (uint256);
    function escrowCreditIdentity(
        bytes32 revenueClass,
        bytes32 profileId,
        address wallet,
        address asset
    ) external view returns (address factory, bytes32 factoryCodeHash, bytes32 walletCodeHash);
    function totalOwed(address asset) external view returns (uint256);
    function surplus(address asset) external view returns (uint256);
    function flushEscrow(bytes32 revenueClass, bytes32 profileId, address wallet, address asset)
        external;
    function flushToVerifiedWalletBestEffort(
        bytes32 revenueClass,
        bytes32 profileId,
        address wallet,
        address asset
    ) external;
    function setCreditProducer(address producer, bool enabled) external;
    function creditProducer(address producer)
        external
        view
        returns (bool enabled, bytes32 codeHash, uint64 revision);
    function creditProducerTransitionHashes(address producer, bool enabled)
        external
        view
        returns (bytes32 scopeHash, bytes32 oldStateHash, bytes32 newStateHash);
    function gasParameterFloor(bytes32 parameterId) external view returns (uint256);
}
