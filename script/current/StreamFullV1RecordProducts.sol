// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./StreamCurrentStackPlan.sol";
import {
    IStreamGasParameterHost
} from "../../smart-contracts/interfaces/stream/parameters/IStreamGasParameterHost.sol";
import {
    IStreamSchemaRegistry
} from "../../smart-contracts/interfaces/stream/metadata/IStreamSchemaRegistry.sol";
import {
    StreamPreservationRecordsV1
} from "../../smart-contracts/domains/preservation/StreamPreservationRecordsV1.sol";
import {
    StreamGeneralAttestations
} from "../../smart-contracts/domains/metadata/StreamGeneralAttestations.sol";
import {
    StreamCollectionMetadataV1
} from "../../smart-contracts/domains/metadata/StreamCollectionMetadataV1.sol";
import {
    StreamGeneralArtistEvidence
} from "../../smart-contracts/domains/metadata/StreamGeneralArtistEvidence.sol";

/// @notice Original full-byte role27 and additional general/notarized role28 products.
/// @dev Complements the independent-class5 role28 host and optional legacy adapter;
/// neither is replaced. Construction is separate from catalog admission, registration,
/// schema publication and family grants. Runtime observations are not compiler provenance.
library StreamFullV1RecordProducts {
    error InvalidRecordComposition();
    error RecordCompositionChanged(address target);

    struct Manifest {
        bytes32 hash;
        string uri;
    }

    struct Configuration {
        address core;
        address executor;
        address metadata;
        address schemas;
        address artistRegistry;
        address artistAttribution;
        bytes32 deploymentHash;
        Manifest preservation;
        Manifest general;
        IStreamGasParameterHost.GasParameterConfig signatureGas;
        IStreamGasParameterHost.GasParameterConfig dependencyReadGas;
    }

    struct Products {
        uint256 chainId;
        StreamPreservationRecordsV1 preservation;
        StreamGeneralAttestations general;
        bytes32 preservationCodeHash;
        bytes32 generalCodeHash;
        bytes32 configurationHash;
        // Core, executor, metadata, schema registry, store, Artist registry, attribution owner.
        bytes32[7] dependencyCodeHashes;
    }

    function deploy(Configuration memory c) internal returns (Products memory p) {
        address[7] memory dependencies = _dependencies(c);
        p.chainId = block.chainid;
        p.configurationHash = keccak256(abi.encode(c));
        for (uint256 i; i < dependencies.length; ++i) {
            p.dependencyCodeHashes[i] = dependencies[i].codehash;
        }
        p.preservation = new StreamPreservationRecordsV1(
            StreamPreservationRecordsV1.Configuration(
                c.core,
                c.metadata,
                c.executor,
                c.deploymentHash,
                c.preservation.uri,
                c.preservation.hash,
                c.dependencyReadGas
            )
        );
        p.general = new StreamGeneralAttestations(
            StreamGeneralAttestations.Configuration(
                c.core,
                c.schemas,
                c.metadata,
                c.artistRegistry,
                c.artistAttribution,
                c.executor,
                c.deploymentHash,
                c.general.uri,
                c.general.hash,
                c.signatureGas,
                c.dependencyReadGas
            )
        );
        p.preservationCodeHash = address(p.preservation).codehash;
        p.generalCodeHash = address(p.general).codehash;
        validate(c, p);
    }

    function validate(Configuration memory c, Products memory p) internal view {
        address[7] memory dependencies = _dependencies(c);
        if (p.chainId != block.chainid || p.configurationHash != keccak256(abi.encode(c))) {
            revert InvalidRecordComposition();
        }
        for (uint256 i; i < dependencies.length; ++i) {
            _pin(dependencies[i], p.dependencyCodeHashes[i]);
        }
        _pin(address(p.preservation), p.preservationCodeHash);
        _pin(address(p.general), p.generalCodeHash);
        if (
            address(p.preservation) == address(p.general) || p.preservation.core() != c.core
                || p.general.core() != c.core || p.preservation.metadataHost() != c.metadata
                || p.general.metadataAuthority() != c.metadata
                || p.preservation.schemaRegistry() != c.schemas
                || p.general.schemaRegistry() != c.schemas
                || p.preservation.chunkStore() != dependencies[4]
                || p.general.chunkStore() != dependencies[4]
                || p.preservation.governanceAuthority() != c.executor
                || p.general.governanceAuthority() != c.executor
                || p.general.artistRegistry() != c.artistRegistry
                || p.general.artistAttribution() != c.artistAttribution
                || p.general.coreCodeHash() != dependencies[0].codehash
                || p.general.schemaRegistryCodeHash() != dependencies[3].codehash
                || p.general.chunkStoreCodeHash() != dependencies[4].codehash
                || p.general.metadataAuthorityCodeHash() != dependencies[2].codehash
                || p.general.artistRegistryCodeHash() != dependencies[5].codehash
                || p.general.artistAttributionCodeHash() != dependencies[6].codehash
        ) revert InvalidRecordComposition();
    }

    /// @notice Two genuine interfaces, both additional to the selected MetadataV1 host.
    function registrations(Configuration memory c, Products memory p, uint32 readGas)
        internal
        view
        returns (StreamModuleRegistration[] memory rows)
    {
        validate(c, p);
        if (readGas == 0) revert InvalidRecordComposition();
        rows = new StreamModuleRegistration[](2);
        rows[0] = StreamModuleRegistration(
            address(p.preservation),
            p.preservation.streamModuleType(),
            p.preservation.streamModuleVersion(),
            p.preservation.streamModuleInterfaceId(),
            readGas,
            p.preservationCodeHash,
            c.deploymentHash,
            c.preservation.hash,
            c.preservation.uri
        );
        rows[1] = StreamModuleRegistration(
            address(p.general),
            p.general.streamModuleType(),
            p.general.streamModuleVersion(),
            p.general.streamModuleInterfaceId(),
            readGas,
            p.generalCodeHash,
            c.deploymentHash,
            c.general.hash,
            c.general.uri
        );
    }

    /// @dev The caller sorts and appends these exact-target rows through the actual catalog
    /// stage planner and its manifest tail. No record-writing privilege is granted here.
    function operatingPolicies(Configuration memory c, Products memory p)
        internal
        view
        returns (GovernanceActionPolicyEntry[] memory rows)
    {
        validate(c, p);
        rows = new GovernanceActionPolicyEntry[](2);
        rows[0] = GovernanceActionPolicyEntry(
            1,
            address(p.preservation),
            p.preservation.raiseGasParameter.selector,
            p.preservationCodeHash,
            c.deploymentHash,
            1,
            0,
            0,
            0
        );
        rows[1] = GovernanceActionPolicyEntry(
            1,
            address(p.general),
            p.general.raiseGasParameter.selector,
            p.generalCodeHash,
            c.deploymentHash,
            1,
            0,
            0,
            0
        );
    }

    function _dependencies(Configuration memory c) private view returns (address[7] memory d) {
        if (c.deploymentHash == 0 || c.preservation.hash == 0 || c.general.hash == 0) {
            revert InvalidRecordComposition();
        }
        d = [
            c.core,
            c.executor,
            c.metadata,
            c.schemas,
            address(0),
            c.artistRegistry,
            c.artistAttribution
        ];
        for (uint256 i; i < d.length; ++i) {
            if (i != 4 && d[i].code.length == 0) revert RecordCompositionChanged(d[i]);
        }
        StreamCollectionMetadataV1 metadata = StreamCollectionMetadataV1(c.metadata);
        if (
            metadata.core() != c.core || metadata.schemaRegistry() != c.schemas
                || metadata.governanceAuthority() != c.executor
                || IStreamSchemaRegistry(c.schemas).governanceAuthority() != c.executor
        ) {
            revert InvalidRecordComposition();
        }
        d[4] = IStreamSchemaRegistry(c.schemas).chunkStore();
        if (d[4].code.length == 0 || metadata.chunkStore() != d[4]) {
            revert InvalidRecordComposition();
        }
        // Includes the original Registry -> Coordinator -> owners[4] reciprocal bindings.
        StreamGeneralArtistEvidence.requireBinding(
            StreamGeneralArtistEvidence.Configuration(
                c.core,
                c.artistRegistry,
                c.artistAttribution,
                c.artistRegistry.codehash,
                c.artistAttribution.codehash,
                c.dependencyReadGas.genesisValue
            )
        );
    }

    function _pin(address target, bytes32 hash) private view {
        if (target.code.length == 0 || target.codehash != hash) {
            revert RecordCompositionChanged(target);
        }
    }
}
