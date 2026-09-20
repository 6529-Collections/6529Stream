// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamFinalityPreservationPolicySnapshotReadsV1 as Collection
} from "../../../smart-contracts/domains/finality/StreamFinalityPreservationPolicySnapshotReadsV1.sol";
import {
    StreamFinalityScopedPreservationPolicySnapshotReadsV1 as Scoped
} from "../../../smart-contracts/domains/finality/StreamFinalityScopedPreservationPolicySnapshotReadsV1.sol";
import {
    StreamPreservationPolicySnapshotTypesV1 as C
} from "../../../smart-contracts/interfaces/stream/metadata/StreamPreservationPolicySnapshotTypesV1.sol";
import {
    StreamScopedPreservationPolicySnapshotTypesV1 as S
} from "../../../smart-contracts/interfaces/stream/metadata/StreamScopedPreservationPolicySnapshotTypesV1.sol";
import {
    IStreamPreservationPolicySnapshotPublicationV1 as CI
} from "../../../smart-contracts/interfaces/stream/metadata/IStreamPreservationPolicySnapshotPublicationV1.sol";
import {
    IStreamScopedPreservationPolicySnapshotPublicationV1 as SI
} from "../../../smart-contracts/interfaces/stream/metadata/IStreamScopedPreservationPolicySnapshotPublicationV1.sol";
import {
    StreamPreservationPolicySnapshotFamiliesV2 as Families
} from "../../../smart-contracts/domains/records/StreamPreservationPolicySnapshotFamiliesV2.sol";
import {
    StreamPreservationTokenProducerProfilesV1 as Producers
} from "../../../smart-contracts/interfaces/stream/finality/StreamPreservationTokenProducerProfilesV1.sol";
import {
    StreamPreservationPolicySnapshotSourceReadsV1 as CollectionSources
} from "../../../smart-contracts/domains/records/StreamPreservationPolicySnapshotSourceReadsV1.sol";
import {
    StreamScopedPreservationPolicySnapshotSourceReadsV1 as ScopedSources
} from "../../../smart-contracts/domains/records/StreamScopedPreservationPolicySnapshotSourceReadsV1.sol";
import {
    StreamMetadataSubjects
} from "../../../smart-contracts/domains/metadata/StreamMetadataSubjects.sol";
import {
    StreamFinalityScope,
    StreamFinalityScopeType
} from "../../../smart-contracts/interfaces/stream/finality/StreamArtworkFinalityTypes.sol";
import {
    StreamFinalitySnapshotEvidence
} from "../../../smart-contracts/interfaces/stream/finality/StreamFinalitySnapshotTypes.sol";

interface SnapshotFamilyVm {
    function warp(uint256) external;
    function expectRevert(bytes calldata) external;
    function readFile(string calldata) external view returns (string memory);
}

/// @dev Exact read-table boundary, not a snapshot writer, Core, Router, or current-stack ceremony.
contract SnapshotFamilyReadTable {
    mapping(bytes32 => bytes) private _answers;
    mapping(bytes32 => bool) private _known;

    function set(bytes memory input, bytes memory output) external {
        _known[keccak256(input)] = true;
        _answers[keccak256(input)] = output;
    }

    fallback(bytes calldata input) external returns (bytes memory) {
        require(_known[keccak256(input)], "unknown boundary call");
        return _answers[keccak256(input)];
    }
}

/// @notice Executes real family dispatch and original/current receipt validators over explicit typed
/// read boundaries. No producer, governance, STATIC ceremony, native runtime, or gas claim follows.
contract StreamPreservationPolicySnapshotFamiliesV2Test {
    SnapshotFamilyVm private constant vm =
        SnapshotFamilyVm(address(uint160(uint256(keccak256("hevm cheat code")))));
    SnapshotFamilyReadTable private host;

    function testCollectionOriginalDefaultRetainsOriginalEvidenceDomain() public {
        (Collection.Dependencies memory d, C.Publication memory p, C.Receipt memory r) =
            _collection(false);
        Collection.Evidence memory e = Collection.requireCurrent(d, p.scope, r.recordHash, 1);
        require(e.receipt.recordHash == r.recordHash && !e.locked);
        bytes32 input = e.inputHash;
        e.inputHash = 0;
        require(
            input
                == keccak256(
                    abi.encode(
                        keccak256("6529STREAM_FINALITY_PRESERVATION_POLICY_SNAPSHOT_INPUT_V1"),
                        d.chainId,
                        d.core,
                        d.metadata,
                        d.snapshots,
                        d.snapshotsCodeHash,
                        p.scope,
                        e
                    )
                )
        );
    }

    function testCollectionV2AuthenticatesCompleteOriginalReceiptAndCurrentness() public {
        (Collection.Dependencies memory d, C.Publication memory p, C.Receipt memory r) =
            _collection(true);
        (C.Publication memory saved, C.Receipt memory receipt) =
            Collection.original(d, p.scope, r.recordHash, 1, Producers.FAMILY_PROFILE);
        require(keccak256(abi.encode(saved, receipt)) == keccak256(abi.encode(p, r)));
        Collection.Evidence memory e =
            Collection.requireCurrent(d, p.scope, r.recordHash, 1, Producers.FAMILY_PROFILE);
        require(e.receipt.recordHash == r.recordHash && e.contentRootRecord == p.contentRootRecord);
        bytes32 input = e.inputHash;
        e.inputHash = 0;
        require(
            input
                == keccak256(
                    abi.encode(
                        keccak256("6529STREAM_FINALITY_PRESERVATION_POLICY_SNAPSHOT_INPUT_V2"),
                        d.chainId,
                        d.core,
                        d.metadata,
                        d.snapshots,
                        d.snapshotsCodeHash,
                        p.scope,
                        e
                    )
                )
        );
    }

    function testCollectionDefaultDoesNotAutodetectV2() public {
        (Collection.Dependencies memory d, C.Publication memory p, C.Receipt memory r) =
            _collection(true);
        vm.expectRevert(abi.encodeWithSelector(Collection.InvalidPolicySnapshotEvidence.selector));
        Collection.requireCurrent(d, p.scope, r.recordHash, 1);
    }

    function testCollectionV2RejectsOriginalHostProfile() public {
        (Collection.Dependencies memory d, C.Publication memory p, C.Receipt memory r) =
            _collection(false);
        vm.expectRevert(abi.encodeWithSelector(Collection.InvalidPolicySnapshotEvidence.selector));
        Collection.original(d, p.scope, r.recordHash, 1, Producers.FAMILY_PROFILE);
    }

    function testCollectionV2RejectsOriginalDefinitionsEvenWithRecomputedRecord() public {
        (Collection.Dependencies memory d, C.Publication memory p, C.Receipt memory r) =
            _collection(true);
        r.schemaHash = Families.hashes(Producers.ORIGINAL_PROFILE, false)[0];
        r = _saveCollection(d, p, r, Producers.FAMILY_PROFILE);
        vm.expectRevert(abi.encodeWithSelector(Collection.InvalidPolicySnapshotEvidence.selector));
        Collection.original(d, p.scope, r.recordHash, 1, Producers.FAMILY_PROFILE);
    }

    function testCollectionChangedCurrentReceiptDoesNotRelabelHistoricalOriginal() public {
        (Collection.Dependencies memory d, C.Publication memory p, C.Receipt memory r) =
            _collection(true);
        C.Receipt memory changed = abi.decode(abi.encode(r), (C.Receipt));
        changed.sourceHash = keccak256("drift");
        host.set(
            abi.encodeCall(CI.requireCurrent, (p.scope, r.recordHash, uint64(1))),
            abi.encode(changed)
        );
        vm.expectRevert(abi.encodeWithSelector(Collection.InvalidPolicySnapshotEvidence.selector));
        Collection.requireCurrent(d, p.scope, r.recordHash, 1, Producers.FAMILY_PROFILE);
        (, C.Receipt memory retained) =
            Collection.original(d, p.scope, r.recordHash, 1, Producers.FAMILY_PROFILE);
        require(keccak256(abi.encode(retained)) == keccak256(abi.encode(r)));
    }

    function testCollectionV2LockMustNameExactReceipt() public {
        (Collection.Dependencies memory d, C.Publication memory p, C.Receipt memory r) =
            _collection(true);
        host.set(
            abi.encodeCall(CI.snapshotLock, (p.scope)),
            abi.encode(C.Lock(r.recordHash, 1, keccak256("action"), 100))
        );
        require(
            Collection.requireLocked(d, p.scope, r.recordHash, 1, Producers.FAMILY_PROFILE).locked
        );
        host.set(
            abi.encodeCall(CI.snapshotLock, (p.scope)),
            abi.encode(C.Lock(keccak256("other"), 1, keccak256("action"), 100))
        );
        vm.expectRevert(abi.encodeWithSelector(Collection.InvalidPolicySnapshotEvidence.selector));
        Collection.requireLocked(d, p.scope, r.recordHash, 1, Producers.FAMILY_PROFILE);
    }

    function testScopedOriginalDefaultRetainsOriginalRecord() public {
        (Scoped.Dependencies memory d, S.Publication memory p, S.Receipt memory r) =
            _scoped(false, StreamFinalityScopeType.TOKEN);
        (, S.Receipt memory retained) = Scoped.original(d, p.scope, r.recordHash, 1);
        require(keccak256(abi.encode(retained)) == keccak256(abi.encode(r)));
        require(Scoped.requireCurrent(d, p.scope, r.recordHash, 1).recordHash == r.recordHash);
    }

    function testScopedV2AcceptsExactTokenReleaseSeasonAndV2EvidenceDomain() public {
        StreamFinalityScopeType[3] memory kinds = [
            StreamFinalityScopeType.TOKEN,
            StreamFinalityScopeType.RELEASE,
            StreamFinalityScopeType.SEASON
        ];
        for (uint256 i; i < 3; ++i) {
            (Scoped.Dependencies memory d, S.Publication memory p, S.Receipt memory r) =
                _scoped(true, kinds[i]);
            (, S.Receipt memory retained) =
                Scoped.original(d, p.scope, r.recordHash, 1, Producers.FAMILY_PROFILE);
            require(keccak256(abi.encode(retained)) == keccak256(abi.encode(r)));
            StreamFinalitySnapshotEvidence memory e =
                Scoped.requireCurrent(d, p.scope, r.recordHash, 1, Producers.FAMILY_PROFILE);
            bytes32 input = e.inputHash;
            e.inputHash = 0;
            require(
                input
                    == keccak256(
                        abi.encode(
                            keccak256(
                                "6529STREAM_FINALITY_SCOPED_PRESERVATION_POLICY_SNAPSHOT_INPUT_V2"
                            ),
                            d.chainId,
                            d.core,
                            d.metadata,
                            d.router,
                            d.snapshots,
                            d.snapshotsCodeHash,
                            p.scope,
                            e
                        )
                    )
            );
        }
    }

    function testScopedDefaultDoesNotAutodetectV2() public {
        (Scoped.Dependencies memory d, S.Publication memory p, S.Receipt memory r) =
            _scoped(true, StreamFinalityScopeType.TOKEN);
        vm.expectRevert(
            abi.encodeWithSelector(Scoped.InvalidScopedPreservationPolicySnapshotEvidence.selector)
        );
        Scoped.original(d, p.scope, r.recordHash, 1);
    }

    function testScopedV2RejectsOriginalHostProfile() public {
        (Scoped.Dependencies memory d, S.Publication memory p, S.Receipt memory r) =
            _scoped(false, StreamFinalityScopeType.TOKEN);
        vm.expectRevert(
            abi.encodeWithSelector(Scoped.InvalidScopedPreservationPolicySnapshotEvidence.selector)
        );
        Scoped.requireCurrent(d, p.scope, r.recordHash, 1, Producers.FAMILY_PROFILE);
    }

    function testScopedV2RejectsOriginalDefinitionsEvenWithRecomputedRecord() public {
        (Scoped.Dependencies memory d, S.Publication memory p, S.Receipt memory r) =
            _scoped(true, StreamFinalityScopeType.TOKEN);
        r.canonicalizationHash = Families.hashes(Producers.ORIGINAL_PROFILE, true)[2];
        r = _saveScoped(d, p, r, Producers.FAMILY_PROFILE);
        vm.expectRevert(
            abi.encodeWithSelector(Scoped.InvalidScopedPreservationPolicySnapshotEvidence.selector)
        );
        Scoped.original(d, p.scope, r.recordHash, 1, Producers.FAMILY_PROFILE);
    }

    function testScopedV2RejectsViewAndCollection() public {
        (Scoped.Dependencies memory d, S.Publication memory p, S.Receipt memory r) =
            _scoped(true, StreamFinalityScopeType.TOKEN);
        p.scope = StreamFinalityScope(StreamFinalityScopeType.COLLECTION, 1, 0, 0);
        vm.expectRevert(
            abi.encodeWithSelector(Scoped.InvalidScopedPreservationPolicySnapshotEvidence.selector)
        );
        Scoped.original(d, p.scope, r.recordHash, 1, Producers.FAMILY_PROFILE);
        p.scope.scopeType = StreamFinalityScopeType.VIEW;
        vm.expectRevert(
            abi.encodeWithSelector(Scoped.InvalidScopedPreservationPolicySnapshotEvidence.selector)
        );
        Scoped.original(d, p.scope, r.recordHash, 1, Producers.FAMILY_PROFILE);
    }

    function testScopedV2RejectsDifferentPinnedOriginalRouter() public {
        (Scoped.Dependencies memory d, S.Publication memory p, S.Receipt memory r) =
            _scoped(true, StreamFinalityScopeType.TOKEN);
        d.router = address(new SnapshotFamilyReadTable());
        d.routerCodeHash = d.router.codehash;
        vm.expectRevert(
            abi.encodeWithSelector(Scoped.InvalidScopedPreservationPolicySnapshotEvidence.selector)
        );
        Scoped.original(d, p.scope, r.recordHash, 1, Producers.FAMILY_PROFILE);
    }

    function testUnknownFamilyFailsBeforeReadingSources() public {
        Collection.Dependencies memory d;
        StreamFinalityScope memory scope;
        vm.expectRevert(abi.encodeWithSelector(Families.InvalidSnapshotFamily.selector));
        Collection.original(d, scope, bytes32(uint256(1)), 1, Producers.CURRENT_ARTIST_PROFILE);
        C.Dependencies memory c;
        vm.expectRevert(abi.encodeWithSelector(C.InvalidPolicySnapshot.selector));
        CollectionSources.bindings(c, Producers.CURRENT_ARTIST_PROFILE);
        S.Dependencies memory s;
        vm.expectRevert(abi.encodeWithSelector(S.InvalidScopedPolicySnapshot.selector));
        ScopedSources.bindings(s, keccak256("VIEW"));
    }

    function testSourceHashesKeepV1DomainsAndExplicitV2Domains() public {
        C.Dependencies memory c;
        C.Source memory cf;
        c.chainId = block.chainid;
        S.Dependencies memory s;
        S.Source memory sf;
        s.chainId = block.chainid;
        bytes32 oldC = CollectionSources.sourceHash(c, cf);
        require(
            oldC
                == keccak256(
                    abi.encode(
                        keccak256("6529STREAM_PRESERVATION_POLICY_SNAPSHOT_SOURCES_V1"),
                        c.chainId,
                        address(this),
                        c.targets,
                        c.codeHashes,
                        cf
                    )
                )
        );
        require(
            CollectionSources.sourceHash(c, cf, Producers.FAMILY_PROFILE)
                == keccak256(
                    abi.encode(
                        keccak256("6529STREAM_PRESERVATION_POLICY_SNAPSHOT_SOURCES_V2"),
                        c.chainId,
                        address(this),
                        c.targets,
                        c.codeHashes,
                        cf
                    )
                )
        );
        require(oldC != CollectionSources.sourceHash(c, cf, Producers.FAMILY_PROFILE));
        require(
            ScopedSources.sourceHash(s, sf)
                == keccak256(
                    abi.encode(
                        keccak256("6529STREAM_SCOPED_PRESERVATION_POLICY_SNAPSHOT_SOURCES_V1"),
                        s.chainId,
                        address(this),
                        s.targets,
                        s.codeHashes,
                        sf
                    )
                )
        );
        require(
            ScopedSources.sourceHash(s, sf, Producers.FAMILY_PROFILE)
                == keccak256(
                    abi.encode(
                        keccak256("6529STREAM_SCOPED_PRESERVATION_POLICY_SNAPSHOT_SOURCES_V2"),
                        s.chainId,
                        address(this),
                        s.targets,
                        s.codeHashes,
                        sf
                    )
                )
        );
    }

    function testExactGovernedV2FilesMatchDefinitionsAndV1FilesRemainUnchanged() public view {
        for (uint256 scope; scope < 2; ++scope) {
            string memory stem = scope == 0
                ? "preservation-policy-collection-snapshot"
                : "scoped-preservation-policy-snapshot";
            string[3] memory extensions = [string("schema"), "profile", "abi"];
            for (uint256 version = 1; version <= 2; ++version) {
                bytes32 family =
                    version == 1 ? Producers.ORIGINAL_PROFILE : Producers.FAMILY_PROFILE;
                bytes32[3] memory hashes = Families.hashes(family, scope == 1);
                uint256[3] memory sizes = Families.lengths(family, scope == 1);
                for (uint256 i; i < 3; ++i) {
                    bytes memory raw = bytes(
                        vm.readFile(
                            string.concat(
                                "docs/schemas/preservation/",
                                stem,
                                version == 1 ? "-v1." : "-v2.",
                                extensions[i],
                                ".json"
                            )
                        )
                    );
                    require(keccak256(raw) == hashes[i] && raw.length == sizes[i]);
                }
            }
        }
    }

    function _collection(bool v2)
        private
        returns (Collection.Dependencies memory d, C.Publication memory p, C.Receipt memory r)
    {
        vm.warp(100);
        host = new SnapshotFamilyReadTable();
        d = Collection.Dependencies(
            address(new SnapshotFamilyReadTable()),
            address(new SnapshotFamilyReadTable()),
            address(host),
            0,
            0,
            address(host).codehash,
            block.chainid,
            1000000,
            12000000
        );
        d.coreCodeHash = d.core.codehash;
        d.metadataCodeHash = d.metadata.codehash;
        bytes32 family = v2 ? Producers.FAMILY_PROFILE : Producers.ORIGINAL_PROFILE;
        host.set(abi.encodeCall(CI.core, ()), abi.encode(d.core));
        host.set(abi.encodeCall(CI.metadataHost, ()), abi.encode(d.metadata));
        host.set(
            abi.encodeWithSignature("supportsInterface(bytes4)", type(CI).interfaceId),
            abi.encode(true)
        );
        host.set(
            abi.encodeCall(CI.preservationPolicySnapshotProfile, ()),
            abi.encode(Families.profile(family, false))
        );
        p.scope = StreamFinalityScope(StreamFinalityScopeType.COLLECTION, 1, 0, 0);
        p.snapshotId = keccak256("snapshot");
        p.outputManifestRecord = keccak256("outputs");
        p.contentRootRecord = keccak256("root");
        p.coordinatorInventoryPlan = keccak256("inventory");
        p.expectedSourceHash = keccak256("source");
        p.manifestURI = "ipfs://snapshot";
        p.effectiveAt = 99;
        p.reasonHash = keccak256("reason");
        r.scopeSubject = StreamMetadataSubjects.scopeSubject(d.chainId, d.core, p.scope);
        r.revision = 1;
        r.manifestHash = keccak256("manifest");
        r.manifestBytes = 32;
        r.sourceHash = p.expectedSourceHash;
        r.publisher = address(this);
        r.authorizationClass = 7;
        r.grantRevision = 1;
        r.displayAuthorizationClass = 8;
        r.displayGrantRevision = 1;
        r.recordedAt = 100;
        bytes32[3] memory hashes = Families.hashes(family, false);
        r.schemaHash = hashes[0];
        r.profileHash = hashes[1];
        r.canonicalizationHash = hashes[2];
        r = _saveCollection(d, p, r, family);
    }

    function _saveCollection(
        Collection.Dependencies memory d,
        C.Publication memory p,
        C.Receipt memory r,
        bytes32 family
    ) private returns (C.Receipt memory) {
        r.recordHash = 0;
        r.chainHash = 0;
        r.recordHash = keccak256(
            abi.encode(
                Families.recordDomain(family, false),
                d.chainId,
                d.snapshots,
                d.core,
                d.metadata,
                p,
                r
            )
        );
        r.chainHash = keccak256("authenticated fixture chain");
        host.set(abi.encodeCall(CI.snapshotRecord, (r.recordHash)), abi.encode(p, r));
        host.set(
            abi.encodeCall(CI.requireCurrent, (p.scope, r.recordHash, r.revision)), abi.encode(r)
        );
        C.Lock memory empty;
        host.set(abi.encodeCall(CI.snapshotLock, (p.scope)), abi.encode(empty));
        return r;
    }

    function _scoped(bool v2, StreamFinalityScopeType kind)
        private
        returns (Scoped.Dependencies memory d, S.Publication memory p, S.Receipt memory r)
    {
        vm.warp(100);
        host = new SnapshotFamilyReadTable();
        d.core = address(new SnapshotFamilyReadTable());
        d.metadata = address(new SnapshotFamilyReadTable());
        d.router = address(new SnapshotFamilyReadTable());
        d.snapshots = address(host);
        d.coreCodeHash = d.core.codehash;
        d.metadataCodeHash = d.metadata.codehash;
        d.routerCodeHash = d.router.codehash;
        d.snapshotsCodeHash = address(host).codehash;
        d.chainId = block.chainid;
        d.readGas = 1000000;
        d.validationGas = 12000000;
        bytes32 family = v2 ? Producers.FAMILY_PROFILE : Producers.ORIGINAL_PROFILE;
        host.set(abi.encodeCall(SI.core, ()), abi.encode(d.core));
        host.set(abi.encodeCall(SI.metadataHost, ()), abi.encode(d.metadata));
        host.set(
            abi.encodeWithSignature("supportsInterface(bytes4)", type(SI).interfaceId),
            abi.encode(true)
        );
        host.set(
            abi.encodeCall(SI.scopedPreservationPolicySnapshotProfile, ()),
            abi.encode(Families.profile(family, true))
        );
        S.Dependencies memory source;
        source.chainId = d.chainId;
        source.targets[0] = d.core;
        source.targets[1] = d.metadata;
        source.targets[4] = d.router;
        source.codeHashes[0] = d.coreCodeHash;
        source.codeHashes[1] = d.metadataCodeHash;
        source.codeHashes[4] = d.routerCodeHash;
        host.set(abi.encodeCall(SI.dependencies, ()), abi.encode(source));
        p.scope = StreamFinalityScope(
            kind,
            1,
            kind == StreamFinalityScopeType.TOKEN ? 1 : 0,
            kind == StreamFinalityScopeType.TOKEN ? bytes32(0) : keccak256("scope")
        );
        p.snapshotId = keccak256("snapshot");
        p.outputManifestRecord = keccak256("output");
        p.coordinatorInventoryPlan = keccak256("inventory");
        p.expectedSourceHash = keccak256("source");
        p.manifestURI = "ipfs://snapshot";
        p.effectiveAt = 99;
        p.reasonHash = keccak256("reason");
        r.scopeSubject = StreamMetadataSubjects.scopeSubject(d.chainId, d.core, p.scope);
        r.revision = 1;
        r.manifestHash = keccak256("manifest");
        r.manifestBytes = 32;
        r.sourceHash = p.expectedSourceHash;
        r.publisher = address(this);
        r.authorizationClass = 7;
        r.grantRevision = 1;
        r.displayAuthorizationClass = 8;
        r.displayGrantRevision = 1;
        r.recordedAt = 100;
        bytes32[3] memory hashes = Families.hashes(family, true);
        r.schemaHash = hashes[0];
        r.profileHash = hashes[1];
        r.canonicalizationHash = hashes[2];
        r = _saveScoped(d, p, r, family);
    }

    function _saveScoped(
        Scoped.Dependencies memory d,
        S.Publication memory p,
        S.Receipt memory r,
        bytes32 family
    ) private returns (S.Receipt memory) {
        r.recordHash = 0;
        r.chainHash = 0;
        r.recordHash = keccak256(
            abi.encode(
                Families.recordDomain(family, true),
                d.chainId,
                d.snapshots,
                d.core,
                d.metadata,
                p,
                r
            )
        );
        r.chainHash = keccak256("authenticated fixture chain");
        host.set(abi.encodeCall(SI.snapshotRecord, (r.recordHash)), abi.encode(p, r));
        host.set(
            abi.encodeCall(SI.requireCurrent, (p.scope, r.recordHash, r.revision)), abi.encode(r)
        );
        S.Lock memory empty;
        host.set(abi.encodeCall(SI.snapshotLock, (p.scope)), abi.encode(empty));
        return r;
    }
}
