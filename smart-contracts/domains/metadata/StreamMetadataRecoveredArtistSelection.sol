// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    IStreamCollectionMetadataV1 as M
} from "../../interfaces/stream/metadata/IStreamCollectionMetadataV1.sol";
import { IStreamArtistHistory } from "../../interfaces/stream/artist/IStreamArtistHistory.sol";
import {
    IStreamArtistIngressBinding
} from "../../interfaces/stream/artist/IStreamArtistIngressBinding.sol";
import {
    IStreamArtistRecoveredHydrationOwner as R
} from "../../interfaces/stream/artist/IStreamArtistRecoveredHydration.sol";
import {
    StreamArtistRecoveredHydrationTypes as RH
} from "../../interfaces/stream/artist/StreamArtistRecoveredHydrationTypes.sol";
import {
    StreamArtistOnboardingTypes as T
} from "../../interfaces/stream/artist/StreamArtistOnboardingTypes.sol";
import { StreamMetadataArtistConfiguration } from "./StreamMetadataArtistConfiguration.sol";

/// @notice Original Metadata ancestry through the actual complete recovered op60 prefix.
/// @dev The enclosing selector authenticates the original/current runtime, current suite,
/// Router and all seven matching completion markers. This adds no publication authority:
/// the original Metadata host still consumes original authorization IDs and record domains.
library StreamMetadataRecoveredArtistSelection {
    function requireAncestor(
        address core,
        address original,
        address current,
        T.SuiteConfiguration memory next,
        uint256 cap
    ) public view {
        _predecessor(current, original, cap);
        address coordinator = abi.decode(
            _read(
                original,
                abi.encodeCall(IStreamArtistIngressBinding.operationCoordinator, ()),
                32,
                cap
            ),
            (address)
        );
        T.SuiteConfiguration memory source =
            StreamMetadataArtistConfiguration.suite(coordinator, cap);
        if (
            source.registry != original || source.core != core || next.registry != current
                || source.mintManager != next.mintManager
                || source.roleRegistry != next.roleRegistry || source.metadata != next.metadata
                || source.primaryResolver != next.primaryResolver
                || source.royaltyResolver != next.royaltyResolver
                || source.primaryRevenueClass != next.primaryRevenueClass
                || source.validator != next.validator
        ) revert M.MetadataHostNotSelected();
        RH.OriginEnvironment memory origin;
        origin.chainId = block.chainid;
        origin.registry = original;
        origin.coordinator = coordinator;
        origin.archive = source.archive;
        origin.owners = source.owners;
        for (uint256 i; i < 7; ++i) {
            origin.ownerCodeHashes[i] = source.owners[i].codehash;
        }
        origin.core = core;
        origin.manager = source.mintManager;
        origin.suiteConfigurationHash = keccak256(abi.encode(source));
        bytes32 hash = RH.originHash(origin);
        bytes memory raw =
            _read(next.owners[2], abi.encodeCall(R.recoveredHydrationOrigin, (hash)), 672, cap);
        RH.OriginEnvironment memory saved = abi.decode(raw, (RH.OriginEnvironment));
        if (keccak256(raw) != keccak256(abi.encode(saved)) || RH.originHash(saved) != hash) {
            revert M.MetadataHostNotSelected();
        }
        // original != current, so the owner's local-origin branch cannot satisfy this query.
        // The only imported-origin producer is immutable installOwnerPrefix during complete
        // op60. Its source certificate joins the flattened original eras and all seven owners;
        // the enclosing selector checks every actual nonzero completion marker. No dynamic
        // journal or unbounded predecessor walk is read at publication time.
    }

    function _predecessor(address current, address original, uint256 cap) private view {
        if (
            abi.decode(
                    _read(
                        current,
                        abi.encodeCall(IStreamArtistHistory.importedHistoryBindingCount, ()),
                        32,
                        cap
                    ),
                    (uint256)
                ) != 1
        ) {
            revert M.MetadataHostNotSelected();
        }
        (address prior, uint64 snapshot, bytes32 root, bytes32 manifest) = abi.decode(
            _read(
                current, abi.encodeCall(IStreamArtistHistory.importedHistoryBinding, (0)), 128, cap
            ),
            (address, uint64, bytes32, bytes32)
        );
        if (
            prior == address(0) || prior == original || prior == current || prior.code.length == 0
                || snapshot == 0 || root == 0 || manifest == 0
        ) revert M.MetadataHostNotSelected();
        (bool bound, bytes32 runtime, uint256 count) = abi.decode(
            _read(
                current,
                abi.encodeCall(IStreamArtistHistory.artistHistoryPredecessorBinding, (prior)),
                96,
                cap
            ),
            (bool, bytes32, uint256)
        );
        if (!bound || count != 1 || prior.codehash != runtime) revert M.MetadataHostNotSelected();
        (bool sealed_, address successor, uint64 sealedAt) = abi.decode(
            _read(prior, abi.encodeCall(IStreamArtistHistory.artistRegistryCutover, ()), 96, cap),
            (bool, address, uint64)
        );
        if (!sealed_ || successor != current || sealedAt == 0 || snapshot > sealedAt) {
            revert M.MetadataHostNotSelected();
        }
    }

    function _read(address target, bytes memory input, uint256 length, uint256 cap)
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
            ok := staticcall(cap, target, add(input, 32), mload(input), add(data, 32), length)
            size := returndatasize()
        }
        if (!ok || size != length) revert M.MetadataReadFailed(target);
    }
}
