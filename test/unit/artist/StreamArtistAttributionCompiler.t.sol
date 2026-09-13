// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "../../../smart-contracts/domains/artist/StreamArtistAttributionLifecycle.sol";

interface AttributionCompilerVm {
    struct Log {
        bytes32[] topics;
        bytes data;
        address emitter;
    }
    function expectRevert(bytes calldata reason) external;
    function recordLogs() external;
    function getRecordedLogs() external returns (Log[] memory);
}

contract AttestationHashCompilerHarness {
    function hash(
        StreamArtistHashes.Environment memory e,
        T.Attestation memory p,
        bytes32 id,
        address signer,
        uint8 class_,
        uint256 nonce,
        uint64 at
    ) external pure returns (bytes32) {
        return StreamArtistHashes.attestationRecordForAuthority(e, p, id, signer, class_, nonce, at);
    }
}

/// @dev Actual Attribution owner; Coordinator/Identity/metadata authority are typed callback boundaries.
contract StreamArtistAttributionCompilerTest {
    AttributionCompilerVm constant vm =
        AttributionCompilerVm(address(uint160(uint256(keccak256("hevm cheat code")))));
    StreamArtistAttributionLifecycle owner;
    AttestationHashCompilerHarness hashes;
    T.Binding binding_;
    address constant REGISTRY = address(0xA1);
    address constant CORE = address(0xC0);
    address constant MANAGER = address(0xD0);
    address constant ARTIST = address(0xA11CE);

    function setUp() public {
        owner =
            new StreamArtistAttributionLifecycle(
            REGISTRY, address(this), address(0xA2), CORE, MANAGER
        );
        hashes = new AttestationHashCompilerHarness();
        binding_ = T.Binding(
            keccak256("artist"),
            ARTIST,
            keccak256("identity"),
            keccak256("binding"),
            1,
            1,
            0,
            0,
            address(0xB0B),
            false
        );
        owner.claim(_context(1), 1, binding_, 0, "");
        binding_.accepted = true;
        owner.accept(_context(2), 1, binding_, keccak256("acceptance"));
    }

    function _context(uint16 op) private view returns (T.ActionContext memory) {
        return T.ActionContext(op, address(0xB0B), owner.ownerStateSnapshotV2());
    }

    function _env() private view returns (StreamArtistHashes.Environment memory) {
        return StreamArtistHashes.Environment(block.chainid, REGISTRY, CORE, MANAGER);
    }

    function _terms(uint8 kind)
        private
        view
        returns (T.Attestation memory p, bytes memory statement)
    {
        statement = hex"00ff012233";
        p = T.Attestation(
            1,
            kind,
            kind == 9 ? bytes32(uint256(uint160(CORE))) : binding_.artistId,
            kind == 9
                ? StreamArtistHashes.deploymentFacts(_env(), 1, binding_)
                : binding_.identityRecordHash,
            kind == 9
                ? keccak256("6529STREAM_ARTIST_DEPLOYMENT_ATTESTATION_V1")
                : keccak256("6529STREAM_ARTIST_PERSONHOOD_WAIVER_V1"),
            keccak256(statement),
            "ipfs://statement"
        );
    }

    function _literal(
        StreamArtistHashes.Environment memory e,
        T.Attestation memory p,
        bytes32 id,
        address signer,
        uint8 class_,
        uint256 nonce,
        uint64 at
    ) private pure returns (bytes32) {
        bytes32[16] memory w;
        w[0] = keccak256("6529STREAM_ARTIST_ATTESTATION_RECORD_V1");
        w[1] = bytes32(e.chainId);
        w[2] = bytes32(uint256(uint160(e.registry)));
        w[3] = bytes32(uint256(uint160(e.core)));
        w[4] = bytes32(p.collectionId);
        w[5] = bytes32(uint256(p.subjectKind));
        w[6] = p.subjectId;
        w[7] = p.subjectStateHash;
        w[8] = p.schemaId;
        w[9] = p.statementHash;
        w[10] = keccak256(bytes(p.statementURI));
        w[11] = id;
        w[12] = bytes32(uint256(uint160(signer)));
        w[13] = bytes32(uint256(class_));
        w[14] = bytes32(nonce);
        w[15] = bytes32(uint256(at));
        return keccak256(abi.encode(w));
    }

    function _assertRecord(
        bytes32 record,
        T.Attestation memory p,
        bytes memory statement,
        address signer,
        uint8 class_,
        uint256 nonce,
        uint64 at,
        T.Snapshot memory before_
    ) private view {
        require(
            record == _literal(_env(), p, binding_.artistId, signer, class_, nonce, at),
            "independent16 words"
        );
        T.AttestationRecord memory r = owner.attestationRecord(record);
        require(
            r.recordHash == record && r.subjectStateHash == p.subjectStateHash
                && r.schemaId == p.schemaId && r.statementHash == p.statementHash
                && r.generation == binding_.generation && r.signedAt == at && r.signer == signer,
            "all seven retained record fields"
        );
        require(
            keccak256(abi.encode(owner.attestation(1, p.subjectKind, p.subjectId)))
                    == keccak256(abi.encode(r))
                && keccak256(owner.statementBytes(p.statementHash)) == keccak256(statement),
            "latest and bytes match"
        );
        T.Snapshot memory after_ = owner.ownerStateSnapshotV2();
        require(
            after_.revision == before_.revision + 1
                && after_.recordChainTip != before_.recordChainTip,
            "one state and primary record commit"
        );
    }

    function testLegacyDeploymentAndIdentityCallbacksPreserveRecordAndLatest() public {
        (T.Attestation memory p, bytes memory s) = _terms(9);
        T.Snapshot memory before_ = owner.ownerStateSnapshotV2();
        bytes32 hash = owner.recordAttestation(_context(24), binding_, p, ARTIST, 7, 1000, s);
        _assertRecord(hash, p, s, ARTIST, 1, 7, 1000, before_);
        (p, s) = _terms(10);
        before_ = owner.ownerStateSnapshotV2();
        hash = owner.recordIdentityAttestation(
            _context(24), binding_, p, binding_.identityRecordHash, ARTIST, 8, 1001, s
        );
        _assertRecord(hash, p, s, ARTIST, 1, 8, 1001, before_);
    }

    function testActualClassThreeAttestationExactEventAndDuplicateRollback() public {
        (T.Attestation memory p, bytes memory s) = _terms(10);
        R.AuthorityFact memory a = R.AuthorityFact(binding_.artistId, address(0x333), 3, 3);
        T.ActionContext memory c = _context(24);
        T.Snapshot memory before_ = owner.ownerStateSnapshotV2();
        vm.recordLogs();
        bytes32 hash = owner.recordAttestationWithAuthority(
            c, binding_, p, binding_.identityRecordHash, a, a.authorityAddress, 9, 1002, s
        );
        _assertRecord(hash, p, s, a.authorityAddress, 3, 9, 1002, before_);
        AttributionCompilerVm.Log[] memory logs = vm.getRecordedLogs();
        require(
            logs.length == 1 && logs[0].emitter == address(owner) && logs[0].topics.length == 4
                && logs[0].topics[0]
                    == keccak256(
                        "ArtistAttestationRecorded(uint16,uint256,uint8,address,bytes32,bytes32,bytes32,bytes32,bytes32,uint8,uint256,uint64,bytes32)"
                    ) && logs[0].topics[1] == bytes32(uint256(1))
                && logs[0].topics[2] == bytes32(uint256(10))
                && logs[0].topics[3] == bytes32(uint256(uint160(a.authorityAddress))),
            "exact event position and topics"
        );
        require(
            keccak256(logs[0].data)
                == keccak256(
                    abi.encode(
                        uint16(1),
                        p.subjectId,
                        p.subjectStateHash,
                        p.schemaId,
                        p.statementHash,
                        keccak256(bytes(p.statementURI)),
                        uint8(3),
                        uint256(9),
                        uint64(1002),
                        hash
                    )
                ),
            "exact event bytes"
        );
        before_ = owner.ownerStateSnapshotV2();
        c = _context(24);
        vm.expectRevert(abi.encodeWithSelector(T.InvalidRecord.selector));
        owner.recordAttestationWithAuthority(
            c, binding_, p, binding_.identityRecordHash, a, a.authorityAddress, 9, 1002, s
        );
        require(
            keccak256(abi.encode(owner.ownerStateSnapshotV2())) == keccak256(abi.encode(before_)),
            "duplicate no state/history change"
        );
    }

    function testAuthorityAndStatementFailuresPreserveSameRecordRetry() public {
        (T.Attestation memory p, bytes memory s) = _terms(10);
        T.ActionContext memory c = _context(24);
        R.AuthorityFact memory a = R.AuthorityFact(binding_.artistId, ARTIST, 1, 4);
        T.Snapshot memory before_ = owner.ownerStateSnapshotV2();
        vm.expectRevert(abi.encodeWithSelector(T.InvalidRecord.selector));
        owner.recordAttestationWithAuthority(
            c, binding_, p, binding_.identityRecordHash, a, ARTIST, 2, 1000, s
        );
        a.status = 1;
        vm.expectRevert(abi.encodeWithSelector(T.InvalidRecord.selector));
        owner.recordAttestationWithAuthority(
            c, binding_, p, binding_.identityRecordHash, a, ARTIST, 2, 1000, hex"0123"
        );
        require(
            keccak256(abi.encode(owner.ownerStateSnapshotV2())) == keccak256(abi.encode(before_)),
            "both failures before commit"
        );
        bytes32 hash = owner.recordAttestationWithAuthority(
            c, binding_, p, binding_.identityRecordHash, a, ARTIST, 2, 1000, s
        );
        _assertRecord(hash, p, s, ARTIST, 1, 2, 1000, before_);
    }

    function _publication(uint8 class_, bool intent) private {
        address signer = class_ == 1 ? ARTIST : address(0x333);
        R.AuthorityFact memory a = R.AuthorityFact(binding_.artistId, signer, class_, class_);
        P.Publication memory pub = P.Publication(
            address(0x123),
            signer,
            1,
            keccak256("subject"),
            intent ? keccak256("ARTIST_INTENT") : keccak256("ARTIST_SEMANTIC_ASSERTION"),
            intent
                ? keccak256("STREAM_ARTIST_INTENT_V1")
                : keccak256("STREAM_SEMANTIC_ASSERTION_V1"),
            keccak256("JCS_RFC8785"),
            1,
            keccak256("payload"),
            keccak256("ipfs://publication"),
            1000,
            keccak256("canonical candidate")
        );
        bytes memory s = abi.encode(uint16(1), pub);
        T.Attestation memory p = T.Attestation(
            1,
            intent ? 7 : 8,
            pub.subjectId,
            intent ? pub.candidateRecordHash : bytes32(0),
            keccak256("6529STREAM_ARTIST_RECORD_PUBLICATION_V1"),
            keccak256(s),
            "ipfs://publication"
        );
        T.Snapshot memory before_ = owner.ownerStateSnapshotV2();
        bytes32 pin = keccak256("typed metadata host runtime");
        bytes32 hash = owner.recordPublicationAttestation(
            _context(24), binding_, p, a, 33, 1000, s, pin
        );
        _assertRecord(hash, p, s, signer, class_, 33, 1000, before_);
        IStreamArtistRecordPublicationOwner.Record memory r = owner.publicationAttestation(hash);
        require(
            keccak256(abi.encode(r.publication)) == keccak256(abi.encode(pub))
                && r.metadataHostCodeHash == pin && r.evidence.signer == signer
                && r.evidence.authorityClass == class_
                && r.evidence.requiredCapability == (intent ? 64 : 1),
            "all publication inputs retain authority and family"
        );
    }

    function testPrincipalIntentPublicationInputPreservesCompleteEvidence() public {
        _publication(1, true);
    }

    function testSuccessorSemanticPublicationInputPreservesCompleteEvidence() public {
        _publication(3, false);
    }

    function testFuzzExactStaticAttestationWords(
        uint256 chainId,
        uint256 nonce,
        uint64 at,
        uint8 class_,
        bytes32 subject
    ) public view {
        (T.Attestation memory p,) = _terms(10);
        p.subjectId = subject;
        p.statementURI = string(abi.encodePacked(subject));
        StreamArtistHashes.Environment memory e = _env();
        e.chainId = chainId;
        require(
            hashes.hash(e, p, binding_.artistId, ARTIST, class_, nonce, at)
                == _literal(e, p, binding_.artistId, ARTIST, class_, nonce, at),
            "independent fuzz16 words"
        );
    }
}
