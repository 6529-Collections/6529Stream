// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "../../../vendor/openzeppelin/IERC165.sol";
import "./StreamMintTicketTypes.sol";
import "./StreamPrivateSaleTypes.sol";

/// @notice Full-payload signer revocation. No bare digest or signer-ownership lookup is admitted.
interface IStreamMintAuthorizationRevocation is IERC165 {
    error MintRevocationInvalidBinding();
    error MintRevocationUnsupportedKind(uint8 authorizerKind);
    error MintRevocationInvalidSignature(address authorizer);
    error MintRevocationInsufficientGas(uint256 required, uint256 available);
    error MintLedgerRevocationUnavailable(address ledger);

    /// @dev family0 is MintTicket; family1 is a primary-mint SaleOffer.
    event MintAuthorizationVoided(
        uint16 schemaVersion,
        uint256 indexed collectionId,
        bytes32 indexed phaseId,
        bytes32 indexed authorizationId,
        address authorizer,
        address verifyingContract,
        uint8 family
    );

    function mintTicketAuthorizationId(
        StreamMintTicketTypes.MintTicket calldata ticket,
        address verifyingGate
    ) external view returns (bytes32);

    function mintOfferAuthorizationId(StreamPrivateSaleTypes.SaleOffer calldata offer)
        external
        view
        returns (bytes32);

    /// @dev Direct original authorizer or valid MintTicketRevocation signature under the
    ///      original ticket domain. Old expiry/policy/gate liveness do not block a void.
    function voidMintTicket(
        StreamMintTicketTypes.MintTicket calldata ticket,
        address verifyingGate,
        bytes calldata revocationSignature
    ) external returns (bytes32 authorizationId);

    /// @dev The original Sales domain and the permanent MintTicketRevocation tuple are used.
    ///      tokenId must be zero; this does not revoke custody-path offers in adapter storage.
    function voidMintOffer(
        StreamPrivateSaleTypes.SaleOffer calldata offer,
        uint8 buyerKind,
        bytes calldata revocationSignature
    ) external returns (bytes32 authorizationId);
}
