// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    StreamArtistCompleteHistoryConservation as Conservation
} from "../../../smart-contracts/domains/artist/StreamArtistCompleteHistoryConservation.sol";
import {
    StreamArtistRecoveredHydrationTypes as RH
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistRecoveredHydrationTypes.sol";
import {
    StreamArtistAuthorityHydrationTypes as AH
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistAuthorityHydration.sol";
import {
    StreamArtistHistoryTypes as H
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistHistory.sol";
import {
    StreamArtistOnboardingTypes as T
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistOnboardingTypes.sol";
import {
    StreamArtistRecoveredMultipleGenerationTypes as G
} from "../../../smart-contracts/domains/artist/StreamArtistRecoveredMultipleGenerationTypes.sol";
import {
    StreamArtistRecoveredBindingCorrectionTypes as CB
} from "../../../smart-contracts/domains/artist/StreamArtistRecoveredBindingCorrectionTypes.sol";
import {
    StreamArtistRecoveredAcceptedGenerationTypes as A
} from "../../../smart-contracts/domains/artist/StreamArtistRecoveredAcceptedGenerationTypes.sol";
import {
    StreamArtistRecoveredAttestationHydration as Records
} from "../../../smart-contracts/domains/artist/StreamArtistRecoveredAttestationHydration.sol";
import {
    StreamArtistRecoveredDisputeHistoryTypes as D
} from "../../../smart-contracts/domains/artist/StreamArtistRecoveredDisputeHistoryTypes.sol";

interface CompleteHistoryConservationVm {
    function expectRevert(bytes4) external;
}

/// @notice Typed empty-graph boundary vectors, not original source or Platform proof.
contract StreamArtistCompleteHistoryConservationEmptyTest {
    CompleteHistoryConservationVm private constant vm =
        CompleteHistoryConservationVm(address(uint160(uint256(keccak256("hevm cheat code")))));

    function testCompleteConservationAllUnboundValidatesExplicitEmptyFamilies() external pure {
        Conservation.Context memory x = _empty();
        Conservation.validate(x);
        require(x.identities.length == 0, "no synthetic Artist needed");
        require(x.inventory.provenance.journals[4].length == 1, "whole Platform journal retained");
    }

    function testCompleteConservationZeroIdentitiesCannotHideFamilyState() external {
        Conservation.Context memory x = _empty();
        x.histories[0].pending = keccak256("invented pending repudiation");
        vm.expectRevert(RH.InvalidRecoveredHydrationProfile.selector);
        Conservation.validate(x);
        x.histories[0].pending = 0;
        Records.Bundle memory attested = abi.decode(x.attestations[0], (Records.Bundle));
        attested.personhood = new Records.PersonhoodRow[](1);
        x.attestations[0] = abi.encode(attested);
        vm.expectRevert(RH.InvalidRecoveredHydrationProfile.selector);
        Conservation.validate(x);
    }

    function testCompleteConservationZeroIdentitiesCannotOmitOrClaimBoundNativeRows() external {
        Conservation.Context memory x = _empty();
        x.consents = new G.Consents[](0);
        vm.expectRevert(RH.InvalidRecoveredHydrationProfile.selector);
        Conservation.validate(x);
        x = _empty();
        x.inventory.provenance.journals[4][0].receipt.operation = 24;
        x.inventory.provenance.journals[4][0].receipt.artistId = bytes32(uint256(1));
        vm.expectRevert(RH.InvalidRecoveredHydrationProfile.selector);
        Conservation.validate(x);
    }

    function _empty() private pure returns (Conservation.Context memory x) {
        RH.OriginEnvironment memory o;
        o.chainId = 1;
        o.registry = address(1);
        o.coordinator = address(2);
        o.archive = address(3);
        o.core = address(4);
        o.manager = address(5);
        o.suiteConfigurationHash = bytes32(uint256(6));
        for (uint8 owner; owner < 7; ++owner) {
            o.owners[owner] = address(uint160(10 + owner));
            o.ownerCodeHashes[owner] = bytes32(uint256(20 + owner));
        }
        RH.Provenance memory p;
        p.origins = new RH.OriginEnvironment[](1);
        p.origins[0] = o;
        p.eras = new RH.Era[](1);
        p.eras[0].originHash = RH.originHash(o);
        for (uint8 owner; owner < 7; ++owner) {
            p.eras[0].checkpoints[owner].schema = RH.CHECKPOINT;
            p.eras[0].checkpoints[owner].ownerState =
                T.Snapshot(RH.ownerDomain(owner), 10, bytes32(uint256(1)), bytes32(uint256(2)));
        }
        p.journals[4] = new RH.JournalEntry[](1);
        p.journals[4][0] = RH.JournalEntry(
            RH.Position(RH.Point(p.eras[0].originHash, 4, 1), 0),
            H.Receipt(10, 0, 7, bytes32(uint256(40)))
        );
        p.eras[0].nativeCounts[4] = 1;
        x.inventory.provenance = p;
        x.scope.collections = new AH.Query[](1);
        x.scope.collections[0].collectionId = 7;
        x.scope.collections[0].records = new bytes32[](1);
        x.scope.collections[0].records[0] = p.journals[4][0].receipt.recordHash;
        x.inventory.bindings.bindings = new CB.Bundle[](1);
        x.inventory.bindings.bindings[0].bindings.collectionId = 7;
        x.inventory.bindings.bindings[0].bindings.provenanceCommitment =
            RH.ownerProvenanceHash(RH.ownerProvenance(p, 0), 0);
        x.inventory.bindings.generations = new A.Generation[][](1);
        x.inventory.bindings.collaborators = new T.CollaboratorRecord[][][](1);
        x.consents = new G.Consents[](1);
        x.consents[0].rows.original.collectionId = 7;
        x.consents[0].rows.original.provenance = RH.ownerProvenanceHash(RH.ownerProvenance(p, 6), 6);
        Records.Bundle memory attested;
        attested.collectionId = 7;
        attested.provenance = RH.ownerProvenanceHash(RH.ownerProvenance(p, 4), 4);
        x.attestations = new bytes[](1);
        x.attestations[0] = abi.encode(attested);
        x.histories = new D.Bundle[](1);
        x.histories[0].collectionId = 7;
        x.histories[0].provenance = attested.provenance;
    }
}
