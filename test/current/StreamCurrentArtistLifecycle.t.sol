// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../helpers/StreamCurrentSafeGovernanceFixture.sol";
import {
    StreamArtistRotationTypes as LifeRotation
} from "../../smart-contracts/interfaces/stream/artist/StreamArtistRotationTypes.sol";
import {
    StreamArtistSuccessionTypes as LifeSuccession
} from "../../smart-contracts/interfaces/stream/artist/StreamArtistSuccessionTypes.sol";

/// @notice Current Core/artist owners and real Safe/Executor lifecycle composition.
contract StreamCurrentArtistLifecycleTest is StreamCurrentSafeGovernanceFixture {
    OfficialSafe private currentSafe;
    OfficialSafe private priorSafe;
    OfficialSafe private nextSafe;
    uint256[] private currentKeys;
    uint256[] private priorKeys;
    uint256[] private nextKeys;
    bytes32 private constant ARBITER = keccak256("ROLE_ATTRIBUTION_ARBITER");

    struct Cohort {
        bytes32 rotation;
        bytes32 stableGuardian;
        bytes32 childGuardian;
        bytes32 stableSuccessor;
        bytes32 childSuccessor;
        bytes32 stableDirective;
        bytes32 childDirective;
        bytes32 stablePayout;
        bytes32 childPayout;
        bytes32 stableRevision;
        bytes32 childRevision;
        bytes32 stableDocument;
        bytes32 childDocument;
        uint64 end;
    }

    function setUp() public {
        currentKeys.push(0x5AFE51);
        currentKeys.push(0x5AFE52);
        nextKeys.push(0x5AFE61);
        nextKeys.push(0x5AFE62);
        SafeComponents memory components = deploySafeComponents("1.4.1");
        currentSafe = createOfficialSafe(components, safeOwnerAddresses(currentKeys), 2, 251);
        nextSafe = createOfficialSafe(components, safeOwnerAddresses(nextKeys), 2, 252);
        uint256[] memory governorSigners = new uint256[](2);
        governorSigners[0] = 0x5AFE71;
        governorSigners[1] = 0x5AFE72;
        OfficialSafe governor =
            createOfficialSafe(components, safeOwnerAddresses(governorSigners), 2, 253);
        _deployCurrentStack(address(currentSafe), vm.addr(PLATFORM_KEY));
        _installGovernorSafe(governor, governorSigners);
        _setRole(ARBITER, address(governorSafe), true);
    }

    function _artistProof(bytes32 digest) internal override returns (bytes memory) {
        return
            safeThresholdSignature(currentKeys, safeMessageDigest(currentSafe, abi.encode(digest)));
    }

    function _authorization(bool signedAt) private view returns (T.Authorization memory a) {
        a.nonce =
        IStreamArtistIdentityOwner(artistSuite.owners[2]).identity(fixtureArtistId).nonceHint;
        a.time = uint64(block.timestamp + (signedAt ? 0 : 1 days));
    }

    function testCurrentSafeSuccessionRecordsUseObservedNonceAndPreserveReplay() public {
        uint256 nonce = _authorization(true).nonce;
        LifeSuccession.Designation memory p = _successorTerms(address(nextSafe), 2);
        T.Authorization memory direct = T.Authorization(0, 0, "");
        bytes memory callData = abi.encodeCall(artists.recordSuccessorDesignation, (p, direct));
        this.executeLifecycleSafe(currentSafe, currentKeys, callData);
        bytes32 record = artists.operativeSuccessorRecord(fixtureArtistId);
        require(
            record
                == keccak256(
                    abi.encode(
                        keccak256("6529STREAM_ARTIST_SUCCESSION_RECORD_V1"),
                        block.chainid,
                        address(artists),
                        fixtureArtistId,
                        p.successor,
                        p.successorKind,
                        p.grantedCapabilities,
                        p.conditionsHash,
                        p.directiveHash,
                        nonce,
                        uint64(block.timestamp)
                    )
                ),
            "direct Safe uses current observed nonce and time"
        );
        LifeSuccession.DesignationRecord memory stored = artists.successorDesignationRecord(record);
        require(
            stored.signer == address(currentSafe) && stored.authorityClass == 1,
            "current artist authority"
        );
        _safeRead(abi.encodeCall(artists.successorDesignation, (fixtureArtistId)));
        _safeRead(abi.encodeCall(artists.successorDesignationRecord, (record)));
        _safeRead(abi.encodeCall(artists.operativeSuccessorRecord, (fixtureArtistId)));

        (LifeSuccession.Directive memory terms, LifeSuccession.PublicDocument memory document) =
            _directiveTerms(4);
        T.Authorization memory signed = _authorization(true);
        signed.signature = _artistProof(artists.estateDirectiveDigest(terms, signed));
        bytes32 directive = artists.recordEstateDirective(terms, signed, document);
        require(
            directive
                == keccak256(
                    abi.encode(
                        keccak256("6529STREAM_ARTIST_ESTATE_DIRECTIVE_RECORD_V1"),
                        block.chainid,
                        address(artists),
                        fixtureArtistId,
                        terms.grantedCapabilities,
                        terms.forbiddenCapabilities,
                        terms.directivePayloadHash,
                        signed.nonce,
                        signed.time
                    )
                ),
            "relayed Safe directive retains exact signed facts"
        );
        require(
            keccak256(artists.estateDirectivePayload(directive)) == terms.directivePayloadHash,
            "stored directive bytes"
        );
        bytes32 root = _identityRoot();
        vm.expectRevert();
        artists.recordEstateDirective(terms, signed, document);
        require(
            _identityRoot() == root
                && artists.operativeEstateDirective(fixtureArtistId) == directive,
            "exact proof replay has no effects"
        );
        _safeRead(abi.encodeCall(artists.estateDirectiveRecord, (directive)));
        _safeRead(abi.encodeCall(artists.estateDirectivePayload, (directive)));
        _safeRead(abi.encodeCall(artists.operativeEstateDirective, (fixtureArtistId)));
        _safeRead(
            abi.encodeCall(
                artists.previewEstateDirectivePayload,
                (terms.grantedCapabilities, terms.forbiddenCapabilities, document)
            )
        );
        _safeRead(abi.encodeCall(artists.successorDesignationDigest, (p, direct)));
        _safeRead(abi.encodeCall(artists.estateDirectiveDigest, (terms, signed)));
    }

    function testCurrentDismissalBeforeCohortExpiryCannotLaterMatureAbandonedHeads() public {
        _exerciseCohort(0);
    }

    function testCurrentDismissalAtCohortExpiryRetainsEveryMatureHead() public {
        _exerciseCohort(1);
    }

    function testCurrentDismissalAfterCohortExpiryRetainsEveryMatureHead() public {
        _exerciseCohort(2);
    }

    function _exerciseCohort(uint8 boundary) private {
        Cohort memory f = _cohort();
        vm.warp(uint256(f.end) + boundary - 1);
        _contest(f.rotation);
        bytes32 frozenTransition = keccak256(abi.encode(artists.rotationRecord(f.rotation)));
        bytes32 dismissal = _dismiss(false, bytes32(0));
        Dismissal.Closure memory closure_ =
            artists.identityTransitionClosure(fixtureArtistId, f.rotation);
        require(
            closure_.dismissalRecordHash == dismissal && closure_.windowEndsAt == f.end
                && closure_.contestedAt == uint256(f.end) + boundary - 1
                && closure_.abandoned == (boundary == 0),
            "exact closure uses contest time, not delayed execution time"
        );
        require(block.timestamp > f.end, "real Executor delay crosses original expiry");
        require(
            keccak256(abi.encode(artists.rotationRecord(f.rotation))) == frozenTransition,
            "terminal closure preserves transition history"
        );
        _assertSelection(f, boundary != 0);
        vm.warp(block.timestamp + 30 days);
        _assertSelection(f, boundary != 0);
        require(
            artists.identityRevisionRecord(f.childRevision).recordHash == f.childRevision
                && artists.successorDesignationRecord(f.childSuccessor).recordHash
                    == f.childSuccessor
                && artists.estateDirectiveRecord(f.childDirective).recordHash == f.childDirective,
            "all child history remains readable"
        );
        (bytes32 window,,) = artists.activeAuthorityWindow(fixtureArtistId);
        require(window == 0, "resolved cohort cannot block new work");
        if (boundary == 0) {
            bytes32 freshRevision = _revise(bytes("post-dismissal current identity"));
            require(
                artists.identityRevisionRecord(freshRevision).previousRevisionRecord
                    == f.stableRevision,
                "revision continues from stable record"
            );
            bytes32 freshPayout = _payout(address(governorSafe));
            require(
                freshPayout != f.childPayout
                    && StreamArtistPayoutLifecycle(artistSuite.owners[5])
                            .payoutAbandonment(f.childPayout) == dismissal,
                "actual Payout lazily detaches exact abandoned child"
            );
            _successor(address(governorSafe), 2);
            _directive(0);
            _guardian(address(governorSafe));
        }
        _safeRead(abi.encodeCall(artists.identityTransitionClosure, (fixtureArtistId, f.rotation)));
        _safeRead(abi.encodeCall(artists.identityContestDismissalRecord, (dismissal)));
    }

    function testCurrentGovernedDismissalRemovesOnlyTheExactRetiredStanding() public {
        bytes32 rotation = _rotate();
        _contest(rotation);
        bytes32 dismissal = _dismiss(true, rotation);
        (bool revoked, bytes32 judgment) =
            artists.priorAddressStandingRevoked(fixtureArtistId, address(priorSafe));
        require(revoked && judgment == dismissal, "real governed retirement-specific judgment");
        // Keep the first cause's replay cell occupied. This new evidence must
        // fail solely for lost standing, then succeed with independent guardianship.
        bytes memory repeat = abi.encodeCall(
            artists.contestArtistIdentity,
            (
                fixtureArtistId,
                rotation,
                keccak256("fresh current guardian evidence"),
                GOVERNANCE_REASON
            )
        );
        bytes32 root = _identityRoot();
        bytes32 retainedCause = artists.currentIdentityContestCause(fixtureArtistId).causeHash;
        vm.expectRevert(abi.encodeWithSignature("Error(string)", "GS013"));
        this.executeLifecycleSafe(priorSafe, priorKeys, repeat);
        require(
            _identityRoot() == root
                && artists.currentIdentityContestCause(fixtureArtistId).causeHash == retainedCause,
            "removed prior standing cannot file another cause"
        );
        // A later independent guardian grant restores that role only, without undoing retirement.
        _guardian(address(priorSafe));
        this.executeLifecycleSafe(priorSafe, priorKeys, repeat);
        require(
            IStreamArtistIdentityOwner(artistSuite.owners[2]).identity(fixtureArtistId).status == 4,
            "independent guardian still has defensive authority"
        );
        (revoked, judgment) =
            artists.priorAddressStandingRevoked(fixtureArtistId, address(priorSafe));
        require(
            revoked && judgment == dismissal,
            "guardian authority does not erase retirement judgment"
        );
    }

    function _cohort() private returns (Cohort memory f) {
        f.stableGuardian = _guardian(address(currentSafe));
        f.stableRevision = _revise(bytes("stable current cohort identity"));
        f.stableDocument = artists.operativeIdentityRecord(fixtureArtistId);
        f.stableSuccessor = _successor(address(governorSafe), 2);
        f.stableDirective = _directive(0);
        (, f.stablePayout) = artists.artistPayoutAccount(fixtureArtistId);
        f.rotation = _rotate();
        f.childGuardian = _guardian(address(governorSafe));
        f.childRevision = _revise(bytes("provisional current cohort identity"));
        f.childDocument = keccak256("provisional current cohort identity");
        f.childSuccessor = _successor(address(0xBEEF), 1);
        f.childDirective = _directive(4);
        f.childPayout = _payout(address(currentSafe));
        f.end = artists.rotationRecord(f.rotation).transition.postWindowEndsAt;
        require(
            block.timestamp < f.end, "all five children created in the actual provisional window"
        );
        _assertSelection(f, false);
    }

    function _assertSelection(Cohort memory f, bool mature) private view {
        (,,, bytes32 guardian) = artists.guardianSet(fixtureArtistId);
        (, bytes32 payout) = artists.artistPayoutAccount(fixtureArtistId);
        require(
            guardian == (mature ? f.childGuardian : f.stableGuardian)
                && payout == (mature ? f.childPayout : f.stablePayout)
                && artists.operativeSuccessorRecord(fixtureArtistId)
                    == (mature ? f.childSuccessor : f.stableSuccessor)
                && artists.operativeEstateDirective(fixtureArtistId)
                    == (mature ? f.childDirective : f.stableDirective)
                && artists.operativeIdentityRecord(fixtureArtistId)
                    == (mature ? f.childDocument : f.stableDocument),
            "five actual owner selections agree with the captured cohort"
        );
    }

    function _rotate() private returns (bytes32 record) {
        LifeRotation.Rotation memory p = LifeRotation.Rotation(
            fixtureArtistId,
            address(currentSafe),
            address(nextSafe),
            keccak256("current Safe rotation"),
            bytes32(0)
        );
        T.Authorization memory oldA = _authorization(false);
        oldA.signature = _artistProof(artists.rotationDigest(p, oldA));
        T.Authorization memory newA = T.Authorization(0, uint64(block.timestamp + 1 days), "");
        newA.signature = safeThresholdSignature(
            nextKeys,
            safeMessageDigest(nextSafe, abi.encode(artists.rotationAcceptanceDigest(p, newA)))
        );
        record = artists.rotateArtistAddress(p, oldA, newA);
        uint64 ready = artists.rotationRecord(record).transition.contestEndsAt;
        vm.warp(ready);
        this.executeCurrentGovernorCall(
            address(artists),
            abi.encodeCall(artists.executeArtistRotation, (fixtureArtistId, record))
        );
        priorSafe = currentSafe;
        priorKeys = currentKeys;
        currentSafe = nextSafe;
        currentKeys = nextKeys;
        require(
            artists.acceptedArtist(1) == address(currentSafe), "real binding reads rotated Safe"
        );
    }

    function _guardian(address account) private returns (bytes32) {
        address[] memory members = new address[](1);
        members[0] = account;
        LifeRotation.GuardianSet memory p = LifeRotation.GuardianSet(fixtureArtistId, members, 1, 0);
        T.Authorization memory a = _authorization(true);
        a.signature = _artistProof(artists.guardianSetDigest(p, a));
        return artists.setArtistGuardians(p, a);
    }

    function _revise(bytes memory document) private returns (bytes32) {
        StreamArtistIdentityRevisionTypes.Revision memory p =
            StreamArtistIdentityRevisionTypes.Revision(
                fixtureArtistId,
                artists.operativeIdentityRecord(fixtureArtistId),
                keccak256(document),
                "urn:current:cohort:identity"
            );
        T.Authorization memory a = _authorization(true);
        a.signature = _artistProof(artists.identityRevisionDigest(p, a));
        return artists.recordIdentityRevision(p, a, document, "Current lifecycle artist");
    }

    function _successorTerms(address account, uint8 kind)
        private
        view
        returns (LifeSuccession.Designation memory)
    {
        return LifeSuccession.Designation(
            fixtureArtistId, account, kind, 4095, keccak256("current estate conditions"), bytes32(0)
        );
    }

    function _successor(address account, uint8 kind) private returns (bytes32) {
        LifeSuccession.Designation memory p = _successorTerms(account, kind);
        T.Authorization memory a = _authorization(true);
        a.signature = _artistProof(artists.successorDesignationDigest(p, a));
        return artists.recordSuccessorDesignation(p, a);
    }

    function _directiveTerms(uint32 forbidden)
        private
        view
        returns (LifeSuccession.Directive memory p, LifeSuccession.PublicDocument memory document)
    {
        document = LifeSuccession.PublicDocument(
            keccak256("current legal instrument"), keccak256("current payout intent")
        );
        uint32 granted = uint32(4095) & ~forbidden;
        p = LifeSuccession.Directive(
            fixtureArtistId,
            granted,
            forbidden,
            keccak256(artists.previewEstateDirectivePayload(granted, forbidden, document))
        );
    }

    function _directive(uint32 forbidden) private returns (bytes32) {
        (LifeSuccession.Directive memory p, LifeSuccession.PublicDocument memory document) =
            _directiveTerms(forbidden);
        T.Authorization memory a = _authorization(true);
        a.signature = _artistProof(artists.estateDirectiveDigest(p, a));
        return artists.recordEstateDirective(p, a, document);
    }

    function _payout(address account) private returns (bytes32) {
        (, bytes32 previous) = artists.artistPayoutAccount(fixtureArtistId);
        T.PayoutDesignation memory p = T.PayoutDesignation(fixtureArtistId, account, previous);
        T.Authorization memory a = _authorization(true);
        a.signature = _artistProof(artists.payoutDesignationDigest(p, a));
        return artists.recordPayoutDesignation(p, a);
    }

    function _contestData(bytes32 rotation) private view returns (bytes memory) {
        return abi.encodeCall(
            artists.contestArtistIdentity,
            (fixtureArtistId, rotation, keccak256("current cohort evidence"), GOVERNANCE_REASON)
        );
    }

    function _contest(bytes32 rotation) private {
        this.executeLifecycleSafe(priorSafe, priorKeys, _contestData(rotation));
        require(
            IStreamArtistIdentityOwner(artistSuite.owners[2]).identity(fixtureArtistId).status == 4,
            "actual prior Safe contest"
        );
    }

    function _dismiss(bool removeStanding, bytes32 retirement) private returns (bytes32) {
        Dismissal.Request memory terms = Dismissal.Request(
            fixtureArtistId,
            artists.currentIdentityContestCause(fixtureArtistId).causeHash,
            artists.latestIdentityContestDismissal(fixtureArtistId),
            keccak256("current adjudication"),
            GOVERNANCE_REASON,
            removeStanding,
            retirement
        );
        Dismissal.Context memory c = artists.identityContestDismissalContext(terms);
        _govern(
            _governanceRequest(
                1,
                address(artists),
                abi.encodeCall(artists.dismissArtistIdentityContest, (terms)),
                c.scopeHash,
                c.oldValueHash,
                c.newValueHash
            )
        );
        bytes32 record = artists.latestIdentityContestDismissal(fixtureArtistId);
        Dismissal.Record memory stored = artists.identityContestDismissalRecord(record);
        require(
            stored.executor == address(executor) && stored.proposer == address(governorSafe)
                && stored.incumbent == address(currentSafe) && stored.restoredStatus == 1,
            "real Executor restores exact current Safe"
        );
        return record;
    }

    function _identityRoot() private view returns (bytes32) {
        return
            keccak256(abi.encode(IStreamArtistOwner(artistSuite.owners[2]).ownerStateSnapshotV2()));
    }

    function _safeRead(bytes memory data) private {
        (bool ok, bytes memory expected) = address(artists).staticcall(data);
        vm.prank(address(governorSafe));
        (bool safeOk, bytes memory observed) = address(artists).staticcall(data);
        require(
            ok && safeOk && keccak256(expected) == keccak256(observed), "Safe caller read parity"
        );
        this.executeCurrentGovernorCall(address(artists), data);
    }

    function executeLifecycleSafe(
        OfficialSafe account,
        uint256[] calldata signingKeys,
        bytes calldata data
    ) external {
        require(msg.sender == address(this), "test only");
        require(
            executeSafe(account, signingKeys, address(artists), 0, data, 0),
            "actual lifecycle Safe call"
        );
    }
}
