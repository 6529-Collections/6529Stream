// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./StreamWorkSelectionFixture.sol";

/// @notice Cold maximum-shape WORK controls, retaining original monolithic-read diagnostics.
contract StreamWorkSelectionColdReadTest is WorkSelectionFixture {
    event log_named_uint(string key, uint256 value);

    function testColdMaximumDefinitionURIUsesBoundedFactsAndCompleteBytes() public {
        registrationURI = _maximumURI();
        _prepare();
        {
            bytes memory input = abi.encodeCall(
                IStreamSchemaRegistry.document, (StreamWorkRecordDefinitions.SCHEMA_ID)
            );
            safeVm.cool(address(schemas));
            (bool admitted,) = address(schemas).staticcall{ gas: 150000 }(input);
            safeVm.cool(address(schemas));
            uint256 beforeGas = gasleft();
            (bool healthy, bytes memory raw) = address(schemas).staticcall{ gas: 400000 }(input);
            uint256 used = beforeGas - gasleft();
            require(healthy, "maximum document is a valid readable registration");
            IStreamSchemaRegistry.DocumentView memory row =
                abi.decode(raw, (IStreamSchemaRegistry.DocumentView));
            require(bytes(row.specification.uri).length == 2048, "literal maximum URI");
            emit log_named_uint("cold full document read gas", used);
            emit log_named_uint("read succeeded at existing 150000 cap", admitted ? 1 : 0);
        }
        StreamWorkRecordTypes.Description memory d = _named();
        bytes32 hash = _curatorPublish(d);
        _coolSources();
        selection.selectCurrent(1, subject, hash, 0, 0, _witness(hash, d));
        _coolSources();
        selection.requireCurrent(1, subject, hash, 1);
    }

    function testColdMaximumRecordURIUsesExactWitnessAndBoundedReceipt() public ready {
        StreamWorkRecordTypes.Description memory d = _named();
        bytes memory payload = StreamWorkRecordJson.serialize(d);
        IStreamPreservationRecords.CollectionRecord memory r = _workRecord(payload);
        r.uri = _maximumURI();
        bytes32 hash = metadata.recordCollectionRecordWithPayload(1, r, payload);
        originals[hash] = r;
        {
            bytes memory input =
                abi.encodeCall(IStreamCollectionMetadataV1.collectionRecord, (hash));
            safeVm.cool(address(metadata));
            (bool admitted,) = address(metadata).staticcall{ gas: 150000 }(input);
            safeVm.cool(address(metadata));
            uint256 beforeGas = gasleft();
            (bool healthy, bytes memory raw) = address(metadata).staticcall{ gas: 400000 }(input);
            uint256 used = beforeGas - gasleft();
            require(healthy, "maximum record is a valid readable publication");
            (IStreamPreservationRecords.CollectionRecord memory original,) = abi.decode(
                raw,
                (
                    IStreamPreservationRecords.CollectionRecord,
                    IStreamCollectionMetadataV1.RecordReceipt
                )
            );
            require(bytes(original.uri).length == 2048, "literal maximum record URI");
            emit log_named_uint("cold full record read gas", used);
            emit log_named_uint("read succeeded at existing 150000 cap", admitted ? 1 : 0);
        }
        IStreamWorkRecordSelection.Witness memory bad = _witness(hash, d);
        bad.original.uri = "ipfs://different";
        _coolSources();
        vm.expectRevert(
            abi.encodeWithSelector(IStreamWorkRecordSelection.InvalidWorkRecord.selector, hash)
        );
        selection.selectCurrent(1, subject, hash, 0, 0, bad);
        _coolSources();
        selection.selectCurrent(1, subject, hash, 0, 0, _witness(hash, d));
        _coolSources();
        selection.requireCurrent(1, subject, hash, 1);
    }

    function _coolSources() private {
        safeVm.cool(address(core));
        safeVm.cool(address(metadata));
        safeVm.cool(address(schemas));
        safeVm.cool(address(store));
        safeVm.cool(address(facade));
        safeVm.cool(address(coordinator));
        safeVm.cool(address(identityOwner));
        safeVm.cool(address(bindingOwner));
        safeVm.cool(address(attributionOwner));
    }

    function _maximumURI() private pure returns (string memory) {
        bytes memory raw = new bytes(2048);
        bytes memory prefix = bytes("ipfs://");
        for (uint256 i; i < raw.length; ++i) {
            raw[i] = i < prefix.length ? prefix[i] : bytes1("a");
        }
        return string(raw);
    }
}
