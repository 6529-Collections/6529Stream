// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamScopedPolicyPublicationGraphTypesV2 as CapacityGraph446
} from "../../../smart-contracts/interfaces/stream/finality/StreamScopedPolicyPublicationGraphTypesV2.sol";
import {
    StreamScopedPolicyPublicationCheckpointDeploymentV2 as CapacityDeploy446
} from "../../../smart-contracts/domains/finality/StreamScopedPolicyPublicationCheckpointDeploymentV2.sol";
import {
    LeafManifestVm as CapacityCreateVm446
} from "../../helpers/scoped-preservation-boundaries/StreamContentLeafManifestVm.sol";

import "../../helpers/ScopedPolicyContentFixtureV2.sol";

contract StreamScopedPolicyContentCheckpointV2Test is ScopedPolicyContentFixtureV2 {
    function testCapacityScopedCheckpointConstructorKeepsHostCreateArgumentsAndIndependentPlan()
        public
    {
        _scopedFixture(1, true);
        StreamFinalityScope memory scope = _scopedScope(2);
        (Checkpoint original, bytes32 selection) = _scopedCapture(scope);
        CapacityGraph446.Recipe memory r;
        CapacityGraph446.Graph memory g;
        r.targets[1] = address(scopedSelections);
        r.targets[3] = address(executor);
        r.checkpointGas[0] = _scopedGas("STATIC_CONTENT_READ_GAS", 8000000, 2);
        r.checkpointGas[1] = _scopedGas("STATIC_CONTENT_RENDER_GAS", 16000000, 2);
        g.sourceSet = original.entropySourceSet();
        g.children[0] = original.terminalReadiness();
        uint64 nonce = CapacityCreateVm446(address(vm)).getNonce(address(this));
        Checkpoint child = Checkpoint(CapacityDeploy446.deploy(r, g));
        require(
            address(child)
                    == CapacityCreateVm446(address(vm)).computeCreateAddress(address(this), nonce)
                && CapacityCreateVm446(address(vm)).getNonce(address(this)) == nonce + 1,
            "same host and one CREATE"
        );
        require(
            child.core() == address(core) && child.metadataRouter() == address(router)
                && child.selectionCheckpoint() == address(scopedSelections)
                && child.entropySourceSet() == g.sourceSet
                && child.terminalReadiness() == g.children[0]
                && child.governanceAuthority() == address(executor),
            "all fixed constructor arguments"
        );
        require(
            child.sourceFactory() == original.sourceFactory()
                && child.factoryDependenciesHash() == original.factoryDependenciesHash(),
            "original actual factory binding"
        );
        bytes32 oldId = original.begin(selection, keccak256("capacity constructor"));
        bytes32 id = child.begin(selection, keccak256("capacity constructor"));
        require(id != oldId, "host is part of checkpoint domain");
        child.append(id, _scopedPayload(scope));
        _assertRoots(child, id);
        require(
            child.requireCurrentCheckpoint(id).nextIndex == 2
                && original.checkpoint(oldId).nextIndex == 0,
            "genuine append with independent storage"
        );
    }

    function testCapacityScopedObservationChecksLastRowAndPreservesReturnedValues() public {
        _scopedFixture(1, true);
        StreamFinalityScope memory scope = _scopedScope(2);
        (Checkpoint host, bytes32 selection) = _scopedCapture(scope);
        bytes32 id = host.begin(selection, keccak256("capacity all-row observation"));
        O.Payload[] memory payload = _scopedPayload(scope);
        bytes32 inputHash = keccak256(abi.encode(payload));
        host.append(id, payload);
        O.Output memory first = host.outputAt(id, 0);
        O.Output memory last = host.outputAt(id, 1);
        require(
            first.entropy.terminal && first.terminalAdmissionHash != 0 && last.entropy.finalized
                && last.entropy.seed == scopedFinalizedSeed && last.terminalAdmissionHash == 0,
            "both original entropy branches survive linked return"
        );
        require(
            last.leaf.metadataHash == keccak256(bytes(router.tokenJSON(92)))
                && last.leaf.animationHash == keccak256(payload[1].animation)
                && last.leaf.imageHash == keccak256(payload[1].image)
                && last.leaf.tokenDataHash == keccak256(core.tokenData(92))
                && last.htmlHash == last.leaf.animationHash,
            "complete returned last-row values"
        );
        bytes32 saved = keccak256(abi.encode(host.checkpoint(id), first, last));
        string memory html = router.tokenHTML(92);
        StaticRouteVm(address(vm))
            .mockCall(
                address(router),
                abi.encodeCall(router.tokenHTML, (uint256(92))),
                abi.encode(string(abi.encodePacked(html, " ")))
            );
        vm.expectRevert(abi.encodeWithSelector(O.StaticContentChanged.selector, id));
        host.requireCurrentCheckpoint(id);
        require(
            keccak256(abi.encode(host.checkpoint(id), host.outputAt(id, 0), host.outputAt(id, 1)))
                == saved,
            "last-row drift cannot rewrite either historical row"
        );
        require(keccak256(abi.encode(payload)) == inputHash, "input array remains unchanged");
        StaticRouteVm(address(vm))
            .mockCall(
                address(router), abi.encodeCall(router.tokenHTML, (uint256(92))), abi.encode(html)
            );
        _assertRoots(host, id);
        require(
            host.requireCurrentCheckpoint(id).nextIndex == 2,
            "all original bytes restore currentness"
        );
    }

    function testCapacityScopedObservationRenderPreflightRollsBackEntireBatch() public {
        _scopedFixture(1, true);
        StreamFinalityScope memory scope = _scopedScope(2);
        (Checkpoint host, bytes32 selection) = _scopedCapture(scope);
        bytes32 id = host.begin(selection, keccak256("capacity render budget"));
        O.Payload[] memory payload = _scopedPayload(scope);
        bytes32 before = keccak256(abi.encode(host.checkpoint(id)));
        uint256 cap = host.gasParameter(keccak256("6529STREAM_GGP_STATIC_CONTENT_RENDER_GAS"));
        (bool ok, bytes memory failure) =
            address(host).call{ gas: cap }(abi.encodeCall(host.append, (id, payload)));
        require(
            !ok && failure.length == 68, "typed preflight refusal, not dependency unavailability"
        );
        bytes4 selector;
        uint256 available;
        uint256 required;
        assembly ("memory-safe") {
            selector := mload(add(failure, 32))
            available := mload(add(failure, 36))
            required := mload(add(failure, 68))
        }
        require(
            selector == O.StaticContentParentGas.selector && required == cap + cap / 63 + 100000
                && available <= required,
            "original exact render cap and parent margin"
        );
        require(keccak256(abi.encode(host.checkpoint(id))) == before, "plan and frontier rollback");
        vm.expectRevert(abi.encodeWithSelector(O.StaticContentIndex.selector, uint256(0)));
        host.outputAt(id, 0);
        host.append(id, payload);
        _assertRoots(host, id);
        require(host.requireCurrentCheckpoint(id).nextIndex == 2, "original complete batch retries");
    }

    function testScopedPolicyAllThreeCanonicalScopesUseActualCreatedSourceSets() public {
        _scopedFixture(1, true);
        for (uint8 kind = 1; kind <= 3; ++kind) {
            StreamFinalityScope memory scope = _scopedScope(kind);
            (Checkpoint host, bytes32 selection) = _scopedCapture(scope);
            bytes32 id = host.begin(selection, keccak256("same salt"));
            host.append(id, _scopedPayload(scope));
            O.Plan memory p = host.requireCurrentCheckpoint(id);
            SourceSet set = SourceSet(host.entropySourceSet());
            require(keccak256(abi.encode(p.scope)) == keccak256(abi.encode(scope)));
            require(p.tokenCount == (kind == 1 ? 1 : 2) && p.nextIndex == p.tokenCount);
            require(
                set.factory() == address(scopedFactory)
                    && host.sourceFactory() == address(scopedFactory)
            );
            require(host.factoryDependenciesHash() == keccak256(abi.encode(_scopedDependencies())));
            require(set.inventoryPlan() == scopedFactory.currentInventoryPlan(scope));
            require(scopedFactory.requireCurrentRoute(scope).component == address(set));
            require(
                p.inventoryHash == set.originalInventoryHash()
                    && p.policyChainHash == set.originalPolicyChainHash()
            );
            require(set.sourceCount() == (kind == 1 ? 1 : 2));
            _assertRoots(host, id);
            require(host.begin(selection, keccak256("same salt")) == id);
        }
    }

    function testScopedPolicyDisabledAndFinalizedRowsKeepDistinctNativeEvidence() public {
        _scopedFixture(1, true);
        StreamFinalityScope memory scope = _scopedScope(2);
        (Checkpoint host, bytes32 selection) = _scopedCapture(scope);
        bytes32 id = host.begin(selection, 0);
        host.append(id, _scopedPayload(scope));
        O.Output memory terminal = host.outputAt(id, 0);
        O.Output memory random = host.outputAt(id, 1);
        require(terminal.entropy.coordinator == address(terminalCoordinator));
        require(
            terminal.entropy.status == 1 && terminal.entropy.mode == 0 && terminal.entropy.terminal
                && !terminal.entropy.finalized && terminal.entropy.seed == 0
                && terminal.terminalAdmissionHash != 0
        );
        require(random.entropy.coordinator == address(randomCoordinator));
        require(
            random.entropy.status == 5 && random.entropy.mode == 2 && !random.entropy.terminal
                && random.entropy.finalized && random.entropy.seed == scopedFinalizedSeed
                && random.terminalAdmissionHash == 0
        );
        EP.PolicyRecord memory policy = EP(address(terminalCoordinator)).collectionEntropyPolicy(1);
        require(
            policy.explicitPolicy && policy.frozen
                && terminal.entropy.policyHash == policy.policyHash
        );
        core.setEntropy(address(randomCoordinator));
        core.setPointer(keccak256("ENTROPY_COORDINATOR"), address(randomCoordinator));
        host.requireCurrentCheckpoint(id);
        require(_has(router.tokenJSON(91), '"entropy_finalized":false'));
        require(!_has(router.tokenHTML(91), "const hash="));
    }

    function testScopedPolicyExplicitNotRequiredIsTerminalWithoutRandomSeed() public {
        _scopedFixture(2, true);
        StreamFinalityScope memory scope = _scopedScope(1);
        (Checkpoint host, bytes32 selection) = _scopedCapture(scope);
        bytes32 id = host.begin(selection, 0);
        host.append(id, _scopedPayload(scope));
        O.Output memory row = host.outputAt(id, 0);
        require(
            row.entropy.status == 2 && row.entropy.mode == 2 && row.entropy.terminal
                && !row.entropy.finalized && row.entropy.seed == 0 && row.terminalAdmissionHash != 0
        );
        (bytes32 nativeSeed, bool nativeFinalized) = terminalCoordinator.tokenSeed(91);
        require(nativeSeed == 0 && !nativeFinalized);
        host.requireCurrentCheckpoint(id);
    }

    function testScopedPolicyPendingBatchRollsBackThenActualFulfillmentRetries() public {
        _scopedFixture(1, false);
        StreamFinalityScope memory scope = _scopedScope(3);
        (Checkpoint host, bytes32 selection) = _scopedCapture(scope);
        bytes32 id = host.begin(selection, 0);
        O.Payload[] memory payload = new O.Payload[](2);
        payload[0] = O.Payload(91, hex"89504e470d0a1a0a", bytes(router.tokenHTML(91)));
        payload[1] =
            O.Payload(92, hex"89504e470d0a1a0a", bytes("nonempty pending output cannot qualify"));
        E.TokenReadiness memory pending = E(host.entropySourceSet()).tokenEntropyReadiness(92);
        require(!pending.finalized && !pending.terminal && pending.seed == 0 && pending.status != 5);
        bytes32 before = keccak256(abi.encode(host.checkpoint(id)));
        vm.expectRevert(abi.encodeWithSelector(O.StaticContentPayload.selector, uint256(92)));
        host.append(id, payload);
        require(keccak256(abi.encode(host.checkpoint(id))) == before);
        vm.expectRevert(abi.encodeWithSelector(O.StaticContentIndex.selector, uint256(0)));
        host.outputAt(id, 0);
        _scopedFinalize();
        host.append(id, _scopedPayload(scope));
        require(host.requireCurrentCheckpoint(id).nextIndex == 2);
    }

    function testScopedPolicyBurnedRetainedIdentityAndPreparedRejection() public {
        _scopedFixture(1, true);
        StreamFinalityScope memory scope = _scopedScope(2);
        _scopedToken(91, 1, 3, address(terminalCoordinator));
        _scopedToken(92, 2, 3, address(randomCoordinator));
        (Checkpoint host, bytes32 selection) = _scopedCapture(scope);
        bytes32 id = host.begin(selection, 0);
        host.append(id, _scopedPayload(scope));
        bytes32 retained = keccak256(abi.encode(host.outputAt(id, 1)));
        require(_has(router.tokenJSON(92), '"metadata_state":"burned"'));
        host.requireCurrentCheckpoint(id);
        _scopedToken(92, 2, 1, address(randomCoordinator));
        vm.expectRevert();
        host.requireCurrentCheckpoint(id);
        require(keccak256(abi.encode(host.outputAt(id, 1))) == retained);
        _scopedToken(92, 2, 3, address(randomCoordinator));
        host.requireCurrentCheckpoint(id);
    }

    function testScopedPolicyPayloadOrderImageAndHTMLFailuresLeaveExactRetry() public {
        _scopedFixture(1, true);
        StreamFinalityScope memory scope = _scopedScope(2);
        (Checkpoint host, bytes32 selection) = _scopedCapture(scope);
        bytes32 id = host.begin(selection, 0);
        bytes32 before = keccak256(abi.encode(host.checkpoint(id)));
        O.Payload[] memory payload = _scopedPayload(scope);
        payload[1].tokenId = 91;
        vm.expectRevert();
        host.append(id, payload);
        require(keccak256(abi.encode(host.checkpoint(id))) == before);
        payload = _scopedPayload(scope);
        payload[1].image = hex"01";
        vm.expectRevert();
        host.append(id, payload);
        require(keccak256(abi.encode(host.checkpoint(id))) == before);
        payload = _scopedPayload(scope);
        payload[1].animation = bytes("substituted HTML");
        vm.expectRevert();
        host.append(id, payload);
        require(keccak256(abi.encode(host.checkpoint(id))) == before);
        host.append(id, _scopedPayload(scope));
        _assertRoots(host, id);
    }

    function testScopedPolicyCurrentSelectionAdmissionAndFullOutputDriftPreserveHistory() public {
        _scopedFixture(1, true);
        StreamFinalityScope memory scope = _scopedScope(3);
        (Checkpoint host, bytes32 selection) = _scopedCapture(scope);
        bytes32 id = host.begin(selection, 0);
        host.append(id, _scopedPayload(scope));
        bytes32 saved =
            keccak256(abi.encode(host.checkpoint(id), host.outputAt(id, 0), host.outputAt(id, 1)));
        scopedModules.setEnabled(false);
        vm.expectRevert();
        host.requireCurrentCheckpoint(id);
        scopedModules.setEnabled(true);
        terminalVersions.setAdmitted(false);
        vm.expectRevert();
        host.requireCurrentCheckpoint(id);
        terminalVersions.setAdmitted(true);
        attribution.setFail(true);
        vm.expectRevert();
        host.requireCurrentCheckpoint(id);
        attribution.setFail(false);
        require(
            keccak256(abi.encode(host.checkpoint(id), host.outputAt(id, 0), host.outputAt(id, 1)))
                == saved
        );
        host.requireCurrentCheckpoint(id);
    }

    function testScopedPolicyRuntimePinsCannotBeReplacedAndOriginalBytesRetry() public {
        _scopedFixture(1, true);
        StreamFinalityScope memory scope = _scopedScope(1);
        (Checkpoint host, bytes32 selection) = _scopedCapture(scope);
        bytes32 id = host.begin(selection, 0);
        host.append(id, _scopedPayload(scope));
        bytes32 saved = keccak256(abi.encode(host.outputAt(id, 0)));
        address[3] memory targets =
            [address(scopedFactory), host.entropySourceSet(), host.terminalReadiness()];
        for (uint256 i; i < targets.length; ++i) {
            bytes memory original = targets[i].code;
            vm.etch(targets[i], hex"00");
            vm.expectRevert();
            host.requireCurrentCheckpoint(id);
            require(keccak256(abi.encode(host.outputAt(id, 0))) == saved);
            vm.etch(targets[i], original);
            host.requireCurrentCheckpoint(id);
        }
    }

    function testScopedPolicyFactoryBindingsAndCanonicalDependencyTupleRejectSubstitution() public {
        _scopedFixture(1, true);
        StreamFinalityScope memory scope = _scopedScope(1);
        (Checkpoint host, bytes32 selection) = _scopedCapture(scope);
        address set = host.entropySourceSet();
        Factory other = Factory(
            _artistArtifactCreate(
                "smart-contracts/domains/finality/StreamFinalityScopedEntropyPolicySourceFactoryV2.sol:StreamFinalityScopedEntropyPolicySourceFactoryV2",
                abi.encode(_scopedDependencies())
            )
        );
        StaticRouteVm(address(vm))
            .mockCall(set, abi.encodeCall(E.factory, ()), abi.encode(address(other)));
        vm.expectRevert();
        host.begin(selection, 0);
        StaticRouteVm(address(vm))
            .mockCall(set, abi.encodeCall(E.factory, ()), abi.encode(address(scopedFactory)));
        PolicyReads.Dependencies memory d = _scopedDependencies();
        bytes memory canonical = abi.encode(d);
        StaticRouteVm(address(vm))
            .mockCall(
                address(scopedFactory),
                abi.encodeWithSignature("dependencies()"),
                abi.encodePacked(canonical, bytes32(0))
            );
        vm.expectRevert();
        host.begin(selection, 0);
        StaticRouteVm(address(vm))
            .mockCall(address(scopedFactory), abi.encodeWithSignature("dependencies()"), canonical);
        ++d.readGas;
        StaticRouteVm(address(vm))
            .mockCall(
                address(scopedFactory), abi.encodeWithSignature("dependencies()"), abi.encode(d)
            );
        vm.expectRevert();
        host.begin(selection, 0);
        StaticRouteVm(address(vm))
            .mockCall(address(scopedFactory), abi.encodeWithSignature("dependencies()"), canonical);
        bytes32 id = host.begin(selection, 0);
        host.append(id, _scopedPayload(scope));
        host.requireCurrentCheckpoint(id);
    }

    function testScopedPolicyWrongScopeCannotBorrowAnotherGenuineFactorySet() public {
        _scopedFixture(1, true);
        StreamFinalityScope memory release_ = _scopedScope(2);
        (Checkpoint host, bytes32 releaseSelection) = _scopedCapture(release_);
        StreamFinalityScope memory season = _scopedScope(3);
        (Checkpoint other, bytes32 seasonSelection) = _scopedCapture(season);
        require(host.entropySourceSet() != other.entropySourceSet());
        vm.expectRevert();
        host.begin(seasonSelection, 0);
        address source = host.entropySourceSet();
        address wrongReadiness = other.terminalReadiness();
        vm.expectRevert();
        _scopedCheckpoint(source, wrongReadiness);
        bytes32 id = host.begin(releaseSelection, 0);
        host.append(id, _scopedPayload(release_));
        host.requireCurrentCheckpoint(id);
    }

    function testScopedPolicyCollectionViewAndMalformedScopesStayOutsideProfile() public {
        _scopedFixture(1, true);
        StreamFinalityScope memory token = _scopedScope(1);
        (Checkpoint host,) = _scopedCapture(token);
        require(host.supportsInterface(type(O).interfaceId));
        require(
            !host.supportsInterface(type(CollectionO).interfaceId)
                && !host.supportsInterface(type(OriginalO).interfaceId)
        );
        require(
            host.scopedPolicyProfile()
                == keccak256("6529STREAM_SCOPED_POLICY_CURRENT_FULL_CONTENT_V2")
        );
        StreamFinalityScope memory collection =
            StreamFinalityScope(StreamFinalityScopeType.COLLECTION, 1, 0, 0);
        bytes32 selection = scopedSelections.begin(collection);
        scopedSelections.append(selection, 16);
        vm.expectRevert(abi.encodeWithSelector(O.InvalidStaticContentConfiguration.selector));
        host.begin(selection, 0);
        StreamFinalityScope memory view_ = _scopedScope(4);
        (Checkpoint viewHost, bytes32 viewSelection) = _scopedCapture(view_);
        vm.expectRevert(abi.encodeWithSelector(O.InvalidStaticContentConfiguration.selector));
        viewHost.begin(viewSelection, 0);
        token.scopeId = bytes32(uint256(1));
        vm.expectRevert();
        scopedSelections.begin(token);
        StreamFinalityScope memory release_ =
            StreamFinalityScope(StreamFinalityScopeType.RELEASE, 1, 91, view_.scopeId);
        vm.expectRevert();
        scopedSelections.begin(release_);
    }

    function testScopedPolicyPartialCaptureEventsAndExactCompletion() public {
        _scopedFixture(1, true);
        StreamFinalityScope memory scope = _scopedScope(3);
        (Checkpoint host, bytes32 selection) = _scopedCapture(scope);
        O.Payload[] memory whole = _scopedPayload(scope);
        O.Payload[] memory one = new O.Payload[](1);
        one[0] = whole[0];
        bytes32 salt = keccak256("incremental capture salt");
        vm.recordLogs();
        bytes32 id = host.begin(selection, salt);
        host.append(id, one);
        Vm.Log[] memory logs = vm.getRecordedLogs();
        require(
            logs.length == 2 && logs[0].emitter == address(host) && logs[1].emitter == address(host)
        );
        require(logs[0].topics[1] == id && logs[1].topics[1] == id && logs[1].topics[2] == 0);
        (uint16 startedVersion, bytes32 eventSalt, O.Plan memory initial) =
            abi.decode(logs[0].data, (uint16, bytes32, O.Plan));
        require(
            startedVersion == 2 && eventSalt == salt && initial.nextIndex == 0
                && initial.tokenCount == 2
        );
        (uint16 appendedVersion, O.Output memory first, bytes32 firstLeafHash) =
            abi.decode(logs[1].data, (uint16, O.Output, bytes32));
        require(
            appendedVersion == 2
                && keccak256(abi.encode(first)) == keccak256(abi.encode(host.outputAt(id, 0)))
        );
        require(firstLeafHash == Tree.leafHash(block.chainid, address(core), first.leaf));
        require(host.checkpoint(id).nextIndex == 1 && host.checkpoint(id).contentRoot == 0);
        vm.expectRevert(abi.encodeWithSelector(O.StaticContentIncomplete.selector, id));
        host.requireCurrentCheckpoint(id);
        one[0] = whole[1];
        vm.recordLogs();
        host.append(id, one);
        logs = vm.getRecordedLogs();
        require(
            logs.length == 2 && logs[0].emitter == address(host) && logs[1].emitter == address(host)
        );
        require(logs[0].topics[1] == id && logs[0].topics[2] == bytes32(uint256(1)));
        require(
            logs[1].topics[0]
                    == keccak256("StaticContentCompleted(uint16,bytes32,bytes32,bytes32,uint64)")
                && logs[1].topics[1] == id
        );
        (uint16 completedVersion, bytes32 contentRoot, bytes32 outputRoot, uint64 count) =
            abi.decode(logs[1].data, (uint16, bytes32, bytes32, uint64));
        O.Plan memory finalPlan = host.requireCurrentCheckpoint(id);
        require(
            completedVersion == 2 && count == 2 && contentRoot == finalPlan.contentRoot
                && outputRoot == finalPlan.outputRoot
        );
        _assertRoots(host, id);
    }

    function testScopedPolicyFullOriginalPolicyDriftRejectsDespiteSameTerminalStatus() public {
        _scopedFixture(1, true);
        StreamFinalityScope memory scope = _scopedScope(1);
        (Checkpoint host, bytes32 selection) = _scopedCapture(scope);
        bytes32 id = host.begin(selection, 0);
        host.append(id, _scopedPayload(scope));
        bytes32 saved = keccak256(abi.encode(host.checkpoint(id), host.outputAt(id, 0)));
        EP.PolicyRecord memory policy = EP(address(terminalCoordinator)).collectionEntropyPolicy(1);
        bytes memory original = abi.encode(policy);
        policy.artistConsentRecord =
            keccak256("different historical receipt, unchanged status/policy hash");
        // Deliberate negative read corruption of one original native getter, never a positive
        // replacement SourceSet or fabricated finalized seed.
        StaticRouteVm(address(vm))
            .mockCall(
                address(terminalCoordinator),
                abi.encodeCall(EP.collectionEntropyPolicy, (uint256(1))),
                abi.encode(policy)
            );
        vm.expectRevert();
        host.requireCurrentCheckpoint(id);
        require(keccak256(abi.encode(host.checkpoint(id), host.outputAt(id, 0))) == saved);
        StaticRouteVm(address(vm))
            .mockCall(
                address(terminalCoordinator),
                abi.encodeCall(EP.collectionEntropyPolicy, (uint256(1))),
                original
            );
        host.requireCurrentCheckpoint(id);
    }

    function _assertRoots(Checkpoint host, bytes32 id) private view {
        O.Plan memory p = host.requireCurrentCheckpoint(id);
        StreamTokenContentLeaf[] memory leaves = new StreamTokenContentLeaf[](p.tokenCount);
        bytes32 leafChain;
        bytes32 outputChain;
        for (uint256 i; i < p.tokenCount; ++i) {
            O.Output memory row = host.outputAt(id, i);
            leaves[i] = row.leaf;
            require(row.leaf.metadataHash == keccak256(bytes(router.tokenJSON(row.leaf.tokenId))));
            require(row.leaf.animationHash == keccak256(bytes(router.tokenHTML(row.leaf.tokenId))));
            require(row.leaf.imageHash == keccak256(hex"89504e470d0a1a0a"));
            require(row.leaf.tokenDataHash == keccak256(hex"00ff6529"));
            leafChain = keccak256(
                abi.encode(
                    keccak256("6529STREAM_SCOPED_POLICY_CONTENT_LEAVES_V2"),
                    leafChain,
                    i,
                    Tree.leafHash(block.chainid, address(core), row.leaf)
                )
            );
            outputChain = keccak256(
                abi.encode(
                    keccak256("6529STREAM_SCOPED_POLICY_FULL_OUTPUTS_V2"), outputChain, i, row
                )
            );
        }
        require(p.contentRoot == Tree.root(block.chainid, address(core), leaves));
        require(p.leafChainHash == leafChain && p.outputRoot == outputChain);
    }
}
