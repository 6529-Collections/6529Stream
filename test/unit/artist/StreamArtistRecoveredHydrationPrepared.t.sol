// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    StreamArtistRecoveredHydrationPrepared as Prepared
} from "../../../smart-contracts/domains/artist/StreamArtistRecoveredHydrationPrepared.sol";
import {
    StreamArtistRecoveredHydrationCommit as Commit
} from "../../../smart-contracts/domains/artist/StreamArtistRecoveredHydrationCommit.sol";
import {
    StreamArtistRecoveredHydrationTypes as RH
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistRecoveredHydrationTypes.sol";
import {
    StreamArtistRecoveredIdentityHydrationTypes as IH
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistRecoveredIdentityHydrationTypes.sol";
import {
    StreamArtistRecoveredPayoutTypes as P
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistRecoveredPayoutTypes.sol";
import {
    StreamArtistAuthorityHydrationTypes as AH
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistAuthorityHydration.sol";
import {
    StreamArtistOnboardingTypes as T
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistOnboardingTypes.sol";
import {
    StreamArtistRecoveredTimingTypes as TM
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistRecoveredTimingTypes.sol";
import {
    StreamArtistRecoveredExternalGuards as External
} from "../../../smart-contracts/domains/artist/StreamArtistRecoveredExternalGuards.sol";

/// @notice Synthetic pure classification and commitment controls, not a seven-owner roundtrip.
/// @dev These deliberately incomplete typed bundles exercise only requiredFeatures/inventory.
/// They do not establish source admission, recovery signatures, capability availability, or
/// semantic/provenance validation; the production prepare/collect paths perform those checks.
contract StreamArtistRecoveredHydrationPreparedTest {
    function testPreparedCurrentClassesHaveExactFeatures() public pure {
        IH.Bundle memory identity;
        P.Bundle memory payout;
        identity.identity.authorityClass = 1;
        assert(Prepared.requiredFeatures(identity, payout, 1) == RH.CLASS_ONE);
        identity.identity.authorityClass = 3;
        assert(Prepared.requiredFeatures(identity, payout, 1) == RH.CLASS_THREE);
    }

    function testPreparedHistoricalRecoveryClassIsRetained() public pure {
        IH.Bundle memory identity;
        P.Bundle memory payout;
        identity.identity.authorityClass = 3;
        identity.recoveries = new IH.RecoveryRow[](2);
        identity.recoveries[0].record.fields.vestedAuthorityClass = 1;
        identity.recoveries[1].record.fields.vestedAuthorityClass = 3;
        assert(Prepared.requiredFeatures(identity, payout, 1) == RH.CLASS_ONE | RH.CLASS_THREE);
        identity.identity.authorityClass = 1;
        assert(Prepared.requiredFeatures(identity, payout, 1) == RH.CLASS_ONE | RH.CLASS_THREE);
    }

    function testPreparedActionEvidenceSelectsV2AndV3Independently() public pure {
        IH.Bundle memory identity;
        P.Bundle memory payout;
        identity.identity.authorityClass = 1;
        identity.actions = new IH.ActionRow[](2);
        // Empty action rows are not evidence of either version.
        assert(Prepared.requiredFeatures(identity, payout, 1) == RH.CLASS_ONE);
        identity.actions[0].evidenceV2.manifestHash = keccak256("synthetic V2 manifest");
        assert(Prepared.requiredFeatures(identity, payout, 1) == RH.CLASS_ONE | RH.ADJUDICATION_V2);
        identity.actions[0].evidenceV2.manifestHash = 0;
        identity.actions[1].evidenceV3.manifestHash = keccak256("synthetic V3 manifest");
        assert(Prepared.requiredFeatures(identity, payout, 1) == RH.CLASS_ONE | RH.REWINDS_V3);
        identity.actions[0].evidenceV2.manifestHash = keccak256("synthetic V2 manifest");
        assert(
            Prepared.requiredFeatures(identity, payout, 1)
                == RH.CLASS_ONE | RH.ADJUDICATION_V2 | RH.REWINDS_V3
        );
    }

    function testPreparedOriginal58ContinuationDoesNotImplyV2() public pure {
        IH.Bundle memory identity;
        P.Bundle memory payout;
        identity.identity.authorityClass = 1;
        identity.originalContinuations = new IH.OriginalContinuationRow[](1);
        // This is the original Dismissal.RevisionContinuation shape written by op58,
        // not EvidenceStateV2. No producer execution or canonical admission is claimed here.
        identity.originalContinuations[0].continuation.artistId = keccak256("artist");
        identity.originalContinuations[0].continuation.dismissalRecordHash = keccak256("original58");
        identity.originalContinuations[0].continuation.continuationHash =
            keccak256("original V1 continuation");
        assert(Prepared.requiredFeatures(identity, payout, 1) == RH.CLASS_ONE);
    }

    function testPreparedEachTypedV3ContinuationRequiresRewinds() public pure {
        for (uint256 kind; kind < 4; ++kind) {
            IH.Bundle memory identity;
            P.Bundle memory payout;
            identity.identity.authorityClass = 3;
            if (kind == 0) identity.revisionContinuations = new IH.RevisionContinuationRow[](1);
            if (kind == 1) identity.standingContinuations = new IH.StandingContinuationRow[](1);
            if (kind == 2) {
                identity.capabilityContinuations = new IH.CapabilityContinuationRow[](1);
            }
            if (kind == 3) payout.continuations = new P.ContinuationRow[](1);
            assert(Prepared.requiredFeatures(identity, payout, 1) == RH.CLASS_THREE | RH.REWINDS_V3);
        }
    }

    function testPreparedRepeatedErasComposeAllRequiredFeatures() public pure {
        IH.Bundle memory identity;
        P.Bundle memory payout;
        identity.identity.authorityClass = 3;
        identity.recoveries = new IH.RecoveryRow[](1);
        identity.recoveries[0].record.fields.vestedAuthorityClass = 1;
        identity.actions = new IH.ActionRow[](1);
        identity.actions[0].evidenceV2.manifestHash = keccak256("V2");
        payout.continuations = new P.ContinuationRow[](1);
        for (uint256 eras = 2; eras <= RH.MAX_ERAS; ++eras) {
            assert(Prepared.requiredFeatures(identity, payout, eras) == RH.KNOWN_FEATURES);
        }
    }

    function testPreparedRejectsZeroAndExcessEraCounts() public view {
        IH.Bundle memory identity;
        P.Bundle memory payout;
        identity.identity.authorityClass = 1;
        _reject(identity, payout, 0, RH.InvalidRecoveredHydrationProfile.selector);
        _reject(identity, payout, RH.MAX_ERAS + 1, RH.InvalidRecoveredHydrationProfile.selector);
    }

    function testPreparedRejectsUnsupportedCurrentClass() public view {
        IH.Bundle memory identity;
        P.Bundle memory payout;
        uint8[4] memory classes = [uint8(0), 2, 4, 255];
        for (uint256 i; i < classes.length; ++i) {
            identity.identity.authorityClass = classes[i];
            _reject(identity, payout, 1, T.UnsupportedProfile.selector);
        }
    }

    function testPreparedRejectsUnsupportedHistoricalClass() public view {
        IH.Bundle memory identity;
        P.Bundle memory payout;
        identity.identity.authorityClass = 1;
        identity.recoveries = new IH.RecoveryRow[](1);
        uint8[4] memory classes = [uint8(0), 2, 4, 255];
        for (uint256 i; i < classes.length; ++i) {
            identity.recoveries[0].record.fields.vestedAuthorityClass = classes[i];
            _reject(identity, payout, 1, T.UnsupportedProfile.selector);
        }
    }

    function testPreparedInventoryHasLiteralVersionedPreimage() public pure {
        Commit.Prepared memory p = _inventory();
        bytes32 provenance = keccak256(
            abi.encode(
                keccak256("6529STREAM_ARTIST_RECOVERED_HYDRATION_PROVENANCE_V1"),
                uint16(1),
                p.admission.provenance
            )
        );
        bytes32 expected = keccak256(
            abi.encode(
                keccak256("6529STREAM_ARTIST_RECOVERED_SEMANTIC_INVENTORY_V1"),
                uint16(1),
                provenance,
                p.query,
                p.data,
                p.timing,
                p.externalGuards
            )
        );
        assert(Prepared.inventory(p) == expected && expected != 0);
        assert(Prepared.inventory(_clone(p)) == expected);
    }

    function testPreparedInventoryBindsEveryOwnerSemanticBytes() public pure {
        Commit.Prepared memory p = _inventory();
        bytes32 original = Prepared.inventory(p);
        for (uint256 i; i < 7; ++i) {
            Commit.Prepared memory changed = _clone(p);
            changed.data[i].typedState = abi.encode("changed typed state", i);
            assert(Prepared.inventory(changed) != original);
        }
        assert(Prepared.inventory(p) == original);
    }

    function testPreparedInventoryBindsGuardOriginsKeysAndCells() public pure {
        Commit.Prepared memory p = _inventory();
        bytes32 original = Prepared.inventory(p);
        for (uint256 i; i < 7; ++i) {
            Commit.Prepared memory changed = _clone(p);
            if (i == 0) changed.data[2].origins[0].surface = keccak256("other surface");
            if (i == 1) changed.data[2].origins[0].scope = keccak256("other scope");
            if (i == 2) changed.data[2].sourceKeys[0] = keccak256("other key");
            if (i == 3) changed.data[2].cells[0].commitment = keccak256("other commitment");
            if (i == 4) ++changed.data[2].cells[0].touchedRevision;
            if (i == 5) ++changed.data[2].cells[0].kind;
            if (i == 6) ++changed.data[2].cells[0].status;
            assert(Prepared.inventory(changed) != original);
        }
    }

    function testPreparedInventoryBindsNoncePrefixEveryWordAndExhaustion() public pure {
        Commit.Prepared memory p = _inventory();
        bytes32 original = Prepared.inventory(p);
        for (uint256 i; i < 34; ++i) {
            Commit.Prepared memory changed = _clone(p);
            if (i == 0) ++changed.data[2].nonces[0].prefix;
            else if (i == 33) changed.data[2].nonces[0].exhausted = true;
            else ++changed.data[2].nonces[0].words[i - 1];
            assert(Prepared.inventory(changed) != original);
        }
    }

    function testPreparedInventoryBindsProvenanceOriginalsAndOccurrences() public pure {
        Commit.Prepared memory p = _inventory();
        bytes32 original = Prepared.inventory(p);
        for (uint256 i; i < 7; ++i) {
            Commit.Prepared memory changed = _clone(p);
            if (i == 0) ++changed.admission.provenance.origins[0].chainId;
            if (i == 1) ++changed.admission.provenance.eras[0].checkpoints[2].ownerState.revision;
            if (i == 2) {
                changed.admission.provenance.eras[0].priorImportCommitment = keccak256("import");
            }
            if (i == 3) ++changed.admission.provenance.journals[2][0].position.nativeIndex;
            if (i == 4) {
                changed.admission.provenance.journals[2][0].receipt.recordHash =
                    keccak256("other original");
            }
            if (i == 5) ++changed.admission.provenance.aliases[2][0].admittedAt.ownerRevision;
            if (i == 6) {
                changed.admission.provenance.aliases[2][0].originalKey =
                    keccak256("other original key");
            }
            assert(Prepared.inventory(changed) != original);
        }
    }

    function testPreparedInventorySeparatelyBindsTimingCheckpoint() public pure {
        Commit.Prepared memory p = _inventory();
        bytes32 original = Prepared.inventory(p);
        for (uint256 i; i < 5; ++i) {
            Commit.Prepared memory changed = _clone(p);
            if (i == 0) changed.timing.schema = keccak256("other timing schema");
            if (i == 1) ++changed.timing.version;
            if (i == 2) ++changed.timing.count;
            if (i == 3) changed.timing.root = keccak256("other timing root");
            if (i == 4) changed.timing.configurationHash = keccak256("other timing configuration");
            // Timing cannot silently change even if all seven payloads remain byte-identical.
            assert(keccak256(abi.encode(changed.data)) == keccak256(abi.encode(p.data)));
            assert(Prepared.inventory(changed) != original);
        }
    }

    function testPreparedInventoryBindsExactQuery() public pure {
        Commit.Prepared memory p = _inventory();
        bytes32 original = Prepared.inventory(p);
        for (uint256 i; i < 6; ++i) {
            Commit.Prepared memory changed = _clone(p);
            if (i == 0) changed.query.artistId = keccak256("other artist");
            if (i == 1) ++changed.query.collectionId;
            if (i == 2) changed.query.bindingHash = keccak256("other binding");
            if (i == 3) changed.query.policies[0].phaseId = keccak256("other phase");
            if (i == 4) changed.query.policies[0].policyHash = keccak256("other policy");
            if (i == 5) changed.query.records[0] = keccak256("other record");
            assert(Prepared.inventory(changed) != original);
        }
    }

    function testPreparedInventorySeparatelyBindsExternalGuards() public pure {
        Commit.Prepared memory p = _inventory();
        bytes32 original = Prepared.inventory(p);
        for (uint256 i; i < 5; ++i) {
            Commit.Prepared memory changed = _clone(p);
            if (i == 0) changed.externalGuards.schema = keccak256("other guard schema");
            if (i == 1) {
                changed.externalGuards.provenanceCommitment = keccak256("other guard provenance");
            }
            if (i == 2) {
                changed.externalGuards.actions[0].witness.executorCodeHash =
                    keccak256("other executor runtime");
            }
            if (i == 3) {
                changed.externalGuards.actions[0].facts.callHash = keccak256("other original calls");
            }
            if (i == 4) ++changed.externalGuards.actions[0].facts.expiresAfter;
            assert(
                keccak256(abi.encode(changed.data, changed.timing))
                    == keccak256(abi.encode(p.data, p.timing))
            );
            assert(Prepared.inventory(changed) != original);
        }
    }

    function features(IH.Bundle memory identity, P.Bundle memory payout, uint256 eras)
        external
        pure
        returns (uint256)
    {
        return Prepared.requiredFeatures(identity, payout, eras);
    }

    function _reject(
        IH.Bundle memory identity,
        P.Bundle memory payout,
        uint256 eras,
        bytes4 expected
    ) private view {
        (bool ok, bytes memory reason) = address(this)
            .staticcall(abi.encodeCall(this.features, (identity, payout, eras)));
        assert(!ok && keccak256(reason) == keccak256(abi.encodeWithSelector(expected)));
    }

    function _clone(Commit.Prepared memory p) private pure returns (Commit.Prepared memory) {
        return abi.decode(abi.encode(p), (Commit.Prepared));
    }

    function _inventory() private pure returns (Commit.Prepared memory p) {
        // Minimal synthetic sentinels. They are hash inputs, not an authenticated certificate.
        p.admission.provenance.origins = new RH.OriginEnvironment[](1);
        p.admission.provenance.origins[0].chainId = 1;
        p.admission.provenance.eras = new RH.Era[](1);
        p.admission.provenance.eras[0].checkpoints[2].ownerState.revision = 9;
        p.admission.provenance.journals[2] = new RH.JournalEntry[](1);
        p.admission.provenance.journals[2][0].receipt.recordHash = keccak256("original receipt");
        p.admission.provenance.aliases[2] = new RH.ReplayAlias[](1);
        p.admission.provenance.aliases[2][0].admittedAt.ownerRevision = 8;
        p.admission.provenance.aliases[2][0].originalKey = keccak256("original key");
        p.query.artistId = keccak256("artist");
        p.query.collectionId = 17;
        p.query.bindingHash = keccak256("binding");
        p.query.policies = new AH.PolicyKey[](1);
        p.query.policies[0] = AH.PolicyKey(keccak256("phase"), keccak256("policy"));
        p.query.records = new bytes32[](1);
        p.query.records[0] = keccak256("original record");
        for (uint256 i; i < 7; ++i) {
            p.data[i].typedState = abi.encode("synthetic semantic state", i);
        }
        p.data[2].origins = new AH.Origin[](1);
        p.data[2].origins[0] = AH.Origin(keccak256("surface"), keccak256("scope"));
        p.data[2].sourceKeys = new bytes32[](1);
        p.data[2].sourceKeys[0] = keccak256("key");
        p.data[2].cells = new T.ReplayCell[](1);
        p.data[2].cells[0] = T.ReplayCell(keccak256("commitment"), 8, 1, 2);
        p.data[2].nonces = new AH.NonceWord[](1);
        p.data[2].nonces[0].prefix = 3;
        p.data[2].nonces[0].words[31] = 1;
        p.timing = TM.Checkpoint(
            TM.SCHEMA, TM.VERSION, 1, keccak256("timing root"), keccak256("timing configuration")
        );
        p.externalGuards.schema = External.SCHEMA;
        p.externalGuards.provenanceCommitment = RH.provenanceHash(p.admission.provenance);
        p.externalGuards.actions = new External.ActionGuard[](1);
        p.externalGuards.actions[0].facts.callHash = keccak256("original calls");
    }
}
