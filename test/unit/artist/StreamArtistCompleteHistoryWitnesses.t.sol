// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamArtistCompleteHistoryWitnesses as W
} from "../../../smart-contracts/domains/artist/StreamArtistCompleteHistoryWitnesses.sol";
import {
    StreamArtistRecoveredHydrationTypes as RH
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistRecoveredHydrationTypes.sol";
import {
    StreamArtistRecoveredMultipleTypes as M
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistRecoveredMultipleTypes.sol";
import {
    StreamArtistMultipleRecordsTypes as MR
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistMultipleRecordsHydration.sol";
import {
    StreamArtistAuthorityHydrationTypes as AH
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistAuthorityHydration.sol";
import {
    StreamArtistReadinessHydrationTypes as R
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistReadinessAuthorityHydration.sol";
import {
    StreamArtistOnboardingTypes as T
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistOnboardingTypes.sol";
import {
    StreamArtistHistoryTypes as H
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistHistory.sol";

interface CompleteHistoryWitnessVm {
    function expectRevert(bytes4) external;
}

/// @notice Witness-order tests only; authentic source and family validation is a separate boundary.
contract StreamArtistCompleteHistoryWitnessesTest {
    CompleteHistoryWitnessVm private constant vm =
        CompleteHistoryWitnessVm(address(uint160(uint256(keccak256("hevm cheat code")))));

    struct Fixture {
        T.SuiteConfiguration source;
        RH.Provenance provenance;
        M.State scope;
        MR.CollectionWitness[] witnesses;
        T.RoyaltyFreeze[] royalties;
    }

    function testHistoricalPrincipalWitnessOrderSurvivesCurrentArtistAndPlatformSibling()
        external
        pure
    {
        Fixture memory f = _fixture();
        W.Plan memory plan = W.collect(f.source, f.provenance, f.scope, f.witnesses, f.royalties);
        require(
            plan.economics[0].length == 0 && plan.attestations[0].length == 0,
            "unbound has no invented witnesses"
        );
        require(
            plan.economics[1].length == 1 && plan.attestations[1].length == 1
                && plan.freezes[1].length == 1,
            "full occurrences"
        );
        require(
            keccak256(abi.encode(plan.economics[1][0]))
                == keccak256(abi.encode(f.witnesses[0].economics[0])),
            "original economics"
        );
        require(
            keccak256(abi.encode(plan.freezes[1][0])) == keccak256(abi.encode(f.royalties[0])),
            "original royalty"
        );
    }

    function testMissingHistoricalEconomicsWitnessRejects() external {
        Fixture memory f = _fixture();
        f.witnesses[0].economics = new T.EconomicsConsent[](0);
        vm.expectRevert(RH.InvalidRecoveredHydrationProfile.selector);
        W.collect(f.source, f.provenance, f.scope, f.witnesses, f.royalties);
    }

    function testZeroPrincipalCannotSupplyBoundRatification() external {
        Fixture memory f = _fixture();
        f.provenance.journals[6][2].receipt.artistId = 0;
        vm.expectRevert(RH.InvalidRecoveredHydrationProfile.selector);
        W.collect(f.source, f.provenance, f.scope, f.witnesses, f.royalties);
    }

    function testOmittedFormerPrincipalRejectsWitnessPlan() external {
        Fixture memory f = _fixture();
        f.scope.artists = new AH.Query[](1);
        f.scope.artists[0].artistId = bytes32(uint256(2));
        vm.expectRevert(RH.InvalidRecoveredHydrationProfile.selector);
        W.collect(f.source, f.provenance, f.scope, f.witnesses, f.royalties);
    }

    function _fixture() private pure returns (Fixture memory f) {
        f.source.primaryResolver = address(0x100);
        f.scope.artists = new AH.Query[](2);
        f.scope.artists[0].artistId = bytes32(uint256(1));
        f.scope.artists[1].artistId = bytes32(uint256(2));
        f.scope.collections = new AH.Query[](2);
        f.scope.collections[0].collectionId = 10;
        f.scope.collections[1].collectionId = 20;
        f.scope.collections[1].artistId = bytes32(uint256(2));
        f.provenance.journals[6] = new RH.JournalEntry[](5);
        uint16[5] memory ops = [uint16(15), 20, 52, 12, 13];
        for (uint256 i; i < ops.length; ++i) {
            f.provenance.journals[6][i].receipt =
                H.Receipt(ops[i], bytes32(uint256(1)), 20, bytes32(i + 1));
        }
        f.provenance.journals[4] = new RH.JournalEntry[](3);
        f.provenance.journals[4][0].receipt = H.Receipt(8, 0, 10, bytes32(uint256(10)));
        f.provenance.journals[4][1].receipt =
            H.Receipt(24, bytes32(uint256(1)), 20, bytes32(uint256(11)));
        f.provenance.journals[4][2].receipt =
            H.Receipt(44, bytes32(uint256(2)), 20, bytes32(uint256(12)));
        f.witnesses = new MR.CollectionWitness[](1);
        f.witnesses[0].collectionId = 20;
        f.witnesses[0].economics = new T.EconomicsConsent[](1);
        f.witnesses[0].economics[0].collectionId = 20;
        f.witnesses[0].economics[0].resolver = f.source.primaryResolver;
        f.witnesses[0].attestations = new R.AttestationInput[](1);
        f.royalties = new T.RoyaltyFreeze[](1);
        f.royalties[0].collectionId = 20;
    }
}
