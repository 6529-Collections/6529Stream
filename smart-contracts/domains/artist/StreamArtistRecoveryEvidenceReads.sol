// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    StreamArtistRecoveryEvidenceTypes as E
} from "../../interfaces/stream/artist/StreamArtistRecoveryEvidenceTypes.sol";
import {
    IStreamArtistRecoveryEvidence,
    IStreamArtistRecoveryEvidenceBinding
} from "../../interfaces/stream/artist/IStreamArtistRecoveryEvidence.sol";
import { StreamArtistIdentityState as Identity } from "./StreamArtistIdentityState.sol";
import {
    StreamArtistGuardianAppealTypes as Appeal
} from "../../interfaces/stream/artist/StreamArtistGuardianAppealTypes.sol";
import { StreamArtistGuardianAppealAuthority } from "./StreamArtistGuardianAppealAuthority.sol";
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
    StreamArtistSuccessionTypes as Succession
} from "../../interfaces/stream/artist/StreamArtistSuccessionTypes.sol";
import { StreamArtistSuccessionHashes } from "./StreamArtistSuccessionHashes.sol";
import {
    StreamArtistOnboardingTypes as T
} from "../../interfaces/stream/artist/StreamArtistOnboardingTypes.sol";

import { StreamArtistHashes as Hashes } from "./StreamArtistHashes.sol";
import {
    StreamArtistRecoveredIdentityRuntime as Recovered
} from "./StreamArtistRecoveredIdentityRuntime.sol";
import {
    StreamArtistRecoveredHydrationState as Imported
} from "./StreamArtistRecoveredHydrationState.sol";

/// @notice Fixed publisher and policy reads for additive native-cause adjudication.
library StreamArtistRecoveryEvidenceReads {
    struct AppealEvidence {
        E.AppealDocumentV2 document;
        Appeal.Authority authority;
        Succession.DirectiveRecord directive;
    }

    function manifest(Identity.OwnerContext memory o, bytes32 hash)
        public
        view
        returns (E.ResolutionManifest memory value)
    {
        IStreamArtistRecoveryEvidence publisher = _publisher(o);
        bytes32 observed;
        (value, observed) = publisher.resolutionManifest(hash);
        if (
            hash == 0 || observed != address(this).codehash
                || hash
                    != E.manifestHash(
                        o.environment.chainId,
                        o.environment.registry,
                        address(this),
                        observed,
                        o.coordinator,
                        o.archive,
                        o.environment.core,
                        o.environment.manager,
                        value
                    )
        ) revert E.InvalidRecoveryManifest(hash);
    }

    function appeal(
        Identity.OwnerContext memory o,
        bytes32 artistId,
        bytes32 manifestHash,
        bytes32 evidenceHash,
        Appeal.Finding[] memory expected
    ) public view returns (AppealEvidence memory retained) {
        IStreamArtistRecoveryEvidence publisher = _publisher(o);
        bytes32 observed;
        (retained.document, observed) = publisher.appealEvidenceV2(evidenceHash);
        if (
            observed != address(this).codehash || expected.length == 0
                || retained.document.resolutionManifestHash != manifestHash
                || retained.document.hostileFindingsHash == 0
                || keccak256(abi.encode(retained.document.findings))
                    != keccak256(abi.encode(expected))
                || E.appealHash(
                        o.environment.chainId,
                        o.environment.registry,
                        address(this),
                        retained.document
                    ) != evidenceHash
        ) revert E.InvalidRecoveryAppealEvidence(evidenceHash);
        T.SuiteConfiguration memory suite =
            IStreamArtistRecoveryDeployment(o.coordinator).suiteConfiguration();
        if (
            suite.owners[2] != address(this) || suite.registry != o.environment.registry
                || suite.core != o.environment.core || suite.mintManager != o.environment.manager
                || IStreamArtistRecoveryDeployment(o.coordinator).deploymentChainId()
                    != o.environment.chainId
        ) revert T.InvalidBinding();
        retained.authority = StreamArtistGuardianAppealAuthority.current(
            IStreamArtistIdentityContestOwner(address(this)).artistWindowAuthority(),
            suite.roleRegistry
        );
        retained.directive = requireGuardianDirective(o, artistId);
    }

    /// @dev Absolute protection for pre-transition records, including an independently
    /// provisional record when that branch would otherwise require only the ordinary tier.
    function requireGuardianDirective(Identity.OwnerContext memory o, bytes32 artistId)
        public
        view
        returns (Succession.DirectiveRecord memory saved)
    {
        bytes32 directive =
            IStreamArtistSuccessionReads(address(this)).operativeEstateDirective(artistId);
        if (directive != 0) {
            saved = IStreamArtistSuccessionReads(address(this)).estateDirectiveRecord(directive);
            Hashes.Environment memory original = o.environment;
            if (Imported.commitment() != 0) {
                original = Recovered.hashes(
                    Recovered.nativeFact(
                        Recovered.load(
                            address(this), o.environment.registry, o.environment.chainId
                        ),
                        37,
                        artistId,
                        directive
                    )
                    .environment
                );
            }
            if (
                saved.recordHash != directive || saved.terms.artistId != artistId
                    || saved.authorityClass != 1 || saved.signer == address(0)
                    || saved.signedAt == 0
                    || StreamArtistSuccessionHashes.directiveRecord(
                            original,
                            saved.terms,
                            T.Authorization(saved.nonce, saved.signedAt, new bytes(0))
                        ) != directive
            ) revert E.InvalidRecoveryAppealEvidence(directive);
            if ((saved.terms.forbiddenCapabilities & 256) != 0) {
                revert Succession.ForbiddenCapability(artistId, 256, directive);
            }
        }
    }

    function _publisher(Identity.OwnerContext memory o)
        private
        view
        returns (IStreamArtistRecoveryEvidence p)
    {
        (address target, bytes32 codeHash) =
            IStreamArtistRecoveryEvidenceBinding(address(this)).recoveryEvidenceBinding();
        if (target.code.length == 0 || codeHash == 0 || target.codehash != codeHash) {
            revert E.RecoveryEvidenceDependencyChanged(target);
        }
        p = IStreamArtistRecoveryEvidence(target);
        if (
            p.owner() != address(this) || p.artistRegistry() != o.environment.registry
                || p.deploymentChainId() != o.environment.chainId
                || p.coordinator() != o.coordinator || p.archive() != o.archive
                || p.core() != o.environment.core || p.mintManager() != o.environment.manager
        ) revert E.RecoveryEvidenceDependencyChanged(target);
    }
}
