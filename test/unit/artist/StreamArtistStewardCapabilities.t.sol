// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "./StreamArtistDormancyLifecycle.t.sol";
import {
    StreamArtistStewardCapabilityTypes as SC
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistStewardCapabilities.sol";
import "../../../smart-contracts/interfaces/stream/artist/IStreamArtistStewardCapabilities.sol";

interface StewardGrantStorageVm {
    function record() external;
    function accesses(address target) external returns (bytes32[] memory, bytes32[] memory);
}

/// @notice Actual Artist/Safe/Archive operation59; Executor admission and Core observations are explicit typed unit boundaries.
contract StreamArtistStewardCapabilitiesTest is StreamArtistDormancyLifecycleTest {
    error LateGrantArchive();
    address private grantExecutor;

    function stewardGrantCurrentTime() external view returns (uint64) {
        require(msg.sender == address(this), "self only");
        return uint64(block.timestamp);
    }

    function _prepareStewardGrant(bool directive) internal returns (bytes32 appointment) {
        _accept();
        _payout();
        if (directive) _directiveRecord(0);
        _newRotationSafe(9401);
        bytes32 notice = this.beginDormancyNotice();
        appointment = this.completeDormancyNotice(notice);
        artist = rotationSafe;
        keys = rotationKeys;
    }

    function _terms(uint32 added) internal view returns (SC.Grant memory p) {
        Estate.AuthorityCapabilities memory caps = ingress.currentAuthorityCapabilities(artistId);
        (bytes32 head,) = ingress.stewardCapabilityGrantState(caps.activationRecordHash);
        return SC.Grant(
            artistId,
            caps.activationRecordHash,
            address(artist),
            ingress.operativeEstateDirective(artistId),
            head,
            caps.effectiveCapabilities,
            added,
            keccak256("independent veto checked steward permission"),
            "urn:steward:terminal-grant"
        );
    }

    function _admitGrant(SC.Grant memory p, uint8 fault) internal returns (SC.Context memory x) {
        x = ingress.stewardCapabilityGrantContext(p);
        address authority = manager.governanceAuthority();
        grantExecutor = authority;
        uint64 observed = this.stewardGrantCurrentTime();
        GovernanceAction memory action;
        action.status = GovernanceActionStatus.EXECUTED;
        action.actionClass = 2;
        action.proposer = address(this);
        action.executor = address(this);
        action.notBefore = observed - 1;
        action.expiresAfter = observed + 1 days;
        action.reasonHash = p.reasonHash;
        action.reasonURI = p.reasonURI;
        // These fields deliberately index another first call. The target validates current per-call context.
        action.target = address(0x1234);
        action.selector = 0x12345678;
        action.scopeHash = keccak256("different first call");
        if (fault == 6) action.vetoer = address(0xDEAD);
        if (fault == 7) action.reasonHash = keccak256("wrong stored reason");
        avm.mockCall(
            authority,
            abi.encodeCall(
                IStreamGovernanceReads.governanceAction, (keccak256("unit authority gas raise"))
            ),
            abi.encode(action)
        );
        avm.mockCall(
            authority,
            abi.encodeCall(
                IStreamGovernanceReads.terminalFreezeGuardianConfigCommitment,
                (keccak256("unit authority gas raise"))
            ),
            abi.encode(fault == 5 ? bytes32(0) : keccak256("captured independent veto set"))
        );
        avm.mockCall(
            authority,
            abi.encodeCall(
                IStreamGovernanceReads.freezeSelectorConfig,
                (
                    address(ingress),
                    IStreamArtistStewardCapabilities.grantStewardCapabilities.selector
                )
            ),
            abi.encode(
                fault != 3,
                fault == 4 ? keccak256("wrong admitted runtime") : address(ingress).codehash,
                uint64(1),
                keccak256("actual selected grant selector config")
            )
        );
        if (fault == 2) x.oldValueHash = keccak256("wrong current call context");
    }

    function _executeGrant(SC.Grant memory p, SC.Context memory x, uint8 class_)
        internal
        returns (bytes32 record)
    {
        ArtistUnitGovernance(grantExecutor)
            .executeModuleContext(
                address(ingress),
                abi.encodeCall(IStreamArtistStewardCapabilities.grantStewardCapabilities, (p)),
                class_,
                x.scopeHash,
                x.oldValueHash,
                x.newValueHash
            );
        (record,) = ingress.stewardCapabilityGrantState(p.expectedAppointmentHash);
    }

    function _healthyGrant(SC.Grant memory p) internal returns (bytes32) {
        return _executeGrant(p, _admitGrant(p, 0), 2);
    }

    function testLaterEconomicsGrantEnablesSameSignedOp15AndRetainsImmutableAppointment() public {
        _prepareStewardGrant(false);
        this.economicsAfterStewardGrant();
    }

    function economicsAfterStewardGrant() external {
        require(msg.sender == address(this), "self only");
        T.EconomicsConsent memory economics = _currentEconomics(address(primary));
        T.Authorization memory a = _authorization(false);
        a.signature = _signature(ingress.economicsConsentDigest(economics, a));
        vm.expectRevert(
            abi.encodeWithSelector(Estate.EstateCapabilityUnavailable.selector, artistId, uint32(4))
        );
        ingress.recordEconomicsConsent(economics, a);
        SC.Grant memory p = _terms(4);
        (bytes32 notice,,) = _dorm().dormancyNotice(artistId);
        (,, Dorm.Terminal memory before_) = _dorm().dormancyRecord(notice);
        bytes32 original = keccak256(abi.encode(before_));
        bytes32 record = _healthyGrant(p);
        SC.Record memory saved = ingress.stewardCapabilityGrantRecord(record);
        require(
            saved.recordHash == record && saved.terms.expectedGrantHead == 0
                && saved.effectiveCapabilities == 373 && saved.witness.guardianCommitment != 0,
            "actual separate original appointment grant chain"
        );
        saved.recordHash = 0;
        require(
            record
                == keccak256(
                    abi.encode(
                        keccak256("6529STREAM_ARTIST_STEWARD_CAPABILITY_GRANT_V1"),
                        block.chainid,
                        address(ingress),
                        suite.owners[2],
                        saved
                    )
                ),
            "independent complete grant record commitment"
        );
        (,, Dorm.Terminal memory after_) = _dorm().dormancyRecord(notice);
        require(
            keccak256(abi.encode(after_)) == original,
            "operation59 never mutates original operation43"
        );
        require(
            _operationPayload(59, manager.governanceAuthority(), record).length != 0,
            "actual operation59 Archive"
        );
        bytes32 consent = ingress.recordEconomicsConsent(economics, a);
        require(
            consent != 0 && _operationPayload(15, address(this), consent).length != 0,
            "same originally denied signed economics consent succeeds"
        );
    }

    function testLaterSanctionGrantStillRequiresBurnBlockAtAppointment() public {
        _prepareStewardGrant(false);
        _healthyGrant(_terms(8));
        this.stewardSanctionBoundary();
        require(
            ingress.currentAuthorityCapabilities(artistId).effectiveCapabilities == 377,
            "sanction-only addition preserves exclusions"
        );
    }

    function testGrantRejectsStaleAppointmentHeadRepeatedAndForbiddenBits() public {
        _prepareStewardGrant(false);
        SC.Grant memory p = _terms(4);
        SC.Grant memory bad = p;
        bad.expectedAppointmentHash = keccak256("foreign appointment");
        avm.expectPartialRevert(SC.InvalidStewardCapabilityGrant.selector);
        ingress.stewardCapabilityGrantContext(bad);
        p = _terms(4);
        p.expectedSteward = address(0x1234);
        avm.expectPartialRevert(SC.InvalidStewardCapabilityGrant.selector);
        ingress.stewardCapabilityGrantContext(p);
        p = _terms(4);
        bytes32 first = _healthyGrant(p);
        p.addedCapabilities = 8;
        avm.expectPartialRevert(SC.InvalidStewardCapabilityGrant.selector);
        ingress.stewardCapabilityGrantContext(p);
        p = _terms(4);
        avm.expectPartialRevert(SC.InvalidStewardCapabilityGrant.selector);
        ingress.stewardCapabilityGrantContext(p);
        p = _terms(2);
        avm.expectPartialRevert(SC.InvalidStewardCapabilityGrant.selector);
        ingress.stewardCapabilityGrantContext(p);
        p = _terms(2048);
        avm.expectPartialRevert(SC.InvalidStewardCapabilityGrant.selector);
        ingress.stewardCapabilityGrantContext(p);
        p = _terms(8);
        bytes32 second = _healthyGrant(p);
        require(
            ingress.stewardCapabilityGrantRecord(second).terms.expectedGrantHead == first
                && ingress.currentAuthorityCapabilities(artistId).effectiveCapabilities == 381,
            "fresh exact head admits remaining permitted bit only"
        );
    }

    function testActualDirectiveHeadDriftRefusesGrantAndExactRestorationRecoversContext() public {
        _prepareStewardGrant(true);
        SC.Grant memory p = _terms(4);
        SC.Context memory before_ = ingress.stewardCapabilityGrantContext(p);
        StewardGrantStorageVm trace = StewardGrantStorageVm(address(vm));
        trace.record();
        bytes32 directive = ingress.operativeEstateDirective(artistId);
        (bytes32[] memory reads,) = trace.accesses(suite.owners[2]);
        uint256 count;
        bytes32 slot;
        for (uint256 i; i < reads.length; ++i) {
            if (vm.load(suite.owners[2], reads[i]) == directive) {
                slot = reads[i];
                ++count;
            }
        }
        require(count == 1 && directive != 0, "unique actual operative directive pointer");
        vm.store(suite.owners[2], slot, keccak256("foreign operative directive"));
        avm.expectPartialRevert(SC.InvalidStewardCapabilityGrant.selector);
        ingress.stewardCapabilityGrantContext(p);
        vm.store(suite.owners[2], slot, directive);
        require(
            keccak256(abi.encode(ingress.stewardCapabilityGrantContext(p)))
                == keccak256(abi.encode(before_)),
            "exact original context restored"
        );
        require(_healthyGrant(p) != 0, "identical requested grant after restoration");
    }

    function testForbiddenArtistDirectiveAndCurrentSuccessorCannotReceiveStewardGrant() public {
        _accept();
        _directiveRecord(4);
        _newRotationSafe(9402);
        bytes32 notice = this.beginDormancyNotice();
        this.completeDormancyNotice(notice);
        artist = rotationSafe;
        keys = rotationKeys;
        SC.Grant memory p = _terms(4);
        avm.expectPartialRevert(SC.InvalidStewardCapabilityGrant.selector);
        ingress.stewardCapabilityGrantContext(p);
        p = _terms(8);
        require(
            _healthyGrant(p) != 0, "different explicitly permitted bit survives forbidden economics"
        );
    }

    function testCurrentClass3DesignationCannotUseOperation59() public {
        _accept();
        _newRotationSafe(9403);
        _successionRecord(_successorTerms(address(rotationSafe), 1));
        bytes32 notice = this.beginDormancyNotice();
        this.completeDormancyNotice(notice);
        artist = rotationSafe;
        keys = rotationKeys;
        SC.Grant memory p = _terms(8);
        avm.expectPartialRevert(SC.InvalidStewardCapabilityGrant.selector);
        ingress.stewardCapabilityGrantContext(p);
    }

    function testTerminalFreezeClassContextAdmissionVetoAndReasonFailuresLeaveState() public {
        _prepareStewardGrant(false);
        SC.Grant memory p = _terms(4);
        bytes32 roots = _roots();
        for (uint8 fault = 1; fault <= 7; ++fault) {
            SC.Context memory x = _admitGrant(p, fault);
            avm.expectRevert(SC.InvalidStewardGrantGovernance.selector);
            _executeGrant(p, x, fault == 1 ? 1 : 2);
            require(
                _roots() == roots, "invalid terminal-freeze witness cannot mutate owner or Archive"
            );
        }
        SC.Context memory x = _admitGrant(p, 0);
        avm.mockCallRevert(
            manager.governanceAuthority(),
            abi.encodeCall(
                IStreamGovernanceReads.freezeSelectorConfig,
                (
                    address(ingress),
                    IStreamArtistStewardCapabilities.grantStewardCapabilities.selector
                )
            ),
            abi.encodeWithSignature("NoFreezeAdmission()")
        );
        avm.expectRevert(SC.InvalidStewardGrantGovernance.selector);
        _executeGrant(p, x, 2);
        avm.clearMockedCalls();
        require(_healthyGrant(p) != 0, "same grant succeeds with complete original admission");
    }

    function testOperation59LateArchiveFailureRollsBackHeadMaskAndAllowsExactRetry() public {
        _prepareStewardGrant(false);
        SC.Grant memory p = _terms(12);
        SC.Context memory x = _admitGrant(p, 0);
        bytes32 roots = _roots();
        avm.mockCallRevert(
            suite.archive,
            abi.encodePacked(IStreamArtistArchiveV2.appendArtistEvidenceV2.selector),
            abi.encodeWithSelector(LateGrantArchive.selector)
        );
        avm.expectRevert(LateGrantArchive.selector);
        _executeGrant(p, x, 2);
        (bytes32 head, uint32 mask) = ingress.stewardCapabilityGrantState(p.expectedAppointmentHash);
        require(
            head == 0 && mask == 0 && _roots() == roots, "complete grant history and owner rollback"
        );
        avm.clearMockedCalls();
        x = _admitGrant(p, 0);
        bytes32 record = _executeGrant(p, x, 2);
        require(
            record != 0
                && ingress.currentAuthorityCapabilities(artistId).effectiveCapabilities == 381,
            "identical grant and context retry after late archive restoration"
        );
    }
}
