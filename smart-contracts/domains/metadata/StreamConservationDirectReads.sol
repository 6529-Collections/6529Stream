// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./StreamConservationFloorReads.sol";
import "../revenue/StreamDirectPrimarySaleHash.sol";
import "../../interfaces/stream/revenue/IStreamDirectPrimarySaleReceipt.sol";
import "../../interfaces/stream/metadata/IStreamDirectPrimaryConservationFloor.sol";
import "../../interfaces/stream/mint/IStreamMintManager.sol";

/// @notice Bounded authentication of an original DIRECT adapter's actual immutable paid outcome.
/// @dev The admitted runtime validates the mint-returned vector before publishing its receipt.
/// Core exposes no token-to-operation getter: its independent proof here is completed collection
/// identity, joined with the original code-pinned Manager's used operation root.
library StreamConservationDirectReads {
    function requireReceipt(
        StreamConservationFloorReads.Context memory x,
        address adapter,
        bytes32 authorizationId
    )
        public
        view
        returns (
            StreamDirectPrimarySaleTypes.Bindings memory bindings,
            StreamDirectPrimarySaleTypes.Receipt memory sale,
            bytes32 key,
            bytes32 receiptHash
        )
    {
        (address registry,) = StreamConservationFloorReads.selected(x, keccak256("MODULE_REGISTRY"));
        uint256[14] memory row = _record(registry, adapter, x.readGas);
        _identity(adapter, row, x.readGas);
        bytes memory raw = StreamConservationFloorReads.read(
            adapter,
            abi.encodeCall(IStreamDirectPrimarySaleReceipt.directPrimaryBindings, ()),
            192,
            x.readGas
        );
        bindings = abi.decode(raw, (StreamDirectPrimarySaleTypes.Bindings));
        if (
            keccak256(raw) != keccak256(abi.encode(bindings)) || bindings.core != x.core
                || bindings.coreCodeHash != x.coreCodeHash
                || bindings.deploymentChainId != x.chainId
                || !StreamSettlementAdmission.isContract(bindings.mintManager)
                || bindings.mintManager.codehash != bindings.mintManagerCodeHash
                || StreamConservationFloorReads.word(
                        bindings.mintManager, abi.encodeWithSignature("core()"), x.readGas
                    ) != uint160(x.core)
                || (bindings.productKind != StreamDirectPrimarySaleTypes.NATIVE_FIXED_PRICE
                    && bindings.productKind != StreamDirectPrimarySaleTypes.ERC20_FIXED_PRICE
                    && bindings.productKind != StreamDirectPrimarySaleTypes.ENGLISH_AUCTION)
        ) revert IStreamConservationFloor.ConservationFloorAuthority(adapter);
        raw = StreamConservationFloorReads.read(
            adapter,
            abi.encodeCall(
                IStreamDirectPrimarySaleReceipt.directPrimarySaleReceipt, (authorizationId)
            ),
            512,
            x.readGas
        );
        sale = abi.decode(raw, (StreamDirectPrimarySaleTypes.Receipt));
        if (keccak256(raw) != keccak256(abi.encode(sale))) _mismatch(adapter, authorizationId);
        _paid(x, adapter, authorizationId, bindings, sale);
        if (
            sale.createdAt < row[10] || sale.createdAt > block.timestamp
                || sale.registryRevision > row[12]
                || (row[1] == 2
                    && (bindings.productKind != StreamDirectPrimarySaleTypes.ENGLISH_AUCTION
                        || sale.createdAt >= row[11]
                        || sale.registryRevision >= row[12]))
        ) revert IStreamConservationFloor.ConservationFloorAuthority(adapter);
        key = StreamDirectPrimarySaleHash.settlementKey(bindings, adapter, authorizationId);
        receiptHash =
            StreamDirectPrimarySaleHash.receiptHash(bindings, adapter, authorizationId, sale);
        if (
            bytes32(
                    StreamConservationFloorReads.word(
                        adapter,
                        abi.encodeCall(
                            IStreamDirectPrimarySaleReceipt.directPrimarySaleReceiptHash,
                            (authorizationId)
                        ),
                        x.readGas
                    )
                ) != receiptHash
        ) _mismatch(adapter, authorizationId);
    }

    function _paid(
        StreamConservationFloorReads.Context memory x,
        address adapter,
        bytes32 authorizationId,
        StreamDirectPrimarySaleTypes.Bindings memory bindings,
        StreamDirectPrimarySaleTypes.Receipt memory sale
    ) private view {
        if (
            authorizationId == 0 || sale.authorizationDigest == 0 || sale.collectionId == 0
                || sale.tokenId == 0 || sale.operationRoot == 0 || sale.operationId == 0
                || sale.boundMintPolicyHash == 0 || sale.expectedPrimaryPolicyHash == 0
                || sale.profileId == 0 || sale.wallet == address(0) || sale.payer == address(0)
                || sale.beneficiary == address(0) || sale.amount == 0 || sale.createdAt == 0
                || sale.registryRevision == 0
                || (bindings.productKind == StreamDirectPrimarySaleTypes.ERC20_FIXED_PRICE
                        ? !StreamSettlementAdmission.isContract(sale.asset)
                        : sale.asset != address(0))
                || StreamConservationFloorReads.word(
                        x.core,
                        abi.encodeCall(
                            IStreamCoreCollectionView.collectionExists, (sale.collectionId)
                        ),
                        x.readGas
                    ) != 1
                || StreamConservationFloorReads.word(
                        bindings.mintManager,
                        abi.encodeCall(
                            IStreamMintManager.isOperationRootUsed, (sale.operationRoot)
                        ),
                        x.readGas
                    ) != 1
                || StreamConservationFloorReads.word(
                        bindings.mintManager,
                        abi.encodeCall(IStreamMintManager.isAuthorizationUsed, (authorizationId)),
                        x.readGas
                    ) != 1
        ) _mismatch(adapter, authorizationId);
        StreamConservationFloorReads.requireToken(x, sale.collectionId, sale.tokenId, true);
    }

    function _identity(address adapter, uint256[14] memory row, uint256 cap) private view {
        bytes4 id = type(IStreamDirectPrimarySaleReceipt).interfaceId;
        if (
            bytes32(row[2]) != StreamDirectPrimarySaleTypes.MODULE_TYPE
                || bytes32(row[3]) != StreamDirectPrimarySaleTypes.MODULE_VERSION
                || row[4] != uint256(uint32(id)) << 224
                || StreamConservationFloorReads.word(
                        adapter, abi.encodeCall(IERC165.supportsInterface, (id)), cap
                    ) != 1
                || StreamConservationFloorReads.word(
                        adapter,
                        abi.encodeCall(IERC165.supportsInterface, (bytes4(0x01ffc9a7))),
                        cap
                    ) != 1
                || StreamConservationFloorReads.word(
                        adapter,
                        abi.encodeCall(IERC165.supportsInterface, (bytes4(0xffffffff))),
                        cap
                    ) != 0
        ) revert IStreamConservationFloor.ConservationFloorAuthority(adapter);
    }

    function _record(address registry, address adapter, uint256 cap)
        private
        view
        returns (uint256[14] memory row)
    {
        if (!StreamSettlementAdmission.isContract(adapter)) {
            revert IStreamConservationFloor.ConservationFloorAuthority(adapter);
        }
        bytes memory input = abi.encodeCall(IStreamModuleRegistry.moduleRecord, (adapter));
        if (cap == 0 || cap > type(uint64).max || gasleft() <= cap + cap / 63 + 10000) {
            revert IStreamConservationFloor.ConservationFloorRead(registry, bytes4(input));
        }
        bool ok;
        uint256 size;
        assembly ("memory-safe") {
            ok := staticcall(cap, registry, add(input, 32), mload(input), row, 448)
            size := returndatasize()
        }
        // Bound the dynamic URI without copying its tail into the caller's memory.
        if (
            !ok || size < 448 || size > 4096 || row[0] != 32 || row[9] != 384
                || row[13] > size - 448 || size - 448 != ((row[13] + 31) / 32) * 32
                || (row[1] != 1 && row[1] != 2) || row[5] > type(uint32).max
                || bytes32(row[6]) != adapter.codehash || row[7] == 0 || row[8] == 0 || row[10] == 0
                || row[10] > block.timestamp || row[10] > type(uint64).max || row[11] < row[10]
                || row[11] > block.timestamp || row[11] > type(uint64).max || row[12] == 0
                || row[12] > type(uint64).max
        ) revert IStreamConservationFloor.ConservationFloorAuthority(adapter);
    }

    function _mismatch(address adapter, bytes32 authorizationId) private pure {
        revert IStreamDirectPrimaryConservationFloor.ConservationDirectSaleMismatch(
            adapter, authorizationId
        );
    }
}
