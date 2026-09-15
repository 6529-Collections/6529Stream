// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { IStreamCorePointers } from "../../interfaces/stream/core/IStreamCorePointers.sol";
import {
    IStreamCollectionMetadataV1 as M
} from "../../interfaces/stream/metadata/IStreamCollectionMetadataV1.sol";
import { IStreamArtistHistory } from "../../interfaces/stream/artist/IStreamArtistHistory.sol";
import {
    IStreamArtistIngressBinding
} from "../../interfaces/stream/artist/IStreamArtistIngressBinding.sol";
import { IStreamArtistOwner } from "../../interfaces/stream/artist/IStreamArtistOwner.sol";
import {
    IStreamArtistAuthorityHydrationCoordinator,
    IStreamArtistAuthorityHydrationOwner
} from "../../interfaces/stream/artist/IStreamArtistAuthorityHydration.sol";
import {
    StreamArtistOnboardingTypes as T
} from "../../interfaces/stream/artist/StreamArtistOnboardingTypes.sol";

import { StreamMetadataArtistConfiguration } from "./StreamMetadataArtistConfiguration.sol";

/// @notice Same-Metadata publication through its original Artist or one completely hydrated successor.
/// @dev Reads only. Metadata retains its original authorization-use map and candidate domains.
library StreamMetadataArtistSelection {
    struct Context {
        address core;
        bytes32 coreHash;
        address original;
        bytes32 originalHash;
        uint256 gasCap;
    }

    struct Selected {
        address registry;
        bytes32 runtimeHash;
    }

    function selected(Context memory c) public view returns (Selected memory s) {
        _code(c.core, c.coreHash);
        _code(c.original, c.originalHash);
        bytes memory raw = _read(
            c,
            c.core,
            abi.encodeCall(IStreamCorePointers.getSatellitePointer, (keccak256("ARTIST_REGISTRY"))),
            320
        );
        (s.registry, s.runtimeHash,,,,,,,,) = abi.decode(
            raw, (address, bytes32, bool, bytes32, bytes4, address, uint8, bytes32, bytes32, uint64)
        );
        _code(s.registry, s.runtimeHash);
        // Earlier Metadata/Artist suites need no hydration API for their original selection.
        if (s.registry == c.original) {
            if (s.runtimeHash != c.originalHash) revert M.MetadataHostNotSelected();
            return s;
        }
        (bool sourceSealed, address successor, uint64 sealedAt) = abi.decode(
            _read(
                c, c.original, abi.encodeCall(IStreamArtistHistory.artistRegistryCutover, ()), 96
            ),
            (bool, address, uint64)
        );
        if (!sourceSealed || successor != s.registry || sealedAt == 0) {
            revert M.MetadataHostNotSelected();
        }
        if (
            _word(
                    c,
                    s.registry,
                    abi.encodeCall(IStreamArtistHistory.importedHistoryBindingCount, ())
                ) != 1
        ) revert M.MetadataHostNotSelected();
        (address predecessor, uint64 snapshot, bytes32 root, bytes32 manifest) = abi.decode(
            _read(
                c, s.registry, abi.encodeCall(IStreamArtistHistory.importedHistoryBinding, (0)), 128
            ),
            (address, uint64, bytes32, bytes32)
        );
        (bool bound, bytes32 sourceHash, uint256 count) = abi.decode(
            _read(
                c,
                s.registry,
                abi.encodeCall(IStreamArtistHistory.artistHistoryPredecessorBinding, (c.original)),
                96
            ),
            (bool, bytes32, uint256)
        );
        if (
            predecessor != c.original || snapshot == 0 || snapshot > sealedAt || root == 0
                || manifest == 0 || !bound || sourceHash != c.originalHash || count != 1
        ) revert M.MetadataHostNotSelected();
        (address nextCoordinator, T.SuiteConfiguration memory next) = _suite(c, s.registry);
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
            revert M.MetadataHostNotSelected();
        }
        // All actual op60 profiles share Source._prepare/SourceGuards._suite and
        // Commit.execute: the exact sealed predecessor, all eight unchanged suite
        // dependencies, and each source owner's reciprocal binding/domain are
        // checked before the seven owner imports, then rechecked before atomic
        // Archive completion. The one-time marker below has no other producer.
        // Both suites/owner bindings are constructor-only. Thus committed op60
        // proves the original relationship without a live read of its old suite.
        // This is committed-state provenance, not an in-flight reentrancy barrier.
        // Artist's metadata dependency is the rendering Router, not this record host.
        (address router, bytes32 routerHash,,,,,,,,) = abi.decode(
            _read(
                c,
                c.core,
                abi.encodeCall(
                    IStreamCorePointers.getSatellitePointer, (keccak256("METADATA_ROUTER"))
                ),
                320
            ),
            (address, bytes32, bool, bytes32, bytes4, address, uint8, bytes32, bytes32, uint64)
        );
        if (router != next.metadata) revert M.MetadataHostNotSelected();
        _code(router, routerHash);
        if (
            abi.decode(_read(c, router, abi.encodeCall(IStreamArtistOwner.core, ()), 32), (address))
                != c.core
        ) revert M.MetadataHostNotSelected();
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
                revert M.MetadataHostNotSelected();
            }
            completion = actual;
        }
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
        s = StreamMetadataArtistConfiguration.suite(coordinator, c.gasCap);
        if (
            s.registry != registry || s.core != c.core || s.metadata == address(0)
                || s.archive.code.length == 0 || s.mintManager == address(0)
        ) revert M.MetadataHostNotSelected();
    }

    function _word(Context memory c, address target, bytes memory input)
        private
        view
        returns (uint256)
    {
        return abi.decode(_read(c, target, input, 32), (uint256));
    }

    function _code(address target, bytes32 expected) private view {
        if (target.code.length == 0 || target.codehash != expected) {
            revert M.MetadataDependencyChanged(target);
        }
    }

    // Host-owned dependency budget; fixed responses never allocate from returned data.
    function _read(Context memory c, address target, bytes memory input, uint256 length)
        private
        view
        returns (bytes memory data)
    {
        uint256 cap = c.gasCap;
        if (
            target.code.length == 0 || cap == 0 || cap == type(uint256).max
                || gasleft() <= cap + cap / 63 + 10000
        ) revert M.MetadataReadFailed(target);
        data = new bytes(length);
        bool ok;
        uint256 size;
        assembly ("memory-safe") {
            ok := staticcall(cap, target, add(input, 32), mload(input), add(data, 32), length)
            size := returndatasize()
        }
        if (!ok || size != length) revert M.MetadataReadFailed(target);
    }
}
