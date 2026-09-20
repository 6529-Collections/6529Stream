// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "./ArtistOnboardingFixture.sol";
import {
    StreamArtistAuthorityHydrationTypes as AH,
    IStreamArtistAuthorityHydration as Hydrate,
    IStreamArtistAuthorityHydrationOwner as HydrationOwner
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistAuthorityHydration.sol";
import {
    IStreamArtistAuthorityCheckpoint as CP
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistAuthorityCheckpoint.sol";
import {
    IStreamArtistHistory as History,
    IStreamArtistHistoryOwner as HistoryOwner,
    IStreamArtistNativeReceipts as Native,
    StreamArtistHistoryTypes as HT
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistHistory.sol";
import "../../../smart-contracts/core/StreamCoreExternalReads.sol";
import "../../../smart-contracts/domains/artist/StreamArtistHistoryState.sol";

import "../../../smart-contracts/interfaces/stream/artist/IStreamArtistDelegationAuthorityHydration.sol";
import "../../../smart-contracts/interfaces/stream/artist/IStreamArtistDelegatedConsent.sol";
import "../../../smart-contracts/interfaces/stream/artist/IStreamArtistSaleFacts.sol";
import {
    StreamArtistDelegationHydrationTypes as DH
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistDelegationAuthorityHydration.sol";

/// @dev Explicit immutable sale-facts boundary; these tests do not execute a sale or payment.
contract DelegationHydrationSaleFacts {
    address public immutable core;
    bytes32 public constant ID = keccak256("delegation hydration sale");
    bytes32 public constant CONFIG = keccak256("delegation hydration original immutable config");

    constructor(address core_) {
        core = core_;
    }

    function streamModuleType() external pure returns (bytes32) {
        return keccak256("HYDRATION_SALE_FACTS_TEST");
    }

    function streamModuleInterfaceId() external pure returns (bytes4) {
        return type(IStreamArtistSaleFacts).interfaceId;
    }

    function supportsInterface(bytes4 id) external pure returns (bool) {
        return id == type(IStreamArtistSaleFacts).interfaceId;
    }

    function saleConsentFacts(bytes32 id) external pure returns (uint256, bytes32) {
        require(id == ID);
        return (1, CONFIG);
    }
}

/// @notice Actual original/successor Artist, seven owners, Archive and threshold Safes.
/// @dev Core/governance and the explicitly named sale facts/catalog admission remain typed boundaries.
contract StreamArtistDelegationAuthorityHydrationTest is ArtistOnboardingFixture {
    bytes32 private constant CHAIN =
        0x2eac9cfc5ca84fbeed56ef1741255e2ec7e45f48bc5c5ceda94397aa23d2f23e;
    bytes32 private constant LEAF =
        0xea04da6644046a7c731e99312c32df311e81aa7e137dfc2a49c2116bb325195d;
    bytes32 private constant POINTER = keccak256("ARTIST_REGISTRY");

    struct Next {
        StreamArtistOnboardingRegistry registry;
        StreamArtistArchiveV2 archive;
        StreamArtistOnboardingCoordinator coordinator;
        address identity;
    }
    AH.Origin[][7] private candidates;
    AH.PolicyKey[] private policyKeys;
    bytes32 private revisionHead;
    bool private signedMode;

    function _initialBindingProposal() internal view override returns (T.BindingProposal memory p) {
        p = _proposal(0);
        p.identityRecordURI = "urn:delegation:identity";
        p.consentMode = signedMode ? 1 : 2;
        p.saleConsentScope = 1;
    }

    function _seed() private {
        _candidate(
            0, "binding_lifecycle.replay.proposal_key", keccak256(abi.encode(uint256(1), uint64(1)))
        );
        _candidate(
            2,
            "identity_authority.replay.nonce_allocator",
            keccak256(abi.encode(bytes32(0), uint256(0)))
        );
        T.Authorization memory a = _authorization(false);
        bytes32 digest = ingress.acceptanceDigest(1, a);
        _authOrigins(digest, a.nonce);
        a.signature = _signature(digest);
        ingress.acceptArtistBinding(1, a);
        _candidate(
            3,
            "acceptance_lifecycle.replay.record_uniqueness",
            keccak256(abi.encode(uint256(1), uint64(1), uint8(1), address(artist)))
        );
        _candidate(2, "identity_authority.replay.one_way_cutover_latch", 0);
        _delegateSetup();
    }

    function _grantTracked(uint64 maximum, uint64 expiry) private returns (bytes32 record) {
        D.Grant memory p = _delegation(1, 1026, uint64(block.timestamp), expiry, maximum);
        T.Authorization memory a = T.Authorization(nextNonce, 0, "");
        _authOrigins(ingress.delegationGrantDigest(p, a), a.nonce);
        record = _grant(p);
        _candidate(2, "identity_authority.replay.delegation_key", record);
    }

    function _revokeTracked(bytes32 grant) private returns (bytes32) {
        D.Revocation memory p =
            D.Revocation(artistId, address(delegateSafe), grant, keccak256("artist revocation"));
        T.Authorization memory a = T.Authorization(nextNonce, uint64(block.timestamp + 1 days), "");
        _authOrigins(ingress.delegationRevocationDigest(p, a), a.nonce);
        bytes32 result = _revoke(grant);
        _candidate(2, "identity_authority.replay.one_way_delegation_revocation", grant);
        return result;
    }

    function _revisionTracked(bytes memory document) private returns (bytes32 record) {
        StreamArtistIdentityRevisionTypes.Revision memory p = _revisionProposal(document);
        T.Authorization memory a = _authorization(true);
        bytes32 digest = ingress.identityRevisionDigest(p, a);
        _authOrigins(digest, a.nonce);
        _candidate(
            2,
            "identity_authority.replay.identity_revision_chain",
            keccak256(abi.encode(artistId, revisionHead, p.previousRecordHash))
        );
        a.signature = _signature(digest);
        record = ingress.recordIdentityRevision(p, a, document, "Revised Artist");
        revisionHead = record;
    }

    function _delegateOrigins(bytes32 digest, uint256 nonce) private {
        bytes32 lane = keccak256(
            abi.encode(
                keccak256("6529STREAM_ARTIST_DELEGATE_NONCE_LANE_V1"),
                artistId,
                address(delegateSafe)
            )
        );
        _candidate(
            2,
            "identity_authority.replay.authorization_consumed_digest",
            keccak256(abi.encode(artistId, digest))
        );
        _candidate(
            2, "identity_authority.replay.delegated_nonce", keccak256(abi.encode(lane, nonce))
        );
    }

    function _policyTracked(bytes32 grant, uint256 nonce, bytes32 hash)
        private
        returns (bytes32 record)
    {
        T.PolicyConsent memory p = T.PolicyConsent(1, PHASE, hash);
        T.Authorization memory a =
            grant == 0 ? _authorization(false) : T.Authorization(nonce, type(uint64).max, "");
        bytes32 digest = ingress.policyConsentDigest(p, a);
        if (grant == 0) {
            _authOrigins(digest, a.nonce);
            a.signature = _signature(digest);
            record = ingress.recordPolicyConsent(p, a);
        } else {
            _delegateOrigins(digest, a.nonce);
            a.signature = _delegateSignature(digest);
            record = IStreamArtistDelegatedConsent(address(ingress))
                .recordDelegatedPolicyConsent(p, grant, a);
        }
        policyKeys.push(AH.PolicyKey(PHASE, hash));
        _candidate(
            6,
            "consent_finality.replay.policy_consent_key",
            keccak256(abi.encode(uint256(1), PHASE, hash))
        );
    }

    function _saleTracked(bytes32 grant, uint256 nonce)
        private
        returns (Sale.Consent memory p, bytes32 record)
    {
        DelegationHydrationSaleFacts sale = new DelegationHydrationSaleFacts(address(core));
        p = Sale.Consent(1, address(sale), sale.ID(), sale.CONFIG());
        (address modules,,,,,,,,,) = core.getSatellitePointer(keccak256("MODULE_REGISTRY"));
        avm.mockCall(
            modules,
            abi.encodeCall(
                IStreamModuleRegistry.isModuleEligible,
                (address(sale), sale.streamModuleType(), sale.streamModuleInterfaceId())
            ),
            abi.encode(true)
        );
        T.Authorization memory a =
            grant == 0 ? _authorization(false) : T.Authorization(nonce, type(uint64).max, "");
        bytes32 digest = ingress.saleConsentDigest(p, a);
        if (grant == 0) {
            _authOrigins(digest, a.nonce);
            a.signature = _signature(digest);
            record = ingress.recordSaleConsent(p, a);
        } else {
            _delegateOrigins(digest, a.nonce);
            a.signature = _delegateSignature(digest);
            record = IStreamArtistDelegatedConsent(address(ingress))
                .recordDelegatedSaleConsent(p, grant, a);
        }
        T.Binding memory binding = coordinator.reads().acceptedBinding(1);
        _candidate(
            6,
            "consent_finality.replay.sale_consent_key",
            keccak256(abi.encode(p, binding.generation, binding.bindingHash))
        );
    }

    function _hydrate(Next memory n, AH.Request memory p) private returns (bytes32) {
        return IStreamArtistDelegationAuthorityHydration(address(n.registry))
            .hydrateArtistAuthorityWithDelegations(p);
    }

    function _parity(Next memory n, bytes32[] memory grants) private view {
        T.SuiteConfiguration memory s = n.coordinator.suiteConfiguration();
        bytes32 marker = HydrationOwner(n.identity).authorityHydrationCommitment();
        require(marker != 0, "complete profile");
        for (uint256 i; i < 7; ++i) {
            require(
                HydrationOwner(s.owners[i]).authorityHydrationCommitment() == marker,
                "all owners atomic"
            );
        }
        require(
            keccak256(abi.encode(IStreamArtistIdentityOwner(n.identity).identity(artistId)))
                == keccak256(
                    abi.encode(IStreamArtistIdentityOwner(suite.owners[2]).identity(artistId))
                ),
            "original identity allocator"
        );
        require(
            n.registry.operativeIdentityRecord(artistId)
                == ingress.operativeIdentityRecord(artistId),
            "operative revision head"
        );
        require(
            keccak256(n.registry.identityRecordBytes(artistId))
                == keccak256(ingress.identityRecordBytes(artistId)),
            "actual retained document bytes"
        );
        for (uint256 i; i < grants.length; ++i) {
            require(
                keccak256(abi.encode(n.registry.delegationRecord(grants[i])))
                    == keccak256(abi.encode(ingress.delegationRecord(grants[i]))),
                "original grant/use/revocation bytes"
            );
            (bool valid, uint64 recorded, uint64 current) =
                StreamArtistIdentityAuthority(n.identity).delegationEpochState(grants[i]);
            require(valid && recorded == 0 && current == 0, "original living grant epoch");
        }
        (bool used, uint256 hint) =
            n.registry.delegatedNonceState(artistId, address(delegateSafe), 0);
        (bool oldUsed, uint256 oldHint) =
            ingress.delegatedNonceState(artistId, address(delegateSafe), 0);
        require(used == oldUsed && hint == oldHint, "delegate lane and next nonce retained");
        for (uint256 owner; owner < 7; ++owner) {
            uint256 count = Native(suite.owners[owner]).artistNativeReceiptCount();
            for (uint256 i; i < count; ++i) {
                bytes32 hash = Native(suite.owners[owner]).artistNativeReceiptAt(i).recordHash;
                require(
                    keccak256(IStreamArtistIdentityOwner(n.identity).signatureBundle(hash))
                        == keccak256(
                            IStreamArtistIdentityOwner(suite.owners[2]).signatureBundle(hash)
                        ),
                    "exact historical signature bundle"
                );
            }
        }
    }

    function testOriginalRevisionAndRevokedGrantHistoryKeepRecordedConsentAndExactArchive()
        external
    {
        _seed();
        bytes32 grant = _grantTracked(0, uint64(block.timestamp + 1 days));
        bytes32 policy = _policyTracked(grant, 0, POLICY);
        _revokeTracked(grant);
        bytes32 revision = _revisionTracked(bytes("{\"name\":\"new identity\"}"));
        Next memory n = _cutover(true, true);
        AH.Request memory p = _request();
        bytes32 prior = _allRoots(n.coordinator);
        vm.recordLogs();
        bytes32 value = _hydrate(n, p);
        _hydrationEvidence(n, p, value, prior, vm.getRecordedLogs());
        bytes32[] memory grants = new bytes32[](1);
        grants[0] = grant;
        _parity(n, grants);
        require(
            keccak256(abi.encode(n.registry.identityRevisionRecord(revision)))
                == keccak256(abi.encode(ingress.identityRevisionRecord(revision))),
            "immutable revision record"
        );
        (bool yes, bytes32 saved) = n.registry.isPolicyConsented(1, PHASE, POLICY);
        require(
            yes && saved == policy && n.registry.recordDelegation(policy) == grant,
            "revoked grant does not erase durable consent"
        );
        T.Authorization memory a = T.Authorization(1, type(uint64).max, "");
        vm.expectRevert(bytes("GS013"));
        this.executeDelegate(
            address(n.registry),
            abi.encodeCall(
                IStreamArtistDelegatedConsent.recordDelegatedPolicyConsent,
                (T.PolicyConsent(1, PHASE, keccak256("refused revoked")), grant, a)
            )
        );
    }

    function testReplacementAfterExhaustionKeepsOneDelegateNonceLaneAndHistoricGrant() external {
        _seed();
        bytes32 first = _grantTracked(1, uint64(block.timestamp + 1 days));
        bytes32 original = _policyTracked(first, 0, POLICY);
        bytes32 second = _grantTracked(2, uint64(block.timestamp + 2 days));
        Next memory n = _cutover(true, true);
        _hydrate(n, _request());
        bytes32[] memory grants = new bytes32[](2);
        grants[0] = first;
        grants[1] = second;
        _parity(n, grants);
        require(
            n.registry.recordDelegation(original) == first,
            "replacement head never substitutes recorded grant"
        );
        bytes32 roots = _allRoots(n.coordinator);
        T.PolicyConsent memory p = T.PolicyConsent(1, PHASE, keccak256("successor new policy"));
        vm.expectRevert(bytes("GS013"));
        this.executeDelegate(
            address(n.registry),
            abi.encodeCall(
                IStreamArtistDelegatedConsent.recordDelegatedPolicyConsent,
                (p, second, T.Authorization(0, type(uint64).max, ""))
            )
        );
        require(
            _allRoots(n.coordinator) == roots && n.registry.delegationRecord(second).uses == 0,
            "used nonce cannot revive under new grant"
        );
        require(
            this.executeDelegate(
                address(n.registry),
                abi.encodeCall(
                    IStreamArtistDelegatedConsent.recordDelegatedPolicyConsent,
                    (p, second, T.Authorization(1, type(uint64).max, ""))
                )
            ),
            "fresh direct Safe delegated write"
        );
        require(
            n.registry.delegationRecord(first).uses == 1
                && n.registry.delegationRecord(second).uses == 1,
            "separate exact use counters"
        );
    }

    function testExpiredGrantImportsAsHistoryAndReplacementUsesSuccessorSignatureDomain() external {
        _seed();
        bytes32 grant = _grantTracked(0, uint64(block.timestamp + 10));
        _policyTracked(grant, 0, POLICY);
        vm.warp(block.timestamp + 11);
        Next memory n = _cutover(true, true);
        _hydrate(n, _request());
        (bool active,,,,,,) = n.registry.delegationState(grant);
        require(!active, "expired remains expired");
        D.Grant memory replacement =
            _delegation(1, 2, uint64(block.timestamp), uint64(block.timestamp + 1 days), 3);
        uint256 nonce = IStreamArtistIdentityOwner(n.identity).identity(artistId).nonceHint;
        T.Authorization memory a = T.Authorization(nonce, 0, "");
        a.signature = _signature(ingress.delegationGrantDigest(replacement, a));
        avm.expectRevert(T.InvalidSignature.selector);
        n.registry.grantArtistDelegation(replacement, a);
        a.signature = _signature(n.registry.delegationGrantDigest(replacement, a));
        bytes32 fresh = n.registry.grantArtistDelegation(replacement, a);
        require(
            fresh != 0 && n.registry.delegationRecord(grant).uses == 1,
            "original grant untouched by fresh successor grant"
        );
        T.PolicyConsent memory p = T.PolicyConsent(1, PHASE, keccak256("fresh replacement policy"));
        require(
            this.executeDelegate(
                address(n.registry),
                abi.encodeCall(
                    IStreamArtistDelegatedConsent.recordDelegatedPolicyConsent,
                    (p, fresh, T.Authorization(1, type(uint64).max, ""))
                )
            ),
            "carried next delegate nonce"
        );
    }

    function testDelegatedSaleRecordAndRevokedGrantStillServeCurrentSaleConsent() external {
        _seed();
        bytes32 grant = _grantTracked(0, uint64(block.timestamp + 1 days));
        (Sale.Consent memory terms, bytes32 record) = _saleTracked(grant, 0);
        _revokeTracked(grant);
        Next memory n = _cutover(true, true);
        _hydrate(n, _request());
        T.SuiteConfiguration memory s = n.coordinator.suiteConfiguration();
        require(
            keccak256(
                    abi.encode(IStreamArtistSaleConsentOwner(s.owners[6]).saleConsentRecord(record))
                )
                == keccak256(
                    abi.encode(
                        IStreamArtistSaleConsentOwner(suite.owners[6]).saleConsentRecord(record)
                    )
                ),
            "original full sale record/domain"
        );
        require(n.registry.recordDelegation(record) == grant, "permanent sale grant witness");
        vm.prank(terms.saleAdapter);
        n.registry.requireSaleConsent(terms.collectionId, terms.saleId, terms.saleConfigHash);
    }

    function testModeOneDirectConsentAndUnusedGrantImportWithoutPromotingDelegate() external {
        signedMode = true;
        setUp();
        _seed();
        bytes32 grant = _grantTracked(0, uint64(block.timestamp + 1 days));
        _policyTracked(0, 0, POLICY);
        Next memory n = _cutover(true, true);
        _hydrate(n, _request());
        require(n.coordinator.reads().acceptedBinding(1).consentMode == 1, "signed mode retained");
        require(
            n.registry.delegationRecord(grant).uses == 0,
            "unused grant retained without invented nonce index"
        );
        vm.expectRevert(bytes("GS013"));
        this.executeDelegate(
            address(n.registry),
            abi.encodeCall(
                IStreamArtistDelegatedConsent.recordDelegatedPolicyConsent,
                (
                    T.PolicyConsent(1, PHASE, keccak256("wrong mode")),
                    grant,
                    T.Authorization(0, type(uint64).max, "")
                )
            )
        );
    }

    function testMissingDelegateNonceInventoryAndForeignOriginRefuseBeforeEveryOwnerWrite()
        external
    {
        _seed();
        bytes32 grant = _grantTracked(0, uint64(block.timestamp + 1 days));
        _policyTracked(grant, 257, POLICY);
        Next memory n = _cutover(true, true);
        AH.Request memory p = _request();
        bytes32 roots = _allRoots(n.coordinator);
        uint256 saved = p.expectedSource[2].nonceIndexCount;
        p.expectedSource[2].nonceIndexCount = 1;
        avm.expectRevert(T.InvalidRecord.selector);
        _hydrate(n, p);
        p.expectedSource[2].nonceIndexCount = saved;
        bytes32 scope = p.replayOrigins[2][0].scope;
        p.replayOrigins[2][0].scope = keccak256("foreign scope");
        avm.expectRevert(T.InvalidRecord.selector);
        _hydrate(n, p);
        p.replayOrigins[2][0].scope = scope;
        AH.PolicyKey[] memory old = p.policies;
        p.policies = new AH.PolicyKey[](0);
        avm.expectRevert(T.InvalidRecord.selector);
        _hydrate(n, p);
        p.policies = old;
        require(_allRoots(n.coordinator) == roots, "no partial import");
        _notHydrated(n);
        require(_hydrate(n, p) != 0, "exact complete request succeeds");
        (bool used, uint256 hint) =
            n.registry.delegatedNonceState(artistId, address(delegateSafe), 257);
        require(used && hint == 0, "sparse delegated nonce and unconsumed zero retained");
    }

    function testNonzeroEpochOrOmittedGrantCannotBeSmuggledThroughCompleteHeaders() external {
        _seed();
        bytes32 grant = _grantTracked(0, uint64(block.timestamp + 1 days));
        _policyTracked(grant, 0, POLICY);
        Next memory n = _cutover(true, true);
        AH.Request memory p = _request();
        AH.Query memory q = _sourceQuery(p);
        bytes memory original = IStreamArtistDelegationHydrationOwner(suite.owners[2])
            .authorityDelegationHydrationState(q);
        (, DH.Identity memory data) = abi.decode(original, (bytes32, DH.Identity));
        data.epoch = 1;
        bytes memory callData = abi.encodeCall(
            IStreamArtistDelegationHydrationOwner.authorityDelegationHydrationState, (q)
        );
        avm.mockCall(suite.owners[2], callData, abi.encode(abi.encode(DH.IDENTITY, data)));
        avm.expectRevert(T.InvalidRecord.selector);
        _hydrate(n, p);
        data.epoch = 0;
        data.grants = new DH.Grant[](0);
        avm.mockCall(suite.owners[2], callData, abi.encode(abi.encode(DH.IDENTITY, data)));
        avm.expectRevert(T.InvalidRecord.selector);
        _hydrate(n, p);
        _notHydrated(n);
        avm.clearMockedCalls();
        require(_hydrate(n, p) != 0, "exact restored export");
    }

    function testLateArchiveRollsBackImportedGrantsNoncesRevisionAndExactSafeRetry() external {
        _seed();
        bytes32 grant = _grantTracked(0, uint64(block.timestamp + 1 days));
        _policyTracked(grant, 0, POLICY);
        _revisionTracked(bytes("{\"name\":\"retained\"}"));
        Next memory n = _cutover(true, true);
        AH.Request memory p = _request();
        bytes memory data = abi.encodeCall(
            IStreamArtistDelegationAuthorityHydration.hydrateArtistAuthorityWithDelegations, (p)
        );
        bytes32 roots = _allRoots(n.coordinator);
        uint256 nonce = artist.nonce();
        avm.mockCallRevert(
            address(n.archive),
            abi.encodeWithSelector(IStreamArtistArchiveV2.appendArtistEvidenceV2.selector),
            abi.encodeWithSignature("Error(string)", "late delegation archive")
        );
        vm.expectRevert(bytes("GS013"));
        this.executeTargetSafe(address(n.registry), data);
        require(
            artist.nonce() == nonce && _allRoots(n.coordinator) == roots
                && n.registry.delegationRecord(grant).grantor == address(0),
            "entire typed import and Safe roll back"
        );
        _notHydrated(n);
        avm.clearMockedCalls();
        require(this.executeTargetSafe(address(n.registry), data), "identical Safe retry");
        bytes32[] memory grants = new bytes32[](1);
        grants[0] = grant;
        _parity(n, grants);
        avm.expectRevert(T.InvalidRecord.selector);
        _hydrate(n, p);
    }

    function testLegacySelectorStillRefusesDelegation() external {
        _seed();
        _grantTracked(0, uint64(block.timestamp + 1 days));
        Next memory n = _cutover(true, true);
        AH.Request memory p = _request();
        avm.expectRevert(T.UnsupportedProfile.selector);
        Hydrate(address(n.registry)).hydrateArtistAuthority(p);
        require(_hydrate(n, p) != 0, "explicit delegation profile");
    }

    function testActualGuardianHistoryCannotDefaultToOriginalLivingDelegationProfile() external {
        _seed();
        address[] memory members = new address[](1);
        members[0] = address(0xF00D);
        R.GuardianSet memory terms = R.GuardianSet(artistId, members, 1, 0);
        T.Authorization memory a = T.Authorization(nextNonce, uint64(block.timestamp), "");
        _authOrigins(ingress.guardianSetDigest(terms, a), a.nonce);
        _candidate(
            2,
            "identity_authority.replay.guardian_set_chain",
            keccak256(abi.encode(artistId, a.nonce))
        );
        bytes32 guardian = _guardianRecord(members, 1, 0, a.nonce);
        require(guardian != 0, "actual unsupported authority history exists");
        Next memory n = _cutover(true, true);
        AH.Request memory p = _request();
        bytes32 roots = _allRoots(n.coordinator);
        avm.expectRevert(T.UnsupportedProfile.selector);
        _hydrate(n, p);
        require(
            _allRoots(n.coordinator) == roots, "unsupported history fails before any owner import"
        );
        _notHydrated(n);
    }

    function _sourceQuery(AH.Request memory p) private view returns (AH.Query memory q) {
        q.artistId = artistId;
        q.collectionId = 1;
        q.bindingHash = coordinator.reads().acceptedBinding(1).bindingHash;
        q.policies = p.policies;
        uint256 count;
        for (uint256 i; i < 7; ++i) {
            count += Native(suite.owners[i]).artistNativeReceiptCount();
        }
        q.records = new bytes32[](count);
        uint256 k;
        for (uint256 i; i < 7; ++i) {
            for (uint256 j; j < Native(suite.owners[i]).artistNativeReceiptCount(); ++j) {
                q.records[k++] = Native(suite.owners[i]).artistNativeReceiptAt(j).recordHash;
            }
        }
    }

    function _candidate(uint256 owner, string memory surface, bytes32 scope) private {
        candidates[owner].push(AH.Origin(keccak256(bytes(surface)), scope));
    }

    function _authOrigins(bytes32 digest, uint256 nonce) private {
        _candidate(
            2,
            "identity_authority.replay.authorization_consumed_digest",
            keccak256(abi.encode(artistId, digest))
        );
        _candidate(
            2, "identity_authority.replay.nonce_allocator", keccak256(abi.encode(artistId, nonce))
        );
    }

    function _sourceKey(uint256 owner, AH.Origin memory o) private view returns (bytes32) {
        return keccak256(
            abi.encode(
                keccak256("6529STREAM_ARTIST_OWNER_REPLAY_KEY_V2"),
                block.chainid,
                address(ingress),
                address(coordinator),
                address(archive),
                suite.owners[owner],
                IStreamArtistOwner(suite.owners[owner]).domainId(),
                o.surface,
                o.scope
            )
        );
    }

    function _request() private view returns (AH.Request memory p) {
        p.artistId = artistId;
        p.collectionId = 1;
        p.policies = policyKeys;
        for (uint256 owner; owner < 7; ++owner) {
            p.expectedSource[owner] = CP(suite.owners[owner]).authorityCheckpoint();
            p.replayOrigins[owner] = new AH.Origin[](p.expectedSource[owner].replayCount);
            for (uint256 j; j < p.expectedSource[owner].replayCount; ++j) {
                (bytes32 key,) = CP(suite.owners[owner]).authorityReplayAt(j);
                bool found;
                for (uint256 k; k < candidates[owner].length; ++k) {
                    if (_sourceKey(owner, candidates[owner][k]) == key) {
                        p.replayOrigins[owner][j] = candidates[owner][k];
                        found = true;
                        break;
                    }
                }
                require(found, "independent preimage exists for every actual source guard");
            }
        }
    }

    function _cutover(bool seal, bool latchCollection) private returns (Next memory n) {
        n = _next();
        HT.Leaf[] memory rows = _leaves(History(address(ingress)));
        (bytes32 root,) = _proof(address(ingress), rows, 0);
        _commit(n, root, keccak256("complete original living delegation manifest"));
        core.set(POINTER, address(n.registry), false);
        if (seal) History(address(ingress)).observeRegistryCutover();
        (, uint64 count) = History(address(ingress)).artistHistoryLane(1, artistId);
        (, bytes32[] memory proof) = _proof(address(ingress), rows, count - 1);
        History(address(n.registry)).verifyImportedLaneTip(0, rows[count - 1], proof);
        if (latchCollection) {
            (, proof) = _proof(address(ingress), rows, rows.length - 1);
            History(address(n.registry)).verifyImportedLaneTip(0, rows[rows.length - 1], proof);
        }
    }

    function _allRoots(StreamArtistOnboardingCoordinator c) private view returns (bytes32) {
        T.SuiteConfiguration memory s = c.suiteConfiguration();
        T.Snapshot[7] memory snapshots;
        for (uint256 j; j < 7; ++j) {
            snapshots[j] = IStreamArtistOwner(s.owners[j]).ownerStateSnapshotV2();
        }
        return keccak256(abi.encode(snapshots));
    }

    function _notHydrated(Next memory n) private view {
        T.SuiteConfiguration memory s = n.coordinator.suiteConfiguration();
        for (uint256 j; j < 7; ++j) {
            require(
                HydrationOwner(s.owners[j]).authorityHydrationCommitment() == 0,
                "no partial owner activation"
            );
        }
        require(
            IStreamArtistIdentityOwner(n.identity).identity(artistId).authorityAddress
                == address(0),
            "no living default authority"
        );
    }

    function _hydrationEvidence(
        Next memory n,
        AH.Request memory p,
        bytes32 value,
        bytes32 prior,
        Vm.Log[] memory logs
    ) private view {
        bytes32 id = keccak256(
            abi.encode(
                keccak256("6529STREAM_ARTIST_ONBOARDING_OPERATION_EVIDENCE_V1"),
                block.chainid,
                address(n.registry),
                address(n.coordinator),
                uint16(60),
                address(this),
                value
            )
        );
        (
            uint16 schema,
            bytes32 configuration,
            uint16 op,
            address actor,
            bytes32 record,
            T.Snapshot[7] memory before_,
            T.Snapshot[7] memory after_,
            bytes memory payload
        ) = abi.decode(
            n.archive.artistEvidenceBytesV2(id, 1),
            (uint16, bytes32, uint16, address, bytes32, T.Snapshot[7], T.Snapshot[7], bytes)
        );
        require(
            schema == 1 && op == 60 && actor == address(this) && record == value
                && configuration == n.coordinator.configurationHash(),
            "original atomic operation envelope"
        );
        require(
            keccak256(abi.encode(before_)) == prior
                && keccak256(abi.encode(after_)) == _allRoots(n.coordinator),
            "all seven exact owner snapshots"
        );
        for (uint256 j; j < 7; ++j) {
            require(
                before_[j].domainId != 0 && after_[j].revision == before_[j].revision + 1,
                "explicit seven-owner write mask"
            );
        }
        (
            bytes32 profile,
            address predecessor,
            address priorCoordinator,
            CP.Checkpoint[7] memory sourceHeaders,
            AH.Query memory query,
            AH.OwnerData[7] memory data
        ) = abi.decode(
            payload, (bytes32, address, address, CP.Checkpoint[7], AH.Query, AH.OwnerData[7])
        );
        AH.Request memory original;
        original.artistId = query.artistId;
        original.collectionId = query.collectionId;
        original.expectedSource = sourceHeaders;
        original.policies = query.policies;
        for (uint256 j; j < 7; ++j) {
            original.replayOrigins[j] = data[j].origins;
        }
        require(
            profile == keccak256("6529STREAM_ARTIST_LIVING_DELEGATION_HYDRATION_V1")
                && predecessor == address(ingress) && priorCoordinator == address(coordinator)
                && keccak256(abi.encode(original)) == keccak256(abi.encode(p)),
            "complete source headers and original request"
        );
        require(
            keccak256(abi.encode(query)) == keccak256(abi.encode(_sourceQuery(p))),
            "independent journal ordering and complete query"
        );
        for (uint256 j; j < 7; ++j) {
            bytes memory originalState = j == 0 || j == 2 || j == 6
                ? IStreamArtistDelegationHydrationOwner(suite.owners[j])
                    .authorityDelegationHydrationState(query)
                : HydrationOwner(suite.owners[j]).authorityHydrationState(query);
            require(
                keccak256(originalState) == keccak256(data[j].typedState),
                "exact fixed owner export bytes in Archive"
            );
        }
        (bytes32 identityTag, DH.Identity memory identityData) =
            abi.decode(data[2].typedState, (bytes32, DH.Identity));
        (bytes32 bindingTag, AH.Binding memory bindingData) =
            abi.decode(data[0].typedState, (bytes32, AH.Binding));
        (bytes32 consentTag, DH.Consent memory consentData) =
            abi.decode(data[6].typedState, (bytes32, DH.Consent));
        require(
            identityTag == keccak256("6529STREAM_ARTIST_LIVING_DELEGATION_IDENTITY_V1")
                && bindingTag == keccak256("6529STREAM_ARTIST_LIVING_DELEGATION_BINDING_V1")
                && consentTag == keccak256("6529STREAM_ARTIST_LIVING_DELEGATION_CONSENT_V1"),
            "independent tagged cross-owner codec"
        );
        require(
            identityData.epoch == 0 && bindingData.item.artistId == artistId
                && consentData.policies.length == p.policies.length,
            "profile identity and complete policy inventory"
        );
        require(
            value
                == keccak256(
                    abi.encode(
                        profile,
                        block.chainid,
                        address(n.registry),
                        address(n.coordinator),
                        predecessor,
                        priorCoordinator,
                        p,
                        query,
                        data
                    )
                ),
            "independent whole profile commitment"
        );
        uint256 found;
        bytes32 topic =
            keccak256("ArtistAuthorityHydrated(uint16,bytes32,uint256,address,bytes32,bytes32)");
        for (uint256 j; j < logs.length; ++j) {
            if (
                logs[j].emitter == address(n.coordinator) && logs[j].topics.length != 0
                    && logs[j].topics[0] == topic
            ) {
                ++found;
                require(
                    logs[j].topics.length == 4 && logs[j].topics[1] == artistId
                        && logs[j].topics[2] == bytes32(uint256(1))
                        && logs[j].topics[3] == bytes32(uint256(uint160(address(ingress))))
                        && keccak256(logs[j].data)
                            == keccak256(abi.encode(uint16(1), profile, value)),
                    "independent actual emitter and complete schema event"
                );
            }
        }
        require(found == 1, "one successful hydration event");
    }

    function _leaves(History h) private view returns (HT.Leaf[] memory rows) {
        (, uint64 a) = h.artistHistoryLane(1, artistId);
        (, uint64 b) = h.artistHistoryLane(2, bytes32(uint256(1)));
        rows = new HT.Leaf[](uint256(a) + b);
        for (uint64 i; i < a; ++i) {
            (bytes32 r, bytes32 c) = h.artistHistoryRecordAt(1, artistId, i);
            rows[i] = HT.Leaf(1, artistId, i, r, c);
        }
        for (uint64 i; i < b; ++i) {
            (bytes32 r, bytes32 c) = h.artistHistoryRecordAt(2, bytes32(uint256(1)), i);
            rows[uint256(a) + i] = HT.Leaf(2, bytes32(uint256(1)), i, r, c);
        }
    }

    function _leaf(address predecessor, HT.Leaf memory p) private view returns (bytes32) {
        return keccak256(
            bytes.concat(
                keccak256(
                    abi.encode(
                        LEAF,
                        block.chainid,
                        predecessor,
                        p.laneKind,
                        p.laneKey,
                        p.sequence,
                        p.recordHash,
                        p.recordChainHash
                    )
                )
            )
        );
    }

    function _proof(address predecessor, HT.Leaf[] memory leaves, uint256 index)
        private
        view
        returns (bytes32 root, bytes32[] memory proof)
    {
        bytes32[] memory layer = new bytes32[](leaves.length);
        proof = new bytes32[](64);
        uint256 used;
        uint256 n = leaves.length;
        for (uint256 i; i < n; ++i) {
            layer[i] = _leaf(predecessor, leaves[i]);
        }
        while (n > 1) {
            if ((index ^ 1) < n) proof[used++] = layer[index ^ 1];
            uint256 nextN = (n + 1) / 2;
            for (uint256 i; i < nextN; ++i) {
                uint256 j = i * 2;
                if (j + 1 == n) {
                    layer[i] = layer[j];
                } else {
                    bytes32 a = layer[j];
                    bytes32 b = layer[j + 1];
                    layer[i] = a < b ? keccak256(abi.encode(a, b)) : keccak256(abi.encode(b, a));
                }
            }
            index /= 2;
            n = nextN;
        }
        root = layer[0];
        assembly ("memory-safe") { mstore(proof, used) }
    }

    function _commitData(Next memory n, bytes32 root, bytes32 manifest, uint8 cls, bool wrong)
        private
        view
        returns (bytes memory)
    {
        HT.Context memory x = History(address(n.registry))
            .artistHistoryImportContext(address(ingress), uint64(block.number), root, manifest);
        return abi.encodeCall(
            ArtistUnitGovernance.executeModuleContext,
            (
                address(n.registry),
                abi.encodeCall(
                    History.commitArtistHistoryImportRoot,
                    (address(ingress), uint64(block.number), root, manifest)
                ),
                cls,
                x.scopeHash,
                wrong ? keccak256("wrong import state") : x.oldValueHash,
                x.newValueHash
            )
        );
    }

    function _commit(Next memory n, bytes32 root, bytes32 manifest) private {
        ArtistUnitGovernance authority = ArtistUnitGovernance(manager.governanceAuthority());
        authority.configureContestReads(
            suite.roleRegistry, address(artist), manifest, "urn:history"
        );
        bytes memory data = _commitData(n, root, manifest, 1, false);
        vm.recordLogs();
        require(
            this.executeTargetSafe(address(authority), data),
            "actual threshold Safe executes typed governance context"
        );
        _historyEvent(
            vm.getRecordedLogs(),
            n.identity,
            keccak256(
                "ArtistHistoryImportRootCommitted(uint16,address,bytes32,uint64,bytes32,bytes32)"
            ),
            bytes32(uint256(uint160(address(ingress)))),
            root,
            abi.encode(
                uint16(1), uint64(block.number), manifest, keccak256("unit authority gas raise")
            )
        );
    }

    function _historyEvent(
        Vm.Log[] memory logs,
        address emitter,
        bytes32 topic,
        bytes32 first,
        bytes32 second,
        bytes memory expected
    ) private pure {
        uint256 found;
        for (uint256 i; i < logs.length; ++i) {
            Vm.Log memory entry = logs[i];
            if (entry.emitter != emitter || entry.topics.length == 0 || entry.topics[0] != topic) {
                continue;
            }
            ++found;
            require(
                entry.topics.length == (second == 0 ? 2 : 3) && entry.topics[1] == first,
                "exact original event emitter/topics"
            );
            if (second != 0) require(entry.topics[2] == second, "exact second indexed word");
            require(
                keccak256(entry.data) == keccak256(expected),
                "independent complete normative event data"
            );
        }
        require(found == 1, "one original normative import event");
    }

    function _next() private returns (Next memory n) {
        T.SuiteConfiguration memory s = suite;
        address governance = manager.governanceAuthority();
        ArtistSanctionFinalityFixture finalityFixture = new ArtistSanctionFinalityFixture();
        uint256 nonce = avm.getNonce(address(this));
        address registry_ = avm.computeCreateAddress(address(this), nonce);
        address archive_ = avm.computeCreateAddress(address(this), nonce + 1);
        address coordinator_ = avm.computeCreateAddress(address(this), nonce + 9);
        address identity_ = avm.computeCreateAddress(address(this), nonce + 4);
        address[3] memory facade;
        address[3] memory identity;
        for (uint8 i; i < 3; ++i) {
            facade[i] = artistExtensionFactory.deployRegistry(i + 4, registry_, coordinator_);
        }
        for (uint8 i; i < 3; ++i) {
            identity[i] = artistExtensionFactory.deployIdentity(
                i + 1, [identity_, registry_, coordinator_, archive_, s.core, s.mintManager]
            );
        }
        n.registry = StreamArtistOnboardingRegistry(
            payable(_artistArtifactCreate(
                    "smart-contracts/domains/artist/StreamArtistOnboardingRegistry.sol:StreamArtistOnboardingRegistry",
                    abi.encode(
                        s.core,
                        s.mintManager,
                        coordinator_,
                        governance,
                        address(estateCoverageProvider),
                        keccak256("successor deployment"),
                        "urn:successor",
                        keccak256("successor manifest"),
                        address(artistExtensionFactory),
                        facade
                    )
                ))
        );
        n.archive = StreamArtistArchiveV2(
            payable(_artistArtifactCreate(
                    "smart-contracts/domains/artist/StreamArtistArchiveV2.sol:StreamArtistArchiveV2",
                    abi.encode(registry_, coordinator_)
                ))
        );
        s.registry = registry_;
        s.archive = archive_;
        s.owners[0] = address(
            StreamArtistBindingLifecycle(
                payable(_artistArtifactCreate(
                        "smart-contracts/domains/artist/StreamArtistBindingLifecycle.sol:StreamArtistBindingLifecycle",
                        abi.encode(registry_, coordinator_, archive_, s.core, s.mintManager)
                    ))
            )
        );
        s.owners[1] = address(
            StreamArtistCollaboratorLifecycle(
                payable(_artistArtifactCreate(
                        "smart-contracts/domains/artist/StreamArtistCollaboratorLifecycle.sol:StreamArtistCollaboratorLifecycle",
                        abi.encode(registry_, coordinator_, archive_, s.core, s.mintManager)
                    ))
            )
        );
        s.owners[2] = address(
            StreamArtistIdentityAuthority(
                payable(_artistArtifactCreate(
                        "smart-contracts/domains/artist/StreamArtistIdentityAuthority.sol:StreamArtistIdentityAuthority",
                        abi.encode(
                            registry_,
                            coordinator_,
                            archive_,
                            s.core,
                            s.mintManager,
                            address(artistExtensionFactory),
                            identity
                        )
                    ))
            )
        );
        s.owners[3] = address(
            StreamArtistAcceptanceLifecycle(
                payable(_artistArtifactCreate(
                        "smart-contracts/domains/artist/StreamArtistAcceptanceLifecycle.sol:StreamArtistAcceptanceLifecycle",
                        abi.encode(registry_, coordinator_, archive_, s.core, s.mintManager)
                    ))
            )
        );
        s.owners[4] = address(
            StreamArtistAttributionLifecycle(
                payable(_artistArtifactCreate(
                        "smart-contracts/domains/artist/StreamArtistAttributionLifecycle.sol:StreamArtistAttributionLifecycle",
                        abi.encode(registry_, coordinator_, archive_, s.core, s.mintManager)
                    ))
            )
        );
        s.owners[5] = address(
            StreamArtistPayoutLifecycle(
                payable(_artistArtifactCreate(
                        "smart-contracts/domains/artist/StreamArtistPayoutLifecycle.sol:StreamArtistPayoutLifecycle",
                        abi.encode(registry_, coordinator_, archive_, s.core, s.mintManager)
                    ))
            )
        );
        s.owners[6] = address(
            StreamArtistConsentFinalityLifecycle(
                payable(_artistArtifactCreate(
                        "smart-contracts/domains/artist/StreamArtistConsentFinalityLifecycle.sol:StreamArtistConsentFinalityLifecycle",
                        abi.encode(registry_, coordinator_, archive_, s.core, s.mintManager)
                    ))
            )
        );
        ArtistUnitGovernance(governance)
            .configureContestReads(
                s.roleRegistry, address(artist), keccak256("successor finality"), "urn:successor"
            );
        address finality = finalityFixture.deploy(s.core, s.metadata, registry_, governance);
        n.coordinator = StreamArtistOnboardingCoordinator(
            payable(_artistArtifactCreate(
                    "smart-contracts/domains/artist/StreamArtistOnboardingCoordinator.sol:StreamArtistOnboardingCoordinator",
                    abi.encode(s, finality)
                ))
        );
        n.identity = s.owners[2];
        require(
            address(n.registry) == registry_ && address(n.archive) == archive_
                && address(n.coordinator) == coordinator_ && n.identity == identity_,
            "actual successor pins"
        );
    }
}
