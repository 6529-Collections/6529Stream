// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamFinalityViewPreservationBindingTypesV1 as V
} from "../../interfaces/stream/finality/StreamFinalityViewPreservationBindingTypesV1.sol";
import {
    StreamFinalityNativeProviderReads as Native
} from "./StreamFinalityNativeProviderReads.sol";
import {
    StreamViewPreservationSnapshotTypesV1 as S
} from "../../interfaces/stream/metadata/StreamViewPreservationSnapshotTypesV1.sol";
import {
    IStreamViewPreservationSnapshotPublicationV1 as Snapshot
} from "../../interfaces/stream/metadata/IStreamViewPreservationSnapshotPublicationV1.sol";
import {
    StreamViewPreservationSnapshotSourceReadsV1 as Sources
} from "../records/StreamViewPreservationSnapshotSourceReadsV1.sol";
import {
    StreamViewPreservationCheckpointSourceV1 as CheckpointSource
} from "./StreamViewPreservationCheckpointSourceV1.sol";
import {
    StreamViewPreservationCheckpointTokenV1 as CheckpointToken
} from "./StreamViewPreservationCheckpointTokenV1.sol";
import {
    StreamViewPreservationManifestReadsV1 as ManifestReads
} from "./StreamViewPreservationManifestReadsV1.sol";
import {
    StreamViewPreservationManifestEncodingV1 as ManifestEncoding
} from "./StreamViewPreservationManifestEncodingV1.sol";
import {
    StreamViewPreservationCheckpointTypesV1 as C
} from "../../interfaces/stream/finality/StreamViewPreservationCheckpointTypesV1.sol";
import {
    StreamViewPreservationManifestTypesV1 as M
} from "../../interfaces/stream/finality/StreamViewPreservationManifestTypesV1.sol";
import { StreamFinalityBoundedReads as Reads } from "./StreamFinalityBoundedReads.sol";
import {
    IStreamViewPreservationRendererV1 as Serving
} from "../../interfaces/stream/metadata/IStreamViewPreservationRendererV1.sol";
import { IERC165 } from "../../vendor/openzeppelin/IERC165.sol";

import {
    StreamViewAdoptionTypes as D
} from "../../interfaces/stream/metadata/StreamViewAdoptionTypes.sol";
import {
    StreamFinalityViewDeclarationBindingV1 as Declaration
} from "./StreamFinalityViewDeclarationBindingV1.sol";

/// @notice Fixed source and runtime joins, without a current snapshot, root, or minted scope.
library StreamFinalityViewPreservationValidationV1 {
    function read(
        Native.Config memory original,
        V.Capability memory capability,
        V.Configuration memory c,
        D.Binding memory declaration
    ) public view returns (V.Receipt memory r) {
        return _read(original, capability, c, declaration, true);
    }

    function _read(
        Native.Config memory original,
        V.Capability memory capability,
        V.Configuration memory c,
        D.Binding memory declaration,
        bool completeBindings
    ) private view returns (V.Receipt memory r) {
        if (
            original.chainId != block.chainid
                || capability.originalHash != keccak256(abi.encode(original))
                || c.validationGas < original.readGas || c.validationGas > 16777216
        ) revert V.InvalidViewPreservationBinding();
        if (completeBindings) Declaration.validate(original, capability, declaration);
        else Declaration.pins(original, capability, declaration);
        pin(c.snapshotHost, c.snapshotCodeHash);
        pin(c.checkpointHost, c.checkpointCodeHash);
        pin(c.manifestHost, c.manifestCodeHash);
        if (
            _word(
                    c.snapshotHost,
                    abi.encodeCall(IERC165.supportsInterface, (type(Snapshot).interfaceId)),
                    original.readGas
                ) != bytes32(uint256(1))
        ) revert V.InvalidViewPreservationBinding();
        bytes memory raw = Reads.read(
            c.snapshotHost, abi.encodeCall(Snapshot.dependencies, ()), 768, original.readGas
        );
        S.Dependencies memory d = abi.decode(raw, (S.Dependencies));
        if (
            keccak256(raw) != keccak256(abi.encode(d)) || d.chainId != original.chainId
                || d.readGas > c.validationGas || d.sourceGas > c.validationGas
                || d.inventoryGas > c.validationGas
        ) revert V.InvalidViewPreservationBinding();
        _fits(c.validationGas, _max(d.readGas, _max(d.sourceGas, d.inventoryGas)));
        // Runtime identities remain checked even when current route validation is deferred
        // to the fixed consumer. In particular Coverage is not a declaration dependency.
        for (uint256 i; i < d.targets.length; ++i) {
            pin(d.targets[i], d.codeHashes[i]);
        }
        uint256[7] memory destination = [uint256(0), 1, 2, 3, 4, 5, 8];
        uint256[7] memory source = [uint256(0), 1, 4, 5, 2, 3, 20];
        for (uint256 i; i < source.length; ++i) {
            if (
                d.targets[destination[i]] != original.targets[source[i]]
                    || d.codeHashes[destination[i]] != original.codeHashes[source[i]]
            ) revert V.InvalidViewPreservationBinding();
        }
        if (
            d.targets[6] != c.checkpointHost || d.codeHashes[6] != c.checkpointCodeHash
                || d.targets[7] != c.manifestHost || d.codeHashes[7] != c.manifestCodeHash
                || d.targets[9] != capability.authority
                || d.codeHashes[9] != capability.authorityCodeHash
        ) revert V.InvalidViewPreservationBinding();
        _address(c.snapshotHost, "core()", d.targets[0], original.readGas);
        _address(c.snapshotHost, "metadataHost()", d.targets[1], original.readGas);
        _address(c.snapshotHost, "governanceAuthority()", d.targets[9], original.readGas);
        if (
            _word(c.snapshotHost, abi.encodeWithSignature("authorityCodeHash()"), original.readGas)
                != d.codeHashes[9]
        ) revert V.InvalidViewPreservationBinding();
        // Admission performs the complete original root-free validation. Operative getters
        // return an authenticated bound capability; the fixed Snapshot/current consumer owns
        // mutable eligibility, selected routes and reciprocal-source validation before use.
        if (completeBindings) Sources.bindings(d);
        r.capabilityHash = capability.capabilityHash;
        r.configuration = c;
        r.declaration = declaration;
        r.dependencies = d;
        r.dependenciesHash = keccak256(raw);
        r.workersHash =
            _workers(c, original.readGas, d.sourceGas, declaration.sourceGas, completeBindings);
    }

    function requireCurrent(
        Native.Config memory original,
        V.Capability memory capability,
        V.Receipt memory saved
    ) public view {
        if (saved.recordHash == 0) {
            revert V.ViewPreservationPending();
        }
        if (
            saved.recordHash != V.receiptHash(saved) || saved.actionId == 0
                || saved.dependenciesHash != keccak256(abi.encode(saved.dependencies))
        ) revert V.InvalidViewPreservationBinding();
        V.Receipt memory current =
            _read(original, capability, saved.configuration, saved.declaration, false);
        if (
            current.capabilityHash != saved.capabilityHash
                || current.workersHash != saved.workersHash
                || keccak256(
                        abi.encode(
                            current.dependencies.targets,
                            current.dependencies.codeHashes,
                            current.dependencies.chainId
                        )
                    )
                    != keccak256(
                        abi.encode(
                            saved.dependencies.targets,
                            saved.dependencies.codeHashes,
                            saved.dependencies.chainId
                        )
                    ) || current.dependencies.readGas < saved.dependencies.readGas
                || current.dependencies.sourceGas < saved.dependencies.sourceGas
                || current.dependencies.inventoryGas < saved.dependencies.inventoryGas
        ) revert V.InvalidViewPreservationBinding();
    }

    function _workers(
        V.Configuration memory c,
        uint256 gasCap,
        uint256 sourceGas,
        uint256 declarationSourceGas,
        bool completeBindings
    ) private view returns (bytes32) {
        address[5] memory targets = [
            address(Sources),
            address(CheckpointSource),
            address(CheckpointToken),
            address(ManifestReads),
            address(ManifestEncoding)
        ];
        bytes32[5] memory hashes;
        for (uint256 i; i < targets.length; ++i) {
            hashes[i] = targets[i].codehash;
            pin(targets[i], hashes[i]);
        }
        if (
            _word(c.checkpointHost, abi.encodeWithSignature("sourceWorkerCodeHash()"), gasCap)
                    != hashes[1]
                || _word(c.checkpointHost, abi.encodeWithSignature("tokenWorkerCodeHash()"), gasCap)
                    != hashes[2]
                || _word(c.manifestHost, abi.encodeWithSignature("readWorkerCodeHash()"), gasCap)
                    != hashes[3]
                || _word(
                        c.manifestHost, abi.encodeWithSignature("encodingWorkerCodeHash()"), gasCap
                    ) != hashes[4]
        ) revert V.InvalidViewPreservationBinding();
        bytes memory raw =
            Reads.read(c.checkpointHost, abi.encodeWithSignature("configuration()"), 384, gasCap);
        C.Configuration memory checkpoint = abi.decode(raw, (C.Configuration));
        if (
            keccak256(raw) != keccak256(abi.encode(checkpoint))
                || _word(c.checkpointHost, abi.encodeWithSignature("configurationHash()"), gasCap)
                    != keccak256(
                        abi.encode(
                            C.PROFILE,
                            block.chainid,
                            c.checkpointHost,
                            checkpoint,
                            targets[1],
                            hashes[1],
                            targets[2],
                            hashes[2]
                        )
                    )
        ) revert V.InvalidViewPreservationBinding();
        raw = Reads.read(c.manifestHost, abi.encodeWithSignature("configuration()"), 384, gasCap);
        M.Configuration memory manifest = abi.decode(raw, (M.Configuration));
        if (
            keccak256(raw) != keccak256(abi.encode(manifest))
                || _word(c.manifestHost, abi.encodeWithSignature("configurationHash()"), gasCap)
                    != keccak256(
                        abi.encode(
                            M.PROFILE,
                            block.chainid,
                            c.manifestHost,
                            manifest,
                            targets[3],
                            hashes[3],
                            targets[4],
                            hashes[4]
                        )
                    )
        ) revert V.InvalidViewPreservationBinding();
        if (completeBindings) ManifestReads.pins(manifest);
        // Necessary original strict-forwarding bounds, not a whole-scope gas/capacity claim.
        _fits(sourceGas, _max(manifest.readGas, manifest.checkpointGas));
        _fits(
            manifest.checkpointGas,
            _max(declarationSourceGas, _max(checkpoint.readGas, checkpoint.servingGas))
        );
        pin(checkpoint.serving, checkpoint.servingCodeHash);
        raw = Reads.read(checkpoint.serving, abi.encodeCall(Serving.configuration, ()), 288, gasCap);
        Serving.Configuration memory serving = abi.decode(raw, (Serving.Configuration));
        if (keccak256(raw) != keccak256(abi.encode(serving))) {
            revert V.InvalidViewPreservationBinding();
        }
        _fits(checkpoint.servingGas, _max(serving.rendererGas, serving.attributionGas));
        return keccak256(abi.encode(targets, hashes));
    }

    function _fits(uint256 outer, uint256 inner) private pure {
        if (outer <= inner + inner / 63 + 10000) revert V.InvalidViewPreservationBinding();
    }

    function _max(uint256 a, uint256 b) private pure returns (uint256) {
        return a > b ? a : b;
    }

    function pin(address target, bytes32 hash) internal view {
        if (target.code.length == 0 || hash == 0 || target.codehash != hash) {
            revert V.ViewPreservationBindingDependency(target);
        }
    }

    function _address(address target, string memory selector, address expected, uint256 cap)
        private
        view
    {
        if (
            _word(target, abi.encodeWithSignature(selector), cap)
                != bytes32(uint256(uint160(expected)))
        ) revert V.InvalidViewPreservationBinding();
    }

    function _word(address target, bytes memory input, uint256 cap) private view returns (bytes32) {
        return abi.decode(Reads.read(target, input, 32, cap), (bytes32));
    }
}
