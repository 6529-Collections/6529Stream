// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../helpers/StreamCurrentStackFixture.sol";
import "../helpers/OfficialSafeFixture.sol";
import "../../script/current/PrepareCurrentMintSetup.s.sol";

/// @notice Real Safe artists and initial owners complete exact saved phase plans.
contract StreamCurrentMintSetupTest is StreamCurrentStackFixture, OfficialSafeFixture {
    bytes32 private constant SETUP_PHASE = keccak256("operator setup phase");
    OfficialSafe private artistSafe;
    OfficialSafe private operatorSafe;
    PrepareCurrentMintSetup private planner;
    uint256[] private keys;

    function setUp() public {
        keys.push(0x5AFE01);
        keys.push(0x5AFE02);
        SafeComponents memory components = deploySafeComponents("1.4.1");
        artistSafe = createOfficialSafe(components, safeOwnerAddresses(keys), 2, 91);
        operatorSafe = createOfficialSafe(components, safeOwnerAddresses(keys), 2, 92);
        _deployCurrentStack(address(artistSafe), vm.addr(PLATFORM_KEY));
        planner = new PrepareCurrentMintSetup();
    }

    function _artistProof(bytes32 digest) internal override returns (bytes memory) {
        return safeThresholdSignature(keys, safeMessageDigest(artistSafe, abi.encode(digest)));
    }

    function _handoffManager() internal override {
        manager.transferOwnership(address(operatorSafe));
    }

    function testSafePhaseSetupResumesEveryCallHandsOffAndActuallyMints() public {
        StreamMintSetupPlan.Plan memory plan = _plan();
        for (uint256 i; i < 5; ++i) {
            StreamMintSetupPlan.NextCall memory next = planner.prepare(plan);
            require(uint256(next.step) == i + 1, "exact setup order");
            require(
                keccak256(abi.encode(next)) == keccak256(abi.encode(planner.prepare(plan))),
                "read-only retry preserves call"
            );
            _submit(next);
        }
        _complete(plan);
        require(artistSafe.nonce() == 2 && operatorSafe.nonce() == 3, "actual Safe call counts");
        IStreamFixedPriceSaleAdapter.SaleAuthorization memory authorization =
            IStreamFixedPriceSaleAdapter.SaleAuthorization({
                collectionId: 1,
                phaseId: SETUP_PHASE,
                payer: BUYER,
                recipient: BUYER,
                artist: address(artistSafe),
                profileId: profile,
                expectedPrimaryPolicyHash: _nativePrimaryPolicyHash(),
                price: 0.01 ether,
                deadline: uint64(block.timestamp + 1 days),
                nonce: bytes32(uint256(91)),
                tokenDataHash: keccak256(TOKEN_DATA),
                mintCommitment: keccak256("operator setup mint"),
                mintPolicyHash: manager.phasePolicyHash(1, SETUP_PHASE),
                signerEpoch: sale.signerEpoch()
            });
        bytes32 digest = sale.authorizationDigest(authorization);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(PLATFORM_KEY, digest);
        bytes memory artistSignature = _artistProof(digest);
        vm.deal(BUYER, 1 ether);
        vm.prank(BUYER);
        sale.buy{ value: authorization.price }(
            authorization, TOKEN_DATA, abi.encodePacked(r, s, v), artistSignature
        );
        uint256 tokenId = core.lastAllocatedTokenId();
        require(
            core.ownerOf(tokenId) == BUYER && core.collectionMintedEver(1) == 1,
            "actual mint after setup"
        );
        (, uint256 requestId) = entropy.requestEntropy(tokenId);
        provider.fulfill(requestId, keccak256("operator mint entropy"));
        (, bool finalized) = entropy.tokenSeed(tokenId);
        require(finalized && bytes(core.tokenURI(tokenId)).length != 0, "actual reveal");
        _complete(plan);
    }

    function testWrongSafeFailureDoesNotAdvanceAndCorrectArtistCanRetry() public {
        StreamMintSetupPlan.Plan memory plan = _plan();
        StreamMintSetupPlan.NextCall memory next = planner.prepare(plan);
        vm.prank(address(operatorSafe));
        (bool targetOk, bytes memory reason) = next.target.call(next.data);
        require(
            !targetOk
                && keccak256(reason)
                    == keccak256(abi.encodeWithSelector(T.InvalidSignature.selector)),
            "exact unauthorized target rejection before Safe wrapping"
        );
        bytes32 digest = operatorSafe.getTransactionHash(
            next.target,
            next.value,
            next.data,
            0,
            2_000_000,
            0,
            0,
            address(0),
            address(0),
            operatorSafe.nonce()
        );
        require(
            !operatorSafe.execTransaction(
                next.target,
                next.value,
                next.data,
                0,
                2_000_000,
                0,
                0,
                address(0),
                payable(address(0)),
                safeThresholdSignature(keys, digest)
            ),
            "wrong Safe target failure"
        );
        require(operatorSafe.nonce() == 1, "outer Safe transaction succeeded");
        require(
            keccak256(abi.encode(planner.prepare(plan))) == keccak256(abi.encode(next)),
            "failed outer Safe receipt cannot advance workflow"
        );
        _submit(next);
        require(
            planner.prepare(plan).step == StreamMintSetupPlan.Step.CONFIGURE_PHASE,
            "confirmed artist success advances workflow"
        );
    }

    function testChangedCounterOrPauseCannotResumeSavedPlan() public {
        StreamMintSetupPlan.Plan memory plan = _plan();
        _submit(planner.prepare(plan));
        _submit(planner.prepare(plan));
        plan.phases[0].counters[0].staticCap += 1;
        _expectPlanError(plan, StreamMintSetupPlan.SetupPhaseChanged.selector);
        plan.phases[0].counters[0].staticCap -= 1;
        require(
            executeSafe(
                operatorSafe,
                keys,
                address(manager),
                0,
                abi.encodeCall(manager.setPhasePaused, (1, SETUP_PHASE, true)),
                0
            ),
            "owner pauses"
        );
        _expectPlanError(plan, StreamMintSetupPlan.SetupPhaseChanged.selector);
    }

    function testWrongChainCodeHashAndPrematureOwnershipHandoffAreRejected() public {
        StreamMintSetupPlan.Plan memory plan = _plan();
        plan.chainId += 1;
        _expectPlanError(plan, StreamMintSetupPlan.InvalidSetupPlan.selector);
        plan.chainId -= 1;
        plan.managerCodeHash = keccak256("wrong manager code");
        _expectPlanError(plan, StreamMintSetupPlan.InvalidSetupPlan.selector);
        plan.managerCodeHash = address(manager).codehash;
        require(
            executeSafe(
                operatorSafe,
                keys,
                address(manager),
                0,
                abi.encodeCall(manager.transferOwnership, (address(executor))),
                0
            ),
            "owner handoff"
        );
        _expectPlanError(plan, StreamMintSetupPlan.SetupOwnerChanged.selector);
    }

    function testEmptyDuplicateAndCrossPhaseNonceCollisionPlansAreRejected() public {
        StreamMintSetupPlan.Plan memory plan = _plan();
        StreamMintSetupPlan.Phase memory first = plan.phases[0];
        plan.phases = new StreamMintSetupPlan.Phase[](0);
        _expectPlanError(plan, StreamMintSetupPlan.InvalidSetupPlan.selector);
        plan.phases = new StreamMintSetupPlan.Phase[](2);
        plan.phases[0] = first;
        plan.phases[1] = _plan().phases[0];
        _expectPlanError(plan, StreamMintSetupPlan.InvalidSetupPlan.selector);
        plan.phases[1].phaseId = keccak256("second phase");
        _expectPlanError(plan, StreamMintSetupPlan.InvalidSetupPlan.selector);
    }

    function testSparsePriorNonceUseRequiresExplicitSavedPlanCorrection() public {
        StreamMintSetupPlan.Plan memory plan = _plan();
        uint256 initial = plan.phases[0].initialConsent.nonce;
        T.PolicyConsent memory unrelated =
            T.PolicyConsent(1, keccak256("other consent"), keccak256("other policy"));
        T.Authorization memory a =
            T.Authorization(initial + 1, uint64(block.timestamp + 1 days), "");
        a.signature = _artistProof(artists.policyConsentDigest(unrelated, a));
        artists.recordPolicyConsent(unrelated, a);
        require(
            artists.artistAuthorizationState(fixtureArtistId, 0, initial).nextUnusedNonce
                == initial,
            "sparse relay preserves earlier unused hint"
        );
        _submit(planner.prepare(plan));
        _submit(planner.prepare(plan));
        _expectPlanError(plan, StreamMintSetupPlan.SetupAuthorizationUnavailable.selector);
        uint256 actual = artists.artistAuthorizationState(fixtureArtistId, 0, 0).nextUnusedNonce;
        require(actual == initial + 2, "allocator skips previously consumed successor");
        plan.phases[0].executorConsent.nonce = actual;
        _submit(planner.prepare(plan));
        _submit(planner.prepare(plan));
        _submit(planner.prepare(plan));
        _complete(plan);
    }

    function testMultiplePhasesKeepFutureNoncesAndHandoffOnlyAfterBoth() public {
        StreamMintSetupPlan.Plan memory plan = _plan();
        StreamMintSetupPlan.Phase memory first = plan.phases[0];
        plan.phases = new StreamMintSetupPlan.Phase[](2);
        plan.phases[0] = first;
        plan.phases[1] = _plan().phases[0];
        plan.phases[1].phaseId = keccak256("second setup phase");
        plan.phases[1].initialConsent.nonce += 2;
        plan.phases[1].executorConsent.nonce += 2;
        for (uint256 i; i < 8; ++i) {
            StreamMintSetupPlan.NextCall memory next = planner.prepare(plan);
            require(uint256(next.step) == i % 4 + 1, "each phase has four confirmed steps");
            require(next.phaseId == plan.phases[i / 4].phaseId, "ordered phase progression");
            require(manager.owner() == address(operatorSafe), "handoff waits for every phase");
            _submit(next);
        }
        require(
            planner.prepare(plan).step == StreamMintSetupPlan.Step.HANDOFF_MANAGER,
            "all listed phases complete before handoff"
        );
        _submit(planner.prepare(plan));
        _complete(plan);
        require(artistSafe.nonce() == 4 && operatorSafe.nonce() == 5, "all Safe calls accounted");
        artists.requireMintConsent(
            1, plan.phases[1].phaseId, manager.phasePolicyHash(1, plan.phases[1].phaseId)
        );
    }

    function _plan() private view returns (StreamMintSetupPlan.Plan memory plan) {
        plan.chainId = block.chainid;
        plan.manager = address(manager);
        plan.managerCodeHash = address(manager).codehash;
        plan.core = address(core);
        plan.artistRegistry = address(artists);
        plan.artistRegistryCodeHash = address(artists).codehash;
        plan.governanceExecutor = address(executor);
        plan.initialOwner = address(operatorSafe);
        plan.phases = new StreamMintSetupPlan.Phase[](1);
        StreamMintSetupPlan.Phase memory f;
        f.collectionId = 1;
        f.phaseId = SETUP_PHASE;
        f.artist = address(artistSafe);
        f.artistId = fixtureArtistId;
        f.bindingHash = artists.attribution(1).nominationHash;
        f.executor = address(sale);
        f.config = IStreamMintManager.MintPhaseConfig(
            false, 0, 0, 1, keccak256("operator phase"), keccak256("operator metadata")
        );
        f.counterIds = new bytes32[](1);
        f.counterIds[0] = keccak256("supply");
        f.counters = new IStreamMintManager.MintCounterConfig[](1);
        f.counters[0] = IStreamMintManager.MintCounterConfig(
            true,
            IStreamMintManager.CounterKeyMode.CONSTANT,
            IStreamMintLedger.CounterCapMode.STATIC,
            IStreamMintLedger.CounterDeltaMode.STATIC,
            10,
            1,
            keccak256("operator counter")
        );
        uint256 hint = artists.artistAuthorizationState(fixtureArtistId, 0, 0).nextUnusedNonce;
        // This fresh fixture has no sparse uses after hint; the separate sparse test challenges it.
        require(
            !artists.artistAuthorizationState(fixtureArtistId, 0, hint + 1).nonceConsumed,
            "fixture successor is unused"
        );
        f.initialConsent = T.Authorization(hint, uint64(block.timestamp + 7 days), "");
        f.executorConsent = T.Authorization(hint + 1, uint64(block.timestamp + 7 days), "");
        plan.phases[0] = f;
    }

    function _submit(StreamMintSetupPlan.NextCall memory next) private {
        require(next.value == 0 && next.target != address(0), "plain zero-value CALL");
        OfficialSafe signer = next.actor == address(artistSafe) ? artistSafe : operatorSafe;
        require(next.actor == address(signer), "expected actor");
        require(
            executeSafe(signer, keys, next.target, next.value, next.data, 0),
            "actual Safe target execution"
        );
    }

    function _complete(StreamMintSetupPlan.Plan memory plan) private view {
        StreamMintSetupPlan.NextCall memory next = planner.prepare(plan);
        require(
            next.step == StreamMintSetupPlan.Step.COMPLETE && next.target == address(0)
                && next.data.length == 0 && manager.owner() == address(executor),
            "confirmed completion"
        );
        artists.requireMintConsent(1, SETUP_PHASE, manager.phasePolicyHash(1, SETUP_PHASE));
    }

    function _expectPlanError(StreamMintSetupPlan.Plan memory plan, bytes4 selector) private {
        (bool ok, bytes memory reason) =
            address(planner).staticcall(abi.encodeCall(planner.prepare, (plan)));
        require(!ok && reason.length >= 4 && bytes4(reason) == selector, "exact planner error");
    }
}
