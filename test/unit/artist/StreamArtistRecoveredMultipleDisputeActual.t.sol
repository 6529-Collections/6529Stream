// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./ArtistRecoveredMultipleDisputeActualFixture.sol";

contract StreamArtistRecoveredMultipleDisputeActualTest is ArtistRecoveredMultipleDisputeActualFixture {
    function testAggregateSignedOpenCounterWithdrawAcrossTwoArtists() external {
        _openPair();
        _mdSigned(2, 3, keccak256("second counter"), false);
        _mdSelect(1);
        _mdSigned(1, 3, keccak256("first counter"), true);
        _mdSelect(2);
        _mdSigned(2, 2, keccak256("second withdrawal"), true);
        _mdSelect(1);
        _mdSigned(1, 2, keccak256("first withdrawal"), false);
        _finish();
    }

    function testAggregateOriginalInterleavedResolutionPoints() external {
        _openPair();
        _mdSelect(1);
        _mdResolve(1, 1, 1);
        _mdSelect(2);
        _mdResolve(2, 1, 1);
        Successor memory next = _multiCutover();
        (RH.Request memory r, Commit.Prepared memory p) = _mdPrepare(next);
        D.Bundle[] memory all = _mdHistory(p);
        require(
            all[0].resolutions[0].point.ownerRevision > all[0].disputes[0].point.ownerRevision + 1,
            "another collection occupies opening plus one"
        );
        _mdImport(next, r, p);
    }

}
