// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    StreamFinalityDiscoveryTypes as D
} from "../../interfaces/stream/finality/StreamFinalityDiscoveryTypes.sol";
import {
    StreamFinalityScope,
    StreamFinalityScopeType
} from "../../interfaces/stream/finality/StreamArtworkFinalityTypes.sol";
import {
    IStreamFinalityProfileSources as Profiles
} from "../../interfaces/stream/finality/IStreamFinalityProfileSources.sol";
import {
    IStreamFinalityViewPreservationBindingV1 as BasicAPI
} from "../../interfaces/stream/finality/IStreamFinalityViewPreservationBindingV1.sol";
import {
    IStreamFinalityViewPreservationCompleteBindingV1 as CompleteAPI
} from "../../interfaces/stream/finality/IStreamFinalityViewPreservationCompleteBindingV1.sol";
import {
    StreamFinalityViewPreservationBindingTypesV1 as Basic
} from "../../interfaces/stream/finality/StreamFinalityViewPreservationBindingTypesV1.sol";
import {
    StreamFinalityViewPreservationCompleteBindingTypesV1 as Complete
} from "../../interfaces/stream/finality/StreamFinalityViewPreservationCompleteBindingTypesV1.sol";
import {
    IStreamViewPreservationFinalitySourcesV1 as Sources
} from "../../interfaces/stream/finality/IStreamViewPreservationFinalitySourcesV1.sol";
import {
    IStreamViewPreservationEvidenceBindingV1 as SnapshotBinding
} from "../../interfaces/stream/finality/IStreamViewPreservationEvidenceBindingV1.sol";
import {
    IStreamViewPolicySourceBindingV2 as FactoryBinding
} from "../../interfaces/stream/finality/IStreamViewPolicySourceBindingV2.sol";
import {
    IStreamFinalityEntropySourceFactory as Factory
} from "../../interfaces/stream/finality/IStreamFinalityEntropySourceFactory.sol";
import {
    IStreamFinalityCurrentEntropyRoute as EntropyRoute
} from "../../interfaces/stream/finality/IStreamFinalityCurrentComponentRoutes.sol";
import {
    IStreamArtworkScopedFinalityComponent
} from "../../interfaces/stream/finality/IStreamArtworkFinalityComponents.sol";
import {
    IStreamViewPreservationContentCheckpointV1 as Checkpoint
} from "../../interfaces/stream/finality/IStreamViewPreservationContentCheckpointV1.sol";
import {
    StreamViewPreservationCheckpointTypesV1 as CheckpointTypes
} from "../../interfaces/stream/finality/StreamViewPreservationCheckpointTypesV1.sol";
import {
    StreamViewAdoptionTypes as Adoption
} from "../../interfaces/stream/metadata/StreamViewAdoptionTypes.sol";
import {
    StreamViewPreservationCheckpointSourceV1 as CheckpointSource
} from "./StreamViewPreservationCheckpointSourceV1.sol";
import {
    StreamPreservationInventoryIO as IO
} from "../preservation/StreamPreservationInventoryIO.sol";
import { StreamMetadataSubjects } from "../metadata/StreamMetadataSubjects.sol";
import { IERC165 } from "../../vendor/openzeppelin/IERC165.sol";

/// @notice Fixed VIEW discovery from the original provider's complete governed source binding.
/// @dev The host first pins its constructor-owned provider and source configuration. Reconstruct
/// the exact catalogue commitment from that provider's bound data without entering its catalogue,
/// inputs or component callbacks. Historical receipts alone do not establish operative binding.
library StreamFinalityViewPreservationDiscoveryV1 {
    bytes32 internal constant PROFILE = keccak256("6529STREAM_VIEW_PRESERVATION_FINALITY_V1");

    struct Bound {
        Basic.Capability capability;
        Basic.Receipt basic;
        Sources.Receipt complete;
        Profiles.Profile profile;
    }

    error InvalidViewDiscovery(address target);

    function profile(D.Configuration memory c, StreamFinalityScope memory scope)
        public
        view
        returns (Profiles.Profile memory)
    {
        _scope(c, scope);
        return _bound(c).profile;
    }

    function requireServing(D.Configuration memory c, StreamFinalityScope memory scope)
        public
        view
    {
        _scope(c, scope);
        Bound memory b = _bound(c);
        if (
            b.profile.referenceRender != c.referenceRender
                || b.profile.entropyFactory != c.entropyFactory
        ) revert InvalidViewDiscovery(c.provider);
        address checkpoint = b.basic.configuration.checkpointHost;
        bytes memory raw = IO.fixedRead(
            checkpoint, abi.encodeCall(Checkpoint.configuration, ()), 384, c.readGas
        );
        CheckpointTypes.Configuration memory configured =
            abi.decode(raw, (CheckpointTypes.Configuration));
        IO.canonical(checkpoint, raw, abi.encode(configured));
        if (
            configured.core != c.core || configured.coreCodeHash != c.core.codehash
                || configured.router != c.router || configured.routerCodeHash != c.router.codehash
                || configured.authority != b.capability.authority
                || configured.authorityCodeHash != b.capability.authorityCodeHash
                || configured.chainId != block.chainid
        ) revert InvalidViewDiscovery(checkpoint);
        // The fixed reader authenticates actual Router adoption, complete live renderer/read
        // roster, policy source set and preservation admission. Its contextHash contains this
        // Discovery address, so it is deliberately neither consumed nor compared to a checkpoint.
        CheckpointTypes.Source memory source = CheckpointSource.current(configured, scope);
        Adoption.Route memory route = source.adoption.source.route;
        if (
            keccak256(abi.encode(source.adoption.input.scope)) != keccak256(abi.encode(scope))
                || route.core != c.core || route.coreCodeHash != c.core.codehash
                || route.router != c.router || route.routerCodeHash != c.router.codehash
                || route.metadata != c.metadata || route.metadataCodeHash != c.metadata.codehash
                || route.provider != c.provider || route.providerCodeHash != c.provider.codehash
                || route.finality != c.finalityRegistry
                || route.finalityCodeHash != c.finalityRegistryCodeHash || route.artist != c.artist
                || route.artistCodeHash != c.artist.codehash
                || route.schemas != b.basic.dependencies.targets[2]
                || route.schemasCodeHash != b.basic.dependencies.codeHashes[2]
                || route.store != b.basic.dependencies.targets[3]
                || route.storeCodeHash != b.basic.dependencies.codeHashes[3]
                || keccak256(abi.encode(route.binding))
                    != keccak256(abi.encode(b.basic.declaration))
        ) revert InvalidViewDiscovery(c.router);
    }

    function _scope(D.Configuration memory c, StreamFinalityScope memory scope) private view {
        if (
            scope.scopeType != StreamFinalityScopeType.VIEW || c.readGas < 50000
                || c.componentGas < c.readGas
        ) revert InvalidViewDiscovery(c.provider);
        StreamMetadataSubjects.scopeSubject(block.chainid, c.core, scope);
    }

    function _bound(D.Configuration memory c) private view returns (Bound memory b) {
        _erc165(c.provider, c.readGas);
        _supports(c.provider, type(BasicAPI).interfaceId, c.readGas);
        _supports(c.provider, type(CompleteAPI).interfaceId, c.readGas);
        _supports(c.provider, type(Sources).interfaceId, c.readGas);
        _supports(c.provider, type(SnapshotBinding).interfaceId, c.readGas);
        _supports(c.provider, type(FactoryBinding).interfaceId, c.readGas);
        if (
            IO.word(
                        c.provider,
                        abi.encodeCall(BasicAPI.viewPreservationBindingProfile, ()),
                        c.readGas
                    ) != Basic.PROFILE
                || IO.word(
                        c.provider,
                        abi.encodeCall(CompleteAPI.completeViewPreservationBindingProfile, ()),
                        c.readGas
                    ) != Complete.PROFILE
                || IO.word(
                        c.provider,
                        abi.encodeCall(BasicAPI.viewPreservationBindingStatus, ()),
                        c.readGas
                    ) != bytes32(uint256(1))
        ) revert InvalidViewDiscovery(c.provider);

        bytes memory raw = IO.fixedRead(
            c.provider, abi.encodeCall(Sources.viewFinalitySources, ()), 192, c.componentGas
        );
        Sources.Selection memory operative = abi.decode(raw, (Sources.Selection));
        IO.canonical(c.provider, raw, abi.encode(operative));
        raw = IO.fixedRead(
            c.provider, abi.encodeCall(Sources.viewFinalitySourcesReceipt, ()), 416, c.readGas
        );
        b.complete = abi.decode(raw, (Sources.Receipt));
        IO.canonical(c.provider, raw, abi.encode(b.complete));
        raw = IO.fixedRead(
            c.provider,
            abi.encodeCall(BasicAPI.viewPreservationBindingCapability, ()),
            128,
            c.readGas
        );
        b.capability = abi.decode(raw, (Basic.Capability));
        IO.canonical(c.provider, raw, abi.encode(b.capability));
        raw = IO.fixedRead(
            c.provider, abi.encodeCall(BasicAPI.viewPreservationBindingReceipt, ()), 1376, c.readGas
        );
        b.basic = abi.decode(raw, (Basic.Receipt));
        IO.canonical(c.provider, raw, abi.encode(b.basic));
        if (
            b.capability.originalHash == 0
                || b.capability.capabilityHash
                    != Basic.hashCapability(block.chainid, c.provider, b.capability)
                || b.basic.capabilityHash != b.capability.capabilityHash || b.basic.recordHash == 0
                || b.basic.recordHash != Basic.receiptHash(b.basic)
                || b.basic.dependenciesHash != keccak256(abi.encode(b.basic.dependencies))
                || b.basic.workersHash == 0 || b.basic.actionId == 0 || b.basic.boundAt == 0
                || b.basic.boundAt > block.timestamp || b.complete.recordHash == 0
                || b.complete.recordHash
                    != Complete.receiptHash(block.chainid, c.provider, b.complete)
                || b.complete.basicBindingRecordHash != b.basic.recordHash
                || b.complete.actionId != b.basic.actionId || b.complete.boundAt != b.basic.boundAt
                || b.complete.referenceDependenciesHash == 0
                || b.complete.inventoryDependenciesHash == 0
                || b.complete.bundleDependenciesHash == 0
                || keccak256(abi.encode(operative)) != keccak256(abi.encode(b.complete.selection))
        ) revert InvalidViewDiscovery(c.provider);

        // Complete selection rechecks the full original inventory commitment. This separate
        // operative basic getter revalidates the basic source workers and constructor identities.
        address snapshot = _address(
            c.provider,
            abi.encodeCall(SnapshotBinding.viewPreservationSnapshotHost, ()),
            c.componentGas
        );
        if (snapshot != b.basic.configuration.snapshotHost) {
            revert InvalidViewDiscovery(c.provider);
        }
        IO.pin(b.capability.authority, b.capability.authorityCodeHash);
        IO.pin(snapshot, b.basic.configuration.snapshotCodeHash);
        IO.pin(b.basic.configuration.checkpointHost, b.basic.configuration.checkpointCodeHash);
        IO.pin(b.basic.configuration.manifestHost, b.basic.configuration.manifestCodeHash);
        IO.pin(operative.referencePublication, operative.referencePublicationCodeHash);
        IO.pin(operative.renderCriticalInventory, operative.renderCriticalInventoryCodeHash);
        IO.pin(operative.bundleArchiveCoverage, operative.bundleArchiveCoverageCodeHash);
        if (
            b.basic.dependencies.chainId != block.chainid
                || b.basic.dependencies.targets[0] != c.core
                || b.basic.dependencies.codeHashes[0] != c.core.codehash
                || b.basic.dependencies.targets[1] != c.metadata
                || b.basic.dependencies.codeHashes[1] != c.metadata.codehash
                || b.basic.dependencies.targets[4] != c.router
                || b.basic.dependencies.codeHashes[4] != c.router.codehash
                || b.basic.dependencies.targets[5] != c.membership
                || b.basic.dependencies.codeHashes[5] != c.membership.codehash
                || b.basic.dependencies.targets[6] != b.basic.configuration.checkpointHost
                || b.basic.dependencies.codeHashes[6] != b.basic.configuration.checkpointCodeHash
                || b.basic.dependencies.targets[7] != b.basic.configuration.manifestHost
                || b.basic.dependencies.codeHashes[7] != b.basic.configuration.manifestCodeHash
                || b.basic.dependencies.targets[9] != b.capability.authority
                || b.basic.dependencies.codeHashes[9] != b.capability.authorityCodeHash
                || b.basic.declaration.membership != c.membership
                || b.basic.declaration.membershipCodeHash != c.membership.codehash
        ) revert InvalidViewDiscovery(c.provider);

        address factory = _address(
            c.provider, abi.encodeCall(FactoryBinding.viewPolicySourceFactoryV2, ()), c.readGas
        );
        bytes32 factoryHash = IO.word(
            c.provider,
            abi.encodeCall(FactoryBinding.viewPolicySourceFactoryV2CodeHash, ()),
            c.readGas
        );
        IO.pin(factory, factoryHash);
        _sameAddress(snapshot, "core()", c.core, c.readGas);
        _sameAddress(snapshot, "metadataHost()", c.metadata, c.readGas);
        _sameAddress(operative.referencePublication, "core()", c.core, c.readGas);
        _sameAddress(operative.referencePublication, "metadataHost()", c.metadata, c.readGas);
        _sameAddress(operative.referencePublication, "metadataRouter()", c.router, c.readGas);
        _sameAddress(operative.referencePublication, "snapshots()", snapshot, c.readGas);
        _sameAddress(factory, "core()", c.core, c.readGas);
        _sameAddress(factory, "metadataHost()", c.metadata, c.readGas);
        _sameAddress(factory, "scopeMembershipHost()", c.membership, c.readGas);
        _erc165(factory, c.readGas);
        _erc165(operative.referencePublication, c.readGas);
        _supports(factory, type(Factory).interfaceId, c.readGas);
        _supports(factory, type(EntropyRoute).interfaceId, c.readGas);
        _supports(
            operative.referencePublication,
            type(IStreamArtworkScopedFinalityComponent).interfaceId,
            c.readGas
        );
        b.profile = Profiles.Profile(
            PROFILE,
            operative.referencePublication,
            operative.referencePublicationCodeHash,
            snapshot,
            b.basic.configuration.snapshotCodeHash,
            factory,
            factoryHash,
            keccak256(
                abi.encode(
                    PROFILE,
                    block.chainid,
                    c.provider,
                    b.capability.originalHash,
                    b.complete.recordHash
                )
            )
        );
    }

    function _erc165(address target, uint256 cap) private view {
        _supports(target, type(IERC165).interfaceId, cap);
        if (
            IO.word(target, abi.encodeCall(IERC165.supportsInterface, (bytes4(0xffffffff))), cap)
                != 0
        ) {
            revert InvalidViewDiscovery(target);
        }
    }

    function _supports(address target, bytes4 id, uint256 cap) private view {
        if (
            IO.word(target, abi.encodeCall(IERC165.supportsInterface, (id)), cap)
                != bytes32(uint256(1))
        ) {
            revert InvalidViewDiscovery(target);
        }
    }

    function _address(address target, bytes memory input, uint256 cap)
        private
        view
        returns (address value)
    {
        uint256 word = uint256(IO.word(target, input, cap));
        if (word == 0 || word > type(uint160).max) revert InvalidViewDiscovery(target);
        return address(uint160(word));
    }

    function _sameAddress(address target, string memory selector, address expected, uint256 cap)
        private
        view
    {
        if (_address(target, abi.encodeWithSignature(selector), cap) != expected) {
            revert InvalidViewDiscovery(target);
        }
    }
}
