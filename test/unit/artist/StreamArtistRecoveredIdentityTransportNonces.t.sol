// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    StreamArtistRecoveredIdentityTransportNonces as Nonces
} from "../../../smart-contracts/domains/artist/StreamArtistRecoveredIdentityTransportNonces.sol";
import {
    StreamArtistHydrationGuards as Guards
} from "../../../smart-contracts/domains/artist/StreamArtistHydrationGuards.sol";
import {
    StreamArtistRecoveredIdentityHydrationTypes as IH
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistRecoveredIdentityHydrationTypes.sol";
import {
    StreamArtistRecoveredHydrationTypes as RH
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistRecoveredHydrationTypes.sol";
import {
    StreamArtistAuthorityHydrationTypes as AH
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistAuthorityHydration.sol";
import {
    StreamArtistOnboardingTypes as T
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistOnboardingTypes.sol";
import {
    StreamArtistRecoveredTimingTypes as TM
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistRecoveredTimingTypes.sol";

interface RecoveredIdentityTransportNonceVm {
    function store(address target, bytes32 slot, bytes32 value) external;
    function mockCallRevert(address target, bytes calldata input, bytes calldata reason) external;
    function clearMockedCalls() external;
}

/// @dev Complete synthetic fixtures copied from RecoveredPreparationTupleFixture.
/// This independent source closure excludes the exporter and importer under active development.
abstract contract RecoveredIdentityTransportNonceFixture {
    RecoveredIdentityTransportNonceVm internal constant vm =
        RecoveredIdentityTransportNonceVm(address(uint160(uint256(keccak256("hevm cheat code")))));
    bytes32 internal constant GUARDS_SLOT =
        keccak256("6529STREAM_ARTIST_AUTHORITY_HYDRATION_STORAGE_V1");
    bytes32 internal constant VALUE = keccak256("owner guard commitment");
    bytes32 internal constant COMPLETE = keccak256("transport boundary completed");

    error StageReached(uint256 stage);

    function _setCommitment(bytes32 value) internal {
        vm.store(address(this), GUARDS_SLOT, value);
    }

    function _reverted(bool ok, bytes memory actual, bytes memory expected) internal pure {
        assert(!ok);
        _same(actual, expected);
    }

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
}

/// @notice Genuine nonce-worker execution against the original typed comparison algorithm.
/// @dev Full synthetic Bundle fixtures do not authenticate source state or prove operation60.
/// The oracle uses calldata only to avoid an unrelated full memory decoder; its checks and
/// their order are the original Transport algorithm, with no projected nonce fields omitted.
contract StreamArtistRecoveredIdentityTransportNoncesTest is
    RecoveredIdentityTransportNonceFixture
{
    function checked(bytes calldata canonical, RH.NonceInventory[] calldata nonces, bytes32 value)
        external
        view
        returns (bytes32)
    {
        Nonces.validate(canonical, nonces, value);
        return COMPLETE;
    }

    function original(IH.Bundle calldata bundle, RH.NonceInventory[] calldata nonces, bytes32 value)
        external
        view
        returns (bytes32)
    {
        if (bundle.nonces.length != nonces.length || Guards.commitment() != value) {
            revert RH.InvalidRecoveredHydrationProvenance();
        }
        for (uint256 i; i < bundle.nonces.length; ++i) {
            if (
                bundle.nonces[i].kind != nonces[i].index.kind
                    || bundle.nonces[i].key != nonces[i].index.key
                    || keccak256(abi.encode(bundle.nonces[i].words))
                        != keccak256(abi.encode(nonces[i].words))
            ) revert RH.InvalidRecoveredHydrationProvenance();
        }
        return COMPLETE;
    }

    function _parity(IH.Bundle memory b, RH.NonceInventory[] memory n, bytes32 value, bool valid)
        private
        view
    {
        (bool oldOk, bytes memory oldResult) =
            address(this).staticcall(abi.encodeCall(this.original, (b, n, value)));
        (bool newOk, bytes memory newResult) =
            address(this).staticcall(abi.encodeCall(this.checked, (abi.encode(b), n, value)));
        assert(oldOk == valid && newOk == oldOk);
        _same(newResult, oldResult);
        _same(
            newResult,
            valid
                ? abi.encode(COMPLETE)
                : abi.encodeWithSelector(RH.InvalidRecoveredHydrationProvenance.selector)
        );
    }

    function testFullBundleNonceParityAndOwnerStorageContext() public {
        _setCommitment(VALUE);
        vm.store(address(Nonces), GUARDS_SLOT, bytes32(uint256(9)));
        vm.store(address(Guards), GUARDS_SLOT, bytes32(uint256(10)));
        IH.Bundle memory b = _identity(91, true);
        (, RH.NonceInventory[] memory n) = _nonceFixture(91, 2, 2);
        _parity(b, n, VALUE, true);
        _parity(b, n, bytes32(uint256(9)), false);
        // These are intentionally not part of the original cross-certificate equality.
        b.nonces[0].hint ^= 1;
        n[0].index.prefixCount += 1;
        _parity(b, n, VALUE, true);
    }

    function testFuzzNonceParityCompleteWords(uint64 seed, uint8 change, uint8 word) public {
        _setCommitment(VALUE);
        IH.Bundle memory b = _identity(seed, true);
        (, RH.NonceInventory[] memory n) = _nonceFixture(seed, 2, 2);
        _parity(b, n, VALUE, true);
        uint256 mutation = change % 8;
        if (mutation == 0) {
            n = new RH.NonceInventory[](1);
        } else if (mutation == 1) {
            n[0].index.kind ^= 1;
        } else if (mutation == 2) {
            n[1].index.key ^= bytes32(uint256(1));
        } else if (mutation == 3) {
            n[1].words[0].prefix ^= 1;
        } else if (mutation == 4) {
            n[0].words[1].exhausted = !n[0].words[1].exhausted;
        } else if (mutation == 5) {
            n[1].words[1].words[word % 32] ^= 1;
        } else if (mutation == 6) {
            n[0].words = new AH.NonceWord[](1);
        } else {
            RH.NonceInventory memory first = n[0];
            n[0] = n[1];
            n[1] = first;
        }
        _parity(b, n, VALUE, false);
    }

    function testEmptyNonceParityStillRequiresGuardCommitment() public {
        IH.Bundle memory b = _identity(7, true);
        b.nonces = new IH.NonceLane[](0);
        RH.NonceInventory[] memory n = new RH.NonceInventory[](0);
        _setCommitment(VALUE);
        _parity(b, n, VALUE, true);
        _parity(b, n, bytes32(0), false);
    }

    function testNonceCountShortCircuitsGuardAndGuardPrecedesRows() public {
        IH.Bundle memory b = _identity(23, true);
        (, RH.NonceInventory[] memory n) = _nonceFixture(23, 2, 2);
        bytes memory trap = abi.encodeWithSelector(StageReached.selector, 2);
        vm.mockCallRevert(address(Guards), abi.encodeWithSelector(Guards.commitment.selector), trap);
        (bool ok, bytes memory reason) = address(this)
            .staticcall(
                abi.encodeCall(this.checked, (abi.encode(b), new RH.NonceInventory[](0), VALUE))
            );
        _reverted(
            ok, reason, abi.encodeWithSelector(RH.InvalidRecoveredHydrationProvenance.selector)
        );
        n[0].index.kind ^= 1;
        (ok, reason) =
            address(this).staticcall(abi.encodeCall(this.checked, (abi.encode(b), n, VALUE)));
        _reverted(ok, reason, trap);
        vm.clearMockedCalls();
    }
}
