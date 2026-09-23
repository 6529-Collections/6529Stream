// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "../../../smart-contracts/domains/mint/StreamPrivateSaleHash.sol";

/// @dev Pure permanent-wire oracle only; no consumer, signer authority or replay acceptance.
contract StreamPrivateSaleHashTest {
    function testSixLiteralNormativeTypehashes() external pure {
        require(
            StreamPrivateSaleHash.AUTHORIZATION_TYPEHASH
                == 0x6e5460498aa6274ffa516d53c6046a385c1ff9dd62d6adbfc54c339a4bb6e8d6
        );
        require(
            StreamPrivateSaleHash.OFFER_TYPEHASH
                == 0x5befc984e6ca9dc13fb8238b12d2d8c7f77bcfbe46489470a66bbdda2b482d1b
        );
        require(
            StreamPrivateSaleHash.CUSTODY_GRANT_TYPEHASH
                == 0xb829ff4936e00a75578357cfc3d855c59e780debb698eb3e8c8e9aff1b013041
        );
        require(
            StreamPrivateSaleHash.OFFER_REVOCATION_TYPEHASH
                == 0xb80f6e5d7ac663ccfb28bbcfae73c4b3111804ebe80d7ac845e1eb88a44d191c
        );
        require(
            StreamPrivateSaleHash.AUTHORIZATION_REVOCATION_TYPEHASH
                == 0x41d0d127fea4cbca0630f242fe7375e83ff775d8215636ae1fdd92b3d481a455
        );
        require(
            StreamPrivateSaleHash.CUSTODY_GRANT_REVOCATION_TYPEHASH
                == 0x56747c6d524c5e2b5568c382f06c2f3c787067868f362f65933656e7a67e8344
        );
    }

    function testAllTwentyFourAuthorizationFieldsInPermanentOrder() external pure {
        StreamPrivateSaleTypes.SaleAuthorization memory a;
        a.chainId = 1001;
        a.saleAdapter = address(1002);
        a.mintManager = address(1003);
        a.collectionId = 1004;
        a.phaseId = bytes32(uint256(1005));
        a.saleId = bytes32(uint256(1006));
        a.saleKind = 7;
        a.revenueClass = bytes32(uint256(1008));
        a.expectedPrimaryPolicyHash = bytes32(uint256(1009));
        a.primaryPolicyMode = 10;
        a.initialRecipientsHash = bytes32(uint256(1011));
        a.beneficiariesHash = bytes32(uint256(1012));
        a.tokenDataArrayHash = bytes32(uint256(1013));
        a.mintCommitmentsHash = bytes32(uint256(1014));
        a.payer = address(1015);
        a.executor = address(1016);
        a.asset = address(1017);
        a.unitPrice = type(uint256).max - 18;
        a.quantity = 1019;
        a.contentSelectionHash = bytes32(uint256(1020));
        a.policyHash = bytes32(uint256(1021));
        a.nonce = bytes32(uint256(1022));
        a.deadline = 1023;
        a.finalizeBy = 1024;
        // Concatenate fixed words named in the permanent type string; do not encode the struct.
        bytes memory first = abi.encode(
            bytes32(0x6e5460498aa6274ffa516d53c6046a385c1ff9dd62d6adbfc54c339a4bb6e8d6),
            a.chainId,
            a.saleAdapter,
            a.mintManager,
            a.collectionId,
            a.phaseId,
            a.saleId
        );
        bytes memory second = abi.encode(
            a.saleKind,
            a.revenueClass,
            a.expectedPrimaryPolicyHash,
            a.primaryPolicyMode,
            a.initialRecipientsHash,
            a.beneficiariesHash
        );
        bytes memory third = abi.encode(
            a.tokenDataArrayHash, a.mintCommitmentsHash, a.payer, a.executor, a.asset, a.unitPrice
        );
        bytes memory fourth = abi.encode(
            a.quantity, a.contentSelectionHash, a.policyHash, a.nonce, a.deadline, a.finalizeBy
        );
        require(
            StreamPrivateSaleHash.authorizationBody(a)
                == keccak256(bytes.concat(first, second, third, fourth)),
            "all24 named words plus literal typehash"
        );
    }

    function testOfferAndGrantNamedFieldsAndDistinctDigestFamilies() external pure {
        StreamPrivateSaleTypes.SaleOffer memory o = StreamPrivateSaleTypes.SaleOffer(
            1,
            address(2),
            address(3),
            4,
            5,
            bytes32(uint256(6)),
            address(7),
            address(8),
            9,
            bytes32(uint256(10)),
            11,
            12
        );
        bytes memory first = abi.encode(
            bytes32(0x5befc984e6ca9dc13fb8238b12d2d8c7f77bcfbe46489470a66bbdda2b482d1b),
            o.chainId,
            o.saleAdapter,
            o.core,
            o.collectionId,
            o.tokenId,
            o.contentSelectionHash
        );
        bytes memory second = abi.encode(
            o.buyer, o.asset, o.price, o.nonce, o.deadline, o.finalizeBy
        );
        require(
            StreamPrivateSaleHash.offerBody(o) == keccak256(bytes.concat(first, second)),
            "all12 offer fields"
        );
        StreamPrivateSaleTypes.SaleCustodyGrant memory g = StreamPrivateSaleTypes.SaleCustodyGrant(
            1,
            address(2),
            address(3),
            5,
            address(7),
            StreamPrivateSaleHash.offerBody(o),
            bytes32(uint256(10)),
            11
        );
        require(
            StreamPrivateSaleHash.custodyGrantBody(g)
                == keccak256(
                    abi.encode(
                        bytes32(0xb829ff4936e00a75578357cfc3d855c59e780debb698eb3e8c8e9aff1b013041),
                        g.chainId,
                        g.saleAdapter,
                        g.core,
                        g.tokenId,
                        g.owner,
                        g.saleRef,
                        g.nonce,
                        g.deadline
                    )
                ),
            "all8 grant fields"
        );
        require(
            StreamPrivateSaleHash.offerBody(o) != StreamPrivateSaleHash.custodyGrantBody(g),
            "separate family identity"
        );
    }

    function testNamedRevocationsAndDomainCannotAliasAcrossFamiliesOrAdapters() external pure {
        uint256 chain = 6529;
        address adapter = address(0xAD);
        address account = address(0xCA);
        bytes32 body = keccak256("full digest");
        bytes32 offer = StreamPrivateSaleHash.offerRevocationBody(chain, adapter, body);
        bytes32 auth =
            StreamPrivateSaleHash.authorizationRevocationBody(chain, adapter, account, body);
        bytes32 grant =
            StreamPrivateSaleHash.custodyGrantRevocationBody(chain, adapter, account, body);
        require(
            offer
                == keccak256(
                    abi.encode(
                        bytes32(0xb80f6e5d7ac663ccfb28bbcfae73c4b3111804ebe80d7ac845e1eb88a44d191c),
                        chain,
                        adapter,
                        body
                    )
                )
        );
        require(
            auth
                == keccak256(
                    abi.encode(
                        bytes32(0x41d0d127fea4cbca0630f242fe7375e83ff775d8215636ae1fdd92b3d481a455),
                        chain,
                        adapter,
                        account,
                        body
                    )
                )
        );
        require(
            grant
                == keccak256(
                    abi.encode(
                        bytes32(0x56747c6d524c5e2b5568c382f06c2f3c787067868f362f65933656e7a67e8344),
                        chain,
                        adapter,
                        account,
                        body
                    )
                )
        );
        bytes32 domain = keccak256(
            abi.encode(
                keccak256(
                    "EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"
                ),
                keccak256("6529Stream Sales"),
                keccak256("1"),
                chain,
                adapter
            )
        );
        require(StreamPrivateSaleHash.domain(chain, adapter) == domain);
        bytes32 digest = StreamPrivateSaleHash.digest(chain, adapter, offer);
        require(digest == keccak256(abi.encodePacked(hex"1901", domain, offer)));
        require(
            digest != StreamPrivateSaleHash.digest(chain, adapter, auth)
                && digest != StreamPrivateSaleHash.digest(chain, adapter, grant)
                && digest != StreamPrivateSaleHash.digest(chain + 1, adapter, offer)
                && digest != StreamPrivateSaleHash.digest(chain, address(0xAE), offer)
        );
    }

    function testFuzzFullWidthOfferWords(uint256 price, uint256 tokenId, bytes32 nonce)
        external
        pure
    {
        StreamPrivateSaleTypes.SaleOffer memory o = StreamPrivateSaleTypes.SaleOffer(
            1,
            address(2),
            address(3),
            4,
            tokenId,
            bytes32(uint256(6)),
            address(7),
            address(8),
            price,
            nonce,
            11,
            12
        );
        bytes memory first = abi.encode(
            bytes32(0x5befc984e6ca9dc13fb8238b12d2d8c7f77bcfbe46489470a66bbdda2b482d1b),
            uint256(1),
            address(2),
            address(3),
            uint256(4),
            tokenId,
            bytes32(uint256(6))
        );
        bytes memory second = abi.encode(
            address(7), address(8), price, nonce, uint64(11), uint64(12)
        );
        require(StreamPrivateSaleHash.offerBody(o) == keccak256(bytes.concat(first, second)));
    }
}
