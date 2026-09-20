// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./StreamCurrentSafeGovernanceFixture.sol";
import "../../smart-contracts/domains/mint/StreamNativeFixedPriceSaleAdapter.sol";
import "../../smart-contracts/domains/mint/StreamOperatorDistribution.sol";
import "../../smart-contracts/domains/mint/StreamImmediateSaleEntropyPolicy.sol";
import {
    StreamPrimarySaleSettlement
} from "../../smart-contracts/domains/revenue/StreamPrimarySaleSettlement.sol";
import "../../smart-contracts/integrations/delegation/NFTdelegation.sol";
import {
    IStreamEntropyCollectionPolicy as Policy
} from "../../smart-contracts/interfaces/stream/entropy/IStreamEntropyCollectionPolicy.sol";
import {
    IStreamArtistContentAuthority as ContentAuthority
} from "../../smart-contracts/interfaces/stream/artist/IStreamArtistContentAuthority.sol";
import {
    IStreamArtistContentHostEvidence
} from "../../smart-contracts/interfaces/stream/artist/IStreamArtistContentHostEvidence.sol";
import {
    StreamArtistContentTypes as Content
} from "../../smart-contracts/interfaces/stream/artist/StreamArtistContentTypes.sol";
import {
    StreamArtistSaleTypes as SaleTerms
} from "../../smart-contracts/interfaces/stream/artist/StreamArtistSaleTypes.sol";

/// @dev Actual receiver boundary: Core forbids burn inside mint completion, but permits it later.
contract CurrentTerminalEntropyReceiver is IERC721Receiver {
    error TerminalRecipientRejected();
    StreamCore public immutable core;
    address public immutable controller;
    uint256 public token;
    bool public accepting;
    bool public mintBurnRefused;
    bool public laterBurned;
    address public originalCoordinator;

    constructor(StreamCore core_) {
        core = core_;
        controller = msg.sender;
    }

    function accept() external {
        require(msg.sender == controller, "receiver controller");
        accepting = true;
    }

    function onERC721Received(address, address from, uint256 id, bytes calldata)
        external
        returns (bytes4)
    {
        require(msg.sender == address(core), "original Core callback");
        if (from == address(0)) {
            (bool ok, bytes memory reason) = address(core).call(abi.encodeCall(core.burn, (id)));
            require(
                !ok
                    && keccak256(reason)
                        == keccak256(
                            abi.encodeWithSelector(StreamCore.MintExecutionInProgress.selector)
                        ),
                "original mint callback burn guard"
            );
            if (!accepting) revert TerminalRecipientRejected();
            mintBurnRefused = true;
            token = id;
            originalCoordinator = core.coordinatorAtMint(id);
        } else {
            require(accepting && id == token && from == address(this), "post-mint custody callback");
            core.burn(id);
            laterBurned = true;
        }
        return IERC721Receiver.onERC721Received.selector;
    }

    function burnThroughCustodyCallback() external {
        require(msg.sender == controller, "receiver controller");
        core.safeTransferFrom(address(this), address(this), token, bytes("post-mint burn"));
    }
}

/// @notice Genuine current Artist/Executor/entropy and paid mint/distribution with original Safes.
/// @dev Only the inherited external entropy provider and explicit receiver behavior are test boundaries.
abstract contract CurrentTerminalEntropyFixture is StreamCurrentSafeGovernanceFixture {
    bytes32 internal constant TERMINAL_PHASE = keccak256("current terminal native phase");
    bytes32 internal constant DISTRIBUTION_PHASE = keccak256("current terminal distribution");
    bytes32 internal constant SUPPLY = keccak256("terminal distribution supply");
    bytes32 internal constant RECIPIENT = keccak256("terminal distribution recipient");
    bytes32 internal constant FAMILY = keccak256("6529STREAM_ENTROPY_CONFIGURATION_V1");
    bytes32 internal constant SALT = keccak256("current terminal declared salt");
    uint256 internal constant PRICE = 1000;
    uint256 internal constant FEE = 100;
    uint256 internal constant EXCESS = 37;
    OfficialSafe internal terminalArtist;
    OfficialSafe internal terminalPayer;
    OfficialSafe internal terminalOperator;
    uint256[] internal terminalKeys;
    StreamPrimarySaleSettlement internal recorder;
    StreamNativeFixedPriceSaleAdapter internal nativeSale;
    StreamOperatorDistribution internal distributor;
    Policy internal policy;
    bytes32 internal saleId;
    IStreamOperatorDistribution.Program internal program;
    IStreamMintManager.MintBatch internal distributionBatch;

    function _constructTerminal() internal {
        terminalKeys.push(0x7E4A01);
        terminalKeys.push(0x7E4A02);
        SafeComponents memory c = deploySafeComponents("1.4.1");
        terminalArtist = createOfficialSafe(c, safeOwnerAddresses(terminalKeys), 2, 7101);
        terminalPayer = createOfficialSafe(c, safeOwnerAddresses(terminalKeys), 2, 7102);
        terminalOperator = createOfficialSafe(c, safeOwnerAddresses(terminalKeys), 2, 7103);
        _deployCurrentStack(address(terminalArtist), vm.addr(PLATFORM_KEY));
        policy = Policy(address(entropy));
        _installGovernorSafe(terminalOperator, terminalKeys);
        vm.deal(address(terminalPayer), 1 ether);
        vm.deal(address(terminalOperator), 1 ether);
        _saleConsent();
    }

    function _artistProof(bytes32 digest) internal override returns (bytes memory) {
        return safeThresholdSignature(
            terminalKeys, safeMessageDigest(terminalArtist, abi.encode(digest))
        );
    }

    function _fixtureSaleConsentScope() internal pure override returns (uint8) {
        return 1;
    }

    function _revealPrincipals()
        internal
        view
        override
        returns (StreamRevealActivationPlan.Principals memory)
    {
        return StreamRevealActivationPlan.Principals(
            address(this), address(nativeSale), address(governanceRoot)
        );
    }

    function _configureInitialRevealPolicy() internal override {
        provider.setFee(FEE);
        entropy.configureCollectionRevealPolicy(
            1, 0, keccak256("ROLE_ENTROPY_REVEAL_OWNER"), 100, FEE
        );
    }

    function _deployAdditionalProducts() internal override {
        recorder = StreamPrimarySaleSettlement(
            payable(_artistArtifactCreate(
                    "smart-contracts/domains/revenue/StreamPrimarySaleSettlement.sol:StreamPrimarySaleSettlement",
                    abi.encode(primaryResolver, address(registry), revenueEscrow)
                ))
        );
        IStreamNativeRefundDelegatedClaims.DelegationDeployment memory delegation;
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
                        delegation
                    )
                ))
        );
        distributor = StreamOperatorDistribution(
            payable(_artistArtifactCreate(
                    "smart-contracts/domains/mint/StreamOperatorDistribution.sol:StreamOperatorDistribution",
                    abi.encode(
                        StreamOperatorDistribution.DeploymentConfig(
                            address(core),
                            address(manager),
                            address(registry),
                            address(executor),
                            address(new DelegationManagementContract()),
                            2,
                            keccak256("current terminal distribution manifest")
                        )
                    )
                ))
        );
        _assertDeployableProductionInstance(address(recorder));
        _assertDeployableProductionInstance(address(nativeSale));
        _assertDeployableProductionInstance(address(distributor));
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
        rows[0] = GovernanceActionPolicyEntry(
            1,
            address(entropy),
            Policy.configureCollectionEntropyPolicy.selector,
            address(entropy).codehash,
            keccak256(abi.encode(DEPLOYMENT_HASH, address(entropy))),
            1,
            0,
            0,
            0
        );
        rows[1] = GovernanceActionPolicyEntry(
            2,
            address(entropy),
            Policy.freezeCollectionEntropyPolicy.selector,
            address(entropy).codehash,
            keccak256(abi.encode(DEPLOYMENT_HASH, address(entropy))),
            1,
            0,
            0,
            0
        );
    }

    function terminalTime() external view returns (uint64) {
        return uint64(block.timestamp);
    }

    function _configureAdditionalProducts() internal override {
        StreamModuleRegistration[] memory rows = new StreamModuleRegistration[](2);
        rows[0] = StreamModuleRegistration(
            address(nativeSale),
            keccak256("NATIVE_PRIMARY_SALE_ADAPTER"),
            keccak256("6529STREAM_UNIVERSAL_SETTLEMENT_V1"),
            type(IStreamNativeSaleBinding).interfaceId,
            500_000,
            address(nativeSale).codehash,
            DEPLOYMENT_HASH,
            keccak256("terminal native current module"),
            "urn:stream:current:terminal-native"
        );
        rows[1] = StreamModuleRegistration(
            address(distributor),
            distributor.MODULE_TYPE(),
            keccak256("6529STREAM_OPERATOR_DISTRIBUTION_V1"),
            type(IStreamOperatorDistribution).interfaceId,
            300_000,
            address(distributor).codehash,
            DEPLOYMENT_HASH,
            keccak256(distributor.moduleManifestBytes()),
            "urn:stream:current:terminal-distribution"
        );
        (GovernanceCall[] memory calls, bytes[] memory data) =
            StreamCurrentStackPlan.registrationCalls(registry, rows);
        (bytes32 scope, bytes32 old_, bytes32 next) = StreamGovernanceBootstrap.deriveBatchTransitionHashes(
            calls, StreamGovernanceBootstrap.governanceCallsHash(calls)
        );
        uint64 ready = this.terminalTime() + uint64(executor.minimumDelay(1));
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
                    old_,
                    next,
                    ready,
                    ready + 7 days,
                    GOVERNANCE_REASON,
                    "urn:stream:current:terminal-admission",
                    DEPLOYMENT_HASH
                )
            )
        );
        vm.warp(ready);
        executor.executeGovernanceBatch(abi.decode(scheduled, (bytes32)), calls, data);
        _configureMintPhase(TERMINAL_PHASE, address(nativeSale));
        saleId = nativeSale.registerSale(
            IStreamNativeFixedPriceSaleAdapter.SaleConfig(
                1,
                TERMINAL_PHASE,
                PRICE,
                0,
                this.terminalTime() + 365 days,
                manager.phasePolicyHash(1, TERMINAL_PHASE),
                primaryResolver.resolvePrimaryAssignment(1, 0, PRIMARY_REVENUE_CLASS).assignmentHash
            )
        );
        nativeSale.transferOwnership(address(executor));
        _configureDistribution();
    }

    function _configureDistribution() private {
        program = IStreamOperatorDistribution.Program(
            address(terminalOperator),
            0,
            SUPPLY,
            RECIPIENT,
            2,
            1,
            IStreamOperatorDistribution.DeliveryMode.FAILURE_ISOLATED,
            false
        );
        distributionBatch.collectionId = 1;
        distributionBatch.phaseId = DISTRIBUTION_PHASE;
        for (uint256 i; i < 2; ++i) {
            distributionBatch.initialRecipients.push(address(distributor));
            distributionBatch.beneficiaries
                .push(i == 0 ? address(terminalPayer) : address(terminalOperator));
            distributionBatch.tokenData.push(TOKEN_DATA);
            distributionBatch.mintCommitments
                .push(keccak256(abi.encode("terminal distribution", i)));
        }
        distributionBatch.contextHash = distributor.sliceHash(0, distributionBatch);
        distributionBatch.authorizationId = distributor.sliceAuthorization(1, DISTRIBUTION_PHASE, 0);
        program.slicesRoot = distributionBatch.contextHash;
        bytes32[] memory ids = new bytes32[](2);
        ids[0] = SUPPLY;
        ids[1] = RECIPIENT;
        IStreamMintManager.MintCounterConfig[] memory configs =
            new IStreamMintManager.MintCounterConfig[](2);
        configs[0] = IStreamMintManager.MintCounterConfig(
            true,
            IStreamMintManager.CounterKeyMode.CONSTANT,
            IStreamMintLedger.CounterCapMode.STATIC,
            IStreamMintLedger.CounterDeltaMode.STATIC,
            2,
            1,
            keccak256("terminal supply config")
        );
        configs[1] = IStreamMintManager.MintCounterConfig(
            true,
            IStreamMintManager.CounterKeyMode.RECIPIENT,
            IStreamMintLedger.CounterCapMode.STATIC,
            IStreamMintLedger.CounterDeltaMode.STATIC,
            1,
            1,
            keccak256("terminal recipient config")
        );
        IStreamMintManager.MintPhaseConfig memory config = IStreamMintManager.MintPhaseConfig(
            false,
            0,
            0,
            2,
            distributor.programHash(1, DISTRIBUTION_PHASE, program),
            keccak256("terminal two-recipient manifest")
        );
        IStreamMintManager.MintGateConfig memory gate;
        _recordFixturePolicy(
            DISTRIBUTION_PHASE,
            manager.previewPhasePolicyHash(
                1, DISTRIBUTION_PHASE, config, gate, ids, configs, new address[](0)
            )
        );
        manager.configurePhase(1, DISTRIBUTION_PHASE, config, gate, ids, configs);
        address[] memory enabled = new address[](1);
        enabled[0] = address(distributor);
        _recordFixturePolicy(
            DISTRIBUTION_PHASE,
            manager.previewPhasePolicyHash(
                1, DISTRIBUTION_PHASE, config, gate, ids, configs, enabled
            )
        );
        manager.setPhaseExecutor(1, DISTRIBUTION_PHASE, address(distributor), true);
        distributionBatch.expectedPolicyHash = manager.phasePolicyHash(1, DISTRIBUTION_PHASE);
    }

    function _safe(OfficialSafe account, address target, uint256 value, bytes memory data)
        internal
    {
        uint256 nonce = account.nonce();
        require(
            executeSafe(account, terminalKeys, target, value, data, 0)
                && account.nonce() == nonce + 1,
            "actual terminal Safe CALL consumes one original nonce"
        );
    }

    function _nextArtistAuthorization() private view returns (T.Authorization memory a) {
        a.nonce =
        IStreamArtistIdentityOwner(artistSuite.owners[2]).identity(fixtureArtistId).nonceHint;
        a.time = uint64(block.timestamp + 1 days);
    }

    function _saleConsent() private {
        SaleTerms.Consent memory terms = SaleTerms.Consent(
            1, address(nativeSale), saleId, nativeSale.saleRecord(saleId).configHash
        );
        _safe(
            terminalArtist,
            address(artists),
            0,
            abi.encodeCall(
                IStreamArtistSaleAuthority.recordSaleConsent, (terms, _nextArtistAuthorization())
            )
        );
        (bool ok, bytes32 record) = artists.isSaleConsented(1, saleId, terms.saleConfigHash);
        require(
            ok && record != 0
                && artists.saleConsentRecord(record).signer == address(terminalArtist),
            "actual exact native sale consent"
        );
    }

    function _policyInput(bool disabled) internal view returns (Policy.PolicyInput memory p) {
        p.renderRequirement = Policy.RenderRequirement.NOT_REQUIRED;
        if (disabled) return p;
        p.mode = Policy.Mode.ASYNC;
        p.provider = address(provider);
        p.collectionSalt = SALT;
        p.publicRequests = true;
        p.timeoutBlocks = 100;
        p.reveal = IStreamRevealFeeEscrow.CollectionRevealPolicy(
            true, 0, keccak256("ROLE_ENTROPY_REVEAL_OWNER"), 100, FEE
        );
    }

    function _policyHash(Policy.PolicyInput memory p, uint32 epoch) private view returns (bytes32) {
        return keccak256(
            abi.encode(
                keccak256("6529STREAM_ENTROPY_COLLECTION_POLICY_V2"),
                block.chainid,
                address(entropy),
                address(core),
                uint256(1),
                p.mode,
                p.securityClass,
                p.renderRequirement,
                p.provider,
                p.provider == address(0) ? bytes32(0) : p.provider.codehash,
                p.provider == address(0) ? bytes32(0) : provider.streamEntropyProviderConfigHash(),
                epoch,
                p.collectionSalt,
                p.publicRequests,
                p.timeoutBlocks,
                p.reveal.declared,
                p.reveal.requestMode,
                p.reveal.revealOwnerRole,
                p.reveal.requestSLOBlocks,
                bytes32(0),
                bytes32(0),
                uint16(0)
            )
        );
    }

    function _contentConsent(bytes32 next) private returns (bytes32 record) {
        Content.Consent memory p = Content.Consent(1, address(entropy), FAMILY, next);
        T.Authorization memory a = _nextArtistAuthorization();
        uint64 observed = this.terminalTime();
        record = keccak256(
            abi.encode(
                keccak256("6529STREAM_ARTIST_CONTENT_CONSENT_RECORD_V1"),
                block.chainid,
                address(artists),
                address(entropy),
                address(core),
                uint256(1),
                FAMILY,
                next,
                fixtureArtistId,
                address(terminalArtist),
                uint8(1),
                a.nonce,
                observed
            )
        );
        vm.recordLogs();
        _safe(
            terminalArtist,
            address(artists),
            0,
            abi.encodeCall(ContentAuthority.recordContentConsent, (p, a))
        );
        Vm.Log[] memory logs = vm.getRecordedLogs();
        uint256 count;
        for (uint256 i; i < logs.length; ++i) {
            if (
                logs[i].emitter == artistSuite.owners[6] && logs[i].topics.length == 4
                    && logs[i].topics[0]
                        == keccak256(
                            "ArtistContentConsentRecorded(uint16,uint256,bytes32,address,bytes32,uint8,uint256,uint64,bytes32)"
                        )
            ) {
                require(
                    logs[i].topics[1] == bytes32(uint256(1)) && logs[i].topics[2] == FAMILY
                        && logs[i].topics[3] == bytes32(uint256(uint160(address(terminalArtist))))
                        && keccak256(logs[i].data)
                            == keccak256(
                                abi.encode(uint16(1), next, uint8(1), a.nonce, observed, record)
                            ),
                    "original op17 consent record and receipt"
                );
                ++count;
            }
        }
        require(
            count == 1
                && IStreamArtistContentHostEvidence(address(artists))
                    .contentConsentEvidenceForHost(1, address(entropy), FAMILY, next) == record,
            "actual host-bound original Artist evidence"
        );
    }

    function _artistState() private view returns (bytes32) {
        T.Snapshot[7] memory snapshots;
        for (uint256 i; i < 7; ++i) {
            snapshots[i] = IStreamArtistOwner(artistSuite.owners[i]).ownerStateSnapshotV2();
        }
        return keccak256(abi.encode(snapshots));
    }

    function _deniedAction(bytes32 id, bytes memory data) private {
        bytes32 artistState = _artistState();
        bytes32 entropyState = keccak256(abi.encode(policy.collectionEntropyPolicy(1)));
        (bool ok, bytes memory reason) =
            address(executor).call(abi.encodeCall(executor.executeGovernanceAction, (id, data)));
        require(
            !ok
                && keccak256(reason)
                    == keccak256(
                        abi.encodeWithSelector(
                            Policy.CollectionPolicyDependency.selector, address(artists)
                        )
                    ),
            "exact missing or inapplicable original Artist consent refusal"
        );
        require(
            executor.governanceAction(id).status == GovernanceActionStatus.SCHEDULED
                && _artistState() == artistState
                && keccak256(abi.encode(policy.collectionEntropyPolicy(1))) == entropyState,
            "failed executing action preserves all original state"
        );
    }

    function _configureTerminal(bool disabled, bool negatives) internal returns (bytes32 hash) {
        Policy.PolicyInput memory input = _policyInput(disabled);
        Policy.PolicyRecord memory before_ = policy.collectionEntropyPolicy(1);
        uint32 epoch = before_.providerEpoch + (disabled ? 1 : 0);
        hash = _policyHash(input, epoch);
        (bytes32 scope, bytes32 old_, bytes32 next, bytes32 content) =
            policy.collectionEntropyPolicyTransition(1, input);
        require(
            content == keccak256(abi.encode(FAMILY, hash, false)),
            "literal explicit content state excludes fee"
        );
        bytes memory data =
            abi.encodeCall(policy.configureCollectionEntropyPolicy, (uint256(1), input));
        GovernanceActionRequest memory request =
            _governanceRequest(1, address(entropy), data, scope, old_, next);
        bytes32 id = _scheduleAsGovernor(request);
        vm.warp(request.notBefore);
        if (negatives) _deniedAction(id, data);
        bytes32 consent = _contentConsent(content);
        vm.recordLogs();
        _executeAsGovernor(id, data);
        Vm.Log[] memory logs = vm.getRecordedLogs();
        Policy.PolicyRecord memory configured = policy.collectionEntropyPolicy(1);
        require(
            configured.configured && configured.explicitPolicy && !configured.frozen
                && configured.mode == input.mode && configured.securityClass == input.securityClass
                && configured.renderRequirement == input.renderRequirement
                && configured.revision == 1 && configured.providerEpoch == epoch
                && configured.policyHash == hash && configured.contentStateHash == content
                && configured.lastActionId == id && configured.artistConsentRecord == consent,
            "exact configured current policy and consumed authorizations"
        );
        _configuredReceipt(logs, input, hash, epoch, id, consent);
        if (negatives) _actionReplay(id, data);

        (scope, old_, next, content) = policy.freezeCollectionEntropyPolicyTransition(1);
        require(
            content == keccak256(abi.encode(FAMILY, hash, true)), "separate frozen content state"
        );
        data = abi.encodeCall(policy.freezeCollectionEntropyPolicy, (uint256(1)));
        request = _governanceRequest(2, address(entropy), data, scope, old_, next);
        id = _scheduleAsGovernor(request);
        vm.warp(request.notBefore);
        if (negatives) _deniedAction(id, data);
        bytes32 freezeConsent = _contentConsent(content);
        require(freezeConsent != consent, "configuration consent cannot substitute for freeze");
        vm.recordLogs();
        _executeAsGovernor(id, data);
        logs = vm.getRecordedLogs();
        Policy.PolicyRecord memory frozen = policy.collectionEntropyPolicy(1);
        require(
            frozen.frozen && frozen.revision == 2 && frozen.policyHash == hash
                && frozen.providerEpoch == epoch && frozen.artistConsentRecord == freezeConsent
                && frozen.lastActionId == id && frozen.contentStateHash == content,
            "original separate governance freeze preserves policy and epoch"
        );
        uint256 count;
        for (uint256 i; i < logs.length; ++i) {
            if (
                logs[i].emitter == address(entropy) && logs[i].topics.length == 3
                    && logs[i].topics[0]
                        == keccak256(
                            "CollectionEntropyPolicyFrozen(uint16,uint256,bytes32,uint64,bytes32,bytes32)"
                        )
            ) {
                require(
                    logs[i].topics[1] == bytes32(uint256(1)) && logs[i].topics[2] == hash
                        && keccak256(logs[i].data)
                            == keccak256(abi.encode(uint16(2), uint64(2), id, freezeConsent)),
                    "exact current freeze receipt"
                );
                ++count;
            }
        }
        require(count == 1, "one actual freeze receipt");
        if (negatives) _actionReplay(id, data);
    }

    function _configuredReceipt(
        Vm.Log[] memory logs,
        Policy.PolicyInput memory p,
        bytes32 hash,
        uint32 epoch,
        bytes32 id,
        bytes32 consent
    ) private view {
        uint256 count;
        for (uint256 i; i < logs.length; ++i) {
            if (
                logs[i].emitter == address(entropy) && logs[i].topics.length == 3
                    && logs[i].topics[0]
                        == keccak256(
                            "CollectionEntropyPolicyConfigured(uint16,uint256,bytes32,uint64,uint32,(uint8,uint8,uint8,address,bytes32,bool,uint64,(bool,uint8,bytes32,uint64,uint256),uint16,bytes32),bytes32,bytes32,bytes32,bytes32,bytes32)"
                        )
            ) {
                require(
                    logs[i].topics[1] == bytes32(uint256(1)) && logs[i].topics[2] == hash
                        && keccak256(logs[i].data)
                            == keccak256(
                                abi.encode(
                                    uint16(2),
                                    uint64(1),
                                    epoch,
                                    p,
                                    p.provider == address(0) ? bytes32(0) : p.provider.codehash,
                                    p.provider == address(0)
                                        ? bytes32(0)
                                        : provider.streamEntropyProviderConfigHash(),
                                    bytes32(0),
                                    id,
                                    consent
                                )
                            ),
                    "exact current configure receipt"
                );
                ++count;
            }
        }
        require(count == 1, "one actual configuration receipt");
    }

    function _actionReplay(bytes32 id, bytes memory data) private {
        bytes32 state = keccak256(abi.encode(policy.collectionEntropyPolicy(1), _artistState()));
        (bool ok, bytes memory reason) =
            address(executor).call(abi.encodeCall(executor.executeGovernanceAction, (id, data)));
        require(
            !ok
                && keccak256(reason)
                    == keccak256(
                        abi.encodeWithSelector(
                            IStreamGovernanceExecutor.GovernanceActionNotScheduled.selector, id
                        )
                    )
                && keccak256(abi.encode(policy.collectionEntropyPolicy(1), _artistState()))
                    == state,
            "exact executed-action replay denial preserves all original state"
        );
    }

    function _execution(address recipient)
        private
        returns (IStreamNativeFixedPriceSaleAdapter.SaleExecutionData memory e)
    {
        e.tokenData = TOKEN_DATA;
        e.authorization = IStreamNativeFixedPriceSaleAdapter.SaleAuthorization(
            saleId,
            nativeSale.saleRecord(saleId).configHash,
            address(terminalPayer),
            address(terminalPayer),
            recipient,
            address(terminalArtist),
            keccak256(TOKEN_DATA),
            keccak256("current terminal paid commitment"),
            1,
            keccak256("current terminal paid nonce"),
            this.terminalTime() + 1 days,
            _nativePrimaryPolicyHash()
        );
        bytes32 digest = nativeSale.authorizationDigest(e.authorization);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(PLATFORM_KEY, digest);
        e.platformSignature = abi.encodePacked(r, s, v);
        e.artistSignature = _artistProof(digest);
    }

    function _safePayload(OfficialSafe account, address target, uint256 value, bytes memory data)
        private
        returns (bytes memory)
    {
        bytes32 digest = account.getTransactionHash(
            target, value, data, 0, 0, 0, 0, address(0), address(0), account.nonce()
        );
        return abi.encodeCall(
            OfficialSafe.execTransaction,
            (
                target,
                value,
                data,
                uint8(0),
                0,
                0,
                0,
                address(0),
                payable(address(0)),
                safeThresholdSignature(terminalKeys, digest)
            )
        );
    }

    function _exactSafe(OfficialSafe account, bytes memory payload) private {
        uint256 nonce = account.nonce();
        (bool ok, bytes memory result) = address(account).call(payload);
        require(
            ok && result.length == 32 && abi.decode(result, (bool)) && account.nonce() == nonce + 1,
            "one original signed Safe transaction"
        );
    }

    function _safeRejected(OfficialSafe account, bytes memory payload) private {
        uint256 nonce = account.nonce();
        uint256 balance = address(account).balance;
        bytes32 artistState = _artistState();
        (bool ok, bytes memory result) = address(account).call(payload);
        require(
            !ok && keccak256(result) == keccak256(abi.encodeWithSignature("Error(string)", "GS013"))
                && account.nonce() == nonce && address(account).balance == balance
                && _artistState() == artistState,
            "original 1.4 target failure restores Safe nonce, value and Artist state"
        );
    }

    function _counter(bytes32 phase, bytes32 counter, address recipient)
        private
        view
        returns (bytes32)
    {
        bytes32 domain = keccak256("6529STREAM_MINT_COUNTER_SUBJECT_V1");
        bytes32 subject = recipient == address(0)
            ? keccak256(
                abi.encode(
                    domain, block.chainid, address(ledger), uint8(1), uint256(1), phase, counter
                )
            )
            : keccak256(abi.encode(domain, block.chainid, address(ledger), uint8(3), recipient));
        return keccak256(
            abi.encode(
                keccak256("6529STREAM_MINT_COUNTER_VALUE_KEY_V1"),
                address(manager),
                uint256(1),
                phase,
                counter,
                subject
            )
        );
    }

    function _unmintedNative(
        StreamNativeSettlementTypes.NativeSettlementCandidate memory c,
        IStreamNativeFixedPriceSaleAdapter.SaleExecutionData memory e
    ) private view {
        bytes32 authorization = keccak256(
            abi.encode(
                keccak256("6529STREAM_MINT_TICKET_AUTHORIZATION_V1"),
                c.executionBinding.saleAuthorizationDigest
            )
        );
        require(
            core.totalSupply() == 0 && core.collectionMintedEver(1) == 0
                && core.collectionNextSerial(1) == 1 && core.lastAllocatedTokenId() == 0
                && core.pendingPreparedMintTokenId() == 0 && !core.preparedMint(1).exists
                && core.coordinatorAtMint(1) == address(0) && core.tokenData(1).length == 0,
            "failed callback rolls back original Core identity and prepared state"
        );
        require(
            manager.nextOperationNonce() == 0
                && !manager.isOperationRootUsed(c.operationIdentityCommitment)
                && !ledger.isManagerAuthorizationUsed(address(manager), authorization)
                && ledger.counterValue(_counter(TERMINAL_PHASE, keccak256("supply"), address(0)))
                    == 0
                && !nativeSale.authorizationUsed(address(terminalArtist), e.authorization.nonce)
                && nativeSale.executionStatus(c.executionBinding.executionId) == 0
                && nativeSale.executionIdByNonce(saleId, 1) == 0,
            "failed callback preserves original mint and commercial replay lanes"
        );
        require(
            wallet.balance == 0 && recorder.totalOfficialSettled(address(0)) == 0
                && address(recorder).balance == 0 && address(nativeSale).balance == 0
                && nativeSale.refundLiability() == 0 && revenueEscrow.totalOwed(address(0)) == 0
                && entropy.revealFeeEscrow(1) == 0 && address(terminalPayer).balance == 1 ether
                && entropy.tokenEntropyStatus(1) == StreamEntropyStatus.NONE
                && entropy.pendingRequestCount() == 0 && provider.nextRequestId() == 1,
            "failed callback preserves payment, liabilities and entropy state"
        );
    }

    function _paid(bool disabled, bool callback) internal returns (uint256 token) {
        address recipient = address(terminalPayer);
        CurrentTerminalEntropyReceiver receiver;
        if (callback) {
            receiver = new CurrentTerminalEntropyReceiver(core);
            recipient = address(receiver);
        }
        IStreamNativeFixedPriceSaleAdapter.SaleExecutionData memory e = _execution(recipient);
        StreamNativeSettlementTypes.NativeSettlementCandidate memory c =
            nativeSale.previewExecution(e);
        uint256 fee = disabled ? 0 : FEE;
        bytes memory data = abi.encodeCall(nativeSale.purchase, (e));
        bytes memory payload =
            _safePayload(terminalPayer, address(nativeSale), PRICE + fee + EXCESS, data);
        if (callback) {
            vm.prank(address(terminalPayer));
            (bool ok, bytes memory reason) =
                address(nativeSale).call{ value: PRICE + fee + EXCESS }(data);
            require(
                !ok
                    && keccak256(reason)
                        == keccak256(
                            abi.encodeWithSelector(
                                CurrentTerminalEntropyReceiver.TerminalRecipientRejected.selector
                            )
                        ),
                "exact original receiver boundary, not unrelated sale failure"
            );
            _unmintedNative(c, e);
            _safeRejected(terminalPayer, payload);
            _unmintedNative(c, e);
            receiver.accept();
        }
        vm.recordLogs();
        _exactSafe(terminalPayer, payload);
        Vm.Log[] memory logs = vm.getRecordedLogs();
        token = core.lastAllocatedTokenId();
        require(
            token == 1 && core.ownerOf(token) == recipient && core.totalSupply() == 1
                && core.collectionMintedEver(1) == 1 && core.collectionNextSerial(1) == 2
                && keccak256(core.tokenData(1)) == keccak256(TOKEN_DATA),
            "actual current paid token"
        );
        bytes32 authorization = keccak256(
            abi.encode(
                keccak256("6529STREAM_MINT_TICKET_AUTHORIZATION_V1"),
                c.executionBinding.saleAuthorizationDigest
            )
        );
        require(
            manager.nextOperationNonce() == 1
                && manager.isOperationRootUsed(c.operationIdentityCommitment)
                && ledger.isManagerAuthorizationUsed(address(manager), authorization)
                && ledger.counterValue(_counter(TERMINAL_PHASE, keccak256("supply"), address(0)))
                    == 1
                && nativeSale.authorizationUsed(address(terminalArtist), e.authorization.nonce)
                && nativeSale.executionStatus(c.executionBinding.executionId) == 2
                && nativeSale.executionIdByNonce(saleId, 1) == c.executionBinding.executionId,
            "original paid authorization and counter consumed once"
        );
        bytes32 key = recorder.settlementKey(address(nativeSale), c.executionBinding.executionId);
        StreamPrimarySettlementTypes.PrimarySettlementResult memory settled =
            recorder.settlementResult(key);
        require(
            recorder.settlementConsumed(key) && settled.amount == PRICE && settled.wallet == wallet
                && settled.operationIdentityCommitment == c.operationIdentityCommitment
                && recorder.totalOfficialSettled(address(0)) == PRICE && wallet.balance == PRICE
                && address(recorder).balance == 0 && revenueEscrow.totalOwed(address(0)) == 0,
            "original official revenue and split wallet conserved"
        );
        require(
            address(terminalPayer).balance == 1 ether - PRICE - fee - EXCESS
                && entropy.revealFeeEscrow(1) == fee && entropy.totalRevealFeeEscrows() == fee
                && address(entropy).balance == fee && address(provider).balance == 0
                && nativeSale.refundableBalance(saleId, address(terminalPayer)) == EXCESS
                && nativeSale.refundLiability() == EXCESS && address(nativeSale).balance == EXCESS,
            "terminal policy retains exact captured fee and payer-owned excess"
        );
        _noTokenRequest(logs, 1);
        _transferReceipt(logs, address(0), recipient, token);
        _terminal(token, disabled, false);
        vm.prank(address(terminalPayer));
        (bool replay, bytes memory failure) =
            address(nativeSale).call{ value: PRICE + fee + EXCESS }(data);
        require(
            !replay
                && keccak256(failure)
                    == keccak256(
                        abi.encodeWithSelector(
                            IStreamNativeFixedPriceSaleAdapter.NativeAuthorizationUsed.selector,
                            address(terminalArtist),
                            e.authorization.nonce
                        )
                    ),
            "exact paid authorization replay denial"
        );
        _safe(
            terminalPayer,
            address(nativeSale),
            0,
            abi.encodeCall(nativeSale.claimRefund, (saleId, address(terminalPayer)))
        );
        require(
            address(terminalPayer).balance == 1 ether - PRICE - fee
                && nativeSale.refundLiability() == 0 && address(nativeSale).balance == 0
                && nativeSale.refundableBalance(saleId, address(terminalPayer)) == 0,
            "original Safe pull refund closes only buyer credit"
        );
        if (callback) {
            require(
                receiver.mintBurnRefused() && receiver.originalCoordinator() == address(entropy),
                "actual callback observes original coordinator and retains burn guard"
            );
            receiver.burnThroughCustodyCallback();
            require(
                receiver.laterBurned() && core.totalSupply() == 0
                    && core.collectionMintedEver(1) == 1 && core.collectionNextSerial(1) == 2
                    && wallet.balance == PRICE,
                "post-mint custody burn preserves lifetime identity and settled price"
            );
            _terminal(token, disabled, true);
            require(
                StreamImmediateSaleEntropyPolicy.requireTerminalToken(
                    address(core), address(entropy), 1, token
                ),
                "actual terminal checker accepts original genuinely burned identity"
            );
        }
    }

    function _terminal(uint256 token, bool disabled, bool burned) internal {
        (bool exists, uint256 collection, uint256 serial, bool actualBurned) =
            core.tokenCollectionIdentity(token);
        require(
            exists && collection == 1 && serial == token && actualBurned == burned
                && core.coordinatorAtMint(token) == address(entropy)
                && core.tokenLifecycle(token) == (burned ? 3 : 2),
            "permanent original current token identity"
        );
        (bool ok, bytes memory raw) =
            address(entropy).staticcall(abi.encodeCall(entropy.tokenEntropy, (token)));
        require(ok && raw.length == 256, "original eight-word entropy read");
        uint256[8] memory words = abi.decode(raw, (uint256[8]));
        Policy.PolicyRecord memory p = policy.collectionEntropyPolicy(1);
        uint8 status = disabled ? 1 : 2;
        (bytes32 seed, bool finalized) = entropy.tokenSeed(token);
        require(
            words[0] == status && uint8(entropy.tokenEntropyStatus(token)) == status
                && words[1] == 0 && seed == 0 && !finalized && words[5] == 0 && words[6] == 0
                && words[7] == 0 && words[2] == (disabled ? 0 : uint256(uint160(address(provider))))
                && words[3] == p.providerEpoch
                && bytes32(words[4])
                    == (disabled ? bytes32(0) : provider.streamEntropyProviderConfigHash())
                && p.frozen && entropy.nonterminalTokenCount(1) == 0,
            "terminal nonrandom state has no fabricated request, seed or finalization"
        );
        (ok, raw) = address(entropy).call(abi.encodeCall(entropy.requestEntropy, (token)));
        bytes memory expected = burned
            ? abi.encodeWithSelector(StreamEntropyCoordinator.InvalidToken.selector, token)
            : abi.encodeWithSelector(
                StreamEntropyCoordinator.InvalidStatus.selector, StreamEntropyStatus(status)
            );
        require(
            !ok && keccak256(raw) == keccak256(expected),
            "exact original terminal token request denial"
        );
    }

    function _noTokenRequest(Vm.Log[] memory logs, uint256 registrations) private view {
        uint256 count;
        uint256 seen;
        bytes32 expectedPolicy = policy.collectionEntropyPolicy(1).policyHash;
        for (uint256 i; i < logs.length; ++i) {
            if (logs[i].topics.length == 0) continue;
            require(
                logs[i].topics[0]
                    != keccak256(
                        "ImmediateRevealAttempt(uint16,uint256,uint256,bool,bytes32,uint256,uint256,bytes)"
                    ),
                "no event claiming an unattempted token request"
            );
            if (
                logs[i].emitter == address(entropy)
                    && logs[i].topics[0]
                        == keccak256(
                            "TokenEntropyPolicyRegistered(uint16,uint256,uint256,bytes32,uint8)"
                        )
            ) {
                require(logs[i].topics.length == 4, "original registration topics");
                uint256 id = uint256(logs[i].topics[2]);
                require(
                    logs[i].topics.length == 4 && logs[i].topics[1] == bytes32(uint256(1))
                        && id >= 1 && id <= registrations && logs[i].topics[3] == expectedPolicy
                        && keccak256(logs[i].data)
                            == keccak256(
                                abi.encode(uint16(2), uint8(entropy.tokenEntropyStatus(id)))
                            ),
                    "original token registration receipt binds declared policy"
                );
                require((seen & (1 << id)) == 0, "one receipt per original token");
                seen |= 1 << id;
                ++count;
            }
        }
        require(
            count == registrations && provider.nextRequestId() == 1
                && entropy.pendingRequestCount() == 0,
            "terminal registrations never contact provider"
        );
    }

    function _distribution(bool disabled) internal {
        uint256 fee = disabled ? 0 : FEE;
        uint256 total = fee * 2;
        bytes memory data = abi.encodeCall(
            distributor.distribute,
            (program, uint256(0), new bytes32[](0), distributionBatch, bytes(""))
        );
        bytes32 authorization = keccak256(
            abi.encode(
                keccak256("6529STREAM_OPERATOR_DISTRIBUTION_AUTHORIZATION_V1"),
                block.chainid,
                address(distributor),
                address(core),
                address(manager),
                uint256(1),
                DISTRIBUTION_PHASE,
                uint256(0)
            )
        );
        bytes32 slice = keccak256(
            abi.encode(
                keccak256("6529STREAM_OPERATOR_DISTRIBUTION_SLICE_V1"),
                block.chainid,
                address(distributor),
                address(core),
                address(manager),
                uint256(1),
                DISTRIBUTION_PHASE,
                uint256(0),
                distributionBatch.beneficiaries,
                distributionBatch.tokenData,
                distributionBatch.mintCommitments
            )
        );
        require(
            distributionBatch.authorizationId == authorization && program.slicesRoot == slice,
            "literal original distribution slice and authorization"
        );
        vm.prank(address(terminalOperator));
        (bool ok, bytes memory reason) = address(distributor).call{ value: total + 1 }(data);
        require(
            !ok
                && keccak256(reason)
                    == keccak256(
                        abi.encodeWithSelector(
                            IStreamOperatorDistribution.DistributionFeeMismatch.selector,
                            total + 1,
                            total
                        )
                    ),
            "exact distribution amount mismatch"
        );
        _safeRejected(
            terminalOperator, _safePayload(terminalOperator, address(distributor), total + 1, data)
        );
        require(
            core.totalSupply() == 0 && core.collectionMintedEver(1) == 0
                && core.lastAllocatedTokenId() == 0 && manager.nextOperationNonce() == 0
                && !distributor.sliceUsed(1, DISTRIBUTION_PHASE, 0)
                && !ledger.isManagerAuthorizationUsed(address(manager), authorization)
                && ledger.counterValue(_counter(DISTRIBUTION_PHASE, SUPPLY, address(0))) == 0
                && entropy.revealFeeEscrow(1) == 0 && address(distributor).balance == 0
                && address(terminalOperator).balance == 1 ether,
            "amount failure preserves original slice, counters, nonces and value"
        );
        vm.recordLogs();
        _safe(terminalOperator, address(distributor), total, data);
        Vm.Log[] memory logs = vm.getRecordedLogs();
        require(
            core.totalSupply() == 2 && core.collectionMintedEver(1) == 2
                && core.lastAllocatedTokenId() == 2 && core.collectionNextSerial(1) == 3
                && core.ownerOf(1) == address(terminalPayer)
                && core.ownerOf(2) == address(terminalOperator)
                && distributor.nftClaim(1).beneficiary == address(0)
                && distributor.nftClaim(2).beneficiary == address(0),
            "two actual beneficiaries receive original current tokens"
        );
        require(
            distributor.sliceUsed(1, DISTRIBUTION_PHASE, 0) && manager.nextOperationNonce() == 2
                && ledger.isManagerAuthorizationUsed(address(manager), authorization)
                && ledger.counterValue(_counter(DISTRIBUTION_PHASE, SUPPLY, address(0))) == 2
                && ledger.counterValue(
                    _counter(DISTRIBUTION_PHASE, RECIPIENT, address(terminalPayer))
                ) == 1
                && ledger.counterValue(
                    _counter(DISTRIBUTION_PHASE, RECIPIENT, address(terminalOperator))
                ) == 1,
            "original batch counts beneficiaries once"
        );
        require(
            address(terminalOperator).balance == 1 ether - total
                && entropy.revealFeeEscrow(1) == total && entropy.totalRevealFeeEscrows() == total
                && address(entropy).balance == total && address(provider).balance == 0
                && address(distributor).balance == 0 && wallet.balance == 0
                && recorder.totalOfficialSettled(address(0)) == 0
                && nativeSale.refundLiability() == 0,
            "free distribution funds only original reveal escrow without sale or buyer credit"
        );
        _noTokenRequest(logs, 2);
        _transferReceipt(logs, address(0), address(distributor), 1);
        _transferReceipt(logs, address(0), address(distributor), 2);
        _transferReceipt(logs, address(distributor), address(terminalPayer), 1);
        _transferReceipt(logs, address(distributor), address(terminalOperator), 2);
        _terminal(1, disabled, false);
        _terminal(2, disabled, false);
        uint256 completions;
        for (uint256 i; i < logs.length; ++i) {
            if (
                logs[i].emitter == address(distributor) && logs[i].topics.length == 4
                    && logs[i].topics[0]
                        == keccak256(
                            "DistributionSliceExecuted(uint16,uint256,bytes32,uint256,bytes32,bytes32,uint256)"
                        )
            ) {
                (uint16 schema, bytes32 recordedSlice, bytes32 operationRoot, uint256 quantity) =
                    abi.decode(logs[i].data, (uint16, bytes32, bytes32, uint256));
                require(
                    logs[i].topics[1] == bytes32(uint256(1))
                        && logs[i].topics[2] == DISTRIBUTION_PHASE
                        && logs[i].topics[3] == bytes32(0) && schema == 1 && recordedSlice == slice
                        && quantity == 2 && manager.isOperationRootUsed(operationRoot),
                    "original distribution execution receipt"
                );
                ++completions;
            }
        }
        require(completions == 1, "one original distribution completion");
        vm.prank(address(terminalOperator));
        (ok, reason) = address(distributor).call{ value: total }(data);
        require(
            !ok
                && keccak256(reason)
                    == keccak256(
                        abi.encodeWithSelector(
                            IStreamOperatorDistribution.DistributionSliceUsed.selector, uint256(0)
                        )
                    ) && core.collectionMintedEver(1) == 2 && entropy.revealFeeEscrow(1) == total,
            "exact used-slice replay rejection retains escrow and lifetime mint count"
        );
    }

    function _transferReceipt(Vm.Log[] memory logs, address from, address to, uint256 token)
        private
        view
    {
        uint256 count;
        for (uint256 i; i < logs.length; ++i) {
            if (
                logs[i].emitter == address(core) && logs[i].topics.length == 4
                    && logs[i].topics[0] == keccak256("Transfer(address,address,uint256)")
                    && logs[i].topics[1] == bytes32(uint256(uint160(from)))
                    && logs[i].topics[2] == bytes32(uint256(uint160(to)))
                    && logs[i].topics[3] == bytes32(token)
            ) {
                require(logs[i].data.length == 0, "original empty-data custody receipt");
                ++count;
            }
        }
        require(count == 1, "one exact original Core Transfer");
    }

    function _scopeRemainsAsync() internal {
        _paid(false, false);
        _govern(
            _governanceRequest(
                1,
                address(entropy),
                abi.encodeCall(entropy.setRequester, (address(terminalOperator), true)),
                0,
                0,
                0
            )
        );
        bytes32 ref = keccak256("actual terminal collection allocation");
        bytes32 scope = keccak256(
            abi.encode(
                keccak256("6529STREAM_ENTROPY_SCOPE_SUBJECT_V1"),
                block.chainid,
                address(entropy),
                address(core),
                uint256(1),
                uint8(0),
                ref
            )
        );
        _safe(
            terminalOperator,
            address(entropy),
            0,
            abi.encodeCall(entropy.registerEntropyScope, (uint256(1), uint8(0), ref))
        );
        require(
            entropy.scopeEntropy(scope).status == StreamEntropyStatus.REGISTERED,
            "actual scope registers despite terminal tokens"
        );
        bytes32 inputs = keccak256("actual allocation inputs");
        uint32 epoch = policy.collectionEntropyPolicy(1).providerEpoch;
        bytes32 key = keccak256(
            abi.encode(
                keccak256("6529STREAM_ENTROPY_SCOPE_REQUEST_V1"),
                block.chainid,
                address(entropy),
                address(core),
                uint256(1),
                scope,
                address(provider),
                epoch,
                provider.streamEntropyProviderConfigHash(),
                inputs,
                uint16(1)
            )
        );
        _safe(
            terminalOperator,
            address(entropy),
            FEE + EXCESS,
            abi.encodeCall(entropy.requestScopeEntropy, (scope, inputs))
        );
        require(
            entropy.scopeEntropy(scope).status == StreamEntropyStatus.REQUESTED
                && entropy.scopeEntropy(scope).requestKey == key
                && entropy.pendingRequestCount() == 1 && provider.nextRequestId() == 2
                && address(provider).balance == FEE && entropy.revealFeeEscrow(1) == FEE
                && entropy.totalRevealFeeEscrows() == FEE
                && entropy.entropyFeeCredit(address(terminalOperator)) == EXCESS
                && entropy.totalFeeCredits() == EXCESS && address(entropy).balance == FEE + EXCESS,
            "scope pays independently and leaves token fee escrow with separate excess credit"
        );
        bytes32 raw = keccak256("actual asynchronous allocation output");
        require(
            provider.fulfill(1, raw) == 0, "actual Coordinator accepts external provider result"
        );
        (bytes32 seed, bool finalized) = entropy.scopeSeed(scope);
        require(
            finalized && seed == _seed(scope, key, 1, raw, SALT, inputs, epoch)
                && entropy.pendingRequestCount() == 0 && entropy.nonterminalTokenCount(1) == 0,
            "literal original asynchronous scope seed"
        );
        _terminal(1, false, false);
        _safe(
            terminalOperator,
            address(entropy),
            0,
            abi.encodeCall(entropy.claimEntropyFeeCredit, (payable(address(terminalOperator))))
        );
        require(
            address(terminalOperator).balance == 1 ether - FEE
                && entropy.entropyFeeCredit(address(terminalOperator)) == 0
                && entropy.totalFeeCredits() == 0 && entropy.revealFeeEscrow(1) == FEE
                && address(entropy).balance == FEE,
            "scope credit claim cannot consume terminal-token escrow"
        );
    }

    function _seed(
        bytes32 scope,
        bytes32 key,
        uint256 request,
        bytes32 raw,
        bytes32 salt,
        bytes32 inputs,
        uint32 epoch
    ) private view returns (bytes32) {
        return keccak256(
            abi.encode(
                scope == bytes32(0)
                    ? keccak256("6529STREAM_ENTROPY_SEED_V1")
                    : keccak256("6529STREAM_ENTROPY_SCOPE_SEED_V1"),
                block.chainid,
                address(entropy),
                address(core),
                uint256(1),
                scope == bytes32(0) ? bytes32(uint256(1)) : scope,
                address(provider),
                epoch,
                provider.streamEntropyProviderConfigHash(),
                key,
                request,
                raw,
                salt,
                inputs
            )
        );
    }

    function _legacyRequiredControl() internal {
        Policy.PolicyRecord memory original = policy.collectionEntropyPolicy(1);
        require(
            !original.explicitPolicy && original.mode == Policy.Mode.ASYNC
                && original.renderRequirement == Policy.RenderRequirement.REQUIRED
                && original.revision == 0,
            "unchanged original profile is a distinct control"
        );
        IStreamNativeFixedPriceSaleAdapter.SaleExecutionData memory e =
            _execution(address(terminalPayer));
        vm.recordLogs();
        _safe(
            terminalPayer,
            address(nativeSale),
            PRICE + FEE,
            abi.encodeCall(nativeSale.purchase, (e))
        );
        Vm.Log[] memory logs = vm.getRecordedLogs();
        (,,,,, bytes32 key, uint256 request, uint16 attempt) = entropy.tokenEntropy(1);
        require(
            core.ownerOf(1) == address(terminalPayer)
                && core.coordinatorAtMint(1) == address(entropy)
                && entropy.tokenEntropyStatus(1) == StreamEntropyStatus.REQUESTED && key != 0
                && request == 1 && attempt == 1 && entropy.pendingRequestCount() == 1
                && entropy.nonterminalTokenCount(1) == 1 && provider.nextRequestId() == 2
                && address(provider).balance == FEE && entropy.revealFeeEscrow(1) == 0
                && wallet.balance == PRICE && recorder.totalOfficialSettled(address(0)) == PRICE
                && address(terminalPayer).balance == 1 ether - PRICE - FEE,
            "original required token still funds and performs one genuine request"
        );
        uint256 count;
        for (uint256 i; i < logs.length; ++i) {
            if (
                logs[i].emitter == address(nativeSale) && logs[i].topics.length == 3
                    && logs[i].topics[0]
                        == keccak256(
                            "ImmediateRevealAttempt(uint16,uint256,uint256,bool,bytes32,uint256,uint256,bytes)"
                        )
            ) {
                require(
                    logs[i].topics[1] == bytes32(uint256(1))
                        && logs[i].topics[2] == bytes32(uint256(1))
                        && keccak256(logs[i].data)
                            == keccak256(
                                abi.encode(uint16(1), true, key, request, uint256(64), bytes(""))
                            ),
                    "original required request receipt"
                );
                ++count;
            }
        }
        require(count == 1, "one real request attempt");
        bytes32 raw = keccak256("original required paid token output");
        require(provider.fulfill(request, raw) == 0, "actual required-token fulfillment");
        (bytes32 seed, bool finalized) = entropy.tokenSeed(1);
        require(
            finalized
                && seed
                    == _seed(
                        0,
                        key,
                        request,
                        raw,
                        keccak256("collection salt"),
                        e.authorization.mintCommitment,
                        original.providerEpoch
                    ) && entropy.tokenEntropyStatus(1) == StreamEntropyStatus.FINALIZED
                && entropy.pendingRequestCount() == 0 && entropy.nonterminalTokenCount(1) == 0,
            "unchanged original required-token finalization and seed preimage"
        );
    }
}
