// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../helpers/StreamCurrentTestProductActivation.sol";
import {
    StreamArtistOnboardingRegistry
} from "../../smart-contracts/domains/artist/StreamArtistOnboardingRegistry.sol";
import "../../script/current/StreamCurrentStackPlan.sol";
import "../../script/current/StreamGenesisManifestPlan.sol";
import {
    EntropyProviderState
} from "../../smart-contracts/interfaces/stream/entropy/IStreamEntropyProviderLifecycle.sol";

interface ProductActivationTestVm {
    function snapshotState() external returns (uint256);
    function revertToState(uint256 id) external returns (bool);
    function getNonce(address account) external view returns (uint64);
    function warp(uint256 timestamp) external;
}

/// @dev Explicit boundary doubles; these are not current production contracts.
contract ProductActivationReadDouble {
    address public immutable expectedHost;
    uint256 public immutable tag;
    bool public failPointer;
    bool public mismatchCount;
    bytes32 public published;

    constructor(address host, uint256 tag_) {
        expectedHost = host;
        tag = tag_;
    }

    function setFailures(bool pointer, bool count) external {
        failPointer = pointer;
        mismatchCount = count;
    }

    function registrationChainHash() external view returns (bytes32, uint64) {
        require(msg.sender == expectedHost, "registration caller");
        return (keccak256("retained registry chain"), 3);
    }

    function moduleCount() external view returns (uint256) {
        require(msg.sender == expectedHost, "count caller");
        return mismatchCount ? 4 : 3;
    }

    function entropyProviderTransition(
        address provider,
        EntropyProviderState next,
        string calldata reason
    ) external view returns (bytes32, bytes32, bytes32, uint8) {
        require(msg.sender == expectedHost, "entropy caller");
        bytes32 scope = keccak256(abi.encode(tag, provider, next, reason));
        return (scope, keccak256(abi.encode(scope, false)), keccak256(abi.encode(scope, true)), 1);
    }

    function creditProducerTransitionHashes(address producer, bool enabled)
        external
        view
        returns (bytes32, bytes32, bytes32)
    {
        require(msg.sender == expectedHost, "escrow caller");
        bytes32 scope = keccak256(abi.encode(tag, producer));
        return
            (scope, keccak256(abi.encode(scope, !enabled)), keccak256(abi.encode(scope, enabled)));
    }

    function streamSystemManifestPointer() external view returns (address) {
        require(msg.sender == expectedHost, "manifest pointer caller");
        return address(0x1234);
    }

    function publishStreamSystemManifest(
        address pointer,
        StreamSystemManifestUpdate calldata update
    ) external {
        published = keccak256(abi.encode(msg.sender, pointer, update));
    }

    fallback() external {
        require(msg.sender == expectedHost, "read caller");
        if (msg.sig == bytes4(keccak256("getSatellitePointer(bytes32)"))) {
            require(!failPointer, "pointer read rejected");
            bytes memory result = new bytes(320);
            assembly ("memory-safe") { return(add(result, 32), mload(result)) }
        }
        require(msg.sig == bytes4(keccak256("streamSystemManifest()")), "unexpected read selector");
        StreamSystemManifest.AggregateState memory state;
        state.manifestHash = keccak256("retained manifest");
        state.manifestURI = "urn:retained:manifest";
        state.modules.collectionMetadata = address(0xCA11);
        state.discovery = StreamSystemManifest.DiscoveryHashes(
            bytes32(uint256(1)),
            bytes32(uint256(2)),
            bytes32(uint256(3)),
            bytes32(uint256(4)),
            bytes32(uint256(5)),
            bytes32(uint256(6)),
            bytes32(uint256(7))
        );
        state.revision = 4;
        bytes memory encoded = abi.encode(state);
        assembly ("memory-safe") { return(add(encoded, 64), sub(mload(encoded), 32)) }
    }
}

contract ProductActivationExecutorDouble {
    address public immutable expectedHost;
    address public expectedRoot;
    bytes32 public candidate = keccak256("candidate");
    bytes32 public catalog = keccak256("catalog");
    uint256 public count = 1;
    uint64 public revision = 7;
    bool public failRead;
    bool public failExecution;
    bool public corruptAppliedCount;
    uint256 public step;
    uint64 public ready;
    bytes32 public action;
    bytes32 public publicationHash;
    bytes32 public scheduleHash;
    bytes32 public executionHash;
    bytes32 public additionsHash;

    constructor(address host) {
        expectedHost = host;
    }

    function configure(
        address root,
        uint64 revision_,
        bool readFailure,
        bool executionFailure,
        bool badCount
    ) external {
        expectedRoot = root;
        revision = revision_;
        failRead = readFailure;
        failExecution = executionFailure;
        corruptAppliedCount = badCount;
    }

    function governanceActionPolicyState()
        external
        view
        returns (bytes32, bytes32, uint256, uint64)
    {
        require(msg.sender == expectedHost, "catalog caller");
        require(!failRead, "catalog read reached");
        return (candidate, catalog, count, revision);
    }

    function publishGovernanceCallData(bytes[] calldata data) external returns (address) {
        require(msg.sender == expectedHost && step == 0, "publish first from host");
        publicationHash = keccak256(abi.encode(msg.sender, data));
        step = 1;
        return address(0xC011);
    }

    function minimumDelay(uint8) external view returns (uint64) {
        require(msg.sender == expectedHost && step == 1, "delay after publish");
        return 3;
    }

    function scheduleGovernanceBatch(
        uint8,
        GovernanceCall[] calldata,
        bytes32,
        bytes32,
        bytes32,
        uint64 notBefore,
        uint64,
        bytes32,
        string calldata,
        bytes32
    ) external returns (bytes32) {
        require(msg.sender == expectedRoot && step == 1, "schedule root after publish");
        scheduleHash = keccak256(msg.data);
        ready = notBefore;
        action = keccak256(abi.encode(scheduleHash));
        step = 2;
        return action;
    }

    function executeGovernanceBatch(
        bytes32 id,
        GovernanceCall[] calldata calls,
        bytes[] calldata data
    ) external payable {
        require(
            msg.sender == expectedHost && step == 2 && block.timestamp == ready,
            "execute host after warp"
        );
        require(id == action && calls.length == data.length, "scheduled exact batch");
        executionHash = keccak256(abi.encode(msg.sender, id, calls, data));
        step = 3;
        for (uint256 i; i < calls.length; ++i) {
            require(keccak256(data[i]) == calls[i].callDataHash, "exact preimage");
            (bool ok, bytes memory result) = calls[i].target.call{ value: calls[i].value }(data[i]);
            if (!ok) assembly ("memory-safe") { revert(add(result, 32), mload(result)) }
        }
        require(!failExecution, "late execution rejected");
    }

    function extendGovernanceActionPolicy(
        uint64 oldRevision,
        bytes32 oldCatalog,
        bytes32 next,
        GovernanceActionPolicyEntry[] calldata additions
    ) external {
        require(
            msg.sender == address(this) && oldRevision == revision && oldCatalog == catalog,
            "exact extension self call"
        );
        additionsHash = keccak256(abi.encode(additions));
        catalog = next;
        count += additions.length + (corruptAppliedCount ? 1 : 0);
        ++revision;
    }

    function transcript() external view returns (bytes32) {
        return keccak256(
            abi.encode(
                candidate,
                catalog,
                count,
                revision,
                step,
                ready,
                action,
                publicationHash,
                scheduleHash,
                executionHash,
                additionsHash
            )
        );
    }
}

contract ProductActivationRootDouble {
    address public immutable expectedHost;
    bytes32 public transcript;

    constructor(address host) {
        expectedHost = host;
    }

    function execute(address target, uint256 value, bytes calldata data)
        external
        returns (bytes memory)
    {
        require(msg.sender == expectedHost, "root caller is host");
        transcript = keccak256(abi.encode(msg.sender, target, value, data));
        (bool ok, bytes memory result) = target.call{ value: value }(data);
        if (!ok) assembly ("memory-safe") { revert(add(result, 32), mload(result)) }
        return result;
    }
}

/// @dev Historical fixture bodies and current wrappers share one caller/storage identity.
/// This isolates the boundary; it does not model a full current production deployment.
contract ProductActivationBoundaryHarness {
    ProductActivationTestVm private constant vm =
        ProductActivationTestVm(address(uint160(uint256(keccak256("hevm cheat code")))));
    StreamGovernanceExecutor internal executor;
    StreamGovernanceActor internal governanceRoot;
    StreamCore internal core;
    StreamModuleRegistry internal registry;
    StreamSystemManifest internal manifest;
    StreamMintManager internal manager;
    StreamMintLedger internal ledger;
    StreamEntropyCoordinator internal entropy;
    address internal provider;
    StreamMetadataRouter internal router;
    StreamRoyaltyResolver internal royalties;
    StreamArtistOnboardingRegistry internal artists;
    address internal assemblyFinality;
    StreamRevenueResolver internal primaryResolver;
    StreamRevenueEscrow internal revenueEscrow;
    StreamFixedPriceSaleAdapter internal sale;
    StreamEnglishAuctionHouse internal auction;
    bytes32 internal profile;
    bytes32 internal DEPLOYMENT_HASH;
    bytes32 internal REGISTRY_HASH;
    bytes32 internal graphFinalityManifestHash;
    bytes32 internal PRIMARY_REVENUE_CLASS;

    GovernanceActionPolicyEntry[] private _foundationPolicies;
    GovernanceActionPolicyEntry[] private _hookPolicies;
    uint64 private _fixtureCatalogRevision;
    bool private _failHook;

    function configure(StreamCurrentTestProductActivation.Context memory c) external {
        executor = c.executor;
        governanceRoot = c.governanceRoot;
        core = c.core;
        registry = c.registry;
        manifest = c.manifest;
        manager = c.manager;
        ledger = c.ledger;
        entropy = c.entropy;
        provider = c.provider;
        router = c.router;
        royalties = c.royalties;
        artists = StreamArtistOnboardingRegistry(payable(address(c.artists)));
        assemblyFinality = c.finality;
        primaryResolver = c.primaryResolver;
        revenueEscrow = c.revenueEscrow;
        sale = c.sale;
        auction = c.auction;
        profile = c.profile;
        DEPLOYMENT_HASH = c.deploymentHash;
        REGISTRY_HASH = c.registryHash;
        graphFinalityManifestHash = c.finalityManifestHash;
        PRIMARY_REVENUE_CLASS = c.primaryRevenueClass;
    }

    function seedPolicies(
        GovernanceActionPolicyEntry[] memory retained,
        GovernanceActionPolicyEntry[] memory operating,
        uint64 revision,
        bool failHook
    ) external {
        delete _foundationPolicies;
        delete _hookPolicies;
        for (uint256 i; i < retained.length; ++i) {
            _foundationPolicies.push(retained[i]);
        }
        for (uint256 i; i < operating.length; ++i) {
            _hookPolicies.push(operating[i]);
        }
        _fixtureCatalogRevision = revision;
        _failHook = failHook;
    }

    function _operatingPolicies() private view returns (GovernanceActionPolicyEntry[] memory) {
        require(!_failHook, "operating hook first");
        return _hookPolicies;
    }

    function revision() external view returns (uint64) {
        return _fixtureCatalogRevision;
    }

    function policies() external view returns (GovernanceActionPolicyEntry[] memory) {
        return _foundationPolicies;
    }

    function originalAdmission(GenesisBatch[] memory batches) external {
        _originalAdmitInitialProductPolicies(batches);
    }

    function linkedAdmission(GenesisBatch[] memory batches) external {
        _admitInitialProductPolicies(batches);
    }

    function originalPublication(
        StreamSystemManifest.ModuleAddresses memory modules,
        bytes32 reason
    ) external returns (GovernanceCall memory, bytes memory) {
        return _initialPublication(modules, reason);
    }

    function linkedPublication(StreamSystemManifest.ModuleAddresses memory modules, bytes32 reason)
        external
        returns (GovernanceCall memory, bytes memory)
    {
        return
            StreamCurrentTestProductActivation.publication(
                _productActivationContext(), modules, reason
            );
    }

    function linkedRegistrations()
        external
        view
        returns (StreamModuleRegistration[] memory, GenesisBatch memory)
    {
        return StreamCurrentTestProductActivation.registrations(_productActivationContext());
    }

    function linkedConfiguration(
        StreamModuleRegistration[] memory records,
        address[] memory extraProducers
    ) external view returns (GenesisBatch memory, GenesisBatch memory) {
        return StreamCurrentTestProductActivation.pointersAndConfiguration(
            _productActivationContext(), records, extraProducers
        );
    }

    function originalRegistrations()
        external
        view
        returns (StreamModuleRegistration[] memory records, GenesisBatch memory registrationBatch)
    {
        StreamModuleRegistration[] memory allRecords = _moduleRecords();
        // Foundation, Router and Artist were already admitted and selected in the first phase.
        records = new StreamModuleRegistration[](allRecords.length - 4);
        uint256 nextRecord;
        for (uint256 i = 2; i < allRecords.length; ++i) {
            if (i == 5 || i == 7) continue;
            records[nextRecord++] = allRecords[i];
        }
        require(nextRecord == records.length, "complete remaining product registration");
        registrationBatch.actionClass = 1;
        (GovernanceCall[] memory registrations, bytes[] memory registrationData) =
            StreamCurrentStackPlan.registrationCalls(registry, records);
        registrationBatch.calls = new GovernanceCall[](records.length + 2);
        registrationBatch.callDatas = new bytes[](records.length + 2);
        for (uint256 i; i < records.length; ++i) {
            registrationBatch.calls[i] = registrations[i];
            registrationBatch.callDatas[i] = registrationData[i];
        }
        (registrationBatch.calls[records.length], registrationBatch.callDatas[records.length]) =
            StreamEntropyLifecyclePlan.activate(
                entropy, address(provider), "urn:stream:genesis:entropy-provider"
            );
        bytes memory data = abi.encodeCall(
            entropy.configureCollection,
            (1, address(provider), keccak256("collection salt"), true, uint64(100))
        );
        registrationBatch.callDatas[records.length + 1] = data;
        registrationBatch.calls[records.length + 1] = _configurationCall(address(entropy), data);
    }

    function originalConfiguration(
        StreamModuleRegistration[] memory records,
        address[] memory extraProducers
    )
        external
        view
        returns (GenesisBatch memory pointerBatch, GenesisBatch memory configurationBatch)
    {
        configurationBatch.actionClass = 1;
        bytes memory data;
        configurationBatch.calls = new GovernanceCall[](7 + extraProducers.length);
        configurationBatch.callDatas = new bytes[](7 + extraProducers.length);
        data = abi.encodeCall(
            router.setCollectionMetadata,
            (
                1,
                "Stream Genesis",
                "Current stack integration",
                "ipfs://image",
                "https://example.invalid/art/"
            )
        );
        configurationBatch.callDatas[0] = data;
        configurationBatch.calls[0] = _configurationCall(address(router), data);
        data =
            abi.encodeCall(router.setCollectionScript, (1, "document.body.textContent=tokenHash;"));
        configurationBatch.callDatas[1] = data;
        configurationBatch.calls[1] = _configurationCall(address(router), data);
        data = abi.encodeCall(royalties.configureCollectionRoyalty, (1, profile, uint16(690)));
        configurationBatch.callDatas[2] = data;
        configurationBatch.calls[2] = _configurationCall(address(royalties), data);
        data = abi.encodeCall(
            primaryResolver.setPrimaryProfileAssignment,
            (PRIMARY_REVENUE_CLASS, uint8(1), 1, profile, bytes32(0))
        );
        configurationBatch.callDatas[3] = data;
        configurationBatch.calls[3] = _configurationCall(address(primaryResolver), data);
        (configurationBatch.calls[4], configurationBatch.callDatas[4]) =
            _escrowProducerCall(address(sale));
        (configurationBatch.calls[5], configurationBatch.callDatas[5]) =
            _escrowProducerCall(address(auction));
        for (uint256 i; i < extraProducers.length; ++i) {
            (configurationBatch.calls[6 + i], configurationBatch.callDatas[6 + i]) =
                _escrowProducerCall(extraProducers[i]);
        }

        data = abi.encodeCall(router.initializeOriginalFinalityAnchor, ());
        configurationBatch.callDatas[6 + extraProducers.length] = data;
        configurationBatch.calls[6 + extraProducers.length] =
            _configurationCall(address(router), data);

        bytes32[] memory installTypes = new bytes32[](records.length);
        for (uint256 i; i < records.length; ++i) {
            installTypes[i] = _pointerType(records[i].moduleType);
        }
        pointerBatch.actionClass = 3;
        (pointerBatch.calls, pointerBatch.callDatas) =
            StreamCurrentStackPlan.pointerCalls(core, registry, installTypes, records);
    }

    function _escrowProducerCall(address producer)
        private
        view
        returns (GovernanceCall memory call_, bytes memory data)
    {
        (bytes32 scope, bytes32 oldState, bytes32 nextState) =
            revenueEscrow.creditProducerTransitionHashes(producer, true);
        data = abi.encodeCall(revenueEscrow.setCreditProducer, (producer, true));
        call_ =
            StreamCurrentStackPlan.call(address(revenueEscrow), data, scope, oldState, nextState);
    }

    function _moduleRecords() private view returns (StreamModuleRegistration[] memory records) {
        records = new StreamModuleRegistration[](10);
        records[0] = _record(
            address(registry),
            keccak256("MODULE_REGISTRY"),
            type(IStreamModuleRegistry).interfaceId,
            REGISTRY_HASH
        );
        records[1] = _record(
            address(manifest),
            0x47fd79d5a6e9b1d75dcedf141a46e2e8f6d95d5a5be2b88f197fa98a1436fec6,
            type(IStreamSystemManifest).interfaceId,
            keccak256("fixture system manifest")
        );
        records[2] = _record(
            address(manager),
            keccak256("MINT_MANAGER"),
            type(IStreamMintManager).interfaceId,
            keccak256("fixture mint manager")
        );
        records[3] = _record(
            address(ledger),
            keccak256("MINT_LEDGER"),
            type(IStreamMintLedger).interfaceId,
            keccak256("fixture mint ledger")
        );
        records[4] = _record(
            address(entropy),
            keccak256("ENTROPY_COORDINATOR"),
            type(IStreamEntropyCoordinator).interfaceId,
            keccak256("fixture entropy module")
        );
        records[5] = _record(
            address(router),
            keccak256("METADATA_ROUTER"),
            type(IStreamMetadataRouter).interfaceId,
            keccak256("fixture metadata module")
        );
        records[6] = _record(
            address(royalties),
            keccak256("REVENUE_RESOLVER"),
            type(IStreamRoyaltyResolver).interfaceId,
            keccak256("fixture royalty module")
        );
        records[7] = _record(
            address(artists),
            keccak256("ARTIST_REGISTRY"),
            type(IStreamArtistMintConsent).interfaceId,
            keccak256("fixture artist module")
        );
        records[8] = _record(
            address(executor),
            keccak256("GOVERNANCE_LAYER"),
            type(IStreamStateExportPublisher).interfaceId,
            keccak256("fixture state export publisher")
        );
        records[9] = _record(
            address(assemblyFinality),
            keccak256("ARTWORK_FINALITY_REGISTRY"),
            type(IStreamArtworkFinalityRegistry).interfaceId,
            graphFinalityManifestHash
        );
    }

    function _pointerType(bytes32 moduleType) private pure returns (bytes32) {
        if (moduleType == 0x47fd79d5a6e9b1d75dcedf141a46e2e8f6d95d5a5be2b88f197fa98a1436fec6) {
            return keccak256("SYSTEM_MANIFEST");
        }
        if (moduleType == keccak256("REVENUE_RESOLVER")) return keccak256("ROYALTY_RESOLVER");
        if (moduleType == keccak256("GOVERNANCE_LAYER")) {
            return keccak256("STATE_EXPORT_PUBLISHER");
        }
        return moduleType;
    }

    function _record(address module, bytes32 moduleType, bytes4 interfaceId, bytes32 moduleHash)
        private
        view
        returns (StreamModuleRegistration memory)
    {
        return StreamModuleRegistration(
            module,
            moduleType,
            keccak256("fixture v1"),
            interfaceId,
            500_000,
            module.codehash,
            DEPLOYMENT_HASH,
            moduleHash,
            "urn:6529stream:fixture:module"
        );
    }

    function _configurationCall(address target, bytes memory data)
        private
        pure
        returns (GovernanceCall memory)
    {
        return StreamCurrentStackPlan.call(
            target, data, keccak256(abi.encode(target, data)), bytes32(0), keccak256(data)
        );
    }

    function _originalAdmitInitialProductPolicies(GenesisBatch[] memory batches) private {
        GovernanceActionPolicyEntry[] memory candidates = _actionPolicies(batches);
        uint256 count;
        for (uint256 i; i < candidates.length; ++i) {
            bool exists;
            for (uint256 j; j < _foundationPolicies.length; ++j) {
                if (_policyKey(candidates[i]) != _policyKey(_foundationPolicies[j])) continue;
                require(
                    keccak256(abi.encode(candidates[i]))
                        == keccak256(abi.encode(_foundationPolicies[j])),
                    "foundation policy cannot be rewritten"
                );
                exists = true;
                break;
            }
            if (!exists) candidates[count++] = candidates[i];
        }
        GovernanceActionPolicyEntry[] memory additions = new GovernanceActionPolicyEntry[](count);
        for (uint256 i; i < count; ++i) {
            additions[i] = candidates[i];
        }
        (bytes32 candidate, bytes32 catalog, uint256 existingCount, uint64 revision) =
            executor.governanceActionPolicyState();
        require(
            revision == _fixtureCatalogRevision && existingCount == _foundationPolicies.length,
            "exact original foundation catalog"
        );
        if (count == 0) return;
        (bytes32 next, bytes32 scope, bytes32 oldHash, bytes32 newHash) = StreamGovernanceActionPolicy.extensionTransition(
            address(executor), candidate, catalog, existingCount, revision, additions
        );
        GenesisBatch memory batch;
        batch.actionClass = 3;
        batch.calls = new GovernanceCall[](2);
        batch.callDatas = new bytes[](2);
        batch.callDatas[0] = abi.encodeCall(
            executor.extendGovernanceActionPolicy, (revision, catalog, next, additions)
        );
        batch.calls[0] = StreamCurrentStackPlan.call(
            address(executor), batch.callDatas[0], scope, oldHash, newHash
        );
        (batch.calls[1], batch.callDatas[1]) =
            _initialPublication(StreamGenesisManifestPlan.readAggregate(manifest).modules, next);
        _executeInitialBatch(batch);
        (, bytes32 appliedCatalog, uint256 appliedCount, uint64 appliedRevision) =
            executor.governanceActionPolicyState();
        require(
            appliedCatalog == next && appliedRevision == revision + 1
                && appliedCount == existingCount + count,
            "exact applied catalog extension"
        );
        _fixtureCatalogRevision = appliedRevision;
        for (uint256 i; i < count; ++i) {
            _foundationPolicies.push(additions[i]);
        }
    }

    function _initialProductModules()
        private
        view
        returns (StreamSystemManifest.ModuleAddresses memory modules)
    {
        modules = StreamGenesisManifestPlan.readAggregate(manifest).modules;
        modules.artistRegistry = address(artists);
        modules.artworkFinalityRegistry = address(assemblyFinality);
        modules.revenueResolver = address(royalties);
        modules.metadataRouter = address(router);
        modules.entropyCoordinator = address(entropy);
        modules.mintManager = address(manager);
        modules.mintLedger = address(ledger);
        modules.streamAdminsOrGovernance = address(executor);
        modules.moduleRegistry = address(registry);
        modules.stateExportPublisher = address(executor);
    }

    function _initialPublication(
        StreamSystemManifest.ModuleAddresses memory modules,
        bytes32 reason
    ) private returns (GovernanceCall memory call_, bytes memory data) {
        StreamSystemManifest.AggregateState memory current =
            StreamGenesisManifestPlan.readAggregate(manifest);
        (address payload, bytes32 hash) = StreamGenesisManifestPlan.writePayload(
            abi.encodePacked(
                "{\"purpose\":\"current product activation\",\"commitment\":\"",
                Strings.toHexString(uint256(reason), 32),
                "\"}"
            )
        );
        StreamSystemManifestUpdate memory update = StreamSystemManifestUpdate(
            hash,
            "urn:6529stream:current-stack:products",
            current.discovery.eventCatalogHash,
            current.discovery.compatibilityMatrixHash,
            current.discovery.numericIdCatalogHash,
            current.discovery.schemaCatalogHash,
            current.discovery.canonicalizationCatalogHash,
            current.discovery.specBundleHash,
            current.discovery.reconstructionClientHash
        );
        return StreamGenesisManifestPlan.publicationCall(manifest, payload, update, modules);
    }

    function _executeInitialBatch(GenesisBatch memory batch) private {
        executor.publishGovernanceCallData(batch.callDatas);
        (bytes32 scope, bytes32 oldHash, bytes32 newHash) = StreamGovernanceBootstrap.deriveBatchTransitionHashes(
            batch.calls, StreamGovernanceBootstrap.governanceCallsHash(batch.calls)
        );
        uint64 ready = uint64(block.timestamp + executor.minimumDelay(batch.actionClass));
        bytes memory result = governanceRoot.execute(
            address(executor),
            0,
            abi.encodeCall(
                executor.scheduleGovernanceBatch,
                (
                    batch.actionClass,
                    batch.calls,
                    scope,
                    oldHash,
                    newHash,
                    ready,
                    ready + 7 days,
                    keccak256("initial product activation"),
                    "urn:6529stream:fixture:product-activation",
                    DEPLOYMENT_HASH
                )
            )
        );
        vm.warp(ready);
        executor.executeGovernanceBatch(abi.decode(result, (bytes32)), batch.calls, batch.callDatas);
    }

    function _actionPolicies(GenesisBatch[] memory batches)
        private
        view
        returns (GovernanceActionPolicyEntry[] memory policies)
    {
        GovernanceActionPolicyEntry[] memory operating = _operatingPolicies();
        uint256 capacity = operating.length;
        for (uint256 i; i < batches.length; ++i) {
            capacity += batches[i].calls.length;
        }
        GovernanceActionPolicyEntry[] memory candidates =
            new GovernanceActionPolicyEntry[](capacity);
        uint256 count = operating.length;
        for (uint256 i; i < count; ++i) {
            candidates[i] = operating[i];
        }
        for (uint256 i; i < batches.length; ++i) {
            for (uint256 j; j < batches[i].calls.length; ++j) {
                GovernanceCall memory operation = batches[i].calls[j];
                bytes32 key = keccak256(
                    abi.encode(batches[i].actionClass, operation.target, operation.selector)
                );
                bool duplicate;
                for (uint256 k; k < count; ++k) {
                    if (
                        keccak256(
                                abi.encode(
                                    candidates[k].actionClass,
                                    candidates[k].target,
                                    candidates[k].selector
                                )
                            ) == key
                    ) duplicate = true;
                }
                if (!duplicate) {
                    candidates[count++] = GovernanceActionPolicyEntry(
                        batches[i].actionClass,
                        operation.target,
                        operation.selector,
                        operation.target.codehash,
                        keccak256(abi.encode(DEPLOYMENT_HASH, operation.target)),
                        1,
                        0,
                        0,
                        bytes32(0)
                    );
                }
            }
        }
        policies = new GovernanceActionPolicyEntry[](count);
        for (uint256 i; i < count; ++i) {
            policies[i] = candidates[i];
        }
        for (uint256 i = 1; i < count; ++i) {
            for (
                uint256 j = i; j > 0 && _policyKey(policies[j - 1]) > _policyKey(policies[j]); --j) {
                (policies[j - 1], policies[j]) = (policies[j], policies[j - 1]);
            }
        }
    }

    function _policyKey(GovernanceActionPolicyEntry memory policy) private pure returns (bytes32) {
        return keccak256(abi.encode(policy.actionClass, policy.target, policy.selector));
    }

    function _productActivationContext()
        private
        view
        returns (StreamCurrentTestProductActivation.Context memory c)
    {
        c.executor = executor;
        c.governanceRoot = governanceRoot;
        c.core = core;
        c.registry = registry;
        c.manifest = manifest;
        c.manager = manager;
        c.ledger = ledger;
        c.entropy = entropy;
        c.provider = address(provider);
        c.router = router;
        c.royalties = royalties;
        c.artists = IStreamArtistMintConsent(address(artists));
        c.finality = address(assemblyFinality);
        c.primaryResolver = primaryResolver;
        c.revenueEscrow = revenueEscrow;
        c.sale = sale;
        c.auction = auction;
        c.profile = profile;
        c.deploymentHash = DEPLOYMENT_HASH;
        c.registryHash = REGISTRY_HASH;
        c.finalityManifestHash = graphFinalityManifestHash;
        c.primaryRevenueClass = PRIMARY_REVENUE_CLASS;
    }

    function _admitInitialProductPolicies(GenesisBatch[] memory batches) private {
        // Preserve the original hook before observing retained policy state.
        GovernanceActionPolicyEntry[] memory operating = _operatingPolicies();
        GovernanceActionPolicyEntry[] memory retained = _foundationPolicies;
        (GovernanceActionPolicyEntry[] memory additions, uint64 appliedRevision) = StreamCurrentTestProductActivation.admitPolicies(
            _productActivationContext(), retained, _fixtureCatalogRevision, operating, batches
        );
        if (additions.length == 0) return;
        _fixtureCatalogRevision = appliedRevision;
        for (uint256 i; i < additions.length; ++i) {
            _foundationPolicies.push(additions[i]);
        }
    }
}

contract StreamCurrentProductActivationBoundaryTest {
    ProductActivationTestVm private constant vm =
        ProductActivationTestVm(address(uint160(uint256(keccak256("hevm cheat code")))));
    ProductActivationBoundaryHarness private host;
    ProductActivationExecutorDouble private executor;
    ProductActivationRootDouble private root;
    ProductActivationReadDouble[] private reads;
    StreamCurrentTestProductActivation.Context private context;

    function setUp() public {
        host = new ProductActivationBoundaryHarness();
        executor = new ProductActivationExecutorDouble(address(host));
        root = new ProductActivationRootDouble(address(host));
        executor.configure(address(root), 7, false, false, false);
        for (uint256 i; i < 15; ++i) {
            reads.push(new ProductActivationReadDouble(address(host), i + 1));
        }
        context.executor = StreamGovernanceExecutor(payable(address(executor)));
        context.governanceRoot = StreamGovernanceActor(payable(address(root)));
        context.core = StreamCore(payable(address(reads[0])));
        context.registry = StreamModuleRegistry(payable(address(reads[1])));
        context.manifest = StreamSystemManifest(payable(address(reads[2])));
        context.manager = StreamMintManager(payable(address(reads[3])));
        context.ledger = StreamMintLedger(payable(address(reads[4])));
        context.entropy = StreamEntropyCoordinator(payable(address(reads[5])));
        context.provider = address(reads[6]);
        context.router = StreamMetadataRouter(payable(address(reads[7])));
        context.royalties = StreamRoyaltyResolver(payable(address(reads[8])));
        context.artists = IStreamArtistMintConsent(address(reads[9]));
        context.finality = address(reads[10]);
        context.primaryResolver = StreamRevenueResolver(payable(address(reads[11])));
        context.revenueEscrow = StreamRevenueEscrow(payable(address(reads[12])));
        context.sale = StreamFixedPriceSaleAdapter(payable(address(reads[13])));
        context.auction = StreamEnglishAuctionHouse(payable(address(reads[14])));
        context.profile = keccak256("boundary profile");
        context.deploymentHash = keccak256("boundary deploymentHash");
        context.registryHash = keccak256("boundary registryHash");
        context.finalityManifestHash = keccak256("boundary finalityManifestHash");
        context.primaryRevenueClass = keccak256("boundary primaryRevenueClass");
        host.configure(context);
    }

    function _row(uint256 id) private view returns (GovernanceActionPolicyEntry memory) {
        address target = address(reads[id]);
        return GovernanceActionPolicyEntry(
            1,
            target,
            bytes4(uint32(id + 1)),
            target.codehash,
            keccak256(abi.encode(context.deploymentHash, target)),
            1,
            0,
            0,
            bytes32(0)
        );
    }

    function _seed(bool addition, bool hookFailure) private {
        GovernanceActionPolicyEntry[] memory retained = new GovernanceActionPolicyEntry[](1);
        retained[0] = _row(10);
        GovernanceActionPolicyEntry[] memory operating =
            new GovernanceActionPolicyEntry[](addition ? 2 : 1);
        operating[0] = retained[0];
        if (addition) operating[1] = _row(11);
        host.seedPolicies(retained, operating, 7, hookFailure);
    }

    function _empty() private pure returns (GenesisBatch[] memory) {
        return new GenesisBatch[](0);
    }

    function _bothReject(bytes memory expected) private {
        (bool oldOk, bytes memory oldData) =
            address(host).call(abi.encodeCall(host.originalAdmission, (_empty())));
        (bool newOk, bytes memory newData) =
            address(host).call(abi.encodeCall(host.linkedAdmission, (_empty())));
        require(
            !oldOk && !newOk && keccak256(oldData) == keccak256(expected)
                && keccak256(newData) == keccak256(expected),
            "same exact rejection"
        );
    }

    function testZeroAdditionsPreservesPriorNonzeroRevision() public {
        _seed(false, false);
        uint256 snapshot = vm.snapshotState();
        host.originalAdmission(_empty());
        bytes32 old = keccak256(abi.encode(host.revision(), host.policies()));
        require(vm.revertToState(snapshot), "restore baseline");
        host.linkedAdmission(_empty());
        require(
            host.revision() == 7 && host.policies().length == 1 && executor.step() == 0,
            "zero additions stay unchanged"
        );
        require(
            old == keccak256(abi.encode(host.revision(), host.policies())), "exact retained state"
        );
    }

    function testZeroAdditionsStillRejectsWrongRevision() public {
        _seed(false, false);
        executor.configure(address(root), 8, false, false, false);
        _bothReject(abi.encodeWithSignature("Error(string)", "exact original foundation catalog"));
    }

    function testOperatingHookFailurePrecedesCatalogRead() public {
        _seed(false, true);
        executor.configure(address(root), 7, true, false, false);
        _bothReject(abi.encodeWithSignature("Error(string)", "operating hook first"));
    }

    function testRetainedPolicyRewriteRejectedBeforeCatalogRead() public {
        GovernanceActionPolicyEntry[] memory retained = new GovernanceActionPolicyEntry[](1);
        retained[0] = _row(10);
        GovernanceActionPolicyEntry[] memory operating = new GovernanceActionPolicyEntry[](1);
        operating[0] = _row(10);
        operating[0].targetCodeHash = keccak256("changed retained hash");
        host.seedPolicies(retained, operating, 7, false);
        executor.configure(address(root), 7, true, false, false);
        _bothReject(
            abi.encodeWithSignature("Error(string)", "foundation policy cannot be rewritten")
        );
    }

    function testRegistrationAndConfigurationReturnedBytesMatch() public {
        (StreamModuleRegistration[] memory oldRecords, GenesisBatch memory oldRegistration) =
            host.originalRegistrations();
        (StreamModuleRegistration[] memory newRecords, GenesisBatch memory newRegistration) =
            host.linkedRegistrations();
        require(
            keccak256(abi.encode(oldRecords, oldRegistration))
                == keccak256(abi.encode(newRecords, newRegistration)),
            "full registration bytes"
        );
        require(
            newRecords.length == 6 && newRegistration.calls.length == 8,
            "original registration roster"
        );
        address[] memory extras = new address[](2);
        extras[0] = address(reads[13]);
        extras[1] = address(reads[14]);
        (GenesisBatch memory oldPointer, GenesisBatch memory oldConfig) =
            host.originalConfiguration(oldRecords, extras);
        (GenesisBatch memory newPointer, GenesisBatch memory newConfig) =
            host.linkedConfiguration(newRecords, extras);
        require(
            keccak256(abi.encode(oldPointer, oldConfig))
                == keccak256(abi.encode(newPointer, newConfig)),
            "full pointer/configuration bytes"
        );
        require(
            newPointer.calls.length == 6 && newConfig.calls.length == 9, "extra producers retained"
        );
    }

    function testExtraProducerOrderChangesExactRows() public {
        (StreamModuleRegistration[] memory records,) = host.linkedRegistrations();
        address[] memory extras = new address[](2);
        extras[0] = address(reads[13]);
        extras[1] = address(reads[14]);
        (, GenesisBatch memory first) = host.linkedConfiguration(records, extras);
        (extras[0], extras[1]) = (extras[1], extras[0]);
        (, GenesisBatch memory second) = host.linkedConfiguration(records, extras);
        require(
            keccak256(first.callDatas[6]) == keccak256(second.callDatas[7])
                && keccak256(first.callDatas[7]) == keccak256(second.callDatas[6]),
            "producer order forwarded"
        );
        require(
            keccak256(first.callDatas[6]) != keccak256(second.callDatas[6]),
            "producer control is sensitive"
        );
    }

    function testBothRejectRegistryCountMismatch() public {
        reads[1].setFailures(false, true);
        (bool a, bytes memory x) =
            address(host).call(abi.encodeCall(host.originalRegistrations, ()));
        (bool b, bytes memory y) = address(host).call(abi.encodeCall(host.linkedRegistrations, ()));
        bytes32 errorHash =
            keccak256(abi.encodeWithSignature("Error(string)", "registry count mismatch"));
        require(
            !a && !b && keccak256(x) == errorHash && keccak256(y) == errorHash,
            "registry rejection unchanged"
        );
    }

    function testPublicationPreservesFullBytesCreatorNonceAndRuntime() public {
        StreamSystemManifest.ModuleAddresses memory modules;
        modules.mintManager = address(context.manager);
        bytes32 reason = keccak256("publication reason");
        uint64 nonce = vm.getNonce(address(host));
        require(nonce > 0 && nonce < 126, "small fixture nonce");
        uint256 snapshot = vm.snapshotState();
        (GovernanceCall memory oldCall, bytes memory oldData) =
            host.originalPublication(modules, reason);
        address oldPointer;
        assembly ("memory-safe") { oldPointer := mload(add(oldData, 36)) }
        bytes memory oldRuntime = oldPointer.code;
        require(vm.revertToState(snapshot), "restore creation nonce");
        (GovernanceCall memory newCall, bytes memory newData) =
            host.linkedPublication(modules, reason);
        address newPointer;
        assembly ("memory-safe") { newPointer := mload(add(newData, 36)) }
        address expectedRoot = address(
            uint160(
                uint256(
                    keccak256(abi.encodePacked(hex"d694", address(host), bytes1(uint8(nonce + 1))))
                )
            )
        );
        address expectedChunk = address(
            uint160(
                uint256(keccak256(abi.encodePacked(hex"d694", address(host), bytes1(uint8(nonce)))))
            )
        );
        require(
            newPointer == oldPointer && newPointer == expectedRoot
                && vm.getNonce(address(host)) == nonce + 2,
            "two same-host CREATEs in original order"
        );
        require(
            expectedChunk.code.length > 1 && keccak256(newPointer.code) == keccak256(oldRuntime),
            "real payload runtimes"
        );
        require(
            keccak256(abi.encode(oldCall, oldData)) == keccak256(abi.encode(newCall, newData)),
            "full publication bytes"
        );
    }

    function testNonemptyAdmissionMatchesCompleteGovernanceTranscript() public {
        _seed(true, false);
        uint256 snapshot = vm.snapshotState();
        host.originalAdmission(_empty());
        bytes32 old = keccak256(
            abi.encode(
                host.policies(),
                host.revision(),
                executor.transcript(),
                root.transcript(),
                reads[2].published(),
                vm.getNonce(address(host)),
                block.timestamp
            )
        );
        require(vm.revertToState(snapshot), "restore admission");
        host.linkedAdmission(_empty());
        require(host.revision() == 8 && host.policies().length == 2, "original host commit");
        require(
            old
                == keccak256(
                    abi.encode(
                        host.policies(),
                        host.revision(),
                        executor.transcript(),
                        root.transcript(),
                        reads[2].published(),
                        vm.getNonce(address(host)),
                        block.timestamp
                    )
                ),
            "full admission/caller/warp/CREATE transcript"
        );
    }

    function testLateExecutionFailureRollsBackAndRetriesIdenticalPolicies() public {
        _seed(true, false);
        executor.configure(address(root), 7, false, true, false);
        uint64 nonce = vm.getNonce(address(host));
        bytes32 beforeState = executor.transcript();
        _bothReject(abi.encodeWithSignature("Error(string)", "late execution rejected"));
        require(
            host.revision() == 7 && host.policies().length == 1
                && executor.transcript() == beforeState,
            "governance and retained state roll back"
        );
        require(
            vm.getNonce(address(host)) == nonce && root.transcript() == bytes32(0)
                && reads[2].published() == bytes32(0),
            "payload CREATE and outward calls roll back"
        );
        executor.configure(address(root), 7, false, false, false);
        host.linkedAdmission(_empty());
        require(
            host.revision() == 8 && host.policies().length == 2, "identical policy retry succeeds"
        );
    }

    function testAppliedCatalogAssertionRollsBackHostCommit() public {
        _seed(true, false);
        executor.configure(address(root), 7, false, false, true);
        uint64 nonce = vm.getNonce(address(host));
        _bothReject(abi.encodeWithSignature("Error(string)", "exact applied catalog extension"));
        require(
            host.revision() == 7 && host.policies().length == 1 && executor.step() == 0
                && vm.getNonce(address(host)) == nonce,
            "final assertion before all host writes"
        );
    }
}
