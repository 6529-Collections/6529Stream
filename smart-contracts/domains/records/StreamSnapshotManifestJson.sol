// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../../interfaces/stream/metadata/StreamSnapshotTypes.sol";
import "../../interfaces/stream/finality/StreamFinalityCoordinatorPolicyTypes.sol";
import "./StreamRecordJson.sol";
import "./StreamSnapshotDefinitions.sol";

/// @notice Complete fixed-key canonical JSON for the native assembled source profile.
/// @dev Inputs are populated exclusively by the fixed host's actual source/policy readers.
///      Decimal strings preserve every uint256 value; source text is never normalized.
library StreamSnapshotManifestJson {
    function manifest(
        StreamSnapshotTypes.Dependencies memory d,
        StreamSnapshotTypes.NativeFacts memory n,
        StreamFinalityCoordinatorPolicyEvidence memory entropy,
        StreamSnapshotTypes.Publication memory p,
        StreamSnapshotTypes.Receipt memory r
    ) public pure returns (bytes memory raw) {
        string memory out = string.concat(
            '{"chainId":',
            StreamRecordJson.unsigned(d.chainId),
            ',"collectionId":',
            StreamRecordJson.unsigned(n.collectionId),
            ',"contentRoot":',
            _root(n),
            ',"dependencyReadProfile":',
            _hash(n.dependencyProfile),
            ',"entropy":',
            _entropy(entropy)
        );
        out = string.concat(
            out,
            ',"metadata":',
            _metadata(n),
            ',"profileHash":',
            _hash(StreamSnapshotDefinitions.PROFILE_HASH),
            ',"publication":',
            _publication(p, r),
            ',"renderer":',
            _renderer(n)
        );
        out = string.concat(
            out,
            ',"schemaHash":',
            _hash(StreamSnapshotDefinitions.SCHEMA_HASH),
            ',"schemaId":',
            _hash(StreamSnapshotDefinitions.SCHEMA_ID),
            ',"script":',
            _script(n)
        );
        out = string.concat(
            out, ',"sources":', _sources(d), ',"subject":', _hash(n.subject), ',"version":1}'
        );
        raw = bytes(out);
        if (raw.length == 0 || raw.length > 524288) revert StreamSnapshotTypes.SnapshotSource();
    }

    function _publication(
        StreamSnapshotTypes.Publication memory p,
        StreamSnapshotTypes.Receipt memory r
    ) private pure returns (string memory) {
        string memory out = string.concat(
            '{"authorizationClass":',
            StreamRecordJson.unsigned(r.authorizationClass),
            ',"displayAuthorizationClass":',
            StreamRecordJson.unsigned(r.displayAuthorizationClass),
            ',"displayGrantRevision":',
            StreamRecordJson.unsigned(r.displayGrantRevision),
            ',"effectiveAt":',
            StreamRecordJson.unsigned(p.effectiveAt)
        );
        out = string.concat(
            out,
            ',"grantRevision":',
            StreamRecordJson.unsigned(r.grantRevision),
            ',"manifestURI":',
            StreamRecordJson.quote(p.manifestURI, 2048, true),
            ',"predecessor":',
            _hash(p.expectedHead),
            ',"publisher":',
            _account(r.publisher)
        );
        out = string.concat(
            out,
            ',"reasonHash":',
            _hash(p.reasonHash),
            ',"revision":',
            StreamRecordJson.unsigned(r.revision),
            ',"snapshotId":',
            _hash(p.snapshotId),
            "}"
        );
        return out;
    }

    function _metadata(StreamSnapshotTypes.NativeFacts memory n)
        private
        pure
        returns (string memory)
    {
        return string.concat(
            '{"animationBaseURI":',
            StreamRecordJson.quote(n.source.animationBaseURI, 2048, true),
            ',"artist":',
            _artist(n.artist),
            ',"description":',
            StreamRecordJson.quote(n.source.description, 2048, true),
            ',"imageURI":',
            StreamRecordJson.quote(n.source.imageURI, 2048, true),
            ',"locks":{"artistIdentity":true,"baseURI":true,"dependencies":true,"displayMetadata":true,"media":true,"script":true}',
            ',"name":',
            StreamRecordJson.quote(n.source.name, 256, true),
            "}"
        );
    }

    function _artist(IStreamMetadataServingFacts.ArtistPresentation memory p)
        private
        pure
        returns (string memory)
    {
        string memory out = string.concat(
            '{"acceptanceRecordHash":',
            _hash(p.acceptanceRecordHash),
            ',"acceptedAt":',
            StreamRecordJson.unsigned(p.acceptedAt),
            ',"artistId":',
            _hash(p.artistId),
            ',"bindingGeneration":',
            StreamRecordJson.unsigned(p.bindingGeneration)
        );
        out = string.concat(
            out,
            ',"bindingHash":',
            _hash(p.bindingHash),
            ',"identityRecordHash":',
            _hash(p.identityRecordHash),
            ',"lockedAt":',
            StreamRecordJson.unsigned(p.lockedAt),
            ',"nominatedArtist":',
            _account(p.nominatedArtist)
        );
        out = string.concat(
            out,
            ',"registry":',
            _account(p.registry),
            ',"registryCodeHash":',
            _hash(p.registryCodeHash),
            ',"snapshotHash":',
            _hash(p.snapshotHash),
            "}"
        );
        return out;
    }

    function _script(StreamSnapshotTypes.NativeFacts memory n)
        private
        pure
        returns (string memory)
    {
        return string.concat(
            '{"byteLength":',
            StreamRecordJson.unsigned(bytes(n.source.script).length),
            ',"content":',
            StreamRecordJson.quote(n.source.script, 8192, false),
            ',"contentHash":',
            _hash(n.serving.scriptHash),
            ',"mode":"ONCHAIN"}'
        );
    }

    function _renderer(StreamSnapshotTypes.NativeFacts memory n)
        private
        pure
        returns (string memory)
    {
        string memory out = string.concat(
            '{"address":',
            _account(n.serving.renderer),
            ',"context":',
            _hash(n.rendererContext),
            ',"presentationProfile":',
            _hash(n.presentationProfile),
            ',"routerManifestHash":',
            _hash(n.routerManifestHash)
        );
        out = string.concat(
            out,
            ',"routerVersion":',
            _hash(n.routerVersion),
            ',"runtimeHash":',
            _hash(n.serving.rendererCodeHash),
            "}"
        );
        return out;
    }

    function _root(StreamSnapshotTypes.NativeFacts memory n) private pure returns (string memory) {
        IStreamContentRootPublication.Record memory r = n.contentRoot;
        string memory out = string.concat(
            '{"artistConsent":',
            _hash(r.artistConsent),
            ',"authorizationClass":',
            StreamRecordJson.unsigned(r.authorizationClass),
            ',"checkpoint":',
            _checkpoint(n),
            ',"contentRoot":',
            _hash(r.contentRoot)
        );
        out = string.concat(
            out,
            ',"grantRevision":',
            StreamRecordJson.unsigned(r.grantRevision),
            ',"leafCount":',
            StreamRecordJson.unsigned(r.leafCount),
            ',"leafManifest":',
            _leaves(n),
            ',"manifestHash":',
            _hash(r.manifestHash)
        );
        out = string.concat(
            out,
            ',"manifestURI":',
            StreamRecordJson.quote(r.publication.manifestURI, 2048, true),
            ',"predecessor":',
            _hash(r.publication.expectedPredecessor),
            ',"publishedAt":',
            StreamRecordJson.unsigned(r.publishedAt),
            ',"publisher":',
            _account(r.publisher)
        );
        out = string.concat(
            out,
            ',"recordHash":',
            _hash(n.contentRootRecordHash),
            ',"routeHash":',
            _hash(r.routeHash),
            ',"stateHash":',
            _hash(r.stateHash),
            "}"
        );
        return out;
    }

    function _checkpoint(StreamSnapshotTypes.NativeFacts memory n)
        private
        pure
        returns (string memory)
    {
        string memory out = string.concat(
            '{"contentRoot":',
            _hash(n.checkpoint.contentRoot),
            ',"inventoryHash":',
            _hash(n.checkpoint.inventoryHash),
            ',"leafChainHash":',
            _hash(n.checkpoint.leafChainHash),
            ',"planHash":',
            _hash(n.leafManifest.checkpointHash)
        );
        out = string.concat(
            out,
            ',"servingStateHash":',
            _hash(n.checkpoint.servingStateHash),
            ',"tokenCount":',
            StreamRecordJson.unsigned(n.checkpoint.tokenCount),
            "}"
        );
        return out;
    }

    function _leaves(StreamSnapshotTypes.NativeFacts memory n)
        private
        pure
        returns (string memory)
    {
        return string.concat(
            '{"artifactHash":',
            _hash(n.leafManifest.artifactHash),
            ',"byteLength":',
            StreamRecordJson.unsigned(n.leafManifest.byteLength),
            ',"coverageHash":',
            _hash(n.leafManifest.coverageHash),
            ',"recordHash":',
            _hash(n.contentRoot.publication.verifiedManifestRecordHash),
            "}"
        );
    }

    function _sources(StreamSnapshotTypes.Dependencies memory d)
        private
        pure
        returns (string memory out)
    {
        out = "[";
        for (uint256 i; i < d.targets.length; ++i) {
            out = string.concat(
                out,
                i == 0 ? "" : ",",
                '{"address":',
                _account(d.targets[i]),
                ',"role":',
                StreamRecordJson.unsigned(i),
                ',"runtimeHash":',
                _hash(d.codeHashes[i]),
                "}"
            );
        }
        return string.concat(out, "]");
    }

    function _entropy(StreamFinalityCoordinatorPolicyEvidence memory e)
        private
        pure
        returns (string memory)
    {
        if (!e.allFrozen || e.policyCount == 0 || e.policies.length != e.policyCount) {
            revert StreamSnapshotTypes.SnapshotSource();
        }
        string memory policies = "[";
        for (uint256 i; i < e.policies.length; ++i) {
            policies = string.concat(policies, i == 0 ? "" : ",", _policy(e.policies[i]));
            if (bytes(policies).length > 524288) revert StreamSnapshotTypes.SnapshotSource();
        }
        return string.concat(
            '{"allFrozen":true,"inventoryHash":',
            _hash(e.inventoryHash),
            ',"planId":',
            _hash(e.planId),
            ',"policies":',
            policies,
            '],"policyChainHash":',
            _hash(e.policyChainHash),
            ',"policyCount":',
            StreamRecordJson.unsigned(e.policyCount),
            "}"
        );
    }

    function _policy(StreamFinalityCoordinatorPolicy memory p)
        private
        pure
        returns (string memory)
    {
        if (!p.frozen) revert StreamSnapshotTypes.SnapshotSource();
        string memory out = string.concat(
            '{"componentDataHash":',
            _hash(p.componentDataHash),
            ',"coordinator":',
            _account(p.coordinator),
            ',"deploymentManifestHash":',
            _hash(p.deploymentManifestHash),
            ',"epoch":',
            StreamRecordJson.unsigned(p.epoch)
        );
        out = string.concat(
            out,
            ',"firstTokenIndex":',
            StreamRecordJson.unsigned(p.firstTokenIndex),
            ',"frozen":true',
            ',"indexedCodeHash":',
            _hash(p.indexedCodeHash),
            ',"moduleManifestHash":',
            _hash(p.moduleManifestHash),
            ',"moduleSchemaHash":'
        );
        out = string.concat(
            out,
            _hash(p.moduleSchemaHash),
            ',"moduleVersion":',
            _hash(p.moduleVersion),
            ',"policyHash":',
            _hash(p.policyHash),
            ',"provider":',
            _account(p.provider),
            ',"salt":'
        );
        out = string.concat(out, _hash(p.salt), "}");
        return out;
    }

    /// @dev Fixed widths are proven by the types, so no dynamic-byte hex indexing is needed.
    function hashJSON(bytes32 value) public pure returns (string memory) {
        return _hash(value);
    }

    function accountJSON(address value) public pure returns (string memory) {
        return _account(value);
    }

    function _hash(bytes32 value) private pure returns (string memory) {
        return _quotedHex(value, 32);
    }

    function _account(address value) private pure returns (string memory) {
        if (value == address(0)) revert StreamRecordJson.InvalidJsonWitness();
        return _quotedHex(bytes32(uint256(uint160(value)) << 96), 20);
    }

    function _quotedHex(bytes32 value, uint256 size) private pure returns (string memory result) {
        result = new string(size * 2 + 4);
        assembly ("memory-safe") {
            let start := add(result, 32)
            mstore8(start, 0x22)
            mstore8(add(start, 1), 0x30)
            mstore8(add(start, 2), 0x78)
            let alphabet := 0x3031323334353637383961626364656600000000000000000000000000000000
            let cursor := add(start, 3)
            let end := add(cursor, mul(size, 2))
            for { } lt(cursor, end) { cursor := add(cursor, 1) } {
                mstore8(cursor, byte(shr(252, value), alphabet))
                value := shl(4, value)
            }
            mstore8(end, 0x22)
        }
    }
}
