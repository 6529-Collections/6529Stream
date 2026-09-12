// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../helpers/StreamCurrentStackFixture.sol";
import "../helpers/OfficialSafeFixture.sol";
import "../../smart-contracts/domains/entropy/StreamEntropyProviderARRNG.sol";

/// @dev Only the external ARRNG service is simulated. Its custody and callback actors are Safes.
contract CurrentARRNGService {
    address public owner;
    address public immutable oracleAddress;
    uint64 public arrngRequestId;
    uint128 public constant minimumNativeToken = 100;
    mapping(uint256 => address) public requestAdapter;

    constructor(address owner_, address oracle_) {
        owner = owner_;
        oracleAddress = oracle_;
    }

    function transferOwnership(address next) external {
        require(msg.sender == owner && next != address(0), "upstream owner");
        owner = next;
    }

    function requestRandomWords(uint256 count, address refund)
        external
        payable
        returns (uint256 id)
    {
        require(
            count == 1 && refund == msg.sender && msg.value >= minimumNativeToken, "ARRNG request"
        );
        id = ++arrngRequestId;
        requestAdapter[id] = msg.sender;
        (bool ok,) = oracleAddress.call{ value: msg.value }("");
        require(ok, "oracle fee");
    }

    function deliver(uint256 id, uint256 word, uint256 refund) external {
        require(msg.sender == oracleAddress, "upstream oracle");
        uint256[] memory words = new uint256[](1);
        words[0] = word;
        IStreamEntropyProviderARRNG(requestAdapter[id]).receiveRandomness{ value: refund }(
            id, words
        );
    }
}

/// @notice Actual Core/Manager/artist/Executor composition for ARRNG and artist-window governance.
contract StreamCurrentARRNGTest is StreamCurrentStackFixture, OfficialSafeFixture {
    OfficialSafe private artistSafe;
    OfficialSafe private buyerSafe;
    uint256[] private keys;
    CurrentARRNGService private upstream;
    StreamEntropyProviderARRNG private arrng;
    bytes private combinedActivationPlan;
    bytes32 private combinedActivationId;
    bytes32 private constant SALT = keccak256("current ARRNG collection salt");
    bytes32 private constant MINT = keccak256("current ARRNG artwork commitment");

    function setUp() public {
        keys.push(0x5AFE01);
        keys.push(0x5AFE02);
        SafeComponents memory components = deploySafeComponents("1.4.1");
        artistSafe = createOfficialSafe(components, safeOwnerAddresses(keys), 2, 161);
        buyerSafe = createOfficialSafe(components, safeOwnerAddresses(keys), 2, 162);
        _deployCurrentStack(address(artistSafe), vm.addr(PLATFORM_KEY));
        vm.deal(address(buyerSafe), 1 ether);
        vm.deal(address(this), 1 ether);
        vm.deal(address(upstream), 1 ether);
        _installSafeGovernor();
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
            address(buyerSafe), address(buyerSafe), address(buyerSafe)
        );
    }

    /// @dev Exercise the exact five-call initial deployment plan with actual Safe role holders.
    function _activateArtistAuthority() internal override {
        StreamArtistActivationPlan.Plan memory plan = StreamRevealActivationPlan.buildWithArtist(
            roles, manager, address(this), _revealPrincipals()
        );
        uint64 notBefore = uint64(block.timestamp + 49 hours);
        executor.publishGovernanceCallData(plan.callDatas);
        uint256 nonce = executor.governanceNonce();
        combinedActivationId = _scheduleFixtureActivation(plan, notBefore);
        combinedActivationPlan = abi.encode(plan);
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamGovernanceExecutor.GovernanceActionNotExecutable.selector,
                combinedActivationId,
                notBefore
            )
        );
        this.executeSavedCombinedActivation(_revealPrincipals());
        vm.warp(notBefore);
        this.executeSavedCombinedActivation(_revealPrincipals());
        this.executeSavedCombinedActivation(_revealPrincipals());
        require(
            executor.governanceNonce() == nonce + 1,
            "one combined action, retry does not reschedule"
        );
    }

    function executeSavedCombinedActivation(StreamRevealActivationPlan.Principals memory principals)
        external
    {
        require(msg.sender == address(this), "fixture only");
        StreamRevealActivationPlan.execute(
            executor,
            roles,
            manager,
            address(this),
            principals,
            combinedActivationId,
            abi.decode(combinedActivationPlan, (StreamArtistActivationPlan.Plan))
        );
    }

    function _activateRevealAuthority() internal override {
        require(
            executeSafe(
                buyerSafe,
                keys,
                address(entropy),
                0,
                abi.encodeCall(
                    entropy.configureCollectionRevealPolicy,
                    (1, 0, keccak256("ROLE_ENTROPY_REVEAL_OWNER"), uint64(100), uint256(100))
                ),
                0
            ),
            "Safe declares reveal policy before registrations"
        );
    }

    function testCompletedCombinedActivationStillRejectsChangedPrincipal() public {
        StreamRevealActivationPlan.Principals memory principals = _revealPrincipals();
        principals.treasury = address(artistSafe);
        vm.expectRevert(
            abi.encodeWithSelector(StreamRevealActivationPlan.InvalidRevealActivationPlan.selector)
        );
        this.executeSavedCombinedActivation(principals);
        vm.expectRevert(
            abi.encodeWithSelector(StreamEntropyCoordinator.Unauthorized.selector, address(this))
        );
        entropy.updateRevealFeePerToken(1, 101);
        vm.prank(vm.addr(keys[0]));
        vm.expectRevert(
            abi.encodeWithSelector(StreamEntropyCoordinator.Unauthorized.selector, vm.addr(keys[0]))
        );
        entropy.updateRevealFeePerToken(1, 101);
    }

    function testSafeRevealEscrowSpendsAtActualRequestAndReleasesOnlyAfterReveal() public {
        uint256 token = _buy();
        require(
            executeSafe(
                buyerSafe,
                keys,
                address(entropy),
                200,
                abi.encodeCall(entropy.fundRevealFeeEscrow, (1)),
                0
            ),
            "Safe funds actual coordinator"
        );
        uint256 beforeOracle = address(artistSafe).balance;
        _requestAsSafe(token, 25);
        require(
            address(artistSafe).balance == beforeOracle + 100 && entropy.revealFeeEscrow(1) == 100
                && entropy.entropyFeeCredit(address(buyerSafe)) == 25
                && entropy.nonterminalTokenCount(1) == 1,
            "escrow pays provider and caller keeps full excess"
        );
        vm.expectRevert(abi.encodeWithSignature("Error(string)", "GS013"));
        this.withdrawRevealEscrowAsSafe(100);
        _deliverAsSafe(1, 42, 0);
        _assertSeed(token, 1, 42);
        uint256 beforeTreasury = address(buyerSafe).balance;
        this.withdrawRevealEscrowAsSafe(100);
        require(
            executeSafe(
                buyerSafe,
                keys,
                address(entropy),
                0,
                abi.encodeCall(entropy.claimEntropyFeeCredit, (payable(address(buyerSafe)))),
                0
            ),
            "Safe claims excess"
        );
        require(
            address(buyerSafe).balance == beforeTreasury + 125
                && entropy.nonterminalTokenCount(1) == 0 && entropy.totalRevealFeeEscrows() == 0
                && entropy.totalFeeCredits() == 0,
            "terminal escrow and caller credit settle independently"
        );
    }

    function withdrawRevealEscrowAsSafe(uint256 amount) external {
        require(msg.sender == address(this), "fixture only");
        require(
            executeSafe(
                buyerSafe,
                keys,
                address(entropy),
                0,
                abi.encodeCall(entropy.withdrawRevealFeeEscrow, (1, amount)),
                0
            ),
            "Safe escrow withdrawal"
        );
    }

    function _deployAdditionalProducts() internal override {
        upstream = new CurrentARRNGService(address(buyerSafe), address(artistSafe));
        arrng = new StreamEntropyProviderARRNG(
            StreamEntropyProviderARRNG.Config(
                address(entropy),
                address(executor),
                address(upstream),
                address(upstream).codehash,
                address(buyerSafe),
                address(artistSafe),
                address(buyerSafe),
                100,
                1_000_000
            ),
            DEPLOYMENT_HASH,
            "urn:stream:fixture:current-arrng",
            keccak256("current ARRNG manifest")
        );
        _assertDeployableProductionInstance(address(arrng));
    }

    function _additionalOperatingPolicies()
        internal
        view
        override
        returns (GovernanceActionPolicyEntry[] memory rows)
    {
        rows = new GovernanceActionPolicyEntry[](5);
        rows[0] = _policy(address(arrng), arrng.updateRequestPayment.selector);
        rows[1] = _policy(address(arrng), arrng.updateControllerOwnerPin.selector);
        rows[2] = _policy(address(arrng), arrng.withdrawFunds.selector);
        rows[3] = _policy(address(arrng), arrng.raiseGasParameter.selector);
        rows[4] = _policy(address(artists), artists.setArtistWindow.selector);
    }

    function _policy(address host, bytes4 selector)
        private
        view
        returns (GovernanceActionPolicyEntry memory)
    {
        return GovernanceActionPolicyEntry(
            1,
            host,
            selector,
            host.codehash,
            keccak256(abi.encode(DEPLOYMENT_HASH, host)),
            1,
            0,
            0,
            0
        );
    }

    function _configureAdditionalProducts() internal override {
        bytes memory data = abi.encodeCall(
            entropy.configureCollection, (1, address(arrng), SALT, true, uint64(100))
        );
        GovernanceActionRequest memory request = _request(address(entropy), data);
        bytes memory result = governanceRoot.execute(
            address(executor), 0, abi.encodeCall(executor.scheduleGovernanceAction, (request))
        );
        vm.warp(request.notBefore);
        executor.executeGovernanceAction(abi.decode(result, (bytes32)), data);
    }

    function testSafeGovernorRaisesLiveSLOThenUnprivilegedSafeRevealsActualMint() public {
        bytes memory restrictRequests = abi.encodeCall(
            entropy.configureCollection, (1, address(arrng), SALT, false, uint64(100))
        );
        _safeGovern(address(entropy), restrictRequests, keccak256("restricted reveal fixture"),
            keccak256("public requests"), keccak256("restricted requests"));
        uint256 token = _buy();
        uint256 registered = entropy.registeredAtBlock(token);
        require(executeSafe(buyerSafe, keys, address(entropy), 100,
            abi.encodeCall(entropy.fundRevealFeeEscrow, (1)), 0), "actual Safe reveal funding");
        bytes32 parameter = entropy.GTP_ENTROPY_REVEAL_SLO_BLOCKS();
        (uint256 value, uint256 floor, uint64 wall, uint64 revision) = entropy.timeParameterInfo(parameter);
        require(value == 100 && floor == 100 && wall == 1200 && revision == 1, "explicit genesis timing");
        bytes32 scope = keccak256(abi.encode(
            bytes32(0xd14cc3d71aa1ccb50b6f723d516042b10a7ef31958f86ccb049a09dbcfefff24),
            block.chainid, address(entropy), parameter));
        bytes32 domain = 0x26290762a61f3dda3fad05a62e5a95dcb1c59db2eaf506cb363c2aa2ab7b8384;
        bytes32 oldState = keccak256(abi.encode(domain, scope, value, floor, wall, revision));
        bytes32 newState = keccak256(abi.encode(domain, scope, uint256(200), floor, wall, revision + 1));
        bytes memory raise = abi.encodeCall(entropy.raiseTimeParameter, (parameter, uint256(200)));
        vm.expectRevert(abi.encodeWithSignature("Error(string)", "GS013"));
        this.attemptDirectEntropyTimeAsSafe(raise);
        _safeGovern(address(entropy), raise, scope, oldState, newState);
        require(entropy.effectiveRevealSLOBlocks(1) == 200
            && entropy.collectionRevealPolicy(1).requestSLOBlocks == 100
            && entropy.registeredAtBlock(token) == registered, "real governed raise retains frozen promise");
        OfficialSafe keeper = createOfficialSafe(
            deploySafeComponents("1.4.1"), safeOwnerAddresses(keys), 2, 163
        );
        require(!roles.hasRole(keccak256("ROLE_ENTROPY_ADMIN"), address(keeper))
            && !roles.hasRole(keccak256("ROLE_ENTROPY_REVEAL_OWNER"), address(keeper)),
            "keeper has no operational authority");
        vm.roll(registered + 200);
        vm.expectRevert(abi.encodeWithSignature("Error(string)", "GS013"));
        this.requestThroughPublicSafe(keeper, token);
        uint256 oracleBefore = address(artistSafe).balance;
        vm.roll(registered + 201);
        this.requestThroughPublicSafe(keeper, token);
        require(entropy.revealFeeEscrow(1) == 0 && address(artistSafe).balance == oracleBefore + 100
            && entropy.entropyFeeCredit(address(keeper)) == 0 && address(keeper).balance == 0,
            "unprivileged Safe pays no value while actual provider receives exact escrow fee");
        _deliverAsSafe(1, 9876, 0);
        _assertSeed(token, 1, 9876);
        require(core.ownerOf(token) == address(buyerSafe) && entropy.nonterminalTokenCount(1) == 0,
            "actual mint/reveal lineage and custody remain unchanged");
    }

    function attemptDirectEntropyTimeAsSafe(bytes calldata data) external {
        require(msg.sender == address(this), "fixture only");
        require(executeSafe(buyerSafe, keys, address(entropy), 0, data, 0), "direct Safe time call");
    }

    function requestThroughPublicSafe(OfficialSafe keeper, uint256 token) external {
        require(msg.sender == address(this), "fixture only");
        require(executeSafe(keeper, keys, address(entropy), 0,
            abi.encodeCall(entropy.requestEntropy, (token)), 0), "public Safe request");
    }

    function testSafeARRNGMintRevealAndGovernedTreasuryWithdrawal() public {
        uint256 token = _buy();
        uint256 oracleBefore = address(artistSafe).balance;
        _requestAsSafe(token, 100);
        require(
            address(artistSafe).balance == oracleBefore + 100 && address(arrng).balance == 0,
            "actual provider fee reaches oracle custody"
        );
        _deliverAsSafe(1, 42, 7);
        _assertSeed(token, 1, 42);
        require(
            arrng.totalRefundsReceived() == 7 && address(arrng).balance == 7,
            "refund remains provider custody"
        );
        uint256 treasuryBefore = address(buyerSafe).balance;
        (bytes32 scope, bytes32 old_, bytes32 next_) = arrng.withdrawalTransitionHashes(7);
        _safeGovern(address(arrng), abi.encodeCall(arrng.withdrawFunds, (7)), scope, old_, next_);
        require(
            address(buyerSafe).balance == treasuryBefore + 7 && address(arrng).balance == 0
                && arrng.totalWithdrawn() == 7,
            "actual Safe Executor treasury withdrawal"
        );
    }

    function testSafeARRNGRevocationRetainsRawThenGovernedRaiseAndRetryFinalizesSameOutput()
        public
    {
        uint256 token = _buy();
        _requestAsSafe(token, 100);
        _safeGovern(
            address(entropy),
            abi.encodeCall(entropy.setProviderRevoked, (address(arrng), true)),
            0,
            0,
            0
        );
        _deliverAsSafe(1, 42, 0);
        (StreamProviderResultStatus status,, bytes32 hash, bool received, bool delivered) =
            arrng.providerResultStatus(1);
        require(
            status == StreamProviderResultStatus.RAW_RANDOMNESS_RECEIVED && received && !delivered
                && entropy.pendingRequestCount() == 1,
            "actual revoked outcome retains output"
        );
        vm.expectRevert(
            abi.encodeWithSelector(
                StreamEntropyCoordinator.InvalidStatus.selector, StreamEntropyStatus.REQUESTED
            )
        );
        entropy.requestEntropy{ value: 100 }(token);
        _deliverAsSafe(1, 99, 0);
        (,, bytes32 afterHash,,) = arrng.providerResultStatus(1);
        require(
            hash == afterHash && upstream.arrngRequestId() == 1,
            "conflict cannot become a fresh draw"
        );
        _raiseDeliveryCap();
        _safeGovern(
            address(entropy),
            abi.encodeCall(entropy.setProviderRevoked, (address(arrng), false)),
            0,
            0,
            0
        );
        require(
            executeSafe(
                buyerSafe,
                keys,
                address(arrng),
                0,
                abi.encodeCall(arrng.retryCoordinatorFulfillment, (1)),
                0
            ),
            "real Safe retries persisted output"
        );
        _assertSeed(token, 1, 42);
        require(
            entropy.pendingRequestCount() == 0 && upstream.arrngRequestId() == 1,
            "one terminal request"
        );
    }

    function testSafeARRNGOwnerRefreshAndPaymentChangePreserveEntropyIdentity() public {
        bytes32 identity = arrng.streamEntropyProviderConfigHash();
        require(
            executeSafe(
                buyerSafe,
                keys,
                address(upstream),
                0,
                abi.encodeCall(upstream.transferOwnership, (address(artistSafe))),
                0
            ),
            "Safe upstream ownership transfer"
        );
        vm.expectRevert(
            abi.encodeWithSelector(IStreamEntropyProviderARRNG.ARRNGUpstreamDrift.selector)
        );
        arrng.quoteRequest("");
        (bytes32 scope, bytes32 old_, bytes32 next_) =
            arrng.ownerPinTransitionHashes(address(artistSafe));
        _safeGovern(
            address(arrng),
            abi.encodeCall(arrng.updateControllerOwnerPin, (address(artistSafe))),
            scope,
            old_,
            next_
        );
        (scope, old_, next_) = arrng.paymentTransitionHashes(200);
        _safeGovern(
            address(arrng), abi.encodeCall(arrng.updateRequestPayment, (200)), scope, old_, next_
        );
        require(
            arrng.streamEntropyProviderConfigHash() == identity
                && arrng.controllerOwner() == address(artistSafe) && arrng.quoteRequest("") == 200,
            "operational changes preserve seed identity"
        );
        uint256 token = _buy();
        _requestAsSafe(token, 200);
        _deliverAsSafe(1, 43, 0);
        _assertSeed(token, 1, 43);
    }

    function testSafeGovernorChangesArtistWindowThroughActualIdentityOwner() public {
        bytes32 parameter = keccak256("ARTIST_ROTATION_CONTEST_SECONDS");
        (uint64 value, uint64 floor, uint64 revision) = artists.artistWindowInfo(parameter);
        require(value == 7 days && floor == 72 hours, "accepted initial artist window");
        uint64 next = value + 1 days;
        address owner = artistSuite.owners[2];
        bytes32 scope = keccak256(
            abi.encode(
                keccak256("6529STREAM_ARTIST_WINDOW_SCOPE_V1"), block.chainid, owner, parameter
            )
        );
        bytes32 oldState = keccak256(
            abi.encode(
                keccak256("6529STREAM_ARTIST_WINDOW_STATE_V1"),
                block.chainid,
                owner,
                parameter,
                value,
                floor,
                revision
            )
        );
        bytes32 newState = keccak256(
            abi.encode(
                keccak256("6529STREAM_ARTIST_WINDOW_STATE_V1"),
                block.chainid,
                owner,
                parameter,
                next,
                floor,
                revision + 1
            )
        );
        bytes memory data = abi.encodeCall(artists.setArtistWindow, (parameter, next, revision));
        vm.expectRevert(abi.encodeWithSelector(T.Unauthorized.selector, address(buyerSafe)));
        vm.prank(address(buyerSafe));
        artists.setArtistWindow(parameter, next, revision);
        // Safe's zero-refund execution mode reverts GS013 when the inner target fails.
        vm.expectRevert(abi.encodeWithSignature("Error(string)", "GS013"));
        this.attemptDirectWindowAsSafe(data);
        _safeGovern(address(artists), data, scope, oldState, newState);
        (uint64 updated, uint64 sameFloor, uint64 updatedRevision) =
            artists.artistWindowInfo(parameter);
        require(
            updated == next && sameFloor == floor && updatedRevision == revision + 1,
            "facade and Identity share actual governed state"
        );
        artists.requireMintConsent(1, PHASE, manager.phasePolicyHash(1, PHASE));
        _buy();
    }

    function attemptDirectWindowAsSafe(bytes calldata data) external {
        require(msg.sender == address(this), "test wrapper only");
        executeSafe(buyerSafe, keys, address(artists), 0, data, 0);
    }

    function _buy() private returns (uint256) {
        IStreamFixedPriceSaleAdapter.SaleAuthorization memory a =
            IStreamFixedPriceSaleAdapter.SaleAuthorization({
                collectionId: 1,
                phaseId: PHASE,
                payer: address(buyerSafe),
                recipient: address(buyerSafe),
                artist: address(artistSafe),
                profileId: profile,
                expectedPrimaryPolicyHash: _nativePrimaryPolicyHash(),
                tokenDataHash: keccak256(TOKEN_DATA),
                mintCommitment: MINT,
                mintPolicyHash: manager.phasePolicyHash(1, PHASE),
                price: 0.01 ether,
                nonce: keccak256("current ARRNG mint"),
                deadline: uint64(block.timestamp + 1 days),
                signerEpoch: sale.signerEpoch()
            });
        bytes32 digest = sale.authorizationDigest(a);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(PLATFORM_KEY, digest);
        require(
            executeSafe(
                buyerSafe,
                keys,
                address(sale),
                a.price,
                abi.encodeCall(
                    sale.buy, (a, TOKEN_DATA, abi.encodePacked(r, s, v), _artistProof(digest))
                ),
                0
            ),
            "actual Safe paid mint"
        );
        uint256 token = core.lastAllocatedTokenId();
        require(
            core.ownerOf(token) == address(buyerSafe)
                && core.coordinatorAtMint(token) == address(entropy),
            "actual NFT custody and pinned coordinator"
        );
        return token;
    }

    function _requestAsSafe(uint256 token, uint256 fee) private {
        require(
            executeSafe(
                buyerSafe,
                keys,
                address(entropy),
                fee,
                abi.encodeCall(entropy.requestEntropy, (token)),
                0
            ),
            "Safe entropy request"
        );
        require(
            upstream.arrngRequestId() == 1 && entropy.pendingRequestCount() == 1,
            "actual asynchronous request registered"
        );
    }

    function _deliverAsSafe(uint256 id, uint256 word, uint256 refund) private {
        require(
            executeSafe(
                artistSafe,
                keys,
                address(upstream),
                0,
                abi.encodeCall(upstream.deliver, (id, word, refund)),
                0
            ),
            "Safe oracle callback"
        );
    }

    function _assertSeed(uint256 token, uint256 id, uint256 word) private view {
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
                bytes32(token),
                address(arrng),
                uint32(1),
                arrng.streamEntropyProviderConfigHash(),
                key,
                id,
                raw,
                SALT,
                MINT
            )
        );
        (bytes32 seed, bool finalized) = entropy.tokenSeed(token);
        require(
            received && delivered && finalized && seed == expected
                && bytes(core.tokenURI(token)).length != 0,
            "actual final seed and metadata match independent inputs"
        );
    }

    function _raiseDeliveryCap() private {
        bytes32 parameter = keccak256("6529STREAM_GGP_VRF_CALLBACK_GAS_LIMIT");
        (uint256 value, uint256 floor, uint8 class_, uint64 revision) =
            arrng.gasParameterInfo(parameter);
        bytes32 scope = keccak256(
            abi.encode(
                keccak256("6529STREAM_GAS_PARAMETER_SCOPE_V2"),
                block.chainid,
                address(arrng),
                parameter
            )
        );
        bytes32 domain = keccak256("6529STREAM_GAS_PARAMETER_STATE_V2");
        _safeGovern(
            address(arrng),
            abi.encodeCall(arrng.raiseGasParameter, (parameter, value * 2)),
            scope,
            keccak256(abi.encode(domain, scope, value, floor, class_, revision)),
            keccak256(abi.encode(domain, scope, value * 2, floor, class_, revision + 1))
        );
        require(arrng.gasParameter(parameter) == 2_000_000, "actual governed callback cap");
    }

    function _installSafeGovernor() private {
        (address previous, bytes32 hash, uint64 revision) = executor.governanceRootState();
        bytes memory data = abi.encodeCall(
            executor.rotateGovernanceRoot, (address(buyerSafe), address(buyerSafe).codehash)
        );
        GovernanceActionRequest memory request = _request(address(executor), data);
        request.actionClass = 3;
        request.scopeHash = keccak256(
            abi.encode(
                keccak256("6529STREAM_GOVERNANCE_ROOT_SCOPE_V1"), block.chainid, address(executor)
            )
        );
        request.oldValueHash = _rootState(previous, hash, revision);
        request.newValueHash =
            _rootState(address(buyerSafe), address(buyerSafe).codehash, revision + 1);
        bytes memory result = governanceRoot.execute(
            address(executor), 0, abi.encodeCall(executor.scheduleGovernanceAction, (request))
        );
        vm.warp(request.notBefore);
        executor.executeGovernanceAction(abi.decode(result, (bytes32)), data);
        (address root,,) = executor.governanceRootState();
        require(root == address(buyerSafe), "actual canonical Safe governor");
    }

    function _rootState(address root, bytes32 hash, uint64 revision)
        private
        view
        returns (bytes32)
    {
        return keccak256(
            abi.encode(
                keccak256("6529STREAM_GOVERNANCE_ROOT_STATE_V1"),
                block.chainid,
                address(executor),
                root,
                hash,
                revision
            )
        );
    }

    function _safeGovern(
        address target,
        bytes memory data,
        bytes32 scope,
        bytes32 old_,
        bytes32 next_
    ) private {
        GovernanceActionRequest memory request = _request(target, data);
        request.scopeHash = scope;
        request.oldValueHash = old_;
        request.newValueHash = next_;
        vm.recordLogs();
        require(
            executeSafe(
                buyerSafe,
                keys,
                address(executor),
                0,
                abi.encodeCall(executor.scheduleGovernanceAction, (request)),
                0
            ),
            "Safe schedules exact action"
        );
        Vm.Log[] memory logs = vm.getRecordedLogs();
        bytes32 topic = keccak256(
            "GovernanceActionScheduled(uint16,bytes32,uint8,address,uint256,bytes4,bytes32,bytes32,bytes32,bytes32,uint64,uint64,uint256,address,bytes32,string,bytes32)"
        );
        bytes32 actionId;
        for (uint256 i; i < logs.length; ++i) {
            if (
                logs[i].emitter == address(executor) && logs[i].topics.length == 4
                    && logs[i].topics[0] == topic
            ) {
                require(actionId == 0, "one exact scheduled action");
                actionId = logs[i].topics[1];
            }
        }
        require(actionId != 0, "actual scheduled action observed");
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamGovernanceExecutor.GovernanceActionNotExecutable.selector,
                actionId,
                request.notBefore
            )
        );
        executor.executeGovernanceAction(actionId, data);
        vm.warp(request.notBefore);
        require(
            executeSafe(
                buyerSafe,
                keys,
                address(executor),
                0,
                abi.encodeCall(executor.executeGovernanceAction, (actionId, data)),
                0
            ),
            "Safe executes after real timelock"
        );
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
            0,
            0,
            0,
            uint64(block.timestamp + 48 hours),
            uint64(block.timestamp + 9 days),
            keccak256("current ARRNG governance"),
            "urn:stream:fixture:arrng-governance",
            DEPLOYMENT_HASH
        );
    }
}
