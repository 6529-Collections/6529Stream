// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    StreamArtistRecoveredAggregateRatificationRows as Rows
} from "../../smart-contracts/domains/artist/StreamArtistRecoveredAggregateRatificationRows.sol";
import {
    StreamArtistRecoveredAggregateRatificationSource as Source
} from "../../smart-contracts/domains/artist/StreamArtistRecoveredAggregateRatificationSource.sol";
import {
    StreamArtistRecoveredAggregateRatificationFacts as Facts
} from "../../smart-contracts/domains/artist/StreamArtistRecoveredAggregateRatificationFacts.sol";
import {
    StreamArtistRecoveredMultipleGenerationConsentValidation as Global
} from "../../smart-contracts/domains/artist/StreamArtistRecoveredMultipleGenerationConsentValidation.sol";
import {
    StreamArtistRecoveredMultipleGenerationTypes as G
} from "../../smart-contracts/domains/artist/StreamArtistRecoveredMultipleGenerationTypes.sol";
import {
    StreamArtistAggregateConsentSupplementTypes as S
} from "../../smart-contracts/domains/artist/StreamArtistAggregateConsentSupplementTypes.sol";
import {
    StreamArtistRecoveredHydrationProvenance as Provenance
} from "../../smart-contracts/domains/artist/StreamArtistRecoveredHydrationProvenance.sol";
import {
    StreamArtistOnboardingTypes as T
} from "../../smart-contracts/interfaces/stream/artist/StreamArtistOnboardingTypes.sol";
import {
    StreamArtistRecoveredHydrationTypes as RH
} from "../../smart-contracts/interfaces/stream/artist/StreamArtistRecoveredHydrationTypes.sol";
import {
    StreamArtistRecoveredIdentityHydrationTypes as IH
} from "../../smart-contracts/interfaces/stream/artist/StreamArtistRecoveredIdentityHydrationTypes.sol";
import {
    StreamArtistRecoveredMultipleTypes as M
} from "../../smart-contracts/interfaces/stream/artist/StreamArtistRecoveredMultipleTypes.sol";
import {
    StreamArtistAuthorityHydrationTypes as AH
} from "../../smart-contracts/interfaces/stream/artist/IStreamArtistAuthorityHydration.sol";
import {
    StreamArtistDelegationHydrationTypes as DH
} from "../../smart-contracts/interfaces/stream/artist/IStreamArtistDelegationAuthorityHydration.sol";
import {
    StreamArtistHistoryTypes as H
} from "../../smart-contracts/interfaces/stream/artist/IStreamArtistHistory.sol";

interface AggregateRatificationVm {
    function mockCall(address target, bytes calldata data, bytes calldata result) external;
    function mockCallRevert(address target, bytes calldata data, bytes calldata reason) external;
}

/// @dev Explicit synthetic typed getter boundary. It is not an admitted Artist owner.
contract AggregateRatificationSourceFixture {
    mapping(bytes32 => T.RatificationRecord) private records;
    mapping(uint256 => T.RatificationRecord) private heads;
    mapping(bytes32 => bytes32) private grants;

    function setRecord(bytes32 lookup, T.RatificationRecord memory row) external {
        records[lookup] = row;
    }

    function setHead(uint256 collection, T.RatificationRecord memory row) external {
        heads[collection] = row;
    }

    function setDelegation(bytes32 record, bytes32 grant) external {
        grants[record] = grant;
    }

    function ratificationRecord(bytes32 record)
        external
        view
        returns (T.RatificationRecord memory)
    {
        return records[record];
    }

    function firstReleaseRatification(uint256 collection)
        external
        view
        returns (T.RatificationRecord memory)
    {
        return heads[collection];
    }

    function recordDelegation(bytes32 record) external view returns (bytes32) {
        return grants[record];
    }
}

/// @notice Real common aggregate52 workers over complete, shape-valid synthetic certificates.
/// @dev This is not owner admission, actual Core, Safe or operation60 coverage. Source tests mock
/// only the exact linked validateOwnerSource boundary; record/head/delegation getters execute.
/// Full canonical Identity bytes are supplied, but whole Identity authentication remains the
/// enclosing caller's responsibility. No signer, nonce, timestamp or generation is invented
/// from the original three-field ratification record.
contract StreamArtistRecoveredAggregateRatificationTest {
    AggregateRatificationVm private constant vm =
        AggregateRatificationVm(address(uint160(uint256(keccak256("hevm cheat code")))));
    bytes32 private constant RATIFICATION = keccak256("consent_finality.replay.ratification_key");
    bytes32 private constant POLICY = keccak256("consent_finality.replay.policy_consent_key");
    bytes32 private constant SCHEMA =
        keccak256("6529STREAM_ARTIST_AGGREGATE_CONSENT_SUPPLEMENT_V1");
    bytes32 private constant A = bytes32(uint256(11));
    bytes32 private constant B = bytes32(uint256(22));

    struct Fixture {
        G.Consents[] all;
        T.RatificationRecord[][] rows;
        M.State scope;
        RH.Provenance p;
        IH.Bundle[] identities;
    }

    function checkGlobal(Fixture memory f, bool legacy) external pure {
        RH.OwnerProvenance memory p = RH.ownerProvenance(f.p, 6);
        if (legacy) Global.validate(f.all, f.scope.collections, p);
        else Global.validate(f.all, f.rows, f.scope.collections, p);
    }

    function facts(Fixture memory f) external pure {
        bytes[] memory ids = new bytes[](f.identities.length);
        for (uint256 i; i < ids.length; ++i) {
            ids[i] = abi.encode(f.identities[i]);
        }
        Facts.validate(ids, f.scope, f.p, f.rows);
    }

    function decode(bytes[] memory raw, bool required)
        external
        pure
        returns (G.Consents[] memory, T.RatificationRecord[][] memory)
    {
        return Rows.decodeRows(raw, required);
    }

    function collect(address owner, Fixture memory f)
        external
        view
        returns (T.RatificationRecord[][] memory)
    {
        return Source.collect(owner, f.scope.collections, RH.ownerProvenance(f.p, 6));
    }

    function heads(address owner, Fixture memory f) external view {
        Source.requireHeads(owner, f.scope.collections, f.rows);
    }

    function testGlobalFourArgumentAdmissionKeepsOldOverloadStrict() external view {
        Fixture memory f = _fixture(address(206));
        this.checkGlobal(f, false);
        this.facts(f);
        _reject(
            abi.encodeCall(this.checkGlobal, (f, true)),
            RH.InvalidRecoveredHydrationProfile.selector
        );
        // The non-ratification policy family still executes in the same complete certificate.
        Fixture memory changed = _copy(f);
        changed.all[2].rows.original.policies[0].recordHash = bytes32(uint256(999));
        _reject(
            abi.encodeCall(this.checkGlobal, (changed, false)),
            RH.InvalidRecoveredHydrationProfile.selector
        );
        this.checkGlobal(f, false);
    }

    function testNoRatificationRowsRetainLegacyBytesAndBothValidatorPaths() external view {
        Fixture memory f = _emptyFixture();
        this.checkGlobal(f, true);
        this.checkGlobal(f, false);
        this.facts(f);
        bytes[] memory raw = _encoded(f);
        for (uint256 i; i < raw.length; ++i) {
            assert(keccak256(raw[i]) == keccak256(abi.encode(f.all[i])));
        }
        (G.Consents[] memory old, T.RatificationRecord[][] memory empty) = this.decode(raw, false);
        assert(keccak256(abi.encode(old)) == keccak256(abi.encode(f.all)));
        assert(keccak256(abi.encode(empty)) == keccak256(abi.encode(f.rows)));
        _reject(
            abi.encodeCall(this.decode, (raw, true)), RH.InvalidRecoveredHydrationProfile.selector
        );
    }

    function testCodecMixedRowsRetainLiteralEnvelopeAndRequireExactFeature() external view {
        Fixture memory f = _fixture(address(206));
        bytes[] memory raw = _encoded(f);
        assert(S.SCHEMA == SCHEMA);
        assert(
            keccak256(raw[0])
                == keccak256(abi.encode(SCHEMA, RH.VERSION, S.Bundle(f.all[0], f.rows[0], "")))
        );
        assert(keccak256(raw[2]) == keccak256(abi.encode(f.all[2])));
        (G.Consents[] memory old, T.RatificationRecord[][] memory records) = this.decode(raw, true);
        assert(keccak256(abi.encode(old, records)) == keccak256(abi.encode(f.all, f.rows)));
        _reject(
            abi.encodeCall(this.decode, (raw, false)), RH.InvalidRecoveredHydrationProfile.selector
        );
    }

    function testCodecRejectsEmptyTaggedVersionTagTrailingAndTruncatedRows() external view {
        Fixture memory f = _fixture(address(206));
        bytes[] memory raw = _encoded(f);
        bytes memory saved = raw[0];
        raw[0] =
            abi.encode(SCHEMA, RH.VERSION, S.Bundle(f.all[0], new T.RatificationRecord[](0), ""));
        _reject(
            abi.encodeCall(this.decode, (raw, true)), RH.InvalidRecoveredHydrationProfile.selector
        );
        raw[0] = abi.encode(SCHEMA, uint16(2), S.Bundle(f.all[0], f.rows[0], ""));
        _reject(
            abi.encodeCall(this.decode, (raw, true)), RH.InvalidRecoveredHydrationProfile.selector
        );
        raw[0] = abi.encode(bytes32(uint256(123)), RH.VERSION, S.Bundle(f.all[0], f.rows[0], ""));
        _rejectAny(abi.encodeCall(this.decode, (raw, true)));
        raw[0] = bytes.concat(saved, bytes32(0));
        _reject(
            abi.encodeCall(this.decode, (raw, true)), RH.InvalidRecoveredHydrationProfile.selector
        );
        raw[0] = new bytes(saved.length - 32);
        for (uint256 i; i < raw[0].length; ++i) {
            raw[0][i] = saved[i];
        }
        _rejectAny(abi.encodeCall(this.decode, (raw, true)));
        raw[0] = saved;
        this.decode(raw, true);
    }

    function testCodecRejectsEmptyCollectionListAndOversizedRatificationVector() external view {
        _reject(
            abi.encodeCall(this.decode, (new bytes[](0), false)),
            RH.InvalidRecoveredHydrationProfile.selector
        );
        Fixture memory f = _fixture(address(206));
        bytes[] memory raw = _encoded(f);
        raw[0] =
            abi.encode(SCHEMA, RH.VERSION, S.Bundle(f.all[0], new T.RatificationRecord[](129), ""));
        _reject(
            abi.encodeCall(this.decode, (raw, true)), RH.InvalidRecoveredHydrationProfile.selector
        );
        this.decode(_encoded(f), true);
    }

    function testRatificationCodecRejectsNonemptySanctionInventoryThenRestores() external view {
        Fixture memory f = _fixture(address(206));
        bytes[] memory raw = _encoded(f);
        bytes memory canonical = raw[0];
        this.decode(raw, true);
        // Even one zero byte is a nonempty, unauthenticated family. The ratification-only
        // worker may not silently ignore it or let a missing ratification feature admit it.
        raw[0] = abi.encode(SCHEMA, RH.VERSION, S.Bundle(f.all[0], f.rows[0], hex"00"));
        _reject(
            abi.encodeCall(this.decode, (raw, true)), RH.InvalidRecoveredHydrationProfile.selector
        );
        _reject(
            abi.encodeCall(this.decode, (raw, false)), RH.InvalidRecoveredHydrationProfile.selector
        );
        raw[0] =
            abi.encode(SCHEMA, RH.VERSION, S.Bundle(f.all[0], f.rows[0], abi.encode(uint256(1))));
        _reject(
            abi.encodeCall(this.decode, (raw, true)), RH.InvalidRecoveredHydrationProfile.selector
        );
        raw[0] = canonical;
        (G.Consents[] memory original, T.RatificationRecord[][] memory records) =
            this.decode(raw, true);
        assert(keccak256(abi.encode(original, records)) == keccak256(abi.encode(f.all, f.rows)));
    }

    function testGlobalRejectsMissingExtraReorderedAndDuplicateRows() external view {
        Fixture memory original = _fixture(address(206));
        for (uint256 mode; mode < 4; ++mode) {
            Fixture memory f = _copy(original);
            if (mode == 0) f.rows[0] = new T.RatificationRecord[](0);
            if (mode == 1) {
                f.rows[2] = new T.RatificationRecord[](1);
                f.rows[2][0] = f.rows[0][0];
            }
            if (mode == 2) {
                T.RatificationRecord memory saved = f.rows[0][0];
                f.rows[0][0] = f.rows[0][1];
                f.rows[0][1] = saved;
            }
            if (mode == 3) f.rows[0][1] = f.rows[0][0];
            _reject(
                abi.encodeCall(this.checkGlobal, (f, false)),
                RH.InvalidRecoveredHydrationProfile.selector
            );
            _reject(abi.encodeCall(this.facts, (f)), RH.InvalidRecoveredHydrationProfile.selector);
        }
        this.checkGlobal(original, false);
        this.facts(original);
    }

    function testGlobalRejectsZeroFieldsAndCrossCollectionOrArtist() external view {
        Fixture memory original = _fixture(address(206));
        for (uint256 mode; mode < 5; ++mode) {
            Fixture memory f = _copy(original);
            if (mode == 0) f.rows[0][0].recordHash = 0;
            if (mode == 1) f.rows[0][0].contentStateHash = 0;
            if (mode == 2) f.rows[0][0].metadataContract = address(0);
            if (mode == 3) f.p.journals[6][0].receipt.collectionId = 2;
            if (mode == 4) f.p.journals[6][0].receipt.artistId = B;
            _commit(f);
            _reject(
                abi.encodeCall(this.checkGlobal, (f, false)),
                RH.InvalidRecoveredHydrationProfile.selector
            );
            _reject(abi.encodeCall(this.facts, (f)), RH.InvalidRecoveredHydrationProfile.selector);
        }
        this.checkGlobal(original, false);
    }

    function testGlobalRejectsAlteredReplayScopeAndUnexpectedNonceIndex() external view {
        Fixture memory original = _fixture(address(206));
        Fixture memory f = _copy(original);
        // Keep the V2 replay key consistent with the changed scope: the global semantic
        // alias join, rather than only the generic provenance key check, must reject it.
        f.p.aliases[6][0].scope = bytes32(uint256(12345));
        f.p.aliases[6][0].originalKey = _key(f.p.origins[0], f.p.aliases[6][0]);
        _sort(f.p.aliases[6]);
        _commit(f);
        _reject(
            abi.encodeCall(this.checkGlobal, (f, false)),
            RH.InvalidRecoveredHydrationProfile.selector
        );
        f = _copy(original);
        f.p.eras[0].checkpoints[6].nonceIndexCount = 1;
        _commit(f);
        _reject(
            abi.encodeCall(this.checkGlobal, (f, false)),
            RH.InvalidRecoveredHydrationProfile.selector
        );
        this.checkGlobal(original, false);
    }

    function testGlobalDoesNotBroadenOtherOperationFamilies() external view {
        Fixture memory f = _fixture(address(206));
        Fixture memory changed = _copy(f);
        // Operation61 is a valid original-journal operation, but not a Consent family
        // admitted by this validator. Supplying52 rows must not silently skip it.
        changed.p.journals[6][0].receipt.operation = 61;
        _commit(changed);
        _reject(abi.encodeCall(this.checkGlobal, (changed, false)), T.UnsupportedProfile.selector);
        this.checkGlobal(f, false);
    }

    function testFactsRequireExactlyOneOriginalSignatureIncludingEmptyDirectEvidence()
        external
        view
    {
        Fixture memory original = _fixture(address(206));
        assert(original.identities[0].signatures[0].signature.length == 0);
        this.facts(original);
        for (uint256 mode; mode < 4; ++mode) {
            Fixture memory f = _copy(original);
            if (mode == 0) f.identities[0].signatures = new IH.SignatureRow[](0);
            if (mode == 1) f.identities[0].signatures[1] = f.identities[0].signatures[0];
            if (mode == 2) f.identities[0].signatures[0].signature = new bytes(4097);
            if (mode == 3) {
                f.identities[1].signatures[0] = f.identities[0].signatures[0];
                f.identities[0].signatures[0].recordHash = bytes32(uint256(999));
            }
            _reject(abi.encodeCall(this.facts, (f)), RH.InvalidRecoveredHydrationProfile.selector);
        }
        this.facts(original);
    }

    function testFactsRejectWrongIdentityDuplicateSubjectsAndCollectionBindings() external view {
        Fixture memory original = _fixture(address(206));
        for (uint256 mode; mode < 5; ++mode) {
            Fixture memory f = _copy(original);
            if (mode == 0) f.identities[0].artistId = B;
            if (mode == 1) {
                f.identities[1].artistId = A;
                f.scope.artists[1].artistId = A;
            }
            if (mode == 2) f.scope.collections[2].collectionId = 1;
            if (mode == 3) f.scope.collections[2].bindingHash = 0;
            if (mode == 4) f.scope.collections[0].artistId = bytes32(uint256(999));
            _reject(abi.encodeCall(this.facts, (f)), RH.InvalidRecoveredHydrationProfile.selector);
        }
        this.facts(original);
    }

    function testFactsRejectDuplicateOccurrenceAndForeignClock() external view {
        Fixture memory f = _fixture(address(206));
        Fixture memory changed = _copy(f);
        changed.p.journals[6][3].receipt.recordHash = changed.p.journals[6][0].receipt.recordHash;
        changed.rows[0][1] = changed.rows[0][0];
        _reject(abi.encodeCall(this.facts, (changed)), RH.InvalidRecoveredHydrationProfile.selector);
        changed = _copy(f);
        changed.p.journals[6][0].position.point.ownerIndex = 2;
        _reject(abi.encodeCall(this.facts, (changed)), RH.InvalidRecoveredHydrationProfile.selector);
        changed = _copy(f);
        changed.p.journals[6][0].position.point.ownerRevision = 5;
        RH.Point memory point = changed.p.journals[6][0].position.point;
        _rejectBytes(
            abi.encodeCall(this.facts, (changed)),
            abi.encodeWithSelector(
                RH.InvalidRecoveredHydrationPoint.selector,
                point.environmentHash,
                point.ownerIndex,
                point.ownerRevision
            )
        );
        this.facts(f);
    }

    function testSourceCollectUsesActualTypedRowsAndLatestPerCollectionIncludingEmpty() external {
        (AggregateRatificationSourceFixture owner, Fixture memory f) = _sourceFixture();
        T.RatificationRecord[][] memory got = this.collect(address(owner), f);
        assert(keccak256(abi.encode(got)) == keccak256(abi.encode(f.rows)));
        assert(got[0].length == 2 && got[1].length == 1 && got[2].length == 0);
        this.heads(address(owner), f);
    }

    function testSourceRejectsAlteredRecordDelegationAndRestoresExactCalls() external {
        (AggregateRatificationSourceFixture owner, Fixture memory f) = _sourceFixture();
        T.RatificationRecord memory saved = f.rows[0][0];
        for (uint256 mode; mode < 4; ++mode) {
            T.RatificationRecord memory row = abi.decode(abi.encode(saved), (T.RatificationRecord));
            if (mode == 0) row.recordHash = bytes32(uint256(999));
            if (mode == 1) row.contentStateHash = 0;
            if (mode == 2) row.metadataContract = address(0);
            if (mode == 3) owner.setDelegation(saved.recordHash, bytes32(uint256(9)));
            owner.setRecord(saved.recordHash, row);
            _reject(
                abi.encodeCall(this.collect, (address(owner), f)),
                RH.InvalidRecoveredHydrationProfile.selector
            );
            owner.setDelegation(saved.recordHash, 0);
            owner.setRecord(saved.recordHash, saved);
            this.collect(address(owner), f);
        }
    }

    function testSourceRejectsStaleNonemptyAndInventedEmptyCollectionHeads() external {
        (AggregateRatificationSourceFixture owner, Fixture memory f) = _sourceFixture();
        owner.setHead(1, f.rows[0][0]);
        _reject(
            abi.encodeCall(this.collect, (address(owner), f)),
            RH.InvalidRecoveredHydrationProfile.selector
        );
        owner.setHead(1, f.rows[0][1]);
        owner.setHead(3, f.rows[1][0]);
        _reject(
            abi.encodeCall(this.heads, (address(owner), f)),
            RH.InvalidRecoveredHydrationProfile.selector
        );
        T.RatificationRecord memory empty;
        owner.setHead(3, empty);
        this.collect(address(owner), f);
    }

    function testSourcePropagatesExactOriginalProvenanceRefusalBeforeGetters() external {
        (AggregateRatificationSourceFixture owner, Fixture memory f) = _sourceFixture();
        bytes memory input = _sourceInput(owner, f);
        bytes memory reason =
            abi.encodeWithSelector(RH.InvalidRecoveredHydrationProvenance.selector);
        owner.setHead(1, f.rows[0][0]);
        vm.mockCallRevert(address(Provenance), input, reason);
        _rejectBytes(abi.encodeCall(this.collect, (address(owner), f)), reason);
        vm.mockCall(address(Provenance), input, abi.encode(bytes32(uint256(1))));
        _reject(
            abi.encodeCall(this.collect, (address(owner), f)),
            RH.InvalidRecoveredHydrationProfile.selector
        );
        owner.setHead(1, f.rows[0][1]);
        this.collect(address(owner), f);
    }

    function testSourceRejectsForeignArtistUnknownCollectionAndRepeatedQuery() external {
        (AggregateRatificationSourceFixture owner, Fixture memory original) = _sourceFixture();
        for (uint256 mode; mode < 3; ++mode) {
            Fixture memory f = _copy(original);
            if (mode == 0) f.p.journals[6][0].receipt.artistId = B;
            if (mode == 1) f.p.journals[6][0].receipt.collectionId = 99;
            if (mode == 2) f.scope.collections[2].collectionId = 1;
            // Admit only this supplied certificate at the explicitly synthetic boundary.
            // The real Source worker must still reject its subject/query relationship.
            vm.mockCall(
                address(Provenance), _sourceInput(owner, f), abi.encode(bytes32(uint256(1)))
            );
            _reject(
                abi.encodeCall(this.collect, (address(owner), f)),
                RH.InvalidRecoveredHydrationProfile.selector
            );
        }
        this.collect(address(owner), original);
    }

    function _fixture(address consent) private pure returns (Fixture memory f) {
        f.all = new G.Consents[](3);
        f.rows = new T.RatificationRecord[][](3);
        f.scope.artists = new AH.Query[](2);
        f.scope.artists[0].artistId = A;
        f.scope.artists[1].artistId = B;
        f.scope.collections = new AH.Query[](3);
        f.identities = new IH.Bundle[](2);
        f.identities[0].artistId = A;
        f.identities[1].artistId = B;
        for (uint256 k; k < 3; ++k) {
            AH.Query memory q;
            q.artistId = k == 1 ? B : A;
            q.collectionId = k + 1;
            q.bindingHash = bytes32(uint256(100 + k));
            f.scope.collections[k] = q;
            f.all[k].rows.original.artistId = q.artistId;
            f.all[k].rows.original.collectionId = q.collectionId;
            f.all[k].rows.original.bindingHash = q.bindingHash;
            f.all[k].bindings = new T.Binding[](1);
            f.all[k].bindings[0].artistId = q.artistId;
            f.all[k].bindings[0].generation = 1;
            f.all[k].bindings[0].bindingHash = q.bindingHash;
            f.all[k].bindings[0].consentMode = 1;
            f.all[k].bindings[0].accepted = true;
        }
        f.rows[0] = new T.RatificationRecord[](2);
        f.rows[1] = new T.RatificationRecord[](1);
        f.rows[2] = new T.RatificationRecord[](0);
        f.rows[0][0] =
            T.RatificationRecord(bytes32(uint256(501)), bytes32(uint256(601)), address(701));
        f.rows[0][1] =
            T.RatificationRecord(bytes32(uint256(502)), bytes32(uint256(602)), address(701));
        f.rows[1][0] =
            T.RatificationRecord(bytes32(uint256(503)), bytes32(uint256(603)), address(702));
        f.scope.collections[2].policies = new AH.PolicyKey[](1);
        f.scope.collections[2].policies[0] =
            AH.PolicyKey(bytes32(uint256(81)), bytes32(uint256(82)));
        f.all[2].rows.original.keys = f.scope.collections[2].policies;
        f.all[2].rows.original.policies = new DH.Policy[](1);
        f.all[2].rows.original.policies[0] = DH.Policy(bytes32(uint256(504)), bytes32(0));
        f.identities[0].signatures = new IH.SignatureRow[](2);
        f.identities[0].signatures[0] = IH.SignatureRow(f.rows[0][0].recordHash, "");
        f.identities[0].signatures[1] = IH.SignatureRow(f.rows[0][1].recordHash, hex"112233");
        f.identities[1].signatures = new IH.SignatureRow[](1);
        f.identities[1].signatures[0] = IH.SignatureRow(f.rows[1][0].recordHash, hex"4455");
        f.p.origins = new RH.OriginEnvironment[](1);
        RH.OriginEnvironment memory o;
        o.chainId = 31337;
        o.registry = address(101);
        o.coordinator = address(102);
        o.archive = address(103);
        o.core = address(104);
        o.manager = address(105);
        o.suiteConfigurationHash = bytes32(uint256(106));
        for (uint8 i; i < 7; ++i) {
            o.owners[i] = address(uint160(200 + i));
            o.ownerCodeHashes[i] = bytes32(uint256(300 + i));
        }
        o.owners[6] = consent;
        f.p.origins[0] = o;
        f.p.eras = new RH.Era[](1);
        f.p.eras[0].originHash = RH.originHash(o);
        f.p.eras[0].checkpoints[6].schema = RH.CHECKPOINT;
        f.p.eras[0].checkpoints[6].ownerState.domainId = RH.ownerDomain(6);
        f.p.eras[0].checkpoints[6].ownerState.stateRoot = bytes32(uint256(401));
        f.p.eras[0].checkpoints[6].ownerState.recordChainTip = bytes32(uint256(402));
        f.p.eras[0].checkpoints[6].ownerState.revision = 4;
        f.p.eras[0].checkpoints[6].replayCount = 4;
        f.p.eras[0].checkpoints[6].replayRoot = bytes32(uint256(403));
        f.p.eras[0].nativeCounts[6] = 4;
        f.p.journals[6] = new RH.JournalEntry[](4);
        f.p.journals[6][0] = _entry(f, 0, 52, A, 1, f.rows[0][0].recordHash);
        f.p.journals[6][1] = _entry(f, 1, 14, A, 3, bytes32(uint256(504)));
        f.p.journals[6][2] = _entry(f, 2, 52, B, 2, f.rows[1][0].recordHash);
        f.p.journals[6][3] = _entry(f, 3, 52, A, 1, f.rows[0][1].recordHash);
        f.p.aliases[6] = new RH.ReplayAlias[](4);
        for (uint256 i; i < 4; ++i) {
            RH.JournalEntry memory n = f.p.journals[6][i];
            RH.ReplayAlias memory a;
            a.originHash = f.p.eras[0].originHash;
            a.ownerIndex = 6;
            a.surface = i == 1 ? POLICY : RATIFICATION;
            a.scope = i == 1
                ? keccak256(abi.encode(uint256(3), bytes32(uint256(81)), bytes32(uint256(82))))
                : keccak256(abi.encode(n.receipt.collectionId, n.receipt.recordHash));
            a.admittedAt = n.position.point;
            a.cell = T.ReplayCell(n.receipt.recordHash, uint64(i + 1), 1, 2);
            a.originalKey = _key(o, a);
            f.p.aliases[6][i] = a;
        }
        _sort(f.p.aliases[6]);
        _commit(f);
    }

    function _emptyFixture() private pure returns (Fixture memory f) {
        f = _fixture(address(206));
        for (uint256 k; k < f.rows.length; ++k) {
            f.rows[k] = new T.RatificationRecord[](0);
        }
        f.scope.collections[2].policies = new AH.PolicyKey[](0);
        f.all[2].rows.original.keys = new AH.PolicyKey[](0);
        f.all[2].rows.original.policies = new DH.Policy[](0);
        f.p.journals[6] = new RH.JournalEntry[](0);
        f.p.aliases[6] = new RH.ReplayAlias[](0);
        f.p.eras[0].nativeCounts[6] = 0;
        f.p.eras[0].checkpoints[6].ownerState.revision = 0;
        f.p.eras[0].checkpoints[6].replayCount = 0;
        f.p.eras[0].checkpoints[6].replayRoot = 0;
        _commit(f);
    }

    function _sourceFixture()
        private
        returns (AggregateRatificationSourceFixture owner, Fixture memory f)
    {
        owner = new AggregateRatificationSourceFixture();
        f = _fixture(address(owner));
        for (uint256 k; k < f.rows.length; ++k) {
            for (uint256 i; i < f.rows[k].length; ++i) {
                owner.setRecord(f.rows[k][i].recordHash, f.rows[k][i]);
            }
            if (f.rows[k].length != 0) owner.setHead(k + 1, f.rows[k][f.rows[k].length - 1]);
        }
        // Mock the exact fixed-library selector and full arguments, not a broad target fallback.
        vm.mockCall(address(Provenance), _sourceInput(owner, f), abi.encode(bytes32(uint256(1))));
    }

    function _sourceInput(AggregateRatificationSourceFixture owner, Fixture memory f)
        private
        pure
        returns (bytes memory)
    {
        return abi.encodeWithSelector(
            Provenance.validateOwnerSource.selector,
            RH.ownerProvenance(f.p, 6),
            uint8(6),
            address(owner)
        );
    }

    function _entry(
        Fixture memory f,
        uint256 index,
        uint16 operation,
        bytes32 artist,
        uint256 collection,
        bytes32 record
    ) private pure returns (RH.JournalEntry memory) {
        return RH.JournalEntry(
            RH.Position(RH.Point(f.p.eras[0].originHash, 6, uint64(index + 1)), index),
            H.Receipt(operation, artist, collection, record)
        );
    }

    function _key(RH.OriginEnvironment memory o, RH.ReplayAlias memory a)
        private
        pure
        returns (bytes32)
    {
        return keccak256(
            abi.encode(
                keccak256("6529STREAM_ARTIST_OWNER_REPLAY_KEY_V2"),
                o.chainId,
                o.registry,
                o.coordinator,
                o.archive,
                o.owners[6],
                RH.ownerDomain(6),
                a.surface,
                a.scope
            )
        );
    }

    function _sort(RH.ReplayAlias[] memory aliases_) private pure {
        for (uint256 i; i < aliases_.length; ++i) {
            for (uint256 j = i + 1; j < aliases_.length; ++j) {
                if (aliases_[j].originalKey < aliases_[i].originalKey) {
                    RH.ReplayAlias memory saved = aliases_[i];
                    aliases_[i] = aliases_[j];
                    aliases_[j] = saved;
                }
            }
        }
    }

    function _commit(Fixture memory f) private pure {
        bytes32 h = RH.ownerProvenanceHash(RH.ownerProvenance(f.p, 6), 6);
        for (uint256 k; k < f.all.length; ++k) {
            f.all[k].rows.original.provenance = h;
        }
    }

    function _encoded(Fixture memory f) private pure returns (bytes[] memory raw) {
        raw = new bytes[](f.all.length);
        for (uint256 k; k < raw.length; ++k) {
            raw[k] = Rows.encode(f.all[k], f.rows[k]);
        }
    }

    function _copy(Fixture memory f) private pure returns (Fixture memory) {
        return abi.decode(abi.encode(f), (Fixture));
    }

    function _reject(bytes memory input, bytes4 selector) private view {
        _rejectBytes(input, abi.encodeWithSelector(selector));
    }

    function _rejectBytes(bytes memory input, bytes memory expected) private view {
        (bool ok, bytes memory result) = address(this).staticcall(input);
        assert(!ok && keccak256(result) == keccak256(expected));
    }

    function _rejectAny(bytes memory input) private view {
        (bool ok,) = address(this).staticcall(input);
        assert(!ok);
    }
}
