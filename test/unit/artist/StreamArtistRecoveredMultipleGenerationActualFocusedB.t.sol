// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./ArtistRecoveredMultipleGenerationActualFixture.sol";

contract StreamArtistRecoveredMultipleGenerationActualFocusedBTest is ArtistRecoveredMultipleGenerationActualFixture {
    function testGenerationAggregateGlobalGrantConservationCannotResetAtGenerationBoundary()
        external
    {
        _mgSource(true);
        Successor memory next = _multiCutover();
        (, Commit.Prepared memory prepared) = _mgPrepare(next);
        (, Payload.Payload memory idPayload) = Payload.decode(prepared.data[2].typedState, 2);
        M.State memory identities =
            ConsentCodec.decode(2, idPayload.semanticState, idPayload.provenance);
        (, Payload.Payload memory consentPayload) = Payload.decode(prepared.data[6].typedState, 6);
        M.State memory rows =
            ConsentCodec.decode(6, consentPayload.semanticState, consentPayload.provenance);
        G.Consents[] memory consents = new G.Consents[](rows.rows.length);
        for (uint256 k; k < consents.length; ++k) {
            consents[k] = abi.decode(rows.rows[k], (G.Consents));
        }
        (, Payload.Payload memory ap) = Payload.decode(prepared.data[4].typedState, 4);
        (M.State memory attested, bytes memory raw) =
            ConsentCodec.decodeAuxiliary(4, ap.semanticState, ap.provenance);
        G.Inventory memory inventory = abi.decode(raw, (G.Inventory));
        for (uint256 k; k < attested.rows.length; ++k) {
            attested.rows[k] = abi.encode(abi.decode(attested.rows[k], (G.Attribution)).records);
        }
        Conservation.Context memory x = Conservation.Context(
            identities.rows,
            identities,
            consents,
            attested.rows,
            inventory,
            prepared.admission.provenance
        );
        Conservation.validate(x);
        bytes memory saved = x.identities[0];
        for (uint256 n = 3; n <= 5; n += 2) {
            IH.Bundle memory b = abi.decode(saved, (IH.Bundle));
            b.delegations[1].record.uses = n;
            x.identities[0] = abi.encode(b);
            (bool ok,) = address(Conservation)
                .staticcall(abi.encodeWithSelector(Conservation.validate.selector, x));
            require(!ok, "missing or double-counted generation use rejects");
        }
        x.identities[0] = saved;
        Conservation.validate(x);
    }

    function testGenerationAggregateFinalCurrentnessRejectsOriginalArchiveInventoryDrift()
        external
    {
        _mgSource(false);
        Successor memory next = _multiCutover();
        (RH.Request memory r, Commit.Prepared memory prepared) = _mgPrepare(next);
        Current.requireCurrent(
            prepared.admission.provenance, prepared.query, prepared.data[4].typedState
        );
        (RH.ExportHeader memory header, Payload.Payload memory payload) =
            Payload.decode(prepared.data[4].typedState, 4);
        (M.State memory scope, bytes memory raw) =
            ConsentCodec.decodeAuxiliary(4, payload.semanticState, payload.provenance);
        G.Inventory memory inventory = abi.decode(raw, (G.Inventory));
        ++inventory.catalogues[0].upper[0];
        payload.semanticState =
            ConsentCodec.encode(4, scope, payload.provenance, abi.encode(inventory));
        header.semanticInventory = keccak256(payload.semanticState);
        (bool ok,) = address(Current)
            .staticcall(
                abi.encodeWithSelector(
                    Current.requireCurrent.selector,
                    prepared.admission.provenance,
                    prepared.query,
                    Payload.encode(4, header, payload)
                )
            );
        require(!ok, "full owner0 cutoff cannot hide inside owner4 envelope");
        Current.requireCurrent(
            prepared.admission.provenance, prepared.query, prepared.data[4].typedState
        );
        _mgImport(next, r, prepared, true);
    }

}
