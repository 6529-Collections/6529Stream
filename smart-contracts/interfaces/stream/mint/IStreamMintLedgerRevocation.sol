// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "../../../vendor/openzeppelin/IERC165.sol";

/// @notice Additive MPA-LEDGER permanent revocation capability; old ledger identity is preserved.
interface IStreamMintLedgerRevocation is IERC165 {
    error InvalidAuthorizationManager(address manager, address caller);
    error InvalidAuthorizationId(bytes32 authorizationId);

    event MintLedgerAuthorizationVoided(
        uint16 schemaVersion, bytes32 indexed authorizationId, address indexed manager
    );

    /// @dev Only an authorized writer may void, and manager must equal msg.sender.
    ///      Uses the same durable used map as consume, without phase/counter/root writes.
    function voidAuthorization(address manager, bytes32 authorizationId) external;
}
