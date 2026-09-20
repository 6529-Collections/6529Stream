// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    StreamCurrentAuthorityDeferredScopedPolicyAssemblyFixture
} from "../helpers/StreamCurrentAuthorityDeferredScopedPolicyAssemblyFixture.sol";
import {
    IStreamCurrentAuthorityDeferredPolicyBindingV2 as DeferredBinding
} from "../../smart-contracts/interfaces/stream/finality/IStreamCurrentAuthorityDeferredPolicyBindingV2.sol";
import {
    StreamCurrentAuthorityDeferredPolicyBindingTypesV2 as BindingTypes
} from "../../smart-contracts/interfaces/stream/finality/StreamCurrentAuthorityDeferredPolicyBindingTypesV2.sol";
import {
    IStreamFinalityProfileSources as ProfileSources
} from "../../smart-contracts/interfaces/stream/finality/IStreamFinalityProfileSources.sol";
import {
    StreamFinalityNativeProviderReads as DeferredNativeConfig
} from "../../smart-contracts/domains/finality/StreamFinalityNativeProviderReads.sol";
import {
    GovernanceActionStatus
} from "../../smart-contracts/interfaces/stream/governance/StreamGovernanceTypes.sol";

/// @notice Source-authored real original deployment and governed binding cases.
/// @dev No mocked Core, Safe, Artist, source receipt, selected pointer or Governance context.
/// These are construction/binding cases; they do not claim a complete scoped STATIC ceremony.
contract StreamCurrentAuthorityDeferredScopedPolicyGraphTest is
    StreamCurrentAuthorityDeferredScopedPolicyAssemblyFixture
{
    function testActualOriginalDeferredGraphMintsWhileCollectionPolicyIsPending() public {
        _deployAssemblyGraph();
        DeferredBinding provider = DeferredBinding(address(assemblyProvider));
        _pending(provider);
        BindingTypes.Capability memory capability = provider.policyBindingCapability();
        require(
            capability.authority == address(assemblyExecutor)
                && capability.authorityCodeHash == address(assemblyExecutor).codehash,
            "original actual governed binder"
        );
        require(
            capability.originalHash == keccak256(abi.encode(scopedGraphOriginal))
                && capability.scopedHash == keccak256(abi.encode(scopedGraphV1)),
            "fixed original profile capabilities"
        );
        _activateAssemblyArtwork();
        _pending(provider);
        require(
            assemblyCore.collectionMintedEver(1) == 2 && sourcePolicySet == address(0),
            "actual original Artist mints before any collection policy source set"
        );
        require(
            assemblyCoordinator.finalityRegistry() == address(assemblyFinality)
                && assemblyCoordinator.finalityEvidenceProvider() == address(assemblyProvider),
            "original wrapper precedes original Coordinator"
        );
        require(
            assemblyAuthorityResolver.anchors().targets[4] == address(assemblyProvider),
            "original resolver pins actual deferred provider"
        );
    }

    function testActualOriginalExecutorBindsRealCollectionSourcesExactlyOnce() public {
        _authorityPrepareOriginalPreservation();
        _bindActualPolicy();
    }

    function testActualOriginalDeferredCapabilityBindsAfterHydratedB() public {
        _authorityPrepareOriginalPreservation();
        _authorityMigrateNext();
        _bindActualPolicy();
        _authorityRequireOriginals();
        _authorityRequireRoute();
    }

    function _bindActualPolicy() private {
        DeferredBinding provider = DeferredBinding(address(assemblyProvider));
        ProfileSources sources = ProfileSources(address(provider));
        _pending(provider);
        bytes32 fixedHash = sources.finalitySourceConfigurationHash();
        bytes32 firstTwo = keccak256(
            abi.encode(sources.finalitySourceProfile(0), sources.finalitySourceProfile(1))
        );
        (DeferredNativeConfig.Config memory policy, address output, bytes32 outputHash) =
            _prepareOriginalCollectionPolicyBinding(1);
        _pending(provider);
        BindingTypes.Transition memory transition =
            provider.bindingTransition(policy, output, outputHash);
        bytes memory callData =
            abi.encodeCall(provider.bindCollectionPolicy, (policy, output, outputHash));
        bytes32 action = _assemblyGovernanceCall(
            2,
            address(provider),
            callData,
            transition.scopeHash,
            transition.oldValueHash,
            transition.newValueHash
        );
        BindingTypes.Receipt memory receipt = provider.requirePolicyBinding();
        require(
            receipt.bindingHash != 0 && receipt.bindingHash == provider.policyBindingHash()
                && receipt.bindingHash == BindingTypes.receiptHash(receipt),
            "exact irreversible binding receipt"
        );
        require(
            receipt.actionId == action
                && assemblyExecutor.governanceAction(action).status
                    == GovernanceActionStatus.EXECUTED,
            "actual scheduled registered terminal action is accounted"
        );
        require(
            keccak256(abi.encode(receipt.policy)) == keccak256(abi.encode(policy))
                && receipt.output == output && receipt.outputCodeHash == outputHash
                && receipt.sourceSet == sourcePolicySet
                && receipt.sourceSetCodeHash == sourcePolicySet.codehash,
            "real candidate and factory source set are the bound tuple"
        );
        require(
            keccak256(abi.encode(sources.finalitySourceProfile(2)))
                == keccak256(abi.encode(receipt.profile)),
            "same bound catalogue profile"
        );
        require(
            sources.finalitySourceConfigurationHash() == fixedHash
                && keccak256(
                        abi.encode(
                            sources.finalitySourceProfile(0), sources.finalitySourceProfile(1)
                        )
                    ) == firstTwo,
            "fixed capability and unrelated catalogue profiles remain exact"
        );
        (bool ok, bytes memory data) = address(provider)
            .staticcall(abi.encodeCall(provider.bindingTransition, (policy, output, outputHash)));
        require(
            !ok
                && keccak256(data)
                    == keccak256(
                        abi.encodeWithSelector(BindingTypes.CollectionPolicyAlreadyBound.selector)
                    ),
            "same tuple cannot schedule a second binding"
        );
    }

    function _pending(DeferredBinding provider) private view {
        require(provider.policyBindingHash() == 0, "explicit pending capability");
        (bool ok, bytes memory data) =
            address(provider).staticcall(abi.encodeCall(provider.requirePolicyBinding, ()));
        require(
            !ok
                && keccak256(data)
                    == keccak256(
                        abi.encodeWithSelector(BindingTypes.CollectionPolicyPending.selector)
                    ),
            "typed receipt rejects pending"
        );
        (ok, data) = address(provider)
            .staticcall(abi.encodeCall(ProfileSources.finalitySourceProfile, (uint8(2))));
        require(
            !ok
                && keccak256(data)
                    == keccak256(
                        abi.encodeWithSelector(BindingTypes.CollectionPolicyPending.selector)
                    ),
            "pending is never a fabricated profile"
        );
    }
}
