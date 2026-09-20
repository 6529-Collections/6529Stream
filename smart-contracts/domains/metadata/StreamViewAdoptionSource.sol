// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "../../interfaces/stream/finality/StreamArtworkFinalityTypes.sol";
import "../../interfaces/stream/finality/StreamScopeMembershipTypes.sol";
import {
    StreamViewAdoptionTypes as V
} from "../../interfaces/stream/metadata/StreamViewAdoptionTypes.sol";
import { StreamViewAdoptionReads as Read } from "./StreamViewAdoptionReads.sol";
import { StreamViewAdoptionDocuments as Documents } from "./StreamViewAdoptionDocuments.sol";
import { StreamMetadataSubjects as Subjects } from "./StreamMetadataSubjects.sol";
import {
    IStreamFinalityScopeMembership as Membership
} from "../../interfaces/stream/finality/IStreamFinalityScopeMembership.sol";
import {
    IStreamCollectionMetadataV1 as Metadata
} from "../../interfaces/stream/metadata/IStreamCollectionMetadataV1.sol";
import {
    IStreamCoreCollectionView as Core
} from "../../interfaces/stream/core/IStreamCoreCollectionView.sol";
import {
    IStreamArtworkFinalityRegistry as Finality
} from "../../interfaces/stream/finality/IStreamArtworkFinalityRegistry.sol";
import { StreamRecordFamilies as Family } from "../records/StreamRecordFamilies.sol";

library StreamViewAdoptionSource {
    function prepare(
        address core,
        address artist,
        address authority,
        V.Input memory p,
        address actor
    ) public view returns (V.Record memory r) {
        if (
            actor == address(0) || p.scope.scopeType != StreamFinalityScopeType.VIEW
                || p.scope.collectionId == 0 || p.scope.scopeId == 0 || p.scope.tokenId != 0
                || p.viewId == 0 || p.viewRecordHash == 0 || p.rendererVersionKey == 0
        ) revert V.InvalidViewAdoption();
        bytes32 subject = Subjects.scopeSubject(block.chainid, core, p.scope);
        V.Route memory route = Read.route(core, artist, authority);
        uint256 cap = route.binding.readGas;
        if (
            Read.word(core, abi.encodeCall(Core.collectionExists, (p.scope.collectionId)), cap) != 1
        ) {
            revert V.InvalidViewAdoption();
        }
        if (
            Read.word(
                        core,
                        abi.encodeCall(Core.collectionFreezeStatus, (p.scope.collectionId)),
                        cap
                    ) != 0
                || Read.word(
                        route.finality, abi.encodeCall(Finality.artworkFreezeMode, (p.scope)), cap
                    ) != uint256(StreamArtworkFreezeMode.NONE)
        ) revert V.ViewAdoptionFrozen(subject);
        r.source = Documents.load(route, p, authority);
        bytes memory raw = Read.read(
            route.binding.membership,
            abi.encodeCall(Membership.requireScopeMembership, (p.scope)),
            256,
            route.binding.sourceGas
        );
        r.source.membership = abi.decode(raw, (StreamScopeMembershipFacts));
        StreamScopeMembershipFacts memory m = r.source.membership;
        if (
            keccak256(raw) != keccak256(abi.encode(m)) || m.scopeSubject != subject
                || m.scopeManifestHash == 0 || m.sourceRecordHash == 0 || m.tokenListHash == 0
                || m.membershipHash == 0 || m.inventoryCount != 0 || m.inventoryPrefixHash != 0
        ) revert V.InvalidViewAdoption();
        r.sourceHash = keccak256(
            abi.encode(
                keccak256("6529STREAM_VIEW_ADOPTION_SOURCE_V1"),
                block.chainid,
                address(this),
                p.scope,
                p.viewId,
                p.viewRecordHash,
                r.source
            )
        );
        if (p.expectedSourceHash != 0 && p.expectedSourceHash != r.sourceHash) {
            revert V.InvalidViewAdoption();
        }
        p.expectedSourceHash = r.sourceHash;
        r.input = p;
        r.actor = actor;
        (r.authorizationClass, r.grantCollectionId, r.grantRevision) =
            _authority(route, p.scope.collectionId, actor);
    }

    function _authority(V.Route memory r, uint256 cid, address actor)
        private
        view
        returns (uint8, uint256, uint64)
    {
        for (uint8 cls = 7; cls <= 8; ++cls) {
            for (uint256 i; i < 2; ++i) {
                uint256 grantCid = i == 0 ? cid : 0;
                bytes memory raw = Read.read(
                    r.metadata,
                    abi.encodeCall(Metadata.familyWriter, (grantCid, Family.IDENTITY, cls, actor)),
                    64,
                    r.binding.readGas
                );
                (bool enabled, uint64 revision) = abi.decode(raw, (bool, uint64));
                if (keccak256(raw) != keccak256(abi.encode(enabled, revision))) {
                    revert V.InvalidViewAdoption();
                }
                if (enabled && revision != 0) return (cls, grantCid, revision);
            }
        }
        revert V.ViewAdoptionAuthority(actor);
    }
}
