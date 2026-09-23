// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./StreamCurrentSafeGovernanceFixture.sol";
import "../../script/current/StreamGovernanceCatalogStagePlan.sol";
import "../../smart-contracts/domains/records/StreamRecordFamilies.sol";

/// @notice Real current graph and threshold-Safe publication operations for documentary tests.
/// @dev Payloads are local test evidence, not claims of public archival or institutional review.
abstract contract CurrentDocumentaryRecordsFixture is StreamCurrentSafeGovernanceFixture {
    function _additionalOperatingPolicies()
        internal
        view
        virtual
        override
        returns (GovernanceActionPolicyEntry[] memory)
    {
        GovernanceActionPolicyEntry[] memory rows = new GovernanceActionPolicyEntry[](4);
        rows[0] =
            _documentaryPolicy(address(assemblySchemas), assemblySchemas.registerDocument.selector);
        rows[1] = _documentaryPolicy(
            address(assemblyMetadata), assemblyMetadata.admitRecordType.selector
        );
        rows[2] = _documentaryPolicy(
            address(assemblyMetadata), assemblyMetadata.setFamilyWriter.selector
        );
        rows[3] = _documentaryPolicy(address(core), core.bindConservationFloor.selector);
        return _appendDocumentaryPolicies(super._additionalOperatingPolicies(), rows);
    }

    function _installDocumentaryGovernor() internal {
        uint256[] memory owners = new uint256[](3);
        owners[0] = 0xD0C001;
        owners[1] = 0xD0C002;
        owners[2] = 0xD0C003;
        uint256[] memory signers = new uint256[](2);
        signers[0] = owners[0];
        signers[1] = owners[1];
        _installGovernorSafe(
            createOfficialSafe(deploySafeComponents("1.4.1"), safeOwnerAddresses(owners), 2, 0xD0C),
            signers
        );
    }

    function _documentaryGovern(
        address target,
        bytes memory data,
        bytes32 scope,
        bytes32 previous,
        bytes32 next
    ) internal {
        _govern(_governanceRequest(1, target, data, scope, previous, next));
    }

    function _documentarySafeCall(address target, bytes memory data) internal {
        this.executeCurrentGovernorCall(target, data);
    }

    function _documentaryPolicy(address target, bytes4 selector)
        internal
        view
        returns (GovernanceActionPolicyEntry memory)
    {
        require(target.code.length != 0, "actual documentary policy target");
        return GovernanceActionPolicyEntry(
            1,
            target,
            selector,
            target.codehash,
            keccak256(abi.encode(DEPLOYMENT_HASH, target)),
            1,
            0,
            0,
            0
        );
    }

    function _appendDocumentaryPolicies(
        GovernanceActionPolicyEntry[] memory existing,
        GovernanceActionPolicyEntry[] memory additions
    ) internal pure returns (GovernanceActionPolicyEntry[] memory rows) {
        rows = new GovernanceActionPolicyEntry[](existing.length + additions.length);
        uint256 count;
        for (uint256 i; i < existing.length; ++i) {
            rows[count++] = existing[i];
        }
        for (uint256 i; i < additions.length; ++i) {
            bool found;
            for (uint256 j; j < count; ++j) {
                if (_documentaryPolicyKey(rows[j]) != _documentaryPolicyKey(additions[i])) {
                    continue;
                }
                require(
                    keccak256(abi.encode(rows[j])) == keccak256(abi.encode(additions[i])),
                    "same selector requires same policy"
                );
                found = true;
            }
            if (!found) rows[count++] = additions[i];
        }
        assembly ("memory-safe") { mstore(rows, count) }
    }

    function _documentaryPolicyKey(GovernanceActionPolicyEntry memory row)
        private
        pure
        returns (bytes32)
    {
        return keccak256(abi.encode(row.actionClass, row.target, row.selector));
    }

    /// @dev Late products enter through the original class-3 catalog and manifest batch.
    function _documentaryAddPolicies(GovernanceActionPolicyEntry[] memory rows) internal {
        require(rows.length != 0 && rows.length <= 64, "one bounded documentary catalog stage");
        for (uint256 i = 1; i < rows.length; ++i) {
            for (
                uint256 j = i;
                j > 0 && _documentaryPolicyKey(rows[j - 1]) > _documentaryPolicyKey(rows[j]);
                --j
            ) {
                (rows[j - 1], rows[j]) = (rows[j], rows[j - 1]);
            }
        }
        StreamGovernanceCatalogStagePlan.Inventory memory inventory =
            StreamGovernanceCatalogStagePlan.inventory(executor, rows);
        StreamSystemManifest.AggregateState memory current =
            StreamGenesisManifestPlan.readAggregate(manifest);
        (address payload, bytes32 hash) = StreamGenesisManifestPlan.writePayload(
            bytes("{\"fixture\":true,\"purpose\":\"documentary conservation producer admission\"}")
        );
        StreamSystemManifestUpdate memory update = StreamSystemManifestUpdate(
            hash,
            "urn:fixture:documentary-producer-admission",
            current.discovery.eventCatalogHash,
            current.discovery.compatibilityMatrixHash,
            current.discovery.numericIdCatalogHash,
            current.discovery.schemaCatalogHash,
            current.discovery.canonicalizationCatalogHash,
            current.discovery.specBundleHash,
            current.discovery.reconstructionClientHash
        );
        (GenesisBatch memory batch, uint256 count) = StreamGovernanceCatalogStagePlan.nextBatch(
            inventory,
            StreamGovernanceCatalogStagePlan.inventoryHash(inventory),
            0,
            manifest,
            payload,
            update
        );
        (bytes32 action, uint64 ready) =
            _scheduleBatchAsGovernor(batch.actionClass, batch.calls, batch.callDatas);
        vm.warp(ready);
        _documentarySafeCall(
            address(executor),
            abi.encodeCall(executor.executeGovernanceBatch, (action, batch.calls, batch.callDatas))
        );
        require(
            count == rows.length
                && executor.governanceAction(action).status == GovernanceActionStatus.EXECUTED,
            "complete actual documentary catalog stage"
        );
    }

    function _documentaryDocument(
        string memory name,
        IStreamSchemaRegistry.DocumentKind kind,
        bytes memory payload
    ) internal returns (bytes32 id) {
        id = keccak256(bytes(name));
        if (assemblySchemas.document(id).exists) {
            require(
                keccak256(assemblySchemas.documentBytes(id)) == keccak256(payload),
                "existing documentary schema has exact committed bytes"
            );
            return id;
        }
        bytes32[] memory chunks = new bytes32[]((payload.length + 8191) / 8192);
        for (uint256 i; i < chunks.length; ++i) {
            uint256 size = payload.length - i * 8192;
            if (size > 8192) size = 8192;
            bytes memory chunk = new bytes(size);
            for (uint256 j; j < size; ++j) {
                chunk[j] = payload[i * 8192 + j];
            }
            (chunks[i],) = assemblyStore.publishChunk(chunk);
        }
        IStreamSchemaRegistry.DocumentSpec memory spec = IStreamSchemaRegistry.DocumentSpec(
            name,
            kind,
            keccak256(payload),
            assemblySchemas.RAW_BYTES(),
            0,
            "",
            uint32(payload.length)
        );
        (bytes32 scope, bytes32 previous, bytes32 next) =
            assemblySchemas.registrationTransition(spec, chunks);
        _documentaryGovern(
            address(assemblySchemas),
            abi.encodeCall(assemblySchemas.registerDocument, (spec, chunks)),
            scope,
            previous,
            next
        );
        require(
            keccak256(assemblySchemas.documentBytes(id)) == keccak256(payload),
            "published exact documentary document"
        );
    }

    function _documentaryAdmitRecordType(bytes32 recordType, bytes32 family, uint16 writerMask)
        internal
    {
        (bytes32 scope, bytes32 previous, bytes32 next) =
            assemblyMetadata.recordTypeTransition(recordType, family, writerMask);
        _documentaryGovern(
            address(assemblyMetadata),
            abi.encodeCall(assemblyMetadata.admitRecordType, (recordType, family, writerMask)),
            scope,
            previous,
            next
        );
    }

    function _documentaryGrantWriter(bytes32 family, address writer) internal {
        (bool granted,) = assemblyMetadata.familyWriter(1, family, 7, writer);
        if (granted) return;
        (bytes32 scope, bytes32 previous, bytes32 next) =
            assemblyMetadata.familyWriterTransition(1, family, 7, writer, true);
        _documentaryGovern(
            address(assemblyMetadata),
            abi.encodeCall(assemblyMetadata.setFamilyWriter, (1, family, 7, writer, true)),
            scope,
            previous,
            next
        );
        (granted,) = assemblyMetadata.familyWriter(1, family, 7, writer);
        require(granted, "actual collection-scoped documentary writer");
    }

    function _documentaryBaseDocuments() internal {
        _documentaryDocument(
            "RAW_BYTES",
            IStreamSchemaRegistry.DocumentKind.CANONICALIZATION,
            bytes(assemblySchemas.RAW_BYTES_DEFINITION())
        );
        _documentaryDocument(
            "RFC8785_JCS",
            IStreamSchemaRegistry.DocumentKind.CANONICALIZATION,
            bytes(vm.readFile("schemas/museum/account-profile/RFC8785_JCS.json"))
        );
    }
}
