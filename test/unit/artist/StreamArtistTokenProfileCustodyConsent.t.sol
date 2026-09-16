// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./ArtistOnboardingFixture.sol";

interface ArtistTokenProfileCallVm {
    function expectCall(address target, uint256 value, bytes calldata data, uint64 count) external;
}

/// @notice Original scope2 PROFILE consent through the actual Artist Safe, owner and Archive.
/// @dev Token identity and resolver governance remain explicit unit boundaries. No custody payment claim.
contract StreamArtistTokenProfileCustodyConsentTest is ArtistOnboardingFixture {
    ArtistTokenProfileCallVm private constant calls =
        ArtistTokenProfileCallVm(address(uint160(uint256(keccak256("hevm cheat code")))));

    function _setupToken(bool payout) private returns (bytes32 profile) {
        directArtistCalls = true;
        _accept();
        if (payout) _payout();
        core.setTokenCollection(41, 1);
        core.setTokenCollection(42, 1);
        profile = primary.primaryEconomicsFacts(1, 1, 1).profileId;
        require(profile != 0, "actual retained collection PROFILE under typed token identity");
    }

    function _record(T.EconomicsConsent memory p) private view returns (bytes32) {
        T.Binding memory b = coordinator.reads().acceptedBinding(p.collectionId);
        return IStreamArtistEconomicsEvidence(suite.owners[6])
            .economicsRecordForBinding(p, b.artistId, b.generation, b.bindingHash);
    }

    function _install(uint256 token, bytes32 profile) private returns (bytes32) {
        // Keep the original typed governance owner. Artist approval does not itself select rights.
        address owner = primary.owner();
        vm.prank(owner);
        return primary.setPrimaryProfileAssignment(PRIMARY, 2, token, profile, 0);
    }

    function _assertOriginalArchive(
        T.EconomicsConsent memory p,
        T.FixedEconomicsCandidate memory candidate,
        T.Authorization memory a,
        bytes32 record
    ) private view {
        T.Binding memory binding_ = coordinator.reads().acceptedBinding(p.collectionId);
        T.Payout memory payout;
        (payout.account, payout.recordHash) = ingress.artistPayoutAccount(artistId);
        bytes32 expected = StreamArtistEconomicsHashes.economicsRecord(
            StreamArtistHashes.Environment(
                block.chainid, address(ingress), suite.core, suite.mintManager
            ),
            p,
            payout.recordHash,
            artistId,
            address(artist),
            a.nonce,
            uint64(block.timestamp)
        );
        IStreamArtistEconomicsEvidence.Association memory association =
            IStreamArtistEconomicsEvidence(suite.owners[6]).economicsRecordAssociation(record);
        require(
            record == expected && association.artistId == binding_.artistId
                && association.bindingGeneration == binding_.generation
                && association.bindingHash == binding_.bindingHash
                && association.payloadHash == keccak256(abi.encode(p))
                && association.originalRecord == record,
            "exact original op15 record and all retained binding association coordinates"
        );
        bytes32 evidenceId = keccak256(
            abi.encode(
                keccak256("6529STREAM_ARTIST_ONBOARDING_OPERATION_EVIDENCE_V1"),
                block.chainid,
                address(ingress),
                address(coordinator),
                uint16(15),
                address(artist),
                record
            )
        );
        (
            uint16 schema,
            bytes32 config,
            uint16 op,
            address actor,
            bytes32 saved,,,
            bytes memory payload
        ) = abi.decode(
            archive.artistEvidenceBytesV2(evidenceId, 1),
            (uint16, bytes32, uint16, address, bytes32, T.Snapshot[7], T.Snapshot[7], bytes)
        );
        T.AssignmentFact memory fact = primary.previewArtistPrimaryAssignmentForScope(
            p.collectionId, p.scope, p.scopeId, candidate.profileHash, 0, candidate.frozen
        );
        T.SignerApproval memory proof =
            T.SignerApproval(address(artist), ingress.economicsConsentDigest(p, a), true);
        bytes memory evidence = abi.encode(candidate, fact, bytes32(0));
        require(
            schema == 1 && config == coordinator.configurationHash() && op == 15
                && actor == address(artist) && saved == record
                && keccak256(payload)
                    == keccak256(abi.encode(binding_, p, payout, a, proof, evidence, association)),
            "unchanged full original Archive payload and direct threshold-Safe actor"
        );
    }

    function testActualArtistTokenProfileConsentIsExactScopeAndPreservesOp15Archive() public {
        bytes32 profile = _setupToken(true);
        (T.EconomicsConsent memory collection,) = _scopePayload(1, 1, profile, false);
        bytes32 collectionRecord = _scopeRecord(collection);
        (T.EconomicsConsent memory p, T.FixedEconomicsCandidate memory candidate) =
            _scopePayload(2, 41, profile, false);
        require(
            p.assignmentHash != collection.assignmentHash && _record(p) == 0,
            "collection consent does not silently authorize original token assignment"
        );
        address owner = primary.owner();
        vm.expectRevert(
            abi.encodeWithSelector(T.MissingMintPrerequisite.selector, keccak256("economics"))
        );
        vm.prank(owner);
        primary.setPrimaryProfileAssignment(PRIMARY, 2, 41, profile, 0);
        T.Authorization memory a = _authorization(false);
        bytes memory data = abi.encodeCall(
            IStreamArtistEconomicsAuthority.recordProspectiveEconomicsConsent, (p, candidate, a)
        );
        uint256 safeNonce = artist.nonce();
        require(
            this.executeArtistSafe(data) && artist.nonce() == safeNonce + 1,
            "actual threshold Safe records original op15"
        );
        bytes32 record = _record(p);
        _assertOriginalArchive(p, candidate, a, record);
        require(
            !primary.primaryEconomicsFacts(1, 2, 41).exists
                && _record(collection) == collectionRecord,
            "approval preserves original collection consent and leaves token SET separate"
        );
        require(
            _install(41, profile) == p.assignmentHash
                && primary.resolvePrimaryAssignment(1, 41, PRIMARY).assignmentHash
                    == p.assignmentHash,
            "original governance owner installs the exact Artist-approved token PROFILE"
        );
        (T.EconomicsConsent memory other,) = _scopePayload(2, 42, profile, false);
        require(
            other.assignmentHash != p.assignmentHash && _record(other) == 0,
            "same collection does not collapse token identity"
        );
        vm.expectRevert(
            abi.encodeWithSelector(T.MissingMintPrerequisite.selector, keccak256("economics"))
        );
        vm.prank(owner);
        primary.setPrimaryProfileAssignment(PRIMARY, 2, 42, profile, 0);
        bytes32 roots = _roots();
        safeNonce = artist.nonce();
        vm.expectRevert(abi.encodeWithSignature("Error(string)", "GS013"));
        this.executeArtistSafe(data);
        require(
            artist.nonce() == safeNonce && roots == _roots() && _record(p) == record,
            "original consent replay changes neither Safe nonce nor original Archive association"
        );
    }

    function testActualTokenProfileMissingPayoutRetainsIdenticalSignedSafeRetry() public {
        bytes32 profile = _setupToken(false);
        (T.EconomicsConsent memory p, T.FixedEconomicsCandidate memory candidate) =
            _scopePayload(2, 41, profile, false);
        T.Authorization memory a = _authorization(false);
        bytes memory data = abi.encodeCall(
            IStreamArtistEconomicsAuthority.recordProspectiveEconomicsConsent, (p, candidate, a)
        );
        uint256 nonce = artist.nonce();
        bytes32 digest = artist.getTransactionHash(
            address(ingress), 0, data, 0, 0, 0, 0, address(0), address(0), nonce
        );
        bytes memory signedCall = abi.encodeCall(
            artist.execTransaction,
            (
                address(ingress),
                0,
                data,
                0,
                0,
                0,
                0,
                address(0),
                payable(address(0)),
                safeThresholdSignature(keys, digest)
            )
        );
        bytes32 before_ = _roots();
        calls.expectCall(address(ingress), 0, data, uint64(2));
        (bool ok, bytes memory result) = address(artist).call(signedCall);
        require(
            !ok && keccak256(result) == keccak256(abi.encodeWithSignature("Error(string)", "GS013"))
                && artist.nonce() == nonce && _roots() == before_ && _record(p) == 0
                && !IStreamArtistIdentityOwner(suite.owners[2]).nonceUsed(artistId, a.nonce),
            "first exact Safe call reaches missing-payout denial and preserves both replay lanes"
        );
        // Actual relayed Safe-message approval repairs payout without consuming the saved Safe transaction nonce.
        T.PayoutDesignation memory designation = T.PayoutDesignation(artistId, address(artist), 0);
        T.Authorization memory payoutA = _authorization(true);
        payoutA.signature = safeThresholdSignature(
            keys,
            safeMessageDigest(
                artist, abi.encode(ingress.payoutDesignationDigest(designation, payoutA))
            )
        );
        ingress.recordPayoutDesignation(designation, payoutA);
        require(
            artist.nonce() == nonce
                && !IStreamArtistIdentityOwner(suite.owners[2]).nonceUsed(artistId, a.nonce),
            "separate real payout signature preserves exact original Safe transaction and consent nonce"
        );
        (ok, result) = address(artist).call(signedCall);
        require(
            ok && abi.decode(result, (bool)) && artist.nonce() == nonce + 1,
            "identical full signed Safe bytes succeed after original payout repair"
        );
        bytes32 record = _record(p);
        _assertOriginalArchive(p, candidate, a, record);
        require(
            _install(41, profile) == p.assignmentHash
                && primary.resolvePrimaryAssignment(1, 41, PRIMARY).assignmentHash
                    == p.assignmentHash,
            "same approved token PROFILE becomes current through separate owner installation"
        );
    }
}
