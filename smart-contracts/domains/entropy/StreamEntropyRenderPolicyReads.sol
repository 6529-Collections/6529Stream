// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import { IERC165 } from "../../vendor/openzeppelin/IERC165.sol";
import { IStreamCoreIdentity as Core } from "../../interfaces/stream/core/IStreamCoreIdentity.sol";
import {
    IStreamEntropyView as E,
    StreamEntropyStatus
} from "../../interfaces/stream/entropy/IStreamEntropyView.sol";
import {
    StreamEntropyPolicyConsumerTypes as P,
    IStreamEntropyPolicyConsumerRead as Read,
    IStreamEntropyPolicyStaticRead as StaticRead
} from "../../interfaces/stream/entropy/StreamEntropyPolicyConsumerTypes.sol";
import { StreamRendererCalls as Calls } from "../metadata/StreamRendererCalls.sol";

/// @notice Original-at-mint terminal facts. This is not evidence that an arbitrary program is entropy-independent.
/// @dev staticTerminal uses the direct producer profile. Ordinary terminal/policy reads retain
/// the original live getters, which may use linked read workers and are not STATIC conformance.
library StreamEntropyRenderPolicyReads {
    error InvalidTerminalEntropy(uint256 tokenId);

    function policy(address coordinator, address core, uint256 collectionId, uint256 cap)
        internal
        view
        returns (P.Policy memory p)
    {
        if (coordinator.code.length == 0 || core.code.length == 0) {
            revert InvalidTerminalEntropy(0);
        }
        if (
            !abi.decode(
                    Calls.read(
                        coordinator,
                        abi.encodeCall(IERC165.supportsInterface, (P.CAPABILITY)),
                        32,
                        true,
                        cap
                    ),
                    (bool)
                )
                || abi.decode(
                        Calls.read(coordinator, abi.encodeWithSignature("core()"), 32, true, cap),
                        (address)
                    ) != core
        ) {
            revert InvalidTerminalEntropy(0);
        }
        bytes memory raw = Calls.read(
            coordinator,
            abi.encodeCall(Read.collectionEntropyPolicy, (collectionId)),
            384,
            true,
            cap
        );
        p = abi.decode(raw, (P.Policy));
        if (keccak256(raw) != keccak256(abi.encode(p))) revert InvalidTerminalEntropy(0);
        _policy(p);
    }

    function _policy(P.Policy memory p) private pure {
        if (
            !p.configured || !p.explicitPolicy || !p.frozen || p.mode > 2 || p.securityClass > 1
                || p.renderRequirement > 1 || p.revision == 0 || p.policyHash == 0
                || p.lastActionId == 0 || p.artistConsentRecord == 0
                || p.contentStateHash != keccak256(abi.encode(P.FAMILY, p.policyHash, p.frozen))
        ) {
            revert InvalidTerminalEntropy(0);
        }
    }

    /// @notice Separate storage-only producer profile for executable STATIC serving.
    /// The original tokenSeed getter derives finalized solely from status. The original tokenEntropy
    /// getter returns requestId/attempt zero whenever this same Subject.requestKey is zero.
    function staticTerminal(address core, uint256 tokenId, uint256 collectionId, uint256 cap)
        internal
        view
        returns (P.Terminal memory t)
    {
        (bool exists, uint256 actualCollection,,) = abi.decode(
            Calls.read(
                core, abi.encodeCall(Core.tokenCollectionIdentity, (tokenId)), 128, true, cap
            ),
            (bool, uint256, uint256, bool)
        );
        if (!exists || collectionId == 0 || actualCollection != collectionId) {
            revert InvalidTerminalEntropy(tokenId);
        }
        t.coordinator = abi.decode(
            Calls.read(core, abi.encodeCall(Core.coordinatorAtMint, (tokenId)), 32, true, cap),
            (address)
        );
        t.coordinatorCodeHash = t.coordinator.codehash;
        if (
            t.coordinator.code.length == 0
                || !abi.decode(
                    Calls.read(
                        t.coordinator,
                        abi.encodeCall(IERC165.supportsInterface, (P.STATIC_CAPABILITY)),
                        32,
                        true,
                        cap
                    ),
                    (bool)
                )
                || abi.decode(
                        Calls.read(t.coordinator, abi.encodeWithSignature("core()"), 32, true, cap),
                        (address)
                    ) != core
        ) revert InvalidTerminalEntropy(tokenId);
        bytes memory raw = Calls.read(
            t.coordinator,
            abi.encodeCall(StaticRead.staticTerminalEntropyFacts, (tokenId)),
            512,
            true,
            cap
        );
        uint256 retainedCollection;
        bytes32 seed;
        bytes32 request;
        (retainedCollection, t.policy, t.status, seed, request) =
            abi.decode(raw, (uint256, P.Policy, uint8, bytes32, bytes32));
        if (
            keccak256(raw)
                    != keccak256(abi.encode(retainedCollection, t.policy, t.status, seed, request))
                || retainedCollection != collectionId || seed != 0 || request != 0
                || t.policy.renderRequirement != 1
                || (t.status == 1 ? t.policy.mode != 0 : t.status != 2 || t.policy.mode != 2)
        ) revert InvalidTerminalEntropy(tokenId);
        _policy(t.policy);
    }

    function terminal(address core, uint256 tokenId, uint256 collectionId, uint256 cap)
        internal
        view
        returns (P.Terminal memory t)
    {
        (bool exists, uint256 actualCollection,,) = abi.decode(
            Calls.read(
                core, abi.encodeCall(Core.tokenCollectionIdentity, (tokenId)), 128, true, cap
            ),
            (bool, uint256, uint256, bool)
        );
        if (!exists || collectionId == 0 || actualCollection != collectionId) {
            revert InvalidTerminalEntropy(tokenId);
        }
        t.coordinator = abi.decode(
            Calls.read(core, abi.encodeCall(Core.coordinatorAtMint, (tokenId)), 32, true, cap),
            (address)
        );
        t.coordinatorCodeHash = t.coordinator.codehash;
        t.policy = policy(t.coordinator, core, collectionId, cap);
        bytes memory raw =
            Calls.read(t.coordinator, abi.encodeCall(E.tokenEntropy, (tokenId)), 256, true, cap);
        (
            StreamEntropyStatus status,
            bytes32 seed,
            address provider,
            uint32 epoch,
            bytes32 configuration,
            bytes32 request,
            uint256 requestId,
            uint16 attempt
        ) = abi.decode(
            raw, (StreamEntropyStatus, bytes32, address, uint32, bytes32, bytes32, uint256, uint16)
        );
        if (
            keccak256(raw)
                != keccak256(
                    abi.encode(
                        status, seed, provider, epoch, configuration, request, requestId, attempt
                    )
                )
        ) revert InvalidTerminalEntropy(tokenId);
        t.status = uint8(status);
        if (
            t.policy.renderRequirement != 1
                || (t.status == 1 ? t.policy.mode != 0 : t.status != 2 || t.policy.mode != 2)
                || seed != 0 || request != 0 || requestId != 0 || attempt != 0
        ) revert InvalidTerminalEntropy(tokenId);
        (bytes32 savedSeed, bool finalized) = abi.decode(
            Calls.read(t.coordinator, abi.encodeCall(E.tokenSeed, (tokenId)), 64, true, cap),
            (bytes32, bool)
        );
        if (
            savedSeed != 0 || finalized
                || abi.decode(
                        Calls.read(
                            t.coordinator,
                            abi.encodeCall(E.tokenEntropyStatus, (tokenId)),
                            32,
                            true,
                            cap
                        ),
                        (StreamEntropyStatus)
                    ) != status
        ) {
            revert InvalidTerminalEntropy(tokenId);
        }
        // Provider/epoch/configuration are retained only in the producer's policy. They are never
        // repurposed as a request or fabricated into a terminal seed/finality claim.
    }
}
