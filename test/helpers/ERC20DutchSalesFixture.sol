// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "./NativeImmediateSalesFixture.sol";
import "./OfficialPermit2Fixture.sol";
import "./UniversalSettlementTestMocks.sol";
import "../../smart-contracts/domains/mint/StreamERC20DutchSale.sol";
import {
    StreamERC20PrimarySettlementAdapter
} from "../../smart-contracts/domains/revenue/StreamERC20PrimarySettlementAdapter.sol";
import {
    IStreamERC20DutchSale as D
} from "../../smart-contracts/interfaces/stream/mint/IStreamERC20DutchSale.sol";
import {
    IStreamERC20DutchPayments as DP
} from "../../smart-contracts/interfaces/stream/revenue/IStreamERC20DutchPayments.sol";
import {
    StreamPrimarySettlementTypes as PS
} from "../../smart-contracts/interfaces/stream/revenue/StreamPrimarySettlementTypes.sol";
import {
    IStreamNativeImmediateSales as S
} from "../../smart-contracts/interfaces/stream/mint/IStreamNativeImmediateSales.sol";
import "../../smart-contracts/interfaces/stream/mint/IStreamMintCounterPolicy.sol";

/// @notice Actual current Core/Manager/Ledger/Payment/Recorder/Registry/Floor/Metadata/Store/wallet
/// and original upstream Safe/Permit2. Artist, entropy, ERC20 and target-side governance are
/// explicit fixture boundaries. Artifact CREATE uses genuine compiled products and original caps.
abstract contract ERC20DutchSalesFixture is NativeImmediateSalesFixture, OfficialPermit2Fixture {
    StreamERC20DutchSale internal dutch;
    StreamERC20PrimarySettlementAdapter internal dutchPayment;
    UniversalPermitToken internal dutchToken;
    address internal dutchPermit2;

    function setUp() public virtual override {
        super.setUp();
        immediateEntropy.configure(true, 0);
        dutchPermit2 = deployOfficialPermit2();
        dutchPayment = StreamERC20PrimarySettlementAdapter(
            payable(_artistArtifactCreate(
                    "smart-contracts/domains/revenue/StreamERC20PrimarySettlementAdapter.sol:StreamERC20PrimarySettlementAdapter",
                    abi.encode(recorder, dutchPermit2, dutchPermit2.codehash)
                ))
        );
        _register(
            address(dutchPayment),
            keccak256("ERC20_PRIMARY_SETTLEMENT_ADAPTER"),
            type(IStreamERC20PrimarySettlementAdapter).interfaceId,
            keccak256("6529STREAM_UNIVERSAL_SETTLEMENT_V1")
        );
        StreamERC20DutchSale.DeploymentConfig memory d;
        d.manager = manager;
        d.recorder = recorder;
        d.artists = artists;
        d.roles = auctionRoles;
        d.authority = address(revenueAuthority);
        d.parameters[0] =
            IStreamGasParameterHost.GasParameterConfig("SALE_ERC1271_GAS_LIMIT", 400000, 350000, 2);
        d.parameters[1] = IStreamGasParameterHost.GasParameterConfig(
            "SALE_ARTIST_AUTHORITY_GAS_LIMIT", 500000, 100000, 2
        );
        d.parameters[2] =
            IStreamGasParameterHost.GasParameterConfig(
            "REVEAL_ATTEMPT_GAS_LIMIT", 2000000, 50000, 2
        );
        dutch = StreamERC20DutchSale(
            payable(_artistArtifactCreate(
                    "smart-contracts/domains/mint/StreamERC20DutchSale.sol:StreamERC20DutchSale",
                    abi.encode(d)
                ))
        );
        dutch.transferOwnership(address(revenueAuthority));
        _register(
            address(dutch),
            keccak256("DUTCH_AUCTION_ADAPTER"),
            type(IStreamERC20SaleExecution).interfaceId,
            keccak256("6529STREAM_UNIVERSAL_SETTLEMENT_V1")
        );
        manager.setPhaseExecutor(1, PHASE, address(dutch), true);
        dutchToken = new UniversalPermitToken();
        _setAssetPolicy(policy, address(dutchToken), 1, keccak256("exact Dutch fixture asset"), 0);
        _dutchPermitPolicy();
        dutchToken.mint(payer, 10000);
        vm.prank(payer);
        dutchToken.approve(address(dutchPayment), 10000);
        require(
            address(dutch).code.length <= 24576 && address(dutchPayment).code.length <= 24576,
            "actual production EIP170"
        );
    }

    function _dutchPermitPolicy() private {
        (bytes32 scope, bytes32 oldHash, bytes32 next) = policy.assetPermitPolicyTransitionHashes(
            address(dutchToken), 3, 1, dutchPermit2, dutchPermit2.codehash
        );
        _context(scope, oldHash, next, 1);
        vm.prank(address(revenueAuthority));
        policy.setAssetPermitPolicy(address(dutchToken), 3, 1, dutchPermit2, dutchPermit2.codehash);
        _clearContext();
    }

    function _dutchConfig(uint8 mode, bool free) internal returns (D.Configuration memory c) {
        c.sale.collectionId = 1;
        c.sale.phaseId = PHASE;
        c.sale.saleKind = 3;
        c.sale.authorityMode = mode;
        c.sale.startsAt = 1000;
        c.sale.endsAt = 3000;
        c.sale.saleSupplyLimit = 8;
        c.sale.mintPolicyHash = manager.phasePolicyHash(1, PHASE);
        c.sale.expectedPrimaryPolicyHash = _primaryPolicyHash();
        c.asset = address(dutchToken);
        c.paymentAdapter = address(dutchPayment);
        c.declaredFree = free;
        c.schedule = IStreamDutchPriceSchedule.DutchPriceSchedule(
            1000, free ? 0 : 100, 1000, 2000, 0, 0, 0
        );
        if (mode == 1) {
            address signer = vm.addr(SIGNER_KEY);
            vm.prank(address(revenueAuthority));
            dutch.configureCollectionSigner(
                1, signer, 1, keccak256("Dutch canonical authority"), true
            );
            (c.sale.signer,) = dutch.collectionSigner(1, signer, 1);
        }
    }

    function _registerDutch(D.Configuration memory c) internal returns (bytes32 id) {
        vm.prank(address(revenueAuthority));
        id = dutch.registerDutchSale(c);
    }

    function _dutchExecution(bytes32 id, address who, uint256 tag)
        internal
        view
        returns (D.Execution memory e)
    {
        e.purchase.saleId = id;
        e.purchase.payer = who;
        e.purchase.executor = who;
        e.purchase.initialRecipient = address(0xBEEF);
        e.purchase.beneficiary = address(0xCAFE);
        e.purchase.tokenData = abi.encode("canonical Dutch artwork", tag);
        e.purchase.mintCommitment = keccak256(abi.encode("Dutch mint commitment", tag));
        e.purchase.executionNonce = dutch.nextExecutionNonce(id, who);
    }

    function _signDutch(D.Execution memory e, uint256 cap) internal returns (D.Execution memory) {
        e.authorization = _dutchAuthorization(e.purchase, uint256(e.purchase.executionNonce));
        e.authorization.unitPrice = cap;
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(SIGNER_KEY, _dutchDigest(e.authorization));
        e.signature =
            IStreamPrivateSaleAdapter.Signature(vm.addr(SIGNER_KEY), 1, abi.encodePacked(r, s, v));
        return e;
    }

    function _dutchRequest(D.Execution memory e, uint256 cap)
        internal
        view
        returns (DP.Request memory)
    {
        return DP.Request(
            address(dutch),
            address(dutch).codehash,
            e.purchase.saleId,
            dutch.dutchSaleRecord(e.purchase.saleId).configHash,
            cap,
            abi.encode(e)
        );
    }

    function _dutchBuy(D.Execution memory e, uint256 cap, uint256 value)
        internal
        returns (DP.Result memory)
    {
        DP.Request memory q = _dutchRequest(e, cap);
        vm.prank(e.purchase.executor);
        return dutchPayment.settleERC20DutchSaleByPayer{ value: value }(q);
    }

    function _intent(D.Execution memory e, uint256 cap, uint256 nonce)
        internal
        view
        returns (PS.PaymentIntent memory)
    {
        return PS.PaymentIntent(
            e.purchase.payer,
            address(dutchToken),
            cap,
            e.purchase.saleId,
            dutch.dutchSaleRecord(e.purchase.saleId).config.sale.expectedPrimaryPolicyHash,
            bytes32(nonce),
            uint64(3000)
        );
    }

    function _intentSignature(PS.PaymentIntent memory i) internal returns (bytes memory) {
        bytes32 domain = keccak256(
            abi.encode(
                keccak256(
                    "EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"
                ),
                keccak256("6529StreamPaymentIntentVerifier"),
                keccak256("1"),
                block.chainid,
                address(dutchPayment)
            )
        );
        bytes32 body = keccak256(
            abi.encode(
                keccak256(
                    "StreamPaymentIntent(address payer,address asset,uint256 maxAmount,bytes32 saleRef,bytes32 expectedPrimaryPolicyHash,bytes32 nonce,uint64 deadline)"
                ),
                i
            )
        );
        bytes32 digest_ = keccak256(abi.encodePacked(hex"1901", domain, body));
        require(digest_ == dutchPayment.paymentIntentDigest(i), "literal original PaymentIntent");
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(PAYER_KEY, digest_);
        return abi.encodePacked(r, s, v);
    }

    function _assertPaid(D.Execution memory e, DP.Result memory out, uint256 amount) internal view {
        require(
            out.revenueOutcome == 2 && out.settlement.amount == amount
                && out.settlement.asset == address(dutchToken),
            "actual inclusion price"
        );
        require(
            out.settlement.executionId == out.executionId
                && out.settlement.executor == e.purchase.executor,
            "exact executor and ID"
        );
        S.Receipt memory receipt = dutch.executionReceipt(out.executionId);
        require(
            receipt.chargedAmount == amount && receipt.settlementKey == out.settlement.settlementKey
                && receipt.tokenId != 0,
            "actual retained receipt"
        );
        require(
            core.ownerOf(receipt.tokenId) == e.purchase.initialRecipient
                && dutch.executionStatus(out.executionId) == 2,
            "actual Core and finalized carrier"
        );
        require(
            keccak256(abi.encode(recorder.settlementResult(receipt.settlementKey)))
                == keccak256(abi.encode(out.settlement)),
            "exact original recorder bytes"
        );
        require(
            dutchPayment.phase() == StreamERC20PrimarySettlementAdapter.Phase.IDLE,
            "original phase restored"
        );
    }

    function _dutchAuthorization(IStreamNativeImmediateSales.Purchase memory p, uint256 nonce)
        internal
        view
        returns (StreamPrivateSaleTypes.SaleAuthorization memory a)
    {
        D.Record memory r = dutch.dutchSaleRecord(p.saleId);
        a.chainId = block.chainid;
        a.saleAdapter = address(dutch);
        a.mintManager = address(manager);
        a.collectionId = r.config.sale.collectionId;
        a.phaseId = r.config.sale.phaseId;
        a.saleId = p.saleId;
        a.saleKind = r.config.sale.saleKind;
        a.revenueClass = CLASS;
        a.expectedPrimaryPolicyHash = r.config.sale.expectedPrimaryPolicyHash;
        a.primaryPolicyMode = r.config.sale.primaryPolicyMode;
        address[] memory recipients = new address[](1);
        recipients[0] = p.initialRecipient;
        address[] memory beneficiaries = new address[](1);
        beneficiaries[0] = p.beneficiary;
        bytes[] memory data = new bytes[](1);
        data[0] = p.tokenData;
        bytes32[] memory commitments = new bytes32[](1);
        commitments[0] = p.mintCommitment;
        a.initialRecipientsHash =
            keccak256(abi.encode(keccak256("6529STREAM_MINT_BATCH_RECIPIENTS_V1"), recipients));
        a.beneficiariesHash = keccak256(
            abi.encode(keccak256("6529STREAM_MINT_BATCH_BENEFICIARIES_V1"), beneficiaries)
        );
        a.tokenDataArrayHash =
            keccak256(abi.encode(keccak256("6529STREAM_MINT_BATCH_TOKEN_DATA_V1"), data));
        a.mintCommitmentsHash =
            keccak256(abi.encode(keccak256("6529STREAM_MINT_BATCH_COMMITMENTS_V1"), commitments));
        a.payer = p.payer;
        a.executor = p.executor;
        a.asset = address(dutchToken);
        a.unitPrice = 1000;
        a.quantity = 1;
        a.policyHash = r.config.sale.mintPolicyHash;
        a.nonce = bytes32(nonce);
        a.deadline = uint64(block.timestamp + 1 hours);
    }

    function _dutchDigest(StreamPrivateSaleTypes.SaleAuthorization memory a)
        internal
        view
        returns (bytes32)
    {
        bytes32 domain = keccak256(
            abi.encode(
                keccak256(
                    "EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"
                ),
                keccak256("6529Stream Sales"),
                keccak256("1"),
                block.chainid,
                address(dutch)
            )
        );
        bytes32 body = keccak256(
            abi.encode(
                keccak256(
                    "SaleAuthorization(uint256 chainId,address saleAdapter,address mintManager,uint256 collectionId,bytes32 phaseId,bytes32 saleId,uint8 saleKind,bytes32 revenueClass,bytes32 expectedPrimaryPolicyHash,uint8 primaryPolicyMode,bytes32 initialRecipientsHash,bytes32 beneficiariesHash,bytes32 tokenDataArrayHash,bytes32 mintCommitmentsHash,address payer,address executor,address asset,uint256 unitPrice,uint256 quantity,bytes32 contentSelectionHash,bytes32 policyHash,bytes32 nonce,uint64 deadline,uint64 finalizeBy)"
                ),
                a
            )
        );
        return keccak256(abi.encodePacked(hex"1901", domain, body));
    }

    function _dutchMerklePhase(address account, uint256 price)
        internal
        returns (bytes32 phase, bytes32 counter, bytes memory data)
    {
        phase = keccak256(abi.encode("immediate price phase", price));
        counter = keccak256("immediate beneficiary allowlist");
        bytes32 leaf = keccak256(
            bytes.concat(
                keccak256(
                    abi.encode(
                        keccak256("6529STREAM_MINT_ALLOWLIST_LEAF_V1"),
                        block.chainid,
                        address(manager),
                        uint256(1),
                        phase,
                        counter,
                        account,
                        uint64(3),
                        true,
                        price
                    )
                )
            )
        );
        bytes32 definition = IStreamMintCounterPolicy(address(ledger))
            .registerCounterDefinition(
                IStreamMintCounterPolicy.Definition(
                    IStreamMintCounterPolicy.CounterScope.PHASE,
                    IStreamMintManager.CounterKeyMode.RECIPIENT,
                    leaf,
                    MANIFEST
                )
            );
        bytes32[] memory ids = new bytes32[](1);
        ids[0] = counter;
        IStreamMintManager.MintCounterConfig[] memory counters =
            new IStreamMintManager.MintCounterConfig[](1);
        counters[0] = IStreamMintManager.MintCounterConfig(
            true,
            IStreamMintManager.CounterKeyMode.RECIPIENT,
            IStreamMintLedger.CounterCapMode.MERKLE_STATIC,
            IStreamMintLedger.CounterDeltaMode.STATIC,
            3,
            1,
            definition
        );
        IStreamMintManager.MintGateConfig memory gate;
        manager.configurePhase(
            1,
            phase,
            IStreamMintManager.MintPhaseConfig(false, 0, 0, 1, MANIFEST, MANIFEST),
            gate,
            ids,
            counters
        );
        manager.setPhaseExecutor(1, phase, address(dutch), true);
        IStreamMintCounterPolicy.AllowlistProof[][] memory proofs =
            new IStreamMintCounterPolicy.AllowlistProof[][](1);
        proofs[0] = new IStreamMintCounterPolicy.AllowlistProof[](1);
        proofs[0][0] = IStreamMintCounterPolicy.AllowlistProof(3, true, price, new bytes32[](0));
        data = abi.encode(proofs);
    }
}
