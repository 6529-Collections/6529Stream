// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    StreamArtistRecoveryRewindSelectionScan as Scan
} from "../../../smart-contracts/domains/artist/StreamArtistRecoveryRewindSelectionScan.sol";
import {
    StreamArtistRecoveryRewindSelectionState as Store
} from "../../../smart-contracts/domains/artist/StreamArtistRecoveryRewindSelectionState.sol";
import {
    StreamArtistRecoveryRewindRecordReads as Records
} from "../../../smart-contracts/domains/artist/StreamArtistRecoveryRewindRecordReads.sol";
import {
    StreamArtistRecoveryRewindTypes as W
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistRecoveryRewindTypes.sol";
import {
    StreamArtistOnboardingTypes as T
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistOnboardingTypes.sol";
import {
    StreamArtistGuardianHistoryTypes as GH
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistGuardianHistoryTypes.sol";
import {
    IStreamArtistIdentityRecoveryOwnerV3
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistIdentityRecoveryV3.sol";

/// @dev Exact finish and six private bodies from Scan at
/// 297a69c2516e65594b87129c30245e9a014251d5; no live worker is used as its oracle.
library RewindFinishFrozenOriginal {
    function finish(Store.State storage s, bytes32 key) public {
        W.BasisV3 memory b = s.bases[key];
        W.ProgressV3 storage p = s.progress[key];
        if (
            p.identityProcessed != b.identity.identity.receiptCount
                || p.payoutProcessed != b.payout.receiptCount
                || p.guardiansProcessed != b.identity.guardianHistory.count
                || s.guardianTip[key] != b.identity.guardianHistory.commitment
                || s.guardianRevision[key] != b.identity.guardianHistory.ownerRevision
                || p.seenExclusions != (uint256(1) << s.excluded[key].length) - 1
        ) revert W.InvalidRecoveryRewindSelection(key);
        W.ResultV3 storage result = s.results[key];
        result.sourceKey = key;
        result.manifestHash = b.identity.manifestHash;
        result.sourceCommitment = b.sourceCommitment;
        result.inventoryCommitment =
            W.selectionInventoryHash(s.environments[key], b.identity.inventory, b.payoutInventory);
        _nonceResult(
            s,
            key,
            W.RecordKind.SUCCESSOR_DESIGNATION,
            b.identity.inventory.designations,
            result.designation
        );
        _nonceResult(
            s, key, W.RecordKind.ESTATE_DIRECTIVE, b.identity.inventory.directives, result.directive
        );
        _nonceResult(
            s,
            key,
            W.RecordKind.STEWARD_SANCTION_GRANT,
            b.identity.inventory.sanctionGrants,
            result.sanctionGrant
        );
        _chainResult(
            s,
            key,
            W.RecordKind.IDENTITY_REVISION,
            b.identity.inventory.revisions,
            result.identityRevision
        );
        _chainResult(
            s,
            key,
            W.RecordKind.PAYOUT_DESIGNATION,
            W.FamilyPointers(
                b.payoutInventory.stable.recordHash, b.payoutInventory.candidate.recordHash
            ),
            result.payout
        );
        _payoutPointers(s, key, b.payoutInventory);
        _sourcePointer(s, key, W.RecordKind.GUARDIAN_SET, b.identity.inventory.guardians.stable);
        _sourcePointer(s, key, W.RecordKind.GUARDIAN_SET, b.identity.inventory.guardians.candidate);
        _paired(s, key, result.designation.operative.recordHash);
        // Retaining an ineligible candidate also retains its original dependency. It may
        // mature later, so an excluded paired directive cannot be hidden behind that candidate.
        _paired(s, key, result.designation.retainedCandidateRecordHash);
        _standingResult(s, key);
        result.guardians.sourceKey = key;
        result.guardians.commitment = keccak256(
            abi.encode(
                keccak256("6529STREAM_ARTIST_RECOVERY_REWIND_GUARDIAN_RESULT_V3"),
                uint16(3),
                s.environments[key],
                b.identity.guardianHistory,
                key,
                result.guardians.selectedRecordHash,
                result.guardians.selectedDataHash,
                result.guardians.selectedNonce
            )
        );
        // The empty case still requires this explicit successful finalization write.
        result.commitment = W.selectionResultHash(s.environments[key], result);
        p.resultCommitment = result.commitment;
        p.complete = true;
    }

    function _nonceResult(
        Store.State storage s,
        bytes32 key,
        W.RecordKind kind,
        W.FamilyPointers memory pointers,
        W.FamilySelectionV3 storage result
    ) private {
        _sourcePointer(s, key, kind, pointers.stable);
        _sourcePointer(s, key, kind, pointers.candidate);
        if (
            pointers.candidate != 0 && s.retained[key][pointers.candidate]
                && !s.records[key][pointers.candidate].eligible
        ) {
            result.retainedCandidateRecordHash = pointers.candidate;
        }
        result.branchCommitment = keccak256(
            abi.encode(
                keccak256("6529STREAM_ARTIST_RECOVERY_REWIND_FAMILY_V3"),
                key,
                kind,
                pointers,
                s.familyCommitments[key][kind],
                result.operative,
                result.retainedCandidateRecordHash
            )
        );
    }

    function _chainResult(
        Store.State storage s,
        bytes32 key,
        W.RecordKind kind,
        W.FamilyPointers memory pointers,
        W.FamilySelectionV3 storage result
    ) private {
        _sourcePointer(s, key, kind, pointers.stable);
        _sourcePointer(s, key, kind, pointers.candidate);
        bytes32 tip = pointers.candidate != 0 ? pointers.candidate : pointers.stable;
        bytes32 selected = s.chainFallback[key][tip];
        if (selected != 0) result.operative = s.records[key][selected].selected;
        if (
            pointers.candidate != 0 && s.retained[key][pointers.candidate]
                && !s.records[key][pointers.candidate].eligible
        ) {
            result.retainedCandidateRecordHash = pointers.candidate;
        }
        result.branchCommitment = keccak256(
            abi.encode(
                keccak256("6529STREAM_ARTIST_RECOVERY_REWIND_BRANCH_V3"),
                key,
                kind,
                pointers,
                s.familyCommitments[key][kind],
                s.branchCommitments[key][tip],
                result.operative,
                result.retainedCandidateRecordHash
            )
        );
    }

    function _sourcePointer(Store.State storage s, bytes32 key, W.RecordKind kind, bytes32 hash)
        private
        view
    {
        if (
            hash != 0
                && (!s.admitted[key][hash]
                    || s.kinds[key][hash] != kind
                    || s.previouslySuperseded[key][hash])
        ) revert W.InvalidRecoveryRewindSelection(key);
    }

    function _payoutPointers(Store.State storage s, bytes32 key, W.PayoutInventoryV3 memory p)
        private
        view
    {
        if (p.stable.recordHash == 0
                ? p.stable.account != address(0)
                : s.records[key][p.stable.recordHash].account != p.stable.account) revert W.InvalidRecoveryRewindSelection(key);
        if (p.candidate.recordHash == 0
                ? p.candidate.account != address(0)
                : s.records[key][p.candidate.recordHash].account != p.candidate.account) revert W.InvalidRecoveryRewindSelection(key);
    }

    function _paired(Store.State storage s, bytes32 key, bytes32 designation) private view {
        if (designation == 0) return;
        bytes32 paired = s.records[key][designation].pairedDirective;
        if (
            paired != 0
                && (!s.admitted[key][paired]
                    || s.kinds[key][paired] != W.RecordKind.ESTATE_DIRECTIVE
                    || !s.retained[key][paired])
        ) {
            revert W.InvalidRecoveryRewindSelection(key);
        }
        // Class3 eligibility is a stronger context rule; class1 preserves originally admitted pairs.
    }

    function _standingResult(Store.State storage s, bytes32 key) private {
        Store.StandingScope[] memory scopes = s.standingScopes[key];
        for (uint256 i = 1; i < scopes.length; ++i) {
            Store.StandingScope memory item = scopes[i];
            uint256 j = i;
            while (
                j > 0
                    && (scopes[j - 1].account > item.account
                        || (scopes[j - 1].account == item.account
                            && scopes[j - 1].retirement > item.retirement))
            ) {
                scopes[j] = scopes[j - 1];
                --j;
            }
            scopes[j] = item;
        }
        for (uint256 i; i < scopes.length; ++i) {
            Store.StandingScope memory scope = scopes[i];
            (bytes32 current, bytes32 raw, bytes32 judgment, bytes32 continuation) = IStreamArtistIdentityRecoveryOwnerV3(
                    s.environments[key].identityOwner
                ).recoveryStandingScopeV3(s.bases[key].identity.artistId, scope.account);
            bytes32 selected =
                s.standingWinners[key][keccak256(abi.encode(scope.account, scope.retirement))];
            W.SelectedRecordV3 memory retained;
            if (selected != 0) retained = s.records[key][selected].selected;
            // A historical scope binds the raw pointer but must not replace the current retirement.
            s.results[key].standing
                .push(
                    W.StandingSelectionV3(
                        scope.account,
                        scope.retirement,
                        raw,
                        retained,
                        judgment,
                        current == scope.retirement ? continuation : bytes32(0)
                    )
                );
        }
    }
}

error FinishStandingFailure(address account);
error FinishStandingWrongCaller(address caller);

/// @dev Explicit fixed-owner read boundary, not an original Artist admission producer.
contract RewindFinishStandingProbe {
    address private _host;
    address private _failAccount;

    function setHost(address host) external {
        _host = host;
    }

    function setFailure(address account) external {
        _failAccount = account;
    }

    function recoveryStandingScopeV3(bytes32 artistId, address account)
        external
        view
        returns (bytes32 current, bytes32 raw, bytes32 judgment, bytes32 continuation)
    {
        if (msg.sender != _host) revert FinishStandingWrongCaller(msg.sender);
        if (account == _failAccount) revert FinishStandingFailure(account);
        require(artistId == bytes32(uint256(77)), "original artist scope");
        require(account == address(0x10) || account == address(0x20), "seeded standing account");
        uint256 n = account == address(0x10) ? 20 : 30;
        return (bytes32(n), bytes32(n + 100), bytes32(n + 200), bytes32(n + 300));
    }
}

/// @dev Two separate declared State roots. Setters seed synthetic completed-scan
/// facts only; they do not claim original journals, admission, or a full selection flow.
contract RewindFinishComparisonHost {
    bytes32 private _before = keccak256("before actual State root");
    Store.State private _actual;
    bytes32 private _between = keccak256("between independent State roots");
    Store.State private _original;
    bytes32 private _after = keccak256("after reference State root");
    address private immutable _owner;

    constructor(address owner) {
        _owner = owner;
    }

    function seed(bytes32 key, bool populated) external {
        _seed(_actual, key, populated);
        _seed(_original, key, populated);
    }

    function fault(bytes32 key, uint256 variant) external {
        _fault(_actual, key, variant);
        _fault(_original, key, variant);
    }

    function repair(bytes32 key, uint256 variant) external {
        _repair(_actual, key, variant);
        _repair(_original, key, variant);
    }

    function run(bool original, bytes32 key)
        external
        returns (W.ResultV3 memory, W.ProgressV3 memory)
    {
        if (original) {
            RewindFinishFrozenOriginal.finish(_original, key);
            return (_original.results[key], _original.progress[key]);
        }
        Scan.finish(_actual, key);
        return (_actual.results[key], _actual.progress[key]);
    }

    function state(bool original, bytes32 key)
        external
        view
        returns (W.ResultV3 memory, W.ProgressV3 memory)
    {
        Store.State storage s = original ? _original : _actual;
        return (s.results[key], s.progress[key]);
    }

    function basis(bytes32 key) external view returns (W.EnvironmentV3 memory, W.BasisV3 memory) {
        return (_actual.environments[key], _actual.bases[key]);
    }

    function readOnlyHash(bool original, bytes32 key) public view returns (bytes32 hash) {
        Store.State storage s = original ? _original : _actual;
        hash = keccak256(
            abi.encode(
                _before,
                _between,
                _after,
                s.environments[key],
                s.bases[key],
                s.seals[key],
                s.excluded[key],
                s.guardianTip[key],
                s.guardianRevision[key],
                s.originalRevisionContinuation[key],
                s.standingScopes[key],
                s.manifestKeys[s.bases[key].identity.manifestHash]
            )
        );
        // Enumerate every record/mapping key addressed by this bounded fixture,
        // including rejected pairs, exclusions, and unused canary record 18.
        for (uint256 i = 1; i <= 18; ++i) {
            bytes32 h = bytes32(i);
            hash = keccak256(
                abi.encode(
                    hash,
                    s.records[key][h],
                    s.kinds[key][h],
                    s.admitted[key][h],
                    s.retained[key][h],
                    s.previouslySuperseded[key][h],
                    s.excludedIndex[key][h],
                    s.chainFallback[key][h],
                    s.branchCommitments[key][h]
                )
            );
        }
        for (uint256 i; i < 7; ++i) {
            hash = keccak256(abi.encode(hash, s.familyCommitments[key][W.RecordKind(i)]));
        }
        for (uint256 i; i < 3; ++i) {
            (address account, bytes32 retirement) = _scope(i);
            bytes32 scope = keccak256(abi.encode(account, retirement));
            hash = keccak256(
                abi.encode(
                    hash,
                    s.standingScopeSeen[key][scope],
                    s.standingWinners[key][scope],
                    s.standingRevisions[key][scope],
                    s.retainedMembers[key][account]
                )
            );
        }
    }

    function stateHash(bool original, bytes32 key) external view returns (bytes32) {
        Store.State storage s = original ? _original : _actual;
        return keccak256(abi.encode(readOnlyHash(original, key), s.results[key], s.progress[key]));
    }

    function _seed(Store.State storage s, bytes32 key, bool populated) private {
        delete s.results[key];
        delete s.progress[key];
        delete s.excluded[key];
        delete s.standingScopes[key];
        W.EnvironmentV3 memory e = W.EnvironmentV3(
            block.chainid,
            address(0x101),
            _owner,
            _owner.codehash,
            address(0x102),
            bytes32(uint256(103)),
            address(this),
            address(0x104),
            address(0x105),
            address(0x106)
        );
        W.BasisV3 memory b;
        b.identity.manifestHash = bytes32(uint256(71));
        b.identity.artistId = bytes32(uint256(77));
        b.identity.ownerCodeHash = e.identityCodeHash;
        b.identity.identity = W.ReceiptPrefix(
            T.Snapshot(bytes32(uint256(72)), 73, bytes32(uint256(74)), bytes32(uint256(75))),
            populated ? 7 : 0
        );
        b.identity.guardianHistory = GH.Head(populated ? 2 : 0, 78, bytes32(uint256(79)));
        b.identity.sourceCommitment = bytes32(uint256(80));
        b.identity.inventory.revisionContinuationHash = bytes32(uint256(81));
        b.identity.inventory.supersessionStateCommitment = bytes32(uint256(82));
        b.payoutCodeHash = e.payoutCodeHash;
        b.payout = W.ReceiptPrefix(
            T.Snapshot(bytes32(uint256(83)), 84, bytes32(uint256(85)), bytes32(uint256(86))),
            populated ? 8 : 0
        );
        b.payoutInventory.supersessionStateCommitment = bytes32(uint256(87));
        b.payoutInventory.continuationCommitment = bytes32(uint256(88));
        b.sourceCommitment = bytes32(uint256(89));
        if (populated) {
            b.identity.inventory.guardians =
                W.FamilyPointers(bytes32(uint256(1)), bytes32(uint256(2)));
            b.identity.inventory.designations =
                W.FamilyPointers(bytes32(uint256(3)), bytes32(uint256(4)));
            b.identity.inventory.directives =
                W.FamilyPointers(bytes32(uint256(5)), bytes32(uint256(6)));
            b.identity.inventory.sanctionGrants =
                W.FamilyPointers(bytes32(uint256(7)), bytes32(uint256(8)));
            b.identity.inventory.revisions =
                W.FamilyPointers(bytes32(uint256(9)), bytes32(uint256(10)));
            b.payoutInventory.stable = T.Payout(address(0x100B), bytes32(uint256(11)));
            b.payoutInventory.candidate = T.Payout(address(0x100C), bytes32(uint256(12)));
            s.results[key].designation.operative = _selected(3);
            s.results[key].directive.operative = _selected(5);
            s.results[key].sanctionGrant.operative = _selected(7);
            s.results[key].guardians.selectedRecordHash = bytes32(uint256(1));
            s.results[key].guardians.selectedDataHash = bytes32(uint256(3001));
            s.results[key].guardians.selectedNonce = 5001;
            s.excluded[key].push(
                W.RecordReference(W.RecordKind.IDENTITY_REVISION, bytes32(uint256(17)))
            );
            s.excluded[key].push(
                W.RecordReference(W.RecordKind.PAYOUT_DESIGNATION, bytes32(uint256(18)))
            );
        }
        s.environments[key] = e;
        s.bases[key] = b;
        s.manifestKeys[b.identity.manifestHash] = key;
        s.guardianTip[key] = b.identity.guardianHistory.commitment;
        s.guardianRevision[key] = b.identity.guardianHistory.ownerRevision;
        s.originalRevisionContinuation[key] = bytes32(uint256(90));
        s.seals[key].manifestHash = bytes32(uint256(91));
        s.seals[key].commitment = bytes32(uint256(92));
        W.ProgressV3 storage p = s.progress[key];
        p.identityProcessed = b.identity.identity.receiptCount;
        p.payoutProcessed = b.payout.receiptCount;
        p.guardiansProcessed = b.identity.guardianHistory.count;
        p.seenExclusions = populated ? 3 : 0;
        p.identityScanCommitment = bytes32(uint256(93));
        p.payoutScanCommitment = bytes32(uint256(94));
        for (uint256 i = 1; i <= 18; ++i) {
            bytes32 h = bytes32(i);
            Records.Facts memory f;
            f.selected = _selected(i);
            f.account = address(uint160(0x1000 + i));
            f.eligible = i != 4 && i != 6 && i != 10 && i != 12;
            f.pairedDirective = i == 4 ? bytes32(uint256(16)) : bytes32(0);
            f.admissionRevision = uint64(i + 100);
            f.authorityClass = 3;
            f.previousRecordHash = bytes32(i + 200);
            f.valueHash = bytes32(i + 300);
            s.records[key][h] = f;
            s.kinds[key][h] = _kind(i);
            s.admitted[key][h] = true;
            s.retained[key][h] = i != 10 && i < 17;
            s.previouslySuperseded[key][h] = false;
            s.excludedIndex[key][h] = populated && i >= 17 ? uint8(i - 16) : 0;
            s.chainFallback[key][h] =
                i == 10 ? bytes32(uint256(9)) : i == 12 ? bytes32(uint256(11)) : h;
            s.branchCommitments[key][h] = bytes32(2000 + i);
        }
        for (uint256 i; i < 7; ++i) {
            s.familyCommitments[key][W.RecordKind(i)] = bytes32(1000 + i);
        }
        // Insertion order B/current, A/current, A/historical is intentionally not sorted.
        for (uint256 i; i < 3; ++i) {
            (address account, bytes32 retirement) = _scope(i);
            bytes32 scope = keccak256(abi.encode(account, retirement));
            s.standingScopeSeen[key][scope] = populated;
            s.standingWinners[key][scope] = bytes32(13 + i);
            s.standingRevisions[key][scope] = uint64(200 + i);
            s.retainedMembers[key][account] = true;
            if (populated) s.standingScopes[key].push(Store.StandingScope(account, retirement));
        }
    }

    function _fault(Store.State storage s, bytes32 key, uint256 variant) private {
        if (variant == 0) ++s.progress[key].identityProcessed;
        if (variant == 1) ++s.progress[key].payoutProcessed;
        if (variant == 2) ++s.progress[key].guardiansProcessed;
        if (variant == 3) s.guardianTip[key] = bytes32(uint256(999));
        if (variant == 4) ++s.guardianRevision[key];
        if (variant == 5) s.progress[key].seenExclusions ^= 1;
        if (variant == 6) s.admitted[key][bytes32(uint256(3))] = false;
        if (variant == 7) s.kinds[key][bytes32(uint256(3))] = W.RecordKind.GUARDIAN_SET;
        if (variant == 8) s.previouslySuperseded[key][bytes32(uint256(3))] = true;
        if (variant == 9) s.admitted[key][bytes32(uint256(2))] = false;
        if (variant == 10) s.bases[key].payoutInventory.stable.recordHash = bytes32(0);
        if (variant == 11) s.bases[key].payoutInventory.candidate.recordHash = bytes32(0);
        if (variant == 12) s.bases[key].payoutInventory.stable.account = address(0x9999);
        if (variant == 13) s.bases[key].payoutInventory.candidate.account = address(0x9999);
        if (variant == 14) s.admitted[key][bytes32(uint256(16))] = false;
        if (variant == 15) s.kinds[key][bytes32(uint256(16))] = W.RecordKind.GUARDIAN_SET;
        if (variant == 16) s.retained[key][bytes32(uint256(16))] = false;
    }

    // Repair only the intentionally corrupted source fact. In particular, never
    // clear results, standing pushes, completion flags, or scan commitments here.
    function _repair(Store.State storage s, bytes32 key, uint256 variant) private {
        if (variant == 0) {
            s.progress[key].identityProcessed = s.bases[key].identity.identity.receiptCount;
        }
        if (variant == 1) s.progress[key].payoutProcessed = s.bases[key].payout.receiptCount;
        if (variant == 2) {
            s.progress[key].guardiansProcessed = s.bases[key].identity.guardianHistory.count;
        }
        if (variant == 3) s.guardianTip[key] = s.bases[key].identity.guardianHistory.commitment;
        if (variant == 4) {
            s.guardianRevision[key] = s.bases[key].identity.guardianHistory.ownerRevision;
        }
        if (variant == 5) {
            s.progress[key].seenExclusions = (uint256(1) << s.excluded[key].length) - 1;
        }
        if (variant == 6) s.admitted[key][bytes32(uint256(3))] = true;
        if (variant == 7) s.kinds[key][bytes32(uint256(3))] = W.RecordKind.SUCCESSOR_DESIGNATION;
        if (variant == 8) s.previouslySuperseded[key][bytes32(uint256(3))] = false;
        if (variant == 9) s.admitted[key][bytes32(uint256(2))] = true;
        if (variant == 10) s.bases[key].payoutInventory.stable.recordHash = bytes32(uint256(11));
        if (variant == 11) {
            s.bases[key].payoutInventory.candidate.recordHash = bytes32(uint256(12));
        }
        if (variant == 12) s.bases[key].payoutInventory.stable.account = address(0x100B);
        if (variant == 13) s.bases[key].payoutInventory.candidate.account = address(0x100C);
        if (variant == 14) s.admitted[key][bytes32(uint256(16))] = true;
        if (variant == 15) s.kinds[key][bytes32(uint256(16))] = W.RecordKind.ESTATE_DIRECTIVE;
        if (variant == 16) s.retained[key][bytes32(uint256(16))] = true;
    }

    function _selected(uint256 i) private pure returns (W.SelectedRecordV3 memory) {
        return
            W.SelectedRecordV3(bytes32(i), bytes32(3000 + i), bytes32(4000 + i), 5000 + i, 6000 + i);
    }

    function _kind(uint256 i) private pure returns (W.RecordKind) {
        if (i <= 2) return W.RecordKind.GUARDIAN_SET;
        if (i <= 4) return W.RecordKind.SUCCESSOR_DESIGNATION;
        if (i <= 6 || i == 16) return W.RecordKind.ESTATE_DIRECTIVE;
        if (i <= 8) return W.RecordKind.STEWARD_SANCTION_GRANT;
        if (i <= 10 || i == 17) return W.RecordKind.IDENTITY_REVISION;
        if (i <= 12 || i == 18) return W.RecordKind.PAYOUT_DESIGNATION;
        return W.RecordKind.PRIOR_ADDRESS_STANDING_REVOCATION;
    }

    function _scope(uint256 i) private pure returns (address account, bytes32 retirement) {
        if (i == 0) return (address(0x20), bytes32(uint256(30)));
        if (i == 1) return (address(0x10), bytes32(uint256(20)));
        return (address(0x10), bytes32(uint256(10)));
    }
}

/// @notice Finish-only differential with explicit synthetic scan state. No original
/// admission, journal scan, full Selector, or capacity/runtime acceptance is claimed.
contract StreamArtistRecoveryRewindSelectionFinishTest {
    bytes32 private constant KEY = bytes32(uint256(12345));
    RewindFinishStandingProbe private owner;
    RewindFinishComparisonHost private host;

    function setUp() public {
        owner = new RewindFinishStandingProbe();
        host = new RewindFinishComparisonHost(address(owner));
        owner.setHost(address(host));
    }

    function testEmptyFinishWritesCompleteAndLiteralCommitmentsOnlyToSelectedRoot() public {
        host.seed(KEY, false);
        (W.ResultV3 memory r,) = _success();
        require(
            r.standing.length == 0 && r.designation.operative.recordHash == 0, "empty selections"
        );
        _literalCommitments(r);
    }

    function testFamiliesFallbackRetainedCandidateAndSortedStandingMatchOriginal() public {
        host.seed(KEY, true);
        (W.ResultV3 memory r,) = _success();
        require(r.designation.operative.recordHash == bytes32(uint256(3)), "nonce family winner");
        require(
            r.designation.retainedCandidateRecordHash == bytes32(uint256(4)),
            "retained ineligible paired candidate"
        );
        require(
            r.directive.retainedCandidateRecordHash == bytes32(uint256(6)),
            "directive candidate retained"
        );
        require(
            r.sanctionGrant.retainedCandidateRecordHash == 0,
            "eligible grant not retained candidate"
        );
        require(
            r.identityRevision.operative.recordHash == bytes32(uint256(9)),
            "excluded revision falls back"
        );
        require(
            r.identityRevision.retainedCandidateRecordHash == 0, "excluded revision is not retained"
        );
        require(
            r.payout.operative.recordHash == bytes32(uint256(11))
                && r.payout.retainedCandidateRecordHash == bytes32(uint256(12)),
            "payout fallback and candidate"
        );
        require(r.standing.length == 3, "all standing scopes");
        require(
            r.standing[0].priorAddress == address(0x10)
                && r.standing[0].retirementHash == bytes32(uint256(10)),
            "historical scope sorted first"
        );
        require(
            r.standing[1].priorAddress == address(0x10)
                && r.standing[1].retirementHash == bytes32(uint256(20)),
            "current same-account scope sorted second"
        );
        require(
            r.standing[2].priorAddress == address(0x20)
                && r.standing[2].retirementHash == bytes32(uint256(30)),
            "second account sorted last"
        );
        require(
            r.standing[0].continuationCommitment == 0
                && r.standing[1].continuationCommitment == bytes32(uint256(320))
                && r.standing[2].continuationCommitment == bytes32(uint256(330)),
            "only current scopes retain continuation"
        );
        require(
            r.standing[0].expectedRevocationRecordHash == bytes32(uint256(120))
                && r.standing[0].retainedRevocation.recordHash == bytes32(uint256(15)),
            "historical raw pointer and selected record retained"
        );
        _literalCommitments(r);
    }

    function testEachInitialFinishGuardRejectsExactOriginalErrorAndRollsBack() public {
        for (uint256 fault; fault < 6; ++fault) {
            host.seed(KEY, true);
            host.fault(KEY, fault);
            _reject(abi.encodeWithSelector(W.InvalidRecoveryRewindSelection.selector, KEY));
            host.repair(KEY, fault);
            _success();
        }
    }

    function testMissingWrongKindPreviouslySupersededAndLateGuardianPointersReject() public {
        for (uint256 fault = 6; fault < 10; ++fault) {
            host.seed(KEY, true);
            host.fault(KEY, fault);
            _reject(abi.encodeWithSelector(W.InvalidRecoveryRewindSelection.selector, KEY));
            host.repair(KEY, fault);
            _success();
        }
    }

    function testStableAndCandidatePayoutAccountBranchesRejectAfterIntermediateWrites() public {
        for (uint256 fault = 10; fault < 14; ++fault) {
            host.seed(KEY, true);
            host.fault(KEY, fault);
            _reject(abi.encodeWithSelector(W.InvalidRecoveryRewindSelection.selector, KEY));
            host.repair(KEY, fault);
            _success();
        }
    }

    function testIneligibleCandidateCannotRetainMissingWrongKindOrExcludedPairedDirective() public {
        for (uint256 fault = 14; fault < 17; ++fault) {
            host.seed(KEY, true);
            host.fault(KEY, fault);
            _reject(abi.encodeWithSelector(W.InvalidRecoveryRewindSelection.selector, KEY));
            host.repair(KEY, fault);
            _success();
        }
    }

    function testLateStandingOwnerFailureRollsBackBothRootsAndRetriesWithoutReseeding() public {
        host.seed(KEY, true);
        owner.setFailure(address(0x20));
        _reject(abi.encodeWithSelector(FinishStandingFailure.selector, address(0x20)));
        owner.setFailure(address(0));
        (W.ResultV3 memory r,) = _success();
        require(r.standing.length == 3, "failed attempt did not retain earlier standing pushes");
        (bool ok, bytes memory error) = address(owner)
            .staticcall(
                abi.encodeCall(owner.recoveryStandingScopeV3, (bytes32(uint256(77)), address(0x10)))
            );
        require(
            !ok
                && keccak256(error)
                    == keccak256(
                        abi.encodeWithSelector(FinishStandingWrongCaller.selector, address(this))
                    ),
            "owner caller probe active"
        );
        _literalCommitments(r);
    }

    function _success() private returns (W.ResultV3 memory r, W.ProgressV3 memory p) {
        bytes32 untouched = host.stateHash(true, KEY);
        bytes32 readOnly = host.readOnlyHash(false, KEY);
        require(untouched == host.stateHash(false, KEY), "identical initial roots");
        (bool actualOK, bytes memory actual) =
            address(host).call(abi.encodeCall(host.run, (false, KEY)));
        require(actualOK, "actual finish succeeds");
        require(host.stateHash(true, KEY) == untouched, "actual cannot mutate reference root");
        bytes32 actualFinished = host.stateHash(false, KEY);
        (bool originalOK, bytes memory original) =
            address(host).call(abi.encodeCall(host.run, (true, KEY)));
        require(
            originalOK && keccak256(actual) == keccak256(original),
            "entire original Result and Progress bytes"
        );
        require(host.stateHash(false, KEY) == actualFinished, "reference cannot mutate actual root");
        require(host.stateHash(true, KEY) == actualFinished, "all compared state agrees");
        require(
            host.readOnlyHash(false, KEY) == readOnly && host.readOnlyHash(true, KEY) == readOnly,
            "all addressed source state remains readonly"
        );
        (r, p) = abi.decode(actual, (W.ResultV3, W.ProgressV3));
        require(
            p.complete && r.commitment != 0 && p.resultCommitment == r.commitment,
            "explicit finish anchor"
        );
    }

    function _reject(bytes memory expected) private {
        bytes32 beforeActual = host.stateHash(false, KEY);
        bytes32 beforeOriginal = host.stateHash(true, KEY);
        (bool actualOK, bytes memory actual) =
            address(host).call(abi.encodeCall(host.run, (false, KEY)));
        require(
            host.stateHash(false, KEY) == beforeActual
                && host.stateHash(true, KEY) == beforeOriginal,
            "failed actual frame fully rolled back"
        );
        (bool originalOK, bytes memory original) =
            address(host).call(abi.encodeCall(host.run, (true, KEY)));
        require(
            !actualOK && !originalOK && keccak256(actual) == keccak256(original)
                && keccak256(actual) == keccak256(expected),
            "full original error bytes"
        );
        require(
            host.stateHash(false, KEY) == beforeActual
                && host.stateHash(true, KEY) == beforeOriginal,
            "failed original frame fully rolled back"
        );
    }

    function _literalCommitments(W.ResultV3 memory r) private view {
        (W.EnvironmentV3 memory e, W.BasisV3 memory b) = host.basis(KEY);
        require(
            r.sourceKey == KEY && r.manifestHash == b.identity.manifestHash
                && r.sourceCommitment == b.sourceCommitment,
            "original source bindings"
        );
        require(
            r.inventoryCommitment
                == keccak256(
                    abi.encode(
                        keccak256("6529STREAM_ARTIST_RECOVERY_REWIND_INVENTORY_V3"),
                        uint16(3),
                        e,
                        b.identity.inventory,
                        b.payoutInventory
                    )
                ),
            "literal inventory domain"
        );
        _family(
            r.designation,
            b.identity.inventory.designations,
            W.RecordKind.SUCCESSOR_DESIGNATION,
            false
        );
        _family(r.directive, b.identity.inventory.directives, W.RecordKind.ESTATE_DIRECTIVE, false);
        _family(
            r.sanctionGrant,
            b.identity.inventory.sanctionGrants,
            W.RecordKind.STEWARD_SANCTION_GRANT,
            false
        );
        _family(
            r.identityRevision, b.identity.inventory.revisions, W.RecordKind.IDENTITY_REVISION, true
        );
        _family(
            r.payout,
            W.FamilyPointers(
                b.payoutInventory.stable.recordHash, b.payoutInventory.candidate.recordHash
            ),
            W.RecordKind.PAYOUT_DESIGNATION,
            true
        );
        require(
            r.guardians.sourceKey == KEY
                && r.guardians.commitment
                    == keccak256(
                        abi.encode(
                            keccak256("6529STREAM_ARTIST_RECOVERY_REWIND_GUARDIAN_RESULT_V3"),
                            uint16(3),
                            e,
                            b.identity.guardianHistory,
                            KEY,
                            r.guardians.selectedRecordHash,
                            r.guardians.selectedDataHash,
                            r.guardians.selectedNonce
                        )
                    ),
            "literal guardian domain"
        );
        bytes32 commitment = r.commitment;
        r.commitment = bytes32(0);
        require(
            commitment
                == keccak256(
                    abi.encode(
                        keccak256("6529STREAM_ARTIST_RECOVERY_REWIND_SELECTION_RESULT_V3"),
                        uint16(3),
                        e,
                        r
                    )
                ),
            "literal result domain omits own commitment"
        );
    }

    function _family(
        W.FamilySelectionV3 memory r,
        W.FamilyPointers memory pointers,
        W.RecordKind kind,
        bool chain
    ) private pure {
        bytes32 family = bytes32(1000 + uint256(kind));
        bytes32 expected;
        if (chain) {
            bytes32 tip = pointers.candidate != 0 ? pointers.candidate : pointers.stable;
            bytes32 branch = tip == 0 ? bytes32(0) : bytes32(2000 + uint256(tip));
            expected = keccak256(
                abi.encode(
                    keccak256("6529STREAM_ARTIST_RECOVERY_REWIND_BRANCH_V3"),
                    KEY,
                    kind,
                    pointers,
                    family,
                    branch,
                    r.operative,
                    r.retainedCandidateRecordHash
                )
            );
        } else {
            expected = keccak256(
                abi.encode(
                    keccak256("6529STREAM_ARTIST_RECOVERY_REWIND_FAMILY_V3"),
                    KEY,
                    kind,
                    pointers,
                    family,
                    r.operative,
                    r.retainedCandidateRecordHash
                )
            );
        }
        require(r.branchCommitment == expected, "literal family or branch commitment");
    }
}
