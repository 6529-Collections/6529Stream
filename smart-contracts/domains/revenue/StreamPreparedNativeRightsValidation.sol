// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "./StreamPreparedNativeSettlementValidation.sol";
import "./StreamPreparedNativeRightsHash.sol";
import "../../interfaces/stream/mint/IStreamPreparedNativeRightsMint.sol";
import "../../interfaces/stream/revenue/IStreamPreparedNativeRightsPrimarySettlement.sol";

/// @notice Original authority and actual Core preparation joins for the distinct rights entry.
library StreamPreparedNativeRightsValidation {
    function readIntent(address sale, address recorder, bytes32 hash)
        public
        view
        returns (StreamPreparedNativeRightsTypes.Intent memory intent)
    {
        bytes memory raw = StreamPreparedNativeSettlementValidation.read(
            sale,
            abi.encodeCall(
                IStreamPreparedNativeRightsSaleBinding.activePreparedNativeRightsIntent, (hash)
            ),
            672
        );
        intent = abi.decode(raw, (StreamPreparedNativeRightsTypes.Intent));
        if (
            hash == 0 || keccak256(raw) != keccak256(abi.encode(intent))
                || StreamPreparedNativeRightsHash.intentHash(sale, recorder, intent) != hash
        ) {
            revert IStreamPreparedNativeRightsPrimarySettlement.InvalidPreparedNativeRights();
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
        bytes memory raw = StreamPreparedNativeSettlementValidation.read(
            recorder,
            abi.encodeWithSelector(
                bytes4(0x01ffc9a7), type(IStreamPreparedNativeRightsPrimarySettlement).interfaceId
            ),
            32
        );
        if (abi.decode(raw, (uint256)) != 1) {
            revert IStreamPreparedNativeRightsPrimarySettlement.InvalidPreparedNativeRights();
        }
    }

    function requireIntentFields(
        StreamPreparedNativeRightsTypes.Facts memory facts,
        StreamPreparedNativeRightsTypes.Intent memory intent
    ) public pure {
        if (
            intent.original.mode != StreamPreparedNativeRightsTypes.COLLECTION_TEMPLATE
                || intent.original.assignmentHash == 0 || intent.original.templateId == 0
                || keccak256(abi.encode(facts.original)) != keccak256(abi.encode(intent.original))
        ) {
            revert IStreamPreparedNativeRightsPrimarySettlement.InvalidPreparedNativeRights();
        }
        StreamPreparedNativeSettlementValidation.requireIntentFields(facts.mint, intent.sale);
    }

    function requireActive(
        address core,
        address registry,
        StreamPreparedNativeRightsTypes.Facts memory rights,
        StreamPreparedNativeRightsTypes.Intent memory original
    ) public view returns (StreamNativeSettlementTypes.SaleLifecycleBinding memory lifecycle) {
        StreamPreparedNativeSettlementTypes.Facts memory facts = rights.mint;
        StreamPreparedNativeSettlementTypes.Intent memory intent = original.sale;
        requireIntentFields(rights, original);
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
        StreamPreparedNativeRightsTypes.Intent memory saved =
            readIntent(facts.saleAdapter, facts.recorder, facts.intentHash);
        if (keccak256(abi.encode(saved)) != keccak256(abi.encode(original))) {
            revert IStreamPreparedNativeRightsPrimarySettlement.InvalidPreparedNativeRights();
        }
        bytes memory raw = StreamPreparedNativeSettlementValidation.read(
            facts.mintManager,
            abi.encodeCall(IStreamPreparedNativeRightsMint.activePreparedNativeRights, ()),
            672
        );
        if (keccak256(raw) != keccak256(abi.encode(rights))) {
            revert IStreamPreparedNativeRightsPrimarySettlement.InvalidPreparedNativeRights();
        }
        raw = StreamPreparedNativeSettlementValidation.read(
            core, abi.encodeCall(IStreamCoreMint.preparedMint, (facts.tokenId)), 96
        );
        StreamPreparedMintRecord memory prepared = abi.decode(raw, (StreamPreparedMintRecord));
        if (
            !prepared.exists || prepared.operationId != facts.operationId
                || prepared.collectionId != facts.collectionId
                || keccak256(raw) != keccak256(abi.encode(prepared))
                || uint256(
                        StreamPreparedNativeSettlementValidation.word(
                            core, "pendingPreparedMintTokenId()"
                        )
                    ) != facts.tokenId || facts.tokenId == 0
        ) {
            revert IStreamPreparedNativeRightsPrimarySettlement.InvalidPreparedNativeRights();
        }
        raw = StreamPreparedNativeSettlementValidation.read(
            core, abi.encodeCall(IStreamCoreIdentity.tokenCollectionIdentity, (facts.tokenId)), 128
        );
        (bool exists, uint256 collection, uint256 serial, bool burned) =
            abi.decode(raw, (bool, uint256, uint256, bool));
        if (
            !exists || burned || collection != facts.collectionId
                || serial != facts.collectionSerial
                || keccak256(raw) != keccak256(abi.encode(exists, collection, serial, burned))
        ) {
            revert IStreamPreparedNativeRightsPrimarySettlement.InvalidPreparedNativeRights();
        }
        raw = StreamPreparedNativeSettlementValidation.read(
            core, abi.encodeCall(IStreamCoreIdentity.tokenLifecycle, (facts.tokenId)), 32
        );
        if (abi.decode(raw, (uint256)) != 1) {
            revert IStreamPreparedNativeRightsPrimarySettlement.InvalidPreparedNativeRights();
        }
        address ledger =
            StreamPreparedNativeSettlementValidation.addressWord(facts.mintManager, "mintLedger()");
        raw = StreamPreparedNativeSettlementValidation.read(
            ledger,
            abi.encodeCall(
                IStreamMintLedger.isManagerOperationRootUsed,
                (facts.mintManager, facts.operationRoot)
            ),
            32
        );
        if (abi.decode(raw, (uint256)) != 1) {
            revert IStreamPreparedNativeRightsPrimarySettlement.InvalidPreparedNativeRights();
        }
    }
}
