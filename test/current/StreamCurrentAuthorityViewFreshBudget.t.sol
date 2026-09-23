// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    StreamCurrentAuthorityViewFreshBudgetFixture
} from "../helpers/StreamCurrentAuthorityViewFreshBudgetFixture.sol";
import {
    StreamCurrentAuthorityViewReferenceFixture
} from "../helpers/StreamCurrentAuthorityViewReferenceFixture.sol";
import {
    StreamCurrentAuthorityFullPreservationPolicyDiscoveryV1 as Discovery
} from "../../smart-contracts/domains/finality/StreamCurrentAuthorityFullPreservationPolicyDiscoveryV1.sol";
import {
    IStreamViewPreservationContentCheckpointV1 as Checkpoint
} from "../../smart-contracts/interfaces/stream/finality/IStreamViewPreservationContentCheckpointV1.sol";
import {
    StreamViewPreservationCheckpointTypesV1 as C
} from "../../smart-contracts/interfaces/stream/finality/StreamViewPreservationCheckpointTypesV1.sol";
import {
    IStreamArtworkScopedFinalityComponent as Component
} from "../../smart-contracts/interfaces/stream/finality/IStreamArtworkFinalityComponents.sol";
import {
    StreamFinalityComponentState
} from "../../smart-contracts/interfaces/stream/finality/StreamArtworkFinalityTypes.sol";
import {
    StreamFinalityRouterEvidence as Reads
} from "../../smart-contracts/domains/finality/StreamFinalityRouterEvidence.sol";

/// @notice One genuine full-currentness measurement before the expensive composition continues.
/// @dev A successful result proves only this exact two-token checkpoint call at the declared
/// child cap. It is not reference/discovery/Finality, total-transaction or browser acceptance.
/// Source reads may be warm after construction in this same test call. Observed call gas includes
/// caller and return-copy overhead; this probe does not establish cold-transaction sizing.
contract StreamCurrentAuthorityViewFreshBudgetTest is StreamCurrentAuthorityViewFreshBudgetFixture {
    event FreshViewCheckpointProbe(
        bytes32 checkpoint,
        bytes32 originalPlanHash,
        uint256 discoveryComponentGas,
        uint256 checkpointCallGas,
        uint256 observedCallGas,
        bool accepted,
        bytes exactResult
    );

    function testFreshCheckpointRevalidationFitsSevenMillionGas() public {
        _authorityPrepareViewArtwork();
        _authorityDeclareAndAdoptView();
        _authorityViewSelectRecords();
        _authorityViewAdmitPreservation();
        _authorityViewPublicationDefinitions();
        (C.Plan memory original, C.Output[] memory rows) = _authorityViewBuildCheckpoint();
        require(
            original.tokenCount == 2 && original.nextIndex == 2 && rows.length == 2,
            "full actual checkpoint, no sampled substitute"
        );
        AuthorityViewConstructionBudgets memory b = _authorityViewConstructionBudgets();
        uint256 parent = Discovery(address(assemblyDiscovery)).configuration().componentGas;
        require(parent == 12000000 && b.outputValidationGas == 7000000, "original parent ceiling");
        require(
            avCheckpoint.configuration().servingGas == b.checkpointServingGas
                && avOutput.configuration().checkpointGas == b.outputValidationGas
                && avRetrieval.configuration().sourceGas == 7000000
                && avBundle.dependencies().archiveGas == 8000000,
            "actual fresh constructor values"
        );
        bytes memory input = abi.encodeCall(
            Checkpoint.requireCurrentCheckpoint, (authorityViewPublication.checkpoint)
        );
        bytes32 beforeHash = keccak256(abi.encode(original, rows));
        uint256 beforeGas = gasleft();
        (bool accepted, bytes memory result) =
            address(avCheckpoint).staticcall{ gas: b.outputValidationGas }(input);
        uint256 observed = beforeGas - gasleft();
        emit FreshViewCheckpointProbe(
            authorityViewPublication.checkpoint,
            keccak256(abi.encode(original)),
            parent,
            b.outputValidationGas,
            observed,
            accepted,
            result
        );
        // Preserve the complete production revert in a failing capture. A false result is a
        // failed trial, never an accepted profile or a reason to skip a row/read.
        if (!accepted) assembly ("memory-safe") { revert(add(result, 32), mload(result)) }
        require(
            keccak256(result) == keccak256(abi.encode(original)),
            "every original plan word returned by full currentness"
        );
        C.Output[] memory afterRows = new C.Output[](2);
        for (uint256 i; i < afterRows.length; ++i) {
            afterRows[i] = avCheckpoint.outputAt(authorityViewPublication.checkpoint, i);
        }
        require(
            keccak256(
                abi.encode(
                    avCheckpoint.requireCurrentCheckpoint(authorityViewPublication.checkpoint),
                    afterRows
                )
            ) == beforeHash,
            "bounded view does not change original complete outputs"
        );
    }
}

/// @notice Retain the original diagnostic deployment as an actual incompatible-budget control.
/// @dev The caller has a full reference and verifies its unrestricted state before and after
/// the bounded failure. No missing-record or mocked source is used to manufacture the refusal.
contract StreamCurrentAuthorityViewOriginalBudgetControlTest is
    StreamCurrentAuthorityViewReferenceFixture
{
    function testOriginalReferenceSixteenMillionChildCannotFitTwelveMillionParent() public {
        _authorityPrepareViewArtwork();
        _authorityDeclareAndAdoptView();
        _authorityPublishViewPreservation();
        _authorityFreezeViewArtwork();
        _authorityPublishViewReference();
        uint256 parent = Discovery(address(assemblyDiscovery)).configuration().componentGas;
        require(
            parent == 12000000 && avReference.dependencies().sourceGas == 16000000
                && avReference.dependencies().snapshotGas == 16000000,
            "original diagnostic constructor tuple retained"
        );
        Component target = Component(address(avReference));
        StreamFinalityComponentState memory beforeState =
            target.finalityStateForScope(authorityViewAdoption.scope);
        require(beforeState.frozen, "actual original current locked reference");
        (bool ok, bytes memory errorData) = address(avReference).staticcall{ gas: parent }(
            abi.encodeCall(Component.finalityStateForScope, (authorityViewAdoption.scope))
        );
        require(!ok && errorData.length == 68, "strict child-budget refusal");
        bytes4 selector;
        uint256 required;
        assembly ("memory-safe") {
            selector := mload(add(errorData, 32))
            required := mload(add(errorData, 68))
        }
        require(
            selector == Reads.RouterEvidenceGas.selector
                && required == 16000000 + uint256(16000000) / 63 + 100000,
            "the configured full sixteen-million forwarding reservation is retained"
        );
        require(
            keccak256(abi.encode(target.finalityStateForScope(authorityViewAdoption.scope)))
                == keccak256(abi.encode(beforeState)),
            "same original reference remains intact after bounded refusal"
        );
    }
}
