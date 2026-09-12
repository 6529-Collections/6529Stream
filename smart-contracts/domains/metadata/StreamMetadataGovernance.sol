// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../../interfaces/stream/metadata/IStreamCollectionMetadataV1.sol";
import "../../interfaces/stream/governance/IStreamGovernanceReads.sol";

/// @notice Bounded live-root authorization for metadata catalog and family grants.
/// @dev Public library calls retain the host address and original caller through DELEGATECALL.
library StreamMetadataGovernance {
    function configurationScope(address executor, bytes32 codeHash, uint256 cap, bytes32 key)
        public
        view
        returns (bytes32)
    {
        (address root, bytes32 rootCodeHash, uint64 revision) = _root(executor, codeHash, cap);
        return keccak256(
            abi.encode(
                keccak256("6529STREAM_METADATA_RECORD_CONFIGURATION_V1"),
                block.chainid,
                address(this),
                key,
                root,
                rootCodeHash,
                revision
            )
        );
    }

    function requireTransition(
        address executor,
        bytes32 codeHash,
        uint256 cap,
        bytes32 scope,
        bytes32 oldHash,
        bytes32 newHash
    ) public view returns (bytes32 actionId) {
        if (msg.sender != executor) {
            revert IStreamCollectionMetadataV1.MetadataAuthorityRequired();
        }
        bool executing;
        uint8 actionClass;
        bytes32 actualScope;
        bytes32 actualOld;
        bytes32 actualNew;
        (executing, actionId, actionClass, actualScope, actualOld, actualNew) = abi.decode(
            _fixed(executor, abi.encodeCall(IStreamGovernanceReads.currentAction, ()), 192, cap),
            (bool, bytes32, uint8, bytes32, bytes32, bytes32)
        );
        if (
            !executing || actionId == 0 || actionClass != 1 || actualScope != scope
                || actualOld != oldHash || actualNew != newHash
        ) {
            revert IStreamCollectionMetadataV1.MetadataAuthorityRequired();
        }
        _requireRootProposer(executor, codeHash, cap, actionId);
    }

    function _requireRootProposer(address executor, bytes32 codeHash, uint256 cap, bytes32 actionId)
        private
        view
    {
        (address root,,) = _root(executor, codeHash, cap);
        // The canonical getter returns one dynamic tuple. Copy only its fixed header and
        // reason length, even if the published reason URI is long. Action target/selector
        // describe the first batch element; the active per-call context was checked above.
        (bytes memory header, uint256 size) = _read(
            executor, abi.encodeCall(IStreamGovernanceReads.governanceAction, (actionId)), 640, cap
        );
        uint256 uriLength = _word(header, 19);
        if (
            size < 640 || _word(header, 0) != 32 || _word(header, 17) != 576
                || uriLength > size - 640 || size % 32 != 0 || size - 640 - uriLength > 31
                || _word(header, 1) != uint256(GovernanceActionStatus.EXECUTED)
                || _word(header, 2) != 1 || _word(header, 12) != uint160(root)
        ) {
            revert IStreamCollectionMetadataV1.MetadataAuthorityRequired();
        }
    }

    function _root(address executor, bytes32 codeHash, uint256 cap)
        private
        view
        returns (address root, bytes32 rootCodeHash, uint64 revision)
    {
        if (executor.code.length == 0 || executor.codehash != codeHash) {
            revert IStreamCollectionMetadataV1.MetadataDependencyChanged(executor);
        }
        (root, rootCodeHash, revision) = abi.decode(
            _fixed(
                executor, abi.encodeCall(IStreamGovernanceReads.governanceRootState, ()), 96, cap
            ),
            (address, bytes32, uint64)
        );
        if (root == address(0) || revision == 0 || root.codehash != rootCodeHash) {
            revert IStreamCollectionMetadataV1.MetadataAuthorityRequired();
        }
    }

    function _word(bytes memory data, uint256 index) private pure returns (uint256 word) {
        assembly ("memory-safe") { word := mload(add(add(data, 32), mul(index, 32))) }
    }

    function _fixed(address target, bytes memory input, uint256 length, uint256 cap)
        private
        view
        returns (bytes memory data)
    {
        uint256 size;
        (data, size) = _read(target, input, length, cap);
        if (size != length) revert IStreamCollectionMetadataV1.MetadataReadFailed(target);
    }

    function _read(address target, bytes memory input, uint256 length, uint256 cap)
        private
        view
        returns (bytes memory data, uint256 size)
    {
        if (gasleft() <= cap + cap / 63 + 10000) {
            revert IStreamCollectionMetadataV1.MetadataReadFailed(target);
        }
        data = new bytes(length);
        bool ok;
        assembly ("memory-safe") {
            ok := staticcall(cap, target, add(input, 32), mload(input), add(data, 32), length)
            size := returndatasize()
        }
        if (!ok || size < length) revert IStreamCollectionMetadataV1.MetadataReadFailed(target);
    }
}
