// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    IStreamArtistStaticIdentityProjection as Projection
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistStaticIdentityProjection.sol";
import {
    StreamArtistStaticIdentityProjection as ProjectionData
} from "../../../smart-contracts/domains/artist/StreamArtistStaticIdentityProjection.sol";
import "./ArtistOnboardingFixture.sol";
import {
    IStreamStaticArtistSource
} from "../../../smart-contracts/interfaces/stream/metadata/IStreamStaticArtistSource.sol";
import {
    IStreamArtistStaticFacts as SF
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistStaticFacts.sol";
import {
    IStreamArtistDisplayFacts
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistDisplayFacts.sol";
import {
    IStreamArtistAttributionClaims
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistAttributionClaims.sol";
import {
    StreamArtistStaticDisplay
} from "../../../smart-contracts/domains/artist/StreamArtistStaticDisplay.sol";
import {
    StreamArtistAttributionReadEncoding
} from "../../../smart-contracts/domains/artist/StreamArtistAttributionReadEncoding.sol";
import {
    StreamArtistIdentityPayloadReads
} from "../../../smart-contracts/domains/artist/StreamArtistIdentityPayloadReads.sol";
import {
    StreamArtistIdentitySupplementalReads
} from "../../../smart-contracts/domains/artist/StreamArtistIdentitySupplementalReads.sol";
import {
    StreamArtistSanctionState
} from "../../../smart-contracts/domains/artist/StreamArtistSanctionState.sol";

/// @notice Actual Artist owners, Safe writes and Archive; Core/finality/governance stay typed fixtures.
/// @dev ABI/source tests alone are not transitive STATIC or deployment-size runtime acceptance.
abstract contract ArtistStaticDisplayFixture is ArtistOnboardingFixture {
    function _static(bytes memory data) internal view returns (bytes memory) {
        return IStreamStaticArtistSource(address(ingress)).staticDisplayRead(data);
    }

    function _parity(bytes memory data) internal view returns (bytes memory result) {
        (bool ok, bytes memory original) = address(ingress).staticcall(data);
        require(ok, "original admitted read");
        result = _static(data);
        require(keccak256(result) == keccak256(original), "exact original ABI result");
    }

    function _reject(bytes memory data) internal view {
        (bool ok,) = address(ingress)
            .staticcall(abi.encodeCall(IStreamStaticArtistSource.staticDisplayRead, (data)));
        require(!ok, "STATIC read must fail closed");
    }

    function _queries() internal view returns (bytes[] memory calls) {
        calls = new bytes[](12);
        calls[0] = abi.encodeWithSignature("collectionArtistState(uint256)", uint256(1));
        calls[1] = abi.encodeCall(IStreamArtistDisplayFacts.displayBinding, (uint256(1)));
        calls[2] = abi.encodeWithSignature("platformWorksState(uint256)", uint256(1));
        calls[3] = abi.encodeWithSignature("attribution(uint256)", uint256(1));
        calls[4] = abi.encodeCall(IStreamArtistDisplayFacts.attributionClaims, (uint256(1)));
        calls[5] = abi.encodeCall(IStreamArtistDisplayFacts.deploymentAttestation, (uint256(1)));
        calls[6] = abi.encodeWithSignature("artistDisplayName(bytes32)", artistId);
        calls[7] = abi.encodeWithSignature("operativeIdentityRecord(bytes32)", artistId);
        calls[8] =
            abi.encodeWithSignature("collaboratorCount(uint256,uint64)", uint256(1), uint64(1));
        calls[9] = abi.encodeCall(
            IStreamArtistDisplayFacts.artistAttestationStatus,
            (uint256(1), uint8(9), bytes32(uint256(uint160(address(core)))), bytes32(0))
        );
        calls[10] = abi.encodeCall(
            IStreamArtistDisplayFacts.displaySanction,
            (StreamFinalityScope(StreamFinalityScopeType.COLLECTION, 1, 0, 0))
        );
        calls[11] = abi.encodeWithSignature(
            "verifySanctionForSubject(uint8,uint256,uint256,bytes32,bytes32)",
            uint8(0),
            uint256(1),
            uint256(0),
            bytes32(0),
            keccak256("absent subject")
        );
    }
}

contract StreamArtistStaticDisplayTest is ArtistStaticDisplayFixture {
    function testStaticClaimedAndAcceptedDisplayMatchesOriginalFactsWithoutWrites() public {
        bytes[] memory calls = _queries();
        for (uint256 i; i < calls.length; ++i) {
            _parity(calls[i]);
        }
        _all();
        bytes32 roots = _roots();
        uint256 nonce = artist.nonce();
        for (uint256 i; i < calls.length; ++i) {
            _parity(calls[i]);
        }
        require(
            _roots() == roots && artist.nonce() == nonce, "reads consume no authority or Safe nonce"
        );
    }

    function testStaticOriginalClaimsAndAttestationFreshnessRemainDistinct() public {
        _all();
        bytes32 claim = IStreamArtistAttributionClaims(address(ingress))
            .fileAttributionClaim(
                1, keccak256("claim evidence"), keccak256("claim reason"), "urn:claim"
            );
        (uint256 count, bytes32 latest) = abi.decode(
            _parity(abi.encodeCall(IStreamArtistDisplayFacts.attributionClaims, (uint256(1)))),
            (uint256, bytes32)
        );
        require(count == 1 && latest == claim, "actual permissionless claim retained");
        bytes32 subject = bytes32(uint256(uint160(address(core))));
        T.AttestationRecord memory record =
            IStreamArtistAttributionOwner(suite.owners[4]).attestation(1, 9, subject);
        (uint8 status,,,,) = abi.decode(
            _parity(
                abi.encodeCall(
                    IStreamArtistDisplayFacts.artistAttestationStatus,
                    (uint256(1), uint8(9), subject, record.subjectStateHash)
                )
            ),
            (uint8, bytes32, bytes32, uint8, uint64)
        );
        require(status == 1, "actual current attestation");
        (status,,,,) = abi.decode(
            _parity(
                abi.encodeCall(
                    IStreamArtistDisplayFacts.artistAttestationStatus,
                    (uint256(1), uint8(9), subject, keccak256("drift"))
                )
            ),
            (uint8, bytes32, bytes32, uint8, uint64)
        );
        require(status == 2, "actual state drift stays stale");
    }

    function testStaticSavedSanctionUsesExactBindingAndSubject() public {
        _all();
        (Q.Request memory q,) = _sanctionPrepared();
        bytes32 hash = ingress.recordArtistSanction(q, _sanctionAuthorization(q));
        bytes memory raw = _parity(
            abi.encodeCall(
                IStreamArtistDisplayFacts.displaySanction,
                (StreamFinalityScope(StreamFinalityScopeType.COLLECTION, 1, 0, 0))
            )
        );
        require(abi.decode(raw, (S.Record)).recordHash == hash, "actual signed sanction record");
        (bool valid, bytes32 got, address signer, uint8 class_) = abi.decode(
            _parity(
                abi.encodeWithSignature(
                    "verifySanctionForSubject(uint8,uint256,uint256,bytes32,bytes32)",
                    uint8(0),
                    uint256(1),
                    uint256(0),
                    bytes32(0),
                    q.terms.sanctionSubjectHash
                )
            ),
            (bool, bytes32, address, uint8)
        );
        require(
            valid && got == hash && signer == address(artist) && class_ == 1,
            "exact original authorship"
        );
        (valid, got,,) = abi.decode(
            _parity(
                abi.encodeWithSignature(
                    "verifySanctionForSubject(uint8,uint256,uint256,bytes32,bytes32)",
                    uint8(0),
                    uint256(1),
                    uint256(0),
                    bytes32(0),
                    keccak256("wrong subject")
                )
            ),
            (bool, bytes32, address, uint8)
        );
        require(!valid && got == hash, "subject mismatch does not erase historical record");
    }

    function testStaticSurvivesUnavailableLegacyDelegateCodecs() public {
        _all();
        bytes[] memory calls = _queries();
        bytes[] memory expected = new bytes[](calls.length);
        for (uint256 i; i < calls.length; ++i) {
            expected[i] = _parity(calls[i]);
        }
        // Only the old delegate read codecs are poisoned. Fixed owners/data remain actual.
        vm.etch(address(StreamArtistAttributionReadEncoding), hex"60006000fd");
        vm.etch(address(StreamArtistIdentityPayloadReads), hex"60006000fd");
        vm.etch(address(StreamArtistIdentitySupplementalReads), hex"60006000fd");
        vm.etch(address(StreamArtistSanctionState), hex"60006000fd");
        for (uint256 i; i < calls.length; ++i) {
            require(
                keccak256(_static(calls[i])) == keccak256(expected[i]), "no legacy codec fallback"
            );
        }
        (bool old,) = address(ingress).staticcall(calls[2]);
        require(!old, "poison reaches original codec control");
    }

    function testStaticUnknownNonCanonicalAndMalformedOwnerReadsAreClosed() public {
        bytes32 roots = _roots();
        uint256 nonce = artist.nonce();
        _reject(hex"");
        _reject(hex"ffffffff");
        _reject(
            abi.encodeWithSignature(
                "recordPayoutDesignation(bytes32,address)", artistId, address(this)
            )
        );
        _reject(
            bytes.concat(
                abi.encodeCall(IStreamArtistDisplayFacts.displayBinding, (uint256(1))), hex"00"
            )
        );
        _reject(
            abi.encodePacked(
                IStreamArtistDisplayFacts.artistAttestationStatus.selector, bytes32(uint256(1))
            )
        );
        bytes memory query = abi.encodeWithSignature("collectionArtistState(uint256)", uint256(1));
        avm.mockCall(
            suite.owners[4], abi.encodeCall(SF.staticAttributionState, (uint256(1))), new bytes(63)
        );
        _reject(query);
        avm.clearMockedCalls();
        _parity(query);
        avm.mockCall(
            suite.owners[4],
            abi.encodeCall(SF.staticAttributionState, (uint256(1))),
            abi.encode(uint8(1), uint64(99))
        );
        _reject(query);
        avm.clearMockedCalls();
        _parity(query);
        require(_roots() == roots && artist.nonce() == nonce, "exact restoration without mutation");
    }

    function testStaticCollectionSelectionAndForeignWorkerContextRemainClosed() public {
        bytes memory data = abi.encodeWithSignature("collectionArtistState(uint256)", uint256(1));
        (bool foreign,) = address(StreamArtistStaticDisplay)
            .staticcall(
                abi.encodeWithSelector(
                    StreamArtistStaticDisplay.read.selector, address(coordinator), data
                )
            );
        require(!foreign, "caller cannot impersonate the bound facade");
        core.set(keccak256("ARTIST_REGISTRY"), address(artist), false);
        _reject(data);
        // The original historical binding getter intentionally has no current-selection gate.
        _parity(abi.encodeCall(IStreamArtistDisplayFacts.displayBinding, (uint256(1))));
        core.set(keccak256("ARTIST_REGISTRY"), address(ingress), false);
        _parity(data);
    }
    OfficialSafe private staticPrior;
    uint256[] private staticPriorKeys;
    bytes32 private staticRotation;
    bytes32 private staticCandidate;
    bytes32 private staticDocument;
    uint64 private staticWindow;

    function stageStaticProvisionalIdentity() external returns (bytes32) {
        require(msg.sender == address(this), "self only");
        _accept();
        _selfGuardian();
        staticPrior = artist;
        staticPriorKeys = keys;
        _newRotationSafe(98501);
        return _stageRotation(0);
    }

    function finishStaticProvisionalIdentity(bytes32 rotation) external {
        require(msg.sender == address(this), "self only");
        ingress.executeArtistRotation(artistId, rotation);
        _adoptRotatedSafe();
        staticRotation = rotation;
        staticDocument = keccak256("actual static provisional document");
        staticCandidate = _reviseDocument(bytes("actual static provisional document"));
        staticWindow = ingress.rotationRecord(rotation).transition.postWindowEndsAt;
    }

    function _prepareMaturity() private {
        bytes32 rotation = this.stageStaticProvisionalIdentity();
        uint64 start = ingress.rotationRecord(rotation).transition.contestEndsAt;
        vm.warp(start);
        this.finishStaticProvisionalIdentity(rotation);
    }

    function _identityQuery() private view returns (bytes memory) {
        return abi.encodeWithSignature("operativeIdentityRecord(bytes32)", artistId);
    }

    function _maturityContext() private view returns (ProjectionData.Context memory c) {
        T.Identity memory actual = IStreamArtistIdentityOwner(suite.owners[2]).identity(artistId);
        c = ProjectionData.Context(
            artistId,
            staticCandidate,
            staticDocument,
            staticRotation,
            actual.authorityAddress,
            actual.authorityClass,
            actual.status,
            ingress.identityRevisionProvisionalAssociation(staticCandidate),
            ingress.rotationRecord(staticRotation).transition
        );
    }

    function _checkpoint() private returns (bytes32) {
        return Projection(address(ingress)).checkpointStaticIdentityMaturity(artistId);
    }

    function testStaticMaturityBoundarySafeCheckpointExactEventAndIdempotence() public {
        bytes32 registration = ingress.operativeIdentityRecord(artistId);
        _prepareMaturity();
        _reject(_identityQuery());
        require(
            ingress.operativeIdentityRecord(artistId) == registration,
            "original early live selection unchanged"
        );
        vm.warp(staticWindow - 1);
        vm.expectRevert(
            abi.encodeWithSelector(
                Projection.StaticIdentityMaturityUnavailable.selector, artistId, staticCandidate
            )
        );
        _checkpoint();
        vm.warp(staticWindow);
        this.assertStaticBoundaryCheckpoint();
    }

    function assertStaticBoundaryCheckpoint() external {
        require(msg.sender == address(this), "self only");
        _reject(_identityQuery()); // Passage of time alone never installs the derived marker.
        ProjectionData.Context memory c = _maturityContext();
        bytes32 expected = keccak256(
            abi.encode(
                keccak256("6529STREAM_ARTIST_STATIC_IDENTITY_MATURITY_V1"),
                block.chainid,
                suite.owners[2],
                address(ingress),
                c
            )
        );
        bytes32 roots = _roots();
        uint256 nonce = artist.nonce();
        uint256 identityNonce =
            IStreamArtistIdentityOwner(suite.owners[2]).identity(artistId).nonceHint;
        vm.recordLogs();
        require(
            executeSafe(
                artist,
                keys,
                address(ingress),
                0,
                abi.encodeCall(Projection.checkpointStaticIdentityMaturity, (artistId)),
                0
            ),
            "actual Safe checkpoint"
        );
        Vm.Log[] memory logs = vm.getRecordedLogs();
        uint256 count;
        bytes32 topic = keccak256(
            "ArtistStaticIdentityMaturityCheckpointed(uint16,bytes32,bytes32,bytes32,uint256,address,bytes)"
        );
        for (uint256 i; i < logs.length; ++i) {
            if (logs[i].topics.length != 0 && logs[i].topics[0] == topic) {
                ++count;
                require(
                    logs[i].emitter == suite.owners[2] && logs[i].topics.length == 4
                        && logs[i].topics[1] == artistId && logs[i].topics[2] == staticCandidate
                        && logs[i].topics[3] == expected,
                    "actual fixed-owner checkpoint topics"
                );
                require(
                    keccak256(logs[i].data)
                        == keccak256(
                            abi.encode(uint16(1), block.chainid, address(ingress), abi.encode(c))
                        ),
                    "complete independent context event"
                );
            }
        }
        require(
            count == 1 && artist.nonce() == nonce + 1 && _roots() == roots
                && IStreamArtistIdentityOwner(suite.owners[2]).identity(artistId).nonceHint
                    == identityNonce,
            "derivative only; no signed authority/Archive mutation"
        );
        require(
            abi.decode(_parity(_identityQuery()), (bytes32)) == staticDocument,
            "mature static/live parity"
        );
        (string memory name, bytes32 hash) = abi.decode(
            _parity(abi.encodeWithSignature("artistDisplayName(bytes32)", artistId)),
            (string, bytes32)
        );
        require(
            hash == staticDocument && keccak256(bytes(name)) == keccak256("Revised Artist"),
            "exact selected document/name"
        );
        vm.recordLogs();
        require(_checkpoint() == expected, "permissionless idempotent marker");
        require(
            vm.getRecordedLogs().length == 0 && _roots() == roots,
            "no duplicate checkpoint event or owner revision"
        );
    }

    function _contestStaticSource() private {
        require(
            executeSafe(staticPrior, staticPriorKeys, address(ingress), 0, _contestData(0), 0),
            "actual original lifetime guardian"
        );
    }

    function testStaticEarlyContestedCandidateNeverObtainsMaturityProjection() public {
        bytes32 registration = ingress.operativeIdentityRecord(artistId);
        _prepareMaturity();
        vm.warp(staticWindow - 1);
        _contestStaticSource();
        vm.warp(staticWindow + 1);
        this.assertStaticAbandonedCandidate(registration);
    }

    function assertStaticAbandonedCandidate(bytes32 registration) external {
        require(msg.sender == address(this), "self only");
        _reject(_identityQuery());
        vm.expectRevert(
            abi.encodeWithSelector(
                Projection.StaticIdentityMaturityUnavailable.selector, artistId, staticCandidate
            )
        );
        _checkpoint();
        require(
            ingress.operativeIdentityRecord(artistId) == registration,
            "original abandoned candidate stays ineligible"
        );
    }

    function testStaticLateContestInvalidatesCheckpointUntilCurrentFactsAreCheckpointed() public {
        _prepareMaturity();
        vm.warp(staticWindow);
        bytes32 first = _checkpoint();
        _parity(_identityQuery());
        vm.warp(staticWindow + 1);
        _contestStaticSource();
        _reject(_identityQuery());
        require(
            ingress.operativeIdentityRecord(artistId) == staticDocument,
            "late contest retains original mature document semantics"
        );
        bytes32 second = _checkpoint();
        require(second != first, "contest and status are bound into exact projection");
        _parity(_identityQuery());
    }

    function stageNextStaticAuthority() external returns (bytes32) {
        require(msg.sender == address(this), "self only");
        _newRotationSafe(98502);
        return _stageRotation(staticRotation);
    }

    function finishNextStaticAuthority(bytes32 rotation) external {
        require(msg.sender == address(this), "self only");
        ingress.executeArtistRotation(artistId, rotation);
        _adoptRotatedSafe();
    }

    function testStaticExecutedAuthorityGenerationInvalidatesOriginalMarker() public {
        _prepareMaturity();
        vm.warp(staticWindow);
        bytes32 first = _checkpoint();
        _parity(_identityQuery());
        bytes32 next = this.stageNextStaticAuthority();
        uint64 start = ingress.rotationRecord(next).transition.contestEndsAt;
        vm.warp(start);
        this.finishNextStaticAuthority(next);
        _reject(_identityQuery());
        require(
            ingress.operativeIdentityRecord(artistId) == staticDocument,
            "original revision survives later authority rotation"
        );
        bytes32 second = _checkpoint();
        require(second != first, "new actual execution head cannot reuse old projection");
        _parity(_identityQuery());
    }

    function testStaticNewProvisionalCandidateCannotReusePriorCheckpoint() public {
        _prepareMaturity();
        vm.warp(staticWindow);
        bytes32 first = _checkpoint();
        _parity(_identityQuery());
        bytes32 next = this.stageNextStaticAuthority();
        vm.warp(ingress.rotationRecord(next).transition.contestEndsAt);
        this.finishNextStaticAuthority(next);
        _reviseDocument(bytes("different provisional candidate"));
        _reject(_identityQuery());
        uint64 end = ingress.rotationRecord(next).transition.postWindowEndsAt;
        vm.warp(end);
        bytes32 second = _checkpoint();
        require(first != second, "new candidate and association cannot reuse prior marker");
        require(
            abi.decode(_parity(_identityQuery()), (bytes32))
                == keccak256("different provisional candidate"),
            "exact new current document"
        );
    }

    /// @dev The Coordinator caller is an explicit typed boundary here. Original owner state writers
    /// create all twenty nonzero/packed output fields; this is an encoder oracle, not approval proof.
    function testStaticPlatformCorrectionPackedFieldsMatchOriginalStateWriters() public {
        ingress.declarePlatformWorks(2, keccak256("packed declaration"));
        StreamArtistAttributionLifecycle target = StreamArtistAttributionLifecycle(suite.owners[4]);
        bytes32 evidence = keccak256("packed evidence");
        bytes32 reason = keccak256("packed reason");
        T.ActionContext memory c = _staticOwnerContext(9);
        vm.prank(address(coordinator));
        bytes32 claim =
            target.filePlatformWorksClaim(c, 2, evidence, reason, "urn:packed", address(artist));
        c = _staticOwnerContext(11);
        vm.prank(address(coordinator));
        target.setPlatformWorksContest(
            c, 2, 1, claim, evidence, reason, keccak256("open packed"), address(artist)
        );
        c = _staticOwnerContext(11);
        vm.prank(address(coordinator));
        target.setPlatformWorksContest(
            c, 2, 3, claim, evidence, reason, keccak256("sustain packed"), address(artist)
        );
        c = _staticOwnerContext(53);
        vm.prank(address(coordinator));
        bytes32 correction = target.approvePlatformWorksCorrection(
            c, 2, claim, evidence, reason, keccak256("correct packed")
        );
        PW.State memory pending = abi.decode(
            _parity(abi.encodeWithSignature("platformWorksState(uint256)", uint256(2))), (PW.State)
        );
        require(
            pending.correction.recordHash == correction
                && pending.correction.proposedArtist == address(artist)
                && pending.correction.approvedAt == block.timestamp && !pending.correction.accepted,
            "all original correction words"
        );
        T.Binding memory b = IStreamArtistBindingOwner(suite.owners[0]).binding(1);
        b.accepted = false;
        b.generation = 1;
        b.bindingHash = keccak256("typed corrective binding");
        c = _staticOwnerContext(1);
        vm.prank(address(coordinator));
        target.claim(c, 2, b, reason, "urn:packed");
        c = _staticOwnerContext(2);
        vm.prank(address(coordinator));
        target.accept(c, 2, b, keccak256("typed corrective acceptance"));
        PW.State memory accepted = abi.decode(
            _parity(abi.encodeWithSignature("platformWorksState(uint256)", uint256(2))), (PW.State)
        );
        require(
            accepted.correction.correctiveGeneration == 1 && accepted.correction.accepted
                && accepted.correction.approvedAt == pending.correction.approvedAt
                && accepted.correction.recordHash == correction,
            "packed uint64/uint64/bool retain exact positions"
        );
    }

    function _staticOwnerContext(uint16 operation) private view returns (T.ActionContext memory) {
        return T.ActionContext(
            operation, address(this), IStreamArtistOwner(suite.owners[4]).ownerStateSnapshotV2()
        );
    }

    function testStaticActualPlatformDeclarationKeepsOriginalStateEncoding() public {
        bytes32 hash = ingress.declarePlatformWorks(2, keccak256("static declaration"));
        PW.State memory state = abi.decode(
            _parity(abi.encodeWithSignature("platformWorksState(uint256)", uint256(2))), (PW.State)
        );
        require(
            state.declaration.recordHash == hash && state.declaration.actor == address(this)
                && state.declaration.declaredAt == block.timestamp && state.contestState == 0,
            "actual nonzero declaration words"
        );
    }
}

contract StreamArtistStaticCollaboratorDisplayTest is ArtistStaticDisplayFixture {
    function _initialBindingProposal() internal view override returns (T.BindingProposal memory p) {
        p = _proposal(0);
        p.collaborators = new T.CollaboratorRecord[](1);
        p.collaborators[0] =
            T.CollaboratorRecord(address(0x1234), keccak256("photographer"), bytes32(0));
    }

    function testStaticProposedCollaboratorKeepsIdentityUnaccepted() public {
        bytes memory data = abi.encodeWithSignature(
            "collaboratorAt(uint256,uint64,uint256)", uint256(1), uint64(1), uint256(0)
        );
        C.Row memory row = abi.decode(_parity(data), (C.Row));
        require(
            row.account == address(0x1234) && row.role == keccak256("photographer") && !row.accepted
                && row.collaboratorArtistId == 0,
            "no invented collaborator identity acceptance"
        );
        require(
            abi.decode(
                _parity(
                    abi.encodeWithSignature(
                        "collaboratorCount(uint256,uint64)", uint256(1), uint64(1)
                    )
                ),
                (uint256)
            ) == 1,
            "exact original proposed count"
        );
        _reject(
            abi.encodeWithSignature(
                "collaboratorAt(uint256,uint64,uint256)", uint256(1), uint64(1), uint256(1)
            )
        );
    }
}
