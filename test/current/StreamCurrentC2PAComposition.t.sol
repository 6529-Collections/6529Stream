// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../helpers/StreamCurrentSafeGovernanceFixture.sol";
import { StreamC2PAStaticReadPlan } from "../../script/current/StreamC2PAStaticReadPlan.sol";
import { StreamFullV1C2PAProducts } from "../../script/current/StreamFullV1C2PAProducts.sol";
import {
    StreamStaticRenderEncoding
} from "../../smart-contracts/domains/metadata/StreamStaticRenderEncoding.sol";
import {
    StreamArtistStaticDisplay
} from "../../smart-contracts/domains/artist/StreamArtistStaticDisplay.sol";
import {
    IStreamArtistStaticFacts
} from "../../smart-contracts/interfaces/stream/artist/IStreamArtistStaticFacts.sol";
import {
    StreamMetadataSubjects
} from "../../smart-contracts/domains/metadata/StreamMetadataSubjects.sol";
import {
    IStreamRenderer as Render
} from "../../smart-contracts/interfaces/stream/metadata/IStreamRenderer.sol";
import {
    IStreamC2PAReconciliation as Report
} from "../../smart-contracts/interfaces/stream/metadata/IStreamC2PAReconciliation.sol";
import {
    StreamArtistC2PATypes as Credential,
    IStreamArtistC2PAReads
} from "../../smart-contracts/interfaces/stream/artist/IStreamArtistC2PA.sol";
import {
    IStreamArtistIdentityRevisionReads
} from "../../smart-contracts/interfaces/stream/artist/IStreamArtistIdentityRevision.sol";
import {
    IStreamArtistAttributionOwner
} from "../../smart-contracts/interfaces/stream/artist/IStreamArtistAttributionOwner.sol";
import {
    IStreamArtistAcceptanceOwner
} from "../../smart-contracts/interfaces/stream/artist/IStreamArtistAcceptanceOwner.sol";
import {
    IStreamArtistCollaboratorRecordsOwner
} from "../../smart-contracts/interfaces/stream/artist/IStreamArtistCollaboratorRecordsOwner.sol";
import {
    IStreamArtistNativeReceipts
} from "../../smart-contracts/interfaces/stream/artist/IStreamArtistHistory.sol";
import {
    IStreamC2PAConflicts as Conflict,
    IStreamStaticC2PAConflicts
} from "../../smart-contracts/interfaces/stream/metadata/IStreamC2PAConflicts.sol";

interface CurrentC2PACompositionVm {
    function expectCall(address target, bytes calldata data, uint64 count) external;
}

/// @notice Original current graph, original op24 and actual threshold Artist/verifier Safes.
/// @dev Only inherited upstream entropy is a service double. Construction, credential history
/// and source inventories are not complete STATIC admission, actual verifier report adoption,
/// finalized C2PA output, deployment-size acceptance or evidence of executed native tests.
contract StreamCurrentC2PACompositionTest is StreamCurrentSafeGovernanceFixture {
    StreamFullV1C2PAProducts.Configuration private configuration;
    StreamFullV1C2PAProducts.Products private products;
    OfficialSafe private artistSafe;
    OfficialSafe private verifierSafe;
    uint256[] private keys;

    function setUp() public {
        keys.push(0xC2FA01);
        keys.push(0xC2FA02);
        SafeComponents memory components = deploySafeComponents("1.4.1");
        artistSafe = createOfficialSafe(components, safeOwnerAddresses(keys), 2, 3824);
        verifierSafe = createOfficialSafe(components, safeOwnerAddresses(keys), 2, 3825);
        OfficialSafe governor = createOfficialSafe(components, safeOwnerAddresses(keys), 2, 3826);
        _deployCurrentStack(address(artistSafe), vm.addr(PLATFORM_KEY));
        _installGovernorSafe(governor, keys);
        configuration.base.core = address(core);
        configuration.base.executor = address(executor);
        configuration.base.router = address(router);
        configuration.base.metadata = address(assemblyMetadata);
        configuration.base.schemas = address(assemblySchemas);
        configuration.base.entropy = address(entropy);
        configuration.base.artist = address(artists);
        configuration.base.finality = address(assemblyFinality);
        configuration.base.deploymentHash = DEPLOYMENT_HASH;
        configuration.base.rendererManifest = Render.RendererManifest(
            keccak256("6529STREAM_RENDERER_V1"),
            keccak256("6529STREAM_STATIC_RENDERER_V1"),
            keccak256("STREAM_CONTEXT_V1"),
            keccak256("STATIC"),
            keccak256("synthetic unregistered C2PA renderer schema"),
            "urn:fixture:c2pa-schema",
            "urn:fixture:c2pa-manifest",
            keccak256("synthetic unregistered C2PA renderer manifest"),
            16777216,
            16777216,
            false
        );
        configuration.base.readGas = IStreamGasParameterHost.GasParameterConfig(
            "METADATA_DEPENDENCY_READ_GAS", 2000000, 100000, 2
        );
        configuration.base.attributionGas = IStreamGasParameterHost.GasParameterConfig(
            "STATIC_ATTRIBUTION_GAS", 8000000, 8000000, 1
        );
        configuration.verifier = address(verifierSafe);
        configuration.reconciliationGas = IStreamGasParameterHost.GasParameterConfig(
            "C2PA_DEPENDENCY_READ_GAS", 1000000, 100000, 2
        );
        // Nested budgets leave the wrapper enough gas to enter the original artist frame.
        // These are fixture values, not measured launch gas acceptance.
        configuration.wrapperArtistGas = IStreamGasParameterHost.GasParameterConfig(
            "C2PA_STATIC_ARTIST_GAS", 6000000, 100000, 2
        );
        configuration.wrapperReportGas = IStreamGasParameterHost.GasParameterConfig(
            "C2PA_STATIC_REPORT_GAS", 2000000, 100000, 2
        );
        products = StreamFullV1C2PAProducts.deploy(configuration);
    }

    function _artistProof(bytes32 digest) internal override returns (bytes memory) {
        return safeThresholdSignature(keys, safeMessageDigest(artistSafe, abi.encode(digest)));
    }

    function testOriginalCurrentGraphAndMatchingNewRendererEncodingBindings() public view {
        StreamFullV1C2PAProducts.validate(configuration, products);
        require(
            products.reconciliation.verifier() == address(verifierSafe),
            "explicit actual Safe verifier"
        );
        require(
            products.artistTargets[0] == address(artistCoordinator)
                && products.artistTargets[1] == artistSuite.owners[2]
                && products.artistTargets[2] == artistSuite.owners[0]
                && products.artistTargets[3] == artistSuite.owners[4],
            "fixed original Artist owners"
        );
        require(
            products.renderer.c2paAttributionEnabled() && products.renderer.c2paConflictsEnabled()
                && products.wrapper.supportsInterface(type(IStreamStaticC2PAConflicts).interfaceId),
            "new Renderer opted into report and standing-conflict wrapper"
        );
        (address encoding, bytes32 hash) = products.renderer.encodingBinding();
        require(
            encoding == address(StreamStaticRenderEncoding) && hash == products.codeHashes[4],
            "matching new Prepared encoding ABI"
        );
        require(
            products.original.artist() == address(artists)
                && products.original.originalFinality() == address(assemblyFinality),
            "original attribution preserved"
        );
    }

    function testOnlyOriginalRendererModuleAndExactOptionalHostPoliciesAreProposed() public view {
        StreamModuleRegistration memory row =
            StreamFullV1C2PAProducts.rendererRegistration(configuration, products, 500000);
        require(
            row.module == address(products.renderer) && row.moduleType == keccak256("RENDERER")
                && row.expectedRuntimeCodeHash == products.codeHashes[3]
                && row.deploymentManifestHash == DEPLOYMENT_HASH,
            "genuine original Renderer registration"
        );
        GovernanceActionPolicyEntry[] memory policies =
            StreamFullV1C2PAProducts.operatingPolicies(configuration, products);
        address[3] memory hosts = [
            address(products.reconciliation), address(products.wrapper), address(products.renderer)
        ];
        require(policies.length == hosts.length, "three explicit optional GGP hosts");
        for (uint256 i; i < policies.length; ++i) {
            require(
                policies[i].target == hosts[i]
                    && policies[i].selector == IStreamGasParameterHost.raiseGasParameter.selector
                    && policies[i].targetCodeHash == hosts[i].codehash
                    && policies[i].actionClass == 1,
                "exact original delayed GGP policy"
            );
        }
    }

    function testAbsentReportPreservesOriginalAttributionAndIsUnevaluated() public view {
        bytes memory original = products.original.attribution(1, 0);
        (bytes memory actual, Report.Display memory display_, bytes32 subject) =
            products.wrapper.attributionWithC2PA(1, 0);
        require(
            original.length != 0 && keccak256(actual) == keccak256(original),
            "same complete original AA bytes"
        );
        bytes32 expected = StreamMetadataSubjects.scopeSubject(
            block.chainid,
            address(core),
            StreamFinalityScope(StreamFinalityScopeType.COLLECTION, 1, 0, 0)
        );
        require(
            subject == expected && display_.recordHash == 0 && display_.selectionHash == 0
                && display_.validation == Report.ValidationStatus.UNEVALUATED
                && display_.authorship == Report.AuthorshipStatus.UNEVALUATED && !display_.current
                && !display_.assertsAuthorship,
            "absence is explicit, not validator success"
        );
    }

    function testEmptyConflictReadsKeepExactTuplesAndReadBothOriginalScopes() public {
        bytes32 collectionSubject = StreamMetadataSubjects.scopeSubject(
            block.chainid,
            address(core),
            StreamFinalityScope(StreamFinalityScopeType.COLLECTION, 1, 0, 0)
        );
        bytes32 tokenSubject = StreamMetadataSubjects.scopeSubject(
            block.chainid,
            address(core),
            StreamFinalityScope(StreamFinalityScopeType.TOKEN, 1, 42, 0)
        );
        // This is an absent-evidence read, not an assertion that token 42 exists.
        Conflict.Standing memory empty;
        (bool ok, bytes memory raw) = address(products.reconciliation)
            .staticcall(abi.encodeCall(Conflict.standingConflict, (uint256(1), collectionSubject)));
        require(
            ok && raw.length == 192 && keccak256(raw) == keccak256(abi.encode(empty)),
            "original local zero Standing ABI"
        );
        (ok, raw) = address(products.reconciliation)
            .staticcall(abi.encodeCall(Report.display, (uint256(1), collectionSubject)));
        Report.Display memory emptyDisplay;
        require(
            ok && raw.length == 192 && keccak256(raw) == keccak256(abi.encode(emptyDisplay)),
            "original Display ABI unchanged"
        );
        CurrentC2PACompositionVm calls = CurrentC2PACompositionVm(address(vm));
        calls.expectCall(
            address(products.reconciliation),
            abi.encodeCall(Conflict.standingConflict, (uint256(1), collectionSubject)),
            2
        );
        calls.expectCall(
            address(products.reconciliation),
            abi.encodeCall(Conflict.standingConflict, (uint256(1), tokenSubject)),
            1
        );
        for (uint256 i; i < 2; ++i) {
            (ok, raw) = address(products.wrapper)
                .staticcall(
                    abi.encodeCall(
                        IStreamStaticC2PAConflicts.attributionC2PAConflicts,
                        (uint256(1), i == 0 ? uint256(0) : uint256(42))
                    )
                );
            require(
                ok && raw.length == 384 && keccak256(raw) == keccak256(abi.encode(empty, empty)),
                "canonical token then collection zero tuples"
            );
        }
    }

    function testStandingConflictEdgesCannotBeOmittedOrResealedWithWrongCaps() public {
        address[2] memory targets = [address(products.wrapper), address(products.reconciliation)];
        bytes4[2] memory selectors = [
            IStreamStaticC2PAConflicts.attributionC2PAConflicts.selector,
            Conflict.standingConflict.selector
        ];
        for (uint256 k; k < targets.length; ++k) {
            StreamC2PAStaticReadPlan.Inventory memory inventory = _inventory();
            uint256 index = _index(inventory.reads, targets[k], selectors[k]);
            StreamC2PAStaticReadPlan.Read[] memory short =
                new StreamC2PAStaticReadPlan.Read[](inventory.reads.length - 1);
            uint256 n;
            for (uint256 i; i < inventory.reads.length; ++i) {
                if (i != index) short[n++] = inventory.reads[i];
            }
            inventory.reads = short;
            bytes32 saved = StreamC2PAStaticReadPlan.inventoryHash(inventory);
            vm.expectRevert(
                abi.encodeWithSignature("Error(string)", "missing exact C2PA source edge")
            );
            this.checkInventory(inventory, saved);
            inventory = _inventory();
            index = _index(inventory.reads, targets[k], selectors[k]);
            inventory.reads[index].maximumReturnBytes -= 32;
            saved = StreamC2PAStaticReadPlan.inventoryHash(inventory);
            vm.expectRevert(abi.encodeWithSignature("Error(string)", "original C2PA read bounds"));
            this.checkInventory(inventory, saved);
        }
    }

    function testActualSafeOp24RetainsDirectCredentialHeadHistoricalRecordAndPersonhood() public {
        IStreamArtistC2PAReads source = IStreamArtistC2PAReads(artistSuite.owners[4]);
        bytes32 personhood = source.personhoodAttestation(1, fixtureArtistId).recordHash;
        require(personhood != 0, "original fixture personhood exists");
        vm.recordLogs();
        bytes32 first = _recordCredential(_credentialPayload(0, false));
        Vm.Log[] memory logs = vm.getRecordedLogs();
        bool sawHead;
        bytes32 topic = keccak256(
            "ArtistC2PACredentialsRecorded(uint16,bytes32,bytes32,(uint64,bytes32,bytes32,bytes32,uint256,bytes32,uint64,bytes32,bytes32,address))"
        );
        for (uint256 i; i < logs.length; ++i) {
            if (
                logs[i].emitter == artistSuite.owners[4] && logs[i].topics.length == 3
                    && logs[i].topics[0] == topic
            ) {
                require(
                    logs[i].topics[1] == fixtureArtistId && logs[i].topics[2] == first,
                    "exact credential event identity"
                );
                (uint16 version, Credential.Head memory emitted) =
                    abi.decode(logs[i].data, (uint16, Credential.Head));
                require(
                    version == 1 && emitted.recordHash == first && emitted.revision == 1,
                    "original credential event payload"
                );
                sawHead = true;
            }
        }
        require(sawHead, "original owner event observed");
        Credential.Head memory historical = source.c2paCredentialRecord(first);
        bytes32 second = _recordCredential(_credentialPayload(first, true));
        Credential.Head memory head = source.c2paCredentialHead(fixtureArtistId);
        require(
            head.revision == 2 && head.recordHash == second && head.previousRecordHash == first
                && head.bindingHash == artists.displayBinding(1).bindingHash
                && head.sourceRegistry == address(artists),
            "actual original head advances"
        );
        require(
            keccak256(abi.encode(source.c2paCredentialRecord(first)))
                == keccak256(abi.encode(historical)),
            "historical head immutable"
        );
        require(
            source.personhoodAttestation(1, fixtureArtistId).recordHash == personhood,
            "credentials preserve original personhood"
        );
        bytes memory retained =
            IStreamArtistAttributionOwner(artistSuite.owners[4]).statementBytes(head.statementHash);
        require(
            abi.decode(retained, (Credential.Payload)).credentials.length == 0,
            "explicit withdrawal remains empty"
        );
        (bool ok, bytes memory raw) = artistSuite.owners[4].staticcall(
            abi.encodeCall(IStreamArtistC2PAReads.c2paCredentialHead, (fixtureArtistId))
        );
        require(
            ok && raw.length == 320 && keccak256(raw) == keccak256(abi.encode(head)),
            "direct fixed owner ten-word ABI"
        );
        (ok,) = address(artists)
            .staticcall(
                abi.encodeCall(IStreamArtistC2PAReads.c2paCredentialHead, (fixtureArtistId))
            );
        require(!ok, "no invented facade credential-head forward");
    }

    function testStaleAndMalformedCredentialUpdatesRollBackActualOwnerHistory() public {
        bytes32 first = _recordCredential(_credentialPayload(0, false));
        uint256 receipts =
            IStreamArtistNativeReceipts(artistSuite.owners[4]).artistNativeReceiptCount();
        bytes memory stale = _credentialPayload(0, true);
        vm.expectRevert();
        this.recordCredential(stale);
        bytes memory malformed = bytes.concat(_credentialPayload(first, true), hex"00");
        vm.expectRevert();
        this.recordCredential(malformed);
        require(
            IStreamArtistC2PAReads(artistSuite.owners[4])
                .c2paCredentialHead(fixtureArtistId)
                .recordHash == first
                && IStreamArtistNativeReceipts(artistSuite.owners[4]).artistNativeReceiptCount()
                == receipts,
            "original head and Archive receipts unchanged"
        );
    }

    function testIncrementalRosterPinsDirectOwnerAuditAndNewEncodingEnvelope() public view {
        StreamC2PAStaticReadPlan.Read[] memory rows =
            StreamC2PAStaticReadPlan.delta(configuration, products);
        require(rows.length == 17, "sixteen serving edges and one historical audit edge");
        _requireEdge(
            rows,
            address(products.wrapper),
            IStreamStaticC2PAConflicts.attributionC2PAConflicts.selector,
            384,
            true,
            1
        );
        _requireEdge(
            rows, address(products.reconciliation), Conflict.standingConflict.selector, 192, true, 1
        );
        _requireEdge(
            rows,
            artistSuite.owners[4],
            IStreamArtistC2PAReads.c2paCredentialHead.selector,
            320,
            true,
            1
        );
        _requireEdge(
            rows,
            artistSuite.owners[4],
            IStreamArtistC2PAReads.c2paCredentialRecord.selector,
            320,
            true,
            2
        );
        _requireEdge(
            rows,
            products.artistStaticDisplay,
            StreamArtistStaticDisplay.read.selector,
            704,
            false,
            1
        );
        _requireEdge(
            rows,
            address(products.reconciliation),
            products.reconciliation.requireCurrent.selector,
            0,
            true,
            1
        );
        _requireEdge(
            rows, products.encoding, StreamStaticRenderEncoding.render.selector, 16777280, false, 1
        );
        for (uint256 i; i < rows.length; ++i) {
            require(rows[i].target.codehash == rows[i].runtimeHash, "live retained source runtime");
        }
    }

    function testCompositionRetainsEverySuppliedOriginalAttributionEdge() public view {
        StreamC2PAStaticReadPlan.Read[] memory base = _partialOriginalRoster();
        StreamC2PAStaticReadPlan.Inventory memory inventory = StreamC2PAStaticReadPlan.compose(
            configuration, products, base, keccak256(abi.encode(base))
        );
        require(
            inventory.reads.length == 20
                && inventory.originalAttributionInventoryHash == keccak256(abi.encode(base)),
            "deduplicated original root and all supplied AA owners"
        );
        for (uint256 i; i < base.length; ++i) {
            bool found;
            for (uint256 j; j < inventory.reads.length; ++j) {
                if (keccak256(abi.encode(base[i])) == keccak256(abi.encode(inventory.reads[j]))) {
                    found = true;
                }
            }
            require(found, "supplied original row never dropped");
        }
        StreamC2PAStaticReadPlan.requireUnchanged(
            configuration, products, inventory, StreamC2PAStaticReadPlan.inventoryHash(inventory)
        );
    }

    function testMissingHistoricalOwnerOrChangedReadCapCannotBeResealedAsComplete() public {
        StreamC2PAStaticReadPlan.Inventory memory inventory = _inventory();
        uint256 index = _index(
            inventory.reads,
            artistSuite.owners[4],
            IStreamArtistC2PAReads.c2paCredentialRecord.selector
        );
        StreamC2PAStaticReadPlan.Read[] memory short =
            new StreamC2PAStaticReadPlan.Read[](inventory.reads.length - 1);
        uint256 n;
        for (uint256 i; i < inventory.reads.length; ++i) {
            if (i != index) short[n++] = inventory.reads[i];
        }
        inventory.reads = short;
        bytes32 saved = StreamC2PAStaticReadPlan.inventoryHash(inventory);
        vm.expectRevert(abi.encodeWithSignature("Error(string)", "missing exact C2PA source edge"));
        this.checkInventory(inventory, saved);
        inventory = _inventory();
        index = _index(
            inventory.reads,
            artistSuite.owners[4],
            IStreamArtistC2PAReads.c2paCredentialHead.selector
        );
        inventory.reads[index].maximumReturnBytes = 288;
        saved = StreamC2PAStaticReadPlan.inventoryHash(inventory);
        vm.expectRevert(abi.encodeWithSignature("Error(string)", "original C2PA read bounds"));
        this.checkInventory(inventory, saved);
    }

    function testConflictingOriginalEdgeAndChangedRetainedRosterHashRefuseComposition() public {
        StreamC2PAStaticReadPlan.Read[] memory base = _partialOriginalRoster();
        vm.expectRevert(
            abi.encodeWithSignature("Error(string)", "retained original attribution roster")
        );
        this.compose(base, keccak256("wrong saved original roster"));
        uint256 index =
            _index(base, address(products.original), products.original.attribution.selector);
        base[index].maximumReturnBytes = 32768;
        bytes32 saved = keccak256(abi.encode(base));
        vm.expectRevert(abi.encodeWithSignature("Error(string)", "conflicting original read edge"));
        this.compose(base, saved);
    }

    function testOriginalAttributionOwnerRuntimeDriftRefusesConstructionReadback() public {
        vm.etch(artistSuite.owners[4], hex"00");
        vm.expectRevert(
            abi.encodeWithSignature("Error(string)", "retained C2PA dependency runtime")
        );
        this.validateProducts(configuration, products);
    }

    function testChangedConfigurationAndLinkedEncodingObservationRefuseReuse() public {
        StreamFullV1C2PAProducts.Configuration memory changed = configuration;
        changed.verifier = address(artistSafe);
        vm.expectRevert(abi.encodeWithSignature("Error(string)", "retained C2PA construction"));
        this.validateProducts(changed, products);
        StreamFullV1C2PAProducts.Products memory observed = products;
        observed.codeHashes[4] = keccak256("old encoding runtime");
        vm.expectRevert(
            abi.encodeWithSignature("Error(string)", "retained C2PA dependency runtime")
        );
        this.validateProducts(configuration, observed);
    }

    function _recordCredential(bytes memory payload) private returns (bytes32 record) {
        bytes32 identity = IStreamArtistIdentityRevisionReads(artistSuite.owners[2])
            .operativeIdentityRecord(fixtureArtistId);
        T.Attestation memory terms = T.Attestation(
            1,
            10,
            fixtureArtistId,
            identity,
            keccak256("6529STREAM_ARTIST_C2PA_CREDENTIALS_V1"),
            keccak256(payload),
            "urn:fixture:c2pa-credentials"
        );
        T.Authorization memory authorization = _artistAuthorization(true);
        authorization.signature = _artistProof(artists.attestationDigest(terms, authorization));
        uint256 index =
            IStreamArtistNativeReceipts(artistSuite.owners[4]).artistNativeReceiptCount();
        record = artists.recordArtistAttestation(terms, authorization, payload);
        require(
            IStreamArtistNativeReceipts(artistSuite.owners[4])
                .artistNativeReceiptAt(index)
                .operation == 24,
            "original op24 native receipt"
        );
        bytes32 expected = keccak256(
            abi.encode(
                keccak256("6529STREAM_ARTIST_ATTESTATION_RECORD_V1"),
                block.chainid,
                address(artists),
                address(core),
                uint256(1),
                uint8(10),
                fixtureArtistId,
                identity,
                terms.schemaId,
                terms.statementHash,
                keccak256(bytes(terms.statementURI)),
                fixtureArtistId,
                address(artistSafe),
                uint8(1),
                authorization.nonce,
                authorization.time
            )
        );
        require(record == expected, "independently recomputed original op24 record");
    }

    function _credentialPayload(bytes32 previous, bool empty) private view returns (bytes memory) {
        Credential.Credential[] memory credentials = new Credential.Credential[](empty ? 0 : 1);
        if (!empty) {
            credentials[0] = Credential.Credential(
                1, sha256("fixture SPKI bytes"), keccak256("fixture identity key id"), 1, 0
            );
        }
        return abi.encode(
            Credential.Payload(
                1,
                fixtureArtistId,
                IStreamArtistIdentityRevisionReads(artistSuite.owners[2])
                    .operativeIdentityRecord(fixtureArtistId),
                previous,
                credentials
            )
        );
    }

    /// @dev Four explicit sample AA rows exercise union preservation. This is NOT the
    /// complete original attribution roster or a registration-ready analysis artifact.
    function _partialOriginalRoster()
        private
        view
        returns (StreamC2PAStaticReadPlan.Read[] memory rows)
    {
        rows = new StreamC2PAStaticReadPlan.Read[](4);
        rows[0] = _row(
            address(products.original),
            "METADATA_COMPANION",
            products.original.attribution.selector,
            32832,
            false
        );
        rows[1] = _row(
            artistSuite.owners[1],
            "ARTIST_COLLABORATOR_RECORDS_OWNER",
            IStreamArtistCollaboratorRecordsOwner.acceptedRow.selector,
            64,
            true
        );
        rows[2] = _row(
            artistSuite.owners[3],
            "ARTIST_ACCEPTANCE_OWNER",
            IStreamArtistAcceptanceOwner.acceptanceRecord.selector,
            32,
            true
        );
        rows[3] = _row(
            artistSuite.owners[6],
            "ARTIST_SANCTION_OWNER",
            IStreamArtistStaticFacts.staticSanctionRecord.selector,
            544,
            true
        );
        for (uint256 i = 1; i < rows.length; ++i) {
            for (uint256 j = i; j > 0 && _key(rows[j - 1]) > _key(rows[j]); --j) {
                (rows[j - 1], rows[j]) = (rows[j], rows[j - 1]);
            }
        }
    }

    function _inventory() private view returns (StreamC2PAStaticReadPlan.Inventory memory) {
        StreamC2PAStaticReadPlan.Read[] memory base = _partialOriginalRoster();
        return StreamC2PAStaticReadPlan.compose(
            configuration, products, base, keccak256(abi.encode(base))
        );
    }

    function _row(address target, string memory role, bytes4 selector, uint32 maximum, bool exact)
        private
        view
        returns (StreamC2PAStaticReadPlan.Read memory)
    {
        return StreamC2PAStaticReadPlan.Read(
            target, target.codehash, keccak256(bytes(role)), selector, maximum, exact, 1
        );
    }

    function _key(StreamC2PAStaticReadPlan.Read memory row) private pure returns (bytes32) {
        return keccak256(abi.encode(row.target, row.selector, row.use));
    }

    function _index(StreamC2PAStaticReadPlan.Read[] memory rows, address target, bytes4 selector)
        private
        pure
        returns (uint256)
    {
        for (uint256 i; i < rows.length; ++i) {
            if (rows[i].target == target && rows[i].selector == selector) return i;
        }
        revert("missing fixture edge");
    }

    function _requireEdge(
        StreamC2PAStaticReadPlan.Read[] memory rows,
        address target,
        bytes4 selector,
        uint32 maximum,
        bool exact,
        uint8 use
    ) private pure {
        StreamC2PAStaticReadPlan.Read memory row = rows[_index(rows, target, selector)];
        require(
            row.maximumReturnBytes == maximum && row.exact == exact && row.use == use,
            "exact observed call edge"
        );
    }

    function recordCredential(bytes calldata payload) external returns (bytes32) {
        require(msg.sender == address(this));
        return _recordCredential(payload);
    }

    function validateProducts(
        StreamFullV1C2PAProducts.Configuration memory c,
        StreamFullV1C2PAProducts.Products memory p
    ) external view {
        StreamFullV1C2PAProducts.validate(c, p);
    }

    function compose(StreamC2PAStaticReadPlan.Read[] memory rows, bytes32 saved) external view {
        StreamC2PAStaticReadPlan.compose(configuration, products, rows, saved);
    }

    function checkInventory(StreamC2PAStaticReadPlan.Inventory memory inventory, bytes32 saved)
        external
        view
    {
        StreamC2PAStaticReadPlan.requireUnchanged(configuration, products, inventory, saved);
    }
}
