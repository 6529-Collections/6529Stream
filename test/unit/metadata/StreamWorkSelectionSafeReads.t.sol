// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./StreamWorkSelectionFixture.sol";

/// @notice Each host read has an exact ordinary result and a real Safe direct-call control.
contract StreamWorkSelectionSafeReadsTest is WorkSelectionFixture {
    function testEveryHostReadHasExactResultAndActualSafeInvocation() public ready {
        uint256[] memory keys = new uint256[](2);
        keys[0] = 301;
        keys[1] = 302;
        OfficialSafe safe =
            createOfficialSafe(deploySafeComponents("1.4.1"), safeOwnerAddresses(keys), 2, 990);
        StreamWorkRecordTypes.Description memory d = _named();
        bytes32 hash = _curatorPublish(d);
        IStreamWorkRecordSelection.Selection memory selected =
            selection.selectCurrent(1, subject, hash, 0, 0, _witness(hash, d));
        bytes[] memory inputs = new bytes[](13);
        bytes[] memory expected = new bytes[](13);
        inputs[0] = abi.encodeCall(
            selection.supportsInterface, (type(IStreamWorkRecordSelection).interfaceId)
        );
        expected[0] = abi.encode(true);
        inputs[1] = abi.encodeCall(selection.core, ());
        expected[1] = abi.encode(address(core));
        inputs[2] = abi.encodeCall(selection.metadata, ());
        expected[2] = abi.encode(address(metadata));
        inputs[3] = abi.encodeCall(selection.schemaRegistry, ());
        expected[3] = abi.encode(address(schemas));
        inputs[4] = abi.encodeCall(selection.chunkStore, ());
        expected[4] = abi.encode(address(store));
        inputs[5] = abi.encodeCall(selection.deploymentChainId, ());
        expected[5] = abi.encode(block.chainid);
        inputs[6] = abi.encodeCall(selection.coreCodeHash, ());
        expected[6] = abi.encode(address(core).codehash);
        inputs[7] = abi.encodeCall(selection.metadataCodeHash, ());
        expected[7] = abi.encode(address(metadata).codehash);
        inputs[8] = abi.encodeCall(selection.schemaRegistryCodeHash, ());
        expected[8] = abi.encode(address(schemas).codehash);
        inputs[9] = abi.encodeCall(selection.chunkStoreCodeHash, ());
        expected[9] = abi.encode(address(store).codehash);
        inputs[10] = abi.encodeCall(selection.currentWork, (1, subject));
        expected[10] = abi.encode(selected);
        inputs[11] = abi.encodeCall(selection.workSelectionAt, (1, subject, 1));
        expected[11] = abi.encode(selected);
        inputs[12] = abi.encodeCall(selection.requireCurrent, (1, subject, hash, 1));
        expected[12] = abi.encode(selected);
        for (uint256 i; i < inputs.length; ++i) {
            (bool ok, bytes memory output) = address(selection).staticcall(inputs[i]);
            require(
                ok && output.length == expected[i].length
                    && keccak256(output) == keccak256(expected[i]),
                "exact reader return"
            );
            require(
                executeSafe(safe, keys, address(selection), 0, inputs[i], 0),
                "actual Safe direct reader"
            );
        }
        require(
            !selection.supportsInterface(0xffffffff) && selection.supportsInterface(0x01ffc9a7),
            "discovery false/true boundaries"
        );
        IStreamWorkRecordSelection.Selection memory empty;
        require(
            keccak256(abi.encode(selection.currentWork(2, subject)))
                == keccak256(abi.encode(empty)),
            "unknown head is entirely zero"
        );
        vm.expectRevert(
            abi.encodeWithSelector(IStreamWorkRecordSelection.WorkSelectionConflict.selector)
        );
        selection.workSelectionAt(1, subject, 0);
    }

    function testLinkedReadMethodsHaveConcreteResultsAndSafeCalls() public ready {
        uint256[] memory keys = new uint256[](2);
        keys[0] = 401;
        keys[1] = 402;
        OfficialSafe safe =
            createOfficialSafe(deploySafeComponents("1.4.1"), safeOwnerAddresses(keys), 2, 991);
        StreamWorkRecordTypes.Description memory witness = _named();
        bytes32 hash = _curatorPublish(witness);
        IStreamWorkRecordSelection.Selection memory selected =
            selection.selectCurrent(1, subject, hash, 0, 0, _witness(hash, witness));
        StreamWorkRecordContext.Dependencies memory d;
        d.targets = [address(core), address(metadata), address(schemas), address(store)];
        for (uint256 i; i < 4; ++i) {
            d.codeHashes[i] = d.targets[i].codehash;
        }
        d.chainId = block.chainid;
        d = StreamWorkRecordContext.currentContext(d);
        StreamWorkRecordContext.Dependencies memory complete = StreamWorkRecordContext.pinArtists(d);
        bytes[] memory inputs = new bytes[](9);
        bytes[] memory expected = new bytes[](9);
        address[] memory targets = new address[](9);
        for (uint256 i; i < 5; ++i) {
            targets[i] = address(StreamWorkRecordContext);
        }
        for (uint256 i = 5; i < 9; ++i) {
            targets[i] = address(StreamWorkRecordReads);
        }
        inputs[0] =
            abi.encodeWithSelector(StreamWorkRecordContext.currentContext.selector, complete);
        expected[0] = abi.encode(complete);
        inputs[1] = abi.encodeWithSelector(StreamWorkRecordContext.pinArtists.selector, d);
        expected[1] = abi.encode(complete);
        inputs[2] = abi.encodeWithSelector(StreamWorkRecordContext.definitions.selector, complete);
        expected[2] = bytes("");
        inputs[3] = abi.encodeWithSelector(
            StreamWorkRecordContext.document.selector,
            complete,
            StreamWorkRecordDefinitions.SCHEMA_ID
        );
        expected[3] = abi.encode(
            IStreamSchemaDocumentFacts(address(schemas))
                .documentFacts(StreamWorkRecordDefinitions.SCHEMA_ID)
        );
        inputs[4] = abi.encodeWithSelector(
            StreamWorkRecordContext.definition.selector,
            complete,
            StreamWorkRecordDefinitions.PROFILE_ID,
            IStreamSchemaRegistry.DocumentKind.CATALOG,
            StreamWorkRecordDefinitions.PROFILE_HASH,
            StreamWorkRecordDefinitions.PROFILE_BYTES,
            schemas.RAW_BYTES(),
            true
        );
        expected[4] = abi.encode(
            bytes(vm.readFile("schemas/records/STREAM_WORK_DESCRIPTION_JSON_PROFILE_V1.json"))
        );
        inputs[5] = abi.encodeWithSelector(
            StreamWorkRecordReads.curatorAuthority.selector, complete, 1, address(this)
        );
        expected[5] = abi.encode(uint8(3), uint256(1), uint64(1));
        inputs[6] = abi.encodeWithSelector(
            StreamWorkRecordReads.recorded.selector,
            complete,
            1,
            subject,
            hash,
            _witness(hash, witness)
        );
        IStreamWorkRecordSelection.Selection memory original =
            abi.decode(abi.encode(selected), (IStreamWorkRecordSelection.Selection));
        original.submitter = address(0);
        original.mode = IStreamWorkRecordSelection.AdoptionMode.ARTIST_RECORD_ADOPTION;
        original.grantScope = 0;
        original.grantRevision = 0;
        original.revision = 0;
        original.selectedAt = 0;
        original.selectorAuthorizationClass = 0;
        original.selectionHash = 0;
        expected[6] = abi.encode(original);
        inputs[7] = abi.encodeWithSelector(
            StreamWorkRecordReads.requireSelectedAssociation.selector, complete, 1, selected
        );
        expected[7] = bytes("");
        inputs[8] = abi.encodeWithSelector(StreamWorkRecordReads.association.selector, complete, 1);
        expected[8] = abi.encode(IStreamWorkRecordSelection.Association(0, 0, 0, 0));
        for (uint256 i; i < inputs.length; ++i) {
            (bool ok, bytes memory output) = targets[i].staticcall(inputs[i]);
            require(
                ok && output.length == expected[i].length
                    && keccak256(output) == keccak256(expected[i]),
                "library exact result"
            );
            require(
                executeSafe(safe, keys, targets[i], 0, inputs[i], 0),
                "actual Safe direct stateless library read"
            );
        }
    }
}
