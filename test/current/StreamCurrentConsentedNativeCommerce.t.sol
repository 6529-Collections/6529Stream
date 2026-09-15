// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../helpers/StreamCurrentStackFixture.sol";
import "../helpers/OfficialSafeFixture.sol";
import {
    StreamNativeCommerceDeployment,
    StreamNativeEnglishAuction,
    StreamPrimarySaleSettlement,
    IStreamNativeEnglishAuction,
    StreamPreparedNativeRightsProjection,
    StreamPreparedNativeRightsTypes,
    StreamSaleTemplate,
    StreamEnglishAuctionClock
} from "../../script/current/StreamNativeCommerceDeployment.sol";
import {
    IStreamArtistTemplateEconomicsAuthority
} from "../../smart-contracts/interfaces/stream/artist/IStreamArtistTemplateEconomicsAuthority.sol";
import {
    IStreamArtistPrimaryTemplateConsentFacts
} from "../../smart-contracts/interfaces/stream/artist/IStreamArtistPrimaryTemplateConsentFacts.sol";

interface CurrentCommerceCallVm {
    function expectCall(address target, uint256 value, bytes calldata data, uint64 count) external;
}

/// @notice Artist consent, delayed governance, Safe auction payment and withdrawals on one current graph.
/// @dev Only the external entropy service is a double. These aggregate workflows do not
/// establish individual cold transaction capacity or acceptance of other rights profiles.
contract StreamCurrentConsentedNativeCommerceTest is
    StreamCurrentStackFixture,
    OfficialSafeFixture
{
    bytes32 private constant COMMERCE_PHASE = keccak256("actual consented native commerce");
    uint96 private constant PRICE = 1_000_000;
    StreamNativeCommerceDeployment.Products private commerce;
    StreamPrimarySaleSettlement private recorder;
    StreamNativeEnglishAuction private house;
    OfficialSafe private artistSafe;
    OfficialSafe private payerSafe;
    uint256[] private keys;
    StreamSaleTemplate.Selection private selected;

    function setUp() public {
        keys.push(0x5AFE01);
        keys.push(0x5AFE02);
        SafeComponents memory components = deploySafeComponents("1.4.1");
        artistSafe = createOfficialSafe(components, safeOwnerAddresses(keys), 2, 301);
        payerSafe = createOfficialSafe(components, safeOwnerAddresses(keys), 2, 302);
        _deployCurrentStack(address(artistSafe), vm.addr(PLATFORM_KEY));
        vm.deal(address(payerSafe), 1 ether);
    }

    function _artistProof(bytes32 digest) internal override returns (bytes memory) {
        return safeThresholdSignature(keys, safeMessageDigest(artistSafe, abi.encode(digest)));
    }

    function _configureInitialRevealPolicy() internal override {
        entropy.configureCollectionRevealPolicy(
            1, 1, keccak256("ROLE_ENTROPY_REVEAL_OWNER"), 100, 100
        );
    }

    function _deployAdditionalProducts() internal override {
        StreamNativeEnglishAuction.DeploymentConfig memory d;
        d.manager = manager;
        d.platform = vm.addr(PLATFORM_KEY);
        d.artists = IStreamArtistAttribution(address(artists));
        d.entropy = IStreamRevealFeeEscrow(address(entropy));
        d.roles = roles;
        d.authority = address(executor);
        d.parameters[0] = IStreamGasParameterHost.GasParameterConfig(
            "SALE_ERC1271_GAS_LIMIT", 400_000, 350_000, 2
        );
        d.parameters[1] = IStreamGasParameterHost.GasParameterConfig(
            "SALE_ARTIST_AUTHORITY_GAS_LIMIT", 300_000, 50_000, 2
        );
        d.parameters[2] = IStreamGasParameterHost.GasParameterConfig(
            "REVEAL_ATTEMPT_GAS_LIMIT", 200_000, 50_000, 2
        );
        d.parameters[3] = IStreamGasParameterHost.GasParameterConfig(
            "SALE_NFT_DELIVERY_GAS_LIMIT", 300_000, 100_000, 2
        );
        commerce = StreamNativeCommerceDeployment.deploy(
            primaryResolver,
            registry,
            revenueEscrow,
            d,
            DEPLOYMENT_HASH,
            keccak256("actual native commerce modules")
        );
        recorder = commerce.recorder;
        house = commerce.house;
        _assertDeployableProductionInstance(address(recorder));
        _assertDeployableProductionInstance(address(house));
    }

    function _additionalOperatingPolicies()
        internal
        view
        override
        returns (GovernanceActionPolicyEntry[] memory rows)
    {
        GovernanceActionPolicyEntry[] memory intents =
            StreamNativeCommerceDeployment.policies(commerce);
        rows = new GovernanceActionPolicyEntry[](2);
        uint256 n;
        for (uint256 i; i < intents.length; ++i) {
            if (intents[i].target == address(manager) || intents[i].target == address(house)) {
                rows[n++] = intents[i];
            }
        }
        require(n == rows.length, "only new Manager and house catalog rows");
    }

    function _configureAdditionalProducts() internal override {
        this.admitCommerce();
        (address target, bytes memory data) =
            StreamNativeCommerceDeployment.managerBinding(commerce);
        (bool ok,) = target.call(data);
        require(ok, "original temporary Manager owner binds exact admitted recorder");
        this.configureCommercePhase();
    }

    function configureCommercePhase() external {
        _configureMintPhase(COMMERCE_PHASE, address(house));
    }

    function admitCommerce() external {
        GenesisBatch memory batch = StreamNativeCommerceDeployment.admission(commerce);
        (bytes32 scope, bytes32 oldHash, bytes32 newHash) = StreamGovernanceBootstrap.deriveBatchTransitionHashes(
            batch.calls, StreamGovernanceBootstrap.governanceCallsHash(batch.calls)
        );
        uint64 ready = uint64(block.timestamp + 48 hours);
        executor.publishGovernanceCallData(batch.callDatas);
        bytes memory scheduled = governanceRoot.execute(
            address(executor),
            0,
            abi.encodeCall(
                executor.scheduleGovernanceBatch,
                (
                    uint8(1),
                    batch.calls,
                    scope,
                    oldHash,
                    newHash,
                    ready,
                    uint64(ready + 7 days),
                    keccak256("actual commerce admission"),
                    "urn:6529stream:fixture:consented-commerce",
                    DEPLOYMENT_HASH
                )
            )
        );
        vm.warp(ready);
        executor.executeGovernanceBatch(
            abi.decode(scheduled, (bytes32)), batch.calls, batch.callDatas
        );
    }

    function testActualArtistConsentRepairsSameGovernanceActionThenSafeAuctionPaysAndReveals()
        public
    {
        bytes32 templateId = this.createArtistTemplate();
        bytes32 beforeAssignment =
            primaryResolver.resolvePrimaryAssignment(1, 0, PRIMARY_REVENUE_CLASS).assignmentHash;
        (bytes32 actionId, uint64 ready, bytes memory data) =
            this.scheduleTemplateAssignment(templateId);
        vm.warp(ready);
        bytes memory originalCall =
            abi.encodeCall(executor.executeGovernanceAction, (actionId, data));
        (bool missingConsent,) = address(executor).call(originalCall);
        require(!missingConsent, "actual bound Artist rejects unconsented low-share assignment");
        require(
            primaryResolver.resolvePrimaryAssignment(1, 0, PRIMARY_REVENUE_CLASS).assignmentHash
                == beforeAssignment,
            "failed governance preserves original assignment"
        );
        this.approveArtistTemplate(templateId);
        (bool repaired,) = address(executor).call(originalCall);
        require(repaired, "identical scheduled assignment succeeds after actual Safe op15");
        this.captureSelection(templateId);
        bytes32 id = this.createCommerceAuction();
        _bid(id);
        (uint64 end,,,) = house.auctionDeadlines(id);
        vm.warp(end);
        require(
            executeSafe(payerSafe, keys, address(house), 0, abi.encodeCall(house.settle, (id)), 0),
            "actual Safe settles actual Artist-authorized mint"
        );
        _assertSettlementAndWithdraw(id);
        uint256 tokenId = house.auction(id).tokenId;
        (, uint256 requestId) = entropy.requestEntropy(tokenId);
        provider.fulfill(requestId, keccak256("joined consented auction entropy"));
        (, bool finalized) = entropy.tokenSeed(tokenId);
        require(
            finalized && bytes(core.tokenURI(tokenId)).length != 0,
            "actual coordinator and metadata complete"
        );
    }

    function testActualCommerceEscrowFailureRollsBackMintAndIdenticalSignedSafeRetryPays() public {
        bytes32 templateId = this.createArtistTemplate();
        this.approveArtistTemplate(templateId);
        (bytes32 actionId, uint64 ready, bytes memory data) =
            this.scheduleTemplateAssignment(templateId);
        vm.warp(ready);
        executor.executeGovernanceAction(actionId, data);
        this.captureSelection(templateId);
        bytes32 id = this.createCommerceAuction();
        _bid(id);
        this.setRecorderAdmission(false);
        uint256 nonce = payerSafe.nonce();
        bytes memory settleData = abi.encodeCall(house.settle, (id));
        bytes32 digest = payerSafe.getTransactionHash(
            address(house), 0, settleData, 0, 0, 0, 0, address(0), address(0), nonce
        );
        bytes memory originalCall = abi.encodeCall(
            payerSafe.execTransaction,
            (
                address(house),
                0,
                settleData,
                uint8(0),
                0,
                0,
                0,
                address(0),
                payable(address(0)),
                safeThresholdSignature(keys, digest)
            )
        );
        require(
            !factory.profileExists(selected.profileId),
            "template profile absent before failed settlement"
        );
        CurrentCommerceCallVm(address(vm))
            .expectCall(
                address(revenueEscrow),
                PRICE,
                abi.encodeCall(
                    revenueEscrow.creditNative,
                    (PRIMARY_REVENUE_CLASS, selected.profileId, selected.wallet, true)
                ),
                2
            );
        (bool failed,) = address(payerSafe).call(originalCall);
        require(
            !failed && payerSafe.nonce() == nonce && house.auction(id).status == 1,
            "failed actual Safe preserves nonce and live auction"
        );
        require(
            core.totalSupply() == 0 && core.lastAllocatedTokenId() == 0
                && core.pendingPreparedMintTokenId() == 0 && core.collectionNextSerial(1) == 1
                && manager.nextOperationNonce() == 0,
            "entire actual prepared mint rolls back"
        );
        require(
            recorder.totalOfficialSettled(address(0)) == 0
                && revenueEscrow.totalOwed(address(0)) == 0 && address(revenueEscrow).balance == 0
                && selected.wallet.code.length == 0 && !factory.profileExists(selected.profileId),
            "no official revenue or materialized wallet survives failure"
        );
        require(
            house.totalBuyerLiabilities() == PRICE + 100 && address(house).balance == PRICE + 100,
            "winning deposit remains held exactly"
        );
        this.setRecorderAdmission(true);
        (bool repaired, bytes memory result) = address(payerSafe).call(originalCall);
        require(
            repaired && abi.decode(result, (bool)) && payerSafe.nonce() == nonce + 1,
            "identical signed Safe transaction succeeds after actual governed repair"
        );
        _assertSettlementAndWithdraw(id);
    }

    function createArtistTemplate() external returns (bytes32 templateId) {
        IStreamRevenueResolver.PrimaryTemplateEntry[] memory entries =
            new IStreamRevenueResolver.PrimaryTemplateEntry[](2);
        entries[0] = IStreamRevenueResolver.PrimaryTemplateEntry(
            address(0), keccak256("COLLECTION_ARTIST"), 100_000, keccak256("artist")
        );
        entries[1] = IStreamRevenueResolver.PrimaryTemplateEntry(
            PROTOCOL, 0, 900_000, keccak256("protocol")
        );
        bytes memory data = abi.encodeCall(
            primaryResolver.createPrimaryTemplate,
            (entries, keccak256("explicit Safe artist consent"))
        );
        (bytes32 actionId, uint64 ready) = _schedule(address(primaryResolver), data, 0, 0, 0);
        vm.warp(ready);
        vm.recordLogs();
        executor.executeGovernanceAction(actionId, data);
        Vm.Log[] memory logs = vm.getRecordedLogs();
        bytes32 topic = keccak256("PrimaryTemplateCreated(bytes32,bytes32,bytes32,uint16,uint16)");
        for (uint256 i; i < logs.length; ++i) {
            if (
                logs[i].emitter == address(primaryResolver) && logs[i].topics.length == 4
                    && logs[i].topics[0] == topic
            ) {
                require(templateId == 0, "one canonical template event");
                templateId = logs[i].topics[1];
            }
        }
        require(templateId != 0, "actual governed template creation");
    }

    function approveArtistTemplate(bytes32 templateId) external {
        T.AssignmentFact memory fact = IStreamArtistPrimaryTemplateConsentFacts(
                address(primaryResolver)
            ).previewArtistPrimaryTemplateConsentAssignment(1, templateId, 0, false);
        T.EconomicsConsent memory p = T.EconomicsConsent(
            1, address(primaryResolver), PRIMARY_REVENUE_CLASS, 1, 1, fact.assignmentHash
        );
        T.Authorization memory a = _artistAuthorization(false);
        a.signature = _artistProof(artists.economicsConsentDigest(p, a));
        require(
            executeSafe(
                artistSafe,
                keys,
                address(artists),
                0,
                abi.encodeCall(
                    IStreamArtistTemplateEconomicsAuthority.recordProspectiveTemplateEconomicsConsent,
                    (p, templateId, a)
                ),
                0
            ),
            "actual Artist Safe executes original op15 consent"
        );
    }

    function scheduleTemplateAssignment(bytes32 templateId)
        external
        returns (bytes32 actionId, uint64 ready, bytes memory data)
    {
        data = abi.encodeCall(
            primaryResolver.setPrimaryTemplateAssignment,
            (PRIMARY_REVENUE_CLASS, uint8(1), uint256(1), templateId, bytes32(0))
        );
        (actionId, ready) = _schedule(address(primaryResolver), data, 0, 0, 0);
    }

    function captureSelection(bytes32 templateId) external {
        selected =
            StreamPreparedNativeRightsProjection.collectionTemplateForMode(primaryResolver, 1, 2);
        T.AssignmentFact memory fact = IStreamArtistPrimaryTemplateConsentFacts(
                address(primaryResolver)
            ).previewArtistPrimaryTemplateConsentAssignment(1, templateId, 0, false);
        require(
            selected.templateId == templateId && selected.assignmentHash == fact.assignmentHash,
            "current consumed assignment matches exact actual Artist approval"
        );
        require(selected.wallet.code.length == 0, "new template split has not been deployed");
    }

    function createCommerceAuction() external returns (bytes32) {
        uint64 now_ = uint64(block.timestamp);
        IStreamNativeEnglishAuction.Configuration memory c;
        c.collectionId = 1;
        c.phaseId = COMMERCE_PHASE;
        c.mintAtSettlement = true;
        c.artworkCommitment = keccak256(TOKEN_DATA);
        c.mintCommitment = keccak256("actual consented commerce mint");
        c.poster = address(this);
        c.reservePrice = PRICE;
        c.minIncrementBps = 500;
        c.clock = StreamEnglishAuctionClock.Configuration(
            now_, now_ + 3600, 0, 600, 600, 3600, false, false
        );
        c.primaryPolicyMode = 1;
        c.settlementWindow = 7 days;
        c.mintPolicyHash = manager.phasePolicyHash(1, COMMERCE_PHASE);
        c.expectedPrimaryPolicyHash = keccak256(
            abi.encode(
                keccak256("6529STREAM_PRIMARY_POLICY_V1"),
                block.chainid,
                address(primaryResolver),
                PRIMARY_REVENUE_CLASS,
                uint256(1),
                uint256(0),
                selected.templateId,
                selected.profileId,
                selected.wallet,
                selected.assignmentHash
            )
        );
        StreamPreparedNativeRightsTypes.OriginalPolicy memory o =
            StreamPreparedNativeRightsTypes.OriginalPolicy(
                2, selected.assignmentHash, selected.templateId
            );
        IStreamNativeEnglishAuction.CreationAuthorization memory a =
            IStreamNativeEnglishAuction.CreationAuthorization(
                house.rightsConfigurationHash(c, o),
                address(artistSafe),
                keccak256("joined auction authorization"),
                now_ + 1 days
            );
        bytes32 digest = house.creationAuthorizationDigest(a);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(PLATFORM_KEY, digest);
        return house.registerRightsAuction(
            c, o, TOKEN_DATA, a, abi.encodePacked(r, s, v), _artistProof(digest)
        );
    }

    function _bid(bytes32 id) private {
        IStreamRevealFeeEscrow.CollectionRevealPolicy memory reveal =
            entropy.collectionRevealPolicy(1);
        require(
            reveal.declared && reveal.requestMode == 1 && reveal.revealFeePerTokenWei == 100,
            "actual selected owner-window reveal policy"
        );
        uint256 beforeBalance = address(payerSafe).balance;
        require(
            executeSafe(
                payerSafe,
                keys,
                address(house),
                PRICE + reveal.revealFeePerTokenWei,
                abi.encodeCall(house.bid, (id, address(0))),
                0
            ),
            "Safe bids and funds exact price plus reveal fee"
        );
        IStreamNativeEnglishAuction.WinningBid memory bid = house.auction(id).winner;
        require(
            bid.payer == address(payerSafe) && bid.executor == address(payerSafe)
                && bid.deliverTo == address(payerSafe)
                && address(payerSafe).balance == beforeBalance - PRICE - 100,
            "original Safe payment and delivery identity"
        );
    }

    function _assertSettlementAndWithdraw(bytes32 id) private {
        IStreamNativeEnglishAuction.Auction memory a = house.auction(id);
        require(
            a.status == 3 && a.tokenId == core.lastAllocatedTokenId()
                && core.ownerOf(a.tokenId) == address(payerSafe) && core.totalSupply() == 1
                && manager.nextOperationNonce() == 1 && core.pendingPreparedMintTokenId() == 0,
            "actual current Core mint completes once to winning Safe"
        );
        require(
            recorder.settlementConsumed(a.settlementKey)
                && recorder.totalOfficialSettled(address(0)) == PRICE
                && recorder.preparedNativeRightsFactsHash(a.settlementKey) != 0,
            "official original recorder retains paid prepared rights evidence"
        );
        require(
            recorder.settlementResult(a.settlementKey).amount == PRICE
                && recorder.settlementResult(a.settlementKey).wallet == selected.wallet
                && recorder.settlementResult(a.settlementKey).profileId == selected.profileId,
            "official payment resolves the Artist-approved template"
        );
        require(
            revenueEscrow.escrowOwed(
                PRIMARY_REVENUE_CLASS, selected.profileId, selected.wallet, address(0)
            ) == PRICE,
            "new template proceeds are credited once to original escrow"
        );
        require(
            executeSafe(
                payerSafe,
                keys,
                address(revenueEscrow),
                0,
                abi.encodeCall(
                    revenueEscrow.flushEscrow,
                    (PRIMARY_REVENUE_CLASS, selected.profileId, selected.wallet, address(0))
                ),
                0
            ),
            "Safe flush deploys and funds the actual split wallet"
        );
        uint256 beforeArtist = address(artistSafe).balance;
        require(
            executeSafe(
                artistSafe,
                keys,
                selected.wallet,
                0,
                abi.encodeCall(
                    IStreamSplitWallet.release,
                    (address(0), address(artistSafe), payable(address(artistSafe)))
                ),
                0
            ),
            "artist Safe withdraws its explicitly approved share"
        );
        IStreamSplitWallet(selected.wallet).release(address(0), PROTOCOL, payable(PROTOCOL));
        require(
            address(artistSafe).balance == beforeArtist + PRICE / 10
                && PROTOCOL.balance == PRICE * 9 / 10 && selected.wallet.balance == 0
                && revenueEscrow.totalOwed(address(0)) == 0,
            "actual 10/90 payout and empty escrow after withdrawals"
        );
        require(
            entropy.revealFeeEscrow(1) == 100 && house.totalBuyerLiabilities() == 0,
            "reveal fee credited separately and buyer liability discharged"
        );
    }

    function setRecorderAdmission(bool enabled) external {
        (bytes32 scope, bytes32 oldHash, bytes32 newHash) =
            revenueEscrow.creditProducerTransitionHashes(address(recorder), enabled);
        bytes memory data =
            abi.encodeCall(revenueEscrow.setCreditProducer, (address(recorder), enabled));
        (bytes32 actionId, uint64 ready) =
            _schedule(address(revenueEscrow), data, scope, oldHash, newHash);
        vm.warp(ready);
        executor.executeGovernanceAction(actionId, data);
    }

    function _schedule(
        address target,
        bytes memory data,
        bytes32 scope,
        bytes32 oldHash,
        bytes32 newHash
    ) private returns (bytes32 actionId, uint64 ready) {
        bytes4 selector;
        assembly ("memory-safe") { selector := mload(add(data, 32)) }
        ready = uint64(block.timestamp + 48 hours);
        GovernanceActionRequest memory request = GovernanceActionRequest(
            1,
            target,
            0,
            selector,
            data,
            scope,
            oldHash,
            newHash,
            ready,
            uint64(ready + 7 days),
            keccak256("actual consented commerce governance"),
            "urn:6529stream:fixture:consented-commerce",
            DEPLOYMENT_HASH
        );
        bytes memory scheduled = governanceRoot.execute(
            address(executor), 0, abi.encodeCall(executor.scheduleGovernanceAction, (request))
        );
        actionId = abi.decode(scheduled, (bytes32));
    }
}
