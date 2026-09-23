// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./ArtistInheritedRecoveryFixture.sol";

contract StreamArtistInheritedRecoveryTest is ArtistInheritedRecoveryFixture {
    function testInheritedTokenActualApprovalAndCompanionExecution() public {
        Approval.Request memory p = _inheritedSetup(false);
        T.Authorization memory a = _authorization(false);
        a.signature = _signature(ingress.recoveryApprovalDigest(p.terms, a));
        bytes32 approval = ingress.recordRecoveryApproval(p, a);
        (Recovery.ApprovalRecord memory saved, Approval.Admission memory admission) =
            ingress.recoveryApprovalRecord(approval);
        require(
            keccak256(abi.encode(admission.scope)) == keccak256(abi.encode(p.scope))
                && keccak256(abi.encode(admission.intent))
                    == keccak256(abi.encode(_inheritedFacts())),
            "exact inherited intent admission"
        );
        (bool valid, bytes32 hash, address signer, uint8 cls) = ingress.verifyRecoveryApproval(
            1, p.terms.finalityRecordHash, p.terms.recoveryManifestHash
        );
        require(
            valid && hash == approval && signer == address(artist) && cls == 1,
            "saved inherited approval"
        );
        require(
            StreamArtistRecoveryHashes.approvalRecord(
                StreamArtistHashes.Environment(
                    block.chainid, address(ingress), address(core), address(manager)
                ),
                saved
            ) == approval,
            "permanent record unchanged"
        );
        _executeInherited();
        StreamFinalityRecoveryRecord memory r =
            inheritedRecovery.finalityRecoveryRecord(INHERITED_ACTION);
        require(
            r.executed && r.generation == 1 && r.predecessorRecoveryId == 0
                && r.originalFinalityRecordHash == p.terms.finalityRecordHash
                && keccak256(abi.encode(r.scope)) == keccak256(abi.encode(p.scope))
                && r.evidence.artistEvidenceKind
                    == StreamFinalityRecoveryArtistEvidenceKind.APPROVAL
                && r.evidence.artistEvidenceHash == approval && r.evidence.artistId == artistId
                && r.evidence.artistSigner == address(artist),
            "actual companion snapshots approval"
        );
    }

    function testInheritedBurnedDirectSafeApprovalRetainsSavedConsentAfterRotationAndExpiry()
        public
    {
        Approval.Request memory p = _inheritedSetup(true);
        T.Authorization memory a = _authorization(false);
        require(
            executeSafe(
                artist,
                keys,
                address(ingress),
                0,
                abi.encodeCall(IStreamArtistRecoveryApproval.recordRecoveryApproval, (p, a)),
                0
            ),
            "actual direct Safe"
        );
        (bool valid, bytes32 hash, address signer,) = ingress.verifyRecoveryApproval(
            1, p.terms.finalityRecordHash, p.terms.recoveryManifestHash
        );
        require(valid, "burned token approved");
        (Recovery.ApprovalRecord memory before_, Approval.Admission memory beforeAdmission) =
            ingress.recoveryApprovalRecord(hash);
        bytes32 immutableBytes = keccak256(abi.encode(before_, beforeAdmission));
        _newRotationSafe(39541);
        bytes32 rotation = _stageRotation(0);
        _executeTimedRotation(rotation);
        _adoptRotatedSafe();
        bytes32 savedHash;
        address savedSigner;
        (valid, savedHash, savedSigner,) = ingress.verifyRecoveryApproval(
            1, p.terms.finalityRecordHash, p.terms.recoveryManifestHash
        );
        require(
            valid && savedHash == hash && savedSigner == signer && block.timestamp > a.time,
            "saved old principal survives rotation and deadline"
        );
        _inheritedToken(1, 0);
        (valid,,,) = ingress.verifyRecoveryApproval(
            1, p.terms.finalityRecordHash, p.terms.recoveryManifestHash
        );
        require(valid, "saved consent does not rerun current token");
        (before_, beforeAdmission) = ingress.recoveryApprovalRecord(hash);
        require(
            keccak256(abi.encode(before_, beforeAdmission)) == immutableBytes,
            "all saved bytes unchanged"
        );
        (bool ready,) = address(inheritedRecovery)
            .staticcall(
                abi.encodeCall(
                    IStreamArtistRecoveryIntent.requireArtistRecoveryIntent,
                    (p.scope, p.terms.finalityRecordHash, p.terms.recoveryManifestHash)
                )
            );
        require(!ready, "companion still rejects current invalid membership");
        _inheritedToken(3, 1);
        _executeInherited();
        require(
            inheritedRecovery.finalityRecoveryRecord(INHERITED_ACTION).evidence.artistSigner
                == signer,
            "execution retains original signer"
        );
    }

    function testInheritedTokenInvalidAdmissionThenSameProofAndLateArchiveRollback() public {
        Approval.Request memory p = _inheritedSetup(false);
        T.Authorization memory a = _authorization(false);
        a.signature = _signature(ingress.recoveryApprovalDigest(p.terms, a));
        bytes32 roots = _roots();
        _inheritedToken(1, 0);
        avm.expectRevert(Recovery.InvalidRecoveryApproval.selector);
        ingress.recordRecoveryApproval(p, a);
        require(
            _roots() == roots
                && !IStreamArtistIdentityOwner(suite.owners[2]).nonceUsed(artistId, a.nonce),
            "invalid member leaves nonce and owners"
        );
        _inheritedToken(2, 0);
        uint256 blockBefore = 12345;
        vm.roll(uint256(type(uint64).max) + 1);
        vm.expectRevert();
        ingress.recordRecoveryApproval(p, a);
        require(
            _roots() == roots
                && !IStreamArtistIdentityOwner(suite.owners[2]).nonceUsed(artistId, a.nonce),
            "actual late Archive rollback"
        );
        vm.roll(blockBefore);
        bytes32 hash = ingress.recordRecoveryApproval(p, a);
        require(
            hash != 0 && IStreamArtistIdentityOwner(suite.owners[2]).nonceUsed(artistId, a.nonce),
            "identical proof retries"
        );
        _executeInherited();
        require(
            inheritedRecovery.finalityRecoveryRecord(INHERITED_ACTION).evidence.artistEvidenceHash
                == hash,
            "retried approval consumed"
        );
    }

    function testInheritedTokenActualFinding23NoticeThenCompanionFallback() public {
        Approval.Request memory p = _inheritedSetup(false);
        Recovery.FindingRequest memory request = Recovery.FindingRequest(
            artistId, 1, keccak256("inherited inability"), keccak256("inherited finding reason")
        );
        U.Target memory target = U.Target(
            address(inheritedRecovery),
            INHERITED_ACTION,
            p.scope,
            p.terms.finalityRecordHash,
            p.terms.recoveryManifestHash
        );
        ArtistUnitRoles(suite.roleRegistry).setArbiter(address(this), true);
        GovernanceAction memory scheduled;
        scheduled.status = GovernanceActionStatus.SCHEDULED;
        scheduled.actionClass = 2;
        scheduled.notBefore = uint64(block.timestamp + 91 days);
        scheduled.expiresAfter = uint64(block.timestamp + 100 days);
        scheduled.reasonURI = "urn:scheduled:inherited";
        avm.mockCall(
            inheritedExecutor,
            abi.encodeCall(IStreamGovernanceReads.governanceAction, (INHERITED_ACTION)),
            abi.encode(scheduled)
        );
        bytes32 finding = _recordUnavailability(request, target);
        (Recovery.FindingRecord memory r,) = ingress.unavailabilityFindingRecord(finding);
        vm.warp(r.noticeEndsAt - 1);
        (bool live,,,) = ingress.verifyRecoveryUnavailability(target);
        require(live, "finding live separately from notice clock");
        _inheritedContext();
        vm.expectRevert(
            abi.encodeWithSelector(
                StreamFinalityRecoveryExecution.FinalityRecoveryUnavailabilityNoticeOpen.selector,
                r.noticeEndsAt
            )
        );
        vm.prank(inheritedExecutor);
        inheritedRecovery.executeFinalityRecovery(inheritedRequest);
        require(
            !inheritedRecovery.finalityRecoveryRecord(INHERITED_ACTION).executed,
            "notice failure does not append"
        );
        vm.warp(r.noticeEndsAt);
        _executeInherited();
        StreamFinalityRecoveryEvidenceSnapshot memory evidence =
        inheritedRecovery.finalityRecoveryRecord(INHERITED_ACTION).evidence;
        require(
            evidence.artistEvidenceKind == StreamFinalityRecoveryArtistEvidenceKind.UNAVAILABILITY
                && evidence.artistEvidenceHash == finding
                && evidence.artistNoticeEndsAt == r.noticeEndsAt && evidence.artistId == artistId,
            "actual fallback snapshots exact Identity finding"
        );
    }
}
