// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    StreamArtistArchiveOriginLineage as Lineage
} from "../../../smart-contracts/domains/preservation/StreamArtistArchiveOriginLineage.sol";
import {
    StreamArtistArchiveOriginProof as Proof
} from "../../../smart-contracts/domains/preservation/StreamArtistArchiveOriginProof.sol";
import {
    StreamArtistArchiveOriginTypes as O
} from "../../../smart-contracts/interfaces/stream/preservation/StreamArtistArchiveOriginTypes.sol";
import {
    StreamArtistOnboardingTypes as A
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistOnboardingTypes.sol";
import {
    StreamRenderCriticalSourceTypes as S
} from "../../../smart-contracts/interfaces/stream/preservation/StreamRenderCriticalSourceTypes.sol";
import {
    StreamPreservationInventoryTypes as T
} from "../../../smart-contracts/interfaces/stream/preservation/StreamPreservationInventoryTypes.sol";
import {
    IStreamMetadataServingFacts as RouterRead
} from "../../../smart-contracts/interfaces/stream/metadata/IStreamMetadataServingFacts.sol";
import {
    IStreamConservationRecordSelection as Conservation
} from "../../../smart-contracts/interfaces/stream/metadata/IStreamConservationRecordSelection.sol";
import {
    IStreamArtistBindingOwner as BindingRead
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistBindingOwner.sol";
import {
    IStreamArtistAcceptanceOwner as AcceptanceRead
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistAcceptanceOwner.sol";

interface OriginLineageVm {
    function mockCall(address, bytes calldata, bytes calldata) external;
    function mockCallRevert(address, bytes calldata, bytes calldata) external;
    function expectRevert(bytes calldata) external;
    function expectCall(address, bytes calldata) external;
    function etch(address, bytes calldata) external;
}

contract OriginLineageMarker {
    function marker() external pure returns (uint256) {
        return 1;
    }
}

contract OriginLineageRouterFixture {
    mapping(uint256 => RouterRead.ArtistPresentation) private _presentations;

    function set(uint256 cid, RouterRead.ArtistPresentation memory value) external {
        _presentations[cid] = value;
    }

    function artistPresentation(uint256 cid)
        external
        view
        returns (RouterRead.ArtistPresentation memory)
    {
        return _presentations[cid];
    }
}

contract OriginLineageOwnerFixture {
    mapping(uint256 => mapping(uint64 => A.Binding)) private _bindings;
    mapping(bytes32 => bytes32) private _records;
    mapping(bytes32 => uint64) private _times;

    function setBinding(uint256 cid, uint64 generation, A.Binding memory value) external {
        _bindings[cid][generation] = value;
    }

    function setAcceptance(bytes32 binding, bytes32 record, uint64 time) external {
        _records[binding] = record;
        _times[binding] = time;
    }

    function bindingAt(uint256 cid, uint64 generation) external view returns (A.Binding memory) {
        return _bindings[cid][generation];
    }

    function acceptanceRecord(bytes32 binding) external view returns (bytes32) {
        return _records[binding];
    }

    function acceptedAt(bytes32 binding) external view returns (uint64) {
        return _times[binding];
    }
}

/// @notice Actual Lineage code with real canonical Router/owner getter fixtures.
/// @dev The two fixed Proof library boundaries (currentOrigin/ancestorOrigin) are explicitly
/// mocked to synthetic admitted environments. These tests do not prove certificate admission,
/// actual op55/56/57/60, a second migration, real Router locking, or full preservation/finality.
/// B/C positives model locked A under later authority without inventing a new Router or requiring
/// a B-native proposal/acceptance receipt. Those origin/certificate proofs belong to Proof tests.
contract StreamArtistArchiveOriginLineageTest {
    OriginLineageVm private constant vm =
        OriginLineageVm(address(uint160(uint256(keccak256("hevm cheat code")))));
    uint256 private constant CID = 77;
    uint64 private constant GENERATION = 7;
    bytes32 private constant ARTIST = keccak256("lineage fixture artist");
    bytes32 private constant BINDING = keccak256("original binding generation seven");
    bytes32 private constant IDENTITY = keccak256("original identity document");
    bytes32 private constant ACCEPTANCE = keccak256("original acceptance");
    S.Dependencies private d;
    O.Origin private a;
    O.Origin private b;
    O.Origin private c;
    RouterRead.ArtistPresentation private presented;
    Conservation.Association private association;
    OriginLineageRouterFixture private router;

    function setUp() public {
        router = new OriginLineageRouterFixture();
        d.targets[0] = address(new OriginLineageMarker());
        d.targets[4] = address(router);
        d.codeHashes[0] = d.targets[0].codehash;
        d.codeHashes[4] = address(router).codehash;
        d.chainId = block.chainid;
        d.readGas = 200000;
        a = _origin(1);
        b = _origin(2);
        c = _origin(3);
        presented.locked = true;
        presented.registry = a.environment.registry;
        presented.registryCodeHash = a.registryCodeHash;
        presented.artistId = ARTIST;
        presented.bindingGeneration = GENERATION;
        presented.bindingHash = BINDING;
        presented.nominatedArtist = address(0xA11CE);
        presented.identityRecordHash = IDENTITY;
        presented.acceptanceRecordHash = ACCEPTANCE;
        presented.acceptedAt = 1000;
        presented.lockedAt = 2000;
        presented.snapshotHash = _snapshot(presented, address(router));
        association = Conservation.Association(ARTIST, BINDING, GENERATION, IDENTITY);
        router.set(CID, presented);
        _save(a);
        _save(b);
        _save(c);
        _select(b, a);
    }

    function readLineage(
        RouterRead.ArtistPresentation calldata p,
        Conservation.Association calldata join
    ) external view returns (O.Origin memory current, O.Origin memory original, bytes32 hash) {
        return Lineage.lineage(d, CID, p, join);
    }

    function testLockedAUnderCurrentBRetainsRouterDomainAndExactOwnerJoins() public {
        _expectJoins(b);
        _expectJoins(a);
        _assertLineage(b, a);
    }

    function testLockedAUnderCurrentCUsesSameOriginalPresentation() public {
        _select(c, a);
        _expectJoins(c);
        _expectJoins(a);
        _assertLineage(c, a);
    }

    function testSameCurrentAndPresentedOriginRemainsSupported() public {
        _select(a, a);
        _expectJoins(a);
        _assertLineage(a, a);
    }

    function testSuppliedPresentationMustEqualExactRouterTuple() public {
        RouterRead.ArtistPresentation memory wrong = presented;
        wrong.nominatedArtist = address(0xB0B);
        vm.expectRevert(abi.encodeWithSelector(T.InventoryRead.selector, address(router)));
        this.readLineage(wrong, association);
        _assertLineage(b, a);
    }

    function testStoredSnapshotHashAndOriginalRouterDomainAreRequired() public {
        RouterRead.ArtistPresentation memory wrong = presented;
        wrong.snapshotHash = keccak256("not original Router hash");
        router.set(CID, wrong);
        _reject(wrong, association);
        wrong.snapshotHash = _snapshot(wrong, b.environment.registry);
        router.set(CID, wrong);
        _reject(wrong, association);
        router.set(CID, presented);
        _assertLineage(b, a);
    }

    function testAllFourAssociationCoordinatesMustMatchLockedPresentation() public {
        for (uint256 i; i < 4; ++i) {
            Conservation.Association memory wrong = association;
            if (i == 0) wrong.artistId = keccak256("wrong artist");
            else if (i == 1) wrong.bindingHash = keccak256("wrong binding");
            else if (i == 2) wrong.generation = GENERATION + 1;
            else wrong.identityRecordHash = keccak256("wrong identity");
            _reject(presented, wrong);
        }
        _assertLineage(b, a);
    }

    function testCurrentBindingRejectsUnacceptedOrChangedHistoricalFields() public {
        A.Binding memory good = _binding();
        for (uint256 i; i < 6; ++i) {
            A.Binding memory wrong = _binding();
            if (i == 0) wrong.accepted = false;
            else if (i == 1) wrong.artistId = keccak256("wrong artist");
            else if (i == 2) wrong.artistAddress = address(0xB0B);
            else if (i == 3) wrong.identityRecordHash = keccak256("wrong identity");
            else if (i == 4) wrong.bindingHash = keccak256("wrong binding");
            else wrong.generation = GENERATION + 1;
            OriginLineageOwnerFixture(b.environment.owners[0]).setBinding(CID, GENERATION, wrong);
            _reject(presented, association);
        }
        OriginLineageOwnerFixture(b.environment.owners[0]).setBinding(CID, GENERATION, good);
        _assertLineage(b, a);
    }

    function testOriginalBindingMustStillMatchAfterCurrentBindingPasses() public {
        A.Binding memory wrong = _binding();
        wrong.identityRecordHash = keccak256("changed original identity");
        OriginLineageOwnerFixture(a.environment.owners[0]).setBinding(CID, GENERATION, wrong);
        _reject(presented, association);
        OriginLineageOwnerFixture(a.environment.owners[0]).setBinding(CID, GENERATION, _binding());
        _assertLineage(b, a);
    }

    function testBothAcceptanceOwnersMustMatchOriginalRecordAndAcceptedAt() public {
        address[2] memory owners = [b.environment.owners[3], a.environment.owners[3]];
        for (uint256 i; i < 2; ++i) {
            OriginLineageOwnerFixture(owners[i])
                .setAcceptance(BINDING, keccak256("wrong record"), presented.acceptedAt);
            _reject(presented, association);
            OriginLineageOwnerFixture(owners[i])
                .setAcceptance(BINDING, ACCEPTANCE, presented.acceptedAt + 1);
            _reject(presented, association);
            OriginLineageOwnerFixture(owners[i])
                .setAcceptance(BINDING, ACCEPTANCE, presented.acceptedAt);
        }
        _assertLineage(b, a);
    }

    function testUncertifiedAncestorProofFailureIsNotConvertedIntoLineage() public {
        vm.mockCallRevert(
            address(Proof),
            abi.encodeWithSelector(
                Proof.ancestorOrigin.selector, d, presented.registry, presented.registryCodeHash
            ),
            abi.encodeWithSelector(O.InvalidArchiveOrigin.selector)
        );
        _reject(presented, association);
    }

    function testUnlockedOrIncompleteStoredPresentationCannotAcquireLineage() public {
        for (uint256 i; i < 5; ++i) {
            RouterRead.ArtistPresentation memory wrong = presented;
            if (i == 0) wrong.locked = false;
            else if (i == 1) wrong.artistId = 0;
            else if (i == 2) wrong.bindingGeneration = 0;
            else if (i == 3) wrong.acceptanceRecordHash = 0;
            else wrong.nominatedArtist = address(0);
            wrong.snapshotHash = _snapshot(wrong, address(router));
            router.set(CID, wrong);
            _reject(wrong, association);
        }
        router.set(CID, presented);
        _assertLineage(b, a);
    }

    function testChangedBindingRuntimeAndOversizedRouterReplyFailBeforeJoin() public {
        address owner = b.environment.owners[0];
        bytes memory saved = owner.code;
        vm.etch(owner, hex"60006000f3");
        vm.expectRevert(abi.encodeWithSelector(T.InventoryRead.selector, owner));
        this.readLineage(presented, association);
        vm.etch(owner, saved);
        bytes memory extra = bytes.concat(abi.encode(presented), bytes32(uint256(1)));
        vm.mockCall(address(router), abi.encodeCall(RouterRead.artistPresentation, (CID)), extra);
        vm.expectRevert(abi.encodeWithSelector(T.InventoryRead.selector, address(router)));
        this.readLineage(presented, association);
    }

    function _reject(RouterRead.ArtistPresentation memory p, Conservation.Association memory join)
        private
    {
        vm.expectRevert(abi.encodeWithSelector(O.InvalidArchiveOrigin.selector));
        this.readLineage(p, join);
    }

    function _assertLineage(O.Origin memory expectedCurrent, O.Origin memory expectedOriginal)
        private
        view
    {
        (O.Origin memory current, O.Origin memory original, bytes32 hash) =
            this.readLineage(presented, association);
        require(
            O.originPinHash(current) == O.originPinHash(expectedCurrent)
                && O.originPinHash(original) == O.originPinHash(expectedOriginal),
            "separate exact environments"
        );
        require(
            hash
                == keccak256(
                    abi.encode(
                        keccak256("6529STREAM_ARTIST_ARCHIVE_PRESENTATION_LINEAGE_V1"),
                        d.chainId,
                        d.targets[0],
                        d.targets[4],
                        CID,
                        presented,
                        association,
                        O.originPinHash(current),
                        O.originPinHash(original)
                    )
                ),
            "exact lineage commitment"
        );
    }

    function _select(O.Origin memory selected, O.Origin memory original) private {
        d.artistTargets = [
            selected.environment.registry,
            selected.environment.coordinator,
            selected.environment.owners[2],
            selected.environment.owners[4],
            selected.environment.archive
        ];
        for (uint256 i; i < 5; ++i) {
            d.artistCodeHashes[i] = d.artistTargets[i].codehash;
        }
        d.artistContentOwner = selected.environment.owners[6];
        d.artistContentOwnerCodeHash = d.artistContentOwner.codehash;
        vm.mockCall(
            address(Proof),
            abi.encodeWithSelector(Proof.currentOrigin.selector, d),
            abi.encode(selected, keccak256("synthetic admitted current completion"))
        );
        vm.mockCall(
            address(Proof),
            abi.encodeWithSelector(
                Proof.ancestorOrigin.selector, d, presented.registry, presented.registryCodeHash
            ),
            abi.encode(original)
        );
    }

    function _expectJoins(O.Origin memory origin) private {
        vm.expectCall(
            origin.environment.owners[0], abi.encodeCall(BindingRead.bindingAt, (CID, GENERATION))
        );
        vm.expectCall(
            origin.environment.owners[3], abi.encodeCall(AcceptanceRead.acceptanceRecord, (BINDING))
        );
        vm.expectCall(
            origin.environment.owners[3], abi.encodeCall(AcceptanceRead.acceptedAt, (BINDING))
        );
    }

    function _save(O.Origin memory origin) private {
        OriginLineageOwnerFixture(origin.environment.owners[0])
            .setBinding(CID, GENERATION, _binding());
        OriginLineageOwnerFixture(origin.environment.owners[3])
            .setAcceptance(BINDING, ACCEPTANCE, presented.acceptedAt);
    }

    function _binding() private view returns (A.Binding memory value) {
        value.artistId = ARTIST;
        value.artistAddress = presented.nominatedArtist;
        value.identityRecordHash = IDENTITY;
        value.bindingHash = BINDING;
        value.generation = GENERATION;
        value.accepted = true;
        value.consentMode = 1;
        value.proposer = address(0x1234);
    }

    function _origin(uint256 n) private returns (O.Origin memory o) {
        o.environment.chainId = block.chainid;
        o.environment.registry = address(new OriginLineageMarker());
        o.environment.coordinator = address(new OriginLineageMarker());
        o.environment.archive = address(new OriginLineageMarker());
        o.environment.core = d.targets[0];
        o.environment.manager = address(0x1111);
        o.environment.suiteConfigurationHash =
            keccak256(abi.encode("synthetic admitted environment", n));
        o.registryCodeHash = o.environment.registry.codehash;
        o.coordinatorCodeHash = o.environment.coordinator.codehash;
        o.archiveCodeHash = o.environment.archive.codehash;
        for (uint256 i; i < 7; ++i) {
            o.environment.owners[i] = address(new OriginLineageOwnerFixture());
            o.environment.ownerCodeHashes[i] = o.environment.owners[i].codehash;
        }
    }

    function _snapshot(RouterRead.ArtistPresentation memory p, address routerDomain)
        private
        view
        returns (bytes32)
    {
        // Typed scalar encoding independently follows the unchanged original Router producer.
        return keccak256(
            abi.encode(
                keccak256("6529STREAM_ROUTER_ARTIST_PRESENTATION_V1"),
                d.chainId,
                d.targets[0],
                routerDomain,
                CID,
                p.registry,
                p.registryCodeHash,
                p.artistId,
                p.bindingGeneration,
                p.bindingHash,
                p.nominatedArtist,
                p.identityRecordHash,
                p.acceptanceRecordHash,
                p.acceptedAt,
                p.lockedAt
            )
        );
    }
}
