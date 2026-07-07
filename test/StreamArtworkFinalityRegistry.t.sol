// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../smart-contracts/IStreamArtworkFinalityRegistry.sol";
import "../smart-contracts/StreamArtworkFinalityPreview.sol";
import "../smart-contracts/StreamArtworkFinalityRegistry.sol";
import "../smart-contracts/StreamArtworkFinalityTypes.sol";
import "./helpers/Assertions.sol";
import "./helpers/FinalityMocks.sol";
import "./helpers/FinalityTestBase.sol";

/// @notice Five-scope lifecycle, execution-gate, diagnostic, and preview coverage for
///         StreamArtworkFinalityRegistry ([LTA-FINALITY], [CMC-FINALITY-INPUTS],
///         [AA-SANCTION], ADR 0009 decision 6).
contract StreamArtworkFinalityRegistryTest is FinalityTestBase {
    using Assertions for bool;
    using Assertions for bytes32;
    using Assertions for uint256;
    using Assertions for address;
    using Assertions for string;

    event CollectionArtworkFinalized(
        uint16 schemaVersion,
        uint256 indexed collectionId,
        bytes32 indexed finalityRecordHash,
        address indexed actor,
        bytes32 componentsHash,
        bytes32 manifestContentHash,
        string finalityManifestURI
    );

    event ArtworkScopeFinalized(
        uint16 schemaVersion,
        uint8 indexed scopeType,
        uint256 indexed collectionId,
        bytes32 indexed finalityRecordHash,
        uint256 tokenId,
        bytes32 scopeId,
        bytes32 componentsHash,
        bytes32 manifestContentHash,
        string finalityManifestURI
    );

    event FinalityManifestStaged(
        uint16 schemaVersion, bytes32 indexed manifestContentHash, uint256 byteLength, address actor
    );

    event FinalityManifestPointerRecorded(
        uint16 schemaVersion,
        bytes32 indexed finalityRecordHash,
        address manifestPointer,
        bytes32 manifestContentHash
    );

    event ArtworkTerminalFreezeExecuted(
        uint16 schemaVersion,
        bytes32 indexed scopeKey,
        bytes32 indexed finalityRecordHash,
        address executor
    );

    // ------------------------------------------------------------------
    // Construction
    // ------------------------------------------------------------------

    function testConstructorRejectsZeroSeams() public {
        vm.expectRevert(
            abi.encodeWithSelector(StreamArtworkFinalityRegistry.FinalityZeroAddress.selector)
        );
        new StreamArtworkFinalityRegistry(
            address(0), address(metadataMock), address(sanctionMock), address(authority), address(0)
        );
        registry.core().assertEq(address(coreMock), "core binding");
        address(registry.metadataReads()).assertEq(address(metadataMock), "metadata seam");
        address(registry.sanctionReads()).assertEq(address(sanctionMock), "sanction seam");
        address(registry.governanceAuthority()).assertEq(address(authority), "authority seam");
        registry.finalityDiscovery().assertEq(address(0), "discovery unbound at genesis");
    }

    // ------------------------------------------------------------------
    // Manifest staging (requirement 14)
    // ------------------------------------------------------------------

    function testManifestStagingContentAddressedAndBounded() public {
        bytes memory manifestBytes = bytes("canonical manifest");
        bytes32 contentHash = keccak256(manifestBytes);
        registry.finalityManifestStored(contentHash).assertFalse("not staged yet");

        vm.expectEmit(true, true, true, true);
        emit FinalityManifestStaged(1, contentHash, manifestBytes.length, address(this));
        registry.stageFinalityManifest(manifestBytes).assertEq(contentHash, "content hash");

        registry.finalityManifestStored(contentHash).assertTrue("staged");
        string(registry.finalityManifestBytes(contentHash))
            .assertEq("canonical manifest", "typed accessor returns the exact bytes");

        // Idempotent restage: same hash back, no state change.
        registry.stageFinalityManifest(manifestBytes).assertEq(contentHash, "idempotent");

        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamArtworkFinalityRegistry.FinalityManifestBytesInvalid.selector
            )
        );
        registry.stageFinalityManifest("");

        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamArtworkFinalityRegistry.FinalityManifestBytesInvalid.selector
            )
        );
        registry.stageFinalityManifest(new bytes(32_769));
    }

    // ------------------------------------------------------------------
    // Collection lifecycle
    // ------------------------------------------------------------------

    function testCollectionLifecycleArtistBound() public {
        Fixture memory fixture = _buildFixture(_collectionScope(COLLECTION_ID), true);
        _scheduleAndOpen(fixture);

        // Preview parity before execution ([AA-SANCTION] requirement 2).
        StreamFinalityPreview memory p = previewer.previewCollectionFinality(
            COLLECTION_ID, fixture.components, fixture.manifest
        );
        p.wouldExecute.assertTrue("preview would execute");
        p.stagedFreezeReady.assertTrue("staged freeze ready");
        p.computedFinalityRecordHash
            .assertEq(fixture.expectedFinalityRecordHash, "preview record hash");
        p.computedSanctionSubjectHash
            .assertEq(fixture.sanctionSubjectHash, "preview exposes the sanction subject hash");
        p.computedComponentsHash.assertEq(fixture.componentsHash, "preview components hash");
        p.computedCoreFactsHash.assertEq(fixture.coreFactsHash, "preview core facts hash");

        // Execution emits the spec event shapes with schemaVersion 1.
        vm.expectEmit(true, true, true, true);
        emit CollectionArtworkFinalized(
            1,
            COLLECTION_ID,
            fixture.expectedFinalityRecordHash,
            finalityAdmin,
            fixture.componentsHash,
            fixture.manifest.contentHash,
            fixture.manifest.uri
        );
        vm.expectEmit(true, true, true, true);
        emit FinalityManifestPointerRecorded(
            1, fixture.expectedFinalityRecordHash, address(registry), fixture.manifest.contentHash
        );
        vm.expectEmit(true, true, true, true);
        emit ArtworkTerminalFreezeExecuted(
            1, fixture.scopeKey, fixture.expectedFinalityRecordHash, finalityAdmin
        );
        _finalizeFixtureCall(fixture);

        _assertStoredCollectionRecord(fixture);
        _assertComponentPagination(fixture);
        _assertHealthyDiagnostics(fixture);
        _assertFrozenRoutes(fixture);
        _assertCollectionImmutability(fixture);
    }

    function _assertStoredCollectionRecord(Fixture memory fixture) private {
        StreamCollectionFinalityRecord memory record =
            registry.collectionFinalityRecord(COLLECTION_ID);
        record.finalized.assertTrue("finalized");
        record.finalityRecordHash.assertEq(fixture.expectedFinalityRecordHash, "record hash");
        record.componentsHash.assertEq(fixture.componentsHash, "components hash");
        record.manifestContentHash.assertEq(fixture.manifest.contentHash, "manifest content");
        record.manifestURIHash.assertEq(fixture.manifest.uriHash, "manifest uri hash");
        record.finalityManifestURI.assertEq(fixture.manifest.uri, "manifest uri");
        record.manifestPointer.assertEq(address(registry), "manifest pointer in registry storage");
        uint256(record.finalizedAt).assertEq(block.timestamp, "finalizedAt");

        // The scoped read mirror serves the COLLECTION scope.
        StreamScopedFinalityRecord memory mirrored =
            registry.artworkScopeFinalityRecord(fixture.scope);
        mirrored.finalized.assertTrue("mirrored finalized");
        mirrored.finalityRecordHash.assertEq(fixture.expectedFinalityRecordHash, "mirrored hash");
        uint256(uint8(mirrored.scope.scopeType))
            .assertEq(uint256(uint8(StreamFinalityScopeType.COLLECTION)), "mirrored scope type");
    }

    function _assertComponentPagination(Fixture memory fixture) private {
        uint256 total = fixture.components.length; // base fixture: 6 mandatory + 1 sanction
        registry.finalityComponentCount(COLLECTION_ID).assertEq(total, "component count");
        StreamFinalityComponentExpectation[] memory page =
            registry.finalityComponents(COLLECTION_ID, 1, 1);
        page.length.assertEq(1, "page size");
        page[0].componentType.assertEq(fixture.components[1].componentType, "page content");
        registry.finalityComponents(COLLECTION_ID, total, 5).length.assertEq(0, "past-end page");
        registry.finalityComponents(COLLECTION_ID, 0, 0).length.assertEq(0, "zero limit");
    }

    function _assertHealthyDiagnostics(Fixture memory fixture) private {
        (bool matches, bytes32 recHash, bytes32 compHash) = registry.verifyFinality(COLLECTION_ID);
        matches.assertTrue("route matches");
        recHash.assertEq(fixture.expectedFinalityRecordHash, "verify record hash");
        compHash.assertEq(fixture.componentsHash, "verify components hash");
        registry.finalityStillMatches(COLLECTION_ID).assertTrue("still matches");
    }

    function _assertFrozenRoutes(Fixture memory fixture) private {
        (bool pinned, address module, bytes32 routeHash, bytes32 routeRecordHash) =
            registry.frozenRouteForScope(StreamFinalityDomains.COMPONENT_RENDERER, fixture.scope);
        pinned.assertTrue("route pinned");
        module.assertEq(address(rendererComponent), "route module");
        routeRecordHash.assertEq(fixture.expectedFinalityRecordHash, "route record hash");
        (routeHash != bytes32(0)).assertTrue("route hash nonzero");
        // OPTIONAL_SNAPSHOT_ROUTE is not in a base fixture, so it is a genuinely absent route.
        (bool unpinned,,, bytes32 stillRecord) = registry.frozenRouteForScope(
            StreamFinalityDomains.COMPONENT_OPTIONAL_SNAPSHOT_ROUTE, fixture.scope
        );
        unpinned.assertFalse("absent route type unpinned");
        stillRecord.assertEq(fixture.expectedFinalityRecordHash, "record hash still returned");
    }

    function _assertCollectionImmutability(Fixture memory fixture) private {
        uint256(uint8(registry.artworkTerminalFreezeAction(fixture.scope).status))
            .assertEq(uint256(uint8(StreamTerminalFreezeStatus.EXECUTED)), "action executed");
        vm.prank(finalityAdmin);
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamArtworkFinalityRegistry.FinalityAlreadyFinalized.selector, fixture.scopeKey
            )
        );
        registry.finalizeCollectionArtwork(
            COLLECTION_ID, fixture.components, fixture.expectedFinalityRecordHash, fixture.manifest
        );
    }

    function testCollectionLifecyclePlatformWorks() public {
        Fixture memory fixture = _buildFixture(_collectionScope(COLLECTION_ID), false);
        _executeFixture(fixture);
        registry.collectionFinalityRecord(COLLECTION_ID).finalized
            .assertTrue("platform-works collection finalized without sanction verification");
        // The declaration component is bound inside componentsHash like any component.
        (bool pinned, address module,,) = registry.frozenRouteForScope(
            StreamFinalityDomains.COMPONENT_PLATFORM_WORKS_DECLARATION, fixture.scope
        );
        pinned.assertTrue("declaration pinned");
        module.assertEq(address(sanctionComponent), "declaration module");
    }

    // ------------------------------------------------------------------
    // Scoped lifecycles (TOKEN, RELEASE, SEASON, VIEW)
    // ------------------------------------------------------------------

    function testTokenScopeLifecycle() public {
        StreamFinalityScope memory scope = _tokenScope(COLLECTION_ID, 4321);
        Fixture memory fixture = _buildFixture(scope, true);
        _scheduleAndOpen(fixture);

        vm.expectEmit(true, true, true, true);
        emit ArtworkScopeFinalized(
            1,
            uint8(StreamFinalityScopeType.TOKEN),
            COLLECTION_ID,
            fixture.expectedFinalityRecordHash,
            4321,
            bytes32(0),
            fixture.componentsHash,
            fixture.manifest.contentHash,
            fixture.manifest.uri
        );
        _finalizeFixtureCall(fixture);

        StreamScopedFinalityRecord memory record = registry.artworkScopeFinalityRecord(scope);
        record.finalized.assertTrue("token record finalized");
        record.finalityRecordHash.assertEq(fixture.expectedFinalityRecordHash, "token record hash");
        record.scope.tokenId.assertEq(4321, "token id echo");
        record.manifestPointer.assertEq(address(registry), "manifest pointer");

        (bool matches, bytes32 recHash,) = registry.verifyArtworkScopeFinality(scope);
        matches.assertTrue("scoped route matches");
        recHash.assertEq(fixture.expectedFinalityRecordHash, "scoped verify hash");

        uint256 total = fixture.components.length;
        registry.finalityComponentCountForScope(scope).assertEq(total, "scoped component count");
        registry.finalityComponentsForScope(scope, 0, 20).length.assertEq(total, "scoped page");

        // The collection itself is untouched.
        registry.collectionFinalityRecord(COLLECTION_ID).finalized
            .assertFalse("collection not finalized by token finality");

        // Immutability at the exact scope.
        vm.prank(finalityAdmin);
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamArtworkFinalityRegistry.FinalityAlreadyFinalized.selector, fixture.scopeKey
            )
        );
        registry.finalizeArtworkScope(
            scope, fixture.components, fixture.expectedFinalityRecordHash, fixture.manifest
        );
    }

    function testReleaseSeasonViewScopeLifecycles() public {
        StreamFinalityScopeType[3] memory scopeTypes = [
            StreamFinalityScopeType.RELEASE,
            StreamFinalityScopeType.SEASON,
            StreamFinalityScopeType.VIEW
        ];
        for (uint256 i = 0; i < scopeTypes.length; i++) {
            StreamFinalityScope memory scope = _idScope(
                scopeTypes[i], COLLECTION_ID, keccak256(abi.encodePacked("scope-id", i))
            );
            Fixture memory fixture = _buildFixture(scope, true);
            _executeFixture(fixture);
            StreamScopedFinalityRecord memory record = registry.artworkScopeFinalityRecord(scope);
            record.finalized.assertTrue("scoped record finalized");
            record.finalityRecordHash
                .assertEq(fixture.expectedFinalityRecordHash, "scoped record hash");
            record.scope.scopeId.assertEq(scope.scopeId, "scope id echo");
            (bool matches,,) = registry.verifyArtworkScopeFinality(scope);
            matches.assertTrue("scoped verify");
        }
    }

    function testScopedEntryRejectsCollectionScopeAndBadShapes() public {
        Fixture memory fixture = _buildFixture(_collectionScope(COLLECTION_ID), true);
        vm.prank(finalityAdmin);
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamArtworkFinalityRegistry.FinalityScopeUsesCollectionEntry.selector
            )
        );
        registry.finalizeArtworkScope(
            fixture.scope, fixture.components, fixture.expectedFinalityRecordHash, fixture.manifest
        );

        // TOKEN scope with a nonzero scopeId is malformed (scope rule 2).
        StreamFinalityScope memory malformed = _tokenScope(COLLECTION_ID, 5);
        malformed.scopeId = keccak256("unexpected");
        vm.prank(finalityAdmin);
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamArtworkFinalityRegistry.FinalityScopeShapeInvalid.selector
            )
        );
        registry.finalizeArtworkScope(
            malformed, fixture.components, fixture.expectedFinalityRecordHash, fixture.manifest
        );

        // RELEASE scope requires a nonzero scopeId (scope rule 3).
        StreamFinalityScope memory releaseScope =
            _idScope(StreamFinalityScopeType.RELEASE, COLLECTION_ID, bytes32(0));
        vm.prank(finalityAdmin);
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamArtworkFinalityRegistry.FinalityScopeShapeInvalid.selector
            )
        );
        registry.finalizeArtworkScope(
            releaseScope, fixture.components, fixture.expectedFinalityRecordHash, fixture.manifest
        );
    }

    function testScopedGatesScopeExistenceAndTokenLifecycle() public {
        StreamFinalityScope memory scope = _tokenScope(COLLECTION_ID, 77);
        Fixture memory fixture = _buildFixture(scope, true);
        _scheduleAndOpen(fixture);

        // scopeExists = false blocks.
        StreamScopedCoreFinalityFacts memory facts = _scopedFactsFor(scope);
        facts.scopeExists = false;
        coreMock.setScopedFacts(scope, facts);
        vm.prank(finalityAdmin);
        vm.expectRevert(
            abi.encodeWithSelector(IStreamArtworkFinalityRegistry.FinalityScopeUnknown.selector)
        );
        registry.finalizeArtworkScope(
            scope, fixture.components, fixture.expectedFinalityRecordHash, fixture.manifest
        );

        // A prepared-incomplete token is not a minted-or-burned token (scope rule 2).
        facts = _scopedFactsFor(scope);
        facts.tokenLifecycle = 1; // PREPARED_INCOMPLETE
        coreMock.setScopedFacts(scope, facts);
        vm.prank(finalityAdmin);
        vm.expectRevert(
            abi.encodeWithSelector(IStreamArtworkFinalityRegistry.FinalityTokenNotInScope.selector)
        );
        registry.finalizeArtworkScope(
            scope, fixture.components, fixture.expectedFinalityRecordHash, fixture.manifest
        );

        // Echoed scope fields must match the queried scope.
        facts = _scopedFactsFor(scope);
        facts.collectionId = COLLECTION_ID + 1;
        coreMock.setScopedFacts(scope, facts);
        vm.prank(finalityAdmin);
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamArtworkFinalityRegistry.FinalityScopedFactsMismatch.selector
            )
        );
        registry.finalizeArtworkScope(
            scope, fixture.components, fixture.expectedFinalityRecordHash, fixture.manifest
        );

        // A BURNED token still finalizes (burn-surviving archival identity), after the facts
        // change is rebound into the staged hash.
        facts = _scopedFactsFor(scope);
        facts.tokenLifecycle = StreamFinalityDomains.TOKEN_LIFECYCLE_BURNED;
        facts.burned = true;
        coreMock.setScopedFacts(scope, facts);
        fixture.coreFactsHash = registry.computeScopedCoreFactsHash(scope);
        _recomputeFixtureHashes(fixture, true);
        vm.prank(finalityAdmin);
        registry.cancelArtworkTerminalFreeze(scope, keccak256("rebind"));
        _executeFixture(fixture);
        registry.artworkScopeFinalityRecord(scope).finalized.assertTrue("burned token finalized");
    }

    function testTokenScopeRequiresExactlyOneLeaf() public {
        StreamFinalityScope memory scope = _tokenScope(COLLECTION_ID, 88);
        Fixture memory fixture = _buildFixture(scope, true);
        metadataMock.setContentRoot(
            COLLECTION_ID,
            registry.contentRootScopeSubject(scope),
            keccak256("root"),
            2, // must be exactly 1 for TOKEN scope
            keccak256("schema")
        );
        _scheduleAndOpen(fixture);
        vm.prank(finalityAdmin);
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamArtworkFinalityRegistry.FinalityContentRootLeafCountMismatch.selector,
                uint64(1),
                uint64(2)
            )
        );
        registry.finalizeArtworkScope(
            scope, fixture.components, fixture.expectedFinalityRecordHash, fixture.manifest
        );
    }

    // ------------------------------------------------------------------
    // Collection execution gates (negative matrix)
    // ------------------------------------------------------------------

    function testFinalizeRequiresFinalityAdmin() public {
        Fixture memory fixture = _buildFixture(_collectionScope(COLLECTION_ID), true);
        _scheduleAndOpen(fixture);
        vm.prank(outsider);
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamArtworkFinalityRegistry.FinalityCallerNotFinalityAdmin.selector, outsider
            )
        );
        registry.finalizeCollectionArtwork(
            COLLECTION_ID, fixture.components, fixture.expectedFinalityRecordHash, fixture.manifest
        );
    }

    function testCollectionGatesExistenceClosedAndBurnBlock() public {
        Fixture memory fixture = _buildFixture(_collectionScope(COLLECTION_ID), true);
        // Snapshot the fixture's exact facts before warping: createdAt is timestamp-derived,
        // and the staged record hash binds the facts hash byte-for-byte.
        StreamCoreCollectionFinalityFacts memory original = _closedCollectionFacts(COLLECTION_ID);
        _scheduleAndOpen(fixture);

        // Unknown collection.
        StreamCoreCollectionFinalityFacts memory facts = _closedCollectionFacts(COLLECTION_ID);
        facts.exists = false;
        coreMock.setCollectionFacts(COLLECTION_ID, facts);
        vm.prank(finalityAdmin);
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamArtworkFinalityRegistry.FinalityCollectionUnknown.selector, COLLECTION_ID
            )
        );
        registry.finalizeCollectionArtwork(
            COLLECTION_ID, fixture.components, fixture.expectedFinalityRecordHash, fixture.manifest
        );

        // ACTIVE (not CLOSED) blocks: CLOSED alone is the minting boundary (requirement 7).
        facts = _cloneFacts(original);
        facts.status = 0;
        coreMock.setCollectionFacts(COLLECTION_ID, facts);
        vm.prank(finalityAdmin);
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamArtworkFinalityRegistry.FinalityCollectionNotClosed.selector,
                COLLECTION_ID,
                uint8(0)
            )
        );
        registry.finalizeCollectionArtwork(
            COLLECTION_ID, fixture.components, fixture.expectedFinalityRecordHash, fixture.manifest
        );

        // CLOSED without the one-way burn block still blocks ([CMC-BURN] rule 7).
        coreMock.setCollectionFacts(COLLECTION_ID, original);
        coreMock.setBurnsBlocked(COLLECTION_ID, false, 0);
        vm.prank(finalityAdmin);
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamArtworkFinalityRegistry.FinalityCollectionBurnsNotBlocked.selector,
                COLLECTION_ID
            )
        );
        registry.finalizeCollectionArtwork(
            COLLECTION_ID, fixture.components, fixture.expectedFinalityRecordHash, fixture.manifest
        );

        // Restore and execute to prove the gate matrix was the only blocker.
        coreMock.setBurnsBlocked(COLLECTION_ID, true, uint64(block.number));
        _finalizeFixtureCall(fixture);
        registry.collectionFinalityRecord(COLLECTION_ID).finalized.assertTrue("finalized");
    }

    function testContentRootGates() public {
        Fixture memory fixture = _buildFixture(_collectionScope(COLLECTION_ID), true);
        bytes32 scopeSubject = registry.contentRootScopeSubject(fixture.scope);
        _scheduleAndOpen(fixture);

        // Missing root blocks every scope in every metadata mode (requirement 6).
        metadataMock.setContentRoot(COLLECTION_ID, scopeSubject, bytes32(0), 0, bytes32(0));
        vm.prank(finalityAdmin);
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamArtworkFinalityRegistry.FinalityContentRootMissing.selector, scopeSubject
            )
        );
        registry.finalizeCollectionArtwork(
            COLLECTION_ID, fixture.components, fixture.expectedFinalityRecordHash, fixture.manifest
        );

        // Leaf count must equal minted-ever for collection scope.
        metadataMock.setContentRoot(
            COLLECTION_ID, scopeSubject, keccak256("root"), MINTED_SUPPLY - 1, keccak256("schema")
        );
        vm.prank(finalityAdmin);
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamArtworkFinalityRegistry.FinalityContentRootLeafCountMismatch.selector,
                MINTED_SUPPLY,
                MINTED_SUPPLY - 1
            )
        );
        registry.finalizeCollectionArtwork(
            COLLECTION_ID, fixture.components, fixture.expectedFinalityRecordHash, fixture.manifest
        );

        // Preview reports the same failing gate without reverting.
        StreamFinalityPreview memory p = previewer.previewCollectionFinality(
            COLLECTION_ID, fixture.components, fixture.manifest
        );
        p.contentRootSatisfied.assertFalse("preview content root gate");
        p.wouldExecute.assertFalse("preview would not execute");
    }

    function _cloneFacts(StreamCoreCollectionFinalityFacts memory facts)
        private
        pure
        returns (StreamCoreCollectionFinalityFacts memory)
    {
        return StreamCoreCollectionFinalityFacts({
            exists: facts.exists,
            hasMaxSupply: facts.hasMaxSupply,
            status: facts.status,
            supplyMode: facts.supplyMode,
            createdAt: facts.createdAt,
            maxSupply: facts.maxSupply,
            mintedSupply: facts.mintedSupply,
            burnedSupply: facts.burnedSupply,
            nextCollectionSerial: facts.nextCollectionSerial,
            collectionConfigHash: facts.collectionConfigHash
        });
    }

    function _cloneManifest(StreamFinalityManifestRef memory manifest)
        private
        pure
        returns (StreamFinalityManifestRef memory)
    {
        return StreamFinalityManifestRef({
            uri: manifest.uri,
            uriHash: manifest.uriHash,
            contentHash: manifest.contentHash,
            schemaId: manifest.schemaId,
            canonicalizationHash: manifest.canonicalizationHash
        });
    }

    function _cloneComponents(StreamFinalityComponentExpectation[] memory components)
        private
        pure
        returns (StreamFinalityComponentExpectation[] memory cloned)
    {
        cloned = new StreamFinalityComponentExpectation[](components.length);
        for (uint256 i = 0; i < components.length; i++) {
            cloned[i] = StreamFinalityComponentExpectation({
                componentType: components[i].componentType,
                component: components[i].component,
                interfaceId: components[i].interfaceId,
                codeHash: components[i].codeHash,
                moduleVersion: components[i].moduleVersion,
                manifestHash: components[i].manifestHash,
                dataHash: components[i].dataHash
            });
        }
    }

    function testManifestGates() public {
        Fixture memory fixture = _buildFixture(_collectionScope(COLLECTION_ID), true);
        _scheduleAndOpen(fixture);

        // uriHash must recompute from the uri string.
        StreamFinalityManifestRef memory badManifest = _cloneManifest(fixture.manifest);
        badManifest.uriHash = keccak256("some other uri");
        vm.prank(finalityAdmin);
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamArtworkFinalityRegistry.FinalityManifestURIHashMismatch.selector,
                keccak256(bytes(fixture.manifest.uri)),
                badManifest.uriHash
            )
        );
        registry.finalizeCollectionArtwork(
            COLLECTION_ID, fixture.components, fixture.expectedFinalityRecordHash, badManifest
        );

        // Zero schema / canonicalization / content hash all block.
        badManifest = _cloneManifest(fixture.manifest);
        badManifest.schemaId = bytes32(0);
        vm.prank(finalityAdmin);
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamArtworkFinalityRegistry.FinalityManifestFieldZero.selector
            )
        );
        registry.finalizeCollectionArtwork(
            COLLECTION_ID, fixture.components, fixture.expectedFinalityRecordHash, badManifest
        );

        // Manifest bytes must already live in registry storage (requirement 14).
        badManifest = _cloneManifest(fixture.manifest);
        badManifest.contentHash = keccak256("never staged bytes");
        vm.prank(finalityAdmin);
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamArtworkFinalityRegistry.FinalityManifestBytesMissing.selector,
                badManifest.contentHash
            )
        );
        registry.finalizeCollectionArtwork(
            COLLECTION_ID, fixture.components, fixture.expectedFinalityRecordHash, badManifest
        );
    }

    function testComponentListShapeGates() public {
        Fixture memory fixture = _buildFixture(_collectionScope(COLLECTION_ID), true);
        _scheduleAndOpen(fixture);

        // Unsorted list reverts before any state is written.
        StreamFinalityComponentExpectation[] memory unsorted =
            new StreamFinalityComponentExpectation[](3);
        unsorted[0] = fixture.components[1];
        unsorted[1] = fixture.components[0];
        unsorted[2] = fixture.components[2];
        vm.prank(finalityAdmin);
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamArtworkFinalityRegistry.FinalityComponentsUnsorted.selector, uint256(1)
            )
        );
        registry.finalizeCollectionArtwork(
            COLLECTION_ID, unsorted, fixture.expectedFinalityRecordHash, fixture.manifest
        );

        // Duplicate full-identity tuples revert.
        StreamFinalityComponentExpectation[] memory duplicated =
            new StreamFinalityComponentExpectation[](2);
        duplicated[0] = fixture.components[0];
        duplicated[1] = fixture.components[0];
        vm.prank(finalityAdmin);
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamArtworkFinalityRegistry.FinalityComponentsUnsorted.selector, uint256(1)
            )
        );
        registry.finalizeCollectionArtwork(
            COLLECTION_ID, duplicated, fixture.expectedFinalityRecordHash, fixture.manifest
        );

        // Empty and over-cap lists revert.
        StreamFinalityComponentExpectation[] memory empty;
        vm.prank(finalityAdmin);
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamArtworkFinalityRegistry.FinalityComponentCountInvalid.selector,
                uint256(0),
                uint256(32)
            )
        );
        registry.finalizeCollectionArtwork(
            COLLECTION_ID, empty, fixture.expectedFinalityRecordHash, fixture.manifest
        );

        StreamFinalityComponentExpectation[] memory tooMany =
            new StreamFinalityComponentExpectation[](33);
        vm.prank(finalityAdmin);
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamArtworkFinalityRegistry.FinalityComponentCountInvalid.selector,
                uint256(33),
                uint256(32)
            )
        );
        registry.finalizeCollectionArtwork(
            COLLECTION_ID, tooMany, fixture.expectedFinalityRecordHash, fixture.manifest
        );
    }

    function testSanctionComponentGates() public {
        Fixture memory fixture = _buildFixture(_collectionScope(COLLECTION_ID), true);
        _scheduleAndOpen(fixture);

        // Missing sanction/declaration component is nonconformant (requirement 9). Removing the
        // one sanction slot leaves the six mandatory components intact, so the mandatory floor
        // passes and the sanction-missing revert fires.
        StreamFinalityComponentExpectation[] memory withoutSanction =
            new StreamFinalityComponentExpectation[](fixture.components.length - 1);
        uint256 cursor = 0;
        for (uint256 i = 0; i < fixture.components.length; i++) {
            if (
                fixture.components[i].componentType
                    != StreamFinalityDomains.COMPONENT_ARTIST_SANCTION
            ) {
                withoutSanction[cursor] = fixture.components[i];
                cursor++;
            }
        }
        vm.prank(finalityAdmin);
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamArtworkFinalityRegistry.FinalitySanctionComponentMissing.selector
            )
        );
        registry.finalizeCollectionArtwork(
            COLLECTION_ID, withoutSanction, fixture.expectedFinalityRecordHash, fixture.manifest
        );

        // Carrying both ARTIST_SANCTION and PLATFORM_WORKS_DECLARATION is nonconformant.
        MockFinalityComponent declarationComponent = new MockFinalityComponent();
        StreamFinalityComponentExpectation memory declarationEntry = _expectationFor(
            declarationComponent,
            StreamFinalityDomains.COMPONENT_PLATFORM_WORKS_DECLARATION,
            keccak256("declaration")
        );
        _installComponentState(fixture.scope, declarationEntry);
        StreamFinalityComponentExpectation[] memory both =
            new StreamFinalityComponentExpectation[](fixture.components.length + 1);
        for (uint256 i = 0; i < fixture.components.length; i++) {
            both[i] = fixture.components[i];
        }
        both[fixture.components.length] = declarationEntry;
        both = _sortComponents(both);
        vm.prank(finalityAdmin);
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamArtworkFinalityRegistry.FinalitySanctionComponentDuplicated.selector
            )
        );
        registry.finalizeCollectionArtwork(
            COLLECTION_ID, both, fixture.expectedFinalityRecordHash, fixture.manifest
        );

        // The wrong component type for the collection's binding state blocks.
        sanctionMock.setRequiredComponentType(
            COLLECTION_ID, StreamFinalityDomains.COMPONENT_PLATFORM_WORKS_DECLARATION
        );
        vm.prank(finalityAdmin);
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamArtworkFinalityRegistry.FinalitySanctionComponentWrongType.selector,
                StreamFinalityDomains.COMPONENT_PLATFORM_WORKS_DECLARATION,
                StreamFinalityDomains.COMPONENT_ARTIST_SANCTION
            )
        );
        registry.finalizeCollectionArtwork(
            COLLECTION_ID, fixture.components, fixture.expectedFinalityRecordHash, fixture.manifest
        );
        sanctionMock.setRequiredComponentType(
            COLLECTION_ID, StreamFinalityDomains.COMPONENT_ARTIST_SANCTION
        );

        // An unverified sanction blocks: no unsigned finalization path (requirement 9).
        sanctionMock.setSanctionResponse(
            uint8(fixture.scope.scopeType),
            COLLECTION_ID,
            0,
            bytes32(0),
            fixture.sanctionSubjectHash,
            false,
            fixture.sanctionRecordHash
        );
        vm.prank(finalityAdmin);
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamArtworkFinalityRegistry.FinalitySanctionInvalid.selector,
                fixture.sanctionSubjectHash
            )
        );
        registry.finalizeCollectionArtwork(
            COLLECTION_ID, fixture.components, fixture.expectedFinalityRecordHash, fixture.manifest
        );

        // A verified sanction whose record hash differs from the component dataHash blocks.
        sanctionMock.setSanctionResponse(
            uint8(fixture.scope.scopeType),
            COLLECTION_ID,
            0,
            bytes32(0),
            fixture.sanctionSubjectHash,
            true,
            keccak256("some other sanction record")
        );
        vm.prank(finalityAdmin);
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamArtworkFinalityRegistry.FinalitySanctionRecordHashMismatch.selector,
                fixture.sanctionRecordHash,
                keccak256("some other sanction record")
            )
        );
        registry.finalizeCollectionArtwork(
            COLLECTION_ID, fixture.components, fixture.expectedFinalityRecordHash, fixture.manifest
        );

        // Restoring the verified response lets execution pass: the sanction subject hash the
        // registry computed matched the fixture's, or the keyed mock could not have answered.
        sanctionMock.setSanctionResponse(
            uint8(fixture.scope.scopeType),
            COLLECTION_ID,
            0,
            bytes32(0),
            fixture.sanctionSubjectHash,
            true,
            fixture.sanctionRecordHash
        );
        _finalizeFixtureCall(fixture);
        registry.collectionFinalityRecord(COLLECTION_ID).finalized.assertTrue("finalized");
    }

    function testLiveComponentVerificationGates() public {
        Fixture memory fixture = _buildFixture(_collectionScope(COLLECTION_ID), true);
        _scheduleAndOpen(fixture);

        // frozen = false blocks (requirement 1: every module must report frozen state).
        StreamFinalityComponentState memory thawed = _stateFor(fixture.components[1]);
        thawed.frozen = false;
        MockFinalityComponent(fixture.components[1].component)
            .setCollectionState(COLLECTION_ID, thawed);
        vm.prank(finalityAdmin);
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamArtworkFinalityRegistry.FinalityComponentMismatch.selector, uint256(1)
            )
        );
        registry.finalizeCollectionArtwork(
            COLLECTION_ID, fixture.components, fixture.expectedFinalityRecordHash, fixture.manifest
        );

        // dataHash drift blocks.
        StreamFinalityComponentState memory drifted = _stateFor(fixture.components[1]);
        drifted.dataHash = keccak256("drifted");
        MockFinalityComponent(fixture.components[1].component)
            .setCollectionState(COLLECTION_ID, drifted);
        vm.prank(finalityAdmin);
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamArtworkFinalityRegistry.FinalityComponentMismatch.selector, uint256(1)
            )
        );
        registry.finalizeCollectionArtwork(
            COLLECTION_ID, fixture.components, fixture.expectedFinalityRecordHash, fixture.manifest
        );
        MockFinalityComponent(fixture.components[1].component)
            .setCollectionState(COLLECTION_ID, _stateFor(fixture.components[1]));

        // A reverting component read blocks recording (stricter than diagnostics).
        MockFinalityComponent(fixture.components[0].component).setMode(1);
        vm.prank(finalityAdmin);
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamArtworkFinalityRegistry.FinalityComponentUnreadable.selector, uint256(0)
            )
        );
        registry.finalizeCollectionArtwork(
            COLLECTION_ID, fixture.components, fixture.expectedFinalityRecordHash, fixture.manifest
        );
        MockFinalityComponent(fixture.components[0].component).setMode(0);

        // A codeHash expectation that no longer matches the deployed code blocks. The mutated
        // entry is the sanction slot (sorted index 0): sanction entries are excluded from the
        // subject hash, so the code-hash gate is reached rather than the sanction gate — for
        // any non-sanction entry the sanction invalidates first, which is the spec's intent
        // (the artist signed those exact components).
        StreamFinalityComponentExpectation[] memory reHashed = _cloneComponents(fixture.components);
        reHashed[0].codeHash = keccak256("not the deployed code hash");
        vm.prank(finalityAdmin);
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamArtworkFinalityRegistry.FinalityComponentCodeHashMismatch.selector,
                uint256(0)
            )
        );
        registry.finalizeCollectionArtwork(
            COLLECTION_ID, reHashed, fixture.expectedFinalityRecordHash, fixture.manifest
        );

        // A component address with no code blocks.
        StreamFinalityComponentExpectation[] memory codeless = _cloneComponents(fixture.components);
        codeless[0].component = address(0xDEAD);
        codeless = _sortComponents(codeless);
        uint256 codelessIndex = 0;
        for (uint256 i = 0; i < codeless.length; i++) {
            if (codeless[i].component == address(0xDEAD)) {
                codelessIndex = i;
            }
        }
        vm.prank(finalityAdmin);
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamArtworkFinalityRegistry.FinalityComponentUnreadable.selector, codelessIndex
            )
        );
        registry.finalizeCollectionArtwork(
            COLLECTION_ID, codeless, fixture.expectedFinalityRecordHash, fixture.manifest
        );
    }

    function testExpectedRecordHashMismatchBlocks() public {
        Fixture memory fixture = _buildFixture(_collectionScope(COLLECTION_ID), true);
        // Stage a hash that will not match the recomputation: both staged and supplied agree,
        // so the staged-hash gate passes and the recomputation gate must catch it.
        bytes32 wrongHash = keccak256("wrong expected record hash");
        uint64 notBefore = uint64(block.timestamp) + registry.TERMINAL_FREEZE_VETO_FLOOR();
        uint64 expiresAfter = notBefore + registry.TERMINAL_FREEZE_EXECUTION_WINDOW_FLOOR();
        vm.prank(finalityAdmin);
        registry.scheduleArtworkTerminalFreeze(fixture.scope, wrongHash, notBefore, expiresAfter);
        vm.warp(notBefore);
        vm.prank(finalityAdmin);
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamArtworkFinalityRegistry.FinalityExpectedRecordHashMismatch.selector,
                wrongHash,
                fixture.expectedFinalityRecordHash
            )
        );
        registry.finalizeCollectionArtwork(
            COLLECTION_ID, fixture.components, wrongHash, fixture.manifest
        );
    }

    // ------------------------------------------------------------------
    // Facade identity binding (requirement 16, [CMC-FINALITY-INPUTS] rule 14)
    // ------------------------------------------------------------------

    function testCoreNativeCollectionsSkipFacadeBindingComponent() public {
        // Identity mode defaults to CORE_NATIVE and no binding record/component exists: passes.
        Fixture memory fixture = _buildFixture(_collectionScope(COLLECTION_ID), true);
        (bool recorded,,) = metadataMock.facadeIdentityBindingRecord(COLLECTION_ID);
        recorded.assertFalse("no binding record for CORE_NATIVE");
        _executeFixture(fixture);
        registry.collectionFinalityRecord(COLLECTION_ID).finalized
            .assertTrue("CORE_NATIVE finalized without facade binding");
        // The permanent record carries no facade-binding component.
        (bool pinned,,,) = registry.frozenRouteForScope(
            StreamFinalityDomains.RECORD_IDENTITY_FACADE_BINDING, fixture.scope
        );
        pinned.assertFalse("no facade route for CORE_NATIVE");
    }

    function testCoreNativeWithSpuriousFacadeComponentReverts() public {
        // A CORE_NATIVE collection must not carry an IDENTITY_FACADE_BINDING component.
        Fixture memory fixture = _buildFixture(_collectionScope(COLLECTION_ID), true);
        StreamFinalityComponentExpectation memory spurious = _expectationFor(
            facadeBindingComponent,
            StreamFinalityDomains.RECORD_IDENTITY_FACADE_BINDING,
            keccak256("spurious-binding")
        );
        _installComponentState(fixture.scope, spurious);
        StreamFinalityComponentExpectation[] memory withSpurious =
            new StreamFinalityComponentExpectation[](fixture.components.length + 1);
        for (uint256 i = 0; i < fixture.components.length; i++) {
            withSpurious[i] = fixture.components[i];
        }
        withSpurious[fixture.components.length] = spurious;
        withSpurious = _sortComponents(withSpurious);
        _scheduleAndOpen(fixture); // staged hash is the clean fixture's; the gate fires first
        vm.prank(finalityAdmin);
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamArtworkFinalityRegistry.FinalityFacadeBindingComponentForbidden.selector,
                COLLECTION_ID
            )
        );
        registry.finalizeCollectionArtwork(
            COLLECTION_ID, withSpurious, fixture.expectedFinalityRecordHash, fixture.manifest
        );
    }

    function testExternalFacadeRecordHashDiffersFromCoreNative() public {
        // Same everything except identity mode: the EXTERNAL_FACADE record binds the facade
        // component, so its finalityRecordHash differs from the CORE_NATIVE case
        // ([LTA-FINALITY] req 16 / [CMC-FACADE-BINDING] rule 6: permanent identity).
        Fixture memory native = _buildFixture(_collectionScope(COLLECTION_ID), true);
        Fixture memory facadeFixture = _buildFixture(
            _collectionScope(COLLECTION_ID + 1),
            true,
            StreamFinalityDomains.METADATA_MODE_OFFCHAIN,
            true
        );
        (native.expectedFinalityRecordHash != facadeFixture.expectedFinalityRecordHash)
        .assertTrue("EXTERNAL_FACADE record hash differs from CORE_NATIVE");
        // The facade fixture carries exactly one extra component (the binding).
        facadeFixture.components.length
            .assertEq(native.components.length + 1, "facade fixture has the binding component");

        _executeFixture(facadeFixture);
        registry.collectionFinalityRecord(COLLECTION_ID + 1).finalized
            .assertTrue("EXTERNAL_FACADE finalized");
        // The binding component is re-surfaced post-finalize through the frozen-route registry.
        (bool pinned, address module,, bytes32 recHash) = registry.frozenRouteForScope(
            StreamFinalityDomains.RECORD_IDENTITY_FACADE_BINDING, facadeFixture.scope
        );
        pinned.assertTrue("facade route pinned");
        module.assertEq(address(facadeBindingComponent), "facade route module");
        recHash.assertEq(facadeFixture.expectedFinalityRecordHash, "facade route record hash");
    }

    function testExternalFacadeGates() public {
        Fixture memory fixture = _buildFixture(
            _collectionScope(COLLECTION_ID),
            true,
            StreamFinalityDomains.METADATA_MODE_OFFCHAIN,
            true
        );
        address facade = address(facadeBindingComponent);

        // Missing binding record blocks (clear the record the fixture set).
        metadataMock.setFacadeBinding(COLLECTION_ID, false, address(0), bytes32(0));
        _scheduleAndOpen(fixture);
        vm.prank(finalityAdmin);
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamArtworkFinalityRegistry.FinalityFacadeBindingMissing.selector, COLLECTION_ID
            )
        );
        registry.finalizeCollectionArtwork(
            COLLECTION_ID, fixture.components, fixture.expectedFinalityRecordHash, fixture.manifest
        );
        StreamFinalityPreview memory p = previewer.previewCollectionFinality(
            COLLECTION_ID, fixture.components, fixture.manifest
        );
        p.facadeBindingSatisfied.assertFalse("preview facade gate");

        // A binding whose facade address is not the registered controller blocks.
        address wrongFacade = address(0xBAD0FACADE);
        metadataMock.setFacadeBinding(COLLECTION_ID, true, wrongFacade, fixture.facadeRecordHash);
        vm.prank(finalityAdmin);
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamArtworkFinalityRegistry.FinalityFacadeBindingControllerMismatch.selector,
                wrongFacade,
                facade
            )
        );
        registry.finalizeCollectionArtwork(
            COLLECTION_ID, fixture.components, fixture.expectedFinalityRecordHash, fixture.manifest
        );

        // Recorded and controller-matched, but the submitted component dataHash != recordHash.
        metadataMock.setFacadeBinding(
            COLLECTION_ID, true, facade, keccak256("some other record hash")
        );
        vm.prank(finalityAdmin);
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamArtworkFinalityRegistry.FinalityFacadeBindingComponentDataHashMismatch
                .selector,
                fixture.facadeRecordHash,
                keccak256("some other record hash")
            )
        );
        registry.finalizeCollectionArtwork(
            COLLECTION_ID, fixture.components, fixture.expectedFinalityRecordHash, fixture.manifest
        );

        // Restore the matching record: finality passes.
        metadataMock.setFacadeBinding(COLLECTION_ID, true, facade, fixture.facadeRecordHash);
        _finalizeFixtureCall(fixture);
        registry.collectionFinalityRecord(COLLECTION_ID).finalized
            .assertTrue("EXTERNAL_FACADE finalized with verified + bound binding");
    }

    function testExternalFacadeMissingBindingComponentReverts() public {
        // EXTERNAL_FACADE with a valid live binding but no submitted binding component blocks:
        // the two-address identity must enter the permanent record.
        Fixture memory fixture = _buildFixture(
            _collectionScope(COLLECTION_ID),
            true,
            StreamFinalityDomains.METADATA_MODE_OFFCHAIN,
            true
        );
        // Drop the facade-binding component from the submitted list.
        StreamFinalityComponentExpectation[] memory withoutBinding =
            new StreamFinalityComponentExpectation[](fixture.components.length - 1);
        uint256 cursor = 0;
        for (uint256 i = 0; i < fixture.components.length; i++) {
            if (
                fixture.components[i].componentType
                    != StreamFinalityDomains.RECORD_IDENTITY_FACADE_BINDING
            ) {
                withoutBinding[cursor] = fixture.components[i];
                cursor++;
            }
        }
        _scheduleAndOpen(fixture);
        vm.prank(finalityAdmin);
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamArtworkFinalityRegistry.FinalityFacadeBindingComponentMissing.selector,
                COLLECTION_ID
            )
        );
        registry.finalizeCollectionArtwork(
            COLLECTION_ID, withoutBinding, fixture.expectedFinalityRecordHash, fixture.manifest
        );
    }

    function testExternalFacadeBindingRequiredForScopedFinalityToo() public {
        StreamFinalityScope memory scope = _tokenScope(COLLECTION_ID, 9);
        Fixture memory fixture =
            _buildFixture(scope, true, StreamFinalityDomains.METADATA_MODE_OFFCHAIN, true);
        // Clear the live binding record: scoped finality blocks too.
        metadataMock.setFacadeBinding(COLLECTION_ID, false, address(0), bytes32(0));
        _scheduleAndOpen(fixture);
        vm.prank(finalityAdmin);
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamArtworkFinalityRegistry.FinalityFacadeBindingMissing.selector, COLLECTION_ID
            )
        );
        registry.finalizeArtworkScope(
            scope, fixture.components, fixture.expectedFinalityRecordHash, fixture.manifest
        );
    }

    // ------------------------------------------------------------------
    // Discovery seam
    // ------------------------------------------------------------------

    function testDiscoveryGateWhenBound() public {
        MockFinalityDiscovery discovery = new MockFinalityDiscovery();
        registry = new StreamArtworkFinalityRegistry(
            address(coreMock),
            address(metadataMock),
            address(sanctionMock),
            address(authority),
            address(discovery)
        );
        previewer = new StreamArtworkFinalityPreview(registry);

        Fixture memory fixture = _buildFixture(_collectionScope(COLLECTION_ID), true);
        uint256 total = fixture.components.length;
        _scheduleAndOpen(fixture);

        // Unconfigured discovery (count 0) blocks.
        vm.prank(finalityAdmin);
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamArtworkFinalityRegistry.FinalityDiscoveryCountMismatch.selector,
                uint256(0),
                total
            )
        );
        registry.finalizeCollectionArtwork(
            COLLECTION_ID, fixture.components, fixture.expectedFinalityRecordHash, fixture.manifest
        );

        // Count match with hash mismatch blocks.
        discovery.setCollectionDiscovery(COLLECTION_ID, total, keccak256("router disagrees"));
        vm.prank(finalityAdmin);
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamArtworkFinalityRegistry.FinalityDiscoveryHashMismatch.selector,
                keccak256("router disagrees"),
                fixture.componentsHash
            )
        );
        registry.finalizeCollectionArtwork(
            COLLECTION_ID, fixture.components, fixture.expectedFinalityRecordHash, fixture.manifest
        );

        // Exact discovery agreement passes.
        discovery.setCollectionDiscovery(COLLECTION_ID, total, fixture.componentsHash);
        _finalizeFixtureCall(fixture);
        registry.collectionFinalityRecord(COLLECTION_ID).finalized.assertTrue("finalized");
    }

    // ------------------------------------------------------------------
    // Diagnostics: never-revert semantics and range verification
    // ------------------------------------------------------------------

    function testVerifyFinalityDegradesWithoutReverting() public {
        Fixture memory fixture = _buildFixture(_collectionScope(COLLECTION_ID), true);
        _executeFixture(fixture);
        (bool matches,,) = registry.verifyFinality(COLLECTION_ID);
        matches.assertTrue("healthy route");

        // Unfinalized collections report (false, 0, 0).
        (bool unknownMatches, bytes32 unknownHash,) = registry.verifyFinality(COLLECTION_ID + 1);
        unknownMatches.assertFalse("unfinalized");
        unknownHash.assertEq(bytes32(0), "no record hash");

        // dataHash drift: still-matches flips false, stored hashes still returned.
        StreamFinalityComponentState memory drifted = _stateFor(fixture.components[1]);
        drifted.dataHash = keccak256("post-finality drift");
        MockFinalityComponent(fixture.components[1].component)
            .setCollectionState(COLLECTION_ID, drifted);
        (bool driftMatches, bytes32 recHash, bytes32 compHash) =
            registry.verifyFinality(COLLECTION_ID);
        driftMatches.assertFalse("drifted route");
        recHash.assertEq(fixture.expectedFinalityRecordHash, "record hash preserved");
        compHash.assertEq(fixture.componentsHash, "components hash preserved");
        registry.finalityStillMatches(COLLECTION_ID).assertFalse("still-matches degraded");
        MockFinalityComponent(fixture.components[1].component)
            .setCollectionState(COLLECTION_ID, _stateFor(fixture.components[1]));

        // A reverting component degrades to false, never reverts the diagnostic.
        MockFinalityComponent(fixture.components[0].component).setMode(1);
        (bool revertMatches,,) = registry.verifyFinality(COLLECTION_ID);
        revertMatches.assertFalse("reverting component");
        MockFinalityComponent(fixture.components[0].component).setMode(0);

        // Malformed (short) returndata degrades to false.
        MockFinalityComponent(fixture.components[0].component).setMode(2);
        (bool shortMatches,,) = registry.verifyFinality(COLLECTION_ID);
        shortMatches.assertFalse("short returndata");
        MockFinalityComponent(fixture.components[0].component).setMode(0);

        // A component exceeding the bounded per-read gas budget degrades to false.
        MockFinalityComponent(fixture.components[0].component).setMode(3);
        (bool gasMatches,,) = registry.verifyFinality(COLLECTION_ID);
        gasMatches.assertFalse("gas-exhausting component");
        MockFinalityComponent(fixture.components[0].component).setMode(0);

        // Replaced code (codehash change) degrades to false.
        vm.etch(fixture.components[0].component, hex"6001600101");
        (bool etchedMatches,,) = registry.verifyFinality(COLLECTION_ID);
        etchedMatches.assertFalse("code replaced");
    }

    function testVerifyFinalityRangePaginatesAndDetectsDrift() public {
        Fixture memory fixture = _buildFixture(_collectionScope(COLLECTION_ID), true);
        _executeFixture(fixture);

        (
            bool rangeMatches,
            bytes32 recHash,
            bytes32 expectedHash,
            bytes32 observedHash,
            uint256 nextStart
        ) = registry.verifyFinalityRange(COLLECTION_ID, 0, 2);
        rangeMatches.assertTrue("healthy range");
        recHash.assertEq(fixture.expectedFinalityRecordHash, "range record hash");
        expectedHash.assertEq(observedHash, "expected == observed while healthy");
        nextStart.assertEq(2, "next start");

        (,,,, uint256 tailNext) = registry.verifyFinalityRange(COLLECTION_ID, 2, 100);
        tailNext.assertEq(fixture.components.length, "tail clamps to count");

        // Drift one component: its range mismatches with divergent hashes, others stay clean.
        StreamFinalityComponentState memory drifted = _stateFor(fixture.components[2]);
        drifted.manifestHash = keccak256("drifted manifest");
        MockFinalityComponent(fixture.components[2].component)
            .setCollectionState(COLLECTION_ID, drifted);
        (bool cleanMatches,,,,) = registry.verifyFinalityRange(COLLECTION_ID, 0, 2);
        cleanMatches.assertTrue("untouched prefix still matches");
        (bool driftedMatches,, bytes32 expectedDrift, bytes32 observedDrift,) =
            registry.verifyFinalityRange(COLLECTION_ID, 2, 1);
        driftedMatches.assertFalse("drifted slice mismatches");
        (expectedDrift != observedDrift).assertTrue("hashes diverge");

        // Unfinalized scope: zeroed diagnostics.
        (bool noneMatches,, bytes32 noneExpected,, uint256 noneNext) =
            registry.verifyFinalityRange(COLLECTION_ID + 1, 0, 5);
        noneMatches.assertFalse("unfinalized range");
        noneExpected.assertEq(bytes32(0), "no expected hash");
        noneNext.assertEq(0, "no next start");
    }

    function testScopedDiagnosticsUseScopedReads() public {
        StreamFinalityScope memory scope = _tokenScope(COLLECTION_ID, 15);
        Fixture memory fixture = _buildFixture(scope, true);
        _executeFixture(fixture);

        (bool matches,,) = registry.verifyArtworkScopeFinality(scope);
        matches.assertTrue("scoped route healthy");

        // Drift the scoped state only: scoped diagnostics degrade.
        StreamFinalityComponentState memory drifted = _stateFor(fixture.components[1]);
        drifted.dataHash = keccak256("scoped drift");
        MockFinalityComponent(fixture.components[1].component).setScopedState(scope, drifted);
        (bool driftMatches, bytes32 recHash,) = registry.verifyArtworkScopeFinality(scope);
        driftMatches.assertFalse("scoped drift detected");
        recHash.assertEq(fixture.expectedFinalityRecordHash, "scoped record hash preserved");

        (bool rangeMatches,,,, uint256 nextStart) =
            registry.verifyArtworkScopeFinalityRange(scope, 0, 100);
        rangeMatches.assertFalse("scoped range mismatch");
        nextStart.assertEq(fixture.components.length, "scoped range clamp");
    }

    // ------------------------------------------------------------------
    // Calldata cap
    // ------------------------------------------------------------------

    function testCalldataCapBlocksOversizedSubmissions() public {
        Fixture memory fixture = _buildFixture(_collectionScope(COLLECTION_ID), true);
        _scheduleAndOpen(fixture);
        bytes memory hugeURI = new bytes(33_000);
        for (uint256 i = 0; i < hugeURI.length; i++) {
            hugeURI[i] = "a";
        }
        StreamFinalityManifestRef memory hugeManifest = _cloneManifest(fixture.manifest);
        hugeManifest.uri = string(hugeURI);
        hugeManifest.uriHash = keccak256(hugeURI);

        // Encode the exact calldata to assert the revert carries the precise observed size.
        bytes memory callData = abi.encodeWithSelector(
            registry.finalizeCollectionArtwork.selector,
            COLLECTION_ID,
            fixture.components,
            fixture.expectedFinalityRecordHash,
            hugeManifest
        );
        (callData.length > registry.MAX_FINALITY_CALLDATA_BYTES()).assertTrue("oversized calldata");

        vm.prank(finalityAdmin);
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamArtworkFinalityRegistry.FinalityCalldataTooLarge.selector,
                callData.length,
                registry.MAX_FINALITY_CALLDATA_BYTES()
            )
        );
        registry.finalizeCollectionArtwork(
            COLLECTION_ID, fixture.components, fixture.expectedFinalityRecordHash, hugeManifest
        );
    }

    // ------------------------------------------------------------------
    // Preview parity on remaining gates
    // ------------------------------------------------------------------

    function testPreviewParityAcrossGates() public {
        Fixture memory fixture = _buildFixture(_collectionScope(COLLECTION_ID), true);

        // Without staging: everything else green, staged flag red.
        StreamFinalityPreview memory p = previewer.previewCollectionFinality(
            COLLECTION_ID, fixture.components, fixture.manifest
        );
        p.stagedFreezeReady.assertFalse("not staged");
        p.coreGatesSatisfied.assertTrue("core gates");
        p.contentRootSatisfied.assertTrue("content root");
        p.manifestSatisfied.assertTrue("manifest");
        p.componentsWellFormed.assertTrue("well-formed");
        p.componentsMatchLive.assertTrue("live match");
        p.sanctionSatisfied.assertTrue("sanction");
        p.facadeBindingSatisfied.assertTrue("facade");
        p.discoveryMatches.assertTrue("discovery unbound");
        p.notAlreadyFinalized.assertTrue("not finalized");
        p.wouldExecute.assertFalse("blocked by staging only");

        // Break the sanction: flag flips, hashes still computed.
        sanctionMock.setRequiredComponentType(
            COLLECTION_ID, StreamFinalityDomains.COMPONENT_PLATFORM_WORKS_DECLARATION
        );
        p = previewer.previewCollectionFinality(COLLECTION_ID, fixture.components, fixture.manifest);
        p.sanctionSatisfied.assertFalse("sanction gate red");
        p.computedSanctionSubjectHash
            .assertEq(fixture.sanctionSubjectHash, "subject hash still exposed");
        sanctionMock.setRequiredComponentType(
            COLLECTION_ID, StreamFinalityDomains.COMPONENT_ARTIST_SANCTION
        );

        // Break a live component: flag flips without reverting the preview.
        MockFinalityComponent(fixture.components[0].component).setMode(1);
        p = previewer.previewCollectionFinality(COLLECTION_ID, fixture.components, fixture.manifest);
        p.componentsMatchLive.assertFalse("live gate red");
        MockFinalityComponent(fixture.components[0].component).setMode(0);

        // After execution: notAlreadyFinalized flips.
        _executeFixture(fixture);
        p = previewer.previewCollectionFinality(COLLECTION_ID, fixture.components, fixture.manifest);
        p.notAlreadyFinalized.assertFalse("already finalized");
        p.wouldExecute.assertFalse("cannot re-execute");
    }

    function testScopedPreviewMatchesScopedExecution() public {
        StreamFinalityScope memory scope =
            _idScope(StreamFinalityScopeType.SEASON, COLLECTION_ID, keccak256("season-1"));
        Fixture memory fixture = _buildFixture(scope, true);
        _scheduleAndOpen(fixture);
        StreamFinalityPreview memory p =
            previewer.previewArtworkScopeFinality(scope, fixture.components, fixture.manifest);
        p.wouldExecute.assertTrue("scoped preview executes");
        p.computedFinalityRecordHash
            .assertEq(fixture.expectedFinalityRecordHash, "scoped preview hash");
        p.computedSanctionSubjectHash.assertEq(fixture.sanctionSubjectHash, "scoped subject hash");
        _finalizeFixtureCall(fixture);
        registry.artworkScopeFinalityRecord(scope).finalized.assertTrue("executed after preview");
    }

    /// @notice Preview mirrors the [LTA-FREEZE] rule 4 live-guardian gate: clearing the veto
    ///         guardian after scheduling makes previewFinality.stagedFreezeReady and the real
    ///         finalize call reject together, so preview and execution never diverge on it.
    function testPreviewStagedFreezeMirrorsGuardianGate() public {
        Fixture memory fixture = _buildFixture(_collectionScope(COLLECTION_ID), true);
        _scheduleAndOpen(fixture);

        // Guardian live: the staged freeze previews ready and would execute.
        StreamFinalityPreview memory p = previewer.previewCollectionFinality(
            COLLECTION_ID, fixture.components, fixture.manifest
        );
        p.stagedFreezeReady.assertTrue("guardian live: staged ready");
        p.wouldExecute.assertTrue("guardian live: would execute");

        // Clear the veto guardian after scheduling; the scheduled action itself is untouched.
        authority.setDefaultGuardian(address(0));
        p = previewer.previewCollectionFinality(COLLECTION_ID, fixture.components, fixture.manifest);
        p.stagedFreezeReady.assertFalse("guardian cleared: staged not ready");
        p.wouldExecute.assertFalse("guardian cleared: would not execute");

        // Execution rejects on the same cleared-guardian gate: the preview matched reality.
        vm.prank(finalityAdmin);
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamArtworkFinalityRegistry.FinalityFreezeGuardianUnset.selector,
                fixture.scopeKey
            )
        );
        registry.finalizeCollectionArtwork(
            COLLECTION_ID, fixture.components, fixture.expectedFinalityRecordHash, fixture.manifest
        );

        // Restoring the guardian re-opens both preview and execution — the gate reads the live
        // guardian each call, never the action's scheduling-time snapshot.
        authority.setDefaultGuardian(guardian);
        p = previewer.previewCollectionFinality(COLLECTION_ID, fixture.components, fixture.manifest);
        p.stagedFreezeReady.assertTrue("guardian restored: staged ready");
        p.wouldExecute.assertTrue("guardian restored: would execute");
        _finalizeFixtureCall(fixture);
        registry.artworkScopeFinalityRecord(fixture.scope).finalized
            .assertTrue("executed after guardian restored");
    }
}
