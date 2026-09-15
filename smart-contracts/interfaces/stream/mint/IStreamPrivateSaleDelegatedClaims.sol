// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/// @notice Live NFTDelegation-triggered claims; delegates can never choose another recipient.
/// @dev The witness locates an original registry row; it contains no caller-supplied authority.
interface IStreamPrivateSaleDelegatedClaims {
    struct DelegationWitness {
        bool walletWide;
        uint256 index;
    }
    function delegateRegistry() external view returns (address);
    function delegateRegistryCodeHash() external view returns (bytes32);
    function delegationUsecase() external view returns (uint256);
    function delegationManifest() external view returns (bytes memory);
    function claimRefundFor(bytes32 saleId, address account, DelegationWitness calldata witness)
        external
        returns (uint256 amount);
    function claimNftFor(bytes32 saleId, address account, DelegationWitness calldata witness)
        external
        returns (bool delivered);
    function claimInventoryNftFor(
        bytes32 saleId,
        uint256 tokenId,
        address account,
        DelegationWitness calldata witness
    ) external returns (bool delivered);
}
