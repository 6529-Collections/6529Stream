// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamCurrentAuthorityInventoryTypes as D
} from "../../interfaces/stream/preservation/StreamCurrentAuthorityInventoryTypes.sol";
import {
    StreamArtistCurrentAuthorityTypes as C
} from "../../interfaces/stream/artist/StreamArtistCurrentAuthorityTypes.sol";
import {
    StreamRenderCriticalSourceTypes as S
} from "../../interfaces/stream/preservation/StreamRenderCriticalSourceTypes.sol";
import {
    StreamArtistArchiveOriginTypes as O
} from "../../interfaces/stream/preservation/StreamArtistArchiveOriginTypes.sol";
import {
    IStreamArtistCurrentAuthorityResolver as Resolver
} from "../../interfaces/stream/preservation/IStreamArtistCurrentAuthorityResolver.sol";
import {
    IStreamRecordCurrentAuthority as Selector
} from "../../interfaces/stream/metadata/IStreamRecordCurrentAuthority.sol";
import { StreamPreservationInventoryIO as IO } from "./StreamPreservationInventoryIO.sol";
import { IERC165 } from "../../vendor/openzeppelin/IERC165.sol";

/// @dev Only the constructor-pinned resolver can select dependencies. No caller-selected route.
library StreamCurrentAuthorityInventorySelection {
    struct Config {
        S.Dependencies originalAnchor;
        D.Dependencies authority;
    }

    struct State {
        Config config;
        D.Capture capture;
    }

    function validate(Config memory config) public view returns (C.Anchors memory anchors) {
        S.Dependencies memory d = config.originalAnchor;
        D.Dependencies memory a = config.authority;
        IO.pin(a.resolver, a.resolverCodeHash);
        if (a.resolverGas < 50000 || a.resolverGas > type(uint64).max || d.chainId != block.chainid)
        {
            revert C.InvalidCurrentAuthority();
        }
        for (uint256 i; i < 12; ++i) {
            IO.pin(d.targets[i], d.codeHashes[i]);
        }
        for (uint256 i; i < 5; ++i) {
            IO.pin(d.artistTargets[i], d.artistCodeHashes[i]);
        }
        IO.pin(d.artistContentOwner, d.artistContentOwnerCodeHash);
        _interface(a.resolver, type(Resolver).interfaceId, a.resolverGas);
        if (
            IO.word(a.resolver, abi.encodeCall(Resolver.currentAuthorityProfile, ()), a.resolverGas)
                != C.PROFILE
        ) revert C.InvalidCurrentAuthority();
        bytes memory raw =
            IO.fixedRead(a.resolver, abi.encodeCall(Resolver.anchors, ()), 416, a.resolverGas);
        anchors = abi.decode(raw, (C.Anchors));
        IO.canonical(a.resolver, raw, abi.encode(anchors));
        if (
            anchors.chainId != d.chainId || anchors.readGas < 50000
                || anchors.readGas > type(uint64).max || anchors.targets[0] != d.targets[0]
                || anchors.codeHashes[0] != d.codeHashes[0] || anchors.targets[1] != d.targets[1]
                || anchors.codeHashes[1] != d.codeHashes[1] || anchors.targets[2] != d.targets[4]
                || anchors.codeHashes[2] != d.codeHashes[4]
                || anchors.targets[3] != d.artistTargets[0]
                || anchors.codeHashes[3] != d.artistCodeHashes[0]
                || anchors.targets[4] == address(0) || anchors.codeHashes[4] == 0
                || anchors.finalityRegistry == address(0)
        ) revert C.InvalidCurrentAuthority();
    }

    function resolve(Config memory config) public view returns (D.Capture memory captured) {
        C.Anchors memory anchors = validate(config);
        D.Dependencies memory a = config.authority;
        bytes memory raw = IO.fixedRead(
            a.resolver, abi.encodeCall(Resolver.currentSelection, ()), 832, a.resolverGas
        );
        captured.selection = abi.decode(raw, (C.Selection));
        IO.canonical(a.resolver, raw, abi.encode(captured.selection));
        C.Selection memory selected = captured.selection;
        if (
            selected.selectionHash == 0
                || selected.selectionHash
                    != C.hashSelection(anchors, selected.origin, selected.completion)
                || selected.origin.environment.chainId != config.originalAnchor.chainId
                || selected.origin.environment.core != config.originalAnchor.targets[0]
        ) revert C.InvalidCurrentAuthority();
        // A fresh memory copy is essential: the original anchor remains unchanged.
        captured.dependencies = abi.decode(abi.encode(config.originalAnchor), (S.Dependencies));
        S.Dependencies memory d = captured.dependencies;
        O.Origin memory o = selected.origin;
        d.artistTargets = [
            o.environment.registry,
            o.environment.coordinator,
            o.environment.owners[2],
            o.environment.owners[4],
            o.environment.archive
        ];
        d.artistCodeHashes = [
            o.registryCodeHash,
            o.coordinatorCodeHash,
            o.environment.ownerCodeHashes[2],
            o.environment.ownerCodeHashes[4],
            o.archiveCodeHash
        ];
        d.artistContentOwner = o.environment.owners[6];
        d.artistContentOwnerCodeHash = o.environment.ownerCodeHashes[6];
        for (uint256 i; i < 5; ++i) {
            IO.pin(d.artistTargets[i], d.artistCodeHashes[i]);
        }
        IO.pin(d.artistContentOwner, d.artistContentOwnerCodeHash);
        _selector(
            d.targets[7],
            d.codeHashes[7],
            keccak256("6529STREAM_CURRENT_AUTHORITY_WORK_SELECTION_V1"),
            o,
            d.readGas,
            d.selectionGas
        );
        _selector(
            d.targets[9],
            d.codeHashes[9],
            keccak256("6529STREAM_CURRENT_AUTHORITY_CONSERVATION_SELECTION_V1"),
            o,
            d.readGas,
            d.selectionGas
        );
    }

    function remember(State storage state, Config memory config, D.Capture memory captured) public {
        if (state.capture.selection.selectionHash != 0) revert C.InvalidCurrentAuthority();
        state.config = config;
        state.capture = captured;
    }

    function requireCurrent(State storage state) public view {
        if (state.capture.selection.selectionHash == 0) revert C.InvalidCurrentAuthority();
        D.Capture memory fresh = resolve(state.config);
        if (keccak256(abi.encode(fresh)) != keccak256(abi.encode(state.capture))) {
            revert C.CurrentAuthorityChanged();
        }
    }

    function _selector(
        address target,
        bytes32 codeHash,
        bytes32 profile,
        O.Origin memory origin,
        uint256 gasCap,
        uint256 selectionGas
    ) private view {
        IO.pin(target, codeHash);
        _interface(target, type(Selector).interfaceId, gasCap);
        if (
            IO.word(target, abi.encodeCall(Selector.currentAuthorityProfile, ()), gasCap) != profile
        ) revert C.InvalidCurrentAuthority();
        bytes memory raw = IO.fixedRead(
            target, abi.encodeCall(Selector.currentArtistContext, ()), 320, selectionGas
        );
        address[5] memory targets = [
            origin.environment.registry,
            origin.environment.coordinator,
            origin.environment.owners[2],
            origin.environment.owners[0],
            origin.environment.owners[4]
        ];
        bytes32[5] memory hashes = [
            origin.registryCodeHash,
            origin.coordinatorCodeHash,
            origin.environment.ownerCodeHashes[2],
            origin.environment.ownerCodeHashes[0],
            origin.environment.ownerCodeHashes[4]
        ];
        IO.canonical(target, raw, abi.encode(targets, hashes));
    }

    function _interface(address target, bytes4 id, uint256 cap) private view {
        if (
            IO.word(target, abi.encodeCall(IERC165.supportsInterface, (bytes4(0x01ffc9a7))), cap)
                    != bytes32(uint256(1))
                || IO.word(target, abi.encodeCall(IERC165.supportsInterface, (id)), cap)
                    != bytes32(uint256(1))
                || IO.word(
                        target, abi.encodeCall(IERC165.supportsInterface, (bytes4(0xffffffff))), cap
                    ) != 0
        ) revert C.InvalidCurrentAuthority();
    }
}
