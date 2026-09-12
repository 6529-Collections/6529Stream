// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../helpers/StreamCurrentStackFixture.sol";
import "../helpers/OfficialSafeFixture.sol";
import "../../smart-contracts/domains/revenue/StreamPrimarySaleSettlement.sol";
import "../../smart-contracts/domains/mint/StreamNativeFixedPriceSaleAdapter.sol";

contract CurrentNativeRecipient is IERC721Receiver {
    error CurrentNativeRejected();
    bool public rejects = true;

    function accept() external {
        rejects = false;
    }

    function onERC721Received(address, address, uint256, bytes calldata)
        external
        view
        returns (bytes4)
    {
        if (rejects) revert CurrentNativeRejected();
        return IERC721Receiver.onERC721Received.selector;
    }
}

/// @notice Actual current native settlement, artist records, governance and threshold Safes.
/// @dev Only the external entropy service is a double. Positive user calls execute through
///      actual Safes; direct negative probes expose exact target revert data.
contract StreamCurrentNativeSettlementTest is StreamCurrentStackFixture, OfficialSafeFixture {
    bytes32 private constant NATIVE_PHASE = keccak256("current shared native phase");
    uint256 private constant PRICE = 1000;
    StreamPrimarySaleSettlement private recorder;
    StreamNativeFixedPriceSaleAdapter private nativeSale;
    OfficialSafe private artistSafe;
    OfficialSafe private payerSafe;
    uint256[] private keys;
    bytes32 private saleId;
    bytes32 private zeroProgram;
    bytes32 private pwywProgram;
    bytes32 private openProgram;
    bool private useTemplate;

    function setUp() public {
        keys.push(0x5AFE01);
        keys.push(0x5AFE02);
        SafeComponents memory components = deploySafeComponents("1.4.1");
        artistSafe = createOfficialSafe(components, safeOwnerAddresses(keys), 2, 101);
        payerSafe = createOfficialSafe(components, safeOwnerAddresses(keys), 2, 102);
        _deployCurrentStack(address(artistSafe), vm.addr(PLATFORM_KEY));
        vm.deal(address(payerSafe), 1 ether);
    }

    function _artistProof(bytes32 digest) internal override returns (bytes memory) {
        return safeThresholdSignature(keys, safeMessageDigest(artistSafe, abi.encode(digest)));
    }

    function _deployAdditionalProducts() internal override {
        recorder =
            new StreamPrimarySaleSettlement(primaryResolver, address(registry), revenueEscrow);
        nativeSale = new StreamNativeFixedPriceSaleAdapter(
            manager, recorder, vm.addr(PLATFORM_KEY), IStreamArtistAttribution(address(artists))
        );
        _assertDeployableProductionInstance(address(recorder));
        _assertDeployableProductionInstance(address(nativeSale));
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
        rows = new GovernanceActionPolicyEntry[](5);
        rows[0] = _nativePolicy(nativeSale.registerSale.selector);
        rows[1] = _nativePolicy(nativeSale.cancelSale.selector);
        rows[2] = _nativePolicy(nativeSale.setPaused.selector);
        rows[3] = _nativePolicy(nativeSale.registerPriceProgram.selector);
        rows[4] = _nativePolicy(nativeSale.closePriceProgram.selector);
    }

    function _nativePolicy(bytes4 selector)
        private
        view
        returns (GovernanceActionPolicyEntry memory)
    {
        return GovernanceActionPolicyEntry(
            1,
            address(nativeSale),
            selector,
            address(nativeSale).codehash,
            keccak256(abi.encode(DEPLOYMENT_HASH, address(nativeSale))),
            1,
            0,
            0,
            bytes32(0)
        );
    }

    function _prepareArtistOnboarding() internal override {
        if (!useTemplate) return;
        bytes32 templateId = _createArtistTemplate();
        bytes memory data = abi.encodeCall(
            primaryResolver.setPrimaryTemplateAssignment,
            (PRIMARY_REVENUE_CLASS, uint8(1), uint256(1), templateId, bytes32(0))
        );
        GovernanceActionRequest memory request = _request(address(primaryResolver), data);
        bytes memory scheduled = governanceRoot.execute(
            address(executor), 0, abi.encodeCall(executor.scheduleGovernanceAction, (request))
        );
        vm.warp(request.notBefore);
        executor.executeGovernanceAction(abi.decode(scheduled, (bytes32)), data);
    }

    function _configureAdditionalProducts() internal override {
        StreamModuleRegistration[] memory records = new StreamModuleRegistration[](1);
        records[0] = StreamModuleRegistration(
            address(nativeSale),
            keccak256("NATIVE_PRIMARY_SALE_ADAPTER"),
            keccak256("6529STREAM_UNIVERSAL_SETTLEMENT_V1"),
            type(IStreamNativeSaleBinding).interfaceId,
            500_000,
            address(nativeSale).codehash,
            DEPLOYMENT_HASH,
            keccak256("native current module"),
            "urn:6529stream:fixture:native"
        );
        (GovernanceCall[] memory calls, bytes[] memory data) =
            StreamCurrentStackPlan.registrationCalls(registry, records);
        (bytes32 scope, bytes32 before_, bytes32 after_) = StreamGovernanceBootstrap.deriveBatchTransitionHashes(
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
                    before_,
                    after_,
                    ready,
                    uint64(ready + 7 days),
                    keccak256("native admission"),
                    "urn:6529stream:fixture:native-admission",
                    DEPLOYMENT_HASH
                )
            )
        );
        vm.warp(ready);
        executor.executeGovernanceBatch(abi.decode(scheduled, (bytes32)), calls, data);
        _configureMintPhase(NATIVE_PHASE, address(nativeSale));
        saleId = nativeSale.registerSale(
            IStreamNativeFixedPriceSaleAdapter.SaleConfig(
                1,
                NATIVE_PHASE,
                PRICE,
                0,
                uint64(block.timestamp + 30 days),
                manager.phasePolicyHash(1, NATIVE_PHASE),
                primaryResolver.resolvePrimaryAssignment(1, 0, PRIMARY_REVENUE_CLASS).assignmentHash
            )
        );
        (, profile, wallet) = sale.primaryPolicy(1);
        zeroProgram = _registerProgram(12, 0, 0, 3);
        pwywProgram = _registerProgram(13, 100, 3000, 3);
        openProgram = _registerProgram(1, PRICE, PRICE, 0);
        nativeSale.transferOwnership(address(executor));
    }

    function _registerProgram(uint8 kind, uint256 minimum, uint256 maximum, uint64 limit)
        private
        returns (bytes32)
    {
        return nativeSale.registerPriceProgram(
            IStreamNativePricePrograms.PriceProgramConfig(
                1,
                NATIVE_PHASE,
                kind,
                minimum,
                maximum,
                limit,
                0,
                uint64(block.timestamp + 30 days),
                1,
                manager.phasePolicyHash(1, NATIVE_PHASE),
                kind == 12
                    ? bytes32(0)
                    : primaryResolver.resolvePrimaryAssignment(1, 0, PRIMARY_REVENUE_CLASS)
                    .assignmentHash
            )
        );
    }

    function testSafeZeroPriceProgramMintsWithoutOfficialRevenueAndCannotReplay() public {
        IStreamNativePricePrograms.PriceProgramExecution memory e =
            _programExecution(zeroProgram, 41, 0, 0);
        IStreamNativePricePrograms.PriceProgramResult memory expected =
            nativeSale.previewPriceProgram(e);
        bytes memory data = abi.encodeCall(nativeSale.executePriceProgram, (e));
        uint256 balance = address(payerSafe).balance;
        uint256 profiles = factory.profileCount();
        require(
            executeSafe(payerSafe, keys, address(nativeSale), 0, data, 0), "Safe zero-price mint"
        );
        require(
            core.ownerOf(core.lastAllocatedTokenId()) == address(payerSafe)
                && core.totalSupply() == 1 && manager.isOperationRootUsed(expected.operationRoot)
                && manager.isAuthorizationUsed(_programAuthorizationId(e)),
            "actual zero-price mint authorization"
        );
        require(
            nativeSale.priceProgramRecord(zeroProgram).mintedQuantity == 1
                && nativeSale.executionStatus(expected.executionId) == 2,
            "zero execution finalized"
        );
        require(
            address(payerSafe).balance == balance && wallet.balance == 0
                && recorder.totalOfficialSettled(address(0)) == 0
                && revenueEscrow.totalOwed(address(0)) == 0 && factory.profileCount() == profiles
                && !recorder.settlementConsumed(
                    recorder.settlementKey(address(nativeSale), expected.executionId)
                ),
            "zero has no payment/profile/official record"
        );
        vm.prank(address(payerSafe));
        (bool ok, bytes memory failure) = address(nativeSale).call(data);
        require(
            !ok
                && keccak256(failure)
                    == keccak256(
                        abi.encodeWithSelector(
                            IStreamNativeFixedPriceSaleAdapter.NativeAuthorizationUsed.selector,
                            address(artistSafe),
                            e.authorization.nonce
                        )
                    ),
            "zero exact replay rejection"
        );
        require(
            core.totalSupply() == 1 && manager.nextOperationNonce() == 1,
            "zero replay cannot mint again"
        );
    }

    function testSafePayWhatYouWantSettlesChosenPriceAndOpenEditionSharesActualMintLedger() public {
        IStreamNativePricePrograms.PriceProgramExecution memory e =
            _programExecution(pwywProgram, 42, 2000, 500);
        IStreamNativePricePrograms.PriceProgramResult memory expected =
            nativeSale.previewPriceProgram(e);
        uint256 balance = address(payerSafe).balance;
        require(
            executeSafe(
                payerSafe,
                keys,
                address(nativeSale),
                2000,
                abi.encodeCall(nativeSale.executePriceProgram, (e)),
                0
            ),
            "Safe chooses price above signed minimum"
        );
        StreamPrimarySettlementTypes.PrimarySettlementResult memory paid = recorder.settlementResult(
            recorder.settlementKey(address(nativeSale), expected.executionId)
        );
        require(
            paid.amount == 2000 && paid.wallet == wallet && wallet.balance == 2000
                && address(payerSafe).balance == balance - 2000
                && manager.isAuthorizationUsed(_programAuthorizationId(e)),
            "full chosen amount is official revenue"
        );
        e = _programExecution(openProgram, 43, PRICE, PRICE);
        require(
            executeSafe(
                payerSafe,
                keys,
                address(nativeSale),
                PRICE,
                abi.encodeCall(nativeSale.executePriceProgram, (e)),
                0
            ),
            "Safe open-edition purchase"
        );
        require(
            core.totalSupply() == 2 && core.collectionMintedEver(1) == 2
                && manager.nextOperationNonce() == 2
                && recorder.totalOfficialSettled(address(0)) == 3000 && wallet.balance == 3000,
            "price kinds share actual mint and money accounting"
        );
        require(
            nativeSale.priceProgramRecord(openProgram).config.maxSaleQuantity == 0
                && nativeSale.priceProgramRecord(openProgram).mintedQuantity == 1,
            "open edition has no adapter cap"
        );
        require(
            executeSafe(
                artistSafe,
                keys,
                wallet,
                0,
                abi.encodeCall(
                    IStreamSplitWallet.release,
                    (address(0), address(artistSafe), payable(address(artistSafe)))
                ),
                0
            ),
            "Safe claims both sale formats"
        );
        require(
            address(artistSafe).balance == 2700 && wallet.balance == 300,
            "actual artist shares across programs"
        );
    }

    function _programExecution(bytes32 id, uint256 nonce, uint256 chosen, uint256 signedPrice)
        private
        returns (IStreamNativePricePrograms.PriceProgramExecution memory e)
    {
        e.chosenUnitPrice = chosen;
        e.tokenData = TOKEN_DATA;
        e.authorization = IStreamNativePricePrograms.PriceProgramAuthorization(
            id,
            nativeSale.priceProgramRecord(id).configHash,
            address(payerSafe),
            address(payerSafe),
            address(payerSafe),
            address(artistSafe),
            keccak256(TOKEN_DATA),
            keccak256(abi.encode("current price program", nonce)),
            nonce,
            bytes32(nonce),
            uint64(block.timestamp + 1 days),
            id == zeroProgram ? bytes32(0) : _nativePrimaryPolicyHash(),
            signedPrice
        );
        bytes32 digest = nativeSale.priceProgramAuthorizationDigest(e.authorization);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(PLATFORM_KEY, digest);
        e.platformSignature = abi.encodePacked(r, s, v);
        e.artistSignature = _artistProof(digest);
    }

    function _programAuthorizationId(IStreamNativePricePrograms.PriceProgramExecution memory e)
        private
        view
        returns (bytes32)
    {
        return keccak256(
            abi.encode(
                keccak256("6529STREAM_MINT_TICKET_AUTHORIZATION_V1"),
                nativeSale.priceProgramAuthorizationDigest(e.authorization)
            )
        );
    }

    function testSafeNativePurchaseMintsRevealsClaimsAndRejectsReplay() public {
        (
            IStreamNativeFixedPriceSaleAdapter.SaleExecutionData memory e,
            StreamNativeSettlementTypes.NativeSettlementCandidate memory c
        ) = _execution(1, address(payerSafe));
        bytes memory data = abi.encodeCall(nativeSale.purchase, (e));
        uint256 before_ = address(payerSafe).balance;
        require(
            executeSafe(payerSafe, keys, address(nativeSale), PRICE, data, 0), "real Safe purchase"
        );
        _settled(c, address(payerSafe), before_);
        uint256 tokenId = core.lastAllocatedTokenId();
        (, uint256 requestId) = entropy.requestEntropy(tokenId);
        provider.fulfill(requestId, keccak256("current native entropy"));
        (, bool finalized) = entropy.tokenSeed(tokenId);
        require(finalized && bytes(core.tokenURI(tokenId)).length != 0, "real native reveal");
        _claim();
        vm.prank(address(payerSafe));
        (bool ok, bytes memory failure) = address(nativeSale).call{ value: PRICE }(data);
        require(
            !ok
                && keccak256(failure)
                    == keccak256(
                        abi.encodeWithSelector(
                            IStreamNativeFixedPriceSaleAdapter.NativeAuthorizationUsed.selector,
                            address(artistSafe),
                            e.authorization.nonce
                        )
                    ),
            "exact native commercial replay rejection"
        );
        require(
            core.totalSupply() == 1 && recorder.totalOfficialSettled(address(0)) == PRICE,
            "native replay leaves lifetime totals"
        );
    }

    function testActualArtistTemplateDefersWalletThenSafeFlushesAndClaims() public {
        useTemplate = true;
        _deployCurrentStack(address(artistSafe), vm.addr(PLATFORM_KEY));
        require(
            wallet.code.length == 0 && !factory.profileExists(profile),
            "undeployed template destination"
        );
        (
            IStreamNativeFixedPriceSaleAdapter.SaleExecutionData memory e,
            StreamNativeSettlementTypes.NativeSettlementCandidate memory c
        ) = _execution(2, address(payerSafe));
        uint256 before_ = address(payerSafe).balance;
        require(
            executeSafe(
                payerSafe,
                keys,
                address(nativeSale),
                PRICE,
                abi.encodeCall(nativeSale.purchase, (e)),
                0
            ),
            "Safe template purchase"
        );
        _settled(c, address(payerSafe), before_);
        require(
            factory.profileExists(profile) && wallet.code.length == 0
                && revenueEscrow.escrowOwed(PRIMARY_REVENUE_CLASS, profile, wallet, address(0))
                    == PRICE,
            "official empty-wallet destination retained in escrow"
        );
        require(
            executeSafe(
                payerSafe,
                keys,
                address(factory),
                0,
                abi.encodeCall(factory.deployWallet, (profile)),
                0
            ),
            "Safe deploys wallet"
        );
        require(
            executeSafe(
                payerSafe,
                keys,
                address(revenueEscrow),
                0,
                abi.encodeCall(
                    revenueEscrow.flushToVerifiedWalletBestEffort,
                    (PRIMARY_REVENUE_CLASS, profile, wallet, address(0))
                ),
                0
            ),
            "Safe flushes native escrow"
        );
        require(
            wallet.balance == PRICE && revenueEscrow.totalOwed(address(0)) == 0,
            "single exact flush"
        );
        _claim();
    }

    function testLateNativeRecipientRejectionRollsBackAndIdenticalSafeCallRetries() public {
        CurrentNativeRecipient recipient = new CurrentNativeRecipient();
        (
            IStreamNativeFixedPriceSaleAdapter.SaleExecutionData memory e,
            StreamNativeSettlementTypes.NativeSettlementCandidate memory c
        ) = _execution(3, address(recipient));
        bytes memory data = abi.encodeCall(nativeSale.purchase, (e));
        uint256 before_ = address(payerSafe).balance;
        vm.prank(address(payerSafe));
        (bool ok, bytes memory failure) = address(nativeSale).call{ value: PRICE }(data);
        require(
            !ok
                && keccak256(failure)
                    == keccak256(
                        abi.encodeWithSelector(
                            CurrentNativeRecipient.CurrentNativeRejected.selector
                        )
                    ),
            "actual late recipient rejection"
        );
        require(
            core.totalSupply() == 0 && core.collectionMintedEver(1) == 0
                && manager.nextOperationNonce() == 0
                && !manager.isOperationRootUsed(c.operationIdentityCommitment)
                && !manager.isAuthorizationUsed(_authorizationId(c)),
            "all actual mint state rolled back"
        );
        require(
            !nativeSale.authorizationUsed(address(artistSafe), e.authorization.nonce)
                && nativeSale.executionIdByNonce(saleId, e.authorization.executionNonce) == 0
                && nativeSale.executionStatus(c.executionBinding.executionId) == 0
                && !recorder.settlementConsumed(
                    recorder.settlementKey(address(nativeSale), c.executionBinding.executionId)
                ),
            "all native replay state rolled back"
        );
        require(
            address(payerSafe).balance == before_ && wallet.balance == 0
                && address(nativeSale).balance == 0 && address(recorder).balance == 0
                && revenueEscrow.totalOwed(address(0)) == 0
                && recorder.totalOfficialSettled(address(0)) == 0,
            "all native money rolled back"
        );
        recipient.accept();
        require(
            executeSafe(payerSafe, keys, address(nativeSale), PRICE, data, 0),
            "identical native call succeeds through actual Safe"
        );
        _settled(c, address(recipient), before_);
    }

    function _execution(uint256 nonce, address recipient)
        private
        returns (
            IStreamNativeFixedPriceSaleAdapter.SaleExecutionData memory e,
            StreamNativeSettlementTypes.NativeSettlementCandidate memory c
        )
    {
        e.tokenData = TOKEN_DATA;
        e.authorization = IStreamNativeFixedPriceSaleAdapter.SaleAuthorization(
            saleId,
            nativeSale.saleRecord(saleId).configHash,
            address(payerSafe),
            address(payerSafe),
            recipient,
            address(artistSafe),
            keccak256(e.tokenData),
            keccak256(abi.encode("native mint", nonce)),
            nonce,
            bytes32(nonce),
            uint64(block.timestamp + 1 days),
            _nativePrimaryPolicyHash()
        );
        bytes32 digest = nativeSale.authorizationDigest(e.authorization);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(PLATFORM_KEY, digest);
        e.platformSignature = abi.encodePacked(r, s, v);
        e.artistSignature = _artistProof(digest);
        c = nativeSale.previewExecution(e);
    }

    function _settled(
        StreamNativeSettlementTypes.NativeSettlementCandidate memory c,
        address recipient,
        uint256 before_
    ) private view {
        bytes32 key = recorder.settlementKey(address(nativeSale), c.executionBinding.executionId);
        StreamPrimarySettlementTypes.PrimarySettlementResult memory result =
            recorder.settlementResult(key);
        require(
            core.ownerOf(core.lastAllocatedTokenId()) == recipient && core.totalSupply() == 1,
            "actual native Core custody"
        );
        require(
            manager.isOperationRootUsed(c.operationIdentityCommitment)
                && manager.nextOperationNonce() == 1
                && manager.isAuthorizationUsed(_authorizationId(c)),
            "actual native mint transcript"
        );
        require(
            recorder.settlementConsumed(key) && result.amount == PRICE && result.wallet == wallet
                && result.operationIdentityCommitment == c.operationIdentityCommitment
                && recorder.officialSettled(PRIMARY_REVENUE_CLASS, profile, wallet, address(0))
                    == PRICE && recorder.totalOfficialSettled(address(0)) == PRICE,
            "official native settlement"
        );
        require(
            nativeSale.executionStatus(c.executionBinding.executionId) == 2
                && nativeSale.executionIdByNonce(saleId, c.executionBinding.executionNonce)
                    == c.executionBinding.executionId,
            "native execution completed once"
        );
        require(
            address(payerSafe).balance == before_ - PRICE && address(nativeSale).balance == 0
                && address(recorder).balance == 0,
            "single native payment without adapter custody"
        );
    }

    function _claim() private {
        require(
            executeSafe(
                artistSafe,
                keys,
                wallet,
                0,
                abi.encodeCall(
                    IStreamSplitWallet.release,
                    (address(0), address(artistSafe), payable(address(artistSafe)))
                ),
                0
            ),
            "Safe claims native share"
        );
        IStreamSplitWallet(wallet).release(address(0), PROTOCOL, payable(PROTOCOL));
        require(
            address(artistSafe).balance == 900 && PROTOCOL.balance == 100 && wallet.balance == 0,
            "actual native 90/10 withdrawals"
        );
    }

    function _createArtistTemplate() private returns (bytes32 templateId) {
        IStreamRevenueResolver.PrimaryTemplateEntry[] memory entries =
            new IStreamRevenueResolver.PrimaryTemplateEntry[](2);
        entries[0] = IStreamRevenueResolver.PrimaryTemplateEntry(
            address(0), keccak256("COLLECTION_ARTIST"), 900_000, keccak256("artist")
        );
        entries[1] = IStreamRevenueResolver.PrimaryTemplateEntry(
            PROTOCOL, bytes32(0), 100_000, keccak256("protocol")
        );
        bytes memory data = abi.encodeCall(
            primaryResolver.createPrimaryTemplate, (entries, keccak256("Safe artist template"))
        );
        GovernanceActionRequest memory request = _request(address(primaryResolver), data);
        bytes memory result = governanceRoot.execute(
            address(executor), 0, abi.encodeCall(executor.scheduleGovernanceAction, (request))
        );
        vm.warp(request.notBefore);
        vm.recordLogs();
        executor.executeGovernanceAction(abi.decode(result, (bytes32)), data);
        Vm.Log[] memory logs = vm.getRecordedLogs();
        bytes32 topic = keccak256("PrimaryTemplateCreated(bytes32,bytes32,bytes32,uint16,uint16)");
        for (uint256 i; i < logs.length; ++i) {
            if (
                logs[i].emitter == address(primaryResolver) && logs[i].topics.length == 4
                    && logs[i].topics[0] == topic
            ) {
                require(templateId == 0, "one template created");
                templateId = logs[i].topics[1];
            }
        }
        require(templateId != 0, "governed template creation observed");
    }

    function _request(address target, bytes memory data)
        private
        view
        returns (GovernanceActionRequest memory)
    {
        bytes4 selector;
        assembly ("memory-safe") { selector := mload(add(data, 32)) }
        return GovernanceActionRequest(
            1,
            target,
            0,
            selector,
            data,
            bytes32(0),
            bytes32(0),
            bytes32(0),
            uint64(block.timestamp + 48 hours),
            uint64(block.timestamp + 9 days),
            keccak256("Safe governance test"),
            "urn:6529stream:fixture:safe-governance",
            DEPLOYMENT_HASH
        );
    }

    function _authorizationId(StreamNativeSettlementTypes.NativeSettlementCandidate memory c)
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
