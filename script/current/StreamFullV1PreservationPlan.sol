// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./StreamCurrentStackPlan.sol";
import "../../smart-contracts/domains/metadata/StreamMetadataGovernanceAdapter.sol";
import "../../smart-contracts/domains/metadata/StreamCollectionMetadata.sol";
import "../../smart-contracts/domains/preservation/StreamPreservationRecords.sol";
import {
    GenesisBatch
} from "../../smart-contracts/interfaces/stream/governance/IStreamGenesisInitializer.sol";

/// @notice Original role27 preservation host and its narrowly scoped compatibility support.
/// @dev The legacy CollectionMetadata instance is a family registry support host, never the
/// role24 pointer (which remains CollectionMetadataV1). This does not prove complete museum
/// payload coverage. Plans are observed stages; register/admit through the canonical Executor
/// with its required manifest tail and install tightening before exposing pause operations.
library StreamFullV1PreservationPlan {
    struct Products {
        StreamMetadataGovernanceAdapter admins;
        StreamCollectionMetadata families;
        StreamPreservationRecords records;
    }

    function deploy(address core, address executor) internal returns (Products memory p) {
        require(core.code.length != 0, "original Core required");
        p.admins = new StreamMetadataGovernanceAdapter(executor);
        p.families = new StreamCollectionMetadata(core, address(p.admins), address(0));
        p.records =
            new StreamPreservationRecords(core, address(p.admins), address(p.families), address(0));
        require(p.families.configurationAuthority() == executor, "original constructor authority");
    }

    function bind(Products memory p) internal view returns (GenesisBatch memory) {
        require(p.admins.familyRegistry() == address(0), "unbound metadata support");
        bytes memory data =
            abi.encodeCall(p.admins.bindMetadataHosts, (address(p.families), address(p.records)));
        return _one(
            1,
            address(p.admins),
            data,
            p.admins.bindingScope(),
            bytes32(0),
            p.admins.bindingHash(address(p.families), address(p.records))
        );
    }

    function operatingPolicies(Products memory p, bytes32 profile)
        internal
        view
        returns (GovernanceActionPolicyEntry[] memory rows)
    {
        rows = new GovernanceActionPolicyEntry[](8);
        rows[0] = _policy(1, address(p.admins), p.admins.bindMetadataHosts.selector, profile);
        rows[1] = _policy(0, address(p.admins), p.admins.pauseMetadata.selector, profile);
        rows[2] = _policy(1, address(p.admins), p.admins.resumeMetadata.selector, profile);
        rows[3] = _policy(1, address(p.families), p.families.admitRecordType.selector, profile);
        rows[4] = _policy(1, address(p.families), p.families.setRecordFamilyGrant.selector, profile);
        rows[5] = _policy(3, address(p.families), p.families.updateAdminContract.selector, profile);
        rows[6] = _policy(3, address(p.records), p.records.updateAdminContract.selector, profile);
        rows[7] = _policy(2, address(p.families), p.families.lockCollectionRecord.selector, profile);
    }

    function registrations(
        Products memory p,
        bytes32 deploymentHash,
        bytes32 manifestHash,
        string memory manifestURI,
        uint32 readGas
    ) internal view returns (StreamModuleRegistration[] memory rows) {
        require(
            deploymentHash != 0 && manifestHash != 0 && bytes(manifestURI).length != 0
                && readGas != 0,
            "preservation registration facts"
        );
        rows = new StreamModuleRegistration[](3);
        rows[0] = StreamModuleRegistration(
            address(p.records),
            p.records.streamModuleFamily(),
            p.records.streamModuleVersion(),
            type(IStreamPreservationRecords).interfaceId,
            readGas,
            address(p.records).codehash,
            deploymentHash,
            manifestHash,
            manifestURI
        );
        rows[1] = StreamModuleRegistration(
            address(p.families),
            keccak256("6529STREAM_RECORD_FAMILY_REGISTRY_V1"),
            p.families.streamModuleVersion(),
            type(IStreamRecordFamilyRegistry).interfaceId,
            readGas,
            address(p.families).codehash,
            deploymentHash,
            manifestHash,
            manifestURI
        );
        rows[2] = StreamModuleRegistration(
            address(p.admins),
            keccak256("6529STREAM_METADATA_GOVERNANCE_ADAPTER"),
            keccak256("6529STREAM_METADATA_GOVERNANCE_ADAPTER_V1"),
            type(IStreamAdmins).interfaceId,
            readGas,
            address(p.admins).codehash,
            deploymentHash,
            manifestHash,
            manifestURI
        );
    }

    function admitRecordType(Products memory p, bytes32 recordType, bytes32 family, uint16 mask)
        internal
        view
        returns (GenesisBatch memory)
    {
        require(!p.families.recordTypePolicy(recordType).admitted, "fresh record type");
        bytes memory data = abi.encodeCall(p.families.admitRecordType, (recordType, family, mask));
        return _configuration(
            p,
            data,
            keccak256("RECORD_TYPE_ADMITTED"),
            keccak256(
                abi.encode(
                    recordType, family, mask, uint64(1), p.families.recordTypeCount() + uint64(1)
                )
            )
        );
    }

    function grantWriter(
        Products memory p,
        bytes32 family,
        uint8 authorizationClass,
        address writer,
        bool enabled
    ) internal view returns (GenesisBatch memory) {
        (bool current, uint64 revision) =
            p.families.recordFamilyGrant(family, authorizationClass, writer);
        require(current != enabled, "writer grant transition");
        bytes memory data = abi.encodeCall(
            p.families.setRecordFamilyGrant, (family, authorizationClass, writer, enabled)
        );
        return _configuration(
            p,
            data,
            keccak256("FAMILY_GRANT_UPDATED"),
            keccak256(abi.encode(family, authorizationClass, writer, enabled, revision + uint64(1)))
        );
    }

    function pause(Products memory p, bool paused) internal view returns (GenesisBatch memory) {
        require(p.admins.metadataPaused() != paused, "pause transition");
        bytes memory data = paused
            ? abi.encodeCall(p.admins.pauseMetadata, ())
            : abi.encodeCall(p.admins.resumeMetadata, ());
        return _one(
            paused ? 0 : 1,
            address(p.admins),
            data,
            p.admins.pauseScope(),
            p.admins.pauseStateHash(!paused, p.admins.pauseRevision()),
            p.admins.pauseStateHash(paused, p.admins.pauseRevision() + uint64(1))
        );
    }

    /// @notice Isolated delayed classifier write, required in addition to the class0 catalog row.
    function pauseClassification(Products memory p) internal view returns (GenesisBatch memory) {
        IStreamGovernanceExecutor executor =
            IStreamGovernanceExecutor(p.admins.governanceExecutor());
        address target = address(p.admins);
        bytes4 selector = p.admins.pauseMetadata.selector;
        (bool enabled,, uint64 revision, bytes32 oldHash) =
            executor.tighteningCallConfig(target, selector);
        require(!enabled, "unclassified pause");
        bytes32 kind = keccak256("6529STREAM_GOVERNANCE_CONFIG_TIGHTENING_CALL");
        bytes32 scope = keccak256(
            abi.encode(
                keccak256("6529STREAM_GOVERNANCE_CONFIG_SCOPE_V1"),
                block.chainid,
                address(executor),
                kind,
                target,
                selector
            )
        );
        bytes32 newHash = keccak256(
            abi.encode(
                keccak256("6529STREAM_GOVERNANCE_CONFIG_STATE_V1"),
                block.chainid,
                address(executor),
                kind,
                target,
                selector,
                true,
                target.codehash,
                revision + uint64(1)
            )
        );
        return _one(
            1,
            address(executor),
            abi.encodeCall(executor.setTighteningCall, (target, selector, true)),
            scope,
            oldHash,
            newHash
        );
    }

    function _configuration(
        Products memory p,
        bytes memory data,
        bytes32 mutation,
        bytes32 mutationHash
    ) private view returns (GenesisBatch memory) {
        bytes32 oldHash = p.families.configurationHash();
        bytes32 nextHash = keccak256(
            abi.encode(
                keccak256("6529STREAM_RECORD_FAMILY_CONFIGURATION_V1"),
                block.chainid,
                address(p.families),
                oldHash,
                p.families.configurationRevision() + uint64(1),
                mutation,
                mutationHash
            )
        );
        return _one(
            1,
            address(p.families),
            data,
            keccak256(
                abi.encode(
                    keccak256("6529STREAM_RECORD_FAMILY_CONFIGURATION_SCOPE_V1"),
                    block.chainid,
                    address(p.families)
                )
            ),
            oldHash,
            nextHash
        );
    }

    function _one(
        uint8 actionClass,
        address target,
        bytes memory data,
        bytes32 scope,
        bytes32 oldHash,
        bytes32 newHash
    ) private pure returns (GenesisBatch memory batch) {
        batch.actionClass = actionClass;
        batch.calls = new GovernanceCall[](1);
        batch.callDatas = new bytes[](1);
        batch.callDatas[0] = data;
        batch.calls[0] = StreamCurrentStackPlan.call(target, data, scope, oldHash, newHash);
    }

    function _policy(uint8 actionClass, address target, bytes4 selector, bytes32 profile)
        private
        view
        returns (GovernanceActionPolicyEntry memory)
    {
        return GovernanceActionPolicyEntry(
            actionClass, target, selector, target.codehash, profile, 1, 0, 0, bytes32(0)
        );
    }
}
