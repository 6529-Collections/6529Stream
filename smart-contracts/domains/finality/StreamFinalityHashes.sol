// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../../interfaces/stream/finality/StreamArtworkFinalityTypes.sol";

/// @notice Stateless permanent preimages; compiler linkage preserves the finality host context.
/// @dev Only the owning registry supplies its immutable Core. These functions do not validate facts.
library StreamFinalityHashes {
    function coreCollectionFactsHash(
        address core_,
        uint256 collectionId,
        StreamCoreCollectionFinalityFacts memory facts
    ) public view returns (bytes32) {
        return keccak256(
            bytes.concat(
                abi.encode(
                    StreamFinalityDomains.STREAM_CORE_COLLECTION_FACTS_V1,
                    block.chainid,
                    core_,
                    collectionId,
                    facts.exists,
                    facts.hasMaxSupply,
                    facts.status
                ),
                abi.encode(
                    facts.supplyMode,
                    facts.maxSupply,
                    facts.mintedSupply,
                    facts.burnedSupply,
                    facts.nextCollectionSerial,
                    facts.collectionConfigHash
                )
            )
        );
    }

    function scopedCoreFactsHash(
        address core_,
        StreamFinalityScope memory scope,
        StreamScopedCoreFinalityFacts memory facts
    ) public view returns (bytes32) {
        return keccak256(
            bytes.concat(
                abi.encode(
                    StreamFinalityDomains.STREAM_SCOPED_CORE_FINALITY_FACTS_V1,
                    block.chainid,
                    core_,
                    uint8(scope.scopeType),
                    scope.collectionId,
                    scope.tokenId,
                    scope.scopeId,
                    facts.scopeExists
                ),
                abi.encode(
                    facts.tokenMappingExists,
                    facts.collectionSerial,
                    facts.tokenLifecycle,
                    facts.burned,
                    facts.collectionStatus,
                    facts.collectionSupplyMode,
                    facts.collectionConfigHash,
                    facts.scopeManifestHash
                )
            )
        );
    }

    function finalityRecordHash(
        address core_,
        StreamFinalityScope memory scope,
        bytes32 coreFactsHash,
        bytes32 componentsHash,
        StreamFinalityManifestRef calldata manifest
    ) public view returns (bytes32) {
        if (scope.scopeType == StreamFinalityScopeType.COLLECTION) {
            return keccak256(
                bytes.concat(
                    abi.encode(
                        StreamFinalityDomains.STREAM_FINALITY_V1,
                        block.chainid,
                        core_,
                        scope.collectionId,
                        coreFactsHash
                    ),
                    abi.encode(
                        componentsHash,
                        manifest.uriHash,
                        manifest.contentHash,
                        manifest.schemaId,
                        manifest.canonicalizationHash
                    )
                )
            );
        }
        return keccak256(
            bytes.concat(
                abi.encode(
                    StreamFinalityDomains.STREAM_SCOPED_FINALITY_V1,
                    block.chainid,
                    core_,
                    uint8(scope.scopeType),
                    scope.collectionId,
                    scope.tokenId,
                    scope.scopeId
                ),
                abi.encode(
                    coreFactsHash,
                    componentsHash,
                    manifest.uriHash,
                    manifest.contentHash,
                    manifest.schemaId,
                    manifest.canonicalizationHash
                )
            )
        );
    }

    function sanctionSubjectHash(
        address core_,
        StreamFinalityScope memory scope,
        bytes32 coreFactsHash,
        bytes32 nonSanctionComponentsHash,
        StreamFinalityManifestRef calldata manifest
    ) public view returns (bytes32) {
        return keccak256(
            bytes.concat(
                abi.encode(
                    StreamFinalityDomains.SANCTION_SUBJECT_DOMAIN,
                    block.chainid,
                    core_,
                    address(this),
                    uint8(scope.scopeType),
                    scope.collectionId,
                    scope.tokenId
                ),
                abi.encode(
                    scope.scopeId,
                    coreFactsHash,
                    nonSanctionComponentsHash,
                    manifest.uriHash,
                    manifest.contentHash,
                    manifest.schemaId,
                    manifest.canonicalizationHash
                )
            )
        );
    }

    function contentRootSubject(address core_, StreamFinalityScope memory scope)
        public
        view
        returns (bytes32)
    {
        if (scope.scopeType == StreamFinalityScopeType.COLLECTION) {
            return keccak256(
                abi.encode(
                    StreamFinalityDomains.STREAM_SUBJECT_COLLECTION_V1,
                    block.chainid,
                    core_,
                    scope.collectionId
                )
            );
        }
        if (scope.scopeType == StreamFinalityScopeType.TOKEN) {
            return keccak256(
                abi.encode(
                    StreamFinalityDomains.STREAM_SUBJECT_TOKEN_V1,
                    block.chainid,
                    core_,
                    scope.tokenId
                )
            );
        }
        return keccak256(
            abi.encode(
                StreamFinalityDomains.STREAM_SUBJECT_SCOPE_V1,
                block.chainid,
                core_,
                scope.collectionId,
                uint8(scope.scopeType),
                scope.scopeId
            )
        );
    }
}
