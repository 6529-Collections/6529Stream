// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { IStreamArtistHistory } from "../../interfaces/stream/artist/IStreamArtistHistory.sol";
import {
    IStreamArtistIngressBinding
} from "../../interfaces/stream/artist/IStreamArtistIngressBinding.sol";
import {
    IStreamArtistAuthorityHydrationOwner
} from "../../interfaces/stream/artist/IStreamArtistAuthorityHydration.sol";
import {
    IStreamGasParameterHost
} from "../../interfaces/stream/parameters/IStreamGasParameterHost.sol";
import {
    StreamArtistOnboardingTypes as T
} from "../../interfaces/stream/artist/StreamArtistOnboardingTypes.sol";
import {
    IStreamRevenueArtistConfiguration
} from "../../interfaces/stream/revenue/IStreamRevenueArtistConfiguration.sol";

/// @notice Fixed current-consumer proof for one completely hydrated Artist successor.
/// @dev The Resolver keeps its original immutables, assignments and replay state. All
/// coordinates come from those immutables and the Core pointer, never user input.
library StreamRevenueArtistSelection {
    struct Context {
        address core;
        address original;
        bytes32 originalHash;
        address selected;
        bytes32 selectedHash;
        bool primary;
        bytes failure;
        uint256 gasCap;
    }

    function successor(Context memory c) public view returns (address) {
        _code(c, c.original, c.originalHash);
        _code(c, c.selected, c.selectedHash);
        // The original, runtime-pinned facade owns this existing op60/finality
        // read budget. Original-selection callers need neither this API nor op60.
        (c.gasCap,,,) = IStreamGasParameterHost(c.original)
            .gasParameterInfo(keccak256("6529STREAM_GGP_ARTIST_FINALITY_READ_GAS"));
        if (c.gasCap == 0 || c.gasCap == type(uint256).max) _fail(c);
        (bool sourceSealed, address successor, uint64 sealedAt) = abi.decode(
            _read(
                c, c.original, abi.encodeCall(IStreamArtistHistory.artistRegistryCutover, ()), 96
            ),
            (bool, address, uint64)
        );
        if (!sourceSealed || successor != c.selected || sealedAt == 0) {
            _fail(c);
        }
        if (
            _word(
                    c,
                    c.selected,
                    abi.encodeCall(IStreamArtistHistory.importedHistoryBindingCount, ())
                ) != 1
        ) _fail(c);
        (address predecessor, uint64 snapshot, bytes32 root, bytes32 manifest) = abi.decode(
            _read(
                c, c.selected, abi.encodeCall(IStreamArtistHistory.importedHistoryBinding, (0)), 128
            ),
            (address, uint64, bytes32, bytes32)
        );
        (bool bound, bytes32 sourceHash, uint256 count) = abi.decode(
            _read(
                c,
                c.selected,
                abi.encodeCall(IStreamArtistHistory.artistHistoryPredecessorBinding, (c.original)),
                96
            ),
            (bool, bytes32, uint256)
        );
        if (
            predecessor != c.original || snapshot == 0 || snapshot > sealedAt || root == 0
                || manifest == 0 || !bound || sourceHash != c.originalHash || count != 1
        ) _fail(c);
        (address nextCoordinator, T.SuiteConfiguration memory next) = _suite(c, c.selected);
        address priorCoordinator = abi.decode(
            _read(
                c,
                c.original,
                abi.encodeCall(IStreamArtistIngressBinding.operationCoordinator, ()),
                32
            ),
            (address)
        );
        if (priorCoordinator == address(0) || priorCoordinator == nextCoordinator) {
            _fail(c);
        }
        // All actual op60 profiles share Source._prepare/SourceGuards._suite and
        // Commit.execute: the exact sealed predecessor, all eight unchanged suite
        // dependencies, and each source owner's reciprocal binding/domain are
        // checked before the seven owner imports, then rechecked before atomic
        // Archive completion. The one-time marker below has no other producer.
        // Both suites/owner bindings are constructor-only. Thus committed op60
        // proves the original relationship without a live read of its old suite.
        // This is committed-state provenance, not an in-flight reentrancy barrier.
        bytes32 completion;
        for (uint256 i; i < 7; ++i) {
            // The current authentic Coordinator constructor validates all seven
            // immutable owner bindings and distinct targets; _suite above rechecks
            // every saved runtime pin. Different source/next registry bindings
            // prohibit sharing an owner. Keep every actual completion check.
            bytes32 actual = bytes32(
                _word(
                    c,
                    next.owners[i],
                    abi.encodeCall(
                        IStreamArtistAuthorityHydrationOwner.authorityHydrationCommitment, ()
                    )
                )
            );
            if (actual == 0 || (i != 0 && actual != completion)) {
                _fail(c);
            }
            completion = actual;
        }
        return c.selected;
    }

    function _suite(Context memory c, address registry)
        private
        view
        returns (address coordinator, T.SuiteConfiguration memory s)
    {
        coordinator = abi.decode(
            _read(
                c,
                registry,
                abi.encodeCall(IStreamArtistIngressBinding.operationCoordinator, ()),
                32
            ),
            (address)
        );
        s = _configuration(c, coordinator);
        if (
            s.registry != registry || s.core != c.core || s.metadata == address(0)
                || s.archive.code.length == 0 || s.mintManager == address(0)
                || (c.primary ? s.primaryResolver : s.royaltyResolver) != address(this)
        ) _fail(c);
    }

    function _word(Context memory c, address target, bytes memory input)
        private
        view
        returns (uint256)
    {
        return abi.decode(_read(c, target, input, 32), (uint256));
    }

    function _configuration(Context memory c, address coordinator)
        private
        view
        returns (T.SuiteConfiguration memory s)
    {
        bytes memory raw = _read(
            c,
            coordinator,
            abi.encodeCall(IStreamRevenueArtistConfiguration.suiteConfiguration, ()),
            544
        );
        s = abi.decode(raw, (T.SuiteConfiguration));
        if (keccak256(raw) != keccak256(abi.encode(s))) _fail(c);
        address finality = abi.decode(
            _read(
                c,
                coordinator,
                abi.encodeCall(IStreamRevenueArtistConfiguration.finalityRegistry, ()),
                32
            ),
            (address)
        );
        address provider = abi.decode(
            _read(
                c,
                coordinator,
                abi.encodeCall(IStreamRevenueArtistConfiguration.finalityEvidenceProvider, ()),
                32
            ),
            (address)
        );
        bytes32 actual = bytes32(
            _word(
                c,
                coordinator,
                abi.encodeCall(IStreamRevenueArtistConfiguration.configurationHash, ())
            )
        );
        if (
            finality.code.length == 0 || provider.code.length == 0
                || actual != _configurationHash(c, coordinator, s, finality, provider)
        ) _fail(c);
    }

    function _configurationHash(
        Context memory c,
        address coordinator,
        T.SuiteConfiguration memory suite,
        address finality,
        address provider
    ) private view returns (bytes32) {
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
            if (targets[i].code.length == 0) _fail(c);
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

    function _code(Context memory c, address target, bytes32 expected) private view {
        if (expected == 0 || target.code.length == 0 || target.codehash != expected) _fail(c);
    }

    /// @dev Fixed response allocation, live governed ceiling, and an explicit local
    /// decoding/error reserve. EIP-150 may clip the ceiling when less gas suffices.
    function _read(Context memory c, address target, bytes memory input, uint256 length)
        private
        view
        returns (bytes memory data)
    {
        if (target.code.length == 0 || gasleft() <= 10000) _fail(c);
        data = new bytes(length);
        uint256 cap = c.gasCap;
        uint256 available = gasleft();
        if (available <= 10000) _fail(c);
        if (cap > available - 10000) cap = available - 10000;
        bool ok;
        uint256 size;
        assembly ("memory-safe") {
            ok := staticcall(cap, target, add(input, 32), mload(input), add(data, 32), length)
            size := returndatasize()
        }
        if (!ok || size != length) _fail(c);
    }

    function _fail(Context memory c) private pure {
        bytes memory reason = c.failure;
        assembly ("memory-safe") { revert(add(reason, 32), mload(reason)) }
    }
}
