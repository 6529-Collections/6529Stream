// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./StreamMintCounterPolicy.sol";
import "./StreamMintOperationIdentity.sol";
import "../../interfaces/stream/mint/IStreamMintManagerImport.sol";
import "../../interfaces/stream/parameters/IStreamGovernedParameterAuthority.sol";

/// @notice Fixed subject derivation and governed snapshot authentication for Ledger/Manager succession.
library StreamMintImport {
    bytes32 internal constant COUNTER_DOMAIN = keccak256("6529STREAM_MINT_COUNTER_IMPORT_LEAF_V1");
    bytes32 internal constant NULLIFIER_DOMAIN =
        keccak256("6529STREAM_MINT_NULLIFIER_IMPORT_LEAF_V1");
    bytes32 internal constant MANIFEST_DOMAIN =
        keccak256("6529STREAM_MINT_IMPORT_MANIFEST_LEAF_V1");
    bytes32 internal constant SCOPE_DOMAIN = keccak256("6529STREAM_MINT_IMPORT_SCOPE_V1");
    bytes32 internal constant COMMITMENT_DOMAIN = keccak256("6529STREAM_MINT_IMPORT_COMMITMENT_V1");

    function requireManagerPair(
        address predecessorLedger,
        address predecessor,
        address successor,
        address authority
    ) public view {
        if (
            _addressRead(predecessor, bytes4(keccak256("mintLedger()"))) != predecessorLedger
                || _addressRead(successor, bytes4(keccak256("mintLedger()"))) != address(this)
                || _addressRead(successor, bytes4(keccak256("governanceAuthority()"))) != authority
                || _addressRead(predecessor, bytes4(keccak256("core()")))
                    != _addressRead(successor, bytes4(keccak256("core()")))
        ) {
            revert IStreamMintLedgerImport.MintImportInvalid();
        }
    }

    function _addressRead(address target, bytes4 selector) private view returns (address result) {
        bytes memory input = abi.encodeWithSelector(selector);
        bool ok;
        uint256 size;
        uint256 word;
        assembly ("memory-safe") {
            ok := staticcall(30000, target, add(input, 32), mload(input), 0, 32)
            size := returndatasize()
            word := mload(0)
        }
        if (!ok || size != 32 || word == 0 || word > type(uint160).max) {
            revert IStreamMintLedgerImport.MintImportInvalid();
        }
        return address(uint160(word));
    }

    function subject(address ledger, IStreamMintLedgerImport.CounterImportLeaf memory leaf)
        public
        view
        returns (bytes32)
    {
        if (
            leaf.counterId == 0 || leaf.keyMode == 0
                || leaf.keyMode > uint8(IStreamMintManager.CounterKeyMode.CONTEXT)
                || (leaf.collectionId == 0 && leaf.phaseId != 0)
        ) revert IStreamMintLedgerImport.MintImportInvalid();
        IStreamMintManager.CounterKeyMode mode = IStreamMintManager.CounterKeyMode(leaf.keyMode);
        StreamMintOperationIdentity.SubjectContext memory c;
        c.chainId = block.chainid;
        c.ledger = ledger;
        c.collectionId = leaf.collectionId;
        c.phaseId = leaf.phaseId;
        c.counterId = leaf.counterId;
        if (mode == IStreamMintManager.CounterKeyMode.CONSTANT) {
            if (leaf.subjectBasis != 0) revert IStreamMintLedgerImport.MintImportInvalid();
        } else if (mode == IStreamMintManager.CounterKeyMode.CONTEXT) {
            if (leaf.subjectBasis == 0) revert IStreamMintLedgerImport.MintImportInvalid();
            c.contextHash = leaf.subjectBasis;
        } else {
            if (uint256(leaf.subjectBasis) == 0 || uint256(leaf.subjectBasis) > type(uint160).max) {
                revert IStreamMintLedgerImport.MintImportInvalid();
            }
            address account = address(uint160(uint256(leaf.subjectBasis)));
            c.payer = account;
            c.recipient = account;
            c.executor = account;
            c.authorizer = account;
        }
        return StreamMintOperationIdentity.subjectKey(mode, c);
    }

    function counterLeaf(
        IStreamMintLedgerImport.ImportCommitment memory c,
        IStreamMintLedgerImport.CounterImportLeaf memory leaf
    ) public view returns (bytes32) {
        return keccak256(
            bytes.concat(
                keccak256(
                    abi.encode(
                        COUNTER_DOMAIN,
                        block.chainid,
                        c.predecessorLedger,
                        c.predecessorManager,
                        leaf
                    )
                )
            )
        );
    }

    function nullifierLeaf(IStreamMintLedgerImport.ImportCommitment memory c, bytes32 nullifier)
        public
        view
        returns (bytes32)
    {
        return keccak256(
            bytes.concat(
                keccak256(
                    abi.encode(
                        NULLIFIER_DOMAIN,
                        block.chainid,
                        c.predecessorLedger,
                        c.predecessorManager,
                        nullifier
                    )
                )
            )
        );
    }

    function descriptorLeaf(
        IStreamMintLedgerImport.ImportCommitment memory c,
        uint64 counters,
        uint64 nullifiers
    ) public view returns (bytes32) {
        return keccak256(
            bytes.concat(
                keccak256(
                    abi.encode(
                        MANIFEST_DOMAIN,
                        block.chainid,
                        address(this),
                        c.predecessorLedger,
                        c.predecessorManager,
                        c.successorManager,
                        c.snapshotBlock,
                        c.manifestHash,
                        counters,
                        nullifiers
                    )
                )
            )
        );
    }

    function authenticateCommit(
        address authority,
        IStreamMintLedgerImport.ImportCommitment memory c,
        bytes32 root
    ) public view returns (bytes32 actionId) {
        bytes32 scope = keccak256(
            abi.encode(SCOPE_DOMAIN, block.chainid, address(this), c.successorManager)
        );
        bytes32 expected = keccak256(
            abi.encode(
                COMMITMENT_DOMAIN,
                scope,
                c.predecessorLedger,
                c.predecessorManager,
                c.successorManager,
                c.snapshotBlock,
                root,
                c.manifestHash
            )
        );
        bytes memory input = abi.encodeCall(IStreamGovernedParameterAuthority.currentAction, ());
        bytes memory result = new bytes(192);
        bool ok;
        uint256 size;
        assembly ("memory-safe") {
            ok := staticcall(100000, authority, add(input, 32), mload(input), add(result, 32), 192)
            size := returndatasize()
        }
        if (!ok || size != 192) revert IStreamMintLedgerImport.MintImportGovernanceInvalid();
        (
            bool executing,
            bytes32 id,
            uint8 cls,
            bytes32 suppliedScope,
            bytes32 oldHash,
            bytes32 newHash
        ) = abi.decode(result, (bool, bytes32, uint8, bytes32, bytes32, bytes32));
        if (
            !executing || id == 0 || cls != 1 || suppliedScope != scope || oldHash != bytes32(0)
                || newHash != expected
        ) {
            revert IStreamMintLedgerImport.MintImportGovernanceInvalid();
        }
        return id;
    }

    function forward(address ledger, bytes calldata encoded) external {
        IStreamMintManagerImport.ImportBatch memory b =
            abi.decode(encoded, (IStreamMintManagerImport.ImportBatch));
        if (
            b.counters.length + b.nullifiers.length == 0
                || b.counters.length + b.nullifiers.length > 32
                || b.counters.length != b.counterProofs.length
                || b.nullifiers.length != b.nullifierProofs.length
        ) revert IStreamMintLedgerImport.MintImportInvalid();
        for (uint256 i; i < b.counters.length; ++i) {
            IStreamMintLedgerImport(ledger)
                .importCounterValue(
                    b.importRoot, b.counters[i], subject(ledger, b.counters[i]), b.counterProofs[i]
                );
        }
        for (uint256 i; i < b.nullifiers.length; ++i) {
            IStreamMintLedgerImport(ledger)
                .importNullifier(b.importRoot, b.nullifiers[i], b.nullifierProofs[i]);
        }
    }
}
