// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./ArtistOnboardingFixture.sol";
import "../../../smart-contracts/interfaces/stream/artist/IStreamArtistContentHostEvidence.sol";

/// @dev Typed selected entropy host only. Configuration application and governance are not modeled.
contract ArtistEntropyConfigurationHostBoundary {
    address public core;

    constructor(address core_) {
        core = core_;
    }

    function setCore(address core_) external {
        core = core_;
    }

    function artistContentFamilyState(uint256 collectionId, bytes32 family)
        external
        view
        returns (bool, bytes32)
    {
        // Deliberately advertises every family: Artist must enforce its own narrow allowlist.
        return (
            true,
            keccak256(
                abi.encode(
                    keccak256("typed entropy configuration current state"),
                    block.chainid,
                    address(this),
                    core,
                    collectionId,
                    family
                )
            )
        );
    }
}

/// @notice Actual Artist facade, seven owners, Archive and threshold Safe; typed Core/entropy.
contract StreamArtistEntropyConfigurationConsentTest is ArtistOnboardingFixture {
    bytes32 private constant CONFIGURATION = keccak256("6529STREAM_ENTROPY_CONFIGURATION_V1");
    bytes32 private constant RECOVERY = keccak256("6529STREAM_ENTROPY_RECOVERY_V1");
    bytes32 private constant ENTROPY_POINTER = keccak256("ENTROPY_COORDINATOR");

    function _configurationHost() private returns (ArtistEntropyConfigurationHostBoundary host) {
        _accept();
        host = new ArtistEntropyConfigurationHostBoundary(address(core));
        core.set(ENTROPY_POINTER, address(host), false);
    }

    function _configurationProposal(address host, bytes32 family)
        private
        view
        returns (Content.Consent memory)
    {
        // A typed boundary commitment, not the production entropy configuration hash recipe.
        return Content.Consent(
            1,
            host,
            family,
            keccak256(
                abi.encode(
                    keccak256("typed resulting collection entropy state"),
                    block.chainid,
                    address(core),
                    host,
                    uint256(1),
                    family
                )
            )
        );
    }

    function _configurationAuthorization(Content.Consent memory p)
        private
        returns (T.Authorization memory a)
    {
        a = _authorization(false);
        a.signature = _signature(ingress.contentConsentDigest(p, a));
    }

    function _configurationEvidence(Content.Consent memory p) private view returns (bytes32) {
        return IStreamArtistContentHostEvidence(address(ingress))
            .contentConsentEvidenceForHost(
                p.collectionId, p.metadataContract, p.familyId, p.newStateHash
            );
    }

    function _configurationRoots() private view returns (bytes32) {
        T.Snapshot[7] memory roots;
        for (uint256 i; i < 7; ++i) {
            roots[i] = IStreamArtistOwner(suite.owners[i]).ownerStateSnapshotV2();
        }
        return keccak256(abi.encode(roots));
    }

    function _configurationRecord(Content.Consent memory p, T.Authorization memory a)
        private
        view
        returns (bytes32)
    {
        return keccak256(
            abi.encode(
                keccak256("6529STREAM_ARTIST_CONTENT_CONSENT_RECORD_V1"),
                block.chainid,
                address(ingress),
                p.metadataContract,
                address(core),
                p.collectionId,
                p.familyId,
                p.newStateHash,
                artistId,
                address(artist),
                uint8(1),
                a.nonce,
                uint64(block.timestamp)
            )
        );
    }

    function testConfigurationUsesOriginalOp17DigestRecordAndArchive() external {
        ArtistEntropyConfigurationHostBoundary host = _configurationHost();
        Content.Consent memory p = _configurationProposal(address(host), CONFIGURATION);
        T.Authorization memory a = _configurationAuthorization(p);
        bytes32 domain = keccak256(
            abi.encode(
                keccak256(
                    "EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"
                ),
                keccak256("6529StreamArtistRegistry"),
                keccak256("1"),
                block.chainid,
                address(ingress)
            )
        );
        bytes32 structHash = keccak256(
            abi.encode(
                keccak256(
                    "StreamArtistContentConsent(address core,address metadataContract,uint256 collectionId,bytes32 familyId,bytes32 newStateHash,uint256 nonce,uint64 deadline)"
                ),
                address(core),
                address(host),
                p.collectionId,
                CONFIGURATION,
                p.newStateHash,
                a.nonce,
                a.time
            )
        );
        bytes32 digest = keccak256(abi.encodePacked(hex"1901", domain, structHash));
        require(ingress.contentConsentDigest(p, a) == digest, "unchanged literal op17 digest");
        bytes32 expected = _configurationRecord(p, a);
        bytes32 record = ingress.recordContentConsent(p, a);
        require(
            record == expected && _configurationEvidence(p) == record, "original record evidence"
        );
        IStreamArtistContentRecordsOwner.ConsentRecord memory stored =
            IStreamArtistContentRecordsOwner(suite.owners[6]).contentConsentRecord(record);
        T.Binding memory binding = IStreamArtistBindingOwner(suite.owners[0]).binding(1);
        require(
            stored.recordHash == record && stored.artistId == artistId
                && stored.bindingGeneration == binding.generation && stored.authorityClass == 1
                && keccak256(abi.encode(stored.terms)) == keccak256(abi.encode(p)),
            "original immutable consent owner record"
        );
        (
            T.Binding memory archivedBinding,
            Content.Consent memory archived,
            T.Authorization memory saved,
            T.SignerApproval memory proof,
            bytes32 current
        ) = abi.decode(
            _operationPayload(17, address(this), record),
            (T.Binding, Content.Consent, T.Authorization, T.SignerApproval, bytes32)
        );
        (, bytes32 expectedCurrent) = host.artistContentFamilyState(1, CONFIGURATION);
        require(
            keccak256(abi.encode(archivedBinding)) == keccak256(abi.encode(binding))
                && keccak256(abi.encode(archived)) == keccak256(abi.encode(p))
                && keccak256(abi.encode(saved)) == keccak256(abi.encode(a))
                && proof.signer == address(artist) && proof.digest == digest && !proof.direct
                && current == expectedCurrent,
            "original Archive payload binds actual selected host read"
        );
    }

    function testConfigurationWrongHostAndCorePreserveExactSignedRetry() external {
        ArtistEntropyConfigurationHostBoundary host = _configurationHost();
        ArtistEntropyConfigurationHostBoundary other =
            new ArtistEntropyConfigurationHostBoundary(address(core));
        Content.Consent memory p = _configurationProposal(address(host), CONFIGURATION);
        T.Authorization memory a = _configurationAuthorization(p);
        bytes32 before_ = _configurationRoots();
        uint256 payloads = archive.storedPayloadCount();
        core.set(ENTROPY_POINTER, address(other), false);
        vm.expectRevert(abi.encodeWithSelector(T.ComponentChanged.selector, address(other)));
        ingress.recordContentConsent(p, a);
        core.set(ENTROPY_POINTER, address(host), false);
        host.setCore(address(0xBAD));
        vm.expectRevert(abi.encodeWithSelector(T.ComponentChanged.selector, address(host)));
        ingress.recordContentConsent(p, a);
        require(
            _configurationRoots() == before_ && archive.storedPayloadCount() == payloads,
            "rejected host consumes no Artist authority or Archive state"
        );
        host.setCore(address(core));
        bytes32 record = ingress.recordContentConsent(p, a);
        core.set(ENTROPY_POINTER, address(other), false);
        vm.expectRevert(abi.encodeWithSelector(T.ComponentChanged.selector, address(other)));
        IStreamArtistContentHostEvidence(address(ingress))
            .contentConsentEvidenceForHost(1, address(host), CONFIGURATION, p.newStateHash);
        core.set(ENTROPY_POINTER, address(host), false);
        require(
            _configurationEvidence(p) == record, "same signed record after original pin restoration"
        );
    }

    function testConfigurationUnknownFamilyAndChangedTargetCannotConsumeSignature() external {
        ArtistEntropyConfigurationHostBoundary host = _configurationHost();
        Content.Consent memory p = _configurationProposal(address(host), CONFIGURATION);
        T.Authorization memory a = _configurationAuthorization(p);
        bytes32 before_ = _configurationRoots();
        Content.Consent memory unknown = _configurationProposal(address(host), keccak256("UNKNOWN"));
        vm.expectRevert(abi.encodeWithSelector(T.ComponentChanged.selector, address(host)));
        ingress.recordContentConsent(unknown, a);
        Content.Consent memory altered = _configurationProposal(address(host), CONFIGURATION);
        altered.newStateHash = keccak256("different configuration");
        avm.expectRevert(T.InvalidSignature.selector);
        ingress.recordContentConsent(altered, a);
        require(
            _configurationRoots() == before_,
            "unknown family and changed state cannot consume nonce"
        );
        bytes32 record = ingress.recordContentConsent(p, a);
        vm.expectRevert(
            abi.encodeWithSelector(T.MissingMintPrerequisite.selector, keccak256("content-consent"))
        );
        IStreamArtistContentHostEvidence(address(ingress))
            .contentConsentEvidenceForHost(1, address(host), CONFIGURATION, altered.newStateHash);
        require(_configurationEvidence(p) == record, "only original signed target has evidence");
    }

    function testConfigurationActualSafeRollbackThenExactConsentRetry() external {
        ArtistEntropyConfigurationHostBoundary host = _configurationHost();
        Content.Consent memory p = _configurationProposal(address(host), CONFIGURATION);
        T.Authorization memory a = _authorization(false);
        bytes memory data =
            abi.encodeCall(IStreamArtistContentAuthority.recordContentConsent, (p, a));
        bytes32 expected = _configurationRecord(p, a);
        bytes32 before_ = _configurationRoots();
        uint256 nonce = artist.nonce();
        uint256 payloads = archive.storedPayloadCount();
        host.setCore(address(0xBAD));
        vm.expectRevert(bytes("GS013"));
        this.executeTargetSafe(address(ingress), data);
        require(
            _configurationRoots() == before_ && artist.nonce() == nonce
                && archive.storedPayloadCount() == payloads
                && IStreamArtistContentRecordsOwner(suite.owners[6])
                .contentConsentRecord(expected)
                .recordHash == 0,
            "actual Safe and all Artist owners roll back"
        );
        host.setCore(address(core));
        require(this.executeTargetSafe(address(ingress), data), "exact direct Safe consent retry");
        require(
            _configurationEvidence(p) == expected && artist.nonce() == nonce + 1
                && archive.storedPayloadCount() > payloads,
            "one original op17 after restoration"
        );
        before_ = _configurationRoots();
        vm.expectRevert(bytes("GS013"));
        this.executeTargetSafe(address(ingress), data);
        require(
            _configurationRoots() == before_ && artist.nonce() == nonce + 1, "nonce replay denied"
        );
    }

    function testConfigurationRecoveryAndMetadataKeepSeparateOriginalEvidence() external {
        ArtistEntropyConfigurationHostBoundary host = _configurationHost();
        Content.Consent memory configuration = _configurationProposal(address(host), CONFIGURATION);
        Content.Consent memory recovery = _configurationProposal(address(host), RECOVERY);
        bytes32 configurationRecord =
            ingress.recordContentConsent(configuration, _configurationAuthorization(configuration));
        vm.expectRevert(
            abi.encodeWithSelector(T.MissingMintPrerequisite.selector, keccak256("content-consent"))
        );
        IStreamArtistContentHostEvidence(address(ingress))
            .contentConsentEvidenceForHost(1, address(host), RECOVERY, recovery.newStateHash);
        T.Authorization memory a = _configurationAuthorization(recovery);
        bytes32 recoveryRecord = ingress.recordContentConsent(recovery, a);
        require(
            recoveryRecord == _configurationRecord(recovery, a)
                && recoveryRecord != configurationRecord
                && _configurationEvidence(configuration) == configurationRecord
                && _configurationEvidence(recovery) == recoveryRecord,
            "old recovery admission and distinct original family records"
        );
        avm.expectRevert(T.UnsupportedProfile.selector);
        ingress.contentConsentEvidence(1, CONFIGURATION, configuration.newStateHash);
        bytes32 metadataState = keccak256("unchanged metadata content");
        bytes32 metadataRecord = _contentConsent(metadataState);
        Content.Consent memory metadata = _contentProposal(metadataState);
        require(
            ingress.contentConsentEvidence(1, metadata.familyId, metadataState) == metadataRecord
                && _configurationEvidence(metadata) == metadataRecord,
            "original metadata-only evidence remains separate"
        );
    }
}
