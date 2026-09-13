// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./StreamWorkSelectionFixture.sol";

contract StreamWorkSelectionBoundariesTest is WorkSelectionFixture {
    function testOriginalSuccessorPublicationClassIsRetained() public ready {
        _bound(1, BINDING, 3);
        publicationAuthorityClass = 3;
        identityOwner.setIdentity(ORIGINAL, 3, 3, IDENTITY);
        StreamWorkRecordTypes.Description memory d = _artistDescription();
        (bytes32 hash,) = _artistPublish(d);
        facade.setSigner(address(0x9876));
        identityOwner.setIdentity(address(0x9876), 3, 3, IDENTITY);
        IStreamWorkRecordSelection.Selection memory s =
            selection.adoptArtistRecord(1, subject, hash, 0, 0, _witness(hash, d));
        require(
            s.recorderAuthorizationClass == 1 && s.artistPublication.authorityClass == 3
                && s.artistPublication.requiredCapability == 1
                && s.artistPublication.signer == ORIGINAL,
            "metadata ARTIST is distinct from original successor class"
        );
    }

    function testCuratorGrantPrecedenceRevocationAndHistoricalSelection() public ready {
        address selector = address(0xc012);
        _grant(1, StreamRecordFamilies.CURATOR, 8, selector, true);
        _grant(0, StreamRecordFamilies.CURATOR, 3, selector, true);
        StreamWorkRecordTypes.Description memory d = _named();
        bytes32 hash = _curatorPublish(d);
        vm.prank(selector);
        IStreamWorkRecordSelection.Selection memory s =
            selection.selectCurrent(1, subject, hash, 0, 0, _witness(hash, d));
        require(
            s.selectorAuthorizationClass == 3 && s.grantScope == 0 && s.grantRevision == 1,
            "class precedence before scope"
        );
        _grant(0, StreamRecordFamilies.CURATOR, 3, selector, false);
        _grant(1, StreamRecordFamilies.CURATOR, 8, selector, false);
        selection.requireCurrent(1, subject, hash, 1);
        d.predecessor = hash;
        d.full.title = "Successor title";
        bytes32 next = _curatorPublish(d);
        vm.prank(selector);
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamWorkRecordSelection.WorkSelectionAuthorityRequired.selector
            )
        );
        selection.selectCurrent(1, subject, next, hash, 1, _witness(next, d));
        _grant(1, StreamRecordFamilies.CURATOR, 8, selector, true);
        vm.prank(selector);
        s = selection.selectCurrent(1, subject, next, hash, 1, _witness(next, d));
        require(
            s.selectorAuthorizationClass == 8 && s.grantScope == 1 && s.grantRevision == 3,
            "same witness after renewed exact grant"
        );
    }

    function testCuratorOriginalIsNotPermissionlessArtistAuthority() public ready {
        StreamWorkRecordTypes.Description memory d = _named();
        bytes32 hash = _curatorPublish(d);
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamWorkRecordSelection.WorkSelectionAuthorityRequired.selector
            )
        );
        selection.adoptArtistRecord(1, subject, hash, 0, 0, _witness(hash, d));
        require(selection.currentWork(1, subject).recordHash == 0, "no provisional head");
        selection.selectCurrent(1, subject, hash, 0, 0, _witness(hash, d));
    }

    function testSelectedCatalogIsEntireRegisteredDocumentAndRetirementIsExplicit() public ready {
        StreamWorkRecordTypes.Description memory d = _named();
        d.full.format.kind = StreamWorkRecordTypes.FormatKind.CATALOG;
        d.full.format.formatId = bytes32(uint256(7));
        d.full.format.catalog.name = "ACTUAL_WORK_FORMAT_V1";
        d.full.format.catalog.selectedEntryId = bytes32(uint256(7));
        d.full.format.catalog.entries = new StreamWorkRecordTypes.CatalogEntry[](2);
        d.full.format.catalog.entries[0].entryId = bytes32(uint256(6));
        d.full.format.catalog.entries[0].puid = "fmt/199";
        d.full.format.catalog.entries[1].entryId = bytes32(uint256(7));
        d.full.format.catalog.entries[1].puid = "fmt/18";
        bytes memory catalog = StreamWorkFormatJson.catalogDocument(d.full.format.catalog);
        bytes32 hash = _curatorPublish(d);
        vm.expectRevert();
        selection.selectCurrent(1, subject, hash, 0, 0, _witness(hash, d));
        bytes32 id = _registerDocument(
            d.full.format.catalog.name,
            IStreamSchemaRegistry.DocumentKind.CATALOG,
            catalog,
            StreamWorkRecordDefinitions.CANON_ID
        );
        StreamWorkRecordTypes.Description memory mutated =
            abi.decode(abi.encode(d), (StreamWorkRecordTypes.Description));
        mutated.full.format.catalog.entries[0].puid = "fmt/19";
        bytes32 other = _curatorPublish(mutated);
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamWorkRecordSelection.WorkDefinitionUnavailable.selector, id
            )
        );
        selection.selectCurrent(1, subject, other, 0, 0, _witness(other, mutated));
        IStreamWorkRecordSelection.Selection memory s =
            selection.selectCurrent(1, subject, hash, 0, 0, _witness(hash, d));
        require(
            s.catalogId == id && s.catalogHash == keccak256(catalog),
            "whole registered ordered catalog"
        );
        _retire(id);
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamWorkRecordSelection.WorkDefinitionUnavailable.selector, id
            )
        );
        selection.requireCurrent(1, subject, hash, 1);
        require(
            selection.currentWork(1, subject).catalogHash == keccak256(catalog),
            "retired catalog history retained"
        );
    }

    function testEachExactDefinitionMustRemainAdmittedWithoutErasingHistory() public ready {
        StreamWorkRecordTypes.Description memory d = _named();
        bytes32 hash = _curatorPublish(d);
        selection.selectCurrent(1, subject, hash, 0, 0, _witness(hash, d));
        bytes32[5] memory ids = [
            StreamWorkRecordDefinitions.SCHEMA_ID,
            StreamWorkRecordDefinitions.PROFILE_ID,
            StreamWorkRecordDefinitions.CATALOG_SCHEMA_ID,
            StreamWorkRecordDefinitions.CATALOG_PROFILE_ID,
            StreamWorkRecordDefinitions.CANON_ID
        ];
        for (uint256 i; i < ids.length; ++i) {
            uint256 snapshot = vm.snapshotState();
            _retire(ids[i]);
            vm.expectRevert(
                abi.encodeWithSelector(
                    IStreamWorkRecordSelection.WorkDefinitionUnavailable.selector, ids[i]
                )
            );
            selection.requireCurrent(1, subject, hash, 1);
            require(
                selection.workSelectionAt(1, subject, 1).recordHash == hash,
                "retired definitions do not erase history"
            );
            require(vm.revertToState(snapshot), "restore exact active definition");
            selection.requireCurrent(1, subject, hash, 1);
        }
    }

    function testCompletePayloadRejectsChangedOptionalAndInactiveFields() public ready {
        StreamWorkRecordTypes.Description memory d = _named();
        d.full.alternateTitles = new string[](1);
        d.full.alternateTitles[0] = "Exact alternate";
        d.full.hasInscription = true;
        d.full.inscription = "Original inscription";
        bytes32 hash = _curatorPublish(d);
        for (uint256 i; i < 5; ++i) {
            StreamWorkRecordTypes.Description memory bad =
                abi.decode(abi.encode(d), (StreamWorkRecordTypes.Description));
            if (i == 0) bad.full.alternateTitles[0] = "Altered alternate";
            if (i == 1) bad.full.inscription = "Altered inscription";
            if (i == 2) bad.full.creation.start = 20240301;
            if (i == 3) bad.profileHash = keccak256("caller interpretation");
            if (i == 4) bad.absence.reason = "inactive absence";
            vm.expectRevert();
            selection.selectCurrent(1, subject, hash, 0, 0, _witness(hash, bad));
            require(selection.currentWork(1, subject).revision == 0, "no partial acceptance");
        }
        selection.selectCurrent(1, subject, hash, 0, 0, _witness(hash, d));
    }

    function testMalformedReceiptWidthsAndTrailingBytesRollback() public ready {
        StreamWorkRecordTypes.Description memory d = _named();
        bytes32 hash = _curatorPublish(d);
        (, IStreamCollectionMetadataV1.RecordReceipt memory receipt) =
            metadata.collectionRecord(hash);
        bytes memory healthy = abi.encode(receipt);
        bytes memory input =
            abi.encodeCall(IStreamCollectionRecordReceipts.collectionRecordReceipt, (hash));
        for (uint256 i; i < 5; ++i) {
            bytes memory bad;
            if (i == 0) bad = new bytes(0);
            if (i == 1) bad = new bytes(32);
            if (i == 2) bad = bytes.concat(healthy, hex"00");
            if (i == 3) {
                bad = abi.encode(receipt);
                assembly ("memory-safe") { mstore(add(bad, 96), 256) }
            }
            if (i == 4) bad = new bytes(8193);
            workVm.mockCall(address(metadata), input, bad);
            vm.expectRevert();
            selection.selectCurrent(1, subject, hash, 0, 0, _witness(hash, d));
            workVm.clearMockedCalls();
            require(selection.currentWork(1, subject).revision == 0, "malformed return no head");
        }
        selection.selectCurrent(1, subject, hash, 0, 0, _witness(hash, d));
    }

    function testEveryOriginalPublicationFieldIsJoinedAndSameRecordRetries() public ready {
        _bound(1, BINDING, 2);
        StreamWorkRecordTypes.Description memory d = _artistDescription();
        (bytes32 hash, bytes32 authorization) = _artistPublish(d);
        IStreamArtistRecordPublicationOwner.Record memory original =
            attributionOwner.publicationAttestation(authorization);
        bytes memory input = abi.encodeCall(
            IStreamArtistRecordPublicationOwner.publicationAttestation, (authorization)
        );
        for (uint256 i; i < 22; ++i) {
            bytes memory raw = abi.encode(original);
            // Each of the 22 fixed words changes independently. Dirty narrow values may fail decoding.
            assembly ("memory-safe") {
                let ptr := add(add(raw, 32), mul(i, 32))
                mstore(ptr, xor(mload(ptr), 1))
            }
            workVm.mockCall(address(attributionOwner), input, raw);
            vm.expectRevert();
            selection.adoptArtistRecord(1, subject, hash, 0, 0, _witness(hash, d));
            workVm.clearMockedCalls();
            require(
                selection.currentWork(1, subject).revision == 0
                    && metadata.consumedArtistAuthorization(authorization),
                "original consumption never resets"
            );
        }
        selection.adoptArtistRecord(1, subject, hash, 0, 0, _witness(hash, d));
    }

    function testArtistAbsenceRequiresItsOriginalAssociationAndNoCreatorIsInvented() public ready {
        _bound(1, BINDING, 2);
        StreamWorkRecordTypes.Description memory d = _absence(0);
        (bytes32 hash,) = _artistPublish(d);
        _bound(1, BINDING, 4);
        vm.expectRevert(
            abi.encodeWithSelector(IStreamWorkRecordSelection.WorkAssociationChanged.selector)
        );
        selection.adoptArtistRecord(1, subject, hash, 0, 0, _witness(hash, d));
        _bound(1, BINDING, 3);
        IStreamWorkRecordSelection.Selection memory s =
            selection.adoptArtistRecord(1, subject, hash, 0, 0, _witness(hash, d));
        require(
            s.form == StreamWorkRecordTypes.Form.DESCRIPTION_ABSENT
                && s.creatorAssociation.artistId == 0 && s.artistPublication.artistId == ARTIST_ID,
            "original absence author distinct from absent creator"
        );
    }

    function testMetadataPointerAndPinnedGraphDriftRejectThenRestore() public ready {
        StreamWorkRecordTypes.Description memory d = _named();
        bytes32 hash = _curatorPublish(d);
        core.setPointer(keccak256("COLLECTION_METADATA"), address(0));
        vm.expectRevert(
            abi.encodeWithSelector(IStreamWorkRecordSelection.WorkHostNotSelected.selector)
        );
        selection.selectCurrent(1, subject, hash, 0, 0, _witness(hash, d));
        core.setPointer(keccak256("COLLECTION_METADATA"), address(metadata));
        T.SuiteConfiguration memory original = coordinator.suiteConfiguration();
        T.SuiteConfiguration memory changed = original;
        WorkSelectionOwnerBoundary replacement = new WorkSelectionOwnerBoundary();
        replacement.configure(address(core), address(facade), address(coordinator));
        changed.owners[0] = address(replacement);
        coordinator.setSuite(changed);
        vm.expectRevert(
            abi.encodeWithSelector(IStreamWorkRecordSelection.WorkAssociationChanged.selector)
        );
        selection.selectCurrent(1, subject, hash, 0, 0, _witness(hash, d));
        // Reconstruct independently: memory struct assignment shares its arrays.
        changed.owners[0] = address(bindingOwner);
        coordinator.setSuite(changed);
        selection.selectCurrent(1, subject, hash, 0, 0, _witness(hash, d));
    }

    function testTokenSubjectRetainsCollectionAssociationAfterBurn() public ready {
        core.setToken(77, ORIGINAL, 2);
        subject = metadata.registerTokenSubject(77);
        _bound(1, BINDING, 2);
        StreamWorkRecordTypes.Description memory d = _artistDescription();
        (bytes32 hash,) = _artistPublish(d);
        core.setToken(77, address(0), 3);
        selection.adoptArtistRecord(1, subject, hash, 0, 0, _witness(hash, d));
        selection.requireCurrent(1, subject, hash, 1);
        vm.expectRevert();
        selection.requireCurrent(2, subject, hash, 1);
    }

    function testActualThresholdSafeCuratorAndPermissionlessArtistDelivery() public ready {
        uint256[] memory keys = new uint256[](2);
        keys[0] = 101;
        keys[1] = 202;
        OfficialSafe safe =
            createOfficialSafe(deploySafeComponents("1.4.1"), safeOwnerAddresses(keys), 2, 902);
        _grant(1, StreamRecordFamilies.CURATOR, 3, address(safe), true);
        StreamWorkRecordTypes.Description memory d = _named();
        bytes32 hash = _curatorPublish(d);
        bytes memory callData =
            abi.encodeCall(selection.selectCurrent, (1, subject, hash, 0, 0, _witness(hash, d)));
        require(
            executeSafe(safe, keys, address(selection), 0, callData, 0), "actual Safe curator write"
        );
        require(
            selection.currentWork(1, subject).submitter == address(safe), "Safe selector is exact"
        );
        _bound(1, BINDING, 2);
        d = _artistDescription();
        d.predecessor = hash;
        (bytes32 next,) = _artistPublish(d);
        _grant(1, StreamRecordFamilies.CURATOR, 3, address(safe), false);
        callData = abi.encodeCall(
            selection.adoptArtistRecord, (1, subject, next, hash, 1, _witness(next, d))
        );
        require(
            executeSafe(safe, keys, address(selection), 0, callData, 0),
            "Safe delivery has no grant requirement"
        );
        IStreamWorkRecordSelection.Selection memory s = selection.currentWork(1, subject);
        require(
            s.submitter == address(safe) && s.recorder == ORIGINAL
                && s.selectorAuthorizationClass == 0,
            "Safe is neither original artist nor curator now"
        );
        require(
            executeSafe(
                safe,
                keys,
                address(selection),
                0,
                abi.encodeCall(selection.requireCurrent, (1, subject, next, 2)),
                0
            ),
            "Safe current evidence read"
        );
    }

    function _retire(bytes32 id) private {
        (bytes32 s, bytes32 o, bytes32 n) =
            schemas.statusTransition(id, IStreamSchemaRegistry.DocumentStatus.DEPRECATED);
        executor.execute(
            address(schemas),
            abi.encodeCall(
                schemas.setDocumentStatus, (id, IStreamSchemaRegistry.DocumentStatus.DEPRECATED)
            ),
            s,
            o,
            n
        );
    }
}
