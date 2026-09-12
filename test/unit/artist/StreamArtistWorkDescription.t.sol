// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./ArtistOnboardingFixture.sol";

/// @notice Actual artist/estate/metadata/Safe composition; Core and governance remain typed fixtures.
contract StreamArtistWorkDescriptionTest is ArtistOnboardingFixture {
    function testActualWorkDescriptionArtistSafeAndCuratorKeepSeparateProvenance() public {
        ArtistCanonicalPublicationFixture f = _canonicalPublicationHost();
        f.configureWorkDescription(address(this));
        StreamCollectionMetadataV1 host = f.metadata();
        bytes memory payload = bytes("artist-authored work description");
        (IStreamPreservationRecords.CollectionRecord memory r, P.Publication memory pub) = f.prepare(
            address(artist),
            keccak256("WORK_DESCRIPTION"),
            keccak256("STREAM_WORK_DESCRIPTION_V1"),
            payload,
            "ipfs://work-description"
        );
        require(
            pub.candidateRecordHash == _canonicalRecordHash(r, pub),
            "literal original generic record preimage"
        );
        (T.Attestation memory p, bytes memory statement) = _canonicalAttestation(pub, r.uri);
        T.Authorization memory a = _authorization(true);
        a.signature = _signature(ingress.attestationDigest(p, a));
        bytes32 authorization = ingress.recordArtistAttestation(p, a, statement);
        require(
            authorization == _publicationExpected(p, a, 1),
            "unchanged original artist attestation preimage"
        );
        P.Evidence memory proof = ingress.requireRecordPublication(authorization, pub);
        require(
            proof.requiredCapability == 1 && proof.authorityClass == 1 && p.subjectKind == 8
                && p.subjectStateHash == 0,
            "actual principal CAP_ATTEST envelope"
        );
        this.executePublicationSafe(
            address(host),
            abi.encodeCall(
                IStreamCollectionMetadataV1.recordArtistCollectionRecordWithPayload,
                (address(artist), uint256(1), r, payload, authorization)
            )
        );
        (, IStreamCollectionMetadataV1.RecordReceipt memory artistReceipt) =
            host.collectionRecord(pub.candidateRecordHash);
        require(
            artistReceipt.authorizationClass == 1
                && artistReceipt.artistAuthorization == authorization
                && artistReceipt.recorder == address(artist),
            "metadata artist receipt retains actual Safe principal"
        );
        bytes32 curatorHash = host.recordCollectionRecordWithPayload(1, r, payload);
        (, IStreamCollectionMetadataV1.RecordReceipt memory curatorReceipt) =
            host.collectionRecord(curatorHash);
        require(
            curatorHash != pub.candidateRecordHash && curatorReceipt.authorizationClass == 3
                && curatorReceipt.artistAuthorization == 0
                && curatorReceipt.recorder == address(this),
            "curator grant has distinct provenance"
        );
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamCollectionMetadataV1.MetadataAuthorizationConsumed.selector, authorization
            )
        );
        host.recordArtistCollectionRecordWithPayload(address(artist), 1, r, payload, authorization);
    }

    function testActualWorkDescriptionEstateAttestCapabilityPublishesSameSharedType() public {
        ArtistCanonicalPublicationFixture f = _canonicalPublicationHost();
        f.configureWorkDescription(address(this));
        _estateActivateAndAdopt(1);
        bytes memory payload = bytes("successor-authored work description");
        (IStreamPreservationRecords.CollectionRecord memory r, P.Publication memory pub) = f.prepare(
            address(artist),
            keccak256("WORK_DESCRIPTION"),
            keccak256("STREAM_WORK_DESCRIPTION_V1"),
            payload,
            "ipfs://successor-description"
        );
        (T.Attestation memory p, bytes memory statement) = _canonicalAttestation(pub, r.uri);
        T.Authorization memory a = _authorization(true);
        a.signature = _signature(ingress.attestationDigest(p, a));
        bytes32 authorization = ingress.recordArtistAttestation(p, a, statement);
        P.Evidence memory proof = ingress.requireRecordPublication(authorization, pub);
        require(
            proof.requiredCapability == 1 && proof.authorityClass == 3,
            "actual estate successor class differs from curator class3"
        );
        StreamCollectionMetadataV1 host = f.metadata();
        host.recordArtistCollectionRecordWithPayload(address(artist), 1, r, payload, authorization);
        (, IStreamCollectionMetadataV1.RecordReceipt memory receipt) =
            host.collectionRecord(pub.candidateRecordHash);
        require(
            receipt.authorizationClass == 1 && receipt.artistAuthorization == authorization,
            "metadata retains artist branch, detached proof retains successor"
        );
    }

    function testActualWorkDescriptionEstateIntentCapabilityCannotReplaceAttest() public {
        ArtistCanonicalPublicationFixture f = _canonicalPublicationHost();
        f.configureWorkDescription(address(this));
        _estateActivateAndAdopt(64);
        bytes memory payload = bytes("intent capability cannot authorize description");
        (IStreamPreservationRecords.CollectionRecord memory r, P.Publication memory pub) = f.prepare(
            address(artist),
            keccak256("WORK_DESCRIPTION"),
            keccak256("STREAM_WORK_DESCRIPTION_V1"),
            payload,
            "ipfs://wrong-capability"
        );
        (T.Attestation memory p, bytes memory statement) = _canonicalAttestation(pub, r.uri);
        T.Authorization memory a = _authorization(true);
        a.signature = _signature(ingress.attestationDigest(p, a));
        bytes32 roots = _roots();
        vm.expectRevert(
            abi.encodeWithSelector(Estate.EstateCapabilityUnavailable.selector, artistId, uint32(1))
        );
        ingress.recordArtistAttestation(p, a, statement);
        require(_roots() == roots, "rejected description changes no artist owner roots");
        require(
            !f.metadata().consumedArtistAuthorization(_publicationExpected(p, a, 3)),
            "rejected proof unconsumed"
        );
    }
}
