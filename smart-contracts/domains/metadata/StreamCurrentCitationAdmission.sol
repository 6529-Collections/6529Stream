// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import { IERC165 } from "../../vendor/openzeppelin/IERC165.sol";
import {
    IStreamCurrentCitationRenderer as C
} from "../../interfaces/stream/metadata/IStreamCurrentCitationRenderer.sol";
import {
    IStreamCurrentCitationRegistry as A
} from "../../interfaces/stream/metadata/IStreamCurrentCitationRegistry.sol";
import {
    IStreamRendererRegistry as V
} from "../../interfaces/stream/metadata/IStreamRendererRegistry.sol";
import { StreamStaticRenderEncoding as Encoding } from "./StreamStaticRenderEncoding.sol";
import { StreamRendererCalls as Calls } from "./StreamRendererCalls.sol";

/// @notice Fixed validator of the separately governed current-output evidence. No state writes.
library StreamCurrentCitationAdmission {
    bytes32 internal constant PROFILE = keccak256("6529STREAM_CURRENT_BASE_CITATION_V1");
    bytes32 internal constant ANALYSIS =
        keccak256("6529STREAM_CURRENT_BASE_CITATION_ANALYSIS_ABI_V1");

    function validate(
        A.CurrentRegistration memory r,
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
        // A current profile includes every original declaration, as well as the new encoder entry.
        // Completeness beyond this finite join is the explicitly retained analysis assertion.
        uint256 oldIndex;
        bool encoder;
        for (uint256 i; i < declared.length; ++i) {
            V.Read memory item = declared[i];
            if (oldIndex < oldReads.length) {
                V.Read storage previous = oldReads[oldIndex];
                if (item.targetIndex == previous.targetIndex && item.selector == previous.selector)
                {
                    if (
                        item.maxReturnBytes != previous.maxReturnBytes
                            || item.exact != previous.exact
                    ) {
                        revert A.InvalidCurrentCitation();
                    }
                    ++oldIndex;
                }
            }
            V.Target storage target = targets[item.targetIndex];
            if (target.target == r.encoding && item.selector == Encoding.renderCurrent.selector) {
                if (
                    target.codeHash != r.encodingRuntimeHash
                        || target.role != keccak256("METADATA_COMPANION") || item.exact
                        || item.maxReturnBytes < 64
                ) revert A.InvalidCurrentCitation();
                encoder = true;
            }
        }
        if (oldIndex != oldReads.length || !encoder) revert A.InvalidCurrentCitation();
        A.CurrentAnalysis memory a = abi.decode(analysis, (A.CurrentAnalysis));
        if (
            keccak256(analysis) != keccak256(abi.encode(a)) || a.analysisProfile != ANALYSIS
                || a.outputProfile != r.profile || a.selector != r.selector
                || a.renderer != original.renderer || a.runtimeHash != original.runtimeHash
                || a.encoding != r.encoding || a.encodingRuntimeHash != r.encodingRuntimeHash
                || a.readSetHash != setHash
                || a.originalRegistrationHash != original.registrationHash || a.toolHash == 0
                || a.findingsHash == 0 || !a.passed
        ) revert A.InvalidCurrentCitation();
        A.CurrentGoldenVector[] memory vectors = abi.decode(golden, (A.CurrentGoldenVector[]));
        if (
            keccak256(golden) != keccak256(abi.encode(vectors)) || vectors.length < 3
                || vectors.length > 16
        ) {
            revert A.InvalidCurrentCitation();
        }
        uint256 modes;
        for (uint256 i; i < vectors.length; ++i) {
            A.CurrentGoldenVector memory v = vectors[i];
            if (v.mode > 2 || v.outputHash == 0) revert A.InvalidCurrentCitation();
            modes |= 1 << v.mode;
            uint256 maximum = v.mode == 1 ? 24576 : v.mode == 0 ? 18000 : 16777216;
            bytes memory raw = Calls.read(
                original.renderer,
                abi.encodeCall(C.renderCurrent, (v.request, v.mode)),
                Calls.ReadOptions(64 + ((maximum + 31) / 32) * 32, false),
                goldenGas
            );
            if (keccak256(bytes(Calls.stringResult(raw, maximum))) != v.outputHash) {
                revert A.InvalidCurrentCitation();
            }
        }
        if (modes != 7) revert A.InvalidCurrentCitation();
    }

    function bindings(A.CurrentRegistration memory r, address renderer, uint256 cap) public view {
        bindingsInternal(r, renderer, cap);
    }

    /// @dev Inlined into serving Registry reads: no transitive library DELEGATECALL under STATIC.
    function bindingsInternal(A.CurrentRegistration memory r, address renderer, uint256 cap)
        internal
        view
    {
        if (
            r.profile != PROFILE || r.selector != C.renderCurrent.selector
                || r.encoding.code.length == 0 || r.encoding.codehash != r.encodingRuntimeHash
                || r.encodingRuntimeHash == 0
        ) {
            revert A.InvalidCurrentCitation();
        }
        if (
            !abi.decode(
                    Calls.read(
                        renderer,
                        abi.encodeCall(IERC165.supportsInterface, (type(C).interfaceId)),
                        Calls.ReadOptions(32, true),
                        cap
                    ),
                    (bool)
                )
                || abi.decode(
                        Calls.read(
                            renderer,
                            abi.encodeCall(C.currentCitationProfile, ()),
                            Calls.ReadOptions(32, true),
                            cap
                        ),
                        (bytes32)
                    ) != PROFILE
        ) {
            revert A.InvalidCurrentCitation();
        }
        (address encoding, bytes32 runtime) = abi.decode(
            Calls.read(
                renderer, abi.encodeCall(C.encodingBinding, ()), Calls.ReadOptions(64, true), cap
            ),
            (address, bytes32)
        );
        if (encoding != r.encoding || runtime != r.encodingRuntimeHash) {
            revert A.InvalidCurrentCitation();
        }
    }
}
