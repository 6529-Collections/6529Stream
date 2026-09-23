// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./ArtistRecoveredMultipleDisputeFixture.sol";
import {
    StreamArtistRecoveredMultipleGenerationTypes as G
} from "../../../smart-contracts/domains/artist/StreamArtistRecoveredMultipleGenerationTypes.sol";
import {
    StreamArtistRecoveredHistoryRecordRouting as Routing
} from "../../../smart-contracts/domains/artist/StreamArtistRecoveredHistoryRecordRouting.sol";
import {
    StreamArtistRecoveredMultipleDisputeConservation as DisputeConservation
} from "../../../smart-contracts/domains/artist/StreamArtistRecoveredMultipleDisputeConservation.sol";
import {
    StreamArtistRecoveredMultipleDisputeCurrent as DisputeCurrent
} from "../../../smart-contracts/domains/artist/StreamArtistRecoveredMultipleDisputeCurrent.sol";

/// @notice Authored actual-owner/Safe aggregate regressions; native execution remains separate.
abstract contract ArtistRecoveredMultipleDisputeActualFixture is ArtistRecoveredMultipleDisputeFixture {
    function _finish() internal {
        Successor memory next = _multiCutover();
        (RH.Request memory r, Commit.Prepared memory p) = _mdPrepare(next);
        _mdImport(next, r, p);
    }

    function _openPair() internal {
        _mdSource(false);
        _mdSigned(1, 1, keccak256("first opening"), false);
        _mdSelect(2);
        _mdSigned(2, 1, keccak256("second opening"), true);
    }

    function _governedOpen(uint256 collection) internal {
        T.Binding memory b = Binding(suite.owners[0]).binding(collection);
        bytes32 parent = ingress.attributionDispute(collection, b.generation).disputeRecordHash;
        bytes32 evidence =
            _mdEvidence(collection, parent, keccak256(abi.encode("reopen", ++actionNonce)));
        AD.Filing memory filing = AD.Filing(collection, b.generation, 1, evidence, evidence);
        AD.Standing memory noStanding;
        T.Authorization memory noAuthorization;
        bytes32 action = _govern(
            abi.encodeCall(Disputes.openAttributionDispute, (filing, noStanding, noAuthorization)),
            ingress.attributionDisputeOpeningContext(filing),
            evidence,
            2
        );
        _rhCandidate(
            4,
            "attribution_lifecycle.replay.dispute_key",
            keccak256(
                abi.encode(
                    collection, b.generation, bytes32(0), address(artist), evidence, evidence
                )
            )
        );
        _rhCandidate(4, "attribution_lifecycle.replay.governance_action", action);
    }

    function _crossFamilies() internal {
        _mdSource(true);
        bytes32 grant = _mcGrant(9);
        _mdFamilies(grant); // 14/15/16/20: five original uses, plus direct17/21.
        bytes32 credential = _maCredential(1, 0, grant, 4, false);
        _mdDelegated(1, 1, grant, 5);
        _maCredential(2, credential, grant, 6, false);
        _mdSigned(1, 3, keccak256("signed original counter"), true);
        _mdDelegated(1, 2, grant, 7);
        require(
            ingress.delegationRecord(grant).uses == 9, "all original consent plus24 plus44/61 uses"
        );
        _mcRevoke(grant);
        _mcGrant(0);
    }

    function _assertOriginalSourceRemainsSealed() internal {
        // Prepare a real counterstatement against A's still-open original episode.
        // Do not clear its observed cutover or impersonate its fixed Coordinator.
        T.Binding memory b = Binding(suite.owners[0]).binding(2);
        AD.Head memory head = ingress.attributionDispute(2, b.generation);
        require(head.open, "original A episode remains open after B hydration");
        bytes32 evidence = _mdEvidence(2, head.disputeRecordHash, keccak256("sealed A counter"));
        AD.Filing memory filing = AD.Filing(2, b.generation, 3, evidence, evidence);
        AD.Standing memory standing = AD.Standing(artistId, b.generation, 0, 0);
        T.Authorization memory authorization =
            T.Authorization(Identity(suite.owners[2]).identity(artistId).nonceHint, 0, "");
        bytes memory data =
            abi.encodeCall(Disputes.recordCounterStatement, (filing, standing, authorization));
        T.Snapshot[7] memory before_;
        uint256[7] memory nativeCounts;
        for (uint8 i; i < 7; ++i) {
            before_[i] = OriginalOwner(suite.owners[i]).ownerStateSnapshotV2();
            nativeCounts[i] = Native(suite.owners[i]).artistNativeReceiptCount();
        }
        uint256 archived = archive.storedPayloadCount();
        uint256 safeNonce = rotationSafe.nonce();
        vm.expectRevert(abi.encodeWithSelector(T.InvalidBinding.selector));
        Disputes(address(ingress)).recordCounterStatement(filing, standing, authorization);
        vm.expectRevert(bytes("GS013"));
        this.rhExecuteNewSafe(address(ingress), data);
        require(
            archive.storedPayloadCount() == archived && rotationSafe.nonce() == safeNonce,
            "sealed source rejects before Archive append and Safe nonce consumption"
        );
        for (uint8 i; i < 7; ++i) {
            require(
                keccak256(abi.encode(OriginalOwner(suite.owners[i]).ownerStateSnapshotV2()))
                        == keccak256(abi.encode(before_[i]))
                    && Native(suite.owners[i]).artistNativeReceiptCount() == nativeCounts[i],
                "all original source snapshots and native receipts unchanged"
            );
        }
    }
}
