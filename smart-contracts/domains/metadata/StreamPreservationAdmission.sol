// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    IStreamPreservationRegistryV1 as A
} from "../../interfaces/stream/metadata/IStreamPreservationRegistryV1.sol";
import {
    IStreamPreservationRendererV1 as P
} from "../../interfaces/stream/metadata/IStreamPreservationRendererV1.sol";
import {
    IStreamPreservationAttributionV1 as PA
} from "../../interfaces/stream/metadata/IStreamPreservationAttributionV1.sol";
import {
    IStreamViewPreservationRendererV1 as View
} from "../../interfaces/stream/metadata/IStreamViewPreservationRendererV1.sol";
import {
    IStreamRendererRegistry as V
} from "../../interfaces/stream/metadata/IStreamRendererRegistry.sol";
import {
    IStreamStaticMetadataRouter as Router
} from "../../interfaces/stream/metadata/IStreamStaticMetadataRouter.sol";
import { IStreamCoreIdentity as CI } from "../../interfaces/stream/core/IStreamCoreIdentity.sol";
import {
    StreamFinalityScope,
    StreamFinalityScopeType
} from "../../interfaces/stream/finality/StreamArtworkFinalityTypes.sol";
import {
    StreamViewAdoptionTypes as Adopted
} from "../../interfaces/stream/metadata/StreamViewAdoptionTypes.sol";
import { StreamViewAdoptionReads as ViewRead } from "./StreamViewAdoptionReads.sol";
import { StreamRendererCalls as Calls } from "./StreamRendererCalls.sol";

interface IStreamPreservationRegistryCoordinates {
    function deploymentChainId() external view returns (uint256);
}

/// @notice Fixed validator for the distinct preservation declaration. Original admission stays intact.
library StreamPreservationAdmission {
    bytes32 internal constant TOKEN = keccak256("6529STREAM_PRESERVATION_RENDER_V1");
    bytes32 internal constant VIEW = keccak256("6529STREAM_ADOPTED_POLICY_VIEW_PRESERVATION_V1");
    bytes32 internal constant ANALYSIS = keccak256("6529STREAM_PRESERVATION_ANALYSIS_ABI_V1");
    uint256 internal constant MAX_OUTPUT = 16777216;

    function key(bytes32 versionKey, address producer, bytes32 profile)
        internal
        pure
        returns (bytes32)
    {
        return keccak256(
            abi.encode(keccak256("6529STREAM_PRESERVATION_KEY_V1"), versionKey, producer, profile)
        );
    }

    /// @notice Nonrecursive fixed STATIC projection of the Registry's compiler-owned public records.
    /// @dev The host pins this worker. No storage slot or mutable target can be selected by callers.
    function requireRegistry(
        address registry,
        bytes32 versionKey,
        address producer,
        bytes32 profile,
        uint256 cap
    ) public view returns (A.ProducerBinding memory, A.Admission memory) {
        bytes32 k = key(versionKey, producer, profile);
        A.PreservationRecord memory record = abi.decode(
            _read(registry, abi.encodeCall(A.preservationRecord, (k)), 576, cap),
            (A.PreservationRecord)
        );
        if (
            record.registrationHash == 0
                || abi.decode(
                        _read(
                            registry,
                            abi.encodeCall(
                                IStreamPreservationRegistryCoordinates.deploymentChainId, ()
                            ),
                            32,
                            cap
                        ),
                        (uint256)
                    ) != block.chainid
        ) {
            revert A.PreservationUnavailable(k);
        }
        V.Version memory original =
            abi.decode(
            _read(registry, abi.encodeCall(V.version, (versionKey)), 288, cap), (V.Version)
        );
        if (!original.exists) revert V.UnknownRenderer(versionKey);
        if (
            original.renderer.code.length == 0 || original.renderer.codehash != original.runtimeHash
        ) {
            revert V.RendererUnavailable(versionKey);
        }
        bytes memory raw = Calls.read(
            registry, abi.encodeCall(A.preservationReads, (k)), Calls.ReadOptions(16448, false), cap
        );
        V.Read[] memory declared = abi.decode(raw, (V.Read[]));
        if (declared.length > 128 || keccak256(raw) != keccak256(abi.encode(declared))) {
            revert A.PreservationUnavailable(k);
        }
        for (uint256 i; i < declared.length; ++i) {
            V.Target memory t = abi.decode(
                _read(
                    registry,
                    abi.encodeCall(V.targetAt, (uint256(declared[i].targetIndex))),
                    96,
                    cap
                ),
                (V.Target)
            );
            if (t.target.code.length == 0 || t.target.codehash != t.codeHash) {
                revert A.PreservationUnavailable(k);
            }
        }
        bindings(record.registration.binding, original, cap);
        return (
            record.registration.binding,
            A.Admission(
                registry,
                registry.codehash,
                versionKey,
                record.registrationHash,
                record.readSetHash,
                record.analysisHash,
                record.goldenHash
            )
        );
    }

    /// @dev Fixed STATIC worker; no storage roots, authority or caller-dependent inputs.
    function requireBindings(A.ProducerBinding memory b, V.Version memory original, uint256 cap)
        public
        view
    {
        bindings(b, original, cap);
    }

    function bindings(A.ProducerBinding memory b, V.Version memory original, uint256 cap)
        internal
        view
    {
        if (
            (b.profile != TOKEN && b.profile != VIEW) || b.producer.code.length == 0
                || b.producer.codehash != b.producerCodeHash || b.attribution.code.length == 0
                || b.attribution.codehash != b.attributionCodeHash || b.core.code.length == 0
                || b.router.code.length == 0 || b.liveRenderer != original.renderer
                || b.liveRendererCodeHash != original.runtimeHash
                || original.renderer.code.length == 0
                || original.renderer.codehash != original.runtimeHash
                || abi.decode(
                        _read(b.producer, abi.encodeCall(P.preservationProfile, ()), 32, cap),
                        (bytes32)
                    ) != b.profile
        ) {
            revert A.InvalidPreservationAdmission();
        }
        if (b.profile == TOKEN) {
            bytes memory raw = _read(
                b.producer, abi.encodeCall(P.preservationBinding, ()), 192, cap
            );
            if (
                keccak256(raw)
                    != keccak256(
                        abi.encode(
                            b.core,
                            b.router,
                            b.liveRenderer,
                            b.liveRendererCodeHash,
                            b.attribution,
                            b.attributionCodeHash
                        )
                    )
            ) revert A.InvalidPreservationAdmission();
        } else {
            View.Configuration memory c = abi.decode(
                _read(b.producer, abi.encodeCall(View.configuration, ()), 288, cap),
                (View.Configuration)
            );
            if (
                c.core != b.core || c.router != b.router
                    || c.preservationAttribution != b.attribution
                    || c.preservationAttributionCodeHash != b.attributionCodeHash
                    || c.core.codehash != c.coreCodeHash || c.router.codehash != c.routerCodeHash
                    || c.chainId != block.chainid || c.rendererGas == 0 || c.attributionGas == 0
            ) revert A.InvalidPreservationAdmission();
        }
        if (
            abi.decode(_read(b.attribution, abi.encodeCall(PA.core, ()), 32, cap), (address))
                    != b.core
                || abi.decode(
                        _read(b.attribution, abi.encodeCall(PA.router, ()), 32, cap), (address)
                    ) != b.router
                || abi.decode(
                        _read(
                            b.attribution,
                            abi.encodeCall(PA.preservationAttributionProfile, ()),
                            32,
                            cap
                        ),
                        (bytes32)
                    ) != keccak256("6529STREAM_NON_SANCTION_ATTRIBUTION_V1")
        ) revert A.InvalidPreservationAdmission();
    }

    function validate(
        A.PreservationRegistration memory registration,
        V.Version memory original,
        V.Read[] memory declared,
        V.Target[] storage targets,
        V.Read[] storage oldReads,
        bytes32 setHash,
        bytes32 schemaHash,
        bytes memory analysis,
        bytes memory golden,
        uint256 readGas,
        uint256 goldenGas
    ) public view {
        A.ProducerBinding memory b = registration.binding;
        bindings(b, original, readGas);
        uint256 oldIndex;
        uint256 required;
        for (uint256 i; i < declared.length; ++i) {
            V.Read memory item = declared[i];
            if (oldIndex < oldReads.length) {
                V.Read storage previous = oldReads[oldIndex];
                if (item.targetIndex == previous.targetIndex && item.selector == previous.selector)
                {
                    if (
                        item.maxReturnBytes != previous.maxReturnBytes
                            || item.exact != previous.exact
                    ) revert A.InvalidPreservationAdmission();
                    ++oldIndex;
                }
            }
            V.Target storage t = targets[item.targetIndex];
            if (t.target == b.producer) {
                if (
                    t.codeHash != b.producerCodeHash || t.role != keccak256("PRESERVATION_RENDERER")
                ) {
                    revert A.InvalidPreservationAdmission();
                }
                if (
                    item.selector == P.preservationProfile.selector && item.exact
                        && item.maxReturnBytes == 32
                ) required |= 1;
                if (b.profile == TOKEN) {
                    if (
                        item.selector == P.preservationBinding.selector && item.exact
                            && item.maxReturnBytes == 192
                    ) required |= 2;
                    if (
                        item.selector == P.preservationTokenJSON.selector && !item.exact
                            && item.maxReturnBytes >= 64
                    ) required |= 4;
                    if (
                        item.selector == P.preservationTokenHTML.selector && !item.exact
                            && item.maxReturnBytes >= 64
                    ) required |= 8;
                } else {
                    if (
                        item.selector == View.configuration.selector && item.exact
                            && item.maxReturnBytes == 288
                    ) required |= 2;
                    if (
                        item.selector == View.preservationViewJSON.selector && !item.exact
                            && item.maxReturnBytes >= 96
                    ) required |= 4;
                    if (
                        item.selector == View.preservationViewHTML.selector && !item.exact
                            && item.maxReturnBytes >= 96
                    ) required |= 8;
                    if (
                        item.selector == View.historicalPreservationViewJSON.selector && !item.exact
                            && item.maxReturnBytes >= 192
                    ) required |= 32;
                    if (
                        item.selector == View.historicalPreservationViewHTML.selector && !item.exact
                            && item.maxReturnBytes >= 192
                    ) required |= 64;
                    if (
                        item.selector == View.preservationViewBinding.selector && item.exact
                            && item.maxReturnBytes == 192
                    ) required |= 128;
                }
            }
            if (t.target == b.attribution && item.selector == PA.preservationAttribution.selector) {
                if (
                    t.codeHash != b.attributionCodeHash
                        || t.role != keccak256("PRESERVATION_ATTRIBUTION") || item.exact
                        || item.maxReturnBytes != 32832
                ) revert A.InvalidPreservationAdmission();
                required |= 16;
            }
        }
        if (oldIndex != oldReads.length || required != (b.profile == TOKEN ? 31 : 255)) {
            revert A.InvalidPreservationAdmission();
        }
        A.PreservationAnalysis memory a = abi.decode(analysis, (A.PreservationAnalysis));
        if (
            keccak256(analysis) != keccak256(abi.encode(a)) || a.analysisProfile != ANALYSIS
                || keccak256(abi.encode(a.binding)) != keccak256(abi.encode(b))
                || a.originalRegistrationHash != original.registrationHash
                || a.schemaHash != schemaHash || schemaHash == 0 || a.readSetHash != setHash
                || a.toolHash == 0 || a.findingsHash == 0 || !a.passed
        ) revert A.InvalidPreservationAdmission();
        A.PreservationGoldenVector[] memory vectors =
            abi.decode(golden, (A.PreservationGoldenVector[]));
        if (
            keccak256(golden) != keccak256(abi.encode(vectors)) || vectors.length < 2
                || vectors.length > 16
        ) revert A.InvalidPreservationAdmission();
        uint256 modes;
        for (uint256 i; i < vectors.length; ++i) {
            A.PreservationGoldenVector memory v = vectors[i];
            if (
                v.outputHash == 0 || v.tokenId == 0 || v.mode < 2
                    || v.mode > (b.profile == TOKEN ? 3 : 5)
            ) {
                revert A.InvalidPreservationAdmission();
            }
            modes |= 1 << v.mode;
            _golden(registration, v, readGas, goldenGas);
        }
        if (modes != (b.profile == TOKEN ? 12 : 60)) revert A.InvalidPreservationAdmission();
    }

    function _golden(
        A.PreservationRegistration memory r,
        A.PreservationGoldenVector memory v,
        uint256 cap,
        uint256 goldenGas
    ) private view {
        A.ProducerBinding memory b = r.binding;
        (bool exists, uint256 cid,,) = abi.decode(
            _read(b.core, abi.encodeCall(CI.tokenCollectionIdentity, (v.tokenId)), 128, cap),
            (bool, uint256, uint256, bool)
        );
        if (!exists || cid != v.scope.collectionId) revert A.InvalidPreservationAdmission();
        string memory output;
        bytes memory raw;
        if (b.profile == TOKEN) {
            // Token methods select MARKETPLACE directly; COLLECTION is the canonical golden coordinate.
            if (
                v.adoptionRecord != 0 || v.scope.scopeType != StreamFinalityScopeType.COLLECTION
                    || v.scope.tokenId != 0 || v.scope.scopeId != 0
            ) revert A.InvalidPreservationAdmission();
            bytes memory configRaw = Calls.read(
                b.router,
                abi.encodeCall(Router.resolvedMetadataConfig, (v.tokenId)),
                Calls.ReadOptions(8192, false),
                cap
            );
            Router.ConfigRecord memory c = abi.decode(configRaw, (Router.ConfigRecord));
            if (
                keccak256(configRaw) != keccak256(abi.encode(c))
                    || c.selection.registry != address(this)
                    || c.selection.registryCodeHash != address(this).codehash
                    || c.selection.versionKey != r.versionKey
                    || c.selection.renderer != b.liveRenderer
                    || c.selection.rendererCodeHash != b.liveRendererCodeHash
            ) revert A.InvalidPreservationAdmission();
            raw = Calls.read(
                b.producer,
                v.mode == 2
                    ? abi.encodeCall(P.preservationTokenJSON, (v.tokenId))
                    : abi.encodeCall(P.preservationTokenHTML, (v.tokenId)),
                Calls.ReadOptions(MAX_OUTPUT + 64, false),
                goldenGas
            );
            output = Calls.stringResult(raw, MAX_OUTPUT);
        } else {
            if (v.adoptionRecord == 0 || v.scope.scopeType != StreamFinalityScopeType.VIEW) {
                revert A.InvalidPreservationAdmission();
            }
            bytes memory recordRaw = ViewRead.recordBytes(b.router, v.adoptionRecord, cap);
            Adopted.Record memory selected = abi.decode(recordRaw, (Adopted.Record));
            if (
                keccak256(recordRaw) != keccak256(abi.encode(selected))
                    || selected.recordHash != v.adoptionRecord
                    || selected.source.renderer.registry != address(this)
                    || selected.source.renderer.registryCodeHash != address(this).codehash
                    || selected.source.renderer.versionKey != r.versionKey
                    || selected.source.renderer.renderer != b.liveRenderer
                    || selected.source.renderer.rendererCodeHash != b.liveRendererCodeHash
            ) revert A.InvalidPreservationAdmission();
            bytes memory bindingRaw = _read(
                b.producer,
                abi.encodeCall(View.preservationViewBinding, (v.adoptionRecord)),
                192,
                cap
            );
            if (
                keccak256(bindingRaw)
                    != keccak256(
                        abi.encode(
                            b.core,
                            b.router,
                            b.liveRenderer,
                            b.liveRendererCodeHash,
                            b.attribution,
                            b.attributionCodeHash
                        )
                    )
            ) revert A.InvalidPreservationAdmission();
            bytes memory input = v.mode == 2
                ? abi.encodeCall(View.preservationViewJSON, (v.scope, v.tokenId))
                : v.mode == 3
                    ? abi.encodeCall(View.preservationViewHTML, (v.scope, v.tokenId))
                    : v.mode == 4
                        ? abi.encodeCall(
                            View.historicalPreservationViewJSON, (v.adoptionRecord, v.tokenId)
                        )
                        : abi.encodeCall(
                            View.historicalPreservationViewHTML, (v.adoptionRecord, v.tokenId)
                        );
            raw = Calls.read(
                b.producer, input, Calls.ReadOptions(MAX_OUTPUT + 192, false), goldenGas
            );
            if (v.mode < 4) {
                bytes32 record;
                (record, output) = abi.decode(raw, (bytes32, string));
                if (
                    record != v.adoptionRecord
                        || keccak256(raw) != keccak256(abi.encode(record, output))
                ) revert A.InvalidPreservationAdmission();
            } else {
                StreamFinalityScope memory scope;
                (scope, output) = abi.decode(raw, (StreamFinalityScope, string));
                if (
                    keccak256(abi.encode(scope)) != keccak256(abi.encode(v.scope))
                        || keccak256(raw) != keccak256(abi.encode(scope, output))
                ) revert A.InvalidPreservationAdmission();
            }
        }
        if (
            bytes(output).length == 0 || bytes(output).length > MAX_OUTPUT
                || keccak256(bytes(output)) != v.outputHash
        ) revert A.InvalidPreservationAdmission();
    }

    function _read(address target, bytes memory input, uint256 size, uint256 cap)
        private
        view
        returns (bytes memory)
    {
        return Calls.read(target, input, Calls.ReadOptions(size, true), cap);
    }
}
