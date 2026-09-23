// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import { IStreamCore } from "../../interfaces/stream/core/IStreamCore.sol";
import {
    IStreamEntropyCollectionPolicy as P
} from "../../interfaces/stream/entropy/IStreamEntropyCollectionPolicy.sol";
import {
    IStreamArtistContentHostEvidence as A
} from "../../interfaces/stream/artist/IStreamArtistContentHostEvidence.sol";
import {
    IStreamArtistAttributionState as B
} from "../../interfaces/stream/artist/IStreamArtistAttributionState.sol";
import { StreamEntropyCollectionPolicyState as S } from "./StreamEntropyCollectionPolicyState.sol";
import {
    IStreamMintGovernanceRegistry as G
} from "../../interfaces/stream/mint/IStreamMintGovernanceRegistry.sol";

/// @notice Bounded original op17 evidence for an already-bound Artist; never an unbound fallback.
library StreamEntropyCollectionPolicyAuthority {
    bytes32 private constant ARTIST_GAS = keccak256("6529STREAM_GGP_ARTIST_FINALITY_READ_GAS");

    function requireSelected(IStreamCore core) public view {
        (address selected, bytes32 hash,,,,, uint8 status,,, uint64 revision) =
            core.getSatellitePointer(keccak256("ENTROPY_COORDINATOR"));
        if (
            selected != address(this) || hash != address(this).codehash || status != 1
                || revision == 0
        ) {
            revert P.CollectionPolicyDependency(selected);
        }
    }

    function evidence(IStreamCore core, uint256 id, bytes32 next)
        public
        view
        returns (bytes32 record)
    {
        requireSelected(core);
        (address artist, bytes32 hash,,,,, uint8 status,,, uint64 revision) =
            core.getSatellitePointer(keccak256("ARTIST_REGISTRY"));
        if (artist.code.length == 0 || artist.codehash != hash || status != 1 || revision == 0) {
            revert P.CollectionPolicyDependency(artist);
        }
        if (
            abi.decode(_read(artist, abi.encodeWithSignature("core()"), 32, 100000), (uint256))
                != uint256(uint160(address(core)))
        ) {
            revert P.CollectionPolicyDependency(artist);
        }
        bytes memory raw = _read(
            artist, abi.encodeWithSignature("gasParameterInfo(bytes32)", ARTIST_GAS), 128, 100000
        );
        (uint256 cap, uint256 floor, uint256 failure, uint256 rev) =
            abi.decode(raw, (uint256, uint256, uint256, uint256));
        if (
            cap == 0 || cap == type(uint256).max || floor == 0 || cap < floor || failure != 2
                || rev == 0 || rev > type(uint64).max
        ) {
            revert P.CollectionPolicyDependency(artist);
        }
        raw = _read(artist, abi.encodeCall(B.collectionArtistState, (id)), 160, cap);
        (
            uint256 state,
            uint256 generation,
            bytes32 artistId,
            uint256 authorityStatus,
            bytes32 bindingHash
        ) = abi.decode(raw, (uint256, uint256, bytes32, uint256, bytes32));
        if (
            (state != 2 && state != 3) || generation == 0 || generation > type(uint64).max
                || artistId == 0 || authorityStatus > type(uint8).max || bindingHash == 0
        ) {
            revert P.CollectionPolicyArtistRequired(id);
        }
        // The selected original Artist host verifies current binding/authority/generation and exact terms.
        record = abi.decode(
            _read(
                artist,
                abi.encodeCall(
                    A.contentConsentEvidenceForHost, (id, address(this), S.FAMILY, next)
                ),
                32,
                cap
            ),
            (bytes32)
        );
        if (record == 0) revert P.CollectionPolicyArtistRequired(id);
    }

    function requireGovernance(IStreamCore core, address authority) public view {
        (address modules, bytes32 hash,,,,, uint8 status,,, uint64 revision) =
            core.getSatellitePointer(keccak256("MODULE_REGISTRY"));
        if (
            modules.code.length == 0 || modules.codehash != hash || status != 1 || revision == 0
                || abi.decode(
                        _read(modules, abi.encodeCall(G.governanceExecutor, ()), 32, 100000),
                        (uint256)
                    ) != uint256(uint160(authority))
        ) {
            revert P.CollectionPolicyDependency(modules);
        }
    }

    function _read(address target, bytes memory data, uint256 size, uint256 cap)
        private
        view
        returns (bytes memory result)
    {
        result = new bytes(size);
        uint256 available = gasleft();
        if (available <= 105000) revert P.CollectionPolicyDependency(target);
        if (cap > available - 105000) cap = available - 105000;
        bool ok;
        uint256 actual;
        assembly ("memory-safe") {
            ok := staticcall(cap, target, add(data, 32), mload(data), add(result, 32), size)
            actual := returndatasize()
        }
        if (!ok || actual != size) revert P.CollectionPolicyDependency(target);
    }
}
