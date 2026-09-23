// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "../../interfaces/stream/artist/IStreamArtistIdentityDismissal.sol";
import "../../interfaces/stream/artist/IStreamArtistPayoutResolutionOwner.sol";
import "../../interfaces/stream/artist/IStreamArtistCurrentPayoutOwner.sol";
import "./StreamArtistIdentityOperations.sol";
import "./StreamArtistRotationOperations.sol";

import "./StreamArtistEconomicsHashes.sol";
import "./StreamArtistEconomicOperations.sol";
import "./StreamArtistBindingOperations.sol";
import "./StreamArtistCollaboratorOperations.sol";
import "./StreamArtistAuthorizationState.sol";
import "./StreamArtistContentOperations.sol";
import "../../interfaces/stream/artist/IStreamArtistCollaboratorCoordinator.sol";
import "../../interfaces/stream/artist/IStreamArtistBindingLifecycleCoordinator.sol";
import "../../interfaces/stream/artist/IStreamArtistDelegationCoordinator.sol";

import "./StreamArtistOnboardingReads.sol";
import "../../interfaces/stream/artist/IStreamArtistCollaboratorOwner.sol";
import "./StreamArtistRegistryValidatorBase.sol";
import "../../interfaces/stream/artist/IStreamArtistOnboardingCoordinator.sol";
import "../../interfaces/stream/artist/IStreamArtistEconomicsCoordinator.sol";
import "../../interfaces/stream/artist/IStreamArtistArchiveV2.sol";
import "../../interfaces/stream/artist/IStreamArtistMintConsent.sol";
import "../../interfaces/stream/artist/IStreamArtistIngressBinding.sol";
import "../../interfaces/stream/governance/IStreamRoleRegistry.sol";
import "../../interfaces/stream/parameters/IStreamGasParameterHost.sol";
import "../../interfaces/stream/core/IStreamCoreCollectionView.sol";
import {
    StreamArtistOnboardingTypes as T
} from "../../interfaces/stream/artist/StreamArtistOnboardingTypes.sol";

import "./StreamArtistBindingCorrectionAdmission.sol";
import { StreamArtistPlatformCorrectionState } from "./StreamArtistPlatformCorrectionState.sol";
import { IStreamArtistPlatformCorrectionLineage } from "../../interfaces/stream/artist/IStreamArtistPlatformCorrectionLineage.sol";
import {
    StreamArtistBindingCorrectionTypes as BC,
    IStreamArtistBindingCorrectionOwner,
    IStreamArtistBindingCorrectionCoordinator
} from "../../interfaces/stream/artist/IStreamArtistBindingCorrection.sol";

/// @notice Additive governed recipe within original operation1 and original immutable owner graph.
library StreamArtistBindingCorrectionOperations {
    function proposeStored(
        T.SuiteConfiguration storage suite,
        address reads,
        bytes32 configurationHash,
        bytes calldata originalCall
    ) public returns (bytes32, bytes32) {
        return proposeEncoded(D.CoordinatorContext(suite, reads, configurationHash), originalCall);
    }

    function proposeEncoded(D.CoordinatorContext memory x, bytes calldata originalCall)
        public
        returns (bytes32, bytes32)
    {
        if (
            bytes4(originalCall[:4])
                != IStreamArtistBindingCorrectionCoordinator.coordinateProposeArtistBindingAfterRevocation
                    .selector
        ) revert T.InvalidRecord();
        (
            address actor,
            uint256 collectionId,
            T.BindingProposal memory p,
            bytes memory document,
            string memory displayName,
            bytes32 repudiationRecord
        ) = abi.decode(
            originalCall[4:], (address, uint256, T.BindingProposal, bytes, string, bytes32)
        );
        return proposeAfterRevocation(
            x, actor, collectionId, p, document, displayName, repudiationRecord
        );
    }

    function proposeAfterRevocation(
        D.CoordinatorContext memory x,
        address actor,
        uint256 collectionId,
        T.BindingProposal memory p,
        bytes memory document,
        string memory displayName,
        bytes32 repudiationRecord
    ) public returns (bytes32 artistId, bytes32 bindingHash) {
        bytes32 role = keccak256("ROLE_ARTIST_REGISTRY_ADMIN");
        if (!IStreamRoleRegistry(x.suite.roleRegistry).hasRole(role, actor)) {
            revert T.Unauthorized(actor);
        }
        (bytes32 roleHash, uint64 roleRevision) =
            IStreamRoleRegistry(x.suite.roleRegistry).roleMutationState(role);
        (BC.Context memory context, BC.Approval memory approval) = StreamArtistBindingCorrectionAdmission.admit(
            x, actor, collectionId, p, document, displayName, repudiationRecord
        );
        T.Snapshot[7] memory before_ = _snapshots(x, 1);
        _collection(x, collectionId);
        IStreamArtistIdentityOwner identity = IStreamArtistIdentityOwner(x.suite.owners[2]);
        artistId = p.artistId;
        bool reused = artistId != bytes32(0);
        if (reused) {
            StreamArtistIdentityOperations.validateProposalIdentity(
                x.suite.owners[2], p, document, displayName
            );
        } else {
            artistId = identity.registerIdentity(
                _context(1, actor, before_[2]),
                p.artistAddress,
                p.identityRecordHash,
                p.identityRecordURI,
                document,
                displayName
            );
        }
        T.Binding memory b = IStreamArtistBindingCorrectionOwner(x.suite.owners[0])
            .proposeAfterRevocation(
                _context(1, actor, before_[0]), collectionId, artistId, p, approval
            );
        bindingHash = b.bindingHash;
        if (StreamArtistPlatformCorrectionState.tagged(approval.causeData)) {
            IStreamArtistPlatformCorrectionLineage(x.suite.owners[4]).claimPlatformContinuation(
                _context(1, actor, before_[4]), collectionId, b, p.reasonHash, p.reasonURI, approval);
        } else {
            IStreamArtistAttributionOwner(x.suite.owners[4])
                .claim(_context(1, actor, before_[4]), collectionId, b, p.reasonHash, p.reasonURI);
        }
        _archive(
            x,
            1,
            actor,
            bindingHash,
            before_,
            abi.encode(
                BC.DETAIL,
                uint16(1),
                collectionId,
                p,
                document,
                displayName,
                reused,
                roleHash,
                roleRevision,
                repudiationRecord,
                context,
                approval
            )
        );
    }

    function _collection(D.CoordinatorContext memory x, uint256 collectionId) private view {
        if (!IStreamCoreCollectionView(x.suite.core).collectionExists(collectionId)) {
            revert T.InvalidAttribution(collectionId);
        }
    }

    function _context(uint16 operationId, address actor, T.Snapshot memory prior)
        private
        pure
        returns (T.ActionContext memory)
    {
        return T.ActionContext(operationId, actor, prior);
    }

    function _snapshots(D.CoordinatorContext memory x, uint16 op)
        private
        view
        returns (T.Snapshot[7] memory result)
    {
        // acceptedBinding also consumes Attribution's state/generation. Commit
        // that read for every recipe using it, without adding an owner mutation.
        uint256 mask = op == 1
            ? 0x15
            : op == 2 ? 0x1f : op == 15 ? 0x77 : op == 18 ? 0x24 : op == 24 ? 0x17 : 0x57;
        for (uint256 i; i < 7; ++i) {
            if ((mask & (1 << i)) != 0) {
                result[i] = IStreamArtistOwner(x.suite.owners[i]).ownerStateSnapshotV2();
            }
        }
    }

    function _archive(
        D.CoordinatorContext memory x,
        uint16 op,
        address actor,
        bytes32 record,
        T.Snapshot[7] memory prior,
        bytes memory payload
    ) private {
        T.Snapshot[7] memory after_ = _snapshots(x, op);
        bytes32 id = keccak256(
            abi.encode(
                keccak256("6529STREAM_ARTIST_ONBOARDING_OPERATION_EVIDENCE_V1"),
                block.chainid,
                x.suite.registry,
                address(this),
                op,
                actor,
                record
            )
        );
        bytes memory evidence =
            abi.encode(uint16(1), x.configurationHash, op, actor, record, prior, after_, payload);
        (bytes32 hash,, bool appended) =
            IStreamArtistArchiveV2(x.suite.archive).appendArtistEvidenceV2(id, 1, evidence);
        if (!appended || hash != keccak256(evidence)) revert T.InvalidRecord();
    }
}
