// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    StreamFinalityNativeProviderReads as Native
} from "./StreamFinalityNativeProviderReads.sol";
import {
    StreamFinalityScopedProviderReads as Scoped
} from "./StreamFinalityScopedProviderReads.sol";
import {
    StreamFinalityDeferredProfileSourceReadsV2 as Selection
} from "./StreamFinalityDeferredProfileSourceReadsV2.sol";
import {
    StreamCurrentAuthorityScopedPolicyGraphSelectionV2 as GraphSelection
} from "./StreamCurrentAuthorityScopedPolicyGraphSelectionV2.sol";
import {
    StreamCurrentAuthorityDeferredPolicyGovernanceV2 as Governance
} from "./StreamCurrentAuthorityDeferredPolicyGovernanceV2.sol";
import {
    StreamCurrentAuthorityDeferredPolicyValidationV2 as Validation
} from "./StreamCurrentAuthorityDeferredPolicyValidationV2.sol";
import {
    StreamCurrentAuthorityDeferredPolicyBindingTypesV2 as T
} from "../../interfaces/stream/finality/StreamCurrentAuthorityDeferredPolicyBindingTypesV2.sol";
import {
    IStreamScopedPolicyPublicationEvidenceBindingV2 as GraphBinding
} from "../../interfaces/stream/finality/IStreamScopedPolicyPublicationEvidenceBindingV2.sol";
import {
    IStreamFinalityProfileSources as Profiles
} from "../../interfaces/stream/finality/IStreamFinalityProfileSources.sol";

/// @notice Fixed constructor and one-way binding work at the original provider's storage roots.
/// @dev The host owns the reentrancy flag and emits only after clearing it. No callback or
/// caller-selected worker is introduced; the existing validator still performs all admission.
library StreamCurrentAuthorityDeferredScopedPolicyBindingWorkerV2 {
    function initialize(
        Selection.Context storage selection,
        GraphSelection.Context storage graph,
        T.Capability storage capability,
        Native.Config memory original,
        Scoped.Config memory scoped,
        GraphBinding.FactoryBinding memory publicationFactory
    ) public returns (bytes32) {
        Selection.Context memory c;
        c.core = original.targets[0];
        c.router = original.targets[2];
        c.routerCodeHash = original.codeHashes[2];
        c.chainId = original.chainId;
        c.readGas = original.readGas;
        c.profiles[0] = _profile(original, 0, keccak256(abi.encode(original)));
        c.profiles[1] = Profiles.Profile(
            Selection.profileHash(1),
            scoped.targets[9],
            scoped.codeHashes[9],
            scoped.targets[8],
            scoped.codeHashes[8],
            scoped.targets[10],
            scoped.codeHashes[10],
            keccak256(abi.encode(scoped))
        );
        Selection.validate(c);
        selection.core = c.core;
        selection.router = c.router;
        selection.routerCodeHash = c.routerCodeHash;
        selection.chainId = c.chainId;
        selection.readGas = c.readGas;
        selection.policyOutput = c.policyOutput;
        selection.policyOutputCodeHash = c.policyOutputCodeHash;
        selection.profiles = c.profiles;
        selection.policyBound = c.policyBound;
        GraphSelection.Context memory initialized =
            GraphSelection.initialize(original, publicationFactory);
        graph.original = initialized.original;
        graph.binding = initialized.binding;
        graph.recipe = initialized.recipe;
        graph.origin = initialized.origin;
        graph.authority = initialized.authority;
        T.Capability memory admitted = Governance.initialize(
            original, keccak256(abi.encode(scoped)), graph.binding.configurationHash
        );
        capability.authority = admitted.authority;
        capability.authorityCodeHash = admitted.authorityCodeHash;
        capability.originalHash = admitted.originalHash;
        capability.scopedHash = admitted.scopedHash;
        capability.graphHash = admitted.graphHash;
        capability.capabilityHash = admitted.capabilityHash;
        return keccak256(
            abi.encode(
                keccak256(
                    "6529STREAM_CURRENT_AUTHORITY_DEFERRED_FINALITY_SOURCE_CONFIGURATION_SCOPED_POLICY_V2"
                ),
                original.chainId,
                address(this),
                capability,
                c.profiles[0],
                c.profiles[1],
                graph.binding
            )
        );
    }

    function transition(
        GraphSelection.Context storage graph,
        T.Capability storage capability,
        Native.Config memory policy,
        address output,
        bytes32 outputHash
    ) public view returns (T.Transition memory) {
        return Validation.transition(_context(graph, capability), policy, output, outputHash);
    }

    function bind(
        Native.Config storage savedPolicy,
        Selection.Context storage selection,
        GraphSelection.Context storage graph,
        T.Capability storage capability,
        T.Receipt storage savedReceipt,
        Native.Config memory policy,
        address output,
        bytes32 outputHash
    ) public returns (bytes32, bytes32, bytes32, bytes32) {
        T.Receipt memory receipt =
            Validation.bind(_context(graph, capability), policy, output, outputHash);
        // Publish in the same original order, after every validator read has completed.
        savedPolicy.targets = receipt.policy.targets;
        savedPolicy.codeHashes = receipt.policy.codeHashes;
        savedPolicy.chainId = receipt.policy.chainId;
        savedPolicy.readGas = receipt.policy.readGas;
        savedPolicy.sourceGas = receipt.policy.sourceGas;
        savedPolicy.componentSourceGas = receipt.policy.componentSourceGas;
        savedPolicy.inventoryDependencyHash = receipt.policy.inventoryDependencyHash;
        selection.profiles[2] = receipt.profile;
        selection.policyOutput = receipt.output;
        selection.policyOutputCodeHash = receipt.outputCodeHash;
        selection.policyBound = true;
        savedReceipt.capabilityHash = receipt.capabilityHash;
        savedReceipt.policy = receipt.policy;
        savedReceipt.profile = receipt.profile;
        savedReceipt.output = receipt.output;
        savedReceipt.outputCodeHash = receipt.outputCodeHash;
        savedReceipt.sourceSet = receipt.sourceSet;
        savedReceipt.sourceSetCodeHash = receipt.sourceSetCodeHash;
        savedReceipt.scope = receipt.scope;
        savedReceipt.inventoryPlan = receipt.inventoryPlan;
        savedReceipt.sourceFactoryDependenciesHash = receipt.sourceFactoryDependenciesHash;
        savedReceipt.sourceSetDataHash = receipt.sourceSetDataHash;
        savedReceipt.bindingHash = receipt.bindingHash;
        savedReceipt.actionId = receipt.actionId;
        return
            (receipt.capabilityHash, receipt.bindingHash, receipt.actionId, T.proposalHash(receipt));
    }

    function _context(GraphSelection.Context storage graph, T.Capability storage capability)
        private
        view
        returns (Validation.Context memory c)
    {
        c.original = graph.original;
        c.capability = capability;
        c.origin = graph.origin;
        c.authority = graph.authority;
    }

    function _profile(Native.Config memory c, uint8 index, bytes32 hash)
        private
        pure
        returns (Profiles.Profile memory)
    {
        return Profiles.Profile(
            Selection.profileHash(index),
            c.targets[9],
            c.codeHashes[9],
            c.targets[8],
            c.codeHashes[8],
            c.targets[10],
            c.codeHashes[10],
            hash
        );
    }
}
