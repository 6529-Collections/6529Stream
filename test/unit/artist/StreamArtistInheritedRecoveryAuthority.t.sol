// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./ArtistInheritedRecoveryFixture.sol";

contract StreamArtistInheritedRecoveryAuthorityTest is ArtistInheritedRecoveryFixture {
    function testInheritedTokenActualEstateSanctionCapabilityAndCompanionSnapshot() public {
        Approval.Request memory p = _inheritedSetup(false);
        _activateInheritedEstate(8);
        T.Authorization memory a = _authorization(false);
        a.signature = _signature(ingress.recoveryApprovalDigest(p.terms, a));
        bytes32 hash = ingress.recordRecoveryApproval(p, a);
        (bool valid, bytes32 saved, address signer, uint8 cls) = ingress.verifyRecoveryApproval(
            1, p.terms.finalityRecordHash, p.terms.recoveryManifestHash
        );
        require(
            valid && hash == saved && signer == address(artist) && cls == 3,
            "actual estate TOKEN approval"
        );
        (, Approval.Admission memory admission) = ingress.recoveryApprovalRecord(hash);
        require(
            keccak256(abi.encode(admission.scope)) == keccak256(abi.encode(p.scope)),
            "TOKEN authority scope retained"
        );
        _executeInherited();
        StreamFinalityRecoveryEvidenceSnapshot memory evidence =
        inheritedRecovery.finalityRecoveryRecord(INHERITED_ACTION).evidence;
        require(
            evidence.artistEvidenceKind == StreamFinalityRecoveryArtistEvidenceKind.APPROVAL
                && evidence.artistEvidenceHash == hash && evidence.artistSigner == signer
                && evidence.artistAuthorityClass == 3,
            "actual companion retains estate class and signer"
        );
    }

    function testInheritedTokenActualEstateWithoutSanctionCapabilityRejectsFreshApproval() public {
        Approval.Request memory p = _inheritedSetup(true);
        _activateInheritedEstate(0);
        T.Authorization memory a = _authorization(false);
        a.signature = _signature(ingress.recoveryApprovalDigest(p.terms, a));
        bytes32 roots = _roots();
        vm.expectRevert(
            abi.encodeWithSelector(Estate.EstateCapabilityUnavailable.selector, artistId, uint32(8))
        );
        ingress.recordRecoveryApproval(p, a);
        require(
            _roots() == roots
                && !IStreamArtistIdentityOwner(suite.owners[2]).nonceUsed(artistId, a.nonce),
            "inherited collection finality grants no new TOKEN authority"
        );
        (bool valid, bytes32 hash,,) = ingress.verifyRecoveryApproval(
            1, p.terms.finalityRecordHash, p.terms.recoveryManifestHash
        );
        require(!valid && hash == 0, "no inadmissible approval stored");
    }

    // The shared fixture uses separate archival and artist role graphs behind this unit Executor.
    // Restore its archival phase for real fixity admission, then the companion's original graph.
    function _activateInheritedEstate(uint32 caps) private {
        ArtistUnitGovernance authority = ArtistUnitGovernance(inheritedExecutor);
        require(authority.roleRegistry() == suite.roleRegistry, "original companion role graph");
        authority.configureContestReads(
            address(estateFixityRoles),
            address(this),
            keccak256("inherited finding reason"),
            "urn:finding"
        );
        require(
            authority.roleRegistry() == address(estateFixityRoles), "actual archival role graph"
        );
        _estateActivateAndAdopt(caps);
        authority.configureContestReads(
            suite.roleRegistry, address(this), keccak256("inherited finding reason"), "urn:finding"
        );
        require(authority.roleRegistry() == suite.roleRegistry, "original companion graph restored");
    }
}
