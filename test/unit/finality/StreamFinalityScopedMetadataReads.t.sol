// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamFinalityScopedMetadataReads as Read
} from "../../../smart-contracts/domains/finality/StreamFinalityScopedMetadataReads.sol";
import {
    IStreamFinalityScopedMetadataReads as I
} from "../../../smart-contracts/interfaces/stream/finality/IStreamFinalityScopedMetadataReads.sol";
import {
    StreamCoreFinalityAdapter
} from "../../../smart-contracts/domains/finality/StreamCoreFinalityAdapter.sol";
import {
    StreamFinalityScope,
    StreamFinalityScopeType,
    StreamCoreFinalityScopeQuery,
    StreamScopedCoreFinalityFacts
} from "../../../smart-contracts/interfaces/stream/finality/StreamArtworkFinalityTypes.sol";
import { IERC165 } from "../../../smart-contracts/vendor/openzeppelin/IERC165.sol";

interface ScopedMetadataVm {
    function mockCall(address, bytes calldata, bytes calldata) external;
    function clearMockedCalls() external;
    function etch(address, bytes calldata) external;
}

contract ScopedMetadataCoreBoundary {
    function collectionExists(uint256) external pure returns (bool) {
        return true;
    }

    function collectionHasMaxSupply(uint256) external pure returns (bool) {
        return true;
    }

    function collectionStatus(uint256) external pure returns (uint8) {
        return 2;
    }

    function collectionSupplyMode(uint256) external pure returns (uint8) {
        return 1;
    }

    function collectionMaxSupply(uint256) external pure returns (uint256) {
        return 3;
    }

    function collectionMintedEver(uint256) external pure returns (uint256) {
        return 3;
    }

    function collectionNextSerial(uint256) external pure returns (uint256) {
        return 4;
    }

    function totalSupplyOfCollection(uint256) external pure returns (uint256) {
        return 2;
    }

    function tokenCollectionIdentity(uint256 id)
        external
        pure
        returns (bool, uint256, uint256, bool)
    {
        return (true, 1, id, true);
    }

    function tokenLifecycle(uint256) external pure returns (uint8) {
        return 2;
    }
}

/// @dev Typed scoped producer boundary; actual combined producer integration remains separate.
contract ScopedMetadataProviderBoundary is I {
    address public immutable core;
    address public immutable metadataHost;
    bool public supported = true;

    struct Row {
        bytes32 root;
        uint64 count;
        bytes32 schema;
        bytes32 snapshot;
        bytes32 manifest;
    }
    mapping(bytes32 => Row) private rows;

    constructor(address c, address m) {
        core = c;
        metadataHost = m;
    }

    function setSupported(bool value) external {
        supported = value;
    }

    function supportsInterface(bytes4 id) external view returns (bool) {
        return supported && id == type(I).interfaceId;
    }

    function set(StreamFinalityScope calldata scope, Row calldata row) external {
        rows[keccak256(abi.encode(scope))] = row;
    }

    function scopedContentRoot(StreamFinalityScope calldata scope)
        external
        view
        returns (bytes32, uint64, bytes32)
    {
        Row storage row = rows[keccak256(abi.encode(scope))];
        return (row.root, row.count, row.schema);
    }

    function scopedSnapshotHash(StreamFinalityScope calldata scope)
        external
        view
        returns (bytes32)
    {
        return rows[keccak256(abi.encode(scope))].snapshot;
    }

    function scopedManifest(StreamFinalityScope calldata scope)
        external
        view
        returns (bool, bytes32)
    {
        bytes32 hash = rows[keccak256(abi.encode(scope))].manifest;
        return (hash != 0, hash);
    }

    function scopeManifest(uint256, bytes32) external pure returns (bool, bytes32) {
        revert("legacy subject-only call forbidden");
    }
}

contract ScopedMetadataReadHarness {
    address public immutable target;
    bytes32 public immutable runtime;

    constructor(address t) {
        target = t;
        runtime = t.codehash;
    }

    function read(StreamFinalityScope memory scope)
        external
        view
        returns (bytes32, uint64, bytes32, bytes32, bool, bytes32)
    {
        (bytes32 root, uint64 count, bytes32 schema) =
            Read.contentRoot(target, runtime, scope, 600000);
        bytes32 snapshot = Read.snapshot(target, runtime, scope, 600000);
        (bool exists, bytes32 manifest) = Read.manifest(target, runtime, scope, 600000);
        return (root, count, schema, snapshot, exists, manifest);
    }
}

contract StreamFinalityScopedMetadataReadsTest {
    ScopedMetadataVm private constant vm =
        ScopedMetadataVm(address(uint160(uint256(keccak256("hevm cheat code")))));
    ScopedMetadataProviderBoundary private provider;
    ScopedMetadataReadHarness private reader;
    StreamCoreFinalityAdapter private adapter;

    function setUp() public {
        ScopedMetadataCoreBoundary core = new ScopedMetadataCoreBoundary();
        provider = new ScopedMetadataProviderBoundary(address(core), address(core));
        reader = new ScopedMetadataReadHarness(address(provider));
        adapter = new StreamCoreFinalityAdapter(address(core), address(core), address(provider));
        _set(_scope(StreamFinalityScopeType.RELEASE), 1);
        _set(_scope(StreamFinalityScopeType.SEASON), 2);
        _set(StreamFinalityScope(StreamFinalityScopeType.TOKEN, 1, 42, 0), 3);
    }

    function _scope(StreamFinalityScopeType kind)
        private
        pure
        returns (StreamFinalityScope memory)
    {
        return StreamFinalityScope(kind, 1, 0, keccak256("same-id"));
    }

    function _set(StreamFinalityScope memory scope, uint256 n) private {
        provider.set(
            scope,
            ScopedMetadataProviderBoundary.Row(
                bytes32(n),
                uint64(n == 3 ? 1 : n),
                bytes32(n + 10),
                bytes32(n + 20),
                bytes32(n + 30)
            )
        );
    }

    function testReleaseSeasonSameIdUsesFullScopeAtActualAdapter() public view {
        StreamFinalityScope memory release = _scope(StreamFinalityScopeType.RELEASE);
        StreamFinalityScope memory season = _scope(StreamFinalityScopeType.SEASON);
        (bytes32 a,,, bytes32 x,, bytes32 m) = reader.read(release);
        (bytes32 b,,, bytes32 y,, bytes32 n) = reader.read(season);
        require(a == bytes32(uint256(1)) && b == bytes32(uint256(2)) && a != b && x != y && m != n);
        StreamScopedCoreFinalityFacts memory r = adapter.scopedCoreFinalityFacts(
            StreamCoreFinalityScopeQuery(uint8(release.scopeType), 1, 0, release.scopeId)
        );
        StreamScopedCoreFinalityFacts memory s = adapter.scopedCoreFinalityFacts(
            StreamCoreFinalityScopeQuery(uint8(season.scopeType), 1, 0, season.scopeId)
        );
        require(
            r.scopeExists && s.scopeExists && r.scopeManifestHash == m && s.scopeManifestHash == n
        );
    }

    function testTokenSourceHasIndependentRootSnapshotAndManifest() public view {
        (
            bytes32 root,
            uint64 count,
            bytes32 schema,
            bytes32 snapshot,
            bool exists,
            bytes32 manifest
        ) = reader.read(StreamFinalityScope(StreamFinalityScopeType.TOKEN, 1, 42, 0));
        require(
            root == bytes32(uint256(3)) && count == 1 && schema == bytes32(uint256(13))
                && snapshot == bytes32(uint256(23)) && exists && manifest == bytes32(uint256(33))
        );
        (bytes32 other,,, bytes32 otherSnapshot,, bytes32 otherManifest) =
            reader.read(StreamFinalityScope(StreamFinalityScopeType.TOKEN, 1, 43, 0));
        require(other == 0 && otherSnapshot == 0 && otherManifest == 0);
    }

    function testAbsentEmptyMalformedCapabilityNeverFallsBack() public {
        provider.setSupported(false);
        _refuses();
        provider.setSupported(true);
        bytes memory callData = abi.encodeCall(IERC165.supportsInterface, (type(I).interfaceId));
        vm.mockCall(address(provider), callData, bytes(""));
        _refuses();
        vm.mockCall(address(provider), callData, hex"01");
        _refuses();
        vm.mockCall(address(provider), callData, abi.encode(uint256(2)));
        _refuses();
        vm.clearMockedCalls();
        reader.read(_scope(StreamFinalityScopeType.RELEASE));
    }

    function testExactShapesRuntimeAndCanonicalBooleansRequired() public {
        StreamFinalityScope memory scope = _scope(StreamFinalityScopeType.RELEASE);
        vm.mockCall(
            address(provider),
            abi.encodeCall(I.scopedManifest, (scope)),
            abi.encode(uint256(2), bytes32(uint256(31)))
        );
        _refuses();
        vm.clearMockedCalls();
        vm.mockCall(
            address(provider),
            abi.encodeCall(I.scopedContentRoot, (scope)),
            abi.encode(bytes32(uint256(1)), uint256(1), bytes32(uint256(11)), uint256(0))
        );
        (bool ok,) = address(reader).staticcall(abi.encodeCall(reader.read, (scope)));
        require(!ok);
        vm.clearMockedCalls();
        bytes memory code = address(provider).code;
        vm.etch(address(provider), hex"00");
        _refuses();
        vm.etch(address(provider), code);
        reader.read(scope);
    }

    function testCollectionFactsRemainOriginalAndDoNotNeedNewCapability() public {
        bytes32 before = keccak256(abi.encode(adapter.coreCollectionFinalityFacts(1)));
        provider.setSupported(false);
        require(keccak256(abi.encode(adapter.coreCollectionFinalityFacts(1))) == before);
        (bool ok,) = address(reader)
            .staticcall(
                abi.encodeCall(
                    reader.read, (StreamFinalityScope(StreamFinalityScopeType.COLLECTION, 1, 0, 0))
                )
            );
        require(!ok);
    }

    function testMalformedScopeRefusesBeforeDependencyCall() public view {
        StreamFinalityScope memory scope = _scope(StreamFinalityScopeType.RELEASE);
        scope.tokenId = 1;
        (bool ok,) = address(reader).staticcall(abi.encodeCall(reader.read, (scope)));
        require(!ok);
        scope = StreamFinalityScope(StreamFinalityScopeType.TOKEN, 1, 0, 0);
        (ok,) = address(reader).staticcall(abi.encodeCall(reader.read, (scope)));
        require(!ok);
    }

    function _refuses() private view {
        (bool ok,) = address(reader)
            .staticcall(abi.encodeCall(reader.read, (_scope(StreamFinalityScopeType.RELEASE))));
        require(!ok);
        (ok,) = address(adapter)
            .staticcall(
                abi.encodeCall(
                    adapter.scopedCoreFinalityFacts,
                    (StreamCoreFinalityScopeQuery(2, 1, 0, keccak256("same-id")))
                )
            );
        require(!ok);
    }
}
