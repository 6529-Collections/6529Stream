// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "../../helpers/PolicyReferenceFixtureV2.sol";

/// @notice Actual V2 Snapshot/reference/Metadata/Schema/Store/Membership and official Safe.
/// @dev Core, Artist, checkpoint/output/root, renderer admission, archive and action context
/// are explicit typed boundaries. These recipes do not establish actual selected-provider,
/// browser replay, complete executable archival closure or transaction-cap acceptance.
contract StreamPolicyReferencePublicationV2Test is PolicyReferenceFixtureV2 {
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
