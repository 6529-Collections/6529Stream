// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "./RecoveryCompanionBoundaryFixture.sol";

/// @dev Explicit artist/Consent/original-history boundaries around the actual supplied OwnerRecords.
/// Core/Executor/RoleRegistry are named raw boundaries in the focused test; no production authority is inferred.
contract RecoveryOwnerNoticeCompositionFixture is RecoveryCompanionBoundaryFixture {
    StreamArtworkFinalityRecovery public recovery;
    RecoveryOriginalRecordFixture public history;
    CompanionDependencyBoundary private renderer;
    StreamFinalityScope private scope;
    bytes32 private originalHash;
    bytes32 private savedArtistId;
    StreamFinalityComponentExpectation private oldRoute;
    StreamFinalityRecoveryRequest private request;
    bytes32 public constant APPROVAL = keccak256("saved approval evidence boundary");
    bytes32 public constant OWNER = keccak256("elapsed owner evidence boundary");

    function initialize(
        address actualCore,
        address actualExecutor,
        address actualRoles,
        address actualOwner
    ) external {
        super.setUp();
        require(address(recovery) == address(0), "fixture one initialization");
        core = CompanionDependencyBoundary(actualCore);
        executor = CompanionDependencyBoundary(actualExecutor);
        roles = CompanionDependencyBoundary(actualRoles);
        suite.core = actualCore;
        suite.roleRegistry = actualRoles;
        _address(artist, IStreamArtistMintConsent.core.selector, actualCore);
        ownerEvidence = CompanionDependencyBoundary(actualOwner);
        for (uint256 i; i < 7; ++i) {
            _address(
                CompanionDependencyBoundary(suite.owners[i]),
                IStreamArtistOwner.core.selector,
                actualCore
            );
        }
        coordinator.answer(
            abi.encodeCall(IStreamArtistRecoveryDeployment.suiteConfiguration, ()),
            abi.encode(suite)
        );
        history = new RecoveryOriginalRecordFixture(address(core), address(artist));
        finality = CompanionDependencyBoundary(address(history));
        _address(
            coordinator, IStreamArtistRecoveryDeployment.finalityRegistry.selector, address(history)
        );
        _word(
            coordinator,
            IStreamArtistRecoveryDeployment.finalityRegistryCodeHash.selector,
            uint256(address(history).codehash)
        );
        IStreamGasParameterHost.GasParameterConfig[3] memory caps;
        caps[0] = IStreamGasParameterHost.GasParameterConfig(
            "RECOVERY_DEPENDENCY_READ_GAS", 150000, 50000, 2
        );
        caps[1] = IStreamGasParameterHost.GasParameterConfig(
            "RECOVERY_ARTIST_READ_GAS", 2000000, 50000, 2
        );
        caps[2] =
            IStreamGasParameterHost.GasParameterConfig("RECOVERY_OWNER_READ_GAS", 500000, 50000, 2);
        recovery = new StreamArtworkFinalityRecovery(
            StreamFinalityRecoveryTargets(
                address(core),
                address(executor),
                address(history),
                address(artist),
                address(ownerEvidence)
            ),
            caps,
            StreamFinalityRecoveryDeploymentConfiguration(
                keccak256("deployment"), "urn:recovery:module", keccak256("module bytes")
            )
        );
        _word(
            artist, IStreamModule.streamModuleType.selector, uint256(keccak256("ARTIST_REGISTRY"))
        );
        _word(
            artist,
            IStreamModule.streamModuleInterfaceId.selector,
            uint256(bytes32(type(IStreamArtistMintConsent).interfaceId))
        );
        _erc(artist, type(IStreamArtistMintConsent).interfaceId);
        scope = StreamFinalityScope(StreamFinalityScopeType.TOKEN, 7, 23, 0);
        savedArtistId = keccak256("original artist");
        originalHash = keccak256("executed original finality");
        renderer = new CompanionDependencyBoundary();
        oldRoute = StreamFinalityComponentExpectation(
            bytes32(uint256(1)),
            address(renderer),
            type(IStreamArtworkScopedFinalityComponent).interfaceId,
            address(renderer).codehash,
            keccak256("version"),
            keccak256("renderer manifest"),
            keccak256("original data")
        );
        S.Record memory sanction = S.Record(
            0,
            savedArtistId,
            address(0xA11CE),
            1,
            S.Terms(1, 7, 23, 0, keccak256("subject"), keccak256("ceremony")),
            1,
            1000,
            2000,
            3,
            keccak256("saved binding"),
            keccak256("digest")
        );
        sanction.recordHash = StreamArtistSanctionHashes.record(
            StreamArtistHashes.Environment(
                block.chainid, address(artist), address(core), suite.mintManager
            ),
            sanction
        );
        StreamFinalityComponentExpectation[] memory items =
            new StreamFinalityComponentExpectation[](2);
        items[0] = oldRoute;
        items[1] = StreamFinalityComponentExpectation(
            keccak256("ARTIST_SANCTION"),
            address(artist),
            type(IStreamArtworkScopedFinalityComponent).interfaceId,
            address(artist).codehash,
            keccak256("artist version"),
            keccak256("artist manifest"),
            sanction.recordHash
        );
        history.set(scope, originalHash, sanction, items);
        CompanionDependencyBoundary(suite.owners[6])
            .answer(
                abi.encodeCall(IStreamArtistSanctionOwner.sanctionRecord, (sanction.recordHash)),
                abi.encode(sanction)
            );
        request.scope = scope;
        request.expectedOriginalFinalityRecordHash = originalHash;
        request.expectedOldRouteHash = keccak256(abi.encode(oldRoute));
        request.replacementRoute = oldRoute;
        request.replacementRoute.dataHash = keccak256("replacement artwork bytes");
        request.recoveryManifest = StreamFinalityManifestRef(
            "urn:actual:recovery",
            keccak256("urn:actual:recovery"),
            0,
            keccak256("intent schema"),
            keccak256("binary ABI canonicalization")
        );
        request.reasonHash = keccak256("recovery reason");
        request.reasonURI = "urn:recovery:reason";
        renderer.answer(
            abi.encodeCall(IStreamArtworkScopedFinalityComponent.finalityStateForScope, (scope)),
            abi.encode(
                StreamFinalityComponentState(
                    true,
                    request.replacementRoute.componentType,
                    request.replacementRoute.component,
                    request.replacementRoute.interfaceId,
                    request.replacementRoute.codeHash,
                    request.replacementRoute.moduleVersion,
                    request.replacementRoute.manifestHash,
                    request.replacementRoute.dataHash
                )
            )
        );
        bytes memory intent = recovery.finalityRecoveryIntentBytes(request);
        request.recoveryManifest.contentHash = recovery.stageFinalityRecoveryManifest(intent);
        recovery.registerFinalityRecoveryIntent(request);
        artist.answer(_approvalRead(), abi.encode(true, APPROVAL, address(0xA11CE), uint8(1)));
    }

    function _approvalRead() private view returns (bytes memory) {
        return abi.encodeCall(
            IStreamArtistRecoveryApproval.verifyRecoveryApproval,
            (uint256(7), originalHash, request.recoveryManifest.contentHash)
        );
    }

    function changeOriginalRecord() external {
        StreamFinalityComponentExpectation[] memory items =
            history.finalityComponentsForScope(scope, 0, 2);
        S.Record memory sanction = history.sanctionRecord(items[1].dataHash);
        history.set(scope, keccak256("changed authoritative original fixture"), sanction, items);
    }

    function requestFacts() external view returns (StreamFinalityRecoveryRequest memory) {
        return request;
    }

    function artistTarget() external view returns (address) {
        return address(artist);
    }

    function ownerTarget() external view returns (address) {
        return address(ownerEvidence);
    }

    function sibling() external returns (StreamArtworkFinalityRecovery) {
        IStreamGasParameterHost.GasParameterConfig[3] memory caps;
        caps[0] = IStreamGasParameterHost.GasParameterConfig(
            "RECOVERY_DEPENDENCY_READ_GAS", 150000, 50000, 2
        );
        caps[1] = IStreamGasParameterHost.GasParameterConfig(
            "RECOVERY_ARTIST_READ_GAS", 2000000, 50000, 2
        );
        caps[2] =
            IStreamGasParameterHost.GasParameterConfig("RECOVERY_OWNER_READ_GAS", 500000, 50000, 2);
        return new StreamArtworkFinalityRecovery(
            StreamFinalityRecoveryTargets(
                address(core),
                address(executor),
                address(history),
                address(artist),
                address(ownerEvidence)
            ),
            caps,
            StreamFinalityRecoveryDeploymentConfiguration(
                keccak256("deployment"), "urn:recovery:module", keccak256("module bytes")
            )
        );
    }
}
