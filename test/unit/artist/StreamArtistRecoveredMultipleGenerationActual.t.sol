// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./ArtistRecoveredMultipleGenerationActualFixture.sol";

contract StreamArtistRecoveredMultipleGenerationActualTest is ArtistRecoveredMultipleGenerationActualFixture {
    function testGenerationAggregatePreservesSameTermsEconomicsSalesAndGlobalGrants() external {
        _mgSource(true);
        require(
            mgEconomics.length == 2
                && keccak256(abi.encode(mgEconomics[0])) == keccak256(abi.encode(mgEconomics[1])),
            "genuine identical original15 terms"
        );
        bytes32 first = Consent(suite.owners[6]).economicsRecord(mgEconomics[0]);
        Economics.Association memory later =
            Economics(suite.owners[6]).economicsRecordAssociation(mcEconomicsRecord);
        require(
            first != mcEconomicsRecord && later.originalRecord == first
                && later.bindingGeneration == 2,
            "original terms anchor and distinct continuation"
        );
        require(
            ingress.delegationRecord(mcGrants[0]).uses == 7
                && ingress.delegationRecord(mcGrants[1]).uses == 4,
            "global all-version use totals"
        );
        Successor memory next = _multiCutover();
        (RH.Request memory r, Commit.Prepared memory p) = _mgPrepare(next);
        _mgImport(next, r, p, false);
    }

    function testGenerationAggregateLateArchiveFailureRollsBackAllScopesThenSafeRetries() external {
        _mgSource(true);
        Successor memory next = _multiCutover();
        (RH.Request memory r, Commit.Prepared memory p) = _mgPrepare(next);
        bytes32 before_ = _mgHash(next);
        uint256 nonce = rotationSafe.nonce();
        uint256 at = block.number;
        bytes memory data = abi.encodeCall(
            ConsentHydration.hydrateRecoveredArtistAuthorityWithConsents, (r, mgRoyalties)
        );
        vm.roll(uint256(type(uint64).max) + 1);
        vm.expectRevert(
            abi.encodeWithSignature(
                "ArtistArchiveBlockNumberOverflow(uint256)", uint256(type(uint64).max) + 1
            )
        );
        ConsentHydration(address(next.registry))
            .hydrateRecoveredArtistAuthorityWithConsents(r, mgRoyalties);
        require(_mgHash(next) == before_, "all seven owners and generation maps rolled back");
        vm.expectRevert(bytes("GS013"));
        this.rhExecuteNewSafe(address(next.registry), data);
        require(
            rotationSafe.nonce() == nonce && _mgHash(next) == before_,
            "Safe nonce and full graph rollback"
        );
        vm.roll(at);
        _mgImport(next, r, p, true);
    }

}
