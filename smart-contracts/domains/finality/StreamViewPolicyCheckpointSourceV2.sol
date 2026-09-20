// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamViewPolicyCheckpointTypesV2 as T
} from "../../interfaces/stream/finality/StreamViewPolicyCheckpointTypesV2.sol";
import {
    StreamViewAdoptionTypes as V
} from "../../interfaces/stream/metadata/StreamViewAdoptionTypes.sol";
import { StreamViewPolicyTypesV2 as Policy } from "../metadata/StreamViewPolicyTypesV2.sol";
import { StreamViewAdoptionReads as Read } from "../metadata/StreamViewAdoptionReads.sol";
import {
    StreamFinalityViewPolicySourceReadsV2 as Current
} from "./StreamFinalityViewPolicySourceReadsV2.sol";
import {
    IStreamViewAdoptionRouter as Router
} from "../../interfaces/stream/metadata/IStreamViewAdoptionRouter.sol";
import {
    IStreamViewRendererV2 as Renderer
} from "../../interfaces/stream/metadata/IStreamViewRendererV2.sol";
import {
    IStreamViewCheckpointServingV2 as Serving
} from "../../interfaces/stream/metadata/IStreamViewCheckpointServingV2.sol";
import {
    IStreamGasParameterHost as Gas
} from "../../interfaces/stream/parameters/IStreamGasParameterHost.sol";
import {
    StreamFinalityScope,
    StreamFinalityScopeType
} from "../../interfaces/stream/finality/StreamArtworkFinalityTypes.sol";
import { IERC165 } from "../../vendor/openzeppelin/IERC165.sol";

/// @notice Root-free current adoption source from actual Router history and selected dependencies.
/// @dev Consumer configuration is constructor-owned. No caller-supplied route becomes authority;
/// retained bytes authenticate the old route before the unchanged reader rederives currentness.
library StreamViewPolicyCheckpointSourceV2 {
    function validate(T.Configuration memory c) public view {
        if (
            c.chainId != block.chainid || c.readGas < 50000 || c.servingGas < c.readGas
                || c.servingGas > 16777216 || c.servingConfigurationHash == 0
        ) {
            revert T.InvalidViewCheckpoint();
        }
        Read.pin(c.core, c.coreCodeHash);
        Read.pin(c.router, c.routerCodeHash);
        Read.pin(c.authority, c.authorityCodeHash);
        Read.pin(c.serving, c.servingCodeHash);
        (address router, bytes32 pin) =
            Read.selected(c.core, keccak256("METADATA_ROUTER"), c.readGas);
        if (
            router != c.router || pin != c.routerCodeHash
                || Read.addr(c.router, abi.encodeWithSignature("core()"), c.readGas) != c.core
                || Read.addr(c.router, abi.encodeCall(Gas.governanceAuthority, ()), c.readGas)
                    != c.authority
                || Read.word(
                        c.serving,
                        abi.encodeCall(IERC165.supportsInterface, (type(Serving).interfaceId)),
                        c.readGas
                    ) != 1
                || bytes32(
                        Read.word(
                            c.serving, abi.encodeCall(Serving.configurationHash, ()), c.readGas
                        )
                    ) != c.servingConfigurationHash
        ) {
            revert T.ViewCheckpointDependency(c.router);
        }
        bytes memory raw = Read.read(c.serving, abi.encodeCall(Serving.binding, ()), 192, c.readGas);
        Serving.Binding memory b = abi.decode(raw, (Serving.Binding));
        if (
            keccak256(raw) != keccak256(abi.encode(b)) || b.core != c.core
                || b.coreCodeHash != c.coreCodeHash || b.router != c.router
                || b.routerCodeHash != c.routerCodeHash || b.chainId != c.chainId
                || b.rendererGas < 50000
                || uint256(b.rendererGas) + uint256(b.rendererGas) / 63 + 50000 >= c.servingGas
        ) {
            revert T.ViewCheckpointDependency(c.serving);
        }
    }

    function current(T.Configuration memory c, StreamFinalityScope memory scope)
        public
        view
        returns (T.Source memory s)
    {
        validate(c);
        if (
            scope.scopeType != StreamFinalityScopeType.VIEW || scope.collectionId == 0
                || scope.tokenId != 0 || scope.scopeId == 0
        ) revert T.InvalidViewCheckpoint();
        bytes32 key = bytes32(
            Read.word(c.router, abi.encodeCall(Router.viewAdoptionHead, (scope)), c.readGas)
        );
        Current.Dependencies memory d;
        d.targets[0] = c.core;
        d.codeHashes[0] = c.coreCodeHash;
        d.targets[1] = c.router;
        d.codeHashes[1] = c.routerCodeHash;
        d.chainId = c.chainId;
        d.readGas = c.readGas;
        // retained only uses the independently pinned original Core/Router domain. It does not
        // treat the following saved route as currently selected or accept arbitrary payloads.
        V.Record memory retained = Current.retained(d, key);
        V.Route memory r = retained.source.route;
        d.targets[2] = r.artist;
        d.codeHashes[2] = r.artistCodeHash;
        d.targets[3] = r.finality;
        d.codeHashes[3] = r.finalityCodeHash;
        d.targets[4] = r.provider;
        d.codeHashes[4] = r.providerCodeHash;
        d.targets[5] = r.metadata;
        d.codeHashes[5] = r.metadataCodeHash;
        d.targets[6] = c.authority;
        d.codeHashes[6] = c.authorityCodeHash;
        d.binding = r.binding;
        s.adoption = Current.requireCurrent(d, scope);
        if (
            s.adoption.recordHash != key
                || keccak256(abi.encode(s.adoption)) != keccak256(abi.encode(retained))
        ) {
            revert T.InvalidViewCheckpoint();
        }
        bytes memory raw = Read.read(
            s.adoption.source.renderer.renderer,
            abi.encodeCall(Renderer.policyViewBinding, ()),
            736,
            c.readGas
        );
        s.policy = abi.decode(raw, (Policy.Binding));
        if (
            keccak256(raw) != keccak256(abi.encode(s.policy))
                || keccak256(abi.encode(s.policy.scope)) != keccak256(abi.encode(scope))
                || keccak256(abi.encode(s.policy.membership))
                    != keccak256(abi.encode(s.adoption.source.membership))
        ) {
            revert T.InvalidViewCheckpoint();
        }
        s.contextHash = keccak256(
            abi.encode(
                T.SOURCE,
                T.PROFILE,
                c.chainId,
                address(this),
                c,
                scope,
                s.adoption.recordHash,
                s.adoption.sourceHash,
                s.policy
            )
        );
    }
}
