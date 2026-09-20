// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    StreamArtistOnboardingTypes as T
} from "../../interfaces/stream/artist/StreamArtistOnboardingTypes.sol";
import {
    StreamArtistCurrentAuthorityTypes as C
} from "../../interfaces/stream/artist/StreamArtistCurrentAuthorityTypes.sol";
import {
    IStreamArtistCurrentAuthorityResolver as Resolver
} from "../../interfaces/stream/preservation/IStreamArtistCurrentAuthorityResolver.sol";
import {
    IStreamFinalityCurrentAuthority as Finality
} from "../../interfaces/stream/finality/IStreamFinalityCurrentAuthority.sol";
import { IStreamCorePointers } from "../../interfaces/stream/core/IStreamCorePointers.sol";
import { StreamFinalityBoundedReads as Reads } from "../finality/StreamFinalityBoundedReads.sol";
import { IERC165 } from "../../vendor/openzeppelin/IERC165.sol";

/// @notice Reciprocal current-suite route; never rewrites the Coordinator's constructor pins.
library StreamArtistCurrentFinalityRoute {
    /// @dev Legacy confirmation reads remain historical and need no current Core pointer.
    /// Only an explicitly advertised capability on the actual Router anchor selects the new route.
    function isAnchoredCapability(address router, uint256 cid, uint256 cap)
        public
        view
        returns (bool)
    {
        (bool ok,, bytes memory raw) = Reads.tryRead(
            router, abi.encodeWithSignature("originalFinalityAnchor(uint256)", cid), 64, cap
        );
        if (!ok) return false;
        (address finality, bytes32 hash) = abi.decode(raw, (address, bytes32));
        _canonical(raw, abi.encode(finality, hash));
        if (finality == address(0)) return false;
        if (!Reads.supportsOptional(finality, type(Finality).interfaceId, cap)) return false;
        if (finality.code.length == 0 || finality.codehash != hash) {
            revert C.InvalidCurrentAuthority();
        }
        return true;
    }

    function resolve(T.SuiteConfiguration memory suite, uint256 chainId, uint256 cid, uint256 cap)
        public
        view
        returns (bool supported, C.Route memory r)
    {
        if (chainId != block.chainid || cap == 0) revert C.InvalidCurrentAuthority();
        bytes memory raw = Reads.read(
            suite.core,
            abi.encodeCall(
                IStreamCorePointers.getSatellitePointer, (keccak256("ARTWORK_FINALITY_REGISTRY"))
            ),
            320,
            cap
        );
        uint256 addressWord;
        bytes32 finalityHash;
        assembly ("memory-safe") {
            addressWord := mload(add(raw, 32))
            finalityHash := mload(add(raw, 64))
        }
        address finality = address(uint160(addressWord));
        if (
            addressWord > type(uint160).max || finality.code.length == 0
                || finality.codehash != finalityHash
        ) revert C.InvalidCurrentAuthority();
        if (!Reads.supportsOptional(finality, type(Finality).interfaceId, cap)) return (false, r);
        _interface(finality, type(Finality).interfaceId, cap);
        if (_word(finality, abi.encodeCall(Finality.currentAuthorityProfile, ()), cap) != C.PROFILE)
        {
            revert C.InvalidCurrentAuthority();
        }
        address resolver =
            _address(finality, abi.encodeCall(Finality.currentAuthorityResolver, ()), cap);
        bytes32 resolverHash =
            _word(finality, abi.encodeCall(Finality.currentAuthorityResolverCodeHash, ()), cap);
        if (resolver.code.length == 0 || resolver.codehash != resolverHash) {
            revert C.InvalidCurrentAuthority();
        }
        _interface(resolver, type(Resolver).interfaceId, cap);
        if (_word(resolver, abi.encodeCall(Resolver.currentAuthorityProfile, ()), cap) != C.PROFILE)
        {
            revert C.InvalidCurrentAuthority();
        }
        raw = Reads.read(resolver, abi.encodeCall(Resolver.anchors, ()), 416, cap);
        C.Anchors memory anchors = abi.decode(raw, (C.Anchors));
        _canonical(raw, abi.encode(anchors));
        if (
            anchors.chainId != chainId || anchors.finalityRegistry != finality
                || anchors.targets[0] != suite.core || anchors.codeHashes[0] != suite.core.codehash
                || anchors.targets[2] != suite.metadata
                || anchors.codeHashes[2] != suite.metadata.codehash
        ) revert C.InvalidCurrentAuthority();
        raw = Reads.read(resolver, abi.encodeCall(Resolver.currentSelection, ()), 832, cap);
        C.Selection memory selected = abi.decode(raw, (C.Selection));
        _canonical(raw, abi.encode(selected));
        if (
            selected.origin.environment.registry != suite.registry
                || selected.origin.registryCodeHash != suite.registry.codehash
                || selected.origin.environment.coordinator != address(this)
                || selected.origin.coordinatorCodeHash != address(this).codehash
                || selected.origin.environment.suiteConfigurationHash
                    != keccak256(abi.encode(suite))
                || selected.selectionHash
                    != C.hashSelection(anchors, selected.origin, selected.completion)
        ) revert C.InvalidCurrentAuthority();
        // Call the resolver directly. Calling Finality.currentArtistAuthority here would recurse.
        raw = Reads.read(resolver, abi.encodeCall(Resolver.currentFinalityRoute, (cid)), 320, cap);
        r = abi.decode(raw, (C.Route));
        _canonical(raw, abi.encode(r));
        if (
            r.finalityRegistry != finality || r.finalityCodeHash != finalityHash
                || r.provider != anchors.targets[4] || r.providerCodeHash != anchors.codeHashes[4]
                || r.provider.code.length == 0 || r.provider.codehash != r.providerCodeHash
                || r.registry != suite.registry || r.registryCodeHash != suite.registry.codehash
                || r.coordinator != address(this) || r.coordinatorCodeHash != address(this).codehash
                || r.selectionHash != selected.selectionHash || r.presentationHash == 0
        ) revert C.InvalidCurrentAuthority();
        return (true, r);
    }

    function _interface(address target, bytes4 id, uint256 cap) private view {
        if (
            !Reads.supportsOptional(target, 0x01ffc9a7, cap)
                || !Reads.supportsOptional(target, id, cap)
                || Reads.supportsOptional(target, 0xffffffff, cap)
        ) revert C.InvalidCurrentAuthority();
    }

    function _word(address target, bytes memory input, uint256 cap) private view returns (bytes32) {
        return abi.decode(Reads.read(target, input, 32, cap), (bytes32));
    }

    function _address(address target, bytes memory input, uint256 cap)
        private
        view
        returns (address)
    {
        uint256 word = uint256(_word(target, input, cap));
        if (word > type(uint160).max) revert C.InvalidCurrentAuthority();
        return address(uint160(word));
    }

    function _canonical(bytes memory raw, bytes memory expected) private pure {
        if (keccak256(raw) != keccak256(expected)) revert C.InvalidCurrentAuthority();
    }
}
