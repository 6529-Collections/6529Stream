// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import { StreamEntropyStatus } from "../../interfaces/stream/entropy/IStreamEntropyView.sol";
import "./StreamEntropyCoordinator.sol";
import { IStreamCore } from "../../interfaces/stream/core/IStreamCore.sol";
import { IStreamRevealFeeEscrow } from "../../interfaces/stream/entropy/IStreamRevealFeeEscrow.sol";
import { IStreamCorePointers } from "../../interfaces/stream/core/IStreamCorePointers.sol";

/// @notice Original scope registration, with current-selection admission for new subjects only.
library StreamEntropyScopeRegistration {
    bytes32 private constant SCOPE_DOMAIN = keccak256("6529STREAM_ENTROPY_SCOPE_SUBJECT_V1");
    event EntropyScopeRegistered(
        uint256 indexed collectionId, bytes32 indexed scopeId, uint8 scopeKind, bytes32 scopeRef
    );

    function register(
        IStreamCore core,
        address authority,
        mapping(address => bool) storage requesters,
        mapping(bytes32 => StreamEntropyCoordinator.Subject) storage _subjects,
        mapping(bytes32 => bool) storage _registeredScopes,
        mapping(uint256 => StreamEntropyCoordinator.CollectionConfig) storage configs,
        mapping(uint256 => IStreamRevealFeeEscrow.CollectionRevealPolicy) storage policies,
        uint256 collectionId,
        uint8 scopeKind,
        bytes32 scopeRef
    ) public returns (bytes32 scopeId) {
        if (msg.sender != authority && !requesters[msg.sender]) {
            revert StreamEntropyCoordinator.Unauthorized(msg.sender);
        }
        if (scopeKind > 2 || scopeRef == 0 || !core.collectionExists(collectionId)) {
            revert StreamEntropyCoordinator.InvalidCollection(collectionId);
        }
        scopeId = keccak256(
            abi.encode(
                SCOPE_DOMAIN,
                block.chainid,
                address(this),
                address(core),
                collectionId,
                scopeKind,
                scopeRef
            )
        );
        if (_subjects[scopeId].status != StreamEntropyStatus.NONE) {
            revert StreamEntropyCoordinator.InvalidSubject(scopeId);
        }
        (address selected, bytes32 codeHash,,,,,,,,) =
            IStreamCorePointers(address(core)).getSatellitePointer(keccak256("ENTROPY_COORDINATOR"));
        if (selected != address(this) || codeHash != address(this).codehash) {
            revert StreamEntropyCoordinator.InvalidCollection(collectionId);
        }
        if (configs[collectionId].provider == address(0)) {
            revert StreamEntropyCoordinator.InvalidCollection(collectionId);
        }
        if (!policies[collectionId].declared) {
            revert StreamEntropyCoordinator.RevealPolicyUndeclared(collectionId);
        }
        configs[collectionId].locked = true;
        _registeredScopes[scopeId] = true;
        _subjects[scopeId].collectionId = collectionId;
        _subjects[scopeId].status = StreamEntropyStatus.REGISTERED;
        emit EntropyScopeRegistered(collectionId, scopeId, scopeKind, scopeRef);
    }

    event EntropyRegistered(
        uint256 indexed collectionId, uint256 indexed tokenId, bytes32 mintCommitment
    );

    /// @notice Original only-Core token hook; sender, identity, policy, writes and event order retained.
    function token(
        IStreamCore core,
        mapping(bytes32 => StreamEntropyCoordinator.Subject) storage _subjects,
        mapping(
            uint256 => StreamEntropyCoordinator.CollectionConfig
        ) storage collectionEntropyConfig,
        mapping(
            uint256 => IStreamRevealFeeEscrow.CollectionRevealPolicy
        ) storage _revealPolicies,
        mapping(uint256 => uint64) storage registeredAtBlock,
        mapping(uint256 => uint256) storage nonterminalTokenCount,
        bytes calldata data
    ) public {
        (uint256 collectionId, uint256 tokenId, address recipient, bytes32 mintCommitment) =
            abi.decode(data, (uint256, uint256, address, bytes32));
        if (msg.sender != address(core)) revert StreamEntropyCoordinator.Unauthorized(msg.sender);
        (bool exists, uint256 actualCollection,, bool burned) =
            core.tokenCollectionIdentity(tokenId);
        if (
            !exists || burned || actualCollection != collectionId || recipient == address(0)
                || core.coordinatorAtMint(tokenId) != address(this)
        ) revert StreamEntropyCoordinator.InvalidToken(tokenId);
        bytes32 key = keccak256(abi.encode("TOKEN", tokenId));
        if (_subjects[key].status != StreamEntropyStatus.NONE) {
            revert StreamEntropyCoordinator.InvalidSubject(key);
        }
        StreamEntropyCoordinator.CollectionConfig storage config =
            collectionEntropyConfig[collectionId];
        if (config.provider == address(0)) {
            revert StreamEntropyCoordinator.InvalidCollection(collectionId);
        }
        if (!_revealPolicies[collectionId].declared) {
            revert StreamEntropyCoordinator.RevealPolicyUndeclared(collectionId);
        }
        config.locked = true;
        _subjects[key].collectionId = collectionId;
        _subjects[key].inputsHash = mintCommitment;
        _subjects[key].status = StreamEntropyStatus.REGISTERED;
        if (block.number > type(uint64).max) {
            revert StreamEntropyCoordinator.EntropyBlockNumberOverflow();
        }
        registeredAtBlock[tokenId] = uint64(block.number);
        ++nonterminalTokenCount[collectionId];
        emit EntropyRegistered(collectionId, tokenId, mintCommitment);
    }
}
