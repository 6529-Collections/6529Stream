// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    ScopedPolicyReferenceFixtureV2
} from "../preservation/StreamScopedPolicyReferencePublicationV2.t.sol";
import {
    StreamFinalityScopedPolicyProviderReadsV2 as P
} from "../../../smart-contracts/domains/finality/StreamFinalityScopedPolicyProviderReadsV2.sol";
import {
    StreamFinalityScopedPolicyProviderMetadataV2 as M
} from "../../../smart-contracts/domains/finality/StreamFinalityScopedPolicyProviderMetadataV2.sol";
import {
    StreamFinalityScopedPolicyMetadataFactsV2 as Local
} from "../../../smart-contracts/domains/finality/StreamFinalityScopedPolicyMetadataFactsV2.sol";
import {
    StreamFinalityScopedPolicyStaticComponentsV2 as Static
} from "../../../smart-contracts/domains/finality/StreamFinalityScopedPolicyStaticComponentsV2.sol";
import {
    StreamFinalityScopedPolicyProviderOperationsV2 as Ops
} from "../../../smart-contracts/domains/finality/StreamFinalityScopedPolicyProviderOperationsV2.sol";
import {
    StreamFinalityScopedPolicySanctionReviewV2 as Review
} from "../../../smart-contracts/domains/finality/StreamFinalityScopedPolicySanctionReviewV2.sol";
import {
    StreamFinalityScopedPolicySnapshotReadsV2 as SnapReads
} from "../../../smart-contracts/domains/finality/StreamFinalityScopedPolicySnapshotReadsV2.sol";
import {
    StreamScopedPolicySnapshotTypesV2 as S
} from "../../../smart-contracts/interfaces/stream/metadata/StreamScopedPolicySnapshotTypesV2.sol";
import {
    IStreamScopedPolicySnapshotPublicationV2 as Snap
} from "../../../smart-contracts/interfaces/stream/metadata/IStreamScopedPolicySnapshotPublicationV2.sol";
import {
    IStreamScopedPolicyContentRootPublicationV2 as Root
} from "../../../smart-contracts/interfaces/stream/metadata/IStreamScopedPolicyContentRootPublicationV2.sol";
import {
    IStreamScopedPolicyOutputManifestV2 as Outputs
} from "../../../smart-contracts/interfaces/stream/finality/IStreamScopedPolicyOutputManifestV2.sol";
import {
    IStreamScopedPolicyContentCheckpointV2 as Content
} from "../../../smart-contracts/interfaces/stream/finality/IStreamScopedPolicyContentCheckpointV2.sol";
import {
    StreamScopedPolicyOutputSchemasV2 as OutputDefs
} from "../../../smart-contracts/domains/finality/StreamScopedPolicyOutputSchemasV2.sol";
import {
    StreamScopedPolicyReferenceTypesV2 as R
} from "../../../smart-contracts/interfaces/stream/preservation/StreamScopedPolicyReferenceTypesV2.sol";
import {
    IStreamScopedPolicyReferencePublicationV2 as Ref
} from "../../../smart-contracts/interfaces/stream/preservation/IStreamScopedPolicyReferencePublicationV2.sol";
import {
    StreamScopedPolicyRenderCriticalInventoryV2 as Inventory
} from "../../../smart-contracts/domains/preservation/StreamScopedPolicyRenderCriticalInventoryV2.sol";
import {
    StreamScopedPolicyBundleArchiveCoverageV2 as Bundle
} from "../../../smart-contracts/domains/preservation/StreamScopedPolicyBundleArchiveCoverageV2.sol";
import {
    IStreamScopedPolicyRenderCriticalInventoryV2 as InventoryI
} from "../../../smart-contracts/interfaces/stream/preservation/IStreamScopedPolicyRenderCriticalInventoryV2.sol";
import {
    IStreamScopedPolicyBundleArchiveCoverageV2 as BundleI
} from "../../../smart-contracts/interfaces/stream/preservation/IStreamScopedPolicyBundleArchiveCoverageV2.sol";
import {
    StreamScopedPolicyRenderCriticalTypesV2 as C
} from "../../../smart-contracts/interfaces/stream/preservation/StreamScopedPolicyRenderCriticalTypesV2.sol";
import {
    StreamScopedPolicyBundleArchiveTypesV2 as B
} from "../../../smart-contracts/interfaces/stream/preservation/StreamScopedPolicyBundleArchiveTypesV2.sol";
import {
    StreamBundleArchiveTypes as Archive
} from "../../../smart-contracts/interfaces/stream/preservation/StreamBundleArchiveTypes.sol";
import {
    StreamPreservationInventoryTypes as I
} from "../../../smart-contracts/interfaces/stream/preservation/StreamPreservationInventoryTypes.sol";
import {
    StreamRenderCriticalSourceTypes as D
} from "../../../smart-contracts/interfaces/stream/preservation/StreamRenderCriticalSourceTypes.sol";
import {
    StreamFinalityScope,
    StreamFinalityScopeType,
    StreamFinalityDomains as Domains,
    StreamFinalityComponentExpectation,
    StreamFinalityComponentState,
    StreamScopedCoreFinalityFacts,
    StreamCoreFinalityScopeQuery
} from "../../../smart-contracts/interfaces/stream/finality/StreamArtworkFinalityTypes.sol";
import {
    StreamScopedFinalityInputManifestTypes as Manifest
} from "../../../smart-contracts/interfaces/stream/finality/StreamScopedFinalityInputManifestTypes.sol";
import {
    IStreamCoreFinalityAdapter as CoreAdapter
} from "../../../smart-contracts/interfaces/stream/finality/IStreamCoreFinalityAdapter.sol";
import {
    IStreamFinalitySanctionReview as Sanction
} from "../../../smart-contracts/interfaces/stream/finality/IStreamFinalitySanctionReview.sol";
import {
    StreamFinalityNativeSanctionProfile as SanctionProfile
} from "../../../smart-contracts/domains/finality/StreamFinalityNativeSanctionProfile.sol";
import {
    StreamExternalArtifactTypes as E
} from "../../../smart-contracts/interfaces/stream/preservation/StreamExternalArtifactTypes.sol";
import {
    IStreamExternalArtifactCoverage as External
} from "../../../smart-contracts/interfaces/stream/preservation/IStreamExternalArtifactCoverage.sol";
import {
    IStreamExternalArtifactCurrentPair as Pair
} from "../../../smart-contracts/interfaces/stream/preservation/IStreamExternalArtifactCurrentPair.sol";
import {
    StreamReferenceRenderDefinitions as RefDefs
} from "../../../smart-contracts/domains/records/StreamReferenceRenderDefinitions.sol";
import {
    IStreamSchemaRegistry as Schema
} from "../../../smart-contracts/interfaces/stream/metadata/IStreamSchemaRegistry.sol";
import {
    IStreamStaticMetadataRouter as RouterStatic
} from "../../../smart-contracts/interfaces/stream/metadata/IStreamStaticMetadataRouter.sol";
import {
    StreamFinalityStaticComponentFacts as StaticFacts
} from "../../../smart-contracts/domains/finality/StreamFinalityStaticComponentFacts.sol";
import {
    StreamMetadataSubjects as Subjects
} from "../../../smart-contracts/domains/metadata/StreamMetadataSubjects.sol";
import {
    StreamFinalityRouterEvidence as RouterReads
} from "../../../smart-contracts/domains/finality/StreamFinalityRouterEvidence.sol";
import {
    StreamFinalityDescriptionReads as Descriptions
} from "../../../smart-contracts/domains/finality/StreamFinalityDescriptionReads.sol";

/// @dev Named late Registry/Core-adapter/Discovery/WORK/RIGHTS/conservation observation boundary.
/// It is not an admitted publication, selected record, independent component or finality registry.
contract ScopedPolicyProviderReadBoundaryV2 {
    mapping(bytes4 => bytes) private responses;

    function set(string calldata signature, bytes calldata value) external {
        responses[bytes4(keccak256(bytes(signature)))] = value;
    }

    fallback() external {
        bytes memory value = responses[msg.sig];
        require(value.length != 0, "missing typed late boundary");
        assembly ("memory-safe") { return(add(value, 32), mload(value)) }
    }
}

/// @dev Exercises linked workers in their consuming host context. Caller-supplied Config exists
/// only in this probe; production Config is constructor-owned by the fixed provider.
contract ScopedPolicyProviderWorkersProbeV2 {
    function root(M.Config calldata c, StreamFinalityScope calldata scope, bool current)
        external
        view
        returns (M.RootFacts memory)
    {
        return M.rootFacts(c, scope, current);
    }

    function snapshot(M.Config calldata c, StreamFinalityScope calldata scope)
        external
        view
        returns (bytes32)
    {
        return M.snapshot(c, scope);
    }

    function scopeManifest(M.Config calldata c, StreamFinalityScope calldata scope)
        external
        view
        returns (bool, bytes32)
    {
        return M.manifest(c, scope);
    }

    function staticFacts(P.Config calldata c, StreamFinalityScope calldata scope, bytes32 family)
        external
        view
        returns (bool, bytes32)
    {
        return Static.facts(c, scope, family);
    }

    function metadataFacts(P.Config calldata c, StreamFinalityScope calldata scope)
        external
        view
        returns (bool, bytes32)
    {
        return Local.facts(c, scope);
    }

    function pins(P.Config calldata c) external view {
        P.requirePins(c);
    }

    function statement(P.Config calldata c, StreamFinalityScope calldata scope)
        external
        view
        returns (Manifest.Statement memory)
    {
        return P.statement(c, scope, new StreamFinalityComponentExpectation[](0));
    }

    function review(P.Config calldata c, Manifest.Statement calldata s)
        external
        view
        returns (Sanction.ReviewFacts memory)
    {
        return Review.review(c, s);
    }

    function prepared(P.Config calldata c, StreamFinalityScope calldata scope) external view {
        Ops.prepared(
            c, scope, bytes32(uint256(1)), new StreamFinalityComponentExpectation[](0), false
        );
    }

    function independent(StreamFinalityComponentExpectation[] calldata entries)
        external
        pure
        returns (StreamFinalityComponentExpectation[] memory)
    {
        return P.independentComponents(entries);
    }
}

/// @notice Genuine full-policy source/checkpoint/output/Snapshot/Router root and reference feed
/// the new provider workers. Current source reads and original 23-word bindings are not mocked.
/// @dev Inherited Core identity, Artist/renderer/governance and archive observation boundaries
/// remain explicit. Inventory/bundle completion and Core adapter below are typed observations,
/// not staged complete preservation or finality. WORK/RIGHTS/conservation are deliberately absent:
/// local metadata cannot become frozen merely because the real snapshot is locked. No gas claim.
contract StreamFinalityScopedPolicyProviderWorkersV2Test is ScopedPolicyReferenceFixtureV2 {
    ScopedPolicyProviderWorkersProbeV2 private probe;
    P.Config private config;
    M.Config private metadataConfig;
    ScopedPolicyProviderReadBoundaryV2[22] private late;
    Inventory private inventory;
    Bundle private bundle;
    C.Evidence private evidence;
    B.BundleEvidence private coverage;
    StreamScopedCoreFinalityFacts private coreFacts;

    function _ready(uint8 terminalStatus, uint8 scopeKind) private {
        _reference(terminalStatus, scopeKind);
        _canonicalCaptures();
        if (referenceInput.observation.captures.length > 1) {
            _register(
                "6529STREAM_ARTIST_SANCTION_NATIVE_CAPTURES_V1",
                Schema.DocumentKind.CATALOG,
                SanctionProfile.document()
            );
        }
        _publishReference();
        probe = new ScopedPolicyProviderWorkersProbeV2();
        config.targets[0] = address(core);
        config.targets[1] = address(metadata);
        config.targets[2] = address(router);
        config.targets[3] = address(scopedMembership);
        config.targets[4] = address(schemas);
        config.targets[5] = address(snapshotStore);
        config.targets[6] = address(snapshotOutputs);
        config.targets[7] = address(snapshotContent);
        config.targets[8] = address(snapshotHost);
        config.targets[9] = address(referenceHost);
        config.targets[10] = address(scopedFactory);
        config.targets[11] = address(artist);
        config.targets[20] = address(snapshotCoverage);
        config.targets[21] = address(externalArchive);
        for (uint256 i = 12; i < 18; ++i) {
            late[i] = new ScopedPolicyProviderReadBoundaryV2();
            config.targets[i] = address(late[i]);
        }
        config.chainId = block.chainid;
        config.readGas = 2000000;
        config.componentSourceGas = 256000000;
        config.sourceGas = 512000000;
        _inventoryBoundary();
        for (uint256 i; i < 22; ++i) {
            config.codeHashes[i] = config.targets[i].codehash;
        }
        _lateAddress(12, "coreReads()", 0);
        _lateAddress(12, "metadataReads()", 1);
        _lateAddress(12, "coreFinalityAdapter()", 14);
        _lateAddress(13, "core()", 0);
        _lateAddress(13, "metadataHost()", 1);
        _lateAddress(14, "core()", 0);
        _lateAddress(14, "collectionMetadata()", 1);
        late[12].set("scopeEvidenceProvider()", abi.encode(address(probe)));
        late[13].set("scopeEvidenceProvider()", abi.encode(address(probe)));
        late[14].set("evidenceProvider()", abi.encode(address(probe)));
        metadataConfig = M.Config(
            SnapReads.Dependencies(
                address(core),
                address(metadata),
                address(router),
                address(snapshotHost),
                address(core).codehash,
                address(metadata).codehash,
                address(router).codehash,
                address(snapshotHost).codehash,
                block.chainid,
                2000000,
                256000000
            ),
            address(scopedMembership),
            address(scopedMembership).codehash
        );
        _statementBoundary();
        probe.pins(config);
    }

    function _lateAddress(uint256 from, string memory selector, uint256 to) private {
        late[from].set(selector, abi.encode(config.targets[to]));
    }

    function _inventoryBoundary() private {
        D.Dependencies memory d;
        uint256[12] memory indexes = [uint256(0), 1, 4, 5, 2, 8, 9, 15, 16, 17, 20, 21];
        for (uint256 i; i < 12; ++i) {
            d.targets[i] = config.targets[indexes[i]];
            d.codeHashes[i] = d.targets[i].codehash;
        }
        for (uint256 i; i < 5; ++i) {
            d.artistTargets[i] = address(artist);
            d.artistCodeHashes[i] = address(artist).codehash;
        }
        d.artistContentOwner = address(artist);
        d.artistContentOwnerCodeHash = address(artist).codehash;
        d.chainId = block.chainid;
        d.readGas = config.readGas;
        d.sourceGas = config.sourceGas;
        d.selectionGas = config.componentSourceGas;
        d.snapshotGas = config.componentSourceGas;
        d.referenceGas = config.sourceGas;
        inventory = new Inventory(d);
        config.targets[18] = address(inventory);
        config.inventoryDependencyHash = keccak256(abi.encode(d));
        Archive.Dependencies memory bd;
        bd.targets = [
            address(core),
            address(metadata),
            address(inventory),
            address(snapshotCoverage),
            address(externalArchive),
            address(artist)
        ];
        for (uint256 i; i < 6; ++i) {
            bd.codeHashes[i] = bd.targets[i].codehash;
        }
        bd.chainId = block.chainid;
        bd.readGas = config.readGas;
        bd.archiveGas = config.sourceGas;
        bundle = new Bundle(bd);
        config.targets[19] = address(bundle);
    }

    function _statementBoundary() private {
        R.Receipt memory r = referenceHost.currentReference(publication.scope);
        S.Receipt memory s = snapshotHost.currentSnapshot(publication.scope);
        evidence.scope = publication.scope;
        evidence.inventory = I.Evidence({
            planId: keccak256("explicit complete inventory boundary"),
            collectionId: publication.scope.collectionId,
            scopeSubject: s.scopeSubject,
            artistId: SNAPSHOT_ARTIST,
            sourceContextHash: keccak256("typed completed source context"),
            tokenInventoryHash: scopedMembership.requireScopeMembership(publication.scope)
            .membershipHash,
            tokenCount: uint64(
                scopedMembership.requireScopeMembership(publication.scope).tokenCount
            ),
            segmentCount: 1,
            itemCount: 1,
            segmentChainHash: keccak256("typed completed segment chain"),
            renderCriticalEvidenceHash: keccak256("typed completed inventory commitment"),
            originals: I.OriginalInputs(
                adoptedRoot,
                adoptedSnapshot,
                r.observation.recordHash,
                keccak256("typed intent"),
                0,
                keccak256("typed interview"),
                keccak256("typed rights"),
                keccak256("typed work")
            )
        });
        coverage = B.BundleEvidence(
            publication.scope,
            I.BundleEvidence(
                evidence.inventory.planId,
                evidence.inventory.renderCriticalEvidenceHash,
                1,
                keccak256("typed archive chain"),
                keccak256("typed complete bundle")
            )
        );
        _saveStatementBoundary();
        coreFacts.scopeExists = true;
        coreFacts.scopeType = uint8(publication.scope.scopeType);
        coreFacts.collectionId = publication.scope.collectionId;
        coreFacts.tokenId = publication.scope.tokenId;
        coreFacts.scopeId = publication.scope.scopeId;
        coreFacts.tokenMappingExists = publication.scope.scopeType == StreamFinalityScopeType.TOKEN;
        coreFacts.collectionSerial = 1;
        coreFacts.tokenLifecycle = Domains.TOKEN_LIFECYCLE_MINTED;
        coreFacts.collectionConfigHash = keccak256("typed original Core config");
        coreFacts.scopeManifestHash =
        scopedMembership.requireScopeMembership(publication.scope).scopeManifestHash;
        late[14].set(
            "scopedCoreFinalityFacts((uint8,uint256,uint256,bytes32))", abi.encode(coreFacts)
        );
    }

    function _saveStatementBoundary() private {
        snapshotVm.mockCall(
            address(inventory),
            abi.encodeCall(InventoryI.requireCurrent, (publication.scope)),
            abi.encode(evidence)
        );
        snapshotVm.mockCall(
            address(bundle),
            abi.encodeCall(
                BundleI.requireCoverage,
                (
                    publication.scope,
                    evidence.inventory.planId,
                    evidence.inventory.renderCriticalEvidenceHash
                )
            ),
            abi.encode(coverage)
        );
    }

    /// @dev Exact external object identities are retained in the real reference publication;
    /// external archival admission itself remains an explicitly mocked observation boundary.
    function _canonicalCaptures() private {
        for (uint256 i; i < referenceInput.observation.captures.length; ++i) {
            E.ObjectIdentity memory o = E.ObjectIdentity(
                SNAPSHOT_ARTIST,
                RefDefs.PNG_SCHEMA_ID,
                keccak256("RAW_BYTES"),
                keccak256(abi.encode("original rendered PNG", i)),
                referenceInput.observation.captures[i].repeatCaptureSha256[0],
                keccak256(abi.encode("original PNG data root", i)),
                55,
                keccak256("IANA:image/png"),
                RefDefs.FORMAT_CATALOG_ID,
                RefDefs.FORMAT_CATALOG_HASH
            );
            bytes32 object = keccak256(
                abi.encode(
                    keccak256("6529STREAM_EXTERNAL_OBJECT_V1"),
                    block.chainid,
                    address(externalArchive),
                    address(core),
                    o
                )
            );
            bytes32 cover = referenceInput.observation.captures[i].coverageHash;
            referenceInput.observation.captures[i].objectHash = object;
            _external(object, cover, o.sha256Digest, false);
            E.Coverage memory e = External(address(externalArchive)).coverage(cover);
            e.contentHash = o.contentHash;
            e.arweaveDataRoot = o.arweaveDataRoot;
            snapshotVm.mockCall(
                address(externalArchive), abi.encodeCall(External.coverage, (cover)), abi.encode(e)
            );
            snapshotVm.mockCall(
                address(externalArchive),
                abi.encodeCall(External.requireCoverage, (cover, SNAPSHOT_ARTIST, object)),
                abi.encode(e)
            );
            snapshotVm.mockCall(
                address(externalArchive),
                abi.encodeCall(External.objectIdentity, (object)),
                abi.encode(o)
            );
            E.CurrentPair memory pair = E.CurrentPair(
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
                abi.encodeCall(
                    Pair.currentReceiptPair,
                    (e.firstReceiptHash, e.secondReceiptHash, e.artistId, object)
                ),
                abi.encode(pair)
            );
        }
    }

    function _lockSnapshot() private {
        (bytes32 scope, bytes32 oldHash, bytes32 next) =
            snapshotHost.lockTransition(publication.scope);
        snapshotVm.mockCall(
            address(executor),
            abi.encodeWithSignature("currentAction()"),
            abi.encode(
                true, keccak256("worker exact class2 snapshot lock"), uint8(2), scope, oldHash, next
            )
        );
        vm.prank(address(executor));
        snapshotHost.lockSnapshot(publication.scope);
        require(snapshotHost.snapshotLock(publication.scope).recordHash == adoptedSnapshot);
    }

    function _history() private view returns (bytes32) {
        return keccak256(
            abi.encode(
                router.scopedContentRootRecord(adoptedRoot),
                router.scopedPolicyContentRootBinding(adoptedRoot),
                snapshotHost.snapshotPayload(adoptedSnapshot),
                referenceHost.referencePayload(
                    referenceHost.currentReference(publication.scope).observation.recordHash
                )
            )
        );
    }

    function testWorkerActualRootCurrentAndOriginalJoinCompletePolicySource() public {
        _ready(1, 2);
        M.RootFacts memory a = probe.root(metadataConfig, publication.scope, true);
        M.RootFacts memory b = probe.root(metadataConfig, publication.scope, false);
        require(keccak256(abi.encode(a)) == keccak256(abi.encode(b)));
        require(
            a.recordHash == adoptedRoot && a.snapshot.recordHash == adoptedSnapshot
                && abi.encode(a.binding).length == 736
                && a.source.sourceFactory == address(scopedFactory)
                && a.binding.factoryDependenciesHash
                    == keccak256(abi.encode(scopedFactory.dependencies()))
                && a.source.entropy.policies.length == 2 && a.source.membership.tokenCount == 2
        );
        R.SourceFacts memory original = referenceHost.referenceSource(
            referenceHost.currentReference(publication.scope).observation.recordHash
        );
        require(keccak256(abi.encode(a.source)) == keccak256(abi.encode(original.snapshotSource)));
        require(
            original.samples[0].entropy.terminal && !original.samples[0].entropy.finalized
                && original.samples[0].entropy.seed == 0
                && original.samples[0].terminalAdmissionHash != 0
        );
        require(
            original.samples[1].entropy.finalized && !original.samples[1].entropy.terminal
                && original.samples[1].terminalAdmissionHash == 0
        );
    }

    function testWorkerTokenSnapshotHashHasNoInventedScopeManifest() public {
        _ready(2, 1);
        require(
            probe.snapshot(metadataConfig, publication.scope)
                == snapshotHost.currentSnapshot(publication.scope).manifestHash
        );
        (bool present, bytes32 hash) = probe.scopeManifest(metadataConfig, publication.scope);
        require(!present && hash == 0);
        R.SourceFacts memory r = referenceHost.referenceSource(
            referenceHost.currentReference(publication.scope).observation.recordHash
        );
        require(
            r.samples[0].entropy.status == 2 && r.samples[0].entropy.terminal
                && !r.samples[0].entropy.finalized
        );
    }

    function testWorkerSeasonManifestRetainsActualMembershipDeclaration() public {
        _ready(1, 3);
        (bool present, bytes32 hash) = probe.scopeManifest(metadataConfig, publication.scope);
        require(
            present && hash != 0
                && hash
                    == scopedMembership.requireScopeMembership(publication.scope).scopeManifestHash
        );
        require(
            probe.snapshot(metadataConfig, publication.scope)
                == snapshotHost.currentSnapshot(publication.scope).manifestHash
        );
    }

    function testWorkerEveryBindingWordRejectsSubstitutionAndRestoresOriginal() public {
        _ready(1, 1);
        Root.Binding memory original = router.scopedPolicyContentRootBinding(adoptedRoot);
        bytes32 saved = _history();
        for (uint256 i; i < 23; ++i) {
            Root.Binding memory changed = abi.decode(abi.encode(original), (Root.Binding));
            assembly ("memory-safe") {
                let p := add(changed, mul(i, 32))
                mstore(p, xor(mload(p), 1))
            }
            snapshotVm.mockCall(
                address(router),
                abi.encodeCall(Root.scopedPolicyContentRootBinding, (adoptedRoot)),
                abi.encode(changed)
            );
            vm.expectRevert(abi.encodeWithSelector(M.InvalidScopedProviderMetadata.selector));
            probe.root(metadataConfig, publication.scope, false);
        }
        snapshotVm.mockCall(
            address(router),
            abi.encodeCall(Root.scopedPolicyContentRootBinding, (adoptedRoot)),
            abi.encode(original)
        );
        require(
            probe.root(metadataConfig, publication.scope, true).recordHash == adoptedRoot
                && _history() == saved
        );
    }

    function testWorkerWrongFullTokenScopeAndOldSnapshotProfileAreRejected() public {
        _ready(1, 1);
        StreamFinalityScope memory wrong = publication.scope;
        wrong.collectionId = 2;
        vm.expectRevert(
            abi.encodeWithSelector(
                RouterReads.RouterEvidenceRead.selector,
                address(snapshotHost),
                Snap.currentSnapshot.selector
            )
        );
        probe.root(metadataConfig, wrong, false);
        snapshotVm.mockCall(
            address(snapshotHost),
            abi.encodeCall(Snap.scopedPolicySnapshotProfile, ()),
            abi.encode(keccak256("old scoped snapshot profile"))
        );
        vm.expectRevert(abi.encodeWithSelector(M.InvalidScopedProviderMetadata.selector));
        probe.root(metadataConfig, publication.scope, false);
        snapshotVm.mockCall(
            address(snapshotHost),
            abi.encodeCall(Snap.scopedPolicySnapshotProfile, ()),
            abi.encode(keccak256("6529STREAM_SCOPED_POLICY_SNAPSHOT_V2"))
        );
        require(probe.root(metadataConfig, publication.scope, true).recordHash == adoptedRoot);
    }

    function testWorkerCurrentValidationFailureCannotEraseOriginalProjection() public {
        _ready(1, 1);
        bytes32 saved = _history();
        S.Receipt memory original = snapshotHost.currentSnapshot(publication.scope);
        S.Receipt memory changed = original;
        changed.sourceHash ^= bytes32(uint256(1));
        snapshotVm.mockCall(
            address(snapshotHost),
            abi.encodeCall(Snap.requireCurrent, (publication.scope, adoptedSnapshot, uint64(1))),
            abi.encode(changed)
        );
        vm.expectRevert(
            abi.encodeWithSelector(SnapReads.InvalidScopedPolicySnapshotEvidence.selector)
        );
        probe.root(metadataConfig, publication.scope, true);
        require(
            probe.root(metadataConfig, publication.scope, false).recordHash == adoptedRoot
                && _history() == saved
        );
        changed.sourceHash ^= bytes32(uint256(1));
        snapshotVm.mockCall(
            address(snapshotHost),
            abi.encodeCall(Snap.requireCurrent, (publication.scope, adoptedSnapshot, uint64(1))),
            abi.encode(changed)
        );
        require(probe.root(metadataConfig, publication.scope, true).recordHash == adoptedRoot);
    }

    function testWorkerStaticRequiresActualLocalSnapshotLockThenProjectsSixFamilies() public {
        _ready(1, 2);
        vm.expectRevert(
            abi.encodeWithSelector(SnapReads.InvalidScopedPolicySnapshotEvidence.selector)
        );
        probe.staticFacts(config, publication.scope, Domains.COMPONENT_RENDERER);
        _lockSnapshot();
        bytes32[6] memory families = [
            Domains.COMPONENT_RENDERER,
            Domains.COMPONENT_RENDER_CONTEXT,
            Domains.COMPONENT_DEPENDENCY_SOURCE,
            Domains.COMPONENT_SCRIPT_SOURCE,
            Domains.COMPONENT_MEDIA_MANIFEST,
            Domains.COMPONENT_METADATA_ROUTER
        ];
        bytes32[6] memory hashes;
        for (uint256 i; i < 6; ++i) {
            (bool frozen, bytes32 hash) = probe.staticFacts(config, publication.scope, families[i]);
            require(frozen && hash != 0);
            for (uint256 j; j < i; ++j) {
                require(hashes[j] != hash);
            }
            hashes[i] = hash;
        }
        bytes32 saved = _history();
        vm.expectRevert(
            abi.encodeWithSelector(
                StaticFacts.StaticComponentFamily.selector, keccak256("unknown family")
            )
        );
        probe.staticFacts(config, publication.scope, keccak256("unknown family"));
        require(_history() == saved);
    }

    function testWorkerMetadataScopeAndPinsCannotBeReplacedByLockedSnapshot() public {
        _ready(1, 1);
        _lockSnapshot();
        StreamFinalityScope memory wrong = publication.scope;
        wrong.scopeType = StreamFinalityScopeType.COLLECTION;
        wrong.tokenId = 0;
        vm.expectRevert(abi.encodeWithSelector(Local.NativeMetadataScope.selector));
        probe.metadataFacts(config, wrong);
        P.Config memory wrongConfig = config;
        wrongConfig.codeHashes[15] ^= bytes32(uint256(1));
        vm.expectRevert(abi.encodeWithSelector(Local.NativeMetadataSource.selector));
        probe.metadataFacts(wrongConfig, publication.scope);
        // No selected WORK/RIGHTS/conservation records were fabricated for this fixture.
        // Even its genuine locked snapshot cannot make that incomplete local family succeed.
        vm.expectRevert(
            abi.encodeWithSelector(
                Descriptions.DescriptionRead.selector,
                config.targets[15],
                bytes4(keccak256("core()"))
            )
        );
        probe.metadataFacts(config, publication.scope);
    }

    function testWorkerStatementRetainsActualOriginalHeadersAndCoreBoundary() public {
        _ready(1, 2);
        Manifest.Statement memory s = probe.statement(config, publication.scope);
        M.RootFacts memory f = probe.root(metadataConfig, publication.scope, false);
        require(
            s.inputs.rootRecordHash == adoptedRoot && s.inputs.snapshotRecordHash == adoptedSnapshot
                && s.inputs.referenceRenderRecordHash
                    == referenceHost.currentReference(publication.scope).observation.recordHash
                && s.snapshotManifestHash == f.snapshot.manifestHash
                && s.contentRoot == f.record.contentRoot
                && s.contentRootSchemaId == OutputDefs.LEAF_SCHEMA && s.leafCount == 2
                && s.entropyPolicy == 1 && s.postFreezePolicy == 1 && s.sanctionPolicy == 1
                && s.nonSanctionComponents.length == 0
        );
        require(
            s.coreFactsHash
                == keccak256(
                    bytes.concat(
                        abi.encode(
                            Domains.STREAM_SCOPED_CORE_FINALITY_FACTS_V1,
                            block.chainid,
                            address(core),
                            uint8(publication.scope.scopeType),
                            publication.scope.collectionId,
                            publication.scope.tokenId,
                            publication.scope.scopeId,
                            coreFacts.scopeExists
                        ),
                        abi.encode(
                            coreFacts.tokenMappingExists,
                            coreFacts.collectionSerial,
                            coreFacts.tokenLifecycle,
                            coreFacts.burned,
                            coreFacts.collectionStatus,
                            coreFacts.collectionSupplyMode,
                            coreFacts.collectionConfigHash,
                            coreFacts.scopeManifestHash
                        )
                    )
                )
        );
    }

    function testWorkerStatementRejectsCurrentOriginalReferenceSubstitution() public {
        _ready(1, 1);
        bytes32 original = evidence.inventory.originals.referenceRenderRecordHash;
        probe.statement(config, publication.scope);
        evidence.inventory.originals.referenceRenderRecordHash =
            keccak256("other genuine-looking reference");
        _saveStatementBoundary();
        vm.expectRevert(abi.encodeWithSelector(P.NativeProviderSource.selector));
        probe.statement(config, publication.scope);
        evidence.inventory.originals.referenceRenderRecordHash = original;
        _saveStatementBoundary();
        require(
            probe.statement(config, publication.scope).inputs.referenceRenderRecordHash == original
        );
    }

    function testWorkerProfileAndConstructorChildMismatchesHaveExactErrors() public {
        _ready(1, 1);
        snapshotVm.mockCall(
            address(inventory),
            abi.encodeCall(InventoryI.scopedPolicyInventoryProfile, ()),
            abi.encode(keccak256("old inventory profile"))
        );
        vm.expectRevert(
            abi.encodeWithSelector(P.NativeProviderDependency.selector, address(inventory))
        );
        probe.pins(config);
        snapshotVm.mockCall(
            address(inventory),
            abi.encodeCall(InventoryI.scopedPolicyInventoryProfile, ()),
            abi.encode(C.PROFILE)
        );
        probe.pins(config);
        snapshotVm.mockCall(
            address(snapshotOutputs),
            abi.encodeCall(Outputs.contentCheckpoint, ()),
            abi.encode(address(snapshotHost))
        );
        vm.expectRevert(
            abi.encodeWithSelector(P.NativeProviderDependency.selector, address(snapshotOutputs))
        );
        probe.pins(config);
        snapshotVm.mockCall(
            address(snapshotOutputs),
            abi.encodeCall(Outputs.contentCheckpoint, ()),
            abi.encode(address(snapshotContent))
        );
        probe.pins(config);
    }

    function testWorkerPreparedGuardRequiresExactOriginalRegistryCaller() public {
        _ready(1, 1);
        probe.statement(config, publication.scope);
        vm.expectRevert(abi.encodeWithSelector(Ops.ScopedProviderRegistryOnly.selector));
        probe.prepared(config, publication.scope);
        P.Config memory changed = config;
        changed.codeHashes[12] ^= bytes32(uint256(1));
        address registry = config.targets[12];
        vm.expectRevert(abi.encodeWithSelector(Ops.ScopedProviderRegistryOnly.selector));
        vm.prank(registry);
        probe.prepared(changed, publication.scope);
    }

    function testWorkerSanctionReviewUsesOrderedOriginalPngContentNotRecordHashes() public {
        _ready(1, 2);
        Manifest.Statement memory s = probe.statement(config, publication.scope);
        Sanction.ReviewFacts memory review = probe.review(config, s);
        require(
            review.schemaVersion == 1 && review.profile == 2 && review.contentRoot == s.contentRoot
                && review.mediaContentHashes.length == 0
                && review.referenceRenderContentHashes.length == 2
        );
        for (uint256 i; i < 2; ++i) {
            bytes32 object = referenceInput.observation.captures[i].objectHash;
            E.ObjectIdentity memory o = External(address(externalArchive)).objectIdentity(object);
            require(
                review.referenceRenderContentHashes[i] == o.contentHash
                    && review.referenceRenderContentHashes[i] != object
                    && review.referenceRenderContentHashes[i] != o.sha256Digest
            );
        }
        bytes32 first = referenceInput.observation.captures[0].objectHash;
        E.ObjectIdentity memory saved = External(address(externalArchive)).objectIdentity(first);
        E.ObjectIdentity memory changed = abi.decode(abi.encode(saved), (E.ObjectIdentity));
        changed.contentHash ^= bytes32(uint256(1));
        snapshotVm.mockCall(
            address(externalArchive),
            abi.encodeCall(External.objectIdentity, (first)),
            abi.encode(changed)
        );
        vm.expectRevert(abi.encodeWithSelector(Review.NativeReviewSource.selector));
        probe.review(config, s);
        snapshotVm.mockCall(
            address(externalArchive),
            abi.encodeCall(External.objectIdentity, (first)),
            abi.encode(saved)
        );
        require(keccak256(abi.encode(probe.review(config, s))) == keccak256(abi.encode(review)));
    }

    function testWorkerIndependentComponentsDoesNotCountSanctionTwice() public {
        StreamFinalityComponentExpectation[] memory rows =
            new StreamFinalityComponentExpectation[](10);
        for (uint256 i; i < 9; ++i) {
            rows[i].componentType = bytes32(i + 1);
        }
        rows[9].componentType = Domains.COMPONENT_ARTIST_SANCTION;
        probe = new ScopedPolicyProviderWorkersProbeV2();
        StreamFinalityComponentExpectation[] memory projected = probe.independent(rows);
        require(projected.length == 9);
        for (uint256 i; i < 9; ++i) {
            require(keccak256(abi.encode(projected[i])) == keccak256(abi.encode(rows[i])));
        }
        rows[8].componentType = Domains.COMPONENT_ARTIST_SANCTION;
        vm.expectRevert(abi.encodeWithSelector(P.NativeProviderSource.selector));
        probe.independent(rows);
    }
}
