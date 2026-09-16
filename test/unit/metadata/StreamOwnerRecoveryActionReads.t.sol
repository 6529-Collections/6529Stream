// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../../../smart-contracts/domains/records/StreamOwnerRecoveryActionReads.sol";

interface OwnerActionVm {
    function warp(uint256 time) external;
    function chainId(uint256 id) external;
    function etch(address target, bytes calldata code) external;
    function cool(address target) external;
}

/// @dev Raw target/Executor/Core boundaries. They assert no actual governance or route authority.
contract OwnerActionReadBoundary {
    mapping(bytes32 => bytes) private answers;

    function answer(bytes calldata input, bytes calldata output) external {
        answers[keccak256(input)] = output;
    }

    fallback() external {
        bytes memory data = answers[keccak256(msg.data)];
        assembly ("memory-safe") { return(add(data, 32), mload(data)) }
    }
}

contract OwnerActionReadHost {
    StreamOwnerRecoveryActionReads.Config private config;
    StreamOwnerRecoveryActionReads.Binding private saved;

    constructor(address core, address executor) {
        config = StreamOwnerRecoveryActionReads.Config(
            core, core.codehash, executor, executor.codehash, address(this), 150000, 2000000
        );
    }

    function admit(
        bytes32 id,
        GovernanceCall[] memory calls,
        StreamFinalityRecoveryRequest memory request
    ) external view returns (StreamOwnerRecoveryActionReads.Binding memory) {
        return StreamOwnerRecoveryActionReads.admit(config, id, calls, request);
    }

    function keep(
        bytes32 id,
        GovernanceCall[] memory calls,
        StreamFinalityRecoveryRequest memory request
    ) external {
        saved = StreamOwnerRecoveryActionReads.admit(config, id, calls, request);
    }

    function eligible(bytes32 id, StreamFinalityScope memory scope, bytes32 manifest)
        external
        view
        returns (bool)
    {
        return StreamOwnerRecoveryActionReads.eligibility(config, saved, id, scope, manifest);
    }

    function configured(
        StreamOwnerRecoveryActionReads.Config memory c,
        bytes32 id,
        GovernanceCall[] memory calls,
        StreamFinalityRecoveryRequest memory request
    ) external view returns (StreamOwnerRecoveryActionReads.Binding memory) {
        return StreamOwnerRecoveryActionReads.admit(c, id, calls, request);
    }

    function configuration() external view returns (StreamOwnerRecoveryActionReads.Config memory) {
        return config;
    }
}

contract StreamOwnerRecoveryActionReadsTest {
    OwnerActionVm private constant vm =
        OwnerActionVm(address(uint160(uint256(keccak256("hevm cheat code")))));
    OwnerActionReadBoundary private core;
    OwnerActionReadBoundary private executor;
    OwnerActionReadBoundary private target;
    OwnerActionReadHost private host;
    StreamFinalityRecoveryRequest private request;
    GovernanceCall[] private calls;
    bytes32 private constant ID = keccak256("scheduled action id");
    bytes32 private constant ORIGINAL = keccak256("original finality record");
    bytes32 private constant OLD = keccak256("old state");
    bytes32 private constant NEW = keccak256("new state");

    function setUp() public {
        vm.warp(1000);
        core = new OwnerActionReadBoundary();
        executor = new OwnerActionReadBoundary();
        target = new OwnerActionReadBoundary();
        host = new OwnerActionReadHost(address(core), address(executor));
        request.scope = StreamFinalityScope(StreamFinalityScopeType.TOKEN, 1, 23, 0);
        request.expectedOriginalFinalityRecordHash = ORIGINAL;
        request.expectedPredecessorRecoveryId = keccak256("predecessor");
        request.expectedOldRouteHash = keccak256("old route");
        request.replacementRoute = StreamFinalityComponentExpectation(
            keccak256("renderer"),
            address(core),
            0x12345678,
            address(core).codehash,
            keccak256("version"),
            keccak256("route manifest"),
            keccak256("data")
        );
        request.recoveryManifest = StreamFinalityManifestRef(
            "urn:manifest",
            keccak256("urn:manifest"),
            keccak256("manifest"),
            keccak256("schema"),
            keccak256("canon")
        );
        request.reasonHash = keccak256("reason");
        request.reasonURI = "urn:reason";
        calls.push(
            GovernanceCall(
                address(core),
                0,
                0x11223344,
                keccak256("first data"),
                keccak256("first scope"),
                0,
                keccak256("first new")
            )
        );
        calls.push(_recovery(request));
        calls.push(
            GovernanceCall(
                address(core),
                0,
                0x44332211,
                keccak256("tail data"),
                keccak256("tail scope"),
                0,
                keccak256("tail new")
            )
        );
        _graph();
        _intent(request);
        _action(calls, 1, 2, 2000, 3000);
    }

    function _graph() private {
        target.answer(abi.encodeWithSignature("core()"), abi.encode(address(core)));
        target.answer(
            abi.encodeWithSignature("governanceAuthority()"), abi.encode(address(executor))
        );
        target.answer(abi.encodeWithSignature("ownerEvidence()"), abi.encode(address(host)));
        core.answer(
            abi.encodeCall(
                IStreamCorePointers.getSatellitePointer, (keccak256("ARTWORK_FINALITY_RECOVERY"))
            ),
            abi.encode(
                address(target),
                address(target).codehash,
                false,
                keccak256("STREAM_ARTWORK_FINALITY_RECOVERY"),
                type(IStreamArtworkFinalityRecovery).interfaceId,
                address(core),
                uint8(0),
                keccak256("module"),
                keccak256("deployment"),
                uint64(1)
            )
        );
    }

    function _scope(StreamFinalityScope memory s) private view returns (bytes32) {
        return keccak256(
            abi.encode(
                keccak256("6529STREAM_FINALITY_RECOVERY_SCOPE_V1"),
                block.chainid,
                address(target),
                s
            )
        );
    }

    function _recovery(StreamFinalityRecoveryRequest memory r)
        private
        view
        returns (GovernanceCall memory)
    {
        return GovernanceCall(
            address(target),
            0,
            IStreamArtworkFinalityRecovery.executeFinalityRecovery.selector,
            keccak256(abi.encodeCall(IStreamArtworkFinalityRecovery.executeFinalityRecovery, (r))),
            _scope(r.scope),
            OLD,
            NEW
        );
    }

    function _hash(GovernanceCall[] memory c) private pure returns (bytes32) {
        return keccak256(
            abi.encode(
                bytes32(0x10f09566fb70f7947b61639c2a53b3aec872069a8b46edd08ba14eb2b5942b70), c
            )
        );
    }

    function _action(
        GovernanceCall[] memory c,
        uint256 status,
        uint256 cls,
        uint256 before_,
        uint256 expiry
    ) private {
        executor.answer(
            abi.encodeCall(IStreamGovernanceActionFacts.governanceActionFacts, (ID)),
            abi.encode(status, cls, _hash(c), before_, expiry)
        );
    }

    function _intent(StreamFinalityRecoveryRequest memory r) private {
        target.answer(
            abi.encodeCall(
                IStreamArtistRecoveryIntent.requireArtistRecoveryIntent,
                (r.scope, ORIGINAL, r.recoveryManifest.contentHash)
            ),
            abi.encode(_scope(r.scope), OLD, NEW, keccak256(abi.encode(r)))
        );
    }

    function _fails(GovernanceCall[] memory c, StreamFinalityRecoveryRequest memory r)
        private
        view
    {
        (bool ok,) = address(host).staticcall(abi.encodeCall(host.admit, (ID, c, r)));
        require(!ok, "reject witness");
    }

    function _healthy() private view {
        require(host.admit(ID, calls, request).target == address(target), "same proof healthy");
    }

    function _eligible() private view returns (bool) {
        return host.eligible(ID, request.scope, request.recoveryManifest.contentHash);
    }

    function _execution(uint256 enabled, bytes32 id, uint256 cls, bytes32 s, bytes32 o, bytes32 n)
        private
    {
        executor.answer(
            abi.encodeCall(IStreamGovernedParameterAuthority.currentAction, ()),
            abi.encode(enabled, id, cls, s, o, n)
        );
    }

    function testCompleteMiddleCallBindsEveryReturnedFieldBeforeDelay() public {
        StreamOwnerRecoveryActionReads.Binding memory b = host.admit(ID, calls, request);
        require(
            keccak256(abi.encode(b))
                == keccak256(
                    abi.encode(
                        address(target),
                        address(target).codehash,
                        _scope(request.scope),
                        OLD,
                        NEW,
                        keccak256(abi.encode(request)),
                        request.recoveryManifest.contentHash,
                        _hash(calls),
                        uint64(3000),
                        ORIGINAL
                    )
                ),
            "ten complete words"
        );
        host.keep(ID, calls, request);
        require(_eligible(), "notice before execution delay");
    }

    function testWholeArraySubstitutionReorderAndTailMutationReject() public {
        GovernanceCall[] memory c = calls;
        c[2].callDataHash = keccak256("same first header wrong tail");
        _fails(c, request);
        c = calls;
        (c[0], c[2]) = (c[2], c[0]);
        _fails(c, request);
        c = new GovernanceCall[](2);
        c[0] = calls[0];
        c[1] = calls[1];
        _fails(c, request);
        _healthy();
    }

    function testAuthenticatedDuplicateRecoveryAndMissingRecoveryReject() public {
        GovernanceCall[] memory c = calls;
        c[2] = c[1];
        _action(c, 1, 2, 2000, 3000);
        _fails(c, request);
        c = calls;
        c[1].selector = 0x99887766;
        _action(c, 1, 2, 2000, 3000);
        _fails(c, request);
        _action(calls, 1, 2, 2000, 3000);
        _healthy();
    }

    function testAuthenticatedRecoveryValueAndDataHashReject() public {
        GovernanceCall[] memory c = calls;
        c[1].value = 1;
        _action(c, 1, 2, 2000, 3000);
        _fails(c, request);
        c = calls;
        c[1].callDataHash = keccak256("wrong exact request calldata");
        _action(c, 1, 2, 2000, 3000);
        _fails(c, request);
        _action(calls, 1, 2, 2000, 3000);
        _healthy();
    }

    function testOriginalRequestMutationCannotBecomeRegisteredIntent() public {
        StreamFinalityRecoveryRequest memory r = request;
        r.reasonURI = "urn:changed";
        _fails(calls, r);
        GovernanceCall[] memory c = calls;
        c[1] = _recovery(r);
        _action(c, 1, 2, 2000, 3000);
        _fails(c, r);
        _action(calls, 1, 2, 2000, 3000);
        _healthy();
    }

    function testEveryStaticRequestWordAndBothStringsRemainCommitted() public view {
        bytes memory encoded = abi.encode(request);
        // Independent exact calldata commitment catches every byte, including dynamic heads/tails.
        bytes memory callData =
            abi.encodeCall(IStreamArtworkFinalityRecovery.executeFinalityRecovery, (request));
        require(keccak256(callData) == calls[1].callDataHash, "canonical original");
        for (uint256 i = 4; i < callData.length; i += 32) {
            bytes1 original = callData[i];
            callData[i] = bytes1(uint8(original) ^ 1);
            require(keccak256(callData) != calls[1].callDataHash, "each changed word committed");
            callData[i] = original;
        }
        require(
            keccak256(encoded) == host.admit(ID, calls, request).requestHash,
            "complete request independent hash"
        );
    }

    function testCancelledVetoedExpiredNoneAndExecutedRejectAdmission() public {
        for (uint256 i; i < 6; ++i) {
            if (i == 1) continue;
            _action(calls, i, 2, 2000, 3000);
            _fails(calls, request);
        }
        _action(calls, 1, 2, 2000, 3000);
        _healthy();
    }

    function testWrongClassZeroExpiryAndReversedWindowReject() public {
        for (uint256 i; i < 7; ++i) {
            if (i == 2) continue;
            _action(calls, 1, i, 2000, 3000);
            _fails(calls, request);
        }
        _action(calls, 1, 2, 0, 0);
        _fails(calls, request);
        _action(calls, 1, 2, 3001, 3000);
        _fails(calls, request);
        _action(calls, 1, 2, 2000, 3000);
        _healthy();
    }

    function testExactExpiryEqualityAndStrictLaterFailure() public {
        host.keep(ID, calls, request);
        vm.warp(3000);
        _healthy();
        require(_eligible(), "expiry equality");
        vm.warp(3001);
        _fails(calls, request);
        require(!_eligible(), "strict later expiry");
    }

    function testZeroActionAndUnknownCallHashReject() public {
        (bool ok,) =
            address(host).staticcall(abi.encodeCall(host.admit, (bytes32(0), calls, request)));
        require(!ok, "zero action");
        executor.answer(
            abi.encodeCall(IStreamGovernanceActionFacts.governanceActionFacts, (ID)),
            abi.encode(uint256(1), uint256(2), bytes32(0), uint256(2000), uint256(3000))
        );
        _fails(calls, request);
        _action(calls, 1, 2, 2000, 3000);
        _healthy();
    }

    function testMalformedActionWidthsAndReturnLengthsRejectThenRetry() public {
        bytes memory input =
            abi.encodeCall(IStreamGovernanceActionFacts.governanceActionFacts, (ID));
        uint256[4] memory indices = [uint256(0), 1, 3, 4];
        uint256[4] memory invalid =
            [uint256(6), 256, uint256(type(uint64).max) + 1, uint256(type(uint64).max) + 1];
        for (uint256 i; i < 4; ++i) {
            bytes memory raw =
                abi.encode(uint256(1), uint256(2), _hash(calls), uint256(2000), uint256(3000));
            uint256 at = indices[i];
            uint256 value = invalid[i];
            assembly ("memory-safe") { mstore(add(add(raw, 32), mul(at, 32)), value) }
            executor.answer(input, raw);
            _fails(calls, request);
        }
        uint256[4] memory lengths = [uint256(0), 32, 159, 65536];
        for (uint256 i; i < 4; ++i) {
            executor.answer(input, new bytes(lengths[i]));
            _fails(calls, request);
        }
        _action(calls, 1, 2, 2000, 3000);
        _healthy();
    }

    function testReciprocalTargetGraphAndCanonicalAddressReject() public {
        bytes4[3] memory selectors = [
            bytes4(keccak256("core()")),
            bytes4(keccak256("governanceAuthority()")),
            bytes4(keccak256("ownerEvidence()"))
        ];
        for (uint256 i; i < 3; ++i) {
            target.answer(abi.encodeWithSelector(selectors[i]), abi.encode(address(0x1234)));
            _fails(calls, request);
            _graph();
            target.answer(abi.encodeWithSelector(selectors[i]), abi.encode(uint256(1) << 160));
            _fails(calls, request);
            _graph();
        }
        _healthy();
    }

    function testIntentAllFourWordsExactAndOversizedReturnReject() public {
        bytes memory input = abi.encodeCall(
            IStreamArtistRecoveryIntent.requireArtistRecoveryIntent,
            (request.scope, ORIGINAL, request.recoveryManifest.contentHash)
        );
        for (uint256 i; i < 4; ++i) {
            bytes memory raw =
                abi.encode(_scope(request.scope), OLD, NEW, keccak256(abi.encode(request)));
            assembly ("memory-safe") { mstore(add(add(raw, 32), mul(i, 32)), 0) }
            target.answer(input, raw);
            _fails(calls, request);
        }
        target.answer(input, new bytes(160));
        _fails(calls, request);
        _intent(request);
        _healthy();
    }

    function testScopeShapeCollectionTokenAndScopedClosedFields() public {
        for (uint256 i; i < 5; ++i) {
            StreamFinalityRecoveryRequest memory r = request;
            r.scope = StreamFinalityScope(
                StreamFinalityScopeType(i),
                1,
                i == 1 ? 23 : 0,
                i > 1 ? keccak256("scope") : bytes32(0)
            );
            GovernanceCall[] memory c = calls;
            c[1] = _recovery(r);
            _intent(r);
            _action(c, 1, 2, 2000, 3000);
            require(
                host.admit(ID, c, r).scopeHash == _scope(r.scope),
                "all supported shapes passed to target"
            );
            r.scope.collectionId = 0;
            c[1] = _recovery(r);
            _intent(r);
            _action(c, 1, 2, 2000, 3000);
            _fails(c, r);
        }
    }

    function testClosedCollectionAndTokenInactiveScopeReject() public {
        StreamFinalityRecoveryRequest memory r = request;
        r.scope.scopeId = keccak256("inactive token scope");
        GovernanceCall[] memory c = calls;
        c[1] = _recovery(r);
        _intent(r);
        _action(c, 1, 2, 2000, 3000);
        _fails(c, r);
        r.scope = StreamFinalityScope(StreamFinalityScopeType.COLLECTION, 1, 23, 0);
        c[1] = _recovery(r);
        _intent(r);
        _action(c, 1, 2, 2000, 3000);
        _fails(c, r);
    }

    function testSavedRuntimePinsCoreExecutorAndTargetRejectDrift() public {
        host.keep(ID, calls, request);
        address[3] memory targets = [address(core), address(executor), address(target)];
        for (uint256 i; i < 3; ++i) {
            bytes memory oldCode = targets[i].code;
            vm.etch(targets[i], hex"60006000fd");
            (bool ok,) = address(host)
                .staticcall(
                    abi.encodeCall(
                        host.eligible, (ID, request.scope, request.recoveryManifest.contentHash)
                    )
                );
            require(!ok, "runtime drift");
            vm.etch(targets[i], oldCode);
            require(_eligible(), "restore exact binding");
        }
    }

    function testExecutedExactActiveContextAndClosedHistoricalFalse() public {
        host.keep(ID, calls, request);
        _action(calls, 3, 2, 2000, 3000);
        vm.warp(2000);
        _execution(1, ID, 2, _scope(request.scope), OLD, NEW);
        require(_eligible(), "active companion callback");
        _execution(0, 0, 0, 0, 0, 0);
        require(!_eligible(), "closed historical context");
        // No live route read is needed to report historical ineligibility.
        target.answer(abi.encodeWithSignature("core()"), bytes(""));
        require(!_eligible(), "closed context before target read");
    }

    function testExecutedWrongEachContextWordAndBeforeDelayFalse() public {
        host.keep(ID, calls, request);
        _action(calls, 3, 2, 2000, 3000);
        _execution(1, ID, 2, _scope(request.scope), OLD, NEW);
        require(!_eligible(), "before actual execution delay");
        vm.warp(2000);
        bytes memory input = abi.encodeCall(IStreamGovernedParameterAuthority.currentAction, ());
        for (uint256 i; i < 6; ++i) {
            bytes memory raw = abi.encode(true, ID, uint8(2), _scope(request.scope), OLD, NEW);
            assembly ("memory-safe") { mstore(add(add(raw, 32), mul(i, 32)), 0) }
            executor.answer(input, raw);
            require(!_eligible(), "each context field exact");
        }
        _execution(1, ID, 2, _scope(request.scope), OLD, NEW);
        require(_eligible(), "same context retry");
    }

    function testMalformedExecutionBoolClassAndLengthReject() public {
        host.keep(ID, calls, request);
        _action(calls, 3, 2, 2000, 3000);
        vm.warp(2000);
        _execution(2, ID, 2, _scope(request.scope), OLD, NEW);
        (bool ok,) = address(host)
            .staticcall(
                abi.encodeCall(
                    host.eligible, (ID, request.scope, request.recoveryManifest.contentHash)
                )
            );
        require(!ok, "noncanonical bool");
        _execution(1, ID, 256, _scope(request.scope), OLD, NEW);
        (ok,) = address(host)
            .staticcall(
                abi.encodeCall(
                    host.eligible, (ID, request.scope, request.recoveryManifest.contentHash)
                )
            );
        require(!ok, "noncanonical class");
        executor.answer(
            abi.encodeCall(IStreamGovernedParameterAuthority.currentAction, ()), new bytes(224)
        );
        (ok,) = address(host)
            .staticcall(
                abi.encodeCall(
                    host.eligible, (ID, request.scope, request.recoveryManifest.contentHash)
                )
            );
        require(!ok, "extra return word");
    }

    function testSavedActionHashAndExpiryChangesReturnFalse() public {
        host.keep(ID, calls, request);
        _action(calls, 1, 2, 2000, 3001);
        require(!_eligible(), "expiry differs");
        GovernanceCall[] memory c = calls;
        c[2].callDataHash = keccak256("changed tail");
        _action(c, 1, 2, 2000, 3000);
        require(!_eligible(), "complete call hash differs");
        _action(calls, 1, 2, 2000, 3000);
        require(_eligible(), "identical proof retry");
    }

    function testWrongManifestScopeChainAndZeroOriginalReject() public {
        host.keep(ID, calls, request);
        (bool ok,) = address(host)
            .staticcall(
                abi.encodeCall(host.eligible, (ID, request.scope, keccak256("other manifest")))
            );
        require(!ok, "manifest join");
        StreamFinalityScope memory s = request.scope;
        s.tokenId++;
        (ok,) = address(host)
            .staticcall(
                abi.encodeCall(host.eligible, (ID, s, request.recoveryManifest.contentHash))
            );
        require(!ok, "scope join");
        uint256 chain = block.chainid;
        vm.chainId(chain + 1);
        (ok,) = address(host)
            .staticcall(
                abi.encodeCall(
                    host.eligible, (ID, request.scope, request.recoveryManifest.contentHash)
                )
            );
        require(!ok, "chain scope domain");
        vm.chainId(chain);
        StreamFinalityRecoveryRequest memory r = request;
        r.expectedOriginalFinalityRecordHash = 0;
        GovernanceCall[] memory c = calls;
        c[1] = _recovery(r);
        _action(c, 1, 2, 2000, 3000);
        _fails(c, r);
    }

    function testFixedHostContextAndInvalidConfiguredCapsReject() public {
        StreamOwnerRecoveryActionReads.Config memory c = host.configuration();
        c.ownerEvidence = address(this);
        (bool ok,) =
            address(host).staticcall(abi.encodeCall(host.configured, (c, ID, calls, request)));
        require(!ok, "foreign host");
        c = host.configuration();
        c.readGas = 0;
        (ok,) = address(host).staticcall(abi.encodeCall(host.configured, (c, ID, calls, request)));
        require(!ok, "zero cap");
        c.readGas = uint256(type(uint64).max) + 1;
        (ok,) = address(host).staticcall(abi.encodeCall(host.configured, (c, ID, calls, request)));
        require(!ok, "overflow cap");
        c = host.configuration();
        (ok,) = address(StreamOwnerRecoveryActionReads)
            .staticcall(
                abi.encodeWithSelector(
                    StreamOwnerRecoveryActionReads.admit.selector, c, ID, calls, request
                )
            );
        require(!ok, "direct library context");
        _healthy();
    }

    function testInsufficientParentAndColdExactSameProofRetry() public {
        bytes memory data = abi.encodeCall(host.admit, (ID, calls, request));
        (bool ok,) = address(host).staticcall{ gas: 100000 }(data);
        require(!ok, "insufficient parent");
        vm.cool(address(core));
        vm.cool(address(executor));
        vm.cool(address(target));
        _healthy();
    }

    function testCorePointerAllIdentityAndCanonicalFieldsChecked() public {
        bytes memory input = abi.encodeCall(
            IStreamCorePointers.getSatellitePointer, (keccak256("ARTWORK_FINALITY_RECOVERY"))
        );
        uint256[10] memory values = [
            uint256(uint160(address(123))),
            uint256(123),
            uint256(2),
            uint256(123),
            uint256(1),
            uint256(1) << 160,
            uint256(4),
            uint256(0),
            uint256(0),
            uint256(type(uint64).max) + 1
        ];
        for (uint256 i; i < 10; ++i) {
            if (i == 7 || i == 8) continue; // provenance words are not readiness gates
            bytes memory raw = abi.encode(
                address(target),
                address(target).codehash,
                false,
                keccak256("STREAM_ARTWORK_FINALITY_RECOVERY"),
                type(IStreamArtworkFinalityRecovery).interfaceId,
                address(core),
                uint8(0),
                keccak256("module"),
                keccak256("deployment"),
                uint64(1)
            );
            uint256 value = values[i];
            assembly ("memory-safe") { mstore(add(add(raw, 32), mul(i, 32)), value) }
            core.answer(input, raw);
            _fails(calls, request);
        }
        core.answer(input, new bytes(352));
        _fails(calls, request);
        _graph();
        _healthy();
    }

    function testCoherentInitialTargetSubstitutionCannotAdoptNewRuntime() public {
        bytes memory oldCode = address(target).code;
        // Same dispatch and storage getters remain executable; unreachable suffix changes runtime.
        vm.etch(address(target), bytes.concat(oldCode, hex"00"));
        _fails(calls, request);
        vm.etch(address(target), oldCode);
        _healthy();
    }

    function testEligibilityDoesNotRecurseIntoFailedIntentProducer() public {
        host.keep(ID, calls, request);
        target.answer(
            abi.encodeCall(
                IStreamArtistRecoveryIntent.requireArtistRecoveryIntent,
                (request.scope, ORIGINAL, request.recoveryManifest.contentHash)
            ),
            bytes("")
        );
        require(_eligible(), "saved notice-action liveness survives unavailable preparation");
        _fails(calls, request); // new notice admission still requires complete actual preparation
        _action(calls, 3, 2, 2000, 3000);
        vm.warp(2000);
        _execution(1, ID, 2, _scope(request.scope), OLD, NEW);
        require(_eligible(), "active owner callback does not recursively prepare");
    }

    function testAdmissionBudgetIsSeparateFromLightweightEligibility() public {
        StreamOwnerRecoveryActionReads.Config memory c = host.configuration();
        c.intentReadGas = 0;
        (bool ok,) =
            address(host).staticcall(abi.encodeCall(host.configured, (c, ID, calls, request)));
        require(!ok, "zero admission cap");
        c.intentReadGas = uint256(type(uint64).max) + 1;
        (ok,) = address(host).staticcall(abi.encodeCall(host.configured, (c, ID, calls, request)));
        require(!ok, "overflow admission cap");
        host.keep(ID, calls, request);
        (ok,) = address(host).staticcall{ gas: 500000 }(
            abi.encodeCall(host.eligible, (ID, request.scope, request.recoveryManifest.contentHash))
        );
        require(ok, "eligibility never requires two-million parent admission reserve");
    }
}
