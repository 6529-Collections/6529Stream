// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./ArtistOnboardingFixture.sol";
import "../../../smart-contracts/interfaces/stream/artist/IStreamArtistRecoveryApproval.sol";

/// @dev Actual Identity/Consent/Archive/Safe composition. Executed Finality, selected Core/module
///      eligibility and staged recovery intent are the explicit typed boundaries inherited below.
contract StreamArtistRecoveryApprovalTest is ArtistOnboardingFixture {
    function _approvalFixture() private returns (Approval.Request memory p) {
        _accept();
        (Q.Request memory q,) = _sanctionPrepared();
        bytes32 sanctionHash = ingress.recordArtistSanction(q, _sanctionAuthorization(q));
        (Confirmation.Transition memory transition,) = _confirmationStored(sanctionHash, 1, 9);
        p.scope = StreamFinalityScope(StreamFinalityScopeType.COLLECTION, 1, 0, 0);
        p.terms = Recovery.ApprovalTerms(
            coordinator.finalityRegistry(),
            1,
            transition.finalityRecordHash,
            keccak256("exact staged recovery approval intent")
        );
        p.recoveryRegistry = address(
            new ArtistRecoveryIntentFixture(
                address(core),
                p.terms.finalityRegistry,
                p.terms.finalityRecordHash,
                p.terms.recoveryManifestHash
            )
        );
        core.set(keccak256("ARTWORK_FINALITY_RECOVERY"), p.recoveryRegistry, false);
        _unavailabilityModule(
            keccak256("ARTIST_REGISTRY"),
            address(ingress),
            keccak256("ARTIST_REGISTRY"),
            type(IStreamArtistMintConsent).interfaceId
        );
        _unavailabilityModule(
            keccak256("ARTWORK_FINALITY_RECOVERY"),
            p.recoveryRegistry,
            keccak256("STREAM_ARTWORK_FINALITY_RECOVERY"),
            0x83685f5c
        );
        require(
            address(ingress).code.length <= 24576 && address(coordinator).code.length <= 24576
                && suite.owners[2].code.length <= 24576 && suite.owners[6].code.length <= 24576
                && StreamArtistConsentFinalityLifecycle(suite.owners[6]).consentWriterExtension()
                    .code.length <= 24576,
            "actual owners and ingress fit"
        );
    }

    function _approvalHash(Approval.Request memory p, T.Authorization memory a)
        private
        view
        returns (bytes32)
    {
        bytes32[12] memory words;
        words[0] = keccak256("6529STREAM_ARTIST_RECOVERY_APPROVAL_RECORD_V1");
        words[1] = bytes32(block.chainid);
        words[2] = bytes32(uint256(uint160(address(ingress))));
        words[3] = bytes32(uint256(uint160(p.terms.finalityRegistry)));
        words[4] = bytes32(p.terms.collectionId);
        words[5] = p.terms.finalityRecordHash;
        words[6] = p.terms.recoveryManifestHash;
        words[7] = artistId;
        words[8] = bytes32(uint256(uint160(address(artist))));
        words[9] = bytes32(uint256(1));
        words[10] = bytes32(a.nonce);
        words[11] = bytes32(block.timestamp);
        return keccak256(abi.encode(words));
    }

    function _assertApproval(Approval.Request memory p, T.Authorization memory a, bytes32 expected)
        private
        view
    {
        (bool valid, bytes32 hash, address signer, uint8 class_) = ingress.verifyRecoveryApproval(
            1, p.terms.finalityRecordHash, p.terms.recoveryManifestHash
        );
        require(
            valid && hash == expected && signer == address(artist) && class_ == 1,
            "exact saved approval"
        );
        (Recovery.ApprovalRecord memory r, Approval.Admission memory admission) =
            ingress.recoveryApprovalRecord(hash);
        require(
            r.recordHash == hash && r.artistId == artistId && r.nonce == a.nonce
                && r.deadline == a.time && r.digest == ingress.recoveryApprovalDigest(p.terms, a)
                && r.terms.finalityRegistry == p.terms.finalityRegistry,
            "permanent record and digest"
        );
        require(
            keccak256(abi.encode(admission.scope)) == keccak256(abi.encode(p.scope))
                && admission.recoveryRegistry == p.recoveryRegistry
                && admission.recoveryRegistryCodeHash == p.recoveryRegistry.codehash
                && admission.originalFinalityCodeHash == p.terms.finalityRegistry.codehash,
            "exact immutable admission"
        );
    }

    function testRecoveryApprovalFirstRelayedActualOwnersReplayEventAndArchive() public {
        Approval.Request memory p = _approvalFixture();
        T.Authorization memory a = _authorization(false);
        a.signature = _signature(ingress.recoveryApprovalDigest(p.terms, a));
        bytes32 expected = _approvalHash(p, a);
        T.Snapshot memory identityBefore =
            IStreamArtistOwner(suite.owners[2]).ownerStateSnapshotV2();
        T.Snapshot memory consentBefore = IStreamArtistOwner(suite.owners[6]).ownerStateSnapshotV2();
        vm.recordLogs();
        bytes32 record = ingress.recordRecoveryApproval(p, a);
        Vm.Log[] memory logs = vm.getRecordedLogs();
        require(record == expected, "literal12 approval");
        _assertApproval(p, a, record);
        require(
            IStreamArtistIdentityOwner(suite.owners[2]).nonceUsed(artistId, a.nonce),
            "shared Identity nonce consumed"
        );
        T.Snapshot memory identityAfter = IStreamArtistOwner(suite.owners[2]).ownerStateSnapshotV2();
        T.Snapshot memory consentAfter = IStreamArtistOwner(suite.owners[6]).ownerStateSnapshotV2();
        require(
            identityAfter.revision == identityBefore.revision + 1
                && identityAfter.recordChainTip == identityBefore.recordChainTip
                && consentAfter.revision == consentBefore.revision + 1
                && consentAfter.recordChainTip != consentBefore.recordChainTip,
            "one commit per owner, Consent primary only"
        );
        uint256 found;
        for (uint256 i; i < logs.length; ++i) {
            if (
                logs[i].emitter == suite.owners[6]
                    && logs[i].topics[0]
                        == keccak256(
                            "ArtistRecoveryApprovalRecorded(uint16,uint256,bytes32,address,bytes32,uint8,uint256,uint64,bytes32)"
                        )
            ) {
                ++found;
                require(
                    logs[i].topics[1] == bytes32(uint256(1))
                        && logs[i].topics[2] == p.terms.recoveryManifestHash
                        && logs[i].topics[3] == bytes32(uint256(uint160(address(artist)))),
                    "indexed event"
                );
                require(
                    keccak256(logs[i].data)
                        == keccak256(
                            abi.encode(
                                uint16(1),
                                p.terms.finalityRecordHash,
                                uint8(1),
                                a.nonce,
                                uint64(block.timestamp),
                                record
                            )
                        ),
                    "event fields"
                );
            }
        }
        require(found == 1, "single approval event");
        bytes32 evidenceId = keccak256(
            abi.encode(
                keccak256("6529STREAM_ARTIST_ONBOARDING_OPERATION_EVIDENCE_V1"),
                block.chainid,
                address(ingress),
                address(coordinator),
                uint16(22),
                address(this),
                record
            )
        );
        bytes memory evidence = archive.artistEvidenceBytesV2(evidenceId, 1);
        (uint16 version, bytes32 config, uint16 operation, address actor, bytes32 observed,,,) = abi.decode(
            evidence,
            (uint16, bytes32, uint16, address, bytes32, T.Snapshot[7], T.Snapshot[7], bytes)
        );
        require(
            version == 1 && config == coordinator.configurationHash() && operation == 22
                && actor == address(this) && observed == record,
            "actual relayer Archive envelope"
        );
    }

    function testRecoveryApprovalDirectSafeAndOriginalDigestHelpers() public {
        Approval.Request memory p = _approvalFixture();
        T.Authorization memory a = _authorization(false);
        bytes32 expected = _approvalHash(p, a);
        require(
            executeSafe(
                artist,
                keys,
                address(ingress),
                0,
                abi.encodeCall(IStreamArtistRecoveryApproval.recordRecoveryApproval, (p, a)),
                0
            ),
            "direct principal Safe"
        );
        _assertApproval(p, a, expected);
        D.Grant memory grant;
        grant.artistId = artistId;
        grant.delegate = address(0xDE1E6A7E);
        D.Revocation memory revoke;
        revoke.artistId = artistId;
        StreamArtistHashes.Environment memory e = StreamArtistHashes.Environment(
            block.chainid, address(ingress), address(core), address(manager)
        );
        require(
            ingress.delegationGrantDigest(grant, a)
                    == StreamArtistDelegationState.grantDigest(e, grant, a.nonce)
                && ingress.delegationRevocationDigest(revoke, a)
                    == StreamArtistDelegationState.revokeDigest(e, revoke, a.nonce, a.time),
            "relocated original digest environment"
        );
    }

    function testRecoveryApprovalRealLateArchiveFailureRollsSafeAndBothOwnersThenRetries() public {
        Approval.Request memory p = _approvalFixture();
        T.Authorization memory a = _authorization(false);
        a.signature = _signature(ingress.recoveryApprovalDigest(p.terms, a));
        bytes32 expected = _approvalHash(p, a);
        bytes memory data =
            abi.encodeCall(IStreamArtistRecoveryApproval.recordRecoveryApproval, (p, a));
        bytes32 roots = _roots();
        uint256 safeNonce = artist.nonce();
        vm.roll(uint256(type(uint64).max) + 1);
        vm.expectRevert(abi.encodeWithSignature("Error(string)", "GS013"));
        this.executeArtistSafe(data);
        require(
            _roots() == roots && artist.nonce() == safeNonce
                && !IStreamArtistIdentityOwner(suite.owners[2]).nonceUsed(artistId, a.nonce),
            "late rollback"
        );
        (bool valid, bytes32 hash,,) = ingress.verifyRecoveryApproval(
            1, p.terms.finalityRecordHash, p.terms.recoveryManifestHash
        );
        require(!valid && hash == 0, "no approval after failed append");
        vm.roll(100);
        require(executeSafe(artist, keys, address(ingress), 0, data, 0), "identical proof retry");
        _assertApproval(p, a, expected);
        require(artist.nonce() == safeNonce + 1, "one successful Safe nonce");
    }

    function _differentManifest(Approval.Request memory p)
        private
        returns (Approval.Request memory)
    {
        p = abi.decode(abi.encode(p), (Approval.Request));
        p.terms.recoveryManifestHash = keccak256("second exact staged approval manifest");
        p.recoveryRegistry = address(
            new ArtistRecoveryIntentFixture(
                address(core),
                p.terms.finalityRegistry,
                p.terms.finalityRecordHash,
                p.terms.recoveryManifestHash
            )
        );
        core.set(keccak256("ARTWORK_FINALITY_RECOVERY"), p.recoveryRegistry, false);
        _unavailabilityModule(
            keccak256("ARTWORK_FINALITY_RECOVERY"),
            p.recoveryRegistry,
            keccak256("STREAM_ARTWORK_FINALITY_RECOVERY"),
            0x83685f5c
        );
        return p;
    }

    function _savedExact(Approval.Request memory p, bytes32 expected, address signer, uint8 class_)
        private
        view
    {
        (bool valid, bytes32 hash, address actualSigner, uint8 actualClass) = ingress.verifyRecoveryApproval(
            p.terms.collectionId, p.terms.finalityRecordHash, p.terms.recoveryManifestHash
        );
        require(
            valid && hash == expected && actualSigner == signer && actualClass == class_,
            "immutable saved authority"
        );
    }

    function testRecoveryApprovalSavedRotationAndZeroCapEstateContinuity() public {
        Approval.Request memory p = _approvalFixture();
        T.Authorization memory a = _authorization(false);
        a.signature = _signature(ingress.recoveryApprovalDigest(p.terms, a));
        bytes32 hash = ingress.recordRecoveryApproval(p, a);
        address originalSigner = address(artist);
        (Recovery.ApprovalRecord memory r, Approval.Admission memory admission) =
            ingress.recoveryApprovalRecord(hash);
        bytes32 saved = keccak256(abi.encode(r, admission));
        _newRotationSafe(29201);
        bytes32 rotation = _stageRotation(0);
        _executeTimedRotation(rotation);
        _adoptRotatedSafe();
        _savedExact(p, hash, originalSigner, 1);
        vm.warp(ingress.rotationRecord(rotation).transition.postWindowEndsAt);
        _estateActivateAndAdopt(0);
        _savedExact(p, hash, originalSigner, 1);
        (r, admission) = ingress.recoveryApprovalRecord(hash);
        require(
            saved == keccak256(abi.encode(r, admission)) && block.timestamp > a.time,
            "saved evidence outlives signing deadline"
        );
        Approval.Request memory fresh = _differentManifest(p);
        a = _authorization(false);
        a.signature = _signature(ingress.recoveryApprovalDigest(fresh.terms, a));
        bytes32 roots = _roots();
        vm.expectRevert(
            abi.encodeWithSelector(Estate.EstateCapabilityUnavailable.selector, artistId, uint32(8))
        );
        ingress.recordRecoveryApproval(fresh, a);
        require(
            _roots() == roots
                && !IStreamArtistIdentityOwner(suite.owners[2]).nonceUsed(artistId, a.nonce),
            "fresh cap8 still required"
        );
        _savedExact(p, hash, originalSigner, 1);
    }

    function testRecoveryApprovalFreshActivatedEstateEightUsesClassThree() public {
        Approval.Request memory p = _approvalFixture();
        _estateActivateAndAdopt(8);
        T.Authorization memory a = _authorization(false);
        a.signature = _signature(ingress.recoveryApprovalDigest(p.terms, a));
        bytes32 hash = ingress.recordRecoveryApproval(p, a);
        _savedExact(p, hash, address(artist), 3);
        (Recovery.ApprovalRecord memory r,) = ingress.recoveryApprovalRecord(hash);
        require(
            r.authorityClass == 3 && r.signer == address(artist) && r.nonce == a.nonce,
            "actual successor record"
        );
    }

    function testRecoveryApprovalSavedContestAndChangedBindingDoNotInventSupersession() public {
        Approval.Request memory p = _approvalFixture();
        _selfGuardian();
        T.Authorization memory a = _authorization(false);
        a.signature = _signature(ingress.recoveryApprovalDigest(p.terms, a));
        bytes32 hash = ingress.recordRecoveryApproval(p, a);
        require(
            executeSafe(artist, keys, address(ingress), 0, _contestData(0), 0),
            "actual Identity contest"
        );
        _savedExact(p, hash, address(artist), 1);
        Approval.Request memory fresh = _differentManifest(p);
        a = _authorization(false);
        a.signature = _signature(ingress.recoveryApprovalDigest(fresh.terms, a));
        bytes32 roots = _roots();
        vm.expectRevert(abi.encodeWithSelector(T.InvalidIdentity.selector, artistId));
        ingress.recordRecoveryApproval(fresh, a);
        require(_roots() == roots, "new contested authorization rejected");
        T.Binding memory b = IStreamArtistBindingOwner(suite.owners[0]).binding(1);
        ++b.generation;
        b.bindingHash = keccak256("unadjudicated replacement");
        avm.mockCall(
            suite.owners[0], abi.encodeCall(IStreamArtistBindingOwner.binding, (1)), abi.encode(b)
        );
        avm.mockCall(
            suite.owners[4],
            abi.encodeCall(IStreamArtistAttributionOwner.attributionState, (1)),
            abi.encode(uint8(2), b.generation)
        );
        _savedExact(p, hash, address(artist), 1);
        avm.expectRevert(
            StreamArtistRecoveryApprovalReads.RecoveryApprovalAssociationUnsupported.selector
        );
        ingress.recordRecoveryApproval(fresh, a);
        require(_roots() == roots, "no fabricated correction adoption");
        avm.mockCall(
            suite.owners[4],
            abi.encodeCall(IStreamArtistAttributionOwner.attributionState, (1)),
            abi.encode(uint8(4), b.generation)
        );
        _savedExact(p, hash, address(artist), 1);
    }

    function testRecoveryApprovalDuplicateConsentFailureRollsFreshIdentityNonceBack() public {
        Approval.Request memory p = _approvalFixture();
        T.Authorization memory a = _authorization(false);
        a.signature = _signature(ingress.recoveryApprovalDigest(p.terms, a));
        bytes32 hash = ingress.recordRecoveryApproval(p, a);
        T.Authorization memory fresh = _authorization(false);
        fresh.signature = _signature(ingress.recoveryApprovalDigest(p.terms, fresh));
        bytes32 roots = _roots();
        avm.expectPartialRevert(T.Replay.selector);
        ingress.recordRecoveryApproval(p, fresh);
        require(
            _roots() == roots
                && !IStreamArtistIdentityOwner(suite.owners[2]).nonceUsed(artistId, fresh.nonce),
            "Consent replay rolls Identity back"
        );
        _savedExact(p, hash, address(artist), 1);
        Approval.Request memory next = _differentManifest(p);
        fresh.signature = _signature(ingress.recoveryApprovalDigest(next.terms, fresh));
        require(
            ingress.recordRecoveryApproval(next, fresh) != hash,
            "same rolled-back nonce healthy distinct intent"
        );
        require(
            ingress.supportsInterface(type(IStreamArtistRecoveryApproval).interfaceId),
            "approval interface advertised"
        );
    }

    function testRecoveryApprovalFixedCallbacksRejectActualSafeCalls() public {
        Approval.Request memory p = _approvalFixture();
        T.Authorization memory a = _authorization(false);
        T.Binding memory b = IStreamArtistBindingOwner(suite.owners[0]).binding(1);
        T.SignerApproval memory proof =
            T.SignerApproval(address(artist), ingress.recoveryApprovalDigest(p.terms, a), true);
        T.ActionContext memory c = T.ActionContext(
            22, address(artist), IStreamArtistOwner(suite.owners[2]).ownerStateSnapshotV2()
        );
        bytes32 roots = _roots();
        vm.expectRevert();
        this.executeTargetSafe(
            address(coordinator),
            abi.encodeCall(
                IStreamArtistRecoveryApprovalCoordinator.coordinateRecordRecoveryApproval,
                (address(artist), p, a)
            )
        );
        vm.expectRevert();
        this.executeTargetSafe(
            suite.owners[2],
            abi.encodeCall(
                IStreamArtistIdentityRecoveryApprovalOwner.consumeRecoveryApproval,
                (c, b, p.terms, a, proof)
            )
        );
        Recovery.ApprovalRecord memory r;
        r.terms = p.terms;
        Approval.Admission memory admission;
        c.expected = IStreamArtistOwner(suite.owners[6]).ownerStateSnapshotV2();
        vm.expectRevert();
        this.executeTargetSafe(
            suite.owners[6],
            abi.encodeCall(
                IStreamArtistRecoveryApprovalOwner.recordRecoveryApproval,
                (c, b, r, R.AuthorityFact(artistId, address(artist), 1, 1), admission)
            )
        );
        address consentWriter =
            StreamArtistConsentFinalityLifecycle(suite.owners[6]).consentWriterExtension();
        vm.expectRevert();
        this.executeTargetSafe(
            consentWriter,
            abi.encodeCall(
                IStreamArtistRecoveryApprovalOwner.recordRecoveryApproval,
                (c, b, r, R.AuthorityFact(artistId, address(artist), 1, 1), admission)
            )
        );
        require(_roots() == roots, "actual Safe has no callback privilege");
    }

    function testRecoveryApprovalConsumedDigestCannotBeRevokedRetroactively() public {
        Approval.Request memory p = _approvalFixture();
        T.Authorization memory a = _authorization(false);
        bytes32 digest = ingress.recoveryApprovalDigest(p.terms, a);
        a.signature = _signature(digest);
        bytes32 hash = ingress.recordRecoveryApproval(p, a);
        StreamArtistAuthorizationTypes.Revocation memory revoke =
            StreamArtistAuthorizationTypes.Revocation(artistId, digest, 0);
        T.Authorization memory authorization = _authorization(false);
        authorization.signature =
            _signature(ingress.authorizationRevocationDigest(revoke, authorization));
        bytes32 roots = _roots();
        avm.expectPartialRevert(T.Replay.selector);
        ingress.revokeArtistAuthorization(revoke, authorization);
        require(
            _roots() == roots
                && !IStreamArtistIdentityOwner(suite.owners[2])
                    .nonceUsed(artistId, authorization.nonce),
            "consumed target revocation rejected atomically"
        );
        _savedExact(p, hash, address(artist), 1);
    }

    function testRecoveryApprovalSavedPointersMayChangeButConsentRuntimeRemainsPinned() public {
        Approval.Request memory p = _approvalFixture();
        T.Authorization memory a = _authorization(false);
        a.signature = _signature(ingress.recoveryApprovalDigest(p.terms, a));
        bytes32 hash = ingress.recordRecoveryApproval(p, a);
        core.set(keccak256("ARTIST_REGISTRY"), address(0xA22), false);
        core.set(keccak256("ARTWORK_FINALITY_REGISTRY"), address(0xF22), false);
        core.set(keccak256("ARTWORK_FINALITY_RECOVERY"), address(0xB22), false);
        _savedExact(p, hash, address(artist), 1);
        _estateSafeRead(
            address(ingress),
            abi.encodeCall(
                IStreamArtistRecoveryApproval.verifyRecoveryApproval,
                (uint256(1), p.terms.finalityRecordHash, p.terms.recoveryManifestHash)
            )
        );
        bytes memory consentCode = suite.owners[6].code;
        bytes32 roots = _roots();
        vm.etch(suite.owners[6], hex"00");
        vm.expectRevert(abi.encodeWithSelector(T.ComponentChanged.selector, suite.owners[6]));
        ingress.verifyRecoveryApproval(1, p.terms.finalityRecordHash, p.terms.recoveryManifestHash);
        vm.etch(suite.owners[6], consentCode);
        require(_roots() == roots, "runtime substitution changes no saved state");
        _savedExact(p, hash, address(artist), 1);
    }

    function testRecoveryApprovalEstateMintCapabilityDoesNotGrantSanctionCapability() public {
        Approval.Request memory p = _approvalFixture();
        _estateActivateAndAdopt(2);
        T.Authorization memory a = _authorization(false);
        a.signature = _signature(ingress.recoveryApprovalDigest(p.terms, a));
        bytes32 roots = _roots();
        vm.expectRevert(
            abi.encodeWithSelector(Estate.EstateCapabilityUnavailable.selector, artistId, uint32(8))
        );
        ingress.recordRecoveryApproval(p, a);
        require(
            _roots() == roots
                && !IStreamArtistIdentityOwner(suite.owners[2]).nonceUsed(artistId, a.nonce),
            "mint-only successor cannot authorize recovery"
        );
        (bool valid, bytes32 hash,,) = ingress.verifyRecoveryApproval(
            1, p.terms.finalityRecordHash, p.terms.recoveryManifestHash
        );
        require(!valid && hash == 0, "no approval from unrelated capability");
    }
}
