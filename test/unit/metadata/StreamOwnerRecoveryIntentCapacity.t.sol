// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../../helpers/RecoveryGovernanceCompositionFixture.sol";

interface OwnerIntentCapacityVm {
    function cool(address target) external;
    function prank(address sender) external;
    function expectRevert() external;
}

/// @notice Actual registered companion request/704-byte intent and original-record preparation.
/// @dev Core/Executor/artist/owner evidence remain the explicit existing boundary fixtures.
contract StreamOwnerRecoveryIntentCapacityTest is RecoveryCompanionBoundaryFixture {
    function _fixture()
        private
        returns (
            RecoveryGovernanceCompositionFixture fixture,
            StreamArtworkFinalityRecovery recovery
        )
    {
        executor.answer(
            abi.encodeWithSignature("isStreamGovernedParameterAuthority()"), abi.encode(true)
        );
        executor.answer(abi.encodeWithSignature("currentAction()"), new bytes(192));
        fixture = new RecoveryGovernanceCompositionFixture();
        fixture.initialize(address(core), address(executor), address(roles));
        recovery = fixture.recovery();
        address selectedArtist = fixture.artistTarget();
        _pointer(
            keccak256("MODULE_REGISTRY"),
            address(modules),
            keccak256("MODULE_REGISTRY"),
            0x11223344,
            address(modules).codehash
        );
        _pointer(RECOVERY, address(recovery), KIND, 0x83685f5c, address(recovery).codehash);
        _pointer(
            keccak256("ARTIST_REGISTRY"),
            selectedArtist,
            keccak256("ARTIST_REGISTRY"),
            type(IStreamArtistMintConsent).interfaceId,
            selectedArtist.codehash
        );
        modules.answer(
            abi.encodeCall(
                IStreamModuleRegistry.isModuleEligible,
                (address(recovery), KIND, bytes4(0x83685f5c))
            ),
            abi.encode(true)
        );
        modules.answer(
            abi.encodeCall(
                IStreamModuleRegistry.isModuleEligible,
                (
                    selectedArtist,
                    keccak256("ARTIST_REGISTRY"),
                    type(IStreamArtistMintConsent).interfaceId
                )
            ),
            abi.encode(true)
        );
    }

    function testActualRegisteredIntentRequiresMoreThanMetadata150k() public {
        (RecoveryGovernanceCompositionFixture fixture, StreamArtworkFinalityRecovery recovery) =
            _fixture();
        address selectedArtist = fixture.artistTarget();
        StreamFinalityRecoveryRequest memory r = fixture.requestFacts();
        bytes memory input = abi.encodeCall(
            IStreamArtistRecoveryIntent.requireArtistRecoveryIntent,
            (r.scope, r.expectedOriginalFinalityRecordHash, r.recoveryManifest.contentHash)
        );
        (bool small,) = address(recovery).staticcall{ gas: 150000 }(input);
        require(!small, "whole preparation cannot forward nested150k plus reserve");
        // Explicitly cool this target and its named direct dependency set. Not an all-library
        // cold transaction, and not a full current OwnerRecords500k evidence callback claim.
        OwnerIntentCapacityVm cooling = OwnerIntentCapacityVm(address(vm));
        cooling.cool(address(recovery));
        cooling.cool(address(core));
        cooling.cool(address(modules));
        cooling.cool(selectedArtist);
        cooling.cool(fixture.ownerTarget());
        cooling.cool(address(fixture.history()));
        cooling.cool(r.replacementRoute.component);
        uint256 before_ = gasleft();
        (bool enough, bytes memory output) = address(recovery).staticcall{ gas: 2000000 }(input);
        uint256 used = before_ - gasleft();
        require(enough && output.length == 128, "actual stored request healthy control");
        IStreamArtistRecoveryIntent.Facts memory facts =
            abi.decode(output, (IStreamArtistRecoveryIntent.Facts));
        require(
            facts.requestHash == keccak256(abi.encode(r))
                && facts.scopeHash
                    == keccak256(
                        abi.encode(
                            keccak256("6529STREAM_FINALITY_RECOVERY_SCOPE_V1"),
                            block.chainid,
                            address(recovery),
                            r.scope
                        )
                    ),
            "actual original request and scope"
        );
        emit IntentPreparationGas(used);
        // A liveness-only owner proof cannot make a mutated request executable: the actual
        // companion rejects its staged-intent mismatch before reaching owner evidence.
        r.expectedOldRouteHash = keccak256("changed current-lineage claim");
        cooling.prank(address(executor));
        cooling.expectRevert();
        recovery.executeFinalityRecovery(r);
    }

    function testMaximumRegisteredRequestRetainsAllReasonBytes() public {
        (RecoveryGovernanceCompositionFixture fixture, StreamArtworkFinalityRecovery recovery) =
            _fixture();
        StreamFinalityRecoveryRequest memory r = fixture.requestFacts();
        uint256 fixedBytes = abi.encode(r).length - ((bytes(r.reasonURI).length + 31) / 32) * 32;
        bytes memory reason = new bytes(24544 - fixedBytes);
        for (uint256 i; i < reason.length; ++i) {
            reason[i] = 0x61;
        }
        r.reasonURI = string(reason);
        require(abi.encode(r).length == 24544, "largest ABI word-aligned SSTORE2 request");
        r.recoveryManifest.contentHash =
            recovery.stageFinalityRecoveryManifest(recovery.finalityRecoveryIntentBytes(r));
        recovery.registerFinalityRecoveryIntent(r);
        bytes memory input = abi.encodeCall(
            IStreamArtistRecoveryIntent.requireArtistRecoveryIntent,
            (r.scope, r.expectedOriginalFinalityRecordHash, r.recoveryManifest.contentHash)
        );
        OwnerIntentCapacityVm cooling = OwnerIntentCapacityVm(address(vm));
        cooling.cool(address(recovery));
        cooling.cool(address(core));
        cooling.cool(address(modules));
        cooling.cool(fixture.artistTarget());
        cooling.cool(fixture.ownerTarget());
        cooling.cool(address(fixture.history()));
        cooling.cool(r.replacementRoute.component);
        uint256 before_ = gasleft();
        (bool ok, bytes memory output) = address(recovery).staticcall{ gas: 8000000 }(input);
        uint256 used = before_ - gasleft();
        require(ok && output.length == 128, "maximum complete registered request");
        IStreamArtistRecoveryIntent.Facts memory f =
            abi.decode(output, (IStreamArtistRecoveryIntent.Facts));
        require(f.requestHash == keccak256(abi.encode(r)), "every exact reason byte retained");
        emit MaximumIntentPreparationGas(used, abi.encode(r).length);
    }
    event MaximumIntentPreparationGas(uint256 gasUsed, uint256 requestBytes);
    event IntentPreparationGas(uint256 gasUsed);
}
