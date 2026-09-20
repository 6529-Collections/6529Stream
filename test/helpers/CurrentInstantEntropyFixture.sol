// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./StreamCurrentSafeGovernanceFixture.sol";
import {
    StreamNativeFixedPriceSaleAdapter
} from "../../smart-contracts/domains/mint/StreamNativeFixedPriceSaleAdapter.sol";
import {
    IStreamNativeFixedPriceSaleAdapter
} from "../../smart-contracts/interfaces/stream/mint/IStreamNativeFixedPriceSaleAdapter.sol";
import {
    IStreamNativeRefundDelegatedClaims
} from "../../smart-contracts/interfaces/stream/mint/IStreamNativeRefundDelegatedClaims.sol";
import {
    IStreamNativeSaleBinding
} from "../../smart-contracts/interfaces/stream/revenue/IStreamNativeSaleBinding.sol";
import {
    StreamNativeSettlementTypes
} from "../../smart-contracts/interfaces/stream/revenue/StreamNativeSettlementTypes.sol";
import {
    StreamPrimarySettlementTypes
} from "../../smart-contracts/interfaces/stream/revenue/StreamPrimarySettlementTypes.sol";
import {
    StreamPrimarySaleSettlement
} from "../../smart-contracts/domains/revenue/StreamPrimarySaleSettlement.sol";
import {
    StreamEntropyProviderInstant
} from "../../smart-contracts/domains/entropy/StreamEntropyProviderInstant.sol";
import {
    IStreamEntropyCollectionPolicy as Policy
} from "../../smart-contracts/interfaces/stream/entropy/IStreamEntropyCollectionPolicy.sol";
import {
    IStreamInstantEntropyProviderIdentity
} from "../../smart-contracts/interfaces/stream/entropy/IStreamInstantEntropyProviderIdentity.sol";
import {
    IStreamEntropyEpochs
} from "../../smart-contracts/interfaces/stream/entropy/IStreamEntropyEpochs.sol";
import {
    IStreamEntropyProviderLifecycle,
    EntropyProviderState
} from "../../smart-contracts/interfaces/stream/entropy/IStreamEntropyProviderLifecycle.sol";
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

/// @dev Explicit recipient refusal; production Core delivery, accounting and entropy remain genuine.
contract CurrentInstantEntropyReceiver is IERC721Receiver {
    error InstantRecipientRejected();
    address private immutable controller;
    StreamCore private immutable core;
    bool public accepting;
    uint256 public received;

    constructor(StreamCore core_) {
        core = core_;
        controller = msg.sender;
    }

    function accept() external {
        require(msg.sender == controller, "receiver controller");
        accepting = true;
    }

    function onERC721Received(address, address from, uint256 token, bytes calldata)
        external
        returns (bytes4)
    {
        require(msg.sender == address(core) && from == address(0), "original Core mint delivery");
        if (!accepting) revert InstantRecipientRejected();
        received = token;
        return IERC721Receiver.onERC721Received.selector;
    }
}

/// @notice Actual current Safe/Artist/governance/payment graph and production LOW_SECURITY provider.
/// @dev The inherited unused ASYNC provider exists only in base setup; no tested INSTANT request uses it.
abstract contract CurrentInstantEntropyFixture is StreamCurrentSafeGovernanceFixture {
    bytes32 internal constant INSTANT_PHASE = keccak256("current instant native phase");
    bytes32 internal constant FAMILY = keccak256("6529STREAM_ENTROPY_CONFIGURATION_V1");
    bytes32 internal constant SALT = keccak256("current instant declared salt");
    bytes32 internal constant ASSUMPTIONS = keccak256(
        "LOW_SECURITY: previous-block hash; validator influence; publicly simulatable; request-timing selection; not VRF; mintCommitment excluded"
    );
    uint256 internal constant PRICE = 1000;
    uint256 internal constant EXCESS = 37;
    uint256 internal constant REQUEST_VALUE = 91;
    OfficialSafe internal instantArtist;
    OfficialSafe internal instantPayer;
    OfficialSafe internal instantOperator;
    uint256[] internal instantKeys;
    StreamPrimarySaleSettlement internal recorder;
    StreamNativeFixedPriceSaleAdapter internal nativeSale;
    StreamEntropyProviderInstant internal lowSecurityProvider;
    Policy internal policy;
    bytes32 internal saleId;

    function _constructInstant() internal {
        vm.roll(100);
        instantKeys.push(0x1A5701);
        instantKeys.push(0x1A5702);
        SafeComponents memory c = deploySafeComponents("1.4.1");
        instantArtist = createOfficialSafe(c, safeOwnerAddresses(instantKeys), 2, 7201);
        instantPayer = createOfficialSafe(c, safeOwnerAddresses(instantKeys), 2, 7202);
        instantOperator = createOfficialSafe(c, safeOwnerAddresses(instantKeys), 2, 7203);
        _deployCurrentStack(address(instantArtist), vm.addr(PLATFORM_KEY));
        policy = Policy(address(entropy));
        _installGovernorSafe(instantOperator, instantKeys);
        vm.deal(address(instantPayer), 1 ether);
        vm.deal(address(instantOperator), 1 ether);
        _admitInstantProvider();
        _saleConsent();
    }

    function _artistProof(bytes32 digest) internal override returns (bytes memory) {
        bytes32 wrapped = keccak256(
            abi.encodePacked(
                bytes2(0x1901),
                _safeDomain(instantArtist),
                keccak256(
                    abi.encode(
                        keccak256("SafeMessage(bytes message)"), keccak256(abi.encode(digest))
                    )
                )
            )
        );
        require(
            wrapped == safeMessageDigest(instantArtist, abi.encode(digest)),
            "original Artist SafeMessage domain"
        );
        return safeThresholdSignature(instantKeys, wrapped);
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

    // The collection is explicitly configured after real Artist onboarding.
    function _configureInitialRevealPolicy() internal override { }

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
        lowSecurityProvider = StreamEntropyProviderInstant(
            _artistArtifactCreate(
                "smart-contracts/domains/entropy/StreamEntropyProviderInstant.sol:StreamEntropyProviderInstant",
                abi.encode(address(entropy))
            )
        );
        _assertDeployableProductionInstance(address(recorder));
        _assertDeployableProductionInstance(address(nativeSale));
        _assertDeployableProductionInstance(address(lowSecurityProvider));
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

    function instantTime() external view returns (uint64) {
        return uint64(block.timestamp);
    }

    function _configureAdditionalProducts() internal override {
        StreamModuleRegistration[] memory rows = new StreamModuleRegistration[](1);
        rows[0] = StreamModuleRegistration(
            address(nativeSale),
            keccak256("NATIVE_PRIMARY_SALE_ADAPTER"),
            keccak256("6529STREAM_UNIVERSAL_SETTLEMENT_V1"),
            type(IStreamNativeSaleBinding).interfaceId,
            500_000,
            address(nativeSale).codehash,
            DEPLOYMENT_HASH,
            keccak256("instant native current module"),
            "urn:stream:current:instant-native"
        );
        (GovernanceCall[] memory calls, bytes[] memory data) =
            StreamCurrentStackPlan.registrationCalls(registry, rows);
        (bytes32 scope, bytes32 old_, bytes32 next) = StreamGovernanceBootstrap.deriveBatchTransitionHashes(
            calls, StreamGovernanceBootstrap.governanceCallsHash(calls)
        );
        uint64 ready = this.instantTime() + uint64(executor.minimumDelay(1));
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
                    "urn:stream:current:instant-admission",
                    DEPLOYMENT_HASH
                )
            )
        );
        vm.warp(ready);
        executor.executeGovernanceBatch(abi.decode(scheduled, (bytes32)), calls, data);
        _configureMintPhase(INSTANT_PHASE, address(nativeSale));
        saleId = nativeSale.registerSale(
            IStreamNativeFixedPriceSaleAdapter.SaleConfig(
                1,
                INSTANT_PHASE,
                PRICE,
                0,
                this.instantTime() + 365 days,
                manager.phasePolicyHash(1, INSTANT_PHASE),
                primaryResolver.resolvePrimaryAssignment(1, 0, PRIMARY_REVENUE_CLASS).assignmentHash
            )
        );
        nativeSale.transferOwnership(address(executor));
    }

    function _safe(OfficialSafe account, address target, uint256 value, bytes memory data)
        internal
    {
        uint256 nonce = account.nonce();
        require(
            executeSafe(account, instantKeys, target, value, data, 0)
                && account.nonce() == nonce + 1,
            "actual instant Safe CALL consumes one original nonce"
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
            instantArtist,
            address(artists),
            0,
            abi.encodeCall(
                IStreamArtistSaleAuthority.recordSaleConsent, (terms, _nextArtistAuthorization())
            )
        );
        (bool ok, bytes32 record) = artists.isSaleConsented(1, saleId, terms.saleConfigHash);
        require(
            ok && record != 0 && artists.saleConsentRecord(record).signer == address(instantArtist),
            "actual exact native sale consent"
        );
    }

    function _policyInput(bool required, bool publicRequests)
        internal
        view
        returns (Policy.PolicyInput memory p)
    {
        p.mode = Policy.Mode.INSTANT;
        p.securityClass = Policy.SecurityClass.LOW_SECURITY;
        p.renderRequirement =
            required ? Policy.RenderRequirement.REQUIRED : Policy.RenderRequirement.NOT_REQUIRED;
        p.provider = address(lowSecurityProvider);
        p.collectionSalt = SALT;
        p.publicRequests = publicRequests;
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
                p.provider == address(0)
                    ? bytes32(0)
                    : lowSecurityProvider.streamEntropyProviderConfigHash(),
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
        uint64 observed = this.instantTime();
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
                address(instantArtist),
                uint8(1),
                a.nonce,
                observed
            )
        );
        vm.recordLogs();
        _safe(
            instantArtist,
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
                        && logs[i].topics[3] == bytes32(uint256(uint160(address(instantArtist))))
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

    function _configureInstant(bool required, bool publicRequests, bool negatives)
        internal
        returns (bytes32 hash)
    {
        Policy.PolicyInput memory input = _policyInput(required, publicRequests);
        Policy.PolicyRecord memory before_ = policy.collectionEntropyPolicy(1);
        uint32 epoch = before_.providerEpoch + 1;
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
                                        : lowSecurityProvider.streamEntropyProviderConfigHash(),
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
            address(instantPayer),
            address(instantPayer),
            recipient,
            address(instantArtist),
            keccak256(TOKEN_DATA),
            keccak256("current instant paid commitment"),
            1,
            keccak256("current instant paid nonce"),
            this.instantTime() + 1 days,
            _nativePrimaryPolicyHash()
        );
        bytes32 domain = keccak256(
            abi.encode(
                keccak256(
                    "EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"
                ),
                keccak256("6529StreamNativeFixedPriceSaleAdapter"),
                keccak256("1"),
                block.chainid,
                address(nativeSale)
            )
        );
        bytes32 digest = keccak256(
            abi.encodePacked(
                bytes2(0x1901),
                domain,
                keccak256(
                    abi.encode(
                        keccak256(
                            "NativeSaleAuthorization(bytes32 saleId,bytes32 saleConfigHash,address payer,address executor,address recipient,address artist,bytes32 tokenDataHash,bytes32 mintCommitment,uint256 executionNonce,bytes32 nonce,uint64 deadline,bytes32 expectedPrimaryPolicyHash)"
                        ),
                        e.authorization
                    )
                )
            )
        );
        require(
            digest == nativeSale.authorizationDigest(e.authorization),
            "literal original commercial authorization digest"
        );
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(PLATFORM_KEY, digest);
        e.platformSignature = abi.encodePacked(r, s, v);
        e.artistSignature = _artistProof(digest);
    }

    function _safePayload(OfficialSafe account, address target, uint256 value, bytes memory data)
        private
        returns (bytes memory)
    {
        bytes32 digest = _safeDigest(account, target, value, data, account.nonce());
        require(
            digest
                == account.getTransactionHash(
                    target, value, data, 0, 0, 0, 0, address(0), address(0), account.nonce()
                ),
            "literal original Safe transaction digest"
        );
        return _signedPayload(target, value, data, safeThresholdSignature(instantKeys, digest));
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
                && ledger.counterValue(_counter(INSTANT_PHASE, keccak256("supply"), address(0)))
                    == 0
                && !nativeSale.authorizationUsed(address(instantArtist), e.authorization.nonce)
                && nativeSale.executionStatus(c.executionBinding.executionId) == 0
                && nativeSale.executionIdByNonce(saleId, 1) == 0,
            "failed callback preserves original mint and commercial replay lanes"
        );
        require(
            wallet.balance == 0 && recorder.totalOfficialSettled(address(0)) == 0
                && address(recorder).balance == 0 && address(nativeSale).balance == 0
                && nativeSale.refundLiability() == 0 && revenueEscrow.totalOwed(address(0)) == 0
                && entropy.revealFeeEscrow(1) == 0 && address(instantPayer).balance == 1 ether
                && entropy.tokenEntropyStatus(1) == StreamEntropyStatus.NONE
                && entropy.registeredAtBlock(1) == 0 && entropy.nonterminalTokenCount(1) == 0
                && entropy.pendingRequestCount() == 0 && provider.nextRequestId() == 1,
            "failed callback preserves payment, liabilities and entropy state"
        );
    }

    function _paid(bool required, bool callback, bool signatureNegatives)
        internal
        returns (uint256 token)
    {
        address recipient = address(instantPayer);
        CurrentInstantEntropyReceiver receiver;
        if (callback) {
            receiver = new CurrentInstantEntropyReceiver(core);
            recipient = address(receiver);
        }
        IStreamNativeFixedPriceSaleAdapter.SaleExecutionData memory e = _execution(recipient);
        StreamNativeSettlementTypes.NativeSettlementCandidate memory c =
            nativeSale.previewExecution(e);
        uint256 fee = 0;
        bytes memory data = abi.encodeCall(nativeSale.purchase, (e));
        bytes memory payload =
            _safePayload(instantPayer, address(nativeSale), PRICE + fee + EXCESS, data);
        if (signatureNegatives) _mintSignatureRefusals(data, payload, c, e);
        if (callback) {
            bytes32 beforeCallback = _state();
            vm.prank(address(instantPayer));
            (bool ok, bytes memory reason) =
                address(nativeSale).call{ value: PRICE + fee + EXCESS }(data);
            require(
                !ok
                    && keccak256(reason)
                        == keccak256(
                            abi.encodeWithSelector(
                                CurrentInstantEntropyReceiver.InstantRecipientRejected.selector
                            )
                        ),
                "exact original receiver boundary, not unrelated sale failure"
            );
            _unmintedNative(c, e);
            _safeRejected(instantPayer, payload);
            _unmintedNative(c, e);
            require(
                _state() == beforeCallback && receiver.received() == 0,
                "callback refusal restores the complete request, payment and receiver state"
            );
            receiver.accept();
        }
        vm.recordLogs();
        _exactSafe(instantPayer, payload);
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
                && ledger.counterValue(_counter(INSTANT_PHASE, keccak256("supply"), address(0)))
                    == 1
                && nativeSale.authorizationUsed(address(instantArtist), e.authorization.nonce)
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
            address(instantPayer).balance == 1 ether - PRICE - fee - EXCESS
                && entropy.revealFeeEscrow(1) == fee && entropy.totalRevealFeeEscrows() == fee
                && address(entropy).balance == fee && address(provider).balance == 0
                && nativeSale.refundableBalance(saleId, address(instantPayer)) == EXCESS
                && nativeSale.refundLiability() == EXCESS && address(nativeSale).balance == EXCESS,
            "instant mint has zero fee and full payer-owned excess"
        );
        _noTokenRequest(logs, 1);
        _transferReceipt(logs, address(0), recipient, token);
        _registered(required);
        if (signatureNegatives) _signatureRejected(payload); // Now genuinely stale after success.
        vm.prank(address(instantPayer));
        (bool replay, bytes memory failure) =
            address(nativeSale).call{ value: PRICE + fee + EXCESS }(data);
        require(
            !replay
                && keccak256(failure)
                    == keccak256(
                        abi.encodeWithSelector(
                            IStreamNativeFixedPriceSaleAdapter.NativeAuthorizationUsed.selector,
                            address(instantArtist),
                            e.authorization.nonce
                        )
                    ),
            "exact paid authorization replay denial"
        );
        _safe(
            instantPayer,
            address(nativeSale),
            0,
            abi.encodeCall(nativeSale.claimRefund, (saleId, address(instantPayer)))
        );
        require(
            address(instantPayer).balance == 1 ether - PRICE - fee
                && nativeSale.refundLiability() == 0 && address(nativeSale).balance == 0
                && nativeSale.refundableBalance(saleId, address(instantPayer)) == 0,
            "original Safe pull refund closes only buyer credit"
        );
        if (callback) {
            require(receiver.received() == token, "actual accepted delivery after exact retry");
        }
    }

    function _noTokenRequest(Vm.Log[] memory logs, uint256 registrations) private view {
        uint256 count;
        uint256 seen;
        bytes32 expectedPolicy = policy.collectionEntropyPolicy(1).policyHash;
        for (uint256 i; i < logs.length; ++i) {
            if (logs[i].topics.length == 0) continue;
            require(
                logs[i].topics[0]
                        != keccak256("EntropyRequested(bytes32,uint256,bytes32,address,uint256)")
                    && logs[i].topics[0]
                        != keccak256(
                            "InstantEntropyProduced(uint16,bytes32,uint256,bytes32,bytes32,uint8,bytes32)"
                        )
                    && logs[i].topics[0]
                        != keccak256("EntropyFinalized(bytes32,uint256,bytes32,bytes32,bytes32)"),
                "registration creates no request or finality receipt"
            );
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
            "registration emits no draw and leaves the unused ASYNC provider untouched"
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

    function _safeDomain(OfficialSafe account) private view returns (bytes32 domain) {
        domain = keccak256(
            abi.encode(
                keccak256("EIP712Domain(uint256 chainId,address verifyingContract)"),
                block.chainid,
                address(account)
            )
        );
        require(domain == account.domainSeparator(), "original Safe EIP712 domain");
    }

    function _safeDigest(
        OfficialSafe account,
        address target,
        uint256 value,
        bytes memory data,
        uint256 nonce
    ) private view returns (bytes32) {
        bytes32 txHash = keccak256(
            abi.encode(
                keccak256(
                    "SafeTx(address to,uint256 value,bytes data,uint8 operation,uint256 safeTxGas,uint256 baseGas,uint256 gasPrice,address gasToken,address refundReceiver,uint256 nonce)"
                ),
                target,
                value,
                keccak256(data),
                uint8(0),
                uint256(0),
                uint256(0),
                uint256(0),
                address(0),
                address(0),
                nonce
            )
        );
        return keccak256(abi.encodePacked(bytes2(0x1901), _safeDomain(account), txHash));
    }

    function _signedPayload(
        address target,
        uint256 value,
        bytes memory data,
        bytes memory signatures
    ) private pure returns (bytes memory) {
        return abi.encodeCall(
            OfficialSafe.execTransaction,
            (target, value, data, uint8(0), 0, 0, 0, address(0), payable(address(0)), signatures)
        );
    }

    function _instantConfig() private view returns (bytes32) {
        return keccak256(
            abi.encode(
                keccak256("6529STREAM_INSTANT_BLOCKHASH_CONFIG_V1"),
                address(entropy),
                uint8(1),
                ASSUMPTIONS
            )
        );
    }

    function _admitInstantProvider() private {
        require(
            lowSecurityProvider.coordinator() == address(entropy)
                && lowSecurityProvider.streamEntropyProviderConfigHash() == _instantConfig()
                && lowSecurityProvider.ASSUMPTIONS_HASH() == ASSUMPTIONS,
            "literal production provider identity and disclosed limitations"
        );
        (IStreamInstantEntropyProviderIdentity.InstantMode mode, bytes32 assumptions) =
            lowSecurityProvider.instantEntropyProfile();
        require(
            uint8(mode) == 1 && assumptions == ASSUMPTIONS, "production delayed blockhash profile"
        );
        string memory reason = "urn:stream:current:instant-provider-admission";
        (bytes32 scope, bytes32 oldHash, bytes32 newHash, uint8 actionClass) = entropy.entropyProviderTransition(
            address(lowSecurityProvider), EntropyProviderState.ACTIVE, reason
        );
        require(actionClass == 1, "original class-one provider admission");
        bytes32 action = _govern(
            _governanceRequest(
                1,
                address(entropy),
                abi.encodeCall(
                    entropy.activateEntropyProvider, (address(lowSecurityProvider), reason)
                ),
                scope,
                oldHash,
                newHash
            )
        );
        IStreamEntropyProviderLifecycle.ProviderRecord memory admitted =
            entropy.entropyProviderRecord(address(lowSecurityProvider));
        require(
            admitted.state == EntropyProviderState.ACTIVE && admitted.revision == 1
                && admitted.runtimeCodeHash == address(lowSecurityProvider).codehash
                && admitted.lastActionId == action
                && admitted.reasonHash == keccak256(bytes(reason)),
            "actual governed production provider admission"
        );
    }

    struct Draw {
        bytes32 key;
        uint256 id;
        uint64 requestedAt;
        bytes context;
        bytes32 raw;
        bytes32 provenance;
        bytes32 seed;
    }

    function _identity() private view returns (Draw memory d) {
        uint32 epoch = policy.collectionEntropyPolicy(1).providerEpoch;
        d.key = keccak256(
            abi.encode(
                keccak256("6529STREAM_ENTROPY_REQUEST_V1"),
                block.chainid,
                address(entropy),
                address(core),
                uint256(1),
                uint256(1),
                address(lowSecurityProvider),
                epoch,
                _instantConfig(),
                uint16(1)
            )
        );
        d.id = uint256(
            keccak256(
                abi.encode(
                    keccak256("6529STREAM_INSTANT_PROVIDER_REQUEST_V1"),
                    d.key,
                    uint16(1),
                    address(lowSecurityProvider),
                    epoch,
                    _instantConfig()
                )
            )
        );
        d.context = abi.encode(
            uint16(1),
            address(core),
            uint256(1),
            uint256(1),
            bytes32(0),
            epoch,
            _instantConfig(),
            uint16(1),
            bytes32(0)
        );
    }

    function _draw() private view returns (Draw memory d) {
        d = _identity();
        d.requestedAt = uint64(block.number);
        uint256 sourceBlock = block.number - 1;
        bytes32 sourceHash = blockhash(sourceBlock);
        d.raw = keccak256(
            abi.encode(
                keccak256("6529STREAM_INSTANT_BLOCKHASH_RAW_V1"),
                d.key,
                keccak256(d.context),
                sourceBlock,
                sourceHash
            )
        );
        d.provenance = keccak256(
            abi.encode(
                keccak256("6529STREAM_INSTANT_BLOCKHASH_PROVENANCE_V1"),
                _instantConfig(),
                d.key,
                keccak256(d.context),
                sourceBlock,
                sourceHash,
                ASSUMPTIONS
            )
        );
        d.seed = keccak256(
            abi.encode(
                keccak256("6529STREAM_ENTROPY_SEED_V1"),
                block.chainid,
                address(entropy),
                address(core),
                uint256(1),
                bytes32(uint256(1)),
                address(lowSecurityProvider),
                policy.collectionEntropyPolicy(1).providerEpoch,
                _instantConfig(),
                d.key,
                d.id,
                d.raw,
                SALT,
                bytes32(0)
            )
        );
    }

    function _subject() private view returns (StreamEntropyCoordinator.Subject memory) {
        return entropy.scopeEntropy(keccak256(abi.encode("TOKEN", uint256(1))));
    }

    function _registered(bool required) private view {
        StreamEntropyStatus expected =
            required ? StreamEntropyStatus.REGISTERED : StreamEntropyStatus.NOT_REQUIRED;
        (bool exists, uint256 collection, uint256 serial, bool burned) =
            core.tokenCollectionIdentity(1);
        require(
            exists && collection == 1 && serial == 1 && !burned && core.tokenLifecycle(1) == 2
                && core.coordinatorAtMint(1) == address(entropy),
            "original minted Core identity and coordinator"
        );
        (
            StreamEntropyStatus status,
            bytes32 seed,
            address selected,
            uint32 epoch,
            bytes32 config,
            bytes32 key,
            uint256 id,
            uint16 attempt
        ) = entropy.tokenEntropy(1);
        require(
            status == expected && entropy.tokenEntropyStatus(1) == expected && seed == 0
                && selected == address(lowSecurityProvider)
                && epoch == policy.collectionEntropyPolicy(1).providerEpoch
                && config == _instantConfig() && key == 0 && id == 0 && attempt == 0,
            "exact undrawn actual INSTANT token tuple"
        );
        (bytes32 seedRead, bool finalized) = entropy.tokenSeed(1);
        StreamEntropyCoordinator.Subject memory subject = _subject();
        require(
            seedRead == 0 && !finalized && subject.collectionId == 1 && subject.status == expected
                && subject.inputsHash == keccak256("current instant paid commitment")
                && subject.requestKey == 0 && subject.seed == 0
                && entropy.registeredAtBlock(1) == block.number
                && entropy.pendingRequestCount() == 0
                && entropy.nonterminalTokenCount(1) == (required ? 1 : 0),
            "mint records its genuine commitment and never invents a seed or request"
        );
        require(
            !entropy.collectionRevealPolicy(1).declared && entropy.revealFeeEscrow(1) == 0
                && entropy.totalRevealFeeEscrows() == 0 && entropy.totalFeeCredits() == 0
                && address(entropy).balance == 0 && address(lowSecurityProvider).balance == 0,
            "INSTANT registration needs no ASYNC policy or fee"
        );
        _absentRequest();
    }

    function _absentRequest() private view {
        Draw memory d = _identity();
        (
            bytes32 subjectKey,
            uint256 token,
            bytes32 scope,
            address selected,
            uint64 at,
            uint256 requestId,
            bytes32 raw
        ) = entropy.requests(d.key);
        IStreamEntropyEpochs.RequestPolicySnapshot memory empty;
        require(
            subjectKey == 0 && token == 0 && scope == 0 && selected == address(0) && at == 0
                && requestId == 0 && raw == 0
                && entropy.providerRequestKeys(address(lowSecurityProvider), d.id) == 0
                && keccak256(abi.encode(entropy.requestPolicySnapshot(d.key)))
                    == keccak256(abi.encode(empty)),
            "no request identity, reverse binding or captured policy before successful draw"
        );
    }

    /// @dev Snapshot unrelated domains as well as the exact candidate request and both custody ledgers.
    function _state() private view returns (bytes32) {
        Draw memory d = _identity();
        (bool ok, bytes memory request) =
            address(entropy).staticcall(abi.encodeCall(entropy.requests, (d.key)));
        require(ok, "original request getter");
        bytes32 entropyState = keccak256(
            abi.encode(
                _subject(),
                request,
                entropy.requestPolicySnapshot(d.key),
                entropy.providerRequestKeys(address(lowSecurityProvider), d.id),
                entropy.registeredAtBlock(1),
                entropy.nonterminalTokenCount(1),
                entropy.pendingRequestCount(),
                entropy.metadataNotificationPending(1),
                policy.collectionEntropyPolicy(1)
            )
        );
        bytes32 balances = keccak256(
            abi.encode(
                address(instantPayer).balance,
                address(entropy).balance,
                address(lowSecurityProvider).balance,
                address(provider).balance,
                entropy.entropyFeeCredit(address(instantPayer)),
                entropy.totalFeeCredits(),
                entropy.revealFeeEscrow(1),
                entropy.totalRevealFeeEscrows(),
                address(nativeSale).balance,
                nativeSale.refundLiability(),
                nativeSale.refundableBalance(saleId, address(instantPayer)),
                wallet.balance,
                address(recorder).balance,
                recorder.totalOfficialSettled(address(0)),
                revenueEscrow.totalOwed(address(0))
            )
        );
        bytes32 mintState = keccak256(
            abi.encode(
                core.totalSupply(),
                core.collectionMintedEver(1),
                core.collectionNextSerial(1),
                core.lastAllocatedTokenId(),
                core.pendingPreparedMintTokenId(),
                core.preparedMint(1),
                core.coordinatorAtMint(1),
                core.tokenData(1),
                manager.nextOperationNonce(),
                ledger.counterValue(_counter(INSTANT_PHASE, keccak256("supply"), address(0)))
            )
        );
        return keccak256(
            abi.encode(entropyState, balances, mintState, instantPayer.nonce(), _artistState())
        );
    }

    function _signatureRejected(bytes memory payload) private {
        bytes32 prior = _state();
        (bool ok, bytes memory reason) = address(instantPayer).call(payload);
        require(
            !ok && keccak256(reason) == keccak256(abi.encodeWithSignature("Error(string)", "GS026"))
                && _state() == prior,
            "exact Safe signature refusal preserves all captured state"
        );
    }

    function _mintSignatureRefusals(
        bytes memory data,
        bytes memory payload,
        StreamNativeSettlementTypes.NativeSettlementCandidate memory candidate,
        IStreamNativeFixedPriceSaleAdapter.SaleExecutionData memory execution
    ) private {
        uint256 nonce = instantPayer.nonce();
        bytes memory signatures = safeThresholdSignature(
            instantKeys, _safeDigest(instantPayer, address(nativeSale), PRICE + EXCESS, data, nonce)
        );
        require(
            keccak256(payload)
                == keccak256(_signedPayload(address(nativeSale), PRICE + EXCESS, data, signatures)),
            "saved exact original Safe envelope"
        );
        // Both values cover the sale; exact GS026 cannot be an underpayment failure.
        _signatureRejected(
            _signedPayload(address(nativeSale), PRICE + EXCESS + 1, data, signatures)
        );
        signatures = safeThresholdSignature(
            instantKeys,
            _safeDigest(instantPayer, address(nativeSale), PRICE + EXCESS, data, nonce + 1)
        );
        _signatureRejected(_signedPayload(address(nativeSale), PRICE + EXCESS, data, signatures));
        _unmintedNative(candidate, execution);
    }

    function _requestPayload() private returns (bytes memory) {
        return _safePayload(
            instantPayer,
            address(entropy),
            REQUEST_VALUE,
            abi.encodeCall(entropy.requestEntropy, (uint256(1)))
        );
    }

    function _requestRefused(bytes memory payload, bytes memory expected) private {
        bytes32 prior = _state();
        vm.prank(address(instantPayer));
        (bool ok, bytes memory reason) = address(entropy).call{ value: REQUEST_VALUE }(
            abi.encodeCall(entropy.requestEntropy, (uint256(1)))
        );
        require(
            !ok && keccak256(reason) == keccak256(expected) && _state() == prior,
            "exact Coordinator request refusal preserves original state and liabilities"
        );
        _safeRejected(instantPayer, payload);
        require(_state() == prior, "actual Safe target refusal restores every captured domain");
    }

    function _requestAfterSameBlockRefusal() internal {
        bytes memory payload = _requestPayload();
        _requestRefused(
            payload,
            abi.encodeWithSelector(
                StreamEntropyCoordinator.InstantEntropyBeforeDelivery.selector, uint256(1)
            )
        );
        _absentRequest();
        vm.roll(block.number + 1);
        _finishRequest(payload);
    }

    function _privateRequesterAdmission() internal {
        vm.roll(block.number + 1);
        bytes memory payload = _requestPayload();
        _requestRefused(
            payload,
            abi.encodeWithSelector(
                StreamEntropyCoordinator.Unauthorized.selector, address(instantPayer)
            )
        );
        _absentRequest();
        _govern(
            _governanceRequest(
                1,
                address(entropy),
                abi.encodeCall(entropy.setRequester, (address(instantPayer), true)),
                0,
                0,
                0
            )
        );
        require(entropy.requesters(address(instantPayer)), "real governed requester admission");
        _finishRequest(payload);
    }

    function _finishRequest(bytes memory payload) private returns (Draw memory d) {
        d = _draw();
        bytes32 artistBefore = _artistState();
        vm.recordLogs();
        _exactSafe(instantPayer, payload);
        Vm.Log[] memory logs = vm.getRecordedLogs();
        _final(d);
        _requestReceipts(logs, d);
        require(
            _artistState() == artistBefore && wallet.balance == PRICE
                && recorder.totalOfficialSettled(address(0)) == PRICE
                && core.ownerOf(1) == address(instantPayer) && core.totalSupply() == 1
                && manager.nextOperationNonce() == 1,
            "request leaves original Artist, mint and paid revenue unchanged"
        );
        require(
            entropy.entropyFeeCredit(address(instantPayer)) == REQUEST_VALUE
                && entropy.totalFeeCredits() == REQUEST_VALUE
                && address(entropy).balance == REQUEST_VALUE
                && address(instantPayer).balance == 1 ether - PRICE - REQUEST_VALUE
                && entropy.revealFeeEscrow(1) == 0 && entropy.totalRevealFeeEscrows() == 0
                && address(lowSecurityProvider).balance == 0 && address(provider).balance == 0
                && provider.nextRequestId() == 1,
            "zero-fee request credits every supplied wei without ASYNC payment"
        );
        vm.recordLogs();
        _safe(
            instantPayer,
            address(entropy),
            0,
            abi.encodeCall(entropy.claimEntropyFeeCredit, (payable(address(instantPayer))))
        );
        logs = vm.getRecordedLogs();
        uint256 claims;
        for (uint256 i; i < logs.length; ++i) {
            if (
                logs[i].emitter == address(entropy) && logs[i].topics.length == 3
                    && logs[i].topics[0]
                        == keccak256("EntropyFeeCreditClaimed(address,address,uint256)")
            ) {
                require(
                    logs[i].topics[1] == bytes32(uint256(uint160(address(instantPayer))))
                        && logs[i].topics[2] == logs[i].topics[1]
                        && keccak256(logs[i].data) == keccak256(abi.encode(REQUEST_VALUE)),
                    "exact original credit-claim receipt"
                );
                ++claims;
            }
        }
        require(
            claims == 1 && entropy.totalFeeCredits() == 0
                && entropy.entropyFeeCredit(address(instantPayer)) == 0
                && address(entropy).balance == 0
                && address(instantPayer).balance == 1 ether - PRICE,
            "original Safe request credit completely discharged"
        );
        _final(d);
    }

    function _final(Draw memory d) private view {
        (
            StreamEntropyStatus status,
            bytes32 seed,
            address selected,
            uint32 epoch,
            bytes32 config,
            bytes32 key,
            uint256 id,
            uint16 attempt
        ) = entropy.tokenEntropy(1);
        require(
            status == StreamEntropyStatus.FINALIZED && seed == d.seed
                && selected == address(lowSecurityProvider)
                && epoch == policy.collectionEntropyPolicy(1).providerEpoch
                && config == _instantConfig() && key == d.key && id == d.id && attempt == 1,
            "original final token tuple and independent seed preimage"
        );
        IStreamEntropyEpochs.RequestPolicySnapshot memory expected =
            IStreamEntropyEpochs.RequestPolicySnapshot(
                address(lowSecurityProvider),
                address(lowSecurityProvider).codehash,
                epoch,
                _instantConfig(),
                SALT,
                bytes32(0),
                1
            );
        require(
            keccak256(abi.encode(entropy.requestPolicySnapshot(d.key)))
                == keccak256(abi.encode(expected)),
            "complete original request snapshot normalizes mint input only for INSTANT"
        );
        (
            bytes32 subjectKey,
            uint256 token,
            bytes32 scope,
            address provider_,
            uint64 at,
            uint256 requestId,
            bytes32 raw
        ) = entropy.requests(d.key);
        require(
            subjectKey == keccak256(abi.encode("TOKEN", uint256(1))) && token == 1 && scope == 0
                && provider_ == address(lowSecurityProvider) && at == d.requestedAt
                && requestId == d.id && raw == d.raw
                && entropy.providerRequestKeys(address(lowSecurityProvider), d.id) == d.key,
            "original request fields and both request identity directions"
        );
        (bytes32 seedRead, bool finalized) = entropy.tokenSeed(1);
        require(
            seedRead == d.seed && finalized
                && _subject().inputsHash == keccak256("current instant paid commitment")
                && entropy.pendingRequestCount() == 0 && entropy.nonterminalTokenCount(1) == 0
                && core.coordinatorAtMint(1) == address(entropy),
            "permanent original mint identity and closed synchronous counters"
        );
    }

    function _requestReceipts(Vm.Log[] memory logs, Draw memory d) private view {
        uint256 requests;
        uint256 produced;
        uint256 finalized;
        uint256 credited;
        for (uint256 i; i < logs.length; ++i) {
            if (logs[i].emitter != address(entropy) || logs[i].topics.length == 0) continue;
            bytes32 topic = logs[i].topics[0];
            if (topic == keccak256("EntropyRequested(bytes32,uint256,bytes32,address,uint256)")) {
                require(
                    logs[i].topics.length == 4 && logs[i].topics[1] == d.key
                        && logs[i].topics[2] == bytes32(uint256(1)) && logs[i].topics[3] == 0
                        && keccak256(logs[i].data)
                            == keccak256(abi.encode(address(lowSecurityProvider), d.id)),
                    "exact original request receipt"
                );
                ++requests;
            } else if (
                topic
                    == keccak256(
                        "InstantEntropyProduced(uint16,bytes32,uint256,bytes32,bytes32,uint8,bytes32)"
                    )
            ) {
                require(
                    requests == 1 && logs[i].topics.length == 3 && logs[i].topics[1] == d.key
                        && logs[i].topics[2] == bytes32(d.id)
                        && keccak256(logs[i].data)
                            == keccak256(
                                abi.encode(uint16(1), d.raw, d.provenance, uint8(1), ASSUMPTIONS)
                            ),
                    "independent production raw randomness, provenance and LOW_SECURITY disclosure receipt"
                );
                ++produced;
            } else if (
                topic == keccak256("EntropyFinalized(bytes32,uint256,bytes32,bytes32,bytes32)")
            ) {
                require(
                    produced == 1 && logs[i].topics.length == 4 && logs[i].topics[1] == d.key
                        && logs[i].topics[2] == bytes32(uint256(1)) && logs[i].topics[3] == 0
                        && keccak256(logs[i].data) == keccak256(abi.encode(d.seed, d.raw)),
                    "exact original finalization receipt"
                );
                ++finalized;
            } else if (topic == keccak256("EntropyFeeCredited(address,uint256)")) {
                require(
                    logs[i].topics.length == 2
                        && logs[i].topics[1] == bytes32(uint256(uint160(address(instantPayer))))
                        && keccak256(logs[i].data) == keccak256(abi.encode(REQUEST_VALUE)),
                    "exact full-value request credit"
                );
                ++credited;
            }
        }
        require(
            requests == 1 && produced == 1 && finalized == 1 && credited == 1,
            "one successful original request, production provenance, finalization and full credit"
        );
    }

    function _requestReplay() internal {
        vm.roll(block.number + 1);
        Draw memory original = _finishRequest(_requestPayload());
        vm.roll(block.number + 1);
        require(_draw().raw != original.raw, "later-block candidate differs before refused reroll");
        bytes memory replay = _requestPayload(); // Fresh valid Safe nonce reaches the actual status guard.
        _requestRefused(
            replay,
            abi.encodeWithSelector(
                StreamEntropyCoordinator.InvalidStatus.selector, StreamEntropyStatus.FINALIZED
            )
        );
        _final(original);
    }

    function _notRequiredRefusal() internal {
        bytes memory payload = _requestPayload();
        _requestRefused(
            payload,
            abi.encodeWithSelector(
                StreamEntropyCoordinator.InvalidStatus.selector, StreamEntropyStatus.NOT_REQUIRED
            )
        );
        _registered(false);
    }
}
