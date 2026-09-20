// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./StreamConservationSelectionFixture.sol";
import "../../../smart-contracts/domains/metadata/StreamRightsRecordSelection.sol";
import "../../../smart-contracts/domains/metadata/StreamNativeConservationFloorProvider.sol";
import {
    StreamMetadataRouterCollectionReads
} from "../../../smart-contracts/domains/metadata/StreamMetadataRouterCollectionReads.sol";
import {
    StreamMetadataRouter
} from "../../../smart-contracts/domains/metadata/StreamMetadataRouter.sol";
import { IStreamCore } from "../../../smart-contracts/interfaces/stream/core/IStreamCore.sol";
import {
    IStreamCoreCollectionView
} from "../../../smart-contracts/interfaces/stream/core/IStreamCoreCollectionView.sol";
import {
    StreamArtistPersonhoodTypes as Personhood,
    IStreamArtistPersonhoodEvidence
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistPersonhoodEvidence.sol";
import {
    StreamArtistPersonhoodDefinitions as PersonhoodDefinitions
} from "../../../smart-contracts/domains/artist/StreamArtistPersonhoodDefinitions.sol";

/// @dev Explicit typed native Router and media-selector boundary. It does not produce archive proof.
/// The empty inventory is the literal full empty native MediaManifest commitment, not bytes32(0).
contract NativeConservationSourceBoundary {
    address public core;
    address public metadata;
    address public schemaRegistry;
    bytes32 public subject;
    bytes32 public manifest = keccak256("typed selected empty native manifest");
    bytes32 public inventory;
    uint8 public occupied;
    bool public mediaUnavailable;
    IStreamMetadataServingFacts.ServingFacts private serving;

    constructor(address c, address m, address s, bytes32 scope) {
        core = c;
        metadata = m;
        schemaRegistry = s;
        subject = scope;
        StreamCollectionManifestTypes.MediaManifest memory empty;
        inventory = keccak256(abi.encode(keccak256("6529STREAM_MEDIA_MASTER_INVENTORY_V1"), empty));
        serving.configured = true;
        serving.mode = keccak256("OFFCHAIN");
        serving.presentationProfile = keccak256("6529STREAM_ROUTER_STABLE_PRESENTATION_V1");
        serving.scriptHash = keccak256("");
    }

    function setOwner(address value) external {
        metadata = value;
    }

    function setMedia(bytes32 locator, bytes32 content, uint8 mask) external {
        manifest = locator;
        inventory = content;
        occupied = mask;
    }

    function setMediaUnavailable(bool value) external {
        mediaUnavailable = value;
    }

    function setServing(IStreamMetadataServingFacts.ServingFacts calldata value) external {
        serving = value;
    }

    function collectionMediaContext(uint256)
        external
        view
        returns (bytes32, bytes32, bytes32, uint8)
    {
        return (subject, manifest, inventory, occupied);
    }

    function requireCollectionMasters(uint256 cid, bytes32 scope) external view returns (bytes32) {
        require(cid == 1 && scope == subject && !mediaUnavailable, "typed masters unavailable");
        return
            keccak256(
                abi.encode("typed complete native media floor", manifest, inventory, occupied)
            );
    }

    function collectionServingFacts(uint256)
        external
        view
        returns (IStreamMetadataServingFacts.ServingFacts memory)
    {
        return serving;
    }
}

/// @dev Actual original Router facts function over explicit storage and Core boundaries.
/// This does not exercise Router write authorization, master production or paid settlement.
contract NativeConservationOriginalRouterFacts {
    address private immutable core;
    address private immutable renderer;
    mapping(uint256 => StreamMetadataRouter.CollectionMetadata) private collections;
    mapping(uint256 => mapping(bytes32 => bool)) private contentLocks;
    mapping(uint256 => IStreamMetadataServingFacts.ArtistPresentation) private presentations;
    mapping(uint256 => bool) private displayLocks;

    constructor(address c, address r) {
        core = c;
        renderer = r;
        collections[1].configured = true;
        collections[1].animationScript = "";
    }

    function collectionServingFacts(uint256 collectionId)
        external
        view
        returns (IStreamMetadataServingFacts.ServingFacts memory)
    {
        return StreamMetadataRouterCollectionReads.facts(
            collections,
            contentLocks,
            presentations,
            displayLocks,
            IStreamCore(core),
            collectionId,
            renderer
        );
    }
}

/// @notice Actual original RIGHTS/Metadata/Schema/Store and conservation selection/receipt checks.
/// @dev Core/Executor, Artist owners/platform declaration, Router, media and script reads are typed
/// boundaries. No real personhood, full native graph or archive execution is claimed by this suite.
/// One regression additionally executes the actual original Router serving-facts producer.
contract StreamNativeConservationFloorProviderTest is ConservationSelectionFixture {
    bytes32 private constant _LITE = keccak256("MUSEUM_GRADE_LITE");
    bytes32 private constant _FULL = keccak256("MUSEUM_GRADE");
    bytes32 private constant _RIGHTS = keccak256("RIGHTS_STATEMENT");
    StreamRightsRecordSelection private rights;
    StreamNativeConservationFloorProvider private provider;
    NativeConservationSourceBoundary private sources;
    bytes32 private rightsHash;

    modifier providerReady() {
        _prepare();
        _bound();
        _prepareProvider();
        _;
    }

    function _prepareProvider() private {
        _registerDocument(
            "STREAM_RIGHTS_V1",
            IStreamSchemaRegistry.DocumentKind.SCHEMA,
            bytes(vm.readFile("schemas/records/STREAM_RIGHTS_V1.json")),
            schemas.RAW_BYTES()
        );
        _registerDocument(
            "STREAM_RIGHTS_JSON_PROFILE_V1",
            IStreamSchemaRegistry.DocumentKind.CATALOG,
            bytes(vm.readFile("schemas/records/STREAM_RIGHTS_JSON_PROFILE_V1.json")),
            schemas.RAW_BYTES()
        );
        _admit(_RIGHTS, StreamRecordFamilies.RIGHTS, uint16((1 << 7) | (1 << 8)));
        _grant(1, StreamRecordFamilies.RIGHTS, 7, address(this), true);
        rights = new StreamRightsRecordSelection(address(core), address(metadata), address(schemas));
        StreamRightsRecordTypes.Statement memory statement;
        statement.subjectId = subject;
        statement.profileHash = StreamRightsRecordDefinitions.PROFILE_HASH;
        statement.licensor.kind = StreamRightsRecordTypes.LicensorKind.ACCOUNT;
        statement.licensor.account = address(0x123);
        statement.startDate = 20260920;
        statement.openEnd = true;
        bytes memory payload = StreamRightsRecordJson.serialize(statement);
        IStreamPreservationRecords.CollectionRecord memory r = _record(_RIGHTS, payload);
        r.schemaId = StreamRightsRecordDefinitions.SCHEMA_ID;
        r.contentHash.canonicalizationId = StreamRightsRecordDefinitions.CANON_ID;
        rightsHash = metadata.recordCollectionRecordWithPayload(1, r, payload);
        rights.selectCurrent(1, subject, rightsHash, 0, 0, statement);
        sources = new NativeConservationSourceBoundary(
            address(core), address(metadata), address(schemas), subject
        );
        core.setPointer(keccak256("METADATA_ROUTER"), address(sources));
        _platformDeclaration(true);
        provider = new StreamNativeConservationFloorProvider(_configuration());
    }

    function _configuration()
        private
        view
        returns (StreamNativeConservationFloorProvider.Configuration memory c)
    {
        c.targets = [
            address(core),
            address(metadata),
            address(schemas),
            address(store),
            address(rights),
            address(selection),
            address(sources),
            address(sources),
            address(facade),
            address(0)
        ];
        for (uint256 i; i < 9; ++i) {
            c.codeHashes[i] = c.targets[i].codehash;
        }
        c.executor = address(executor);
        c.readGas = IStreamGasParameterHost.GasParameterConfig(
            "CONSERVATION_PROVIDER_READ_GAS", 300000, 100000, 2
        );
        c.sourceGas = IStreamGasParameterHost.GasParameterConfig(
            "CONSERVATION_PROVIDER_SOURCE_GAS", 8000000, 1000000, 2
        );
        c.referenceGas = IStreamGasParameterHost.GasParameterConfig(
            "CONSERVATION_PROVIDER_REFERENCE_GAS", 16000000, 1000000, 2
        );
    }

    function _platformDeclaration(bool active) private {
        StreamArtistPlatformTypes.State memory state;
        if (active) {
            state.declaration = StreamArtistPlatformTypes.Declaration(
                keccak256("typed actual platform declaration record"),
                keccak256("typed original platform statement"),
                address(this),
                uint64(block.timestamp)
            );
            T.Binding memory empty;
            bindingOwner.setBinding(empty, 0);
            attributionOwner.setBinding(empty, 0);
        } else {
            _bound();
        }
        cvm.mockCall(
            address(facade),
            abi.encodeCall(IStreamArtistPlatformWorks.platformWorksState, (uint256(1))),
            abi.encode(state)
        );
    }

    function _sale() private pure returns (StreamConservationFloorTypes.SaleContext memory sale) {
        sale.collectionId = 1;
        sale.saleAdapter = address(0x5a1e);
        sale.saleId = keccak256("actual sale scope fixture");
    }

    function testProviderActualRightsAndExplicitEmptyMediaPlatformFloor() public providerReady {
        StreamConservationFloorTypes.CollectionFacts memory c =
            provider.requireCollectionFloor(1, _LITE);
        require(
            c.platformWorks && c.rightsRecordHash == rightsHash && c.artistId == 0
                && c.personhoodEvidenceHash == 0 && c.intentRecordHash == 0
                && c.intentWaiverRecordHash == 0,
            "platform omits artist evidence and retains actual original rights"
        );
        IStreamCollectionMetadataV1.RecordReceipt memory receipt =
            metadata.collectionRecordReceipt(rightsHash);
        require(
            receipt.schemaDefinitionHash == StreamRightsRecordDefinitions.SCHEMA_HASH
                && metadata.recordHashAt(1, _RIGHTS, receipt.recordIndex) == rightsHash,
            "actual rights receipt and lane"
        );
        StreamConservationFloorTypes.SaleContext memory sale = _sale();
        StreamConservationFloorTypes.ReleaseContext memory r = provider.saleRelease(sale);
        StreamConservationFloorTypes.ReleaseFacts memory f =
            provider.requireReleaseFloor(sale, r, _LITE);
        require(
            r.scopeSubject == subject && r.mediaInventoryHash == sources.inventory()
                && r.mediaInventoryHash != 0 && !r.scriptWork && r.scriptSourceHash == 0
                && f.mediaEvidenceHash != 0 && f.referenceEvidenceHash == 0
                && f.sourceContextHash == r.sourceContextHash,
            "explicit empty denominator and fresh source"
        );
    }

    function testProviderOriginalRouterEmptyOffchainScriptPreservesNoScriptRelease()
        public
        providerReady
    {
        StreamConservationFloorTypes.SaleContext memory sale = _sale();
        StreamConservationFloorTypes.ReleaseContext memory typed = provider.saleRelease(sale);
        NativeConservationOriginalRouterFacts original =
            new NativeConservationOriginalRouterFacts(address(core), address(sources));
        // The existing Core boundary owns collection existence; freeze is its only extra read here.
        cvm.mockCall(
            address(core),
            abi.encodeCall(IStreamCoreCollectionView.collectionFreezeStatus, (uint256(1))),
            abi.encode(false)
        );
        IStreamMetadataServingFacts.ServingFacts memory facts = original.collectionServingFacts(1);
        require(
            facts.configured && facts.mode == keccak256("OFFCHAIN")
                && facts.presentationProfile
                    == keccak256("6529STREAM_ROUTER_STABLE_PRESENTATION_V1")
                && facts.scriptHash == keccak256("") && facts.scriptHash != 0
                && facts.scriptBytes == 0,
            "actual original Router empty-script facts"
        );
        StreamNativeConservationFloorProvider.Configuration memory c = _configuration();
        c.targets[7] = address(original);
        c.codeHashes[7] = address(original).codehash;
        core.setPointer(keccak256("METADATA_ROUTER"), address(original));
        StreamNativeConservationFloorProvider consumer =
            new StreamNativeConservationFloorProvider(c);
        StreamConservationFloorTypes.ReleaseContext memory release = consumer.saleRelease(sale);
        require(
            !release.scriptWork && release.scriptSourceHash == 0
                && release.membershipHash == typed.membershipHash,
            "empty source hash is not an executable script or a different semantic release"
        );
        require(
            release.sourceContextHash
                == keccak256(
                    abi.encode(
                        consumer.configurationHash(),
                        sources.manifest(),
                        bytes32(0),
                        uint8(0),
                        facts,
                        release.membershipHash
                    )
                ),
            "original source context retains the exact unmodified Router facts"
        );
    }

    function testProviderOffchainRejectsZeroOpaqueAndContradictoryScriptFacts()
        public
        providerReady
    {
        StreamConservationFloorTypes.SaleContext memory sale = _sale();
        IStreamMetadataServingFacts.ServingFacts memory original = sources.collectionServingFacts(1);
        for (uint256 i; i < 7; ++i) {
            IStreamMetadataServingFacts.ServingFacts memory bad =
                abi.decode(abi.encode(original), (IStreamMetadataServingFacts.ServingFacts));
            if (i == 0) bad.scriptHash = 0; // No original supported profile uses an all-zero empty hash.
            if (i == 1) bad.scriptHash = keccak256("opaque unserved script");
            if (i == 2) bad.scriptBytes = 1;
            if (i == 3) {
                bad.scriptHash = 0;
                bad.scriptBytes = 1;
            }
            if (i == 4) {
                bad.scriptHash = keccak256("nonempty script");
                bad.scriptBytes = 1;
            }
            if (i == 5) {
                bad.presentationProfile = keccak256("6529STREAM_ROUTER_CHUNKED_PRESENTATION_V1");
            }
            if (i == 6) bad.mode = keccak256("HYBRID");
            sources.setServing(bad);
            vm.expectRevert(
                abi.encodeWithSelector(
                    StreamNativeConservationFloorProvider.NativeConservationScopeUnavailable
                    .selector
                )
            );
            provider.saleRelease(sale);
        }
        sources.setServing(original);
        require(
            provider.saleRelease(sale).scriptSourceHash == 0, "exact empty facts restore mapping"
        );
    }

    function testProviderOnchainModeCannotUseEmptyScriptLengthOrHash() public providerReady {
        bytes32 script = keccak256("actual nonempty script fixture");
        _script(keccak256("original nonempty script manifest"), script, false, 0);
        StreamConservationFloorTypes.SaleContext memory sale = _sale();
        require(provider.saleRelease(sale).scriptWork, "valid original typed script control");
        IStreamMetadataServingFacts.ServingFacts memory serving = sources.collectionServingFacts(1);
        uint32 originalLength = serving.scriptBytes;
        serving.scriptBytes = 0;
        sources.setServing(serving);
        vm.expectRevert(
            abi.encodeWithSelector(
                StreamNativeConservationFloorProvider.NativeConservationScopeUnavailable.selector
            )
        );
        provider.saleRelease(sale);
        serving.scriptBytes = originalLength;
        serving.scriptHash = keccak256("");
        sources.setServing(serving);
        vm.expectRevert(
            abi.encodeWithSelector(
                StreamNativeConservationFloorProvider.NativeConservationScopeUnavailable.selector
            )
        );
        provider.saleRelease(sale);
    }

    function testProviderUnknownCollectionAndUnallocatedTokenReject() public providerReady {
        vm.expectRevert(
            abi.encodeWithSelector(
                StreamNativeConservationFloorProvider.NativeConservationScopeUnavailable.selector
            )
        );
        provider.requireCollectionFloor(0, _LITE);
        vm.expectRevert(
            abi.encodeWithSelector(
                StreamNativeConservationFloorProvider.NativeConservationScopeUnavailable.selector
            )
        );
        provider.requireCollectionFloor(3, _LITE);
        StreamConservationFloorTypes.SaleContext memory sale = _sale();
        sale.tokenId = 13;
        vm.expectRevert(
            abi.encodeWithSelector(
                StreamNativeConservationFloorProvider.NativeConservationScopeUnavailable.selector
            )
        );
        provider.saleRelease(sale);
        core.setToken(13, address(this), 2);
        require(
            provider.saleRelease(sale).scopeSubject == subject,
            "real typed allocation belongs to correct collection"
        );
    }

    function testProviderCompletedBurnRetainsCollectionReleaseAndRejectsInconsistentIdentity()
        public
        providerReady
    {
        StreamConservationFloorTypes.SaleContext memory sale = _sale();
        sale.tokenId = 13;
        core.setToken(13, address(this), 2);
        StreamConservationFloorTypes.ReleaseContext memory before_ = provider.saleRelease(sale);
        core.setToken(13, address(0), 3);
        StreamConservationFloorTypes.ReleaseContext memory after_ = provider.saleRelease(sale);
        require(
            keccak256(abi.encode(before_)) == keccak256(abi.encode(after_)),
            "completed callback burn retains the entire collection release"
        );
        require(
            provider.requireReleaseFloor(sale, after_, _LITE).mediaEvidenceHash != 0,
            "burn never substitutes for missing release proof"
        );
        cvm.mockCall(
            address(core),
            abi.encodeCall(IStreamCoreIdentity.tokenLifecycle, (sale.tokenId)),
            abi.encode(uint8(2))
        );
        vm.expectRevert(
            abi.encodeWithSelector(
                StreamNativeConservationFloorProvider.NativeConservationScopeUnavailable.selector
            )
        );
        provider.saleRelease(sale);
        cvm.mockCall(
            address(core),
            abi.encodeCall(IStreamCoreIdentity.tokenLifecycle, (sale.tokenId)),
            abi.encode(uint8(3))
        );
        cvm.mockCall(
            address(core),
            abi.encodeCall(IStreamCoreIdentity.tokenCollectionIdentity, (sale.tokenId)),
            abi.encode(true, uint256(2), uint256(13), true)
        );
        vm.expectRevert(
            abi.encodeWithSelector(
                StreamNativeConservationFloorProvider.NativeConservationScopeUnavailable.selector
            )
        );
        provider.saleRelease(sale);
    }

    function testProviderCurrentSelectedOwnerAndMasterOwnerMismatchReject() public providerReady {
        core.setPointer(keccak256("METADATA_ROUTER"), address(schemas));
        vm.expectRevert(
            abi.encodeWithSelector(
                StreamNativeConservationFloorProvider.NativeConservationDependency.selector,
                address(schemas)
            )
        );
        provider.saleRelease(_sale());
        core.setPointer(keccak256("METADATA_ROUTER"), address(sources));
        sources.setOwner(address(schemas));
        vm.expectRevert(
            abi.encodeWithSelector(
                StreamNativeConservationFloorProvider.NativeConservationDependency.selector,
                address(sources)
            )
        );
        provider.saleRelease(_sale());
        sources.setOwner(address(metadata));
        require(provider.saleRelease(_sale()).membershipHash != 0, "exact selected owner retry");
    }

    function testProviderInactiveSelectedOwnerRejected() public providerReady {
        bytes32 role = keccak256("METADATA_ROUTER");
        cvm.mockCall(
            address(core),
            abi.encodeCall(IStreamCorePointers.getSatellitePointer, (role)),
            abi.encode(
                address(sources),
                address(sources).codehash,
                false,
                role,
                bytes4(0),
                address(core),
                uint8(2),
                bytes32(uint256(1)),
                bytes32(uint256(2)),
                uint64(1)
            )
        );
        vm.expectRevert(
            abi.encodeWithSelector(
                StreamNativeConservationFloorProvider.NativeConservationDependency.selector,
                address(sources)
            )
        );
        provider.saleRelease(_sale());
    }

    function testProviderRuntimeMutationRejectsAndOriginalRestorationWorks() public providerReady {
        bytes memory original = address(sources).code;
        vm.etch(address(sources), hex"00");
        vm.expectRevert(
            abi.encodeWithSelector(
                StreamNativeConservationFloorProvider.NativeConservationDependency.selector,
                address(sources)
            )
        );
        provider.saleRelease(_sale());
        vm.etch(address(sources), original);
        require(provider.saleRelease(_sale()).membershipHash != 0, "original runtime restored");
    }

    function testProviderArtistDiagnosticNeverBecomesPersonhoodProof() public providerReady {
        _platformDeclaration(false);
        StreamConservationRecordTypes.Intent memory intent = _intent();
        (bytes32 h,) = _publish(
            IStreamConservationRecordSelection.RecordKind.INTENT,
            StreamArtistIntentJson.serialize(intent),
            1
        );
        selection.adoptIntent(1, subject, h, 0, 0, _intentWitness(h, intent));
        StreamConservationFloorTypes.CollectionFacts memory f = provider.currentCollectionRecords(1);
        require(
            !f.platformWorks && f.rightsRecordHash == rightsHash && f.intentRecordHash == h
                && f.intentWaiverRecordHash == 0 && f.interviewEvidenceHash != 0
                && f.artistId == ARTIST_ID && f.identityRecordHash == IDENTITY
                && f.personhoodEvidenceHash == 0,
            "actual original records are diagnostics only"
        );
        vm.expectRevert(
            abi.encodeWithSelector(
                StreamNativeConservationFloorProvider.NativePersonhoodVerificationUnavailable
                .selector,
                uint256(1),
                ARTIST_ID,
                IDENTITY
            )
        );
        provider.requireCollectionFloor(1, _LITE);
        vm.expectRevert(
            abi.encodeWithSelector(
                StreamNativeConservationFloorProvider.NativePersonhoodVerificationUnavailable
                .selector,
                uint256(1),
                ARTIST_ID,
                IDENTITY
            )
        );
        provider.requireCollectionFloor(1, _FULL);
    }

    function testProviderSemanticReleaseExcludesProviderAndMediaReceiptLocators()
        public
        providerReady
    {
        StreamConservationFloorTypes.SaleContext memory sale = _sale();
        StreamConservationFloorTypes.ReleaseContext memory before_ = provider.saleRelease(sale);
        StreamNativeConservationFloorProvider.Configuration memory c = _configuration();
        c.sourceGas.genesisValue += 1;
        StreamNativeConservationFloorProvider successor =
            new StreamNativeConservationFloorProvider(c);
        StreamConservationFloorTypes.ReleaseContext memory after_ = successor.saleRelease(sale);
        require(
            before_.membershipHash == after_.membershipHash
                && before_.sourceContextHash != after_.sourceContextHash,
            "new provider configuration changes source observation, not semantic release"
        );
        sources.setMedia(keccak256("re-recorded same native media"), sources.inventory(), 0);
        after_ = provider.saleRelease(sale);
        require(
            before_.membershipHash == after_.membershipHash
                && before_.sourceContextHash != after_.sourceContextHash,
            "native manifest locator is not semantic content"
        );
        sources.setMedia(
            sources.manifest(), keccak256("different actual complete media inventory"), 1
        );
        require(
            provider.saleRelease(sale).membershipHash != before_.membershipHash,
            "new actual inventory is new release"
        );
    }

    function testProviderStaleReleaseContextAndUnavailableMasterRefuse() public providerReady {
        StreamConservationFloorTypes.SaleContext memory sale = _sale();
        StreamConservationFloorTypes.ReleaseContext memory r = provider.saleRelease(sale);
        sources.setMedia(keccak256("new source observation"), sources.inventory(), 0);
        vm.expectRevert(
            abi.encodeWithSelector(
                StreamNativeConservationFloorProvider.NativeConservationScopeUnavailable.selector
            )
        );
        provider.requireReleaseFloor(sale, r, _LITE);
        r = provider.saleRelease(sale);
        sources.setMediaUnavailable(true);
        vm.expectRevert(
            abi.encodeWithSelector(
                StreamNativeConservationFloorProvider.NativeConservationRead.selector,
                address(sources),
                IStreamMediaMasterSelection.requireCollectionMasters.selector
            )
        );
        provider.requireReleaseFloor(sale, r, _LITE);
    }

    function testProviderMissingMediaDenominatorCannotMeanEmpty() public providerReady {
        sources.setMedia(bytes32(0), sources.inventory(), 0);
        vm.expectRevert(
            abi.encodeWithSelector(
                StreamNativeConservationFloorProvider.NativeConservationScopeUnavailable.selector
            )
        );
        provider.saleRelease(_sale());
        sources.setMedia(keccak256("manifest"), bytes32(0), 0);
        vm.expectRevert(
            abi.encodeWithSelector(
                StreamNativeConservationFloorProvider.NativeConservationScopeUnavailable.selector
            )
        );
        provider.saleRelease(_sale());
    }

    function testProviderConstructorRejectsBadCorePin() public providerReady {
        StreamNativeConservationFloorProvider.Configuration memory c = _configuration();
        c.codeHashes[0] = keccak256("foreign Core runtime");
        vm.expectRevert(
            abi.encodeWithSelector(
                StreamNativeConservationFloorProvider.InvalidNativeConservationConfiguration
                .selector
            )
        );
        new StreamNativeConservationFloorProvider(c);
    }

    function _artistFloorIntent() private returns (bytes32 hash) {
        _platformDeclaration(false);
        StreamConservationRecordTypes.Intent memory intent = _intent();
        (hash,) = _publish(
            IStreamConservationRecordSelection.RecordKind.INTENT,
            StreamArtistIntentJson.serialize(intent),
            1
        );
        selection.adoptIntent(1, subject, hash, 0, 0, _intentWitness(hash, intent));
    }

    function _typedPersonhood() private view returns (Personhood.Selection memory p) {
        // Exact original owner read boundary only: this test does not execute verified op24.
        p.nativeRecord.recordHash = keccak256("typed original personhood evidence record");
        p.nativeRecord.subjectStateHash = keccak256("operative identity after registration");
        p.nativeRecord.schemaId = PersonhoodDefinitions.EVIDENCE_SCHEMA;
        p.nativeRecord.statementHash = keccak256("typed original retained personhood statement");
        p.nativeRecord.generation = 1;
        p.nativeRecord.signedAt = uint64(block.timestamp);
        p.nativeRecord.signer = ORIGINAL;
        p.sourceRegistry = address(0x011d); // Original imported origin differs from current facade.
        p.evidenceReference = Personhood.Reference(
            1,
            PersonhoodDefinitions.PROFILE_HASH,
            p.sourceRegistry,
            ARTIST_ID,
            p.nativeRecord.subjectStateHash,
            address(store),
            address(store).codehash,
            keccak256("typed original notarization record")
        );
        p.notarizationType = keccak256("INSTITUTIONAL_VERIFICATION");
        p.recorder = address(0x6529);
        p.notarizationHead = p.evidenceReference.notarizationRecordHash;
        p.identityCurrent = true;
        p.notarizationCurrent = true;
        p.status = Personhood.Status.RESOLVED;
    }

    function _mockPersonhood(address owner, Personhood.Selection memory p, bytes32 summary)
        private
    {
        cvm.mockCall(
            owner,
            abi.encodeCall(
                IStreamArtistPersonhoodEvidence.personhoodEvidence, (uint256(1), ARTIST_ID)
            ),
            abi.encode(p)
        );
        cvm.mockCall(
            owner,
            abi.encodeCall(
                IStreamArtistPersonhoodEvidence.personhoodProofSummaryHash,
                (p.nativeRecord.recordHash)
            ),
            abi.encode(summary)
        );
    }

    function testProviderResolvedImportedPersonhoodPreservesOriginalRegistrationAndDiagnostics()
        public
        providerReady
    {
        bytes32 intentHash = _artistFloorIntent();
        Personhood.Selection memory p = _typedPersonhood();
        bytes32 summary = keccak256("typed original verified summary hash");
        require(
            p.nativeRecord.subjectStateHash != IDENTITY && p.sourceRegistry != address(facade),
            "operative identity and imported origin deliberately differ from current registration graph"
        );
        _mockPersonhood(address(attributionOwner), p, summary);
        StreamConservationFloorTypes.CollectionFacts memory lite =
            provider.requireCollectionFloor(1, _LITE);
        StreamConservationFloorTypes.CollectionFacts memory full =
            provider.requireCollectionFloor(1, _FULL);
        require(
            lite.artistId == ARTIST_ID && lite.identityRecordHash == IDENTITY
                && lite.personhoodEvidenceHash == summary && lite.intentRecordHash == intentHash
                && lite.rightsRecordHash == rightsHash && lite.interviewEvidenceHash != 0
                && keccak256(abi.encode(full)) == keccak256(abi.encode(lite)),
            "collection floor adds original personhood commitment without changing registration identity"
        );
        StreamConservationFloorTypes.CollectionFacts memory diagnostic =
            provider.currentCollectionRecords(1);
        require(
            diagnostic.personhoodEvidenceHash == 0 && diagnostic.identityRecordHash == IDENTITY
                && diagnostic.intentRecordHash == intentHash,
            "diagnostic remains zero personhood even when the separate floor is available"
        );
    }

    function testProviderCurrentWaiverSupersedesProofAndStaleWaiverStillRejects()
        public
        providerReady
    {
        _artistFloorIntent();
        Personhood.Selection memory p = _typedPersonhood();
        bytes32 oldSummary = keccak256("previous typed verified summary");
        _mockPersonhood(address(attributionOwner), p, oldSummary);
        require(
            provider.requireCollectionFloor(1, _LITE).personhoodEvidenceHash == oldSummary,
            "initial proof"
        );
        p.nativeRecord.recordHash = keccak256("original selected native waiver");
        p.nativeRecord.schemaId = PersonhoodDefinitions.WAIVER_SCHEMA;
        p.nativeRecord.statementHash = keccak256("original selected waiver statement");
        p.sourceRegistry = address(0);
        Personhood.Reference memory empty;
        p.evidenceReference = empty;
        p.notarizationType = 0;
        p.recorder = address(0);
        p.notarizationHead = 0;
        p.notarizationCurrent = false;
        p.status = Personhood.Status.WAIVER;
        _mockPersonhood(address(attributionOwner), p, 0);
        require(
            provider.requireCollectionFloor(1, _FULL).personhoodEvidenceHash
                == p.nativeRecord.recordHash,
            "selected original waiver succeeds with no documentary summary"
        );
        p.identityCurrent = false;
        p.status = Personhood.Status.STALE;
        _mockPersonhood(address(attributionOwner), p, 0);
        vm.expectRevert(
            abi.encodeWithSelector(
                StreamNativeConservationFloorProvider.NativePersonhoodVerificationUnavailable
                .selector,
                uint256(1),
                ARTIST_ID,
                IDENTITY
            )
        );
        provider.requireCollectionFloor(1, _LITE);
        require(
            provider.currentCollectionRecords(1).personhoodEvidenceHash == 0,
            "retained old summary and stale waiver do not change diagnostics"
        );
    }

    function testProviderRetainedArtistPinsRejectCoherentAttributionOwnerReplacement()
        public
        providerReady
    {
        _artistFloorIntent();
        Personhood.Selection memory p = _typedPersonhood();
        bytes32 summary = keccak256("typed original summary");
        _mockPersonhood(address(attributionOwner), p, summary);
        require(
            provider.requireCollectionFloor(1, _LITE).personhoodEvidenceHash == summary,
            "initial exact graph"
        );
        ConservationSelectionOwnerBoundary replacement = new ConservationSelectionOwnerBoundary();
        replacement.configure(address(core), address(facade), address(coordinator));
        replacement.setBinding(bindingOwner.binding(1), 2);
        _mockPersonhood(address(replacement), p, summary);
        T.SuiteConfiguration memory original = coordinator.suiteConfiguration();
        T.SuiteConfiguration memory changed = coordinator.suiteConfiguration();
        changed.owners[4] = address(replacement);
        coordinator.setSuite(changed);
        vm.expectRevert();
        provider.currentCollectionRecords(1);
        vm.expectRevert();
        provider.requireCollectionFloor(1, _LITE);
        coordinator.setSuite(original);
        require(
            provider.requireCollectionFloor(1, _LITE).personhoodEvidenceHash == summary,
            "original retained conservation graph restores floor"
        );
        bytes memory originalRuntime = address(attributionOwner).code;
        vm.etch(address(attributionOwner), hex"00");
        vm.expectRevert();
        provider.currentCollectionRecords(1);
        vm.etch(address(attributionOwner), originalRuntime);
        require(
            provider.requireCollectionFloor(1, _LITE).personhoodEvidenceHash == summary,
            "restored original Attribution runtime, not newly sampled replacement"
        );
    }

    function testProviderOriginalConfigurationRoundtripAndIndependentCommitment()
        public
        providerReady
    {
        StreamNativeConservationFloorProvider.Configuration memory expected = _configuration();
        StreamNativeConservationFloorProvider.Configuration memory original =
            provider.originalConfiguration();
        require(
            keccak256(abi.encode(original)) == keccak256(abi.encode(expected)),
            "complete original targets, pins, executor and all gas configuration fields"
        );
        require(
            provider.configurationHash()
                == keccak256(
                    abi.encode(
                        keccak256("6529STREAM_NATIVE_CONSERVATION_PROVIDER_V1"),
                        block.chainid,
                        original
                    )
                ),
            "original constructor tuple independently reconstructs immutable configuration hash"
        );
    }

    function testProviderOriginalConfigurationRetainsGenesisAfterAllGovernedGasRaises()
        public
        providerReady
    {
        StreamNativeConservationFloorProvider.Configuration memory original =
            provider.originalConfiguration();
        bytes32 originalHash = provider.configurationHash();
        _raiseProviderGas(provider.READ_GAS(), original.readGas.genesisValue + 1000);
        _raiseProviderGas(provider.SOURCE_GAS(), original.sourceGas.genesisValue + 1000);
        _raiseProviderGas(provider.REFERENCE_GAS(), original.referenceGas.genesisValue + 1000);
        require(
            provider.gasParameter(provider.READ_GAS()) == original.readGas.genesisValue + 1000
                && provider.gasParameter(provider.SOURCE_GAS())
                    == original.sourceGas.genesisValue + 1000
                && provider.gasParameter(provider.REFERENCE_GAS())
                    == original.referenceGas.genesisValue + 1000,
            "actual governed current values raised independently"
        );
        StreamNativeConservationFloorProvider.Configuration memory after_ =
            provider.originalConfiguration();
        require(
            keccak256(abi.encode(after_)) == keccak256(abi.encode(original))
                && provider.configurationHash() == originalHash,
            "getter retains original names, genesis values, floors, failure classes and pins"
        );
        require(
            provider.requireCollectionFloor(1, _LITE).rightsRecordHash == rightsHash,
            "original platform floor remains usable after governed raises"
        );
    }

    function _raiseProviderGas(bytes32 parameter, uint256 nextValue) private {
        (uint256 value, uint256 floor, uint8 failureClass, uint64 revision) =
            provider.gasParameterInfo(parameter);
        bytes32 scope = keccak256(
            abi.encode(
                bytes32(0x9533611d402c2b44cf950a4a8900d25f6829bfac541dc4d5353094f966bb1a71),
                block.chainid,
                address(provider),
                parameter
            )
        );
        bytes32 stateDomain = 0x5059a253d3f7dd63b5d9fd1f0568caf72967f501a3db678b31cefe911334159c;
        bytes32 oldState =
            keccak256(abi.encode(stateDomain, scope, value, floor, failureClass, revision));
        bytes32 nextState = keccak256(
            abi.encode(stateDomain, scope, nextValue, floor, failureClass, revision + uint64(1))
        );
        executor.execute(
            address(provider),
            abi.encodeCall(IStreamGasParameterHost.raiseGasParameter, (parameter, nextValue)),
            scope,
            oldState,
            nextState
        );
    }

    function _script(bytes32 receipt, bytes32 payloadHash, bool chunked, bytes32 libraryBundle)
        private
    {
        bytes32 profile = chunked
            ? keccak256("6529STREAM_ROUTER_CHUNKED_PRESENTATION_V1")
            : keccak256("6529STREAM_ROUTER_STABLE_PRESENTATION_V1");
        IStreamMetadataServingFacts.ServingFacts memory serving;
        serving.configured = true;
        serving.mode = keccak256("ONCHAIN");
        serving.presentationProfile = profile;
        serving.scriptHash = payloadHash;
        serving.scriptBytes = chunked ? 12000 : 60;
        serving.renderer = address(sources);
        serving.rendererCodeHash = address(sources).codehash;
        sources.setServing(serving);
        StreamCollectionManifestTypes.ScriptManifest memory m;
        m.scriptHash = payloadHash;
        m.rendererCompatibility = profile;
        m.sourceType = chunked
            ? StreamCollectionManifestTypes.PayloadSourceType.SSTORE2
            : StreamCollectionManifestTypes.PayloadSourceType.INLINE_CHUNKS;
        m.scriptURI = "ar://original-script";
        m.mimeType = "application/javascript";
        m.chunkCount = chunked ? 2 : 1;
        m.executable = true;
        if (chunked) m.sourcePointer = "typed-native-metadata-bundle-locator";
        cvm.mockCall(
            address(metadata),
            abi.encodeCall(IStreamCollectionManifestReads.scriptManifestHash, (uint256(1))),
            abi.encode(receipt)
        );
        cvm.mockCall(
            address(metadata),
            abi.encodeCall(IStreamCollectionManifestReads.scriptManifest, (uint256(1))),
            abi.encode(m)
        );
        cvm.mockCall(
            address(core),
            abi.encodeCall(IStreamCoreConservationTier.declaredConservationTier, (uint256(1))),
            abi.encode(_LITE)
        );
        if (chunked) {
            bytes32 bundle = keccak256("actual original typed finalized script bundle");
            IStreamScriptBundles.Selection memory selected = IStreamScriptBundles.Selection(
                address(metadata), address(metadata).codehash, bundle, receipt
            );
            IStreamScriptBundles.Facts memory facts = IStreamScriptBundles.Facts(
                payloadHash, libraryBundle, 12000, 2, m.sourceType, false, true
            );
            cvm.mockCall(
                address(sources),
                abi.encodeCall(IStreamScriptBundleSelection.collectionScriptBundle, (uint256(1))),
                abi.encode(selected)
            );
            cvm.mockCall(
                address(metadata),
                abi.encodeCall(IStreamScriptBundles.scriptBundle, (bundle)),
                abi.encode(facts)
            );
        }
    }

    function testProviderLiteScriptSkipsReferenceButFullPresaleIsExplicitlyUnavailable()
        public
        providerReady
    {
        _script(
            keccak256("original selected script manifest"),
            keccak256("actual script content"),
            false,
            0
        );
        StreamConservationFloorTypes.SaleContext memory sale = _sale();
        StreamConservationFloorTypes.ReleaseContext memory r = provider.saleRelease(sale);
        require(r.scriptWork && r.scriptSourceHash != 0, "complete supported script source");
        StreamConservationFloorTypes.ReleaseFacts memory f =
            provider.requireReleaseFloor(sale, r, _LITE);
        require(
            f.mediaEvidenceHash != 0 && f.referenceEvidenceHash == 0,
            "LITE has no script capture prerequisite"
        );
        vm.expectRevert(
            abi.encodeWithSelector(
                StreamNativeConservationFloorProvider.NativePresaleReferenceUnavailable.selector,
                uint256(1)
            )
        );
        provider.requireReleaseFloor(sale, r, _FULL);
        cvm.mockCall(
            address(core),
            abi.encodeCall(IStreamCoreConservationTier.declaredConservationTier, (uint256(1))),
            abi.encode(_FULL)
        );
        require(
            provider.saleRelease(sale).membershipHash == r.membershipHash,
            "mapping remains available for a genuinely recorded identical semantic release"
        );
        vm.expectRevert(
            abi.encodeWithSelector(
                StreamNativeConservationFloorProvider.NativePresaleReferenceUnavailable.selector,
                uint256(1)
            )
        );
        provider.requireReleaseFloor(sale, r, _FULL);
    }

    function testProviderScriptReceiptLocatorExcludedAndActualContentChangesRelease()
        public
        providerReady
    {
        bytes32 payloadHash = keccak256("original actual script content");
        _script(keccak256("first script manifest"), payloadHash, false, 0);
        StreamConservationFloorTypes.ReleaseContext memory before_ = provider.saleRelease(_sale());
        _script(keccak256("successor metadata script manifest"), payloadHash, false, 0);
        StreamConservationFloorTypes.ReleaseContext memory after_ = provider.saleRelease(_sale());
        require(
            before_.membershipHash == after_.membershipHash
                && before_.scriptSourceHash == after_.scriptSourceHash
                && before_.sourceContextHash != after_.sourceContextHash,
            "source receipt changes without semantic change"
        );
        _script(
            keccak256("changed-content manifest"),
            keccak256("different actual script content"),
            false,
            0
        );
        after_ = provider.saleRelease(_sale());
        require(
            before_.membershipHash != after_.membershipHash
                && before_.scriptSourceHash != after_.scriptSourceHash,
            "actual script content changes semantic release"
        );
    }

    function testProviderChunkedScriptRejectsUnenumeratedLibraryEvenWithEmptyLibraryURI()
        public
        providerReady
    {
        _script(
            keccak256("chunked script manifest"), keccak256("complete chunked payload"), true, 0
        );
        require(
            provider.saleRelease(_sale()).scriptSourceHash != 0,
            "original finalized standalone bundle"
        );
        _script(
            keccak256("chunked script manifest"),
            keccak256("complete chunked payload"),
            true,
            keccak256("uncovered actual library bundle")
        );
        vm.expectRevert(
            abi.encodeWithSelector(
                StreamNativeConservationFloorProvider.NativeConservationScopeUnavailable.selector
            )
        );
        provider.saleRelease(_sale());
    }
}
