// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamArtistGuardianAppealEvidence
} from "../../../smart-contracts/domains/artist/StreamArtistGuardianAppealEvidence.sol";
import {
    StreamArtistGuardianAppealAuthority
} from "../../../smart-contracts/domains/artist/StreamArtistGuardianAppealAuthority.sol";
import {
    StreamArtistGuardianAppealTypes as A
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistGuardianAppealTypes.sol";
import {
    StreamArtistIdentityRecoveryOperationTypes as R
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistIdentityRecoveryOperationTypes.sol";

contract GuardianAppealReadBoundary {
    mapping(bytes4 => bytes) private replies;

    function set(bytes4 selector, bytes calldata reply) external {
        replies[selector] = reply;
    }

    fallback() external {
        bytes memory reply = replies[msg.sig];
        assembly ("memory-safe") { return(add(reply, 32), mload(reply)) }
    }
}

/// @dev Pure publication grammar and typed root/role reads; actual authority/owner admission is a separate cohort.
contract StreamArtistGuardianAppealEvidenceTest {
    GuardianAppealReadBoundary private executor;
    GuardianAppealReadBoundary private roles;
    StreamArtistGuardianAppealEvidence private publisher;

    function setUp() public {
        executor = new GuardianAppealReadBoundary();
        roles = new GuardianAppealReadBoundary();
        publisher = new StreamArtistGuardianAppealEvidence(address(this), address(0x2222));
        _restore();
    }

    function _set(GuardianAppealReadBoundary target, string memory signature, bytes memory data)
        private
    {
        target.set(bytes4(keccak256(bytes(signature))), data);
    }

    function _restore() private {
        _set(executor, "roleRegistry()", abi.encode(address(roles)));
        _set(roles, "owner()", abi.encode(address(executor)));
        _set(executor, "owner()", abi.encode(address(this)));
        _set(
            executor,
            "governanceRootState()",
            abi.encode(address(this), address(this).codehash, uint64(7))
        );
        _set(roles, "hasRole(bytes32,address)", abi.encode(true));
        _set(
            roles, "roleMutationState(bytes32)", abi.encode(keccak256("appeal mutation"), uint64(3))
        );
    }

    function observe() external view returns (A.Authority memory) {
        return StreamArtistGuardianAppealAuthority.current(address(executor), address(roles));
    }

    function _rejectAuthority() private view {
        (bool ok,) = address(this).staticcall(abi.encodeCall(this.observe, ()));
        require(!ok, "bad actual reciprocal or root fact rejected");
    }

    function _request() private pure returns (R.Request memory p) {
        p = R.Request(
            bytes32(uint256(1)),
            address(0x1234),
            1,
            bytes32(uint256(2)),
            bytes32(uint256(3)),
            bytes32(uint256(4)),
            bytes32(uint256(5)),
            new bytes32[](1)
        );
        p.supersededRecordHashes[0] = bytes32(uint256(9));
    }

    function _document() private pure returns (A.Document memory d) {
        d = A.Document(
            A.requestCommitment(_request()),
            bytes32(uint256(2)),
            bytes32(uint256(6)),
            bytes32(uint256(7)),
            bytes32(uint256(8)),
            bytes32(uint256(10)),
            new A.Finding[](1)
        );
        d.findings[0] = A.Finding(bytes32(uint256(9)), new address[](2));
        d.findings[0].parties[0] = address(0x10);
        d.findings[0].parties[1] = address(0x20);
    }

    function testExactRootRoleAndReciprocalWitness() public view {
        A.Authority memory a = this.observe();
        require(
            a.executor == address(executor) && a.roles == address(roles) && a.root == address(this)
        );
        require(
            a.rootCodeHash == address(this).codehash && a.rootRevision == 7 && a.roleRevision == 3
        );
        require(a.roleMutationHash == keccak256("appeal mutation"));
    }

    function testOwnerRootAndRolesDisagreementsReject() public {
        _set(executor, "owner()", abi.encode(address(0xBAD)));
        _rejectAuthority();
        _restore();
        _set(roles, "owner()", abi.encode(address(0xBAD)));
        _rejectAuthority();
        _restore();
        _set(executor, "roleRegistry()", abi.encode(address(0xBAD)));
        _rejectAuthority();
        _restore();
        _set(
            executor,
            "governanceRootState()",
            abi.encode(address(this), bytes32(uint256(1)), uint64(7))
        );
        _rejectAuthority();
        _restore();
        _set(
            executor,
            "governanceRootState()",
            abi.encode(address(0x1234), bytes32(uint256(1)), uint64(7))
        );
        _rejectAuthority();
        _restore();
        require(this.observe().root == address(this));
    }

    function testRoleRevocationAndMalformedRootFactsReject() public {
        _set(roles, "hasRole(bytes32,address)", abi.encode(false));
        _rejectAuthority();
        _restore();
        _set(executor, "governanceRootState()", abi.encode(address(this), address(this).codehash));
        _rejectAuthority();
        _restore();
        _set(
            executor,
            "governanceRootState()",
            abi.encode(address(this), address(this).codehash, uint64(7), uint256(0))
        );
        _rejectAuthority();
        _restore();
        _set(
            roles, "roleMutationState(bytes32)", abi.encode(keccak256("appeal mutation"), uint64(0))
        );
        _rejectAuthority();
        _restore();
        bytes32 before_ = keccak256(abi.encode(this.observe()));
        _set(
            executor,
            "governanceRootState()",
            abi.encode(address(this), address(this).codehash, uint64(8))
        );
        require(
            keccak256(abi.encode(this.observe())) != before_, "root revision enters policy identity"
        );
    }

    function testPublicationRetainsExactBytesAndObservedOwnerCode() public {
        A.Document memory d = _document();
        bytes32 hash = publisher.publish(d);
        require(hash == A.documentHash(block.chainid, address(0x2222), address(this), d));
        (A.Document memory saved, bytes32 observed) = publisher.evidence(hash);
        require(
            keccak256(abi.encode(saved)) == keccak256(abi.encode(d))
                && observed == address(this).codehash
        );
        require(publisher.publish(d) == hash, "identical immutable publication is idempotent");
        d.hostileFindingsHash = keccak256("other findings");
        require(publisher.publish(d) != hash, "changed findings get different immutable identity");
        (saved,) = publisher.evidence(hash);
        require(saved.hostileFindingsHash == bytes32(uint256(10)), "old content never overwritten");
    }

    function testPublisherRejectsEmptyDuplicateAndUnorderedParties() public {
        A.Document memory d = _document();
        d.findings[0].parties[1] = d.findings[0].parties[0];
        (bool ok,) = address(publisher).call(abi.encodeCall(publisher.publish, (d)));
        require(!ok);
        d = _document();
        d.findings = new A.Finding[](0);
        (ok,) = address(publisher).call(abi.encodeCall(publisher.publish, (d)));
        require(!ok);
        d = _document();
        d.findings[0].parties = new address[](0);
        (ok,) = address(publisher).call(abi.encodeCall(publisher.publish, (d)));
        require(!ok);
        d = _document();
        d.findings[0].parties[0] = address(0x30);
        (ok,) = address(publisher).call(abi.encodeCall(publisher.publish, (d)));
        require(!ok);
        require(publisher.publish(_document()) != 0);
    }

    function testFuzzRequestOmitsOnlyResultingEvidenceHash(bytes32 evidence) public pure {
        R.Request memory p = _request();
        bytes32 original = A.requestCommitment(p);
        p.evidenceHash = evidence;
        require(A.requestCommitment(p) == original);
        require(
            original
                == keccak256(
                    abi.encode(
                        keccak256("6529STREAM_ARTIST_GUARDIAN_APPEAL_REQUEST_V1"),
                        uint16(1),
                        p.artistId,
                        p.newAddress,
                        p.vestedAuthorityClass,
                        p.expectedCauseHash,
                        p.expectedResolutionHash,
                        bytes32(0),
                        p.reasonHash,
                        p.supersededRecordHashes
                    )
                )
        );
        p.expectedResolutionHash = bytes32(uint256(11));
        require(A.requestCommitment(p) != original);
        p = _request();
        p.newAddress = address(0x5678);
        require(A.requestCommitment(p) != original);
        p = _request();
        p.reasonHash = bytes32(uint256(12));
        require(A.requestCommitment(p) != original);
        p = _request();
        p.supersededRecordHashes[0] = bytes32(uint256(13));
        require(A.requestCommitment(p) != original);
    }
}
