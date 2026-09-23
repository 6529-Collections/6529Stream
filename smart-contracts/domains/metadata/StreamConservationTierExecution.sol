// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./StreamCollectionMetadataV1.sol";
import "./StreamConservationTiers.sol";
import "../../interfaces/stream/metadata/IStreamConservationTier.sol";
import "../../interfaces/stream/metadata/IStreamCollectionMetadataV1.sol";
import "../../interfaces/stream/core/IStreamCoreCollectionView.sol";
import "../../interfaces/stream/core/IStreamCoreConservationTier.sol";
import "../records/StreamRecordFamilies.sol";

/// @notice Fixed tier facade worker; grants stay in Metadata, declarations stay in Core.
library StreamConservationTierExecution {
    event CollectionConservationTierDeclared(
        uint256 indexed collectionId, bytes32 indexed tier, uint16 schemaVersion
    );

    function declareTier(
        mapping(bytes32 => StreamCollectionMetadataV1.Grant) storage grants,
        address core,
        bytes32 coreCodeHash,
        uint256 readGas,
        uint256 collectionId,
        bytes32 tier
    ) public {
        _knownCollection(core, coreCodeHash, readGas, collectionId);
        // A collection metadata administrator and a global administrator are separate grants.
        // A broad RIGHTS grant, artist signature, curator, or owner is never sufficient.
        if (
            !grants[_key(collectionId, 7, msg.sender)].enabled
                && !grants[_key(0, 8, msg.sender)].enabled
        ) revert IStreamCollectionMetadataV1.MetadataAuthorityRequired();
        StreamConservationTiers.requireKnown(tier);
        IStreamCoreConservationTier(core).recordConservationTier(collectionId, tier);
        emit CollectionConservationTierDeclared(collectionId, tier, 1);
    }

    function readTier(address core, bytes32 coreCodeHash, uint256 readGas, uint256 collectionId)
        public
        view
        returns (bytes32 declared, bytes32 effective)
    {
        _knownCollection(core, coreCodeHash, readGas, collectionId);
        declared = bytes32(
            _word(
                core,
                abi.encodeCall(
                    IStreamCoreConservationTier.declaredConservationTier, (collectionId)
                ),
                readGas
            )
        );
        uint256 completedMints = _word(
            core,
            abi.encodeCall(IStreamCoreCollectionView.collectionMintedEver, (collectionId)),
            readGas
        );
        effective = StreamConservationTiers.effective(declared, completedMints);
    }

    function _key(uint256 collectionId, uint8 authClass, address account)
        private
        pure
        returns (bytes32)
    {
        return keccak256(
            abi.encode(collectionId, StreamRecordFamilies.CONSERVATION, authClass, account)
        );
    }

    function _knownCollection(address core, bytes32 codeHash, uint256 cap, uint256 collectionId)
        private
        view
    {
        if (core.code.length == 0 || core.codehash != codeHash) {
            revert IStreamCollectionMetadataV1.MetadataDependencyChanged(core);
        }
        if (
            collectionId == 0
                || _word(
                        core,
                        abi.encodeCall(IStreamCoreCollectionView.collectionExists, (collectionId)),
                        cap
                    ) != 1
        ) revert IStreamCollectionMetadataV1.InvalidMetadataRecord();
    }

    function _word(address target, bytes memory data, uint256 cap)
        private
        view
        returns (uint256 result)
    {
        if (gasleft() <= cap + cap / 63 + 10000) {
            revert IStreamCollectionMetadataV1.MetadataReadFailed(target);
        }
        bool ok;
        uint256 size;
        assembly ("memory-safe") {
            ok := staticcall(cap, target, add(data, 32), mload(data), 0, 32)
            size := returndatasize()
            result := mload(0)
        }
        if (!ok || size != 32) revert IStreamCollectionMetadataV1.MetadataReadFailed(target);
    }
}
