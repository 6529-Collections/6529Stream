// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../helpers/StreamCurrentStackFixture.sol";
import "../helpers/StreamCurrentAssetPolicy.sol";
import "../helpers/OfficialSafeFixture.sol";
import "../mocks/MockStreamPaymentToken.sol";
import "../../smart-contracts/domains/revenue/StreamPrimarySaleSettlement.sol";
import "../../smart-contracts/domains/revenue/StreamERC20PrimarySettlementAdapter.sol";
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

/// @notice Official Safe artists/payers use universal settlement with the actual current owners.
/// @dev Only the test ERC-20 and external entropy service are controlled boundaries. Permit2 is
///      disabled in this fixture; its domain tests are separate from these current-stack flows.
contract StreamCurrentUniversalSettlementTest is StreamCurrentStackFixture, OfficialSafeFixture {
    bytes32 private constant UNIVERSAL_PHASE = keccak256("current universal ERC20 phase");
    StreamPrimarySaleSettlement private recorder;
    StreamERC20PrimarySettlementAdapter private payment;
    StreamUniversalFixedPriceSaleAdapter private universalSale;
    MockStreamPaymentToken private token;
    OfficialSafe private artistSafe;
    OfficialSafe private payerSafe;
    uint256[] private keys;
    bytes32 private saleId;

    function setUp() public {
        keys.push(0x5AFE01);
        keys.push(0x5AFE02);
        SafeComponents memory components = deploySafeComponents("1.4.1");
        artistSafe = createOfficialSafe(components, safeOwnerAddresses(keys), 2, 81);
        payerSafe = createOfficialSafe(components, safeOwnerAddresses(keys), 2, 82);
        _deployCurrentStack(address(artistSafe), vm.addr(PLATFORM_KEY));
        require(
            manager.owner() == address(executor) && executor.genesisInitialized(),
            "actual final owners"
        );
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
        universalSale = new StreamUniversalFixedPriceSaleAdapter(
            manager, recorder, vm.addr(PLATFORM_KEY), IStreamArtistAttribution(address(artists))
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
        GovernanceCall[] memory calls = new GovernanceCall[](3);
        bytes[] memory data = new bytes[](3);
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
        _executeGovernedBatch(calls, data);
        require(
            registry.moduleRecord(address(payment)).status == ModuleRegistryStatus.ACTIVE
                && registry.moduleRecord(address(universalSale)).status
                    == ModuleRegistryStatus.ACTIVE,
            "actual governed universal admission"
        );
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

    function testActualSafeDirectPaymentMintsRevealsAndClaimsOfficialRevenue() public {
        (
            IStreamUniversalFixedPriceSaleAdapter.SaleExecutionData memory e,
            StreamPrimarySettlementTypes.ERC20SettlementCandidate memory c
        ) = _execution(1, address(payerSafe), address(payerSafe));
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
        (, uint256 requestId) = entropy.requestEntropy(tokenId);
        provider.fulfill(requestId, keccak256("universal current entropy"));
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
        c = universalSale.previewExecution(e);
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
