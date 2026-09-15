// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    StreamArtistStewardSanctionState as G
} from "../../../smart-contracts/domains/artist/StreamArtistStewardSanctionState.sol";
import {
    StreamArtistIdentityState
} from "../../../smart-contracts/domains/artist/StreamArtistIdentityState.sol";
import {
    StreamArtistRotationState
} from "../../../smart-contracts/domains/artist/StreamArtistRotationState.sol";
import { StreamArtistHashes } from "../../../smart-contracts/domains/artist/StreamArtistHashes.sol";
import {
    StreamArtistOnboardingTypes as T
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistOnboardingTypes.sol";
import {
    StreamArtistRotationTypes as R
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistRotationTypes.sol";
import {
    IStreamArtistStewardSanctionGrant as SG
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistStewardSanctionGrant.sol";
import "../../regression/legacy/helpers/CharacterizationTestBase.sol";

/// @dev Actual Identity nonce/signature and Rotation eligibility state, with an explicit trusted
///      Coordinator-verdict boundary. This harness does not claim facade, ERC1271 or Archive execution.
contract StewardSanctionStateHarness {
    address public immutable owner;
    G.State private grants;
    StreamArtistIdentityState.State private identities;
    StreamArtistRotationState.State private rotations;
    mapping(bytes32 => T.ReplayCell) private replay;

    constructor() {
        owner = msg.sender;
    }
    modifier onlyOwner() {
        require(msg.sender == owner, "owner");
        _;
    }

    function environment() public view returns (StreamArtistHashes.Environment memory) {
        return StreamArtistHashes.Environment(
            block.chainid, address(this), address(0xc0), address(0x123)
        );
    }

    function principal(bytes32 artistId, uint8 cls, uint8 status) external onlyOwner {
        T.Identity storage p = identities.identities[artistId];
        p.authorityAddress = owner;
        p.authorityClass = cls;
        p.status = status;
    }

    function recordGrant(
        SG.Grant calldata p,
        T.Authorization calldata a,
        T.SignerApproval calldata proof,
        uint16 operation
    ) external onlyOwner returns (bytes32) {
        StreamArtistIdentityState.OwnerContext memory o =
            StreamArtistIdentityState.OwnerContext(
                environment(), address(this), address(0xa), keccak256("IDENTITY"), 0
            );
        T.ActionContext memory c;
        c.operationId = operation;
        c.actor = msg.sender;
        return G.record(grants, identities, rotations, replay, o, c, p, a, proof).record;
    }

    function current(bytes32 artistId) external view returns (bool, bytes32) {
        return G.current(grants, rotations, artistId);
    }

    function item(bytes32 hash) external view returns (SG.GrantRecord memory) {
        return grants.records[hash];
    }

    function signature(bytes32 hash) external view returns (bytes memory) {
        return identities.signatures[hash];
    }

    function identity(bytes32 artistId) external view returns (T.Identity memory) {
        return identities.identities[artistId];
    }

    function digest(SG.Grant calldata p, T.Authorization calldata a)
        external
        view
        returns (bytes32)
    {
        return G.digest(environment(), p, a);
    }

    function hashRecord(SG.Grant calldata p, T.Authorization calldata a, address signer)
        external
        view
        returns (bytes32)
    {
        return G.recordHash(environment(), p, a, signer);
    }

    function transition(
        bytes32 artistId,
        bytes32 hash,
        uint64 endsAt,
        uint64 contestedAt,
        uint8 phase
    ) external onlyOwner {
        rotations.latestExecution[artistId] = hash;
        R.RotationRecord storage record_ = rotations.rotations[hash];
        record_.recordHash = hash;
        record_.transition = R.TransitionState(artistId, hash, 1, 2, 3, endsAt, contestedAt, phase);
    }
}

contract StreamArtistStewardSanctionStateTest is CharacterizationTestBase {
    StewardSanctionStateHarness private host;
    bytes32 private constant ARTIST = keccak256("original artist");

    function setUp() public {
        vm.warp(1000);
        host = new StewardSanctionStateHarness();
        host.principal(ARTIST, 1, 1);
    }

    function _terms(bool granted) private pure returns (SG.Grant memory) {
        return SG.Grant(ARTIST, granted, keccak256("canonical statement commitment"));
    }

    function _auth(uint256 nonce) private pure returns (T.Authorization memory) {
        return T.Authorization(nonce, 900, hex"112233445566");
    }

    function _proof(SG.Grant memory p, T.Authorization memory a)
        private
        view
        returns (T.SignerApproval memory)
    {
        return T.SignerApproval(address(this), host.digest(p, a), false);
    }

    function _record(bool granted, uint256 nonce) private returns (bytes32) {
        SG.Grant memory p = _terms(granted);
        T.Authorization memory a = _auth(nonce);
        T.SignerApproval memory proof = _proof(p, a);
        return host.recordGrant(p, a, proof, 19);
    }

    function testCanonicalOp19DigestRecordSignatureAndEntireEvent() public {
        SG.Grant memory p = _terms(true);
        T.Authorization memory a = _auth(7);
        bytes32 structHash = keccak256(
            abi.encode(
                keccak256(
                    "StreamStewardSanctionGrant(bytes32 artistId,bool granted,bytes32 statementHash,uint256 nonce,uint64 signedAt)"
                ),
                p.artistId,
                p.granted,
                p.statementHash,
                a.nonce,
                a.time
            )
        );
        bytes32 domain = keccak256(
            abi.encode(
                keccak256(
                    "EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"
                ),
                keccak256("6529StreamArtistRegistry"),
                keccak256("1"),
                block.chainid,
                address(host)
            )
        );
        require(
            host.digest(p, a) == keccak256(abi.encodePacked("\x19\x01", domain, structHash)),
            "original signed schema"
        );
        bytes32 expected = keccak256(
            abi.encode(
                keccak256("6529STREAM_ARTIST_STEWARD_SANCTION_GRANT_RECORD_V1"),
                block.chainid,
                address(host),
                ARTIST,
                true,
                p.statementHash,
                address(this),
                uint8(1),
                a.nonce,
                a.time
            )
        );
        T.SignerApproval memory proof = _proof(p, a);
        vm.recordLogs();
        bytes32 result = host.recordGrant(p, a, proof, 19);
        Vm.Log[] memory logs = vm.getRecordedLogs();
        require(
            result == expected && host.hashRecord(p, a, address(this)) == expected,
            "original signer-scoped record"
        );
        require(
            keccak256(host.signature(result)) == keccak256(a.signature), "full original signature"
        );
        SG.GrantRecord memory stored = host.item(result);
        require(
            keccak256(abi.encode(stored))
                == keccak256(
                    abi.encode(
                        SG.GrantRecord(
                            expected,
                            p,
                            address(this),
                            1,
                            a.nonce,
                            a.time,
                            R.ProvisionalAssociation(0, 0)
                        )
                    )
                ),
            "full retained original record"
        );
        require(
            logs.length == 1 && logs[0].emitter == address(host) && logs[0].topics.length == 3,
            "one canonical event"
        );
        require(
            logs[0].topics[0]
                == keccak256(
                    "StewardSanctionGrantRecorded(uint16,bytes32,address,bool,bytes32,uint8,uint256,uint64,bytes32)"
                ),
            "event schema"
        );
        require(
            logs[0].topics[1] == ARTIST
                && logs[0].topics[2] == bytes32(uint256(uint160(address(this)))),
            "indexed identities"
        );
        require(
            keccak256(logs[0].data)
                == keccak256(
                    abi.encode(
                        uint16(1), true, p.statementHash, uint8(1), a.nonce, a.time, expected
                    )
                ),
            "full event data"
        );
    }

    function testHighestNonceWithdrawalAndLowerLateRecordsRemainAppendOnly() public {
        bytes32 grant = _record(true, 10);
        bytes32 olderWithdrawal = _record(false, 2);
        (bool granted, bytes32 operative) = host.current(ARTIST);
        require(granted && operative == grant, "lower nonce cannot replace grant");
        bytes32 withdrawal = _record(false, 11);
        bytes32 olderGrant = _record(true, 9);
        (granted, operative) = host.current(ARTIST);
        require(!granted && operative == withdrawal, "highest withdrawal wins");
        require(
            host.item(grant).recordHash == grant
                && host.item(olderWithdrawal).recordHash == olderWithdrawal
                && host.item(olderGrant).recordHash == olderGrant,
            "original history remains"
        );
        T.Authorization memory a = _auth(11);
        SG.Grant memory p = _terms(false);
        T.SignerApproval memory proof = _proof(p, a);
        vm.expectRevert(abi.encodeWithSelector(T.InvalidRecord.selector));
        host.recordGrant(p, a, proof, 19);
        require(host.item(withdrawal).terms.granted == false, "replay cannot rewrite withdrawal");
    }

    function testWrongApprovalRollsBackThenIdenticalAuthorizationRetries() public {
        SG.Grant memory p = _terms(true);
        T.Authorization memory a = _auth(0);
        T.SignerApproval memory proof = _proof(p, a);
        bytes32 originalDigest = proof.digest;
        proof.digest = keccak256("wrong verdict");
        bytes32 expected = host.hashRecord(p, a, address(this));
        vm.expectRevert(abi.encodeWithSelector(T.InvalidSignature.selector));
        host.recordGrant(p, a, proof, 19);
        require(
            host.identity(ARTIST).nonceHint == 0 && host.item(expected).recordHash == 0
                && host.signature(expected).length == 0,
            "failed nonce/record/signature rollback"
        );
        proof.digest = originalDigest;
        require(
            host.recordGrant(p, a, proof, 19) == expected && host.identity(ARTIST).nonceHint == 1,
            "same authorization retry"
        );
    }

    function testLivingArtistOnlyIncludesNoticeButRejectsOtherClassesAndContested() public {
        SG.Grant memory p = _terms(true);
        T.Authorization memory a = _auth(0);
        T.SignerApproval memory proof = _proof(p, a);
        for (uint8 cls = 2; cls <= 4; ++cls) {
            host.principal(ARTIST, cls, cls == 2 ? 1 : 3);
            vm.expectRevert(abi.encodeWithSelector(SG.InvalidStewardSanctionGrant.selector, ARTIST));
            host.recordGrant(p, a, proof, 19);
        }
        host.principal(ARTIST, 1, 4);
        vm.expectRevert(abi.encodeWithSelector(SG.InvalidStewardSanctionGrant.selector, ARTIST));
        host.recordGrant(p, a, proof, 19);
        host.principal(ARTIST, 1, 2);
        require(host.recordGrant(p, a, proof, 19) != 0, "notice remains living Artist authority");
    }

    function testProvisionalWithdrawalBecomesOperativeOnlyAfterActualWindow() public {
        bytes32 original = _record(true, 1);
        bytes32 transitionHash = keccak256("executed rotation");
        host.transition(ARTIST, transitionHash, 2000, 0, 2);
        bytes32 pending = _record(false, 3);
        SG.GrantRecord memory retained = host.item(pending);
        require(
            retained.provisional.transitionRecordHash == transitionHash
                && retained.provisional.windowEndsAt == 2000,
            "actual association"
        );
        (bool granted, bytes32 operative) = host.current(ARTIST);
        require(granted && operative == original, "provisional withdrawal cannot suppress original");
        vm.warp(2000);
        (granted, operative) = host.current(ARTIST);
        require(
            !granted && operative == pending && host.item(original).terms.granted,
            "eligible withdrawal preserves original record"
        );
    }

    function testContestedOrSupersededProvisionalRecordNeverDisplacesPriorGrant() public {
        bytes32 original = _record(true, 1);
        bytes32 transitionHash = keccak256("contested rotation");
        host.transition(ARTIST, transitionHash, 2000, 0, 2);
        bytes32 pending = _record(false, 3);
        host.transition(ARTIST, transitionHash, 2000, 1500, 2);
        vm.warp(2100);
        (bool granted, bytes32 operative) = host.current(ARTIST);
        require(granted && operative == original, "timely contest never times out");
        host.transition(ARTIST, transitionHash, 2000, 1500, 3);
        (granted, operative) = host.current(ARTIST);
        require(
            granted && operative == original && host.item(pending).recordHash == pending,
            "superseded candidate is retained but ineligible"
        );
    }
}
