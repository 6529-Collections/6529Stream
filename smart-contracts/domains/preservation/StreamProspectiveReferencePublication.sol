// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    IStreamProspectiveReferencePublication
} from "../../interfaces/stream/preservation/IStreamProspectiveReferencePublication.sol";
import {
    StreamProspectiveReferenceTypes as P
} from "../../interfaces/stream/preservation/StreamProspectiveReferenceTypes.sol";
import {
    StreamReferenceRenderTypes as R
} from "../../interfaces/stream/preservation/StreamReferenceRenderTypes.sol";
import {
    IStreamCollectionMetadataV1
} from "../../interfaces/stream/metadata/IStreamCollectionMetadataV1.sol";
import {
    IStreamReferenceInventoryPreparation
} from "../../interfaces/stream/preservation/IStreamReferenceInventoryPreparation.sol";
import {
    IStreamReferenceEnvironmentPreparation
} from "../../interfaces/stream/preservation/IStreamReferenceEnvironmentPreparation.sol";
import { StreamSnapshotManifestBytes as Bytes } from "../records/StreamSnapshotManifestBytes.sol";
import { StreamRecordFamilies } from "../records/StreamRecordFamilies.sol";
import {
    StreamProspectiveReferenceDefinitions as D
} from "../records/StreamProspectiveReferenceDefinitions.sol";
import { StreamMetadataRenderer } from "../metadata/StreamMetadataRenderer.sol";
import { StreamGasParameterHost } from "../parameters/StreamGasParameterHost.sol";
import {
    IStreamGasParameterHost
} from "../../interfaces/stream/parameters/IStreamGasParameterHost.sol";
import {
    StreamProspectiveReferenceSourceReads as Sources
} from "./StreamProspectiveReferenceSourceReads.sol";
import {
    StreamProspectiveReferenceEncoding as Encoding
} from "./StreamProspectiveReferenceEncoding.sol";
import {
    StreamProspectiveReferenceRecords as Records
} from "./StreamProspectiveReferenceRecords.sol";
import {
    StreamReferenceRenderPreparation as Preparation
} from "./StreamReferenceRenderPreparation.sol";
import {
    StreamReferenceInventoryPreparation as Inventory
} from "./StreamReferenceInventoryPreparation.sol";

/// @notice Original CURATOR observations for an explicitly named prospective simulation.
/// @dev No finality interface: actual token/serial captures remain a distinct required later stage.
contract StreamProspectiveReferencePublication is
    IStreamProspectiveReferencePublication,
    IStreamReferenceInventoryPreparation,
    IStreamReferenceEnvironmentPreparation,
    StreamGasParameterHost
{
    bytes32 public constant READ_GAS = keccak256("6529STREAM_GGP_PROSPECTIVE_REFERENCE_READ_GAS");
    bytes32 public constant SOURCE_GAS =
        keccak256("6529STREAM_GGP_PROSPECTIVE_REFERENCE_SOURCE_GAS");
    bytes32 public constant ARCHIVE_GAS =
        keccak256("6529STREAM_GGP_PROSPECTIVE_REFERENCE_ARCHIVE_GAS");
    address public immutable override core;
    address public immutable override conservationFloor;
    uint256 public immutable deploymentChainId;
    P.Dependencies private _fixed;
    mapping(bytes32 => Bytes.Manifest) private _publications;
    mapping(bytes32 => Bytes.Manifest) private _payloads;
    mapping(bytes32 => Bytes.Manifest) private _inventories;
    mapping(bytes32 => P.Receipt) private _receipts;
    mapping(uint256 => bytes32[]) private _history;
    mapping(uint256 => mapping(bytes32 => bool)) private _ids;
    bool private _entered;

    constructor(P.Dependencies memory d, address executor, GasParameterConfig[3] memory configs)
        StreamGasParameterHost(executor)
    {
        if (
            _registerGasParameter(configs[0]) != READ_GAS
                || _registerGasParameter(configs[1]) != SOURCE_GAS
                || _registerGasParameter(configs[2]) != ARCHIVE_GAS
        ) revert P.InvalidProspectiveReference();
        for (uint256 i; i < 3; ++i) {
            if (configs[i].failureClass != 2) revert P.InvalidProspectiveReference();
        }
        _fixed = d;
        core = d.targets[0];
        conservationFloor = d.targets[1];
        deploymentChainId = block.chainid;
        Sources.validate(dependencies());
        Sources.same(conservationFloor, "governanceAuthority()", executor, configs[0].genesisValue);
        if (
            executor == address(0)
                || Sources.word(
                        conservationFloor,
                        abi.encodeWithSignature("executorCodeHash()"),
                        configs[0].genesisValue
                    ) != executor.codehash
        ) revert P.InvalidProspectiveReference();
    }
    modifier guarded() {
        if (_entered) revert P.InvalidProspectiveReference();
        _entered = true;
        _;
        _entered = false;
    }

    function supportsInterface(bytes4 id) external pure override returns (bool) {
        return id == 0x01ffc9a7 || id == type(IStreamProspectiveReferencePublication).interfaceId
            || id == type(IStreamReferenceInventoryPreparation).interfaceId
            || id == type(IStreamReferenceEnvironmentPreparation).interfaceId
            || id == type(IStreamGasParameterHost).interfaceId;
    }

    function dependencies() public view override returns (P.Dependencies memory d) {
        d = _fixed;
        d.readGas = gasParameter(READ_GAS);
        d.sourceGas = gasParameter(SOURCE_GAS);
        d.archiveGas = gasParameter(ARCHIVE_GAS);
    }

    function currentSource(uint256 cid)
        public
        view
        override
        returns (P.Source memory s, bytes32 hash)
    {
        P.Dependencies memory d = dependencies();
        s = Sources.current(d, cid);
        hash = Sources.sourceHash(d, cid, s);
    }

    function simulationHTML(uint256 cid, P.Vector calldata v)
        external
        view
        override
        returns (bytes memory)
    {
        (P.Source memory s, bytes32 hash) = currentSource(cid);
        return Encoding.html(deploymentChainId, core, cid, hash, v, s.script);
    }

    function previewProspectiveReference(P.Publication calldata input, address recorder)
        external
        view
        override
        returns (bytes32 sourceHash, bytes memory canonical)
    {
        P.Publication memory p = input;
        _candidate(p);
        P.Dependencies memory d = dependencies();
        (P.Source memory s, P.Evidence memory e, bytes memory out) =
            Records.prepare(_inventories, d, p);
        _authority(s.provider.metadata, p.collectionId, recorder, d.readGas);
        return (e.sourceHash, out);
    }

    function publishProspectiveReference(P.Publication calldata input)
        external
        override
        guarded
        returns (bytes32 hash)
    {
        P.Publication memory p = input;
        _candidate(p);
        P.Dependencies memory d = dependencies();
        // Select authority from actual current Floor/Core Metadata before expensive archive proof.
        P.Source memory initial = Sources.current(d, p.collectionId);
        (uint8 cls, uint64 grant) =
            _authority(initial.provider.metadata, p.collectionId, msg.sender, d.readGas);
        (P.Source memory s, P.Evidence memory e, bytes memory canonical) =
            Records.prepare(_inventories, d, p);
        if (
            p.expectedSourceHash == 0 || p.expectedSourceHash != e.sourceHash
                || Sources.sourceHash(d, p.collectionId, initial) != e.sourceHash
        ) revert P.InvalidProspectiveReference();
        P.Receipt memory r;
        r.collectionId = p.collectionId;
        r.referenceId = p.referenceId;
        r.predecessor = p.expectedHead;
        r.revision = p.expectedRevision + 1;
        r.subject = s.release.scopeSubject;
        r.membershipHash = s.release.membershipHash;
        r.sourceHash = e.sourceHash;
        r.payloadHash = keccak256(canonical);
        r.payloadBytes = uint32(canonical.length);
        r.recorder = msg.sender;
        r.authorizationClass = cls;
        r.grantRevision = grant;
        r.effectiveAt = p.effectiveAt;
        r.recordedAt = uint64(block.timestamp);
        r.reasonHash = p.reasonHash;
        r.schemaHash = D.SCHEMA_HASH;
        r.profileHash = D.PROFILE_HASH;
        r.canonicalizationHash = D.CANON_HASH;
        hash = keccak256(
            abi.encode(
                keccak256("6529STREAM_PROSPECTIVE_REFERENCE_RECORD_V1"),
                deploymentChainId,
                address(this),
                core,
                conservationFloor,
                p,
                r
            )
        );
        if (_receipts[hash].recordHash != 0) revert P.InvalidProspectiveReference();
        r.recordHash = hash;
        r.chainHash = keccak256(
            abi.encode(
                keccak256("6529STREAM_PROSPECTIVE_REFERENCE_CHAIN_V1"),
                deploymentChainId,
                address(this),
                core,
                p.collectionId,
                p.expectedHead == 0 ? bytes32(0) : _receipts[p.expectedHead].chainHash,
                r.revision,
                hash
            )
        );
        Bytes.retain(_payloads[hash], d.targets[3], canonical);
        Bytes.retain(_publications[hash], d.targets[3], abi.encode(p));
        // Keep all binding writes atomic with the late current head/source/grant rechecks.
        _candidate(p);
        (P.Source memory late, bytes32 currentHash) = currentSource(p.collectionId);
        (uint8 lateClass, uint64 lateGrant) =
            _authority(late.provider.metadata, p.collectionId, msg.sender, d.readGas);
        if (currentHash != e.sourceHash || lateClass != cls || lateGrant != grant) {
            revert P.InvalidProspectiveReference();
        }
        _receipts[hash] = r;
        _history[p.collectionId].push(hash);
        _ids[p.collectionId][p.referenceId] = true;
        emit ProspectiveReferencePublished(1, hash, p.collectionId, p.referenceId, r, p.manifestURI);
    }

    function currentProspectiveReference(uint256 cid)
        public
        view
        override
        returns (P.Receipt memory)
    {
        return _receipts[_head(cid)];
    }

    function requireProspectiveCollectionReference(uint256 cid, bytes32 subject, bytes32 membership)
        external
        view
        override
        returns (bytes32)
    {
        P.Receipt memory r = currentProspectiveReference(cid);
        _known(r.recordHash);
        if (
            r.collectionId != cid || r.subject != subject || r.membershipHash != membership
                || r.revision != _history[cid].length
        ) revert P.InvalidProspectiveReference();
        Records.requireCurrent(
            _publications[r.recordHash], _payloads[r.recordHash], _inventories, dependencies(), r
        );
        return keccak256(
            abi.encode(
                keccak256("6529STREAM_PROSPECTIVE_COLLECTION_REFERENCE_EVIDENCE_V1"),
                deploymentChainId,
                address(this),
                core,
                conservationFloor,
                cid,
                subject,
                membership,
                r
            )
        );
    }

    function prospectiveRecord(bytes32 hash)
        external
        view
        override
        returns (P.Publication memory p, P.Receipt memory)
    {
        _known(hash);
        bytes memory raw = Bytes.read(_publications[hash]);
        p = abi.decode(raw, (P.Publication));
        Sources.canonical(raw, abi.encode(p));
        return (p, _receipts[hash]);
    }

    function prospectivePayload(bytes32 hash) external view override returns (bytes memory) {
        _known(hash);
        return Bytes.read(_payloads[hash]);
    }

    function prospectiveCount(uint256 cid) external view override returns (uint256) {
        return _history[cid].length;
    }

    function prospectiveAt(uint256 cid, uint256 index) external view override returns (bytes32) {
        return _history[cid][index];
    }

    function prepareFileInventory(R.PackageFile[] calldata rows, bool relative)
        external
        guarded
        returns (bytes32)
    {
        return Preparation.prepare(
            _inventories, _fixed.targets[3], _fixed.codeHashes[3], rows, relative
        );
    }

    function prepareFileInventoryPart(R.PackageFile[] calldata, bool)
        external
        override
        guarded
        returns (bytes32)
    {
        return Inventory.preparePart(
            _inventories, _fixed.targets[3], _fixed.codeHashes[3], msg.data
        );
    }

    function prepareFileInventoryFromParts(R.PackageFile[] calldata, bool)
        external
        override
        guarded
        returns (bytes32)
    {
        return Inventory.assemble(_inventories, _fixed.targets[3], _fixed.codeHashes[3], msg.data);
    }

    function prepareEnvironment(R.Environment calldata)
        external
        override
        guarded
        returns (bytes32)
    {
        return Preparation.prepareEnvironment(
            _inventories, _fixed.targets[3], _fixed.codeHashes[3], msg.data
        );
    }

    function preparedFileInventory(bytes32 id) external view returns (bytes memory) {
        return Bytes.read(_inventories[id]);
    }

    function _candidate(P.Publication memory p) private view {
        if (
            p.collectionId == 0 || p.referenceId == 0 || p.reasonHash == 0 || p.effectiveAt == 0
                || p.effectiveAt > block.timestamp || block.timestamp > type(uint64).max
                || p.expectedRevision == type(uint64).max || _ids[p.collectionId][p.referenceId]
        ) revert P.InvalidProspectiveReference();
        if (
            _head(p.collectionId) != p.expectedHead
                || _history[p.collectionId].length != p.expectedRevision
        ) revert P.ProspectiveLineage(p.expectedHead, _head(p.collectionId));
        StreamMetadataRenderer.requireValidUtf8ContentUri(
            "prospectiveManifestURI", p.manifestURI, 2048, true
        );
    }

    function _authority(address metadata, uint256 cid, address actor, uint256 cap)
        private
        view
        returns (uint8 cls, uint64 revision)
    {
        if (actor == address(0)) revert P.ProspectiveAuthority(actor);
        for (uint8 i; i < 2; ++i) {
            cls = i == 0 ? 3 : 8;
            bytes memory raw = Sources.read(
                metadata,
                abi.encodeCall(
                    IStreamCollectionMetadataV1.familyWriter,
                    (i == 0 ? cid : 0, StreamRecordFamilies.CURATOR, cls, actor)
                ),
                64,
                cap
            );
            bool enabled;
            (enabled, revision) = abi.decode(raw, (bool, uint64));
            Sources.canonical(raw, abi.encode(enabled, revision));
            if (enabled && revision != 0) return (cls, revision);
        }
        revert P.ProspectiveAuthority(actor);
    }

    function _head(uint256 cid) private view returns (bytes32) {
        uint256 n = _history[cid].length;
        return n == 0 ? bytes32(0) : _history[cid][n - 1];
    }

    function _known(bytes32 hash) private view {
        if (hash == 0 || _receipts[hash].recordHash != hash) {
            revert P.InvalidProspectiveReference();
        }
    }
}
