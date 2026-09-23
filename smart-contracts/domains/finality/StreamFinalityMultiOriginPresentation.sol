// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "../../interfaces/stream/finality/StreamFinalityEvidenceTypes.sol";
import "../../interfaces/stream/finality/StreamFinalityConservationTypes.sol";

import {
    StreamFinalityMultiOriginConfiguration as Configuration
} from "./StreamFinalityMultiOriginConfiguration.sol";
import {
    StreamFinalityConservationReads as Conservation
} from "./StreamFinalityConservationReads.sol";
import {
    StreamMultiOriginInventoryCalls as OriginCalls
} from "../preservation/StreamMultiOriginInventoryCalls.sol";
import { StreamFinalityBoundedReads as Reads } from "./StreamFinalityBoundedReads.sol";
import {
    StreamArtistArchiveOriginTypes as O
} from "../../interfaces/stream/preservation/StreamArtistArchiveOriginTypes.sol";
import {
    StreamRenderCriticalSourceTypes as S
} from "../../interfaces/stream/preservation/StreamRenderCriticalSourceTypes.sol";
import "../../interfaces/stream/metadata/IStreamMetadataServingFacts.sol";

/// @notice Review projection of the exact locked presentation under authenticated current ancestry.
/// @dev The provider first admits its complete statement. This reuses its fixed source tuples;
/// it neither changes the Router's original Artist/Finality anchor nor reauthorizes old signers.
library StreamFinalityMultiOriginPresentation {
    error FinalityPresentationChanged();

    function artist(
        address[22] memory targets,
        bytes32[22] memory hashes,
        uint256 chainId,
        uint256 readGas,
        bytes32 dependencyHash,
        bytes32 inventoryProfile,
        StreamFinalityScope memory scope,
        StreamFinalityScopeInputs memory inputs
    ) public view returns (bytes32) {
        (S.Dependencies memory d, O.Dependencies memory od) = Configuration.read(
            targets, hashes, chainId, readGas, dependencyHash, inventoryProfile
        );
        Conservation.Dependencies memory cd;
        uint256[5] memory indexes = [uint256(0), 1, 4, 5, 17];
        for (uint256 i; i < 5; ++i) {
            cd.targets[i] = targets[indexes[i]];
            cd.codeHashes[i] = hashes[indexes[i]];
        }
        cd.chainId = chainId;
        cd.readGas = d.readGas;
        cd.selectionGas = d.selectionGas;
        StreamFinalityConservationEvidence memory selected = Conservation.requireCurrent(cd, scope);
        if (
            selected.intentRecordHash != inputs.intentRecordHash
                || selected.intentWaiverRecordHash != inputs.intentWaiverRecordHash
                || selected.interviewEvidenceHash != inputs.interviewEvidenceHash
        ) revert FinalityPresentationChanged();
        bytes memory raw = Reads.read(
            targets[2],
            abi.encodeCall(IStreamMetadataServingFacts.artistPresentation, (scope.collectionId)),
            384,
            readGas
        );
        IStreamMetadataServingFacts.ArtistPresentation memory presented =
            abi.decode(raw, (IStreamMetadataServingFacts.ArtistPresentation));
        if (keccak256(raw) != keccak256(abi.encode(presented))) {
            revert FinalityPresentationChanged();
        }
        (O.Origin memory current, O.Origin memory original, bytes32 lineageHash) =
            OriginCalls.lineage(d, od, scope.collectionId, presented, selected.selected.association);
        if (
            current.environment.registry != targets[11] || current.registryCodeHash != hashes[11]
                || original.environment.registry != presented.registry
                || original.registryCodeHash != presented.registryCodeHash || lineageHash == 0
                || presented.artistId != selected.selected.association.artistId
        ) revert FinalityPresentationChanged();
        return presented.artistId;
    }
}
