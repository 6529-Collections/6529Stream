// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "./StreamArtistPlatformWorks.t.sol";

/// @notice Original op10 claimant/Archive proof, using real accepted or refused Artist generations.
/// @dev Actual Artist/Safe/Archive/preservation; inherited selected metadata and Core/governance boundaries.
contract StreamArtistAttributionClaimsTest is StreamArtistPlatformWorksTest {
    function _displayClaimEvidence() private view returns (bytes32) {
        PW.State memory p = ingress.platformWorksState(2);
        return ingress.platformWorksClaimRecord(p.latestClaim).evidenceHash;
    }

    function _displayAttribution() private view returns (bytes32) {
        (uint8 state, uint64 generation) =
            IStreamArtistAttributionOwner(suite.owners[4]).attributionState(2);
        return keccak256(
            abi.encode(state, generation, ingress.displayBinding(2), ingress.platformWorksState(2))
        );
    }

    function _displayClaim(address actor, bytes32 evidence, string memory uri)
        private
        returns (bytes32)
    {
        vm.prank(actor);
        return ingress.fileAttributionClaim(2, evidence, evidence, uri);
    }

    function _displayGuardedRoutes(bytes32 evidence) private {
        T.ActionContext memory context = T.ActionContext(
            10, address(0xFA1E), IStreamArtistOwner(suite.owners[4]).ownerStateSnapshotV2()
        );
        address writer = ingress.registryWriterExtension();
        bytes32 roots = _roots();
        vm.expectRevert(abi.encodeWithSelector(T.Unauthorized.selector, address(this)));
        IStreamArtistAttributionClaimsOwner(suite.owners[4])
            .fileAttributionClaim(
                context, 2, evidence, evidence, "urn:forged:owner", address(artist)
            );
        vm.expectRevert(abi.encodeWithSelector(T.Unauthorized.selector, address(this)));
        IStreamArtistAttributionClaimsCoordinator(address(coordinator))
            .coordinateFileAttributionClaim(
                address(0xFA1E), 2, evidence, evidence, "urn:forged:coordinator"
            );
        vm.expectRevert(abi.encodeWithSignature("ExtensionWrongHost(address)", writer));
        IStreamArtistAttributionClaims(writer)
            .fileAttributionClaim(2, evidence, evidence, "urn:direct:writer");
        require(
            _roots() == roots,
            "permissionless facade never permits actor-forged owner or coordinator callbacks"
        );
    }

    function _displayClaimArchive(address actor, bytes32 record) private view {
        bytes32 id = keccak256(
            abi.encode(
                keccak256("6529STREAM_ARTIST_ONBOARDING_OPERATION_EVIDENCE_V1"),
                block.chainid,
                address(ingress),
                address(coordinator),
                uint16(10),
                actor,
                record
            )
        );
        (uint16 version, bytes32 config, uint16 op, address savedActor, bytes32 saved,,,) = abi.decode(
            archive.artistEvidenceBytesV2(id, 1),
            (uint16, bytes32, uint16, address, bytes32, T.Snapshot[7], T.Snapshot[7], bytes)
        );
        require(
            version == 1 && config == coordinator.configurationHash() && op == 10
                && savedActor == actor && saved == record,
            "actual original op10 archived actor/record/configuration"
        );
    }

    function testDisplayBoundClaimsOriginalHashAndNoAttributionOrStandingAuthority() public {
        this.testSustainedCorrectionActualSafeAcceptanceAndFreshMintPrerequisites();
        require(
            ingress.displayBinding(2).accepted,
            "actual Artist acceptance, not platform-only surrogate"
        );
        bytes32 evidence = _displayClaimEvidence();
        bytes32 state = _displayAttribution();
        _displayGuardedRoutes(evidence);
        address claimant = address(0xBADA55);
        bytes32 record = _displayClaim(claimant, evidence, "urn:unaffiliated:claim");
        StreamArtistAttributionClaimTypes.Claim memory c = ingress.attributionClaimRecord(record);
        require(
            record
                == keccak256(
                    abi.encode(
                        keccak256("6529STREAM_ARTIST_ATTRIBUTION_CLAIM_RECORD_V1"),
                        block.chainid,
                        address(ingress),
                        address(core),
                        uint256(2),
                        claimant,
                        evidence,
                        evidence,
                        c.filedAt
                    )
                ),
            "independently rebuilt original op10 permanent record"
        );
        (uint256 count, bytes32 latest) = ingress.attributionClaims(2);
        require(
            count == ingress.platformWorksState(2).claimCount + 1 && latest == record
                && c.index == 1 && c.previousRecordHash == 0 && c.claimant == claimant
                && _displayAttribution() == state,
            "permissionless evidence changes only claim history, not current attribution or bound authority"
        );
        _displayClaimArchive(claimant, record);
        ingress.requireMintConsent(2, PHASE, POLICY);
        vm.prank(claimant);
        vm.expectRevert(abi.encodeWithSelector(T.Unauthorized.selector, claimant));
        ingress.approvePlatformWorksCorrection(2, record, evidence, evidence);
        require(_displayAttribution() == state, "claim filing grants no correction authority");
    }

    function testDisplayRefusedAttributionStillAcceptsClaimsAndPermanentTupleReplay() public {
        this.testRefusedCorrectiveGenerationPermanentlyConsumesOnlyApproval();
        (uint8 state,) = IStreamArtistAttributionOwner(suite.owners[4]).attributionState(2);
        require(
            state == 5 && !ingress.displayBinding(2).accepted, "actual refused Artist generation"
        );
        bytes32 original = _displayAttribution();
        bytes32 evidence = _displayClaimEvidence();
        address actor = address(0xC1A1);
        bytes32 first = _displayClaim(actor, evidence, "urn:claim:first");
        bytes32 second = _displayClaim(address(0xC1A2), evidence, "urn:claim:second");
        (uint256 count, bytes32 latest) = ingress.attributionClaims(2);
        require(
            count == ingress.platformWorksState(2).claimCount + 2 && latest == second
                && ingress.attributionClaimRecord(second).previousRecordHash == first
                && ingress.attributionClaimRecord(first).claimant == actor
                && _displayAttribution() == original,
            "refusal cannot block public allegations and all original records remain"
        );
        bytes32 roots = _roots();
        vm.prank(actor);
        vm.expectRevert(
            abi.encodeWithSelector(
                StreamArtistAttributionClaimTypes.InvalidAttributionClaim.selector, uint256(2)
            )
        );
        ingress.fileAttributionClaim(
            2, evidence, evidence, "changed URI cannot replay same claimant tuple"
        );
        require(roots == _roots(), "permanent tuple replay leaves count/history/Archive unchanged");
    }

    function testDisplayCombinedClaimsPreserveActualSameBlockOrderAcrossCorrection() public {
        this.testSustainedCorrectionActualSafeAcceptanceAndFreshMintPrerequisites();
        bytes32 evidence = _displayClaimEvidence();
        (uint256 originalCount, bytes32 originalLatest) = ingress.attributionClaims(2);
        require(
            originalCount != 0 && originalLatest == ingress.platformWorksState(2).latestClaim,
            "original Platform history survives actual correction"
        );
        bytes32 first = _displayClaim(address(0xCC01), evidence, "urn:artist:one");
        vm.prank(address(0xCC02));
        bytes32 middle = ingress.filePlatformWorksClaim(2, evidence, evidence, "urn:platform:two");
        (uint256 count, bytes32 latest) = ingress.attributionClaims(2);
        require(
            count == originalCount + 2 && latest == middle,
            "same-block original op9 after op10 is actual latest, not a timestamp guess"
        );
        bytes32 last = _displayClaim(address(0xCC03), evidence, "urn:artist:three");
        (count, latest) = ingress.attributionClaims(2);
        require(
            count == originalCount + 3 && latest == last
                && ingress.platformWorksState(2).latestClaim == middle
                && ingress.attributionClaimRecord(last).previousRecordHash == first
                && ingress.attributionClaimRecord(first).filedAt
                    == ingress.platformWorksClaimRecord(middle).filedAt
                && ingress.attributionClaimRecord(last).filedAt
                    == ingress.platformWorksClaimRecord(middle).filedAt,
            "combined ordering preserves both canonical separate record chains"
        );
    }

    function testDisplayClaimLateArchiveRollbackAndIdenticalCallerRetry() public {
        this.testSustainedCorrectionActualSafeAcceptanceAndFreshMintPrerequisites();
        bytes32 evidence = _displayClaimEvidence();
        bytes32 original = _displayAttribution();
        bytes32 roots = _roots();
        (uint256 originalCount, bytes32 originalLatest) = ingress.attributionClaims(2);
        uint256 oldBlock = block.number;
        address actor = address(0xC1A3);
        vm.roll(uint256(type(uint64).max) + 1);
        vm.prank(actor);
        vm.expectRevert(
            abi.encodeWithSignature(
                "ArtistArchiveBlockNumberOverflow(uint256)", uint256(type(uint64).max) + 1
            )
        );
        ingress.fileAttributionClaim(2, evidence, evidence, "urn:claim:retry");
        (uint256 count, bytes32 latest) = ingress.attributionClaims(2);
        require(
            count == originalCount && latest == originalLatest && roots == _roots()
                && _displayAttribution() == original,
            "late Archive failure rolls back count, latest, immutable claim and replay atomically"
        );
        vm.roll(oldBlock);
        bytes32 record = _displayClaim(actor, evidence, "urn:claim:retry");
        (count, latest) = ingress.attributionClaims(2);
        require(
            count == originalCount + 1 && latest == record && _displayAttribution() == original,
            "identical original caller/calldata retry"
        );
        _displayClaimArchive(actor, record);
    }
}
