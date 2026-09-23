// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import { StreamFinalityNativeProviderReads } from "./StreamFinalityNativeProviderReads.sol";
import {
    StreamFinalityViewPreservationBindingV1 as ViewBinding
} from "./StreamFinalityViewPreservationBindingV1.sol";
import {
    StreamFinalityViewPolicyFactoryBindingV1 as ViewPolicyFactory
} from "./StreamFinalityViewPolicyFactoryBindingV1.sol";
import {
    StreamFinalityViewPreservationBindingTypesV1 as ViewBindingTypes
} from "../../interfaces/stream/finality/StreamFinalityViewPreservationBindingTypesV1.sol";
import {
    StreamFinalityViewPreservationCompleteBindingTypesV1 as CompleteViewBinding
} from "../../interfaces/stream/finality/StreamFinalityViewPreservationCompleteBindingTypesV1.sol";
import {
    IStreamViewPreservationFinalitySourcesV1
} from "../../interfaces/stream/finality/IStreamViewPreservationFinalitySourcesV1.sol";
import {
    StreamViewAdoptionTypes as ViewDeclarationTypes
} from "../../interfaces/stream/metadata/StreamViewAdoptionTypes.sol";
import {
    IStreamFinalityViewPreservationBindingV1 as BasicBinding
} from "../../interfaces/stream/finality/IStreamFinalityViewPreservationBindingV1.sol";
import {
    IStreamFinalityViewPreservationCompleteBindingV1 as FullBinding
} from "../../interfaces/stream/finality/IStreamFinalityViewPreservationCompleteBindingV1.sol";
import {
    IStreamViewSourceBinding
} from "../../interfaces/stream/finality/IStreamViewSourceBinding.sol";
import {
    IStreamViewPreservationEvidenceBindingV1
} from "../../interfaces/stream/finality/IStreamViewPreservationEvidenceBindingV1.sol";

/// @notice Closed original VIEW binding transport in the provider's delegate context.
/// @dev Only compiler-fixed selectors are decoded. The original binding worker owns every
/// check and write; original host storage roots, caller, event emitter and hash domain remain.
library StreamFinalityViewProviderBindingTransportV1 {
    error UnsupportedViewBindingSelector();
    event ViewPreservationBound(
        bytes32 indexed recordHash,
        bytes32 indexed actionId,
        address indexed snapshotHost,
        bytes32 proposalHash,
        bytes32 dependenciesHash
    );
    event ViewPreservationCompleteBound(
        bytes32 indexed completeRecordHash,
        bytes32 indexed basicRecordHash,
        bytes32 indexed actionId,
        bytes32 fullProposalHash
    );

    function read(
        ViewBinding.State storage state,
        StreamFinalityNativeProviderReads.Config storage original,
        address factory,
        bytes32 factoryCodeHash,
        bytes32 factoryDependenciesHash,
        bytes calldata input
    ) public view returns (bytes memory) {
        bytes4 selector = bytes4(input[:4]);
        if (selector == BasicBinding.viewPreservationBindingCapability.selector) {
            return abi.encode(state.capability);
        }
        if (selector == BasicBinding.viewPreservationBindingReceipt.selector) {
            return abi.encode(state.receipt);
        }
        if (selector == BasicBinding.viewPreservationBindingTransition.selector) {
            (
                ViewBindingTypes.Configuration memory configuration,
                ViewDeclarationTypes.Binding memory declaration
            ) = abi.decode(
                input[4:], (ViewBindingTypes.Configuration, ViewDeclarationTypes.Binding)
            );

            _validateFactory(state, original, factory, factoryCodeHash, factoryDependenciesHash);
            return abi.encode(ViewBinding.transition(state, original, configuration, declaration));
        }
        if (selector == FullBinding.completeViewPreservationBindingTransition.selector) {
            (
                ViewBindingTypes.Configuration memory configuration,
                ViewDeclarationTypes.Binding memory declaration,
                IStreamViewPreservationFinalitySourcesV1.Selection memory selected
            ) = abi.decode(
                input[4:],
                (
                    ViewBindingTypes.Configuration,
                    ViewDeclarationTypes.Binding,
                    IStreamViewPreservationFinalitySourcesV1.Selection
                )
            );

            _validateFactory(state, original, factory, factoryCodeHash, factoryDependenciesHash);
            return abi.encode(
                ViewBinding.completeTransition(
                    state, original, configuration, declaration, selected
                )
            );
        }
        if (selector == IStreamViewPreservationFinalitySourcesV1.viewFinalitySources.selector) {
            return abi.encode(ViewBinding.completeSelection(state, original));
        }
        if (
            selector == IStreamViewPreservationFinalitySourcesV1.viewFinalitySourcesReceipt.selector
        ) {
            return abi.encode(ViewBinding.completeHistory(state, original));
        }
        if (selector == IStreamViewSourceBinding.viewSourceBinding.selector) {
            return abi.encode(ViewBinding.declaration(state, original));
        }
        if (
            selector
                == IStreamViewPreservationEvidenceBindingV1.viewPreservationSnapshotHost.selector
        ) {
            return abi.encode(ViewBinding.current(state, original).snapshotHost);
        }
        if (
            selector
                == IStreamViewPreservationEvidenceBindingV1.viewPreservationSnapshotCodeHash
                .selector
        ) {
            return abi.encode(ViewBinding.current(state, original).snapshotCodeHash);
        }
        if (
            selector
                == IStreamViewPreservationEvidenceBindingV1.viewPreservationSnapshotValidationGas
                .selector
        ) {
            return abi.encode(ViewBinding.current(state, original).validationGas);
        }
        revert UnsupportedViewBindingSelector();
    }

    function write(
        ViewBinding.State storage state,
        StreamFinalityNativeProviderReads.Config storage original,
        address factory,
        bytes32 factoryCodeHash,
        bytes32 factoryDependenciesHash,
        bytes calldata input
    ) public returns (bytes memory) {
        bytes4 selector = bytes4(input[:4]);
        if (selector == BasicBinding.bindViewPreservation.selector) {
            (
                ViewBindingTypes.Configuration memory configuration,
                ViewDeclarationTypes.Binding memory declaration
            ) = abi.decode(
                input[4:], (ViewBindingTypes.Configuration, ViewDeclarationTypes.Binding)
            );

            _validateFactory(state, original, factory, factoryCodeHash, factoryDependenciesHash);
            ViewBindingTypes.Receipt memory r =
                ViewBinding.bind(state, original, configuration, declaration);
            emit ViewPreservationBound(
                r.recordHash,
                r.actionId,
                r.configuration.snapshotHost,
                ViewBindingTypes.proposalHash(r),
                r.dependenciesHash
            );
            return abi.encode(r.recordHash);
        }
        if (selector == FullBinding.bindCompleteViewPreservation.selector) {
            (
                ViewBindingTypes.Configuration memory configuration,
                ViewDeclarationTypes.Binding memory declaration,
                IStreamViewPreservationFinalitySourcesV1.Selection memory selected
            ) = abi.decode(
                input[4:],
                (
                    ViewBindingTypes.Configuration,
                    ViewDeclarationTypes.Binding,
                    IStreamViewPreservationFinalitySourcesV1.Selection
                )
            );

            _validateFactory(state, original, factory, factoryCodeHash, factoryDependenciesHash);
            (
                ViewBindingTypes.Receipt memory basic,
                IStreamViewPreservationFinalitySourcesV1.Receipt memory complete
            ) = ViewBinding.bindComplete(state, original, configuration, declaration, selected);
            emit ViewPreservationCompleteBound(
                complete.recordHash,
                basic.recordHash,
                complete.actionId,
                CompleteViewBinding.proposalHash(basic, complete)
            );
            return abi.encode(complete.recordHash);
        }
        revert UnsupportedViewBindingSelector();
    }

    function _validateFactory(
        ViewBinding.State storage state,
        StreamFinalityNativeProviderReads.Config storage original,
        address factory,
        bytes32 codeHash,
        bytes32 dependenciesHash
    ) private view {
        if (state.receipt.recordHash != 0) {
            revert ViewBindingTypes.ViewPreservationAlreadyBound();
        }
        ViewPolicyFactory.validate(original, factory, codeHash, dependenciesHash);
    }
}
