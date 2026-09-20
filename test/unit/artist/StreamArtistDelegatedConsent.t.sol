// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "./ArtistOnboardingFixture.sol";
import "../../../smart-contracts/interfaces/stream/artist/IStreamArtistDelegatedConsent.sol";
import {
    StreamArtistAuthorityHydrationTypes as AH,
    IStreamArtistAuthorityHydrationOwner
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistAuthorityHydration.sol";

/// @notice Actual Artist facade/owners/Archive, Manager, resolvers, registered native adapter and threshold Safes.
/// @dev Core, role/governance and metadata remain the original explicitly typed unit boundaries.
contract StreamArtistDelegatedConsentTest is ArtistOnboardingFixture {
    bool private signedMode;

    function _initialBindingProposal() internal view override returns (T.BindingProposal memory p) {
        p = _proposal(bytes32(0));
        p.consentMode = signedMode ? 1 : 2;
    }

    function _dc() private view returns (IStreamArtistDelegatedConsent) {
        return IStreamArtistDelegatedConsent(address(ingress));
    }

    function _terms() private view returns (T.PolicyConsent memory) {
        return T.PolicyConsent(1, PHASE, POLICY);
    }

    function _readyPolicy(uint32 caps, uint64 maximum) private returns (bytes32 grant) {
        _accept();
        _payout();
        _economics();
        _ratify();
        _attestations();
        _delegateSetup();
        grant = _grant(
            _delegation(1, caps, uint64(block.timestamp), uint64(block.timestamp + 1 days), maximum)
        );
    }

    function _policyAuth(T.PolicyConsent memory p, uint256 nonce)
        private
        returns (T.Authorization memory a)
    {
        a = T.Authorization(nonce, type(uint64).max, "");
        a.signature = _delegateSignature(ingress.policyConsentDigest(p, a));
    }

    function _saleAuth(Sale.Consent memory p, uint256 nonce)
        private
        returns (T.Authorization memory a)
    {
        a = T.Authorization(nonce, type(uint64).max, "");
        a.signature = _delegateSignature(ingress.saleConsentDigest(p, a));
    }

    function _grantSale(uint64 maximum) private returns (bytes32) {
        _delegateSetup();
        return _grant(
            _delegation(1, 1024, uint64(block.timestamp), uint64(block.timestamp + 1 days), maximum)
        );
    }

    function _anotherSale(uint96 price) private returns (Sale.Consent memory p) {
        bytes32 id = nativeSale.registerSale(
            IStreamNativeFixedPriceSaleAdapter.SaleConfig(
                1,
                PHASE,
                price,
                0,
                type(uint64).max,
                POLICY,
                primary.resolvePrimaryAssignment(1, 0, PRIMARY).assignmentHash
            )
        );
        p = Sale.Consent(1, address(nativeSale), id, nativeSale.saleRecord(id).configHash);
    }

    function _literalPolicy(T.PolicyConsent memory p, T.Authorization memory a)
        private
        view
        returns (bytes32)
    {
        return keccak256(
            abi.encode(
                keccak256("6529STREAM_ARTIST_POLICY_CONSENT_RECORD_V1"),
                block.chainid,
                address(ingress),
                address(manager),
                p.collectionId,
                p.phaseId,
                p.policyHash,
                artistId,
                address(delegateSafe),
                uint8(2),
                a.nonce,
                uint64(block.timestamp)
            )
        );
    }

    function _literalSale(Sale.Consent memory p, T.Authorization memory a)
        private
        view
        returns (bytes32)
    {
        return keccak256(
            abi.encode(
                keccak256("6529STREAM_ARTIST_SALE_CONSENT_RECORD_V1"),
                block.chainid,
                address(ingress),
                p.saleAdapter,
                address(core),
                p.collectionId,
                p.saleId,
                p.saleConfigHash,
                artistId,
                address(delegateSafe),
                uint8(2),
                a.nonce,
                uint64(block.timestamp)
            )
        );
    }

    function testModeTwoPolicyUsesOriginalDigestRecordGrantArchiveAndActualReadiness() public {
        bytes32 grant = _readyPolicy(2, 1);
        T.PolicyConsent memory p = _terms();
        T.Authorization memory a = _policyAuth(p, 0);
        uint256 principalNonceBefore =
            IStreamArtistIdentityOwner(suite.owners[2]).identity(artistId).nonceHint;
        vm.recordLogs();
        bytes32 record = _dc().recordDelegatedPolicyConsent(p, grant, a);
        Vm.Log[] memory logs = vm.getRecordedLogs();
        require(record == _literalPolicy(p, a), "original policy record words class2");
        require(
            ingress.recordDelegation(record) == grant && ingress.delegationRecord(grant).uses == 1,
            "one grant use"
        );
        require(
            IStreamArtistIdentityOwner(suite.owners[2]).identity(artistId).nonceHint
                == principalNonceBefore,
            "actual principal authorization lane untouched"
        );
        require(_operationPayload(14, address(this), record).length != 0, "actual archive");
        _delegationEvent(logs, record, grant, 14);
        ingress.requireMintConsent(1, PHASE, POLICY);
        vm.expectRevert();
        _dc().recordDelegatedPolicyConsent(p, grant, a);
    }

    function _delegationEvent(Vm.Log[] memory logs, bytes32 record, bytes32 grant, uint16 op)
        private
        view
    {
        bytes32 topic =
            keccak256("ArtistConsentDelegationRecorded(uint16,bytes32,bytes32,bytes32,uint16)");
        uint256 count;
        for (uint256 i; i < logs.length; ++i) {
            if (logs[i].topics.length == 4 && logs[i].topics[0] == topic) {
                require(
                    logs[i].emitter == suite.owners[6] && logs[i].topics[1] == record
                        && logs[i].topics[2] == grant && logs[i].topics[3] == artistId,
                    "association emitter and indexed identity"
                );
                require(
                    keccak256(logs[i].data) == keccak256(abi.encode(uint16(1), op)),
                    "association version/op"
                );
                ++count;
            }
        }
        require(count == 1, "one association event");
    }

    function testModeTwoSaleUsesExactOriginalRecordAndCurrentRegisteredFacts() public {
        Sale.Consent memory p = _saleFixture(1);
        bytes32 grant = _grantSale(1);
        T.Authorization memory a = _saleAuth(p, 0);
        bytes32 record = _dc().recordDelegatedSaleConsent(p, grant, a);
        require(
            record == _literalSale(p, a) && ingress.recordDelegation(record) == grant,
            "class2 original sale record"
        );
        Sale.Record memory item =
            IStreamArtistSaleConsentOwner(suite.owners[6]).saleConsentRecord(record);
        require(
            item.signer == address(delegateSafe) && item.authorityClass == 2
                && item.artistId == artistId,
            "delegate retains original primary artist identity"
        );
        _requireSale(p);
        require(_operationPayload(16, address(this), record).length != 0, "actual op16 archive");
    }

    function _policyTerminal(uint8 reason) private {
        bytes32 grant = _readyPolicy(2, reason == 2 ? 1 : 0);
        T.PolicyConsent memory p = _terms();
        bytes32 record = _dc().recordDelegatedPolicyConsent(p, grant, _policyAuth(p, 0));
        if (reason == 0) vm.warp(ingress.delegationRecord(grant).grant.expiresAt);
        if (reason == 1) _revoke(grant);
        ingress.requireMintConsent(1, PHASE, POLICY);
        require(ingress.recordDelegation(record) == grant, "old consent retains provenance");
        T.PolicyConsent memory changed =
            T.PolicyConsent(1, PHASE, keccak256("changed unsigned policy"));
        T.Authorization memory a = _policyAuth(changed, 1);
        bytes32 before_ = _roots();
        vm.expectRevert(abi.encodeWithSelector(D.DelegationUnavailable.selector, grant));
        _dc().recordDelegatedPolicyConsent(changed, grant, a);
        require(
            _roots() == before_ && ingress.delegationRecord(grant).uses == 1, "denied action atomic"
        );
        vm.expectRevert(
            abi.encodeWithSelector(T.MissingMintPrerequisite.selector, keccak256("policy"))
        );
        ingress.requireMintConsent(1, PHASE, changed.policyHash);
    }

    function testExpiredGrantKeepsExactPolicyConsentButRefusesNewChangedPolicy() public {
        _policyTerminal(0);
    }

    function testRevokedGrantKeepsExactPolicyConsentButRefusesNewChangedPolicy() public {
        _policyTerminal(1);
    }

    function testExhaustedOneUseGrantKeepsExactPolicyConsentButRefusesNewChangedPolicy() public {
        _policyTerminal(2);
    }

    function _saleTerminal(uint8 reason) private {
        Sale.Consent memory p = _saleFixture(1);
        bytes32 grant = _grantSale(reason == 2 ? 1 : 0);
        bytes32 record = _dc().recordDelegatedSaleConsent(p, grant, _saleAuth(p, 0));
        if (reason == 0) vm.warp(ingress.delegationRecord(grant).grant.expiresAt);
        if (reason == 1) _revoke(grant);
        _requireSale(p);
        Sale.Consent memory changed = _anotherSale(1001);
        T.Authorization memory a = _saleAuth(changed, 1);
        bytes32 before_ = _roots();
        vm.expectRevert(abi.encodeWithSelector(D.DelegationUnavailable.selector, grant));
        _dc().recordDelegatedSaleConsent(changed, grant, a);
        require(
            _roots() == before_ && ingress.recordDelegation(record) == grant,
            "historical record unchanged"
        );
        vm.expectRevert(
            abi.encodeWithSelector(
                Sale.SaleConsentUnavailable.selector, 1, changed.saleId, changed.saleConfigHash
            )
        );
        _requireSale(changed);
    }

    function testExpiredGrantKeepsExactSaleConsentButRefusesNewSale() public {
        _saleTerminal(0);
    }

    function testRevokedGrantKeepsExactSaleConsentButRefusesNewSale() public {
        _saleTerminal(1);
    }

    function testExhaustedOneUseGrantKeepsExactSaleConsentButRefusesNewSale() public {
        _saleTerminal(2);
    }

    function testModeOneRefusesBothDelegatedActionsEvenWithBothCapabilities() public {
        signedMode = true;
        Sale.Consent memory p = _saleFixture(1);
        _delegateSetup();
        bytes32 grant = _grant(_delegation(1, 1026, 1000, 2000, 0));
        T.PolicyConsent memory policy_ = T.PolicyConsent(1, PHASE, keccak256("new policy"));
        T.Authorization memory a = _policyAuth(policy_, 0);
        vm.expectRevert(abi.encodeWithSelector(T.UnsupportedProfile.selector));
        _dc().recordDelegatedPolicyConsent(policy_, grant, a);
        a = _saleAuth(p, 0);
        vm.expectRevert(abi.encodeWithSelector(T.UnsupportedProfile.selector));
        _dc().recordDelegatedSaleConsent(p, grant, a);
        require(ingress.delegationRecord(grant).uses == 0, "forbidden mode consumes no grant");
    }

    function testModeTwoStillAllowsOriginalPrincipalPolicyAndSale() public {
        Sale.Consent memory p = _saleFixture(1);
        bytes32 record = ingress.recordSaleConsent(p, _saleAuthorization(p));
        require(ingress.recordDelegation(record) == 0, "principal record has no invented grant");
        _requireSale(p);
        ingress.requireMintConsent(1, PHASE, POLICY);
    }

    function testDelegateCannotUseMissingCapabilityOrMissingCollectionAndForbiddenCapsStayRejected()
        public
    {
        bytes32 grant = _readyPolicy(4, 0);
        T.PolicyConsent memory p = _terms();
        T.Authorization memory a = _policyAuth(p, 0);
        vm.expectRevert(abi.encodeWithSelector(D.DelegationCapability.selector, grant, uint32(2)));
        _dc().recordDelegatedPolicyConsent(p, grant, a);
        _revoke(grant);
        grant = _grant(_delegation(0, 2, 1000, 2000, 0));
        p.collectionId = 2;
        a = _policyAuth(p, 0);
        vm.expectRevert(abi.encodeWithSelector(T.InvalidAttribution.selector, 2));
        _dc().recordDelegatedPolicyConsent(p, grant, a);
        _revoke(grant);
        uint32[3] memory forbiddenBits = [uint32(256), uint32(512), uint32(2048)];
        for (uint256 i; i < forbiddenBits.length; ++i) {
            D.Grant memory forbidden = _delegation(1, forbiddenBits[i], 1000, 2000, 0);
            T.Authorization memory principal = T.Authorization(
                IStreamArtistIdentityOwner(suite.owners[2]).identity(artistId).nonceHint, 0, ""
            );
            principal.signature = _signature(ingress.delegationGrantDigest(forbidden, principal));
            vm.expectRevert(abi.encodeWithSelector(T.UnsupportedProfile.selector));
            ingress.grantArtistDelegation(forbidden, principal);
        }
    }

    function testDelegateFutureStartWrongSafeDomainAndReplayPreserveAtomicState() public {
        _accept();
        _delegateSetup();
        bytes32 grant = _grant(_delegation(1, 2, 1100, 2000, 0));
        T.PolicyConsent memory p = _terms();
        T.Authorization memory a = _policyAuth(p, 0);
        bytes32 before_ = _roots();
        vm.expectRevert(abi.encodeWithSelector(D.DelegationUnavailable.selector, grant));
        _dc().recordDelegatedPolicyConsent(p, grant, a);
        require(_roots() == before_, "future grant no mutation");
        vm.warp(1100);
        a.signature = _signature(ingress.policyConsentDigest(p, a));
        vm.expectRevert(abi.encodeWithSelector(T.InvalidSignature.selector));
        _dc().recordDelegatedPolicyConsent(p, grant, a);
        a = _policyAuth(p, 0);
        _dc().recordDelegatedPolicyConsent(p, grant, a);
        bytes32 after_ = _roots();
        vm.expectRevert();
        _dc().recordDelegatedPolicyConsent(p, grant, a);
        require(
            _roots() == after_ && ingress.delegationRecord(grant).uses == 1,
            "persistent delegate nonce replay"
        );
    }

    function executeSavedDelegate(bytes calldata data) external {
        (bool ok, bytes memory result) = address(delegateSafe).call(data);
        if (!ok) assembly ("memory-safe") { revert(add(result, 32), mload(result)) }
        require(abi.decode(result, (bool)), "saved delegate Safe CALL");
    }

    function testLateArchiveFailureRollsBackUsesNonceRecordsAndIdenticalSignedSafeRetry() public {
        bytes32 grant = _readyPolicy(2, 1);
        T.PolicyConsent memory p = _terms();
        T.Authorization memory a = T.Authorization(0, type(uint64).max, "");
        bytes memory call_ =
            abi.encodeCall(
            IStreamArtistDelegatedConsent.recordDelegatedPolicyConsent, (p, grant, a)
        );
        uint256 nonce = delegateSafe.nonce();
        bytes memory signatures = safeThresholdSignature(
            delegateKeys,
            delegateSafe.getTransactionHash(
                address(ingress), 0, call_, 0, 0, 0, 0, address(0), address(0), nonce
            )
        );
        bytes memory saved = abi.encodeCall(
            OfficialSafe.execTransaction,
            (address(ingress), 0, call_, 0, 0, 0, 0, address(0), payable(address(0)), signatures)
        );
        bytes32 before_ = _roots();
        avm.mockCallRevert(
            address(archive),
            abi.encodeWithSelector(IStreamArtistArchiveV2.appendArtistEvidenceV2.selector),
            abi.encodeWithSelector(T.InvalidRecord.selector)
        );
        vm.expectRevert(abi.encodeWithSignature("Error(string)", "GS013"));
        this.executeSavedDelegate(saved);
        require(
            _roots() == before_ && delegateSafe.nonce() == nonce
                && ingress.delegationRecord(grant).uses == 0,
            "complete late rollback"
        );
        avm.clearMockedCalls();
        this.executeSavedDelegate(saved);
        require(
            delegateSafe.nonce() == nonce + 1 && ingress.delegationRecord(grant).uses == 1,
            "same signed Safe tx succeeds once"
        );
        bytes32 record = _literalPolicy(p, a);
        require(ingress.recordDelegation(record) == grant, "original direct record");
        require(
            _operationPayload(14, address(delegateSafe), record).length != 0,
            "original Safe actor archived"
        );
        ingress.requireMintConsent(1, PHASE, POLICY);
    }

    function testAuthorityRotationPreservesGrantAndAllowsFreshSaleConsentFromOriginalDelegate()
        public
    {
        Sale.Consent memory p = _saleFixture(1);
        _delegateSetup();
        bytes32 grant = _grant(_delegation(1, 1024, 1000, uint64(400 days), 0));
        _dc().recordDelegatedSaleConsent(p, grant, _saleAuth(p, 0));
        _newRotationSafe(94242);
        bytes32 rotation = _stageRotation(0);
        _executeTimedRotation(rotation);
        _requireSale(p);
        Sale.Consent memory next = _anotherSale(1002);
        _dc().recordDelegatedSaleConsent(next, grant, _saleAuth(next, 1));
        _requireSale(next);
        require(
            !ingress.delegationRecord(grant).revoked && ingress.delegationRecord(grant).uses == 2,
            "rotation preserves original delegate grant"
        );
    }

    function testEstateExecutionInvalidatesGrantEpochBeforeNewDelegatedPolicyOrSale() public {
        Sale.Consent memory p = _saleFixture(1);
        _delegateSetup();
        bytes32 grant = _grant(_delegation(1, 1026, 1000, uint64(400 days), 0));
        _dc().recordDelegatedSaleConsent(p, grant, _saleAuth(p, 0));
        Sale.Consent memory next = _anotherSale(1003);
        Estate.Execution memory execution = _estatePendingFixture(4095);
        (Estate.RequestRecord memory item,,) =
            ingress.estateActivationRecord(execution.expectedActivationRecordHash);
        vm.warp(item.noticeEndsAt);
        ingress.executeEstateActivation(execution);
        (bool active, uint64 recorded, uint64 current) =
            IStreamArtistEstateOwner(suite.owners[2]).delegationEpochState(grant);
        require(
            !active && recorded == 0 && current == 1, "actual estate epoch invalidates old grant"
        );
        T.Authorization memory saleA = _saleAuth(next, 1);
        T.PolicyConsent memory policy_ = T.PolicyConsent(1, PHASE, keccak256("estate new policy"));
        T.Authorization memory policyA = _policyAuth(policy_, 1);
        bytes32 before_ = _roots();
        vm.expectRevert(abi.encodeWithSelector(D.DelegationUnavailable.selector, grant));
        _dc().recordDelegatedPolicyConsent(policy_, grant, policyA);
        vm.expectRevert(abi.encodeWithSelector(D.DelegationUnavailable.selector, grant));
        _dc().recordDelegatedSaleConsent(next, grant, saleA);
        require(
            _roots() == before_ && ingress.delegationRecord(grant).uses == 1,
            "epoch refusal atomically preserves stored consent"
        );
    }

    function testModeTwoCannotBeSilentlyExportedByOriginalModeOneHydration() public {
        _accept();
        T.Binding memory b = IStreamArtistBindingOwner(suite.owners[0]).binding(1);
        AH.Query memory q;
        q.artistId = artistId;
        q.collectionId = 1;
        q.bindingHash = b.bindingHash;
        q.policies = new AH.PolicyKey[](0);
        q.records = new bytes32[](0);
        vm.expectRevert(abi.encodeWithSelector(T.UnsupportedProfile.selector));
        IStreamArtistAuthorityHydrationOwner(suite.owners[0]).authorityHydrationState(q);
    }
}
