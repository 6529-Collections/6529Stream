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
import { IStreamCorePointers as Core } from "../../interfaces/stream/core/IStreamCorePointers.sol";
import {
    IStreamCoreIdentity as Identity
} from "../../interfaces/stream/core/IStreamCoreIdentity.sol";
import {
    IStreamCoreCollectionView as Collections
} from "../../interfaces/stream/core/IStreamCoreCollectionView.sol";
import {
    IStreamGovernedParameterAuthority as G
} from "../../interfaces/stream/parameters/IStreamGovernedParameterAuthority.sol";
import { IStreamSplitFactory as F } from "../../interfaces/stream/revenue/IStreamSplitFactory.sol";
import {
    StreamRoyaltyContinuityParameters as Parameters
} from "./StreamRoyaltyContinuityParameters.sol";
import { StreamRoyaltyContinuityState as S } from "./StreamRoyaltyContinuityState.sol";
import { StreamRoyaltySnapshot as Snap } from "./StreamRoyaltySnapshot.sol";
import { StreamRoyaltyAssignmentHash as Hash } from "./StreamRoyaltyAssignmentHash.sol";

/// @notice Fixed typed copy of every producer-enumerated protected route and immutable election.
/// @dev No supplied balances/route list. An exact class1 begin commits the full source header;
///      each permissionless chunk rechecks its unchanged source and copies the next rows only.
library StreamRoyaltyContinuityImport {
    bytes32 private constant DOMAIN = keccak256("6529STREAM_ROYALTY_CONTINUITY_MANIFEST_V1");
    bytes32 private constant ACTION = keccak256("6529STREAM_ROYALTY_CONTINUITY_BEGIN_V1");
    bytes32 private constant ROYALTY = keccak256("ROYALTY_RESOLVER");
    bytes4 private constant ERC165 = 0x01ffc9a7;

    struct Context {
        address core;
        bytes32 coreHash;
        address factory;
        address authority;
        uint16 maximum;
    }
    event EconomicContinuityBegun(
        uint16 schemaVersion,
        address indexed source,
        bytes32 indexed manifestHash,
        bytes32 indexed actionId,
        bytes canonicalManifest
    );
    event EconomicContinuityProgress(
        uint16 schemaVersion,
        bytes32 indexed manifestHash,
        uint256 importedRoutes,
        uint256 importedElections
    );
    event EconomicContinuityCompleted(
        uint16 schemaVersion,
        address indexed source,
        bytes32 indexed manifestHash,
        bytes32 frozenStateHash
    );

    function preview(Context memory c, address source, C.ManifestRef memory ref)
        public
        view
        returns (bytes32 manifest, bytes32 scope, bytes32 oldHash, bytes32 newHash)
    {
        S.State storage s = S.state();
        if (
            s.transfer.status != 0 || s.mutations != 0 || s.entered || s.routes.length != 0
                || s.elections.length != 0
        ) {
            revert C.InvalidEconomicContinuity();
        }
        C.Header memory h = _admitSource(c, source);
        if (
            ref.expectedSourceHeaderHash != keccak256(abi.encode(h)) || bytes(ref.uri).length == 0
                || bytes(ref.uri).length > 2048 || ref.uriHash != keccak256(bytes(ref.uri))
                || ref.schemaId != S.MANIFEST_SCHEMA || ref.canonicalizationId != S.CANONICALIZATION
        ) {
            revert C.InvalidEconomicContinuity();
        }
        manifest = keccak256(
            abi.encode(
                DOMAIN,
                block.chainid,
                source,
                source.codehash,
                address(this),
                c.core,
                c.factory,
                h,
                ref.uri,
                ref.uriHash,
                ref.schemaId,
                ref.canonicalizationId
            )
        );
        if (ref.contentHash != manifest) revert C.InvalidEconomicContinuity();
        scope = keccak256(abi.encode(ACTION, block.chainid, address(this), c.core, source));
        oldHash = keccak256(abi.encode(scope, uint8(0), uint256(0)));
        newHash = keccak256(
            abi.encode(scope, manifest, source.codehash, h, c.authority, c.authority.codehash)
        );
    }

    function begin(Context memory c, address source, C.ManifestRef memory ref) public {
        if (msg.sender != c.authority) revert C.InvalidEconomicContinuity();
        (bytes32 manifest, bytes32 scope, bytes32 oldHash, bytes32 newHash) =
            preview(c, source, ref);
        bytes memory raw = _read(c, c.authority, abi.encodeCall(G.currentAction, ()), 192);
        (bool executing, bytes32 id, uint8 cls, bytes32 aScope, bytes32 aOld, bytes32 aNew) =
            abi.decode(raw, (bool, bytes32, uint8, bytes32, bytes32, bytes32));
        if (
            !executing || id == 0 || cls != 1 || scope != aScope || oldHash != aOld
                || newHash != aNew
        ) {
            revert C.InvalidEconomicContinuity();
        }
        C.Header memory h = _admitSource(c, source);
        if (keccak256(abi.encode(h)) != ref.expectedSourceHeaderHash) {
            revert C.EconomicContinuitySourceChanged();
        }
        C.ImportState storage t = S.state().transfer;
        t.status = 1;
        t.source = source;
        t.sourceRuntimeHash = source.codehash;
        t.manifestHash = manifest;
        t.beginActionId = id;
        t.expected = h;
        t.manifestReference = ref;
        emit EconomicContinuityBegun(
            1,
            source,
            manifest,
            id,
            abi.encode(
                DOMAIN,
                block.chainid,
                source,
                source.codehash,
                address(this),
                c.core,
                c.factory,
                h,
                ref.uri,
                ref.uriHash,
                ref.schemaId,
                ref.canonicalizationId
            )
        );
    }

    function importNext(
        R.RoyaltyConfig storage defaults,
        mapping(uint256 => R.RoyaltyConfig) storage collections,
        mapping(
            uint256 => R.RoyaltyConfig
        ) storage tokens,
        Snap.State storage snapshots,
        Context memory c,
        uint256 maxRoutes,
        uint256 maxElections
    ) public {
        S.State storage s = S.state();
        C.ImportState storage t = s.transfer;
        if (
            t.status != 1 || s.entered || maxRoutes > 16 || maxElections > 64
                || (maxRoutes == 0 && maxElections == 0)
        ) {
            revert C.InvalidEconomicContinuity();
        }
        s.entered = true;
        _unchanged(c);
        uint256 end = t.importedElections + maxElections;
        if (end > t.expected.electionCount) end = t.expected.electionCount;
        while (t.importedElections < end) {
            C.Election memory e = abi.decode(
                _read(
                    c, t.source, abi.encodeCall(I.economicElectionAt, (t.importedElections)), 128
                ),
                (C.Election)
            );
            if (
                e.electionHash
                    != keccak256(
                        abi.encode(
                            keccak256("6529STREAM_ROYALTY_MODE_ELECTION_V1"),
                            block.chainid,
                            e.hashOrigin,
                            c.core,
                            e.collectionId,
                            e.mode
                        )
                    )
            ) revert C.InvalidEconomicContinuity();
            if (
                !abi.decode(
                        _read(
                            c,
                            c.core,
                            abi.encodeCall(Collections.collectionExists, (e.collectionId)),
                            32
                        ),
                        (bool)
                    ) || snapshots.elections[e.collectionId].hash != 0
            ) revert C.InvalidEconomicContinuity();
            snapshots.elections[e.collectionId] = Snap.Election(e.mode, e.electionHash);
            S.recordElection(e);
            ++t.importedElections;
        }
        if (t.importedElections == t.expected.electionCount) {
            end = t.importedRoutes + maxRoutes;
            if (end > t.expected.protectedCount) end = t.expected.protectedCount;
            C.Route memory empty;
            while (t.importedRoutes < end) {
                C.Route memory r = abi.decode(
                    _read(
                        c,
                        t.source,
                        abi.encodeCall(I.protectedEconomicRouteAt, (t.importedRoutes)),
                        abi.encode(empty).length
                    ),
                    (C.Route)
                );
                _route(c, r, snapshots);
                R.RoyaltyConfig memory current =
                    r.scope == 0
                    ? defaults
                    : r.scope == 1 ? collections[r.scopeId] : tokens[r.scopeId];
                R.RoyaltyConfig memory zero;
                if (keccak256(abi.encode(current)) != keccak256(abi.encode(zero))) {
                    revert C.InvalidEconomicContinuity();
                }
                if (r.scope == 0) {
                    defaults.wallet = r.config.wallet;
                    defaults.royaltyBps = r.config.royaltyBps;
                    defaults.configured = r.config.configured;
                    defaults.frozen = r.config.frozen;
                    defaults.revision = r.config.revision;
                    defaults.profileId = r.config.profileId;
                } else if (r.scope == 1) {
                    collections[r.scopeId] = r.config;
                } else {
                    tokens[r.scopeId] = r.config;
                    if (r.snapshot.exists) snapshots.snapshots[r.scopeId] = r.snapshot;
                }
                S.recordRoute(c.core, r);
                ++t.importedRoutes;
            }
        }
        _unchanged(c);
        s.entered = false;
        emit EconomicContinuityProgress(1, t.manifestHash, t.importedRoutes, t.importedElections);
    }

    function complete(Context memory c) public {
        S.State storage s = S.state();
        C.ImportState storage t = s.transfer;
        if (
            t.status != 1 || s.entered || t.importedRoutes != t.expected.protectedCount
                || t.importedElections != t.expected.electionCount
        ) revert C.InvalidEconomicContinuity();
        _unchanged(c);
        C.Header memory h = S.header(c.core, c.factory, c.maximum);
        if (keccak256(abi.encode(h)) != keccak256(abi.encode(t.expected))) {
            revert C.InvalidEconomicContinuity();
        }
        t.status = 2;
        emit EconomicContinuityCompleted(1, t.source, t.manifestHash, h.frozenStateHash);
    }

    function supportsContinuity(
        Context memory c,
        address oldResolver,
        bytes32 oldHash,
        bytes32 manifest
    ) public view returns (bool) {
        C.ImportState storage t = S.state().transfer;
        if (
            t.status != 2 || oldResolver != t.source || oldResolver.codehash != t.sourceRuntimeHash
                || manifest == 0 || manifest != t.manifestHash
                || oldHash != t.expected.frozenStateHash
        ) return false;
        C.Header memory old = _header(c, oldResolver);
        C.Header memory ours = S.header(c.core, c.factory, c.maximum);
        return keccak256(abi.encode(old)) == keccak256(abi.encode(t.expected))
            && keccak256(abi.encode(ours)) == keccak256(abi.encode(old));
    }

    function _route(Context memory c, C.Route memory r, Snap.State storage snapshots) private view {
        if (
            r.config.royaltyBps > c.maximum
                || (r.config.royaltyBps == 0) != (r.config.profileId == 0)
                || (r.config.royaltyBps == 0) != (r.config.wallet == address(0))
        ) revert C.InvalidEconomicContinuity();
        if (
            r.config.royaltyBps != 0
                && (!F(c.factory).splitWalletExists(r.config.profileId)
                    || F(c.factory).walletFor(r.config.profileId) != r.config.wallet)
        ) revert C.InvalidEconomicContinuity();
        if (r.scope == 2) {
            (bool exists, uint256 collection,,) = abi.decode(
                _read(
                    c, c.core, abi.encodeCall(Identity.tokenCollectionIdentity, (r.scopeId)), 128
                ),
                (bool, uint256, uint256, bool)
            );
            if (!exists || collection != r.collectionId) revert C.InvalidEconomicContinuity();
        } else if (
            r.scope == 1
                && !abi.decode(
                    _read(
                        c,
                        c.core,
                        abi.encodeCall(Collections.collectionExists, (r.collectionId)),
                        32
                    ),
                    (bool)
                )
        ) {
            revert C.InvalidEconomicContinuity();
        }
        if (
            r.assignmentHash
                    != Hash.assignmentForOrigin(
                        F(c.factory), r.config, r.scope, r.scopeId, r.hashOrigin
                    )
                || r.policyHash
                    != Hash.policyForOrigin(
                        r.collectionId, r.scope, r.scopeId, r.config, r.assignmentHash, r.hashOrigin
                    )
        ) {
            revert C.InvalidEconomicContinuity();
        }
        if (r.snapshot.exists) {
            if (
                snapshots.elections[r.collectionId].mode != 2
                    || snapshots.elections[r.collectionId].hash != r.snapshot.electionHash
                    || r.snapshot.manager == address(0) || r.snapshot.operationRoot == 0
                    || r.snapshot.operationId == 0 || r.snapshot.preparedProofHash == 0
                    || r.snapshot.sourceAssignmentHash == 0 || r.snapshot.modeAssignmentHash == 0
                    || r.snapshot.sourceRoyaltyPolicyHash == 0
            ) {
                revert C.InvalidEconomicContinuity();
            }
        } else {
            P.Snapshot memory empty;
            if (keccak256(abi.encode(r.snapshot)) != keccak256(abi.encode(empty))) {
                revert C.InvalidEconomicContinuity();
            }
        }
    }

    function _unchanged(Context memory c) private view {
        C.ImportState storage t = S.state().transfer;
        if (
            t.source.codehash != t.sourceRuntimeHash
                || keccak256(abi.encode(_admitSource(c, t.source)))
                    != keccak256(abi.encode(t.expected))
        ) revert C.EconomicContinuitySourceChanged();
    }

    function _admitSource(Context memory c, address source)
        private
        view
        returns (C.Header memory h)
    {
        if (
            source == address(0) || source == address(this) || source.code.length == 0
                || c.core.codehash != c.coreHash
        ) {
            revert C.InvalidEconomicContinuity();
        }
        bytes memory ptr = _read(
            c, c.core, abi.encodeCall(Core.getSatellitePointer, (ROYALTY)), 320
        );
        (address selected, bytes32 hash,,,,,,,,) = abi.decode(
            ptr, (address, bytes32, bool, bytes32, bytes4, address, uint8, bytes32, bytes32, uint64)
        );
        if (
            selected != source || hash != source.codehash
                || abi.decode(
                        _read(c, source, abi.encodeWithSelector(ERC165, type(I).interfaceId), 32),
                        (uint256)
                    ) != 1
                || abi.decode(_read(c, source, abi.encodeWithSignature("owner()"), 32), (address))
                    != c.authority
                || abi.decode(
                        _read(c, source, abi.encodeWithSignature("boundCoreCodeHash()"), 32),
                        (bytes32)
                    ) != c.coreHash
                || !abi.decode(
                    _read(c, source, abi.encodeCall(I.economicContinuityReady, ()), 32), (bool)
                )
        ) {
            revert C.InvalidEconomicContinuity();
        }
        h = _header(c, source);
        if (
            h.schemaVersion != 1 || h.core != c.core || h.factory != c.factory
                || h.maxRoyaltyBps != c.maximum || (h.protectedCount == 0) != (h.protectedRoot == 0)
                || (h.electionCount == 0) != (h.electionRoot == 0)
        ) {
            revert C.InvalidEconomicContinuity();
        }
    }

    function _header(Context memory c, address source) private view returns (C.Header memory h) {
        h = abi.decode(_read(c, source, abi.encodeCall(I.continuityHeader, ()), 288), (C.Header));
    }

    function _read(Context memory, address target, bytes memory input, uint256 expected)
        private
        view
        returns (bytes memory data)
    {
        uint256 cap = Parameters.value(Parameters.READ_GAS);
        uint256 available = gasleft();
        if (available <= 35000) revert C.EconomicContinuityReadFailed(target, bytes4(input));
        uint256 possible = (available - 30000) * 63 / 64;
        if (cap > possible) cap = possible;
        data = new bytes(expected);
        bool ok;
        assembly ("memory-safe") {
            ok := staticcall(cap, target, add(input, 32), mload(input), add(data, 32), expected)
            ok := and(ok, eq(returndatasize(), expected))
        }
        if (!ok) revert C.EconomicContinuityReadFailed(target, bytes4(input));
    }
}
