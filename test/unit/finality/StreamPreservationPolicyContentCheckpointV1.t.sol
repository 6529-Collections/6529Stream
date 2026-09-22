// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../../helpers/PreservationPolicyContentFixtureV1.sol";

contract StreamPreservationPolicyContentCheckpointV1Test is PreservationPolicyContentFixtureV1 {
    function testPreservationAllFourScopesKeepCompleteMembershipAndLiteralNewHashes() public {
        _preservationFixture(1);
        for (uint8 kind; kind < 4; ++kind) {
            Capture memory c = _capture(_scope(kind), true);
            require(
                PreservationERC165(address(c.host))
                    .supportsInterface(type(Preservation).interfaceId)
            );
            require(!PreservationERC165(address(c.host)).supportsInterface(type(O).interfaceId));
            require(
                !PreservationERC165(address(c.host))
                    .supportsInterface(type(CollectionO).interfaceId)
            );
            bytes32 profile = kind == 0
                ? keccak256("6529STREAM_PRESERVATION_POLICY_CONTENT_V1")
                : keccak256("6529STREAM_SCOPED_PRESERVATION_POLICY_CONTENT_V1");
            require(c.host.preservationPolicyProfile() == profile);
            require(c.host.checkpoint(c.id).tokenCount == (kind == 1 ? 1 : 2));
            require(c.host.sourceFactory() == (kind == 0 ? address(0) : address(scopedFactory)));
            require(
                c.host.factoryDependenciesHash()
                    == (kind == 0 ? bytes32(0) : keccak256(abi.encode(_scopedDependencies())))
            );
            Preservation.Plan memory p = c.host.checkpoint(c.id);
            require(
                c.id
                    == keccak256(
                        abi.encode(
                            profile,
                            block.chainid,
                            address(c.host),
                            address(scopedSelections),
                            c.selection,
                            p.selectionHash,
                            c.host.entropySourceSet(),
                            c.host.entropySourceSet().codehash,
                            c.host.terminalReadiness(),
                            c.host.terminalReadiness().codehash,
                            p.inventoryHash,
                            p.policyChainHash,
                            p.preservationProfile,
                            keccak256("preservation candidate")
                        )
                    )
            );
            c.host.append(c.id, _payload(c));
            _assertComplete(c);
            require(c.host.begin(c.selection, keccak256("preservation candidate")) == c.id);
        }
    }

    function testPreservationOriginalNotRequiredAndFinalizedEvidenceStayDistinct() public {
        _scopedFixture(2, true);
        Capture memory terminal = _capture(_scopedScope(1), true);
        terminal.host.append(terminal.id, _payload(terminal));
        Preservation.Output memory first = terminal.host.outputAt(terminal.id, 0);
        require(
            first.entropy.terminal && first.entropy.status == 2 && !first.entropy.finalized
                && first.entropy.seed == 0 && first.terminalAdmissionHash != 0
        );
        Capture memory finalized =
            _capture(StreamFinalityScope(StreamFinalityScopeType.TOKEN, 1, 92, 0), true);
        finalized.host.append(finalized.id, _payload(finalized));
        Preservation.Output memory second = finalized.host.outputAt(finalized.id, 0);
        require(
            !second.entropy.terminal && second.entropy.status == 5 && second.entropy.finalized
                && second.entropy.seed == scopedFinalizedSeed && second.terminalAdmissionHash == 0
        );
        _assertComplete(terminal);
        _assertComplete(finalized);
    }

    function testPreservationBurnedRetainedMembersDoNotRequireLiveOwnership() public {
        _preservationFixture(1);
        _scopedToken(91, 1, 3, address(terminalCoordinator));
        _scopedToken(92, 2, 3, address(terminalCoordinator));
        Capture memory c = _capture(_scope(3), true);
        require(_has(router.tokenJSON(91), '"metadata_state":"burned"'));
        c.host.append(c.id, _payload(c));
        _assertComplete(c);
        bytes32 saved = _history(c);
        _scopedToken(92, 2, 1, address(terminalCoordinator));
        vm.expectRevert();
        c.host.requireCurrentCheckpoint(c.id);
        require(_history(c) == saved);
        _scopedToken(92, 2, 3, address(terminalCoordinator));
        _assertComplete(c);
    }

    function testPreservationMissingAndFailedAdmissionLeaveExactAppendRetry() public {
        _preservationFixture(1);
        Capture memory c = _capture(_scope(1), false);
        bytes32 before = _history(c);
        Preservation.Payload[] memory values = _payload(c);
        address registry = scopedSelections.selectionAt(c.selection, 0).selection.registry;
        bytes4 selector = bytes4(keccak256("requirePreservation(bytes32,address,bytes32)"));
        vm.expectRevert(
            abi.encodeWithSelector(
                PreservationCalls.RendererReadFailed.selector, registry, selector
            )
        );
        c.host.append(c.id, values);
        require(_history(c) == before);
        StaticRouteVm(address(vm))
            .mockCallRevert(
                registry,
                _admissionInput(c, 0),
                abi.encodeWithSignature("Error(string)", "separate governed admission unavailable")
            );
        vm.expectRevert(
            abi.encodeWithSelector(
                PreservationCalls.RendererReadFailed.selector, registry, selector
            )
        );
        c.host.append(c.id, values);
        require(_history(c) == before);
        _admitAll(c);
        c.host.append(c.id, values);
        _assertComplete(c);
    }

    function testPreservationIncompleteAdmissionBindingAndWrongTupleLengthFailClosed() public {
        _preservationFixture(1);
        Capture memory c = _capture(_scope(1), true);
        Preservation.Payload[] memory values = _payload(c);
        bytes32 before = _history(c);
        for (uint256 field; field < 7; ++field) {
            PreservationTypes.Admission memory a = _admission(c, 0);
            if (field == 0) a.registry = address(0);
            else if (field == 1) a.registryCodeHash = 0;
            else if (field == 2) a.versionKey = 0;
            else if (field == 3) a.registrationHash = 0;
            else if (field == 4) a.readSetHash = 0;
            else if (field == 5) a.analysisHash = 0;
            else a.goldenHash = 0;
            _setAdmission(c, 0, abi.encode(_binding(c, 0), a));
            vm.expectRevert(
                abi.encodeWithSelector(Preservation.StaticContentPayload.selector, uint256(91))
            );
            c.host.append(c.id, values);
            require(_history(c) == before);
        }
        PreservationTypes.Binding memory b = _binding(c, 0);
        b.profile = keccak256("wrong preservation profile");
        _setAdmission(c, 0, abi.encode(b, _admission(c, 0)));
        vm.expectRevert(
            abi.encodeWithSelector(Preservation.StaticContentPayload.selector, uint256(91))
        );
        c.host.append(c.id, values);
        _setAdmission(
            c, 0, abi.encodePacked(abi.encode(_binding(c, 0), _admission(c, 0)), bytes32(0))
        );
        vm.expectRevert(
            abi.encodeWithSelector(
                PreservationCalls.RendererReadFailed.selector,
                scopedSelections.selectionAt(c.selection, 0).selection.registry,
                bytes4(keccak256("requirePreservation(bytes32,address,bytes32)"))
            )
        );
        c.host.append(c.id, values);
        require(_history(c) == before);
        _admitAll(c);
        c.host.append(c.id, values);
        _assertComplete(c);
    }

    function testPreservationSecondPayloadFailureRollsBackRowsFrontierAndRoots() public {
        _preservationFixture(1);
        Capture memory c = _capture(_scope(2), true);
        bytes32 before = _history(c);
        for (uint256 defect; defect < 3; ++defect) {
            Preservation.Payload[] memory values = _payload(c);
            if (defect == 0) values[1].tokenId = 91;
            else if (defect == 1) values[1].image = hex"01";
            else values[1].animation = bytes("substituted preservation HTML");
            vm.expectRevert(
                abi.encodeWithSelector(Preservation.StaticContentPayload.selector, uint256(92))
            );
            c.host.append(c.id, values);
            require(_history(c) == before);
            vm.expectRevert(
                abi.encodeWithSelector(Preservation.StaticContentIndex.selector, uint256(0))
            );
            c.host.outputAt(c.id, 0);
        }
        c.host.append(c.id, _payload(c));
        _assertComplete(c); // Literal root also proves no failed frontier residue survived.
    }

    function testPreservationSecondProducerFailureAndEmptyBytesKeepExactBatchRetry() public {
        _preservationFixture(1);
        Capture memory c = _capture(_scope(2), true);
        Preservation.Payload[] memory values = _payload(c);
        bytes32 before = _history(c);
        string memory json = c.producers[1].preservationTokenJSON(92);
        string memory html = c.producers[1].preservationTokenHTML(92);
        c.producers[1].setFail(true);
        vm.expectRevert(
            abi.encodeWithSelector(
                PreservationCalls.RendererReadFailed.selector,
                address(c.producers[1]),
                bytes4(keccak256("preservationTokenJSON(uint256)"))
            )
        );
        c.host.append(c.id, values);
        require(_history(c) == before);
        c.producers[1].setFail(false);
        c.producers[1].setBytes(92, "", html);
        vm.expectRevert(
            abi.encodeWithSelector(Preservation.StaticContentPayload.selector, uint256(92))
        );
        c.host.append(c.id, values);
        require(_history(c) == before);
        c.producers[1].setBytes(92, json, "");
        vm.expectRevert(
            abi.encodeWithSelector(Preservation.StaticContentPayload.selector, uint256(92))
        );
        c.host.append(c.id, values);
        require(_history(c) == before);
        c.producers[1].setBytes(92, json, html);
        c.host.append(c.id, values);
        _assertComplete(c);
    }

    function testPreservationProducerProfileAndBindingDriftPreserveHistoricalOutput() public {
        _preservationFixture(1);
        Capture memory c = _capture(_scope(1), true);
        c.host.append(c.id, _payload(c));
        bytes32 before = _history(c);
        PreservationTypes.Binding memory b = _binding(c, 0);
        c.producer.setProfile(keccak256("wrong profile"));
        vm.expectRevert(
            abi.encodeWithSelector(PreservationTypes.InvalidPreservationBinding.selector)
        );
        c.host.requireCurrentCheckpoint(c.id);
        c.producer.setProfile(b.profile);
        c.producer
            .setBinding(
                address(metadata),
                b.metadataRouter,
                b.liveRenderer,
                b.liveRendererCodeHash,
                b.attribution,
                b.attributionCodeHash
            );
        vm.expectRevert(
            abi.encodeWithSelector(PreservationTypes.InvalidPreservationBinding.selector)
        );
        c.host.requireCurrentCheckpoint(c.id);
        c.producer
            .setBinding(
                b.core,
                b.metadataRouter,
                b.liveRenderer,
                b.liveRendererCodeHash,
                b.attribution,
                bytes32(uint256(1))
            );
        vm.expectRevert(
            abi.encodeWithSelector(
                PreservationTypes.PreservationDependencyChanged.selector, b.attribution
            )
        );
        c.host.requireCurrentCheckpoint(c.id);
        c.producer
            .setBinding(
                b.core,
                b.metadataRouter,
                b.liveRenderer,
                b.liveRendererCodeHash,
                b.attribution,
                b.attributionCodeHash
            );
        require(_history(c) == before);
        _assertComplete(c);
    }

    function testPreservationRuntimeAndLiveAdmissionFailuresCannotRewriteSavedRows() public {
        _preservationFixture(1);
        Capture memory c = _capture(_scope(1), true);
        c.host.append(c.id, _payload(c));
        bytes32 before = _history(c);
        address[5] memory targets = [
            address(c.producer),
            address(attribution),
            c.host.entropySourceSet(),
            c.host.terminalReadiness(),
            address(scopedFactory)
        ];
        for (uint256 i; i < targets.length; ++i) {
            bytes memory code = targets[i].code;
            vm.etch(targets[i], hex"00");
            vm.expectRevert();
            c.host.requireCurrentCheckpoint(c.id);
            require(_history(c) == before);
            vm.etch(targets[i], code);
            _assertComplete(c);
        }
        terminalVersions.setAdmitted(false);
        vm.expectRevert();
        c.host.requireCurrentCheckpoint(c.id);
        terminalVersions.setAdmitted(true);
        _assertComplete(c);
    }

    function testPreservationCurrentFullBytesAndAdmissionRerenderKeepIndependentLiveHistory()
        public
    {
        _preservationFixture(1);
        StreamFinalityScope memory scope = _scope(1);
        Capture memory c = _capture(scope, true);
        c.host.append(c.id, _payload(c));
        (Checkpoint live, bytes32 selected) = _scopedCapture(scope);
        bytes32 liveId = live.begin(selected, 0);
        live.append(liveId, _scopedPayload(scope));
        live.requireCurrentCheckpoint(liveId);
        bytes32 before = _history(c);
        bytes32 oldLive = keccak256(abi.encode(live.outputAt(liveId, 0)));
        string memory liveJSON = router.tokenJSON(91);
        StaticRouteVm(address(vm))
            .mockCall(
                address(router),
                abi.encodeCall(router.tokenJSON, (uint256(91))),
                abi.encode(string(abi.encodePacked(" ", liveJSON)))
            );
        vm.expectRevert(abi.encodeWithSelector(O.StaticContentChanged.selector, liveId));
        live.requireCurrentCheckpoint(liveId);
        c.host.requireCurrentCheckpoint(c.id); // New path never reads live tokenJSON as its output.
        StaticRouteVm(address(vm))
            .mockCall(
                address(router),
                abi.encodeCall(router.tokenJSON, (uint256(91))),
                abi.encode(liveJSON)
            );
        string memory preserved = c.producer.preservationTokenJSON(91);
        string memory html = c.producer.preservationTokenHTML(91);
        c.producer.setBytes(91, string(abi.encodePacked(" ", preserved)), html);
        vm.expectRevert(abi.encodeWithSelector(Preservation.StaticContentChanged.selector, c.id));
        c.host.requireCurrentCheckpoint(c.id);
        live.requireCurrentCheckpoint(liveId);
        c.producer.setBytes(91, preserved, html);
        PreservationTypes.Admission memory a = _admission(c, 0);
        a.analysisHash = keccak256("changed governed evidence");
        _setAdmission(c, 0, abi.encode(_binding(c, 0), a));
        vm.expectRevert(abi.encodeWithSelector(Preservation.StaticContentChanged.selector, c.id));
        c.host.requireCurrentCheckpoint(c.id);
        _admitAll(c);
        require(_history(c) == before && keccak256(abi.encode(live.outputAt(liveId, 0))) == oldLive);
        _assertComplete(c);
    }

    function testPreservationSourceMembershipAndOriginalConfigDriftFailClosed() public {
        _preservationFixture(1);
        Capture memory c = _capture(_scope(2), true);
        c.host.append(c.id, _payload(c));
        bytes32 before = _history(c);
        address source = c.host.entropySourceSet();
        PreservationMembership memory membership = E(source).scopeMembershipFacts();
        PreservationMembership memory changed =
            abi.decode(abi.encode(membership), (PreservationMembership));
        changed.tokenCount = 1;
        StaticRouteVm(address(vm))
            .mockCall(source, abi.encodeCall(E.scopeMembershipFacts, ()), abi.encode(changed));
        vm.expectRevert(
            abi.encodeWithSelector(Preservation.InvalidStaticContentConfiguration.selector)
        );
        c.host.requireCurrentCheckpoint(c.id);
        StaticRouteVm(address(vm))
            .mockCall(source, abi.encodeCall(E.scopeMembershipFacts, ()), abi.encode(membership));
        bytes32 original = E(source).originalInventoryHash();
        StaticRouteVm(address(vm))
            .mockCall(
                source,
                abi.encodeCall(E.originalInventoryHash, ()),
                abi.encode(keccak256("different inventory"))
            );
        vm.expectRevert(abi.encodeWithSelector(Preservation.StaticContentChanged.selector, c.id));
        c.host.requireCurrentCheckpoint(c.id);
        StaticRouteVm(address(vm))
            .mockCall(source, abi.encodeCall(E.originalInventoryHash, ()), abi.encode(original));
        S.ConfigRecord memory config = router.resolvedMetadataConfig(91);
        bytes memory exact = abi.encode(config);
        config.config.frozen = false;
        StaticRouteVm(address(vm))
            .mockCall(
                address(router),
                abi.encodeCall(router.resolvedMetadataConfig, (uint256(91))),
                abi.encode(config)
            );
        vm.expectRevert();
        c.host.requireCurrentCheckpoint(c.id);
        StaticRouteVm(address(vm))
            .mockCall(
                address(router), abi.encodeCall(router.resolvedMetadataConfig, (uint256(91))), exact
            );
        require(_history(c) == before);
        _assertComplete(c);
    }

    function testPreservationIncompleteSelectionAndOutputAreNotCompleteCandidates() public {
        _preservationFixture(1);
        Capture memory c = _capture(_scope(2), true);
        Selection.Plan memory saved = scopedSelections.checkpoint(c.selection);
        Selection.Plan memory changed = abi.decode(abi.encode(saved), (Selection.Plan));
        changed.nextIndex = 1;
        StaticRouteVm(address(vm))
            .mockCall(
                address(scopedSelections),
                abi.encodeCall(Selection.requireCurrentCheckpoint, (c.selection)),
                abi.encode(changed)
            );
        vm.expectRevert(
            abi.encodeWithSelector(Preservation.InvalidStaticContentConfiguration.selector)
        );
        c.host.begin(c.selection, bytes32(uint256(1)));
        StaticRouteVm(address(vm))
            .mockCall(
                address(scopedSelections),
                abi.encodeCall(Selection.requireCurrentCheckpoint, (c.selection)),
                abi.encode(saved)
            );
        Preservation.Payload[] memory all = _payload(c);
        Preservation.Payload[] memory part = new Preservation.Payload[](1);
        part[0] = all[0];
        c.host.append(c.id, part);
        vm.expectRevert(abi.encodeWithSelector(Preservation.StaticContentIncomplete.selector, c.id));
        c.host.requireCurrentCheckpoint(c.id);
        require(c.host.checkpoint(c.id).nextIndex == 1 && c.host.checkpoint(c.id).contentRoot == 0);
        part[0] = all[1];
        c.host.append(c.id, part);
        _assertComplete(c);
    }

    function testPreservationMixedRenderersKeepEveryMemberAndRejectCrossRowProducer() public {
        _scopedFixture(1, true);
        for (uint8 kind = 2; kind <= 3; ++kind) {
            Capture memory c = _capture(_scope(kind), true);
            require(scopedSelections.checkpoint(c.selection).tokenCount == 2);
            Selection.TokenSelection memory first = scopedSelections.selectionAt(c.selection, 0);
            Selection.TokenSelection memory second = scopedSelections.selectionAt(c.selection, 1);
            require(
                first.selection.renderer != second.selection.renderer
                    && first.selection.registry != second.selection.registry
                    && first.selection.versionKey == second.selection.versionKey
            );
            require(address(c.producers[0]) != address(c.producers[1]));
            bytes32 before = _history(c);
            Preservation.Payload[] memory values = _payload(c);
            values[1].producer = address(c.producers[0]);
            vm.expectRevert(
                abi.encodeWithSelector(PreservationTypes.InvalidPreservationBinding.selector)
            );
            c.host.append(c.id, values);
            require(_history(c) == before && c.host.checkpoint(c.id).nextIndex == 0);
            vm.expectRevert(
                abi.encodeWithSelector(Preservation.StaticContentIndex.selector, uint256(0))
            );
            c.host.outputAt(c.id, 0);
            c.host.append(c.id, _payload(c));
            _assertComplete(c);
            require(
                c.host.outputAt(c.id, 0).entropy.terminal
                    && c.host.outputAt(c.id, 1).entropy.finalized
            );
        }
    }
}
