// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "./StreamScopedPreservationPolicyReferencePublicationV1Fixture.sol";

contract StreamScopedPreservationPolicyReferencePublicationV1ContinuationTest is
    ScopedPreservationReferenceFixtureV1
{
    function testOfficialSafeLateMissingChunkRollsBackAndRetriesIdenticalEnvelope() public {
        _reference(1, 3);
        uint256[] memory keys = new uint256[](2);
        keys[0] = 0x819131;
        keys[1] = 0x819132;
        OfficialSafe account =
            createOfficialSafe(deploySafeComponents("1.4.1"), safeOwnerAddresses(keys), 2, 1912);
        _familyGrant(1, Families.CURATOR, 3, address(account), true);
        bytes memory raw = _referenceBytes(address(account));
        _upload(raw, true);
        bytes32 missing = keccak256(_chunk(raw, (raw.length - 1) / 8192));
        (address pointer,) = snapshotStore.chunk(missing);
        require(pointer == address(0), "genuinely absent final payload chunk");
        bytes32 rootSaved = keccak256(
            abi.encode(
                router.scopedContentRootRecord(adoptedRoot),
                PolicyRoot(address(router)).scopedPreservationPolicyContentRootBinding(adoptedRoot)
            )
        );
        bytes32 snapshotSaved = _historyHash(adoptedSnapshot);
        bytes memory input = abi.encodeCall(referenceHost.publishReference, (referenceInput));
        vm.expectRevert(
            abi.encodeWithSelector(StoredBytes.SnapshotChunkUnavailable.selector, missing)
        );
        vm.prank(address(account));
        referenceHost.publishReference(referenceInput);
        uint256 nonce = account.nonce();
        bytes memory signatures = safeThresholdSignature(
            keys,
            account.getTransactionHash(
                address(referenceHost), 0, input, 0, 0, 0, 0, address(0), address(0), nonce
            )
        );
        bytes32 envelope = keccak256(abi.encode(input, signatures, nonce));
        vm.expectRevert(abi.encodeWithSignature("Error(string)", "GS013"));
        account.execTransaction(
            address(referenceHost),
            0,
            input,
            0,
            0,
            0,
            0,
            address(0),
            payable(address(0)),
            signatures
        );
        require(
            account.nonce() == nonce && referenceHost.referenceCount(referenceInput.scope) == 0
                && referenceHost.currentReference(referenceInput.scope).observation.recordHash == 0
        );
        require(
            _historyHash(adoptedSnapshot) == snapshotSaved
                && keccak256(
                    abi.encode(
                        router.scopedContentRootRecord(adoptedRoot),
                        PolicyRoot(address(router))
                            .scopedPreservationPolicyContentRootBinding(adoptedRoot)
                    )
                ) == rootSaved
        );
        _upload(raw, false);
        require(keccak256(abi.encode(input, signatures, nonce)) == envelope);
        require(
            account.execTransaction(
                address(referenceHost),
                0,
                input,
                0,
                0,
                0,
                0,
                address(0),
                payable(address(0)),
                signatures
            )
        );
        RefT.Receipt memory r = referenceHost.currentReference(referenceInput.scope);
        require(account.nonce() == nonce + 1 && r.observation.recorder == address(account));
        require(
            keccak256(referenceHost.referencePayload(r.observation.recordHash)) == keccak256(raw)
        );
        require(
            referenceHost.requireCurrent(referenceInput.scope, r.observation.recordHash, 1)
                .observation.recordHash == r.observation.recordHash
        );
    }

    function testClassTwoLockHasExactPreimageCurrentnessEventAndNoReplay() public {
        _reference(1, 2);
        bytes32 hash = _publishReference();
        (bytes32 scope, bytes32 oldHash, bytes32 newHash) =
            referenceHost.lockTransition(referenceInput.scope);
        RefT.Receipt memory r = referenceHost.currentReference(referenceInput.scope);
        require(
            scope
                == keccak256(
                    abi.encode(
                        keccak256("6529STREAM_SCOPED_PRESERVATION_POLICY_REFERENCE_LOCK_SCOPE_V1"),
                        block.chainid,
                        address(referenceHost),
                        address(core),
                        referenceInput.scope,
                        r.scopeSubject
                    )
                )
        );
        require(
            oldHash == keccak256(abi.encode(scope, hash, uint64(1), false))
                && newHash == keccak256(abi.encode(scope, hash, uint64(1), true))
        );
        vm.expectRevert(
            abi.encodeWithSelector(RefT.ScopedPolicyReferenceAuthority.selector, address(this))
        );
        referenceHost.lockReference(referenceInput.scope);
        _referenceAction(1, scope, oldHash, newHash);
        vm.expectRevert(
            abi.encodeWithSelector(RefT.ScopedPolicyReferenceAuthority.selector, address(executor))
        );
        vm.prank(address(executor));
        referenceHost.lockReference(referenceInput.scope);
        _referenceAction(2, scope, oldHash, newHash ^ bytes32(uint256(1)));
        vm.expectRevert(
            abi.encodeWithSelector(RefT.ScopedPolicyReferenceAuthority.selector, address(executor))
        );
        vm.prank(address(executor));
        referenceHost.lockReference(referenceInput.scope);
        require(referenceHost.referenceLock(referenceInput.scope).actionId == 0);
        _referenceAction(2, scope, oldHash, newHash);
        vm.recordLogs();
        vm.prank(address(executor));
        referenceHost.lockReference(referenceInput.scope);
        Vm.Log[] memory logs = vm.getRecordedLogs();
        (uint16 version, RefR.Lock memory l) = abi.decode(logs[0].data, (uint16, RefR.Lock));
        require(logs.length == 1 && version == 1 && l.recordHash == hash && l.revision == 1);
        require(logs[0].emitter == address(referenceHost) && logs[0].topics[1] == r.scopeSubject);
        require(
            l.actionId == keccak256("exact scoped policy reference lock")
                && keccak256(abi.encode(l))
                    == keccak256(abi.encode(referenceHost.referenceLock(referenceInput.scope)))
        );
        StreamFinalityComponentState memory c =
            referenceHost.finalityStateForScope(referenceInput.scope);
        require(
            c.frozen
                && c.dataHash
                    == keccak256(
                        abi.encode(
                            keccak256(
                                "6529STREAM_LOCKED_SCOPED_PRESERVATION_POLICY_REFERENCE_COMPONENT_V1"
                            ),
                            block.chainid,
                            address(referenceHost),
                            address(core),
                            referenceInput.scope,
                            r,
                            l
                        )
                    )
        );
        StreamFinalityComponentState memory typedState =
            ReferenceReads.component(_readerDependencies(), referenceInput.scope, hash, 1);
        require(keccak256(abi.encode(typedState)) == keccak256(abi.encode(c)));
        vm.expectRevert(
            abi.encodeWithSelector(RefT.ScopedPolicyReferenceLocked.selector, r.scopeSubject)
        );
        vm.prank(address(executor));
        referenceHost.lockReference(referenceInput.scope);
        referenceInput.observation.referenceId = keccak256("forbidden locked successor");
        referenceInput.observation.expectedHead = hash;
        referenceInput.observation.expectedRevision = 1;
        vm.expectRevert(
            abi.encodeWithSelector(RefT.ScopedPolicyReferenceLocked.selector, r.scopeSubject)
        );
        referenceHost.previewReference(referenceInput, address(this));
    }

    function testTokenTupleProfileAndDefinitionsDoNotBorrowOldRecords() public {
        _reference(1, 1);
        bytes32 hash = _publishReference();
        require(
            referenceHost.supportsInterface(type(RefInterface).interfaceId)
                && !referenceHost.supportsInterface(type(OldRefInterface).interfaceId)
                && !referenceHost.supportsInterface(type(RefV1).interfaceId)
                && !referenceHost.supportsInterface(type(MetricInterface).interfaceId)
        );
        require(
            referenceHost.scopedPreservationPolicyReferenceProfile()
                == keccak256("6529STREAM_SCOPED_PRESERVATION_POLICY_REFERENCE_V1")
        );
        StreamFinalityScope memory wrong = referenceInput.scope;
        wrong.collectionId = 2;
        vm.expectRevert(abi.encodeWithSelector(RefT.InvalidScopedPolicyReference.selector));
        referenceHost.currentReference(wrong);
        vm.expectRevert(abi.encodeWithSelector(RefT.InvalidScopedPolicyReference.selector));
        referenceHost.requireCurrent(wrong, hash, 1);
        vm.expectRevert(abi.encodeWithSelector(RefT.InvalidScopedPolicyReference.selector));
        referenceHost.lockTransition(wrong);
        vm.expectRevert(abi.encodeWithSelector(RefT.InvalidScopedPolicyReference.selector));
        referenceHost.referenceAt(wrong, 0);
        (RefT.Publication memory p, RefT.Receipt memory r) = referenceHost.referenceRecord(hash);
        require(r.observation.recordHash == hash && p.scope.collectionId == 1);
    }

    function testActualRootSuccessorStalesCurrentButPreservesOriginalReference() public {
        _reference(1, 2);
        bytes32 first = _publishReference();
        bytes32 original = _referenceHistory(first);
        bytes32 prior = adoptedRoot;
        adoptedRoot = _adopt(adoptedSnapshot, 1);
        require(
            adoptedRoot != prior
                && router.scopedContentRootRecord(adoptedRoot).publication.expectedPredecessor
                    == prior
        );
        vm.expectRevert(abi.encodeWithSelector(RefT.InvalidScopedPolicyReference.selector));
        referenceHost.requireCurrent(referenceInput.scope, first, 1);
        require(_referenceHistory(first) == original);
        referenceInput.observation.referenceId = keccak256("reference following new root");
        referenceInput.observation.expectedHead = first;
        referenceInput.observation.expectedRevision = 1;
        bytes32 second = _publishReference();
        require(
            referenceHost.requireCurrent(referenceInput.scope, second, 2).observation.predecessor
                == first
        );
        require(
            referenceHost.referenceSource(second).contentRootRecordHash == adoptedRoot
                && _referenceHistory(first) == original
        );
    }

    function testPreservationBytesStaySeparateFromLiveRouterAndProducerDriftStalesCurrent() public {
        _reference(1, 2);
        bytes32 hash = _publishReference();
        bytes32 original = _referenceHistory(hash);
        uint256 token = referenceInput.observation.captures[0].tokenId;
        snapshotVm.mockCall(
            address(router),
            abi.encodeWithSignature("tokenJSON(uint256)", token),
            abi.encode("independent changed live JSON")
        );
        snapshotVm.mockCall(
            address(router),
            abi.encodeWithSignature("tokenHTML(uint256)", token),
            abi.encode("independent changed live HTML")
        );
        require(
            referenceHost.requireCurrent(referenceInput.scope, hash, 1).observation.recordHash
                == hash
        );
        string memory json = snapshotCapture.producers[0].preservationTokenJSON(token);
        string memory html = snapshotCapture.producers[0].preservationTokenHTML(token);
        snapshotCapture.producers[0].setBytes(token, string.concat(json, " "), html);
        vm.expectRevert();
        referenceHost.requireCurrent(referenceInput.scope, hash, 1);
        require(_referenceHistory(hash) == original);
        snapshotCapture.producers[0].setBytes(token, json, html);
        require(
            referenceHost.requireCurrent(referenceInput.scope, hash, 1).observation.recordHash
                == hash
        );
    }

    function testSampleIndependentlyRejoinsEverySavedAdmissionWord() public {
        _reference(1, 2);
        bytes32 hash = _publishReference();
        RefT.SourceFacts memory facts = referenceHost.referenceSource(hash);
        PreservationReferenceSampleProbe probe = new PreservationReferenceSampleProbe();
        RefT.Dependencies memory d = referenceHost.dependencies();
        Snap.Dependencies memory source = snapshotHost.dependencies();
        Content.Output memory original = snapshotContent.outputAt(snapshotCapture.id, 1);
        bytes memory input = abi.encodeCall(Content.outputAt, (snapshotCapture.id, uint256(1)));
        for (uint256 i; i < 7; ++i) {
            bytes memory encoded = abi.encode(original.preservationAdmission);
            encoded[i * 32 + 31] ^= 0x01;
            Content.Output memory bad = abi.decode(abi.encode(original), (Content.Output));
            bad.preservationAdmission = abi.decode(encoded, (P.Admission));
            snapshotVm.mockCall(address(snapshotContent), input, abi.encode(bad));
            vm.expectRevert(abi.encodeWithSelector(RefT.InvalidScopedPolicyReference.selector));
            probe.sample(
                d,
                source,
                referenceInput.scope,
                facts.snapshotSource,
                1,
                referenceInput.observation.captures[1]
            );
        }
        snapshotVm.mockCall(address(snapshotContent), input, abi.encode(original));
        RefT.Sample memory sample = probe.sample(
            d,
            source,
            referenceInput.scope,
            facts.snapshotSource,
            1,
            referenceInput.observation.captures[1]
        );
        require(
            keccak256(abi.encode(sample.preservationAdmission))
                == keccak256(abi.encode(original.preservationAdmission))
        );
    }

    function testSampleRejectsOtherMembersProducerAndMalformedAdmissionReturn() public {
        _reference(1, 2);
        bytes32 hash = _publishReference();
        RefT.SourceFacts memory facts = referenceHost.referenceSource(hash);
        PreservationReferenceSampleProbe probe = new PreservationReferenceSampleProbe();
        RefT.Dependencies memory d = referenceHost.dependencies();
        Snap.Dependencies memory source = snapshotHost.dependencies();
        Content.Output memory original = snapshotContent.outputAt(snapshotCapture.id, 1);
        Content.Output memory bad = abi.decode(abi.encode(original), (Content.Output));
        bad.preservation = snapshotContent.outputAt(snapshotCapture.id, 0).preservation;
        bytes memory input = abi.encodeCall(Content.outputAt, (snapshotCapture.id, uint256(1)));
        snapshotVm.mockCall(address(snapshotContent), input, abi.encode(bad));
        vm.expectRevert(abi.encodeWithSelector(P.InvalidPreservationBinding.selector));
        probe.sample(
            d,
            source,
            referenceInput.scope,
            facts.snapshotSource,
            1,
            referenceInput.observation.captures[1]
        );
        snapshotVm.mockCall(address(snapshotContent), input, abi.encode(original));
        Capture memory c = snapshotCapture;
        _setAdmission(c, 1, new bytes(480));
        vm.expectRevert();
        probe.sample(
            d,
            source,
            referenceInput.scope,
            facts.snapshotSource,
            1,
            referenceInput.observation.captures[1]
        );
        _setAdmission(c, 1, abi.encode(_binding(c, 1), _admission(c, 1)));
        require(
            probe.sample(
                    d,
                    source,
                    referenceInput.scope,
                    facts.snapshotSource,
                    1,
                    referenceInput.observation.captures[1]
                ).observation.tokenId == 92
        );
    }

    function testTypedReferenceReaderPreservesOriginalAfterRootDriftAndRejectsWrongCapability()
        public
    {
        _reference(1, 1);
        bytes32 hash = _publishReference();
        ReferenceReads.Dependencies memory d = _readerDependencies();
        (RefT.Publication memory p, RefT.Receipt memory saved) =
            ReferenceReads.original(d, referenceInput.scope, hash, 1);
        require(keccak256(abi.encode(p)) == keccak256(abi.encode(referenceInput)));
        require(
            ReferenceReads.requireCurrent(d, referenceInput.scope, hash, 1).observation.recordHash
                == hash
        );
        StreamFinalityScope memory wrong = referenceInput.scope;
        wrong.collectionId = 2;
        vm.expectRevert(
            abi.encodeWithSelector(
                ReferenceReads.InvalidScopedPreservationPolicyReferenceEvidence.selector
            )
        );
        ReferenceReads.original(d, wrong, hash, 1);
        snapshotVm.mockCall(
            address(referenceHost),
            abi.encodeWithSignature("supportsInterface(bytes4)", type(RefInterface).interfaceId),
            abi.encode(false)
        );
        vm.expectRevert(
            abi.encodeWithSelector(
                ReferenceReads.InvalidScopedPreservationPolicyReferenceEvidence.selector
            )
        );
        ReferenceReads.original(d, referenceInput.scope, hash, 1);
        snapshotVm.mockCall(
            address(referenceHost),
            abi.encodeWithSignature("supportsInterface(bytes4)", type(RefInterface).interfaceId),
            abi.encode(true)
        );
        snapshotVm.mockCall(
            address(referenceHost),
            abi.encodeCall(RefInterface.scopedPreservationPolicyReferenceProfile, ()),
            abi.encode(keccak256("6529STREAM_SCOPED_POLICY_REFERENCE_V2"))
        );
        vm.expectRevert(
            abi.encodeWithSelector(
                ReferenceReads.InvalidScopedPreservationPolicyReferenceEvidence.selector
            )
        );
        ReferenceReads.original(d, referenceInput.scope, hash, 1);
        snapshotVm.mockCall(
            address(referenceHost),
            abi.encodeCall(RefInterface.scopedPreservationPolicyReferenceProfile, ()),
            abi.encode(keccak256("6529STREAM_SCOPED_PRESERVATION_POLICY_REFERENCE_V1"))
        );
        _adopt(adoptedSnapshot, 1);
        (, RefT.Receipt memory historical) =
            ReferenceReads.original(d, referenceInput.scope, hash, 1);
        require(keccak256(abi.encode(historical)) == keccak256(abi.encode(saved)));
        vm.expectRevert(
            abi.encodeWithSignature(
                "RouterEvidenceRead(address,bytes4)",
                address(referenceHost),
                RefInterface.requireCurrent.selector
            )
        );
        ReferenceReads.requireCurrent(d, referenceInput.scope, hash, 1);
    }

    function testReferenceInventoryTraversesEveryOriginalMemberAndCaptureInExactOrder() public {
        _reference(1, 2);
        bytes32 hash = _publishReference();
        RefT.SourceFacts memory f = referenceHost.referenceSource(hash);
        ReferenceInventory.Context memory c = ReferenceInventory.Context(
            referenceInput.scope,
            f.scopeSubject,
            SNAPSHOT_ARTIST,
            f.snapshot,
            referenceHost.currentReference(referenceInput.scope)
        );
        InventorySources.Dependencies memory d;
        d.targets[6] = address(referenceHost);
        d.targets[11] = address(externalArchive);
        d.readGas = 2000000;
        d.sourceGas = 8000000;
        (Inventory.Item[] memory rows, uint64 total) = ReferenceInventory.items(d, c, 0, 64);
        require(total == 10 && rows.length == total);
        require(
            rows[0].role == keccak256("SCOPED_PRESERVATION_POLICY_REFERENCE_MANIFEST")
                && rows[0].schemaId == RefDocuments.SCHEMA_ID
        );
        require(rows[1].role == keccak256("REFERENCE_ENVIRONMENT_DECLARATION"));
        require(rows[2].role == keccak256("RUNNABLE_ENGINE_TOOLCHAIN_ZIP"));
        require(
            rows[3].role == keccak256("RUNNABLE_PACKAGE_MEMBER")
                && rows[4].role == keccak256("RUNNABLE_PACKAGE_MEMBER")
        );
        require(rows[5].role == keccak256("NATIVE_OS_PREREQUISITE"));
        for (uint64 i; i < total; ++i) {
            (Inventory.Item[] memory page, uint64 count) = ReferenceInventory.items(d, c, i, 1);
            require(
                count == total && page.length == 1
                    && keccak256(abi.encode(page[0])) == keccak256(abi.encode(rows[i]))
            );
            if (i >= 6) {
                require(
                    rows[i].role
                        == (i % 2 == 0
                                ? keccak256("REFERENCE_CAPTURE")
                                : keccak256("REFERENCE_CAPTURE_DECLARATION"))
                );
            }
        }
        vm.expectRevert(abi.encodeWithSelector(Inventory.InvalidInventorySegment.selector));
        ReferenceInventory.items(d, c, total, 1);
        vm.expectRevert(abi.encodeWithSelector(Inventory.InvalidInventorySegment.selector));
        ReferenceInventory.items(d, c, 0, 65);
        c.scope.collectionId = 2;
        vm.expectRevert(abi.encodeWithSelector(Inventory.InventorySourceChanged.selector));
        ReferenceInventory.items(d, c, 0, 1);
    }
}
