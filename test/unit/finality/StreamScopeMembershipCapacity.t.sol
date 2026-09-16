// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../../helpers/ScopeMembershipPublicationFixture.sol";
import "../../../smart-contracts/domains/records/StreamRecordDocumentReads.sol";

interface ScopeMembershipColdVm {
    function cool(address target) external;
}

contract StreamScopeMembershipCapacityTest is ScopeMembershipPublicationFixture {
    ScopeMembershipColdVm private constant coldVm =
        ScopeMembershipColdVm(address(uint160(uint256(keccak256("hevm cheat code")))));
    event ColdReadMeasured(bytes32 indexed operation, uint256 used, uint256 returnedBytes);

    function _cold(bytes32 recordHash, bytes32[] memory parts) private {
        (address payloadPointer,) = metadata.recordPayload(recordHash);
        address[] memory pointers = new address[](parts.length);
        for (uint256 i; i < parts.length; ++i) {
            (pointers[i],) = store.chunk(parts[i]);
        }
        coldVm.cool(address(core));
        coldVm.cool(address(metadata));
        coldVm.cool(address(store));
        coldVm.cool(address(schemas));
        coldVm.cool(address(inventory));
        coldVm.cool(address(membership));
        coldVm.cool(address(StreamScopeMembershipReads));
        coldVm.cool(address(StreamScopeMembershipEncoding));
        coldVm.cool(address(StreamCollectionRecordHashes));
        coldVm.cool(address(StreamRecordDocumentReads));
        coldVm.cool(address(StreamMetadataSubjects));
        coldVm.cool(payloadPointer);
        for (uint256 i; i < pointers.length; ++i) {
            coldVm.cool(pointers[i]);
        }
        IStreamSchemaRegistry.DocumentView memory d = schemas.document(SCOPE_SCHEMA);
        (address pointer,) = store.chunk(d.chunkHashes[0]);
        coldVm.cool(pointer);
        d = schemas.document(SCOPE_CANON);
        (pointer,) = store.chunk(d.chunkHashes[0]);
        coldVm.cool(pointer);
        // The pointer discovery calls above warmed registry/store; reset them after all discovery.
        coldVm.cool(address(schemas));
        coldVm.cool(address(store));
    }

    function testColdMaximumPermanentRecordAndNestedManifestReadUseIndependent500kProfile() public {
        uint256[] memory ids = new uint256[](16384);
        for (uint256 i; i < ids.length; ++i) {
            ids[i] = i + 1;
        }
        StreamScopeMembershipManifest memory m = _manifest(2, ids);
        bytes memory uri = new bytes(2048);
        for (uint256 i; i < uri.length; ++i) {
            uri[i] = 0x61;
        }
        uri[0] = 0x69;
        uri[1] = 0x70;
        uri[2] = 0x66;
        uri[3] = 0x73;
        uri[4] = 0x3a;
        uri[5] = 0x2f;
        uri[6] = 0x2f;
        bytes32 recordHash = _publish(m, string(uri));
        bytes memory input = abi.encodeCall(metadata.collectionRecord, (recordHash));
        _cold(recordHash, m.chunkHashes);
        (bool oldOK,) = address(metadata).staticcall{ gas: 150000 }(input);
        require(!oldOK, "ordinary cap rejects actual maximum stored URI");
        _cold(recordHash, m.chunkHashes);
        uint256 beforeGas = gasleft();
        (bool ok, bytes memory raw) = address(metadata).staticcall{ gas: 500000 }(input);
        uint256 used = beforeGas - gasleft();
        require(ok && raw.length <= 4096);
        (
            IStreamPreservationRecords.CollectionRecord memory r,
            IStreamCollectionMetadataV1.RecordReceipt memory receipt
        ) = abi.decode(
            raw,
            (IStreamPreservationRecords.CollectionRecord, IStreamCollectionMetadataV1.RecordReceipt)
        );
        require(
            bytes(r.uri).length == 2048 && keccak256(bytes(r.uri)) == keccak256(uri)
                && receipt.recorder == address(this)
        );
        require(keccak256(raw) == keccak256(abi.encode(r, receipt)));
        emit ColdReadMeasured(keccak256("actual maximum permanent record"), used, raw.length);
        input = abi.encodeCall(metadata.recordPayload, (recordHash));
        _cold(recordHash, m.chunkHashes);
        (oldOK,) = address(metadata).staticcall{ gas: 150000 }(input);
        require(!oldOK, "outer150k cannot admit nested150k plus reserve");
        _cold(recordHash, m.chunkHashes);
        beforeGas = gasleft();
        (ok, raw) = address(metadata).staticcall{ gas: 500000 }(input);
        used = beforeGas - gasleft();
        require(ok && raw.length == 2432);
        (, bytes memory payload) = abi.decode(raw, (address, bytes));
        require(
            payload.length == 2336
                && keccak256(payload) == keccak256(StreamScopeMembershipEncoding.encode(m))
        );
        emit ColdReadMeasured(keccak256("actual maximum nested manifest"), used, raw.length);
        _cold(recordHash, m.chunkHashes);
        StreamFinalityScope memory s = membership.beginScopeMembership(recordHash);
        require(
            membership.scopeMembershipProgress(s).totalParts == 64
                && membership.scopeMembershipProgress(s).totalTokens == 16384
        );
    }

    function testColdMaximum64PartValidatingFactsHaveMeasuredOuterBudget() public {
        // Each ordinary batch remains separately bounded. Metering is paused only during setup
        // so a single test may construct the entire allowed64-part state without a test gas ceiling.
        vm.pauseGasMetering();
        uint256[] memory ids = _tokens(16384);
        _index(ids, 0, ids.length);
        StreamScopeMembershipManifest memory m = _manifest(4, ids);
        bytes32 recordHash = _publish(m, "ipfs://full64");
        StreamFinalityScope memory s = membership.beginScopeMembership(recordHash);
        for (uint256 i; i < 64; ++i) {
            membership.continueScopeMembership(s, 1);
        }
        require(
            membership.scopeMembershipProgress(s).complete
                && membership.scopeMembershipProgress(s).processedTokens == 16384
        );
        StreamScopeMembershipFacts memory expected = membership.requireScopeMembership(s);
        vm.resumeGasMetering();
        bytes memory input = abi.encodeCall(membership.requireScopeMembership, (s));
        _cold(recordHash, m.chunkHashes);
        (bool oldOK,) = address(membership).staticcall{ gas: 150000 }(input);
        require(!oldOK, "eight words do not imply150k recursive validation");
        _cold(recordHash, m.chunkHashes);
        uint256 beforeGas = gasleft();
        (bool ok, bytes memory raw) = address(membership).staticcall{ gas: 1200000 }(input);
        uint256 used = beforeGas - gasleft();
        require(ok && raw.length == 256 && keccak256(raw) == keccak256(abi.encode(expected)));
        emit ColdReadMeasured(keccak256("actual64-part membership facts"), used, raw.length);
        require(membership.scopeTokenAt(s, 16383) == ids[16383]);
    }
}
