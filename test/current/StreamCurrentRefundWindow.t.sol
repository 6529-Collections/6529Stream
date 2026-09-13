// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../helpers/StreamCurrentSafeGovernanceFixture.sol";
import "../../smart-contracts/domains/mint/StreamNativeRefundWindowSale.sol";
import "../../smart-contracts/domains/revenue/StreamPrimarySaleSettlement.sol";
import "../../smart-contracts/domains/entropy/StreamEntropyProviderARRNG.sol";
import "../../smart-contracts/interfaces/stream/artist/IStreamArtistIdentityContest.sol";

/// @dev The only external-system double; its failure is controlled by an actual Safe.
contract CurrentRefundARRNGService {
    address public owner;
    address public immutable oracleAddress;
    uint64 public arrngRequestId;
    uint128 public constant minimumNativeToken = 100;
    bool public rejecting;
    mapping(uint256 => address) public requestAdapter;

    constructor(address controller, address oracle) {
        owner = controller;
        oracleAddress = oracle;
    }

    function setRejecting(bool value) external {
        require(msg.sender == owner, "controller");
        rejecting = value;
    }

    function requestRandomWords(uint256 count, address refund)
        external
        payable
        returns (uint256 id)
    {
        require(!rejecting, "external service unavailable");
        require(count == 1 && refund == msg.sender && msg.value == 100, "request/fee");
        id = ++arrngRequestId;
        requestAdapter[id] = msg.sender;
        (bool paid,) = oracleAddress.call{ value: msg.value }("");
        require(paid, "oracle fee");
    }

    function deliver(uint256 id, uint256 word) external {
        require(msg.sender == oracleAddress, "oracle");
        uint256[] memory words = new uint256[](1);
        words[0] = word;
        IStreamEntropyProviderARRNG(requestAdapter[id]).receiveRandomness(id, words);
    }
}

/// @notice Actual Core/Manager/artist/settlement/entropy/Executor and threshold Safe composition.
contract StreamCurrentRefundWindowTest is StreamCurrentSafeGovernanceFixture {
    bytes32 private constant REFUND_PHASE = keccak256("actual current refund phase");
    bytes32 private constant SALT = keccak256("actual current refund entropy salt");
    uint256 private constant PRICE = 1000;
    uint256 private constant FEE = 100;
    uint256[] private keys;
    OfficialSafe private artistSafe;
    OfficialSafe private operatorSafe;
    OfficialSafe private payerSafe;
    OfficialSafe private keeperSafe;
    StreamPrimarySaleSettlement private recorder;
    StreamNativeRefundWindowSale private refundSale;
    StreamEntropyProviderARRNG private arrng;
    CurrentRefundARRNGService private upstream;
    bytes32 private refundId;

    function setUp() public {
        keys.push(0x5AFE01);
        keys.push(0x5AFE02);
        SafeComponents memory components = deploySafeComponents("1.4.1");
        artistSafe = createOfficialSafe(components, safeOwnerAddresses(keys), 2, 211);
        operatorSafe = createOfficialSafe(components, safeOwnerAddresses(keys), 2, 212);
        payerSafe = createOfficialSafe(components, safeOwnerAddresses(keys), 2, 213);
        keeperSafe = createOfficialSafe(components, safeOwnerAddresses(keys), 2, 214);
        _deployCurrentStack(address(artistSafe), vm.addr(PLATFORM_KEY));
        _installGovernorSafe(operatorSafe, keys);
        vm.deal(address(payerSafe), 1 ether);
        _govern(
            _governanceRequest(
                1,
                address(entropy),
                abi.encodeCall(entropy.setRequester, (address(refundSale), true)),
                0,
                0,
                0
            )
        );
        require(entropy.requesters(address(refundSale)), "actual admitted AT_MINT requester");
        require(
            !roles.hasRole(keccak256("ROLE_ENTROPY_ADMIN"), address(keeperSafe))
                && !roles.hasRole(keccak256("ROLE_ENTROPY_REVEAL_OWNER"), address(keeperSafe)),
            "keeper has no entropy role"
        );
    }

    function _artistProof(bytes32 digest) internal override returns (bytes memory) {
        return safeThresholdSignature(keys, safeMessageDigest(artistSafe, abi.encode(digest)));
    }

    function _revealPrincipals()
        internal
        view
        override
        returns (StreamRevealActivationPlan.Principals memory)
    {
        return StreamRevealActivationPlan.Principals(
            address(operatorSafe), address(operatorSafe), address(operatorSafe)
        );
    }

    function _configureInitialRevealPolicy() internal override {
        _exec(
            operatorSafe,
            address(entropy),
            0,
            abi.encodeCall(
                entropy.configureCollectionRevealPolicy,
                (uint256(1), uint8(0), keccak256("ROLE_ENTROPY_REVEAL_OWNER"), uint64(100), FEE)
            )
        );
    }

    function _deployAdditionalProducts() internal override {
        recorder = new StreamPrimarySaleSettlement(
            primaryResolver, address(registry), revenueEscrow
        );
        StreamNativeRefundWindowSale.DeploymentConfig memory config;
        config.manager = manager;
        config.recorder = recorder;
        config.platform = vm.addr(PLATFORM_KEY);
        config.artists = IStreamArtistAttribution(address(artists));
        config.entropy = IStreamRevealFeeEscrow(address(entropy));
        config.roles = roles;
        config.authority = address(executor);
        // Explicit composition budgets; cold candidate sizing is separate acceptance work.
        config.parameters[0] = IStreamGasParameterHost.GasParameterConfig(
            "SALE_ERC1271_GAS_LIMIT", 1_000_000, 350_000, 2
        );
        config.parameters[1] = IStreamGasParameterHost.GasParameterConfig(
            "SALE_ARTIST_AUTHORITY_GAS_LIMIT", 2_000_000, 50_000, 2
        );
        config.parameters[2] = IStreamGasParameterHost.GasParameterConfig(
            "REVEAL_ATTEMPT_GAS_LIMIT", 4_000_000, 50_000, 2
        );
        refundSale = new StreamNativeRefundWindowSale(config);
        upstream = new CurrentRefundARRNGService(address(operatorSafe), address(artistSafe));
        arrng = new StreamEntropyProviderARRNG(
            StreamEntropyProviderARRNG.Config(
                address(entropy),
                address(executor),
                address(upstream),
                address(upstream).codehash,
                address(operatorSafe),
                address(artistSafe),
                address(operatorSafe),
                FEE,
                2_000_000
            ),
            DEPLOYMENT_HASH,
            "urn:stream:current:refund-arrng",
            keccak256("current refund ARRNG manifest")
        );
        _assertDeployableProductionInstance(address(recorder));
        _assertDeployableProductionInstance(address(refundSale));
        _assertDeployableProductionInstance(address(arrng));
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
        rows = new GovernanceActionPolicyEntry[](1);
        rows[0] = GovernanceActionPolicyEntry(
            1,
            address(refundSale),
            refundSale.raiseGasParameter.selector,
            address(refundSale).codehash,
            keccak256(abi.encode(DEPLOYMENT_HASH, address(refundSale))),
            1,
            0,
            0,
            0
        );
    }

    function _configureAdditionalProducts() internal override {
        StreamModuleRegistration[] memory registrations = new StreamModuleRegistration[](1);
        registrations[0] = StreamModuleRegistration(
            address(refundSale),
            keccak256("NATIVE_REFUND_WINDOW_SALE_ADAPTER"),
            keccak256("6529STREAM_UNIVERSAL_SETTLEMENT_V1"),
            type(IStreamDeferredNativeSaleBinding).interfaceId,
            500_000,
            address(refundSale).codehash,
            DEPLOYMENT_HASH,
            keccak256("current refund module"),
            "urn:stream:current:refund"
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
                    "urn:stream:current:refund-admission",
                    DEPLOYMENT_HASH
                )
            )
        );
        vm.warp(ready);
        executor.executeGovernanceBatch(abi.decode(scheduled, (bytes32)), calls, data);
        bytes memory configure = abi.encodeCall(
            entropy.configureCollection, (uint256(1), address(arrng), SALT, false, uint64(100))
        );
        GovernanceActionRequest memory request =
            _governanceRequest(1, address(entropy), configure, 0, 0, 0);
        scheduled = governanceRoot.execute(
            address(executor), 0, abi.encodeCall(executor.scheduleGovernanceAction, (request))
        );
        vm.warp(request.notBefore);
        executor.executeGovernanceAction(abi.decode(scheduled, (bytes32)), configure);
        _configureMintPhase(REFUND_PHASE, address(refundSale));
        refundId = refundSale.registerRefundSale(
            IStreamNativeRefundWindowSale.RefundSaleConfig(
                1,
                REFUND_PHASE,
                PRICE,
                20,
                0,
                uint64(block.timestamp + 60 days),
                1 hours,
                10 days,
                1,
                manager.phasePolicyHash(1, REFUND_PHASE)
            )
        );
        refundSale.transferOwnership(address(operatorSafe));
    }

    function testSafeDepositRefundAndPullClaimPreserveMonotonicPurchaseNonce() public {
        IStreamNativeRefundWindowSale.RefundPurchaseData memory data = _purchaseData(1);
        bytes32 id = _purchase(data);
        require(
            core.totalSupply() == 0 && recorder.totalOfficialSettled(address(0)) == 0
                && wallet.balance == 0,
            "deposit has no mint or revenue"
        );
        require(
            address(refundSale).balance == PRICE + FEE
                && refundSale.totalBuyerLiabilities() == PRICE + FEE,
            "exact pending custody"
        );
        _safeRead(abi.encodeCall(refundSale.refundSaleRecord, (refundId)));
        _safeRead(abi.encodeCall(refundSale.refundPurchaseRecord, (id)));
        _safeRead(abi.encodeCall(refundSale.eip712Domain, ()));
        _safeRead(abi.encodeCall(refundSale.purchaseDeadlines, (id)));
        _safeRead(
            abi.encodeCall(refundSale.refundPurchaseAuthorizationDigest, (data.authorization))
        );
        _exec(payerSafe, address(refundSale), 0, abi.encodeCall(refundSale.refundPurchase, (id)));
        require(
            refundSale.refundableBalance(refundId, address(payerSafe)) == PRICE + FEE
                && refundSale.refundPurchaseRecord(id).status == 3
                && refundSale.totalPendingDeposits() == 0,
            "per-sale credit only"
        );
        _exec(
            payerSafe,
            address(refundSale),
            0,
            abi.encodeCall(refundSale.claimRefund, (refundId, payable(address(payerSafe))))
        );
        require(
            address(payerSafe).balance == 1 ether && address(refundSale).balance == 0
                && refundSale.totalBuyerLiabilities() == 0,
            "Safe full pull refund"
        );
        require(
            refundSale.nextPurchaseNonce(refundId, address(payerSafe)) == 2
                && refundSale.purchaseAuthorizationUsed(
                    address(artistSafe), data.authorization.nonce
                ),
            "consumed authorization stays consumed"
        );
        vm.expectRevert(abi.encodeWithSignature("Error(string)", "GS013"));
        this.purchaseAsSafe(data);
        bytes32 next = _purchase(_purchaseData(2));
        require(
            next != id && refundSale.nextPurchaseNonce(refundId, address(payerSafe)) == 3,
            "fresh monotonic purchase succeeds"
        );
    }

    function testPermissionlessSafeFinalizationPaysMintsAndRequestsActualEntropy() public {
        IStreamNativeRefundWindowSale.RefundPurchaseData memory data = _purchaseData(3);
        bytes32 id = _purchase(data);
        (uint64 deadline,,) = refundSale.purchaseDeadlines(id);
        uint256 oracleBefore = address(artistSafe).balance;
        vm.warp(deadline);
        _exec(
            keeperSafe,
            address(refundSale),
            0,
            abi.encodeCall(refundSale.finalizeRefundWindow, (id))
        );
        IStreamNativeRefundWindowSale.RefundFinalizationResult memory result =
            refundSale.finalizeRefundWindow(id);
        require(
            result.tokenId == 1 && result.amount == PRICE && result.revealFeeForwarded == FEE
                && result.revealFeeRefunded == 0,
            "exact stored result"
        );
        require(
            core.ownerOf(1) == address(payerSafe) && core.collectionMintedEver(1) == 1
                && recorder.totalOfficialSettled(address(0)) == PRICE && wallet.balance == PRICE
                && address(refundSale).balance == 0 && refundSale.totalBuyerLiabilities() == 0,
            "actual mint/revenue/custody"
        );
        require(
            upstream.arrngRequestId() == 1 && entropy.pendingRequestCount() == 1
                && entropy.revealFeeEscrow(1) == 0
                && address(artistSafe).balance == oracleBefore + FEE,
            "actual admitted AT_MINT request spends exact fee"
        );
        _deliver(1, 777, data.authorization.mintCommitment);
        _exec(
            keeperSafe,
            address(refundSale),
            0,
            abi.encodeCall(refundSale.finalizeRefundWindow, (id))
        );
        require(
            core.collectionMintedEver(1) == 1 && upstream.arrngRequestId() == 1
                && wallet.balance == PRICE,
            "finalization is idempotent"
        );
    }

    function testCaughtExternalProviderFailurePreservesMintThenPublicSafeSLOReveals() public {
        _exec(operatorSafe, address(upstream), 0, abi.encodeCall(upstream.setRejecting, (true)));
        IStreamNativeRefundWindowSale.RefundPurchaseData memory data = _purchaseData(4);
        bytes32 id = _purchase(data);
        (uint64 deadline,,) = refundSale.purchaseDeadlines(id);
        vm.warp(deadline);
        _exec(
            keeperSafe,
            address(refundSale),
            0,
            abi.encodeCall(refundSale.finalizeRefundWindow, (id))
        );
        require(
            refundSale.refundPurchaseRecord(id).status == 2 && core.ownerOf(1) == address(payerSafe)
                && recorder.totalOfficialSettled(address(0)) == PRICE
                && entropy.pendingRequestCount() == 0 && upstream.arrngRequestId() == 0
                && entropy.revealFeeEscrow(1) == FEE
                && refundSale.refundCredit(address(payerSafe)) == 0,
            "provider failure does not unwind final mint"
        );
        _exec(operatorSafe, address(upstream), 0, abi.encodeCall(upstream.setRejecting, (false)));
        uint256 registered = entropy.registeredAtBlock(1);
        vm.roll(registered + entropy.effectiveRevealSLOBlocks(1));
        vm.expectRevert(abi.encodeWithSignature("Error(string)", "GS013"));
        this.requestAsKeeper();
        vm.roll(registered + entropy.effectiveRevealSLOBlocks(1) + 1);
        this.requestAsKeeper();
        require(
            upstream.arrngRequestId() == 1 && entropy.revealFeeEscrow(1) == 0
                && address(keeperSafe).balance == 0,
            "public Safe spends collection escrow"
        );
        _deliver(1, 888, data.authorization.mintCommitment);
    }

    function testActualContestBlocksNoneConsentProfileDepositsAndFinalizationButKeepsExit() public {
        _setRole(keccak256("ROLE_ATTRIBUTION_ARBITER"), address(operatorSafe), true);
        bytes32 id = _purchase(_purchaseData(5));
        IStreamNativeRefundWindowSale.RefundPurchaseData memory denied = _purchaseData(6);
        require(artists.saleConsentScope(1) == 0, "actual NONE sale consent");
        IStreamArtistIdentityContest contests = IStreamArtistIdentityContest(address(artists));
        bytes32 evidence = keccak256("refund actual artist contest");
        (bytes32 scope, bytes32 old_, bytes32 next_) =
            contests.identityContestGovernanceContext(
                fixtureArtistId, 0, evidence, GOVERNANCE_REASON
            );
        _govern(
            _governanceRequest(
                1,
                address(artists),
                abi.encodeCall(
                    contests.contestArtistIdentity,
                    (fixtureArtistId, bytes32(0), evidence, GOVERNANCE_REASON)
                ),
                scope,
                old_,
                next_
            )
        );
        require(
            IStreamArtistIdentityOwner(artistSuite.owners[2]).identity(fixtureArtistId).status == 4,
            "actual contested identity"
        );
        (uint64 refundDeadline, uint64 finalizeBy,) = refundSale.purchaseDeadlines(id);
        require(
            block.timestamp >= refundDeadline && block.timestamp < finalizeBy
                && block.timestamp < denied.authorization.deadline,
            "negative remains within valid finalize/signature windows"
        );
        uint256 beforeBalance = address(payerSafe).balance;
        vm.expectRevert(abi.encodeWithSignature("Error(string)", "GS013"));
        this.purchaseAsSafe(denied);
        vm.expectRevert(abi.encodeWithSignature("Error(string)", "GS013"));
        this.finalizeAsKeeper(id);
        require(
            address(payerSafe).balance == beforeBalance
                && refundSale.nextPurchaseNonce(refundId, address(payerSafe)) == 2
                && !refundSale.purchaseAuthorizationUsed(
                    address(artistSafe), denied.authorization.nonce
                ) && refundSale.refundPurchaseRecord(id).status == 1 && core.totalSupply() == 0
                && recorder.totalOfficialSettled(address(0)) == 0,
            "contested admission and finalization roll back"
        );
        vm.warp(uint256(finalizeBy) + 1);
        _exec(
            keeperSafe,
            address(refundSale),
            0,
            abi.encodeCall(refundSale.unlockRefund, (id, uint8(0)))
        );
        _exec(
            payerSafe,
            address(refundSale),
            0,
            abi.encodeCall(refundSale.claimRefund, (refundId, payable(address(payerSafe))))
        );
        require(
            address(payerSafe).balance == 1 ether && refundSale.totalBuyerLiabilities() == 0,
            "contested identity cannot trap payer exit"
        );
    }

    function _purchaseData(uint256 number)
        private
        returns (IStreamNativeRefundWindowSale.RefundPurchaseData memory data)
    {
        IStreamNativeRefundWindowSale.RefundSaleRecord memory record =
            refundSale.refundSaleRecord(refundId);
        data.tokenData = abi.encode("actual current refund artwork", number);
        data.authorization = IStreamNativeRefundWindowSale.RefundPurchaseAuthorization(
            refundId,
            record.configHash,
            address(payerSafe),
            address(payerSafe),
            address(artistSafe),
            keccak256(data.tokenData),
            keccak256(abi.encode("actual refund mint", number)),
            refundSale.nextPurchaseNonce(refundId, address(payerSafe)),
            bytes32(number),
            PRICE,
            uint64(block.timestamp + 30 days),
            record.windowPolicyHash,
            uint64(block.timestamp + 20 days),
            uint64(block.timestamp + 30 days),
            record.expectedPrimaryPolicyHash
        );
        bytes32 digest = refundSale.refundPurchaseAuthorizationDigest(data.authorization);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(PLATFORM_KEY, digest);
        data.platformSignature = abi.encodePacked(r, s, v);
        data.artistSignature =
            safeThresholdSignature(keys, safeMessageDigest(artistSafe, abi.encode(digest)));
    }

    function _purchase(IStreamNativeRefundWindowSale.RefundPurchaseData memory data)
        private
        returns (bytes32 id)
    {
        vm.recordLogs();
        this.purchaseAsSafe(data);
        Vm.Log[] memory logs = vm.getRecordedLogs();
        uint256 found;
        for (uint256 i; i < logs.length; ++i) {
            if (
                logs[i].emitter == address(refundSale)
                    && logs[i].topics[0]
                        == keccak256(
                            "RefundWindowPurchase(uint16,bytes32,bytes32,address,uint256,uint256,uint64)"
                        )
            ) {
                require(
                    logs[i].topics.length == 4 && logs[i].topics[1] == refundId
                        && address(uint160(uint256(logs[i].topics[3]))) == address(payerSafe),
                    "exact purchase event actors"
                );
                (uint16 version, uint256 quantity, uint256 amount,) =
                    abi.decode(logs[i].data, (uint16, uint256, uint256, uint64));
                require(
                    version == 1 && quantity == 1 && amount == PRICE,
                    "exact captured purchase price"
                );
                id = logs[i].topics[2];
                ++found;
            }
        }
        require(
            found == 1 && id != 0 && refundSale.refundPurchaseRecord(id).status == 1,
            "one actual purchase record"
        );
    }

    function _deliver(uint256 id, uint256 word, bytes32 commitment) private {
        _exec(artistSafe, address(upstream), 0, abi.encodeCall(upstream.deliver, (id, word)));
        (, bytes32 key,, bool received, bool delivered) = arrng.providerResultStatus(id);
        uint256[] memory words = new uint256[](1);
        words[0] = word;
        bytes32 raw = keccak256(abi.encode(keccak256("6529STREAM_ARRNG_RAW_V1"), key, id, words));
        bytes32 expected = keccak256(
            abi.encode(
                keccak256("6529STREAM_ENTROPY_SEED_V1"),
                block.chainid,
                address(entropy),
                address(core),
                uint256(1),
                bytes32(uint256(1)),
                address(arrng),
                uint32(1),
                arrng.streamEntropyProviderConfigHash(),
                key,
                id,
                raw,
                SALT,
                commitment
            )
        );
        (bytes32 seed, bool final_) = entropy.tokenSeed(1);
        require(
            received && delivered && final_ && seed == expected
                && bytes(core.tokenURI(1)).length != 0 && entropy.nonterminalTokenCount(1) == 0,
            "exact current seed/metadata lineage"
        );
    }

    function _safeRead(bytes memory data) private {
        (bool ok, bytes memory expected) = address(refundSale).staticcall(data);
        vm.prank(address(payerSafe));
        (bool asSafe, bytes memory actual) = address(refundSale).staticcall(data);
        require(ok && asSafe && keccak256(expected) == keccak256(actual), "Safe read parity");
        _exec(payerSafe, address(refundSale), 0, data);
    }

    function _exec(OfficialSafe caller, address target, uint256 value, bytes memory data) private {
        require(
            executeSafe(caller, keys, target, value, data, 0), "actual threshold Safe execution"
        );
    }

    function purchaseAsSafe(IStreamNativeRefundWindowSale.RefundPurchaseData calldata data)
        external
    {
        require(msg.sender == address(this), "fixture only");
        _exec(
            payerSafe,
            address(refundSale),
            PRICE + FEE,
            abi.encodeCall(refundSale.purchaseRefundWindow, (data))
        );
    }

    function finalizeAsKeeper(bytes32 id) external {
        require(msg.sender == address(this), "fixture only");
        _exec(
            keeperSafe,
            address(refundSale),
            0,
            abi.encodeCall(refundSale.finalizeRefundWindow, (id))
        );
    }

    function requestAsKeeper() external {
        require(msg.sender == address(this), "fixture only");
        _exec(keeperSafe, address(entropy), 0, abi.encodeCall(entropy.requestEntropy, (uint256(1))));
    }
}
