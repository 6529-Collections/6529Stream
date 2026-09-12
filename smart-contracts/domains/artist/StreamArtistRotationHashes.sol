// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./StreamArtistHashes.sol";
import {
    StreamArtistOnboardingTypes as T
} from "../../interfaces/stream/artist/StreamArtistOnboardingTypes.sol";
import {
    StreamArtistRotationTypes as R
} from "../../interfaces/stream/artist/StreamArtistRotationTypes.sol";

/// @notice Permanent guardian/rotation/standing schemas; supplemental concurrency fields are excluded.
library StreamArtistRotationHashes {
    function guardianDigest(
        StreamArtistHashes.Environment memory e,
        R.GuardianSet memory p,
        T.Authorization memory a
    ) public pure returns (bytes32) {
        return StreamArtistHashes.typed(
            e,
            keccak256(
                abi.encode(
                    keccak256(
                        "StreamArtistGuardianSet(bytes32 artistId,address[] guardians,uint32 approvalThreshold,uint64 minContestSeconds,uint256 nonce,uint64 signedAt)"
                    ),
                    p.artistId,
                    keccak256(abi.encodePacked(p.guardians)),
                    p.approvalThreshold,
                    p.minContestSeconds,
                    a.nonce,
                    a.time
                )
            )
        );
    }

    function rotationDigest(
        StreamArtistHashes.Environment memory e,
        R.Rotation memory p,
        T.Authorization memory a
    ) public pure returns (bytes32) {
        return StreamArtistHashes.typed(
            e,
            keccak256(
                abi.encode(
                    bytes32(0x5b4e68760703787cefafa5c70864d397b1de70e70818739680256a123fe7a184),
                    p.artistId,
                    p.oldAddress,
                    p.newAddress,
                    p.reasonHash,
                    a.nonce,
                    a.time
                )
            )
        );
    }

    function acceptanceDigest(
        StreamArtistHashes.Environment memory e,
        R.Rotation memory p,
        T.Authorization memory a
    ) public pure returns (bytes32) {
        return StreamArtistHashes.typed(
            e,
            keccak256(
                abi.encode(
                    bytes32(0x87eea3b0d5e1275bbdc74e691b4e19a12e9e76b634bac03ae439ae584859ecd0),
                    p.artistId,
                    p.oldAddress,
                    p.newAddress,
                    a.nonce,
                    a.time
                )
            )
        );
    }

    function standingDigest(
        StreamArtistHashes.Environment memory e,
        R.StandingRevocation memory p,
        T.Authorization memory a
    ) public pure returns (bytes32) {
        return StreamArtistHashes.typed(
            e,
            keccak256(
                abi.encode(
                    bytes32(0xc3782eba55027b9bef1f60b09cfbcfa48bbd834194f743ae92029711ae18f936),
                    p.artistId,
                    p.revokedAddress,
                    p.reasonHash,
                    a.nonce,
                    a.time
                )
            )
        );
    }

    function guardianRecord(
        StreamArtistHashes.Environment memory e,
        R.GuardianSet memory p,
        T.Authorization memory a
    ) public pure returns (bytes32) {
        return keccak256(
            abi.encode(
                bytes32(0xfb979fce9edd361cf23ba8baee900f7054451db7b563ba0ab11a5ef3621cd297),
                e.chainId,
                e.registry,
                p.artistId,
                p.guardians,
                p.approvalThreshold,
                p.minContestSeconds,
                a.nonce,
                a.time
            )
        );
    }

    function rotationRecord(
        StreamArtistHashes.Environment memory e,
        R.Rotation memory p,
        uint256 nonce,
        uint64 stagedAt,
        uint64 contestEndsAt
    ) public pure returns (bytes32) {
        return keccak256(
            abi.encode(
                bytes32(0x8d7c32ae357c27253fd4480fe9d411cefc64a5634952ed8c8ebe7dcf63257ea5),
                e.chainId,
                e.registry,
                p.artistId,
                p.oldAddress,
                p.newAddress,
                p.reasonHash,
                nonce,
                stagedAt,
                contestEndsAt
            )
        );
    }

    function standingRecord(
        StreamArtistHashes.Environment memory e,
        R.StandingRevocation memory p,
        address signer,
        uint256 nonce,
        uint64 signedAt
    ) public pure returns (bytes32) {
        return keccak256(
            abi.encode(
                bytes32(0xc62769083037c111cec5a5f8d100e5c4064db79bec694312e35e53acc7256d0e),
                e.chainId,
                e.registry,
                p.artistId,
                p.revokedAddress,
                p.retiredTransitionRecordHash,
                signer,
                uint8(1),
                p.reasonHash,
                nonce,
                signedAt
            )
        );
    }

    function standingRecordForAuthority(
        StreamArtistHashes.Environment memory e,
        R.StandingRevocation memory p,
        address signer,
        uint8 authorityClass,
        uint256 nonce,
        uint64 signedAt
    ) public pure returns (bytes32) {
        return keccak256(
            abi.encode(
                bytes32(0xc62769083037c111cec5a5f8d100e5c4064db79bec694312e35e53acc7256d0e),
                e.chainId,
                e.registry,
                p.artistId,
                p.revokedAddress,
                p.retiredTransitionRecordHash,
                signer,
                authorityClass,
                p.reasonHash,
                nonce,
                signedAt
            )
        );
    }
}
