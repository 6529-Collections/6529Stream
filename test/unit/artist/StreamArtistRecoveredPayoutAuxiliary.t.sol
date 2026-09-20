// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    StreamArtistRecoveredPayoutTransport as Transport
} from "../../../smart-contracts/domains/artist/StreamArtistRecoveredPayoutTransport.sol";
import {
    StreamArtistRecoveredHydrationState as Imported
} from "../../../smart-contracts/domains/artist/StreamArtistRecoveredHydrationState.sol";
import {
    StreamArtistPayoutRecoveryState as State
} from "../../../smart-contracts/domains/artist/StreamArtistPayoutRecoveryState.sol";
import {
    StreamArtistRecoveredRuntimeReads as Runtime
} from "../../../smart-contracts/domains/artist/StreamArtistRecoveredRuntimeReads.sol";
import {
    StreamArtistRecoveredHydrationTypes as RH
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistRecoveredHydrationTypes.sol";
import {
    StreamArtistRecoveryRewindTypes as W
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistRecoveryRewindTypes.sol";
import {
    StreamArtistOnboardingTypes as T
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistOnboardingTypes.sol";
import {
    IStreamArtistAuthorityCheckpoint as CP
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistAuthorityCheckpoint.sol";

/// @dev Deliberately synthetic typed storage boundary; no Payout35 or Coordinator admission.
contract RecoveredPayoutAuxiliaryHarness {
    State.State private recovery;

    function install(RH.OwnerProvenance memory prefix) external {
        Imported.installOwnerPrefix(prefix, 5, keccak256("synthetic import"), 1);
    }

    function write(W.PayoutContinuationV3 memory c) external {
        recovery.continuations[c.continuationHash] = c;
    }

    function retain(bytes32 key, RH.Point memory point) external {
        Imported.installArtifact(Transport.CONTINUATION, key, point);
    }

    function point(bytes32 key, RH.OriginEnvironment memory current)
        external
        view
        returns (RH.Point memory)
    {
        return Transport.auxiliaryPoint(recovery, Transport.CONTINUATION, key, current);
    }
}

/// @notice Missing auxiliary metadata must not relabel old high revisions as new local writes.
/// @dev Original-domain hashes are real; record admission and clock certificates are synthetic.
contract StreamArtistRecoveredPayoutAuxiliaryTest {
    RecoveredPayoutAuxiliaryHarness private host;
    RH.OriginEnvironment private old;
    RH.OriginEnvironment private current;

    function setUp() public {
        host = new RecoveredPayoutAuxiliaryHarness();
        old = _environment(100);
        current = _environment(200);
        current.owners[5] = address(host);
        RH.OwnerProvenance memory prefix;
        prefix.origins = new RH.OriginEnvironment[](1);
        prefix.origins[0] = old;
        prefix.eras = new RH.OwnerEra[](1);
        prefix.eras[0] = RH.OwnerEra(
            RH.originHash(old),
            CP.Checkpoint(
                RH.CHECKPOINT,
                T.Snapshot(RH.ownerDomain(5), 200, bytes32(uint256(1)), bytes32(uint256(2))),
                0,
                0,
                0,
                0
            ),
            0,
            0,
            0
        );
        host.install(prefix);
    }

    function testOldHighRevisionWithoutSavedOriginCannotBecomeCurrent() public {
        W.PayoutContinuationV3 memory c = _continuation(old, 100);
        host.write(c);
        (bool ok,) =
            address(host).staticcall(abi.encodeCall(host.point, (c.continuationHash, current)));
        require(!ok, "old raw100 above import1 is not current-domain proof");
    }

    function testRetainedOldHighRevisionKeepsItsOriginalPoint() public {
        W.PayoutContinuationV3 memory c = _continuation(old, 100);
        host.write(c);
        RH.Point memory expected = RH.Point(RH.originHash(old), 5, 100);
        host.retain(c.continuationHash, expected);
        require(
            keccak256(abi.encode(host.point(c.continuationHash, current)))
                == keccak256(abi.encode(expected)),
            "saved original point"
        );
    }

    function testNewCurrentDomainContinuationHasPositiveLocalProof() public {
        W.PayoutContinuationV3 memory c = _continuation(current, 2);
        host.write(c);
        RH.Point memory point = host.point(c.continuationHash, current);
        require(
            point.environmentHash == RH.originHash(current) && point.ownerRevision == 2
                && point.ownerIndex == 5,
            "genuine current hash"
        );
    }

    function testNewCurrentHashStillCannotPrecedeImportBoundary() public {
        W.PayoutContinuationV3 memory c = _continuation(current, 1);
        host.write(c);
        (bool ok,) =
            address(host).staticcall(abi.encodeCall(host.point, (c.continuationHash, current)));
        require(!ok, "import revision cannot be a new continuation");
    }

    function testAlteredCurrentEnvironmentCannotAuthenticateLocalContinuation() public {
        W.PayoutContinuationV3 memory c = _continuation(current, 100);
        host.write(c);
        RH.OriginEnvironment memory wrong = current;
        wrong.registry = address(9999);
        (bool ok,) =
            address(host).staticcall(abi.encodeCall(host.point, (c.continuationHash, wrong)));
        require(!ok, "no relabeled current environment");
    }

    function _continuation(RH.OriginEnvironment memory environment, uint64 revision)
        private
        pure
        returns (W.PayoutContinuationV3 memory c)
    {
        c.artistId = keccak256("artist");
        c.recoveryRecordHash = keccak256("original recovery");
        c.actionId = keccak256("original action");
        c.manifestHash = keccak256("original manifest");
        c.planCommitment = keccak256("original plan");
        c.identityOwnerRevision = 88;
        c.payoutOwnerRevision = revision;
        c.continuationHash = W.payoutContinuationHash(Runtime.rewindEnvironment(environment), c);
    }

    function _environment(uint160 base) private view returns (RH.OriginEnvironment memory e) {
        e.chainId = block.chainid;
        e.registry = address(base);
        e.coordinator = address(base + 1);
        e.archive = address(base + 2);
        e.core = address(10);
        e.manager = address(11);
        e.suiteConfigurationHash = keccak256(abi.encode(base));
        for (uint8 i; i < 7; ++i) {
            e.owners[i] = address(base + 10 + i);
            e.ownerCodeHashes[i] = keccak256(abi.encode(base, i));
        }
    }
}
