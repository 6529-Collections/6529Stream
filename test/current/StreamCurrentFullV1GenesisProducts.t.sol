// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../helpers/StreamCurrentStackFixture.sol";
import "../helpers/OfficialSafeFixture.sol";
import "../../script/current/StreamFullV1GenesisProducts.sol";
import "../../script/current/StreamGovernanceStagePlan.sol";
import {
    IStreamClaimRouter
} from "../../smart-contracts/interfaces/stream/revenue/IStreamClaimRouter.sol";

/// @dev External delegate.xyz service boundary only, not a substitute for a genesis product.
contract GenesisDelegationServiceDouble {
    mapping(bytes32 => bool) private grants;

    function delegateContract(address delegate, address token, bytes32 rights, bool enabled)
        external
    {
        grants[keccak256(abi.encode(msg.sender, delegate, token, rights))] = enabled;
    }

    function checkDelegateForContract(
        address delegate,
        address vault,
        address token,
        bytes32 rights
    ) external view returns (bool) {
        return grants[keccak256(abi.encode(vault, delegate, token, rights))];
    }
}

/// @notice Authored composition of six additional roles on the actual current deployment graph.
/// @dev Inherited randomness and the external delegation service are explicit doubles.
/// Attestations here are the existing independent-class5 surface; the assigned general
/// signer-verified institutional/estate producer remains required for role28 completion.
/// This suite does not claim all37 roles, full production providers, or executed acceptance.
contract StreamCurrentFullV1GenesisProductsTest is StreamCurrentStackFixture, OfficialSafeFixture {
    StreamFullV1GenesisProducts.Configuration private composition;
    StreamFullV1GenesisProducts.Products private products;
    OfficialSafe private governor;
    OfficialSafe private otherSafe;
    uint256[] private keys;

    function setUp() public {
        keys.push(0x652901);
        keys.push(0x652902);
        SafeComponents memory safe = deploySafeComponents("1.4.1");
        governor = createOfficialSafe(safe, safeOwnerAddresses(keys), 2, 3701);
        otherSafe = createOfficialSafe(safe, safeOwnerAddresses(keys), 2, 3702);
        vm.deal(address(this), 10 ether);
        _deployCurrentStack(vm.addr(ARTIST_KEY), vm.addr(PLATFORM_KEY));
        _installGovernor();
        _executeStage(_registrationWithTail(), keccak256("genesis independent products"));
    }

    function _deployAdditionalProducts() internal override {
        composition.core = address(core);
        composition.executor = address(executor);
        composition.metadata = address(assemblyMetadata);
        composition.schemas = address(assemblySchemas);
        composition.ticketSigner = address(governor);
        composition.ticketSignerKind = 2;
        composition.delegateRegistry = address(new GenesisDelegationServiceDouble());
        composition.delegationUsecase = keccak256("full-v1 genesis delegate gate fixture");
        composition.deploymentHash = DEPLOYMENT_HASH;
        composition.ticket = _manifest("tickets");
        composition.delegateManifestURI = "https://engineering.example.invalid/genesis/delegation";
        composition.owner = _manifest("owner-records");
        composition.attestation = _manifest("attestations");
        composition.views = _manifest("views");
        composition.signatureGas = IStreamGasParameterHost.GasParameterConfig(
            "METADATA_ERC1271_VERIFY_GAS", 400000, 90000, 2
        );
        composition.dependencyReadGas = IStreamGasParameterHost.GasParameterConfig(
            "METADATA_DEPENDENCY_READ_GAS", 300000, 50000, 2
        );
        products = StreamFullV1GenesisProducts.deploy(composition);
    }

    function _additionalOperatingPolicies()
        internal
        view
        override
        returns (GovernanceActionPolicyEntry[] memory rows)
    {
        rows = new GovernanceActionPolicyEntry[](1);
        rows[0] = GovernanceActionPolicyEntry(
            1,
            address(products.tickets),
            products.tickets.raiseGasParameter.selector,
            address(products.tickets).codehash,
            keccak256(abi.encode(DEPLOYMENT_HASH, address(products.tickets))),
            1,
            0,
            0,
            bytes32(0)
        );
    }

    function testOriginalProductsShareActualCoreSchemasAndCanonicalGovernance() public view {
        StreamFullV1GenesisProducts.validate(composition, products);
        require(
            products.views.metadataHost() == address(assemblyMetadata), "selected original metadata"
        );
        require(
            products.owners.schemaRegistry() == address(assemblySchemas), "shared original schemas"
        );
        require(
            products.attestations.chunkStore() == assemblySchemas.chunkStore(),
            "shared original bytes"
        );
        require(products.tickets.ticketSigner() == address(governor), "Safe ticket signer");
        StreamModuleRegistration[] memory rows =
            StreamFullV1GenesisProducts.registrations(composition, products, 600000, 500000);
        for (uint256 i; i < rows.length; ++i) {
            StreamModuleRecord memory r = registry.moduleRecord(rows[i].module);
            require(
                r.status == ModuleRegistryStatus.ACTIVE
                    && r.runtimeCodeHash == rows[i].expectedRuntimeCodeHash
                    && r.moduleType == rows[i].moduleType && r.interfaceId == rows[i].interfaceId
                    && r.moduleVersion == rows[i].moduleVersion
                    && r.moduleManifestHash == rows[i].moduleManifestHash,
                "exact original module admission"
            );
        }
        require(address(products.claims).code.length != 0, "actual noncustodial claim router");
        require(
            manager.owner() == address(executor) && ledger.owner() == address(executor),
            "handoff retained"
        );
    }

    function testSafeRecordRevocationsRetainContractPrincipalAcrossIdenticalOwners() public {
        require(
            executeSafe(
                governor,
                keys,
                address(products.owners),
                0,
                abi.encodeCall(products.owners.revokeOwnerRecordNonce, (uint256(37))),
                0
            ),
            "owner nonce"
        );
        require(
            executeSafe(
                governor,
                keys,
                address(products.attestations),
                0,
                abi.encodeCall(products.attestations.revokeIndependentAttestorNonce, (uint256(37))),
                0
            ),
            "attestor nonce"
        );
        require(products.owners.isOwnerRecordNonceUsed(address(governor), 37), "actual Safe owner");
        require(
            products.attestations.isIndependentAttestorNonceUsed(address(governor), 37),
            "actual Safe attestor"
        );
        require(
            !products.owners.isOwnerRecordNonceUsed(address(otherSafe), 37),
            "different Safe principal"
        );
        require(
            !products.attestations.isIndependentAttestorNonceUsed(vm.addr(keys[0]), 37),
            "owner not Safe"
        );
        vm.prank(vm.addr(keys[0]));
        products.owners.revokeOwnerRecordNonce(38);
        require(
            !products.owners.isOwnerRecordNonceUsed(address(governor), 38),
            "EOA cannot consume Safe nonce"
        );
    }

    function testSafeClaimFailureRollsBackReleaseAndExactValidClaimRetries() public {
        IStreamSplitWallet.SplitEntry[] memory entries = new IStreamSplitWallet.SplitEntry[](1);
        entries[0] = IStreamSplitWallet.SplitEntry(
            address(governor), 1000000, keccak256("Safe entitlement")
        );
        (bytes32 profileId,) = factory.createProfile(entries, keccak256("genesis claim profile"));
        address split = factory.deployWallet(profileId);
        (bool funded,) = payable(split).call{ value: 1 ether }("");
        require(funded, "actual wallet passive funding");
        IStreamClaimRouter.ClaimCall[] memory claims = new IStreamClaimRouter.ClaimCall[](2);
        claims[0] = IStreamClaimRouter.ClaimCall(split, address(0), address(governor));
        claims[1] = IStreamClaimRouter.ClaimCall(address(0xBAD), address(0), address(governor));
        uint256 nonce = governor.nonce();
        uint256 before = address(governor).balance;
        vm.expectRevert();
        executeSafe(
            governor,
            keys,
            address(products.claims),
            0,
            abi.encodeCall(products.claims.syncAndClaimMany, (claims, false)),
            0
        );
        require(
            split.balance == 1 ether && address(governor).balance == before
                && governor.nonce() == nonce,
            "outer Safe rollback restores first release and nonce"
        );
        claims = new IStreamClaimRouter.ClaimCall[](1);
        claims[0] = IStreamClaimRouter.ClaimCall(split, address(0), address(governor));
        require(
            executeSafe(
                governor,
                keys,
                address(products.claims),
                0,
                abi.encodeCall(products.claims.syncAndClaimMany, (claims, false)),
                0
            ),
            "original valid claim retries"
        );
        require(
            address(governor).balance == before + 1 ether && split.balance == 0,
            "entitled Safe paid"
        );
        require(address(products.claims).balance == 0, "router never takes custody");
    }

    function testSafeSchedulesExactTicketGasRaiseAfterDirectCallsFail() public {
        bytes32 id = products.tickets.GGP_TICKET_ERC1271_GAS_LIMIT();
        IStreamGasParameterHost host = IStreamGasParameterHost(address(products.tickets));
        (uint256 value, uint256 floor, uint8 failure, uint64 revision) = host.gasParameterInfo(id);
        bytes memory data = abi.encodeCall(host.raiseGasParameter, (id, value * 2));
        vm.expectRevert();
        executeSafe(governor, keys, address(host), 0, data, 0);
        bytes32 scope = keccak256(
            abi.encode(
                keccak256("6529STREAM_GAS_PARAMETER_SCOPE_V2"), block.chainid, address(host), id
            )
        );
        bytes32 state = keccak256("6529STREAM_GAS_PARAMETER_STATE_V2");
        GenesisBatch memory batch;
        batch.actionClass = 1;
        batch.calls = new GovernanceCall[](1);
        batch.callDatas = new bytes[](1);
        batch.callDatas[0] = data;
        batch.calls[0] = StreamCurrentStackPlan.call(
            address(host),
            data,
            scope,
            keccak256(abi.encode(state, scope, value, floor, failure, revision)),
            keccak256(abi.encode(state, scope, value * 2, floor, failure, revision + 1))
        );
        _executeStage(batch, keccak256("actual ticket budget raise"));
        require(host.gasParameter(id) == value * 2, "exact governed raise executed");
    }

    function testRetainedCompositionRejectsChangedMetadataOrRuntimeFacts() public {
        StreamFullV1GenesisProducts.Configuration memory changed = composition;
        changed.metadata = address(products.views);
        vm.expectRevert();
        this.validateComposition(changed, products);
        StreamFullV1GenesisProducts.Products memory changedProducts = products;
        changedProducts.codeHashes[1] = bytes32(uint256(1));
        vm.expectRevert(
            abi.encodeWithSelector(
                StreamFullV1GenesisProducts.GenesisProductChanged.selector,
                address(products.tickets)
            )
        );
        this.validateComposition(composition, changedProducts);
        StreamFullV1GenesisProducts.validate(composition, products);
    }

    function validateComposition(
        StreamFullV1GenesisProducts.Configuration memory c,
        StreamFullV1GenesisProducts.Products memory p
    ) external view {
        StreamFullV1GenesisProducts.validate(c, p);
    }

    function _manifest(string memory name)
        private
        pure
        returns (StreamFullV1GenesisProducts.Manifest memory)
    {
        return StreamFullV1GenesisProducts.Manifest(
            keccak256(abi.encode("full-v1 genesis product fixture", name)),
            string.concat("https://engineering.example.invalid/genesis/", name)
        );
    }

    function _installGovernor() private {
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
        private
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

    function _registrationWithTail() private returns (GenesisBatch memory batch) {
        GenesisBatch memory original = StreamFullV1GenesisProducts.registrationBatch(
            registry, composition, products, 600000, 500000
        );
        batch.actionClass = original.actionClass;
        batch.calls = new GovernanceCall[](original.calls.length + 1);
        batch.callDatas = new bytes[](batch.calls.length);
        for (uint256 i; i < original.calls.length; ++i) {
            batch.calls[i] = original.calls[i];
            batch.callDatas[i] = original.callDatas[i];
        }
        StreamSystemManifest.AggregateState memory current =
            StreamGenesisManifestPlan.readAggregate(manifest);
        (address payload, bytes32 hash) = StreamGenesisManifestPlan.writePayload(
            bytes("{\"purpose\":\"six original genesis products\",\"completeGenesis\":false}")
        );
        StreamSystemManifestUpdate memory update = StreamSystemManifestUpdate(
            hash,
            "urn:6529stream:genesis:independent-products",
            current.discovery.eventCatalogHash,
            current.discovery.compatibilityMatrixHash,
            current.discovery.numericIdCatalogHash,
            current.discovery.schemaCatalogHash,
            current.discovery.canonicalizationCatalogHash,
            current.discovery.specBundleHash,
            current.discovery.reconstructionClientHash
        );
        (batch.calls[original.calls.length], batch.callDatas[original.calls.length]) =
            StreamGenesisManifestPlan.publicationCall(manifest, payload, update, current.modules);
    }

    function _executeStage(GenesisBatch memory batch, bytes32 stage) private {
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
        vm.expectRevert();
        this.executeSaved(plan, action, saved);
        vm.warp(ready);
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
