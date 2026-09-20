// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./StreamCurrentStackFixture.sol";
import "./OfficialSafeFixture.sol";
import {
    StreamFullV1StaticRendererPlan
} from "../../script/current/StreamFullV1StaticRendererPlan.sol";
import {
    StreamRendererRegistryModule
} from "../../smart-contracts/domains/metadata/StreamRendererRegistryModule.sol";
import "../../script/current/StreamGovernanceCatalogStagePlan.sol";
import {
    IStreamRenderer as Render
} from "../../smart-contracts/interfaces/stream/metadata/IStreamRenderer.sol";
import {
    IStreamRendererRegistry as Versions
} from "../../smart-contracts/interfaces/stream/metadata/IStreamRendererRegistry.sol";
import {
    IStreamSchemaRegistry as Schema
} from "../../smart-contracts/interfaces/stream/metadata/IStreamSchemaRegistry.sol";
import {
    IStreamStaticMetadataRouter as StaticRouter
} from "../../smart-contracts/interfaces/stream/metadata/IStreamStaticMetadataRouter.sol";
import {
    IStreamStaticMetadataSource as StaticSource
} from "../../smart-contracts/interfaces/stream/metadata/IStreamStaticMetadataSource.sol";
import {
    IStreamStaticEntropySource
} from "../../smart-contracts/interfaces/stream/metadata/IStreamStaticEntropySource.sol";
import { IStreamCoreMint } from "../../smart-contracts/interfaces/stream/core/IStreamCoreMint.sol";
import {
    StreamStaticRenderEncoding
} from "../../smart-contracts/domains/metadata/StreamStaticRenderEncoding.sol";

import {
    IStreamArtistContentAuthority
} from "../../smart-contracts/interfaces/stream/artist/IStreamArtistContentAuthority.sol";
import {
    StreamArtistContentTypes as Content
} from "../../smart-contracts/interfaces/stream/artist/StreamArtistContentTypes.sol";
import { Strings } from "../../smart-contracts/vendor/openzeppelin/Strings.sol";
import { Base64 } from "../../smart-contracts/vendor/openzeppelin/Base64.sol";

interface StaticTokenVm {
    function expectCall(address target, bytes calldata data) external;
}

/// @dev Buyer-chosen receiver; its ordinary repair never changes protocol state.
contract StaticTokenReceiver {
    address private immutable controller = msg.sender;
    address private immutable core;
    bool private accepts;
    uint256 public calls;

    constructor(address core_) {
        core = core_;
    }

    function repair() external {
        require(msg.sender == controller);
        accepts = true;
    }

    function onERC721Received(address, address from, uint256 id, bytes calldata)
        external
        returns (bytes4)
    {
        require(msg.sender == core && from == address(0) && id == 1, "original mint callback");
        ++calls;
        require(accepts, "explicit receiver rejection");
        return this.onERC721Received.selector;
    }
}

/// @notice Current STATIC token composition, with unchanged production and genesis fixture sources.
/// @dev Admission analysis/empty golden are synthetic joins, not STATIC conformance. The inherited
/// upstream entropy provider and buyer-chosen rejecting receiver are explicit external boundaries.
abstract contract CurrentStaticTokenRenderingFixture is
    StreamCurrentStackFixture,
    OfficialSafeFixture
{
    using Strings for uint256;
    StreamFullV1StaticRendererPlan.Configuration internal configuration;
    StreamFullV1StaticRendererPlan.Products internal rendering;
    Versions.Registration internal registration;
    Versions.Read[] internal declaredReads;
    OfficialSafe internal governor;
    OfficialSafe internal otherSafe;
    OfficialSafe internal tokenArtist;
    OfficialSafe internal tokenBuyer;
    uint256[] internal keys;
    bytes32 internal versionKey;
    bytes32 internal tokenArtistId;
    bytes32 internal defaultRecord;
    StaticRouter.ConfigRecord internal initialRecord;
    bytes32 internal constant TOKEN_PHASE = keccak256("actual STATIC token phase");
    bytes32 internal constant TOKEN_COMMITMENT = keccak256("actual STATIC token commitment");
    bytes32 internal constant TOKEN_SALT = keccak256("actual STATIC collection salt");
    bytes32 internal constant RAW_RANDOMNESS = keccak256("actual STATIC upstream raw randomness");
    string internal constant PROGRAM = "document.body.textContent='STATIC token';";
    bytes internal constant STATIC_TOKEN_DATA = hex"00ff6529";
    uint256 internal constant PRICE = 1000;

    function _constructStaticTokenRendering() internal {
        keys.push(0x652901);
        keys.push(0x652902);
        SafeComponents memory c = deploySafeComponents("1.4.1");
        governor = createOfficialSafe(c, safeOwnerAddresses(keys), 2, 4723);
        otherSafe = createOfficialSafe(c, safeOwnerAddresses(keys), 2, 4724);
        tokenArtist = createOfficialSafe(c, safeOwnerAddresses(keys), 2, 4725);
        tokenBuyer = createOfficialSafe(c, safeOwnerAddresses(keys), 2, 4726);
        _deployCurrentStack(vm.addr(ARTIST_KEY), vm.addr(PLATFORM_KEY));
        _installGovernor();
        _constructOriginalRenderer();
        _extendCatalog();
        _registerModules();
        _fixtureDocuments();
        _admit(registration);
        _grantWriter();
        _configureTokenCollection();
        vm.deal(address(tokenBuyer), 1 ether);
    }

    function _additionalOperatingPolicies()
        internal
        view
        override
        returns (GovernanceActionPolicyEntry[] memory rows)
    {
        rows = new GovernanceActionPolicyEntry[](2);
        rows[0] = _policy(address(assemblySchemas), assemblySchemas.registerDocument.selector);
        rows[1] = _policy(address(assemblyMetadata), assemblyMetadata.setFamilyWriter.selector);
    }

    function _configureTokenCollection() internal {
        IStreamSplitWallet.SplitEntry[] memory entries = new IStreamSplitWallet.SplitEntry[](2);
        entries[0] =
            IStreamSplitWallet.SplitEntry(address(tokenArtist), 900_000, keccak256("artist"));
        entries[1] = IStreamSplitWallet.SplitEntry(PROTOCOL, 100_000, keccak256("protocol"));
        (profile, wallet) = factory.createProfile(entries, keccak256("STATIC token Artist split"));
        (GovernanceCall memory op, bytes memory data) =
            StreamCurrentStackPlan.createCollectionCall(core, 2, 5);
        _executeStage(_single(op, data), keccak256("actual second collection"));
        _governToken(
            address(router),
            abi.encodeCall(
                router.setCollectionMetadata,
                (2, "STATIC Study", "Exact current token", "ipfs://static-image", "")
            )
        );
        _governToken(address(router), abi.encodeCall(router.setCollectionScript, (2, PROGRAM)));
        _governToken(
            address(royalties),
            abi.encodeCall(royalties.configureCollectionRoyalty, (2, profile, uint16(690)))
        );
        _governToken(
            address(primaryResolver),
            abi.encodeCall(
                primaryResolver.setPrimaryProfileAssignment,
                (PRIMARY_REVENUE_CLASS, uint8(1), uint256(2), profile, bytes32(0))
            )
        );
        _governToken(
            address(entropy),
            abi.encodeCall(
                entropy.configureCollection, (2, address(provider), TOKEN_SALT, true, uint64(100))
            )
        );
        entropy.configureCollectionRevealPolicy(
            2, 0, keccak256("ROLE_ENTROPY_REVEAL_OWNER"), 100, 0
        );
        _tokenSafe(
            governor,
            address(router),
            0,
            abi.encodeCall(router.setDefaultMetadataConfig, (_input()))
        );
        defaultRecord = router.defaultMetadataConfig().recordHash;
        vm.recordLogs();
        _tokenSafe(
            governor,
            address(router),
            0,
            abi.encodeCall(router.activateStaticMetadata, (2, defaultRecord))
        );
        initialRecord = router.collectionMetadataConfig(2);
        require(
            initialRecord.previous == defaultRecord && initialRecord.collectionId == 2
                && initialRecord.tokenId == 0 && initialRecord.revision == 1
                && initialRecord.defaultRevision == 1 && initialRecord.level == 3
                && initialRecord.sourceSnapshotHash == 0,
            "exact captured default wrapper"
        );
        _assertConfigRecord(initialRecord, _input());
        _configEvent(vm.getRecordedLogs(), initialRecord);
        _onboardTokenArtist();
        _configureTokenPhase();
        // Original 8m optional attribution frame needs room inside the Router's own frame.
        // These are explicit governed fixture choices, not production defaults/capacity evidence.
        _raiseTokenGas(
            address(router), keccak256("6529STREAM_GGP_ROUTER_BUNDLE_RENDER_GAS"), 16000000
        );
        _raiseTokenGas(
            address(core),
            0x02ad62929eaa837b9d1704745193125454925fd11a6bf273d7bb1faa23272e93,
            24000000
        );
    }

    function _governToken(address target, bytes memory data) internal {
        _executeStage(
            _single(
                StreamCurrentStackPlan.call(
                    target, data, keccak256(abi.encode(target, data)), 0, keccak256(data)
                ),
                data
            ),
            keccak256(data)
        );
    }

    function _raiseTokenGas(address target, bytes32 id, uint256 next) internal {
        (uint256 value, uint256 floor, uint8 failureClass, uint64 revision) =
            IStreamGasParameterHost(target).gasParameterInfo(id);
        require(next == value * 2, "one ordinary bounded raise");
        bytes32 scope = keccak256(
            abi.encode(keccak256("6529STREAM_GAS_PARAMETER_SCOPE_V2"), block.chainid, target, id)
        );
        bytes32 prior = keccak256(
            abi.encode(
                keccak256("6529STREAM_GAS_PARAMETER_STATE_V2"),
                scope,
                value,
                floor,
                failureClass,
                revision
            )
        );
        bytes32 after_ = keccak256(
            abi.encode(
                keccak256("6529STREAM_GAS_PARAMETER_STATE_V2"),
                scope,
                next,
                floor,
                failureClass,
                revision + 1
            )
        );
        bytes memory data = abi.encodeCall(IStreamGasParameterHost.raiseGasParameter, (id, next));
        _executeStage(
            _single(StreamCurrentStackPlan.call(target, data, scope, prior, after_), data),
            keccak256(data)
        );
        require(
            IStreamGasParameterHost(target).gasParameter(id) == next, "actual governed read frame"
        );
    }

    function _onboardTokenArtist() internal {
        bytes memory document = bytes("STATIC token Artist identity");
        T.BindingProposal memory p;
        p.artistAddress = address(tokenArtist);
        p.identityRecordHash = keccak256(document);
        p.identityRecordURI = "urn:fixture:static-token:artist";
        p.consentMode = 1;
        p.collaborators = new T.CollaboratorRecord[](0);
        p.capabilityPolicyOverrides = new T.CapabilityPolicyOverride[](0);
        (tokenArtistId,) = artists.proposeArtistBinding(2, p, document, "STATIC Artist");
        _tokenSafe(
            tokenArtist,
            address(artists),
            0,
            abi.encodeCall(artists.acceptArtistBinding, (2, _tokenArtistAuth(false)))
        );
        T.PayoutDesignation memory payout =
            T.PayoutDesignation(tokenArtistId, address(tokenArtist), bytes32(0));
        _tokenSafe(
            tokenArtist,
            address(artists),
            0,
            abi.encodeCall(artists.recordPayoutDesignation, (payout, _tokenArtistAuth(true)))
        );
        (T.AssignmentFact memory primary, T.AssignmentFact memory royalty) =
            artistCoordinator.reads().currentAssignments(2);
        _tokenEconomicsConsent(primary);
        _tokenEconomicsConsent(royalty);
        (, bytes32 state) = router.currentArtistContentState(2);
        T.Ratification memory ratification = T.Ratification(2, address(router), state);
        _tokenSafe(
            tokenArtist,
            address(artists),
            0,
            abi.encodeCall(
                artists.recordContentRatification, (ratification, _tokenArtistAuth(false))
            )
        );
        T.Binding memory binding_ = IStreamArtistBindingOwner(artistSuite.owners[0]).binding(2);
        bytes32 facts = StreamArtistHashes.deploymentFacts(
            StreamArtistHashes.Environment(
                block.chainid, address(artists), address(core), address(manager)
            ),
            2,
            binding_
        );
        _tokenAttestation(
            9,
            bytes32(uint256(uint160(address(core)))),
            facts,
            keccak256("6529STREAM_ARTIST_DEPLOYMENT_ATTESTATION_V1")
        );
        _tokenAttestation(
            10,
            tokenArtistId,
            binding_.identityRecordHash,
            keccak256("6529STREAM_ARTIST_PERSONHOOD_WAIVER_V1")
        );
    }

    function _tokenArtistAuth(bool signedAt) internal view returns (T.Authorization memory) {
        uint256 nonce =
            IStreamArtistIdentityOwner(artistSuite.owners[2]).identity(tokenArtistId).nonceHint;
        return
            T.Authorization(
                nonce, uint64(signedAt ? block.timestamp : block.timestamp + 1 days), ""
            );
    }

    function _tokenEconomicsConsent(T.AssignmentFact memory fact) internal {
        T.EconomicsConsent memory c = T.EconomicsConsent(
            2, fact.resolver, fact.revenueClass, fact.scope, fact.scopeId, fact.assignmentHash
        );
        _tokenSafe(
            tokenArtist,
            address(artists),
            0,
            abi.encodeCall(artists.recordEconomicsConsent, (c, _tokenArtistAuth(false)))
        );
    }

    function _tokenAttestation(uint8 kind, bytes32 subject, bytes32 state, bytes32 schema)
        internal
    {
        bytes memory statement = abi.encode(kind, subject, state, schema);
        T.Attestation memory p = T.Attestation(
            2,
            kind,
            subject,
            state,
            schema,
            keccak256(statement),
            "urn:fixture:static-token:statement"
        );
        _tokenSafe(
            tokenArtist,
            address(artists),
            0,
            abi.encodeCall(artists.recordArtistAttestation, (p, _tokenArtistAuth(true), statement))
        );
    }

    function _configureTokenPhase() internal {
        bytes32[] memory ids = new bytes32[](1);
        ids[0] = keccak256("STATIC token supply");
        IStreamMintManager.MintCounterConfig[] memory counters =
            new IStreamMintManager.MintCounterConfig[](1);
        counters[0] = IStreamMintManager.MintCounterConfig(
            true,
            IStreamMintManager.CounterKeyMode.CONSTANT,
            IStreamMintLedger.CounterCapMode.STATIC,
            IStreamMintLedger.CounterDeltaMode.STATIC,
            5,
            1,
            keccak256("STATIC counter")
        );
        IStreamMintManager.MintGateConfig memory gate;
        IStreamMintManager.MintPhaseConfig memory c = IStreamMintManager.MintPhaseConfig(
            false, 0, 0, 1, keccak256("STATIC phase"), keccak256("STATIC metadata")
        );
        address[] memory allowed = new address[](0);
        _tokenPolicyConsent(
            manager.previewPhasePolicyHash(2, TOKEN_PHASE, c, gate, ids, counters, allowed)
        );
        _governToken(
            address(manager),
            abi.encodeCall(manager.configurePhase, (2, TOKEN_PHASE, c, gate, ids, counters))
        );
        allowed = new address[](1);
        allowed[0] = address(sale);
        _tokenPolicyConsent(
            manager.previewPhasePolicyHash(2, TOKEN_PHASE, c, gate, ids, counters, allowed)
        );
        _governToken(
            address(manager),
            abi.encodeCall(manager.setPhaseExecutor, (2, TOKEN_PHASE, address(sale), true))
        );
    }

    function _tokenPolicyConsent(bytes32 policy) internal {
        T.PolicyConsent memory c = T.PolicyConsent(2, TOKEN_PHASE, policy);
        _tokenSafe(
            tokenArtist,
            address(artists),
            0,
            abi.encodeCall(artists.recordPolicyConsent, (c, _tokenArtistAuth(false)))
        );
    }

    function _tokenSafe(OfficialSafe account, address target, uint256 value, bytes memory data)
        internal
    {
        uint256 nonce = account.nonce();
        require(executeSafe(account, keys, target, value, data, 0), "actual STATIC Safe action");
        require(account.nonce() == nonce + 1, "one actual Safe nonce");
    }

    function _tokenPayload(OfficialSafe account, address target, uint256 value, bytes memory data)
        internal
        returns (bytes memory)
    {
        bytes32 digest = account.getTransactionHash(
            target, value, data, 0, 0, 0, 0, address(0), address(0), account.nonce()
        );
        return abi.encodeCall(
            account.execTransaction,
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
                safeThresholdSignature(keys, digest)
            )
        );
    }

    function _tokenFailure(OfficialSafe account, bytes memory exact) internal {
        uint256 nonce = account.nonce();
        uint256 balance = address(account).balance;
        (bool ok, bytes memory out) = address(account).call(exact);
        require(
            !ok && keccak256(out) == keccak256(abi.encodeWithSignature("Error(string)", "GS013")),
            "original failed Safe target"
        );
        require(
            account.nonce() == nonce && address(account).balance == balance,
            "failed Safe nonce and value restored"
        );
    }

    function _tokenSuccess(OfficialSafe account, bytes memory exact) internal {
        uint256 nonce = account.nonce();
        (bool ok, bytes memory out) = address(account).call(exact);
        require(
            ok && abi.decode(out, (bool)) && account.nonce() == nonce + 1,
            "exact original Safe succeeds once"
        );
    }

    function _purchase(address recipient)
        internal
        returns (IStreamFixedPriceSaleAdapter.SaleAuthorization memory a, bytes memory exact)
    {
        (bytes32 policy,,) = sale.primaryPolicy(2);
        a = IStreamFixedPriceSaleAdapter.SaleAuthorization(
            2,
            TOKEN_PHASE,
            address(tokenBuyer),
            recipient,
            address(tokenArtist),
            profile,
            policy,
            keccak256(STATIC_TOKEN_DATA),
            TOKEN_COMMITMENT,
            manager.phasePolicyHash(2, TOKEN_PHASE),
            PRICE,
            keccak256("STATIC purchase nonce"),
            uint64(block.timestamp + 1 days),
            sale.signerEpoch()
        );
        bytes32 digest = sale.authorizationDigest(a);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(PLATFORM_KEY, digest);
        bytes memory artistSignature =
            safeThresholdSignature(keys, safeMessageDigest(tokenArtist, abi.encode(digest)));
        exact = _tokenPayload(
            tokenBuyer,
            address(sale),
            PRICE,
            abi.encodeCall(
                sale.buy, (a, STATIC_TOKEN_DATA, abi.encodePacked(r, s, v), artistSignature)
            )
        );
    }

    function _mintToken() internal {
        (, bytes memory exact) = _purchase(address(tokenBuyer));
        vm.recordLogs();
        _tokenSuccess(tokenBuyer, exact);
        _mintEvents(vm.getRecordedLogs(), address(tokenBuyer));
        _mintState(address(tokenBuyer));
    }

    function _mintState(address recipient) internal view {
        (bool exists, uint256 collection, uint256 serial, bool burned) =
            core.tokenCollectionIdentity(1);
        require(
            exists && collection == 2 && serial == 1 && !burned && core.ownerOf(1) == recipient,
            "literal completed STATIC identity"
        );
        require(
            core.collectionMintedEver(2) == 1 && core.collectionNextSerial(2) == 2
                && core.lastAllocatedTokenId() == 1 && core.totalSupply() == 1
                && manager.nextOperationNonce() == 1 && core.pendingPreparedMintTokenId() == 0,
            "independent one mint allocation"
        );
        require(
            keccak256(core.tokenData(1)) == keccak256(STATIC_TOKEN_DATA)
                && core.coordinatorAtMint(1) == address(entropy),
            "original content and entropy anchor"
        );
        require(
            wallet.balance == PRICE && address(tokenBuyer).balance == 1 ether - PRICE,
            "exact original paid value"
        );
        require(
            router.resolvedMetadataConfig(1).recordHash == initialRecord.recordHash,
            "actual selected token STATIC record"
        );
        _assertMintLedger(true);
    }

    function _assertMintLedger(bool consumed) internal view {
        bytes32 counter = keccak256("STATIC token supply");
        bytes32 subject = keccak256(
            abi.encode(
                keccak256("6529STREAM_MINT_COUNTER_SUBJECT_V1"),
                block.chainid,
                address(ledger),
                IStreamMintManager.CounterKeyMode.CONSTANT,
                uint256(2),
                TOKEN_PHASE,
                counter
            )
        );
        bytes32 key = keccak256(
            abi.encode(
                keccak256("6529STREAM_MINT_COUNTER_VALUE_KEY_V1"),
                address(manager),
                uint256(2),
                TOKEN_PHASE,
                counter,
                subject
            )
        );
        bytes32 authorization = keccak256(
            abi.encode(
                keccak256("6529STREAM_NATIVE_SALE_NONCE_V1"),
                block.chainid,
                address(sale),
                address(tokenArtist),
                keccak256("STATIC purchase nonce")
            )
        );
        require(
            ledger.counterValue(key) == (consumed ? 1 : 0)
                && ledger.isManagerAuthorizationUsed(address(manager), authorization) == consumed,
            "independent original counter and authorization state"
        );
    }

    function _mintEvents(Vm.Log[] memory logs, address recipient) internal view {
        uint256 transfer;
        uint256 registered;
        for (uint256 i; i < logs.length; ++i) {
            if (
                logs[i].emitter == address(core) && logs[i].topics.length == 4
                    && logs[i].topics[0] == keccak256("Transfer(address,address,uint256)")
            ) {
                require(
                    logs[i].topics[1] == 0
                        && logs[i].topics[2] == bytes32(uint256(uint160(recipient)))
                        && logs[i].topics[3] == bytes32(uint256(1)) && logs[i].data.length == 0,
                    "exact minted transfer"
                );
                ++transfer;
            }
            if (
                logs[i].emitter == address(entropy) && logs[i].topics.length == 3
                    && logs[i].topics[0] == keccak256("EntropyRegistered(uint256,uint256,bytes32)")
            ) {
                require(
                    logs[i].topics[1] == bytes32(uint256(2))
                        && logs[i].topics[2] == bytes32(uint256(1))
                        && keccak256(logs[i].data) == keccak256(abi.encode(TOKEN_COMMITMENT)),
                    "exact original registration event"
                );
                ++registered;
            }
        }
        require(transfer == 1 && registered == 1, "one mint and entropy registration receipt");
    }

    function _revealToken() internal returns (bytes32 seed) {
        bytes32 config = keccak256(abi.encode("LOCAL_TEST_ONLY", address(entropy)));
        bytes32 request = keccak256(
            abi.encode(
                keccak256("6529STREAM_ENTROPY_REQUEST_V1"),
                block.chainid,
                address(entropy),
                address(core),
                uint256(2),
                uint256(1),
                address(provider),
                uint32(1),
                config,
                uint16(1)
            )
        );
        vm.recordLogs();
        _tokenSafe(
            tokenBuyer, address(entropy), 0, abi.encodeCall(entropy.requestEntropy, (uint256(1)))
        );
        _oneTokenEvent(
            vm.getRecordedLogs(),
            address(entropy),
            keccak256("EntropyRequested(bytes32,uint256,bytes32,address,uint256)"),
            request,
            bytes32(uint256(1)),
            0,
            abi.encode(address(provider), uint256(1))
        );
        seed = keccak256(
            abi.encode(
                keccak256("6529STREAM_ENTROPY_SEED_V1"),
                block.chainid,
                address(entropy),
                address(core),
                uint256(2),
                bytes32(uint256(1)),
                address(provider),
                uint32(1),
                config,
                request,
                uint256(1),
                RAW_RANDOMNESS,
                TOKEN_SALT,
                TOKEN_COMMITMENT
            )
        );
        vm.recordLogs();
        require(
            provider.fulfill(1, RAW_RANDOMNESS) == 0, "actual coordinator accepts external service"
        );
        _oneTokenEvent(
            vm.getRecordedLogs(),
            address(entropy),
            keccak256("EntropyFinalized(bytes32,uint256,bytes32,bytes32,bytes32)"),
            request,
            bytes32(uint256(1)),
            0,
            abi.encode(seed, RAW_RANDOMNESS)
        );
        (bytes32 actual, bool finalized) = entropy.tokenSeed(1);
        require(finalized && actual == seed, "independent literal-domain seed preimage");
        require(
            provider.fulfill(1, RAW_RANDOMNESS) == 3, "original fulfilled request replay denied"
        );
    }

    function _oneTokenEvent(
        Vm.Log[] memory logs,
        address emitter,
        bytes32 signature,
        bytes32 a,
        bytes32 b,
        bytes32 c,
        bytes memory expected
    ) internal pure {
        uint256 count;
        for (uint256 i; i < logs.length; ++i) {
            if (
                logs[i].emitter != emitter || logs[i].topics.length != 4
                    || logs[i].topics[0] != signature
            ) continue;
            require(
                logs[i].topics[1] == a && logs[i].topics[2] == b && logs[i].topics[3] == c
                    && keccak256(logs[i].data) == keccak256(expected),
                "exact original STATIC receipt"
            );
            ++count;
        }
        require(count == 1, "one exact original STATIC receipt");
    }

    function _assertConfigRecord(
        StaticRouter.ConfigRecord memory record,
        StaticRouter.ConfigInput memory input
    ) internal view {
        bytes32 targetsHash = keccak256(abi.encode(_targets()));
        bytes32 readsHash = keccak256(
            abi.encode(keccak256("6529STREAM_RENDERER_READ_SET_V1"), targetsHash, declaredReads)
        );
        bytes32 registeredHash = keccak256(
            abi.encode(
                keccak256("6529STREAM_RENDERER_REGISTRATION_V1"),
                block.chainid,
                address(rendering.versions),
                address(assemblySchemas),
                address(assemblySchemas).codehash,
                targetsHash,
                registration,
                declaredReads
            )
        );
        require(
            keccak256(abi.encode(record.config)) == keccak256(abi.encode(input.config))
                && record.selection.registry == address(rendering.versions)
                && record.selection.registryCodeHash == address(rendering.versions).codehash
                && record.selection.renderer == address(rendering.renderer)
                && record.selection.rendererCodeHash == address(rendering.renderer).codehash
                && record.selection.versionKey == versionKey
                && record.selection.rendererId == keccak256("6529STREAM_RENDERER_V1")
                && record.selection.rendererVersion == keccak256("6529STREAM_STATIC_RENDERER_V1")
                && record.selection.contextVersion == keccak256("STREAM_CONTEXT_V1")
                && record.selection.schemaHash == keccak256(_schema())
                && record.selection.readSetHash == readsHash
                && record.selection.registrationHash == registeredHash,
            "original configured renderer and fixed identity"
        );
        bytes32 saved = record.recordHash;
        record.recordHash = 0;
        require(
            saved
                == keccak256(
                    abi.encode(
                        keccak256("6529STREAM_STATIC_METADATA_CONFIG_RECORD_V1"),
                        address(core),
                        address(router),
                        record
                    )
                ),
            "independent config record commitment"
        );
        record.recordHash = saved;
        StaticRouter.Authorization memory a = router.metadataConfigAuthorization(saved);
        require(
            a.actor == address(governor) && a.metadata == address(assemblyMetadata)
                && a.metadataCodeHash == address(assemblyMetadata).codehash && a.authorityClass == 8
                && a.grantCollectionId == 0 && a.grantRevision == 1,
            "actual governor writer grant receipt"
        );
    }

    function _configEvent(Vm.Log[] memory logs, StaticRouter.ConfigRecord memory record)
        internal
        view
    {
        _oneTokenEvent(
            logs,
            address(router),
            keccak256(
                "MetadataConfigRecorded(uint16,uint256,uint256,bytes32,(bytes32,bytes32,uint256,uint256,uint64,uint64,uint8,bytes32,(address,bytes32,bytes32,address,bytes32,bytes32,bytes32,bytes32,bytes32,bytes32,bytes32),(uint8,address,string,string,uint8,bool)))"
            ),
            bytes32(record.collectionId),
            bytes32(record.tokenId),
            record.recordHash,
            abi.encode(uint16(1), record)
        );
    }

    function _configConsent(uint256 token, StaticRouter.ConfigInput memory input)
        internal
        returns (bytes32 record)
    {
        // Preview is only a signing input. Independent stored/output/event checks supply the oracle.
        Content.Consent memory c = Content.Consent(
            2,
            address(router),
            keccak256("RENDERER_CONFIG"),
            router.previewStaticMetadataConfig(2, token, input)
        );
        IStreamArtistContentAuthority a = IStreamArtistContentAuthority(address(artists));
        _tokenSafe(
            tokenArtist,
            address(artists),
            0,
            abi.encodeCall(a.recordContentConsent, (c, _tokenArtistAuth(false)))
        );
        record = a.contentConsentEvidence(2, c.familyId, c.newStateHash);
        require(
            record != 0 && !router.consumedArtistContentConsent(record), "fresh actual Artist op17"
        );
    }

    function _has(string memory value, string memory literal) internal pure returns (bool) {
        bytes memory a = bytes(value);
        bytes memory b = bytes(literal);
        if (b.length > a.length) return false;
        for (uint256 i; i <= a.length - b.length; ++i) {
            bool same = true;
            for (uint256 j; j < b.length; ++j) {
                if (a[i + j] != b[j]) {
                    same = false;
                    break;
                }
            }
            if (same) return true;
        }
        return false;
    }

    function _literalContext(bytes32 seed, bytes32 config, bool finalized)
        internal
        view
        returns (string memory)
    {
        bytes memory out = abi.encodePacked(
            '{"schema":"stream-render-context-v1","chainId":"',
            block.chainid.toString(),
            '","contract":"',
            uint256(uint160(address(core))).toHexString(20),
            '","tokenId":"1","collectionId":"2","collectionSerial":"1","collectionSupplyMode":"FIXED","collectionStatus":"ACTIVE"'
        );
        if (finalized) {
            out = bytes.concat(
                out,
                abi.encodePacked(
                    ',"hash":"',
                    uint256(seed).toHexString(32),
                    '","seed":"',
                    uint256(seed).toHexString(32),
                    '"'
                )
            );
        }
        return string(
            bytes.concat(
                out,
                abi.encodePacked(
                    ',"entropyStatus":"',
                    finalized ? "FINALIZED" : "REGISTERED",
                    '","entropyProvider":"',
                    uint256(uint160(address(provider))).toHexString(20),
                    '","viewId":"MARKETPLACE","metadataSnapshotHash":"',
                    uint256(config).toHexString(32),
                    '","rendererId":"',
                    uint256(keccak256("6529STREAM_RENDERER_V1")).toHexString(32),
                    '","rendererVersion":"',
                    uint256(keccak256("6529STREAM_STATIC_RENDERER_V1")).toHexString(32),
                    '","renderContextVersion":"STREAM_CONTEXT_V1","scriptHash":"',
                    uint256(keccak256(bytes(PROGRAM))).toHexString(32),
                    '","tokenData":"0x00ff6529","dependencyScript":""}'
                )
            )
        );
    }

    function _literalHTML(bytes32 seed, bytes32 config) internal view returns (string memory) {
        return string.concat(
            "<html><head></head><body><script>window.__STREAM_TOKEN__=",
            _literalContext(seed, config, true),
            ";const stream=window.__STREAM_TOKEN__;const hash=stream.hash;const tokenId=Number(stream.tokenId);const tokenData=stream.tokenData;</script><script></script><script>",
            PROGRAM,
            "</script></body></html>"
        );
    }

    function _assertOutput(bytes32 seed, bytes32 config, string memory state) internal view {
        string memory html = _literalHTML(seed, config);
        require(
            keccak256(bytes(router.tokenHTML(1))) == keccak256(bytes(html)),
            "independent complete literal HTML"
        );
        string memory json = router.tokenJSON(1);
        require(
            _has(
                json,
                string.concat(
                    '{"name":"STATIC Study #1","description":"Exact current token","image":"ipfs://static-image","animation_url":"data:text/html;base64,',
                    Base64.encode(bytes(html)),
                    '","metadata_state":"',
                    state,
                    '"'
                )
            ),
            "independent output header and full animation bytes"
        );
        require(
            _has(json, _literalContext(seed, config, true))
                && _has(json, '"token_data_base64":"AP9lKQ=="')
                && _has(json, '"render_mode":"full"') && _has(json, '"state":"artist_accepted"')
                && _has(json, '"artist_display_name":"STATIC Artist"')
                && !_has(json, '"state":"attribution_unavailable"'),
            "literal data and actual Artist disclosure"
        );
        require(
            _has(
                json,
                string.concat(
                    '"artist_address":"',
                    uint256(uint160(address(tokenArtist))).toHexString(20),
                    '"'
                )
            ),
            "actual Safe Artist identity"
        );
    }

    function _constructOriginalRenderer() internal {
        configuration.core = address(core);
        configuration.executor = address(executor);
        configuration.router = address(router);
        configuration.metadata = address(assemblyMetadata);
        configuration.schemas = address(assemblySchemas);
        configuration.entropy = address(entropy);
        configuration.artist = address(artists);
        configuration.finality = address(assemblyFinality);
        configuration.deploymentHash = DEPLOYMENT_HASH;
        configuration.registryManifestURI = "urn:fixture:original-renderer-registry";
        configuration.registryManifestHash = keccak256("fixture renderer registry manifest");
        configuration.rendererManifest = Render.RendererManifest(
            keccak256("6529STREAM_RENDERER_V1"),
            keccak256("6529STREAM_STATIC_RENDERER_V1"),
            keccak256("STREAM_CONTEXT_V1"),
            keccak256("STATIC"),
            keccak256(_schema()),
            "urn:fixture:renderer-output-schema",
            "urn:fixture:renderer-manifest",
            keccak256(_manifestDocument()),
            16777216,
            16777216,
            false
        );
        configuration.readGas = IStreamGasParameterHost.GasParameterConfig(
            "METADATA_DEPENDENCY_READ_GAS", 2000000, 100000, 2
        );
        configuration.attributionGas = IStreamGasParameterHost.GasParameterConfig(
            "STATIC_ATTRIBUTION_GAS", 8000000, 8000000, 1
        );
        configuration.goldenGas = IStreamGasParameterHost.GasParameterConfig(
            "RENDERER_GOLDEN_VECTOR_GAS", 20000000, 100000, 2
        );
        rendering = StreamFullV1StaticRendererPlan.deployRenderer(configuration);
        rendering =
            StreamFullV1StaticRendererPlan.deployRegistry(configuration, rendering, _targets());
        versionKey = keccak256(
            abi.encode(
                keccak256("6529STREAM_RENDERER_VERSION_V1"),
                configuration.rendererManifest.rendererId,
                configuration.rendererManifest.rendererVersion
            )
        );
        _directReads();
    }

    /// @dev Partial direct fixture inventory, deliberately not a transitive analysis report.
    function _targets() internal view returns (Versions.Target[] memory targets) {
        (address encoding,) = rendering.renderer.encodingBinding();
        targets = new Versions.Target[](6);
        targets[0] = Versions.Target(address(core), address(core).codehash, keccak256("CORE"));
        targets[1] = Versions.Target(
            address(assemblyMetadata),
            address(assemblyMetadata).codehash,
            keccak256("COLLECTION_METADATA")
        );
        targets[2] = Versions.Target(
            address(router), address(router).codehash, keccak256("METADATA_COMPANION")
        );
        targets[3] = Versions.Target(
            address(entropy), address(entropy).codehash, keccak256("ENTROPY_COORDINATOR")
        );
        targets[4] = Versions.Target(
            address(rendering.attribution),
            address(rendering.attribution).codehash,
            keccak256("METADATA_COMPANION")
        );
        targets[5] = Versions.Target(encoding, encoding.codehash, keccak256("METADATA_COMPANION"));
        for (uint256 i = 1; i < targets.length; ++i) {
            for (uint256 j = i; j > 0 && targets[j - 1].target > targets[j].target; --j) {
                (targets[j - 1], targets[j]) = (targets[j], targets[j - 1]);
            }
        }
    }

    function _directReads() internal {
        Versions.Target[] memory targets = _targets();
        for (uint16 i; i < targets.length; ++i) {
            address target = targets[i].target;
            if (target == address(core)) {
                declaredReads.push(
                    Versions.Read(i, IStreamCoreMint.tokenData.selector, 16448, false)
                );
            } else if (target == address(assemblyMetadata)) {
                declaredReads.push(Versions.Read(i, StaticSource.staticBundle.selector, 384, true));
                declaredReads.push(
                    Versions.Read(i, StaticSource.staticBundleChunk.selector, 128, true)
                );
                declaredReads.push(
                    Versions.Read(i, StaticSource.staticScriptManifest.selector, 9504, false)
                );
            } else if (target == address(router)) {
                declaredReads.push(
                    Versions.Read(
                        i, StaticRouter.staticRenderSourceForConfig.selector, 20736, false
                    )
                );
            } else if (target == address(entropy)) {
                declaredReads.push(
                    Versions.Read(
                        i, IStreamStaticEntropySource.staticTokenRenderFacts.selector, 96, true
                    )
                );
            } else if (target == address(rendering.attribution)) {
                declaredReads.push(
                    Versions.Read(i, rendering.attribution.attribution.selector, 32832, false)
                );
            } else {
                declaredReads.push(
                    Versions.Read(i, StreamStaticRenderEncoding.render.selector, 16777216, false)
                );
            }
        }
        for (uint256 i = 1; i < declaredReads.length; ++i) {
            for (
                uint256 j = i;
                j > 0 && _readOrder(declaredReads[j - 1]) > _readOrder(declaredReads[j]);
                --j
            ) {
                Versions.Read memory previous = declaredReads[j - 1];
                declaredReads[j - 1] = declaredReads[j];
                declaredReads[j] = previous;
            }
        }
    }

    function _readOrder(Versions.Read memory read) internal pure returns (uint256) {
        return (uint256(read.targetIndex) << 32) | uint32(read.selector);
    }

    function _fixtureDocuments() internal {
        if (!assemblySchemas.document(assemblySchemas.RAW_BYTES()).exists) {
            _document(
                "RAW_BYTES",
                Schema.DocumentKind.CANONICALIZATION,
                bytes(assemblySchemas.RAW_BYTES_DEFINITION())
            );
        }
        registration.renderer = address(rendering.renderer);
        registration.manifest = configuration.rendererManifest;
        registration.schemaDocument =
            _document("GENESIS_RENDERER_SCHEMA_FIXTURE_V1", Schema.DocumentKind.SCHEMA, _schema());
        registration.contextDocument = _document(
            "STREAM_CONTEXT_V1",
            Schema.DocumentKind.SCHEMA,
            bytes("{\"fixture\":true,\"name\":\"STREAM_CONTEXT_V1\"}")
        );
        registration.manifestDocument = _document(
            "GENESIS_RENDERER_MANIFEST_FIXTURE_V1", Schema.DocumentKind.CATALOG, _manifestDocument()
        );
        Versions.Analysis memory analysis = Versions.Analysis(
            rendering.versions.ANALYSIS_PROFILE(),
            address(rendering.renderer),
            address(rendering.renderer).codehash,
            keccak256(
                abi.encode(
                    keccak256("6529STREAM_RENDERER_READ_SET_V1"),
                    rendering.versions.targetSetHash(),
                    declaredReads
                )
            ),
            registration.manifest.rendererVersion,
            registration.manifest.contextVersion,
            registration.manifest.schemaHash,
            keccak256("SYNTHETIC FIXTURE: no analysis tool executed"),
            keccak256("SYNTHETIC FIXTURE: partial direct reads, not a conformance report"),
            true
        );
        registration.analysisDocument = _document(
            "GENESIS_ANALYSIS_JOIN_FIXTURE_V1", Schema.DocumentKind.CATALOG, abi.encode(analysis)
        );
        Versions.GoldenVector[] memory vectors = new Versions.GoldenVector[](1);
        vectors[0].request.core = address(core);
        vectors[0].request.mode = Render.MetadataMode.ONCHAIN;
        vectors[0].outputHash = keccak256(bytes(rendering.renderer.tokenURI(vectors[0].request)));
        registration.goldenDocument = _document(
            "GENESIS_EMPTY_GOLDEN_FIXTURE_V1", Schema.DocumentKind.CATALOG, abi.encode(vectors)
        );
    }

    function _schema() internal pure returns (bytes memory) {
        return bytes(
            "{\"fixture\":true,\"type\":\"object\",\"purpose\":\"current renderer admission join\"}"
        );
    }

    function _manifestDocument() internal pure returns (bytes memory) {
        return bytes(
            "{\"fixture\":true,\"renderer\":\"6529STREAM_STATIC_RENDERER_V1\",\"reviewed\":false}"
        );
    }

    function _document(string memory name, Schema.DocumentKind kind, bytes memory payload)
        internal
        returns (bytes32 id)
    {
        (bytes32 hash,) = assemblyStore.publishChunk(payload);
        bytes32[] memory chunks = new bytes32[](1);
        chunks[0] = hash;
        Schema.DocumentSpec memory spec = Schema.DocumentSpec(
            name, kind, hash, assemblySchemas.RAW_BYTES(), 0, "", uint32(payload.length)
        );
        (bytes32 scope, bytes32 previous, bytes32 next) =
            assemblySchemas.registrationTransition(spec, chunks);
        bytes memory data = abi.encodeCall(assemblySchemas.registerDocument, (spec, chunks));
        _executeStage(
            _single(
                StreamCurrentStackPlan.call(address(assemblySchemas), data, scope, previous, next),
                data
            ),
            keccak256(bytes(name))
        );
        id = keccak256(bytes(name));
        require(
            keccak256(assemblySchemas.documentBytes(id)) == hash, "exact original document bytes"
        );
    }

    function _admit(Versions.Registration memory item) internal {
        (GovernanceCall memory operation, bytes memory data) =
            StreamFullV1StaticRendererPlan.admission(configuration, rendering, item, declaredReads);
        _executeStage(
            _single(operation, data),
            keccak256(abi.encode("fixture original renderer admission", item.goldenDocument))
        );
    }

    function _grantWriter() internal {
        bytes32 family = keccak256("6529STREAM_RECORD_FAMILY_IDENTITY_DISPLAY_V1");
        (bytes32 scope, bytes32 previous, bytes32 next) =
            assemblyMetadata.familyWriterTransition(0, family, 8, address(governor), true);
        bytes memory data = abi.encodeCall(
            assemblyMetadata.setFamilyWriter,
            (uint256(0), family, uint8(8), address(governor), true)
        );
        _executeStage(
            _single(
                StreamCurrentStackPlan.call(address(assemblyMetadata), data, scope, previous, next),
                data
            ),
            keccak256("explicit Safe static default writer")
        );
    }

    function _input() internal view returns (StaticRouter.ConfigInput memory) {
        return StaticRouter.ConfigInput(
            address(rendering.versions),
            versionKey,
            Render.MetadataConfig(
                Render.MetadataMode.ONCHAIN,
                address(rendering.renderer),
                "",
                "",
                Render.OffchainURIIdMode.TOKEN_ID,
                false
            )
        );
    }

    function _extendCatalog() internal {
        GovernanceActionPolicyEntry[] memory rows =
            StreamFullV1StaticRendererPlan.operatingPolicies(configuration, rendering);
        for (uint256 i = 1; i < rows.length; ++i) {
            for (uint256 j = i; j > 0 && _key(rows[j - 1]) > _key(rows[j]); --j) {
                (rows[j - 1], rows[j]) = (rows[j], rows[j - 1]);
            }
        }
        StreamGovernanceCatalogStagePlan.Inventory memory inventory =
            StreamGovernanceCatalogStagePlan.inventory(executor, rows);
        (address payload, StreamSystemManifestUpdate memory update) =
            _publication("renderer policies");
        (GenesisBatch memory batch, uint256 count) = StreamGovernanceCatalogStagePlan.nextBatch(
            inventory,
            StreamGovernanceCatalogStagePlan.inventoryHash(inventory),
            0,
            manifest,
            payload,
            update
        );
        _executeStage(batch, keccak256("original renderer catalog"));
        require(count == rows.length, "complete bounded policy addition");
    }

    function _registerModules() internal {
        (GovernanceCall[] memory calls, bytes[] memory datas) = StreamCurrentStackPlan.registrationCalls(
            registry, StreamFullV1StaticRendererPlan.registrations(configuration, rendering, 500000)
        );
        GenesisBatch memory batch;
        batch.actionClass = 1;
        batch.calls = new GovernanceCall[](calls.length + 1);
        batch.callDatas = new bytes[](calls.length + 1);
        for (uint256 i; i < calls.length; ++i) {
            batch.calls[i] = calls[i];
            batch.callDatas[i] = datas[i];
        }
        (address payload, StreamSystemManifestUpdate memory update) =
            _publication("original renderer hosts");
        (batch.calls[calls.length], batch.callDatas[calls.length]) =
            StreamGenesisManifestPlan.publicationCall(
                manifest, payload, update, StreamGenesisManifestPlan.readAggregate(manifest).modules
            );
        _executeStage(batch, keccak256("original renderer module rows"));
    }

    function _publication(string memory purpose)
        internal
        returns (address payload, StreamSystemManifestUpdate memory update)
    {
        StreamSystemManifest.AggregateState memory current =
            StreamGenesisManifestPlan.readAggregate(manifest);
        bytes32 hash;
        (payload, hash) = StreamGenesisManifestPlan.writePayload(
            bytes(string.concat("{\"fixture\":true,\"purpose\":\"", purpose, "\"}"))
        );
        update = StreamSystemManifestUpdate(
            hash,
            "urn:fixture:static-genesis",
            current.discovery.eventCatalogHash,
            current.discovery.compatibilityMatrixHash,
            current.discovery.numericIdCatalogHash,
            current.discovery.schemaCatalogHash,
            current.discovery.canonicalizationCatalogHash,
            current.discovery.specBundleHash,
            current.discovery.reconstructionClientHash
        );
    }

    function _single(GovernanceCall memory operation, bytes memory data)
        internal
        pure
        returns (GenesisBatch memory batch)
    {
        batch.actionClass = 1;
        batch.calls = new GovernanceCall[](1);
        batch.callDatas = new bytes[](1);
        batch.calls[0] = operation;
        batch.callDatas[0] = data;
    }

    function _policy(address target, bytes4 selector)
        internal
        view
        returns (GovernanceActionPolicyEntry memory)
    {
        return GovernanceActionPolicyEntry(
            1, target, selector, target.codehash, DEPLOYMENT_HASH, 1, 0, 0, bytes32(0)
        );
    }

    function _key(GovernanceActionPolicyEntry memory row) internal pure returns (bytes32) {
        return keccak256(abi.encode(row.actionClass, row.target, row.selector));
    }

    function _expectSafeFailure(OfficialSafe account, address target, bytes memory data) internal {
        uint256 nonce = account.nonce();
        vm.expectRevert();
        this.safeCall(account, target, data);
        require(account.nonce() == nonce, "Safe nonce rolls back");
    }

    function safeCall(OfficialSafe account, address target, bytes memory data)
        external
        returns (bool)
    {
        return executeSafe(account, keys, target, 0, data, 0);
    }

    function admit(Versions.Registration memory item) external {
        _admit(item);
    }

    function validate(StreamFullV1StaticRendererPlan.Products memory products) external view {
        StreamFullV1StaticRendererPlan.validate(configuration, products);
    }

    function deployRegistry(
        StreamFullV1StaticRendererPlan.Products memory products,
        Versions.Target[] memory targets
    ) external {
        StreamFullV1StaticRendererPlan.deployRegistry(configuration, products, targets);
    }

    function _installGovernor() internal {
        (address prior, bytes32 hash, uint64 revision) = executor.governanceRootState();
        bytes memory data = abi.encodeCall(
            executor.rotateGovernanceRoot, (address(governor), address(governor).codehash)
        );
        uint64 ready = uint64(block.timestamp + executor.minimumDelay(3));
        GovernanceActionRequest memory request = GovernanceActionRequest(
            3,
            address(executor),
            0,
            executor.rotateGovernanceRoot.selector,
            data,
            keccak256(
                abi.encode(
                    keccak256("6529STREAM_GOVERNANCE_ROOT_SCOPE_V1"),
                    block.chainid,
                    address(executor)
                )
            ),
            _rootState(prior, hash, revision),
            _rootState(address(governor), address(governor).codehash, revision + 1),
            ready,
            ready + 7 days,
            keccak256("full-v1 actual Safe root"),
            "urn:6529stream:genesis:Safe-root",
            DEPLOYMENT_HASH
        );
        bytes memory result = governanceRoot.execute(
            address(executor), 0, abi.encodeCall(executor.scheduleGovernanceAction, (request))
        );
        vm.warp(ready);
        executor.executeGovernanceAction(abi.decode(result, (bytes32)), data);
    }

    function _rootState(address root, bytes32 hash, uint64 revision)
        internal
        view
        returns (bytes32)
    {
        return keccak256(
            abi.encode(
                keccak256("6529STREAM_GOVERNANCE_ROOT_STATE_V1"),
                block.chainid,
                address(executor),
                root,
                hash,
                revision
            )
        );
    }

    function _executeStage(GenesisBatch memory batch, bytes32 stage) internal {
        uint64 ready = uint64(block.timestamp + executor.minimumDelay(batch.actionClass));
        StreamGovernanceStagePlan.Plan memory plan = StreamGovernanceStagePlan.build(
            executor,
            stage,
            batch,
            ready,
            ready + 7 days,
            stage,
            "urn:6529stream:genesis:composed-stage",
            DEPLOYMENT_HASH
        );
        bytes32 saved = StreamGovernanceStagePlan.planHash(plan);
        executor.publishGovernanceCallData(batch.callDatas);
        StreamGovernanceStagePlan.NextCall memory next =
            StreamGovernanceStagePlan.scheduling(plan, saved);
        vm.recordLogs();
        require(
            executeSafe(governor, keys, next.target, next.value, next.data, 0),
            "real Safe schedules"
        );
        Vm.Log[] memory logs = vm.getRecordedLogs();
        bytes32 topic = keccak256(
            "GovernanceActionScheduled(uint16,bytes32,uint8,address,uint256,bytes4,bytes32,bytes32,bytes32,bytes32,uint64,uint64,uint256,address,bytes32,string,bytes32)"
        );
        bytes32 action;
        for (uint256 i; i < logs.length; ++i) {
            if (
                logs[i].emitter == address(executor) && logs[i].topics.length == 4
                    && logs[i].topics[0] == topic
            ) {
                require(action == 0, "one observed action");
                action = logs[i].topics[1];
            }
        }
        require(action != 0, "actual receipt action ID");
        if (ready > block.timestamp) {
            (bool early,) =
                address(this).call(abi.encodeCall(this.executeSaved, (plan, action, saved)));
            require(!early, "execution before delay rejected");
            vm.warp(ready);
        }
        require(
            StreamGovernanceStagePlan.execute(plan, action, saved),
            "permissionless delayed execution"
        );
    }

    function executeSaved(StreamGovernanceStagePlan.Plan memory plan, bytes32 action, bytes32 saved)
        external
        returns (bool)
    {
        return StreamGovernanceStagePlan.execute(plan, action, saved);
    }
}
