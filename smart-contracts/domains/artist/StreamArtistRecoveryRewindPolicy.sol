// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamArtistRecoveryRewindTypes as W
} from "../../interfaces/stream/artist/StreamArtistRecoveryRewindTypes.sol";
import {
    IStreamArtistRecoveryRewindSelection
} from "../../interfaces/stream/artist/IStreamArtistRecoveryRewindSelection.sol";
import {
    IStreamArtistSuccessionReads
} from "../../interfaces/stream/artist/IStreamArtistSuccessionRecords.sol";
import {
    StreamArtistSuccessionTypes as S
} from "../../interfaces/stream/artist/StreamArtistSuccessionTypes.sol";

/// @notice Dependencies are checked against one completed selection before any owner writes.
library StreamArtistRecoveryRewindPolicy {
    function exclusions(W.ResolutionManifestV3 memory m, W.RecordKind kind)
        public
        pure
        returns (bytes32[] memory hashes)
    {
        hashes = new bytes32[](m.supersededRecords.length);
        uint256 count;
        for (uint256 i; i < m.supersededRecords.length; ++i) {
            if (m.supersededRecords[i].kind == kind) {
                hashes[count++] = m.supersededRecords[i].recordHash;
            }
        }
        assembly ("memory-safe") { mstore(hashes, count) }
    }

    function capabilities(
        IStreamArtistRecoveryRewindSelection worker,
        W.ResultV3 memory r,
        bytes32 artistId,
        uint8 authorityClass
    ) public view returns (uint32 mask) {
        bytes32 designation = r.designation.operative.recordHash;
        if (designation == 0) {
            if (authorityClass == 3) revert W.InvalidRecoveryRewindRecord(designation);
            return 0;
        }
        S.DesignationRecord memory d =
            IStreamArtistSuccessionReads(address(this)).successorDesignationRecord(designation);
        if (
            d.recordHash != designation || d.terms.artistId != artistId
                || keccak256(abi.encode(d)) != r.designation.operative.originalDataHash
        ) {
            revert W.InvalidRecoveryRewindRecord(designation);
        }
        mask = d.terms.grantedCapabilities;
        bytes32 pair = d.terms.directiveHash;
        if (pair != 0) {
            (W.RecordKind kind, W.SelectedRecordV3 memory selected, bool retained, bool eligible) =
                worker.selectionRecordV3(r.sourceKey, pair);
            S.DirectiveRecord memory paired =
                IStreamArtistSuccessionReads(address(this)).estateDirectiveRecord(pair);
            if (
                kind != W.RecordKind.ESTATE_DIRECTIVE || !retained || selected.recordHash != pair
                    || paired.recordHash != pair || paired.terms.artistId != artistId
                    || keccak256(abi.encode(paired)) != selected.originalDataHash
                    || (authorityClass == 3 && !eligible)
            ) revert W.InvalidRecoveryRewindRecord(pair);
            mask &= paired.terms.grantedCapabilities;
        }
        bytes32 forbidden = r.directive.operative.recordHash;
        if (forbidden != 0) {
            S.DirectiveRecord memory directive =
                IStreamArtistSuccessionReads(address(this)).estateDirectiveRecord(forbidden);
            if (
                directive.recordHash != forbidden || directive.terms.artistId != artistId
                    || keccak256(abi.encode(directive)) != r.directive.operative.originalDataHash
            ) {
                revert W.InvalidRecoveryRewindRecord(forbidden);
            }
            mask &= ~directive.terms.forbiddenCapabilities;
        }
        mask &= 4095;
    }
}
