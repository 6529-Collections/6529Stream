// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamPreservationPolicyPublicationGraphTypesV1 as CapacityReferenceGraph454
} from "../../../smart-contracts/interfaces/stream/finality/StreamPreservationPolicyPublicationGraphTypesV1.sol";
import {
    StreamPreservationPolicyPublicationReferenceDeploymentV2 as CapacityReferenceDeploy454
} from "../../../smart-contracts/domains/finality/StreamPreservationPolicyPublicationReferenceDeploymentV2.sol";
import {
    LeafManifestVm as CapacityReferenceCreateVm454
} from "../../helpers/scoped-preservation-boundaries/StreamContentLeafManifestVm.sol";
import {
    IStreamGasParameterHost as CapacityReferenceGas454
} from "../../../smart-contracts/interfaces/stream/parameters/IStreamGasParameterHost.sol";
import {
    StreamPreservationPolicyReferencePublicationV2 as CapacityReferenceV2
} from "../../../smart-contracts/domains/preservation/StreamPreservationPolicyReferencePublicationV2.sol";

import {
    PreservationSnapshotFixtureV1
} from "../metadata/StreamPreservationPolicySnapshotPublicationV1.t.sol";
import { OfficialSafe } from "../../helpers/OfficialSafeFixture.sol";
import { StaticRouteVm } from "../../helpers/StaticMetadataRoutingFixture.sol";
import { Vm } from "../../regression/legacy/helpers/CharacterizationTestBase.sol";
import {
    StreamPreservationPolicyReferencePublicationV1 as Ref
} from "../../../smart-contracts/domains/preservation/StreamPreservationPolicyReferencePublicationV1.sol";
import {
    StreamPreservationPolicyReferenceTypesV1 as RefT
} from "../../../smart-contracts/interfaces/stream/preservation/StreamPreservationPolicyReferenceTypesV1.sol";
import {
    IStreamPreservationPolicyReferencePublicationV1 as RefInterface
} from "../../../smart-contracts/interfaces/stream/preservation/IStreamPreservationPolicyReferencePublicationV1.sol";
import {
    IStreamPolicyReferencePublicationV2 as OldRefInterface
} from "../../../smart-contracts/interfaces/stream/preservation/IStreamPolicyReferencePublicationV2.sol";
import {
    IStreamScopedPreservationPolicyReferencePublicationV1 as ScopedRefInterface
} from "../../../smart-contracts/interfaces/stream/preservation/IStreamScopedPreservationPolicyReferencePublicationV1.sol";
import {
    StreamReferenceRenderTypes as RefR
} from "../../../smart-contracts/interfaces/stream/preservation/StreamReferenceRenderTypes.sol";
import {
    StreamPreservationPolicySnapshotTypesV1 as Snap
} from "../../../smart-contracts/interfaces/stream/metadata/StreamPreservationPolicySnapshotTypesV1.sol";
import {
    IStreamPreservationPolicySnapshotPublicationV1 as SnapshotInterface
} from "../../../smart-contracts/interfaces/stream/metadata/IStreamPreservationPolicySnapshotPublicationV1.sol";
import {
    IStreamContentRootPublication as Root
} from "../../../smart-contracts/interfaces/stream/metadata/IStreamContentRootPublication.sol";
import {
    IStreamPreservationPolicyContentRootPublicationV1 as RootProfile
} from "../../../smart-contracts/interfaces/stream/metadata/IStreamPreservationPolicyContentRootPublicationV1.sol";
import {
    IStreamPreservationPolicyContentCheckpointV1 as Content
} from "../../../smart-contracts/interfaces/stream/finality/IStreamPreservationPolicyContentCheckpointV1.sol";
import {
    StreamPreservationPolicyOutputTypesV1 as P
} from "../../../smart-contracts/interfaces/stream/finality/StreamPreservationPolicyOutputTypesV1.sol";
import {
    StreamPreservationPolicyReferenceDefinitionsV1 as RefDocuments
} from "../../../smart-contracts/domains/records/StreamPreservationPolicyReferenceDefinitionsV1.sol";
import {
    StreamReferenceRenderDefinitions as OriginalDefinitions
} from "../../../smart-contracts/domains/records/StreamReferenceRenderDefinitions.sol";
import {
    StreamReferenceEnvironmentJson
} from "../../../smart-contracts/domains/records/StreamReferenceEnvironmentJson.sol";
import {
    StreamFinalityPreservationPolicyReferenceReadsV1 as ReferenceReads
} from "../../../smart-contracts/domains/finality/StreamFinalityPreservationPolicyReferenceReadsV1.sol";
import {
    StreamFinalityPreservationPolicySnapshotReadsV1 as SnapshotReads
} from "../../../smart-contracts/domains/finality/StreamFinalityPreservationPolicySnapshotReadsV1.sol";
import {
    StreamPreservationPolicyReferenceSampleReadsV1 as Samples
} from "../../../smart-contracts/domains/preservation/StreamPreservationPolicyReferenceSampleReadsV1.sol";
import {
    StreamPreservationPolicyReferenceInventoryReadsV1 as ReferenceInventory
} from "../../../smart-contracts/domains/preservation/StreamPreservationPolicyReferenceInventoryReadsV1.sol";
import {
    StreamPreservationPolicyRenderCriticalTypesV1 as InventoryContext
} from "../../../smart-contracts/interfaces/stream/preservation/StreamPreservationPolicyRenderCriticalTypesV1.sol";
import {
    StreamRenderCriticalSourceTypes as InventorySources
} from "../../../smart-contracts/interfaces/stream/preservation/StreamRenderCriticalSourceTypes.sol";
import {
    StreamPreservationInventoryTypes as Inventory
} from "../../../smart-contracts/interfaces/stream/preservation/StreamPreservationInventoryTypes.sol";
import {
    StreamExternalArtifactTypes as External
} from "../../../smart-contracts/interfaces/stream/preservation/StreamExternalArtifactTypes.sol";
import {
    IStreamExternalArtifactCoverage as ExternalArchive
} from "../../../smart-contracts/interfaces/stream/preservation/IStreamExternalArtifactCoverage.sol";
import {
    IStreamExternalArtifactCurrentPair
} from "../../../smart-contracts/interfaces/stream/preservation/IStreamExternalArtifactCurrentPair.sol";
import {
    IStreamSchemaRegistry as Schema
} from "../../../smart-contracts/interfaces/stream/metadata/IStreamSchemaRegistry.sol";
import {
    IStreamGasParameterHost as Gas
} from "../../../smart-contracts/interfaces/stream/parameters/IStreamGasParameterHost.sol";
import {
    StreamRecordFamilies as Families
} from "../../../smart-contracts/domains/records/StreamRecordFamilies.sol";
import {
    StreamFinalityScope,
    StreamFinalityScopeType
} from "../../../smart-contracts/interfaces/stream/finality/StreamArtworkFinalityTypes.sol";

/// @dev Typed PNG/ZIP object/current-pair boundary; no fresh browser or complete archive claim.
contract CollectionPreservationReferenceExternalBoundary {
    address public immutable core;

    constructor(address c) {
        core = c;
    }

    function supportsInterface(bytes4 id) external pure returns (bool) {
        return id == 0x01ffc9a7 || id == type(IStreamExternalArtifactCurrentPair).interfaceId;
    }
}

contract CollectionPreservationReferenceSampleProbe {
    function sample(
        RefT.Dependencies calldata d,
        Snap.Dependencies calldata source,
        StreamFinalityScope calldata scope,
        Snap.Source calldata facts,
        uint64 index,
        RefR.Capture calldata capture
    ) external view returns (RefT.Sample memory) {
        return Samples.requireSample(d, source, scope, facts, index, capture, true);
    }
}

/// @notice Genuine mixed native policies, membership/selection, preservation checkpoint/output,
/// Collection snapshot, reference host, Schema/Store/Metadata grants and official Safe.
/// @dev Preserves the inherited canonical pre-snapshot Router root and locked Artist boundaries.
/// Per-member producer/admission and PNG/ZIP coverage are explicit typed boundaries. No actual
/// ADR0054 rendering implementation, op17 root adoption, browser or full finality ceremony claimed.
abstract contract PreservationReferenceFixtureV1 is PreservationSnapshotFixtureV1 {
    Ref internal referenceHost;
    RefT.Publication internal referenceInput;
    CollectionPreservationReferenceExternalBoundary internal externalArchive;
    bytes32 internal adoptedSnapshot;

    function _reference() internal {
        _initialize();
        _prepare();
        adoptedSnapshot = _publish();
        externalArchive = new CollectionPreservationReferenceExternalBoundary(address(core));
        referenceInput.scope = publication.scope;
        referenceInput.observation.collectionId = publication.scope.collectionId;
        referenceInput.observation.referenceId =
            keccak256("collection preservation exact reference");
        referenceInput.observation.snapshotRecordHash = adoptedSnapshot;
        referenceInput.observation.snapshotRevision = 1;
        referenceInput.observation.effectiveAt = uint64(block.timestamp);
        referenceInput.observation.reasonHash = keccak256("repeat actual full-policy rendering");
        referenceInput.observation.manifestURI = "ipfs://collection-preservation-reference";
        _environment();
        uint256 count = scopedMembership.requireScopeMembership(publication.scope).tokenCount;
        referenceInput.observation.captures = new RefR.Capture[](count == 1 ? 1 : 2);
        for (uint256 i; i < referenceInput.observation.captures.length; ++i) {
            uint256 token = scopedMembership.scopeTokenAt(publication.scope, i == 0 ? 0 : count - 1);
            (,, uint256 serial,) = core.tokenCollectionIdentity(token);
            bytes memory html = bytes(
                snapshotCapture.producers[i == 0 ? 0 : count - 1].preservationTokenHTML(token)
            );
            RefR.Capture memory c;
            c.tokenId = token;
            c.collectionSerial = serial;
            c.metadataJSONHash = keccak256(
                bytes(
                    snapshotCapture.producers[i == 0 ? 0 : count - 1].preservationTokenJSON(token)
                )
            );
            c.htmlHash = keccak256(html);
            c.htmlBytes = uint32(html.length);
            c.animationHTML = html;
            c.objectHash = keccak256(abi.encode("typed PNG object", token));
            c.coverageHash = keccak256(abi.encode("typed PNG coverage", token));
            c.sourceSha256 = sha256(html);
            c.repeatCaptureSha256 = [
                keccak256(abi.encode("same PNG", token)), keccak256(abi.encode("same PNG", token))
            ];
            c.environmentManifestHash = referenceInput.observation.environment.manifestHash;
            c.capturedAt = uint64(block.timestamp);
            referenceInput.observation.captures[i] = c;
            _external(c.objectHash, c.coverageHash, c.repeatCaptureSha256[0], false);
        }
        _registerReferenceDefinitions();
        _familyGrant(1, Families.CURATOR, 3, address(this), true);
        RefT.Dependencies memory d;
        d.targets = [
            address(core),
            address(metadata),
            address(schemas),
            address(snapshotStore),
            address(router),
            address(snapshotHost),
            address(externalArchive)
        ];
        for (uint256 i; i < d.targets.length; ++i) {
            d.codeHashes[i] = d.targets[i].codehash;
        }
        d.chainId = block.chainid;
        referenceHost = new Ref(d, address(executor), _referenceGas());
        _upload(
            bytes(
                StreamReferenceEnvironmentJson.files(
                    referenceInput.observation.environment.packageFiles, true
                )
            ),
            false
        );
        _upload(
            bytes(
                StreamReferenceEnvironmentJson.files(
                    referenceInput.observation.environment.platformPrerequisites, false
                )
            ),
            false
        );
        referenceHost.prepareFileInventory(
            referenceInput.observation.environment.packageFiles, true
        );
        referenceHost.prepareFileInventory(
            referenceInput.observation.environment.platformPrerequisites, false
        );
    }

    function _referenceGas() internal pure returns (Gas.GasParameterConfig[4] memory configs) {
        // Parent reservations intentionally cover the genuine nested whole-scope producers.
        // They are fixture caps, not transaction/gas acceptance evidence.
        configs[0] = Gas.GasParameterConfig("POLICY_REFERENCE_READ_GAS", 2000000, 50000, 1);
        configs[1] = Gas.GasParameterConfig("POLICY_REFERENCE_SOURCE_GAS", 8000000, 50000, 1);
        configs[2] = Gas.GasParameterConfig("POLICY_REFERENCE_SNAPSHOT_GAS", 128000000, 50000, 1);
        configs[3] = Gas.GasParameterConfig("POLICY_REFERENCE_ARCHIVE_GAS", 2000000, 50000, 1);
    }

    function _referenceBytes(address recorder) internal returns (bytes memory raw) {
        (bytes32 sources, bytes memory payload) =
            referenceHost.previewReference(referenceInput, recorder);
        referenceInput.observation.expectedSourcesHash = sources;
        _upload(abi.encode(referenceInput), false);
        return payload;
    }

    function _publishReference() internal returns (bytes32) {
        _upload(_referenceBytes(address(this)), false);
        return referenceHost.publishReference(referenceInput);
    }

    function _assertReferencePayload(bytes memory raw, RefT.SourceFacts memory expected)
        internal
        view
    {
        (
            bytes32 domain,
            uint256 chain,
            address host,
            RefT.Publication memory p,
            RefT.Receipt memory r,
            RefT.SourceFacts memory f,
            bytes memory environment
        ) = abi.decode(
            raw,
            (bytes32, uint256, address, RefT.Publication, RefT.Receipt, RefT.SourceFacts, bytes)
        );
        require(
            domain == keccak256("6529STREAM_PRESERVATION_POLICY_REFERENCE_PAYLOAD_V1")
                && chain == block.chainid && host == address(referenceHost)
        );
        require(keccak256(raw) == keccak256(abi.encode(domain, chain, host, p, r, f, environment)));
        require(keccak256(abi.encode(f)) == keccak256(abi.encode(expected)));
        require(
            p.observation.expectedSourcesHash == 0
                && r.observation.sourcesHash == referenceInput.observation.expectedSourcesHash
        );
        require(
            r.observation.recordHash == 0 && r.observation.recordChainHash == 0
                && r.observation.payloadHash == 0 && r.observation.payloadBytes == 0
                && r.observation.recordedAt == 0
        );
        require(
            keccak256(environment) == referenceInput.observation.environment.manifestHash
                && environment.length == referenceInput.observation.environment.manifestBytes
        );
        require(keccak256(abi.encode(p.scope)) == keccak256(abi.encode(referenceInput.scope)));
    }

    function _referenceHistory(bytes32 hash) internal view returns (bytes32) {
        (RefT.Publication memory p, RefT.Receipt memory r) = referenceHost.referenceRecord(hash);
        return keccak256(
            abi.encode(
                p, r, referenceHost.referencePayload(hash), referenceHost.referenceSource(hash)
            )
        );
    }

    function _readerDependencies() internal view returns (ReferenceReads.Dependencies memory d) {
        d.targets = [
            address(core),
            address(metadata),
            address(router),
            address(snapshotHost),
            address(referenceHost)
        ];
        for (uint256 i; i < d.targets.length; ++i) {
            d.codeHashes[i] = d.targets[i].codehash;
        }
        d.chainId = block.chainid;
        d.readGas = 2000000;
        // Nested fixture proof budget; no native transaction-size or gas acceptance claim.
        d.sourceGas = 256000000;
    }

    function _referenceAction(uint8 cls, bytes32 scope, bytes32 oldHash, bytes32 newHash) internal {
        snapshotVm.mockCall(
            address(executor),
            abi.encodeWithSignature("currentAction()"),
            abi.encode(
                true, keccak256("exact scoped policy reference lock"), cls, scope, oldHash, newHash
            )
        );
    }

    function _environment() internal {
        RefR.Environment memory e;
        e.objectHash = keccak256("runtime object");
        e.coverageHash = keccak256("runtime coverage");
        e.engineName = "Google Chrome";
        e.engineVersion = "fixture";
        e.engineExecutableSha256 = keccak256("engine bytes boundary");
        e.toolchainName = "reference_capture.py; Python; websockets";
        e.toolchainVersion = "fixture";
        e.toolchainSha256 = keccak256("tool bytes boundary");
        e.engineExecutablePath = "engine/chrome.exe";
        e.toolchainPath = "tool/reference_capture.py";
        e.packageFiles = new RefR.PackageFile[](2);
        e.packageFiles[0] = RefR.PackageFile(e.engineExecutablePath, 10, e.engineExecutableSha256);
        e.packageFiles[1] = RefR.PackageFile(e.toolchainPath, 11, e.toolchainSha256);
        e.platformPrerequisites = new RefR.PackageFile[](1);
        e.platformPrerequisites[0] = RefR.PackageFile(
            "C:/Windows/system32/kernel32.dll", 12, keccak256("explicit OS boundary")
        );
        e.operatingSystem = "Windows";
        e.operatingSystemVersion = "fixture";
        e.architecture = "AMD64";
        e.viewportWidth = 64;
        e.viewportHeight = 64;
        e.devicePixelRatio = 1;
        e.colorSpace = "srgb";
        e.softwareRasterization = true;
        e.captureProfile = keccak256("STREAM_REFERENCE_CANVAS_STILL_WINDOWS_V1");
        e.licenseNote = "undetermined";
        bytes memory raw = StreamReferenceEnvironmentJson.manifest(e);
        e.manifestHash = keccak256(raw);
        e.manifestBytes = uint32(raw.length);
        referenceInput.observation.environment = e;
        _external(e.objectHash, e.coverageHash, keccak256("ZIP SHA boundary"), true);
    }

    function _external(bytes32 object, bytes32 cover, bytes32 sha, bool runtime) internal {
        External.Coverage memory e;
        e.coverageHash = cover;
        e.objectHash = object;
        e.artistId = SNAPSHOT_ARTIST;
        e.contentHash = keccak256(abi.encode("content", object));
        e.sha256Digest = sha;
        e.arweaveDataRoot = keccak256(abi.encode("archive", object));
        e.byteSize = 55;
        e.firstFamilyRecordHash = bytes32(uint256(1));
        e.secondFamilyRecordHash = bytes32(uint256(2));
        e.firstReceiptHash = keccak256(abi.encode("receipt1", object));
        e.secondReceiptHash = keccak256(abi.encode("receipt2", object));
        e.firstFixityHash = bytes32(uint256(3));
        e.secondFixityHash = bytes32(uint256(4));
        e.checkpointHash = keccak256("archive checkpoint boundary");
        e.profileHash = keccak256("archive profile boundary");
        External.ObjectIdentity memory o = External.ObjectIdentity(
            e.artistId,
            runtime ? OriginalDefinitions.ZIP_SCHEMA_ID : OriginalDefinitions.PNG_SCHEMA_ID,
            keccak256("RAW_BYTES"),
            e.contentHash,
            sha,
            e.arweaveDataRoot,
            e.byteSize,
            runtime ? keccak256("IANA:application/zip") : keccak256("IANA:image/png"),
            OriginalDefinitions.FORMAT_CATALOG_ID,
            OriginalDefinitions.FORMAT_CATALOG_HASH
        );
        External.CurrentPair memory pair = External.CurrentPair(
            e.objectHash,
            e.artistId,
            e.contentHash,
            e.sha256Digest,
            e.arweaveDataRoot,
            e.byteSize,
            e.firstFamilyRecordHash,
            e.secondFamilyRecordHash,
            e.firstReceiptHash,
            e.secondReceiptHash,
            e.firstFixityHash,
            e.secondFixityHash,
            e.checkpointHash,
            e.profileHash
        );
        snapshotVm.mockCall(
            address(externalArchive),
            abi.encodeCall(ExternalArchive.requireCoverage, (cover, e.artistId, object)),
            abi.encode(e)
        );
        snapshotVm.mockCall(
            address(externalArchive),
            abi.encodeCall(ExternalArchive.coverage, (cover)),
            abi.encode(e)
        );
        snapshotVm.mockCall(
            address(externalArchive),
            abi.encodeCall(ExternalArchive.objectIdentity, (object)),
            abi.encode(o)
        );
        snapshotVm.mockCall(
            address(externalArchive),
            abi.encodeCall(
                IStreamExternalArtifactCurrentPair.currentReceiptPair,
                (e.firstReceiptHash, e.secondReceiptHash, e.artistId, object)
            ),
            abi.encode(pair)
        );
    }

    function _registerReferenceDefinitions() internal {
        string[3] memory names = [
            "STREAM_PRESERVATION_POLICY_COLLECTION_REFERENCE_ABI_V1",
            "STREAM_PRESERVATION_POLICY_COLLECTION_REFERENCE_PROFILE_V1",
            "STREAM_ABI_PRESERVATION_POLICY_COLLECTION_REFERENCE_V1"
        ];
        string[3] memory files = [
            "preservation-policy-collection-reference-v1.schema.json",
            "preservation-policy-collection-reference-v1.profile.json",
            "preservation-policy-collection-reference-v1.abi.json"
        ];
        for (uint256 i; i < 3; ++i) {
            _register(
                names[i],
                i == 0
                    ? Schema.DocumentKind.SCHEMA
                    : i == 1 ? Schema.DocumentKind.CATALOG : Schema.DocumentKind.CANONICALIZATION,
                bytes(vm.readFile(string.concat("docs/schemas/preservation/", files[i])))
            );
        }
        string[4] memory originals = [
            "STREAM_REFERENCE_NATIVE_ENVIRONMENT_V1",
            "STREAM_REFERENCE_PNG_OBJECT_V1",
            "STREAM_REFERENCE_RUNTIME_ZIP_OBJECT_V1",
            "STREAM_REFERENCE_NATIVE_FORMATS_V1"
        ];
        for (uint256 i; i < 4; ++i) {
            _register(
                originals[i],
                i == 3 ? Schema.DocumentKind.CATALOG : Schema.DocumentKind.SCHEMA,
                bytes(vm.readFile(string.concat("schemas/records/", originals[i], ".json")))
            );
        }
    }
}

contract StreamPreservationPolicyReferencePublicationV1Test is PreservationReferenceFixtureV1 {
    function testCapacityReferenceFamilyDeploymentKeepsProfileGateAndCreateArguments() public {
        _reference();
        RefT.Dependencies memory d = referenceHost.dependencies();
        CapacityReferenceGraph454.Recipe memory r;
        CapacityReferenceGraph454.Graph memory g;
        for (uint256 i; i < 5; ++i) {
            r.inventory.targets[i] = d.targets[i];
            r.inventory.codeHashes[i] = d.codeHashes[i];
        }
        r.inventory.chainId = d.chainId;
        r.targets[3] = address(executor);
        r.codeHashes[3] = address(executor).codehash;
        g.children[3] = d.targets[5];
        g.codeHashes[3] = d.codeHashes[5];
        r.inventory.targets[11] = d.targets[6];
        r.inventory.codeHashes[11] = d.codeHashes[6];
        r.referenceGas[0] = CapacityReferenceGas454.GasParameterConfig(
            "POLICY_REFERENCE_READ_GAS", d.readGas, 50000, 1
        );
        r.referenceGas[1] = CapacityReferenceGas454.GasParameterConfig(
            "POLICY_REFERENCE_SOURCE_GAS", d.sourceGas, 50000, 1
        );
        r.referenceGas[2] = CapacityReferenceGas454.GasParameterConfig(
            "POLICY_REFERENCE_SNAPSHOT_GAS", d.snapshotGas, 50000, 1
        );
        r.referenceGas[3] = CapacityReferenceGas454.GasParameterConfig(
            "POLICY_REFERENCE_ARCHIVE_GAS", d.archiveGas, 50000, 1
        );
        uint64 nonce = CapacityReferenceCreateVm454(address(vm)).getNonce(address(this));

        vm.expectRevert(abi.encodeWithSelector(RefT.InvalidPolicyReference.selector));
        CapacityReferenceDeploy454.deploy(r, g);
        require(
            CapacityReferenceCreateVm454(address(vm)).getNonce(address(this)) == nonce,
            "old snapshot profile refuses without consuming CREATE"
        );
        // Only the existing snapshot profile getter is a typed constructor boundary here.
        // No claim that the original V1 payload becomes a genuine V2 snapshot/reference.
        StaticRouteVm(address(vm))
            .mockCall(
                d.targets[5],
                abi.encodeWithSignature("preservationPolicySnapshotProfile()"),
                abi.encode(keccak256("6529STREAM_PRESERVATION_POLICY_SNAPSHOT_V2"))
            );

        CapacityReferenceV2 child = CapacityReferenceV2(CapacityReferenceDeploy454.deploy(r, g));
        require(
            address(child)
                    == CapacityReferenceCreateVm454(address(vm))
                        .computeCreateAddress(address(this), nonce)
                && CapacityReferenceCreateVm454(address(vm)).getNonce(address(this)) == nonce + 1,
            "original host caller and one CREATE"
        );
        require(
            keccak256(abi.encode(child.dependencies())) == keccak256(abi.encode(d))
                && child.governanceAuthority() == address(executor)
                && child.executorCodeHash() == address(executor).codehash,
            "all seven dependencies and four gas parameters preserved"
        );
        require(
            child.core() == d.targets[0] && child.metadataHost() == d.targets[1]
                && child.metadataRouter() == d.targets[4] && child.snapshots() == d.targets[5]
                && child.archiveCoverage() == d.targets[6]
                && child.deploymentChainId() == block.chainid,
            "original constructor immutables"
        );

        require(
            child.preservationPolicyReferenceProfile()
                    == keccak256("6529STREAM_PRESERVATION_POLICY_REFERENCE_V2")
                && referenceHost.preservationPolicyReferenceProfile()
                    == keccak256("6529STREAM_PRESERVATION_POLICY_REFERENCE_V1"),
            "fixed profiles remain distinct"
        );
        StaticRouteVm(address(vm))
            .mockCall(
                d.targets[5],
                abi.encodeWithSignature("preservationPolicySnapshotProfile()"),
                abi.encode(keccak256("6529STREAM_PRESERVATION_POLICY_SNAPSHOT_V1"))
            );
        bytes32 record = _publishReference();
        require(
            referenceHost.requireCurrent(referenceInput.scope, record, 1).observation.recordHash
                    == record && child.referenceCount(referenceInput.scope) == 0,
            "original profile publication never writes new child history"
        );
    }

    /// @dev Actual Operations and retained Store bytes; the suite's named source/archive
    /// boundaries remain explicit. No browser replay or whole-stack gas claim.
    function testCapacityReferenceOperationsRetainCallerEventAndAtomicRetry() public {
        _reference();
        address recorder = address(0xCA454);
        _familyGrant(referenceInput.scope.collectionId, Families.CURATOR, 3, recorder, true);
        bytes memory raw = _referenceBytes(recorder);
        _upload(raw, false);
        bytes32 sources = referenceInput.observation.expectedSourcesHash;
        referenceInput.observation.expectedSourcesHash =
            keccak256("wrong capacity reference sources");
        vm.expectRevert(abi.encodeWithSelector(RefT.InvalidPolicyReference.selector));
        vm.prank(recorder);
        referenceHost.publishReference(referenceInput);
        referenceInput.observation.expectedSourcesHash = sources;
        _familyGrant(referenceInput.scope.collectionId, Families.CURATOR, 3, recorder, false);
        vm.expectRevert(abi.encodeWithSelector(RefT.PolicyReferenceAuthority.selector, recorder));
        vm.prank(recorder);
        referenceHost.publishReference(referenceInput);
        require(
            referenceHost.referenceCount(referenceInput.scope) == 0
                && referenceHost.currentReference(referenceInput.scope).observation.recordHash == 0,
            "source or authority refusal consumes no id or head"
        );
        _familyGrant(referenceInput.scope.collectionId, Families.CURATOR, 3, recorder, true);
        raw = _referenceBytes(recorder);
        _upload(raw, false);
        RefT.Receipt memory expected;
        {
            (
                bytes32 payloadDomain,
                uint256 chain,
                address producer,
                RefT.Publication memory normalized,
                RefT.Receipt memory receipt,,
            ) = abi.decode(
                raw,
                (bytes32, uint256, address, RefT.Publication, RefT.Receipt, RefT.SourceFacts, bytes)
            );
            require(
                payloadDomain == keccak256("6529STREAM_PRESERVATION_POLICY_REFERENCE_PAYLOAD_V1")
                    && chain == block.chainid && producer == address(referenceHost),
                "original payload host and domain"
            );
            require(
                normalized.observation.expectedSourcesHash == 0
                    && receipt.observation.sourcesHash
                        == referenceInput.observation.expectedSourcesHash
                    && receipt.observation.recorder == recorder
                    && receipt.observation.authorizationClass == 3
                    && receipt.observation.grantRevision == 3 && receipt.observation.recordHash == 0
                    && receipt.observation.recordChainHash == 0
                    && receipt.observation.payloadHash == 0 && receipt.observation.payloadBytes == 0
                    && receipt.observation.recordedAt == 0,
                "canonical receipt keeps real recorder and fresh grant"
            );
            expected = receipt;
        }
        expected.observation.payloadHash = keccak256(raw);
        expected.observation.payloadBytes = uint32(raw.length);
        expected.observation.recordedAt = uint64(block.timestamp);
        bytes32 literalRecord = keccak256(
            abi.encode(
                keccak256("6529STREAM_PRESERVATION_POLICY_REFERENCE_RECORD_V1"),
                block.chainid,
                address(referenceHost),
                address(core),
                address(metadata),
                referenceInput,
                expected
            )
        );

        vm.recordLogs();
        vm.prank(recorder);
        bytes32 record = referenceHost.publishReference(referenceInput);
        Vm.Log[] memory logs = vm.getRecordedLogs();
        require(record == literalRecord, "delegate host and original caller remain in record");
        expected.observation.recordHash = record;
        expected.observation.recordChainHash = keccak256(
            abi.encode(
                keccak256("6529STREAM_PRESERVATION_POLICY_REFERENCE_CHAIN_V1"),
                block.chainid,
                address(referenceHost),
                address(core),
                expected.scopeSubject,
                bytes32(0),
                uint64(1),
                record
            )
        );
        (RefT.Publication memory stored, RefT.Receipt memory receipt) =
            referenceHost.referenceRecord(record);
        require(
            keccak256(abi.encode(stored)) == keccak256(abi.encode(referenceInput))
                && keccak256(abi.encode(receipt)) == keccak256(abi.encode(expected)),
            "all original publication and receipt fields retained"
        );
        require(
            logs.length == 1 && logs[0].emitter == address(referenceHost)
                && logs[0].topics.length == 4,
            "original host event only"
        );
        require(
            logs[0].topics[0]
                    == keccak256(
                        "PolicyReferencePublished(uint16,bytes32,bytes32,bytes32,(bytes32,(bytes32,bytes32,uint256,bytes32,bytes32,uint64,bytes32,uint32,bytes32,bytes32,uint64,address,uint8,uint64,uint64,uint64,bytes32,bytes32,bytes32,bytes32)),string)"
                    ) && logs[0].topics[1] == expected.scopeSubject
                && logs[0].topics[2] == referenceInput.observation.referenceId
                && logs[0].topics[3] == record,
            "exact event signature and indexed fields"
        );
        (uint16 version, RefT.Receipt memory eventReceipt, string memory uri) =
            abi.decode(logs[0].data, (uint16, RefT.Receipt, string));
        require(
            version == 1 && keccak256(abi.encode(eventReceipt)) == keccak256(abi.encode(expected))
                && keccak256(bytes(uri))
                    == keccak256(bytes(referenceInput.observation.manifestURI)),
            "full original event tuple"
        );
        require(
            keccak256(referenceHost.referencePayload(record)) == keccak256(raw)
                && keccak256(
                        abi.encode(referenceHost.requireCurrent(referenceInput.scope, record, 1))
                    ) == keccak256(abi.encode(expected)),
            "current and historical receipt agree"
        );
        bytes32 original = keccak256(abi.encode(stored, receipt, raw));
        vm.expectRevert(abi.encodeWithSelector(RefT.InvalidPolicyReference.selector));
        vm.prank(recorder);
        referenceHost.publishReference(referenceInput);
        require(
            referenceHost.referenceCount(referenceInput.scope) == 1,
            "exact reference id cannot replay"
        );
        referenceInput.observation.referenceId = keccak256("capacity reference successor");
        vm.expectRevert(
            abi.encodeWithSelector(RefT.PolicyReferenceLineage.selector, bytes32(0), record)
        );
        vm.prank(recorder);
        referenceHost.publishReference(referenceInput);
        require(
            referenceHost.referenceCount(referenceInput.scope) == 1
                && referenceHost.referenceAt(referenceInput.scope, 0) == record,
            "stale lineage cannot consume successor id"
        );
        referenceInput.observation.expectedHead = record;
        referenceInput.observation.expectedRevision = 1;
        _upload(_referenceBytes(recorder), false);
        vm.prank(recorder);
        bytes32 successor = referenceHost.publishReference(referenceInput);
        require(
            referenceHost.requireCurrent(referenceInput.scope, successor, 2).observation.predecessor
                    == record && referenceHost.referenceCount(referenceInput.scope) == 2,
            "same refused id succeeds with exact lineage"
        );
        (stored, receipt) = referenceHost.referenceRecord(record);
        require(
            keccak256(abi.encode(stored, receipt, referenceHost.referencePayload(record)))
                == original,
            "successor cannot rewrite original history"
        );
    }

    function testCollectionReferenceRetainsMixedPoliciesEveryProducerAndLiteralOriginalHashes()
        public
    {
        _reference();
        bytes memory raw = _referenceBytes(address(this));
        _upload(raw, false);
        vm.recordLogs();
        bytes32 hash = referenceHost.publishReference(referenceInput);
        Vm.Log[] memory logs = vm.getRecordedLogs();
        require(logs.length == 1 && logs[0].emitter == address(referenceHost));
        (uint16 version, RefT.Receipt memory eventReceipt, string memory uri) =
            abi.decode(logs[0].data, (uint16, RefT.Receipt, string));
        RefT.Receipt memory r = referenceHost.requireCurrent(referenceInput.scope, hash, 1);
        require(version == 1 && logs[0].topics.length == 4 && logs[0].topics[3] == hash);
        require(
            keccak256(abi.encode(eventReceipt)) == keccak256(abi.encode(r))
                && keccak256(bytes(uri)) == keccak256(bytes(referenceInput.observation.manifestURI))
        );
        RefT.SourceFacts memory f = referenceHost.referenceSource(hash);
        _assertReferencePayload(raw, f);
        require(
            f.snapshot.recordHash == adoptedSnapshot
                && f.contentRootRecordHash == publication.contentRootRecord
        );
        require(keccak256(abi.encode(f.contentRoot)) == keccak256(abi.encode(canonicalRoot)));
        require(
            abi.encode(f.contentRootBinding).length == 608
                && keccak256(abi.encode(f.contentRootBinding)) == keccak256(abi.encode(rootBinding))
        );
        require(
            f.snapshotSource.membership.tokenCount == 2 && f.snapshotSource.entropy.policyCount == 2
                && f.snapshotSource.entropy.allFrozen
        );
        require(
            abi.encode(f.snapshotSource.content).length == 448
                && abi.encode(f.snapshotSource.outputs).length == 608 && f.samples.length == 2
        );
        for (uint256 i; i < 2; ++i) {
            Content.Output memory row = snapshotContent.outputAt(snapshotCapture.id, i);
            require(abi.encode(row).length == 1152 && f.samples[i].membershipIndex == i);
            require(
                keccak256(abi.encode(f.samples[i].preservation))
                    == keccak256(abi.encode(row.preservation))
            );
            require(
                keccak256(abi.encode(f.samples[i].preservationAdmission))
                    == keccak256(abi.encode(row.preservationAdmission))
            );
            require(
                keccak256(abi.encode(f.samples[i].entropy)) == keccak256(abi.encode(row.entropy))
            );
            require(
                f.samples[i].observation.collectionSerial
                    == referenceInput.observation.captures[i].collectionSerial
            );
        }
        require(
            f.samples[0].entropy.terminal && f.samples[0].entropy.seed == 0
                && f.samples[0].terminalAdmissionHash != 0
        );
        require(
            f.samples[1].entropy.finalized && f.samples[1].entropy.seed == scopedFinalizedSeed
                && f.samples[1].terminalAdmissionHash == 0
        );
        require(f.samples[0].preservation.producer != f.samples[1].preservation.producer);
        RefT.Dependencies memory d = referenceHost.dependencies();
        require(
            r.observation.sourcesHash
                == keccak256(
                    abi.encode(
                        keccak256("6529STREAM_PRESERVATION_POLICY_REFERENCE_SOURCES_V1"),
                        block.chainid,
                        address(referenceHost),
                        d.targets,
                        d.codeHashes,
                        f
                    )
                )
        );
        RefT.Receipt memory fields = abi.decode(abi.encode(r), (RefT.Receipt));
        fields.observation.recordHash = 0;
        fields.observation.recordChainHash = 0;
        require(
            hash
                == keccak256(
                    abi.encode(
                        keccak256("6529STREAM_PRESERVATION_POLICY_REFERENCE_RECORD_V1"),
                        block.chainid,
                        address(referenceHost),
                        address(core),
                        address(metadata),
                        referenceInput,
                        fields
                    )
                )
        );
        require(
            r.observation.recordChainHash
                == keccak256(
                    abi.encode(
                        keccak256("6529STREAM_PRESERVATION_POLICY_REFERENCE_CHAIN_V1"),
                        block.chainid,
                        address(referenceHost),
                        address(core),
                        r.scopeSubject,
                        bytes32(0),
                        uint64(1),
                        hash
                    )
                )
        );
        require(
            referenceHost.referenceCount(referenceInput.scope) == 1
                && referenceHost.referenceAt(referenceInput.scope, 0) == hash
        );
        require(keccak256(referenceHost.referencePayload(hash)) == keccak256(raw));
    }

    function testCollectionReferenceCapabilitiesAndEveryOtherScopeCannotBorrowOriginalRecords()
        public
    {
        _reference();
        require(referenceHost.supportsInterface(type(RefInterface).interfaceId));
        require(!referenceHost.supportsInterface(type(OldRefInterface).interfaceId));
        require(!referenceHost.supportsInterface(type(ScopedRefInterface).interfaceId));
        require(
            referenceHost.preservationPolicyReferenceProfile()
                == keccak256("6529STREAM_PRESERVATION_POLICY_REFERENCE_V1")
        );
        _referenceBytes(address(this));
        for (uint8 i = 0; i < 4; ++i) {
            RefT.Publication memory bad = abi.decode(abi.encode(referenceInput), (RefT.Publication));
            bad.scope = i == 0
                ? StreamFinalityScope(StreamFinalityScopeType.TOKEN, 1, 91, 0)
                : i == 1
                    ? StreamFinalityScope(
                        StreamFinalityScopeType.RELEASE, 1, 0, bytes32(uint256(1))
                    )
                    : i == 2
                        ? StreamFinalityScope(
                                StreamFinalityScopeType.SEASON, 1, 0, bytes32(uint256(1))
                            )
                        : StreamFinalityScope(
                            StreamFinalityScopeType.VIEW, 1, 0, bytes32(uint256(1))
                        );
            vm.expectRevert(abi.encodeWithSelector(RefT.InvalidPolicyReference.selector));
            referenceHost.previewReference(bad, address(this));
        }
        RefT.Dependencies memory d = referenceHost.dependencies();
        snapshotVm.mockCall(
            address(snapshotHost),
            abi.encodeCall(SnapshotInterface.preservationPolicySnapshotProfile, ()),
            abi.encode(keccak256("old policy snapshot"))
        );
        vm.expectRevert(abi.encodeWithSelector(RefT.InvalidPolicyReference.selector));
        new Ref(d, address(executor), _referenceGas());
        snapshotVm.mockCall(
            address(snapshotHost),
            abi.encodeCall(SnapshotInterface.preservationPolicySnapshotProfile, ()),
            abi.encode(keccak256("6529STREAM_PRESERVATION_POLICY_SNAPSHOT_V1"))
        );
        _publishReference();
    }

    function testCollectionReferenceSampleMembershipAndByteExactObservationAreNotOptional() public {
        _reference();
        _referenceBytes(address(this));
        RefT.Publication memory bad = abi.decode(abi.encode(referenceInput), (RefT.Publication));
        RefR.Capture memory first = bad.observation.captures[0];
        bad.observation.captures[0] = bad.observation.captures[1];
        bad.observation.captures[1] = first;
        vm.expectRevert(abi.encodeWithSelector(RefT.InvalidPolicyReference.selector));
        referenceHost.previewReference(bad, address(this));
        bad = abi.decode(abi.encode(referenceInput), (RefT.Publication));
        bad.observation.captures = new RefR.Capture[](1);
        bad.observation.captures[0] = first;
        vm.expectRevert(abi.encodeWithSelector(RefT.InvalidPolicyReference.selector));
        referenceHost.previewReference(bad, address(this));
        bad = abi.decode(abi.encode(referenceInput), (RefT.Publication));
        bad.observation.captures[1].animationHTML =
            abi.encodePacked(bad.observation.captures[1].animationHTML, bytes1(0x20));
        vm.expectRevert(abi.encodeWithSelector(RefT.InvalidPolicyReference.selector));
        referenceHost.previewReference(bad, address(this));
        bad = abi.decode(abi.encode(referenceInput), (RefT.Publication));
        bad.observation.captures[1].repeatCaptureSha256[1] ^= bytes32(uint256(1));
        vm.expectRevert(abi.encodeWithSelector(RefT.InvalidPolicyReference.selector));
        referenceHost.previewReference(bad, address(this));
        require(referenceHost.referenceCount(referenceInput.scope) == 0);
        _publishReference();
    }

    function testCollectionSampleIndependentlyAuthenticatesAllSixteenSavedAdmissionWords() public {
        _reference();
        bytes32 hash = _publishReference();
        RefT.SourceFacts memory f = referenceHost.referenceSource(hash);
        CollectionPreservationReferenceSampleProbe probe =
            new CollectionPreservationReferenceSampleProbe();
        RefT.Dependencies memory d = referenceHost.dependencies();
        Snap.Dependencies memory sd = snapshotHost.dependencies();
        RefR.Capture memory capture = referenceInput.observation.captures[1];
        RefT.Sample memory expected =
            probe.sample(d, sd, referenceInput.scope, f.snapshotSource, 1, capture);
        bytes memory original =
            abi.encode(_binding(snapshotCapture, 1), _admission(snapshotCapture, 1));
        require(original.length == 512);
        for (uint256 i; i < 16; ++i) {
            bytes memory corrupt = abi.encodePacked(original);
            corrupt[(i + 1) * 32 - 1] = bytes1(uint8(corrupt[(i + 1) * 32 - 1]) ^ 1);
            _setAdmission(snapshotCapture, 1, corrupt);
            vm.expectRevert();
            probe.sample(d, sd, referenceInput.scope, f.snapshotSource, 1, capture);
            _setAdmission(snapshotCapture, 1, original);
            require(
                keccak256(
                    abi.encode(
                        probe.sample(d, sd, referenceInput.scope, f.snapshotSource, 1, capture)
                    )
                ) == keccak256(abi.encode(expected))
            );
        }
        _setAdmission(snapshotCapture, 1, abi.encodePacked(original, bytes32(uint256(1))));
        vm.expectRevert();
        probe.sample(d, sd, referenceInput.scope, f.snapshotSource, 1, capture);
        _setAdmission(snapshotCapture, 1, original);
        referenceHost.requireCurrent(referenceInput.scope, hash, 1);
    }

    function testCollectionSampleRejectsAnotherMembersProducerAndRetainsHistoricalFacts() public {
        _reference();
        bytes32 hash = _publishReference();
        bytes32 history = _referenceHistory(hash);
        RefT.SourceFacts memory f = referenceHost.referenceSource(hash);
        CollectionPreservationReferenceSampleProbe probe =
            new CollectionPreservationReferenceSampleProbe();
        RefT.Dependencies memory d = referenceHost.dependencies();
        Snap.Dependencies memory sd = snapshotHost.dependencies();
        Content.Output memory row = snapshotContent.outputAt(snapshotCapture.id, 1);
        bytes memory original = abi.encode(row);
        row.preservation = _binding(snapshotCapture, 0);
        row.preservationAdmission = _admission(snapshotCapture, 0);
        snapshotVm.mockCall(
            address(snapshotContent),
            abi.encodeCall(Content.outputAt, (snapshotCapture.id, uint256(1))),
            abi.encode(row)
        );
        RefR.Capture memory c = referenceInput.observation.captures[1];
        vm.expectRevert();
        probe.sample(d, sd, referenceInput.scope, f.snapshotSource, 1, c);
        require(_referenceHistory(hash) == history);
        snapshotVm.mockCall(
            address(snapshotContent),
            abi.encodeCall(Content.outputAt, (snapshotCapture.id, uint256(1))),
            original
        );
        referenceHost.requireCurrent(referenceInput.scope, hash, 1);
    }

    function testCollectionReferenceUsesPreservationBytesAndDriftOnlyStalesCurrent() public {
        _reference();
        bytes32 hash = _publishReference();
        bytes32 history = _referenceHistory(hash);
        uint256 token = referenceInput.observation.captures[1].tokenId;
        string memory json = snapshotCapture.producers[1].preservationTokenJSON(token);
        string memory html = snapshotCapture.producers[1].preservationTokenHTML(token);
        // Direct display bytes are a separate boundary; the saved producer is the authority here.
        snapshotVm.mockCall(
            address(router),
            abi.encodeWithSignature("tokenJSON(uint256)", token),
            abi.encode("changed live-only JSON")
        );
        snapshotVm.mockCall(
            address(router),
            abi.encodeWithSignature("tokenHTML(uint256)", token),
            abi.encode("changed live-only HTML")
        );
        referenceHost.requireCurrent(referenceInput.scope, hash, 1);
        snapshotCapture.producers[1].setBytes(token, string.concat(json, " "), html);
        vm.expectRevert();
        referenceHost.requireCurrent(referenceInput.scope, hash, 1);
        require(_referenceHistory(hash) == history);
        snapshotCapture.producers[1].setBytes(token, json, html);
        referenceHost.requireCurrent(referenceInput.scope, hash, 1);
        P.Admission memory a = _admission(snapshotCapture, 1);
        a.goldenHash ^= bytes32(uint256(1));
        _setAdmission(snapshotCapture, 1, abi.encode(_binding(snapshotCapture, 1), a));
        vm.expectRevert();
        referenceHost.requireCurrent(referenceInput.scope, hash, 1);
        require(_referenceHistory(hash) == history);
        _setAdmission(
            snapshotCapture,
            1,
            abi.encode(_binding(snapshotCapture, 1), _admission(snapshotCapture, 1))
        );
        referenceHost.requireCurrent(referenceInput.scope, hash, 1);
    }

    function testCollectionReferenceRootHeadDriftPreservesOriginalReaderButRejectsCurrent() public {
        _reference();
        bytes32 hash = _publishReference();
        bytes32 history = _referenceHistory(hash);
        ReferenceReads.Dependencies memory d = _readerDependencies();
        ReferenceReads.requireCurrent(d, referenceInput.scope, hash, 1);
        snapshotVm.mockCall(
            address(router),
            abi.encodeCall(Root.collectionContentRootHead, (uint256(1))),
            abi.encode(bytes32(uint256(99)))
        );
        vm.expectRevert();
        ReferenceReads.requireCurrent(d, referenceInput.scope, hash, 1);
        (, RefT.Receipt memory original) = ReferenceReads.original(d, referenceInput.scope, hash, 1);
        require(original.observation.recordHash == hash && _referenceHistory(hash) == history);
        _refreshRoot();
        ReferenceReads.requireCurrent(d, referenceInput.scope, hash, 1);
        snapshotVm.mockCall(
            address(referenceHost),
            abi.encodeCall(RefInterface.preservationPolicyReferenceProfile, ()),
            abi.encode(keccak256("old reference"))
        );
        vm.expectRevert(
            abi.encodeWithSelector(ReferenceReads.InvalidPolicyReferenceEvidence.selector)
        );
        ReferenceReads.original(d, referenceInput.scope, hash, 1);
    }

    function testCollectionReferenceCuratorGrantLineageAndExactClassTwoLock() public {
        _reference();
        address recorder = address(0xB00B);
        vm.expectRevert(abi.encodeWithSelector(RefT.PolicyReferenceAuthority.selector, recorder));
        referenceHost.previewReference(referenceInput, recorder);
        _familyGrant(0, Families.CURATOR, 8, recorder, true);
        _familyGrant(1, Families.CURATOR, 3, recorder, true);
        _upload(_referenceBytes(recorder), false);
        vm.prank(recorder);
        bytes32 first = referenceHost.publishReference(referenceInput);
        RefT.Receipt memory r = referenceHost.requireCurrent(referenceInput.scope, first, 1);
        require(r.observation.authorizationClass == 3 && r.observation.grantRevision == 1);
        bytes32 history = _referenceHistory(first);
        vm.expectRevert(abi.encodeWithSelector(RefT.InvalidPolicyReference.selector));
        referenceHost.publishReference(referenceInput);
        referenceInput.observation.referenceId = keccak256("successor reference");
        referenceInput.observation.expectedHead = first;
        referenceInput.observation.expectedRevision = 1;
        bytes32 second = _publishReference();
        require(
            referenceHost.currentReference(referenceInput.scope).observation.predecessor == first
                && _referenceHistory(first) == history
        );
        (bytes32 scope, bytes32 oldHash, bytes32 next) =
            referenceHost.lockTransition(referenceInput.scope);
        _referenceAction(1, scope, oldHash, next);
        vm.expectRevert(
            abi.encodeWithSelector(RefT.PolicyReferenceAuthority.selector, address(executor))
        );
        vm.prank(address(executor));
        referenceHost.lockReference(referenceInput.scope);
        _referenceAction(2, scope, oldHash, next);
        vm.prank(address(executor));
        referenceHost.lockReference(referenceInput.scope);
        ReferenceReads.Dependencies memory d = _readerDependencies();
        (RefT.Receipt memory saved, RefR.Lock memory l) =
            ReferenceReads.requireLocked(d, referenceInput.scope, second, 2);
        require(
            saved.observation.recordHash == second && l.recordHash == second && l.revision == 2
                && l.actionId != 0
        );
        ReferenceReads.component(d, referenceInput.scope, second, 2);
        referenceInput.observation.referenceId = keccak256("after lock");
        referenceInput.observation.expectedHead = second;
        referenceInput.observation.expectedRevision = 2;
        vm.expectRevert(
            abi.encodeWithSelector(RefT.PolicyReferenceLocked.selector, saved.scopeSubject)
        );
        referenceHost.previewReference(referenceInput, address(this));
    }

    function testCollectionReferenceOfficialSafeLateStoreFailureAndIdenticalRetry() public {
        _reference();
        uint256[] memory keys = new uint256[](2);
        keys[0] = 0x837121;
        keys[1] = 0x837122;
        OfficialSafe account =
            createOfficialSafe(deploySafeComponents("1.4.1"), safeOwnerAddresses(keys), 2, 8711);
        _familyGrant(1, Families.CURATOR, 3, address(account), true);
        bytes memory raw = _referenceBytes(address(account));
        require(raw.length > 8192);
        _upload(raw, true);
        bytes memory input = abi.encodeCall(referenceHost.publishReference, (referenceInput));
        uint256 nonce = account.nonce();
        bytes memory signature = safeThresholdSignature(
            keys,
            account.getTransactionHash(
                address(referenceHost), 0, input, 0, 0, 0, 0, address(0), address(0), nonce
            )
        );
        vm.expectRevert(abi.encodeWithSignature("Error(string)", "GS013"));
        account.execTransaction(
            address(referenceHost), 0, input, 0, 0, 0, 0, address(0), payable(address(0)), signature
        );
        require(
            account.nonce() == nonce && referenceHost.referenceCount(referenceInput.scope) == 0
                && referenceHost.currentReference(referenceInput.scope).observation.recordHash == 0
        );
        _upload(raw, false);
        require(
            account.execTransaction(
                address(referenceHost),
                0,
                input,
                0,
                0,
                0,
                0,
                address(0),
                payable(address(0)),
                signature
            )
        );
        RefT.Receipt memory r = referenceHost.currentReference(referenceInput.scope);
        require(
            account.nonce() == nonce + 1 && r.observation.recorder == address(account)
                && keccak256(referenceHost.referencePayload(r.observation.recordHash))
                    == keccak256(raw)
        );
        referenceHost.requireCurrent(referenceInput.scope, r.observation.recordHash, 1);
    }

    function testCollectionReferenceInventoryKeepsEveryOrderedFileAndCaptureOriginal() public {
        _reference();
        bytes32 hash = _publishReference();
        RefT.SourceFacts memory f = referenceHost.referenceSource(hash);
        InventoryContext.Context memory c;
        c.records.collectionId = 1;
        c.records.artistId = SNAPSHOT_ARTIST;
        c.snapshot = f.snapshot;
        c.referenceRender = referenceHost.currentReference(referenceInput.scope);
        c.source = f.snapshotSource;
        InventorySources.Dependencies memory d;
        // This isolated reference-stage test pins genuine code in the unused fixed-role slots;
        // it does not assert those slots form a complete render-critical inventory graph.
        for (uint256 i; i < 12; ++i) {
            d.targets[i] = address(core);
            d.codeHashes[i] = address(core).codehash;
        }
        for (uint256 i; i < 5; ++i) {
            d.artistTargets[i] = address(artist);
            d.artistCodeHashes[i] = address(artist).codehash;
        }
        d.artistContentOwner = address(artist);
        d.artistContentOwnerCodeHash = address(artist).codehash;
        d.targets[6] = address(referenceHost);
        d.codeHashes[6] = address(referenceHost).codehash;
        d.targets[10] = address(snapshotCoverage);
        d.codeHashes[10] = address(snapshotCoverage).codehash;
        d.targets[11] = address(externalArchive);
        d.codeHashes[11] = address(externalArchive).codehash;
        d.chainId = block.chainid;
        d.readGas = 2000000;
        d.sourceGas = 8000000;
        d.selectionGas = 2000000;
        d.snapshotGas = 2000000;
        d.referenceGas = 2000000;
        Inventory.Item[] memory rows = ReferenceInventory.items(d, c);
        require(
            rows.length == 10 && rows[0].role == keccak256("REFERENCE_MANIFEST")
                && rows[0].schemaId == RefDocuments.SCHEMA_ID
        );
        require(
            rows[1].role == keccak256("REFERENCE_ENVIRONMENT_DECLARATION")
                && rows[2].role == keccak256("RUNNABLE_ENGINE_TOOLCHAIN_ZIP")
        );
        require(
            rows[3].role == keccak256("RUNNABLE_PACKAGE_MEMBER")
                && rows[4].role == keccak256("RUNNABLE_PACKAGE_MEMBER")
                && rows[5].role == keccak256("NATIVE_OS_PREREQUISITE")
        );
        for (uint256 i = 6; i < 10; ++i) {
            require(
                rows[i].role
                    == (i % 2 == 0
                            ? keccak256("REFERENCE_CAPTURE")
                            : keccak256("REFERENCE_CAPTURE_DECLARATION"))
            );
        }
        c.source.scope.collectionId = 2;
        vm.expectRevert(abi.encodeWithSelector(Inventory.InventorySourceChanged.selector));
        ReferenceInventory.items(d, c);
    }
}
