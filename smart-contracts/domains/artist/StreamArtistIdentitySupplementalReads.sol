// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "./StreamArtistIdentityHistoryMutation.sol";
import "./StreamArtistIdentityHydration.sol";
import "./StreamArtistHistoryState.sol";
import {
    StreamArtistHistoryTypes as H
} from "../../interfaces/stream/artist/IStreamArtistHistory.sol";
import { StreamArtistIdentityReadDispatch } from "./StreamArtistIdentityReadDispatch.sol";
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

/// @notice Fixed encoded projection of the remaining original Identity reads.
/// @dev Explicit original storage roots; read-only dispatch cannot mutate or acquire authority.
library StreamArtistIdentitySupplementalReads {
    struct ReplayRoot {
        mapping(bytes32 => T.ReplayCell) cells;
    }
    using StreamArtistNonceAvailability for StreamArtistNonceAvailability.Index;

    function read(
        uint256[15] memory roots,
        StreamArtistIdentityState.OwnerContext memory o,
        bytes calldata call_
    ) public view returns (bytes memory) {
        bytes4 selector = bytes4(call_[:4]);
        if (selector == bytes4(keccak256("authorityNonceWordAt(uint8,bytes32,uint256)"))) {
            StreamArtistIdentityState.State storage _identity;
            assembly ("memory-safe") { _identity.slot := mload(roots) }
            StreamArtistCollaboratorIdentityState.State storage _collaboratorAccounts;
            assembly ("memory-safe") { _collaboratorAccounts.slot := mload(add(roots, 32)) }
            StreamArtistDelegationState.State storage _delegations;
            assembly ("memory-safe") { _delegations.slot := mload(add(roots, 64)) }
            StreamArtistRotationState.State storage _rotations;
            assembly ("memory-safe") { _rotations.slot := mload(add(roots, 128)) }
            StreamArtistEstateState.State storage _estate;
            assembly ("memory-safe") { _estate.slot := mload(add(roots, 256)) }

            (uint8 kind, bytes32 key, uint256 index) =
                abi.decode(call_[4:], (uint8, bytes32, uint256));
            (uint256 v0, uint256[32] memory v1, bool v2) = _original_authorityNonceWordAt(
                _identity,
                _collaboratorAccounts,
                _delegations,
                _rotations,
                _estate,
                kind,
                key,
                index
            );
            return abi.encode(v0, v1, v2);
        }
        if (selector == bytes4(keccak256("recordPreimageBytes(bytes32)"))) {
            (bytes32 hash) = abi.decode(call_[4:], (bytes32));
            bytes memory v0 = _original_recordPreimageBytes(hash);
            return abi.encode(v0);
        }
        if (selector == bytes4(keccak256("storedPayloadCount()"))) {
            uint256 v0 = _original_storedPayloadCount();
            return abi.encode(v0);
        }
        if (selector == bytes4(keccak256("storedPayloadAt(uint256)"))) {
            (uint256 index) = abi.decode(call_[4:], (uint256));
            (address v0, bytes32 v1, bytes32 v2) = _original_storedPayloadAt(index);
            return abi.encode(v0, v1, v2);
        }
        if (selector == bytes4(keccak256("latestUnavailabilityFinding(bytes32,uint256)"))) {
            StreamArtistUnavailabilityState.State storage _unavailability;
            assembly ("memory-safe") { _unavailability.slot := mload(add(roots, 288)) }

            (bytes32 artistId, uint256 collectionId) = abi.decode(call_[4:], (bytes32, uint256));
            bytes32 v0 =
                _original_latestUnavailabilityFinding(_unavailability, artistId, collectionId);
            return abi.encode(v0);
        }
        if (
            selector
                == bytes4(
                    keccak256(
                        "unavailabilityFindingLive(bytes32,(bytes32,address,bytes32,bytes32,uint64,uint8,uint8,uint8,address,bool))"
                    )
                )
        ) {
            StreamArtistUnavailabilityState.State storage _unavailability;
            assembly ("memory-safe") { _unavailability.slot := mload(add(roots, 288)) }

            (bytes32 hash, T.Binding memory b) = abi.decode(call_[4:], (bytes32, T.Binding));
            bool v0 = _original_unavailabilityFindingLive(_unavailability, hash, b);
            return abi.encode(v0);
        }
        if (selector == bytes4(keccak256("estateActivationState(bytes32)"))) {
            StreamArtistEstateState.State storage _estate;
            assembly ("memory-safe") { _estate.slot := mload(add(roots, 256)) }

            (bytes32 artistId) = abi.decode(call_[4:], (bytes32));
            (address v0, uint64 v1, bytes32 v2) = _original_estateActivationState(_estate, artistId);
            return abi.encode(v0, v1, v2);
        }
        if (selector == bytes4(keccak256("estateActivationNonceHint(bytes32,address)"))) {
            StreamArtistEstateState.State storage _estate;
            assembly ("memory-safe") { _estate.slot := mload(add(roots, 256)) }

            (bytes32 artistId, address successor) = abi.decode(call_[4:], (bytes32, address));
            uint256 v0 = _original_estateActivationNonceHint(_estate, artistId, successor);
            return abi.encode(v0);
        }
        if (
            selector
                == bytes4(
                    keccak256(
                        "estateActivationDigest((bytes32,address,bytes32,bytes32,bytes32),(uint256,uint64,bytes))"
                    )
                )
        ) {
            (Estate.Request memory p, T.Authorization memory a) =
                abi.decode(call_[4:], (Estate.Request, T.Authorization));
            bytes32 v0 = _original_estateActivationDigest(o, p, a);
            return abi.encode(v0);
        }
        if (selector == bytes4(keccak256("estateTransitionStanding(bytes32)"))) {
            StreamArtistEstateState.State storage _estate;
            assembly ("memory-safe") { _estate.slot := mload(add(roots, 256)) }

            (bytes32 record) = abi.decode(call_[4:], (bytes32));
            (address v0, bytes32 v1, uint64 v2) =
                _original_estateTransitionStanding(_estate, record);
            return abi.encode(v0, v1, v2);
        }
        if (selector == bytes4(keccak256("operativeEstateDirective(bytes32)"))) {
            StreamArtistRotationState.State storage _rotations;
            assembly ("memory-safe") { _rotations.slot := mload(add(roots, 128)) }
            StreamArtistSuccessionState.State storage _succession;
            assembly ("memory-safe") { _succession.slot := mload(add(roots, 192)) }

            (bytes32 artistId) = abi.decode(call_[4:], (bytes32));
            bytes32 v0 = _original_operativeEstateDirective(_rotations, _succession, artistId);
            return abi.encode(v0);
        }
        if (selector == bytes4(keccak256("successorDesignation(bytes32)"))) {
            StreamArtistRotationState.State storage _rotations;
            assembly ("memory-safe") { _rotations.slot := mload(add(roots, 128)) }
            StreamArtistSuccessionState.State storage _succession;
            assembly ("memory-safe") { _succession.slot := mload(add(roots, 192)) }

            (bytes32 artistId) = abi.decode(call_[4:], (bytes32));
            (address v0, uint8 v1, uint32 v2, bytes32 v3, bytes32 v4, uint256 v5) =
                _original_successorDesignation(_rotations, _succession, artistId);
            return abi.encode(v0, v1, v2, v3, v4, v5);
        }

        if (selector == bytes4(keccak256("latestIdentityRecovery(bytes32)"))) {
            StreamArtistIdentityRecoveryState.State storage _identityRecovery;
            assembly ("memory-safe") { _identityRecovery.slot := mload(add(roots, 320)) }

            (bytes32 artistId) = abi.decode(call_[4:], (bytes32));
            bytes32 v0 = _original_latestIdentityRecovery(_identityRecovery, artistId);
            return abi.encode(v0);
        }
        if (selector == bytes4(keccak256("identityRecoveryReceipts(bytes32)"))) {
            StreamArtistIdentityRecoveryState.State storage _identityRecovery;
            assembly ("memory-safe") { _identityRecovery.slot := mload(add(roots, 320)) }

            (bytes32 record) = abi.decode(call_[4:], (bytes32));
            (bytes32 v0, bytes32 v1, bytes32 v2) =
                _original_identityRecoveryReceipts(_identityRecovery, record);
            return abi.encode(v0, v1, v2);
        }
        if (selector == bytes4(keccak256("recoveryTransitionStanding(bytes32)"))) {
            StreamArtistRotationState.State storage _rotations;
            assembly ("memory-safe") { _rotations.slot := mload(add(roots, 128)) }
            StreamArtistEstateState.State storage _estate;
            assembly ("memory-safe") { _estate.slot := mload(add(roots, 256)) }
            StreamArtistIdentityRecoveryState.State storage _identityRecovery;
            assembly ("memory-safe") { _identityRecovery.slot := mload(add(roots, 320)) }

            (bytes32 record) = abi.decode(call_[4:], (bytes32));
            (address v0, bytes32 v1, uint64 v2) =
                _original_recoveryTransitionStanding(_rotations, _estate, _identityRecovery, record);
            return abi.encode(v0, v1, v2);
        }
        if (selector == bytes4(keccak256("latestIdentityContest(bytes32)"))) {
            StreamArtistIdentityContestState.State storage _identityContests;
            assembly ("memory-safe") { _identityContests.slot := mload(add(roots, 160)) }

            (bytes32 artistId) = abi.decode(call_[4:], (bytes32));
            bytes32 v0 = _original_latestIdentityContest(_identityContests, artistId);
            return abi.encode(v0);
        }
        if (
            selector
                == bytes4(keccak256("identityContestContext((bytes32,bytes32,bytes32,bytes32))"))
        ) {
            StreamArtistIdentityState.State storage _identity;
            assembly ("memory-safe") { _identity.slot := mload(roots) }
            StreamArtistRotationState.State storage _rotations;
            assembly ("memory-safe") { _rotations.slot := mload(add(roots, 128)) }
            StreamArtistIdentityContestState.State storage _identityContests;
            assembly ("memory-safe") { _identityContests.slot := mload(add(roots, 160)) }
            StreamArtistSuccessionState.State storage _succession;
            assembly ("memory-safe") { _succession.slot := mload(add(roots, 192)) }
            StreamArtistIdentityResolutionState.State storage _resolutions;
            assembly ("memory-safe") { _resolutions.slot := mload(add(roots, 224)) }

            (Contest.Request memory p) = abi.decode(call_[4:], (Contest.Request));
            (bytes32 v0, bytes32 v1, bytes32 v2) = _original_identityContestContext(
                _identity, _rotations, _identityContests, _succession, _resolutions, o, p
            );
            return abi.encode(v0, v1, v2);
        }
        if (selector == bytes4(keccak256("identityRecordBytes(bytes32)"))) {
            StreamArtistIdentityState.State storage _identity;
            assembly ("memory-safe") { _identity.slot := mload(roots) }
            StreamArtistIdentityRevisionState.State storage _identityRevisions;
            assembly ("memory-safe") { _identityRevisions.slot := mload(add(roots, 96)) }
            StreamArtistRotationState.State storage _rotations;
            assembly ("memory-safe") { _rotations.slot := mload(add(roots, 128)) }

            (bytes32 artistId) = abi.decode(call_[4:], (bytes32));
            bytes memory v0 =
                _original_identityRecordBytes(_identity, _identityRevisions, _rotations, artistId);
            return abi.encode(v0);
        }
        if (selector == bytes4(keccak256("priorAddressStandingRevoked(bytes32,address)"))) {
            StreamArtistRotationState.State storage _rotations;
            assembly ("memory-safe") { _rotations.slot := mload(add(roots, 128)) }
            StreamArtistIdentityResolutionState.State storage _resolutions;
            assembly ("memory-safe") { _resolutions.slot := mload(add(roots, 224)) }

            (bytes32 artistId, address account) = abi.decode(call_[4:], (bytes32, address));
            (bool v0, bytes32 v1) =
                _original_priorAddressStandingRevoked(_rotations, _resolutions, artistId, account);
            return abi.encode(v0, v1);
        }
        if (selector == bytes4(keccak256("lastArtistTransition(bytes32)"))) {
            StreamArtistRotationState.State storage _rotations;
            assembly ("memory-safe") { _rotations.slot := mload(add(roots, 128)) }

            (bytes32 artistId) = abi.decode(call_[4:], (bytes32));
            bytes32 v0 = _original_lastArtistTransition(_rotations, artistId);
            return abi.encode(v0);
        }
        if (selector == bytes4(keccak256("activeAuthorityWindow(bytes32)"))) {
            StreamArtistRotationState.State storage _rotations;
            assembly ("memory-safe") { _rotations.slot := mload(add(roots, 128)) }
            StreamArtistIdentityResolutionState.State storage _resolutions;
            assembly ("memory-safe") { _resolutions.slot := mload(add(roots, 224)) }

            (bytes32 artistId) = abi.decode(call_[4:], (bytes32));
            (bytes32 v0, uint64 v1, bool v2) =
                _original_activeAuthorityWindow(_rotations, _resolutions, artistId);
            return abi.encode(v0, v1, v2);
        }
        if (selector == bytes4(keccak256("rotationAcceptanceNonceState(bytes32,address,uint256)")))
        {
            StreamArtistRotationState.State storage _rotations;
            assembly ("memory-safe") { _rotations.slot := mload(add(roots, 128)) }
            mapping(bytes32 => T.ReplayCell) storage _replay = _replayRoot(roots[14]).cells;

            (bytes32 artistId, address account, uint256 nonce) =
                abi.decode(call_[4:], (bytes32, address, uint256));
            (bool v0, uint256 v1) = _original_rotationAcceptanceNonceState(
                _rotations, _replay, o, artistId, account, nonce
            );
            return abi.encode(v0, v1);
        }
        if (selector == bytes4(keccak256("provisionalAssociation(bytes32)"))) {
            StreamArtistRotationState.State storage _rotations;
            assembly ("memory-safe") { _rotations.slot := mload(add(roots, 128)) }
            StreamArtistIdentityResolutionState.State storage _resolutions;
            assembly ("memory-safe") { _resolutions.slot := mload(add(roots, 224)) }

            (bytes32 artistId) = abi.decode(call_[4:], (bytes32));
            R.ProvisionalAssociation memory v0 =
                _original_provisionalAssociation(_rotations, _resolutions, artistId);
            return abi.encode(v0);
        }
        if (selector == bytes4(keccak256("provisionalRecordEligible(bytes32,(bytes32,uint64))"))) {
            StreamArtistRotationState.State storage _rotations;
            assembly ("memory-safe") { _rotations.slot := mload(add(roots, 128)) }

            (bytes32 artistId, R.ProvisionalAssociation memory a) =
                abi.decode(call_[4:], (bytes32, R.ProvisionalAssociation));
            bool v0 = _original_provisionalRecordEligible(_rotations, artistId, a);
            return abi.encode(v0);
        }
        if (selector == bytes4(keccak256("artistWindowInfo(bytes32)"))) {
            StreamArtistRotationState.State storage _rotations;
            assembly ("memory-safe") { _rotations.slot := mload(add(roots, 128)) }
            StreamArtistEstateState.State storage _estate;
            assembly ("memory-safe") { _estate.slot := mload(add(roots, 256)) }
            StreamArtistUnavailabilityState.State storage _unavailability;
            assembly ("memory-safe") { _unavailability.slot := mload(add(roots, 288)) }
            StreamArtistDormancyState.State storage _dormancy;
            assembly ("memory-safe") { _dormancy.slot := mload(add(roots, 352)) }

            (bytes32 parameter) = abi.decode(call_[4:], (bytes32));
            (uint64 v0, uint64 v1, uint64 v2) = _original_artistWindowInfo(
                _rotations, _estate, _unavailability, _dormancy, parameter
            );
            return abi.encode(v0, v1, v2);
        }
        if (selector == bytes4(keccak256("artistWindowScope(bytes32)"))) {
            StreamArtistRotationState.State storage _rotations;
            assembly ("memory-safe") { _rotations.slot := mload(add(roots, 128)) }
            StreamArtistEstateState.State storage _estate;
            assembly ("memory-safe") { _estate.slot := mload(add(roots, 256)) }
            StreamArtistUnavailabilityState.State storage _unavailability;
            assembly ("memory-safe") { _unavailability.slot := mload(add(roots, 288)) }
            StreamArtistDormancyState.State storage _dormancy;
            assembly ("memory-safe") { _dormancy.slot := mload(add(roots, 352)) }

            (bytes32 parameter) = abi.decode(call_[4:], (bytes32));
            bytes32 v0 = _original_artistWindowScope(
                _rotations, _estate, _unavailability, _dormancy, parameter
            );
            return abi.encode(v0);
        }
        if (selector == bytes4(keccak256("artistWindowStateHash(bytes32,uint64,uint64)"))) {
            StreamArtistRotationState.State storage _rotations;
            assembly ("memory-safe") { _rotations.slot := mload(add(roots, 128)) }
            StreamArtistEstateState.State storage _estate;
            assembly ("memory-safe") { _estate.slot := mload(add(roots, 256)) }
            StreamArtistUnavailabilityState.State storage _unavailability;
            assembly ("memory-safe") { _unavailability.slot := mload(add(roots, 288)) }
            StreamArtistDormancyState.State storage _dormancy;
            assembly ("memory-safe") { _dormancy.slot := mload(add(roots, 352)) }

            (bytes32 parameter, uint64 value, uint64 revision) =
                abi.decode(call_[4:], (bytes32, uint64, uint64));
            bytes32 v0 = _original_artistWindowStateHash(
                _rotations, _estate, _unavailability, _dormancy, parameter, value, revision
            );
            return abi.encode(v0);
        }
        if (selector == bytes4(keccak256("nextRegistrationNonce()"))) {
            StreamArtistIdentityState.State storage _identity;
            assembly ("memory-safe") { _identity.slot := mload(roots) }

            uint256 v0 = _original_nextRegistrationNonce(_identity);
            return abi.encode(v0);
        }
        if (selector == bytes4(keccak256("activeIdentity(address)"))) {
            StreamArtistIdentityState.State storage _identity;
            assembly ("memory-safe") { _identity.slot := mload(roots) }

            (address account) = abi.decode(call_[4:], (address));
            bytes32 v0 = _original_activeIdentity(_identity, account);
            return abi.encode(v0);
        }
        if (selector == bytes4(keccak256("authorityState(bytes32)"))) {
            StreamArtistIdentityState.State storage _identity;
            assembly ("memory-safe") { _identity.slot := mload(roots) }

            (bytes32 artistId) = abi.decode(call_[4:], (bytes32));
            (address v0, uint8 v1, uint8 v2, bytes32 v3) =
                _original_authorityState(_identity, artistId);
            return abi.encode(v0, v1, v2, v3);
        }
        if (selector == bytes4(keccak256("delegationEpochState(bytes32)"))) {
            StreamArtistDelegationState.State storage _delegations;
            assembly ("memory-safe") { _delegations.slot := mload(add(roots, 64)) }
            StreamArtistEstateState.State storage _estate;
            assembly ("memory-safe") { _estate.slot := mload(add(roots, 256)) }

            (bytes32 grant) = abi.decode(call_[4:], (bytes32));
            (bool v0, uint64 v1, uint64 v2) =
                _original_delegationEpochState(_delegations, _estate, grant);
            return abi.encode(v0, v1, v2);
        }
        if (selector == bytes4(keccak256("collaboratorRegistrationNonceState(address,uint256)"))) {
            StreamArtistCollaboratorIdentityState.State storage _collaboratorAccounts;
            assembly ("memory-safe") { _collaboratorAccounts.slot := mload(add(roots, 32)) }
            mapping(bytes32 => T.ReplayCell) storage _replay = _replayRoot(roots[14]).cells;

            (address account, uint256 nonce) = abi.decode(call_[4:], (address, uint256));
            (bool v0, uint256 v1) = _original_collaboratorRegistrationNonceState(
                _collaboratorAccounts, _replay, o, account, nonce
            );
            return abi.encode(v0, v1);
        }
        if (selector == bytes4(keccak256("delegatedNonceState(bytes32,address,uint256)"))) {
            StreamArtistDelegationState.State storage _delegations;
            assembly ("memory-safe") { _delegations.slot := mload(add(roots, 64)) }
            mapping(bytes32 => T.ReplayCell) storage _replay = _replayRoot(roots[14]).cells;

            (bytes32 artistId, address delegate, uint256 nonce) =
                abi.decode(call_[4:], (bytes32, address, uint256));
            (bool v0, uint256 v1) =
                _original_delegatedNonceState(_delegations, _replay, o, artistId, delegate, nonce);
            return abi.encode(v0, v1);
        }
        if (selector == bytes4(keccak256("stewardSanctionGrant(bytes32)"))) {
            StreamArtistRotationState.State storage _rotations;
            assembly ("memory-safe") { _rotations.slot := mload(add(roots, 128)) }
            StreamArtistStewardSanctionState.State storage _stewardGrants;
            assembly ("memory-safe") { _stewardGrants.slot := mload(add(roots, 384)) }

            (bytes32 id) = abi.decode(call_[4:], (bytes32));
            (bool v0, bytes32 v1) = _original_stewardSanctionGrant(_rotations, _stewardGrants, id);
            return abi.encode(v0, v1);
        }
        if (selector == bytes4(keccak256("stewardSanctionGrantSignature(bytes32)"))) {
            StreamArtistIdentityState.State storage _identity;
            assembly ("memory-safe") { _identity.slot := mload(roots) }

            (bytes32 hash) = abi.decode(call_[4:], (bytes32));
            bytes memory v0 = _original_stewardSanctionGrantSignature(_identity, hash);
            return abi.encode(v0);
        }
        if (
            selector
                == bytes4(
                    keccak256(
                        "stewardSanctionGrantDigest((bytes32,bool,bytes32),(uint256,uint64,bytes))"
                    )
                )
        ) {
            (SG.Grant memory p, T.Authorization memory a) =
                abi.decode(call_[4:], (SG.Grant, T.Authorization));
            bytes32 v0 = _original_stewardSanctionGrantDigest(o, p, a);
            return abi.encode(v0);
        }
        if (selector == bytes4(keccak256("stewardCapabilityGrantState(bytes32)"))) {
            StreamArtistStewardCapabilityState.State storage _stewardCapabilityGrants;
            assembly ("memory-safe") { _stewardCapabilityGrants.slot := mload(add(roots, 416)) }

            (bytes32 appointment) = abi.decode(call_[4:], (bytes32));
            (bytes32 v0, uint32 v1) =
                _original_stewardCapabilityGrantState(_stewardCapabilityGrants, appointment);
            return abi.encode(v0, v1);
        }
        if (selector == bytes4(keccak256("artistRecordChainHash(bytes32)"))) {
            (bytes32 id) = abi.decode(call_[4:], (bytes32));
            bytes32 v0 = _original_artistRecordChainHash(id);
            return abi.encode(v0);
        }
        if (selector == bytes4(keccak256("collectionRecordChainHash(uint256)"))) {
            (uint256 id) = abi.decode(call_[4:], (uint256));
            bytes32 v0 = _original_collectionRecordChainHash(id);
            return abi.encode(v0);
        }
        if (selector == bytes4(keccak256("artistHistoryLane(uint8,bytes32)"))) {
            (uint8 kind, bytes32 id) = abi.decode(call_[4:], (uint8, bytes32));
            (bytes32 v0, uint64 v1) = _original_artistHistoryLane(kind, id);
            return abi.encode(v0, v1);
        }
        if (selector == bytes4(keccak256("artistHistoryRecordAt(uint8,bytes32,uint64)"))) {
            (uint8 kind, bytes32 id, uint64 index) = abi.decode(call_[4:], (uint8, bytes32, uint64));
            (bytes32 v0, bytes32 v1) = _original_artistHistoryRecordAt(o, kind, id, index);
            return abi.encode(v0, v1);
        }
        if (selector == bytes4(keccak256("artistHistoryContinuityCommitment()"))) {
            bytes32 v0 = _original_artistHistoryContinuityCommitment();
            return abi.encode(v0);
        }
        if (selector == bytes4(keccak256("artistHistorySourceCursor(address)"))) {
            (address source) = abi.decode(call_[4:], (address));
            uint256 v0 = _original_artistHistorySourceCursor(source);
            return abi.encode(v0);
        }
        if (selector == bytes4(keccak256("importedHistoryBindingCount()"))) {
            uint256 v0 = _original_importedHistoryBindingCount();
            return abi.encode(v0);
        }
        if (selector == bytes4(keccak256("importedHistoryBinding(uint256)"))) {
            (uint256 index) = abi.decode(call_[4:], (uint256));
            (address v0, uint64 v1, bytes32 v2, bytes32 v3) =
                _original_importedHistoryBinding(index);
            return abi.encode(v0, v1, v2, v3);
        }
        if (selector == bytes4(keccak256("artistHistoryPredecessorBinding(address)"))) {
            (address source) = abi.decode(call_[4:], (address));
            (bool v0, bytes32 v1, uint256 v2) = _original_artistHistoryPredecessorBinding(source);
            return abi.encode(v0, v1, v2);
        }
        if (
            selector
                == bytes4(
                    keccak256(
                        "verifyImportedRecord(bytes32,(uint8,bytes32,uint64,bytes32,bytes32),bytes32[])"
                    )
                )
        ) {
            (bytes32 root, H.Leaf memory p, bytes32[] memory proof) =
                abi.decode(call_[4:], (bytes32, H.Leaf, bytes32[]));
            bool v0 = _original_verifyImportedRecord(root, p, proof);
            return abi.encode(v0);
        }
        if (selector == bytes4(keccak256("importedLaneVerified(uint8,bytes32)"))) {
            (uint8 kind, bytes32 id) = abi.decode(call_[4:], (uint8, bytes32));
            (bool v0, bytes32 v1, uint64 v2) = _original_importedLaneVerified(kind, id);
            return abi.encode(v0, v1, v2);
        }
        if (selector == bytes4(keccak256("artistRegistryCutover()"))) {
            (bool v0, address v1, uint64 v2) = _original_artistRegistryCutover();
            return abi.encode(v0, v1, v2);
        }
        if (
            selector
                == bytes4(keccak256("artistHistoryImportContext(address,uint64,bytes32,bytes32)"))
        ) {
            (address predecessor, uint64 snapshot, bytes32 root, bytes32 manifest) =
                abi.decode(call_[4:], (address, uint64, bytes32, bytes32));
            H.Context memory v0 =
                _original_artistHistoryImportContext(o, predecessor, snapshot, root, manifest);
            return abi.encode(v0);
        }
        revert T.InvalidRecord();
    }

    function _original_authorityNonceWordAt(
        StreamArtistIdentityState.State storage _identity,
        StreamArtistCollaboratorIdentityState.State storage _collaboratorAccounts,
        StreamArtistDelegationState.State storage _delegations,
        StreamArtistRotationState.State storage _rotations,
        StreamArtistEstateState.State storage _estate,
        uint8 kind,
        bytes32 key,
        uint256 index
    ) private view returns (uint256 prefix, uint256[32] memory words, bool exhausted) {
        prefix = StreamArtistAuthorityCheckpoint.noncePrefixAt(kind, key, index);
        if (kind == 1) {
            (words, exhausted) = _identity.nonceAvailability[key].checkpointWords(prefix);
        } else if (kind == 2) {
            (words, exhausted) = _delegations.availability[key].checkpointWords(prefix);
        } else if (kind == 3 && uint256(key) >> 160 == 0) {
            (words, exhausted) = _collaboratorAccounts.available[address(
                    uint160(uint256(key))
                )].checkpointWords(prefix);
        } else if (kind == 4) {
            (words, exhausted) = _rotations.acceptanceNonces[key].checkpointWords(prefix);
        } else if (kind == 5) {
            (words, exhausted) = _estate.nonceAvailability[key].checkpointWords(prefix);
        } else {
            revert StreamArtistAuthorityCheckpoint.InvalidAuthorityCheckpoint();
        }
    }

    function _original_recordPreimageBytes(bytes32 hash) private view returns (bytes memory) {
        return StreamArtistPayloadStore.recordBytes(hash);
    }

    function _original_storedPayloadCount() private view returns (uint256) {
        return StreamArtistPayloadStore.count();
    }

    function _original_storedPayloadAt(uint256 index)
        private
        view
        returns (address, bytes32, bytes32)
    {
        return StreamArtistPayloadStore.at(index);
    }

    function _original_latestUnavailabilityFinding(
        StreamArtistUnavailabilityState.State storage _unavailability,
        bytes32 artistId,
        uint256 collectionId
    ) private view returns (bytes32) {
        return _unavailability.latest[
            StreamArtistUnavailabilityState.associationKey(artistId, collectionId)
        ];
    }

    function _original_unavailabilityFindingLive(
        StreamArtistUnavailabilityState.State storage _unavailability,
        bytes32 hash,
        T.Binding memory b
    ) private view returns (bool) {
        return StreamArtistUnavailabilityState.live(_unavailability, hash, b);
    }

    function _original_estateActivationState(
        StreamArtistEstateState.State storage _estate,
        bytes32 artistId
    ) private view returns (address, uint64, bytes32) {
        bytes32 hash = _estate.pending[artistId];
        Estate.RequestRecord storage item = _estate.requests[hash];
        return (item.terms.successor, item.noticeEndsAt, hash);
    }

    function _original_estateActivationNonceHint(
        StreamArtistEstateState.State storage _estate,
        bytes32 artistId,
        address successor
    ) private view returns (uint256) {
        return _estate.nonceHints[StreamArtistEstateState.nonceLane(artistId, successor)];
    }

    function _original_estateActivationDigest(
        StreamArtistIdentityState.OwnerContext memory o,
        Estate.Request memory p,
        T.Authorization memory a
    ) private view returns (bytes32) {
        return StreamArtistEstateHashes.digest(o.environment, p, a);
    }

    function _original_estateTransitionStanding(
        StreamArtistEstateState.State storage _estate,
        bytes32 record
    ) private view returns (address, bytes32, uint64) {
        Estate.RequestRecord storage item = _estate.requests[record];
        if (record == bytes32(0) || item.recordHash != record || item.terms.artistId == bytes32(0))
        {
            revert R.InvalidRotation(record);
        }
        return (item.incumbent, item.guardianRecordHash, item.standingTailSeconds);
    }

    function _original_operativeEstateDirective(
        StreamArtistRotationState.State storage _rotations,
        StreamArtistSuccessionState.State storage _succession,
        bytes32 artistId
    ) private view returns (bytes32) {
        return StreamArtistSuccessionState.operativeDirective(_succession, _rotations, artistId);
    }

    function _original_successorDesignation(
        StreamArtistRotationState.State storage _rotations,
        StreamArtistSuccessionState.State storage _succession,
        bytes32 artistId
    ) private view returns (address, uint8, uint32, bytes32, bytes32, uint256) {
        Succ.DesignationRecord storage r = _succession.designations[
            StreamArtistSuccessionState.operativeDesignation(_succession, _rotations, artistId)
        ];
        return (
            r.terms.successor,
            r.terms.successorKind,
            r.terms.grantedCapabilities,
            r.terms.conditionsHash,
            r.terms.directiveHash,
            r.nonce
        );
    }

    function _original_latestIdentityRecovery(
        StreamArtistIdentityRecoveryState.State storage _identityRecovery,
        bytes32 artistId
    ) private view returns (bytes32) {
        return _identityRecovery.latest[artistId];
    }

    function _original_identityRecoveryReceipts(
        StreamArtistIdentityRecoveryState.State storage _identityRecovery,
        bytes32 record
    ) private view returns (bytes32, bytes32, bytes32) {
        return StreamArtistIdentityRecoveryState.receiptCommitments(_identityRecovery, record);
    }

    function _original_recoveryTransitionStanding(
        StreamArtistRotationState.State storage _rotations,
        StreamArtistEstateState.State storage _estate,
        StreamArtistIdentityRecoveryState.State storage _identityRecovery,
        bytes32 record
    ) private view returns (address, bytes32, uint64) {
        return StreamArtistRecoveryOwnerReads.standing(
            _identityRecovery, _rotations, _estate, record
        );
    }

    function _original_latestIdentityContest(
        StreamArtistIdentityContestState.State storage _identityContests,
        bytes32 artistId
    ) private view returns (bytes32) {
        return _identityContests.latest[artistId];
    }

    function _original_identityContestContext(
        StreamArtistIdentityState.State storage _identity,
        StreamArtistRotationState.State storage _rotations,
        StreamArtistIdentityContestState.State storage _identityContests,
        StreamArtistSuccessionState.State storage _succession,
        StreamArtistIdentityResolutionState.State storage _resolutions,
        StreamArtistIdentityState.OwnerContext memory o,
        Contest.Request memory p
    ) private view returns (bytes32, bytes32, bytes32) {
        return StreamArtistIdentityCauseState.context(
            _resolutions, _identity, _rotations, _identityContests, _succession, o, p
        );
    }

    function _original_identityRecordBytes(
        StreamArtistIdentityState.State storage _identity,
        StreamArtistIdentityRevisionState.State storage _identityRevisions,
        StreamArtistRotationState.State storage _rotations,
        bytes32 artistId
    ) private view returns (bytes memory) {
        return _identity.documents[
            StreamArtistIdentityRevisionState.operative(
                _identityRevisions, _identity, _rotations, artistId
            )
        ];
    }

    function _original_priorAddressStandingRevoked(
        StreamArtistRotationState.State storage _rotations,
        StreamArtistIdentityResolutionState.State storage _resolutions,
        bytes32 artistId,
        address account
    ) private view returns (bool, bytes32) {
        return StreamArtistIdentityDismissalState.standingRevoked(
            _resolutions, _rotations, artistId, account
        );
    }

    function _original_lastArtistTransition(
        StreamArtistRotationState.State storage _rotations,
        bytes32 artistId
    ) private view returns (bytes32) {
        return _rotations.latestTransition[artistId];
    }

    function _original_activeAuthorityWindow(
        StreamArtistRotationState.State storage _rotations,
        StreamArtistIdentityResolutionState.State storage _resolutions,
        bytes32 artistId
    ) private view returns (bytes32, uint64, bool) {
        return StreamArtistRotationState.activeWindowWithResolution(
            _rotations, artistId, _resolutions.closures[_rotations.latestExecution[artistId]]
        );
    }

    function _original_rotationAcceptanceNonceState(
        StreamArtistRotationState.State storage _rotations,
        mapping(bytes32 => T.ReplayCell) storage _replay,
        StreamArtistIdentityState.OwnerContext memory o,
        bytes32 artistId,
        address account,
        uint256 nonce
    ) private view returns (bool, uint256) {
        return StreamArtistRotationState.acceptanceNonceState(
            _rotations, _replay, o, artistId, account, nonce
        );
    }

    function _original_provisionalAssociation(
        StreamArtistRotationState.State storage _rotations,
        StreamArtistIdentityResolutionState.State storage _resolutions,
        bytes32 artistId
    ) private view returns (R.ProvisionalAssociation memory) {
        return StreamArtistRotationState.associationWithResolution(
            _rotations, artistId, _resolutions.closures[_rotations.latestExecution[artistId]]
        );
    }

    function _original_provisionalRecordEligible(
        StreamArtistRotationState.State storage _rotations,
        bytes32 artistId,
        R.ProvisionalAssociation memory a
    ) private view returns (bool) {
        return StreamArtistRotationState.eligible(_rotations, artistId, a);
    }

    function _original_artistWindowInfo(
        StreamArtistRotationState.State storage _rotations,
        StreamArtistEstateState.State storage _estate,
        StreamArtistUnavailabilityState.State storage _unavailability,
        StreamArtistDormancyState.State storage _dormancy,
        bytes32 parameter
    ) private view returns (uint64, uint64, uint64) {
        return StreamArtistWindowConfiguration.info(
            _rotations, _estate, _unavailability, _dormancy, parameter
        );
    }

    function _original_artistWindowScope(
        StreamArtistRotationState.State storage _rotations,
        StreamArtistEstateState.State storage _estate,
        StreamArtistUnavailabilityState.State storage _unavailability,
        StreamArtistDormancyState.State storage _dormancy,
        bytes32 parameter
    ) private view returns (bytes32) {
        return StreamArtistWindowConfiguration.scope(
            _rotations, _estate, _unavailability, _dormancy, parameter
        );
    }

    function _original_artistWindowStateHash(
        StreamArtistRotationState.State storage _rotations,
        StreamArtistEstateState.State storage _estate,
        StreamArtistUnavailabilityState.State storage _unavailability,
        StreamArtistDormancyState.State storage _dormancy,
        bytes32 parameter,
        uint64 value,
        uint64 revision
    ) private view returns (bytes32) {
        return StreamArtistWindowConfiguration.stateHash(
            _rotations, _estate, _unavailability, _dormancy, parameter, value, revision
        );
    }

    function _original_nextRegistrationNonce(StreamArtistIdentityState.State storage _identity)
        private
        view
        returns (uint256)
    {
        return _identity.nextRegistrationNonce;
    }

    function _original_activeIdentity(
        StreamArtistIdentityState.State storage _identity,
        address account
    ) private view returns (bytes32) {
        return _identity.activeIdentity[account];
    }

    function _original_authorityState(
        StreamArtistIdentityState.State storage _identity,
        bytes32 artistId
    )
        private
        view
        returns (
            address authorityAddress,
            uint8 authorityClass,
            uint8 status,
            bytes32 identityRecordHash
        )
    {
        T.Identity storage item = _identity.identities[artistId];
        return (item.authorityAddress, item.authorityClass, item.status, item.identityRecordHash);
    }

    function _original_delegationEpochState(
        StreamArtistDelegationState.State storage _delegations,
        StreamArtistEstateState.State storage _estate,
        bytes32 grant
    ) private view returns (bool valid, uint64 recorded, uint64 current) {
        D.Record storage item = _delegations.records[grant];
        recorded = _estate.grantEpoch[grant];
        current = _estate.delegationEpoch[item.grant.artistId];
        valid = item.grantor != address(0) && recorded == current;
    }

    function _original_collaboratorRegistrationNonceState(
        StreamArtistCollaboratorIdentityState.State storage _collaboratorAccounts,
        mapping(bytes32 => T.ReplayCell) storage _replay,
        StreamArtistIdentityState.OwnerContext memory o,
        address account,
        uint256 nonce
    ) private view returns (bool, uint256) {
        return StreamArtistCollaboratorIdentityState.nonceState(
            _collaboratorAccounts, _replay, o, account, nonce
        );
    }

    function _original_delegatedNonceState(
        StreamArtistDelegationState.State storage _delegations,
        mapping(
            bytes32 => T.ReplayCell
        ) storage _replay,
        StreamArtistIdentityState.OwnerContext memory o,
        bytes32 artistId,
        address delegate,
        uint256 nonce
    ) private view returns (bool, uint256) {
        bytes32 lane = StreamArtistDelegationState.lane(artistId, delegate);
        return (
            _replay[_replayKey(
                        o,
                        keccak256("identity_authority.replay.delegated_nonce"),
                        keccak256(abi.encode(lane, nonce))
                    )].status != 0,
            _delegations.hints[lane]
        );
    }

    function _original_stewardSanctionGrant(
        StreamArtistRotationState.State storage _rotations,
        StreamArtistStewardSanctionState.State storage _stewardGrants,
        bytes32 id
    ) private view returns (bool, bytes32) {
        return StreamArtistStewardSanctionState.current(_stewardGrants, _rotations, id);
    }

    function _original_stewardSanctionGrantSignature(
        StreamArtistIdentityState.State storage _identity,
        bytes32 hash
    ) private view returns (bytes memory) {
        return _identity.signatures[hash];
    }

    function _original_stewardSanctionGrantDigest(
        StreamArtistIdentityState.OwnerContext memory o,
        SG.Grant memory p,
        T.Authorization memory a
    ) private view returns (bytes32) {
        return StreamArtistStewardSanctionState.digest(o.environment, p, a);
    }

    function _original_stewardCapabilityGrantState(
        StreamArtistStewardCapabilityState.State storage _stewardCapabilityGrants,
        bytes32 appointment
    ) private view returns (bytes32, uint32) {
        return
            (
                _stewardCapabilityGrants.head[appointment],
                _stewardCapabilityGrants.added[appointment]
            );
    }

    function _original_artistRecordChainHash(bytes32 id) private view returns (bytes32 tip) {
        (tip,) = StreamArtistHistoryState.lane(1, id);
    }

    function _original_collectionRecordChainHash(uint256 id) private view returns (bytes32 tip) {
        (tip,) = StreamArtistHistoryState.lane(2, bytes32(id));
    }

    function _original_artistHistoryLane(uint8 kind, bytes32 id)
        private
        view
        returns (bytes32, uint64)
    {
        return StreamArtistHistoryState.lane(kind, id);
    }

    function _original_artistHistoryRecordAt(
        StreamArtistIdentityState.OwnerContext memory o,
        uint8 kind,
        bytes32 id,
        uint64 index
    ) private view returns (bytes32, bytes32) {
        return StreamArtistHistoryState.at(
            o.environment.core,
            o.environment.registry,
            kind,
            id,
            index,
            StreamArtistHistoryProof.cap(o.environment.registry)
        );
    }

    function _original_artistHistoryContinuityCommitment() private view returns (bytes32) {
        return StreamArtistHistoryState.commitment();
    }

    function _original_artistHistorySourceCursor(address source) private view returns (uint256) {
        return StreamArtistHistoryState.cursor(source);
    }

    function _original_importedHistoryBindingCount() private view returns (uint256) {
        return StreamArtistHistoryState.bindingCount();
    }

    function _original_importedHistoryBinding(uint256 index)
        private
        view
        returns (address, uint64, bytes32, bytes32)
    {
        H.Binding memory b = StreamArtistHistoryState.binding(index);
        return (b.predecessorRegistry, b.snapshotBlock, b.importRoot, b.manifestHash);
    }

    function _original_artistHistoryPredecessorBinding(address source)
        private
        view
        returns (bool, bytes32, uint256)
    {
        return StreamArtistHistoryState.predecessorBinding(source);
    }

    function _original_verifyImportedRecord(bytes32 root, H.Leaf memory p, bytes32[] memory proof)
        private
        view
        returns (bool)
    {
        return StreamArtistHistoryState.verifyRecord(root, p, proof);
    }

    function _original_importedLaneVerified(uint8 kind, bytes32 id)
        private
        view
        returns (bool, bytes32, uint64)
    {
        return StreamArtistHistoryState.verified(kind, id);
    }

    function _original_artistRegistryCutover() private view returns (bool, address, uint64) {
        return StreamArtistHistoryState.cutover();
    }

    function _original_artistHistoryImportContext(
        StreamArtistIdentityState.OwnerContext memory o,
        address predecessor,
        uint64 snapshot,
        bytes32 root,
        bytes32 manifest
    ) private view returns (H.Context memory) {
        return StreamArtistHistoryState.context(
            o.environment.registry, H.Binding(predecessor, snapshot, root, manifest)
        );
    }

    function _replayKey(
        StreamArtistIdentityState.OwnerContext memory o,
        bytes32 surface,
        bytes32 scope
    ) private view returns (bytes32) {
        return keccak256(
            abi.encode(
                keccak256("6529STREAM_ARTIST_OWNER_REPLAY_KEY_V2"),
                o.environment.chainId,
                o.environment.registry,
                o.coordinator,
                o.archive,
                address(this),
                o.domain,
                surface,
                scope
            )
        );
    }

    function _replayRoot(uint256 slot) private pure returns (ReplayRoot storage r) {
        assembly ("memory-safe") { r.slot := slot }
    }
}
