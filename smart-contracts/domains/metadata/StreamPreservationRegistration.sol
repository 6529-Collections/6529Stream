// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    IStreamPreservationRegistryV1 as P
} from "../../interfaces/stream/metadata/IStreamPreservationRegistryV1.sol";
import {
    IStreamRendererRegistry as V
} from "../../interfaces/stream/metadata/IStreamRendererRegistry.sol";
import {
    IStreamSchemaRegistry as S
} from "../../interfaces/stream/metadata/IStreamSchemaRegistry.sol";
import {
    IStreamSchemaDocumentFacts as F
} from "../../interfaces/stream/metadata/IStreamSchemaDocumentFacts.sol";
import {
    IStreamGovernedParameterAuthority as G
} from "../../interfaces/stream/parameters/IStreamGovernedParameterAuthority.sol";
import { StreamRendererCalls as Calls } from "./StreamRendererCalls.sol";
import { StreamPreservationAdmission as Admission } from "./StreamPreservationAdmission.sol";

/// @notice Closed additive registration path; the original Registry declaration and state are retained.
library StreamPreservationRegistration {
    struct State {
        mapping(bytes32 => P.PreservationRecord) records;
        mapping(bytes32 => V.Read[]) reads;
    }

    struct Context {
        address authority;
        bytes32 authorityHash;
        address schemas;
        bytes32 schemasHash;
        bytes32 targetSetHash;
        uint256 chainId;
        uint256 readGas;
        uint256 goldenGas;
    }
    event PreservationRegistered(
        uint16 schemaVersion,
        bytes32 indexed key,
        address indexed producer,
        bytes32 indexed actionId,
        bytes32 registrationHash,
        P.PreservationRegistration registration,
        V.Read[] reads
    );

    function registerEncoded(
        State storage state,
        mapping(bytes32 => V.Version) storage versions,
        V.Target[] storage targets,
        mapping(bytes32 => V.Read[]) storage originalReads,
        Context memory c,
        bytes calldata input
    ) public {
        if (input.length < 4 || bytes4(input) != P.registerPreservation.selector) {
            revert P.InvalidPreservationAdmission();
        }
        (P.PreservationRegistration memory r, V.Read[] memory declared) =
            abi.decode(input[4:], (P.PreservationRegistration, V.Read[]));
        _register(state, versions, targets, originalReads, c, r, declared);
    }

    function transitionEncoded(
        State storage state,
        mapping(bytes32 => V.Version) storage versions,
        Context memory c,
        bytes calldata input
    ) public view returns (bytes32, bytes32, bytes32) {
        if (input.length < 4 || bytes4(input) != P.preservationTransition.selector) revert P.InvalidPreservationAdmission();
        (P.PreservationRegistration memory r, V.Read[] memory declared) =
            abi.decode(input[4:], (P.PreservationRegistration, V.Read[]));
        return _transition(state, versions[r.versionKey], c, r, declared);
    }

    function _register(
        State storage state,
        mapping(bytes32 => V.Version) storage versions,
        V.Target[] storage targets,
        mapping(bytes32 => V.Read[]) storage originalReads,
        Context memory c,
        P.PreservationRegistration memory r,
        V.Read[] memory declared
    ) private {
        bytes32 key = Admission.key(r.versionKey, r.binding.producer, r.binding.profile);
        V.Version storage v = versions[r.versionKey];
        if (!v.exists || v.deprecated || state.records[key].registrationHash != 0) {
            revert P.PreservationUnavailable(key);
        }
        if (v.renderer.code.length == 0 || v.renderer.codehash != v.runtimeHash) {
            revert V.RendererUnavailable(r.versionKey);
        }
        bytes32 declaration = _declaration(c, v.registrationHash, r, declared);
        bytes32 action = _governed(
            c, _scope(c.chainId, key), _stateHash(0), _stateHash(declaration)
        );
        bytes32 setHash = _readSet(c.targetSetHash, targets, declared);
        F.DocumentFacts memory schema = _fact(c, r.schemaDocument, S.DocumentKind.SCHEMA);
        bytes memory analysis = _document(c, r.analysisDocument);
        bytes memory golden = _document(c, r.goldenDocument);
        Admission.validate(
            r,
            v,
            declared,
            targets,
            originalReads[r.versionKey],
            setHash,
            schema.contentHash,
            analysis,
            golden,
            c.readGas,
            c.goldenGas
        );
        state.records[key] = P.PreservationRecord(
            r, declaration, setHash, keccak256(analysis), keccak256(golden), action
        );
        for (uint256 i; i < declared.length; ++i) {
            state.reads[key].push(declared[i]);
        }
        emit PreservationRegistered(1, key, r.binding.producer, action, declaration, r, declared);
    }

    function _transition(
        State storage state,
        V.Version storage original,
        Context memory c,
        P.PreservationRegistration memory r,
        V.Read[] memory declared
    ) private view returns (bytes32, bytes32, bytes32) {
        bytes32 key = Admission.key(r.versionKey, r.binding.producer, r.binding.profile);
        return (
            _scope(c.chainId, key),
            _stateHash(state.records[key].registrationHash),
            _stateHash(_declaration(c, original.registrationHash, r, declared))
        );
    }

    function _declaration(
        Context memory c,
        bytes32 original,
        P.PreservationRegistration memory r,
        V.Read[] memory declared
    ) private view returns (bytes32) {
        return keccak256(
            abi.encode(
                keccak256("6529STREAM_PRESERVATION_REGISTRATION_V1"),
                c.chainId,
                address(this),
                c.schemas,
                c.schemasHash,
                c.targetSetHash,
                original,
                r,
                declared
            )
        );
    }

    function _scope(uint256 chainId, bytes32 key) private view returns (bytes32) {
        return keccak256(
            abi.encode(keccak256("6529STREAM_PRESERVATION_SCOPE_V1"), chainId, address(this), key)
        );
    }

    function _stateHash(bytes32 value) private pure returns (bytes32) {
        return keccak256(abi.encode(keccak256("6529STREAM_PRESERVATION_STATE_V1"), value));
    }

    function _readSet(bytes32 targetSetHash, V.Target[] storage targets, V.Read[] memory declared)
        private
        view
        returns (bytes32)
    {
        if (declared.length > 128) revert V.InvalidRendererRegistration();
        uint256 previous;
        for (uint256 i; i < declared.length; ++i) {
            V.Read memory item = declared[i];
            uint256 order = (uint256(item.targetIndex) << 32) | uint32(item.selector);
            if (
                item.targetIndex >= targets.length || item.selector == 0
                    || (i != 0 && order <= previous) || item.maxReturnBytes == 0
                    || item.maxReturnBytes > 16777216
                    || (item.exact && item.maxReturnBytes % 32 != 0)
            ) {
                revert V.InvalidRendererRegistration();
            }
            V.Target storage target = targets[item.targetIndex];
            if (target.target.code.length == 0 || target.target.codehash != target.codeHash) {
                revert V.InvalidRendererRegistration();
            }
            previous = order;
        }
        return
            keccak256(
                abi.encode(keccak256("6529STREAM_RENDERER_READ_SET_V1"), targetSetHash, declared)
            );
    }

    function _document(Context memory c, bytes32 id) private view returns (bytes memory payload) {
        F.DocumentFacts memory f = _fact(c, id, S.DocumentKind.CATALOG);
        if (f.totalBytes == 0 || f.totalBytes > 8192) revert V.InvalidRendererEvidence(id);
        bytes memory encoded = Calls.read(
            c.schemas,
            abi.encodeCall(S.documentBytes, (id)),
            Calls.ReadOptions(64 + ((uint256(f.totalBytes) + 31) / 32) * 32, false),
            c.readGas
        );
        payload = abi.decode(encoded, (bytes));
        if (
            payload.length != f.totalBytes || keccak256(payload) != f.contentHash
                || keccak256(encoded) != keccak256(abi.encode(payload))
        ) revert V.InvalidRendererEvidence(id);
    }

    function _fact(Context memory c, bytes32 id, S.DocumentKind kind)
        private
        view
        returns (F.DocumentFacts memory f)
    {
        if (c.schemas.codehash != c.schemasHash || id == 0) revert V.InvalidRendererEvidence(id);
        f = abi.decode(
            Calls.read(
                c.schemas,
                abi.encodeCall(F.documentFacts, (id)),
                Calls.ReadOptions(288, true),
                c.readGas
            ),
            (F.DocumentFacts)
        );
        if (
            !f.exists || f.kind != kind || f.status != S.DocumentStatus.ACTIVE || f.contentHash == 0
        ) {
            revert V.InvalidRendererEvidence(id);
        }
    }

    function _governed(Context memory c, bytes32 scope, bytes32 previous, bytes32 next)
        private
        view
        returns (bytes32 id)
    {
        if (
            block.chainid != c.chainId || msg.sender != c.authority
                || msg.sender.codehash != c.authorityHash
        ) revert V.RendererGovernanceRequired();
        (bool executing, bytes32 action, uint8 kind, bytes32 s, bytes32 p, bytes32 n) =
            G(c.authority).currentAction();
        if (!executing || action == 0 || kind != 1 || s != scope || p != previous || n != next) {
            revert V.RendererGovernanceRequired();
        }
        return action;
    }
}
