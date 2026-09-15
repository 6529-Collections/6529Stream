// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/// @notice Native surplus only: owed credits, escrow and NFTs remain untouched.
interface IStreamNativeSurplus {
    struct NativeSurplusState {
        uint256 balance;
        uint256 liabilities;
        uint256 available;
        uint64 revision;
        uint256 cumulativeSwept;
        bytes32 lastActionId;
    }

    struct NativeSurplusAuthority {
        address executor;
        bytes32 executorCodeHash;
        address roleRegistry;
        bytes32 roleRegistryCodeHash;
        address recipient;
        bytes32 roleChainHash;
        uint64 roleRevision;
    }

    struct NativeSurplusQuote {
        NativeSurplusState state;
        NativeSurplusAuthority authority;
        uint256 amount;
        bytes32 reasonHash;
        bytes32 scopeHash;
        bytes32 oldValueHash;
        bytes32 newValueHash;
    }
    error AdapterSurplusUnderfunded(address asset);
    error NativeSurplusRequestInvalid();
    error NativeSurplusAuthorityInvalid(address target);
    error NativeSurplusActionInvalid();
    error NativeSurplusActionUsed(bytes32 actionId);
    error NativeSurplusTransferFailed();
    error NativeSurplusCallbackChanged();

    event AdapterSurplusSwept(
        uint16 schemaVersion, address indexed to, address asset, uint256 amount, bytes32 actionId
    );
    event NativeSurplusSweepRecorded(
        uint16 schemaVersion,
        address indexed adapter,
        address indexed actor,
        bytes32 indexed actionId,
        address recipient,
        bytes32 domain,
        bytes32 reasonHash,
        uint256 amount,
        uint256 resultingSurplus,
        uint64 revision,
        uint256 cumulativeSwept
    );

    /// @notice Provider-independent accounting read; an insolvent state reports zero available.
    function nativeSurplusState() external view returns (NativeSurplusState memory);
    /// @notice Exact per-call delayed action commitments; balance donations do not alter them.
    function nativeSurplusQuote(uint256 amount, bytes32 reasonHash)
        external
        view
        returns (NativeSurplusQuote memory);
    function nativeSurplusActionUsed(bytes32 actionId) external view returns (bool);
    /// @notice Only the canonical executing delayed governance action may transfer native surplus.
    function sweepNativeSurplus(uint256 amount, bytes32 reasonHash) external returns (uint256);
}
