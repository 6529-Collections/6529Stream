// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "./StreamFinalityMultiOriginConfiguration.t.sol";
import {
    StreamCurrentAuthorityConfiguration as CurrentConfiguration
} from "../../../smart-contracts/domains/finality/StreamCurrentAuthorityConfiguration.sol";
import {
    StreamCurrentAuthorityPresentation as CurrentPresentation
} from "../../../smart-contracts/domains/finality/StreamCurrentAuthorityPresentation.sol";
import {
    StreamCurrentAuthorityBundleArchiveEnvironment as CurrentEnvironment
} from "../../../smart-contracts/domains/preservation/StreamCurrentAuthorityBundleArchiveEnvironment.sol";
import {
    StreamCurrentAuthorityInventoryTypes as D
} from "../../../smart-contracts/interfaces/stream/preservation/StreamCurrentAuthorityInventoryTypes.sol";
import {
    StreamArtistCurrentAuthorityTypes as CA
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistCurrentAuthorityTypes.sol";
import {
    IStreamArtistCurrentAuthorityResolver as Resolver
} from "../../../smart-contracts/interfaces/stream/preservation/IStreamArtistCurrentAuthorityResolver.sol";
import {
    IStreamRecordCurrentAuthority as Selector
} from "../../../smart-contracts/interfaces/stream/metadata/IStreamRecordCurrentAuthority.sol";
import { IERC165 } from "../../../smart-contracts/vendor/openzeppelin/IERC165.sol";

contract CurrentAuthorityConsumerHarness {
    function configuration(Native.Config memory c, bytes32 profile)
        external
        view
        returns (S.Dependencies memory, O.Dependencies memory)
    {
        return CurrentConfiguration.read(
            c.targets, c.codeHashes, c.chainId, c.readGas, c.inventoryDependencyHash, profile
        );
    }

    function artist(
        Native.Config memory c,
        bytes32 profile,
        StreamFinalityScope memory scope,
        StreamFinalityScopeInputs memory inputs
    ) external view returns (bytes32) {
        return CurrentPresentation.artist(
            c.targets,
            c.codeHashes,
            c.chainId,
            c.readGas,
            c.inventoryDependencyHash,
            profile,
            scope,
            inputs
        );
    }

    function capture(
        B.Dependencies memory b,
        O.Dependencies memory o,
        D.Dependencies memory a,
        bytes32 profile,
        bytes32 id
    ) external view returns (D.Capture memory) {
        return CurrentEnvironment.capture(b, o, a, profile, id);
    }
}

/// @dev Typed resolver/inventory boundaries. Uses actual fixed-configuration, selection projection
/// and archive environment readers; actual ancestry/import and Finality execution remain separate.
abstract contract CurrentAuthorityConsumerFixture is FinalityMultiOriginFixture {
    CurrentAuthorityConsumerHarness internal caHarness;
    FinalityMultiOriginReadTable internal resolver;
    D.Dependencies internal ad;
    D.Capture internal captured;
    CA.Anchors internal anchors;
    bytes32 internal constant PLAN = keccak256("current authority plan boundary");

    function setUp() public virtual override {
        super.setUp();
        caHarness = new CurrentAuthorityConsumerHarness();
        resolver = new FinalityMultiOriginReadTable();
        ad = D.Dependencies(address(resolver), address(resolver).codehash, 4000000);
        // The two selector capabilities have distinct profile domains.
        c.targets[15] = address(new FinalityMultiOriginReadTable());
        c.codeHashes[15] = c.targets[15].codehash;
        sd.targets[7] = c.targets[15];
        sd.codeHashes[7] = c.codeHashes[15];
        c.targets[17] = address(new FinalityMultiOriginReadTable());
        c.codeHashes[17] = c.targets[17].codehash;
        sd.targets[9] = c.targets[17];
        sd.codeHashes[9] = c.codeHashes[17];
        anchors.targets =
            [c.targets[0], c.targets[1], c.targets[2], c.targets[11], address(caHarness)];
        for (uint256 i; i < 5; ++i) {
            anchors.codeHashes[i] = anchors.targets[i].codehash;
        }
        anchors.finalityRegistry = c.targets[12];
        anchors.chainId = block.chainid;
        anchors.readGas = 500000;
        _support(address(resolver), type(Resolver).interfaceId);
        resolver.set(abi.encodeCall(Resolver.currentAuthorityProfile, ()), abi.encode(CA.PROFILE));
        resolver.set(abi.encodeCall(Resolver.anchors, ()), abi.encode(anchors));
        _select(address(new FinalityMultiOriginReadTable()));
        _publishCurrent(D.INVENTORY_PROFILE);
    }

    function _support(address target, bytes4 id) internal {
        FinalityMultiOriginReadTable(target)
            .set(
                abi.encodeCall(IERC165.supportsInterface, (type(IERC165).interfaceId)),
                abi.encode(true)
            );
        FinalityMultiOriginReadTable(target)
            .set(abi.encodeCall(IERC165.supportsInterface, (id)), abi.encode(true));
        FinalityMultiOriginReadTable(target)
            .set(abi.encodeCall(IERC165.supportsInterface, (bytes4(0xffffffff))), abi.encode(false));
    }

    function _select(address registry) internal {
        O.Origin memory o;
        o.environment.chainId = block.chainid;
        o.environment.core = c.targets[0];
        o.environment.registry = registry;
        o.registryCodeHash = registry.codehash;
        o.environment.coordinator = registry;
        o.coordinatorCodeHash = registry.codehash;
        o.environment.archive = registry;
        o.archiveCodeHash = registry.codehash;
        o.environment.suiteConfigurationHash = keccak256(abi.encode("suite", registry));
        for (uint256 i; i < 7; ++i) {
            o.environment.owners[i] = registry;
            o.environment.ownerCodeHashes[i] = registry.codehash;
        }
        captured.dependencies = abi.decode(abi.encode(sd), (S.Dependencies));
        for (uint256 i; i < 5; ++i) {
            captured.dependencies.artistTargets[i] = registry;
            captured.dependencies.artistCodeHashes[i] = registry.codehash;
        }
        captured.dependencies.artistContentOwner = registry;
        captured.dependencies.artistContentOwnerCodeHash = registry.codehash;
        captured.selection = CA.Selection(o, keccak256("completed hydration boundary"), bytes32(0));
        captured.selection.selectionHash =
            CA.hashSelection(anchors, o, captured.selection.completion);
        resolver.set(abi.encodeCall(Resolver.currentSelection, ()), abi.encode(captured.selection));
        address[5] memory targets = [registry, registry, registry, registry, registry];
        bytes32[5] memory hashes = [
            registry.codehash,
            registry.codehash,
            registry.codehash,
            registry.codehash,
            registry.codehash
        ];
        uint256[2] memory indexes = [uint256(15), 17];
        for (uint256 i; i < 2; ++i) {
            address target = c.targets[indexes[i]];
            _support(target, type(Selector).interfaceId);
            FinalityMultiOriginReadTable(target)
                .set(
                    abi.encodeCall(Selector.currentAuthorityProfile, ()),
                    abi.encode(
                        i == 0
                            ? keccak256("6529STREAM_CURRENT_AUTHORITY_WORK_SELECTION_V1")
                            : keccak256("6529STREAM_CURRENT_AUTHORITY_CONSERVATION_SELECTION_V1")
                    )
                );
            FinalityMultiOriginReadTable(target)
                .set(abi.encodeCall(Selector.currentArtistContext, ()), abi.encode(targets, hashes));
        }
    }

    function _publishCurrent(bytes32 profile) internal {
        c.inventoryDependencyHash = D.dependencyHash(profile, sd, od, ad);
        bytes32 coverageProfile = CurrentEnvironment.coverageProfile(profile);
        inventory.set(abi.encodeWithSignature("dependencies()"), abi.encode(sd));
        inventory.set(abi.encodeWithSignature("originalAnchor()"), abi.encode(sd));
        inventory.set(abi.encodeWithSignature("originDependencies()"), abi.encode(od));
        inventory.set(abi.encodeWithSignature("authorityDependencies()"), abi.encode(ad));
        inventory.set(
            abi.encodeWithSignature("authoritySelection(bytes32)", PLAN), abi.encode(captured)
        );
        inventory.set(abi.encodeWithSignature("originProfile()"), abi.encode(profile));
        inventory.set(
            abi.encodeWithSignature("dependencyHash()"), abi.encode(c.inventoryDependencyHash)
        );
        bundle.set(abi.encodeWithSignature("dependencies()"), abi.encode(bd));
        bundle.set(abi.encodeWithSignature("originDependencies()"), abi.encode(od));
        bundle.set(abi.encodeWithSignature("authorityDependencies()"), abi.encode(ad));
        bundle.set(abi.encodeWithSignature("originProfile()"), abi.encode(coverageProfile));
        bundle.set(abi.encodeWithSignature("INVENTORY_PROFILE()"), abi.encode(profile));
        bundle.set(
            abi.encodeWithSignature("dependencyHash()"),
            abi.encode(keccak256(abi.encode(coverageProfile, profile, bd, od, ad)))
        );
    }

    function _configuration() internal view returns (S.Dependencies memory current) {
        (current,) = caHarness.configuration(c, D.INVENTORY_PROFILE);
    }

    function _rejectCurrent() internal {
        (bool ok,) = address(caHarness)
            .call(abi.encodeCall(caHarness.configuration, (c, D.INVENTORY_PROFILE)));
        require(!ok, "current config must reject");
    }
}

contract StreamCurrentAuthorityConfigurationTest is CurrentAuthorityConsumerFixture {
    function testFourProfilesReturnCurrentProjectionAndKeepOriginalAnchors() public {
        bytes32[4] memory profiles = [
            D.INVENTORY_PROFILE,
            D.SCOPED_INVENTORY_PROFILE,
            D.POLICY_INVENTORY_PROFILE,
            D.SCOPED_POLICY_INVENTORY_PROFILE
        ];
        for (uint256 i; i < 4; ++i) {
            _publishCurrent(profiles[i]);
            (S.Dependencies memory actual, O.Dependencies memory origin) =
                caHarness.configuration(c, profiles[i]);
            require(keccak256(abi.encode(actual)) == keccak256(abi.encode(captured.dependencies)));
            require(
                actual.artistTargets[0] != c.targets[11] && sd.artistTargets[0] == c.targets[11]
            );
            require(keccak256(abi.encode(origin)) == keccak256(abi.encode(od)));
        }
    }

    function testUnpredictedCNeedsNoProviderReconfigurationButOldCaptureExpires() public {
        D.Capture memory before = caHarness.capture(bd, od, ad, D.INVENTORY_PROFILE, PLAN);
        bytes32 fixedHash = c.inventoryDependencyHash;
        _select(address(new FinalityMultiOriginReadTable()));
        require(_configuration().artistTargets[0] == captured.dependencies.artistTargets[0]);
        require(
            c.inventoryDependencyHash == fixedHash
                && before.selection.selectionHash != captured.selection.selectionHash
        );
        (bool ok,) = address(caHarness)
            .call(abi.encodeCall(caHarness.capture, (bd, od, ad, D.INVENTORY_PROFILE, PLAN)));
        require(!ok, "old plan may not adopt new selection");
        _publishCurrent(D.INVENTORY_PROFILE);
        require(
            caHarness.capture(bd, od, ad, D.INVENTORY_PROFILE, PLAN).selection.selectionHash
                == captured.selection.selectionHash
        );
    }

    function testResolverAndBundleConfigurationArePartOfFixedHash() public {
        D.Dependencies memory wrong = ad;
        wrong.resolverGas += 1;
        bundle.set(abi.encodeWithSignature("authorityDependencies()"), abi.encode(wrong));
        _rejectCurrent();
        _publishCurrent(D.INVENTORY_PROFILE);
        inventory.set(abi.encodeWithSignature("authorityDependencies()"), abi.encode(wrong));
        _rejectCurrent();
    }

    function testOriginalProviderFinalityAndSelectorTupleRemainExact() public {
        anchors.finalityRegistry = address(worker);
        resolver.set(abi.encodeCall(Resolver.anchors, ()), abi.encode(anchors));
        _rejectCurrent();
        anchors.finalityRegistry = c.targets[12];
        anchors.targets[4] = address(worker);
        anchors.codeHashes[4] = address(worker).codehash;
        resolver.set(abi.encodeCall(Resolver.anchors, ()), abi.encode(anchors));
        _rejectCurrent();
    }

    function testCaptureAndSelectorMalformedReturnReject() public {
        inventory.set(
            abi.encodeWithSignature("authoritySelection(bytes32)", PLAN),
            abi.encode(captured.selection)
        );
        (bool ok,) = address(caHarness)
            .call(abi.encodeCall(caHarness.capture, (bd, od, ad, D.INVENTORY_PROFILE, PLAN)));
        require(!ok);
        _publishCurrent(D.INVENTORY_PROFILE);
        FinalityMultiOriginReadTable(c.targets[15])
            .set(
                abi.encodeCall(Selector.currentArtistContext, ()),
                abi.encode(sd.artistTargets, sd.artistCodeHashes)
            );
        _rejectCurrent();
    }

    function testLegacyProfileAndRuntimeCannotMasqueradeAsCurrentCapability() public {
        c.inventoryDependencyHash = O.inventoryDependencyHash(O.INVENTORY_PROFILE, sd, od);
        _rejectCurrent();
        _publishCurrent(D.INVENTORY_PROFILE);
        vm.etch(address(resolver), hex"00");
        _rejectCurrent();
    }
}
