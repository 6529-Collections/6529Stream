// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import { IERC165 } from "../../vendor/openzeppelin/IERC165.sol";
import {
    IStreamTerminalEntropyReadiness as I
} from "../../interfaces/stream/finality/IStreamTerminalEntropyReadiness.sol";
import {
    IStreamFinalityEntropyPolicySourceSet as E
} from "../../interfaces/stream/finality/IStreamFinalityEntropyPolicySourceSet.sol";
import {
    IStreamStaticMetadataRouter as M
} from "../../interfaces/stream/metadata/IStreamStaticMetadataRouter.sol";
import { IStreamRenderer as R } from "../../interfaces/stream/metadata/IStreamRenderer.sol";
import {
    IStreamTerminalEntropyRegistry as A
} from "../../interfaces/stream/metadata/IStreamTerminalEntropyRegistry.sol";
import {
    IStreamTerminalEntropyRenderer as T
} from "../../interfaces/stream/metadata/IStreamTerminalEntropyRenderer.sol";
import {
    IStreamCurrentCitationRegistry as C
} from "../../interfaces/stream/metadata/IStreamCurrentCitationRegistry.sol";
import { StreamRendererCalls as Calls } from "../metadata/StreamRendererCalls.sol";

/// @notice Exact terminal policy plus independently admitted nonrandom program profile.
/// @dev A readiness adapter, not a reference publication, rendered-byte proof or new finality authority.
contract StreamTerminalEntropyReadiness is I {
    address public immutable core;
    bytes32 public immutable coreCodeHash;
    address public immutable metadataRouter;
    bytes32 public immutable metadataRouterCodeHash;
    address public immutable entropySourceSet;
    bytes32 public immutable entropySourceSetCodeHash;
    uint256 public immutable deploymentChainId;
    uint32 public immutable readGas;
    uint32 public immutable sourceGas;
    error TerminalReadinessUnavailable();

    constructor(
        address core_,
        address router_,
        address source_,
        uint32 readGas_,
        uint32 sourceGas_
    ) {
        if (
            core_.code.length == 0 || router_.code.length == 0 || source_.code.length == 0
                || readGas_ < 50000 || sourceGas_ < readGas_
        ) revert TerminalReadinessUnavailable();
        core = core_;
        coreCodeHash = core_.codehash;
        metadataRouter = router_;
        metadataRouterCodeHash = router_.codehash;
        entropySourceSet = source_;
        entropySourceSetCodeHash = source_.codehash;
        deploymentChainId = block.chainid;
        readGas = readGas_;
        sourceGas = sourceGas_;
        if (
            abi.decode(_read(router_, abi.encodeWithSignature("core()"), 32, readGas_), (address))
                    != core_
                || abi.decode(
                        _read(source_, abi.encodeWithSignature("core()"), 32, readGas_), (address)
                    ) != core_
                || !abi.decode(
                    _read(
                        source_,
                        abi.encodeCall(IERC165.supportsInterface, (type(E).interfaceId)),
                        32,
                        readGas_
                    ),
                    (bool)
                )
                || abi.decode(
                        _read(
                            source_, abi.encodeWithSignature("SOURCE_SET_PROFILE()"), 32, readGas_
                        ),
                        (bytes32)
                    ) != keccak256("6529STREAM_ENTROPY_POLICY_SOURCE_SET_V2")
        ) revert TerminalReadinessUnavailable();
    }

    function requireTerminalRenderReady(uint256 tokenId) external view returns (Evidence memory e) {
        if (
            block.chainid != deploymentChainId || core.codehash != coreCodeHash
                || metadataRouter.codehash != metadataRouterCodeHash
                || entropySourceSet.codehash != entropySourceSetCodeHash
        ) revert TerminalReadinessUnavailable();
        _read(entropySourceSet, abi.encodeCall(E.requireCurrentSourceSet, ()), 0, sourceGas);
        e.entropy = abi.decode(
            _read(
                entropySourceSet, abi.encodeCall(E.tokenEntropyReadiness, (tokenId)), 320, sourceGas
            ),
            (E.TokenReadiness)
        );
        if (
            !e.entropy.terminal || e.entropy.finalized || e.entropy.seed != 0
                || e.entropy.renderRequirement != 1 || e.entropy.policyHash == 0
        ) revert TerminalReadinessUnavailable();
        bytes memory raw = Calls.read(
            metadataRouter,
            abi.encodeCall(M.resolvedMetadataConfig, (tokenId)),
            8192,
            false,
            readGas
        );
        M.ConfigRecord memory c = abi.decode(raw, (M.ConfigRecord));
        if (
            keccak256(raw) != keccak256(abi.encode(c)) || c.recordHash == 0 || !c.config.frozen
                || c.config.mode != R.MetadataMode.ONCHAIN
                || c.selection.renderer.codehash != c.selection.rendererCodeHash
                || c.selection.registry.codehash != c.selection.registryCodeHash
        ) revert TerminalReadinessUnavailable();
        (address renderer, bytes32 runtime, bytes32 profile, bytes4 selector) = abi.decode(
            _read(
                c.selection.registry,
                abi.encodeCall(A.requireTerminalEntropy, (c.selection.versionKey)),
                128,
                sourceGas
            ),
            (address, bytes32, bytes32, bytes4)
        );
        if (
            renderer != c.selection.renderer || runtime != c.selection.rendererCodeHash
                || profile != keccak256("6529STREAM_TERMINAL_ENTROPY_RENDER_V1")
                || selector != T.renderTerminal.selector
        ) revert TerminalReadinessUnavailable();
        (address sourceCore, address entropy, bytes32 entropyHash) = abi.decode(
            _read(renderer, abi.encodeCall(T.terminalPolicyBinding, ()), 96, readGas),
            (address, address, bytes32)
        );
        if (
            sourceCore != core || entropy != e.entropy.coordinator
                || entropyHash != e.entropy.coordinatorCodeHash
        ) revert TerminalReadinessUnavailable();
        C.CurrentRecord memory admitted = abi.decode(
            _read(
                c.selection.registry,
                abi.encodeCall(A.terminalEntropyRecord, (c.selection.versionKey)),
                384,
                readGas
            ),
            (C.CurrentRecord)
        );
        e.configRecordHash = c.recordHash;
        e.versionKey = c.selection.versionKey;
        e.renderer = renderer;
        e.rendererCodeHash = runtime;
        e.registry = c.selection.registry;
        e.registryCodeHash = c.selection.registryCodeHash;
        e.admissionHash = admitted.registrationHash;
        if (e.admissionHash == 0) revert TerminalReadinessUnavailable();
        e.policyChainHash = abi.decode(
            _read(entropySourceSet, abi.encodeCall(E.originalPolicyChainHash, ()), 32, readGas),
            (bytes32)
        );
        e.evidenceHash = keccak256(
            abi.encode(
                keccak256("6529STREAM_TERMINAL_REFERENCE_READINESS_V1"),
                deploymentChainId,
                address(this),
                core,
                metadataRouter,
                entropySourceSet,
                entropySourceSetCodeHash,
                tokenId,
                e
            )
        );
    }

    function _read(address target, bytes memory input, uint256 size, uint256 cap)
        private
        view
        returns (bytes memory)
    {
        return Calls.read(target, input, size, true, cap);
    }
}
