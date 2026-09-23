// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "./StreamScopedPreservationPolicyReferencePublicationV1Fixture.sol";

contract StreamScopedPreservationPolicyReferencePublicationV1Test is
    ScopedPreservationReferenceFixtureV1
{
    function testCapacityReferenceFamilyDeploymentKeepsProfileGateAndCreateArguments() public {
        _reference(1, 2);
        RefT.Dependencies memory d = referenceHost.dependencies();
        CapacityReferenceGraph454.Recipe memory r;
        CapacityReferenceGraph454.Graph memory g;
        for (uint256 i; i < 5; ++i) {
            r.inventory.targets[i] = d.targets[i];
            r.inventory.codeHashes[i] = d.codeHashes[i];
        }
        r.inventory.chainId = d.chainId;
        r.targets[3] = address(executor);
        r.codeHashes[3] = address(executor).codehash;
        g.children[3] = d.targets[5];
        g.codeHashes[3] = d.codeHashes[5];
        r.inventory.targets[11] = d.targets[6];
        r.inventory.codeHashes[11] = d.codeHashes[6];
        r.referenceGas[0] = CapacityReferenceGas454.GasParameterConfig(
            "SCOPED_POLICY_REFERENCE_READ_GAS", d.readGas, 50000, 1
        );
        r.referenceGas[1] = CapacityReferenceGas454.GasParameterConfig(
            "SCOPED_POLICY_REFERENCE_SOURCE_GAS", d.sourceGas, 50000, 1
        );
        r.referenceGas[2] = CapacityReferenceGas454.GasParameterConfig(
            "SCOPED_POLICY_REFERENCE_SNAPSHOT_GAS", d.snapshotGas, 50000, 1
        );
        r.referenceGas[3] = CapacityReferenceGas454.GasParameterConfig(
            "SCOPED_POLICY_REFERENCE_ARCHIVE_GAS", d.archiveGas, 50000, 1
        );
        uint64 nonce = CapacityReferenceCreateVm454(address(vm)).getNonce(address(this));

        vm.expectRevert(abi.encodeWithSelector(RefT.InvalidScopedPolicyReference.selector));
        CapacityReferenceDeploy454.deploy(r, g);
        require(
            CapacityReferenceCreateVm454(address(vm)).getNonce(address(this)) == nonce,
            "old snapshot profile refuses without consuming CREATE"
        );
        // Only the existing snapshot profile getter is a typed constructor boundary here.
        // No claim that the original V1 payload becomes a genuine V2 snapshot/reference.
        StaticRouteVm(address(vm))
            .mockCall(
                d.targets[5],
                abi.encodeWithSignature("scopedPreservationPolicySnapshotProfile()"),
                abi.encode(keccak256("6529STREAM_SCOPED_PRESERVATION_POLICY_SNAPSHOT_V2"))
            );

        CapacityReferenceV2 child = CapacityReferenceV2(CapacityReferenceDeploy454.deploy(r, g));
        require(
            address(child)
                    == CapacityReferenceCreateVm454(address(vm))
                        .computeCreateAddress(address(this), nonce)
                && CapacityReferenceCreateVm454(address(vm)).getNonce(address(this)) == nonce + 1,
            "original host caller and one CREATE"
        );
        require(
            keccak256(abi.encode(child.dependencies())) == keccak256(abi.encode(d))
                && child.governanceAuthority() == address(executor)
                && child.executorCodeHash() == address(executor).codehash,
            "all seven dependencies and four gas parameters preserved"
        );
        require(
            child.core() == d.targets[0] && child.metadataHost() == d.targets[1]
                && child.metadataRouter() == d.targets[4] && child.snapshots() == d.targets[5]
                && child.archiveCoverage() == d.targets[6]
                && child.deploymentChainId() == block.chainid,
            "original constructor immutables"
        );

        require(
            child.scopedPreservationPolicyReferenceProfile()
                    == keccak256("6529STREAM_SCOPED_PRESERVATION_POLICY_REFERENCE_V2")
                && referenceHost.scopedPreservationPolicyReferenceProfile()
                    == keccak256("6529STREAM_SCOPED_PRESERVATION_POLICY_REFERENCE_V1"),
            "fixed profiles remain distinct"
        );
        StaticRouteVm(address(vm))
            .mockCall(
                d.targets[5],
                abi.encodeWithSignature("scopedPreservationPolicySnapshotProfile()"),
                abi.encode(keccak256("6529STREAM_SCOPED_PRESERVATION_POLICY_SNAPSHOT_V1"))
            );
        bytes32 record = _publishReference();
        require(
            referenceHost.requireCurrent(referenceInput.scope, record, 1).observation.recordHash
                    == record && child.referenceCount(referenceInput.scope) == 0,
            "original profile publication never writes new child history"
        );
    }

    /// @dev Actual Operations and retained Store bytes; the suite's named source/archive
    /// boundaries remain explicit. No browser replay or whole-stack gas claim.
    function testCapacityReferenceOperationsRetainCallerEventAndAtomicRetry() public {
        _reference(1, 2);
        address recorder = address(0xCA454);
        _familyGrant(referenceInput.scope.collectionId, Families.CURATOR, 3, recorder, true);
        bytes memory raw = _referenceBytes(recorder);
        _upload(raw, false);
        bytes32 sources = referenceInput.observation.expectedSourcesHash;
        referenceInput.observation.expectedSourcesHash =
            keccak256("wrong capacity reference sources");
        vm.expectRevert(abi.encodeWithSelector(RefT.InvalidScopedPolicyReference.selector));
        vm.prank(recorder);
        referenceHost.publishReference(referenceInput);
        referenceInput.observation.expectedSourcesHash = sources;
        _familyGrant(referenceInput.scope.collectionId, Families.CURATOR, 3, recorder, false);
        vm.expectRevert(
            abi.encodeWithSelector(RefT.ScopedPolicyReferenceAuthority.selector, recorder)
        );
        vm.prank(recorder);
        referenceHost.publishReference(referenceInput);
        require(
            referenceHost.referenceCount(referenceInput.scope) == 0
                && referenceHost.currentReference(referenceInput.scope).observation.recordHash == 0,
            "source or authority refusal consumes no id or head"
        );
        _familyGrant(referenceInput.scope.collectionId, Families.CURATOR, 3, recorder, true);
        raw = _referenceBytes(recorder);
        _upload(raw, false);
        RefT.Receipt memory expected;
        {
            (
                bytes32 payloadDomain,
                uint256 chain,
                address producer,
                RefT.Publication memory normalized,
                RefT.Receipt memory receipt,,
            ) = abi.decode(
                raw,
                (bytes32, uint256, address, RefT.Publication, RefT.Receipt, RefT.SourceFacts, bytes)
            );
            require(
                payloadDomain
                        == keccak256("6529STREAM_SCOPED_PRESERVATION_POLICY_REFERENCE_PAYLOAD_V1")
                    && chain == block.chainid && producer == address(referenceHost),
                "original payload host and domain"
            );
            require(
                normalized.observation.expectedSourcesHash == 0
                    && receipt.observation.sourcesHash
                        == referenceInput.observation.expectedSourcesHash
                    && receipt.observation.recorder == recorder
                    && receipt.observation.authorizationClass == 3
                    && receipt.observation.grantRevision == 3 && receipt.observation.recordHash == 0
                    && receipt.observation.recordChainHash == 0
                    && receipt.observation.payloadHash == 0 && receipt.observation.payloadBytes == 0
                    && receipt.observation.recordedAt == 0,
                "canonical receipt keeps real recorder and fresh grant"
            );
            expected = receipt;
        }
        expected.observation.payloadHash = keccak256(raw);
        expected.observation.payloadBytes = uint32(raw.length);
        expected.observation.recordedAt = uint64(block.timestamp);
        bytes32 literalRecord = keccak256(
            abi.encode(
                keccak256("6529STREAM_SCOPED_PRESERVATION_POLICY_REFERENCE_RECORD_V1"),
                block.chainid,
                address(referenceHost),
                address(core),
                address(metadata),
                referenceInput,
                expected
            )
        );

        vm.recordLogs();
        vm.prank(recorder);
        bytes32 record = referenceHost.publishReference(referenceInput);
        Vm.Log[] memory logs = vm.getRecordedLogs();
        require(record == literalRecord, "delegate host and original caller remain in record");
        expected.observation.recordHash = record;
        expected.observation.recordChainHash = keccak256(
            abi.encode(
                keccak256("6529STREAM_SCOPED_PRESERVATION_POLICY_REFERENCE_CHAIN_V1"),
                block.chainid,
                address(referenceHost),
                address(core),
                expected.scopeSubject,
                bytes32(0),
                uint64(1),
                record
            )
        );
        (RefT.Publication memory stored, RefT.Receipt memory receipt) =
            referenceHost.referenceRecord(record);
        require(
            keccak256(abi.encode(stored)) == keccak256(abi.encode(referenceInput))
                && keccak256(abi.encode(receipt)) == keccak256(abi.encode(expected)),
            "all original publication and receipt fields retained"
        );
        require(
            logs.length == 1 && logs[0].emitter == address(referenceHost)
                && logs[0].topics.length == 4,
            "original host event only"
        );
        require(
            logs[0].topics[0]
                    == keccak256(
                        "ScopedPolicyReferencePublished(uint16,bytes32,bytes32,bytes32,(bytes32,(bytes32,bytes32,uint256,bytes32,bytes32,uint64,bytes32,uint32,bytes32,bytes32,uint64,address,uint8,uint64,uint64,uint64,bytes32,bytes32,bytes32,bytes32)),string)"
                    ) && logs[0].topics[1] == expected.scopeSubject
                && logs[0].topics[2] == referenceInput.observation.referenceId
                && logs[0].topics[3] == record,
            "exact event signature and indexed fields"
        );
        (uint16 version, RefT.Receipt memory eventReceipt, string memory uri) =
            abi.decode(logs[0].data, (uint16, RefT.Receipt, string));
        require(
            version == 1 && keccak256(abi.encode(eventReceipt)) == keccak256(abi.encode(expected))
                && keccak256(bytes(uri))
                    == keccak256(bytes(referenceInput.observation.manifestURI)),
            "full original event tuple"
        );
        require(
            keccak256(referenceHost.referencePayload(record)) == keccak256(raw)
                && keccak256(
                        abi.encode(referenceHost.requireCurrent(referenceInput.scope, record, 1))
                    ) == keccak256(abi.encode(expected)),
            "current and historical receipt agree"
        );
        bytes32 original = keccak256(abi.encode(stored, receipt, raw));
        vm.expectRevert(abi.encodeWithSelector(RefT.InvalidScopedPolicyReference.selector));
        vm.prank(recorder);
        referenceHost.publishReference(referenceInput);
        require(
            referenceHost.referenceCount(referenceInput.scope) == 1,
            "exact reference id cannot replay"
        );
        referenceInput.observation.referenceId = keccak256("capacity reference successor");
        vm.expectRevert(
            abi.encodeWithSelector(RefT.ScopedPolicyReferenceLineage.selector, bytes32(0), record)
        );
        vm.prank(recorder);
        referenceHost.publishReference(referenceInput);
        require(
            referenceHost.referenceCount(referenceInput.scope) == 1
                && referenceHost.referenceAt(referenceInput.scope, 0) == record,
            "stale lineage cannot consume successor id"
        );
        referenceInput.observation.expectedHead = record;
        referenceInput.observation.expectedRevision = 1;
        _upload(_referenceBytes(recorder), false);
        vm.prank(recorder);
        bytes32 successor = referenceHost.publishReference(referenceInput);
        require(
            referenceHost.requireCurrent(referenceInput.scope, successor, 2).observation.predecessor
                    == record && referenceHost.referenceCount(referenceInput.scope) == 2,
            "same refused id succeeds with exact lineage"
        );
        (stored, receipt) = referenceHost.referenceRecord(record);
        require(
            keccak256(abi.encode(stored, receipt, referenceHost.referencePayload(record)))
                == original,
            "successor cannot rewrite original history"
        );
    }

    function testActualReleaseReferenceBindsOriginalRootFactoryAndMixedPolicySamples() public {
        _reference(1, 2);
        bytes memory raw = _referenceBytes(address(this));
        _upload(raw, false);
        vm.recordLogs();
        bytes32 hash = referenceHost.publishReference(referenceInput);
        Vm.Log[] memory logs = vm.getRecordedLogs();
        require(logs.length == 1 && logs[0].emitter == address(referenceHost));
        (uint16 version, RefT.Receipt memory eventReceipt, string memory uri) =
            abi.decode(logs[0].data, (uint16, RefT.Receipt, string));
        RefT.Receipt memory r = referenceHost.requireCurrent(referenceInput.scope, hash, 1);
        require(version == 1 && logs[0].topics.length == 4);
        require(
            logs[0].topics[1] == r.scopeSubject
                && logs[0].topics[2] == referenceInput.observation.referenceId
                && logs[0].topics[3] == hash
        );
        require(keccak256(bytes(uri)) == keccak256(bytes(referenceInput.observation.manifestURI)));
        require(keccak256(abi.encode(eventReceipt)) == keccak256(abi.encode(r)));
        require(
            r.observation.payloadHash == keccak256(raw)
                && keccak256(referenceHost.referencePayload(hash)) == keccak256(raw)
        );
        RefT.SourceFacts memory f = referenceHost.referenceSource(hash);
        _assertReferencePayload(raw, f);
        require(
            r.observation.recordChainHash
                == keccak256(
                    abi.encode(
                        keccak256("6529STREAM_SCOPED_PRESERVATION_POLICY_REFERENCE_CHAIN_V1"),
                        block.chainid,
                        address(referenceHost),
                        address(core),
                        r.scopeSubject,
                        bytes32(0),
                        uint64(1),
                        hash
                    )
                )
        );
        require(f.contentRootRecordHash == adoptedRoot && f.snapshot.recordHash == adoptedSnapshot);
        require(
            abi.encode(f.contentRootBinding).length == 800
                && f.contentRootBinding.metadataRouter == address(router)
                && f.contentRootBinding.preservationOutputProfile
                    == keccak256("6529STREAM_PRESERVATION_RENDER_V1")
        );
        for (uint256 i; i < f.samples.length; ++i) {
            require(abi.encode(f.samples[i]).length == 2560);
            Content.Output memory row = snapshotContent.outputAt(snapshotCapture.id, i);
            require(
                keccak256(abi.encode(f.samples[i].preservation, f.samples[i].preservationAdmission))
                    == keccak256(abi.encode(row.preservation, row.preservationAdmission))
            );
        }
        require(
            f.samples[0].preservation.producer != f.samples[1].preservation.producer
                && f.samples[0].preservation.liveRenderer != f.samples[1].preservation.liveRenderer
        );
        require(
            keccak256(abi.encode(f.contentRoot))
                == keccak256(abi.encode(router.scopedContentRootRecord(adoptedRoot)))
        );
        require(
            keccak256(abi.encode(f.contentRootBinding))
                == keccak256(
                    abi.encode(
                        PolicyRoot(address(router))
                            .scopedPreservationPolicyContentRootBinding(adoptedRoot)
                    )
                )
        );
        require(
            f.contentRootBinding.profileId == RootDocuments.PROFILE
                && f.contentRootBinding.sourceFactory == address(scopedFactory)
        );
        require(
            f.contentRootBinding.factoryDependenciesHash
                == keccak256(abi.encode(_scopedDependencies()))
        );
        require(
            f.samples.length == 2 && f.samples[0].membershipIndex == 0
                && f.samples[1].membershipIndex == 1
        );
        require(
            f.samples[0].observation.tokenId == 91 && f.samples[0].observation.collectionSerial == 1
        );
        require(
            f.samples[1].observation.tokenId == 92 && f.samples[1].observation.collectionSerial == 2
        );
        require(
            f.samples[0].entropy.terminal && !f.samples[0].entropy.finalized
                && f.samples[0].entropy.seed == 0 && f.samples[0].terminalAdmissionHash != 0
        );
        require(
            !f.samples[1].entropy.terminal && f.samples[1].entropy.finalized
                && f.samples[1].entropy.seed == scopedFinalizedSeed
                && f.samples[1].terminalAdmissionHash == 0
        );
        require(
            r.observation.sourcesHash
                == keccak256(
                    abi.encode(
                        keccak256("6529STREAM_SCOPED_PRESERVATION_POLICY_REFERENCE_SOURCES_V1"),
                        block.chainid,
                        address(referenceHost),
                        referenceHost.dependencies().targets,
                        referenceHost.dependencies().codeHashes,
                        f
                    )
                )
        );
        RefT.Receipt memory fields = abi.decode(abi.encode(r), (RefT.Receipt));
        fields.observation.recordHash = 0;
        fields.observation.recordChainHash = 0;
        require(
            hash
                == keccak256(
                    abi.encode(
                        keccak256("6529STREAM_SCOPED_PRESERVATION_POLICY_REFERENCE_RECORD_V1"),
                        block.chainid,
                        address(referenceHost),
                        address(core),
                        address(metadata),
                        referenceInput,
                        fields
                    )
                )
        );
        require(
            snapshotHost.requireCurrent(publication.scope, adoptedSnapshot, 1).recordHash
                == adoptedSnapshot
        );
        require(
            snapshotOutputs.requireCurrentManifest(
                publication.outputManifestRecord, SNAPSHOT_ARTIST
            )
            .manifestHash == f.snapshotSource.outputs.manifestHash
        );
    }

    function testActualSeasonNotRequiredRowStaysTerminalAndFinalizedRowKeepsSeed() public {
        _reference(2, 3);
        bytes32 hash = _publishReference();
        RefT.SourceFacts memory f = referenceHost.referenceSource(hash);
        require(f.snapshotSource.scope.scopeType == StreamFinalityScopeType.SEASON);
        require(
            f.samples[0].entropy.status == 2 && f.samples[0].entropy.mode == 2
                && f.samples[0].entropy.renderRequirement == 1
        );
        require(
            f.samples[0].entropy.terminal && !f.samples[0].entropy.finalized
                && f.samples[0].observation.seed == 0
        );
        require(
            f.samples[1].entropy.status == 5 && f.samples[1].observation.seed == scopedFinalizedSeed
        );
        require(
            referenceHost.requireCurrent(referenceInput.scope, hash, 1).observation.recordHash
                == hash
        );
    }

    function testEveryDeclaredRootInterpretationRemainsExact() public {
        _reference(1, 2);
        bytes32 hash = _publishReference();
        bytes32 saved = _referenceHistory(hash);
        PolicyRoot.Binding memory original =
            PolicyRoot(address(router)).scopedPreservationPolicyContentRootBinding(adoptedRoot);
        for (uint256 i; i < 6; ++i) {
            PolicyRoot.Binding memory bad = abi.decode(abi.encode(original), (PolicyRoot.Binding));
            if (i == 0) bad.profileId = 0;
            else if (i == 1) bad.factoryDependenciesHash ^= bytes32(uint256(1));
            else if (i == 2) bad.snapshotProfileHash ^= bytes32(uint256(1));
            else if (i == 3) bad.outputRoot ^= bytes32(uint256(1));
            else if (i == 4) bad.metadataRouter = address(snapshotContent);
            else bad.preservationOutputProfile = keccak256("wrong projection");
            snapshotVm.mockCall(
                address(router),
                abi.encodeCall(
                    PolicyRoot.scopedPreservationPolicyContentRootBinding, (adoptedRoot)
                ),
                abi.encode(bad)
            );
            vm.expectRevert(abi.encodeWithSelector(RefT.InvalidScopedPolicyReference.selector));
            referenceHost.requireCurrent(referenceInput.scope, hash, 1);
        }
        snapshotVm.mockCall(
            address(router),
            abi.encodeCall(PolicyRoot.scopedPreservationPolicyContentRootBinding, (adoptedRoot)),
            abi.encode(original)
        );
        require(
            referenceHost.requireCurrent(referenceInput.scope, hash, 1).observation.recordHash
                == hash
        );
        require(_referenceHistory(hash) == saved);
    }

    function testSnapshotDeclaredOutputReceiptCannotBeReplacedByDifferentOriginalTuple() public {
        _reference(1, 2);
        bytes32 hash = _publishReference();
        bytes32 saved = _referenceHistory(hash);
        Outputs.Manifest memory original =
            snapshotOutputs.manifestRecord(publication.outputManifestRecord);
        Outputs.Manifest memory changed = original;
        changed.artifactHash ^= bytes32(uint256(1));
        snapshotVm.mockCall(
            address(snapshotOutputs),
            abi.encodeCall(Outputs.manifestRecord, (publication.outputManifestRecord)),
            abi.encode(changed)
        );
        // Snapshot currentness reads requireCurrentManifest and still authenticates the actual tuple.
        // The separate exact original-record join in Reference catches this conflicting getter.
        require(
            snapshotHost.requireCurrent(publication.scope, adoptedSnapshot, 1).recordHash
                == adoptedSnapshot
        );
        vm.expectRevert(abi.encodeWithSelector(RefT.InvalidScopedPolicyReference.selector));
        referenceHost.requireCurrent(referenceInput.scope, hash, 1);
        changed.artifactHash ^= bytes32(uint256(1));
        snapshotVm.mockCall(
            address(snapshotOutputs),
            abi.encodeCall(Outputs.manifestRecord, (publication.outputManifestRecord)),
            abi.encode(changed)
        );
        require(
            referenceHost.requireCurrent(referenceInput.scope, hash, 1).observation.recordHash
                == hash
        );
        require(_referenceHistory(hash) == saved);
    }

    function testArchiveCurrentPairFailurePreservesOriginalAndNewNonzeroFixityCanRefresh() public {
        _reference(1, 1);
        bytes32 hash = _publishReference();
        bytes32 saved = _referenceHistory(hash);
        RefR.Capture memory capture = referenceInput.observation.captures[0];
        External.Coverage memory e =
            ExternalArchive(address(externalArchive)).coverage(capture.coverageHash);
        External.CurrentPair memory pair = External.CurrentPair(
            e.objectHash,
            e.artistId,
            e.contentHash,
            e.sha256Digest,
            e.arweaveDataRoot,
            e.byteSize,
            e.firstFamilyRecordHash,
            e.secondFamilyRecordHash,
            e.firstReceiptHash,
            e.secondReceiptHash,
            bytes32(0),
            e.secondFixityHash,
            e.checkpointHash,
            e.profileHash
        );
        bytes memory input = abi.encodeCall(
            IStreamExternalArtifactCurrentPair.currentReceiptPair,
            (e.firstReceiptHash, e.secondReceiptHash, e.artistId, e.objectHash)
        );
        snapshotVm.mockCall(address(externalArchive), input, abi.encode(pair));
        vm.expectRevert(abi.encodeWithSelector(RefR.InvalidReferenceRender.selector));
        referenceHost.requireCurrent(referenceInput.scope, hash, 1);
        require(_referenceHistory(hash) == saved);
        pair.firstFixityHash = keccak256("new current nonzero fixity boundary");
        snapshotVm.mockCall(address(externalArchive), input, abi.encode(pair));
        require(
            referenceHost.requireCurrent(referenceInput.scope, hash, 1).observation.recordHash
                == hash
        );
        require(_referenceHistory(hash) == saved);
    }

    function testByteExactSamplesDoNotAcceptMetricLikeDriftOrWrongOrdinal() public {
        _reference(1, 2);
        _referenceBytes(address(this));
        require(!referenceHost.supportsInterface(type(MetricInterface).interfaceId));
        bytes32 repeat = referenceInput.observation.captures[0].repeatCaptureSha256[1];
        referenceInput.observation.captures[0].repeatCaptureSha256[1] ^= bytes32(uint256(1));
        vm.expectRevert(abi.encodeWithSelector(RefT.InvalidScopedPolicyReference.selector));
        referenceHost.previewReference(referenceInput, address(this));
        referenceInput.observation.captures[0].repeatCaptureSha256[1] = repeat;
        uint256 token = referenceInput.observation.captures[0].tokenId;
        referenceInput.observation.captures[0].tokenId =
        referenceInput.observation.captures[1].tokenId;
        vm.expectRevert(abi.encodeWithSelector(RefT.InvalidScopedPolicyReference.selector));
        referenceHost.previewReference(referenceInput, address(this));
        referenceInput.observation.captures[0].tokenId = token;
        referenceInput.observation.captures[0].collectionSerial += 1;
        vm.expectRevert(abi.encodeWithSelector(RefT.InvalidScopedPolicyReference.selector));
        referenceHost.previewReference(referenceInput, address(this));
        referenceInput.observation.captures[0].collectionSerial -= 1;
        bytes32 hash = _publishReference();
        require(
            referenceHost.requireCurrent(referenceInput.scope, hash, 1).observation.recordHash
                == hash
        );
    }

    function testCanonicalCaptureBytesAndEnvironmentCannotBeSubstituted() public {
        _reference(1, 2);
        _referenceBytes(address(this));
        bytes memory html = referenceInput.observation.captures[0].animationHTML;
        referenceInput.observation.captures[0].animationHTML = bytes.concat(html, hex"20");
        vm.expectRevert(abi.encodeWithSelector(RefT.InvalidScopedPolicyReference.selector));
        referenceHost.previewReference(referenceInput, address(this));
        referenceInput.observation.captures[0].animationHTML = html;
        bytes32 environment = referenceInput.observation.captures[1].environmentManifestHash;
        referenceInput.observation.captures[1].environmentManifestHash ^= bytes32(uint256(1));
        vm.expectRevert(abi.encodeWithSelector(RefT.InvalidScopedPolicyReference.selector));
        referenceHost.previewReference(referenceInput, address(this));
        referenceInput.observation.captures[1].environmentManifestHash = environment;
        bytes32 hash = _publishReference();
        require(referenceHost.referenceSource(hash).environmentCoverage.artistId == SNAPSHOT_ARTIST);
    }

    function testReferenceAuthorityIsCuratorWithOriginalCollectionPrecedence() public {
        _reference(1, 1);
        address recorder = address(0xA117);
        _familyGrant(1, Families.SNAPSHOT, 7, recorder, true);
        vm.expectRevert(
            abi.encodeWithSelector(RefT.ScopedPolicyReferenceAuthority.selector, recorder)
        );
        referenceHost.previewReference(referenceInput, recorder);
        _familyGrant(0, Families.CURATOR, 8, recorder, true);
        _familyGrant(1, Families.CURATOR, 3, recorder, true);
        _upload(_referenceBytes(recorder), false);
        vm.prank(recorder);
        bytes32 hash = referenceHost.publishReference(referenceInput);
        RefT.Receipt memory r = referenceHost.requireCurrent(referenceInput.scope, hash, 1);
        require(
            r.observation.recorder == recorder && r.observation.authorizationClass == 3
                && r.observation.grantRevision == 1
        );
        _familyGrant(1, Families.CURATOR, 3, recorder, false);
        require(
            referenceHost.requireCurrent(referenceInput.scope, hash, 1).observation.recordHash
                == hash
        );
        referenceInput.observation.referenceId = keccak256("global curator successor");
        referenceInput.observation.expectedHead = hash;
        referenceInput.observation.expectedRevision = 1;
        _upload(_referenceBytes(recorder), false);
        vm.prank(recorder);
        bytes32 second = referenceHost.publishReference(referenceInput);
        require(
            referenceHost.requireCurrent(referenceInput.scope, second, 2).observation
                .authorizationClass == 8
        );
    }
}
