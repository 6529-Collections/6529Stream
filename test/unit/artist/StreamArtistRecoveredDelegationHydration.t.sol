// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    StreamArtistRecoveredDelegationHydration as Checked
} from "../../../smart-contracts/domains/artist/StreamArtistRecoveredDelegationHydration.sol";
import {
    StreamArtistDelegationState as Delegations
} from "../../../smart-contracts/domains/artist/StreamArtistDelegationState.sol";
import {
    StreamArtistHashes as Hashes
} from "../../../smart-contracts/domains/artist/StreamArtistHashes.sol";
import {
    StreamArtistRecoveredIdentityHydrationTypes as IH
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistRecoveredIdentityHydrationTypes.sol";
import {
    StreamArtistRecoveredHydrationTypes as RH
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistRecoveredHydrationTypes.sol";
import {
    StreamArtistDelegationTypes as D
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistDelegationTypes.sol";
import {
    StreamArtistOnboardingTypes as T
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistOnboardingTypes.sol";
import {
    StreamArtistHistoryTypes as H
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistHistory.sol";
import {
    StreamArtistAuthorityHydrationTypes as AH
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistAuthorityHydration.sol";

contract RecoveredDelegationValidationHarness {
    function validate(IH.Bundle memory b, RH.OwnerProvenance memory p) external pure {
        Checked.validate(b, p);
    }
}

/// @notice Pure component controls using explicitly synthetic original-owner certificates.
/// @dev This host tests the delegation leaf after the enclosing fixed-source provenance boundary.
/// It does not claim actual grants, revocations, Safe signatures or operation60 admission. The
/// actual recovered-delegation host exercises the raw exporter and its corrected tagged lane.
contract StreamArtistRecoveredDelegationHydrationTest {
    bytes32 private constant ARTIST = keccak256("component artist");
    address private constant DELEGATE = address(0xD001);

    struct Fixture {
        IH.Bundle b;
        RH.OwnerProvenance p;
        RecoveredDelegationValidationHarness target;
    }

    function testDelegationComponentOriginalDomainsAndCrossEraOrder() external {
        Fixture memory f = _fixture();
        _valid(f);
        require(
            f.b.delegations[0].position.point.ownerRevision
                > f.b.delegations[1].position.point.ownerRevision,
            "old80 precedes current2 by original era, never raw revision"
        );
        f.b.identity.authorityAddress = address(0x9999);
        f.b.identity.authorityClass = 3;
        _valid(f);
    }

    function testDelegationComponentRejectsChangedGrantBodyAndRebasedDomain() external {
        Fixture memory f = _fixture();
        _valid(f);
        f.b.delegations[0].record.grant.constraintsHash = keccak256("different grant");
        _reject(f);
        f = _fixture();
        _valid(f);
        // Preserve the earlier grant/revocation ordering, but attribute B's retained hash to A.
        f.b.delegations[1].position.point.environmentHash = f.p.eras[0].originHash;
        f.b.delegations[1].position.point.ownerRevision = 82;
        f.p.journal[2].position = f.b.delegations[1].position;
        _reject(f);
    }

    function testDelegationComponentRequiresFinalCurrentGrantForEveryVersion() external {
        Fixture memory f = _fixture();
        _valid(f);
        f.b.delegations[0].current = f.b.delegations[0].recordHash;
        _reject(f);
        f.b.delegations[0].current = f.b.delegations[1].recordHash;
        _valid(f);
        f.b.delegations[1].current = 0;
        _reject(f);
    }

    function testDelegationComponentRejectsOmittedOrDuplicatedRevocation() external {
        Fixture memory f = _fixture();
        _valid(f);
        RH.JournalEntry[] memory omitted = new RH.JournalEntry[](2);
        omitted[0] = f.p.journal[0];
        omitted[1] = f.p.journal[2];
        f.p.journal = omitted;
        _reject(f);
        f = _fixture();
        _valid(f);
        RH.JournalEntry[] memory duplicated = new RH.JournalEntry[](4);
        for (uint256 i; i < 3; ++i) {
            duplicated[i] = f.p.journal[i];
        }
        duplicated[3] = f.p.journal[1];
        f.p.journal = duplicated;
        _reject(f);
    }

    function testDelegationComponentRejectsEarlyOrSharedRevocation() external {
        Fixture memory f = _fixture();
        _valid(f);
        f.p.journal[1].position.point.ownerRevision = 79;
        _reject(f);
        f = _fixture();
        _valid(f);
        f.b.delegations[1].record.revoked = true;
        f.b.delegations[1].record.revocationRecordHash =
        f.b.delegations[0].record.revocationRecordHash;
        _reject(f);
    }

    function testDelegationComponentRejectsEpochAboveHeadOrBackward() external {
        Fixture memory f = _fixture();
        _valid(f);
        f.b.delegations[1].epoch = f.b.heads.delegationEpoch + 1;
        _reject(f);
        f = _fixture();
        _valid(f);
        f.b.delegations[0].epoch = 2;
        _reject(f);
        f.b.delegations[0].epoch = 0;
        _valid(f);
    }

    function testDelegationComponentRequiresTaggedDelegateNonceLane() external {
        Fixture memory f = _fixture();
        _valid(f);
        require(
            f.b.nonces[1].key == Delegations.lane(ARTIST, DELEGATE)
                && f.b.nonces[1].key != keccak256(abi.encode(ARTIST, DELEGATE)),
            "actual producer nonce key differs from current-grant mapping key"
        );
        f.b.nonces[1].key = keccak256(abi.encode(ARTIST, DELEGATE));
        _reject(f);
        f.b.nonces[1].key = Delegations.lane(ARTIST, DELEGATE);
        _valid(f);
    }

    function testDelegationComponentRejectsMissingDuplicateAndWrongKindLane() external {
        Fixture memory f = _fixture();
        _valid(f);
        IH.NonceLane[] memory one = new IH.NonceLane[](1);
        one[0] = f.b.nonces[0];
        f.b.nonces = one;
        _reject(f);
        f = _fixture();
        _valid(f);
        f.b.nonces[0] = f.b.nonces[1];
        _reject(f);
        f = _fixture();
        _valid(f);
        f.b.nonces[1].kind = 1;
        _reject(f);
    }

    function testDelegationComponentReconcilesUsedBitsAcrossAllVersions() external {
        Fixture memory f = _fixture();
        _valid(f);
        f.b.nonces[1].words[0].words[0] |= uint256(1) << 9;
        _reject(f);
        f = _fixture();
        _valid(f);
        f.b.nonces[1].words[1].words[0] = 0;
        _reject(f);
        f = _fixture();
        _valid(f);
        f.b.nonces[1].words[1].prefix = f.b.nonces[1].words[0].prefix;
        _reject(f);
        f = _fixture();
        _valid(f);
        f.b.delegations[0].record.uses = 1;
        _reject(f);
    }

    function testDelegationComponentAuthenticatesGrantAndRevocationReplayPoints() external {
        Fixture memory f = _fixture();
        _valid(f);
        f.p.aliases[0].admittedAt.ownerRevision = 81;
        _reject(f);
        f = _fixture();
        _valid(f);
        f.p.aliases[1].cell.commitment = keccak256("different authorization");
        _reject(f);
        f = _fixture();
        _valid(f);
        f.p.aliases[6].cell.status = 1;
        _reject(f);
        f = _fixture();
        _valid(f);
        f.p.aliases[2].surface = keccak256("missing original observed digest");
        _reject(f);
    }

    function testDelegationComponentPreservesExpiredRevokedAndOldEpochFacts() external {
        Fixture memory f = _fixture();
        _valid(f);
        require(
            f.b.delegations[0].record.revoked && f.b.delegations[0].epoch == 0
                && f.b.delegations[1].epoch == 1 && f.b.heads.delegationEpoch == 2,
            "all historical versions survive independently of current epoch"
        );
        f.b.delegations[0].record.revoked = false;
        _reject(f);
        f = _fixture();
        _valid(f);
        f.b.delegations[0].record.uses = 4;
        _reject(f);
    }

    function testDelegationComponentDigestOnly54AddsNoDelegateNonceLane() external {
        Fixture memory f = _fixture();
        _valid(f);
        RH.JournalEntry[] memory journal = new RH.JournalEntry[](4);
        for (uint256 i; i < 3; ++i) {
            journal[i] = f.p.journal[i];
        }
        journal[3] = RH.JournalEntry(
            RH.Position(RH.Point(f.p.eras[1].originHash, 2, 3), 1),
            H.Receipt(54, ARTIST, 0, keccak256("original digest-only54"))
        );
        f.p.journal = journal;
        // Its full principal authorization/replay is checked by the enclosing source. The
        // delegation leaf must not infer another delegate tree or another grant use from54.
        _valid(f);
    }

    function _fixture() private returns (Fixture memory f) {
        f.target = new RecoveredDelegationValidationHarness();
        f.b.artistId = ARTIST;
        f.b.heads.delegationEpoch = 2;
        f.b.delegations = new IH.DelegationRow[](2);
        f.p.origins = new RH.OriginEnvironment[](2);
        f.p.eras = new RH.OwnerEra[](2);
        f.p.journal = new RH.JournalEntry[](3);
        f.p.aliases = new RH.ReplayAlias[](7);
        for (uint256 i; i < 2; ++i) {
            RH.OriginEnvironment memory o;
            o.chainId = 1;
            o.registry = address(uint160(0x100 + i));
            o.core = address(0x200);
            o.manager = address(0x300);
            o.owners[2] = address(uint160(0x400 + i));
            o.ownerCodeHashes[2] = keccak256("synthetic owner runtime");
            f.p.origins[i] = o;
            f.p.eras[i].originHash = RH.originHash(o);
            f.p.eras[i].checkpoint.schema = RH.CHECKPOINT;
            f.p.eras[i].checkpoint.ownerState.domainId = RH.ownerDomain(2);
            f.p.eras[i].checkpoint.ownerState.revision = i == 0 ? 100 : 10;
            f.p.eras[i].checkpoint.nonceIndexCount = 2;
            D.Record memory item;
            item.grant = D.Grant(ARTIST, DELEGATE, 1, 6, 1, 200, 3, bytes32(0));
            item.grantor = address(uint160(0x500 + i));
            item.nonce = 7 + i;
            item.uses = i == 0 ? 2 : 1;
            item.revoked = i == 0;
            if (i == 0) item.revocationRecordHash = keccak256("original27");
            bytes32 record = _grantHash(o, item);
            RH.Position memory position =
                RH.Position(RH.Point(RH.originHash(o), 2, i == 0 ? 80 : 2), 0);
            f.b.delegations[i] = IH.DelegationRow(position, record, item, 0, uint64(i));
            f.p.journal[i == 0 ? 0 : 2] =
                RH.JournalEntry(position, H.Receipt(26, ARTIST, 0, record));
            bytes32 digest = Delegations.grantDigest(
                Hashes.Environment(o.chainId, o.registry, o.core, o.manager), item.grant, item.nonce
            );
            _alias(
                f, i * 3, position.point, "identity_authority.replay.delegation_key", record, record
            );
            _alias(
                f,
                i * 3 + 1,
                position.point,
                "identity_authority.replay.nonce_allocator",
                keccak256(abi.encode(ARTIST, item.nonce)),
                digest
            );
            _alias(
                f,
                i * 3 + 2,
                position.point,
                "identity_authority.replay.authorization_consumed_digest",
                keccak256(abi.encode(ARTIST, digest)),
                digest
            );
        }
        f.b.delegations[0].current = f.b.delegations[1].recordHash;
        f.b.delegations[1].current = f.b.delegations[1].recordHash;
        RH.Point memory revokedAt = RH.Point(f.p.eras[0].originHash, 2, 81);
        bytes32 revoked = f.b.delegations[0].record.revocationRecordHash;
        f.p.journal[1] =
            RH.JournalEntry(RH.Position(revokedAt, 1), H.Receipt(27, ARTIST, 0, revoked));
        _alias(
            f,
            6,
            revokedAt,
            "identity_authority.replay.one_way_delegation_revocation",
            f.b.delegations[0].recordHash,
            revoked
        );
        f.b.nonces = new IH.NonceLane[](2);
        f.b.nonces[0].kind = 1;
        f.b.nonces[0].key = ARTIST;
        f.b.nonces[0].words = new AH.NonceWord[](1);
        f.b.nonces[0].words[0].words[0] = (uint256(1) << 7) | (uint256(1) << 8);
        f.b.nonces[1].kind = 2;
        f.b.nonces[1].key = Delegations.lane(ARTIST, DELEGATE);
        f.b.nonces[1].words = new AH.NonceWord[](2);
        f.b.nonces[1].words[0].words[0] = (uint256(1) << 2) | (uint256(1) << 7);
        f.b.nonces[1].words[1].prefix = 1;
        f.b.nonces[1].words[1].words[0] = uint256(1) << 4;
    }

    function _alias(
        Fixture memory f,
        uint256 index,
        RH.Point memory point,
        string memory surface,
        bytes32 scope,
        bytes32 commitment
    ) private pure {
        f.p.aliases[index] = RH.ReplayAlias(
            point.environmentHash,
            2,
            keccak256(bytes(surface)),
            scope,
            bytes32(0),
            T.ReplayCell(commitment, point.ownerRevision, 1, 2),
            point
        );
    }

    function _grantHash(RH.OriginEnvironment memory o, D.Record memory item)
        private
        pure
        returns (bytes32)
    {
        D.Grant memory g = item.grant;
        return keccak256(
            abi.encode(
                keccak256("6529STREAM_ARTIST_DELEGATION_RECORD_V1"),
                o.chainId,
                o.registry,
                g.artistId,
                g.delegate,
                g.collectionId,
                g.capabilities,
                g.notBefore,
                g.expiresAt,
                g.maxUses,
                g.constraintsHash,
                item.nonce
            )
        );
    }

    function _valid(Fixture memory f) private view {
        f.target.validate(f.b, f.p);
    }

    function _reject(Fixture memory f) private view {
        (bool ok, bytes memory reason) =
            address(f.target).staticcall(abi.encodeCall(f.target.validate, (f.b, f.p)));
        require(!ok && reason.length >= 4, "malformed delegation must reject");
        bytes4 selector;
        assembly ("memory-safe") { selector := mload(add(reason, 32)) }
        require(selector == IH.InvalidRecoveredIdentity.selector, "exact delegation error");
    }
}
