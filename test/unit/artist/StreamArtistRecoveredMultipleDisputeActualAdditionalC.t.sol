// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./ArtistRecoveredMultipleDisputeActualFixture.sol";

contract StreamArtistRecoveredMultipleDisputeActualAdditionalCTest is ArtistRecoveredMultipleDisputeActualFixture {
    function testAggregateFinalArchiveCutoffRecheckWithoutAttestations() external {
        _openPair();
        Successor memory next = _multiCutover();
        (RH.Request memory r, Commit.Prepared memory p) = _mdPrepare(next);
        DisputeCurrent.requireCurrent(p.admission.provenance, p.query, p.data[4].typedState);
        (RH.ExportHeader memory header, Payload.Payload memory payload) =
            Payload.decode(p.data[4].typedState, 4);
        require((header.requiredFeatures & RH.ATTESTATIONS) == 0, "no op24 branch");
        (M.State memory scope, bytes memory raw) =
            ConsentCodec.decodeAuxiliary(4, payload.semanticState, payload.provenance);
        G.Inventory memory inventory = abi.decode(raw, (G.Inventory));
        ++inventory.catalogues[0].upper[0];
        payload.semanticState =
            ConsentCodec.encode(4, scope, payload.provenance, abi.encode(inventory));
        header.semanticInventory = keccak256(payload.semanticState);
        (bool ok,) = address(Routing)
            .staticcall(
                abi.encodeWithSelector(
                    Routing.requireCurrent.selector,
                    p.admission.provenance,
                    p.query,
                    Payload.encode(4, header, payload)
                )
            );
        require(!ok, "actual post-import route rejects unrelated owner cutoff drift");
        _mdImport(next, r, p);
    }

    function testAggregateRepeatedImportRetainsOriginalPositionsAndFreshSuccessorHistory()
        external
    {
        _openPair();
        Successor memory middle = _multiCutover();
        (RH.Request memory firstRequest, Commit.Prepared memory first) = _mdPrepare(middle);
        _mdImport(middle, firstRequest, first);
        bytes32 firstValue = HydrationOwner(middle.identity).authorityHydrationCommitment();
        _assertOriginalSourceRemainsSealed();
        _rhAdopt(middle);
        _mdSelect(1);
        bytes32 withdrawal = _mdSigned(1, 2, keccak256("successor original61"), true);
        _mdSelect(2);
        _mdResolve(2, 1, 1);
        Successor memory last = _multiCutover();
        (RH.Request memory secondRequest, Commit.Prepared memory second) = _mdPrepare(last);
        require(
            secondRequest.expectedSourceImportCommitment == firstValue
                && second.admission.provenance.eras.length == 2,
            "real imported prefix and fresh era"
        );
        RH.JournalEntry[] memory before_ = first.admission.provenance.journals[4];
        RH.JournalEntry[] memory after_ = second.admission.provenance.journals[4];
        require(after_.length == before_.length + 1, "only fresh signed61 adds a native record");
        for (uint256 i; i < before_.length; ++i) {
            require(
                keccak256(abi.encode(before_[i])) == keccak256(abi.encode(after_[i])),
                "original occurrence index, point and receipt preserved"
            );
        }
        require(
            after_[before_.length].receipt.recordHash == withdrawal
                && after_[before_.length].position.nativeIndex == 0
                && after_[before_.length].position.point.environmentHash
                    == second.admission.provenance.eras[1].originHash,
            "fresh successor receipt keeps its own original domain and index"
        );
        _mdImport(last, secondRequest, second);
    }

}
