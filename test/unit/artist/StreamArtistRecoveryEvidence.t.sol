// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    StreamArtistRecoveryEvidence
} from "../../../smart-contracts/domains/artist/StreamArtistRecoveryEvidence.sol";
import {
    StreamArtistRecoveryEvidenceDeployment
} from "../../../smart-contracts/domains/artist/StreamArtistRecoveryEvidenceDeployment.sol";
import {
    StreamArtistRecoveryEvidenceTypes as E
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistRecoveryEvidenceTypes.sol";
import {
    StreamArtistGuardianAppealTypes as Appeal
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistGuardianAppealTypes.sol";
import {
    StreamArtistIdentityRecoveryOperationTypes as Recovery
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistIdentityRecoveryOperationTypes.sol";

interface RecoveryEvidenceVm {
    function chainId(uint256 value) external;
    function etch(address target, bytes calldata code) external;
}

contract RecoveryEvidenceFutureOwner {
    address public immutable evidence;

    constructor() {
        require(address(this).code.length == 0, "owner is still constructing");
        evidence = StreamArtistRecoveryEvidenceDeployment.deploy(
            address(this), address(2), address(3), address(4), address(5), address(6)
        );
    }
}

contract RecoveryEvidencePublisherCaller {
    function publish(StreamArtistRecoveryEvidence publisher, E.ResolutionManifest calldata m)
        external
        returns (bytes32)
    {
        return publisher.publishResolutionManifest(m);
    }
}

/// @notice Exact content domains and publication grammar; no simulated semantic admission.
/// @dev Synthetic references deliberately need no actual Artist, Contest, vesting or governance.
contract StreamArtistRecoveryEvidenceTest {
    RecoveryEvidenceVm private constant vm =
        RecoveryEvidenceVm(address(uint160(uint256(keccak256("hevm cheat code")))));
    StreamArtistRecoveryEvidence private publisher;

    function setUp() public {
        publisher = new StreamArtistRecoveryEvidence(
            address(this), address(2), address(3), address(4), address(5), address(6)
        );
    }

    function _manifest() private pure returns (E.ResolutionManifest memory m) {
        m.artistId = bytes32(uint256(1));
        m.ownerRevision = 7;
        m.causeHash = bytes32(uint256(2));
        m.resolutionHash = bytes32(uint256(3));
        m.executedHead = bytes32(uint256(4));
        m.basis = E.VestingBasis.DECLARED_VESTINGS;
        m.requestCommitment = bytes32(uint256(5));
        m.resolutionEvidenceHash = bytes32(uint256(6));
        m.contestedVestings = new E.VestingReference[](2);
        // Chronological references are intentionally not sorted by their hash values.
        m.contestedVestings[0] = E.VestingReference(bytes32(uint256(9)), bytes32(uint256(19)));
        m.contestedVestings[1] = E.VestingReference(bytes32(uint256(4)), bytes32(uint256(14)));
        m.supersededRecordHashes = new bytes32[](2);
        m.supersededRecordHashes[0] = bytes32(uint256(11));
        m.supersededRecordHashes[1] = bytes32(uint256(12));
    }

    function _appeal(bytes32 manifest) private pure returns (E.AppealDocumentV2 memory d) {
        d.resolutionManifestHash = manifest;
        d.hostileFindingsHash = keccak256("original hostile findings content");
        d.findings = new Appeal.Finding[](2);
        for (uint256 i; i < 2; ++i) {
            d.findings[i] = Appeal.Finding(bytes32(uint256(11 + i)), new address[](2));
            d.findings[i].parties[0] = address(0x10);
            d.findings[i].parties[1] = address(0x20);
        }
    }

    function _expectedManifest(E.ResolutionManifest memory m, address owner, bytes32 code)
        private
        view
        returns (bytes32)
    {
        return keccak256(
            abi.encode(
                keccak256("6529STREAM_ARTIST_RECOVERY_RESOLUTION_MANIFEST_V1"),
                uint16(1),
                block.chainid,
                address(2),
                owner,
                code,
                address(3),
                address(4),
                address(5),
                address(6),
                m
            )
        );
    }

    function _rejectManifest(E.ResolutionManifest memory m) private {
        (bool ok,) =
            address(publisher).call(abi.encodeCall(publisher.publishResolutionManifest, (m)));
        require(!ok, "malformed manifest rejected");
    }

    function _rejectAppeal(E.AppealDocumentV2 memory d) private {
        (bool ok,) = address(publisher).call(abi.encodeCall(publisher.publishAppealV2, (d)));
        require(!ok, "malformed appeal rejected");
    }

    function testManifestLiteralDomainEnvironmentAndExactImmutableReadback() public {
        E.ResolutionManifest memory m = _manifest();
        bytes32 hash = publisher.publishResolutionManifest(m);
        require(hash == _expectedManifest(m, address(this), address(this).codehash));
        (E.ResolutionManifest memory saved, bytes32 observed) = publisher.resolutionManifest(hash);
        require(
            keccak256(abi.encode(saved)) == keccak256(abi.encode(m))
                && observed == address(this).codehash,
            "every field and original reference order retained"
        );
        require(publisher.publishResolutionManifest(m) == hash, "same publication is idempotent");
        m.resolutionEvidenceHash = keccak256("different resolution evidence");
        bytes32 changed = publisher.publishResolutionManifest(m);
        require(changed != hash, "opaque resolution evidence is committed");
        (saved,) = publisher.resolutionManifest(hash);
        require(saved.resolutionEvidenceHash == bytes32(uint256(6)), "old manifest retained");
        m = _manifest();
        E.VestingReference memory first = m.contestedVestings[0];
        m.contestedVestings[0] = m.contestedVestings[1];
        m.contestedVestings[1] = first;
        require(
            publisher.publishResolutionManifest(m) != hash,
            "order changes identity; original ancestry admission owns its validity"
        );
        require(
            publisher.owner() == address(this) && publisher.artistRegistry() == address(2)
                && publisher.coordinator() == address(3) && publisher.archive() == address(4)
                && publisher.core() == address(5) && publisher.mintManager() == address(6)
                && publisher.deploymentChainId() == block.chainid,
            "all immutable environment getters"
        );
    }

    function testNoContestedVestingAllowsRealAncestryOrGenuinelyZeroExecution() public {
        E.ResolutionManifest memory m = _manifest();
        m.basis = E.VestingBasis.NO_CONTESTED_VESTING;
        m.contestedVestings = new E.VestingReference[](0);
        bytes32 nonzeroHead = publisher.publishResolutionManifest(m);
        m.executedHead = 0;
        m.resolutionHash = 0;
        m.supersededRecordHashes = new bytes32[](0);
        bytes32 zeroHead = publisher.publishResolutionManifest(m);
        require(nonzeroHead != zeroHead, "NONE never silently replaces the actual execution head");
        (E.ResolutionManifest memory saved,) = publisher.resolutionManifest(nonzeroHead);
        require(saved.executedHead == bytes32(uint256(4)) && saved.contestedVestings.length == 0);
    }

    function testPublicationIsPermissionlessAndDoesNotRequireSyntheticAuthorityRecords() public {
        RecoveryEvidencePublisherCaller caller = new RecoveryEvidencePublisherCaller();
        E.ResolutionManifest memory m = _manifest();
        bytes32 hash = caller.publish(publisher, m);
        require(hash == _expectedManifest(m, address(this), address(this).codehash));
        // Shape-only publication also permits the appeal to be retained before its manifest.
        E.AppealDocumentV2 memory d = _appeal(keccak256("not yet published manifest"));
        require(publisher.publishAppealV2(d) != 0, "publication does not pretend to adjudicate");
    }

    function testManifestRequiredFieldsAndBasisShapeReject() public {
        for (uint256 fault; fault < 8; ++fault) {
            E.ResolutionManifest memory m = _manifest();
            if (fault == 0) m.artistId = 0;
            if (fault == 1) m.ownerRevision = 0;
            if (fault == 2) m.causeHash = 0;
            if (fault == 3) m.requestCommitment = 0;
            if (fault == 4) m.resolutionEvidenceHash = 0;
            if (fault == 5) m.executedHead = 0;
            if (fault == 6) m.contestedVestings = new E.VestingReference[](0);
            if (fault == 7) m.basis = E.VestingBasis.NO_CONTESTED_VESTING;
            _rejectManifest(m);
        }
    }

    function testManifestZeroDuplicateReferencesAndUnsortedSupersessionsReject() public {
        for (uint256 fault; fault < 7; ++fault) {
            E.ResolutionManifest memory m = _manifest();
            if (fault == 0) m.contestedVestings[0].transitionRecordHash = 0;
            if (fault == 1) m.contestedVestings[0].vestingCommitment = 0;
            if (fault == 2) {
                m.contestedVestings[1].transitionRecordHash =
                m.contestedVestings[0].transitionRecordHash;
            }
            if (fault == 3) {
                m.contestedVestings[1].vestingCommitment = m.contestedVestings[0].vestingCommitment;
            }
            if (fault == 4) m.supersededRecordHashes[0] = 0;
            if (fault == 5) m.supersededRecordHashes[1] = m.supersededRecordHashes[0];
            if (fault == 6) m.supersededRecordHashes[0] = bytes32(uint256(13));
            _rejectManifest(m);
        }
    }

    function testDeclaredReferenceAndSupersessionPublicationBounds() public {
        E.ResolutionManifest memory m = _manifest();
        m.contestedVestings = new E.VestingReference[](64);
        m.supersededRecordHashes = new bytes32[](64);
        for (uint256 i; i < 64; ++i) {
            m.contestedVestings[i] = E.VestingReference(bytes32(i + 1), bytes32(i + 101));
            m.supersededRecordHashes[i] = bytes32(i + 201);
        }
        require(publisher.publishResolutionManifest(m) != 0, "64-reference evidence profile");
        m.contestedVestings = new E.VestingReference[](65);
        _rejectManifest(m);
        m = _manifest();
        m.supersededRecordHashes = new bytes32[](65);
        _rejectManifest(m);
    }

    function testAppealLiteralDomainAndImmutableFindingsWithoutInventedContest() public {
        E.AppealDocumentV2 memory d = _appeal(publisher.publishResolutionManifest(_manifest()));
        bytes32 hash = publisher.publishAppealV2(d);
        require(
            hash
                == keccak256(
                    abi.encode(
                        keccak256("6529STREAM_ARTIST_HOSTILE_GUARDIAN_EVIDENCE_V2"),
                        uint16(2),
                        block.chainid,
                        address(2),
                        address(this),
                        d
                    )
                ),
            "literal approved appeal domain"
        );
        (E.AppealDocumentV2 memory saved, bytes32 observed) = publisher.appealEvidenceV2(hash);
        require(
            keccak256(abi.encode(saved)) == keccak256(abi.encode(d))
                && observed == address(this).codehash
        );
        require(publisher.publishAppealV2(d) == hash);
        d.findings[0].parties[1] = address(0x30);
        require(publisher.publishAppealV2(d) != hash);
        (saved,) = publisher.appealEvidenceV2(hash);
        require(saved.findings[0].parties[1] == address(0x20), "original hostile parties retained");
    }

    function testAppealShapeRejectsMissingDuplicateUnsortedAndOversizedFindings() public {
        for (uint256 fault; fault < 10; ++fault) {
            E.AppealDocumentV2 memory d = _appeal(bytes32(uint256(1)));
            if (fault == 0) d.resolutionManifestHash = 0;
            if (fault == 1) d.hostileFindingsHash = 0;
            if (fault == 2) d.findings = new Appeal.Finding[](0);
            if (fault == 3) d.findings = new Appeal.Finding[](65);
            if (fault == 4) d.findings[1].guardianRecordHash = d.findings[0].guardianRecordHash;
            if (fault == 5) d.findings[0].guardianRecordHash = bytes32(uint256(13));
            if (fault == 6) d.findings[0].parties = new address[](0);
            if (fault == 7) d.findings[0].parties = new address[](9);
            if (fault == 8) d.findings[0].parties[1] = d.findings[0].parties[0];
            if (fault == 9) d.findings[0].parties[0] = address(0x30);
            _rejectAppeal(d);
        }
    }

    function testFutureOwnerDeploymentUnknownReadsAndLiveOwnerRequirement() public {
        RecoveryEvidenceFutureOwner future = new RecoveryEvidenceFutureOwner();
        StreamArtistRecoveryEvidence nested = StreamArtistRecoveryEvidence(future.evidence());
        E.ResolutionManifest memory m = _manifest();
        require(
            nested.publishResolutionManifest(m)
                == _expectedManifest(m, address(future), address(future).codehash),
            "linked constructor deployment captured the future host"
        );
        (bool ok,) =
            address(nested).staticcall(abi.encodeCall(nested.resolutionManifest, (bytes32(0))));
        require(!ok, "unknown manifest is not empty evidence");
        (ok,) = address(nested).staticcall(abi.encodeCall(nested.appealEvidenceV2, (bytes32(0))));
        require(!ok, "unknown appeal is not empty evidence");
        nested = new StreamArtistRecoveryEvidence(
            address(0xBAD), address(2), address(3), address(4), address(5), address(6)
        );
        (ok,) = address(nested).call(abi.encodeCall(nested.publishResolutionManifest, (m)));
        require(!ok, "unfinished or missing owner cannot publish");
    }

    function testChainAndChangedOwnerCodeDoNotRewriteRetainedEvidence() public {
        RecoveryEvidenceFutureOwner future = new RecoveryEvidenceFutureOwner();
        StreamArtistRecoveryEvidence nested = StreamArtistRecoveryEvidence(future.evidence());
        E.ResolutionManifest memory m = _manifest();
        bytes32 hash = nested.publishResolutionManifest(m);
        E.AppealDocumentV2 memory d = _appeal(hash);
        bytes32 appeal = nested.publishAppealV2(d);
        bytes32 originalCode = address(future).codehash;
        uint256 originalChain = block.chainid;
        vm.chainId(originalChain + 1);
        (bool ok,) = address(nested).call(abi.encodeCall(nested.publishResolutionManifest, (m)));
        require(!ok, "wrong chain rejects publication");
        vm.chainId(originalChain);
        vm.etch(address(future), hex"60006000f3");
        require(
            nested.publishResolutionManifest(m) != hash, "owner runtime enters manifest identity"
        );
        (ok,) = address(nested).call(abi.encodeCall(nested.publishAppealV2, (d)));
        require(!ok, "same appeal cannot overwrite observed owner code");
        (, bytes32 observed) = nested.resolutionManifest(hash);
        require(observed == originalCode);
        (, observed) = nested.appealEvidenceV2(appeal);
        require(observed == originalCode, "old immutable evidence remains independently readable");
    }

    function testFuzzRequestCommitmentPreservesOriginalOmittedEvidenceWord(bytes32 evidence)
        public
        pure
    {
        Recovery.Request memory p = Recovery.Request(
            bytes32(uint256(1)),
            address(2),
            1,
            bytes32(uint256(3)),
            bytes32(0),
            evidence,
            bytes32(uint256(4)),
            new bytes32[](0)
        );
        bytes32 expected = keccak256(
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
        );
        require(E.requestCommitment(p) == expected && Appeal.requestCommitment(p) == expected);
        p.evidenceHash = ~evidence;
        require(E.requestCommitment(p) == expected);
        p.expectedCauseHash = bytes32(uint256(5));
        require(E.requestCommitment(p) != expected, "only the resulting evidence word is omitted");
    }
}
