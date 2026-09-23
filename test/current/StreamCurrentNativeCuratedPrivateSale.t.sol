// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./helpers/NativeCuratedSaleFixture.sol";
import {
    DelegationManagementContract
} from "../../smart-contracts/integrations/delegation/NFTdelegation.sol";
import {
    StreamNativeCuratedPrivateSale
} from "../../smart-contracts/domains/mint/StreamNativeCuratedPrivateSale.sol";
import {
    StreamPrivateSaleHash
} from "../../smart-contracts/domains/mint/StreamPrivateSaleHash.sol";
import { StreamMintTicketHash } from "../../smart-contracts/domains/mint/StreamMintTicketHash.sol";
import {
    StreamNativeCuratedPrivateAuthorization
} from "../../smart-contracts/domains/mint/StreamNativeCuratedPrivateAuthorization.sol";
import {
    IStreamNativeRefundDelegatedClaims
} from "../../smart-contracts/interfaces/stream/mint/IStreamNativeRefundDelegatedClaims.sol";

/// @dev ERC1271 success authenticates the same actual EOA key used to produce the signature.
contract CurrentCuratedPrivateSigner {
    address private immutable _owner;

    constructor(address owner) {
        _owner = owner;
    }

    function isValidSignature(bytes32 digest, bytes calldata signature)
        external
        view
        returns (bytes4)
    {
        if (signature.length != 65) return 0xffffffff;
        bytes32 r;
        bytes32 s;
        uint8 v;
        assembly ("memory-safe") {
            r := calldataload(signature.offset)
            s := calldataload(add(signature.offset, 32))
            v := byte(0, calldataload(add(signature.offset, 64)))
        }
        return ecrecover(digest, v, r, s) == _owner ? bytes4(0x1626ba7e) : bytes4(0xffffffff);
    }
}

/// @notice Actual current Core/Manager/Ledger, registered gate, recorder and native settlement.
/// @dev Artist, entropy and governance ceremony boundaries are identified in the shared fixture.
contract StreamCurrentNativeCuratedPrivateSaleTest is NativeCuratedSaleFixture {
    StreamNativeCuratedPrivateSale private privateSale;
    DelegationManagementContract private privateDelegation;
    bytes32 private constant SIGNER_EVIDENCE =
        keccak256("curated private collection signer evidence");

    function setUp() public override {
        super.setUp();
        privateSale = new StreamNativeCuratedPrivateSale(_curatedDeployment());
        _registerCuratedHost(address(privateSale));
        entropy.configure(7, 1, false, false);
        vm.deal(payer, 1 ether);
    }

    function testPrivateCanonicalEOAActualMintSettlementAndBuyerFeeCredit() public {
        _assertOriginalDomain();
        (
            CuratedPlan memory p,
            Curated.PrivateConfiguration memory config,
            Curated.Selection memory chosen
        ) = _open(payer, vm.addr(SIGNER_KEY), 1, 1);
        StreamPrivateSaleTypes.SaleAuthorization memory a = _authorization(p, chosen, payer);
        IStreamPrivateSaleAdapter.Signature memory sig = _signature(a, config);
        bytes32 digest = _digest(a);
        vm.prank(payer);
        Curated.ExecutionRecord memory e =
            privateSale.purchasePrivateContent{ value: 1027 }(a, sig, chosen, _direct());
        _assertCuratedExecution(p, 1, e);
        require(
            e.authorizationId == StreamMintTicketHash.authorizationId(digest)
                && e.authorizationDigest == digest,
            "canonical ticket key and signed digest"
        );
        require(
            privateSale.saleRecord(p.saleId).status == 4
                && privateSale.nextPurchaseNonce(p.saleId, payer) == 2,
            "private completion and durable local nonce"
        );
        require(
            privateSale.refundableBalance(p.saleId, payer) == 20
                && privateSale.refundLiability() == 20 && address(privateSale).balance == 20,
            "excess belongs to actual buyer"
        );
        require(
            entropy.revealFeeEscrow(1) == 7 && recorder.totalOfficialSettled(address(0)) == 1000,
            "price and fee separated"
        );
        address recipient = address(0xBEEF);
        vm.prank(payer);
        privateSale.claimRefund(p.saleId, recipient);
        require(
            recipient.balance == 20 && privateSale.refundLiability() == 0
                && address(privateSale).balance == 0,
            "pull credit conservation"
        );
        vm.prank(payer);
        vm.expectRevert();
        privateSale.purchasePrivateContent{ value: 1007 }(a, sig, chosen, _direct());
        require(
            ledger.counterValue(_curatedCounterKey(p, 1)) == 1
                && recorder.totalOfficialSettled(address(0)) == 1000,
            "replay made no mint or revenue"
        );
    }

    function testPrivateERC1271SellerAndDeclaredEmptyTokenBytes() public {
        CurrentCuratedPrivateSigner seller = new CurrentCuratedPrivateSigner(vm.addr(SIGNER_KEY));
        (
            CuratedPlan memory p,
            Curated.PrivateConfiguration memory config,
            Curated.Selection memory chosen
        ) = _open(payer, address(seller), 2, 0);
        StreamPrivateSaleTypes.SaleAuthorization memory a = _authorization(p, chosen, payer);
        vm.prank(payer);
        Curated.ExecutionRecord memory e = privateSale.purchasePrivateContent{ value: 1007 }(
            a, _signature(a, config), chosen, _direct()
        );
        _assertCuratedExecution(p, 0, e);
        require(
            core.tokenData(e.tokenId).length == 0 && e.contentLeaf == p.leaves[0],
            "exact published empty bytes supported"
        );
    }

    function testPrivateOtherPublishedLeafAndRawBytesCannotReplaceSelectedWork() public {
        (
            CuratedPlan memory p,
            Curated.PrivateConfiguration memory config,
            Curated.Selection memory chosen
        ) = _open(payer, vm.addr(SIGNER_KEY), 1, 1);
        StreamPrivateSaleTypes.SaleAuthorization memory a = _authorization(p, chosen, payer);
        IStreamPrivateSaleAdapter.Signature memory sig = _signature(a, config);
        Curated.Selection memory other = _curatedSelection(p, 2, payer, 1);
        vm.prank(payer);
        vm.expectRevert();
        privateSale.purchasePrivateContent{ value: 1007 }(a, sig, other, _direct());
        chosen.tokenData = "wrong actual bytes";
        vm.prank(payer);
        vm.expectRevert();
        privateSale.purchasePrivateContent{ value: 1007 }(a, sig, chosen, _direct());
        _assertUnused(p, a, 1);
    }

    function testPrivateInvalidProofAndBeneficiaryRollbackBeforeMint() public {
        (
            CuratedPlan memory p,
            Curated.PrivateConfiguration memory config,
            Curated.Selection memory chosen
        ) = _open(payer, vm.addr(SIGNER_KEY), 1, 1);
        StreamPrivateSaleTypes.SaleAuthorization memory a = _authorization(p, chosen, payer);
        IStreamPrivateSaleAdapter.Signature memory sig = _signature(a, config);
        chosen.content.proof[0] = bytes32(uint256(123));
        vm.prank(payer);
        vm.expectRevert();
        privateSale.purchasePrivateContent{ value: 1007 }(a, sig, chosen, _direct());
        chosen = _curatedSelection(p, 1, address(0xBAD), 1);
        vm.prank(payer);
        vm.expectRevert();
        privateSale.purchasePrivateContent{ value: 1007 }(a, sig, chosen, _direct());
        _assertUnused(p, a, 1);
    }

    function testPrivateCallerMustBeBuyerOrLiveAdmittedDelegate() public {
        (
            CuratedPlan memory p,
            Curated.PrivateConfiguration memory config,
            Curated.Selection memory chosen
        ) = _open(payer, vm.addr(SIGNER_KEY), 1, 1);
        address other = address(0xBAD);
        vm.deal(other, 1 ether);
        StreamPrivateSaleTypes.SaleAuthorization memory a = _authorization(p, chosen, other);
        IStreamPrivateSaleAdapter.Signature memory sig = _signature(a, config);
        vm.prank(other);
        vm.expectRevert();
        privateSale.purchasePrivateContent{ value: 1007 }(a, sig, chosen, _direct());
        _assertUnused(p, a, 1);
    }

    function testPrivateExplicitSignerKindAndMembershipCannotBeSubstituted() public {
        (
            CuratedPlan memory p,
            Curated.PrivateConfiguration memory config,
            Curated.Selection memory chosen
        ) = _open(payer, vm.addr(SIGNER_KEY), 1, 1);
        StreamPrivateSaleTypes.SaleAuthorization memory a = _authorization(p, chosen, payer);
        IStreamPrivateSaleAdapter.Signature memory sig = _signature(a, config);
        sig.kind = 2;
        vm.prank(payer);
        vm.expectRevert();
        privateSale.purchasePrivateContent{ value: 1007 }(a, sig, chosen, _direct());
        sig = IStreamPrivateSaleAdapter.Signature(
            vm.addr(AUCTION_PLATFORM_KEY), 1, _curatedSignature(AUCTION_PLATFORM_KEY, _digest(a))
        );
        vm.prank(payer);
        vm.expectRevert();
        privateSale.purchasePrivateContent{ value: 1007 }(a, sig, chosen, _direct());
        _assertUnused(p, a, 1);
    }

    function testPrivateOriginalAuthPriceNonceDeadlineAndPolicyStayBinding() public {
        (
            CuratedPlan memory p,
            Curated.PrivateConfiguration memory config,
            Curated.Selection memory chosen
        ) = _open(payer, vm.addr(SIGNER_KEY), 1, 1);
        StreamPrivateSaleTypes.SaleAuthorization memory a = _authorization(p, chosen, payer);
        a.unitPrice += 1;
        _rejectSigned(p, config, chosen, a);
        a.unitPrice = p.config.price;
        a.nonce = 0;
        _rejectSigned(p, config, chosen, a);
        a.nonce = keccak256("original nonce");
        a.deadline = p.config.endsAt + 1;
        _rejectSigned(p, config, chosen, a);
        a.deadline = p.config.endsAt;
        a.primaryPolicyMode = 1;
        _rejectSigned(p, config, chosen, a);
        a.primaryPolicyMode = 0;
        a.finalizeBy = p.config.endsAt;
        _rejectSigned(p, config, chosen, a);
    }

    function testPrivateSignerRevisionRevocationCannotRewriteHistoricalMembership() public {
        (
            CuratedPlan memory p,
            Curated.PrivateConfiguration memory config,
            Curated.Selection memory chosen
        ) = _open(payer, vm.addr(SIGNER_KEY), 1, 1);
        StreamPrivateSaleTypes.SaleAuthorization memory a = _authorization(p, chosen, payer);
        IStreamPrivateSaleAdapter.Signature memory sig = _signature(a, config);
        privateSale.configureCollectionSigner(
            1, config.signer, config.signerKind, SIGNER_EVIDENCE, false
        );
        vm.prank(payer);
        vm.expectRevert();
        privateSale.purchasePrivateContent{ value: 1007 }(a, sig, chosen, _direct());
        vm.warp(p.config.endsAt + 1);
        privateSale.expirePrivateSale(p.saleId);
        (uint256 collection, bytes32 phase, address signer, uint8 kind, bytes32 hash) =
            privateSale.curatedSaleAuthorizationBinding(p.saleId);
        require(
            collection == 1 && phase == p.config.phaseId && signer == config.signer && kind == 1
                && hash == privateSale.privateConfigurationHash(config),
            "historical exact160 binding survives expiry/revocation"
        );
        require(
            privateSale.saleRecord(p.saleId).status == 3 && privateSale.nextSaleNonce() == 2,
            "expiry keeps creation identity"
        );
    }

    function testPrivateZeroAndAllowCurrentConfigurationsRejectedWithoutNonceAdvance() public {
        CuratedPlan memory p = _curatedPlan(address(privateSale), 5, Curated.SelectionMode.PUBLIC);
        Curated.PrivateConfiguration memory c = _configuration(p, payer, vm.addr(SIGNER_KEY), 1, 1);
        Curated.Selection memory chosen = _curatedSelection(p, 1, payer, 1);
        c.sale.price = 0;
        vm.expectRevert();
        privateSale.registerCuratedPrivateSale(c, chosen.content.proof);
        c.sale.price = p.config.price;
        c.sale.primaryPolicyMode = 1;
        vm.expectRevert();
        privateSale.registerCuratedPrivateSale(c, chosen.content.proof);
        require(
            privateSale.nextSaleNonce() == 1 && privateSale.saleRecord(p.saleId).status == 0,
            "failed configuration is atomic"
        );
    }

    function testPrivateRejectingFinalReceiverRollsBackMintReplayRevenueAndCredit() public {
        NativeAuctionReceiver buyer = new NativeAuctionReceiver();
        buyer.configure(true, false, address(0), "", address(0));
        (
            CuratedPlan memory p,
            Curated.PrivateConfiguration memory config,
            Curated.Selection memory chosen
        ) = _open(address(buyer), vm.addr(SIGNER_KEY), 1, 1);
        StreamPrivateSaleTypes.SaleAuthorization memory a =
            _authorization(p, chosen, address(buyer));
        bytes memory callData = abi.encodeCall(
            privateSale.purchasePrivateContent, (a, _signature(a, config), chosen, _direct())
        );
        vm.deal(address(this), 1 ether);
        vm.expectRevert();
        buyer.callTarget{ value: 1027 }(address(privateSale), 1027, callData);
        _assertUnused(p, a, 1);
        require(
            entropy.revealFeeEscrow(1) == 0 && entropy.mintCalls() == 0
                && address(privateSale).balance == 0,
            "late failure rolls back entropy and custody"
        );
        buyer.configure(false, false, address(0), "", address(0));
        bytes memory raw = buyer.callTarget{ value: 1027 }(address(privateSale), 1027, callData);
        Curated.ExecutionRecord memory e = abi.decode(raw, (Curated.ExecutionRecord));
        _assertCuratedExecution(p, 1, e);
    }

    function testPrivateFinalReceiverReentryRejectedWhileDeliveryCanComplete() public {
        NativeAuctionReceiver buyer = new NativeAuctionReceiver();
        (
            CuratedPlan memory p,
            Curated.PrivateConfiguration memory config,
            Curated.Selection memory chosen
        ) = _open(address(buyer), vm.addr(SIGNER_KEY), 1, 1);
        StreamPrivateSaleTypes.SaleAuthorization memory a =
            _authorization(p, chosen, address(buyer));
        bytes memory data = abi.encodeCall(
            privateSale.purchasePrivateContent, (a, _signature(a, config), chosen, _direct())
        );
        buyer.configure(false, false, address(privateSale), data, address(0));
        vm.deal(address(this), 1 ether);
        Curated.ExecutionRecord memory e = abi.decode(
            buyer.callTarget{ value: 1007 }(address(privateSale), 1007, data),
            (Curated.ExecutionRecord)
        );
        _assertCuratedExecution(p, 1, e);
        require(
            buyer.callbackRejected() && recorder.totalOfficialSettled(address(0)) == 1000,
            "one guarded mint and official settlement"
        );
    }

    function testPrivateLateArtistConsentLossRollsBackEntirePurchase() public {
        NativeAuctionReceiver buyer = new NativeAuctionReceiver();
        buyer.configure(
            false,
            false,
            address(artists),
            abi.encodeCall(NativeCuratedArtistBoundary.setConsent, (false)),
            address(0)
        );
        (
            CuratedPlan memory p,
            Curated.PrivateConfiguration memory config,
            Curated.Selection memory chosen
        ) = _open(address(buyer), vm.addr(SIGNER_KEY), 1, 1);
        StreamPrivateSaleTypes.SaleAuthorization memory a =
            _authorization(p, chosen, address(buyer));
        bytes memory data = abi.encodeCall(
            privateSale.purchasePrivateContent, (a, _signature(a, config), chosen, _direct())
        );
        vm.deal(address(this), 1 ether);
        vm.expectRevert();
        buyer.callTarget{ value: 1007 }(address(privateSale), 1007, data);
        _assertUnused(p, a, 1);
        require(
            NativeCuratedArtistBoundary(address(artists)).consent(),
            "late callback mutation rolled back too"
        );
    }

    function testPrivateCanonicalManagerRevocationBlocksTheActualSignedMint() public {
        (
            CuratedPlan memory p,
            Curated.PrivateConfiguration memory config,
            Curated.Selection memory chosen
        ) = _open(payer, vm.addr(SIGNER_KEY), 1, 1);
        StreamPrivateSaleTypes.SaleAuthorization memory a = _authorization(p, chosen, payer);
        IStreamPrivateSaleAdapter.Signature memory sig = _signature(a, config);
        bytes32 expected = StreamMintTicketHash.authorizationId(_digest(a));
        require(manager.mintSaleAuthorizationId(a) == expected, "same actual revocation key");
        vm.prank(config.signer);
        require(
            manager.voidMintSaleAuthorization(a, "") == expected, "direct configured seller void"
        );
        vm.prank(payer);
        vm.expectRevert();
        privateSale.purchasePrivateContent{ value: 1007 }(a, sig, chosen, _direct());
        require(
            ledger.isManagerAuthorizationUsed(address(manager), expected)
                && ledger.counterValue(_curatedCounterKey(p, 1)) == 0
                && privateSale.nextPurchaseNonce(p.saleId, payer) == 1
                && recorder.totalOfficialSettled(address(0)) == 0,
            "void survives while failed purchase is atomic"
        );
    }

    function testPrivateHistoricalVoidSurvivesExpirySignerRevocationAndArtistLoss() public {
        (
            CuratedPlan memory p,
            Curated.PrivateConfiguration memory config,
            Curated.Selection memory chosen
        ) = _open(payer, vm.addr(SIGNER_KEY), 1, 1);
        StreamPrivateSaleTypes.SaleAuthorization memory a = _authorization(p, chosen, payer);
        privateSale.configureCollectionSigner(1, config.signer, 1, SIGNER_EVIDENCE, false);
        NativeCuratedArtistBoundary(address(artists)).setConsent(false);
        vm.warp(p.config.endsAt + 1);
        privateSale.expirePrivateSale(p.saleId);
        vm.prank(config.signer);
        bytes32 id = manager.voidMintSaleAuthorization(a, "");
        require(
            id == StreamMintTicketHash.authorizationId(_digest(a))
                && ledger.isManagerAuthorizationUsed(address(manager), id),
            "historical void has no live sale dependency"
        );
    }

    function testPrivateERC1271RelayedVoidUsesOriginalSalesRevocationDomain() public {
        CurrentCuratedPrivateSigner seller = new CurrentCuratedPrivateSigner(vm.addr(SIGNER_KEY));
        (CuratedPlan memory p,, Curated.Selection memory chosen) =
            _open(payer, address(seller), 2, 1);
        StreamPrivateSaleTypes.SaleAuthorization memory a = _authorization(p, chosen, payer);
        bytes32 id = StreamMintTicketHash.authorizationId(_digest(a));
        bytes32 revocation = keccak256(
            abi.encodePacked(
                hex"1901",
                StreamPrivateSaleHash.domain(block.chainid, address(privateSale)),
                StreamMintTicketHash.revocationBody(
                    block.chainid, address(manager), address(ledger), id
                )
            )
        );
        bytes memory signature = _curatedSignature(SIGNER_KEY, revocation);
        require(
            manager.voidMintSaleAuthorization(a, signature) == id
                && ledger.isManagerAuthorizationUsed(address(manager), id),
            "actual ERC1271 historical seller revocation"
        );
    }

    function testPrivateActualDelegatePaysButBuyerOwnsDeliveryAndExcessCredit() public {
        _deployDelegatedPrivate();
        address delegate = address(0xD311);
        (
            CuratedPlan memory p,
            Curated.PrivateConfiguration memory config,
            Curated.Selection memory chosen
        ) = _open(payer, vm.addr(SIGNER_KEY), 1, 1);
        vm.prank(payer);
        privateDelegation.registerDelegationAddress(
            address(core), delegate, block.timestamp + 1 days, 2, true, 0
        );
        StreamPrivateSaleTypes.SaleAuthorization memory a = _authorization(p, chosen, delegate);
        IStreamPrivateSaleAdapter.Signature memory sig = _signature(a, config);
        vm.deal(delegate, 1 ether);
        vm.prank(delegate);
        Curated.ExecutionRecord memory e =
            privateSale.purchasePrivateContent{ value: 1027 }(a, sig, chosen, _direct());
        _assertCuratedExecution(p, 1, e);
        require(
            e.buyer == payer && core.ownerOf(e.tokenId) == payer
                && privateSale.refundableBalance(p.saleId, payer) == 20
                && privateSale.refundableBalance(p.saleId, delegate) == 0,
            "delegate funding preserves buyer custody and credit"
        );
        vm.prank(payer);
        privateDelegation.revokeDelegationAddress(address(core), delegate, 2);
        vm.prank(delegate);
        vm.expectRevert();
        privateSale.claimRefundFor(p.saleId, payer, _direct());
        vm.etch(address(privateDelegation), hex"00");
        uint256 balance = payer.balance;
        vm.prank(payer);
        privateSale.claimRefund(p.saleId, payer);
        require(
            payer.balance == balance + 20 && privateSale.refundLiability() == 0,
            "buyer credit independent of failed delegation provider"
        );
    }

    function testPrivateDelegateGrantRevokedDuringFinalDeliveryRollsBackAllEffects() public {
        _deployDelegatedPrivate();
        NativeAuctionReceiver buyer = new NativeAuctionReceiver();
        address delegate = address(0xD311);
        (
            CuratedPlan memory p,
            Curated.PrivateConfiguration memory config,
            Curated.Selection memory chosen
        ) = _open(address(buyer), vm.addr(SIGNER_KEY), 1, 1);
        buyer.callTarget(
            address(privateDelegation),
            0,
            abi.encodeCall(
                privateDelegation.registerDelegationAddress,
                (address(core), delegate, block.timestamp + 1 days, uint256(2), true, uint256(0))
            )
        );
        buyer.configure(
            false,
            false,
            address(privateDelegation),
            abi.encodeCall(
                privateDelegation.revokeDelegationAddress, (address(core), delegate, uint256(2))
            ),
            address(0)
        );
        StreamPrivateSaleTypes.SaleAuthorization memory a = _authorization(p, chosen, delegate);
        IStreamPrivateSaleAdapter.Signature memory sig = _signature(a, config);
        vm.deal(delegate, 1 ether);
        vm.prank(delegate);
        vm.expectRevert();
        privateSale.purchasePrivateContent{ value: 1027 }(a, sig, chosen, _direct());
        _assertUnused(p, a, 1);
        require(
            entropy.revealFeeEscrow(1) == 0 && address(privateSale).balance == 0,
            "post-callback live-grant failure is atomic"
        );
        buyer.configure(false, false, address(0), "", address(0));
        vm.prank(delegate);
        Curated.ExecutionRecord memory e =
            privateSale.purchasePrivateContent{ value: 1027 }(a, sig, chosen, _direct());
        _assertCuratedExecution(p, 1, e);
    }

    function _deployDelegatedPrivate() private {
        privateDelegation = new DelegationManagementContract();
        StreamNativeCuratedSaleBase.DeploymentConfig memory d = _curatedDeployment();
        d.delegation = IStreamNativeRefundDelegatedClaims.DelegationDeployment(
            address(privateDelegation),
            2,
            MANIFEST,
            IStreamGasParameterHost.GasParameterConfig(
                "DELEGATE_REGISTRY_GAS_LIMIT", 150000, 50000, 2
            )
        );
        privateSale = new StreamNativeCuratedPrivateSale(d);
        _registerCuratedHost(address(privateSale));
    }

    function _moduleManifest(address module) internal view override returns (bytes32) {
        return module == address(privateSale) && address(privateDelegation) != address(0)
            ? keccak256(privateSale.refundDelegationManifest())
            : MANIFEST;
    }

    function _assertOriginalDomain() private view {
        (
            bytes1 fields,
            string memory name,
            string memory version,
            uint256 chainId,
            address verifyingContract,
            bytes32 salt,
            uint256[] memory extensions
        ) = privateSale.eip712Domain();
        require(
            fields == 0x0f && keccak256(bytes(name)) == keccak256("6529Stream Sales")
                && keccak256(bytes(version)) == keccak256("1") && chainId == block.chainid
                && verifyingContract == address(privateSale) && salt == 0 && extensions.length == 0,
            "original canonical Sales domain published through ERC5267"
        );
    }

    function _configuration(
        CuratedPlan memory p,
        address buyer,
        address signer,
        uint8 kind,
        uint256 index
    ) private returns (Curated.PrivateConfiguration memory c) {
        privateSale.configureCollectionSigner(1, signer, kind, SIGNER_EVIDENCE, true);
        Curated.CollectionSigner memory configured = privateSale.collectionSigner(1, signer, kind);
        c.sale = p.config;
        c.buyer = buyer;
        c.contentId = bytes32(index);
        c.tokenDataHash = keccak256(_curatedArtwork(index));
        c.signer = signer;
        c.signerKind = kind;
        c.signerEvidenceHash = configured.evidenceHash;
        c.signerRevision = configured.revision;
        c.signerAuthority = configured.authority;
    }

    function _open(address buyer, address signer, uint8 kind, uint256 index)
        private
        returns (
            CuratedPlan memory p,
            Curated.PrivateConfiguration memory c,
            Curated.Selection memory chosen
        )
    {
        p = _curatedPlan(address(privateSale), 5, Curated.SelectionMode.PUBLIC);
        c = _configuration(p, buyer, signer, kind, index);
        chosen = _curatedSelection(p, index, buyer, 1);
        bytes32 id = privateSale.registerCuratedPrivateSale(c, chosen.content.proof);
        require(
            id == p.saleId
                && privateSale.saleRecord(id).configHash == privateSale.privateConfigurationHash(c),
            "original private sale identity and immutable full hash"
        );
        _bindCuratedConsent(id, privateSale.privateConfigurationHash(c));
        vm.warp(p.config.startsAt);
    }

    function _authorization(CuratedPlan memory p, Curated.Selection memory chosen, address executor)
        private
        view
        returns (StreamPrivateSaleTypes.SaleAuthorization memory a)
    {
        address[] memory recipients = new address[](1);
        recipients[0] = address(privateSale);
        address[] memory beneficiaries = new address[](1);
        beneficiaries[0] = chosen.recipient;
        bytes[] memory data = new bytes[](1);
        data[0] = chosen.tokenData;
        bytes32[] memory commitments = new bytes32[](1);
        commitments[0] = chosen.mintCommitment;
        a.chainId = block.chainid;
        a.saleAdapter = address(privateSale);
        a.mintManager = address(manager);
        a.collectionId = 1;
        a.phaseId = p.config.phaseId;
        a.saleId = p.saleId;
        a.saleKind = 5;
        a.revenueClass = CLASS;
        a.expectedPrimaryPolicyHash = p.config.expectedPrimaryPolicyHash;
        a.primaryPolicyMode = 0;
        a.initialRecipientsHash =
            keccak256(abi.encode(keccak256("6529STREAM_MINT_BATCH_RECIPIENTS_V1"), recipients));
        a.beneficiariesHash = keccak256(
            abi.encode(keccak256("6529STREAM_MINT_BATCH_BENEFICIARIES_V1"), beneficiaries)
        );
        a.tokenDataArrayHash =
            keccak256(abi.encode(keccak256("6529STREAM_MINT_BATCH_TOKEN_DATA_V1"), data));
        a.mintCommitmentsHash =
            keccak256(abi.encode(keccak256("6529STREAM_MINT_BATCH_COMMITMENTS_V1"), commitments));
        a.payer = chosen.recipient;
        a.executor = executor;
        a.unitPrice = p.config.price;
        a.quantity = 1;
        a.contentSelectionHash = p.leaves[uint256(chosen.content.contentId)];
        a.policyHash = p.config.mintPolicyHash;
        a.nonce = keccak256(abi.encode("canonical private nonce", p.saleId));
        a.deadline = p.config.endsAt;
    }

    function _digest(StreamPrivateSaleTypes.SaleAuthorization memory a)
        private
        view
        returns (bytes32)
    {
        return StreamPrivateSaleHash.digest(
            block.chainid, address(privateSale), StreamPrivateSaleHash.authorizationBody(a)
        );
    }

    function _signature(
        StreamPrivateSaleTypes.SaleAuthorization memory a,
        Curated.PrivateConfiguration memory c
    ) private returns (IStreamPrivateSaleAdapter.Signature memory) {
        return IStreamPrivateSaleAdapter.Signature(
            c.signer, c.signerKind, _curatedSignature(SIGNER_KEY, _digest(a))
        );
    }

    function _direct()
        private
        pure
        returns (IStreamNativeRefundDelegatedClaims.DelegationWitness memory)
    {
        return IStreamNativeRefundDelegatedClaims.DelegationWitness(false, 0);
    }

    function _rejectSigned(
        CuratedPlan memory p,
        Curated.PrivateConfiguration memory c,
        Curated.Selection memory chosen,
        StreamPrivateSaleTypes.SaleAuthorization memory a
    ) private {
        IStreamPrivateSaleAdapter.Signature memory sig = _signature(a, c);
        vm.prank(payer);
        vm.expectRevert();
        privateSale.purchasePrivateContent{ value: 1007 }(a, sig, chosen, _direct());
        _assertUnused(p, a, 1);
    }

    function _assertUnused(
        CuratedPlan memory p,
        StreamPrivateSaleTypes.SaleAuthorization memory a,
        uint256 index
    ) private view {
        require(
            ledger.counterValue(_curatedCounterKey(p, index)) == 0
                && !ledger.isManagerAuthorizationUsed(
                    address(manager), StreamMintTicketHash.authorizationId(_digest(a))
                ),
            "unused actual ledger counter and authorization"
        );
        require(
            privateSale.nextPurchaseNonce(p.saleId, a.payer) == 1
                && privateSale.saleRecord(p.saleId).status == 1
                && privateSale.refundLiability() == 0,
            "no partial host effects"
        );
        require(
            recorder.totalOfficialSettled(address(0)) == 0 && core.pendingPreparedMintTokenId() == 0
                && manager.preparedNativeContentAdmission() == 0,
            "no partial official revenue or pending Core state"
        );
    }
}
