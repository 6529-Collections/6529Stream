// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../helpers/StreamCurrentSafeGovernanceFixture.sol";
import "../../smart-contracts/domains/mint/StreamNativeDutchSale.sol";
import "../../smart-contracts/domains/revenue/StreamPrimarySaleSettlement.sol";
import "../../smart-contracts/domains/entropy/StreamEntropyProviderARRNG.sol";
import "../../smart-contracts/interfaces/stream/artist/IStreamArtistIdentityContest.sol";
import {
    StreamArtistSaleTypes as SaleTerms
} from "../../smart-contracts/interfaces/stream/artist/StreamArtistSaleTypes.sol";

/// @dev The only external-system double; its failure is controlled by an actual Safe.
contract CurrentDutchARRNGService {
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
contract StreamCurrentDutchSaleTest is StreamCurrentSafeGovernanceFixture {
    bytes32 private constant DUTCH_PHASE = keccak256("actual current Dutch phase");
    bytes32 private constant SALT = keccak256("actual current Dutch entropy salt");
    uint256 private constant PRICE = 1000;
    uint256 private constant FEE = 100;
    uint256[] private keys;
    OfficialSafe private artistSafe;
    OfficialSafe private operatorSafe;
    OfficialSafe private payerSafe;
    OfficialSafe private keeperSafe;
    StreamPrimarySaleSettlement private recorder;
    StreamNativeDutchSale private dutchSale;
    StreamEntropyProviderARRNG private arrng;
    CurrentDutchARRNGService private upstream;
    bytes32 private dutchId;

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
                abi.encodeCall(entropy.setRequester, (address(dutchSale), true)),
                0,
                0,
                0
            )
        );
        require(entropy.requesters(address(dutchSale)), "actual admitted AT_MINT requester");
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
        recorder =
            new StreamPrimarySaleSettlement(primaryResolver, address(registry), revenueEscrow);
        StreamNativeDutchSale.DeploymentConfig memory config;
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
        dutchSale = new StreamNativeDutchSale(config);
        upstream = new CurrentDutchARRNGService(address(operatorSafe), address(artistSafe));
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
            "urn:stream:current:dutch-arrng",
            keccak256("current Dutch ARRNG manifest")
        );
        _assertDeployableProductionInstance(address(recorder));
        _assertDeployableProductionInstance(address(dutchSale));
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
            address(dutchSale),
            dutchSale.raiseGasParameter.selector,
            address(dutchSale).codehash,
            keccak256(abi.encode(DEPLOYMENT_HASH, address(dutchSale))),
            1,
            0,
            0,
            0
        );
    }

    function _configureAdditionalProducts() internal override {
        StreamModuleRegistration[] memory registrations = new StreamModuleRegistration[](1);
        registrations[0] = StreamModuleRegistration(
            address(dutchSale),
            keccak256("NATIVE_PRIMARY_SALE_ADAPTER"),
            keccak256("6529STREAM_UNIVERSAL_SETTLEMENT_V1"),
            type(IStreamNativeSaleBinding).interfaceId,
            500_000,
            address(dutchSale).codehash,
            DEPLOYMENT_HASH,
            keccak256("current Dutch module"),
            "urn:stream:current:dutch"
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
                    "urn:stream:current:dutch-admission",
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
        _configureMintPhase(DUTCH_PHASE, address(dutchSale));
        dutchId = dutchSale.registerDutchSale(
            IStreamNativeDutchSale.DutchSaleConfig(
                1,
                DUTCH_PHASE,
                IStreamDutchPriceSchedule.DutchPriceSchedule(
                    1000, 200, uint64(block.timestamp), uint64(block.timestamp + 10 days), 0, 0, 0
                ),
                20,
                uint64(block.timestamp + 60 days),
                false,
                manager.phasePolicyHash(1, DUTCH_PHASE)
            )
        );
        dutchSale.transferOwnership(address(operatorSafe));
    }

    function _fixtureSaleConsentScope() internal pure override returns (uint8) {
        return 1;
    }

    function testActualSafeConsentDecliningPriceExactRevenueRevealAndPullCredit() public {
        IStreamNativeDutchSale.DutchPurchaseData memory data = _purchaseData(1, PRICE);
        bytes32 digest = dutchSale.authorizationDigest(data.authorization);
        uint256 payerBefore = address(payerSafe).balance;
        require(artists.saleConsentScope(1) == 1, "actual REQUIRED election");
        vm.expectRevert(abi.encodeWithSignature("Error(string)", "GS013"));
        this.purchaseAsSafe(data, 1200);
        require(
            core.totalSupply() == 0 && address(payerSafe).balance == payerBefore
                && !dutchSale.authorizationUsed(address(artistSafe), data.authorization.nonce),
            "missing consent has no effects"
        );
        _consent();
        IStreamDutchPriceSchedule.DutchPriceSchedule memory schedule =
        dutchSale.saleRecord(dutchId).config.schedule;
        vm.warp(uint256(schedule.startTime) + 5 days);
        require(
            dutchSale.currentPrice(dutchId) == 600
                && dutchSale.authorizationDigest(data.authorization) == digest,
            "charge falls without changing signed maximum"
        );
        IStreamNativeDutchSale.DutchPurchaseResult memory result = _purchase(data, 1200);
        require(
            result.revenueOutcome == 2 && result.chargedAmount == 600
                && result.revealFeeForwarded == FEE && result.excessCredited == 500
                && !result.escrowed && result.settlementKey != 0,
            "exact price fee and excess"
        );
        require(
            core.ownerOf(1) == address(payerSafe) && core.collectionMintedEver(1) == 1
                && recorder.totalOfficialSettled(address(0)) == 600 && wallet.balance == 600
                && address(payerSafe).balance == payerBefore - 1200
                && dutchSale.refundableBalance(dutchId, address(payerSafe)) == 500
                && dutchSale.refundLiability() == 500 && address(dutchSale).balance == 500,
            "actual NFT custody official revenue and per-sale buyer credit"
        );
        require(
            upstream.arrngRequestId() == 1 && entropy.pendingRequestCount() == 1
                && entropy.revealFeeEscrow(1) == 0,
            "actual admitted AT_MINT request"
        );
        _deliver(1, 777, data.authorization.mintCommitment);
        _safeRead(abi.encodeCall(dutchSale.saleRecord, (dutchId)));
        _safeRead(abi.encodeCall(dutchSale.currentPrice, (dutchId)));
        _safeRead(abi.encodeCall(dutchSale.eip712Domain, ()));
        _safeRead(abi.encodeCall(dutchSale.authorizationDigest, (data.authorization)));
        _safeRead(abi.encodeCall(dutchSale.refundableBalance, (dutchId, address(payerSafe))));
        _setRole(keccak256("ROLE_PAUSE_GUARDIAN"), address(operatorSafe), true);
        _exec(
            operatorSafe,
            address(dutchSale),
            0,
            abi.encodeCall(dutchSale.pauseAdapter, (GOVERNANCE_REASON))
        );
        _exec(operatorSafe, address(dutchSale), 0, abi.encodeCall(dutchSale.closeSale, (dutchId)));
        vm.prank(vm.addr(keys[0]));
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamNativeDutchSale.DutchCreditEmpty.selector, dutchId, vm.addr(keys[0])
            )
        );
        dutchSale.claimRefund(dutchId, address(payerSafe));
        _exec(
            payerSafe,
            address(dutchSale),
            0,
            abi.encodeCall(dutchSale.claimRefund, (dutchId, address(payerSafe)))
        );
        require(
            address(payerSafe).balance == payerBefore - 700 && dutchSale.refundLiability() == 0
                && address(dutchSale).balance == 0,
            "closed paused sale retains Safe pull claim"
        );
        _exec(
            payerSafe,
            address(core),
            0,
            abi.encodeWithSignature(
                "safeTransferFrom(address,address,uint256)",
                address(payerSafe),
                address(artistSafe),
                uint256(1)
            )
        );
        require(
            core.ownerOf(1) == address(artistSafe), "Safe transfers revealed NFT to another Safe"
        );
    }

    function testSignedMaximumRejectsThenSameSafeAuthorizationExecutesAtRestingPrice() public {
        _consent();
        IStreamNativeDutchSale.DutchPurchaseData memory data = _purchaseData(2, 500);
        bytes32 digest = dutchSale.authorizationDigest(data.authorization);
        require(dutchSale.currentPrice(dutchId) > 500, "negative is above signed maximum");
        vm.expectRevert(abi.encodeWithSignature("Error(string)", "GS013"));
        this.purchaseAsSafe(data, 700);
        require(
            !dutchSale.authorizationUsed(address(artistSafe), data.authorization.nonce)
                && dutchSale.executionIdByNonce(dutchId, 2) == 0 && core.totalSupply() == 0,
            "price rejection does not consume either replay lane"
        );
        vm.warp(dutchSale.saleRecord(dutchId).config.schedule.endTime);
        IStreamNativeDutchSale.DutchPurchaseResult memory result = _purchase(data, 700);
        require(
            result.chargedAmount == 200 && result.excessCredited == 400
                && dutchSale.authorizationDigest(data.authorization) == digest
                && recorder.totalOfficialSettled(address(0)) == 200 && wallet.balance == 200,
            "same signed maximum exact resting-price execution"
        );
        vm.expectRevert(abi.encodeWithSignature("Error(string)", "GS013"));
        this.purchaseAsSafe(data, 700);
        require(
            core.collectionMintedEver(1) == 1 && wallet.balance == 200
                && dutchSale.refundableBalance(dutchId, address(payerSafe)) == 400,
            "replay preserves mint revenue and credit"
        );
    }

    function testCaughtActualProviderFailurePreservesDutchMintAndPublicSafeRetry() public {
        _consent();
        _exec(operatorSafe, address(upstream), 0, abi.encodeCall(upstream.setRejecting, (true)));
        IStreamNativeDutchSale.DutchPurchaseData memory data = _purchaseData(3, PRICE);
        uint256 price = dutchSale.currentPrice(dutchId);
        IStreamNativeDutchSale.DutchPurchaseResult memory result = _purchase(data, price + FEE);
        require(
            core.ownerOf(1) == address(payerSafe) && result.chargedAmount == price
                && recorder.totalOfficialSettled(address(0)) == price && wallet.balance == price
                && dutchSale.executionStatus(result.executionId) == 2
                && dutchSale.refundLiability() == 0 && upstream.arrngRequestId() == 0
                && entropy.revealFeeEscrow(1) == FEE,
            "admitted failed request retains NFT revenue and collection fee"
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
            "permissionless Safe retries from collection escrow"
        );
        _deliver(1, 888, data.authorization.mintCommitment);
    }

    function testActualArtistContestDeniesNewDutchPurchaseButPreservesSafeCreditExit() public {
        _consent();
        uint256 price = dutchSale.currentPrice(dutchId);
        _purchase(_purchaseData(4, PRICE), price + FEE + 100);
        IStreamNativeDutchSale.DutchPurchaseData memory denied = _purchaseData(5, PRICE);
        _setRole(keccak256("ROLE_ATTRIBUTION_ARBITER"), address(operatorSafe), true);
        IStreamArtistIdentityContest contests = IStreamArtistIdentityContest(address(artists));
        bytes32 evidence = keccak256("Dutch actual identity contest");
        (bytes32 scope, bytes32 old_, bytes32 next_) = contests.identityContestGovernanceContext(
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
            IStreamArtistIdentityOwner(artistSuite.owners[2]).identity(fixtureArtistId).status == 4
                && block.timestamp < denied.authorization.deadline
                && block.timestamp < dutchSale.saleRecord(dutchId).config.closesAt,
            "actual contest within valid sale and signature windows"
        );
        vm.expectRevert(abi.encodeWithSignature("Error(string)", "GS013"));
        this.purchaseAsSafe(denied, PRICE + FEE);
        require(
            core.collectionMintedEver(1) == 1 && wallet.balance == price
                && !dutchSale.authorizationUsed(address(artistSafe), denied.authorization.nonce)
                && dutchSale.executionIdByNonce(dutchId, 5) == 0,
            "contest denies mint without consuming signed authorization"
        );
        uint256 beforeBalance = address(payerSafe).balance;
        _exec(
            payerSafe,
            address(dutchSale),
            0,
            abi.encodeCall(dutchSale.claimRefund, (dutchId, address(payerSafe)))
        );
        require(
            address(payerSafe).balance == beforeBalance + 100 && dutchSale.refundLiability() == 0,
            "artist contest cannot trap buyer excess"
        );
    }

    function _consent() private {
        bytes32 configHash = dutchSale.saleRecord(dutchId).configHash;
        SaleTerms.Consent memory terms =
            SaleTerms.Consent(1, address(dutchSale), dutchId, configHash);
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
        (bool consented, bytes32 recordHash) = artists.isSaleConsented(1, dutchId, configHash);
        SaleTerms.Record memory record = artists.saleConsentRecord(recordHash);
        require(
            consented && record.signer == address(artistSafe) && record.artistId == fixtureArtistId
                && record.terms.saleAdapter == address(dutchSale) && record.terms.saleId == dutchId
                && record.terms.saleConfigHash == configHash,
            "actual operation16 records Safe artist and exact sale terms"
        );
    }

    function _purchaseData(uint256 number, uint256 maximum)
        private
        returns (IStreamNativeDutchSale.DutchPurchaseData memory data)
    {
        IStreamNativeDutchSale.DutchSaleRecord memory record = dutchSale.saleRecord(dutchId);
        data.tokenData = abi.encode("actual current Dutch artwork", number);
        data.authorization = IStreamNativeDutchSale.DutchAuthorization(
            dutchId,
            record.configHash,
            address(payerSafe),
            address(payerSafe),
            address(payerSafe),
            address(artistSafe),
            keccak256(data.tokenData),
            keccak256(abi.encode("actual Dutch mint", number)),
            number,
            bytes32(number),
            uint64(block.timestamp + 90 days),
            record.expectedPrimaryPolicyHash,
            maximum
        );
        bytes32 digest = dutchSale.authorizationDigest(data.authorization);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(PLATFORM_KEY, digest);
        data.platformSignature = abi.encodePacked(r, s, v);
        data.artistSignature =
            safeThresholdSignature(keys, safeMessageDigest(artistSafe, abi.encode(digest)));
    }

    function _purchase(IStreamNativeDutchSale.DutchPurchaseData memory data, uint256 value)
        private
        returns (IStreamNativeDutchSale.DutchPurchaseResult memory result)
    {
        vm.recordLogs();
        this.purchaseAsSafe(data, value);
        Vm.Log[] memory logs = vm.getRecordedLogs();
        uint256 found;
        for (uint256 i; i < logs.length; ++i) {
            if (
                logs[i].emitter != address(dutchSale)
                    || logs[i].topics[0]
                        != keccak256(
                            "DutchPurchaseCompleted(uint16,bytes32,bytes32,address,(uint8,uint256,uint256,uint256,uint256,bytes32,bytes32,bytes32,bytes32,bool))"
                        )
            ) continue;
            require(
                logs[i].topics.length == 4 && logs[i].topics[1] == dutchId
                    && address(uint160(uint256(logs[i].topics[3]))) == address(payerSafe),
                "exact actual purchase event actors"
            );
            uint16 version;
            (version, result) =
                abi.decode(logs[i].data, (uint16, IStreamNativeDutchSale.DutchPurchaseResult));
            require(
                version == 1 && result.executionId == logs[i].topics[2] && result.operationId != 0
                    && dutchSale.executionIdByNonce(dutchId, data.authorization.executionNonce)
                        == result.executionId && dutchSale.executionStatus(result.executionId) == 2,
                "one committed actual execution and mint operation"
            );
            ++found;
        }
        require(found == 1, "one completion event");
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
        (bool ok, bytes memory expected) = address(dutchSale).staticcall(data);
        vm.prank(address(payerSafe));
        (bool asSafe, bytes memory actual) = address(dutchSale).staticcall(data);
        require(ok && asSafe && keccak256(expected) == keccak256(actual), "Safe read parity");
        _exec(payerSafe, address(dutchSale), 0, data);
    }

    function _exec(OfficialSafe caller, address target, uint256 value, bytes memory data) private {
        require(
            executeSafe(caller, keys, target, value, data, 0), "actual threshold Safe execution"
        );
    }

    function purchaseAsSafe(IStreamNativeDutchSale.DutchPurchaseData calldata data, uint256 value)
        external
    {
        require(msg.sender == address(this), "fixture only");
        _exec(payerSafe, address(dutchSale), value, abi.encodeCall(dutchSale.purchase, (data)));
    }

    function requestAsKeeper() external {
        require(msg.sender == address(this), "fixture only");
        _exec(keeperSafe, address(entropy), 0, abi.encodeCall(entropy.requestEntropy, (uint256(1))));
    }
}
