// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamPolicyPublicationGraphTypesV2 as CapacityReferenceGraph454
} from "../../../smart-contracts/interfaces/stream/finality/StreamPolicyPublicationGraphTypesV2.sol";
import {
    StreamPolicyPublicationReferenceDeploymentV2 as CapacityReferenceDeploy454
} from "../../../smart-contracts/domains/finality/StreamPolicyPublicationReferenceDeploymentV2.sol";
import {
    LeafManifestVm as CapacityReferenceCreateVm454
} from "../../helpers/scoped-preservation-boundaries/StreamContentLeafManifestVm.sol";
import {
    IStreamGasParameterHost as CapacityReferenceGas454
} from "../../../smart-contracts/interfaces/stream/parameters/IStreamGasParameterHost.sol";

import { Vm } from "../../regression/legacy/helpers/CharacterizationTestBase.sol";
import "../../helpers/PolicyReferenceFixtureV2.sol";

/// @notice Actual V2 Snapshot/reference/Metadata/Schema/Store/Membership and official Safe.
/// @dev Core, Artist, checkpoint/output/root, renderer admission, archive and action context
/// are explicit typed boundaries. These recipes do not establish actual selected-provider,
/// browser replay, complete executable archival closure or transaction-cap acceptance.
contract StreamPolicyReferencePublicationV2Test is PolicyReferenceFixtureV2 {
    function testCapacityReferenceDeploymentKeepsCreatorArgumentsAndIndependentHistory() public {
        _reference(true);
        T.Dependencies memory d = referenceHost.dependencies();
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
            "POLICY_REFERENCE_READ_GAS", d.readGas, 50000, 1
        );
        r.referenceGas[1] = CapacityReferenceGas454.GasParameterConfig(
            "POLICY_REFERENCE_SOURCE_GAS", d.sourceGas, 50000, 1
        );
        r.referenceGas[2] = CapacityReferenceGas454.GasParameterConfig(
            "POLICY_REFERENCE_SNAPSHOT_GAS", d.snapshotGas, 50000, 1
        );
        r.referenceGas[3] = CapacityReferenceGas454.GasParameterConfig(
            "POLICY_REFERENCE_ARCHIVE_GAS", d.archiveGas, 50000, 1
        );
        uint64 nonce = CapacityReferenceCreateVm454(address(vm)).getNonce(address(this));

        StreamPolicyReferencePublicationV2 child =
            StreamPolicyReferencePublicationV2(CapacityReferenceDeploy454.deploy(r, g));
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

        StreamPolicyReferencePublicationV2 original = referenceHost;
        referenceHost = child;
        referenceHost.prepareFileInventory(
            referenceInput.observation.environment.packageFiles, true
        );
        referenceHost.prepareFileInventory(
            referenceInput.observation.environment.platformPrerequisites, false
        );
        bytes32 record = _publishReference();
        require(
            referenceHost.requireCurrent(referenceInput.scope, record, 1).observation.recordHash
                    == record && original.referenceCount(referenceInput.scope) == 0,
            "actual new child publication and independent history"
        );
    }

    /// @dev Actual Operations and retained Store bytes; the suite's named source/archive
    /// boundaries remain explicit. No browser replay or whole-stack gas claim.
    function testCapacityReferenceOperationsRetainCallerEventAndAtomicRetry() public {
        _reference(true);
        address recorder = address(0xCA454);
        _grant(referenceInput.scope.collectionId, StreamRecordFamilies.CURATOR, 3, recorder, true);
        bytes memory raw = _referenceBytes(recorder);
        _uploadSnapshot(raw, false);
        bytes32 sources = referenceInput.observation.expectedSourcesHash;
        referenceInput.observation.expectedSourcesHash =
            keccak256("wrong capacity reference sources");
        vm.expectRevert(abi.encodeWithSelector(T.InvalidPolicyReference.selector));
        vm.prank(recorder);
        referenceHost.publishReference(referenceInput);
        referenceInput.observation.expectedSourcesHash = sources;
        _grant(referenceInput.scope.collectionId, StreamRecordFamilies.CURATOR, 3, recorder, false);
        vm.expectRevert(abi.encodeWithSelector(T.PolicyReferenceAuthority.selector, recorder));
        vm.prank(recorder);
        referenceHost.publishReference(referenceInput);
        require(
            referenceHost.referenceCount(referenceInput.scope) == 0
                && referenceHost.currentReference(referenceInput.scope).observation.recordHash == 0,
            "source or authority refusal consumes no id or head"
        );
        _grant(referenceInput.scope.collectionId, StreamRecordFamilies.CURATOR, 3, recorder, true);
        raw = _referenceBytes(recorder);
        _uploadSnapshot(raw, false);
        T.Receipt memory expected;
        {
            (
                bytes32 payloadDomain,
                uint256 chain,
                address producer,
                T.Publication memory normalized,
                T.Receipt memory receipt,,
            ) = abi.decode(
                raw, (bytes32, uint256, address, T.Publication, T.Receipt, T.SourceFacts, bytes)
            );
            require(
                payloadDomain == keccak256("6529STREAM_POLICY_REFERENCE_PAYLOAD_V2")
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
                keccak256("6529STREAM_POLICY_REFERENCE_RECORD_V2"),
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
                keccak256("6529STREAM_POLICY_REFERENCE_CHAIN_V2"),
                block.chainid,
                address(referenceHost),
                address(core),
                expected.scopeSubject,
                bytes32(0),
                uint64(1),
                record
            )
        );
        (T.Publication memory stored, T.Receipt memory receipt) =
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
                        "PolicyReferencePublished(uint16,bytes32,bytes32,bytes32,(bytes32,(bytes32,bytes32,uint256,bytes32,bytes32,uint64,bytes32,uint32,bytes32,bytes32,uint64,address,uint8,uint64,uint64,uint64,bytes32,bytes32,bytes32,bytes32)),string)"
                    ) && logs[0].topics[1] == expected.scopeSubject
                && logs[0].topics[2] == referenceInput.observation.referenceId
                && logs[0].topics[3] == record,
            "exact event signature and indexed fields"
        );
        (uint16 version, T.Receipt memory eventReceipt, string memory uri) =
            abi.decode(logs[0].data, (uint16, T.Receipt, string));
        require(
            version == 2 && keccak256(abi.encode(eventReceipt)) == keccak256(abi.encode(expected))
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
        vm.expectRevert(abi.encodeWithSelector(T.InvalidPolicyReference.selector));
        vm.prank(recorder);
        referenceHost.publishReference(referenceInput);
        require(
            referenceHost.referenceCount(referenceInput.scope) == 1,
            "exact reference id cannot replay"
        );
        referenceInput.observation.referenceId = keccak256("capacity reference successor");
        vm.expectRevert(
            abi.encodeWithSelector(T.PolicyReferenceLineage.selector, bytes32(0), record)
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
        _uploadSnapshot(_referenceBytes(recorder), false);
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

    function testTerminalReferenceRetainsExactPolicyAndOriginalV2Record() public {
        _reference(true);
        bytes memory raw = _referenceBytes(address(this));
        _uploadSnapshot(raw, false);
        bytes32 hash = referenceHost.publishReference(referenceInput);
        T.Receipt memory current = referenceHost.requireCurrent(referenceInput.scope, hash, 1);
        (T.Publication memory p, T.Receipt memory r) = referenceHost.referenceRecord(hash);
        require(keccak256(abi.encode(p)) == keccak256(abi.encode(referenceInput)));
        require(keccak256(abi.encode(current)) == keccak256(abi.encode(r)));
        require(r.observation.payloadHash == keccak256(raw));
        require(keccak256(referenceHost.referencePayload(hash)) == keccak256(raw));
        r.observation.recordHash = 0;
        r.observation.recordChainHash = 0;
        require(
            hash
                == keccak256(
                    abi.encode(
                        keccak256("6529STREAM_POLICY_REFERENCE_RECORD_V2"),
                        block.chainid,
                        address(referenceHost),
                        address(core),
                        address(metadata),
                        p,
                        r
                    )
                )
        );
        T.SourceFacts memory f = referenceHost.referenceSource(hash);
        require(f.samples.length == 2 && f.snapshotSource.membership.tokenCount == 3);
        require(f.samples[0].membershipIndex == 0 && f.samples[1].membershipIndex == 2);
        for (uint256 i; i < f.samples.length; ++i) {
            require(f.samples[i].entropy.terminal && !f.samples[i].entropy.finalized);
            require(
                f.samples[i].entropy.seed == 0
                    && f.samples[i].entropy.policyHash == policyRow.policyHash
            );
            require(f.samples[i].terminalAdmissionHash != 0);
        }
        require(f.contentRootRecordHash == publication.contentRootRecord);
        require(f.snapshot.recordHash == referenceInput.observation.snapshotRecordHash);
    }

    function testFullJsonDriftRefusesCurrentAndPreservesExactHistory() public {
        _reference(true);
        bytes32 hash = _publishReference();
        bytes32 payload = keccak256(referenceHost.referencePayload(hash));
        uint256 token = referenceInput.observation.captures[0].tokenId;
        // The compact historical read is already distinct in the fixture. Only full current
        // JSON satisfies this producer, even if the archived compact output is unchanged.
        svm.mockCall(
            address(route),
            abi.encodeWithSignature("tokenJSON(uint256)", token),
            abi.encode(bytes("full JSON changed"))
        );
        vm.expectRevert();
        referenceHost.requireCurrent(referenceInput.scope, hash, 1);
        require(keccak256(referenceHost.referencePayload(hash)) == payload);
    }

    function testFullHtmlAndTokenDataDriftIndependentlyRefuse() public {
        _reference(true);
        bytes32 hash = _publishReference();
        R.Capture memory c = referenceInput.observation.captures[0];
        svm.mockCall(
            address(route),
            abi.encodeWithSignature("tokenHTML(uint256)", c.tokenId),
            abi.encode(bytes("changed HTML"))
        );
        vm.expectRevert();
        referenceHost.requireCurrent(referenceInput.scope, hash, 1);
        svm.mockCall(
            address(route),
            abi.encodeWithSignature("tokenHTML(uint256)", c.tokenId),
            abi.encode(c.animationHTML)
        );
        svm.mockCall(
            address(core),
            abi.encodeWithSignature("tokenData(uint256)", c.tokenId),
            abi.encode(bytes(hex"1235"))
        );
        vm.expectRevert();
        referenceHost.requireCurrent(referenceInput.scope, hash, 1);
        svm.mockCall(
            address(core),
            abi.encodeWithSignature("tokenData(uint256)", c.tokenId),
            abi.encode(bytes(hex"1234"))
        );
        require(
            referenceHost.requireCurrent(referenceInput.scope, hash, 1).observation.recordHash
                == hash
        );
    }

    function testActualFirstLastOrdinalsAndSerialNotTokenId() public {
        _reference(true);
        uint256 original = referenceInput.observation.captures[0].tokenId;
        referenceInput.observation.captures[0].tokenId =
        referenceInput.observation.captures[1].tokenId;
        vm.expectRevert();
        referenceHost.previewReference(referenceInput, address(this));
        referenceInput.observation.captures[0].tokenId = original;
        uint256 serial = referenceInput.observation.captures[0].collectionSerial;
        referenceInput.observation.captures[0].collectionSerial = serial + 1;
        vm.expectRevert();
        referenceHost.previewReference(referenceInput, address(this));
        referenceInput.observation.captures[0].collectionSerial = serial;
        bytes32 hash = _publishReference();
        require(
            referenceHost.referenceSource(hash).samples[0].observation.collectionSerial == serial
        );
    }

    function testScopeAndSnapshotSubstitutionNeverBorrowV1OrOtherScope() public {
        _reference(true);
        bytes32 snapshot = referenceInput.observation.snapshotRecordHash;
        referenceInput.observation.snapshotRecordHash = keccak256("V1 receipt or foreign host");
        vm.expectRevert();
        referenceHost.previewReference(referenceInput, address(this));
        referenceInput.observation.snapshotRecordHash = snapshot;
        referenceInput.scope.scopeType = StreamFinalityScopeType.TOKEN;
        referenceInput.scope.tokenId = referenceInput.observation.captures[0].tokenId;
        vm.expectRevert();
        referenceHost.previewReference(referenceInput, address(this));
        referenceInput.scope = publication.scope;
        referenceInput.scope.scopeType = StreamFinalityScopeType.VIEW;
        vm.expectRevert();
        referenceHost.previewReference(referenceInput, address(this));
    }

    function testCanonicalRootAndCompletePolicySetDriftRefuseCurrent() public {
        _reference(true);
        bytes32 hash = _publishReference();
        bytes32 payload = keccak256(referenceHost.referencePayload(hash));
        route.set("collectionContentRootHead(uint256)", abi.encode(keccak256("new canonical head")));
        vm.expectRevert();
        referenceHost.requireCurrent(referenceInput.scope, hash, 1);
        route.set("collectionContentRootHead(uint256)", abi.encode(publication.contentRootRecord));
        entropy.setCurrent(false);
        vm.expectRevert();
        referenceHost.requireCurrent(referenceInput.scope, hash, 1);
        entropy.setCurrent(true);
        policyRow.collectionPolicy.lastActionId = keccak256("changed full policy evidence");
        entropy.set("sourcePolicyAt(uint256)", abi.encode(policyRow));
        vm.expectRevert();
        referenceHost.requireCurrent(referenceInput.scope, hash, 1);
        require(keccak256(referenceHost.referencePayload(hash)) == payload);
    }

    function testTerminalCannotSubstituteFinalizedSeedOrAdmission() public {
        _reference(true);
        uint256 token = referenceInput.observation.captures[0].tokenId;
        IStreamFinalityEntropyPolicySourceSet.TokenReadiness memory wrong =
            IStreamFinalityEntropyPolicySourceSet.TokenReadiness(
                address(entropy),
                address(entropy).codehash,
                policyRow.policyHash,
                1,
                0,
                0,
                1,
                true,
                true,
                bytes32(0)
            );
        svm.mockCall(
            address(entropy),
            abi.encodeCall(IStreamFinalityEntropyPolicySourceSet.tokenEntropyReadiness, (token)),
            abi.encode(wrong)
        );
        vm.expectRevert();
        referenceHost.previewReference(referenceInput, address(this));
        wrong.finalized = false;
        wrong.seed = keccak256("fabricated seed");
        svm.mockCall(
            address(entropy),
            abi.encodeCall(IStreamFinalityEntropyPolicySourceSet.tokenEntropyReadiness, (token)),
            abi.encode(wrong)
        );
        vm.expectRevert();
        referenceHost.previewReference(referenceInput, address(this));
    }

    function testCaptureRepeatAndOriginalEnvironmentIdentityBothRequired() public {
        _reference(true);
        bytes32 original = referenceInput.observation.captures[0].repeatCaptureSha256[1];
        referenceInput.observation.captures[0].repeatCaptureSha256[1] =
            keccak256("different capture");
        vm.expectRevert();
        referenceHost.previewReference(referenceInput, address(this));
        referenceInput.observation.captures[0].repeatCaptureSha256[1] = original;
        referenceInput.observation.captures[0].environmentManifestHash =
            keccak256("different environment");
        vm.expectRevert();
        referenceHost.previewReference(referenceInput, address(this));
    }

    function testCuratorGrantAndExactSourcesRequiredAtPublication() public {
        _reference(true);
        bytes memory raw = _referenceBytes(address(this));
        _uploadSnapshot(raw, false);
        _grant(1, StreamRecordFamilies.CURATOR, 3, address(this), false);
        vm.expectRevert();
        referenceHost.publishReference(referenceInput);
        _grant(0, StreamRecordFamilies.CURATOR, 8, address(this), true);
        raw = _referenceBytes(address(this));
        _uploadSnapshot(raw, false);
        bytes32 original = referenceInput.observation.expectedSourcesHash;
        referenceInput.observation.expectedSourcesHash = keccak256("caller claim");
        vm.expectRevert();
        referenceHost.publishReference(referenceInput);
        require(referenceHost.referenceCount(referenceInput.scope) == 0);
        referenceInput.observation.expectedSourcesHash = original;
        bytes32 hash = referenceHost.publishReference(referenceInput);
        require(
            referenceHost.requireCurrent(referenceInput.scope, hash, 1).observation
                    .authorizationClass == 8
        );
    }

    function testExactClassTwoLockAndIndependentComponentReader() public {
        _reference(true);
        bytes32 hash = _publishReference();
        (bytes32 scope, bytes32 oldHash, bytes32 newHash) =
            referenceHost.lockTransition(referenceInput.scope);
        svm.mockCall(
            address(executor),
            abi.encodeWithSignature("currentAction()"),
            abi.encode(true, keccak256("lock"), uint8(2), scope, oldHash, bytes32(0))
        );
        vm.expectRevert();
        vm.prank(address(executor));
        referenceHost.lockReference(referenceInput.scope);
        svm.mockCall(
            address(executor),
            abi.encodeWithSignature("currentAction()"),
            abi.encode(true, keccak256("lock"), uint8(2), scope, oldHash, newHash)
        );
        vm.prank(address(executor));
        referenceHost.lockReference(referenceInput.scope);
        require(ReferenceReads.component(_reader(), referenceInput.scope, hash, 1).frozen);
        vm.expectRevert();
        referenceHost.publishReference(referenceInput);
        ReferenceReads.Dependencies memory d = _reader();
        d.targets[3] = address(route);
        d.codeHashes[3] = address(route).codehash;
        vm.expectRevert();
        ReferenceReads.requireCurrent(d, referenceInput.scope, hash, 1);
    }

    function testFullPayloadChunkEnumerationMatchesHistoricalBytes() public {
        _reference(true);
        bytes32 hash = _publishReference();
        bytes memory full = referenceHost.referencePayload(hash);
        uint256 n = referenceHost.referenceChunkCount(hash);
        require(n > 1 && n == (full.length + 8191) / 8192);
        bytes memory joined;
        for (uint256 i; i < n; ++i) {
            (address pointer, bytes32 digest, uint32 size) = referenceHost.referenceChunkAt(hash, i);
            require(pointer.code.length == uint256(size) + 1);
            bytes memory part = new bytes(size);
            assembly ("memory-safe") { extcodecopy(pointer, add(part, 32), 1, size) }
            require(keccak256(part) == digest);
            joined = bytes.concat(joined, part);
        }
        require(keccak256(joined) == keccak256(full));
    }

    function testOfficialSafeMissingChunkRollsBackIdenticalSignatureRetry() public {
        _reference(true);
        uint256[] memory keys = new uint256[](2);
        keys[0] = 0x818141;
        keys[1] = 0x818142;
        OfficialSafe account =
            createOfficialSafe(deploySafeComponents("1.4.1"), safeOwnerAddresses(keys), 2, 904);
        _grant(1, StreamRecordFamilies.CURATOR, 3, address(account), true);
        bytes memory raw = _referenceBytes(address(account));
        _uploadSnapshot(raw, true);
        bytes memory input = abi.encodeCall(referenceHost.publishReference, (referenceInput));
        uint256 nonce = account.nonce();
        bytes memory signatures = safeThresholdSignature(
            keys,
            account.getTransactionHash(
                address(referenceHost), 0, input, 0, 0, 0, 0, address(0), address(0), nonce
            )
        );
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
        require(account.nonce() == nonce && referenceHost.referenceCount(referenceInput.scope) == 0);
        _uploadSnapshot(raw, false);
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
        require(
            account.nonce() == nonce + 1
                && referenceHost.currentReference(referenceInput.scope).observation.recorder
                    == address(account)
        );
    }
}
