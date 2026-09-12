// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../helpers/StreamCurrentSafeGovernanceFixture.sol";
import "../../smart-contracts/domains/mint/StreamNativeClearingSale.sol";
import "../../smart-contracts/domains/revenue/StreamPrimarySaleSettlement.sol";
import {
    StreamArtistSaleTypes as ClearingConsent
} from "../../smart-contracts/interfaces/stream/artist/StreamArtistSaleTypes.sol";

/// @notice Current Core/Manager/artist/recorder clearing composition with actual 2-of-3 Safes.
/// @dev External randomness uses the existing explicit provider double; this profile has zero reveal fee.
///      Functional integration does not satisfy the separately measured collector gas ceiling.
contract StreamCurrentClearingSaleTest is StreamCurrentSafeGovernanceFixture {
    bytes32 private constant CLEARING_PHASE = keccak256("current clearing phase");
    uint256[] private signingKeys;
    OfficialSafe private artistSafe;
    OfficialSafe private payerSafe;
    OfficialSafe private keeperSafe;
    StreamNativeClearingSale private clearing;
    StreamPrimarySaleSettlement private recorder;
    bytes32 private saleId;

    function setUp() public {
        signingKeys.push(0xC1EA01);
        signingKeys.push(0xC1EA03);
        uint256[] memory owners = new uint256[](3);
        owners[0] = 0xC1EA01;
        owners[1] = 0xC1EA02;
        owners[2] = 0xC1EA03;
        SafeComponents memory components = deploySafeComponents("1.4.1");
        artistSafe = createOfficialSafe(components, safeOwnerAddresses(owners), 2, 301);
        payerSafe = createOfficialSafe(components, safeOwnerAddresses(owners), 2, 302);
        keeperSafe = createOfficialSafe(components, safeOwnerAddresses(owners), 2, 303);
        OfficialSafe governor = createOfficialSafe(components, safeOwnerAddresses(owners), 2, 304);
        _deployCurrentStack(address(artistSafe), vm.addr(PLATFORM_KEY));
        _installGovernorSafe(governor, signingKeys);
        clearing.transferOwnership(address(governor));
        IStreamNativeClearingSale.ClearingSaleConfig memory config =
            IStreamNativeClearingSale.ClearingSaleConfig(
                1,
                CLEARING_PHASE,
                IStreamDutchPriceSchedule.DutchPriceSchedule(
                    1000, 200, uint64(block.timestamp), uint64(block.timestamp + 10 days), 0, 0, 0
                ),
                2,
                uint64(block.timestamp + 10 days),
                7 days,
                uint64(block.timestamp + 30 days),
                1,
                manager.phasePolicyHash(1, CLEARING_PHASE)
            );
        saleId = clearing.saleIdFor(1, CLEARING_PHASE, 1);
        _exec(
            governor, address(clearing), 0, abi.encodeCall(clearing.registerClearingSale, (config))
        );
        require(clearing.saleRecord(saleId).configHash != 0, "Safe registers exact clearing sale");
        require(
            payerSafe.getOwners().length == 3 && payerSafe.getThreshold() == 2,
            "actual 2-of-3 payer"
        );
        vm.deal(address(payerSafe), 1 ether);
    }

    function _artistProof(bytes32 digest) internal override returns (bytes memory) {
        return
            safeThresholdSignature(signingKeys, safeMessageDigest(artistSafe, abi.encode(digest)));
    }

    function _fixtureSaleConsentScope() internal pure override returns (uint8) {
        return 1;
    }

    function _deployAdditionalProducts() internal override {
        recorder =
            new StreamPrimarySaleSettlement(primaryResolver, address(registry), revenueEscrow);
        StreamNativeClearingSale.DeploymentConfig memory deployment;
        deployment.manager = manager;
        deployment.recorder = recorder;
        deployment.platform = vm.addr(PLATFORM_KEY);
        deployment.artists = IStreamArtistAttribution(address(artists));
        deployment.entropy = IStreamRevealFeeEscrow(address(entropy));
        deployment.roles = roles;
        deployment.authority = address(executor);
        // Composition budgets are explicit test inputs, not cold candidate measurements.
        deployment.parameters[0] = IStreamGasParameterHost.GasParameterConfig(
            "SALE_ERC1271_GAS_LIMIT", 1000000, 350000, 2
        );
        deployment.parameters[1] = IStreamGasParameterHost.GasParameterConfig(
            "SALE_ARTIST_AUTHORITY_GAS_LIMIT", 2000000, 50000, 2
        );
        deployment.parameters[2] = IStreamGasParameterHost.GasParameterConfig(
            "REVEAL_ATTEMPT_GAS_LIMIT", 4000000, 50000, 2
        );
        clearing = new StreamNativeClearingSale(deployment);
        _assertDeployableProductionInstance(address(recorder));
        _assertDeployableProductionInstance(address(clearing));
    }

    function _additionalEscrowProducers() internal view override returns (address[] memory rows) {
        rows = new address[](1);
        rows[0] = address(recorder);
    }

    function _configureAdditionalProducts() internal override {
        StreamModuleRegistration[] memory registrations = new StreamModuleRegistration[](1);
        registrations[0] = StreamModuleRegistration(
            address(clearing),
            keccak256("NATIVE_PRIMARY_SALE_ADAPTER"),
            keccak256("6529STREAM_UNIVERSAL_SETTLEMENT_V1"),
            type(IStreamNativeSaleBinding).interfaceId,
            500000,
            address(clearing).codehash,
            DEPLOYMENT_HASH,
            keccak256("current clearing module"),
            "urn:stream:current:clearing"
        );
        (GovernanceCall[] memory calls, bytes[] memory data) =
            StreamCurrentStackPlan.registrationCalls(registry, registrations);
        (bytes32 scope, bytes32 before_, bytes32 after_) = StreamGovernanceBootstrap.deriveBatchTransitionHashes(
            calls, StreamGovernanceBootstrap.governanceCallsHash(calls)
        );
        uint64 ready = uint64(block.timestamp + executor.minimumDelay(1));
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
                    GOVERNANCE_REASON,
                    "urn:stream:current:clearing-admission",
                    DEPLOYMENT_HASH
                )
            )
        );
        vm.warp(ready);
        executor.executeGovernanceBatch(abi.decode(scheduled, (bytes32)), calls, data);
        _configureMintPhase(CLEARING_PHASE, address(clearing));
    }

    function testCurrentSafeClearingMintRebatesAndBothOfficialSupplementsConserveValue() public {
        IStreamNativeClearingSale.ClearingPurchaseData memory firstData = _purchaseData(1);
        uint256 initialBalance = address(payerSafe).balance;
        vm.expectRevert(bytes("GS013"));
        this.purchaseAsSafe(firstData, 1200);
        require(
            core.totalSupply() == 0 && address(payerSafe).balance == initialBalance,
            "missing REQUIRED consent has no mint or payment"
        );
        require(
            clearing.nextPurchaseNonce(saleId, address(payerSafe)) == 1,
            "failed purchase preserves buyer nonce"
        );
        _consent();
        bytes32 first = _buy(firstData, 1200);
        require(
            recorder.totalOfficialSettled(address(0)) == 200 && wallet.balance == 200,
            "only first resting floor is official"
        );
        require(
            clearing.refundableBalance(saleId, address(payerSafe)) == 200,
            "excess claimable before clearing"
        );
        _claim();
        vm.warp(uint256(clearing.saleRecord(saleId).config.schedule.startTime) + 5 days);
        bytes32 second = _buy(_purchaseData(2), 600);
        _exec(keeperSafe, address(clearing), 0, abi.encodeCall(clearing.fixClearingPrice, (saleId)));
        require(
            clearing.financialSale(saleId).clearingPrice == 600
                && clearing.financialSale(saleId).scheduledSupplement == 800,
            "sold-out schedule fixes one global price"
        );
        require(
            clearing.refundableBalance(saleId, address(payerSafe)) == 400,
            "rebate includes both purchases before financial processing"
        );
        _claim();
        require(
            address(payerSafe).balance == initialBalance - 1200, "buyer paid two uniform prices"
        );
        require(
            clearing.totalBuyerLiabilities() == 800 && address(clearing).balance == 800,
            "only supplemental custody remains"
        );
        _settle(first);
        _settle(second);
        require(
            recorder.totalOfficialSettled(address(0)) == 1200 && wallet.balance == 1200,
            "actual split wallet received two exact full prices"
        );
        require(
            core.totalSupply() == 2 && core.ownerOf(1) == address(payerSafe)
                && core.ownerOf(2) == address(payerSafe),
            "supplements never mint another NFT"
        );
        require(
            clearing.totalBuyerLiabilities() == 0 && address(clearing).balance == 0,
            "no stranded custody"
        );
        _settle(first);
        require(
            wallet.balance == 1200 && core.collectionMintedEver(1) == 2,
            "settled purchase replay is read-only"
        );
        vm.expectRevert(bytes("GS013"));
        this.purchaseAsSafe(firstData, 1200);
        require(
            clearing.nextPurchaseNonce(saleId, address(payerSafe)) == 3,
            "purchase replay never rewinds nonce"
        );
    }

    function testCurrentSafePartialEscapeRefundsOnlyUnsettledSupplementAndKeepsNFTs() public {
        _consent();
        uint256 initialBalance = address(payerSafe).balance;
        bytes32 first = _buy(_purchaseData(1), 1000);
        vm.warp(uint256(clearing.saleRecord(saleId).config.schedule.startTime) + 5 days);
        bytes32 second = _buy(_purchaseData(2), 600);
        _exec(keeperSafe, address(clearing), 0, abi.encodeCall(clearing.fixClearingPrice, (saleId)));
        _claim();
        _settle(first);
        require(
            wallet.balance == 800 && recorder.totalOfficialSettled(address(0)) == 800,
            "both floors and one settled supplement"
        );
        vm.warp(uint256(clearing.saleRecord(saleId).config.absoluteEscapeDeadline) + 1);
        _exec(
            keeperSafe,
            address(clearing),
            0,
            abi.encodeCall(clearing.unlockRefunds, (saleId, uint8(0)))
        );
        require(
            clearing.refundableBalance(saleId, address(payerSafe)) == 400,
            "only unprocessed second supplement returns"
        );
        _claim();
        require(
            address(payerSafe).balance == initialBalance - 800,
            "buyer and official revenue conserve all funds"
        );
        require(
            clearing.totalBuyerLiabilities() == 0 && address(clearing).balance == 0,
            "terminal custody empty"
        );
        vm.expectRevert(bytes("GS013"));
        this.settleAsSafe(second);
        require(
            wallet.balance == 800 && core.totalSupply() == 2
                && core.ownerOf(1) == address(payerSafe) && core.ownerOf(2) == address(payerSafe),
            "escape never claws back official revenue or minted NFTs"
        );
    }

    function _consent() private {
        bytes32 configHash = clearing.saleRecord(saleId).configHash;
        ClearingConsent.Consent memory terms =
            ClearingConsent.Consent(1, address(clearing), saleId, configHash);
        T.Authorization memory authorization = T.Authorization(
            IStreamArtistAuthorizationRevocation(address(artists))
            .artistAuthorizationState(fixtureArtistId, bytes32(0), 0)
            .nextUnusedNonce,
            uint64(block.timestamp + 1 days),
            ""
        );
        _exec(
            artistSafe,
            address(artists),
            0,
            abi.encodeCall(IStreamArtistSaleAuthority.recordSaleConsent, (terms, authorization))
        );
        (bool accepted, bytes32 hash) = artists.isSaleConsented(1, saleId, configHash);
        require(
            accepted && artists.saleConsentRecord(hash).signer == address(artistSafe),
            "actual Safe operation16 sale consent"
        );
    }

    function _purchaseData(uint256 number)
        private
        returns (IStreamNativeClearingSale.ClearingPurchaseData memory d)
    {
        IStreamNativeClearingSale.ClearingSaleRecord memory sale_ = clearing.saleRecord(saleId);
        d.tokenData = abi.encode("actual current clearing artwork", number);
        d.authorization = IStreamNativeClearingSale.ClearingAuthorization(
            saleId,
            sale_.configHash,
            address(payerSafe),
            address(payerSafe),
            address(payerSafe),
            address(artistSafe),
            keccak256(d.tokenData),
            keccak256(abi.encode("current clearing mint", number)),
            clearing.nextPurchaseNonce(saleId, address(payerSafe)),
            number,
            bytes32(number),
            uint64(block.timestamp + 90 days),
            sale_.expectedPrimaryPolicyHash,
            1000,
            false,
            0,
            sale_.windowPolicyHash,
            sale_.config.closesAt + sale_.config.finalizationWindowSeconds,
            sale_.config.absoluteEscapeDeadline
        );
        bytes32 digest = clearing.authorizationDigest(d.authorization);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(PLATFORM_KEY, digest);
        d.platformSignature = abi.encodePacked(r, s, v);
        d.artistSignature =
            safeThresholdSignature(signingKeys, safeMessageDigest(artistSafe, abi.encode(digest)));
    }

    function _buy(IStreamNativeClearingSale.ClearingPurchaseData memory d, uint256 value)
        private
        returns (bytes32 id)
    {
        id = keccak256(
            abi.encode(
                keccak256("6529STREAM_SALE_PURCHASE_V1"),
                block.chainid,
                address(clearing),
                saleId,
                address(payerSafe),
                d.authorization.purchaseNonce
            )
        );
        this.purchaseAsSafe(d, value);
        IStreamNativeClearingSale.ClearingPurchaseRecord memory stored = clearing.purchaseRecord(id);
        require(
            stored.tokenId == d.authorization.executionNonce && stored.floorSettlementKey != 0
                && stored.originalFloor.operationId != 0,
            "exact purchase retains official floor and real mint operation"
        );
        require(core.ownerOf(stored.tokenId) == address(payerSafe), "actual Safe custody");
    }

    function _claim() private {
        _exec(
            payerSafe,
            address(clearing),
            0,
            abi.encodeCall(clearing.claimRefund, (saleId, address(payerSafe)))
        );
    }

    function _settle(bytes32 id) private {
        this.settleAsSafe(id);
    }

    function purchaseAsSafe(
        IStreamNativeClearingSale.ClearingPurchaseData calldata d,
        uint256 value
    ) external {
        require(msg.sender == address(this), "test only");
        _exec(payerSafe, address(clearing), value, abi.encodeCall(clearing.purchase, (d)));
    }

    function settleAsSafe(bytes32 id) external {
        require(msg.sender == address(this), "test only");
        _exec(
            keeperSafe,
            address(clearing),
            0,
            abi.encodeCall(clearing.settlePurchaseSupplement, (id))
        );
    }

    function _exec(OfficialSafe account, address target, uint256 value, bytes memory data) private {
        require(
            executeSafe(account, signingKeys, target, value, data, 0),
            "actual Safe executes Stream call"
        );
    }
}
