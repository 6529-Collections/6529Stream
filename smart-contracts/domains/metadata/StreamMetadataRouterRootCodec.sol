// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    IStreamContentRootPublication as R
} from "../../interfaces/stream/metadata/IStreamContentRootPublication.sol";
import {
    IStreamScopedContentRootPublication as S
} from "../../interfaces/stream/metadata/IStreamScopedContentRootPublication.sol";
import {
    IStreamPolicyContentRootPublicationV2 as V
} from "../../interfaces/stream/metadata/IStreamPolicyContentRootPublicationV2.sol";
import {
    StreamMetadataPolicyContentRootV2 as PolicyRoot
} from "./StreamMetadataPolicyContentRootV2.sol";
import { StreamMetadataRouterContent as Content } from "./StreamMetadataRouterContent.sol";
import { StreamMetadataContentRoot as Root } from "./StreamMetadataContentRoot.sol";
import { StreamMetadataScopedContent as Scoped } from "./StreamMetadataScopedContent.sol";
import {
    StreamMetadataScopedContentState as ScopedState
} from "./StreamMetadataScopedContentState.sol";

/// @notice Fixed codecs around the original publication workers and original Router storage.
/// @dev No record cache or new state. Delegate execution retains the actual caller and Router.
library StreamMetadataRouterRootCodec {
    bytes32 private constant FAMILY = keccak256("CONTENT_ROOT");

    function preview(
        Root.State storage roots,
        ScopedState.State storage scoped,
        Content.Layout memory layout,
        Content.Context memory context,
        bytes calldata input
    ) public view returns (bytes32) {
        bytes4 selector = bytes4(input[:4]);
        if (selector == R.previewContentRootPublication.selector) {
            (R.Publication memory publication, address publisher) =
                abi.decode(input[4:], (R.Publication, address));
            bytes32 legacy =
                Root.prepare(
                roots, Root.Context(context.core, context.artist), publication, publisher
            )
            .stateHash;
            return ScopedState.familyCurrent(context.core, publication.collectionId, legacy);
        }
        if (selector == S.previewScopedContentRootPublication.selector) {
            (S.Publication memory publication, address publisher) =
                abi.decode(input[4:], (S.Publication, address));
            return Scoped.preview(scoped, layout, context, publication, publisher);
        }
        if (selector == V.previewPolicyContentRootPublication.selector) {
            (R.Publication memory publication, address publisher) =
                abi.decode(input[4:], (R.Publication, address));
            (R.Record memory prepared,) = PolicyRoot.prepare(
                roots, Root.Context(context.core, context.artist), publication, publisher
            );
            return
                ScopedState.familyCurrent(
                    context.core, publication.collectionId, prepared.stateHash
                );
        }
        revert R.InvalidContentRootPublication();
    }

    function publish(
        Root.State storage roots,
        ScopedState.State storage scoped,
        Content.Layout memory layout,
        Content.Context memory context,
        bytes calldata input
    ) public returns (bytes32 recordHash) {
        bytes4 selector = bytes4(input[:4]);
        if (selector == R.publishVerifiedTokenContentRoot.selector) {
            R.Publication memory publication = abi.decode(input[4:], (R.Publication));
            Root.Context memory ctx = Root.Context(context.core, context.artist);
            R.Record memory prepared = Root.prepare(roots, ctx, publication, msg.sender);
            (bytes32 consent, bytes32 ratification) = Content.authorize(
                layout,
                context,
                publication.collectionId,
                FAMILY,
                ScopedState.familyCurrent(
                    context.core, publication.collectionId, prepared.stateHash
                )
            );
            recordHash = Root.publish(roots, ctx, publication, prepared, consent);
            Content.recordApplication(
                layout, context, publication.collectionId, FAMILY, consent, ratification
            );
            return recordHash;
        }
        if (selector == S.publishScopedContentRootPublication.selector) {
            S.Publication memory publication = abi.decode(input[4:], (S.Publication));
            return Scoped.publish(scoped, layout, context, publication);
        }
        if (selector == V.publishVerifiedPolicyContentRoot.selector) {
            R.Publication memory publication = abi.decode(input[4:], (R.Publication));
            Root.Context memory ctx = Root.Context(context.core, context.artist);
            (R.Record memory prepared, V.Binding memory binding) =
                PolicyRoot.prepare(roots, ctx, publication, msg.sender);
            (bytes32 consent, bytes32 ratification) = Content.authorize(
                layout,
                context,
                publication.collectionId,
                FAMILY,
                ScopedState.familyCurrent(
                    context.core, publication.collectionId, prepared.stateHash
                )
            );
            recordHash = PolicyRoot.publish(roots, ctx, publication, prepared, binding, consent);
            Content.recordApplication(
                layout, context, publication.collectionId, FAMILY, consent, ratification
            );
            return recordHash;
        }
        revert R.InvalidContentRootPublication();
    }

    function read(Root.State storage roots, bytes calldata input)
        public
        view
        returns (bytes memory)
    {
        bytes4 selector = bytes4(input[:4]);
        bytes32 hash = abi.decode(input[4:], (bytes32));
        if (selector == R.contentRootRecord.selector) {
            return abi.encode(Root.readRecord(roots, hash));
        }
        if (selector == V.policyContentRootBinding.selector) {
            return abi.encode(PolicyRoot.readBinding(hash));
        }
        revert R.InvalidContentRootPublication();
    }
}
