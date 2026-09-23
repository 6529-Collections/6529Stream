// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "../../../smart-contracts/interfaces/stream/finality/IStreamArtistRecoveryIntent.sol";

/// @dev Typed recovery producer boundary only. This does not execute recovery or prove its intent serializer.
contract ArtistRecoveryIntentFixture is IStreamArtistRecoveryIntent {
    address public immutable core;
    address public immutable originalFinalityRegistry;
    bytes32 public immutable finalityRecord;
    bytes32 public immutable manifest;

    constructor(address core_, address finality_, bytes32 record_, bytes32 manifest_) {
        core = core_;
        originalFinalityRegistry = finality_;
        finalityRecord = record_;
        manifest = manifest_;
    }

    // Declared primary-module facts are boundary doubles, not an implemented recovery interface.
    function streamModuleType() external pure returns (bytes32) {
        return keccak256("STREAM_ARTWORK_FINALITY_RECOVERY");
    }

    function streamModuleInterfaceId() external pure returns (bytes4) {
        return 0x83685f5c;
    }

    function supportsInterface(bytes4 id) external pure returns (bool) {
        return id == 0x83685f5c || id == 0x01ffc9a7;
    }

    function requireArtistRecoveryIntent(
        StreamFinalityScope calldata scope,
        bytes32 record_,
        bytes32 manifest_
    ) external view returns (Facts memory) {
        require(
            scope.scopeType == StreamFinalityScopeType.COLLECTION && scope.collectionId == 1
                && scope.tokenId == 0 && scope.scopeId == 0 && record_ == finalityRecord
                && manifest_ == manifest,
            "exact unit intent boundary"
        );
        return Facts(
            keccak256(abi.encode(scope)),
            keccak256("old recovery route"),
            keccak256("replacement route"),
            keccak256(abi.encode(scope, record_, manifest_))
        );
    }
}
