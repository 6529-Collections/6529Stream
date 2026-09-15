// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./StreamArtistGuardianSupersessionActual.t.sol";
import {
    IStreamArtistEstateOwner
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistEstateOwner.sol";

/// @dev Actual Artist/Safe/Archive estate flows. The unit Executor switches from the original
/// archival role graph to the constructor-pinned Artist graph after real coverage and op40.
/// Scheduled action facts remain typed fixtures; real delayed governance is a separate cohort.
contract StreamArtistEstateRecoveryActualTest is StreamArtistGuardianSupersessionActualTest {
    bytes32 private estateActivation;
    bytes32 private selectedEstateGuardian;
    bytes32 private lowerEstateGuardian;
    address private livingKey;
    OfficialSafe private lifetimeVetoSafe;
    uint256[] private lifetimeVetoKeys;
    bytes32 private estateOriginals;

    function _estateRecoveryCase(uint32 capabilities) private {
        _sizes();
        livingKey = address(artist);
        _delegateSetup();
        _newRotationSafe(55001);
        lifetimeVetoSafe = rotationSafe;
        lifetimeVetoKeys = rotationKeys;
        address[] memory members = new address[](1);
        members[0] = livingKey;
        selectedEstateGuardian = _guardianRecord(members, 1, 10 days, 900);
        members[0] = address(lifetimeVetoSafe);
        lowerEstateGuardian = _guardianRecord(members, 1, 20 days, 100);
        require(
            ArtistUnitGovernance(manager.governanceAuthority()).roleRegistry()
                == address(estateFixityRoles),
            "original archival fixture phase"
        );
        Estate.Execution memory activation = _estateActivateAndAdopt(capabilities);
        estateActivation = activation.expectedActivationRecordHash;
        V.Snapshot memory vesting = _snapshot(estateActivation);
        require(
            vesting.operationId == 40 && vesting.authorityClass == 3 && vesting.guardians.count == 2
                && vesting.previousTransitionRecordHash == 0,
            "actual first estate vesting prefix"
        );
        require(
            vesting.oldAddress == livingKey && vesting.newAddress == address(artist),
            "original estate successor"
        );
        R.TransitionState memory window = ingress.artistTransitionState(estateActivation);
        vm.warp(window.postWindowEndsAt);
        _newRotationSafe(55002);
        ArtistUnitGovernance authority = ArtistUnitGovernance(manager.governanceAuthority());
        ArtistUnitRoles(suite.roleRegistry).setArbiter(address(artist), true);
        authority.configureContestReads(
            suite.roleRegistry,
            address(artist),
            keccak256("compromise reason"),
            "urn:unit:estate-recovery"
        );
        require(
            authority.roleRegistry() == suite.roleRegistry,
            "restore authenticated Artist role graph"
        );
        (bytes32 scope, bytes32 oldHash, bytes32 newHash) = ingress.identityContestGovernanceContext(
            artistId,
            estateActivation,
            keccak256("compromise evidence"),
            keccak256("compromise reason")
        );
        authority.executeModuleContext(
            address(ingress), _contestData(estateActivation), 1, scope, oldHash, newHash
        );
        Dismissal.Cause memory cause = ingress.currentIdentityContestCause(artistId);
        require(
            cause.facts.authorityClass == 3 && cause.facts.priorStatus == 3
                && cause.facts.executedTransitionHash == estateActivation,
            "actual estate compromise cause"
        );
        require(
            ingress.artistTransitionState(estateActivation).contestedAt == window.postWindowEndsAt,
            "exact-expiry contest remains eligible"
        );
        estateOriginals = _estateOriginalHash();
    }

    function _estateOriginalHash() private view returns (bytes32) {
        (Estate.RequestRecord memory request, uint8 phase, Estate.ExecutionFacts memory execution) =
            ingress.estateActivationRecord(estateActivation);
        return keccak256(
            abi.encode(
                request,
                phase,
                execution,
                ingress.artistTransitionState(estateActivation),
                _snapshot(estateActivation),
                ingress.guardianSetRecord(selectedEstateGuardian),
                ingress.guardianSetRecord(lowerEstateGuardian),
                ingress.successorDesignationRecord(request.designationRecordHash),
                ingress.operativeSuccessorRecord(artistId),
                ingress.operativeEstateDirective(artistId)
            )
        );
    }

    function _estateRecoveryTerms() private view returns (IdentityRecovery.Request memory p) {
        Dismissal.Cause memory cause = ingress.currentIdentityContestCause(artistId);
        p = IdentityRecovery.Request(
            artistId,
            address(rotationSafe),
            3,
            cause.causeHash,
            ingress.latestIdentityContestDismissal(artistId),
            cause.facts.evidenceHash,
            cause.facts.reasonHash,
            new bytes32[](0)
        );
    }

    function _prepareEstate(
        IdentityRecovery.Request memory p,
        T.Authorization memory a,
        bytes32 action
    ) private {
        GovernanceCall[] memory calls = _schedule(action, p, a);
        ingress.registerIdentityRecoveryAction(currentId, calls, p, a);
        (A.Association memory association,,, uint64 count) = _read();
        require(
            count == 2 && association.guardian.recordHash == selectedEstateGuardian
                && association.contextHash
                    == keccak256(abi.encode(ingress.identityRecoveryContext(p, a))),
            "prepared exact estate context and operative guardian"
        );
    }

    function _executeEstateRecovery(IdentityRecovery.Request memory p, T.Authorization memory a)
        private
        returns (bytes32)
    {
        vm.warp(scheduled.notBefore);
        scheduled.status = GovernanceActionStatus.EXECUTED;
        _publish();
        return this.executeRegistered(p, a);
    }

    function _assertRecoveredEstate(
        bytes32 record,
        IdentityRecovery.Request memory p,
        uint32 capabilities,
        T.Identity memory prior,
        uint64 epoch
    ) private view {
        T.Identity memory principal = IStreamArtistIdentityOwner(suite.owners[2]).identity(artistId);
        Estate.AuthorityCapabilities memory rights = ingress.currentAuthorityCapabilities(artistId);
        IdentityRecovery.Record memory recovered = ingress.identityRecoveryRecord(record);
        require(
            principal.authorityAddress == p.newAddress && principal.authorityClass == 3
                && principal.status == 3 && principal.identityRecordHash == prior.identityRecordHash
                && principal.lastAuthorityActionAt == prior.lastAuthorityActionAt,
            "recovered estate identity preserves class and original identity/activity"
        );
        require(
            rights.authorityAddress == p.newAddress && rights.authorityClass == 3
                && rights.status == 3 && rights.effectiveCapabilities == capabilities
                && rights.activationRecordHash == estateActivation,
            "original estate activation and bounded capabilities survive key recovery"
        );
        require(
            recovered.fields.vestedAuthorityClass == 3
                && recovered.fields.oldAddress == prior.authorityAddress
                && recovered.fields.newAddress == p.newAddress
                && recovered.delegationEpoch == epoch + 1
                && recovered.postContestSeconds == 10 days,
            "class3 primary epoch and selected guardian window"
        );
        require(
            _estateOriginalHash() == estateOriginals,
            "all original estate guardian and vesting records remain exact"
        );
        V.Snapshot memory saved = _snapshot(record);
        V.Snapshot memory previous = _snapshot(estateActivation);
        require(
            saved.operationId == 35 && saved.authorityClass == 3
                && saved.oldAddress == prior.authorityAddress && saved.newAddress == p.newAddress
                && saved.previousTransitionRecordHash == estateActivation
                && saved.previousCommitment == previous.commitment
                && keccak256(abi.encode(saved.guardians))
                    == keccak256(abi.encode(previous.guardians)),
            "new recovery vesting chains exact estate prefix"
        );
        (bytes32 primary, bytes32 occurrence, bytes32 secondary) =
            IStreamArtistIdentityRecoveryOwner(suite.owners[2]).identityRecoveryReceipts(record);
        require(
            primary != 0 && occurrence != 0 && secondary != 0 && primary != secondary,
            "both ordered retained receipt commitments"
        );
        (bool livingRevoked, bytes32 livingRetirement) =
            ingress.priorAddressStandingRevoked(artistId, livingKey);
        (bool estateRevoked, bytes32 estateRetirement) =
            ingress.priorAddressStandingRevoked(artistId, prior.authorityAddress);
        require(
            !livingRevoked && !estateRevoked && livingRetirement == 0 && estateRetirement == 0,
            "neither prior principal standing was revoked"
        );
        (address originalPrior, bytes32 originalGuardian, uint64 originalTail) =
            IStreamArtistEstateOwner(suite.owners[2]).estateTransitionStanding(estateActivation);
        (address recoveredPrior, bytes32 recoveredGuardian, uint64 recoveredTail) =
            IStreamArtistIdentityRecoveryOwner(suite.owners[2]).recoveryTransitionStanding(record);
        require(
            originalPrior == livingKey && recoveredPrior == prior.authorityAddress
                && originalGuardian == selectedEstateGuardian
                && recoveredGuardian == selectedEstateGuardian && originalTail != 0
                && recoveredTail != 0,
            "separate permanent estate and recovery standing"
        );
    }

    function testActualEstateRecoveryPreservesCapabilitiesAndAtomicArchiveRetry() public {
        _estateRecoveryCase(2304);
        IdentityRecovery.Request memory p = _estateRecoveryTerms();
        T.Authorization memory a = _acceptance(p);
        IdentityRecovery.Context memory context = ingress.identityRecoveryContext(p, a);
        _prepareEstate(p, a, keccak256("estate recovery actual action"));
        vm.warp(scheduled.notBefore);
        scheduled.status = GovernanceActionStatus.EXECUTED;
        _publish();
        T.Identity memory prior = IStreamArtistIdentityOwner(suite.owners[2]).identity(artistId);
        T.Snapshot memory before_ = _ownerSnapshot();
        bytes32 roots = _roots();
        _overflow();
        this.executeRegistered(p, a);
        _inactive();
        (bool used,) = ingress.rotationAcceptanceNonceState(artistId, p.newAddress, a.nonce);
        require(
            !used && _roots() == roots && ingress.latestIdentityRecovery(artistId) == 0
                && keccak256(
                        abi.encode(IStreamArtistIdentityOwner(suite.owners[2]).identity(artistId))
                    ) == keccak256(abi.encode(prior)) && _estateOriginalHash() == estateOriginals,
            "late Archive failure rolls back acceptance principal receipts and history"
        );
        vm.roll(restoreBlock);
        vm.recordLogs();
        bytes32 recovered = this.executeRegistered(p, a);
        _assertSnapshot(_snapshot(recovered), 35, before_, vm.getRecordedLogs());
        _assertRecoveredEstate(recovered, p, 2304, prior, context.delegationEpoch);
        _adoptRotatedSafe();
        bytes32 newGuardian = _guardianRecord(new address[](0), 0, 0, nextNonce);
        R.GuardianRecord memory admitted = ingress.guardianSetRecord(newGuardian);
        require(
            admitted.authorityClass == 3 && admitted.signer == p.newAddress,
            "recovered Safe exercises actual granted estate capability"
        );
    }

    function removeEstateGuardians() external returns (bytes32) {
        require(msg.sender == address(this), "fixture caller");
        return _guardianRecord(new address[](0), 0, 0, nextNonce);
    }

    function testActualZeroCapabilityEstateRecoveryRejectsLivingEscalation() public {
        _estateRecoveryCase(0);
        IdentityRecovery.Request memory p = _estateRecoveryTerms();
        T.Authorization memory a = _acceptance(p);
        IdentityRecovery.Context memory context = ingress.identityRecoveryContext(p, a);
        bytes32 roots = _roots();
        p.vestedAuthorityClass = 1;
        vm.expectRevert(
            abi.encodeWithSelector(
                IdentityRecovery.UnsupportedIdentityRecoveryProfile.selector, artistId
            )
        );
        ingress.identityRecoveryContext(p, a);
        p.vestedAuthorityClass = 3;
        bytes32 reason = p.reasonHash;
        p.reasonHash = keccak256("unrelated estate recovery reason");
        vm.expectRevert();
        ingress.identityRecoveryContext(p, a);
        p.reasonHash = reason;
        p.supersededRecordHashes = new bytes32[](1);
        p.supersededRecordHashes[0] = lowerEstateGuardian;
        vm.expectRevert(
            abi.encodeWithSelector(
                IdentityRecovery.UnsupportedIdentityRecoveryProfile.selector, artistId
            )
        );
        ingress.identityRecoveryContext(p, a);
        p.supersededRecordHashes = new bytes32[](0);
        require(_roots() == roots, "invalid profile reads have no owner effect");
        _prepareEstate(p, a, keccak256("zero mask estate action"));
        T.Identity memory prior = IStreamArtistIdentityOwner(suite.owners[2]).identity(artistId);
        bytes32 recovered = _executeEstateRecovery(p, a);
        _assertRecoveredEstate(recovered, p, 0, prior, context.delegationEpoch);
        _adoptRotatedSafe();
        roots = _roots();
        vm.expectRevert(
            abi.encodeWithSelector(
                Estate.EstateCapabilityUnavailable.selector, artistId, uint32(2048)
            )
        );
        this.removeEstateGuardians();
        require(
            _roots() == roots
                && ingress.currentAuthorityCapabilities(artistId).effectiveCapabilities == 0,
            "zero original estate mask never becomes living full authority"
        );
    }

    function testActualEstateRecoveryLifetimeLowerNonceGuardianVeto() public {
        _estateRecoveryCase(2048);
        IdentityRecovery.Request memory p = _estateRecoveryTerms();
        T.Authorization memory a = _acceptance(p);
        _prepareEstate(p, a, keccak256("estate lifetime veto action"));
        (address[] memory operative,,,) = ingress.guardianSet(artistId);
        require(
            operative.length == 1 && operative[0] != address(lifetimeVetoSafe),
            "veto actor appears only in unselected original lower nonce set"
        );
        vm.warp(scheduled.notBefore);
        bytes32 reason = keccak256("lifetime estate guardian veto");
        require(
            executeSafe(
                lifetimeVetoSafe,
                lifetimeVetoKeys,
                address(ingress),
                0,
                abi.encodeCall(
                    IStreamArtistRecoveryAction.vetoIdentityRecovery, (artistId, reason)
                ),
                0
            ),
            "original lifetime guardian Safe veto after notBefore"
        );
        (, A.Veto memory veto,,) = _read();
        require(
            veto.vetoer == address(lifetimeVetoSafe) && veto.reasonHash == reason
                && veto.vetoedAt == block.timestamp,
            "permanent action-local guardian veto"
        );
        bytes32 roots = _roots();
        scheduled.status = GovernanceActionStatus.EXECUTED;
        _publish();
        vm.expectRevert(abi.encodeWithSelector(A.RecoveryActionVetoed.selector, currentId));
        this.executeRegistered(p, a);
        _inactive();
        (bool used,) = ingress.rotationAcceptanceNonceState(artistId, p.newAddress, a.nonce);
        require(
            !used && _roots() == roots && ingress.latestIdentityRecovery(artistId) == 0
                && _estateOriginalHash() == estateOriginals,
            "veto prevents recovery and nonce consumption"
        );
    }
}
