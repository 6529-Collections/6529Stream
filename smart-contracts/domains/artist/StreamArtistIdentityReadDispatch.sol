// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import { StreamArtistRecoveryRewindState } from "./StreamArtistRecoveryRewindState.sol";
import { StreamArtistRecoveryRewindReads } from "./StreamArtistRecoveryRewindReads.sol";
import { StreamArtistRecoveryRewindInventory } from "./StreamArtistRecoveryRewindInventory.sol";
import {
    StreamArtistRecoveryRewindCapabilityReads
} from "./StreamArtistRecoveryRewindCapabilityReads.sol";
import {
    IStreamArtistIdentityRecoveryOwnerV3 as RewindOwner
} from "../../interfaces/stream/artist/IStreamArtistIdentityRecoveryV3.sol";

import { StreamArtistRecoveryAdjudicationReads } from "./StreamArtistRecoveryAdjudicationReads.sol";
import { StreamArtistRecoveryAdjudicationState } from "./StreamArtistRecoveryAdjudicationState.sol";
import {
    IStreamArtistIdentityRecoveryOwnerV2
} from "../../interfaces/stream/artist/IStreamArtistIdentityRecoveryV2.sol";
import {
    IStreamArtistRecoverySelectionOwnerV2
} from "../../interfaces/stream/artist/IStreamArtistRecoverySelectionPreparation.sol";
import "./StreamArtistEntropyUnavailabilityState.sol";
import "../../interfaces/stream/artist/IStreamArtistEntropyFindingHydration.sol";
import {
    StreamArtistEntropyUnavailabilityTypes as EU,
    IStreamArtistEntropyUnavailability,
    IStreamArtistEntropyUnavailabilityOwner,
    IStreamArtistEntropyUnavailabilityCoordinator
} from "../../interfaces/stream/artist/IStreamArtistEntropyUnavailability.sol";

import { StreamArtistPayloadStore } from "./StreamArtistPayloadStore.sol";
import { StreamArtistIdentityPayloadReads } from "./StreamArtistIdentityPayloadReads.sol";
import { StreamArtistDormancyRecovery } from "./StreamArtistDormancyRecovery.sol";
import "../../interfaces/stream/artist/IStreamArtistStewardCapabilities.sol";
import {
    StreamArtistStewardCapabilityTypes as SC
} from "../../interfaces/stream/artist/IStreamArtistStewardCapabilities.sol";

import "./StreamArtistDormancyReadEncoding.sol";
import {
    StreamArtistDormancyTypes as Dorm
} from "../../interfaces/stream/artist/IStreamArtistDormancy.sol";
import {
    IStreamArtistStewardSanctionGrant as SG
} from "../../interfaces/stream/artist/IStreamArtistStewardSanctionGrant.sol";
import { StreamArtistExtensionAdmission } from "./StreamArtistExtensionAdmission.sol";
import {
    StreamArtistGuardianSelectionTypes as GuardianSelectionTypes
} from "../../interfaces/stream/artist/StreamArtistGuardianSelectionTypes.sol";
import {
    StreamArtistGuardianSupersessionTypes as GuardianSupersessionTypes
} from "../../interfaces/stream/artist/StreamArtistGuardianSupersessionTypes.sol";
import { StreamArtistGuardianVestingHistory } from "./StreamArtistGuardianVestingHistory.sol";
import {
    StreamArtistGuardianHistoryTypes as GH
} from "../../interfaces/stream/artist/StreamArtistGuardianHistoryTypes.sol";
import {
    IStreamArtistRecoveryActionOwner
} from "../../interfaces/stream/artist/IStreamArtistRecoveryAction.sol";
import {
    StreamArtistRecoveryActionTypes as RecoveryAction
} from "../../interfaces/stream/artist/StreamArtistRecoveryActionTypes.sol";
import { StreamArtistRecoveryOwnerReads } from "./StreamArtistRecoveryOwnerReads.sol";

import "./StreamArtistContentHashes.sol";

import "./StreamArtistEconomicsHashes.sol";

import "./StreamArtistOwner.sol";
import "./StreamArtistIdentityData.sol";
import "../../interfaces/stream/artist/IStreamArtistUnavailability.sol";
import "./StreamArtistIdentityWriterExtension.sol";
import "../../interfaces/stream/artist/IStreamArtistIdentityRecovery.sol";
import "./StreamArtistIdentityExtensionDeployment.sol";
import "./StreamArtistEstateExtensionDeployment.sol";
import "./StreamArtistRecoveryExtensionDeployment.sol";
import "./StreamArtistIdentityDismissalState.sol";
import "./StreamArtistIdentityCauseState.sol";
import "./StreamArtistIdentityResolutionReads.sol";
import "./StreamArtistNonceAvailability.sol";
import "./StreamArtistDelegationState.sol";
import "./StreamArtistIdentityState.sol";
import "./StreamArtistBindingOperations.sol";
import "./StreamArtistCollaboratorIdentityState.sol";
import "./StreamArtistAuthorizationState.sol";
import "./StreamArtistIdentityRevisionState.sol";
import "./StreamArtistIdentityConsentState.sol";
import "./StreamArtistRotationState.sol";
import "./StreamArtistTimingState.sol";
import "./StreamArtistEstateReads.sol";
import "./StreamArtistEstateReadEncoding.sol";
import "./StreamArtistEstateTiming.sol";
import "./StreamArtistWindowConfiguration.sol";
import "../../interfaces/stream/artist/IStreamArtistEstateOwner.sol";
import "../../interfaces/stream/artist/IStreamArtistRotationOwner.sol";
import {
    StreamArtistOnboardingTypes as T
} from "../../interfaces/stream/artist/StreamArtistOnboardingTypes.sol";

/// @notice Fixed dispatch of original encoded Identity reads; explicit storage roots, no write route.
library StreamArtistIdentityReadDispatch {
    struct Input {
        StreamArtistIdentityState.OwnerContext owner;
        bytes data;
    }

    function read(
        StreamArtistIdentityState.State storage _identity,
        StreamArtistDelegationState.State storage _delegations,
        StreamArtistIdentityRevisionState.State storage _identityRevisions,
        StreamArtistRotationState.State storage _rotations,
        StreamArtistIdentityContestState.State storage _identityContests,
        StreamArtistSuccessionState.State storage _succession,
        StreamArtistIdentityResolutionState.State storage _resolutions,
        StreamArtistEstateState.State storage _estate,
        StreamArtistUnavailabilityState.State storage _unavailability,
        StreamArtistIdentityRecoveryState.State storage _identityRecovery,
        StreamArtistDormancyState.State storage _dormancy,
        StreamArtistStewardSanctionState.State storage _stewardGrants,
        StreamArtistStewardCapabilityState.State storage _stewardCapabilityGrants,
        mapping(bytes32 => T.ReplayCell) storage _replay,
        StreamArtistRecoveryAdjudicationState.State storage _recoveryAdjudication,
        StreamArtistRecoveryRewindState.State storage _recoveryRewinds,
        Input calldata input
    ) public view returns (bytes memory) {
        bytes calldata call_ = input.data;
        bytes4 selector = bytes4(call_[:4]);
        if (selector == bytes4(keccak256("currentAuthorityCapabilities(bytes32)"))) {
            bytes32 artistId = abi.decode(call_[4:], (bytes32));
            if (_recoveryRewinds.capabilityHead[artistId] != 0) {
                return abi.encode(
                    StreamArtistRecoveryRewindCapabilityReads.current(
                        _recoveryRewinds, _identity, _estate, _dormancy, artistId
                    )
                );
            }
        }
        if (
            selector == RewindOwner.recoveryRewindInventoryV3.selector
                || selector == RewindOwner.recoveryRecordStatusV3.selector
                || selector == RewindOwner.recoveryStandingScopeV3.selector
                || selector == RewindOwner.latestRecoveryCapabilityContinuationV3.selector
                || selector == RewindOwner.recoveryCapabilityContinuationV3.selector
                || selector == RewindOwner.identityRevisionRecoveryContinuationV3.selector
                || selector == RewindOwner.recoveryRevisionContinuationV3.selector
                || selector == RewindOwner.standingRevocationRecoveryContinuationV3.selector
                || selector == RewindOwner.recoveryStandingContinuationV3.selector
        ) {
            return StreamArtistRecoveryRewindInventory.readEncoded(
                _recoveryRewinds,
                _identityRecovery,
                _rotations,
                _resolutions,
                _identityRevisions,
                _succession,
                _stewardGrants,
                call_
            );
        }
        if (
            selector == RewindOwner.recoveryRewindBasisV3.selector
                || selector == RewindOwner.identityRecoveryEvidenceStateV3.selector
                || selector == RewindOwner.identityRecoveryContextV3.selector
                || selector == RewindOwner.guardianRecoveryAuthorityRoleV3.selector
        ) {
            return StreamArtistRecoveryRewindReads.read(
                _identityRecovery,
                _recoveryRewinds,
                _identity,
                _rotations,
                _resolutions,
                _estate,
                _dormancy,
                input.owner,
                call_
            );
        }
        // Preserve the exact prior public overload and every original selector path.
        return read(
            _identity,
            _delegations,
            _identityRevisions,
            _rotations,
            _identityContests,
            _succession,
            _resolutions,
            _estate,
            _unavailability,
            _identityRecovery,
            _dormancy,
            _stewardGrants,
            _stewardCapabilityGrants,
            _replay,
            _recoveryAdjudication,
            input
        );
    }

    function read(
        StreamArtistIdentityState.State storage _identity,
        StreamArtistDelegationState.State storage _delegations,
        StreamArtistIdentityRevisionState.State storage _identityRevisions,
        StreamArtistRotationState.State storage _rotations,
        StreamArtistIdentityContestState.State storage _identityContests,
        StreamArtistSuccessionState.State storage _succession,
        StreamArtistIdentityResolutionState.State storage _resolutions,
        StreamArtistEstateState.State storage _estate,
        StreamArtistUnavailabilityState.State storage _unavailability,
        StreamArtistIdentityRecoveryState.State storage _identityRecovery,
        StreamArtistDormancyState.State storage _dormancy,
        StreamArtistStewardSanctionState.State storage _stewardGrants,
        StreamArtistStewardCapabilityState.State storage _stewardCapabilityGrants,
        mapping(bytes32 => T.ReplayCell) storage _replay,
        StreamArtistRecoveryAdjudicationState.State storage _recoveryAdjudication,
        Input calldata input
    ) public view returns (bytes memory) {
        StreamArtistIdentityState.OwnerContext memory o = input.owner;
        bytes calldata call_ = input.data;
        bytes4 selector = bytes4(call_[:4]);
        if (selector == bytes4(keccak256("operativeIdentityRecord(bytes32)"))) {
            bytes32 artistId = abi.decode(call_[4:], (bytes32));
            return abi.encode(
                StreamArtistIdentityRevisionState.operativeRead(
                    _identityRevisions, _identity, _rotations, artistId
                )
            );
        }
        if (selector == bytes4(keccak256("nonceUsed(bytes32,uint256)"))) {
            (bytes32 artistId, uint256 nonce) = abi.decode(call_[4:], (bytes32, uint256));
            bytes32 key = keccak256(
                abi.encode(
                    keccak256("6529STREAM_ARTIST_OWNER_REPLAY_KEY_V2"),
                    o.environment.chainId,
                    o.environment.registry,
                    o.coordinator,
                    o.archive,
                    address(this),
                    o.domain,
                    keccak256("identity_authority.replay.nonce_allocator"),
                    keccak256(abi.encode(artistId, nonce))
                )
            );
            return abi.encode(_replay[key].status != 0);
        }
        if (
            selector == IStreamArtistIdentityRecoveryOwnerV2.identityRecoveryContextV2.selector
                || selector
                    == IStreamArtistIdentityRecoveryOwnerV2.guardianRecoveryAuthorityRoleV2.selector
                || selector
                    == IStreamArtistIdentityRecoveryOwnerV2.identityRecoveryEvidenceState.selector
                || selector
                    == IStreamArtistRecoverySelectionOwnerV2.recoverySelectionBasisV2.selector
        ) {
            return StreamArtistRecoveryAdjudicationReads.read(
                _identityRecovery,
                _recoveryAdjudication,
                _identity,
                _rotations,
                _resolutions,
                _estate,
                _dormancy,
                o,
                call_
            );
        }
        return read(
            _identity,
            _delegations,
            _identityRevisions,
            _rotations,
            _identityContests,
            _succession,
            _resolutions,
            _estate,
            _unavailability,
            _identityRecovery,
            _dormancy,
            _stewardGrants,
            _stewardCapabilityGrants,
            _replay,
            o,
            call_
        );
    }

    function read(
        StreamArtistIdentityState.State storage _identity,
        StreamArtistDelegationState.State storage _delegations,
        StreamArtistIdentityRevisionState.State storage _identityRevisions,
        StreamArtistRotationState.State storage _rotations,
        StreamArtistIdentityContestState.State storage _identityContests,
        StreamArtistSuccessionState.State storage _succession,
        StreamArtistIdentityResolutionState.State storage _resolutions,
        StreamArtistEstateState.State storage _estate,
        StreamArtistUnavailabilityState.State storage _unavailability,
        StreamArtistIdentityRecoveryState.State storage _identityRecovery,
        StreamArtistDormancyState.State storage _dormancy,
        StreamArtistStewardSanctionState.State storage _stewardGrants,
        StreamArtistStewardCapabilityState.State storage _stewardCapabilityGrants,
        mapping(bytes32 => T.ReplayCell) storage _replay,
        StreamArtistIdentityState.OwnerContext memory o,
        bytes calldata call_
    ) public view returns (bytes memory) {
        bytes4 selector = bytes4(call_[:4]);
        if (
            selector
                == IStreamArtistEntropyFindingHydrationOwner.entropyUnavailabilityFindingOrigin
                .selector
        ) {
            bytes32 hash = abi.decode(call_[4:], (bytes32));
            if (
                _unavailability.records[hash].recordHash == 0
                    || StreamArtistEntropyUnavailabilityStore.state().admissions[hash].target
                        .coordinator == address(0)
            ) return abi.encode(address(0));
            address origin = StreamArtistEntropyUnavailabilityStore.state().origins[hash];
            return abi.encode(origin == address(0) ? o.environment.registry : origin);
        }
        if (
            selector
                == IStreamArtistEntropyUnavailabilityOwner.entropyUnavailabilityFindingRecord
                .selector
        ) {
            bytes32 hash = abi.decode(call_[4:], (bytes32));
            return StreamArtistEntropyUnavailabilityState.recordRead(_unavailability, hash);
        }
        if (
            selector
                == IStreamArtistEntropyUnavailabilityOwner.entropyUnavailabilityFindingContext
                .selector
        ) {
            return StreamArtistEntropyUnavailabilityState.contextEncoded(
                _unavailability,
                _identity,
                StreamArtistUnavailabilityState.OwnerContext(
                    o.environment, o.coordinator, o.archive, o.domain, o.revision
                ),
                call_[4:]
            );
        }
        if (selector == bytes4(keccak256("unavailabilityFindingRecord(bytes32)"))) {
            (bytes32 hash) = abi.decode(call_[4:], (bytes32));
            return StreamArtistUnavailabilityState.recordEncodedRead(_unavailability, hash);
        }
        if (
            selector
                == bytes4(
                    keccak256(
                        "unavailabilityFindingContext(((bytes32,uint256,bytes32,bytes32),(address,bytes32,(uint8,uint256,uint256,bytes32),bytes32,bytes32),(bytes32,address,bytes32,bytes32,uint64,uint8,uint8,uint8,address,bool),(bytes32,address,uint8,bytes32,uint64,bytes32,bytes32,bytes32),bytes32,bytes32,uint64,uint64,bool))"
                    )
                )
        ) {
            (U.Input memory p) = abi.decode(call_[4:], (U.Input));
            return StreamArtistUnavailabilityState.contextEncodedRead(
                _unavailability,
                StreamArtistUnavailabilityState.OwnerContext(
                    o.environment, o.coordinator, o.archive, o.domain, o.revision
                ),
                _identity.identities[p.terms.artistId],
                p
            );
        }
        if (
            selector
                == bytes4(
                    keccak256(
                        "estateRequestFacts((bytes32,address,bytes32,bytes32,bytes32),bytes32)"
                    )
                )
        ) {
            (Estate.Request memory p, bytes32 envelopeHash) =
                abi.decode(call_[4:], (Estate.Request, bytes32));
            return StreamArtistEstateReadEncoding.request(
                _estate, _identity, _rotations, _succession, _resolutions, p, envelopeHash
            );
        }
        if (
            selector == bytes4(keccak256("estateExecutionFacts((bytes32,bytes32,bytes32),bytes32)"))
        ) {
            (Estate.Execution memory p, bytes32 envelopeHash) =
                abi.decode(call_[4:], (Estate.Execution, bytes32));
            return StreamArtistEstateReadEncoding.execution(
                _estate,
                _identity,
                _rotations,
                _succession,
                _resolutions,
                o.environment,
                p,
                envelopeHash
            );
        }
        if (selector == bytes4(keccak256("estateActivationRecord(bytes32)"))) {
            (bytes32 record) = abi.decode(call_[4:], (bytes32));
            return StreamArtistEstateReadEncoding.record(_estate, record);
        }
        if (selector == bytes4(keccak256("currentAuthorityCapabilities(bytes32)"))) {
            (bytes32 artistId) = abi.decode(call_[4:], (bytes32));
            return StreamArtistDormancyReadEncoding.authority(
                _dormancy, _stewardCapabilityGrants, _estate, _identity, artistId
            );
        }
        if (selector == bytes4(keccak256("successorDesignationRecord(bytes32)"))) {
            (bytes32 record) = abi.decode(call_[4:], (bytes32));
            return StreamArtistEstateReadEncoding.designation(_succession, record);
        }
        if (selector == bytes4(keccak256("estateDirectiveRecord(bytes32)"))) {
            (bytes32 record) = abi.decode(call_[4:], (bytes32));
            return StreamArtistEstateReadEncoding.directive(_succession, record);
        }
        if (selector == bytes4(keccak256("estateDirectivePayload(bytes32)"))) {
            (bytes32 record) = abi.decode(call_[4:], (bytes32));
            return StreamArtistIdentityPayloadReads.estateDirectivePayload(_succession, record);
        }
        if (selector == bytes4(keccak256("guardianRecordSupersession(bytes32)"))) {
            (bytes32 recordHash) = abi.decode(call_[4:], (bytes32));
            return
                StreamArtistRecoveryOwnerReads.guardianSupersession(_identityRecovery, recordHash);
        }
        if (selector == bytes4(keccak256("guardianRecoverySelection(bytes32)"))) {
            (bytes32 actionId) = abi.decode(call_[4:], (bytes32));
            return StreamArtistRecoveryOwnerReads.selection(_identityRecovery, actionId);
        }
        if (selector == bytes4(keccak256("guardianRecoveryAuthorityRole(bytes32,bytes32[])"))) {
            (bytes32 artistId, bytes32[] memory records) =
                abi.decode(call_[4:], (bytes32, bytes32[]));
            if (
                artistId == 0 || _identity.identities[artistId].authorityAddress == address(0)
                    || _identity.identities[artistId].status != 4
            ) revert T.InvalidIdentity(artistId);
            return StreamArtistRecoveryOwnerReads.authorityRole(
                _identityRecovery, _rotations, artistId, records
            );
        }
        if (selector == bytes4(keccak256("guardianVestingSnapshot(bytes32,bytes32)"))) {
            (bytes32 artistId, bytes32 recordHash) = abi.decode(call_[4:], (bytes32, bytes32));
            return StreamArtistGuardianVestingHistory.encoded(
                _identityRecovery.vestingHistory, artistId, recordHash
            );
        }
        if (selector == bytes4(keccak256("guardianHistoryState(bytes32,uint64,address,bytes32)"))) {
            (bytes32 artistId, uint64 index, address actor, bytes32 actionId) =
                abi.decode(call_[4:], (bytes32, uint64, address, bytes32));
            return StreamArtistRecoveryOwnerReads.history(
                _identityRecovery, artistId, index, actor, actionId
            );
        }
        if (selector == bytes4(keccak256("identityRecoveryActionState(bytes32,bytes32)"))) {
            (bytes32 artistId, bytes32 actionId) = abi.decode(call_[4:], (bytes32, bytes32));
            return StreamArtistRecoveryOwnerReads.action(_identityRecovery, artistId, actionId);
        }
        if (
            selector
                == bytes4(
                    keccak256(
                        "identityRecoveryContext((bytes32,address,uint8,bytes32,bytes32,bytes32,bytes32,bytes32[]),(uint256,uint64,bytes))"
                    )
                )
        ) {
            (IdentityRecovery.Request memory p, T.Authorization memory a) =
                abi.decode(call_[4:], (IdentityRecovery.Request, T.Authorization));
            return StreamArtistDormancyRecovery.contextEncoded(
                _identityRecovery,
                _identity,
                _rotations,
                _resolutions,
                _estate,
                _dormancy,
                _succession,
                _identityContests,
                o,
                p,
                a
            );
        }
        if (selector == bytes4(keccak256("identityRecoveryRecord(bytes32)"))) {
            (bytes32 record) = abi.decode(call_[4:], (bytes32));
            return StreamArtistRecoveryOwnerReads.record(_identityRecovery, record);
        }
        if (
            selector
                == bytes4(
                    keccak256(
                        "identityContestDismissalContext((bytes32,bytes32,bytes32,bytes32,bytes32,bool,bytes32))"
                    )
                )
        ) {
            (Dismissal.Request memory p) = abi.decode(call_[4:], (Dismissal.Request));
            return StreamArtistIdentityResolutionReads.context(
                _resolutions,
                _identity,
                _rotations,
                _identityRevisions,
                _succession,
                o.environment,
                p
            );
        }
        if (selector == bytes4(keccak256("currentIdentityContestCause(bytes32)"))) {
            (bytes32 artistId) = abi.decode(call_[4:], (bytes32));
            return StreamArtistIdentityResolutionReads.currentCause(_resolutions, artistId);
        }
        if (selector == bytes4(keccak256("identityContestCause(bytes32)"))) {
            (bytes32 hash) = abi.decode(call_[4:], (bytes32));
            return StreamArtistIdentityResolutionReads.cause(_resolutions, hash);
        }
        if (selector == bytes4(keccak256("identityContestDismissalRecord(bytes32)"))) {
            (bytes32 hash) = abi.decode(call_[4:], (bytes32));
            return StreamArtistIdentityResolutionReads.record(_resolutions, hash);
        }
        if (selector == bytes4(keccak256("latestIdentityContestDismissal(bytes32)"))) {
            (bytes32 artistId) = abi.decode(call_[4:], (bytes32));
            return StreamArtistIdentityResolutionReads.latest(_resolutions, artistId);
        }
        if (selector == bytes4(keccak256("identityTransitionClosure(bytes32,bytes32)"))) {
            (bytes32 artistId, bytes32 transition) = abi.decode(call_[4:], (bytes32, bytes32));
            return StreamArtistIdentityResolutionReads.closure(_resolutions, artistId, transition);
        }
        if (selector == bytes4(keccak256("identityRevisionContinuation(bytes32)"))) {
            (bytes32 hash) = abi.decode(call_[4:], (bytes32));
            return StreamArtistIdentityResolutionReads.continuation(_resolutions, hash);
        }
        if (selector == bytes4(keccak256("identityContestRecord(bytes32)"))) {
            (bytes32 record) = abi.decode(call_[4:], (bytes32));
            return StreamArtistRecoveryOwnerReads.contest(_identityContests, record);
        }
        if (selector == bytes4(keccak256("identityRevisionRecord(bytes32)"))) {
            (bytes32 record) = abi.decode(call_[4:], (bytes32));
            return
                StreamArtistIdentityPayloadReads.identityRevisionRecord(_identityRevisions, record);
        }
        if (selector == bytes4(keccak256("operativeIdentityMetadata(bytes32)"))) {
            (bytes32 artistId) = abi.decode(call_[4:], (bytes32));
            return StreamArtistIdentityPayloadReads.operativeIdentityMetadata(
                _identityRevisions, _identity, _rotations, artistId
            );
        }
        if (selector == bytes4(keccak256("artistDisplayName(bytes32)"))) {
            (bytes32 artistId) = abi.decode(call_[4:], (bytes32));
            return StreamArtistIdentityPayloadReads.artistDisplayName(
                _identityRevisions, _identity, _rotations, artistId
            );
        }
        if (selector == bytes4(keccak256("artistAuthorizationState(bytes32,bytes32,uint256)"))) {
            (bytes32 artistId, bytes32 digest, uint256 nonce) =
                abi.decode(call_[4:], (bytes32, bytes32, uint256));
            return StreamArtistIdentityPayloadReads.artistAuthorizationState(
                _identity, _replay, o, artistId, digest, nonce
            );
        }
        if (selector == bytes4(keccak256("guardianSet(bytes32)"))) {
            (bytes32 artistId) = abi.decode(call_[4:], (bytes32));
            return
                StreamArtistRecoveryOwnerReads.guardianSet(_identityRecovery, _rotations, artistId);
        }
        if (selector == bytes4(keccak256("pendingRotation(bytes32)"))) {
            (bytes32 artistId) = abi.decode(call_[4:], (bytes32));
            return StreamArtistIdentityResolutionReads.pendingRotation(_rotations, artistId);
        }
        if (selector == bytes4(keccak256("guardianSetRecord(bytes32)"))) {
            (bytes32 record) = abi.decode(call_[4:], (bytes32));
            return StreamArtistIdentityResolutionReads.guardian(_rotations, record);
        }
        if (selector == bytes4(keccak256("rotationRecord(bytes32)"))) {
            (bytes32 record) = abi.decode(call_[4:], (bytes32));
            return StreamArtistIdentityResolutionReads.rotation(_rotations, record);
        }
        if (selector == bytes4(keccak256("standingRevocationRecord(bytes32)"))) {
            (bytes32 record) = abi.decode(call_[4:], (bytes32));
            return StreamArtistIdentityResolutionReads.standingRevocationRecord(_rotations, record);
        }
        if (selector == bytes4(keccak256("artistTransitionState(bytes32)"))) {
            (bytes32 record) = abi.decode(call_[4:], (bytes32));
            return _dormancy.transitions[record].recordHash != bytes32(0)
                ? abi.encode(_dormancy.transitions[record])
                : StreamArtistIdentityResolutionReads.artistTransitionState(
                    _rotations, _estate, _identityRecovery, record
                );
        }
        if (selector == bytes4(keccak256("identityRevisionProvisionalAssociation(bytes32)"))) {
            (bytes32 record) = abi.decode(call_[4:], (bytes32));
            return StreamArtistIdentityPayloadReads.identityRevisionProvisionalAssociation(
                _identityRevisions, record
            );
        }
        if (selector == bytes4(keccak256("identity(bytes32)"))) {
            (bytes32 artistId) = abi.decode(call_[4:], (bytes32));
            return StreamArtistIdentityResolutionReads.identity(_identity, artistId);
        }
        if (selector == bytes4(keccak256("identityDocumentBytes(bytes32)"))) {
            (bytes32 documentHash) = abi.decode(call_[4:], (bytes32));
            return StreamArtistIdentityPayloadReads.identityDocumentBytes(_identity, documentHash);
        }
        if (selector == bytes4(keccak256("signatureBundle(bytes32)"))) {
            (bytes32 recordHash) = abi.decode(call_[4:], (bytes32));
            return StreamArtistIdentityPayloadReads.signatureBundle(_identity, recordHash);
        }
        if (selector == bytes4(keccak256("delegationRecord(bytes32)"))) {
            (bytes32 grant) = abi.decode(call_[4:], (bytes32));
            return StreamArtistIdentityResolutionReads.delegation(_delegations, grant);
        }
        if (selector == bytes4(keccak256("dormancyState(bytes32)"))) {
            (bytes32 id) = abi.decode(call_[4:], (bytes32));
            return StreamArtistDormancyReadEncoding.state(_dormancy, _identity, id);
        }
        if (selector == bytes4(keccak256("dormancyNotice(bytes32)"))) {
            (bytes32 id) = abi.decode(call_[4:], (bytes32));
            return StreamArtistDormancyReadEncoding.notice(_dormancy, id);
        }
        if (selector == bytes4(keccak256("dormancyRecord(bytes32)"))) {
            (bytes32 n) = abi.decode(call_[4:], (bytes32));
            return StreamArtistDormancyReadEncoding.record(_dormancy, n);
        }
        if (selector == bytes4(keccak256("dormancyInitiationContext((bytes32,bytes32,string))"))) {
            (Dorm.Initiation memory p) = abi.decode(call_[4:], (Dorm.Initiation));
            return StreamArtistDormancyReadEncoding.initiation(
                _dormancy, _identity, _rotations, _estate, _resolutions, o.environment, p
            );
        }
        if (
            selector
                == bytes4(keccak256("dormancyCompletionContext((bytes32,bytes32,address,bytes32))"))
        ) {
            (Dorm.Completion memory p) = abi.decode(call_[4:], (Dorm.Completion));
            return StreamArtistDormancyReadEncoding.completion(
                _dormancy,
                _stewardGrants,
                _identity,
                _rotations,
                _estate,
                _succession,
                _resolutions,
                o.environment,
                p,
                false
            );
        }
        if (
            selector
                == bytes4(
                    keccak256("dormancyCompletionEvidence((bytes32,bytes32,address,bytes32))")
                )
        ) {
            (Dorm.Completion memory p) = abi.decode(call_[4:], (Dorm.Completion));
            return StreamArtistDormancyReadEncoding.completion(
                _dormancy,
                _stewardGrants,
                _identity,
                _rotations,
                _estate,
                _succession,
                _resolutions,
                o.environment,
                p,
                true
            );
        }
        if (selector == bytes4(keccak256("dormancyTransitionStanding(bytes32)"))) {
            (bytes32 record) = abi.decode(call_[4:], (bytes32));
            return StreamArtistDormancyReadEncoding.standing(_dormancy, record);
        }
        if (selector == bytes4(keccak256("dormancyResolutionState(bytes32,bytes32)"))) {
            (bytes32 id, bytes32 cause) = abi.decode(call_[4:], (bytes32, bytes32));
            return StreamArtistDormancyReadEncoding.resolution(_dormancy, id, cause);
        }
        if (selector == bytes4(keccak256("stewardSanctionGrantRecord(bytes32)"))) {
            (bytes32 hash) = abi.decode(call_[4:], (bytes32));
            return StreamArtistIdentityPayloadReads.stewardSanctionGrantRecord(_stewardGrants, hash);
        }
        if (
            selector
                == bytes4(
                    keccak256(
                        "stewardCapabilityGrantContext((bytes32,bytes32,address,bytes32,bytes32,uint32,uint32,bytes32,string))"
                    )
                )
        ) {
            (SC.Grant memory p) = abi.decode(call_[4:], (SC.Grant));
            return StreamArtistStewardCapabilityState.contextEncoded(
                _stewardCapabilityGrants,
                _dormancy,
                _identity,
                _rotations,
                _succession,
                o.environment,
                p
            );
        }
        if (selector == bytes4(keccak256("stewardCapabilityGrantRecord(bytes32)"))) {
            (bytes32 hash) = abi.decode(call_[4:], (bytes32));
            return StreamArtistStewardCapabilityState.recordEncoded(_stewardCapabilityGrants, hash);
        }
        revert T.InvalidRecord();
    }
}
