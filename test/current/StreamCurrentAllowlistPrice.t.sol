// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../helpers/CurrentCommerceConservationFixture.sol";
import "../helpers/StreamCurrentAssetPolicy.sol";
import { StreamArtistSaleTypes as SaleTerms } from "../../smart-contracts/interfaces/stream/artist/StreamArtistSaleTypes.sol";
import "../mocks/MockStreamPaymentToken.sol";
import {
    StreamPrimarySaleSettlement
} from "../../smart-contracts/domains/revenue/StreamPrimarySaleSettlement.sol";
import "../../smart-contracts/domains/revenue/StreamERC20PrimarySettlementAdapter.sol";
import {StreamUniversalAllowlistPriceSale} from "../../smart-contracts/domains/mint/StreamUniversalAllowlistPriceSale.sol";
import {StreamUniversalAllowlistPrice} from "../../smart-contracts/domains/mint/StreamUniversalAllowlistPrice.sol";
import {IStreamUniversalAllowlistPriceSale} from "../../smart-contracts/interfaces/stream/mint/IStreamUniversalAllowlistPriceSale.sol";
import {IStreamUniversalFixedPriceSaleAdapter} from "../../smart-contracts/interfaces/stream/mint/IStreamUniversalFixedPriceSaleAdapter.sol";

interface CurrentPriceVm {
    function expectCall(address target,uint256 value,bytes calldata input,uint64 count) external;
}

contract CurrentPriceRecipient is IERC721Receiver {
    bool public rejects = true;

    function setRejects(bool value) external {
        rejects = value;
    }

    function onERC721Received(address, address, uint256, bytes calldata)
        external
        view
        returns (bytes4)
    {
        require(!rejects, "current universal recipient rejected");
        return IERC721Receiver.onERC721Received.selector;
    }
}

/// @notice Authored actual-current same-leaf integration recipe; not executed in this inert packet.
/// @dev Only the test ERC-20 and external entropy service are controlled boundaries. Permit2 is
///      disabled in this fixture; its domain tests are separate from these current-stack flows.
contract StreamCurrentAllowlistPriceTest is CurrentCommerceConservationFixture {
    bytes32 private constant UNIVERSAL_PHASE = keccak256("current universal ERC20 phase");
    StreamPrimarySaleSettlement private recorder;
    StreamERC20PrimarySettlementAdapter private payment;
    StreamUniversalAllowlistPriceSale private universalSale;
    MockStreamPaymentToken private token;
    OfficialSafe private artistSafe;
    OfficialSafe private payerSafe;
    uint256[] private keys;
    bytes32 private saleId;
    bool private requireSaleConsent;
    bytes32 private constant PRICE_COUNTER=keccak256("current exact same-leaf price");
    bytes private priceProof;
    bytes32 private priceDefinition;
    bool private priceByRecipient;
    bool private freePrice;
    address private priceSubject;


    function _fixtureSaleConsentScope() internal view override returns (uint8) {
        return requireSaleConsent ? 1 : 0;
    }

    function setUp() public {
        keys.push(0x5AFE01);
        keys.push(0x5AFE02);
        SafeComponents memory components = deploySafeComponents("1.4.1");
        artistSafe = createOfficialSafe(components, safeOwnerAddresses(keys), 2, 81);
        payerSafe = createOfficialSafe(components, safeOwnerAddresses(keys), 2, 82);
    }

    /// @dev Elect consent before the single graph deployment; return after governance time warps.
    function deployUniversalScenario(bool required) external {
        require(msg.sender == address(this), "fixture caller");
        requireSaleConsent = required;
        _deployCurrentStack(address(artistSafe), vm.addr(PLATFORM_KEY));
        require(
            manager.owner() == address(executor) && executor.genesisInitialized(),
            "actual final owners"
        );
        _enableUniversalCommerceFloor();
    }

    function _enableUniversalCommerceFloor() private {
        OfficialSafe governor =
            createOfficialSafe(deploySafeComponents("1.4.1"), safeOwnerAddresses(keys), 2, 83);
        _installGovernorSafe(governor, keys);
        _enableWaivedCommerceFloor();
    }

    function _artistProof(bytes32 digest) internal override returns (bytes memory) {
        return safeThresholdSignature(keys, safeMessageDigest(artistSafe, abi.encode(digest)));
    }

    function _deployAdditionalProducts() internal override {
        token = new MockStreamPaymentToken();
        token.mint(address(payerSafe), 10_000);
        recorder =
            new StreamPrimarySaleSettlement(primaryResolver, address(registry), revenueEscrow);
        payment = new StreamERC20PrimarySettlementAdapter(recorder, address(0), bytes32(0));
        universalSale = new StreamUniversalAllowlistPriceSale(
            manager, recorder, vm.addr(PLATFORM_KEY), IStreamArtistAttribution(address(artists)),
            IStreamGasParameterHost.GasParameterConfig("REVEAL_ATTEMPT_GAS_LIMIT", 1_000_000, 100_000, 2)
        );
        _assertDeployableProductionInstance(address(recorder));
        _assertDeployableProductionInstance(address(payment));
        _assertDeployableProductionInstance(address(universalSale));
    }

    function _additionalEscrowProducers() internal view override returns (address[] memory rows) {
        rows = new address[](1);
        rows[0] = address(recorder);
    }

    function _additionalOperatingPolicies()
        internal
        view
        override
        returns (GovernanceActionPolicyEntry[] memory rows)
    {
        rows = new GovernanceActionPolicyEntry[](3);
        rows[0] = _policy(universalSale.registerAllowlistSale.selector);
        rows[1] = _policy(universalSale.cancelSale.selector);
        rows[2] = _policy(universalSale.setPaused.selector);
        rows = _commerceFloorPolicies(rows);
    }

    function _policy(bytes4 selector) private view returns (GovernanceActionPolicyEntry memory) {
        return GovernanceActionPolicyEntry(
            1,
            address(universalSale),
            selector,
            address(universalSale).codehash,
            keccak256(abi.encode(DEPLOYMENT_HASH, address(universalSale))),
            1,
            0,
            0,
            bytes32(0)
        );
    }

    function _configureAdditionalProducts() internal override {
        StreamModuleRegistration[] memory records = new StreamModuleRegistration[](2);
        records[0] = _registration(
            address(payment),
            keccak256("ERC20_PRIMARY_SETTLEMENT_ADAPTER"),
            type(IStreamERC20PrimarySettlementAdapter).interfaceId
        );
        records[1] = _registration(
            address(universalSale),
            keccak256("FIXED_PRICE_SALE_ADAPTER"),
            type(IStreamERC20SaleExecution).interfaceId
        );
        (GovernanceCall[] memory registrations, bytes[] memory registrationData) =
            StreamCurrentStackPlan.registrationCalls(registry, records);
        GovernanceActionRequest memory asset = StreamCurrentAssetPolicy.activationRequest(
            assetPolicy, address(token), keccak256("current universal exact ERC20"), DEPLOYMENT_HASH
        );
        GovernanceCall[] memory calls = new GovernanceCall[](4);
        bytes[] memory data = new bytes[](4);
        for (uint256 i; i < 2; ++i) {
            calls[i] = registrations[i];
            data[i] = registrationData[i];
        }
        calls[2] = StreamCurrentStackPlan.call(
            address(assetPolicy),
            asset.callData,
            asset.scopeHash,
            asset.oldValueHash,
            asset.newValueHash
        );
        data[2] = asset.callData;
        data[3] = abi.encodeCall(entropy.setRequester, (address(universalSale), true));
        calls[3] = StreamCurrentStackPlan.call(
            address(entropy), data[3],
            keccak256(abi.encode("universal reveal requester", address(entropy), address(universalSale))),
            keccak256(abi.encode(false)), keccak256(abi.encode(true))
        );
        _executeGovernedBatch(calls, data);
        require(
            registry.moduleRecord(address(payment)).status == ModuleRegistryStatus.ACTIVE
                && registry.moduleRecord(address(universalSale)).status
                    == ModuleRegistryStatus.ACTIVE,
            "actual governed universal admission"
        );
        _configurePricePhase();
        saleId = universalSale.registerAllowlistSale(
            IStreamUniversalFixedPriceSaleAdapter.SaleConfig(
                address(payment),
                1,
                UNIVERSAL_PHASE,
                address(token),
                100,
                0,
                uint64(block.timestamp + 30 days),
                manager.phasePolicyHash(1, UNIVERSAL_PHASE),
                _nativePrimaryPolicyHash()
            ), IStreamUniversalAllowlistPriceSale.AllowlistPricePolicy(PRICE_COUNTER,freePrice)
        );
        require(
            executeSafe(
                payerSafe,
                keys,
                address(token),
                0,
                abi.encodeCall(token.approve, (address(payment), uint256(10_000))),
                0
            ),
            "Safe approves sole payer boundary"
        );
        universalSale.transferOwnership(address(executor));
    }

    function _registration(address module, bytes32 kind, bytes4 capability)
        private
        view
        returns (StreamModuleRegistration memory)
    {
        return StreamModuleRegistration(
            module,
            kind,
            keccak256("6529STREAM_UNIVERSAL_SETTLEMENT_V1"),
            capability,
            500_000,
            module.codehash,
            DEPLOYMENT_HASH,
            keccak256(abi.encode("universal module", kind)),
            "urn:6529stream:fixture:universal"
        );
    }

    function _executeGovernedBatch(GovernanceCall[] memory calls, bytes[] memory data) private {
        (bytes32 scope, bytes32 oldState, bytes32 nextState) = StreamGovernanceBootstrap.deriveBatchTransitionHashes(
            calls, StreamGovernanceBootstrap.governanceCallsHash(calls)
        );
        uint64 ready = uint64(block.timestamp + 48 hours);
        executor.publishGovernanceCallData(data);
        bytes memory scheduled = governanceRoot.execute(
            address(executor),
            0,
            abi.encodeCall(
                executor.scheduleGovernanceBatch,
                (
                    uint8(1),
                    calls,
                    scope,
                    oldState,
                    nextState,
                    ready,
                    uint64(ready + 7 days),
                    keccak256("current universal admission"),
                    "urn:6529stream:fixture:universal-admission",
                    DEPLOYMENT_HASH
                )
            )
        );
        bytes32 actionId = abi.decode(scheduled, (bytes32));
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamGovernanceExecutor.GovernanceActionNotExecutable.selector, actionId, ready
            )
        );
        executor.executeGovernanceBatch(actionId, calls, data);
        vm.warp(ready);
        executor.executeGovernanceBatch(actionId, calls, data);
    }

    function testRequiredUniversalSaleReadRejectsBeforeConsentAndSafePaymentThenSucceeds() public {
        this.deployUniversalScenario(true);
        require(artists.saleConsentScope(1) == 1, "actual immutable REQUIRED election");
        IStreamUniversalFixedPriceSaleAdapter.SaleExecutionData memory e =
            _signedExecution(61, address(payerSafe), address(payerSafe));
        bytes memory preview = abi.encodeCall(universalSale.previewAllowlistExecution, (e,priceProof));
        uint256 safeNonce = payerSafe.nonce();
        vm.expectRevert(abi.encodeWithSignature("Error(string)", "GS013"));
        this.executeRequiredUniversalRead(preview);
        require(
            payerSafe.nonce() == safeNonce && core.totalSupply() == 0
                && token.rawBalance(address(payerSafe)) == 10_000
                && recorder.totalOfficialSettled(address(token)) == 0,
            "actual Safe cannot obtain an executable preview without artist sale consent"
        );
        SaleTerms.Consent memory terms = SaleTerms.Consent(
            1, address(universalSale), saleId, universalSale.saleRecord(saleId).configHash
        );
        T.Authorization memory authorization = T.Authorization(
            IStreamArtistAuthorizationRevocation(address(artists))
                .artistAuthorizationState(fixtureArtistId, bytes32(0), 0).nextUnusedNonce,
            uint64(block.timestamp + 1 days),
            ""
        );
        require(
            executeSafe(
                artistSafe, keys, address(artists), 0,
                abi.encodeCall(IStreamArtistSaleAuthority.recordSaleConsent, (terms, authorization)), 0
            ),
            "actual artist Safe approves the registered ERC20 sale terms"
        );
        (bool consented, bytes32 recordHash) =
            artists.isSaleConsented(1, saleId, terms.saleConfigHash);
        SaleTerms.Record memory record = artists.saleConsentRecord(recordHash);
        require(
            consented && record.signer == address(artistSafe) && record.artistId == fixtureArtistId
                && record.terms.saleAdapter == address(universalSale),
            "canonical sale consent evidence"
        );
        require(
            executeSafe(payerSafe, keys, address(universalSale), 0, preview, 0),
            "identical Safe read succeeds after consent"
        );
        (StreamPrimarySettlementTypes.ERC20SettlementCandidate memory c,)=
            universalSale.previewAllowlistExecution(e,priceProof);
        require(
            executeSafe(
                payerSafe, keys, address(payment), 0,
                abi.encodeCall(payment.settleERC20PrimarySaleByPayer, (c, StreamUniversalAllowlistPrice.encode(e,c.sale.amount,priceProof))), 0
            ),
            "actual Safe payer completes the artist-approved ERC20 purchase"
        );
        _assertSettled(c, address(payerSafe));
    }

    /// @dev External void boundary includes the real Safe transaction and its nonce rollback.
    function executeRequiredUniversalRead(bytes calldata data) external {
        require(msg.sender == address(this), "fixture caller");
        require(executeSafe(payerSafe, keys, address(universalSale), 0, data, 0), "Safe read");
    }

    function testActualSafeDirectPaymentMintsRevealsAndClaimsOfficialRevenue() public {
        this.deployUniversalScenario(false);
        (
            IStreamUniversalFixedPriceSaleAdapter.SaleExecutionData memory e,
            StreamPrimarySettlementTypes.ERC20SettlementCandidate memory c
        ) = _execution(1, address(payerSafe), address(payerSafe));
        uint256 expectedRequest = provider.nextRequestId();
        require(
            executeSafe(
                payerSafe,
                keys,
                address(payment),
                0,
                abi.encodeCall(payment.settleERC20PrimarySaleByPayer, (c, StreamUniversalAllowlistPrice.encode(e,c.sale.amount,priceProof))),
                0
            ),
            "Safe direct universal mint"
        );
        _assertSettled(c, address(payerSafe));
        uint256 tokenId = core.lastAllocatedTokenId();
        require(provider.nextRequestId() == expectedRequest + 1, "automatic AT_MINT request reached actual provider");
        provider.fulfill(expectedRequest, keccak256("universal current entropy"));
        (bytes32 seed, bool finalized) = entropy.tokenSeed(tokenId);
        require(
            finalized && seed != 0 && bytes(core.tokenURI(tokenId)).length != 0,
            "actual reveal and metadata"
        );
        require(
            executeSafe(
                artistSafe,
                keys,
                wallet,
                0,
                abi.encodeCall(
                    IStreamSplitWallet.release,
                    (address(token), address(artistSafe), payable(address(artistSafe)))
                ),
                0
            ),
            "Safe claims artist share"
        );
        IStreamSplitWallet(wallet).release(address(token), PROTOCOL, payable(PROTOCOL));
        require(
            token.rawBalance(address(artistSafe)) == 36 && token.rawBalance(PROTOCOL) == 4
                && token.rawBalance(wallet) == 0,
            "exact current withdrawals"
        );
        require(
            recorder.totalOfficialSettled(address(token)) == 40,
            "official lifetime revenue persists"
        );
    }

    function testActualSafeSignedIntentMintsAndRejectsExactReplay() public {
        this.deployUniversalScenario(false);
        (
            IStreamUniversalFixedPriceSaleAdapter.SaleExecutionData memory e,
            StreamPrimarySettlementTypes.ERC20SettlementCandidate memory c
        ) = _execution(2, address(this), address(payerSafe));
        (StreamPrimarySettlementTypes.PaymentIntent memory intent, bytes memory signature) =
            _intent(2);
        payment.settleERC20PrimarySaleWithIntent(c, intent, signature, StreamUniversalAllowlistPrice.encode(e,c.sale.amount,priceProof));
        _assertSettled(c, address(payerSafe));
        require(
            payment.isPaymentIntentNonceUsed(address(payerSafe), intent.nonce),
            "real Safe consent consumed"
        );
        (bool ok, bytes memory failure) = address(payment)
            .call(
                abi.encodeCall(
                    payment.settleERC20PrimarySaleWithIntent, (c, intent, signature, StreamUniversalAllowlistPrice.encode(e,c.sale.amount,priceProof))
                )
            );
        require(
            !ok
                && keccak256(failure)
                    == keccak256(
                        abi.encodeWithSelector(
                            StreamERC20PrimarySettlementAdapter.PaymentIntentNonceUsed.selector,
                            address(payerSafe),
                            intent.nonce
                        )
                    ),
            "exact payer consent replay rejection"
        );
        require(
            core.totalSupply() == 1 && token.rawBalance(wallet) == 40
                && recorder.totalOfficialSettled(address(token)) == 40,
            "replay has no effect"
        );
    }

    function testLateRecipientRejectionRollsBackAndSameSafeIntentRetries() public {
        this.deployUniversalScenario(false);
        CurrentPriceRecipient recipient = new CurrentPriceRecipient();
        (
            IStreamUniversalFixedPriceSaleAdapter.SaleExecutionData memory e,
            StreamPrimarySettlementTypes.ERC20SettlementCandidate memory c
        ) = _execution(3, address(this), address(recipient));
        (StreamPrimarySettlementTypes.PaymentIntent memory intent, bytes memory signature) =
            _intent(3);
        bytes memory callData = abi.encodeCall(
            payment.settleERC20PrimarySaleWithIntent, (c, intent, signature, StreamUniversalAllowlistPrice.encode(e,c.sale.amount,priceProof))
        );
        // This unique receiver must be reached by both the failing call and identical retry.
        CurrentPriceVm(address(vm)).expectCall(address(recipient),0,
            abi.encodeWithSelector(IERC721Receiver.onERC721Received.selector),2);
        (bool ok, bytes memory failure) = address(payment).call(callData);
        require(
            !ok
                && keccak256(failure)
                    == keccak256(
                        abi.encodeWithSelector(
                            StreamERC20PrimarySettlementAdapter.PaymentCallbackFailed.selector
                        )
                    ),
            "exact payment callback rejection"
        );
        require(
            core.totalSupply() == 0 && core.collectionMintedEver(1) == 0
                && manager.nextOperationNonce() == 0
                && !manager.isOperationRootUsed(c.operationIdentityCommitment)
                && !manager.isAuthorizationUsed(_mintAuthorizationId(c)),
            "Core and ledger rollback"
        );
        require(
            !payment.isPaymentIntentNonceUsed(address(payerSafe), intent.nonce)
                && !universalSale.authorizationUsed(address(artistSafe), e.authorization.nonce)
                && universalSale.executionIdByNonce(saleId, e.authorization.executionNonce) == 0
                && universalSale.executionStatus(c.executionBinding.executionId) == 0
                && !recorder.settlementConsumed(
                    recorder.settlementKey(address(universalSale), c.executionBinding.executionId)
                ),
            "all consent and settlement rollback"
        );
        require(
            token.rawBalance(address(payerSafe)) == 10_000 && token.rawBalance(wallet) == 0
                && token.rawBalance(address(payment)) == 0
                && token.rawBalance(address(recorder)) == 0
                && recorder.totalOfficialSettled(address(token)) == 0,
            "all payment effects rollback"
        );
        require(ledger.counterValue(_priceValueKey())==0,"late failure restores genuine Ledger counter");
        _assertNoCommerceFloorReceipt(
            recorder.settlementKey(address(universalSale), c.executionBinding.executionId)
        );
        recipient.setRejects(false);
        (ok,) = address(payment).call(callData);
        require(ok, "identical calldata retries after recipient accepts");
        _assertSettled(c, address(recipient));
    }

    function _execution(uint256 nonce, address caller, address recipient)
        private
        returns (
            IStreamUniversalFixedPriceSaleAdapter.SaleExecutionData memory e,
            StreamPrimarySettlementTypes.ERC20SettlementCandidate memory c
        )
    {
        e = _signedExecution(nonce, caller, recipient);
        (c,)=universalSale.previewAllowlistExecution(e,priceProof);
    }

    function _signedExecution(uint256 nonce, address caller, address recipient)
        private
        returns (IStreamUniversalFixedPriceSaleAdapter.SaleExecutionData memory e)
    {
        e.tokenData = TOKEN_DATA;
        e.authorization = IStreamUniversalFixedPriceSaleAdapter.SaleAuthorization(
            saleId,
            universalSale.saleRecord(saleId).configHash,
            address(payerSafe),
            caller,
            recipient,
            address(artistSafe),
            keccak256(e.tokenData),
            keccak256(abi.encode("current universal mint", nonce)),
            nonce,
            bytes32(nonce),
            uint64(block.timestamp + 1 days)
        );
        bytes32 digest = universalSale.authorizationDigest(e.authorization);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(PLATFORM_KEY, digest);
        e.platformSignature = abi.encodePacked(r, s, v);
        e.artistSignature = _artistProof(digest);
    }

    function _intent(uint256 nonce)
        private
        returns (StreamPrimarySettlementTypes.PaymentIntent memory intent, bytes memory signature)
    {
        intent = StreamPrimarySettlementTypes.PaymentIntent(
            address(payerSafe),
            address(token),
            40,
            saleId,
            _nativePrimaryPolicyHash(),
            bytes32(nonce),
            uint64(block.timestamp + 1 days)
        );
        signature = safeThresholdSignature(
            keys, safeMessageDigest(payerSafe, abi.encode(payment.paymentIntentDigest(intent)))
        );
    }

    function _assertSettled(
        StreamPrimarySettlementTypes.ERC20SettlementCandidate memory c,
        address recipient
    ) private view {
        bytes32 key = recorder.settlementKey(address(universalSale), c.executionBinding.executionId);
        StreamPrimarySettlementTypes.PrimarySettlementResult memory result =
            recorder.settlementResult(key);
        _assertWaivedCommerceReceipt(address(recorder), key, 0);
        require(ledger.counterValue(_priceValueKey())==1,"same original allowlist key debited");
        require(
            core.ownerOf(core.lastAllocatedTokenId()) == recipient && core.totalSupply() == 1
                && core.collectionMintedEver(1) == 1,
            "real Core custody and supply"
        );
        require(
            manager.isOperationRootUsed(c.operationIdentityCommitment)
                && manager.nextOperationNonce() == 1
                && manager.isAuthorizationUsed(_mintAuthorizationId(c)),
            "real manager operation"
        );
        require(
            recorder.settlementConsumed(key) && result.wallet == wallet && result.amount == 40
                && result.operationIdentityCommitment == c.operationIdentityCommitment,
            "exact official result"
        );
        require(
            recorder.officialSettled(PRIMARY_REVENUE_CLASS, profile, wallet, address(token)) == 40
                && recorder.totalOfficialSettled(address(token)) == 40,
            "actual official accounting"
        );
        require(
            token.rawBalance(address(payerSafe)) == 9960 && token.rawBalance(wallet) == 40
                && token.rawBalance(address(payment)) == 0
                && token.rawBalance(address(recorder)) == 0,
            "single payer pull and exact terminal funding"
        );
    }

    function _mintAuthorizationId(StreamPrimarySettlementTypes.ERC20SettlementCandidate memory c)
        private
        pure
        returns (bytes32)
    {
        return keccak256(
            abi.encode(
                keccak256("6529STREAM_MINT_TICKET_AUTHORIZATION_V1"),
                c.executionBinding.saleAuthorizationDigest
            )
        );
    }

    function _configurePricePhase() private {
        IStreamMintManager.CounterKeyMode keyMode=priceByRecipient?IStreamMintManager.CounterKeyMode.RECIPIENT:IStreamMintManager.CounterKeyMode.PAYER;
        if(priceSubject==address(0))priceSubject=address(payerSafe);
        uint256 price=freePrice?0:40;
        bytes32 leaf=keccak256(bytes.concat(keccak256(abi.encode(keccak256("6529STREAM_MINT_ALLOWLIST_LEAF_V1"),block.chainid,address(manager),uint256(1),UNIVERSAL_PHASE,PRICE_COUNTER,priceSubject,uint64(1),true,price))));
        priceDefinition=ledger.registerCounterDefinition(IStreamMintCounterPolicy.Definition(IStreamMintCounterPolicy.CounterScope.PHASE,keyMode,leaf,keccak256("fixture complete one-leaf file")));
        IStreamMintCounterPolicy.AllowlistProof[][] memory proofs=new IStreamMintCounterPolicy.AllowlistProof[][](1);
        proofs[0]=new IStreamMintCounterPolicy.AllowlistProof[](1);
        proofs[0][0]=IStreamMintCounterPolicy.AllowlistProof(1,true,price,new bytes32[](0)); priceProof=abi.encode(proofs);
        bytes32[] memory ids=new bytes32[](1); ids[0]=PRICE_COUNTER;
        IStreamMintManager.MintCounterConfig[] memory rows=new IStreamMintManager.MintCounterConfig[](1);
        rows[0]=IStreamMintManager.MintCounterConfig(true,keyMode,IStreamMintLedger.CounterCapMode.MERKLE_STATIC,IStreamMintLedger.CounterDeltaMode.STATIC,1,1,priceDefinition);
        IStreamMintManager.MintPhaseConfig memory cfg=IStreamMintManager.MintPhaseConfig(false,0,0,1,keccak256("price phase"),keccak256("price phase metadata"));
        IStreamMintManager.MintGateConfig memory gate; address[] memory enabled=new address[](0);
        _recordFixturePolicy(UNIVERSAL_PHASE,manager.previewPhasePolicyHash(1,UNIVERSAL_PHASE,cfg,gate,ids,rows,enabled));
        manager.configurePhase(1,UNIVERSAL_PHASE,cfg,gate,ids,rows);
        enabled=new address[](1); enabled[0]=address(universalSale);
        _recordFixturePolicy(UNIVERSAL_PHASE,manager.previewPhasePolicyHash(1,UNIVERSAL_PHASE,cfg,gate,ids,rows,enabled));
        manager.setPhaseExecutor(1,UNIVERSAL_PHASE,address(universalSale),true);
    }

    function _priceValueKey() private view returns(bytes32) {
        IStreamMintManager.CounterKeyMode mode=priceByRecipient?IStreamMintManager.CounterKeyMode.RECIPIENT:IStreamMintManager.CounterKeyMode.PAYER;
        bytes32 subject=keccak256(abi.encode(keccak256("6529STREAM_MINT_COUNTER_SUBJECT_V1"),block.chainid,address(ledger),mode,priceSubject));
        return keccak256(abi.encode(keccak256("6529STREAM_MINT_COUNTER_VALUE_KEY_V1"),address(manager),uint256(1),UNIVERSAL_PHASE,PRICE_COUNTER,subject));
    }

    function testActualRecipientLeafDebitsBeneficiaryWithSeparatePayerAndExecutor() public {
        priceByRecipient=true; CurrentPriceRecipient recipient=new CurrentPriceRecipient(); recipient.setRejects(false); priceSubject=address(recipient);
        this.deployUniversalScenario(false);
        (IStreamUniversalFixedPriceSaleAdapter.SaleExecutionData memory e,StreamPrimarySettlementTypes.ERC20SettlementCandidate memory c)=_execution(71,address(this),address(recipient));
        (StreamPrimarySettlementTypes.PaymentIntent memory intent,bytes memory signature)=_intent(71);
        payment.settleERC20PrimarySaleWithIntent(c,intent,signature,StreamUniversalAllowlistPrice.encode(e,c.sale.amount,priceProof));
        _assertSettled(c,address(recipient));
        require(c.sale.payer==address(payerSafe) && c.executor==address(this) && c.sale.beneficiary==address(recipient) && c.sale.amount==40,"three distinct subject roles and leaf amount");
    }

    function testActualDeclaredFreeTierConsumesLedgerWithoutPaymentOrOfficialRevenue() public {
        freePrice=true; this.deployUniversalScenario(false);
        IStreamUniversalFixedPriceSaleAdapter.SaleExecutionData memory e=_signedExecution(72,address(payerSafe),address(payerSafe));
        (StreamPrimarySettlementTypes.ERC20SettlementCandidate memory c,)=universalSale.previewAllowlistExecution(e,priceProof);
        vm.recordLogs();
        require(executeSafe(payerSafe,keys,address(universalSale),0,abi.encodeCall(universalSale.executeAllowlistFreeMint,(e,priceProof)),0),"actual Safe free tier");
        Vm.Log[] memory logs=vm.getRecordedLogs();for(uint256 i;i<logs.length;++i)require(logs[i].emitter!=address(payment) && logs[i].emitter!=address(recorder),"no zero-amount official settlement event");
        require(core.totalSupply()==1 && core.collectionMintedEver(1)==1 && core.ownerOf(core.lastAllocatedTokenId())==address(payerSafe) && ledger.counterValue(_priceValueKey())==1,"actual free custody and same cap");
        require(manager.isOperationRootUsed(c.operationIdentityCommitment) && manager.isAuthorizationUsed(_mintAuthorizationId(c)) && universalSale.executionStatus(c.executionBinding.executionId)==2,"actual Manager and carrier replay");
        require(token.rawBalance(address(payerSafe))==10000 && token.rawBalance(wallet)==0 && recorder.totalOfficialSettled(address(token))==0,"free has no official ERC20 money");
    }

    function testActualMissingProofThenExactRetryAndOriginalLedgerCap() public {
        this.deployUniversalScenario(false);
        IStreamUniversalFixedPriceSaleAdapter.SaleExecutionData memory e=_signedExecution(73,address(payerSafe),address(payerSafe));
        vm.expectRevert(); universalSale.previewAllowlistExecution(e,"");
        require(ledger.counterValue(_priceValueKey())==0 && core.totalSupply()==0,"missing proof never spends cap");
        (StreamPrimarySettlementTypes.ERC20SettlementCandidate memory c,bytes memory data)=universalSale.previewAllowlistExecution(e,priceProof);
        require(executeSafe(payerSafe,keys,address(payment),0,abi.encodeCall(payment.settleERC20PrimarySaleByPayer,(c,data)),0),"same signed authorization and valid proof retry");
        _assertSettled(c,address(payerSafe));
        uint256 safeNonce=payerSafe.nonce();
        vm.expectRevert(abi.encodeWithSelector(IStreamMintLedger.CounterCapExceeded.selector,
            _priceValueKey(),uint256(2),uint256(1)));
        this.attemptSecondPriceMint();
        require(payerSafe.nonce()==safeNonce && ledger.counterValue(_priceValueKey())==1 && core.totalSupply()==1 && token.rawBalance(wallet)==40 && recorder.totalOfficialSettled(address(token))==40,"counter exhaustion is atomic");
    }

    function attemptSecondPriceMint() external {
        require(msg.sender==address(this),"fixture caller");
        IStreamUniversalFixedPriceSaleAdapter.SaleExecutionData memory e=_signedExecution(74,address(payerSafe),address(payerSafe));
        (StreamPrimarySettlementTypes.ERC20SettlementCandidate memory c,bytes memory data)=universalSale.previewAllowlistExecution(e,priceProof);
        require(executeSafe(payerSafe,keys,address(payment),0,abi.encodeCall(payment.settleERC20PrimarySaleByPayer,(c,data)),0),"second price mint");
    }
}
