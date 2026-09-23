// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "../../../smart-contracts/interfaces/stream/finality/StreamFinalityEvidenceTypes.sol";
import "../../../smart-contracts/interfaces/stream/finality/StreamArtworkFinalityTypes.sol";

import {
    StreamFinalityMultiOriginConfiguration as Configuration
} from "../../../smart-contracts/domains/finality/StreamFinalityMultiOriginConfiguration.sol";
import {
    StreamFinalityMultiOriginPresentation as Presentation
} from "../../../smart-contracts/domains/finality/StreamFinalityMultiOriginPresentation.sol";
import {
    StreamFinalityNativeProviderReads as Native
} from "../../../smart-contracts/domains/finality/StreamFinalityNativeProviderReads.sol";
import {
    StreamFinalityMultiOriginNativeProviderReads
} from "../../../smart-contracts/domains/finality/StreamFinalityMultiOriginNativeProviderReads.sol";
import {
    StreamFinalityMultiOriginScopedProviderReads
} from "../../../smart-contracts/domains/finality/StreamFinalityMultiOriginScopedProviderReads.sol";
import {
    StreamFinalityMultiOriginPolicyProviderReadsV2
} from "../../../smart-contracts/domains/finality/StreamFinalityMultiOriginPolicyProviderReadsV2.sol";
import {
    StreamFinalityMultiOriginNativeSanctionReview
} from "../../../smart-contracts/domains/finality/StreamFinalityMultiOriginNativeSanctionReview.sol";
import {
    StreamFinalityMultiOriginScopedSanctionReview
} from "../../../smart-contracts/domains/finality/StreamFinalityMultiOriginScopedSanctionReview.sol";
import {
    StreamFinalityMultiOriginPolicySanctionReviewV2
} from "../../../smart-contracts/domains/finality/StreamFinalityMultiOriginPolicySanctionReviewV2.sol";
import {
    StreamArtistArchiveOriginTypes as O
} from "../../../smart-contracts/interfaces/stream/preservation/StreamArtistArchiveOriginTypes.sol";
import {
    StreamRenderCriticalSourceTypes as S
} from "../../../smart-contracts/interfaces/stream/preservation/StreamRenderCriticalSourceTypes.sol";
import {
    StreamBundleArchiveTypes as B
} from "../../../smart-contracts/interfaces/stream/preservation/StreamBundleArchiveTypes.sol";

interface FinalityMultiOriginVm {
    function etch(address target, bytes calldata runtime) external;
    function warp(uint256 timestamp) external;
}

/// @dev Exact typed read boundary. This does not implement a live Finality/Artist environment.
contract FinalityMultiOriginReadTable {
    mapping(bytes32 => bytes) private _values;

    function set(bytes memory input, bytes memory output) external {
        _values[keccak256(input)] = output;
    }

    fallback(bytes calldata input) external returns (bytes memory) {
        bytes memory output = _values[keccak256(input)];
        require(output.length != 0, "unconfigured boundary read");
        return output;
    }
}

contract FinalityMultiOriginHarness {
    function configuration(Native.Config memory c, bytes32 profile)
        external
        view
        returns (S.Dependencies memory, O.Dependencies memory)
    {
        return Configuration.read(
            c.targets, c.codeHashes, c.chainId, c.readGas, c.inventoryDependencyHash, profile
        );
    }

    function legacy(Native.Config memory c) external view {
        Native.requirePins(c);
    }

    function artist(
        Native.Config memory c,
        bytes32 profile,
        StreamFinalityScope memory scope,
        StreamFinalityScopeInputs memory inputs
    ) external view returns (bytes32) {
        return Presentation.artist(
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
}

abstract contract FinalityMultiOriginFixture {
    FinalityMultiOriginVm internal constant vm =
        FinalityMultiOriginVm(address(uint160(uint256(keccak256("hevm cheat code")))));
    FinalityMultiOriginReadTable internal table;
    FinalityMultiOriginReadTable internal inventory;
    FinalityMultiOriginReadTable internal bundle;
    FinalityMultiOriginReadTable internal worker;
    FinalityMultiOriginHarness internal harness;
    Native.Config internal c;
    S.Dependencies internal sd;
    O.Dependencies internal od;
    B.Dependencies internal bd;

    function setUp() public virtual {
        table = new FinalityMultiOriginReadTable();
        inventory = new FinalityMultiOriginReadTable();
        bundle = new FinalityMultiOriginReadTable();
        worker = new FinalityMultiOriginReadTable();
        harness = new FinalityMultiOriginHarness();
        for (uint256 i; i < 22; ++i) {
            c.targets[i] = address(table);
            c.codeHashes[i] = address(table).codehash;
        }
        c.targets[18] = address(inventory);
        c.codeHashes[18] = address(inventory).codehash;
        c.targets[19] = address(bundle);
        c.codeHashes[19] = address(bundle).codehash;
        c.chainId = block.chainid;
        c.readGas = 500000;
        c.componentSourceGas = 1000000;
        c.sourceGas = 5000000;
        uint256[12] memory indexes = [uint256(0), 1, 4, 5, 2, 8, 9, 15, 16, 17, 20, 21];
        for (uint256 i; i < 12; ++i) {
            sd.targets[i] = c.targets[indexes[i]];
            sd.codeHashes[i] = c.codeHashes[indexes[i]];
        }
        for (uint256 i; i < 5; ++i) {
            sd.artistTargets[i] = address(table);
            sd.artistCodeHashes[i] = address(table).codehash;
        }
        sd.artistContentOwner = address(table);
        sd.artistContentOwnerCodeHash = address(table).codehash;
        sd.chainId = block.chainid;
        sd.readGas = 500000;
        sd.sourceGas = 2000000;
        sd.selectionGas = 2000000;
        sd.snapshotGas = 2000000;
        sd.referenceGas = 2000000;
        od = O.Dependencies(address(worker), address(worker).codehash, 4000000, O.PROFILE);
        uint256[5] memory bi = [uint256(0), 1, 18, 20, 21];
        for (uint256 i; i < 5; ++i) {
            bd.targets[i] = c.targets[bi[i]];
            bd.codeHashes[i] = c.codeHashes[bi[i]];
        }
        bd.targets[5] = sd.artistTargets[4];
        bd.codeHashes[5] = sd.artistCodeHashes[4];
        bd.chainId = block.chainid;
        bd.readGas = 500000;
        bd.archiveGas = 2000000;
        _publish(O.INVENTORY_PROFILE);
        inventory.set(abi.encodeWithSignature("core()"), abi.encode(c.targets[0]));
        inventory.set(abi.encodeWithSignature("metadataHost()"), abi.encode(c.targets[1]));
        inventory.set(abi.encodeWithSignature("metadataRouter()"), abi.encode(c.targets[2]));
        inventory.set(abi.encodeWithSignature("snapshots()"), abi.encode(c.targets[8]));
        inventory.set(abi.encodeWithSignature("referencePublisher()"), abi.encode(c.targets[9]));
        inventory.set(abi.encodeWithSignature("artifactCoverage()"), abi.encode(c.targets[20]));
        inventory.set(abi.encodeWithSignature("externalCoverage()"), abi.encode(c.targets[21]));
    }

    function _publish(bytes32 profile) internal {
        c.inventoryDependencyHash = O.inventoryDependencyHash(profile, sd, od);
        bytes32 coverageProfile = profile == O.INVENTORY_PROFILE
            || profile == O.POLICY_INVENTORY_PROFILE
            ? O.COVERAGE_PROFILE
            : keccak256("6529STREAM_MULTI_ORIGIN_SCOPED_BUNDLE_IMMUTABLE_STOP_AGGREGATE_V1");
        inventory.set(abi.encodeWithSignature("dependencies()"), abi.encode(sd));
        inventory.set(abi.encodeWithSignature("originDependencies()"), abi.encode(od));
        inventory.set(abi.encodeWithSignature("originProfile()"), abi.encode(profile));
        inventory.set(
            abi.encodeWithSignature("dependencyHash()"), abi.encode(c.inventoryDependencyHash)
        );
        bundle.set(abi.encodeWithSignature("dependencies()"), abi.encode(bd));
        bundle.set(abi.encodeWithSignature("originDependencies()"), abi.encode(od));
        bundle.set(abi.encodeWithSignature("originProfile()"), abi.encode(coverageProfile));
        bundle.set(abi.encodeWithSignature("INVENTORY_PROFILE()"), abi.encode(profile));
        bundle.set(
            abi.encodeWithSignature("dependencyHash()"),
            abi.encode(keccak256(abi.encode(coverageProfile, profile, bd, od)))
        );
    }

    function _reject(bytes memory input, bytes4 selector) internal {
        (bool ok, bytes memory result) = address(harness).call(input);
        require(!ok && result.length >= 4 && bytes4(result) == selector, "exact rejection required");
    }
}

contract StreamFinalityMultiOriginConfigurationTest is FinalityMultiOriginFixture {
    function testAllFourExplicitProfilesBindFullConfigurationAndCoverage() public {
        bytes32[4] memory profiles = [
            O.INVENTORY_PROFILE,
            O.SCOPED_INVENTORY_PROFILE,
            O.POLICY_INVENTORY_PROFILE,
            O.SCOPED_POLICY_INVENTORY_PROFILE
        ];
        bytes32 previous;
        for (uint256 i; i < profiles.length; ++i) {
            _publish(profiles[i]);
            (S.Dependencies memory actual, O.Dependencies memory origin) =
                harness.configuration(c, profiles[i]);
            require(keccak256(abi.encode(actual)) == keccak256(abi.encode(sd)));
            require(keccak256(abi.encode(origin)) == keccak256(abi.encode(od)));
            require(c.inventoryDependencyHash != previous);
            previous = c.inventoryDependencyHash;
        }
    }

    function testLegacyBaseOnlyHashCannotMasqueradeAsAdditiveProfile() public {
        _reject(abi.encodeCall(harness.legacy, (c)), Native.NativeProviderDependency.selector);
        c.inventoryDependencyHash = keccak256(abi.encode(sd));
        _reject(
            abi.encodeCall(harness.configuration, (c, O.INVENTORY_PROFILE)),
            Configuration.InvalidFinalityArchiveConfiguration.selector
        );
    }

    function testCommonSourceAndArtistMappingsRejectEvenWithRecomputedHash() public {
        sd.targets[9] = address(worker);
        sd.codeHashes[9] = address(worker).codehash;
        _publish(O.INVENTORY_PROFILE);
        _reject(
            abi.encodeCall(harness.configuration, (c, O.INVENTORY_PROFILE)),
            Configuration.InvalidFinalityArchiveConfiguration.selector
        );
        sd.targets[9] = c.targets[17];
        sd.codeHashes[9] = c.codeHashes[17];
        sd.artistTargets[0] = address(worker);
        sd.artistCodeHashes[0] = address(worker).codehash;
        _publish(O.INVENTORY_PROFILE);
        _reject(
            abi.encodeCall(harness.configuration, (c, O.INVENTORY_PROFILE)),
            Configuration.InvalidFinalityArchiveConfiguration.selector
        );
    }

    function testBundleProfileWorkerArchiveAndHashMustBeExactlyReciprocal() public {
        bytes memory key = abi.encodeWithSignature("INVENTORY_PROFILE()");
        bundle.set(key, abi.encode(O.SCOPED_INVENTORY_PROFILE));
        _reject(
            abi.encodeCall(harness.configuration, (c, O.INVENTORY_PROFILE)),
            Configuration.InvalidFinalityArchiveConfiguration.selector
        );
        _publish(O.INVENTORY_PROFILE);
        O.Dependencies memory wrong = od;
        wrong.originGas += 1;
        bundle.set(abi.encodeWithSignature("originDependencies()"), abi.encode(wrong));
        _reject(
            abi.encodeCall(harness.configuration, (c, O.INVENTORY_PROFILE)),
            Configuration.InvalidFinalityArchiveConfiguration.selector
        );
        _publish(O.INVENTORY_PROFILE);
        bd.targets[5] = address(worker);
        bd.codeHashes[5] = address(worker).codehash;
        _publish(O.INVENTORY_PROFILE);
        _reject(
            abi.encodeCall(harness.configuration, (c, O.INVENTORY_PROFILE)),
            Configuration.InvalidFinalityArchiveConfiguration.selector
        );
        bd.targets[5] = sd.artistTargets[4];
        bd.codeHashes[5] = sd.artistCodeHashes[4];
        _publish(O.INVENTORY_PROFILE);
        bundle.set(abi.encodeWithSignature("dependencyHash()"), abi.encode(bytes32(uint256(1))));
        _reject(
            abi.encodeCall(harness.configuration, (c, O.INVENTORY_PROFILE)),
            Configuration.InvalidFinalityArchiveConfiguration.selector
        );
    }

    function testOriginalFinalityRuntimePinAndWorkerRuntimeRemainRequired() public {
        bytes32 saved = c.codeHashes[12];
        c.codeHashes[12] = keccak256("wrong original Finality runtime");
        _reject(
            abi.encodeCall(harness.configuration, (c, O.INVENTORY_PROFILE)),
            Configuration.InvalidFinalityArchiveConfiguration.selector
        );
        c.codeHashes[12] = saved;
        vm.etch(address(worker), hex"00");
        _reject(
            abi.encodeCall(harness.configuration, (c, O.INVENTORY_PROFILE)),
            Configuration.InvalidFinalityArchiveConfiguration.selector
        );
    }

    function testMalformedBaseAndUnknownProfileFailClosed() public {
        _reject(
            abi.encodeCall(harness.configuration, (c, bytes32(uint256(1)))),
            Configuration.InvalidFinalityArchiveConfiguration.selector
        );
        inventory.set(abi.encodeWithSignature("dependencies()"), abi.encode(sd.chainId));
        _reject(
            abi.encodeCall(harness.configuration, (c, O.INVENTORY_PROFILE)),
            bytes4(keccak256("FinalityReadFailed(address)"))
        );
    }
}
