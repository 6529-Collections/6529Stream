// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
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
        _grant(1, StreamRecordFamilies.SNAPSHOT, 3, address(this), true);
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
