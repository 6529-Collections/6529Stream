// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "../../../smart-contracts/domains/mint/StreamMintTicketHash.sol";

contract StreamMintTicketHashTest {
    function _ticket() private pure returns (StreamMintTicketTypes.MintTicket memory t) {
        t.chainId = 11;
        t.manager = address(12);
        t.ledger = address(13);
        t.collectionId = 14;
        t.phaseId = bytes32(uint256(15));
        t.executor = address(16);
        t.payer = address(17);
        t.authorizer = address(18);
        t.authorizerKind = 2;
        t.initialRecipientsHash = bytes32(uint256(20));
        t.beneficiariesHash = bytes32(uint256(21));
        t.tokenDataArrayHash = bytes32(uint256(22));
        t.mintCommitmentsHash = bytes32(uint256(23));
        t.quantity = 24;
        t.contextHash = bytes32(uint256(25));
        t.policyHash = bytes32(uint256(26));
        t.nonce = bytes32(uint256(27));
        t.deadline = 28;
    }

    function _namedBody(StreamMintTicketTypes.MintTicket memory t) private pure returns (bytes32) {
        return keccak256(
            bytes.concat(
                abi.encode(
                    bytes32(0x8bebeeccaa47d5cdada1485a88dfd7933c17ca5dde68b2d549dcf1bd38e0bfa8),
                    t.chainId,
                    t.manager,
                    t.ledger,
                    t.collectionId,
                    t.phaseId,
                    t.executor
                ),
                abi.encode(
                    t.payer,
                    t.authorizer,
                    t.authorizerKind,
                    t.initialRecipientsHash,
                    t.beneficiariesHash,
                    t.tokenDataArrayHash
                ),
                abi.encode(
                    t.mintCommitmentsHash,
                    t.quantity,
                    t.contextHash,
                    t.policyHash,
                    t.nonce,
                    t.deadline
                )
            )
        );
    }

    function testLiteralTypesAndAllEighteenNamedTicketFields() external pure {
        require(
            StreamMintTicketHash.TICKET_TYPEHASH
                == 0x8bebeeccaa47d5cdada1485a88dfd7933c17ca5dde68b2d549dcf1bd38e0bfa8
        );
        require(
            StreamMintTicketHash.REVOCATION_TYPEHASH
                == 0xdbe06065e5132b7c1a8d3c3351245e27c1d3708e694c3e79fcdc491e22f3d7aa
        );
        require(
            StreamMintTicketHash.AUTHORIZATION_DOMAIN
                == 0x255ffcce76be6ac89667675f1a7d2fb20ee56b101da7daddc9d13697a1217d97
        );
        StreamMintTicketTypes.MintTicket memory t = _ticket();
        bytes32 original = _namedBody(t);
        require(StreamMintTicketHash.body(t) == original);
        for (uint256 i; i < 18; ++i) {
            StreamMintTicketTypes.MintTicket memory changed =
                abi.decode(abi.encode(t), (StreamMintTicketTypes.MintTicket));
            // Every fixture word remains within its declared narrow width after increment.
            assembly ("memory-safe") {
                let p := add(changed, mul(i, 32))
                mstore(p, add(mload(p), 1))
            }
            require(StreamMintTicketHash.body(changed) == _namedBody(changed));
            require(_namedBody(changed) != original);
        }
    }

    function testFullDomainDigestAndLedgerWrapAreSeparateFromRawBody() external pure {
        StreamMintTicketTypes.MintTicket memory t = _ticket();
        address gate = address(29);
        bytes32 expectedDomain = keccak256(
            abi.encode(
                keccak256(
                    "EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"
                ),
                keccak256("6529Stream Mint Tickets"),
                keccak256("1"),
                t.chainId,
                gate
            )
        );
        bytes32 expectedDigest =
            keccak256(abi.encodePacked(hex"1901", expectedDomain, _namedBody(t)));
        require(StreamMintTicketHash.digest(t.chainId, gate, t) == expectedDigest);
        bytes32 id = keccak256(
            abi.encode(
                bytes32(0x255ffcce76be6ac89667675f1a7d2fb20ee56b101da7daddc9d13697a1217d97),
                expectedDigest
            )
        );
        require(StreamMintTicketHash.authorizationId(expectedDigest) == id);
        require(id != expectedDigest && id != StreamMintTicketHash.authorizationId(_namedBody(t)));
        require(StreamMintTicketHash.digest(t.chainId + 1, gate, t) != expectedDigest);
        require(StreamMintTicketHash.digest(t.chainId, address(30), t) != expectedDigest);
        bytes32 revocation = keccak256(
            abi.encode(
                bytes32(0xdbe06065e5132b7c1a8d3c3351245e27c1d3708e694c3e79fcdc491e22f3d7aa),
                t.chainId,
                t.manager,
                t.ledger,
                id
            )
        );
        require(
            StreamMintTicketHash.revocationBody(t.chainId, t.manager, t.ledger, id) == revocation
        );
        require(
            StreamMintTicketHash.revocationBody(t.chainId, address(31), t.ledger, id) != revocation
        );
        require(
            StreamMintTicketHash.revocationBody(t.chainId, t.manager, address(32), id) != revocation
        );
    }

    function testFuzzFullWidthTicketNonceQuantityAndContext(
        uint256 quantity,
        bytes32 nonce,
        bytes32 context
    ) external pure {
        StreamMintTicketTypes.MintTicket memory t = _ticket();
        t.quantity = quantity;
        t.nonce = nonce;
        t.contextHash = context;
        require(StreamMintTicketHash.body(t) == _namedBody(t));
    }
}
