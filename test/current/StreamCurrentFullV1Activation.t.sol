// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "../helpers/StreamFullV1ActivationFixture.sol";
import { StreamMuseumGenesisSource } from "../helpers/StreamMuseumGenesisSource.sol";
import {
    StreamSchemaAdmissionPlan as MuseumAdmission
} from "../../script/current/StreamSchemaAdmissionPlan.sol";
import {
    StreamFullV1ActivationPolicies
} from "../../script/current/StreamFullV1ActivationPolicies.sol";
import { StreamFullV1ActivationPlan } from "../../script/current/StreamFullV1ActivationPlan.sol";
import {
    StreamGovernanceCatalogStagePlan
} from "../../script/current/StreamGovernanceCatalogStagePlan.sol";
import { StreamGovernanceStagePlan } from "../../script/current/StreamGovernanceStagePlan.sol";
import {
    IStreamEntropyProviderLifecycle,
    EntropyProviderState
} from "../../smart-contracts/interfaces/stream/entropy/IStreamEntropyProviderLifecycle.sol";

/// @notice Authored current-graph activation slices using actual 2-of-2 Safe delayed governance.
/// @dev Includes a combined canonical Museum admission/binding case. Complete STATIC
/// admission, live services and full37 functional/release acceptance remain separate.
contract StreamCurrentFullV1ActivationTest is StreamFullV1ActivationFixture {
    uint256 private stageNonce;

    function setUp() public {
        _constructActivationCandidate();
    }

    function _additionalOperatingPolicies()
        internal
        view
        override
        returns (GovernanceActionPolicyEntry[] memory rows)
    {
        rows = new GovernanceActionPolicyEntry[](4);
        rows[0] =
            _fixturePolicy(address(assemblySchemas), assemblySchemas.registerDocument.selector);
        rows[1] =
            _fixturePolicy(address(assemblyMetadata), assemblyMetadata.setFamilyWriter.selector);
        rows[2] = _fixturePolicy(address(entropy), entropy.raiseGasParameter.selector);
        rows[3] =
            _fixturePolicy(address(assemblyMetadata), assemblyMetadata.admitRecordType.selector);
    }

    function testConstructedInventoryHas21PendingRowsAndOriginalSortedPolicies() public view {
        StreamModuleRegistration[] memory rows =
            StreamFullV1ActivationPlan.pendingRegistrations(_context(), _inputs());
        require(rows.length == 21, "21 actual pending module products");
        for (uint256 i; i < rows.length; ++i) {
            require(rows[i].module.codehash == rows[i].expectedRuntimeCodeHash, "retained runtime");
            require(
                rows[i].module != address(products.independent.claims)
                    && rows[i].module != products.continuity.walletImplementation
                    && rows[i].module != address(products.rendering.attribution),
                "nonmodule companions stay inventory only"
            );
        }
        GovernanceActionPolicyEntry[] memory policies =
            StreamFullV1ActivationPolicies.desired(_context());
        bool retirement;
        bool recovery;
        for (uint256 i; i < policies.length; ++i) {
            if (i != 0) {
                require(
                    StreamFullV1ActivationPolicies.key(policies[i - 1])
                        < StreamFullV1ActivationPolicies.key(policies[i]),
                    "sorted unique original keys"
                );
            }
            require(
                policies[i].callType == 1 && policies[i].valuePolicy == 0
                    && policies[i].valueLimit == 0,
                "zero value exact target policies"
            );
            if (
                policies[i].target == address(ledger)
                    && policies[i].selector == ledger.retireLedgerWriter.selector
            ) retirement = policies[i].actionClass == 0;
            if (
                policies[i].target == address(products.continuity.manager)
                    && policies[i].selector
                        == products.continuity.manager.recoverPreparedMint.selector
            ) recovery = policies[i].actionClass == 3;
        }
        require(retirement && recovery, "original recovery classes");
    }

    function testActualSafeAdmits21OriginalModulesWithExactTailsAndIdempotentReadback() public {
        _extend();
        uint256 count = registry.moduleCount();
        _register();
        require(registry.moduleCount() == count + 21, "exact real module additions");
        StreamFullV1ActivationPlan.requireRegistered(_context(), _inputs());
        StreamModuleRegistration[] memory rows =
            StreamFullV1ActivationPlan.registrations(_context(), _inputs());
        for (uint256 i; i < rows.length; ++i) {
            require(
                registry.isModuleEligible(rows[i].module, rows[i].moduleType, rows[i].interfaceId),
                "actual ACTIVE product"
            );
        }
        require(
            !ledger.ledgerWriter(address(products.continuity.manager)),
            "admission did not grant reserve writer"
        );
        (address recorder,,,) = manager.preparedNativeRecorder();
        require(recorder == address(0), "admission did not bind recorder");
    }

    function testOneWayOriginalBindingsWriterAndIsolatedRetirementClassifier() public {
        _extend();
        _register();
        _run(StreamFullV1ActivationPlan.recorderCredit(_context()));
        _run(StreamFullV1ActivationPlan.custodyBinding(_context()));
        _run(StreamFullV1ActivationPlan.managerBinding(_context(), false));
        _run(StreamFullV1ActivationPlan.managerBinding(_context(), true));
        _run(StreamFullV1ActivationPlan.reserveWriter(_context()));
        GenesisBatch memory isolated = StreamFullV1ActivationPlan.retirementClassifier(_context());
        require(
            isolated.actionClass == 1 && isolated.calls.length == 1
                && isolated.calls[0].target == address(executor),
            "isolated original classifier"
        );
        StreamFullV1ActivationPlan.Publication memory pub = _publication();
        vm.expectRevert();
        this.appendClassifierTail(isolated, pub);
        _run(isolated);
        StreamMintFallbackPlan.requireReserveReady(
            StreamFullV1ContinuityProducts.mintConfiguration(
                configuration.continuity, products.continuity
            )
        );
        (bool classified, bytes32 codeHash,,) =
            executor.tighteningCallConfig(address(ledger), ledger.retireLedgerWriter.selector);
        require(
            classified && codeHash == address(ledger).codehash
                && ledger.ledgerWriterRetiredAt(address(manager)) == 0,
            "classified but primary not retired"
        );
        require(
            products.commerce.native.recorder.canonicalCustodyHouse().house
                == address(products.commerce.native.house),
            "original canonical house"
        );
        vm.expectRevert();
        this.planManager(false);
        vm.expectRevert();
        this.planManager(true);
        vm.expectRevert();
        this.planCustody();
    }

    function testPrerequisitesFailBeforeAdmissionAndCredit() public {
        vm.expectRevert();
        this.planManager(false);
        vm.expectRevert();
        this.planManager(true);
        vm.expectRevert();
        this.planProvider(2);
        _extend();
        _register();
        vm.expectRevert();
        this.planManager(false);
        vm.expectRevert();
        this.planManager(true);
        StreamEntropyFallbackPlan.Collection memory row = _collection();
        vm.expectRevert();
        this.planCollection(row);
    }

    function testOriginalProvidersActivateOnOwnCoordinatorsAndReserveCollectionReadback() public {
        _extend();
        _register();
        // The existing foundation already classified both primary retirement selectors.
        (bool existing, bytes32 primaryHash,,) = executor.tighteningCallConfig(
            address(entropy), entropy.deprecateEntropyProvider.selector
        );
        require(existing && primaryHash == address(entropy).codehash, "retain primary classifier");
        _run(StreamFullV1ActivationPlan.providerClassifier(_context(), true, false));
        _run(StreamFullV1ActivationPlan.providerClassifier(_context(), true, true));
        for (uint8 i; i < 3; ++i) {
            _run(
                StreamFullV1ActivationPlan.providerActivation(
                    _context(), i, "urn:fixture:activation:provider"
                )
            );
            (StreamEntropyCoordinator e, address provider) =
                StreamFullV1ActivationPlan.providerPair(_context(), i);
            IStreamEntropyProviderLifecycle.ProviderRecord memory r =
                e.entropyProviderRecord(provider);
            require(
                r.state == EntropyProviderState.ACTIVE && r.runtimeCodeHash == provider.codehash
                    && r.lastActionId != 0,
                "actual original activation receipt"
            );
        }
        require(
            entropy.entropyProviderRecord(address(products.continuity.provider)).state
                == EntropyProviderState.UNKNOWN,
            "backup provider not activated on primary"
        );
        StreamEntropyFallbackPlan.Collection memory row = _collection();
        _run(StreamFullV1ActivationPlan.collectionConfiguration(_context(), 2, row));
        StreamEntropyFallbackPlan.Collection memory wrong =
            abi.decode(abi.encode(row), (StreamEntropyFallbackPlan.Collection));
        wrong.revealOwnerRole = keccak256("ROLE_ENTROPY_ADMIN");
        vm.expectRevert();
        this.planReveal(wrong, address(this));
        vm.expectRevert();
        this.planReveal(row, address(governorSafe));
        // Base fixture grants this explicit entropy administrator; no implicit writer grant.
        require(
            roles.hasRole(keccak256("ROLE_ENTROPY_ADMIN"), address(this)), "actual fixture role"
        );
        StreamGovernanceStagePlan.NextCall memory reveal =
            StreamFullV1ActivationPlan.revealConfiguration(_context(), 2, row, address(this));
        require(
            reveal.caller == address(this) && reveal.target == address(products.continuity.entropy),
            "explicit direct administrator call"
        );
        (bool ok,) = reveal.target.call(reveal.data);
        require(ok, "original reveal configuration");
        StreamEntropyFallbackPlan.Collection[] memory all =
            new StreamEntropyFallbackPlan.Collection[](1);
        all[0] = row;
        StreamEntropyFallbackPlan.checkpoint(
            entropy,
            products.continuity.entropy,
            all,
            keccak256("explicit fixture historical inventory only")
        );
        row.provider = address(products.vrf);
        vm.expectRevert();
        this.planCollection(row);
    }

    /// @notice One actual graph retains every original role across schema and module activation.
    /// @dev This does not select reserve products as primary or invent STATIC analysis evidence.
    function testAll37ConstructionSurvivesCombinedBindingsAndCanonicalMuseumAdmission() public {
        StreamFullV1Candidate.Inventory memory original =
            StreamFullV1Candidate.capture(foundation, configuration, products);
        require(
            original.roles.length == 37 && original.support.length == 25, "complete construction"
        );
        uint256 modulesBefore = registry.moduleCount();
        _extend();
        _register();
        require(registry.moduleCount() == modulesBefore + 21, "all original pending modules");
        StreamFullV1ActivationPlan.requireRegistered(_context(), _inputs());

        // Admissions and the later bindings share the same Registry, Store, Safe and Executor.
        (MuseumAdmission.Document[] memory rows, string[] memory paths, bytes32 sourceHash) =
            StreamMuseumGenesisSource.load();
        MuseumAdmission.Plan memory catalog =
            MuseumAdmission.capture(assemblySchemas, sourceHash, rows);
        bytes32 catalogHash = MuseumAdmission.planHash(catalog);
        uint256 documentsBefore = assemblySchemas.documentCount();
        uint256 pending = MuseumAdmission.pending(catalog, catalogHash);
        for (uint256 i; i < rows.length; ++i) {
            MuseumAdmission.publish(catalog, catalogHash, i, bytes(vm.readFile(paths[i])));
            GenesisBatch memory intent = MuseumAdmission.next(catalog, catalogHash, i);
            if (intent.calls.length != 0) {
                _run(
                    StreamFullV1ActivationPlan.withManifestTail(_context(), intent, _publication())
                );
            }
        }
        require(
            assemblySchemas.documentCount() == documentsBefore + pending, "exact schema additions"
        );
        _requireCanonicalMuseum(catalog, catalogHash, paths);
        require(
            !ledger.ledgerWriter(address(products.continuity.manager)), "schemas grant no writer"
        );

        _run(StreamFullV1ActivationPlan.recorderCredit(_context()));
        _run(StreamFullV1ActivationPlan.custodyBinding(_context()));
        _run(StreamFullV1ActivationPlan.managerBinding(_context(), false));
        _run(StreamFullV1ActivationPlan.managerBinding(_context(), true));
        _run(StreamFullV1ActivationPlan.reserveWriter(_context()));
        _run(StreamFullV1ActivationPlan.retirementClassifier(_context()));
        StreamMintFallbackPlan.requireReserveReady(
            StreamFullV1ContinuityProducts.mintConfiguration(
                configuration.continuity, products.continuity
            )
        );
        (address primaryRecorder,,,) = manager.preparedNativeRecorder();
        (address reserveRecorder,,,) = products.continuity.manager.preparedNativeRecorder();
        (bool enabled, bytes32 recorderHash,) = revenueEscrow.creditProducer(primaryRecorder);
        require(
            primaryRecorder == address(products.commerce.native.recorder)
                && reserveRecorder == primaryRecorder && enabled
                && recorderHash == primaryRecorder.codehash
                && products.commerce.native.recorder.canonicalCustodyHouse().house
                    == address(products.commerce.native.house),
            "actual primary reserve recorder and escrow bindings"
        );
        _run(StreamFullV1ActivationPlan.providerClassifier(_context(), true, false));
        _run(StreamFullV1ActivationPlan.providerClassifier(_context(), true, true));
        for (uint8 i; i < 3; ++i) {
            _run(
                StreamFullV1ActivationPlan.providerActivation(
                    _context(), i, "urn:fixture:combined-genesis"
                )
            );
            (StreamEntropyCoordinator coordinator, address provider) =
                StreamFullV1ActivationPlan.providerPair(_context(), i);
            IStreamEntropyProviderLifecycle.ProviderRecord memory receipt =
                coordinator.entropyProviderRecord(provider);
            require(
                receipt.state == EntropyProviderState.ACTIVE
                    && receipt.runtimeCodeHash == provider.codehash && receipt.lastActionId != 0,
                "three original provider activation receipts"
            );
        }
        StreamEntropyFallbackPlan.Collection memory reserve = _collection();
        _run(StreamFullV1ActivationPlan.collectionConfiguration(_context(), 2, reserve));
        StreamGovernanceStagePlan.NextCall memory reveal =
            StreamFullV1ActivationPlan.revealConfiguration(_context(), 2, reserve, address(this));
        require(
            reveal.caller == address(this) && reveal.target == address(products.continuity.entropy),
            "explicit reserve administrator"
        );
        (bool ok,) = reveal.target.call(reveal.data);
        require(ok, "actual reserve reveal policy");
        StreamEntropyFallbackPlan.Collection[] memory collections =
            new StreamEntropyFallbackPlan.Collection[](1);
        collections[0] = reserve;
        StreamEntropyFallbackPlan.checkpoint(
            entropy,
            products.continuity.entropy,
            collections,
            keccak256("combined fixture inventory")
        );

        StreamFullV1Candidate.requireUnchanged(
            foundation, configuration, products, savedInventoryHash
        );
        StreamFullV1Candidate.Inventory memory retained =
            StreamFullV1Candidate.capture(foundation, configuration, products);
        require(
            keccak256(abi.encode(retained)) == keccak256(abi.encode(original)),
            "all37 and25support retain original identities"
        );
        StreamFullV1ActivationPlan.requireRegistered(_context(), _inputs());
        require(
            StreamFullV1ActivationPlan.pendingRegistrations(_context(), _inputs()).length == 0,
            "no omitted admission"
        );
        _requireCanonicalMuseum(catalog, catalogHash, paths);
        require(
            StreamCurrentStackPlan.readPointer(core, keccak256("MINT_MANAGER")).target
                    == address(manager)
                && StreamCurrentStackPlan.readPointer(core, keccak256("ENTROPY_COORDINATOR")).target
                == address(entropy) && ledger.ledgerWriterRetiredAt(address(manager)) == 0
                && entropy.entropyProviderRecord(address(products.continuity.provider)).state
                    == EntropyProviderState.UNKNOWN,
            "reserve readiness neither promotes backup nor retires primary"
        );
    }

    function _requireCanonicalMuseum(
        MuseumAdmission.Plan memory catalog,
        bytes32 hash,
        string[] memory paths
    ) private view {
        MuseumAdmission.requireRegistered(catalog, hash);
        require(
            catalog.documents.length == 51 && paths.length == 51, "complete canonical source set"
        );
        uint256 bytesCount;
        uint256 occurrences;
        for (uint256 i; i < catalog.documents.length; ++i) {
            MuseumAdmission.Document memory row = catalog.documents[i];
            bytes32 id = keccak256(bytes(row.specification.name));
            require(
                MuseumAdmission.next(catalog, hash, i).calls.length == 0,
                "original ACTIVE schema readback"
            );
            require(
                keccak256(assemblySchemas.documentBytes(id))
                    == keccak256(bytes(vm.readFile(paths[i]))),
                "all original canonical bytes"
            );
            for (uint256 j; j < row.chunkHashes.length; ++j) {
                require(
                    assemblySchemas.documentChunkHashAt(id, j) == row.chunkHashes[j],
                    "ordered original chunk occurrence"
                );
            }
            bytesCount += row.specification.totalBytes;
            occurrences += row.chunkHashes.length;
        }
        require(
            bytesCount == 401717 && occurrences == 78, "complete Museum byte and occurrence closure"
        );
    }

    function testChangedRegistrationMetadataRejectedAfterActualAdmission() public {
        _extend();
        _register();
        StreamFullV1ActivationPlan.RegistrationInputs memory changed = _inputs();
        changed.readGas += 1;
        vm.expectRevert();
        this.pending(changed);
        changed = _inputs();
        changed.fixedSale.hash = keccak256("changed proposed module manifest");
        vm.expectRevert();
        this.pending(changed);
        require(
            StreamFullV1ActivationPlan.pendingRegistrations(_context(), _inputs()).length == 0,
            "original exact rows retained"
        );
    }

    function testInvalidManifestTailRollsBackRealRegistryMutation() public {
        _extend();
        StreamFullV1ActivationPlan.Publication memory pub = _publication();
        pub.update.manifestHash = keccak256("wrong payload commitment");
        GenesisBatch memory batch =
            StreamFullV1ActivationPlan.registrationBatch(_context(), _inputs(), 1, pub);
        StreamGovernanceStagePlan.Plan memory plan = _plan(batch);
        bytes32 id = _schedule(plan);
        uint256 count = registry.moduleCount();
        vm.warp(plan.notBefore);
        vm.expectRevert();
        this.executePlan(plan, id);
        require(
            registry.moduleCount() == count
                && executor.governanceAction(id).status == GovernanceActionStatus.SCHEDULED,
            "tail failure rolls back module and action"
        );
        require(
            StreamFullV1ActivationPlan.pendingRegistrations(_context(), _inputs()).length == 21,
            "all originals remain pending"
        );
    }

    function testSavedRegistrationRejectsChangedRegistryPrefix() public {
        _extend();
        GenesisBatch memory first =
            StreamFullV1ActivationPlan.registrationBatch(_context(), _inputs(), 1, _publication());
        StreamGovernanceStagePlan.Plan memory stale = _plan(first);
        bytes32 staleId = _schedule(stale);
        _run(StreamFullV1ActivationPlan.registrationBatch(_context(), _inputs(), 1, _publication()));
        vm.expectRevert();
        this.executePlan(stale, staleId);
        require(
            StreamFullV1ActivationPlan.pendingRegistrations(_context(), _inputs()).length == 20,
            "stale action cannot duplicate admission"
        );
    }

    function testRetainedCatalogConflictAndConstructionDriftRefusePlanning() public {
        GovernanceActionPolicyEntry[] memory known = _knownPolicies();
        known[0].valuePolicy = 1;
        vm.expectRevert();
        this.additions(known);
        StreamFullV1ActivationPlan.Context memory x = _context();
        x.inventoryHash = keccak256("wrong saved construction");
        vm.expectRevert();
        this.validateContext(x);
    }

    function testSuppliedDocumentPlanRetainsOrderedMultiChunkBytesWithoutInventingMuseumSchema()
        public
    {
        _extend();
        if (!assemblySchemas.document(assemblySchemas.RAW_BYTES()).exists) {
            bytes memory raw = bytes(assemblySchemas.RAW_BYTES_DEFINITION());
            (bytes32 hash,) = assemblyStore.publishChunk(raw);
            bytes32[] memory bootstrapChunks = new bytes32[](1);
            bootstrapChunks[0] = hash;
            IStreamSchemaRegistry.DocumentSpec memory bootstrap = IStreamSchemaRegistry.DocumentSpec(
                "RAW_BYTES",
                IStreamSchemaRegistry.DocumentKind.CANONICALIZATION,
                hash,
                assemblySchemas.RAW_BYTES(),
                0,
                "",
                uint32(raw.length)
            );
            _run(
                StreamFullV1ActivationPlan.withManifestTail(
                    _context(),
                    StreamFullV1ActivationPlan.schemaDocument(
                        _context(), bootstrap, bootstrapChunks
                    ),
                    _publication()
                )
            );
        }
        bytes memory first = new bytes(8192);
        bytes memory last = new bytes(808);
        for (uint256 i; i < first.length; ++i) {
            first[i] = 0x61;
        }
        for (uint256 i; i < last.length; ++i) {
            last[i] = 0x62;
        }
        bytes32[] memory chunks = new bytes32[](2);
        (chunks[0],) = assemblyStore.publishChunk(first);
        (chunks[1],) = assemblyStore.publishChunk(last);
        bytes32 content = keccak256(bytes.concat(first, last));
        IStreamSchemaRegistry.DocumentSpec memory spec = IStreamSchemaRegistry.DocumentSpec(
            "ACTIVATION_OPAQUE_DOCUMENT_FIXTURE_V1",
            IStreamSchemaRegistry.DocumentKind.SCHEMA,
            content,
            assemblySchemas.RAW_BYTES(),
            0,
            "urn:fixture:not-a-Museum-definition",
            9000
        );
        _run(
            StreamFullV1ActivationPlan.withManifestTail(
                _context(),
                StreamFullV1ActivationPlan.schemaDocument(_context(), spec, chunks),
                _publication()
            )
        );
        bytes32 id = keccak256(bytes(spec.name));
        IStreamSchemaRegistry.DocumentView memory observed = assemblySchemas.document(id);
        require(
            observed.exists && observed.chunkHashes.length == 2
                && observed.chunkHashes[0] == chunks[0] && observed.chunkHashes[1] == chunks[1]
                && observed.specification.contentHash == content
                && keccak256(assemblySchemas.documentBytes(id)) == content,
            "original document bytes and ordering"
        );
        vm.expectRevert();
        this.planDocument(spec, chunks);
    }

    function testConstructedRendererCannotStandInForSuppliedStaticAdmissionEvidence() public {
        Versions.Registration memory empty;
        Versions.Read[] memory reads = new Versions.Read[](0);
        vm.expectRevert();
        this.planStatic(empty, reads);
    }

    function _context() private view returns (StreamFullV1ActivationPlan.Context memory) {
        return StreamFullV1ActivationPlan.Context(
            foundation, configuration, products, savedInventoryHash
        );
    }

    function _inputs()
        private
        pure
        returns (StreamFullV1ActivationPlan.RegistrationInputs memory r)
    {
        r.gateGas = 1000000;
        r.readGas = 1000000;
        r.commerceGas = 500000;
        r.providerGas = 1000000;
        r.fixedSale = StreamFullV1ActivationPlan.Manifest(
            keccak256("fixture fixed"), "urn:fixture:activation:fixed"
        );
        r.dutch = StreamFullV1ActivationPlan.Manifest(
            keccak256("fixture Dutch"), "urn:fixture:activation:dutch"
        );
        r.privateSale = StreamFullV1ActivationPlan.Manifest(
            keccak256("fixture private"), "urn:fixture:activation:private"
        );
        r.erc20 = StreamFullV1ActivationPlan.Manifest(
            keccak256("fixture ERC20"), "urn:fixture:activation:erc20"
        );
    }

    function _collection() private view returns (StreamEntropyFallbackPlan.Collection memory) {
        return StreamEntropyFallbackPlan.Collection(
            1,
            address(products.continuity.provider),
            keccak256("reserve fixture salt"),
            true,
            100,
            1,
            keccak256("ROLE_ENTROPY_REVEAL_OWNER"),
            100,
            0
        );
    }

    function _publication() private returns (StreamFullV1ActivationPlan.Publication memory p) {
        StreamSystemManifest.AggregateState memory current =
            StreamGenesisManifestPlan.readAggregate(manifest);
        (p.payload, p.update.manifestHash) = StreamGenesisManifestPlan.writePayload(
            bytes("{\"fixture\":true,\"scope\":\"authored activation stage only\"}")
        );
        p.update.manifestURI = "urn:fixture:activation-stage";
        p.update.eventCatalogHash = current.discovery.eventCatalogHash;
        p.update.compatibilityMatrixHash = current.discovery.compatibilityMatrixHash;
        p.update.numericIdCatalogHash = current.discovery.numericIdCatalogHash;
        p.update.schemaCatalogHash = current.discovery.schemaCatalogHash;
        p.update.canonicalizationCatalogHash = current.discovery.canonicalizationCatalogHash;
        p.update.specBundleHash = current.discovery.specBundleHash;
        p.update.reconstructionClientHash = current.discovery.reconstructionClientHash;
    }

    function _plan(GenesisBatch memory batch)
        private
        returns (StreamGovernanceStagePlan.Plan memory)
    {
        uint64 ready = uint64(block.timestamp + executor.minimumDelay(batch.actionClass));
        return StreamGovernanceStagePlan.build(
            executor,
            keccak256(abi.encode("activation fixture", ++stageNonce)),
            batch,
            ready,
            ready + 7 days,
            keccak256("fixture stage reason"),
            "urn:fixture:activation",
            DEPLOYMENT_HASH
        );
    }

    function _schedule(StreamGovernanceStagePlan.Plan memory p) private returns (bytes32 id) {
        bytes32 hash = StreamGovernanceStagePlan.planHash(p);
        StreamGovernanceStagePlan.NextCall memory call_ =
            StreamGovernanceStagePlan.publication(p, hash);
        (bool ok,) = call_.target.call(call_.data);
        require(ok, "exact calldata published");
        call_ = StreamGovernanceStagePlan.scheduling(p, hash);
        require(call_.caller == address(governorSafe), "actual threshold root");
        vm.recordLogs();
        require(
            executeSafe(governorSafe, governorKeys, call_.target, 0, call_.data, 0),
            "Safe schedules saved plan"
        );
        Vm.Log[] memory logs = vm.getRecordedLogs();
        bytes32 topic = keccak256(
            "GovernanceActionScheduled(uint16,bytes32,uint8,address,uint256,bytes4,bytes32,bytes32,bytes32,bytes32,uint64,uint64,uint256,address,bytes32,string,bytes32)"
        );
        for (uint256 i; i < logs.length; ++i) {
            if (
                logs[i].emitter == address(executor) && logs[i].topics.length == 4
                    && logs[i].topics[0] == topic
            ) {
                require(id == 0, "one original action event");
                id = logs[i].topics[1];
            }
        }
        require(
            StreamGovernanceStagePlan.verifyAction(p, id, hash) == GovernanceActionStatus.SCHEDULED,
            "saved plan matches actual Safe action"
        );
    }

    function _run(GenesisBatch memory batch) private {
        StreamGovernanceStagePlan.Plan memory p = _plan(batch);
        bytes32 id = _schedule(p);
        (bool early,) = address(executor)
            .call(
                abi.encodeCall(executor.executeGovernanceBatch, (id, batch.calls, batch.callDatas))
            );
        require(!early, "real delay enforced");
        vm.warp(p.notBefore);
        require(
            StreamGovernanceStagePlan.execute(p, id, StreamGovernanceStagePlan.planHash(p)),
            "actual stage executed"
        );
        require(
            !StreamGovernanceStagePlan.execute(p, id, StreamGovernanceStagePlan.planHash(p)),
            "completed saved action no-op"
        );
    }

    function _extend() private {
        StreamGovernanceCatalogStagePlan.Inventory memory inventory =
            StreamFullV1ActivationPolicies.catalogInventory(_context(), _knownPolicies());
        bytes32 hash = StreamGovernanceCatalogStagePlan.inventoryHash(inventory);
        uint256 offset;
        while (offset < inventory.additions.length) {
            StreamFullV1ActivationPlan.Publication memory pub = _publication();
            (GenesisBatch memory batch, uint256 next) = StreamGovernanceCatalogStagePlan.nextBatch(
                inventory, hash, offset, manifest, pub.payload, pub.update
            );
            require(
                batch.actionClass == 3 && batch.calls.length == 2
                    && batch.calls[1].target == address(manifest),
                "exact catalog tail"
            );
            _run(batch);
            offset = next;
        }
    }

    function _register() private {
        while (StreamFullV1ActivationPlan.pendingRegistrations(_context(), _inputs()).length != 0) {
            GenesisBatch memory batch = StreamFullV1ActivationPlan.registrationBatch(
                _context(), _inputs(), 7, _publication()
            );
            require(
                batch.calls[batch.calls.length - 1].target == address(manifest),
                "original manifest tail"
            );
            _run(batch);
        }
    }

    /// @dev Exact matching rows already installed by this fixture's initial batches, its
    /// 74 operating policies and the four explicit additional policies above. Not a live lookup.
    function _knownPolicies() private view returns (GovernanceActionPolicyEntry[] memory out) {
        GovernanceActionPolicyEntry[] memory wanted =
            StreamFullV1ActivationPolicies.desired(_context());
        uint256 n;
        for (uint256 i; i < wanted.length; ++i) {
            GovernanceActionPolicyEntry memory r = wanted[i];
            bool known = r.target == address(manifest) || r.target == address(executor)
                || r.target == address(registry) || r.target == address(revenueEscrow)
                || r.target == address(assemblySchemas) || r.target == address(assemblyMetadata)
                || r.target == address(entropy)
                || (r.target == address(ledger) && r.selector == ledger.setLedgerWriter.selector);
            if (known) wanted[n++] = r;
        }
        out = new GovernanceActionPolicyEntry[](n);
        for (uint256 i; i < n; ++i) {
            out[i] = wanted[i];
        }
    }

    function _fixturePolicy(address target, bytes4 selector)
        private
        view
        returns (GovernanceActionPolicyEntry memory)
    {
        return GovernanceActionPolicyEntry(
            1,
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

    function executePlan(StreamGovernanceStagePlan.Plan memory p, bytes32 id) external {
        StreamGovernanceStagePlan.execute(p, id, StreamGovernanceStagePlan.planHash(p));
    }

    function planManager(bool reserve) external view {
        StreamFullV1ActivationPlan.managerBinding(_context(), reserve);
    }

    function planCustody() external view {
        StreamFullV1ActivationPlan.custodyBinding(_context());
    }

    function planProvider(uint8 index) external view {
        StreamFullV1ActivationPlan.providerActivation(_context(), index, "urn:fixture:provider");
    }

    function planCollection(StreamEntropyFallbackPlan.Collection memory row) external view {
        StreamFullV1ActivationPlan.collectionConfiguration(_context(), 2, row);
    }

    function pending(StreamFullV1ActivationPlan.RegistrationInputs memory r) external view {
        StreamFullV1ActivationPlan.pendingRegistrations(_context(), r);
    }

    function additions(GovernanceActionPolicyEntry[] memory known) external view {
        StreamFullV1ActivationPolicies.additions(_context(), known);
    }

    function validateContext(StreamFullV1ActivationPlan.Context memory x) external view {
        StreamFullV1ActivationPlan.validate(x);
    }

    function appendClassifierTail(
        GenesisBatch memory batch,
        StreamFullV1ActivationPlan.Publication memory pub
    ) external view {
        StreamFullV1ActivationPlan.withManifestTail(_context(), batch, pub);
    }

    function planDocument(IStreamSchemaRegistry.DocumentSpec memory spec, bytes32[] memory chunks)
        external
        view
    {
        StreamFullV1ActivationPlan.schemaDocument(_context(), spec, chunks);
    }

    function planStatic(Versions.Registration memory registration, Versions.Read[] memory reads)
        external
        view
    {
        StreamFullV1ActivationPlan.staticAdmission(_context(), registration, reads);
    }

    function planReveal(StreamEntropyFallbackPlan.Collection memory row, address administrator)
        external
        view
    {
        StreamFullV1ActivationPlan.revealConfiguration(_context(), 2, row, administrator);
    }
}
