// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "../helpers/StreamCurrentStackFixture.sol";
import "../helpers/OfficialSafeFixture.sol";
import "../../smart-contracts/domains/mint/StreamNativeFixedPriceSaleAdapter.sol";
import {
    StreamPrimarySaleSettlement
} from "../../smart-contracts/domains/revenue/StreamPrimarySaleSettlement.sol";
import "../../smart-contracts/interfaces/stream/artist/IStreamArtistDelegatedConsent.sol";

/// @notice Real current Core/Manager/Ledger/Artist/Registry/governance/recorder/native fixed sale, with separate threshold Safes.
/// @dev Only the inherited external entropy provider is substituted. Native acceptance and cold capacity are separate evidence.
contract StreamCurrentArtistDelegatedConsentTest is StreamCurrentStackFixture, OfficialSafeFixture {
    bytes32 private constant DELEGATED_PHASE = keccak256("ART42 delegated native phase");
    uint256 private constant PRICE = 1_000_000;
    OfficialSafe private principalSafe;
    OfficialSafe private delegateSafe;
    OfficialSafe private buyerSafe;
    uint256[] private keys;
    StreamPrimarySaleSettlement private recorder;
    StreamNativeFixedPriceSaleAdapter private nativeSale;
    bytes32 private grant;
    bytes32 private saleId;
    bytes32 private configHash;
    uint256 private delegateNonce;

    function setUp() public {
        keys.push(0x5AFE01);
        keys.push(0x5AFE02);
        SafeComponents memory components = deploySafeComponents("1.4.1");
        principalSafe = createOfficialSafe(components, safeOwnerAddresses(keys), 2, 4240);
        delegateSafe = createOfficialSafe(components, safeOwnerAddresses(keys), 2, 4241);
        buyerSafe = createOfficialSafe(components, safeOwnerAddresses(keys), 2, 4242);
        _deployCurrentStack(address(principalSafe), vm.addr(PLATFORM_KEY));
        vm.deal(address(buyerSafe), 1 ether);
    }

    function _artistProof(bytes32 digest) internal override returns (bytes memory) {
        return safeThresholdSignature(keys, safeMessageDigest(principalSafe, abi.encode(digest)));
    }

    function _delegateProof(bytes32 digest) private returns (bytes memory) {
        return safeThresholdSignature(keys, safeMessageDigest(delegateSafe, abi.encode(digest)));
    }

    function _dc() private view returns (IStreamArtistDelegatedConsent) {
        return IStreamArtistDelegatedConsent(address(artists));
    }

    function _deployAdditionalProducts() internal override {
        recorder = StreamPrimarySaleSettlement(
            payable(_artistArtifactCreate(
                    "smart-contracts/domains/revenue/StreamPrimarySaleSettlement.sol:StreamPrimarySaleSettlement",
                    abi.encode(primaryResolver, address(registry), revenueEscrow)
                ))
        );
        nativeSale = StreamNativeFixedPriceSaleAdapter(
            payable(_artistArtifactCreate(
                    "smart-contracts/domains/mint/StreamNativeFixedPriceSaleAdapter.sol:StreamNativeFixedPriceSaleAdapter",
                    abi.encode(
                        manager,
                        recorder,
                        vm.addr(PLATFORM_KEY),
                        IStreamArtistAttribution(address(artists)),
                        IStreamGasParameterHost.GasParameterConfig(
                            "REVEAL_ATTEMPT_GAS_LIMIT", 2_000_000, 50_000, 2
                        ),
                        IStreamNativeRefundDelegatedClaims.DelegationDeployment(
                            address(0),
                            0,
                            bytes32(0),
                            IStreamGasParameterHost.GasParameterConfig("", 0, 0, 0)
                        )
                    )
                ))
        );
        _assertDeployableProductionInstance(address(recorder));
        _assertDeployableProductionInstance(address(nativeSale));
    }

    function _configureAdditionalProducts() internal override {
        _admitNative();
        D.Grant memory p = D.Grant(
            fixtureArtistId,
            address(delegateSafe),
            1,
            1026,
            uint64(block.timestamp),
            uint64(block.timestamp + 400 days),
            3,
            keccak256("ART42 grant")
        );
        T.Authorization memory a = _artistAuthorization(false);
        a.time = 0;
        a.signature = _artistProof(artists.delegationGrantDigest(p, a));
        grant = artists.grantArtistDelegation(p, a);
        IStreamMintManager.MintPhaseConfig memory config = IStreamMintManager.MintPhaseConfig(
            false, 0, 0, 1, keccak256("ART42 terms"), keccak256("ART42 metadata")
        );
        IStreamMintManager.MintGateConfig memory gate;
        bytes32[] memory ids = new bytes32[](0);
        IStreamMintManager.MintCounterConfig[] memory counters =
            new IStreamMintManager.MintCounterConfig[](0);
        address[] memory enabled = new address[](0);
        _recordPolicy(
            manager.previewPhasePolicyHash(1, DELEGATED_PHASE, config, gate, ids, counters, enabled)
        );
        manager.configurePhase(1, DELEGATED_PHASE, config, gate, ids, counters);
        enabled = new address[](1);
        enabled[0] = address(nativeSale);
        _recordPolicy(
            manager.previewPhasePolicyHash(1, DELEGATED_PHASE, config, gate, ids, counters, enabled)
        );
        manager.setPhaseExecutor(1, DELEGATED_PHASE, address(nativeSale), true);
        saleId = nativeSale.registerSale(
            IStreamNativeFixedPriceSaleAdapter.SaleConfig(
                1,
                DELEGATED_PHASE,
                PRICE,
                0,
                type(uint64).max,
                manager.phasePolicyHash(1, DELEGATED_PHASE),
                primaryResolver.resolvePrimaryAssignment(1, 0, PRIMARY_REVENUE_CLASS).assignmentHash
            )
        );
        configHash = nativeSale.saleRecord(saleId).configHash;
    }

    function _recordPolicy(bytes32 hash) private {
        T.PolicyConsent memory p = T.PolicyConsent(1, DELEGATED_PHASE, hash);
        T.Authorization memory a = T.Authorization(delegateNonce++, type(uint64).max, "");
        a.signature = _delegateProof(artists.policyConsentDigest(p, a));
        bytes32 record = _dc().recordDelegatedPolicyConsent(p, grant, a);
        require(artists.recordDelegation(record) == grant, "actual policy retained grant");
    }

    function _recordSale() private returns (bytes32 record) {
        Sale.Consent memory p = Sale.Consent(1, address(nativeSale), saleId, configHash);
        T.Authorization memory a = T.Authorization(delegateNonce++, type(uint64).max, "");
        a.signature = _delegateProof(artists.saleConsentDigest(p, a));
        record = _dc().recordDelegatedSaleConsent(p, grant, a);
        require(artists.recordDelegation(record) == grant, "actual sale retained grant");
    }

    function _admitNative() private {
        StreamModuleRegistration[] memory records = new StreamModuleRegistration[](2);
        records[0] = StreamModuleRegistration(
            address(recorder),
            keccak256("PRIMARY_SALE_SETTLEMENT"),
            keccak256("6529STREAM_UNIVERSAL_SETTLEMENT_V1"),
            type(IStreamNativePrimarySaleSettlement).interfaceId,
            500_000,
            address(recorder).codehash,
            DEPLOYMENT_HASH,
            keccak256("ART42 recorder manifest"),
            "urn:stream:art42:recorder"
        );
        records[1] = StreamModuleRegistration(
            address(nativeSale),
            keccak256("NATIVE_PRIMARY_SALE_ADAPTER"),
            keccak256("6529STREAM_UNIVERSAL_SETTLEMENT_V1"),
            type(IStreamNativeSaleBinding).interfaceId,
            500_000,
            address(nativeSale).codehash,
            DEPLOYMENT_HASH,
            keccak256("ART42 sale manifest"),
            "urn:stream:art42:sale"
        );
        (GovernanceCall[] memory registration, bytes[] memory data) =
            StreamCurrentStackPlan.registrationCalls(registry, records);
        GovernanceCall[] memory calls = new GovernanceCall[](3);
        bytes[] memory payloads = new bytes[](3);
        for (uint256 i; i < 2; ++i) {
            calls[i] = registration[i];
            payloads[i] = data[i];
        }
        (bytes32 scope, bytes32 oldHash, bytes32 newHash) =
            revenueEscrow.creditProducerTransitionHashes(address(recorder), true);
        payloads[2] = abi.encodeCall(revenueEscrow.setCreditProducer, (address(recorder), true));
        calls[2] =
            StreamCurrentStackPlan.call(
            address(revenueEscrow), payloads[2], scope, oldHash, newHash
        );
        (scope, oldHash, newHash) = StreamGovernanceBootstrap.deriveBatchTransitionHashes(
            calls, StreamGovernanceBootstrap.governanceCallsHash(calls)
        );
        uint64 ready = uint64(block.timestamp + executor.minimumDelay(1));
        executor.publishGovernanceCallData(payloads);
        bytes memory scheduled = governanceRoot.execute(
            address(executor),
            0,
            abi.encodeCall(
                executor.scheduleGovernanceBatch,
                (
                    uint8(1),
                    calls,
                    scope,
                    oldHash,
                    newHash,
                    ready,
                    ready + 7 days,
                    keccak256("ART42 native admission"),
                    "urn:stream:art42:admission",
                    DEPLOYMENT_HASH
                )
            )
        );
        vm.warp(ready);
        executor.executeGovernanceBatch(abi.decode(scheduled, (bytes32)), calls, payloads);
    }

    function _execution()
        private
        returns (IStreamNativeFixedPriceSaleAdapter.SaleExecutionData memory e)
    {
        e.authorization = IStreamNativeFixedPriceSaleAdapter.SaleAuthorization(
            saleId,
            configHash,
            address(buyerSafe),
            address(buyerSafe),
            address(buyerSafe),
            address(principalSafe),
            keccak256(TOKEN_DATA),
            keccak256("ART42 mint commitment"),
            1,
            keccak256("ART42 purchase"),
            type(uint64).max,
            bytes32(0)
        );
        e.authorization.expectedPrimaryPolicyHash = StreamSaleTemplate.policyHash(
            primaryResolver, 1, StreamNativeSettlementSupport.rights(primaryResolver, 1)
        );
        e.tokenData = TOKEN_DATA;
        bytes32 digest = nativeSale.authorizationDigest(e.authorization);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(PLATFORM_KEY, digest);
        e.platformSignature = abi.encodePacked(r, s, v);
        e.artistSignature = _artistProof(digest);
    }

    function _savedPurchase(IStreamNativeFixedPriceSaleAdapter.SaleExecutionData memory e)
        private
        returns (bytes memory)
    {
        bytes memory data = abi.encodeCall(nativeSale.purchase, (e));
        bytes32 digest = buyerSafe.getTransactionHash(
            address(nativeSale), PRICE, data, 0, 0, 0, 0, address(0), address(0), buyerSafe.nonce()
        );
        return abi.encodeCall(
            buyerSafe.execTransaction,
            (
                address(nativeSale),
                PRICE,
                data,
                uint8(0),
                0,
                0,
                0,
                address(0),
                payable(address(0)),
                safeThresholdSignature(keys, digest)
            )
        );
    }

    function _assertPaid(bytes memory saved, uint256 oldBalance) private {
        (bool ok, bytes memory result) = address(buyerSafe).call(saved);
        require(ok && abi.decode(result, (bool)), "original signed buyer Safe CALL");
        require(
            core.ownerOf(1) == address(buyerSafe) && core.collectionMintedEver(1) == 1,
            "actual current NFT acquired"
        );
        require(
            buyerSafe.nonce() == 1 && address(buyerSafe).balance == oldBalance - PRICE
                && wallet.balance == PRICE,
            "payer and full official revenue conserved"
        );
        require(
            artists.delegationRecord(grant).uses == 3 && manager.nextOperationNonce() == 1,
            "no extra consent use at mint"
        );
        require(core.coordinatorAtMint(1) == address(entropy), "original entropy anchor");
        (address receiver, uint256 amount) = core.royaltyInfo(1, 10_000);
        require(receiver == wallet && amount == 690, "actual original royalty consumer");
    }

    function testActualCurrentMintConsumesRecordedPolicyAndSaleAfterGrantExhaustion() public {
        _recordSale();
        IStreamNativeFixedPriceSaleAdapter.SaleExecutionData memory e = _execution();
        _assertPaid(_savedPurchase(e), address(buyerSafe).balance);
    }

    function testActualCurrentMintKeepsExactConsentsAfterGrantRevocation() public {
        _recordSale();
        D.Revocation memory p = D.Revocation(
            fixtureArtistId, address(delegateSafe), grant, keccak256("stop new consents")
        );
        T.Authorization memory a = _artistAuthorization(false);
        a.signature = _artistProof(artists.delegationRevocationDigest(p, a));
        artists.revokeArtistDelegation(p, a);
        IStreamNativeFixedPriceSaleAdapter.SaleExecutionData memory e = _execution();
        _assertPaid(_savedPurchase(e), address(buyerSafe).balance);
    }

    function testActualCurrentMintKeepsExactConsentsAfterGrantExpiry() public {
        _recordSale();
        vm.warp(artists.delegationRecord(grant).grant.expiresAt);
        IStreamNativeFixedPriceSaleAdapter.SaleExecutionData memory e = _execution();
        _assertPaid(_savedPurchase(e), address(buyerSafe).balance);
    }

    function testMissingSaleConsentRollsBackOriginalSignedBuyerSafeThenExactRetry() public {
        IStreamNativeFixedPriceSaleAdapter.SaleExecutionData memory e = _execution();
        bytes memory saved = _savedPurchase(e);
        uint256 balance = address(buyerSafe).balance;
        (bool ok, bytes memory reason) = address(buyerSafe).call(saved);
        require(
            !ok
                && keccak256(reason)
                    == keccak256(abi.encodeWithSignature("Error(string)", "GS013")),
            "missing exact sale consent denies actual Safe"
        );
        require(
            buyerSafe.nonce() == 0 && address(buyerSafe).balance == balance
                && core.totalSupply() == 0 && manager.nextOperationNonce() == 0
                && wallet.balance == 0,
            "whole current sale rolls back"
        );
        require(
            artists.delegationRecord(grant).uses == 2
                && !nativeSale.authorizationUsed(address(principalSafe), e.authorization.nonce),
            "grant and sale replay unchanged"
        );
        _recordSale();
        _assertPaid(saved, balance);
    }

    function _onboardFixtureArtist(address artist_) internal override {
        bytes memory document = bytes("current-stack artist identity");
        T.BindingProposal memory p;
        p.artistAddress = artist_;
        p.identityRecordHash = keccak256(document);
        p.identityRecordURI = "urn:6529stream:fixture:artist-identity";
        p.consentMode = 2;
        p.saleConsentScope = 1;
        p.collaborators = new T.CollaboratorRecord[](0);
        p.capabilityPolicyOverrides = new T.CapabilityPolicyOverride[](0);
        (fixtureArtistId,) = artists.proposeArtistBinding(1, p, document, "Stream Artist");
        T.Authorization memory a = _artistAuthorization(false);
        a.signature = _artistProof(artists.acceptanceDigest(1, a));
        artists.acceptArtistBinding(1, a);
        T.PayoutDesignation memory payout =
            T.PayoutDesignation(fixtureArtistId, artist_, bytes32(0));
        a = _artistAuthorization(true);
        a.signature = _artistProof(artists.payoutDesignationDigest(payout, a));
        artists.recordPayoutDesignation(payout, a);
        (T.AssignmentFact memory primary, T.AssignmentFact memory royalty) =
            artistCoordinator.reads().currentAssignments(1);
        _recordModeTwoEconomics(primary);
        _recordModeTwoEconomics(royalty);
        (, bytes32 contentState) = router.currentArtistContentState(1);
        T.Ratification memory ratification = T.Ratification(1, address(router), contentState);
        a = _artistAuthorization(false);
        a.signature = _artistProof(artists.contentRatificationDigest(ratification, a));
        artists.recordContentRatification(ratification, a);
        T.Binding memory binding_ = IStreamArtistBindingOwner(artistSuite.owners[0]).binding(1);
        bytes32 facts = StreamArtistHashes.deploymentFacts(
            StreamArtistHashes.Environment(
                block.chainid, address(artists), artistSuite.core, artistSuite.mintManager
            ),
            1,
            binding_
        );
        _recordModeTwoAttestation(
            9,
            bytes32(uint256(uint160(artistSuite.core))),
            facts,
            keccak256("6529STREAM_ARTIST_DEPLOYMENT_ATTESTATION_V1")
        );
        _recordModeTwoAttestation(
            10,
            fixtureArtistId,
            binding_.identityRecordHash,
            keccak256("6529STREAM_ARTIST_PERSONHOOD_WAIVER_V1")
        );
    }

    function _recordModeTwoEconomics(T.AssignmentFact memory fact) private {
        T.EconomicsConsent memory p = T.EconomicsConsent(
            1, fact.resolver, fact.revenueClass, fact.scope, fact.scopeId, fact.assignmentHash
        );
        T.Authorization memory a = _artistAuthorization(false);
        a.signature = _artistProof(artists.economicsConsentDigest(p, a));
        artists.recordEconomicsConsent(p, a);
    }

    function _recordModeTwoAttestation(uint8 kind, bytes32 subject, bytes32 state, bytes32 schema)
        private
    {
        bytes memory statement = abi.encode(kind, subject, state, schema);
        T.Attestation memory p = T.Attestation(
            1,
            kind,
            subject,
            state,
            schema,
            keccak256(statement),
            "urn:6529stream:fixture:statement"
        );
        T.Authorization memory a = _artistAuthorization(true);
        a.signature = _artistProof(artists.attestationDigest(p, a));
        artists.recordArtistAttestation(p, a, statement);
    }
}
