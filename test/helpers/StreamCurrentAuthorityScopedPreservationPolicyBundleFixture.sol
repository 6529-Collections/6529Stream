// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    StreamCurrentAuthorityScopedPreservationPolicySealingFixture
} from "./StreamCurrentAuthorityScopedPreservationPolicySealingFixture.sol";
import {
    IStreamScopedPreservationPolicyBundleArchiveCoverageV1 as ScopedBundleInterface
} from "../../smart-contracts/interfaces/stream/preservation/IStreamScopedPreservationPolicyBundleArchiveCoverageV1.sol";
import {
    StreamCurrentAuthorityScopedPreservationPolicyBundleArchiveCoverageV1 as ScopedBundleHost
} from "../../smart-contracts/domains/preservation/StreamCurrentAuthorityScopedPreservationPolicyBundleArchiveCoverageV1.sol";
import {
    StreamCurrentAuthorityScopedPreservationPolicyRenderCriticalInventoryV1 as ScopedBundleInventory
} from "../../smart-contracts/domains/preservation/StreamCurrentAuthorityScopedPreservationPolicyRenderCriticalInventoryV1.sol";
import {
    StreamScopedPreservationPolicyBundleArchiveTypesV1 as ScopedBundleEvidence
} from "../../smart-contracts/interfaces/stream/preservation/StreamScopedPreservationPolicyBundleArchiveTypesV1.sol";
import {
    StreamPreservationInventoryTypes as ScopedBundleItems
} from "../../smart-contracts/interfaces/stream/preservation/StreamPreservationInventoryTypes.sol";
import {
    StreamBundleArchiveTypes as ScopedBundle
} from "../../smart-contracts/interfaces/stream/preservation/StreamBundleArchiveTypes.sol";
import {
    StreamExternalArtifactTypes as ScopedBundleExternal
} from "../../smart-contracts/interfaces/stream/preservation/StreamExternalArtifactTypes.sol";
import {
    StreamReferenceRenderTypes as ScopedBundleReference
} from "../../smart-contracts/interfaces/stream/preservation/StreamReferenceRenderTypes.sol";
import {
    StreamCurrentAuthorityInventoryTypes as ScopedBundleAuthority
} from "../../smart-contracts/interfaces/stream/preservation/StreamCurrentAuthorityInventoryTypes.sol";
import {
    StreamArtistArchiveOriginTypes as ScopedBundleOrigins
} from "../../smart-contracts/interfaces/stream/preservation/StreamArtistArchiveOriginTypes.sol";
import {
    StreamPreservationInventoryChains as ScopedBundleChains
} from "../../smart-contracts/domains/preservation/StreamPreservationInventoryChains.sol";

/// @notice Consumes every preservation inventory occurrence through its actual scoped child 6.
/// @dev The caller supplies bytes retained from this source graph and fresh package endpoint
/// proofs. No browser/package capture is performed here, and no native fixture capture is read.
/// Actual inventory commitments authenticate byte identity; this helper cannot make arbitrary
/// supplied bytes an original. The existing local checkpoint/receipt signers are fixture evidence,
/// not live storage delivery. Every canonicalization ID remains unchanged: a production reader
/// that does not support a source profile must reject it rather than receive a normalized item.
abstract contract StreamCurrentAuthorityScopedPreservationPolicyBundleFixture is
    StreamCurrentAuthorityScopedPreservationPolicySealingFixture
{
    struct AuthorityScopedEndpoint {
        bytes32 contentHash;
        bytes32 sha256Digest;
        bytes32 arweaveDataRoot;
        uint64 byteSize;
        bytes firstDataPath;
        bytes lastDataPath;
        bytes firstChunkRaw;
        bytes lastChunkRaw;
    }

    struct AuthorityScopedPackageProof {
        uint256 packageIndex;
        string path;
        AuthorityScopedEndpoint endpoint;
    }

    struct AuthorityScopedPackageInputs {
        bool fromFiles;
        AuthorityScopedPackageProof[] objects;
        string[] paths;
    }

    struct AuthorityScopedBundle {
        address host;
        ScopedBundleEvidence.BundleEvidence evidence;
        ScopedBundle.Proof[][] proofs;
        bytes32 refreshId;
        uint256 byteOccurrences;
        uint256 packageMembers;
        uint256 emptyPackageMembers;
        uint256 stateBundles;
    }

    /// @dev retainedBytes are complete exact source bytes, not digests copied from inventory.
    /// Package proofs contain one entry per nonempty declared file, ordered by packageIndex.
    /// largeByteProofs contain one unique endpoint proof for each distinct retained byte object
    /// of at least 262144 bytes that the inventory actually requires. Small byte objects derive
    /// their exact single-leaf native path from their complete supplied bytes.
    function _authorityCoverScopedBundle(
        AuthorityScopedPublication memory publication,
        AuthorityScopedReference memory referenceResult,
        AuthorityScopedInventory memory inventoryResult,
        bytes[] memory retainedBytes,
        AuthorityScopedPackageProof[] memory packageProofs,
        AuthorityScopedEndpoint[] memory largeByteProofs
    ) internal returns (AuthorityScopedBundle memory result) {
        AuthorityScopedPackageInputs memory packages =
            AuthorityScopedPackageInputs(false, packageProofs, new string[](0));
        return _scopedBundleCover(
            publication, referenceResult, inventoryResult, retainedBytes, packages, largeByteProofs
        );
    }

    /// @notice Streams explicitly supplied fresh package proof files, retaining only B.Proof rows.
    /// @dev One path per nonempty original file, in original package order. The caller chooses
    /// task-owned paths under its Foundry filesystem permissions; there is no directory discovery,
    /// fallback path or automatic claim that a file's timestamp proves a fresh browser capture.
    /// The flat JSON fields are packageIndex, path, contentHash, sha256Digest, arweaveDataRoot,
    /// byteSize, firstDataPath, lastDataPath, firstChunkRaw and lastChunkRaw. Each file is read only
    /// inside a separate self-call; no complete package endpoint array enters the parent frame.
    /// Retained bytes and rare large-source endpoints still use the bounded in-memory API.
    function _authorityCoverScopedBundle(
        AuthorityScopedPublication memory publication,
        AuthorityScopedReference memory referenceResult,
        AuthorityScopedInventory memory inventoryResult,
        bytes[] memory retainedBytes,
        string[] memory packageProofPaths,
        AuthorityScopedEndpoint[] memory largeByteProofs
    ) internal returns (AuthorityScopedBundle memory result) {
        AuthorityScopedPackageInputs memory packages = AuthorityScopedPackageInputs(
            true, new AuthorityScopedPackageProof[](0), packageProofPaths
        );
        return _scopedBundleCover(
            publication, referenceResult, inventoryResult, retainedBytes, packages, largeByteProofs
        );
    }

    function _scopedBundleCover(
        AuthorityScopedPublication memory publication,
        AuthorityScopedReference memory referenceResult,
        AuthorityScopedInventory memory inventoryResult,
        bytes[] memory retainedBytes,
        AuthorityScopedPackageInputs memory packages,
        AuthorityScopedEndpoint[] memory largeByteProofs
    ) private returns (AuthorityScopedBundle memory result) {
        ScopedBundleHost host = _scopedBundleHost(publication, referenceResult, inventoryResult);
        result.host = address(host);
        _scopedBundleInputs(retainedBytes, packages.objects, largeByteProofs);
        uint256 packageCount = packages.fromFiles ? packages.paths.length : packages.objects.length;
        if (packages.fromFiles) {
            for (uint256 i; i < packages.paths.length; ++i) {
                _scopedBundleProofPath(packages.paths[i]);
            }
        }
        bool[] memory usedLarge = new bool[](largeByteProofs.length);
        bool[] memory usedBytes = new bool[](retainedBytes.length);
        result.proofs = new ScopedBundle.Proof[][](inventoryResult.rows.length);
        ScopedBundleReference.PackageFile[] memory files =
        referenceResult.publication.observation.environment.packageFiles;
        uint256 nextPackage;
        uint256 nextFile;
        for (uint256 i; i < inventoryResult.rows.length; ++i) {
            result.proofs[i] = new ScopedBundle.Proof[](inventoryResult.rows[i].length);
            for (uint256 j; j < inventoryResult.rows[i].length; ++j) {
                ScopedBundleItems.Item memory item = inventoryResult.rows[i][j];
                if (item.role == keccak256("RUNNABLE_PACKAGE_MEMBER")) {
                    require(item.sourceIndex == nextFile && nextFile < files.length);
                    ScopedBundleReference.PackageFile memory file = files[nextFile++];
                    _scopedBundleFile(item, file, referenceResult);
                    if (file.byteSize == 0) {
                        require(item.kind == ScopedBundleItems.Kind.EMPTY_PACKAGE_MEMBER);
                        ++result.emptyPackageMembers;
                    } else {
                        require(
                            item.kind == ScopedBundleItems.Kind.EXTERNAL_REFERENCE
                                && nextPackage < packageCount
                        );
                        if (packages.fromFiles) {
                            result.proofs[i][j] = this.coverAuthorityScopedPackageFile(
                                item, file, packages.paths[nextPackage]
                            );
                        } else {
                            AuthorityScopedPackageProof memory proof = packages.objects[nextPackage];
                            _scopedBundlePackageProof(item, file, proof);
                            result.proofs[i][j] =
                                this.coverAuthorityScopedEndpoint(item, proof.endpoint);
                        }
                        ++nextPackage;
                        ++result.packageMembers;
                    }
                } else if (item.kind == ScopedBundleItems.Kind.STATE_BUNDLE) {
                    ++result.stateBundles;
                } else if (item.kind == ScopedBundleItems.Kind.EXTERNAL_OBJECT) {
                    result.proofs[i][j] =
                        ScopedBundle.Proof(1, item.originalCoverageHash, item.objectHash);
                } else if (item.kind == ScopedBundleItems.Kind.ONCHAIN_OBJECT) {
                    result.proofs[i][j] =
                        ScopedBundle.Proof(2, item.originalCoverageHash, item.objectHash);
                } else if (
                    item.kind != ScopedBundleItems.Kind.ABSENT
                        && item.kind != ScopedBundleItems.Kind.EMPTY_BYTES
                        && item.kind != ScopedBundleItems.Kind.NATIVE_OS_PREREQUISITE
                ) {
                    require(item.kind != ScopedBundleItems.Kind.EMPTY_PACKAGE_MEMBER);
                    uint256 at = _scopedBundleBytes(item, retainedBytes);
                    usedBytes[at] = true;
                    AuthorityScopedEndpoint memory endpoint;
                    if (retainedBytes[at].length >= 262144) {
                        uint256 large = _scopedBundleLarge(retainedBytes[at], largeByteProofs);
                        usedLarge[large] = true;
                        endpoint = largeByteProofs[large];
                    }
                    result.proofs[i][j] =
                        this.coverAuthorityScopedRetainedBytes(item, retainedBytes[at], endpoint);
                    ++result.byteOccurrences;
                }
            }
        }
        require(
            nextPackage == packageCount && nextFile == files.length
                && result.packageMembers + result.emptyPackageMembers == files.length,
            "every original package member has exactly one ordered occurrence"
        );
        for (uint256 i; i < usedLarge.length; ++i) {
            require(usedLarge[i], "no unrelated large object proof");
        }
        for (uint256 i; i < usedBytes.length; ++i) {
            require(usedBytes[i], "byte registry contains only actually required source bytes");
        }
        // Complete every new receipt/fixity before freezing the bundle environment. Source
        // currentness is checked separately from archived-object liveness, before and after.
        _scopedBundleCurrent(publication, inventoryResult);
        _scopedBundleConsume(host, inventoryResult, result);
        _scopedBundleCurrent(publication, inventoryResult);
    }

    /// @dev The object-array route releases this frame's copies; its caller still retains inputs.
    function coverAuthorityScopedEndpoint(
        ScopedBundleItems.Item calldata item,
        AuthorityScopedEndpoint calldata endpoint
    ) external returns (ScopedBundle.Proof memory) {
        require(msg.sender == address(this), "fixture self-call only");
        return _scopedBundleExternal(item, endpoint);
    }

    /// @dev Filesystem read and JSON/endpoint allocations remain in this single-member frame.
    /// The original item/file identity is already checked against the real retained reference;
    /// every field below is also checked before the production native verifier is called.
    function coverAuthorityScopedPackageFile(
        ScopedBundleItems.Item calldata item,
        ScopedBundleReference.PackageFile calldata file,
        string calldata proofPath
    ) external returns (ScopedBundle.Proof memory) {
        require(msg.sender == address(this), "fixture self-call only");
        _scopedBundleProofPath(proofPath);
        string memory json = assemblyVm.readFile(proofPath);
        // Two maximum native chunks are about 1 MiB when hex encoded. Leave explicit room
        // for both bounded 64-level paths and metadata; no unbounded package document parser.
        require(bytes(json).length != 0 && bytes(json).length <= 2 * 1024 * 1024);
        AuthorityScopedPackageProof memory proof;
        proof.packageIndex = assemblyVm.parseJsonUint(json, ".packageIndex");
        proof.path = assemblyVm.parseJsonString(json, ".path");
        proof.endpoint.contentHash = _scopedBundleJSONHash(json, ".contentHash");
        proof.endpoint.sha256Digest = _scopedBundleJSONHash(json, ".sha256Digest");
        proof.endpoint.arweaveDataRoot = _scopedBundleJSONHash(json, ".arweaveDataRoot");
        uint256 size = assemblyVm.parseJsonUint(json, ".byteSize");
        require(size != 0 && size <= type(uint64).max, "exact positive uint64 object size");
        proof.endpoint.byteSize = uint64(size);
        _scopedBundlePackageProof(item, file, proof);
        proof.endpoint.firstDataPath = safeVm.parseJsonBytes(json, ".firstDataPath");
        proof.endpoint.lastDataPath = safeVm.parseJsonBytes(json, ".lastDataPath");
        proof.endpoint.firstChunkRaw = safeVm.parseJsonBytes(json, ".firstChunkRaw");
        proof.endpoint.lastChunkRaw = safeVm.parseJsonBytes(json, ".lastChunkRaw");
        _scopedBundleEndpointShape(proof.endpoint.firstDataPath, proof.endpoint.firstChunkRaw);
        _scopedBundleEndpointShape(proof.endpoint.lastDataPath, proof.endpoint.lastChunkRaw);
        return _scopedBundleExternal(item, proof.endpoint);
    }

    function _scopedBundlePackageProof(
        ScopedBundleItems.Item memory item,
        ScopedBundleReference.PackageFile memory file,
        AuthorityScopedPackageProof memory proof
    ) private pure {
        require(
            item.kind == ScopedBundleItems.Kind.EXTERNAL_REFERENCE
                && item.role == keccak256("RUNNABLE_PACKAGE_MEMBER") && item.algorithm == 2
                && item.canonicalizationId == keccak256("RAW_BYTES") && item.digest.length == 32
                && item.byteSize == file.byteSize
                && keccak256(item.digest) == keccak256(abi.encodePacked(file.sha256Digest))
                && keccak256(bytes(item.uri)) == keccak256(bytes(file.path))
                && proof.packageIndex == item.sourceIndex
                && keccak256(bytes(proof.path)) == keccak256(bytes(file.path))
                && proof.endpoint.byteSize == file.byteSize && file.byteSize != 0
                && proof.endpoint.sha256Digest == file.sha256Digest,
            "fresh endpoint object is this exact declared uncompressed member"
        );
    }

    function _scopedBundleProofPath(string memory path) private pure {
        bytes memory raw = bytes(path);
        require(raw.length != 0 && raw.length <= 4096, "bounded explicit proof file path");
        for (uint256 i; i < raw.length; ++i) {
            require(raw[i] != 0, "proof path has no NUL byte");
        }
    }

    function _scopedBundleJSONHash(string memory json, string memory key)
        private
        pure
        returns (bytes32 value)
    {
        bytes memory raw = safeVm.parseJsonBytes(json, key);
        require(raw.length == 32, "exact 32-byte object identity");
        value = abi.decode(raw, (bytes32));
        require(value != 0, "nonzero object identity");
    }

    function _scopedBundleEndpointShape(bytes memory path, bytes memory chunk) private pure {
        // Match StreamArweaveObjectInclusion's finite native path/chunk envelope. Its real
        // verifier still authenticates interval, root and first/last endpoint placement.
        require(
            path.length >= 64 && path.length <= 64 + 96 * 64 && (path.length - 64) % 96 == 0
                && chunk.length != 0 && chunk.length <= 262144,
            "bounded native endpoint proof"
        );
    }

    function coverAuthorityScopedRetainedBytes(
        ScopedBundleItems.Item calldata item,
        bytes calldata raw,
        AuthorityScopedEndpoint memory endpoint
    ) external returns (ScopedBundle.Proof memory) {
        require(msg.sender == address(this), "fixture self-call only");
        require(
            (item.algorithm == 1 || item.algorithm == 2) && item.digest.length == 32
                && raw.length != 0 && raw.length <= type(uint64).max
                && keccak256(item.digest)
                    == keccak256(
                        abi.encodePacked(item.algorithm == 1 ? keccak256(raw) : sha256(raw))
                    ) && (item.byteSize == 0 || item.byteSize == raw.length),
            "complete retained bytes match the original occurrence"
        );
        if (item.kind == ScopedBundleItems.Kind.CONTRACT_RUNTIME) {
            require(keccak256(raw) == item.source.codehash, "actual original runtime bytes");
        }
        if (raw.length < 262144) {
            require(
                endpoint.contentHash == 0 && endpoint.sha256Digest == 0
                    && endpoint.arweaveDataRoot == 0 && endpoint.byteSize == 0
                    && endpoint.firstDataPath.length == 0 && endpoint.lastDataPath.length == 0
                    && endpoint.firstChunkRaw.length == 0 && endpoint.lastChunkRaw.length == 0
            );
            endpoint.contentHash = keccak256(raw);
            endpoint.sha256Digest = sha256(raw);
            endpoint.byteSize = uint64(raw.length);
            endpoint.arweaveDataRoot = sha256(
                abi.encodePacked(
                    sha256(abi.encodePacked(endpoint.sha256Digest)),
                    sha256(abi.encode(uint256(raw.length)))
                )
            );
            endpoint.firstDataPath = abi.encode(endpoint.sha256Digest, uint256(raw.length));
            endpoint.lastDataPath = endpoint.firstDataPath;
            endpoint.firstChunkRaw = raw;
            endpoint.lastChunkRaw = raw;
        } else {
            require(
                endpoint.contentHash == keccak256(raw) && endpoint.sha256Digest == sha256(raw)
                    && endpoint.byteSize == raw.length,
                "large native proof and full source bytes identify the same object"
            );
        }
        return _scopedBundleExternal(item, endpoint);
    }

    function _scopedBundleExternal(
        ScopedBundleItems.Item memory item,
        AuthorityScopedEndpoint memory endpoint
    ) private returns (ScopedBundle.Proof memory) {
        require(
            endpoint.contentHash != 0 && endpoint.sha256Digest != 0 && endpoint.arweaveDataRoot != 0
                && endpoint.byteSize != 0 && item.digest.length == 32
                && (item.byteSize == 0 || item.byteSize == endpoint.byteSize)
                && (item.algorithm == 1 || item.algorithm == 2)
                && keccak256(item.digest)
                    == keccak256(
                        abi.encodePacked(
                            item.algorithm == 1 ? endpoint.contentHash : endpoint.sha256Digest
                        )
                    )
        );
        ScopedBundleExternal.ObjectIdentity memory object;
        object.artistId = assemblyArtistId;
        object.schemaId = item.schemaId != 0
            ? item.schemaId
            : keccak256("PRESERVATION_ORIGINAL_BYTES_DECLARATION");
        object.canonicalizationId = item.canonicalizationId;
        object.contentHash = endpoint.contentHash;
        object.sha256Digest = endpoint.sha256Digest;
        object.arweaveDataRoot = endpoint.arweaveDataRoot;
        object.byteSize = endpoint.byteSize;
        object.formatId =
            item.formatId != 0 ? item.formatId : keccak256("DECLARED_APPLICATION_OCTET_STREAM");
        object.formatCatalogId = item.kind != ScopedBundleItems.Kind.REGISTERED_DOCUMENT
            && item.catalogId != 0
            ? item.catalogId
            : keccak256("PRESERVATION_BYTE_OBJECT_DECLARATION");
        object.formatCatalogHash = item.kind != ScopedBundleItems.Kind.REGISTERED_DOCUMENT
            && item.catalogId != 0
            ? item.catalogHash
            : keccak256(
                "declared object metadata; interpretation comes from actual original source"
            );
        ScopedBundleExternal.Coverage memory covered = _assemblyCoverExternal(
            object,
            endpoint.firstDataPath,
            endpoint.lastDataPath,
            endpoint.firstChunkRaw,
            endpoint.lastChunkRaw
        );
        require(
            covered.objectHash != 0 && covered.coverageHash != 0 && covered.firstReceiptHash != 0
                && covered.secondReceiptHash != 0 && covered.firstFixityHash != 0
                && covered.secondFixityHash != 0
        );
        return ScopedBundle.Proof(1, covered.coverageHash, covered.objectHash);
    }

    function _scopedBundleHost(
        AuthorityScopedPublication memory publication,
        AuthorityScopedReference memory referenceResult,
        AuthorityScopedInventory memory inventoryResult
    ) private view returns (ScopedBundleHost host) {
        require(
            publication.graph.preparedChildren == 7
                && publication.graph.children[5] == inventoryResult.host
                && publication.graph.children[4] == referenceResult.host
                && inventoryResult.planId == inventoryResult.evidence.inventory.planId
                && inventoryResult.planId != 0
                && inventoryResult.evidence.inventory.originals.referenceRenderRecordHash
                    == referenceResult.recordHash
                && inventoryResult.evidence.inventory.originals.snapshotRecordHash
                    == publication.snapshot.recordHash
                && inventoryResult.evidence.inventory.originals.rootRecordHash
                    == publication.rootHash
                && keccak256(abi.encode(publication.scope))
                    == keccak256(abi.encode(inventoryResult.evidence.scope))
                && keccak256(abi.encode(referenceResult.publication.scope))
                    == keccak256(abi.encode(publication.scope))
        );
        for (uint256 i; i < 7; ++i) {
            require(
                publication.graph.children[i].code.length != 0
                    && publication.graph.children[i].codehash == publication.graph.codeHashes[i]
            );
        }
        host = ScopedBundleHost(publication.graph.children[6]);
        require(
            host.renderCriticalInventory() == inventoryResult.host
                && host.inventoryCodeHash() == inventoryResult.host.codehash
                && host.core() == address(assemblyCore)
                && host.metadataHost() == address(assemblyMetadata)
                && host.externalCoverage() == address(assemblyExternal)
                && host.artifactCoverage() == address(assemblyArtifact)
                && host.INVENTORY_PROFILE()
                    == ScopedBundleAuthority.SCOPED_PRESERVATION_POLICY_INVENTORY_PROFILE
                && host.scopedPreservationPolicyBundleArchiveProfile()
                    == keccak256(
                        "6529STREAM_CURRENT_AUTHORITY_SCOPED_PRESERVATION_POLICY_BUNDLE_IMMUTABLE_STOP_AGGREGATE_V1"
                    ) && host.supportsInterface(type(ScopedBundleInterface).interfaceId)
                && !host.progress(inventoryResult.planId).complete
                && host.progress(inventoryResult.planId).itemCount == 0,
            "fresh genuine scoped-preservation-policy bundle child"
        );
        _scopedBundleCurrent(publication, inventoryResult);
    }

    function _scopedBundleCurrent(
        AuthorityScopedPublication memory publication,
        AuthorityScopedInventory memory inventoryResult
    ) private view {
        ScopedBundleInventory inventory = ScopedBundleInventory(inventoryResult.host);
        require(
            keccak256(abi.encode(inventory.requireCurrent(publication.scope)))
                    == keccak256(abi.encode(inventoryResult.evidence))
                && inventoryResult.authorityCaptureHash
                    == keccak256(abi.encode(inventory.authoritySelection(inventoryResult.planId))),
            "same genuine current inventory and complete authority capture"
        );
        inventory.requireFullDefinitionBytes(inventoryResult.planId);
    }

    function _scopedBundleInputs(
        bytes[] memory retainedBytes,
        AuthorityScopedPackageProof[] memory packageProofs,
        AuthorityScopedEndpoint[] memory largeByteProofs
    ) private pure {
        for (uint256 i; i < retainedBytes.length; ++i) {
            require(retainedBytes[i].length != 0);
            for (uint256 j; j < i; ++j) {
                require(keccak256(retainedBytes[i]) != keccak256(retainedBytes[j]));
            }
        }
        for (uint256 i; i < packageProofs.length; ++i) {
            if (i != 0) require(packageProofs[i - 1].packageIndex < packageProofs[i].packageIndex);
        }
        for (uint256 i; i < largeByteProofs.length; ++i) {
            require(largeByteProofs[i].byteSize >= 262144 && largeByteProofs[i].contentHash != 0);
            for (uint256 j; j < i; ++j) {
                require(largeByteProofs[i].contentHash != largeByteProofs[j].contentHash);
            }
        }
    }

    function _scopedBundleBytes(ScopedBundleItems.Item memory item, bytes[] memory retainedBytes)
        private
        pure
        returns (uint256)
    {
        require((item.algorithm == 1 || item.algorithm == 2) && item.digest.length == 32);
        bytes32 expected = abi.decode(item.digest, (bytes32));
        for (uint256 i; i < retainedBytes.length; ++i) {
            if (
                (item.algorithm == 1 ? keccak256(retainedBytes[i]) : sha256(retainedBytes[i]))
                    == expected
            ) {
                require(item.byteSize == 0 || item.byteSize == retainedBytes[i].length);
                return i;
            }
        }
        revert("missing complete exact source bytes; inventory digests are not byte witnesses");
    }

    function _scopedBundleLarge(bytes memory raw, AuthorityScopedEndpoint[] memory largeByteProofs)
        private
        pure
        returns (uint256)
    {
        bytes32 expected = keccak256(raw);
        for (uint256 i; i < largeByteProofs.length; ++i) {
            if (largeByteProofs[i].contentHash == expected) {
                require(
                    largeByteProofs[i].byteSize == raw.length
                        && largeByteProofs[i].sha256Digest == sha256(raw)
                );
                return i;
            }
        }
        revert("large source requires fresh native endpoint proof for exact complete bytes");
    }

    function _scopedBundleFile(
        ScopedBundleItems.Item memory item,
        ScopedBundleReference.PackageFile memory file,
        AuthorityScopedReference memory referenceResult
    ) private pure {
        require(
            item.source == referenceResult.host && item.sourceRecord == referenceResult.recordHash
                && item.algorithm == 2 && item.canonicalizationId == keccak256("RAW_BYTES")
                && item.byteSize == file.byteSize && item.digest.length == 32
                && keccak256(item.digest) == keccak256(abi.encodePacked(file.sha256Digest))
                && keccak256(bytes(item.uri)) == keccak256(bytes(file.path))
                && (file.byteSize != 0 || file.sha256Digest == sha256(bytes("")))
        );
    }

    function _scopedBundleConsume(
        ScopedBundleHost host,
        AuthorityScopedInventory memory inventoryResult,
        AuthorityScopedBundle memory result
    ) private {
        bytes32 id = inventoryResult.planId;
        ScopedBundleInventory inventory = ScopedBundleInventory(inventoryResult.host);
        require(inventoryResult.rows.length == inventoryResult.evidence.inventory.segmentCount);
        host.beginCoverage(id);
        uint64 consumed;
        bytes32 segmentChain;
        for (uint64 i; i < inventoryResult.rows.length; ++i) {
            ScopedBundleItems.Segment memory segment = inventory.inventorySegment(id, i);
            ScopedBundleItems.Item[] memory rows = inventoryResult.rows[i];
            require(rows.length == segment.itemCount && rows.length == result.proofs[i].length);
            bytes32[] memory next = new bytes32[](rows.length);
            bytes32 chain;
            for (uint256 j = rows.length; j != 0; --j) {
                next[j - 1] = chain;
                chain = ScopedBundleChains.link(
                    segment.key, segment.itemCount, uint64(j - 1), rows[j - 1], chain
                );
            }
            require(chain == segment.firstLink, "every occurrence matches original stored segment");
            segmentChain = ScopedBundleChains.append(segmentChain, i, segment);
            if (rows.length == 0) host.coverEmptySegment(id);
            for (uint256 j; j < rows.length; ++j) {
                host.coverNext(id, rows[j], next[j], result.proofs[i][j]);
                (ScopedBundleItems.Item memory saved, ScopedBundle.Admission memory admission) =
                    host.admittedItem(id, consumed);
                require(
                    keccak256(abi.encode(saved)) == keccak256(abi.encode(rows[j]))
                        && keccak256(abi.encode(admission.proof))
                            == keccak256(abi.encode(result.proofs[i][j]))
                        && admission.originalBundleHash != 0
                );
                bytes32 originHash;
                if (rows[j].kind == ScopedBundleItems.Kind.STATE_BUNDLE) {
                    originHash = ScopedBundleOrigins.recordOriginHash(
                        inventory.artistArchiveOrigin(id, ScopedBundleChains.itemHash(rows[j]))
                    );
                    require(originHash != 0);
                }
                require(host.admittedOriginHash(id, consumed) == originHash);
                ++consumed;
            }
        }
        ScopedBundle.Progress memory progress = host.progress(id);
        require(
            progress.complete && progress.itemCount == consumed
                && consumed == inventoryResult.evidence.inventory.itemCount
                && progress.segmentIndex == inventoryResult.rows.length
                && progress.segmentItemIndex == 0 && progress.nextLink == 0
                && progress.segmentChainHash == segmentChain
                && segmentChain == inventoryResult.evidence.inventory.segmentChainHash
        );
        result.evidence = host.requireCoverage(
            inventoryResult.evidence.scope,
            id,
            inventoryResult.evidence.inventory.renderCriticalEvidenceHash
        );
        require(
            result.evidence.coverage.inventoryPlan == id
                && result.evidence.coverage.itemCount == consumed
                && result.evidence.coverage.bundleCoverageHash != 0
                && result.evidence.coverage.renderCriticalEvidenceHash
                    == inventoryResult.evidence.inventory.renderCriticalEvidenceHash
                && result.evidence.coverage.evidenceChainHash == progress.evidenceChainHash
                && keccak256(abi.encode(result.evidence))
                    == keccak256(abi.encode(host.requireFullCurrentCoverage(id))),
            "complete real bundle and full per-entry current diagnostics agree"
        );
        result.refreshId = host.beginRefresh(id);
        ScopedBundle.Refresh memory refresh = host.refresh(result.refreshId);
        require(
            refresh.complete && refresh.nextIndex == consumed
                && refresh.environmentHash == progress.environmentHash
                && refresh.currentObservationChain != 0,
            "all proofs preceded one unchanged current bundle environment"
        );
    }
}
