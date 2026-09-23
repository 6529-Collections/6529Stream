// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./StreamCollectionMetadataV1.t.sol";
import {
    RecordArtistReadFixture,
    RecordArtistReadReplacement
} from "./StreamRecordArtistIdentityReads.t.sol";
import { RightsSelectionFileVm } from "./StreamRightsRecordSelection.t.sol";
import "../../helpers/RecordSelectionLockFixture.sol";
import "../../../smart-contracts/domains/metadata/StreamCurrentAuthorityRightsRecordSelection.sol";
import {
    StreamRightsRecordSelection as LegacyRights
} from "../../../smart-contracts/domains/metadata/StreamRightsRecordSelection.sol";

/// @notice Real Metadata, Schema/Store, record reads and Rights state; explicitly typed Artist graph.
/// @dev These cases do not prove op60 succession, real Artist authority or legal ownership.
/// The genuine current-stack succession fixture is separate. Governance seal context uses the
/// existing named boundary; no production scheduling, veto or threshold-Safe claim is made here.
contract StreamCurrentAuthorityRightsRecordSelectionTest is
    CollectionMetadataV1Fixture,
    RecordSelectionLockFixture
{
    StreamCurrentAuthorityRightsRecordSelection private current;
    LegacyRights private legacy;
    RecordArtistReadFixture private facade;
    RecordArtistReadFixture private coordinator;
    RecordArtistReadFixture private identity;
    bytes32 private constant RIGHTS_KIND = keccak256("RIGHTS_STATEMENT");
    bytes32 private constant REGISTRATION = bytes32(uint256(77));
    bytes4 private constant SUITE = bytes4(keccak256("suiteConfiguration()"));
    bytes4 private constant AUTHORITY = bytes4(keccak256("authorityState(bytes32)"));

    function _prepareCurrent() private {
        RightsSelectionFileVm files = RightsSelectionFileVm(address(vm));
        _register(
            "RFC8785_JCS",
            IStreamSchemaRegistry.DocumentKind.CANONICALIZATION,
            files.readFileBinary("schemas/museum/account-profile/RFC8785_JCS.json")
        );
        _register(
            "STREAM_RIGHTS_JSON_PROFILE_V1",
            IStreamSchemaRegistry.DocumentKind.CATALOG,
            files.readFileBinary("schemas/records/STREAM_RIGHTS_JSON_PROFILE_V1.json")
        );
        bytes memory raw = files.readFileBinary("schemas/records/STREAM_RIGHTS_V1.json");
        bytes32[] memory chunks = new bytes32[]((raw.length + 8191) / 8192);
        for (uint256 i; i < chunks.length; ++i) {
            uint256 length = raw.length - i * 8192;
            if (length > 8192) length = 8192;
            bytes memory chunk = new bytes(length);
            for (uint256 j; j < length; ++j) {
                chunk[j] = raw[i * 8192 + j];
            }
            (chunks[i],) = store.publishChunk(chunk);
        }
        IStreamSchemaRegistry.DocumentSpec memory spec = IStreamSchemaRegistry.DocumentSpec(
            "STREAM_RIGHTS_V1",
            IStreamSchemaRegistry.DocumentKind.SCHEMA,
            keccak256(raw),
            schemas.RAW_BYTES(),
            0,
            "",
            uint32(raw.length)
        );
        (bytes32 scope, bytes32 oldHash, bytes32 nextHash) =
            schemas.registrationTransition(spec, chunks);
        executor.execute(
            address(schemas),
            abi.encodeCall(schemas.registerDocument, (spec, chunks)),
            scope,
            oldHash,
            nextHash
        );
        facade = new RecordArtistReadFixture();
        coordinator = new RecordArtistReadFixture();
        identity = new RecordArtistReadFixture();
        facade.set(bytes4(keccak256("core()")), abi.encode(address(core)));
        facade.set(bytes4(keccak256("operationCoordinator()")), abi.encode(address(coordinator)));
        coordinator.set(bytes4(keccak256("deploymentChainId()")), abi.encode(block.chainid));
        coordinator.set(SUITE, _suite());
        identity.set(bytes4(keccak256("core()")), abi.encode(address(core)));
        identity.set(bytes4(keccak256("artistRegistry()")), abi.encode(address(facade)));
        identity.set(bytes4(keccak256("operationCoordinator()")), abi.encode(address(coordinator)));
        identity.set(bytes4(keccak256("deploymentChainId()")), abi.encode(block.chainid));
        identity.set(AUTHORITY, abi.encode(address(0), uint8(0), uint8(0), REGISTRATION));
        // Original metadata remains bound to this facade, even when later selectors resolve current authority.
        StreamCollectionMetadataV1.Configuration memory c;
        c.core = address(core);
        c.executor = address(executor);
        c.schemas = address(schemas);
        c.artistRegistry = address(facade);
        c.deploymentManifestHash = bytes32(uint256(1));
        c.manifestHash = bytes32(uint256(2));
        c.manifestURI = "ipfs://metadata-module";
        c.dependencyReadGas = IStreamGasParameterHost.GasParameterConfig(
            "METADATA_DEPENDENCY_READ_GAS", 150000, 100000, 2
        );
        c.artistReadGas = IStreamGasParameterHost.GasParameterConfig(
            "METADATA_ARTIST_READ_GAS", 2000000, 1000000, 2
        );
        metadata = new StreamCollectionMetadataV1(c);
        core.setPointer(keccak256("COLLECTION_METADATA"), address(metadata));
        core.setPointer(keccak256("ARTIST_REGISTRY"), address(facade));
        _admit(RIGHTS_KIND, StreamRecordFamilies.RIGHTS, 0x0180);
        _grant(1, StreamRecordFamilies.RIGHTS, 7, address(this), true);
        legacy = new LegacyRights(address(core), address(metadata), address(schemas));
        current = new StreamCurrentAuthorityRightsRecordSelection(
            address(core), address(metadata), address(schemas)
        );
    }

    function _suite() private view returns (bytes memory) {
        uint256[17] memory words;
        words[0] = uint160(address(facade));
        words[4] = uint160(address(identity));
        words[9] = uint160(address(core));
        return abi.encode(words);
    }

    function _statement() private view returns (StreamRightsRecordTypes.Statement memory s) {
        s.subjectId = subject;
        s.profileHash = StreamRightsRecordDefinitions.PROFILE_HASH;
        s.licensor.kind = StreamRightsRecordTypes.LicensorKind.ACCOUNT;
        s.licensor.account = address(0x123);
        s.startDate = 20260912;
        s.openEnd = true;
    }

    function _publish(StreamRightsRecordTypes.Statement memory s, uint64 effectiveAt)
        private
        returns (bytes32 hash, IStreamRightsRecordWitnessSelection.Witness memory w)
    {
        bytes memory payload = StreamRightsRecordJson.serialize(s);
        w.statement = s;
        w.original = _record(RIGHTS_KIND, payload);
        w.original.subjectId = s.subjectId;
        w.original.schemaId = StreamRightsRecordDefinitions.SCHEMA_ID;
        w.original.contentHash.canonicalizationId = StreamRightsRecordDefinitions.CANON_ID;
        w.original.effectiveAt = effectiveAt;
        hash = metadata.recordCollectionRecordWithPayload(1, w.original, payload);
    }

    function _select(
        bytes32 hash,
        StreamRightsRecordTypes.Statement memory s,
        bytes32 head,
        uint64 revision
    ) private returns (IStreamRightsRecordSelection.Selection memory) {
        return current.selectCurrent(1, s.subjectId, hash, head, revision, s);
    }

    function _literalFirst(address selector, bytes32 record, bytes32 payload, bytes32 registration)
        private
        view
        returns (bytes32)
    {
        bytes32[23] memory words;
        words[0] = keccak256("6529STREAM_RIGHTS_SELECTION_V1");
        words[1] = bytes32(block.chainid);
        words[2] = bytes32(uint256(uint160(selector)));
        words[3] = bytes32(uint256(uint160(address(core))));
        words[4] = bytes32(uint256(uint160(address(metadata))));
        words[5] = bytes32(uint256(uint160(address(schemas))));
        words[6] = bytes32(uint256(uint160(address(store))));
        words[7] = bytes32(uint256(1));
        words[8] = subject;
        words[9] = record;
        words[11] = payload;
        words[12] = bytes32(uint256(uint160(address(this))));
        words[13] = bytes32(uint256(1));
        words[14] = bytes32(uint256(1));
        words[15] = bytes32(uint256(1));
        words[17] = bytes32(block.timestamp);
        words[18] = bytes32(uint256(7));
        words[19] = bytes32(uint256(uint160(address(this))));
        words[20] = bytes32(uint256(7));
        words[21] = registration;
        return keccak256(abi.encode(words));
    }

    function testOriginalInterfacesRecordHashSelectionMeaningAndEventArePreserved() public {
        _prepareCurrent();
        require(
            current.currentAuthorityProfile()
                == keccak256("6529STREAM_CURRENT_AUTHORITY_RIGHTS_SELECTION_V1"),
            "closed current authority profile"
        );
        require(
            current.supportsInterface(type(IStreamRightsRecordCurrentAuthority).interfaceId)
                && !legacy.supportsInterface(type(IStreamRightsRecordCurrentAuthority).interfaceId),
            "distinct additive capability"
        );
        (address[3] memory targets, bytes32[3] memory pins) = current.currentArtistIdentityContext();
        require(
            targets[0] == address(facade) && targets[1] == address(coordinator)
                && targets[2] == address(identity),
            "exact ordered Identity graph"
        );
        for (uint256 i; i < 3; ++i) {
            require(pins[i] == targets[i].codehash, "exact current runtime pins");
        }
        require(
            current.supportsInterface(type(IStreamRightsRecordSelection).interfaceId)
                && current.supportsInterface(type(IStreamRightsRecordWitnessSelection).interfaceId)
                && current.supportsInterface(type(IStreamRecordSelectionLock).interfaceId)
                && !current.supportsInterface(0xffffffff),
            "preserved capabilities"
        );
        require(
            current.core() == address(core) && current.metadata() == address(metadata)
                && current.schemaRegistry() == address(schemas)
                && current.chunkStore() == address(store)
                && current.deploymentChainId() == block.chainid,
            "same original anchors"
        );
        StreamRightsRecordTypes.Statement memory s = _statement();
        (bytes32 hash, IStreamRightsRecordWitnessSelection.Witness memory w) = _publish(s, 1);
        require(
            hash == _oldRecordHash(address(this), w.original), "original fourteen-word host record"
        );
        IStreamRightsRecordSelection.Selection memory old =
            legacy.selectCurrent(1, subject, hash, 0, 0, s);
        vm.recordLogs();
        IStreamRightsRecordSelection.Selection memory next = _select(hash, s, 0, 0);
        Vm.Log[] memory logs = vm.getRecordedLogs();
        require(
            logs.length == 1 && logs[0].emitter == address(current) && logs[0].topics.length == 4,
            "one selection event"
        );
        require(
            logs[0].topics[0]
                    == keccak256(
                        "RightsRecordSelected(uint256,bytes32,bytes32,(bytes32,bytes32,bytes32,address,uint256,uint64,uint64,uint64,uint64,uint8,address,uint8,bytes32,bytes32))"
                    ) && logs[0].topics[1] == bytes32(uint256(1)) && logs[0].topics[2] == subject
                && logs[0].topics[3] == hash
                && keccak256(logs[0].data) == keccak256(abi.encode(next)),
            "exact event tuple"
        );
        bytes32 payload = keccak256(StreamRightsRecordJson.serialize(s));
        require(
            next.selectionHash == _literalFirst(address(current), hash, payload, 0)
                && old.selectionHash == _literalFirst(address(legacy), hash, payload, 0)
                && next.selectionHash != old.selectionHash,
            "same domain, distinct selector host"
        );
        next.selectionHash = 0;
        old.selectionHash = 0;
        require(
            keccak256(abi.encode(next)) == keccak256(abi.encode(old)),
            "every semantic selection field unchanged"
        );
        require(
            schemas.document(StreamRightsRecordDefinitions.SCHEMA_ID).chunkHashes.length == 2,
            "complete multi-chunk schema"
        );
    }

    function testAccountSelectionRevalidatesCanonicalCurrentArtistGraphAndRetries() public {
        _prepareCurrent();
        StreamRightsRecordTypes.Statement memory s = _statement();
        (bytes32 hash,) = _publish(s, 1);
        for (uint256 i; i < 17; ++i) {
            if (i == 15) continue;
            bytes memory malformed = _suite();
            assembly ("memory-safe") { mstore(add(add(malformed, 32), mul(i, 32)), shl(160, 1)) }
            coordinator.set(SUITE, malformed);
            vm.expectRevert(
                abi.encodeWithSelector(
                    StreamRecordArtistIdentityReads.ArtistIdentityReadFailed.selector,
                    address(coordinator)
                )
            );
            _select(hash, s, 0, 0);
        }
        coordinator.set(SUITE, _suite());
        identity.set(bytes4(keccak256("core()")), abi.encode(address(0xBAD)));
        vm.expectRevert(
            abi.encodeWithSelector(
                StreamRecordArtistIdentityReads.InvalidArtistIdentityContext.selector
            )
        );
        _select(hash, s, 0, 0);
        identity.set(bytes4(keccak256("core()")), abi.encode(address(core)));
        RecordArtistReadFixture foreign = new RecordArtistReadFixture();
        facade.set(
            bytes4(keccak256("artistRegistryCutover()")),
            abi.encode(false, address(foreign), uint64(0))
        );
        core.setPointer(keccak256("ARTIST_REGISTRY"), address(foreign));
        vm.expectRevert(
            abi.encodeWithSelector(IStreamCollectionMetadataV1.MetadataHostNotSelected.selector)
        );
        _select(hash, s, 0, 0);
        core.setPointer(keccak256("ARTIST_REGISTRY"), address(facade));
        require(current.currentRights(1, subject).revision == 0, "all refusals atomic");
        IStreamRightsRecordSelection.Selection memory saved = _select(hash, s, 0, 0);
        coordinator.set(SUITE, bytes.concat(_suite(), bytes32(0)));
        vm.expectRevert(
            abi.encodeWithSelector(
                StreamRecordArtistIdentityReads.ArtistIdentityReadFailed.selector,
                address(coordinator)
            )
        );
        current.requireCurrent(1, subject, hash, 1);
        require(
            keccak256(abi.encode(current.rightsSelectionAt(1, subject, 1)))
                == keccak256(abi.encode(saved)),
            "raw history does not reread current graph"
        );
        coordinator.set(SUITE, _suite());
        require(
            current.requireCurrent(1, subject, hash, 1).selectionHash == saved.selectionHash,
            "same selection restored"
        );
    }

    function testOriginalThreeRuntimePinsRejectCoherentReplacementAndRestore() public {
        _prepareCurrent();
        StreamRightsRecordTypes.Statement memory statement = _statement();
        (bytes32 hash,) = _publish(statement, 1);
        RecordArtistReadReplacement replacement = new RecordArtistReadReplacement();
        address[3] memory targets = [address(facade), address(coordinator), address(identity)];
        bytes4[3] memory getters = [bytes4(keccak256("core()")), SUITE, bytes4(keccak256("core()"))];
        for (uint256 i; i < 3; ++i) {
            bytes memory code = targets[i].code;
            (bool beforeOK, bytes memory beforeReply) =
                targets[i].staticcall(abi.encodeWithSelector(getters[i]));
            require(beforeOK && beforeReply.length != 0, "original coherent getter");
            vm.etch(targets[i], address(replacement).code);
            (bool afterOK, bytes memory afterReply) =
                targets[i].staticcall(abi.encodeWithSelector(getters[i]));
            require(
                afterOK && keccak256(afterReply) == keccak256(beforeReply),
                "replacement retains original getter/storage"
            );
            vm.expectRevert(
                abi.encodeWithSelector(
                    IStreamRightsRecordSelection.RightsDependencyChanged.selector, targets[i]
                )
            );
            current.currentArtistIdentityContext();
            vm.expectRevert(
                abi.encodeWithSelector(
                    IStreamRightsRecordSelection.RightsDependencyChanged.selector, targets[i]
                )
            );
            _select(hash, statement, 0, 0);
            vm.etch(targets[i], code);
            (address[3] memory restored, bytes32[3] memory pins) =
                current.currentArtistIdentityContext();
            require(
                restored[i] == targets[i] && pins[i] == targets[i].codehash,
                "same pinned graph restored"
            );
            require(
                current.currentRights(1, subject).revision == 0,
                "no state from changed initial graph"
            );
        }
        require(
            _select(hash, statement, 0, 0).recordHash == hash, "identical original record retries"
        );
    }

    function testArtistRegistrationIsDocumentaryAndUnknownOrMalformedCannotSelect() public {
        _prepareCurrent();
        StreamRightsRecordTypes.Statement memory s = _statement();
        s.licensor.kind = StreamRightsRecordTypes.LicensorKind.ARTIST;
        s.licensor.account = address(0);
        s.licensor.artistId = bytes32(uint256(33));
        (bytes32 hash,) = _publish(s, 1);
        identity.set(AUTHORITY, abi.encode(address(0), uint8(0), uint8(0), bytes32(0)));
        vm.expectRevert(
            abi.encodeWithSelector(
                StreamRecordArtistIdentityReads.UnknownRecordArtist.selector, s.licensor.artistId
            )
        );
        _select(hash, s, 0, 0);
        identity.set(AUTHORITY, abi.encode(address(0), uint256(256), uint256(0), REGISTRATION));
        vm.expectRevert(
            abi.encodeWithSelector(
                StreamRecordArtistIdentityReads.ArtistIdentityReadFailed.selector, address(identity)
            )
        );
        _select(hash, s, 0, 0);
        require(current.currentRights(1, subject).revision == 0, "no unknown identity state");
        identity.set(AUTHORITY, abi.encode(address(0), uint8(0), uint8(0), REGISTRATION));
        IStreamRightsRecordSelection.Selection memory next = _select(hash, s, 0, 0);
        IStreamRightsRecordSelection.Selection memory old =
            legacy.selectCurrent(1, subject, hash, 0, 0, s);
        require(
            next.artistIdentityRecordHash == REGISTRATION
                && old.artistIdentityRecordHash == REGISTRATION,
            "registration without active signer gate"
        );
        identity.set(
            AUTHORITY, abi.encode(address(0xBEEF), uint8(255), uint8(255), bytes32(uint256(88)))
        );
        require(
            current.requireCurrent(1, subject, hash, 1).artistIdentityRecordHash == REGISTRATION,
            "saved reference is not rewritten by current authority"
        );
    }

    function testWitnessEffectiveTimeAndPayloadRemainOriginalNotNewTemporalPolicy() public {
        _prepareCurrent();
        StreamRightsRecordTypes.Statement memory s = _statement();
        s.grants.publication.extension = "Keep attribution on labels.";
        // Original generic records permit a future effectiveAt: selection authenticates it,
        // while later consumers retain their independent temporal eligibility rules.
        (bytes32 hash, IStreamRightsRecordWitnessSelection.Witness memory w) = _publish(s, 10000);
        bytes memory original = abi.encode(w);
        ++w.original.effectiveAt;
        vm.expectRevert(
            abi.encodeWithSelector(IStreamRightsRecordSelection.InvalidRightsRecord.selector, hash)
        );
        current.selectCurrentWithRecord(1, subject, hash, 0, 0, w);
        w = abi.decode(original, (IStreamRightsRecordWitnessSelection.Witness));
        w.statement.grants.publication.extension = "";
        vm.expectRevert(abi.encodeWithSelector(StreamRecordJson.RecordPayloadMismatch.selector));
        current.selectCurrentWithRecord(1, subject, hash, 0, 0, w);
        w = abi.decode(original, (IStreamRightsRecordWitnessSelection.Witness));
        w.statement.profileHash = bytes32(uint256(1));
        vm.expectRevert(
            abi.encodeWithSelector(IStreamRightsRecordSelection.InvalidRightsRecord.selector, hash)
        );
        current.selectCurrentWithRecord(1, subject, hash, 0, 0, w);
        require(current.currentRights(1, subject).revision == 0, "witness refusals atomic");
        w = abi.decode(original, (IStreamRightsRecordWitnessSelection.Witness));
        IStreamRightsRecordSelection.Selection memory next =
            current.selectCurrentWithRecord(1, subject, hash, 0, 0, w);
        IStreamRightsRecordSelection.Selection memory old =
            legacy.selectCurrent(1, subject, hash, 0, 0, s);
        require(
            next.payloadHash == old.payloadHash && next.selectedAt == old.selectedAt,
            "future original retains legacy selection behavior"
        );
    }

    function testRightsGrantPrecedenceRevocationAndExactSuccessorHistory() public {
        _prepareCurrent();
        StreamRightsRecordTypes.Statement memory s = _statement();
        (bytes32 first,) = _publish(s, 1);
        _grant(1, StreamRecordFamilies.RIGHTS, 7, address(this), false);
        _grant(0, StreamRecordFamilies.SNAPSHOT, 8, address(this), true);
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamRightsRecordSelection.RightsSelectionAuthorityRequired.selector
            )
        );
        _select(first, s, 0, 0);
        _grant(0, StreamRecordFamilies.RIGHTS, 7, address(this), true);
        _grant(1, StreamRecordFamilies.RIGHTS, 8, address(this), true);
        IStreamRightsRecordSelection.Selection memory one = _select(first, s, 0, 0);
        require(
            one.authorizationClass == 7 && one.grantScope == 0, "class7 before collection class8"
        );
        s.predecessor = first;
        (bytes32 second,) = _publish(s, 1);
        _grant(0, StreamRecordFamilies.RIGHTS, 7, address(this), false);
        _grant(1, StreamRecordFamilies.RIGHTS, 8, address(this), false);
        require(
            current.requireCurrent(1, subject, first, 1).selectionHash == one.selectionHash,
            "revocation does not erase accepted evidence"
        );
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamRightsRecordSelection.RightsSelectionAuthorityRequired.selector
            )
        );
        _select(second, s, first, 1);
        _grant(0, StreamRecordFamilies.RIGHTS, 8, address(this), true);
        IStreamRightsRecordSelection.Selection memory two = _select(second, s, first, 1);
        require(
            two.authorizationClass == 8 && two.grantScope == 0 && two.revision == 2
                && two.predecessor == first && two.recordIndex > one.recordIndex,
            "same original successor after restored authority"
        );
        vm.expectRevert(
            abi.encodeWithSelector(IStreamRightsRecordSelection.RightsSelectionConflict.selector)
        );
        _select(second, s, first, 1);
        require(
            keccak256(abi.encode(current.rightsSelectionAt(1, subject, 1)))
                == keccak256(abi.encode(one)),
            "retained selected history"
        );
    }

    function testCurrentMetadataAndRetiredDefinitionsRejectWhileHistoryRemains() public {
        _prepareCurrent();
        (bytes32 hash,) = _publish(_statement(), 1);
        IStreamRightsRecordSelection.Selection memory saved = _select(hash, _statement(), 0, 0);
        core.setPointer(keccak256("COLLECTION_METADATA"), address(schemas));
        vm.expectRevert(
            abi.encodeWithSelector(IStreamRightsRecordSelection.RightsHostNotSelected.selector)
        );
        current.requireCurrent(1, subject, hash, 1);
        core.setPointer(keccak256("COLLECTION_METADATA"), address(metadata));
        require(
            current.requireCurrent(1, subject, hash, 1).selectionHash == saved.selectionHash,
            "same host restored"
        );
        bytes32 id = StreamRightsRecordDefinitions.PROFILE_ID;
        (bytes32 scope, bytes32 oldHash, bytes32 nextHash) =
            schemas.statusTransition(id, IStreamSchemaRegistry.DocumentStatus.DEPRECATED);
        executor.execute(
            address(schemas),
            abi.encodeCall(
                schemas.setDocumentStatus, (id, IStreamSchemaRegistry.DocumentStatus.DEPRECATED)
            ),
            scope,
            oldHash,
            nextHash
        );
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamRightsRecordSelection.RightsDefinitionUnavailable.selector, id
            )
        );
        current.requireCurrent(1, subject, hash, 1);
        require(
            keccak256(abi.encode(current.currentRights(1, subject))) == keccak256(abi.encode(saved))
                && keccak256(abi.encode(current.rightsSelectionAt(1, subject, 1)))
                    == keccak256(abi.encode(saved)),
            "raw current and history remain original"
        );
    }

    function testOriginalTerminalSealBlocksBothEntrypointsAndRetainsEvidence() public {
        _prepareCurrent();
        StreamRightsRecordTypes.Statement memory s = _statement();
        (bytes32 first,) = _publish(s, 1);
        IStreamRightsRecordSelection.Selection memory saved = _select(first, s, 0, 0);
        _sealGraph(address(core), address(executor));
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamRecordSelectionLock.RecordSelectionLockAuthorityRequired.selector
            )
        );
        current.lockSelection(1, subject, first, 1);
        (bytes32 scope, bytes32 oldHash, bytes32 nextHash) =
            current.selectionLockTransition(1, subject, first, 1);
        bytes32 action = _sealWitness(address(executor), 2, 2, scope, oldHash, nextHash);
        executor.execute(
            address(current),
            abi.encodeCall(current.lockSelection, (1, subject, first, uint64(1))),
            scope,
            oldHash,
            nextHash
        );
        _sealClear();
        IStreamRecordSelectionLock.SelectionLock memory seal = current.selectionLock(1, subject);
        require(
            seal.locked && seal.recordHash == first && seal.selectionHash == saved.selectionHash
                && seal.actionId == action && seal.revision == 1,
            "original terminal seal evidence"
        );
        s.predecessor = first;
        (bytes32 second, IStreamRightsRecordWitnessSelection.Witness memory w) = _publish(s, 1);
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamRecordSelectionLock.RecordSelectionLocked.selector, uint256(1), subject
            )
        );
        _select(second, s, first, 1);
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamRecordSelectionLock.RecordSelectionLocked.selector, uint256(1), subject
            )
        );
        current.selectCurrentWithRecord(1, subject, second, first, 1, w);
        vm.etch(address(metadata), hex"00");
        require(
            keccak256(abi.encode(current.selectionLock(1, subject))) == keccak256(abi.encode(seal))
                && keccak256(abi.encode(current.rightsSelectionAt(1, subject, 1)))
                    == keccak256(abi.encode(saved)),
            "lock and retained selection survive dependency outage"
        );
    }
}
