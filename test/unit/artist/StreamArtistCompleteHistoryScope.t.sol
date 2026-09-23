// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    StreamArtistCompleteHistoryScope as Scope
} from "../../../smart-contracts/domains/artist/StreamArtistCompleteHistoryScope.sol";
import {
    StreamArtistRecoveredHydrationTypes as RH
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistRecoveredHydrationTypes.sol";
import {
    StreamArtistMultipleHydrationTypes as MH
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistMultipleAuthorityHydration.sol";
import {
    StreamArtistRecoveredMultipleTypes as M
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistRecoveredMultipleTypes.sol";
import {
    StreamArtistOnboardingTypes as T
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistOnboardingTypes.sol";
import {
    StreamArtistHistoryTypes as H
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistHistory.sol";

/// @notice Membership-level oracles; actual writer chronology is tested separately.
interface CompleteHistoryScopeVm {
    function expectRevert(bytes4) external;
}

contract StreamArtistCompleteHistoryScopeTest {
    CompleteHistoryScopeVm private constant vm =
        CompleteHistoryScopeVm(address(uint160(uint256(keccak256("hevm cheat code")))));

    function assertEq(uint256 a, uint256 b) private pure {
        require(a == b, "count differs");
    }

    function assertEq(bytes32 a, bytes32 b) private pure {
        require(a == b, "record differs");
    }

    function assertEq(bytes memory a, bytes memory b) private pure {
        require(keccak256(a) == keccak256(b), "bytes differ");
    }

    function assertFalse(bool value) private pure {
        require(!value, "unexpected acceptance");
    }

    function testFormerAndCurrentArtistAndOrdinaryCollaboratorKeepNativeMembership() public pure {
        (MH.Request memory r, T.Binding[] memory heads, RH.Provenance memory p) = _history();
        M.State memory s = Scope.partition(r, heads, p);
        assertEq(s.artists.length, 3);
        assertEq(s.artists[0].records.length, 3);
        assertEq(s.artists[1].records.length, 2);
        assertEq(s.artists[2].records.length, 2);
        assertEq(s.collections[0].records.length, 1);
        assertEq(s.collections[1].records.length, 4);
        assertEq(s.collections[1].artistId, bytes32(uint256(2)));
        assertEq(s.collections[1].records[0], bytes32(uint256(101)));
        assertEq(s.collections[1].records[1], bytes32(uint256(102)));
        assertEq(s.collections[1].records[2], bytes32(uint256(103)));
        assertEq(s.collections[1].records[3], bytes32(uint256(104)));
    }

    function testOmittingFormerArtistRejectsWholeSource() public {
        (MH.Request memory r, T.Binding[] memory heads, RH.Provenance memory p) = _history();
        r.artistIds = new bytes32[](2);
        r.artistIds[0] = bytes32(uint256(2));
        r.artistIds[1] = bytes32(uint256(3));
        vm.expectRevert(RH.InvalidRecoveredHydrationProfile.selector);
        Scope.partition(r, heads, p);
    }

    function testOmittingPlatformSiblingRejectsWholeSource() public {
        (MH.Request memory r, T.Binding[] memory heads, RH.Provenance memory p) = _history();
        r.collections[0] = r.collections[1];
        heads[0] = heads[1];
        MH.Collection[] memory selected = new MH.Collection[](1);
        selected[0] = r.collections[0];
        r.collections = selected;
        T.Binding[] memory current = new T.Binding[](1);
        current[0] = heads[0];
        vm.expectRevert(RH.InvalidRecoveredHydrationProfile.selector);
        Scope.partition(r, current, p);
    }

    function testZeroArtistCannotMasqueradeAsBoundDispute() public {
        (MH.Request memory r, T.Binding[] memory heads, RH.Provenance memory p) = _history();
        p.journals[4][0].receipt.operation = 44;
        vm.expectRevert(RH.InvalidRecoveredHydrationProfile.selector);
        Scope.partition(r, heads, p);
    }

    function testEachDependencyRequiresItsOwnUniqueRegistration() public {
        (MH.Request memory r, T.Binding[] memory heads, RH.Provenance memory p) = _history();
        p.journals[2][2].receipt.operation = 25;
        vm.expectRevert(RH.InvalidRecoveredHydrationProfile.selector);
        Scope.partition(r, heads, p);
        p.journals[2][2].receipt.operation = 6;
        p.journals[2][2].receipt.recordHash = bytes32(uint256(123));
        vm.expectRevert(RH.InvalidRecoveredHydrationProfile.selector);
        Scope.partition(r, heads, p);
    }

    function testPendingAndTerminalHeadsDoNotInventAcceptance() public pure {
        (MH.Request memory r, T.Binding[] memory heads, RH.Provenance memory p) = _history();
        assertFalse(heads[1].accepted);
        M.State memory s = Scope.partition(r, heads, p);
        assertEq(s.collections[1].bindingHash, heads[1].bindingHash);
        // No completion/terminal claim belongs to membership. The source family proves it.
        heads[1].accepted = true;
        assertEq(abi.encode(Scope.partition(r, heads, p)), abi.encode(s));
    }

    function _history()
        private
        pure
        returns (MH.Request memory r, T.Binding[] memory heads, RH.Provenance memory p)
    {
        r.artistIds = new bytes32[](3);
        for (uint256 i; i < 3; ++i) {
            r.artistIds[i] = bytes32(i + 1);
        }
        r.collections = new MH.Collection[](2);
        r.collections[0].collectionId = 10;
        r.collections[1].collectionId = 20;
        r.collections[1].artistId = bytes32(uint256(2));
        heads = new T.Binding[](2);
        heads[1].artistId = bytes32(uint256(2));
        heads[1].generation = 2;
        heads[1].bindingHash = bytes32(uint256(102));
        p.journals[0] = new RH.JournalEntry[](2);
        p.journals[0][0].receipt = H.Receipt(1, bytes32(uint256(1)), 20, bytes32(uint256(101)));
        p.journals[0][1].receipt = H.Receipt(1, bytes32(uint256(2)), 20, bytes32(uint256(102)));
        p.journals[2] = new RH.JournalEntry[](3);
        for (uint256 i; i < 3; ++i) {
            p.journals[2][i].receipt = H.Receipt(i == 2 ? 6 : 1, bytes32(i + 1), 0, bytes32(i + 1));
        }
        p.journals[3] = new RH.JournalEntry[](2);
        p.journals[3][0].receipt = H.Receipt(2, bytes32(uint256(1)), 20, bytes32(uint256(103)));
        p.journals[3][1].receipt = H.Receipt(7, bytes32(uint256(3)), 20, bytes32(uint256(104)));
        p.journals[4] = new RH.JournalEntry[](1);
        p.journals[4][0].receipt = H.Receipt(8, 0, 10, bytes32(uint256(105)));
    }
}
