// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamArtistGuardianAppealTypes as A
} from "../../interfaces/stream/artist/StreamArtistGuardianAppealTypes.sol";
import {
    IStreamArtistGuardianAppealEvidence,
    IStreamArtistGuardianAppealBinding
} from "../../interfaces/stream/artist/IStreamArtistGuardianAppealEvidence.sol";
import {
    IStreamArtistGuardianSelectionOwner
} from "../../interfaces/stream/artist/IStreamArtistGuardianSelectionPreparation.sol";
import { IStreamArtistOwner } from "../../interfaces/stream/artist/IStreamArtistOwner.sol";
import {
    IStreamArtistRecoveryDeployment
} from "../../interfaces/stream/artist/IStreamArtistRecoveryDeployment.sol";
import {
    IStreamArtistIdentityContestOwner
} from "../../interfaces/stream/artist/IStreamArtistIdentityContest.sol";
import {
    IStreamArtistSuccessionReads
} from "../../interfaces/stream/artist/IStreamArtistSuccessionRecords.sol";
import {
    StreamArtistOnboardingTypes as T
} from "../../interfaces/stream/artist/StreamArtistOnboardingTypes.sol";
import {
    StreamArtistIdentityRecoveryOperationTypes as R
} from "../../interfaces/stream/artist/StreamArtistIdentityRecoveryOperationTypes.sol";
import {
    StreamArtistSuccessionTypes as S
} from "../../interfaces/stream/artist/StreamArtistSuccessionTypes.sol";
import {
    StreamArtistIdentityDismissalTypes as D
} from "../../interfaces/stream/artist/StreamArtistIdentityDismissalTypes.sol";
import {
    StreamArtistIdentityContestTypes as C
} from "../../interfaces/stream/artist/StreamArtistIdentityContestTypes.sol";
import {
    StreamArtistGuardianVestingTypes as V
} from "../../interfaces/stream/artist/StreamArtistGuardianVestingTypes.sol";
import { StreamArtistHashes } from "./StreamArtistHashes.sol";
import { StreamArtistSuccessionHashes } from "./StreamArtistSuccessionHashes.sol";
import { StreamArtistGuardianAppealAuthority } from "./StreamArtistGuardianAppealAuthority.sol";
import {
    StreamArtistRecoveredIdentityRuntime as Recovered
} from "./StreamArtistRecoveredIdentityRuntime.sol";

library StreamArtistGuardianAppealReads {
    function requireWitness(
        StreamArtistHashes.Environment memory e,
        address proposer,
        bytes32 mutation,
        uint64 revision
    ) public view {
        A.Authority memory a = _authority(address(this), e);
        if (proposer != a.root || mutation != a.roleMutationHash || revision != a.roleRevision) {
            revert A.InvalidGuardianAppeal(bytes32(0));
        }
    }

    /// @dev The owner constructs the exact complete pre-cutoff subset from its authenticated original history.
    function requireEvidence(
        StreamArtistHashes.Environment memory e,
        R.Request memory p,
        D.Cause memory cause,
        C.Record memory contest,
        V.Snapshot memory cutoff,
        A.Finding[] memory expected
    ) public view returns (bytes32) {
        A.Evidence memory retained = read(address(this), e, p);
        A.Document memory d = retained.document;
        if (
            d.requestCommitment != A.requestCommitment(p) || d.causeHash != cause.causeHash
                || d.contestRecordHash != contest.recordHash
                || d.vestingCommitment != cutoff.commitment
                || d.transitionRecordHash != cutoff.transitionRecordHash
                || d.hostileFindingsHash == 0 || expected.length == 0
                || keccak256(abi.encode(d.findings)) != keccak256(abi.encode(expected))
        ) {
            revert A.InvalidGuardianAppeal(p.evidenceHash);
        }
        return keccak256(
            abi.encode(
                keccak256("6529STREAM_ARTIST_GUARDIAN_APPEAL_CONTEXT_V1"),
                uint16(1),
                A.APPEAL,
                retained,
                cause,
                contest,
                cutoff
            )
        );
    }

    /// @notice Exact retained content and current policy for the same locked preparation/operation Archive.
    /// @dev Full adjudicability is supplied by the owner before this read; this function alone grants no authority.
    function read(address owner, StreamArtistHashes.Environment memory e, R.Request memory p)
        public
        view
        returns (A.Evidence memory result)
    {
        address child = IStreamArtistGuardianSelectionOwner(owner).identityRecoveryExtension();
        (address target, bytes32 codeHash) =
            IStreamArtistGuardianAppealBinding(child).guardianAppealEvidenceBinding();
        if (
            child.code.length == 0 || target.code.length == 0 || target.codehash != codeHash
                || codeHash == 0 || block.chainid != e.chainId || owner.code.length == 0
        ) revert A.GuardianAppealDependencyChanged(target);
        IStreamArtistGuardianAppealEvidence publisher = IStreamArtistGuardianAppealEvidence(target);
        if (
            publisher.owner() != owner || publisher.artistRegistry() != e.registry
                || publisher.deploymentChainId() != e.chainId
        ) {
            revert A.GuardianAppealDependencyChanged(target);
        }
        bytes32 observed;
        (result.document, observed) = publisher.evidence(p.evidenceHash);
        if (
            observed != owner.codehash
                || A.documentHash(e.chainId, e.registry, owner, result.document) != p.evidenceHash
        ) {
            revert A.InvalidGuardianAppeal(p.evidenceHash);
        }
        result.authority = _authority(owner, e);
        bytes32 directive = IStreamArtistSuccessionReads(owner).operativeEstateDirective(p.artistId);
        if (directive != 0) {
            result.directive = IStreamArtistSuccessionReads(owner).estateDirectiveRecord(directive);
            S.DirectiveRecord memory saved = result.directive;
            StreamArtistHashes.Environment memory original = e;
            if (Recovered.active(owner)) {
                original = Recovered.hashes(
                    Recovered.nativeFact(
                        Recovered.load(owner, e.registry, e.chainId), 37, p.artistId, directive
                    )
                    .environment
                );
            }
            if (
                saved.recordHash != directive || saved.terms.artistId != p.artistId
                    || saved.authorityClass != 1 || saved.signer == address(0)
                    || saved.signedAt == 0
                    || StreamArtistSuccessionHashes.directiveRecord(
                            original,
                            saved.terms,
                            T.Authorization(saved.nonce, saved.signedAt, new bytes(0))
                        ) != directive
            ) {
                revert A.InvalidGuardianAppeal(directive);
            }
            if ((saved.terms.forbiddenCapabilities & 256) != 0) {
                revert S.ForbiddenCapability(p.artistId, 256, directive);
            }
        }
    }

    function _authority(address owner, StreamArtistHashes.Environment memory e)
        private
        view
        returns (A.Authority memory)
    {
        address coordinator = IStreamArtistOwner(owner).operationCoordinator();
        T.SuiteConfiguration memory suite =
            IStreamArtistRecoveryDeployment(coordinator).suiteConfiguration();
        if (
            suite.owners[2] != owner || suite.registry != e.registry || suite.core != e.core
                || suite.mintManager != e.manager
                || IStreamArtistOwner(owner).deploymentChainId() != e.chainId
                || IStreamArtistRecoveryDeployment(coordinator).deploymentChainId() != e.chainId
        ) revert T.InvalidBinding();
        return StreamArtistGuardianAppealAuthority.current(
            IStreamArtistIdentityContestOwner(owner).artistWindowAuthority(), suite.roleRegistry
        );
    }
}
