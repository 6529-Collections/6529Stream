// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../helpers/CurrentCommerceConservationFixture.sol";
import {
    StreamNativeClaimSales
} from "../../smart-contracts/domains/mint/StreamNativeClaimSales.sol";
import {
    StreamPrimarySaleSettlement
} from "../../smart-contracts/domains/revenue/StreamPrimarySaleSettlement.sol";
import {
    IStreamPrimarySaleSettlement
} from "../../smart-contracts/interfaces/stream/revenue/IStreamPrimarySaleSettlement.sol";
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

import {
    IStreamNativeClaimSales as Claim
} from "../../smart-contracts/interfaces/stream/mint/IStreamNativeClaimSales.sol";
import {
    IStreamMintCounterPolicy
} from "../../smart-contracts/interfaces/stream/mint/IStreamMintCounterPolicy.sol";
import {
    IStreamMintImmediateSaleAuthorizationRevocation
} from "../../smart-contracts/interfaces/stream/mint/IStreamMintImmediateSaleAuthorizationRevocation.sol";
import {
    IStreamImmediateSaleReveal
} from "../../smart-contracts/interfaces/stream/mint/IStreamImmediateSaleReveal.sol";

interface CurrentClaimCallVm {
    function expectCall(address target, uint256 value, bytes calldata data, uint64 count) external;
}

/// @dev User receiver, not a replacement for any protocol product. A reverted callback cannot
/// retain its observation; the test also counts actual Core calls across failure and retry.
contract CurrentClaimReceiver {
    StreamCore private immutable core;
    StreamNativeClaimSales private immutable claims;
    StreamPrimarySaleSettlement private immutable recorder;
    StreamConservationFloor private immutable floor;
    address private immutable controller;
    bytes32 private executionId;
    bytes32 private settlementKey;
    bool public rejecting = true;
    uint256 public deliveries;
    uint256 public receivedToken;

    error DeliveryRejected();

    constructor(
        StreamCore c,
        StreamNativeClaimSales s,
        StreamPrimarySaleSettlement r,
        StreamConservationFloor f
    ) {
        core = c;
        claims = s;
        recorder = r;
        floor = f;
        controller = msg.sender;
    }

    function expectExecution(bytes32 id, bytes32 key) external {
        require(msg.sender == controller, "receiver controller");
        executionId = id;
        settlementKey = key;
    }

    function acceptDelivery() external {
        require(msg.sender == controller, "receiver controller");
        rejecting = false;
    }

    function onERC721Received(address, address, uint256 token, bytes calldata)
        external
        returns (bytes4)
    {
        require(
            msg.sender == address(core) && core.ownerOf(token) == address(this),
            "actual Core delivery"
        );
        require(
            claims.executionStatus(executionId) == 1, "claim remains in progress during delivery"
        );
        require(
            recorder.settlementConsumed(settlementKey) && floor.firstSale(1).receiptHash != 0,
            "official payment and permanent floor precede delivery"
        );
        ++deliveries;
        receivedToken = token;
        if (rejecting) revert DeliveryRejected();
        return this.onERC721Received.selector;
    }
}

/// @notice Canonical free and chosen-price purchases through actual current products and threshold Safes.
/// @dev Only the upstream entropy provider is a test double. Coordinator, Artist, governance,
/// Core, Metadata, Manager, Ledger, recorder and permanent WAIVED Floor retain actual code.
/// WAIVED is explicit and supplies no documentary evidence. These aggregate scenarios do not
/// establish cold transaction gas capacity, other rights profiles or public randomness security.
abstract contract StreamCurrentNativeClaimSalesFixture is CurrentCommerceConservationFixture {
    bytes32 internal constant CLAIM_PHASE = keccak256("current native claims phase");
    uint256 internal constant PRICE = 1000;
    uint256 internal constant REVEAL_FEE = 100;
    bytes32 internal constant MERKLE_PHASE = keccak256("current claim beneficiary allowlist");
    bytes32 internal constant PRICE_COUNTER = keccak256("current claim price counter");
    uint256 internal constant SURPLUS = 77;
    StreamNativeClaimSales internal claims;
    StreamPrimarySaleSettlement internal recorder;
    OfficialSafe internal artistSafe;
    OfficialSafe internal payerSafe;
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
        this.deployClaimScenario();
    }

    /// @dev Fresh frames keep observations after governance warps explicit under via-IR.
    function claimsScenarioTime() external view returns (uint64) {
        return uint64(block.timestamp);
    }

    function deployClaimScenario() external {
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
        StreamNativeClaimSales.DeploymentConfig memory d;
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
        claims = StreamNativeClaimSales(
            payable(_artistArtifactCreate(
                    "smart-contracts/domains/mint/StreamNativeClaimSales.sol:StreamNativeClaimSales",
                    abi.encode(d)
                ))
        );
        _assertDeployableProductionInstance(address(recorder));
        _assertDeployableProductionInstance(address(claims));
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
        rows = new GovernanceActionPolicyEntry[](3);
        rows[0] = _claimsPolicy(claims.configureCollectionSigner.selector);
        rows[1] = _claimsPolicy(claims.registerSale.selector);
        rows[2] = _claimsPolicy(claims.closeSale.selector);
        rows = _commerceFloorPolicies(rows);
    }

    function _claimsPolicy(bytes4 selector)
        private
        view
        returns (GovernanceActionPolicyEntry memory)
    {
        return GovernanceActionPolicyEntry(
            1,
            address(claims),
            selector,
            address(claims).codehash,
            keccak256(abi.encode(DEPLOYMENT_HASH, address(claims))),
            1,
            0,
            0,
            0
        );
    }

    function _configureAdditionalProducts() internal override {
        this.admitClaims();
        _configureMintPhase(CLAIM_PHASE, address(claims));
        _configureClaimAllowlist();
        claims.transferOwnership(address(executor));
    }

    function admitClaims() external {
        require(msg.sender == address(this), "fixture caller");
        StreamModuleRegistration[] memory records = new StreamModuleRegistration[](2);
        records[0] = StreamModuleRegistration(
            address(claims),
            keccak256("NATIVE_PRIMARY_SALE_ADAPTER"),
            keccak256("6529STREAM_UNIVERSAL_SETTLEMENT_V1"),
            type(IStreamNativeSaleBinding).interfaceId,
            500_000,
            address(claims).codehash,
            DEPLOYMENT_HASH,
            keccak256("current canonical claims module"),
            "urn:stream:current:canonical-claims"
        );
        // Escrow producer permission does not admit a recorder to the permanent Core Floor.
        records[1] = StreamModuleRegistration(
            address(recorder),
            keccak256("PRIMARY_SALE_SETTLEMENT"),
            keccak256("6529STREAM_UNIVERSAL_SETTLEMENT_V1"),
            type(IStreamPrimarySaleSettlement).interfaceId,
            500_000,
            address(recorder).codehash,
            DEPLOYMENT_HASH,
            keccak256("current canonical claims recorder"),
            "urn:stream:current:claims-recorder"
        );
        (GovernanceCall[] memory calls, bytes[] memory data) =
            StreamCurrentStackPlan.registrationCalls(registry, records);
        (bytes32 scope, bytes32 before_, bytes32 after_) = StreamGovernanceBootstrap.deriveBatchTransitionHashes(
            calls, StreamGovernanceBootstrap.governanceCallsHash(calls)
        );
        uint64 ready = this.claimsScenarioTime() + 48 hours;
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
                    keccak256("current claims admission"),
                    "urn:stream:current:claims-admission",
                    DEPLOYMENT_HASH
                )
            )
        );
        vm.warp(ready);
        executor.executeGovernanceBatch(abi.decode(scheduled, (bytes32)), calls, data);
        StreamModuleRecord memory record = registry.moduleRecord(address(claims));
        require(
            record.status == ModuleRegistryStatus.ACTIVE
                && record.runtimeCodeHash == address(claims).codehash,
            "actual delayed module admission"
        );
        record = registry.moduleRecord(address(recorder));
        require(
            record.status == ModuleRegistryStatus.ACTIVE
                && record.runtimeCodeHash == address(recorder).codehash
                && record.moduleType == keccak256("PRIMARY_SALE_SETTLEMENT")
                && record.moduleVersion == keccak256("6529STREAM_UNIVERSAL_SETTLEMENT_V1")
                && record.interfaceId == type(IStreamPrimarySaleSettlement).interfaceId,
            "actual delayed recorder admission required by permanent Floor"
        );
    }

    function governClaims(bytes calldata data) external {
        require(msg.sender == address(this), "fixture caller");
        _govern(_governanceRequest(1, address(claims), data, 0, 0, 0));
    }

    function _register(uint8 mode, uint8 kind, uint64 cap, bytes32 phase)
        internal
        returns (bytes32 id)
    {
        Claim.Configuration memory c;
        c.sale.collectionId = 1;
        c.sale.phaseId = phase;
        c.sale.saleKind = kind;
        c.sale.authorityMode = mode;
        c.sale.endsAt = this.claimsScenarioTime() + 30 days;
        c.sale.saleSupplyLimit = cap;
        c.sale.mintPolicyHash = manager.phasePolicyHash(1, phase);
        if (kind == 13) {
            c.maxUnitPrice = 2000;
            c.sale.expectedPrimaryPolicyHash = _nativePrimaryPolicyHash();
        }
        if (phase == MERKLE_PHASE) c.sale.priceCounterId = PRICE_COUNTER;
        if (mode == 1) {
            this.governClaims(
                abi.encodeCall(
                    claims.configureCollectionSigner,
                    (
                        uint256(1),
                        address(artistSafe),
                        uint8(2),
                        keccak256("current immutable claim signer"),
                        true
                    )
                )
            );
            bool enabled;
            (c.sale.signer, enabled) = claims.collectionSigner(1, address(artistSafe), 2);
            require(
                enabled && c.sale.signer.installingAuthority == address(executor),
                "actual governed signer installation"
            );
        }
        id = claims.saleIdFor(1, phase, claims.nextSaleNonce());
        this.governClaims(abi.encodeCall(claims.registerSale, (c)));
        Claim.Record memory record = claims.saleRecord(id);
        bytes32 expected = keccak256(
            abi.encode(
                keccak256("6529STREAM_NATIVE_CLAIM_SALES_CONFIG_V1"),
                block.chainid,
                address(claims),
                c
            )
        );
        require(
            keccak256(abi.encode(record.sale.config)) == keccak256(abi.encode(c.sale))
                && record.maxUnitPrice == c.maxUnitPrice && record.sale.configHash == expected,
            "actual immutable configuration with independent hash"
        );
        _recordConsent(id, expected);
    }

    function _recordConsent(bytes32 id, bytes32 configHash) private {
        require(artists.saleConsentScope(1) == 1, "actual REQUIRED sale-consent election");
        SaleConsent.Consent memory terms = SaleConsent.Consent(1, address(claims), id, configHash);
        T.Authorization memory authorization = T.Authorization(
            IStreamArtistAuthorizationRevocation(address(artists))
            .artistAuthorizationState(fixtureArtistId, 0, 0)
            .nextUnusedNonce,
            this.claimsScenarioTime() + 1 days,
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
            "actual Artist Safe consents to exact claim sale"
        );
        (bool consented, bytes32 receipt) = artists.isSaleConsented(1, id, configHash);
        SaleConsent.Record memory consent = artists.saleConsentRecord(receipt);
        require(
            consented && consent.signer == address(artistSafe)
                && consent.artistId == fixtureArtistId
                && keccak256(abi.encode(consent.terms)) == keccak256(abi.encode(terms)),
            "actual permanent Artist sale record"
        );
    }

    function _configureClaimAllowlist() private {
        // Independent canonical double-hashed leaf: the counter subject is the beneficiary.
        bytes32 leaf = keccak256(
            bytes.concat(
                keccak256(
                    abi.encode(
                        keccak256("6529STREAM_MINT_ALLOWLIST_LEAF_V1"),
                        block.chainid,
                        address(manager),
                        uint256(1),
                        MERKLE_PHASE,
                        PRICE_COUNTER,
                        SECOND_OWNER,
                        uint64(1),
                        true,
                        uint256(0)
                    )
                )
            )
        );
        bytes32 definition = IStreamMintCounterPolicy(address(ledger))
            .registerCounterDefinition(
                IStreamMintCounterPolicy.Definition(
                    IStreamMintCounterPolicy.CounterScope.PHASE,
                    IStreamMintManager.CounterKeyMode.RECIPIENT,
                    leaf,
                    DEPLOYMENT_HASH
                )
            );
        bytes32[] memory counters = new bytes32[](1);
        counters[0] = PRICE_COUNTER;
        IStreamMintManager.MintCounterConfig[] memory configs =
            new IStreamMintManager.MintCounterConfig[](1);
        configs[0] = IStreamMintManager.MintCounterConfig(
            true,
            IStreamMintManager.CounterKeyMode.RECIPIENT,
            IStreamMintLedger.CounterCapMode.MERKLE_STATIC,
            IStreamMintLedger.CounterDeltaMode.STATIC,
            1,
            1,
            definition
        );
        IStreamMintManager.MintGateConfig memory gate;
        IStreamMintManager.MintPhaseConfig memory config =
            IStreamMintManager.MintPhaseConfig(false, 0, 0, 1, DEPLOYMENT_HASH, DEPLOYMENT_HASH);
        address[] memory phaseExecutors = new address[](0);
        _recordFixturePolicy(
            MERKLE_PHASE,
            manager.previewPhasePolicyHash(
                1, MERKLE_PHASE, config, gate, counters, configs, phaseExecutors
            )
        );
        manager.configurePhase(1, MERKLE_PHASE, config, gate, counters, configs);
        phaseExecutors = new address[](1);
        phaseExecutors[0] = address(claims);
        _recordFixturePolicy(
            MERKLE_PHASE,
            manager.previewPhasePolicyHash(
                1, MERKLE_PHASE, config, gate, counters, configs, phaseExecutors
            )
        );
        manager.setPhaseExecutor(1, MERKLE_PHASE, address(claims), true);
    }

    function _allowlistData() internal pure returns (bytes memory) {
        IStreamMintCounterPolicy.AllowlistProof[][] memory proofs =
            new IStreamMintCounterPolicy.AllowlistProof[][](1);
        proofs[0] = new IStreamMintCounterPolicy.AllowlistProof[](1);
        proofs[0][0] = IStreamMintCounterPolicy.AllowlistProof(1, true, 0, new bytes32[](0));
        return abi.encode(proofs);
    }

    function _purchase(bytes32 id, uint256 tag, uint256 chosen)
        internal
        view
        returns (Claim.Purchase memory p)
    {
        p.mint.saleId = id;
        p.mint.payer = address(payerSafe);
        p.mint.executor = address(payerSafe);
        p.mint.initialRecipient = address(payerSafe);
        p.mint.beneficiary = SECOND_OWNER;
        p.mint.tokenData = abi.encode(TOKEN_DATA, tag);
        p.mint.mintCommitment = keccak256(abi.encode("current claims commitment", tag));
        p.mint.executionNonce = claims.nextExecutionNonce(id, p.mint.payer);
        p.chosenUnitPrice = chosen;
    }

    function _authorization(Claim.Purchase memory p, uint256 nonce, uint256 minimum)
        internal
        view
        returns (Sales.SaleAuthorization memory a)
    {
        Immediate.Configuration memory c = claims.saleRecord(p.mint.saleId).sale.config;
        a.chainId = block.chainid;
        a.saleAdapter = address(claims);
        a.mintManager = address(manager);
        a.collectionId = 1;
        a.phaseId = c.phaseId;
        a.saleId = p.mint.saleId;
        a.saleKind = c.saleKind;
        a.revenueClass = PRIMARY_REVENUE_CLASS;
        a.expectedPrimaryPolicyHash = c.expectedPrimaryPolicyHash;
        address[] memory recipients = new address[](1);
        recipients[0] = p.mint.initialRecipient;
        address[] memory beneficiaries = new address[](1);
        beneficiaries[0] = p.mint.beneficiary;
        bytes[] memory data = new bytes[](1);
        data[0] = p.mint.tokenData;
        bytes32[] memory commitments = new bytes32[](1);
        commitments[0] = p.mint.mintCommitment;
        a.initialRecipientsHash =
            keccak256(abi.encode(keccak256("6529STREAM_MINT_BATCH_RECIPIENTS_V1"), recipients));
        a.beneficiariesHash = keccak256(
            abi.encode(keccak256("6529STREAM_MINT_BATCH_BENEFICIARIES_V1"), beneficiaries)
        );
        a.tokenDataArrayHash =
            keccak256(abi.encode(keccak256("6529STREAM_MINT_BATCH_TOKEN_DATA_V1"), data));
        a.mintCommitmentsHash =
            keccak256(abi.encode(keccak256("6529STREAM_MINT_BATCH_COMMITMENTS_V1"), commitments));
        a.payer = p.mint.payer;
        a.executor = p.mint.executor;
        a.unitPrice = minimum;
        a.quantity = 1;
        a.policyHash = c.mintPolicyHash;
        a.nonce = bytes32(nonce);
        a.deadline = this.claimsScenarioTime() + 30 days;
    }

    function _literalDigest(Sales.SaleAuthorization memory a) internal view returns (bytes32) {
        bytes32 domain = keccak256(
            abi.encode(
                keccak256(
                    "EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"
                ),
                keccak256("6529Stream Sales"),
                keccak256("1"),
                block.chainid,
                address(claims)
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

    function _authorizationId(bytes32 digest) internal pure returns (bytes32) {
        return keccak256(abi.encode(keccak256("6529STREAM_MINT_TICKET_AUTHORIZATION_V1"), digest));
    }

    function _publicAuthorizationId(Claim.Purchase memory p) internal view returns (bytes32) {
        bytes32 configHash = claims.saleRecord(p.mint.saleId).sale.configHash;
        bytes32 request = keccak256(
            abi.encode(
                keccak256("6529STREAM_NATIVE_CLAIM_SALES_REQUEST_V1"),
                block.chainid,
                address(claims),
                configHash,
                p
            )
        );
        return keccak256(
            abi.encode(
                keccak256("6529STREAM_NATIVE_PUBLIC_CLAIM_MINT_AUTHORIZATION_V1"),
                block.chainid,
                address(claims),
                address(manager),
                configHash,
                request
            )
        );
    }

    function _saleProof(Sales.SaleAuthorization memory a)
        internal
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

    function _signedSafeCall(uint256 value, bytes memory data) internal returns (bytes memory) {
        bytes memory signatures = safeThresholdSignature(
            payerKeys,
            payerSafe.getTransactionHash(
                address(claims), value, data, 0, 0, 0, 0, address(0), address(0), payerSafe.nonce()
            )
        );
        return abi.encodeCall(
            payerSafe.execTransaction,
            (
                address(claims),
                value,
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

    function _executeSaved(bytes memory callData) internal {
        (bool ok, bytes memory result) = address(payerSafe).call(callData);
        require(
            ok && result.length == 32 && abi.decode(result, (bool)), "actual threshold Safe CALL"
        );
    }

    function _requestAndFulfill(uint256 tokenId) internal {
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

    function _assertReceipt(
        Claim.Purchase memory p,
        Native.NativeSettlementCandidate memory c,
        Immediate.Receipt memory r,
        bytes32 auth,
        bytes32 digest,
        uint256 credit
    ) internal view {
        require(
            r.saleId == p.mint.saleId && r.executionId == c.executionBinding.executionId
                && r.authorizationId == auth && r.saleAuthorizationDigest == digest
                && r.operationRoot == c.operationIdentityCommitment
                && r.operationId == c.operationId,
            "exact original authority and operation receipt"
        );
        require(
            r.tokenId != 0 && r.chargedAmount == p.chosenUnitPrice && r.revealFee == REVEAL_FEE
                && r.revealCredit == credit,
            "chosen amount and actual reveal accounting"
        );
        require(
            claims.executionStatus(r.executionId) == 2
                && core.ownerOf(r.tokenId) == p.mint.initialRecipient
                && core.coordinatorAtMint(r.tokenId) == address(entropy)
                && c.sale.beneficiary == p.mint.beneficiary,
            "actual recipient distinct from bound beneficiary, coordinator retained"
        );
        require(
            ledger.isManagerAuthorizationUsed(address(manager), auth)
                && ledger.isManagerOperationRootUsed(address(manager), r.operationRoot),
            "actual Ledger replay consumed"
        );
        require(
            claims.activePublicNativeCandidate(r.executionId) == 0,
            "no lingering public paid witness"
        );
        if (p.chosenUnitPrice == 0) _assertFreeReceipt(r);
        else _assertPaidReceipt(p, c, r);
    }

    function _assertFreeReceipt(Immediate.Receipt memory r) private view {
        bytes32 key = recorder.settlementKey(address(claims), r.executionId);
        require(
            r.settlementKey == 0 && !recorder.settlementConsumed(key)
                && recorder.settlementResult(key).candidateCommitment == 0
                && commerceFloor.directPrimarySaleFloorReceipt(key).receiptHash == 0,
            "zero price creates no official or DIRECT payment receipt"
        );
        _assertNoCommerceFloorReceipt(key);
        require(
            wallet.balance == 0 && recorder.totalOfficialSettled(address(0)) == 0
                && revenueEscrow.totalOwed(address(0)) == 0 && address(revenueEscrow).balance == 0,
            "reveal payment is never official sale revenue"
        );
    }

    function _assertPaidReceipt(
        Claim.Purchase memory p,
        Native.NativeSettlementCandidate memory c,
        Immediate.Receipt memory r
    ) private view {
        bytes32 key = recorder.settlementKey(address(claims), r.executionId);
        Settlement.PrimarySettlementResult memory result = recorder.settlementResult(key);
        require(
            r.settlementKey == key && recorder.settlementConsumed(key)
                && result.settlementKey == key
                && result.candidateCommitment == _candidateCommitment(c),
            "independently bound original native settlement"
        );
        require(
            result.profileId == profile && result.wallet == wallet && result.asset == address(0)
                && result.amount == p.chosenUnitPrice && result.executor == address(payerSafe)
                && !result.escrowed,
            "whole chosen amount reaches original official PROFILE wallet"
        );
        require(
            result.executionId == r.executionId
                && result.operationIdentityCommitment == r.operationRoot
                && result.currentPolicyHash == c.currentPolicyHash
                && result.boundPolicyHash == c.boundPolicyHash,
            "official result retains actual mint operation and policy"
        );
        _assertWaivedCommerceReceipt(address(recorder), key);
        StreamConservationFloorTypes.SettlementReceipt memory floorReceipt =
            commerceFloor.settlementReceipt(key);
        require(
            floorReceipt.candidateCommitment == result.candidateCommitment
                && floorReceipt.resultHash == keccak256(abi.encode(result))
                && floorReceipt.releaseReceiptHash == 0 && commerceFloor.sourceCount() == 0
                && commerceFloor.firstSale(1).sourceId == 0,
            "actual WAIVED Floor binds original result with no documentary evidence"
        );
        require(
            commerceFloor.firstSale(1).sourceSetHash == commerceFloor.sourceSetHashAt(0)
                && commerceFloor.sourceSetHashAt(0) != 0
                && commerceFloor.directPrimarySaleFloorReceipt(key).receiptHash == 0,
            "permanent first sale has exact empty source head and no duplicate DIRECT receipt"
        );
    }

    /// @dev The permissionless preparation boundary diagnoses genuine missing evidence before
    /// payment. This prospective result creates neither an official payment nor a Floor receipt.
    function _assertMissingDocumentaryFloor(Native.NativeSettlementCandidate memory n) internal {
        Settlement.ERC20SettlementCandidate memory c;
        c.saleAdapter = n.saleAdapter;
        c.executor = n.executor;
        c.sale = n.sale;
        c.executionBinding = n.executionBinding;
        c.orchestrationOrder = n.orchestrationOrder;
        c.mintManager = n.mintManager;
        c.operationIdentityCommitment = n.operationIdentityCommitment;
        c.operationId = n.operationId;
        c.currentPolicyHash = n.currentPolicyHash;
        c.boundPolicyHash = n.boundPolicyHash;
        c.rights = n.rights;
        c.saleExecutionHash = n.saleExecutionHash;
        Settlement.PrimarySettlementResult memory r;
        r.candidateCommitment = _candidateCommitment(n);
        r.settlementKey = recorder.settlementKey(address(claims), n.executionBinding.executionId);
        r.profileId = n.rights.profileId;
        r.wallet = n.rights.wallet;
        r.amount = n.sale.amount;
        r.executor = n.executor;
        r.executionId = n.executionBinding.executionId;
        r.operationIdentityCommitment = n.operationIdentityCommitment;
        r.currentPolicyHash = n.currentPolicyHash;
        r.boundPolicyHash = n.boundPolicyHash;
        require(commerceFloor.sourceCount() == 0, "no documentary source installed");
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamConservationFloor.ConservationFloorSourceUnavailable.selector
            )
        );
        commerceFloor.preparePrimarySale(address(recorder), c, r);
    }

    function _candidateCommitment(Native.NativeSettlementCandidate memory c)
        private
        view
        returns (bytes32)
    {
        return keccak256(
            abi.encode(
                keccak256("6529STREAM_NATIVE_SETTLEMENT_CANDIDATE_V1"),
                block.chainid,
                address(recorder),
                c
            )
        );
    }

    function _assertFreeEvents(Vm.Log[] memory logs, Immediate.Receipt memory r) internal view {
        uint256 seen;
        for (uint256 i; i < logs.length; ++i) {
            require(
                logs[i].emitter != address(recorder) && logs[i].emitter != address(commerceFloor),
                "zero path emits no recorder or conservation events"
            );
            if (
                logs[i].emitter == address(claims) && logs[i].topics.length != 0
                    && logs[i].topics[0]
                        == keccak256("FreeClaimExecuted(bytes32,bytes32,uint256,bytes32)")
            ) {
                require(
                    logs[i].topics.length == 4 && logs[i].topics[1] == r.saleId
                        && logs[i].topics[2] == r.executionId
                        && uint256(logs[i].topics[3]) == r.tokenId
                        && keccak256(logs[i].data) == keccak256(abi.encode(r.authorizationId)),
                    "exact free event identity"
                );
                ++seen;
            }
        }
        require(seen == 1, "one explicit free event");
    }

    function _assertMoney(uint256 payerBefore, uint256 revenue, uint256 count, uint256 credit)
        internal
        view
    {
        require(
            address(payerSafe).balance == payerBefore - revenue - count * REVEAL_FEE - credit
                && wallet.balance == revenue && recorder.totalOfficialSettled(address(0)) == revenue
                && recorder.officialSettled(PRIMARY_REVENUE_CLASS, profile, wallet, address(0))
                    == revenue,
            "actual native revenue and payer conservation"
        );
        require(
            revenueEscrow.totalOwed(address(0)) == 0 && address(revenueEscrow).balance == 0
                && address(recorder).balance == 0,
            "direct payment has no recorder or escrow residue"
        );
        require(
            entropy.revealFeeEscrow(1) == count * REVEAL_FEE
                && address(entropy).balance == count * REVEAL_FEE
                && address(claims).balance == credit && claims.refundLiability() == credit
                && provider.nextRequestId() == 1,
            "manual reveal fees and native payer excess remain separate from revenue"
        );
    }

    function _counterKey(Claim.Purchase memory p) internal view returns (bytes32) {
        bytes32 phase = claims.saleRecord(p.mint.saleId).sale.config.phaseId;
        bool merkle = phase == MERKLE_PHASE;
        bytes32 counter = merkle ? PRICE_COUNTER : keccak256("supply");
        bytes32 subject = manager.previewSubjectKey(
            merkle
                ? IStreamMintManager.CounterKeyMode.RECIPIENT
                : IStreamMintManager.CounterKeyMode.CONSTANT,
            1,
            phase,
            counter,
            p.mint.payer,
            p.mint.beneficiary,
            address(claims),
            address(0),
            0
        );
        return manager.previewCounterValueKey(1, phase, counter, subject);
    }

    function _counter(Claim.Purchase memory p) internal view returns (uint64) {
        return ledger.counterValue(_counterKey(p));
    }

    // Small independently grouped snapshots avoid a single wide ABI expression under via-IR.
    function _adapterState(Claim.Purchase memory p, bytes32 executionId)
        private
        view
        returns (bytes32)
    {
        bytes32 saleState = keccak256(
            abi.encode(
                claims.saleRecord(p.mint.saleId),
                claims.nextExecutionNonce(p.mint.saleId, p.mint.payer),
                claims.executionStatus(executionId),
                claims.executionReceipt(executionId),
                claims.activePublicNativeCandidate(executionId)
            )
        );
        bytes32 refunds = keccak256(
            abi.encode(
                address(claims).balance,
                claims.refundLiability(),
                claims.refundAccountCount(),
                claims.refundableBalance(p.mint.saleId, p.mint.payer),
                claims.refundableBalance(p.mint.saleId, p.mint.beneficiary)
            )
        );
        return
            keccak256(abi.encode(payerSafe.nonce(), address(payerSafe).balance, saleState, refunds));
    }

    function _paymentState(bytes32 key) private view returns (bytes32) {
        bytes32 official = keccak256(
            abi.encode(
                recorder.settlementConsumed(key),
                recorder.settlementResult(key),
                recorder.totalOfficialSettled(address(0)),
                recorder.officialSettled(PRIMARY_REVENUE_CLASS, profile, wallet, address(0))
            )
        );
        return keccak256(
            abi.encode(
                official,
                wallet.balance,
                address(recorder).balance,
                revenueEscrow.totalOwed(address(0)),
                address(revenueEscrow).balance
            )
        );
    }

    function _floorState(bytes32 key) private view returns (bytes32) {
        return keccak256(
            abi.encode(
                commerceFloor.firstSale(1),
                commerceFloor.settlementReceipt(key),
                commerceFloor.directPrimarySaleFloorReceipt(key),
                core.declaredConservationTier(1)
            )
        );
    }

    function _mintState(Claim.Purchase memory p, bytes32 root) private view returns (bytes32) {
        bytes32 mintState = keccak256(
            abi.encode(
                manager.nextOperationNonce(),
                ledger.isManagerOperationRootUsed(address(manager), root),
                _counter(p),
                core.collectionMintedEver(1),
                core.lastAllocatedTokenId(),
                core.balanceOf(p.mint.initialRecipient)
            )
        );
        return keccak256(
            abi.encode(
                mintState,
                entropy.revealFeeEscrow(1),
                address(entropy).balance,
                provider.nextRequestId(),
                address(provider).balance
            )
        );
    }

    function _effectsState(Claim.Purchase memory p, Native.NativeSettlementCandidate memory c)
        private
        view
        returns (bytes32)
    {
        bytes32 key = recorder.settlementKey(address(claims), c.executionBinding.executionId);
        return keccak256(
            abi.encode(
                _adapterState(p, c.executionBinding.executionId),
                _paymentState(key),
                _floorState(key),
                _mintState(p, c.operationIdentityCommitment)
            )
        );
    }

    function _purchaseState(
        Claim.Purchase memory p,
        Native.NativeSettlementCandidate memory c,
        bytes32 auth
    ) internal view returns (bytes32) {
        return keccak256(
            abi.encode(
                _effectsState(p, c), ledger.isManagerAuthorizationUsed(address(manager), auth)
            )
        );
    }

    function _expectSavedFailure(
        bytes memory saved,
        Claim.Purchase memory p,
        Native.NativeSettlementCandidate memory c,
        bytes32 auth
    ) internal returns (bytes memory reason) {
        bytes32 before_ = _purchaseState(p, c, auth);
        bool ok;
        (ok, reason) = address(payerSafe).call(saved);
        require(
            !ok && _purchaseState(p, c, auth) == before_,
            "failed Safe envelope leaves payment, mint, refund and replay state unchanged"
        );
    }

    function _assertSafeTargetFailure(bytes memory reason) internal pure {
        require(
            keccak256(reason) == keccak256(abi.encodeWithSignature("Error(string)", "GS013")),
            "actual threshold Safe reached reverting target call"
        );
    }

    function _expectSignedFailure(
        Claim.Purchase memory p,
        Sales.SaleAuthorization memory a,
        Native.NativeSettlementCandidate memory tracked,
        bytes memory expected
    ) internal {
        IStreamPrivateSaleAdapter.Signature memory proof = _saleProof(a);
        vm.expectRevert(expected);
        claims.previewSignedPurchase(p, a, proof);
        _expectSavedFailure(
            _signedSafeCall(
                p.chosenUnitPrice + REVEAL_FEE, abi.encodeCall(claims.purchaseSigned, (p, a, proof))
            ),
            p,
            tracked,
            _authorizationId(_literalDigest(a))
        );
    }

    function _voidByArtist(
        Sales.SaleAuthorization memory a,
        Native.NativeSettlementCandidate memory c
    ) internal {
        Claim.Purchase memory p = _purchase(a.saleId, 0, 0);
        bytes32 auth = _authorizationId(_literalDigest(a));
        require(
            !ledger.isManagerAuthorizationUsed(address(manager), auth),
            "original Sales ID initially unused"
        );
        bytes32 state = _effectsState(p, c);
        uint256 nonce = artistSafe.nonce();
        vm.recordLogs();
        require(
            executeSafe(
                artistSafe,
                artistKeys,
                address(manager),
                0,
                abi.encodeCall(
                    IStreamMintImmediateSaleAuthorizationRevocation.voidMintImmediateSaleAuthorization,
                    (a, address(artistSafe), uint8(2), bytes(""))
                ),
                0
            ),
            "actual original authorizer Safe voids full Sales payload"
        );
        _assertVoidEvents(vm.getRecordedLogs(), a, auth);
        require(
            artistSafe.nonce() == nonce + 1
                && ledger.isManagerAuthorizationUsed(address(manager), auth)
                && _effectsState(p, c) == state,
            "only void map and actual authorizer Safe nonce change"
        );
    }

    function _assertVoidEvents(Vm.Log[] memory logs, Sales.SaleAuthorization memory a, bytes32 auth)
        private
        view
    {
        uint256 ledgerEvents;
        uint256 managerEvents;
        for (uint256 i; i < logs.length; ++i) {
            Vm.Log memory log = logs[i];
            require(
                log.emitter != address(recorder) && log.emitter != address(commerceFloor),
                "void emits no payment events"
            );
            if (
                log.emitter == address(ledger) && log.topics.length != 0
                    && log.topics[0]
                        == keccak256("MintLedgerAuthorizationVoided(uint16,bytes32,address)")
            ) {
                require(
                    log.topics.length == 3 && log.topics[1] == auth
                        && log.topics[2] == bytes32(uint256(uint160(address(manager))))
                        && keccak256(log.data) == keccak256(abi.encode(uint16(1))),
                    "exact manager-scoped Ledger void event"
                );
                ++ledgerEvents;
            }
            if (
                log.emitter == address(manager) && log.topics.length != 0
                    && log.topics[0]
                        == keccak256(
                            "MintAuthorizationVoided(uint16,uint256,bytes32,bytes32,address,address,uint8)"
                        )
            ) {
                require(
                    log.topics.length == 4 && log.topics[1] == bytes32(a.collectionId)
                        && log.topics[2] == a.phaseId && log.topics[3] == auth
                        && keccak256(log.data)
                            == keccak256(
                                abi.encode(
                                    uint16(1), address(artistSafe), address(claims), uint8(2)
                                )
                            ),
                    "exact original Sales family and authorizer in Manager void event"
                );
                ++managerEvents;
            }
        }
        require(ledgerEvents == 1 && managerEvents == 1, "one Ledger and one Manager void receipt");
    }
}

/// @notice Original eight actual-current claim cases, over the shared host-local fixture.
contract StreamCurrentNativeClaimSalesTest is StreamCurrentNativeClaimSalesFixture {
    function testActualSafeSignedFreeClaimConsumesOriginalSalesAuthorityWithoutPaymentReceipt()
        public
    {
        bytes32 id = _register(1, 12, 4, CLAIM_PHASE);
        Claim.Purchase memory p = _purchase(id, 1, 0);
        Sales.SaleAuthorization memory a = _authorization(p, 71, 0);
        IStreamPrivateSaleAdapter.Signature memory proof = _saleProof(a);
        bytes32 digest = _literalDigest(a);
        require(claims.authorizationDigest(a) == digest, "original literal 24-field Sales-v1");
        Native.NativeSettlementCandidate memory c = claims.previewSignedPurchase(p, a, proof);
        bytes memory saved =
            _signedSafeCall(REVEAL_FEE, abi.encodeCall(claims.purchaseSigned, (p, a, proof)));
        uint256 before_ = address(payerSafe).balance;
        uint256 nonce = manager.nextOperationNonce();
        vm.recordLogs();
        _executeSaved(saved);
        Immediate.Receipt memory r = claims.executionReceipt(c.executionBinding.executionId);
        _assertReceipt(p, c, r, _authorizationId(digest), digest, 0);
        _assertFreeEvents(vm.getRecordedLogs(), r);
        _assertMoney(before_, 0, 1, 0);
        require(
            manager.nextOperationNonce() == nonce + 1 && _counter(p) == 1,
            "one real operation and counter"
        );
        _expectSavedFailure(saved, p, c, r.authorizationId);

        // Safe replay and Ledger replay are separate boundaries. Use both fresh nonces but
        // retain the exact original seller authorization and threshold ERC-1271 proof.
        p.mint.executionNonce = claims.nextExecutionNonce(id, address(payerSafe));
        saved = _signedSafeCall(REVEAL_FEE, abi.encodeCall(claims.purchaseSigned, (p, a, proof)));
        _expectSavedFailure(saved, p, c, r.authorizationId);
        _requestAndFulfill(r.tokenId);
    }

    function testActualSafeFreeRevealSurplusBelongsToPayerAndWithdrawsAfterCapClosure() public {
        bytes32 id = _register(2, 12, 1, CLAIM_PHASE);
        Claim.Purchase memory p = _purchase(id, 2, 0);
        p.mint.initialRecipient = SECOND_OWNER;
        (Native.NativeSettlementCandidate memory c, bytes32 auth) = claims.previewPublicPurchase(p);
        require(auth == _publicAuthorizationId(p), "literal public free identity");
        uint256 before_ = address(payerSafe).balance;
        _executeSaved(
            _signedSafeCall(REVEAL_FEE + SURPLUS, abi.encodeCall(claims.purchasePublic, (p)))
        );
        Immediate.Receipt memory r = claims.executionReceipt(c.executionBinding.executionId);
        _assertReceipt(p, c, r, auth, 0, SURPLUS);
        _assertMoney(before_, 0, 1, SURPLUS);
        require(claims.saleRecord(id).sale.closed, "finite free cap closes sale");
        require(
            claims.refundableBalance(id, address(payerSafe)) == SURPLUS
                && claims.refundableBalance(id, SECOND_OWNER) == 0,
            "native payer owns excess, not token recipient or beneficiary"
        );
        require(claims.refundAccountCount() == 1, "one enumerable refund owner");
        (bytes32 listedId, address listedPayer) = claims.refundAccountAt(0);
        require(listedId == id && listedPayer == address(payerSafe), "exact refund account");
        bytes32 state = _purchaseState(p, c, auth);
        vm.prank(SECOND_OWNER);
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamImmediateSaleReveal.SaleRefundEmpty.selector, id, SECOND_OWNER
            )
        );
        claims.claimRefund(id, SECOND_OWNER);
        require(_purchaseState(p, c, auth) == state, "nonowner refund leaves all state unchanged");
        _executeSaved(
            _signedSafeCall(0, abi.encodeCall(claims.claimRefund, (id, address(payerSafe))))
        );
        require(
            address(payerSafe).balance == before_ - REVEAL_FEE
                && claims.refundableBalance(id, address(payerSafe)) == 0
                && claims.refundLiability() == 0 && address(claims).balance == 0
                && claims.refundAccountCount() == 1,
            "closed-sale Safe pull conserves fee and append-only account history"
        );
        _requestAndFulfill(r.tokenId);
    }

    function testActualSafePublicPWYWZeroThenPaidUsesPriorWaiverAndOneGenuineFirstSale() public {
        _declareWaivedCommerce();
        bytes32 id = _register(2, 13, 4, CLAIM_PHASE);
        uint256 before_ = address(payerSafe).balance;
        Claim.Purchase memory p = _purchase(id, 10, 0);
        (Native.NativeSettlementCandidate memory c, bytes32 freeAuth) =
            claims.previewPublicPurchase(p);
        require(freeAuth == _publicAuthorizationId(p), "literal zero public authorization");
        vm.recordLogs();
        _executeSaved(_signedSafeCall(REVEAL_FEE, abi.encodeCall(claims.purchasePublic, (p))));
        Immediate.Receipt memory r = claims.executionReceipt(c.executionBinding.executionId);
        _assertReceipt(p, c, r, freeAuth, 0, 0);
        _assertFreeEvents(vm.getRecordedLogs(), r);
        require(commerceFloor.firstSale(1).receiptHash == 0, "free PWYW is not a first payment");

        bytes32 firstReceipt;
        for (uint256 i; i < 2; ++i) {
            p = _purchase(id, 11 + i, PRICE + i * 500);
            bytes32 auth;
            (c, auth) = claims.previewPublicPurchase(p);
            require(
                auth == _publicAuthorizationId(p) && auth != freeAuth,
                "distinct literal chosen-price identity"
            );
            _executeSaved(
                _signedSafeCall(
                    p.chosenUnitPrice + REVEAL_FEE, abi.encodeCall(claims.purchasePublic, (p))
                )
            );
            r = claims.executionReceipt(c.executionBinding.executionId);
            _assertReceipt(p, c, r, auth, 0, 0);
            bytes32 observed = commerceFloor.firstSale(1).receiptHash;
            if (i == 0) {
                firstReceipt = observed;
            } else {
                require(
                    observed == firstReceipt, "second positive payment retains original first sale"
                );
            }
        }
        _assertMoney(before_, 2500, 3, 0);
        require(
            _counter(p) == 3 && claims.saleRecord(id).sale.soldQuantity == 3,
            "free and positive paths both consume actual supply"
        );
    }

    function testActualUndeclaredFreeMintDoesNotAuthorizeLaterPaidPWYW() public {
        bytes32 id = _register(2, 13, 4, CLAIM_PHASE);
        Claim.Purchase memory p = _purchase(id, 20, 0);
        (Native.NativeSettlementCandidate memory c, bytes32 auth) = claims.previewPublicPurchase(p);
        _executeSaved(_signedSafeCall(REVEAL_FEE, abi.encodeCall(claims.purchasePublic, (p))));
        _assertReceipt(p, c, claims.executionReceipt(c.executionBinding.executionId), auth, 0, 0);
        require(
            core.declaredConservationTier(1) == 0 && core.collectionMintedEver(1) == 1,
            "actual free mint retains undeclared conservation"
        );
        p = _purchase(id, 21, PRICE);
        (c, auth) = claims.previewPublicPurchase(p);
        _assertMissingDocumentaryFloor(c);
        bytes memory reason = _expectSavedFailure(
            _signedSafeCall(PRICE + REVEAL_FEE, abi.encodeCall(claims.purchasePublic, (p))),
            p,
            c,
            auth
        );
        _assertSafeTargetFailure(reason);
        _assertNoCommerceFloorReceipt(
            recorder.settlementKey(address(claims), c.executionBinding.executionId)
        );
        require(
            core.collectionMintedEver(1) == 1 && _counter(p) == 1 && wallet.balance == 0
                && entropy.revealFeeEscrow(1) == REVEAL_FEE,
            "failed positive crossing preserves exactly the prior free mint"
        );
        // Core permanently forbids declaring a tier after that first mint. No late waiver repair.
    }

    function testActualSafeSignedPWYWPreservesOriginalMinimumQuantityAndFiniteSaleCap() public {
        _declareWaivedCommerce();
        bytes32 id = _register(1, 13, 1, CLAIM_PHASE);
        Claim.Purchase memory p = _purchase(id, 30, 1500);
        Sales.SaleAuthorization memory a = _authorization(p, 81, PRICE);
        Native.NativeSettlementCandidate memory c =
            claims.previewSignedPurchase(p, a, _saleProof(a));
        p.chosenUnitPrice = PRICE - 1;
        _expectSignedFailure(
            p,
            a,
            c,
            abi.encodeWithSelector(Claim.ClaimPriceInvalid.selector, PRICE - 1, PRICE, 2000)
        );
        p.chosenUnitPrice = 2001;
        _expectSignedFailure(
            p, a, c, abi.encodeWithSelector(Claim.ClaimPriceInvalid.selector, 2001, PRICE, 2000)
        );
        p.chosenUnitPrice = 1500;
        a.quantity = 2;
        // Re-sign the malformed quantity so the failure proves original singleton semantics.
        _expectSignedFailure(
            p, a, c, abi.encodeWithSelector(Immediate.InvalidImmediateSale.selector)
        );
        a.quantity = 1;
        uint256 before_ = address(payerSafe).balance;
        _executeSaved(
            _signedSafeCall(
                1500 + REVEAL_FEE, abi.encodeCall(claims.purchaseSigned, (p, a, _saleProof(a)))
            )
        );
        _assertReceipt(
            p,
            c,
            claims.executionReceipt(c.executionBinding.executionId),
            _authorizationId(_literalDigest(a)),
            _literalDigest(a),
            0
        );
        _assertMoney(before_, 1500, 1, 0);
        require(
            claims.saleRecord(id).sale.closed && _counter(p) == 1,
            "chosen amount paid, finite sale cap consumed"
        );
        p = _purchase(id, 31, 2000);
        a = _authorization(p, 82, PRICE);
        _expectSignedFailure(
            p, a, c, abi.encodeWithSelector(Immediate.ImmediateSaleUnavailable.selector, id)
        );
    }

    function testActualSafePWYWMerkleZeroOverrideBindsBeneficiaryAndActualLedgerCap() public {
        bytes32 id = _register(1, 13, 4, MERKLE_PHASE);
        Claim.Purchase memory p = _purchase(id, 40, 0);
        p.mint.resolverData = _allowlistData();
        Sales.SaleAuthorization memory a = _authorization(p, 91, PRICE);
        Native.NativeSettlementCandidate memory c =
            claims.previewSignedPurchase(p, a, _saleProof(a));
        p.mint.beneficiary = address(0xBAD);
        a = _authorization(p, 92, PRICE);
        _expectSignedFailure(
            p,
            a,
            c,
            abi.encodeWithSignature(
                "InvalidSaleAllowlistProof(bytes32,address)", PRICE_COUNTER, address(0xBAD)
            )
        );
        p.mint.beneficiary = SECOND_OWNER;
        a = _authorization(p, 91, PRICE);
        uint256 before_ = address(payerSafe).balance;
        _executeSaved(
            _signedSafeCall(
                REVEAL_FEE, abi.encodeCall(claims.purchaseSigned, (p, a, _saleProof(a)))
            )
        );
        _assertReceipt(
            p,
            c,
            claims.executionReceipt(c.executionBinding.executionId),
            _authorizationId(_literalDigest(a)),
            _literalDigest(a),
            0
        );
        _assertMoney(before_, 0, 1, 0);
        require(
            _counter(p) == 1 && !claims.saleRecord(id).sale.closed,
            "explicit zero overrides signed minimum while actual recipient counter reaches cap"
        );
        p = _purchase(id, 41, 0);
        p.mint.resolverData = _allowlistData();
        a = _authorization(p, 93, PRICE);
        bytes32 key = _counterKey(p);
        _expectSignedFailure(
            p,
            a,
            c,
            abi.encodeWithSelector(
                IStreamMintLedger.CounterCapExceeded.selector, key, uint64(2), uint64(1)
            )
        );
        require(
            !claims.saleRecord(id).sale.closed && claims.saleRecord(id).sale.soldQuantity == 1,
            "beneficiary cap, not adapter closure or consumed seller nonce, rejects second claim"
        );
    }

    function testActualArtistSafeVoidsOriginalPWYWAuthorizationBeforeAndAfterSaleRetirement()
        public
    {
        _declareWaivedCommerce();
        bytes32 id = _register(1, 13, 4, CLAIM_PHASE);
        Claim.Purchase memory p = _purchase(id, 50, PRICE);
        Sales.SaleAuthorization memory a = _authorization(p, 101, PRICE);
        Native.NativeSettlementCandidate memory c =
            claims.previewSignedPurchase(p, a, _saleProof(a));
        bytes32 auth = _authorizationId(_literalDigest(a));
        _voidByArtist(a, c);
        _expectSavedFailure(
            _signedSafeCall(
                PRICE + REVEAL_FEE, abi.encodeCall(claims.purchaseSigned, (p, a, _saleProof(a)))
            ),
            p,
            c,
            auth
        );

        a = _authorization(p, 102, PRICE);
        c = claims.previewSignedPurchase(p, a, _saleProof(a));
        this.governClaims(abi.encodeCall(claims.closeSale, (id)));
        this.governClaims(
            abi.encodeCall(
                claims.configureCollectionSigner,
                (
                    uint256(1),
                    address(artistSafe),
                    uint8(2),
                    keccak256("retired claim signer"),
                    false
                )
            )
        );
        (, bool enabled) = claims.collectionSigner(1, address(artistSafe), 2);
        require(!enabled && claims.saleRecord(id).sale.closed, "actual governed retirement");
        vm.warp(uint256(a.deadline) + 1);
        _voidByArtist(a, c);
        require(
            ledger.isManagerAuthorizationUsed(address(manager), auth)
                && ledger.isManagerAuthorizationUsed(
                    address(manager), _authorizationId(_literalDigest(a))
                ),
            "both original Sales IDs permanently void despite expired and disabled live authority"
        );
        require(
            core.collectionMintedEver(1) == 0 && _counter(p) == 0
                && claims.saleRecord(id).sale.soldQuantity == 0 && wallet.balance == 0,
            "historical revocation grants no mint or payment authority"
        );
    }

    function testActualLateCoreDeliveryFailureRollsBackPaymentAndIdenticalSafeBytesRetry() public {
        _declareWaivedCommerce();
        bytes32 id = _register(2, 13, 4, CLAIM_PHASE);
        CurrentClaimReceiver receiver =
            new CurrentClaimReceiver(core, claims, recorder, commerceFloor);
        Claim.Purchase memory p = _purchase(id, 60, PRICE);
        p.mint.initialRecipient = address(receiver);
        (Native.NativeSettlementCandidate memory c, bytes32 auth) = claims.previewPublicPurchase(p);
        require(
            auth == _publicAuthorizationId(p), "literal public identity includes delivery recipient"
        );
        bytes32 key = recorder.settlementKey(address(claims), c.executionBinding.executionId);
        receiver.expectExecution(c.executionBinding.executionId, key);
        CurrentClaimCallVm(address(vm))
            .expectCall(
                address(receiver), 0, abi.encodeWithSelector(receiver.onERC721Received.selector), 2
            );
        bytes memory saved = _signedSafeCall(
            PRICE + REVEAL_FEE + SURPLUS, abi.encodeCall(claims.purchasePublic, (p))
        );
        uint256 before_ = address(payerSafe).balance;
        uint256 operationNonce = manager.nextOperationNonce();
        _assertSafeTargetFailure(_expectSavedFailure(saved, p, c, auth));
        require(
            receiver.deliveries() == 0 && receiver.receivedToken() == 0
                && core.balanceOf(address(receiver)) == 0,
            "rejected recipient and Core state roll back too"
        );
        _assertNoCommerceFloorReceipt(key);
        receiver.acceptDelivery();
        _executeSaved(saved);
        Immediate.Receipt memory r = claims.executionReceipt(c.executionBinding.executionId);
        _assertReceipt(p, c, r, auth, 0, SURPLUS);
        _assertMoney(before_, PRICE, 1, SURPLUS);
        require(
            receiver.deliveries() == 1 && receiver.receivedToken() == r.tokenId
                && core.balanceOf(address(receiver)) == 1
                && manager.nextOperationNonce() == operationNonce + 1 && _counter(p) == 1
                && claims.refundableBalance(id, address(payerSafe)) == SURPLUS,
            "identical Safe envelope pays and mints exactly once after receiver repair"
        );
    }
}
