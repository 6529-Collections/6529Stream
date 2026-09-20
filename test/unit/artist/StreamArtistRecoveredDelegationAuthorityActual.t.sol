// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    StreamArtistRecoveredAuthorityActualTest
} from "./StreamArtistRecoveredAuthorityActual.t.sol";
import {
    StreamArtistOnboardingTypes as T
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistOnboardingTypes.sol";
import {
    StreamArtistDelegationTypes as D
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistDelegationTypes.sol";
import {
    StreamArtistSaleTypes as Sale
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistSaleTypes.sol";
import {
    StreamArtistRecoveredHydrationTypes as RH
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistRecoveredHydrationTypes.sol";
import {
    StreamArtistRecoveredIdentityHydrationTypes as IH
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistRecoveredIdentityHydrationTypes.sol";
import {
    StreamArtistAuthorityHydrationTypes as AH,
    IStreamArtistAuthorityHydrationOwner as HydrationOwner
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistAuthorityHydration.sol";
import {
    StreamArtistMultipleRecordsTypes as MR
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistMultipleRecordsHydration.sol";
import {
    StreamArtistReadinessHydrationTypes as Ready
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistReadinessAuthorityHydration.sol";
import {
    IStreamArtistRecoveredHydration as Recovered,
    IStreamArtistRecoveredHydrationOwner as RecoveredOwner,
    IStreamArtistRecoveredNativeChronology as NativeClock
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistRecoveredHydration.sol";
import {
    IStreamArtistDelegation
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistDelegation.sol";
import {
    IStreamArtistDelegatedConsent
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistDelegatedConsent.sol";
import {
    IStreamArtistDelegatedConsentOwner as Delegated
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistDelegatedConsentOwner.sol";
import {
    IStreamArtistSaleConsentOwner as Sales
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistSaleOwner.sol";
import {
    IStreamArtistSaleFacts
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistSaleFacts.sol";
import {
    IStreamArtistEconomicsEvidence as Economics
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistEconomicsEvidence.sol";
import {
    IStreamArtistConsentOwner as Consent
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistConsentOwner.sol";
import {
    IStreamArtistIdentityOwner as Identity
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistIdentityOwner.sol";
import {
    IStreamArtistBindingOwner as Binding
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistBindingOwner.sol";
import {
    IStreamArtistOwner as Owner
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistOwner.sol";
import {
    IStreamArtistAuthorityCheckpoint as CP
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistAuthorityCheckpoint.sol";
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
import {
    StreamArtistRecoveredPayloadHydration as Publications
} from "../../../smart-contracts/domains/artist/StreamArtistRecoveredPayloadHydration.sol";
import {
    StreamArtistRecoveredIdentityHydrationSource as IdentitySource
} from "../../../smart-contracts/domains/artist/StreamArtistRecoveredIdentityHydrationSource.sol";

interface RecoveredDelegationEpochReader {
    function delegationEpochState(bytes32 grant) external view returns (bool, uint64, uint64);
}

/// @dev Immutable sale-facts boundary registered in the actual ModuleRegistry. No sale/payment claim.
contract RecoveredDelegationSaleFacts {
    address public immutable core;
    bytes32 public constant ID = keccak256("recovered delegated sale");
    bytes32 public constant CONFIG = keccak256("recovered delegated immutable sale terms");

    constructor(address core_) {
        core = core_;
    }

    function streamModuleType() external pure returns (bytes32) {
        return keccak256("RECOVERED_DELEGATION_SALE_FACTS");
    }

    function streamModuleInterfaceId() external pure returns (bytes4) {
        return type(IStreamArtistSaleFacts).interfaceId;
    }

    function supportsInterface(bytes4 id) external pure returns (bool) {
        return id == type(IStreamArtistSaleFacts).interfaceId || id == 0x01ffc9a7;
    }

    function saleConsentFacts(bytes32 id) external pure returns (uint256, bytes32) {
        require(id == ID);
        return (1, CONFIG);
    }
}

/// @notice Actual original35/26/27/14/15/16, seven-owner operation60 and threshold Safe continuation.
/// @dev Core and scheduled governance are the inherited explicit typed unit boundaries. The sale
/// facts contract is immutable and admitted by real ModuleRegistry storage. No capability, source
/// checkpoint, semantic record, import apply, or Archive response is mocked. Fresh delegation
/// remains class1-only; the pre35 case proves historical epoch invalidation without changing policy.
contract StreamArtistRecoveredDelegationAuthorityActualTest is
    StreamArtistRecoveredAuthorityActualTest
{
    struct InventoryScope {
        uint256 grants;
        uint256 authorizations;
        uint256 consents;
    }

    struct Grant {
        bytes32 hash;
        D.Record expected;
        uint64 epoch;
        RH.Position position;
        RH.Position revokedAt;
    }

    struct Authorization {
        bytes32 record;
        bytes32 digest;
        uint256 nonce;
        address delegate;
        bytes signature;
        RH.Point point;
    }

    struct ConsentRecord {
        uint16 operation;
        bytes32 hash;
        bytes32 grant;
        T.PolicyConsent policy;
        T.EconomicsConsent economics;
        Economics.Association association;
        Sale.Record sale;
        RH.Position position;
    }
    Grant[] private dcGrants;
    Authorization[] private dcAuthorizations;
    ConsentRecord[] private dcConsents;
    RecoveredDelegationSaleFacts private dcSale;
    uint64 private dcEpoch;

    constructor() {
        actualSaleRegistryFixture = true;
    }

    function _initialBindingProposal() internal view override returns (T.BindingProposal memory p) {
        p = super._initialBindingProposal();
        p.consentMode = 2;
        p.saleConsentScope = 1;
    }

    function testRecoveredDelegationMixedOriginalsAndSpentLanesRemainExactAfterImport() external {
        _dcBaseline();
        T.SuiteConfiguration memory original = suite;
        InventoryScope memory originalScope = _dcScope();
        Successor memory next = _rhCutover();
        bytes32 sourceBefore = _dcSource(original);
        _dcTransfer(next);
        _dcAssert(next.coordinator.suiteConfiguration());
        require(
            _dcSource(original) == sourceBefore, "import never mutates original grants or consents"
        );
        _rhAdopt(next);
        _dcUnavailable(dcGrants[0].hash, 40); // Exhausted original grant.
        _dcUnavailable(dcGrants[1].hash, 41); // Explicitly revoked replacement.
        T.PolicyConsent memory p = _dcPolicyTerms(100);
        T.Authorization memory a = T.Authorization(257, type(uint64).max, "");
        a.signature = _delegateSignature(ingress.policyConsentDigest(p, a));
        bytes32 before_ = _rhDestinationHash(next);
        bytes32 key = _dcKey(
            suite,
            2,
            "identity_authority.replay.delegated_nonce",
            keccak256(abi.encode(_dcLane(address(delegateSafe)), uint256(257)))
        );
        vm.expectRevert(abi.encodeWithSelector(T.Replay.selector, key));
        IStreamArtistDelegatedConsent(address(ingress))
            .recordDelegatedPolicyConsent(p, dcGrants[2].hash, a);
        require(
            _rhDestinationHash(next) == before_,
            "replacement cannot reset sparse spent delegate nonce"
        );
        _dcPolicy(dcGrants[2].hash, 2, 101, true);
        _dcAssert(suite);
        vm.prank(address(dcSale));
        ingress.requireSaleConsent(1, dcSale.ID(), dcSale.CONFIG());
        require(
            _dcSource(original, originalScope) == sourceBefore, "fresh B use leaves A unchanged"
        );
    }

    function testRecoveredDelegationFreshBGrantAndConsentThenCUseCurrentDomainAndUltimateClocks()
        external
    {
        _dcBaseline();
        T.SuiteConfiguration memory original = suite;
        InventoryScope memory originalScope = _dcScope();
        Successor memory middle = _rhCutover();
        bytes32 sourceBefore = _dcSource(original);
        Commit.Prepared memory first = _dcTransfer(middle);
        _rhAdopt(middle);
        _dcRevoke(dcGrants[2].hash);
        bytes32 replacement = _dcGrant(
            _delegation(1, 1030, uint64(block.timestamp), uint64(block.timestamp + 365 days), 0)
        );
        _dcPolicy(replacement, 2, 200, true);
        T.SuiteConfiguration memory intermediate = suite;
        require(
            Native(suite.owners[2]).artistNativeReceiptCount() == 2
                && Native(suite.owners[6]).artistNativeReceiptCount() == 1,
            "B original27/26 and original14 native suffixes, no synthetic Identity14"
        );
        Successor memory last = _rhCutover();
        InventoryScope memory middleScope = _dcScope();
        bytes32 middleBefore = _dcSource(intermediate);
        Commit.Prepared memory second = _dcTransfer(last);
        require(second.admission.provenance.eras.length == 2, "two flattened original environments");
        for (uint8 owner; owner < 7; ++owner) {
            RH.JournalEntry[] memory prior = first.admission.provenance.journals[owner];
            RH.JournalEntry[] memory later = second.admission.provenance.journals[owner];
            for (uint256 i; i < prior.length; ++i) {
                require(
                    keccak256(abi.encode(prior[i])) == keccak256(abi.encode(later[i])),
                    "A occurrences and admission revisions remain A"
                );
            }
        }
        ConsentRecord memory bConsent = dcConsents[dcConsents.length - 1];
        require(
            bConsent.position.point.environmentHash
                    == second.admission.provenance.eras[1].originHash
                && bConsent.position.nativeIndex == 0 && bConsent.position.point.ownerRevision == 2,
            "B Consent14 uses its own actual local clock"
        );
        require(
            _dcSource(original, originalScope) == sourceBefore
                && _dcSource(intermediate, middleScope) == middleBefore,
            "second import preserves both source suites"
        );
        _dcAssert(last.coordinator.suiteConfiguration());
        _rhAdopt(last);
        T.PolicyConsent memory p = _dcPolicyTerms(201);
        T.Authorization memory a = T.Authorization(3, type(uint64).max, "");
        a.signature = _delegateSignature(middle.registry.policyConsentDigest(p, a));
        bytes32 before_ = _rhDestinationHash(last);
        avm.expectRevert(T.InvalidSignature.selector);
        IStreamArtistDelegatedConsent(address(ingress))
            .recordDelegatedPolicyConsent(p, replacement, a);
        require(_rhDestinationHash(last) == before_, "B signature cannot authorize a C write");
        _dcPolicy(replacement, 3, 201, false);
        _dcAssert(suite);
        require(
            _dcSource(original, originalScope) == sourceBefore
                && _dcSource(intermediate, middleScope) == middleBefore,
            "C native write never reopens A or B"
        );
    }

    function testRecoveredDelegationCompletePrepareGatesBadWitnessAndLateArchiveSafeRetry()
        external
    {
        _dcBaseline();
        T.SuiteConfiguration memory original = suite;
        Successor memory next = _rhCutover();
        RH.Request memory request = _dcRequest();
        Commit.Prepared memory prepared = _dcPrepared(next, request);
        request.expectedSemanticInventory = Prepared.inventory(prepared);
        bytes32 before_ = _rhDestinationHash(next);
        bytes32 sourceBefore = _dcSource(original);
        uint256 features = request.expectedCapabilities[6].supportedFeatures;
        request.expectedCapabilities[6].supportedFeatures = features & ~RH.DELEGATED_CONSENT;
        avm.expectRevert(RH.InvalidRecoveredHydrationProfile.selector);
        Recovered(address(next.registry)).hydrateRecoveredArtistAuthority(request);
        request.expectedCapabilities[6].supportedFeatures = features;
        T.EconomicsConsent[] memory terms = request.records.witnesses[0].economics;
        request.records.witnesses[0].economics = new T.EconomicsConsent[](0);
        avm.expectRevert(T.UnsupportedProfile.selector);
        Recovered(address(next.registry)).hydrateRecoveredArtistAuthority(request);
        request.records.witnesses[0].economics = terms;
        ++request.records.authority.expectedSource[2].nonceIndexCount;
        avm.expectRevert(RH.InvalidRecoveredHydrationProvenance.selector);
        Recovered(address(next.registry)).hydrateRecoveredArtistAuthority(request);
        --request.records.authority.expectedSource[2].nonceIndexCount;
        require(
            _rhDestinationHash(next) == before_,
            "bad declared capabilities/witnesses cannot partially install"
        );
        bytes memory call_ = abi.encodeCall(Recovered.hydrateRecoveredArtistAuthority, (request));
        uint256 originalBlock = block.number;
        uint256 safeNonce = rotationSafe.nonce();
        vm.roll(uint256(type(uint64).max) + 1);
        vm.expectRevert(
            abi.encodeWithSignature(
                "ArtistArchiveBlockNumberOverflow(uint256)", uint256(type(uint64).max) + 1
            )
        );
        Recovered(address(next.registry)).hydrateRecoveredArtistAuthority(request);
        require(
            _rhDestinationHash(next) == before_,
            "late original Archive restores all seven owners, grants and catalogs"
        );
        vm.expectRevert(bytes("GS013"));
        this.rhExecuteNewSafe(address(next.registry), call_);
        require(
            rotationSafe.nonce() == safeNonce && _rhDestinationHash(next) == before_,
            "real Safe nonce and complete apply rollback"
        );
        require(_dcSource(original) == sourceBefore, "failed imports preserve source");
        vm.roll(originalBlock);
        require(
            this.rhExecuteNewSafe(address(next.registry), call_),
            "identical full Safe request retries"
        );
        require(rotationSafe.nonce() == safeNonce + 1, "exactly one Safe execution");
        _rhImported(next, prepared, HydrationOwner(next.identity).authorityHydrationCommitment());
        _dcAssert(next.coordinator.suiteConfiguration());
    }

    function testRecoveredDelegationPre35GrantKeepsOriginalEpochAndCannotReviveAfterImport()
        external
    {
        // Wildcard26 is genuinely permitted before collection acceptance. This delegate differs
        // from the later guardian Safe, so no synthetic setup or repeated Safe creation is needed.
        address oldDelegate = address(0xD1E6A7E);
        bytes32 old = _dcGrant(
            D.Grant(
                artistId,
                oldDelegate,
                0,
                2,
                uint64(block.timestamp),
                uint64(block.timestamp + 365 days),
                0,
                keccak256("original pre35 grant")
            )
        );
        _dcBaseline();
        (bool valid, uint64 recorded, uint64 current) =
            RecoveredDelegationEpochReader(suite.owners[2]).delegationEpochState(old);
        require(
            !valid && recorded == 0 && current == dcEpoch && current == 1,
            "actual35 advances epoch, never rewrites old26"
        );
        Successor memory next = _rhCutover();
        _dcTransfer(next);
        _dcAssert(next.coordinator.suiteConfiguration());
        _rhAdopt(next);
        bytes32 before_ = _rhDestinationHash(next);
        vm.expectRevert(abi.encodeWithSelector(D.DelegationUnavailable.selector, old));
        vm.prank(oldDelegate);
        IStreamArtistDelegatedConsent(address(ingress))
            .recordDelegatedPolicyConsent(
                _dcPolicyTerms(300), old, T.Authorization(0, type(uint64).max, "")
            );
        require(
            _rhDestinationHash(next) == before_, "intrinsically live old grant cannot bypass epoch"
        );
        D.Grant memory p = D.Grant(
            artistId,
            oldDelegate,
            0,
            2,
            uint64(block.timestamp),
            uint64(block.timestamp + 365 days),
            0,
            keccak256("conflicting stale epoch replacement")
        );
        T.Authorization memory a = T.Authorization(nextNonce, 0, "");
        a.signature = _signature(ingress.delegationGrantDigest(p, a));
        vm.expectRevert(abi.encodeWithSelector(D.ConflictingDelegation.selector, old));
        ingress.grantArtistDelegation(p, a);
        require(
            _rhDestinationHash(next) == before_,
            "epoch invalidation does not silently free original occupied grant"
        );
    }

    function _dcBaseline() private {
        dcSale = new RecoveredDelegationSaleFacts(address(core));
        _saleRegister(
            saleModules,
            factory.governanceAuthority(),
            address(dcSale),
            dcSale.streamModuleType(),
            dcSale.streamModuleInterfaceId()
        );
        _rhBaseline();
        _adoptRotatedSafe();
        uint64 end = ingress.artistTransitionState(rhRecovery).postWindowEndsAt;
        if (block.timestamp < end) vm.warp(end);
        dcEpoch = 1;
        bytes32 first = _dcGrant(
            _delegation(1, 1030, uint64(block.timestamp), uint64(block.timestamp + 365 days), 2)
        );
        _dcPolicy(first, 257, 1, false);
        _dcSale(first, 0);
        bytes32 second = _dcGrant(
            _delegation(1, 1030, uint64(block.timestamp), uint64(block.timestamp + 365 days), 2)
        );
        T.Binding memory b = Binding(suite.owners[0]).binding(1);
        T.PayoutDesignation memory p = T.PayoutDesignation(artistId, b.artistAddress, 0);
        T.Authorization memory a = _authorization(true);
        bytes32 digest = ingress.payoutDesignationDigest(p, a);
        a.signature = _signature(digest);
        bytes32 payout = ingress.recordPayoutDesignation(p, a);
        _dcAuth(payout, digest, a, address(0));
        _rhCandidate(
            5, "payout_lifecycle.replay.designation_chain", keccak256(abi.encode(artistId))
        );
        _dcEconomics(second, 1);
        _dcRevoke(second);
        _dcGrant(
            _delegation(1, 1030, uint64(block.timestamp), uint64(block.timestamp + 365 days), 0)
        );
        require(
            Native(suite.owners[6]).artistNativeReceiptCount() == 3,
            "actual delegated14/16/15 source occurrences"
        );
    }

    function _dcGrant(D.Grant memory p) private returns (bytes32 record) {
        T.Authorization memory a = T.Authorization(nextNonce, 0, "");
        bytes32 digest = ingress.delegationGrantDigest(p, a);
        a.signature = _signature(digest);
        record = _grant(p);
        _dcAuth(record, digest, a, address(0));
        _rhCandidate(2, "identity_authority.replay.delegation_key", record);
        (, uint64 epoch,) =
            RecoveredDelegationEpochReader(suite.owners[2]).delegationEpochState(record);
        Grant memory item;
        item.hash = record;
        item.expected = D.Record(p, address(artist), a.nonce, 0, false, bytes32(0));
        require(
            keccak256(abi.encode(ingress.delegationRecord(record)))
                == keccak256(abi.encode(item.expected)),
            "exact original grant body"
        );
        item.epoch = epoch;
        item.position = _dcPosition(2, 26, record);
        dcGrants.push(item);
    }

    function _dcRevoke(bytes32 record) private {
        D.Revocation memory p =
            D.Revocation(artistId, address(delegateSafe), record, keccak256("artist revocation"));
        T.Authorization memory a = T.Authorization(nextNonce, uint64(block.timestamp + 1 days), "");
        bytes32 digest = ingress.delegationRevocationDigest(p, a);
        a.signature = _signature(digest);
        bytes32 revoked = _revoke(record);
        _dcAuth(revoked, digest, a, address(0));
        _rhCandidate(2, "identity_authority.replay.one_way_delegation_revocation", record);
        uint256 index = _dcGrantIndex(record);
        dcGrants[index].expected.revoked = true;
        dcGrants[index].expected.revocationRecordHash = revoked;
        require(
            keccak256(abi.encode(ingress.delegationRecord(record)))
                == keccak256(abi.encode(dcGrants[index].expected)),
            "revocation preserves grant terms, signer, nonce and use count"
        );
        dcGrants[index].revokedAt = _dcPosition(2, 27, revoked);
    }

    function _dcPolicyTerms(uint256 salt) private pure returns (T.PolicyConsent memory) {
        return T.PolicyConsent(
            1,
            keccak256(abi.encode("recovered delegation phase", salt)),
            keccak256(abi.encode("recovered delegation policy", salt))
        );
    }

    function _dcPolicy(bytes32 grant, uint256 nonce, uint256 salt, bool direct) private {
        T.PolicyConsent memory p = _dcPolicyTerms(salt);
        T.Authorization memory a = T.Authorization(nonce, type(uint64).max, "");
        bytes32 digest = ingress.policyConsentDigest(p, a);
        bytes32 record;
        if (direct) {
            require(
                this.executeDelegate(
                    address(ingress),
                    abi.encodeCall(
                        IStreamArtistDelegatedConsent.recordDelegatedPolicyConsent, (p, grant, a)
                    )
                ),
                "actual delegate Safe authorizes current-domain policy"
            );
            record = Consent(suite.owners[6]).policyRecord(1, p.phaseId, p.policyHash);
        } else {
            a.signature = _delegateSignature(digest);
            record = IStreamArtistDelegatedConsent(address(ingress))
                .recordDelegatedPolicyConsent(p, grant, a);
        }
        ConsentRecord memory item;
        item.operation = 14;
        item.hash = record;
        item.grant = grant;
        item.policy = p;
        _dcConsent(item, digest, a);
        _rhCandidate(
            6,
            "consent_finality.replay.policy_consent_key",
            keccak256(abi.encode(uint256(1), p.phaseId, p.policyHash))
        );
    }

    function _dcSale(bytes32 grant, uint256 nonce) private {
        Sale.Consent memory p = Sale.Consent(1, address(dcSale), dcSale.ID(), dcSale.CONFIG());
        T.Authorization memory a = T.Authorization(nonce, type(uint64).max, "");
        bytes32 digest = ingress.saleConsentDigest(p, a);
        a.signature = _delegateSignature(digest);
        bytes32 record =
            IStreamArtistDelegatedConsent(address(ingress)).recordDelegatedSaleConsent(p, grant, a);
        ConsentRecord memory item;
        item.operation = 16;
        item.hash = record;
        item.grant = grant;
        item.sale = Sales(suite.owners[6]).saleConsentRecord(record);
        require(
            record
                == keccak256(
                    abi.encode(
                        keccak256("6529STREAM_ARTIST_SALE_CONSENT_RECORD_V1"),
                        block.chainid,
                        address(ingress),
                        address(dcSale),
                        address(core),
                        uint256(1),
                        p.saleId,
                        p.saleConfigHash,
                        artistId,
                        address(delegateSafe),
                        uint8(2),
                        nonce,
                        uint64(block.timestamp)
                    )
                ),
            "exact original delegated sale preimage"
        );
        _dcConsent(item, digest, a);
        T.Binding memory b = Binding(suite.owners[0]).binding(1);
        _rhCandidate(
            6,
            "consent_finality.replay.sale_consent_key",
            keccak256(abi.encode(p, b.generation, b.bindingHash))
        );
    }

    function _dcEconomics(bytes32 grant, uint256 nonce) private {
        T.EconomicsConsent memory p = _currentEconomics(address(primary));
        T.Authorization memory a = T.Authorization(nonce, type(uint64).max, "");
        bytes32 digest = ingress.economicsConsentDigest(p, a);
        a.signature = _delegateSignature(digest);
        bytes32 record = ingress.recordDelegatedEconomicsConsent(p, grant, a);
        ConsentRecord memory item;
        item.operation = 15;
        item.hash = record;
        item.grant = grant;
        item.economics = p;
        item.association = Economics(suite.owners[6]).economicsRecordAssociation(record);
        _dcConsent(item, digest, a);
        _rhCandidate(6, "consent_finality.replay.consent_key", keccak256(abi.encode(p)));
    }

    function _dcConsent(ConsentRecord memory item, bytes32 digest, T.Authorization memory a)
        private
    {
        _dcAuth(item.hash, digest, a, address(delegateSafe));
        item.position = _dcPosition(6, item.operation, item.hash);
        dcConsents.push(item);
        uint256 index = _dcGrantIndex(item.grant);
        ++dcGrants[index].expected.uses;
        require(
            keccak256(abi.encode(ingress.delegationRecord(item.grant)))
                == keccak256(abi.encode(dcGrants[index].expected)),
            "one genuine successful delegation use"
        );
    }

    function _dcAuth(bytes32 record, bytes32 digest, T.Authorization memory a, address delegate)
        private
    {
        if (delegate == address(0)) {
            _rhAuthorization(digest, a.nonce);
        } else {
            _rhCandidate(
                2,
                "identity_authority.replay.authorization_consumed_digest",
                keccak256(abi.encode(artistId, digest))
            );
            _rhCandidate(
                2,
                "identity_authority.replay.delegated_nonce",
                keccak256(abi.encode(_dcLane(delegate), a.nonce))
            );
        }
        dcAuthorizations.push(
            Authorization(
                record,
                digest,
                a.nonce,
                delegate,
                a.signature,
                RH.Point(
                    RH.originHash(_dcOrigin(suite)),
                    2,
                    Owner(suite.owners[2]).ownerStateSnapshotV2().revision
                )
            )
        );
    }

    function _dcPosition(uint8 owner, uint16 operation, bytes32 record)
        private
        view
        returns (RH.Position memory)
    {
        uint256 index = Native(suite.owners[owner]).artistNativeReceiptCount() - 1;
        H.Receipt memory row = Native(suite.owners[owner]).artistNativeReceiptAt(index);
        require(
            row.operation == operation && row.recordHash == record && row.artistId == artistId
                && row.collectionId == (owner == 6 ? 1 : 0),
            "actual original native occurrence"
        );
        return RH.Position(
            RH.Point(
                RH.originHash(_dcOrigin(suite)),
                owner,
                NativeClock(suite.owners[owner]).artistNativeReceiptRevisionAt(index)
            ),
            index
        );
    }

    function _dcRequest() private view returns (RH.Request memory p) {
        p = _rhRequest();
        uint256 policies;
        uint256 economics;
        for (uint256 i; i < dcConsents.length; ++i) {
            if (dcConsents[i].operation == 14) ++policies;
            else if (dcConsents[i].operation == 15) ++economics;
        }
        p.records.authority.collections[0].policies = new AH.PolicyKey[](policies);
        if (economics != 0) {
            p.records.witnesses = new MR.CollectionWitness[](1);
            p.records.witnesses[0].collectionId = 1;
            p.records.witnesses[0].economics = new T.EconomicsConsent[](economics);
            p.records.witnesses[0].attestations = new Ready.AttestationInput[](0);
        }
        policies = 0;
        economics = 0;
        for (uint256 i; i < dcConsents.length; ++i) {
            ConsentRecord memory item = dcConsents[i];
            if (item.operation == 14) {
                p.records.authority.collections[0].policies[policies++] =
                    AH.PolicyKey(item.policy.phaseId, item.policy.policyHash);
            } else if (item.operation == 15) {
                p.records.witnesses[0].economics[economics++] = item.economics;
            }
        }
    }

    function _dcPrepared(Successor memory next, RH.Request memory request)
        private
        view
        returns (Commit.Prepared memory p)
    {
        p = Prepared.prepare(next.coordinator.suiteConfiguration(), request);
        for (uint8 i; i < 7; ++i) {
            (RH.ExportHeader memory h,) = Payload.decode(p.data[i].typedState, i);
            require(
                (h.requiredFeatures & RH.DELEGATED_CONSENT) != 0
                    && (h.requiredFeatures & RH.DIRECT_ECONOMICS) != 0,
                "real full source chooses delegation and economics capabilities"
            );
        }
        (, Payload.Payload memory payload) = Payload.decode(p.data[2].typedState, 2);
        IH.Bundle memory b = IdentitySource.decode(payload.semanticState, payload.provenance);
        require(
            b.delegations.length == dcGrants.length && b.heads.delegationEpoch == dcEpoch,
            "complete native26 inventory and actual current epoch"
        );
        for (uint256 i; i < dcGrants.length; ++i) {
            Grant memory g = dcGrants[i];
            bytes32 latest = g.hash;
            for (uint256 j = i + 1; j < dcGrants.length; ++j) {
                if (dcGrants[j].expected.grant.delegate == g.expected.grant.delegate) {
                    latest = dcGrants[j].hash;
                }
            }
            require(
                b.delegations[i].recordHash == g.hash && b.delegations[i].epoch == g.epoch
                    && b.delegations[i].current == latest
                    && keccak256(abi.encode(b.delegations[i].record))
                        == keccak256(abi.encode(g.expected))
                    && keccak256(abi.encode(b.delegations[i].position))
                        == keccak256(abi.encode(g.position)),
                "every original grant, final use/revoke bytes, current pointer and ultimate coordinate"
            );
        }
    }

    function _dcTransfer(Successor memory next) private returns (Commit.Prepared memory prepared) {
        RH.Request memory request = _dcRequest();
        prepared = _dcPrepared(next, request);
        request.expectedSemanticInventory = Prepared.inventory(prepared);
        bytes32 value = Recovered(address(next.registry)).hydrateRecoveredArtistAuthority(request);
        _rhImported(next, prepared, value);
    }

    function _dcAssert(T.SuiteConfiguration memory target) private view {
        T.Binding memory b = Binding(target.owners[0]).binding(1);
        require(
            b.accepted && b.consentMode == 2 && b.saleConsentScope == 1,
            "original mode2 binding retained"
        );
        for (uint256 i; i < dcGrants.length; ++i) {
            Grant memory g = dcGrants[i];
            require(
                keccak256(
                    abi.encode(IStreamArtistDelegation(target.registry).delegationRecord(g.hash))
                ) == keccak256(abi.encode(g.expected)),
                "original full grant and final mutation fields"
            );
            (bool valid, uint64 epoch, uint64 current) =
                RecoveredDelegationEpochReader(target.owners[2]).delegationEpochState(g.hash);
            require(
                epoch == g.epoch && current == dcEpoch && valid == (g.epoch == dcEpoch),
                "historical epoch separate from intrinsic current grant liveness"
            );
            _dcOccurrence(target, 2, 26, g.hash, g.position);
            _dcCell(
                target,
                2,
                "identity_authority.replay.delegation_key",
                g.hash,
                g.hash,
                g.position.point
            );
            if (g.expected.revoked) {
                _dcOccurrence(target, 2, 27, g.expected.revocationRecordHash, g.revokedAt);
                _dcCell(
                    target,
                    2,
                    "identity_authority.replay.one_way_delegation_revocation",
                    g.hash,
                    g.expected.revocationRecordHash,
                    g.revokedAt.point
                );
            }
        }
        for (uint256 i; i < dcAuthorizations.length; ++i) {
            Authorization memory a = dcAuthorizations[i];
            require(
                keccak256(Identity(target.owners[2]).signatureBundle(a.record))
                    == keccak256(a.signature),
                "exact original signature bundle including empty direct Safe proof"
            );
            _dcCell(
                target,
                2,
                "identity_authority.replay.authorization_consumed_digest",
                keccak256(abi.encode(artistId, a.digest)),
                a.digest,
                a.point
            );
            if (a.delegate == address(0)) {
                require(
                    Identity(target.owners[2]).nonceUsed(artistId, a.nonce),
                    "principal nonce retained"
                );
                _dcCell(
                    target,
                    2,
                    "identity_authority.replay.nonce_allocator",
                    keccak256(abi.encode(artistId, a.nonce)),
                    a.digest,
                    a.point
                );
            } else {
                (bool used,) = IStreamArtistDelegation(target.registry)
                    .delegatedNonceState(artistId, a.delegate, a.nonce);
                require(used, "complete delegate lane includes sparse signed nonce");
                _dcCell(
                    target,
                    2,
                    "identity_authority.replay.delegated_nonce",
                    keccak256(abi.encode(_dcLane(a.delegate), a.nonce)),
                    a.digest,
                    a.point
                );
            }
        }
        for (uint256 i; i < dcConsents.length; ++i) {
            ConsentRecord memory c = dcConsents[i];
            require(
                Delegated(target.owners[6]).recordDelegation(c.hash) == c.grant
                    && IStreamArtistDelegation(target.registry).recordDelegation(c.hash) == c.grant,
                "permanent consent-to-original-grant join"
            );
            bytes32 scope;
            string memory surface;
            if (c.operation == 14) {
                require(
                    Consent(target.owners[6]).policyRecord(1, c.policy.phaseId, c.policy.policyHash)
                        == c.hash,
                    "original14 map"
                );
                surface = "consent_finality.replay.policy_consent_key";
                scope = keccak256(abi.encode(uint256(1), c.policy.phaseId, c.policy.policyHash));
            } else if (c.operation == 15) {
                require(
                    Consent(target.owners[6]).economicsRecord(c.economics) == c.hash
                        && keccak256(
                            abi.encode(
                                Economics(target.owners[6]).economicsRecordAssociation(c.hash)
                            )
                        ) == keccak256(abi.encode(c.association))
                        && Economics(target.owners[6])
                            .economicsRecordForBinding(c.economics, artistId, 1, b.bindingHash)
                        == c.hash,
                    "all original15 payload/binding/association maps"
                );
                surface = "consent_finality.replay.consent_key";
                scope = keccak256(abi.encode(c.economics));
            } else {
                require(
                    keccak256(abi.encode(Sales(target.owners[6]).saleConsentRecord(c.hash)))
                            == keccak256(abi.encode(c.sale))
                        && Sales(target.owners[6])
                            .saleConsentAt(1, c.sale.terms.saleId, c.sale.terms.saleConfigHash)
                        == c.hash,
                    "full original16 including delegate signer, nonce, time and original binding"
                );
                surface = "consent_finality.replay.sale_consent_key";
                scope = keccak256(
                    abi.encode(c.sale.terms, c.sale.bindingGeneration, c.sale.bindingHash)
                );
            }
            _dcCell(target, 6, surface, scope, c.hash, c.position.point);
            _dcOccurrence(target, 6, c.operation, c.hash, c.position);
        }
        uint256 expectedHint;
        bool used_ = true;
        while (used_) {
            used_ = false;
            for (uint256 i; i < dcAuthorizations.length; ++i) {
                if (
                    dcAuthorizations[i].delegate == address(delegateSafe)
                        && dcAuthorizations[i].nonce == expectedHint
                ) used_ = true;
            }
            if (used_) ++expectedHint;
        }
        (, uint256 hint) = IStreamArtistDelegation(target.registry)
            .delegatedNonceState(artistId, address(delegateSafe), 257);
        require(hint == expectedHint, "replacement and hydration never reset delegate allocator");
    }

    function _dcCell(
        T.SuiteConfiguration memory target,
        uint8 owner,
        string memory surface,
        bytes32 scope,
        bytes32 commitment,
        RH.Point memory point
    ) private view {
        bytes32 key = _dcKey(target, owner, surface, scope);
        T.ReplayCell memory cell = Owner(target.owners[owner]).replayCell(key);
        require(
            cell.kind == 1 && cell.status == 2 && cell.commitment == commitment
                && cell.touchedRevision == point.ownerRevision
                && keccak256(
                    abi.encode(
                        RecoveredOwner(target.owners[owner]).recoveredHydrationReplayPoint(key)
                    )
                ) == keccak256(abi.encode(point)),
            "exact spent cell and ultimate producer clock"
        );
    }

    function _dcOccurrence(
        T.SuiteConfiguration memory target,
        uint8 owner,
        uint16 operation,
        bytes32 record,
        RH.Position memory position
    ) private view {
        (RH.OwnerProvenance memory prefix,,) =
            RecoveredOwner(target.owners[owner]).recoveredHydrationImportedPrefix();
        uint256 matches;
        for (uint256 i; i < prefix.journal.length; ++i) {
            if (prefix.journal[i].receipt.recordHash == record) {
                require(
                    prefix.journal[i].receipt.operation == operation
                        && keccak256(abi.encode(prefix.journal[i].position))
                            == keccak256(abi.encode(position)),
                    "original imported occurrence never reindexed"
                );
                ++matches;
            }
        }
        for (uint256 i; i < Native(target.owners[owner]).artistNativeReceiptCount(); ++i) {
            if (Native(target.owners[owner]).artistNativeReceiptAt(i).recordHash == record) {
                require(
                    Native(target.owners[owner]).artistNativeReceiptAt(i).operation == operation
                        && i == position.nativeIndex
                        && NativeClock(target.owners[owner]).artistNativeReceiptRevisionAt(i)
                            == position.point.ownerRevision
                        && RH.originHash(_dcOrigin(target)) == position.point.environmentHash,
                    "genuine current native occurrence"
                );
                ++matches;
            }
        }
        require(matches == 1, "one exact original occurrence");
    }

    function _dcUnavailable(bytes32 grant, uint256 nonce) private {
        T.PolicyConsent memory p = _dcPolicyTerms(nonce);
        T.Authorization memory a = T.Authorization(nonce, type(uint64).max, "");
        a.signature = _delegateSignature(ingress.policyConsentDigest(p, a));
        bytes32 before_ = _dcSource(suite);
        vm.expectRevert(abi.encodeWithSelector(D.DelegationUnavailable.selector, grant));
        IStreamArtistDelegatedConsent(address(ingress)).recordDelegatedPolicyConsent(p, grant, a);
        require(
            _dcSource(suite) == before_,
            "unavailable grant rejects before permanent nonce/use mutation"
        );
    }

    function _dcScope() private view returns (InventoryScope memory) {
        return InventoryScope(dcGrants.length, dcAuthorizations.length, dcConsents.length);
    }

    function _dcSource(T.SuiteConfiguration memory target) private view returns (bytes32) {
        return _dcSource(target, _dcScope());
    }

    // Freeze the exact original selectors, including empty direct signatures. Later B/C rows
    // must not grow A's oracle merely by appending absent-record lookups to the test arrays.
    function _dcSource(T.SuiteConfiguration memory target, InventoryScope memory scope)
        private
        view
        returns (bytes32 value)
    {
        value = _rhRecoveryFacts(target.owners[2]);
        for (uint8 i; i < 7; ++i) {
            value = keccak256(
                abi.encode(
                    value,
                    CP(target.owners[i]).authorityCheckpoint(),
                    Publications.collect(target.owners[i], i),
                    Guards.collectNonces(
                        target.owners[i], CP(target.owners[i]).authorityCheckpoint()
                    )
                )
            );
        }
        for (uint256 i; i < scope.grants; ++i) {
            value = keccak256(
                abi.encode(
                    value,
                    IStreamArtistDelegation(target.registry).delegationRecord(dcGrants[i].hash)
                )
            );
        }
        for (uint256 i; i < scope.authorizations; ++i) {
            value = keccak256(
                abi.encode(
                    value, Identity(target.owners[2]).signatureBundle(dcAuthorizations[i].record)
                )
            );
        }
        for (uint256 i; i < scope.consents; ++i) {
            ConsentRecord memory c = dcConsents[i];
            value = keccak256(
                abi.encode(
                    value,
                    Delegated(target.owners[6]).recordDelegation(c.hash),
                    Consent(target.owners[6])
                        .policyRecord(1, c.policy.phaseId, c.policy.policyHash),
                    Consent(target.owners[6]).economicsRecord(c.economics),
                    Economics(target.owners[6]).economicsRecordAssociation(c.hash),
                    Sales(target.owners[6]).saleConsentRecord(c.hash)
                )
            );
        }
    }

    function _dcGrantIndex(bytes32 record) private view returns (uint256) {
        for (uint256 i; i < dcGrants.length; ++i) {
            if (dcGrants[i].hash == record) return i;
        }
        revert("fixture grant missing");
    }

    function _dcLane(address delegate) private view returns (bytes32) {
        return keccak256(
            abi.encode(keccak256("6529STREAM_ARTIST_DELEGATE_NONCE_LANE_V1"), artistId, delegate)
        );
    }

    function _dcKey(
        T.SuiteConfiguration memory target,
        uint8 owner,
        string memory surface,
        bytes32 scope
    ) private view returns (bytes32) {
        return Guards.replayKey(
            _dcOrigin(target), owner, AH.Origin(keccak256(bytes(surface)), scope)
        );
    }

    function _dcOrigin(T.SuiteConfiguration memory target)
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
