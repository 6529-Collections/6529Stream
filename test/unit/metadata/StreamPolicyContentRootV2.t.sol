// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "./StreamContentRootPublication.t.sol";
import { RouterCodecReference } from "../../helpers/RouterCodecReference.sol";
import {
    IStreamPolicyOutputManifestV2 as PM
} from "../../../smart-contracts/interfaces/stream/finality/IStreamPolicyOutputManifestV2.sol";
import {
    IStreamPolicyOutputEvidenceBindingV2 as PB
} from "../../../smart-contracts/interfaces/stream/finality/IStreamPolicyOutputEvidenceBindingV2.sol";
import {
    IStreamPolicyContentRootPublicationV2 as PV
} from "../../../smart-contracts/interfaces/stream/metadata/IStreamPolicyContentRootPublicationV2.sol";
import {
    StreamPolicyOutputSchemasV2 as PD
} from "../../../smart-contracts/domains/finality/StreamPolicyOutputSchemasV2.sol";
import {
    StreamPolicyContentRootSchemasV2 as RD
} from "../../../smart-contracts/domains/finality/StreamPolicyContentRootSchemasV2.sol";

interface PolicyRootVm {
    function mockCall(address target, bytes calldata input, bytes calldata result) external;
    function clearMockedCalls() external;
    function snapshotState() external returns (uint256);
    function revertToState(uint256 snapshot) external returns (bool);
    function etch(address target, bytes calldata code) external;
}

contract PolicyRootCheckpointBoundary is RootCheckpointBoundary {
    constructor(address c, address r) RootCheckpointBoundary(c, r) { }

    function entropySourceSet() external view returns (address) {
        return address(this);
    }
}

contract PolicyRootManifestBoundary {
    address public immutable core;
    address public immutable contentCheckpoint;
    address public immutable artifactCoverage;
    address public immutable router;
    uint8 public fault;
    bytes32 public driftAfterConsent;

    constructor(address c, address p, address a, address r) {
        core = c;
        contentCheckpoint = p;
        artifactCoverage = a;
        router = r;
    }

    function supportsInterface(bytes4 id) external pure returns (bool) {
        return id == type(PM).interfaceId;
    }

    function outputProfile() external pure returns (bytes32) {
        return keccak256("6529STREAM_POLICY_CURRENT_FULL_CONTENT_V2");
    }

    function change(uint8 f, bytes32 consent) external {
        fault = f;
        driftAfterConsent = consent;
    }

    function requireCurrentManifest(bytes32 hash, bytes32 artistId)
        external
        view
        returns (PM.Manifest memory m)
    {
        require(
            hash == keccak256("verified") && artistId == keccak256("artist"), "exact V2 manifest"
        );
        require(fault != 1, "retired output");
        m = PM.Manifest(
            keccak256("checkpoint"),
            keccak256("complete checkpoint"),
            contentCheckpoint,
            keccak256("inventory"),
            keccak256("full policy chain"),
            keccak256("artifact"),
            keccak256("coverage"),
            artistId,
            keccak256("root"),
            keccak256("ordered outputs"),
            keccak256("manifest"),
            StreamFinalityScope(StreamFinalityScopeType.COLLECTION, 1, 0, 0),
            1,
            1216
        );
        if (fault == 2) m.scope.collectionId = 2;
        if (fault == 3) m.scope.tokenId = 91;
        if (fault == 4) m.policyChainHash = 0;
        if (fault == 5) m.entropySourceSet = address(0xBEEF);
        if (fault == 6) m.artistId = keccak256("foreign Artist");
        if (fault == 7) m.tokenCount = 0;
        if (
            driftAfterConsent != 0
                && StreamMetadataRouter(router).consumedArtistContentConsent(driftAfterConsent)
        ) {
            m.policyChainHash = keccak256("late substituted policy");
        }
    }
}

contract PolicyRootProviderBoundary is RootProviderBoundary {
    address public immutable policyOutputManifestV2;
    bytes32 public immutable policyOutputManifestV2CodeHash;

    constructor(address m, address s, address oldManifest, address v2)
        RootProviderBoundary(m, s, oldManifest)
    {
        policyOutputManifestV2 = v2;
        policyOutputManifestV2CodeHash = v2.codehash;
    }

    function supportsInterface(bytes4 id) external pure returns (bool) {
        return id == type(PB).interfaceId;
    }
}

/// @notice Actual Router canonical state, Schema/Store, writer grants and threshold-two Safe.
/// @dev Core/Artist/governance execution/finality/provider/checkpoint/verified manifest are named
/// typed boundaries. Separate checkpoint/manifest suites exercise their actual producers.
contract StreamPolicyContentRootV2Test is ContentRootPublicationFixture {
    PolicyRootManifestBoundary private policyManifest;

    function _initializeOriginalFinalityAnchor() internal override { }

    function setUp() public override {
        super.setUp();
        address cp = address(new PolicyRootCheckpointBoundary(address(core), address(router)));
        policyManifest = new PolicyRootManifestBoundary(
            address(core), cp, manifest.artifactCoverage(), address(router)
        );
        provider = address(
            new PolicyRootProviderBoundary(
                address(metadata), address(schemas), address(manifest), address(policyManifest)
            )
        );
        finality = new RootFinalityBoundary(
            address(core), address(artist), address(metadata), provider, manifest.artifactCoverage()
        );
        artist.configure(address(router), address(finality));
        core.setPointer(keccak256("ARTWORK_FINALITY_REGISTRY"), address(finality));
        router.initializeOriginalFinalityAnchor();
        _policyDocuments();
    }

    function testPolicyRootCanonicalFamilyAndIndependentLiteralDomains() public {
        IStreamContentRootPublication.Publication memory p = _publication();
        bytes32 consent = keccak256("policy consent");
        bytes32 approved = _approvePolicy(p, address(this), consent);
        vm.recordLogs();
        bytes32 hash = router.publishVerifiedPolicyContentRoot(p);
        IStreamContentRootPublication.Record memory r = router.contentRootRecord(hash);
        PV.Binding memory b = router.policyContentRootBinding(hash);
        require(
            hash
                == keccak256(
                    abi.encode(
                        keccak256("6529STREAM_POLICY_CONTENT_ROOT_RECORD_V2"),
                        block.chainid,
                        address(router),
                        r,
                        b
                    )
                )
        );
        require(
            b.profileId == keccak256("6529STREAM_POLICY_CURRENT_FULL_CONTENT_V2")
                && b.outputManifest == address(policyManifest)
        );
        require(
            b.policyChainHash == keccak256("full policy chain")
                && b.inventoryHash == keccak256("inventory")
        );
        require(
            router.collectionContentRootHead(1) == hash
                && router.consumedArtistContentConsent(consent)
        );
        (bool supported, bytes32 familyState) = router.artistContentFamilyState(1, FAMILY);
        require(supported && familyState == approved && r.stateHash == approved);
        (bytes32 root, uint64 count, bytes32 schema) = router.tokenContentRoot(1, _subject());
        require(root == r.contentRoot && count == 1 && schema == PD.LEAF_SCHEMA);
        (root, count, schema) = router.tokenContentRoot(1, keccak256("wrong subject"));
        require(root == 0 && count == 0 && schema == 0);
        Vm.Log[] memory logs = vm.getRecordedLogs();
        require(
            logs.length == 3 && logs[0].emitter == address(router)
                && logs[1].emitter == address(router) && logs[2].emitter == address(router)
        );
        require(keccak256(logs[0].data) == keccak256(abi.encode(uint16(2), r)));
        require(
            logs[1].topics[1] == bytes32(uint256(1)) && logs[1].topics[2] == hash
                && keccak256(logs[1].data) == keccak256(abi.encode(uint16(2), b))
        );
        r.stateHash = 0;
        r.artistConsent = 0;
        r.publishedAt = 0;
        require(
            approved
                == keccak256(
                    abi.encode(
                        keccak256("6529STREAM_POLICY_CONTENT_ROOT_STATE_V2"),
                        block.chainid,
                        address(router),
                        r,
                        b
                    )
                )
        );
    }

    function testPolicyRootOriginalV1AndV2ShareCanonicalLineageAndConsumedMap() public {
        _documents(schemas.RAW_BYTES());
        IStreamContentRootPublication.Publication memory p = _publication();
        bytes32 firstConsent = keccak256("original consent");
        _approve(p, address(this), firstConsent);
        bytes32 first = router.publishVerifiedTokenContentRoot(p);
        bytes32 oldRecord = keccak256(abi.encode(router.contentRootRecord(first)));
        require(router.policyContentRootBinding(first).profileId == 0);
        (,, bytes32 schema) = router.tokenContentRoot(1, _subject());
        require(schema == StreamContentRootSchemas.LEAF_SCHEMA);
        p.expectedPredecessor = first;
        _approvePolicy(p, address(this), firstConsent);
        vm.expectRevert(
            abi.encodeWithSelector(
                StreamMetadataRouter.ArtistContentConsentConsumed.selector, firstConsent
            )
        );
        router.publishVerifiedPolicyContentRoot(p);
        _approvePolicy(p, address(this), keccak256("second consent"));
        bytes32 second = router.publishVerifiedPolicyContentRoot(p);
        require(router.contentRootRecord(second).publication.expectedPredecessor == first);
        require(keccak256(abi.encode(router.contentRootRecord(first))) == oldRecord);
        p.expectedPredecessor = second;
        _approve(p, address(this), keccak256("third consent"));
        bytes32 third = router.publishVerifiedTokenContentRoot(p);
        require(
            router.contentRootRecord(third).publication.expectedPredecessor == second
                && router.policyContentRootBinding(third).profileId == 0
        );
        (,, schema) = router.tokenContentRoot(1, _subject());
        require(schema == StreamContentRootSchemas.LEAF_SCHEMA);
    }

    function testPolicyRootExactGrantRevisionPublisherAndBindingRemainCurrent() public {
        IStreamContentRootPublication.Publication memory p = _publication();
        bytes32 approved = _approvePolicy(p, address(this), keccak256("consent"));
        _grant(1, 7, address(this), false);
        vm.expectRevert();
        router.publishVerifiedPolicyContentRoot(p);
        _grant(1, 7, address(this), true);
        require(router.previewPolicyContentRootPublication(p, address(this)) != approved);
        vm.expectRevert();
        router.publishVerifiedPolicyContentRoot(p);
        _approvePolicy(p, address(this), keccak256("consent"));
        artist.changeGeneration();
        vm.expectRevert();
        router.publishVerifiedPolicyContentRoot(p);
        require(
            !router.consumedArtistContentConsent(keccak256("consent"))
                && router.collectionContentRootHead(1) == 0
        );
    }

    function testPolicyRootLateDependencyDriftRollsBackExactApprovalAndRetries() public {
        IStreamContentRootPublication.Publication memory p = _publication();
        bytes32 consent = keccak256("late consent");
        _approvePolicy(p, address(this), consent);
        policyManifest.change(0, consent);
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamContentRootPublication.InvalidContentRootPublication.selector
            )
        );
        router.publishVerifiedPolicyContentRoot(p);
        require(
            !router.consumedArtistContentConsent(consent)
                && router.collectionContentRootHead(1) == 0
        );
        policyManifest.change(0, 0);
        bytes32 record = router.publishVerifiedPolicyContentRoot(p);
        require(router.contentRootRecord(record).artistConsent == consent);
    }

    function testPolicyRootMissingProviderCapabilityAndRuntimeCannotBorrowV1() public {
        IStreamContentRootPublication.Publication memory p = _publication();
        PolicyRootVm(address(vm))
            .mockCall(
                provider,
                abi.encodeWithSignature("supportsInterface(bytes4)", type(PB).interfaceId),
                abi.encode(false)
            );
        vm.expectRevert();
        router.previewPolicyContentRootPublication(p, address(this));
        PolicyRootVm(address(vm)).clearMockedCalls();
        PolicyRootVm(address(vm))
            .mockCall(
                provider,
                abi.encodeCall(PB.policyOutputManifestV2CodeHash, ()),
                abi.encode(keccak256("wrong runtime"))
            );
        vm.expectRevert();
        router.previewPolicyContentRootPublication(p, address(this));
        PolicyRootVm(address(vm)).clearMockedCalls();
        require(router.previewPolicyContentRootPublication(p, address(this)) != 0);
    }

    function testFuzzPolicyRootRejectsIncompleteOrForeignManifest(uint8 selected) public {
        policyManifest.change(uint8(uint256(selected) % 7 + 1), 0);
        vm.expectRevert();
        router.previewPolicyContentRootPublication(_publication(), address(this));
        require(router.collectionContentRootHead(1) == 0);
    }

    function testPolicyRootRetiredSchemasAndOutputKeepImmutableHistory() public {
        IStreamContentRootPublication.Publication memory p = _publication();
        _approvePolicy(p, address(this), keccak256("consent"));
        bytes32 record = router.publishVerifiedPolicyContentRoot(p);
        bytes32 retained = keccak256(
            abi.encode(router.contentRootRecord(record), router.policyContentRootBinding(record))
        );
        p.expectedPredecessor = record;
        policyManifest.change(1, 0);
        vm.expectRevert();
        router.previewPolicyContentRootPublication(p, address(this));
        policyManifest.change(0, 0);
        (bytes32 s, bytes32 o, bytes32 n) = schemas.statusTransition(
            RD.ROOT_SCHEMA, IStreamSchemaRegistry.DocumentStatus.DEPRECATED
        );
        executor.execute(
            address(schemas),
            abi.encodeCall(
                schemas.setDocumentStatus,
                (RD.ROOT_SCHEMA, IStreamSchemaRegistry.DocumentStatus.DEPRECATED)
            ),
            s,
            o,
            n
        );
        vm.expectRevert();
        router.previewPolicyContentRootPublication(p, address(this));
        require(
            retained
                == keccak256(
                    abi.encode(
                        router.contentRootRecord(record), router.policyContentRootBinding(record)
                    )
                )
        );
    }

    function testPolicyRootOriginalRatificationEvolutionAndFreezeApply() public {
        (, bytes32 beforeState) = router.currentArtistContentState(1);
        artist.ratify(beforeState, keccak256("ratification"));
        IStreamContentRootPublication.Publication memory p = _publication();
        _approvePolicy(p, address(this), keccak256("first"));
        p.expectedPredecessor = router.publishVerifiedPolicyContentRoot(p);
        _approvePolicy(p, address(this), keccak256("second"));
        router.publishVerifiedPolicyContentRoot(p);
        (bytes32 ratification, bytes32 evolved) = router.artistContentEvolution(1);
        (, bytes32 current) = router.currentArtistContentState(1);
        require(
            ratification == keccak256("ratification") && evolved == current
                && current != beforeState
        );
        bytes32[] memory locks = new bytes32[](1);
        // CONTENT_ROOT is not an original Artist freeze lock class. Preserve the
        // supported SCRIPT lock, then exercise the original Core root freeze gate.
        locks[0] = keccak256("SCRIPT");
        artist.setFreeze(router.artistContentFreezeState(1), locks);
        router.applyArtistContentFreeze(1, keccak256("freeze"));
        (bool supported, bool locked) = router.artistContentLockState(1, locks[0]);
        require(supported && locked, "original Artist SCRIPT lock");
        p.expectedPredecessor = router.collectionContentRootHead(1);
        _approvePolicy(p, address(this), keccak256("third"));
        core.setFrozen(true);
        vm.expectRevert();
        router.publishVerifiedPolicyContentRoot(p);
        require(
            !router.consumedArtistContentConsent(keccak256("third"))
                && router.collectionContentRootHead(1) == p.expectedPredecessor,
            "Core freeze preserves approval and root"
        );
        core.setFrozen(false);
        router.publishVerifiedPolicyContentRoot(p);
        require(router.consumedArtistContentConsent(keccak256("third")), "exact approval retry");
    }

    function testPolicyRootActualSafeLateRollbackIdenticalSignedRetry() public {
        uint256[] memory keys = new uint256[](2);
        keys[0] = 0xA11CE;
        keys[1] = 0xB0B;
        OfficialSafe account =
            createOfficialSafe(deploySafeComponents("1.4.1"), safeOwnerAddresses(keys), 2, 9981);
        _grant(0, 8, address(account), true);
        IStreamContentRootPublication.Publication memory p = _publication();
        bytes32 consent = keccak256("safe consent");
        _approvePolicy(p, address(account), consent);
        bytes memory data = abi.encodeCall(router.publishVerifiedPolicyContentRoot, (p));
        bytes memory signatures = safeThresholdSignature(
            keys,
            account.getTransactionHash(
                address(router), 0, data, 0, 0, 0, 0, address(0), address(0), account.nonce()
            )
        );
        uint256 nonce = account.nonce();
        policyManifest.change(0, consent);
        vm.expectRevert();
        account.execTransaction(
            address(router), 0, data, 0, 0, 0, 0, address(0), payable(address(0)), signatures
        );
        require(
            account.nonce() == nonce && !router.consumedArtistContentConsent(consent)
                && router.collectionContentRootHead(1) == 0
        );
        policyManifest.change(0, 0);
        require(
            account.execTransaction(
                address(router), 0, data, 0, 0, 0, 0, address(0), payable(address(0)), signatures
            )
        );
        IStreamContentRootPublication.Record memory r =
            router.contentRootRecord(router.collectionContentRootHead(1));
        require(
            account.nonce() == nonce + 1 && r.publisher == address(account)
                && r.authorizationClass == 8 && r.artistConsent == consent
        );
    }

    function testPolicyCodecMatchesOriginalFieldsWithDistinctRuntimeCommitments() public {
        bytes memory referenceCode =
            address(
            new RouterCodecReference(
                address(core),
                address(executor),
                keccak256("deployment"),
                "ipfs://router",
                keccak256("manifest"),
                IStreamArtistAttribution(address(artist))
            )
        )
        .code;
        IStreamContentRootPublication.Publication memory p = _publication();
        bytes32 consent = keccak256("paired V2 publication");
        bytes32 preview = _approvePolicy(p, address(this), consent);
        PolicyRootVm snapshots = PolicyRootVm(address(vm));
        uint256 snapshot = snapshots.snapshotState();
        snapshots.etch(address(router), referenceCode);
        // The original route commits this facade's runtime hash. An etched reference must
        // obtain its own exact approval; pretending the old approval still applies is invalid.
        bytes32 oldPreview = _approvePolicy(p, address(this), consent);
        require(oldPreview != preview, "facade runtime remains in approved state");
        bytes32 oldHash = router.publishVerifiedPolicyContentRoot(p);
        IStreamContentRootPublication.Record memory oldRecord = router.contentRootRecord(oldHash);
        bytes memory oldBinding = abi.encode(router.policyContentRootBinding(oldHash));
        require(
            oldHash
                == keccak256(
                    abi.encode(
                        keccak256("6529STREAM_POLICY_CONTENT_ROOT_RECORD_V2"),
                        block.chainid,
                        address(router),
                        oldRecord,
                        router.policyContentRootBinding(oldHash)
                    )
                ),
            "original independent record preimage"
        );
        require(oldRecord.stateHash == oldPreview);
        require(router.consumedArtistContentConsent(consent));
        require(snapshots.revertToState(snapshot), "restore original comparison");
        bytes32 hash = router.publishVerifiedPolicyContentRoot(p);
        IStreamContentRootPublication.Record memory current = router.contentRootRecord(hash);
        require(
            hash
                == keccak256(
                    abi.encode(
                        keccak256("6529STREAM_POLICY_CONTENT_ROOT_RECORD_V2"),
                        block.chainid,
                        address(router),
                        current,
                        router.policyContentRootBinding(hash)
                    )
                ),
            "current independent record preimage"
        );
        require(
            hash != oldHash && current.routeHash != oldRecord.routeHash
                && current.stateHash == preview
        );
        // Only the route/runtime-dependent commitments differ. Compare every other encoded field.
        oldRecord.routeHash = 0;
        oldRecord.stateHash = 0;
        current.routeHash = 0;
        current.stateHash = 0;
        require(keccak256(abi.encode(current)) == keccak256(abi.encode(oldRecord)));
        require(
            keccak256(abi.encode(router.policyContentRootBinding(hash))) == keccak256(oldBinding)
        );
        require(
            router.collectionContentRootHead(1) == hash
                && router.consumedArtistContentConsent(consent)
        );
        PV.Binding memory empty;
        require(
            keccak256(abi.encode(router.policyContentRootBinding(bytes32(uint256(42)))))
                == keccak256(abi.encode(empty))
        );
    }

    function _approvePolicy(
        IStreamContentRootPublication.Publication memory p,
        address publisher,
        bytes32 consent
    ) private returns (bytes32 state) {
        state = router.previewPolicyContentRootPublication(p, publisher);
        artist.approve(state, consent);
    }

    function _policyDocuments() private {
        string[5] memory names = [
            "STREAM_POLICY_OUTPUT_MANIFEST_V2",
            "STREAM_ABI_POLICY_OUTPUT_MANIFEST_V2",
            "STREAM_POLICY_TOKEN_CONTENT_LEAF_V2",
            "STREAM_POLICY_CONTENT_ROOT_RECORD_V2",
            "STREAM_ABI_POLICY_CONTENT_ROOT_RECORD_V2"
        ];
        for (uint256 i; i < names.length; ++i) {
            _register(
                names[i],
                (i == 1 || i == 4)
                    ? IStreamSchemaRegistry.DocumentKind.CANONICALIZATION
                    : IStreamSchemaRegistry.DocumentKind.SCHEMA,
                RD.document(keccak256(bytes(names[i]))),
                schemas.RAW_BYTES()
            );
        }
    }
}
