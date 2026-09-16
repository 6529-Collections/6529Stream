// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./StreamReferenceSourceExport.t.sol";
import { ReferencePriorManifestJson } from "./ReferencePriorManifestJson.sol";
import {
    StreamSnapshotSourceReads
} from "../../../smart-contracts/domains/records/StreamSnapshotSourceReads.sol";
import "./StreamExternalArtifactCoverage.t.sol";
import {
    StreamReferenceRenderPublication
} from "../../../smart-contracts/domains/preservation/StreamReferenceRenderPublication.sol";
import {
    StreamReferenceRenderTypes
} from "../../../smart-contracts/interfaces/stream/preservation/StreamReferenceRenderTypes.sol";
import {
    StreamReferenceRendererCatalog
} from "../../../smart-contracts/domains/records/StreamReferenceRendererCatalog.sol";
import {
    StreamReferenceEnvironmentJson
} from "../../../smart-contracts/domains/records/StreamReferenceEnvironmentJson.sol";
import {
    StreamReferenceRenderDefinitions
} from "../../../smart-contracts/domains/records/StreamReferenceRenderDefinitions.sol";

import {
    StreamFinalityReferenceReads
} from "../../../smart-contracts/domains/finality/StreamFinalityReferenceReads.sol";
import {
    StreamFinalityReferenceEvidence
} from "../../../smart-contracts/interfaces/stream/finality/StreamFinalityReferenceTypes.sol";

/// @dev Test-only transaction envelope. Its decoder runs before the inner CALL timer.
///      Under --isolate this external entry starts a fresh context; it does not pre-read Safe
///      or source dependencies. The fixed child gas budget excludes this wrapper transaction.
contract ReferenceSafeEnvelopeProbe {
    function execute(address safe, bytes memory transaction, uint256 available)
        external
        returns (uint256 used)
    {
        require(gasleft() > available + available / 63 + 10000, "envelope forwarding reserve");
        uint256 before = gasleft();
        (bool ok, bytes memory result) = safe.call{ gas: available }(transaction);
        used = before - gasleft();
        require(ok && result.length == 32 && abi.decode(result, (bool)), "bounded Safe execution");
        require(used <= available, "CALL overhead remains inside envelope");
    }
}

contract ReferenceFixedConsumer {
    StreamFinalityReferenceReads.Dependencies private fixedDependencies;

    constructor(StreamFinalityReferenceReads.Dependencies memory d) {
        fixedDependencies = d;
    }

    function read(StreamFinalityScope calldata scope, bytes32 hash, uint64 revision, bool locked)
        external
        view
        returns (StreamFinalityReferenceEvidence memory)
    {
        return locked
            ? StreamFinalityReferenceReads.requireLocked(fixedDependencies, scope, hash, revision)
            : StreamFinalityReferenceReads.requireCurrent(fixedDependencies, scope, hash, revision);
    }
}

import {
    StreamReferenceRenderSourceReads
} from "../../../smart-contracts/domains/preservation/StreamReferenceRenderSourceReads.sol";

interface ReferenceFixtureVm {
    function toString(bytes calldata) external pure returns (string memory);
    function parseJsonString(string calldata, string calldata) external pure returns (string memory);
    function parseJsonUint(string calldata, string calldata) external pure returns (uint256);
}

/// @notice Actual reference, Snapshot, Router, Schema/Store, external proof/coverage/RoleRegistry and Safe execution.
/// @dev Core/Executor/artist/seed/old content-leaf archive and network observer assertions are explicit fixtures.
contract StreamReferenceRenderPublicationTest is ReferenceSourceExportTest {
    ReferenceFixtureVm private constant fixtureVm =
        ReferenceFixtureVm(address(uint160(uint256(keccak256("hevm cheat code")))));
    StreamExternalArtifactCoverage private archiveHost;
    StreamArweaveObjectCheckpointVerifier private archiveVerifier;
    StreamRoleRegistry private archiveRoles;
    OfficialSafe private archiveAgentSafe;
    OfficialSafe private archiveFixitySafe;
    uint256[] private archiveAgentKeys;
    uint256[] private archiveFixityKeys;
    uint256 private constant OBSERVER_A = 0x652921;
    uint256 private constant OBSERVER_B = 0x652922;
    uint256 private constant SECOND_AGENT = 0x652925;
    E.ObjectIdentity private archiveObject;
    bytes32 private archiveObjectHash;
    bytes32 private archiveCheckpointHash;
    bytes32 private archiveTransactionId;
    bytes32 private archiveFirstFamily;
    bytes32 private archiveSecondFamily;
    bytes private archiveFirstPath;
    bytes private archiveLastPath;
    StreamReferenceRenderPublication private referenceHost;
    StreamReferenceRenderTypes.Publication private terms;
    bytes32[3] private originalFirstReceipts;
    bytes32[3] private originalSecondReceipts;

    function setUp() public override {
        super.setUp();
        archiveRoles = new StreamRoleRegistry(address(executor));
        cheat.mockCall(
            address(executor),
            abi.encodeWithSignature("roleRegistry()"),
            abi.encode(address(archiveRoles))
        );
        cheat.mockCall(
            core.selected(keccak256("MODULE_REGISTRY")),
            abi.encodeWithSignature("governanceExecutor()"),
            abi.encode(address(executor))
        );
        A.Observer[] memory observers = new A.Observer[](2);
        observers[0] = A.Observer(safeVm.addr(OBSERVER_A), keccak256("observer-one"));
        observers[1] = A.Observer(safeVm.addr(OBSERVER_B), keccak256("observer-two"));
        if (observers[0].account > observers[1].account) {
            (observers[0], observers[1]) = (observers[1], observers[0]);
        }
        archiveVerifier = new StreamArweaveObjectCheckpointVerifier(
            address(executor),
            observers,
            2,
            IStreamGasParameterHost.GasParameterConfig(
                "ARCHIVAL_ERC1271_VERIFY_GAS", 400000, 90000, 2
            )
        );
        archiveHost = new StreamExternalArtifactCoverage(
            address(core),
            address(executor),
            address(archiveRoles),
            address(archiveVerifier),
            IStreamGasParameterHost.GasParameterConfig(
                "EXTERNAL_ARCHIVE_READ_GAS", 300000, 150000, 2
            ),
            IStreamGasParameterHost.GasParameterConfig(
                "EXTERNAL_ARCHIVE_SIGNATURE_GAS", 400000, 90000, 2
            )
        );
        SafeComponents memory components = deploySafeComponents("1.4.1");
        archiveAgentKeys.push(0x652931);
        archiveAgentKeys.push(0x652932);
        archiveFixityKeys.push(0x652933);
        archiveFixityKeys.push(0x652934);
        archiveAgentSafe =
            createOfficialSafe(components, safeOwnerAddresses(archiveAgentKeys), 2, 131);
        archiveFixitySafe =
            createOfficialSafe(components, safeOwnerAddresses(archiveFixityKeys), 2, 132);
        _extRole(address(archiveFixitySafe), true);
        archiveFirstFamily = _extAdmit(
            "arweave-object", _extFamily("arweave-object", true, address(archiveAgentSafe))
        );
        archiveSecondFamily = _extAdmit(
            "institution-object", _extFamily("institution-object", false, safeVm.addr(SECOND_AGENT))
        );
        _registerReferenceDefinitions();
        StreamSnapshotTypes.NativeFacts memory native =
            StreamSnapshotSourceReads.requireCurrent(_dependencies(), 1);
        StreamReferenceRenderTypes.RendererDeclaration memory declaration =
            StreamReferenceRenderTypes.RendererDeclaration(
                native.serving.renderer,
                native.serving.rendererCodeHash,
                native.routerVersion,
                native.routerManifestHash,
                native.presentationProfile,
                native.rendererContext,
                native.dependencyProfile,
                keccak256("STATIC")
            );
        bytes memory catalog = StreamReferenceRendererCatalog.declarationJSON(declaration);
        _snapshotDocument(
            "STREAM_REFERENCE_RENDERER_CLASS_FIXTURE_V1",
            IStreamSchemaRegistry.DocumentKind.CATALOG,
            catalog
        );
        StreamReferenceRenderTypes.Dependencies memory d;
        d.targets = [
            address(core),
            address(metadata),
            address(schemas),
            address(store),
            address(router),
            address(snapshots),
            address(archiveHost)
        ];
        for (uint256 i; i < 7; ++i) {
            d.codeHashes[i] = d.targets[i].codehash;
        }
        d.chainId = block.chainid;
        d.rendererCatalogId = keccak256("STREAM_REFERENCE_RENDERER_CLASS_FIXTURE_V1");
        d.rendererCatalogHash = keccak256(catalog);
        d.rendererCatalogBytes = uint32(catalog.length);
        d.readGas = 500000;
        d.sourceGas = 4000000;
        d.snapshotGas = 6000000;
        d.archiveGas = 2000000;
        IStreamGasParameterHost.GasParameterConfig[4] memory configs;
        configs[0] = _gas("REFERENCE_READ_GAS", d.readGas, 1);
        configs[1] = _gas("REFERENCE_SOURCE_GAS", d.sourceGas, 1);
        configs[2] = _gas("REFERENCE_SNAPSHOT_GAS", d.snapshotGas, 1);
        configs[3] = _gas("REFERENCE_ARCHIVE_GAS", d.archiveGas, 1);
        referenceHost = new StreamReferenceRenderPublication(d, address(executor), configs);
        _curator(address(this), 3, true);
        _terms();
    }

    function _registerReferenceDefinitions() private {
        string[8] memory names = [
            "STREAM_NATIVE_REFERENCE_RENDER_V1",
            "STREAM_NATIVE_REFERENCE_RENDER_JSON_PROFILE_V1",
            "STREAM_REFERENCE_NATIVE_ENVIRONMENT_V1",
            "STREAM_REFERENCE_PNG_OBJECT_V1",
            "STREAM_REFERENCE_RUNTIME_ZIP_OBJECT_V1",
            "STREAM_REFERENCE_NATIVE_FORMATS_V1",
            "STREAM_RENDERER_CLASS_DECLARATION_V1",
            "STREAM_RENDERER_CLASS_DECLARATION_JSON_PROFILE_V1"
        ];
        for (uint256 i; i < 8; ++i) {
            _snapshotDocument(
                names[i],
                (i == 1 || i == 5 || i == 7)
                    ? IStreamSchemaRegistry.DocumentKind.CATALOG
                    : IStreamSchemaRegistry.DocumentKind.SCHEMA,
                bytes(vm.readFile(string.concat("schemas/records/", names[i], ".json")))
            );
        }
    }

    function _curator(address actor, uint8 cls, bool enabled) private {
        uint256 cid = cls == 8 ? 0 : 1;
        (bytes32 s, bytes32 o, bytes32 n) =
            metadata.familyWriterTransition(cid, StreamRecordFamilies.CURATOR, cls, actor, enabled);
        executor.execute(
            address(metadata),
            abi.encodeCall(
                metadata.setFamilyWriter, (cid, StreamRecordFamilies.CURATOR, cls, actor, enabled)
            ),
            s,
            o,
            n
        );
    }

    function _loadObject(string memory json, string memory prefix, bool runtime)
        private
        returns (bytes32 hash, bytes32 coverageHash)
    {
        archiveObject = E.ObjectIdentity(
            keccak256("artist"),
            runtime
                ? StreamReferenceRenderDefinitions.ZIP_SCHEMA_ID
                : StreamReferenceRenderDefinitions.PNG_SCHEMA_ID,
            keccak256("RAW_BYTES"),
            bytes32(safeVm.parseJsonBytes(json, string.concat(prefix, ".contentHash"))),
            bytes32(safeVm.parseJsonBytes(json, string.concat(prefix, ".sha256Digest"))),
            bytes32(safeVm.parseJsonBytes(json, string.concat(prefix, ".arweaveDataRoot"))),
            uint64(fixtureVm.parseJsonUint(json, string.concat(prefix, ".byteSize"))),
            runtime ? keccak256("IANA:application/zip") : keccak256("IANA:image/png"),
            StreamReferenceRenderDefinitions.FORMAT_CATALOG_ID,
            StreamReferenceRenderDefinitions.FORMAT_CATALOG_HASH
        );
        archiveFirstPath = safeVm.parseJsonBytes(json, string.concat(prefix, ".firstDataPath"));
        archiveLastPath = safeVm.parseJsonBytes(json, string.concat(prefix, ".lastDataPath"));
        hash = archiveHost.recordObject(archiveObject);
        archiveObjectHash = hash;
        A.Checkpoint memory cp = _extCheckpointTerms();
        cp.transactionId = keccak256(abi.encode("actual reference object", hash));
        archiveTransactionId = cp.transactionId;
        archiveCheckpointHash = archiveVerifier.recordCheckpoint(
            cp,
            abi.encode(cp.dataRoot, uint256(cp.dataSize)),
            archiveFirstPath,
            archiveLastPath,
            _extCertificate(cp)
        );
        bytes32 a = _extRecordReceipt(true, uint256(hash));
        bytes32 b = _extRecordReceipt(false, uint256(hash));
        _extRecordFixity(a, 1, false);
        _extRecordFixity(b, 1, false);
        coverageHash = archiveHost.recordCoverage(a, b);
    }

    function _terms() private {
        string memory json =
            vm.readFile("test/fixtures/preservation/reference-actual-native-v1.json");
        StreamReferenceRenderTypes.Environment memory env;
        (env.objectHash, env.coverageHash) = _loadObject(
            vm.readFile("test/fixtures/preservation/reference-browser-object-v1.json"), "", true
        );
        E.Coverage memory cover = archiveHost.coverage(env.coverageHash);
        originalFirstReceipts[0] = cover.firstReceiptHash;
        originalSecondReceipts[0] = cover.secondReceiptHash;
        env.engineName = "Google Chrome";
        env.engineVersion = "152.0.7977.83";
        env.engineExecutableSha256 = bytes32(safeVm.parseJsonBytes(json, ".engineExecutableSha256"));
        env.engineExecutablePath = "engine/chrome.exe";
        env.toolchainName = "reference_capture.py; Python; websockets";
        env.toolchainVersion = "STREAM_REFERENCE_CANVAS_STILL_WINDOWS_V1; 3.12.10; 15.0.1";
        env.toolchainSha256 = bytes32(safeVm.parseJsonBytes(json, ".toolchainSha256"));
        env.toolchainPath = "tool/reference_capture.py";
        env.packageFiles = abi.decode(
            safeVm.parseJsonBytes(json, ".packageFilesABI"),
            (StreamReferenceRenderTypes.PackageFile[])
        );
        env.platformPrerequisites = abi.decode(
            safeVm.parseJsonBytes(json, ".platformPrerequisitesABI"),
            (StreamReferenceRenderTypes.PackageFile[])
        );
        env.operatingSystem = "Windows";
        env.operatingSystemVersion = fixtureVm.parseJsonString(json, ".operatingSystemVersion");
        env.architecture = "AMD64";
        env.viewportWidth = 64;
        env.viewportHeight = 64;
        env.devicePixelRatio = 1;
        env.colorSpace = "srgb";
        env.softwareRasterization = true;
        env.captureProfile = keccak256("STREAM_REFERENCE_CANVAS_STILL_WINDOWS_V1");
        env.licenseNote = fixtureVm.parseJsonString(json, ".licenseNote");
        bytes memory environment = StreamReferenceEnvironmentJson.manifest(env);
        env.manifestHash = keccak256(environment);
        env.manifestBytes = uint32(environment.length);
        StreamReferenceRenderTypes.Publication memory p;
        p.collectionId = 1;
        p.referenceId = keccak256("actual first and last native reference");
        (p.snapshotRecordHash,) = _publish(address(this));
        p.snapshotRevision = 1;
        p.environment = env;
        p.reasonHash = keccak256("actual source export and repeated capture");
        p.effectiveAt = 1000;
        p.manifestURI = "ipfs://local-fixture-reference-manifest";
        p.captures = new StreamReferenceRenderTypes.Capture[](2);
        for (uint256 i; i < 2; ++i) {
            string memory prefix = i == 0 ? ".capture1" : ".capture2";
            StreamReferenceRenderTypes.Capture memory c;
            c.tokenId = i + 1;
            c.collectionSerial = i + 1;
            c.animationHTML = safeVm.parseJsonBytes(json, string.concat(prefix, ".html"));
            c.htmlHash = keccak256(c.animationHTML);
            c.htmlBytes = uint32(c.animationHTML.length);
            c.sourceSha256 = sha256(c.animationHTML);
            c.metadataJSONHash =
                keccak256(bytes(router.historicalTokenMetadataJSON(address(core), i + 1)));
            (c.objectHash, c.coverageHash) = _loadObject(json, prefix, false);
            cover = archiveHost.coverage(c.coverageHash);
            originalFirstReceipts[i + 1] = cover.firstReceiptHash;
            originalSecondReceipts[i + 1] = cover.secondReceiptHash;
            c.repeatCaptureSha256 = [cover.sha256Digest, cover.sha256Digest];
            c.environmentManifestHash = env.manifestHash;
            c.capturedAt = 1000;
            p.captures[i] = c;
        }
        bytes memory packageJSON =
            bytes(StreamReferenceEnvironmentJson.files(env.packageFiles, true));
        bytes memory platformJSON =
            bytes(StreamReferenceEnvironmentJson.files(env.platformPrerequisites, false));
        _upload(packageJSON);
        _upload(platformJSON);
        referenceHost.prepareFileInventory(env.packageFiles, true);
        referenceHost.prepareFileInventory(env.platformPrerequisites, false);
        terms = p;
    }

    function _referencePublish(address actor) private returns (bytes32 hash) {
        StreamReferenceRenderTypes.Publication memory p = terms;
        (p.expectedSourcesHash,) = referenceHost.previewReference(p, actor);
        (, bytes memory raw) = referenceHost.previewReference(p, actor);
        _upload(raw);
        _upload(abi.encode(p));
        bytes memory input = abi.encodeCall(referenceHost.publishReference, (p));
        vm.prank(actor);
        uint256 before = gasleft();
        (bool ok, bytes memory result) = address(referenceHost).call{ gas: 16000000 }(input);
        uint256 used = before - gasleft();
        if (!ok) assembly ("memory-safe") { revert(add(result, 32), mload(result)) }
        hash = abi.decode(result, (bytes32));
        emit log_named_uint("referencePublishCalleeGas", used);
    }

    function testActualSourceAndFullBrowserArchiveReferencePublication() public {
        bytes32 hash = _referencePublish(address(this));
        StreamReferenceRenderTypes.Receipt memory receipt = referenceHost.requireCurrent(1, hash, 1);
        require(
            receipt.recordHash == hash && receipt.recorder == address(this)
                && receipt.authorizationClass == 3 && receipt.grantRevision != 0
        );
        bytes memory raw = referenceHost.referencePayload(hash);
        require(keccak256(raw) == receipt.payloadHash);
        cheat.createDir("reference-publication", true);
        cheat.writeFile("reference-publication/manifest.json", string(raw));
        emit log_named_uint("referenceCanonicalBytes", raw.length);
    }

    function testMalformedOriginalPublicationOffsetsLengthsAndExactRetry() public {
        StreamReferenceRenderTypes.Publication memory p = terms;
        bytes memory canonical;
        (p.expectedSourcesHash, canonical) = referenceHost.previewReference(p, address(this));
        _upload(canonical);
        _upload(abi.encode(p));
        bytes memory input = abi.encodeCall(referenceHost.publishReference, (p));
        for (uint256 mode; mode < 4; ++mode) {
            bytes memory bad = bytes.concat(input);
            assembly ("memory-safe") {
                // ABI data starts at +32; selector +4; sole dynamic tuple begins at +36.
                switch mode
                case 0 { mstore(add(bad, 36), not(0)) }
                case 1 { mstore(add(bad, 292), not(0)) }
                case 2 {
                    let captures := add(add(bad, 68), mload(add(bad, 292)))
                    mstore(captures, not(0))
                }
                default { mstore(bad, 4) }
            }
            (bool ok,) = address(referenceHost).call(bad);
            require(!ok && referenceHost.currentReference(1).recordHash == 0);
        }
        bytes32 hash = referenceHost.publishReference(p);
        require(referenceHost.requireCurrent(1, hash, 1).payloadHash == keccak256(canonical));
    }

    function _lockReference() private {
        (bytes32 scope, bytes32 oldHash, bytes32 newHash) = referenceHost.lockTransition(1);
        cheat.mockCall(
            address(executor),
            abi.encodeCall(IStreamGovernedParameterAuthority.currentAction, ()),
            abi.encode(
                true, keccak256("reference terminal action"), uint8(2), scope, oldHash, newHash
            )
        );
        vm.prank(address(executor));
        referenceHost.lockReference(1);
    }

    function testOriginalRecordFlatPreimageAndExactRetainedABI() public {
        bytes32 hash = _referencePublish(address(this));
        (
            StreamReferenceRenderTypes.Publication memory p,
            StreamReferenceRenderTypes.Receipt memory r
        ) = referenceHost.referenceRecord(hash);
        StreamReferenceRenderTypes.Dependencies memory d = referenceHost.dependencies();
        StreamReferenceRenderTypes.SourceFacts memory f =
            StreamReferenceRenderSourceReads.requireSources(d, p, false);
        bytes memory priorCanonical = ReferencePriorManifestJson.assemble(
            d, p, r, f, StreamReferenceEnvironmentJson.manifest(p.environment)
        );
        bytes memory actualCanonical = referenceHost.referencePayload(hash);
        require(
            priorCanonical.length == actualCanonical.length
                && keccak256(priorCanonical) == keccak256(actualCanonical)
        );
        require(
            p.expectedSourcesHash == r.sourcesHash
                && keccak256(abi.encode(p.environment)) == keccak256(abi.encode(terms.environment))
        );
        bytes32 chain = r.recordChainHash;
        r.recordHash = 0;
        r.recordChainHash = 0;
        require(
            hash
                == keccak256(
                    abi.encode(
                        keccak256("6529STREAM_NATIVE_REFERENCE_RECORD_V1"),
                        block.chainid,
                        address(referenceHost),
                        address(core),
                        address(metadata),
                        p,
                        r
                    )
                )
        );
        require(
            chain
                == keccak256(
                    abi.encode(
                        keccak256("6529STREAM_NATIVE_REFERENCE_CHAIN_V1"),
                        block.chainid,
                        address(referenceHost),
                        address(core),
                        uint256(1),
                        bytes32(0),
                        uint64(1),
                        hash
                    )
                )
        );
        (bool ok, bytes memory raw) =
            address(referenceHost).staticcall(abi.encodeCall(referenceHost.referenceRecord, (hash)));
        r.recordHash = hash;
        r.recordChainHash = chain;
        require(ok && keccak256(raw) == keccak256(abi.encode(p, r)));
    }

    function testOriginalCuratorRevocationAndGlobalSafePublication() public {
        uint256[] memory keys = new uint256[](2);
        keys[0] = 4411;
        keys[1] = 4412;
        OfficialSafe safe =
            createOfficialSafe(deploySafeComponents("1.4.1"), safeOwnerAddresses(keys), 2, 4413);
        _curator(address(safe), 8, true);
        StreamReferenceRenderTypes.Publication memory p = terms;
        bytes memory raw;
        (p.expectedSourcesHash,) = referenceHost.previewReference(p, address(safe));
        (, raw) = referenceHost.previewReference(p, address(safe));
        _upload(raw);
        _upload(abi.encode(p));
        require(
            executeSafe(
                safe,
                keys,
                address(referenceHost),
                0,
                abi.encodeCall(referenceHost.publishReference, (p)),
                0
            )
        );
        StreamReferenceRenderTypes.Receipt memory r = referenceHost.currentReference(1);
        require(r.recorder == address(safe) && r.authorizationClass == 8 && r.grantRevision != 0);
        _curator(address(safe), 8, false);
        require(
            executeSafe(
                safe,
                keys,
                address(referenceHost),
                0,
                abi.encodeCall(referenceHost.requireCurrent, (1, r.recordHash, r.revision)),
                0
            )
        );
        p.expectedHead = r.recordHash;
        p.expectedRevision = 1;
        p.referenceId = keccak256("next Safe reference");
        vm.expectRevert();
        referenceHost.previewReference(p, address(safe));
    }

    function testExactSafeTransactionIntrinsicFloorAndColdEnvelope() public {
        uint256[] memory keys = new uint256[](2);
        keys[0] = 4421;
        keys[1] = 4422;
        OfficialSafe safe =
            createOfficialSafe(deploySafeComponents("1.4.1"), safeOwnerAddresses(keys), 2, 4423);
        _curator(address(safe), 8, true);
        StreamReferenceRenderTypes.Publication memory p = terms;
        bytes memory raw;
        (p.expectedSourcesHash, raw) = referenceHost.previewReference(p, address(safe));
        _upload(raw);
        _upload(abi.encode(p));
        bytes memory publication = abi.encodeCall(referenceHost.publishReference, (p));
        bytes32 digest = safe.getTransactionHash(
            address(referenceHost), 0, publication, 0, 0, 0, 0, address(0), address(0), safe.nonce()
        );
        bytes memory transaction = abi.encodeCall(
            safe.execTransaction,
            (
                address(referenceHost),
                0,
                publication,
                0,
                0,
                0,
                0,
                address(0),
                payable(address(0)),
                safeThresholdSignature(keys, digest)
            )
        );
        uint256 zero;
        for (uint256 i; i < transaction.length; ++i) {
            if (transaction[i] == 0) ++zero;
        }
        uint256 tokens = zero + 4 * (transaction.length - zero);
        // Non-creation transaction: EIP-7623 intrinsic and minimum calldata floor.
        uint256 intrinsic = 21000 + 4 * tokens;
        uint256 floor = 21000 + 10 * tokens;
        uint256 maximum = 16777216; // EIP-7825, independently of the block gas limit.
        require(floor <= maximum && intrinsic < maximum);
        uint256 available = maximum - intrinsic;
        ReferenceSafeEnvelopeProbe probe = new ReferenceSafeEnvelopeProbe();
        vm.expectRevert();
        probe.execute(address(safe), transaction, 1000000);
        require(safe.nonce() == 0 && referenceHost.referenceCount(1) == 0);
        uint256 used = probe.execute(address(safe), transaction, available);
        StreamReferenceRenderTypes.Receipt memory r = referenceHost.currentReference(1);
        require(
            r.recordHash != 0 && r.recorder == address(safe) && r.authorizationClass == 8
                && r.grantRevision != 0 && safe.nonce() == 1
        );
        uint256 envelope = intrinsic + used;
        if (envelope < floor) envelope = floor;
        require(envelope <= maximum);
        cheat.createDir("reference-safe-envelope", true);
        cheat.writeFile("reference-safe-envelope/calldata.hex", fixtureVm.toString(transaction));
        emit log_named_uint("referenceSafeTransactionBytes", transaction.length);
        emit log_named_uint("referenceSafeTransactionZeroBytes", zero);
        emit log_named_uint("referenceSafeTransactionIntrinsic", intrinsic);
        emit log_named_uint("referenceSafeTransactionFloor", floor);
        emit log_named_uint("referenceSafeExecutionBudget", available);
        emit log_named_uint("referenceSafeExecutionGasIncludingColdCall", used);
        emit log_named_uint("referenceSafeWholeTransactionEnvelope", envelope);
    }

    function testMissingBytesRollbackAndExactRetry() public {
        StreamReferenceRenderTypes.Publication memory p = terms;
        bytes memory raw;
        (p.expectedSourcesHash,) = referenceHost.previewReference(p, address(this));
        (, raw) = referenceHost.previewReference(p, address(this));
        _upload(raw);
        vm.expectRevert();
        referenceHost.publishReference(p);
        require(
            referenceHost.referenceCount(1) == 0
                && referenceHost.currentReference(1).recordHash == 0
        );
        _upload(abi.encode(p));
        referenceHost.publishReference(p);
        require(referenceHost.referenceCount(1) == 1);
    }

    function testTwoOriginalRevisionsAndCASUniqueId() public {
        bytes32 firstHash = _referencePublish(address(this));
        bytes memory original = referenceHost.referencePayload(firstHash);
        vm.expectRevert();
        referenceHost.previewReference(terms, address(this));
        StreamReferenceRenderTypes.Publication memory p = terms;
        p.expectedHead = firstHash;
        p.expectedRevision = 1;
        vm.expectRevert();
        referenceHost.previewReference(p, address(this));
        p.referenceId = keccak256("second original reference");
        terms = p;
        bytes32 secondHash = _referencePublish(address(this));
        require(referenceHost.requireCurrent(1, secondHash, 2).predecessor == firstHash);
        vm.expectRevert();
        referenceHost.requireCurrent(1, firstHash, 1);
        require(keccak256(referenceHost.referencePayload(firstHash)) == keccak256(original));
    }

    function testLockedComponentStableAcrossOriginalReceiptRefreshFailureAndRepair() public {
        bytes32 hash = _referencePublish(address(this));
        vm.expectRevert();
        referenceHost.finalityState(1);
        _lockReference();
        StreamFinalityComponentState memory original = referenceHost.finalityState(1);
        require(
            original.frozen
                && original.componentType == StreamFinalityDomains.COMPONENT_REFERENCE_RENDER
        );
        _extRecordFixity(originalFirstReceipts[0], 1, false);
        require(referenceHost.finalityState(1).dataHash == original.dataHash);
        _extRecordFixity(originalFirstReceipts[0], 2, false);
        vm.expectRevert();
        referenceHost.requireCurrent(1, hash, 1);
        _extRecordFixity(originalFirstReceipts[0], 1, true);
        require(referenceHost.finalityState(1).dataHash == original.dataHash);
        StreamReferenceRenderTypes.Publication memory p = terms;
        p.referenceId = keccak256("locked successor");
        p.expectedHead = hash;
        p.expectedRevision = 1;
        vm.expectRevert();
        referenceHost.previewReference(p, address(this));
        require(
            keccak256(abi.encode(referenceHost.finalityStateForScope(_scope())))
                == keccak256(abi.encode(original))
        );
        StreamFinalityScope memory bad = _scope();
        bad.tokenId = 1;
        vm.expectRevert();
        referenceHost.finalityStateForScope(bad);
    }

    function testTerminalLockRequiresExactContextAndRuntime() public {
        _referencePublish(address(this));
        (bytes32 scope, bytes32 oldHash, bytes32 newHash) = referenceHost.lockTransition(1);
        vm.expectRevert();
        referenceHost.lockReference(1);
        for (uint256 i; i < 4; ++i) {
            cheat.mockCall(
                address(executor),
                abi.encodeCall(IStreamGovernedParameterAuthority.currentAction, ()),
                abi.encode(
                    true,
                    keccak256("wrong context"),
                    uint8(i == 0 ? 1 : 2),
                    i == 1 ? bytes32(0) : scope,
                    i == 2 ? bytes32(0) : oldHash,
                    i == 3 ? bytes32(0) : newHash
                )
            );
            vm.prank(address(executor));
            vm.expectRevert();
            referenceHost.lockReference(1);
        }
        bytes memory original = address(executor).code;
        vm.etch(address(executor), hex"00");
        vm.prank(address(executor));
        vm.expectRevert();
        referenceHost.lockReference(1);
        vm.etch(address(executor), original);
        _lockReference();
        require(referenceHost.referenceLock(1).actionId != 0);
    }

    function testWrongSourceOrderHTMLRepeatAndArchiveObjectRejected() public {
        StreamReferenceRenderTypes.Publication memory p = terms;
        p.captures[0].tokenId = 2;
        vm.expectRevert();
        referenceHost.previewReference(p, address(this));
        p = terms;
        p.captures[0].animationHTML[0] ^= 0x01;
        p.captures[0].htmlHash = keccak256(p.captures[0].animationHTML);
        p.captures[0].sourceSha256 = sha256(p.captures[0].animationHTML);
        vm.expectRevert();
        referenceHost.previewReference(p, address(this));
        p = terms;
        p.captures[0].repeatCaptureSha256[1] ^= bytes32(uint256(1));
        vm.expectRevert();
        referenceHost.previewReference(p, address(this));
        p = terms;
        p.captures[0].objectHash = p.environment.objectHash;
        p.captures[0].coverageHash = p.environment.coverageHash;
        vm.expectRevert();
        referenceHost.previewReference(p, address(this));
    }

    function testBurnedEndpointsRemainHistoricalAndUnresolvedEntropyRejects() public {
        core.setToken(1, address(0), 3);
        core.setToken(2, address(0), 3);
        (bytes32 source,) = referenceHost.previewReference(terms, address(this));
        require(source != 0);
        cheat.mockCall(
            address(first),
            abi.encodeCall(IStreamEntropyView.tokenSeed, (uint256(1))),
            abi.encode(bytes32(0), false)
        );
        vm.expectRevert();
        referenceHost.previewReference(terms, address(this));
    }

    function testRetiredRendererDefinitionAndGraphDriftCannotRemainCurrent() public {
        bytes32 hash = _referencePublish(address(this));
        bytes memory code = address(archiveHost).code;
        vm.etch(address(archiveHost), hex"00");
        vm.expectRevert();
        referenceHost.requireCurrent(1, hash, 1);
        vm.etch(address(archiveHost), code);
        bytes32 id = StreamReferenceRenderDefinitions.RENDERER_SCHEMA_ID;
        (bytes32 s, bytes32 o, bytes32 n) =
            schemas.statusTransition(id, IStreamSchemaRegistry.DocumentStatus.DEPRECATED);
        executor.execute(
            address(schemas),
            abi.encodeCall(
                schemas.setDocumentStatus, (id, IStreamSchemaRegistry.DocumentStatus.DEPRECATED)
            ),
            s,
            o,
            n
        );
        vm.expectRevert();
        referenceHost.requireCurrent(1, hash, 1);
        require(referenceHost.referencePayload(hash).length != 0);
    }

    function testFuzzZeroOrFutureEffectiveDateRejected(uint64 offset) public {
        StreamReferenceRenderTypes.Publication memory p = terms;
        p.effectiveAt = 0;
        vm.expectRevert();
        referenceHost.previewReference(p, address(this));
        p.effectiveAt = uint64(block.timestamp) + uint64(offset % 1000000) + 1;
        vm.expectRevert();
        referenceHost.previewReference(p, address(this));
        require(referenceHost.referenceCount(1) == 0);
    }

    function testFuzzCatalogCannotSelectAnAlternateHash(bytes32 different) public {
        StreamReferenceRenderTypes.Dependencies memory d = referenceHost.dependencies();
        if (different == d.rendererCatalogHash) return;
        d.rendererCatalogHash = different;
        vm.expectRevert();
        StreamReferenceRenderSourceReads.requireSources(d, terms, false);
    }

    function _referenceConsumer() private returns (ReferenceFixedConsumer) {
        StreamFinalityReferenceReads.Dependencies memory d;
        d.core = address(core);
        d.metadata = address(metadata);
        d.referencePublisher = address(referenceHost);
        d.metadataRouter = address(router);
        d.snapshots = address(snapshots);
        d.coreCodeHash = address(core).codehash;
        d.metadataCodeHash = address(metadata).codehash;
        d.referenceCodeHash = address(referenceHost).codehash;
        d.routerCodeHash = address(router).codehash;
        d.snapshotsCodeHash = address(snapshots).codehash;
        d.chainId = block.chainid;
        d.readGas = 500000;
        d.validationGas = 10000000;
        return new ReferenceFixedConsumer(d);
    }

    function testFixedConsumerCurrentLockAndSafeCall() public {
        bytes32 hash = _referencePublish(address(this));
        ReferenceFixedConsumer consumer = _referenceConsumer();
        StreamFinalityReferenceEvidence memory e = consumer.read(_scope(), hash, 1, false);
        require(e.inputHash != 0 && !e.locked && e.recordHash == hash && e.componentDataHash == 0);
        vm.expectRevert();
        consumer.read(_scope(), hash, 1, true);
        _lockReference();
        e = consumer.read(_scope(), hash, 1, true);
        require(e.locked && e.componentDataHash == referenceHost.finalityState(1).dataHash);
        _extRecordFixity(originalSecondReceipts[1], 1, false);
        require(consumer.read(_scope(), hash, 1, true).inputHash == e.inputHash);
        require(
            executeSafe(
                archiveAgentSafe,
                archiveAgentKeys,
                address(consumer),
                0,
                abi.encodeCall(consumer.read, (_scope(), hash, uint64(1), true)),
                0
            )
        );
    }

    function testFixedConsumerRejectsMalformedReceiptLockAndWrongGraph() public {
        bytes32 hash = _referencePublish(address(this));
        ReferenceFixedConsumer consumer = _referenceConsumer();
        StreamReferenceRenderTypes.Receipt memory r = referenceHost.currentReference(1);
        r.authorizationClass = 7;
        cheat.mockCall(
            address(referenceHost),
            abi.encodeCall(referenceHost.requireCurrent, (uint256(1), hash, uint64(1))),
            abi.encode(r)
        );
        vm.expectRevert();
        consumer.read(_scope(), hash, 1, false);
        r.authorizationClass = 3;
        cheat.mockCall(
            address(referenceHost),
            abi.encodeCall(referenceHost.requireCurrent, (uint256(1), hash, uint64(1))),
            abi.encode(r)
        );
        cheat.mockCall(
            address(referenceHost),
            abi.encodeCall(referenceHost.referenceLock, (uint256(1))),
            abi.encode(hash, uint64(1), bytes32(0), uint64(0))
        );
        vm.expectRevert();
        consumer.read(_scope(), hash, 1, false);
        cheat.mockCall(
            address(referenceHost),
            abi.encodeCall(referenceHost.referenceLock, (uint256(1))),
            abi.encode(bytes32(0), uint64(0), bytes32(0), uint64(0))
        );
        cheat.mockCall(
            address(referenceHost),
            abi.encodeCall(referenceHost.metadataRouter, ()),
            abi.encode(address(0x1234))
        );
        vm.expectRevert();
        consumer.read(_scope(), hash, 1, false);
    }

    function testPreparedInventoriesPermissionlessBoundedAndExact() public {
        StreamReferenceRenderTypes.Dependencies memory d = referenceHost.dependencies();
        IStreamGasParameterHost.GasParameterConfig[4] memory configs;
        configs[0] = _gas("REFERENCE_READ_GAS", d.readGas, 1);
        configs[1] = _gas("REFERENCE_SOURCE_GAS", d.sourceGas, 1);
        configs[2] = _gas("REFERENCE_SNAPSHOT_GAS", d.snapshotGas, 1);
        configs[3] = _gas("REFERENCE_ARCHIVE_GAS", d.archiveGas, 1);
        StreamReferenceRenderPublication fresh =
            new StreamReferenceRenderPublication(d, address(executor), configs);
        StreamReferenceRenderTypes.Environment memory e = terms.environment;
        bytes memory input = abi.encodeCall(fresh.prepareFileInventory, (e.packageFiles, true));
        uint256 before = gasleft();
        vm.prank(address(0xCAFE));
        (bool ok, bytes memory result) = address(fresh).call{ gas: 16000000 }(input);
        uint256 used = before - gasleft();
        require(ok, "complete package preparation16M");
        bytes32 id = abi.decode(result, (bytes32));
        require(
            keccak256(fresh.preparedFileInventory(id))
                == keccak256(bytes(StreamReferenceEnvironmentJson.files(e.packageFiles, true)))
        );
        require(
            fresh.prepareFileInventory(e.packageFiles, true) == id && fresh.referenceCount(1) == 0
        );
        emit log_named_uint("referencePackagePreparationCalleeGas", used);
        StreamReferenceRenderTypes.Publication memory p = terms;
        vm.expectRevert();
        fresh.previewReference(p, address(0xCAFE));
        p.environment.packageFiles[0].sha256Digest ^= bytes32(uint256(1));
        vm.expectRevert();
        referenceHost.previewReference(p, address(this));
    }

    function testPreparedFullPublicationAndNamedColdConsumerCapacity() public {
        bytes32 hash = _referencePublish(address(this));
        ReferenceFixedConsumer consumer = _referenceConsumer();
        bytes memory input = abi.encodeCall(consumer.read, (_scope(), hash, uint64(1), false));
        address[15] memory targets = [
            address(core),
            address(metadata),
            address(schemas),
            address(store),
            address(router),
            address(snapshots),
            address(archiveHost),
            address(checkpoint),
            address(leaves),
            address(inventory),
            address(membership),
            address(coordinators),
            address(first),
            address(second),
            address(artist)
        ];
        for (uint256 i; i < targets.length; ++i) {
            safeVm.cool(targets[i]);
        }
        safeVm.cool(address(StreamFinalityReferenceReads));
        safeVm.cool(address(StreamReferenceRenderSourceReads));
        safeVm.cool(address(referenceHost));
        uint256 before = gasleft();
        (bool ok, bytes memory raw) = address(consumer).staticcall{ gas: 16000000 }(input);
        uint256 used = before - gasleft();
        require(ok, "named cold complete reference consumer16M");
        StreamFinalityReferenceEvidence memory e =
            abi.decode(raw, (StreamFinalityReferenceEvidence));
        require(
            keccak256(raw) == keccak256(abi.encode(e)) && e.recordHash == hash && e.inputHash != 0
                && !e.locked
        );
        emit log_named_uint("referenceNamed18ColdConsumerGas", used);
        emit log_named_uint("referenceConsumerReturnBytes", raw.length);
    }

    function _extSign(uint256 key, bytes32 digest) private returns (bytes memory) {
        (uint8 v, bytes32 r, bytes32 s) = safeVm.sign(key, digest);
        return abi.encodePacked(r, s, v);
    }

    function _extCheckpointTerms() private view returns (A.Checkpoint memory c) {
        c.networkId = archiveVerifier.networkId();
        c.configurationHash = archiveVerifier.configurationHash();
        c.blockHash = new bytes(48);
        c.blockHash[0] = 0x65;
        c.blockHeight = 1;
        c.transactionId =
            keccak256("explicit local quorum network fixture for complete browser object");
        c.dataRoot = archiveObject.arweaveDataRoot;
        c.dataSize = archiveObject.byteSize;
        c.transactionRoot = sha256(
            abi.encodePacked(
                sha256(abi.encodePacked(c.dataRoot)), sha256(abi.encode(uint256(c.dataSize)))
            )
        );
        c.transactionEnd = c.dataSize;
        c.blockDataSize = c.dataSize;
        c.observedAt = uint64(block.timestamp);
    }

    function _extCertificate(A.Checkpoint memory c) private returns (A.ObserverProof[] memory p) {
        bytes32 digest = archiveVerifier.checkpointDigest(c);
        p = new A.ObserverProof[](2);
        p[0] = A.ObserverProof(safeVm.addr(OBSERVER_A), _extSign(OBSERVER_A, digest));
        p[1] = A.ObserverProof(safeVm.addr(OBSERVER_B), _extSign(OBSERVER_B, digest));
        if (p[0].account > p[1].account) (p[0], p[1]) = (p[1], p[0]);
    }

    function _extFamily(string memory name, bool endowed, address agent)
        private
        view
        returns (A.Family memory)
    {
        bytes memory salt = bytes(endowed ? "one" : "two");
        return A.Family(
            keccak256(bytes(name)),
            endowed ? archiveVerifier.networkId() : keccak256("INSTITUTIONAL_ARCHIVE"),
            keccak256(bytes.concat(salt, "protocol")),
            keccak256(bytes.concat(salt, "addressing")),
            keccak256(bytes.concat(salt, "custodian")),
            keccak256(bytes.concat(salt, "funding")),
            keccak256(bytes.concat(salt, "retrieval")),
            keccak256("same jurisdiction allowed"),
            endowed ? 1 : 2,
            agent,
            endowed ? archiveVerifier.profileHash() : archiveHost.POSSESSION_PROFILE()
        );
    }

    function _extAdmit(string memory name, A.Family memory f) private returns (bytes32 hash) {
        bytes32 scope;
        bytes32 oldHash;
        bytes32 newHash;
        (hash, scope, oldHash, newHash) = archiveHost.familyRegistrationContext(name, f);
        require(
            abi.decode(
                executor.execute(
                    address(archiveHost),
                    abi.encodeCall(archiveHost.admitFamily, (name, f)),
                    scope,
                    oldHash,
                    newHash
                ),
                (bytes32)
            ) == hash
        );
    }

    function _extStatus(bytes32 hash, uint8 status) private {
        (bytes32 scope, bytes32 oldHash, bytes32 newHash) =
            archiveHost.familyStatusContext(hash, status);
        executor.execute(
            address(archiveHost),
            abi.encodeCall(archiveHost.setFamilyStatus, (hash, status)),
            scope,
            oldHash,
            newHash
        );
    }

    function _extReceipt(bool first, uint256 nonce)
        private
        returns (E.Receipt memory r, bytes memory id)
    {
        id = first
            ? abi.encodePacked(archiveTransactionId)
            : bytes(
                "https://institution.example.invalid/objects/sha256/d2eabd7dffeed4f37632e9e8d5a861d7fe5df621d66e62cd43234ecb9a572417"
            );
        r = E.Receipt(
            archiveObjectHash,
            first ? archiveFirstFamily : archiveSecondFamily,
            keccak256(id),
            keccak256(bytes(first ? "CONTENT_ADDRESSED_INCLUSION" : "ATTESTED_POSSESSION")),
            first ? archiveVerifier.profileHash() : archiveHost.POSSESSION_PROFILE(),
            first ? archiveCheckpointHash : bytes32(0),
            first ? address(archiveAgentSafe) : safeVm.addr(SECOND_AGENT),
            uint64(block.timestamp),
            nonce,
            uint64(block.timestamp + 1 days)
        );
        if (!first) r.proofRecordHash = archiveHost.possessionHash(r);
    }

    function _extRecordReceipt(bool first, uint256 nonce) private returns (bytes32 hash) {
        (E.Receipt memory r, bytes memory id) = _extReceipt(first, nonce);
        bytes memory sig = first
            ? safeThresholdSignature(
                archiveAgentKeys,
                safeMessageDigest(archiveAgentSafe, abi.encodePacked(archiveHost.receiptDigest(r)))
            )
            : _extSign(SECOND_AGENT, archiveHost.receiptDigest(r));
        return archiveHost.recordReceipt(r, id, sig);
    }

    function _extFixity(bytes32 receiptHash, uint8 outcome)
        private
        view
        returns (E.Fixity memory f)
    {
        (E.Receipt memory r,,) = archiveHost.receipt(receiptHash);
        f.receiptHash = receiptHash;
        f.objectHash = r.objectHash;
        f.familyRecordHash = r.familyRecordHash;
        f.storageIdentifierHash = r.storageIdentifierHash;
        f.profileHash = archiveHost.FIXITY_PROFILE();
        E.ObjectIdentity memory originalObject = archiveHost.objectIdentity(r.objectHash);
        f.expectedSha256 = originalObject.sha256Digest;
        f.expectedKeccak256 = originalObject.contentHash;
        f.expectedArweaveRoot = originalObject.arweaveDataRoot;
        f.expectedSize = originalObject.byteSize;
        if (outcome == 1) {
            f.observedSha256 = originalObject.sha256Digest;
            f.observedKeccak256 = originalObject.contentHash;
            f.observedArweaveRoot = originalObject.arweaveDataRoot;
            f.observedSize = originalObject.byteSize;
        }
        f.checkedAt = uint64(block.timestamp);
        f.outcome = outcome;
        f.reportHash = keccak256("full locally retrieved original package fixity report fixture");
        f.previousFixityHash = archiveHost.latestFixity(receiptHash);
        f.verifier = address(archiveFixitySafe);
        f.deadline = uint64(block.timestamp + 1 days);
        f.nonce = uint256(f.previousFixityHash);
    }

    function _extRecordFixity(bytes32 receiptHash, uint8 outcome, bool repair)
        private
        returns (bytes32)
    {
        E.Fixity memory f = _extFixity(receiptHash, outcome);
        if (repair) f.repairReportHash = keccak256("repair report");
        return archiveHost.recordFixity(
            f,
            safeThresholdSignature(
                archiveFixityKeys,
                safeMessageDigest(archiveFixitySafe, abi.encodePacked(archiveHost.fixityDigest(f)))
            )
        );
    }

    function _extCovered() private returns (bytes32 first, bytes32 second, bytes32 hash) {
        first = _extRecordReceipt(true, 0);
        second = _extRecordReceipt(false, 0);
        _extRecordFixity(first, 1, false);
        _extRecordFixity(second, 1, false);
        hash = archiveHost.recordCoverage(first, second);
    }

    function _extFails(address target, bytes memory data) private {
        (bool ok,) = target.call(data);
        require(!ok, "expected rejection");
    }

    function _extRole(address holder, bool granted) private {
        bytes32 role = keccak256("ROLE_FIXITY_OPERATOR");
        (bytes32 chain, uint64 revision) = archiveRoles.roleMutationState(role);
        (bytes32 globalChain, uint64 globalRevision) = archiveRoles.globalRoleMutationState();
        bytes32 scope = keccak256(
            abi.encode(
                keccak256("6529STREAM_ROLE_MUTATION_SCOPE_V1"),
                block.chainid,
                address(archiveRoles),
                role,
                holder
            )
        );
        bytes32 nextChain = keccak256(
            abi.encode(
                keccak256("6529STREAM_ROLE_MUTATION_V1"),
                chain,
                block.chainid,
                address(archiveRoles),
                role,
                holder,
                granted,
                revision + 1
            )
        );
        bytes32 nextGlobal = keccak256(
            abi.encode(
                keccak256("6529STREAM_GLOBAL_ROLE_MUTATION_V1"),
                globalChain,
                block.chainid,
                address(archiveRoles),
                role,
                holder,
                granted,
                globalRevision + 1
            )
        );
        bytes32 oldHash = keccak256(
            abi.encode(
                keccak256("6529STREAM_ROLE_MUTATION_STATE_V1"),
                block.chainid,
                address(archiveRoles),
                scope,
                !granted,
                chain,
                revision,
                globalChain,
                globalRevision
            )
        );
        bytes32 newHash = keccak256(
            abi.encode(
                keccak256("6529STREAM_ROLE_MUTATION_STATE_V1"),
                block.chainid,
                address(archiveRoles),
                scope,
                granted,
                nextChain,
                revision + 1,
                nextGlobal,
                globalRevision + 1
            )
        );
        executor.execute(
            address(archiveRoles),
            granted
                ? abi.encodeCall(archiveRoles.grantRole, (role, holder))
                : abi.encodeCall(archiveRoles.revokeRole, (role, holder)),
            scope,
            oldHash,
            newHash
        );
    }
}
