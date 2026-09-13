// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../../smart-contracts/domains/finality/StreamFinalityScopeMembership.sol";
import "../../smart-contracts/domains/finality/StreamCollectionTokenInventory.sol";
import "../../smart-contracts/domains/metadata/StreamCollectionMetadataV1.sol";
import "../../smart-contracts/domains/metadata/StreamSchemaRegistry.sol";
import "../regression/legacy/helpers/CharacterizationTestBase.sol";

/// @dev Explicit identity/Core selection boundary; actual Metadata/schema/store/inventory below.
contract ScopeMetadataCoreBoundary {
    struct Token {
        uint256 collectionId;
        uint256 serial;
        uint8 lifecycle;
    }
    mapping(uint256 => Token) internal tokens;
    mapping(uint256 => uint256) public collectionMintedEver;
    mapping(bytes32 => address) public selected;

    function supportsInterface(bytes4 id) external pure returns (bool) {
        return id == 0x01ffc9a7 || id == 0x80ac58cd;
    }

    function collectionExists(uint256 id) external pure returns (bool) {
        return id == 1 || id == 2;
    }

    function setToken(uint256 id, uint256 cid, uint256 serial, uint8 life) external {
        tokens[id] = Token(cid, serial, life);
        if (life == 2 && serial > collectionMintedEver[cid]) collectionMintedEver[cid] = serial;
    }

    function tokenCollectionIdentity(uint256 id)
        external
        view
        returns (bool, uint256, uint256, bool)
    {
        Token memory t = tokens[id];
        return (t.lifecycle != 0, t.collectionId, t.serial, t.lifecycle == 3);
    }

    function tokenLifecycle(uint256 id) external view returns (uint8) {
        return tokens[id].lifecycle;
    }

    function setPointer(bytes32 key, address target) external {
        selected[key] = target;
    }

    function getSatellitePointer(bytes32 kind)
        external
        view
        returns (address, bytes32, bool, bytes32, bytes4, address, uint8, bytes32, bytes32, uint64)
    {
        address t = selected[kind];
        return (
            t,
            t.codehash,
            false,
            kind,
            type(IStreamCollectionMetadataV1).interfaceId,
            address(this),
            1,
            bytes32(uint256(1)),
            bytes32(uint256(2)),
            1
        );
    }
}

contract ScopeMetadataArtistBoundary {
    address public immutable core;

    constructor(address c) {
        core = c;
    }
}

contract ScopeMetadataExecutorBoundary {
    bool private active;
    bytes32 private scope;
    bytes32 private oldHash;
    bytes32 private newHash;
    address public root;
    bytes32 private rootCodeHash;
    uint64 private rootRevision = 1;
    address private proposer;
    GovernanceActionStatus private storedStatus = GovernanceActionStatus.EXECUTED;
    string private reasonURI;

    constructor() {
        root = msg.sender;
        rootCodeHash = msg.sender.codehash;
        proposer = msg.sender;
    }

    function setRoot(address account) external {
        root = account;
        rootCodeHash = account.codehash;
        ++rootRevision;
    }

    function setProposer(address account) external {
        proposer = account;
    }

    function setReasonURI(string memory value) external {
        reasonURI = value;
    }

    function setStoredStatus(GovernanceActionStatus value) external {
        storedStatus = value;
    }

    function governanceRootState() external view returns (address, bytes32, uint64) {
        return (root, rootCodeHash, rootRevision);
    }

    function governanceAction(bytes32) external view returns (GovernanceAction memory a) {
        a.status = storedStatus;
        a.actionClass = 1;
        // Deliberately represent another first batch target, not the metadata call.
        a.target = address(0xbeef);
        a.selector = 0x11223344;
        a.proposer = proposer;
        a.reasonURI = reasonURI;
    }

    function isStreamGovernedParameterAuthority() external pure returns (bool) {
        return true;
    }

    function currentAction()
        external
        view
        returns (bool, bytes32, uint8, bytes32, bytes32, bytes32)
    {
        return active
            ? (true, bytes32(uint256(1)), uint8(1), scope, oldHash, newHash)
            : (false, bytes32(0), uint8(0), bytes32(0), bytes32(0), bytes32(0));
    }

    function execute(address target, bytes memory data, bytes32 s, bytes32 o, bytes32 n)
        external
        returns (bytes memory result)
    {
        active = true;
        scope = s;
        oldHash = o;
        newHash = n;
        (bool ok, bytes memory output) = target.call(data);
        if (!ok) assembly { revert(add(output, 32), mload(output)) }
        active = false;
        scope = 0;
        oldHash = 0;
        newHash = 0;
        return output;
    }
}

/// @dev Governance is an exact currentAction/root boundary; no actual scheduling authority claim.
abstract contract ScopeMembershipPublicationFixture is CharacterizationTestBase {
    ScopeMetadataCoreBoundary internal core;
    ScopeMetadataExecutorBoundary internal executor;
    ScopeMetadataArtistBoundary internal artist;
    StreamCollectionMetadataV1 internal metadata;
    StreamSchemaRegistry internal schemas;
    StreamSchemaDocumentStore internal store;
    StreamCollectionTokenInventory internal inventory;
    StreamFinalityScopeMembership internal membership;
    bytes32 internal constant SCOPE_RECORD = keccak256("SCOPE_MEMBERSHIP");
    bytes32 internal constant SCOPE_SCHEMA = keccak256("STREAM_SCOPE_MEMBERSHIP_V1");
    bytes32 internal constant SCOPE_CANON = keccak256("STREAM_SCOPE_MEMBERSHIP_ABI_V1");

    function setUp() public {
        vm.warp(1000);
        core = new ScopeMetadataCoreBoundary();
        executor = new ScopeMetadataExecutorBoundary();
        artist = new ScopeMetadataArtistBoundary(address(core));
        schemas = new StreamSchemaRegistry(address(executor));
        store = StreamSchemaDocumentStore(schemas.chunkStore());
        _register(
            "RAW_BYTES",
            IStreamSchemaRegistry.DocumentKind.CANONICALIZATION,
            bytes(schemas.RAW_BYTES_DEFINITION())
        );
        require(
            _register(
                "STREAM_SCOPE_MEMBERSHIP_V1",
                IStreamSchemaRegistry.DocumentKind.SCHEMA,
                bytes(vm.readFile("docs/schemas/finality/scope-membership-v1.schema.json"))
            ) == SCOPE_SCHEMA
        );
        require(
            _register(
                "STREAM_SCOPE_MEMBERSHIP_ABI_V1",
                IStreamSchemaRegistry.DocumentKind.CANONICALIZATION,
                bytes(vm.readFile("docs/schemas/finality/scope-membership-abi-v1.json"))
            ) == SCOPE_CANON
        );
        StreamCollectionMetadataV1.Configuration memory c;
        c.core = address(core);
        c.executor = address(executor);
        c.schemas = address(schemas);
        c.artistRegistry = address(artist);
        c.deploymentManifestHash = bytes32(uint256(1));
        c.manifestHash = bytes32(uint256(2));
        c.manifestURI = "ipfs://scope-metadata";
        c.dependencyReadGas = IStreamGasParameterHost.GasParameterConfig(
            "METADATA_DEPENDENCY_READ_GAS", 150000, 100000, 2
        );
        c.artistReadGas = IStreamGasParameterHost.GasParameterConfig(
            "METADATA_ARTIST_READ_GAS", 2000000, 1000000, 2
        );
        metadata = new StreamCollectionMetadataV1(c);
        core.setPointer(keccak256("COLLECTION_METADATA"), address(metadata));
        core.setPointer(keccak256("ARTIST_REGISTRY"), address(artist));
        _admit(SCOPE_RECORD, StreamRecordFamilies.IDENTITY, 384);
        _grant(1, StreamRecordFamilies.IDENTITY, 7, address(this), true);
        inventory = new StreamCollectionTokenInventory(
            address(core),
            address(executor),
            IStreamGasParameterHost.GasParameterConfig(
                "TOKEN_INVENTORY_CORE_READ_GAS", 100000, 50000, 1
            )
        );
        membership = new StreamFinalityScopeMembership(
            address(core),
            address(metadata),
            address(inventory),
            address(executor),
            IStreamGasParameterHost.GasParameterConfig(
                "SCOPE_MEMBERSHIP_READ_GAS", 500000, 50000, 1
            )
        );
    }

    function _tokens(uint256 count) internal returns (uint256[] memory ids) {
        ids = new uint256[](count);
        for (uint256 i; i < count; ++i) {
            ids[i] = (i + 1) * 3;
            core.setToken(ids[i], 1, i + 1, 2);
        }
    }

    function _index(uint256[] memory ids, uint256 start, uint256 end) internal {
        while (start < end) {
            uint256 next = start + 256;
            if (next > end) next = end;
            uint256[] memory batch = new uint256[](next - start);
            for (uint256 i = start; i < next; ++i) {
                batch[i - start] = ids[i];
            }
            inventory.appendCollectionTokens(1, batch);
            start = next;
        }
    }

    function _manifest(uint8 family, uint256[] memory ids)
        internal
        returns (StreamScopeMembershipManifest memory m)
    {
        bytes memory whole = new bytes(ids.length * 32);
        for (uint256 i; i < ids.length; ++i) {
            uint256 id = ids[i];
            assembly { mstore(add(add(whole, 32), mul(i, 32)), id) }
        }
        bytes32[] memory parts = new bytes32[]((whole.length + 8191) / 8192);
        for (uint256 i; i < parts.length; ++i) {
            uint256 length = whole.length - i * 8192;
            if (length > 8192) length = 8192;
            bytes memory part = new bytes(length);
            for (uint256 at; at < length; at += 32) {
                assembly {
                    mstore(
                        add(add(part, 32), at),
                        mload(add(add(whole, 32), add(mul(i, 8192), at)))
                    )
                }
            }
            (parts[i],) = store.publishChunk(part);
        }
        return StreamScopeMembershipManifest(
            1, block.chainid, address(core), 1, family, ids.length, keccak256(whole), parts
        );
    }

    function _record(StreamScopeMembershipManifest memory m, string memory uri)
        internal
        view
        returns (IStreamPreservationRecords.CollectionRecord memory r, bytes memory payload)
    {
        payload = StreamScopeMembershipEncoding.encode(m);
        r.recordType = SCOPE_RECORD;
        r.subjectId = StreamMetadataSubjects.scopeSubject(
            block.chainid,
            address(core),
            StreamFinalityScope(StreamFinalityScopeType.COLLECTION, 1, 0, 0)
        );
        r.schemaId = SCOPE_SCHEMA;
        r.contentHash =
            IStreamPreservationRecords.HashRef(1, abi.encode(keccak256(payload)), SCOPE_CANON);
        r.uri = uri;
        r.effectiveAt = 1000;
    }

    function _publish(StreamScopeMembershipManifest memory m, string memory uri)
        internal
        returns (bytes32 hash)
    {
        (IStreamPreservationRecords.CollectionRecord memory r, bytes memory payload) =
            _record(m, uri);
        return metadata.recordCollectionRecordWithPayload(1, r, payload);
    }

    function _seal(uint8 family, uint256[] memory ids, string memory uri)
        internal
        returns (StreamFinalityScope memory s)
    {
        s = membership.beginScopeMembership(_publish(_manifest(family, ids), uri));
        membership.continueScopeMembership(s, 64);
    }

    function _register(
        string memory name,
        IStreamSchemaRegistry.DocumentKind kind,
        bytes memory payload
    ) internal returns (bytes32) {
        (bytes32 hash,) = store.publishChunk(payload);
        bytes32[] memory chunks = new bytes32[](1);
        chunks[0] = hash;
        IStreamSchemaRegistry.DocumentSpec memory spec = IStreamSchemaRegistry.DocumentSpec(
            name, kind, hash, schemas.RAW_BYTES(), 0, "", uint32(payload.length)
        );
        (bytes32 s, bytes32 o, bytes32 n) = schemas.registrationTransition(spec, chunks);
        return abi.decode(
            executor.execute(
                address(schemas), abi.encodeCall(schemas.registerDocument, (spec, chunks)), s, o, n
            ),
            (bytes32)
        );
    }

    function _admit(bytes32 kind, bytes32 family, uint16 mask) internal {
        (bytes32 s, bytes32 o, bytes32 n) = metadata.recordTypeTransition(kind, family, mask);
        executor.execute(
            address(metadata),
            abi.encodeCall(metadata.admitRecordType, (kind, family, mask)),
            s,
            o,
            n
        );
    }

    function _grant(
        uint256 collectionId,
        bytes32 family,
        uint8 authClass,
        address account,
        bool enabled
    ) internal {
        (bytes32 s, bytes32 o, bytes32 n) = metadata.familyWriterTransition(
            collectionId, family, authClass, account, enabled
        );
        executor.execute(
            address(metadata),
            abi.encodeCall(
                metadata.setFamilyWriter, (collectionId, family, authClass, account, enabled)
            ),
            s,
            o,
            n
        );
    }
}
