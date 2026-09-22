// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamArtistOnboardingTypes as T
} from "../../interfaces/stream/artist/StreamArtistOnboardingTypes.sol";
import {
    IStreamCollectionMetadataV1 as M
} from "../../interfaces/stream/metadata/IStreamCollectionMetadataV1.sol";
import {
    IStreamMetadataArtistConfiguration
} from "../../interfaces/stream/metadata/IStreamMetadataArtistConfiguration.sol";

/// @notice Authenticates the actual original Coordinator constructor commitment.
/// @dev The preimage is byte-exact to StreamArtistOnboardingCoordinator's original
/// configurationHash. Live target hashes retain all16 runtime pins without reading
/// duplicate stored target/hash arrays. No new Coordinator API or gas cap is used.
library StreamMetadataArtistConfiguration {
    function suite(address coordinator, uint256 cap)
        public
        view
        returns (T.SuiteConfiguration memory s)
    {
        bytes memory raw = _read(
            coordinator, IStreamMetadataArtistConfiguration.suiteConfiguration.selector, 544, cap
        );
        s = abi.decode(raw, (T.SuiteConfiguration));
        if (keccak256(raw) != keccak256(abi.encode(s))) revert M.MetadataHostNotSelected();
        address finality = abi.decode(
            _read(
                coordinator, IStreamMetadataArtistConfiguration.finalityRegistry.selector, 32, cap
            ),
            (address)
        );
        address provider = abi.decode(
            _read(
                coordinator,
                IStreamMetadataArtistConfiguration.finalityEvidenceProvider.selector,
                32,
                cap
            ),
            (address)
        );
        bytes32 actual = abi.decode(
            _read(
                coordinator, IStreamMetadataArtistConfiguration.configurationHash.selector, 32, cap
            ),
            (bytes32)
        );
        if (
            finality.code.length == 0 || provider.code.length == 0
                || actual != hash(coordinator, s, finality, provider)
        ) revert M.MetadataHostNotSelected();
    }

    function hash(
        address coordinator,
        T.SuiteConfiguration memory suite,
        address finality,
        address provider
    ) internal view returns (bytes32) {
        (bytes32 result,) = hashAndRuntime(coordinator, suite, finality, provider);
        return result;
    }

    /// @dev Return the runtime facts authenticated by the original constructor hash so a
    /// fixed caller can reuse them without a second set of code reads. Same encoding/checks.
    function hashAndRuntime(
        address coordinator,
        T.SuiteConfiguration memory suite,
        address finality,
        address provider
    ) internal view returns (bytes32 result, bytes32[16] memory runtimeHashes) {
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
        for (uint256 i; i < 16; ++i) {
            if (targets[i].code.length == 0) revert M.MetadataHostNotSelected();
            runtimeHashes[i] = targets[i].codehash;
        }
        bytes32 providerCodeHash = provider.codehash;
        result = keccak256(
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

    function _read(address target, bytes4 selector, uint256 length, uint256 cap)
        private
        view
        returns (bytes memory data)
    {
        if (
            target.code.length == 0 || cap == 0 || cap == type(uint256).max
                || gasleft() <= cap + cap / 63 + 10000
        ) revert M.MetadataReadFailed(target);
        data = new bytes(length);
        bool ok;
        uint256 size;
        assembly ("memory-safe") {
            let ptr := mload(0x40)
            mstore(ptr, selector)
            ok := staticcall(cap, target, ptr, 4, add(data, 32), length)
            size := returndatasize()
        }
        if (!ok || size != length) revert M.MetadataReadFailed(target);
    }
}
