// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./StreamPreparedNativeSettlementValidation.sol";
import "../mint/StreamPreparedNativeContentPurchaseReads.sol";
import "./StreamPreparedNativeSettlementHash.sol";
import "../../interfaces/stream/mint/IStreamPreparedNativeMint.sol";
import "../../interfaces/stream/revenue/IStreamPreparedNativePrimarySaleSettlement.sol";
import "../../interfaces/stream/core/IStreamCore.sol";

/// @notice Actual active Manager, original admitted sale, Core identity and consumed ledger joins.
library StreamPreparedNativeContentPurchaseValidation {
    error PreparedNativeReadFailed(address target, bytes4 selector);

    function readIntent(address sale, address recorder, bytes32 hash)
        public
        view
        returns (StreamPreparedNativeSettlementTypes.Intent memory intent)
    {
        bytes memory raw = read(
            sale,
            abi.encodeCall(
                IStreamPreparedNativeContentSale.activePreparedNativeContentIntent, (hash)
            ),
            576
        );
        intent = abi.decode(raw, (StreamPreparedNativeSettlementTypes.Intent));
        if (
            keccak256(raw) != keccak256(abi.encode(intent)) || hash == 0
                || StreamPreparedNativeContentHash.intentHash(sale, recorder, intent) != hash
        ) {
            revert IStreamPreparedNativePrimarySaleSettlement.InvalidPreparedNativeSettlement();
        }
    }

    function requireBindings(
        address core,
        address registry,
        address manager,
        address sale,
        address recorder,
        bytes32 recorderHash
    ) public view {
        StreamPreparedNativeSettlementValidation.requireBindings(
            core, registry, manager, sale, recorder, recorderHash
        );
        if (
            abi.decode(
                    read(
                        recorder,
                        abi.encodeWithSelector(
                            bytes4(0x01ffc9a7),
                            type(IStreamPreparedNativeContentPurchaseSettlement).interfaceId
                        ),
                        32
                    ),
                    (uint256)
                ) != 1
        ) revert IStreamPreparedNativePrimarySaleSettlement.InvalidPreparedNativeSettlement();
    }

    function requireIntentFields(
        StreamPreparedNativeSettlementTypes.Facts memory facts,
        StreamPreparedNativeSettlementTypes.Intent memory intent
    ) public pure {
        if (
            intent.collectionId == 0 || intent.collectionId != facts.collectionId
                || intent.phaseId == 0 || intent.phaseId != facts.phaseId || intent.saleId == 0
                || intent.saleNonce == 0 || intent.executor == address(0)
                || intent.payer == address(0) || intent.payer != facts.payer
                || intent.poster == address(0) || intent.beneficiary == address(0)
                || intent.beneficiary != facts.beneficiary || intent.amount == 0
                || intent.primaryPolicyMode > 1 || intent.originalPrimaryPolicyHash == 0
                || intent.executionNonce == 0
                || (intent.authorityMode != 1 && intent.authorityMode != 2)
                || intent.saleAuthorizationDigest == 0 || intent.saleExecutionHash == 0
                || intent.contentSelectionHash == 0 || intent.mintCommitment != facts.mintCommitment
                || intent.boundMintPolicyHash == 0
                || intent.boundMintPolicyHash != facts.boundPolicyHash
                || facts.initialRecipient != facts.saleAdapter || facts.saleAdapter == address(0)
                || facts.mintManager == address(0) || facts.recorder == address(0)
                || facts.recorderCodeHash == 0 || facts.operationRoot == 0 || facts.operationId == 0
                || facts.currentPolicyHash == 0 || facts.intentHash == 0
        ) {
            revert IStreamPreparedNativePrimarySaleSettlement.InvalidPreparedNativeSettlement();
        }
    }

    function requireActive(
        address core,
        address registry,
        StreamPreparedNativeSettlementTypes.Facts memory facts,
        StreamPreparedNativeSettlementTypes.Intent memory intent
    ) public view returns (StreamNativeSettlementTypes.SaleLifecycleBinding memory lifecycle) {
        requireIntentFields(facts, intent);
        StreamPreparedNativeContentPurchaseReads.requireActive(registry, facts, intent);
        lifecycle = StreamPreparedNativeSettlementAdmission.requireAdmission(
            registry, facts.saleAdapter, intent.saleId
        );
        requireBindings(
            core,
            registry,
            facts.mintManager,
            facts.saleAdapter,
            facts.recorder,
            facts.recorderCodeHash
        );
        StreamPreparedNativeSettlementTypes.Intent memory saved =
            readIntent(facts.saleAdapter, facts.recorder, facts.intentHash);
        if (keccak256(abi.encode(saved)) != keccak256(abi.encode(intent))) {
            revert IStreamPreparedNativePrimarySaleSettlement.InvalidPreparedNativeSettlement();
        }
        bytes memory raw = read(
            facts.mintManager,
            abi.encodeCall(IStreamPreparedNativeMint.activePreparedNativeMint, ()),
            576
        );
        if (keccak256(raw) != keccak256(abi.encode(facts))) {
            revert IStreamPreparedNativePrimarySaleSettlement.InvalidPreparedNativeSettlement();
        }
        raw = read(core, abi.encodeCall(IStreamCoreMint.preparedMint, (facts.tokenId)), 96);
        StreamPreparedMintRecord memory prepared = abi.decode(raw, (StreamPreparedMintRecord));
        if (
            !prepared.exists || prepared.operationId != facts.operationId
                || prepared.collectionId != facts.collectionId
                || keccak256(raw) != keccak256(abi.encode(prepared))
                || uint256(word(core, "pendingPreparedMintTokenId()")) != facts.tokenId
                || facts.tokenId == 0
        ) {
            revert IStreamPreparedNativePrimarySaleSettlement.InvalidPreparedNativeSettlement();
        }
        raw = read(
            core, abi.encodeCall(IStreamCoreIdentity.tokenCollectionIdentity, (facts.tokenId)), 128
        );
        (bool exists, uint256 collection, uint256 serial, bool burned) =
            abi.decode(raw, (bool, uint256, uint256, bool));
        if (
            !exists || burned || collection != facts.collectionId
                || serial != facts.collectionSerial
                || keccak256(raw) != keccak256(abi.encode(exists, collection, serial, burned))
        ) {
            revert IStreamPreparedNativePrimarySaleSettlement.InvalidPreparedNativeSettlement();
        }
        raw = read(core, abi.encodeCall(IStreamCoreIdentity.tokenLifecycle, (facts.tokenId)), 32);
        if (abi.decode(raw, (uint256)) != 1) {
            revert IStreamPreparedNativePrimarySaleSettlement.InvalidPreparedNativeSettlement();
        }
        address ledger = addressWord(facts.mintManager, "mintLedger()");
        raw = read(
            ledger,
            abi.encodeCall(
                IStreamMintLedger.isManagerOperationRootUsed,
                (facts.mintManager, facts.operationRoot)
            ),
            32
        );
        if (abi.decode(raw, (uint256)) != 1) {
            revert IStreamPreparedNativePrimarySaleSettlement.InvalidPreparedNativeSettlement();
        }
    }

    /// @dev Exact-code infrastructure and admitted fixed getters only; no remote revert is bubbled.
    function read(address target, bytes memory data, uint256 size)
        internal
        view
        returns (bytes memory raw)
    {
        raw = new bytes(size);
        bool ok;
        uint256 actual;
        assembly ("memory-safe") {
            ok := staticcall(gas(), target, add(data, 32), mload(data), add(raw, 32), size)
            actual := returndatasize()
        }
        if (!ok || actual != size) revert PreparedNativeReadFailed(target, bytes4(data));
    }

    function word(address target, string memory signature) internal view returns (bytes32) {
        return abi.decode(read(target, abi.encodeWithSignature(signature), 32), (bytes32));
    }

    function addressWord(address target, string memory signature) internal view returns (address) {
        uint256 raw = uint256(word(target, signature));
        if (raw > type(uint160).max) {
            revert PreparedNativeReadFailed(target, bytes4(keccak256(bytes(signature))));
        }
        return address(uint160(raw));
    }
}
