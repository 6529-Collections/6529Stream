// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamArtistAttestationTypes as Attest
} from "../../interfaces/stream/artist/IStreamArtistAttestationWriter.sol";
import {
    StreamArtistOnboardingTypes as T
} from "../../interfaces/stream/artist/StreamArtistOnboardingTypes.sol";
import "../../interfaces/stream/artist/IStreamArtistFinalityBinding.sol";
import "../../interfaces/stream/artist/IStreamArtistPrimaryScopeFacts.sol";
import "../../interfaces/stream/artist/IStreamArtistRoyaltyScopeFacts.sol";
import "../../interfaces/stream/core/IStreamCorePointers.sol";
import "../../interfaces/stream/mint/IStreamMintReads.sol";
import "../../interfaces/stream/parameters/IStreamGasParameterHost.sol";
import "../../interfaces/stream/metadata/IStreamCollectionManifestReads.sol";
import "../../interfaces/stream/finality/IStreamArtworkFinalityRegistry.sol";
import "../../interfaces/stream/finality/IStreamFinalityDeploymentBindings.sol";
import "../../interfaces/stream/finality/IStreamFinalityDiscoverySources.sol";
import "../finality/StreamFinalityNativeProviderReads.sol";

// Selector projections of actual owner APIs. Absence/malformed replies fail; no fallback hash.
interface IStreamArtistSnapshotConfiguration {
    function nativeConfiguration()
        external
        view
        returns (StreamFinalityNativeProviderReads.Config memory);
}

/// @notice Exact admitted subject owners for original AA-ATTEST kinds 1 through 6.
/// @dev Signatures bind the original subject ID/hash; descriptors only locate those facts.
library StreamArtistAttestationSubjectReads {
    error AttestationSubjectRead(address owner, bytes4 selector);
    error AttestationSubjectGas(uint256 available);

    function read(
        T.SuiteConfiguration memory s,
        T.Attestation memory p,
        Attest.Subject memory q,
        bool scoped
    ) public view returns (Attest.Fact memory f, bytes memory evidence) {
        if (p.subjectKind == 0 || p.subjectKind > 6 || p.schemaId == 0) {
            revert T.UnsupportedProfile();
        }
        if (
            !scoped
                && (q.scopeType != 0
                    || q.tokenId != 0
                    || q.scopeId != 0
                    || q.resolver != address(0))
        ) {
            revert T.InvalidRecord();
        }
        if (scoped && p.subjectKind != 4 && p.subjectKind != 6) revert T.UnsupportedProfile();
        if (p.subjectKind == 1) {
            (f, evidence) = _snapshot(s, p);
        } else if (p.subjectKind == 2 || p.subjectKind == 3) {
            address owner = _selected(s.core, keccak256("COLLECTION_METADATA"), address(0));
            if (
                abi.decode(
                            _fixed(
                                s,
                                owner,
                                abi.encodeCall(IStreamCollectionManifestReads.core, ()),
                                32
                            ),
                            (address)
                        ) != s.core || p.subjectId != bytes32(p.collectionId)
            ) revert T.InvalidRecord();
            bytes memory input = p.subjectKind == 2
                ? abi.encodeCall(
                    IStreamCollectionManifestReads.scriptManifestHash, (p.collectionId)
                )
                : abi.encodeCall(IStreamCollectionManifestReads.mediaManifestHash, (p.collectionId));
            bytes32 hash = abi.decode(_fixed(s, owner, input, 32), (bytes32));
            f = Attest.Fact(owner, owner.codehash, bytes32(p.collectionId), hash);
            evidence = abi.encode(p.subjectKind, f);
        } else if (p.subjectKind == 4) {
            (f, evidence) = _finality(s, p, q, scoped);
        } else if (p.subjectKind == 5) {
            if (address(IStreamMintReads(s.mintManager).core()) != s.core) {
                revert T.ComponentChanged(s.mintManager);
            }
            (bool exists,) = IStreamMintReads(s.mintManager).phase(p.collectionId, p.subjectId);
            if (!exists || p.subjectId == 0) revert T.InvalidRecord();
            f = Attest.Fact(
                s.mintManager,
                s.mintManager.codehash,
                p.subjectId,
                abi.decode(
                    _fixed(
                        s,
                        s.mintManager,
                        abi.encodeCall(
                            IStreamMintReads.phasePolicyHash, (p.collectionId, p.subjectId)
                        ),
                        32
                    ),
                    (bytes32)
                )
            );
            evidence = abi.encode(f);
        } else {
            (f, evidence) = _economics(s, p, q, scoped);
        }
        if (
            f.owner.code.length == 0 || f.ownerCodeHash != f.owner.codehash || f.stateHash == 0
                || f.subjectId != p.subjectId || f.stateHash != p.subjectStateHash
        ) revert T.InvalidRecord();
    }

    function _snapshot(T.SuiteConfiguration memory s, T.Attestation memory p)
        private
        view
        returns (Attest.Fact memory f, bytes memory evidence)
    {
        address registry = _registry(s);
        IStreamFinalityDeploymentBindings finality = IStreamFinalityDeploymentBindings(registry);
        address provider = finality.scopeEvidenceProvider();
        if (
            provider.code.length == 0
                || provider.codehash != finality.scopeEvidenceProviderCodeHash()
        ) {
            revert T.ComponentChanged(provider);
        }
        address host = IStreamFinalityDiscoverySources(provider).snapshotHost();
        StreamFinalityNativeProviderReads.Config memory c = abi.decode(
            _fixed(
                s,
                provider,
                abi.encodeCall(IStreamArtistSnapshotConfiguration.nativeConfiguration, ()),
                1568
            ),
            (StreamFinalityNativeProviderReads.Config)
        );
        if (
            c.chainId != block.chainid || c.targets[0] != s.core || c.targets[2] != s.metadata
                || c.targets[11] != s.registry || c.targets[12] != registry || c.targets[8] != host
                || host.code.length == 0 || c.codeHashes[8] == 0 || host.codehash != c.codeHashes[8]
        ) {
            revert T.ComponentChanged(host);
        }
        IStreamCollectionSnapshots owner = IStreamCollectionSnapshots(host);
        if (owner.core() != s.core || owner.metadataRouter() != s.metadata) {
            revert T.ComponentChanged(host);
        }
        StreamSnapshotTypes.Receipt memory r = abi.decode(
            _fixed(
                s,
                host,
                abi.encodeCall(IStreamCollectionSnapshots.currentSnapshot, (p.collectionId)),
                672
            ),
            (StreamSnapshotTypes.Receipt)
        );
        if (
            r.collectionId != p.collectionId || r.snapshotId == 0 || r.snapshotId != p.subjectId
                || r.recordHash == 0 || r.revision == 0 || r.manifestHash == 0
                || r.manifestHash
                    != abi.decode(
                        _fixed(
                            s,
                            host,
                            abi.encodeCall(
                                IStreamCollectionSnapshots.latestSnapshotHash, (p.collectionId)
                            ),
                            32
                        ),
                        (bytes32)
                    )
                || r.manifestHash
                    != abi.decode(
                        _fixed(
                            s,
                            host,
                            abi.encodeCall(
                                IStreamCollectionSnapshots.snapshotHash,
                                (p.collectionId, r.snapshotId)
                            ),
                            32
                        ),
                        (bytes32)
                    )
        ) revert T.InvalidRecord();
        f = Attest.Fact(host, c.codeHashes[8], r.snapshotId, r.manifestHash);
        evidence = abi.encode(registry, provider, provider.codehash, r);
    }

    function _finality(
        T.SuiteConfiguration memory s,
        T.Attestation memory p,
        Attest.Subject memory q,
        bool scoped
    ) private view returns (Attest.Fact memory f, bytes memory evidence) {
        address registry = _registry(s);
        if (q.resolver != address(0) || q.scopeType > 4) revert T.UnsupportedProfile();
        StreamFinalityScope memory scope = StreamFinalityScope(
            StreamFinalityScopeType(q.scopeType), p.collectionId, q.tokenId, q.scopeId
        );
        if (
            (q.scopeType == 0 && (q.tokenId != 0 || q.scopeId != 0))
                || (q.scopeType == 1 && (q.tokenId == 0 || q.scopeId != 0))
                || (q.scopeType >= 2 && (q.tokenId != 0 || q.scopeId == 0))
        ) revert T.InvalidRecord();
        bytes32 key = scoped
            ? keccak256(
                abi.encode(keccak256("6529STREAM_ARTIST_FINALITY_ATTESTATION_SUBJECT_V1"), scope)
            )
            : bytes32(p.collectionId);
        bytes32 hash;
        if (q.scopeType == 0) {
            StreamCollectionFinalityRecord memory r =
                IStreamArtworkFinalityRegistry(registry).collectionFinalityRecord(p.collectionId);
            if (!r.finalized || r.finalizedAt == 0 || r.finalizedAt > block.timestamp) {
                revert T.InvalidRecord();
            }
            hash = r.finalityRecordHash;
            evidence = abi.encode(scope, r);
        } else {
            StreamScopedFinalityRecord memory r =
                IStreamArtworkFinalityRegistry(registry).artworkScopeFinalityRecord(scope);
            if (
                !r.finalized || r.finalizedAt == 0 || r.finalizedAt > block.timestamp
                    || keccak256(abi.encode(r.scope)) != keccak256(abi.encode(scope))
            ) revert T.InvalidRecord();
            hash = r.finalityRecordHash;
            evidence = abi.encode(r);
        }
        f = Attest.Fact(registry, registry.codehash, key, hash);
    }

    function _economics(
        T.SuiteConfiguration memory s,
        T.Attestation memory p,
        Attest.Subject memory q,
        bool scoped
    ) private view returns (Attest.Fact memory f, bytes memory evidence) {
        address resolver = scoped ? q.resolver : address(uint160(uint256(p.subjectId)));
        if (resolver != s.primaryResolver && resolver != s.royaltyResolver) {
            revert T.ComponentChanged(resolver);
        }
        if (!scoped && bytes32(uint256(uint160(resolver))) != p.subjectId) {
            revert T.InvalidRecord();
        }
        if (
            scoped
                && (q.scopeType > 2
                    || q.tokenId != 0
                    || (q.scopeType == 0 && q.scopeId != 0)
                    || (q.scopeType == 1 && uint256(q.scopeId) != p.collectionId)
                    || (q.scopeType == 2 && q.scopeId == 0))
        ) revert T.InvalidRecord();
        T.AssignmentFact memory a;
        if (resolver == s.primaryResolver) {
            if (IStreamRevenueResolver(resolver).core() != s.core) {
                revert T.ComponentChanged(resolver);
            }
            IStreamRevenueResolver.ResolvedPrimaryAssignment memory r = scoped
                ? IStreamArtistPrimaryScopeFacts(resolver)
                    .primaryEconomicsFacts(p.collectionId, q.scopeType, uint256(q.scopeId))
                : IStreamRevenueResolver(resolver)
                    .resolvePrimaryAssignment(p.collectionId, 0, s.primaryRevenueClass);
            if (!r.exists) revert T.InvalidRecord();
            a = T.AssignmentFact(
                resolver, s.primaryRevenueClass, r.scope, r.scopeId, r.assignmentHash
            );
            evidence = abi.encode(r);
        } else {
            _selected(s.core, keccak256("ROYALTY_RESOLVER"), resolver);
            IStreamRoyaltyResolver.RoyaltyConfig memory config;
            if (scoped) {
                (a, config) = IStreamArtistRoyaltyScopeFacts(resolver)
                    .royaltyEconomicsFacts(p.collectionId, q.scopeType, uint256(q.scopeId));
            } else {
                (a, config,) = IStreamArtistRoyaltyScopeFacts(resolver)
                    .resolveRoyaltyAssignment(p.collectionId, 0);
            }
            if (
                !config.configured || a.resolver != resolver
                    || a.revenueClass != keccak256("ROYALTY_ERC2981")
            ) revert T.InvalidRecord();
            evidence = abi.encode(a, config);
        }
        if (scoped && (a.scope != q.scopeType || a.scopeId != uint256(q.scopeId))) {
            revert T.InvalidRecord();
        }
        bytes32 key = scoped
            ? keccak256(
                abi.encode(
                    keccak256("6529STREAM_ARTIST_ECONOMICS_ATTESTATION_SUBJECT_V1"),
                    p.collectionId,
                    resolver,
                    a.revenueClass,
                    a.scope,
                    a.scopeId
                )
            )
            : p.subjectId;
        f = Attest.Fact(resolver, resolver.codehash, key, a.assignmentHash);
    }

    function _fixed(T.SuiteConfiguration memory s, address target, bytes memory input, uint256 size)
        private
        view
        returns (bytes memory result)
    {
        (uint256 cap,, uint8 failure, uint64 revision) = IStreamGasParameterHost(s.registry)
            .gasParameterInfo(keccak256("6529STREAM_GGP_ARTIST_RECORD_PUBLICATION_READ_GAS"));
        if (cap == 0 || cap > type(uint256).max / 2 || failure != 2 || revision == 0) {
            revert T.InvalidBinding();
        }
        result = new bytes(size);
        uint256 available = gasleft();
        if (available <= 105000) revert AttestationSubjectGas(available);
        uint256 forwarded = available - 105000;
        if (cap < forwarded) forwarded = cap;
        bool ok;
        uint256 actual;
        assembly ("memory-safe") {
            ok := staticcall(forwarded, target, add(input, 32), mload(input), add(result, 32), size)
            actual := returndatasize()
        }
        if (!ok || actual != size) revert AttestationSubjectRead(target, bytes4(input));
    }

    function _registry(T.SuiteConfiguration memory s) private view returns (address r) {
        r = IStreamArtistFinalityBinding(s.registry).finalityRegistry();
        if (
            r.code.length == 0
                || r.codehash != IStreamArtistFinalityBinding(s.registry).finalityRegistryCodeHash()
        ) revert T.ComponentChanged(r);
    }

    function _selected(address core, bytes32 kind, address expected)
        private
        view
        returns (address target)
    {
        bytes32 hash;
        (target, hash,,,,,,,,) = IStreamCorePointers(core).getSatellitePointer(kind);
        if (
            target.code.length == 0 || hash == 0 || target.codehash != hash
                || (expected != address(0) && target != expected)
        ) revert T.ComponentChanged(target);
    }
}
