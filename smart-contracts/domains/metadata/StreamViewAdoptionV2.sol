// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamViewAdoptionTypes as V
} from "../../interfaces/stream/metadata/StreamViewAdoptionTypes.sol";
import {
    IStreamViewAdoptionPolicyRouterV2 as Interface
} from "../../interfaces/stream/metadata/IStreamViewAdoptionPolicyRouterV2.sol";
import { StreamViewAdoptionState as State } from "./StreamViewAdoptionState.sol";
import { StreamViewAdoptionStateV2 as PolicyState } from "./StreamViewAdoptionStateV2.sol";
import { StreamViewPolicyTypesV2 as T } from "./StreamViewPolicyTypesV2.sol";
import { StreamViewAdoptionSourceV2 as Source } from "./StreamViewAdoptionSourceV2.sol";
import { StreamMetadataStaticState as Static } from "./StreamMetadataStaticState.sol";
import { StreamMetadataRouterContent as Content } from "./StreamMetadataRouterContent.sol";

/// @notice Fixed Router delegate worker, sharing the original op17 consent and evolution book.
library StreamViewAdoptionV2 {
    struct Locks {
        mapping(uint256 => mapping(bytes32 => bool)) values;
    }
    event ViewAdopted(
        uint16 schemaVersion,
        bytes32 profile,
        uint256 indexed collectionId,
        bytes32 indexed scopeSubject,
        bytes32 indexed recordHash,
        V.Record record
    );

    function previewEncoded(
        Content.Layout memory l,
        Content.Context memory c,
        bytes calldata original
    ) public view returns (bytes memory) {
        if (bytes4(original) != Interface.previewPolicyViewAdoption.selector) {
            revert V.InvalidViewAdoption();
        }
        (V.Input memory input, address actor) = abi.decode(original[4:], (V.Input, address));
        (bytes32 family, bytes32 source) = preview(l, c, input, actor);
        return abi.encode(family, source);
    }

    function adoptEncoded(
        Content.Layout memory l,
        Content.Context memory c,
        bytes calldata original
    ) public returns (bytes32) {
        if (bytes4(original) != Interface.adoptPolicyView.selector) {
            revert V.InvalidViewAdoption();
        }
        return adopt(l, c, abi.decode(original[4:], (V.Input)));
    }

    function encoded(bytes32 key) public view returns (bytes memory) {
        return State.encoded(key);
    }

    function preview(
        Content.Layout memory l,
        Content.Context memory c,
        V.Input memory input,
        address actor
    ) internal view returns (bytes32 family, bytes32 source) {
        _mutable(l, c, input);
        V.Record memory r = Source.prepare(c.core, c.artist, c.authority, input, actor);
        return (_nextFamily(c.core, r), r.sourceHash);
    }

    function adopt(Content.Layout memory l, Content.Context memory c, V.Input memory input)
        internal
        returns (bytes32 hash)
    {
        _mutable(l, c, input);
        V.Record memory r = Source.prepare(c.core, c.artist, c.authority, input, msg.sender);
        if (input.expectedSourceHash == 0) revert V.InvalidViewAdoption();
        bytes32 nextFamily = _nextFamily(c.core, r);
        (bytes32 consent, bytes32 ratification) =
            Content.authorizeView(l, c, input.scope.collectionId, nextFamily);
        _mutable(l, c, input);
        V.Record memory live = Source.prepare(c.core, c.artist, c.authority, input, msg.sender);
        if (
            keccak256(abi.encode(live)) != keccak256(abi.encode(r))
                || _nextFamily(c.core, live) != nextFamily
        ) revert V.InvalidViewAdoption();
        hash = PolicyState.commit(c.core, r, consent);
        Content.recordApplication(
            l, c, input.scope.collectionId, Static.FAMILY, consent, ratification
        );
        V.Record memory saved = abi.decode(State.encoded(hash), (V.Record));
        emit ViewAdopted(
            2, T.PROFILE, input.scope.collectionId, State.subject(c.core, input.scope), hash, saved
        );
    }

    function _nextFamily(address core, V.Record memory r) private view returns (bytes32) {
        uint256 cid = r.input.scope.collectionId;
        return State.wrap(
            core,
            cid,
            Static.legacyFamilyOf(core, cid, Static.state().collections[cid]),
            PolicyState.next(core, r)
        );
    }

    function _mutable(Content.Layout memory l, Content.Context memory c, V.Input memory p)
        private
        view
    {
        if (!Static.activated(p.scope.collectionId)) revert V.InvalidViewAdoption();
        Locks storage locks;
        uint256 slot = l._artistContentLocks;
        assembly ("memory-safe") { locks.slot := slot }
        if (locks.values[p.scope.collectionId][Static.FAMILY]) {
            revert V.ViewAdoptionFrozen(State.subject(c.core, p.scope));
        }
        // A frozen marketplace configuration is not an alternate VIEW scope freeze. Source
        // preparation separately enforces collection freeze and exact/inherited artwork freeze.
    }
}
