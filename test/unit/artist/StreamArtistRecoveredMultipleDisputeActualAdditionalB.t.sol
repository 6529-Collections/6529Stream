// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./ArtistRecoveredMultipleDisputeActualFixture.sol";

contract StreamArtistRecoveredMultipleDisputeActualAdditionalBTest is ArtistRecoveredMultipleDisputeActualFixture {
    function testAggregatePendingGenerationRevocationDoesNotInventAcceptance() external {
        _openPair();
        _mdSelect(1);
        bytes32 first = _mdResolve(1, 2, 2);
        _mdCorrectWithAcceptance(1, first, false);
        require(!Binding(suite.owners[0]).binding(1).accepted, "actual pending generation two");
        _governedOpen(1);
        bytes32 second = _mdResolve(1, 2, 2);
        _mdCorrect(1, second);
        Successor memory next = _multiCutover();
        (RH.Request memory r, Commit.Prepared memory p) = _mdPrepare(next);
        D.Bundle[] memory all = _mdHistory(p);
        require(
            all[0].generations.length == 3 && !all[0].generations[1].accepted,
            "retained original unaccepted interval"
        );
        _mdImport(next, r, p);
        T.Binding memory pending =
            Binding(next.coordinator.suiteConfiguration().owners[0]).bindingAt(1, 2);
        require(
            !pending.accepted
                && Acceptance(next.coordinator.suiteConfiguration().owners[3])
                    .acceptanceRecord(pending.bindingHash) == 0,
            "no synthetic acceptance after whole import"
        );
    }

    function testAggregateTwoVetoesShareOneGlobalIdentityInventory() external {
        _mdSource(false);
        RP.Record memory first = _mdStage(1, keccak256("veto first Artist"), false);
        _mdSelect(2);
        RP.Record memory second = _mdStage(2, keccak256("veto second Artist"), true);
        _mdSelect(1);
        _mdVeto(1, first);
        _mdSelect(2);
        _mdVeto(2, second);
        _finish();
    }

    function testAggregateTwoArtistsSameNumericDelegateNonceIndependentLanes() external {
        _mdSource(false);
        bytes32 first = _mcGrant(3);
        _mcPolicy(1, first, 77, false);
        _mdDelegated(1, 1, first, 78);
        _mdSelect(2);
        bytes32 second = _mcGrant(3);
        _mcPolicy(2, second, 77, false);
        _mdDelegated(2, 1, second, 78);
        _mdSelect(1);
        _mdDelegated(1, 2, first, 79);
        _mdSelect(2);
        _mdDelegated(2, 2, second, 79);
        Successor memory next = _multiCutover();
        (RH.Request memory r, Commit.Prepared memory p) = _mdPrepare(next);
        _mdImport(next, r, p);
        for (uint256 k; k < 2; ++k) {
            (bool used,) = next.registry
                .delegatedNonceState(multiCollectionArtists[k], address(delegateSafe), 77);
            require(used, "same numeric nonce survives in independent original Artist lanes");
        }
    }

    function testAggregateGrantConservationAndPerArtistC2PAAcrossFamilies() external {
        _crossFamilies();
        _finish();
    }

}
