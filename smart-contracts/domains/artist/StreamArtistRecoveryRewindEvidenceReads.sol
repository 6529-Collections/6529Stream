// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    StreamArtistRecoveryRewindTypes as W
} from "../../interfaces/stream/artist/StreamArtistRecoveryRewindTypes.sol";
import {
    IStreamArtistRecoveryRewindEvidence,
    IStreamArtistRecoveryRewindEvidenceBinding
} from "../../interfaces/stream/artist/IStreamArtistRecoveryRewindEvidence.sol";
import {
    IStreamArtistRecoveryRewindSelection,
    IStreamArtistRecoveryRewindSelectionBinding
} from "../../interfaces/stream/artist/IStreamArtistRecoveryRewindSelection.sol";
import {
    StreamArtistRecoveryRewindEnvironment as Environment
} from "./StreamArtistRecoveryRewindEnvironment.sol";
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
    StreamArtistOnboardingTypes as T
} from "../../interfaces/stream/artist/StreamArtistOnboardingTypes.sol";

/// @notice Fixed V3 content and worker pins. A published body never replaces original records.
library StreamArtistRecoveryRewindEvidenceReads {
    struct AppealEvidence {
        W.AppealDocumentV3 document;
        Appeal.Authority authority;
    }

    function environment(Identity.OwnerContext memory o)
        public
        view
        returns (W.EnvironmentV3 memory)
    {
        return Environment.fromFixed(
            address(this),
            o.environment.registry,
            o.coordinator,
            o.archive,
            o.environment.core,
            o.environment.manager
        );
    }

    function manifest(Identity.OwnerContext memory o, bytes32 hash)
        public
        view
        returns (W.ResolutionManifestV3 memory m)
    {
        W.EnvironmentV3 memory e = environment(o);
        bytes32 identityCode;
        bytes32 payoutCode;
        (m, identityCode, payoutCode) = publisher(e).resolutionManifestV3(hash);
        if (
            hash == 0 || identityCode != e.identityCodeHash || payoutCode != e.payoutCodeHash
                || W.manifestHash(e, m) != hash
        ) revert W.InvalidRecoveryRewindManifest(hash);
    }

    function appeal(
        Identity.OwnerContext memory o,
        bytes32 manifestHash,
        bytes32 evidenceHash,
        Appeal.Finding[] memory expected
    ) public view returns (AppealEvidence memory retained) {
        W.EnvironmentV3 memory e = environment(o);
        bytes32 identityCode;
        bytes32 payoutCode;
        (retained.document, identityCode, payoutCode) = publisher(e).appealEvidenceV3(evidenceHash);
        if (
            identityCode != e.identityCodeHash || payoutCode != e.payoutCodeHash
                || expected.length == 0 || retained.document.resolutionManifestHash != manifestHash
                || retained.document.hostileFindingsHash == 0
                || keccak256(abi.encode(retained.document.findings))
                    != keccak256(abi.encode(expected))
                || W.appealHash(e, retained.document) != evidenceHash
        ) {
            revert W.InvalidRecoveryRewindAppeal(evidenceHash);
        }
        T.SuiteConfiguration memory suite =
            IStreamArtistRecoveryDeployment(o.coordinator).suiteConfiguration();
        retained.authority = StreamArtistGuardianAppealAuthority.current(
            IStreamArtistIdentityContestOwner(address(this)).artistWindowAuthority(),
            suite.roleRegistry
        );
    }

    function publisher(W.EnvironmentV3 memory e)
        public
        view
        returns (IStreamArtistRecoveryRewindEvidence p)
    {
        (address target, bytes32 pin) = IStreamArtistRecoveryRewindEvidenceBinding(e.identityOwner)
            .recoveryRewindEvidenceBinding();
        if (target.code.length == 0 || pin == 0 || target.codehash != pin) {
            revert W.RecoveryRewindDependencyChanged(target);
        }
        p = IStreamArtistRecoveryRewindEvidence(target);
        if (
            p.owner() != e.identityOwner || p.payoutOwner() != e.payoutOwner
                || p.artistRegistry() != e.registry || p.deploymentChainId() != e.chainId
                || p.coordinator() != e.coordinator || p.archive() != e.archive
                || p.core() != e.core || p.mintManager() != e.manager
        ) {
            revert W.RecoveryRewindDependencyChanged(target);
        }
    }

    function worker(W.EnvironmentV3 memory e)
        public
        view
        returns (IStreamArtistRecoveryRewindSelection p)
    {
        (address target, bytes32 pin) = IStreamArtistRecoveryRewindSelectionBinding(e.identityOwner)
            .recoveryRewindSelectionBinding();
        if (target.code.length == 0 || pin == 0 || target.codehash != pin) {
            revert W.RecoveryRewindDependencyChanged(target);
        }
        p = IStreamArtistRecoveryRewindSelection(target);
        if (
            p.owner() != e.identityOwner || p.payoutOwner() != e.payoutOwner
                || p.artistRegistry() != e.registry || p.deploymentChainId() != e.chainId
                || p.coordinator() != e.coordinator
        ) revert W.RecoveryRewindDependencyChanged(target);
    }
}
