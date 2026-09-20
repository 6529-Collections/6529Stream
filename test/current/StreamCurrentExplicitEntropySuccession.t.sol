// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../helpers/StreamCurrentSafeGovernanceFixture.sol";
import {
    StreamEntropyPolicySuccessionPlan
} from "../../script/current/StreamEntropyPolicySuccessionPlan.sol";
import { StreamEntropyFallbackPlan } from "../../script/current/StreamEntropyFallbackPlan.sol";
import "../../smart-contracts/domains/entropy/StreamEntropyProviderInstant.sol";
import {
    IStreamEntropyCollectionPolicy as SuccessionPolicy
} from "../../smart-contracts/interfaces/stream/entropy/IStreamEntropyCollectionPolicy.sol";
import {
    IStreamEntropyPolicyContinuity as SuccessionContinuity
} from "../../smart-contracts/interfaces/stream/entropy/IStreamEntropyPolicyContinuity.sol";
import {
    IStreamEntropyOriginRelay as SuccessionRelay
} from "../../smart-contracts/interfaces/stream/entropy/IStreamEntropyOriginRelay.sol";
import {
    IStreamArtistContentAuthority as ContentAuthority
} from "../../smart-contracts/interfaces/stream/artist/IStreamArtistContentAuthority.sol";
import {
    IStreamArtistContentHostEvidence
} from "../../smart-contracts/interfaces/stream/artist/IStreamArtistContentHostEvidence.sol";
import {
    IStreamArtistContentRecordsOwner
} from "../../smart-contracts/interfaces/stream/artist/IStreamArtistContentOwner.sol";
import {
    StreamArtistContentTypes as Content
} from "../../smart-contracts/interfaces/stream/artist/StreamArtistContentTypes.sol";

interface ExplicitSuccessionFaultVm {
    function mockCallRevert(address target, bytes calldata data, bytes calldata reason) external;
    function clearMockedCalls() external;
}

/// @notice Actual Artist consent, governed policy import, Safe purchases and successor requests.
/// @dev Source recipes only until the exact Artist/Router creation graph fits and is executed.
/// Core, Artist owners, Executor, registry, manifest, Manager and Safes are production contracts.
/// ASYNC randomness is the existing original-bound mock; INSTANT uses its production provider.
contract StreamCurrentExplicitEntropySuccessionTest is StreamCurrentSafeGovernanceFixture {
    bytes32 private constant ENTROPY = keccak256("ENTROPY_COORDINATOR");
    bytes32 private constant FAMILY = keccak256("6529STREAM_ENTROPY_CONFIGURATION_V1");
    bytes32 private constant SALT = keccak256("explicit current succession salt");
    bytes32 private constant IMPORT = keccak256("explicit current succession inventory");
    bytes32 private constant SCOPE_INPUT = keccak256("actual successor allocation inputs");
    uint256 private constant FEE = 5;
    StreamEntropyCoordinator private candidate;
    StreamEntropyProviderInstant private instant;
    OfficialSafe private artistSafe;
    OfficialSafe private buyerSafe;
    uint256[] private keys;
    uint256 private purchaseNonce;

    function _start(SuccessionPolicy.Mode mode, bool required, bool freeze) private {
        keys.push(0xEAC001);
        keys.push(0xEAC002);
        SafeComponents memory safe = deploySafeComponents("1.4.1");
        artistSafe = createOfficialSafe(safe, safeOwnerAddresses(keys), 2, 8101);
        buyerSafe = createOfficialSafe(safe, safeOwnerAddresses(keys), 2, 8102);
        OfficialSafe governor = createOfficialSafe(safe, safeOwnerAddresses(keys), 2, 8103);
        vm.deal(address(this), 100 ether);
        vm.deal(address(buyerSafe), 20 ether);
        _deployCurrentStack(address(artistSafe), vm.addr(PLATFORM_KEY));
        _installGovernorSafe(governor, keys);
        _assertDeployableProductionInstance(address(candidate));
        _assertDeployableProductionInstance(address(instant));
        _batch(StreamEntropyFallbackPlan.registration(registry, entropy, candidate, 500000));
        _admit(entropy, address(instant));
        _admit(candidate, address(provider));
        _admit(candidate, address(instant));
        provider.setFee(FEE);
        _configure(mode, required, freeze);
    }

    function _artistProof(bytes32 digest) internal override returns (bytes memory) {
        return safeThresholdSignature(keys, safeMessageDigest(artistSafe, abi.encode(digest)));
    }

    function _deployAdditionalProducts() internal override {
        candidate = StreamEntropyCoordinator(
            payable(_artistArtifactCreate(
                    "smart-contracts/domains/entropy/StreamEntropyCoordinator.sol:StreamEntropyCoordinator",
                    abi.encode(
                        StreamEntropyFallbackPlan.deploymentConfig(
                            entropy,
                            StreamCurrentStackPlan.entropyTimeParameters(),
                            DEPLOYMENT_HASH,
                            "urn:fixture:explicit-successor",
                            keccak256("explicit successor module")
                        )
                    )
                ))
        );
        instant = StreamEntropyProviderInstant(
            _artistArtifactCreate(
                "smart-contracts/domains/entropy/StreamEntropyProviderInstant.sol:StreamEntropyProviderInstant",
                abi.encode(address(entropy))
            )
        );
    }

    function _additionalOperatingPolicies()
        internal
        view
        override
        returns (GovernanceActionPolicyEntry[] memory rows)
    {
        StreamEntropyCoordinator[] memory origins = new StreamEntropyCoordinator[](1);
        origins[0] = entropy;
        GovernanceActionPolicyEntry[] memory succession =
            StreamEntropyPolicySuccessionPlan.catalogRows(candidate, origins, DEPLOYMENT_HASH);
        rows = new GovernanceActionPolicyEntry[](8);
        for (uint256 i; i < succession.length; ++i) {
            rows[i] = succession[i];
        }
        rows[4] = _row(1, address(candidate), candidate.activateEntropyProvider.selector);
        rows[5] = _row(1, address(candidate), candidate.setRequester.selector);
        rows[6] =
            _row(1, address(entropy), SuccessionPolicy.configureCollectionEntropyPolicy.selector);
        rows[7] = _row(2, address(entropy), SuccessionPolicy.freezeCollectionEntropyPolicy.selector);
    }

    function _row(uint8 cls, address target, bytes4 selector)
        private
        view
        returns (GovernanceActionPolicyEntry memory)
    {
        return GovernanceActionPolicyEntry(
            cls,
            target,
            selector,
            target.codehash,
            keccak256(abi.encode(DEPLOYMENT_HASH, target)),
            1,
            0,
            0,
            0
        );
    }

    function _admit(StreamEntropyCoordinator host, address selected) private {
        (GovernanceCall memory call_, bytes memory data) =
            StreamEntropyLifecyclePlan.activate(host, selected, "urn:fixture:original-provider");
        _one(1, call_, data);
    }

    function _one(uint8 cls, GovernanceCall memory call_, bytes memory data)
        private
        returns (bytes32)
    {
        GenesisBatch memory b;
        b.actionClass = cls;
        b.calls = new GovernanceCall[](1);
        b.callDatas = new bytes[](1);
        b.calls[0] = call_;
        b.callDatas[0] = data;
        return _batch(b);
    }

    function _batch(GenesisBatch memory b) private returns (bytes32 id) {
        uint64 ready;
        (id, ready) = _scheduleBatchAsGovernor(b.actionClass, b.calls, b.callDatas);
        vm.warp(ready);
        this.executeCurrentGovernorCall(
            address(executor),
            abi.encodeCall(executor.executeGovernanceBatch, (id, b.calls, b.callDatas))
        );
        require(
            executor.governanceAction(id).status == GovernanceActionStatus.EXECUTED,
            "actual delayed Safe batch"
        );
    }

    function _configure(SuccessionPolicy.Mode mode, bool required, bool freeze) private {
        SuccessionPolicy.PolicyInput memory p;
        p.mode = mode;
        p.renderRequirement = required
            ? SuccessionPolicy.RenderRequirement.REQUIRED
            : SuccessionPolicy.RenderRequirement.NOT_REQUIRED;
        if (mode != SuccessionPolicy.Mode.DISABLED) {
            p.provider =
                mode == SuccessionPolicy.Mode.INSTANT ? address(instant) : address(provider);
            p.collectionSalt = SALT;
            p.publicRequests = true;
        }
        if (mode == SuccessionPolicy.Mode.INSTANT) {
            p.securityClass = SuccessionPolicy.SecurityClass.LOW_SECURITY;
        }
        if (mode == SuccessionPolicy.Mode.ASYNC) {
            p.timeoutBlocks = 100;
            p.reveal = IStreamRevealFeeEscrow.CollectionRevealPolicy(
                true, 0, keccak256("ROLE_ENTROPY_REVEAL_OWNER"), 100, FEE
            );
        }
        SuccessionPolicy policy = SuccessionPolicy(address(entropy));
        (bytes32 scope, bytes32 old_, bytes32 next, bytes32 content) =
            policy.collectionEntropyPolicyTransition(1, p);
        bytes32 consent = _consent(content);
        bytes memory data = abi.encodeCall(policy.configureCollectionEntropyPolicy, (uint256(1), p));
        bytes32 action =
            _one(1, StreamCurrentStackPlan.call(address(entropy), data, scope, old_, next), data);
        SuccessionPolicy.PolicyRecord memory record = policy.collectionEntropyPolicy(1);
        require(
            record.explicitPolicy && record.revision == 1 && record.lastActionId == action
                && record.artistConsentRecord == consent && record.contentStateHash == content,
            "actual explicit action and Artist receipt"
        );
        require(
            record.policyHash == _hash(address(entropy), p, record.providerEpoch)
                && record.policyHash != _hash(address(candidate), p, record.providerEpoch)
                && content == keccak256(abi.encode(FAMILY, record.policyHash, false)),
            "independent policy preimage binds original Coordinator"
        );
        if (!freeze) return;
        (scope, old_, next, content) = policy.freezeCollectionEntropyPolicyTransition(1);
        bytes32 frozenConsent = _consent(content);
        require(frozenConsent != consent, "separate Artist freeze consent");
        data = abi.encodeCall(policy.freezeCollectionEntropyPolicy, (uint256(1)));
        action =
            _one(2, StreamCurrentStackPlan.call(address(entropy), data, scope, old_, next), data);
        SuccessionPolicy.PolicyRecord memory frozen = policy.collectionEntropyPolicy(1);
        require(
            frozen.frozen && frozen.revision == 2 && frozen.policyHash == record.policyHash
                && frozen.lastActionId == action && frozen.artistConsentRecord == frozenConsent
                && content == keccak256(abi.encode(FAMILY, record.policyHash, true)),
            "separate governed freeze retains original policy hash"
        );
    }

    function _hash(address origin, SuccessionPolicy.PolicyInput memory p, uint32 epoch)
        private
        view
        returns (bytes32)
    {
        bytes32 config = p.provider == address(0)
            ? bytes32(0)
            : IStreamEntropyProvider(p.provider).streamEntropyProviderConfigHash();
        return keccak256(
            abi.encode(
                keccak256("6529STREAM_ENTROPY_COLLECTION_POLICY_V2"),
                block.chainid,
                origin,
                address(core),
                uint256(1),
                p.mode,
                p.securityClass,
                p.renderRequirement,
                p.provider,
                p.provider == address(0) ? bytes32(0) : p.provider.codehash,
                config,
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

    function _consent(bytes32 content) private returns (bytes32 expected) {
        T.Authorization memory a;
        a.nonce =
        IStreamArtistIdentityOwner(artistSuite.owners[2]).identity(fixtureArtistId).nonceHint;
        a.time = uint64(block.timestamp + 1 days);
        expected = keccak256(
            abi.encode(
                keccak256("6529STREAM_ARTIST_CONTENT_CONSENT_RECORD_V1"),
                block.chainid,
                address(artists),
                address(entropy),
                address(core),
                uint256(1),
                FAMILY,
                content,
                fixtureArtistId,
                address(artistSafe),
                uint8(1),
                a.nonce,
                uint64(block.timestamp)
            )
        );
        require(
            executeSafe(
                artistSafe,
                keys,
                address(artists),
                0,
                abi.encodeCall(
                    ContentAuthority.recordContentConsent,
                    (Content.Consent(1, address(entropy), FAMILY, content), a)
                ),
                0
            ),
            "actual Artist Safe consent"
        );
        require(
            IStreamArtistContentHostEvidence(address(artists))
                .contentConsentEvidenceForHost(1, address(entropy), FAMILY, content) == expected,
            "original host-bound Artist consent preimage"
        );
    }

    function _artistState() private view returns (bytes32) {
        T.Snapshot[7] memory rows;
        for (uint256 i; i < rows.length; ++i) {
            rows[i] = IStreamArtistOwner(artistSuite.owners[i]).ownerStateSnapshotV2();
        }
        return keccak256(abi.encode(rows));
    }

    function _migrate() private returns (SuccessionContinuity.PolicyExport memory original) {
        original = SuccessionContinuity(address(entropy)).exportEntropyPolicy(1);
        IStreamArtistContentRecordsOwner owner =
            IStreamArtistContentRecordsOwner(artistSuite.owners[6]);
        IStreamArtistContentRecordsOwner.ConsentRecord memory historical =
            owner.contentConsentRecord(original.record.artistConsentRecord);
        require(
            historical.recordHash == original.record.artistConsentRecord
                && historical.artistId == fixtureArtistId && historical.authorityClass == 1
                && historical.terms.collectionId == 1
                && historical.terms.metadataContract == address(entropy)
                && historical.terms.familyId == FAMILY
                && historical.terms.newStateHash == original.record.contentStateHash,
            "permanent original Artist consent facts"
        );
        bytes32 artistBefore = _artistState();
        _batch(StreamEntropyPolicySuccessionPlan.begin(entropy, candidate, IMPORT));
        SuccessionContinuity(address(candidate)).importNextEntropyPolicy(0);
        _assertOriginal(original);
        bool routed = original.policy.mode == SuccessionPolicy.Mode.ASYNC
            || (original.policy.mode == SuccessionPolicy.Mode.INSTANT
                && original.policy.renderRequirement == SuccessionPolicy.RenderRequirement.REQUIRED);
        if (routed) {
            _batch(StreamEntropyPolicySuccessionPlan.admitRoute(entropy, candidate, 1));
            SuccessionContinuity(address(candidate)).confirmEntropyRelayRoute(1);
        }
        SuccessionContinuity.ImportReceipt memory receipt =
            SuccessionContinuity(address(candidate)).entropyPolicyImport();
        require(
            receipt.count == 1 && receipt.nextIndex == 1
                && receipt.requiredRelayCount == (routed ? 1 : 0)
                && receipt.confirmedRelayCount == (routed ? 1 : 0),
            "mode-specific route requirement"
        );
        _batch(StreamEntropyPolicySuccessionPlan.seal(candidate));
        receipt = SuccessionContinuity(address(candidate)).entropyPolicyImport();
        uint256 publications = manifest.streamSystemManifestPointerCount();
        (address payload, StreamSystemManifestUpdate memory update) = _publication();
        bytes32 action = _batch(
            StreamEntropyPolicySuccessionPlan.cutover(
                core, registry, entropy, candidate, manifest, payload, update
            )
        );
        receipt.state = SuccessionContinuity.ImportState.ACTIVE;
        receipt.activationActionId = action;
        require(
            keccak256(abi.encode(SuccessionContinuity(address(candidate)).entropyPolicyImport()))
                    == keccak256(abi.encode(receipt))
                && StreamCurrentStackPlan.readPointer(core, ENTROPY).target == address(candidate)
                && StreamCurrentStackPlan.readPointer(core, ENTROPY).revision
                    == receipt.pointerRevision + 1
                && StreamGenesisManifestPlan.readAggregate(manifest).modules.entropyCoordinator
                    == address(candidate)
                && manifest.streamSystemManifestPointerCount() == publications + 1,
            "atomic actual Core and manifest cutover"
        );
        _assertOriginal(original);
        require(_artistState() == artistBefore, "import creates no Artist action, nonce or receipt");
        // The facade's evidence reader authenticates the currently selected host. Historical
        // authorization remains at its permanent owner and original binding generation.
        require(
            keccak256(abi.encode(owner.contentConsentRecord(historical.recordHash)))
                    == keccak256(abi.encode(historical))
                && keccak256(
                    abi.encode(
                        owner.contentConsentAt(historical.terms, historical.bindingGeneration)
                    )
                ) == keccak256(abi.encode(historical)),
            "permanent Artist evidence retains the original host domain after cutover"
        );
    }

    function _publication()
        private
        returns (address payload, StreamSystemManifestUpdate memory update)
    {
        StreamSystemManifest.AggregateState memory current =
            StreamGenesisManifestPlan.readAggregate(manifest);
        bytes32 hash;
        (payload, hash) = StreamGenesisManifestPlan.writePayload(
            bytes("{\"purpose\":\"actual explicit entropy succession\"}")
        );
        update = StreamSystemManifestUpdate(
            hash,
            "urn:fixture:explicit-entropy-succession",
            current.discovery.eventCatalogHash,
            current.discovery.compatibilityMatrixHash,
            current.discovery.numericIdCatalogHash,
            current.discovery.schemaCatalogHash,
            current.discovery.canonicalizationCatalogHash,
            current.discovery.specBundleHash,
            current.discovery.reconstructionClientHash
        );
    }

    function _assertOriginal(SuccessionContinuity.PolicyExport memory original) private view {
        require(
            original.profile == SuccessionContinuity.PolicyProfile.EXPLICIT
                && original.record.artistConsentRecord != 0 && original.record.lastActionId != 0
                && original.policyOrigin == address(entropy),
            "actual original evidence exists"
        );
        require(
            keccak256(abi.encode(SuccessionContinuity(address(candidate)).exportEntropyPolicy(1)))
                == keccak256(abi.encode(original)),
            "complete explicit policy and original Artist/action receipts copied byte-exactly"
        );
        (bytes32 imported, bytes32 exported, address origin, bytes32 pin, bytes32 hash) =
            SuccessionContinuity(address(candidate)).importedEntropyPolicy(1);
        require(
            imported == SuccessionContinuity(address(candidate)).entropyPolicyImport().importHash
                && exported == keccak256(abi.encode(original)) && origin == address(entropy)
                && pin == address(entropy).codehash && hash == original.record.policyHash,
            "exact independent import witness"
        );
    }

    function _buy(StreamEntropyCoordinator expected) private returns (uint256 token) {
        IStreamFixedPriceSaleAdapter.SaleAuthorization memory a =
            IStreamFixedPriceSaleAdapter.SaleAuthorization(
                1,
                PHASE,
                address(buyerSafe),
                address(buyerSafe),
                artist,
                profile,
                _nativePrimaryPolicyHash(),
                keccak256(TOKEN_DATA),
                keccak256(abi.encode("succession mint", ++purchaseNonce)),
                manager.phasePolicyHash(1, PHASE),
                0.01 ether,
                bytes32(purchaseNonce),
                uint64(block.timestamp + 1 days),
                sale.signerEpoch()
            );
        bytes32 digest = sale.authorizationDigest(a);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(PLATFORM_KEY, digest);
        require(
            executeSafe(
                buyerSafe,
                keys,
                address(sale),
                a.price,
                abi.encodeCall(
                    sale.buy, (a, TOKEN_DATA, abi.encodePacked(r, s, v), _artistProof(digest))
                ),
                0
            ),
            "actual signed Safe purchase"
        );
        token = core.lastAllocatedTokenId();
        require(
            core.ownerOf(token) == address(buyerSafe)
                && core.coordinatorAtMint(token) == address(expected),
            "actual Core minted at selected Coordinator"
        );
    }

    function _packet(StreamEntropyCoordinator host, bytes memory data, uint256 value)
        private
        returns (bytes memory)
    {
        bytes32 digest = buyerSafe.getTransactionHash(
            address(host), value, data, 0, 0, 0, 0, address(0), address(0), buyerSafe.nonce()
        );
        return abi.encodeCall(
            buyerSafe.execTransaction,
            (
                address(host),
                value,
                data,
                0,
                0,
                0,
                0,
                address(0),
                payable(address(0)),
                safeThresholdSignature(keys, digest)
            )
        );
    }

    function submitPacket(bytes calldata packet) external returns (bool) {
        require(msg.sender == address(this));
        (bool ok, bytes memory out) = address(buyerSafe).call(packet);
        if (!ok) assembly ("memory-safe") { revert(add(out, 32), mload(out)) }
        return abi.decode(out, (bool));
    }

    function _request(StreamEntropyCoordinator host, uint256 token, uint256 value)
        private
        returns (bytes32 key, uint256 id)
    {
        return _sendRequest(
            host, token, 0, _packet(host, abi.encodeCall(host.requestEntropy, (token)), value)
        );
    }

    function _sendRequest(
        StreamEntropyCoordinator host,
        uint256 token,
        bytes32 scope,
        bytes memory packet
    ) private returns (bytes32 key, uint256 id) {
        vm.recordLogs();
        require(this.submitPacket(packet), "actual Safe entropy request");
        Vm.Log[] memory logs = vm.getRecordedLogs();
        for (uint256 i; i < logs.length; ++i) {
            if (
                logs[i].emitter == address(host) && logs[i].topics.length == 4
                    && logs[i].topics[0]
                        == keccak256("EntropyRequested(bytes32,uint256,bytes32,address,uint256)")
            ) {
                require(
                    key == 0 && logs[i].topics[2] == bytes32(token) && logs[i].topics[3] == scope,
                    "one exact subject request"
                );
                key = logs[i].topics[1];
                address selected;
                (selected, id) = abi.decode(logs[i].data, (address, uint256));
                require(
                    selected == host.requestPolicySnapshot(key).provider,
                    "original provider in request event"
                );
            }
        }
        require(key != 0 && id != 0, "actual request identity");
    }

    function _context(StreamEntropyCoordinator host, uint256 token, bytes32 scope, bytes32 key)
        private
        view
        returns (bytes memory)
    {
        IStreamEntropyEpochs.RequestPolicySnapshot memory p = host.requestPolicySnapshot(key);
        return abi.encode(
            scope == 0 ? uint16(1) : uint16(2),
            address(core),
            uint256(1),
            token,
            scope,
            p.providerEpoch,
            p.providerConfigHash,
            p.requestAttempt,
            p.inputsHash
        );
    }

    function _relay(uint256 token, bytes32 scope, bytes32 key) private view returns (bytes32) {
        return keccak256(
            abi.encode(
                keccak256("6529STREAM_ENTROPY_RELAY_V1"),
                block.chainid,
                address(entropy),
                address(candidate),
                address(candidate).codehash,
                SuccessionContinuity(address(candidate)).entropyPolicyImport().importHash,
                uint256(1),
                key,
                keccak256(_context(candidate, token, scope, key))
            )
        );
    }

    function _final(
        StreamEntropyCoordinator host,
        uint256 token,
        bytes32 scope,
        bytes32 key,
        uint256 id,
        bytes32 raw
    ) private view {
        IStreamEntropyEpochs.RequestPolicySnapshot memory p = host.requestPolicySnapshot(key);
        bytes32 seed = keccak256(
            abi.encode(
                StreamEntropyCoordinator.SeedInputs(
                    scope == 0
                        ? keccak256("6529STREAM_ENTROPY_SEED_V1")
                        : keccak256("6529STREAM_ENTROPY_SCOPE_SEED_V1"),
                    block.chainid,
                    address(host),
                    address(core),
                    1,
                    token == 0 ? scope : bytes32(token),
                    p.provider,
                    p.providerEpoch,
                    p.providerConfigHash,
                    key,
                    id,
                    raw,
                    p.collectionSalt,
                    p.inputsHash
                )
            )
        );
        (bytes32 actual, bool finalized) =
            token == 0 ? host.scopeSeed(scope) : host.tokenSeed(token);
        require(
            finalized && actual == seed && host.providerRequestKeys(p.provider, id) == key,
            "independent successor seed and original provider identity"
        );
        require(host.pendingRequestCount() == 0, "one real pending request closed");
    }

    function _finishRelay(uint256 token, bytes32 scope, bytes32 key, uint256 id, bytes32 raw)
        private
    {
        bytes32 relayId = _relay(token, scope, key);
        SuccessionRelay.RelayResult memory result =
            SuccessionRelay(address(entropy)).entropyRelayResult(relayId);
        require(
            result.submitted && result.successor == address(candidate)
                && result.provider == address(provider) && result.providerRequestId == id
                && result.successorRequestKey == key
                && result.contextHash == keccak256(_context(candidate, token, scope, key)),
            "real origin route preserves successor context and actual provider ID"
        );
        require(
            address(provider.coordinator()) == address(entropy)
                && entropy.providerRequestKeys(address(provider), id) == 0,
            "provider accepts only ultimate origin without an invented origin subject"
        );
        uint256 draws = provider.nextRequestId();
        require(provider.fulfill(id, raw) == 0, "origin captures provider result");
        (bool delivered, uint8 outcome) =
            SuccessionRelay(address(entropy)).retryEntropyRelay(relayId);
        require(
            delivered && outcome == 0 && provider.nextRequestId() == draws,
            "delivery retry cannot redraw"
        );
        result = SuccessionRelay(address(entropy)).entropyRelayResult(relayId);
        require(
            result.rawReceived && result.raw == raw && result.delivered,
            "raw zero is a received result"
        );
        _final(candidate, token, scope, key, id, raw);
    }

    function testActualArtistAsyncCutoverPreservesReceiptsOldSeedsEscrowsAndSafeCredits() public {
        _start(SuccessionPolicy.Mode.ASYNC, true, true);
        entropy.fundRevealFeeEscrow{ value: 11 }(1);
        uint256 oldToken = _buy(entropy);
        (bytes32 oldKey, uint256 oldId) = _request(entropy, oldToken, 9);
        require(provider.fulfill(oldId, IMPORT) == 0);
        _final(entropy, oldToken, 0, oldKey, oldId, IMPORT);
        (bytes32 oldSeed,) = entropy.tokenSeed(oldToken);
        SuccessionContinuity.PolicyExport memory original = _migrate();
        require(
            candidate.revealFeeEscrow(1) == 0 && candidate.totalFeeCredits() == 0
                && entropy.revealFeeEscrow(1) == 6
                && entropy.entropyFeeCredit(address(buyerSafe)) == 9,
            "policy import never copies historical escrow or credit"
        );
        candidate.fundRevealFeeEscrow{ value: 3 }(1);
        uint256 token = _buy(candidate);
        (bytes32 key, uint256 id) = _request(candidate, token, 9);
        require(
            candidate.revealFeeEscrow(1) == 0 && candidate.totalRevealFeeEscrows() == 0
                && candidate.entropyFeeCredit(address(buyerSafe)) == 7
                && candidate.totalFeeCredits() == 7 && address(candidate).balance == 7
                && address(provider).balance == 10 && address(entropy).balance == 15,
            "actual two-host fee conservation"
        );
        _finishRelay(token, 0, key, id, 0);
        (bytes32 retained,) = entropy.tokenSeed(oldToken);
        require(
            retained == oldSeed && core.coordinatorAtMint(oldToken) == address(entropy)
                && entropy.tokenEntropyStatus(token) == StreamEntropyStatus.NONE,
            "historical subject and seed stay at origin"
        );
        _assertOriginal(original);
        uint256 balance = address(buyerSafe).balance;
        require(
            this.submitPacket(
                _packet(
                    candidate,
                    abi.encodeCall(candidate.claimEntropyFeeCredit, (payable(address(buyerSafe)))),
                    0
                )
            )
        );
        require(
            address(buyerSafe).balance == balance + 7 && candidate.totalFeeCredits() == 0
                && address(candidate).balance == 0
                && entropy.entropyFeeCredit(address(buyerSafe)) == 9,
            "successor credit claim cannot drain old liabilities"
        );
    }

    function testActualArtistDisabledCutoverNeedsNoRouteAndNewMintCannotRequest() public {
        _terminal(SuccessionPolicy.Mode.DISABLED, StreamEntropyStatus.DISABLED);
    }

    function testActualArtistInstantNotRequiredCutoverNeedsNoRouteOrProviderDraw() public {
        _terminal(SuccessionPolicy.Mode.INSTANT, StreamEntropyStatus.NOT_REQUIRED);
    }

    function _terminal(SuccessionPolicy.Mode mode, StreamEntropyStatus expected) private {
        _start(mode, false, true);
        SuccessionContinuity.PolicyExport memory original = _migrate();
        uint256 token = _buy(candidate);
        require(
            candidate.tokenEntropyStatus(token) == expected
                && candidate.nonterminalTokenCount(1) == 0 && candidate.pendingRequestCount() == 0
                && candidate.revealFeeEscrow(1) == 0,
            "actual terminal token has no request obligation"
        );
        bytes memory packet =
            _packet(candidate, abi.encodeCall(candidate.requestEntropy, (token)), 7);
        uint256 nonce = buyerSafe.nonce();
        vm.expectRevert();
        this.submitPacket(packet);
        (bytes32 seed, bool final_) = candidate.tokenSeed(token);
        require(
            buyerSafe.nonce() == nonce && seed == 0 && !final_ && provider.nextRequestId() == 1
                && candidate.totalFeeCredits() == 0 && address(candidate).balance == 0
                && candidate.tokenEntropyStatus(token) == expected,
            "terminal refusal creates no fee, seed or Safe nonce"
        );
        _assertOriginal(original);
    }

    function testActualArtistInstantCutoverSameSignedRequestRetriesAndOldTokenKeepsOrigin() public {
        _start(SuccessionPolicy.Mode.INSTANT, true, true);
        uint256 old = _buy(entropy);
        _migrate();
        uint256 token = _buy(candidate);
        bytes memory packet =
            _packet(candidate, abi.encodeCall(candidate.requestEntropy, (token)), 7);
        uint256 nonce = buyerSafe.nonce();
        vm.expectRevert();
        this.submitPacket(packet);
        require(
            buyerSafe.nonce() == nonce
                && candidate.tokenEntropyStatus(token) == StreamEntropyStatus.REGISTERED
                && candidate.totalFeeCredits() == 0,
            "same-block refusal preserves exact packet retry"
        );
        vm.roll(block.number + 1);
        (bytes32 key, uint256 id) = _sendRequest(candidate, token, 0, packet);
        bytes32 raw = keccak256(
            abi.encode(
                keccak256("6529STREAM_INSTANT_BLOCKHASH_RAW_V1"),
                key,
                keccak256(_context(candidate, token, 0, key)),
                block.number - 1,
                blockhash(block.number - 1)
            )
        );
        _final(candidate, token, 0, key, id, raw);
        require(
            candidate.requestPolicySnapshot(key).inputsHash == 0
                && instant.coordinator() == address(entropy)
                && candidate.entropyFeeCredit(address(buyerSafe)) == 7
                && entropy.totalFeeCredits() == 0 && provider.nextRequestId() == 1,
            "original STATIC provider and zero-fee successor domain"
        );
        (key, id) = _request(entropy, old, 0);
        raw = keccak256(
            abi.encode(
                keccak256("6529STREAM_INSTANT_BLOCKHASH_RAW_V1"),
                key,
                keccak256(_context(entropy, old, 0, key)),
                block.number - 1,
                blockhash(block.number - 1)
            )
        );
        _final(entropy, old, 0, key, id, raw);
        require(
            core.coordinatorAtMint(old) == address(entropy)
                && core.coordinatorAtMint(token) == address(candidate)
                && entropy.tokenEntropyStatus(token) == StreamEntropyStatus.NONE,
            "actual original token remains callable after cutover"
        );
    }

    function testActualArtistAsyncNotRequiredStillRoutesScopesAndKeepsTokenTerminal() public {
        _start(SuccessionPolicy.Mode.ASYNC, false, true);
        _migrate();
        uint256 token = _buy(candidate);
        require(
            candidate.tokenEntropyStatus(token) == StreamEntropyStatus.NOT_REQUIRED
                && SuccessionContinuity(address(candidate))
                    .entropyPolicyImport()
                    .confirmedRelayCount == 1,
            "ASYNC scopes still require a route"
        );
        _govern(
            _governanceRequest(
                1,
                address(candidate),
                abi.encodeCall(candidate.setRequester, (address(buyerSafe), true)),
                0,
                0,
                0
            )
        );
        bytes32 scope = keccak256(
            abi.encode(
                keccak256("6529STREAM_ENTROPY_SCOPE_SUBJECT_V1"),
                block.chainid,
                address(candidate),
                address(core),
                uint256(1),
                uint8(1),
                IMPORT
            )
        );
        require(
            this.submitPacket(
                _packet(
                    candidate,
                    abi.encodeCall(candidate.registerEntropyScope, (uint256(1), uint8(1), IMPORT)),
                    0
                )
            )
        );
        candidate.fundRevealFeeEscrow{ value: 11 }(1);
        (bytes32 key, uint256 id) = _sendRequest(
            candidate,
            0,
            scope,
            _packet(
                candidate, abi.encodeCall(candidate.requestScopeEntropy, (scope, SCOPE_INPUT)), 9
            )
        );
        require(
            candidate.revealFeeEscrow(1) == 11
                && candidate.entropyFeeCredit(address(buyerSafe)) == 4,
            "scope caller pays quote; token escrow is untouched"
        );
        _finishRelay(0, scope, key, id, IMPORT);
        require(
            candidate.tokenEntropyStatus(token) == StreamEntropyStatus.NOT_REQUIRED
                && candidate.nonterminalTokenCount(1) == 0
                && candidate.requestPolicySnapshot(key).inputsHash == SCOPE_INPUT,
            "scope finality never fabricates a terminal token draw"
        );
    }

    function testActualFirstMintAfterCopyInvalidatesUnfrozenExplicitImportWithoutArtistRewrite()
        public
    {
        _start(SuccessionPolicy.Mode.INSTANT, true, false);
        _batch(StreamEntropyPolicySuccessionPlan.begin(entropy, candidate, IMPORT));
        SuccessionContinuity(address(candidate)).importNextEntropyPolicy(0);
        SuccessionContinuity.ImportReceipt memory before_ =
            SuccessionContinuity(address(candidate)).entropyPolicyImport();
        bytes32 artistBefore = _artistState();
        _buy(entropy);
        vm.expectRevert(
            abi.encodeWithSelector(
                SuccessionContinuity.EntropyPolicyImportSourceChanged.selector, address(entropy)
            )
        );
        SuccessionContinuity(address(candidate)).entropyPolicyImportSealTransition();
        require(
            keccak256(abi.encode(SuccessionContinuity(address(candidate)).entropyPolicyImport()))
                    == keccak256(abi.encode(before_)) && _artistState() == artistBefore
                && StreamCurrentStackPlan.readPointer(core, ENTROPY).target == address(entropy),
            "actual Core first registration invalidates only stale import"
        );
    }

    function testActualSafeRelayFailurePreservesEscrowAndIdenticalRequestRetry() public {
        _start(SuccessionPolicy.Mode.ASYNC, true, true);
        _migrate();
        candidate.fundRevealFeeEscrow{ value: 3 }(1);
        uint256 token = _buy(candidate);
        bytes memory packet =
            _packet(candidate, abi.encodeCall(candidate.requestEntropy, (token)), 9);
        bytes32 artistBefore = _artistState();
        uint256 nonce = buyerSafe.nonce();
        ExplicitSuccessionFaultVm fault = ExplicitSuccessionFaultVm(address(vm));
        fault.mockCallRevert(
            address(entropy),
            abi.encodePacked(SuccessionRelay.relayEntropyRequest.selector),
            abi.encodeWithSignature("TemporaryOriginFailure()")
        );
        vm.expectRevert();
        this.submitPacket(packet);
        require(
            buyerSafe.nonce() == nonce && candidate.revealFeeEscrow(1) == 3
                && candidate.totalFeeCredits() == 0 && candidate.pendingRequestCount() == 0
                && candidate.tokenEntropyStatus(token) == StreamEntropyStatus.REGISTERED
                && provider.nextRequestId() == 1 && address(provider).balance == 0
                && _artistState() == artistBefore,
            "actual Safe failure rolls request, provider, credit and fee effects back"
        );
        fault.clearMockedCalls();
        (bytes32 key, uint256 id) = _sendRequest(candidate, token, 0, packet);
        _finishRelay(token, 0, key, id, IMPORT);
        require(
            candidate.entropyFeeCredit(address(buyerSafe)) == 7 && buyerSafe.nonce() == nonce + 1,
            "identical signed request consumes nonce and fee exactly once"
        );
    }
}
