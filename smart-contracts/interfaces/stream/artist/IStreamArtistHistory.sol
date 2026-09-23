// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "../../../vendor/openzeppelin/IERC165.sol";
import "./StreamArtistOnboardingTypes.sol";

library StreamArtistHistoryTypes {
    struct Leaf {
        uint8 laneKind;
        bytes32 laneKey;
        uint64 sequence;
        bytes32 recordHash;
        bytes32 recordChainHash;
    }

    struct Binding {
        address predecessorRegistry;
        uint64 snapshotBlock;
        bytes32 importRoot;
        bytes32 manifestHash;
    }

    struct Receipt {
        uint16 operation;
        bytes32 artistId;
        uint256 collectionId;
        bytes32 recordHash;
    }

    struct Context {
        bytes32 scopeHash;
        bytes32 oldValueHash;
        bytes32 newValueHash;
    }
}

/// @notice Canonical native lanes and the original operation55/56/57 import admission surface.
/// @dev A verified tip or member is history evidence, never an imported authority installation.
interface IStreamArtistHistory is IERC165 {
    event ArtistHistoryImportRootCommitted(
        uint16 schemaVersion,
        address indexed predecessorRegistry,
        bytes32 indexed importRoot,
        uint64 snapshotBlock,
        bytes32 manifestHash,
        bytes32 governanceActionId
    );
    event ArtistHistoryLaneVerified(
        uint16 schemaVersion,
        uint8 indexed laneKind,
        bytes32 indexed laneKey,
        uint256 bindingIndex,
        bytes32 laneTip,
        uint64 recordCount
    );
    event ArtistRegistryCutoverObserved(
        uint16 schemaVersion, address indexed successorTarget, uint64 observedAt
    );

    function artistRecordChainHash(bytes32 artistId) external view returns (bytes32);
    function collectionRecordChainHash(uint256 collectionId) external view returns (bytes32);
    function artistHistoryLane(uint8 kind, bytes32 key)
        external
        view
        returns (bytes32 tip, uint64 count);
    function artistHistoryRecordAt(uint8 kind, bytes32 key, uint64 index)
        external
        view
        returns (bytes32 recordHash, bytes32 chainHash);
    function commitArtistHistoryImportRoot(
        address predecessorRegistry,
        uint64 snapshotBlock,
        bytes32 importRoot,
        bytes32 manifestHash
    ) external;
    function artistHistoryImportContext(
        address predecessorRegistry,
        uint64 snapshotBlock,
        bytes32 importRoot,
        bytes32 manifestHash
    ) external view returns (StreamArtistHistoryTypes.Context memory);
    function importedHistoryBinding(uint256 index)
        external
        view
        returns (
            address predecessorRegistry,
            uint64 snapshotBlock,
            bytes32 importRoot,
            bytes32 manifestHash
        );
    function importedHistoryBindingCount() external view returns (uint256);
    function artistHistoryPredecessorBinding(address predecessorRegistry)
        external
        view
        returns (bool committed, bytes32 predecessorCodeHash, uint256 bindingCount);
    function verifyImportedRecord(
        bytes32 importRoot,
        StreamArtistHistoryTypes.Leaf calldata leaf,
        bytes32[] calldata proof
    ) external view returns (bool);
    function verifyImportedLaneTip(
        uint256 bindingIndex,
        StreamArtistHistoryTypes.Leaf calldata tipLeaf,
        bytes32[] calldata proof
    ) external;
    function importedLaneVerified(uint8 kind, bytes32 key)
        external
        view
        returns (bool verified, bytes32 laneTip, uint64 recordCount);
    function observeRegistryCutover() external;
    function artistRegistryCutover()
        external
        view
        returns (bool observed, address successor, uint64 blockNumber);
    function artistHistoryContinuityCommitment() external view returns (bytes32);
}

interface IStreamArtistNativeReceipts {
    function artistNativeReceiptCount() external view returns (uint256);
    function artistNativeReceiptAt(uint256 index)
        external
        view
        returns (StreamArtistHistoryTypes.Receipt memory);
}

interface IStreamArtistHistoryOwner {
    function syncArtistNativeHistory(
        address source,
        uint256 first,
        StreamArtistHistoryTypes.Receipt[] calldata rows
    ) external;
    function artistHistorySourceCursor(address source) external view returns (uint256);
    function applyArtistHistoryImport(
        StreamArtistOnboardingTypes.ActionContext calldata c,
        StreamArtistHistoryTypes.Binding calldata binding_,
        bytes32 actionId
    ) external;
    function applyArtistHistoryLaneVerification(
        StreamArtistOnboardingTypes.ActionContext calldata c,
        uint256 index,
        StreamArtistHistoryTypes.Leaf calldata leaf,
        bytes32[] calldata proof
    ) external;
    function applyArtistRegistryCutover(StreamArtistOnboardingTypes.ActionContext calldata c)
        external;
}

interface IStreamArtistHistoryCoordinator {
    function coordinateCommitArtistHistoryImportRoot(
        address actor,
        StreamArtistHistoryTypes.Binding calldata binding_
    ) external;
    function coordinateVerifyImportedLaneTip(
        address actor,
        uint256 index,
        StreamArtistHistoryTypes.Leaf calldata leaf,
        bytes32[] calldata proof
    ) external;
    function coordinateObserveRegistryCutover(address actor) external;
}
