// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./StreamCurrentStackPlan.sol";
import {
    IStreamGasParameterHost
} from "../../smart-contracts/interfaces/stream/parameters/IStreamGasParameterHost.sol";
import { IStreamMintGate } from "../../smart-contracts/interfaces/stream/mint/IStreamMintGate.sol";
import {
    GenesisBatch
} from "../../smart-contracts/interfaces/stream/governance/IStreamGenesisInitializer.sol";
import { StreamClaimRouter } from "../../smart-contracts/domains/revenue/StreamClaimRouter.sol";
import { StreamMintTicketGate } from "../../smart-contracts/domains/mint/StreamMintTicketGate.sol";
import {
    StreamDelegateRegistryGate
} from "../../smart-contracts/domains/mint/StreamDelegateRegistryGate.sol";
import { StreamOwnerRecords } from "../../smart-contracts/domains/metadata/StreamOwnerRecords.sol";
import {
    StreamCollectionAttestations
} from "../../smart-contracts/domains/metadata/StreamCollectionAttestations.sol";
import {
    StreamCollectionViews
} from "../../smart-contracts/domains/metadata/StreamCollectionViews.sol";
import {
    StreamCollectionMetadataV1
} from "../../smart-contracts/domains/metadata/StreamCollectionMetadataV1.sol";

/// @notice Original products for independent full-v1 genesis roles 10,13,19,26,28,29.
/// @dev Construction and registration planning are separate observed stages. This library
/// does not initialize the foundation, select pointers, grant roles, or claim a complete
/// genesis deployment. The actual claim router is permissionless and has no ERC165 surface;
/// it is recorded as a deployed role, never given a fictitious registry interface.
/// Role28 here is the existing independent-class5 host; its general signer-verified
/// institutional/estate producer remains a separately required composition input.
library StreamFullV1GenesisProducts {
    error InvalidGenesisProductDependencies();
    error GenesisProductChanged(address product);

    struct Manifest {
        bytes32 hash;
        string uri;
    }

    struct Configuration {
        address core;
        address executor;
        address metadata;
        address schemas;
        address ticketSigner;
        uint8 ticketSignerKind;
        address delegateRegistry;
        bytes32 delegationUsecase;
        bytes32 deploymentHash;
        Manifest ticket;
        string delegateManifestURI;
        Manifest owner;
        Manifest attestation;
        Manifest views;
        IStreamGasParameterHost.GasParameterConfig signatureGas;
        IStreamGasParameterHost.GasParameterConfig dependencyReadGas;
    }

    struct Products {
        uint256 chainId;
        StreamClaimRouter claims;
        StreamMintTicketGate tickets;
        StreamDelegateRegistryGate delegates;
        StreamOwnerRecords owners;
        StreamCollectionAttestations attestations;
        StreamCollectionViews views;
        bytes32[6] codeHashes;
        bytes32 configurationHash;
    }

    /// @dev All original constructors run with the caller as deployer; no replacement host,
    /// runtime substitution, initializer bypass or authority-bearing deployment proxy is used.
    function deploy(Configuration memory c) internal returns (Products memory p) {
        _dependencies(c);
        p.chainId = block.chainid;
        p.configurationHash = keccak256(abi.encode(c));
        p.claims = new StreamClaimRouter();
        p.tickets = new StreamMintTicketGate(c.executor, c.ticketSigner, c.ticketSignerKind);
        p.delegates = new StreamDelegateRegistryGate(
            c.core, c.delegateRegistry, c.delegationUsecase, c.executor
        );
        p.owners = new StreamOwnerRecords(
            StreamOwnerRecords.Configuration(
                c.core,
                c.schemas,
                c.executor,
                c.deploymentHash,
                c.owner.uri,
                c.owner.hash,
                c.signatureGas,
                c.dependencyReadGas
            )
        );
        p.attestations = new StreamCollectionAttestations(
            StreamCollectionAttestations.Configuration(
                c.core,
                c.schemas,
                c.executor,
                c.deploymentHash,
                c.attestation.uri,
                c.attestation.hash,
                c.signatureGas,
                c.dependencyReadGas
            )
        );
        p.views = new StreamCollectionViews(
            StreamCollectionViews.Configuration(
                c.core,
                c.metadata,
                c.executor,
                c.deploymentHash,
                c.views.uri,
                c.views.hash,
                c.dependencyReadGas
            )
        );
        address[6] memory hosts = addresses(p);
        for (uint256 i; i < hosts.length; ++i) {
            p.codeHashes[i] = hosts[i].codehash;
        }
        validate(c, p);
    }

    function addresses(Products memory p) internal pure returns (address[6] memory) {
        return [
            address(p.claims),
            address(p.tickets),
            address(p.delegates),
            address(p.owners),
            address(p.attestations),
            address(p.views)
        ];
    }

    /// @notice Authenticate the retained deployment before constructing a later action.
    function validate(Configuration memory c, Products memory p) internal view {
        _dependencies(c);
        if (p.chainId != block.chainid || p.configurationHash != keccak256(abi.encode(c))) {
            revert InvalidGenesisProductDependencies();
        }
        address[6] memory hosts = addresses(p);
        for (uint256 i; i < hosts.length; ++i) {
            if (hosts[i].code.length == 0 || hosts[i].codehash != p.codeHashes[i]) {
                revert GenesisProductChanged(hosts[i]);
            }
            for (uint256 j; j < i; ++j) {
                if (hosts[j] == hosts[i]) revert GenesisProductChanged(hosts[i]);
            }
        }
        if (
            p.tickets.ticketSigner() != c.ticketSigner
                || p.tickets.ticketSignerKind() != c.ticketSignerKind
                || p.tickets.governanceAuthority() != c.executor || p.delegates.core() != c.core
                || p.delegates.delegateRegistry() != c.delegateRegistry
                || p.delegates.delegateRegistryCodeHash() != c.delegateRegistry.codehash
                || p.delegates.delegationUsecase() != c.delegationUsecase
                || p.delegates.governanceAuthority() != c.executor || p.owners.core() != c.core
                || p.owners.schemaRegistry() != c.schemas
                || p.owners.governanceAuthority() != c.executor || p.attestations.core() != c.core
                || p.attestations.schemaRegistry() != c.schemas
                || p.attestations.governanceAuthority() != c.executor || p.views.core() != c.core
                || p.views.metadataHost() != c.metadata || p.views.schemaRegistry() != c.schemas
                || p.views.governanceAuthority() != c.executor
                || p.owners.chunkStore() != p.attestations.chunkStore()
                || p.owners.chunkStore() != p.views.chunkStore()
        ) {
            revert InvalidGenesisProductDependencies();
        }
    }

    /// @notice Five genuine ERC165 module rows; role10 is a separate noncustodial identity.
    function registrations(
        Configuration memory c,
        Products memory p,
        uint32 gateGas,
        uint32 readGas
    ) internal view returns (StreamModuleRegistration[] memory rows) {
        validate(c, p);
        if (gateGas == 0 || readGas == 0) revert InvalidGenesisProductDependencies();
        rows = new StreamModuleRegistration[](5);
        rows[0] = _record(
            address(p.tickets),
            keccak256("6529STREAM_MINT_GATE_V1"),
            keccak256("6529STREAM_MINT_TICKET_GATE_V1"),
            type(IStreamMintGate).interfaceId,
            gateGas,
            c.deploymentHash,
            c.ticket
        );
        rows[1] = _record(
            address(p.delegates),
            keccak256("6529STREAM_MINT_GATE_V1"),
            p.delegates.MODULE_VERSION(),
            type(IStreamMintGate).interfaceId,
            gateGas,
            c.deploymentHash,
            Manifest(p.delegates.moduleManifestHash(), c.delegateManifestURI)
        );
        rows[2] = _record(
            address(p.owners),
            p.owners.streamModuleType(),
            p.owners.streamModuleVersion(),
            p.owners.streamModuleInterfaceId(),
            readGas,
            c.deploymentHash,
            c.owner
        );
        rows[3] = _record(
            address(p.attestations),
            p.attestations.streamModuleType(),
            p.attestations.streamModuleVersion(),
            p.attestations.streamModuleInterfaceId(),
            readGas,
            c.deploymentHash,
            c.attestation
        );
        rows[4] = _record(
            address(p.views),
            p.views.streamModuleType(),
            p.views.streamModuleVersion(),
            p.views.streamModuleInterfaceId(),
            readGas,
            c.deploymentHash,
            c.views
        );
    }

    /// @dev The caller appends the canonical same-class manifest publication before scheduling.
    /// Rebuild after observing preceding registry changes; these hashes bind the current chain.
    function registrationBatch(
        StreamModuleRegistry registry,
        Configuration memory c,
        Products memory p,
        uint32 gateGas,
        uint32 readGas
    ) internal view returns (GenesisBatch memory batch) {
        if (address(registry.governanceExecutor()) != c.executor) {
            revert InvalidGenesisProductDependencies();
        }
        batch.actionClass = 1;
        (batch.calls, batch.callDatas) = StreamCurrentStackPlan.registrationCalls(
            registry, registrations(c, p, gateGas, readGas)
        );
    }

    function _dependencies(Configuration memory c) private view {
        if (
            c.core.code.length == 0 || c.executor.code.length == 0 || c.metadata.code.length == 0
                || c.schemas.code.length == 0 || c.delegateRegistry.code.length == 0
                || c.delegationUsecase == 0 || c.ticketSigner == address(0)
                || (c.ticketSignerKind != 1 && c.ticketSignerKind != 2) || c.deploymentHash == 0
                || c.ticket.hash == 0 || bytes(c.ticket.uri).length == 0
                || bytes(c.delegateManifestURI).length == 0 || c.owner.hash == 0
                || c.attestation.hash == 0 || c.views.hash == 0
        ) {
            revert InvalidGenesisProductDependencies();
        }
        StreamCollectionMetadataV1 metadata = StreamCollectionMetadataV1(c.metadata);
        if (
            metadata.core() != c.core || metadata.schemaRegistry() != c.schemas
                || metadata.governanceAuthority() != c.executor
        ) {
            revert InvalidGenesisProductDependencies();
        }
    }

    function _record(
        address target,
        bytes32 kind,
        bytes32 version,
        bytes4 interfaceId,
        uint32 gasLimit,
        bytes32 deploymentHash,
        Manifest memory manifest
    ) private view returns (StreamModuleRegistration memory) {
        return StreamModuleRegistration(
            target,
            kind,
            version,
            interfaceId,
            gasLimit,
            target.codehash,
            deploymentHash,
            manifest.hash,
            manifest.uri
        );
    }
}
