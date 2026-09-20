// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./StreamConservationSelectionFixture.sol";
import "../../../smart-contracts/domains/metadata/StreamRightsRecordSelection.sol";
import "../../../smart-contracts/domains/metadata/StreamNativeConservationFloorProvider.sol";

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

/// @notice Actual original RIGHTS/Metadata/Schema/Store and conservation selection/receipt checks.
/// @dev Core/Executor, Artist owners/platform declaration, Router, media and script reads are typed
/// boundaries. No real personhood, full native graph or archive execution is claimed by this suite.
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
        core.setToken(13, address(this), 3);
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
        vm.expectRevert(
            abi.encodeWithSelector(
                StreamNativeConservationFloorProvider.NativePresaleReferenceUnavailable.selector,
                uint256(1)
            )
        );
        provider.saleRelease(sale); // Even an existing semantic receipt cannot excuse a now-FULL script gate.
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
