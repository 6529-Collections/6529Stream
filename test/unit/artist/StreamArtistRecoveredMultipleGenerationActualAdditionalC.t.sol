// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./ArtistRecoveredMultipleGenerationActualFixture.sol";

contract StreamArtistRecoveredMultipleGenerationActualAdditionalCTest is ArtistRecoveredMultipleGenerationActualFixture {
    function testGenerationAggregateWithoutAttestationsStillRechecksArchiveAfterImport() external {
        _multiSource(true, false);
        _mgCorrect(1);
        Successor memory next = _multiCutover();
        (RH.Request memory r, Commit.Prepared memory prepared) = _mgPrepare(next);
        (RH.ExportHeader memory header, Payload.Payload memory payload) =
            Payload.decode(prepared.data[4].typedState, 4);
        require(
            (header.requiredFeatures & RH.ATTESTATIONS) == 0
                && (header.requiredFeatures & XF.MULTIPLE_GENERATIONS) != 0,
            "closed generation profile without op24"
        );
        Routing.requireCurrent(
            prepared.admission.provenance, prepared.query, prepared.data[4].typedState
        );
        (M.State memory scope, bytes memory raw) =
            ConsentCodec.decodeAuxiliary(4, payload.semanticState, payload.provenance);
        G.Inventory memory inventory = abi.decode(raw, (G.Inventory));
        ++inventory.catalogues[0].upper[0];
        payload.semanticState =
            ConsentCodec.encode(4, scope, payload.provenance, abi.encode(inventory));
        header.semanticInventory = keccak256(payload.semanticState);
        (bool ok, bytes memory reason) = address(Routing)
            .staticcall(
                abi.encodeWithSelector(
                    Routing.requireCurrent.selector,
                    prepared.admission.provenance,
                    prepared.query,
                    Payload.encode(4, header, payload)
                )
            );
        require(
            !ok
                && keccak256(reason)
                    == keccak256(
                        abi.encodeWithSelector(RH.InvalidRecoveredHydrationProfile.selector)
                    ),
            "actual post-import router cannot skip new profile without op24"
        );
        Routing.requireCurrent(
            prepared.admission.provenance, prepared.query, prepared.data[4].typedState
        );
        _mgImport(next, r, prepared, true);
    }

    /// @dev Actual original52/owner/Archive/Safe writes; the inherited Core/governance and
    /// Metadata boundaries remain explicit. This is not a full current-Core integration case.
    function testGenerationAggregateRatificationRetainsOriginalHeadsSignaturesAndArchive()
        external
    {
        _mgSource(true);
        bytes[] memory saved = new bytes[](3);
        saved[0] = _mgRatificationWrite(1, 5201, false);
        saved[1] = _mgRatificationWrite(2, 5202, true);
        saved[2] = _mgRatificationWrite(1, 5203, false);
        require(
            ingress.delegationRecord(mcGrants[0]).uses == 7
                && ingress.delegationRecord(mcGrants[1]).uses == 4,
            "original52 never consumes a delegation grant"
        );
        Successor memory next = _multiCutover();
        (RH.Request memory r, Commit.Prepared memory p) = _mgPrepare(next);
        _mgRatificationHeaders(p);
        bytes32 source = _mgRatificationSourceCut(saved);
        _mgImport(next, r, p, true);
        _mgRatificationAssert(next.coordinator.suiteConfiguration(), saved);
        require(_mgRatificationSourceCut(saved) == source, "original source and Archive unchanged");
    }

    function testGenerationAggregateRatificationLateArchiveRollsBackThenSameSafeRetries() external {
        _mgSource(false);
        bytes[] memory saved = new bytes[](2);
        saved[0] = _mgRatificationWrite(1, 5211, true);
        saved[1] = _mgRatificationWrite(2, 5212, false);
        Successor memory next = _multiCutover();
        (RH.Request memory r, Commit.Prepared memory p) = _mgPrepare(next);
        _mgRatificationHeaders(p);
        bytes32 source = _mgRatificationSourceCut(saved);
        bytes32 before_ = keccak256(
            abi.encode(
                _mgHash(next), _mgRatificationState(next.coordinator.suiteConfiguration(), saved)
            )
        );
        uint256 nonce = rotationSafe.nonce();
        uint256 height = block.number;
        bytes memory data = abi.encodeCall(
            ConsentHydration.hydrateRecoveredArtistAuthorityWithConsents, (r, mgRoyalties)
        );
        vm.roll(uint256(type(uint64).max) + 1);
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamArtistArchiveV2.ArtistArchiveBlockNumberOverflow.selector,
                uint256(type(uint64).max) + 1
            )
        );
        ConsentHydration(address(next.registry))
            .hydrateRecoveredArtistAuthorityWithConsents(r, mgRoyalties);
        require(
            keccak256(
                abi.encode(
                    _mgHash(next),
                    _mgRatificationState(next.coordinator.suiteConfiguration(), saved)
                )
            ) == before_,
            "direct late Archive failure rolls back every52 map and original nonce"
        );
        vm.expectRevert(bytes("GS013"));
        this.rhExecuteNewSafe(address(next.registry), data);
        require(
            rotationSafe.nonce() == nonce
                && keccak256(
                    abi.encode(
                        _mgHash(next),
                        _mgRatificationState(next.coordinator.suiteConfiguration(), saved)
                    )
                ) == before_,
            "same Safe nonce and complete seven-owner rollback"
        );
        vm.roll(height);
        require(
            keccak256(data)
                == keccak256(
                    abi.encodeCall(
                        ConsentHydration.hydrateRecoveredArtistAuthorityWithConsents,
                        (r, mgRoyalties)
                    )
                ),
            "identical restored operation60 input"
        );
        _mgImport(next, r, p, true);
        require(rotationSafe.nonce() == nonce + 1, "only successful retry consumes Safe nonce");
        _mgRatificationAssert(next.coordinator.suiteConfiguration(), saved);
        require(
            _mgRatificationSourceCut(saved) == source,
            "failed and successful imports preserve source"
        );
    }

}
