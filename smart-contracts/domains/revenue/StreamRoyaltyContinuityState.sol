// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamRoyaltyContinuityTypes as C,
    IStreamRoyaltyEconomicContinuity as I
} from "../../interfaces/stream/revenue/IStreamRoyaltyEconomicContinuity.sol";
import {
    IStreamRoyaltyResolver as R
} from "../../interfaces/stream/revenue/IStreamRoyaltyResolver.sol";
import {
    IStreamRoyaltySnapshot as P
} from "../../interfaces/stream/revenue/IStreamRoyaltySnapshot.sol";

/// @notice Producer-owned complete immutable route/election inventory in Resolver storage.
/// @dev Original assignment/snapshot ledgers remain authoritative; this is their continuity witness.
library StreamRoyaltyContinuityState {
    bytes32 private constant SLOT = keccak256("6529STREAM_ROYALTY_CONTINUITY_STORAGE_V1");
    bytes32 internal constant CLASS = keccak256("ROYALTY_ERC2981");
    bytes32 internal constant MANIFEST_SCHEMA = keccak256("STREAM_ROYALTY_CONTINUITY_MANIFEST_V1");
    bytes32 internal constant CANONICALIZATION = keccak256("STREAM_ROYALTY_CONTINUITY_ABI_V1");

    struct State {
        uint256 mutations;
        bool entered;
        bytes32 protectedRoot;
        bytes32 electionRoot;
        C.Route[] routes;
        C.Election[] elections;
        mapping(bytes32 => uint256) routeIndex;
        mapping(uint256 => uint256) electionIndex;
        C.ImportState transfer;
        // Derived only from the actually selected source during the original governed begin.
        // Appended fields leave every original ledger and import ABI/preimage unchanged.
        address consumerOrigin;
        bytes32 consumerOriginRuntimeHash;
    }
    event ProtectedEconomicRouteRecorded(
        uint16 schemaVersion,
        uint256 indexed index,
        bytes32 indexed routeKey,
        bytes32 indexed routeHash,
        bytes canonicalRoute
    );
    event EconomicElectionRecorded(
        uint16 schemaVersion,
        uint256 indexed index,
        uint256 indexed collectionId,
        bytes32 electionHash,
        address hashOrigin,
        uint8 mode
    );

    function state() internal pure returns (State storage s) {
        bytes32 slot = SLOT;
        assembly ("memory-safe") { s.slot := slot }
    }

    function writable() internal view {
        if (state().transfer.status == 1 || state().entered) {
            revert C.EconomicContinuityInProgress();
        }
    }

    function noteMutation() internal {
        ++state().mutations;
    }

    function key(uint8 scope, uint256 id) internal pure returns (bytes32) {
        return keccak256(abi.encode(CLASS, scope, id));
    }

    function origin(uint8 scope, uint256 id, bool frozen) internal view returns (address) {
        uint256 n = state().routeIndex[key(scope, id)];
        return frozen && n != 0 ? state().routes[n - 1].hashOrigin : address(this);
    }

    function electionOrigin(uint256 id) internal view returns (address) {
        uint256 n = state().electionIndex[id];
        return n == 0 ? address(this) : state().elections[n - 1].hashOrigin;
    }

    function routeHash(address core, C.Route memory r) public view returns (bytes32) {
        return keccak256(
            abi.encode(
                keccak256("6529STREAM_PROTECTED_ROYALTY_ROUTE_V1"),
                block.chainid,
                core,
                CLASS,
                r.scope,
                r.scopeId,
                r.collectionId,
                r.hashOrigin,
                r.config,
                r.assignmentHash,
                r.policyHash,
                uint8(1),
                r.snapshot
            )
        );
    }

    function header(address core, address factory, uint16 maximum)
        public
        view
        returns (C.Header memory h)
    {
        State storage s = state();
        h = C.Header(
            1,
            core,
            factory,
            maximum,
            s.routes.length,
            s.protectedRoot,
            s.elections.length,
            s.electionRoot,
            0
        );
        if (h.protectedCount != 0 || h.electionCount != 0) {
            h.frozenStateHash = keccak256(
                abi.encode(
                    keccak256("6529STREAM_FROZEN_ROYALTY_STATE_V1"),
                    block.chainid,
                    core,
                    factory,
                    maximum,
                    h.protectedCount,
                    h.protectedRoot,
                    h.electionCount,
                    h.electionRoot
                )
            );
        }
    }

    function recordRoute(address core, C.Route memory r) public {
        State storage s = state();
        bytes32 k = key(r.scope, r.scopeId);
        if (
            !r.config.configured || !r.config.frozen || r.hashOrigin == address(0)
                || r.assignmentHash == 0 || r.policyHash == 0 || s.routeIndex[k] != 0 || r.scope > 2
                || (r.scope == 0 && (r.scopeId != 0 || r.collectionId != 0))
                || (r.scope != 0 && (r.scopeId == 0 || r.collectionId == 0))
                || (r.scope == 1 && r.scopeId != r.collectionId)
        ) revert C.InvalidEconomicContinuity();
        if (
            r.snapshot.exists
                && (r.scope != 2
                    || r.snapshot.tokenId != r.scopeId
                    || r.snapshot.collectionId != r.collectionId
                    || r.snapshot.tokenAssignmentHash != r.assignmentHash
                    || r.snapshot.tokenRoyaltyPolicyHash != r.policyHash
                    || r.snapshot.tokenConfigHash != keccak256(abi.encode(r.config)))
        ) {
            revert C.InvalidEconomicContinuity();
        }
        uint256 index = s.routes.length;
        bytes32 hash = routeHash(core, r);
        s.routeIndex[k] = index + 1;
        s.routes.push(r);
        s.protectedRoot = keccak256(abi.encode(s.protectedRoot, index, k, hash));
        emit ProtectedEconomicRouteRecorded(1, index, k, hash, abi.encode(r));
    }

    function recordElection(C.Election memory e) public {
        State storage s = state();
        if (
            e.collectionId == 0 || (e.mode != 1 && e.mode != 2) || e.electionHash == 0
                || e.hashOrigin == address(0) || s.electionIndex[e.collectionId] != 0
        ) revert C.InvalidEconomicContinuity();
        uint256 index = s.elections.length;
        s.electionIndex[e.collectionId] = index + 1;
        s.elections.push(e);
        s.electionRoot = keccak256(abi.encode(s.electionRoot, index, e));
        emit EconomicElectionRecorded(
            1, index, e.collectionId, e.electionHash, e.hashOrigin, e.mode
        );
    }

    function routeAt(uint256 index) public view returns (C.Route memory) {
        if (index >= state().routes.length) revert C.EconomicContinuityIndex();
        return state().routes[index];
    }

    function electionAt(uint256 index) public view returns (C.Election memory) {
        if (index >= state().elections.length) revert C.EconomicContinuityIndex();
        return state().elections[index];
    }

    function protectedHash(address core, uint8 scope, uint256 id) public view returns (bytes32) {
        uint256 n = state().routeIndex[key(scope, id)];
        return n == 0 ? bytes32(0) : routeHash(core, state().routes[n - 1]);
    }
}
