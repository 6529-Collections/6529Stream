// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../../../smart-contracts/domains/artist/StreamArtistDelegationState.sol";

interface DelegationCompilerVm {
    function expectRevert(bytes calldata reason) external;
    function warp(uint256 time) external;
}

contract DelegationCompilerHarness {
    StreamArtistDelegationState.State private _state;

    struct Use {
        bytes32 record;
        bytes32 artistId;
        uint256 collectionId;
        uint32 capability;
        T.Authorization authorization;
        T.SignerApproval proof;
        address actor;
        bytes32 digest;
    }

    function grant(D.Grant memory p, address grantor, uint256 nonce) external returns (bytes32) {
        (bytes32 recordHash,) = StreamArtistDelegationState.grant(
            _state,
            StreamArtistHashes.Environment(block.chainid, address(this), address(1), address(2)),
            p,
            grantor,
            nonce
        );
        return recordHash;
    }

    function consume(Use memory p) external returns (bytes32, bytes32) {
        return StreamArtistDelegationState.consume(
            _state,
            p.record,
            p.artistId,
            p.collectionId,
            p.capability,
            p.authorization,
            p.proof,
            p.actor,
            p.digest
        );
    }

    function record(bytes32 key) external view returns (D.Record memory) {
        return _state.records[key];
    }

    function hint(bytes32 lane) external view returns (uint256) {
        return _state.hints[lane];
    }

    function word(bytes32 lane, uint8 level, uint256 prefix) external view returns (uint256) {
        return _state.availability[lane].full[level][prefix];
    }
}

/// @notice Compiler-bound delegation state transitions against independent flat-word commitments.
/// @dev SignerApproval is already verified by the Coordinator in production. This harness tests
///      the linked state boundary, not cryptographic signature admission or full artist ingress.
contract StreamArtistDelegationCompilerTest {
    DelegationCompilerVm private constant vm =
        DelegationCompilerVm(address(uint160(uint256(keccak256("hevm cheat code")))));
    bytes32 private constant ARTIST = keccak256("delegation compiler artist");
    address private constant DELEGATE = address(0x6529);
    address private constant GRANTOR = address(0x1234);
    bytes32 private constant DIGEST = keccak256("verified coordinator digest");

    function _grant(uint64 maximum) private pure returns (D.Grant memory p) {
        return D.Grant(ARTIST, DELEGATE, 7, 36, 1000, 2000, maximum, keccak256("constraints"));
    }

    function _setup(uint64 maximum) private returns (DelegationCompilerHarness h, bytes32 record) {
        vm.warp(1000);
        h = new DelegationCompilerHarness();
        record = h.grant(_grant(maximum), GRANTOR, 11);
        require(record == _grantRecord(h, maximum, 11), "literal grant record");
    }

    function _grantRecord(DelegationCompilerHarness h, uint64 maximum, uint256 nonce)
        private
        view
        returns (bytes32)
    {
        bytes32[12] memory words;
        words[0] = keccak256("6529STREAM_ARTIST_DELEGATION_RECORD_V1");
        words[1] = bytes32(block.chainid);
        words[2] = bytes32(uint256(uint160(address(h))));
        words[3] = ARTIST;
        words[4] = bytes32(uint256(uint160(DELEGATE)));
        words[5] = bytes32(uint256(7));
        words[6] = bytes32(uint256(36));
        words[7] = bytes32(uint256(1000));
        words[8] = bytes32(uint256(2000));
        words[9] = bytes32(uint256(maximum));
        words[10] = keccak256("constraints");
        words[11] = bytes32(nonce);
        return keccak256(abi.encode(words));
    }

    function _use(bytes32 record, uint256 nonce, bool direct)
        private
        pure
        returns (DelegationCompilerHarness.Use memory p)
    {
        p.record = record;
        p.artistId = ARTIST;
        p.collectionId = 7;
        p.capability = 4;
        p.authorization = T.Authorization(nonce, 1500, direct ? bytes("") : bytes(hex"01"));
        p.proof = T.SignerApproval(DELEGATE, DIGEST, direct);
        p.actor = direct ? DELEGATE : address(0x9876);
        p.digest = DIGEST;
    }

    function _lane() private pure returns (bytes32) {
        bytes32[3] memory words = [
            keccak256("6529STREAM_ARTIST_DELEGATE_NONCE_LANE_V1"),
            ARTIST,
            bytes32(uint256(uint160(DELEGATE)))
        ];
        return keccak256(abi.encode(words));
    }

    function _availability(uint256 nonce, uint256 oldWord) private pure returns (bytes32) {
        bytes32[2] memory initial =
            [keccak256("6529STREAM_ARTIST_NONCE_AVAILABILITY_INDEX_V1"), bytes32(nonce)];
        bytes32[5] memory words = [
            keccak256(abi.encode(initial)),
            bytes32(0),
            bytes32(nonce >> 8),
            bytes32(oldWord),
            bytes32(oldWord | (uint256(1) << (nonce & 255)))
        ];
        return keccak256(abi.encode(words));
    }

    function _delta(bytes32 record, D.Record memory r, uint256 nonce, uint256 hint, uint256 oldWord)
        private
        pure
        returns (bytes32)
    {
        bytes32[18] memory words;
        words[0] = record;
        words[1] = r.grant.artistId;
        words[2] = bytes32(uint256(uint160(r.grant.delegate)));
        words[3] = bytes32(r.grant.collectionId);
        words[4] = bytes32(uint256(r.grant.capabilities));
        words[5] = bytes32(uint256(r.grant.notBefore));
        words[6] = bytes32(uint256(r.grant.expiresAt));
        words[7] = bytes32(uint256(r.grant.maxUses));
        words[8] = r.grant.constraintsHash;
        words[9] = bytes32(uint256(uint160(r.grantor)));
        words[10] = bytes32(r.nonce);
        words[11] = bytes32(r.uses);
        words[12] = r.revoked ? bytes32(uint256(1)) : bytes32(0);
        words[13] = r.revocationRecordHash;
        words[14] = _lane();
        words[15] = bytes32(nonce);
        words[16] = bytes32(hint);
        words[17] = _availability(nonce, oldWord);
        return keccak256(abi.encode(words));
    }

    function _assertUse(
        DelegationCompilerHarness h,
        bytes32 record,
        uint256 nonce,
        bool direct,
        uint256 expectedHint,
        uint256 expectedUses
    ) private {
        D.Record memory expected = h.record(record);
        expected.uses = expectedUses;
        uint256 oldWord = h.word(_lane(), 0, nonce >> 8);
        (bytes32 lane, bytes32 delta) = h.consume(_use(record, nonce, direct));
        require(lane == _lane(), "literal lane");
        require(delta == _delta(record, expected, nonce, expectedHint, oldWord), "literal delta");
        require(
            keccak256(abi.encode(h.record(record))) == keccak256(abi.encode(expected)),
            "full record"
        );
        require(h.hint(lane) == expectedHint, "hint");
        require(
            h.word(lane, 0, nonce >> 8) == (oldWord | (uint256(1) << (nonce & 255))), "replay bit"
        );
    }

    function _unchanged(DelegationCompilerHarness h, bytes32 record) private view {
        require(h.record(record).uses == 0 && h.hint(_lane()) == 0, "uses/hint changed");
        require(h.word(_lane(), 0, 0) == 0, "nonce changed");
    }

    function testDelegationSignedOrderDirectAdvanceAndExhaustion() external {
        (DelegationCompilerHarness h, bytes32 record) = _setup(3);
        _assertUse(h, record, 1, false, 0, 1);
        _assertUse(h, record, 0, true, 2, 2);
        _assertUse(h, record, 2, true, 3, 3);
        DelegationCompilerHarness.Use memory p = _use(record, 3, true);
        vm.expectRevert(abi.encodeWithSelector(D.DelegationUnavailable.selector, record));
        h.consume(p);
        require(h.record(record).uses == 3 && h.hint(_lane()) == 3, "exhausted mutation");
        require(h.word(_lane(), 0, 0) == 7, "exhausted replay mutation");
    }

    function testDelegationDuplicateAndDirectWrongHintRollBack() external {
        (DelegationCompilerHarness h, bytes32 record) = _setup(0);
        DelegationCompilerHarness.Use memory p = _use(record, 1, true);
        vm.expectRevert(abi.encodeWithSelector(T.InvalidRecord.selector));
        h.consume(p);
        _unchanged(h, record);
        _assertUse(h, record, 1, false, 0, 1);
        p = _use(record, 1, false);
        vm.expectRevert(
            abi.encodeWithSelector(
                StreamArtistNonceAvailability.NonceAvailabilityAlreadyUsed.selector, uint256(1)
            )
        );
        h.consume(p);
        require(h.record(record).uses == 1 && h.hint(_lane()) == 0, "duplicate state mutation");
        require(h.word(_lane(), 0, 0) == 2, "duplicate replay mutation");
        _assertUse(h, record, 0, true, 2, 2);
    }

    function testDelegationScopeCapabilityAndSignatureRejectBeforeReplay() external {
        (DelegationCompilerHarness h, bytes32 record) = _setup(0);
        DelegationCompilerHarness.Use memory p = _use(record, 0, true);
        p.artistId = bytes32(uint256(1));
        p.capability = 128;
        p.proof.signer = address(0xBAD);
        vm.expectRevert(abi.encodeWithSelector(D.DelegationScope.selector, record));
        h.consume(p);
        _unchanged(h, record);
        p.artistId = ARTIST;
        vm.expectRevert(
            abi.encodeWithSelector(D.DelegationCapability.selector, record, uint32(128))
        );
        h.consume(p);
        _unchanged(h, record);
        p.capability = 4;
        vm.expectRevert(abi.encodeWithSelector(T.InvalidSignature.selector));
        h.consume(p);
        _unchanged(h, record);
        p = _use(record, 0, true);
        p.authorization.signature = hex"01";
        vm.expectRevert(abi.encodeWithSelector(T.InvalidSignature.selector));
        h.consume(p);
        _unchanged(h, record);
        p = _use(record, 0, false);
        p.authorization.signature = new bytes(4097);
        vm.expectRevert(
            abi.encodeWithSelector(T.BoundExceeded.selector, uint256(4097), uint256(4096))
        );
        h.consume(p);
        _unchanged(h, record);
        _assertUse(h, record, 0, true, 1, 1);
    }

    function testDelegationReplacementRetainsPermanentReplayLane() external {
        (DelegationCompilerHarness h, bytes32 record) = _setup(1);
        _assertUse(h, record, 0, true, 1, 1);
        bytes32 replacement = h.grant(_grant(2), GRANTOR, 12);
        require(replacement != record, "replacement record");
        require(replacement == _grantRecord(h, 2, 12), "literal replacement record");
        DelegationCompilerHarness.Use memory p = _use(replacement, 0, false);
        vm.expectRevert(
            abi.encodeWithSelector(
                StreamArtistNonceAvailability.NonceAvailabilityAlreadyUsed.selector, uint256(0)
            )
        );
        h.consume(p);
        require(
            h.record(replacement).uses == 0 && h.record(record).uses == 1, "replacement history"
        );
        _assertUse(h, replacement, 1, true, 2, 1);
    }

    function testDelegationTemporalAndCollectionChecksLeaveProofReusable() external {
        (DelegationCompilerHarness h, bytes32 record) = _setup(0);
        DelegationCompilerHarness.Use memory p = _use(record, 0, true);
        vm.warp(999);
        vm.expectRevert(abi.encodeWithSelector(D.DelegationUnavailable.selector, record));
        h.consume(p);
        _unchanged(h, record);
        vm.warp(2000);
        vm.expectRevert(abi.encodeWithSelector(D.DelegationUnavailable.selector, record));
        h.consume(p);
        _unchanged(h, record);
        vm.warp(1000);
        p.collectionId = 8;
        vm.expectRevert(abi.encodeWithSelector(D.DelegationScope.selector, record));
        h.consume(p);
        _unchanged(h, record);
        _assertUse(h, record, 0, true, 1, 1);
    }

    function testFuzzDelegationLiteralNonceAndRecordDelta(uint256 nonce) external {
        (DelegationCompilerHarness h, bytes32 record) = _setup(0);
        _assertUse(h, record, nonce, false, nonce == 0 ? 1 : 0, 1);
    }
}
