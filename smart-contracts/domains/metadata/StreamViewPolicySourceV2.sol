// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "../../interfaces/stream/finality/StreamArtworkFinalityTypes.sol";
import "../../interfaces/stream/finality/StreamScopeMembershipTypes.sol";
import { IERC165 } from "../../vendor/openzeppelin/IERC165.sol";
import { IStreamCoreIdentity as Core } from "../../interfaces/stream/core/IStreamCoreIdentity.sol";
import {
    IStreamStaticEntropySource as Static
} from "../../interfaces/stream/metadata/IStreamStaticEntropySource.sol";
import {
    StreamEntropyPolicyConsumerTypes as P,
    IStreamEntropyPolicyStaticRead as Explicit
} from "../../interfaces/stream/entropy/StreamEntropyPolicyConsumerTypes.sol";
import {
    IStreamFinalityEntropyPolicySourceSet as Set
} from "../../interfaces/stream/finality/IStreamFinalityEntropyPolicySourceSet.sol";
import {
    IStreamFinalityScopedEntropyPolicySourceFactoryV2 as Factory
} from "../../interfaces/stream/finality/IStreamFinalityScopedEntropyPolicySourceFactoryV2.sol";
import {
    IStreamFinalityEntropySourceFactory as GenericFactory
} from "../../interfaces/stream/finality/IStreamFinalityEntropySourceFactory.sol";
import {
    StreamFinalityCoordinatorPolicyV2 as Policy
} from "../../interfaces/stream/finality/StreamFinalityCoordinatorPolicyTypesV2.sol";
import {
    StreamViewAdoptionTypes as V
} from "../../interfaces/stream/metadata/StreamViewAdoptionTypes.sol";
import { StreamViewPolicyTypesV2 as T } from "./StreamViewPolicyTypesV2.sol";
import { StreamViewAdoptionReads as Read } from "./StreamViewAdoptionReads.sol";

/// @notice Authentic constructor/source projection plus internal STATIC token entropy reads.
/// @dev Binding is not Artist adoption. The consuming constructor pins factory/runtime, and
/// adoption independently requires that exact selected provider-owned factory configuration.
library StreamViewPolicySourceV2 {
    function bind(
        address core,
        address factory,
        address sourceSet,
        StreamFinalityScope memory scope,
        uint32 readGas,
        uint32 sourceGas
    ) public view returns (T.Binding memory b, Policy[] memory policies) {
        if (
            scope.scopeType != StreamFinalityScopeType.VIEW || scope.collectionId == 0
                || scope.tokenId != 0 || scope.scopeId == 0 || readGas < 50000
                || sourceGas < readGas
        ) revert V.InvalidViewAdoption();
        Read.pin(core, core.codehash);
        Read.pin(factory, factory.codehash);
        Read.pin(sourceSet, sourceSet.codehash);
        if (
            Read.word(
                        factory,
                        abi.encodeCall(IERC165.supportsInterface, (type(Factory).interfaceId)),
                        readGas
                    ) != 1
                || bytes32(
                        Read.word(
                            factory, abi.encodeCall(Factory.scopedPolicyFactoryProfile, ()), readGas
                        )
                    ) != keccak256("6529STREAM_SCOPED_ENTROPY_POLICY_SOURCE_FACTORY_V2")
                || Read.addr(factory, abi.encodeCall(GenericFactory.core, ()), readGas) != core
                || Read.word(
                        sourceSet,
                        abi.encodeCall(IERC165.supportsInterface, (type(Set).interfaceId)),
                        readGas
                    ) != 1
                || bytes32(
                        Read.word(
                            sourceSet, abi.encodeWithSignature("SOURCE_SET_PROFILE()"), readGas
                        )
                    ) != keccak256("6529STREAM_ENTROPY_POLICY_SOURCE_SET_V2")
                || Read.addr(sourceSet, abi.encodeCall(Set.factory, ()), readGas) != factory
                || Read.addr(sourceSet, abi.encodeWithSignature("core()"), readGas) != core
        ) revert V.InvalidViewAdoption();
        bytes memory raw = Read.read(sourceSet, abi.encodeCall(Set.sourceScope, ()), 128, readGas);
        if (keccak256(raw) != keccak256(abi.encode(scope))) revert V.InvalidViewAdoption();
        b.core = core;
        b.coreCodeHash = core.codehash;
        b.factory = factory;
        b.factoryCodeHash = factory.codehash;
        b.sourceSet = sourceSet;
        b.sourceSetCodeHash = sourceSet.codehash;
        b.chainId = block.chainid;
        b.scope = scope;
        b.inventoryPlan =
            bytes32(Read.word(sourceSet, abi.encodeCall(Set.inventoryPlan, ()), readGas));
        b.inventoryHash =
            bytes32(Read.word(sourceSet, abi.encodeCall(Set.originalInventoryHash, ()), readGas));
        b.policyChainHash =
            bytes32(Read.word(sourceSet, abi.encodeCall(Set.originalPolicyChainHash, ()), readGas));
        if (b.inventoryPlan == 0 || b.inventoryHash == 0 || b.policyChainHash == 0) {
            revert V.InvalidViewAdoption();
        }
        raw = Read.read(
            factory, abi.encodeCall(GenericFactory.sourceSetForPlan, (b.inventoryPlan)), 64, readGas
        );
        if (keccak256(raw) != keccak256(abi.encode(sourceSet, b.sourceSetCodeHash))) {
            revert V.InvalidViewAdoption();
        }
        if (
            bytes32(
                    Read.word(
                        factory,
                        abi.encodeCall(GenericFactory.currentInventoryPlan, (scope)),
                        sourceGas
                    )
                ) != b.inventoryPlan
        ) revert V.InvalidViewAdoption();
        // Includes every original policy and current selected Metadata eligibility. This is a
        // constructor/adoption source check; it is never called from executable STATIC serving.
        Read.read(sourceSet, abi.encodeWithSignature("requireCurrentSelection()"), 0, sourceGas);
        raw = Read.read(sourceSet, abi.encodeCall(Set.scopeMembershipFacts, ()), 256, readGas);
        b.membership = abi.decode(raw, (StreamScopeMembershipFacts));
        bytes32 subject = keccak256(
            abi.encode(
                keccak256("6529STREAM_SUBJECT_SCOPE_V1"),
                block.chainid,
                core,
                scope.collectionId,
                uint8(scope.scopeType),
                scope.scopeId
            )
        );
        if (
            keccak256(raw) != keccak256(abi.encode(b.membership))
                || b.membership.scopeSubject != subject || b.membership.scopeManifestHash == 0
                || b.membership.sourceRecordHash == 0 || b.membership.membershipHash == 0
                || b.membership.tokenListHash == 0 || b.membership.tokenCount == 0
                || b.membership.inventoryCount != 0 || b.membership.inventoryPrefixHash != 0
        ) revert V.InvalidViewAdoption();
        b.policyCount = Read.word(sourceSet, abi.encodeCall(Set.sourceCount, ()), readGas);
        if (b.policyCount == 0 || b.policyCount > b.membership.tokenCount) {
            revert V.InvalidViewAdoption();
        }
        policies = new Policy[](b.policyCount);
        for (uint256 i; i < policies.length; ++i) {
            raw = Read.read(sourceSet, abi.encodeCall(Set.sourcePolicyAt, (i)), 832, readGas);
            policies[i] = abi.decode(raw, (Policy));
            if (keccak256(raw) != keccak256(abi.encode(policies[i]))) {
                revert V.InvalidViewAdoption();
            }
            _rule(policies[i]);
        }
    }

    /// @dev Internal only: no linked/delegated call in the executable renderer. The supplied
    /// rule comes exclusively from its constructor-retained full policy roster.
    function token(
        address core,
        uint256 tokenId,
        uint256 collectionId,
        Policy memory rule,
        uint256 cap
    ) internal view returns (T.Entropy memory t) {
        _rule(rule);
        (bool exists, uint256 cid, uint256 serial, bool burned) = abi.decode(
            Read.read(core, abi.encodeCall(Core.tokenCollectionIdentity, (tokenId)), 128, cap),
            (bool, uint256, uint256, bool)
        );
        if (
            !exists || tokenId == 0 || cid == 0 || cid != collectionId || serial == 0
                || Read.word(core, abi.encodeCall(Core.tokenLifecycle, (tokenId)), cap)
                    != (burned ? 3 : 2)
                || Read.addr(core, abi.encodeCall(Core.coordinatorAtMint, (tokenId)), cap)
                    != rule.coordinator
                || Read.addr(rule.coordinator, abi.encodeWithSignature("core()"), cap) != core
        ) revert V.InvalidViewAdoption();
        t.coordinator = rule.coordinator;
        t.coordinatorCodeHash = rule.indexedCodeHash;
        t.policyHash = rule.policyHash;
        t.explicitPolicy = rule.explicitPolicy;
        if (rule.explicitPolicy) {
            if (
                Read.word(
                        t.coordinator,
                        abi.encodeCall(IERC165.supportsInterface, (P.STATIC_CAPABILITY)),
                        cap
                    ) != 1
            ) revert V.InvalidViewAdoption();
            bytes memory raw = Read.read(
                t.coordinator,
                abi.encodeCall(Explicit.staticTerminalEntropyFacts, (tokenId)),
                512,
                cap
            );
            uint256 actualCollection;
            bytes32 request;
            (actualCollection, t.policy, t.status, t.seed, request) =
                abi.decode(raw, (uint256, P.Policy, uint8, bytes32, bytes32));
            if (
                keccak256(raw)
                        != keccak256(
                            abi.encode(actualCollection, t.policy, t.status, t.seed, request)
                        ) || actualCollection != cid
                    || keccak256(abi.encode(t.policy))
                        != keccak256(abi.encode(rule.collectionPolicy))
            ) revert V.InvalidViewAdoption();
            if (t.status == 1 || t.status == 2) {
                if (
                    t.seed != 0 || request != 0 || t.policy.renderRequirement != 1
                        || (t.status == 1 ? t.policy.mode != 0 : t.policy.mode != 2)
                ) revert V.InvalidViewAdoption();
                t.terminal = true;
            } else {
                if (t.status != 5 || t.policy.mode != 2 || t.policy.renderRequirement != 0) {
                    revert V.InvalidViewAdoption();
                }
                t.finalized = true;
            }
        } else {
            bytes memory raw = Read.read(
                t.coordinator, abi.encodeCall(Static.staticTokenRenderFacts, (tokenId)), 96, cap
            );
            address provider;
            (t.status, t.seed, provider) = abi.decode(raw, (uint8, bytes32, address));
            if (
                keccak256(raw) != keccak256(abi.encode(t.status, t.seed, provider)) || t.status != 5
            ) revert V.InvalidViewAdoption();
            t.finalized = true;
        }
    }

    function _rule(Policy memory r) private view {
        Read.pin(r.coordinator, r.indexedCodeHash);
        if (
            !r.frozen || r.policyHash == 0 || r.componentDataHash == 0 || r.moduleVersion == 0
                || r.moduleManifestHash == 0 || r.moduleSchemaHash == 0
                || r.deploymentManifestHash == 0
        ) revert V.InvalidViewAdoption();
        if (r.explicitPolicy) {
            P.Policy memory p = r.collectionPolicy;
            if (
                !p.configured || !p.explicitPolicy || !p.frozen || p.mode > 2 || p.securityClass > 1
                    || p.renderRequirement > 1 || p.revision == 0 || p.policyHash != r.policyHash
                    || p.lastActionId == 0 || p.artistConsentRecord == 0
                    || p.contentStateHash != keccak256(abi.encode(P.FAMILY, p.policyHash, p.frozen))
                    || r.provider != address(0) || r.epoch != 0 || r.salt != 0
            ) revert V.InvalidViewAdoption();
        } else {
            P.Policy memory empty;
            if (
                r.provider == address(0) || r.epoch == 0 || r.salt == 0
                    || keccak256(abi.encode(r.collectionPolicy)) != keccak256(abi.encode(empty))
            ) revert V.InvalidViewAdoption();
        }
    }
}
