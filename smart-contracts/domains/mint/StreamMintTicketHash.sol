// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../../interfaces/stream/mint/StreamMintTicketTypes.sol";

/// @notice Canonical MPA-TICKET hashes. These helpers confer no signer or mint authority.
library StreamMintTicketHash {
    bytes32 internal constant TICKET_TYPEHASH = keccak256(
        "MintTicket(uint256 chainId,address manager,address ledger,uint256 collectionId,bytes32 phaseId,address executor,address payer,address authorizer,uint8 authorizerKind,bytes32 initialRecipientsHash,bytes32 beneficiariesHash,bytes32 tokenDataArrayHash,bytes32 mintCommitmentsHash,uint256 quantity,bytes32 contextHash,bytes32 policyHash,bytes32 nonce,uint64 deadline)"
    );
    bytes32 internal constant REVOCATION_TYPEHASH = keccak256(
        "MintTicketRevocation(uint256 chainId,address manager,address ledger,bytes32 authorizationId)"
    );
    bytes32 internal constant AUTHORIZATION_DOMAIN =
        keccak256("6529STREAM_MINT_TICKET_AUTHORIZATION_V1");

    function domain(uint256 chainId, address gate) internal pure returns (bytes32) {
        return keccak256(
            abi.encode(
                keccak256(
                    "EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"
                ),
                keccak256("6529Stream Mint Tickets"),
                keccak256("1"),
                chainId,
                gate
            )
        );
    }

    function body(StreamMintTicketTypes.MintTicket memory ticket) internal pure returns (bytes32) {
        return keccak256(abi.encode(TICKET_TYPEHASH, ticket));
    }

    function digest(uint256 chainId, address gate, StreamMintTicketTypes.MintTicket memory ticket)
        internal
        pure
        returns (bytes32)
    {
        return keccak256(abi.encodePacked(hex"1901", domain(chainId, gate), body(ticket)));
    }

    function authorizationId(bytes32 fullEip712Digest) internal pure returns (bytes32) {
        return keccak256(abi.encode(AUTHORIZATION_DOMAIN, fullEip712Digest));
    }

    function revocationBody(uint256 chainId, address manager, address ledger, bytes32 id)
        internal
        pure
        returns (bytes32)
    {
        return keccak256(abi.encode(REVOCATION_TYPEHASH, chainId, manager, ledger, id));
    }
}
