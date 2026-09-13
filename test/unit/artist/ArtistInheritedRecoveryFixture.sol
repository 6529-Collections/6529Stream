// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./ArtistOnboardingFixture.sol";
import "../../../smart-contracts/domains/finality/StreamArtworkFinalityRecovery.sol";

/// @dev Exact external observations only; no owner-notice, replacement authority or governance claim.
contract ArtistInheritedReadBoundary {
    mapping(bytes32 => bytes) private answers;

    function answer(bytes memory input, bytes memory output) external {
        answers[keccak256(input)] = output;
    }

    fallback() external {
        bytes memory output = answers[keccak256(msg.data)];
        assembly ("memory-safe") { return(add(output, 32), mload(output)) }
    }
}

/// @dev Real Artist/owners/Archive/Safe and companion. Core identities, original executed records,
///      module eligibility, OwnerRecords and executing governance context are explicit boundaries.
abstract contract ArtistInheritedRecoveryFixture is ArtistOnboardingFixture {
    StreamArtworkFinalityRecovery internal inheritedRecovery;
    ArtistInheritedReadBoundary internal inheritedOwner;
    ArtistInheritedReadBoundary internal inheritedRenderer;
    StreamFinalityRecoveryRequest internal inheritedRequest;
    StreamFinalityComponentExpectation internal inheritedOldRoute;
    bytes32 internal inheritedSanction;
    address internal inheritedExecutor;
    bytes32 internal constant INHERITED_ACTION = keccak256("inherited token recovery action");

    function _inheritedSetup(bool burned) internal returns (Approval.Request memory approval) {
        _accept();
        (Q.Request memory q,) = _sanctionPrepared();
        inheritedSanction = ingress.recordArtistSanction(q, _sanctionAuthorization(q));
        (, Confirmation.Observation memory o) = _confirmationStored(inheritedSanction, 2, 9);
        address original = coordinator.finalityRegistry();
        inheritedExecutor = StreamArtistIdentityAuthority(suite.owners[2]).artistWindowAuthority();
        ArtistUnitRoles(suite.roleRegistry).configureOwner(inheritedExecutor);
        ArtistUnitGovernance(inheritedExecutor)
            .configureContestReads(
                suite.roleRegistry,
                address(this),
                keccak256("inherited finding reason"),
                "urn:finding"
            );
        inheritedOwner = new ArtistInheritedReadBoundary();
        inheritedRenderer = new ArtistInheritedReadBoundary();
        _inheritedERC165(address(core), type(IStreamFinalityRecoveryCore).interfaceId);
        inheritedOwner.answer(
            abi.encodeCall(
                IERC165.supportsInterface, (type(IStreamFinalityRecoveryOwnerEvidence).interfaceId)
            ),
            abi.encode(true)
        );
        inheritedOwner.answer(
            abi.encodeCall(IERC165.supportsInterface, (type(IERC165).interfaceId)), abi.encode(true)
        );
        inheritedOwner.answer(
            abi.encodeCall(IERC165.supportsInterface, (bytes4(0xffffffff))), abi.encode(false)
        );
        inheritedOwner.answer(
            abi.encodeCall(IStreamFinalityRecoveryOwnerBindings.core, ()), abi.encode(address(core))
        );
        inheritedOwner.answer(
            abi.encodeCall(IStreamFinalityRecoveryOwnerBindings.governanceAuthority, ()),
            abi.encode(inheritedExecutor)
        );
        IStreamGasParameterHost.GasParameterConfig[3] memory caps;
        caps[0] = IStreamGasParameterHost.GasParameterConfig(
            "RECOVERY_DEPENDENCY_READ_GAS", 150000, 50000, 2
        );
        caps[1] = IStreamGasParameterHost.GasParameterConfig(
            "RECOVERY_ARTIST_READ_GAS", 8000000, 50000, 2
        );
        caps[2] =
            IStreamGasParameterHost.GasParameterConfig("RECOVERY_OWNER_READ_GAS", 500000, 50000, 2);
        inheritedRecovery = new StreamArtworkFinalityRecovery(
            StreamFinalityRecoveryTargets(
                address(core),
                inheritedExecutor,
                original,
                address(ingress),
                address(inheritedOwner)
            ),
            caps,
            StreamFinalityRecoveryDeploymentConfiguration(
                keccak256("inherited deployment"),
                "urn:inherited:module",
                keccak256("inherited module")
            )
        );
        core.set(keccak256("ARTWORK_FINALITY_RECOVERY"), address(inheritedRecovery), false);
        _unavailabilityModule(
            keccak256("ARTIST_REGISTRY"),
            address(ingress),
            keccak256("ARTIST_REGISTRY"),
            type(IStreamArtistMintConsent).interfaceId
        );
        _unavailabilityModule(
            keccak256("ARTWORK_FINALITY_RECOVERY"),
            address(inheritedRecovery),
            keccak256("STREAM_ARTWORK_FINALITY_RECOVERY"),
            0x83685f5c
        );
        inheritedOldRoute = StreamFinalityComponentExpectation(
            bytes32(uint256(1)),
            address(inheritedRenderer),
            type(IStreamArtworkFinalityComponent).interfaceId,
            address(inheritedRenderer).codehash,
            keccak256("version"),
            keccak256("route manifest"),
            keccak256("old bytes")
        );
        o.components[0] = inheritedOldRoute;
        o.finalityRecord.componentsHash = keccak256(
            abi.encode(StreamFinalityDomains.STREAM_FINALITY_COMPONENTS_V1, o.components)
        );
        avm.mockCall(
            original,
            abi.encodeCall(IStreamArtworkFinalityRegistry.collectionFinalityRecord, (1)),
            abi.encode(o.finalityRecord)
        );
        avm.mockCall(
            original,
            abi.encodeCall(IStreamArtworkFinalityRegistry.finalityComponents, (1, 0, 2)),
            abi.encode(o.components)
        );
        StreamFinalityScope memory collection =
            StreamFinalityScope(StreamFinalityScopeType.COLLECTION, 1, 0, 0);
        inheritedRequest.scope = StreamFinalityScope(StreamFinalityScopeType.TOKEN, 1, 9, 0);
        avm.mockCall(
            original,
            abi.encodeCall(
                IStreamArtworkScopedFrozenRouteRegistry.frozenRouteForScope,
                (bytes32(uint256(1)), collection)
            ),
            abi.encode(
                true,
                inheritedOldRoute.component,
                keccak256(abi.encode(inheritedOldRoute)),
                o.finalityRecord.finalityRecordHash
            )
        );
        avm.mockCall(
            original,
            abi.encodeCall(
                IStreamArtworkScopedFrozenRouteRegistry.frozenRouteForScope,
                (bytes32(uint256(1)), inheritedRequest.scope)
            ),
            abi.encode(false, address(0), bytes32(0), bytes32(0))
        );
        _inheritedToken(burned ? 3 : 2, burned ? 1 : 0);
        inheritedRequest.expectedOriginalFinalityRecordHash = o.finalityRecord.finalityRecordHash;
        inheritedRequest.expectedOldRouteHash = keccak256(abi.encode(inheritedOldRoute));
        inheritedRequest.replacementRoute = inheritedOldRoute;
        inheritedRequest.replacementRoute.interfaceId =
        type(IStreamArtworkScopedFinalityComponent).interfaceId;
        inheritedRequest.replacementRoute.dataHash = keccak256("new token bytes");
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
        inheritedRequest.recoveryManifest = StreamFinalityManifestRef(
            "urn:inherited:intent",
            keccak256("urn:inherited:intent"),
            0,
            keccak256("intent schema"),
            keccak256("intent ABI")
        );
        inheritedRequest.reasonHash = keccak256("inherited reason");
        inheritedRequest.reasonURI = "urn:inherited:reason";
        bytes memory bytes_ = inheritedRecovery.finalityRecoveryIntentBytes(inheritedRequest);
        inheritedRequest.recoveryManifest.contentHash =
            inheritedRecovery.stageFinalityRecoveryManifest(bytes_);
        inheritedRecovery.registerFinalityRecoveryIntent(inheritedRequest);
        inheritedOwner.answer(
            abi.encodeCall(
                IStreamFinalityRecoveryOwnerEvidence.verifyRecoveryOwnerEvidence,
                (
                    inheritedRequest.scope,
                    INHERITED_ACTION,
                    inheritedRequest.recoveryManifest.contentHash
                )
            ),
            abi.encode(
                true,
                keccak256("owner evidence boundary"),
                uint64(1),
                uint64(1),
                uint32(1),
                uint32(0)
            )
        );
        avm.mockCall(
            address(core),
            abi.encodeCall(IStreamFinalityRecoveryCore.lastAllocatedTokenId, ()),
            abi.encode(uint256(9))
        );
        approval = Approval.Request(
            address(inheritedRecovery),
            inheritedRequest.scope,
            Recovery.ApprovalTerms(
                original,
                1,
                inheritedRequest.expectedOriginalFinalityRecordHash,
                inheritedRequest.recoveryManifest.contentHash
            )
        );
        require(
            address(ingress).code.length <= 24576 && address(coordinator).code.length <= 24576
                && address(inheritedRecovery).code.length <= 24576,
            "real ingress and companion fit"
        );
    }

    function _inheritedToken(uint256 lifecycle, uint256 burned) internal {
        avm.mockCall(
            address(core),
            abi.encodeCall(IStreamCoreIdentity.tokenCollectionIdentity, (9)),
            abi.encode(uint256(1), uint256(1), uint256(1), burned)
        );
        avm.mockCall(
            address(core),
            abi.encodeCall(IStreamCoreIdentity.tokenLifecycle, (9)),
            abi.encode(lifecycle)
        );
    }

    function _inheritedERC165(address target, bytes4 id) private {
        avm.mockCall(target, abi.encodeCall(IERC165.supportsInterface, (id)), abi.encode(true));
    }

    function _inheritedFacts() internal view returns (IStreamArtistRecoveryIntent.Facts memory) {
        return inheritedRecovery.requireArtistRecoveryIntent(
            inheritedRequest.scope,
            inheritedRequest.expectedOriginalFinalityRecordHash,
            inheritedRequest.recoveryManifest.contentHash
        );
    }

    function _executeInherited() internal {
        _inheritedContext();
        vm.prank(inheritedExecutor);
        inheritedRecovery.executeFinalityRecovery(inheritedRequest);
    }

    function _inheritedContext() internal {
        IStreamArtistRecoveryIntent.Facts memory f = _inheritedFacts();
        avm.mockCall(
            inheritedExecutor,
            abi.encodeCall(IStreamGovernanceReads.currentAction, ()),
            abi.encode(
                true, INHERITED_ACTION, uint8(2), f.scopeHash, f.oldValueHash, f.newValueHash
            )
        );
    }
}
