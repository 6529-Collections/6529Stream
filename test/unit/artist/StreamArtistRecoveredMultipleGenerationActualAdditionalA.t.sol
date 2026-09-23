// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./ArtistRecoveredMultipleGenerationActualFixture.sol";

contract StreamArtistRecoveredMultipleGenerationActualAdditionalATest is ArtistRecoveredMultipleGenerationActualFixture {
    function testGenerationAggregateDirectSafeKeepsInterleavedResolutionCoordinates() external {
        _mgSource(false);
        Successor memory next = _multiCutover();
        (RH.Request memory r, Commit.Prepared memory p) = _mgPrepare(next);
        RH.OwnerProvenance memory owner = RH.ownerProvenance(p.admission.provenance, 4);
        bool found;
        for (uint256 i; i < owner.journal.length; ++i) {
            if (owner.journal[i].receipt.operation == 44) {
                require(
                    owner.journal[i + 1].receipt.operation == 24,
                    "actual other collection write inside governed dispute"
                );
                for (uint256 j; j < owner.aliases.length; ++j) {
                    if (
                        owner.aliases[j].surface
                                == keccak256("attribution_lifecycle.replay.dispute_resolution_key")
                            && owner.aliases[j].scope == owner.journal[i].receipt.recordHash
                    ) {
                        require(
                            owner.aliases[j].admittedAt.ownerRevision
                                == owner.journal[i].position.point.ownerRevision + 2,
                            "authentic resolution is not opening plus one"
                        );
                        found = true;
                    }
                }
            }
        }
        require(found, "original resolution alias");
        _mgImport(next, r, p, true);
    }

    function testGenerationAggregateMixedClassThreeCorrectionAndOriginalSafe() external {
        _multiSource(false, true);
        _adoptRotatedSafe();
        vm.warp(ingress.artistTransitionState(multiRecovery[1]).postWindowEndsAt);
        _mgCorrect(2);
        _maCredential(2, 0, 0, 0, true);
        require(maRows[0].authorityClass == 3, "actual recovered class3 generation2");
        Successor memory next = _multiCutover();
        (RH.Request memory r, Commit.Prepared memory p) = _mgPrepare(next);
        _mgImport(next, r, p, true);
    }

    function testGenerationAggregateRepeatedImportRetainsAllOriginalEraPoints() external {
        _mgSource(false);
        Successor memory middle = _multiCutover();
        (RH.Request memory r, Commit.Prepared memory p) = _mgPrepare(middle);
        _mgImport(middle, r, p, true);
        _rhAdopt(middle);
        Successor memory next = _multiCutover();
        (r, p) = _mgPrepare(next);
        require(p.admission.provenance.eras.length == 2, "full inherited and current provenance");
        _mgImport(next, r, p, true);
    }

}
