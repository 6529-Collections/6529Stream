// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./ArtistRecoveredMultipleDisputeFixture.sol";
import {
    StreamArtistCompleteHistoryConservation as CHConservation
} from "../../../smart-contracts/domains/artist/StreamArtistCompleteHistoryConservation.sol";
import {
    StreamArtistRecoveredMultipleGenerationTypes as CHG
} from "../../../smart-contracts/domains/artist/StreamArtistRecoveredMultipleGenerationTypes.sol";

/// @notice Actual original Consent, op24 and dispute uses share one retained grant ledger.
/// @dev The established source fixture supplies canonical complete rows. This tests the new
/// conservation join, not the not-yet-composed CompleteHistory import route.
contract StreamArtistCompleteHistoryConservationActualTest is
    ArtistRecoveredMultipleDisputeFixture
{
    function testCompleteHistoryConservationRetainsAllFamiliesAndRevokedGrantVersion() external {
        _mdSource(true);
        bytes32 grant = _mcGrant(9);
        _mdFamilies(grant);
        bytes32 credential = _maCredential(1, 0, grant, 4, false);
        _mdDelegated(1, 1, grant, 5);
        _maCredential(2, credential, grant, 6, false);
        _mdSigned(1, 3, keccak256("original direct counter"), true);
        _mdDelegated(1, 2, grant, 7);
        require(ingress.delegationRecord(grant).uses == 9, "actual original global count");
        _mcRevoke(grant);
        _mcGrant(0);

        Successor memory next = _multiCutover();
        (, Commit.Prepared memory prepared) = _mdPrepare(next);
        CHConservation.Context memory x = _conservation(prepared);
        CHConservation.validate(x);

        // Keep every original source family and occurrence, changing only its saved total.
        // Counting Consent and op24 while dropping the dispute contribution would accept 7.
        bytes memory saved = x.identities[0];
        IH.Bundle memory identity = abi.decode(saved, (IH.Bundle));
        bool found;
        for (uint256 g; g < identity.delegations.length; ++g) {
            if (identity.delegations[g].recordHash != grant) continue;
            require(identity.delegations[g].record.revoked, "retained revoked grant version");
            require(identity.delegations[g].record.uses == 9, "source total unchanged");
            identity.delegations[g].record.uses = 7;
            found = true;
        }
        require(found, "authentic retained grant");
        x.identities[0] = abi.encode(identity);
        (bool ok, bytes memory reason) = address(CHConservation)
            .staticcall(abi.encodeWithSelector(CHConservation.validate.selector, x));
        require(
            !ok
                && keccak256(reason)
                    == keccak256(
                        abi.encodeWithSelector(RH.InvalidRecoveredHydrationProfile.selector)
                    ),
            "all three family increments required"
        );
        x.identities[0] = saved;
        CHConservation.validate(x);
    }

    function _conservation(Commit.Prepared memory prepared)
        private
        pure
        returns (CHConservation.Context memory x)
    {
        (, Payload.Payload memory identity) = Payload.decode(prepared.data[2].typedState, 2);
        x.scope = ConsentCodec.decode(2, identity.semanticState, identity.provenance);
        x.identities = x.scope.rows;
        (, Payload.Payload memory consent) = Payload.decode(prepared.data[6].typedState, 6);
        M.State memory rows = ConsentCodec.decode(6, consent.semanticState, consent.provenance);
        x.consents = new CHG.Consents[](rows.rows.length);
        for (uint256 k; k < x.consents.length; ++k) {
            x.consents[k] = abi.decode(rows.rows[k], (CHG.Consents));
        }
        (, Payload.Payload memory attribution) = Payload.decode(prepared.data[4].typedState, 4);
        (M.State memory attested, bytes memory raw) =
            ConsentCodec.decodeAuxiliary(4, attribution.semanticState, attribution.provenance);
        CHG.Inventory memory inventory = abi.decode(raw, (CHG.Inventory));
        x.inventory.provenance = prepared.admission.provenance;
        x.inventory.bindings.bindings = inventory.bindings;
        x.inventory.bindings.generations = inventory.generations;
        x.attestations = new bytes[](attested.rows.length);
        x.histories = new D.Bundle[](attested.rows.length);
        for (uint256 k; k < attested.rows.length; ++k) {
            MD.Attribution memory row = abi.decode(attested.rows[k], (MD.Attribution));
            x.attestations[k] = abi.encode(row.records);
            x.histories[k] = row.history;
        }
    }
}
