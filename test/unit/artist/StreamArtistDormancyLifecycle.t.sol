// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "./ArtistOnboardingFixture.sol";
import "../../../smart-contracts/interfaces/stream/artist/IStreamArtistDormancy.sol";
import {
    StreamArtistDormancyTypes as Dorm
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistDormancy.sol";
import {
    IStreamArtistStewardSanctionGrant as SG
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistStewardSanctionGrant.sol";
import "../../../smart-contracts/interfaces/stream/core/IStreamCoreBurn.sol";

/// @notice Actual Artist/Safe/Archive lifecycle. Governance role/action and Core facts are typed unit boundaries.
contract StreamArtistDormancyLifecycleTest is ArtistOnboardingFixture {
    error LateDormancyArchive();
    bytes32 private constant DORMANCY_ROLE = keccak256("ROLE_ARTIST_DORMANCY_ADMIN");

    function _dorm() internal view returns (IStreamArtistDormancy) {
        return IStreamArtistDormancy(address(ingress));
    }

    function _identity() internal view returns (StreamArtistIdentityAuthority) {
        return StreamArtistIdentityAuthority(suite.owners[2]);
    }

    function _grantSanction(bool granted) internal returns (bytes32 record) {
        SG.Grant memory p =
            SG.Grant(artistId, granted, keccak256("original living steward grant statement"));
        T.Authorization memory a = _authorization(true);
        a.signature = _signature(SG(address(ingress)).stewardSanctionGrantDigest(p, a));
        return SG(address(ingress)).recordStewardSanctionGrant(p, a);
    }

    function _contextCall(bytes memory call_, Dorm.Context memory x, bytes32 evidence) internal {
        ArtistUnitGovernance authority = ArtistUnitGovernance(manager.governanceAuthority());
        authority.configureContestReads(
            suite.roleRegistry, address(this), evidence, "urn:dormancy:evidence"
        );
        avm.mockCall(
            suite.roleRegistry,
            abi.encodeCall(IStreamRoleRegistry.hasRole, (DORMANCY_ROLE, address(this))),
            abi.encode(true)
        );
        authority.executeModuleContext(
            address(ingress), call_, 1, x.scopeHash, x.oldValueHash, x.newValueHash
        );
    }

    // Fresh frames keep clock-dependent admission/signature creation after every logical time change.
    function beginDormancyNotice() external returns (bytes32 notice) {
        require(msg.sender == address(this), "self only");
        uint64 last = _identity().identity(artistId).lastAuthorityActionAt;
        (uint64 inactivity,,) =
            ingress.artistWindowInfo(keccak256("ARTIST_DORMANCY_MIN_INACTIVITY_SECONDS"));
        vm.warp(uint256(last) + inactivity);
        Dorm.Initiation memory p = Dorm.Initiation(
            artistId, keccak256("reasonable contact attempts"), "urn:dormancy:outreach"
        );
        Dorm.Context memory x = _dorm().dormancyInitiationContext(p);
        _contextCall(
            abi.encodeCall(IStreamArtistDormancy.initiateArtistDormancy, (p)), x, p.evidenceHash
        );
        (notice,,) = _dorm().dormancyNotice(artistId);
    }

    function completeDormancyNotice(bytes32 notice) external returns (bytes32 record) {
        require(msg.sender == address(this), "self only");
        (Dorm.Notice memory n,,) = _dorm().dormancyRecord(notice);
        vm.warp(n.noticeEndsAt);
        vm.roll(500);
        Dorm.Completion memory p = Dorm.Completion(
            artistId, notice, address(rotationSafe), keccak256("contact and open phase disposition")
        );
        (Dorm.Context memory x, Dorm.Plan memory plan) = _dorm().dormancyCompletionContext(p);
        bytes memory evidence =
            IStreamArtistDormancyEvidence(address(ingress)).dormancyCompletionEvidence(p);
        require(
            keccak256(evidence)
                == keccak256(
                    abi.encode(
                        keccak256("6529STREAM_ARTIST_DORMANCY_COMPLETION_EVIDENCE_V1"),
                        uint16(1),
                        p,
                        plan
                    )
                ),
            "actual selected grant in completing evidence"
        );
        _contextCall(
            abi.encodeCall(IStreamArtistDormancy.completeArtistDormancy, (p)),
            x,
            keccak256(evidence)
        );
        (,, Dorm.Terminal memory terminal) = _dorm().dormancyRecord(notice);
        return terminal.recordHash;
    }

    function _safeCancel(
        OfficialSafe signer,
        uint256[] memory signingKeys,
        bytes32 notice,
        bytes32 grant
    ) internal {
        require(
            executeSafe(
                signer,
                signingKeys,
                address(ingress),
                0,
                abi.encodeCall(
                    IStreamArtistDormancy.cancelArtistDormancy, (artistId, notice, grant)
                ),
                0
            ),
            "actual threshold Safe liveness"
        );
    }

    function _assertCancelled(bytes32 notice, uint8 class_) internal view {
        (Dorm.Notice memory saved, uint8 phase, Dorm.Terminal memory terminal) =
            _dorm().dormancyRecord(notice);
        require(
            saved.recordHash == notice && phase == 2 && terminal.recordHash != 0
                && terminal.noticeHash == notice && terminal.authorityClass == class_,
            "immutable notice and classified cancellation"
        );
        require(
            _identity().identity(artistId).lastAuthorityActionAt == terminal.observedAt,
            "cancellation advances actual inactivity clock"
        );
    }

    function _guardian() internal {
        address[] memory members = new address[](1);
        members[0] = address(this);
        _guardianRecord(members, 1, 30 days, 77);
    }

    function fileNoticeCompromise() external {
        require(msg.sender == address(this), "self only");
        ingress.contestArtistIdentity(
            artistId,
            0,
            keccak256("notice guardian knows artist is alive"),
            keccak256("notice compromise")
        );
    }

    function testNoticeExplicitLivingSafeCancellationRefreshesClockAndArchive() public {
        _accept();
        bytes32 notice = this.beginDormancyNotice();
        T.Snapshot memory before_ = _identity().ownerStateSnapshotV2();
        _safeCancel(artist, keys, notice, 0);
        _assertCancelled(notice, 1);
        (,, Dorm.Terminal memory terminal) = _dorm().dormancyRecord(notice);
        require(
            _identity().identity(artistId).status == 1
                && _identity().ownerStateSnapshotV2().revision == before_.revision + 1,
            "one owner cancellation commit"
        );
        require(
            _operationPayload(42, address(artist), terminal.recordHash).length != 0,
            "original op42 archived"
        );
        Dorm.Initiation memory p =
            Dorm.Initiation(artistId, keccak256("another attempt"), "urn:retry");
        avm.expectPartialRevert(Dorm.DormancyInactivity.selector);
        _dorm().dormancyInitiationContext(p);
    }

    function testSignedOp19CancelsNoticeWithArchiveRollbackAndIdenticalRetry() public {
        _accept();
        bytes32 notice = this.beginDormancyNotice();
        this.signedGrantDuringNotice(notice);
    }

    function signedGrantDuringNotice(bytes32 notice) external {
        require(msg.sender == address(this), "self only");
        SG.Grant memory p = SG.Grant(artistId, true, keccak256("operative artist grant"));
        T.Authorization memory a = _authorization(true);
        a.signature = _signature(SG(address(ingress)).stewardSanctionGrantDigest(p, a));
        bytes memory originalCall = abi.encodeCall(SG.recordStewardSanctionGrant, (p, a));
        bytes32 roots = _roots();
        T.Identity memory principal = _identity().identity(artistId);
        avm.mockCallRevert(
            suite.archive,
            abi.encodePacked(IStreamArtistArchiveV2.appendArtistEvidenceV2.selector),
            abi.encodeWithSelector(LateDormancyArchive.selector)
        );
        (bool ok, bytes memory reason) = address(ingress).call(originalCall);
        require(
            !ok
                && keccak256(reason)
                    == keccak256(abi.encodeWithSelector(LateDormancyArchive.selector)),
            "first attempt reached actual late archive boundary"
        );
        require(
            _roots() == roots && !_identity().nonceUsed(artistId, a.nonce)
                && keccak256(abi.encode(_identity().identity(artistId)))
                    == keccak256(abi.encode(principal)),
            "nonce liveness notice and roots roll back"
        );
        (, uint8 phase,) = _dorm().dormancyRecord(notice);
        require(phase == 1, "failed append retains live notice");
        avm.clearMockedCalls();
        (ok, reason) = address(ingress).call(originalCall);
        require(ok, "byte-identical signed retry");
        bytes32 record = abi.decode(reason, (bytes32));
        _assertCancelled(notice, 1);
        require(
            SG(address(ingress)).stewardSanctionGrantRecord(record).signer == address(artist)
                && _operationPayload(19, address(this), record).length != 0,
            "actual original grant and archive"
        );
    }

    function testActiveDelegateSafeCancelsNoticeWithoutConsumingDelegatedUse() public {
        _accept();
        _delegateSetup();
        bytes32 grant = _grant(_delegation(1, 1, 0, type(uint64).max, 3));
        bytes32 notice = this.beginDormancyNotice();
        _safeCancel(delegateSafe, delegateKeys, notice, grant);
        _assertCancelled(notice, 2);
        require(
            ingress.delegationRecord(grant).uses == 0 && _identity().identity(artistId).status == 1,
            "explicit liveness is not a fabricated delegated write"
        );
    }

    function testOperativeSuccessorSafeCancelsNoticeWithOriginalDesignation() public {
        _accept();
        _newRotationSafe(9301);
        bytes32 designation = _successionRecord(_successorTerms(address(rotationSafe), 1));
        bytes32 notice = this.beginDormancyNotice();
        _safeCancel(rotationSafe, rotationKeys, notice, 0);
        _assertCancelled(notice, 3);
        require(
            ingress.operativeSuccessorRecord(artistId) == designation
                && _identity().identity(artistId).authorityAddress == address(artist),
            "liveness retains living authority and original plan"
        );
    }

    function testDefaultStewardCompletionPreservesOldMintConsentAndRejectsNewPolicy() public {
        _all();
        _newRotationSafe(9302);
        bytes32 binding_ = coordinator.reads().acceptedBinding(1).bindingHash;
        bytes32 notice = this.beginDormancyNotice();
        bytes32 record = this.completeDormancyNotice(notice);
        Estate.AuthorityCapabilities memory caps = ingress.currentAuthorityCapabilities(artistId);
        require(
            caps.authorityClass == 4 && caps.status == 3 && caps.effectiveCapabilities == 369
                && caps.activationRecordHash == record,
            "default permanent steward exclusions"
        );
        require(
            coordinator.reads().acceptedBinding(1).bindingHash == binding_,
            "appointment does not rewrite old acceptance"
        );
        ingress.requireMintConsent(1, PHASE, POLICY);
        (uint8 status,, uint64 appointed) = _dorm().dormancyState(artistId);
        require(status == 3 && appointed == 500, "actual appointment height");
        V.Snapshot memory vesting = _identity().guardianVestingSnapshot(artistId, record);
        require(
            vesting.operationId == 43 && vesting.authorityClass == 4
                && vesting.newAddress == address(rotationSafe),
            "actual op43 history producer"
        );
        require(
            _operationPayload(43, manager.governanceAuthority(), record).length != 0,
            "original completion archived"
        );
        artist = rotationSafe;
        keys = rotationKeys;
        this.stewardAttestAndRejectPolicy();
    }

    function stewardAttestAndRejectPolicy() external {
        require(msg.sender == address(this), "self only");
        bytes32 assignment =
            primary.resolvePrimaryAssignment(1, 0, keccak256("PRIMARY_SALE")).assignmentHash;
        bytes memory statement = bytes("steward preserves current rights documentation");
        T.Attestation memory p = T.Attestation(
            1,
            6,
            bytes32(uint256(uint160(address(primary)))),
            assignment,
            keccak256("steward rights schema"),
            keccak256(statement),
            "urn:steward"
        );
        T.Authorization memory a = _authorization(true);
        a.signature = _signature(ingress.attestationDigest(p, a));
        bytes32 record = ingress.recordArtistAttestation(p, a, statement);
        require(
            record != 0 && _operationPayload(24, address(this), record).length != 0,
            "actual class4 original op24"
        );
        T.PolicyConsent memory policy =
            T.PolicyConsent(1, PHASE, keccak256("new unauthorized works"));
        a = _authorization(false);
        a.signature = _signature(ingress.policyConsentDigest(policy, a));
        vm.expectRevert(
            abi.encodeWithSelector(Estate.EstateCapabilityUnavailable.selector, artistId, uint32(2))
        );
        ingress.recordPolicyConsent(policy, a);
    }

    function testOperativeGrantAndDirectiveAreExplicitInCompletionAndForbiddenWins() public {
        _accept();
        bytes32 grant = _grantSanction(true);
        bytes32 directive = _directiveRecord(8);
        _newRotationSafe(9303);
        bytes32 notice = this.beginDormancyNotice();
        this.completeDormancyNotice(notice);
        (,, Dorm.Terminal memory terminal) = _dorm().dormancyRecord(notice);
        require(
            terminal.plan.stewardGrantRecordHash == grant && terminal.plan.directive == directive,
            "operative original records retained in completing plan"
        );
        require(
            terminal.plan.capabilities == (369 | 2048)
                && terminal.plan.capabilities & (2 | 4 | 8) == 0,
            "forbidden sanction dominates pregrant and governance"
        );
    }

    function testDefaultStewardCannotRemoveOriginalLifetimeGuardian() public {
        _accept();
        _guardian();
        _newRotationSafe(9304);
        bytes32 notice = this.beginDormancyNotice();
        this.completeDormancyNotice(notice);
        artist = rotationSafe;
        keys = rotationKeys;
        this.tryStewardGuardianReplacement();
    }

    function tryStewardGuardianReplacement() external {
        require(msg.sender == address(this), "self only");
        address[] memory members = new address[](1);
        members[0] = address(0xCAFE);
        R.GuardianSet memory p = R.GuardianSet(artistId, members, 1, 30 days);
        T.Authorization memory a = _authorization(true);
        a.signature = _signature(ingress.guardianSetDigest(p, a));
        vm.expectRevert(
            abi.encodeWithSelector(
                Estate.EstateCapabilityUnavailable.selector, artistId, uint32(2048)
            )
        );
        ingress.setArtistGuardians(p, a);
        members = new address[](2);
        members[0] = address(0xCAFE);
        members[1] = address(this);
        p.guardians = members;
        a.signature = _signature(ingress.guardianSetDigest(p, a));
        bytes32 record = ingress.setArtistGuardians(p, a);
        require(record != 0, "default steward may retain and add guardians");
    }

    function testNoticeCompromiseDismissalRestoresOriginalDeadline() public {
        _accept();
        _guardian();
        bytes32 notice = this.beginDormancyNotice();
        (Dorm.Notice memory saved,,) = _dorm().dormancyRecord(notice);
        this.fileNoticeCompromise();
        require(_identity().identity(artistId).status == 4, "actual guardian cause contests notice");
        Dismissal.Request memory p = _dismissalRequest();
        this.executeGovernedDismissal(p, 1, 0);
        (uint8 status, uint64 end,) = _dorm().dormancyState(artistId);
        require(
            status == 2 && end == saved.noticeEndsAt
                && ingress.currentIdentityContestCause(artistId).facts.priorStatus == 2,
            "dismissal retains original notice and immutable cause"
        );
    }

    function testCancelledContestedNoticeInvalidatesStagedDismissalAndNeverResurrects() public {
        _accept();
        _guardian();
        bytes32 notice = this.beginDormancyNotice();
        this.fileNoticeCompromise();
        Dismissal.Request memory p = _dismissalRequest();
        Dismissal.Context memory old = ingress.identityContestDismissalContext(p);
        _safeCancel(artist, keys, notice, 0);
        _assertCancelled(notice, 1);
        require(_identity().identity(artistId).status == 4, "liveness does not clear compromise");
        Dismissal.Context memory fresh = ingress.identityContestDismissalContext(p);
        require(
            fresh.cohortHash != old.cohortHash && fresh.oldValueHash != old.oldValueHash,
            "notice terminal invalidates old governed cohort"
        );
        ArtistUnitGovernance authority = ArtistUnitGovernance(manager.governanceAuthority());
        ArtistUnitRoles(suite.roleRegistry).setArbiter(address(artist), true);
        authority.configureContestReads(
            suite.roleRegistry, address(artist), p.reasonHash, "urn:dismissal"
        );
        avm.expectRevert(Contest.InvalidContestGovernance.selector);
        authority.executeModuleContext(
            address(ingress),
            abi.encodeCall(IStreamArtistIdentityDismissal.dismissArtistIdentityContest, (p)),
            1,
            old.scopeHash,
            old.oldValueHash,
            old.newValueHash
        );
        this.executeGovernedDismissal(p, 1, 0);
        require(
            _identity().identity(artistId).status == 1,
            "fresh dismissal never resurrects cancelled notice"
        );
    }

    function testStewardSanctionUsesBurnBlockAtAppointmentAndIdenticalHealthyRetry() public {
        _accept();
        _grantSanction(true);
        _newRotationSafe(9305);
        bytes32 notice = this.beginDormancyNotice();
        this.completeDormancyNotice(notice);
        artist = rotationSafe;
        keys = rotationKeys;
        this.stewardSanctionBoundary();
    }

    function stewardSanctionBoundary() external {
        require(msg.sender == address(this), "self only");
        (Q.Request memory q,) = _sanctionPrepared();
        T.Authorization memory a = _sanctionAuthorization(q);
        bytes32 roots = _roots();
        avm.mockCall(
            address(core),
            abi.encodeCall(IStreamCoreBurn.collectionBurnsBlockedAtBlock, (uint256(1))),
            abi.encode(uint64(501))
        );
        vm.expectRevert(abi.encodeWithSelector(T.InvalidIdentity.selector, artistId));
        ingress.recordArtistSanction(q, a);
        require(
            _roots() == roots && !_identity().nonceUsed(artistId, a.nonce),
            "late burn block cannot consume sanction authority"
        );
        avm.mockCall(
            address(core),
            abi.encodeCall(IStreamCoreBurn.collectionBurnsBlockedAtBlock, (uint256(1))),
            abi.encode(uint64(500))
        );
        bytes32 record = ingress.recordArtistSanction(q, a);
        _assertSavedSanction(record, q.terms.sanctionSubjectHash, address(artist), 4);
    }

    function testActualDelegatedAttestationAutomaticallyCancelsPendingNotice() public {
        _accept();
        _payout();
        _delegateSetup();
        bytes32 grant = _grant(_delegation(1, 1, 0, type(uint64).max, 3));
        bytes32 notice = this.beginDormancyNotice();
        this.delegateAttestationDuringNotice(notice, grant);
    }

    function delegateAttestationDuringNotice(bytes32 notice, bytes32 grant) external {
        require(msg.sender == address(this), "self only");
        bytes memory statement = bytes("delegate is actively preserving the artist record");
        bytes32 assignment =
            primary.resolvePrimaryAssignment(1, 0, keccak256("PRIMARY_SALE")).assignmentHash;
        T.Attestation memory p = T.Attestation(
            1,
            6,
            bytes32(uint256(uint160(address(primary)))),
            assignment,
            keccak256("delegate notice schema"),
            keccak256(statement),
            "urn:delegate:notice"
        );
        T.Authorization memory a = T.Authorization(0, uint64(block.timestamp), "");
        a.signature = _delegateSignature(ingress.attestationDigest(p, a));
        bytes32 record = ingress.recordDelegatedArtistAttestation(p, grant, a, statement);
        _assertCancelled(notice, 2);
        require(
            record != 0 && ingress.recordDelegation(record) == grant
                && ingress.delegationRecord(grant).uses == 1
                && _operationPayload(24, address(this), record).length != 0,
            "actual authenticated delegated operation cancels atomically"
        );
    }

    function testDesignationCompletionVestsExactClass3CapabilitiesAndHistory() public {
        _accept();
        _newRotationSafe(9306);
        bytes32 designation = _successionRecord(_successorTerms(address(rotationSafe), 1));
        bytes32 notice = this.beginDormancyNotice();
        bytes32 record = this.completeDormancyNotice(notice);
        Estate.AuthorityCapabilities memory caps = ingress.currentAuthorityCapabilities(artistId);
        (,, Dorm.Terminal memory terminal) = _dorm().dormancyRecord(notice);
        require(
            caps.authorityClass == 3 && caps.effectiveCapabilities == 1
                && caps.activationRecordHash == record && terminal.plan.designation == designation
                && terminal.appointmentBlock == 0,
            "original designated successor is distinct from steward appointment"
        );
        V.Snapshot memory vesting = _identity().guardianVestingSnapshot(artistId, record);
        require(
            vesting.operationId == 43 && vesting.authorityClass == 3
                && vesting.oldAddress == address(artist)
                && vesting.newAddress == address(rotationSafe),
            "exact original op43 authority history"
        );
    }
}
