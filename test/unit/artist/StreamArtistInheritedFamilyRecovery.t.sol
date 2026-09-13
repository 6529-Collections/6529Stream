// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./ArtistInheritedRecoveryFixture.sol";
import {
    ArtistFamilyMembershipPublicationFixture,
    ArtistFamilyProviderBoundary
} from "./ArtistFamilyMembershipPublicationFixture.sol";
import {
    IStreamFinalityScopeMembership
} from "../../../smart-contracts/interfaces/stream/finality/IStreamFinalityScopeMembership.sol";

/// @dev Actual Artist/Safe/owners/Archive/companion and published Metadata/membership. Original
///      executed finality, provider binding, Core identities and governance/Owner evidence are boundaries.
contract StreamArtistInheritedFamilyRecoveryTest is ArtistInheritedRecoveryFixture {
    ArtistFamilyMembershipPublicationFixture private familyPublisher;
    address private familyMetadata;
    address private familyMembership;
    bytes32 private familyAction;

    function _familyGraph(bool raiseCaps) private {
        _inheritedSetup(false);
        familyPublisher = new ArtistFamilyMembershipPublicationFixture();
        familyMetadata = familyPublisher.deploy(address(core), address(ingress));
        _unavailabilityModule(
            keccak256("COLLECTION_METADATA"),
            familyMetadata,
            keccak256("COLLECTION_METADATA"),
            type(IStreamCollectionMetadataV1).interfaceId
        );
        avm.mockCall(
            address(core),
            abi.encodeCall(IERC165.supportsInterface, (bytes4(0x01ffc9a7))),
            abi.encode(true)
        );
        avm.mockCall(
            address(core),
            abi.encodeCall(IERC165.supportsInterface, (bytes4(0x80ac58cd))),
            abi.encode(true)
        );
        avm.mockCall(
            address(core),
            abi.encodeCall(IERC165.supportsInterface, (bytes4(0xffffffff))),
            abi.encode(false)
        );
        avm.mockCall(
            address(core),
            abi.encodeWithSignature("collectionMintedEver(uint256)", 1),
            abi.encode(uint256(1))
        );
        uint256[] memory ids = new uint256[](1);
        ids[0] = 9;
        familyMembership = familyPublisher.initialize(ids);
        ArtistFamilyProviderBoundary provider = new ArtistFamilyProviderBoundary(
            address(core), familyMetadata, suite.metadata, familyMembership
        );
        address original = coordinator.finalityRegistry();
        avm.mockCall(
            original,
            abi.encodeCall(IStreamFinalityDeploymentBindings.metadataReads, ()),
            abi.encode(familyMetadata)
        );
        avm.mockCall(
            original,
            abi.encodeCall(IStreamFinalityDeploymentBindings.scopeEvidenceProvider, ()),
            abi.encode(address(provider))
        );
        avm.mockCall(
            original,
            abi.encodeCall(IStreamFinalityDeploymentBindings.scopeEvidenceProviderCodeHash, ()),
            abi.encode(address(provider).codehash)
        );
        if (raiseCaps) _raiseFamilyCaps();
    }

    /// @dev Exact executing-context boundary; each actual host update remains <=2x and single-use.
    function _raiseFamilyParameter(IStreamGasParameterHost host, bytes32 id, uint256 target)
        private
    {
        (uint256 value, uint256 floor, uint8 failure, uint64 revision) = host.gasParameterInfo(id);
        bytes32 scope = keccak256(
            abi.encode(
                bytes32(0x9533611d402c2b44cf950a4a8900d25f6829bfac541dc4d5353094f966bb1a71),
                block.chainid,
                address(host),
                id
            )
        );
        bytes32 domain = 0x5059a253d3f7dd63b5d9fd1f0568caf72967f501a3db678b31cefe911334159c;
        while (value < target) {
            uint256 next = value * 2 < target ? value * 2 : target;
            bytes32 action =
                keccak256(abi.encode("family parameter raise", address(host), id, revision, next));
            avm.mockCall(
                inheritedExecutor,
                abi.encodeCall(IStreamGovernanceReads.currentAction, ()),
                abi.encode(
                    true,
                    action,
                    uint8(1),
                    scope,
                    keccak256(abi.encode(domain, scope, value, floor, failure, revision)),
                    keccak256(abi.encode(domain, scope, next, floor, failure, revision + 1))
                )
            );
            vm.prank(inheritedExecutor);
            host.raiseGasParameter(id, next);
            (uint256 actual, uint256 actualFloor, uint8 actualFailure, uint64 actualRevision) =
                host.gasParameterInfo(id);
            require(
                actual == next && actualFloor == floor && actualFailure == failure
                    && actualRevision == revision + 1
            );
            value = actual;
            revision = actualRevision;
        }
        avm.mockCall(
            inheritedExecutor,
            abi.encodeCall(IStreamGovernanceReads.currentAction, ()),
            abi.encode(false, bytes32(0), uint8(0), bytes32(0), bytes32(0), bytes32(0))
        );
    }

    function _raiseFamilyCaps() private {
        _raiseFamilyParameter(
            IStreamGasParameterHost(address(inheritedRecovery)),
            inheritedRecovery.GGP_RECOVERY_DEPENDENCY_READ_GAS(),
            2000000
        );
        _raiseFamilyParameter(
            IStreamGasParameterHost(address(ingress)),
            keccak256("6529STREAM_GGP_ARTIST_FINALITY_READ_GAS"),
            8000000
        );
        _raiseFamilyParameter(
            IStreamGasParameterHost(address(inheritedRecovery)),
            inheritedRecovery.GGP_RECOVERY_ARTIST_READ_GAS(),
            16000000
        );
        require(
            inheritedRecovery.gasParameter(inheritedRecovery.GGP_RECOVERY_DEPENDENCY_READ_GAS())
                == 2000000
        );
        require(
            ingress.gasParameter(keccak256("6529STREAM_GGP_ARTIST_FINALITY_READ_GAS")) == 8000000
        );
    }

    function _familyRequest(uint8 family) private returns (Approval.Request memory p) {
        uint256[] memory ids = new uint256[](1);
        ids[0] = 9;
        inheritedRequest.scope =
            familyPublisher.publish(family, ids, "ipfs://artist-inherited-family");
        familyAction = keccak256(abi.encode("family recovery action", inheritedRequest.scope));
        avm.mockCall(
            coordinator.finalityRegistry(),
            abi.encodeCall(
                IStreamArtworkScopedFrozenRouteRegistry.frozenRouteForScope,
                (inheritedRequest.replacementRoute.componentType, inheritedRequest.scope)
            ),
            abi.encode(false, address(0), bytes32(0), bytes32(0))
        );
        inheritedRequest.replacementRoute.dataHash =
            keccak256(abi.encode("family replacement", family));
        inheritedRequest.expectedPredecessorRecoveryId = 0;
        inheritedRequest.expectedOldRouteHash = keccak256(abi.encode(inheritedOldRoute));
        return _stageFamilyRequest();
    }

    function _stageFamilyRequest() private returns (Approval.Request memory p) {
        StreamFinalityComponentExpectation memory r = inheritedRequest.replacementRoute;
        inheritedRenderer.answer(
            abi.encodeCall(
                IStreamArtworkScopedFinalityComponent.finalityStateForScope,
                (inheritedRequest.scope)
            ),
            abi.encode(
                StreamFinalityComponentState(
                    true,
                    r.componentType,
                    r.component,
                    r.interfaceId,
                    r.codeHash,
                    r.moduleVersion,
                    r.manifestHash,
                    r.dataHash
                )
            )
        );
        inheritedRequest.recoveryManifest.contentHash = 0;
        inheritedRequest.recoveryManifest.contentHash =
            inheritedRecovery.stageFinalityRecoveryManifest(
                inheritedRecovery.finalityRecoveryIntentBytes(inheritedRequest)
            );
        inheritedRecovery.registerFinalityRecoveryIntent(inheritedRequest);
        inheritedOwner.answer(
            abi.encodeCall(
                IStreamFinalityRecoveryOwnerEvidence.verifyRecoveryOwnerEvidence,
                (
                    inheritedRequest.scope,
                    familyAction,
                    inheritedRequest.recoveryManifest.contentHash
                )
            ),
            abi.encode(
                true, keccak256("owner family boundary"), uint64(1), uint64(1), uint32(1), uint32(0)
            )
        );
        return Approval.Request(
            address(inheritedRecovery),
            inheritedRequest.scope,
            Recovery.ApprovalTerms(
                coordinator.finalityRegistry(),
                1,
                inheritedRequest.expectedOriginalFinalityRecordHash,
                inheritedRequest.recoveryManifest.contentHash
            )
        );
    }

    function _approveFamily(Approval.Request memory p) private returns (bytes32) {
        T.Authorization memory a = _authorization(false);
        a.signature = _signature(ingress.recoveryApprovalDigest(p.terms, a));
        return ingress.recordRecoveryApproval(p, a);
    }

    function _executeFamily() private {
        IStreamArtistRecoveryIntent.Facts memory f = _inheritedFacts();
        avm.mockCall(
            inheritedExecutor,
            abi.encodeCall(IStreamGovernanceReads.currentAction, ()),
            abi.encode(true, familyAction, uint8(2), f.scopeHash, f.oldValueHash, f.newValueHash)
        );
        vm.prank(inheritedExecutor);
        inheritedRecovery.executeFinalityRecovery(inheritedRequest);
    }

    function testActualArtistApprovalAndCompanionExecuteAllThreePublishedFamilies() public {
        _familyGraph(true);
        for (uint8 family = 2; family <= 4; ++family) {
            Approval.Request memory p = _familyRequest(family);
            bytes32 approval = _approveFamily(p);
            (, Approval.Admission memory admission) = ingress.recoveryApprovalRecord(approval);
            require(keccak256(abi.encode(admission.scope)) == keccak256(abi.encode(p.scope)));
            _executeFamily();
            StreamFinalityRecoveryRecord memory r =
                inheritedRecovery.finalityRecoveryRecord(familyAction);
            require(r.executed && r.originalFinalityRecordHash == p.terms.finalityRecordHash);
            require(keccak256(abi.encode(r.scope)) == keccak256(abi.encode(p.scope)));
            require(
                r.evidence.artistEvidenceHash == approval
                    && r.evidence.artistSigner == address(artist)
                    && r.evidence.artistAuthorityClass == 1
            );
        }
    }

    function testExistingTokenApprovalStillExecutesThroughAdmissionWrapper() public {
        Approval.Request memory p = _inheritedSetup(false);
        bytes32 hash = _approveFamily(p);
        _executeInherited();
        require(
            inheritedRecovery.finalityRecoveryRecord(INHERITED_ACTION).evidence.artistEvidenceHash
                == hash
        );
    }

    function testSavedFamilyApprovalAndExactHeadSurviveMembershipLossButNewPreparationRejects()
        public
    {
        _familyGraph(true);
        Approval.Request memory first = _familyRequest(2);
        bytes32 approval = _approveFamily(first);
        _executeFamily();
        bytes32 executed = familyAction;
        bytes32 history = keccak256(abi.encode(inheritedRecovery.finalityRecoveryRecord(executed)));
        bytes32 oldRoute = keccak256(abi.encode(inheritedRequest.replacementRoute));
        inheritedRequest.expectedPredecessorRecoveryId = executed;
        inheritedRequest.expectedOldRouteHash = oldRoute;
        inheritedRequest.replacementRoute.dataHash = keccak256("later family replacement");
        familyAction = keccak256("later family action");
        Approval.Request memory next = _stageFamilyRequest();
        bytes memory runtime = familyMembership.code;
        vm.etch(familyMembership, hex"00");
        (bool valid, bytes32 saved,,) = ingress.verifyRecoveryApproval(
            1, first.terms.finalityRecordHash, first.terms.recoveryManifestHash
        );
        require(valid && saved == approval);
        (bool pinned,,, bytes32 original, bytes32 recovery) = inheritedRecovery.resolvedFinalityRoute(
            inheritedRequest.replacementRoute.componentType, first.scope
        );
        require(pinned && original == first.terms.finalityRecordHash && recovery == executed);
        require(
            keccak256(abi.encode(inheritedRecovery.finalityRecoveryRecord(executed))) == history
        );
        (bool ok,) = address(inheritedRecovery)
            .staticcall(
                abi.encodeCall(
                    inheritedRecovery.requireArtistRecoveryIntent,
                    (next.scope, next.terms.finalityRecordHash, next.terms.recoveryManifestHash)
                )
            );
        require(!ok, "existing exact head cannot bypass fresh member pin");
        vm.etch(familyMembership, runtime);
        _inheritedFacts();
        _approveFamily(next);
        _executeFamily();
        require(inheritedRecovery.finalityRecoveryRecord(familyAction).executed);
    }

    function testActualGovernedDependencyAndArtistOuterRaisesAdmitFamilyApproval() public {
        _familyGraph(false);
        Approval.Request memory p = _familyRequest(3);
        bytes32 roots = _roots();
        T.Authorization memory a = _authorization(false);
        a.signature = _signature(ingress.recoveryApprovalDigest(p.terms, a));
        (bool ok,) = address(ingress).call(abi.encodeCall(ingress.recordRecoveryApproval, (p, a)));
        require(
            !ok && _roots() == roots
                && !IStreamArtistIdentityOwner(suite.owners[2]).nonceUsed(artistId, a.nonce)
        );
        _raiseFamilyParameter(
            IStreamGasParameterHost(address(inheritedRecovery)),
            inheritedRecovery.GGP_RECOVERY_DEPENDENCY_READ_GAS(),
            2000000
        );
        (ok,) = address(ingress).call(abi.encodeCall(ingress.recordRecoveryApproval, (p, a)));
        require(
            !ok && _roots() == roots
                && !IStreamArtistIdentityOwner(suite.owners[2]).nonceUsed(artistId, a.nonce),
            "Artist outer default cannot forward governed two million"
        );
        _raiseFamilyParameter(
            IStreamGasParameterHost(address(ingress)),
            keccak256("6529STREAM_GGP_ARTIST_FINALITY_READ_GAS"),
            8000000
        );
        bytes32 hash = ingress.recordRecoveryApproval(p, a);
        require(
            hash != 0 && IStreamArtistIdentityOwner(suite.owners[2]).nonceUsed(artistId, a.nonce)
        );
        bytes32 approvedRoots = _roots();
        IStreamArtistRecoveryIntent.Facts memory f = _inheritedFacts();
        avm.mockCall(
            inheritedExecutor,
            abi.encodeCall(IStreamGovernanceReads.currentAction, ()),
            abi.encode(true, familyAction, uint8(2), f.scopeHash, f.oldValueHash, f.newValueHash)
        );
        vm.prank(inheritedExecutor);
        bytes memory error;
        (ok, error) = address(inheritedRecovery)
            .call(abi.encodeCall(inheritedRecovery.executeFinalityRecovery, (inheritedRequest)));
        require(
            !ok
                && keccak256(error)
                    == keccak256(
                        abi.encodeWithSelector(
                            bytes4(keccak256("FinalityRecoveryArtistEvidenceUnreadable()"))
                        )
                    ),
            "companion Artist cap must cover raised Artist nested read"
        );
        require(
            _roots() == approvedRoots
                && !inheritedRecovery.finalityRecoveryRecord(familyAction).executed
        );
        _raiseFamilyParameter(
            IStreamGasParameterHost(address(inheritedRecovery)),
            inheritedRecovery.GGP_RECOVERY_ARTIST_READ_GAS(),
            16000000
        );
        _executeFamily();
        require(
            inheritedRecovery.finalityRecoveryRecord(familyAction).evidence.artistEvidenceHash
                == hash
        );
    }
}
