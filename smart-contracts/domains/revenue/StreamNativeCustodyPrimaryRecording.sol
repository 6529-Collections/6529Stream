// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./StreamNativeCustodyPrimaryValidation.sol";
import "./StreamTokenProfileCustodyHash.sol";
import "./StreamCustodyRightsHash.sol";
import "./StreamPlatformCustodyHash.sol";
import "./StreamNativePrimaryExecution.sol";
import "./StreamPrimarySettlementEmission.sol";
import "./StreamPrimarySettlementHash.sol";

/// @notice Official payment before custody delivery, with no mint or ledger operation.
library StreamNativeCustodyPrimaryRecording {
    struct Context {
        StreamNativeCustodyPrimaryAdmission.Context admission;
        bytes32 resolverHash;
        StreamNativePrimaryExecution.Context funding;
    }
    event NativeCustodyRevenueRecorded(
        bytes32 indexed settlementKey,
        bytes32 indexed saleKey,
        bytes32 indexed factsHash,
        StreamNativeCustodySettlementTypes.Facts facts,
        StreamPrimarySettlementTypes.PrimarySettlementResult result
    );

    function execute(
        Context memory x,
        StreamNativeCustodySettlementTypes.CanonicalHouse memory pin,
        mapping(bytes32 => bool) storage saleConsumed,
        mapping(bytes32 => bool) storage consumed,
        mapping(
            bytes32 => StreamPrimarySettlementTypes.PrimarySettlementResult
        ) storage results,
        mapping(bytes32 => bytes32) storage factsHashes,
        mapping(bytes32 => uint256) storage official,
        mapping(address => uint256) storage total,
        bytes32 id
    ) public returns (StreamPrimarySettlementTypes.PrimarySettlementResult memory r) {
        requireContext(x);
        StreamNativeCustodySettlementTypes.Facts memory f =
            StreamNativeCustodyPrimaryValidation.read(x.admission, pin, id);
        if (
            IERC165(msg.sender)
                    .supportsInterface(type(IStreamPlatformNativeRightsAuction).interfaceId)
                && IStreamPlatformNativeRightsAuction(msg.sender)
                        .platformAuctionDeclaration(f.auction.saleId) != 0
        ) {
            revert IStreamNativeCustodyPrimarySettlement.InvalidNativeCustodySettlement();
        }
        StreamTokenProfileCustodyHash.requireLegacy(msg.sender, id);
        StreamCustodyRightsHash.requireLegacy(msg.sender, id);
        if (
            msg.value != f.auction.winner.amount
                || f.auction.winner.payer == address(x.funding.escrow)
        ) {
            revert IStreamNativeCustodyPrimarySettlement.InvalidNativeCustodySettlement();
        }
        (
            StreamPrimarySettlementTypes.ERC20SettlementCandidate memory c,
            StreamSaleTemplate.Selection memory selected
        ) = StreamNativeCustodyPrimaryValidation.derive(
            x.funding.rights, f, msg.sender, address(this)
        );
        if (c.sale.payer == selected.wallet) {
            revert IStreamNativeCustodyPrimarySettlement.InvalidNativeCustodySettlement();
        }
        bytes32 saleKey = StreamPreparedNativeSettlementHash.saleKey(
            address(this), msg.sender, f.auction.saleId, f.auction.saleNonce
        );
        bytes32 key = StreamPrimarySettlementHash.settlementKey(
            address(this), msg.sender, c.executionBinding.executionId
        );
        if (saleConsumed[saleKey] || consumed[key]) {
            revert IStreamPrimarySaleSettlement.SettlementAlreadyConsumed(key);
        }
        saleConsumed[saleKey] = true;
        consumed[key] = true;
        bool escrowed = StreamNativePrimaryExecution.fund(
            x.funding, c.sale.collectionId, c.sale.amount, selected
        );
        requireContext(x);
        StreamNativeCustodySettlementTypes.Facts memory after_ =
            StreamNativeCustodyPrimaryValidation.read(x.admission, pin, id);
        (StreamPrimarySettlementTypes.ERC20SettlementCandidate memory afterCandidate,) = StreamNativeCustodyPrimaryValidation.derive(
            x.funding.rights, after_, msg.sender, address(this)
        );
        if (
            keccak256(abi.encode(f)) != keccak256(abi.encode(after_))
                || keccak256(abi.encode(c)) != keccak256(abi.encode(afterCandidate))
        ) {
            revert IStreamNativeCustodyPrimarySettlement.InvalidNativeCustodySettlement();
        }
        bytes32 factsHash = keccak256(
            abi.encode(
                keccak256("6529STREAM_NATIVE_CUSTODY_TRANSFER_FACTS_V1"),
                block.chainid,
                address(this),
                msg.sender,
                f
            )
        );
        r = StreamPrimarySettlementTypes.PrimarySettlementResult(
            keccak256(
                abi.encode(
                    keccak256("6529STREAM_NATIVE_CUSTODY_TRANSFER_CANDIDATE_V1"),
                    block.chainid,
                    address(this),
                    msg.sender,
                    f,
                    c
                )
            ),
            key,
            selected.profileId,
            selected.wallet,
            address(0),
            c.sale.amount,
            c.executor,
            c.executionBinding.executionId,
            escrowed,
            0,
            0,
            0
        );
        results[key] = r;
        factsHashes[key] = factsHash;
        official[
            keccak256(
                abi.encode(
                    keccak256("6529STREAM_OFFICIAL_PRIMARY_SETTLED_V1"),
                    keccak256("PRIMARY_SALE"),
                    selected.profileId,
                    selected.wallet,
                    address(0)
                )
            )
        ] += r.amount;
        total[address(0)] += r.amount;
        StreamPrimarySettlementEmission.emitSettlement(
            c, r, address(0), f.auction.config.expectedPrimaryPolicyHash
        );
        emit NativeCustodyRevenueRecorded(key, saleKey, factsHash, f, r);
    }

    function requireContext(Context memory x) private view {
        StreamSettlementAdmission.requireRegistry(
            x.admission.core, x.admission.coreHash, x.admission.registry, x.admission.registryHash
        );
        if (
            address(x.funding.rights.resolver).codehash != x.resolverHash
                || address(x.funding.rights.factory).codehash != x.funding.factoryHash
        ) {
            revert IStreamNativeCustodyPrimarySettlement.InvalidNativeCustodySettlement();
        }
    }
}
