// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./StreamCurrentFullPreservationPolicyViewInventoryFixture.sol";
import "./StreamCurrentFullPreservationPolicyPublicationBase.sol";
import {
    IStreamFinalityViewPreservationCompleteBindingV1 as CompleteBinding
} from "../../smart-contracts/interfaces/stream/finality/IStreamFinalityViewPreservationCompleteBindingV1.sol";
import {
    StreamFinalityViewPreservationCompleteBindingTypesV1 as CompleteBindingTypes
} from "../../smart-contracts/interfaces/stream/finality/StreamFinalityViewPreservationCompleteBindingTypesV1.sol";
import {
    IStreamViewPreservationFinalitySourcesV1 as CompleteSources
} from "../../smart-contracts/interfaces/stream/finality/IStreamViewPreservationFinalitySourcesV1.sol";
import {
    StreamViewPreservationRenderCriticalInventoryV1 as CompleteInventory
} from "../../smart-contracts/domains/preservation/StreamViewPreservationRenderCriticalInventoryV1.sol";
import {
    StreamViewPreservationBundleArchiveCoverageV1 as CompleteBundle
} from "../../smart-contracts/domains/preservation/StreamViewPreservationBundleArchiveCoverageV1.sol";

/// @notice One actual governed admission of the complete fixed VIEW preservation source graph.
/// @dev Construction authenticates identities and reciprocal configurations before publication.
/// Browser observations, inventory coverage, sanction and finality remain later distinct steps.
abstract contract StreamCurrentFullPreservationPolicyViewCompleteFixture is
    StreamCurrentFullPreservationPolicyViewInventoryFixture
{
    CompleteSources.Selection internal viewCompleteSelection;
    CompleteSources.Receipt internal viewCompleteBindingReceipt;
    ViewPreservationBindingTypes.Configuration internal viewCompleteConfiguration;
    ViewAdoption.Binding internal viewCompleteDeclaration;
    ViewPreservationBindingTypes.Transition internal viewCompleteTransition;
    bytes32 internal viewCompleteBindingAction;

    /// @dev Reviewed NEW-host diagnostic tuple, in read/source/selection/snapshot/reference order.
    /// It preserves every existing host cap. This tuple is source/integration configuration,
    /// not acceptance under the 16,777,216 transaction limit; that capacity remains unproved.
    function _viewCompleteInventoryCaps() internal pure virtual returns (uint256[5] memory) {
        return [uint256(2000000), 18000000, 8000000, 18000000, 24000000];
    }

    /// @dev Reviewed diagnostic read/archive constructor caps for the NEW bundle host.
    function _viewCompleteBundleCaps() internal pure virtual returns (uint256[2] memory) {
        return [uint256(2000000), 8000000];
    }

    function _executeFullPolicyViewBinding(
        ViewPreservationBindingTypes.Configuration memory configuration_,
        ViewAdoption.Binding memory declaration_
    ) internal virtual override returns (bytes32 action) {
        // These hosts must exist before the one binding action. Subsequent observation
        // publication must reuse viewReference and cannot replace the bound selection.
        _viewDeployReference([uint256(1000000), 16000000, 16000000, 1000000]);
        _viewDeployCompleteInventory();
        _viewDeployCompleteBundle();
        viewCompleteSelection = CompleteSources.Selection(
            address(viewReference),
            address(viewReference).codehash,
            address(viewInventory),
            address(viewInventory).codehash,
            address(viewBundle),
            address(viewBundle).codehash
        );
        viewCompleteConfiguration = configuration_;
        viewCompleteDeclaration = declaration_;
        CompleteBinding binding_ = CompleteBinding(address(assemblyProvider));
        require(
            binding_.completeViewPreservationBindingProfile()
                == keccak256("6529STREAM_FINALITY_VIEW_PRESERVATION_COMPLETE_BINDING_V1"),
            "actual additive complete profile on the one original provider"
        );
        viewCompleteTransition = binding_.completeViewPreservationBindingTransition(
            configuration_, declaration_, viewCompleteSelection
        );
        _viewBeforeCompleteBind();
        action = _assemblyGovernanceCall(
            2,
            address(binding_),
            abi.encodeCall(
                CompleteBinding.bindCompleteViewPreservation,
                (configuration_, declaration_, viewCompleteSelection)
            ),
            viewCompleteTransition.scopeHash,
            viewCompleteTransition.oldValueHash,
            viewCompleteTransition.newValueHash
        );
        viewCompleteBindingAction = action;
        viewCompleteBindingReceipt =
            CompleteSources(address(assemblyProvider)).viewFinalitySourcesReceipt();
        _viewRequireCompleteBinding();
        _viewAfterCompleteBind();
    }

    function _viewBeforeCompleteBind() internal virtual { }

    function _viewAfterCompleteBind() internal virtual { }

    function _viewDeployCompleteInventory() private {
        require(address(viewInventory) == address(0), "one fixed actual VIEW inventory");
        // All original documentary/archive/Artist roles already exist in this graph.
        // Derive their exact accepted pins, replacing only the distinct VIEW producers.
        StreamRenderCriticalSourceTypes.Dependencies memory d = assemblyInventory.dependencies();
        d.targets[5] = address(assemblyViewPreservationSnapshot);
        d.codeHashes[5] = address(assemblyViewPreservationSnapshot).codehash;
        d.targets[6] = address(viewReference);
        d.codeHashes[6] = address(viewReference).codehash;
        uint256[5] memory caps = _viewCompleteInventoryCaps();
        d.readGas = caps[0];
        d.sourceGas = caps[1];
        d.selectionGas = caps[2];
        d.snapshotGas = caps[3];
        d.referenceGas = caps[4];
        require(d.chainId == block.chainid, "original inventory chain");
        for (uint256 i; i < 12; ++i) {
            require(
                d.targets[i].code.length != 0 && d.targets[i].codehash == d.codeHashes[i],
                "all twelve actual source runtime pins before complete binding"
            );
        }
        for (uint256 i; i < 5; ++i) {
            require(
                d.artistTargets[i].code.length != 0
                    && d.artistTargets[i].codehash == d.artistCodeHashes[i],
                "all five original Artist runtime pins before complete binding"
            );
        }
        require(
            d.artistContentOwner.code.length != 0
                && d.artistContentOwner.codehash == d.artistContentOwnerCodeHash,
            "original content authority pin before complete binding"
        );
        require(
            type(CompleteInventory).creationCode.length + abi.encode(d).length <= 49152,
            "actual complete VIEW inventory initcode fits"
        );
        viewInventory = new CompleteInventory(d);
        require(
            address(viewInventory).code.length != 0 && address(viewInventory).code.length <= 24576,
            "actual complete VIEW inventory runtime fits"
        );
        require(
            keccak256(abi.encode(viewInventory.dependencies())) == keccak256(abi.encode(d))
                && viewInventory.dependencyHash() == keccak256(abi.encode(d)),
            "exact complete VIEW inventory configuration"
        );
    }

    function _viewDeployCompleteBundle() private {
        require(address(viewBundle) == address(0), "one fixed actual VIEW bundle");
        StreamBundleArchiveTypes.Dependencies memory d;
        d.targets = [
            address(assemblyCore),
            address(assemblyMetadata),
            address(viewInventory),
            address(assemblyArtifact),
            address(assemblyExternal),
            assemblySuite.archive
        ];
        for (uint256 i; i < 6; ++i) {
            require(d.targets[i].code.length != 0, "actual VIEW bundle source exists");
            d.codeHashes[i] = d.targets[i].codehash;
        }
        d.chainId = block.chainid;
        uint256[2] memory caps = _viewCompleteBundleCaps();
        d.readGas = caps[0];
        d.archiveGas = caps[1];
        require(
            type(CompleteBundle).creationCode.length + abi.encode(d).length <= 49152,
            "actual complete VIEW bundle initcode fits"
        );
        viewBundle = new CompleteBundle(d);
        require(
            address(viewBundle).code.length != 0 && address(viewBundle).code.length <= 24576,
            "actual complete VIEW bundle runtime fits"
        );
        require(
            keccak256(abi.encode(viewBundle.dependencies())) == keccak256(abi.encode(d))
                && viewBundle.dependencyHash() == keccak256(abi.encode(d)),
            "exact complete VIEW bundle configuration"
        );
    }

    function _viewRequireCompleteBinding() internal view {
        ViewPreservationBindingTypes.Receipt memory basic =
            ViewPreservationBinding(address(assemblyProvider)).viewPreservationBindingReceipt();
        CompleteSources.Receipt memory complete =
            CompleteSources(address(assemblyProvider)).viewFinalitySourcesReceipt();
        require(
            complete.recordHash != 0 && complete.actionId == viewCompleteBindingAction
                && complete.actionId == basic.actionId && complete.boundAt == basic.boundAt
                && complete.basicBindingRecordHash == basic.recordHash
                && complete.referenceDependenciesHash
                    == keccak256(abi.encode(viewReference.dependencies()))
                && complete.inventoryDependenciesHash
                    == keccak256(abi.encode(viewInventory.dependencies()))
                && complete.bundleDependenciesHash
                    == keccak256(abi.encode(viewBundle.dependencies()))
                && keccak256(abi.encode(complete.selection))
                    == keccak256(abi.encode(viewCompleteSelection))
                && keccak256(
                    abi.encode(CompleteSources(address(assemblyProvider)).viewFinalitySources())
                ) == keccak256(abi.encode(viewCompleteSelection)),
            "one original class2 action links both exact receipts and all real source identities"
        );
        bytes32 literalProposal = keccak256(
            abi.encode(
                keccak256("6529STREAM_FINALITY_VIEW_PRESERVATION_COMPLETE_PROPOSAL_V1"),
                ViewPreservationBindingTypes.proposalHash(basic),
                complete.selection,
                complete.referenceDependenciesHash,
                complete.inventoryDependenciesHash,
                complete.bundleDependenciesHash
            )
        );
        require(
            viewCompleteTransition.newValueHash == literalProposal
                && literalProposal != ViewPreservationBindingTypes.proposalHash(basic)
                && keccak256(abi.encode(viewCompleteTransition))
                    == keccak256(
                        abi.encode(
                            CompleteBindingTypes.transition(
                                block.chainid, address(assemblyProvider), basic, complete
                            )
                        )
                    ),
            "governance authorized the full proposal including all three source commitments"
        );
        require(
            complete.recordHash
                == keccak256(
                    abi.encode(
                        keccak256("6529STREAM_FINALITY_VIEW_PRESERVATION_COMPLETE_RECEIPT_V1"),
                        block.chainid,
                        address(assemblyProvider),
                        complete.selection,
                        complete.referenceDependenciesHash,
                        complete.inventoryDependenciesHash,
                        complete.bundleDependenciesHash,
                        complete.basicBindingRecordHash,
                        complete.actionId,
                        complete.boundAt
                    )
                ),
            "independent complete receipt preimage and exact basic-action linkage"
        );
    }
}
