// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { StreamArtistRecoveredPreparationTuple as Tuple } from
    "../../../smart-contracts/domains/artist/StreamArtistRecoveredPreparationTuple.sol";
import { StreamArtistRecoveredPreparationIdentityFacts as Facts } from
    "../../../smart-contracts/domains/artist/StreamArtistRecoveredPreparationIdentityFacts.sol";
import { StreamArtistRecoveredIdentityHydrationTypes as IH } from
    "../../../smart-contracts/interfaces/stream/artist/StreamArtistRecoveredIdentityHydrationTypes.sol";
import { StreamArtistRecoveredHydrationTypes as RH } from
    "../../../smart-contracts/interfaces/stream/artist/StreamArtistRecoveredHydrationTypes.sol";
import { StreamArtistAuthorityHydrationTypes as AH } from
    "../../../smart-contracts/interfaces/stream/artist/IStreamArtistAuthorityHydration.sol";
import { StreamArtistOnboardingTypes as T } from
    "../../../smart-contracts/interfaces/stream/artist/StreamArtistOnboardingTypes.sol";
import { StreamArtistRecoveredTimingTypes as TM } from
    "../../../smart-contracts/interfaces/stream/artist/StreamArtistRecoveredTimingTypes.sol";
import { StreamArtistRecoveredDelegatedConsentHydration as Delegated } from
    "../../../smart-contracts/domains/artist/StreamArtistRecoveredDelegatedConsentHydration.sol";
import { StreamArtistRecoveredContentConsentHydration as Content } from
    "../../../smart-contracts/domains/artist/StreamArtistRecoveredContentConsentHydration.sol";
import { StreamArtistDelegationHydrationTypes as DH } from
    "../../../smart-contracts/interfaces/stream/artist/IStreamArtistDelegationAuthorityHydration.sol";
import { StreamArtistContentTypes as CT } from
    "../../../smart-contracts/interfaces/stream/artist/StreamArtistContentTypes.sol";
import { IStreamArtistContentRecordsOwner as ContentOwner } from
    "../../../smart-contracts/interfaces/stream/artist/IStreamArtistContentOwner.sol";
import { StreamArtistPublicationHydrationTypes as PubH } from
    "../../../smart-contracts/interfaces/stream/artist/IStreamArtistPublicationAuthorityHydration.sol";

/// @dev Synthetic typed sentinels for pure encoding/projection tests, not source certificates.
abstract contract RecoveredPreparationTupleFixture {
    function _same(bytes memory actual, bytes memory expected) internal pure {
        assert(actual.length == expected.length && keccak256(actual) == keccak256(expected));
    }

    function _bytes(uint256 seed, uint256 length) internal pure returns (bytes memory result) {
        result = new bytes(length);
        for (uint256 i; i < length; ++i) {
            result[i] = bytes1(uint8(uint256(keccak256(abi.encode(seed, i)))));
        }
    }

    function _words(uint256 seed, uint256 lane, uint256 count)
        internal
        pure
        returns (AH.NonceWord[] memory words)
    {
        words = new AH.NonceWord[](count);
        for (uint256 i; i < count; ++i) {
            words[i].prefix = uint256(keccak256(abi.encode(seed, lane, i)));
            words[i].exhausted = ((seed >> i) & 1) != 0;
            for (uint256 j; j < 32; ++j) {
                words[i].words[j] = uint256(keccak256(abi.encode(seed, lane, i, j)));
            }
        }
    }

    function _nonceFixture(uint256 seed, uint256 lanes, uint256 words)
        internal
        pure
        returns (IH.Bundle memory identity, RH.NonceInventory[] memory nonces)
    {
        identity.nonces = new IH.NonceLane[](lanes);
        nonces = new RH.NonceInventory[](lanes);
        for (uint256 i; i < lanes; ++i) {
            identity.nonces[i].kind = uint8(i + 1);
            identity.nonces[i].key = keccak256(abi.encode("lane", seed, i));
            identity.nonces[i].hint = seed;
            identity.nonces[i].words = _words(seed, i, words);
            nonces[i].index.kind = identity.nonces[i].kind;
            nonces[i].index.key = identity.nonces[i].key;
            nonces[i].index.prefixCount = words;
            // Separate allocations are essential: mutations must not change both witnesses.
            nonces[i].words = _words(seed, i, words);
        }
    }

    function _identity(uint256 seed, bool populated) internal pure returns (IH.Bundle memory b) {
        if (!populated) return b;
        (b,) = _nonceFixture(seed, 2, 2);
        bytes32 key = keccak256(abi.encode("identity", seed));
        bytes memory payload = _bytes(seed, 1 + seed % 65);
        b.artistId = key;
        b.sourceSnapshot = T.Snapshot(key, 17, key, keccak256(payload));
        b.nextRegistrationNonce = seed;
        b.identity.authorityAddress = address(0x1234);
        b.identity.authorityClass = 3;
        b.identity.status = 2;
        b.identity.identityRecordURI = string(payload);
        b.identity.displayName = "nested identity sentinel";
        b.identityDocument = payload;
        b.documents = new IH.DocumentRow[](2);
        b.documents[0] = IH.DocumentRow(key, payload);
        b.documents[1] = IH.DocumentRow(keccak256(payload), _bytes(seed, 33));
        b.heads.latestRecovery = key;
        b.heads.guardianRecordsSeen = 2;
        b.timing.entries = new TM.Entry[](2);
        b.timing.entries[0].change.actionId = key;
        b.timing.entries[1].commitment = key;
        b.timing.configuration.values[6] = uint64(seed);
        b.timing.checkpoint = TM.Checkpoint(key, 7, seed, key, keccak256(payload));
        b.signatures = new IH.SignatureRow[](2);
        b.signatures[0] = IH.SignatureRow(key, payload);
        b.signatures[1] = IH.SignatureRow(keccak256(payload), _bytes(seed, 65));
        b.revisions = new IH.RevisionRow[](1);
        b.revisions[0].document = payload;
        b.revisions[0].position.nativeIndex = seed;
        b.delegations = new IH.DelegationRow[](1);
        b.delegations[0].recordHash = key;
        b.guardians = new IH.GuardianRow[](1);
        b.guardians[0].record.recordHash = key;
        b.guardians[0].record.terms.guardians = new address[](2);
        b.guardians[0].record.terms.guardians[0] = address(0x1234);
        b.guardians[0].record.terms.guardians[1] = address(0x5678);
        b.memberships = new IH.MembershipRow[](1);
        b.memberships[0].actor = address(0x1234);
        b.memberships[0].indices = new uint64[](2);
        b.memberships[0].indices[1] = uint64(seed);
        b.rotations = new IH.RotationRow[](1);
        b.rotations[0].record.recordHash = key;
        b.rotations[0].approvals = new bool[](2);
        b.rotations[0].approvals[1] = true;
        b.contests = new IH.ContestRow[](1);
        b.contests[0].position.nativeIndex = seed;
        b.causes = new IH.CauseRow[](1);
        b.causes[0].notice = key;
        b.dismissals = new IH.DismissalRow[](1);
        b.dismissals[0].position.nativeIndex = seed;
        b.closures = new IH.ClosureRow[](1);
        b.closures[0].transition = key;
        b.standing = new IH.StandingRow[](1);
        b.standing[0].account = address(0x1234);
        b.standingRecords = new IH.StandingRecordRow[](1);
        b.standingRecords[0].rewindContinuation = key;
        b.recoveries = new IH.RecoveryRow[](1);
        b.recoveries[0].record.fields.vestedAuthorityClass = 1;
        b.recoveries[0].secondaryOccurrence = key;
        b.vestings = new IH.VestingRow[](1);
        b.vestings[0].point.environmentHash = key;
        b.actions = new IH.ActionRow[](1);
        b.actions[0].evidenceV2.manifestHash = key;
        b.actions[0].evidenceV3.manifestHash = keccak256(payload);
        b.actions[0].excludedMemberships = new uint64[](2);
        b.actions[0].excludedMemberships[1] = uint64(seed);
        b.actions[0].restoredGuardian.terms.guardians = new address[](1);
        b.actions[0].restoredGuardian.terms.guardians[0] = address(0x5678);
        b.designations = new IH.DesignationRow[](1);
        b.designations[0].position.nativeIndex = seed;
        b.directives = new IH.DirectiveRow[](1);
        b.directives[0].payload = payload;
        b.sanctionGrants = new IH.GrantRow[](1);
        b.sanctionGrants[0].position.nativeIndex = seed;
        b.estates = new IH.EstateRow[](1);
        b.estates[0].phase = 2;
        b.notices = new IH.NoticeRow[](1);
        b.notices[0].phase = 3;
        b.findings = new IH.FindingRow[](1);
        b.findings[0].latestForCollection = key;
        b.originalContinuations = new IH.OriginalContinuationRow[](1);
        b.originalContinuations[0].point.environmentHash = key;
        b.revisionContinuations = new IH.RevisionContinuationRow[](1);
        b.revisionContinuations[0].point.environmentHash = key;
        b.standingContinuations = new IH.StandingContinuationRow[](1);
        b.standingContinuations[0].scopeHead = key;
        b.capabilityContinuations = new IH.CapabilityContinuationRow[](1);
        b.capabilityContinuations[0].point.environmentHash = key;
    }

    function _provenance(uint256 seed, bool populated)
        internal
        pure
        returns (RH.Provenance memory p)
    {
        if (!populated) return p;
        bytes32 key = keccak256(abi.encode("origin", seed));
        p.origins = new RH.OriginEnvironment[](2);
        p.eras = new RH.Era[](2);
        for (uint256 era; era < 2; ++era) {
            p.origins[era].chainId = seed;
            p.origins[era].registry = address(uint160(0x400 + era));
            p.eras[era].originHash = key;
            p.eras[era].priorImportCommitment = bytes32(era + 1);
            for (uint8 i; i < 7; ++i) {
                p.origins[era].owners[i] = address(uint160(0x500 + uint256(i)));
                p.origins[era].ownerCodeHashes[i] = key;
                p.eras[era].checkpoints[i].ownerState.stateRoot = key;
                p.eras[era].checkpoints[i].nonceIndexCount = 2;
            }
        }
        for (uint8 i; i < 7; ++i) {
            p.journals[i] = new RH.JournalEntry[](2);
            p.journals[i][0].position.point = RH.Point(key, i, uint64(seed));
            p.journals[i][1].receipt.recordHash = key;
            p.aliases[i] = new RH.ReplayAlias[](1);
            p.aliases[i][0].ownerIndex = i;
            p.aliases[i][0].originalKey = key;
            p.aliases[i][0].cell = T.ReplayCell(key, uint64(seed), 1, 2);
        }
    }

    function _query(uint256 seed, bool populated) internal pure returns (AH.Query memory q) {
        if (!populated) return q;
        q.artistId = keccak256(abi.encode("artist", seed));
        q.collectionId = seed;
        q.bindingHash = keccak256("binding");
        q.policies = new AH.PolicyKey[](2);
        q.policies[0] = AH.PolicyKey(q.artistId, q.bindingHash);
        q.policies[1] = AH.PolicyKey(q.bindingHash, q.artistId);
        q.records = new bytes32[](2);
        q.records[0] = q.artistId;
        q.records[1] = q.bindingHash;
    }

    function _delegated(uint256 seed, bool populated)
        internal
        pure
        returns (Delegated.Bundle memory b)
    {
        if (!populated) return b;
        AH.Query memory q = _query(seed, true);
        b.provenance = keccak256("provenance");
        b.artistId = q.artistId;
        b.collectionId = q.collectionId;
        b.bindingHash = q.bindingHash;
        b.keys = q.policies;
        b.policies = new DH.Policy[](2);
        b.policies[0] = DH.Policy(q.artistId, q.bindingHash);
        b.policies[1] = DH.Policy(q.bindingHash, q.artistId);
        b.economics = new Delegated.Economics[](1);
        b.economics[0].grant = q.bindingHash;
        b.economics[0].item.recordHash = q.artistId;
        b.sales = new DH.Sale[](1);
        b.sales[0].item.recordHash = q.bindingHash;
        b.sales[0].item.nonce = seed;
        b.sales[0].grant = q.artistId;
    }

    function _content(uint256 seed, bool populated)
        internal
        pure
        returns (Content.Bundle memory b)
    {
        if (!populated) return b;
        b.original = _delegated(seed, true);
        b.consents = new ContentOwner.ConsentRecord[](1);
        b.consents[0].recordHash = b.original.artistId;
        b.consents[0].terms.collectionId = seed;
        b.royalties = new Content.Royalty[](1);
        b.royalties[0].terms = T.RoyaltyFreeze(address(0x1234), seed, bytes32(seed), bytes32(seed));
        b.royalties[0].grant = b.original.bindingHash;
        b.freezes = new CT.FreezeRecord[](1);
        b.freezes[0].recordHash = b.original.bindingHash;
        b.freezes[0].metadataContract = address(0x5678);
        b.freezes[0].lockClasses = new bytes32[](2);
        b.freezes[0].lockClasses[0] = b.original.artistId;
        b.freezes[0].lockClasses[1] = b.original.bindingHash;
    }

    function _rows(uint256 seed, bool populated) internal pure returns (PubH.Row[] memory rows) {
        rows = new PubH.Row[](populated ? 2 : 0);
        for (uint256 i; i < rows.length; ++i) {
            rows[i].attestation.input.nonce = seed;
            rows[i].attestation.statement = _bytes(seed, i == 0 ? 31 : 33);
            rows[i].publication.metadataHostCodeHash = keccak256(abi.encode(seed, i));
            rows[i].publication.publication.metadataHost = address(uint160(0x600 + i));
            rows[i].publication.evidence.bindingGeneration = uint64(seed);
        }
    }
}

/// @notice All fixed tuple forms compared with compiler-generated ABI for their actual types.
/// @dev No mock, source read, source authenticity, or admitted-history claim is involved.
contract StreamArtistRecoveredPreparationTupleEncodingTest is RecoveredPreparationTupleFixture {
    function testEveryTupleConstructorMatchesEmptyTypedValues() public pure {
        _pairs(0, false);
        _joins(0, false, 0);
    }

    function testEveryTupleConstructorMatchesPopulatedNestedValues() public pure {
        _pairs(64, true);
        _joins(64, true, 2);
        _joins(32, true, type(uint8).max);
    }

    function testOneWithTwoWordsPreservesBoolAndFullWidthEraBoundaries() public pure {
        IH.Bundle memory identity = _identity(32, true);
        bytes memory raw = abi.encode(identity);
        uint256[5] memory eras = [uint256(0), 1, 16, 17, type(uint256).max];
        for (uint256 payout; payout < 2; ++payout) {
            for (uint256 i; i < eras.length; ++i) {
                _same(
                    Tuple.oneWithTwoWords(raw, payout, eras[i]),
                    abi.encode(identity, payout != 0, eras[i])
                );
            }
        }
    }

    function testFuzzEveryTupleConstructorMatchesNativeABI(uint64 seed, uint8 mode) public pure {
        // Row counts are fixed at at most two; byte strings are bounded at65 bytes.
        _pairs(seed, true);
        _joins(seed, true, mode);
    }

    function _pairs(uint256 seed, bool populated) private pure {
        IH.Bundle memory identity = _identity(seed, populated);
        RH.Provenance memory provenance = _provenance(seed, populated);
        RH.OwnerProvenance memory owner = RH.ownerProvenance(provenance, 2);
        (, RH.NonceInventory[] memory nonces) = _nonceFixture(seed, populated ? 2 : 0, 2);
        bytes memory raw = abi.encode(identity);
        _same(Tuple.two(abi.encode(provenance), raw), abi.encode(provenance, identity));
        _same(Tuple.two(raw, abi.encode(owner)), abi.encode(identity, owner));
        _same(Tuple.two(raw, abi.encode(nonces)), abi.encode(identity, nonces));
        _same(
            Tuple.oneWithTwoWords(raw, populated ? 1 : 0, seed),
            abi.encode(identity, populated, seed)
        );
        _same(bytes.concat(abi.encode(uint256(32)), Tuple.body(raw)), raw);
    }

    function _joins(uint256 seed, bool populated, uint8 mode) private pure {
        IH.Bundle memory identity = _identity(seed, populated);
        AH.Query memory query = _query(seed, populated);
        RH.Provenance memory provenance = _provenance(seed, populated);
        PubH.Row[] memory rows = _rows(seed, populated);
        Delegated.Bundle memory delegated = _delegated(seed, populated);
        Content.Bundle memory content = _content(seed, populated);
        bytes memory raw = abi.encode(identity);
        _same(
            Tuple.four(raw, abi.encode(rows), abi.encode(query), abi.encode(provenance)),
            abi.encode(identity, rows, query, provenance)
        );
        _same(
            Tuple.fourAndMode(
                raw, abi.encode(delegated), abi.encode(query), abi.encode(provenance), mode
            ),
            abi.encode(identity, delegated, query, provenance, mode)
        );
        _same(
            Tuple.fourModeAndRows(
                raw, abi.encode(delegated), abi.encode(query), abi.encode(provenance), mode,
                abi.encode(rows)
            ),
            abi.encode(identity, delegated, query, provenance, mode, rows)
        );
        _same(
            Tuple.fourModeAndRows(
                raw, abi.encode(content), abi.encode(query), abi.encode(provenance), mode,
                abi.encode(rows)
            ),
            abi.encode(identity, content, query, provenance, mode, rows)
        );
    }
}

/// @notice Envelope guards and byte-exact result forwarding, independent of semantic decoding.
contract StreamArtistRecoveredPreparationTupleFramingTest is RecoveredPreparationTupleFixture {
    function body(bytes memory raw) external pure returns (bytes memory) {
        return Tuple.body(raw);
    }

    function requireSingle(bytes memory raw) external pure {
        Tuple.requireSingle(raw);
    }

    function result(bool ok, bytes memory raw) external pure returns (bytes memory) {
        return Tuple.result(ok, raw);
    }

    function construct(uint8 form, bytes[5] memory args) external pure returns (bytes memory) {
        if (form == 0) return Tuple.two(args[0], args[1]);
        if (form == 1) return Tuple.oneWithTwoWords(args[0], 1, 16);
        if (form == 2) return Tuple.four(args[0], args[1], args[2], args[3]);
        if (form == 3) return Tuple.fourAndMode(args[0], args[1], args[2], args[3], 2);
        return Tuple.fourModeAndRows(args[0], args[1], args[2], args[3], 2, args[4]);
    }

    function testBodyRejectsEveryShortLength() public view {
        for (uint256 length; length < 64; ++length) {
            bytes memory raw = new bytes(length);
            if (length >= 32) {
                assembly ("memory-safe") { mstore(add(raw, 32), 32) }
            }
            _badFrame(raw);
        }
    }

    function testFuzzBodyRejectsMisalignedLength(uint8 words, uint8 tail) public view {
        bytes memory raw = new bytes(64 + (uint256(words) % 8) * 32 + 1 + uint256(tail) % 31);
        assembly ("memory-safe") { mstore(add(raw, 32), 32) }
        _badFrame(raw);
    }

    function testFuzzBodyRejectsWrongOuterOffset(uint256 offset) public view {
        if (offset == 32) offset = 64;
        _badFrame(abi.encode(offset, uint256(0)));
    }

    function testOuterFramingDoesNotClaimNestedSemanticValidation() public pure {
        bytes memory framed = abi.encode(uint256(32), type(uint256).max);
        Tuple.requireSingle(framed);
        _same(Tuple.body(framed), abi.encode(type(uint256).max));
    }

    function testEveryConstructorRejectsEveryMalformedArgument() public view {
        uint8[5] memory counts = [uint8(2), 1, 4, 4, 5];
        for (uint8 form; form < 5; ++form) {
            for (uint8 bad; bad < counts[form]; ++bad) {
                bytes[5] memory args;
                for (uint8 i; i < 5; ++i) args[i] = abi.encode(bytes("valid dynamic body"));
                args[bad] = abi.encode(uint256(64), uint256(0));
                _expectProfile(abi.encodeCall(this.construct, (form, args)));
            }
        }
    }

    function testResultPreservesEmptyAndNonstandardRevertBytes() public view {
        _result(new bytes(0));
        _result(hex"12");
        _result(bytes.concat(hex"deadbeef", abi.encode(uint256(17)), hex"aa"));
        _result(abi.encodeWithSelector(RH.InvalidRecoveredHydrationProfile.selector));
    }

    function testFuzzResultPreservesBoundedOpaqueBytes(uint256 seed, uint8 length) public view {
        _result(_bytes(seed, uint256(length) % 97));
    }

    function _badFrame(bytes memory raw) private view {
        _expectProfile(abi.encodeCall(this.body, (raw)));
        _expectProfile(abi.encodeCall(this.requireSingle, (raw)));
    }

    function _expectProfile(bytes memory input) private view {
        (bool ok, bytes memory reason) = address(this).staticcall(input);
        assert(!ok);
        _same(reason, abi.encodeWithSelector(RH.InvalidRecoveredHydrationProfile.selector));
    }

    function _result(bytes memory raw) private view {
        _same(Tuple.result(true, raw), raw);
        (bool ok, bytes memory reason) =
            address(this).staticcall(abi.encodeCall(this.result, (false, raw)));
        assert(!ok);
        _same(reason, raw);
    }
}

/// @notice Pure Identity projections against the original feature and nonce equality rules.
/// @dev These synthetic bundles deliberately bypass source admission and structural validation.
contract StreamArtistRecoveredPreparationIdentityFactsTest is RecoveredPreparationTupleFixture {
    function features(IH.Bundle memory b, bool payout, uint256 eras)
        external pure returns (uint256, bool)
    {
        return Facts.features(b, payout, eras);
    }

    function originalFeatures(IH.Bundle memory b, bool payout, uint256 eras)
        external pure returns (uint256, bool)
    {
        return (_features(b, payout, eras), b.delegations.length != 0);
    }

    function nonces(IH.Bundle memory b, RH.NonceInventory[] memory n) external pure {
        Facts.nonces(b, n);
    }

    function originalNonces(IH.Bundle memory b, RH.NonceInventory[] memory n) external pure {
        if (b.nonces.length != n.length) revert RH.InvalidRecoveredHydrationProvenance();
        for (uint256 i; i < n.length; ++i) {
            if (
                b.nonces[i].kind != n[i].index.kind || b.nonces[i].key != n[i].index.key
                    || keccak256(abi.encode(b.nonces[i].words)) != keccak256(abi.encode(n[i].words))
            ) revert RH.InvalidRecoveredHydrationProvenance();
        }
    }

    function testFuzzTimingReturnsExactOriginalCheckpoint(uint256 seed, bytes32 salt) public pure {
        IH.Bundle memory b;
        b.timing.checkpoint = TM.Checkpoint(
            salt, uint16(seed), seed, bytes32(seed), keccak256(abi.encode(salt))
        );
        b.timing.entries = new TM.Entry[](1);
        b.timing.entries[0].commitment = keccak256("irrelevant timing row");
        b.timing.configuration.values[0] = uint64(seed);
        _same(abi.encode(Facts.timing(b)), abi.encode(b.timing.checkpoint));
    }

    function testFuzzFeatureAndDelegationProjectionsMatchOriginal(uint256 seed, bool payout)
        public pure
    {
        IH.Bundle memory b;
        b.identity.authorityClass = (seed & 1) == 0 ? 1 : 3;
        b.recoveries = new IH.RecoveryRow[](2);
        b.recoveries[0].record.fields.vestedAuthorityClass = (seed & 2) == 0 ? 1 : 3;
        b.recoveries[1].record.fields.vestedAuthorityClass = (seed & 4) == 0 ? 1 : 3;
        b.actions = new IH.ActionRow[](2);
        if ((seed & 8) != 0) b.actions[0].evidenceV2.manifestHash = bytes32(uint256(1));
        if ((seed & 16) != 0) b.actions[1].evidenceV3.manifestHash = bytes32(uint256(2));
        b.revisionContinuations = new IH.RevisionContinuationRow[]((seed & 32) == 0 ? 0 : 1);
        b.standingContinuations = new IH.StandingContinuationRow[]((seed & 64) == 0 ? 0 : 1);
        b.capabilityContinuations = new IH.CapabilityContinuationRow[]((seed & 128) == 0 ? 0 : 1);
        b.delegations = new IH.DelegationRow[]((seed & 256) == 0 ? 0 : 2);
        b.originalContinuations = new IH.OriginalContinuationRow[]((seed & 512) == 0 ? 0 : 1);
        uint256 eras = 1 + (seed >> 16) % 16;
        (uint256 actual, bool hasDelegations) = Facts.features(b, payout, eras);
        assert(actual == _features(b, payout, eras));
        assert(hasDelegations == (b.delegations.length != 0));
    }

    function testFuzzFeatureFailureParity(uint8 current, uint8 historical, uint256 eras)
        public view
    {
        IH.Bundle memory b;
        b.identity.authorityClass = current;
        b.recoveries = new IH.RecoveryRow[](1);
        b.recoveries[0].record.fields.vestedAuthorityClass = historical;
        _featureParity(b, false, eras);
    }

    function testOriginalContinuationAloneDoesNotAdvertiseV2OrV3() public pure {
        IH.Bundle memory b;
        b.identity.authorityClass = 3;
        b.originalContinuations = new IH.OriginalContinuationRow[](1);
        b.originalContinuations[0].continuation.continuationHash = keccak256("original op58");
        (uint256 value, bool delegated) = Facts.features(b, false, 1);
        assert(value == 2 && !delegated);
    }

    function testFeatureClassRejectionPrecedesEraRejection() public view {
        IH.Bundle memory b;
        b.recoveries = new IH.RecoveryRow[](1);
        b.recoveries[0].record.fields.vestedAuthorityClass = 2;
        _featureReject(b, 0, T.UnsupportedProfile.selector);
        b.identity.authorityClass = 1;
        _featureReject(b, 17, T.UnsupportedProfile.selector);
        b.recoveries[0].record.fields.vestedAuthorityClass = 3;
        _featureReject(b, 0, RH.InvalidRecoveredHydrationProfile.selector);
        _featureReject(b, 17, RH.InvalidRecoveredHydrationProfile.selector);
    }

    function testFuzzNonceEqualityMatchesOriginal(uint256 seed, uint8 lanes, uint8 words)
        public view
    {
        (IH.Bundle memory b, RH.NonceInventory[] memory n) =
            _nonceFixture(seed, uint256(lanes) % 3, uint256(words) % 3);
        _nonceParity(b, n, true);
        // The original equality checks words, kind and key. Source shape validation separately
        // authenticates prefixCount; the Identity lane's allocation hint is not compared here.
        for (uint256 i; i < n.length; ++i) {
            n[i].index.prefixCount = type(uint256).max;
            b.nonces[i].hint = ~seed;
        }
        _nonceParity(b, n, true);
    }

    function testNonceShapeOrderPrefixExhaustionAndEveryWordMismatch() public view {
        for (uint8 fault; fault < 40; ++fault) _nonceMismatch(93, fault);
    }

    function testFuzzNonceMismatchMatchesOriginal(uint256 seed, uint8 fault) public view {
        _nonceMismatch(seed, fault % 40);
    }

    function _nonceMismatch(uint256 seed, uint8 fault) private view {
        (IH.Bundle memory b, RH.NonceInventory[] memory n) = _nonceFixture(seed, 2, 2);
        uint256 lane = seed % 2;
        uint256 word = (seed >> 8) % 2;
        if (fault == 0) n = new RH.NonceInventory[](1);
        else if (fault == 1) n[lane].index.kind ^= 1;
        else if (fault == 2) n[lane].index.key ^= bytes32(uint256(1));
        else if (fault == 3) (n[0], n[1]) = (n[1], n[0]);
        else if (fault == 4) n[lane].words = new AH.NonceWord[](1);
        else if (fault == 5) {
            (n[lane].words[0], n[lane].words[1]) = (n[lane].words[1], n[lane].words[0]);
        }
        else if (fault == 6) n[lane].words[word].prefix ^= 1;
        else if (fault == 7) n[lane].words[word].exhausted = !n[lane].words[word].exhausted;
        else n[lane].words[word].words[uint256(fault) - 8] ^= 1;
        _nonceParity(b, n, false);
    }

    function _nonceParity(IH.Bundle memory b, RH.NonceInventory[] memory n, bool succeeds)
        private view
    {
        (bool actualOK, bytes memory actual) =
            address(this).staticcall(abi.encodeCall(this.nonces, (b, n)));
        (bool oldOK, bytes memory old) =
            address(this).staticcall(abi.encodeCall(this.originalNonces, (b, n)));
        assert(actualOK == succeeds && oldOK == succeeds);
        _same(actual, old);
        if (!succeeds) {
            _same(actual, abi.encodeWithSelector(RH.InvalidRecoveredHydrationProvenance.selector));
        }
    }

    function _featureParity(IH.Bundle memory b, bool payout, uint256 eras) private view {
        (bool actualOK, bytes memory actual) =
            address(this).staticcall(abi.encodeCall(this.features, (b, payout, eras)));
        (bool oldOK, bytes memory old) =
            address(this).staticcall(abi.encodeCall(this.originalFeatures, (b, payout, eras)));
        assert(actualOK == oldOK);
        _same(actual, old);
    }

    function _featureReject(IH.Bundle memory b, uint256 eras, bytes4 expected) private view {
        _featureParity(b, true, eras);
        (bool ok, bytes memory reason) =
            address(this).staticcall(abi.encodeCall(this.features, (b, true, eras)));
        assert(!ok);
        _same(reason, abi.encodeWithSelector(expected));
    }

    function _features(IH.Bundle memory b, bool payout, uint256 eras)
        private pure returns (uint256 value)
    {
        value = _class(b.identity.authorityClass);
        for (uint256 i; i < b.recoveries.length; ++i) {
            value |= _class(b.recoveries[i].record.fields.vestedAuthorityClass);
        }
        for (uint256 i; i < b.actions.length; ++i) {
            if (b.actions[i].evidenceV2.manifestHash != 0) value |= 4;
            if (b.actions[i].evidenceV3.manifestHash != 0) value |= 8;
        }
        if (
            b.revisionContinuations.length != 0 || b.standingContinuations.length != 0
                || b.capabilityContinuations.length != 0 || payout
        ) value |= 8;
        if (eras > 1) value |= 16;
        if (eras == 0 || eras > 16) revert RH.InvalidRecoveredHydrationProfile();
    }

    function _class(uint8 value) private pure returns (uint256) {
        if (value == 1) return 1;
        if (value == 3) return 2;
        revert T.UnsupportedProfile();
    }
}
