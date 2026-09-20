// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "../../helpers/ViewPreservationReferenceFixtureV1.sol";

contract StreamViewPreservationReferencePublicationV1Test is ViewPreservationReferenceFixtureV1 {
    function testActualSnapshotToReferenceLiteralBytesDomainsAndReader() public {
        _referenceInit();
        bytes memory canonical = _referenceBytes(address(this));
        _uploadReference(canonical, false);
        bytes32 hash = referenceHost.publishReference(referenceInput);
        (Ref.Publication memory p, Ref.Receipt memory r) = referenceHost.referenceRecord(hash);
        require(
            keccak256(abi.encode(p)) == keccak256(abi.encode(referenceInput)),
            "complete original input"
        );
        require(
            keccak256(referenceHost.referencePayload(hash)) == keccak256(canonical),
            "complete canonical bytes"
        );
        require(
            r.observation.payloadHash == keccak256(canonical)
                && r.observation.payloadBytes == canonical.length,
            "payload commitment"
        );
        Ref.Receipt memory fields = abi.decode(abi.encode(r), (Ref.Receipt));
        fields.observation.recordHash = 0;
        fields.observation.recordChainHash = 0;
        require(
            hash
                == keccak256(
                    abi.encode(
                        keccak256("6529STREAM_VIEW_PRESERVATION_REFERENCE_RECORD_V1"),
                        savedChain,
                        address(referenceHost),
                        address(core),
                        address(core),
                        p,
                        fields
                    )
                ),
            "literal complete record"
        );
        require(
            r.observation.recordChainHash
                == keccak256(
                    abi.encode(
                        keccak256("6529STREAM_VIEW_PRESERVATION_REFERENCE_CHAIN_V1"),
                        savedChain,
                        address(referenceHost),
                        address(core),
                        r.scopeSubject,
                        bytes32(0),
                        uint64(1),
                        hash
                    )
                ),
            "literal first chain"
        );
        require(
            keccak256(abi.encode(finalityReader.current(_referenceReader(), scope, hash, 1)))
                == keccak256(abi.encode(r)),
            "independent typed current reader"
        );
        Ref.SourceFacts memory f = referenceHost.referenceSource(hash);
        require(
            f.snapshot.recordHash == snapshotHash && f.contentRootRecordHash == rootHash,
            "snapshot and authorized root join"
        );
        require(
            f.samples.length == 1 && f.snapshotSource.membership.tokenCount == 1
                && f.samples[0].membershipIndex == 0,
            "complete membership versus bounded capture"
        );
        require(
            f.samples[0].output.entropy.terminal && !f.samples[0].output.entropy.finalized
                && f.samples[0].output.entropy.seed == 0,
            "no invented final seed"
        );
        require(
            referenceHost.referenceCount(scope) == 1 && referenceHost.referenceAt(scope, 0) == hash,
            "scope history"
        );
    }

    function testRootBindingSnapshotAndIndependentStateMismatchRestore() public {
        _referenceInit();
        (bytes32 expected,) = referenceHost.previewReference(referenceInput, address(this));
        RootBinding.Binding memory original = rootBinding;
        rootBinding.adoptionRecord = keccak256("foreign adoption");
        _rootReplies();
        vm.expectRevert(abi.encodeWithSelector(Ref.InvalidViewPreservationReference.selector));
        referenceHost.previewReference(referenceInput, address(this));
        rootBinding = original;
        rootBinding.snapshotProfileHash = keccak256("old scoped profile");
        _rootReplies();
        vm.expectRevert(abi.encodeWithSelector(Ref.InvalidViewPreservationReference.selector));
        referenceHost.previewReference(referenceInput, address(this));
        rootBinding = original;
        bytes32 state = rootRecord.stateHash;
        rootRecord.stateHash = keccak256("independent state corruption");
        _rootReplies();
        vm.expectRevert(abi.encodeWithSelector(Ref.InvalidViewPreservationReference.selector));
        referenceHost.previewReference(referenceInput, address(this));
        rootRecord.stateHash = state;
        _rootReplies();
        (bytes32 restored,) = referenceHost.previewReference(referenceInput, address(this));
        require(restored == expected, "exact root restoration");
    }

    function testNonSanctionOutputDriftRefusesCurrentButRetainsHistory() public {
        _referenceInit();
        bytes32 hash = _publishReference();
        bytes32 historical = keccak256(referenceHost.referencePayload(hash));
        bytes memory old = abi.encode(bytes("{\"artist\":\"fixture\"}"));
        // Use the fixture's actual retained attribution reply, rather than inventing its old value.
        (bool ok, bytes memory raw) = address(attribution)
            .staticcall(
                abi.encodeWithSignature(
                    "preservationAttribution(uint256,uint256)", uint256(1), uint256(11)
                )
            );
        require(ok, "positive original attribution");
        old = raw;
        _answer(
            attribution,
            "preservationAttribution(uint256,uint256)",
            abi.encode(uint256(1), uint256(11)),
            abi.encode(bytes("{\"changed\":true}"))
        );
        vm.expectRevert();
        referenceHost.requireCurrent(scope, hash, 1);
        require(keccak256(referenceHost.referencePayload(hash)) == historical, "historical payload");
        _answer(
            attribution,
            "preservationAttribution(uint256,uint256)",
            abi.encode(uint256(1), uint256(11)),
            old
        );
        require(
            referenceHost.requireCurrent(scope, hash, 1).observation.recordHash == hash,
            "exact current restore"
        );
    }

    function testBothGrantsClassThreeThenNewHeadClassEightAndReplayRefusal() public {
        _referenceInit();
        bytes32 first = _publishReference();
        require(
            referenceHost.currentReference(scope).observation.authorizationClass == 3,
            "local grant precedence"
        );
        _referenceGrants(address(this), false, true);
        referenceInput.observation.expectedHead = first;
        referenceInput.observation.expectedRevision = 1;
        referenceInput.observation.referenceId = keccak256("reference two");
        referenceInput.observation.expectedSourcesHash = 0;
        bytes32 second = _publishReference();
        Ref.Receipt memory r = referenceHost.currentReference(scope);
        require(
            r.observation.recordHash == second && r.observation.predecessor == first
                && r.observation.authorizationClass == 8 && r.observation.grantRevision == 8,
            "global fallback new record"
        );
        vm.expectRevert(abi.encodeWithSelector(Ref.InvalidViewPreservationReference.selector));
        referenceHost.publishReference(referenceInput);
        require(referenceHost.referenceCount(scope) == 2, "replay has no append");
    }

    function testMissingFinalChunkRollsBackWholeReferenceThenIdenticalRetry() public {
        _referenceInit();
        bytes memory canonical = _referenceBytes(address(this));
        require(canonical.length > 8192, "actual multi chunk payload");
        _uploadReference(canonical, true);
        vm.expectRevert();
        referenceHost.publishReference(referenceInput);
        require(
            referenceHost.referenceCount(scope) == 0
                && referenceHost.currentReference(scope).observation.recordHash == 0,
            "no partial head"
        );
        _uploadReference(canonical, false);
        bytes32 hash = referenceHost.publishReference(referenceInput);
        require(
            keccak256(referenceHost.referencePayload(hash)) == keccak256(canonical),
            "identical retry bytes"
        );
    }

    function testClassTwoLockAndLiteralScopedComponent() public {
        _referenceInit();
        bytes32 hash = _publishReference();
        (bytes32 actionScope, bytes32 oldHash, bytes32 nextHash) =
            referenceHost.lockTransition(scope);
        _action(true, keccak256("lock action"), 1, actionScope, oldHash, nextHash);
        vm.prank(address(core));
        vm.expectRevert(
            abi.encodeWithSelector(Ref.ViewPreservationReferenceAuthority.selector, address(core))
        );
        referenceHost.lockReference(scope);
        _action(true, keccak256("lock action"), 2, actionScope, oldHash, nextHash);
        vm.prank(address(core));
        referenceHost.lockReference(scope);
        Ref.Receipt memory r = referenceHost.currentReference(scope);
        RR.Lock memory locked = referenceHost.referenceLock(scope);
        StreamFinalityComponentState memory got =
            finalityReader.component(_referenceReader(), scope, hash, 1);
        require(
            got.frozen
                && got.dataHash
                    == keccak256(
                        abi.encode(
                            keccak256("6529STREAM_LOCKED_VIEW_PRESERVATION_REFERENCE_COMPONENT_V1"),
                            savedChain,
                            address(referenceHost),
                            address(core),
                            scope,
                            r,
                            locked
                        )
                    ),
            "literal locked component"
        );
        referenceInput.observation.expectedHead = hash;
        referenceInput.observation.expectedRevision = 1;
        referenceInput.observation.referenceId = keccak256("locked future");
        vm.expectRevert(
            abi.encodeWithSelector(Ref.ViewPreservationReferenceLocked.selector, r.scopeSubject)
        );
        referenceHost.publishReference(referenceInput);
    }

    function testWrongScopeSameIdentifierNeverBorrowsViewRecord() public {
        _referenceInit();
        bytes32 hash = _publishReference();
        StreamFinalityScope memory wrong = scope;
        wrong.scopeType = StreamFinalityScopeType.SEASON;
        vm.expectRevert(abi.encodeWithSelector(Ref.InvalidViewPreservationReference.selector));
        referenceHost.requireCurrent(wrong, hash, 1);
        ReferenceReader.Dependencies memory d = _referenceReader();
        vm.expectRevert(
            abi.encodeWithSelector(
                ReferenceReader.InvalidViewPreservationReferenceEvidence.selector
            )
        );
        finalityReader.current(d, wrong, hash, 1);
        require(
            referenceHost.requireCurrent(scope, hash, 1).observation.recordHash == hash,
            "view remains current"
        );
    }

    function testIndependentReaderRejectsForeignChainAndRuntimeRestores() public {
        _referenceInit();
        bytes32 hash = _publishReference();
        ReferenceReader.Dependencies memory d = _referenceReader();
        d.chainId = savedChain + 1;
        vm.expectRevert(
            abi.encodeWithSelector(
                ReferenceReader.InvalidViewPreservationReferenceEvidence.selector
            )
        );
        finalityReader.current(d, scope, hash, 1);
        d.chainId = savedChain;
        d.codeHashes[4] = keccak256("foreign publisher runtime");
        vm.expectRevert(
            abi.encodeWithSelector(
                ReferenceReader.ViewPreservationReferenceDependency.selector, address(referenceHost)
            )
        );
        finalityReader.current(d, scope, hash, 1);
        d.codeHashes[4] = address(referenceHost).codehash;
        require(
            finalityReader.current(d, scope, hash, 1).observation.recordHash == hash,
            "independent exact restore"
        );
    }
}
