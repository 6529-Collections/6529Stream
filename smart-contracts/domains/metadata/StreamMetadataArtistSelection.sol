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
        (address priorCoordinator, T.SuiteConfiguration memory prior) = _suite(c, c.original);
        (address nextCoordinator, T.SuiteConfiguration memory next) = _suite(c, s.registry);
        if (
            priorCoordinator == nextCoordinator || prior.archive == next.archive
                || keccak256(
                        abi.encode(
                            prior.core,
                            prior.mintManager,
                            prior.roleRegistry,
                            prior.metadata,
                            prior.primaryResolver,
                            prior.royaltyResolver,
                            prior.primaryRevenueClass,
                            prior.validator
                        )
                    )
                    != keccak256(
                        abi.encode(
                            next.core,
                            next.mintManager,
                            next.roleRegistry,
                            next.metadata,
                            next.primaryResolver,
                            next.royaltyResolver,
                            next.primaryRevenueClass,
                            next.validator
                        )
                    )
        ) revert M.MetadataHostNotSelected();
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
        if (router != prior.metadata) revert M.MetadataHostNotSelected();
        _code(router, routerHash);
        if (
            abi.decode(_read(c, router, abi.encodeCall(IStreamArtistOwner.core, ()), 32), (address))
                != c.core
        ) revert M.MetadataHostNotSelected();
        bytes32 completion;
        for (uint256 i; i < 7; ++i) {
            if (prior.owners[i] == next.owners[i]) revert M.MetadataHostNotSelected();
            bytes32 domain = _owner(c, prior, priorCoordinator, i);
            if (_owner(c, next, nextCoordinator, i) != domain || domain == 0) {
                revert M.MetadataHostNotSelected();
            }
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
        bytes memory raw = _read(
            c,
            coordinator,
            abi.encodeCall(IStreamArtistAuthorityHydrationCoordinator.authorityHydrationSuite, ()),
            544
        );
        s = abi.decode(raw, (T.SuiteConfiguration));
        if (
            keccak256(raw) != keccak256(abi.encode(s)) || s.registry != registry || s.core != c.core
                || s.metadata == address(0) || s.archive.code.length == 0
                || s.mintManager == address(0)
        ) revert M.MetadataHostNotSelected();
    }

    function _owner(Context memory c, T.SuiteConfiguration memory s, address coordinator, uint256 i)
        private
        view
        returns (bytes32)
    {
        address owner = s.owners[i];
        if (
            abi.decode(
                        _read(c, owner, abi.encodeCall(IStreamArtistOwner.artistRegistry, ()), 32),
                        (address)
                    ) != s.registry
                || abi.decode(
                        _read(
                            c,
                            owner,
                            abi.encodeCall(IStreamArtistOwner.operationCoordinator, ()),
                            32
                        ),
                        (address)
                    ) != coordinator
                || abi.decode(
                        _read(c, owner, abi.encodeCall(IStreamArtistOwner.archiveV2, ()), 32),
                        (address)
                    ) != s.archive
                || abi.decode(
                        _read(c, owner, abi.encodeCall(IStreamArtistOwner.core, ()), 32), (address)
                    ) != s.core
                || abi.decode(
                        _read(c, owner, abi.encodeCall(IStreamArtistOwner.mintManager, ()), 32),
                        (address)
                    ) != s.mintManager
                || _word(c, owner, abi.encodeCall(IStreamArtistOwner.deploymentChainId, ()))
                    != block.chainid
        ) revert M.MetadataHostNotSelected();
        return bytes32(_word(c, owner, abi.encodeCall(IStreamArtistOwner.domainId, ())));
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
