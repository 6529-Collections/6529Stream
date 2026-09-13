// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../../helpers/DutchSaleTestBase.sol";

contract StreamNativeDutchAuthorityTest is DutchSaleTestBase {
    function _golden(IStreamNativeDutchSale.DutchAuthorization memory a, address consumer)
        private
        view
        returns (bytes32)
    {
        bytes32 structHash = keccak256(
            abi.encode(
                keccak256(
                    "DutchAuthorization(bytes32 saleId,bytes32 saleConfigHash,address payer,address executor,address recipient,address artist,bytes32 tokenDataHash,bytes32 mintCommitment,uint256 executionNonce,bytes32 nonce,uint64 deadline,bytes32 expectedPrimaryPolicyHash,uint256 unitPrice)"
                ),
                a.saleId,
                a.saleConfigHash,
                a.payer,
                a.executor,
                a.recipient,
                a.artist,
                a.tokenDataHash,
                a.mintCommitment,
                a.executionNonce,
                a.nonce,
                a.deadline,
                a.expectedPrimaryPolicyHash,
                a.unitPrice
            )
        );
        bytes32 domain = keccak256(
            abi.encode(
                keccak256(
                    "EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"
                ),
                keccak256("6529StreamNativeDutchSale"),
                keccak256("1"),
                block.chainid,
                consumer
            )
        );
        return keccak256(abi.encodePacked(hex"1901", domain, structHash));
    }

    function testThirteenNamedFieldsAndActualERC5267DomainPinTheUnchangedMaximum() public {
        IStreamNativeDutchSale.DutchPurchaseData memory d = _dutchData(1, payer, payer);
        bytes32 expected = _golden(d.authorization, address(dutchSale));
        require(
            expected == dutchSale.authorizationDigest(d.authorization),
            "independent thirteen fields"
        );
        (
            bytes1 fields,
            string memory name,
            string memory version,
            uint256 chainId,
            address consumer,
            bytes32 salt,
            uint256[] memory extensions
        ) = dutchSale.eip712Domain();
        require(
            fields == 0x0f && keccak256(bytes(name)) == keccak256("6529StreamNativeDutchSale")
                && keccak256(bytes(version)) == keccak256("1") && chainId == block.chainid
                && consumer == address(dutchSale) && salt == 0 && extensions.length == 0,
            "actual discovery"
        );
        for (uint256 field; field < 13; ++field) {
            IStreamNativeDutchSale.DutchAuthorization memory a = abi.decode(
                abi.encode(d.authorization), (IStreamNativeDutchSale.DutchAuthorization)
            );
            if (field == 0) {
                a.saleId = bytes32(uint256(a.saleId) ^ 1);
            } else if (field == 1) {
                a.saleConfigHash = bytes32(uint256(a.saleConfigHash) ^ 1);
            } else if (field == 2) {
                a.payer = address(0xAA);
            } else if (field == 3) {
                a.executor = address(0xBB);
            } else if (field == 4) {
                a.recipient = address(0xCC);
            } else if (field == 5) {
                a.artist = address(0xDD);
            } else if (field == 6) {
                a.tokenDataHash = bytes32(uint256(a.tokenDataHash) ^ 1);
            } else if (field == 7) {
                a.mintCommitment = bytes32(uint256(a.mintCommitment) ^ 1);
            } else if (field == 8) {
                ++a.executionNonce;
            } else if (field == 9) {
                a.nonce = bytes32(uint256(a.nonce) ^ 1);
            } else if (field == 10) {
                ++a.deadline;
            } else if (field == 11) {
                a.expectedPrimaryPolicyHash = bytes32(uint256(a.expectedPrimaryPolicyHash) ^ 1);
            } else {
                ++a.unitPrice;
            }
            require(
                dutchSale.authorizationDigest(a) == _golden(a, consumer)
                    && dutchSale.authorizationDigest(a) != expected,
                "one named field"
            );
        }
        vm.warp(1009);
        vm.prank(payer);
        dutchSale.purchase{ value: 1100 }(d);
        require(
            refundManager.lastAuthorizationId()
                    == keccak256(
                        abi.encode(keccak256("6529STREAM_MINT_TICKET_AUTHORIZATION_V1"), expected)
                    ) && wallet.balance == 190,
            "late inclusion keeps full old proof maximum"
        );
    }

    function testWrongConsumerProofRejectsBeforeFundingThenOriginalProofExecutes() public {
        IStreamNativeDutchSale.DutchPurchaseData memory d = _dutchData(1, payer, payer);
        bytes32 wrong = _golden(d.authorization, address(0x1234));
        d.platformSignature = _sign(PLATFORM_KEY, wrong);
        d.artistSignature = _sign(ARTIST_KEY, wrong);
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamNativeDutchSale.DutchSignatureInvalid.selector, vm.addr(PLATFORM_KEY)
            )
        );
        vm.prank(payer);
        dutchSale.purchase{ value: 1100 }(d);
        require(
            wallet.balance == 0 && recorder.totalOfficialSettled(address(0)) == 0
                && !dutchSale.authorizationUsed(artist, bytes32(uint256(1))),
            "bad domain did not consume money or proof"
        );
        _signDutch(d);
        vm.prank(payer);
        dutchSale.purchase{ value: 1100 }(d);
        require(wallet.balance == 1000, "healthy original domain");
    }
}
