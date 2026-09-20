// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "../../helpers/ScopedReferenceSnapshotFixture.sol";
import {
    StreamFinalityScopedProviderMetadata as Reader
} from "../../../smart-contracts/domains/finality/StreamFinalityScopedProviderMetadata.sol";
import {
    StreamFinalityScopedSnapshotReads as SnapshotReads
} from "../../../smart-contracts/domains/finality/StreamFinalityScopedSnapshotReads.sol";
import {
    IStreamScopedContentRootPublication as Root
} from "../../../smart-contracts/interfaces/stream/metadata/IStreamScopedContentRootPublication.sol";

contract ScopedProviderMetadataProbe {
    function snapshot(Reader.Config memory c, StreamFinalityScope memory scope)
        external
        view
        returns (bytes32)
    {
        return Reader.snapshot(c, scope);
    }

    function root(Reader.Config memory c, StreamFinalityScope memory scope)
        external
        view
        returns (bytes32, uint64, bytes32)
    {
        return Reader.root(c, scope);
    }

    function manifest(Reader.Config memory c, StreamFinalityScope memory scope)
        external
        view
        returns (bool, bytes32)
    {
        return Reader.manifest(c, scope);
    }
}

/// @notice Real scoped Snapshot/Metadata/Schema/Store/membership joins.
/// @dev Inherited Core/Artist/renderer/output/archive facts and the Router root below are
/// explicit typed boundaries. This is not actual Artist op17 or a combined-provider ceremony.
contract StreamFinalityScopedProviderMetadataTest is ScopedReferenceSnapshotFixture {
    ScopedProviderMetadataProbe private probe;
    Reader.Config private config;
    Root.Record private declaredRoot;

    function _ready(uint8 kind) private {
        _initialize(kind);
        bytes32 key = _publishSnapshot();
        Scoped.Receipt memory saved = host.currentSnapshot(publication.scope);
        Reader.Config memory c;
        c.snapshots = SnapshotReads.Dependencies(
            address(core),
            address(metadata),
            address(route),
            address(host),
            address(core).codehash,
            address(metadata).codehash,
            address(route).codehash,
            address(host).codehash,
            block.chainid,
            600000,
            10000000
        );
        c.membership = address(membership);
        c.membershipCodeHash = address(membership).codehash;
        config = c;
        probe = new ScopedProviderMetadataProbe();
        Root.Record memory root;
        root.publication.scope = publication.scope;
        root.publication.snapshotRecordHash = key;
        root.publication.snapshotRevision = saved.revision;
        root.snapshotHost = address(host);
        root.snapshotCodeHash = address(host).codehash;
        root.snapshotManifestHash = saved.manifestHash;
        root.snapshotSourceHash = saved.sourceHash;
        root.artistConsent = keccak256("explicit typed original op17 boundary");
        root.stateHash = keccak256("explicit typed signed family state");
        root.contentRoot = contentPlan.contentRoot;
        root.leafCount = contentPlan.tokenCount;
        declaredRoot = root;
        route.set(
            "scopedContentRootHead((uint8,uint256,uint256,bytes32))",
            abi.encode(keccak256("typed root head"))
        );
        route.set("scopedContentRootRecord(bytes32)", abi.encode(root));
        route.set(
            "scopedTokenContentRoot((uint8,uint256,uint256,bytes32))",
            abi.encode(root.contentRoot, root.leafCount, keccak256("leaf schema"))
        );
    }

    function _positive(uint8 kind) private {
        _ready(kind);
        Scoped.Receipt memory saved = host.currentSnapshot(publication.scope);
        require(probe.snapshot(config, publication.scope) == saved.manifestHash);
        (bytes32 value, uint64 count, bytes32 schema) = probe.root(config, publication.scope);
        require(
            value == contentPlan.contentRoot && count == contentPlan.tokenCount
                && schema == keccak256("leaf schema")
        );
        (bool published, bytes32 hash) = probe.manifest(config, publication.scope);
        StreamScopeMembershipFacts memory actual =
            membership.requireScopeMembership(publication.scope);
        if (kind == 1) {
            require(!published && hash == 0 && actual.tokenCount == 1);
        } else {
            require(published && hash == actual.scopeManifestHash && actual.sourceRecordHash != 0);
        }
    }

    function testReleaseOriginalSnapshotMembershipAndRoot() public {
        _positive(2);
    }

    function testSeasonOriginalSnapshotMembershipAndRoot() public {
        _positive(3);
    }

    function testTokenOriginalSnapshotAndIndependentIdentity() public {
        _positive(1);
    }

    function testSameIdDifferentScopeKindNeverAliases() public {
        _ready(2);
        StreamFinalityScope memory changed = publication.scope;
        changed.scopeType = StreamFinalityScopeType.SEASON;
        (bool snapshotOk,) =
            address(probe).staticcall(abi.encodeCall(probe.snapshot, (config, changed)));
        (bool rootOk,) = address(probe).staticcall(abi.encodeCall(probe.root, (config, changed)));
        (bool manifestOk,) =
            address(probe).staticcall(abi.encodeCall(probe.manifest, (config, changed)));
        require(!snapshotOk && !rootOk && !manifestOk);
        require(probe.snapshot(config, publication.scope) != 0);
    }

    function testRootSnapshotPinAndManifestSubstitutionRefuse() public {
        _ready(2);
        Reader.Config memory wrong = config;
        wrong.snapshots.snapshotsCodeHash ^= bytes32(uint256(1));
        (bool pinOk,) =
            address(probe).staticcall(abi.encodeCall(probe.root, (wrong, publication.scope)));
        require(!pinOk);
        Root.Record memory changed = declaredRoot;
        changed.snapshotManifestHash ^= bytes32(uint256(1));
        route.set("scopedContentRootRecord(bytes32)", abi.encode(changed));
        (bool bytesOk,) =
            address(probe).staticcall(abi.encodeCall(probe.root, (config, publication.scope)));
        require(!bytesOk);
        route.set("scopedContentRootRecord(bytes32)", abi.encode(declaredRoot));
        probe.root(config, publication.scope);
    }

    function testCurrentSnapshotSourceDriftRefusesRetainedHistoricalHead() public {
        _ready(2);
        Scoped.Receipt memory prior = host.currentSnapshot(publication.scope);
        outputManifest.outputRoot ^= bytes32(uint256(1));
        _refreshPlans();
        (bool currentOk,) =
            address(probe).staticcall(abi.encodeCall(probe.snapshot, (config, publication.scope)));
        (bool rootOk,) =
            address(probe).staticcall(abi.encodeCall(probe.root, (config, publication.scope)));
        require(!currentOk && !rootOk);
        (, Scoped.Receipt memory saved) = host.snapshotRecord(prior.recordHash);
        require(keccak256(abi.encode(saved)) == keccak256(abi.encode(prior)));
    }

    function testEmptyHostAndCollectionNeverFallBack() public {
        _ready(2);
        Reader.Config memory empty = config;
        empty.snapshots.snapshots = address(0);
        (bool hostOk,) =
            address(probe).staticcall(abi.encodeCall(probe.snapshot, (empty, publication.scope)));
        StreamFinalityScope memory collection =
            StreamFinalityScope(StreamFinalityScopeType.COLLECTION, 1, 0, 0);
        (bool collectionOk,) =
            address(probe).staticcall(abi.encodeCall(probe.manifest, (config, collection)));
        require(!hostOk && !collectionOk);
    }
}
