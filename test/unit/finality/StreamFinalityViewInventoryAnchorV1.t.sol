// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "../../regression/legacy/helpers/CharacterizationTestBase.sol";
import {
    StreamFinalityViewInventoryAnchorV1 as Anchor
} from "../../../smart-contracts/domains/finality/StreamFinalityViewInventoryAnchorV1.sol";
import {
    StreamFinalityNativeProviderReads as Native
} from "../../../smart-contracts/domains/finality/StreamFinalityNativeProviderReads.sol";
import {
    StreamRenderCriticalSourceTypes as S
} from "../../../smart-contracts/interfaces/stream/preservation/StreamRenderCriticalSourceTypes.sol";
import {
    StreamCurrentAuthorityInventoryTypes as D
} from "../../../smart-contracts/interfaces/stream/preservation/StreamCurrentAuthorityInventoryTypes.sol";
import {
    StreamArtistArchiveOriginTypes as O
} from "../../../smart-contracts/interfaces/stream/preservation/StreamArtistArchiveOriginTypes.sol";
import {
    StreamArtistCurrentAuthorityTypes as C
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistCurrentAuthorityTypes.sol";
import {
    IStreamArtistCurrentAuthorityResolver as Resolver
} from "../../../smart-contracts/interfaces/stream/preservation/IStreamArtistCurrentAuthorityResolver.sol";

/// @dev Exact immutable-getter boundary. Unconfigured currentSelection and inventory reads revert.
contract ViewAnchorBoundary {
    mapping(bytes32 => bytes) private response;

    function set(bytes memory input, bytes memory value) external {
        response[keccak256(input)] = value;
    }

    fallback() external {
        bytes memory raw = response[keccak256(msg.data)];
        require(raw.length != 0, "no currentness or selector shortcut");
        assembly ("memory-safe") { return(add(raw, 32), mload(raw)) }
    }
}

contract ViewAnchorProbe {
    function check(Native.Config memory c, S.Dependencies memory d) external view returns (bool) {
        return Anchor.matches(c, d);
    }
}

/// @notice Configuration-only literal proof; real current-graph producer ceremony is a separate recipe.
contract StreamFinalityViewInventoryAnchorV1Test is CharacterizationTestBase {
    ViewAnchorBoundary private inventory;
    ViewAnchorBoundary private resolver;
    ViewAnchorBoundary private originWorker;
    ViewAnchorBoundary private leaf;
    ViewAnchorProbe private probe;
    Native.Config private config;
    S.Dependencies private anchor;
    O.Dependencies private origin;
    D.Dependencies private authority;
    C.Anchors private resolverAnchor;

    function setUp() public {
        inventory = new ViewAnchorBoundary();
        resolver = new ViewAnchorBoundary();
        originWorker = new ViewAnchorBoundary();
        leaf = new ViewAnchorBoundary();
        probe = new ViewAnchorProbe();
        config.chainId = block.chainid;
        config.readGas = 500000;
        config.sourceGas = 4000000;
        config.componentSourceGas = 2000000;
        for (uint256 i; i < 22; ++i) {
            config.targets[i] = address(leaf);
            config.codeHashes[i] = address(leaf).codehash;
        }
        config.targets[18] = address(inventory);
        config.codeHashes[18] = address(inventory).codehash;
        anchor.chainId = config.chainId;
        anchor.readGas = 500000;
        anchor.sourceGas = 2000000;
        anchor.selectionGas = 2000000;
        anchor.snapshotGas = 2000000;
        anchor.referenceGas = 2000000;
        for (uint256 i; i < 12; ++i) {
            anchor.targets[i] = address(leaf);
            anchor.codeHashes[i] = address(leaf).codehash;
        }
        for (uint256 i; i < 5; ++i) {
            anchor.artistTargets[i] = address(leaf);
            anchor.artistCodeHashes[i] = address(leaf).codehash;
        }
        anchor.artistContentOwner = address(leaf);
        anchor.artistContentOwnerCodeHash = address(leaf).codehash;
        origin = O.Dependencies(
            address(originWorker),
            address(originWorker).codehash,
            1000000,
            keccak256("6529STREAM_ARTIST_ARCHIVE_ORIGIN_V1")
        );
        authority = D.Dependencies(address(resolver), address(resolver).codehash, 2000000);
        config.inventoryDependencyHash = keccak256(
            abi.encode(
                keccak256("6529STREAM_CURRENT_AUTHORITY_RENDER_CRITICAL_INVENTORY_V1"),
                anchor,
                origin,
                authority
            )
        );
        _put(
            inventory,
            "originProfile()",
            abi.encode(keccak256("6529STREAM_CURRENT_AUTHORITY_RENDER_CRITICAL_INVENTORY_V1"))
        );
        _put(inventory, "originalAnchor()", abi.encode(anchor));
        _put(inventory, "originDependencies()", abi.encode(origin));
        _put(inventory, "authorityDependencies()", abi.encode(authority));
        _put(inventory, "dependencyHash()", abi.encode(config.inventoryDependencyHash));
        resolver.set(
            abi.encodeWithSignature("supportsInterface(bytes4)", bytes4(0x01ffc9a7)),
            abi.encode(true)
        );
        resolver.set(
            abi.encodeWithSignature("supportsInterface(bytes4)", type(Resolver).interfaceId),
            abi.encode(true)
        );
        resolver.set(
            abi.encodeWithSignature("supportsInterface(bytes4)", bytes4(0xffffffff)),
            abi.encode(false)
        );
        _put(
            resolver,
            "currentAuthorityProfile()",
            abi.encode(keccak256("6529STREAM_ARTIST_CURRENT_AUTHORITY_V1"))
        );
        resolverAnchor.targets =
            [address(leaf), address(leaf), address(leaf), address(leaf), address(probe)];
        resolverAnchor.codeHashes = [
            address(leaf).codehash,
            address(leaf).codehash,
            address(leaf).codehash,
            address(leaf).codehash,
            address(probe).codehash
        ];
        resolverAnchor.chainId = config.chainId;
        resolverAnchor.readGas = 500000;
        resolverAnchor.finalityRegistry = address(leaf);
        _put(resolver, "anchors()", abi.encode(resolverAnchor));
    }

    function _put(ViewAnchorBoundary target, string memory sig, bytes memory data) private {
        target.set(abi.encodeWithSignature(sig), data);
    }

    function _positive() private view {
        require(probe.check(config, anchor), "exact restored immutable configuration");
    }

    function _refuse() private {
        (bool ok,) = address(probe).call(abi.encodeCall(probe.check, (config, anchor)));
        require(!ok, "changed original cannot authenticate");
    }

    function testLiteralCurrentAuthorityCommitmentAndNoCurrentSelectionRead() public view {
        require(
            config.inventoryDependencyHash != keccak256(abi.encode(anchor)),
            "full O/D commitment differs from raw1344"
        );
        _positive();
    }

    function testOriginalRawPathMakesNoAddedExternalQuery() public view {
        Native.Config memory c = config;
        c.inventoryDependencyHash = keccak256(abi.encode(anchor));
        c.targets[18] = address(originWorker);
        require(
            probe.check(c, anchor), "unconfigured origin worker would refuse every new selector"
        );
    }

    function testUnknownProfileCannotBorrowSameDependenciesOrFallback() public {
        _positive();
        _put(
            inventory,
            "originProfile()",
            abi.encode(
                keccak256("6529STREAM_CURRENT_AUTHORITY_SCOPED_RENDER_CRITICAL_INVENTORY_V1")
            )
        );
        _refuse();
        _put(
            inventory,
            "originProfile()",
            abi.encode(keccak256("6529STREAM_CURRENT_AUTHORITY_RENDER_CRITICAL_INVENTORY_V1"))
        );
        _positive();
    }

    function testEveryOriginAndAuthorityFieldIsCommitted() public {
        for (uint256 i; i < 4; ++i) {
            O.Dependencies memory o = origin;
            if (i == 0) o.worker = address(leaf);
            else if (i == 1) o.workerCodeHash = keccak256("wrong origin runtime");
            else if (i == 2) o.originGas += 1;
            else o.profile = keccak256("unknown origin");
            _put(inventory, "originDependencies()", abi.encode(o));
            _refuse();
            _put(inventory, "originDependencies()", abi.encode(origin));
            _positive();
        }
        for (uint256 i; i < 3; ++i) {
            D.Dependencies memory d = authority;
            if (i == 0) d.resolver = address(leaf);
            else if (i == 1) d.resolverCodeHash = keccak256("wrong resolver runtime");
            else d.resolverGas += 1;
            _put(inventory, "authorityDependencies()", abi.encode(d));
            _refuse();
            _put(inventory, "authorityDependencies()", abi.encode(authority));
            _positive();
        }
    }

    function testExactOriginalAnchorAndImmutableStoredHashAreIndependentJoins() public {
        S.Dependencies memory d = anchor;
        d.artistContentOwner = address(originWorker);
        _put(inventory, "originalAnchor()", abi.encode(d));
        _refuse();
        _put(inventory, "originalAnchor()", abi.encode(anchor));
        _positive();
        _put(inventory, "dependencyHash()", abi.encode(keccak256(abi.encode(anchor))));
        _refuse();
        _put(inventory, "dependencyHash()", abi.encode(config.inventoryDependencyHash));
        _positive();
    }

    function testAllResolverAnchorsAndHostIdentityAreChecked() public {
        for (uint256 i; i < 13; ++i) {
            C.Anchors memory a = resolverAnchor;
            if (i < 5) a.targets[i] = address(originWorker);
            else if (i < 10) a.codeHashes[i - 5] = keccak256("foreign runtime");
            else if (i == 10) a.finalityRegistry = address(originWorker);
            else if (i == 11) a.chainId += 1;
            else a.readGas = 49999;
            _put(resolver, "anchors()", abi.encode(a));
            _refuse();
            _put(resolver, "anchors()", abi.encode(resolverAnchor));
            _positive();
        }
        ViewAnchorProbe foreign = new ViewAnchorProbe();
        (bool ok,) = address(foreign).call(abi.encodeCall(foreign.check, (config, anchor)));
        require(!ok, "provider is part of immutable resolver anchors");
        _positive();
    }

    function testMalformedCapabilityAndCanonicalTuplesFailRestore() public {
        bytes memory input =
            abi.encodeWithSignature("supportsInterface(bytes4)", type(Resolver).interfaceId);
        resolver.set(input, abi.encode(uint256(2)));
        _refuse();
        resolver.set(input, abi.encode(true));
        _positive();
        _put(inventory, "originDependencies()", bytes.concat(abi.encode(origin), bytes32(0)));
        _refuse();
        _put(inventory, "originDependencies()", abi.encode(origin));
        _positive();
        _put(resolver, "currentAuthorityProfile()", abi.encode(bytes32(0)));
        _refuse();
        _put(
            resolver,
            "currentAuthorityProfile()",
            abi.encode(keccak256("6529STREAM_ARTIST_CURRENT_AUTHORITY_V1"))
        );
        _positive();
    }

    function testRuntimeAndChainDriftRestoresExactOriginal() public {
        bytes memory code = address(originWorker).code;
        vm.etch(address(originWorker), hex"00");
        _refuse();
        vm.etch(address(originWorker), code);
        _positive();
        code = address(resolver).code;
        vm.etch(address(resolver), hex"00");
        _refuse();
        vm.etch(address(resolver), code);
        _positive();
        uint256 chain = config.chainId;
        vm.chainId(chain + 1);
        _refuse();
        vm.chainId(chain);
        _positive();
    }
}
