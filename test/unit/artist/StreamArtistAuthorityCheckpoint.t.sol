// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "./ArtistOnboardingFixture.sol";
import {
    IStreamArtistAuthorityCheckpoint as CP
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistAuthorityCheckpoint.sol";

/// @notice Actual Artist/Safe/owner inventories; typed unit Core/governance, no import authority yet.
contract StreamArtistAuthorityCheckpointTest is ArtistOnboardingFixture {
    function _cp(uint256 owner) internal view returns (CP) {
        return CP(suite.owners[owner]);
    }

    function _allReplayCells(uint256 owner) internal view {
        CP host = _cp(owner);
        CP.Checkpoint memory c = host.authorityCheckpoint();
        require(
            c.schema == keccak256("6529STREAM_ARTIST_GUARD_CHECKPOINT_V1"),
            "actual constructor schema"
        );
        for (uint256 i; i < c.replayCount; ++i) {
            (bytes32 key, T.ReplayCell memory cell) = host.authorityReplayAt(i);
            require(
                key != 0 && cell.status != 0
                    && keccak256(abi.encode(cell))
                        == keccak256(
                            abi.encode(IStreamArtistOwner(suite.owners[owner]).replayCell(key))
                        ),
                "actual fixed-owner cell"
            );
            for (uint256 j; j < i; ++j) {
                (bytes32 prior,) = host.authorityReplayAt(j);
                require(prior != key, "unique complete key inventory");
            }
        }
    }

    function _index(uint8 kind, bytes32 key) internal view returns (CP.NonceIndex memory found) {
        CP host = _cp(2);
        CP.Checkpoint memory c = host.authorityCheckpoint();
        for (uint256 i; i < c.nonceIndexCount; ++i) {
            CP.NonceIndex memory n = host.authorityNonceIndexAt(i);
            if (n.kind == kind && n.key == key) return n;
        }
        revert("missing original typed nonce index");
    }

    function _contains(uint8 kind, bytes32 key, uint256 nonce) internal view returns (bool) {
        CP.NonceIndex memory n = _index(kind, key);
        for (uint256 i; i < n.prefixCount; ++i) {
            (uint256 prefix, uint256[32] memory words, bool exhausted) =
                _cp(2).authorityNonceWordAt(kind, key, i);
            require(!exhausted, "finite fixture namespace");
            if (prefix == nonce >> 8) return (words[0] & (uint256(1) << (nonce & 255))) != 0;
        }
        return false;
    }

    function testCheckpointIncludesSparseConsumedAndRevokedNoncesAndExactDigestGuard() external {
        uint256 acceptanceNonce = nextNonce;
        _accept();
        uint256 revocationNonce = nextNonce;
        _cancelAuthorization(
            StreamArtistAuthorizationTypes.Revocation(artistId, 0, type(uint256).max)
        );
        T.PolicyConsent memory p = T.PolicyConsent(1, PHASE, POLICY);
        T.Authorization memory a = T.Authorization(777, 2000, "");
        bytes32 digest = ingress.policyConsentDigest(p, a);
        a.signature = _signature(digest);
        _cancelAuthorization(StreamArtistAuthorizationTypes.Revocation(artistId, digest, 0));
        CP.NonceIndex memory n = _index(1, artistId);
        require(
            n.prefixCount == 2 && _contains(1, artistId, acceptanceNonce)
                && _contains(1, artistId, revocationNonce)
                && _contains(1, artistId, type(uint256).max) && !_contains(1, artistId, 777),
            "arbitrary uint256 prefixes, no fabricated consumed target"
        );
        StreamArtistAuthorizationTypes.State memory status =
            ingress.artistAuthorizationState(artistId, digest, 777);
        require(status.digestRevoked && !status.nonceConsumed, "original independent digest denial");
        bytes32 before_ = keccak256(abi.encode(_cp(2).authorityCheckpoint()));
        avm.expectPartialRevert(T.Replay.selector);
        ingress.recordPolicyConsent(p, a);
        require(
            keccak256(abi.encode(_cp(2).authorityCheckpoint())) == before_,
            "denied write adds no inventory"
        );
        for (uint256 owner; owner < 7; ++owner) {
            _allReplayCells(owner);
        }
    }

    function testCheckpointRetainsMutablePayoutReplayHeadAtOneInventoryPosition() external {
        _payout();
        CP host = _cp(5);
        CP.Checkpoint memory before_ = host.authorityCheckpoint();
        require(before_.replayCount == 1, "one actual payout chain key");
        (bytes32 key, T.ReplayCell memory first) = host.authorityReplayAt(0);
        bytes32 next = _dismissalPayout(address(0xD001));
        CP.Checkpoint memory after_ = host.authorityCheckpoint();
        (bytes32 same, T.ReplayCell memory last) = host.authorityReplayAt(0);
        require(
            same == key && after_.replayCount == 1 && after_.replayRoot != before_.replayRoot
                && last.commitment == next && last.commitment != first.commitment && last.kind == 3
                && last.status == 1,
            "latest real chain cell, same stable inventory index"
        );
        _allReplayCells(5);
    }

    function testCheckpointSeparatesDelegateAndRotationAcceptanceNonceTrees() external {
        _accept();
        _payout();
        _delegateSetup();
        bytes32 grant = _grant(_delegation(1, 4, 1000, 2000, 3));
        T.EconomicsConsent memory p = _currentEconomics(address(primary));
        T.Authorization memory a = T.Authorization(256, 2000, "");
        a.signature = _delegateSignature(ingress.economicsConsentDigest(p, a));
        ingress.recordDelegatedEconomicsConsent(p, grant, a);
        bytes32 lane = keccak256(
            abi.encode(
                keccak256("6529STREAM_ARTIST_DELEGATE_NONCE_LANE_V1"),
                artistId,
                address(delegateSafe)
            )
        );
        require(
            _contains(2, lane, 256) && !_contains(1, artistId, 256)
                && ingress.delegationRecord(grant).uses == 1,
            "separate original delegate lane and use"
        );
        _newRotationSafe(21101);
        R.Rotation memory rotation = _rotationTerms(0);
        (T.Authorization memory oldA, T.Authorization memory newA) =
            _rotationAuthorizations(rotation);
        ingress.rotateArtistAddress(rotation, oldA, newA);
        CP.Checkpoint memory header = _cp(2).authorityCheckpoint();
        bool found;
        for (uint256 i; i < header.nonceIndexCount; ++i) {
            CP.NonceIndex memory n = _cp(2).authorityNonceIndexAt(i);
            if (n.kind == 4) {
                require(_contains(4, n.key, newA.nonce), "original two-sided acceptance nonce");
                found = true;
            }
        }
        require(found, "typed rotation tree present");
        _allReplayCells(2);
    }

    function testCheckpointLateArchiveRollbackPreservesInventoriesAndIdenticalSafeRetry() external {
        StreamArtistAuthorizationTypes.Revocation memory p =
            StreamArtistAuthorizationTypes.Revocation(artistId, 0, 65537);
        T.Authorization memory a = _authorization(false);
        bytes memory data =
            abi.encodeCall(IStreamArtistAuthorizationRevocation.revokeArtistAuthorization, (p, a));
        bytes32 before_ = keccak256(abi.encode(_cp(2).authorityCheckpoint()));
        bytes32 roots = _roots();
        uint256 nonce = artist.nonce();
        avm.mockCallRevert(
            address(archive),
            abi.encodeWithSelector(IStreamArtistArchiveV2.appendArtistEvidenceV2.selector),
            abi.encodeWithSignature("Error(string)", "checkpoint archive failure")
        );
        vm.expectRevert(bytes("GS013"));
        this.executeTargetSafe(address(ingress), data);
        require(
            keccak256(abi.encode(_cp(2).authorityCheckpoint())) == before_ && _roots() == roots
                && artist.nonce() == nonce,
            "all auxiliary and original state rolls back"
        );
        avm.clearMockedCalls();
        require(this.executeTargetSafe(address(ingress), data), "identical actual Safe retry");
        require(
            _contains(1, artistId, 65537) && _contains(1, artistId, a.nonce)
                && artist.nonce() == nonce + 1,
            "one successful authority transition indexed"
        );
        _allReplayCells(2);
    }
}
