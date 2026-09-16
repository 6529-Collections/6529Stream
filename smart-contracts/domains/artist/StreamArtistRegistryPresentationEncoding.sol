// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "../../interfaces/stream/artist/IStreamArtistPlatformWorks.sol";
import "../../interfaces/stream/artist/IStreamArtistDisplayFacts.sol";
import "../../interfaces/stream/artist/IStreamArtistAttributionClaims.sol";
import "./StreamArtistAttributionPolicy.sol";
import "../../interfaces/stream/artist/IStreamArtistIdentityDismissal.sol";

import "./StreamArtistEconomicsHashes.sol";
import "./StreamArtistSanctionReads.sol";
import {
    IStreamArtistContentAuthority
} from "../../interfaces/stream/artist/IStreamArtistContentAuthority.sol";
import "../../interfaces/stream/artist/IStreamArtistDelegation.sol";
import "../../interfaces/stream/artist/IStreamArtistBindingLifecycle.sol";
import "../../interfaces/stream/artist/IStreamArtistBeneficiaryFacts.sol";
import "../../interfaces/stream/artist/IStreamArtistCollaboratorLifecycle.sol";

import "./StreamArtistOnboardingCoordinator.sol";
import "../../interfaces/stream/artist/IStreamArtistOnboarding.sol";
import "../../interfaces/stream/artist/IStreamArtistContentRatification.sol";
import "../../interfaces/stream/artist/IStreamArtistEconomicsAuthority.sol";
import "../modules/StreamModuleBase.sol";
import "../parameters/StreamGasParameterHost.sol";
import {
    StreamArtistOnboardingTypes as T
} from "../../interfaces/stream/artist/StreamArtistOnboardingTypes.sol";

/// @notice Fixed typed read encoding; suite and host originate from the immutable reader.
library StreamArtistRegistryPresentationEncoding {
    /// @dev Original facade arguments decoded once; each typed encoder below is unchanged.
    function readEncoded(address host, address coordinator, bytes calldata data)
        public
        view
        returns (bytes memory)
    {
        bytes4 selector = bytes4(data[:4]);
        if (
            selector
                == bytes4(
                    keccak256(
                        "requireRecordPublication(bytes32,(address,address,uint256,bytes32,bytes32,bytes32,bytes32,uint16,bytes32,bytes32,uint64,bytes32))"
                    )
                )
        ) {
            (bytes32 recordHash, P.Publication memory publication) =
                abi.decode(data[4:], (bytes32, P.Publication));
            return requireRecordPublication(host, coordinator, recordHash, publication);
        }
        if (selector == bytes4(keccak256("platformWorksState(uint256)"))) {
            uint256 id = abi.decode(data[4:], (uint256));
            return platformWorksState(host, coordinator, id);
        }
        if (selector == bytes4(keccak256("platformWorksDeclaration(uint256)"))) {
            uint256 id = abi.decode(data[4:], (uint256));
            return platformWorksDeclaration(host, coordinator, id);
        }
        if (selector == bytes4(keccak256("platformWorksContest(uint256)"))) {
            uint256 id = abi.decode(data[4:], (uint256));
            return platformWorksContest(host, coordinator, id);
        }
        if (selector == bytes4(keccak256("displayBinding(uint256)"))) {
            uint256 id = abi.decode(data[4:], (uint256));
            return displayBinding(host, coordinator, id);
        }
        if (selector == bytes4(keccak256("artistAttestationStatus(uint256,uint8,bytes32,bytes32)")))
        {
            (uint256 id, uint8 kind, bytes32 subjectId, bytes32 currentHash) =
                abi.decode(data[4:], (uint256, uint8, bytes32, bytes32));
            return artistAttestationStatus(host, coordinator, id, kind, subjectId, currentHash);
        }
        if (selector == bytes4(keccak256("displaySanction((uint8,uint256,uint256,bytes32))"))) {
            StreamFinalityScope memory scope = abi.decode(data[4:], (StreamFinalityScope));
            return displaySanction(host, coordinator, scope);
        }
        if (selector == bytes4(keccak256("attributionClaims(uint256)"))) {
            uint256 id = abi.decode(data[4:], (uint256));
            return attributionClaims(host, coordinator, id);
        }
        if (selector == bytes4(keccak256("deploymentAttestation(uint256)"))) {
            uint256 id = abi.decode(data[4:], (uint256));
            return deploymentAttestation(host, coordinator, id);
        }
        if (selector == bytes4(keccak256("attestationAuthorityClass(bytes32)"))) {
            bytes32 record = abi.decode(data[4:], (bytes32));
            return attestationAuthorityClass(host, coordinator, record);
        }
        if (selector == bytes4(keccak256("attributionClaimRecord(bytes32)"))) {
            bytes32 record = abi.decode(data[4:], (bytes32));
            return attributionClaimRecord(host, coordinator, record);
        }
        if (selector == bytes4(keccak256("platformWorksClaims(uint256)"))) {
            uint256 id = abi.decode(data[4:], (uint256));
            return platformWorksClaims(host, coordinator, id);
        }
        if (selector == bytes4(keccak256("platformWorksCorrection(uint256)"))) {
            uint256 id = abi.decode(data[4:], (uint256));
            return platformWorksCorrection(host, coordinator, id);
        }
        if (selector == bytes4(keccak256("platformWorksClaimRecord(bytes32)"))) {
            bytes32 hash = abi.decode(data[4:], (bytes32));
            return platformWorksClaimRecord(host, coordinator, hash);
        }
        if (selector == bytes4(keccak256("platformWorksContestRecord(bytes32)"))) {
            bytes32 hash = abi.decode(data[4:], (bytes32));
            return platformWorksContestRecord(host, coordinator, hash);
        }
        if (
            selector
                == bytes4(
                    keccak256("platformWorksContext(uint256,uint8,bytes32,bytes32,bytes32,bool)")
                )
        ) {
            (
                uint256 id,
                uint8 state,
                bytes32 claim_,
                bytes32 evidence,
                bytes32 reason,
                bool correction
            ) = abi.decode(data[4:], (uint256, uint8, bytes32, bytes32, bytes32, bool));
            return
                platformWorksContext(
                    host, coordinator, id, state, claim_, evidence, reason, correction
                );
        }
        if (selector == bytes4(keccak256("collaboratorIdentityProposal(address,bytes32)"))) {
            (address account, bytes32 identityRecordHash) = abi.decode(data[4:], (address, bytes32));
            return collaboratorIdentityProposal(host, coordinator, account, identityRecordHash);
        }
        if (selector == bytes4(keccak256("collaboratorAt(uint256,uint64,uint256)"))) {
            (uint256 collectionId, uint64 generation, uint256 index) =
                abi.decode(data[4:], (uint256, uint64, uint256));
            return collaboratorAt(host, coordinator, collectionId, generation, index);
        }
        if (selector == bytes4(keccak256("delegationRecord(bytes32)"))) {
            bytes32 grant = abi.decode(data[4:], (bytes32));
            return delegationRecord(host, coordinator, grant);
        }
        if (selector == bytes4(keccak256("delegationState(bytes32)"))) {
            bytes32 grant = abi.decode(data[4:], (bytes32));
            return delegationState(host, coordinator, grant);
        }
        if (selector == bytes4(keccak256("bindingTermination(uint256,uint64)"))) {
            (uint256 collectionId, uint64 generation) = abi.decode(data[4:], (uint256, uint64));
            return bindingTermination(host, coordinator, collectionId, generation);
        }
        if (selector == bytes4(keccak256("firstReleaseRatification(uint256)"))) {
            uint256 collectionId = abi.decode(data[4:], (uint256));
            return firstReleaseRatification(host, coordinator, collectionId);
        }
        revert T.InvalidRecord();
    }

    struct Context {
        address host;
        address coordinator;
    }

    function requireRecordPublication(
        address host,
        address coordinator,
        bytes32 recordHash,
        P.Publication memory publication
    ) public view returns (bytes memory) {
        P.Evidence memory v0 = _original_requireRecordPublication(
            Context(host, coordinator), recordHash, publication
        );
        return abi.encode(v0);
    }

    function _original_requireRecordPublication(
        Context memory x,
        bytes32 recordHash,
        P.Publication memory publication
    ) private view returns (P.Evidence memory) {
        return StreamArtistRecordPublicationReads.requirePublication(
            _contentSuite(x), recordHash, publication
        );
    }

    function platformWorksState(address host, address coordinator, uint256 id)
        public
        view
        returns (bytes memory)
    {
        PW.State memory v0 = _original_platformWorksState(Context(host, coordinator), id);
        return abi.encode(v0);
    }

    function _original_platformWorksState(Context memory x, uint256 id)
        private
        view
        returns (PW.State memory)
    {
        return _platformOwner(x).platformWorksState(id);
    }

    function platformWorksDeclaration(address host, address coordinator, uint256 id)
        public
        view
        returns (bytes memory)
    {
        (bool v0, bytes32 v1, uint64 v2) =
            _original_platformWorksDeclaration(Context(host, coordinator), id);
        return abi.encode(v0, v1, v2);
    }

    function _original_platformWorksDeclaration(Context memory x, uint256 id)
        private
        view
        returns (bool, bytes32, uint64)
    {
        PW.State memory p = _platformOwner(x).platformWorksState(id);
        return (p.declaration.recordHash != 0, p.declaration.recordHash, p.declaration.declaredAt);
    }

    function platformWorksContest(address host, address coordinator, uint256 id)
        public
        view
        returns (bytes memory)
    {
        (uint8 v0, bytes32 v1) = _original_platformWorksContest(Context(host, coordinator), id);
        return abi.encode(v0, v1);
    }

    function _original_platformWorksContest(Context memory x, uint256 id)
        private
        view
        returns (uint8, bytes32)
    {
        PW.State memory p = _platformOwner(x).platformWorksState(id);
        return (p.contestState, p.contestClaim);
    }

    function displayBinding(address host, address coordinator, uint256 id)
        public
        view
        returns (bytes memory)
    {
        T.Binding memory v0 = _original_displayBinding(Context(host, coordinator), id);
        return abi.encode(v0);
    }

    function _original_displayBinding(Context memory x, uint256 id)
        private
        view
        returns (T.Binding memory)
    {
        return IStreamArtistBindingOwner(_contentSuite(x).owners[0]).binding(id);
    }

    function artistAttestationStatus(
        address host,
        address coordinator,
        uint256 id,
        uint8 kind,
        bytes32 subjectId,
        bytes32 currentHash
    ) public view returns (bytes memory) {
        (uint8 v0, bytes32 v1, bytes32 v2, uint8 v3, uint64 v4) = _original_artistAttestationStatus(
            Context(host, coordinator), id, kind, subjectId, currentHash
        );
        return abi.encode(v0, v1, v2, v3, v4);
    }

    function _original_artistAttestationStatus(
        Context memory x,
        uint256 id,
        uint8 kind,
        bytes32 subjectId,
        bytes32 currentHash
    ) private view returns (uint8, bytes32, bytes32, uint8, uint64) {
        return IStreamArtistDisplayFacts(_contentSuite(x).owners[4])
            .artistAttestationStatus(id, kind, subjectId, currentHash);
    }

    function displaySanction(address host, address coordinator, StreamFinalityScope memory scope)
        public
        view
        returns (bytes memory)
    {
        S.Record memory v0 = _original_displaySanction(Context(host, coordinator), scope);
        return abi.encode(v0);
    }

    function _original_displaySanction(Context memory x, StreamFinalityScope memory scope)
        private
        view
        returns (S.Record memory)
    {
        return StreamArtistSanctionReads.currentRecord(_contentSuite(x), scope);
    }

    function attributionClaims(address host, address coordinator, uint256 id)
        public
        view
        returns (bytes memory)
    {
        (uint256 v0, bytes32 v1) = _original_attributionClaims(Context(host, coordinator), id);
        return abi.encode(v0, v1);
    }

    function _original_attributionClaims(Context memory x, uint256 id)
        private
        view
        returns (uint256, bytes32)
    {
        return IStreamArtistDisplayFacts(_contentSuite(x).owners[4]).attributionClaims(id);
    }

    function deploymentAttestation(address host, address coordinator, uint256 id)
        public
        view
        returns (bytes memory)
    {
        (bytes32 v0, uint8 v1, uint64 v2) =
            _original_deploymentAttestation(Context(host, coordinator), id);
        return abi.encode(v0, v1, v2);
    }

    function _original_deploymentAttestation(Context memory x, uint256 id)
        private
        view
        returns (bytes32, uint8, uint64)
    {
        return IStreamArtistDisplayFacts(_contentSuite(x).owners[4]).deploymentAttestation(id);
    }

    function attestationAuthorityClass(address host, address coordinator, bytes32 record)
        public
        view
        returns (bytes memory)
    {
        uint8 v0 = _original_attestationAuthorityClass(Context(host, coordinator), record);
        return abi.encode(v0);
    }

    function _original_attestationAuthorityClass(Context memory x, bytes32 record)
        private
        view
        returns (uint8)
    {
        return
            IStreamArtistDisplayFacts(_contentSuite(x).owners[4]).attestationAuthorityClass(record);
    }

    function attributionClaimRecord(address host, address coordinator, bytes32 record)
        public
        view
        returns (bytes memory)
    {
        StreamArtistAttributionClaimTypes.Claim memory v0 =
            _original_attributionClaimRecord(Context(host, coordinator), record);
        return abi.encode(v0);
    }

    function _original_attributionClaimRecord(Context memory x, bytes32 record)
        private
        view
        returns (StreamArtistAttributionClaimTypes.Claim memory)
    {
        return IStreamArtistAttributionClaimsOwner(_contentSuite(x).owners[4])
            .attributionClaimRecord(record);
    }

    function platformWorksClaims(address host, address coordinator, uint256 id)
        public
        view
        returns (bytes memory)
    {
        (uint256 v0, bytes32 v1) = _original_platformWorksClaims(Context(host, coordinator), id);
        return abi.encode(v0, v1);
    }

    function _original_platformWorksClaims(Context memory x, uint256 id)
        private
        view
        returns (uint256, bytes32)
    {
        PW.State memory p = _platformOwner(x).platformWorksState(id);
        return (p.claimCount, p.latestClaim);
    }

    function platformWorksCorrection(address host, address coordinator, uint256 id)
        public
        view
        returns (bytes memory)
    {
        (uint64 v0, bytes32 v1) = _original_platformWorksCorrection(Context(host, coordinator), id);
        return abi.encode(v0, v1);
    }

    function _original_platformWorksCorrection(Context memory x, uint256 id)
        private
        view
        returns (uint64, bytes32)
    {
        PW.State memory p = _platformOwner(x).platformWorksState(id);
        return (p.correction.correctiveGeneration, p.correction.approvalActionId);
    }

    function platformWorksClaimRecord(address host, address coordinator, bytes32 hash)
        public
        view
        returns (bytes memory)
    {
        PW.Claim memory v0 = _original_platformWorksClaimRecord(Context(host, coordinator), hash);
        return abi.encode(v0);
    }

    function _original_platformWorksClaimRecord(Context memory x, bytes32 hash)
        private
        view
        returns (PW.Claim memory)
    {
        return _platformOwner(x).platformWorksClaimRecord(hash);
    }

    function platformWorksContestRecord(address host, address coordinator, bytes32 hash)
        public
        view
        returns (bytes memory)
    {
        PW.Contest memory v0 =
            _original_platformWorksContestRecord(Context(host, coordinator), hash);
        return abi.encode(v0);
    }

    function _original_platformWorksContestRecord(Context memory x, bytes32 hash)
        private
        view
        returns (PW.Contest memory)
    {
        return _platformOwner(x).platformWorksContestRecord(hash);
    }

    function platformWorksContext(
        address host,
        address coordinator,
        uint256 id,
        uint8 state,
        bytes32 claim_,
        bytes32 evidence,
        bytes32 reason,
        bool correction
    ) public view returns (bytes memory) {
        PW.Context memory v0 = _original_platformWorksContext(
            Context(host, coordinator), id, state, claim_, evidence, reason, correction
        );
        return abi.encode(v0);
    }

    function _original_platformWorksContext(
        Context memory x,
        uint256 id,
        uint8 state,
        bytes32 claim_,
        bytes32 evidence,
        bytes32 reason,
        bool correction
    ) private view returns (PW.Context memory) {
        return IStreamArtistPlatformCoordinator(x.coordinator)
            .platformWorksContext(id, state, claim_, evidence, reason, correction);
    }

    function collaboratorIdentityProposal(
        address host,
        address coordinator,
        address account,
        bytes32 identityRecordHash
    ) public view returns (bytes memory) {
        C.IdentityProposalState memory v0 = _original_collaboratorIdentityProposal(
            Context(host, coordinator), account, identityRecordHash
        );
        return abi.encode(v0);
    }

    function _original_collaboratorIdentityProposal(
        Context memory x,
        address account,
        bytes32 identityRecordHash
    ) private view returns (C.IdentityProposalState memory) {
        T.SuiteConfiguration memory s = StreamArtistOnboardingCoordinator(x.coordinator)
            .suiteConfiguration();
        return IStreamArtistCollaboratorRecordsOwner(s.owners[1])
            .identityProposal(account, identityRecordHash);
    }

    function collaboratorAt(
        address host,
        address coordinator,
        uint256 collectionId,
        uint64 generation,
        uint256 index
    ) public view returns (bytes memory) {
        C.Row memory v0 = _original_collaboratorAt(
            Context(host, coordinator), collectionId, generation, index
        );
        return abi.encode(v0);
    }

    function _original_collaboratorAt(
        Context memory x,
        uint256 collectionId,
        uint64 generation,
        uint256 index
    ) private view returns (C.Row memory) {
        return _reads(x).collaboratorAt(collectionId, generation, index);
    }

    function delegationRecord(address host, address coordinator, bytes32 grant)
        public
        view
        returns (bytes memory)
    {
        D.Record memory v0 = _original_delegationRecord(Context(host, coordinator), grant);
        return abi.encode(v0);
    }

    function _original_delegationRecord(Context memory x, bytes32 grant)
        private
        view
        returns (D.Record memory)
    {
        T.SuiteConfiguration memory s =
            StreamArtistOnboardingCoordinator(x.coordinator).suiteConfiguration();
        return IStreamArtistDelegationOwner(s.owners[2]).delegationRecord(grant);
    }

    function delegationState(address host, address coordinator, bytes32 grant)
        public
        view
        returns (bytes memory)
    {
        (bool v0, address v1, uint256 v2, uint32 v3, uint64 v4, uint64 v5, uint64 v6) =
            _original_delegationState(Context(host, coordinator), grant);
        return abi.encode(v0, v1, v2, v3, v4, v5, v6);
    }

    function _original_delegationState(Context memory x, bytes32 grant)
        private
        view
        returns (bool, address, uint256, uint32, uint64, uint64, uint64)
    {
        D.Record memory item = _original_delegationRecord(x, grant);
        T.SuiteConfiguration memory suite =
            StreamArtistOnboardingCoordinator(x.coordinator).suiteConfiguration();
        (bool currentEpoch,,) =
            IStreamArtistEstateOwner(suite.owners[2]).delegationEpochState(grant);
        uint64 remaining = item.grantor == address(0)
            ? 0
            : item.grant.maxUses == 0
                ? type(uint64).max
                : uint64(uint256(item.grant.maxUses) - item.uses);
        return (
            currentEpoch && StreamArtistDelegationState.active(item),
            item.grant.delegate,
            item.grant.collectionId,
            item.grant.capabilities,
            item.grant.notBefore,
            item.grant.expiresAt,
            currentEpoch ? remaining : 0
        );
    }

    function bindingTermination(
        address host,
        address coordinator,
        uint256 collectionId,
        uint64 generation
    ) public view returns (bytes memory) {
        L.Terminal memory v0 = _original_bindingTermination(
            Context(host, coordinator), collectionId, generation
        );
        return abi.encode(v0);
    }

    function _original_bindingTermination(Context memory x, uint256 collectionId, uint64 generation)
        private
        view
        returns (L.Terminal memory)
    {
        T.SuiteConfiguration memory s =
            StreamArtistOnboardingCoordinator(x.coordinator).suiteConfiguration();
        return IStreamArtistBindingTerminationOwner(s.owners[0])
            .bindingTermination(collectionId, generation);
    }

    function firstReleaseRatification(address host, address coordinator, uint256 collectionId)
        public
        view
        returns (bytes memory)
    {
        (bool v0, bytes32 v1, bytes32 v2) =
            _original_firstReleaseRatification(Context(host, coordinator), collectionId);
        return abi.encode(v0, v1, v2);
    }

    function _original_firstReleaseRatification(Context memory x, uint256 collectionId)
        private
        view
        returns (bool, bytes32, bytes32)
    {
        T.SuiteConfiguration memory s =
            StreamArtistOnboardingCoordinator(x.coordinator).suiteConfiguration();
        T.RatificationRecord memory r =
            IStreamArtistConsentOwner(s.owners[6]).firstReleaseRatification(collectionId);
        return (r.recordHash != bytes32(0), r.contentStateHash, r.recordHash);
    }

    function _contentSuite(Context memory x) private view returns (T.SuiteConfiguration memory) {
        return StreamArtistOnboardingCoordinator(x.coordinator).suiteConfiguration();
    }

    function _platformOwner(Context memory x) private view returns (IStreamArtistPlatformOwner) {
        return IStreamArtistPlatformOwner(_contentSuite(x).owners[4]);
    }

    function _rotationOwner(Context memory x) private view returns (IStreamArtistRotationOwner) {
        return IStreamArtistRotationOwner(_contentSuite(x).owners[2]);
    }

    function _successionOwner(Context memory x)
        private
        view
        returns (IStreamArtistSuccessionOwner)
    {
        return IStreamArtistSuccessionOwner(_contentSuite(x).owners[2]);
    }

    function _identityOwner(Context memory x)
        private
        view
        returns (IStreamArtistIdentityRevisionOwner)
    {
        T.SuiteConfiguration memory s =
            StreamArtistOnboardingCoordinator(x.coordinator).suiteConfiguration();
        return IStreamArtistIdentityRevisionOwner(s.owners[2]);
    }

    function _reads(Context memory x) private view returns (StreamArtistOnboardingReads) {
        return StreamArtistOnboardingCoordinator(x.coordinator).reads();
    }

    function _environment(Context memory x)
        private
        view
        returns (StreamArtistHashes.Environment memory)
    {
        T.SuiteConfiguration memory s = _contentSuite(x);
        return StreamArtistHashes.Environment(
            StreamArtistOnboardingCoordinator(x.coordinator).deploymentChainId(),
            x.host,
            s.core,
            s.mintManager
        );
    }
}
