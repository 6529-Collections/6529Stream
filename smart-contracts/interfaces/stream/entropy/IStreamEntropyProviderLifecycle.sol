// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "../../../vendor/openzeppelin/IERC165.sol";

/// @notice Numeric lifecycle shared with the canonical module-state vocabulary.
enum EntropyProviderState {
    UNKNOWN,
    ACTIVE,
    DEPRECATED,
    INCIDENT_REVOKED
}

/// @notice Coordinator-owned provider admission; no post-mint migration or fresh draw authority.
interface IStreamEntropyProviderLifecycle is IERC165 {
    struct ProviderRecord {
        EntropyProviderState state;
        bytes32 runtimeCodeHash;
        uint64 revision;
        bytes32 reasonHash;
        bytes32 lastActionId;
    }
    error InvalidProviderTransition(
        address provider, EntropyProviderState oldState, EntropyProviderState newState
    );
    error EntropyProviderUnavailable(address provider, EntropyProviderState state);
    error ProviderLifecycleInvalidReason();
    error ProviderLifecycleUnauthorized(address caller);
    error ProviderLifecycleInvalidContext();
    error ProviderLifecycleWrongClass(uint8 expected, uint8 actual);
    error ProviderLifecycleReplay(address provider, bytes32 actionId);
    error ProviderLifecycleRevisionOverflow(address provider);
    error ProviderIndexOutOfBounds(uint256 index);
    event EntropyProviderStateUpdated(
        uint16 schemaVersion,
        address indexed provider,
        bytes32 indexed actionId,
        EntropyProviderState oldState,
        EntropyProviderState newState,
        string reasonURI
    );
    function entropyProviderRecord(address provider) external view returns (ProviderRecord memory);
    function entropyProviderCount() external view returns (uint256);
    function entropyProviderAt(uint256 index) external view returns (address);
    /// @notice Class-1 admission or restoration; checks the live adapter and binds its runtime.
    function activateEntropyProvider(address provider, string calldata reasonURI) external;
    /// @notice Class-0 ACTIVE→DEPRECATED; existing requests retain their fulfillment route.
    function deprecateEntropyProvider(address provider, string calldata reasonURI) external;
    /// @notice Class-0 ACTIVE/DEPRECATED→INCIDENT_REVOKED, without deleting any history.
    function revokeEntropyProvider(address provider, string calldata reasonURI) external;
    /// @notice Exact canonical scope/old/new commitments and class for the named new state.
    function entropyProviderTransition(
        address provider,
        EntropyProviderState next,
        string calldata reasonURI
    ) external view returns (bytes32 scope, bytes32 oldHash, bytes32 newHash, uint8 actionClass);
    /// @notice Exact class-1 compatibility transition for the original setProviderRevoked selector.
    function providerRevocationTransition(address provider, bool revoked)
        external
        view
        returns (bytes32 scope, bytes32 oldHash, bytes32 newHash);
}
