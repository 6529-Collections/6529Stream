// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamMetadataRecoveryRoutes
} from "../../../smart-contracts/domains/metadata/StreamMetadataRecoveryRoutes.sol";
import {
    StreamMetadataRouter
} from "../../../smart-contracts/domains/metadata/StreamMetadataRouter.sol";
import {
    StreamCollectionMetadataV1
} from "../../../smart-contracts/domains/metadata/StreamCollectionMetadataV1.sol";
import {
    StreamSchemaRegistry
} from "../../../smart-contracts/domains/metadata/StreamSchemaRegistry.sol";
import {
    StreamSchemaDocumentStore
} from "../../../smart-contracts/domains/metadata/StreamSchemaDocumentStore.sol";
import {
    IStreamCollectionMetadataV1
} from "../../../smart-contracts/interfaces/stream/metadata/IStreamCollectionMetadataV1.sol";
import {
    IStreamCollectionManifestReads
} from "../../../smart-contracts/interfaces/stream/metadata/IStreamCollectionManifestReads.sol";
import {
    IStreamCollectionManifestWriter
} from "../../../smart-contracts/interfaces/stream/metadata/IStreamCollectionManifestWriter.sol";
import {
    StreamCollectionManifestTypes as M
} from "../../../smart-contracts/interfaces/stream/metadata/StreamCollectionManifestTypes.sol";
import {
    PresentationCoreBoundary,
    PresentationEntropyBoundary
} from "./StreamMetadataServing.t.sol";
import { MetadataExecutorBoundary } from "./StreamCollectionMetadataV1.t.sol";
import "../../../smart-contracts/interfaces/stream/artist/IStreamArtistAttribution.sol";
import "../../../smart-contracts/interfaces/stream/artist/IStreamArtistContentRatification.sol";
import "../../../smart-contracts/interfaces/stream/artist/IStreamArtistContentAuthority.sol";
import "../../../smart-contracts/interfaces/stream/parameters/IStreamGasParameterHost.sol";
import "../../regression/legacy/helpers/CharacterizationTestBase.sol";
import "../../helpers/OfficialSafeFixture.sol";

contract ManifestArtistBoundary {
    address public core;
    address public router;
    mapping(bytes32 => bytes32) private approvals;
    C.FreezeRecord private frozen;

    constructor(address c) {
        core = c;
    }

    function setRouter(address r) external {
        router = r;
    }

    function supportsInterface(bytes4 id) external pure returns (bool) {
        return id == type(IStreamArtistAttribution).interfaceId
            || id == type(IStreamArtistContentRatification).interfaceId;
    }

    function attribution(uint256)
        external
        pure
        returns (IStreamCollectionArtistRegistry.Attribution memory a)
    {
        a.nominatedArtist = address(0xa11ce);
        a.artist = address(0xa11ce);
    }

    function firstReleaseRatification(uint256) external pure returns (bool, bytes32, bytes32) {
        return (false, 0, 0);
    }

    function approve(uint256 c, bytes32 family, bytes32 state, bytes32 evidence) external {
        approvals[keccak256(abi.encode(c, family, state))] = evidence;
    }

    function contentConsentEvidence(uint256 c, bytes32 family, bytes32 state)
        external
        view
        returns (bytes32)
    {
        require(msg.sender == router, "canonical content caller");
        return approvals[keccak256(abi.encode(c, family, state))];
    }

    function freeze(bytes32 family, bytes32 state) external {
        frozen.recordHash = keccak256("manifest freeze");
        frozen.artistId = keccak256("artist");
        frozen.metadataContract = router;
        frozen.expectedStateHash = state;
        frozen.authorityClass = 1;
        delete frozen.lockClasses;
        frozen.lockClasses.push(family);
    }

    function contentFreezeAuthorization(bytes32) external view returns (C.FreezeRecord memory) {
        return frozen;
    }

    function isContentFreezeAuthorized(uint256, bytes32 family)
        external
        view
        returns (bool, bytes32)
    {
        return
            (frozen.lockClasses.length == 1 && frozen.lockClasses[0] == family, frozen.recordHash);
    }
}

/// @notice Actual Router/metadata/blob storage and threshold Safe, with typed Core/Artist/Executor boundaries.
contract StreamCollectionManifestsTest is CharacterizationTestBase, OfficialSafeFixture {
    PresentationCoreBoundary private core;
    ManifestArtistBoundary private artist;
    StreamMetadataRouter private router;
    StreamCollectionMetadataV1 private metadata;
    StreamSchemaRegistry private schemas;
    bytes32 private constant SCRIPT = keccak256("SCRIPT");
    bytes32 private constant MEDIA = keccak256("MEDIA_MANIFEST");
    string private constant JS = "document.body.textContent = tokenId;";

    function setUp() public {
        core = new PresentationCoreBoundary();
        artist = new ManifestArtistBoundary(address(core));
        core.configure(address(artist), address(new PresentationEntropyBoundary()));
        router = _router(address(this));
        artist.setRouter(address(router));
        MetadataExecutorBoundary executor = new MetadataExecutorBoundary();
        schemas = new StreamSchemaRegistry(address(executor));
        StreamCollectionMetadataV1.Configuration memory c;
        c.core = address(core);
        c.executor = address(executor);
        c.schemas = address(schemas);
        c.artistRegistry = address(artist);
        c.deploymentManifestHash = keccak256("deployment");
        c.manifestHash = keccak256("manifest");
        c.manifestURI = "ipfs://metadata";
        c.dependencyReadGas = IStreamGasParameterHost.GasParameterConfig(
            "METADATA_DEPENDENCY_READ_GAS", 1000000, 100000, 2
        );
        c.artistReadGas = IStreamGasParameterHost.GasParameterConfig(
            "METADATA_ARTIST_READ_GAS", 2000000, 1000000, 2
        );
        metadata = new StreamCollectionMetadataV1(c);
        _pointer(keccak256("METADATA_ROUTER"), address(router));
        _pointer(keccak256("COLLECTION_METADATA"), address(metadata));
        router.setCollectionMetadata(1, "Name", "Description", "ipfs://image", "");
        router.setCollectionScript(1, JS);
        core.setMinted(1);
    }

    function _router(address authority) private returns (StreamMetadataRouter) {
        return new StreamMetadataRouter(
            address(core),
            authority,
            keccak256("deployment"),
            "urn:router",
            keccak256("manifest"),
            IStreamArtistAttribution(address(artist))
        );
    }

    function _pointer(bytes32 key, address target) private {
        StreamMetadataRecoveryRoutes.Pointer memory p;
        p.target = target;
        p.codeHash = target.codehash;
        p.status = 1;
        p.revision = 1;
        core.setRecoveryPointer(key, p);
    }

    function _script() private pure returns (M.ScriptManifest memory m) {
        m.scriptHash = keccak256(bytes(JS));
        m.rendererCompatibility = keccak256("6529STREAM_ROUTER_STABLE_PRESENTATION_V1");
        m.sourceType = M.PayloadSourceType.INLINE_CHUNKS;
        m.scriptURI = "ipfs://script-mirror";
        m.mimeType = "application/javascript";
        m.chunkCount = 1;
        m.executable = true;
    }

    function _media() private pure returns (M.MediaManifest memory m) {
        m.imageSourceType = M.PayloadSourceType.IPFS;
        m.imageURI = "ipfs://image";
        m.imageHash = keccak256("actual image commitment");
        m.imageMimeType = "image/png";
        m.manifestURI = "ipfs://media-descriptors";
        m.manifestHash = keccak256("descriptor bytes");
    }

    function _approveScript(M.ScriptManifest memory m, bytes32 evidence) private {
        artist.approve(1, SCRIPT, router.previewArtistScriptManifestState(1, m), evidence);
    }

    function testScriptFullTypedHashActualBytesNoopAndSourceInvalidation() public {
        M.ScriptManifest memory m = _script();
        bytes32 evidence = keccak256("script approval");
        _approveScript(m, evidence);
        bytes32 expected = keccak256(
            abi.encode(
                keccak256("6529STREAM_CURRENT_SCRIPT_MANIFEST_V1"),
                block.chainid,
                address(core),
                address(metadata),
                address(router),
                address(router).codehash,
                uint256(1),
                m.scriptHash,
                m
            )
        );
        vm.recordLogs();
        router.setCollectionScriptManifest(1, m);
        Vm.Log[] memory logs = vm.getRecordedLogs();
        bool stored;
        bool selected;
        for (uint256 i; i < logs.length; ++i) {
            if (
                logs[i].topics.length != 4 || logs[i].topics[1] != bytes32(uint256(1))
                    || logs[i].topics[2] != bytes32(uint256(2)) || logs[i].topics[3] != expected
            ) continue;
            if (
                logs[i].emitter == address(metadata)
                    && logs[i].topics[0]
                        == keccak256(
                            "CollectionManifestStored(uint16,uint256,uint8,bytes32,address,bytes32)"
                        )
            ) {
                require(
                    keccak256(logs[i].data)
                        == keccak256(abi.encode(uint16(1), address(router), m.scriptHash))
                );
                stored = true;
            }
            if (
                logs[i].emitter == address(router)
                    && logs[i].topics[0]
                        == keccak256(
                            "CollectionManifestSelected(uint16,uint256,uint8,bytes32,address,bytes32)"
                        )
            ) {
                require(
                    keccak256(logs[i].data)
                        == keccak256(
                            abi.encode(uint16(1), address(metadata), address(metadata).codehash)
                        )
                );
                selected = true;
            }
        }
        require(stored && selected, "exact manifest events");
        require(metadata.scriptManifestHash(1) == expected && expected != m.scriptHash);
        require(keccak256(abi.encode(metadata.scriptManifest(1))) == keccak256(abi.encode(m)));
        require(
            keccak256(metadata.scriptChunk(1, 0)) == m.scriptHash
                && router.consumedArtistContentConsent(evidence)
        );
        (bool supported, bytes32 family) = router.artistContentFamilyState(1, SCRIPT);
        require(supported);
        require(router.previewArtistScriptState(1, JS) == family);
        router.setCollectionScriptManifest(1, m); // exact no-op does not consume again
        artist.approve(
            1, SCRIPT, router.previewArtistScriptState(1, "new script"), keccak256("new raw")
        );
        router.setCollectionScript(1, "new script");
        require(metadata.scriptManifestHash(1) == 0);
        require(
            keccak256(abi.encode(metadata.recordedScriptManifest(expected)))
                == keccak256(abi.encode(m))
        );
    }

    function testMediaFullDescriptorAndExactSourceBinding() public {
        M.MediaManifest memory m = _media();
        artist.approve(
            1, MEDIA, router.previewArtistMediaManifestState(1, m), keccak256("media approval")
        );
        router.setCollectionMediaManifest(1, m);
        bytes32 expected = keccak256(
            abi.encode(
                keccak256("6529STREAM_CURRENT_MEDIA_MANIFEST_V1"),
                block.chainid,
                address(core),
                address(metadata),
                address(router),
                address(router).codehash,
                uint256(1),
                keccak256(abi.encode("ipfs://image", "")),
                m
            )
        );
        require(
            metadata.mediaManifestHash(1) == expected
                && keccak256(abi.encode(metadata.mediaManifest(1))) == keccak256(abi.encode(m))
        );
        m.imageURI = "ipfs://different";
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamCollectionManifestWriter.InvalidCollectionManifest.selector
            )
        );
        router.previewArtistMediaManifestState(1, m);
        artist.approve(
            1,
            MEDIA,
            router.previewArtistMediaState(1, "ipfs://new-image", ""),
            keccak256("new image approval")
        );
        router.setCollectionMetadata(1, "Name", "Description", "ipfs://new-image", "");
        require(metadata.mediaManifestHash(1) == 0);
        require(metadata.recordedMediaManifest(expected).imageHash != 0);
    }

    function testWrongFamilyOrCollectionApprovalAndDirectHostCannotWrite() public {
        M.ScriptManifest memory m = _script();
        bytes32 state = router.previewArtistScriptManifestState(1, m);
        artist.approve(2, SCRIPT, state, keccak256("wrong collection"));
        artist.approve(1, MEDIA, state, keccak256("wrong family"));
        vm.expectRevert(
            abi.encodeWithSelector(
                StreamMetadataRouter.ArtistContentAuthorizationRequired.selector, uint256(1)
            )
        );
        router.setCollectionScriptManifest(1, m);
        vm.expectRevert(
            abi.encodeWithSelector(IStreamCollectionMetadataV1.MetadataAuthorityRequired.selector)
        );
        metadata.storeScriptManifest(1, m);
        require(metadata.scriptManifestHash(1) == 0);
        _approveScript(m, keccak256("correct"));
        router.setCollectionScriptManifest(1, m);
        require(metadata.scriptManifestHash(1) != 0);
    }

    function testWholeContentFreezeCoversTypedManifestAndCoreFreeze() public {
        M.ScriptManifest memory m = _script();
        _approveScript(m, keccak256("before freeze"));
        router.setCollectionScriptManifest(1, m);
        artist.freeze(SCRIPT, router.artistContentFreezeState(1));
        router.applyArtistContentFreeze(1, keccak256("manifest freeze"));
        m.scriptURI = "ipfs://changed-mirror";
        vm.expectRevert(
            abi.encodeWithSelector(
                StreamMetadataRouter.ArtistContentLocked.selector, uint256(1), SCRIPT
            )
        );
        router.setCollectionScriptManifest(1, m);
        core.setFrozen(true);
        M.MediaManifest memory media = _media();
        vm.expectRevert(
            abi.encodeWithSelector(StreamMetadataRouter.CollectionFrozen.selector, uint256(1))
        );
        router.setCollectionMediaManifest(1, media);
    }

    function testUnsupportedExecutionAndMissingHashNeverBecomeManifests() public {
        M.ScriptManifest memory m = _script();
        m.executable = false;
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamCollectionManifestWriter.UnsupportedCollectionManifest.selector
            )
        );
        router.previewArtistScriptManifestState(1, m);
        m = _script();
        m.scriptHash = keccak256("unrelated script");
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamCollectionManifestWriter.InvalidCollectionManifest.selector
            )
        );
        router.previewArtistScriptManifestState(1, m);
        M.MediaManifest memory media = _media();
        media.imageSourceType = M.PayloadSourceType.NONE;
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamCollectionManifestWriter.InvalidCollectionManifest.selector
            )
        );
        router.previewArtistMediaManifestState(1, media);
        require(metadata.scriptManifestHash(1) == 0 && metadata.mediaManifestHash(1) == 0);
    }

    function testOptionalScriptMirrorUsesContentURIsWithoutExecutingThem() public {
        M.ScriptManifest memory m = _script();
        string[4] memory allowed =
            ["", "ipfs://mirror", "ar://mirror", "https://example.test/mirror.js"];
        for (uint256 i; i < allowed.length; ++i) {
            m.scriptURI = allowed[i];
            require(router.previewArtistScriptManifestState(1, m) != 0);
        }
        string[4] memory rejected = [
            "javascript:alert(1)",
            "data:text/javascript,alert(1)",
            "http://example.test/script",
            "https://"
        ];
        for (uint256 i; i < rejected.length; ++i) {
            m.scriptURI = rejected[i];
            vm.expectRevert(abi.encodeWithSelector(bytes4(keccak256("UnsafeMetadataURI()"))));
            router.previewArtistScriptManifestState(1, m);
        }
    }

    function testAbsentExternalHashesRoundTripWithoutClaimingVerifiedBytes() public {
        M.MediaManifest memory m = _media();
        m.imageHash = 0;
        m.manifestHash = 0;
        m.alternatesURI = "https://example.test/alternates.json";
        artist.approve(
            1,
            MEDIA,
            router.previewArtistMediaManifestState(1, m),
            keccak256("explicit absent hashes")
        );
        router.setCollectionMediaManifest(1, m);
        require(metadata.mediaManifestHash(1) != 0);
        M.MediaManifest memory got = metadata.mediaManifest(1);
        require(keccak256(abi.encode(got)) == keccak256(abi.encode(m)));
        require(got.imageHash == 0 && got.manifestHash == 0 && got.alternatesHash == 0);
        m.alternatesURI = "";
        m.alternatesHash = keccak256("orphan digest");
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamCollectionManifestWriter.InvalidCollectionManifest.selector
            )
        );
        router.previewArtistMediaManifestState(1, m);
    }

    function testSelectedOwnerDriftFailsClosedAndRestorationRetainsManifest() public {
        M.ScriptManifest memory m = _script();
        _approveScript(m, keccak256("source owner"));
        router.setCollectionScriptManifest(1, m);
        bytes32 hash = metadata.scriptManifestHash(1);
        _pointer(keccak256("COLLECTION_METADATA"), address(artist));
        vm.expectRevert(
            abi.encodeWithSelector(IStreamCollectionMetadataV1.MetadataHostNotSelected.selector)
        );
        metadata.scriptManifestHash(1);
        _pointer(keccak256("COLLECTION_METADATA"), address(metadata));
        require(metadata.scriptManifestHash(1) == hash);
        _pointer(keccak256("METADATA_ROUTER"), address(artist));
        vm.expectRevert();
        metadata.scriptManifestHash(1);
        _pointer(keccak256("METADATA_ROUTER"), address(router));
        require(metadata.scriptManifestHash(1) == hash);
    }

    function testActualSafeMissingApprovalRestoresIdenticalSignedCall() public {
        uint256[] memory keys = new uint256[](2);
        keys[0] = 71;
        keys[1] = 72;
        OfficialSafe account =
            createOfficialSafe(deploySafeComponents("1.4.1"), safeOwnerAddresses(keys), 2, 9001);
        router = _router(address(account));
        artist.setRouter(address(router));
        _pointer(keccak256("METADATA_ROUTER"), address(router));
        core.setMinted(0);
        require(
            executeSafe(
                account,
                keys,
                address(router),
                0,
                abi.encodeCall(
                    router.setCollectionMetadata, (1, "Name", "Description", "ipfs://image", "")
                ),
                0
            )
        );
        require(
            executeSafe(
                account,
                keys,
                address(router),
                0,
                abi.encodeCall(router.setCollectionScript, (1, JS)),
                0
            )
        );
        core.setMinted(1);
        M.ScriptManifest memory m = _script();
        bytes memory data = abi.encodeCall(router.setCollectionScriptManifest, (1, m));
        uint256 nonce = account.nonce();
        bytes32 digest = account.getTransactionHash(
            address(router), 0, data, 0, 0, 0, 0, address(0), address(0), nonce
        );
        bytes memory signatures = safeThresholdSignature(keys, digest);
        bytes memory transaction = abi.encodeCall(
            account.execTransaction,
            (address(router), 0, data, 0, 0, 0, 0, address(0), payable(address(0)), signatures)
        );
        (bool ok, bytes memory reason) = address(account).call(transaction);
        require(
            !ok && keccak256(reason) == keccak256(abi.encodeWithSignature("Error(string)", "GS013"))
                && account.nonce() == nonce
        );
        require(metadata.scriptManifestHash(1) == 0);
        _approveScript(m, keccak256("safe approval"));
        (ok, reason) = address(account).call(transaction);
        require(ok && abi.decode(reason, (bool)) && account.nonce() == nonce + 1);
        require(metadata.scriptManifestHash(1) != 0);
    }
}
