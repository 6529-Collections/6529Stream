// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./CurrentStaticTokenRenderingFixture.sol";
import { StreamFullV1C2PAProducts } from "../../script/current/StreamFullV1C2PAProducts.sol";
import {
    IStreamC2PAReconciliation as CR
} from "../../smart-contracts/interfaces/stream/metadata/IStreamC2PAReconciliation.sol";
import {
    IStreamC2PAConflicts as CF
} from "../../smart-contracts/interfaces/stream/metadata/IStreamC2PAConflicts.sol";
import {
    StreamArtistC2PATypes as Credentials,
    IStreamArtistC2PAReads
} from "../../smart-contracts/interfaces/stream/artist/IStreamArtistC2PA.sol";
import {
    StreamCollectionManifestTypes as Media
} from "../../smart-contracts/interfaces/stream/metadata/StreamCollectionManifestTypes.sol";
import {
    IStreamPreservationRecords as Records
} from "../../smart-contracts/interfaces/stream/preservation/IStreamPreservationRecords.sol";
import {
    StreamArtistAttributionDisputeTypes as Dispute,
    IStreamArtistAttributionDisputes
} from "../../smart-contracts/interfaces/stream/artist/IStreamArtistAttributionDisputes.sol";
import {
    IStreamCollectionArchivalCoverage
} from "../../smart-contracts/interfaces/stream/preservation/IStreamCollectionArchivalCoverage.sol";

/// @notice Actual current Artist/verifier/Metadata/adoption/rendering composition.
/// @dev Admission documents and selected-verifier observations are explicit synthetic evidence.
/// No cryptographic engine, accepted transitive STATIC profile or native execution is claimed.
abstract contract CurrentC2PATokenLifecycleFixture is CurrentStaticTokenRenderingFixture {
    using Strings for uint256;
    StreamFullV1C2PAProducts.Configuration internal c2paConfiguration;
    StreamFullV1C2PAProducts.Products internal c2pa;
    StreamRendererRegistryModule internal c2paVersions;
    Versions.Registration internal c2paRegistration;
    Versions.Read[] internal c2paReads;
    OfficialSafe internal verifierSafe;
    bytes32 internal credential;
    bytes32 internal credentialStatement;
    bytes32 internal mediaManifest;
    bytes32 internal tokenSubject;
    bytes32 internal collectionSubject;
    bytes32 internal seed;
    uint64 internal recordCount;
    bytes32 internal recordChain;
    uint64 internal reportSequence;
    uint256 internal archiveNonce;
    bytes32 internal archiveFamilyOne;
    bytes32 internal archiveFamilyTwo;
    bytes32 internal constant C2PA_FAMILY = keccak256("6529STREAM_RECORD_FAMILY_C2PA_V1");
    bytes32 internal constant C2PA_SCHEMA = keccak256("6529STREAM_C2PA_RECONCILIATION_REPORT_V1");
    bytes32 internal constant KEY_ID = keccak256("actual token Artist test key id");
    bytes32 internal constant SPKI = sha256("explicit synthetic selected-verifier SPKI bytes");
    bytes32 internal constant MEDIA_HASH = keccak256("explicit retained fixture media bytes");

    function _constructC2PAToken() internal {
        _constructStaticTokenRendering();
        SafeComponents memory components = deploySafeComponents("1.4.1");
        verifierSafe = createOfficialSafe(components, safeOwnerAddresses(keys), 2, 0xC2FA);
        c2paConfiguration.base = configuration;
        c2paConfiguration.verifier = address(verifierSafe);
        c2paConfiguration.reconciliationGas = IStreamGasParameterHost.GasParameterConfig(
            "C2PA_DEPENDENCY_READ_GAS", 1000000, 100000, 2
        );
        c2paConfiguration.wrapperArtistGas = IStreamGasParameterHost.GasParameterConfig(
            "C2PA_STATIC_ARTIST_GAS", 6000000, 100000, 2
        );
        c2paConfiguration.wrapperReportGas = IStreamGasParameterHost.GasParameterConfig(
            "C2PA_STATIC_REPORT_GAS", 2000000, 100000, 2
        );
        c2pa = StreamFullV1C2PAProducts.deploy(c2paConfiguration);
        address[6] memory products = StreamFullV1C2PAProducts.addresses(c2pa);
        for (uint256 i; i < products.length; ++i) {
            require(products[i].code.length <= 24_576, "original C2PA product runtime limit");
        }
        c2paVersions = new StreamRendererRegistryModule(
            StreamRendererRegistryModule.Deployment(
                address(executor),
                address(assemblySchemas),
                _c2paTargets(),
                configuration.readGas,
                configuration.goldenGas,
                DEPLOYMENT_HASH,
                "urn:fixture:c2pa-token-registry",
                keccak256("C2PA token registry fixture")
            )
        );
        require(address(c2paVersions).code.length <= 24_576, "original Registry runtime limit");
        _c2paPolicies();
        _c2paModules();
        _c2paAdmission();
        _document(
            "6529STREAM_C2PA_RECONCILIATION_REPORT_V1",
            Schema.DocumentKind.SCHEMA,
            bytes(vm.readFile("schemas/records/6529STREAM_C2PA_RECONCILIATION_REPORT_V1.json"))
        );
        (bytes32 scope, bytes32 previous, bytes32 next) =
            assemblyMetadata.recordTypeTransition(keccak256("C2PA_VALIDATION"), C2PA_FAMILY, 0x150);
        bytes memory data = abi.encodeCall(
            assemblyMetadata.admitRecordType,
            (keccak256("C2PA_VALIDATION"), C2PA_FAMILY, uint16(0x150))
        );
        _executeStage(
            _single(
                StreamCurrentStackPlan.call(address(assemblyMetadata), data, scope, previous, next),
                data
            ),
            keccak256("actual C2PA record policy")
        );
        _verifierGrant(verifierSafe, 6, true);
        _selectC2PARenderer();
        _selectC2PAMedia();
        credential = _credentials(false);
        _mintToken();
        seed = _revealToken();
        tokenSubject = keccak256(
            abi.encode(
                keccak256("6529STREAM_SUBJECT_TOKEN_V1"), block.chainid, address(core), uint256(1)
            )
        );
        collectionSubject = keccak256(
            abi.encode(
                keccak256("6529STREAM_SUBJECT_COLLECTION_V1"),
                block.chainid,
                address(core),
                uint256(2)
            )
        );
        require(
            assemblyMetadata.registerTokenSubject(1) == tokenSubject,
            "literal original token subject"
        );
        _admitTokenCitation(
            c2paVersions,
            c2pa.renderer,
            c2paReads,
            _c2paTargets(),
            _tokenCitationRequest(seed, true),
            _c2paContext()
        );
    }

    function _c2paTargets() internal view returns (Versions.Target[] memory targets) {
        targets = new Versions.Target[](8);
        Versions.Target[] memory original = _targets();
        for (uint256 i; i < original.length; ++i) {
            targets[i] = original[i];
            if (targets[i].target == address(rendering.attribution)) {
                targets[i] = Versions.Target(
                    address(c2pa.original),
                    address(c2pa.original).codehash,
                    keccak256("METADATA_COMPANION")
                );
            }
        }
        targets[6] = Versions.Target(
            address(c2pa.wrapper),
            address(c2pa.wrapper).codehash,
            keccak256("STATIC_C2PA_ATTRIBUTION")
        );
        targets[7] = Versions.Target(
            address(c2pa.reconciliation),
            address(c2pa.reconciliation).codehash,
            keccak256("C2PA_RECONCILIATION")
        );
        for (uint256 i = 1; i < targets.length; ++i) {
            for (uint256 j = i; j > 0 && targets[j - 1].target > targets[j].target; --j) {
                (targets[j - 1], targets[j]) = (targets[j], targets[j - 1]);
            }
        }
    }

    function _c2paPolicies() internal {
        GovernanceActionPolicyEntry[] memory rows = new GovernanceActionPolicyEntry[](4);
        rows[0] = _policy(address(c2paVersions), c2paVersions.registerRenderer.selector);
        rows[1] = _policy(address(assemblyMetadata), assemblyMetadata.admitRecordType.selector);
        rows[2] =
            _policy(address(artistArchivalCoverage), artistArchivalCoverage.admitFamily.selector);
        rows[3] = _policy(
            address(artists), IStreamArtistAttributionDisputes.resolveAttributionDispute.selector
        );
        for (uint256 i = 1; i < rows.length; ++i) {
            for (uint256 j = i; j > 0 && _key(rows[j - 1]) > _key(rows[j]); --j) {
                (rows[j - 1], rows[j]) = (rows[j], rows[j - 1]);
            }
        }
        StreamGovernanceCatalogStagePlan.Inventory memory inventory =
            StreamGovernanceCatalogStagePlan.inventory(executor, rows);
        (address payload, StreamSystemManifestUpdate memory update) =
            _publication("actual C2PA token policies");
        (GenesisBatch memory batch, uint256 count) = StreamGovernanceCatalogStagePlan.nextBatch(
            inventory,
            StreamGovernanceCatalogStagePlan.inventoryHash(inventory),
            0,
            manifest,
            payload,
            update
        );
        _executeStage(batch, keccak256("C2PA token policy extension"));
        require(count == rows.length, "complete C2PA original policies");
    }

    function _c2paModules() internal {
        StreamModuleRegistration[] memory rows = new StreamModuleRegistration[](2);
        rows[0] = StreamFullV1C2PAProducts.rendererRegistration(c2paConfiguration, c2pa, 500000);
        rows[1] = StreamFullV1StaticRendererPlan.registrations(configuration, rendering, 500000)[1];
        rows[1].module = address(c2paVersions);
        rows[1].expectedRuntimeCodeHash = address(c2paVersions).codehash;
        rows[1].moduleManifestHash = keccak256("C2PA token registry fixture");
        rows[1].moduleManifestURI = "urn:fixture:c2pa-token-registry";
        (GovernanceCall[] memory ops, bytes[] memory datas) =
            StreamCurrentStackPlan.registrationCalls(registry, rows);
        GenesisBatch memory batch;
        batch.actionClass = 1;
        batch.calls = new GovernanceCall[](3);
        batch.callDatas = new bytes[](3);
        for (uint256 i; i < 2; ++i) {
            batch.calls[i] = ops[i];
            batch.callDatas[i] = datas[i];
        }
        (address payload, StreamSystemManifestUpdate memory update) =
            _publication("actual C2PA module rows");
        (batch.calls[2], batch.callDatas[2]) = StreamGenesisManifestPlan.publicationCall(
            manifest, payload, update, StreamGenesisManifestPlan.readAggregate(manifest).modules
        );
        _executeStage(batch, keccak256("C2PA token module admission"));
    }

    function _c2paAdmission() internal {
        Versions.Target[] memory targets = _c2paTargets();
        for (uint16 i; i < targets.length; ++i) {
            address target = targets[i].target;
            if (target == address(core)) {
                c2paReads.push(Versions.Read(i, IStreamCoreMint.tokenData.selector, 16448, false));
            } else if (target == address(assemblyMetadata)) {
                c2paReads.push(
                    Versions.Read(i, StaticSource.staticScriptManifest.selector, 9504, false)
                );
            } else if (target == address(router)) {
                c2paReads.push(
                    Versions.Read(
                        i, StaticRouter.staticRenderSourceForConfig.selector, 20736, false
                    )
                );
            } else if (target == address(entropy)) {
                c2paReads.push(
                    Versions.Read(
                        i, IStreamStaticEntropySource.staticTokenRenderFacts.selector, 96, true
                    )
                );
            } else if (target == address(c2pa.original)) {
                c2paReads.push(Versions.Read(i, c2pa.original.attribution.selector, 32832, false));
            } else if (target == address(c2pa.wrapper)) {
                c2paReads.push(
                    Versions.Read(i, c2pa.wrapper.attributionWithC2PA.selector, 33120, false)
                );
            } else if (target == address(c2pa.reconciliation)) {
                c2paReads.push(Versions.Read(i, c2pa.reconciliation.display.selector, 192, true));
            } else {
                c2paReads.push(
                    Versions.Read(i, StreamStaticRenderEncoding.render.selector, 16777216, false)
                );
            }
        }
        c2paRegistration.renderer = address(c2pa.renderer);
        c2paRegistration.manifest = configuration.rendererManifest;
        c2paRegistration.schemaDocument = registration.schemaDocument;
        c2paRegistration.contextDocument = registration.contextDocument;
        c2paRegistration.manifestDocument = registration.manifestDocument;
        Versions.Analysis memory analysis = Versions.Analysis(
            keccak256("6529STREAM_STATIC_RENDERER_ANALYSIS_ABI_V1"),
            address(c2pa.renderer),
            address(c2pa.renderer).codehash,
            keccak256(
                abi.encode(
                    keccak256("6529STREAM_RENDERER_READ_SET_V1"),
                    keccak256(abi.encode(targets)),
                    c2paReads
                )
            ),
            configuration.rendererManifest.rendererVersion,
            configuration.rendererManifest.contextVersion,
            configuration.rendererManifest.schemaHash,
            keccak256("SYNTHETIC FIXTURE: no analysis executed"),
            keccak256("SYNTHETIC FIXTURE: partial C2PA direct rows only"),
            true
        );
        c2paRegistration.analysisDocument = _document(
            "C2PA_TOKEN_PARTIAL_ANALYSIS_FIXTURE", Schema.DocumentKind.CATALOG, abi.encode(analysis)
        );
        Versions.GoldenVector[] memory vectors = new Versions.GoldenVector[](1);
        vectors[0].request.core = address(core);
        vectors[0].request.mode = Render.MetadataMode.ONCHAIN;
        vectors[0].outputHash = keccak256(bytes(c2pa.renderer.tokenURI(vectors[0].request)));
        c2paRegistration.goldenDocument = _document(
            "C2PA_TOKEN_EMPTY_GOLDEN_FIXTURE", Schema.DocumentKind.CATALOG, abi.encode(vectors)
        );
        (bytes32 scope, bytes32 previous, bytes32 next) =
            c2paVersions.registrationTransition(c2paRegistration, c2paReads);
        bytes memory data =
            abi.encodeCall(c2paVersions.registerRenderer, (c2paRegistration, c2paReads));
        _executeStage(
            _single(
                StreamCurrentStackPlan.call(address(c2paVersions), data, scope, previous, next),
                data
            ),
            keccak256("actual C2PA renderer admitted")
        );
    }

    function _selectC2PARenderer() internal {
        StaticRouter.ConfigInput memory input = _input();
        input.registry = address(c2paVersions);
        input.config.renderer = address(c2pa.renderer);
        _contentConsent(
            keccak256("RENDERER_CONFIG"), router.previewStaticMetadataConfig(2, 0, input)
        );
        _tokenSafe(
            governor,
            address(router),
            0,
            abi.encodeCall(router.setCollectionMetadataConfig, (uint256(2), input))
        );
        initialRecord = router.collectionMetadataConfig(2);
        require(
            initialRecord.selection.renderer == address(c2pa.renderer)
                && initialRecord.selection.registry == address(c2paVersions)
                && initialRecord.collectionId == 2 && initialRecord.tokenId == 0
                && initialRecord.revision == 2 && initialRecord.defaultRevision == 1
                && initialRecord.level == 1,
            "original explicit C2PA collection override"
        );
    }

    function _contentConsent(bytes32 family, bytes32 state) internal {
        Content.Consent memory consent = Content.Consent(2, address(router), family, state);
        _tokenSafe(
            tokenArtist,
            address(artists),
            0,
            abi.encodeCall(
                IStreamArtistContentAuthority.recordContentConsent,
                (consent, _tokenArtistAuth(false))
            )
        );
    }

    function _selectC2PAMedia() internal {
        Media.MediaManifest memory m;
        m.imageSourceType = Media.PayloadSourceType.IPFS;
        m.imageURI = "ipfs://static-image";
        m.imageHash = MEDIA_HASH;
        m.imageMimeType = "image/png";
        _contentConsent(keccak256("MEDIA_MANIFEST"), router.previewArtistMediaManifestState(2, m));
        _governToken(
            address(router), abi.encodeCall(router.setCollectionMediaManifest, (uint256(2), m))
        );
        Media.Selection memory selected = router.selectedCollectionManifest(2, 3);
        require(
            selected.host == address(assemblyMetadata)
                && selected.codeHash == address(assemblyMetadata).codehash
                && selected.manifestHash != 0,
            "original selected media source"
        );
        mediaManifest = keccak256(
            abi.encode(
                keccak256("6529STREAM_CURRENT_MEDIA_MANIFEST_V1"),
                block.chainid,
                address(core),
                address(assemblyMetadata),
                address(router),
                address(router).codehash,
                uint256(2),
                keccak256(abi.encode("ipfs://static-image", "")),
                m
            )
        );
        require(
            selected.manifestHash == mediaManifest, "independent exact media manifest commitment"
        );
    }

    function _credentials(bool empty) internal returns (bytes32 record) {
        Credentials.Head memory prior =
            IStreamArtistC2PAReads(artistSuite.owners[4]).c2paCredentialHead(tokenArtistId);
        Credentials.Credential[] memory rows = new Credentials.Credential[](empty ? 0 : 1);
        if (!empty) rows[0] = Credentials.Credential(1, SPKI, KEY_ID, 1, 0);
        T.Binding memory binding_ = IStreamArtistBindingOwner(artistSuite.owners[0]).binding(2);
        bytes memory statement = abi.encode(
            Credentials.Payload(
                1, tokenArtistId, binding_.identityRecordHash, prior.recordHash, rows
            )
        );
        T.Attestation memory p = T.Attestation(
            2,
            10,
            tokenArtistId,
            binding_.identityRecordHash,
            keccak256("6529STREAM_ARTIST_C2PA_CREDENTIALS_V1"),
            keccak256(statement),
            "urn:fixture:c2pa-token-credentials"
        );
        bytes32 personhood =
            IStreamArtistC2PAReads(artistSuite.owners[4])
        .personhoodAttestation(2, tokenArtistId)
        .recordHash;
        T.Authorization memory auth = _tokenArtistAuth(true);
        bytes32 expected = keccak256(
            abi.encode(
                keccak256("6529STREAM_ARTIST_ATTESTATION_RECORD_V1"),
                block.chainid,
                address(artists),
                address(core),
                uint256(2),
                uint8(10),
                tokenArtistId,
                binding_.identityRecordHash,
                p.schemaId,
                keccak256(statement),
                keccak256(bytes(p.statementURI)),
                tokenArtistId,
                address(tokenArtist),
                uint8(1),
                auth.nonce,
                auth.time
            )
        );
        _tokenSafe(
            tokenArtist,
            address(artists),
            0,
            abi.encodeCall(artists.recordArtistAttestation, (p, auth, statement))
        );
        Credentials.Head memory head =
            IStreamArtistC2PAReads(artistSuite.owners[4]).c2paCredentialHead(tokenArtistId);
        require(
            head.revision == prior.revision + 1 && head.previousRecordHash == prior.recordHash
                && head.artistId == tokenArtistId && head.collectionId == 2
                && head.bindingHash == binding_.bindingHash && head.generation == 1
                && head.identityRecordHash == binding_.identityRecordHash
                && head.statementHash == keccak256(statement)
                && head.sourceRegistry == address(artists) && head.recordHash == expected,
            "exact original credential head"
        );
        require(
            personhood != 0
                && IStreamArtistC2PAReads(artistSuite.owners[4])
                .personhoodAttestation(2, tokenArtistId)
                .recordHash == personhood,
            "original credentials neither replace nor satisfy personhood"
        );
        credentialStatement = head.statementHash;
        record = head.recordHash;
        _c2paArchive(24, address(tokenArtist), record);
    }

    function _verifierGrant(OfficialSafe account, uint8 class_, bool enabled) internal {
        (bytes32 scope, bytes32 previous, bytes32 next) = assemblyMetadata.familyWriterTransition(
            2, C2PA_FAMILY, class_, address(account), enabled
        );
        bytes memory data = abi.encodeCall(
            assemblyMetadata.setFamilyWriter,
            (uint256(2), C2PA_FAMILY, class_, address(account), enabled)
        );
        _executeStage(
            _single(
                StreamCurrentStackPlan.call(address(assemblyMetadata), data, scope, previous, next),
                data
            ),
            keccak256(abi.encode("C2PA verifier grant", address(account), class_, enabled))
        );
    }

    function _report(bytes32 subject, CR.AuthorshipStatus authorship)
        internal
        returns (CR.Report memory p)
    {
        T.Binding memory binding_ = IStreamArtistBindingOwner(artistSuite.owners[0]).binding(2);
        p.version = 1;
        p.profile = keccak256("6529STREAM_C2PA_RECONCILIATION_V1");
        p.collectionId = 2;
        p.subjectId = subject;
        p.artistId = tokenArtistId;
        p.bindingHash = binding_.bindingHash;
        p.generation = 1;
        p.identityRecordHash = binding_.identityRecordHash;
        p.identityDocumentHash = binding_.identityRecordHash;
        p.credentialRecordHash = credential;
        p.credentialEnumerationHash = credentialStatement;
        p.publicKeyHistoryHash = keccak256("explicit synthetic verifier key-history interpretation");
        p.selectedMediaManifestHash = mediaManifest;
        p.mediaSlot = 1;
        p.mediaHash = MEDIA_HASH;
        p.claimAssetHash = MEDIA_HASH;
        p.manifestHash = keccak256("synthetic C2PA manifest");
        p.claimHash = keccak256(abi.encode("synthetic claim", ++reportSequence));
        p.claimSignatureHash = keccak256("synthetic claim signature");
        p.signerKind = 1;
        p.signerFingerprint = SPKI;
        p.signerKeyFingerprint = SPKI;
        p.keyId = KEY_ID;
        p.signedAt = uint64(block.timestamp);
        p.validation = CR.ValidationStatus.VALID;
        p.authorship = authorship;
        p.assertsAuthorship = true;
        p.validatorIdentityHash = keccak256("explicit selected test verifier");
        p.softwareVersionHash = keccak256("synthetic-observation-v1");
        (p.validationReportHash,) = assemblyStore.publishChunk(
            bytes("synthetic selected verifier observation; no cryptographic claim")
        );
        (p.trustAnchorsHash,) =
            assemblyStore.publishChunk(bytes("synthetic retained test trust anchor"));
        p.reportURI = "urn:fixture:c2pa-token-report";
    }

    function _c2paArchive(uint16 op, address actor, bytes32 record) internal view {
        bytes32 id = keccak256(
            abi.encode(
                keccak256("6529STREAM_ARTIST_ONBOARDING_OPERATION_EVIDENCE_V1"),
                block.chainid,
                address(artists),
                address(artistCoordinator),
                op,
                actor,
                record
            )
        );
        (uint16 schema, bytes32 config, uint16 actual, address savedActor, bytes32 saved,,,) = abi.decode(
            StreamArtistArchiveV2(artistSuite.archive).artistEvidenceBytesV2(id, 1),
            (uint16, bytes32, uint16, address, bytes32, T.Snapshot[7], T.Snapshot[7], bytes)
        );
        require(
            schema == 1 && config == artistCoordinator.configurationHash() && actual == op
                && savedActor == actor && saved == record,
            "exact actual Artist Archive operation"
        );
    }

    function _cRole(bytes32 role, address holder) internal {
        (bytes32 oldChain, uint64 revision) = roles.roleMutationState(role);
        (bytes32 oldGlobal, uint64 globalRevision) = roles.globalRoleMutationState();
        require(!roles.hasRole(role, holder), "fresh actual role grant");
        bytes32 scope = keccak256(
            abi.encode(
                keccak256("6529STREAM_ROLE_MUTATION_SCOPE_V1"),
                block.chainid,
                address(roles),
                role,
                holder
            )
        );
        bytes32 nextChain = keccak256(
            abi.encode(
                keccak256("6529STREAM_ROLE_MUTATION_V1"),
                oldChain,
                block.chainid,
                address(roles),
                role,
                holder,
                true,
                revision + 1
            )
        );
        bytes32 nextGlobal = keccak256(
            abi.encode(
                keccak256("6529STREAM_GLOBAL_ROLE_MUTATION_V1"),
                oldGlobal,
                block.chainid,
                address(roles),
                role,
                holder,
                true,
                globalRevision + 1
            )
        );
        bytes32 domain = keccak256("6529STREAM_ROLE_MUTATION_STATE_V1");
        bytes32 previous = keccak256(
            abi.encode(
                domain,
                block.chainid,
                address(roles),
                scope,
                false,
                oldChain,
                revision,
                oldGlobal,
                globalRevision
            )
        );
        bytes32 next = keccak256(
            abi.encode(
                domain,
                block.chainid,
                address(roles),
                scope,
                true,
                nextChain,
                revision + 1,
                nextGlobal,
                globalRevision + 1
            )
        );
        bytes memory data = abi.encodeCall(roles.grantRole, (role, holder));
        _executeStage(
            _single(StreamCurrentStackPlan.call(address(roles), data, scope, previous, next), data),
            keccak256(abi.encode("C2PA role", role, holder))
        );
        require(roles.hasRole(role, holder), "actual retained role grant");
    }

    function _prepareC2PAArchive() internal {
        _cRole(keccak256("ROLE_FIXITY_OPERATOR"), vm.addr(0xE5705));
        _cRole(keccak256("ROLE_ATTRIBUTION_ARBITER"), address(governor));
        archiveFamilyOne = _cFamily(true);
        archiveFamilyTwo = _cFamily(false);
    }

    function _cFamily(bool native_) internal returns (bytes32 hash) {
        string memory name = native_ ? "c2pa-token-native" : "c2pa-token-possession";
        bytes memory salt = bytes(name);
        StreamArchivalTypes.Family memory f = StreamArchivalTypes.Family(
            keccak256(salt),
            native_ ? artistArchivalCheckpoint.networkId() : keccak256("IPFS"),
            keccak256(bytes.concat(salt, "protocol")),
            keccak256(bytes.concat(salt, "addressing")),
            keccak256(bytes.concat(salt, "custodian")),
            keccak256(bytes.concat(salt, "funding")),
            keccak256(bytes.concat(salt, "retrieval")),
            keccak256(bytes.concat(salt, "jurisdiction")),
            native_ ? 1 : 2,
            vm.addr(native_ ? 0xE5703 : 0xE5704),
            native_
                ? artistArchivalCheckpoint.profileHash()
                : artistArchivalCoverage.POSSESSION_PROFILE()
        );
        bytes32 scope;
        bytes32 previous;
        bytes32 next;
        (hash, scope, previous, next) = artistArchivalCoverage.familyRegistrationContext(name, f);
        bytes memory data = abi.encodeCall(artistArchivalCoverage.admitFamily, (name, f));
        _executeStage(
            _single(
                StreamCurrentStackPlan.call(
                    address(artistArchivalCoverage), data, scope, previous, next
                ),
                data
            ),
            keccak256(salt)
        );
    }

    function _cSign(uint256 key, bytes32 digest) internal returns (bytes memory) {
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(key, digest);
        return abi.encodePacked(r, s, v);
    }

    function _cLeaf(bytes32 digest, uint256 end) internal pure returns (bytes32) {
        return sha256(abi.encodePacked(sha256(abi.encodePacked(digest)), sha256(abi.encode(end))));
    }

    function _cArchiveBytes(bytes memory payload) internal returns (bytes32 evidence) {
        (evidence,) = assemblyStore.publishChunk(payload);
        StreamArchivalTypes.Envelope memory e = StreamArchivalTypes.Envelope(
            0,
            evidence,
            keccak256("6529STREAM_PLATFORM_WORKS_EVIDENCE_V1"),
            keccak256("BINARY_EXACT_V1"),
            2,
            sha256(payload),
            uint64(payload.length),
            1,
            0
        );
        bytes32 env = artistArchivalCoverage.recordCollectionEnvelope(2, e, payload);
        StreamArchivalTypes.Checkpoint memory c;
        c.networkId = artistArchivalCheckpoint.networkId();
        c.blockHash = new bytes(48);
        c.blockHash[0] = 0x65;
        c.blockHeight = 1500000;
        c.dataSize = uint64(payload.length);
        c.blockDataSize = payload.length;
        c.dataRoot = _cLeaf(sha256(payload), payload.length);
        c.transactionRoot = _cLeaf(c.dataRoot, payload.length);
        c.transactionId = keccak256(abi.encode("synthetic C2PA archival transaction", evidence));
        c.transactionEnd = payload.length;
        c.observedAt = uint64(block.timestamp);
        c.configurationHash = artistArchivalCheckpoint.configurationHash();
        bytes32 digest = artistArchivalCheckpoint.checkpointDigest(c);
        StreamArchivalTypes.ObserverProof[] memory certificate =
            new StreamArchivalTypes.ObserverProof[](2);
        certificate[0] = StreamArchivalTypes.ObserverProof(
            vm.addr(ARCHIVAL_OBSERVER_ONE), _cSign(ARCHIVAL_OBSERVER_ONE, digest)
        );
        certificate[1] = StreamArchivalTypes.ObserverProof(
            vm.addr(ARCHIVAL_OBSERVER_TWO), _cSign(ARCHIVAL_OBSERVER_TWO, digest)
        );
        if (certificate[0].account > certificate[1].account) {
            (certificate[0], certificate[1]) = (certificate[1], certificate[0]);
        }
        bytes32 checkpoint = artistArchivalCheckpoint.recordCheckpoint(
            c,
            abi.encodePacked(c.dataRoot, uint256(payload.length)),
            abi.encodePacked(sha256(payload), uint256(payload.length)),
            payload,
            certificate
        );
        bytes32 first = _cReceipt(
            env, archiveFamilyOne, checkpoint, abi.encodePacked(c.transactionId), 0xE5703, true
        );
        bytes32 second = _cReceipt(
            env,
            archiveFamilyTwo,
            0,
            abi.encodePacked(bytes4(0x01551220), e.payloadDigest),
            0xE5704,
            false
        );
        _cFixity(first, e);
        _cFixity(second, e);
        bytes32 coverage = artistArchivalCoverage.recordCoverage(first, second);
        StreamArchivalTypes.CoverageFacts memory f =
            artistArchivalCoverage.requireCollectionEvidence(2, evidence);
        require(
            f.coverageRecordHash == coverage && f.evidenceHash == evidence && f.envelopeHash == env
                && f.artistId == 0,
            "actual dual-family collection coverage"
        );
    }

    function _cReceipt(
        bytes32 envelope,
        bytes32 family,
        bytes32 checkpoint,
        bytes memory identifier,
        uint256 key,
        bool native_
    ) internal returns (bytes32) {
        StreamArchivalTypes.ReceiptTerms memory r = StreamArchivalTypes.ReceiptTerms(
            envelope,
            family,
            keccak256(identifier),
            keccak256(bytes(native_ ? "CONTENT_ADDRESSED_INCLUSION" : "ATTESTED_POSSESSION")),
            native_
                ? artistArchivalCheckpoint.profileHash()
                : artistArchivalCoverage.POSSESSION_PROFILE(),
            checkpoint,
            vm.addr(key),
            uint64(block.timestamp),
            archiveNonce++,
            uint64(block.timestamp + 1 days)
        );
        if (!native_) {
            r.proofRecordHash = artistArchivalCoverage.possessionHash(
                StreamArchivalTypes.Possession(
                    envelope, family, r.storageIdentifierHash, r.writer, r.observedAt
                )
            );
        }
        return artistArchivalCoverage.recordReceipt(
            r, identifier, _cSign(key, artistArchivalCoverage.receiptDigest(r))
        );
    }

    function _cFixity(bytes32 receipt, StreamArchivalTypes.Envelope memory e) internal {
        (StreamArchivalTypes.ReceiptTerms memory r,,) = artistArchivalCoverage.receipt(receipt);
        StreamArchivalTypes.FixityTerms memory f = StreamArchivalTypes.FixityTerms(
            receipt,
            r.envelopeHash,
            r.familyRecordHash,
            e.payloadDigest,
            e.payloadDigest,
            e.byteSize,
            uint64(block.timestamp),
            1,
            keccak256(abi.encode("C2PA fixity", receipt)),
            0,
            0,
            vm.addr(0xE5705),
            archiveNonce++,
            uint64(block.timestamp + 1 days)
        );
        artistArchivalCoverage.recordFixity(
            f, _cSign(0xE5705, artistArchivalCoverage.fixityDigest(f))
        );
    }

    function _cEvidence(bytes32 parent, bytes memory narrative) internal returns (bytes32) {
        bytes32 narrativeHash = _cArchiveBytes(narrative);
        T.Binding memory b = IStreamArtistBindingOwner(artistSuite.owners[0]).binding(2);
        return _cArchiveBytes(
            abi.encode(Dispute.Evidence(1, 2, 1, b.bindingHash, parent, narrativeHash))
        );
    }

    function _resolveConflictWithExactRetry(CF.Conflict memory conflict)
        internal
        returns (bytes32 action)
    {
        _prepareC2PAArchive();
        bytes32 openingEvidence = _cEvidence(0, bytes("explicit original C2PA dispute opening"));
        Dispute.Filing memory filing = Dispute.Filing(2, 1, 1, openingEvidence, openingEvidence);
        Dispute.Standing memory standing = Dispute.Standing(tokenArtistId, 1, 0, 0);
        T.Authorization memory auth = _tokenArtistAuth(false);
        uint64 openedAt = uint64(block.timestamp);
        _tokenSafe(
            tokenArtist,
            address(artists),
            0,
            abi.encodeCall(
                IStreamArtistAttributionDisputes.openAttributionDispute, (filing, standing, auth)
            )
        );
        bytes32 opening = keccak256(
            abi.encode(
                keccak256("6529STREAM_ARTIST_DISPUTE_RECORD_V1"),
                block.chainid,
                address(artists),
                uint256(2),
                uint64(1),
                uint8(1),
                address(tokenArtist),
                uint8(1),
                openingEvidence,
                openingEvidence,
                auth.nonce,
                openedAt
            )
        );
        Dispute.Head memory head =
            IStreamArtistAttributionDisputes(address(artists)).attributionDispute(2, 1);
        require(
            head.open && head.disputeRecordHash == opening && head.counterStatementRecordHash == 0,
            "independent original opening record"
        );
        _c2paArchive(44, address(tokenArtist), opening);
        bytes memory narrative = abi.encode(
            keccak256("6529STREAM_C2PA_DISPUTE_DISPOSITION_V1"),
            block.chainid,
            address(c2pa.reconciliation),
            address(core),
            address(artists),
            uint256(2),
            conflict.subjectId,
            tokenArtistId,
            conflict.bindingHash,
            uint64(1),
            conflict.conflictId,
            conflict.chainHash,
            conflict.recordHash,
            conflict.selectionHash,
            uint8(1)
        );
        require(
            keccak256(c2pa.reconciliation.resolutionNarrative(conflict.conflictId))
                == keccak256(narrative),
            "independent exact conflict narrative"
        );
        bytes32 evidence = _cEvidence(opening, narrative);
        Dispute.ResolutionRequest memory resolution =
            Dispute.ResolutionRequest(2, 1, opening, 1, evidence, evidence, 0);
        Dispute.Context memory context = IStreamArtistAttributionDisputes(address(artists))
            .attributionDisputeResolutionContext(resolution);
        require(
            context.requiredClass == 1 && context.restoredState == 2,
            "original accepted-state resolution class"
        );
        bytes memory data = abi.encodeCall(
            IStreamArtistAttributionDisputes.resolveAttributionDispute, (resolution)
        );
        uint64 ready = uint64(block.timestamp + executor.minimumDelay(1));
        GovernanceActionRequest memory request = GovernanceActionRequest(
            1,
            address(artists),
            0,
            IStreamArtistAttributionDisputes.resolveAttributionDispute.selector,
            data,
            context.scopeHash,
            context.oldValueHash,
            context.newValueHash,
            ready,
            ready + 7 days,
            evidence,
            "urn:fixture:c2pa-op46",
            DEPLOYMENT_HASH
        );
        vm.recordLogs();
        _tokenSafe(
            governor,
            address(executor),
            0,
            abi.encodeCall(executor.scheduleGovernanceAction, (request))
        );
        Vm.Log[] memory schedule = vm.getRecordedLogs();
        bytes32 scheduled = keccak256(
            "GovernanceActionScheduled(uint16,bytes32,uint8,address,uint256,bytes4,bytes32,bytes32,bytes32,bytes32,uint64,uint64,uint256,address,bytes32,string,bytes32)"
        );
        for (uint256 i; i < schedule.length; ++i) {
            if (
                schedule[i].emitter == address(executor) && schedule[i].topics.length == 4
                    && schedule[i].topics[0] == scheduled
            ) {
                require(action == 0, "one actual op46 schedule");
                action = schedule[i].topics[1];
            }
        }
        require(action != 0, "original scheduled action identity");
        bytes memory exact = _tokenPayload(
            tokenBuyer,
            address(c2pa.reconciliation),
            0,
            abi.encodeCall(c2pa.reconciliation.clearStandingConflict, (conflict.conflictId, action))
        );
        CF.Standing memory before_ = c2pa.reconciliation.standingConflict(2, conflict.subjectId);
        _tokenFailure(tokenBuyer, exact);
        require(
            keccak256(abi.encode(c2pa.reconciliation.standingConflict(2, conflict.subjectId)))
                    == keccak256(abi.encode(before_))
                && c2pa.reconciliation.conflictResolution(conflict.conflictId).actionId == 0,
            "unexecuted action cannot clear original conflict"
        );
        vm.warp(ready);
        executor.executeGovernanceAction(action, data);
        Dispute.Resolution memory resolved =
            IStreamArtistAttributionDisputes(address(artists)).attributionDisputeResolution(action);
        require(
            keccak256(abi.encode(resolved.terms)) == keccak256(abi.encode(resolution))
                && resolved.actionId == action && resolved.actor == address(executor)
                && resolved.proposer == address(governor) && resolved.actionClass == 1
                && resolved.restoredState == 2,
            "actual arbiter Safe proposed original op46"
        );
        _c2paArchive(46, address(executor), action);
        vm.recordLogs();
        _tokenSuccess(tokenBuyer, exact);
        CF.Resolution memory expected =
            CF.Resolution(action, opening, evidence, keccak256(narrative), uint64(block.timestamp));
        require(
            keccak256(abi.encode(c2pa.reconciliation.conflictResolution(conflict.conflictId)))
                == keccak256(abi.encode(expected)),
            "exact original disposition acknowledgement"
        );
        Vm.Log[] memory cleared = vm.getRecordedLogs();
        uint256 count;
        for (uint256 i; i < cleared.length; ++i) {
            if (
                cleared[i].emitter == address(c2pa.reconciliation) && cleared[i].topics.length == 3
                    && cleared[i].topics[0]
                        == keccak256(
                            "C2PAConflictCleared(bytes32,bytes32,(bytes32,bytes32,bytes32,bytes32,uint64))"
                        )
            ) {
                require(
                    cleared[i].topics[1] == conflict.conflictId && cleared[i].topics[2] == action
                        && keccak256(cleared[i].data) == keccak256(abi.encode(expected)),
                    "exact cleared receipt"
                );
                ++count;
            }
        }
        require(count == 1, "one original conflict acknowledgement");
        CF.Standing memory after_ = c2pa.reconciliation.standingConflict(2, conflict.subjectId);
        require(
            after_.conflictId == 0 && after_.recordHash == 0 && after_.selectionHash == 0
                && after_.unresolvedCount == 0 && after_.revision == before_.revision
                && after_.chainHash == before_.chainHash,
            "acknowledgement retains immutable conflict chain"
        );
        _tokenFailure(
            tokenBuyer,
            _tokenPayload(
                tokenBuyer,
                address(c2pa.reconciliation),
                0,
                abi.encodeCall(
                    c2pa.reconciliation.clearStandingConflict, (conflict.conflictId, action)
                )
            )
        );
    }

    function _recordInput(CR.Report memory p)
        internal
        pure
        returns (Records.CollectionRecord memory r)
    {
        r.recordType = keccak256("C2PA_VALIDATION");
        r.subjectId = p.subjectId;
        r.schemaId = C2PA_SCHEMA;
        r.uri = p.reportURI;
        r.effectiveAt = p.signedAt;
        r.contentHash =
            Records.HashRef(1, abi.encode(keccak256(abi.encode(p))), keccak256("RAW_BYTES"));
    }

    function _recordHash(OfficialSafe recorder, Records.CollectionRecord memory r)
        internal
        view
        returns (bytes32)
    {
        return keccak256(
            abi.encode(
                keccak256("6529stream.preservation-record.v2"),
                block.chainid,
                address(assemblyMetadata),
                address(core),
                address(recorder),
                uint256(2),
                r.recordType,
                r.subjectId,
                keccak256(
                    abi.encode(uint16(1), keccak256(r.contentHash.digest), keccak256("RAW_BYTES"))
                ),
                keccak256(bytes(r.uri)),
                r.schemaId,
                bytes32(0),
                keccak256(abi.encode(uint16(0), keccak256(bytes("")), bytes32(0))),
                r.effectiveAt
            )
        );
    }

    function _publish(CR.Report memory p, OfficialSafe recorder, uint8 class_)
        internal
        returns (bytes32 hash)
    {
        Records.CollectionRecord memory r = _recordInput(p);
        hash = _recordHash(recorder, r);
        vm.recordLogs();
        _tokenSafe(
            recorder,
            address(assemblyMetadata),
            0,
            abi.encodeCall(
                assemblyMetadata.recordCollectionRecordWithPayload, (uint256(2), r, abi.encode(p))
            )
        );
        _checkPublished(p, recorder, class_, hash, vm.getRecordedLogs());
    }

    function _checkPublished(
        CR.Report memory p,
        OfficialSafe recorder,
        uint8 class_,
        bytes32 hash,
        Vm.Log[] memory logs
    ) internal {
        Records.CollectionRecord memory r = _recordInput(p);
        bytes32 nextChain = keccak256(
            abi.encode(
                bytes32(0x0e7a0feb85d4a4a3e90074703c19de35786e11afaae8f9868aa2a911bcfa1609),
                block.chainid,
                address(assemblyMetadata),
                uint256(2),
                keccak256("C2PA_VALIDATION"),
                recordChain,
                hash,
                recordCount
            )
        );
        (
            Records.CollectionRecord memory actual,
            IStreamCollectionMetadataV1.RecordReceipt memory receipt
        ) = assemblyMetadata.collectionRecord(hash);
        require(
            keccak256(abi.encode(actual)) == keccak256(abi.encode(r)) && receipt.collectionId == 2
                && receipt.recorder == address(recorder) && receipt.authorizationClass == class_
                && receipt.recordIndex == recordCount && receipt.recordChainHash == nextChain
                && receipt.artistAuthorization == 0 && receipt.recordedAt == block.timestamp
                && receipt.schemaDefinitionHash
                    == 0x9c896dc177954cc145f240cbcd4097a3b953b0121360c7f2acef053bc17e68cb,
            "independent original Metadata receipt and zero-based chain"
        );
        (address pointer, bytes memory payload) = assemblyMetadata.recordPayload(hash);
        require(
            pointer != address(0) && keccak256(payload) == keccak256(abi.encode(p)),
            "original retained report bytes"
        );
        _oneTokenEvent(
            logs,
            address(assemblyMetadata),
            keccak256(
                "CollectionRecordRecorded(uint256,bytes32,bytes32,(bytes32,bytes32,(uint16,bytes,bytes32),string,bytes32,bytes32,(uint16,bytes,bytes32),uint64),bytes32,bytes32,address,bytes32,uint16)"
            ),
            bytes32(uint256(2)),
            keccak256("C2PA_VALIDATION"),
            p.subjectId,
            abi.encode(r, hash, nextChain, address(recorder), bytes32(uint256(class_)), uint16(1))
        );
        recordChain = nextChain;
        ++recordCount;
    }

    function _adopt(CR.Report memory p, bytes32 record, bytes32 prior, uint64 revision)
        internal
        returns (CR.Selection memory expected)
    {
        (, IStreamCollectionMetadataV1.RecordReceipt memory receipt) =
            assemblyMetadata.collectionRecord(record);
        expected = CR.Selection(
            record, prior, 0, revision + 1, receipt.recordIndex, receipt.authorizationClass, p
        );
        expected.selectionHash = keccak256(
            abi.encode(
                keccak256("6529STREAM_C2PA_RECONCILIATION_V1"),
                block.chainid,
                address(c2pa.reconciliation),
                address(core),
                address(assemblyMetadata),
                address(artists),
                address(router),
                address(verifierSafe),
                expected
            )
        );
        vm.recordLogs();
        _tokenSafe(
            tokenBuyer,
            address(c2pa.reconciliation),
            0,
            abi.encodeCall(
                c2pa.reconciliation.adopt, (uint256(2), p.subjectId, record, prior, revision)
            )
        );
        Vm.Log[] memory logs = vm.getRecordedLogs();
        require(
            keccak256(abi.encode(c2pa.reconciliation.currentSelection(2, p.subjectId)))
                    == keccak256(abi.encode(expected))
                && keccak256(
                    abi.encode(c2pa.reconciliation.selectionAt(2, p.subjectId, revision + 1))
                ) == keccak256(abi.encode(expected)),
            "independent immutable adoption record"
        );
        _oneTokenEvent(
            logs,
            address(c2pa.reconciliation),
            keccak256(
                "C2PAReconciliationSelected(uint256,bytes32,bytes32,(bytes32,bytes32,bytes32,uint64,uint64,uint8,(uint16,bytes32,uint256,bytes32,bytes32,bytes32,uint64,bytes32,bytes32,bytes32,bytes32,bytes32,bytes32,uint8,bytes32,bytes32,bytes32,bytes32,bytes32,uint8,bytes32,bytes32,bytes32,uint64,uint8,uint8,bool,bytes32,bytes32,bytes32,bytes32,string)))"
            ),
            bytes32(uint256(2)),
            p.subjectId,
            record,
            abi.encode(expected)
        );
        CR.Display memory d = c2pa.reconciliation.display(2, p.subjectId);
        require(
            d.current && d.recordHash == record && d.selectionHash == expected.selectionHash
                && d.validation == CR.ValidationStatus.VALID && d.authorship == p.authorship
                && d.assertsAuthorship,
            "actual current selected verifier report"
        );
    }

    function _assertConflict(CR.Selection memory selected, CF.Standing memory prior)
        internal
        view
        returns (CF.Conflict memory expected)
    {
        expected = CF.Conflict(
            0,
            2,
            selected.report.subjectId,
            tokenArtistId,
            selected.report.bindingHash,
            1,
            selected.recordHash,
            selected.selectionHash,
            prior.conflictId,
            0,
            prior.revision + 1,
            uint64(block.timestamp)
        );
        expected.conflictId = keccak256(
            abi.encode(
                keccak256("6529STREAM_C2PA_STANDING_CONFLICT_V1"),
                block.chainid,
                address(c2pa.reconciliation),
                address(core),
                address(artists),
                expected
            )
        );
        expected.chainHash = keccak256(
            abi.encode(
                keccak256("6529STREAM_C2PA_CONFLICT_CHAIN_V1"),
                prior.chainHash,
                expected.conflictId,
                expected.revision
            )
        );
        require(
            keccak256(abi.encode(c2pa.reconciliation.conflictRecord(expected.conflictId)))
                    == keccak256(abi.encode(expected))
                && c2pa.reconciliation.conflictAt(2, expected.subjectId, expected.revision)
                    == expected.conflictId,
            "independent immutable standing conflict"
        );
        CF.Standing memory expectedHead = CF.Standing(
            expected.conflictId,
            expected.chainHash,
            expected.recordHash,
            expected.selectionHash,
            expected.revision,
            prior.unresolvedCount + 1
        );
        require(
            keccak256(abi.encode(c2pa.reconciliation.standingConflict(2, expected.subjectId)))
                == keccak256(abi.encode(expectedHead)),
            "exact standing conflict history"
        );
    }

    function _c2paContext() internal view returns (string memory) {
        return string.concat(
            '{"schema":"stream-render-context-v1","chainId":"',
            block.chainid.toString(),
            '","contract":"',
            uint256(uint160(address(core))).toHexString(20),
            '","tokenId":"1","collectionId":"2","collectionSerial":"1","collectionSupplyMode":"FIXED","collectionStatus":"ACTIVE","hash":"',
            uint256(seed).toHexString(32),
            '","seed":"',
            uint256(seed).toHexString(32),
            '","entropyStatus":"FINALIZED","entropyProvider":"',
            uint256(uint160(address(provider))).toHexString(20),
            '","viewId":"MARKETPLACE","metadataSnapshotHash":"',
            uint256(initialRecord.recordHash).toHexString(32),
            '","rendererId":"',
            uint256(keccak256("6529STREAM_RENDERER_V1")).toHexString(32),
            '","rendererVersion":"',
            uint256(keccak256("6529STREAM_STATIC_RENDERER_V1")).toHexString(32),
            '","renderContextVersion":"STREAM_CONTEXT_V1","scriptHash":"',
            uint256(keccak256(bytes(PROGRAM))).toHexString(32),
            '","mediaManifestHash":"',
            uint256(mediaManifest).toHexString(32),
            '","tokenData":"0x00ff6529","dependencyScript":""}'
        );
    }

    function _assertC2PAOutput(
        bytes32 record,
        bytes32 subject,
        string memory validation,
        string memory authorship,
        bool current,
        string memory state,
        bool adverse
    ) internal view {
        string memory html = string.concat(
            "<html><head></head><body><script>window.__STREAM_TOKEN__=",
            _c2paContext(),
            ";const stream=window.__STREAM_TOKEN__;const hash=stream.hash;const tokenId=Number(stream.tokenId);const tokenData=stream.tokenData;</script><script></script><script>",
            PROGRAM,
            "</script></body></html>"
        );
        require(
            keccak256(bytes(router.tokenHTML(1))) == keccak256(bytes(html)),
            "independent full C2PA token HTML"
        );
        string memory json = router.tokenJSON(1);
        _assertTokenCitationDelta(json, _c2paContext());
        require(
            _has(json, _literalCurrentTokenContext(_c2paContext()))
                && _has(json, '"artist_display_name":"STATIC Artist"')
                && _has(json, '"state":"artist_accepted"')
                && _has(json, '"token_data_base64":"AP9lKQ=="')
                && _has(
                    json,
                    string.concat(
                        '"animation_url":"data:text/html;base64,', Base64.encode(bytes(html)), '"'
                    )
                ),
            "original token and Safe Artist output retained"
        );
        require(
            _has(json, string.concat('"c2pa_validation_status":"', validation, '"'))
                && _has(json, string.concat('"c2pa_authorship_status":"', authorship, '"'))
                && _has(
                    json, current ? '"c2pa_report_current":true' : '"c2pa_report_current":false'
                )
                && _has(
                    json,
                    adverse
                        ? '"c2pa_attribution_divergence":true'
                        : '"c2pa_attribution_divergence":false'
                ) && _has(json, string.concat('"c2pa_conflict_state":"', state, '"'))
                && _has(json, '"c2pa_basis":"selected_verifier_report"')
                && _has(json, '"c2pa_read_unavailable":false')
                && _has(json, '"c2pa_conflict_read_unavailable":false')
                && _has(
                    json, string.concat('"c2pa_record":"', uint256(record).toHexString(32), '"')
                )
                && _has(
                    json, string.concat('"c2pa_subject":"', uint256(subject).toHexString(32), '"')
                ),
            "literal independently expected C2PA output"
        );
    }
}
