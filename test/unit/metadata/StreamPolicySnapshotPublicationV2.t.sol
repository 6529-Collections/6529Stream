// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamPolicyPublicationGraphTypesV2 as SnapshotGraph442
} from "../../../smart-contracts/interfaces/stream/finality/StreamPolicyPublicationGraphTypesV2.sol";
import {
    StreamPolicyPublicationSnapshotDeploymentV2 as SnapshotDeployment442
} from "../../../smart-contracts/domains/finality/StreamPolicyPublicationSnapshotDeploymentV2.sol";
import {
    LeafManifestVm as SnapshotCreateVm442
} from "../../helpers/scoped-preservation-boundaries/StreamContentLeafManifestVm.sol";
import { Vm } from "../../regression/legacy/helpers/CharacterizationTestBase.sol";

import "../../helpers/PolicySnapshotFixtureV2.sol";
import {
    StreamFinalityPolicySnapshotReadsV2 as Reader
} from "../../../smart-contracts/domains/finality/StreamFinalityPolicySnapshotReadsV2.sol";

contract PolicySnapshotReaderProbeV2 {
    function current(
        Reader.Dependencies calldata d,
        StreamFinalityScope calldata scope,
        bytes32 hash,
        uint64 revision
    ) external view returns (Reader.Evidence memory) {
        return Reader.requireCurrent(d, scope, hash, revision);
    }
}

/// @dev Actual Metadata/schema/Store/membership/inventory/snapshot and 2-of-2 Safe. Core/Artist,
/// canonical Router root, selection/output, policy source set and governance are typed boundaries.
/// No selected-provider, current-stack or finality acceptance claim follows from this cohort.
contract StreamPolicySnapshotPublicationV2Test is PolicySnapshotFixtureV2 {
    /// @dev Actual deployment worker and new child publish; no moved helper is mocked.
    function testCapacitySnapshotDeploymentPreservesCreateArgumentsAndIndependentHistory() public {
        _initializePolicySnapshot();
        Scoped.Dependencies memory d = host.dependencies();
        SnapshotGraph442.Recipe memory r;
        SnapshotGraph442.Graph memory g;
        for (uint256 i; i < 5; ++i) {
            r.inventory.targets[i] = d.targets[i];
            r.inventory.codeHashes[i] = d.codeHashes[i];
        }
        r.inventory.chainId = d.chainId;
        r.targets[0] = d.targets[5];
        r.codeHashes[0] = d.codeHashes[5];
        r.targets[1] = d.targets[6];
        r.codeHashes[1] = d.codeHashes[6];
        r.targets[3] = address(executor);
        r.codeHashes[3] = address(executor).codehash;
        r.inventory.targets[10] = d.targets[9];
        r.inventory.codeHashes[10] = d.codeHashes[9];
        g.children[1] = d.targets[7];
        g.codeHashes[1] = d.codeHashes[7];
        g.children[2] = d.targets[8];
        g.codeHashes[2] = d.codeHashes[8];
        g.sourceSet = d.targets[10];
        g.sourceSetCodeHash = d.codeHashes[10];
        r.snapshotGas[0] = IStreamGasParameterHost.GasParameterConfig(
            "POLICY_SNAPSHOT_READ_GAS", d.readGas, 50000, 2
        );
        r.snapshotGas[1] = IStreamGasParameterHost.GasParameterConfig(
            "POLICY_SNAPSHOT_SOURCE_GAS", d.sourceGas, 50000, 2
        );
        r.snapshotGas[2] = IStreamGasParameterHost.GasParameterConfig(
            "POLICY_SNAPSHOT_INVENTORY_GAS", d.inventoryGas, 50000, 2
        );

        uint64 nonce = SnapshotCreateVm442(address(vm)).getNonce(address(this));
        StreamPolicySnapshotPublicationV2 deployed =
            StreamPolicySnapshotPublicationV2(SnapshotDeployment442.deploy(r, g));
        require(
            address(deployed)
                == SnapshotCreateVm442(address(vm)).computeCreateAddress(address(this), nonce),
            "same host CREATE caller and nonce"
        );
        require(
            SnapshotCreateVm442(address(vm)).getNonce(address(this)) == nonce + 1,
            "exactly one child CREATE"
        );
        require(
            keccak256(abi.encode(deployed.dependencies())) == keccak256(abi.encode(d))
                && deployed.governanceAuthority() == address(executor)
                && deployed.authorityCodeHash() == address(executor).codehash,
            "complete projected arguments and immutable authority"
        );
        StreamPolicySnapshotPublicationV2 second =
            StreamPolicySnapshotPublicationV2(SnapshotDeployment442.deploy(r, g));
        require(
            address(second)
                    == SnapshotCreateVm442(address(vm))
                        .computeCreateAddress(address(this), uint256(nonce) + 1)
                && SnapshotCreateVm442(address(vm)).getNonce(address(this)) == nonce + 2
                && address(second) != address(deployed),
            "duplicate arguments create independent next host"
        );
        host = deployed;
        bytes32 record = _publishSnapshot();
        require(
            host.currentSnapshot(publication.scope).recordHash == record,
            "real publication through deployed child"
        );
        require(
            second.snapshotCount(publication.scope) == 0
                && second.currentSnapshot(publication.scope).recordHash == 0,
            "constructor worker cannot share history storage"
        );
    }

    /// @dev Real Assembly/Admission/Writer calls and Metadata grants. The inherited named
    /// source boundaries remain unchanged; this is not full current-stack gas acceptance.
    function testCapacityExtractionPreservesPreviewCopiesPublisherEventAndRollback() public {
        _initializePolicySnapshot();
        address publisher = address(0xCA442);
        _grant(publication.scope.collectionId, StreamRecordFamilies.SNAPSHOT, 7, publisher, true);
        _grant(publication.scope.collectionId, StreamRecordFamilies.IDENTITY, 7, publisher, true);
        publication.expectedSourceHash = keccak256("preview-only circularity sentinel");
        (bytes32 source, bytes memory raw) = host.previewSnapshot(publication, publisher);
        require(
            source != 0 && source != publication.expectedSourceHash, "independent source commitment"
        );
        (,,,,, Scoped.Publication memory canonicalPublication, Scoped.Receipt memory expected,) = abi.decode(
            raw,
            (
                bytes32,
                uint256,
                address,
                address[11],
                bytes32[11],
                Scoped.Publication,
                Scoped.Receipt,
                Scoped.Source
            )
        );
        require(
            canonicalPublication.expectedSourceHash == 0 && expected.sourceHash == source
                && expected.publisher == publisher && expected.authorizationClass == 7
                && expected.displayAuthorizationClass == 7 && expected.grantRevision == 1
                && expected.displayGrantRevision == 1 && expected.recordHash == 0
                && expected.chainHash == 0 && expected.manifestHash == 0
                && expected.manifestBytes == 0 && expected.recordedAt == 0,
            "assembly returns normalized bytes and retains full receipt fields"
        );
        publication.expectedSourceHash = keccak256("a different preview sentinel");
        (bytes32 sameSource, bytes memory sameRaw) = host.previewSnapshot(publication, publisher);
        require(
            source == sameSource && keccak256(raw) == keccak256(sameRaw),
            "preview has no circular input"
        );
        publication.expectedSourceHash = source;
        _uploadSnapshot(raw, false);
        Scoped.Publication memory wrong = publication;
        wrong.expectedSourceHash = keccak256("wrong actual source commitment");
        vm.expectRevert(abi.encodeWithSelector(Scoped.InvalidPolicySnapshot.selector));
        vm.prank(publisher);
        host.publishSnapshot(wrong);
        require(
            host.snapshotCount(publication.scope) == 0
                && host.currentSnapshot(publication.scope).recordHash == 0,
            "expected-source refusal leaves no receipt, head or consumed snapshot id"
        );
        expected.manifestHash = keccak256(raw);
        expected.manifestBytes = uint32(raw.length);
        expected.recordedAt = uint64(block.timestamp);
        bytes32 literalRecord = keccak256(
            abi.encode(
                keccak256("6529STREAM_POLICY_SNAPSHOT_RECORD_V2"),
                block.chainid,
                address(host),
                address(core),
                address(metadata),
                publication,
                expected
            )
        );
        vm.recordLogs();
        vm.prank(publisher);
        bytes32 record = host.publishSnapshot(publication);
        Vm.Log[] memory logs = vm.getRecordedLogs();
        require(
            record == literalRecord,
            "writer hash retains original publisher and restored sourceHash"
        );
        expected.recordHash = record;
        expected.chainHash = keccak256(
            abi.encode(
                keccak256("6529STREAM_POLICY_SNAPSHOT_CHAIN_V2"),
                block.chainid,
                address(host),
                address(core),
                publication.scope,
                bytes32(0),
                uint64(1),
                record
            )
        );
        (Scoped.Publication memory stored, Scoped.Receipt memory receipt) =
            host.snapshotRecord(record);
        require(
            keccak256(abi.encode(stored)) == keccak256(abi.encode(publication)),
            "stored request keeps nonzero expectedSourceHash"
        );
        require(
            keccak256(abi.encode(receipt)) == keccak256(abi.encode(expected)),
            "all receipt words exact"
        );
        require(
            logs.length == 1 && logs[0].emitter == address(host) && logs[0].topics.length == 4,
            "event emitted by original host"
        );
        require(
            logs[0].topics[0]
                == keccak256(
                    "PolicySnapshotPublished(uint16,bytes32,bytes32,bytes32,((uint8,uint256,uint256,bytes32),bytes32,bytes32,uint64,bytes32,bytes32,bytes32,bytes32,string,uint64,bytes32),(bytes32,bytes32,bytes32,uint64,bytes32,bytes32,uint32,bytes32,address,uint8,uint64,uint8,uint64,uint64,bytes32,bytes32,bytes32))"
                ),
            "original event signature"
        );
        (
            uint16 eventVersion,
            Scoped.Publication memory eventPublication,
            Scoped.Receipt memory eventReceipt
        ) = abi.decode(logs[0].data, (uint16, Scoped.Publication, Scoped.Receipt));
        require(
            eventVersion == 2 && logs[0].topics[1] == expected.scopeSubject
                && logs[0].topics[2] == publication.snapshotId && logs[0].topics[3] == record
                && keccak256(abi.encode(eventPublication, eventReceipt))
                    == keccak256(abi.encode(stored, receipt)),
            "original event and storage agree"
        );
        require(
            keccak256(host.snapshotPayload(record)) == keccak256(raw), "complete immutable payload"
        );
        require(
            host.requireCurrent(publication.scope, record, 1).recordHash == record,
            "restored currentness"
        );
        vm.expectRevert(abi.encodeWithSelector(Scoped.InvalidPolicySnapshot.selector));
        vm.prank(publisher);
        host.publishSnapshot(publication);
        require(
            host.snapshotCount(publication.scope) == 1
                && host.snapshotAt(publication.scope, 0) == record,
            "replay cannot append"
        );
        require(
            keccak256(host.snapshotPayload(record)) == keccak256(raw), "replay keeps original bytes"
        );
    }

    function testCompletePolicyPayloadAndOriginalRecordDomain() public {
        _initializePolicySnapshot();
        bytes memory raw = _bytes(address(this));
        bytes32 hash = _publishSnapshot();
        require(keccak256(host.snapshotPayload(hash)) == keccak256(raw));
        (
            bytes32 domain,
            uint256 chain,
            address producer,
            address[11] memory targets,
            bytes32[11] memory runtimes,
            Scoped.Publication memory p,
            Scoped.Receipt memory r,
            Scoped.Source memory f
        ) = abi.decode(
            raw,
            (
                bytes32,
                uint256,
                address,
                address[11],
                bytes32[11],
                Scoped.Publication,
                Scoped.Receipt,
                Scoped.Source
            )
        );
        require(
            domain == keccak256("6529STREAM_POLICY_SNAPSHOT_PAYLOAD_V2") && chain == block.chainid
                && producer == address(host)
        );
        require(targets[0] == address(core) && runtimes[0] == address(core).codehash);
        require(
            p.expectedSourceHash == 0 && r.recordHash == 0 && r.chainHash == 0
                && r.manifestHash == 0 && r.manifestBytes == 0 && r.recordedAt == 0
        );
        require(
            f.entropy.policies.length == 1 && f.entropy.allFrozen
                && f.entropy.policies[0].explicitPolicy
        );
        require(
            f.entropy.policies[0].collectionPolicy.policyHash == policyRow.policyHash
                && f.entropy.policies[0].provider == address(0)
        );
        require(
            f.root.artistConsent == canonicalRoot.artistConsent
                && f.rootBinding.profileId == keccak256("6529STREAM_POLICY_CURRENT_FULL_CONTENT_V2")
        );
        Scoped.Receipt memory saved = host.requireCurrent(publication.scope, hash, 1);
        saved.recordHash = 0;
        saved.chainHash = 0;
        require(
            hash
                == keccak256(
                    abi.encode(
                        keccak256("6529STREAM_POLICY_SNAPSHOT_RECORD_V2"),
                        block.chainid,
                        address(host),
                        address(core),
                        address(metadata),
                        publication,
                        saved
                    )
                )
        );
    }

    function testCanonicalHeadChangeRefusesCurrentButHistoryRemainsExact() public {
        _initializePolicySnapshot();
        bytes32 hash = _publishSnapshot();
        bytes32 original = keccak256(host.snapshotPayload(hash));
        route.set("collectionContentRootHead(uint256)", abi.encode(keccak256("foreign head")));
        vm.expectRevert();
        host.requireCurrent(publication.scope, hash, 1);
        require(keccak256(host.snapshotPayload(hash)) == original);
        _refreshRoot();
        require(host.requireCurrent(publication.scope, hash, 1).recordHash == hash);
    }

    function testOriginalProfileOrForeignPolicySetCannotBeAdopted() public {
        _initializePolicySnapshot();
        rootBinding.profileId = keccak256("V1");
        _refreshRoot();
        vm.expectRevert();
        host.previewSnapshot(publication, address(this));
        rootBinding.profileId = keccak256("6529STREAM_POLICY_CURRENT_FULL_CONTENT_V2");
        rootBinding.entropySourceSetCodeHash ^= bytes32(uint256(1));
        _refreshRoot();
        vm.expectRevert();
        host.previewSnapshot(publication, address(this));
    }

    function testFullPolicyRowChangeStalesOriginalSnapshot() public {
        _initializePolicySnapshot();
        bytes32 hash = _publishSnapshot();
        policyRow.collectionPolicy.lastActionId ^= bytes32(uint256(1));
        entropy.set("sourcePolicyAt(uint256)", abi.encode(policyRow));
        vm.expectRevert();
        host.requireCurrent(publication.scope, hash, 1);
        policyRow.collectionPolicy.lastActionId ^= bytes32(uint256(1));
        entropy.set("sourcePolicyAt(uint256)", abi.encode(policyRow));
        require(host.requireCurrent(publication.scope, hash, 1).recordHash == hash);
        entropy.setCurrent(false);
        vm.expectRevert();
        host.requireCurrent(publication.scope, hash, 1);
    }

    function testBothOriginalWriterFamiliesAndCollectionScopeRequired() public {
        _initializePolicySnapshot();
        _grant(1, StreamRecordFamilies.IDENTITY, 7, address(this), false);
        vm.expectRevert();
        host.previewSnapshot(publication, address(this));
        _grant(1, StreamRecordFamilies.IDENTITY, 7, address(this), true);
        _grant(1, StreamRecordFamilies.SNAPSHOT, 7, address(this), false);
        vm.expectRevert();
        metadata.familyWriterTransition(1, StreamRecordFamilies.SNAPSHOT, 3, address(this), true);
        vm.expectRevert();
        host.previewSnapshot(publication, address(this));
        _grant(1, StreamRecordFamilies.SNAPSHOT, 7, address(this), true);
        publication.scope.scopeType = StreamFinalityScopeType.TOKEN;
        publication.scope.tokenId = 1;
        vm.expectRevert();
        host.previewSnapshot(publication, address(this));
    }

    function testMultiChunkInventoryReconstructsCompleteImmutablePayload() public {
        _initializePolicySnapshot();
        bytes memory uri = new bytes(2000);
        for (uint256 i; i < uri.length; ++i) {
            uri[i] = 0x61;
        }
        publication.manifestURI = string.concat("https://", string(uri));
        canonicalRoot.publication.manifestURI = publication.manifestURI;
        _refreshRoot();
        bytes memory raw = _bytes(address(this));
        require(raw.length > 8192);
        bytes32 hash = _publishSnapshot();
        uint256 n = host.snapshotChunkCount(hash);
        require(n == (raw.length + 8191) / 8192);
        bytes memory complete;
        for (uint256 i; i < n; ++i) {
            (address pointer, bytes32 digest, uint32 length) = host.snapshotChunkAt(hash, i);
            bytes memory bytes_ = store.readChunk(digest);
            require(
                pointer.code.length == uint256(length) + 1 && bytes_.length == length
                    && keccak256(bytes_) == digest
            );
            complete = bytes.concat(complete, bytes_);
        }
        require(
            keccak256(complete) == keccak256(raw)
                && keccak256(host.snapshotPayload(hash)) == keccak256(raw)
        );
    }

    function testIndependentReaderRequiresOriginalReceiptCurrentSourceAndLockShape() public {
        _initializePolicySnapshot();
        bytes32 hash = _publishSnapshot();
        PolicySnapshotReaderProbeV2 reader = new PolicySnapshotReaderProbeV2();
        Reader.Dependencies memory d = Reader.Dependencies(
            address(core),
            address(metadata),
            address(host),
            address(core).codehash,
            address(metadata).codehash,
            address(host).codehash,
            block.chainid,
            500000,
            6000000
        );
        Reader.Evidence memory e = reader.current(d, publication.scope, hash, 1);
        require(
            e.inputHash != 0 && !e.locked && e.receipt.recordHash == hash
                && e.contentRootRecord == publication.contentRootRecord
        );
        vm.expectRevert();
        reader.current(d, publication.scope, hash, 2);
        d.snapshotsCodeHash ^= bytes32(uint256(1));
        vm.expectRevert();
        reader.current(d, publication.scope, hash, 1);
    }

    function testOfficialSafeMissingBytesRollsBackAndIdenticalRetry() public {
        _initializePolicySnapshot();
        uint256[] memory keys = new uint256[](2);
        keys[0] = 0x818121;
        keys[1] = 0x818122;
        OfficialSafe account =
            createOfficialSafe(deploySafeComponents("1.4.1"), safeOwnerAddresses(keys), 2, 902);
        _grant(1, StreamRecordFamilies.SNAPSHOT, 7, address(account), true);
        _grant(1, StreamRecordFamilies.IDENTITY, 7, address(account), true);
        bytes memory raw = _bytes(address(account));
        _uploadSnapshot(raw, true);
        bytes memory input = abi.encodeCall(host.publishSnapshot, (publication));
        uint256 nonce = account.nonce();
        bytes memory signatures = safeThresholdSignature(
            keys,
            account.getTransactionHash(
                address(host), 0, input, 0, 0, 0, 0, address(0), address(0), nonce
            )
        );
        vm.expectRevert(abi.encodeWithSignature("Error(string)", "GS013"));
        account.execTransaction(
            address(host), 0, input, 0, 0, 0, 0, address(0), payable(address(0)), signatures
        );
        require(account.nonce() == nonce && host.snapshotCount(publication.scope) == 0);
        _uploadSnapshot(raw, false);
        require(
            account.execTransaction(
                address(host), 0, input, 0, 0, 0, 0, address(0), payable(address(0)), signatures
            )
        );
        require(
            account.nonce() == nonce + 1
                && host.currentSnapshot(publication.scope).publisher == address(account)
        );
    }

    function testGlobalGrantsAndExactSourceCommitment() public {
        _initializePolicySnapshot();
        _grant(1, StreamRecordFamilies.SNAPSHOT, 7, address(this), false);
        _grant(1, StreamRecordFamilies.IDENTITY, 7, address(this), false);
        _grant(0, StreamRecordFamilies.SNAPSHOT, 8, address(this), true);
        _grant(0, StreamRecordFamilies.IDENTITY, 8, address(this), true);
        bytes memory raw = _bytes(address(this));
        _uploadSnapshot(raw, false);
        bytes32 expected = publication.expectedSourceHash;
        publication.expectedSourceHash = keccak256("substituted source");
        vm.expectRevert(abi.encodeWithSelector(Scoped.InvalidPolicySnapshot.selector));
        host.publishSnapshot(publication);
        require(host.snapshotCount(publication.scope) == 0);
        publication.expectedSourceHash = expected;
        bytes32 hash = host.publishSnapshot(publication);
        Scoped.Receipt memory r = host.requireCurrent(publication.scope, hash, 1);
        require(r.authorizationClass == 8 && r.displayAuthorizationClass == 8);
    }

    function testExactClassTwoLockAndPublicationReplay() public {
        _initializePolicySnapshot();
        bytes32 hash = _publishSnapshot();
        (bytes32 scope, bytes32 oldState, bytes32 newState) = host.lockTransition(publication.scope);
        vm.expectRevert();
        host.lockSnapshot(publication.scope);
        svm.mockCall(
            address(executor),
            abi.encodeWithSignature("currentAction()"),
            abi.encode(true, keccak256("lock"), uint8(2), scope, oldState, keccak256("wrong next"))
        );
        vm.expectRevert(
            abi.encodeWithSelector(Scoped.PolicySnapshotAuthority.selector, address(executor))
        );
        vm.prank(address(executor));
        host.lockSnapshot(publication.scope);
        require(host.snapshotLock(publication.scope).actionId == 0);
        svm.mockCall(
            address(executor),
            abi.encodeWithSignature("currentAction()"),
            abi.encode(true, keccak256("lock"), uint8(2), scope, oldState, newState)
        );
        vm.prank(address(executor));
        host.lockSnapshot(publication.scope);
        require(host.snapshotLock(publication.scope).recordHash == hash);
        vm.expectRevert();
        host.publishSnapshot(publication);
        require(host.requireCurrent(publication.scope, hash, 1).recordHash == hash);
    }
}
