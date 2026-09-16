// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "./ArtistOnboardingFixture.sol";
import "../../../smart-contracts/domains/artist/StreamArtistAttestationSubjectReads.sol";
import {
    StreamArtistAttestationTypes as Attest
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistAttestationWriter.sol";

/// @dev Explicit owner boundary. These methods never claim real manifest publication or finality execution.
contract ArtistAttestationSubjectOwner {
    address public immutable core;
    address public immutable metadataRouter;
    bytes32 public script;
    bytes32 public media;
    bool public fail;
    StreamSnapshotTypes.Receipt private receipt;

    constructor(address c, address router) {
        core = c;
        metadataRouter = router;
    }

    function configure(bytes32 s, bytes32 m, bool f) external {
        script = s;
        media = m;
        fail = f;
    }

    function scriptManifestHash(uint256) external view returns (bytes32) {
        require(!fail, "owner unavailable");
        return script;
    }

    function mediaManifestHash(uint256) external view returns (bytes32) {
        require(!fail, "owner unavailable");
        return media;
    }

    function setReceipt(StreamSnapshotTypes.Receipt calldata x) external {
        receipt = x;
    }

    function currentSnapshot(uint256) external view returns (StreamSnapshotTypes.Receipt memory) {
        return receipt;
    }

    function latestSnapshotHash(uint256) external view returns (bytes32) {
        return receipt.manifestHash;
    }

    function snapshotHash(uint256, bytes32 id) external view returns (bytes32) {
        return id == receipt.snapshotId ? receipt.manifestHash : bytes32(0);
    }
}

/// @notice Actual Artist owners, threshold Safes, Manager/Resolvers and Archive; typed Core and subject-owner boundaries.
contract StreamArtistSubjectAttestationTest is ArtistOnboardingFixture {
    function _terms(uint8 kind, bytes32 key, bytes32 hash)
        internal
        pure
        returns (T.Attestation memory p, bytes memory statement)
    {
        statement = abi.encode("authored attestation", kind, key, hash);
        p = T.Attestation(
            1,
            kind,
            key,
            hash,
            keccak256("subject test statement schema"),
            keccak256(statement),
            "urn:attestation:subject"
        );
    }

    function _auth(T.Attestation memory p, bool delegate_, uint256 nonce)
        internal
        returns (T.Authorization memory a)
    {
        a = T.Authorization(nonce, uint64(block.timestamp), "");
        bytes32 digest = ingress.attestationDigest(p, a);
        a.signature = delegate_ ? _delegateSignature(digest) : _signature(digest);
    }

    function _expected(
        T.Attestation memory p,
        T.Authorization memory a,
        address signer,
        uint8 class_
    ) internal view returns (bytes32) {
        // Independent literal original 16-word record, not a new domain or helper-produced oracle.
        return keccak256(
            abi.encode(
                keccak256("6529STREAM_ARTIST_ATTESTATION_RECORD_V1"),
                block.chainid,
                address(ingress),
                address(core),
                p.collectionId,
                p.subjectKind,
                p.subjectId,
                p.subjectStateHash,
                p.schemaId,
                p.statementHash,
                keccak256(bytes(p.statementURI)),
                artistId,
                signer,
                class_,
                a.nonce,
                a.time
            )
        );
    }

    function _primaryTerms()
        internal
        view
        returns (T.Attestation memory p, bytes memory statement)
    {
        bytes32 hash =
            primary.resolvePrimaryAssignment(1, 0, keccak256("PRIMARY_SALE")).assignmentHash;
        return _terms(6, bytes32(uint256(uint160(address(primary)))), hash);
    }

    function _signed(T.Attestation memory p, bytes memory statement)
        internal
        returns (bytes32 record)
    {
        T.Authorization memory a = _auth(p, false, nextNonce++);
        record = ingress.recordArtistAttestation(p, a, statement);
        require(record == _expected(p, a, address(artist), 1), "original principal record");
    }

    function _assertAssociation(bytes32 record, bytes32 grant, address owner) internal view {
        Attest.Association memory a = ingress.attestationAssociation(record);
        T.Binding memory b = ingress.displayBinding(1);
        require(
            a.artistId == artistId && a.bindingHash == b.bindingHash && a.generation == b.generation
                && a.delegation == grant && a.fact.owner == owner
                && a.fact.ownerCodeHash == owner.codehash,
            "exact binding/source/grant association"
        );
        require(
            _operationPayload(24, address(this), record).length != 0,
            "actual original Archive op24 evidence"
        );
    }

    function testSubjectActualManagerPhaseAndBothResolverAssignments() public {
        _all();
        require(
            this.executeTargetSafe(address(manager), _configureData()),
            "actual approved phase registration"
        );
        (T.Attestation memory p, bytes memory statement) =
            _terms(5, PHASE, manager.phasePolicyHash(1, PHASE));
        bytes32 record = _signed(p, statement);
        _assertAssociation(record, 0, address(manager));
        (p, statement) = _primaryTerms();
        _assertAssociation(_signed(p, statement), 0, address(primary));
        (T.AssignmentFact memory fact,,) = royalty.resolveRoyaltyAssignment(1, 0);
        (p, statement) = _terms(6, bytes32(uint256(uint160(address(royalty)))), fact.assignmentHash);
        _assertAssociation(_signed(p, statement), 0, address(royalty));
    }

    function testSubjectManifestExactHashesAndAdvertisedOwnerFailure() public {
        _accept();
        ArtistAttestationSubjectOwner owner =
            new ArtistAttestationSubjectOwner(address(core), address(metadata));
        bytes32 script = keccak256("full canonical ScriptManifest owner boundary");
        bytes32 media = keccak256("full canonical MediaManifest owner boundary");
        owner.configure(script, media, false);
        core.set(keccak256("COLLECTION_METADATA"), address(owner), false);
        (T.Attestation memory p, bytes memory statement) = _terms(2, bytes32(uint256(1)), script);
        bytes32 record = _signed(p, statement);
        _assertAssociation(record, 0, address(owner));
        (p, statement) = _terms(3, bytes32(uint256(1)), media);
        T.Authorization memory a = _auth(p, false, nextNonce++);
        bytes32 roots = _roots();
        owner.configure(script, media, true);
        vm.expectRevert(
            abi.encodeWithSelector(
                StreamArtistAttestationSubjectReads.AttestationSubjectRead.selector,
                address(owner),
                IStreamCollectionManifestReads.mediaManifestHash.selector
            )
        );
        ingress.recordArtistAttestation(p, a, statement);
        require(_roots() == roots, "owner failure does not consume signature");
        owner.configure(script, media, false);
        require(
            ingress.recordArtistAttestation(p, a, statement) == _expected(p, a, address(artist), 1),
            "identical signed retry"
        );
        (uint8 status,,,,) = ingress.artistAttestationStatus(
            1, 2, bytes32(uint256(1)), keccak256("replacement manifest")
        );
        require(
            status == 2 && ingress.attestationAuthorityClass(record) == 1,
            "changed manifest is stale without rewriting original record"
        );
    }

    function testSubjectSnapshotUsesOriginalPinnedHostAndManifestNotReceiptHash() public {
        _accept();
        ArtistAttestationSubjectOwner owner =
            new ArtistAttestationSubjectOwner(address(core), address(metadata));
        StreamSnapshotTypes.Receipt memory receipt;
        receipt.recordHash = keccak256("original snapshot receipt");
        receipt.collectionId = 1;
        receipt.snapshotId = keccak256("original snapshot ID");
        receipt.revision = 1;
        receipt.manifestHash = keccak256("actual complete snapshot manifest");
        owner.setReceipt(receipt);
        address finality = ingress.finalityRegistry();
        address provider = IStreamFinalityDeploymentBindings(finality).scopeEvidenceProvider();
        StreamFinalityNativeProviderReads.Config memory c;
        c.chainId = block.chainid;
        c.targets[0] = address(core);
        c.targets[2] = address(metadata);
        c.targets[8] = address(owner);
        c.codeHashes[8] = address(owner).codehash;
        c.targets[11] = address(ingress);
        c.targets[12] = finality;
        avm.mockCall(
            provider,
            abi.encodeCall(IStreamFinalityDiscoverySources.snapshotHost, ()),
            abi.encode(address(owner))
        );
        avm.mockCall(
            provider,
            abi.encodeCall(IStreamArtistSnapshotConfiguration.nativeConfiguration, ()),
            abi.encode(c)
        );
        (T.Attestation memory p, bytes memory statement) =
            _terms(1, receipt.snapshotId, receipt.recordHash);
        T.Authorization memory a = _auth(p, false, nextNonce++);
        bytes32 roots = _roots();
        avm.expectRevert(T.InvalidRecord.selector);
        ingress.recordArtistAttestation(p, a, statement);
        require(_roots() == roots, "receipt record is not snapshot manifest");
        (p, statement) = _terms(1, receipt.snapshotId, receipt.manifestHash);
        a = _auth(p, false, nextNonce++);
        c.codeHashes[8] = keccak256("foreign runtime");
        avm.mockCall(
            provider,
            abi.encodeCall(IStreamArtistSnapshotConfiguration.nativeConfiguration, ()),
            abi.encode(c)
        );
        vm.expectRevert(abi.encodeWithSelector(T.ComponentChanged.selector, address(owner)));
        ingress.recordArtistAttestation(p, a, statement);
        c.codeHashes[8] = address(owner).codehash;
        avm.mockCall(
            provider,
            abi.encodeCall(IStreamArtistSnapshotConfiguration.nativeConfiguration, ()),
            abi.encode(c)
        );
        bytes32 record = ingress.recordArtistAttestation(p, a, statement);
        _assertAssociation(record, 0, address(owner));
        avm.clearMockedCalls();
    }

    function testSubjectExecutedFinalityCollectionAndExactScopedKey() public {
        _accept();
        address f = ingress.finalityRegistry();
        StreamCollectionFinalityRecord memory collection;
        collection.finalityRecordHash = keccak256("typed executed collection record");
        collection.finalizedAt = uint64(block.timestamp);
        (T.Attestation memory p, bytes memory statement) =
            _terms(4, bytes32(uint256(1)), collection.finalityRecordHash);
        T.Authorization memory a = _auth(p, false, nextNonce++);
        avm.mockCall(
            f,
            abi.encodeCall(IStreamArtworkFinalityRegistry.collectionFinalityRecord, (1)),
            abi.encode(collection)
        );
        avm.expectRevert(T.InvalidRecord.selector);
        ingress.recordArtistAttestation(p, a, statement);
        collection.finalized = true;
        avm.mockCall(
            f,
            abi.encodeCall(IStreamArtworkFinalityRegistry.collectionFinalityRecord, (1)),
            abi.encode(collection)
        );
        _assertAssociation(ingress.recordArtistAttestation(p, a, statement), 0, f);
        StreamFinalityScope memory scope =
            StreamFinalityScope(StreamFinalityScopeType.TOKEN, 1, 41, 0);
        StreamScopedFinalityRecord memory token;
        token.finalized = true;
        token.scope = scope;
        token.finalityRecordHash = keccak256("typed executed token41 record");
        token.finalizedAt = uint64(block.timestamp);
        avm.mockCall(
            f,
            abi.encodeCall(IStreamArtworkFinalityRegistry.artworkScopeFinalityRecord, (scope)),
            abi.encode(token)
        );
        bytes32 key = keccak256(
            abi.encode(keccak256("6529STREAM_ARTIST_FINALITY_ATTESTATION_SUBJECT_V1"), scope)
        );
        (p, statement) = _terms(4, key, token.finalityRecordHash);
        a = _auth(p, false, nextNonce++);
        Attest.Subject memory q = Attest.Subject(1, 41, 0, address(0));
        bytes32 record = ingress.recordArtistScopedAttestation(p, q, a, statement);
        require(
            record == _expected(p, a, address(artist), 1),
            "scope locator does not change signed record domain"
        );
        _assertAssociation(record, 0, f);
        avm.clearMockedCalls();
    }

    function testSubjectActualScopedEconomicsRejectsCollectionApprovalForToken() public {
        _accept();
        core.setTokenCollection(41, 1);
        // Existing actual per-key collection assignment; descriptor must match the signed key.
        IStreamRevenueResolver.ResolvedPrimaryAssignment memory fact =
            primary.primaryEconomicsFacts(1, 1, 1);
        bytes32 key = keccak256(
            abi.encode(
                keccak256("6529STREAM_ARTIST_ECONOMICS_ATTESTATION_SUBJECT_V1"),
                uint256(1),
                address(primary),
                keccak256("PRIMARY_SALE"),
                uint8(1),
                uint256(1)
            )
        );
        (T.Attestation memory p, bytes memory statement) = _terms(6, key, fact.assignmentHash);
        T.Authorization memory a = _auth(p, false, nextNonce++);
        Attest.Subject memory q = Attest.Subject(1, 0, bytes32(uint256(1)), address(primary));
        bytes32 record = ingress.recordArtistScopedAttestation(p, q, a, statement);
        _assertAssociation(record, 0, address(primary));
        q.scopeType = 2;
        q.scopeId = bytes32(uint256(41));
        bytes32 roots = _roots();
        avm.expectRevert(T.InvalidRecord.selector);
        ingress.recordArtistScopedAttestation(p, q, a, statement);
        require(_roots() == roots, "collection signed hash is not an invented token approval");
    }

    function testSubjectDelegatedSafeOriginalClassNonceGrantAndArchive() public {
        _accept();
        _delegateSetup();
        bytes32 grant = _grant(_delegation(1, 1, 1000, 2000, 2));
        T.Identity memory before_ = IStreamArtistIdentityOwner(suite.owners[2]).identity(artistId);
        (T.Attestation memory p, bytes memory statement) = _primaryTerms();
        T.Authorization memory a = _auth(p, true, 0);
        vm.recordLogs();
        bytes32 record = ingress.recordDelegatedArtistAttestation(p, grant, a, statement);
        Vm.Log[] memory logs = vm.getRecordedLogs();
        uint256 n;
        bytes32 topic =
            keccak256("ArtistAttestationDelegation(uint16,bytes32,bytes32,bytes32,address)");
        for (uint256 i; i < logs.length; ++i) {
            if (
                logs[i].emitter == suite.owners[4] && logs[i].topics.length != 0
                    && logs[i].topics[0] == topic
            ) {
                ++n;
                require(
                    logs[i].topics.length == 4 && logs[i].topics[1] == record
                        && logs[i].topics[2] == grant && logs[i].topics[3] == artistId
                        && keccak256(logs[i].data)
                            == keccak256(abi.encode(uint16(1), address(delegateSafe))),
                    "exact grant event"
                );
            }
        }
        require(
            n == 1 && record == _expected(p, a, address(delegateSafe), 2),
            "original class2 hash and one event"
        );
        _assertAssociation(record, grant, address(primary));
        require(
            ingress.recordDelegation(record) == grant
                && ingress.attestationAuthorityClass(record) == 2
                && ingress.delegationRecord(grant).uses == 1,
            "canonical saved grant/class/use"
        );
        T.Identity memory after_ = IStreamArtistIdentityOwner(suite.owners[2]).identity(artistId);
        require(
            before_.nonceHint == after_.nonceHint
                && before_.lastAuthorityActionAt == after_.lastAuthorityActionAt,
            "delegate does not claim principal liveness or nonce"
        );
        (bool used, uint256 hint) = ingress.delegatedNonceState(artistId, address(delegateSafe), 0);
        require(used && hint == 1, "delegate lane");
        bytes32 roots = _roots();
        avm.expectPartialRevert(T.Replay.selector);
        ingress.recordDelegatedArtistAttestation(p, grant, a, statement);
        require(
            _roots() == roots && ingress.delegationRecord(grant).uses == 1,
            "replay cannot consume another use"
        );
    }

    function testSubjectDelegatedScopeCapabilityAndRevocationPreserveUnusedSignature() public {
        _accept();
        _delegateSetup();
        bytes32 wrongScope = _grant(_delegation(2, 1, 1000, 2000, 0));
        (T.Attestation memory p, bytes memory statement) = _primaryTerms();
        T.Authorization memory a = _auth(p, true, 0);
        vm.expectRevert(abi.encodeWithSelector(D.DelegationScope.selector, wrongScope));
        ingress.recordDelegatedArtistAttestation(p, wrongScope, a, statement);
        _revoke(wrongScope);
        bytes32 wrongCap = _grant(_delegation(1, 32, 1000, 2000, 0));
        vm.expectRevert(
            abi.encodeWithSelector(D.DelegationCapability.selector, wrongCap, uint32(1))
        );
        ingress.recordDelegatedArtistAttestation(p, wrongCap, a, statement);
        _revoke(wrongCap);
        bytes32 correct = _grant(_delegation(1, 1, 1000, 2000, 1));
        bytes32 record = ingress.recordDelegatedArtistAttestation(p, correct, a, statement);
        require(
            record == _expected(p, a, address(delegateSafe), 2),
            "same unused signature survives refused scope/cap grants"
        );
        a = _auth(p, true, 1);
        vm.expectRevert(abi.encodeWithSelector(D.DelegationUnavailable.selector, correct));
        ingress.recordDelegatedArtistAttestation(p, correct, a, statement);
        _revoke(correct);
        require(
            ingress.recordDelegation(record) == correct
                && ingress.attestationAuthorityClass(record) == 2,
            "revocation preserves historical class2 evidence"
        );
    }

    function testSubjectDelegatedLateArchiveFailureRollsBackAllOwnersAndSameSignedRetry() public {
        _accept();
        _delegateSetup();
        bytes32 grant = _grant(_delegation(1, 1, 1000, 2000, 1));
        (T.Attestation memory p, bytes memory statement) = _primaryTerms();
        T.Authorization memory a = _auth(p, true, 0);
        bytes32 expected = _expected(p, a, address(delegateSafe), 2);
        bytes32 roots = _roots();
        uint256 at = block.number;
        vm.roll(uint256(type(uint64).max) + 1);
        vm.expectRevert(
            abi.encodeWithSignature(
                "ArtistArchiveBlockNumberOverflow(uint256)", uint256(type(uint64).max) + 1
            )
        );
        ingress.recordDelegatedArtistAttestation(p, grant, a, statement);
        (bool used,) = ingress.delegatedNonceState(artistId, address(delegateSafe), 0);
        require(
            _roots() == roots && !used && ingress.delegationRecord(grant).uses == 0
                && ingress.attestationAuthorityClass(expected) == 0
                && ingress.attestationAssociation(expected).artistId == 0,
            "all authority/use/class/association rolled back"
        );
        vm.roll(at);
        require(
            ingress.recordDelegatedArtistAttestation(p, grant, a, statement) == expected,
            "byte-identical signed retry"
        );
    }

    function testSubjectDelegatedIntentPublicationHasExactUseAndStopsAfterRevocation() public {
        ArtistPublicationHostFixture host = _publicationHost();
        _delegateSetup();
        bytes32 grant = _grant(_delegation(1, 64, 1000, 2000, 1));
        (P.Publication memory pub, T.Attestation memory p,) = _publicationTerms(host, true);
        pub.recorder = address(delegateSafe);
        pub.candidateRecordHash = host.candidateHash(pub);
        bytes memory statement = abi.encode(uint16(1), pub);
        p.subjectStateHash = pub.candidateRecordHash;
        p.statementHash = keccak256(statement);
        T.Authorization memory a = _auth(p, true, 0);
        bytes32 record = ingress.recordDelegatedArtistAttestation(p, grant, a, statement);
        P.Evidence memory e = ingress.requireRecordPublication(record, pub);
        require(
            e.signer == address(delegateSafe) && e.authorityClass == 2
                && e.requiredCapability == 64,
            "actual recorded delegate intent proof"
        );
        require(
            ingress.delegationRecord(grant).uses == 1,
            "proof completion does not consume a second use"
        );
        _revoke(grant);
        avm.expectRevert(T.InvalidRecord.selector);
        ingress.requireRecordPublication(record, pub);
        require(
            ingress.attestationAuthorityClass(record) == 2,
            "revoking future publication cannot erase history"
        );
    }

    function testSubjectDelegatedDeploymentAndIdentityPreserveActualMintPrerequisites() public {
        _all();
        (bytes32 living,,) = ingress.deploymentAttestation(1);
        _delegateSetup();
        bytes32 grant = _grant(_delegation(1, 1, 1000, 2000, 2));
        T.Binding memory b = ingress.displayBinding(1);
        bytes32 facts = StreamArtistHashes.deploymentFacts(
            StreamArtistHashes.Environment(
                block.chainid, address(ingress), suite.core, suite.mintManager
            ),
            1,
            b
        );
        (T.Attestation memory p, bytes memory statement) =
            _terms(9, bytes32(uint256(uint160(address(core)))), facts);
        p.schemaId = keccak256("6529STREAM_ARTIST_DEPLOYMENT_ATTESTATION_V1");
        T.Authorization memory a = _auth(p, true, 0);
        bytes memory original = a.signature;
        a.signature = new bytes(65);
        avm.expectRevert(T.InvalidSignature.selector);
        ingress.recordDelegatedArtistAttestation(p, grant, a, statement);
        a.signature = original;
        bytes32 deployment = ingress.recordDelegatedArtistAttestation(p, grant, a, statement);
        (p, statement) = _terms(10, artistId, ingress.operativeIdentityRecord(artistId));
        p.schemaId = keccak256("6529STREAM_ARTIST_PERSONHOOD_WAIVER_V1");
        a = _auth(p, true, 1);
        bytes32 identity = ingress.recordDelegatedArtistAttestation(p, grant, a, statement);
        require(
            ingress.attestationAuthorityClass(living) == 1
                && ingress.attestationAuthorityClass(deployment) == 2
                && ingress.attestationAuthorityClass(identity) == 2
                && ingress.recordDelegation(identity) == grant,
            "original principal and delegated historical classes stay distinct"
        );
        ingress.requireMintConsent(1, PHASE, POLICY);
        _revoke(grant);
        ingress.requireMintConsent(1, PHASE, POLICY);
        require(
            ingress.attestationAuthorityClass(identity) == 2,
            "revocation does not erase completed original authorizations"
        );
    }

    function testSubjectDirectDelegateSafeUsesOriginalHintAndNormalizedTime() public {
        _accept();
        _delegateSetup();
        bytes32 grant = _grant(_delegation(1, 1, 1000, 2000, 1));
        (T.Attestation memory p, bytes memory statement) = _primaryTerms();
        T.Authorization memory submitted = T.Authorization(0, 0, "");
        require(
            this.executeDelegate(
                address(ingress),
                abi.encodeCall(
                    IStreamArtistAttestationWriter.recordDelegatedArtistAttestation,
                    (p, grant, submitted, statement)
                )
            ),
            "actual threshold Safe direct delegate"
        );
        T.Authorization memory effective = T.Authorization(0, uint64(block.timestamp), "");
        bytes32 record = _expected(p, effective, address(delegateSafe), 2);
        require(
            ingress.attestationAuthorityClass(record) == 2
                && ingress.recordDelegation(record) == grant,
            "original class2/time record"
        );
        require(
            _operationPayload(24, address(delegateSafe), record).length != 0,
            "actual direct actor archived"
        );
        (bool used, uint256 hint) = ingress.delegatedNonceState(artistId, address(delegateSafe), 0);
        require(used && hint == 1, "direct original nonce hint consumed");
    }

    function testSubjectDelegatedForbiddenDirectiveAndExpiryDoNotRewriteHistory() public {
        _accept();
        _delegateSetup();
        bytes32 grant = _grant(_delegation(1, 1, 1000, 2000, 0));
        (T.Attestation memory p, bytes memory statement) = _primaryTerms();
        T.Authorization memory a = _auth(p, true, 0);
        bytes32 directive = _directiveRecord(1);
        bytes32 roots = _roots();
        vm.expectRevert(
            abi.encodeWithSelector(
                Succ.ForbiddenCapability.selector, artistId, uint32(1), directive
            )
        );
        ingress.recordDelegatedArtistAttestation(p, grant, a, statement);
        require(
            _roots() == roots && ingress.delegationRecord(grant).uses == 0,
            "absolute directive precedes grant use"
        );
        _directiveRecord(0);
        bytes32 record = ingress.recordDelegatedArtistAttestation(p, grant, a, statement);
        require(
            record == _expected(p, a, address(delegateSafe), 2),
            "same signed request after actual Artist directive replacement"
        );
        a = _auth(p, true, 1);
        vm.warp(2000);
        vm.expectRevert(abi.encodeWithSelector(D.DelegationUnavailable.selector, grant));
        ingress.recordDelegatedArtistAttestation(p, grant, a, statement);
        require(
            ingress.attestationAuthorityClass(record) == 2
                && ingress.delegationRecord(grant).uses == 1,
            "expiry does not erase original attestation"
        );
    }

    function testSubjectManifestMalformedReturnCannotFallBackToRawFamily() public {
        _accept();
        ArtistAttestationSubjectOwner owner =
            new ArtistAttestationSubjectOwner(address(core), address(metadata));
        bytes32 hash = keccak256("actual named manifest hash");
        owner.configure(hash, hash, false);
        core.set(keccak256("COLLECTION_METADATA"), address(owner), false);
        (T.Attestation memory p, bytes memory statement) = _terms(2, bytes32(uint256(1)), hash);
        T.Authorization memory a = _auth(p, false, nextNonce++);
        avm.mockCall(
            address(owner),
            abi.encodeCall(IStreamCollectionManifestReads.scriptManifestHash, (1)),
            abi.encode(hash, hash)
        );
        vm.expectRevert(
            abi.encodeWithSelector(
                StreamArtistAttestationSubjectReads.AttestationSubjectRead.selector,
                address(owner),
                IStreamCollectionManifestReads.scriptManifestHash.selector
            )
        );
        ingress.recordArtistAttestation(p, a, statement);
        avm.clearMockedCalls();
        require(
            ingress.recordArtistAttestation(p, a, statement) == _expected(p, a, address(artist), 1),
            "same signed request after exact owner return restored"
        );
    }

    function testSubjectNewOwnerAndCoordinatorEntriesRejectDirectCalls() public {
        _accept();
        (T.Attestation memory p, bytes memory statement) = _primaryTerms();
        T.Authorization memory a = _auth(p, false, nextNonce++);
        Attest.Admission memory admission;
        Attest.Subject memory q;
        T.Binding memory b = ingress.displayBinding(1);
        T.Snapshot memory snapshot = IStreamArtistOwner(suite.owners[4]).ownerStateSnapshotV2();
        avm.expectPartialRevert(T.Unauthorized.selector);
        IStreamArtistAuthenticatedAttestationOwner(suite.owners[4])
            .recordAuthenticatedAttestation(
                T.ActionContext(24, address(this), snapshot), b, p, admission, statement
            );
        avm.expectPartialRevert(T.Unauthorized.selector);
        IStreamArtistAttestationCoordinator(address(coordinator))
            .coordinateSubjectAttestation(address(artist), p, q, false, 0, a, statement);
        bytes32 record = ingress.recordArtistAttestation(p, a, statement);
        require(record == _expected(p, a, address(artist), 1), "authorized route remains usable");
    }
}
