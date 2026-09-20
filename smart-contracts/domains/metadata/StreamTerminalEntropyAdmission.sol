// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import { IERC165 } from "../../vendor/openzeppelin/IERC165.sol";
import {
    IStreamTerminalEntropyRenderer as T
} from "../../interfaces/stream/metadata/IStreamTerminalEntropyRenderer.sol";
import {
    IStreamTerminalEntropyRegistry as A
} from "../../interfaces/stream/metadata/IStreamTerminalEntropyRegistry.sol";
import {
    IStreamCurrentCitationRegistry as C
} from "../../interfaces/stream/metadata/IStreamCurrentCitationRegistry.sol";
import {
    IStreamRendererRegistry as V
} from "../../interfaces/stream/metadata/IStreamRendererRegistry.sol";
import { StreamTerminalEntropyEncoding as Encoding } from "./StreamTerminalEntropyEncoding.sol";
import {
    StreamTerminalEntropyValidation as Validation
} from "./StreamTerminalEntropyValidation.sol";
import { StreamRendererCalls as Calls } from "./StreamRendererCalls.sol";

/// @notice Governed analysis assertion and actual golden outputs for the separate terminal profile.
library StreamTerminalEntropyAdmission {
    bytes32 internal constant PROFILE = keccak256("6529STREAM_TERMINAL_ENTROPY_RENDER_V1");
    bytes32 internal constant ANALYSIS = keccak256("6529STREAM_TERMINAL_ENTROPY_ANALYSIS_ABI_V1");

    function validate(
        C.CurrentRegistration memory r,
        V.Version memory original,
        V.Read[] memory declared,
        V.Target[] storage targets,
        V.Read[] storage oldReads,
        bytes32 setHash,
        bytes memory analysis,
        bytes memory golden,
        uint256 readGas,
        uint256 goldenGas
    ) public view {
        bindings(r, original.renderer, readGas);
        uint256 oldIndex;
        bool encoder;
        bool validator;
        uint256 required;
        (address core, address entropy, bytes32 entropyHash) = abi.decode(
            Calls.read(
                original.renderer, abi.encodeCall(T.terminalPolicyBinding, ()), 96, true, readGas
            ),
            (address, address, bytes32)
        );
        if (core.code.length == 0 || entropy.code.length == 0 || entropy.codehash != entropyHash) {
            revert A.InvalidTerminalEntropyAdmission();
        }
        (address validation, bytes32 validationHash) = abi.decode(
            Calls.read(
                original.renderer,
                abi.encodeCall(T.terminalValidationBinding, ()),
                64,
                true,
                readGas
            ),
            (address, bytes32)
        );
        for (uint256 i; i < declared.length; ++i) {
            V.Read memory item = declared[i];
            if (oldIndex < oldReads.length) {
                V.Read storage previous = oldReads[oldIndex];
                if (item.targetIndex == previous.targetIndex && item.selector == previous.selector)
                {
                    if (
                        item.maxReturnBytes != previous.maxReturnBytes
                            || item.exact != previous.exact
                    ) revert A.InvalidTerminalEntropyAdmission();
                    ++oldIndex;
                }
            }
            V.Target storage target = targets[item.targetIndex];
            if (
                target.target == validation && target.role == keccak256("METADATA_COMPANION")
                    && target.codeHash == validationHash
                    && item.selector == Validation.validate.selector && item.exact
                    && item.maxReturnBytes == 480
            ) validator = true;
            if (target.target == r.encoding && item.selector == Encoding.render.selector) {
                if (
                    target.codeHash != r.encodingRuntimeHash
                        || target.role != keccak256("METADATA_COMPANION") || item.exact
                        || item.maxReturnBytes < 64
                ) revert A.InvalidTerminalEntropyAdmission();
                encoder = true;
            }
            if (
                target.target == entropy && target.codeHash == entropyHash
                    && target.role == keccak256("ENTROPY_COORDINATOR") && item.exact
            ) {
                if (item.selector == 0x40016975 && item.maxReturnBytes == 512) {
                    required |= 1;
                }
                if (
                    item.selector == IERC165.supportsInterface.selector && item.maxReturnBytes == 32
                ) required |= 2;
                if (item.selector == bytes4(keccak256("core()")) && item.maxReturnBytes == 32) {
                    required |= 4;
                }
            }
            if (target.target == core && target.role == keccak256("CORE") && item.exact) {
                if (
                    item.selector == bytes4(keccak256("tokenCollectionIdentity(uint256)"))
                        && item.maxReturnBytes == 128
                ) required |= 8;
                if (
                    item.selector == bytes4(keccak256("coordinatorAtMint(uint256)"))
                        && item.maxReturnBytes == 32
                ) required |= 16;
                if (
                    item.selector == bytes4(keccak256("tokenLifecycle(uint256)"))
                        && item.maxReturnBytes == 32
                ) required |= 32;
                if (
                    item.selector == bytes4(keccak256("collectionFreezeStatus(uint256)"))
                        && item.maxReturnBytes == 32
                ) required |= 64;
                if (
                    item.selector == bytes4(keccak256("collectionSupplyMode(uint256)"))
                        && item.maxReturnBytes == 32
                ) required |= 128;
                if (
                    item.selector == bytes4(keccak256("collectionStatus(uint256)"))
                        && item.maxReturnBytes == 32
                ) required |= 256;
            }
        }
        if (oldIndex != oldReads.length || !encoder || !validator || required != 511) {
            revert A.InvalidTerminalEntropyAdmission();
        }
        A.TerminalAnalysis memory a = abi.decode(analysis, (A.TerminalAnalysis));
        C.CurrentAnalysis memory b = a.bindings;
        if (
            keccak256(analysis) != keccak256(abi.encode(a)) || !a.entropyIndependent
                || b.analysisProfile != ANALYSIS || b.outputProfile != r.profile
                || b.selector != r.selector || b.renderer != original.renderer
                || b.runtimeHash != original.runtimeHash || b.encoding != r.encoding
                || b.encodingRuntimeHash != r.encodingRuntimeHash || b.readSetHash != setHash
                || b.originalRegistrationHash != original.registrationHash || b.toolHash == 0
                || b.findingsHash == 0 || !b.passed
        ) revert A.InvalidTerminalEntropyAdmission();
        C.CurrentGoldenVector[] memory vectors = abi.decode(golden, (C.CurrentGoldenVector[]));
        if (
            keccak256(golden) != keccak256(abi.encode(vectors)) || vectors.length < 4
                || vectors.length > 16
        ) revert A.InvalidTerminalEntropyAdmission();
        uint256 modes;
        for (uint256 i; i < vectors.length; ++i) {
            C.CurrentGoldenVector memory v = vectors[i];
            if (v.mode > 3 || v.outputHash == 0) revert A.InvalidTerminalEntropyAdmission();
            modes |= 1 << v.mode;
            uint256 maximum = v.mode == 1 ? 24576 : v.mode == 0 ? 18000 : 16777216;
            bytes memory raw = Calls.read(
                original.renderer,
                abi.encodeCall(T.renderTerminal, (v.request, v.mode)),
                64 + ((maximum + 31) / 32) * 32,
                false,
                goldenGas
            );
            if (keccak256(bytes(Calls.stringResult(raw, maximum))) != v.outputHash) {
                revert A.InvalidTerminalEntropyAdmission();
            }
        }
        if (modes != 15) revert A.InvalidTerminalEntropyAdmission();
    }

    /// @dev Inlined into the serving Registry; no delegated library read.
    function bindings(C.CurrentRegistration memory r, address renderer, uint256 cap) internal view {
        if (
            r.profile != PROFILE || r.selector != T.renderTerminal.selector
                || r.encoding.code.length == 0 || r.encodingRuntimeHash == 0
                || r.encoding.codehash != r.encodingRuntimeHash
        ) revert A.InvalidTerminalEntropyAdmission();
        if (
            !abi.decode(
                    Calls.read(
                        renderer,
                        abi.encodeCall(IERC165.supportsInterface, (type(T).interfaceId)),
                        32,
                        true,
                        cap
                    ),
                    (bool)
                )
                || abi.decode(
                        Calls.read(
                            renderer, abi.encodeCall(T.terminalEntropyProfile, ()), 32, true, cap
                        ),
                        (bytes32)
                    ) != PROFILE
        ) revert A.InvalidTerminalEntropyAdmission();
        (address encoding, bytes32 runtime) = abi.decode(
            Calls.read(renderer, abi.encodeCall(T.terminalEncodingBinding, ()), 64, true, cap),
            (address, bytes32)
        );
        if (encoding != r.encoding || runtime != r.encodingRuntimeHash) {
            revert A.InvalidTerminalEntropyAdmission();
        }
    }
}
