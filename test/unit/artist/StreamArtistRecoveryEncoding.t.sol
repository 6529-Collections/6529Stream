// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../../../smart-contracts/domains/artist/StreamArtistRecoveryHashes.sol";

/// @notice Literal permanent words only; operative recovery and authority admission are separate.
contract StreamArtistRecoveryEncodingTest {
    function _environment() private pure returns (StreamArtistHashes.Environment memory) {
        return StreamArtistHashes.Environment(1, address(0x101), address(0x202), address(0x404));
    }

    function _approval() private pure returns (Recovery.ApprovalRecord memory r) {
        r.terms =
            Recovery.ApprovalTerms(address(0x303), 7, bytes32(uint256(11)), bytes32(uint256(12)));
        r.artistId = bytes32(uint256(13));
        r.signer = address(0x505);
        r.authorityClass = 3;
        r.nonce = 17;
        r.signedAt = 1000;
        r.deadline = 2000;
        r.bindingGeneration = 2;
        r.bindingHash = bytes32(uint256(18));
        r.digest = bytes32(uint256(19));
    }

    function _finding() private pure returns (Recovery.FindingRecord memory r) {
        r.terms = Recovery.FindingRequest(
            bytes32(uint256(13)), 7, bytes32(uint256(21)), bytes32(uint256(22))
        );
        r.governanceActionId = bytes32(uint256(23));
        r.noticeEndsAt = 1000 + 90 days;
        r.recordedAt = 1000;
        r.noticeSeconds = 90 days;
        r.timingRevision = 1;
        r.bindingGeneration = 2;
        r.bindingHash = bytes32(uint256(18));
    }

    function _approvalWords(Recovery.ApprovalRecord memory r) private pure returns (bytes32) {
        bytes32[12] memory w;
        w[0] = 0xe60e6ec1d140fa0166261169322ac5c58d77797094a2b68866f812d1172e89b9;
        w[1] = bytes32(uint256(1));
        w[2] = bytes32(uint256(0x101));
        w[3] = bytes32(uint256(uint160(r.terms.finalityRegistry)));
        w[4] = bytes32(r.terms.collectionId);
        w[5] = r.terms.finalityRecordHash;
        w[6] = r.terms.recoveryManifestHash;
        w[7] = r.artistId;
        w[8] = bytes32(uint256(uint160(r.signer)));
        w[9] = bytes32(uint256(r.authorityClass));
        w[10] = bytes32(r.nonce);
        w[11] = bytes32(uint256(r.signedAt));
        return keccak256(abi.encode(w));
    }

    function _findingWords(Recovery.FindingRecord memory r) private pure returns (bytes32) {
        bytes32[10] memory w;
        w[0] = 0xc087b73d3ef4933341423d2630b88eca87257e38716a129b316ebc148a7fa1f5;
        w[1] = bytes32(uint256(1));
        w[2] = bytes32(uint256(0x101));
        w[3] = r.terms.artistId;
        w[4] = bytes32(r.terms.collectionId);
        w[5] = r.terms.evidenceHash;
        w[6] = r.terms.reasonHash;
        w[7] = r.governanceActionId;
        w[8] = bytes32(uint256(r.noticeEndsAt));
        w[9] = bytes32(uint256(r.recordedAt));
        return keccak256(abi.encode(w));
    }

    function _digestWords(StreamArtistHashes.Environment memory e, Recovery.ApprovalRecord memory r)
        private
        pure
        returns (bytes32)
    {
        bytes32[8] memory w;
        w[0] = keccak256(
            "StreamArtistRecoveryApproval(address core,address finalityRegistry,uint256 collectionId,bytes32 finalityRecordHash,bytes32 recoveryManifestHash,uint256 nonce,uint64 deadline)"
        );
        w[1] = bytes32(uint256(uint160(e.core)));
        w[2] = bytes32(uint256(uint160(r.terms.finalityRegistry)));
        w[3] = bytes32(r.terms.collectionId);
        w[4] = r.terms.finalityRecordHash;
        w[5] = r.terms.recoveryManifestHash;
        w[6] = bytes32(r.nonce);
        w[7] = bytes32(uint256(r.deadline));
        bytes32 domain = keccak256(
            abi.encode(
                keccak256(
                    "EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"
                ),
                keccak256("6529StreamArtistRegistry"),
                keccak256("1"),
                e.chainId,
                e.registry
            )
        );
        return keccak256(bytes.concat(hex"1901", domain, keccak256(abi.encode(w))));
    }

    function testPermanentApprovalAndFindingLiteralWords() public pure {
        Recovery.ApprovalRecord memory r = _approval();
        require(
            StreamArtistRecoveryHashes.approvalRecord(_environment(), r) == _approvalWords(r),
            "approval12"
        );
        Recovery.FindingRecord memory f = _finding();
        require(
            StreamArtistRecoveryHashes.findingRecord(_environment(), f) == _findingWords(f),
            "finding10"
        );
        require(
            StreamArtistRecoveryHashes.approvalDigest(_environment(), r.terms, r.nonce, r.deadline)
                == _digestWords(_environment(), r),
            "digest8"
        );
    }

    function testDigestSeparatesActualChainVerifierAndCore() public pure {
        StreamArtistHashes.Environment memory e = _environment();
        Recovery.ApprovalRecord memory r = _approval();
        bytes32 initial = _digestWords(e, r);
        e.chainId = 2;
        bytes32 changed = StreamArtistRecoveryHashes.approvalDigest(e, r.terms, r.nonce, r.deadline);
        require(changed == _digestWords(e, r) && changed != initial, "chain");
        e = _environment();
        e.registry = address(0x999);
        changed = StreamArtistRecoveryHashes.approvalDigest(e, r.terms, r.nonce, r.deadline);
        require(changed == _digestWords(e, r) && changed != initial, "verifier");
        e = _environment();
        e.core = address(0x999);
        changed = StreamArtistRecoveryHashes.approvalDigest(e, r.terms, r.nonce, r.deadline);
        require(changed == _digestWords(e, r) && changed != initial, "core");
    }

    function testApprovalAdmissionEvidenceDoesNotRewritePermanentRecord() public pure {
        Recovery.ApprovalRecord memory r = _approval();
        bytes32 initial = StreamArtistRecoveryHashes.approvalRecord(_environment(), r);
        bytes32 digest = _digestWords(_environment(), r);
        ++r.deadline;
        ++r.bindingGeneration;
        r.bindingHash = bytes32(uint256(999));
        r.digest = bytes32(uint256(1000));
        r.recordHash = bytes32(uint256(1001));
        require(
            StreamArtistRecoveryHashes.approvalRecord(_environment(), r) == initial,
            "admission is separate"
        );
        require(
            StreamArtistRecoveryHashes.approvalDigest(_environment(), r.terms, r.nonce, r.deadline)
                != digest,
            "deadline signed"
        );
        ++r.signedAt;
        require(
            StreamArtistRecoveryHashes.approvalRecord(_environment(), r) != initial,
            "observed time recorded"
        );
    }

    function testFindingCapturedTimingAndAssociationAreSeparateEvidence() public pure {
        Recovery.FindingRecord memory r = _finding();
        bytes32 initial = StreamArtistRecoveryHashes.findingRecord(_environment(), r);
        ++r.noticeSeconds;
        ++r.timingRevision;
        ++r.bindingGeneration;
        r.bindingHash = bytes32(uint256(999));
        r.recordHash = bytes32(uint256(1000));
        require(
            StreamArtistRecoveryHashes.findingRecord(_environment(), r) == initial,
            "separate evidence"
        );
        ++r.noticeEndsAt;
        require(
            StreamArtistRecoveryHashes.findingRecord(_environment(), r) != initial,
            "notice recorded"
        );
        --r.noticeEndsAt;
        ++r.recordedAt;
        require(
            StreamArtistRecoveryHashes.findingRecord(_environment(), r) != initial,
            "observed time recorded"
        );
    }

    function testFuzzApprovalWords(uint256 nonce, uint64 signedAt, uint8 authorityClass)
        public
        pure
    {
        Recovery.ApprovalRecord memory r = _approval();
        r.nonce = nonce;
        r.signedAt = signedAt;
        r.authorityClass = authorityClass;
        require(
            StreamArtistRecoveryHashes.approvalRecord(_environment(), r) == _approvalWords(r),
            "approval words"
        );
        require(
            StreamArtistRecoveryHashes.approvalDigest(_environment(), r.terms, r.nonce, r.deadline)
                == _digestWords(_environment(), r),
            "digest words"
        );
    }

    function testFuzzFindingWords(uint256 collectionId, uint64 recordedAt, uint64 endsAt)
        public
        pure
    {
        Recovery.FindingRecord memory r = _finding();
        r.terms.collectionId = collectionId;
        r.recordedAt = recordedAt;
        r.noticeEndsAt = endsAt;
        require(
            StreamArtistRecoveryHashes.findingRecord(_environment(), r) == _findingWords(r),
            "finding words"
        );
    }
}
