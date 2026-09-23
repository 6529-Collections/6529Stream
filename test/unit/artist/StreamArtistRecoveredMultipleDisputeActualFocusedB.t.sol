// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./ArtistRecoveredMultipleDisputeActualFixture.sol";

contract StreamArtistRecoveredMultipleDisputeActualFocusedBTest is ArtistRecoveredMultipleDisputeActualFixture {
    function testAggregateGlobalGrantCountRejectsMissingDisputeFamily() external {
        _crossFamilies();
        Successor memory next = _multiCutover();
        (RH.Request memory r, Commit.Prepared memory p) = _mdPrepare(next);
        (, Payload.Payload memory id) = Payload.decode(p.data[2].typedState, 2);
        M.State memory identities = ConsentCodec.decode(2, id.semanticState, id.provenance);
        (, Payload.Payload memory consent) = Payload.decode(p.data[6].typedState, 6);
        M.State memory rows = ConsentCodec.decode(6, consent.semanticState, consent.provenance);
        G.Consents[] memory consents = new G.Consents[](rows.rows.length);
        for (uint256 k; k < consents.length; ++k) {
            consents[k] = abi.decode(rows.rows[k], (G.Consents));
        }
        (, Payload.Payload memory ap) = Payload.decode(p.data[4].typedState, 4);
        (M.State memory attested, bytes memory raw) =
            ConsentCodec.decodeAuxiliary(4, ap.semanticState, ap.provenance);
        G.Inventory memory inventory = abi.decode(raw, (G.Inventory));
        for (uint256 k; k < attested.rows.length; ++k) {
            attested.rows[k] = abi.encode(abi.decode(attested.rows[k], (MD.Attribution)).records);
        }
        DisputeConservation.Context memory x = DisputeConservation.Context(
            identities.rows,
            identities,
            consents,
            attested.rows,
            inventory,
            p.admission.provenance,
            _mdHistory(p)
        );
        DisputeConservation.validate(x);
        bytes memory saved = x.identities[0];
        IH.Bundle memory b = abi.decode(saved, (IH.Bundle));
        bool changed;
        for (uint256 j; j < b.delegations.length; ++j) {
            if (b.delegations[j].recordHash == mcGrants[0]) {
                require(b.delegations[j].record.uses == 9, "known actual global count");
                b.delegations[j].record.uses = 7;
                changed = true;
            }
        }
        require(changed, "selected actual original grant");
        x.identities[0] = abi.encode(b);
        (bool ok, bytes memory reason) = address(DisputeConservation)
            .staticcall(abi.encodeWithSelector(DisputeConservation.validate.selector, x));
        require(
            !ok
                && keccak256(reason)
                    == keccak256(
                        abi.encodeWithSelector(RH.InvalidRecoveredHydrationProfile.selector)
                    ),
            "consent plus24 cannot omit original44/61 grant uses"
        );
        x.identities[0] = saved;
        DisputeConservation.validate(x);
        _mdImport(next, r, p);
    }

    function testAggregateLateArchiveFailureRollsBackAllOwnersThenIdenticalSafeRetry() external {
        _crossFamilies();
        Successor memory next = _multiCutover();
        (RH.Request memory r, Commit.Prepared memory p) = _mdPrepare(next);
        bytes memory data = abi.encodeCall(
            ConsentHydration.hydrateRecoveredArtistAuthorityWithConsents, (r, mdRoyalties)
        );
        bytes32 before_ = _mdState(next, p);
        uint256 nonce = rotationSafe.nonce();
        uint256 at = block.number;
        vm.roll(uint256(type(uint64).max) + 1);
        vm.expectRevert(
            abi.encodeWithSignature(
                "ArtistArchiveBlockNumberOverflow(uint256)", uint256(type(uint64).max) + 1
            )
        );
        ConsentHydration(address(next.registry))
            .hydrateRecoveredArtistAuthorityWithConsents(r, mdRoyalties);
        require(
            _mdState(next, p) == before_,
            "direct late append rollback all seven owners and original maps"
        );
        vm.expectRevert(bytes("GS013"));
        this.rhExecuteNewSafe(address(next.registry), data);
        require(
            rotationSafe.nonce() == nonce && _mdState(next, p) == before_,
            "Safe nonce and state rolled back"
        );
        vm.roll(at);
        _mdImport(next, r, p);
    }

}
