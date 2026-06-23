// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./IStreamSplitWallet.sol";
import "./Math.sol";
import "./ReentrancyGuard.sol";

/// @notice Pull-payment split wallet for one immutable split profile.
contract StreamSplitWallet is IStreamSplitWallet, ReentrancyGuard {
    /// @notice Parts-per-million denominator for split shares.
    uint32 public constant SHARE_DENOMINATOR_PPM = 1_000_000;
    /// @notice Factory that deployed this wallet and is allowed to initialize it once.
    address public factory;
    /// @notice Whether the factory has initialized the immutable split profile.
    bool public initialized;
    /// @notice Profile identifier that binds wallet code, entries, metadata, chain, and factory.
    bytes32 public profileId;
    /// @notice Canonical hash of the split entries used to initialize this wallet.
    bytes32 public entriesHash;
    /// @notice Hash of the off-chain profile metadata URI for catalogue and provenance material.
    bytes32 public metadataURIHash;

    SplitEntry[] private _entries;
    address[] private _uniqueAccounts;
    /// @notice Aggregate parts-per-million share for a unique account across all labels.
    mapping(address => uint32) public aggregateSharePpm;
    /// @notice Amount released for an account by asset address.
    mapping(address => mapping(address => uint256)) public accountReleased;
    /// @notice Total amount released by asset address.
    mapping(address => uint256) public totalReleased;
    /// @notice Whether an asset observation has emitted its initialization event.
    mapping(address => bool) public assetObservationInitialized;
    /// @notice Last observed cumulative receipts value recorded through syncAsset or release.
    mapping(address => uint256) public lastObservedReceived;

    constructor() {
        factory = msg.sender;
    }

    /// @notice Accepts native ETH receipts passively for later pull release.
    receive() external payable { }

    /// @notice Initializes the wallet with immutable entries and aggregate account shares.
    function initialize(
        bytes32 profileId_,
        bytes32 entriesHash_,
        bytes32 metadataURIHash_,
        SplitEntry[] calldata entries_,
        address[] calldata accounts_,
        uint32[] calldata aggregateSharePpm_
    ) external {
        if (msg.sender != factory) {
            revert UnauthorizedInitializer(msg.sender);
        }
        if (initialized) {
            revert AlreadyInitialized();
        }
        if (entries_.length == 0 || accounts_.length == 0) {
            revert InvalidInitializationInput();
        }
        if (accounts_.length != aggregateSharePpm_.length) {
            revert InvalidInitializationInput();
        }
        if (keccak256(abi.encode(entries_)) != entriesHash_) {
            revert InvalidInitializationInput();
        }

        initialized = true;
        profileId = profileId_;
        entriesHash = entriesHash_;
        metadataURIHash = metadataURIHash_;

        uint256 entryTotal = 0;
        uint256 aggregateTotal = 0;
        for (uint256 i = 0; i < entries_.length; i++) {
            if (entries_[i].account == address(0) || entries_[i].sharePpm == 0) {
                revert InvalidInitializationInput();
            }
            entryTotal += entries_[i].sharePpm;
            _entries.push(entries_[i]);
        }
        for (uint256 i = 0; i < accounts_.length; i++) {
            address account = accounts_[i];
            uint32 sharePpm = aggregateSharePpm_[i];
            if (account == address(0) || sharePpm == 0 || aggregateSharePpm[account] != 0) {
                revert InvalidInitializationInput();
            }
            uint256 expectedSharePpm = 0;
            for (uint256 j = 0; j < entries_.length; j++) {
                if (entries_[j].account == account) {
                    expectedSharePpm += entries_[j].sharePpm;
                }
            }
            if (expectedSharePpm != sharePpm) {
                revert InvalidInitializationInput();
            }
            _uniqueAccounts.push(account);
            aggregateSharePpm[account] = sharePpm;
            aggregateTotal += sharePpm;
        }
        if (entryTotal != SHARE_DENOMINATOR_PPM) {
            revert InvalidInitializationInput();
        }
        if (aggregateTotal != SHARE_DENOMINATOR_PPM) {
            revert InvalidInitializationInput();
        }
    }

    /// @notice Returns the number of canonical label-level split entries.
    function entryCount() external view returns (uint256) {
        return _entries.length;
    }

    /// @notice Returns one canonical label-level split entry.
    function entry(uint256 index)
        external
        view
        returns (address account, uint32 sharePpm, bytes32 labelId)
    {
        SplitEntry storage splitEntry = _entries[index];
        return (splitEntry.account, splitEntry.sharePpm, splitEntry.labelId);
    }

    /// @notice Returns the number of unique accounts after label shares are aggregated.
    function uniqueAccountCount() external view returns (uint256) {
        return _uniqueAccounts.length;
    }

    /// @notice Returns one unique account and its aggregate share by sorted account index.
    function uniqueAccount(uint256 index) external view returns (address account, uint32 sharePpm) {
        account = _uniqueAccounts[index];
        sharePpm = aggregateSharePpm[account];
    }

    /// @notice Returns cumulative native receipts observed as current balance plus released funds.
    function observedReceived(address asset) public view returns (uint256) {
        _requireNativeAsset(asset);
        return address(this).balance + totalReleased[asset];
    }

    /// @notice Returns the currently releasable native amount for an account.
    function releasable(address asset, address account) public view returns (uint256) {
        uint32 sharePpm = aggregateSharePpm[account];
        if (sharePpm == 0) {
            _requireNativeAsset(asset);
            return 0;
        }

        uint256 entitlement = Math.mulDiv(observedReceived(asset), sharePpm, SHARE_DENOMINATOR_PPM);
        uint256 released = accountReleased[asset][account];
        if (entitlement <= released) {
            return 0;
        }
        return entitlement - released;
    }

    /// @notice Returns unreleasable native dust caused by integer division rounding.
    function roundingDust(address asset) external view returns (uint256) {
        _requireNativeAsset(asset);
        uint256 totalReleasable = 0;
        for (uint256 i = 0; i < _uniqueAccounts.length; i++) {
            totalReleasable += releasable(asset, _uniqueAccounts[i]);
        }
        if (totalReleasable >= address(this).balance) {
            return 0;
        }
        return address(this).balance - totalReleasable;
    }

    /// @notice Emits the current cumulative receipt observation for the native asset.
    function syncAsset(address asset) external nonReentrant returns (uint256 observed) {
        observed = observedReceived(asset);
        _recordObservation(asset, observed);
    }

    /// @notice Pulls releasable native funds for an account to that account or its chosen recipient.
    function release(address asset, address account, address payable recipient)
        external
        nonReentrant
        returns (uint256 amount)
    {
        _requireNativeAsset(asset);
        if (recipient == address(0)) {
            revert ZeroRecipient();
        }
        if (recipient != account && msg.sender != account) {
            revert UnauthorizedReleaseRecipient(msg.sender, account, recipient);
        }

        uint256 observed = observedReceived(asset);
        amount = releasable(asset, account);
        if (amount == 0) {
            revert NoReleasableFunds(asset, account);
        }

        accountReleased[asset][account] += amount;
        totalReleased[asset] += amount;

        (bool success,) = recipient.call{ value: amount }("");
        if (!success) {
            revert NativeTransferFailed(recipient, amount);
        }

        uint256 postTransferObserved = observedReceived(asset);
        if (postTransferObserved != observed) {
            revert NativeReceiptInvariantBroken(observed, postTransferObserved);
        }
        _recordObservation(asset, observed);

        emit NativeReleased(profileId, account, recipient, amount, totalReleased[asset], observed);
    }

    function _recordObservation(address asset, uint256 observed) private {
        if (!assetObservationInitialized[asset]) {
            assetObservationInitialized[asset] = true;
            lastObservedReceived[asset] = observed;
            emit AssetObservationInitialized(profileId, asset, observed);
            return;
        }

        uint256 previous = lastObservedReceived[asset];
        if (observed < previous) {
            revert ObservedReceiptsDecreased(asset, previous, observed);
        }
        if (observed == previous) {
            return;
        }
        lastObservedReceived[asset] = observed;
        emit AssetSynced(profileId, asset, previous, observed);
    }

    function _requireNativeAsset(address asset) private pure {
        if (asset != address(0)) {
            revert UnsupportedAsset(asset);
        }
    }
}
