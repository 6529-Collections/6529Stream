// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    StreamCurrentAuthorityScopedPreservationPolicyInventoryFixture
} from "./StreamCurrentAuthorityScopedPreservationPolicyInventoryFixture.sol";
import {
    StreamFinalityScope
} from "../../smart-contracts/interfaces/stream/finality/StreamArtworkFinalityTypes.sol";
import {
    StreamMetadataSubjects
} from "../../smart-contracts/domains/metadata/StreamMetadataSubjects.sol";
import {
    StreamRightsRecordTypes as ScopedRights
} from "../../smart-contracts/interfaces/stream/metadata/StreamRightsRecordTypes.sol";
import {
    StreamRightsRecordDefinitions as ScopedRightsDefinitions
} from "../../smart-contracts/domains/records/StreamRightsRecordDefinitions.sol";
import {
    StreamRightsRecordJson as ScopedRightsJSON
} from "../../smart-contracts/domains/records/StreamRightsRecordJson.sol";
import {
    IStreamRightsRecordSelection as ScopedRightsSelection
} from "../../smart-contracts/interfaces/stream/metadata/IStreamRightsRecordSelection.sol";
import {
    IStreamPreservationRecords as ScopedRightsRecords
} from "../../smart-contracts/interfaces/stream/preservation/IStreamPreservationRecords.sol";
import {
    IStreamCollectionMetadataV1 as ScopedRightsMetadata
} from "../../smart-contracts/interfaces/stream/metadata/IStreamCollectionMetadataV1.sol";
import {
    IStreamRecordSelectionLock as ScopedHeadLock
} from "../../smart-contracts/interfaces/stream/metadata/IStreamRecordSelectionLock.sol";
import {
    IStreamConservationRecordSelection as ScopedIntentSelection
} from "../../smart-contracts/interfaces/stream/metadata/IStreamConservationRecordSelection.sol";

/// @notice Scope-specific RIGHTS-family publication and real terminal selected-head seals.
/// @dev Fixture statements use an ACCOUNT licensor and unspecified grants; they assert no legal
/// ownership or permissions. RIGHTS uses its actual class-7 writer, separately from Artist op24.
abstract contract StreamCurrentAuthorityScopedPreservationPolicySealingFixture is
    StreamCurrentAuthorityScopedPreservationPolicyInventoryFixture
{
    struct AuthorityScopedRights {
        bytes32 subject;
        bytes32 recordHash;
        ScopedRightsRecords.CollectionRecord original;
        ScopedRightsMetadata.RecordReceipt receipt;
        ScopedRights.Statement statement;
        ScopedRightsSelection.Selection selection;
        bytes payload;
    }

    struct AuthorityScopedSeals {
        ScopedHeadLock.SelectionLock work;
        ScopedHeadLock.SelectionLock rights;
        ScopedIntentSelection.IntentLock intent;
    }

    function _authorityPublishScopedRights(StreamFinalityScope memory scope)
        internal
        returns (AuthorityScopedRights memory result)
    {
        result.subject = StreamMetadataSubjects.scopeSubject(
            block.chainid, address(assemblyCore), scope
        );
        require(assemblyMembership.requireScopeMembership(scope).scopeSubject == result.subject);
        require(assemblyRights.currentRights(scope.collectionId, result.subject).recordHash == 0);
        result.statement.subjectId = result.subject;
        result.statement.profileHash = ScopedRightsDefinitions.PROFILE_HASH;
        result.statement.licensor.kind = ScopedRights.LicensorKind.ACCOUNT;
        result.statement.licensor.account = address(this);
        result.statement.startDate = 20240229;
        result.statement.openEnd = true;
        result.payload = ScopedRightsJSON.serialize(result.statement);
        result.original.recordType = keccak256("RIGHTS_STATEMENT");
        result.original.subjectId = result.subject;
        result.original.schemaId = ScopedRightsDefinitions.SCHEMA_ID;
        result.original.effectiveAt = uint64(block.timestamp);
        result.original.uri = "urn:fixture:current-authority:scoped-rights";
        result.original.contentHash = ScopedRightsRecords.HashRef(
            1, abi.encodePacked(keccak256(result.payload)), keccak256("RFC8785_JCS")
        );
        (, uint64 count) =
            assemblyMetadata.recordChainHash(scope.collectionId, result.original.recordType);
        assemblyMetadata.prepareRecordPayload(result.payload);
        result.recordHash = assemblyMetadata.recordCollectionRecordWithPayload(
            scope.collectionId, result.original, result.payload
        );
        (
            ScopedRightsRecords.CollectionRecord memory saved,
            ScopedRightsMetadata.RecordReceipt memory receipt
        ) = assemblyMetadata.collectionRecord(result.recordHash);
        result.receipt = receipt;
        require(
            keccak256(abi.encode(saved)) == keccak256(abi.encode(result.original))
                && receipt.collectionId == scope.collectionId && receipt.recordIndex == count
                && receipt.recorder == address(this) && receipt.authorizationClass == 7
                && receipt.artistAuthorization == 0 && receipt.recordChainHash != 0
        );
        (, bytes memory retained) = assemblyMetadata.recordPayload(result.recordHash);
        require(keccak256(retained) == keccak256(result.payload));
        // A valid publication cannot skip the selector's exact prior-head comparison.
        (bool accepted,) = address(assemblyRights)
            .call(
                abi.encodeCall(
                    assemblyRights.selectCurrent,
                    (
                        scope.collectionId,
                        result.subject,
                        result.recordHash,
                        bytes32(uint256(1)),
                        uint64(0),
                        result.statement
                    )
                )
            );
        require(
            !accepted
                && assemblyRights.currentRights(scope.collectionId, result.subject).recordHash == 0
        );
        result.selection = assemblyRights.selectCurrent(
            scope.collectionId, result.subject, result.recordHash, 0, 0, result.statement
        );
        require(
            result.selection.recordHash == result.recordHash && result.selection.revision == 1
                && result.selection.authorizationClass == 7
                && result.selection.recorderAuthorizationClass == 7
                && result.selection.recordIndex == count
                && result.selection.selector == address(this)
                && result.selection.recorder == address(this)
                && result.selection.artistIdentityRecordHash == 0
                && result.selection.payloadHash == keccak256(result.payload)
        );
        require(
            keccak256(
                abi.encode(
                    assemblyRights.requireCurrent(
                        scope.collectionId, result.subject, result.recordHash, 1
                    )
                )
            ) == keccak256(abi.encode(result.selection))
        );
    }

    function _authoritySealScopedRecords(
        ScopedRecordSet memory records,
        AuthorityScopedRights memory rightsResult
    ) internal returns (AuthorityScopedSeals memory result) {
        uint256 cid = records.scope.collectionId;
        require(
            records.subject == rightsResult.subject
                && records.intentSelection.record.recordHash != 0
        );
        // Re-read the actual selected heads under the presently authenticated Artist suite.
        // Supplied historical fields alone cannot authorize a new terminal selection seal.
        require(
            keccak256(
                abi.encode(
                    assemblyWork.requireCurrent(
                        cid,
                        records.subject,
                        records.workSelection.recordHash,
                        records.workSelection.revision
                    )
                )
            ) == keccak256(abi.encode(records.workSelection)),
            "actual current WORK head"
        );
        require(
            keccak256(
                abi.encode(
                    assemblyRights.requireCurrent(
                        cid,
                        records.subject,
                        rightsResult.recordHash,
                        rightsResult.selection.revision
                    )
                )
            ) == keccak256(abi.encode(rightsResult.selection)),
            "actual current RIGHTS head"
        );
        require(
            keccak256(
                abi.encode(
                    assemblyConservation.requireCurrent(
                        cid,
                        records.subject,
                        records.intentSelection.origin,
                        records.intentSelection.record.recordHash,
                        records.intentSelection.revision
                    )
                )
            ) == keccak256(abi.encode(records.intentSelection)),
            "actual current Intent head"
        );
        result.work = _authoritySealScopedHead(
            ScopedHeadLock(address(assemblyWork)),
            cid,
            records.subject,
            records.workSelection.recordHash,
            records.workSelection.revision,
            records.workSelection.selectionHash
        );
        result.rights = _authoritySealScopedHead(
            ScopedHeadLock(address(assemblyRights)),
            cid,
            records.subject,
            rightsResult.recordHash,
            rightsResult.selection.revision,
            rightsResult.selection.selectionHash
        );
        bytes memory callData = abi.encodeCall(
            assemblyConservation.lockArtistIntent,
            (
                cid,
                records.subject,
                records.intentSelection.record.recordHash,
                records.intentSelection.revision
            )
        );
        (bool accepted,) = address(assemblyConservation).call(callData);
        require(
            !accepted && !assemblyConservation.intentLock(cid, records.subject).locked,
            "publication/adoption caller cannot impersonate the current Artist principal"
        );
        uint256 nonce = assemblyArtist.nonce();
        require(
            executeSafe(
                assemblyArtist, assemblyArtistKeys, address(assemblyConservation), 0, callData, 0
            )
        );
        result.intent = assemblyConservation.intentLock(cid, records.subject);
        require(
            assemblyArtist.nonce() == nonce + 1 && result.intent.locked
                && result.intent.locker == address(assemblyArtist)
                && result.intent.artistId == records.intentSelection.association.artistId
                && result.intent.identityRecordHash
                    == records.intentSelection.association.identityRecordHash
                && result.intent.bindingHash == records.intentSelection.association.bindingHash
                && result.intent.bindingGeneration == records.intentSelection.association.generation
                && result.intent.recordHash == records.intentSelection.record.recordHash
                && result.intent.revision == records.intentSelection.revision
        );
    }

    function _authoritySealScopedHead(
        ScopedHeadLock host,
        uint256 cid,
        bytes32 subject,
        bytes32 recordHash,
        uint64 revision,
        bytes32 selectionHash
    ) private returns (ScopedHeadLock.SelectionLock memory seal) {
        bytes memory callData = abi.encodeCall(
            host.lockSelection, (cid, subject, recordHash, revision)
        );
        (bool accepted,) = address(host).call(callData);
        require(
            !accepted && !host.selectionLock(cid, subject).locked,
            "only exact governed terminal action seals a selected head"
        );
        (bytes32 scope, bytes32 oldHash, bytes32 newHash) =
            host.selectionLockTransition(cid, subject, recordHash, revision);
        bytes32 action =
            _assemblyGovernanceCall(2, address(host), callData, scope, oldHash, newHash);
        seal = host.selectionLock(cid, subject);
        require(
            seal.locked && seal.recordHash == recordHash && seal.revision == revision
                && seal.selectionHash == selectionHash && seal.executor == address(assemblyExecutor)
                && seal.governanceRoot == address(assemblyRoot) && seal.actionId == action
                && action != 0 && seal.scopeHash == scope && seal.oldValueHash == oldHash
                && seal.newValueHash == newHash
        );
    }
}
