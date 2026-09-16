// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./StreamFinalityPreparedScope.t.sol";
import "../../../smart-contracts/domains/metadata/StreamSchemaRegistry.sol";
import { InputManifestGovernanceBoundary } from "./StreamFinalityInputManifestReads.t.sol";
import "../../../smart-contracts/domains/finality/StreamFinalityNativeSanctionReview.sol";

/// @dev Projection-only typed source boundaries. Complete native admission/ceremony remains outside this cohort.
contract NativeSanctionProjectionHarness {
    function review(
        StreamFinalityNativeProviderReads.Config calldata c,
        StreamFinalityInputManifestTypes.Statement calldata s
    ) external view returns (IStreamFinalitySanctionReview.ReviewFacts memory) {
        return StreamFinalityNativeSanctionReview.review(c, s);
    }
}

contract NativeReviewReturnBomb {
    fallback() external {
        assembly ("memory-safe") { return(0, 1048577) }
    }
}

contract StreamFinalityNativeSanctionReviewTest is CharacterizationTestBase {
    NativeSanctionProjectionHarness private harness;
    NativeProviderReadTable private table;
    StreamSchemaRegistry private schemas;
    StreamSchemaDocumentStore private store;
    InputManifestGovernanceBoundary private governance;
    bytes32 private constant PROFILE = keccak256("6529STREAM_ARTIST_SANCTION_NATIVE_CAPTURES_V1");
    StreamFinalityNativeProviderReads.Config private config;
    StreamFinalityInputManifestTypes.Statement private statement;
    StreamReferenceRenderTypes.Publication private publication;
    StreamReferenceRenderTypes.Receipt private receipt;
    IStreamMetadataServingFacts.ArtistPresentation private artist;
    bytes32 private constant ARTIST = keccak256("original frozen artist");

    function setUp() public {
        harness = new NativeSanctionProjectionHarness();
        table = new NativeProviderReadTable();
        config.chainId = block.chainid;
        config.readGas = 1000000;
        config.sourceGas = 4000000;
        for (uint256 i; i < 22; ++i) {
            config.targets[i] = address(table);
            config.codeHashes[i] = address(table).codehash;
        }
        _schemaStore();
        _register(
            "6529STREAM_ARTIST_SANCTION_NATIVE_CAPTURES_V1",
            IStreamSchemaRegistry.DocumentKind.CATALOG,
            StreamFinalityNativeSanctionProfile.document()
        );
        statement.scope = StreamFinalityScope(StreamFinalityScopeType.COLLECTION, 7, 0, 0);
        statement.contentRoot = keccak256("actual token content root");
        statement.inputs.referenceRenderRecordHash = keccak256("original reference record");
        statement.inputs.snapshotRecordHash = keccak256("original source snapshot");
        statement.referenceRenderManifestHash = keccak256("original reference manifest");
        receipt.recordHash = statement.inputs.referenceRenderRecordHash;
        receipt.collectionId = 7;
        receipt.referenceId = keccak256("reference identity");
        receipt.snapshotRecordHash = statement.inputs.snapshotRecordHash;
        receipt.snapshotRevision = 3;
        receipt.payloadHash = statement.referenceRenderManifestHash;
        receipt.payloadBytes = 99;
        receipt.sourcesHash = keccak256("original source facts");
        publication.collectionId = 7;
        publication.referenceId = receipt.referenceId;
        publication.snapshotRecordHash = receipt.snapshotRecordHash;
        publication.snapshotRevision = receipt.snapshotRevision;
        publication.expectedSourcesHash = receipt.sourcesHash;
        artist.registry = address(table);
        artist.registryCodeHash = address(table).codehash;
        artist.artistId = ARTIST;
        artist.locked = true;
        artist.bindingGeneration = 1;
        artist.bindingHash = keccak256("original binding");
        artist.identityRecordHash = keccak256("original identity");
        artist.acceptanceRecordHash = keccak256("original acceptance");
        artist.snapshotHash = keccak256("original presentation");
        artist.nominatedArtist = address(0x6529);
        _artist();
        _captures(2, false);
    }

    // Schema and immutable chunk storage are actual implementations; governance action context is typed.
    function _schemaStore() private {
        governance = new InputManifestGovernanceBoundary();
        schemas = new StreamSchemaRegistry(address(governance));
        store = StreamSchemaDocumentStore(schemas.chunkStore());
        config.targets[4] = address(schemas);
        config.codeHashes[4] = address(schemas).codehash;
        config.targets[5] = address(store);
        config.codeHashes[5] = address(store).codehash;
        _register(
            "RAW_BYTES",
            IStreamSchemaRegistry.DocumentKind.CANONICALIZATION,
            bytes(schemas.RAW_BYTES_DEFINITION())
        );
    }

    function _register(
        string memory name,
        IStreamSchemaRegistry.DocumentKind kind,
        bytes memory value
    ) private {
        (bytes32 hash,) = store.publishChunk(value);
        bytes32[] memory chunks = new bytes32[](1);
        chunks[0] = hash;
        IStreamSchemaRegistry.DocumentSpec memory spec = IStreamSchemaRegistry.DocumentSpec(
            name,
            kind,
            hash,
            keccak256("RAW_BYTES"),
            0,
            "ipfs://stream/definition",
            uint32(value.length)
        );
        (bytes32 scope, bytes32 oldHash, bytes32 newHash) =
            schemas.registrationTransition(spec, chunks);
        governance.run(
            address(schemas),
            abi.encodeCall(schemas.registerDocument, (spec, chunks)),
            scope,
            oldHash,
            newHash
        );
    }

    function _retireProfile() private {
        (bytes32 scope, bytes32 oldHash, bytes32 newHash) =
            schemas.statusTransition(PROFILE, IStreamSchemaRegistry.DocumentStatus.DEPRECATED);
        governance.run(
            address(schemas),
            abi.encodeCall(
                schemas.setDocumentStatus,
                (PROFILE, IStreamSchemaRegistry.DocumentStatus.DEPRECATED)
            ),
            scope,
            oldHash,
            newHash
        );
    }

    function _artist() private {
        table.put(
            abi.encodeCall(IStreamMetadataServingFacts.artistPresentation, (7)), abi.encode(artist)
        );
    }

    function _object(uint256 index)
        private
        pure
        returns (StreamExternalArtifactTypes.ObjectIdentity memory o)
    {
        o.artistId = ARTIST;
        o.schemaId = StreamReferenceRenderDefinitions.PNG_SCHEMA_ID;
        o.canonicalizationId = keccak256("RAW_BYTES");
        o.contentHash = keccak256(abi.encode("full original PNG", index));
        o.sha256Digest = sha256(abi.encode("full original PNG", index));
        o.arweaveDataRoot = keccak256(abi.encode("native root", index));
        o.byteSize = 100 + uint64(index);
        o.formatId = keccak256("IANA:image/png");
        o.formatCatalogId = StreamReferenceRenderDefinitions.FORMAT_CATALOG_ID;
        o.formatCatalogHash = StreamReferenceRenderDefinitions.FORMAT_CATALOG_HASH;
    }

    function _key(StreamExternalArtifactTypes.ObjectIdentity memory o)
        private
        view
        returns (bytes32)
    {
        return keccak256(
            abi.encode(
                keccak256("6529STREAM_EXTERNAL_OBJECT_V1"),
                block.chainid,
                address(table),
                config.targets[0],
                o
            )
        );
    }

    function _putObject(bytes32 key, StreamExternalArtifactTypes.ObjectIdentity memory o) private {
        table.put(
            abi.encodeCall(IStreamExternalArtifactCoverage.objectIdentity, (key)), abi.encode(o)
        );
    }

    function _captures(uint256 count, bool repeated) private {
        delete publication.captures;
        for (uint256 i; i < count; ++i) {
            StreamExternalArtifactTypes.ObjectIdentity memory o = _object(repeated ? 0 : i);
            StreamReferenceRenderTypes.Capture memory capture;
            capture.tokenId = 100 + i;
            capture.collectionSerial = i + 1;
            capture.objectHash = _key(o);
            capture.coverageHash = keccak256(abi.encode("original coverage", i));
            capture.animationHTML =
                bytes("<!doctype html><html><body>source for original render</body></html>");
            capture.htmlBytes = uint32(capture.animationHTML.length);
            capture.htmlHash = keccak256(capture.animationHTML);
            capture.sourceSha256 = sha256(capture.animationHTML);
            capture.repeatCaptureSha256 = [o.sha256Digest, o.sha256Digest];
            publication.captures.push(capture);
            _putObject(capture.objectHash, o);
        }
        _publication();
    }

    function _publication() private {
        table.put(
            abi.encodeCall(
                IStreamReferenceRenderPublication.referenceRecord,
                (statement.inputs.referenceRenderRecordHash)
            ),
            abi.encode(publication, receipt)
        );
        table.put(
            abi.encodeCall(IStreamReferenceRenderPublication.currentReference, (7)),
            abi.encode(receipt)
        );
    }

    function _review() private view returns (IStreamFinalitySanctionReview.ReviewFacts memory) {
        return harness.review(config, statement);
    }

    function _reject() private {
        vm.expectRevert();
        harness.review(config, statement);
    }

    function testRegisteredProfileBytesMatchPortableDocumentAndOriginalBases() public {
        bytes memory expected =
            bytes(vm.readFile("docs/schemas/finality/sanction-native-captures-v1.profile.json"));
        require(
            keccak256(expected) == keccak256(StreamFinalityNativeSanctionProfile.document()),
            "portable profile"
        );
        require(
            keccak256(schemas.documentBytes(PROFILE)) == keccak256(expected), "actual registry copy"
        );
        require(
            keccak256(store.readChunk(keccak256(expected))) == keccak256(expected),
            "actual store copy"
        );
        require(
            keccak256(bytes(vm.readFile("docs/schemas/finality/sanction-ceremony-v1.schema.json")))
                == 0xd964c877b4256e4e829aa2630470b85832e4aa1e8a59da32094334550341600a,
            "original ceremony schema"
        );
        require(
            keccak256(bytes(vm.readFile("docs/schemas/finality/sanction-ceremony-jcs-v1.json")))
                == 0x0d8a4197d8a294bd36eb4fd400c1ecc88ac8104c7091223b5436892a4797eef4,
            "original ceremony rules"
        );
        require(
            keccak256(bytes(vm.readFile("docs/schemas/finality/sanction-archive-v1.schema.json")))
                == 0xd55474e8f3ce5aacaa70ca4a40aee030b39b366143118c9d27ff2547e85efb1a,
            "original archive schema"
        );
        require(
            keccak256(bytes(vm.readFile("docs/schemas/finality/sanction-archive-abi-v1.json")))
                == 0x4b09880c931db919d35159b9974e21dcf1583bfaa65c18e3636e8721140cc690,
            "original archive rules"
        );
        require(_review().profile == 2, "actual registered profile admission");
    }

    function testMissingProfileRejectsMultipleButNotSingleCapture() public {
        _schemaStore();
        _reject();
        _captures(1, false);
        require(_review().profile == 1, "original single profile unaffected");
    }

    function testUnregisteredStoredProfileCannotAdmit() public {
        _schemaStore();
        store.publishChunk(StreamFinalityNativeSanctionProfile.document());
        _reject();
    }

    function testWrongRegisteredProfileBytesReject() public {
        _schemaStore();
        _register(
            "6529STREAM_ARTIST_SANCTION_NATIVE_CAPTURES_V1",
            IStreamSchemaRegistry.DocumentKind.CATALOG,
            bytes("{}")
        );
        _reject();
    }

    function testWrongRegisteredProfileKindRejects() public {
        _schemaStore();
        _register(
            "6529STREAM_ARTIST_SANCTION_NATIVE_CAPTURES_V1",
            IStreamSchemaRegistry.DocumentKind.SCHEMA,
            StreamFinalityNativeSanctionProfile.document()
        );
        _reject();
    }

    function testRetiredProfileStopsNewAdmissionButRetainsOriginalBytes() public {
        IStreamFinalitySanctionReview.ReviewFacts memory original = _review();
        bytes memory historicalBytes = schemas.documentBytes(PROFILE);
        _retireProfile();
        _reject();
        require(
            keccak256(schemas.documentBytes(PROFILE)) == keccak256(historicalBytes),
            "retained registry bytes"
        );
        require(
            keccak256(store.readChunk(keccak256(historicalBytes))) == keccak256(historicalBytes),
            "retained store bytes"
        );
        require(
            original.referenceRenderContentHashes[0] == _object(0).contentHash,
            "original projection retained"
        );
        _captures(1, false);
        require(_review().profile == 1, "profile1 still available");
    }

    function testProfileSchemaAndStorePinsRemainRequired() public {
        config.codeHashes[4] = keccak256("another registry runtime");
        _reject();
        config.codeHashes[4] = address(schemas).codehash;
        config.codeHashes[5] = keccak256("another store runtime");
        _reject();
    }

    function testProfile1PreservesOneOriginalCapture() public {
        _captures(1, false);
        IStreamFinalitySanctionReview.ReviewFacts memory result = _review();
        require(
            result.schemaVersion == 1 && result.profile == 1
                && result.mediaContentHashes.length == 0
        );
        require(
            result.contentRoot == statement.contentRoot
                && result.referenceRenderContentHashes.length == 1
        );
        require(result.referenceRenderContentHashes[0] == _object(0).contentHash);
        require(abi.encode(result).length == 288);
    }

    function testProfile2PreservesOrderedOriginalCaptureHashes() public {
        IStreamFinalitySanctionReview.ReviewFacts memory result = _review();
        require(
            result.schemaVersion == 1 && result.profile == 2
                && result.mediaContentHashes.length == 0
        );
        require(result.referenceRenderContentHashes[0] == _object(0).contentHash);
        require(result.referenceRenderContentHashes[1] == _object(1).contentHash);
        require(result.referenceRenderContentHashes[0] != publication.captures[0].objectHash);
        require(result.referenceRenderContentHashes[0] != publication.captures[0].sourceSha256);
        require(abi.encode(result).length == 320);
    }

    function testRepeatedCaptureBytesKeepEveryOccurrence() public {
        _captures(2, true);
        IStreamFinalitySanctionReview.ReviewFacts memory result = _review();
        require(result.referenceRenderContentHashes.length == 2);
        require(result.referenceRenderContentHashes[0] == result.referenceRenderContentHashes[1]);
    }

    function testFuzzProjectionPreservesAllOrderedEntries(uint8 seed) public {
        uint256 count = 1 + uint256(seed) % 16;
        _captures(count, false);
        IStreamFinalitySanctionReview.ReviewFacts memory result = _review();
        require(result.profile == (count == 1 ? 1 : 2));
        require(
            result.referenceRenderContentHashes.length == count
                && abi.encode(result).length == 256 + 32 * count
        );
        for (uint256 i; i < count; ++i) {
            require(result.referenceRenderContentHashes[i] == _object(i).contentHash);
        }
    }

    function testZeroAndOversizedCaptureListsRevert() public {
        _captures(0, false);
        _reject();
        _captures(17, false);
        _reject();
    }

    function testWrongScopeAndZeroRootRevert() public {
        statement.scope.tokenId = 1;
        _reject();
        statement.scope.tokenId = 0;
        statement.scope.scopeId = bytes32(uint256(1));
        _reject();
        statement.scope.scopeId = 0;
        statement.contentRoot = 0;
        _reject();
    }

    function testChangedOriginalReceiptAndSnapshotRevert() public {
        receipt.recordHash = keccak256("substituted original");
        _publication();
        _reject();
        receipt.recordHash = statement.inputs.referenceRenderRecordHash;
        receipt.snapshotRecordHash = keccak256("other snapshot");
        _publication();
        _reject();
    }

    function testChangedManifestAndSourceJoinRevert() public {
        receipt.payloadHash = keccak256("another manifest");
        _publication();
        _reject();
        receipt.payloadHash = statement.referenceRenderManifestHash;
        publication.expectedSourcesHash = keccak256("another source");
        _publication();
        _reject();
    }

    function testCurrentHeadMustBeTheSameOriginalReceipt() public {
        StreamReferenceRenderTypes.Receipt memory current = receipt;
        current.revision += 1;
        table.put(
            abi.encodeCall(IStreamReferenceRenderPublication.currentReference, (7)),
            abi.encode(current)
        );
        _reject();
    }

    function testNoncanonicalOriginalPublicationReverts() public {
        table.put(
            abi.encodeCall(
                IStreamReferenceRenderPublication.referenceRecord,
                (statement.inputs.referenceRenderRecordHash)
            ),
            bytes.concat(abi.encode(publication, receipt), bytes32(0))
        );
        _reject();
    }

    function testFrozenArtistBindingAndRuntimeAreRequired() public {
        artist.locked = false;
        _artist();
        _reject();
        artist.locked = true;
        artist.registryCodeHash = keccak256("other runtime");
        _artist();
        _reject();
    }

    function testDifferentArtistObjectReverts() public {
        StreamExternalArtifactTypes.ObjectIdentity memory o = _object(0);
        o.artistId = keccak256("other artist");
        _putObject(publication.captures[0].objectHash, o);
        _reject();
    }

    function testObjectPreimagePreventsContentAndKeySubstitution() public {
        StreamExternalArtifactTypes.ObjectIdentity memory o = _object(0);
        o.contentHash = receipt.recordHash;
        _putObject(publication.captures[0].objectHash, o);
        _reject();
    }

    function testOriginalPngSHA256MustMatchRepeatedCapture() public {
        publication.captures[0].repeatCaptureSha256 =
            [keccak256("incorrect flat digest"), keccak256("incorrect flat digest")];
        _publication();
        _reject();
    }

    function testHtmlSourceAndRenderedPngDigestsRemainDistinct() public view {
        require(
            publication.captures[0].sourceSha256 == sha256(publication.captures[0].animationHTML),
            "HTML source digest"
        );
        require(
            publication.captures[0].sourceSha256 != _object(0).sha256Digest,
            "source is not rendered PNG"
        );
        require(
            _review().referenceRenderContentHashes[0] == _object(0).contentHash,
            "original full PNG content"
        );
    }

    function testMissingOrDisagreeingRepeatedPngDigestsReject() public {
        publication.captures[0].repeatCaptureSha256[0] = 0;
        _publication();
        _reject();
        publication.captures[0].repeatCaptureSha256[0] = _object(0).sha256Digest;
        publication.captures[0].repeatCaptureSha256[1] = 0;
        _publication();
        _reject();
        publication.captures[0].repeatCaptureSha256[1] = publication.captures[0].sourceSha256;
        _publication();
        _reject();
    }

    function testPNGSchemaFormatAndCatalogAreFixed() public {
        bytes32 key = publication.captures[0].objectHash;
        for (uint256 i; i < 4; ++i) {
            StreamExternalArtifactTypes.ObjectIdentity memory o = _object(0);
            if (i == 0) o.schemaId = keccak256("unreviewed schema");
            if (i == 1) o.formatId = keccak256("IANA:application/zip");
            if (i == 2) o.formatCatalogHash = keccak256("unreviewed catalog");
            if (i == 3) o.canonicalizationId = keccak256("another canonicalization");
            bytes32 changed = _key(o);
            publication.captures[0].objectHash = changed;
            _putObject(changed, o);
            _publication();
            _reject();
        }
        publication.captures[0].objectHash = key;
    }

    function testZeroObjectFactsAndNoncanonicalEncodingRevert() public {
        StreamExternalArtifactTypes.ObjectIdentity memory o = _object(0);
        o.byteSize = 0;
        _putObject(publication.captures[0].objectHash, o);
        _reject();
        table.put(
            abi.encodeCall(
                IStreamExternalArtifactCoverage.objectIdentity, (publication.captures[0].objectHash)
            ),
            bytes.concat(abi.encode(_object(0)), bytes32(0))
        );
        _reject();
    }

    function testRuntimeAndChainPinsAreRequired() public {
        config.codeHashes[21] = keccak256("changed runtime");
        _reject();
        config.codeHashes[21] = address(table).codehash;
        config.chainId += 1;
        _reject();
    }

    function testPublicationReturnBombIsBounded() public {
        address bomb = address(new NativeReviewReturnBomb());
        config.targets[9] = bomb;
        config.codeHashes[9] = bomb.codehash;
        _reject();
    }

    function testBurningPublicationReadFailsAndHealthyRetryWorks() public {
        address burner = address(new PreparedReadBurner());
        config.targets[9] = burner;
        config.codeHashes[9] = burner.codehash;
        config.sourceGas = 300000;
        (bool success,) = address(harness).staticcall{ gas: 1000000 }(
            abi.encodeCall(harness.review, (config, statement))
        );
        require(!success, "burning source must fail");
        config.targets[9] = address(table);
        config.codeHashes[9] = address(table).codehash;
        require(
            _review().referenceRenderContentHashes.length == 2,
            "same healthy read remains available"
        );
    }
}
