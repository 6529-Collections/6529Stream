// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../../helpers/UniversalSettlementTestBase.sol";

interface UniversalAuthorizationCallVm {
    function expectCall(address target, bytes calldata data) external;
}

contract StreamUniversalAuthorizationIdentityTest is UniversalSettlementTestBase {
    function testExactFullDigestAuthorizationReachesManagerPreviewAndExecution() public {
        (
            IStreamUniversalFixedPriceSaleAdapter.SaleExecutionData memory e,
            StreamPrimarySettlementTypes.ERC20SettlementCandidate memory c
        ) = _execution(payer, payer, payer, 1);
        bytes32 original = _digest(e.authorization, block.chainid, address(sale));
        IStreamMintManager.MintBatch memory b = _batch(e, original);
        require(
            c.operationIdentityCommitment == keccak256(abi.encode(b, address(sale), uint256(0))),
            "independent exact batch identity"
        );
        // Changing just a signed field changes its ledger authorization identity, before any lane is consumed.
        e.authorization.recipient = address(0xBEEF);
        bytes32 changed = _digest(e.authorization, block.chainid, address(sale));
        require(changed != original, "recipient changes full digest");
        e.platformSignature = _sign(PLATFORM_KEY, changed);
        e.artistSignature = _sign(ARTIST_KEY, changed);
        b = _batch(e, changed);
        UniversalAuthorizationCallVm(address(vm))
            .expectCall(
                address(manager),
                abi.encodeCall(IStreamMintReads.previewSingleStepMintOperation, (b, bytes("")))
            );
        c = sale.previewExecution(e);
        require(
            c.operationIdentityCommitment == keccak256(abi.encode(b, address(sale), uint256(0))),
            "changed field changes exact manager root"
        );
        UniversalAuthorizationCallVm(address(vm))
            .expectCall(
                address(manager),
                abi.encodeCall(IStreamMintManager.executeSingleStepMint, (b, bytes("")))
            );
        vm.prank(payer);
        payment.settleERC20PrimarySaleByPayer(c, abi.encode(e));
        require(
            manager.ownerOf(1) == address(0xBEEF)
                && sale.authorizationUsed(artist, e.authorization.nonce)
                && sale.executionIdByNonce(saleId, 1) == c.executionBinding.executionId,
            "mint plus independent replay lanes"
        );
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamUniversalFixedPriceSaleAdapter.UniversalAuthorizationUsed.selector,
                artist,
                e.authorization.nonce
            )
        );
        sale.previewExecution(e);
    }

    function testChainAndVerifyingContractDomainsCannotAuthorizeTheCanonicalBatch() public {
        (IStreamUniversalFixedPriceSaleAdapter.SaleExecutionData memory e,) =
            _execution(payer, payer, payer, 1);
        bytes32 correct = _digest(e.authorization, block.chainid, address(sale));
        for (uint256 i; i < 2; ++i) {
            bytes32 wrong = _digest(
                e.authorization,
                i == 0 ? block.chainid + 1 : block.chainid,
                i == 0 ? address(sale) : address(0xBAD)
            );
            require(wrong != correct, "domain is material to full ID");
            e.platformSignature = _sign(PLATFORM_KEY, wrong);
            e.artistSignature = _sign(ARTIST_KEY, wrong);
            vm.expectRevert(
                abi.encodeWithSelector(
                    IStreamUniversalFixedPriceSaleAdapter.UniversalSaleSignatureInvalid.selector,
                    vm.addr(PLATFORM_KEY)
                )
            );
            sale.previewExecution(e);
        }
        require(
            !sale.authorizationUsed(artist, e.authorization.nonce)
                && sale.executionIdByNonce(saleId, 1) == 0 && token.balanceOf(payer) == 10000
                && manager.nonce() == 0,
            "wrong-domain checks leave all lanes untouched"
        );
    }

    function _digest(
        IStreamUniversalFixedPriceSaleAdapter.SaleAuthorization memory a,
        uint256 chain,
        address verifier
    ) private pure returns (bytes32) {
        bytes32 domain = keccak256(
            abi.encode(
                keccak256(
                    "EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"
                ),
                keccak256("6529StreamUniversalFixedPriceSaleAdapter"),
                keccak256("1"),
                chain,
                verifier
            )
        );
        bytes32 typeHash = keccak256(
            "UniversalSaleAuthorization(bytes32 saleId,bytes32 saleConfigHash,address payer,address executor,address recipient,address artist,bytes32 tokenDataHash,bytes32 mintCommitment,uint256 executionNonce,bytes32 nonce,uint64 deadline)"
        );
        return keccak256(abi.encodePacked(hex"1901", domain, keccak256(abi.encode(typeHash, a))));
    }

    function _batch(
        IStreamUniversalFixedPriceSaleAdapter.SaleExecutionData memory e,
        bytes32 digest
    ) private view returns (IStreamMintManager.MintBatch memory b) {
        IStreamUniversalFixedPriceSaleAdapter.SaleConfig memory config =
        sale.saleRecord(saleId).config;
        b.collectionId = config.collectionId;
        b.phaseId = config.phaseId;
        b.payer = e.authorization.payer;
        b.initialRecipients = new address[](1);
        b.initialRecipients[0] = e.authorization.recipient;
        b.beneficiaries = new address[](1);
        b.beneficiaries[0] = e.authorization.recipient;
        b.tokenData = new bytes[](1);
        b.tokenData[0] = e.tokenData;
        b.mintCommitments = new bytes32[](1);
        b.mintCommitments[0] = e.authorization.mintCommitment;
        b.expectedPolicyHash = config.mintPolicyHash;
        b.authorizationId =
            keccak256(abi.encode(keccak256("6529STREAM_MINT_TICKET_AUTHORIZATION_V1"), digest));
        b.contextHash = digest;
    }
}
