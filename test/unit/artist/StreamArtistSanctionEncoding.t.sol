// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../../../smart-contracts/domains/artist/StreamArtistSanctionHashes.sol";
import "../../../smart-contracts/domains/artist/StreamArtistSanctionCeremony.sol";

interface SanctionEncodingVm {
    function expectRevert(bytes4 reason) external;
}

/// @notice Independent permanent word preimages and exact canonical/archival bytes.
/// @dev No live authority or archival admission is inferred from these stateless encoding tests.
contract StreamArtistSanctionEncodingTest {
    SanctionEncodingVm private constant vm =
        SanctionEncodingVm(address(uint160(uint256(keccak256("hevm cheat code")))));

    function _subject() private pure returns (S.Subject memory p) {
        p.domain = 0x47c9894872096248b3971f1551b555619aea8b63903f526c2da354a7286bb473;
        p.chainId = 1;
        p.core = address(0x202);
        p.finalityRegistry = address(0x303);
        p.scopeType = 1;
        p.collectionId = 7;
        p.tokenId = 1 << 200;
        p.coreFactsHash = bytes32(uint256(11));
        p.nonSanctionComponentsHash = bytes32(uint256(12));
        p.manifestURIHash = bytes32(uint256(13));
        p.manifestContentHash = bytes32(uint256(14));
        p.manifestSchemaId = bytes32(uint256(15));
        p.manifestCanonicalizationHash = bytes32(uint256(16));
    }

    function _ceremony() private pure returns (S.Ceremony memory c) {
        c.contentRoot = bytes32(uint256(31));
        c.mediaHashes = new bytes32[](1);
        c.mediaHashes[0] = bytes32(uint256(32));
        c.referenceRenderHashes = new bytes32[](1);
        c.referenceRenderHashes[0] = bytes32(uint256(33));
        c.statement =
            string(hex"49207265766965776564202274686973222e0a4c696e655c74776f090020c3a920f09f9880");
        c.signingToolName = "Example Tool";
        c.signingToolVersion = "1.0";
    }

    function _environment() private pure returns (StreamArtistHashes.Environment memory) {
        return StreamArtistHashes.Environment(1, address(0x101), address(0x202), address(0x404));
    }

    function _record() private pure returns (S.Record memory r) {
        S.Subject memory p = _subject();
        r.artistId = bytes32(uint256(41));
        r.signer = address(0x505);
        r.authorityClass = 3;
        r.terms = S.Terms(1, 7, 1 << 200, 0, _flatSubject(p), 0);
        r.nonce = 45;
        r.signedAt = 1000;
        r.deadline = 2000;
        r.bindingGeneration = 2;
        r.bindingHash = bytes32(uint256(46));
    }

    function _flatSubject(S.Subject memory p) private pure returns (bytes32) {
        bytes32[14] memory words;
        words[0] = p.domain;
        words[1] = bytes32(p.chainId);
        words[2] = bytes32(uint256(uint160(p.core)));
        words[3] = bytes32(uint256(uint160(p.finalityRegistry)));
        words[4] = bytes32(uint256(p.scopeType));
        words[5] = bytes32(p.collectionId);
        words[6] = bytes32(p.tokenId);
        words[7] = p.scopeId;
        words[8] = p.coreFactsHash;
        words[9] = p.nonSanctionComponentsHash;
        words[10] = p.manifestURIHash;
        words[11] = p.manifestContentHash;
        words[12] = p.manifestSchemaId;
        words[13] = p.manifestCanonicalizationHash;
        return keccak256(abi.encode(words));
    }

    function _flatRecord(S.Record memory r) private pure returns (bytes32) {
        bytes32[14] memory words;
        words[0] = 0xc41417c9bc70713f2cd138ca6fa362e0868076b835d53f51e6d710a2be40dc6b;
        words[1] = bytes32(uint256(1));
        words[2] = bytes32(uint256(0x101));
        words[3] = r.artistId;
        words[4] = bytes32(uint256(uint160(r.signer)));
        words[5] = bytes32(uint256(r.authorityClass));
        words[6] = bytes32(uint256(r.terms.scopeType));
        words[7] = bytes32(r.terms.collectionId);
        words[8] = bytes32(r.terms.tokenId);
        words[9] = r.terms.scopeId;
        words[10] = r.terms.sanctionSubjectHash;
        words[11] = r.terms.statementHash;
        words[12] = bytes32(r.nonce);
        words[13] = bytes32(uint256(r.signedAt));
        return keccak256(abi.encode(words));
    }

    function _flatDigest(S.Record memory r) private pure returns (bytes32) {
        bytes32[10] memory words;
        words[0] = 0x0651c04c186a25456f0dc9ca0a4a29a5537f2aeb0fe7e69cb2d3d202b41549b3;
        words[1] = bytes32(uint256(0x202));
        words[2] = bytes32(uint256(r.terms.scopeType));
        words[3] = bytes32(r.terms.collectionId);
        words[4] = bytes32(r.terms.tokenId);
        words[5] = r.terms.scopeId;
        words[6] = r.terms.sanctionSubjectHash;
        words[7] = r.terms.statementHash;
        words[8] = bytes32(r.nonce);
        words[9] = bytes32(uint256(r.deadline));
        bytes32 domain = keccak256(
            abi.encode(
                keccak256(
                    "EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"
                ),
                keccak256("6529StreamArtistRegistry"),
                keccak256("1"),
                uint256(1),
                address(0x101)
            )
        );
        return keccak256(bytes.concat(hex"1901", domain, keccak256(abi.encode(words))));
    }

    function testPermanentSubjectRecordAndDeadlineAreIndependent() public {
        S.Record memory r = _record();
        r.terms.statementHash = bytes32(uint256(50));
        require(
            StreamArtistSanctionHashes.subject(_subject()) == _flatSubject(_subject()), "subject14"
        );
        bytes32 initial = StreamArtistSanctionHashes.record(_environment(), r);
        require(initial == _flatRecord(r), "record14");
        bytes32 digest = StreamArtistSanctionHashes.digest(
            _environment(), r.terms, T.Authorization(r.nonce, r.deadline, "")
        );
        require(digest == _flatDigest(r), "digest10");
        ++r.deadline;
        require(
            StreamArtistSanctionHashes.record(_environment(), r) == initial, "unsigned deadline"
        );
        require(
            StreamArtistSanctionHashes.digest(
                _environment(), r.terms, T.Authorization(r.nonce, r.deadline, "")
            ) != digest,
            "signed deadline"
        );
        ++r.signedAt;
        require(StreamArtistSanctionHashes.record(_environment(), r) != initial, "observed time");
    }

    function testFuzzPermanentRecordWords(uint256 nonce, uint64 signedAt, uint8 authorityClass)
        public
    {
        S.Record memory r = _record();
        r.nonce = nonce;
        r.signedAt = signedAt;
        r.authorityClass = authorityClass;
        require(
            StreamArtistSanctionHashes.record(_environment(), r) == _flatRecord(r), "record words"
        );
    }

    function testCeremonyCanonicalGolden() public {
        bytes memory actual = StreamArtistSanctionCeremony.document(_subject(), _ceremony());
        bytes memory expected = _golden();
        require(
            actual.length == expected.length && keccak256(actual) == keccak256(expected),
            "canonical bytes"
        );
    }

    function testCeremonyRejectsMalformedUtf8AndKeepsHealthyRetry() public {
        bytes[9] memory bad = [
            bytes(hex"80"),
            bytes(hex"c080"),
            bytes(hex"c2"),
            bytes(hex"e08080"),
            bytes(hex"eda080"),
            bytes(hex"f0808080"),
            bytes(hex"f4908080"),
            bytes(hex"f5808080"),
            bytes(hex"e228a1")
        ];
        S.Ceremony memory c = _ceremony();
        S.Subject memory p = _subject();
        for (uint256 i; i < bad.length; ++i) {
            c.statement = string(bad[i]);
            vm.expectRevert(S.InvalidSanctionCeremony.selector);
            StreamArtistSanctionCeremony.document(p, c);
        }
        c = _ceremony();
        require(
            keccak256(StreamArtistSanctionCeremony.document(p, c)) == keccak256(_golden()),
            "healthy same context"
        );
    }

    function testCeremonyBoundsAndRepeatedOrderedHashes() public {
        S.Ceremony memory c = _ceremony();
        S.Subject memory p = _subject();
        c.statement = "";
        vm.expectRevert(S.InvalidSanctionCeremony.selector);
        StreamArtistSanctionCeremony.document(p, c);
        c = _ceremony();
        c.mediaHashes = new bytes32[](17);
        vm.expectRevert(S.InvalidSanctionCeremony.selector);
        StreamArtistSanctionCeremony.document(p, c);
        c.mediaHashes = new bytes32[](2);
        c.mediaHashes[0] = bytes32(uint256(32));
        c.mediaHashes[1] = c.mediaHashes[0];
        require(
            StreamArtistSanctionCeremony.document(p, c).length > _golden().length,
            "ordered repetition"
        );
        c.mediaHashes[1] = 0;
        vm.expectRevert(S.InvalidSanctionCeremony.selector);
        StreamArtistSanctionCeremony.document(p, c);
    }

    function testArchiveWholeBytesAndSignatureRequired() public {
        S.Record memory r = _record();
        bytes memory ceremony = _golden();
        r.terms.statementHash = keccak256(ceremony);
        r.recordHash = _flatRecord(r);
        r.digest = _flatDigest(r);
        bytes memory signature = hex"0102030405";
        bytes memory actual = StreamArtistSanctionHashes.archiveBytes(
            _environment(), address(0x303), r, ceremony, signature
        );
        bytes32[24] memory words;
        words[0] = keccak256("6529STREAM_ARTIST_SANCTION_ARCHIVE_V1");
        words[1] = bytes32(uint256(1));
        words[2] = bytes32(uint256(1));
        words[3] = bytes32(uint256(0x101));
        words[4] = bytes32(uint256(0x202));
        words[5] = bytes32(uint256(0x303));
        words[6] = r.recordHash;
        words[7] = r.artistId;
        words[8] = bytes32(uint256(uint160(r.signer)));
        words[9] = bytes32(uint256(r.authorityClass));
        words[10] = bytes32(uint256(r.terms.scopeType));
        words[11] = bytes32(r.terms.collectionId);
        words[12] = bytes32(r.terms.tokenId);
        words[13] = r.terms.scopeId;
        words[14] = r.terms.sanctionSubjectHash;
        words[15] = r.terms.statementHash;
        words[16] = bytes32(r.nonce);
        words[17] = bytes32(uint256(r.signedAt));
        words[18] = bytes32(uint256(r.deadline));
        words[19] = bytes32(uint256(r.bindingGeneration));
        words[20] = r.bindingHash;
        words[21] = r.digest;
        words[22] = bytes32(uint256(768));
        words[23] = bytes32(uint256(768 + _tail(ceremony).length));
        bytes memory expected = bytes.concat(abi.encode(words), _tail(ceremony), _tail(signature));
        require(
            actual.length == expected.length && keccak256(actual) == keccak256(expected),
            "archive complete bytes"
        );
        vm.expectRevert(S.InvalidSanction.selector);
        StreamArtistSanctionHashes.archiveBytes(_environment(), address(0x303), r, ceremony, "");
        signature[0] = 0xff;
        require(
            keccak256(
                StreamArtistSanctionHashes.archiveBytes(
                    _environment(), address(0x303), r, ceremony, signature
                )
            ) != keccak256(actual),
            "actual signature bound"
        );
    }

    function _tail(bytes memory value) private pure returns (bytes memory result) {
        result = new bytes(32 + (value.length + 31) / 32 * 32);
        uint256 length = value.length;
        assembly ("memory-safe") { mstore(add(result, 32), length) }
        for (uint256 i; i < length; ++i) {
            result[32 + i] = value[i];
        }
    }

    function _golden() private pure returns (bytes memory) {
        return hex"7b22636f6e74656e74526f6f74223a22307830303030303030303030303030303030303030303030303030303030303030303030303030303030303030303030303030303030303030303030303030303166222c226d65646961486173686573223a5b22307830303030303030303030303030303030303030303030303030303030303030303030303030303030303030303030303030303030303030303030303030303230225d2c227265666572656e636552656e646572486173686573223a5b22307830303030303030303030303030303030303030303030303030303030303030303030303030303030303030303030303030303030303030303030303030303231225d2c2273616e6374696f6e5375626a656374223a7b22636861696e4964223a2231222c22636f6c6c656374696f6e4964223a2237222c22636f7265223a22307830303030303030303030303030303030303030303030303030303030303030303030303030323032222c22636f7265466163747348617368223a22307830303030303030303030303030303030303030303030303030303030303030303030303030303030303030303030303030303030303030303030303030303062222c22646f6d61696e223a22307834376339383934383732303936323438623339373166313535316235353536313961656138623633393033663532366332646133353461373238366262343733222c2266696e616c6974795265676973747279223a22307830303030303030303030303030303030303030303030303030303030303030303030303030333033222c226d616e696665737443616e6f6e6963616c697a6174696f6e48617368223a22307830303030303030303030303030303030303030303030303030303030303030303030303030303030303030303030303030303030303030303030303030303130222c226d616e6966657374436f6e74656e7448617368223a22307830303030303030303030303030303030303030303030303030303030303030303030303030303030303030303030303030303030303030303030303030303065222c226d616e6966657374536368656d614964223a22307830303030303030303030303030303030303030303030303030303030303030303030303030303030303030303030303030303030303030303030303030303066222c226d616e696665737455524948617368223a22307830303030303030303030303030303030303030303030303030303030303030303030303030303030303030303030303030303030303030303030303030303064222c226e6f6e53616e6374696f6e436f6d706f6e656e747348617368223a22307830303030303030303030303030303030303030303030303030303030303030303030303030303030303030303030303030303030303030303030303030303063222c2273636f70654964223a22307830303030303030303030303030303030303030303030303030303030303030303030303030303030303030303030303030303030303030303030303030303030222c2273636f706554797065223a312c22746f6b656e4964223a2231363036393338303434323538393930323735353431393632303932333431313632363032353232323032393933373832373932383335333031333736227d2c22736368656d61223a223635323953545245414d5f4152544953545f53414e4354494f4e5f434552454d4f4e595f5631222c227369676e696e67546f6f6c223a7b226e616d65223a224578616d706c6520546f6f6c222c2276657273696f6e223a22312e30227d2c2273746174656d656e74223a2249207265766965776564205c22746869735c222e5c6e4c696e655c5c74776f5c745c753030303020c3a920f09f9880227d";
    }
}
