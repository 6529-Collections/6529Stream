// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../helpers/CurrentCommerceConservationFixture.sol";
import {
    StreamNativeImmediateSales
} from "../../smart-contracts/domains/mint/StreamNativeImmediateSales.sol";
import {
    StreamPrimarySaleSettlement
} from "../../smart-contracts/domains/revenue/StreamPrimarySaleSettlement.sol";
import {
    IStreamPrivateSaleAdapter
} from "../../smart-contracts/interfaces/stream/mint/IStreamPrivateSaleAdapter.sol";
import {
    IStreamNativeSaleBinding
} from "../../smart-contracts/interfaces/stream/revenue/IStreamNativeSaleBinding.sol";
import {
    IStreamNativeImmediateSales as Immediate
} from "../../smart-contracts/interfaces/stream/mint/IStreamNativeImmediateSales.sol";
import {
    StreamPrivateSaleTypes as Sales
} from "../../smart-contracts/interfaces/stream/mint/StreamPrivateSaleTypes.sol";
import {
    StreamNativeSettlementTypes as Native
} from "../../smart-contracts/interfaces/stream/revenue/StreamNativeSettlementTypes.sol";
import {
    StreamPrimarySettlementTypes as Settlement
} from "../../smart-contracts/interfaces/stream/revenue/StreamPrimarySettlementTypes.sol";
import {
    StreamArtistSaleTypes as SaleConsent
} from "../../smart-contracts/interfaces/stream/artist/StreamArtistSaleTypes.sol";

/// @notice Canonical signed and unsigned purchases through actual current products and threshold Safes.
/// @dev Only the upstream entropy provider is a test double. Coordinator, Artist, governance,
/// Core, Metadata, Manager, Ledger, recorder and permanent WAIVED Floor retain actual code.
/// WAIVED is explicit and supplies no documentary evidence. These aggregate scenarios do not
/// establish cold transaction gas capacity, other rights profiles or public randomness security.
contract CurrentNativeImmediateSalesTest is CurrentCommerceConservationFixture {
    bytes32 private constant IMMEDIATE_PHASE = keccak256("current canonical immediate phase");
    uint256 private constant PRICE = 1000;
    uint256 private constant REVEAL_FEE = 100;
    uint256 private constant PAYMENT = PRICE + REVEAL_FEE;
    StreamNativeImmediateSales private immediate;
    StreamPrimarySaleSettlement private recorder;
    OfficialSafe private artistSafe;
    OfficialSafe private payerSafe;
    uint256[] private artistKeys;
    uint256[] private payerKeys;

    function setUp() public {
        artistKeys.push(0x1AA01);
        artistKeys.push(0x1AA02);
        payerKeys.push(0x1BB01);
        payerKeys.push(0x1BB02);
        SafeComponents memory components = deploySafeComponents("1.4.1");
        artistSafe = createOfficialSafe(components, safeOwnerAddresses(artistKeys), 2, 901);
        payerSafe = createOfficialSafe(components, safeOwnerAddresses(payerKeys), 2, 902);
        vm.deal(address(payerSafe), 1 ether);
        this.deployImmediateScenario();
    }

    /// @dev Fresh frames keep observations after governance warps explicit under via-IR.
    function immediateScenarioTime() external view returns (uint64) {
        return uint64(block.timestamp);
    }

    function deployImmediateScenario() external {
        require(msg.sender == address(this), "fixture caller");
        _deployCurrentStack(address(artistSafe), vm.addr(PLATFORM_KEY));
        uint256[] memory keys = new uint256[](2);
        keys[0] = 0x1CC01;
        keys[1] = 0x1CC02;
        OfficialSafe governor =
            createOfficialSafe(deploySafeComponents("1.4.1"), safeOwnerAddresses(keys), 2, 903);
        _installGovernorSafe(governor, keys);
        _prepareCommerceFloor();
        _bindCommerceFloor();
        // Every test chooses when the real Metadata declaration is executed.
        require(core.declaredConservationTier(1) == 0, "no implicit waiver");
    }

    function _fixtureSaleConsentScope() internal pure override returns (uint8) {
        return 1;
    }

    function _artistProof(bytes32 digest) internal override returns (bytes memory) {
        return safeThresholdSignature(artistKeys, safeMessageDigest(artistSafe, abi.encode(digest)));
    }

    function _revealPrincipals()
        internal
        view
        override
        returns (StreamRevealActivationPlan.Principals memory)
    {
        return StreamRevealActivationPlan.Principals(
            address(this), address(payerSafe), address(governanceRoot)
        );
    }

    function _configureInitialRevealPolicy() internal override {
        // Manual ASYNC: purchase funds the real escrow; a separate actual Safe requests later.
        entropy.configureCollectionRevealPolicy(
            1, 1, keccak256("ROLE_ENTROPY_REVEAL_OWNER"), 100, REVEAL_FEE
        );
        provider.setFee(REVEAL_FEE);
    }

    function _deployAdditionalProducts() internal override {
        recorder = StreamPrimarySaleSettlement(
            _artistArtifactCreate(
                "smart-contracts/domains/revenue/StreamPrimarySaleSettlement.sol:StreamPrimarySaleSettlement",
                abi.encode(primaryResolver, address(registry), revenueEscrow)
            )
        );
        StreamNativeImmediateSales.DeploymentConfig memory d;
        d.manager = manager;
        d.recorder = recorder;
        d.artists = IStreamArtistAttribution(address(artists));
        d.roles = roles;
        d.authority = address(executor);
        d.parameters[0] = IStreamGasParameterHost.GasParameterConfig(
            "SALE_ERC1271_GAS_LIMIT", 400_000, 350_000, 2
        );
        d.parameters[1] = IStreamGasParameterHost.GasParameterConfig(
            "SALE_ARTIST_AUTHORITY_GAS_LIMIT", 600_000, 100_000, 2
        );
        d.parameters[2] = IStreamGasParameterHost.GasParameterConfig(
            "REVEAL_ATTEMPT_GAS_LIMIT", 2_000_000, 50_000, 2
        );
        immediate = StreamNativeImmediateSales(
            payable(_artistArtifactCreate(
                    "smart-contracts/domains/mint/StreamNativeImmediateSales.sol:StreamNativeImmediateSales",
                    abi.encode(d)
                ))
        );
        _assertDeployableProductionInstance(address(recorder));
        _assertDeployableProductionInstance(address(immediate));
    }

    function _additionalEscrowProducers() internal view override returns (address[] memory rows) {
        rows = new address[](1);
        rows[0] = address(recorder);
    }

    function _additionalOperatingPolicies()
        internal
        view
        override
        returns (GovernanceActionPolicyEntry[] memory rows)
    {
        rows = new GovernanceActionPolicyEntry[](2);
        rows[0] = _immediatePolicy(immediate.configureCollectionSigner.selector);
        rows[1] = _immediatePolicy(immediate.registerSale.selector);
        rows = _commerceFloorPolicies(rows);
    }

    function _immediatePolicy(bytes4 selector)
        private
        view
        returns (GovernanceActionPolicyEntry memory)
    {
        return GovernanceActionPolicyEntry(
            1,
            address(immediate),
            selector,
            address(immediate).codehash,
            keccak256(abi.encode(DEPLOYMENT_HASH, address(immediate))),
            1,
            0,
            0,
            0
        );
    }

    function _configureAdditionalProducts() internal override {
        this.admitImmediate();
        _configureMintPhase(IMMEDIATE_PHASE, address(immediate));
        immediate.transferOwnership(address(executor));
    }

    function admitImmediate() external {
        require(msg.sender == address(this), "fixture caller");
        StreamModuleRegistration[] memory records = new StreamModuleRegistration[](1);
        records[0] = StreamModuleRegistration(
            address(immediate),
            keccak256("NATIVE_PRIMARY_SALE_ADAPTER"),
            keccak256("6529STREAM_UNIVERSAL_SETTLEMENT_V1"),
            type(IStreamNativeSaleBinding).interfaceId,
            500_000,
            address(immediate).codehash,
            DEPLOYMENT_HASH,
            keccak256("current canonical immediate module"),
            "urn:stream:current:canonical-immediate"
        );
        (GovernanceCall[] memory calls, bytes[] memory data) =
            StreamCurrentStackPlan.registrationCalls(registry, records);
        (bytes32 scope, bytes32 before_, bytes32 after_) = StreamGovernanceBootstrap.deriveBatchTransitionHashes(
            calls, StreamGovernanceBootstrap.governanceCallsHash(calls)
        );
        uint64 ready = this.immediateScenarioTime() + 48 hours;
        executor.publishGovernanceCallData(data);
        bytes memory scheduled = governanceRoot.execute(
            address(executor),
            0,
            abi.encodeCall(
                executor.scheduleGovernanceBatch,
                (
                    uint8(1),
                    calls,
                    scope,
                    before_,
                    after_,
                    ready,
                    ready + 7 days,
                    keccak256("current immediate admission"),
                    "urn:stream:current:immediate-admission",
                    DEPLOYMENT_HASH
                )
            )
        );
        vm.warp(ready);
        executor.executeGovernanceBatch(abi.decode(scheduled, (bytes32)), calls, data);
        StreamModuleRecord memory record = registry.moduleRecord(address(immediate));
        require(
            record.status == ModuleRegistryStatus.ACTIVE
                && record.runtimeCodeHash == address(immediate).codehash,
            "actual delayed module admission"
        );
    }

    function governImmediate(bytes calldata data) external {
        require(msg.sender == address(this), "fixture caller");
        _govern(_governanceRequest(1, address(immediate), data, 0, 0, 0));
    }

    function testActualSafeCanonicalSignedFixedSaleConsentRevenueFloorAndReplay() public {
        _declareWaivedCommerce();
        bytes32 saleId = _register(1, 0);
        Immediate.Purchase memory p = _purchase(saleId, 1);
        Sales.SaleAuthorization memory a = _authorization(p, 71);
        IStreamPrivateSaleAdapter.Signature memory proof = _saleProof(a);
        bytes32 digest = _literalDigest(a);
        require(immediate.authorizationDigest(a) == digest, "original literal Sales-v1 digest");
        Native.NativeSettlementCandidate memory candidate =
            immediate.previewSignedPurchase(p, a, proof);
        bytes32 auth = _authorizationId(digest);
        bytes memory callData = abi.encodeCall(immediate.purchaseSigned, (p, a, proof));
        uint256 before_ = address(payerSafe).balance;
        uint256 operationNonce = manager.nextOperationNonce();
        bytes memory saved = _signedSafeCall(callData);
        _executeSaved(saved);
        Immediate.Receipt memory receipt =
            immediate.executionReceipt(candidate.executionBinding.executionId);
        _assertReceipt(p, candidate, receipt, auth, digest);
        _assertBalances(before_, 1);
        require(
            manager.nextOperationNonce() == operationNonce + 1 && _supply() == 1,
            "one real mint and counter"
        );

        bytes32 state = _purchaseState(p, candidate, auth);
        (bool replay,) = address(payerSafe).call(saved);
        require(
            !replay && _purchaseState(p, candidate, auth) == state,
            "exact Safe transaction cannot replay"
        );
        // A fresh Safe nonce and adapter execution nonce cannot restore a consumed Sales authorization.
        p.executionNonce = immediate.nextExecutionNonce(saleId, address(payerSafe));
        bytes memory duplicate =
            _signedSafeCall(abi.encodeCall(immediate.purchaseSigned, (p, a, proof)));
        (replay,) = address(payerSafe).call(duplicate);
        require(
            !replay && _purchaseState(p, candidate, auth) == state,
            "Ledger replay survives fresh execution nonce"
        );
        _requestAndFulfill(receipt.tokenId);
    }

    function testActualSafeUnsignedOpenSalesHaveDistinctLedgerIdsAndOneFirstSale() public {
        _declareWaivedCommerce();
        bytes32 saleId = _register(2, 1);
        uint256 before_ = address(payerSafe).balance;
        bytes32 firstAuthorization;
        bytes32 firstReceipt;
        uint256 operationNonce = manager.nextOperationNonce();
        for (uint256 i; i < 2; ++i) {
            Immediate.Purchase memory p = _purchase(saleId, 20 + i);
            (Native.NativeSettlementCandidate memory candidate, bytes32 auth) =
                immediate.previewPublicPurchase(p);
            require(
                candidate.executionBinding.authorityMode == 2
                    && candidate.executionBinding.saleAuthorizationDigest == 0,
                "genuine public record without Sales signature"
            );
            require(auth == _publicAuthorizationId(p), "independent public Ledger identity");
            _executeSaved(_signedSafeCall(abi.encodeCall(immediate.purchasePublic, (p))));
            Immediate.Receipt memory receipt =
                immediate.executionReceipt(candidate.executionBinding.executionId);
            _assertReceipt(p, candidate, receipt, auth, 0);
            bytes32 observed =
                commerceFloor.settlementReceipt(receipt.settlementKey).firstSaleReceiptHash;
            if (i == 0) {
                firstAuthorization = auth;
                firstReceipt = observed;
            } else {
                require(
                    auth != firstAuthorization && observed == firstReceipt,
                    "new request retains permanent first sale"
                );
            }
            require(
                immediate.activePublicNativeCandidate(candidate.executionBinding.executionId) == 0,
                "temporary public recording authority cleared"
            );
        }
        _assertBalances(before_, 2);
        require(
            immediate.saleRecord(saleId).soldQuantity == 2 && !immediate.saleRecord(saleId).closed
                && manager.nextOperationNonce() == operationNonce + 2 && _supply() == 2,
            "open sale still obeys actual Manager counter"
        );
    }

    function testActualMissingFloorWaiverRollsBackAndIdenticalSignedSafePayloadRetries() public {
        bytes32 saleId = _register(1, 0);
        Immediate.Purchase memory p = _purchase(saleId, 30);
        Sales.SaleAuthorization memory a = _authorization(p, 73);
        IStreamPrivateSaleAdapter.Signature memory proof = _saleProof(a);
        Native.NativeSettlementCandidate memory candidate =
            immediate.previewSignedPurchase(p, a, proof);
        bytes32 auth = _authorizationId(_literalDigest(a));
        bytes memory saved =
            _signedSafeCall(abi.encodeCall(immediate.purchaseSigned, (p, a, proof)));
        bytes32 before_ = _purchaseState(p, candidate, auth);
        (bool ok, bytes memory reason) = address(payerSafe).call(saved);
        require(
            !ok
                && keccak256(reason)
                    == keccak256(abi.encodeWithSignature("Error(string)", "GS013")),
            "actual Safe surfaces failed floor transaction"
        );
        require(
            _purchaseState(p, candidate, auth) == before_,
            "all sale/payment/mint/entropy/Safe state rolls back"
        );
        _assertNoCommerceFloorReceipt(
            recorder.settlementKey(address(immediate), candidate.executionBinding.executionId)
        );
        require(core.declaredConservationTier(1) == 0, "failed payment cannot declare waiver");
        _declareWaivedCommerce();
        uint256 payerBefore = address(payerSafe).balance;
        _executeSaved(saved);
        Immediate.Receipt memory receipt =
            immediate.executionReceipt(candidate.executionBinding.executionId);
        _assertReceipt(p, candidate, receipt, auth, _literalDigest(a));
        _assertBalances(payerBefore, 1);
        require(_supply() == 1, "identical saved bytes mint once after explicit evidence");
    }

    function _register(uint8 mode, uint8 kind) private returns (bytes32 id) {
        Immediate.Configuration memory c;
        c.collectionId = 1;
        c.phaseId = IMMEDIATE_PHASE;
        c.saleKind = kind;
        c.authorityMode = mode;
        c.unitPrice = PRICE;
        c.endsAt = this.immediateScenarioTime() + 30 days;
        c.saleSupplyLimit = kind == 0 ? 4 : 0;
        c.mintPolicyHash = manager.phasePolicyHash(1, IMMEDIATE_PHASE);
        c.expectedPrimaryPolicyHash = _nativePrimaryPolicyHash();
        if (mode == 1) {
            this.governImmediate(
                abi.encodeCall(
                    immediate.configureCollectionSigner,
                    (
                        uint256(1),
                        address(artistSafe),
                        uint8(2),
                        keccak256("current immutable signer evidence"),
                        true
                    )
                )
            );
            bool enabled;
            (c.signer, enabled) = immediate.collectionSigner(1, address(artistSafe), 2);
            require(
                enabled && c.signer.installingAuthority == address(executor),
                "actual governed signer installation"
            );
        }
        id = immediate.saleIdFor(1, IMMEDIATE_PHASE, immediate.nextSaleNonce());
        this.governImmediate(abi.encodeCall(immediate.registerSale, (c)));
        Immediate.Record memory record = immediate.saleRecord(id);
        require(
            keccak256(abi.encode(record.config)) == keccak256(abi.encode(c))
                && record.configHash != 0,
            "actual immutable sale registration"
        );
        require(artists.saleConsentScope(1) == 1, "actual immutable REQUIRED sale-consent election");
        SaleConsent.Consent memory terms =
            SaleConsent.Consent(1, address(immediate), id, record.configHash);
        T.Authorization memory authorization = T.Authorization(
            IStreamArtistAuthorizationRevocation(address(artists))
            .artistAuthorizationState(fixtureArtistId, 0, 0)
            .nextUnusedNonce,
            this.immediateScenarioTime() + 1 days,
            ""
        );
        require(
            executeSafe(
                artistSafe,
                artistKeys,
                address(artists),
                0,
                abi.encodeCall(
                    IStreamArtistSaleAuthority.recordSaleConsent, (terms, authorization)
                ),
                0
            ),
            "Artist Safe consents to exact sale"
        );
        (bool consented, bytes32 receipt) = artists.isSaleConsented(1, id, record.configHash);
        SaleConsent.Record memory consent = artists.saleConsentRecord(receipt);
        require(
            consented && consent.signer == address(artistSafe)
                && consent.artistId == fixtureArtistId
                && keccak256(abi.encode(consent.terms)) == keccak256(abi.encode(terms)),
            "actual permanent Artist sale record"
        );
    }

    function _purchase(bytes32 id, uint256 tag) private view returns (Immediate.Purchase memory p) {
        p.saleId = id;
        p.payer = address(payerSafe);
        p.executor = address(payerSafe);
        p.initialRecipient = address(payerSafe);
        p.beneficiary = SECOND_OWNER;
        p.tokenData = abi.encode(TOKEN_DATA, tag);
        p.mintCommitment = keccak256(abi.encode("current immediate commitment", tag));
        p.executionNonce = immediate.nextExecutionNonce(id, p.payer);
    }

    function _authorization(Immediate.Purchase memory p, uint256 nonce)
        private
        view
        returns (Sales.SaleAuthorization memory a)
    {
        Immediate.Configuration memory c = immediate.saleRecord(p.saleId).config;
        a.chainId = block.chainid;
        a.saleAdapter = address(immediate);
        a.mintManager = address(manager);
        a.collectionId = 1;
        a.phaseId = IMMEDIATE_PHASE;
        a.saleId = p.saleId;
        a.saleKind = c.saleKind;
        a.revenueClass = PRIMARY_REVENUE_CLASS;
        a.expectedPrimaryPolicyHash = c.expectedPrimaryPolicyHash;
        address[] memory recipients = new address[](1);
        recipients[0] = p.initialRecipient;
        address[] memory beneficiaries = new address[](1);
        beneficiaries[0] = p.beneficiary;
        bytes[] memory data = new bytes[](1);
        data[0] = p.tokenData;
        bytes32[] memory commitments = new bytes32[](1);
        commitments[0] = p.mintCommitment;
        a.initialRecipientsHash =
            keccak256(abi.encode(keccak256("6529STREAM_MINT_BATCH_RECIPIENTS_V1"), recipients));
        a.beneficiariesHash = keccak256(
            abi.encode(keccak256("6529STREAM_MINT_BATCH_BENEFICIARIES_V1"), beneficiaries)
        );
        a.tokenDataArrayHash =
            keccak256(abi.encode(keccak256("6529STREAM_MINT_BATCH_TOKEN_DATA_V1"), data));
        a.mintCommitmentsHash =
            keccak256(abi.encode(keccak256("6529STREAM_MINT_BATCH_COMMITMENTS_V1"), commitments));
        a.payer = p.payer;
        a.executor = p.executor;
        a.unitPrice = PRICE;
        a.quantity = 1;
        a.policyHash = c.mintPolicyHash;
        a.nonce = bytes32(nonce);
        a.deadline = this.immediateScenarioTime() + 1 days;
    }

    function _literalDigest(Sales.SaleAuthorization memory a) private view returns (bytes32) {
        bytes32 domain = keccak256(
            abi.encode(
                keccak256(
                    "EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"
                ),
                keccak256("6529Stream Sales"),
                keccak256("1"),
                block.chainid,
                address(immediate)
            )
        );
        bytes32 body = keccak256(
            abi.encode(
                keccak256(
                    "SaleAuthorization(uint256 chainId,address saleAdapter,address mintManager,uint256 collectionId,bytes32 phaseId,bytes32 saleId,uint8 saleKind,bytes32 revenueClass,bytes32 expectedPrimaryPolicyHash,uint8 primaryPolicyMode,bytes32 initialRecipientsHash,bytes32 beneficiariesHash,bytes32 tokenDataArrayHash,bytes32 mintCommitmentsHash,address payer,address executor,address asset,uint256 unitPrice,uint256 quantity,bytes32 contentSelectionHash,bytes32 policyHash,bytes32 nonce,uint64 deadline,uint64 finalizeBy)"
                ),
                a
            )
        );
        return keccak256(abi.encodePacked(hex"1901", domain, body));
    }

    function _authorizationId(bytes32 digest) private pure returns (bytes32) {
        return keccak256(abi.encode(keccak256("6529STREAM_MINT_TICKET_AUTHORIZATION_V1"), digest));
    }

    function _publicAuthorizationId(Immediate.Purchase memory p) private view returns (bytes32) {
        bytes32 configHash = immediate.saleRecord(p.saleId).configHash;
        bytes32 request = keccak256(
            abi.encode(
                keccak256("6529STREAM_NATIVE_IMMEDIATE_SALES_REQUEST_V1"),
                block.chainid,
                address(immediate),
                configHash,
                p
            )
        );
        return keccak256(
            abi.encode(
                keccak256("6529STREAM_NATIVE_PUBLIC_MINT_AUTHORIZATION_V1"),
                block.chainid,
                address(immediate),
                address(manager),
                configHash,
                request
            )
        );
    }

    function _saleProof(Sales.SaleAuthorization memory a)
        private
        returns (IStreamPrivateSaleAdapter.Signature memory)
    {
        return IStreamPrivateSaleAdapter.Signature(
            address(artistSafe),
            2,
            safeThresholdSignature(
                artistKeys, safeMessageDigest(artistSafe, abi.encode(_literalDigest(a)))
            )
        );
    }

    function _signedSafeCall(bytes memory data) private returns (bytes memory) {
        bytes memory signatures = safeThresholdSignature(
            payerKeys,
            payerSafe.getTransactionHash(
                address(immediate),
                PAYMENT,
                data,
                0,
                0,
                0,
                0,
                address(0),
                address(0),
                payerSafe.nonce()
            )
        );
        return abi.encodeCall(
            payerSafe.execTransaction,
            (
                address(immediate),
                PAYMENT,
                data,
                uint8(0),
                0,
                0,
                0,
                address(0),
                payable(address(0)),
                signatures
            )
        );
    }

    function _executeSaved(bytes memory callData) private {
        (bool ok, bytes memory result) = address(payerSafe).call(callData);
        require(
            ok && result.length == 32 && abi.decode(result, (bool)), "actual threshold Safe CALL"
        );
    }

    function _assertReceipt(
        Immediate.Purchase memory p,
        Native.NativeSettlementCandidate memory c,
        Immediate.Receipt memory r,
        bytes32 auth,
        bytes32 digest
    ) private view {
        require(
            r.saleId == p.saleId && r.executionId == c.executionBinding.executionId
                && r.authorizationId == auth && r.saleAuthorizationDigest == digest
                && r.operationRoot == c.operationIdentityCommitment
                && r.operationId == c.operationId && r.tokenId != 0 && r.chargedAmount == PRICE
                && r.revealFee == REVEAL_FEE && r.revealCredit == 0,
            "exact singleton purchase receipt"
        );
        require(
            immediate.executionStatus(r.executionId) == 2
                && core.ownerOf(r.tokenId) == address(payerSafe)
                && core.coordinatorAtMint(r.tokenId) == address(entropy)
                && c.sale.beneficiary == SECOND_OWNER,
            "actual owner distinct from bound beneficiary, coordinator retained"
        );
        require(
            ledger.isManagerAuthorizationUsed(address(manager), auth)
                && ledger.isManagerOperationRootUsed(address(manager), r.operationRoot),
            "actual Ledger authority and operation replay"
        );
        Settlement.PrimarySettlementResult memory result =
            recorder.settlementResult(r.settlementKey);
        require(
            recorder.settlementConsumed(r.settlementKey) && result.settlementKey == r.settlementKey
                && result.candidateCommitment
                    == keccak256(
                        abi.encode(
                            keccak256("6529STREAM_NATIVE_SETTLEMENT_CANDIDATE_V1"),
                            block.chainid,
                            address(recorder),
                            c
                        )
                    ) && result.profileId == profile && result.wallet == wallet
                && result.asset == address(0) && result.amount == PRICE
                && result.executor == address(payerSafe) && !result.escrowed
                && result.executionId == r.executionId
                && result.operationIdentityCommitment == r.operationRoot
                && result.currentPolicyHash == c.currentPolicyHash
                && result.boundPolicyHash == c.boundPolicyHash,
            "original official native result"
        );
        _assertWaivedCommerceReceipt(address(recorder), r.settlementKey);
        StreamConservationFloorTypes.SettlementReceipt memory floor =
            commerceFloor.settlementReceipt(r.settlementKey);
        require(
            floor.candidateCommitment == result.candidateCommitment
                && floor.resultHash == keccak256(abi.encode(result))
                && floor.releaseReceiptHash == 0 && commerceFloor.sourceCount() == 0
                && commerceFloor.firstSale(1).sourceId == 0
                && commerceFloor.firstSale(1).sourceSetHash == commerceFloor.sourceSetHashAt(0)
                && commerceFloor.sourceSetHashAt(0) != 0,
            "actual Floor binds full original result without invented documentary evidence"
        );
        require(
            commerceFloor.directPrimarySaleFloorReceipt(r.settlementKey).receiptHash == 0,
            "official payment does not create duplicate DIRECT receipt"
        );
    }

    function _assertBalances(uint256 payerBefore, uint256 count) private view {
        require(
            address(payerSafe).balance == payerBefore - count * PAYMENT
                && wallet.balance == count * PRICE
                && recorder.totalOfficialSettled(address(0)) == count * PRICE
                && revenueEscrow.totalOwed(address(0)) == 0,
            "actual native revenue conservation"
        );
        require(
            entropy.revealFeeEscrow(1) == count * REVEAL_FEE
                && address(entropy).balance == count * REVEAL_FEE && address(immediate).balance == 0
                && immediate.refundLiability() == 0 && provider.nextRequestId() == 1,
            "manual reveal escrow separated from price, no adapter residue"
        );
    }

    function _supply() private view returns (uint64) {
        bytes32 subject = manager.previewSubjectKey(
            IStreamMintManager.CounterKeyMode.CONSTANT,
            1,
            IMMEDIATE_PHASE,
            keccak256("supply"),
            address(payerSafe),
            address(payerSafe),
            address(immediate),
            address(0),
            0
        );
        return ledger.counterValue(
            manager.previewCounterValueKey(1, IMMEDIATE_PHASE, keccak256("supply"), subject)
        );
    }

    function _purchaseState(
        Immediate.Purchase memory p,
        Native.NativeSettlementCandidate memory c,
        bytes32 auth
    ) private view returns (bytes32) {
        bytes32 key = recorder.settlementKey(address(immediate), c.executionBinding.executionId);
        return keccak256(
            abi.encode(
                payerSafe.nonce(),
                address(payerSafe).balance,
                wallet.balance,
                address(immediate).balance,
                immediate.refundLiability(),
                immediate.executionStatus(c.executionBinding.executionId),
                immediate.executionReceipt(c.executionBinding.executionId),
                immediate.nextExecutionNonce(p.saleId, p.payer),
                immediate.saleRecord(p.saleId).soldQuantity,
                recorder.settlementConsumed(key),
                recorder.settlementResult(key),
                recorder.totalOfficialSettled(address(0)),
                revenueEscrow.totalOwed(address(0)),
                address(revenueEscrow).balance,
                commerceFloor.firstSale(1),
                commerceFloor.settlementReceipt(key),
                manager.nextOperationNonce(),
                ledger.isManagerAuthorizationUsed(address(manager), auth),
                ledger.isManagerOperationRootUsed(address(manager), c.operationIdentityCommitment),
                core.collectionMintedEver(1),
                _supply(),
                entropy.revealFeeEscrow(1),
                address(entropy).balance,
                provider.nextRequestId()
            )
        );
    }

    function _requestAndFulfill(uint256 tokenId) private {
        require(
            executeSafe(
                payerSafe,
                payerKeys,
                address(entropy),
                0,
                abi.encodeCall(entropy.requestEntropy, (tokenId)),
                0
            ),
            "actual reveal-owner Safe request"
        );
        (,,,,, bytes32 requestKey, uint256 requestId,) = entropy.tokenEntropy(tokenId);
        require(
            requestKey != 0 && requestId == 1 && entropy.revealFeeEscrow(1) == 0
                && address(provider).balance == REVEAL_FEE,
            "actual Coordinator consumes escrow for upstream fee"
        );
        provider.fulfill(requestId, bytes32(0));
        (, bool finalized) = entropy.tokenSeed(tokenId);
        require(
            finalized && bytes(core.tokenURI(tokenId)).length != 0,
            "actual Coordinator and Metadata finish with upstream raw zero"
        );
    }
}
