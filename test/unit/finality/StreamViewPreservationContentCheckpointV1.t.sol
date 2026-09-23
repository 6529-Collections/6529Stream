// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "../../helpers/ViewPreservationCheckpointFixtureV1.sol";
import {
    StreamViewPreservationCheckpointSourceV1 as Current
} from "../../../smart-contracts/domains/finality/StreamViewPreservationCheckpointSourceV1.sol";

/// @notice Actual complete reader + checkpoint state machine; typed external authority graph.
contract StreamViewPreservationContentCheckpointV1Test is ViewPreservationCheckpointFixtureV1 {
    function testCompleteThreeRowsBindLiteralRootAndExplicitRetainedBurnedMember() public {
        _build(3, 33);
        bytes32 id = checkpointHost.begin(scope, keccak256("three rows"));
        CT.Plan memory p = checkpointHost.checkpoint(id);
        bytes32 chain = keccak256(
            abi.encode(
                keccak256("6529STREAM_ADOPTED_VIEW_PRESERVATION_CHAIN_V1"),
                id,
                scope,
                p.sourceContextHash,
                membership.membershipHash,
                uint64(3)
            )
        );
        for (uint256 i; i < 3; ++i) {
            uint256 token = 11 * (i + 1);
            _append(id, token, i == 2);
            CT.Output memory o = checkpointHost.outputAt(id, i);
            require(o.index == i && o.tokenId == token && o.collectionSerial == 7 + i * 3);
            require(
                o.burned == (i == 2) && o.lifecycle == (i == 2 ? 3 : 2)
                    && o.servingKind == (i == 2 ? 2 : 1)
            );
            require(
                o.entropy.terminal && !o.entropy.finalized && o.entropy.status == 1
                    && o.entropy.seed == 0
            );
            require(o.tokenDataHash == keccak256(hex"00f1ff00"));
            bytes32 row = keccak256(
                abi.encode(
                    keccak256("6529STREAM_ADOPTED_VIEW_PRESERVATION_ROW_V1"),
                    block.chainid,
                    address(checkpointHost),
                    id,
                    o
                )
            );
            chain = keccak256(
                abi.encode(
                    keccak256("6529STREAM_ADOPTED_VIEW_PRESERVATION_CHAIN_V1"),
                    chain,
                    uint64(i),
                    row
                )
            );
        }
        bytes32 expected = keccak256(
            abi.encode(
                keccak256("6529STREAM_ADOPTED_VIEW_PRESERVATION_OUTPUT_ROOT_V1"),
                block.chainid,
                address(checkpointHost),
                checkpointHost.configurationHash(),
                id,
                scope,
                adopted,
                p.sourceContextHash,
                uint64(3),
                chain,
                _literalTree(id, 3),
                keccak256("6529STREAM_ADOPTED_POLICY_VIEW_PRESERVATION_V1")
            )
        );
        require(checkpointHost.seal(id) == expected);
        CT.Plan memory complete = checkpointHost.requireCurrentCheckpoint(id);
        require(
            complete.outputRoot == expected && complete.rowChain == chain && complete.nextIndex == 3
                && complete.contentRoot == _literalTree(id, 3)
        );
        vm.expectRevert(abi.encodeWithSelector(V.InvalidViewAdoption.selector));
        serving.preservationViewJSON(scope, 33);
        (, string memory historical) = serving.historicalPreservationViewJSON(adopted, 33);
        require(keccak256(bytes(historical)) == checkpointHost.outputAt(id, 2).jsonHash);
    }

    function testNextOrdinalAndWrongBytesAreAtomicWithExactRetry() public {
        _build(3, 0);
        bytes32 id = checkpointHost.begin(scope, 0);
        (bytes memory json, bytes memory html) = _payload(11, false);
        bytes32 beforeHash = keccak256(abi.encode(checkpointHost.checkpoint(id)));
        vm.expectRevert(abi.encodeWithSelector(CT.ViewCheckpointToken.selector, uint256(22)));
        checkpointHost.append(id, 22, json, html);
        vm.expectRevert(abi.encodeWithSelector(CT.ViewCheckpointToken.selector, uint256(11)));
        checkpointHost.append(id, 11, json, bytes.concat(html, hex"00"));
        require(beforeHash == keccak256(abi.encode(checkpointHost.checkpoint(id))));
        checkpointHost.append(id, 11, json, html);
        require(checkpointHost.checkpoint(id).nextIndex == 1);
        vm.expectRevert(abi.encodeWithSelector(CT.ViewCheckpointToken.selector, uint256(11)));
        checkpointHost.append(id, 11, json, html);
        _append(id, 22, false);
    }

    function testCannotSealOmittedRowsOrAppendDuplicateMembershipEntry() public {
        _build(3, 0);
        bytes32 id = checkpointHost.begin(scope, 0);
        _append(id, 11, false);
        vm.expectRevert(abi.encodeWithSelector(CT.ViewCheckpointIndex.selector, uint256(1)));
        checkpointHost.seal(id);
        _answer(
            core,
            "scopeTokenAt((uint8,uint256,uint256,bytes32),uint256)",
            abi.encode(scope, uint256(1)),
            abi.encode(uint256(11))
        );
        (bytes memory json, bytes memory html) = _payload(11, false);
        vm.expectRevert(abi.encodeWithSelector(CT.ViewCheckpointToken.selector, uint256(11)));
        checkpointHost.append(id, 11, json, html);
        require(checkpointHost.checkpoint(id).nextIndex == 1);
        _token(22, 1, false);
        _append(id, 22, false);
        _append(id, 33, false);
        checkpointHost.seal(id);
    }

    function testSealReobservesEarlierFullOutputAndRollsBackThenIdenticalRetry() public {
        _build(3, 0);
        bytes32 id = checkpointHost.begin(scope, 0);
        _append(id, 11, false);
        _append(id, 22, false);
        _append(id, 33, false);
        bytes32 historical = keccak256(abi.encode(checkpointHost.outputAt(id, 0)));
        _answer(
            preservation,
            "preservationAttribution(uint256,uint256)",
            abi.encode(uint256(1), uint256(11)),
            abi.encode(bytes('{"state":"changed standing"}'))
        );
        vm.expectRevert(abi.encodeWithSelector(CT.ViewCheckpointChanged.selector, id));
        checkpointHost.seal(id);
        require(
            checkpointHost.checkpoint(id).outputRoot == 0
                && historical == keccak256(abi.encode(checkpointHost.outputAt(id, 0)))
        );
        _answer(
            preservation,
            "preservationAttribution(uint256,uint256)",
            abi.encode(uint256(1), uint256(11)),
            abi.encode(bytes('{"state":"typed_live"}'))
        );
        bytes32 root = checkpointHost.seal(id);
        require(root != 0);
        require(checkpointHost.seal(id) == root);
    }

    function testCurrentRefusesDeclarationAndSelectedProviderDriftButRetainsRows() public {
        _build(1, 0);
        bytes32 id = checkpointHost.begin(scope, 0);
        _append(id, 11, false);
        checkpointHost.seal(id);
        CT.Output memory saved = checkpointHost.outputAt(id, 0);
        _answer(
            core,
            "selectedViewRecord(uint256,bytes32)",
            abi.encode(uint256(1), VIEW_ID),
            abi.encode(keccak256("replacement declaration"), false)
        );
        vm.expectRevert(abi.encodeWithSelector(V.InvalidViewAdoption.selector));
        checkpointHost.requireCurrentCheckpoint(id);
        require(
            keccak256(abi.encode(saved)) == keccak256(abi.encode(checkpointHost.outputAt(id, 0)))
        );
        _answer(
            core,
            "selectedViewRecord(uint256,bytes32)",
            abi.encode(uint256(1), VIEW_ID),
            abi.encode(declared, false)
        );
        _answer(
            core, "scopeEvidenceProviderCodeHash()", "", abi.encode(keccak256("foreign runtime"))
        );
        vm.expectRevert(abi.encodeWithSelector(V.ViewAdoptionDependency.selector, address(core)));
        checkpointHost.requireCurrentCheckpoint(id);
        _answer(core, "scopeEvidenceProviderCodeHash()", "", abi.encode(address(core).codehash));
        checkpointHost.requireCurrentCheckpoint(id);
    }

    function testSavedTagAndMembershipMutationRefuseBeforeProgress() public {
        _build(1, 0);
        bytes32 id = checkpointHost.begin(scope, 0);
        records.forceTag(adopted, 0);
        vm.expectRevert(abi.encodeWithSelector(V.InvalidViewAdoption.selector));
        checkpointHost.begin(scope, 0);
        records.forceTag(adopted, T.PROFILE);
        StreamScopeMembershipFacts memory changed = membership;
        changed.membershipHash ^= bytes32(uint256(1));
        _answer(
            core,
            "requireScopeMembership((uint8,uint256,uint256,bytes32))",
            abi.encode(scope),
            abi.encode(changed)
        );
        (bytes memory json, bytes memory html) = _payload(11, false);
        vm.expectRevert(abi.encodeWithSelector(V.InvalidViewAdoption.selector));
        checkpointHost.append(id, 11, json, html);
        require(checkpointHost.checkpoint(id).nextIndex == 0);
        _answer(
            core,
            "requireScopeMembership((uint8,uint256,uint256,bytes32))",
            abi.encode(scope),
            abi.encode(membership)
        );
        checkpointHost.append(id, 11, json, html);
    }

    function testPendingAndPreparedAreNotTerminalOrCompletedIdentity() public {
        _build(1, 0);
        bytes32 id = checkpointHost.begin(scope, 0);
        (bytes memory json, bytes memory html) = _payload(11, false);
        _facts(3, 0, keccak256("pending request"));
        vm.expectRevert(abi.encodeWithSelector(V.InvalidViewAdoption.selector));
        checkpointHost.append(id, 11, json, html);
        _facts(1, 0, 0);
        _identity(1, false, 7);
        vm.expectRevert(abi.encodeWithSelector(CT.ViewCheckpointToken.selector, uint256(11)));
        checkpointHost.append(id, 11, json, html);
        _identity(2, false, 7);
        checkpointHost.append(id, 11, json, html);
    }

    function testFinalizedFullPolicyPreservesActualSeedAndNoTerminalClaim() public {
        _policy(2, 0, true);
        _build(1, 0);
        bytes32 id = checkpointHost.begin(scope, 0);
        _append(id, 11, false);
        CT.Output memory o = checkpointHost.outputAt(id, 0);
        require(o.entropy.finalized && !o.entropy.terminal && o.entropy.status == 5);
        require(
            o.entropy.seed == keccak256(abi.encode("genuine typed finalized seed", uint256(11)))
        );
        require(
            keccak256(abi.encode(o.entropy.policy)) == keccak256(abi.encode(rule.collectionPolicy))
        );
        checkpointHost.seal(id);
    }

    function testAsyncTerminalPolicyRequiresExactZeroSeedAndRequest() public {
        _policy(2, 1, true);
        _build(1, 0);
        bytes32 id = checkpointHost.begin(scope, 0);
        (bytes memory json, bytes memory html) = _payload(11, false);
        _facts(2, 0, keccak256("invented request"));
        vm.expectRevert(abi.encodeWithSelector(V.InvalidViewAdoption.selector));
        checkpointHost.append(id, 11, json, html);
        _facts(2, 0, 0);
        checkpointHost.append(id, 11, json, html);
        CT.Output memory o = checkpointHost.outputAt(id, 0);
        require(o.entropy.terminal && !o.entropy.finalized && o.entropy.status == 2);
    }

    function testFullScopeCoordinatesAndConfigurationHostCannotAlias() public {
        _build(1, 0);
        bytes32 id = checkpointHost.begin(scope, 0);
        StreamFinalityScope memory other = StreamFinalityScope(
            StreamFinalityScopeType.SEASON, scope.collectionId, 0, scope.scopeId
        );
        vm.expectRevert(abi.encodeWithSelector(CT.InvalidViewCheckpoint.selector));
        checkpointHost.begin(other, 0);
        Checkpoint second = new Checkpoint(config);
        require(second.configurationHash() != checkpointHost.configurationHash());
        require(second.begin(scope, 0) != id);
        CT.Configuration memory bad = config;
        bad.servingConfigurationHash ^= bytes32(uint256(1));
        vm.expectRevert(
            abi.encodeWithSelector(CT.ViewCheckpointDependency.selector, address(records))
        );
        new Checkpoint(bad);
        uint256 originalChain = config.chainId;
        vm.chainId(originalChain + 1);
        vm.expectRevert(abi.encodeWithSelector(CT.InvalidViewCheckpoint.selector));
        checkpointHost.begin(scope, 0);
        vm.chainId(originalChain);
        require(checkpointHost.begin(scope, 0) == id);
    }

    function testPreparedRowsAndImmutableSealedRowsNeverClaimUnobservedBytes() public {
        _build(1, 0);
        bytes32 id = checkpointHost.begin(scope, 0);
        vm.expectRevert(abi.encodeWithSelector(CT.ViewCheckpointChanged.selector, id));
        checkpointHost.requireCurrentCheckpoint(id);
        _append(id, 11, false);
        checkpointHost.seal(id);
        bytes32 saved = keccak256(abi.encode(checkpointHost.outputAt(id, 0)));
        (bytes memory json, bytes memory html) = _payload(11, false);
        vm.expectRevert(abi.encodeWithSelector(CT.ViewCheckpointIndex.selector, uint256(1)));
        checkpointHost.append(id, 11, json, html);
        _answer(core, "tokenData(uint256)", abi.encode(uint256(11)), abi.encode(hex"01"));
        vm.expectRevert(abi.encodeWithSelector(CT.ViewCheckpointChanged.selector, id));
        checkpointHost.requireCurrentCheckpoint(id);
        require(saved == keccak256(abi.encode(checkpointHost.outputAt(id, 0))));
        _answer(core, "tokenData(uint256)", abi.encode(uint256(11)), abi.encode(hex"00f1ff00"));
        checkpointHost.requireCurrentCheckpoint(id);
    }

    function testEmptyMembershipCannotBecomeFakeOutputObservation() public {
        _build(1, 0);
        StreamScopeMembershipFacts memory empty = membership;
        empty.tokenCount = 0;
        _answer(sourceSet, "scopeMembershipFacts()", "", abi.encode(empty));
        vm.expectRevert(abi.encodeWithSelector(V.InvalidViewAdoption.selector));
        checkpointHost.begin(scope, 0);
        _answer(sourceSet, "scopeMembershipFacts()", "", abi.encode(membership));
        require(checkpointHost.begin(scope, 0) != 0);
    }

    function _literalTree(bytes32 id, uint256 n) private view returns (bytes32) {
        bytes32[] memory level = new bytes32[](n);
        for (uint256 i; i < n; ++i) {
            CT.Output memory row = checkpointHost.outputAt(id, i);
            level[i] = keccak256(
                abi.encode(
                    keccak256("6529STREAM_VIEW_PRESERVATION_CONTENT_LEAF_V1"),
                    keccak256("6529STREAM_ADOPTED_POLICY_VIEW_PRESERVATION_V1"),
                    config.chainId,
                    address(core),
                    scope,
                    adopted,
                    row
                )
            );
        }
        while (n > 1) {
            uint256 next;
            for (uint256 i; i < n; i += 2) {
                level[next++] = i + 1 < n
                    ? keccak256(
                        abi.encode(
                            keccak256("6529STREAM_VIEW_PRESERVATION_CONTENT_NODE_V1"),
                            level[i],
                            level[i + 1]
                        )
                    )
                    : level[i];
            }
            n = next;
        }
        return level[0];
    }

    function testCurrentSourceUsesActualCheckpointDomainWithoutClaimingCompletedRows() public {
        _build(1, 0);
        CT.Source memory actual = checkpointHost.currentSource(scope);
        bytes32 expected = keccak256(
            abi.encode(
                keccak256("6529STREAM_ADOPTED_VIEW_PRESERVATION_SOURCE_V1"),
                keccak256("6529STREAM_ADOPTED_VIEW_PRESERVATION_CHECKPOINT_V1"),
                config.chainId,
                address(checkpointHost),
                config,
                scope,
                actual.adoption.recordHash,
                actual.adoption.sourceHash,
                actual.policy,
                keccak256("6529STREAM_ADOPTED_POLICY_VIEW_PRESERVATION_V1"),
                actual.preservation,
                actual.admission
            )
        );
        require(actual.contextHash == expected);
        bytes32 id = checkpointHost.begin(scope, 0);
        require(checkpointHost.checkpoint(id).sourceContextHash == expected);
        vm.expectRevert(abi.encodeWithSelector(CT.ViewCheckpointChanged.selector, id));
        checkpointHost.requireCurrentCheckpoint(id);
        Checkpoint other = new Checkpoint(config);
        require(other.currentSource(scope).contextHash != expected);
    }

    function testSingleAndEvenTreeRootsBindFullRowsAndCurrentAdmission() public {
        for (uint256 n = 1; n <= 2; ++n) {
            _build(n, 0);
            bytes32 id = checkpointHost.begin(scope, bytes32(n));
            for (uint256 i; i < n; ++i) {
                _append(id, 11 * (i + 1), false);
            }
            checkpointHost.seal(id);
            require(checkpointHost.requireCurrentCheckpoint(id).contentRoot == _literalTree(id, n));
        }
    }

    function testEveryAdmissionWordAndProducerWordIsJoinedBeforeProgress() public {
        _build(1, 0);
        bytes32 id = checkpointHost.begin(scope, 0);
        bytes32 initial = keccak256(abi.encode(checkpointHost.checkpoint(id)));
        bytes memory good = abi.encode(producerBinding, admission);
        for (uint256 i; i < 16; ++i) {
            bytes memory changed = abi.encode(producerBinding, admission);
            changed[i * 32 + 31] ^= bytes1(uint8(1));
            _answer(
                core,
                "requirePreservation(bytes32,address,bytes32)",
                abi.encode(admission.versionKey, address(serving), CT.OUTPUT_PROFILE),
                changed
            );
            (bool ok,) = address(checkpointHost)
                .call(abi.encodeCall(checkpointHost.begin, (scope, bytes32(0))));
            if (i >= 12) {
                // Arbitrary but authenticated analysis/read/golden hashes create a DIFFERENT context;
                // they are not claimed predictable. They cannot finish the original preparation.
                if (ok) {
                    (bytes memory j, bytes memory h) = _payload(11, false);
                    (ok,) = address(checkpointHost)
                        .call(abi.encodeCall(checkpointHost.append, (id, 11, j, h)));
                }
            }
            require(!ok, "binding field must refuse old context");
            require(initial == keccak256(abi.encode(checkpointHost.checkpoint(id))));
            _answer(
                core,
                "requirePreservation(bytes32,address,bytes32)",
                abi.encode(admission.versionKey, address(serving), CT.OUTPUT_PROFILE),
                good
            );
            require(checkpointHost.begin(scope, 0) == id);
        }
        _append(id, 11, false);
        checkpointHost.seal(id);
    }

    function testProducerSuccessCannotSubstituteForActualCurrentAdmission() public {
        _build(1, 0);
        bytes32 id = checkpointHost.begin(scope, 0);
        _answer(
            core,
            "supportsInterface(bytes4)",
            abi.encode(type(Admission).interfaceId),
            abi.encode(false)
        );
        serving.preservationViewJSON(scope, 11);
        vm.expectRevert(abi.encodeWithSelector(CT.ViewCheckpointDependency.selector, address(core)));
        checkpointHost.begin(scope, 0);
        _answer(
            core,
            "supportsInterface(bytes4)",
            abi.encode(type(Admission).interfaceId),
            abi.encode(true)
        );
        _answer(
            core,
            "requirePreservation(bytes32,address,bytes32)",
            abi.encode(admission.versionKey, address(serving), CT.OUTPUT_PROFILE),
            hex"1234"
        );
        vm.expectRevert();
        checkpointHost.begin(scope, 0);
        _installAdmission(producerBinding, admission);
        _append(id, 11, false);
        checkpointHost.seal(id);
    }

    function testTypedSanctionProjectionDoesNotHideOtherCurrentDrift() public {
        _build(1, 0);
        bytes32 id = checkpointHost.begin(scope, 0);
        _append(id, 11, false);
        checkpointHost.seal(id);
        CT.Plan memory before_ = checkpointHost.requireCurrentCheckpoint(id);
        _answer(
            attribution,
            "attribution(uint256,uint256)",
            abi.encode(uint256(1), uint256(11)),
            abi.encode(bytes('{"state":"artist_sanctioned","sanction":"typed new record"}'))
        );
        require(
            keccak256(abi.encode(checkpointHost.requireCurrentCheckpoint(id)))
                == keccak256(abi.encode(before_))
        );
        _preserved(11, bytes('{"state":"typed_live","standing_conflict":"changed"}'));
        vm.expectRevert(abi.encodeWithSelector(CT.ViewCheckpointChanged.selector, id));
        checkpointHost.requireCurrentCheckpoint(id);
        _preserved(11, bytes('{"state":"typed_live"}'));
        checkpointHost.requireCurrentCheckpoint(id);
    }
}
