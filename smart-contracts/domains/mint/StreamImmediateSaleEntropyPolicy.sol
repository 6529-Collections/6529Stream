// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    IStreamEntropyCollectionPolicy as Policy
} from "../../interfaces/stream/entropy/IStreamEntropyCollectionPolicy.sol";
import { IStreamEntropyView } from "../../interfaces/stream/entropy/IStreamEntropyView.sol";
import { IStreamCoreIdentity } from "../../interfaces/stream/core/IStreamCoreIdentity.sol";
import {
    IStreamImmediateSaleReveal as Reveal
} from "../../interfaces/stream/mint/IStreamImmediateSaleReveal.sol";

/// @notice Fixed read boundary for explicit terminal-token policy in immediate sale paths.
/// @dev A missing legacy capability is not an entropy exemption. No token is represented as finalized.
library StreamImmediateSaleEntropyPolicy {
    function terminalStatus(address coordinator, uint256 collectionId)
        public
        view
        returns (uint8 status)
    {
        Policy.PolicyRecord memory p = _policy(coordinator, collectionId);
        if (!p.explicitPolicy) return 0;
        if (p.mode == Policy.Mode.DISABLED) return 1;
        if (p.renderRequirement == Policy.RenderRequirement.NOT_REQUIRED) return 2;
    }

    /// @notice Validate the completed original token before skipping its reveal request.
    /// @dev Receiver callbacks may already have burned it; permanent identity remains authoritative.
    function requireTerminalToken(
        address core,
        address coordinator,
        uint256 collectionId,
        uint256 tokenId
    ) public view returns (bool terminal) {
        Policy.PolicyRecord memory p = _policy(coordinator, collectionId);
        if (!p.explicitPolicy || p.renderRequirement != Policy.RenderRequirement.NOT_REQUIRED) {
            return false;
        }
        uint8 expected = p.mode == Policy.Mode.DISABLED ? 1 : 2;
        if (!p.frozen) revert Reveal.SaleRevealDependencyInvalid(coordinator);
        uint256[4] memory identity = abi.decode(
            _read(
                core, abi.encodeCall(IStreamCoreIdentity.tokenCollectionIdentity, (tokenId)), 128
            ),
            (uint256[4])
        );
        uint256 lifecycle = abi.decode(
            _read(core, abi.encodeCall(IStreamCoreIdentity.tokenLifecycle, (tokenId)), 32),
            (uint256)
        );
        uint256 original = abi.decode(
            _read(core, abi.encodeCall(IStreamCoreIdentity.coordinatorAtMint, (tokenId)), 32),
            (uint256)
        );
        if (
            identity[0] != 1 || identity[1] != collectionId || identity[2] == 0
                || (lifecycle != 2 && lifecycle != 3) || identity[3] != (lifecycle == 3 ? 1 : 0)
                || original != uint256(uint160(coordinator))
        ) revert Reveal.SaleRevealDependencyInvalid(core);
        uint256[8] memory e = abi.decode(
            _read(coordinator, abi.encodeCall(IStreamEntropyView.tokenEntropy, (tokenId)), 256),
            (uint256[8])
        );
        uint256[2] memory seed = abi.decode(
            _read(coordinator, abi.encodeCall(IStreamEntropyView.tokenSeed, (tokenId)), 64),
            (uint256[2])
        );
        uint256 observed = abi.decode(
            _read(
                coordinator, abi.encodeCall(IStreamEntropyView.tokenEntropyStatus, (tokenId)), 32
            ),
            (uint256)
        );
        if (
            e[0] != expected || observed != expected || e[1] != 0 || e[5] != 0 || e[6] != 0
                || e[7] != 0 || seed[0] != 0 || seed[1] != 0 || e[2] > type(uint160).max
                || e[3] > type(uint32).max || e[3] != p.providerEpoch
                || (expected == 1 ? e[2] != 0 || e[4] != 0 : e[2] == 0 || e[4] == 0)
        ) {
            revert Reveal.SaleRevealDependencyInvalid(coordinator);
        }
        return true;
    }

    function _policy(address target, uint256 collectionId)
        private
        view
        returns (Policy.PolicyRecord memory p)
    {
        bytes memory query =
            abi.encodeWithSignature("supportsInterface(bytes4)", type(Policy).interfaceId);
        bool ok;
        uint256 size;
        uint256 word;
        assembly ("memory-safe") {
            ok := staticcall(30000, target, add(query, 32), mload(query), 0, 32)
            size := returndatasize()
            word := mload(0)
        }
        // Original coordinators need not expose the additive interface.
        if (!ok || size == 0) return p;
        if (size != 32 || word > 1) revert Reveal.SaleRevealDependencyInvalid(target);
        if (word == 0) return p;
        p = abi.decode(
            _read(target, abi.encodeCall(Policy.collectionEntropyPolicy, (collectionId)), 384),
            (Policy.PolicyRecord)
        );
        if (!p.explicitPolicy) {
            if (
                p.mode != Policy.Mode.ASYNC
                    || p.renderRequirement != Policy.RenderRequirement.REQUIRED
                    || p.securityClass != Policy.SecurityClass.HIGH_ASSURANCE || p.revision != 0
            ) {
                revert Reveal.SaleRevealDependencyInvalid(target);
            }
            return p;
        }
        if (
            !p.configured || p.revision == 0 || p.policyHash == 0 || p.contentStateHash == 0
                || p.lastActionId == 0 || p.artistConsentRecord == 0
                || (p.mode == Policy.Mode.DISABLED
                    && p.renderRequirement != Policy.RenderRequirement.NOT_REQUIRED)
                || (p.mode == Policy.Mode.INSTANT
                    && p.securityClass != Policy.SecurityClass.LOW_SECURITY)
        ) {
            revert Reveal.SaleRevealDependencyInvalid(target);
        }
        bytes32 expected = keccak256(
            abi.encode(keccak256("6529STREAM_ENTROPY_CONFIGURATION_V1"), p.policyHash, p.frozen)
        );
        if (p.contentStateHash != expected) revert Reveal.SaleRevealDependencyInvalid(target);
    }

    function _read(address target, bytes memory data, uint256 length)
        private
        view
        returns (bytes memory raw)
    {
        raw = new bytes(length);
        bool ok;
        uint256 size;
        assembly ("memory-safe") {
            ok := staticcall(gas(), target, add(data, 32), mload(data), add(raw, 32), length)
            size := returndatasize()
        }
        if (!ok || size != length) revert Reveal.SaleRevealDependencyInvalid(target);
    }
}
