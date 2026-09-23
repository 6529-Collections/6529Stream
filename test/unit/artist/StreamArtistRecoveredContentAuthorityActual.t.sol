// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    StreamArtistRecoveredDelegationAuthorityActualTest
} from "./StreamArtistRecoveredDelegationAuthorityActual.t.sol";
import { OfficialSafe } from "../../helpers/OfficialSafeFixture.sol";
import {
    StreamArtistDelegationTypes as D
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistDelegationTypes.sol";
import {
    IStreamArtistDelegation
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistDelegation.sol";
import {
    StreamArtistRecoveredIdentityHydrationTypes as IH
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistRecoveredIdentityHydrationTypes.sol";
import {
    StreamArtistRecoveredIdentityHydrationSource as IdentitySource
} from "../../../smart-contracts/domains/artist/StreamArtistRecoveredIdentityHydrationSource.sol";
import {
    StreamArtistOnboardingTypes as T
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistOnboardingTypes.sol";
import {
    StreamArtistContentTypes as Content
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistContentTypes.sol";
import {
    IStreamArtistContentAuthority
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistContentAuthority.sol";
import {
    IStreamArtistContentRecordsOwner as ContentOwner
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistContentOwner.sol";
import {
    IStreamArtistConsentOwner as Consent
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistConsentOwner.sol";
import {
    IStreamArtistEconomicsAuthority
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistEconomicsAuthority.sol";
import {
    IStreamArtistEconomicsEvidence as Economics
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistEconomicsEvidence.sol";
import {
    StreamArtistAuthorizationTypes as Auth
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistAuthorizationRevocation.sol";
import {
    IStreamArtistIdentityOwner as Identity
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistIdentityOwner.sol";
import {
    IStreamArtistAttributionOwner as Attribution
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistAttributionOwner.sol";
import {
    IStreamArtistAttestationWriter as Attestation
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistAttestationWriter.sol";
import {
    IStreamArtistArchiveV2 as Archive
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistArchiveV2.sol";
import {
    IStreamArtistBindingOwner as Binding
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistBindingOwner.sol";
import {
    IStreamArtistOnboarding
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistOnboarding.sol";
import {
    IStreamArtistOwner as Owner
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistOwner.sol";
import {
    StreamArtistRecoveredHydrationTypes as RH
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistRecoveredHydrationTypes.sol";
import {
    IStreamArtistRecoveredHydrationOwner as RecoveredOwner,
    IStreamArtistRecoveredNativeChronology as NativeClock
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistRecoveredHydration.sol";
import {
    IStreamArtistRecoveredConsentHydration as Recovered
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistRecoveredConsentHydration.sol";
import {
    StreamArtistAuthorityHydrationTypes as AH,
    IStreamArtistAuthorityHydrationOwner as HydrationOwner
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistAuthorityHydration.sol";
import {
    StreamArtistReadinessHydrationTypes as Ready
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistReadinessAuthorityHydration.sol";
import {
    IStreamArtistNativeReceipts as Native,
    StreamArtistHistoryTypes as H
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistHistory.sol";
import {
    StreamArtistRecoveredHydrationPrepared as Prepared
} from "../../../smart-contracts/domains/artist/StreamArtistRecoveredHydrationPrepared.sol";
import {
    StreamArtistRecoveredHydrationCommit as Commit
} from "../../../smart-contracts/domains/artist/StreamArtistRecoveredHydrationCommit.sol";
import {
    StreamArtistRecoveredHydrationGuards as Guards
} from "../../../smart-contracts/domains/artist/StreamArtistRecoveredHydrationGuards.sol";
import {
    StreamArtistRecoveredHydrationOwnerPayload as Payload
} from "../../../smart-contracts/domains/artist/StreamArtistRecoveredHydrationOwnerPayload.sol";

/// @notice Actual mature35, mixed14/15/16/24 and original17/20/21 through Safe operation60.
/// @dev Original21 is content freeze; ARTIST_INTENT is a separate original24 subject profile.
/// Core, scheduled governance and the metadata host remain explicit inherited typed boundaries.
/// Metadata.setContent models an external host state change, never an Artist authorization.
/// Registry, seven owners, Archive, split/royalty resolvers and both Safe signatures are real.
/// No capability, checkpoint, semantic storage or provenance bypass is used. Runtime is pending.
contract StreamArtistRecoveredContentAuthorityActualTest is
    StreamArtistRecoveredDelegationAuthorityActualTest
{
    struct Row {
        uint16 operation;
        bytes32 record;
        Content.Consent content;
        Content.Freeze freeze;
        T.RoyaltyFreeze royalty;
        T.Authorization authorization;
        bytes32 digest;
        RH.Position position;
        RH.Point authorizationPoint;
        bytes32 originalBody;
        bytes32 archivePayload;
        address originalArchive;
        bytes32 archiveId;
        bytes32 grant;
    }

    struct ExtraAuthorization {
        bytes32 record;
        bytes32 digest;
        T.Authorization authorization;
        RH.Point point;
    }
    Row[] private ccRows;
    ExtraAuthorization[] private ccExtra;
    T.EconomicsConsent private ccProspective;
    bytes32 private ccProspectiveRecord;
    Economics.Association private ccProspectiveAssociation;
    Ready.AttestationInput private ccAttestation;
    T.AttestationRecord private ccAttestationRecord;
    bytes32 private ccAttestationAssociation;
    bytes private ccStatement;
    uint256 private ccRevokedNonce;
    bytes32 private ccRevocation;
    RH.Point private ccRevokedPoint;
    OfficialSafe private ccFreezeDelegate;
    uint256[] private ccFreezeKeys;
    bytes32 private ccFreezeGrant;
    D.Record private ccFreezeGrantBefore;
    D.Record private ccFreezeGrantAfter;
    RH.Position private ccFreezeGrantPosition;

    function testRecoveredContentActualDelegated20JoinsAllOriginalUsesAndGuards() external {
        _ccBaseline(true);
        T.SuiteConfiguration memory original = suite;
        Row memory retained = ccRows[5];
        require(
            retained.grant == ccFreezeGrant && ccFreezeGrantAfter.uses == 1,
            "actual delegated20 consumes exactly one source use"
        );
        Successor memory next = _rhCutover();
        bytes32 sourceBefore = _ccSource(original, ccRows.length);
        _ccTransfer(next);
        _ccAssert(next.coordinator.suiteConfiguration(), ccRows.length);
        _rhAdopt(next);
        require(
            IStreamArtistDelegation(address(ingress)).recordDelegation(retained.record)
                    == ccFreezeGrant
                && Consent(suite.owners[6])
                .royaltyFreezeRecord(retained.royalty, artistId, 1)
                .recordHash == retained.record,
            "imported exact scope and historical grant association"
        );
        (bool active, address delegate,,,,, uint64 remaining) =
            ingress.delegationState(ccFreezeGrant);
        require(
            active && delegate == address(ccFreezeDelegate) && remaining == 1,
            "actual current class1 grant retains remaining use"
        );
        bytes32 before_ = _rhDestinationHash(next);
        avm.expectRevert(T.InvalidSignature.selector);
        ingress.authorizeDelegatedRoyaltyFreeze(
            retained.royalty, ccFreezeGrant, retained.authorization
        );
        T.Authorization memory a = retained.authorization;
        a.signature = _ccFreezeSignature(ingress.royaltyFreezeDigest(retained.royalty, a));
        vm.expectRevert(
            abi.encodeWithSelector(
                T.Replay.selector,
                _ccKey(
                    suite,
                    2,
                    "identity_authority.replay.delegated_nonce",
                    keccak256(abi.encode(_ccFreezeLane(), a.nonce))
                )
            )
        );
        ingress.authorizeDelegatedRoyaltyFreeze(retained.royalty, ccFreezeGrant, a);
        a.nonce = 258;
        a.signature = _ccFreezeSignature(ingress.royaltyFreezeDigest(retained.royalty, a));
        vm.expectRevert(
            abi.encodeWithSelector(
                T.Replay.selector,
                _ccKey(
                    suite,
                    6,
                    "consent_finality.replay.freeze_key",
                    keccak256(abi.encode(retained.royalty, artistId, uint64(1)))
                )
            )
        );
        ingress.authorizeDelegatedRoyaltyFreeze(retained.royalty, ccFreezeGrant, a);
        (bool used,) = ingress.delegatedNonceState(artistId, address(ccFreezeDelegate), 258);
        require(
            !used && _rhDestinationHash(next) == before_
                && keccak256(abi.encode(ingress.delegationRecord(ccFreezeGrant)))
                    == keccak256(abi.encode(ccFreezeGrantAfter)),
            "late owner6 replay restores fresh delegate nonce and tentative use increment"
        );
        D.Grant memory replacement = ccFreezeGrantAfter.grant;
        a = _authorization(false);
        a.time = 0;
        a.signature = _signature(ingress.delegationGrantDigest(replacement, a));
        vm.expectRevert(abi.encodeWithSelector(D.ConflictingDelegation.selector, ccFreezeGrant));
        ingress.grantArtistDelegation(replacement, a);
        require(
            _rhDestinationHash(next) == before_,
            "retained active current-grant pointer still blocks replacement"
        );
        royalty.applyArtistRoyaltyFreeze(1, retained.royalty.expectedAssignmentHash);
        require(
            royalty.collectionRoyalty(1).frozen,
            "real resolver accepts current imported delegated20"
        );
        _ccAssert(suite, ccRows.length);
        require(
            _ccSource(original, ccRows.length) == sourceBefore,
            "import and current guard probes preserve original suite"
        );
    }

    function testRecoveredContentMixedOriginalsAndExactHistoricalHeads() external {
        _ccBaseline();
        T.SuiteConfiguration memory original = suite;
        Successor memory next = _rhCutover();
        bytes32 beforeSource = _ccSource(original, ccRows.length);
        _ccTransfer(next);
        _ccAssert(next.coordinator.suiteConfiguration(), ccRows.length);
        require(
            _ccSource(original, ccRows.length) == beforeSource,
            "import leaves sealed source unchanged"
        );
        _rhAdopt(next);
        metadata.configureArtist(address(ingress));
        require(
            ingress.contentConsentEvidence(
                1, ccRows[0].content.familyId, ccRows[0].content.newStateHash
            ) == ccRows[2].record,
            "latest original17 target, not first admission"
        );
        (bool valid, bytes32 head) = ingress.isContentFreezeAuthorized(1, keccak256("SCRIPT"));
        require(valid && head == ccRows[4].record, "last same-lock original21 remains current");
        require(
            ingress.contentFreezeAuthorization(ccRows[1].record).recordHash == ccRows[1].record,
            "stale first21 remains historical"
        );
        require(
            IStreamArtistEconomicsAuthority(address(ingress))
                .isRoyaltyFreezeAuthorized(1, ccRows[5].royalty.expectedAssignmentHash),
            "current binding keeps second original20"
        );
        vm.expectRevert(abi.encodeWithSignature("Error(string)", "unit stale freeze"));
        metadata.applyFreeze(1, ccRows[1].record);
        metadata.applyFreeze(1, head);
        require(
            metadata.contentLocks(1, keccak256("SCRIPT")),
            "typed host consumes exact imported authorization"
        );
        royalty.applyArtistRoyaltyFreeze(1, ccRows[5].royalty.expectedAssignmentHash);
        require(
            royalty.collectionRoyalty(1).frozen,
            "real royalty resolver consumes retained original20"
        );
        require(
            _ccSource(original, ccRows.length) == beforeSource,
            "external host use does not rewrite original owner records"
        );
    }

    function testRecoveredContentRepeatedImportKeepsAAndBClocksAndFreshSafeWrites() external {
        _ccBaseline();
        T.SuiteConfiguration memory original = suite;
        uint256 aCount = ccRows.length;
        Successor memory middle = _rhCutover();
        bytes32 sourceA = _ccSource(original, aCount);
        Commit.Prepared memory first = _ccTransfer(middle);
        _rhAdopt(middle);
        _ccContent(keccak256("B fresh target"), true);
        metadata.setContent(keccak256("B external host state"));
        _ccFreeze();
        T.SuiteConfiguration memory intermediate = suite;
        uint256 bCount = ccRows.length;
        _ccAssert(intermediate, bCount);
        require(_ccSource(original, aCount) == sourceA, "fresh B rows do not enlarge A oracle");
        Successor memory last = _rhCutover();
        bytes32 sourceB = _ccSource(intermediate, bCount);
        Commit.Prepared memory second = _ccTransfer(last);
        require(second.admission.provenance.eras.length == 2, "flat actual A/B origins");
        RH.JournalEntry[] memory a = first.admission.provenance.journals[6];
        RH.JournalEntry[] memory ab = second.admission.provenance.journals[6];
        require(ab.length == a.length + 2, "only genuine B17/21 native suffix");
        for (uint256 i; i < a.length; ++i) {
            require(
                keccak256(abi.encode(a[i])) == keccak256(abi.encode(ab[i])),
                "ultimate A occurrences unchanged"
            );
        }
        require(
            ab[a.length].receipt.operation == 17 && ab[a.length + 1].receipt.operation == 21
                && ab[a.length].position.nativeIndex == 0
                && ab[a.length].position.point.ownerRevision == 2,
            "B local native indices and revisions remain genuine"
        );
        _ccAssert(last.coordinator.suiteConfiguration(), bCount);
        _rhAdopt(last);
        _ccContent(keccak256("C fresh target"), false);
        _ccAssert(suite, ccRows.length);
        require(
            _ccSource(original, aCount) == sourceA && _ccSource(intermediate, bCount) == sourceB,
            "C import/write preserve both ancestors and their catalogs"
        );
    }

    function testRecoveredContentStaleDomainSpentNonceAndRevocationStayDistinct() external {
        _ccBaseline();
        Successor memory next = _rhCutover();
        _ccTransfer(next);
        _rhAdopt(next);
        Row memory old = ccRows[0];
        bytes32 before_ = _rhDestinationHash(next);
        avm.expectRevert(T.InvalidSignature.selector);
        ingress.recordContentConsent(old.content, old.authorization);
        T.Authorization memory a = old.authorization;
        a.signature = _signature(ingress.contentConsentDigest(old.content, a));
        vm.expectRevert(
            abi.encodeWithSelector(
                T.Replay.selector,
                _ccKey(
                    suite,
                    2,
                    "identity_authority.replay.nonce_allocator",
                    keccak256(abi.encode(artistId, a.nonce))
                )
            )
        );
        ingress.recordContentConsent(old.content, a);
        a = T.Authorization(ccRevokedNonce, uint64(block.timestamp + 1 days), "");
        a.signature = _signature(ingress.contentConsentDigest(old.content, a));
        vm.expectRevert(
            abi.encodeWithSelector(
                T.Replay.selector,
                _ccKey(
                    suite,
                    2,
                    "identity_authority.replay.nonce_allocator",
                    keccak256(abi.encode(artistId, ccRevokedNonce))
                )
            )
        );
        ingress.recordContentConsent(old.content, a);
        Row memory freeze = ccRows[5];
        a = _authorization(false);
        a.signature = _signature(ingress.royaltyFreezeDigest(freeze.royalty, a));
        vm.expectRevert(
            abi.encodeWithSelector(
                T.Replay.selector,
                _ccKey(
                    suite,
                    6,
                    "consent_finality.replay.freeze_key",
                    keccak256(abi.encode(freeze.royalty, artistId, uint64(1)))
                )
            )
        );
        ingress.authorizeArtistRoyaltyFreeze(freeze.royalty, a);
        require(
            !Identity(suite.owners[2]).nonceUsed(artistId, a.nonce)
                && _rhDestinationHash(next) == before_,
            "all precise failures roll back authorization and semantic pointers"
        );
        _ccContent(keccak256("A repeated target"), false);
        require(
            ContentOwner(suite.owners[6]).contentConsentAt(old.content, 1).recordHash
                == ccRows[ccRows.length - 1].record,
            "new signed17 for same target allowed with fresh nonce"
        );
        _ccAssert(suite, ccRows.length);
    }

    function testRecoveredContentCompleteWitnessesGateFailuresAndExactArchiveSafeRetry() external {
        _ccBaseline();
        T.SuiteConfiguration memory original = suite;
        Successor memory next = _rhCutover();
        RH.Request memory request = _ccRequest();
        T.RoyaltyFreeze[] memory terms = _ccRoyalties();
        Commit.Prepared memory prepared = _ccPrepared(next, request, terms);
        request.expectedSemanticInventory = Prepared.inventory(prepared);
        bytes32 before_ = _rhDestinationHash(next);
        bytes32 sourceBefore = _ccSource(original, ccRows.length);
        request.expectedCapabilities[6].supportedFeatures &= ~uint64(256);
        avm.expectRevert(RH.InvalidRecoveredHydrationProfile.selector);
        Recovered(address(next.registry))
            .hydrateRecoveredArtistAuthorityWithConsents(request, terms);
        request.expectedCapabilities[6].supportedFeatures |= uint64(256);
        T.RoyaltyFreeze[] memory missing = new T.RoyaltyFreeze[](1);
        missing[0] = terms[0];
        avm.expectRevert(T.UnsupportedProfile.selector);
        Recovered(address(next.registry))
            .hydrateRecoveredArtistAuthorityWithConsents(request, missing);
        (terms[0], terms[1]) = (terms[1], terms[0]);
        avm.expectRevert(RH.InvalidRecoveredHydrationProfile.selector);
        Recovered(address(next.registry))
            .hydrateRecoveredArtistAuthorityWithConsents(request, terms);
        (terms[0], terms[1]) = (terms[1], terms[0]);
        ++request.records.authority.expectedSource[6].ownerState.revision;
        avm.expectRevert(RH.InvalidRecoveredHydrationProvenance.selector);
        Recovered(address(next.registry))
            .hydrateRecoveredArtistAuthorityWithConsents(request, terms);
        --request.records.authority.expectedSource[6].ownerState.revision;
        require(
            _rhDestinationHash(next) == before_,
            "valid complete prepare precedes every exact negative"
        );
        bytes memory call_ =
            abi.encodeCall(Recovered.hydrateRecoveredArtistAuthorityWithConsents, (request, terms));
        uint256 oldBlock = block.number;
        uint256 safeNonce = rotationSafe.nonce();
        vm.roll(uint256(type(uint64).max) + 1);
        vm.expectRevert(
            abi.encodeWithSignature(
                "ArtistArchiveBlockNumberOverflow(uint256)", uint256(type(uint64).max) + 1
            )
        );
        Recovered(address(next.registry))
            .hydrateRecoveredArtistAuthorityWithConsents(request, terms);
        vm.expectRevert(bytes("GS013"));
        this.rhExecuteNewSafe(address(next.registry), call_);
        address owner = next.coordinator.suiteConfiguration().owners[6];
        require(
            _rhDestinationHash(next) == before_ && rotationSafe.nonce() == safeNonce,
            "all seven owners, payload catalogs and Safe nonce revert"
        );
        require(
            ContentOwner(owner).contentConsentRecord(ccRows[0].record).recordHash == 0
                && ContentOwner(owner)
                .contentFreezeAt(1, 1, address(metadata), keccak256("SCRIPT"))
                .recordHash == 0
                && Consent(owner).royaltyFreezeRecord(terms[1], artistId, 1).recordHash == 0,
            "late failure also restores keyed maps and selected heads"
        );
        require(
            _ccSource(original, ccRows.length) == sourceBefore, "failed import never writes source"
        );
        vm.roll(oldBlock);
        require(
            this.rhExecuteNewSafe(address(next.registry), call_),
            "identical Safe request succeeds on exact retry"
        );
        require(rotationSafe.nonce() == safeNonce + 1, "only successful retry consumes Safe nonce");
        _rhImported(next, prepared, HydrationOwner(next.identity).authorityHydrationCommitment());
        _ccAssert(next.coordinator.suiteConfiguration(), ccRows.length);
    }

    function _ccBaseline() private {
        _ccBaseline(false);
    }

    function _ccBaseline(bool delegatedFreeze) private {
        _dcBaseline();
        _ccContent(keccak256("A repeated target"), false); // 0
        _ccFreeze(); // 1, later stale
        _ccContent(keccak256("A repeated target"), false); // 2, same target new original record
        _ccRoyalty(); // 3, historical assignment
        metadata.setContent(keccak256("A external host state"));
        _ccFreeze(); // 4, current same-lock head
        _ccAdvanceRoyalty();
        if (delegatedFreeze) _ccDelegatedRoyalty();
        else _ccRoyalty(); // 5, new actual assignment
        _ccAttest();
        ccRevokedNonce = nextNonce + 300;
        Auth.Revocation memory revoke = Auth.Revocation(artistId, 0, ccRevokedNonce);
        T.Authorization memory a = _authorization(false);
        bytes32 digest = ingress.authorizationRevocationDigest(revoke, a);
        a.signature = _signature(digest);
        ccRevocation = ingress.revokeArtistAuthorization(revoke, a);
        _ccExtraAuth(ccRevocation, digest, a);
        ccRevokedPoint = ccExtra[ccExtra.length - 1].point;
        _rhCandidate(
            2,
            "identity_authority.replay.nonce_allocator",
            keccak256(abi.encode(artistId, ccRevokedNonce))
        );
        _rhCandidate(
            2,
            "identity_authority.replay.target_authorization_revocation",
            keccak256(abi.encode(artistId, bytes32(0), ccRevokedNonce))
        );
    }

    function _ccContent(bytes32 candidate, bool direct) private {
        Row memory item;
        item.operation = 17;
        item.content = _contentProposal(candidate);
        item.authorization = _authorization(false);
        item.digest = ingress.contentConsentDigest(item.content, item.authorization);
        address actor = address(this);
        if (direct) {
            actor = address(rotationSafe);
            require(
                this.rhExecuteNewSafe(
                    address(ingress),
                    abi.encodeCall(
                        IStreamArtistContentAuthority.recordContentConsent,
                        (item.content, item.authorization)
                    )
                ),
                "actual current Safe direct17"
            );
            item.record = ContentOwner(suite.owners[6]).contentConsentAt(item.content, 1).recordHash;
        } else {
            item.authorization.signature = _signature(item.digest);
            item.record = ingress.recordContentConsent(item.content, item.authorization);
        }
        require(
            item.record
                == keccak256(
                    abi.encode(
                        keccak256("6529STREAM_ARTIST_CONTENT_CONSENT_RECORD_V1"),
                        block.chainid,
                        address(ingress),
                        address(metadata),
                        address(core),
                        uint256(1),
                        item.content.familyId,
                        item.content.newStateHash,
                        artistId,
                        address(artist),
                        uint8(1),
                        item.authorization.nonce,
                        uint64(block.timestamp)
                    )
                ),
            "literal original17 hash"
        );
        item.originalBody =
            keccak256(abi.encode(ContentOwner(suite.owners[6]).contentConsentRecord(item.record)));
        _rhCandidate(
            6,
            "consent_finality.replay.content_consent_key",
            keccak256(abi.encode(keccak256(abi.encode(item.content, uint64(1))), item.record))
        );
        _ccRemember(item, actor);
    }

    function _ccFreeze() private {
        Row memory item;
        item.operation = 21;
        item.freeze = _contentFreezeProposal();
        item.authorization = _authorization(false);
        item.digest = ingress.contentFreezeDigest(item.freeze, item.authorization);
        item.authorization.signature = _signature(item.digest);
        item.record = ingress.authorizeArtistContentFreeze(item.freeze, item.authorization);
        require(
            item.record
                == keccak256(
                    abi.encode(
                        keccak256("6529STREAM_ARTIST_CONTENT_FREEZE_RECORD_V1"),
                        block.chainid,
                        address(ingress),
                        address(metadata),
                        address(core),
                        uint256(1),
                        item.freeze.lockClasses,
                        item.freeze.expectedStateHash,
                        artistId,
                        address(artist),
                        uint8(1),
                        item.authorization.nonce,
                        uint64(block.timestamp)
                    )
                ),
            "literal original21 hash"
        );
        item.originalBody =
            keccak256(abi.encode(ContentOwner(suite.owners[6]).contentFreezeRecord(item.record)));
        _rhCandidate(
            6,
            "consent_finality.replay.freeze_key",
            keccak256(abi.encode(keccak256("CONTENT"), uint256(1), uint64(1), item.record))
        );
        _ccRemember(item, address(this));
    }

    function _ccRoyalty() private {
        Row memory item;
        item.operation = 20;
        item.royalty = _freezePayload();
        item.authorization = _authorization(false);
        item.digest = ingress.royaltyFreezeDigest(item.royalty, item.authorization);
        item.authorization.signature = _signature(item.digest);
        item.record = ingress.authorizeArtistRoyaltyFreeze(item.royalty, item.authorization);
        require(
            item.record
                == keccak256(
                    abi.encode(
                        keccak256("6529STREAM_ARTIST_ROYALTY_FREEZE_RECORD_V1"),
                        block.chainid,
                        address(ingress),
                        address(royalty),
                        uint256(1),
                        item.royalty.revenueClass,
                        item.royalty.expectedAssignmentHash,
                        artistId,
                        address(artist),
                        uint8(1),
                        item.authorization.nonce,
                        uint64(block.timestamp)
                    )
                ),
            "literal original20 hash"
        );
        item.originalBody = keccak256(
            abi.encode(Consent(suite.owners[6]).royaltyFreezeRecord(item.royalty, artistId, 1))
        );
        _rhCandidate(
            6,
            "consent_finality.replay.freeze_key",
            keccak256(abi.encode(item.royalty, artistId, uint64(1)))
        );
        _ccRemember(item, address(this));
    }

    function _ccAdvanceRoyalty() private {
        bytes32 profile = royalty.collectionRoyalty(1).profileId;
        T.AssignmentFact memory fact =
            royalty.previewArtistRoyaltyAssignment(1, profile, 600, false);
        ccProspective = T.EconomicsConsent(
            1, address(royalty), fact.revenueClass, fact.scope, fact.scopeId, fact.assignmentHash
        );
        T.Authorization memory a = _authorization(false);
        bytes32 digest = ingress.economicsConsentDigest(ccProspective, a);
        a.signature = _signature(digest);
        ccProspectiveRecord = IStreamArtistEconomicsAuthority(address(ingress))
            .recordProspectiveEconomicsConsent(
                ccProspective, T.FixedEconomicsCandidate(profile, 0, 600, false), a
            );
        _ccExtraAuth(ccProspectiveRecord, digest, a);
        ccProspectiveAssociation =
            Economics(suite.owners[6]).economicsRecordAssociation(ccProspectiveRecord);
        _rhCandidate(6, "consent_finality.replay.consent_key", keccak256(abi.encode(ccProspective)));
        vm.prank(royalty.owner());
        royalty.configureCollectionRoyalty(1, profile, 600);
        require(
            royalty.currentArtistRoyaltyAssignment(1).assignmentHash == fact.assignmentHash,
            "real admitted royalty mutation creates distinct freeze scope"
        );
    }

    function _ccDelegatedRoyalty() private {
        ccFreezeKeys = new uint256[](2);
        ccFreezeKeys[0] = 0xC0F1;
        ccFreezeKeys[1] = 0xC0F2;
        ccFreezeDelegate =
            createOfficialSafe(safeComponents, safeOwnerAddresses(ccFreezeKeys), 2, 503);
        D.Grant memory p = D.Grant(
            artistId,
            address(ccFreezeDelegate),
            1,
            D.ROYALTY_FREEZE,
            uint64(block.timestamp),
            uint64(block.timestamp + 365 days),
            2,
            keccak256("actual ART36 freeze grant")
        );
        T.Authorization memory a = _authorization(false);
        a.time = 0;
        bytes32 digest = ingress.delegationGrantDigest(p, a);
        a.signature = _signature(digest);
        ccFreezeGrant = ingress.grantArtistDelegation(p, a);
        require(
            ccFreezeGrant == _grantRecord(p, a.nonce),
            "literal original26 hash through original helper"
        );
        _ccExtraAuth(ccFreezeGrant, digest, a);
        _rhCandidate(2, "identity_authority.replay.delegation_key", ccFreezeGrant);
        ccFreezeGrantBefore = D.Record(p, address(artist), a.nonce, 0, false, bytes32(0));
        require(
            keccak256(abi.encode(ingress.delegationRecord(ccFreezeGrant)))
                == keccak256(abi.encode(ccFreezeGrantBefore)),
            "real rotated Safe signs exact original26"
        );
        uint256 index = Native(suite.owners[2]).artistNativeReceiptCount() - 1;
        H.Receipt memory row = Native(suite.owners[2]).artistNativeReceiptAt(index);
        require(
            row.operation == 26 && row.recordHash == ccFreezeGrant && row.artistId == artistId
                && row.collectionId == 0,
            "genuine grant occurrence"
        );
        ccFreezeGrantPosition = RH.Position(
            RH.Point(
                RH.originHash(_ccOrigin(suite)),
                2,
                NativeClock(suite.owners[2]).artistNativeReceiptRevisionAt(index)
            ),
            index
        );
        Row memory item;
        item.operation = 20;
        item.grant = ccFreezeGrant;
        item.royalty = _freezePayload();
        item.authorization = T.Authorization(257, uint64(block.timestamp + 1 days), "");
        item.digest = ingress.royaltyFreezeDigest(item.royalty, item.authorization);
        item.authorization.signature = _ccFreezeSignature(item.digest);
        item.record =
            ingress.authorizeDelegatedRoyaltyFreeze(item.royalty, item.grant, item.authorization);
        require(
            item.record
                == keccak256(
                    abi.encode(
                        keccak256("6529STREAM_ARTIST_ROYALTY_FREEZE_RECORD_V1"),
                        block.chainid,
                        address(ingress),
                        address(royalty),
                        uint256(1),
                        item.royalty.revenueClass,
                        item.royalty.expectedAssignmentHash,
                        artistId,
                        address(ccFreezeDelegate),
                        uint8(2),
                        item.authorization.nonce,
                        uint64(block.timestamp)
                    )
                ),
            "literal unchanged class2 original20 hash"
        );
        ccFreezeGrantAfter = D.Record(p, address(artist), a.nonce, 1, false, bytes32(0));
        require(
            keccak256(abi.encode(ingress.delegationRecord(ccFreezeGrant)))
                == keccak256(abi.encode(ccFreezeGrantAfter)),
            "one real delegated20 use with all other original fields retained"
        );
        item.originalBody = keccak256(
            abi.encode(Consent(suite.owners[6]).royaltyFreezeRecord(item.royalty, artistId, 1))
        );
        _rhCandidate(
            6,
            "consent_finality.replay.freeze_key",
            keccak256(abi.encode(item.royalty, artistId, uint64(1)))
        );
        _ccRemember(item, address(this));
    }

    function _ccFreezeSignature(bytes32 digest) private returns (bytes memory) {
        return safeThresholdSignature(
            ccFreezeKeys, safeMessageDigest(ccFreezeDelegate, abi.encode(digest))
        );
    }

    function _ccFreezeLane() private view returns (bytes32) {
        return keccak256(
            abi.encode(
                keccak256("6529STREAM_ARTIST_DELEGATE_NONCE_LANE_V1"),
                artistId,
                address(ccFreezeDelegate)
            )
        );
    }

    function _ccAttest() private {
        bytes32 assignment =
            primary.resolvePrimaryAssignment(1, 0, keccak256("PRIMARY_SALE")).assignmentHash;
        ccStatement = bytes("verified primary assignment beside content history");
        T.Attestation memory p = T.Attestation(
            1,
            6,
            bytes32(uint256(uint160(address(primary)))),
            assignment,
            keccak256("ART36 original subject"),
            keccak256(ccStatement),
            "urn:art36:primary"
        );
        T.Authorization memory a = _authorization(true);
        bytes32 digest = ingress.attestationDigest(p, a);
        a.signature = _signature(digest);
        bytes32 record = ingress.recordArtistAttestation(p, a, ccStatement);
        require(
            record
                == keccak256(
                    abi.encode(
                        keccak256("6529STREAM_ARTIST_ATTESTATION_RECORD_V1"),
                        block.chainid,
                        address(ingress),
                        address(core),
                        p.collectionId,
                        p.subjectKind,
                        p.subjectId,
                        p.subjectStateHash,
                        p.schemaId,
                        p.statementHash,
                        keccak256(bytes(p.statementURI)),
                        artistId,
                        address(artist),
                        uint8(1),
                        a.nonce,
                        a.time
                    )
                ),
            "unchanged literal original24 hash"
        );
        _ccExtraAuth(record, digest, a);
        _rhCandidate(2, "identity_authority.replay.attestation_key", keccak256(abi.encode(record)));
        ccAttestation = Ready.AttestationInput(p, a.nonce);
        ccAttestationRecord = Attribution(suite.owners[4]).attestationRecord(record);
        ccAttestationAssociation = keccak256(abi.encode(ingress.attestationAssociation(record)));
    }

    function _ccRemember(Row memory item, address actor) private {
        if (item.grant == 0) {
            _rhAuthorization(item.digest, item.authorization.nonce);
        } else {
            _rhCandidate(
                2,
                "identity_authority.replay.authorization_consumed_digest",
                keccak256(abi.encode(artistId, item.digest))
            );
            _rhCandidate(
                2,
                "identity_authority.replay.delegated_nonce",
                keccak256(abi.encode(_ccFreezeLane(), item.authorization.nonce))
            );
        }
        uint256 index = Native(suite.owners[6]).artistNativeReceiptCount() - 1;
        H.Receipt memory receipt = Native(suite.owners[6]).artistNativeReceiptAt(index);
        require(
            receipt.operation == item.operation && receipt.recordHash == item.record
                && receipt.artistId == artistId && receipt.collectionId == 1,
            "real original native occurrence"
        );
        bytes32 env = RH.originHash(_ccOrigin(suite));
        item.position = RH.Position(
            RH.Point(env, 6, NativeClock(suite.owners[6]).artistNativeReceiptRevisionAt(index)),
            index
        );
        item.authorizationPoint =
            RH.Point(env, 2, Owner(suite.owners[2]).ownerStateSnapshotV2().revision);
        bytes memory payload = _operationPayload(item.operation, actor, item.record);
        require(payload.length != 0, "actual original Archive payload");
        bytes32 fullPayloadHash = keccak256(payload);
        if (item.grant != 0) {
            bytes32 recordedGrant;
            D.Record memory prior;
            (payload, recordedGrant, prior) = abi.decode(payload, (bytes, bytes32, D.Record));
            require(
                recordedGrant == item.grant
                    && keccak256(abi.encode(prior)) == keccak256(abi.encode(ccFreezeGrantBefore)),
                "original delegated20 wrapper preserves exact pre-use grant"
            );
        }
        T.Binding memory originalBinding;
        T.Authorization memory archivedAuthorization;
        T.SignerApproval memory signerProof;
        if (item.operation == 17) {
            Content.Consent memory terms;
            (originalBinding, terms, archivedAuthorization, signerProof,) = abi.decode(
                payload, (T.Binding, Content.Consent, T.Authorization, T.SignerApproval, bytes32)
            );
            require(
                keccak256(abi.encode(terms)) == keccak256(abi.encode(item.content)),
                "original Archive17 full terms"
            );
        } else if (item.operation == 21) {
            Content.Freeze memory terms;
            (originalBinding, terms, archivedAuthorization, signerProof) =
                abi.decode(payload, (T.Binding, Content.Freeze, T.Authorization, T.SignerApproval));
            require(
                keccak256(abi.encode(terms)) == keccak256(abi.encode(item.freeze)),
                "original Archive21 full ordered locks and state"
            );
        } else {
            T.RoyaltyFreeze memory terms;
            (originalBinding, terms, archivedAuthorization, signerProof) = abi.decode(
                payload, (T.Binding, T.RoyaltyFreeze, T.Authorization, T.SignerApproval)
            );
            require(
                keccak256(abi.encode(terms)) == keccak256(abi.encode(item.royalty)),
                "original Archive20 exact resolver and assignment"
            );
        }
        require(
            originalBinding.artistId == artistId && originalBinding.generation == 1
                && keccak256(abi.encode(archivedAuthorization))
                    == keccak256(abi.encode(item.authorization))
                && signerProof.signer
                    == (item.grant == 0 ? address(artist) : address(ccFreezeDelegate))
                && signerProof.digest == item.digest
                && signerProof.direct == (actor == signerProof.signer),
            "original binding and real Safe signer proof"
        );
        item.archivePayload = fullPayloadHash;
        item.originalArchive = address(archive);
        item.archiveId = keccak256(
            abi.encode(
                keccak256("6529STREAM_ARTIST_ONBOARDING_OPERATION_EVIDENCE_V1"),
                block.chainid,
                address(ingress),
                address(coordinator),
                item.operation,
                actor,
                item.record
            )
        );
        ccRows.push(item);
    }

    function _ccExtraAuth(bytes32 record, bytes32 digest, T.Authorization memory a) private {
        _rhAuthorization(digest, a.nonce);
        ccExtra.push(
            ExtraAuthorization(
                record,
                digest,
                a,
                RH.Point(
                    RH.originHash(_ccOrigin(suite)),
                    2,
                    Owner(suite.owners[2]).ownerStateSnapshotV2().revision
                )
            )
        );
    }

    function _ccRequest() private view returns (RH.Request memory p) {
        p = _dcRequest();
        T.EconomicsConsent[] memory old = p.records.witnesses[0].economics;
        p.records.witnesses[0].economics = new T.EconomicsConsent[](old.length + 1);
        for (uint256 i; i < old.length; ++i) {
            p.records.witnesses[0].economics[i] = old[i];
        }
        p.records.witnesses[0].economics[old.length] = ccProspective;
        p.records.witnesses[0].attestations = new Ready.AttestationInput[](1);
        p.records.witnesses[0].attestations[0] = ccAttestation;
    }

    function _ccRoyalties() private view returns (T.RoyaltyFreeze[] memory p) {
        uint256 count;
        for (uint256 i; i < ccRows.length; ++i) {
            if (ccRows[i].operation == 20) ++count;
        }
        p = new T.RoyaltyFreeze[](count);
        count = 0;
        for (uint256 i; i < ccRows.length; ++i) {
            if (ccRows[i].operation == 20) p[count++] = ccRows[i].royalty;
        }
    }

    function _ccPrepared(Successor memory next, RH.Request memory p, T.RoyaltyFreeze[] memory terms)
        private
        view
        returns (Commit.Prepared memory prepared)
    {
        prepared = Prepared.prepare(next.coordinator.suiteConfiguration(), p, terms);
        for (uint8 i; i < 7; ++i) {
            (RH.ExportHeader memory h,) = Payload.decode(prepared.data[i].typedState, i);
            uint256 expected = RH.CLASS_ONE | RH.DIRECT_ECONOMICS | RH.DELEGATED_CONSENT
                | RH.ATTESTATIONS | RH.CONTENT_CONSENTS;
            if (prepared.admission.provenance.eras.length > 1) expected |= RH.REPEATED_IMPORT;
            require(
                h.requiredFeatures == expected,
                "features derive from genuine living/mixed/attestation/content source"
            );
            require(
                (p.expectedCapabilities[i].supportedFeatures & 511) == 511,
                "production owners explicitly advertise complete content graph"
            );
        }
        if (ccFreezeGrant != 0) {
            (, Payload.Payload memory encoded) = Payload.decode(prepared.data[2].typedState, 2);
            IH.Bundle memory identity =
                IdentitySource.decode(encoded.semanticState, encoded.provenance);
            uint256 found;
            for (uint256 i; i < identity.delegations.length; ++i) {
                IH.DelegationRow memory row = identity.delegations[i];
                if (row.recordHash != ccFreezeGrant) continue;
                require(
                    row.current == ccFreezeGrant && row.epoch == identity.heads.delegationEpoch
                        && keccak256(abi.encode(row.record))
                            == keccak256(abi.encode(ccFreezeGrantAfter))
                        && keccak256(abi.encode(row.position))
                            == keccak256(abi.encode(ccFreezeGrantPosition)),
                    "actual prepared grant current head, epoch, original record and occurrence"
                );
                ++found;
            }
            require(found == 1, "one complete original freeze grant in shared Identity inventory");
        }
    }

    function _ccTransfer(Successor memory next) private returns (Commit.Prepared memory prepared) {
        RH.Request memory request = _ccRequest();
        T.RoyaltyFreeze[] memory terms = _ccRoyalties();
        prepared = _ccPrepared(next, request, terms);
        request.expectedSemanticInventory = Prepared.inventory(prepared);
        require(
            this.rhExecuteNewSafe(
                address(next.registry),
                abi.encodeCall(
                    Recovered.hydrateRecoveredArtistAuthorityWithConsents, (request, terms)
                )
            ),
            "actual Safe operation60 with exact royalty witness order"
        );
        _rhImported(next, prepared, HydrationOwner(next.identity).authorityHydrationCommitment());
    }

    function _ccAssert(T.SuiteConfiguration memory target, uint256 count) private view {
        _dcAssert(target);
        for (uint256 i; i < count; ++i) {
            Row memory r = ccRows[i];
            require(_ccBody(target, r) == r.originalBody, "entire original body preserved");
            bytes memory archived;
            (,,,,,,, archived) = abi.decode(
                Archive(r.originalArchive).artistEvidenceBytesV2(r.archiveId, 1),
                (uint16, bytes32, uint16, address, bytes32, T.Snapshot[7], T.Snapshot[7], bytes)
            );
            require(
                keccak256(archived) == r.archivePayload,
                "original Archive evidence remains exact at original origin"
            );
            if (r.grant == 0) {
                _ccAuthorization(target, r.record, r.digest, r.authorization, r.authorizationPoint);
            } else {
                require(
                    keccak256(Identity(target.owners[2]).signatureBundle(r.record))
                        == keccak256(r.authorization.signature),
                    "original delegated Safe signature preserved"
                );
                (bool used, uint256 hint) = IStreamArtistDelegation(target.registry)
                    .delegatedNonceState(artistId, address(ccFreezeDelegate), r.authorization.nonce);
                require(
                    used && hint == 0
                        && IStreamArtistDelegation(target.registry).recordDelegation(r.record)
                            == r.grant,
                    "sparse original delegated nonce and per-record grant association"
                );
                _ccCell(
                    target,
                    2,
                    "identity_authority.replay.authorization_consumed_digest",
                    keccak256(abi.encode(artistId, r.digest)),
                    r.digest,
                    r.authorizationPoint
                );
                _ccCell(
                    target,
                    2,
                    "identity_authority.replay.delegated_nonce",
                    keccak256(abi.encode(_ccFreezeLane(), r.authorization.nonce)),
                    r.digest,
                    r.authorizationPoint
                );
            }
            string memory surface = r.operation == 17
                ? "consent_finality.replay.content_consent_key"
                : "consent_finality.replay.freeze_key";
            bytes32 scope = r.operation == 17
                ? keccak256(abi.encode(keccak256(abi.encode(r.content, uint64(1))), r.record))
                : r.operation == 20
                    ? keccak256(abi.encode(r.royalty, artistId, uint64(1)))
                    : keccak256(abi.encode(keccak256("CONTENT"), uint256(1), uint64(1), r.record));
            _ccCell(target, 6, surface, scope, r.record, r.position.point);
            _ccOccurrence(target, r);
            if (r.operation == 17) {
                bytes32 selected = r.record;
                for (uint256 j = i + 1; j < count; ++j) {
                    if (
                        ccRows[j].operation == 17
                            && keccak256(abi.encode(ccRows[j].content))
                                == keccak256(abi.encode(r.content))
                    ) selected = ccRows[j].record;
                }
                require(
                    ContentOwner(target.owners[6]).contentConsentAt(r.content, 1).recordHash
                        == selected,
                    "exact latest target pointer across origins"
                );
            }
            if (r.operation == 21) {
                for (uint256 k; k < r.freeze.lockClasses.length; ++k) {
                    bytes32 selected = r.record;
                    for (uint256 j = i + 1; j < count; ++j) {
                        if (ccRows[j].operation == 21) {
                            for (uint256 q; q < ccRows[j].freeze.lockClasses.length; ++q) {
                                if (ccRows[j].freeze.lockClasses[q] == r.freeze.lockClasses[k]) {
                                    selected = ccRows[j].record;
                                }
                            }
                        }
                    }
                    require(
                        ContentOwner(target.owners[6])
                        .contentFreezeAt(1, 1, address(metadata), r.freeze.lockClasses[k])
                        .recordHash == selected,
                        "exact selected lock head"
                    );
                }
            }
        }
        for (uint256 i; i < ccExtra.length; ++i) {
            _ccAuthorization(
                target,
                ccExtra[i].record,
                ccExtra[i].digest,
                ccExtra[i].authorization,
                ccExtra[i].point
            );
        }
        _ccCell(
            target,
            2,
            "identity_authority.replay.nonce_allocator",
            keccak256(abi.encode(artistId, ccRevokedNonce)),
            ccRevocation,
            ccRevokedPoint
        );
        _ccCell(
            target,
            2,
            "identity_authority.replay.target_authorization_revocation",
            keccak256(abi.encode(artistId, bytes32(0), ccRevokedNonce)),
            ccRevocation,
            ccRevokedPoint
        );
        require(
            Consent(target.owners[6]).economicsRecord(ccProspective) == ccProspectiveRecord
                && keccak256(
                    abi.encode(
                        Economics(target.owners[6]).economicsRecordAssociation(ccProspectiveRecord)
                    )
                ) == keccak256(abi.encode(ccProspectiveAssociation)),
            "original payout-associated approval unchanged"
        );
        require(
            keccak256(
                    abi.encode(
                        Attribution(target.owners[4])
                            .attestationRecord(ccAttestationRecord.recordHash)
                    )
                ) == keccak256(abi.encode(ccAttestationRecord))
                && keccak256(
                    Attribution(target.owners[4]).statementBytes(ccAttestation.terms.statementHash)
                ) == keccak256(ccStatement),
            "original verified24 and exact statement retained beside owner6"
        );
        require(
            keccak256(
                abi.encode(
                    Attestation(target.registry)
                        .attestationAssociation(ccAttestationRecord.recordHash)
                )
            ) == ccAttestationAssociation,
            "original24 fact owner/codehash, binding and class association remain exact"
        );
        if (ccFreezeGrant != 0) {
            require(
                keccak256(
                    abi.encode(
                        IStreamArtistDelegation(target.registry).delegationRecord(ccFreezeGrant)
                    )
                ) == keccak256(abi.encode(ccFreezeGrantAfter)),
                "complete imported grant final tuple including exact use count"
            );
            _ccCell(
                target,
                2,
                "identity_authority.replay.delegation_key",
                ccFreezeGrant,
                ccFreezeGrant,
                ccFreezeGrantPosition.point
            );
            Row memory grantRow;
            grantRow.operation = 26;
            grantRow.record = ccFreezeGrant;
            grantRow.position = ccFreezeGrantPosition;
            _ccOccurrence(target, grantRow);
        }
    }

    function _ccAuthorization(
        T.SuiteConfiguration memory target,
        bytes32 record,
        bytes32 digest,
        T.Authorization memory a,
        RH.Point memory point
    ) private view {
        require(
            keccak256(Identity(target.owners[2]).signatureBundle(record)) == keccak256(a.signature)
                && Identity(target.owners[2]).nonceUsed(artistId, a.nonce),
            "full original signature and spent nonce"
        );
        _ccCell(
            target,
            2,
            "identity_authority.replay.authorization_consumed_digest",
            keccak256(abi.encode(artistId, digest)),
            digest,
            point
        );
        _ccCell(
            target,
            2,
            "identity_authority.replay.nonce_allocator",
            keccak256(abi.encode(artistId, a.nonce)),
            digest,
            point
        );
    }

    function _ccCell(
        T.SuiteConfiguration memory target,
        uint8 owner,
        string memory surface,
        bytes32 scope,
        bytes32 commitment,
        RH.Point memory point
    ) private view {
        bytes32 key = _ccKey(target, owner, surface, scope);
        T.ReplayCell memory cell = Owner(target.owners[owner]).replayCell(key);
        require(
            cell.kind == 1 && cell.status == 2 && cell.commitment == commitment
                && cell.touchedRevision == point.ownerRevision
                && keccak256(
                    abi.encode(
                        RecoveredOwner(target.owners[owner]).recoveredHydrationReplayPoint(key)
                    )
                ) == keccak256(abi.encode(point)),
            "original replay value and separately authenticated ultimate clock"
        );
    }

    function _ccOccurrence(T.SuiteConfiguration memory target, Row memory r) private view {
        uint8 owner = r.position.point.ownerIndex;
        (RH.OwnerProvenance memory prefix,,) =
            RecoveredOwner(target.owners[owner]).recoveredHydrationImportedPrefix();
        uint256 found;
        for (uint256 i; i < prefix.journal.length; ++i) {
            if (prefix.journal[i].receipt.recordHash == r.record) {
                require(
                    prefix.journal[i].receipt.operation == r.operation
                        && keccak256(abi.encode(prefix.journal[i].position))
                            == keccak256(abi.encode(r.position)),
                    "imported occurrence preserves physical source coordinate"
                );
                ++found;
            }
        }
        for (uint256 i; i < Native(target.owners[owner]).artistNativeReceiptCount(); ++i) {
            if (Native(target.owners[owner]).artistNativeReceiptAt(i).recordHash == r.record) {
                require(
                    Native(target.owners[owner]).artistNativeReceiptAt(i).operation == r.operation
                        && i == r.position.nativeIndex
                        && NativeClock(target.owners[owner]).artistNativeReceiptRevisionAt(i)
                            == r.position.point.ownerRevision
                        && RH.originHash(_ccOrigin(target)) == r.position.point.environmentHash,
                    "genuine local current occurrence"
                );
                ++found;
            }
        }
        require(found == 1, "exactly one original occurrence");
    }

    function _ccBody(T.SuiteConfiguration memory target, Row memory r)
        private
        view
        returns (bytes32)
    {
        if (r.operation == 17) {
            return
                keccak256(abi.encode(ContentOwner(target.owners[6]).contentConsentRecord(r.record)));
        }
        if (r.operation == 21) {
            return
                keccak256(abi.encode(ContentOwner(target.owners[6]).contentFreezeRecord(r.record)));
        }
        return keccak256(
            abi.encode(Consent(target.owners[6]).royaltyFreezeRecord(r.royalty, artistId, 1))
        );
    }

    // Explicit saved count: later B/C additions never add absent-row reads to ancestor A.
    function _ccSource(T.SuiteConfiguration memory target, uint256 count)
        private
        view
        returns (bytes32 value)
    {
        value = _dcSource(target, _dcScope());
        for (uint256 i; i < count; ++i) {
            Row memory r = ccRows[i];
            value = keccak256(
                abi.encode(
                    value,
                    _ccBody(target, r),
                    Identity(target.owners[2]).signatureBundle(r.record),
                    ContentOwner(target.owners[6]).contentConsentAt(r.content, 1),
                    ContentOwner(target.owners[6])
                        .contentFreezeAt(1, 1, address(metadata), keccak256("SCRIPT"))
                )
            );
        }
        for (uint256 i; i < ccExtra.length; ++i) {
            value = keccak256(
                abi.encode(value, Identity(target.owners[2]).signatureBundle(ccExtra[i].record))
            );
        }
        value = keccak256(
            abi.encode(
                value,
                Consent(target.owners[6]).economicsRecord(ccProspective),
                Economics(target.owners[6]).economicsRecordAssociation(ccProspectiveRecord),
                Attribution(target.owners[4]).attestationRecord(ccAttestationRecord.recordHash)
            )
        );
        if (ccFreezeGrant != 0) {
            value = keccak256(
                abi.encode(
                    value,
                    IStreamArtistDelegation(target.registry).delegationRecord(ccFreezeGrant),
                    IStreamArtistDelegation(target.registry).recordDelegation(ccRows[5].record)
                )
            );
        }
    }

    function _ccKey(
        T.SuiteConfiguration memory target,
        uint8 owner,
        string memory surface,
        bytes32 scope
    ) private view returns (bytes32) {
        return Guards.replayKey(
            _ccOrigin(target), owner, AH.Origin(keccak256(bytes(surface)), scope)
        );
    }

    function _ccOrigin(T.SuiteConfiguration memory target)
        private
        view
        returns (RH.OriginEnvironment memory e)
    {
        e.chainId = block.chainid;
        e.registry = target.registry;
        e.coordinator = Owner(target.owners[2]).operationCoordinator();
        e.archive = target.archive;
        e.owners = target.owners;
        for (uint8 i; i < 7; ++i) {
            e.ownerCodeHashes[i] = target.owners[i].codehash;
        }
        e.core = target.core;
        e.manager = target.mintManager;
        e.suiteConfigurationHash = keccak256(abi.encode(target));
    }
}
