// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../../../smart-contracts/domains/artist/StreamArtistRecordPublicationRules.sol";

interface PublicationEnvelopeVm {
    function expectRevert(bytes calldata reason) external;
}

/// @notice Pure profile proof only; actual owner/nonce/metadata publication are separate tests.
contract StreamArtistRecordPublicationEnvelopeTest {
    PublicationEnvelopeVm private constant vm =
        PublicationEnvelopeVm(address(uint160(uint256(keccak256("hevm cheat code")))));

    function _publication()
        private
        pure
        returns (StreamArtistRecordPublicationTypes.Publication memory p)
    {
        p = StreamArtistRecordPublicationTypes.Publication(
            address(0x123),
            address(0x456),
            1,
            keccak256("collection subject"),
            keccak256("ARTIST_INTENT"),
            keccak256("STREAM_ARTIST_INTENT_V1"),
            keccak256("JCS_RFC8785"),
            1,
            keccak256("actual bytes"),
            keccak256("ipfs://publication"),
            1900000000,
            keccak256("independently derived canonical record")
        );
    }

    function _attestation(
        StreamArtistRecordPublicationTypes.Publication memory publication,
        uint8 kind
    ) private pure returns (T.Attestation memory p, bytes memory statement) {
        statement = abi.encode(uint16(1), publication);
        p = T.Attestation(
            publication.collectionId,
            kind,
            publication.subjectId,
            kind == 7 ? publication.candidateRecordHash : bytes32(0),
            keccak256("6529STREAM_ARTIST_RECORD_PUBLICATION_V1"),
            keccak256(statement),
            "ipfs://publication"
        );
    }

    function testExactStaticEnvelopeIncludesRecorderAndIntentSpecificCapability() public pure {
        StreamArtistRecordPublicationTypes.Publication memory publication = _publication();
        (T.Attestation memory p, bytes memory statement) = _attestation(publication, 7);
        require(statement.length == 416, "version plus twelve exact words");
        bytes memory literal = abi.encode(
            uint16(1),
            address(0x123),
            address(0x456),
            uint256(1),
            keccak256("collection subject"),
            keccak256("ARTIST_INTENT"),
            keccak256("STREAM_ARTIST_INTENT_V1"),
            keccak256("JCS_RFC8785"),
            uint16(1),
            keccak256("actual bytes"),
            keccak256("ipfs://publication"),
            uint64(1900000000),
            keccak256("independently derived canonical record")
        );
        require(keccak256(statement) == keccak256(literal), "independent static preimage");
        (StreamArtistRecordPublicationTypes.Publication memory decoded, uint32 cap) =
            StreamArtistRecordPublicationRules.decode(p, statement);
        require(
            cap == 64 && keccak256(abi.encode(decoded)) == keccak256(abi.encode(publication)),
            "intent64 alone"
        );
    }

    function testFamilySubjectCannotConfuseIntentAndInterviewWithHealthyControl() public {
        StreamArtistRecordPublicationTypes.Publication memory publication = _publication();
        (T.Attestation memory p, bytes memory statement) = _attestation(publication, 8);
        vm.expectRevert(abi.encodeWithSelector(T.InvalidRecord.selector));
        StreamArtistRecordPublicationRules.decode(p, statement);
        publication.recordType = keccak256("ARTIST_STATEMENT");
        publication.schemaId = keccak256("STREAM_ARTIST_INTERVIEW_V1");
        (p, statement) = _attestation(publication, 7);
        vm.expectRevert(abi.encodeWithSelector(T.InvalidRecord.selector));
        StreamArtistRecordPublicationRules.decode(p, statement);
        (p, statement) = _attestation(publication, 8);
        (, uint32 cap) = StreamArtistRecordPublicationRules.decode(p, statement);
        require(
            cap == 1 && p.subjectStateHash == 0,
            "freeform interview with exact envelope, no staleness claim"
        );
    }

    function testRecorderUriAndCanonicalEncodingCannotBeSubstituted() public {
        StreamArtistRecordPublicationTypes.Publication memory publication = _publication();
        (T.Attestation memory p, bytes memory statement) = _attestation(publication, 7);
        publication.recorder = address(0x789);
        bytes memory altered = abi.encode(uint16(1), publication);
        vm.expectRevert(abi.encodeWithSelector(T.InvalidRecord.selector));
        StreamArtistRecordPublicationRules.decode(p, altered);
        p.statementURI = "ipfs://different";
        vm.expectRevert(abi.encodeWithSelector(T.InvalidRecord.selector));
        StreamArtistRecordPublicationRules.decode(p, statement);
        p.statementURI = "ipfs://publication";
        vm.expectRevert(abi.encodeWithSelector(T.InvalidRecord.selector));
        StreamArtistRecordPublicationRules.decode(p, bytes.concat(statement, bytes32(0)));
        (StreamArtistRecordPublicationTypes.Publication memory original,) =
            StreamArtistRecordPublicationRules.decode(p, statement);
        require(original.recorder == address(0x456), "same exact original remains healthy");
    }

    function testSemanticAssertionUsesExactSchemaAndOrdinaryAttestationCapability() public {
        StreamArtistRecordPublicationTypes.Publication memory publication = _publication();
        publication.recordType = keccak256("ARTIST_SEMANTIC_ASSERTION");
        publication.schemaId = keccak256("STREAM_SEMANTIC_ASSERTION_V1");
        (T.Attestation memory p, bytes memory statement) = _attestation(publication, 7);
        vm.expectRevert(abi.encodeWithSelector(T.InvalidRecord.selector));
        StreamArtistRecordPublicationRules.decode(p, statement);
        (p, statement) = _attestation(publication, 8);
        (, uint32 capability) = StreamArtistRecordPublicationRules.decode(p, statement);
        require(capability == 1 && p.subjectStateHash == 0, "subject8 ordinary capability only");
        publication.schemaId = keccak256("STREAM_ARTIST_INTENT_V1");
        (p, statement) = _attestation(publication, 8);
        vm.expectRevert(abi.encodeWithSelector(T.UnsupportedProfile.selector));
        StreamArtistRecordPublicationRules.decode(p, statement);
    }
}
