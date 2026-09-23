// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    StreamArtistOnboardingRegistry
} from "../../smart-contracts/domains/artist/StreamArtistOnboardingRegistry.sol";

import "../helpers/StreamCurrentAuthorityMigrationRecipe.sol";
import {
    StreamCurrentAuthorityRightsRecordSelection
} from "../../smart-contracts/domains/metadata/StreamCurrentAuthorityRightsRecordSelection.sol";
import {
    IStreamRightsRecordSelection as RightsAPI
} from "../../smart-contracts/interfaces/stream/metadata/IStreamRightsRecordSelection.sol";
import {
    IStreamRightsRecordWitnessSelection as RightsWitness
} from "../../smart-contracts/interfaces/stream/metadata/IStreamRightsRecordWitnessSelection.sol";
import {
    IStreamRightsRecordCurrentAuthority as RightsAuthority
} from "../../smart-contracts/interfaces/stream/metadata/IStreamRightsRecordCurrentAuthority.sol";
import {
    StreamRightsRecordTypes as RightsTypes
} from "../../smart-contracts/interfaces/stream/metadata/StreamRightsRecordTypes.sol";
import {
    IStreamRecordSelectionLock as RightsLock
} from "../../smart-contracts/interfaces/stream/metadata/IStreamRecordSelectionLock.sol";

interface CurrentRightsChainVm {
    function chainId(uint256 value) external;
}

/// @notice Genuine Core, root/Artist Safes, Metadata, Identity owners and repeated recovered import.
/// @dev These two selectors are new original deployments while A is current; they do not import
/// the legacy selector's state or replace the provider's genesis binding. That graph adoption is
/// separately owned. No Core/Artist/Safe mock, runtime installation or storage injection is used.
/// Native execution, current artifact closure, sizes and gas remain separate acceptance gates.
contract StreamCurrentAuthorityRightsRecordSelectionTest is StreamCurrentAuthorityMigrationRecipe {
    StreamCurrentAuthorityRightsRecordSelection private freshRights;
    StreamCurrentAuthorityRightsRecordSelection private retainedRights;
    StreamRightsRecordSelection private legacyRights;
    RightsAPI.Selection private originalFreshSelection;
    RightsAPI.Selection private originalRetainedSelection;
    RightsLock.SelectionLock private originalRightsSeal;
    bytes32 private originalRegistration;

    function setUp() public {
        _authorityPrepareOriginalPreservation();
        freshRights = _newRights();
        retainedRights = _newRights();
        legacyRights = new StreamRightsRecordSelection(
            address(assemblyCore), address(assemblyMetadata), address(assemblySchemas)
        );
        legacyRights.selectCurrent(
            1, _assemblySubject(), assemblyRightsRecord, 0, 0, assemblyRightsStatement
        );
        originalFreshSelection = freshRights.selectCurrent(
            1, _assemblySubject(), assemblyRightsRecord, 0, 0, assemblyRightsStatement
        );
        originalRetainedSelection = retainedRights.selectCurrent(
            1, _assemblySubject(), assemblyRightsRecord, 0, 0, assemblyRightsStatement
        );
        _assertLiteralSelection(freshRights, originalFreshSelection);
        _assertLiteralSelection(retainedRights, originalRetainedSelection);
        originalRightsSeal = _sealRights(retainedRights, assemblyRightsRecord, 1);
        (,,, originalRegistration) =
            IStreamArtistIdentityOwner(assemblySuite.owners[2]).authorityState(assemblyArtistId);
        require(originalRegistration != 0, "actual original immutable identity registration");
        require(
            freshRights.currentAuthorityProfile()
                    == keccak256("6529STREAM_CURRENT_AUTHORITY_RIGHTS_SELECTION_V1")
                && freshRights.supportsInterface(type(RightsAuthority).interfaceId)
                && freshRights.supportsInterface(type(RightsAPI).interfaceId)
                && freshRights.supportsInterface(type(RightsWitness).interfaceId)
                && freshRights.supportsInterface(type(RightsLock).interfaceId),
            "explicit additive capability and all original Rights APIs"
        );
        _assertCurrentIdentityContext();
    }

    function testActualAtoBtoCRetainsOriginalSealAndSelectsFreshAccountThenArtist() public {
        address originalSelector = address(freshRights);
        bytes32 originalReceipt = _originalReceiptHash();
        _authorityMigrateNext();
        require(authorityEra == 1, "genuine completed B");
        _assertCurrentIdentityContext();
        _assertRetainedA();
        (bool legacyCurrent,) = address(legacyRights)
            .staticcall(
                abi.encodeCall(
                    legacyRights.requireCurrent,
                    (1, _assemblySubject(), assemblyRightsRecord, uint64(1))
                )
            );
        require(
            !legacyCurrent, "independently deployed legacy A pins retain their original meaning"
        );
        RightsTypes.Statement memory account = _statement(assemblyRightsRecord, false);
        (
            bytes32 accountRecord,
            IStreamPreservationRecords.CollectionRecord memory accountOriginal
        ) = _recordRights(account, "urn:current-rights:B-account");
        RightsAPI.Selection memory selectedB = freshRights.selectCurrentWithRecord(
            1,
            _assemblySubject(),
            accountRecord,
            assemblyRightsRecord,
            1,
            RightsWitness.Witness(accountOriginal, account)
        );
        require(
            selectedB.authorizationClass == 7 && selectedB.recorderAuthorizationClass == 7
                && selectedB.selector == address(this) && selectedB.recorder == address(this)
                && selectedB.artistIdentityRecordHash == 0 && selectedB.revision == 2,
            "fresh ACCOUNT selection uses actual original RIGHTS class7 grant"
        );
        _assertLiteralSelection(freshRights, selectedB);
        _assertCurrent(freshRights, selectedB);
        address b = address(assemblyArtists);
        require(authorityRegistries[2] == address(0), "C was not predetermined in A or B");

        _authorityMigrateNext();
        require(authorityEra == 2 && address(assemblyArtists) != b, "later genuine completed C");
        _assertCurrentIdentityContext();
        _assertRetainedA();
        _assertCurrent(freshRights, selectedB);
        RightsTypes.Statement memory artist = _statement(accountRecord, true);
        (bytes32 artistRecord,) = _recordRights(artist, "urn:current-rights:C-artist");
        RightsAPI.Selection memory selectedC = freshRights.selectCurrent(
            1, _assemblySubject(), artistRecord, accountRecord, 2, artist
        );
        require(
            selectedC.artistIdentityRecordHash == originalRegistration && selectedC.revision == 3
                && selectedC.recordIndex > selectedB.recordIndex
                && selectedC.predecessor == selectedB.recordHash,
            "current C owner proves retained registration without rewriting its original domain"
        );
        _assertLiteralSelection(freshRights, selectedC);
        _assertCurrent(freshRights, selectedC);
        require(
            address(freshRights) == originalSelector
                && keccak256(abi.encode(freshRights.rightsSelectionAt(1, _assemblySubject(), 1)))
                    == keccak256(abi.encode(originalFreshSelection))
                && keccak256(abi.encode(freshRights.rightsSelectionAt(1, _assemblySubject(), 2)))
                == keccak256(abi.encode(selectedB)) && _originalReceiptHash() == originalReceipt,
            "same instance keeps full A/B history and original Metadata receipt bytes"
        );
        RightsLock.SelectionLock memory cSeal = _sealRights(freshRights, artistRecord, 3);
        require(
            cSeal.selectionHash == selectedC.selectionHash, "fresh seal authenticates C context"
        );
        _assertRetainedA();
        _assertBothSelectionEntrypointsLocked(
            retainedRights, accountRecord, accountOriginal, account
        );
    }

    function testActualIncompleteSuccessorRefusesCurrentUseThenGenuineHydrationRetries() public {
        RightsTypes.Statement memory nextStatement = _statement(assemblyRightsRecord, false);
        (bytes32 nextRecord, IStreamPreservationRecords.CollectionRecord memory original) =
            _recordRights(nextStatement, "urn:current-rights:pending-account");
        bytes memory exactSelection = abi.encodeCall(
            freshRights.selectCurrentWithRecord,
            (
                1,
                _assemblySubject(),
                nextRecord,
                assemblyRightsRecord,
                uint64(1),
                RightsWitness.Witness(original, nextStatement)
            )
        );
        T.SuiteConfiguration memory source = assemblySuite;
        CurrentAuthoritySuccessorGraph successorGraph = new CurrentAuthoritySuccessorGraph();
        (T.SuiteConfiguration memory unproven, StreamArtistOnboardingCoordinator coordinator) = successorGraph.construct(
            source,
            address(assemblyModules),
            address(assemblyExecutor),
            address(assemblyManifest),
            address(assemblyArchive),
            address(assemblyCheckpointVerifier),
            ASSEMBLY_DEPLOYMENT
        );
        StreamModuleRegistration memory admitted = _admitUnprovenAuthority(unproven.registry);
        HT.Leaf[] memory leaves = _rightsBindHistory(source.registry, unproven.registry);
        StreamCorePointerState memory old =
            StreamCurrentStackPlan.readPointer(assemblyCore, AUTHORITY_POINTER);
        _selectAuthorityPointer(
            StreamCurrentStackPlan.pointerState(
                address(assemblyModules), admitted, false, old.revision + 1
            )
        );
        _rightsVerifyAndObserve(source.registry, unproven.registry, leaves);
        // Core admitted the genuine original55 predecessor. Both original lane tips and the
        // source's original57 terminal cutover are real. Only atomic seven-owner op60 is pending.
        for (uint256 i; i < 7; ++i) {
            require(
                AuthorityOwner(unproven.owners[i]).authorityHydrationCommitment() == 0,
                "unhydrated actual owner"
            );
        }
        (bool resolve,) = address(assemblyAuthorityResolver)
            .staticcall(abi.encodeCall(assemblyAuthorityResolver.currentSelection, ()));
        require(!resolve, "real resolver refuses pointer without authority provenance");
        (bool read,) = address(freshRights)
            .staticcall(
                abi.encodeCall(
                    freshRights.requireCurrent,
                    (1, _assemblySubject(), assemblyRightsRecord, uint64(1))
                )
            );
        (bool context,) = address(freshRights)
            .staticcall(abi.encodeCall(freshRights.currentArtistIdentityContext, ()));
        (bool select,) = address(freshRights).call(exactSelection);
        (bool seal,) = address(freshRights)
            .staticcall(
                abi.encodeCall(
                    freshRights.selectionLockTransition,
                    (1, _assemblySubject(), assemblyRightsRecord, uint64(1))
                )
            );
        (bool constructorAccepted,) =
            address(this).call(abi.encodeCall(this.deployCurrentRightsForTest, ()));
        require(
            !read && !context && !select && !seal && !constructorAccepted,
            "all current uses, even ACCOUNT, fail closed"
        );
        require(
            keccak256(abi.encode(freshRights.currentRights(1, _assemblySubject())))
                    == keccak256(abi.encode(originalFreshSelection))
                && keccak256(abi.encode(retainedRights.selectionLock(1, _assemblySubject())))
                    == keccak256(abi.encode(originalRightsSeal)),
            "refusal retains full history and historical original seal"
        );
        AuthorityRecoveredTypes.Request memory request = _rightsRequest(source);
        Commit.Prepared memory prepared = Prepared.prepare(unproven, request);
        request.expectedSemanticInventory = Prepared.inventory(prepared);
        bytes32 sourceBefore = _rightsOwnerState(source);
        _rightsSafeCall(
            unproven.registry,
            abi.encodeCall(AuthorityRecoveredEntry.hydrateRecoveredArtistAuthority, (request))
        );
        require(_rightsOwnerState(source) == sourceBefore, "actual source unchanged by hydration");
        _rightsAssertImport(unproven, prepared);
        assemblySuite = unproven;
        assemblyArtists = StreamArtistOnboardingRegistry(payable(unproven.registry));
        assemblyCoordinator = coordinator;
        assemblyArtistNonce =
        IStreamArtistIdentityOwner(unproven.owners[2]).identity(assemblyArtistId).nonceHint;
        authorityEra = 1;
        authorityRegistries[1] = unproven.registry;
        authorityCoordinators[1] = address(coordinator);
        authorityConfigurations[1] = coordinator.configurationHash();
        authorityOwnFinalities[1] = coordinator.finalityRegistry();
        authorityOwnProviders[1] = coordinator.finalityEvidenceProvider();
        _authorityRequireOriginals();
        _authorityRequireRoute();
        _assertCurrentIdentityContext();
        (bool retried, bytes memory result) = address(freshRights).call(exactSelection);
        require(
            retried,
            "identical record/witness/predecessor succeeds after genuine seven-owner hydration"
        );
        RightsAPI.Selection memory selected = abi.decode(result, (RightsAPI.Selection));
        require(
            selected.revision == 2 && selected.recordHash == nextRecord,
            "one successful append only"
        );
        _assertLiteralSelection(freshRights, selected);
        _assertCurrent(freshRights, selected);
        _assertRetainedA();
    }

    function testActualUnknownArtistAndForeignSchemaOrChainKeepHistoryReadable() public {
        RightsTypes.Statement memory unknown = _statement(assemblyRightsRecord, true);
        unknown.licensor.artistId = keccak256("never registered in actual Identity owner");
        (
            bytes32 unknownRecord,
            IStreamPreservationRecords.CollectionRecord memory unknownOriginal
        ) = _recordRights(unknown, "urn:current-rights:unknown-documentary-artist");
        (bool selected, bytes memory error_) = address(freshRights)
            .call(
                abi.encodeCall(
                    freshRights.selectCurrentWithRecord,
                    (
                        1,
                        _assemblySubject(),
                        unknownRecord,
                        assemblyRightsRecord,
                        uint64(1),
                        RightsWitness.Witness(unknownOriginal, unknown)
                    )
                )
            );
        require(
            !selected
                && keccak256(error_)
                    == keccak256(
                        abi.encodeWithSelector(
                            StreamRecordArtistIdentityReads.UnknownRecordArtist.selector,
                            unknown.licensor.artistId
                        )
                    ),
            "actual current Identity has no registration for supplied documentary artist"
        );
        require(
            keccak256(abi.encode(freshRights.currentRights(1, _assemblySubject())))
                == keccak256(abi.encode(originalFreshSelection)),
            "unknown generic append cannot replace the selected head"
        );
        StreamSchemaRegistry foreign = new StreamSchemaRegistry(address(assemblyExecutor));
        (bool foreignAccepted,) = address(this)
            .call(abi.encodeCall(this.deployRightsWithSchemasForTest, (address(foreign))));
        require(
            !foreignAccepted,
            "another genuine schema deployment cannot replace original Metadata pins"
        );
        uint256 originalChain = freshRights.deploymentChainId();
        bytes32 subject = _assemblySubject();
        CurrentRightsChainVm(address(assemblyVm)).chainId(originalChain + 1);
        (bool current, bytes memory chainError) = address(freshRights)
            .staticcall(
                abi.encodeCall(
                    freshRights.requireCurrent, (1, subject, assemblyRightsRecord, uint64(1))
                )
            );
        require(
            !current
                && keccak256(chainError)
                    == keccak256(
                        abi.encodeWithSelector(
                            RightsAPI.RightsDependencyChanged.selector, address(assemblyCore)
                        )
                    ),
            "exact original chain bound on current use"
        );
        require(
            keccak256(abi.encode(freshRights.rightsSelectionAt(1, subject, 1)))
                == keccak256(abi.encode(originalFreshSelection)),
            "historical tuple is independent of today's eligibility"
        );
        CurrentRightsChainVm(address(assemblyVm)).chainId(originalChain);
        _assertRetainedA();
        RightsTypes.Statement memory known = _statement(assemblyRightsRecord, true);
        (bytes32 knownRecord, IStreamPreservationRecords.CollectionRecord memory knownOriginal) =
            _recordRights(known, "urn:current-rights:known-documentary-artist");
        RightsAPI.Selection memory fresh = freshRights.selectCurrentWithRecord(
            1,
            subject,
            knownRecord,
            assemblyRightsRecord,
            1,
            RightsWitness.Witness(knownOriginal, known)
        );
        require(
            fresh.artistIdentityRecordHash == originalRegistration
                && fresh.recordIndex > originalFreshSelection.recordIndex + 1,
            "later valid original may bypass an unselected generic dossier append"
        );
        _assertLiteralSelection(freshRights, fresh);
        _assertCurrent(freshRights, fresh);
    }

    function deployCurrentRightsForTest() external returns (address) {
        require(msg.sender == address(this), "test constructor probe only");
        return address(_newRights());
    }

    function deployRightsWithSchemasForTest(address schemas_) external returns (address) {
        require(msg.sender == address(this), "test constructor probe only");
        return address(
            new StreamCurrentAuthorityRightsRecordSelection(
                address(assemblyCore), address(assemblyMetadata), schemas_
            )
        );
    }

    function _newRights() private returns (StreamCurrentAuthorityRightsRecordSelection) {
        return new StreamCurrentAuthorityRightsRecordSelection(
            address(assemblyCore), address(assemblyMetadata), address(assemblySchemas)
        );
    }

    function _statement(bytes32 predecessor, bool artist)
        private
        view
        returns (RightsTypes.Statement memory s)
    {
        s = abi.decode(abi.encode(assemblyRightsStatement), (RightsTypes.Statement));
        s.predecessor = predecessor;
        s.grants.exhibition.status = RightsTypes.Status.GRANTED;
        if (artist) {
            s.licensor.kind = RightsTypes.LicensorKind.ARTIST;
            s.licensor.artistId = assemblyArtistId;
            s.licensor.account = address(0);
        }
    }

    function _recordRights(RightsTypes.Statement memory statement, string memory uri)
        private
        returns (bytes32 key, IStreamPreservationRecords.CollectionRecord memory r)
    {
        bytes memory raw = StreamRightsRecordJson.serialize(statement);
        r.recordType = keccak256("RIGHTS_STATEMENT");
        r.subjectId = _assemblySubject();
        r.schemaId = StreamRightsRecordDefinitions.SCHEMA_ID;
        r.effectiveAt = uint64(block.timestamp);
        r.uri = uri;
        r.contentHash = IStreamPreservationRecords.HashRef(
            1, abi.encodePacked(keccak256(raw)), keccak256("RFC8785_JCS")
        );
        key = assemblyMetadata.recordCollectionRecordWithPayload(1, r, raw);
        require(
            key
                == keccak256(
                    abi.encode(
                        keccak256("6529stream.preservation-record.v2"),
                        block.chainid,
                        address(assemblyMetadata),
                        address(assemblyCore),
                        address(this),
                        uint256(1),
                        r.recordType,
                        r.subjectId,
                        keccak256(
                            abi.encode(
                                r.contentHash.algorithm,
                                keccak256(r.contentHash.digest),
                                r.contentHash.canonicalizationId
                            )
                        ),
                        keccak256(bytes(r.uri)),
                        r.schemaId,
                        bytes32(0),
                        keccak256(abi.encode(uint16(0), keccak256(bytes("")), bytes32(0))),
                        r.effectiveAt
                    )
                ),
            "literal original fourteen-word Metadata record hash"
        );
        (
            IStreamPreservationRecords.CollectionRecord memory stored,
            IStreamCollectionMetadataV1.RecordReceipt memory receipt
        ) = assemblyMetadata.collectionRecord(key);
        require(
            keccak256(abi.encode(stored)) == keccak256(abi.encode(r))
                && receipt.recorder == address(this) && receipt.authorizationClass == 7
                && receipt.artistAuthorization == 0,
            "genuine original ACCOUNT-class7 receipt and complete bytes"
        );
    }

    function _assertLiteralSelection(
        StreamCurrentAuthorityRightsRecordSelection selector,
        RightsAPI.Selection memory selected
    ) private view {
        RightsAPI.Selection memory preimage = abi.decode(
            abi.encode(selected), (RightsAPI.Selection)
        );
        preimage.selectionHash = 0;
        require(
            selected.selectionHash
                == keccak256(
                    abi.encode(
                        keccak256("6529STREAM_RIGHTS_SELECTION_V1"),
                        selector.deploymentChainId(),
                        address(selector),
                        address(assemblyCore),
                        address(assemblyMetadata),
                        address(assemblySchemas),
                        selector.chunkStore(),
                        uint256(1),
                        _assemblySubject(),
                        preimage
                    )
                ),
            "unchanged literal original Rights selection domain and tuple"
        );
    }

    function _assertCurrent(
        StreamCurrentAuthorityRightsRecordSelection selector,
        RightsAPI.Selection memory selected
    ) private view {
        require(
            keccak256(
                abi.encode(
                    selector.requireCurrent(
                        1, _assemblySubject(), selected.recordHash, selected.revision
                    )
                )
            ) == keccak256(abi.encode(selected)),
            "exact retained selected tuple remains currently eligible"
        );
    }

    function _assertRetainedA() private view {
        _assertCurrent(retainedRights, originalRetainedSelection);
        require(
            keccak256(abi.encode(retainedRights.rightsSelectionAt(1, _assemblySubject(), 1)))
                    == keccak256(abi.encode(originalRetainedSelection))
                && keccak256(abi.encode(retainedRights.selectionLock(1, _assemblySubject())))
                    == keccak256(abi.encode(originalRightsSeal)),
            "full original A selection and seal unchanged"
        );
    }

    function _assertCurrentIdentityContext() private view {
        (address[3] memory targets, bytes32[3] memory hashes) =
            freshRights.currentArtistIdentityContext();
        require(
            targets[0] == address(assemblyArtists) && targets[1] == address(assemblyCoordinator)
                && targets[2] == assemblySuite.owners[2],
            "actual current facade Coordinator and Identity owner, never a constructor A equality constraint"
        );
        for (uint256 i; i < 3; ++i) {
            require(
                hashes[i] == targets[i].codehash && targets[i].code.length != 0,
                "actual current runtime pins"
            );
        }
        require(
            assemblyMetadata.artistRegistry() == authorityOriginalSuite.registry,
            "original Metadata ancestry anchor is unchanged"
        );
    }

    function _originalReceiptHash() private view returns (bytes32) {
        (
            IStreamPreservationRecords.CollectionRecord memory record,
            IStreamCollectionMetadataV1.RecordReceipt memory receipt
        ) = assemblyMetadata.collectionRecord(assemblyRightsRecord);
        (, bytes memory payload) = assemblyMetadata.recordPayload(assemblyRightsRecord);
        return keccak256(abi.encode(record, receipt, payload));
    }

    function _sealRights(
        StreamCurrentAuthorityRightsRecordSelection selector,
        bytes32 record,
        uint64 revision
    ) private returns (RightsLock.SelectionLock memory seal) {
        (bytes32 scope, bytes32 before_, bytes32 after_) =
            selector.selectionLockTransition(1, _assemblySubject(), record, revision);
        bytes32 action = _assemblyGovernanceCall(
            2,
            address(selector),
            abi.encodeCall(selector.lockSelection, (1, _assemblySubject(), record, revision)),
            scope,
            before_,
            after_
        );
        seal = selector.selectionLock(1, _assemblySubject());
        require(
            seal.locked && seal.recordHash == record && seal.revision == revision
                && seal.actionId == action && seal.executor == address(assemblyExecutor)
                && seal.governanceRoot == address(assemblyRoot)
                && assemblyExecutor.governanceAction(action).status
                    == GovernanceActionStatus.EXECUTED,
            "actual delayed TERMINAL_FREEZE root Safe action seals the original head"
        );
    }

    function _assertBothSelectionEntrypointsLocked(
        StreamCurrentAuthorityRightsRecordSelection selector,
        bytes32 record,
        IStreamPreservationRecords.CollectionRecord memory original,
        RightsTypes.Statement memory statement
    ) private {
        bytes memory expected = abi.encodeWithSelector(
            RightsLock.RecordSelectionLocked.selector, uint256(1), _assemblySubject()
        );
        (bool a, bytes memory x) = address(selector)
            .call(
                abi.encodeCall(
                    selector.selectCurrent,
                    (1, _assemblySubject(), record, assemblyRightsRecord, uint64(1), statement)
                )
            );
        (bool b, bytes memory y) = address(selector)
            .call(
                abi.encodeCall(
                    selector.selectCurrentWithRecord,
                    (
                        1,
                        _assemblySubject(),
                        record,
                        assemblyRightsRecord,
                        uint64(1),
                        RightsWitness.Witness(original, statement)
                    )
                )
            );
        require(
            !a && !b && keccak256(x) == keccak256(expected) && keccak256(y) == keccak256(expected),
            "both unchanged selector entrypoints retain exact permanent seal error"
        );
    }

    function _admitUnprovenAuthority(address target)
        private
        returns (StreamModuleRegistration memory row)
    {
        row = _assemblyModule(
            target,
            AUTHORITY_POINTER,
            type(IStreamArtistMintConsent).interfaceId,
            keccak256(abi.encode("current Rights unproven successor", target))
        );
        StreamModuleRegistration[] memory rows = new StreamModuleRegistration[](1);
        rows[0] = row;
        (GovernanceCall[] memory calls, bytes[] memory data) =
            StreamCurrentStackPlan.registrationCalls(assemblyModules, rows);
        GenesisBatch memory batch = GenesisBatch(1, calls, data);
        _admitAssemblyBatch(batch);
        _assemblyGovernance(batch, "urn:current-rights:admit-unproven-successor");
    }

    function _selectAuthorityPointer(StreamCorePointerState memory desired) private {
        StreamCorePointerState memory old =
            StreamCurrentStackPlan.readPointer(assemblyCore, AUTHORITY_POINTER);
        (bytes32 scope, bytes32 before_, bytes32 after_) = StreamCurrentStackPlan.pointerTransitionHashes(
            assemblyCore, AUTHORITY_POINTER, old, desired
        );
        GenesisBatch memory batch;
        batch.actionClass = 3;
        batch.calls = new GovernanceCall[](2);
        batch.callDatas = new bytes[](2);
        batch.callDatas[0] = abi.encodeCall(
            assemblyCore.updateSatellitePointer, (AUTHORITY_POINTER, desired.target)
        );
        batch.calls[0] = StreamCurrentStackPlan.call(
            address(assemblyCore), batch.callDatas[0], scope, before_, after_
        );
        StreamSystemManifest.ModuleAddresses memory modules =
        StreamGenesisManifestPlan.readAggregate(assemblyManifest).modules;
        modules.artistRegistry = desired.target;
        (batch.calls[1], batch.callDatas[1]) =
            _assemblyPublishManifest(modules, AUTHORITY_MIGRATION_REASON);
        _admitAssemblyBatch(batch);
        _assemblyGovernance(batch, AUTHORITY_MIGRATION_URI);
        StreamCorePointerState memory actual =
            StreamCurrentStackPlan.readPointer(assemblyCore, AUTHORITY_POINTER);
        require(
            keccak256(abi.encode(actual)) == keccak256(abi.encode(desired)),
            "actual governed pointer equals independently planned current pin tuple"
        );
    }

    // Frozen private ceremony helpers from StreamCurrentAuthorityMigrationRecipe at base
    // 0aee507bb0648a90ebc4e41059cc610a828d724c. Bodies are preserved with only local
    // helper names changed, so this case can pause before op60 without editing shared fixtures.
    function _rightsRun(GenesisBatch memory batch) private returns (bytes32 action) {
        _admitAssemblyBatch(batch);
        action = _assemblyGovernance(batch, AUTHORITY_MIGRATION_URI);
    }

    function _rightsBindHistory(address source, address destination)
        private
        returns (HT.Leaf[] memory leaves)
    {
        leaves = _rightsLeaves(source);
        (bytes32 root,) = _rightsProof(source, leaves, 0);
        HT.Binding memory binding_ =
            HT.Binding(source, uint64(block.number), root, AUTHORITY_MIGRATION_REASON);
        HT.Context memory context_ = History(destination)
            .artistHistoryImportContext(
                source, binding_.snapshotBlock, root, AUTHORITY_MIGRATION_REASON
            );
        GenesisBatch memory batch;
        batch.actionClass = 1;
        batch.calls = new GovernanceCall[](1);
        batch.callDatas = new bytes[](1);
        batch.callDatas[0] = abi.encodeCall(
            History.commitArtistHistoryImportRoot,
            (source, binding_.snapshotBlock, root, AUTHORITY_MIGRATION_REASON)
        );
        batch.calls[0] = StreamCurrentStackPlan.call(
            destination,
            batch.callDatas[0],
            context_.scopeHash,
            context_.oldValueHash,
            context_.newValueHash
        );
        bytes32 action = _rightsRun(batch);
        (bool committed, bytes32 hash, uint256 count) =
            History(destination).artistHistoryPredecessorBinding(source);
        require(
            committed && hash == source.codehash && count == 1,
            "actual original55 predecessor admission"
        );
        _authorityCandidate(
            2,
            "identity_authority.replay.governance_action",
            keccak256(
                abi.encode(action, context_.scopeHash, context_.oldValueHash, context_.newValueHash)
            )
        );
        _authorityCandidate(
            2, "identity_authority.replay.import_binding_key", keccak256(abi.encode(binding_))
        );
    }

    function _rightsVerifyAndObserve(address source, address destination, HT.Leaf[] memory leaves)
        private
    {
        (, uint64 count) = History(source).artistHistoryLane(1, assemblyArtistId);
        _rightsVerify(destination, source, leaves, count - 1);
        _rightsVerify(destination, source, leaves, leaves.length - 1);
        _rightsSafeCall(source, abi.encodeCall(History.observeRegistryCutover, ()));
        _authorityCandidate(2, "identity_authority.replay.one_way_cutover_latch", 0);
        (bool observed, address next,) = History(source).artistRegistryCutover();
        require(observed && next == destination, "actual source57 terminal cutover");
    }

    function _rightsVerify(
        address destination,
        address source,
        HT.Leaf[] memory leaves,
        uint256 index
    ) private {
        (, bytes32[] memory proof) = _rightsProof(source, leaves, index);
        HT.Leaf memory row = leaves[index];
        _rightsSafeCall(
            destination, abi.encodeCall(History.verifyImportedLaneTip, (uint256(0), row, proof))
        );
        _authorityCandidate(
            2,
            "identity_authority.replay.verified_lane_key",
            keccak256(abi.encode(row.laneKind, row.laneKey))
        );
        _authorityCandidate(
            2,
            "identity_authority.replay.import_binding",
            keccak256(abi.encode(uint256(0), row.laneKind, row.laneKey))
        );
    }

    function _rightsSafeCall(address target, bytes memory data) private {
        uint256 nonce = assemblyArtist.nonce();
        require(
            executeSafe(assemblyArtist, assemblyArtistKeys, target, 0, data, 0),
            "actual recovered threshold Safe call"
        );
        require(assemblyArtist.nonce() == nonce + 1, "exact actual Safe transaction consumed");
    }

    function _rightsRequest(T.SuiteConfiguration memory source)
        private
        view
        returns (AuthorityRecoveredTypes.Request memory p)
    {
        p.records.authority.artistIds = new bytes32[](1);
        p.records.authority.artistIds[0] = assemblyArtistId;
        p.records.authority.collections = new MH.Collection[](1);
        p.records.authority.collections[0] = MH.Collection(assemblyArtistId, 1, authorityPolicies);
        p.records.witnesses = new MR.CollectionWitness[](1);
        p.records.witnesses[0] = MR.CollectionWitness(1, authorityEconomics, authorityAttestations);
        p.expectedSourceImportCommitment =
            AuthorityOwner(source.owners[2]).authorityHydrationCommitment();
        AuthorityRecoveredTypes.OriginEnvironment memory environment = _rightsEnvironment(source);
        for (uint8 i; i < 7; ++i) {
            p.expectedCapabilities[i] =
                RecoveredOwner(source.owners[i]).recoveredAuthorityHydrationCapability();
            CP.Checkpoint memory cp = CP(source.owners[i]).authorityCheckpoint();
            p.records.authority.expectedSource[i] = cp;
            p.records.authority.replayOrigins[i] = new AH.Origin[](cp.replayCount);
            for (uint256 j; j < cp.replayCount; ++j) {
                (bytes32 key,) = CP(source.owners[i]).authorityReplayAt(j);
                bool found;
                for (uint256 k; k < authorityCandidates[i].length; ++k) {
                    AH.Origin memory origin = authorityCandidates[i][k];
                    if (Guards.replayKey(environment, i, origin) != key) continue;
                    p.records.authority.replayOrigins[i][j] = origin;
                    found = true;
                    break;
                }
                require(found, "every actual source guard has its literal writer preimage");
            }
        }
    }

    function _rightsEnvironment(T.SuiteConfiguration memory suite)
        private
        view
        returns (AuthorityRecoveredTypes.OriginEnvironment memory e)
    {
        e.chainId = block.chainid;
        e.registry = suite.registry;
        e.coordinator =
            StreamArtistOnboardingRegistry(payable(suite.registry)).operationCoordinator();
        e.archive = suite.archive;
        e.owners = suite.owners;
        for (uint256 i; i < 7; ++i) {
            e.ownerCodeHashes[i] = suite.owners[i].codehash;
        }
        e.core = suite.core;
        e.manager = suite.mintManager;
        e.suiteConfigurationHash = keccak256(abi.encode(suite));
    }

    function _rightsOwnerState(T.SuiteConfiguration memory suite)
        private
        view
        returns (bytes32 value)
    {
        for (uint8 i; i < 7; ++i) {
            CP.Checkpoint memory cp = CP(suite.owners[i]).authorityCheckpoint();
            value = keccak256(
                abi.encode(
                    value,
                    cp,
                    Publications.collect(suite.owners[i], i),
                    Guards.collectNonces(suite.owners[i], cp),
                    IStreamArtistNativeReceipts(suite.owners[i]).artistNativeReceiptCount(),
                    AuthorityOwner(suite.owners[i]).authorityHydrationCommitment()
                )
            );
        }
        return keccak256(
            abi.encode(value, History(suite.owners[2]).artistHistoryContinuityCommitment())
        );
    }

    function _rightsAssertImport(
        T.SuiteConfiguration memory destination,
        Commit.Prepared memory prepared
    ) private view {
        bytes32 completion = AuthorityOwner(destination.owners[2]).authorityHydrationCommitment();
        require(completion != 0, "actual atomic recovered completion");
        for (uint8 i; i < 7; ++i) {
            address owner = destination.owners[i];
            T.Snapshot memory now_ = IStreamArtistOwner(owner).ownerStateSnapshotV2();
            require(
                now_.revision == prepared.admission.before_[i].revision + 1
                    && now_.recordChainTip == prepared.admission.before_[i].recordChainTip
                    && AuthorityOwner(owner).authorityHydrationCommitment() == completion,
                "seven exact original owner commits"
            );
            require(
                IStreamArtistNativeReceipts(owner).artistNativeReceiptCount() == 0,
                "import does not fabricate native receipts"
            );
            (
                AuthorityRecoveredTypes.OwnerProvenance memory prefix,
                bytes32 imported,
                uint64 revision
            ) = RecoveredOwner(owner).recoveredHydrationImportedPrefix();
            require(
                imported == completion && revision == now_.revision
                    && keccak256(abi.encode(prefix))
                        == keccak256(
                            abi.encode(
                                AuthorityRecoveredTypes.ownerProvenance(
                                    prepared.admission.provenance, i
                                )
                            )
                        ),
                "exact original flattened provenance"
            );
            (, Payload.Payload memory payload) = Payload.decode(prepared.data[i].typedState, i);
            require(
                keccak256(abi.encode(Publications.collect(owner, i)))
                    == keccak256(abi.encode(payload.publications)),
                "all original publication catalogs retained"
            );
        }
    }

    function _rightsLeaves(address source) private view returns (HT.Leaf[] memory rows) {
        History h = History(source);
        (, uint64 a) = h.artistHistoryLane(1, assemblyArtistId);
        (, uint64 b) = h.artistHistoryLane(2, bytes32(uint256(1)));
        require(a != 0 && b != 0, "actual nonempty artist and collection histories");
        rows = new HT.Leaf[](uint256(a) + b);
        for (uint64 i; i < a; ++i) {
            (bytes32 r, bytes32 c) = h.artistHistoryRecordAt(1, assemblyArtistId, i);
            rows[i] = HT.Leaf(1, assemblyArtistId, i, r, c);
        }
        for (uint64 i; i < b; ++i) {
            (bytes32 r, bytes32 c) = h.artistHistoryRecordAt(2, bytes32(uint256(1)), i);
            rows[uint256(a) + i] = HT.Leaf(2, bytes32(uint256(1)), i, r, c);
        }
    }

    function _rightsProof(address source, HT.Leaf[] memory leaves, uint256 index)
        private
        view
        returns (bytes32 root, bytes32[] memory proof)
    {
        bytes32[] memory layer = new bytes32[](leaves.length);
        proof = new bytes32[](64);
        uint256 used;
        uint256 n = leaves.length;
        for (uint256 i; i < n; ++i) {
            HT.Leaf memory p = leaves[i];
            layer[i] = keccak256(
                bytes.concat(
                    keccak256(
                        abi.encode(
                            bytes32(
                                0xea04da6644046a7c731e99312c32df311e81aa7e137dfc2a49c2116bb325195d
                            ),
                            block.chainid,
                            source,
                            p.laneKind,
                            p.laneKey,
                            p.sequence,
                            p.recordHash,
                            p.recordChainHash
                        )
                    )
                )
            );
        }
        while (n > 1) {
            if ((index ^ 1) < n) proof[used++] = layer[index ^ 1];
            uint256 nextN = (n + 1) / 2;
            for (uint256 i; i < nextN; ++i) {
                uint256 j = i * 2;
                if (j + 1 == n) {
                    layer[i] = layer[j];
                } else {
                    bytes32 a = layer[j];
                    bytes32 b = layer[j + 1];
                    layer[i] = a < b ? keccak256(abi.encode(a, b)) : keccak256(abi.encode(b, a));
                }
            }
            index /= 2;
            n = nextN;
        }
        root = layer[0];
        assembly ("memory-safe") { mstore(proof, used) }
    }
}
