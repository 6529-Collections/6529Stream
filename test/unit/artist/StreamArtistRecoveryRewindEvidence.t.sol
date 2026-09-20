// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    StreamArtistRecoveryRewindEvidence
} from "../../../smart-contracts/domains/artist/StreamArtistRecoveryRewindEvidence.sol";
import {
    StreamArtistRecoveryRewindEvidenceDeployment
} from "../../../smart-contracts/domains/artist/StreamArtistRecoveryRewindEvidenceDeployment.sol";
import {
    StreamArtistRecoveryRewindTypes as W
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistRecoveryRewindTypes.sol";
import {
    StreamArtistRecoveryEvidenceTypes as E
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistRecoveryEvidenceTypes.sol";
import {
    StreamArtistOnboardingTypes as T
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistOnboardingTypes.sol";
import {
    StreamArtistGuardianAppealTypes as Appeal
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistGuardianAppealTypes.sol";
import {
    StreamArtistIdentityRecoveryOperationTypes as Recovery
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistIdentityRecoveryOperationTypes.sol";

interface RewindEvidenceVm {
    struct Log {
        bytes32[] topics;
        bytes data;
        address emitter;
    }
    function chainId(uint256 value) external;
    function etch(address target, bytes calldata code) external;
    function recordLogs() external;
    function getRecordedLogs() external returns (Log[] memory);
}

contract RewindEvidenceBoundaryStub { }

/// @dev Mutable test boundary permits explicit suite-corruption controls; this is not a real Coordinator.
contract RewindEvidenceCoordinatorStub {
    uint256 public immutable deploymentChainId = block.chainid;
    T.SuiteConfiguration private _suite;

    function setSuite(T.SuiteConfiguration calldata suite) external {
        _suite = suite;
    }

    function suiteConfiguration() external view returns (T.SuiteConfiguration memory) {
        return _suite;
    }
}

/// @dev Only deployment getters used by the publisher; no Artist records or admission are simulated.
contract RewindEvidenceOwnerStub {
    uint256 public immutable deploymentChainId = block.chainid;
    address public immutable artistRegistry;
    address public immutable operationCoordinator;
    address public immutable archiveV2;
    address public immutable core;
    address public immutable mintManager;
    bytes32 public immutable domainId;

    constructor(
        address registry,
        address coordinator,
        address archive,
        address core_,
        address manager,
        bytes32 domain
    ) {
        artistRegistry = registry;
        operationCoordinator = coordinator;
        archiveV2 = archive;
        core = core_;
        mintManager = manager;
        domainId = domain;
    }
}

contract RewindEvidenceOwnerVariant is RewindEvidenceOwnerStub {
    constructor(
        address registry,
        address coordinator,
        address archive,
        address core_,
        address manager,
        bytes32 domain
    ) RewindEvidenceOwnerStub(registry, coordinator, archive, core_, manager, domain) { }

    function distinctRuntime() external pure returns (uint256) {
        return 1;
    }
}

contract RewindEvidenceConstructingOwner is RewindEvidenceOwnerStub {
    address public immutable publisher;

    constructor(
        address registry,
        address coordinator,
        address archive,
        address core_,
        address manager
    )
        RewindEvidenceOwnerStub(
            registry, coordinator, archive, core_, manager, keccak256("domain:identity_authority")
        )
    {
        require(address(this).code.length == 0, "future owner has no runtime yet");
        publisher = StreamArtistRecoveryRewindEvidenceDeployment.deploy(
            address(this), registry, coordinator, archive, core_, manager
        );
    }
}

contract RewindEvidencePermissionlessCaller {
    function publish(
        StreamArtistRecoveryRewindEvidence publisher,
        W.ResolutionManifestV3 calldata m
    ) external returns (bytes32) {
        return publisher.publishResolutionManifestV3(m);
    }
}

/// @notice Publisher grammar, literal domains and fixed-suite bindings only.
/// @dev Synthetic manifests and deployment stubs do not claim original semantic admission.
contract StreamArtistRecoveryRewindEvidenceTest {
    RewindEvidenceVm private constant vm =
        RewindEvidenceVm(address(uint160(uint256(keccak256("hevm cheat code")))));
    address private registry;
    address private archive;
    address private core;
    address private manager;
    RewindEvidenceCoordinatorStub private coordinator;
    RewindEvidenceOwnerStub private identity;
    RewindEvidenceOwnerStub private payout;
    StreamArtistRecoveryRewindEvidence private publisher;

    function setUp() public {
        registry = address(new RewindEvidenceBoundaryStub());
        archive = address(new RewindEvidenceBoundaryStub());
        core = address(new RewindEvidenceBoundaryStub());
        manager = address(new RewindEvidenceBoundaryStub());
        coordinator = new RewindEvidenceCoordinatorStub();
        identity = _owner(keccak256("domain:identity_authority"));
        payout = _owner(keccak256("domain:payout_lifecycle"));
        coordinator.setSuite(_suite());
        publisher = new StreamArtistRecoveryRewindEvidence(
            address(identity), registry, address(coordinator), archive, core, manager
        );
    }

    function _owner(bytes32 domain) private returns (RewindEvidenceOwnerStub) {
        return new RewindEvidenceOwnerStub(
            registry, address(coordinator), archive, core, manager, domain
        );
    }

    function _suite() private view returns (T.SuiteConfiguration memory s) {
        s.registry = registry;
        s.archive = archive;
        s.core = core;
        s.mintManager = manager;
        s.owners[2] = address(identity);
        s.owners[5] = address(payout);
    }

    function _environment() private view returns (W.EnvironmentV3 memory) {
        return W.EnvironmentV3(
            block.chainid,
            registry,
            address(identity),
            address(identity).codehash,
            address(payout),
            address(payout).codehash,
            address(coordinator),
            archive,
            core,
            manager
        );
    }

    function _manifest() private pure returns (W.ResolutionManifestV3 memory m) {
        m.artistId = bytes32(uint256(1));
        m.identity = W.ReceiptPrefix(
            T.Snapshot(
                keccak256("domain:identity_authority"), 8, bytes32(uint256(2)), bytes32(uint256(3))
            ),
            17
        );
        m.payout = W.ReceiptPrefix(
            T.Snapshot(
                keccak256("domain:payout_lifecycle"), 0, bytes32(uint256(4)), bytes32(uint256(5))
            ),
            0
        );
        m.causeHash = bytes32(uint256(6));
        m.resolutionHash = bytes32(uint256(7));
        m.executedHead = bytes32(uint256(8));
        m.basis = E.VestingBasis.DECLARED_VESTINGS;
        m.requestCommitment = bytes32(uint256(9));
        m.resolutionEvidenceHash = bytes32(uint256(10));
        m.contestedVestings = new E.VestingReference[](2);
        m.contestedVestings[0] = E.VestingReference(bytes32(uint256(19)), bytes32(uint256(29)));
        m.contestedVestings[1] = E.VestingReference(bytes32(uint256(18)), bytes32(uint256(28)));
        m.supersededRecords = new W.RecordReference[](7);
        // Record hashes are sorted; kinds deliberately are not.
        for (uint256 i; i < 7; ++i) {
            m.supersededRecords[i] = W.RecordReference(W.RecordKind(6 - i), bytes32(100 + i));
        }
    }

    function _appeal() private pure returns (W.AppealDocumentV3 memory d) {
        d.resolutionManifestHash = bytes32(uint256(1));
        d.hostileFindingsHash = bytes32(uint256(2));
        d.findings = new Appeal.Finding[](2);
        for (uint256 i; i < 2; ++i) {
            d.findings[i] = Appeal.Finding(bytes32(10 + i), new address[](2));
            d.findings[i].parties[0] = address(0x10);
            d.findings[i].parties[1] = address(0x20);
        }
    }

    function _payout(uint8 authorityClass) private view returns (W.PayoutOriginalV3 memory p) {
        p.terms = T.PayoutDesignation(bytes32(uint256(1)), address(0x123), bytes32(uint256(44)));
        p.signer = address(0x456);
        p.authorityClass = authorityClass;
        p.nonce = type(uint256).max - 1;
        p.signedAt = 1;
        p.recordHash = keccak256(
            abi.encode(
                keccak256("6529STREAM_ARTIST_PAYOUT_DESIGNATION_RECORD_V1"),
                block.chainid,
                registry,
                p.terms.artistId,
                p.terms.payoutAccount,
                p.terms.previousDesignationRecordHash,
                p.signer,
                p.authorityClass,
                p.nonce,
                p.signedAt
            )
        );
    }

    function _rejectManifest(W.ResolutionManifestV3 memory m) private {
        (bool ok,) =
            address(publisher).call(abi.encodeCall(publisher.publishResolutionManifestV3, (m)));
        require(!ok, "invalid manifest rejected");
    }

    function _rejectAppeal(W.AppealDocumentV3 memory d) private {
        (bool ok,) = address(publisher).call(abi.encodeCall(publisher.publishAppealV3, (d)));
        require(!ok, "invalid appeal rejected");
    }

    function testRewindManifestLiteralDomainAllKindsAndExactReadback() public {
        W.ResolutionManifestV3 memory m = _manifest();
        vm.recordLogs();
        bytes32 hash = publisher.publishResolutionManifestV3(m);
        RewindEvidenceVm.Log[] memory logs = vm.getRecordedLogs();
        require(
            hash
                == keccak256(
                    abi.encode(
                        keccak256("6529STREAM_ARTIST_RECOVERY_RESOLUTION_MANIFEST_V3"),
                        uint16(3),
                        _environment(),
                        m
                    )
                ),
            "literal V3 environment and complete tuple"
        );
        (W.ResolutionManifestV3 memory saved, bytes32 ic, bytes32 pc) =
            publisher.resolutionManifestV3(hash);
        require(
            keccak256(abi.encode(saved)) == keccak256(abi.encode(m)), "all fields/order retained"
        );
        require(
            ic == address(identity).codehash && pc == address(payout).codehash, "both pins retained"
        );
        require(logs.length == 1 && logs[0].emitter == address(publisher), "one evidence event");
        require(
            logs[0].topics[0]
                == keccak256(
                    "RecoveryRewindManifestPublished(bytes32,bytes32,bytes32,bytes32,bytes32)"
                )
        );
        require(
            logs[0].topics[1] == hash && logs[0].topics[2] == m.artistId
                && logs[0].topics[3] == m.causeHash
        );
        require(publisher.publishResolutionManifestV3(m) == hash, "idempotent publication");
        m.payout.receiptCount = 1;
        require(publisher.publishResolutionManifestV3(m) != hash, "complete payout prefix bound");
        (saved,,) = publisher.resolutionManifestV3(hash);
        require(saved.payout.receiptCount == 0, "original remains exact");
    }

    function testRewindNoneAllowsRealAncestryAndExplicitEmptySelection() public {
        W.ResolutionManifestV3 memory m = _manifest();
        m.basis = E.VestingBasis.NO_CONTESTED_VESTING;
        m.contestedVestings = new E.VestingReference[](0);
        bytes32 retainedHead = publisher.publishResolutionManifestV3(m);
        m.executedHead = 0;
        m.resolutionHash = 0;
        m.supersededRecords = new W.RecordReference[](0);
        require(
            publisher.publishResolutionManifestV3(m) != retainedHead,
            "NONE never fabricates zero ancestry"
        );
        require(publisher.payoutOwner() == address(payout), "payout derives from suite5");
    }

    function testRewindPermissionlessShapeDoesNotClaimSemanticAdmission() public {
        RewindEvidencePermissionlessCaller caller = new RewindEvidencePermissionlessCaller();
        bytes32 hash = caller.publish(publisher, _manifest());
        require(
            hash != 0 && publisher.publishAppealV3(_appeal()) != 0,
            "no synthetic governance or Artist records required"
        );
        W.ResolutionManifestV3 memory m = _manifest();
        E.VestingReference memory first = m.contestedVestings[0];
        m.contestedVestings[0] = m.contestedVestings[1];
        m.contestedVestings[1] = first;
        require(
            publisher.publishResolutionManifestV3(m) != hash,
            "ancestry validator, not publisher, decides chronology"
        );
    }

    function testRewindManifestMissingFieldsAndWrongSnapshotDomainsReject() public {
        for (uint256 fault; fault < 14; ++fault) {
            W.ResolutionManifestV3 memory m = _manifest();
            if (fault == 0) m.artistId = 0;
            if (fault == 1) m.causeHash = 0;
            if (fault == 2) m.requestCommitment = 0;
            if (fault == 3) m.resolutionEvidenceHash = 0;
            if (fault == 4) m.identity.snapshot.revision = 0;
            if (fault == 5) m.identity.snapshot.domainId = m.payout.snapshot.domainId;
            if (fault == 6) m.payout.snapshot.domainId = m.identity.snapshot.domainId;
            if (fault == 7) m.identity.snapshot.stateRoot = 0;
            if (fault == 8) m.identity.snapshot.recordChainTip = 0;
            if (fault == 9) m.payout.snapshot.stateRoot = 0;
            if (fault == 10) m.payout.snapshot.recordChainTip = 0;
            if (fault == 11) m.executedHead = 0;
            if (fault == 12) m.contestedVestings = new E.VestingReference[](0);
            if (fault == 13) m.basis = E.VestingBasis.NO_CONTESTED_VESTING;
            _rejectManifest(m);
        }
    }

    function testRewindManifestDuplicatesOrderingAndPublicationBoundsReject() public {
        for (uint256 fault; fault < 9; ++fault) {
            W.ResolutionManifestV3 memory m = _manifest();
            if (fault == 0) m.contestedVestings[0].transitionRecordHash = 0;
            if (fault == 1) m.contestedVestings[0].vestingCommitment = 0;
            if (fault == 2) {
                m.contestedVestings[1].transitionRecordHash =
                m.contestedVestings[0].transitionRecordHash;
            }
            if (fault == 3) {
                m.contestedVestings[1].vestingCommitment = m.contestedVestings[0].vestingCommitment;
            }
            if (fault == 4) m.supersededRecords[0].recordHash = 0;
            if (fault == 5) m.supersededRecords[1].recordHash = m.supersededRecords[0].recordHash;
            if (fault == 6) m.supersededRecords[0].recordHash = bytes32(uint256(200));
            if (fault == 7) m.supersededRecords = new W.RecordReference[](65);
            if (fault == 8) m.contestedVestings = new E.VestingReference[](65);
            _rejectManifest(m);
        }
        W.ResolutionManifestV3 memory largest = _manifest();
        largest.contestedVestings = new E.VestingReference[](64);
        largest.supersededRecords = new W.RecordReference[](64);
        for (uint256 i; i < 64; ++i) {
            largest.contestedVestings[i] = E.VestingReference(bytes32(i + 1), bytes32(i + 101));
            largest.supersededRecords[i] = W.RecordReference(W.RecordKind(i % 7), bytes32(i + 201));
        }
        require(
            publisher.publishResolutionManifestV3(largest) != 0, "bounded64 evidence is accepted"
        );
    }

    function testRewindAppealLiteralDomainPinsAndImmutableFindings() public {
        W.AppealDocumentV3 memory d = _appeal();
        bytes32 hash = publisher.publishAppealV3(d);
        require(
            hash
                == keccak256(
                    abi.encode(
                        keccak256("6529STREAM_ARTIST_HOSTILE_GUARDIAN_EVIDENCE_V3"),
                        uint16(3),
                        _environment(),
                        d
                    )
                )
        );
        (W.AppealDocumentV3 memory saved, bytes32 ic, bytes32 pc) = publisher.appealEvidenceV3(hash);
        require(keccak256(abi.encode(saved)) == keccak256(abi.encode(d)));
        require(ic == address(identity).codehash && pc == address(payout).codehash);
        require(publisher.publishAppealV3(d) == hash);
        d.findings[0].parties[1] = address(0x30);
        require(publisher.publishAppealV3(d) != hash);
        (saved,,) = publisher.appealEvidenceV3(hash);
        require(saved.findings[0].parties[1] == address(0x20));
    }

    function testRewindAppealShapeRejectsMissingDuplicateAndUnsortedFindings() public {
        for (uint256 fault; fault < 11; ++fault) {
            W.AppealDocumentV3 memory d = _appeal();
            if (fault == 0) d.resolutionManifestHash = 0;
            if (fault == 1) d.hostileFindingsHash = 0;
            if (fault == 2) d.findings = new Appeal.Finding[](0);
            if (fault == 3) d.findings = new Appeal.Finding[](65);
            if (fault == 4) d.findings[0].guardianRecordHash = 0;
            if (fault == 5) d.findings[1].guardianRecordHash = d.findings[0].guardianRecordHash;
            if (fault == 6) d.findings[0].guardianRecordHash = bytes32(uint256(100));
            if (fault == 7) d.findings[0].parties = new address[](0);
            if (fault == 8) d.findings[0].parties = new address[](9);
            if (fault == 9) d.findings[0].parties[1] = d.findings[0].parties[0];
            if (fault == 10) d.findings[0].parties[0] = address(0x30);
            _rejectAppeal(d);
        }
    }

    function testRewindPayoutLiteralOriginalClass1And3AndExactFullWidthNonce() public {
        for (uint8 authorityClass = 1; authorityClass <= 3; authorityClass += 2) {
            W.PayoutOriginalV3 memory p = _payout(authorityClass);
            bytes32 hash = publisher.publishPayoutOriginalV3(p);
            require(
                hash
                    == keccak256(
                        abi.encode(
                            keccak256("6529STREAM_ARTIST_RECOVERY_PAYOUT_ORIGINAL_V3"),
                            uint16(3),
                            _environment(),
                            p
                        )
                    ),
                "evidence binds exact original canonical preimage"
            );
            (W.PayoutOriginalV3 memory saved, bytes32 found, bytes32 ic, bytes32 pc) =
                publisher.payoutOriginalV3(p.recordHash);
            require(found == hash && keccak256(abi.encode(saved)) == keccak256(abi.encode(p)));
            require(ic == address(identity).codehash && pc == address(payout).codehash);
            require(publisher.publishPayoutOriginalV3(p) == hash);
        }
    }

    function testRewindPayoutSubstitutionCannotPoisonOriginalRecordKey() public {
        W.PayoutOriginalV3 memory original = _payout(3);
        for (uint256 fault; fault < 10; ++fault) {
            W.PayoutOriginalV3 memory p = _payout(3);
            if (fault == 0) p.recordHash = 0;
            if (fault == 1) p.terms.artistId = 0;
            if (fault == 2) p.terms.payoutAccount = address(0);
            if (fault == 3) p.terms.previousDesignationRecordHash = 0;
            if (fault == 4) p.signer = address(0);
            if (fault == 5) p.signer = address(0x789);
            if (fault == 6) p.authorityClass = 1;
            if (fault == 7) p.authorityClass = 4;
            if (fault == 8) p.nonce = 1;
            if (fault == 9) p.signedAt = 2;
            (bool ok,) =
                address(publisher).call(abi.encodeCall(publisher.publishPayoutOriginalV3, (p)));
            require(!ok, "wrong preimage fails before key retention");
        }
        (bool exists,) = address(publisher)
            .staticcall(abi.encodeCall(publisher.payoutOriginalV3, (original.recordHash)));
        require(!exists, "failed publications leave no record");
        require(
            publisher.publishPayoutOriginalV3(original) != 0,
            "identical genuine preimage publishes afterward"
        );
    }

    function testRewindFutureOwnerWaitsForInitializedOriginalSuite() public {
        RewindEvidenceCoordinatorStub later = new RewindEvidenceCoordinatorStub();
        RewindEvidenceConstructingOwner future =
            new RewindEvidenceConstructingOwner(registry, address(later), archive, core, manager);
        StreamArtistRecoveryRewindEvidence nested =
            StreamArtistRecoveryRewindEvidence(future.publisher());
        (bool ok,) =
            address(nested).call(abi.encodeCall(nested.publishResolutionManifestV3, (_manifest())));
        require(!ok, "no invented payout during partial deployment");
        RewindEvidenceOwnerStub futurePayout = new RewindEvidenceOwnerStub(
            registry, address(later), archive, core, manager, keccak256("domain:payout_lifecycle")
        );
        T.SuiteConfiguration memory s = _suite();
        s.owners[2] = address(future);
        s.owners[5] = address(futurePayout);
        later.setSuite(s);
        require(
            nested.publishResolutionManifestV3(_manifest()) != 0,
            "publisher made during owner construction becomes usable"
        );
        require(nested.payoutOwner() == address(futurePayout), "actual late suite5 chosen");
    }

    function testRewindWrongSuiteAndOwnerBindingsRejectWithHealthyRetry() public {
        for (uint256 fault; fault < 8; ++fault) {
            T.SuiteConfiguration memory s = _suite();
            if (fault == 0) s.registry = archive;
            if (fault == 1) s.archive = registry;
            if (fault == 2) s.core = manager;
            if (fault == 3) s.mintManager = core;
            if (fault == 4) s.owners[2] = address(payout);
            if (fault == 5) s.owners[5] = address(identity);
            if (fault == 6) s.owners[5] = address(0xBAD);
            if (fault == 7) s.owners[5] = address(_owner(keccak256("wrong domain")));
            coordinator.setSuite(s);
            _rejectManifest(_manifest());
        }
        coordinator.setSuite(_suite());
        require(publisher.publishResolutionManifestV3(_manifest()) != 0);
    }

    function testRewindPublishedOwnerRuntimePinsAndChainRejectDrift() public {
        bytes32 manifest = publisher.publishResolutionManifestV3(_manifest());
        W.PayoutOriginalV3 memory p = _payout(1);
        publisher.publishPayoutOriginalV3(p);
        bytes memory originalCode = address(payout).code;
        RewindEvidenceOwnerVariant variant = new RewindEvidenceOwnerVariant(
            registry,
            address(coordinator),
            archive,
            core,
            manager,
            keccak256("domain:payout_lifecycle")
        );
        vm.etch(address(payout), address(variant).code);
        (bool ok,) = address(publisher)
            .staticcall(abi.encodeCall(publisher.resolutionManifestV3, (manifest)));
        require(!ok, "same getters cannot replace captured payout runtime");
        (ok,) = address(publisher).call(abi.encodeCall(publisher.publishPayoutOriginalV3, (p)));
        require(!ok, "existing payout witness cannot be repinned");
        vm.etch(address(payout), originalCode);
        publisher.resolutionManifestV3(manifest);
        uint256 originalChain = block.chainid;
        vm.chainId(originalChain + 1);
        _rejectManifest(_manifest());
        vm.chainId(originalChain);
        require(
            publisher.publishResolutionManifestV3(_manifest()) == manifest,
            "exact restoration and retry"
        );
    }

    function testRewindUnknownEvidenceIsNotAnEmptySuccessfulPublication() public {
        (bool ok,) = address(publisher)
            .staticcall(abi.encodeCall(publisher.resolutionManifestV3, (bytes32(0))));
        require(!ok);
        (ok,) =
            address(publisher).staticcall(abi.encodeCall(publisher.appealEvidenceV3, (bytes32(0))));
        require(!ok);
        (ok,) =
            address(publisher).staticcall(abi.encodeCall(publisher.payoutOriginalV3, (bytes32(0))));
        require(!ok);
    }

    function testRewindEqualRuntimeCannotSubstituteOriginalPayoutAddress() public {
        bytes32 hash = publisher.publishResolutionManifestV3(_manifest());
        RewindEvidenceOwnerStub other = _owner(keccak256("domain:payout_lifecycle"));
        require(
            address(other).codehash == address(payout).codehash, "same code and immutable arguments"
        );
        T.SuiteConfiguration memory s = _suite();
        s.owners[5] = address(other);
        coordinator.setSuite(s);
        (bool ok,) =
            address(publisher).staticcall(abi.encodeCall(publisher.resolutionManifestV3, (hash)));
        require(!ok, "full environment pins the original address too");
        coordinator.setSuite(_suite());
        publisher.resolutionManifestV3(hash);
    }

    function testRewindOriginalRequestCommitmentOmitsOnlyAppealEvidence() public pure {
        Recovery.Request memory request;
        request.artistId = bytes32(uint256(1));
        request.newAddress = address(2);
        request.vestedAuthorityClass = 1;
        request.expectedCauseHash = bytes32(uint256(3));
        request.expectedResolutionHash = bytes32(uint256(4));
        request.evidenceHash = bytes32(uint256(5));
        request.reasonHash = bytes32(uint256(6));
        request.supersededRecordHashes = new bytes32[](1);
        request.supersededRecordHashes[0] = bytes32(uint256(7));
        bytes32 original = W.requestCommitment(request);
        require(original == Appeal.requestCommitment(request));
        request.evidenceHash = bytes32(uint256(8));
        require(W.requestCommitment(request) == original);
        request.supersededRecordHashes[0] = bytes32(uint256(9));
        require(
            W.requestCommitment(request) != original, "entire original exclusion list remains bound"
        );
    }
}
