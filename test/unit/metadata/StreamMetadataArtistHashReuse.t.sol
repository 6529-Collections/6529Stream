// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    StreamArtistOnboardingTypes as T
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistOnboardingTypes.sol";
import {
    IStreamCollectionMetadataV1 as M
} from "../../../smart-contracts/interfaces/stream/metadata/IStreamCollectionMetadataV1.sol";
import {
    StreamMetadataArtistConfiguration as Current
} from "../../../smart-contracts/domains/metadata/StreamMetadataArtistConfiguration.sol";

contract MetadataHashRuntimeProbe {
    uint256 public immutable salt;

    constructor(uint256 s) {
        salt = s;
    }
}

/// @notice Exact f650 constructor-preimage oracle, independent of the new helper call.
contract MetadataHashReuseProbe {
    function facts(
        address coordinator,
        T.SuiteConfiguration memory suite,
        address finality,
        address provider
    ) public view returns (bytes32, bytes32[16] memory, bytes32) {
        (bytes32 hash, bytes32[16] memory runtimeHashes) =
            Current.hashAndRuntime(coordinator, suite, finality, provider);
        require(Current.hash(coordinator, suite, finality, provider) == hash, "old API changed");
        return (hash, runtimeHashes, keccak256(abi.encode(suite)));
    }

    function originalHash(
        address coordinator,
        T.SuiteConfiguration memory suite,
        address finality,
        address provider
    ) public view returns (bytes32) {
        address[16] memory targets;
        for (uint256 i; i < 7; ++i) {
            targets[i] = suite.owners[i];
        }
        targets[7] = suite.registry;
        targets[8] = suite.archive;
        targets[9] = suite.core;
        targets[10] = suite.mintManager;
        targets[11] = suite.roleRegistry;
        targets[12] = suite.metadata;
        targets[13] = suite.primaryResolver;
        targets[14] = suite.royaltyResolver;
        targets[15] = suite.validator;
        bytes32[16] memory runtimeHashes;
        for (uint256 i; i < 16; ++i) {
            if (targets[i].code.length == 0) revert M.MetadataHostNotSelected();
            runtimeHashes[i] = targets[i].codehash;
        }
        bytes32 providerCodeHash = provider.codehash;
        return keccak256(
            abi.encode(
                keccak256("6529STREAM_ARTIST_ONBOARDING_CONFIGURATION_V1"),
                block.chainid,
                coordinator,
                suite,
                runtimeHashes,
                finality,
                finality.codehash,
                provider,
                providerCodeHash,
                uint16(1),
                uint16(2),
                uint16(3),
                uint16(4),
                uint16(5),
                uint16(6),
                uint16(7),
                uint16(12),
                uint16(13),
                uint16(14),
                uint16(15),
                uint16(16),
                uint16(17),
                uint16(18),
                uint16(20),
                uint16(21),
                uint16(22),
                uint16(23),
                uint16(24),
                uint16(25),
                uint16(26),
                uint16(27),
                uint16(28),
                uint16(29),
                uint16(30),
                uint16(31),
                uint16(32),
                uint16(33),
                uint16(34),
                uint16(35),
                uint16(36),
                uint16(37),
                uint16(38),
                uint16(39),
                uint16(40),
                uint16(51),
                uint16(52),
                uint16(54),
                uint16(58),
                uint16(65534),
                keccak256("6529STREAM_ARTIST_RECOVERY_PREPARATION_PROFILE_V1"),
                keccak256("6529STREAM_ARTIST_RECOVERY_GUARDIAN_HISTORY_PROFILE_V1"),
                keccak256("6529STREAM_ARTIST_RECOVERY_FIRST_ROTATION_PROFILE_V1"),
                keccak256("6529STREAM_ARTIST_RECOVERY_HISTORICAL_ROTATION_PROFILE_V1"),
                keccak256("6529STREAM_ARTIST_GUARDIAN_VESTING_PROFILE_V1"),
                keccak256("6529STREAM_ARTIST_GUARDIAN_SUPERSESSION_PROFILE_V1"),
                keccak256("6529STREAM_ARTIST_GUARDIAN_HEAD_SELECTION_PROFILE_V1"),
                keccak256("6529STREAM_ARTIST_GUARDIAN_ROOT_APPEAL_PROFILE_V1"),
                keccak256("6529STREAM_ARTIST_FIRST_ESTATE_RECOVERY_PROFILE_V1"),
                keccak256("6529STREAM_ARTIST_ESTATE_SUCCESSOR_GUARDIAN_RECOVERY_PROFILE_V1")
            )
        );
    }
}

/// @dev Read/hash-only tests. Deployed typed targets provide runtime identities, no Artist authority.
contract StreamMetadataArtistHashReuseTest {
    MetadataHashReuseProbe private probe;
    address[4] private targets;

    function setUp() public {
        probe = new MetadataHashReuseProbe();
        for (uint256 i; i < 4; ++i) {
            targets[i] = address(new MetadataHashRuntimeProbe(i));
        }
    }

    function _suite(bytes32 seed) private view returns (T.SuiteConfiguration memory s) {
        s.registry = targets[uint8(seed[0]) % 4];
        s.archive = targets[uint8(seed[1]) % 4];
        s.core = targets[uint8(seed[2]) % 4];
        s.mintManager = targets[uint8(seed[3]) % 4];
        s.roleRegistry = targets[uint8(seed[4]) % 4];
        s.metadata = targets[uint8(seed[5]) % 4];
        s.primaryResolver = targets[uint8(seed[6]) % 4];
        s.royaltyResolver = targets[uint8(seed[7]) % 4];
        s.primaryRevenueClass = seed;
        s.validator = targets[uint8(seed[8]) % 4];
        for (uint256 i; i < 7; ++i) {
            s.owners[i] = targets[uint8(seed[9 + i]) % 4];
        }
    }

    function testFuzzExactConstructorHashAndRuntimeFacts(bytes32 seed, address coordinator)
        public
        view
    {
        T.SuiteConfiguration memory s = _suite(seed);
        address finality = targets[uint8(seed[16]) % 4];
        address provider = targets[uint8(seed[17]) % 4];
        (bytes32 actual, bytes32[16] memory hashes, bytes32 suiteHash) =
            probe.facts(coordinator, s, finality, provider);
        require(
            actual == probe.originalHash(coordinator, s, finality, provider), "original preimage"
        );
        require(suiteHash == keccak256(abi.encode(s)), "suite preimage");
        for (uint256 i; i < 7; ++i) {
            require(hashes[i] == s.owners[i].codehash, "owner order");
        }
        require(
            hashes[7] == s.registry.codehash && hashes[8] == s.archive.codehash
                && hashes[9] == s.core.codehash,
            "registry/archive/core order"
        );
        require(
            hashes[10] == s.mintManager.codehash && hashes[11] == s.roleRegistry.codehash
                && hashes[12] == s.metadata.codehash,
            "manager/role/metadata order"
        );
        require(
            hashes[13] == s.primaryResolver.codehash && hashes[14] == s.royaltyResolver.codehash
                && hashes[15] == s.validator.codehash,
            "resolver/validator order"
        );
    }

    function testCodeMissingOwnerAndDependencyRetainOriginalRefusal() public view {
        T.SuiteConfiguration memory s = _suite(bytes32(uint256(1)));
        s.owners[6] = address(0);
        _sameRefusal(s);
        s = _suite(bytes32(uint256(1)));
        s.validator = address(0);
        _sameRefusal(s);
    }

    function _sameRefusal(T.SuiteConfiguration memory s) private view {
        (bool ok, bytes memory result) = address(probe)
            .staticcall(abi.encodeCall(probe.facts, (address(this), s, targets[0], targets[1])));
        (bool oldOK, bytes memory oldResult) = address(probe)
            .staticcall(
                abi.encodeCall(probe.originalHash, (address(this), s, targets[0], targets[1]))
            );
        require(!ok && !oldOK && keccak256(result) == keccak256(oldResult), "refusal changed");
        require(
            result.length == 4 && bytes4(result) == M.MetadataHostNotSelected.selector,
            "exact original error"
        );
    }
}
