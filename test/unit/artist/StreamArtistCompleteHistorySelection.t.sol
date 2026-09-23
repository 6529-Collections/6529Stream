// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    StreamArtistCompleteHistorySelection as Selection
} from "../../../smart-contracts/domains/artist/StreamArtistCompleteHistorySelection.sol";
import {
    StreamArtistRecoveredHydrationTypes as RH
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistRecoveredHydrationTypes.sol";
import {
    StreamArtistOnboardingTypes as T
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistOnboardingTypes.sol";
import {
    StreamArtistHistoryTypes as H
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistHistory.sol";
import {
    StreamArtistCollaboratorTypes as C
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistCollaboratorTypes.sol";
import {
    StreamArtistPlatformTypes as PW
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistPlatformTypes.sol";
import {
    StreamArtistAttributionDisputeTypes as AD
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistAttributionDisputes.sol";

/// @dev Explicit getter boundary for route-selection tests; not original producer or admission evidence.
contract CompleteHistorySelectionOwner {
    RH.OwnerProvenance private prefix;
    uint64 private importedAt;
    T.Snapshot private snapshot;
    H.Receipt[] private receipts;
    mapping(uint256 => T.Binding) private heads;
    mapping(uint256 => mapping(uint64 => T.Binding)) private generations;
    mapping(uint256 => mapping(uint64 => C.BindingTerms)) private terms;
    mapping(uint256 => PW.State) private platforms;
    mapping(uint256 => uint8) private attribution;
    mapping(uint256 => uint64) private attributionGeneration;
    mapping(bytes32 => AD.Record) private disputes;

    function append(uint16 operation, bytes32 artist, uint256 collection, bytes32 record) external {
        receipts.push(H.Receipt(operation, artist, collection, record));
    }

    function setPrefix(RH.OwnerProvenance memory p, uint64 at, uint64 revision) external {
        prefix = p;
        importedAt = at;
        snapshot.revision = revision;
    }

    function setBinding(uint256 id, T.Binding memory b, bool current) external {
        generations[id][b.generation] = b;
        if (current) heads[id] = b;
    }

    function setTerms(uint256 id, uint64 generation, uint32 count) external {
        terms[id][generation].count = count;
    }

    function setAttribution(uint256 id, uint8 state, uint64 generation) external {
        attribution[id] = state;
        attributionGeneration[id] = generation;
    }

    function setPlatform(uint256 id, bytes32 declaration) external {
        platforms[id].declaration.recordHash = declaration;
    }

    function setDispute(bytes32 hash, AD.Record memory record) external {
        disputes[hash] = record;
    }

    function recoveredHydrationImportedPrefix()
        external
        view
        returns (RH.OwnerProvenance memory, bytes32, uint64)
    {
        return (prefix, 0, importedAt);
    }

    function ownerStateSnapshotV2() external view returns (T.Snapshot memory) {
        return snapshot;
    }

    function artistNativeReceiptCount() external view returns (uint256) {
        return receipts.length;
    }

    function artistNativeReceiptAt(uint256 i) external view returns (H.Receipt memory) {
        return receipts[i];
    }

    function binding(uint256 id) external view returns (T.Binding memory) {
        return heads[id];
    }

    function bindingAt(uint256 id, uint64 generation) external view returns (T.Binding memory) {
        return generations[id][generation];
    }

    function bindingTerms(uint256 id, uint64 generation)
        external
        view
        returns (C.BindingTerms memory)
    {
        return terms[id][generation];
    }

    function platformWorksState(uint256 id) external view returns (PW.State memory) {
        return platforms[id];
    }

    function attributionState(uint256 id) external view returns (uint8, uint64) {
        return (attribution[id], attributionGeneration[id]);
    }

    function attributionDisputeRecord(bytes32 hash) external view returns (AD.Record memory) {
        return disputes[hash];
    }
}

contract CompleteHistorySelectionPredecessor {
    T.SuiteConfiguration private suite;

    constructor(T.SuiteConfiguration memory source) {
        suite = source;
    }

    function operationCoordinator() external view returns (address) {
        return address(this);
    }

    function authorityHydrationSuite() external view returns (T.SuiteConfiguration memory) {
        return suite;
    }

    function importedHistoryBindingCount() external pure returns (uint256) {
        return 1;
    }

    function importedHistoryBinding(uint256)
        external
        view
        returns (address, uint64, bytes32, bytes32)
    {
        return (address(this), 1, bytes32(uint256(1)), bytes32(uint256(2)));
    }
}

contract StreamArtistCompleteHistorySelectionTest {
    T.SuiteConfiguration private source;
    CompleteHistorySelectionOwner[7] private owners;
    bytes32 private constant ARTIST = bytes32(uint256(101));

    function setUp() external {
        for (uint8 i; i < 7; ++i) {
            owners[i] = new CompleteHistorySelectionOwner();
            source.owners[i] = address(owners[i]);
        }
        _bound(1, 1, ARTIST, true);
        owners[0].append(1, ARTIST, 1, bytes32(uint256(201)));
    }

    function testCompleteSelectionPreservesOrdinaryAcceptedRoute() external view {
        require(!Selection.requiredFromSource(source), "ordinary accepted source changed route");
    }

    function testCompleteSelectionUsesActualPendingHeadDespiteCallerMasksAndOmissions() external {
        _bound(1, 1, ARTIST, false);
        CompleteHistorySelectionPredecessor prior = new CompleteHistorySelectionPredecessor(source);
        T.SuiteConfiguration memory destination;
        destination.owners[2] = address(prior);
        RH.Request memory request;
        require(Selection.required(destination, request), "actual pending head omitted");
        for (uint8 i; i < 7; ++i) {
            request.expectedCapabilities[i].supportedFeatures = type(uint256).max;
        }
        request.expectedSemanticInventory = bytes32(uint256(123));
        require(Selection.required(destination, request), "caller claims changed route");
        _bound(1, 1, ARTIST, true);
        require(!Selection.required(destination, request), "capability union selected route");
    }

    function testCompleteSelectionDetectsFormerArtistFromOriginalBindingRows() external {
        _bound(1, 2, bytes32(uint256(102)), true);
        require(Selection.requiredFromSource(source), "former Artist chronology missed");
    }

    function testCompleteSelectionPreservesSupportedSingletonPlatformRoute() external {
        owners[4].setPlatform(1, bytes32(uint256(301)));
        owners[4].append(8, 0, 1, bytes32(uint256(301)));
        require(!Selection.requiredFromSource(source), "singleton Platform route changed");
    }

    function testCompleteSelectionDetectsAggregateRetainedPlatformOnBoundSubject() external {
        owners[4].setPlatform(1, bytes32(uint256(301)));
        owners[4].append(8, 0, 1, bytes32(uint256(301)));
        _bound(2, 1, ARTIST, true);
        owners[0].append(1, ARTIST, 2, bytes32(uint256(202)));
        require(Selection.requiredFromSource(source), "consumed Platform declaration missed");
    }

    function testCompleteSelectionComposesRetainedPlatformWithOrdinaryCollaborators() external {
        owners[4].setPlatform(1, bytes32(uint256(301)));
        owners[4].append(8, 0, 1, bytes32(uint256(301)));
        owners[0].setTerms(1, 1, 1);
        require(Selection.requiredFromSource(source), "singleton Platform collaborators missed");
    }

    function testCompleteSelectionCountsOriginalCollaboratorRegistrationsAsPrincipals() external {
        owners[4].setPlatform(1, bytes32(uint256(301)));
        owners[4].append(8, 0, 1, bytes32(uint256(301)));
        owners[2].append(1, ARTIST, 0, ARTIST);
        require(!Selection.requiredFromSource(source), "one principal changed singleton route");
        bytes32 second = bytes32(uint256(102));
        owners[2].append(6, second, 0, second);
        require(Selection.requiredFromSource(source), "second actual principal missed");
    }

    function testCompleteSelectionLeavesUnboundAndSimpleSiblingOnOldRoute() external {
        _unbound();
        require(!Selection.requiredFromSource(source), "simple unbound composition changed route");
    }

    function testCompleteSelectionAdmitsAllUnboundAllegationWithoutDeclaration() external {
        T.SuiteConfiguration memory onlyUnbound;
        for (uint8 i; i < 7; ++i) {
            onlyUnbound.owners[i] = address(new CompleteHistorySelectionOwner());
        }
        CompleteHistorySelectionOwner(onlyUnbound.owners[4]).append(10, 0, 2, bytes32(uint256(305)));
        require(Selection.requiredFromSource(onlyUnbound), "legal op10 without declaration missed");
        CompleteHistorySelectionOwner(onlyUnbound.owners[4]).setPlatform(2, bytes32(uint256(301)));
        require(!Selection.requiredFromSource(onlyUnbound), "declared unbound old route changed");
    }

    function testCompleteSelectionComposesUnboundWithAdvancedConsentSibling() external {
        _unbound();
        owners[6].append(15, ARTIST, 1, bytes32(uint256(501)));
        require(Selection.requiredFromSource(source), "unbound economics sibling missed");
    }

    function testCompleteSelectionComposesUnboundWithCollaborators() external {
        _unbound();
        owners[0].setTerms(1, 1, 1);
        require(Selection.requiredFromSource(source), "unbound collaborator sibling missed");
    }

    function testCompleteSelectionKeepsNarrowGovernedCorrectionWithCollaborators() external {
        _bound(1, 2, ARTIST, true);
        owners[0].setTerms(1, 2, 1);
        _dispute(1, 0);
        require(!Selection.requiredFromSource(source), "old narrow governed44 route changed");
    }

    function testCompleteSelectionComposesCollaboratorsWithFullDisputesWithoutRecoveryGate()
        external
    {
        owners[0].setTerms(1, 1, 1);
        _dispute(1, 1);
        require(owners[2].artistNativeReceiptCount() == 0, "no synthetic recovery");
        require(
            Selection.requiredFromSource(source), "ordinary principal dispute composition missed"
        );
    }

    function testCompleteSelectionReadsOriginalImportedPlatformAndAttestationHistory() external {
        RH.OwnerProvenance memory prefix;
        prefix.journal = new RH.JournalEntry[](2);
        prefix.journal[0].receipt = H.Receipt(8, 0, 2, bytes32(uint256(302)));
        prefix.journal[1].receipt = H.Receipt(24, ARTIST, 1, bytes32(uint256(401)));
        owners[4].setPrefix(prefix, 1, 1);
        require(Selection.requiredFromSource(source), "imported original records omitted");
    }

    function testCompleteSelectionDoesNotTreatOwnerOneImportCommitAsCollaboratorHistory() external {
        RH.OwnerProvenance memory prefix;
        owners[1].setPrefix(prefix, 1, 1);
        _dispute(1, 1);
        require(!Selection.requiredFromSource(source), "import itself invented collaborators");
        owners[1].setPrefix(prefix, 1, 2);
        require(Selection.requiredFromSource(source), "actual collaborator mutation ignored");
    }

    function _bound(uint256 id, uint64 generation, bytes32 artist, bool accepted) private {
        T.Binding memory b;
        b.artistId = artist;
        b.artistAddress = address(0xA11);
        b.bindingHash = bytes32(uint256(200) + generation);
        b.generation = generation;
        b.consentMode = 1;
        b.accepted = accepted;
        owners[0].setBinding(id, b, true);
        owners[4].setAttribution(id, accepted ? 2 : 1, generation);
    }

    function _unbound() private {
        owners[4].append(8, 0, 2, bytes32(uint256(302)));
        owners[4].setPlatform(2, bytes32(uint256(302)));
    }

    function _dispute(uint64 generation, uint8 authorityClass) private {
        bytes32 hash = bytes32(uint256(601));
        AD.Record memory r;
        r.recordHash = hash;
        r.terms.bindingGeneration = generation;
        r.authorityClass = authorityClass;
        owners[4].setDispute(hash, r);
        owners[4].append(44, ARTIST, 1, hash);
    }
}
