// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../../smart-contracts/domains/artist/StreamArtistRecoveryOriginalReads.sol";

/// @dev Mutable exact historical-return boundary, not a finality ceremony or Consent authority.
contract RecoveryOriginalRecordFixture {
    address public immutable coreReads;
    address public immutable sanctionReads;
    address public constant artifactCoverage = address(0xA47);
    mapping(bytes32 => StreamScopedFinalityRecord) private records;
    mapping(bytes32 => StreamFinalityComponentExpectation[]) private components;
    mapping(bytes32 => S.Record) private sanctions;
    mapping(bytes32 => StreamFinalityExecutionWitness) private executions;
    mapping(bytes32 => StreamFinalitySanctionArchiveWitness) private archives;

    constructor(address core_, address artist_) {
        coreReads = core_;
        sanctionReads = artist_;
    }

    function key(StreamFinalityScope memory scope) public pure returns (bytes32) {
        return keccak256(abi.encode(scope));
    }

    function set(
        StreamFinalityScope calldata scope,
        bytes32 hash,
        S.Record calldata sanction,
        StreamFinalityComponentExpectation[] calldata items
    ) external {
        bytes32 k = key(scope);
        delete components[k];
        for (uint256 i; i < items.length; ++i) {
            components[k].push(items[i]);
        }
        records[k] = StreamScopedFinalityRecord(
            true,
            scope,
            hash,
            keccak256("immutable manifest bytes"),
            keccak256("urn:original"),
            keccak256(abi.encode(StreamFinalityDomains.STREAM_FINALITY_COMPONENTS_V1, items)),
            "urn:original",
            address(this),
            1000
        );
        sanctions[sanction.recordHash] = sanction;
        executions[hash] = StreamFinalityExecutionWitness(
            keccak256(abi.encode("executed action", hash)),
            address(0xA1),
            keccak256("reason"),
            keccak256("role mutation"),
            1
        );
        StreamFinalitySanctionArchiveProof memory proof = StreamFinalitySanctionArchiveProof(
            sanction.recordHash, keccak256("whole archive artifact"), keccak256("stable completion")
        );
        archives[hash] = StreamFinalitySanctionArchiveWitness(
            keccak256(
                abi.encode(
                    keccak256("6529STREAM_FINALITY_SANCTION_ARCHIVE_EVIDENCE_V1"),
                    block.chainid,
                    coreReads,
                    address(this),
                    artifactCoverage,
                    proof
                )
            ),
            proof
        );
    }

    function sanctionRecord(bytes32 hash) external view returns (S.Record memory) {
        return sanctions[hash];
    }

    function finalityExecutionWitness(bytes32 hash)
        external
        view
        returns (StreamFinalityExecutionWitness memory)
    {
        return executions[hash];
    }

    function finalitySanctionArchiveWitness(bytes32 hash)
        external
        view
        returns (StreamFinalitySanctionArchiveWitness memory)
    {
        return archives[hash];
    }

    function _collection(uint256 id) private pure returns (StreamFinalityScope memory) {
        return StreamFinalityScope(StreamFinalityScopeType.COLLECTION, id, 0, 0);
    }

    function collectionFinalityRecord(uint256 id)
        external
        view
        returns (StreamCollectionFinalityRecord memory out)
    {
        StreamScopedFinalityRecord storage r = records[key(_collection(id))];
        if (!r.finalized) return out;
        return StreamCollectionFinalityRecord(
            true,
            r.finalityRecordHash,
            r.manifestContentHash,
            r.manifestURIHash,
            r.finalityManifestURI,
            r.componentsHash,
            r.manifestPointer,
            r.finalizedAt
        );
    }

    function artworkScopeFinalityRecord(StreamFinalityScope calldata scope)
        external
        view
        returns (StreamScopedFinalityRecord memory)
    {
        return records[key(scope)];
    }

    function finalityComponentCount(uint256 id) external view returns (uint256) {
        return components[key(_collection(id))].length;
    }

    function finalityComponentCountForScope(StreamFinalityScope calldata scope)
        external
        view
        returns (uint256)
    {
        return components[key(scope)].length;
    }

    function _items(bytes32 k, uint256 start, uint256 count)
        private
        view
        returns (StreamFinalityComponentExpectation[] memory result)
    {
        result = new StreamFinalityComponentExpectation[](count);
        for (uint256 i; i < count; ++i) {
            result[i] = components[k][start + i];
        }
    }

    function finalityComponents(uint256 id, uint256 start, uint256 count)
        external
        view
        returns (StreamFinalityComponentExpectation[] memory)
    {
        return _items(key(_collection(id)), start, count);
    }

    function finalityComponentsForScope(
        StreamFinalityScope calldata scope,
        uint256 start,
        uint256 count
    ) external view returns (StreamFinalityComponentExpectation[] memory) {
        return _items(key(scope), start, count);
    }

    function frozenRouteForScope(bytes32 kind, StreamFinalityScope calldata scope)
        external
        view
        returns (bool, address, bytes32, bytes32)
    {
        bytes32 k = key(scope);
        bytes32 hash = records[k].finalityRecordHash;
        for (uint256 i; i < components[k].length; ++i) {
            StreamFinalityComponentExpectation memory r = components[k][i];
            if (r.componentType == kind) return (true, r.component, keccak256(abi.encode(r)), hash);
        }
        return (false, address(0), bytes32(0), hash);
    }
}
