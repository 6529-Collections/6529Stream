// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    StreamArtistRecoveredAggregateSanctionIdentityFacts as Facts
} from "../../../smart-contracts/domains/artist/StreamArtistRecoveredAggregateSanctionIdentityFacts.sol";
import {
    StreamArtistRecoveredSanctionCatalogue as Catalogue
} from "../../../smart-contracts/domains/artist/StreamArtistRecoveredSanctionCatalogue.sol";
import {
    StreamArtistRecoveredSanctionHistoryTypes as H
} from "../../../smart-contracts/domains/artist/StreamArtistRecoveredSanctionHistoryTypes.sol";
import {
    StreamArtistRecoveredHydrationTypes as RH
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistRecoveredHydrationTypes.sol";
import {
    StreamArtistRecoveredIdentityHydrationTypes as IH
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistRecoveredIdentityHydrationTypes.sol";
import {
    StreamArtistRecoveredMultipleTypes as M
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistRecoveredMultipleTypes.sol";
import {
    StreamArtistAuthorityHydrationTypes as AH
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistAuthorityHydration.sol";
import {
    StreamArtistOnboardingTypes as T
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistOnboardingTypes.sol";
import {
    StreamArtistDormancyTypes as Dorm
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistDormancy.sol";
import {
    StreamArtistSanctionHashes as Hashes
} from "../../../smart-contracts/domains/artist/StreamArtistSanctionHashes.sol";
import { StreamArtistHashes } from "../../../smart-contracts/domains/artist/StreamArtistHashes.sol";

interface AggregateSanctionIdentityVm {
    function mockCall(address, bytes calldata, bytes calldata) external;
}

/// @notice Component proof of original historical Identity joins, not an op12/60 ceremony.
/// @dev Only Catalogue.read is mocked at its exact typed library boundary. The original
/// payload decoder, hash/digest functions, canonical Identity frame and chronology run.
/// The synthetic complete bundles/clock table model the enclosing authenticated transport;
/// this host does not prove Archive admission, signature validity or all-owner import.
contract StreamArtistRecoveredAggregateSanctionIdentityFactsTest {
    AggregateSanctionIdentityVm private constant vm =
        AggregateSanctionIdentityVm(address(uint160(uint256(keccak256("hevm cheat code")))));
    bytes32 private constant NONCE = keccak256("identity_authority.replay.nonce_allocator");
    bytes32 private constant OBSERVED =
        keccak256("identity_authority.replay.authorization_consumed_digest");
    bytes32 private constant CANCEL =
        keccak256("identity_authority.replay.dormancy_cancellation_key");

    struct Fixture {
        IH.Bundle[] identities;
        M.State scope;
        H.Inventory history;
        RH.Provenance provenance;
        H.Envelope[] envelopes;
        H.SanctionPayload[] payloads;
    }

    function check(
        bytes[] calldata identities,
        M.State calldata scope,
        H.Inventory calldata h,
        RH.Provenance calldata p
    ) external view {
        Facts.validate(identities, scope, h, p);
    }

    function testAggregateSanctionHistoricalArtistsAndAllOriginalClasses() external {
        Fixture memory f = _fixture();
        require(
            f.scope.collections[0].artistId != f.history.sanctions[0].record.artistId,
            "old Artist differs"
        );
        require(
            f.payloads[0].record.authorityClass == 1 && f.payloads[1].record.authorityClass == 3
                && f.payloads[2].record.authorityClass == 4,
            "original classes"
        );
        for (uint256 i; i < f.identities.length; ++i) {
            require(
                f.identities[i].identity.authorityAddress != f.payloads[i].record.signer,
                "current principal differs"
            );
        }
        _pass(f);
    }

    function testAggregateSanctionRequiresHistoricalArtistAndExactSignature() external {
        Fixture memory f = _fixture();
        _pass(f);
        f.identities[0].signatures[0].signature = hex"ff";
        _reject(f);
        f.identities[0].signatures[0].signature = f.payloads[0].authorization.signature;
        f.scope.artists[0].artistId = keccak256("wrong original Artist");
        _reject(f);
        f.scope.artists[0].artistId = f.identities[0].artistId;
        _pass(f);
    }

    function testAggregateSanctionRequiresExactNoncePointAndConsumedKindOneWord() external {
        Fixture memory f = _fixture();
        _pass(f);
        f.provenance.aliases[2][0].admittedAt.ownerRevision -= 1;
        _reject(f);
        f.provenance.aliases[2][0].admittedAt.ownerRevision += 1;
        f.identities[0].nonces[0].kind = 2;
        _reject(f);
        f.identities[0].nonces[0].kind = 1;
        f.identities[0].nonces[0].words[0].words[0] = 0;
        _reject(f);
        f.identities[0].nonces[0].words[0].words[1] =
            uint256(1) << uint8(f.payloads[0].record.nonce);
        _reject(f);
        f.identities[0].nonces[0].words[0].words[1] = 0;
        f.identities[0].nonces[0].words[0].words[0] =
            uint256(1) << uint8(f.payloads[0].record.nonce);
        _pass(f);
    }

    function testAggregateSanctionObservedDigestMayPrecedeButNotFollowAdmission() external {
        Fixture memory f = _fixture();
        f.provenance.aliases[2][1].admittedAt.ownerRevision = 1;
        _pass(f);
        f.provenance.aliases[2][1].admittedAt.ownerRevision = 11;
        _reject(f);
        f.provenance.aliases[2][1].admittedAt.ownerRevision = 10;
        f.provenance.aliases[2][1].cell.status = 1;
        _reject(f);
    }

    function testAggregateSanctionCompleteRowCountAndExactOldRecord() external {
        Fixture memory f = _fixture();
        _pass(f);
        f.history.sanctions[1].record.signer = address(0xBAD);
        _reject(f);
        f.history.sanctions[1].record.signer = f.payloads[1].approval.signer;
        H.OperationEvidence[] memory operations = f.history.operations;
        f.history.operations = new H.OperationEvidence[](2);
        f.history.operations[0] = operations[0];
        f.history.operations[1] = operations[1];
        _reject(f);
        f.history.operations = operations;
        H.SanctionRow[] memory rows = f.history.sanctions;
        f.history.sanctions = new H.SanctionRow[](2);
        f.history.sanctions[0] = rows[0];
        f.history.sanctions[1] = rows[1];
        _reject(f);
        f.history.sanctions = rows;
        _pass(f);
    }

    function testAggregateSanctionActual42ShapeKeepsZeroOwnerRecordDelta() external {
        Fixture memory f = _fixture();
        _notice(f, 0);
        require(f.provenance.journals[2].length == 2, "notice and cancellation");
        require(
            f.envelopes[0].before_[2].recordChainTip == f.envelopes[0].after_[2].recordChainTip,
            "separate accumulator"
        );
        _pass(f);
        f.envelopes[0].after_[2].recordChainTip = keccak256("false op12 owner record");
        _reject(f);
        f.envelopes[0].after_[2].recordChainTip = f.envelopes[0].before_[2].recordChainTip;
        _pass(f);
    }

    function testAggregateSanctionOpenNoticeRequiresSameRevisionCancellation() external {
        Fixture memory f = _fixture();
        _notice(f, 0);
        _pass(f);
        RH.JournalEntry[] memory rows = f.provenance.journals[2];
        f.provenance.journals[2] = new RH.JournalEntry[](1);
        f.provenance.journals[2][0] = rows[0];
        _reject(f);
        f.provenance.journals[2] = rows;
        f.provenance.journals[2][1].position.point.ownerRevision = 11;
        _reject(f);
        f.provenance.journals[2][1].position.point.ownerRevision = 10;
        f.identities[0].notices[0].phase = 1;
        _reject(f);
        f.identities[0].notices[0].phase = 2;
        _pass(f);
    }

    function testAggregateSanctionCancellationChecksOriginalActorClockCounterAndGuard() external {
        Fixture memory f = _fixture();
        _notice(f, 0);
        _pass(f);
        f.identities[0].notices[0].terminal.actor = address(0xBAD);
        _reject(f);
        f.identities[0].notices[0].terminal.actor = f.payloads[0].record.signer;
        f.identities[0].notices[0].terminal.observedAt += 1;
        _reject(f);
        f.identities[0].notices[0].terminal.observedAt -= 1;
        f.identities[0].notices[0].notice.priorActivity += 1;
        _reject(f);
        f.identities[0].notices[0].notice.priorActivity -= 1;
        f.provenance.aliases[2][6].cell.commitment = keccak256("wrong cancellation");
        _reject(f);
        f.provenance.aliases[2][6].cell.commitment = f.identities[0].notices[0].terminal.recordHash;
        _pass(f);
    }

    function testAggregateSanctionPreviouslyClosedAndFutureNoticesDoNotInventActivity() external {
        Fixture memory f = _fixture();
        _notice(f, 0);
        _pass(f);
        // The earlier terminal belongs to a different original mutation. This leaf relies
        // on the enclosing full Identity validator for its preimage, not on this op12.
        f.provenance.journals[2][1].position.point.ownerRevision = 9;
        f.provenance.aliases[2][6].admittedAt.ownerRevision = 9;
        f.provenance.aliases[2][6].cell.touchedRevision = 9;
        _pass(f);
        // A notice first created after the sanction does not prove activity at the sanction.
        f.identities[0].notices[0].position.point.ownerRevision = 30;
        f.identities[0].notices[0].phase = 1;
        Dorm.Terminal memory emptyTerminal;
        f.identities[0].notices[0].terminal = emptyTerminal;
        RH.ReplayAlias[] memory aliases = f.provenance.aliases[2];
        f.provenance.aliases[2] = new RH.ReplayAlias[](6);
        for (uint256 i; i < 6; ++i) {
            f.provenance.aliases[2][i] = aliases[i];
        }
        f.provenance.journals[2] = new RH.JournalEntry[](1);
        f.provenance.journals[2][0].position = f.identities[0].notices[0].position;
        f.provenance.journals[2][0].receipt.operation = 41;
        f.provenance.journals[2][0].receipt.artistId = f.identities[0].artistId;
        f.provenance.journals[2][0].receipt.recordHash =
        f.identities[0].notices[0].notice.recordHash;
        _pass(f);
    }

    function testAggregateSanctionRejectsSyntheticNative12And13() external {
        Fixture memory f = _fixture();
        _pass(f);
        f.provenance.journals[2] = new RH.JournalEntry[](1);
        f.provenance.journals[2][0].position.point =
            RH.Point(f.provenance.eras[0].originHash, 2, 40);
        f.provenance.journals[2][0].receipt.operation = 12;
        _reject(f);
        f.provenance.journals[2][0].receipt.operation = 13;
        _reject(f);
    }

    function testAggregateSanctionRejectsClassThreeNative42AndOtherSameClockRows() external {
        Fixture memory f = _fixture();
        _pass(f);
        f.provenance.journals[2] = new RH.JournalEntry[](1);
        RH.JournalEntry memory j;
        j.position.point = RH.Point(f.provenance.eras[0].originHash, 2, 12);
        j.receipt.operation = 42;
        j.receipt.artistId = f.identities[1].artistId;
        j.receipt.recordHash = keccak256("invented class3 native42");
        f.provenance.journals[2][0] = j;
        _reject(f);
        f.provenance.journals[2][0].position.point.ownerRevision = 10;
        f.provenance.journals[2][0].receipt.artistId = f.identities[0].artistId;
        f.provenance.journals[2][0].receipt.operation = 39;
        _reject(f);
        f.provenance.journals[2] = new RH.JournalEntry[](0);
        _pass(f);
    }

    function _fixture() private pure returns (Fixture memory f) {
        f.identities = new IH.Bundle[](3);
        f.scope.artists = new AH.Query[](3);
        f.scope.collections = new AH.Query[](1);
        f.history.catalogues = new H.Catalogue[](1);
        f.history.operations = new H.OperationEvidence[](3);
        f.history.sanctions = new H.SanctionRow[](3);
        f.envelopes = new H.Envelope[](3);
        f.payloads = new H.SanctionPayload[](3);
        f.provenance.origins = new RH.OriginEnvironment[](1);
        f.provenance.eras = new RH.Era[](1);
        RH.OriginEnvironment memory o;
        o.chainId = 1;
        o.registry = address(0x1000);
        o.coordinator = address(0x1001);
        o.core = address(0x1002);
        o.manager = address(0x1003);
        o.archive = address(0x1004);
        for (uint256 i; i < 7; ++i) {
            o.owners[i] = address(uint160(0x2000 + i));
            o.ownerCodeHashes[i] = keccak256(abi.encode("synthetic original runtime", i));
        }
        f.provenance.origins[0] = o;
        bytes32 origin = RH.originHash(o);
        f.provenance.eras[0].originHash = origin;
        f.provenance.eras[0].checkpoints[2].schema = RH.CHECKPOINT;
        f.provenance.eras[0].checkpoints[2].ownerState.domainId = RH.ownerDomain(2);
        f.provenance.eras[0].checkpoints[2].ownerState.revision = 100;
        f.history.catalogues[0].originHash = origin;
        f.history.catalogues[0].count = 3;
        f.provenance.aliases[2] = new RH.ReplayAlias[](6);
        for (uint256 i; i < 3; ++i) {
            H.SanctionPayload memory s;
            s.record.artistId = keccak256(abi.encode("historical Artist", i));
            s.record.signer = address(uint160(0x3000 + i));
            s.record.authorityClass = i == 0 ? 1 : uint8(i + 2);
            s.record.terms.collectionId = 91;
            s.record.terms.sanctionSubjectHash = keccak256(abi.encode("subject", i));
            s.record.terms.statementHash = keccak256(abi.encode("statement", i));
            s.record.nonce = 257 + i;
            s.record.signedAt = uint64(1000 + i);
            s.record.deadline = 2000;
            s.binding_.artistId = s.record.artistId;
            s.binding_.artistAddress = s.record.signer;
            s.binding_.generation = uint64(i + 1);
            s.binding_.bindingHash = keccak256(abi.encode("old accepted binding", i));
            s.binding_.accepted = true;
            s.record.bindingGeneration = s.binding_.generation;
            s.record.bindingHash = s.binding_.bindingHash;
            s.authorization =
                T.Authorization(s.record.nonce, 2000, abi.encode("retained signature", i));
            s.request.terms = s.record.terms;
            StreamArtistHashes.Environment memory env =
                StreamArtistHashes.Environment(o.chainId, o.registry, o.core, o.manager);
            s.record.digest = Hashes.digest(env, s.record.terms, s.authorization);
            s.record.recordHash = Hashes.record(env, s.record);
            s.approval = T.SignerApproval(s.record.signer, s.record.digest, false);
            s.authority.authorityAddress = s.record.signer;
            s.authority.authorityClass = s.record.authorityClass;
            f.payloads[i] = s;
            f.envelopes[i].version = 1;
            f.envelopes[i].operation = 12;
            f.envelopes[i].value = s.record.recordHash;
            f.envelopes[i].before_[2] = T.Snapshot(
                RH.ownerDomain(2),
                uint64(9 + i * 2),
                keccak256("before"),
                keccak256("unchanged record tip")
            );
            f.envelopes[i].after_[2] = T.Snapshot(
                RH.ownerDomain(2),
                uint64(10 + i * 2),
                keccak256("after"),
                keccak256("unchanged record tip")
            );
            f.envelopes[i].after_[6].revision = uint64(5 + i);
            f.history.operations[i] = H.OperationEvidence(
                origin,
                12,
                H.Evidence(i, address(uint160(0x4000 + i)), bytes32(i + 1), bytes32(i + 2))
            );
            f.history.sanctions[i].record = _copyRecord(s).record;
            f.history.sanctions[i].point = RH.Point(origin, 6, uint64(5 + i));
            f.history.sanctions[i].evidence = f.history.operations[i].evidence;
            IH.Bundle memory b;
            b.artistId = s.record.artistId;
            b.identity.authorityAddress = address(uint160(0x5000 + i));
            b.identity.authorityClass = 1;
            b.signatures = new IH.SignatureRow[](1);
            b.signatures[0] = IH.SignatureRow(s.record.recordHash, s.authorization.signature);
            b.nonces = new IH.NonceLane[](1);
            b.nonces[0].kind = 1;
            b.nonces[0].key = b.artistId;
            b.nonces[0].words = new AH.NonceWord[](1);
            b.nonces[0].words[0].prefix = s.record.nonce >> 8;
            b.nonces[0].words[0].words[0] = uint256(1) << uint8(s.record.nonce);
            f.identities[i] = b;
            f.scope.artists[i].artistId = b.artistId;
            RH.Point memory point = RH.Point(origin, 2, uint64(10 + i * 2));
            f.provenance.aliases[2][i * 2] = _alias(
                NONCE, keccak256(abi.encode(b.artistId, s.record.nonce)), s.record.digest, point
            );
            f.provenance.aliases[2][i * 2 + 1] = _alias(
                OBSERVED, keccak256(abi.encode(b.artistId, s.record.digest)), s.record.digest, point
            );
        }
        f.scope.collections[0].collectionId = 91;
        f.scope.collections[0].artistId = f.identities[2].artistId;
        f.scope.collections[0].bindingHash = f.payloads[2].binding_.bindingHash;
    }

    function _notice(Fixture memory f, uint256 artist) private pure {
        H.SanctionPayload memory s = f.payloads[artist];
        RH.Point memory point =
            RH.Point(f.provenance.eras[0].originHash, 2, f.envelopes[artist].after_[2].revision);
        IH.NoticeRow memory n;
        n.position.point = RH.Point(point.environmentHash, 2, 2);
        n.notice.recordHash = keccak256("original notice");
        n.notice.terms.artistId = s.record.artistId;
        n.notice.incumbent = s.record.signer;
        n.notice.priorActivity = 7;
        n.notice.noticeEndsAt = 900;
        n.phase = 2;
        n.terminal.noticeHash = n.notice.recordHash;
        n.terminal.actor = s.record.signer;
        n.terminal.authorityClass = 1;
        n.terminal.observedAt = s.record.signedAt;
        RH.OriginEnvironment memory o = f.provenance.origins[0];
        // Literal original42 preimage, independent of the new leaf's private calculation.
        n.terminal.recordHash = keccak256(
            abi.encode(
                keccak256("6529STREAM_ARTIST_DORMANCY_CANCELLATION_V1"),
                o.chainId,
                o.registry,
                o.owners[2],
                n.terminal,
                uint256(8)
            )
        );
        f.identities[artist].notices = new IH.NoticeRow[](1);
        f.identities[artist].notices[0] = n;
        f.provenance.journals[2] = new RH.JournalEntry[](2);
        f.provenance.journals[2][0].position = n.position;
        f.provenance.journals[2][0].receipt.operation = 41;
        f.provenance.journals[2][0].receipt.artistId = s.record.artistId;
        f.provenance.journals[2][0].receipt.recordHash = n.notice.recordHash;
        f.provenance.journals[2][1].position = RH.Position(point, 1);
        f.provenance.journals[2][1].receipt.operation = 42;
        f.provenance.journals[2][1].receipt.artistId = s.record.artistId;
        f.provenance.journals[2][1].receipt.recordHash = n.terminal.recordHash;
        RH.ReplayAlias[] memory aliases = f.provenance.aliases[2];
        f.provenance.aliases[2] = new RH.ReplayAlias[](aliases.length + 1);
        for (uint256 i; i < aliases.length; ++i) {
            f.provenance.aliases[2][i] = aliases[i];
        }
        f.provenance.aliases[2][aliases.length] =
            _alias(CANCEL, n.notice.recordHash, n.terminal.recordHash, point);
    }

    function _alias(bytes32 surface, bytes32 scope, bytes32 commitment, RH.Point memory point)
        private
        pure
        returns (RH.ReplayAlias memory a)
    {
        a.originHash = point.environmentHash;
        a.ownerIndex = 2;
        a.surface = surface;
        a.scope = scope;
        a.originalKey =
            keccak256(abi.encode("synthetic key", point.environmentHash, surface, scope));
        a.cell = T.ReplayCell(commitment, point.ownerRevision, 1, 2);
        a.admittedAt = RH.Point(point.environmentHash, point.ownerIndex, point.ownerRevision);
    }

    function _copyRecord(H.SanctionPayload memory s)
        private
        pure
        returns (H.SanctionPayload memory)
    {
        return abi.decode(abi.encode(s), (H.SanctionPayload));
    }

    function _mock(Fixture memory f) private {
        for (uint256 i; i < f.envelopes.length; ++i) {
            H.SanctionPayload memory s = f.payloads[i];
            f.envelopes[i].payload = abi.encode(
                s.binding_,
                s.request,
                s.authorization,
                s.approval,
                s.authority,
                s.record,
                s.prepared
            );
            // Library selectors require abi.encodeWithSelector with solc0.8.19.
            vm.mockCall(
                address(Catalogue),
                abi.encodeWithSelector(
                    Catalogue.read.selector,
                    f.provenance.origins[0],
                    f.history.catalogues[0],
                    H.Evidence(i, address(uint160(0x4000 + i)), bytes32(i + 1), bytes32(i + 2))
                ),
                abi.encode(f.envelopes[i])
            );
        }
    }

    function _call(Fixture memory f) private returns (bool ok, bytes memory result) {
        _mock(f);
        bytes[] memory identities = new bytes[](f.identities.length);
        for (uint256 i; i < identities.length; ++i) {
            identities[i] = abi.encode(f.identities[i]);
        }
        return address(this)
            .staticcall(abi.encodeCall(this.check, (identities, f.scope, f.history, f.provenance)));
    }

    function _pass(Fixture memory f) private {
        (bool ok, bytes memory result) = _call(f);
        if (!ok) assembly ("memory-safe") { revert(add(result, 32), mload(result)) }
    }

    function _reject(Fixture memory f) private {
        (bool ok, bytes memory result) = _call(f);
        require(!ok, "invalid original Identity join accepted");
        require(
            keccak256(result)
                == keccak256(abi.encodeWithSelector(RH.InvalidRecoveredHydrationProfile.selector)),
            "exact profile rejection"
        );
    }
}
