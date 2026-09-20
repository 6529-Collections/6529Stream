// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../../interfaces/stream/entropy/IStreamInstantEntropyProvider.sol";
import "../../interfaces/stream/entropy/IStreamInstantEntropyProviderIdentity.sol";

/// @notice Optional LOW_SECURITY previous-block adapter, excluded from the genesis provider set.
/// @dev Publicly predictable and susceptible to validator influence and request-timing selection.
/// No external calls, mutable storage, callback, payment or production test mode exists.
contract StreamEntropyProviderInstant is
    IStreamInstantEntropyProvider,
    IStreamInstantEntropyProviderIdentity
{
    bytes32 public constant ASSUMPTIONS_HASH = keccak256(
        "LOW_SECURITY: previous-block hash; validator influence; publicly simulatable; request-timing selection; not VRF; mintCommitment excluded"
    );
    bytes32 public constant RAW_DOMAIN = keccak256("6529STREAM_INSTANT_BLOCKHASH_RAW_V1");
    bytes32 public constant PROVENANCE_DOMAIN =
        keccak256("6529STREAM_INSTANT_BLOCKHASH_PROVENANCE_V1");
    address public immutable coordinator;
    bytes32 private immutable _configHash;

    error InvalidCoordinator();
    error InvalidInstantRequest();
    event InstantEntropyAssumptions(
        uint16 schemaVersion, InstantMode mode, bytes32 assumptionsHash
    );

    constructor(address coordinator_) {
        if (coordinator_ == address(0)) revert InvalidCoordinator();
        coordinator = coordinator_;
        _configHash = keccak256(
            abi.encode(
                keccak256("6529STREAM_INSTANT_BLOCKHASH_CONFIG_V1"),
                coordinator_,
                InstantMode.DELAYED_BLOCKHASH,
                ASSUMPTIONS_HASH
            )
        );
        emit InstantEntropyAssumptions(1, InstantMode.DELAYED_BLOCKHASH, ASSUMPTIONS_HASH);
    }

    function supportsInterface(bytes4 id) external pure override returns (bool) {
        return id == type(IERC165).interfaceId
            || id == type(IStreamInstantEntropyProvider).interfaceId
            || id == type(IStreamInstantEntropyProviderIdentity).interfaceId;
    }

    function isStreamInstantEntropyProvider() external pure override returns (bool) {
        return true;
    }

    function streamEntropyProviderFamily() external pure override returns (bytes32) {
        return keccak256("STREAM_INSTANT_DELAYED_BLOCKHASH");
    }

    function streamEntropyProviderVersion() external pure override returns (bytes32) {
        return keccak256("6529stream.entropy-provider-instant-blockhash.v1");
    }

    function streamEntropyProviderConfigHash() external view override returns (bytes32) {
        return _configHash;
    }

    function instantEntropyProfile() external pure override returns (InstantMode, bytes32) {
        return (InstantMode.DELAYED_BLOCKHASH, ASSUMPTIONS_HASH);
    }

    function instantEntropy(bytes32 requestKey, bytes calldata context)
        external
        view
        override
        returns (bytes32 rawRandomness, bytes32 provenanceHash)
    {
        if (msg.sender != coordinator || requestKey == 0 || block.number == 0) {
            revert InvalidInstantRequest();
        }
        uint256 sourceBlock = block.number - 1;
        bytes32 sourceHash = blockhash(sourceBlock);
        bytes32 contextHash = keccak256(context);
        rawRandomness =
            keccak256(abi.encode(RAW_DOMAIN, requestKey, contextHash, sourceBlock, sourceHash));
        provenanceHash = keccak256(
            abi.encode(
                PROVENANCE_DOMAIN,
                _configHash,
                requestKey,
                contextHash,
                sourceBlock,
                sourceHash,
                ASSUMPTIONS_HASH
            )
        );
    }
}
