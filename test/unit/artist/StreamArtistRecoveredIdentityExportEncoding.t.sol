// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { RecoveredPreparationTupleFixture } from "./StreamArtistRecoveredPreparationTuple.t.sol";
import {
    StreamArtistRecoveredIdentityExportEncoding as Encoding
} from "../../../smart-contracts/domains/artist/StreamArtistRecoveredIdentityExportEncoding.sol";
import {
    StreamArtistRecoveredIdentityHydrationTypes as IH
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistRecoveredIdentityHydrationTypes.sol";
import {
    StreamArtistRecoveredHydrationTypes as RH
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistRecoveredHydrationTypes.sol";

/// @notice Compiler-generated typed ABI is the oracle for all 34 fields and row framing.
/// @dev Synthetic values establish encoding parity, not export reads or source authentication.
contract StreamArtistRecoveredIdentityExportEncodingTest is RecoveredPreparationTupleFixture {
    function testJoinAndSplitEveryEmptyFieldMatchesTypedABI() public pure {
        _checkBundle(_identity(0, false));
    }

    function testJoinAndSplitEveryPopulatedFieldMatchesTypedABI() public pure {
        _checkBundle(_identity(64, true));
        _checkBundle(_identity(type(uint64).max, true));
    }

    function testFuzzJoinAndSplitEveryFieldMatchesTypedABI(uint64 seed) public pure {
        // The complete fixture has bounded row counts and byte strings of at most 65 bytes.
        _checkBundle(_identity(seed, true));
    }

    function testReplaceAllFourContinuationsWithDifferentRowsAndLengths() public pure {
        // Counts 2, 0, 3, 1 differ independently from the original one-row arrays.
        _checkReplacement(6529, 114);
    }

    function testReplaceAllFourContinuationsWithEmptyArrays() public pure {
        _checkReplacement(32, 0);
    }

    function testFuzzReplaceAllFourContinuations(uint64 seed, uint8 counts) public pure {
        // Each two-bit count is independently bounded to zero through three rows.
        _checkReplacement(seed, counts);
    }

    function testEmptyDynamicAndStaticRowArraysMatchTypedABI() public pure {
        _checkArrays(0, 0, 0);
    }

    function testMultirowArraysPreserveOrderAndWordBoundaryLengths() public pure {
        uint256[6] memory lengths = [uint256(0), 1, 31, 32, 33, 65];
        for (uint256 i; i < lengths.length; ++i) {
            _checkArrays(6529, 3, lengths[i]);
        }
    }

    function testFuzzDynamicAndStaticRowArraysMatchTypedABI(
        uint64 seed,
        uint8 countHint,
        uint8 lengthHint
    ) public pure {
        _checkArrays(seed, uint256(countHint) % 4, uint256(lengthHint) % 66);
    }

    function _checkBundle(IH.Bundle memory b) private pure {
        bytes memory canonical = abi.encode(b);
        bytes[34] memory expected = _fields(b);
        _same(Encoding.join(expected), canonical);
        bytes[34] memory actual = Encoding.split(canonical);
        for (uint256 i; i < 34; ++i) {
            _same(actual[i], expected[i]);
        }
        // The helper must not mutate its encoded inputs as it reads their nested offsets.
        _same(canonical, abi.encode(b));
        bytes[34] memory unchanged = _fields(b);
        for (uint256 i; i < 34; ++i) {
            _same(expected[i], unchanged[i]);
        }
    }

    function _checkReplacement(uint64 seed, uint8 counts) private pure {
        IH.Bundle memory original = _identity(seed, true);
        bytes memory canonical = abi.encode(original);
        bytes[34] memory beforeFields = _fields(original);
        // Independent allocation prevents replacements from also changing the original oracle.
        IH.Bundle memory expected = _identity(seed, true);
        _continuations(expected, seed, counts);
        bytes memory fourArrays = abi.encode(
            expected.originalContinuations,
            expected.revisionContinuations,
            expected.standingContinuations,
            expected.capabilityContinuations
        );
        bytes memory wanted = abi.encode(expected);
        bytes memory actual = Encoding.replaceContinuations(canonical, fourArrays);
        _same(actual, wanted);
        bytes[34] memory afterFields = Encoding.split(actual);
        bytes[34] memory wantedFields = _fields(expected);
        for (uint256 i; i < 34; ++i) {
            _same(afterFields[i], wantedFields[i]);
            if (i < 30) _same(afterFields[i], beforeFields[i]);
            else assert(keccak256(afterFields[i]) != keccak256(beforeFields[i]));
        }
        _same(canonical, abi.encode(original));
        _same(
            fourArrays,
            abi.encode(
                expected.originalContinuations,
                expected.revisionContinuations,
                expected.standingContinuations,
                expected.capabilityContinuations
            )
        );
    }

    function _continuations(IH.Bundle memory b, uint64 seed, uint8 counts) private pure {
        b.originalContinuations = new IH.OriginalContinuationRow[](counts & 3);
        b.revisionContinuations = new IH.RevisionContinuationRow[]((counts >> 2) & 3);
        b.standingContinuations = new IH.StandingContinuationRow[]((counts >> 4) & 3);
        b.capabilityContinuations = new IH.CapabilityContinuationRow[]((counts >> 6) & 3);
        for (uint256 i; i < b.originalContinuations.length; ++i) {
            bytes32 key = keccak256(abi.encode("replacement original", seed, i));
            b.originalContinuations[i].point = RH.Point(key, 1, uint64(uint256(seed) + i));
            b.originalContinuations[i].continuation.continuationHash = key;
            b.originalContinuations[i].continuation.stableDocumentHash = bytes32(i + 1);
        }
        for (uint256 i; i < b.revisionContinuations.length; ++i) {
            bytes32 key = keccak256(abi.encode("replacement revision", seed, i));
            b.revisionContinuations[i].point = RH.Point(key, 2, uint64(uint256(seed) + i));
            b.revisionContinuations[i].continuation.continuationHash = key;
            b.revisionContinuations[i].continuation.ownerRevision = uint64(i + 1);
        }
        for (uint256 i; i < b.standingContinuations.length; ++i) {
            bytes32 key = keccak256(abi.encode("replacement standing", seed, i));
            b.standingContinuations[i].point = RH.Point(key, 3, uint64(uint256(seed) + i));
            b.standingContinuations[i].continuation.priorAddress = address(uint160(i + 100));
            b.standingContinuations[i].continuation.continuationHash = key;
            b.standingContinuations[i].scopeHead = keccak256(abi.encode(key, "head"));
        }
        for (uint256 i; i < b.capabilityContinuations.length; ++i) {
            bytes32 key = keccak256(abi.encode("replacement capability", seed, i));
            b.capabilityContinuations[i].point = RH.Point(key, 4, uint64(uint256(seed) + i));
            b.capabilityContinuations[i].continuation.commitment = key;
            b.capabilityContinuations[i].continuation.effectiveCapabilities = uint32(seed);
            b.capabilityContinuations[i].continuation.authorityAddress = address(uint160(i + 200));
        }
    }

    function _checkArrays(uint64 seed, uint256 count, uint256 length) private pure {
        IH.DocumentRow[] memory documents = new IH.DocumentRow[](count);
        IH.NonceLane[] memory nonces = new IH.NonceLane[](count);
        IH.ActionRow[] memory actions = new IH.ActionRow[](count);
        IH.StandingRow[] memory standing = new IH.StandingRow[](count);
        IH.OriginalContinuationRow[] memory continuations = new IH.OriginalContinuationRow[](count);
        bytes[] memory encoded = new bytes[](count);
        for (uint256 i; i < count; ++i) {
            uint256 rowSeed = uint256(seed) + i;
            bytes32 key = keccak256(abi.encode("array row", seed, i));
            documents[i] = IH.DocumentRow(key, _bytes(rowSeed, (length + 17 * i) % 66));
            nonces[i].kind = uint8(i + 1);
            nonces[i].key = key;
            nonces[i].hint = rowSeed;
            nonces[i].words = _words(rowSeed, i, rowSeed % 3);
            actions[i].point = RH.Point(key, uint8(i), uint64(rowSeed));
            actions[i].restoredGuardian.terms.guardians = new address[](i);
            actions[i].excludedMemberships = new uint64[](count - i);
            for (uint256 j; j < i; ++j) {
                actions[i].restoredGuardian.terms.guardians[j] = address(uint160(rowSeed + j));
            }
            for (uint256 j; j < count - i; ++j) {
                actions[i].excludedMemberships[j] = uint64(rowSeed + j);
            }
            actions[i].evidenceV3.manifestHash = key;
            standing[i].account = address(uint160(rowSeed));
            standing[i].retirement = key;
            standing[i].judgment.dismissalRecordHash = keccak256(abi.encode(key, "judgment"));
            continuations[i].point = RH.Point(key, uint8(i), uint64(rowSeed));
            continuations[i].continuation.continuationHash = key;
            continuations[i].continuation.stableDocumentHash = bytes32(rowSeed);
        }
        for (uint256 i; i < count; ++i) {
            encoded[i] = abi.encode(documents[i]);
        }
        _same(Encoding.array(encoded, true), abi.encode(documents));
        for (uint256 i; i < count; ++i) {
            encoded[i] = abi.encode(nonces[i]);
        }
        _same(Encoding.array(encoded, true), abi.encode(nonces));
        for (uint256 i; i < count; ++i) {
            encoded[i] = abi.encode(actions[i]);
        }
        _same(Encoding.array(encoded, true), abi.encode(actions));
        for (uint256 i; i < count; ++i) {
            encoded[i] = abi.encode(standing[i]);
        }
        _same(Encoding.array(encoded, false), abi.encode(standing));
        for (uint256 i; i < count; ++i) {
            encoded[i] = abi.encode(continuations[i]);
        }
        _same(Encoding.array(encoded, false), abi.encode(continuations));
    }

    // This is an explicit typed oracle; it does not use the helper's widths or offset arithmetic.
    function _fields(IH.Bundle memory b) private pure returns (bytes[34] memory fields) {
        fields[0] = abi.encode(b.artistId);
        fields[1] = abi.encode(b.sourceSnapshot);
        fields[2] = abi.encode(b.nextRegistrationNonce);
        fields[3] = abi.encode(b.identity);
        fields[4] = abi.encode(b.identityDocument);
        fields[5] = abi.encode(b.documents);
        fields[6] = abi.encode(b.heads);
        fields[7] = abi.encode(b.timing);
        fields[8] = abi.encode(b.signatures);
        fields[9] = abi.encode(b.nonces);
        fields[10] = abi.encode(b.revisions);
        fields[11] = abi.encode(b.delegations);
        fields[12] = abi.encode(b.guardians);
        fields[13] = abi.encode(b.memberships);
        fields[14] = abi.encode(b.rotations);
        fields[15] = abi.encode(b.contests);
        fields[16] = abi.encode(b.causes);
        fields[17] = abi.encode(b.dismissals);
        fields[18] = abi.encode(b.closures);
        fields[19] = abi.encode(b.standing);
        fields[20] = abi.encode(b.standingRecords);
        fields[21] = abi.encode(b.recoveries);
        fields[22] = abi.encode(b.vestings);
        fields[23] = abi.encode(b.actions);
        fields[24] = abi.encode(b.designations);
        fields[25] = abi.encode(b.directives);
        fields[26] = abi.encode(b.sanctionGrants);
        fields[27] = abi.encode(b.estates);
        fields[28] = abi.encode(b.notices);
        fields[29] = abi.encode(b.findings);
        fields[30] = abi.encode(b.originalContinuations);
        fields[31] = abi.encode(b.revisionContinuations);
        fields[32] = abi.encode(b.standingContinuations);
        fields[33] = abi.encode(b.capabilityContinuations);
    }
}
