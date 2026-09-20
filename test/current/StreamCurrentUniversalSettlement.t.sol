// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../helpers/CurrentCommerceConservationFixture.sol";
import "../helpers/StreamCurrentAssetPolicy.sol";
import "../helpers/OfficialPermit2Fixture.sol";
import { StreamArtistSaleTypes as SaleTerms } from "../../smart-contracts/interfaces/stream/artist/StreamArtistSaleTypes.sol";
import "../mocks/MockStreamPaymentToken.sol";
import {
    StreamPrimarySaleSettlement
} from "../../smart-contracts/domains/revenue/StreamPrimarySaleSettlement.sol";
import { StreamERC20PrimarySettlementAdapter } from "../../smart-contracts/domains/revenue/StreamERC20PrimarySettlementAdapter.sol";
import { IStreamPinnedPermit2 } from "../../smart-contracts/interfaces/stream/revenue/IStreamPinnedPermit2.sol";
import "../../smart-contracts/domains/mint/StreamUniversalFixedPriceSaleAdapter.sol";

contract CurrentUniversalRecipient is IERC721Receiver {
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

interface CurrentUniversalCallsVm {
    function expectCall(address target, uint256 value, bytes calldata data, uint64 count) external;
}

/// @dev Observes the actual registered/delivered state before a deliberate recipient rejection.
contract CurrentUniversalObservedRecipient is IERC721Receiver {
    StreamCore private immutable currentCore;
    StreamEntropyCoordinator private immutable coordinator;
    MockStreamPaymentToken private immutable paymentToken;
    StreamPrimarySaleSettlement private immutable settlement;
    address private immutable splitWallet;
    address private immutable controller;
    bool private accepting;
    uint256 public deliveries;

    error CurrentRecipientRejected(uint256 tokenId);

    constructor(
        StreamCore core_, StreamEntropyCoordinator coordinator_, MockStreamPaymentToken token_,
        StreamPrimarySaleSettlement recorder_, address wallet_
    ) {
        currentCore = core_;
        coordinator = coordinator_;
        paymentToken = token_;
        settlement = recorder_;
        splitWallet = wallet_;
        controller = msg.sender;
    }

    function accept() external {
        require(msg.sender == controller, "recipient controller");
        accepting = true;
    }

    function onERC721Received(address, address from, uint256 tokenId, bytes calldata)
        external returns (bytes4)
    {
        require(msg.sender == address(currentCore) && from == address(0) && tokenId == 1,
            "actual Core mint callback");
        require(currentCore.ownerOf(tokenId) == address(this)
            && currentCore.tokenLifecycle(tokenId) == 2
            && currentCore.coordinatorAtMint(tokenId) == address(coordinator)
            && coordinator.tokenEntropyStatus(tokenId) == StreamEntropyStatus.REGISTERED
            && coordinator.registeredAtBlock(tokenId) == block.number
            && coordinator.pendingRequestCount() == 0,
            "actual entropy registration and delivery precede receiver");
        require(paymentToken.rawBalance(splitWallet) == 100
            && settlement.totalOfficialSettled(address(paymentToken)) == 100
            && coordinator.revealFeeEscrow(1) == 0,
            "token revenue precedes receiver; native funding follows Manager return");
        ++deliveries;
        if (!accepting) revert CurrentRecipientRejected(tokenId);
        return IERC721Receiver.onERC721Received.selector;
    }
}

/// @notice Official Safe artists/payers use universal settlement with the actual current owners.
/// @dev Only the test ERC-20 and external entropy service are controlled boundaries. Permit2
///      is enabled only by the scenario that deploys and admits the exact upstream runtime.
contract StreamCurrentUniversalSettlementTest is
    CurrentCommerceConservationFixture,
    OfficialPermit2Fixture
{
    bytes32 private constant UNIVERSAL_PHASE = keccak256("current universal ERC20 phase");
    StreamPrimarySaleSettlement private recorder;
    StreamERC20PrimarySettlementAdapter private payment;
    StreamUniversalFixedPriceSaleAdapter private universalSale;
    MockStreamPaymentToken private token;
    OfficialSafe private artistSafe;
    OfficialSafe private payerSafe;
    uint256[] private keys;
    bytes32 private saleId;
    bool private requireSaleConsent;

    bool private usePermit2;
    address private currentPermit2;
    uint256 private nativeRevealFee;
    uint256 private constant NATIVE_FEE = 100;
    uint256 private constant PROVIDER_FEE = 60;
    uint256 private constant NATIVE_EXCESS = 75;

    struct NativeSafePacket {
        OfficialSafe funder;
        uint256[] funderKeys;
        IStreamUniversalFixedPriceSaleAdapter.SaleExecutionData execution;
        StreamPrimarySettlementTypes.ERC20SettlementCandidate candidate;
        StreamPrimarySettlementTypes.PaymentIntent intent;
        bytes input;
        bytes envelope;
        uint256 funderNonce;
        uint256 payerNonce;
        uint256 providerRequest;
    }

    function _configureInitialRevealPolicy() internal override {
        if (nativeRevealFee == 0) {
            super._configureInitialRevealPolicy();
            return;
        }
        entropy.configureCollectionRevealPolicy(
            1, 0, keccak256("ROLE_ENTROPY_REVEAL_OWNER"), 100, nativeRevealFee
        );
    }

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
        if (usePermit2) currentPermit2 = deployOfficialPermit2();
        payment = new StreamERC20PrimarySettlementAdapter(
            recorder, currentPermit2, usePermit2 ? currentPermit2.codehash : bytes32(0)
        );
        universalSale = new StreamUniversalFixedPriceSaleAdapter(
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
        rows[0] = _policy(universalSale.registerSale.selector);
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
        if (usePermit2) _configureCurrentPermit2();
        _configureMintPhase(UNIVERSAL_PHASE, address(universalSale));
        saleId = universalSale.registerSale(
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
            )
        );
        require(
            executeSafe(
                payerSafe,
                keys,
                address(token),
                0,
                abi.encodeCall(token.approve,
                    (usePermit2 ? currentPermit2 : address(payment), uint256(10_000))),
                0
            ),
            "Safe approves sole payer boundary"
        );
        universalSale.transferOwnership(address(executor));
    }

    function _configureCurrentPermit2() private {
        (bytes32 permitScope, bytes32 oldPermit, bytes32 nextPermit) =
            assetPolicy.assetPermitPolicyTransitionHashes(
                address(token), 2, 1, currentPermit2, currentPermit2.codehash
            );
        bytes32 id = keccak256("6529STREAM_GGP_WALLET_DEPOSIT_GAS_LIMIT");
        (uint256 value, uint256 floor, uint8 failureClass, uint64 revision) =
            factory.gasParameterInfo(id);
        require(value == 200_000, "preserved default whole-call budget before governed raise");
        bytes32 scope = keccak256(abi.encode(
            keccak256("6529STREAM_GAS_PARAMETER_SCOPE_V2"), block.chainid, address(factory), id
        ));
        bytes32 domain = keccak256("6529STREAM_GAS_PARAMETER_STATE_V2");
        GovernanceCall[] memory calls = new GovernanceCall[](2);
        bytes[] memory data = new bytes[](2);
        data[0] = abi.encodeCall(assetPolicy.setAssetPermitPolicy,
            (address(token), uint8(2), uint8(1), currentPermit2, currentPermit2.codehash));
        calls[0] = StreamCurrentStackPlan.call(
            address(assetPolicy), data[0], permitScope, oldPermit, nextPermit
        );
        data[1] = abi.encodeCall(factory.raiseGasParameter, (id, uint256(400_000)));
        calls[1] = StreamCurrentStackPlan.call(
            address(factory), data[1], scope,
            keccak256(abi.encode(domain, scope, value, floor, failureClass, revision)),
            keccak256(abi.encode(domain, scope, uint256(400_000), floor, failureClass, revision + 1))
        );
        // Actual class-1 scheduling, early-execution rejection, delay and semantic readback.
        _executeGovernedBatch(calls, data);
        IStreamAssetPermitPolicy.AssetPermitPolicy memory policy_ =
            assetPolicy.assetPermitPolicy(address(token));
        require(policy_.capabilities == 2 && policy_.permit2AllowanceMode == 1
            && policy_.permit2 == currentPermit2 && policy_.permit2CodeHash == currentPermit2.codehash
            && policy_.assetCodeHash == address(token).codehash
            && policy_.assetPolicyHash == assetPolicy.assetPolicyHash(address(token))
            && policy_.assetPolicyRevision == assetPolicy.assetPolicyRevision(address(token))
            && policy_.revision == 1 && factory.gasParameter(id) == 400_000
            && payment.permit2() == currentPermit2 && payment.permit2CodeHash() == currentPermit2.codehash,
            "actual governed Permit2 admission and complete-call budget");
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
        bytes memory preview = abi.encodeCall(universalSale.previewExecution, (e));
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
        StreamPrimarySettlementTypes.ERC20SettlementCandidate memory c =
            universalSale.previewExecution(e);
        require(
            executeSafe(
                payerSafe, keys, address(payment), 0,
                abi.encodeCall(payment.settleERC20PrimarySaleByPayer, (c, abi.encode(e))), 0
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
                abi.encodeCall(payment.settleERC20PrimarySaleByPayer, (c, abi.encode(e))),
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
            token.rawBalance(address(artistSafe)) == 90 && token.rawBalance(PROTOCOL) == 10
                && token.rawBalance(wallet) == 0,
            "exact current withdrawals"
        );
        require(
            recorder.totalOfficialSettled(address(token)) == 100,
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
        payment.settleERC20PrimarySaleWithIntent(c, intent, signature, abi.encode(e));
        _assertSettled(c, address(payerSafe));
        require(
            payment.isPaymentIntentNonceUsed(address(payerSafe), intent.nonce),
            "real Safe consent consumed"
        );
        (bool ok, bytes memory failure) = address(payment)
            .call(
                abi.encodeCall(
                    payment.settleERC20PrimarySaleWithIntent, (c, intent, signature, abi.encode(e))
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
            core.totalSupply() == 1 && token.rawBalance(wallet) == 100
                && recorder.totalOfficialSettled(address(token)) == 100,
            "replay has no effect"
        );
    }

    function testLateRecipientRejectionRollsBackAndSameSafeIntentRetries() public {
        this.deployUniversalScenario(false);
        CurrentUniversalRecipient recipient = new CurrentUniversalRecipient();
        (
            IStreamUniversalFixedPriceSaleAdapter.SaleExecutionData memory e,
            StreamPrimarySettlementTypes.ERC20SettlementCandidate memory c
        ) = _execution(3, address(this), address(recipient));
        (StreamPrimarySettlementTypes.PaymentIntent memory intent, bytes memory signature) =
            _intent(3);
        bytes memory callData = abi.encodeCall(
            payment.settleERC20PrimarySaleWithIntent, (c, intent, signature, abi.encode(e))
        );
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
        _assertNoCommerceFloorReceipt(
            recorder.settlementKey(address(universalSale), c.executionBinding.executionId)
        );
        recipient.setRejects(false);
        (ok,) = address(payment).call(callData);
        require(ok, "identical calldata retries after recipient accepts");
        _assertSettled(c, address(recipient));
    }

    function testActualTwoSafesFundNativeRevealRequestAndOnlyExecutorClaimsExcess() public {
        _deployNativeRevealScenario();
        NativeSafePacket memory p = _nativeSafePacket(4, address(payerSafe));
        _expectTokenFunding(1);
        _expectNativeRequest();
        (bool ok,) = address(p.funder).call(p.envelope);
        require(ok, "actual funder Safe pays the token payer's signed intent");
        _assertNativeSafeSettlement(p);
        _finalizeAndClaimNativeExcess(p);
    }

    function testActualTwoSafesRestoreRegisteredMintAndRetryIdenticalNativeEnvelope() public {
        _deployNativeRevealScenario();
        CurrentUniversalObservedRecipient recipient = new CurrentUniversalObservedRecipient(
            core, entropy, token, recorder, wallet
        );
        NativeSafePacket memory p = _nativeSafePacket(5, address(recipient));
        CurrentUniversalCallsVm(address(vm)).expectCall(
            address(recipient), 0, abi.encodeWithSelector(IERC721Receiver.onERC721Received.selector), 2
        );
        _expectTokenFunding(2);
        // The rejected delivery must precede fee funding and the at-mint provider call.
        _expectNativeRequest();
        (bool ok, bytes memory reason) = address(p.funder).call(p.envelope);
        _requireSafeFailure(ok, reason);
        require(recipient.deliveries() == 0, "rejected recipient state rolls back");
        _assertNativeSafeRollback(p);
        recipient.accept();
        // Retain the complete signatures, inner payment bytes, native value and Safe nonce.
        (ok,) = address(p.funder).call(p.envelope);
        require(ok && recipient.deliveries() == 1, "byte-identical signed Safe retry delivers");
        _assertNativeSafeSettlement(p);
        _finalizeAndClaimNativeExcess(p);
    }

    function testActualSafePermit2RestoresNativeMintThenRetriesExactPermitAndSafeEnvelope() public {
        usePermit2 = true;
        _deployNativeRevealScenario();
        vm.deal(address(payerSafe), NATIVE_FEE + NATIVE_EXCESS);
        CurrentUniversalObservedRecipient recipient = new CurrentUniversalObservedRecipient(
            core, entropy, token, recorder, wallet
        );
        (IStreamUniversalFixedPriceSaleAdapter.SaleExecutionData memory e,
            StreamPrimarySettlementTypes.ERC20SettlementCandidate memory c) =
            _execution(6, address(payerSafe), address(recipient));
        StreamPrimarySettlementTypes.Permit2TransferAuthorization memory permit = _safePermit2(7);
        bytes memory input = abi.encodeCall(payment.settleERC20PrimarySaleWithPermit2,
            (c, permit, abi.encode(e)));
        bytes memory envelope = _signedNativeSafeCall(
            payerSafe, keys, address(payment), NATIVE_FEE + NATIVE_EXCESS, input
        );
        uint256 safeNonce = payerSafe.nonce();
        uint256 requestId = provider.nextRequestId();
        require(token.allowance(address(payerSafe), address(payment)) == 0
            && token.allowance(address(payerSafe), currentPermit2) == 10_000,
            "sole finite token approval targets official Permit2");
        _expectTokenFunding(2);
        _expectNativeRequest();
        CurrentUniversalCallsVm(address(vm)).expectCall(
            address(recipient), 0, abi.encodeWithSelector(IERC721Receiver.onERC721Received.selector), 2
        );
        CurrentUniversalCallsVm(address(vm)).expectCall(
            currentPermit2, 0,
            abi.encodeCall(IStreamPinnedPermit2.permitTransferFrom, (
                IStreamPinnedPermit2.PermitTransferFrom(
                    IStreamPinnedPermit2.TokenPermissions(address(token), 100), permit.nonce, permit.deadline),
                IStreamPinnedPermit2.SignatureTransferDetails(address(payment), 100),
                address(payerSafe), permit.signature
            )), 2
        );
        (bool ok, bytes memory reason) = address(payerSafe).call(envelope);
        _requireSafeFailure(ok, reason);
        require(recipient.deliveries() == 0 && payerSafe.nonce() == safeNonce
            && token.rawBalance(address(payerSafe)) == 10_000
            && token.allowance(address(payerSafe), currentPermit2) == 10_000
            && token.allowance(address(payerSafe), address(payment)) == 0
            && IStreamPinnedPermit2(currentPermit2).nonceBitmap(address(payerSafe), 0) == 0,
            "actual Safe nonce, Permit2 bitmap and finite approval all roll back");
        require(core.totalSupply() == 0 && core.lastAllocatedTokenId() == 0
            && core.collectionMintedEver(1) == 0 && core.coordinatorAtMint(1) == address(0)
            && manager.nextOperationNonce() == 0
            && !manager.isOperationRootUsed(c.operationIdentityCommitment)
            && !manager.isAuthorizationUsed(_mintAuthorizationId(c))
            && !universalSale.authorizationUsed(address(artistSafe), e.authorization.nonce)
            && universalSale.executionIdByNonce(saleId, e.authorization.executionNonce) == 0
            && universalSale.executionStatus(c.executionBinding.executionId) == 0
            && payment.phase() == StreamERC20PrimarySettlementAdapter.Phase.IDLE,
            "actual mint and sale consent roll back after Permit2 funding");
        bytes32 key = recorder.settlementKey(address(universalSale), c.executionBinding.executionId);
        require(!recorder.settlementConsumed(key) && recorder.totalOfficialSettled(address(token)) == 0
            && token.rawBalance(wallet) == 0 && token.rawBalance(address(payment)) == 0
            && token.rawBalance(address(recorder)) == 0,
            "original token funding and official settlement roll back");
        _assertNoCommerceFloorReceipt(key);
        require(entropy.tokenEntropyStatus(1) == StreamEntropyStatus.NONE
            && entropy.registeredAtBlock(1) == 0 && entropy.pendingRequestCount() == 0
            && entropy.nonterminalTokenCount(1) == 0 && provider.nextRequestId() == requestId
            && entropy.revealFeeEscrow(1) == 0 && entropy.totalRevealFeeEscrows() == 0
            && entropy.totalFeeCredits() == 0 && address(entropy).balance == 0
            && address(provider).balance == 0 && universalSale.refundLiability() == 0
            && universalSale.refundableBalance(saleId, address(payerSafe)) == 0
            && address(universalSale).balance == 0 && address(payment).balance == 0
            && address(payerSafe).balance == NATIVE_FEE + NATIVE_EXCESS,
            "actual entropy registration and native custody roll back before request");
        recipient.accept();
        // Reuse both original Permit2 proof and the complete original native-value Safe CALL.
        (ok,) = address(payerSafe).call(envelope);
        require(ok && recipient.deliveries() == 1, "exact Safe Permit2/native retry delivers");
        _assertSettled(c, address(recipient));
        require(payerSafe.nonce() == safeNonce + 1
            && token.allowance(address(payerSafe), currentPermit2) == 9900
            && token.allowance(address(payerSafe), address(payment)) == 0
            && IStreamPinnedPermit2(currentPermit2).nonceBitmap(address(payerSafe), 0) == uint256(1) << 7
            && payment.phase() == StreamERC20PrimarySettlementAdapter.Phase.IDLE,
            "actual Safe Permit2 consumes exactly one nonce bit and token amount");
        _assertPermit2NativeRequest(requestId);
        provider.fulfill(requestId, keccak256("actual Safe Permit2 native reveal"));
        (bytes32 seed, bool finalized) = entropy.tokenSeed(1);
        require(finalized && seed != 0 && entropy.tokenEntropyStatus(1) == StreamEntropyStatus.FINALIZED
            && entropy.pendingRequestCount() == 0 && entropy.nonterminalTokenCount(1) == 0
            && bytes(core.tokenURI(1)).length != 0,
            "actual Permit2-funded token finalizes through its selected Coordinator");
        require(executeSafe(payerSafe, keys, address(universalSale), 0,
            abi.encodeCall(universalSale.claimRefund, (saleId, address(payerSafe))), 0),
            "actual payer-executor Safe claims its own native allowance excess");
        (bytes32 refundSale, address refundOwner) = universalSale.refundAccountAt(0);
        require(payerSafe.nonce() == safeNonce + 2 && address(payerSafe).balance == NATIVE_EXCESS
            && universalSale.refundLiability() == 0 && address(universalSale).balance == 0
            && universalSale.refundableBalance(saleId, address(payerSafe)) == 0
            && universalSale.refundAccountCount() == 1 && refundSale == saleId
            && refundOwner == address(payerSafe) && address(recipient).balance == 0
            && entropy.revealFeeEscrow(1) == NATIVE_FEE - PROVIDER_FEE
            && address(provider).balance == PROVIDER_FEE && token.rawBalance(wallet) == 100
            && recorder.totalOfficialSettled(address(token)) == 100,
            "Permit2 token proceeds stay separate from provider fee and native refund");
    }

    function _safePermit2(uint256 nonce)
        private returns (StreamPrimarySettlementTypes.Permit2TransferAuthorization memory permit)
    {
        permit.nonce = nonce;
        permit.deadline = block.timestamp + 1 days;
        bytes32 permissions = keccak256(abi.encode(
            keccak256("TokenPermissions(address token,uint256 amount)"), address(token), uint256(100)
        ));
        bytes32 transfer = keccak256(abi.encode(
            keccak256("PermitTransferFrom(TokenPermissions permitted,address spender,uint256 nonce,uint256 deadline)TokenPermissions(address token,uint256 amount)"),
            permissions, address(payment), permit.nonce, permit.deadline
        ));
        bytes32 digest = keccak256(abi.encodePacked(hex"1901", permit2Domain(currentPermit2), transfer));
        permit.signature = safeThresholdSignature(keys, safeMessageDigest(payerSafe, abi.encode(digest)));
    }

    function _assertPermit2NativeRequest(uint256 providerRequest) private view {
        (StreamEntropyStatus status, bytes32 seed, address selected,,, bytes32 requestKey,
            uint256 requestId, uint16 attempt) = entropy.tokenEntropy(1);
        require(status == StreamEntropyStatus.REQUESTED && seed == 0 && selected == address(provider)
            && requestKey != 0 && requestId == providerRequest && attempt == 1
            && provider.nextRequestId() == providerRequest + 1
            && entropy.providerRequestKeys(address(provider), requestId) == requestKey
            && entropy.pendingRequestCount() == 1 && entropy.nonterminalTokenCount(1) == 1
            && core.coordinatorAtMint(1) == address(entropy),
            "actual Permit2/native mint requests the original selected provider");
        require(entropy.revealFeeEscrow(1) == NATIVE_FEE - PROVIDER_FEE
            && entropy.totalRevealFeeEscrows() == NATIVE_FEE - PROVIDER_FEE
            && address(entropy).balance == NATIVE_FEE - PROVIDER_FEE
            && address(provider).balance == PROVIDER_FEE && entropy.totalFeeCredits() == 0
            && universalSale.refundableBalance(saleId, address(payerSafe)) == NATIVE_EXCESS
            && universalSale.refundLiability() == NATIVE_EXCESS
            && address(universalSale).balance == NATIVE_EXCESS && address(payment).balance == 0
            && address(payerSafe).balance == 0,
            "Permit2 payer-executor owns only its native excess; token price stays 100");
    }

    function _deployNativeRevealScenario() private {
        nativeRevealFee = NATIVE_FEE;
        this.deployUniversalScenario(false);
        provider.setFee(PROVIDER_FEE);
        IStreamEntropyCollectionPolicy.PolicyRecord memory policy_ =
            entropy.collectionEntropyPolicy(1);
        IStreamRevealFeeEscrow.CollectionRevealPolicy memory reveal = entropy.collectionRevealPolicy(1);
        require(policy_.configured && !policy_.frozen
            && policy_.mode == IStreamEntropyCollectionPolicy.Mode.ASYNC
            && policy_.renderRequirement == IStreamEntropyCollectionPolicy.RenderRequirement.REQUIRED
            && reveal.declared && reveal.requestMode == 0 && reveal.revealFeePerTokenWei == NATIVE_FEE
            && entropy.requesters(address(universalSale))
            && address(entropy.core()) == address(core),
            "actual ASYNC REQUIRED policy and governed sale requester");
    }

    function _nativeSafePacket(uint256 nonce, address recipient)
        private returns (NativeSafePacket memory p)
    {
        p.funderKeys = new uint256[](2);
        p.funderKeys[0] = 0x5AFE03;
        p.funderKeys[1] = 0x5AFE04;
        p.funder = createOfficialSafe(
            deploySafeComponents("1.4.1"), safeOwnerAddresses(p.funderKeys), 2, 840 + nonce
        );
        require(address(p.funder) != address(payerSafe) && payerSafe.getThreshold() == 2
            && p.funder.getThreshold() == 2, "distinct actual threshold Safes");
        vm.deal(address(p.funder), NATIVE_FEE + NATIVE_EXCESS);
        vm.deal(address(payerSafe), 73);
        (p.execution, p.candidate) = _execution(nonce, address(p.funder), recipient);
        bytes memory proof;
        (p.intent, proof) = _intent(nonce);
        require(p.intent.maxAmount == 100 && p.intent.asset == address(token)
            && p.intent.payer == address(payerSafe) && p.candidate.executor == address(p.funder),
            "original token-only intent with separately bound native funder");
        p.input = abi.encodeCall(
            payment.settleERC20PrimarySaleWithIntent, (p.candidate, p.intent, proof, abi.encode(p.execution))
        );
        p.funderNonce = p.funder.nonce();
        p.payerNonce = payerSafe.nonce();
        p.providerRequest = provider.nextRequestId();
        p.envelope = _signedNativeSafeCall(
            p.funder, p.funderKeys, address(payment), NATIVE_FEE + NATIVE_EXCESS, p.input
        );
    }

    function _signedNativeSafeCall(
        OfficialSafe account, uint256[] memory signers, address target, uint256 value, bytes memory input
    ) private returns (bytes memory) {
        bytes32 digest = account.getTransactionHash(
            target, value, input, 0, 0, 0, 0, address(0), address(0), account.nonce()
        );
        bytes memory signatures = safeThresholdSignature(signers, digest);
        return abi.encodeCall(OfficialSafe.execTransaction,
            (target, value, input, uint8(0), uint256(0), uint256(0), uint256(0),
                address(0), payable(address(0)), signatures));
    }

    function _expectTokenFunding(uint64 count) private {
        CurrentUniversalCallsVm(address(vm)).expectCall(
            address(token), 0,
            abi.encodeCall(token.transferFrom, (address(payerSafe), address(payment), uint256(100))), count
        );
        CurrentUniversalCallsVm(address(vm)).expectCall(
            address(token), 0, abi.encodeCall(token.transfer, (address(recorder), uint256(100))), count
        );
        CurrentUniversalCallsVm(address(vm)).expectCall(
            address(token), 0, abi.encodeCall(token.transfer, (wallet, uint256(100))), count
        );
    }

    function _expectNativeRequest() private {
        CurrentUniversalCallsVm(address(vm)).expectCall(
            address(entropy), NATIVE_FEE, abi.encodeCall(entropy.fundRevealFeeEscrow, (uint256(1))), 1
        );
        CurrentUniversalCallsVm(address(vm)).expectCall(
            address(provider), PROVIDER_FEE,
            abi.encodeWithSelector(IStreamEntropyProvider.requestEntropy.selector), 1
        );
    }

    function _requireSafeFailure(bool ok, bytes memory reason) private pure {
        require(!ok && keccak256(reason) == keccak256(abi.encodeWithSignature("Error(string)", "GS013")),
            "actual Safe reports reverted target call");
    }

    function _assertNativeSafeRollback(NativeSafePacket memory p) private view {
        require(p.funder.nonce() == p.funderNonce && payerSafe.nonce() == p.payerNonce
            && core.totalSupply() == 0 && core.lastAllocatedTokenId() == 0
            && core.collectionMintedEver(1) == 0 && core.coordinatorAtMint(1) == address(0)
            && manager.nextOperationNonce() == 0
            && !manager.isOperationRootUsed(p.candidate.operationIdentityCommitment)
            && !manager.isAuthorizationUsed(_mintAuthorizationId(p.candidate)),
            "actual Safe Core Manager and Ledger state restored");
        require(!payment.isPaymentIntentNonceUsed(address(payerSafe), p.intent.nonce)
            && !universalSale.authorizationUsed(address(artistSafe), p.execution.authorization.nonce)
            && universalSale.executionIdByNonce(saleId, p.execution.authorization.executionNonce) == 0
            && universalSale.executionStatus(p.candidate.executionBinding.executionId) == 0
            && recorder.totalOfficialSettled(address(token)) == 0
            && token.rawBalance(address(payerSafe)) == 10_000 && token.rawBalance(wallet) == 0
            && token.rawBalance(address(payment)) == 0 && token.rawBalance(address(recorder)) == 0
            && token.allowance(address(payerSafe), address(payment)) == 10_000,
            "token consent, finite allowance and original revenue restored");
        bytes32 key = recorder.settlementKey(address(universalSale), p.candidate.executionBinding.executionId);
        require(!recorder.settlementConsumed(key), "official receipt not consumed");
        _assertNoCommerceFloorReceipt(key);
        require(entropy.tokenEntropyStatus(1) == StreamEntropyStatus.NONE
            && entropy.registeredAtBlock(1) == 0 && entropy.pendingRequestCount() == 0
            && entropy.nonterminalTokenCount(1) == 0 && provider.nextRequestId() == p.providerRequest
            && entropy.revealFeeEscrow(1) == 0 && entropy.totalRevealFeeEscrows() == 0
            && entropy.totalFeeCredits() == 0 && address(entropy).balance == 0
            && address(provider).balance == 0 && universalSale.refundLiability() == 0
            && universalSale.refundableBalance(saleId, address(p.funder)) == 0
            && address(universalSale).balance == 0 && address(payment).balance == 0
            && address(p.funder).balance == NATIVE_FEE + NATIVE_EXCESS
            && address(payerSafe).balance == 73,
            "registration, requests and both native custody locations restored");
    }

    function _assertNativeSafeSettlement(NativeSafePacket memory p) private view {
        _assertSettled(p.candidate, p.execution.authorization.recipient);
        require(p.funder.nonce() == p.funderNonce + 1 && payerSafe.nonce() == p.payerNonce
            && payment.isPaymentIntentNonceUsed(address(payerSafe), p.intent.nonce)
            && token.allowance(address(payerSafe), address(payment)) == 9900,
            "only funder Safe CALL nonce advances; exact token intent consumed");
        (StreamEntropyStatus status, bytes32 seed, address selected,,, bytes32 requestKey,
            uint256 requestId, uint16 attempt) = entropy.tokenEntropy(1);
        require(status == StreamEntropyStatus.REQUESTED && seed == 0 && selected == address(provider)
            && requestKey != 0 && requestId == p.providerRequest && attempt == 1
            && provider.nextRequestId() == p.providerRequest + 1
            && entropy.providerRequestKeys(address(provider), requestId) == requestKey
            && entropy.pendingRequestCount() == 1 && entropy.nonterminalTokenCount(1) == 1
            && core.coordinatorAtMint(1) == address(entropy),
            "original actual Coordinator records the authorized provider request");
        require(entropy.revealFeeEscrow(1) == NATIVE_FEE - PROVIDER_FEE
            && entropy.totalRevealFeeEscrows() == NATIVE_FEE - PROVIDER_FEE
            && address(entropy).balance == NATIVE_FEE - PROVIDER_FEE
            && address(provider).balance == PROVIDER_FEE && entropy.totalFeeCredits() == 0
            && universalSale.refundableBalance(saleId, address(p.funder)) == NATIVE_EXCESS
            && universalSale.refundableBalance(saleId, address(payerSafe)) == 0
            && universalSale.refundLiability() == NATIVE_EXCESS
            && address(universalSale).balance == NATIVE_EXCESS && address(payment).balance == 0
            && address(p.funder).balance == 0 && address(payerSafe).balance == 73,
            "actual native escrow spend and executor-only excess exclude official token revenue");
    }

    function _finalizeAndClaimNativeExcess(NativeSafePacket memory p) private {
        provider.fulfill(p.providerRequest, keccak256("actual two-Safe ERC20 reveal"));
        (bytes32 seed, bool finalized) = entropy.tokenSeed(1);
        require(finalized && seed != 0 && entropy.tokenEntropyStatus(1) == StreamEntropyStatus.FINALIZED
            && entropy.pendingRequestCount() == 0 && entropy.nonterminalTokenCount(1) == 0
            && bytes(core.tokenURI(1)).length != 0,
            "actual provider result finalizes original token and metadata");
        bytes memory wrongClaim = _signedNativeSafeCall(
            payerSafe, keys, address(universalSale), 0,
            abi.encodeCall(universalSale.claimRefund, (saleId, address(payerSafe)))
        );
        (bool ok, bytes memory reason) = address(payerSafe).call(wrongClaim);
        _requireSafeFailure(ok, reason);
        require(payerSafe.nonce() == p.payerNonce && address(payerSafe).balance == 73
            && universalSale.refundableBalance(saleId, address(p.funder)) == NATIVE_EXCESS,
            "token payer Safe cannot consume another executor's native credit");
        require(executeSafe(p.funder, p.funderKeys, address(universalSale), 0,
            abi.encodeCall(universalSale.claimRefund, (saleId, address(p.funder))), 0),
            "actual native funder Safe claims its own excess");
        (bytes32 refundSale, address refundOwner) = universalSale.refundAccountAt(0);
        require(address(p.funder).balance == NATIVE_EXCESS && p.funder.nonce() == p.funderNonce + 2
            && address(payerSafe).balance == 73 && universalSale.refundLiability() == 0
            && universalSale.refundableBalance(saleId, address(p.funder)) == 0
            && address(universalSale).balance == 0 && universalSale.refundAccountCount() == 1
            && refundSale == saleId && refundOwner == address(p.funder)
            && entropy.revealFeeEscrow(1) == NATIVE_FEE - PROVIDER_FEE
            && address(provider).balance == PROVIDER_FEE && token.rawBalance(wallet) == 100
            && recorder.totalOfficialSettled(address(token)) == 100,
            "discoverable native refund closes without changing token revenue or provider accounting");
    }

    function _execution(uint256 nonce, address caller, address recipient)
        private
        returns (
            IStreamUniversalFixedPriceSaleAdapter.SaleExecutionData memory e,
            StreamPrimarySettlementTypes.ERC20SettlementCandidate memory c
        )
    {
        e = _signedExecution(nonce, caller, recipient);
        c = universalSale.previewExecution(e);
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
            100,
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
            recorder.settlementConsumed(key) && result.wallet == wallet && result.amount == 100
                && result.operationIdentityCommitment == c.operationIdentityCommitment,
            "exact official result"
        );
        require(
            recorder.officialSettled(PRIMARY_REVENUE_CLASS, profile, wallet, address(token)) == 100
                && recorder.totalOfficialSettled(address(token)) == 100,
            "actual official accounting"
        );
        require(
            token.rawBalance(address(payerSafe)) == 9900 && token.rawBalance(wallet) == 100
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
}
