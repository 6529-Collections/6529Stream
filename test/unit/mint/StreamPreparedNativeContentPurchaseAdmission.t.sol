// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "../../regression/legacy/helpers/CharacterizationTestBase.sol";
import "../../../smart-contracts/domains/mint/StreamPreparedNativeContentPurchaseHash.sol";

contract CuratedPurchaseHashHarness {
    function check(
        IStreamMintManager.MintBatch calldata b,
        StreamPreparedNativeContentPurchaseTypes.GateData calldata d,
        StreamPreparedNativeContentPurchaseTypes.Purchase calldata p,
        StreamPreparedNativeSettlementTypes.Intent calldata i
    ) external view {
        StreamPreparedNativeContentPurchaseHash.requireAuthorization(b, d, p, i);
    }

    function readPurchase(
        address house,
        bytes32 intentHash,
        StreamPreparedNativeSettlementTypes.Intent calldata i
    ) external view returns (StreamPreparedNativeContentPurchaseTypes.Purchase memory) {
        return StreamPreparedNativeContentPurchaseHash.readPurchase(house, intentHash, i);
    }
}

/// @dev Focused actual batch codec boundary. This is not a gate signature or full paid-mint fixture.
contract StreamPreparedNativeContentPurchaseAdmissionTest is CharacterizationTestBase {
    CuratedPurchaseHashHarness private harness;
    StreamPreparedNativeContentPurchaseTypes.Purchase private active;

    function setUp() public {
        vm.warp(100);
        harness = new CuratedPurchaseHashHarness();
    }

    function activePreparedNativeContentPurchase(bytes32)
        external
        view
        returns (StreamPreparedNativeContentPurchaseTypes.Purchase memory)
    {
        return active;
    }

    function _recipe()
        private
        view
        returns (
            IStreamMintManager.MintBatch memory b,
            StreamPreparedNativeContentPurchaseTypes.GateData memory d,
            StreamPreparedNativeContentPurchaseTypes.Purchase memory p,
            StreamPreparedNativeSettlementTypes.Intent memory i
        )
    {
        b.collectionId = 1;
        b.phaseId = keccak256("phase");
        b.payer = address(0xB);
        b.authorizer = address(0xC);
        b.initialRecipients = new address[](1);
        b.initialRecipients[0] = address(this);
        b.beneficiaries = new address[](1);
        b.beneficiaries[0] = address(0xD);
        b.tokenData = new bytes[](1);
        b.tokenData[0] = hex"123456";
        b.mintCommitments = new bytes32[](1);
        b.mintCommitments[0] = keccak256("commitment");
        b.expectedPolicyHash = keccak256("phase policy");
        i.collectionId = 1;
        i.phaseId = b.phaseId;
        i.saleId = keccak256("sale");
        i.saleNonce = 19;
        i.executor = address(0xE);
        i.payer = b.payer;
        i.poster = address(0xF);
        i.beneficiary = b.beneficiaries[0];
        i.amount = 1 ether;
        i.originalPrimaryPolicyHash = keccak256("original primary");
        i.executionNonce = 7;
        i.authorityMode = 1;
        i.saleExecutionHash = keccak256("execution");
        i.contentSelectionHash = keccak256("leaf");
        i.mintCommitment = b.mintCommitments[0];
        i.boundMintPolicyHash = b.expectedPolicyHash;
        StreamPrivateSaleTypes.SaleAuthorization memory a;
        a.chainId = block.chainid;
        a.saleAdapter = address(this);
        a.mintManager = address(harness);
        a.collectionId = 1;
        a.phaseId = b.phaseId;
        a.saleId = i.saleId;
        a.saleKind = 5;
        a.revenueClass = keccak256("PRIMARY_SALE");
        a.expectedPrimaryPolicyHash = i.originalPrimaryPolicyHash;
        a.initialRecipientsHash = keccak256(
            abi.encode(keccak256("6529STREAM_MINT_BATCH_RECIPIENTS_V1"), b.initialRecipients)
        );
        a.beneficiariesHash = keccak256(
            abi.encode(keccak256("6529STREAM_MINT_BATCH_BENEFICIARIES_V1"), b.beneficiaries)
        );
        a.tokenDataArrayHash =
            keccak256(abi.encode(keccak256("6529STREAM_MINT_BATCH_TOKEN_DATA_V1"), b.tokenData));
        a.mintCommitmentsHash = keccak256(
            abi.encode(keccak256("6529STREAM_MINT_BATCH_COMMITMENTS_V1"), b.mintCommitments)
        );
        a.payer = b.payer;
        a.executor = i.executor;
        a.unitPrice = i.amount;
        a.quantity = 1;
        a.contentSelectionHash = i.contentSelectionHash;
        a.policyHash = b.expectedPolicyHash;
        a.nonce = bytes32(uint256(12));
        a.deadline = 200;
        i.saleAuthorizationDigest = StreamPrivateSaleHash.digest(
            block.chainid, address(this), StreamPrivateSaleHash.authorizationBody(a)
        );
        b.authorizationId = StreamMintTicketHash.authorizationId(i.saleAuthorizationDigest);
        p = StreamPreparedNativeContentPurchaseTypes.Purchase(
            i.saleId,
            19,
            keccak256("immutable configuration"),
            keccak256(
                abi.encode(
                    keccak256("6529STREAM_SALE_PURCHASE_V1"),
                    block.chainid,
                    address(this),
                    i.saleId,
                    b.payer,
                    uint256(7)
                )
            ),
            b.payer,
            7,
            b.authorizationId,
            b.authorizer,
            1,
            0
        );
        d.authorizationId = b.authorizationId;
        d.intentHash = keccak256("separate active intent");
        d.authorization = a;
        d.signature = IStreamPrivateSaleAdapter.Signature(b.authorizer, 1, hex"01");
    }

    function testPrivateActualFourArrayHashesAndTicketAreDistinctFromActiveIntent() public {
        (
            IStreamMintManager.MintBatch memory b,
            StreamPreparedNativeContentPurchaseTypes.GateData memory d,
            StreamPreparedNativeContentPurchaseTypes.Purchase memory p,
            StreamPreparedNativeSettlementTypes.Intent memory i
        ) = _recipe();
        require(b.authorizationId != d.intentHash, "separate authorization");
        harness.check(b, d, p, i);
        active = p;
        require(
            harness.readPurchase(address(this), d.intentHash, i).purchaseId == p.purchaseId,
            "original purchase domain"
        );
    }

    function testChangedTokenBytesOrCommitmentRecomputedIntentStillRejectOriginalSignaturePayload()
        public
    {
        (
            IStreamMintManager.MintBatch memory b,
            StreamPreparedNativeContentPurchaseTypes.GateData memory d,
            StreamPreparedNativeContentPurchaseTypes.Purchase memory p,
            StreamPreparedNativeSettlementTypes.Intent memory i
        ) = _recipe();
        b.tokenData[0] = hex"123457";
        vm.expectRevert(
            abi.encodeWithSelector(
                StreamPreparedNativeContentPurchaseHash.InvalidPreparedNativeContentPurchase
                .selector
            )
        );
        harness.check(b, d, p, i);
        b.tokenData[0] = hex"123456";
        b.mintCommitments[0] = keccak256("changed");
        i.mintCommitment = b.mintCommitments[0];
        vm.expectRevert(
            abi.encodeWithSelector(
                StreamPreparedNativeContentPurchaseHash.InvalidPreparedNativeContentPurchase
                .selector
            )
        );
        harness.check(b, d, p, i);
    }

    function testArrayDomainsCannotAliasAndPrivateCannotClaimPublicIdentity() public {
        (
            IStreamMintManager.MintBatch memory b,
            StreamPreparedNativeContentPurchaseTypes.GateData memory d,
            StreamPreparedNativeContentPurchaseTypes.Purchase memory p,
            StreamPreparedNativeSettlementTypes.Intent memory i
        ) = _recipe();
        d.authorization.initialRecipientsHash = keccak256(abi.encode(b.initialRecipients));
        vm.expectRevert(
            abi.encodeWithSelector(
                StreamPreparedNativeContentPurchaseHash.InvalidPreparedNativeContentPurchase
                .selector
            )
        );
        harness.check(b, d, p, i);
        active = p;
        active.authorizationId = d.intentHash;
        vm.expectRevert(
            abi.encodeWithSelector(
                StreamPreparedNativeContentPurchaseHash.InvalidPreparedNativeContentPurchase
                .selector
            )
        );
        harness.readPurchase(address(this), d.intentHash, i);
    }

    function testPublicRequiresEntireEmptyPresentationAndOriginalPurchaseNonce() public {
        (
            IStreamMintManager.MintBatch memory b,
            StreamPreparedNativeContentPurchaseTypes.GateData memory d,
            StreamPreparedNativeContentPurchaseTypes.Purchase memory p,
            StreamPreparedNativeSettlementTypes.Intent memory i
        ) = _recipe();
        i.authorityMode = 2;
        p.authorizationId = d.intentHash;
        p.authorizer = address(0);
        p.authorizerKind = 0;
        b.authorizationId = d.intentHash;
        b.authorizer = address(0);
        d.authorizationId = d.intentHash;
        vm.expectRevert(
            abi.encodeWithSelector(
                StreamPreparedNativeContentPurchaseHash.InvalidPreparedNativeContentPurchase
                .selector
            )
        );
        harness.check(b, d, p, i);
        StreamPrivateSaleTypes.SaleAuthorization memory empty;
        d.authorization = empty;
        d.signature = IStreamPrivateSaleAdapter.Signature(address(0), 0, "");
        harness.check(b, d, p, i);
        active = p;
        harness.readPurchase(address(this), d.intentHash, i);
        active.purchaseNonce = 8;
        vm.expectRevert(
            abi.encodeWithSelector(
                StreamPreparedNativeContentPurchaseHash.InvalidPreparedNativeContentPurchase
                .selector
            )
        );
        harness.readPurchase(address(this), d.intentHash, i);
    }
}
