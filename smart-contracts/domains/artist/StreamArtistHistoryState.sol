// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "./StreamArtistHistoryProof.sol";
import {
    StreamArtistHistoryTypes as H
} from "../../interfaces/stream/artist/IStreamArtistHistory.sol";

/// @notice Separate Identity-owned continuity namespace. Original owner roots and records are untouched.
library StreamArtistHistoryState {
    bytes32 private constant SLOT = keccak256("6529STREAM_ARTIST_CANONICAL_HISTORY_STORAGE_V1");
    bytes32 private constant CHAIN =
        0x2eac9cfc5ca84fbeed56ef1741255e2ec7e45f48bc5c5ceda94397aa23d2f23e;

    struct Row {
        bytes32 record;
        bytes32 chain;
    }

    struct Verified {
        bool done;
        bytes32 tip;
        uint64 count;
        uint256 bindingIndex;
    }

    struct State {
        mapping(bytes32 => Row[]) lanes;
        mapping(address => uint256) observed;
        H.Binding[] bindings;
        mapping(bytes32 => uint256) rootIndexPlusOne;
        mapping(address => bytes32) predecessorCode;
        mapping(address => uint256) predecessorCount;
        mapping(bytes32 => Verified) verified;
        bool served;
        bool cutover;
        address successor;
        uint64 cutoverBlock;
        bytes32 commitment;
        mapping(bytes32 => bytes32) hydrated;
    }
    error InvalidArtistHistory();
    error ArtistHistoryImportedAuthorityUnavailable(uint8 kind, bytes32 key);
    error ArtistRegistryNoLongerCurrent();
    event ArtistRecordChainAdvanced(
        uint16 schemaVersion,
        uint8 indexed laneKind,
        bytes32 indexed laneKey,
        uint64 sequence,
        bytes32 recordHash,
        bytes32 previousChainHash,
        bytes32 recordChainHash
    );
    event ArtistHistoryImportRootCommitted(
        uint16 schemaVersion,
        address indexed predecessorRegistry,
        bytes32 indexed importRoot,
        uint64 snapshotBlock,
        bytes32 manifestHash,
        bytes32 governanceActionId
    );
    event ArtistHistoryLaneVerified(
        uint16 schemaVersion,
        uint8 indexed laneKind,
        bytes32 indexed laneKey,
        uint256 bindingIndex,
        bytes32 laneTip,
        uint64 recordCount
    );
    event ArtistRegistryCutoverObserved(
        uint16 schemaVersion, address indexed successorTarget, uint64 observedAt
    );

    function state() internal pure returns (State storage s) {
        bytes32 slot = SLOT;
        assembly ("memory-safe") { s.slot := slot }
    }

    function key(uint8 kind, bytes32 id) internal pure returns (bytes32) {
        StreamArtistHistoryProof.validLane(kind, id);
        return keccak256(abi.encode(kind, id));
    }

    function commitment() public view returns (bytes32) {
        return state().commitment;
    }

    function cursor(address source) public view returns (uint256) {
        return state().observed[source];
    }

    function lane(uint8 kind, bytes32 id) public view returns (bytes32 tip, uint64 count) {
        bytes32 k = key(kind, id);
        Row[] storage rows = state().lanes[k];
        Verified storage v = state().verified[k];
        count = uint64(rows.length) + (v.done ? v.count : 0);
        tip = rows.length != 0 ? rows[rows.length - 1].chain : v.tip;
    }

    function at(
        address core,
        address registry,
        uint8 kind,
        bytes32 id,
        uint64 index,
        uint256 gasCap
    ) public view returns (bytes32, bytes32) {
        State storage s = state();
        bytes32 laneKey = key(kind, id);
        Verified storage v = s.verified[laneKey];
        uint64 prefix = v.done ? v.count : 0;
        if (index >= prefix) {
            if (index - prefix >= s.lanes[laneKey].length) revert InvalidArtistHistory();
            Row storage row = s.lanes[laneKey][index - prefix];
            return (row.record, row.chain);
        }
        if (!v.done || index >= v.count) revert InvalidArtistHistory();
        address prior = s.bindings[v.bindingIndex].predecessorRegistry;
        StreamArtistHistoryProof.predecessor(
            core, registry, prior, s.predecessorCode[prior], gasCap
        );
        // The permanent latch is never re-evaluated. This is a historical index read only.
        return abi.decode(
            StreamArtistHistoryProof.fixedRead(
                prior,
                abi.encodeCall(IStreamArtistHistory.artistHistoryRecordAt, (kind, id, index)),
                64,
                gasCap
            ),
            (bytes32, bytes32)
        );
    }

    function sync(
        address core,
        address registry,
        address source,
        uint256 first,
        H.Receipt[] memory rows,
        uint256 gasCap
    ) public {
        State storage s = state();
        if (
            source == address(0) || s.observed[source] != first || rows.length > 128
                || (s.cutover && rows.length != 0)
        ) revert InvalidArtistHistory();
        if (rows.length != 0) {
            (address current,) = StreamArtistHistoryProof.pointer(core, gasCap);
            if (current != registry) revert ArtistRegistryNoLongerCurrent();
            s.served = true;
        }
        for (uint256 i; i < rows.length; ++i) {
            H.Receipt memory r = rows[i];
            if (
                r.recordHash == 0 || r.operation == 0 || (r.operation > 59 && r.operation != 61)
                    || (r.artistId == 0 && r.collectionId == 0)
            ) revert InvalidArtistHistory();
            if (r.artistId != 0) _append(core, registry, 1, r.artistId, r.recordHash, gasCap);
            if (r.collectionId != 0) {
                _append(core, registry, 2, bytes32(r.collectionId), r.recordHash, gasCap);
            }
        }
        s.observed[source] = first + rows.length;
        if (rows.length != 0) {
            s.commitment = keccak256(abi.encode(s.commitment, source, first, rows));
        }
    }

    function _append(
        address core,
        address registry,
        uint8 kind,
        bytes32 id,
        bytes32 record,
        uint256 gasCap
    ) private {
        State storage s = state();
        bytes32 laneKey = key(kind, id);
        // No native writer may silently replace an unhydrated predecessor lane.
        Verified storage v = s.verified[laneKey];
        if (v.done && s.hydrated[laneKey] == 0) {
            revert ArtistHistoryImportedAuthorityUnavailable(kind, id);
        }
        if (!v.done && s.bindings.length != 0) {
            address prior = s.bindings[0].predecessorRegistry;
            StreamArtistHistoryProof.predecessor(
                core, registry, prior, s.predecessorCode[prior], gasCap
            );
            (, uint64 count) = StreamArtistHistoryProof.lane(prior, kind, id, gasCap);
            if (count != 0) revert ArtistHistoryImportedAuthorityUnavailable(kind, id);
        }
        Row[] storage rows = s.lanes[laneKey];
        uint64 prefix = v.done ? v.count : 0;
        if (rows.length >= type(uint64).max - prefix) revert InvalidArtistHistory();
        bytes32 previous = rows.length == 0 ? v.tip : rows[rows.length - 1].chain;
        bytes32 next = keccak256(abi.encode(CHAIN, previous, record));
        rows.push(Row(record, next));
        emit ArtistRecordChainAdvanced(
            1, kind, id, prefix + uint64(rows.length - 1), record, previous, next
        );
    }

    function activate(bytes32 artistId, uint256 collectionId, bytes32 value) public {
        State storage s = state();
        bytes32 a = key(1, artistId);
        bytes32 c = key(2, bytes32(collectionId));
        if (
            value == 0 || !s.verified[a].done || !s.verified[c].done || s.hydrated[a] != 0
                || s.hydrated[c] != 0 || s.cutover || s.lanes[a].length != 0
                || s.lanes[c].length != 0
        ) revert InvalidArtistHistory();
        s.hydrated[a] = value;
        s.hydrated[c] = value;
        s.commitment = keccak256(
            abi.encode(s.commitment, uint16(60), artistId, collectionId, value)
        );
    }

    /// @notice Completes each exact latched lane once, including shared-Artist collection sets.
    function activateMultiple(bytes32[] memory artists, uint256[] memory collections, bytes32 value)
        public
    {
        if (value == 0 || artists.length == 0 || collections.length == 0) {
            revert InvalidArtistHistory();
        }
        State storage s = state();
        if (s.cutover) revert InvalidArtistHistory();
        for (uint256 i; i < artists.length; ++i) {
            if (artists[i] == 0 || (i != 0 && artists[i] <= artists[i - 1])) {
                revert InvalidArtistHistory();
            }
            _activateMultipleLane(s, 1, artists[i], value);
        }
        for (uint256 i; i < collections.length; ++i) {
            if (collections[i] == 0 || (i != 0 && collections[i] <= collections[i - 1])) {
                revert InvalidArtistHistory();
            }
            _activateMultipleLane(s, 2, bytes32(collections[i]), value);
        }
        s.commitment = keccak256(
            abi.encode(
                s.commitment,
                uint16(60),
                keccak256("6529STREAM_ARTIST_MULTIPLE_LIVING_HYDRATION_V1"),
                artists,
                collections,
                value
            )
        );
    }

    function _activateMultipleLane(State storage s, uint8 kind, bytes32 id, bytes32 value) private {
        bytes32 lane = key(kind, id);
        if (!s.verified[lane].done || s.hydrated[lane] != 0 || s.lanes[lane].length != 0) {
            revert InvalidArtistHistory();
        }
        s.hydrated[lane] = value;
    }

    function bindingCount() public view returns (uint256) {
        return state().bindings.length;
    }

    function binding(uint256 index) public view returns (H.Binding memory) {
        return state().bindings[index];
    }

    function predecessorBinding(address source) public view returns (bool, bytes32, uint256) {
        State storage s = state();
        return
            (s.predecessorCount[source] != 0, s.predecessorCode[source], s.predecessorCount[source]);
    }

    function context(address registry, H.Binding memory p)
        public
        view
        returns (H.Context memory x)
    {
        State storage s = state();
        x.scopeHash = keccak256(
            abi.encode(
                keccak256("6529STREAM_ARTIST_HISTORY_IMPORT_SCOPE_V1"),
                block.chainid,
                registry,
                address(this)
            )
        );
        x.oldValueHash = keccak256(abi.encode(x.scopeHash, s.bindings.length, s.commitment));
        x.newValueHash = keccak256(
            abi.encode(x.oldValueHash, p, p.predecessorRegistry.codehash, s.bindings.length)
        );
    }

    function commit(
        address core,
        address registry,
        H.Binding memory p,
        bytes32 actionId,
        uint256 gasCap
    ) public {
        State storage s = state();
        if (
            s.cutover || p.snapshotBlock == 0 || p.snapshotBlock > block.number || p.importRoot == 0
                || p.manifestHash == 0 || s.rootIndexPlusOne[p.importRoot] != 0
        ) revert InvalidArtistHistory();
        if (s.bindings.length != 0 && s.bindings[0].predecessorRegistry != p.predecessorRegistry) {
            revert InvalidArtistHistory();
        }
        bytes32 code = p.predecessorRegistry.codehash;
        StreamArtistHistoryProof.predecessor(core, registry, p.predecessorRegistry, code, gasCap);
        (address current,) = StreamArtistHistoryProof.pointer(core, gasCap);
        if (current != registry && current != p.predecessorRegistry) revert InvalidArtistHistory();
        if (
            s.predecessorCode[p.predecessorRegistry] != 0
                && s.predecessorCode[p.predecessorRegistry] != code
        ) revert InvalidArtistHistory();
        if (current == registry) s.served = true;
        uint256 index = s.bindings.length;
        s.bindings.push(p);
        s.rootIndexPlusOne[p.importRoot] = index + 1;
        s.predecessorCode[p.predecessorRegistry] = code;
        ++s.predecessorCount[p.predecessorRegistry];
        s.commitment = keccak256(abi.encode(s.commitment, uint16(55), p, code, index));
        emit ArtistHistoryImportRootCommitted(
            1, p.predecessorRegistry, p.importRoot, p.snapshotBlock, p.manifestHash, actionId
        );
    }

    function verifyRecord(bytes32 root, H.Leaf memory p, bytes32[] memory proof)
        public
        view
        returns (bool)
    {
        uint256 plus = state().rootIndexPlusOne[root];
        if (plus == 0) return false;
        return StreamArtistHistoryProof.verify(
            root, state().bindings[plus - 1].predecessorRegistry, p, proof
        );
    }

    function verifyTip(
        address core,
        address registry,
        uint256 index,
        H.Leaf memory p,
        bytes32[] memory proof,
        uint256 gasCap
    ) public {
        State storage s = state();
        H.Binding memory b = s.bindings[index];
        bytes32 laneKey = key(p.laneKind, p.laneKey);
        if (
            s.cutover || s.verified[laneKey].done || s.lanes[laneKey].length != 0
                || p.sequence == type(uint64).max
        ) revert InvalidArtistHistory();
        (address current,) = StreamArtistHistoryProof.pointer(core, gasCap);
        if (current != registry || current == b.predecessorRegistry) {
            revert ArtistRegistryNoLongerCurrent();
        }
        StreamArtistHistoryProof.predecessor(
            core, registry, b.predecessorRegistry, s.predecessorCode[b.predecessorRegistry], gasCap
        );
        if (!StreamArtistHistoryProof.verify(b.importRoot, b.predecessorRegistry, p, proof)) {
            revert InvalidArtistHistory();
        }
        (bytes32 tip, uint64 count) =
            StreamArtistHistoryProof.lane(b.predecessorRegistry, p.laneKind, p.laneKey, gasCap);
        if (tip != p.recordChainHash || count != p.sequence + 1) revert InvalidArtistHistory();
        (bytes32 record, bytes32 chain) = abi.decode(
            StreamArtistHistoryProof.fixedRead(
                b.predecessorRegistry,
                abi.encodeCall(
                    IStreamArtistHistory.artistHistoryRecordAt, (p.laneKind, p.laneKey, p.sequence)
                ),
                64,
                gasCap
            ),
            (bytes32, bytes32)
        );
        if (record != p.recordHash || chain != tip) revert InvalidArtistHistory();
        s.served = true;
        s.verified[laneKey] = Verified(true, tip, count, index);
        s.commitment = keccak256(abi.encode(s.commitment, uint16(56), index, p));
        emit ArtistHistoryLaneVerified(1, p.laneKind, p.laneKey, index, tip, count);
    }

    function verified(uint8 kind, bytes32 id) public view returns (bool, bytes32, uint64) {
        Verified storage v = state().verified[key(kind, id)];
        return (v.done, v.tip, v.count);
    }

    function cutover() public view returns (bool, address, uint64) {
        State storage s = state();
        return (s.cutover, s.successor, s.cutoverBlock);
    }

    function requireNativeCurrent(address core, address registry, uint256 gasCap) public view {
        if (state().cutover) revert ArtistRegistryNoLongerCurrent();
        (address current,) = StreamArtistHistoryProof.pointer(core, gasCap);
        if (current != registry) revert ArtistRegistryNoLongerCurrent();
    }

    function observe(address core, address registry, uint256 gasCap) public {
        State storage s = state();
        if (
            !s.served || s.cutover || block.number > type(uint64).max
                || block.timestamp > type(uint64).max
        ) {
            revert InvalidArtistHistory();
        }
        (address current,) = StreamArtistHistoryProof.pointer(core, gasCap);
        if (current == registry) revert InvalidArtistHistory();
        s.cutover = true;
        s.successor = current;
        s.cutoverBlock = uint64(block.number);
        s.commitment = keccak256(abi.encode(s.commitment, uint16(57), current, block.number));
        emit ArtistRegistryCutoverObserved(1, current, uint64(block.timestamp));
    }
}
