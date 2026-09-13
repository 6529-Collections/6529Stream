// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "../../regression/legacy/helpers/CharacterizationTestBase.sol";
import "../../helpers/OfficialSafeFixture.sol";
import "../../../smart-contracts/domains/finality/StreamFinalityPreparedScopeReads.sol";
import "../../../smart-contracts/domains/finality/StreamFinalityNativeEvidenceProvider.sol";

/// @dev Explicit dependency/returndata boundary; no table represents validated original evidence.
contract NativeProviderReadTable {
    mapping(bytes32 => bytes) private values;
    mapping(bytes32 => bool) private present;

    function put(bytes calldata input, bytes calldata result) external {
        values[keccak256(input)] = result;
        present[keccak256(input)] = true;
    }

    fallback() external {
        require(present[keccak256(msg.data)], "unset read");
        bytes memory out = values[keccak256(msg.data)];
        assembly ("memory-safe") { return(add(out, 32), mload(out)) }
    }
}

contract PreparedReadHarness {
    function dispatch(
        address provider,
        StreamFinalityScope calldata scope,
        bytes32 hash,
        StreamFinalityComponentExpectation[] calldata components,
        uint256 cap
    ) external view returns (bytes memory) {
        return StreamFinalityPreparedScopeReads.read(provider, scope, hash, components, cap);
    }

    function bounded(address target, bytes calldata input, uint256 length, uint256 cap)
        external
        view
        returns (bool, uint256, bytes memory)
    {
        return StreamFinalityBoundedReads.tryRead(target, input, length, cap);
    }

    function components(
        StreamFinalityNativeProviderReads.Config calldata c,
        StreamFinalityScope calldata scope
    ) external view returns (StreamFinalityComponentExpectation[] memory) {
        return StreamFinalityNativeProviderReads.currentComponents(c, scope);
    }

    function statement(
        StreamFinalityNativeProviderReads.Config calldata c,
        StreamFinalityScope calldata scope,
        StreamFinalityComponentExpectation[] calldata rows
    ) external view returns (StreamFinalityInputManifestTypes.Statement memory) {
        return StreamFinalityNativeProviderReads.statement(c, scope, rows);
    }

    function project(StreamFinalityComponentExpectation[] calldata entries)
        external
        pure
        returns (StreamFinalityComponentExpectation[] memory)
    {
        return StreamFinalityNativeProviderReads.independentComponents(entries);
    }
}

contract PreparedReadBurner {
    fallback() external {
        assembly ("memory-safe") { for { } 1 { } { } }
    }
}

contract StreamFinalityPreparedScopeTest is CharacterizationTestBase, OfficialSafeFixture {
    PreparedReadHarness private harness;
    NativeProviderReadTable private table;
    StreamFinalityScope private scope;
    bytes32 private constant MANIFEST = keccak256("independent manifest");

    function setUp() public {
        harness = new PreparedReadHarness();
        table = new NativeProviderReadTable();
        scope = StreamFinalityScope(StreamFinalityScopeType.COLLECTION, 1, 0, 0);
    }

    function _rows() private pure returns (StreamFinalityComponentExpectation[] memory r) {
        r = new StreamFinalityComponentExpectation[](9);
        for (uint256 i; i < 9; ++i) {
            r[i] = StreamFinalityComponentExpectation(
                bytes32(i + 1),
                address(uint160(i + 1)),
                bytes4(uint32(i + 1)),
                bytes32(i + 2),
                bytes32(i + 3),
                bytes32(i + 4),
                bytes32(i + 5)
            );
        }
    }

    function _result(bytes32 root) private pure returns (bytes memory) {
        StreamFinalityScopeInputs memory i;
        i.rootRecordHash = root;
        return abi.encode(i, bytes32(uint256(11)), bytes32(uint256(12)));
    }

    function _probe(bytes memory result) private {
        table.put(
            abi.encodeCall(
                IERC165.supportsInterface, (type(IStreamFinalityPreparedScopeEvidence).interfaceId)
            ),
            result
        );
    }

    function _legacy(bytes memory result) private {
        table.put(
            abi.encodeCall(
                IStreamFinalityScopeEvidence.requireFinalityScopeInputs, (scope, MANIFEST)
            ),
            result
        );
    }

    function _prepared(bytes memory result) private {
        table.put(
            abi.encodeCall(
                IStreamFinalityPreparedScopeEvidence.requirePreparedFinalityScopeInputs,
                (scope, MANIFEST, _rows())
            ),
            result
        );
    }

    function _dispatch() private view returns (bytes memory) {
        return harness.dispatch(address(table), scope, MANIFEST, _rows(), 16000000);
    }

    function testAbsentCapabilityPreservesLegacy() public {
        _legacy(_result(bytes32(uint256(1))));
        require(keccak256(_dispatch()) == keccak256(_result(bytes32(uint256(1)))));
    }

    function testFalseCapabilityPreservesLegacy() public {
        _probe(abi.encode(false));
        _legacy(_result(bytes32(uint256(2))));
        require(keccak256(_dispatch()) == keccak256(_result(bytes32(uint256(2)))));
    }

    function testPreparedReceivesAllSevenFields() public {
        _probe(abi.encode(true));
        _prepared(_result(bytes32(uint256(3))));
        _legacy(_result(bytes32(uint256(9))));
        require(keccak256(_dispatch()) == keccak256(_result(bytes32(uint256(3)))));
    }

    function testAdvertisedFailureNeverFallsBack() public {
        _probe(abi.encode(true));
        _legacy(_result(bytes32(uint256(9))));
        vm.expectRevert(
            abi.encodeWithSelector(
                StreamFinalityBoundedReads.FinalityReadFailed.selector, address(table)
            )
        );
        _dispatch();
    }

    function testMalformedProbeFailsClosed() public {
        _probe(abi.encode(uint256(2)));
        _legacy(_result(bytes32(uint256(9))));
        vm.expectRevert(
            abi.encodeWithSelector(
                StreamFinalityBoundedReads.FinalityCapabilityMalformed.selector, address(table)
            )
        );
        _dispatch();
    }

    function testOversizedProbeFailsClosed() public {
        _probe(abi.encode(true, uint256(0)));
        _legacy(_result(bytes32(uint256(9))));
        vm.expectRevert();
        _dispatch();
    }

    function testShortPreparedReturnFailsClosed() public {
        _probe(abi.encode(true));
        _prepared(new bytes(383));
        vm.expectRevert();
        _dispatch();
    }

    function testOversizedPreparedReturnFailsClosed() public {
        _probe(abi.encode(true));
        _prepared(new bytes(416));
        vm.expectRevert();
        _dispatch();
    }

    function testCheapReadWorksBelowConfiguredCap() public {
        table.put(hex"abcd", abi.encode(uint256(42)));
        (bool success, bytes memory out) = address(harness).staticcall{ gas: 400000 }(
            abi.encodeCall(harness.bounded, (address(table), hex"abcd", 32, 16000000))
        );
        require(success);
        (bool ok, uint256 size, bytes memory result) = abi.decode(out, (bool, uint256, bytes));
        require(ok && size == 32 && abi.decode(result, (uint256)) == 42);
    }

    function testExhaustingCalleeReturnsFailureAndHealthyRetry() public {
        PreparedReadBurner burner = new PreparedReadBurner();
        (bool success, bytes memory out) = address(harness).staticcall{ gas: 400000 }(
            abi.encodeCall(harness.bounded, (address(burner), hex"abcd", 32, 16000000))
        );
        require(success);
        (bool ok,,) = abi.decode(out, (bool, uint256, bytes));
        require(!ok);
        table.put(hex"abcd", abi.encode(uint256(42)));
        (ok,,) = harness.bounded(address(table), hex"abcd", 32, 16000000);
        require(ok);
    }

    function testBoundedReadRejectsOversizedReturn() public {
        table.put(hex"abcd", abi.encode(uint256(42), uint256(1)));
        (bool ok, uint256 size,) = harness.bounded(address(table), hex"abcd", 32, 16000000);
        require(!ok && size == 64);
    }

    function testFuzzConfiguredUpperBound(uint32 cap) public {
        uint256 limit = 50000 + uint256(cap);
        table.put(hex"abcd", abi.encode(uint256(42)));
        (bool success, bytes memory out) = address(harness).staticcall{ gas: 400000 }(
            abi.encodeCall(harness.bounded, (address(table), hex"abcd", 32, limit))
        );
        require(success);
        (bool ok,,) = abi.decode(out, (bool, uint256, bytes));
        require(ok);
    }

    function testSanctionProjectionKeepsEveryIndependentField() public {
        StreamFinalityComponentExpectation[] memory r = _rows();
        StreamFinalityComponentExpectation[] memory full =
            new StreamFinalityComponentExpectation[](10);
        for (uint256 i; i < 9; ++i) {
            full[i] = r[i];
        }
        full[9].componentType = StreamFinalityDomains.COMPONENT_ARTIST_SANCTION;
        require(keccak256(abi.encode(harness.project(full))) == keccak256(abi.encode(r)));
    }

    function testMissingIndependentProjectionRejected() public {
        StreamFinalityComponentExpectation[] memory r = _rows();
        r[2].componentType = StreamFinalityDomains.COMPONENT_ARTIST_SANCTION;
        vm.expectRevert();
        harness.project(r);
    }

    function _routes()
        private
        returns (
            StreamFinalityNativeProviderReads.Config memory c,
            StreamFinalityCurrentComponentRoute[] memory routes
        )
    {
        c.targets[13] = address(table);
        c.sourceGas = 16000000;
        routes = new StreamFinalityCurrentComponentRoute[](9);
        for (uint256 i; i < 9; ++i) {
            NativeProviderReadTable component = new NativeProviderReadTable();
            routes[i] = StreamFinalityCurrentComponentRoute(
                bytes32(i + 1),
                address(component),
                type(IStreamArtworkFinalityComponent).interfaceId,
                address(component).codehash
            );
            StreamFinalityComponentState memory s = StreamFinalityComponentState(
                true,
                routes[i].componentType,
                address(component),
                routes[i].interfaceId,
                routes[i].codeHash,
                bytes32(i + 2),
                bytes32(i + 3),
                bytes32(i + 4)
            );
            component.put(
                abi.encodeCall(IStreamArtworkFinalityComponent.finalityState, (uint256(1))),
                abi.encode(s)
            );
        }
        table.put(
            abi.encodeCall(
                IStreamFinalityCurrentComponentRoutes.requireCurrentRoutes, (scope, false)
            ),
            abi.encode(routes)
        );
    }

    function testPublicComponentsReadCanonicalFullState() public {
        (
            StreamFinalityNativeProviderReads.Config memory c,
            StreamFinalityCurrentComponentRoute[] memory r
        ) = _routes();
        StreamFinalityComponentExpectation[] memory out = harness.components(c, scope);
        require(out.length == 9);
        for (uint256 i; i < 9; ++i) {
            require(
                out[i].component == r[i].component && out[i].dataHash == bytes32(i + 4)
                    && out[i].moduleVersion == bytes32(i + 2)
            );
        }
    }

    function testPublicComponentsRejectHostOnlyFourWordState() public {
        (
            StreamFinalityNativeProviderReads.Config memory c,
            StreamFinalityCurrentComponentRoute[] memory r
        ) = _routes();
        NativeProviderReadTable(r[0].component)
            .put(
                abi.encodeCall(IStreamArtworkFinalityComponent.finalityState, (uint256(1))),
                abi.encode(true, bytes32(uint256(1)), bytes32(uint256(2)), bytes32(uint256(3)))
            );
        vm.expectRevert();
        harness.components(c, scope);
    }

    function testPublicComponentsRejectMismatchedRouteIdentity() public {
        (
            StreamFinalityNativeProviderReads.Config memory c,
            StreamFinalityCurrentComponentRoute[] memory r
        ) = _routes();
        StreamFinalityComponentState memory s = StreamFinalityComponentState(
            true,
            bytes32(uint256(777)),
            r[0].component,
            r[0].interfaceId,
            r[0].codeHash,
            bytes32(uint256(1)),
            bytes32(uint256(2)),
            bytes32(uint256(3))
        );
        NativeProviderReadTable(r[0].component)
            .put(
                abi.encodeCall(IStreamArtworkFinalityComponent.finalityState, (uint256(1))),
                abi.encode(s)
            );
        vm.expectRevert();
        harness.components(c, scope);
    }

    function _baseConfig() private returns (StreamFinalityNativeProviderReads.Config memory c) {
        c.chainId = block.chainid;
        c.readGas = 500000;
        c.sourceGas = 16000000;
        c.inventoryDependencyHash = keccak256("pending real inventory");
        for (uint256 i; i < 22; ++i) {
            c.targets[i] = address(new NativeProviderReadTable());
            c.codeHashes[i] = c.targets[i].codehash;
        }
        _put(c, 1, abi.encodeWithSignature("core()"), abi.encode(c.targets[0]));
        _put(c, 2, abi.encodeWithSignature("core()"), abi.encode(c.targets[0]));
        _put(c, 3, abi.encodeWithSignature("core()"), abi.encode(c.targets[0]));
        _put(c, 3, abi.encodeWithSignature("metadataHost()"), abi.encode(c.targets[1]));
        _put(
            c,
            2,
            abi.encodeCall(IERC165.supportsInterface, (type(IERC165).interfaceId)),
            abi.encode(true)
        );
        _put(
            c,
            2,
            abi.encodeCall(
                IERC165.supportsInterface, (type(IStreamMetadataServingFacts).interfaceId)
            ),
            abi.encode(true)
        );
        _put(
            c,
            2,
            abi.encodeCall(IERC165.supportsInterface, (type(IStreamMetadataRouter).interfaceId)),
            abi.encode(true)
        );
        _put(
            c, 2, abi.encodeCall(IERC165.supportsInterface, (bytes4(0xffffffff))), abi.encode(false)
        );
        for (uint256 i = 1; i <= 2; ++i) {
            _put(c, i, abi.encodeWithSignature("streamModuleVersion()"), abi.encode(bytes32(i)));
            _put(
                c,
                i,
                abi.encodeWithSignature("streamModuleManifest()"),
                abi.encode("ipfs://original", bytes32(i + 3))
            );
        }
        IStreamMetadataServingFacts.ServingFacts memory f;
        f.configured = true;
        f.mode = keccak256("ONCHAIN");
        _put(
            c,
            2,
            abi.encodeCall(IStreamMetadataServingFacts.collectionServingFacts, (uint256(1))),
            abi.encode(f)
        );
    }

    function _put(
        StreamFinalityNativeProviderReads.Config memory c,
        uint256 i,
        bytes memory input,
        bytes memory output
    ) private {
        NativeProviderReadTable(c.targets[i]).put(input, output);
    }

    function testProviderRejectsDirectPreparedCaller() public {
        StreamFinalityNativeProviderReads.Config memory c = _baseConfig();
        StreamFinalityNativeEvidenceProvider p = new StreamFinalityNativeEvidenceProvider(c);
        vm.expectRevert(
            abi.encodeWithSelector(
                StreamFinalityNativeEvidenceProvider.NativeProviderOriginalRegistryOnly.selector
            )
        );
        p.requirePreparedFinalityScopeInputs(scope, MANIFEST, _rows());
    }

    function testProviderRejectsChangedOriginalRegistryRuntime() public {
        StreamFinalityNativeProviderReads.Config memory c = _baseConfig();
        StreamFinalityNativeEvidenceProvider p = new StreamFinalityNativeEvidenceProvider(c);
        vm.etch(c.targets[12], hex"00");
        vm.prank(c.targets[12]);
        vm.expectRevert(
            abi.encodeWithSelector(
                StreamFinalityNativeEvidenceProvider.NativeProviderOriginalRegistryOnly.selector
            )
        );
        p.requirePreparedFinalityScopeInputs(scope, MANIFEST, _rows());
    }

    function testProviderConstructorRetainsFuturePinsWithoutReadiness() public {
        StreamFinalityNativeProviderReads.Config memory c = _baseConfig();
        for (uint256 i = 6; i < 22; ++i) {
            c.targets[i] = address(uint160(7000 + i));
            c.codeHashes[i] = bytes32(i + 1);
        }
        StreamFinalityNativeEvidenceProvider p = new StreamFinalityNativeEvidenceProvider(c);
        require(keccak256(abi.encode(p.nativeConfiguration())) == keccak256(abi.encode(c)));
        require(
            p.collectionMetadataMode(1) == 1
                && !p.collectionRecordTypeLocked(1, keccak256("METADATA_ALL"))
        );
        vm.expectRevert();
        p.requireFinalityScopeInputs(scope, MANIFEST);
    }

    function testProviderSafePublicReadAndProtocolOnlyRestriction() public {
        StreamFinalityNativeProviderReads.Config memory c = _baseConfig();
        StreamFinalityNativeEvidenceProvider p = new StreamFinalityNativeEvidenceProvider(c);
        uint256[] memory keys = new uint256[](2);
        keys[0] = 191;
        keys[1] = 192;
        OfficialSafe account =
            createOfficialSafe(deploySafeComponents("1.4.1"), safeOwnerAddresses(keys), 2, 191);
        require(
            executeSafe(
                account,
                keys,
                address(p),
                0,
                abi.encodeCall(p.collectionMetadataMode, (uint256(1))),
                0
            )
        );
        require(account.nonce() == 1);
        (bool ok, bytes memory failure) =
            address(this).call(abi.encodeCall(this.executePreparedSafe, (account, keys, p)));
        require(
            !ok
                && keccak256(failure)
                    == keccak256(abi.encodeWithSignature("Error(string)", "GS013"))
        );
        require(account.nonce() == 1);
    }

    function executePreparedSafe(
        OfficialSafe account,
        uint256[] calldata keys,
        StreamFinalityNativeEvidenceProvider p
    ) external {
        require(
            executeSafe(
                account,
                keys,
                address(p),
                0,
                abi.encodeCall(p.requirePreparedFinalityScopeInputs, (scope, MANIFEST, _rows())),
                0
            )
        );
    }

    function _inputFixture()
        private
        returns (
            StreamFinalityNativeProviderReads.Config memory c,
            StreamPreservationInventoryTypes.Evidence memory e
        )
    {
        c = _baseConfig();
        uint256[7] memory from = [uint256(0), 1, 2, 8, 9, 20, 21];
        string[7] memory selectors = [
            "core()",
            "metadataHost()",
            "metadataRouter()",
            "snapshots()",
            "referencePublisher()",
            "artifactCoverage()",
            "externalCoverage()"
        ];
        for (uint256 i; i < 7; ++i) {
            _put(c, 18, abi.encodeWithSignature(selectors[i]), abi.encode(c.targets[from[i]]));
        }
        _put(c, 19, abi.encodeWithSignature("core()"), abi.encode(c.targets[0]));
        _put(c, 19, abi.encodeWithSignature("metadataHost()"), abi.encode(c.targets[1]));
        _put(c, 19, abi.encodeWithSignature("renderCriticalInventory()"), abi.encode(c.targets[18]));
        _put(c, 19, abi.encodeWithSignature("artifactCoverage()"), abi.encode(c.targets[20]));
        _put(c, 19, abi.encodeWithSignature("externalCoverage()"), abi.encode(c.targets[21]));
        _put(c, 14, abi.encodeWithSignature("core()"), abi.encode(c.targets[0]));
        _put(c, 14, abi.encodeWithSignature("collectionMetadata()"), abi.encode(c.targets[1]));
        _put(c, 12, abi.encodeWithSignature("coreReads()"), abi.encode(c.targets[0]));
        _put(c, 12, abi.encodeWithSignature("metadataReads()"), abi.encode(c.targets[1]));
        _put(
            c, 12, abi.encodeWithSignature("scopeEvidenceProvider()"), abi.encode(address(harness))
        );
        _put(
            c, 13, abi.encodeWithSignature("scopeEvidenceProvider()"), abi.encode(address(harness))
        );
        _put(c, 14, abi.encodeWithSignature("evidenceProvider()"), abi.encode(address(harness)));
        _inputDependencies(c);
        e.planId = bytes32(uint256(1));
        e.collectionId = 1;
        e.scopeSubject = StreamMetadataSubjects.scopeSubject(block.chainid, c.targets[0], scope);
        e.artistId = bytes32(uint256(2));
        e.sourceContextHash = bytes32(uint256(3));
        e.tokenInventoryHash = bytes32(uint256(4));
        e.tokenCount = 2;
        e.segmentCount = 40;
        e.itemCount = 547;
        e.segmentChainHash = bytes32(uint256(5));
        e.renderCriticalEvidenceHash = bytes32(uint256(6));
        e.originals = StreamPreservationInventoryTypes.OriginalInputs(
            bytes32(uint256(10)),
            bytes32(uint256(11)),
            bytes32(uint256(12)),
            bytes32(uint256(13)),
            0,
            bytes32(uint256(14)),
            bytes32(uint256(15)),
            bytes32(uint256(16))
        );
        _put(
            c,
            18,
            abi.encodeCall(IStreamRenderCriticalInventory.requireCurrent, (uint256(1))),
            abi.encode(e)
        );
        StreamPreservationInventoryTypes.BundleEvidence memory bundle =
            StreamPreservationInventoryTypes.BundleEvidence(
                e.planId,
                e.renderCriticalEvidenceHash,
                e.itemCount,
                bytes32(uint256(17)),
                bytes32(uint256(18))
            );
        _put(
            c,
            19,
            abi.encodeCall(
                IStreamBundleArchiveCoverage.requireCoverage,
                (e.planId, e.renderCriticalEvidenceHash)
            ),
            abi.encode(bundle)
        );
        _put(
            c,
            2,
            abi.encodeCall(IStreamContentRootPublication.collectionContentRootHead, (uint256(1))),
            abi.encode(e.originals.rootRecordHash)
        );
        _put(
            c,
            2,
            abi.encodeCall(
                IStreamContentRootPublication.tokenContentRoot, (uint256(1), e.scopeSubject)
            ),
            abi.encode(bytes32(uint256(19)), uint64(2), bytes32(uint256(20)))
        );
        StreamSnapshotTypes.Receipt memory snap;
        snap.collectionId = 1;
        snap.recordHash = e.originals.snapshotRecordHash;
        snap.manifestHash = bytes32(uint256(21));
        snap.revision = 7;
        _put(
            c,
            8,
            abi.encodeCall(IStreamCollectionSnapshots.currentSnapshot, (uint256(1))),
            abi.encode(snap)
        );
        StreamReferenceRenderTypes.Receipt memory ref;
        ref.collectionId = 1;
        ref.recordHash = e.originals.referenceRenderRecordHash;
        ref.payloadHash = bytes32(uint256(22));
        ref.snapshotRecordHash = snap.recordHash;
        ref.snapshotRevision = snap.revision;
        _put(
            c,
            9,
            abi.encodeCall(IStreamReferenceRenderPublication.currentReference, (uint256(1))),
            abi.encode(ref)
        );
        StreamCoreCollectionFinalityFacts memory f;
        f.exists = true;
        f.status = StreamFinalityDomains.CORE_COLLECTION_STATUS_CLOSED;
        f.mintedSupply = 2;
        f.collectionConfigHash = bytes32(uint256(23));
        _put(
            c,
            14,
            abi.encodeCall(IStreamCoreFinalityAdapter.coreCollectionFinalityFacts, (uint256(1))),
            abi.encode(f)
        );
        _put(
            c,
            0,
            abi.encodeCall(IStreamCoreFinalitySource.collectionBurnsBlocked, (uint256(1))),
            abi.encode(true)
        );
        _put(
            c,
            0,
            abi.encodeCall(IStreamCoreFinalitySource.collectionFreezeStatus, (uint256(1))),
            abi.encode(true)
        );
    }

    function _inputDependencies(StreamFinalityNativeProviderReads.Config memory c) private {
        StreamRenderCriticalSourceTypes.Dependencies memory d;
        uint256[12] memory idx = [uint256(0), 1, 4, 5, 2, 8, 9, 15, 16, 17, 20, 21];
        for (uint256 i; i < 12; ++i) {
            d.targets[i] = c.targets[idx[i]];
            d.codeHashes[i] = c.codeHashes[idx[i]];
        }
        for (uint256 i; i < 5; ++i) {
            d.artistTargets[i] = c.targets[11];
            d.artistCodeHashes[i] = c.codeHashes[11];
        }
        d.artistContentOwner = c.targets[11];
        d.artistContentOwnerCodeHash = c.codeHashes[11];
        d.chainId = c.chainId;
        d.readGas = 500000;
        c.inventoryDependencyHash = keccak256(abi.encode(d));
        _put(c, 18, abi.encodeWithSignature("dependencies()"), abi.encode(d));
        _put(
            c,
            18,
            abi.encodeWithSignature("dependencyHash()"),
            abi.encode(c.inventoryDependencyHash)
        );
        StreamSnapshotTypes.Dependencies memory sd;
        uint256[8] memory si = [uint256(0), 1, 4, 5, 2, 6, 7, 3];
        for (uint256 i; i < 8; ++i) {
            sd.targets[i] = c.targets[si[i]];
            sd.codeHashes[i] = c.codeHashes[si[i]];
        }
        sd.targets[8] = address(new NativeProviderReadTable());
        sd.codeHashes[8] = sd.targets[8].codehash;
        sd.chainId = c.chainId;
        _put(c, 8, abi.encodeCall(IStreamCollectionSnapshots.dependencies, ()), abi.encode(sd));
        _put(c, 10, abi.encodeWithSignature("coordinatorInventory()"), abi.encode(sd.targets[8]));
    }

    function testTenInputsBindOriginalHeadsAndActualManifestFields() public {
        (
            StreamFinalityNativeProviderReads.Config memory c,
            StreamPreservationInventoryTypes.Evidence memory e
        ) = _inputFixture();
        StreamFinalityInputManifestTypes.Statement memory s = harness.statement(c, scope, _rows());
        require(
            s.inputs.rootRecordHash == e.originals.rootRecordHash
                && s.inputs.snapshotRecordHash == e.originals.snapshotRecordHash
        );
        require(
            s.inputs.referenceRenderRecordHash == e.originals.referenceRenderRecordHash
                && s.inputs.intentRecordHash == e.originals.intentRecordHash
                && s.inputs.intentWaiverRecordHash == 0
        );
        require(
            s.inputs.interviewEvidenceHash == e.originals.interviewEvidenceHash
                && s.inputs.rightsStatementRecordHash == e.originals.rightsStatementRecordHash
                && s.inputs.workDescriptionRecordHash == e.originals.workDescriptionRecordHash
        );
        require(
            s.inputs.renderCriticalEvidenceHash == e.renderCriticalEvidenceHash
                && s.inputs.bundleCoverageHash == bytes32(uint256(18))
        );
        require(
            s.snapshotManifestHash == bytes32(uint256(21))
                && s.referenceRenderManifestHash == bytes32(uint256(22)) && s.leafCount == 2
        );
    }

    function testMismatchedBundleCountRejected() public {
        (
            StreamFinalityNativeProviderReads.Config memory c,
            StreamPreservationInventoryTypes.Evidence memory e
        ) = _inputFixture();
        StreamPreservationInventoryTypes.BundleEvidence memory b =
            StreamPreservationInventoryTypes.BundleEvidence(
                e.planId,
                e.renderCriticalEvidenceHash,
                546,
                bytes32(uint256(17)),
                bytes32(uint256(18))
            );
        _put(
            c,
            19,
            abi.encodeCall(
                IStreamBundleArchiveCoverage.requireCoverage,
                (e.planId, e.renderCriticalEvidenceHash)
            ),
            abi.encode(b)
        );
        vm.expectRevert();
        harness.statement(c, scope, _rows());
    }

    function testFrozenCoreIsRequiredIndependentlyOfInventory() public {
        (StreamFinalityNativeProviderReads.Config memory c,) = _inputFixture();
        _put(
            c,
            0,
            abi.encodeCall(IStreamCoreFinalitySource.collectionFreezeStatus, (uint256(1))),
            abi.encode(false)
        );
        vm.expectRevert();
        harness.statement(c, scope, _rows());
    }

    function testCurrentRootMustEqualInventoryOriginal() public {
        (StreamFinalityNativeProviderReads.Config memory c,) = _inputFixture();
        _put(
            c,
            2,
            abi.encodeCall(IStreamContentRootPublication.collectionContentRootHead, (uint256(1))),
            abi.encode(bytes32(uint256(777)))
        );
        vm.expectRevert();
        harness.statement(c, scope, _rows());
    }

    function testSiblingSelectorConfigCannotBorrowInventory() public {
        (StreamFinalityNativeProviderReads.Config memory c,) = _inputFixture();
        c.targets[15] = address(new NativeProviderReadTable());
        c.codeHashes[15] = c.targets[15].codehash;
        vm.expectRevert();
        harness.statement(c, scope, _rows());
    }

    function testSnapshotAndEntropyMustUseSameOriginalInventory() public {
        (StreamFinalityNativeProviderReads.Config memory c,) = _inputFixture();
        _put(
            c,
            10,
            abi.encodeWithSignature("coordinatorInventory()"),
            abi.encode(address(new NativeProviderReadTable()))
        );
        vm.expectRevert();
        harness.statement(c, scope, _rows());
    }
}
