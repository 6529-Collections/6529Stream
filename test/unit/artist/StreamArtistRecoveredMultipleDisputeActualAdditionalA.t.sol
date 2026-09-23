// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./ArtistRecoveredMultipleDisputeActualFixture.sol";

contract StreamArtistRecoveredMultipleDisputeActualAdditionalATest is ArtistRecoveredMultipleDisputeActualFixture {
    function testAggregateRevocationReopenAndOriginalSecondResolution() external {
        _openPair();
        _mdSelect(1);
        _mdResolve(1, 2, 2);
        _mdSelect(2);
        _mdSigned(2, 2, keccak256("other withdrawal"), false);
        _mdSelect(1);
        _governedOpen(1);
        require(
            ingress.attributionDispute(1, 1).reopened, "actual arbiter reopened prior revocation"
        );
        _mdResolve(1, 1, 2);
        _finish();
    }

    function testAggregateSharedArtistPendingCountsAndOriginalCancellation() external {
        _mdSource(true);
        RP.Record memory first = _mdStage(1, keccak256("first pending"), false);
        _mdStage(2, keccak256("second pending"), true);
        _mdCancel(1, first);
        Successor memory next = _multiCutover();
        (RH.Request memory r, Commit.Prepared memory p) = _mdPrepare(next);
        _mdImport(next, r, p);
        D.Bundle[] memory all = _mdHistory(p);
        require(all[0].pending == 0 && all[1].pending != 0, "distinct live pending cells");
        require(
            RepudiationOwner(next.coordinator.suiteConfiguration().owners[4])
                .repudiationCount(artistId, keccak256(abi.encode(first.authorityHead))) == 1,
            "one global cohort count"
        );
    }

    function testAggregateGuardianVetoPreservesOriginalIdentityPairAndOtherArtist() external {
        _mdSource(false);
        RP.Record memory first = _mdStage(1, keccak256("veto first"), false);
        _mdSelect(2);
        RP.Record memory second = _mdStage(2, keccak256("cancel second"), true);
        _mdCancel(2, second);
        _mdSelect(1);
        _mdVeto(1, first);
        _finish();
    }

    function testAggregateExecutedRepudiationCorrectionAndLaterSignedHistory() external {
        _mdSource(false);
        RP.Record memory first = _mdStage(1, keccak256("execute first"), false);
        _mdSelect(2);
        _mdSigned(2, 1, keccak256("interleaved second"), true);
        _mdSelect(1);
        _mdExecute(1, first);
        _mdCorrect(1, first.recordHash);
        _mdSigned(1, 1, keccak256("later generation opening"), true);
        _mdSigned(1, 2, keccak256("later generation withdrawal"), false);
        _finish();
    }

}
