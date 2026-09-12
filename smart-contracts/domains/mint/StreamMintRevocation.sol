// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../../interfaces/stream/mint/IStreamMintAuthorizationRevocation.sol";
import "../../interfaces/stream/mint/IStreamMintLedger.sol";
import "../../interfaces/stream/mint/IStreamMintLedgerRevocation.sol";
import "./StreamMintTicketHash.sol";
import "./StreamPrivateSaleHash.sol";

/// @notice Full-payload signer validation and exact manager-scoped Ledger voids.
/// @dev The guarded Manager invokes mutable functions through compiler links; direct CALL rejects.
///      Original gate/adapter addresses are domain inputs, not current authorization callbacks.
library StreamMintRevocation {
    struct Context {
        address core;
        address ledger;
        uint256 signatureGas;
    }

    event MintAuthorizationVoided(
        uint16 schemaVersion,
        uint256 indexed collectionId,
        bytes32 indexed phaseId,
        bytes32 indexed authorizationId,
        address authorizer,
        address verifyingContract,
        uint8 family
    );

    function ticketId(StreamMintTicketTypes.MintTicket memory ticket, address gate)
        public
        view
        returns (bytes32)
    {
        return StreamMintTicketHash.authorizationId(
            StreamMintTicketHash.digest(block.chainid, gate, ticket)
        );
    }

    function offerId(StreamPrivateSaleTypes.SaleOffer memory offer) public view returns (bytes32) {
        return StreamMintTicketHash.authorizationId(
            StreamPrivateSaleHash.digest(
                block.chainid, offer.saleAdapter, StreamPrivateSaleHash.offerBody(offer)
            )
        );
    }

    function voidTicket(
        Context memory c,
        StreamMintTicketTypes.MintTicket calldata ticket,
        address gate,
        bytes calldata signature
    ) public returns (bytes32 id) {
        if (
            ticket.chainId != block.chainid || ticket.manager != address(this)
                || ticket.ledger != c.ledger || gate == address(0)
                || ticket.authorizer == address(0)
        ) {
            revert IStreamMintAuthorizationRevocation.MintRevocationInvalidBinding();
        }
        id = ticketId(ticket, gate);
        _authorizer(
            c,
            ticket.authorizer,
            ticket.authorizerKind,
            id,
            StreamMintTicketHash.domain(block.chainid, gate),
            signature
        );
        _void(c.ledger, id);
        emit MintAuthorizationVoided(
            1, ticket.collectionId, ticket.phaseId, id, ticket.authorizer, gate, 0
        );
    }

    function voidOffer(
        Context memory c,
        StreamPrivateSaleTypes.SaleOffer calldata offer,
        uint8 kind,
        bytes calldata signature
    ) public returns (bytes32 id) {
        if (
            offer.chainId != block.chainid || offer.core != c.core || offer.tokenId != 0
                || offer.buyer == address(0) || offer.saleAdapter == address(0)
        ) {
            revert IStreamMintAuthorizationRevocation.MintRevocationInvalidBinding();
        }
        id = offerId(offer);
        _authorizer(
            c,
            offer.buyer,
            kind,
            id,
            StreamPrivateSaleHash.domain(block.chainid, offer.saleAdapter),
            signature
        );
        _void(c.ledger, id);
        emit MintAuthorizationVoided(
            1, offer.collectionId, 0, id, offer.buyer, offer.saleAdapter, 1
        );
    }

    function _authorizer(
        Context memory c,
        address signer,
        uint8 kind,
        bytes32 id,
        bytes32 originalDomain,
        bytes calldata signature
    ) private view {
        if (kind != 1 && kind != 2) {
            revert IStreamMintAuthorizationRevocation.MintRevocationUnsupportedKind(kind);
        }
        if (msg.sender == signer) return;
        bytes32 digest = keccak256(
            abi.encodePacked(
                hex"1901",
                originalDomain,
                StreamMintTicketHash.revocationBody(block.chainid, address(this), c.ledger, id)
            )
        );
        if (!_validSignature(signer, kind, digest, signature, c.signatureGas)) {
            revert IStreamMintAuthorizationRevocation.MintRevocationInvalidSignature(signer);
        }
    }

    function _validSignature(
        address signer,
        uint8 kind,
        bytes32 digest,
        bytes calldata signature,
        uint256 cap
    ) private view returns (bool) {
        if (kind == 1) {
            bytes32 r;
            bytes32 s;
            uint8 v;
            if (signature.length == 65) {
                assembly ("memory-safe") {
                    r := calldataload(signature.offset)
                    s := calldataload(add(signature.offset, 32))
                    v := byte(0, calldataload(add(signature.offset, 64)))
                }
            } else if (signature.length == 64) {
                bytes32 vs;
                assembly ("memory-safe") {
                    r := calldataload(signature.offset)
                    vs := calldataload(add(signature.offset, 32))
                }
                s = bytes32(uint256(vs) & ((uint256(1) << 255) - 1));
                v = uint8((uint256(vs) >> 255) + 27);
            } else {
                return false;
            }
            if (
                uint256(s) > 0x7fffffffffffffffffffffffffffffff5d576e7357a4501ddfe92f46681b20a0
                    || (v != 27 && v != 28)
            ) return false;
            address recovered = ecrecover(digest, v, r, s);
            return recovered != address(0) && recovered == signer;
        }
        return _contractSignature(signer, digest, signature, cap);
    }

    function _contractSignature(
        address signer,
        bytes32 digest,
        bytes calldata signature,
        uint256 cap
    ) private view returns (bool) {
        bytes memory data = abi.encodeWithSelector(bytes4(0x1626ba7e), digest, signature);
        uint256 available = gasleft();
        uint256 required = cap + (cap + 62) / 63 + 40_000;
        if (available < required) {
            revert IStreamMintAuthorizationRevocation.MintRevocationInsufficientGas(
                required, available
            );
        }
        bool ok;
        uint256 size;
        uint256 word;
        assembly ("memory-safe") {
            ok := staticcall(cap, signer, add(data, 32), mload(data), 0, 32)
            size := returndatasize()
            word := mload(0)
        }
        return ok && size == 32 && word == uint256(uint32(0x1626ba7e)) << 224;
    }

    function _void(address ledger, bytes32 id) private {
        if (
            _word(
                    ledger,
                    abi.encodeWithSelector(
                        IERC165.supportsInterface.selector,
                        type(IStreamMintLedgerRevocation).interfaceId
                    )
                ) != 1
        ) {
            revert IStreamMintAuthorizationRevocation.MintLedgerRevocationUnavailable(ledger);
        }
        bytes memory usedCall =
            abi.encodeCall(IStreamMintLedger.isManagerAuthorizationUsed, (address(this), id));
        uint256 used = _word(ledger, usedCall);
        if (used > 1) {
            revert IStreamMintAuthorizationRevocation.MintLedgerRevocationUnavailable(ledger);
        }
        if (used == 1) revert IStreamMintLedger.AuthorizationAlreadyConsumed(id);
        bytes memory data =
            abi.encodeCall(IStreamMintLedgerRevocation.voidAuthorization, (address(this), id));
        bool ok;
        uint256 size;
        assembly ("memory-safe") {
            ok := call(gas(), ledger, 0, add(data, 32), mload(data), 0, 0)
            size := returndatasize()
        }
        if (!ok || size != 0 || _word(ledger, usedCall) != 1) {
            revert IStreamMintAuthorizationRevocation.MintLedgerRevocationUnavailable(ledger);
        }
    }

    function _word(address ledger, bytes memory data) private view returns (uint256 word) {
        bool ok;
        uint256 size;
        assembly ("memory-safe") {
            ok := staticcall(gas(), ledger, add(data, 32), mload(data), 0, 32)
            size := returndatasize()
            word := mload(0)
        }
        if (!ok || size != 32) {
            revert IStreamMintAuthorizationRevocation.MintLedgerRevocationUnavailable(ledger);
        }
    }
}
